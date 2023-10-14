/* Copyright (C) 2000-2023 Free Software Foundation, Inc.
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

#include <sysdeps/generic/sysdep.h>

#ifdef __ASSEMBLER__

/* Macros to help writing .prologue directives in assembly code.  */
#define ASM_UNW_PRLG_RP			0x8
#define ASM_UNW_PRLG_PFS		0x4
#define ASM_UNW_PRLG_PSP		0x2
#define ASM_UNW_PRLG_PR			0x1
#define ASM_UNW_PRLG_GRSAVE(ninputs)	(32+(ninputs))

#define ENTRY(name)				\
	.text;					\
	.align 32;				\
	.proc C_SYMBOL_NAME(name);		\
	.global C_SYMBOL_NAME(name);		\
	C_LABEL(name)				\
	CALL_MCOUNT

#define LOCAL_ENTRY(name)			\
	.text;					\
	.align 32;				\
	.proc C_SYMBOL_NAME(name);		\
	C_LABEL(name)				\
	CALL_MCOUNT

#define LEAF(name)				\
  .text;					\
  .align 32;					\
  .proc C_SYMBOL_NAME(name);			\
  .global name;					\
  C_LABEL(name)

#define LOCAL_LEAF(name)			\
  .text;					\
  .align 32;					\
  .proc C_SYMBOL_NAME(name);			\
  C_LABEL(name)

/* Mark the end of function SYM.  */
#undef END
#define END(sym)	.endp C_SYMBOL_NAME(sym)

#endif /* ASSEMBLER */
