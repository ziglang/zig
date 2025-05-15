/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1994 The Regents of the University of California.
 * Copyright (c) 1994 Jan-Simon Pendry.
 * Copyright (c) 2005, 2006 Masanori Ozawa <ozawa@ongs.co.jp>, ONGS Inc.
 * Copyright (c) 2006 Daichi Goto <daichi@freebsd.org>
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

#ifdef _KERNEL

/* copy method of attr from lower to upper */
typedef enum _unionfs_copymode {
	UNIONFS_TRADITIONAL = 0,
	UNIONFS_TRANSPARENT,
	UNIONFS_MASQUERADE
} unionfs_copymode;

/* whiteout policy of upper layer */
typedef enum _unionfs_whitemode {
       UNIONFS_WHITE_ALWAYS = 0,
       UNIONFS_WHITE_WHENNEEDED
} unionfs_whitemode;

struct unionfs_mount {
	struct mount   *um_lowermp;     /* MNT_REFed lower mount object */
	struct mount   *um_uppermp;     /* MNT_REFed upper mount object */
	struct vnode   *um_lowervp;	/* VREFed once */
	struct vnode   *um_uppervp;	/* VREFed once */
	struct vnode   *um_rootvp;	/* ROOT vnode */
	struct mount_upper_node	um_lower_link;	/* node in lower FS list of uppers */
	struct mount_upper_node	um_upper_link;	/* node in upper FS list of uppers */
	unionfs_copymode um_copymode;
	unionfs_whitemode um_whitemode;
	uid_t		um_uid;
	gid_t		um_gid;
	u_short		um_udir;
	u_short		um_ufile;
};

/* unionfs status list */
struct unionfs_node_status {
	LIST_ENTRY(unionfs_node_status) uns_list;	/* Status list */
	pid_t		uns_pid;		/* current process id */
	int		uns_node_flag;		/* uns flag */
	int		uns_lower_opencnt;	/* open count of lower */
	int		uns_upper_opencnt;	/* open count of upper */
	int		uns_lower_openmode;	/* open mode of lower */
	int		uns_readdir_status;	/* read status of readdir */
};

/* union node status flags */
#define	UNS_OPENL_4_READDIR	0x01	/* open lower layer for readdir */

/* A cache of vnode references */
struct unionfs_node {
	struct vnode   *un_lowervp;		/* lower side vnode */
	struct vnode   *un_uppervp;		/* upper side vnode */
	struct vnode   *un_dvp;			/* parent unionfs vnode */
	struct vnode   *un_vnode;		/* Back pointer */
	LIST_HEAD(, unionfs_node_status) un_unshead;
						/* unionfs status head */
	LIST_HEAD(unionfs_node_hashhead, unionfs_node) *un_hashtbl;
						/* dir vnode hash table */
	union {
		LIST_ENTRY(unionfs_node) un_hash; /* hash list entry */
		STAILQ_ENTRY(unionfs_node) un_rele; /* deferred release list */
	};

	char           *un_path;		/* path */
	int		un_pathlen;		/* strlen of path */
	int		un_flag;		/* unionfs node flag */
};

/*
 * unionfs node flags
 * It needs the vnode with exclusive lock, when changing the un_flag variable.
 */
#define UNIONFS_OPENEXTL	0x01	/* openextattr (lower) */
#define UNIONFS_OPENEXTU	0x02	/* openextattr (upper) */

extern struct vop_vector unionfs_vnodeops;

static inline struct unionfs_node *
unionfs_check_vnode(struct vnode *vp, const char *file __unused,
    int line __unused)
{
	/*
	 * unionfs_lock() needs the NULL check here, as it explicitly
	 * handles the case in which the vnode has been vgonel()'ed.
	 */
	KASSERT(vp->v_op == &unionfs_vnodeops || vp->v_data == NULL,
	    ("%s:%d: non-unionfs vnode %p", file, line, vp));
	return ((struct unionfs_node *)vp->v_data);
}

#define	MOUNTTOUNIONFSMOUNT(mp) ((struct unionfs_mount *)((mp)->mnt_data))
#define	VTOUNIONFS(vp) unionfs_check_vnode(vp, __FILE__, __LINE__)
#define	UNIONFSTOV(xp) ((xp)->un_vnode)

int	unionfs_init(struct vfsconf *);
int	unionfs_uninit(struct vfsconf *);
int	unionfs_nodeget(struct mount *, struct vnode *, struct vnode *,
	    struct vnode *, struct vnode **, struct componentname *);
void	unionfs_noderem(struct vnode *);
void	unionfs_get_node_status(struct unionfs_node *, struct thread *,
	    struct unionfs_node_status **);
void	unionfs_tryrem_node_status(struct unionfs_node *,
	    struct unionfs_node_status *);
int	unionfs_check_rmdir(struct vnode *, struct ucred *, struct thread *td);
int	unionfs_copyfile(struct unionfs_node *, int, struct ucred *,
	    struct thread *);
void	unionfs_create_uppervattr_core(struct unionfs_mount *, struct vattr *,
	    struct vattr *, struct thread *);
int	unionfs_create_uppervattr(struct unionfs_mount *, struct vnode *,
	    struct vattr *, struct ucred *, struct thread *);
int	unionfs_mkshadowdir(struct unionfs_mount *, struct vnode *,
	    struct unionfs_node *, struct componentname *, struct thread *);
int	unionfs_mkwhiteout(struct vnode *, struct vnode *,
	    struct componentname *, struct thread *, char *, int);
int	unionfs_relookup(struct vnode *, struct vnode **,
	    struct componentname *, struct componentname *, struct thread *,
	    char *, int, u_long);
int	unionfs_relookup_for_create(struct vnode *, struct componentname *,
	    struct thread *);
int	unionfs_relookup_for_delete(struct vnode *, struct componentname *,
	    struct thread *);
int	unionfs_relookup_for_rename(struct vnode *, struct componentname *,
	    struct thread *);
void	unionfs_forward_vop_start_pair(struct vnode *, int *,
	    struct vnode *, int *);
bool	unionfs_forward_vop_finish_pair(struct vnode *, struct vnode *, int,
	    struct vnode *, struct vnode *, int);

static inline void
unionfs_forward_vop_start(struct vnode *basevp, int *lkflags)
{
	unionfs_forward_vop_start_pair(basevp, lkflags, NULL, NULL);
}

static inline bool
unionfs_forward_vop_finish(struct vnode *unionvp, struct vnode *basevp,
    int lkflags)
{
	return (unionfs_forward_vop_finish_pair(unionvp, basevp, lkflags,
	    NULL, NULL, 0));
}

#define	UNIONFSVPTOLOWERVP(vp) (VTOUNIONFS(vp)->un_lowervp)
#define	UNIONFSVPTOUPPERVP(vp) (VTOUNIONFS(vp)->un_uppervp)

#ifdef MALLOC_DECLARE
MALLOC_DECLARE(M_UNIONFSNODE);
MALLOC_DECLARE(M_UNIONFSPATH);
#endif

#ifdef UNIONFS_DEBUG
#define UNIONFSDEBUG(format, args...) printf(format ,## args)
#else
#define UNIONFSDEBUG(format, args...)
#endif				/* UNIONFS_DEBUG */

#endif				/* _KERNEL */