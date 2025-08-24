/* $NetBSD: genfs_node.h,v 1.24 2020/03/14 21:47:41 ad Exp $ */

/*
 * Copyright (c) 2001 Chuck Silvers.
 * All rights reserved.
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
 *      This product includes software developed by Chuck Silvers.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_MISCFS_GENFS_GENFS_NODE_H_
#define	_MISCFS_GENFS_GENFS_NODE_H_

#include <sys/rwlock.h>

struct vm_page;
struct kauth_cred;
struct uio;
struct vnode;

struct genfs_ops {
	void	(*gop_size)(struct vnode *, off_t, off_t *, int);
	int	(*gop_alloc)(struct vnode *, off_t, off_t, int,
	    struct kauth_cred *);
	int	(*gop_write)(struct vnode *, struct vm_page **, int, int);
	void	(*gop_markupdate)(struct vnode *, int);
	void	(*gop_putrange)(struct vnode *, off_t, off_t *, off_t *);
};

#define GOP_SIZE(vp, size, eobp, flags) \
	(*VTOG(vp)->g_op->gop_size)((vp), (size), (eobp), (flags))
#define GOP_ALLOC(vp, off, len, flags, cred) \
	(*VTOG(vp)->g_op->gop_alloc)((vp), (off), (len), (flags), (cred))
#define GOP_WRITE(vp, pgs, npages, flags) \
	(*VTOG(vp)->g_op->gop_write)((vp), (pgs), (npages), (flags))
#define GOP_PUTRANGE(vp, off, lop, hip) \
	(*VTOG(vp)->g_op->gop_putrange)((vp), (off), (lop), (hip))

/*
 * GOP_MARKUPDATE: mark vnode's timestamps for update.
 *
 * => called with vmobjlock (and possibly other locks) held.
 * => used for accesses via mmap.
 */

#define GOP_MARKUPDATE(vp, flags) \
	(VTOG(vp)->g_op->gop_markupdate) ? \
	(*VTOG(vp)->g_op->gop_markupdate)((vp), (flags)) : \
	(void)0;

/* Flags to GOP_SIZE */
#define	GOP_SIZE_MEM	0x4	/* in-memory size */

/* Flags to GOP_MARKUPDATE */
#define	GOP_UPDATE_ACCESSED	1
#define	GOP_UPDATE_MODIFIED	2

struct genfs_node {
	const struct genfs_ops	*g_op;		/* ops vector */
	krwlock_t		g_glock;	/* getpages lock */
};

#define VTOG(vp) ((struct genfs_node *)(vp)->v_data)

void	genfs_size(struct vnode *, off_t, off_t *, int);
void	genfs_node_init(struct vnode *, const struct genfs_ops *);
void	genfs_node_destroy(struct vnode *);
void	genfs_gop_putrange(struct vnode *, off_t, off_t *, off_t *);
int	genfs_gop_write(struct vnode *, struct vm_page **, int, int);
int	genfs_gop_write_rwmap(struct vnode *, struct vm_page **, int, int);
int	genfs_compat_gop_write(struct vnode *, struct vm_page **, int, int);
void	genfs_directio(struct vnode *, struct uio *, int);

void	genfs_node_wrlock(struct vnode *);
void	genfs_node_rdlock(struct vnode *);
int	genfs_node_rdtrylock(struct vnode *);
void	genfs_node_unlock(struct vnode *);
int	genfs_node_wrlocked(struct vnode *);

#endif	/* _MISCFS_GENFS_GENFS_NODE_H_ */