/* Copyright (C) 2000-2024 Free Software Foundation, Inc.
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

#ifndef _SYS_TAS_H
#define _SYS_TAS_H 1

#include <features.h>
#include <sgidefs.h>

__BEGIN_DECLS

extern int _test_and_set (int *__p, int __v)
     __THROW __attribute__ ((__nomips16__));

#ifdef __USE_EXTERN_INLINES

# ifndef _EXTERN_INLINE
#  define _EXTERN_INLINE __extern_inline
# endif

_EXTERN_INLINE int __attribute__ ((__nomips16__))
__NTH (_test_and_set (int *__p, int __v))
{
  int __r, __t;

  /* The R5900 reports itself as MIPS III but it does not have LL/SC.  */
  __asm__ __volatile__
    ("/* Inline test and set */\n"
     ".set	push\n\t"
#if _MIPS_SIM == _ABIO32 && (__mips < 2 || defined (_MIPS_ARCH_R5900))
     ".set	mips2\n\t"
#endif
     "sync\n\t"
     "1:\n\t"
     "ll	%0,%3\n\t"
     "move	%1,%4\n\t"
     "beq	%0,%4,2f\n\t"
     "sc	%1,%2\n\t"
     "beqz	%1,1b\n"
     "sync\n\t"
     ".set	pop\n\t"
     "2:\n\t"
     "/* End test and set */"
     : "=&r" (__r), "=&r" (__t), "=m" (*__p)
     : "m" (*__p), "r" (__v)
     : "memory");

  return __r;
}

#endif /* __USE_EXTERN_INLINES */

__END_DECLS

#endif /* sys/tas.h */