/* Copyright (C) 1996-2023 Free Software Foundation, Inc.
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

#include <sysdeps/unix/sysv/linux/sysdep.h>
#include <tls.h>

/* Defines RTLD_PRIVATE_ERRNO.  */
#include <dl-sysdep.h>

/* For Linux we can use the system call table in the header file
	/usr/include/asm/unistd.h
   of the kernel.  But these symbols do not follow the SYS_* syntax
   so we have to redefine the `SYS_ify' macro here.  */
#undef SYS_ify
#define SYS_ify(syscall_name)	__NR_##syscall_name

#ifdef __ASSEMBLER__

/* Linux uses a negative return value to indicate syscall errors, unlike
   most Unices, which use the condition codes' carry flag.

   Since version 2.1 the return value of a system call might be negative
   even if the call succeeded.  E.g., the `lseek' system call might return
   a large offset.  Therefore we must not anymore test for < 0, but test
   for a real error by making sure the value in %d0 is a real error
   number.  Linus said he will make sure the no syscall returns a value
   in -1 .. -4095 as a valid result so we can safely test with -4095.  */

/* We don't want the label for the error handler to be visible in the symbol
   table when we define it here.  */
#undef SYSCALL_ERROR_LABEL
#ifdef PIC
#define SYSCALL_ERROR_LABEL .Lsyscall_error
#else
#define SYSCALL_ERROR_LABEL __syscall_error
#endif

#undef PSEUDO
#define	PSEUDO(name, syscall_name, args)				      \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args);					      \
    cmp.l &-4095, %d0;							      \
    jcc SYSCALL_ERROR_LABEL

#undef PSEUDO_END
#define PSEUDO_END(name)						      \
  SYSCALL_ERROR_HANDLER;						      \
  END (name)

#undef PSEUDO_NOERRNO
#define	PSEUDO_NOERRNO(name, syscall_name, args)			      \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args)

#undef PSEUDO_END_NOERRNO
#define PSEUDO_END_NOERRNO(name)					      \
  END (name)

#define ret_NOERRNO rts

/* The function has to return the error code.  */
#undef	PSEUDO_ERRVAL
#define	PSEUDO_ERRVAL(name, syscall_name, args) \
  .text;								      \
  ENTRY (name)								      \
    DO_CALL (syscall_name, args);					      \
    negl %d0

#undef	PSEUDO_END_ERRVAL
#define	PSEUDO_END_ERRVAL(name) \
  END (name)

#define ret_ERRVAL rts

#ifdef PIC
# if RTLD_PRIVATE_ERRNO
#  define SYSCALL_ERROR_HANDLER						      \
SYSCALL_ERROR_LABEL:							      \
    PCREL_OP (lea, rtld_errno, %a0, %a0);				      \
    neg.l %d0;								      \
    move.l %d0, (%a0);							      \
    move.l &-1, %d0;							      \
    /* Copy return value to %a0 for syscalls that are declared to return      \
       a pointer (e.g., mmap).  */					      \
    move.l %d0, %a0;							      \
    rts;
# elif defined _LIBC_REENTRANT
#  if IS_IN (libc)
#   define SYSCALL_ERROR_ERRNO __libc_errno
#  else
#   define SYSCALL_ERROR_ERRNO errno
#  endif
#  define SYSCALL_ERROR_HANDLER						      \
SYSCALL_ERROR_LABEL:							      \
    neg.l %d0;								      \
    move.l %d0, -(%sp);							      \
    cfi_adjust_cfa_offset (4);						      \
    jbsr __m68k_read_tp@PLTPC;						      \
    SYSCALL_ERROR_LOAD_GOT (%a1);					      \
    add.l (SYSCALL_ERROR_ERRNO@TLSIE, %a1), %a0;			      \
    move.l (%sp)+, (%a0);						      \
    cfi_adjust_cfa_offset (-4);						      \
    move.l &-1, %d0;							      \
    /* Copy return value to %a0 for syscalls that are declared to return      \
       a pointer (e.g., mmap).  */					      \
    move.l %d0, %a0;							      \
    rts;
# else /* !_LIBC_REENTRANT */
/* Store (- %d0) into errno through the GOT.  */
#  define SYSCALL_ERROR_HANDLER						      \
SYSCALL_ERROR_LABEL:							      \
    move.l (errno@GOTPC, %pc), %a0;					      \
    neg.l %d0;								      \
    move.l %d0, (%a0);							      \
    move.l &-1, %d0;							      \
    /* Copy return value to %a0 for syscalls that are declared to return      \
       a pointer (e.g., mmap).  */					      \
    move.l %d0, %a0;							      \
    rts;
# endif /* _LIBC_REENTRANT */
#else
# define SYSCALL_ERROR_HANDLER	/* Nothing here; code in sysdep.S is used.  */
#endif /* PIC */

/* Linux takes system call arguments in registers:

	syscall number	%d0	     call-clobbered
	arg 1		%d1	     call-clobbered
	arg 2		%d2	     call-saved
	arg 3		%d3	     call-saved
	arg 4		%d4	     call-saved
	arg 5		%d5	     call-saved
	arg 6		%a0	     call-clobbered

   The stack layout upon entering the function is:

	24(%sp)		Arg# 6
	20(%sp)		Arg# 5
	16(%sp)		Arg# 4
	12(%sp)		Arg# 3
	 8(%sp)		Arg# 2
	 4(%sp)		Arg# 1
	  (%sp)		Return address

   (Of course a function with say 3 arguments does not have entries for
   arguments 4 and 5.)

   Separate move's are faster than movem, but need more space.  Since
   speed is more important, we don't use movem.  Since %a0 and %a1 are
   scratch registers, we can use them for saving as well.  */

#define DO_CALL(syscall_name, args)			      		      \
    move.l &SYS_ify(syscall_name), %d0;					      \
    DOARGS_##args							      \
    trap &0;								      \
    UNDOARGS_##args

#define	DOARGS_0	/* No arguments to frob.  */
#define	UNDOARGS_0	/* No arguments to unfrob.  */
#define	_DOARGS_0(n)	/* No arguments to frob.  */

#define	DOARGS_1	_DOARGS_1 (4)
#define	_DOARGS_1(n)	move.l n(%sp), %d1; _DOARGS_0 (n)
#define	UNDOARGS_1	UNDOARGS_0

#define	DOARGS_2	_DOARGS_2 (8)
#define	_DOARGS_2(n)	move.l %d2, %a0; cfi_register (%d2, %a0);	      \
			move.l n(%sp), %d2; _DOARGS_1 (n-4)
#define	UNDOARGS_2	UNDOARGS_1; move.l %a0, %d2; cfi_restore (%d2)

#define DOARGS_3	_DOARGS_3 (12)
#define _DOARGS_3(n)	move.l %d3, %a1; cfi_register (%d3, %a1);	      \
			move.l n(%sp), %d3; _DOARGS_2 (n-4)
#define UNDOARGS_3	UNDOARGS_2; move.l %a1, %d3; cfi_restore (%d3)

#define DOARGS_4	_DOARGS_4 (16)
#define _DOARGS_4(n)	move.l %d4, -(%sp);				      \
			cfi_adjust_cfa_offset (4); cfi_rel_offset (%d4, 0);   \
			move.l n+4(%sp), %d4; _DOARGS_3 (n)
#define UNDOARGS_4	UNDOARGS_3; move.l (%sp)+, %d4;			      \
			cfi_adjust_cfa_offset (-4); cfi_restore (%d4)

#define DOARGS_5	_DOARGS_5 (20)
#define _DOARGS_5(n)	move.l %d5, -(%sp); 				      \
			cfi_adjust_cfa_offset (4); cfi_rel_offset (%d5, 0);   \
			move.l n+4(%sp), %d5; _DOARGS_4 (n)
#define UNDOARGS_5	UNDOARGS_4; move.l (%sp)+, %d5;			      \
			cfi_adjust_cfa_offset (-4); cfi_restore (%d5)

#define DOARGS_6	_DOARGS_6 (24)
#define _DOARGS_6(n)	_DOARGS_5 (n-4); move.l %a0, -(%sp);		      \
			cfi_adjust_cfa_offset (4);			      \
			move.l n+12(%sp), %a0;
#define UNDOARGS_6	move.l (%sp)+, %a0; cfi_adjust_cfa_offset (-4);	      \
			UNDOARGS_5


#define	ret	rts
#if 0 /* Not used by Linux */
#define	r0	%d0
#define	r1	%d1
#define	MOVE(x,y)	movel x , y
#endif

#else /* not __ASSEMBLER__ */

/* Define a macro which expands inline into the wrapper code for a system
   call.  This use is for internal calls that do not need to handle errors
   normally.  It will never touch errno.  This returns just what the kernel
   gave back.  */
#undef INTERNAL_SYSCALL
#define INTERNAL_SYSCALL_NCS(name, nr, args...)	\
  ({ unsigned int _sys_result;				\
     {							\
       /* Load argument values in temporary variables
	  to perform side effects like function calls
	  before the call used registers are set.  */	\
       LOAD_ARGS_##nr (args)				\
       LOAD_REGS_##nr					\
       register int _d0 asm ("%d0") = name;		\
       asm volatile ("trap #0"				\
		     : "=d" (_d0)			\
		     : "0" (_d0) ASM_ARGS_##nr		\
		     : "memory");			\
       _sys_result = _d0;				\
     }							\
     (int) _sys_result; })
#define INTERNAL_SYSCALL(name, nr, args...)	\
  INTERNAL_SYSCALL_NCS (__NR_##name, nr, ##args)

#define LOAD_ARGS_0()
#define LOAD_REGS_0
#define ASM_ARGS_0
#define LOAD_ARGS_1(a1)				\
  LOAD_ARGS_0 ()				\
  int __arg1 = (int) (a1);
#define LOAD_REGS_1				\
  register int _d1 asm ("d1") = __arg1;		\
  LOAD_REGS_0
#define ASM_ARGS_1	ASM_ARGS_0, "d" (_d1)
#define LOAD_ARGS_2(a1, a2)			\
  LOAD_ARGS_1 (a1)				\
  int __arg2 = (int) (a2);
#define LOAD_REGS_2				\
  register int _d2 asm ("d2") = __arg2;		\
  LOAD_REGS_1
#define ASM_ARGS_2	ASM_ARGS_1, "d" (_d2)
#define LOAD_ARGS_3(a1, a2, a3)			\
  LOAD_ARGS_2 (a1, a2)				\
  int __arg3 = (int) (a3);
#define LOAD_REGS_3				\
  register int _d3 asm ("d3") = __arg3;		\
  LOAD_REGS_2
#define ASM_ARGS_3	ASM_ARGS_2, "d" (_d3)
#define LOAD_ARGS_4(a1, a2, a3, a4)		\
  LOAD_ARGS_3 (a1, a2, a3)			\
  int __arg4 = (int) (a4);
#define LOAD_REGS_4				\
  register int _d4 asm ("d4") = __arg4;		\
  LOAD_REGS_3
#define ASM_ARGS_4	ASM_ARGS_3, "d" (_d4)
#define LOAD_ARGS_5(a1, a2, a3, a4, a5)		\
  LOAD_ARGS_4 (a1, a2, a3, a4)			\
  int __arg5 = (int) (a5);
#define LOAD_REGS_5				\
  register int _d5 asm ("d5") = __arg5;		\
  LOAD_REGS_4
#define ASM_ARGS_5	ASM_ARGS_4, "d" (_d5)
#define LOAD_ARGS_6(a1, a2, a3, a4, a5, a6)	\
  LOAD_ARGS_5 (a1, a2, a3, a4, a5)		\
  int __arg6 = (int) (a6);
#define LOAD_REGS_6				\
  register int _a0 asm ("a0") = __arg6;		\
  LOAD_REGS_5
#define ASM_ARGS_6	ASM_ARGS_5, "a" (_a0)

#undef HAVE_INTERNAL_BRK_ADDR_SYMBOL
#define HAVE_INTERNAL_BRK_ADDR_SYMBOL 1

#endif /* not __ASSEMBLER__ */

/* M68K needs system-supplied DSO to access TLS helpers
   even when statically linked.  */
#define NEED_STATIC_SYSINFO_DSO 1
