/* Copyright (C) 1992-2020 Free Software Foundation, Inc.
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

#ifndef _LINUX_POWERPC_SYSDEP_H
#define _LINUX_POWERPC_SYSDEP_H 1

#include <sysdeps/unix/sysv/linux/powerpc/sysdep.h>
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/powerpc/sysdep.h>
#include <tls.h>

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#ifndef __ASSEMBLER__

# include <errno.h>

/* Define a macro which expands inline into the wrapper code for a VDSO
   call. This use is for internal calls that do not need to handle errors
   normally. It will never touch errno.
   On powerpc a system call basically clobbers the same registers like a
   function call, with the exception of LR (which is needed for the
   "sc; bnslr+" sequence) and CR (where only CR0.SO is clobbered to signal
   an error return status).  */
# define INTERNAL_VSYSCALL_CALL_TYPE(funcptr, err, type, nr, args...)	      \
  ({									      \
    register void *r0  __asm__ ("r0");					      \
    register long int r3  __asm__ ("r3");				      \
    register long int r4  __asm__ ("r4");				      \
    register long int r5  __asm__ ("r5");				      \
    register long int r6  __asm__ ("r6");				      \
    register long int r7  __asm__ ("r7");				      \
    register long int r8  __asm__ ("r8");				      \
    register long int r9  __asm__ ("r9");				      \
    register long int r10 __asm__ ("r10");				      \
    register long int r11 __asm__ ("r11");				      \
    register long int r12 __asm__ ("r12");				      \
    register type rval  __asm__ ("r3");					      \
    LOADARGS_##nr (funcptr, args);					      \
    __asm__ __volatile__						      \
      ("mtctr %0\n\t"							      \
       "bctrl\n\t"							      \
       "mfcr %0"							      \
       : "+r" (r0), "+r" (r3), "+r" (r4), "+r" (r5),  "+r" (r6),  "+r" (r7),  \
	 "+r" (r8), "+r" (r9), "+r" (r10), "+r" (r11), "+r" (r12)	      \
       : : "cr0", "ctr", "lr", "memory");				      \
    err = (long int) r0;						      \
    __asm__ __volatile__ ("" : "=r" (rval) : "r" (r3), "r" (r4));	      \
    rval;								      \
  })

#define INTERNAL_VSYSCALL_CALL(funcptr, err, nr, args...) \
  INTERNAL_VSYSCALL_CALL_TYPE(funcptr, err, long int, nr, args)

# undef INLINE_SYSCALL
# define INLINE_SYSCALL(name, nr, args...)				\
  ({									\
    INTERNAL_SYSCALL_DECL (sc_err);					\
    long int sc_ret = INTERNAL_SYSCALL (name, sc_err, nr, args);	\
    if (INTERNAL_SYSCALL_ERROR_P (sc_ret, sc_err))			\
      {									\
	__set_errno (INTERNAL_SYSCALL_ERRNO (sc_ret, sc_err));		\
	sc_ret = -1L;							\
      }									\
    sc_ret;								\
  })

/* Define a macro which expands inline into the wrapper code for a system
   call. This use is for internal calls that do not need to handle errors
   normally. It will never touch errno.
   On powerpc a system call basically clobbers the same registers like a
   function call, with the exception of LR (which is needed for the
   "sc; bnslr+" sequence) and CR (where only CR0.SO is clobbered to signal
   an error return status).  */

# undef INTERNAL_SYSCALL_DECL
# define INTERNAL_SYSCALL_DECL(err) long int err __attribute__ ((unused))

# undef INTERNAL_SYSCALL
# define INTERNAL_SYSCALL_NCS(name, err, nr, args...)			\
  ({									\
    register long int r0  __asm__ ("r0");				\
    register long int r3  __asm__ ("r3");				\
    register long int r4  __asm__ ("r4");				\
    register long int r5  __asm__ ("r5");				\
    register long int r6  __asm__ ("r6");				\
    register long int r7  __asm__ ("r7");				\
    register long int r8  __asm__ ("r8");				\
    register long int r9  __asm__ ("r9");				\
    register long int r10 __asm__ ("r10");				\
    register long int r11 __asm__ ("r11");				\
    register long int r12 __asm__ ("r12");				\
    LOADARGS_##nr(name, args);						\
    __asm__ __volatile__						\
      ("sc   \n\t"							\
       "mfcr %0"							\
       : "=&r" (r0),							\
	 "=&r" (r3), "=&r" (r4), "=&r" (r5),  "=&r" (r6),  "=&r" (r7),	\
	 "=&r" (r8), "=&r" (r9), "=&r" (r10), "=&r" (r11), "=&r" (r12)	\
       : ASM_INPUT_##nr							\
       : "cr0", "ctr", "memory");					\
    err = r0;								\
    (int) r3;								\
  })
# define INTERNAL_SYSCALL(name, err, nr, args...) \
  INTERNAL_SYSCALL_NCS (__NR_##name, err, nr, ##args)

# undef INTERNAL_SYSCALL_ERROR_P
# define INTERNAL_SYSCALL_ERROR_P(val, err) \
  ((void) (val), __builtin_expect ((err) & (1 << 28), 0))

# undef INTERNAL_SYSCALL_ERRNO
# define INTERNAL_SYSCALL_ERRNO(val, err)     (val)

# define LOADARGS_0(name, dummy)					      \
	r0 = name
# define LOADARGS_1(name, __arg1) \
	long int arg1 = (long int) (__arg1);	\
  LOADARGS_0(name, 0);					   \
	extern void __illegally_sized_syscall_arg1 (void); \
	if (__builtin_classify_type (__arg1) != 5 && sizeof (__arg1) > 4) \
	  __illegally_sized_syscall_arg1 (); \
	r3 = arg1
# define LOADARGS_2(name, __arg1, __arg2) \
	long int arg2 = (long int) (__arg2); \
	LOADARGS_1(name, __arg1); \
	extern void __illegally_sized_syscall_arg2 (void); \
	if (__builtin_classify_type (__arg2) != 5 && sizeof (__arg2) > 4) \
	  __illegally_sized_syscall_arg2 (); \
	r4 = arg2
# define LOADARGS_3(name, __arg1, __arg2, __arg3) \
	long int arg3 = (long int) (__arg3); \
	LOADARGS_2(name, __arg1, __arg2); \
	extern void __illegally_sized_syscall_arg3 (void); \
	if (__builtin_classify_type (__arg3) != 5 && sizeof (__arg3) > 4) \
	  __illegally_sized_syscall_arg3 (); \
	r5 = arg3
# define LOADARGS_4(name, __arg1, __arg2, __arg3, __arg4) \
	long int arg4 = (long int) (__arg4); \
	LOADARGS_3(name, __arg1, __arg2, __arg3); \
	extern void __illegally_sized_syscall_arg4 (void); \
	if (__builtin_classify_type (__arg4) != 5 && sizeof (__arg4) > 4) \
	  __illegally_sized_syscall_arg4 (); \
	r6 = arg4
# define LOADARGS_5(name, __arg1, __arg2, __arg3, __arg4, __arg5) \
	long int arg5 = (long int) (__arg5); \
	LOADARGS_4(name, __arg1, __arg2, __arg3, __arg4); \
	extern void __illegally_sized_syscall_arg5 (void); \
	if (__builtin_classify_type (__arg5) != 5 && sizeof (__arg5) > 4) \
	  __illegally_sized_syscall_arg5 (); \
	r7 = arg5
# define LOADARGS_6(name, __arg1, __arg2, __arg3, __arg4, __arg5, __arg6) \
	long int arg6 = (long int) (__arg6); \
	LOADARGS_5(name, __arg1, __arg2, __arg3, __arg4, __arg5); \
	extern void __illegally_sized_syscall_arg6 (void); \
	if (__builtin_classify_type (__arg6) != 5 && sizeof (__arg6) > 4) \
	  __illegally_sized_syscall_arg6 (); \
	r8 = arg6

# define ASM_INPUT_0 "0" (r0)
# define ASM_INPUT_1 ASM_INPUT_0, "1" (r3)
# define ASM_INPUT_2 ASM_INPUT_1, "2" (r4)
# define ASM_INPUT_3 ASM_INPUT_2, "3" (r5)
# define ASM_INPUT_4 ASM_INPUT_3, "4" (r6)
# define ASM_INPUT_5 ASM_INPUT_4, "5" (r7)
# define ASM_INPUT_6 ASM_INPUT_5, "6" (r8)

#endif /* __ASSEMBLER__ */


/* Pointer mangling support.  */
#if IS_IN (rtld)
/* We cannot use the thread descriptor because in ld.so we use setjmp
   earlier than the descriptor is initialized.  */
#else
# ifdef __ASSEMBLER__
#  define PTR_MANGLE(reg, tmpreg) \
	lwz	tmpreg,POINTER_GUARD(r2); \
	xor	reg,tmpreg,reg
#  define PTR_MANGLE2(reg, tmpreg) \
	xor	reg,tmpreg,reg
#  define PTR_MANGLE3(destreg, reg, tmpreg) \
	lwz	tmpreg,POINTER_GUARD(r2); \
	xor	destreg,tmpreg,reg
#  define PTR_DEMANGLE(reg, tmpreg) PTR_MANGLE (reg, tmpreg)
#  define PTR_DEMANGLE2(reg, tmpreg) PTR_MANGLE2 (reg, tmpreg)
#  define PTR_DEMANGLE3(destreg, reg, tmpreg) PTR_MANGLE3 (destreg, reg, tmpreg)
# else
#  define PTR_MANGLE(var) \
  (var) = (__typeof (var)) ((uintptr_t) (var) ^ THREAD_GET_POINTER_GUARD ())
#  define PTR_DEMANGLE(var)	PTR_MANGLE (var)
# endif
#endif

#endif /* linux/powerpc/powerpc32/sysdep.h */
