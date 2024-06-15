/* Assembler macros for Nios II.
   Copyright (C) 2000-2024 Free Software Foundation, Inc.
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

#ifndef _LINUX_NIOS2_SYSDEP_H
#define _LINUX_NIOS2_SYSDEP_H 1

#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/unix/sysdep.h>
#include <sysdeps/nios2/sysdep.h>

/* For RTLD_PRIVATE_ERRNO.  */
#include <dl-sysdep.h>

#include <tls.h>

/* For Linux we can use the system call table in the header file
        /usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)   __NR_##syscall_name

#ifdef __ASSEMBLER__

#undef SYSCALL_ERROR_LABEL
#define SYSCALL_ERROR_LABEL __local_syscall_error

#undef PSEUDO
#define PSEUDO(name, syscall_name, args) \
  ENTRY (name)                           \
    DO_CALL (syscall_name, args)         \
    bne r7, zero, SYSCALL_ERROR_LABEL;   \

#undef PSEUDO_END
#define PSEUDO_END(name) \
  SYSCALL_ERROR_HANDLER  \
  END (name)

#undef PSEUDO_NOERRNO
#define PSEUDO_NOERRNO(name, syscall_name, args) \
  ENTRY (name)                                   \
    DO_CALL (syscall_name, args)

#undef PSEUDO_END_NOERRNO
#define PSEUDO_END_NOERRNO(name) \
  END (name)

#undef ret_NOERRNO
#define ret_NOERRNO ret

#undef DO_CALL
#define DO_CALL(syscall_name, args) \
    DOARGS_##args                   \
    movi r2, SYS_ify(syscall_name);  \
    trap;

#if defined(__PIC__) || defined(PIC)

# if RTLD_PRIVATE_ERRNO

#  define SYSCALL_ERROR_HANDLER			\
  SYSCALL_ERROR_LABEL:				\
  nextpc r3;					\
1:						\
  movhi r8, %hiadj(rtld_errno - 1b);		\
  addi r8, r8, %lo(rtld_errno - 1b);		\
  add r3, r3, r8;				\
  stw r2, 0(r3);				\
  movi r2, -1;					\
  ret;

# else

#  if IS_IN (libc)
#   define SYSCALL_ERROR_ERRNO __libc_errno
#  else
#   define SYSCALL_ERROR_ERRNO errno
#  endif
#  define SYSCALL_ERROR_HANDLER			\
  SYSCALL_ERROR_LABEL:				\
  nextpc r3;					\
1:						\
  movhi r8, %hiadj(_gp_got - 1b);		\
  addi r8, r8, %lo(_gp_got - 1b);		\
  add r3, r3, r8;				\
  ldw r3, %tls_ie(SYSCALL_ERROR_ERRNO)(r3);	\
  add r3, r23, r3;				\
  stw r2, 0(r3);				\
  movi r2, -1;					\
  ret;

# endif

#else

/* We can use a single error handler in the static library.  */
#define SYSCALL_ERROR_HANDLER			\
  SYSCALL_ERROR_LABEL:				\
  jmpi __syscall_error;

#endif

#define DOARGS_0 /* nothing */
#define DOARGS_1 /* nothing */
#define DOARGS_2 /* nothing */
#define DOARGS_3 /* nothing */
#define DOARGS_4 /* nothing */
#define DOARGS_5 ldw r8, 0(sp);
#define DOARGS_6 ldw r9, 4(sp); ldw r8, 0(sp);

/* The function has to return the error code.  */
#undef  PSEUDO_ERRVAL
#define PSEUDO_ERRVAL(name, syscall_name, args) \
  ENTRY (name)                                  \
    DO_CALL (syscall_name, args)

#undef  PSEUDO_END_ERRVAL
#define PSEUDO_END_ERRVAL(name) \
  END (name)

#define ret_ERRVAL ret

#else /* __ASSEMBLER__ */

/* In order to get __set_errno() definition in INLINE_SYSCALL.  */
#include <errno.h>

#undef INTERNAL_SYSCALL_RAW
#define INTERNAL_SYSCALL_RAW(name, nr, args...)                 \
  ({ unsigned int _sys_result;                                  \
     {                                                          \
       /* Load argument values in temporary variables
	  to perform side effects like function calls
	  before the call-used registers are set.  */		\
       LOAD_ARGS_##nr (args)					\
       LOAD_REGS_##nr						\
       register int _r2 asm ("r2") = (int)(name);               \
       register int _err asm ("r7");                            \
       asm volatile ("trap"                                     \
                     : "+r" (_r2), "=r" (_err)                  \
                     : ASM_ARGS_##nr				\
                     : __SYSCALL_CLOBBERS);                     \
       _sys_result = _err != 0 ? -_r2 : _r2;                    \
     }                                                          \
     (int) _sys_result; })

#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL(name, nr, args...) \
	INTERNAL_SYSCALL_RAW(SYS_ify(name), nr, args)

#undef INTERNAL_SYSCALL_NCS
#define INTERNAL_SYSCALL_NCS(number, nr, args...) \
	INTERNAL_SYSCALL_RAW(number, nr, args)

#define LOAD_ARGS_0()
#define LOAD_REGS_0
#define ASM_ARGS_0
#define LOAD_ARGS_1(a1)				\
  LOAD_ARGS_0 ()				\
  int __arg1 = (int) (a1);
#define LOAD_REGS_1				\
  register int _r4 asm ("r4") = __arg1;		\
  LOAD_REGS_0
#define ASM_ARGS_1                  "r" (_r4)
#define LOAD_ARGS_2(a1, a2)			\
  LOAD_ARGS_1 (a1)				\
  int __arg2 = (int) (a2);
#define LOAD_REGS_2				\
  register int _r5 asm ("r5") = __arg2;		\
  LOAD_REGS_1
#define ASM_ARGS_2      ASM_ARGS_1, "r" (_r5)
#define LOAD_ARGS_3(a1, a2, a3)			\
  LOAD_ARGS_2 (a1, a2)				\
  int __arg3 = (int) (a3);
#define LOAD_REGS_3				\
  register int _r6 asm ("r6") = __arg3;		\
  LOAD_REGS_2
#define ASM_ARGS_3      ASM_ARGS_2, "r" (_r6)
#define LOAD_ARGS_4(a1, a2, a3, a4)		\
  LOAD_ARGS_3 (a1, a2, a3)			\
  int __arg4 = (int) (a4);
#define LOAD_REGS_4				\
  register int _r7 asm ("r7") = __arg4;		\
  LOAD_REGS_3
#define ASM_ARGS_4      ASM_ARGS_3, "r" (_r7)
#define LOAD_ARGS_5(a1, a2, a3, a4, a5)		\
  LOAD_ARGS_4 (a1, a2, a3, a4)			\
  int __arg5 = (int) (a5);
#define LOAD_REGS_5				\
  register int _r8 asm ("r8") = __arg5;		\
  LOAD_REGS_4
#define ASM_ARGS_5      ASM_ARGS_4, "r" (_r8)
#define LOAD_ARGS_6(a1, a2, a3, a4, a5, a6)	\
  LOAD_ARGS_5 (a1, a2, a3, a4, a5)		\
  int __arg6 = (int) (a6);
#define LOAD_REGS_6			    \
  register int _r9 asm ("r9") = __arg6;     \
  LOAD_REGS_5
#define ASM_ARGS_6      ASM_ARGS_5, "r" (_r9)

#define __SYSCALL_CLOBBERS "memory"

#undef HAVE_INTERNAL_BRK_ADDR_SYMBOL
#define HAVE_INTERNAL_BRK_ADDR_SYMBOL 1

#endif /* __ASSEMBLER__ */

#endif /* linux/nios2/sysdep.h */
