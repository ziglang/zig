/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

/*
 * sys/statvfs.h
 */
#ifndef _SYS_STATVFS_H_
#define	_SYS_STATVFS_H_

#include <sys/_types.h>
#include <sys/cdefs.h>

#include <sys/_types/_fsblkcnt_t.h>
#include <sys/_types/_fsfilcnt_t.h>

/* Following structure is used as a statvfs/fstatvfs function parameter */
struct statvfs {
	unsigned long	f_bsize;	/* File system block size */
	unsigned long	f_frsize;	/* Fundamental file system block size */
	fsblkcnt_t	f_blocks;	/* Blocks on FS in units of f_frsize */
	fsblkcnt_t	f_bfree;	/* Free blocks */
	fsblkcnt_t	f_bavail;	/* Blocks available to non-root */
	fsfilcnt_t	f_files;	/* Total inodes */
	fsfilcnt_t	f_ffree;	/* Free inodes */
	fsfilcnt_t	f_favail;	/* Free inodes for non-root */
	unsigned long	f_fsid;		/* Filesystem ID */
	unsigned long	f_flag;		/* Bit mask of values */
	unsigned long	f_namemax;	/* Max file name length */
};

/* Defined bits for f_flag field value */
#define	ST_RDONLY	0x00000001	/* Read-only file system */
#define	ST_NOSUID	0x00000002	/* Does not honor setuid/setgid */

__BEGIN_DECLS
int fstatvfs(int, struct statvfs *);
int statvfs(const char * __restrict, struct statvfs * __restrict);
__END_DECLS

#endif	/* _SYS_STATVFS_H_ */