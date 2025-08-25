/* Struct kernel_stat64 to stat64.  Linux/SPARC version.
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

#include <errno.h>

static inline void
__cp_stat64_kstat64 (struct stat64 *st64, const struct kernel_stat64 *kst64)
{
  st64->st_dev = kst64->st_dev;
  st64->__pad1 = 0;
  st64->st_ino = kst64->st_ino;
  st64->st_mode = kst64->st_mode;
  st64->st_nlink = kst64->st_nlink;
  st64->st_uid = kst64->st_uid;
  st64->st_gid = kst64->st_gid;
  st64->st_rdev = kst64->st_rdev;
  st64->__pad2 = 0;
  st64->st_size = kst64->st_size;
  st64->st_blksize = kst64->st_blksize;
  st64->st_blocks = kst64->st_blocks;
  st64->st_atim.tv_sec = kst64->st_atime_sec;
  st64->st_atim.tv_nsec = kst64->st_atime_nsec;
  st64->st_mtim.tv_sec = kst64->st_mtime_sec;
  st64->st_mtim.tv_nsec = kst64->st_mtime_nsec;
  st64->st_ctim.tv_sec = kst64->st_ctime_sec;
  st64->st_ctim.tv_nsec = kst64->st_ctime_nsec;
  st64->__glibc_reserved4 = 0;
  st64->__glibc_reserved5 = 0;
}
