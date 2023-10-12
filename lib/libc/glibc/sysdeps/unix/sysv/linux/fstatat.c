/* Get file status.  Linux version.
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

#include <sys/stat.h>
#include <kernel_stat.h>
#include <sysdep.h>

#if !XSTAT_IS_XSTAT64
int
__fstatat (int fd, const char *file, struct stat *buf, int flag)
{
  struct __stat64_t64 st64;
  int r = __fstatat64_time64 (fd, file, &st64, flag);
  if (r == 0)
    {
      if (! in_ino_t_range (st64.st_ino)
	  || ! in_off_t_range (st64.st_size)
	  || ! in_blkcnt_t_range (st64.st_blocks)
	  || ! in_time_t_range (st64.st_atim.tv_sec)
	  || ! in_time_t_range (st64.st_mtim.tv_sec)
	  || ! in_time_t_range (st64.st_ctim.tv_sec))
	return INLINE_SYSCALL_ERROR_RETURN_VALUE (EOVERFLOW);

      /* Clear internal pad and reserved fields.  */
      memset (buf, 0, sizeof (*buf));

      buf->st_dev = st64.st_dev;
      buf->st_ino = st64.st_ino;
      buf->st_mode = st64.st_mode;
      buf->st_nlink = st64.st_nlink;
      buf->st_uid = st64.st_uid;
      buf->st_gid = st64.st_gid;
      buf->st_rdev = st64.st_rdev;
      buf->st_size = st64.st_size;
      buf->st_blksize = st64.st_blksize;
      buf->st_blocks  = st64.st_blocks;
      buf->st_atim = valid_timespec64_to_timespec (st64.st_atim);
      buf->st_mtim = valid_timespec64_to_timespec (st64.st_mtim);
      buf->st_ctim = valid_timespec64_to_timespec (st64.st_ctim);
    }
  return r;
}

weak_alias (__fstatat, fstatat)
#endif
