/* Copyright (C) 1991-2025 Free Software Foundation, Inc.
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

#include <sysdeps/generic/sysdep.h>
#include <single-thread.h>
#include <sys/syscall.h>
#define	HAVE_SYSCALLS

/* Note that using a `PASTE' macro loses.  */
#define	SYSCALL__(name, args)	PSEUDO (__##name, name, args)
#define	SYSCALL(name, args)	PSEUDO (name, name, args)

#ifndef __ASSEMBLER__
# include <errno.h>

#define __SYSCALL_CONCAT_X(a,b)     a##b
#define __SYSCALL_CONCAT(a,b)       __SYSCALL_CONCAT_X (a, b)


#define __INTERNAL_SYSCALL0(name) \
  INTERNAL_SYSCALL (name, 0)
#define __INTERNAL_SYSCALL1(name, a1) \
  INTERNAL_SYSCALL (name, 1, a1)
#define __INTERNAL_SYSCALL2(name, a1, a2) \
  INTERNAL_SYSCALL (name, 2, a1, a2)
#define __INTERNAL_SYSCALL3(name, a1, a2, a3) \
  INTERNAL_SYSCALL (name, 3, a1, a2, a3)
#define __INTERNAL_SYSCALL4(name, a1, a2, a3, a4) \
  INTERNAL_SYSCALL (name, 4, a1, a2, a3, a4)
#define __INTERNAL_SYSCALL5(name, a1, a2, a3, a4, a5) \
  INTERNAL_SYSCALL (name, 5, a1, a2, a3, a4, a5)
#define __INTERNAL_SYSCALL6(name, a1, a2, a3, a4, a5, a6) \
  INTERNAL_SYSCALL (name, 6, a1, a2, a3, a4, a5, a6)
#define __INTERNAL_SYSCALL7(name, a1, a2, a3, a4, a5, a6, a7) \
  INTERNAL_SYSCALL (name, 7, a1, a2, a3, a4, a5, a6, a7)

#define __INTERNAL_SYSCALL_NARGS_X(a,b,c,d,e,f,g,h,n,...) n
#define __INTERNAL_SYSCALL_NARGS(...) \
  __INTERNAL_SYSCALL_NARGS_X (__VA_ARGS__,7,6,5,4,3,2,1,0,)
#define __INTERNAL_SYSCALL_DISP(b,...) \
  __SYSCALL_CONCAT (b,__INTERNAL_SYSCALL_NARGS(__VA_ARGS__))(__VA_ARGS__)

/* Issue a syscall defined by syscall number plus any other argument required.
   It is similar to INTERNAL_SYSCALL macro, but without the need to pass the
   expected argument number as second parameter.  */
#define INTERNAL_SYSCALL_CALL(...) \
  __INTERNAL_SYSCALL_DISP (__INTERNAL_SYSCALL, __VA_ARGS__)

#define __INTERNAL_SYSCALL_NCS0(name) \
  INTERNAL_SYSCALL_NCS (name, 0)
#define __INTERNAL_SYSCALL_NCS1(name, a1) \
  INTERNAL_SYSCALL_NCS (name, 1, a1)
#define __INTERNAL_SYSCALL_NCS2(name, a1, a2) \
  INTERNAL_SYSCALL_NCS (name, 2, a1, a2)
#define __INTERNAL_SYSCALL_NCS3(name, a1, a2, a3) \
  INTERNAL_SYSCALL_NCS (name, 3, a1, a2, a3)
#define __INTERNAL_SYSCALL_NCS4(name, a1, a2, a3, a4) \
  INTERNAL_SYSCALL_NCS (name, 4, a1, a2, a3, a4)
#define __INTERNAL_SYSCALL_NCS5(name, a1, a2, a3, a4, a5) \
  INTERNAL_SYSCALL_NCS (name, 5, a1, a2, a3, a4, a5)
#define __INTERNAL_SYSCALL_NCS6(name, a1, a2, a3, a4, a5, a6) \
  INTERNAL_SYSCALL_NCS (name, 6, a1, a2, a3, a4, a5, a6)
#define __INTERNAL_SYSCALL_NCS7(name, a1, a2, a3, a4, a5, a6, a7) \
  INTERNAL_SYSCALL_NCS (name, 7, a1, a2, a3, a4, a5, a6, a7)

#define INTERNAL_SYSCALL_NCS_CALL(...) \
  __INTERNAL_SYSCALL_DISP (__INTERNAL_SYSCALL_NCS, __VA_ARGS__)

#define __INLINE_SYSCALL0(name) \
  INLINE_SYSCALL (name, 0)
#define __INLINE_SYSCALL1(name, a1) \
  INLINE_SYSCALL (name, 1, a1)
#define __INLINE_SYSCALL2(name, a1, a2) \
  INLINE_SYSCALL (name, 2, a1, a2)
#define __INLINE_SYSCALL3(name, a1, a2, a3) \
  INLINE_SYSCALL (name, 3, a1, a2, a3)
#define __INLINE_SYSCALL4(name, a1, a2, a3, a4) \
  INLINE_SYSCALL (name, 4, a1, a2, a3, a4)
#define __INLINE_SYSCALL5(name, a1, a2, a3, a4, a5) \
  INLINE_SYSCALL (name, 5, a1, a2, a3, a4, a5)
#define __INLINE_SYSCALL6(name, a1, a2, a3, a4, a5, a6) \
  INLINE_SYSCALL (name, 6, a1, a2, a3, a4, a5, a6)
#define __INLINE_SYSCALL7(name, a1, a2, a3, a4, a5, a6, a7) \
  INLINE_SYSCALL (name, 7, a1, a2, a3, a4, a5, a6, a7)

#define __INLINE_SYSCALL_NARGS_X(a,b,c,d,e,f,g,h,n,...) n
#define __INLINE_SYSCALL_NARGS(...) \
  __INLINE_SYSCALL_NARGS_X (__VA_ARGS__,7,6,5,4,3,2,1,0,)
#define __INLINE_SYSCALL_DISP(b,...) \
  __SYSCALL_CONCAT (b,__INLINE_SYSCALL_NARGS(__VA_ARGS__))(__VA_ARGS__)

/* Issue a syscall defined by syscall number plus any other argument
   required.  Any error will be handled using arch defined macros and errno
   will be set accordingly.
   It is similar to INLINE_SYSCALL macro, but without the need to pass the
   expected argument number as second parameter.  */
#define INLINE_SYSCALL_CALL(...) \
  __INLINE_SYSCALL_DISP (__INLINE_SYSCALL, __VA_ARGS__)

#define __INTERNAL_SYSCALL_NCS0(name) \
  INTERNAL_SYSCALL_NCS (name, 0)
#define __INTERNAL_SYSCALL_NCS1(name, a1) \
  INTERNAL_SYSCALL_NCS (name, 1, a1)
#define __INTERNAL_SYSCALL_NCS2(name, a1, a2) \
  INTERNAL_SYSCALL_NCS (name, 2, a1, a2)
#define __INTERNAL_SYSCALL_NCS3(name, a1, a2, a3) \
  INTERNAL_SYSCALL_NCS (name, 3, a1, a2, a3)
#define __INTERNAL_SYSCALL_NCS4(name, a1, a2, a3, a4) \
  INTERNAL_SYSCALL_NCS (name, 4, a1, a2, a3, a4)
#define __INTERNAL_SYSCALL_NCS5(name, a1, a2, a3, a4, a5) \
  INTERNAL_SYSCALL_NCS (name, 5, a1, a2, a3, a4, a5)
#define __INTERNAL_SYSCALL_NCS6(name, a1, a2, a3, a4, a5, a6) \
  INTERNAL_SYSCALL_NCS (name, 6, a1, a2, a3, a4, a5, a6)
#define __INTERNAL_SYSCALL_NCS7(name, a1, a2, a3, a4, a5, a6, a7) \
  INTERNAL_SYSCALL_NCS (name, 7, a1, a2, a3, a4, a5, a6, a7)

/* Issue a syscall defined by syscall number plus any other argument required.
   It is similar to INTERNAL_SYSCALL_NCS macro, but without the need to pass
   the expected argument number as third parameter.  */
#define INTERNAL_SYSCALL_NCS_CALL(...) \
  __INTERNAL_SYSCALL_DISP (__INTERNAL_SYSCALL_NCS, __VA_ARGS__)

/* Cancellation macros.  */
#include <syscall_types.h>

/* Adjust both the __syscall_cancel and the SYSCALL_CANCEL macro to support
   7 arguments instead of default 6 (curently only mip32).  It avoid add
   the requirement to each architecture to support 7 argument macros
   {INTERNAL,INLINE}_SYSCALL.  */
#ifdef HAVE_CANCELABLE_SYSCALL_WITH_7_ARGS
# define __SYSCALL_CANCEL7_ARG_DEF	__syscall_arg_t a7,
# define __SYSCALL_CANCEL7_ARCH_ARG_DEF ,__syscall_arg_t a7
# define __SYSCALL_CANCEL7_ARG		0,
# define __SYSCALL_CANCEL7_ARG7		a7,
# define __SYSCALL_CANCEL7_ARCH_ARG7	, a7
#else
# define __SYSCALL_CANCEL7_ARG_DEF
# define __SYSCALL_CANCEL7_ARCH_ARG_DEF
# define __SYSCALL_CANCEL7_ARG
# define __SYSCALL_CANCEL7_ARG7
# define __SYSCALL_CANCEL7_ARCH_ARG7
#endif
long int __internal_syscall_cancel (__syscall_arg_t a1, __syscall_arg_t a2,
				    __syscall_arg_t a3, __syscall_arg_t a4,
				    __syscall_arg_t a5, __syscall_arg_t a6,
				    __SYSCALL_CANCEL7_ARG_DEF
				    __syscall_arg_t nr) attribute_hidden;

long int __syscall_cancel (__syscall_arg_t arg1, __syscall_arg_t arg2,
			   __syscall_arg_t arg3, __syscall_arg_t arg4,
			   __syscall_arg_t arg5, __syscall_arg_t arg6,
			   __SYSCALL_CANCEL7_ARG_DEF
			   __syscall_arg_t nr) attribute_hidden;

#define __SYSCALL_CANCEL0(name)						\
  __syscall_cancel (0, 0, 0, 0, 0, 0, __SYSCALL_CANCEL7_ARG __NR_##name)
#define __SYSCALL_CANCEL1(name, a1)					\
  __syscall_cancel (__SSC (a1), 0, 0, 0, 0, 0,				\
		    __SYSCALL_CANCEL7_ARG __NR_##name)
#define __SYSCALL_CANCEL2(name, a1, a2) \
  __syscall_cancel (__SSC (a1), __SSC (a2), 0, 0, 0, 0,			\
		    __SYSCALL_CANCEL7_ARG __NR_##name)
#define __SYSCALL_CANCEL3(name, a1, a2, a3) \
  __syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3), 0, 0, 0,	\
		    __SYSCALL_CANCEL7_ARG __NR_##name)
#define __SYSCALL_CANCEL4(name, a1, a2, a3, a4) \
  __syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3),			\
		    __SSC(a4), 0, 0, __SYSCALL_CANCEL7_ARG __NR_##name)
#define __SYSCALL_CANCEL5(name, a1, a2, a3, a4, a5) \
  __syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3), __SSC(a4),	\
		    __SSC (a5), 0, __SYSCALL_CANCEL7_ARG __NR_##name)
#define __SYSCALL_CANCEL6(name, a1, a2, a3, a4, a5, a6) \
  __syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3), __SSC (a4),	\
		    __SSC (a5), __SSC (a6), __SYSCALL_CANCEL7_ARG	\
		    __NR_##name)
#define __SYSCALL_CANCEL7(name, a1, a2, a3, a4, a5, a6, a7)		\
  __syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3), __SSC (a4),	\
		    __SSC (a5), __SSC (a6), __SSC (a7), __NR_##name)

#define __SYSCALL_CANCEL_NARGS_X(a,b,c,d,e,f,g,h,n,...) n
#define __SYSCALL_CANCEL_NARGS(...) \
  __SYSCALL_CANCEL_NARGS_X (__VA_ARGS__,7,6,5,4,3,2,1,0,)
#define __SYSCALL_CANCEL_CONCAT_X(a,b)     a##b
#define __SYSCALL_CANCEL_CONCAT(a,b)       __SYSCALL_CANCEL_CONCAT_X (a, b)
#define __SYSCALL_CANCEL_DISP(b,...) \
  __SYSCALL_CANCEL_CONCAT (b,__SYSCALL_CANCEL_NARGS(__VA_ARGS__))(__VA_ARGS__)

/* Issue a cancellable syscall defined first argument plus any other argument
   required.  If and error occurs its value, the macro returns -1 and sets
   errno accordingly.  */
#define __SYSCALL_CANCEL_CALL(...) \
  __SYSCALL_CANCEL_DISP (__SYSCALL_CANCEL, __VA_ARGS__)

#define __INTERNAL_SYSCALL_CANCEL0(name)				\
  __internal_syscall_cancel (0, 0, 0, 0, 0, 0, __SYSCALL_CANCEL7_ARG	\
			     __NR_##name)
#define __INTERNAL_SYSCALL_CANCEL1(name, a1)				\
  __internal_syscall_cancel (__SSC (a1), 0, 0, 0, 0, 0,			\
			     __SYSCALL_CANCEL7_ARG __NR_##name)
#define __INTERNAL_SYSCALL_CANCEL2(name, a1, a2)			\
  __internal_syscall_cancel (__SSC (a1), __SSC (a2), 0, 0, 0, 0,	\
			     __SYSCALL_CANCEL7_ARG __NR_##name)
#define __INTERNAL_SYSCALL_CANCEL3(name, a1, a2, a3)			\
  __internal_syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3), 0,	\
			     0, 0, __SYSCALL_CANCEL7_ARG __NR_##name)
#define __INTERNAL_SYSCALL_CANCEL4(name, a1, a2, a3, a4)		\
  __internal_syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3),	\
			     __SSC(a4), 0, 0,				\
			     __SYSCALL_CANCEL7_ARG __NR_##name)
#define __INTERNAL_SYSCALL_CANCEL5(name, a1, a2, a3, a4, a5)		\
  __internal_syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3),	\
			     __SSC(a4), __SSC (a5), 0,			\
			     __SYSCALL_CANCEL7_ARG __NR_##name)
#define __INTERNAL_SYSCALL_CANCEL6(name, a1, a2, a3, a4, a5, a6)	\
  __internal_syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3),	\
			     __SSC (a4), __SSC (a5), __SSC (a6),	\
			     __SYSCALL_CANCEL7_ARG __NR_##name)
#define __INTERNAL_SYSCALL_CANCEL7(name, a1, a2, a3, a4, a5, a6, a7) \
  __internal_syscall_cancel (__SSC (a1), __SSC (a2), __SSC (a3),     \
			     __SSC (a4), __SSC (a5), __SSC (a6),     \
			     __SSC (a7), __NR_##name)

/* Issue a cancellable syscall defined by syscall number NAME plus any other
   argument required.  If an error occurs its value is returned as an negative
   number unmodified and errno is not set.  */
#define __INTERNAL_SYSCALL_CANCEL_CALL(...) \
  __SYSCALL_CANCEL_DISP (__INTERNAL_SYSCALL_CANCEL, __VA_ARGS__)

#if IS_IN (rtld)
/* The loader does not need to handle thread cancellation, use direct
   syscall instead.  */
# define INTERNAL_SYSCALL_CANCEL(...) INTERNAL_SYSCALL_CALL(__VA_ARGS__)
# define SYSCALL_CANCEL(...)          INLINE_SYSCALL_CALL (__VA_ARGS__)
#else
# define INTERNAL_SYSCALL_CANCEL(...) \
  __INTERNAL_SYSCALL_CANCEL_CALL (__VA_ARGS__)
# define SYSCALL_CANCEL(...) \
  __SYSCALL_CANCEL_CALL (__VA_ARGS__)
#endif

#endif /* __ASSEMBLER__  */

/* Machine-dependent sysdep.h files are expected to define the macro
   PSEUDO (function_name, syscall_name) to emit assembly code to define the
   C-callable function FUNCTION_NAME to do system call SYSCALL_NAME.
   r0 and r1 are the system call outputs.  MOVE(x, y) should be defined as
   an instruction such that "MOVE(r1, r0)" works.  ret should be defined
   as the return instruction.  */

#ifndef SYS_ify
#define SYS_ify(syscall_name) SYS_##syscall_name
#endif

/* Terminate a system call named SYM.  This is used on some platforms
   to generate correct debugging information.  */
#ifndef PSEUDO_END
#define PSEUDO_END(sym)
#endif
#ifndef PSEUDO_END_NOERRNO
#define PSEUDO_END_NOERRNO(sym)	PSEUDO_END(sym)
#endif
#ifndef PSEUDO_END_ERRVAL
#define PSEUDO_END_ERRVAL(sym)	PSEUDO_END(sym)
#endif

/* Wrappers around system calls should normally inline the system call code.
   But sometimes it is not possible or implemented and we use this code.  */
#ifndef INLINE_SYSCALL
#define INLINE_SYSCALL(name, nr, args...) __syscall_##name (args)
#endif
