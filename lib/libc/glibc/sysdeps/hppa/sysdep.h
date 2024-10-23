/* Assembler macros for HP/PA.
   Copyright (C) 1999-2024 Free Software Foundation, Inc.
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

#undef ASM_LINE_SEP
#define ASM_LINE_SEP !

#ifdef	__ASSEMBLER__

/* Syntactic details of assembler.  */

#define ALIGNARG(log2) log2


/* Define an entry point visible from C.

   There is currently a bug in gdb which prevents us from specifying
   incomplete stabs information.  Fake some entries here which specify
   the current source file.  */
#define	ENTRY(name)							      \
  .SPACE $TEXT$							ASM_LINE_SEP  \
  .SUBSPA $CODE$,QUAD=0,ALIGN=8,ACCESS=44,CODE_ONLY		ASM_LINE_SEP  \
  .align ALIGNARG(4)						ASM_LINE_SEP  \
  .NSUBSPA $CODE$,QUAD=0,ALIGN=8,ACCESS=44,CODE_ONLY		ASM_LINE_SEP  \
  .EXPORT C_SYMBOL_NAME(name),ENTRY,PRIV_LEV=3,ARGW0=GR,RTNVAL=GR ASM_LINE_SEP\
  C_LABEL(name)								      \
  CALL_MCOUNT

#undef	END
#define END(name)							      \
  .PROCEND

/* GCC does everything for us. */
#ifdef	PROF
#define CALL_MCOUNT
#else
#define CALL_MCOUNT		/* Do nothing.  */
#endif

#define	PSEUDO(name, syscall_name, args)				      \
  ENTRY (name)								      \
  DO_CALL (syscall_name, args)

#undef	PSEUDO_END
#define	PSEUDO_END(name)						      \
  END (name)

#undef JUMPTARGET
#define JUMPTARGET(name)	name
#define SYSCALL_PIC_SETUP	/* Nothing.  */

/* Local label name for asm code. */
#ifndef L
#define L(name)		name
#endif

#endif	/* __ASSEMBLER__ */
