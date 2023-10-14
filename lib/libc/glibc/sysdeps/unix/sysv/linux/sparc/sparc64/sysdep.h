/* Copyright (C) 1997-2023 Free Software Foundation, Inc.
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

#ifndef _LINUX_SPARC64_SYSDEP_H
#define _LINUX_SPARC64_SYSDEP_H 1

#include <sysdeps/unix/sysv/linux/sparc/sysdep.h>

#if IS_IN (rtld)
# include <dl-sysdep.h>		/* Defines RTLD_PRIVATE_ERRNO.  */
#endif
#include <tls.h>

#undef SYS_ify
#define SYS_ify(syscall_name) __NR_##syscall_name

#ifdef __ASSEMBLER__

#define LOADSYSCALL(x) mov __NR_##x, %g1

#undef PSEUDO
#define PSEUDO(name, syscall_name, args)	\
	.text;					\
ENTRY(name);					\
	LOADSYSCALL(syscall_name);		\
	ta		0x6d;			\
	bcc,pt		%xcc, 1f;		\
	 nop;					\
	SYSCALL_ERROR_HANDLER			\
1:

#undef PSEUDO_NOERRNO
#define	PSEUDO_NOERRNO(name, syscall_name, args)\
	.text;					\
ENTRY(name);					\
	LOADSYSCALL(syscall_name);		\
	ta		0x6d;

#undef PSEUDO_ERRVAL
#define	PSEUDO_ERRVAL(name, syscall_name, args) \
	.text;					\
ENTRY(name);					\
	LOADSYSCALL(syscall_name);		\
	ta		0x6d;

#undef PSEUDO_END
#define PSEUDO_END(name)			\
	END(name)

#ifndef PIC
# define SYSCALL_ERROR_HANDLER			\
	mov	%o7, %g1;			\
	call	__syscall_error;		\
	 mov	%g1, %o7;
#else
# if RTLD_PRIVATE_ERRNO
#  define SYSCALL_ERROR_HANDLER			\
0:	SETUP_PIC_REG_LEAF(o2,g1)		\
	sethi	%gdop_hix22(rtld_errno), %g1;	\
	xor	%g1, %gdop_lox10(rtld_errno), %g1;\
	ldx	[%o2 + %g1], %g1, %gdop(rtld_errno); \
	st	%o0, [%g1];			\
	jmp	%o7 + 8;			\
	 mov	-1, %o0;
# elif defined _LIBC_REENTRANT

#  if IS_IN (libc)
#   define SYSCALL_ERROR_ERRNO __libc_errno
#  else
#   define SYSCALL_ERROR_ERRNO errno
#  endif
#  define SYSCALL_ERROR_HANDLER					\
0:	SETUP_PIC_REG_LEAF(o2,g1)				\
	sethi	%tie_hi22(SYSCALL_ERROR_ERRNO), %g1;		\
	add	%g1, %tie_lo10(SYSCALL_ERROR_ERRNO), %g1;	\
	ldx	[%o2 + %g1], %g1, %tie_ldx(SYSCALL_ERROR_ERRNO);\
	st	%o0, [%g7 + %g1];				\
	jmp	%o7 + 8;					\
	 mov	-1, %o0;
# else
#  define SYSCALL_ERROR_HANDLER		\
0:	SETUP_PIC_REG_LEAF(o2,g1)	\
	sethi	%gdop_hix22(errno), %g1;\
	xor	%g1, %gdop_lox10(errno), %g1;\
	ldx	[%o2 + %g1], %g1, %gdop(errno);\
	st	%o0, [%g1];		\
	jmp	%o7 + 8;		\
	 mov	-1, %o0;
# endif	/* _LIBC_REENTRANT */
#endif	/* PIC */

#else  /* __ASSEMBLER__ */

#define __SYSCALL_STRING						\
	"ta	0x6d;"							\
	"bcc,pt	%%xcc, 1f;"						\
	" nop;"								\
	"sub	%%g0, %%o0, %%o0;"					\
	"1:"

#define __SYSCALL_CLOBBERS						\
	"f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7",			\
	"f8", "f9", "f10", "f11", "f12", "f13", "f14", "f15",		\
	"f16", "f17", "f18", "f19", "f20", "f21", "f22", "f23",		\
	"f24", "f25", "f26", "f27", "f28", "f29", "f30", "f31",		\
	"f32", "f34", "f36", "f38", "f40", "f42", "f44", "f46",		\
	"f48", "f50", "f52", "f54", "f56", "f58", "f60", "f62",		\
	"cc", "memory"

#endif	/* __ASSEMBLER__ */

/* This is the offset from the %sp to the backing store above the
   register windows.  So if you poke stack memory directly you add this.  */
#define STACK_BIAS	2047

#endif /* linux/sparc64/sysdep.h */
