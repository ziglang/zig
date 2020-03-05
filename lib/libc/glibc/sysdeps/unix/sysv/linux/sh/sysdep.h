/* Copyright (C) 1992-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper, <drepper@gnu.ai.mit.edu>, August 1995.
   Changed by Kaz Kojima, <kkojima@rr.iij4u.or.jp>.

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

#ifndef _LINUX_SH_SYSDEP_H
#define _LINUX_SH_SYSDEP_H 1

/* There is some commonality.  */
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/sh/sysdep.h>
#include <tls.h>

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)	(__NR_##syscall_name)


#ifdef __ASSEMBLER__

/* Linux uses a negative return value to indicate syscall errors,
   unlike most Unices, which use the condition codes' carry flag.

   Since version 2.1 the return value of a system call might be
   negative even if the call succeeded.  E.g., the `lseek' system call
   might return a large offset.  Therefore we must not anymore test
   for < 0, but test for a real error by making sure the value in R0
   is a real error number.  Linus said he will make sure the no syscall
   returns a value in -1 .. -4095 as a valid result so we can savely
   test with -4095.  */

#define _IMM1 #-1
#define _IMM12 #-12
#undef	PSEUDO
#define	PSEUDO(name, syscall_name, args) \
 .text; \
 ENTRY (name); \
    DO_CALL (syscall_name, args); \
    mov r0,r1; \
    mov _IMM12,r2; \
    shad r2,r1; \
    not r1,r1; \
    tst r1,r1; \
    bf .Lpseudo_end; \
    SYSCALL_ERROR_HANDLER; \
 .Lpseudo_end:

#undef	PSEUDO_END
#define	PSEUDO_END(name) \
  END (name)

#undef	PSEUDO_NOERRNO
#define	PSEUDO_NOERRNO(name, syscall_name, args) \
 .text; \
 ENTRY (name); \
    DO_CALL (syscall_name, args)

#undef	PSEUDO_END_NOERRNO
#define	PSEUDO_END_NOERRNO(name) \
  END (name)

#define ret_NOERRNO ret

#define	PSEUDO_ERRVAL(name, syscall_name, args) \
 .text; \
 ENTRY (name); \
    DO_CALL (syscall_name, args);

#undef	PSEUDO_END_ERRVAL
#define	PSEUDO_END_ERRVAL(name) \
  END (name)

#define ret_ERRVAL ret

#ifndef PIC
# define SYSCALL_ERROR_HANDLER	\
	mov.l 0f,r1; \
	jmp @r1; \
	 mov r0,r4; \
	.align 2; \
     0: .long __syscall_error
#else
# if RTLD_PRIVATE_ERRNO
#  define SYSCALL_ERROR_HANDLER	\
	neg r0,r1; \
	mov r12,r2; \
	cfi_register (r12, r2); \
	mov.l 0f,r12; \
	mova 0f,r0; \
	add r0,r12; \
	mov.l 1f,r0; \
	mov.l r1,@(r0,r12); \
	mov r2,r12; \
	cfi_restore (r12); \
	bra .Lpseudo_end; \
	 mov _IMM1,r0; \
	.align 2; \
     0: .long _GLOBAL_OFFSET_TABLE_; \
     1: .long rtld_errno@GOTOFF

# elif defined _LIBC_REENTRANT

#  if IS_IN (libc)
#   define SYSCALL_ERROR_ERRNO __libc_errno
#  else
#   define SYSCALL_ERROR_ERRNO errno
#  endif
#  define SYSCALL_ERROR_HANDLER \
	neg r0,r1; \
	mov r12,r2; \
	cfi_register (r12, r2); \
	mov.l 0f,r12; \
	mova 0f,r0; \
	add r0,r12; \
	mov.l 1f,r0; \
	stc gbr, r4; \
	mov.l @(r0,r12),r0; \
	mov r2,r12; \
	cfi_restore (r12); \
	add r4,r0; \
	mov.l r1,@r0; \
	bra .Lpseudo_end; \
	 mov _IMM1,r0; \
	.align 2; \
     0: .long _GLOBAL_OFFSET_TABLE_; \
     1: .long SYSCALL_ERROR_ERRNO@GOTTPOFF
# else
/* Store (-r0) into errno through the GOT.  */
#  define SYSCALL_ERROR_HANDLER						      \
	neg r0,r1; \
	mov r12,r2; \
	cfi_register (r12, r2); \
	mov.l 0f,r12; \
	mova 0f,r0; \
	add r0,r12; \
	mov.l 1f,r0; \
	mov.l @(r0,r12),r0; \
	mov r2,r12; \
	cfi_restore (r12); \
	mov.l r1,@r0; \
	bra .Lpseudo_end; \
	 mov _IMM1,r0; \
	.align 2; \
     0: .long _GLOBAL_OFFSET_TABLE_; \
     1: .long errno@GOT
# endif	/* _LIBC_REENTRANT */
#endif	/* PIC */

# ifdef NEED_SYSCALL_INST_PAD
#  define SYSCALL_INST_PAD \
	or r0,r0; or r0,r0; or r0,r0; or r0,r0; or r0,r0
# else
#  define SYSCALL_INST_PAD
# endif

#define SYSCALL_INST0	trapa #0x10
#define SYSCALL_INST1	trapa #0x11
#define SYSCALL_INST2	trapa #0x12
#define SYSCALL_INST3	trapa #0x13
#define SYSCALL_INST4	trapa #0x14
#define SYSCALL_INST5	mov.l @(0,r15),r0; trapa #0x15
#define SYSCALL_INST6	mov.l @(0,r15),r0; mov.l @(4,r15),r1; trapa #0x16

#undef	DO_CALL
#define DO_CALL(syscall_name, args)	\
    mov.l 1f,r3;			\
    SYSCALL_INST##args;			\
    SYSCALL_INST_PAD;			\
    bra 2f;				\
     nop;				\
    .align 2;				\
 1: .long SYS_ify (syscall_name);	\
 2:

#else /* not __ASSEMBLER__ */

#define SYSCALL_INST_STR0	"trapa #0x10\n\t"
#define SYSCALL_INST_STR1	"trapa #0x11\n\t"
#define SYSCALL_INST_STR2	"trapa #0x12\n\t"
#define SYSCALL_INST_STR3	"trapa #0x13\n\t"
#define SYSCALL_INST_STR4	"trapa #0x14\n\t"
#define SYSCALL_INST_STR5	"trapa #0x15\n\t"
#define SYSCALL_INST_STR6	"trapa #0x16\n\t"

# ifdef NEED_SYSCALL_INST_PAD
#  define SYSCALL_INST_PAD "\
	or r0,r0; or r0,r0; or r0,r0; or r0,r0; or r0,r0"
# else
#  define SYSCALL_INST_PAD
# endif

#define ASMFMT_0
#define ASMFMT_1 \
	, "r" (r4)
#define ASMFMT_2 \
	, "r" (r4), "r" (r5)
#define ASMFMT_3 \
	, "r" (r4), "r" (r5), "r" (r6)
#define ASMFMT_4 \
	, "r" (r4), "r" (r5), "r" (r6), "r" (r7)
#define ASMFMT_5 \
	, "r" (r4), "r" (r5), "r" (r6), "r" (r7), "0" (r0)
#define ASMFMT_6 \
	, "r" (r4), "r" (r5), "r" (r6), "r" (r7), "0" (r0), "r" (r1)
#define ASMFMT_7 \
	, "r" (r4), "r" (r5), "r" (r6), "r" (r7), "0" (r0), "r" (r1), "r" (r2)

#define SUBSTITUTE_ARGS_0()
#define SUBSTITUTE_ARGS_1(arg1) \
	long int _arg1 = (long int) (arg1);				      \
	register long int r4 asm ("%r4") = (long int) (_arg1)
#define SUBSTITUTE_ARGS_2(arg1, arg2) \
	long int _arg1 = (long int) (arg1);				      \
	long int _arg2 = (long int) (arg2);				      \
	register long int r4 asm ("%r4") = (long int) (_arg1);		      \
	register long int r5 asm ("%r5") = (long int) (_arg2)
#define SUBSTITUTE_ARGS_3(arg1, arg2, arg3) \
	long int _arg1 = (long int) (arg1);				      \
	long int _arg2 = (long int) (arg2);				      \
	long int _arg3 = (long int) (arg3);				      \
	register long int r4 asm ("%r4") = (long int) (_arg1);		      \
	register long int r5 asm ("%r5") = (long int) (_arg2);		      \
	register long int r6 asm ("%r6") = (long int) (_arg3)
#define SUBSTITUTE_ARGS_4(arg1, arg2, arg3, arg4) \
	long int _arg1 = (long int) (arg1);				      \
	long int _arg2 = (long int) (arg2);				      \
	long int _arg3 = (long int) (arg3);				      \
	long int _arg4 = (long int) (arg4);				      \
	register long int r4 asm ("%r4") = (long int) (_arg1);		      \
	register long int r5 asm ("%r5") = (long int) (_arg2);		      \
	register long int r6 asm ("%r6") = (long int) (_arg3);		      \
	register long int r7 asm ("%r7") = (long int) (_arg4)
#define SUBSTITUTE_ARGS_5(arg1, arg2, arg3, arg4, arg5) \
	long int _arg1 = (long int) (arg1);				      \
	long int _arg2 = (long int) (arg2);				      \
	long int _arg3 = (long int) (arg3);				      \
	long int _arg4 = (long int) (arg4);				      \
	long int _arg5 = (long int) (arg5);				      \
	register long int r4 asm ("%r4") = (long int) (_arg1);		      \
	register long int r5 asm ("%r5") = (long int) (_arg2);		      \
	register long int r6 asm ("%r6") = (long int) (_arg3);		      \
	register long int r7 asm ("%r7") = (long int) (_arg4);		      \
	register long int r0 asm ("%r0") = (long int) (_arg5)
#define SUBSTITUTE_ARGS_6(arg1, arg2, arg3, arg4, arg5, arg6) \
	long int _arg1 = (long int) (arg1);				      \
	long int _arg2 = (long int) (arg2);				      \
	long int _arg3 = (long int) (arg3);				      \
	long int _arg4 = (long int) (arg4);				      \
	long int _arg5 = (long int) (arg5);				      \
	long int _arg6 = (long int) (arg6);				      \
	register long int r4 asm ("%r4") = (long int)(_arg1);		      \
	register long int r5 asm ("%r5") = (long int) (_arg2);		      \
	register long int r6 asm ("%r6") = (long int) (_arg3);		      \
	register long int r7 asm ("%r7") = (long int) (_arg4);		      \
	register long int r0 asm ("%r0") = (long int) (_arg5);		      \
	register long int r1 asm ("%r1") = (long int) (_arg6)
#define SUBSTITUTE_ARGS_7(arg1, arg2, arg3, arg4, arg5, arg6, arg7) \
	long int _arg1 = (long int) (arg1);				      \
	long int _arg2 = (long int) (arg2);				      \
	long int _arg3 = (long int) (arg3);				      \
	long int _arg4 = (long int) (arg4);				      \
	long int _arg5 = (long int) (arg5);				      \
	long int _arg6 = (long int) (arg6);				      \
	long int _arg7 = (long int) (arg7);				      \
	register long int r4 asm ("%r4") = (long int) (_arg1);		      \
	register long int r5 asm ("%r5") = (long int) (_arg2);		      \
	register long int r6 asm ("%r6") = (long int) (_arg3);		      \
	register long int r7 asm ("%r7") = (long int) (_arg4);		      \
	register long int r0 asm ("%r0") = (long int) (_arg5);		      \
	register long int r1 asm ("%r1") = (long int) (_arg6);		      \
	register long int r2 asm ("%r2") = (long int) (_arg7)

#undef INLINE_SYSCALL
#define INLINE_SYSCALL(name, nr, args...) \
  ({                                                                          \
    unsigned int resultvar = INTERNAL_SYSCALL (name, , nr, args);             \
    if (__builtin_expect (INTERNAL_SYSCALL_ERROR_P (resultvar, ), 0))         \
      {                                                                       \
	__set_errno (INTERNAL_SYSCALL_ERRNO (resultvar, ));                   \
	resultvar = 0xffffffff;                                               \
      }                                                                       \
    (int) resultvar; })

#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL(name, err, nr, args...) \
  ({									      \
    unsigned long int resultvar;					      \
    register long int r3 asm ("%r3") = SYS_ify (name);			      \
    SUBSTITUTE_ARGS_##nr(args);						      \
									      \
    asm volatile (SYSCALL_INST_STR##nr SYSCALL_INST_PAD			      \
		  : "=z" (resultvar)					      \
		  : "r" (r3) ASMFMT_##nr				      \
		  : "memory", "t");					      \
									      \
    (int) resultvar; })

/* The _NCS variant allows non-constant syscall numbers.  */
#define INTERNAL_SYSCALL_NCS(name, err, nr, args...) \
  ({									      \
    unsigned long int resultvar;					      \
    register long int r3 asm ("%r3") = (name);				      \
    SUBSTITUTE_ARGS_##nr(args);						      \
									      \
    asm volatile (SYSCALL_INST_STR##nr SYSCALL_INST_PAD			      \
		  : "=z" (resultvar)					      \
		  : "r" (r3) ASMFMT_##nr				      \
		  : "memory", "t");					      \
									      \
    (int) resultvar; })

#undef INTERNAL_SYSCALL_DECL
#define INTERNAL_SYSCALL_DECL(err) do { } while (0)

#undef INTERNAL_SYSCALL_ERROR_P
#define INTERNAL_SYSCALL_ERROR_P(val, err) \
  ((unsigned int) (val) >= 0xfffff001u)

#undef INTERNAL_SYSCALL_ERRNO
#define INTERNAL_SYSCALL_ERRNO(val, err)        (-(val))

#endif	/* __ASSEMBLER__ */

/* Pointer mangling support.  */
#if IS_IN (rtld)
/* We cannot use the thread descriptor because in ld.so we use setjmp
   earlier than the descriptor is initialized.  Using a global variable
   is too complicated here since we have no PC-relative addressing mode.  */
#else
# ifdef __ASSEMBLER__
#  define PTR_MANGLE(reg, tmp) \
     stc gbr,tmp; mov.l @(POINTER_GUARD,tmp),tmp; xor tmp,reg
#  define PTR_MANGLE2(reg, tmp)	xor tmp,reg
#  define PTR_DEMANGLE(reg, tmp)	PTR_MANGLE (reg, tmp)
#  define PTR_DEMANGLE2(reg, tmp)	PTR_MANGLE2 (reg, tmp)
# else
#  define PTR_MANGLE(var) \
     (var) = (void *) ((uintptr_t) (var) ^ THREAD_GET_POINTER_GUARD ())
#  define PTR_DEMANGLE(var)	PTR_MANGLE (var)
# endif
#endif

#endif /* linux/sh/sysdep.h */
