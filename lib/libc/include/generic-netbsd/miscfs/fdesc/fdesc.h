/*	$NetBSD: fdesc.h,v 1.23 2020/01/17 20:08:09 ad Exp $	*/

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
 *	@(#)fdesc.h	8.8 (Berkeley) 4/3/95
 *
 * #Id: fdesc.h,v 1.8 1993/04/06 15:28:33 jsp Exp #
 */

#ifdef _KERNEL

#define FD_ROOT		2
#define FD_DEVFD	3
#define FD_STDIN	4
#define FD_STDOUT	5
#define FD_STDERR	6
#define FD_CTTY		7
#define FD_DESC		8
#define FD_MAX		12

typedef enum {
	Froot,
	Fdevfd,
	Fdesc,
	Flink,
	Fctty
} fdntype;

struct fdescnode {
	struct vnode	*fd_vnode;	/* Back ptr to vnode */
	fdntype		fd_type;	/* Type of this node */
	unsigned	fd_fd;		/* Fd to be dup'ed */
	const char	*fd_link;	/* Link to fd/n */
	int		fd_ix;		/* filesystem index */
};

#define	VTOFDESC(vp) ((struct fdescnode *)(vp)->v_data)

#define FDESC_MAXNAMLEN	255

extern dev_t devctty;
extern void fdesc_init(void);
extern void fdesc_done(void);
extern int fdesc_root(struct mount *, int, struct vnode **);
extern int fdesc_allocvp(fdntype, int, struct mount *, struct vnode **);
extern int (**fdesc_vnodeop_p)(void *);
extern struct vfsops fdesc_vfsops;

#endif /* _KERNEL */