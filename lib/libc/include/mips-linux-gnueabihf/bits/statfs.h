/* Copyright (C) 1997-2024 Free Software Foundation, Inc.
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

#include <bits/types.h>  /* for __fsid_t and __fsblkcnt_t*/

struct statfs
  {
    long int f_type;
#define f_fstyp f_type
    long int f_bsize;
    long int f_frsize;	/* Fragment size - unsupported */
#ifndef __USE_FILE_OFFSET64
    __fsblkcnt_t f_blocks;
    __fsblkcnt_t f_bfree;
    __fsblkcnt_t f_files;
    __fsblkcnt_t f_ffree;
    __fsblkcnt_t f_bavail;
#else
    __fsblkcnt64_t f_blocks;
    __fsblkcnt64_t f_bfree;
    __fsblkcnt64_t f_files;
    __fsblkcnt64_t f_ffree;
    __fsblkcnt64_t f_bavail;
#endif

	/* Linux specials */
    __fsid_t f_fsid;
    long int f_namelen;
    long int f_flags;
    long int f_spare[5];
  };

#ifdef __USE_LARGEFILE64
struct statfs64
  {
    long int f_type;
#define f_fstyp f_type
    long int f_bsize;
    long int f_frsize;	/* Fragment size - unsupported */
    __fsblkcnt64_t f_blocks;
    __fsblkcnt64_t f_bfree;
    __fsblkcnt64_t f_files;
    __fsblkcnt64_t f_ffree;
    __fsblkcnt64_t f_bavail;

	/* Linux specials */
    __fsid_t f_fsid;
    long int f_namelen;
    long int f_flags;
    long int f_spare[5];
  };
#endif

/* Tell code we have these members.  */
#define _STATFS_F_NAMELEN