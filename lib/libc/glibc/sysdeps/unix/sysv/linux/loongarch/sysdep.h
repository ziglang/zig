/* Assembly macros for LoongArch.
   Copyright (C) 2022-2025 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _LINUX_LOONGARCH_SYSDEP_H
#define _LINUX_LOONGARCH_SYSDEP_H 1

#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/sysdep.h>
#include <tls.h>

#ifdef __ASSEMBLER__

#include <sys/asm.h>
#define ret jirl zero, ra, 0
#define L(label) .L##label

/* Performs a system call, handling errors by setting errno.  Linux indicates
   errors by setting a0 to a value between -1 and -4095.  */
#undef PSEUDO
#define PSEUDO(name, syscall_name, args) \
  ENTRY (name); \
  li.d a7, SYS_ify (syscall_name); \
  syscall 0; \
  li.d a7, -4096; \
  bltu a7, a0, .Lsyscall_error##name;

#undef PSEUDO_END
#define PSEUDO_END(sym) \
  SYSCALL_ERROR_HANDLER (sym); \
  ret; \
  END (sym);

#if !IS_IN(libc)
#if RTLD_PRIVATE_ERRNO

#define SYSCALL_ERROR_HANDLER(name) \
  .Lsyscall_error##name : la t0, rtld_errno; \
  sub.w a0, zero, a0; \
  st.w a0, t0, 0; \
  li.d a0, -1;

#else

#define SYSCALL_ERROR_HANDLER(name) \
  .Lsyscall_error##name : la.tls.ie t0, errno; \
  add.d t0, tp, t0; \
  sub.w a0, zero, a0; \
  st.w a0, t0, 0; \
  li.d a0, -1;

#endif
#else

#define SYSCALL_ERROR_HANDLER(name) .Lsyscall_error##name : b __syscall_error;

#endif

/* Performs a system call, not setting errno.  */
#undef PSEUDO_NEORRNO
#define PSEUDO_NOERRNO(name, syscall_name, args) \
  ENTRY (name); \
  li.d a7, SYS_ify (syscall_name); \
  syscall 0;

#undef PSEUDO_END_NOERRNO
#define PSEUDO_END_NOERRNO(name) END (name);

#undef ret_NOERRNO
#define ret_NOERRNO ret

/* Performs a system call, returning the error code.  */
#undef PSEUDO_ERRVAL
#define PSEUDO_ERRVAL(name, syscall_name, args) \
  PSEUDO_NOERRNO (name, syscall_name, args); \
  slli.d a0, a0, 32; \
  srai.d a0, a0, 32; /* sign_ext */ \
  sub.d a0, zero, a0;

#undef PSEUDO_END_ERRVAL
#define PSEUDO_END_ERRVAL(name) END (name);

#undef ret_ERRVAL
#define ret_ERRVAL ret

#endif /* __ASSEMBLER__ */

/* In order to get __set_errno() definition in INLINE_SYSCALL.  */
#ifndef __ASSEMBLER__
#include <errno.h>
#endif

#include <sysdeps/unix/sysdep.h>

#undef SYS_ify
#define SYS_ify(syscall_name) __NR_##syscall_name

#ifndef __ASSEMBLER__

#define VDSO_NAME "LINUX_5.10"
#define VDSO_HASH 182947696

/* List of system calls which are supported as vsyscalls.  */
#define HAVE_CLOCK_GETRES64_VSYSCALL "__vdso_clock_getres"
#define HAVE_CLOCK_GETTIME64_VSYSCALL "__vdso_clock_gettime"
#define HAVE_GETTIMEOFDAY_VSYSCALL "__vdso_gettimeofday"
#define HAVE_GETCPU_VSYSCALL "__vdso_getcpu"
#define HAVE_GETRANDOM_VSYSCALL "__vdso_getrandom"

#define HAVE_CLONE3_WRAPPER 1

#define INTERNAL_SYSCALL(name, nr, args...) \
  internal_syscall##nr (SYS_ify (name), args)

#define INTERNAL_SYSCALL_NCS(number, nr, args...) \
  internal_syscall##nr (number, args)

#define internal_syscall0(number, dummy...) \
  ({ \
    long int _sys_result; \
\
    { \
      register long int __a7 asm ("$a7") = number; \
      register long int __a0 asm ("$a0"); \
      __asm__ volatile ("syscall 0\n\t" \
		       : "=r"(__a0) \
		       : "r"(__a7) \
		       : __SYSCALL_CLOBBERS); \
      _sys_result = __a0; \
    } \
    _sys_result; \
  })

#define internal_syscall1(number, arg0) \
  ({ \
    long int _sys_result; \
\
    { \
      long int _arg0 = (long int) (arg0); \
      register long int __a7 asm ("$a7") = number; \
      register long int __a0 asm ("$a0") = _arg0; \
      __asm__ volatile ("syscall 0\n\t" \
		       : "+r"(__a0) \
		       : "r"(__a7) \
		       : __SYSCALL_CLOBBERS); \
      _sys_result = __a0; \
    } \
    _sys_result; \
  })

#define internal_syscall2(number, arg0, arg1) \
  ({ \
    long int _sys_result; \
\
    { \
      long int _arg0 = (long int) (arg0); \
      long int _arg1 = (long int) (arg1); \
      register long int __a7 asm ("$a7") = number; \
      register long int __a0 asm ("$a0") = _arg0; \
      register long int __a1 asm ("$a1") = _arg1; \
      __asm__ volatile ("syscall 0\n\t" \
		       : "+r"(__a0) \
		       : "r"(__a7), "r"(__a1) \
		       : __SYSCALL_CLOBBERS); \
      _sys_result = __a0; \
    } \
    _sys_result; \
  })

#define internal_syscall3(number, arg0, arg1, arg2) \
  ({ \
    long int _sys_result; \
\
    { \
      long int _arg0 = (long int) (arg0); \
      long int _arg1 = (long int) (arg1); \
      long int _arg2 = (long int) (arg2); \
      register long int __a7 asm ("$a7") = number; \
      register long int __a0 asm ("$a0") = _arg0; \
      register long int __a1 asm ("$a1") = _arg1; \
      register long int __a2 asm ("$a2") = _arg2; \
      __asm__ volatile ("syscall 0\n\t" \
		       : "+r"(__a0) \
		       : "r"(__a7), "r"(__a1), "r"(__a2) \
		       : __SYSCALL_CLOBBERS); \
      _sys_result = __a0; \
    } \
    _sys_result; \
  })

#define internal_syscall4(number, arg0, arg1, arg2, arg3) \
  ({ \
    long int _sys_result; \
\
    { \
      long int _arg0 = (long int) (arg0); \
      long int _arg1 = (long int) (arg1); \
      long int _arg2 = (long int) (arg2); \
      long int _arg3 = (long int) (arg3); \
      register long int __a7 asm ("$a7") = number; \
      register long int __a0 asm ("$a0") = _arg0; \
      register long int __a1 asm ("$a1") = _arg1; \
      register long int __a2 asm ("$a2") = _arg2; \
      register long int __a3 asm ("$a3") = _arg3; \
      __asm__ volatile ("syscall 0\n\t" \
		       : "+r"(__a0) \
		       : "r"(__a7), "r"(__a1), "r"(__a2), "r"(__a3) \
		       : __SYSCALL_CLOBBERS); \
      _sys_result = __a0; \
    } \
    _sys_result; \
  })

#define internal_syscall5(number, arg0, arg1, arg2, arg3, arg4) \
  ({ \
    long int _sys_result; \
\
    { \
      long int _arg0 = (long int) (arg0); \
      long int _arg1 = (long int) (arg1); \
      long int _arg2 = (long int) (arg2); \
      long int _arg3 = (long int) (arg3); \
      long int _arg4 = (long int) (arg4); \
      register long int __a7 asm ("$a7") = number; \
      register long int __a0 asm ("$a0") = _arg0; \
      register long int __a1 asm ("$a1") = _arg1; \
      register long int __a2 asm ("$a2") = _arg2; \
      register long int __a3 asm ("$a3") = _arg3; \
      register long int __a4 asm ("$a4") = _arg4; \
      __asm__ volatile ("syscall 0\n\t" \
		       : "+r"(__a0) \
		       : "r"(__a7), "r"(__a1), "r"(__a2), \
			 "r"(__a3), "r"(__a4) \
		       : __SYSCALL_CLOBBERS); \
      _sys_result = __a0; \
    } \
    _sys_result; \
  })

#define internal_syscall6(number, arg0, arg1, arg2, arg3, arg4, arg5) \
  ({ \
    long int _sys_result; \
\
    { \
      long int _arg0 = (long int) (arg0); \
      long int _arg1 = (long int) (arg1); \
      long int _arg2 = (long int) (arg2); \
      long int _arg3 = (long int) (arg3); \
      long int _arg4 = (long int) (arg4); \
      long int _arg5 = (long int) (arg5); \
      register long int __a7 asm ("$a7") = number; \
      register long int __a0 asm ("$a0") = _arg0; \
      register long int __a1 asm ("$a1") = _arg1; \
      register long int __a2 asm ("$a2") = _arg2; \
      register long int __a3 asm ("$a3") = _arg3; \
      register long int __a4 asm ("$a4") = _arg4; \
      register long int __a5 asm ("$a5") = _arg5; \
      __asm__ volatile ("syscall 0\n\t" \
		       : "+r"(__a0) \
		       : "r"(__a7), "r"(__a1), "r"(__a2), "r"(__a3), \
			 "r"(__a4), "r"(__a5) \
		       : __SYSCALL_CLOBBERS); \
      _sys_result = __a0; \
    } \
    _sys_result; \
  })

#define internal_syscall7(number, arg0, arg1, arg2, arg3, arg4, arg5, arg6) \
  ({ \
    long int _sys_result; \
\
    { \
      long int _arg0 = (long int) (arg0); \
      long int _arg1 = (long int) (arg1); \
      long int _arg2 = (long int) (arg2); \
      long int _arg3 = (long int) (arg3); \
      long int _arg4 = (long int) (arg4); \
      long int _arg5 = (long int) (arg5); \
      long int _arg6 = (long int) (arg6); \
      register long int __a7 asm ("$a7") = number; \
      register long int __a0 asm ("$a0") = _arg0; \
      register long int __a1 asm ("$a1") = _arg1; \
      register long int __a2 asm ("$a2") = _arg2; \
      register long int __a3 asm ("$a3") = _arg3; \
      register long int __a4 asm ("$a4") = _arg4; \
      register long int __a5 asm ("$a5") = _arg5; \
      register long int __a6 asm ("$a6") = _arg6; \
      __asm__ volatile ("syscall 0\n\t" \
		       : "+r"(__a0) \
		       : "r"(__a7), "r"(__a1), "r"(__a2), "r"(__a3), \
			 "r"(__a4), "r"(__a5), "r"(__a6) \
		       : __SYSCALL_CLOBBERS); \
      _sys_result = __a0; \
    } \
    _sys_result; \
  })

#define __SYSCALL_CLOBBERS \
  "$t0", "$t1", "$t2", "$t3", "$t4", "$t5", "$t6", "$t7", "$t8", "memory"

extern long int __syscall_error (long int neg_errno);

#endif /* ! __ASSEMBLER__ */

#endif /* linux/loongarch/sysdep.h */
