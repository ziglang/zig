/* Copyright (C) 2011-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_STATFS_H
# error "Never include <bits/statfs.h> directly; use <sys/statfs.h> instead."
#endif

#include <bits/endian.h>
#include <bits/types.h>
#include <bits/wordsize.h>

#if defined __USE_FILE_OFFSET64
# define __field64(type, type64, name) type64 name
#elif __BYTE_ORDER == __LITTLE_ENDIAN
# define __field64(type, type64, name) \
  type name __attribute__((__aligned__ (__alignof__ (type64)))); int __##name##_pad
#else
# define __field64(type, type64, name) \
  int __##name##_pad __attribute__((__aligned__ (__alignof__ (type64)))); type name
#endif

struct statfs
  {
    __SWORD_TYPE f_type;
    __SWORD_TYPE f_bsize;
    __field64(__fsblkcnt_t, __fsblkcnt64_t, f_blocks);
    __field64(__fsblkcnt_t, __fsblkcnt64_t, f_bfree);
    __field64(__fsblkcnt_t, __fsblkcnt64_t, f_bavail);
    __field64(__fsfilcnt_t, __fsfilcnt64_t, f_files);
    __field64(__fsfilcnt_t, __fsfilcnt64_t, f_ffree);
    __fsid_t f_fsid;
    __SWORD_TYPE f_namelen;
    __SWORD_TYPE f_frsize;
    __SWORD_TYPE f_flags;
    __SWORD_TYPE f_spare[4];
  };

#undef __field64

#ifdef __USE_LARGEFILE64
struct statfs64
  {
    __SWORD_TYPE f_type;
    __SWORD_TYPE f_bsize;
    __fsblkcnt64_t f_blocks;
    __fsblkcnt64_t f_bfree;
    __fsblkcnt64_t f_bavail;
    __fsfilcnt64_t f_files;
    __fsfilcnt64_t f_ffree;
    __fsid_t f_fsid;
    __SWORD_TYPE f_namelen;
    __SWORD_TYPE f_frsize;
    __SWORD_TYPE f_flags;
    __SWORD_TYPE f_spare[4];
  };
#endif

/* Tell code we have these members.  */
#define _STATFS_F_NAMELEN
#define _STATFS_F_FRSIZE
#define _STATFS_F_FLAGS