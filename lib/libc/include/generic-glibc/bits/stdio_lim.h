/* System specific stdio.h definitions.  Linux version.
   Copyright (C) 2023-2025 Free Software Foundation, Inc.
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

#ifndef _BITS_STDIO_LIM_H
#define _BITS_STDIO_LIM_H 1

#ifndef _STDIO_H
# error "Never include <bits/stdio_lim.h> directly; use <stdio.h> instead."
#endif

#define FILENAME_MAX 4096

#endif /* bits/stdio_lim.h */