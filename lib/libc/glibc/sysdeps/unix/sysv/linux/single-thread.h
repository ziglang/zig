/* Single thread optimization, Linux version.
   Copyright (C) 2019-2020 Free Software Foundation, Inc.
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

#ifndef _SINGLE_THREAD_H
#define _SINGLE_THREAD_H

/* The default way to check if the process is single thread is by using the
   pthread_t 'multiple_threads' field.  However, for some architectures it is
   faster to either use an extra field on TCB or global variables (the TCB
   field is also used on x86 for some single-thread atomic optimizations).

   The ABI might define SINGLE_THREAD_BY_GLOBAL to enable the single thread
   check to use global variables instead of the pthread_t field.  */

#ifdef SINGLE_THREAD_BY_GLOBAL
# if IS_IN (libc)
extern int __libc_multiple_threads;
#  define SINGLE_THREAD_P \
  __glibc_likely (__libc_multiple_threads == 0)
# elif IS_IN (libpthread)
extern int __pthread_multiple_threads;
#  define SINGLE_THREAD_P \
  __glibc_likely (__pthread_multiple_threads == 0)
# elif IS_IN (librt)
#   define SINGLE_THREAD_P					\
  __glibc_likely (THREAD_GETMEM (THREAD_SELF,			\
				 header.multiple_threads) == 0)
# else
/* For rtld, et cetera.  */
#  define SINGLE_THREAD_P (1)
# endif
#else /* SINGLE_THREAD_BY_GLOBAL  */
# if IS_IN (libc) || IS_IN (libpthread) || IS_IN (librt)
#   define SINGLE_THREAD_P					\
  __glibc_likely (THREAD_GETMEM (THREAD_SELF,			\
				 header.multiple_threads) == 0)
# else
/* For rtld, et cetera.  */
#  define SINGLE_THREAD_P (1)
# endif
#endif /* SINGLE_THREAD_BY_GLOBAL  */

#define RTLD_SINGLE_THREAD_P \
  __glibc_likely (THREAD_GETMEM (THREAD_SELF, \
				 header.multiple_threads) == 0)

#endif /* _SINGLE_THREAD_H  */
