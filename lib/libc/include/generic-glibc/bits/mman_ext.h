/* System-specific extensions of <sys/mman.h>, Linux version.
   Copyright (C) 2022-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_MMAN_H
# error "Never include <bits/mman_ext.h> directly; use <sys/mman.h> instead."
#endif

#ifdef __USE_GNU
struct iovec;
extern __ssize_t process_madvise (int __pid_fd, const struct iovec *__iov,
				  size_t __count, int __advice,
				  unsigned __flags)
  __THROW;

extern int process_mrelease (int pidfd, unsigned int flags) __THROW;

#endif /* __USE_GNU  */