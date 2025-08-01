/* Checking macros for inet functions.
   Copyright (C) 2025 Free Software Foundation, Inc.
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

#ifndef _BITS_INET_FORTIFIED_H
#define _BITS_INET_FORTIFIED_H 1

#ifndef _ARPA_INET_H
# error "Never include <bits/inet-fortified.h> directly; use <arpa/inet.h> instead."
#endif

#include <bits/inet-fortified-decl.h>

__fortify_function __attribute_overloadable__ const char *
__NTH (inet_ntop (int __af,
	   __fortify_clang_overload_arg (const void *, __restrict, __src),
	   char *__restrict __dst, socklen_t __dst_size))
    __fortify_clang_warning_only_if_bos_lt (__dst_size, __dst,
					    "inet_ntop called with bigger length "
					    "than size of destination buffer")
{
  return __glibc_fortify (inet_ntop, __dst_size, sizeof (char),
			  __glibc_objsize (__dst),
			  __af, __src, __dst, __dst_size);
};

__fortify_function __attribute_overloadable__ int
__NTH (inet_pton (int __af,
	   const char *__restrict __src,
	   __fortify_clang_overload_arg (void *, __restrict, __dst)))
    __fortify_clang_warning_only_if_bos0_lt
	(4, __dst, "inet_pton called with destination buffer size less than 4")
{
  size_t sz = 0;
  if (__af == AF_INET)
    sz = sizeof (struct in_addr);
  else if (__af == AF_INET6)
    sz = sizeof (struct in6_addr);
  else
    return __inet_pton_alias (__af, __src, __dst);

  return __glibc_fortify (inet_pton, sz, sizeof (char),
			  __glibc_objsize (__dst),
			  __af, __src, __dst);
};

#endif /* bits/inet-fortified.h.  */