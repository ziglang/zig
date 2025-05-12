/*	$NetBSD: ptyfs.h,v 1.16 2020/11/27 14:43:57 christos Exp $	*/

/*
 * Copyright (c) 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Jan-Simon Pendry.
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
 *	@(#)procfs.h	8.9 (Berkeley) 5/14/95
 */

/*
 * Copyright (c) 1993 Jan-Simon Pendry
 *
 * This code is derived from software contributed to Berkeley by
 * Jan-Simon Pendry.
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
 *	@(#)procfs.h	8.9 (Berkeley) 5/14/95
 */

#ifndef _FS_PTYFS_PTYFS_H_
#define _FS_PTYFS_PTYFS_H_

#ifdef _KERNEL
/*
 * The different types of node in a ptyfs filesystem
 */
typedef enum {
	PTYFSpts,	/* The slave side of a pty */
	PTYFSptc,	/* The controlling side of a pty */
	PTYFSroot,	/* the filesystem root */
} ptyfstype;

/*
 * control data for the proc file system.
 */
struct ptyfskey {
	ptyfstype	ptk_type;	/* type of ptyfs node */
	int		ptk_pty;	/* the pty index */
};
struct ptyfsnode {
	SLIST_ENTRY(ptyfsnode) ptyfs_hash;	/* hash chain */
	struct ptyfskey	ptyfs_key;
#define ptyfs_type	ptyfs_key.ptk_type
#define ptyfs_pty	ptyfs_key.ptk_pty
	u_long		ptyfs_fileno;	/* unique file id */
	int		ptyfs_status;	/* status flag for times */
#define	PTYFS_ACCESS	1
#define	PTYFS_MODIFY	2
#define	PTYFS_CHANGE	4
	/* Attribute information */
	uid_t		ptyfs_uid;
	gid_t		ptyfs_gid;
	mode_t		ptyfs_mode;
	int		ptyfs_flags;
	struct timespec	ptyfs_ctime, ptyfs_mtime, ptyfs_atime, ptyfs_birthtime;
};

struct ptyfsmount {
	kmutex_t pmnt_lock;
	TAILQ_ENTRY(ptyfsmount) pmnt_le;
	struct mount *pmnt_mp;
	gid_t pmnt_gid;
	mode_t pmnt_mode;
	int pmnt_flags;
	int pmnt_bitmap_size;
	uint8_t *pmnt_bitmap;
};

#define VFSTOPTY(mp)	((struct ptyfsmount *)(mp)->mnt_data)

#endif /* _KERNEL */

struct ptyfs_args {
	int version;
	gid_t gid;
	mode_t mode;
	int flags;
};

#define PTYFS_ARGSVERSION	2

/*
 * Kernel stuff follows
 */
#ifdef _KERNEL

#define UIO_MX 32

#define PTYFS_FILENO(type, pty) \
    ((type == PTYFSroot) ? 2 : \
     ((((pty) + 1) * 2 + (((type) == PTYFSpts) ? 1 : 2))))

#define PTYFS_MAKEDEV(ptyfs) \
    pty_makedev((ptyfs)->ptyfs_type == PTYFSpts ? 't' : 'p', (ptyfs)->ptyfs_pty)

#define PTYFS_ITIMES(ptyfs, acc, mod, cre) \
   while ((ptyfs)->ptyfs_status & (PTYFS_ACCESS|PTYFS_CHANGE|PTYFS_MODIFY)) \
	ptyfs_itimes(ptyfs, acc, mod, cre)
/*
 * Convert between ptyfsnode vnode
 */
#define VTOPTYFS(vp)	((struct ptyfsnode *)(vp)->v_data)

void ptyfs_set_active(struct mount *, int);
void ptyfs_clr_active(struct mount *, int);
int ptyfs_next_active(struct mount *, int);
int ptyfs_allocvp(struct mount *, struct vnode **, ptyfstype, int);
void ptyfs_hashinit(void);
void ptyfs_hashdone(void);
struct ptyfsnode *ptyfs_get_node(ptyfstype, int);
void ptyfs_itimes(struct ptyfsnode *, const struct timespec *,
    const struct timespec *, const struct timespec *);

extern int (**ptyfs_vnodeop_p)(void *);
extern struct vfsops ptyfs_vfsops;

int	ptyfs_root(struct mount *, int, struct vnode **);

#endif /* _KERNEL */
#endif /* _FS_PTYFS_PTYFS_H_ */