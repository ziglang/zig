/* Finding the entry point and start of text.  PowerPC64 version.
   Copyright (C) 2002-2021 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */


#ifndef __ASSEMBLY__
extern void _start (void);
#endif

#define ENTRY_POINT _start

#if _CALL_ELF != 2
/* We have to provide a special declaration.  */
#define ENTRY_POINT_DECL(class) class void _start (void);

/* Use the address of ._start as the lowest address for which we need
   to keep profiling records.  We can't copy the ia64 scheme as our
   entry poiny address is really the address of the function
   descriptor, not the actual function entry.  */
#define TEXT_START \
  ({ extern unsigned long int _start_as_data[] asm ("_start");  \
     _start_as_data[0]; })
#endif
