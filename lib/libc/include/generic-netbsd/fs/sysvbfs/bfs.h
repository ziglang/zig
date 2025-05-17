/*	$NetBSD: bfs.h,v 1.8 2014/01/09 13:23:57 hannken Exp $	*/

/*-
 * Copyright (c) 2004 The NetBSD Foundation, Inc.
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

#ifndef _FS_SYSVBFS_BFS_H_
#define	_FS_SYSVBFS_BFS_H_
/*
 *   Boot File System
 *
 *	+----------
 *	|bfs_super_block (512byte)
 *	|				1 sector
 *	|
 *	+----------
 *	|bfs_inode (64byte) * 8
 *	|    .				1 sector
 *	|bfs_inode
 *	+----------  <--- bfs_super_block.header.data_start
 *	|DATA BLOCK
 *	|    .
 *	|    .
 *	|
 *	+----------  <--- bfs_super_block.header.data_end
 */

/* BFS specification */
#define	BFS_SECTOR		0	/* no offset */
#define	BFS_MAGIC		0x1badface
#define	BFS_FILENAME_MAXLEN	14
#define	BFS_ROOT_INODE		2
#define	BFS_BSIZE		512
#define	BFS_BSHIFT		9

struct bfs_super_block_header {
	uint32_t magic;
	uint32_t data_start_byte;
	uint32_t data_end_byte;
} __packed;

struct bfs_compaction {
	uint32_t from;
	uint32_t to;
	uint32_t from_backup;
	uint32_t to_backup;
} __packed;

struct bfs_fileattr {
	uint32_t type;
	uint32_t mode;
	int32_t uid;
	int32_t gid;
	uint32_t nlink;
	int32_t atime;
	int32_t mtime;
	int32_t ctime;
	int32_t padding[4];
} __packed;	/* 48byte */

struct bfs_inode {
	uint16_t number;		/*  0 */
	int16_t padding;
	uint32_t start_sector;		/*  4 */
	uint32_t end_sector;		/*  8 */
	uint32_t eof_offset_byte;	/* 12 (offset from super block start) */
	struct bfs_fileattr attr;	/* 16 */
} __packed;	/* 64byte */

struct bfs_super_block {
	struct bfs_super_block_header header;
	struct bfs_compaction compaction;
	char fsname[6];
	char volume[6];
	int32_t padding[118];
} __packed;

struct bfs_dirent {
	uint16_t inode;
	char name[BFS_FILENAME_MAXLEN];
} __packed; /* 16byte */

#if defined _KERNEL || defined _STANDALONE
/* Software definition */
struct sector_io_ops;
struct bfs {
	int start_sector;
	/* Super block */
	struct bfs_super_block *super_block;
	size_t super_block_size;

	/* Data block */
	uint32_t data_start, data_end;

	/* Inode */
	struct bfs_inode *inode;
	int n_inode;
	int max_inode;

	/* root directory */
	struct bfs_dirent *dirent;
	size_t dirent_size;
	int n_dirent;
	int max_dirent;
	struct bfs_inode *root_inode;

	/* Sector I/O operation */
	struct sector_io_ops *io;

	bool debug;
};

struct sector_io_ops {
	bool (*read)(void *, uint8_t *, daddr_t);
	bool (*read_n)(void *, uint8_t *, daddr_t, int);
	bool (*write)(void *, uint8_t *, daddr_t);
	bool (*write_n)(void *, uint8_t *, daddr_t, int);
};

struct vnode;

int bfs_init2(struct bfs **, int, struct sector_io_ops *, bool);
void bfs_fini(struct bfs *);
int bfs_file_read(const struct bfs *, const char *, void *, size_t, size_t *);
int bfs_file_write(struct bfs *, const char *, void *, size_t);
int bfs_file_create(struct bfs *, const char *, void *,  size_t,
    const struct bfs_fileattr *);
int bfs_file_delete(struct bfs *, const char *, bool);
int bfs_file_rename(struct bfs *, const char *, const char *);
bool bfs_file_lookup(const struct bfs *, const char *, int *, int *,
    size_t *);
size_t bfs_file_size(const struct bfs_inode *);

bool bfs_dump(const struct bfs *);

/* filesystem ops */
int sysvbfs_bfs_init(struct bfs **, struct vnode *);
void sysvbfs_bfs_fini(struct bfs *);
bool bfs_inode_lookup(const struct bfs *, ino_t, struct bfs_inode **);
int bfs_inode_delete(struct bfs *, ino_t);
bool bfs_dirent_lookup_by_name(const struct bfs *, const char *,
    struct bfs_dirent **);
bool bfs_dirent_lookup_by_inode(const struct bfs *, int,
    struct bfs_dirent **);
void bfs_inode_set_attr(const struct bfs *, struct bfs_inode *,
    const struct bfs_fileattr *attr);
int bfs_inode_alloc(const struct bfs *, struct bfs_inode **, int *,
    int *);
#endif /* _KERNEL || _STANDALONE */
#endif /* _FS_SYSVBFS_BFS_H_ */