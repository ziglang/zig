/* Assembler macros for C-SKY.
   Copyright (C) 2018-2025 Free Software Foundation, Inc.
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

#include <sysdeps/generic/sysdep.h>
#include <features.h>

#ifdef __ASSEMBLER__

# define ASM_SIZE_DIRECTIVE(name) .size name,.-name

/* Define an entry point visible from C.  */
# define ENTRY(name)		\
	.globl name;		\
	.type name,@function;	\
	.align 4;		\
	name##:;		\
	cfi_startproc;		\
	CALL_MCOUNT

# undef  END
# define END(name)		\
	cfi_endproc;		\
	ASM_SIZE_DIRECTIVE(name)

/* If compiled for profiling, call `mcount' at the start of each function.  */
# ifdef PROF
#  ifdef __PIC__
#   define CALL_MCOUNT				\
	subi	sp, 4;				\
	stw	lr, (sp, 0);			\
	grs	t0, .Lgetpc;			\
.Lgetpc:					\
	lrw	gb, .Lgetpc@GOTPC;		\
	addu	gb, t0;				\
	lrw	t1, _mcount@PLT;		\
	ldr.w	t0, (gb, t1 << 0);		\
	jmp	t0;
#  else
#   define CALL_MCOUNT				\
	subi	sp, 4;				\
	stw	lr, (sp, 0);			\
	jbsr	_mcount;
#  endif
# else
#  define CALL_MCOUNT	/* Do nothing.  */
# endif

# if defined (__CK860__)
/* Instruction fetch will be faster when the label is 16 bytes aligned.
   Filling with nop instruction to avoid extra jump.  */
#  define LABLE_ALIGN	\
	.balignw 16, 0x6c03

#  define PRE_BNEZAD(R)

#  define BNEZAD(R, L)	\
	bnezad	R, L
# else
#  define LABLE_ALIGN	\
	.balignw 8, 0x6c03

#  define PRE_BNEZAD(R)	\
	subi	R, 1

#  define BNEZAD(R, L)	\
	bnez	R, L
# endif

#endif
