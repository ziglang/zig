/*	$NetBSD: extattr.h,v 1.12 2020/04/18 19:18:34 christos Exp $	*/

/*-
 * Copyright (c) 1999-2001 Robert N. M. Watson
 * All rights reserved.
 *
 * This software was developed by Robert Watson for the TrustedBSD Project.
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
 * $FreeBSD: src/sys/ufs/ufs/extattr.h,v 1.20 2005/01/31 08:16:45 imp Exp $
 */

/*
 * Support for file system extended attributes on the UFS1 file system.
 * Developed by the TrustedBSD Project.
 */

#ifndef _UFS_UFS_EXTATTR_H_
#define	_UFS_UFS_EXTATTR_H_

#define	UFS_EXTATTR_MAGIC		0x00b5d5ec
#define	UFS_EXTATTR_VERSION		0x00000003
#define	UFS_EXTATTR_FSROOTSUBDIR	".attribute"
#define	UFS_EXTATTR_SUBDIR_SYSTEM	"system"
#define	UFS_EXTATTR_SUBDIR_USER		"user"
#define	UFS_EXTATTR_MAXEXTATTRNAME	256	/* including null */

#define	UFS_EXTATTR_ATTR_FLAG_INUSE	0x00000001	/* attr has been set */
#define	UFS_EXTATTR_PERM_KERNEL		0x00000000
#define	UFS_EXTATTR_PERM_ROOT		0x00000001
#define	UFS_EXTATTR_PERM_OWNER		0x00000002
#define	UFS_EXTATTR_PERM_ANYONE		0x00000003

#define	UFS_EXTATTR_UEPM_INITIALIZED	0x00000001
#define	UFS_EXTATTR_UEPM_STARTED	0x00000002

#define	UFS_EXTATTR_CMD_START		EXTATTR_CMD_START
#define	UFS_EXTATTR_CMD_STOP		EXTATTR_CMD_STOP
#define	UFS_EXTATTR_CMD_ENABLE		0x00000003
#define	UFS_EXTATTR_CMD_DISABLE		0x00000004

struct ufs_extattr_fileheader {
	uint32_t	uef_magic;	/* magic number for sanity checking */
	uint32_t	uef_version;	/* version of attribute file */
	uint32_t	uef_size;	/* size of attributes, w/o header */
};

struct ufs_extattr_header {
	uint32_t	ueh_flags;	/* flags for attribute */
	uint32_t	ueh_len;	/* local defined length; <= uef_size */
	uint32_t	ueh_i_gen;	/* generation number for sanity */
	/* data follows the header */
};

/*
 * This structure defines the required fields of an extended-attribute header.
 */
struct extattr {
	uint32_t ea_length;	    /* length of this attribute */
	uint8_t	ea_namespace;	    /* name space of this attribute */
	uint8_t	ea_contentpadlen;   /* bytes of padding at end of attribute */
	uint8_t	ea_namelength;	    /* length of attribute name */
	char	ea_name[1];	    /* attribute name (NOT nul-terminated) */
	/* padding, if any, to align attribute content to 8 byte boundary */
	/* extended attribute content follows */
};

/*
 * These macros are used to access and manipulate an extended attribute:
 *
 * EXTATTR_NEXT(eap) returns a pointer to the next extended attribute
 *	following eap.
 * EXTATTR_CONTENT(eap) returns a pointer to the extended attribute
 *	content referenced by eap.
 * EXTATTR_CONTENT_SIZE(eap) returns the size of the extended attribute
 *	content referenced by eap.
 */
#define	EXTATTR_NEXT(eap) \
	((struct extattr *)(((u_char *)(eap)) + (eap)->ea_length))
#define	EXTATTR_CONTENT(eap) \
	(void *)(((u_char *)(eap)) + EXTATTR_BASE_LENGTH(eap))
#define	EXTATTR_CONTENT_SIZE(eap) \
	((eap)->ea_length - EXTATTR_BASE_LENGTH(eap) - (eap)->ea_contentpadlen)
/* -1 below compensates for ea_name[1] */
#define	EXTATTR_BASE_LENGTH(eap) \
	roundup2((sizeof(struct extattr) - 1 + (eap)->ea_namelength), 8)

#ifdef _KERNEL

#ifdef MALLOC_DECLARE
MALLOC_DECLARE(M_EXTATTR);
#endif

struct vnode;
LIST_HEAD(ufs_extattr_list_head, ufs_extattr_list_entry);
struct ufs_extattr_list_entry {
	LIST_ENTRY(ufs_extattr_list_entry)	uele_entries;
	struct ufs_extattr_fileheader		uele_fileheader;
	int		uele_attrnamespace;
	char		uele_attrname[UFS_EXTATTR_MAXEXTATTRNAME];
	struct vnode	*uele_backing_vnode;
	int		uele_flags;
};

/* uele_flags */
#define	UELE_F_NEEDSWAP		0x01	/* needs byte swap */

#define	UELE_NEEDSWAP(uele)	((uele)->uele_flags & UELE_F_NEEDSWAP)

struct lock;
struct ufs_extattr_per_mount {
	kmutex_t			uepm_lock;
	struct ufs_extattr_list_head	uepm_list;
	kauth_cred_t			uepm_ucred;
	int				uepm_lockcnt;
	int				uepm_flags;
};

void	ufs_extattr_uepm_init(struct ufs_extattr_per_mount *uepm);
void	ufs_extattr_uepm_destroy(struct ufs_extattr_per_mount *uepm);
int	ufs_extattr_start(struct mount *mp, struct lwp *l);
int	ufs_extattr_autostart(struct mount *mp, struct lwp *l);
void	ufs_extattr_stop(struct mount *mp, struct lwp *l);
int	ufs_extattrctl(struct mount *mp, int cmd, struct vnode *filename,
	    int attrnamespace, const char *attrname);
struct vop_getextattr_args;
int	ufs_getextattr(struct vop_getextattr_args *ap);
struct vop_deleteextattr_args;
int	ufs_deleteextattr(struct vop_deleteextattr_args *ap);
struct vop_setextattr_args;
int	ufs_setextattr(struct vop_setextattr_args *ap);
struct vop_listextattr_args;
int	ufs_listextattr(struct vop_listextattr_args *ap);
void	ufs_extattr_vnode_inactive(struct vnode *vp, struct lwp *l);

void	ufs_extattr_init(void);
void	ufs_extattr_done(void);

#endif /* !_KERNEL */

#endif /* !_UFS_UFS_EXTATTR_H_ */