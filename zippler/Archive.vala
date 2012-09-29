/*
 * Archive.vala
 *
 * Copyright (c) 2012 Jonas Kulla <Nyocurio@googlemail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 */


using Unzip;
using Zip;

public errordomain Zippler.Error
{
	FILE_ERROR,
	ERRNO,
	END_OF_FILE,
	BAD_ARCHIVE,
	BAD_CRC,
	INTERNAL_ERROR,
	UNKNOWN
}

public enum Zippler.CacheType
{
	NONE,
	PROGRESSIVE,
	FULL
}

public class Zippler.Archive : Object
{
	private Unzip.File unzp;

	private Zippler.MemContext mem_context;

	private HashTable<string, Entry> entry_hash;


	public bool loaded { get; private set; default = false; }

	public CacheType cache_type { get; set; default = CacheType.NONE; }

	public string global_comment { get; internal set; default = ""; }

	public Entry root_entry { get; private set; default = null; }

	public ulong entry_count { get; private set; default = 0; }

	public Archive()
	{
		entry_hash = new HashTable<string, Entry>(str_hash, str_equal);

		root_entry = new Entry.create_root();
		entry_hash.insert("/", root_entry);
	}

	~Archive()
	{
		if (loaded)
			unzp.close();
	}

	private static void throw_error(Unzip.ReturnCode code) throws Error
	{
		switch (code)
		{
		case ReturnCode.ERRNO :
			throw new Zippler.Error.ERRNO("ERRNO set");

		case ReturnCode.EOF :
			throw new Zippler.Error.END_OF_FILE("End of file");

		case ReturnCode.BAD_ZIPFILE :
			throw new Zippler.Error.BAD_ARCHIVE("Bad archive");

		case ReturnCode.CRC_ERROR :
			throw new Zippler.Error.BAD_CRC("Bad CRC");

		default:
			throw new Zippler.Error.UNKNOWN("Unknown error");
		}
	}

	public void load_file_buffered(string filename) throws Error
	{
		if (loaded)
			return;

		Zippler.Memory mem;
		try
		{
			mem = new Zippler.Memory.from_file(filename);
		}
		catch (FileError e)
		{
			throw new Zippler.Error.FILE_ERROR(e.message);
		}

		this.mem_context = new MemContext(mem);
		unzp = Unzip.File.with_vector("", mem_context.vector);

		load_tree();
	}

	public void load_memory(uint8[] data) throws Error
	{
		if (loaded)
			return;

		var mem = new Zippler.Memory.from_data(data);
		this.mem_context = new MemContext(mem);
		unzp = Unzip.File.with_vector("", mem_context.vector);

		load_tree();
	}

	public void load_file(string filename) throws Error
	{
		if (loaded)
			return;

		unzp = Unzip.File(filename);

		load_tree();
	}

	private void load_tree() throws Error
	{
		if ((size_t)unzp == 0)
			throw new Zippler.Error.FILE_ERROR("Could not open archive");

		/* load entry tree */
		GlobalInfo ginfo;
		ReturnCode rcode = unzp.get_global_info(out ginfo);
		if (rcode != ReturnCode.OK)
			throw_error(rcode);

		entry_count = ginfo.entry_count;
		var comment_size = ginfo.comment_size;

		var comment_buf = new char[comment_size+1];
		if (unzp.get_global_comment(comment_buf) > 0)
			global_comment = (string) comment_buf;

		for (int i = 0; i < entry_count; i++)
		{
			Unzip.FileInfo finfo;
			Unzip.FilePosition fposition;

			unzp.get_current_file_info(out finfo);
			unzp.get_current_file_position(out fposition);

			var _name = new char[finfo.filename_size+1];
			var extra = new uint8[finfo.file_extra_size];
			var _comment = new char[finfo.file_comment_size+1];
			unzp.get_current_file_info(out finfo, _name, extra, _comment);

			_name[_name.length-1] = '\0';
			_comment[_comment.length-1] = '\0';

			var name = (string) _name;
			var comment = (string) _comment;

			Entry parent;
			string entry_name;
			EntryType type;
			string entry_path = "/" + name;

			get_entry_info(entry_path, out parent, out entry_name, out type);

			if (type == EntryType.DIRECTORY)
			{
				// Check if this dir was already preemptivley
				// added, and replace the entry data if so
				Entry? existing = entry_hash.lookup(entry_path);
				if (existing != null)
				{
					existing.accept_data(finfo, entry_name, entry_path,
					                     extra, comment, fposition,
					                     EntryType.DIRECTORY);

					if (i+1 < entry_count)
						unzp.go_to_next_file();

					continue;
				}
			}

			var entry = new Entry(finfo, entry_name, entry_path,
			                      extra, comment, fposition,
				                  type, cache_type == CacheType.PROGRESSIVE);

			setup_entry(entry, parent, entry_path);

			if (i+1 < entry_count)
				unzp.go_to_next_file();
		}

		if (cache_type == CacheType.FULL)
			root_entry.foreach_child( (e) =>
			{
				e.cache_contents();
			});

		this.loaded = true;
	}

	private void setup_entry(Entry entry, Entry parent, string path)
	{
		entry.archive = this;
		entry.parent = parent;
		parent.append_child(entry);

		entry_hash.insert(path, entry);
	}

	private void get_entry_info(string path,
	                            out Entry parent,
	                            out string name,
	                            out EntryType type)
	{
		type = path.has_suffix("/") ? EntryType.DIRECTORY
			                        : EntryType.FILE;

		string basename = Path.get_basename(path);
		string dirname  = Path.get_dirname(path);

		string parent_path;

		if (type == EntryType.FILE)
		{
			name = basename;
			parent_path = dirname;
		}
		else
		{
			name = basename + "/";
			parent_path = Path.get_dirname(dirname);
		}

		bool in_root = (parent_path == "/");

		if (in_root)
		{
			parent = root_entry;
		}
		else
		{
			string _parent_path = parent_path + "/";

			parent = entry_hash.lookup(_parent_path);

			if (parent == null)
			{
				parent =
					new Entry.create_placeholder
						(Path.get_basename(_parent_path)+"/", _parent_path+"/");

				Entry super_parent;
				get_entry_info(_parent_path, out super_parent, null, null);

				super_parent.append_child(parent);
				parent.parent = super_parent;

				entry_hash.insert(_parent_path, parent);
			}
		}
	}

	// Actually returns zero terminated string
	internal uint8[]? get_entry_data_uncompressed(Entry e)
	{
		if (!e.has_readable_content())
			return null;

		unzp.go_to_file_position(e.get_file_position());

		var data = new uint8[e.uncompressed_size+1];

		unzp.open_current_file();
		unzp.read_current_file(data);
		unzp.close_current_file();

		data[data.length-1] = '\0';

		return data;
	}

	internal uint8[]? get_entry_data_compressed(Entry e, out int method, out int level)
	{
		method = 0; level = 0;

		if (!e.has_readable_content())
			return null;

		unzp.go_to_file_position(e.get_file_position());

		var data = new uint8[e.compressed_size];

		unzp.open_current_file_raw(out method, out level);
		unzp.read_current_file(data);
		unzp.close_current_file();

		return data;
	}

	private static int DEFAULT_METHOD = 8;
	private static int DEFAULT_LEVEL  = 5;

	public void write_to_file(string filename)
	{
		var zfile = Zip.File(filename, AppendMode.CREATE);

		write(zfile);
	}

	public uint8[] write_to_memory()
	{
		var mem = new Zippler.Memory();
		var ctx = new Zippler.MemContext(mem);
		var zfile = Zip.File.with_vector("", AppendMode.CREATE, null, ctx.vector);

		write(zfile);

		mem.trim();

		return (owned) mem.data;
	}

	private void write(Zip.File zfile)
	{
		root_entry.foreach_child((e) =>
		{
			var finfo = Zip.FileInfo();
			finfo.dos_date    = 0;
			finfo.date_time   = gdt_to_zdt(e.date_time);
			finfo.internal_fa = e.internal_fa;
			finfo.external_fa = e.external_fa;

			string zip_path = e.path[1:e.path.length];

			if (e.get_contents_modified())
			{
				// Write newly attached data

				zfile.open_new_file
					(zip_path, finfo, e.extra,
					 null, e.comment, DEFAULT_METHOD, DEFAULT_LEVEL);

				var data = e.get_contents();

				zfile.write_to_file(data);

				zfile.close_file();
			}
			else
			{
				// Write old raw data

				int method = 0,
				    level  = 0;

				var data = get_entry_data_compressed(e, out method, out level);

				zfile.open_new_file_raw
					(zip_path, finfo, e.extra,
					 null, e.comment, method, level);

				zfile.write_to_file(data);

				zfile.close_file_raw(e.uncompressed_size, e.crc);
			}
		});

		zfile.close(global_comment);
	}

	public unowned Entry? add_entry(string name, Entry parent)
	{
		// Parent must be a directory
		if (parent.entry_type != EntryType.DIRECTORY)
			return null;

		// No double slash allowed
		if (name.contains("//"))
			return null;

		return add_entry_path(parent.path + name);
	}

	public unowned Entry? add_entry_path(string path)
	{
		// Root path not allowed
		if (path == "/")
			return null;

		// Full path must be absolute
		if (!path.has_prefix("/"))
			return null;

		// No double slash allowed
		if (path.contains("//"))
			return null;

		// Check if already existing
		if (entry_hash.lookup(path) != null)
			return null;

		Entry parent;
		string name;
		EntryType type;

		get_entry_info(path, out parent, out name, out type);

		var entry = new Entry.empty(name, path, type);
		setup_entry(entry, parent, path);
		entry.set_user_created();

		entry_count++;

		weak Entry ret = entry;
		return ret;
	}

	public bool remove_entry(Entry e)
	{
		// Must be entry from this archive
		if (e.archive != this)
			return false;

		if (e == root_entry)
			return false;

		entry_hash.remove(e.path);
		e.parent.remove_child(e);

		if (e.entry_type == EntryType.DIRECTORY)
		{
			List<weak Entry> children = e.get_children();
			foreach (Entry c in children)
				remove_entry(c);
		}

		entry_count--;

		return true;
	}

	public List<unowned Entry> get_flat_list()
	{
		var list = new List<unowned Entry>();
		root_entry.foreach_child((e) =>
		{
			list.append(e);
		});

		return (owned) list;
	}

	public unowned Entry? lookup_entry(string path)
	{
		return entry_hash.lookup(path);
	}
}

