/* Assembly macros for 32-bit PowerPC.
   Copyright (C) 1999-2025 Free Software Foundation, Inc.
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

#include <sysdeps/powerpc/sysdep.h>

#ifdef __ASSEMBLER__

/* If compiled for profiling, call `_mcount' at the start of each
   function.  */
#ifdef	PROF
/* The mcount code relies on a the return address being on the stack
   to locate our caller and so it can restore it; so store one just
   for its benefit.  */
# define CALL_MCOUNT							      \
  mflr  r0;								      \
  stw   r0,4(r1);							      \
  cfi_offset (lr, 4);							      \
  bl    JUMPTARGET(_mcount);
#else  /* PROF */
# define CALL_MCOUNT		/* Do nothing.  */
#endif /* PROF */

#define	ENTRY(name)							      \
  .globl C_SYMBOL_NAME(name);						      \
  .type C_SYMBOL_NAME(name),@function;					      \
  .align ALIGNARG(2);							      \
  C_LABEL(name)								      \
  cfi_startproc;							      \
  CALL_MCOUNT

#define ENTRY_TOCLESS(name) ENTRY(name)

/* helper macro for accessing the 32-bit powerpc GOT. */

#define	SETUP_GOT_ACCESS(regname,GOT_LABEL)				      \
	bcl	20,31,GOT_LABEL	;					      \
GOT_LABEL:			;					      \
	mflr	(regname)

#define EALIGN_W_0  /* No words to insert.  */
#define EALIGN_W_1  nop
#define EALIGN_W_2  nop;nop
#define EALIGN_W_3  nop;nop;nop
#define EALIGN_W_4  EALIGN_W_3;nop
#define EALIGN_W_5  EALIGN_W_4;nop
#define EALIGN_W_6  EALIGN_W_5;nop
#define EALIGN_W_7  EALIGN_W_6;nop

/* EALIGN is like ENTRY, but does alignment to 'words'*4 bytes
   past a 2^align boundary.  */
#ifdef PROF
# define EALIGN(name, alignt, words)					      \
  .globl C_SYMBOL_NAME(name);						      \
  .type C_SYMBOL_NAME(name),@function;					      \
  .align ALIGNARG(2);							      \
  C_LABEL(name)								      \
  cfi_startproc;							      \
  CALL_MCOUNT								      \
  b 0f;									      \
  .align ALIGNARG(alignt);						      \
  EALIGN_W_##words;							      \
  0:
#else /* PROF */
# define EALIGN(name, alignt, words)					      \
  .globl C_SYMBOL_NAME(name);						      \
  .type C_SYMBOL_NAME(name),@function;					      \
  .align ALIGNARG(alignt);						      \
  EALIGN_W_##words;							      \
  C_LABEL(name)								      \
  cfi_startproc;
#endif

#undef	END
#define END(name)							      \
  cfi_endproc;								      \
  ASM_SIZE_DIRECTIVE(name)

#define DO_CALL(syscall)						      \
    li 0,syscall;							      \
    DO_CALL_SC

#define DO_CALL_SC \
	sc

#undef JUMPTARGET
#ifdef PIC
# define JUMPTARGET(name) name##@plt
#else
# define JUMPTARGET(name) name
#endif

#define TAIL_CALL_NO_RETURN(__func) \
    b __func@local

#if defined SHARED && defined PIC && !defined NO_HIDDEN
# undef HIDDEN_JUMPTARGET
# define HIDDEN_JUMPTARGET(name) __GI_##name##@local
#endif

#define TAIL_CALL_SYSCALL_ERROR \
    b __syscall_error@local

#define PSEUDO(name, syscall_name, args)				      \
  .section ".text";							      \
  ENTRY (name)								      \
    DO_CALL (SYS_ify (syscall_name));

#define RET_SC \
    bnslr+;

#define PSEUDO_RET							      \
    RET_SC;								      \
    TAIL_CALL_SYSCALL_ERROR
#define ret PSEUDO_RET

#undef	PSEUDO_END
#define	PSEUDO_END(name)						      \
  END (name)

#define PSEUDO_NOERRNO(name, syscall_name, args)			      \
  .section ".text";							      \
  ENTRY (name)								      \
    DO_CALL (SYS_ify (syscall_name));

#define PSEUDO_RET_NOERRNO						      \
    blr
#define ret_NOERRNO PSEUDO_RET_NOERRNO

#undef	PSEUDO_END_NOERRNO
#define	PSEUDO_END_NOERRNO(name)					      \
  END (name)

#define PSEUDO_ERRVAL(name, syscall_name, args)				      \
  .section ".text";							      \
  ENTRY (name)								      \
    DO_CALL (SYS_ify (syscall_name));

#define PSEUDO_RET_ERRVAL						      \
    blr
#define ret_ERRVAL PSEUDO_RET_ERRVAL

#undef	PSEUDO_END_ERRVAL
#define	PSEUDO_END_ERRVAL(name)						      \
  END (name)

/* Local labels stripped out by the linker.  */
#undef L
#define L(x) .L##x

#define XGLUE(a,b) a##b
#define GLUE(a,b) XGLUE (a,b)
#define GENERATE_GOT_LABEL(name) GLUE (.got_label, name)

/* Label in text section.  */
#define C_TEXT(name) name

/* Read the value of member from rtld_global_ro.  */
#ifdef PIC
# ifdef SHARED
#  if IS_IN (rtld)
/* Inside ld.so we use the local alias to avoid runtime GOT
   relocations.  */
#   define __GLRO(rOUT, rGOT, member, offset)				\
	lwz     rOUT,_rtld_local_ro@got(rGOT);				\
	lwz     rOUT,offset(rOUT)
#  else
#   define __GLRO(rOUT, rGOT, member, offset)				\
	lwz     rOUT,_rtld_global_ro@got(rGOT);				\
	lwz     rOUT,offset(rOUT)
#  endif
# else
#  define __GLRO(rOUT, rGOT, member, offset)				\
	lwz     rOUT,member@got(rGOT);					\
	lwz     rOUT,0(rOUT)
# endif
#else
/* Position-dependent code does not require access to the GOT.  */
# define __GLRO(rOUT, rGOT, member, offset)				\
	lis     rOUT,(member)@ha;					\
	lwz     rOUT,(member)@l(rOUT)
#endif	/* PIC */

#endif	/* __ASSEMBLER__ */
