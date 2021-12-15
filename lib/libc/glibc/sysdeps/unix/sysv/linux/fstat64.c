/* Get file status.  Linux version.
   Copyright (C) 2020-2021 Free Software Foundation, Inc.
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

#define __fstat __redirect___fstat
#define fstat   __redirect_fstat
#include <sys/stat.h>
#include <fcntl.h>
#include <kernel_stat.h>
#include <stat_t64_cp.h>
#include <errno.h>

int
__fstat64_time64 (int fd, struct __stat64_t64 *buf)
{
  if (fd < 0)
    {
      __set_errno (EBADF);
      return -1;
    }
  return __fstatat64_time64 (fd, "", buf, AT_EMPTY_PATH);
}
#if __TIMESIZE != 64
hidden_def (__fstat64_time64)

int
__fstat64 (int fd, struct stat64 *buf)
{
  if (fd < 0)
    {
      __set_errno (EBADF);
      return -1;
    }

  struct __stat64_t64 st_t64;
  return __fstat64_time64 (fd, &st_t64)
	 ?: __cp_stat64_t64_stat64 (&st_t64, buf);
}
#endif

#undef __fstat
#undef fstat

hidden_def (__fstat64)
weak_alias (__fstat64, fstat64)

#if XSTAT_IS_XSTAT64
strong_alias (__fstat64, __fstat)
weak_alias (__fstat64, fstat)
#endif
