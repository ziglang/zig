/* bits/ipctypes.h -- Define some types used by SysV IPC/MSG/SHM.  MIPS version
   Copyright (C) 2002-2025 Free Software Foundation, Inc.
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

/*
 * Never include <bits/ipctypes.h> directly.
 */

#ifndef _BITS_IPCTYPES_H
#define _BITS_IPCTYPES_H	1

#include <bits/types.h>

typedef __SLONG32_TYPE __ipc_pid_t;


#endif /* bits/ipctypes.h */