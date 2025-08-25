/*	$NetBSD: ufs_wapbl.h,v 1.19 2020/04/11 17:43:54 jdolecek Exp $	*/

/*-
 * Copyright (c) 2003,2006,2008 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Wasabi Systems, Inc.
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


#ifndef _UFS_UFS_UFS_WAPBL_H_
#define	_UFS_UFS_UFS_WAPBL_H_

#if defined(_KERNEL_OPT)
#include "opt_wapbl.h"
#endif

/*
 * Information for the journal location stored in the superblock.
 * We store the journal version, some flags, the journal location
 * type, and some location specific "locators" that identify where
 * the log itself is located.
 */

/* fs->fs_journal_version */
#define	UFS_WAPBL_VERSION			1

/* fs->fs_journal_location */
#define	UFS_WAPBL_JOURNALLOC_NONE		0

#define	UFS_WAPBL_JOURNALLOC_END_PARTITION	1
#define	 UFS_WAPBL_EPART_ADDR			  0 /* locator slots */
#define	 UFS_WAPBL_EPART_COUNT			  1
#define	 UFS_WAPBL_EPART_BLKSZ			  2
#define	 UFS_WAPBL_EPART_UNUSED			  3

#define	UFS_WAPBL_JOURNALLOC_IN_FILESYSTEM	2
#define	 UFS_WAPBL_INFS_ADDR			  0 /* locator slots */
#define	 UFS_WAPBL_INFS_COUNT			  1
#define	 UFS_WAPBL_INFS_BLKSZ			  2
#define	 UFS_WAPBL_INFS_INO			  3

/* fs->fs_journal_flags */
#define	UFS_WAPBL_FLAGS_CREATE_LOG		0x1
#define	UFS_WAPBL_FLAGS_CLEAR_LOG		0x2


/*
 * The journal size is limited to between 1MB and 64MB.
 * The default journal size is the filesystem size divided by
 * the scale factor - this is 1M of journal per 1GB of filesystem
 * space.
 *
 * XXX: Is 64MB too limiting?  If user explicitly asks for more, allow it?
 */
#define	UFS_WAPBL_JOURNAL_SCALE			1024
#define	UFS_WAPBL_MIN_JOURNAL_SIZE		(1024 * 1024)
#define	UFS_WAPBL_MAX_JOURNAL_SIZE		(64 * 1024 * 1024)


#if defined(WAPBL)

static __inline int
ufs_wapbl_begin(struct mount *mp, const char *file, int line)
{
	if (mp->mnt_wapbl) {
		int error;
		error = wapbl_begin(mp->mnt_wapbl, file, line);
		if (error)
			return error;
	}
	return 0;
}

static __inline void
ufs_wapbl_end(struct mount *mp)
{
	if (mp->mnt_wapbl) {
		wapbl_end(mp->mnt_wapbl);
	}
}

#define	UFS_WAPBL_BEGIN(mp)						\
	ufs_wapbl_begin(mp, __func__, __LINE__)
#define	UFS_WAPBL_END(mp) ufs_wapbl_end(mp)

#define	UFS_WAPBL_UPDATE(vp, access, modify, flags)			\
	if ((vp)->v_mount->mnt_wapbl) {					\
		UFS_UPDATE(vp, access, modify, flags);			\
	}

#ifdef DIAGNOSTIC
#define	UFS_WAPBL_JLOCK_ASSERT(mp)					\
	if (mp->mnt_wapbl) wapbl_jlock_assert(mp->mnt_wapbl)
#define	UFS_WAPBL_JUNLOCK_ASSERT(mp)					\
	if (mp->mnt_wapbl) wapbl_junlock_assert(mp->mnt_wapbl)
#else
#define	UFS_WAPBL_JLOCK_ASSERT(mp)
#define UFS_WAPBL_JUNLOCK_ASSERT(mp)
#endif

#define	UFS_WAPBL_REGISTER_INODE(mp, ino, mode)				\
	if (mp->mnt_wapbl) wapbl_register_inode(mp->mnt_wapbl, ino, mode)
#define	UFS_WAPBL_UNREGISTER_INODE(mp, ino, mode)			\
	if (mp->mnt_wapbl) wapbl_unregister_inode(mp->mnt_wapbl, ino, mode)

#define	UFS_WAPBL_REGISTER_DEALLOCATION(mp, blk, len, cookiep)		\
	(mp->mnt_wapbl)							\
	    ? wapbl_register_deallocation(mp->mnt_wapbl, blk, len,	\
		false, cookiep)						\
	    : 0

#define	UFS_WAPBL_REGISTER_DEALLOCATION_FORCE(mp, blk, len)		\
	(								\
	  (mp->mnt_wapbl)						\
	    ? wapbl_register_deallocation(mp->mnt_wapbl, blk, len,	\
		true, NULL)						\
	    : 0								\
	)

#define	UFS_WAPBL_UNREGISTER_DEALLOCATION(mp, cookie)			\
	if (mp->mnt_wapbl) wapbl_unregister_deallocation(mp->mnt_wapbl, cookie)

#else /* ! WAPBL */
#define	UFS_WAPBL_BEGIN(mp) (__USE(mp), 0)
#define	UFS_WAPBL_END(mp)	do { } while (0)
#define	UFS_WAPBL_UPDATE(vp, access, modify, flags)	do { } while (0)
#define	UFS_WAPBL_JLOCK_ASSERT(mp)
#define	UFS_WAPBL_JUNLOCK_ASSERT(mp)
#define	UFS_WAPBL_REGISTER_INODE(mp, ino, mode)		do { } while (0)
#define	UFS_WAPBL_UNREGISTER_INODE(mp, ino, mode)	do { } while (0)
#define	UFS_WAPBL_REGISTER_DEALLOCATION(mp, blk, len, cookiep)		0
#define	UFS_WAPBL_REGISTER_DEALLOCATION_FORCE(mp, blk, len)		0
#define	UFS_WAPBL_UNREGISTER_DEALLOCATION(mp, cookie)	do { } while (0)
#endif

#endif /* !_UFS_UFS_UFS_WAPBL_H_ */