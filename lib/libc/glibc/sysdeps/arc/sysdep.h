/* Assembler macros for ARC.
   Copyright (C) 2020-2025 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License as
   published by the Free Software Foundation; either version 2.1 of the
   License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#include <sysdeps/generic/sysdep.h>

#ifdef	__ASSEMBLER__

/* Syntactic details of assembler.
   ; is not newline but comment, # is also for comment.  */
# define ASM_SIZE_DIRECTIVE(name) .size name,.-name

# define ENTRY(name)						\
	.align 4				ASM_LINE_SEP	\
	.globl C_SYMBOL_NAME(name)		ASM_LINE_SEP	\
	.type C_SYMBOL_NAME(name),%function	ASM_LINE_SEP	\
	C_LABEL(name)				ASM_LINE_SEP	\
	cfi_startproc				ASM_LINE_SEP	\
	CALL_MCOUNT

# undef  END
# define END(name)						\
	cfi_endproc				ASM_LINE_SEP	\
	ASM_SIZE_DIRECTIVE(name)

# ifdef SHARED
#  define PLTJMP(_x)	_x##@plt
# else
#  define PLTJMP(_x)	_x
# endif

# define L(label) .L##label

# define CALL_MCOUNT		/* Do nothing for now.  */

# define STR(reg, rbase, off)	st  reg, [rbase, off * 4]
# define LDR(reg, rbase, off)	ld  reg, [rbase, off * 4]

#endif	/* __ASSEMBLER__ */
