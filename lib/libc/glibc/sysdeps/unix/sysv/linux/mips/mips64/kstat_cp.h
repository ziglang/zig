/* Struct stat/stat64 to stat/stat64 conversion for Linux.
   Copyright (C) 2020-2025 Free Software Foundation, Inc.
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

#include <sys/stat.h>
#include <kernel_stat.h>

static inline long int
__cp_kstat_stat (const struct kernel_stat *kst, struct stat *st)
{
  if (! in_ino_t_range (kst->st_ino)
      || ! in_off_t_range (kst->st_size)
      || ! in_blkcnt_t_range (kst->st_blocks))
    return -EOVERFLOW;

  st->st_dev = kst->st_dev;
  memset (&st->st_pad1, 0, sizeof (st->st_pad1));
  st->st_ino = kst->st_ino;
  st->st_mode = kst->st_mode;
  st->st_nlink = kst->st_nlink;
  st->st_uid = kst->st_uid;
  st->st_gid = kst->st_gid;
  st->st_rdev = kst->st_rdev;
  memset (&st->st_pad2, 0, sizeof (st->st_pad2));
  st->st_size = kst->st_size;
  st->st_pad3 = 0;
  st->st_atim.tv_sec = kst->st_atime_sec;
  st->st_atim.tv_nsec = kst->st_atime_nsec;
  st->st_mtim.tv_sec = kst->st_mtime_sec;
  st->st_mtim.tv_nsec = kst->st_mtime_nsec;
  st->st_ctim.tv_sec = kst->st_ctime_sec;
  st->st_ctim.tv_nsec = kst->st_ctime_nsec;
  st->st_blksize = kst->st_blksize;
  st->st_blocks = kst->st_blocks;
  memset (&st->st_pad5, 0, sizeof (st->st_pad5));

  return 0;
}

static inline void
__cp_kstat_stat64_t64 (const struct kernel_stat *kst, struct __stat64_t64 *st)
{
  st->st_dev = kst->st_dev;
  st->st_ino = kst->st_ino;
  st->st_mode = kst->st_mode;
  st->st_nlink = kst->st_nlink;
  st->st_uid = kst->st_uid;
  st->st_gid = kst->st_gid;
  st->st_rdev = kst->st_rdev;
  st->st_size = kst->st_size;
  st->st_blksize = kst->st_blksize;
  st->st_blocks = kst->st_blocks;
  st->st_atim.tv_sec = kst->st_atime_sec;
  st->st_atim.tv_nsec = kst->st_atime_nsec;
  st->st_mtim.tv_sec = kst->st_mtime_sec;
  st->st_mtim.tv_nsec = kst->st_mtime_nsec;
  st->st_ctim.tv_sec = kst->st_ctime_sec;
  st->st_ctim.tv_nsec = kst->st_ctime_nsec;
}
