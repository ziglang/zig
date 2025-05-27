/*	$NetBSD: specdev.h,v 1.53 2022/10/26 23:40:08 riastradh Exp $	*/

/*-
 * Copyright (c) 2008 The NetBSD Foundation, Inc.
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright (c) 1990, 1993
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
 *	@(#)specdev.h	8.6 (Berkeley) 5/21/95
 */

#ifndef _MISCFS_SPECFS_SPECDEV_H_
#define _MISCFS_SPECFS_SPECDEV_H_

#include <sys/mutex.h>
#include <sys/vnode.h>

typedef struct specnode {
	vnode_t		*sn_next;
	struct specdev	*sn_dev;
	dev_t		sn_rdev;
	u_int		sn_opencnt;	/* # of opens, share of sd_opencnt */
	bool		sn_gone;
} specnode_t;

typedef struct specdev {
	struct mount	*sd_mountpoint;
	struct lockf	*sd_lockf;
	vnode_t		*sd_bdevvp;
	u_int		sd_opencnt;	/* # of opens; close when ->0 */
	u_int		sd_refcnt;	/* # of specnodes referencing this */
	dev_t		sd_rdev;
	volatile u_int	sd_iocnt;	/* # bdev/cdev_* operations active */
	bool		sd_opened;	/* true if successfully opened */
	bool		sd_closing;	/* true when bdev/cdev_close ongoing */
} specdev_t;

/*
 * Exported shorthand
 */
#define v_specnext	v_specnode->sn_next
#define v_rdev		v_specnode->sn_rdev
#define v_speclockf	v_specnode->sn_dev->sd_lockf

/*
 * Special device management
 */
void	spec_node_init(vnode_t *, dev_t);
void	spec_node_destroy(vnode_t *);
int	spec_node_lookup_by_dev(enum vtype, dev_t, int, vnode_t **);
int	spec_node_lookup_by_mount(struct mount *, vnode_t **);
struct mount *spec_node_getmountedfs(vnode_t *);
void	spec_node_setmountedfs(vnode_t *, struct mount *);
void	spec_node_revoke(vnode_t *);

/*
 * Prototypes for special file operations on vnodes.
 */
extern const struct vnodeopv_desc spec_vnodeop_opv_desc;
extern	int (**spec_vnodeop_p)(void *);
struct	nameidata;
struct	componentname;
struct	flock;
struct	buf;
struct	uio;

int	spec_lookup(void *);
int	spec_open(void *);
int	spec_close(void *);
int	spec_read(void *);
int	spec_write(void *);
int	spec_fdiscard(void *);
int	spec_ioctl(void *);
int	spec_poll(void *);
int	spec_kqfilter(void *);
int	spec_mmap(void *);
int	spec_fsync(void *);
#define	spec_seek	genfs_nullop		/* XXX should query device */
int	spec_inactive(void *);
int	spec_reclaim(void *);
int	spec_bmap(void *);
int	spec_strategy(void *);
int	spec_print(void *);
int	spec_pathconf(void *);
int	spec_advlock(void *);

/*
 * This macro provides an initializer list for the fs-independent part
 * of a filesystem's special file vnode ops descriptor table. We still
 * need such a table in every filesystem, but we can at least avoid
 * the cutpaste.
 *
 * This contains these ops:
 *    parsepath lookup
 *    create whiteout mknod open fallocate fdiscard ioctl poll kqfilter
 *    revoke mmap seek remove link rename mkdir rmdir symlink readdir
 *    readlink abortop bmap strategy pathconf advlock getpages putpages
 *
 * The filesystem should provide these ops that need to be its own:
 *    access and accessx
 *    getattr
 *    setattr
 *    fcntl
 *    inactive
 *    reclaim
 *    lock
 *    unlock
 *    print (should probably also call spec_print)
 *    islocked
 *    bwrite (normally vn_bwrite)
 *    openextattr
 *    closeextattr
 *    getextattr
 *    setextattr
 *    listextattr
 *    deleteextattr
 *    getacl
 *    setacl
 *    aclcheck
 *
 * The filesystem should also provide these ops that some filesystems
 * do their own things with:
 *    close
 *    read
 *    write
 *    fsync
 * In most cases "their own things" means adjust timestamps and call
 * spec_foo. For fsync it varies, but should always also call spec_fsync.
 *
 * Note that because the op descriptor tables are unordered it does not
 * matter where in the table this macro goes (except I think default
 * still needs to be first...)
 */
#define GENFS_SPECOP_ENTRIES \
	{ &vop_parsepath_desc, genfs_badop },		/* parsepath */	\
	{ &vop_lookup_desc, spec_lookup },		/* lookup */	\
	{ &vop_create_desc, genfs_badop },		/* create */	\
	{ &vop_whiteout_desc, genfs_badop },		/* whiteout */	\
	{ &vop_mknod_desc, genfs_badop },		/* mknod */	\
	{ &vop_open_desc, spec_open },			/* open */	\
	{ &vop_fallocate_desc, genfs_eopnotsupp },	/* fallocate */	\
	{ &vop_fdiscard_desc, spec_fdiscard },		/* fdiscard */	\
	{ &vop_ioctl_desc, spec_ioctl },		/* ioctl */	\
	{ &vop_poll_desc, spec_poll },			/* poll */	\
	{ &vop_kqfilter_desc, spec_kqfilter },		/* kqfilter */	\
	{ &vop_revoke_desc, genfs_revoke },		/* revoke */	\
	{ &vop_mmap_desc, spec_mmap },			/* mmap */	\
	{ &vop_seek_desc, spec_seek },			/* seek */	\
	{ &vop_remove_desc, genfs_badop },		/* remove */	\
	{ &vop_link_desc, genfs_badop },		/* link */	\
	{ &vop_rename_desc, genfs_badop },		/* rename */	\
	{ &vop_mkdir_desc, genfs_badop },		/* mkdir */	\
	{ &vop_rmdir_desc, genfs_badop },		/* rmdir */	\
	{ &vop_symlink_desc, genfs_badop },		/* symlink */	\
	{ &vop_readdir_desc, genfs_badop },		/* readdir */	\
	{ &vop_readlink_desc, genfs_badop },		/* readlink */	\
	{ &vop_abortop_desc, genfs_badop },		/* abortop */	\
	{ &vop_bmap_desc, spec_bmap },			/* bmap */	\
	{ &vop_strategy_desc, spec_strategy },		/* strategy */	\
	{ &vop_pathconf_desc, spec_pathconf },		/* pathconf */	\
	{ &vop_advlock_desc, spec_advlock },		/* advlock */	\
	{ &vop_getpages_desc, genfs_getpages },		/* getpages */	\
	{ &vop_putpages_desc, genfs_putpages }		/* putpages */


bool	iskmemvp(struct vnode *);
void	spec_init(void);

#endif /* _MISCFS_SPECFS_SPECDEV_H_ */