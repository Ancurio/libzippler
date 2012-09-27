/*
 * Utility.vala
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


using GLib;

namespace Zippler
{
	internal GLib.DateTime udt_to_gdt(Unzip.DateTime udt)
	{
		return new GLib.DateTime.local
		(
			udt.year,
			udt.month,
			udt.day,
			udt.hour,
			udt.minute,
			udt.second
		);
	}

	internal Zip.DateTime gdt_to_zdt(GLib.DateTime gdt)
	{
		var zdt = Zip.DateTime();

		zdt.second = gdt.get_second();
		zdt.minute = gdt.get_minute();
		zdt.hour   = gdt.get_hour();
		zdt.day    = gdt.get_day_of_month();
		zdt.month  = gdt.get_month();
		zdt.year   = gdt.get_year();

		return zdt;
	}
}

