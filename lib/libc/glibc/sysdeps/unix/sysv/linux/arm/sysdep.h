/* Copyright (C) 1992-2021 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper, <drepper@gnu.ai.mit.edu>, August 1995.
   ARM changes by Philip Blundell, <pjb27@cam.ac.uk>, May 1997.

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

#ifndef _LINUX_ARM_SYSDEP_H
#define _LINUX_ARM_SYSDEP_H 1

/* There is some commonality.  */
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/arm/sysdep.h>

/* Defines RTLD_PRIVATE_ERRNO and USE_DL_SYSINFO.  */
#include <dl-sysdep.h>

#include <tls.h>

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)	(__NR_##syscall_name)

#include <bits/hwcap.h>

#ifdef __ASSEMBLER__

#ifndef ARCH_HAS_HARD_TP
/* Internal macro calling the linux kernel kuser_get_tls helper.
   Note that in thumb mode, a constant pool break is often out of range, so
   we always expand the constant inline.  */
# ifdef __thumb2__
#  define GET_TLS_BODY			\
	movw	r0, #0x0fe0;		\
	movt	r0, #0xffff;		\
	blx	r0
# else
#  define GET_TLS_BODY \
	mov	r0, #0xffff0fff;	/* Point to the high page.  */	\
	mov	lr, pc;			/* Save our return address.  */	\
	sub	pc, r0, #31		/* Jump to the TLS entry.  */
# endif

/* Helper to get the TLS base pointer.  Save LR in TMP, return in R0,
   and no other registers clobbered.  TMP may be LR itself to indicate
   that no save is necessary.  */
# undef GET_TLS
# define GET_TLS(TMP)			\
  .ifnc TMP, lr;			\
	mov	TMP, lr;		\
	cfi_register (lr, TMP);		\
	GET_TLS_BODY;			\
	mov	lr, TMP;		\
	cfi_restore (lr);		\
  .else;				\
	GET_TLS_BODY;			\
  .endif
#endif /* ARCH_HAS_HARD_TP */

/* Linux uses a negative return value to indicate syscall errors,
   unlike most Unices, which use the condition codes' carry flag.

   Since version 2.1 the return value of a system call might be
   negative even if the call succeeded.  E.g., the `lseek' system call
   might return a large offset.  Therefore we must not anymore test
   for < 0, but test for a real error by making sure the value in R0
   is a real error number.  Linus said he will make sure the no syscall
   returns a value in -1 .. -4095 as a valid result so we can safely
   test with -4095.  */

#undef	PSEUDO
#define	PSEUDO(name, syscall_name, args)		\
	.text;						\
  ENTRY (name);						\
	DO_CALL (syscall_name, args);			\
	cmn	r0, $4096;

#define PSEUDO_RET					\
	it	cc;					\
	RETINSTR(cc, lr);				\
	b	PLTJMP(SYSCALL_ERROR)
#undef ret
#define ret PSEUDO_RET

#undef	PSEUDO_END
#define	PSEUDO_END(name)				\
	SYSCALL_ERROR_HANDLER;				\
  END (name)

#undef	PSEUDO_NOERRNO
#define	PSEUDO_NOERRNO(name, syscall_name, args)	\
	.text;						\
  ENTRY (name);						\
	DO_CALL (syscall_name, args);

#define PSEUDO_RET_NOERRNO				\
	DO_RET (lr);

#undef ret_NOERRNO
#define ret_NOERRNO PSEUDO_RET_NOERRNO

#undef	PSEUDO_END_NOERRNO
#define	PSEUDO_END_NOERRNO(name)			\
  END (name)

/* The function has to return the error code.  */
#undef	PSEUDO_ERRVAL
#define	PSEUDO_ERRVAL(name, syscall_name, args)		\
	.text;						\
  ENTRY (name)						\
	DO_CALL (syscall_name, args);			\
	rsb	r0, r0, #0

#undef	PSEUDO_END_ERRVAL
#define	PSEUDO_END_ERRVAL(name)				\
  END (name)

#define ret_ERRVAL PSEUDO_RET_NOERRNO

#if !IS_IN (libc)
# define SYSCALL_ERROR __local_syscall_error
# if RTLD_PRIVATE_ERRNO
#  define SYSCALL_ERROR_HANDLER					\
__local_syscall_error:						\
	rsb	r0, r0, #0;					\
	LDST_PCREL(str, r0, r1, C_SYMBOL_NAME(rtld_errno));	\
	mvn	r0, #0;						\
	DO_RET(lr)
# else
#  if defined(__ARM_ARCH_4T__) && defined(__THUMB_INTERWORK__)
#   define POP_PC \
  pop { lr }; \
  cfi_adjust_cfa_offset (-4); \
  cfi_restore (lr); \
  bx lr
#  else
#   define POP_PC  pop { pc }
#  endif
#  define SYSCALL_ERROR_HANDLER					\
__local_syscall_error:						\
	push	{ lr };						\
	cfi_adjust_cfa_offset (4);				\
	cfi_rel_offset (lr, 0);					\
	push	{ r0 };	    					\
	cfi_adjust_cfa_offset (4);				\
	bl	PLTJMP(C_SYMBOL_NAME(__errno_location)); 	\
	pop	{ r1 };						\
	cfi_adjust_cfa_offset (-4);				\
	rsb	r1, r1, #0;					\
	str	r1, [r0];					\
	mvn	r0, #0;						\
	POP_PC;
# endif
#else
# define SYSCALL_ERROR_HANDLER	/* Nothing here; code in sysdep.S is used.  */
# define SYSCALL_ERROR __syscall_error
#endif

/* The ARM EABI user interface passes the syscall number in r7, instead
   of in the swi.  This is more efficient, because the kernel does not need
   to fetch the swi from memory to find out the number; which can be painful
   with separate I-cache and D-cache.  Make sure to use 0 for the SWI
   argument; otherwise the (optional) compatibility code for APCS binaries
   may be invoked.  */

/* Linux takes system call args in registers:
	arg 1		r0
	arg 2		r1
	arg 3		r2
	arg 4		r3
	arg 5		r4	(this is different from the APCS convention)
	arg 6		r5
	arg 7		r6

   The compiler is going to form a call by coming here, through PSEUDO, with
   arguments
	syscall number	in the DO_CALL macro
	arg 1		r0
	arg 2		r1
	arg 3		r2
	arg 4		r3
	arg 5		[sp]
	arg 6		[sp+4]
	arg 7		[sp+8]

   We need to shuffle values between R4..R6 and the stack so that the
   caller's v1..v3 and stack frame are not corrupted, and the kernel
   sees the right arguments.

*/

/* We must save and restore r7 (call-saved) for the syscall number.
   We never make function calls from inside here (only potentially
   signal handlers), so we do not bother with doubleword alignment.

   Just like the APCS syscall convention, the EABI syscall convention uses
   r0 through r6 for up to seven syscall arguments.  None are ever passed to
   the kernel on the stack, although incoming arguments are on the stack for
   syscalls with five or more arguments.

   The assembler will convert the literal pool load to a move for most
   syscalls.  */

#undef	DO_CALL
#define DO_CALL(syscall_name, args)			\
	DOARGS_##args;					\
	ldr	r7, =SYS_ify (syscall_name);		\
	swi	0x0;					\
	UNDOARGS_##args

#undef  DOARGS_0
#define DOARGS_0					\
	.fnstart;					\
	push	{ r7 };					\
	cfi_adjust_cfa_offset (4);			\
	cfi_rel_offset (r7, 0);				\
	.save	{ r7 }
#undef  DOARGS_1
#define DOARGS_1 DOARGS_0
#undef  DOARGS_2
#define DOARGS_2 DOARGS_0
#undef  DOARGS_3
#define DOARGS_3 DOARGS_0
#undef  DOARGS_4
#define DOARGS_4 DOARGS_0
#undef  DOARGS_5
#define DOARGS_5					\
	.fnstart;					\
	push	{r4, r7};				\
	cfi_adjust_cfa_offset (8);			\
	cfi_rel_offset (r4, 0);				\
	cfi_rel_offset (r7, 4);				\
	.save	{ r4, r7 };				\
	ldr	r4, [sp, #8]
#undef  DOARGS_6
#define DOARGS_6					\
	.fnstart;					\
	mov	ip, sp;					\
	push	{r4, r5, r7};				\
	cfi_adjust_cfa_offset (12);			\
	cfi_rel_offset (r4, 0);				\
	cfi_rel_offset (r5, 4);				\
	cfi_rel_offset (r7, 8);				\
	.save	{ r4, r5, r7 };				\
	ldmia	ip, {r4, r5}
#undef  DOARGS_7
#define DOARGS_7					\
	.fnstart;					\
	mov	ip, sp;					\
	push	{r4, r5, r6, r7};			\
	cfi_adjust_cfa_offset (16);			\
	cfi_rel_offset (r4, 0);				\
	cfi_rel_offset (r5, 4);				\
	cfi_rel_offset (r6, 8);				\
	cfi_rel_offset (r7, 12);			\
	.save	{ r4, r5, r6, r7 };			\
	ldmia	ip, {r4, r5, r6}

#undef  UNDOARGS_0
#define UNDOARGS_0					\
	pop	{r7};					\
	cfi_adjust_cfa_offset (-4);			\
	cfi_restore (r7);				\
	.fnend
#undef  UNDOARGS_1
#define UNDOARGS_1 UNDOARGS_0
#undef  UNDOARGS_2
#define UNDOARGS_2 UNDOARGS_0
#undef  UNDOARGS_3
#define UNDOARGS_3 UNDOARGS_0
#undef  UNDOARGS_4
#define UNDOARGS_4 UNDOARGS_0
#undef  UNDOARGS_5
#define UNDOARGS_5					\
	pop	{r4, r7};				\
	cfi_adjust_cfa_offset (-8);			\
	cfi_restore (r4);				\
	cfi_restore (r7);				\
	.fnend
#undef  UNDOARGS_6
#define UNDOARGS_6					\
	pop	{r4, r5, r7};				\
	cfi_adjust_cfa_offset (-12);			\
	cfi_restore (r4);				\
	cfi_restore (r5);				\
	cfi_restore (r7);				\
	.fnend
#undef  UNDOARGS_7
#define UNDOARGS_7					\
	pop	{r4, r5, r6, r7};			\
	cfi_adjust_cfa_offset (-16);			\
	cfi_restore (r4);				\
	cfi_restore (r5);				\
	cfi_restore (r6);				\
	cfi_restore (r7);				\
	.fnend

#else /* not __ASSEMBLER__ */

#if defined(__thumb__)
/* We can not expose the use of r7 to the compiler.  GCC (as
   of 4.5) uses r7 as the hard frame pointer for Thumb - although
   for Thumb-2 it isn't obviously a better choice than r11.
   And GCC does not support asms that conflict with the frame
   pointer.

   This would be easier if syscall numbers never exceeded 255,
   but they do.  For the moment the LOAD_ARGS_7 is sacrificed.
   We can't use push/pop inside the asm because that breaks
   unwinding (i.e. thread cancellation) for this frame.  We can't
   locally save and restore r7, because we do not know if this
   function uses r7 or if it is our caller's r7; if it is our caller's,
   then unwinding will fail higher up the stack.  So we move the
   syscall out of line and provide its own unwind information.  */
# undef INTERNAL_SYSCALL_RAW
# define INTERNAL_SYSCALL_RAW(name, nr, args...)		\
  ({								\
      register int _a1 asm ("a1");				\
      int _nametmp = name;					\
      LOAD_ARGS_##nr (args)					\
      register int _name asm ("ip") = _nametmp;			\
      asm volatile ("bl      __libc_do_syscall"			\
                    : "=r" (_a1)				\
                    : "r" (_name) ASM_ARGS_##nr			\
                    : "memory", "lr");				\
      _a1; })
#else /* ARM */
# undef INTERNAL_SYSCALL_RAW
# define INTERNAL_SYSCALL_RAW(name, nr, args...)		\
  ({								\
       register int _a1 asm ("r0"), _nr asm ("r7");		\
       LOAD_ARGS_##nr (args)					\
       _nr = name;						\
       asm volatile ("swi	0x0	@ syscall " #name	\
		     : "=r" (_a1)				\
		     : "r" (_nr) ASM_ARGS_##nr			\
		     : "memory");				\
       _a1; })
#endif

#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL(name, nr, args...)			\
	INTERNAL_SYSCALL_RAW(SYS_ify(name), nr, args)

#define VDSO_NAME  "LINUX_2.6"
#define VDSO_HASH  61765110

/* List of system calls which are supported as vsyscalls.  */
#define HAVE_CLOCK_GETTIME_VSYSCALL	"__vdso_clock_gettime"
#define HAVE_CLOCK_GETTIME64_VSYSCALL	"__vdso_clock_gettime64"
#define HAVE_GETTIMEOFDAY_VSYSCALL	"__vdso_gettimeofday"

#define LOAD_ARGS_0()
#define ASM_ARGS_0
#define LOAD_ARGS_1(a1)				\
  int _a1tmp = (int) (a1);			\
  LOAD_ARGS_0 ()				\
  _a1 = _a1tmp;
#define ASM_ARGS_1	ASM_ARGS_0, "r" (_a1)
#define LOAD_ARGS_2(a1, a2)			\
  int _a2tmp = (int) (a2);			\
  LOAD_ARGS_1 (a1)				\
  register int _a2 asm ("a2") = _a2tmp;
#define ASM_ARGS_2	ASM_ARGS_1, "r" (_a2)
#define LOAD_ARGS_3(a1, a2, a3)			\
  int _a3tmp = (int) (a3);			\
  LOAD_ARGS_2 (a1, a2)				\
  register int _a3 asm ("a3") = _a3tmp;
#define ASM_ARGS_3	ASM_ARGS_2, "r" (_a3)
#define LOAD_ARGS_4(a1, a2, a3, a4)		\
  int _a4tmp = (int) (a4);			\
  LOAD_ARGS_3 (a1, a2, a3)			\
  register int _a4 asm ("a4") = _a4tmp;
#define ASM_ARGS_4	ASM_ARGS_3, "r" (_a4)
#define LOAD_ARGS_5(a1, a2, a3, a4, a5)		\
  int _v1tmp = (int) (a5);			\
  LOAD_ARGS_4 (a1, a2, a3, a4)			\
  register int _v1 asm ("v1") = _v1tmp;
#define ASM_ARGS_5	ASM_ARGS_4, "r" (_v1)
#define LOAD_ARGS_6(a1, a2, a3, a4, a5, a6)	\
  int _v2tmp = (int) (a6);			\
  LOAD_ARGS_5 (a1, a2, a3, a4, a5)		\
  register int _v2 asm ("v2") = _v2tmp;
#define ASM_ARGS_6	ASM_ARGS_5, "r" (_v2)
#ifndef __thumb__
# define LOAD_ARGS_7(a1, a2, a3, a4, a5, a6, a7)	\
  int _v3tmp = (int) (a7);				\
  LOAD_ARGS_6 (a1, a2, a3, a4, a5, a6)			\
  register int _v3 asm ("v3") = _v3tmp;
# define ASM_ARGS_7	ASM_ARGS_6, "r" (_v3)
#endif

/* For EABI, non-constant syscalls are actually pretty easy...  */
#undef INTERNAL_SYSCALL_NCS
#define INTERNAL_SYSCALL_NCS(number, nr, args...)              \
  INTERNAL_SYSCALL_RAW (number, nr, args)

#define SINGLE_THREAD_BY_GLOBAL	1

#endif	/* __ASSEMBLER__ */

#endif /* linux/arm/sysdep.h */
