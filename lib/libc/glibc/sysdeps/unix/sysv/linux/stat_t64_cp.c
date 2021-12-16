/* Struct stat/stat64 to stat/stat64 conversion for Linux.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#include <stat_t64_cp.h>
#include <string.h>
#include <errno.h>
#include <time.h>

#if __TIMESIZE != 64

static inline bool
in_time_t_range (__time64_t t)
{
  time_t s = t;
  return s == t;
}

static inline struct timespec
valid_timespec64_to_timespec (const struct __timespec64 ts64)
{
  struct timespec ts;

  ts.tv_sec = (time_t) ts64.tv_sec;
  ts.tv_nsec = ts64.tv_nsec;

  return ts;
}

int
__cp_stat64_t64_stat64 (const struct __stat64_t64 *st64_t64,
			struct stat64 *st64)
{
  if (! in_time_t_range (st64_t64->st_atim.tv_sec)
      || ! in_time_t_range (st64_t64->st_mtim.tv_sec)
      || ! in_time_t_range (st64_t64->st_ctim.tv_sec))
    {
      __set_errno (EOVERFLOW);
      return -1;
    }

  /* Clear both pad and reserved fields.  */
  memset (st64, 0, sizeof (*st64));

  st64->st_dev = st64_t64->st_dev,
  st64->st_ino = st64_t64->st_ino;
  st64->st_mode = st64_t64->st_mode;
  st64->st_nlink = st64_t64->st_nlink;
  st64->st_uid = st64_t64->st_uid;
  st64->st_gid = st64_t64->st_gid;
  st64->st_rdev = st64_t64->st_rdev;
  st64->st_size = st64_t64->st_size;
  st64->st_blksize = st64_t64->st_blksize;
  st64->st_blocks  = st64_t64->st_blocks;
  st64->st_atim = valid_timespec64_to_timespec (st64_t64->st_atim);
  st64->st_mtim = valid_timespec64_to_timespec (st64_t64->st_mtim);
  st64->st_ctim = valid_timespec64_to_timespec (st64_t64->st_ctim);

  return 0;
}
#endif
