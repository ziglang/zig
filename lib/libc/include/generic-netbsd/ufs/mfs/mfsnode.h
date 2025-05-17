/*	$NetBSD: mfsnode.h,v 1.22 2021/07/18 23:57:15 dholland Exp $	*/

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
 *	@(#)mfsnode.h	8.3 (Berkeley) 5/19/95
 */

#ifndef _UFS_MFS_MFSNODE_H_
#define _UFS_MFS_MFSNODE_H_

/*
 * This structure defines the control data for the memory based file system.
 */

struct mfsnode {
	struct vnode *mfs_vnode;	/* vnode associated with this mfsnode */
	void 	*mfs_baseoff;		/* base of file system in memory */
	long	mfs_size;		/* size of memory file system */
	struct proc *mfs_proc;		/* supporting process */
	int	mfs_shutdown;		/* shutdown this mfsnode */
#if defined(_KERNEL)
	kcondvar_t mfs_cv;		/* notifier */
	int	mfs_refcnt;		/* number of references */
	struct	bufq_state *mfs_buflist;/* list of I/O requests */
#endif /* defined(_KERNEL) */
};

#if defined(_KERNEL)
/*
 * Convert between mfsnode pointers and vnode pointers
 */
#define VTOMFS(vp)	((struct mfsnode *)(vp)->v_data)
#define MFSTOV(mfsp)	((mfsp)->mfs_vnode)

#endif /* defined(_KERNEL) */

#endif /* !_UFS_MFS_MFSNODE_H_ */