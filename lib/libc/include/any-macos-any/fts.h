/*
 * Copyright (c) 2000, 2003-2006, 2008, 2012 Apple Inc. All rights reserved.
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
 * Copyright (c) 1989, 1993
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)fts.h	8.3 (Berkeley) 8/14/94
 */

#ifndef	_FTS_H_
#define	_FTS_H_

#include <sys/_types.h>
#include <sys/_types/_dev_t.h>
#include <sys/_types/_ino_t.h>
#include <sys/_types/_nlink_t.h>

#include <Availability.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"

typedef struct {
	struct _ftsent *fts_cur;	/* current node */
	struct _ftsent *fts_child;	/* linked list of children */
	struct _ftsent **fts_array;	/* sort array */
	dev_t fts_dev;			/* starting device # */
	char *fts_path;			/* path for this descent */
	int fts_rfd;			/* fd for root */
	int fts_pathlen;		/* sizeof(path) */
	int fts_nitems;			/* elements in the sort array */
#ifdef __BLOCKS__
	union {
#endif /* __BLOCKS__ */
	    int (*fts_compar)();	/* compare function */
#ifdef __BLOCKS__
	    int (^fts_compar_b)();	/* compare block */
	};
#endif /* __BLOCKS__ */

#define	FTS_COMFOLLOW	0x001		/* follow command line symlinks */
#define	FTS_LOGICAL	0x002		/* logical walk */
#define	FTS_NOCHDIR	0x004		/* don't change directories */
#define	FTS_NOSTAT	0x008		/* don't get stat info */
#define	FTS_PHYSICAL	0x010		/* physical walk */
#define	FTS_SEEDOT	0x020		/* return dot and dot-dot */
#define	FTS_XDEV	0x040		/* don't cross devices */
#define	FTS_WHITEOUT	0x080		/* (no longer supported) return whiteout information */
#define	FTS_COMFOLLOWDIR 0x400		/* (non-std) follow command line symlinks for directories only */
#if (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED < 1090) || (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED < 70000)
#define	FTS_OPTIONMASK	0x4ff		/* valid user option mask */
#else
#define	FTS_NOSTAT_TYPE	0x800		/* (non-std) no stat, but use d_type in struct dirent when available */
#define	FTS_OPTIONMASK	0xcff		/* valid user option mask */
#endif

#define	FTS_NAMEONLY	0x100		/* (private) child names only */
#define	FTS_STOP	0x200		/* (private) unrecoverable error */
#ifdef __BLOCKS__
#define	FTS_BLOCK_COMPAR 0x80000000	/* fts_compar is a block */
#endif /* __BLOCKS__ */
	int fts_options;		/* fts_open options, global flags */
} FTS;

typedef struct _ftsent {
	struct _ftsent *fts_cycle;	/* cycle node */
	struct _ftsent *fts_parent;	/* parent directory */
	struct _ftsent *fts_link;	/* next file in directory */
	long fts_number;	        /* local numeric value */
	void *fts_pointer;	        /* local address value */
	char *fts_accpath;		/* access path */
	char *fts_path;			/* root path */
	int fts_errno;			/* errno for this node */
	int fts_symfd;			/* fd for symlink or chdir */
	unsigned short fts_pathlen;	/* strlen(fts_path) */
	unsigned short fts_namelen;	/* strlen(fts_name) */

	ino_t fts_ino;			/* inode */
	dev_t fts_dev;			/* device */
	nlink_t fts_nlink;		/* link count */

#define	FTS_ROOTPARENTLEVEL	-1
#define	FTS_ROOTLEVEL		 0
#define	FTS_MAXLEVEL		 0x7fffffff
	short fts_level;		/* depth (-1 to N) */

#define	FTS_D		 1		/* preorder directory */
#define	FTS_DC		 2		/* directory that causes cycles */
#define	FTS_DEFAULT	 3		/* none of the above */
#define	FTS_DNR		 4		/* unreadable directory */
#define	FTS_DOT		 5		/* dot or dot-dot */
#define	FTS_DP		 6		/* postorder directory */
#define	FTS_ERR		 7		/* error; errno is set */
#define	FTS_F		 8		/* regular file */
#define	FTS_INIT	 9		/* initialized only */
#define	FTS_NS		10		/* stat(2) failed */
#define	FTS_NSOK	11		/* no stat(2) requested */
#define	FTS_SL		12		/* symbolic link */
#define	FTS_SLNONE	13		/* symbolic link without target */
#define	FTS_W		14		/* whiteout object */
	unsigned short fts_info;	/* user flags for FTSENT structure */

#define	FTS_DONTCHDIR	 0x01		/* don't chdir .. to the parent */
#define	FTS_SYMFOLLOW	 0x02		/* followed a symlink to get here */
#define	FTS_ISW		 0x04		/* this is a whiteout object */
#define	FTS_CHDIRFD 0x08 /* indicates the fts_symfd field was set for chdir */
	unsigned short fts_flags;	/* private flags for FTSENT structure */

#define	FTS_AGAIN	 1		/* read node again */
#define	FTS_FOLLOW	 2		/* follow symbolic link */
#define	FTS_NOINSTR	 3		/* no instructions */
#define	FTS_SKIP	 4		/* discard node */
	unsigned short fts_instr;	/* fts_set() instructions */

	struct stat *fts_statp;		/* stat(2) information */
	char fts_name[1];		/* file name */
} FTSENT;

#include <sys/cdefs.h>
#include <Availability.h>

__BEGIN_DECLS
//Begin-Libc
#ifndef LIBC_ALIAS_FTS_CHILDREN
//End-Libc
FTSENT	*fts_children(FTS *, int) __DARWIN_INODE64(fts_children);
//Begin-Libc
#else /* LIBC_ALIAS_FTS_CHILDREN */
FTSENT	*fts_children(FTS *, int) LIBC_INODE64(fts_children);
#endif /* !LIBC_ALIAS_FTS_CHILDREN */
//End-Libc
//Begin-Libc
#ifndef LIBC_ALIAS_FTS_CLOSE
//End-Libc
int	 fts_close(FTS *) __DARWIN_INODE64(fts_close);
//Begin-Libc
#else /* LIBC_ALIAS_FTS_CLOSE */
int	 fts_close(FTS *) LIBC_INODE64(fts_close);
#endif /* !LIBC_ALIAS_FTS_CLOSE */
//End-Libc
//Begin-Libc
#ifndef LIBC_ALIAS_FTS_OPEN
//End-Libc
FTS	*fts_open(char * const *, int,
	    int (*)(const FTSENT **, const FTSENT **)) __DARWIN_INODE64(fts_open);
//Begin-Libc
#else /* LIBC_ALIAS_FTS_OPEN */
FTS	*fts_open(char * const *, int,
	    int (*)(const FTSENT **, const FTSENT **)) LIBC_INODE64(fts_open);
#endif /* !LIBC_ALIAS_FTS_OPEN */
//End-Libc
#ifdef __BLOCKS__
#if __has_attribute(noescape)
#define __fts_noescape __attribute__((__noescape__))
#else
#define __fts_noescape
#endif
//Begin-Libc
#ifndef LIBC_ALIAS_FTS_OPEN_B
//End-Libc
FTS	*fts_open_b(char * const *, int,
	    int (^)(const FTSENT **, const FTSENT **) __fts_noescape)
	    __DARWIN_INODE64(fts_open_b) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
//Begin-Libc
#else /* LIBC_ALIAS_FTS_OPEN */
FTS	*fts_open_b(char * const *, int,
	    int (^)(const FTSENT **, const FTSENT **) __fts_noescape)
	    LIBC_INODE64(fts_open_b);
#endif /* !LIBC_ALIAS_FTS_OPEN */
//End-Libc
#endif /* __BLOCKS__ */
//Begin-Libc
#ifndef LIBC_ALIAS_FTS_READ
//End-Libc
FTSENT	*fts_read(FTS *) __DARWIN_INODE64(fts_read);
//Begin-Libc
#else /* LIBC_ALIAS_FTS_READ */
FTSENT	*fts_read(FTS *) LIBC_INODE64(fts_read);
#endif /* !LIBC_ALIAS_FTS_READ */
//End-Libc
//Begin-Libc
#ifndef LIBC_ALIAS_FTS_SET
//End-Libc
int	 fts_set(FTS *, FTSENT *, int) __DARWIN_INODE64(fts_set);
//Begin-Libc
#else /* LIBC_ALIAS_FTS_SET */
int	 fts_set(FTS *, FTSENT *, int) LIBC_INODE64(fts_set);
#endif /* !LIBC_ALIAS_FTS_SET */
//End-Libc
__END_DECLS

#pragma clang diagnostic pop
#endif /* !_FTS_H_ */

