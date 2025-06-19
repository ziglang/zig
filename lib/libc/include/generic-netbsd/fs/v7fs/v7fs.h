/*	$NetBSD: v7fs.h,v 1.4 2022/05/24 06:28:01 andvar Exp $	*/

/*-
 * Copyright (c) 2011 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by UCHIYAMA Yasushi.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _V7FS_H_
/* 7th Edition of Unix(PDP-11) Filesystem definition. */
#define	_V7FS_H_
#include <sys/types.h>
#ifndef _KERNEL
#include <inttypes.h>
#endif
/*
 *   V7 File System
 *
 *     +------------------
 *     |Boot block (512byte)	sector [0]
 *     |
 *     +------------------
 *     |Super block (512byte)	sector [1]
 *     |
 *     +------------------
 *     |v7fs_inode(64byte       sector [2]
 *         .
 *         .
 *     |
 *     +------------------
 *     |data block              sector [datablock_start_sector]
 *     |
 *         .
 *         .
 *     |
 *     +------------------
 *				 <-    [sector volume_size]
 *
 *     |
 *     +------------------	volume size.
 *
 * Max volume size is 8GB (24bit daddr_t)
 * Max file size is ~1GB
 *
 */

/* V7 type. */
typedef uint16_t v7fs_ino_t;
typedef uint32_t v7fs_daddr_t;
typedef int32_t v7fs_time_t;
typedef uint32_t v7fs_off_t;
typedef uint16_t v7fs_dev_t;
typedef uint16_t v7fs_mode_t;
#define	V7FS_DADDR_MAX		0x00ffffff
#define	V7FS_INODE_MAX		0xffff

#define	V7FS_BSIZE		512
#define	V7FS_BSHIFT		9
#define	V7FS_ROUND_BSIZE(x)					\
	((((x) + (V7FS_BSIZE - 1)) & ~(V7FS_BSIZE - 1)))
#define	V7FS_TRUNC_BSIZE(x)	((x) & ~(V7FS_BSIZE - 1))

#define	V7FS_RESIDUE_BSIZE(x)					\
	((x) - ((((x) - 1) >> V7FS_BSHIFT) << V7FS_BSHIFT))

/* Disk location. */
#define	V7FS_BOOTBLOCK_SECTOR	0
#define	V7FS_SUPERBLOCK_SECTOR	1
#define	V7FS_ILIST_SECTOR	2

/* Superblock */
/* cache. */
#define	V7FS_MAX_FREEBLOCK	50
#define	V7FS_MAX_FREEINODE	100
struct v7fs_superblock {
	/* [3 ... (datablock_start_sector-1)]are ilist */
	uint16_t datablock_start_sector;
	v7fs_daddr_t volume_size;
	int16_t nfreeblock;	/* # of freeblock in superblock cache. */
	v7fs_daddr_t freeblock[V7FS_MAX_FREEBLOCK];	/* cache. */
	int16_t nfreeinode;	/* # of free inode in superblock cache. */
	v7fs_ino_t freeinode[V7FS_MAX_FREEINODE];	/* cache. */
	int8_t lock_freeblock;
	int8_t lock_freeinode;
	int8_t modified;
	int8_t readonly;
	v7fs_time_t update_time;
	v7fs_daddr_t total_freeblock;
	v7fs_ino_t total_freeinode;
} __packed;

/* Datablock */
#define	V7FS_NADDR		13
#define	V7FS_NADDR_DIRECT	10
#define	V7FS_NADDR_INDEX1	10
#define	V7FS_NADDR_INDEX2	11
#define	V7FS_NADDR_INDEX3	12
/* daddr index. */
#define	V7FS_DADDR_PER_BLOCK	(V7FS_BSIZE / sizeof(v7fs_daddr_t))
struct v7fs_freeblock {
	int16_t nfreeblock;
	v7fs_daddr_t freeblock[V7FS_MAX_FREEBLOCK];
} __packed;


/* Dirent */
#define	V7FS_NAME_MAX		14
#define	V7FS_PATH_MAX		PATH_MAX	/* No V7 limit. */
#define	V7FS_LINK_MAX		LINK_MAX	/* No V7 limit. */
struct v7fs_dirent {
	v7fs_ino_t inode_number;
	char name[V7FS_NAME_MAX];
} __packed;	/*16byte */

/* Inode */
#define	V7FS_BALBLK_INODE	1	/* monument */
#define	V7FS_ROOT_INODE		2
#define	V7FS_MAX_INODE(s)						\
	(((s)->datablock_start_sector -	V7FS_ILIST_SECTOR) *		\
	V7FS_BSIZE / sizeof(struct v7fs_inode_diskimage))
#define	V7FS_INODE_PER_BLOCK						\
	(V7FS_BSIZE / sizeof(struct v7fs_inode_diskimage))
#define	V7FS_ILISTBLK_MAX	(V7FS_INODE_MAX / V7FS_INODE_PER_BLOCK)

struct v7fs_inode_diskimage {
	int16_t mode;
	int16_t nlink;	/* [DIR] # of child directories. [REG] link count. */
	int16_t uid;
	int16_t gid;
	v7fs_off_t filesize;	/* byte */
#define	V7FS_DINODE_ADDR_LEN	40
	/* 39 used; 13 addresses of 3 byte each. */
	uint8_t addr[V7FS_DINODE_ADDR_LEN];
	/*for device node: addr[0] is major << 8 | minor. */
	v7fs_time_t atime;
	v7fs_time_t mtime;
	v7fs_time_t ctime;
} __packed;	/*64byte */

/* File type */
#define	V7FS_IFMT	0170000	/* File type mask */
#define	V7FS_IFCHR	0020000	/* character device */
#define	V7FS_IFDIR	0040000	/* directory */
#define	V7FS_IFBLK	0060000	/* block device */
#define	V7FS_IFREG	0100000	/* file. */
/* Obsoleted file type. */
#define	V7FS_IFMPC	0030000	/* multiplexed char special */
#define	V7FS_IFMPB	0070000	/* multiplexed block special */
/* Don't appear original V7 filesystem. Found at 2.10BSD. */
#define	V7FSBSD_IFLNK	0120000	/* symbolic link */
#define	V7FSBSD_IFSOCK	0140000	/* socket */
/* Don't appear original V7 filesystem. NetBSD. */
#define	V7FSBSD_IFFIFO	0010000	/* Named pipe. */

#define	V7FSBSD_MAXSYMLINKLEN	V7FS_BSIZE

#endif	/*!_V7FS_H_ */