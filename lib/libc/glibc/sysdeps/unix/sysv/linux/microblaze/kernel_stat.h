/* Definition of `struct stat' used in the kernel
   Copyright (C) 2013-2023 Free Software Foundation, Inc.

   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License as
   published by the Free Software Foundation; either version 2.1 of the
   License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

struct kernel_stat
{
        unsigned long   st_dev;         /* Device.  */
        unsigned long   st_ino;         /* File serial number.  */
        unsigned int    st_mode;        /* File mode.  */
        unsigned int    st_nlink;       /* Link count.  */
        unsigned int    st_uid;         /* User ID of the file's owner.  */
        unsigned int    st_gid;         /* Group ID of the file's group.  */
        unsigned long   st_rdev;        /* Device number, if device.  */
        unsigned long   __pad2;
#define _HAVE_STAT___PAD2
#define _HAVE_STAT64___PAD2
        long            st_size;        /* Size of file, in bytes.  */
        int             st_blksize;     /* Optimal block size for I/O.  */
        int             __pad3;
#define _HAVE_STAT___PAD3
#define _HAVE_STAT64___PAD3
        long            st_blocks;      /* Number 512-byte blocks allocated.  */
        struct timespec st_atim;
        struct timespec st_mtim;
        struct timespec st_ctim;
#define _HAVE_STAT_NSEC
#define _HAVE_STAT64_NSEC
        unsigned int    __glibc_reserved4;
#define _HAVE_STAT___UNUSED4
#define _HAVE_STAT64___UNUSED4
        unsigned int    __glibc_reserved5;
#define _HAVE_STAT___UNUSED5
#define _HAVE_STAT64___UNUSED5
};

#define STAT_IS_KERNEL_STAT 0
#define STAT64_IS_KERNEL_STAT64 1
#define XSTAT_IS_XSTAT64 0
#define STATFS_IS_STATFS64 0
