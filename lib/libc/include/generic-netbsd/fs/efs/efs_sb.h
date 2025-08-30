/*	$NetBSD: efs_sb.h,v 1.1 2007/06/29 23:30:29 rumble Exp $	*/

/*
 * Copyright (c) 2006 Stephen M. Rumble <rumble@ephemeral.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * See IRIX efs(4)
 */

#ifndef _FS_EFS_EFS_SB_H_
#define _FS_EFS_EFS_SB_H_

/*
 * EFS superblock (92 bytes)
 *
 * Notes:
 *   [0] - Values can either be EFS_SB_MAGIC, or EFS_SB_NEWMAGIC (IRIX 3.3+).
 *   [1] - Only used in a grown filesystem. Original bitmap is unused.
 *   [2] - Only exists in IRIX3.3+. (XXX - IRIX man pages say 3.3+ fsck
 *         creates a replicated superblock if space free. Does it update magic?)
 *   [3] - According to IRIX kernel elf headers, two checksum routines exist.
 *   [4] - New at some point (in IRIX 5, but apparently not in IRIX 4).
 */
struct efs_sb {
	int32_t		sb_size;	/* 0:   fs size incl. bb 0 (in bb) */
	int32_t		sb_firstcg;	/* 4:   first cg offset (in bb) */
	int32_t		sb_cgfsize;	/* 8:   cg size (in bb) */
	int16_t		sb_cgisize;	/* 12:  inodes/cg (in bb) */
	int16_t		sb_sectors;	/* 14:  geom: sectors/track */
	int16_t		sb_heads;	/* 16:  geom: heads/cylinder (unused) */
	int16_t		sb_ncg;		/* 18:  num of cg's in the filesystem */
	int16_t		sb_dirty;	/* 20:  non-0 indicates fsck required */
	int16_t		sb_pad0;	/* 22:  */
	int32_t		sb_time;	/* 24:  superblock ctime */
	int32_t		sb_magic;	/* 28:  magic [0] */
	char		sb_fname[6];	/* 32:  name of filesystem */ 
	char		sb_fpack[6];	/* 38:  name of filesystem pack */
	int32_t		sb_bmsize;	/* 44:  bitmap size (in bytes) */
	int32_t		sb_tfree;	/* 48:  total free data blocks */
	int32_t		sb_tinode;	/* 52:  total free inodes */
	int32_t		sb_bmblock;	/* 56:  bitmap offset (grown fs) [1] */
	int32_t		sb_replsb;	/* 62:  repl. superblock offset [2] */
	int32_t		sb_lastinode;	/* 64:  last allocated inode [4] */
	int8_t		sb_spare[20];	/* 68:  unused */
	int32_t		sb_checksum;	/* 88:  checksum (all above) [3] */
} __packed;

#define EFS_SB_SIZE		(sizeof(struct efs_sb))
#define EFS_SB_CHECKSUM_SIZE	(EFS_SB_SIZE - 4)

#define EFS_SB_MAGIC		0x00072959	/* original, ungrown layout */
#define EFS_SB_NEWMAGIC		0x0007295A	/* grown fs (IRIX >= 3.3) */

/* sb_dirty values */
#define EFS_SB_CLEAN		0		/* filesystem is clean */

#endif /* !_FS_EFS_EFS_SB_H_ */