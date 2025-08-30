/* Checking macros for socket functions.
   Copyright (C) 2005-2025 Free Software Foundation, Inc.
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

#ifndef _SYS_SOCKET_H
# error "Never include <bits/socket2.h> directly; use <sys/socket.h> instead."
#endif

extern ssize_t __recv_chk (int __fd, void *__buf, size_t __n, size_t __buflen,
			   int __flags);
extern ssize_t __REDIRECT (__recv_alias, (int __fd, void *__buf, size_t __n,
					  int __flags), recv);
extern ssize_t __REDIRECT (__recv_chk_warn,
			   (int __fd, void *__buf, size_t __n, size_t __buflen,
			    int __flags), __recv_chk)
     __warnattr ("recv called with bigger length than size of destination "
		 "buffer");

__fortify_function __attribute_overloadable__ ssize_t
recv (int __fd, __fortify_clang_overload_arg0 (void *, ,__buf), size_t __n,
      int __flags)
     __fortify_clang_warning_only_if_bos0_lt (__n, __buf,
					      "recv called with bigger length than "
					      "size of destination buffer")
{
  size_t __sz = __glibc_objsize0 (__buf);
  if (__glibc_safe_or_unknown_len (__n, sizeof (char), __sz))
    return __recv_alias (__fd, __buf, __n, __flags);
#if !__fortify_use_clang
  if (__glibc_unsafe_len (__n, sizeof (char), __sz))
    return __recv_chk_warn (__fd, __buf, __n, __sz, __flags);
#endif
  return __recv_chk (__fd, __buf, __n, __sz, __flags);
}

extern ssize_t __recvfrom_chk (int __fd, void *__restrict __buf, size_t __n,
			       size_t __buflen, int __flags,
			       __SOCKADDR_ARG __addr,
			       socklen_t *__restrict __addr_len);
extern ssize_t __REDIRECT (__recvfrom_alias,
			   (int __fd, void *__restrict __buf, size_t __n,
			    int __flags, __SOCKADDR_ARG __addr,
			    socklen_t *__restrict __addr_len), recvfrom);
extern ssize_t __REDIRECT (__recvfrom_chk_warn,
			   (int __fd, void *__restrict __buf, size_t __n,
			    size_t __buflen, int __flags,
			    __SOCKADDR_ARG __addr,
			    socklen_t *__restrict __addr_len), __recvfrom_chk)
     __warnattr ("recvfrom called with bigger length than size of "
		 "destination buffer");

__fortify_function __attribute_overloadable__ ssize_t
recvfrom (int __fd, __fortify_clang_overload_arg0 (void *, __restrict, __buf),
	  size_t __n, int __flags,
	  __SOCKADDR_ARG __addr, socklen_t *__restrict __addr_len)
     __fortify_clang_warning_only_if_bos0_lt (__n, __buf,
					      "recvfrom called with bigger length "
					      "than size of destination buffer")
{
  size_t __sz = __glibc_objsize0 (__buf);
  if (__glibc_safe_or_unknown_len (__n, sizeof (char), __sz))
    return __recvfrom_alias (__fd, __buf, __n, __flags, __addr, __addr_len);
#if !__fortify_use_clang
  if (__glibc_unsafe_len (__n, sizeof (char), __sz))
    return __recvfrom_chk_warn (__fd, __buf, __n, __sz, __flags, __addr,
				__addr_len);
#endif
  return __recvfrom_chk (__fd, __buf, __n, __sz, __flags, __addr, __addr_len);
}