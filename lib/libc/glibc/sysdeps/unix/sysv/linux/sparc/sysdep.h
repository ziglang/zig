/* Copyright (C) 2000-2025 Free Software Foundation, Inc.
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

#ifndef _LINUX_SPARC_SYSDEP_H
#define _LINUX_SPARC_SYSDEP_H 1

#include <sysdeps/unix/sysdep.h>
#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <sysdeps/sparc/sysdep.h>

#ifdef __ASSEMBLER__

#define	ret		retl; nop
#define	ret_NOERRNO	retl; nop
#define	ret_ERRVAL	retl; nop
#define	r0		%o0
#define	r1		%o1
#define	MOVE(x,y)	mov x, y

#else	/* __ASSEMBLER__ */

# define VDSO_NAME  "LINUX_2.6"
# define VDSO_HASH  61765110

/* List of system calls which are supported as vsyscalls.  */
# ifdef __arch64__
#  define HAVE_CLOCK_GETTIME64_VSYSCALL	"__vdso_clock_gettime"
# else
#  define HAVE_CLOCK_GETTIME_VSYSCALL	"__vdso_clock_gettime"
# endif
# define HAVE_GETTIMEOFDAY_VSYSCALL	"__vdso_gettimeofday"

#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL(name, nr, args...) \
  internal_syscall##nr(__SYSCALL_STRING, __NR_##name, args)

#undef INTERNAL_SYSCALL_NCS
#define INTERNAL_SYSCALL_NCS(name, nr, args...) \
  _internal_syscall##nr(__SYSCALL_STRING, "p", name, args)

#define _internal_syscall0(string,nc,name,dummy...)	\
({									\
	register long __o0 __asm__ ("o0");				\
	long int _name = (long int) (name);				\
	__asm __volatile (string : "=r" (__o0) :			\
			  [scn] nc (_name) :				\
			  __SYSCALL_CLOBBERS);				\
	__o0;								\
})
#define internal_syscall0(string,name,args...)				\
  _internal_syscall0(string, "i", name, args)

#define _internal_syscall1(string,nc,name,arg1)				\
({									\
	long int _arg1 = (long int) (arg1);				\
	long int _name = (long int) (name);				\
	register long int  __o0 __asm__ ("o0") = _arg1;			\
	__asm __volatile (string : "+r" (__o0) :			\
			  [scn] nc (_name) :				\
			  __SYSCALL_CLOBBERS);				\
	__o0;								\
})
#define internal_syscall1(string,name,args...)				\
  _internal_syscall1(string, "i", name, args)

#define _internal_syscall2(string,nc,name,arg1,arg2)			\
({									\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	long int _name = (long int) (name);				\
	register long int __o0 __asm__ ("o0") = _arg1;			\
	register long int __o1 __asm__ ("o1") = _arg2;			\
	__asm __volatile (string : "+r" (__o0) :			\
			  [scn] nc (_name), "r" (__o1) :		\
			  __SYSCALL_CLOBBERS);				\
	__o0;								\
})
#define internal_syscall2(string,name,args...)				\
  _internal_syscall2(string, "i", name, args)

#define _internal_syscall3(string,nc,name,arg1,arg2,arg3)		\
({									\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	long int _arg3 = (long int) (arg3);				\
	long int _name = (long int) (name);				\
	register long int __o0 __asm__ ("o0") = _arg1;			\
	register long int __o1 __asm__ ("o1") = _arg2;			\
	register long int __o2 __asm__ ("o2") = _arg3;			\
	__asm __volatile (string : "+r" (__o0) :			\
			  [scn] nc (_name), "r" (__o1),			\
			  "r" (__o2) :					\
			  __SYSCALL_CLOBBERS);				\
	__o0;								\
})
#define internal_syscall3(string,name,args...)				\
  _internal_syscall3(string, "i", name, args)

#define _internal_syscall4(string,nc,name,arg1,arg2,arg3,arg4)		\
({									\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	long int _arg3 = (long int) (arg3);				\
	long int _arg4 = (long int) (arg4);				\
	long int _name = (long int) (name);				\
	register long int __o0 __asm__ ("o0") = _arg1;			\
	register long int __o1 __asm__ ("o1") = _arg2;			\
	register long int __o2 __asm__ ("o2") = _arg3;			\
	register long int __o3 __asm__ ("o3") = _arg4;			\
	__asm __volatile (string : "+r" (__o0) :			\
			  [scn] nc (_name), "r" (__o1),			\
			  "r" (__o2), "r" (__o3) :			\
			  __SYSCALL_CLOBBERS);				\
	__o0;								\
})
#define internal_syscall4(string,name,args...)				\
  _internal_syscall4(string, "i", name, args)

#define _internal_syscall5(string,nc,name,arg1,arg2,arg3,arg4,arg5)	\
({									\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	long int _arg3 = (long int) (arg3);				\
	long int _arg4 = (long int) (arg4);				\
	long int _arg5 = (long int) (arg5);				\
	long int _name = (long int) (name);				\
	register long int __o0 __asm__ ("o0") = _arg1;			\
	register long int __o1 __asm__ ("o1") = _arg2;			\
	register long int __o2 __asm__ ("o2") = _arg3;			\
	register long int __o3 __asm__ ("o3") = _arg4;			\
	register long int __o4 __asm__ ("o4") = _arg5;			\
	__asm __volatile (string : "+r" (__o0) :			\
			  [scn] nc (_name), "r" (__o1),			\
			  "r" (__o2), "r" (__o3), "r" (__o4) :		\
			  __SYSCALL_CLOBBERS);				\
	__o0;								\
})
#define internal_syscall5(string,name,args...)				\
  _internal_syscall5(string, "i", name, args)

#define _internal_syscall6(string,nc,name,arg1,arg2,arg3,arg4,arg5,arg6)\
({									\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	long int _arg3 = (long int) (arg3);				\
	long int _arg4 = (long int) (arg4);				\
	long int _arg5 = (long int) (arg5);				\
	long int _arg6 = (long int) (arg6);				\
	long int _name = (long int) (name);				\
	register long int __o0 __asm__ ("o0") = _arg1;			\
	register long int __o1 __asm__ ("o1") = _arg2;			\
	register long int __o2 __asm__ ("o2") = _arg3;			\
	register long int __o3 __asm__ ("o3") = _arg4;			\
	register long int __o4 __asm__ ("o4") = _arg5;			\
	register long int __o5 __asm__ ("o5") = _arg6;			\
	__asm __volatile (string : "+r" (__o0) :			\
			  [scn] nc (_name), "r" (__o1),			\
			  "r" (__o2), "r" (__o3), "r" (__o4),		\
			  "r" (__o5) :					\
			  __SYSCALL_CLOBBERS);				\
	__o0;								\
})
#define internal_syscall6(string,name,args...)				\
  _internal_syscall6(string, "i", name, args)

#define INLINE_CLONE_SYSCALL(arg1,arg2,arg3,arg4,arg5)			\
({									\
	long int _arg1 = (long int) (arg1);				\
	long int _arg2 = (long int) (arg2);				\
	long int _arg3 = (long int) (arg3);				\
	long int _arg4 = (long int) (arg4);				\
	long int _arg5 = (long int) (arg5);				\
	long int _name = __NR_clone;					\
	register long int __o0 __asm__ ("o0") = _arg1;			\
	register long int __o1 __asm__ ("o1") = _arg2;			\
	register long int __o2 __asm__ ("o2") = _arg3;			\
	register long int __o3 __asm__ ("o3") = _arg4;			\
	register long int __o4 __asm__ ("o4") = _arg5;			\
	__asm __volatile (__SYSCALL_STRING :				\
			  "=r" (__o0), "=r" (__o1) :			\
			  [scn] "i" (_name), "0" (__o0), "1" (__o1),	\
			  "r" (__o2), "r" (__o3), "r" (__o4) :		\
			  __SYSCALL_CLOBBERS);				\
	if (__glibc_unlikely ((unsigned long int) (__o0) > -4096UL))	\
	  {		     			       		   	\
	    __set_errno (-__o0);					\
	    __o0 = -1L;			    				\
	  } 	      							\
	else								\
	  { 	      							\
	    __o0 &= (__o1 - 1);						\
	  } 	    	    						\
	__o0;								\
})

#endif	/* __ASSEMBLER__ */

#endif /* _LINUX_SPARC_SYSDEP_H */
