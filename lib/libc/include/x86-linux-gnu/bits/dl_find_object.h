/* x86 definitions for finding objects.
   Copyright (C) 2021-2024 Free Software Foundation, Inc.
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

#ifndef _DLFCN_H
# error "Never use <bits/dl_find_object.h> directly; include <dlfcn.h> instead."
#endif

#ifdef __x86_64__
# define DLFO_STRUCT_HAS_EH_DBASE 0
#else
# define DLFO_STRUCT_HAS_EH_DBASE 1
#endif
#define DLFO_STRUCT_HAS_EH_COUNT 0
#define DLFO_EH_SEGMENT_TYPE PT_GNU_EH_FRAME