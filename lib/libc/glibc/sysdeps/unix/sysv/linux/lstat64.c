/* Get file status.
   Copyright (C) 1996-2021 Free Software Foundation, Inc.
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

#define __lstat __redirect___lstat
#define lstat   __redirect_lstat
#include <sys/stat.h>
#include <fcntl.h>
#include <kernel_stat.h>
#include <stat_t64_cp.h>

int
__lstat64_time64 (const char *file, struct __stat64_t64 *buf)
{
  return __fstatat64_time64 (AT_FDCWD, file, buf, AT_SYMLINK_NOFOLLOW);
}
#if __TIMESIZE != 64
hidden_def (__lstat64_time64)

int
__lstat64 (const char *file, struct stat64 *buf)
{
  struct __stat64_t64 st_t64;
  return __lstat64_time64 (file, &st_t64)
	 ?: __cp_stat64_t64_stat64 (&st_t64, buf);
}
#endif
hidden_def (__lstat64)
weak_alias (__lstat64, lstat64)

#undef __lstat
#undef lstat

#if XSTAT_IS_XSTAT64
strong_alias (__lstat64, __lstat)
weak_alias (__lstat64, lstat)
#endif
