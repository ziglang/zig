/* Assembler macros for i386.
   Copyright (C) 1991-2021 Free Software Foundation, Inc.
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

#include <sysdeps/x86/sysdep.h>

/* It is desirable that the names of PIC thunks match those used by
   GCC so that multiple copies are eliminated by the linker.  Because
   GCC 4.6 and earlier use __i686 in the names, it is necessary to
   override that predefined macro.  */
#if defined __i686 && defined __ASSEMBLER__
#undef __i686
#define __i686 __i686
#endif

#ifdef	__ASSEMBLER__
# define GET_PC_THUNK(reg) __x86.get_pc_thunk.reg
#else
# define GET_PC_THUNK_STR(reg) "__x86.get_pc_thunk." #reg
#endif

#ifdef	__ASSEMBLER__

/* Syntactic details of assembler.  */

/* If compiled for profiling, call `mcount' at the start of each function.  */
#ifdef	PROF
/* The mcount code relies on a normal frame pointer being on the stack
   to locate our caller, so push one just for its benefit.  */
#define CALL_MCOUNT \
  pushl %ebp; cfi_adjust_cfa_offset (4); movl %esp, %ebp; \
  cfi_def_cfa_register (ebp); call JUMPTARGET(mcount); \
  popl %ebp; cfi_def_cfa (esp, 4);
#else
#define CALL_MCOUNT		/* Do nothing.  */
#endif

#define	PSEUDO(name, syscall_name, args)				      \
  .globl syscall_error;							      \
lose: SYSCALL_PIC_SETUP							      \
  jmp JUMPTARGET(syscall_error);					      \
  ENTRY (name)								      \
  DO_CALL (syscall_name, args);						      \
  jb lose

# define SETUP_PIC_REG(reg) \
  .ifndef GET_PC_THUNK(reg);						      \
  .section .text.GET_PC_THUNK(reg),"axG",@progbits,GET_PC_THUNK(reg),comdat;  \
  .globl GET_PC_THUNK(reg);						      \
  .hidden GET_PC_THUNK(reg);						      \
  .p2align 4;								      \
  .type GET_PC_THUNK(reg),@function;					      \
GET_PC_THUNK(reg):							      \
  movl (%esp), %e##reg;							      \
  ret;									      \
  .size GET_PC_THUNK(reg), . - GET_PC_THUNK(reg);			      \
  .previous;								      \
  .endif;								      \
  call GET_PC_THUNK(reg)

# define LOAD_PIC_REG(reg) \
  SETUP_PIC_REG(reg); addl $_GLOBAL_OFFSET_TABLE_, %e##reg

#undef JUMPTARGET
#ifdef PIC
#define JUMPTARGET(name)	name##@PLT
#define SYSCALL_PIC_SETUP \
    pushl %ebx;								      \
    cfi_adjust_cfa_offset (4);						      \
    call 0f;								      \
0:  popl %ebx;								      \
    cfi_adjust_cfa_offset (-4);						      \
    addl $_GLOBAL_OFFSET_TABLE_+[.-0b], %ebx;

#else
#define JUMPTARGET(name)	name
#define SYSCALL_PIC_SETUP	/* Nothing.  */
#endif

#else /* __ASSEMBLER__ */

# define SETUP_PIC_REG_STR(reg)						\
  ".ifndef " GET_PC_THUNK_STR (reg) "\n"				\
  ".section .text." GET_PC_THUNK_STR (reg) ",\"axG\",@progbits,"	\
    GET_PC_THUNK_STR (reg) ",comdat\n"					\
  ".globl " GET_PC_THUNK_STR (reg) "\n"					\
  ".hidden " GET_PC_THUNK_STR (reg) "\n"				\
  ".p2align 4\n"							\
  ".type " GET_PC_THUNK_STR (reg) ",@function\n"			\
GET_PC_THUNK_STR (reg) ":"						\
  "movl (%%esp), %%e" #reg "\n"						\
  "ret\n"								\
  ".size " GET_PC_THUNK_STR (reg) ", . - " GET_PC_THUNK_STR (reg) "\n"	\
  ".previous\n"								\
  ".endif\n"								\
  "call " GET_PC_THUNK_STR (reg)

# define LOAD_PIC_REG_STR(reg) \
  SETUP_PIC_REG_STR (reg) "\naddl $_GLOBAL_OFFSET_TABLE_, %%e" #reg

#endif	/* __ASSEMBLER__ */
