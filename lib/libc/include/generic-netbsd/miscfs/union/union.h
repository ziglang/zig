/*	$NetBSD: union.h,v 1.30 2020/08/18 09:44:07 hannken Exp $	*/

/*
 * Copyright (c) 1994 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software donated to Berkeley by
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
 *	@(#)union.h	8.9 (Berkeley) 12/10/94
 */

/*
 * Copyright (c) 1994 Jan-Simon Pendry.
 * All rights reserved.
 *
 * This code is derived from software donated to Berkeley by
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
 *	@(#)union.h	8.9 (Berkeley) 12/10/94
 */

#ifndef _MISCFS_UNION_H_
#define _MISCFS_UNION_H_

struct union_args {
	char		*target;	/* Target of loopback  */
	int		mntflags;	/* Options on the mount */
};

#define UNMNT_ABOVE	0x0001		/* Target appears below mount point */
#define UNMNT_BELOW	0x0002		/* Target appears below mount point */
#define UNMNT_REPLACE	0x0003		/* Target replaces mount point */
#define UNMNT_OPMASK	0x0003

#define UNMNT_BITS "\177\20" \
    "b\00above\0b\01below\0b\02replace\0"

#ifdef _KERNEL

struct union_mount {
	struct vnode	*um_uppervp;
	struct vnode	*um_lowervp;
	kauth_cred_t	um_cred;	/* Credentials of user calling mount */
	int		um_cmode;	/* cmask from mount process */
	int		um_op;		/* Operation mode */
};

/*
 * DEFDIRMODE is the mode bits used to create a shadow directory.
 */
#define	UN_DIRMODE	(S_IRWXU|S_IRWXG|S_IRWXO)
#define	UN_FILEMODE	(S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH)

/*
 * A cache of vnode references.
 * Lock requirements are:
 *
 *	:	stable
 *	c	unheadlock[hash]
 *	l	un_lock
 *	m	un_lock or vnode lock to read, un_lock and
 *			exclusive vnode lock to write
 *	v	vnode lock to read, exclusive vnode lock to write
 *
 * Lock order is vnode then un_lock.
 */
struct union_node {
	kmutex_t		un_lock;
	LIST_ENTRY(union_node)	un_cache;	/* c: Hash chain */
	int			un_refs;	/* c: Reference counter */
	struct mount		*un_mount;	/* c: union mount */
	struct vnode		*un_vnode;	/* :: Back pointer */
	struct vnode	        *un_uppervp;	/* m: overlaying object */
	struct vnode	        *un_lowervp;	/* v: underlying object */
	struct vnode		*un_dirvp;	/* v: Parent dir of uppervp */
	struct vnode		*un_pvp;	/* v: Parent vnode */
	char			*un_path;	/* v: saved component name */
	int			un_openl;	/* v: # of opens on lowervp */
	unsigned int		un_cflags;	/* c: cache flags */
	bool			un_hooknode;	/* :: from union_readdirhook */
	struct vnode		**un_dircache;	/* v: cached union stack */
	off_t			un_uppersz;	/* l: size of upper object */
	off_t			un_lowersz;	/* l: size of lower object */
};

#define UN_CACHED	0x10		/* In union cache */

extern int union_allocvp(struct vnode **, struct mount *,
				struct vnode *, struct vnode *,
				struct componentname *, struct vnode *,
				struct vnode *, int);
extern int union_check_rmdir(struct union_node *, kauth_cred_t);
extern int union_copyfile(struct vnode *, struct vnode *, kauth_cred_t,
    struct lwp *);
extern int union_copyup(struct union_node *, int, kauth_cred_t,
    struct lwp *);
extern void union_diruncache(struct union_node *);
extern int union_dowhiteout(struct union_node *, kauth_cred_t);
extern int union_mkshadow(struct union_mount *, struct vnode *,
    struct componentname *, struct vnode **);
extern int union_mkwhiteout(struct union_mount *, struct vnode *,
    struct componentname *, struct union_node *);
extern int union_vn_create(struct vnode **, struct union_node *,
    struct lwp *);
extern int union_cn_close(struct vnode *, int, kauth_cred_t,
    struct lwp *);
extern void union_removed_upper(struct union_node *un);
extern struct vnode *union_lowervp(struct vnode *);
extern void union_newsize(struct vnode *, off_t, off_t);
int union_readdirhook(struct vnode **, struct file *, struct lwp *);

VFS_PROTOS(union);

#define	MOUNTTOUNIONMOUNT(mp) ((struct union_mount *)((mp)->mnt_data))
#define	VTOUNION(vp) ((struct union_node *)(vp)->v_data)
#define	UNIONTOV(un) ((un)->un_vnode)
#define	LOWERVP(vp) (VTOUNION(vp)->un_lowervp)
#define	UPPERVP(vp) (VTOUNION(vp)->un_uppervp)
#define OTHERVP(vp) (UPPERVP(vp) ? UPPERVP(vp) : LOWERVP(vp))
#define LOCKVP(vp) (UPPERVP(vp) ? UPPERVP(vp) : (vp))

extern int (**union_vnodeop_p)(void *);

void union_init(void);
void union_reinit(void);
void union_done(void);
int union_freevp(struct vnode *);

#endif /* _KERNEL */
#endif /* _MISCFS_UNION_H_ */