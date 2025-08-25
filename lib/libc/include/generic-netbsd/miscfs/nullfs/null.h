/*	$NetBSD: null.h,v 1.20 2017/04/11 07:51:37 hannken Exp $	*/

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

#ifndef _MISCFS_NULLFS_H_
#define _MISCFS_NULLFS_H_

#include <miscfs/genfs/layer.h>

struct null_args {
	struct	layer_args	la;	/* generic layerfs args */
};
#define	nulla_target	la.target
#define	nulla_export	la.export

#ifdef _KERNEL
struct null_mount {
	struct	layer_mount	lm;	/* generic layerfs mount stuff */
};
#define	nullm_rootvp		lm.layerm_rootvp
#define	nullm_export		lm.layerm_export
#define	nullm_flags		lm.layerm_flags
#define	nullm_size		lm.layerm_size
#define	nullm_tag		lm.layerm_tag
#define	nullm_bypass		lm.layerm_bypass
#define	nullm_alloc		lm.layerm_alloc
#define	nullm_vnodeop_p		lm.layerm_vnodeop_p
#define	nullm_node_hashtbl	lm.layerm_node_hashtbl
#define	nullm_node_hash		lm.layerm_node_hash
#define	nullm_hashlock		lm.layerm_hashlock

/*
 * A cache of vnode references
 */
struct null_node {
	struct	layer_node	ln;
};
#define	null_hash	ln.layer_hash
#define	null_lowervp	ln.layer_lowervp
#define	null_vnode	ln.layer_vnode
#define	null_flags	ln.layer_flags

#define	MOUNTTONULLMOUNT(mp) ((struct null_mount *)((mp)->mnt_data))

extern int (**null_vnodeop_p)(void *);
extern struct vfsops nullfs_vfsops;

void nullfs_init(void);

#endif /* _KERNEL */
#endif /* _MISCFS_NULLFS_H_ */