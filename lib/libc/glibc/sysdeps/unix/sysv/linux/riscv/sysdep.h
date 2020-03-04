/* Assembly macros for RISC-V.
   Copyright (C) 2011-2018
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

#ifndef _LINUX_RISCV_SYSDEP_H
#define _LINUX_RISCV_SYSDEP_H 1

#include <sysdeps/unix/sysv/linux/generic/sysdep.h>
#include <tls.h>

#ifdef __ASSEMBLER__

# include <sys/asm.h>

# define ENTRY(name) LEAF(name)

# define L(label) .L ## label

/* Performs a system call, handling errors by setting errno.  Linux indicates
   errors by setting a0 to a value between -1 and -4095.  */
# undef PSEUDO
# define PSEUDO(name, syscall_name, args)			\
  .text;							\
  .align 2;							\
  ENTRY (name);							\
  li a7, SYS_ify (syscall_name);				\
  scall;							\
  li a7, -4096;							\
  bgtu a0, a7, .Lsyscall_error ## name;

# undef PSEUDO_END
# define PSEUDO_END(sym) 					\
  SYSCALL_ERROR_HANDLER (sym)					\
  ret;								\
  END (sym)

# if !IS_IN (libc)
#  if RTLD_PRIVATE_ERRNO
#   define SYSCALL_ERROR_HANDLER(name)				\
.Lsyscall_error ## name:					\
	li t1, -4096;						\
	neg a0, a0;						\
        sw a0, rtld_errno, t1;					\
        li a0, -1;
#  elif defined (__PIC__)
#   define SYSCALL_ERROR_HANDLER(name)				\
.Lsyscall_error ## name:					\
        la.tls.ie t1, errno;					\
	add t1, t1, tp;						\
	neg a0, a0;						\
	sw a0, 0(t1);						\
        li a0, -1;
#  else
#   define SYSCALL_ERROR_HANDLER(name)				\
.Lsyscall_error ## name:					\
        lui t1, %tprel_hi(errno);				\
        add t1, t1, tp, %tprel_add(errno);			\
	neg a0, a0;						\
        sw a0, %tprel_lo(errno)(t1);				\
        li a0, -1;
#  endif
# else
#  define SYSCALL_ERROR_HANDLER(name)				\
.Lsyscall_error ## name:					\
        j       __syscall_error;
# endif

/* Performs a system call, not setting errno.  */
# undef PSEUDO_NEORRNO
# define PSEUDO_NOERRNO(name, syscall_name, args)	\
  .align 2;						\
  ENTRY (name);						\
  li a7, SYS_ify (syscall_name);			\
  scall;

# undef PSEUDO_END_NOERRNO
# define PSEUDO_END_NOERRNO(name)			\
  END (name)

# undef ret_NOERRNO
# define ret_NOERRNO ret

/* Perfroms a system call, returning the error code.  */
# undef PSEUDO_ERRVAL
# define PSEUDO_ERRVAL(name, syscall_name, args) 	\
  PSEUDO_NOERRNO (name, syscall_name, args)		\
  neg a0, a0;

# undef PSEUDO_END_ERRVAL
# define PSEUDO_END_ERRVAL(name)			\
  END (name)

# undef ret_ERRVAL
# define ret_ERRVAL ret

#endif /* __ASSEMBLER__ */

/* In order to get __set_errno() definition in INLINE_SYSCALL.  */
#ifndef __ASSEMBLER__
# include <errno.h>
#endif

#include <sysdeps/unix/sysdep.h>

#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#ifndef __ASSEMBLER__

# define VDSO_NAME  "LINUX_4.15"
# define VDSO_HASH  182943605

/* List of system calls which are supported as vsyscalls.  */
# define HAVE_CLOCK_GETRES64_VSYSCALL	"__vdso_clock_getres"
# define HAVE_CLOCK_GETTIME64_VSYSCALL	"__vdso_clock_gettime"
# define HAVE_GETTIMEOFDAY_VSYSCALL	"__vdso_gettimeofday"
# define HAVE_GETCPU_VSYSCALL		"__vdso_getcpu"

/* Define a macro which expands into the inline wrapper code for a system
   call.  */
# undef INLINE_SYSCALL
# define INLINE_SYSCALL(name, nr, args...)				\
  ({ INTERNAL_SYSCALL_DECL (err);					\
     long int __sys_result = INTERNAL_SYSCALL (name, err, nr, args);	\
     if (__glibc_unlikely (INTERNAL_SYSCALL_ERROR_P (__sys_result, )))  \
       {								\
         __set_errno (INTERNAL_SYSCALL_ERRNO (__sys_result, ));		\
	 __sys_result = (unsigned long) -1;				\
       }								\
     __sys_result; })

# define INTERNAL_SYSCALL_DECL(err) do { } while (0)

# define INTERNAL_SYSCALL_ERROR_P(val, err) \
        ((unsigned long int) (val) > -4096UL)

# define INTERNAL_SYSCALL_ERRNO(val, err)     (-val)

# define INTERNAL_SYSCALL(name, err, nr, args...) \
	internal_syscall##nr (SYS_ify (name), err, args)

# define INTERNAL_SYSCALL_NCS(number, err, nr, args...) \
	internal_syscall##nr (number, err, args)

# define internal_syscall0(number, err, dummy...)			\
({ 									\
	long int _sys_result;						\
									\
	{								\
	register long int __a7 asm ("a7") = number;			\
	register long int __a0 asm ("a0");				\
	__asm__ volatile ( 						\
	"scall\n\t" 							\
	: "=r" (__a0)							\
	: "r" (__a7)							\
	: __SYSCALL_CLOBBERS); 						\
	_sys_result = __a0;						\
	}								\
	_sys_result;							\
})

# define internal_syscall1(number, err, arg0)				\
({ 									\
	long int _sys_result;						\
									\
	{								\
	register long int __a7 asm ("a7") = number;			\
	register long int __a0 asm ("a0") = (long int) (arg0);		\
	__asm__ volatile ( 						\
	"scall\n\t" 							\
	: "+r" (__a0)							\
	: "r" (__a7)							\
	: __SYSCALL_CLOBBERS); 						\
	_sys_result = __a0;						\
	}								\
	_sys_result;							\
})

# define internal_syscall2(number, err, arg0, arg1)	    		\
({ 									\
	long int _sys_result;						\
									\
	{								\
	register long int __a7 asm ("a7") = number;			\
	register long int __a0 asm ("a0") = (long int) (arg0);		\
	register long int __a1 asm ("a1") = (long int) (arg1);		\
	__asm__ volatile ( 						\
	"scall\n\t" 							\
	: "+r" (__a0)							\
	: "r" (__a7), "r" (__a1)					\
	: __SYSCALL_CLOBBERS); 						\
	_sys_result = __a0;						\
	}								\
	_sys_result;							\
})

# define internal_syscall3(number, err, arg0, arg1, arg2)      		\
({ 									\
	long int _sys_result;						\
									\
	{								\
	register long int __a7 asm ("a7") = number;			\
	register long int __a0 asm ("a0") = (long int) (arg0);		\
	register long int __a1 asm ("a1") = (long int) (arg1);		\
	register long int __a2 asm ("a2") = (long int) (arg2);		\
	__asm__ volatile ( 						\
	"scall\n\t" 							\
	: "+r" (__a0)							\
	: "r" (__a7), "r" (__a1), "r" (__a2)				\
	: __SYSCALL_CLOBBERS); 						\
	_sys_result = __a0;						\
	}								\
	_sys_result;							\
})

# define internal_syscall4(number, err, arg0, arg1, arg2, arg3)	  \
({ 									\
	long int _sys_result;						\
									\
	{								\
	register long int __a7 asm ("a7") = number;			\
	register long int __a0 asm ("a0") = (long int) (arg0);		\
	register long int __a1 asm ("a1") = (long int) (arg1);		\
	register long int __a2 asm ("a2") = (long int) (arg2);		\
	register long int __a3 asm ("a3") = (long int) (arg3);		\
	__asm__ volatile ( 						\
	"scall\n\t" 							\
	: "+r" (__a0)							\
	: "r" (__a7), "r" (__a1), "r" (__a2), "r" (__a3)		\
	: __SYSCALL_CLOBBERS); 						\
	_sys_result = __a0;						\
	}								\
	_sys_result;							\
})

# define internal_syscall5(number, err, arg0, arg1, arg2, arg3, arg4)   \
({ 									\
	long int _sys_result;						\
									\
	{								\
	register long int __a7 asm ("a7") = number;			\
	register long int __a0 asm ("a0") = (long int) (arg0);		\
	register long int __a1 asm ("a1") = (long int) (arg1);		\
	register long int __a2 asm ("a2") = (long int) (arg2);		\
	register long int __a3 asm ("a3") = (long int) (arg3);		\
	register long int __a4 asm ("a4") = (long int) (arg4);		\
	__asm__ volatile ( 						\
	"scall\n\t" 							\
	: "+r" (__a0)							\
	: "r" (__a7), "r"(__a1), "r"(__a2), "r"(__a3), "r" (__a4)	\
	: __SYSCALL_CLOBBERS); 						\
	_sys_result = __a0;						\
	}								\
	_sys_result;							\
})

# define internal_syscall6(number, err, arg0, arg1, arg2, arg3, arg4, arg5) \
({ 									\
	long int _sys_result;						\
									\
	{								\
	register long int __a7 asm ("a7") = number;			\
	register long int __a0 asm ("a0") = (long int) (arg0);		\
	register long int __a1 asm ("a1") = (long int) (arg1);		\
	register long int __a2 asm ("a2") = (long int) (arg2);		\
	register long int __a3 asm ("a3") = (long int) (arg3);		\
	register long int __a4 asm ("a4") = (long int) (arg4);		\
	register long int __a5 asm ("a5") = (long int) (arg5);		\
	__asm__ volatile ( 						\
	"scall\n\t" 							\
	: "+r" (__a0)							\
	: "r" (__a7), "r" (__a1), "r" (__a2), "r" (__a3),		\
	  "r" (__a4), "r" (__a5)					\
	: __SYSCALL_CLOBBERS); 						\
	_sys_result = __a0;						\
	}								\
	_sys_result;							\
})

# define internal_syscall7(number, err, arg0, arg1, arg2, arg3, arg4, arg5, arg6) \
({ 									\
	long int _sys_result;						\
									\
	{								\
	register long int __a7 asm ("a7") = number;			\
	register long int __a0 asm ("a0") = (long int) (arg0);		\
	register long int __a1 asm ("a1") = (long int) (arg1);		\
	register long int __a2 asm ("a2") = (long int) (arg2);		\
	register long int __a3 asm ("a3") = (long int) (arg3);		\
	register long int __a4 asm ("a4") = (long int) (arg4);		\
	register long int __a5 asm ("a5") = (long int) (arg5);		\
	register long int __a6 asm ("a6") = (long int) (arg6);		\
	__asm__ volatile ( 						\
	"scall\n\t" 							\
	: "+r" (__a0)							\
	: "r" (__a7), "r" (__a1), "r" (__a2), "r" (__a3),		\
	  "r" (__a4), "r" (__a5), "r" (__a6)				\
	: __SYSCALL_CLOBBERS); 						\
	_sys_result = __a0;						\
	}								\
	_sys_result;							\
})

# define __SYSCALL_CLOBBERS "memory"

extern long int __syscall_error (long int neg_errno);

#endif /* ! __ASSEMBLER__ */

/* Pointer mangling is not supported.  */
#define PTR_MANGLE(var) (void) (var)
#define PTR_DEMANGLE(var) (void) (var)

#endif /* linux/riscv/sysdep.h */
