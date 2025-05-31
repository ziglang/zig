/*	$NetBSD: ntfs_inode.h,v 1.9 2014/11/13 16:51:53 hannken Exp $	*/

/*-
 * Copyright (c) 1998, 1999 Semen Ustimenko
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	Id: ntfs_inode.h,v 1.4 1999/05/12 09:43:00 semenu Exp
 */

#ifndef _NTFS_NTFS_INODE_H_
#define _NTFS_NTFS_INODE_H_
#include <miscfs/genfs/genfs_node.h>

/* These flags are kept in i_flag. */
#define	IN_ACCESS	0x0001	/* Access time update request. */
#define	IN_CHANGE	0x0002	/* Inode change time update request. */
#define	IN_EXLOCK	0x0004	/* File has exclusive lock. */
#define	IN_LOCKED	0x0008	/* Inode lock. */
#define	IN_LWAIT	0x0010	/* Process waiting on file lock. */
#define	IN_MODIFIED	0x0020	/* Inode has been modified. */
#define	IN_RENAME	0x0040	/* Inode is being renamed. */
#define	IN_SHLOCK	0x0080	/* File has shared lock. */
#define	IN_UPDATE	0x0100	/* Modification time update request. */
#define	IN_WANTED	0x0200	/* Inode is wanted by a process. */
#define	IN_RECURSE	0x0400	/* Recursion expected */

#define	IN_HASHED	0x0800	/* Inode is on hash list */
#define	IN_LOADED	0x8000	/* ntvattrs loaded */
#define	IN_PRELOADED	0x4000	/* loaded from directory entry */

struct ntnode {
	struct vnode   *i_devvp;	/* vnode of blk dev we live on */
	dev_t           i_dev;		/* Device associated with the inode. */

	LIST_ENTRY(ntnode)	i_hash;
	struct ntfsmount       *i_mp;
	ino_t           i_number;
	u_int32_t       i_flag;

	/* locking */
	kcondvar_t	i_lock;
	kmutex_t	i_interlock;
	int		i_usecount;
	int		i_busy;

	LIST_HEAD(,ntvattr)	i_valist;

	long		i_nlink;	/* MFR */
	ino_t		i_mainrec;	/* MFR */
	u_int32_t	i_frflag;	/* MFR */
};

#define NTKEY_SIZE(attrlen) (sizeof(struct ntkey) + (attrlen))
struct ntkey {
	ino_t		k_ino;		/* Inode number of ntnode. */
	u_int32_t	k_attrtype;	/* Attribute type. */
	char		k_attrname[1];	/* Attribute name (variable length). */
} __packed;

struct fnode {
	struct genfs_node f_gnode;

	LIST_ENTRY(fnode) f_fnlist;
	struct vnode   *f_vp;		/* Associatied vnode */
	struct ntnode  *f_ip;		/* Associated ntnode */

	ntfs_times_t	f_times;	/* $NAME/dirinfo */
	ino_t		f_pnumber;	/* $NAME/dirinfo */
	u_int32_t       f_fflag;	/* $NAME/dirinfo */
	u_int64_t	f_size;		/* defattr/dirinfo: */
	u_int64_t	f_allocated;	/* defattr/dirinfo */

	struct ntkey   *f_key;
	struct ntkey	f_smallkey;
#define f_ino f_key->k_ino
#define f_attrtype f_key->k_attrtype
#define f_attrname f_key->k_attrname

	/* for ntreaddir */
	u_int32_t       f_lastdattr;
	u_int32_t       f_lastdblnum;
	u_int32_t       f_lastdoff;
	u_int32_t       f_lastdnum;
	void *        f_dirblbuf;
	u_int32_t       f_dirblsz;
};

/* This overlays the fid structure (see <sys/mount.h>) */
struct ntfid {
	u_int16_t ntfid_len;	/* Length of structure. */
	u_int16_t ntfid_pad;	/* Force 32-bit alignment. */
	ino_t     ntfid_ino;	/* File number (ino). */
	u_int8_t  ntfid_attr;	/* Attribute identifier */
#ifdef notyet
	int32_t   ntfid_gen;	/* Generation number. */
#endif
};
#endif /* _NTFS_NTFS_INODE_H_ */