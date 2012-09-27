/*
 * Entry.vala
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

public enum Zippler.EntryType
{
	FILE,
	DIRECTORY
}

public class Zippler.Entry
{
	private bool placeholder;
	private bool contents_modified = false;
	private bool user_created = false;
	private bool cache_contents_on_read;

	private FilePosition fposition;

	// Cached decoded contents are intentionally
	// one byte longer, so on 'get_contents_string()'
	// we can just return that, and on 'get_contents()'
	// we can trim the buffer. This way a buffer is never
	// realloc'ed to a bigger size. However, new content
	// attached by the user is the exact length,
	// so we have to deal with this corner case.

	// Is zero terminated
	private uint8[]? cached_contents_term;
	// Is NOT zero terminated
	private uint8[]? cached_contents_user;

	public string name { get; internal set; }
	public string path { get; private set; }
	public EntryType entry_type { get; private set; }

	public uint8[]? extra;
	public string? comment;

	public ulong version;
	public ulong flags;
	public ulong dos_date;
	public ulong crc;
	public ulong compressed_size;
	public ulong uncompressed_size;

	public ulong disk_number_start;
	public ulong internal_fa;
	public ulong external_fa;

	public GLib.DateTime date_time;

	private List<Entry> children;
	public uint children_count { get; private set; default = 0; }

	public weak Archive archive { get; internal set; }
	public weak Entry? parent { get; internal set; default = null; }


	internal Entry.create_root()
	{
		this.name = ("/");
		this.entry_type = EntryType.DIRECTORY;
		this.placeholder = true;
	}

	internal Entry.empty(string name, string path, EntryType type)
	{
		this.name = name;
		this.path = path;
		this.entry_type = type;
		this.date_time = new GLib.DateTime.now_local();
	}

	internal Entry.create_placeholder(string name, string path)
	{
		Entry.empty(name, path, EntryType.DIRECTORY);
		this.placeholder = true;
	}

	internal void accept_data(Unzip.FileInfo info,
	                          string name,
	                          string path,
	                          uint8[]? extra,
	                          string? comment,
	                          FilePosition fposition,
	                          EntryType type)
	{
		this.name = name;
		this.path = path;

		this.entry_type        = type;
		this.version           = info.version;
		this.flags             = info.flags;
		this.dos_date          = info.dos_date;
		this.crc               = info.crc;
		this.compressed_size   = info.compressed_size;
		this.uncompressed_size = info.uncompressed_size;

		this.extra = extra;
		this.comment = comment;

		this.disk_number_start = info.disk_number_start;
		this.internal_fa       = info.internal_fa;
		this.external_fa       = info.external_fa;

		this.date_time         = udt_to_gdt(info.date_time);

		this.fposition = fposition;

		this.placeholder = false;
	}


	internal Entry(Unzip.FileInfo info,
	               string name,
	               string internal_name,
	               uint8[]? extra,
	               string? comment,
	               FilePosition fposition,
	               EntryType type,
	               bool progressive_cache)
	{
		accept_data
			(info, name, internal_name,
			 extra, comment, fposition, type);

		this.cache_contents_on_read = progressive_cache;
	}

	internal FilePosition get_file_position()
	{
		return fposition;
	}

	internal bool get_contents_modified()
	{
		return contents_modified;
	}

	internal bool has_readable_content()
	{
		return entry_type != EntryType.DIRECTORY;
	}

	internal void set_user_created()
	{
		user_created = true;

		if (entry_type == EntryType.FILE)
			set_contents("".data);
	}

	internal void cache_contents()
	{
		if (entry_type == EntryType.DIRECTORY)
			return;

		if (cached_contents_term != null) // Already cached
			return;

		if (cached_contents_user != null)
			return;

		cached_contents_term =
			archive.get_entry_data_uncompressed(this);
	}

	private uint8[]? get_contents_intern(ref bool terminated)
	{
		if (!has_readable_content())
			return null;

		if (cache_contents_on_read)
			cache_contents();

		terminated = (!contents_modified);

		uint8[] contents = null;

		if (cached_contents_user != null)
			return cached_contents_user;
		else if (cached_contents_term != null)
			contents = cached_contents_term;
		else
			contents = archive.get_entry_data_uncompressed(this);

		return contents;
	}

	internal void append_child(Entry child)
	{
		children.append(child);
		children_count++;
	}

	internal void remove_child(Entry child)
	{
		children.remove(child);
		children_count--;
	}

	public List<weak Entry> get_children()
	{
		return children.copy();
	}

	public uint8[]? get_contents()
	{
		bool terminated = false;
		uint8[]? contents = get_contents_intern(ref terminated);

		if (contents == null)
			return null;

		if (terminated)
			contents.resize(contents.length-1);

		return contents;
	}

	public string get_contents_string()
	{
		bool terminated = false;
		uint8[]? contents = get_contents_intern(ref terminated);

		if (contents == null)
			return "";

		if (!terminated)
		{
			contents.resize(contents.length+1);
			contents[contents.length-1] = '\0';
		}

		return (string) (owned) contents;
	}

	public uint8[]? get_contents_raw()
	{
		if (entry_type == EntryType.DIRECTORY)
			return null;

		// No compressed data present
		if (user_created)
			return null;

		int method = 0,
		    level  = 0;

		return archive.get_entry_data_compressed(this, out method, out level);
	}

	public void set_contents(owned uint8[] data)
	{
		cached_contents_user = data;
		contents_modified = true;
		date_time = new GLib.DateTime.now_local();
	}

	internal static int compare_func(Entry e1, Entry e2)
	{
		return GLib.strcmp(e1.path, e2.path);
	}
}

