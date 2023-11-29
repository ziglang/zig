/* Assembler macros for Nios II.
   Copyright (C) 2015-2023 Free Software Foundation, Inc.
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

/* Syntactic details of assembler.  */

#define ASM_SIZE_DIRECTIVE(name) .size name,.-name

#define ENTRY(name)						 \
  .globl C_SYMBOL_NAME(name);					 \
  .type C_SYMBOL_NAME(name),%function;				 \
  C_LABEL(name)							 \
  cfi_startproc;						 \
  CALL_MCOUNT;

#undef  END
#define END(name)				\
  cfi_endproc;					\
  ASM_SIZE_DIRECTIVE(name)

#ifdef PROF

# ifdef __PIC__
#  define CALL_MCOUNT				\
  mov r8, ra;					\
  nextpc r2;					\
1:						\
  movhi r3, %hiadj(_gp_got - 1b);		\
  addi r3, r3, %lo(_gp_got - 1b);		\
  add r2, r2, r3;				\
  ldw r2, %call(_mcount)(r2);			\
  callr r2;					\
  mov ra, r8;					\
  ret;
# else
#  define CALL_MCOUNT				\
  mov r8, ra;					\
  call _mount;					\
  mov ra, r8;					\
  ret;
# endif

#else
# define CALL_MCOUNT		/* Do nothing.  */
#endif

#endif	/* __ASSEMBLER__ */
