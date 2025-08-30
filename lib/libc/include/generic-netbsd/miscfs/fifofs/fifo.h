/*	$NetBSD: fifo.h,v 1.28 2022/10/26 23:40:20 riastradh Exp $	*/

/*
 * Copyright (c) 1991, 1993
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
 *	@(#)fifo.h	8.6 (Berkeley) 5/21/95
 */

#ifndef _MISCFS_FIFOFS_FIFO_H_
#define _MISCFS_FIFOFS_FIFO_H_

#include <sys/vnode.h>

#include <miscfs/genfs/genfs.h>

extern const struct vnodeopv_desc fifo_vnodeop_opv_desc;

extern int (**fifo_vnodeop_p)(void *);

/*
 * This macro provides an initializer list for the fs-independent part
 * of a filesystem's fifo vnode ops descriptor table. We still need
 * such a table in every filesystem, but we can at least avoid the
 * cutpaste.
 *
 * This contains these ops:
 *    parsepath lookup
 *    create whiteout mknod open fallocate fdiscard ioctl poll kqfilter
 *    revoke mmap seek remove link rename mkdir rmdir symlink readdir
 *    readlink abortop bmap pathconf advlock getpages putpages
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
 *    strategy
 *    print (should probably also call fifo_print)
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
 * fifo_foo (currently via vn_fifo_bypass). For fsync it varies.
 *
 * Note that because the op descriptor tables are unordered it does not
 * matter where in the table this macro goes (except I think default
 * still needs to be first...)
 *
 * XXX currently all the ops are vn_fifo_bypass, which does an
 * indirect call via the fifofs ops table (externed above), which
 * someone decided was preferable to exposing the function
 * definitions. This includes (for now at least) the ones that are
 * sent to genfs by that table. This should probably be changed, but
 * not just yet.
 */
#define GENFS_FIFOOP_ENTRIES \
	{ &vop_parsepath_desc, genfs_badop },		/* parsepath */	\
	{ &vop_lookup_desc, vn_fifo_bypass },		/* lookup */	\
	{ &vop_create_desc, vn_fifo_bypass },		/* create */	\
	{ &vop_whiteout_desc, vn_fifo_bypass },		/* whiteout */	\
	{ &vop_mknod_desc, vn_fifo_bypass },		/* mknod */	\
	{ &vop_open_desc, vn_fifo_bypass },		/* open */	\
	{ &vop_fallocate_desc, vn_fifo_bypass },	/* fallocate */	\
	{ &vop_fdiscard_desc, vn_fifo_bypass },		/* fdiscard */	\
	{ &vop_ioctl_desc, vn_fifo_bypass },		/* ioctl */	\
	{ &vop_poll_desc, vn_fifo_bypass },		/* poll */	\
	{ &vop_kqfilter_desc, vn_fifo_bypass },		/* kqfilter */	\
	{ &vop_revoke_desc, vn_fifo_bypass },		/* revoke */	\
	{ &vop_mmap_desc, vn_fifo_bypass },		/* mmap */	\
	{ &vop_seek_desc, vn_fifo_bypass },		/* seek */	\
	{ &vop_remove_desc, vn_fifo_bypass },		/* remove */	\
	{ &vop_link_desc, vn_fifo_bypass },		/* link */	\
	{ &vop_rename_desc, vn_fifo_bypass },		/* rename */	\
	{ &vop_mkdir_desc, vn_fifo_bypass },		/* mkdir */	\
	{ &vop_rmdir_desc, vn_fifo_bypass },		/* rmdir */	\
	{ &vop_symlink_desc, vn_fifo_bypass },		/* symlink */	\
	{ &vop_readdir_desc, vn_fifo_bypass },		/* readdir */	\
	{ &vop_readlink_desc, vn_fifo_bypass },		/* readlink */	\
	{ &vop_abortop_desc, vn_fifo_bypass },		/* abortop */	\
	{ &vop_bmap_desc, vn_fifo_bypass },		/* bmap */	\
	{ &vop_pathconf_desc, vn_fifo_bypass },		/* pathconf */	\
	{ &vop_advlock_desc, vn_fifo_bypass },		/* advlock */	\
	{ &vop_getpages_desc, genfs_badop },	 	/* getpages */	\
	{ &vop_putpages_desc, vn_fifo_bypass }	 	/* putpages */

#endif	/* _MISCFS_FIFOFS_FIFO_H_ */