/* Assembler macros for x86.
   Copyright (C) 2017-2025 Free Software Foundation, Inc.
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

#ifndef _X86_SYSDEP_H
#define _X86_SYSDEP_H 1

#include <sysdeps/generic/sysdep.h>

/* The extended state feature IDs in the state component bitmap.  */
#define X86_XSTATE_X87_ID	0
#define X86_XSTATE_SSE_ID	1
#define X86_XSTATE_AVX_ID	2
#define X86_XSTATE_BNDREGS_ID	3
#define X86_XSTATE_BNDCFG_ID	4
#define X86_XSTATE_K_ID		5
#define X86_XSTATE_ZMM_H_ID	6
#define X86_XSTATE_ZMM_ID	7
#define X86_XSTATE_PKRU_ID	9
#define X86_XSTATE_TILECFG_ID	17
#define X86_XSTATE_TILEDATA_ID	18
#define X86_XSTATE_APX_F_ID	19

#ifdef __x86_64__
/* Offset for fxsave/xsave area used by _dl_runtime_resolve.  Also need
   space to preserve RCX, RDX, RSI, RDI, R8, R9 and RAX.  It must be
   aligned to 16 bytes for fxsave and 64 bytes for xsave.  It is non-zero
   because MOV, instead of PUSH, is used to save registers onto stack.

   +==================+<- stack frame start aligned at 8 or 16 bytes
   |                  |<- paddings for stack realignment of 64 bytes
   |------------------|<- xsave buffer end aligned at 64 bytes
   |                  |<-
   |                  |<-
   |                  |<-
   |------------------|<- xsave buffer start at STATE_SAVE_OFFSET(%rsp)
   |                  |<- 8-byte padding for 64-byte alignment
   |                  |<- R9
   |                  |<- R8
   |                  |<- RDI
   |                  |<- RSI
   |                  |<- RDX
   |                  |<- RCX
   |                  |<- RAX
   +==================+<- RSP aligned at 64 bytes

 */
# define STATE_SAVE_OFFSET (8 * 7 + 8)

/* _dl_tlsdesc_dynamic preserves RDI, RSI and RBX before realigning
   stack.  After realigning stack, it saves RCX, RDX, R8, R9, R10 and
   R11.  Allocate space for RDI, RSI and RBX to avoid clobbering saved
   RDI, RSI and RBX values on stack by xsave.

   +==================+<- stack frame start aligned at 8 or 16 bytes
   |                  |<- RDI saved in the red zone
   |                  |<- RSI saved in the red zone
   |                  |<- RBX saved in the red zone
   |                  |<- paddings for stack realignment of 64 bytes
   |------------------|<- xsave buffer end aligned at 64 bytes
   |                  |<-
   |                  |<-
   |                  |<-
   |------------------|<- xsave buffer start at STATE_SAVE_OFFSET(%rsp)
   |                  |<- 8-byte padding for 64-byte alignment
   |                  |<- 8-byte padding for 64-byte alignment
   |                  |<- R11
   |                  |<- R10
   |                  |<- R9
   |                  |<- R8
   |                  |<- RDX
   |                  |<- RCX
   +==================+<- RSP aligned at 64 bytes

   Define the total register save area size for all integer registers by
   adding 24 to STATE_SAVE_OFFSET since RDI, RSI and RBX are saved onto
   stack without adjusting stack pointer first, using the red-zone.  */
# define TLSDESC_CALL_REGISTER_SAVE_AREA (STATE_SAVE_OFFSET + 24)

/* Save SSE, AVX, AVX512, mask, bound and APX registers.  Bound and APX
   registers are mutually exclusive.  */
# define STATE_SAVE_MASK		\
  ((1 << X86_XSTATE_SSE_ID)		\
   | (1 << X86_XSTATE_AVX_ID)		\
   | (1 << X86_XSTATE_BNDREGS_ID)	\
   | (1 << X86_XSTATE_K_ID)		\
   | (1 << X86_XSTATE_ZMM_H_ID) 	\
   | (1 << X86_XSTATE_ZMM_ID)		\
   | (1 << X86_XSTATE_APX_F_ID))

/* AMX state mask.  */
# define AMX_STATE_SAVE_MASK		\
  ((1 << X86_XSTATE_TILECFG_ID) | (1 << X86_XSTATE_TILEDATA_ID))

/* States to be included in xsave_state_full_size.  */
# define FULL_STATE_SAVE_MASK		\
  (STATE_SAVE_MASK | AMX_STATE_SAVE_MASK)
#else
/* Offset for fxsave/xsave area used by _dl_tlsdesc_dynamic.  Since i386
   uses PUSH to save registers onto stack, use 0 here.  */
# define STATE_SAVE_OFFSET 0
# define TLSDESC_CALL_REGISTER_SAVE_AREA 0

/* Save SSE, AVX, AXV512, mask and bound registers.   */
# define STATE_SAVE_MASK		\
  ((1 << X86_XSTATE_SSE_ID)		\
   | (1 << X86_XSTATE_AVX_ID)		\
   | (1 << X86_XSTATE_BNDREGS_ID)	\
   | (1 << X86_XSTATE_K_ID)		\
   | (1 << X86_XSTATE_ZMM_H_ID))

/* States to be included in xsave_state_size.  */
# define FULL_STATE_SAVE_MASK		STATE_SAVE_MASK
#endif

/* States which should be saved for TLSDESC_CALL and TLS_DESC_CALL.
   Compiler assumes that all registers, including AMX and x87 FPU
   stack registers, are unchanged after CALL, except for EFLAGS and
   RAX/EAX.  */
#define TLSDESC_CALL_STATE_SAVE_MASK	\
  (FULL_STATE_SAVE_MASK | (1 << X86_XSTATE_X87_ID))

/* Constants for bits in __x86_string_control:  */

/* Avoid short distance REP MOVSB.  */
#define X86_STRING_CONTROL_AVOID_SHORT_DISTANCE_REP_MOVSB	(1 << 0)

#ifdef	__ASSEMBLER__

/* Syntactic details of assembler.  */

/* ELF uses byte-counts for .align, most others use log2 of count of bytes.  */
#define ALIGNARG(log2) 1<<log2
#define ASM_SIZE_DIRECTIVE(name) .size name,.-name;

/* Common entry 16 byte aligns.  */
#define ENTRY(name) ENTRY_P2ALIGN (name, 4)

#undef	END
#define END(name)							      \
  cfi_endproc;								      \
  ASM_SIZE_DIRECTIVE(name)

#define ENTRY_CHK(name) ENTRY (name)
#define END_CHK(name) END (name)

/* Since C identifiers are not normally prefixed with an underscore
   on this system, the asm identifier `syscall_error' intrudes on the
   C name space.  Make sure we use an innocuous name.  */
#define	syscall_error	__syscall_error
#define mcount		_mcount

#undef	PSEUDO_END
#define	PSEUDO_END(name)						      \
  END (name)

/* Local label name for asm code. */
#ifndef L
/* ELF-like local names start with `.L'.  */
# define LOCAL_LABEL(name) .L##name
# define L(name)	LOCAL_LABEL(name)
#endif

#define atom_text_section .section ".text.atom", "ax"

#endif	/* __ASSEMBLER__ */

#endif	/* _X86_SYSDEP_H */
