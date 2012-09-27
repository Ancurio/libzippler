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
		vector.open       = open;
		vector.read       = read;
		vector.write      = write;
		vector.close      = close;
		vector.tell       = tell;
		vector.seek       = seek;
		vector.test_error = test_error;
		vector.user_data  = this;
	}

	public static void* open(void* _self, string filename, IOApi.Mode mode)
	{
		var self = _self as MemContext;
		self.mode = mode;
		self.opened = true;

//		stdout.printf("Call: OPEN. filename: %s, mode: %d\n", filename, mode);
//		stdout.printf("--> Return: %p\n", _self);

		return _self;
	}

	public static ulong read(void* _self, void* stream, uint8* buffer, ulong size)
	{
		var self = _self as MemContext;

		long i;
		for (i = 0; i < size; i++)
		{
			if (self.position > self.memory.size)
				break;

			buffer[i] = self.memory.data[self.position++];
		}

//		stdout.printf("--> Return: %lu\n", i);
//		stdout.printf("Call: READ. stream: %p, buffer: %p, size %lu\n",
//		              stream, buffer, size);

		return i;
	}

	public static ulong write(void* _self, void* stream, uint8* buffer, ulong size)
	{
		var self = _self as MemContext;

		long i;
		for (i = 0; i < size; i++)
		{
			if (self.position > self.memory.data.length)
				self.memory.expand();

			if (self.position > self.memory.size)
				self.memory.size = self.position;

			self.memory.data[self.position++] = buffer[i];
		}

//		stdout.printf("Call: WRITE. stream: %p, buffer: %p, size %lu\n",
//		              stream, buffer, size);
//		stdout.printf("--> Return: %lu\n", i);
		return i;
	}

	public static bool close(void* _self, void* stream)
	{
		var self = _self as MemContext;

		self.opened = false;

//		stdout.printf("Call: CLOSE. stream: %p\n", stream);
//		stdout.printf("--> Return: %s\n", "false");

		return false;
	}

	public static bool test_error(void* _self, void* stream)
	{
		// Not sure what to do with this yet

//		stdout.printf("Call: ERROR. stream: %p\n", stream);
//		stdout.printf("--> Return: %s\n", "false");

		return false;
	}

	public static long tell(void* _self, void* stream)
	{
		var self = _self as MemContext;

//		stdout.printf("Call: TELL. stream: %p\n", stream);
//		stdout.printf("--> Return: %li\n", self.position);

		return self.position;
	}

	public static long seek(void* _self, void* stream, ulong offset, IOApi.SeekType type)
	{
		var self = _self as MemContext;


		long seek_to = self.position;
		switch (type)
		{
		case IOApi.SeekType.SET :
			seek_to = 0;
			break;

		case IOApi.SeekType.END :
			seek_to = (long) self.memory.size;
			break;

		case IOApi.SeekType.CUR :
			break;
		}

		seek_to += (long) offset;

		if (seek_to > self.memory.size+1)
		{
//			stdout.printf("SEEK TOO FAR: seek_to: %li, memory.size: %lu\n", seek_to, self.memory.size);
//			stdout.printf("--> Return: %li\n", -1);
			return -1;
		}

		self.position = seek_to;

//		stdout.printf("Call: SEEK. stream: %p, offset: %lu, mode: %d\n",
//		              stream, offset, type);
//		stdout.printf("--> Return: %li\n", 0);

		return 0;
	}


}

