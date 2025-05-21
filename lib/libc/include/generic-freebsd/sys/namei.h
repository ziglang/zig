/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1985, 1989, 1991, 1993
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
 *	@(#)namei.h	8.5 (Berkeley) 1/9/95
 */

#ifndef _SYS_NAMEI_H_
#define	_SYS_NAMEI_H_

#include <sys/caprights.h>
#include <sys/filedesc.h>
#include <sys/queue.h>
#include <sys/_seqc.h>
#include <sys/_uio.h>

enum nameiop { LOOKUP, CREATE, DELETE, RENAME };

struct componentname {
	/*
	 * Arguments to lookup.
	 */
	u_int64_t cn_flags;	/* flags to namei */
	struct	ucred *cn_cred;	/* credentials */
	enum nameiop cn_nameiop;	/* namei operation */
	int	cn_lkflags;	/* Lock flags LK_EXCLUSIVE or LK_SHARED */
	/*
	 * Shared between lookup and commit routines.
	 */
	char	*cn_pnbuf;	/* pathname buffer */
	char	*cn_nameptr;	/* pointer to looked up name */
	long	cn_namelen;	/* length of looked up component */
};

struct nameicap_tracker;
TAILQ_HEAD(nameicap_tracker_head, nameicap_tracker);

/*
 * Encapsulation of namei parameters.
 */
struct nameidata {
	/*
	 * Arguments to namei/lookup.
	 */
	const	char *ni_dirp;		/* pathname pointer */
	enum	uio_seg ni_segflg;	/* location of pathname */
	cap_rights_t *ni_rightsneeded;	/* rights required to look up vnode */
	/*
	 * Arguments to lookup.
	 */
	struct  vnode *ni_startdir;	/* starting directory */
	struct	vnode *ni_rootdir;	/* logical root directory */
	struct	vnode *ni_topdir;	/* logical top directory */
	int	ni_dirfd;		/* starting directory for *at functions */
	int	ni_lcf;			/* local call flags */
	/*
	 * Results: returned from namei
	 */
	struct filecaps ni_filecaps;	/* rights the *at base has */
	/*
	 * Results: returned from/manipulated by lookup
	 */
	struct	vnode *ni_vp;		/* vnode of result */
	struct	vnode *ni_dvp;		/* vnode of intermediate directory */
	/*
	 * Results: flags returned from namei
	 */
	u_int	ni_resflags;
	/*
	 * Debug for validating API use by the callers.
	 */
	u_short	ni_debugflags;
	/*
	 * Shared between namei and lookup/commit routines.
	 */
	u_short	ni_loopcnt;		/* count of symlinks encountered */
	size_t	ni_pathlen;		/* remaining chars in path */
	char	*ni_next;		/* next location in pathname */
	/*
	 * Lookup parameters: this structure describes the subset of
	 * information from the nameidata structure that is passed
	 * through the VOP interface.
	 */
	struct componentname ni_cnd;
	struct nameicap_tracker_head ni_cap_tracker;
	/*
	 * Private helper data for UFS, must be at the end.  See
	 * NDINIT_PREFILL().
	 */
	seqc_t	ni_dvp_seqc;
	seqc_t	ni_vp_seqc;
};

#ifdef _KERNEL

enum cache_fpl_status { CACHE_FPL_STATUS_DESTROYED, CACHE_FPL_STATUS_ABORTED,
    CACHE_FPL_STATUS_PARTIAL, CACHE_FPL_STATUS_HANDLED, CACHE_FPL_STATUS_UNSET };
int	cache_fplookup(struct nameidata *ndp, enum cache_fpl_status *status,
    struct pwd **pwdp);

/*
 * Flags for namei.
 *
 * If modifying the list make sure to check whether NDVALIDATE needs updating.
 */

/*
 * Debug.
 */
#define	NAMEI_DBG_INITED	0x0001
#define	NAMEI_DBG_CALLED	0x0002
#define	NAMEI_DBG_HADSTARTDIR	0x0004

/*
 * namei operational modifier flags, stored in ni_cnd.flags
 */
#define	NC_NOMAKEENTRY	0x0001	/* name must not be added to cache */
#define	NC_KEEPPOSENTRY	0x0002	/* don't evict a positive entry */
#define	NOCACHE		NC_NOMAKEENTRY	/* for compatibility with older code */
#define	LOCKLEAF	0x0004	/* lock vnode on return */
#define	LOCKPARENT	0x0008	/* want parent vnode returned locked */
#define	WANTPARENT	0x0010	/* want parent vnode returned unlocked */
#define	FAILIFEXISTS	0x0020	/* return EEXIST if found */
#define	FOLLOW		0x0040	/* follow symbolic links */
#define	EMPTYPATH	0x0080	/* Allow empty path for *at */
#define	LOCKSHARED	0x0100	/* Shared lock leaf */
#define	NOFOLLOW	0x0000	/* do not follow symbolic links (pseudo) */
#define	RBENEATH	0x100000000ULL /* No escape, even tmp, from start dir */
#define	MODMASK		0xf000001ffULL	/* mask of operational modifiers */

/*
 * Namei parameter descriptors.
 */
#define	RDONLY		0x00000200 /* lookup with read-only semantics */
#define	ISRESTARTED	0x00000400 /* restarted namei */
/* UNUSED		0x00000800 */
#define	ISWHITEOUT	0x00001000 /* found whiteout */
#define	DOWHITEOUT	0x00002000 /* do whiteouts */
#define	WILLBEDIR	0x00004000 /* new files will be dirs; allow trailing / */
#define	ISOPEN		0x00008000 /* caller is opening; return a real vnode. */
#define	NOCROSSMOUNT	0x00010000 /* do not cross mount points */
#define	NOMACCHECK	0x00020000 /* do not perform MAC checks */
#define	AUDITVNODE1	0x00040000 /* audit the looked up vnode information */
#define	AUDITVNODE2	0x00080000 /* audit the looked up vnode information */
#define	NOCAPCHECK	0x00100000 /* do not perform capability checks */
#define	OPENREAD	0x00200000 /* open for reading */
#define	OPENWRITE	0x00400000 /* open for writing */
#define	WANTIOCTLCAPS	0x00800000 /* leave ioctl caps for the caller */
/* UNUSED		0x01000000 */
#define	NOEXECCHECK	0x02000000 /* do not perform exec check on dir */
#define	MAKEENTRY	0x04000000 /* entry is to be added to name cache */
#define	ISSYMLINK	0x08000000 /* symlink needs interpretation */
#define	ISLASTCN	0x10000000 /* this is last component of pathname */
#define	ISDOTDOT	0x20000000 /* current component name is .. */
#define	TRAILINGSLASH	0x40000000 /* path ended in a slash */
#define	PARAMASK	0x7ffffe00 /* mask of parameter descriptors */

/*
 * Flags which must not be passed in by callers.
 */
#define NAMEI_INTERNAL_FLAGS	\
	(NOEXECCHECK | MAKEENTRY | ISSYMLINK | ISLASTCN | ISDOTDOT | \
	 TRAILINGSLASH | ISRESTARTED)

/*
 * Namei results flags
 */
#define	NIRES_ABS	0x00000001 /* Path was absolute */
#define	NIRES_STRICTREL	0x00000002 /* Restricted lookup result */
#define	NIRES_EMPTYPATH	0x00000004 /* EMPTYPATH used */

/*
 * Flags in ni_lcf, valid for the duration of the namei call.
 */
#define	NI_LCF_STRICTREL	0x0001	/* relative lookup only */
#define	NI_LCF_CAP_DOTDOT	0x0002	/* ".." in strictrelative case */
/* Track capability restrictions seperately for violation ktracing. */
#define	NI_LCF_STRICTREL_KTR	0x0004	/* trace relative lookups */
#define	NI_LCF_CAP_DOTDOT_KTR	0x0008	/* ".." in strictrelative case */
#define	NI_LCF_KTR_FLAGS	(NI_LCF_STRICTREL_KTR | NI_LCF_CAP_DOTDOT_KTR)

/*
 * Initialization of a nameidata structure.
 */
#define	NDINIT(ndp, op, flags, segflg, namep)				\
	NDINIT_ALL(ndp, op, flags, segflg, namep, AT_FDCWD, NULL, &cap_no_rights)
#define	NDINIT_AT(ndp, op, flags, segflg, namep, dirfd)			\
	NDINIT_ALL(ndp, op, flags, segflg, namep, dirfd, NULL, &cap_no_rights)
#define	NDINIT_ATRIGHTS(ndp, op, flags, segflg, namep, dirfd, rightsp) 	\
	NDINIT_ALL(ndp, op, flags, segflg, namep, dirfd, NULL, rightsp)
#define	NDINIT_ATVP(ndp, op, flags, segflg, namep, vp)			\
	NDINIT_ALL(ndp, op, flags, segflg, namep, AT_FDCWD, vp, &cap_no_rights)

/*
 * Note the constant pattern may *hide* bugs.
 * Note also that we enable debug checks for non-TIED KLDs
 * so that they can run on an INVARIANTS kernel without tripping over
 * assertions on ni_debugflags state.
 */
#if defined(INVARIANTS) || (defined(KLD_MODULE) && !defined(KLD_TIED))
#define NDINIT_PREFILL(arg)	memset(arg, 0xff, offsetof(struct nameidata,	\
    ni_dvp_seqc))
#define NDINIT_DBG(arg)		{ (arg)->ni_debugflags = NAMEI_DBG_INITED; }
#define NDREINIT_DBG(arg)	{						\
	if (((arg)->ni_debugflags & NAMEI_DBG_INITED) == 0)			\
		panic("namei data not inited");					\
	if (((arg)->ni_debugflags & NAMEI_DBG_HADSTARTDIR) != 0)		\
		panic("NDREINIT on namei data with NAMEI_DBG_HADSTARTDIR");	\
	(arg)->ni_debugflags = NAMEI_DBG_INITED;				\
}
#else
#define NDINIT_PREFILL(arg)	do { } while (0)
#define NDINIT_DBG(arg)		do { } while (0)
#define NDREINIT_DBG(arg)	do { } while (0)
#endif

#define NDINIT_ALL(ndp, op, flags, segflg, namep, dirfd, startdir, rightsp)	\
do {										\
	struct nameidata *_ndp = (ndp);						\
	cap_rights_t *_rightsp = (rightsp);					\
	MPASS(_rightsp != NULL);						\
	NDINIT_PREFILL(_ndp);							\
	NDINIT_DBG(_ndp);							\
	_ndp->ni_cnd.cn_nameiop = op;						\
	_ndp->ni_cnd.cn_flags = flags;						\
	_ndp->ni_segflg = segflg;						\
	_ndp->ni_dirp = namep;							\
	_ndp->ni_dirfd = dirfd;							\
	_ndp->ni_startdir = startdir;						\
	_ndp->ni_resflags = 0;							\
	filecaps_init(&_ndp->ni_filecaps);					\
	_ndp->ni_rightsneeded = _rightsp;					\
} while (0)

#define NDREINIT(ndp)	do {							\
	struct nameidata *_ndp = (ndp);						\
	NDREINIT_DBG(_ndp);							\
	filecaps_free(&_ndp->ni_filecaps);					\
	_ndp->ni_resflags = 0;							\
	_ndp->ni_startdir = NULL;						\
} while (0)

#define	NDPREINIT(ndp) do {							\
	(ndp)->ni_dvp_seqc = SEQC_MOD;						\
	(ndp)->ni_vp_seqc = SEQC_MOD;						\
} while (0)

#define NDFREE_IOCTLCAPS(ndp) do {						\
	struct nameidata *_ndp = (ndp);						\
	filecaps_free(&_ndp->ni_filecaps);					\
} while (0)

#define	NDFREE_PNBUF(ndp) do {							\
	struct nameidata *_ndp = (ndp);						\
	MPASS(_ndp->ni_cnd.cn_pnbuf != NULL);					\
	uma_zfree(namei_zone, _ndp->ni_cnd.cn_pnbuf);				\
	_ndp->ni_cnd.cn_pnbuf = NULL;						\
} while (0)

int	namei(struct nameidata *ndp);
int	vfs_lookup(struct nameidata *ndp);
int	vfs_relookup(struct vnode *dvp, struct vnode **vpp,
	    struct componentname *cnp, bool refstart);

#define namei_setup_rootdir(ndp, cnp, pwd) do {					\
	if (__predict_true((cnp->cn_flags & ISRESTARTED) == 0))			\
		ndp->ni_rootdir = pwd->pwd_adir;				\
	else									\
		ndp->ni_rootdir = pwd->pwd_rdir;				\
} while (0)
#endif

/*
 * Stats on usefulness of namei caches.
 */
struct nchstats {
	long	ncs_goodhits;		/* hits that we can really use */
	long	ncs_neghits;		/* negative hits that we can use */
	long	ncs_badhits;		/* hits we must drop */
	long	ncs_falsehits;		/* hits with id mismatch */
	long	ncs_miss;		/* misses */
	long	ncs_long;		/* long names that ignore cache */
	long	ncs_pass2;		/* names found with passes == 2 */
	long	ncs_2passes;		/* number of times we attempt it */
};

extern struct nchstats nchstats;

#endif /* !_SYS_NAMEI_H_ */