/* Define the machine-dependent type 'jmp_buf'.  ARC version.
   Copyright (C) 2020-2025 Free Software Foundation, Inc.
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

#ifndef _ARC_BITS_SETJMP_H
#define _ARC_BITS_SETJMP_H 1

/* Saves r13-r25 (callee-saved), fp (frame pointer), sp (stack pointer),
   blink (branch-n-link).  */
typedef long int __jmp_buf[32];

#endif