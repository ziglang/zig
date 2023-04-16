/* Miscellaneous macros.
   Copyright (C) 2000-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_ASM_H
#define _SYS_ASM_H

/* Macros to handle different pointer/register sizes for 32/64-bit code.  */
#if __riscv_xlen == 64
# define PTRLOG 3
# define SZREG  8
# define REG_S sd
# define REG_L ld
#elif __riscv_xlen == 32
# define PTRLOG 2
# define SZREG  4
# define REG_S sw
# define REG_L lw
#else
# error __riscv_xlen must equal 32 or 64
#endif

#if !defined __riscv_float_abi_soft
/* For ABI uniformity, reserve 8 bytes for floats, even if double-precision
   floating-point is not supported in hardware.  */
# if defined __riscv_float_abi_double
#  define FREG_L fld
#  define FREG_S fsd
#  define SZFREG 8
# else
#  error unsupported FLEN
# endif
#endif

/* Declare leaf routine.  */
#define	LEAF(symbol)				\
		.globl	symbol;			\
		.align	2;			\
		.type	symbol,@function;	\
symbol:						\
		cfi_startproc;

/* Mark end of function.  */
#undef END
#define END(function)				\
		cfi_endproc;			\
		.size	function,.-function

/* Stack alignment.  */
#define ALMASK	~15

#endif /* sys/asm.h */