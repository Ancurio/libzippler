/*
 * Memory.vala
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


using IOApi;
using GLib;

class Zippler.Memory
{
	public uint8[] data;
	public ulong size;

	private static int default_size = 0x100;

	public Memory()
	{
		data = new uint8[default_size];
		size = 0;
	}

	public Memory.from_file(string filename) throws FileError
	{
		try
		{
			FileUtils
				.get_data(filename, out this.data);
		}
		catch (FileError e)
		{
			throw e;
		}

		this.size = this.data.length;
	}

	public Memory.from_data(uint8[] data)
	{
		this.data = data;
		this.size = data.length;
	}

	public void expand()
	{
		int new_size = default_size;
		while (new_size <= size)
			new_size <<= 1;
		data.resize(new_size);
	}

	public void trim()
	{
		data.resize((int)(size+1));
	}

//~ 	public void dump()
//~ 	{
//~ 		for (long i = 0; i < size; i++)
//~ 			stdout.printf("%02X ", data[i]);
//~
//~ 		stdout.printf("\n");
//~ 	}
}

class Zippler.MemContext
{
	public Zippler.Memory memory;
	public IOApi.Mode mode;
	public long position = 0;

	public bool opened = false;

	public IOApi.FileFuncVector vector;

	public MemContext(Memory memory)
	{
		this.memory = memory;

		vector = FileFuncVector();
		vector.open       = MemContext.open;
		vector.read       = MemContext.read;
		vector.write      = MemContext.write;
		vector.close      = MemContext.close;
		vector.tell       = MemContext.tell;
		vector.seek       = MemContext.seek;
		vector.test_error = MemContext.test_error;
		vector.user_data  = this;
	}

	public void* open(string filename, IOApi.Mode mode)
	{
		this.mode = mode;
		this.opened = true;

//		stdout.printf("Call: OPEN. filename: %s, mode: %d\n", filename, mode);
//		stdout.printf("--> Return: %p\n", _self);

		return this;
	}

	public ulong read(void* stream, uint8* buffer, ulong size)
	{
		long i;
		for (i = 0; i < size; i++)
		{
			if (position > memory.size)
				break;

			buffer[i] = memory.data[position++];
		}

//		stdout.printf("--> Return: %lu\n", i);
//		stdout.printf("Call: READ. stream: %p, buffer: %p, size %lu\n",
//		              stream, buffer, size);

		return i;
	}

	public ulong write(void* stream, uint8* buffer, ulong size)
	{
		long i;
		for (i = 0; i < size; i++)
		{
			if (position > memory.data.length)
				memory.expand();

			if (position > memory.size)
				memory.size = position;

			memory.data[position++] = buffer[i];
		}

//		stdout.printf("Call: WRITE. stream: %p, buffer: %p, size %lu\n",
//		              stream, buffer, size);
//		stdout.printf("--> Return: %lu\n", i);
		return i;
	}

	public bool close(void* stream)
	{
		opened = false;

//		stdout.printf("Call: CLOSE. stream: %p\n", stream);
//		stdout.printf("--> Return: %s\n", "false");

		return false;
	}

	public bool test_error(void* stream)
	{
		// Not sure what to do with this yet

//		stdout.printf("Call: ERROR. stream: %p\n", stream);
//		stdout.printf("--> Return: %s\n", "false");

		return false;
	}

	public long tell(void* stream)
	{
//		stdout.printf("Call: TELL. stream: %p\n", stream);
//		stdout.printf("--> Return: %li\n", position);

		return position;
	}

	public long seek(void* stream, ulong offset, IOApi.SeekType type)
	{
		long seek_to = position;
		switch (type)
		{
		case IOApi.SeekType.SET :
			seek_to = 0;
			break;

		case IOApi.SeekType.END :
			seek_to = (long) memory.size;
			break;

		case IOApi.SeekType.CUR :
			break;
		}

		seek_to += (long) offset;

		if (seek_to > memory.size+1)
		{
//			stdout.printf("SEEK TOO FAR: seek_to: %li, size: %lu\n", seek_to, memory.size);
//			stdout.printf("--> Return: %li\n", -1);
			return -1;
		}

		position = seek_to;

//		stdout.printf("Call: SEEK. stream: %p, offset: %lu, mode: %d\n",
//		              stream, offset, type);
//		stdout.printf("--> Return: %li\n", 0);

		return 0;
	}


}

