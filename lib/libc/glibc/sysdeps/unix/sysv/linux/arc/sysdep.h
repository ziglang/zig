/* Assembler macros for ARC.
   Copyright (C) 2020-2023 Free Software Foundation, Inc.
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

#ifndef _LINUX_ARC_SYSDEP_H
#define _LINUX_ARC_SYSDEP_H 1

#include <sysdeps/arc/sysdep.h>
#include <bits/wordsize.h>
#include <sysdeps/unix/sysdep.h>
#include <sysdeps/unix/sysv/linux/sysdep.h>

/* "workarounds" for generic code needing to handle 64-bit time_t.  */

/* Fix sysdeps/unix/sysv/linux/clock_getcpuclockid.c.  */
#define __NR_clock_getres	__NR_clock_getres_time64
/* Fix sysdeps/nptl/lowlevellock-futex.h.  */
#define __NR_futex		__NR_futex_time64
/* Fix sysdeps/unix/sysv/linux/pause.c.  */
#define __NR_ppoll		__NR_ppoll_time64
/* Fix sysdeps/unix/sysv/linux/select.c.  */
#define __NR_pselect6		__NR_pselect6_time64
/* Fix sysdeps/unix/sysv/linux/recvmmsg.c.  */
#define __NR_recvmmsg		__NR_recvmmsg_time64
/* Fix sysdeps/unix/sysv/linux/sigtimedwait.c.  */
#define __NR_rt_sigtimedwait	__NR_rt_sigtimedwait_time64
/* Fix sysdeps/unix/sysv/linux/semtimedop.c.  */
#define __NR_semtimedop		__NR_semtimedop_time64
/* Hack sysdeps/unix/sysv/linux/generic/utimes.c.  */
#define __NR_utimensat		__NR_utimensat_time64

/* For RTLD_PRIVATE_ERRNO.  */
#include <dl-sysdep.h>

#include <tls.h>

#undef SYS_ify
#define SYS_ify(syscall_name)   __NR_##syscall_name

#ifdef __ASSEMBLER__

/* This is a "normal" system call stub: if there is an error,
   it returns -1 and sets errno.  */

# undef PSEUDO
# define PSEUDO(name, syscall_name, args)			\
  PSEUDO_NOERRNO(name, syscall_name, args)	ASM_LINE_SEP	\
    brhi   r0, -4096, L (call_syscall_err)	ASM_LINE_SEP

# define ret	j_s  [blink]

# undef PSEUDO_END
# define PSEUDO_END(name)					\
  SYSCALL_ERROR_HANDLER				ASM_LINE_SEP	\
  END (name)

/* --------- Helper for SYSCALL_NOERRNO -----------
   This kind of system call stub never returns an error.
   We return the return value register to the caller unexamined.  */

# undef PSEUDO_NOERRNO
# define PSEUDO_NOERRNO(name, syscall_name, args)		\
  .text						ASM_LINE_SEP	\
  ENTRY (name)					ASM_LINE_SEP	\
    DO_CALL (syscall_name, args)		ASM_LINE_SEP	\

/* Return the return value register unexamined. Since r0 is both
   syscall return reg and function return reg, no work needed.  */
# define ret_NOERRNO						\
  j_s  [blink]		ASM_LINE_SEP

# undef PSEUDO_END_NOERRNO
# define PSEUDO_END_NOERRNO(name)				\
  END (name)

/* --------- Helper for SYSCALL_ERRVAL -----------
   This kind of system call stub returns the errno code as its return
   value, or zero for success.  We may massage the kernel's return value
   to meet that ABI, but we never set errno here.  */

# undef PSEUDO_ERRVAL
# define PSEUDO_ERRVAL(name, syscall_name, args)		\
  PSEUDO_NOERRNO(name, syscall_name, args)	ASM_LINE_SEP

/* Don't set errno, return kernel error (in errno form) or zero.  */
# define ret_ERRVAL						\
  rsub   r0, r0, 0				ASM_LINE_SEP	\
  ret_NOERRNO

# undef PSEUDO_END_ERRVAL
# define PSEUDO_END_ERRVAL(name)				\
  END (name)


/* To reduce the code footprint, we confine the actual errno access
   to single place in __syscall_error().
   This takes raw kernel error value, sets errno and returns -1.  */
# if IS_IN (libc)
#  define CALL_ERRNO_SETTER_C	bl     PLTJMP(HIDDEN_JUMPTARGET(__syscall_error))
# else
#  define CALL_ERRNO_SETTER_C	bl     PLTJMP(__syscall_error)
# endif

# define SYSCALL_ERROR_HANDLER				\
L (call_syscall_err):			ASM_LINE_SEP	\
    push_s   blink			ASM_LINE_SEP	\
    cfi_adjust_cfa_offset (4)		ASM_LINE_SEP	\
    cfi_rel_offset (blink, 0)		ASM_LINE_SEP	\
    CALL_ERRNO_SETTER_C			ASM_LINE_SEP	\
    pop_s  blink			ASM_LINE_SEP	\
    cfi_adjust_cfa_offset (-4)		ASM_LINE_SEP	\
    cfi_restore (blink)			ASM_LINE_SEP	\
    j_s      [blink]

# define DO_CALL(syscall_name, args)			\
    mov    r8, __NR_##syscall_name	ASM_LINE_SEP	\
    ARC_TRAP_INSN			ASM_LINE_SEP

# define ARC_TRAP_INSN	trap_s 0

#else  /* !__ASSEMBLER__ */

# if IS_IN (libc)
extern long int __syscall_error (long int);
hidden_proto (__syscall_error)
# endif

# define ARC_TRAP_INSN	"trap_s 0	\n\t"

# define HAVE_CLONE3_WRAPPER	1

# undef INTERNAL_SYSCALL_NCS
# define INTERNAL_SYSCALL_NCS(number, nr_args, args...)	\
  ({								\
    /* Per ABI, r0 is 1st arg and return reg.  */		\
    register long int __ret __asm__("r0");			\
    register long int _sys_num __asm__("r8");			\
								\
    LOAD_ARGS_##nr_args (number, args)				\
								\
    __asm__ volatile (						\
                      ARC_TRAP_INSN				\
                      : "+r" (__ret)				\
                      : "r"(_sys_num) ASM_ARGS_##nr_args	\
                      : "memory");				\
                                                                \
    __ret; })

# undef INTERNAL_SYSCALL
# define INTERNAL_SYSCALL(name, nr, args...) 	\
  INTERNAL_SYSCALL_NCS(__NR_##name, nr, args)

/* Macros for setting up inline __asm__ input regs.  */
# define ASM_ARGS_0
# define ASM_ARGS_1	ASM_ARGS_0, "r" (__ret)
# define ASM_ARGS_2	ASM_ARGS_1, "r" (_arg2)
# define ASM_ARGS_3	ASM_ARGS_2, "r" (_arg3)
# define ASM_ARGS_4	ASM_ARGS_3, "r" (_arg4)
# define ASM_ARGS_5	ASM_ARGS_4, "r" (_arg5)
# define ASM_ARGS_6	ASM_ARGS_5, "r" (_arg6)
# define ASM_ARGS_7	ASM_ARGS_6, "r" (_arg7)

/* Macros for converting sys-call wrapper args into sys call args.  */
# define LOAD_ARGS_0(nm, arg)				\
  _sys_num = (long int) (nm);

# define LOAD_ARGS_1(nm, arg1)				\
  __ret = (long int) (arg1);					\
  LOAD_ARGS_0 (nm, arg1)

/* Note that the use of _tmpX might look superfluous, however it is needed
   to ensure that register variables are not clobbered if arg happens to be
   a function call itself. e.g. sched_setaffinity() calling getpid() for arg2
   Also this specific order of recursive calling is important to segregate
   the tmp args evaluation (function call case described above) and assignment
   of register variables.  */

# define LOAD_ARGS_2(nm, arg1, arg2)			\
  long int _tmp2 = (long int) (arg2);			\
  LOAD_ARGS_1 (nm, arg1)				\
  register long int _arg2 __asm__ ("r1") = _tmp2;

# define LOAD_ARGS_3(nm, arg1, arg2, arg3)		\
  long int _tmp3 = (long int) (arg3);			\
  LOAD_ARGS_2 (nm, arg1, arg2)				\
  register long int _arg3 __asm__ ("r2") = _tmp3;

#define LOAD_ARGS_4(nm, arg1, arg2, arg3, arg4)		\
  long int _tmp4 = (long int) (arg4);			\
  LOAD_ARGS_3 (nm, arg1, arg2, arg3)			\
  register long int _arg4 __asm__ ("r3") = _tmp4;

# define LOAD_ARGS_5(nm, arg1, arg2, arg3, arg4, arg5)	\
  long int _tmp5 = (long int) (arg5);			\
  LOAD_ARGS_4 (nm, arg1, arg2, arg3, arg4)		\
  register long int _arg5 __asm__ ("r4") = _tmp5;

# define LOAD_ARGS_6(nm,  arg1, arg2, arg3, arg4, arg5, arg6)\
  long int _tmp6 = (long int) (arg6);			\
  LOAD_ARGS_5 (nm, arg1, arg2, arg3, arg4, arg5)	\
  register long int _arg6 __asm__ ("r5") = _tmp6;

# define LOAD_ARGS_7(nm, arg1, arg2, arg3, arg4, arg5, arg6, arg7)\
  long int _tmp7 = (int) (arg7);				\
  LOAD_ARGS_6 (nm, arg1, arg2, arg3, arg4, arg5, arg6)	\
  register long int _arg7 __asm__ ("r6") = _tmp7;

# undef HAVE_INTERNAL_BRK_ADDR_SYMBOL
# define HAVE_INTERNAL_BRK_ADDR_SYMBOL  1

#endif /* !__ASSEMBLER__ */

#endif /* linux/arc/sysdep.h */
