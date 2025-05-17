/*	$NetBSD: lfs_accessors.h,v 1.51 2022/04/24 20:32:44 rillig Exp $	*/

/*  from NetBSD: lfs.h,v 1.165 2015/07/24 06:59:32 dholland Exp  */
/*  from NetBSD: dinode.h,v 1.25 2016/01/22 23:06:10 dholland Exp  */
/*  from NetBSD: dir.h,v 1.25 2015/09/01 06:16:03 dholland Exp  */

/*-
 * Copyright (c) 1999, 2000, 2001, 2002, 2003 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Konrad E. Schroder <perseant@hhhh.org>.
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
/*-
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)lfs.h	8.9 (Berkeley) 5/8/95
 */
/*
 * Copyright (c) 2002 Networks Associates Technology, Inc.
 * All rights reserved.
 *
 * This software was developed for the FreeBSD Project by Marshall
 * Kirk McKusick and Network Associates Laboratories, the Security
 * Research Division of Network Associates, Inc. under DARPA/SPAWAR
 * contract N66001-01-C-8035 ("CBOSS"), as part of the DARPA CHATS
 * research program
 *
 * Copyright (c) 1982, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)dinode.h	8.9 (Berkeley) 3/29/95
 */
/*
 * Copyright (c) 1982, 1986, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)dir.h	8.5 (Berkeley) 4/27/95
 */

#ifndef _UFS_LFS_LFS_ACCESSORS_H_
#define _UFS_LFS_LFS_ACCESSORS_H_

#if defined(_KERNEL_OPT)
#include "opt_lfs.h"
#endif

#include <sys/bswap.h>

#include <ufs/lfs/lfs.h>

#if !defined(_KERNEL) && !defined(_STANDALONE)
#include <assert.h>
#include <string.h>
#define KASSERT assert
#else
#include <sys/systm.h>
#endif

/*
 * STRUCT_LFS is used by the libsa code to get accessors that work
 * with struct salfs instead of struct lfs, and by the cleaner to
 * get accessors that work with struct clfs.
 */

#ifndef STRUCT_LFS
#define STRUCT_LFS struct lfs
#endif

/*
 * byte order
 */

/*
 * For now at least, the bootblocks shall not be endian-independent.
 * We can see later if it fits in the size budget. Also disable the
 * byteswapping if LFS_EI is off.
 *
 * Caution: these functions "know" that bswap16/32/64 are unsigned,
 * and if that changes will likely break silently.
 */

#if defined(_STANDALONE) || (defined(_KERNEL) && !defined(LFS_EI))
#define LFS_SWAP_int16_t(fs, val) (val)
#define LFS_SWAP_int32_t(fs, val) (val)
#define LFS_SWAP_int64_t(fs, val) (val)
#define LFS_SWAP_uint16_t(fs, val) (val)
#define LFS_SWAP_uint32_t(fs, val) (val)
#define LFS_SWAP_uint64_t(fs, val) (val)
#else
#define LFS_SWAP_int16_t(fs, val) \
	((fs)->lfs_dobyteswap ? (int16_t)bswap16(val) : (val))
#define LFS_SWAP_int32_t(fs, val) \
	((fs)->lfs_dobyteswap ? (int32_t)bswap32(val) : (val))
#define LFS_SWAP_int64_t(fs, val) \
	((fs)->lfs_dobyteswap ? (int64_t)bswap64(val) : (val))
#define LFS_SWAP_uint16_t(fs, val) \
	((fs)->lfs_dobyteswap ? bswap16(val) : (val))
#define LFS_SWAP_uint32_t(fs, val) \
	((fs)->lfs_dobyteswap ? bswap32(val) : (val))
#define LFS_SWAP_uint64_t(fs, val) \
	((fs)->lfs_dobyteswap ? bswap64(val) : (val))
#endif

/*
 * For handling directories we will need to know if the volume is
 * little-endian.
 */
#if BYTE_ORDER == LITTLE_ENDIAN
#define LFS_LITTLE_ENDIAN_ONDISK(fs) (!(fs)->lfs_dobyteswap)
#else
#define LFS_LITTLE_ENDIAN_ONDISK(fs) ((fs)->lfs_dobyteswap)
#endif


/*
 * Suppress spurious warnings -- we use
 *
 *	type *foo = &obj->member;
 *
 * in macros to verify that obj->member has the right type.  When the
 * object is a packed structure with misaligned members, this causes
 * some compiles to squeal that taking the address might lead to
 * undefined behaviour later on -- which is helpful in general, not
 * relevant in this case, because we don't do anything with foo
 * afterward; we only declare it to get a type check and then we
 * discard it.
 */
#ifdef __GNUC__
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Waddress-of-packed-member"
#elif __GNUC_PREREQ__(9,0)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Waddress-of-packed-member"
#endif
#endif



/*
 * directories
 */

#define LFS_DIRHEADERSIZE(fs) \
	((fs)->lfs_is64 ? sizeof(struct lfs_dirheader64) : sizeof(struct lfs_dirheader32))

/*
 * The LFS_DIRSIZ macro gives the minimum record length which will hold
 * the directory entry.  This requires the amount of space in struct lfs_direct
 * without the d_name field, plus enough space for the name with a terminating
 * null byte (dp->d_namlen+1), rounded up to a 4 byte boundary.
 */
#define	LFS_DIRECTSIZ(fs, namlen) \
	(LFS_DIRHEADERSIZE(fs) + (((namlen)+1 + 3) &~ 3))

/*
 * The size of the largest possible directory entry. This is
 * used by ulfs_dirhash to figure the size of an array, so we
 * need a single constant value true for both lfs32 and lfs64.
 */
#define LFS_MAXDIRENTRYSIZE \
	(sizeof(struct lfs_dirheader64) + (((LFS_MAXNAMLEN+1)+1 + 3) & ~3))

#if (BYTE_ORDER == LITTLE_ENDIAN)
#define LFS_OLDDIRSIZ(oldfmt, dp, needswap)	\
    (((oldfmt) && !(needswap)) ?		\
    LFS_DIRECTSIZ((dp)->d_type) : LFS_DIRECTSIZ((dp)->d_namlen))
#else
#define LFS_OLDDIRSIZ(oldfmt, dp, needswap)	\
    (((oldfmt) && (needswap)) ?			\
    LFS_DIRECTSIZ((dp)->d_type) : LFS_DIRECTSIZ((dp)->d_namlen))
#endif

#define LFS_DIRSIZ(fs, dp) LFS_DIRECTSIZ(fs, lfs_dir_getnamlen(fs, dp))

/* Constants for the first argument of LFS_OLDDIRSIZ */
#define LFS_OLDDIRFMT	1
#define LFS_NEWDIRFMT	0

#define LFS_NEXTDIR(fs, dp) \
	((LFS_DIRHEADER *)((char *)(dp) + lfs_dir_getreclen(fs, dp)))

static __inline char *
lfs_dir_nameptr(const STRUCT_LFS *fs, LFS_DIRHEADER *dh)
{
	if (fs->lfs_is64) {
		return (char *)(&dh->u_64 + 1);
	} else {
		return (char *)(&dh->u_32 + 1);
	}
}

static __inline uint64_t
lfs_dir_getino(const STRUCT_LFS *fs, const LFS_DIRHEADER *dh)
{
	if (fs->lfs_is64) {
		return LFS_SWAP_uint64_t(fs, dh->u_64.dh_ino);
	} else {
		return LFS_SWAP_uint32_t(fs, dh->u_32.dh_ino);
	}
}

static __inline uint16_t
lfs_dir_getreclen(const STRUCT_LFS *fs, const LFS_DIRHEADER *dh)
{
	if (fs->lfs_is64) {
		return LFS_SWAP_uint16_t(fs, dh->u_64.dh_reclen);
	} else {
		return LFS_SWAP_uint16_t(fs, dh->u_32.dh_reclen);
	}
}

static __inline uint8_t
lfs_dir_gettype(const STRUCT_LFS *fs, const LFS_DIRHEADER *dh)
{
	if (fs->lfs_is64) {
		KASSERT(fs->lfs_hasolddirfmt == 0);
		return dh->u_64.dh_type;
	} else if (fs->lfs_hasolddirfmt) {
		return LFS_DT_UNKNOWN;
	} else {
		return dh->u_32.dh_type;
	}
}

static __inline uint8_t
lfs_dir_getnamlen(const STRUCT_LFS *fs, const LFS_DIRHEADER *dh)
{
	if (fs->lfs_is64) {
		KASSERT(fs->lfs_hasolddirfmt == 0);
		return dh->u_64.dh_namlen;
	} else if (fs->lfs_hasolddirfmt && LFS_LITTLE_ENDIAN_ONDISK(fs)) {
		/* low-order byte of old 16-bit namlen field */
		return dh->u_32.dh_type;
	} else {
		return dh->u_32.dh_namlen;
	}
}

static __inline void
lfs_dir_setino(STRUCT_LFS *fs, LFS_DIRHEADER *dh, uint64_t ino)
{
	if (fs->lfs_is64) {
		dh->u_64.dh_ino = LFS_SWAP_uint64_t(fs, ino);
	} else {
		dh->u_32.dh_ino = LFS_SWAP_uint32_t(fs, ino);
	}
}

static __inline void
lfs_dir_setreclen(STRUCT_LFS *fs, LFS_DIRHEADER *dh, uint16_t reclen)
{
	if (fs->lfs_is64) {
		dh->u_64.dh_reclen = LFS_SWAP_uint16_t(fs, reclen);
	} else {
		dh->u_32.dh_reclen = LFS_SWAP_uint16_t(fs, reclen);
	}
}

static __inline void
lfs_dir_settype(const STRUCT_LFS *fs, LFS_DIRHEADER *dh, uint8_t type)
{
	if (fs->lfs_is64) {
		KASSERT(fs->lfs_hasolddirfmt == 0);
		dh->u_64.dh_type = type;
	} else if (fs->lfs_hasolddirfmt) {
		/* do nothing */
		return;
	} else {
		dh->u_32.dh_type = type;
	}
}

static __inline void
lfs_dir_setnamlen(const STRUCT_LFS *fs, LFS_DIRHEADER *dh, uint8_t namlen)
{
	if (fs->lfs_is64) {
		KASSERT(fs->lfs_hasolddirfmt == 0);
		dh->u_64.dh_namlen = namlen;
	} else if (fs->lfs_hasolddirfmt && LFS_LITTLE_ENDIAN_ONDISK(fs)) {
		/* low-order byte of old 16-bit namlen field */
		dh->u_32.dh_type = namlen;
	} else {
		dh->u_32.dh_namlen = namlen;
	}
}

static __inline void
lfs_copydirname(STRUCT_LFS *fs, char *dest, const char *src,
		unsigned namlen, unsigned reclen)
{
	unsigned spacelen;

	KASSERT(reclen > LFS_DIRHEADERSIZE(fs));
	spacelen = reclen - LFS_DIRHEADERSIZE(fs);

	/* must always be at least 1 byte as a null terminator */
	KASSERT(spacelen > namlen);

	memcpy(dest, src, namlen);
	memset(dest + namlen, '\0', spacelen - namlen);
}

static __inline LFS_DIRHEADER *
lfs_dirtemplate_dotdot(STRUCT_LFS *fs, union lfs_dirtemplate *dt)
{
	/* XXX blah, be nice to have a way to do this w/o casts */
	if (fs->lfs_is64) {
		return (LFS_DIRHEADER *)&dt->u_64.dotdot_header;
	} else {
		return (LFS_DIRHEADER *)&dt->u_32.dotdot_header;
	}
}

static __inline char *
lfs_dirtemplate_dotdotname(STRUCT_LFS *fs, union lfs_dirtemplate *dt)
{
	if (fs->lfs_is64) {
		return dt->u_64.dotdot_name;
	} else {
		return dt->u_32.dotdot_name;
	}
}

/*
 * dinodes
 */

/*
 * Maximum length of a symlink that can be stored within the inode.
 */
#define LFS32_MAXSYMLINKLEN	((ULFS_NDADDR + ULFS_NIADDR) * sizeof(int32_t))
#define LFS64_MAXSYMLINKLEN	((ULFS_NDADDR + ULFS_NIADDR) * sizeof(int64_t))

#define LFS_MAXSYMLINKLEN(fs) \
	((fs)->lfs_is64 ? LFS64_MAXSYMLINKLEN : LFS32_MAXSYMLINKLEN)

#define DINOSIZE(fs) ((fs)->lfs_is64 ? sizeof(struct lfs64_dinode) : sizeof(struct lfs32_dinode))

#define DINO_IN_BLOCK(fs, base, ix) \
	((union lfs_dinode *)((char *)(base) + DINOSIZE(fs) * (ix)))

static __inline void
lfs_copy_dinode(STRUCT_LFS *fs,
    union lfs_dinode *dst, const union lfs_dinode *src)
{
	/*
	 * We can do structure assignment of the structs, but not of
	 * the whole union, as the union is the size of the (larger)
	 * 64-bit struct and on a 32-bit fs the upper half of it might
	 * be off the end of a buffer or otherwise invalid.
	 */
	if (fs->lfs_is64) {
		dst->u_64 = src->u_64;
	} else {
		dst->u_32 = src->u_32;
	}
}

#define LFS_DEF_DINO_ACCESSOR(type, type32, field) \
	static __inline type				\
	lfs_dino_get##field(STRUCT_LFS *fs, union lfs_dinode *dip) \
	{							\
		if (fs->lfs_is64) {				\
			return LFS_SWAP_##type(fs, dip->u_64.di_##field); \
		} else {					\
			return LFS_SWAP_##type32(fs, dip->u_32.di_##field); \
		}						\
	}							\
	static __inline void				\
	lfs_dino_set##field(STRUCT_LFS *fs, union lfs_dinode *dip, type val) \
	{							\
		if (fs->lfs_is64) {				\
			type *p = &dip->u_64.di_##field;	\
			(void)p;				\
			dip->u_64.di_##field = LFS_SWAP_##type(fs, val); \
		} else {					\
			type32 *p = &dip->u_32.di_##field;	\
			(void)p;				\
			dip->u_32.di_##field = LFS_SWAP_##type32(fs, val); \
		}						\
	}							\

LFS_DEF_DINO_ACCESSOR(uint16_t, uint16_t, mode)
LFS_DEF_DINO_ACCESSOR(int16_t, int16_t, nlink)
LFS_DEF_DINO_ACCESSOR(uint64_t, uint32_t, inumber)
LFS_DEF_DINO_ACCESSOR(uint64_t, uint64_t, size)
LFS_DEF_DINO_ACCESSOR(int64_t, int32_t, atime)
LFS_DEF_DINO_ACCESSOR(int32_t, int32_t, atimensec)
LFS_DEF_DINO_ACCESSOR(int64_t, int32_t, mtime)
LFS_DEF_DINO_ACCESSOR(int32_t, int32_t, mtimensec)
LFS_DEF_DINO_ACCESSOR(int64_t, int32_t, ctime)
LFS_DEF_DINO_ACCESSOR(int32_t, int32_t, ctimensec)
LFS_DEF_DINO_ACCESSOR(uint32_t, uint32_t, flags)
LFS_DEF_DINO_ACCESSOR(uint64_t, uint32_t, blocks)
LFS_DEF_DINO_ACCESSOR(int32_t, int32_t, gen)
LFS_DEF_DINO_ACCESSOR(uint32_t, uint32_t, uid)
LFS_DEF_DINO_ACCESSOR(uint32_t, uint32_t, gid)

/* XXX this should be done differently (it's a fake field) */
LFS_DEF_DINO_ACCESSOR(int64_t, int32_t, rdev)

static __inline daddr_t
lfs_dino_getdb(STRUCT_LFS *fs, union lfs_dinode *dip, unsigned ix)
{
	KASSERT(ix < ULFS_NDADDR);
	if (fs->lfs_is64) {
		return LFS_SWAP_int64_t(fs, dip->u_64.di_db[ix]);
	} else {
		/* note: this must sign-extend or UNWRITTEN gets trashed */
		return (int32_t)LFS_SWAP_int32_t(fs, dip->u_32.di_db[ix]);
	}
}

static __inline daddr_t
lfs_dino_getib(STRUCT_LFS *fs, union lfs_dinode *dip, unsigned ix)
{
	KASSERT(ix < ULFS_NIADDR);
	if (fs->lfs_is64) {
		return LFS_SWAP_int64_t(fs, dip->u_64.di_ib[ix]);
	} else {
		/* note: this must sign-extend or UNWRITTEN gets trashed */
		return (int32_t)LFS_SWAP_int32_t(fs, dip->u_32.di_ib[ix]);
	}
}

static __inline void
lfs_dino_setdb(STRUCT_LFS *fs, union lfs_dinode *dip, unsigned ix, daddr_t val)
{
	KASSERT(ix < ULFS_NDADDR);
	if (fs->lfs_is64) {
		dip->u_64.di_db[ix] = LFS_SWAP_int64_t(fs, val);
	} else {
		dip->u_32.di_db[ix] = LFS_SWAP_uint32_t(fs, val);
	}
}

static __inline void
lfs_dino_setib(STRUCT_LFS *fs, union lfs_dinode *dip, unsigned ix, daddr_t val)
{
	KASSERT(ix < ULFS_NIADDR);
	if (fs->lfs_is64) {
		dip->u_64.di_ib[ix] = LFS_SWAP_int64_t(fs, val);
	} else {
		dip->u_32.di_ib[ix] = LFS_SWAP_uint32_t(fs, val);
	}
}

/* birthtime is present only in the 64-bit inode */
static __inline void
lfs_dino_setbirthtime(STRUCT_LFS *fs, union lfs_dinode *dip,
    const struct timespec *ts)
{
	if (fs->lfs_is64) {
		dip->u_64.di_birthtime = ts->tv_sec;
		dip->u_64.di_birthnsec = ts->tv_nsec;
	} else {
		/* drop it on the floor */
	}
}

/*
 * indirect blocks
 */

static __inline daddr_t
lfs_iblock_get(STRUCT_LFS *fs, void *block, unsigned ix)
{
	if (fs->lfs_is64) {
		// XXX re-enable these asserts after reorging this file
		//KASSERT(ix < lfs_sb_getbsize(fs) / sizeof(int64_t));
		return (daddr_t)(((int64_t *)block)[ix]);
	} else {
		//KASSERT(ix < lfs_sb_getbsize(fs) / sizeof(int32_t));
		/* must sign-extend or UNWRITTEN gets trashed */
		return (daddr_t)(int64_t)(((int32_t *)block)[ix]);
	}
}

static __inline void
lfs_iblock_set(STRUCT_LFS *fs, void *block, unsigned ix, daddr_t val)
{
	if (fs->lfs_is64) {
		//KASSERT(ix < lfs_sb_getbsize(fs) / sizeof(int64_t));
		((int64_t *)block)[ix] = val;
	} else {
		//KASSERT(ix < lfs_sb_getbsize(fs) / sizeof(int32_t));
		((int32_t *)block)[ix] = val;
	}
}

/*
 * "struct buf" associated definitions
 */

# define LFS_LOCK_BUF(bp) do {						\
	if (((bp)->b_flags & B_LOCKED) == 0 && bp->b_iodone == NULL) {	\
		mutex_enter(&lfs_lock);					\
		++locked_queue_count;					\
		locked_queue_bytes += bp->b_bufsize;			\
		mutex_exit(&lfs_lock);					\
	}								\
	(bp)->b_flags |= B_LOCKED;					\
} while (0)

# define LFS_UNLOCK_BUF(bp) do {					\
	if (((bp)->b_flags & B_LOCKED) != 0 && bp->b_iodone == NULL) {	\
		mutex_enter(&lfs_lock);					\
		--locked_queue_count;					\
		locked_queue_bytes -= bp->b_bufsize;			\
		if (locked_queue_count < LFS_WAIT_BUFS &&		\
		    locked_queue_bytes < LFS_WAIT_BYTES)		\
			cv_broadcast(&locked_queue_cv);			\
		mutex_exit(&lfs_lock);					\
	}								\
	(bp)->b_flags &= ~B_LOCKED;					\
} while (0)

/*
 * "struct inode" associated definitions
 */

#define LFS_SET_UINO(ip, states) do {					\
	if (((states) & IN_ACCESSED) && !((ip)->i_state & IN_ACCESSED))	\
		lfs_sb_adduinodes((ip)->i_lfs, 1);			\
	if (((states) & IN_CLEANING) && !((ip)->i_state & IN_CLEANING))	\
		lfs_sb_adduinodes((ip)->i_lfs, 1);			\
	if (((states) & IN_MODIFIED) && !((ip)->i_state & IN_MODIFIED))	\
		lfs_sb_adduinodes((ip)->i_lfs, 1);			\
	(ip)->i_state |= (states);					\
} while (0)

#define LFS_CLR_UINO(ip, states) do {					\
	if (((states) & IN_ACCESSED) && ((ip)->i_state & IN_ACCESSED))	\
		lfs_sb_subuinodes((ip)->i_lfs, 1);			\
	if (((states) & IN_CLEANING) && ((ip)->i_state & IN_CLEANING))	\
		lfs_sb_subuinodes((ip)->i_lfs, 1);			\
	if (((states) & IN_MODIFIED) && ((ip)->i_state & IN_MODIFIED))	\
		lfs_sb_subuinodes((ip)->i_lfs, 1);			\
	(ip)->i_state &= ~(states);					\
	if (lfs_sb_getuinodes((ip)->i_lfs) < 0) {			\
		panic("lfs_uinodes < 0");				\
	}								\
} while (0)

#define LFS_ITIMES(ip, acc, mod, cre) \
	while ((ip)->i_state & (IN_ACCESS | IN_CHANGE | IN_UPDATE | IN_MODIFY)) \
		lfs_itimes(ip, acc, mod, cre)

/*
 * On-disk and in-memory checkpoint segment usage structure.
 */

#define	SEGUPB(fs)	(lfs_sb_getsepb(fs))
#define	SEGTABSIZE_SU(fs)						\
	((lfs_sb_getnseg(fs) + SEGUPB(fs) - 1) / lfs_sb_getsepb(fs))

#ifdef _KERNEL
# define SHARE_IFLOCK(F) 						\
  do {									\
	rw_enter(&(F)->lfs_iflock, RW_READER);				\
  } while(0)
# define UNSHARE_IFLOCK(F)						\
  do {									\
	rw_exit(&(F)->lfs_iflock);					\
  } while(0)
#else /* ! _KERNEL */
# define SHARE_IFLOCK(F)
# define UNSHARE_IFLOCK(F)
#endif /* ! _KERNEL */

/* Read in the block with a specific segment usage entry from the ifile. */
#define	LFS_SEGENTRY(SP, F, IN, BP) do {				\
	int _e;								\
	SHARE_IFLOCK(F);						\
	VTOI((F)->lfs_ivnode)->i_state |= IN_ACCESS;			\
	if ((_e = bread((F)->lfs_ivnode,				\
	    ((IN) / lfs_sb_getsepb(F)) + lfs_sb_getcleansz(F),		\
	    lfs_sb_getbsize(F), 0, &(BP))) != 0)			\
		panic("lfs: ifile read: segentry %llu: error %d\n",	\
			 (unsigned long long)(IN), _e);			\
	if (lfs_sb_getversion(F) == 1)					\
		(SP) = (SEGUSE *)((SEGUSE_V1 *)(BP)->b_data +		\
			((IN) & (lfs_sb_getsepb(F) - 1)));		\
	else								\
		(SP) = (SEGUSE *)(BP)->b_data + ((IN) % lfs_sb_getsepb(F)); \
	UNSHARE_IFLOCK(F);						\
} while (0)

#define LFS_WRITESEGENTRY(SP, F, IN, BP) do {				\
	if ((SP)->su_nbytes == 0)					\
		(SP)->su_flags |= SEGUSE_EMPTY;				\
	else								\
		(SP)->su_flags &= ~SEGUSE_EMPTY;			\
	(F)->lfs_suflags[(F)->lfs_activesb][(IN)] = (SP)->su_flags;	\
	LFS_BWRITE_LOG(BP);						\
} while (0)

/*
 * FINFO (file info) entries.
 */

/* Size of an on-disk block pointer, e.g. in an indirect block. */
/* XXX: move to a more suitable location in this file */
#define LFS_BLKPTRSIZE(fs) ((fs)->lfs_is64 ? sizeof(int64_t) : sizeof(int32_t))

/* Size of an on-disk inode number. */
/* XXX: move to a more suitable location in this file */
#define LFS_INUMSIZE(fs) ((fs)->lfs_is64 ? sizeof(int64_t) : sizeof(int32_t))

/* size of a FINFO, without the block pointers */
#define	FINFOSIZE(fs)	((fs)->lfs_is64 ? sizeof(FINFO64) : sizeof(FINFO32))

/* Full size of the provided FINFO record, including its block pointers. */
#define FINFO_FULLSIZE(fs, fip) \
	(FINFOSIZE(fs) + lfs_fi_getnblocks(fs, fip) * LFS_BLKPTRSIZE(fs))

#define NEXT_FINFO(fs, fip) \
	((FINFO *)((char *)(fip) + FINFO_FULLSIZE(fs, fip)))

#define LFS_DEF_FI_ACCESSOR(type, type32, field) \
	static __inline type				\
	lfs_fi_get##field(STRUCT_LFS *fs, FINFO *fip)		\
	{							\
		if (fs->lfs_is64) {				\
			return fip->u_64.fi_##field; 		\
		} else {					\
			return fip->u_32.fi_##field; 		\
		}						\
	}							\
	static __inline void				\
	lfs_fi_set##field(STRUCT_LFS *fs, FINFO *fip, type val) \
	{							\
		if (fs->lfs_is64) {				\
			type *p = &fip->u_64.fi_##field;	\
			(void)p;				\
			fip->u_64.fi_##field = val;		\
		} else {					\
			type32 *p = &fip->u_32.fi_##field;	\
			(void)p;				\
			fip->u_32.fi_##field = val;		\
		}						\
	}							\

LFS_DEF_FI_ACCESSOR(uint32_t, uint32_t, nblocks)
LFS_DEF_FI_ACCESSOR(uint32_t, uint32_t, version)
LFS_DEF_FI_ACCESSOR(uint64_t, uint32_t, ino)
LFS_DEF_FI_ACCESSOR(uint32_t, uint32_t, lastlength)

static __inline daddr_t
lfs_fi_getblock(STRUCT_LFS *fs, FINFO *fip, unsigned idx)
{
	void *firstblock;

	firstblock = (char *)fip + FINFOSIZE(fs);
	KASSERT(idx < lfs_fi_getnblocks(fs, fip));
	if (fs->lfs_is64) {
		return ((int64_t *)firstblock)[idx];
	} else {
		return ((int32_t *)firstblock)[idx];
	}
}

static __inline void
lfs_fi_setblock(STRUCT_LFS *fs, FINFO *fip, unsigned idx, daddr_t blk)
{
	void *firstblock;

	firstblock = (char *)fip + FINFOSIZE(fs);
	KASSERT(idx < lfs_fi_getnblocks(fs, fip));
	if (fs->lfs_is64) {
		((int64_t *)firstblock)[idx] = blk;
	} else {
		((int32_t *)firstblock)[idx] = blk;
	}
}

/*
 * inode info entries (in the segment summary)
 */

#define IINFOSIZE(fs)	((fs)->lfs_is64 ? sizeof(IINFO64) : sizeof(IINFO32))

/* iinfos scroll backward from the end of the segment summary block */
#define SEGSUM_IINFOSTART(fs, buf) \
	((IINFO *)((char *)buf + lfs_sb_getsumsize(fs) - IINFOSIZE(fs)))

#define NEXTLOWER_IINFO(fs, iip) \
	((IINFO *)((char *)(iip) - IINFOSIZE(fs)))

#define NTH_IINFO(fs, buf, n) \
	((IINFO *)((char *)SEGSUM_IINFOSTART(fs, buf) - (n)*IINFOSIZE(fs)))

static __inline uint64_t
lfs_ii_getblock(STRUCT_LFS *fs, IINFO *iip)
{
	if (fs->lfs_is64) {
		return iip->u_64.ii_block;
	} else {
		return iip->u_32.ii_block;
	}
}

static __inline void
lfs_ii_setblock(STRUCT_LFS *fs, IINFO *iip, uint64_t block)
{
	if (fs->lfs_is64) {
		iip->u_64.ii_block = block;
	} else {
		iip->u_32.ii_block = block;
	}
}

/*
 * Index file inode entries.
 */

#define IFILE_ENTRYSIZE(fs) \
	((fs)->lfs_is64 ? sizeof(IFILE64) : sizeof(IFILE32))

/*
 * LFSv1 compatibility code is not allowed to touch if_atime, since it
 * may not be mapped!
 */
/* Read in the block with a specific inode from the ifile. */
#define	LFS_IENTRY(IP, F, IN, BP) do {					\
	int _e;								\
	SHARE_IFLOCK(F);						\
	VTOI((F)->lfs_ivnode)->i_state |= IN_ACCESS;			\
	if ((_e = bread((F)->lfs_ivnode,				\
	(IN) / lfs_sb_getifpb(F) + lfs_sb_getcleansz(F) + lfs_sb_getsegtabsz(F), \
	lfs_sb_getbsize(F), 0, &(BP))) != 0)				\
		panic("lfs: ifile ino %d read %d", (int)(IN), _e);	\
	if ((F)->lfs_is64) {						\
		(IP) = (IFILE *)((IFILE64 *)(BP)->b_data +		\
				 (IN) % lfs_sb_getifpb(F));		\
	} else if (lfs_sb_getversion(F) > 1) {				\
		(IP) = (IFILE *)((IFILE32 *)(BP)->b_data +		\
				(IN) % lfs_sb_getifpb(F)); 		\
	} else {							\
		(IP) = (IFILE *)((IFILE_V1 *)(BP)->b_data +		\
				 (IN) % lfs_sb_getifpb(F));		\
	}								\
	UNSHARE_IFLOCK(F);						\
} while (0)
#define LFS_IENTRY_NEXT(IP, F) do { \
	if ((F)->lfs_is64) {						\
		(IP) = (IFILE *)((IFILE64 *)(IP) + 1);			\
	} else if (lfs_sb_getversion(F) > 1) {				\
		(IP) = (IFILE *)((IFILE32 *)(IP) + 1);			\
	} else {							\
		(IP) = (IFILE *)((IFILE_V1 *)(IP) + 1);			\
	}								\
} while (0)

#define LFS_DEF_IF_ACCESSOR(type, type32, field) \
	static __inline type				\
	lfs_if_get##field(STRUCT_LFS *fs, IFILE *ifp)		\
	{							\
		if (fs->lfs_is64) {				\
			return ifp->u_64.if_##field; 		\
		} else {					\
			return ifp->u_32.if_##field; 		\
		}						\
	}							\
	static __inline void				\
	lfs_if_set##field(STRUCT_LFS *fs, IFILE *ifp, type val) \
	{							\
		if (fs->lfs_is64) {				\
			type *p = &ifp->u_64.if_##field;	\
			(void)p;				\
			ifp->u_64.if_##field = val;		\
		} else {					\
			type32 *p = &ifp->u_32.if_##field;	\
			(void)p;				\
			ifp->u_32.if_##field = val;		\
		}						\
	}							\

LFS_DEF_IF_ACCESSOR(uint32_t, uint32_t, version)
LFS_DEF_IF_ACCESSOR(int64_t, int32_t, daddr)
LFS_DEF_IF_ACCESSOR(uint64_t, uint32_t, nextfree)
LFS_DEF_IF_ACCESSOR(uint64_t, uint32_t, atime_sec)
LFS_DEF_IF_ACCESSOR(uint32_t, uint32_t, atime_nsec)

/*
 * Cleaner information structure.  This resides in the ifile and is used
 * to pass information from the kernel to the cleaner.
 */

#define	CLEANSIZE_SU(fs)						\
	((((fs)->lfs_is64 ? sizeof(CLEANERINFO64) : sizeof(CLEANERINFO32)) + \
		lfs_sb_getbsize(fs) - 1) >> lfs_sb_getbshift(fs))

#define LFS_DEF_CI_ACCESSOR(type, type32, field) \
	static __inline type				\
	lfs_ci_get##field(STRUCT_LFS *fs, CLEANERINFO *cip)	\
	{							\
		if (fs->lfs_is64) {				\
			return cip->u_64.field; 		\
		} else {					\
			return cip->u_32.field; 		\
		}						\
	}							\
	static __inline void				\
	lfs_ci_set##field(STRUCT_LFS *fs, CLEANERINFO *cip, type val) \
	{							\
		if (fs->lfs_is64) {				\
			type *p = &cip->u_64.field;		\
			(void)p;				\
			cip->u_64.field = val;			\
		} else {					\
			type32 *p = &cip->u_32.field;		\
			(void)p;				\
			cip->u_32.field = val;			\
		}						\
	}							\

LFS_DEF_CI_ACCESSOR(uint32_t, uint32_t, clean)
LFS_DEF_CI_ACCESSOR(uint32_t, uint32_t, dirty)
LFS_DEF_CI_ACCESSOR(int64_t, int32_t, bfree)
LFS_DEF_CI_ACCESSOR(int64_t, int32_t, avail)
LFS_DEF_CI_ACCESSOR(uint64_t, uint32_t, free_head)
LFS_DEF_CI_ACCESSOR(uint64_t, uint32_t, free_tail)
LFS_DEF_CI_ACCESSOR(uint32_t, uint32_t, flags)

static __inline void
lfs_ci_shiftcleantodirty(STRUCT_LFS *fs, CLEANERINFO *cip, unsigned num)
{
	lfs_ci_setclean(fs, cip, lfs_ci_getclean(fs, cip) - num);
	lfs_ci_setdirty(fs, cip, lfs_ci_getdirty(fs, cip) + num);
}

static __inline void
lfs_ci_shiftdirtytoclean(STRUCT_LFS *fs, CLEANERINFO *cip, unsigned num)
{
	lfs_ci_setdirty(fs, cip, lfs_ci_getdirty(fs, cip) - num);
	lfs_ci_setclean(fs, cip, lfs_ci_getclean(fs, cip) + num);
}

/* Read in the block with the cleaner info from the ifile. */
#define LFS_CLEANERINFO(CP, F, BP) do {					\
	int _e;								\
	SHARE_IFLOCK(F);						\
	VTOI((F)->lfs_ivnode)->i_state |= IN_ACCESS;			\
	_e = bread((F)->lfs_ivnode,					\
	    (daddr_t)0, lfs_sb_getbsize(F), 0, &(BP));			\
	if (_e)								\
		panic("lfs: ifile read: cleanerinfo: error %d\n", _e);	\
	(CP) = (CLEANERINFO *)(BP)->b_data;				\
	UNSHARE_IFLOCK(F);						\
} while (0)

/*
 * Synchronize the Ifile cleaner info with current avail and bfree.
 */
#define LFS_SYNC_CLEANERINFO(cip, fs, bp, w) do {		 	\
    mutex_enter(&lfs_lock);						\
    if ((w) || lfs_ci_getbfree(fs, cip) != lfs_sb_getbfree(fs) ||	\
	lfs_ci_getavail(fs, cip) != lfs_sb_getavail(fs) - fs->lfs_ravail - \
	fs->lfs_favail) {	 					\
	lfs_ci_setbfree(fs, cip, lfs_sb_getbfree(fs));		 	\
	lfs_ci_setavail(fs, cip, lfs_sb_getavail(fs) - fs->lfs_ravail -	\
		fs->lfs_favail);				 	\
	if (((bp)->b_flags & B_GATHERED) == 0) {		 	\
		fs->lfs_flags |= LFS_IFDIRTY;				\
	}								\
	mutex_exit(&lfs_lock);						\
	(void) LFS_BWRITE_LOG(bp); /* Ifile */			 	\
    } else {							 	\
	mutex_exit(&lfs_lock);						\
	brelse(bp, 0);						 	\
    }									\
} while (0)

/*
 * Get the head of the inode free list.
 * Always called with the segment lock held.
 */
#define LFS_GET_HEADFREE(FS, CIP, BP, FREEP) do {			\
	if (lfs_sb_getversion(FS) > 1) {				\
		LFS_CLEANERINFO((CIP), (FS), (BP));			\
		lfs_sb_setfreehd(FS, lfs_ci_getfree_head(FS, CIP));	\
		brelse(BP, 0);						\
	}								\
	*(FREEP) = lfs_sb_getfreehd(FS);				\
} while (0)

#define LFS_PUT_HEADFREE(FS, CIP, BP, VAL) do {				\
	lfs_sb_setfreehd(FS, VAL);					\
	if (lfs_sb_getversion(FS) > 1) {				\
		LFS_CLEANERINFO((CIP), (FS), (BP));			\
		lfs_ci_setfree_head(FS, CIP, VAL);			\
		LFS_BWRITE_LOG(BP);					\
		mutex_enter(&lfs_lock);					\
		(FS)->lfs_flags |= LFS_IFDIRTY;				\
		mutex_exit(&lfs_lock);					\
	}								\
} while (0)

#define LFS_GET_TAILFREE(FS, CIP, BP, FREEP) do {			\
	LFS_CLEANERINFO((CIP), (FS), (BP));				\
	*(FREEP) = lfs_ci_getfree_tail(FS, CIP);			\
	brelse(BP, 0);							\
} while (0)

#define LFS_PUT_TAILFREE(FS, CIP, BP, VAL) do {				\
	LFS_CLEANERINFO((CIP), (FS), (BP));				\
	lfs_ci_setfree_tail(FS, CIP, VAL);				\
	LFS_BWRITE_LOG(BP);						\
	mutex_enter(&lfs_lock);						\
	(FS)->lfs_flags |= LFS_IFDIRTY;					\
	mutex_exit(&lfs_lock);						\
} while (0)

/*
 * On-disk segment summary information
 */

#define SEGSUM_SIZE(fs) \
	(fs->lfs_is64 ? sizeof(SEGSUM64) : \
	 lfs_sb_getversion(fs) > 1 ? sizeof(SEGSUM32) : sizeof(SEGSUM_V1))

/*
 * The SEGSUM structure is followed by FINFO structures. Get the pointer
 * to the first FINFO.
 *
 * XXX this can't be a macro yet; this file needs to be resorted.
 */
#if 0
static __inline FINFO *
segsum_finfobase(STRUCT_LFS *fs, SEGSUM *ssp)
{
	return (FINFO *)((char *)ssp + SEGSUM_SIZE(fs));
}
#else
#define SEGSUM_FINFOBASE(fs, ssp) \
	((FINFO *)((char *)(ssp) + SEGSUM_SIZE(fs)));
#endif

#define LFS_DEF_SS_ACCESSOR(type, type32, field) \
	static __inline type				\
	lfs_ss_get##field(STRUCT_LFS *fs, SEGSUM *ssp)		\
	{							\
		if (fs->lfs_is64) {				\
			return ssp->u_64.ss_##field; 		\
		} else {					\
			return ssp->u_32.ss_##field; 		\
		}						\
	}							\
	static __inline void				\
	lfs_ss_set##field(STRUCT_LFS *fs, SEGSUM *ssp, type val) \
	{							\
		if (fs->lfs_is64) {				\
			type *p = &ssp->u_64.ss_##field;	\
			(void)p;				\
			ssp->u_64.ss_##field = val;		\
		} else {					\
			type32 *p = &ssp->u_32.ss_##field;	\
			(void)p;				\
			ssp->u_32.ss_##field = val;		\
		}						\
	}							\

LFS_DEF_SS_ACCESSOR(uint32_t, uint32_t, sumsum)
LFS_DEF_SS_ACCESSOR(uint32_t, uint32_t, datasum)
LFS_DEF_SS_ACCESSOR(uint32_t, uint32_t, magic)
LFS_DEF_SS_ACCESSOR(uint32_t, uint32_t, ident)
LFS_DEF_SS_ACCESSOR(int64_t, int32_t, next)
LFS_DEF_SS_ACCESSOR(uint16_t, uint16_t, nfinfo)
LFS_DEF_SS_ACCESSOR(uint16_t, uint16_t, ninos)
LFS_DEF_SS_ACCESSOR(uint16_t, uint16_t, flags)
LFS_DEF_SS_ACCESSOR(uint64_t, uint32_t, reclino)
LFS_DEF_SS_ACCESSOR(uint64_t, uint64_t, serial)
LFS_DEF_SS_ACCESSOR(uint64_t, uint64_t, create)

static __inline size_t
lfs_ss_getsumstart(STRUCT_LFS *fs)
{
	/* These are actually all the same. */
	if (fs->lfs_is64) {
		return offsetof(SEGSUM64, ss_datasum);
	} else /* if (lfs_sb_getversion(fs) > 1) */ {
		return offsetof(SEGSUM32, ss_datasum);
	} /* else {
		return offsetof(SEGSUM_V1, ss_datasum);
	} */
	/*
	 * XXX ^^^ until this file is resorted lfs_sb_getversion isn't
	 * defined yet.
	 */
}

static __inline uint32_t
lfs_ss_getocreate(STRUCT_LFS *fs, SEGSUM *ssp)
{
	KASSERT(fs->lfs_is64 == 0);
	/* XXX need to resort this file before we can do this */
	//KASSERT(lfs_sb_getversion(fs) == 1);

	return ssp->u_v1.ss_create;
}

static __inline void
lfs_ss_setocreate(STRUCT_LFS *fs, SEGSUM *ssp, uint32_t val)
{
	KASSERT(fs->lfs_is64 == 0);
	/* XXX need to resort this file before we can do this */
	//KASSERT(lfs_sb_getversion(fs) == 1);

	ssp->u_v1.ss_create = val;
}


/*
 * Super block.
 */

/*
 * Generate accessors for the on-disk superblock fields with cpp.
 */

#define LFS_DEF_SB_ACCESSOR_FULL(type, type32, field) \
	static __inline type				\
	lfs_sb_get##field(STRUCT_LFS *fs)			\
	{							\
		if (fs->lfs_is64) {				\
			return fs->lfs_dlfs_u.u_64.dlfs_##field; \
		} else {					\
			return fs->lfs_dlfs_u.u_32.dlfs_##field; \
		}						\
	}							\
	static __inline void				\
	lfs_sb_set##field(STRUCT_LFS *fs, type val)		\
	{							\
		if (fs->lfs_is64) {				\
			fs->lfs_dlfs_u.u_64.dlfs_##field = val;	\
		} else {					\
			fs->lfs_dlfs_u.u_32.dlfs_##field = val;	\
		}						\
	}							\
	static __inline void				\
	lfs_sb_add##field(STRUCT_LFS *fs, type val)		\
	{							\
		if (fs->lfs_is64) {				\
			type *p64 = &fs->lfs_dlfs_u.u_64.dlfs_##field; \
			*p64 += val;				\
		} else {					\
			type32 *p32 = &fs->lfs_dlfs_u.u_32.dlfs_##field; \
			*p32 += val;				\
		}						\
	}							\
	static __inline void				\
	lfs_sb_sub##field(STRUCT_LFS *fs, type val)		\
	{							\
		if (fs->lfs_is64) {				\
			type *p64 = &fs->lfs_dlfs_u.u_64.dlfs_##field; \
			*p64 -= val;				\
		} else {					\
			type32 *p32 = &fs->lfs_dlfs_u.u_32.dlfs_##field; \
			*p32 -= val;				\
		}						\
	}

#define LFS_DEF_SB_ACCESSOR(t, f) LFS_DEF_SB_ACCESSOR_FULL(t, t, f)

#define LFS_DEF_SB_ACCESSOR_32ONLY(type, field, val64) \
	static __inline type				\
	lfs_sb_get##field(STRUCT_LFS *fs)			\
	{							\
		if (fs->lfs_is64) {				\
			return val64;				\
		} else {					\
			return fs->lfs_dlfs_u.u_32.dlfs_##field; \
		}						\
	}

LFS_DEF_SB_ACCESSOR(uint32_t, version)
LFS_DEF_SB_ACCESSOR_FULL(uint64_t, uint32_t, size)
LFS_DEF_SB_ACCESSOR(uint32_t, ssize)
LFS_DEF_SB_ACCESSOR_FULL(uint64_t, uint32_t, dsize)
LFS_DEF_SB_ACCESSOR(uint32_t, bsize)
LFS_DEF_SB_ACCESSOR(uint32_t, fsize)
LFS_DEF_SB_ACCESSOR(uint32_t, frag)
LFS_DEF_SB_ACCESSOR_FULL(uint64_t, uint32_t, freehd)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, bfree)
LFS_DEF_SB_ACCESSOR_FULL(uint64_t, uint32_t, nfiles)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, avail)
LFS_DEF_SB_ACCESSOR(int32_t, uinodes)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, idaddr)
LFS_DEF_SB_ACCESSOR_32ONLY(uint32_t, ifile, LFS_IFILE_INUM)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, lastseg)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, nextseg)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, curseg)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, offset)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, lastpseg)
LFS_DEF_SB_ACCESSOR(uint32_t, inopf)
LFS_DEF_SB_ACCESSOR(uint32_t, minfree)
LFS_DEF_SB_ACCESSOR(uint64_t, maxfilesize)
LFS_DEF_SB_ACCESSOR(uint32_t, fsbpseg)
LFS_DEF_SB_ACCESSOR(uint32_t, inopb)
LFS_DEF_SB_ACCESSOR(uint32_t, ifpb)
LFS_DEF_SB_ACCESSOR(uint32_t, sepb)
LFS_DEF_SB_ACCESSOR(uint32_t, nindir)
LFS_DEF_SB_ACCESSOR(uint32_t, nseg)
LFS_DEF_SB_ACCESSOR(uint32_t, nspf)
LFS_DEF_SB_ACCESSOR(uint32_t, cleansz)
LFS_DEF_SB_ACCESSOR(uint32_t, segtabsz)
LFS_DEF_SB_ACCESSOR_32ONLY(uint32_t, segmask, 0)
LFS_DEF_SB_ACCESSOR_32ONLY(uint32_t, segshift, 0)
LFS_DEF_SB_ACCESSOR(uint64_t, bmask)
LFS_DEF_SB_ACCESSOR(uint32_t, bshift)
LFS_DEF_SB_ACCESSOR(uint64_t, ffmask)
LFS_DEF_SB_ACCESSOR(uint32_t, ffshift)
LFS_DEF_SB_ACCESSOR(uint64_t, fbmask)
LFS_DEF_SB_ACCESSOR(uint32_t, fbshift)
LFS_DEF_SB_ACCESSOR(uint32_t, blktodb)
LFS_DEF_SB_ACCESSOR(uint32_t, fsbtodb)
LFS_DEF_SB_ACCESSOR(uint32_t, sushift)
LFS_DEF_SB_ACCESSOR(int32_t, maxsymlinklen)
LFS_DEF_SB_ACCESSOR(uint32_t, cksum)
LFS_DEF_SB_ACCESSOR(uint16_t, pflags)
LFS_DEF_SB_ACCESSOR(uint32_t, nclean)
LFS_DEF_SB_ACCESSOR(int32_t, dmeta)
LFS_DEF_SB_ACCESSOR(uint32_t, minfreeseg)
LFS_DEF_SB_ACCESSOR(uint32_t, sumsize)
LFS_DEF_SB_ACCESSOR(uint64_t, serial)
LFS_DEF_SB_ACCESSOR(uint32_t, ibsize)
LFS_DEF_SB_ACCESSOR_FULL(int64_t, int32_t, s0addr)
LFS_DEF_SB_ACCESSOR(uint64_t, tstamp)
LFS_DEF_SB_ACCESSOR(uint32_t, inodefmt)
LFS_DEF_SB_ACCESSOR(uint32_t, interleave)
LFS_DEF_SB_ACCESSOR(uint32_t, ident)
LFS_DEF_SB_ACCESSOR(uint32_t, resvseg)

/* special-case accessors */

/*
 * the v1 otstamp field lives in what's now dlfs_inopf
 */
#define lfs_sb_getotstamp(fs) lfs_sb_getinopf(fs)
#define lfs_sb_setotstamp(fs, val) lfs_sb_setinopf(fs, val)

/*
 * lfs_sboffs is an array
 */
static __inline int32_t
lfs_sb_getsboff(STRUCT_LFS *fs, unsigned n)
{
#ifdef KASSERT /* ugh */
	KASSERT(n < LFS_MAXNUMSB);
#endif
	if (fs->lfs_is64) {
		return fs->lfs_dlfs_u.u_64.dlfs_sboffs[n];
	} else {
		return fs->lfs_dlfs_u.u_32.dlfs_sboffs[n];
	}
}
static __inline void
lfs_sb_setsboff(STRUCT_LFS *fs, unsigned n, int32_t val)
{
#ifdef KASSERT /* ugh */
	KASSERT(n < LFS_MAXNUMSB);
#endif
	if (fs->lfs_is64) {
		fs->lfs_dlfs_u.u_64.dlfs_sboffs[n] = val;
	} else {
		fs->lfs_dlfs_u.u_32.dlfs_sboffs[n] = val;
	}
}

/*
 * lfs_fsmnt is a string
 */
static __inline const char *
lfs_sb_getfsmnt(STRUCT_LFS *fs)
{
	if (fs->lfs_is64) {
		return (const char *)fs->lfs_dlfs_u.u_64.dlfs_fsmnt;
	} else {
		return (const char *)fs->lfs_dlfs_u.u_32.dlfs_fsmnt;
	}
}

static __inline void
lfs_sb_setfsmnt(STRUCT_LFS *fs, const char *str)
{
	if (fs->lfs_is64) {
		(void)strncpy((char *)fs->lfs_dlfs_u.u_64.dlfs_fsmnt, str,
			sizeof(fs->lfs_dlfs_u.u_64.dlfs_fsmnt));
	} else {
		(void)strncpy((char *)fs->lfs_dlfs_u.u_32.dlfs_fsmnt, str,
			sizeof(fs->lfs_dlfs_u.u_32.dlfs_fsmnt));
	}
}

/* Highest addressable fsb */
#define LFS_MAX_DADDR(fs) \
	((fs)->lfs_is64 ? 0x7fffffffffffffff : 0x7fffffff)

/* LFS_NINDIR is the number of indirects in a file system block. */
#define	LFS_NINDIR(fs)	(lfs_sb_getnindir(fs))

/* LFS_INOPB is the number of inodes in a secondary storage block. */
#define	LFS_INOPB(fs)	(lfs_sb_getinopb(fs))
/* LFS_INOPF is the number of inodes in a fragment. */
#define LFS_INOPF(fs)	(lfs_sb_getinopf(fs))

#define	lfs_blkoff(fs, loc)	((int)((loc) & lfs_sb_getbmask(fs)))
#define lfs_fragoff(fs, loc)    /* calculates (loc % fs->lfs_fsize) */ \
    ((int)((loc) & lfs_sb_getffmask(fs)))

/* XXX: lowercase these as they're no longer macros */
/* Frags to diskblocks */
static __inline uint64_t
LFS_FSBTODB(STRUCT_LFS *fs, uint64_t b)
{
#if defined(_KERNEL)
	return b << (lfs_sb_getffshift(fs) - DEV_BSHIFT);
#else
	return b << lfs_sb_getfsbtodb(fs);
#endif
}
/* Diskblocks to frags */
static __inline uint64_t
LFS_DBTOFSB(STRUCT_LFS *fs, uint64_t b)
{
#if defined(_KERNEL)
	return b >> (lfs_sb_getffshift(fs) - DEV_BSHIFT);
#else
	return b >> lfs_sb_getfsbtodb(fs);
#endif
}

#define	lfs_lblkno(fs, loc)	((loc) >> lfs_sb_getbshift(fs))
#define	lfs_lblktosize(fs, blk)	((blk) << lfs_sb_getbshift(fs))

/* Frags to bytes */
static __inline uint64_t
lfs_fsbtob(STRUCT_LFS *fs, uint64_t b)
{
	return b << lfs_sb_getffshift(fs);
}
/* Bytes to frags */
static __inline uint64_t
lfs_btofsb(STRUCT_LFS *fs, uint64_t b)
{
	return b >> lfs_sb_getffshift(fs);
}

#define lfs_numfrags(fs, loc)	/* calculates (loc / fs->lfs_fsize) */	\
	((loc) >> lfs_sb_getffshift(fs))
#define lfs_blkroundup(fs, size)/* calculates roundup(size, lfs_sb_getbsize(fs)) */ \
	((off_t)(((size) + lfs_sb_getbmask(fs)) & (~lfs_sb_getbmask(fs))))
#define lfs_fragroundup(fs, size)/* calculates roundup(size, fs->lfs_fsize) */ \
	((off_t)(((size) + lfs_sb_getffmask(fs)) & (~lfs_sb_getffmask(fs))))
#define lfs_fragstoblks(fs, frags)/* calculates (frags / fs->fs_frag) */ \
	((frags) >> lfs_sb_getfbshift(fs))
#define lfs_blkstofrags(fs, blks)/* calculates (blks * fs->fs_frag) */ \
	((blks) << lfs_sb_getfbshift(fs))
#define lfs_fragnum(fs, fsb)	/* calculates (fsb % fs->lfs_frag) */	\
	((fsb) & ((fs)->lfs_frag - 1))
#define lfs_blknum(fs, fsb)	/* calculates rounddown(fsb, fs->lfs_frag) */ \
	((fsb) &~ ((fs)->lfs_frag - 1))
#define lfs_dblksize(fs, dp, lbn) \
	(((lbn) >= ULFS_NDADDR || lfs_dino_getsize(fs, dp) >= ((lbn) + 1) << lfs_sb_getbshift(fs)) \
	    ? lfs_sb_getbsize(fs) \
	    : (lfs_fragroundup(fs, lfs_blkoff(fs, lfs_dino_getsize(fs, dp)))))

#define	lfs_segsize(fs)	(lfs_sb_getversion(fs) == 1 ?	     		\
			   lfs_lblktosize((fs), lfs_sb_getssize(fs)) :	\
			   lfs_sb_getssize(fs))
/* XXX segtod produces a result in frags despite the 'd' */
#define lfs_segtod(fs, seg) (lfs_btofsb(fs, lfs_segsize(fs)) * (seg))
#define	lfs_dtosn(fs, daddr)	/* block address to segment number */	\
	((uint32_t)(((daddr) - lfs_sb_gets0addr(fs)) / lfs_segtod((fs), 1)))
#define lfs_sntod(fs, sn)	/* segment number to disk address */	\
	((daddr_t)(lfs_segtod((fs), (sn)) + lfs_sb_gets0addr(fs)))

/* XXX, blah. make this appear only if struct inode is defined */
#ifdef _UFS_LFS_LFS_INODE_H_
static __inline uint32_t
lfs_blksize(STRUCT_LFS *fs, struct inode *ip, uint64_t lbn)
{
	if (lbn >= ULFS_NDADDR || lfs_dino_getsize(fs, ip->i_din) >= (lbn + 1) << lfs_sb_getbshift(fs)) {
		return lfs_sb_getbsize(fs);
	} else {
		return lfs_fragroundup(fs, lfs_blkoff(fs, lfs_dino_getsize(fs, ip->i_din)));
	}
}
#endif

/*
 * union lfs_blocks
 */

static __inline void
lfs_blocks_fromvoid(STRUCT_LFS *fs, union lfs_blocks *bp, void *p)
{
	if (fs->lfs_is64) {
		bp->b64 = p;
	} else {
		bp->b32 = p;
	}
}

static __inline void
lfs_blocks_fromfinfo(STRUCT_LFS *fs, union lfs_blocks *bp, FINFO *fip)
{
	void *firstblock;

	firstblock = (char *)fip + FINFOSIZE(fs);
	if (fs->lfs_is64) {
		bp->b64 = (int64_t *)firstblock;
	}  else {
		bp->b32 = (int32_t *)firstblock;
	}
}

static __inline daddr_t
lfs_blocks_get(STRUCT_LFS *fs, union lfs_blocks *bp, unsigned idx)
{
	if (fs->lfs_is64) {
		return bp->b64[idx];
	} else {
		return bp->b32[idx];
	}
}

static __inline void
lfs_blocks_set(STRUCT_LFS *fs, union lfs_blocks *bp, unsigned idx, daddr_t val)
{
	if (fs->lfs_is64) {
		bp->b64[idx] = val;
	} else {
		bp->b32[idx] = val;
	}
}

static __inline void
lfs_blocks_inc(STRUCT_LFS *fs, union lfs_blocks *bp)
{
	if (fs->lfs_is64) {
		bp->b64++;
	} else {
		bp->b32++;
	}
}

static __inline int
lfs_blocks_eq(STRUCT_LFS *fs, union lfs_blocks *bp1, union lfs_blocks *bp2)
{
	if (fs->lfs_is64) {
		return bp1->b64 == bp2->b64;
	} else {
		return bp1->b32 == bp2->b32;
	}
}

static __inline int
lfs_blocks_sub(STRUCT_LFS *fs, union lfs_blocks *bp1, union lfs_blocks *bp2)
{
	/* (remember that the pointers are typed) */
	if (fs->lfs_is64) {
		return bp1->b64 - bp2->b64;
	} else {
		return bp1->b32 - bp2->b32;
	}
}

/*
 * struct segment
 */


/*
 * Macros for determining free space on the disk, with the variable metadata
 * of segment summaries and inode blocks taken into account.
 */
/*
 * Estimate number of clean blocks not available for writing because
 * they will contain metadata or overhead.  This is calculated as
 *
 *		E = ((C * M / D) * D + (0) * (T - D)) / T
 * or more simply
 *		E = (C * M) / T
 *
 * where
 * C is the clean space,
 * D is the dirty space,
 * M is the dirty metadata, and
 * T = C + D is the total space on disk.
 *
 * This approximates the old formula of E = C * M / D when D is close to T,
 * but avoids falsely reporting "disk full" when the sample size (D) is small.
 */
#define LFS_EST_CMETA(F) ((						\
	(lfs_sb_getdmeta(F) * (int64_t)lfs_sb_getnclean(F)) / 		\
	(lfs_sb_getnseg(F))))

/* Estimate total size of the disk not including metadata */
#define LFS_EST_NONMETA(F) (lfs_sb_getdsize(F) - lfs_sb_getdmeta(F) - LFS_EST_CMETA(F))

/* Estimate number of blocks actually available for writing */
#define LFS_EST_BFREE(F) (lfs_sb_getbfree(F) > LFS_EST_CMETA(F) ?	     \
			  lfs_sb_getbfree(F) - LFS_EST_CMETA(F) : 0)

/* Amount of non-meta space not available to mortal man */
#define LFS_EST_RSVD(F) ((LFS_EST_NONMETA(F) *			     \
				   (uint64_t)lfs_sb_getminfree(F)) /	     \
				  100)

/* Can credential C write BB blocks? XXX: kauth_cred_geteuid is abusive */
#define ISSPACE(F, BB, C)						\
	((((C) == NOCRED || kauth_cred_geteuid(C) == 0) &&		\
	  LFS_EST_BFREE(F) >= (BB)) ||					\
	 (kauth_cred_geteuid(C) != 0 && IS_FREESPACE(F, BB)))

/* Can an ordinary user write BB blocks */
#define IS_FREESPACE(F, BB)						\
	  (LFS_EST_BFREE(F) >= (BB) + LFS_EST_RSVD(F))

/*
 * The minimum number of blocks to create a new inode.  This is:
 * directory direct block (1) + ULFS_NIADDR indirect blocks + inode block (1) +
 * ifile direct block (1) + ULFS_NIADDR indirect blocks = 3 + 2 * ULFS_NIADDR blocks.
 */
#define LFS_NRESERVE(F) (lfs_btofsb((F), (2 * ULFS_NIADDR + 3) << lfs_sb_getbshift(F)))


/*
 * Suppress spurious clang warnings
 */
#ifdef __GNUC__
#if defined(__clang__)
#pragma clang diagnostic pop
#elif __GNUC_PREREQ__(9,0)
#pragma GCC diagnostic pop
#endif
#endif


#endif /* _UFS_LFS_LFS_ACCESSORS_H_ */