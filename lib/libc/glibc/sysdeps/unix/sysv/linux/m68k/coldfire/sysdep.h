/* Copyright (C) 2010-2024 Free Software Foundation, Inc.
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

#ifndef _LINUX_M68K_COLDFIRE_SYSDEP_H
#define _LINUX_M68K_COLDFIRE_SYSDEP_H 1

#include <sysdeps/unix/sysdep.h>
#include <sysdeps/m68k/coldfire/sysdep.h>
#include <sysdeps/unix/sysv/linux/m68k/sysdep.h>

#define SYSCALL_ERROR_LOAD_GOT(reg)					      \
    move.l &_GLOBAL_OFFSET_TABLE_@GOTPC, reg;				      \
    lea (-6, %pc, reg), reg

#endif
