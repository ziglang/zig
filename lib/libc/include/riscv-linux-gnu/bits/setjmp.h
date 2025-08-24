/* Define the machine-dependent type `jmp_buf'.  RISC-V version.
   Copyright (C) 2011-2025 Free Software Foundation, Inc.
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

#ifndef _RISCV_BITS_SETJMP_H
#define _RISCV_BITS_SETJMP_H

typedef struct __jmp_buf_internal_tag
  {
    /* Program counter.  */
    long int __pc;
    /* Callee-saved registers.  */
    long int __regs[12];
    /* Stack pointer.  */
    long int __sp;

    /* Callee-saved floating point registers.  */
#if defined __riscv_float_abi_double
   double __fpregs[12];
#elif !defined __riscv_float_abi_soft
# error unsupported FLEN
#endif
  } __jmp_buf[1];

#endif /* _RISCV_BITS_SETJMP_H */