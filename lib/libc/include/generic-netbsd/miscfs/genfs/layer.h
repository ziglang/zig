/*	$NetBSD: layer.h,v 1.17 2017/04/11 07:51:37 hannken Exp $	*/

/*
 * Copyright (c) 1999 National Aeronautics & Space Administration
 * All rights reserved.
 *
 * This software was written by William Studenmund of the
 * Numerical Aerospace Simulation Facility, NASA Ames Research Center.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the National Aeronautics & Space Administration
 *    nor the names of its contributors may be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NATIONAL AERONAUTICS & SPACE ADMINISTRATION
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE ADMINISTRATION OR CONTRIB-
 * UTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	from: Id: lofs.h,v 1.8 1992/05/30 10:05:43 jsp Exp
 *	@(#)null.h	8.2 (Berkeley) 1/21/94
 */

#ifndef _MISCFS_GENFS_LAYER_H_
#define _MISCFS_GENFS_LAYER_H_

struct layer_args {
	char	*target;		/* Target of loopback  */
	struct export_args30 _pad1; /* compat with old userland tools */
};

#ifdef _KERNEL

struct layer_mount {
	struct vnode		*layerm_rootvp;	/* Ref to root layer_node */
	u_int			layerm_flags;	/* mount point layer flags */
	u_int			layerm_size;	/* size of fs's struct node */
	enum vtagtype		layerm_tag;	/* vtag of our vnodes */
	int				/* bypass routine for this mount */
				(*layerm_bypass)(void *);
	int			(**layerm_vnodeop_p)	/* ops for our nodes */
				(void *);
};

#define	LAYERFS_MFLAGS		0x00000fff	/* reserved layer mount flags */
#define	LAYERFS_MBYPASSDEBUG	0x00000001

/*
 * A cache of vnode references
 */
struct layer_node {
	struct vnode	        *layer_lowervp;	/* VREFed once */
	struct vnode		*layer_vnode;	/* Back pointer */
	unsigned int		layer_flags;	/* locking, etc. */
};

#define	LAYERFS_RESFLAGS	0x00000fff	/* flags reserved for layerfs */
#define	LAYERFS_REMOVED 	0x00000001	/* Did a remove on this node */

#define	LAYERFS_DO_BYPASS(vp, ap)	\
	(*MOUNTTOLAYERMOUNT((vp)->v_mount)->layerm_bypass)((ap))

struct vnode *layer_checkvp(struct vnode *vp, const char *fil, int lno);

#define	MOUNTTOLAYERMOUNT(mp) ((struct layer_mount *)((mp)->mnt_data))
#define	VTOLAYER(vp) ((struct layer_node *)(vp)->v_data)
#define	LAYERTOV(xp) ((xp)->layer_vnode)
#ifdef LAYERFS_DIAGNOSTIC
#define	LAYERVPTOLOWERVP(vp) layer_checkvp((vp), __FILE__, __LINE__)
extern int layerfs_debug;
#else
#define	LAYERVPTOLOWERVP(vp) (VTOLAYER(vp)->layer_lowervp)
#endif

#endif /* _KERNEL */
#endif /* _MISCFS_GENFS_LAYER_H_ */