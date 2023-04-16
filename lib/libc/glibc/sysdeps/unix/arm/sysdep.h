/* Copyright (C) 1997-2023 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#include <sysdeps/unix/sysdep.h>
#include <sysdeps/arm/sysdep.h>

/* Some definitions to allow the assembler in sysdeps/unix/ to build
   without needing ARM-specific versions of all the files.  */

#ifdef __ASSEMBLER__

#define ret		DO_RET (r14)
#define MOVE(a,b)	mov b,a

#endif
