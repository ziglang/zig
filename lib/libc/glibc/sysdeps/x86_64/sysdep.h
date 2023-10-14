/* Assembler macros for x86-64.
   Copyright (C) 2001-2023 Free Software Foundation, Inc.
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

#ifndef _X86_64_SYSDEP_H
#define _X86_64_SYSDEP_H 1

#include <sysdeps/x86/sysdep.h>
#ifdef __ASSEMBLER__
# define LP_SIZE 8
#else
# define LP_SIZE "8"
#endif

#ifdef	__ASSEMBLER__

/* Syntactic details of assembler.  */

/* This macro is for setting proper CFI with DW_CFA_expression describing
   the register as saved relative to %rsp instead of relative to the CFA.
   Expression is DW_OP_drop, DW_OP_breg7 (%rsp is register 7), sleb128 offset
   from %rsp.  */
#define cfi_offset_rel_rsp(regn, off)	.cfi_escape 0x10, regn, 0x4, 0x13, \
					0x77, off & 0x7F | 0x80, off >> 7

/* If compiled for profiling, call `mcount' at the start of each function.  */
#ifdef	PROF
/* The mcount code relies on a normal frame pointer being on the stack
   to locate our caller, so push one just for its benefit.  */
#define CALL_MCOUNT                                                          \
  pushq %rbp;                                                                \
  cfi_adjust_cfa_offset(8);                                                  \
  movq %rsp, %rbp;                                                           \
  cfi_def_cfa_register(%rbp);                                                \
  call JUMPTARGET(mcount);                                                   \
  popq %rbp;                                                                 \
  cfi_def_cfa(rsp,8);
#else
#define CALL_MCOUNT		/* Do nothing.  */
#endif

#define	PSEUDO(name, syscall_name, args)				      \
lose:									      \
  jmp JUMPTARGET(syscall_error)						      \
  .globl syscall_error;							      \
  ENTRY (name)								      \
  DO_CALL (syscall_name, args);						      \
  jb lose

#undef JUMPTARGET
#ifdef SHARED
# ifdef BIND_NOW
#  define JUMPTARGET(name)	*name##@GOTPCREL(%rip)
# else
#  define JUMPTARGET(name)	name##@PLT
# endif
#else
/* For static archives, branch to target directly.  */
# define JUMPTARGET(name)	name
#endif

/* Instruction to operate on long and pointer.  */
#define LP_OP(insn) insn##q

/* Assembler address directive. */
#define ASM_ADDR .quad

/* Registers to hold long and pointer.  */
#define RAX_LP	rax
#define RBP_LP	rbp
#define RBX_LP	rbx
#define RCX_LP	rcx
#define RDI_LP	rdi
#define RDX_LP	rdx
#define RSI_LP	rsi
#define RSP_LP	rsp
#define R8_LP	r8
#define R9_LP	r9
#define R10_LP	r10
#define R11_LP	r11
#define R12_LP	r12
#define R13_LP	r13
#define R14_LP	r14
#define R15_LP	r15

/* Zero upper vector registers and return with xtest.  NB: Use VZEROALL
   to avoid RTM abort triggered by VZEROUPPER inside transactionally.  */
#define ZERO_UPPER_VEC_REGISTERS_RETURN_XTEST \
	xtest;							\
	jnz	1f;						\
	vzeroupper;						\
	ret;							\
1:								\
	vzeroall;						\
	ret

/* Can be used to replace vzeroupper that is not directly before a
   return.  This is useful when hoisting a vzeroupper from multiple
   return paths to decrease the total number of vzerouppers and code
   size.  */
#define COND_VZEROUPPER_XTEST							\
    xtest;							\
    jz 1f;							\
    vzeroall;							\
    jmp 2f;							\
1:							\
    vzeroupper;							\
2:

/* In RTM define this as COND_VZEROUPPER_XTEST.  */
#ifndef COND_VZEROUPPER
# define COND_VZEROUPPER vzeroupper
#endif

/* Zero upper vector registers and return.  */
#ifndef ZERO_UPPER_VEC_REGISTERS_RETURN
# define ZERO_UPPER_VEC_REGISTERS_RETURN \
	VZEROUPPER;						\
	ret
#endif

#ifndef VZEROUPPER_RETURN
# define VZEROUPPER_RETURN	VZEROUPPER; ret
#endif

#else	/* __ASSEMBLER__ */

/* Instruction to operate on long and pointer.  */
#define LP_OP(insn) #insn "q"

/* Assembler address directive. */
#define ASM_ADDR ".quad"

/* Registers to hold long and pointer.  */
#define RAX_LP	"rax"
#define RBP_LP	"rbp"
#define RBX_LP	"rbx"
#define RCX_LP	"rcx"
#define RDI_LP	"rdi"
#define RDX_LP	"rdx"
#define RSI_LP	"rsi"
#define RSP_LP	"rsp"
#define R8_LP	"r8"
#define R9_LP	"r9"
#define R10_LP	"r10"
#define R11_LP	"r11"
#define R12_LP	"r12"
#define R13_LP	"r13"
#define R14_LP	"r14"
#define R15_LP	"r15"

#endif	/* __ASSEMBLER__ */

#endif	/* _X86_64_SYSDEP_H */
