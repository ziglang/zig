/* Miscellaneous macros.
   Copyright (C) 2022-2025 Free Software Foundation, Inc.
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

#include <sys/regdef.h>
#include <sysdeps/generic/sysdep.h>

/* Macros to handle different pointer/register sizes for 32/64-bit code.  */
#define SZREG 8
#define SZFREG 8
#define SZVREG 16
#define SZXREG 32
#define REG_L ld.d
#define REG_S st.d
#define SRLI srli.d
#define SLLI slli.d
#define ADDI addi.d
#define ADD  add.d
#define SUB  sub.d
#define BSTRINS  bstrins.d
#define LI  li.d
#define FREG_L fld.d
#define FREG_S fst.d

/*  Declare leaf routine.
    The usage of macro LEAF/ENTRY is as follows:
    1. LEAF(fcn) -- the align value of fcn is .align 3 (default value)
    2. LEAF(fcn, 6) -- the align value of fcn is .align 6
*/
#define LEAF_IMPL(symbol, aln, ...)	\
	.text;				\
	.globl symbol;			\
	.align aln;			\
	.type symbol, @function;	\
symbol: \
	cfi_startproc;


#define LEAF(...) LEAF_IMPL(__VA_ARGS__, 3)
#define ENTRY(...) LEAF(__VA_ARGS__)

#define	LEAF_NO_ALIGN(symbol)		\
	.text;				\
	.globl	symbol;			\
	.type	symbol, @function;	\
symbol: \
	cfi_startproc;

#define ENTRY_NO_ALIGN(symbol) LEAF_NO_ALIGN(symbol)


/* Mark end of function.  */
#undef END
#define END(function) \
  cfi_endproc; \
  .size function, .- function;

/* Stack alignment.  */
#define ALMASK ~15

#endif /* sys/asm.h */