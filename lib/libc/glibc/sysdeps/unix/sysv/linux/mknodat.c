/* Create a special or ordinary file.  Linux version.
   Copyright (C) 2020-2023 Free Software Foundation, Inc.
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

#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <sysdep.h>

int
__mknodat (int fd, const char *path, mode_t mode, dev_t dev)
{
  /* The user-exported dev_t is 64-bit while the kernel interface is
     32-bit.  */
  unsigned int k_dev = dev;
  if (k_dev != dev)
    return INLINE_SYSCALL_ERROR_RETURN_VALUE (EINVAL);

  return INLINE_SYSCALL_CALL (mknodat, fd, path, mode, k_dev);
}
libc_hidden_def (__mknodat)
weak_alias (__mknodat, mknodat)
