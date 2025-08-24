/*	$NetBSD: umap.h,v 1.19 2019/08/20 21:18:10 perseant Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software donated to Berkeley by
 * the UCLA Ficus project.
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
 *	from: @(#)null_vnops.c       1.5 (Berkeley) 7/10/92
 *	@(#)umap.h	8.4 (Berkeley) 8/20/94
 */

#include <miscfs/genfs/layer.h>

#define MAPFILEENTRIES 64
#define GMAPFILEENTRIES 16
#define NOBODY 32767
#define NULLGROUP 65534

struct umap_args {
	struct layer_args la;		/* generic layerfs args. Includes
					 * target and export info */
#define	umap_target	la.target
#define	umap_export	la.export
	int 		nentries;       /* # of entries in user map array */
	int 		gnentries;	/* # of entries in group map array */
	u_long 		(*mapdata)[2];	/* pointer to array of user mappings */
	u_long 		(*gmapdata)[2];	/* pointer to array of group mappings */
	u_long		fsid;		/* user-supplied per-fs ident */
};

#ifdef _KERNEL

struct umap_mount {
	struct layer_mount lm;
	int             info_nentries;  /* number of uid mappings */
	int		info_gnentries;	/* number of gid mappings */
	u_long		info_mapdata[MAPFILEENTRIES][2]; /* mapping data for
	    user mapping in ficus */
	u_long		info_gmapdata[GMAPFILEENTRIES][2]; /*mapping data for
	    group mapping in ficus */
};
#define	umapm_rootvp		lm.layerm_rootvp
#define	umapm_export		lm.layerm_export
#define	umapm_flags		lm.layerm_flags
#define	umapm_size		lm.layerm_size
#define	umapm_tag		lm.layerm_tag
#define	umapm_bypass		lm.layerm_bypass
#define	umapm_alloc		lm.layerm_alloc
#define	umapm_vnodeop_p		lm.layerm_vnodeop_p
#define	umapm_node_hashtbl	lm.layerm_node_hashtbl
#define	umapm_node_hash		lm.layerm_node_hash
#define	umapm_hashlock		lm.layerm_hashlock

/*
 * A cache of vnode references
 */
struct umap_node {
	struct	layer_node	ln;
};

u_long umap_reverse_findid(u_long id, u_long map[][2], int nentries);
void umap_mapids(struct mount *v_mount, kauth_cred_t credp);

#define	umap_hash	ln.layer_hash
#define	umap_lowervp	ln.layer_lowervp
#define	umap_vnode	ln.layer_vnode
#define	umap_flags	ln.layer_flags

#define	MOUNTTOUMAPMOUNT(mp) ((struct umap_mount *)((mp)->mnt_data))
#define	VTOUMAP(vp) ((struct umap_node *)(vp)->v_data)
#define UMAPTOV(xp) ((xp)->umap_vnode)
#ifdef UMAPFS_DIAGNOSTIC
#define	UMAPVPTOLOWERVP(vp) layer_checkvp((vp), __FILE__, __LINE__)
#else
#define	UMAPVPTOLOWERVP(vp) (VTOUMAP(vp)->umap_lowervp)
#endif

extern int (**umap_vnodeop_p)(void *);
extern struct vfsops umapfs_vfsops;

int     umap_bypass(void *);

#define NUMAPNODECACHE	16

#endif /* _KERNEL */