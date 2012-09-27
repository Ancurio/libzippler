
using Zippler;
using Gtk;


void append_store_entry(TreeStore store,
                        TreeIter p_iter,
                        List<weak Zippler.Entry> entries,
                        HashTable<void*, Zippler.Entry> hash)
{
	entries.sort( (e1, e2) =>
	{
		if (e1.entry_type == EntryType.DIRECTORY)
		{
			if (e2.entry_type == EntryType.DIRECTORY)
				return GLib.strcmp(e1.name, e2.name);
			else
				return -1;
		}
		if (e2.entry_type == EntryType.DIRECTORY)
			return 1;

		return GLib.strcmp(e1.name, e2.name);
	});

	foreach (Zippler.Entry e in entries)
	{
		TreeIter child;
		store.append(out child, p_iter);
		store.set(child,
		          0, e.name,
		          1, e.uncompressed_size,
		          2, e.date_time.format("%H:%M %d-%b-%Y"),
		         -1);
		hash.insert(child.user_data, e);
		if (e.entry_type == Zippler.EntryType.DIRECTORY)
			append_store_entry(store, child, e.get_children(), hash);
	}
}


TreeStore setup_store(Zippler.Archive zip,
                      HashTable<void*, Zippler.Entry> hash)
{
	var store = new TreeStore(3, typeof(string),
	                             typeof(ulong),
	                             typeof(string));

	TreeIter root;
	store.append(out root, null);
	store.set(root, 0, "/", 1, 0, 2, "", -1);
	hash.insert(root.user_data, zip.root_entry);

	append_store_entry(store, root, zip.root_entry.get_children(), hash);

	return store;
}


int main(string[] args)
{

	if (args.length < 2)
	{
		stdout.printf("Usage: %s [zipfile]\n", args[0]);
		return 0;
	}

	Gtk.init(ref args);

	var zip = new Zippler.Archive();
//	zip.cache_type = CacheType.PROGRESSIVE;

	try {
		zip.load_file_buffered(args[1]); }

	catch(Zippler.Error e) { return 0; }

	var hash = new HashTable<void*, Zippler.Entry>(direct_hash, direct_equal);

	TreeStore store = setup_store(zip, hash);

	var view = new TreeView();
	view.insert_column_with_attributes
		(-1, "Name", new CellRendererText (), "text", 0, null);
	view.insert_column_with_attributes
		(-1, "Size", new CellRendererText (), "text", 1, null);
	view.insert_column_with_attributes
		(-1, "Date", new CellRendererText (), "text", 2, null);

	view.set_model(store);

	var buffer = new TextBuffer(null);

	var text = new TextView.with_buffer(buffer);
	text.wrap_mode = WrapMode.WORD;

	var select = view.get_selection();
	select.changed.connect( (s) =>
	{
		TreeIter selected;
		s.get_selected(null, out selected);
		Zippler.Entry entry = hash.lookup(selected.user_data);
		if (entry != null)
		{
			if (entry.entry_type == EntryType.DIRECTORY)
				return;

			string contents = entry.get_contents_string();

			if (!contents.validate())
				contents = "[INVALID UTF8]";

			if (contents == "")
				contents = "[EMPTY FILE]";

			buffer.set_text(contents);
		}
	});

	var scrolled_view = new ScrolledWindow(null, null);
	scrolled_view.add_with_viewport(view);

	var scrolled_text = new ScrolledWindow(null, null);
	scrolled_text.add_with_viewport(text);

	var paned = new Paned(Orientation.HORIZONTAL);
//	var paned = new Paned();
	paned.pack1(scrolled_view, true, false);
	paned.pack2(scrolled_text, true, false);

	var win = new Window();
	win.set_default_size(640, 480);
	win.add(paned);
	win.show_all();
	win.destroy.connect(Gtk.main_quit);

	Gtk.main();

	return 0;
}
