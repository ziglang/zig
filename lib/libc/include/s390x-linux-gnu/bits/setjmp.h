/* Copyright (C) 2000-2024 Free Software Foundation, Inc.
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

/* Define the machine-dependent type `jmp_buf'.  IBM s390 version.  */

#ifndef __S390_SETJMP_H__
#define __S390_SETJMP_H__

#if !defined _SETJMP_H && !defined _PTHREAD_H
# error "Never include <bits/setjmp.h> directly; use <setjmp.h> instead."
#endif

#include <bits/wordsize.h>

#ifndef	_ASM

typedef struct __s390_jmp_buf
{
  /* We save registers 6-15.  */
  long int __gregs[10];

# if __WORDSIZE == 64
  /* We save fpu registers f8 - f15.  */
  long __fpregs[8];
# else
  /* We save fpu registers 4 and 6.  */
  long __fpregs[4];
# endif
} __jmp_buf[1];

#endif

#endif /* __S390_SETJMP_H__ */