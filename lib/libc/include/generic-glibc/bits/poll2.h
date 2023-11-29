/* Checking macros for poll functions.
   Copyright (C) 2012-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_POLL_H
# error "Never include <bits/poll2.h> directly; use <sys/poll.h> instead."
#endif


__BEGIN_DECLS

extern int __REDIRECT (__poll_alias, (struct pollfd *__fds, nfds_t __nfds,
				      int __timeout), poll);
extern int __poll_chk (struct pollfd *__fds, nfds_t __nfds, int __timeout,
		       __SIZE_TYPE__ __fdslen)
    __attr_access ((__write_only__, 1, 2));
extern int __REDIRECT (__poll_chk_warn, (struct pollfd *__fds, nfds_t __nfds,
					 int __timeout, __SIZE_TYPE__ __fdslen),
		       __poll_chk)
  __warnattr ("poll called with fds buffer too small file nfds entries");

__fortify_function __fortified_attr_access (__write_only__, 1, 2) int
poll (struct pollfd *__fds, nfds_t __nfds, int __timeout)
{
  return __glibc_fortify (poll, __nfds, sizeof (*__fds),
			  __glibc_objsize (__fds),
			  __fds, __nfds, __timeout);
}


#ifdef __USE_GNU
# ifdef __USE_TIME_BITS64
extern int __REDIRECT (__ppoll64_alias, (struct pollfd *__fds, nfds_t __nfds,
				       const struct timespec *__timeout,
				       const __sigset_t *__ss), __ppoll64);
extern int __ppoll64_chk (struct pollfd *__fds, nfds_t __nfds,
			  const struct timespec *__timeout,
			  const __sigset_t *__ss, __SIZE_TYPE__ __fdslen)
    __attr_access ((__write_only__, 1, 2));
extern int __REDIRECT (__ppoll64_chk_warn, (struct pollfd *__fds, nfds_t __n,
					    const struct timespec *__timeout,
					    const __sigset_t *__ss,
					    __SIZE_TYPE__ __fdslen),
		       __ppoll64_chk)
  __warnattr ("ppoll called with fds buffer too small file nfds entries");

__fortify_function __fortified_attr_access (__write_only__, 1, 2) int
ppoll (struct pollfd *__fds, nfds_t __nfds, const struct timespec *__timeout,
       const __sigset_t *__ss)
{
  return __glibc_fortify (ppoll64, __nfds, sizeof (*__fds),
			  __glibc_objsize (__fds),
			  __fds, __nfds, __timeout, __ss);
}
# else
extern int __REDIRECT (__ppoll_alias, (struct pollfd *__fds, nfds_t __nfds,
				       const struct timespec *__timeout,
				       const __sigset_t *__ss), ppoll);
extern int __ppoll_chk (struct pollfd *__fds, nfds_t __nfds,
			const struct timespec *__timeout,
			const __sigset_t *__ss, __SIZE_TYPE__ __fdslen)
    __attr_access ((__write_only__, 1, 2));
extern int __REDIRECT (__ppoll_chk_warn, (struct pollfd *__fds, nfds_t __nfds,
					  const struct timespec *__timeout,
					  const __sigset_t *__ss,
					  __SIZE_TYPE__ __fdslen),
		       __ppoll_chk)
  __warnattr ("ppoll called with fds buffer too small file nfds entries");

__fortify_function __fortified_attr_access (__write_only__, 1, 2) int
ppoll (struct pollfd *__fds, nfds_t __nfds, const struct timespec *__timeout,
       const __sigset_t *__ss)
{
  return __glibc_fortify (ppoll, __nfds, sizeof (*__fds),
			  __glibc_objsize (__fds),
			  __fds, __nfds, __timeout, __ss);
}
# endif
#endif

__END_DECLS