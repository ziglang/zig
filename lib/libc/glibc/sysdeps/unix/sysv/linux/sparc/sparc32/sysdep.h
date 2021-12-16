/* Copyright (C) 1997-2021 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Miguel de Icaza <miguel@gnu.ai.mit.edu>, January 1997.

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

#ifndef _LINUX_SPARC32_SYSDEP_H
#define _LINUX_SPARC32_SYSDEP_H 1

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
	ta		0x10;			\
	bcc		1f;			\
	 nop;					\
	SYSCALL_ERROR_HANDLER			\
1:

#undef PSEUDO_NOERRNO
#define PSEUDO_NOERRNO(name, syscall_name, args)\
	.text;					\
ENTRY(name);					\
	LOADSYSCALL(syscall_name);		\
	ta		0x10;

#undef PSEUDO_ERRVAL
#define PSEUDO_ERRVAL(name, syscall_name, args)	\
	.text;					\
ENTRY(name);					\
	LOADSYSCALL(syscall_name);		\
	ta		0x10;

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
	ld	[%o2 + %g1], %g1, %gdop(rtld_errno); \
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
	ld	[%o2 + %g1], %g1, %tie_ld(SYSCALL_ERROR_ERRNO);	\
	st	%o0, [%g7 + %g1];				\
	jmp	%o7 + 8;					\
	 mov	-1, %o0;
# else
#  define SYSCALL_ERROR_HANDLER		\
0:	SETUP_PIC_REG_LEAF(o2,g1)	\
	sethi	%gdop_hix22(errno), %g1;\
	xor	%g1, %gdop_lox10(errno), %g1;\
	ld	[%o2 + %g1], %g1, %gdop(errno);\
	st	%o0, [%g1];		\
	jmp	%o7 + 8;		\
	 mov	-1, %o0;
# endif	/* _LIBC_REENTRANT */
#endif	/* PIC */


#else  /* __ASSEMBLER__ */

#define __SYSCALL_STRING						\
	"ta	0x10;"							\
	"bcc	1f;"							\
	" nop;"								\
	"sub	%%g0, %%o0, %%o0;"					\
	"1:"

#define __SYSCALL_CLOBBERS						\
	"f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7",			\
	"f8", "f9", "f10", "f11", "f12", "f13", "f14", "f15",		\
	"f16", "f17", "f18", "f19", "f20", "f21", "f22", "f23",		\
	"f24", "f25", "f26", "f27", "f28", "f29", "f30", "f31",		\
	"cc", "memory"

#undef HAVE_INTERNAL_BRK_ADDR_SYMBOL
#define HAVE_INTERNAL_BRK_ADDR_SYMBOL 1

#endif	/* __ASSEMBLER__ */

/* Pointer mangling support.  */
#if IS_IN (rtld)
/* We cannot use the thread descriptor because in ld.so we use setjmp
   earlier than the descriptor is initialized.  */
#else
# ifdef __ASSEMBLER__
#  define PTR_MANGLE(dreg, reg, tmpreg) \
  ld	[%g7 + POINTER_GUARD], tmpreg; \
  xor	reg, tmpreg, dreg
#  define PTR_DEMANGLE(dreg, reg, tmpreg) PTR_MANGLE (dreg, reg, tmpreg)
#  define PTR_MANGLE2(dreg, reg, tmpreg) \
  xor	reg, tmpreg, dreg
#  define PTR_DEMANGLE2(dreg, reg, tmpreg) PTR_MANGLE2 (dreg, reg, tmpreg)
# else
#  define PTR_MANGLE(var) \
  (var) = (__typeof (var)) ((uintptr_t) (var) ^ THREAD_GET_POINTER_GUARD ())
#  define PTR_DEMANGLE(var)     PTR_MANGLE (var)
# endif
#endif

#endif /* linux/sparc/sysdep.h */
