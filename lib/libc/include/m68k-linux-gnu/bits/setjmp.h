/* Copyright (C) 1997-2024 Free Software Foundation, Inc.
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

/* Define the machine-dependent type `jmp_buf'.  m68k version.  */
#ifndef _BITS_SETJMP_H
#define _BITS_SETJMP_H	1

#if !defined _SETJMP_H && !defined _PTHREAD_H
# error "Never include <bits/setjmp.h> directly; use <setjmp.h> instead."
#endif

typedef struct __jmp_buf_internal_tag
  {
    /* There are eight 4-byte data registers, but D0 is not saved.  */
    long int __dregs[7];

    /* There are six 4-byte address registers, plus the FP and SP.  */
    int *__aregs[6];
    int *__fp;
    int *__sp;

#if defined __HAVE_68881__ || defined __HAVE_FPU__
    /* There are eight floating point registers which
       are saved in IEEE 96-bit extended format.  */
    char __fpregs[8 * (96 / 8)];
#elif defined __mcffpu__
    char __fpregs[8 * (64 / 8)];
#endif

  } __jmp_buf[1];

#endif	/* bits/setjmp.h */