/* Define the machine-dependent type `jmp_buf'.  Nios II version.
   Copyright (C) 1992-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

#ifndef _NIOS2_BITS_SETJMP_H
#define _NIOS2_BITS_SETJMP_H 1

#if !defined(_SETJMP_H) && !defined(_PTHREAD_H)
# error "Never include <bits/setjmp.h> directly; use <setjmp.h> instead."
#endif

/* Saves r16-r22 (callee-saved, including GOT pointer), fp (frame pointer),
   ra (return address), and sp (stack pointer).  */
typedef int __jmp_buf[10];

#endif /* _NIOS2_BITS_SETJMP_H */