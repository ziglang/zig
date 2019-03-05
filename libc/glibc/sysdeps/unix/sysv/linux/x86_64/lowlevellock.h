/* Copyright (C) 2002-2019 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@redhat.com>, 2002.

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
   <http://www.gnu.org/licenses/>.  */

#ifndef _LOWLEVELLOCK_H
#define _LOWLEVELLOCK_H	1

#include <stap-probe.h>

#ifndef __ASSEMBLER__
# include <time.h>
# include <sys/param.h>
# include <bits/pthreadtypes.h>
# include <kernel-features.h>

# ifndef LOCK_INSTR
#  ifdef UP
#   define LOCK_INSTR	/* nothing */
#  else
#   define LOCK_INSTR "lock;"
#  endif
# endif
#else
# ifndef LOCK
#  ifdef UP
#   define LOCK
#  else
#   define LOCK lock
#  endif
# endif
#endif

#include <lowlevellock-futex.h>

/* XXX Remove when no assembler code uses futexes anymore.  */
#define SYS_futex		__NR_futex

#ifndef __ASSEMBLER__

/* Initializer for lock.  */
#define LLL_LOCK_INITIALIZER		(0)
#define LLL_LOCK_INITIALIZER_LOCKED	(1)
#define LLL_LOCK_INITIALIZER_WAITERS	(2)


/* NB: in the lll_trylock macro we simply return the value in %eax
   after the cmpxchg instruction.  In case the operation succeded this
   value is zero.  In case the operation failed, the cmpxchg instruction
   has loaded the current value of the memory work which is guaranteed
   to be nonzero.  */
#if !IS_IN (libc) || defined UP
# define __lll_trylock_asm LOCK_INSTR "cmpxchgl %2, %1"
#else
# define __lll_trylock_asm "cmpl $0, __libc_multiple_threads(%%rip)\n\t"      \
			   "je 0f\n\t"					      \
			   "lock; cmpxchgl %2, %1\n\t"			      \
			   "jmp 1f\n\t"					      \
			   "0:\tcmpxchgl %2, %1\n\t"			      \
			   "1:"
#endif

#define lll_trylock(futex) \
  ({ int ret;								      \
     __asm __volatile (__lll_trylock_asm				      \
		       : "=a" (ret), "=m" (futex)			      \
		       : "r" (LLL_LOCK_INITIALIZER_LOCKED), "m" (futex),      \
			 "0" (LLL_LOCK_INITIALIZER)			      \
		       : "memory");					      \
     ret; })

#define lll_cond_trylock(futex) \
  ({ int ret;								      \
     __asm __volatile (LOCK_INSTR "cmpxchgl %2, %1"			      \
		       : "=a" (ret), "=m" (futex)			      \
		       : "r" (LLL_LOCK_INITIALIZER_WAITERS),		      \
			 "m" (futex), "0" (LLL_LOCK_INITIALIZER)	      \
		       : "memory");					      \
     ret; })

#if !IS_IN (libc) || defined UP
# define __lll_lock_asm_start LOCK_INSTR "cmpxchgl %4, %2\n\t"		      \
			      "jz 24f\n\t"
#else
# define __lll_lock_asm_start "cmpl $0, __libc_multiple_threads(%%rip)\n\t"   \
			      "je 0f\n\t"				      \
			      "lock; cmpxchgl %4, %2\n\t"		      \
			      "jnz 1f\n\t"				      \
			      "jmp 24f\n"				      \
			      "0:\tcmpxchgl %4, %2\n\t"			      \
			      "jz 24f\n\t"
#endif

#define lll_lock(futex, private) \
  (void)								      \
    ({ int ignore1, ignore2, ignore3;					      \
       if (__builtin_constant_p (private) && (private) == LLL_PRIVATE)	      \
	 __asm __volatile (__lll_lock_asm_start				      \
			   "1:\tlea %2, %%" RDI_LP "\n"			      \
			   "2:\tsub $128, %%" RSP_LP "\n"		      \
			   ".cfi_adjust_cfa_offset 128\n"		      \
			   "3:\tcallq __lll_lock_wait_private\n"	      \
			   "4:\tadd $128, %%" RSP_LP "\n"		      \
			   ".cfi_adjust_cfa_offset -128\n"		      \
			   "24:"					      \
			   : "=S" (ignore1), "=&D" (ignore2), "=m" (futex),   \
			     "=a" (ignore3)				      \
			   : "0" (1), "m" (futex), "3" (0)		      \
			   : "cx", "r11", "cc", "memory");		      \
       else								      \
	 __asm __volatile (__lll_lock_asm_start				      \
			   "1:\tlea %2, %%" RDI_LP "\n"			      \
			   "2:\tsub $128, %%" RSP_LP "\n"		      \
			   ".cfi_adjust_cfa_offset 128\n"		      \
			   "3:\tcallq __lll_lock_wait\n"		      \
			   "4:\tadd $128, %%" RSP_LP "\n"		      \
			   ".cfi_adjust_cfa_offset -128\n"		      \
			   "24:"					      \
			   : "=S" (ignore1), "=D" (ignore2), "=m" (futex),    \
			     "=a" (ignore3)				      \
			   : "1" (1), "m" (futex), "3" (0), "0" (private)     \
			   : "cx", "r11", "cc", "memory");		      \
    })									      \

#define lll_cond_lock(futex, private) \
  (void)								      \
    ({ int ignore1, ignore2, ignore3;					      \
       __asm __volatile (LOCK_INSTR "cmpxchgl %4, %2\n\t"		      \
			 "jz 24f\n"					      \
			 "1:\tlea %2, %%" RDI_LP "\n"			      \
			 "2:\tsub $128, %%" RSP_LP "\n"			      \
			 ".cfi_adjust_cfa_offset 128\n"			      \
			 "3:\tcallq __lll_lock_wait\n"			      \
			 "4:\tadd $128, %%" RSP_LP "\n"			      \
			 ".cfi_adjust_cfa_offset -128\n"		      \
			 "24:"						      \
			 : "=S" (ignore1), "=D" (ignore2), "=m" (futex),      \
			   "=a" (ignore3)				      \
			 : "1" (2), "m" (futex), "3" (0), "0" (private)	      \
			 : "cx", "r11", "cc", "memory");		      \
    })

#define lll_timedlock(futex, timeout, private) \
  ({ int result, ignore1, ignore2, ignore3;				      \
     __asm __volatile (LOCK_INSTR "cmpxchgl %1, %4\n\t"			      \
		       "jz 24f\n"					      \
		       "1:\tlea %4, %%" RDI_LP "\n"			      \
		       "0:\tmov %8, %%" RDX_LP "\n"			      \
		       "2:\tsub $128, %%" RSP_LP "\n"			      \
		       ".cfi_adjust_cfa_offset 128\n"			      \
		       "3:\tcallq __lll_timedlock_wait\n"		      \
		       "4:\tadd $128, %%" RSP_LP "\n"			      \
		       ".cfi_adjust_cfa_offset -128\n"			      \
		       "24:"						      \
		       : "=a" (result), "=D" (ignore1), "=S" (ignore2),	      \
			 "=&d" (ignore3), "=m" (futex)			      \
		       : "0" (0), "1" (1), "m" (futex), "m" (timeout),	      \
			 "2" (private)					      \
		       : "memory", "cx", "cc", "r10", "r11");		      \
     result; })

extern int __lll_timedlock_elision (int *futex, short *adapt_count,
					 const struct timespec *timeout,
					 int private) attribute_hidden;

#define lll_timedlock_elision(futex, adapt_count, timeout, private)	\
  __lll_timedlock_elision(&(futex), &(adapt_count), timeout, private)

#if !IS_IN (libc) || defined UP
# define __lll_unlock_asm_start LOCK_INSTR "decl %0\n\t"		      \
				"je 24f\n\t"
#else
# define __lll_unlock_asm_start "cmpl $0, __libc_multiple_threads(%%rip)\n\t" \
				"je 0f\n\t"				      \
				"lock; decl %0\n\t"			      \
				"jne 1f\n\t"				      \
				"jmp 24f\n\t"				      \
				"0:\tdecl %0\n\t"			      \
				"je 24f\n\t"
#endif

#define lll_unlock(futex, private) \
  (void)								      \
    ({ int ignore;							      \
       if (__builtin_constant_p (private) && (private) == LLL_PRIVATE)	      \
	 __asm __volatile (__lll_unlock_asm_start			      \
			   "1:\tlea %0, %%" RDI_LP "\n"			      \
			   "2:\tsub $128, %%" RSP_LP "\n"		      \
			   ".cfi_adjust_cfa_offset 128\n"		      \
			   "3:\tcallq __lll_unlock_wake_private\n"	      \
			   "4:\tadd $128, %%" RSP_LP "\n"		      \
			   ".cfi_adjust_cfa_offset -128\n"		      \
			   "24:"					      \
			   : "=m" (futex), "=&D" (ignore)		      \
			   : "m" (futex)				      \
			   : "ax", "cx", "r11", "cc", "memory");	      \
       else								      \
	 __asm __volatile (__lll_unlock_asm_start			      \
			   "1:\tlea %0, %%" RDI_LP "\n"			      \
			   "2:\tsub $128, %%" RSP_LP "\n"		      \
			   ".cfi_adjust_cfa_offset 128\n"		      \
			   "3:\tcallq __lll_unlock_wake\n"		      \
			   "4:\tadd $128, %%" RSP_LP "\n"		      \
			   ".cfi_adjust_cfa_offset -128\n"		      \
			   "24:"					      \
			   : "=m" (futex), "=&D" (ignore)		      \
			   : "m" (futex), "S" (private)			      \
			   : "ax", "cx", "r11", "cc", "memory");	      \
    })

#define lll_islocked(futex) \
  (futex != LLL_LOCK_INITIALIZER)

extern int __lll_timedwait_tid (int *, const struct timespec *)
     attribute_hidden;

/* The kernel notifies a process which uses CLONE_CHILD_CLEARTID via futex
   wake-up when the clone terminates.  The memory location contains the
   thread ID while the clone is running and is reset to zero by the kernel
   afterwards.  The kernel up to version 3.16.3 does not use the private futex
   operations for futex wake-up when the clone terminates.
   If ABSTIME is not NULL, is used a timeout for futex call.  If the timeout
   occurs then return ETIMEOUT, if ABSTIME is invalid, return EINVAL.
   The futex operation are issues with cancellable versions.  */
#define lll_wait_tid(tid, abstime)					\
  ({									\
    int __res = 0;							\
    __typeof (tid) __tid;						\
    if (abstime != NULL)						\
      __res = __lll_timedwait_tid (&(tid), (abstime));			\
    else								\
      /* We need acquire MO here so that we synchronize with the 	\
	 kernel's store to 0 when the clone terminates. (see above)  */	\
      while ((__tid = atomic_load_acquire (&(tid))) != 0)		\
        lll_futex_wait_cancel (&(tid), __tid, LLL_SHARED);		\
    __res;								\
  })

extern int __lll_lock_elision (int *futex, short *adapt_count, int private)
  attribute_hidden;

extern int __lll_unlock_elision (int *lock, int private)
  attribute_hidden;

extern int __lll_trylock_elision (int *lock, short *adapt_count)
  attribute_hidden;

#define lll_lock_elision(futex, adapt_count, private) \
  __lll_lock_elision (&(futex), &(adapt_count), private)
#define lll_unlock_elision(futex, adapt_count, private) \
  __lll_unlock_elision (&(futex), private)
#define lll_trylock_elision(futex, adapt_count) \
  __lll_trylock_elision (&(futex), &(adapt_count))

#endif  /* !__ASSEMBLER__ */

#endif	/* lowlevellock.h */
