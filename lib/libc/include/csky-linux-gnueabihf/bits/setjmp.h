/* Define the machine-dependent type `jmp_buf'.  C-SKY version.
   Copyright (C) 2018-2021 Free Software Foundation, Inc.
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

#ifndef _CSKY_BITS_SETJMP_H
#define _CSKY_BITS_SETJMP_H 1

typedef struct __jmp_buf_str
  {
    /* Stack pointer.  */
    int __sp;
    int __lr;
    /* The actual core defines which registers should be saved.  The
       buffer contains 32 words, keep space for future growth.
       Callee-saved registers:
       r4 ~ r11, r16 ~ r17, r26 ~r31 for abiv2; r8 ~ r14 for abiv1.  */
    int __regs[32];
  } __jmp_buf[1];

#endif