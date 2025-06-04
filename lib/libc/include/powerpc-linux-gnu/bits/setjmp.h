/* Copyright (C) 1997-2025 Free Software Foundation, Inc.
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

/* Define the machine-dependent type `jmp_buf'.  PowerPC version.  */
#ifndef _BITS_SETJMP_H
#define _BITS_SETJMP_H  1

#if !defined _SETJMP_H && !defined _PTHREAD_H
# error "Never include <bits/setjmp.h> directly; use <setjmp.h> instead."
#endif

/* The previous bits/setjmp.h had __jmp_buf defined as a structure.
   We use an array of 'long int' instead, to make writing the
   assembler easier. Naturally, user code should not depend on
   either representation. */

#include <bits/wordsize.h>

/* The current powerpc 32-bit Altivec ABI specifies for SVR4 ABI and EABI
   the vrsave must be at byte 248 & v20 at byte 256.  So we must pad this
   correctly on 32 bit.  It also insists that vecregs are only guaranteed
   4 byte alignment so we need to use vperm in the setjmp/longjmp routines.
   We have to version the code because members like  int __mask_was_saved
   in the jmp_buf will move as jmp_buf is now larger than 248 bytes.  We
   cannot keep the altivec jmp_buf backward compatible with the jmp_buf.  */
#ifndef	_ASM
# if __WORDSIZE == 64
typedef long int __jmp_buf[64] __attribute__ ((__aligned__ (16)));
# else
/* The alignment is not essential, i.e.the buffer can be copied to a 4 byte
   aligned buffer as per the ABI it is just added for performance reasons.  */
typedef long int __jmp_buf[64 + (12 * 4)] __attribute__ ((__aligned__ (16)));
# endif
#endif

#endif  /* bits/setjmp.h */