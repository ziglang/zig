/*	$NetBSD: efs.h,v 1.2 2007/06/30 15:56:16 rumble Exp $	*/

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

#ifndef _FS_EFS_EFS_H_
#define _FS_EFS_EFS_H_

#define EFS_DEBUG

/*
 * SGI EFS - Extent File System
 *
 * The EFS filesystem is comprised of 512-byte sectors, or "basic blocks" (bb).
 * These blocks are divided into cylinder groups (cg), from which extents are
 * allocated. An extent is a contiguous region of blocks with minimal length
 * of 1 and maximal length of 248.
 *
 * The filesystem is limited to 8GB by struct efs_extent's ex_bn field, which
 * specifies an extent's offset in terms of basic blocks. Unfortunately, it was
 * squished into a bitfield and given only 24bits so we are left with
 * 2**24 * 512 bytes. Individual files are maximally 2GB, but not due to any
 * limitation of on-disk structures. All sizes and offsets are stored as block,
 * not byte values, with the exception of sb.sb_bmsize and efs_dinode.di_size.
 *
 * An EFS filesystem begins with the superblock (struct efs_sb) at bb offset 1
 * (offset 0 is reserved for bootblocks and other forms of contraband). The
 * superblock contains various parameters including magic, checksum, filesystem
 * size, number of cylinder groups, size of cylinder groups, and location of the
 * first cylinder group. A bitmap may begin at offset bb 2. This is true of
 * filesystems whose magic flag is EFS_MAGIC. However, the ability to grow an
 * efs filesystem was added in IRIX 3.3 and a grown efs's bitmap is located
 * toward the end of the disk, pointed to by sb.sb_bmblock. A grown filesystem
 * is detected with the EFS_NEWMAGIC flag. See below for more details and
 * differences.
 *
 * In order to promote inode and data locality, the disk is separated into
 * sb.sb_ncg cylinder groups, which consist of sb.sb_cgfsize blocks each.
 * The cylinder groups are laid out consecutively beginning from block offset
 * sb.sb_firstcg. The beginning of each cylinder group is comprised of
 * sb.sb_cgisize inodes (struct efs_dinode). The remaining space contains
 * file extents, which are preferentially allocated to files whose inodes are
 * within the same cylinder group.
 *
 * EFS increases I/O performance by storing files in contiguous chunks called
 * 'extents' (struct efs_extent). Extents are variably sized from 1 to 248
 * blocks, but please don't ask me why 256 isn't the limit.
 *
 * Each inode (struct efs_dinode) contains space for twelve extent descriptors,
 * allowing for up to 1,523,712 byte files (12 * 248 * 512) to be described
 * without indirection. When indirection is employed, each of the twelve
 * descriptors may reference extents that contain up to 248 more direct
 * descriptors. Since each descriptor is 8 bytes we could theoretically have
 * in total 15,872 * 12 direct descriptors, allowing for 15,872 * 12 * 248 *
 * 512 = ~22GB files. However, since ei_numextents is a signed 16-bit quantity,
 * we're limited to only 32767 indirect extents, which leaves us with a ~3.87GB
 * maximum file size. (Of course, with a maximum filesystem size of 8GB, such a
 * restriction isn't so bad.) Note that a single full indirect extent could
 * reference approximately 1.877GB of data, but SGI strikes again! Earlier
 * versions of IRIX (4.0.5H certainly, and perhaps prior) limit indirect
 * extents to 32 basic blocks worth. This caps the number of extents at 12 *
 * 32 * 64, permitting ~2.91GB files. SGI later raised this limit to 64 blocks
 * worth, which exceeds the range of ei_numextents and gives a maximum
 * theoretical file size of ~3.87GB. However, EFS purportedly only permits
 * files up to 2GB in length.
 *
 * The bitmap referred to by sb_bmsize and (optionally) sb_bmblock contains
 * data block allocation information. I haven't looked at this at all, nor
 * am I aware of how inode allocation is performed.
 *
 * An EFS disk layout looks like the following:
 *     ____________________________________________________________________
 *    | unused | superblock | bitmap | pad | cyl grp | ..cyl grps... | pad |
 *     --------------------------------------------------------------------
 * bb:     0          1         2          ^-sb.sb_firstcg      sb.sb_size-^
 *
 * A cylinder group looks like the following:
 *     ____________________________________________________________________
 *    |    inodes    |           ... extents and free space ...            | 
 *     --------------------------------------------------------------------
 *           0       ^-(sb.sb_cgisize *                      sb.sb_cgfsize-^
 *                      sizeof(struct efs_dinode))
 *
 * So far as I am aware, EFS file systems have always been big endian, existing
 * on mips (and perhaps earlier on m68k) machines only. While mips chips are
 * bi-endian, I am unaware of any sgimips machine that was used in mipsel mode.
 *
 * See efs_sb.h, efs_dir.h, and efs_dinode.h for more information regarding
 * directory layout and on-disk inodes, and the superblock accordingly.
 */

/*
 * Basic blocks are always 512 bytes.
 */
#define EFS_BB_SHFT	9
#define EFS_BB_SIZE	(1 << EFS_BB_SHFT)

/*
 * EFS basic block layout:
 */
#define EFS_BB_UNUSED	0	/* bb 0 is unused */
#define EFS_BB_SB	1	/* bb 1 is superblock */
#define EFS_BB_BITMAP	2	/* bb 2 is bitmap (unless moved by growfs) */
/* bitmap continues, then padding up to first aligned cylinder group */

/*
 * basic block <-> byte conversions
 */
#define EFS_BB2BY(_x)		((_x) << EFS_BB_SHFT)
#define EFS_BY2BB(_x)		(((_x) + EFS_BB_SIZE - 1) >> EFS_BB_SHFT)

/*
 * Struct efs_extent limits us to 24 bit offsets, therefore the maximum
 * efs.sb_size is 2**24 blocks (8GB).
 *
 * Trivia: IRIX's mkfs_efs(1M) has claimed the maximum to be 0xfffffe for years.
 */
#define EFS_SIZE_MAX		0x01000000

#ifdef _KERNEL

#define	VFSTOEFS(mp)    ((struct efs_mount *)(mp)->mnt_data)

/* debug goo */
#ifdef DEBUG
#define EFS_DEBUG
#endif
#ifdef EFS_DEBUG
#define EFS_DPRINTF(_x)	printf _x
#else
#define EFS_DPRINTF(_x)
#endif

#endif

#endif /* !_FS_EFS_EFS_H_ */