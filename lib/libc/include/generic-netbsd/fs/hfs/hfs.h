/*	$NetBSD: hfs.h,v 1.12 2020/07/24 05:26:37 skrll Exp $	*/

/*-
 * Copyright (c) 2005, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Yevgeny Binder and Dieter Baron.
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

#ifndef _FS_HFS_HFS_H_
#define _FS_HFS_HFS_H_

#include <sys/vnode.h>
#include <sys/mount.h>

#include <miscfs/genfs/genfs_node.h>

/* XXX remove before release */
/*#define HFS_DEBUG*/

#ifdef HFS_DEBUG
	#if defined(_KERNEL)
		#include "opt_ddb.h"
	#endif /* defined(_KERNEL_) */
#endif /* HFS_DEBUG */

#include <fs/hfs/libhfs.h>

/* XXX: make these mount options */
#define HFS_DEFAULT_UID	0
#define HFS_DEFAULT_GID	0
#define HFS_DEFAULT_DIR_MODE	0755
#define HFS_DEFAULT_FILE_MODE	0755

struct hfs_args {
	char *fspec;		/* block special device to mount */
};

struct hfsmount {
	struct mount *hm_mountp;	/* filesystem vfs structure */
	dev_t hm_dev;				/* device mounted */
	struct vnode *hm_devvp;		/* block device mounted vnode */
	hfs_volume hm_vol;			/* essential volume information */
};

struct hfsnode_key {
	hfs_cnid_t hnk_cnid;
	uint8_t hnk_fork;
};

struct hfsnode {
	struct genfs_node h_gnode;
	struct vnode *h_vnode;		/* vnode associated with this hnode */
	struct hfsmount *h_hmp;	/* mount point associated with this hnode */
	struct vnode *h_devvp;		/* vnode for block I/O */
	dev_t	h_dev;				/* device associated with this hnode */

	union {
		hfs_file_record_t		file;
		hfs_folder_record_t	folder;
		struct {
			int16_t			rec_type;
			uint16_t		flags;
			uint32_t		valence;
			hfs_cnid_t		cnid;
		} u; /* convenience for accessing common record info */
	} h_rec; /* catalog record for this hnode */

	/*
	 * We cache this vnode's parent CNID here upon vnode creation (i.e., during
	 * hfs_vop_vget()) for quick access without needing to search the catalog.
	 * Note, however, that this value must also be updated whenever this file
	 * is moved.
	 */
	hfs_cnid_t		h_parent;

	struct hfsnode_key h_key;
#define h_fork	h_key.hnk_fork

	long	dummy;	/* FOR DEVELOPMENT ONLY */
};

typedef struct {
	struct vnode* devvp; /* vnode for device I/O */
	size_t devblksz; /* device block size (NOT HFS+ allocation block size)*/
} hfs_libcb_data; /* custom data used in hfs_volume.cbdata */

typedef struct {
	kauth_cred_t cred;
	struct lwp *l;
	struct vnode *devvp;
} hfs_libcb_argsopen;

typedef struct {
	struct lwp *l;
} hfs_libcb_argsclose;

typedef struct {
	kauth_cred_t cred;
	struct lwp *l;
} hfs_libcb_argsread;

#ifdef _KERNEL
#include <sys/malloc.h>

MALLOC_DECLARE(M_HFSMNT);	/* defined in hfs_vfsops.c */

/*
 * Convenience macros
 */

/* Convert mount ptr to hfsmount ptr. */
#define VFSTOHFS(mp)    ((struct hfsmount *)((mp)->mnt_data))

/* Convert between vnode ptrs and hfsnode ptrs. */
#define VTOH(vp)    ((struct hfsnode *)(vp)->v_data)
#define	HTOV(hp)	((hp)->h_vnode)

/* Get volume's allocation block size given a vnode ptr */
#define HFS_BLOCKSIZE(vp)    (VTOH(vp)->h_hmp->hm_vol.vh.block_size)


/* Convert special device major/minor */
#define HFS_CONVERT_RDEV(x)	makedev((x)>>24, (x)&0xffffff)

/*
 * Global variables
 */

extern const struct vnodeopv_desc hfs_vnodeop_opv_desc;
extern const struct vnodeopv_desc hfs_specop_opv_desc;
extern const struct vnodeopv_desc hfs_fifoop_opv_desc;
extern int (**hfs_specop_p) (void *);
extern int (**hfs_fifoop_p) (void *);
extern struct pool hfs_node_pool;


/*
 * Function prototypes
 */

/* hfs_subr.c */
void hfs_vinit (struct mount *, int (**)(void *), int (**)(void *),
		 struct vnode **);
int hfs_pread(struct vnode*, void*, size_t, uint64_t, uint64_t, kauth_cred_t);
char* hfs_unicode_to_ascii(const unichar_t*, uint8_t, char*);
unichar_t* hfs_ascii_to_unicode(const char*, uint8_t, unichar_t*);

void hfs_time_to_timespec(uint32_t, struct timespec *);
enum vtype hfs_catalog_keyed_record_vtype(const hfs_catalog_keyed_record_t *);

void hfs_libcb_error(const char*, const char*, int, va_list);
void* hfs_libcb_malloc(size_t, hfs_callback_args*);
void* hfs_libcb_realloc(void*, size_t, hfs_callback_args*);
void hfs_libcb_free(void*, hfs_callback_args*);
int hfs_libcb_opendev(hfs_volume*, const char*, hfs_callback_args*);
void hfs_libcb_closedev(hfs_volume*, hfs_callback_args*);
int hfs_libcb_read(hfs_volume*, void*, uint64_t, uint64_t,
	hfs_callback_args*);

uint16_t be16tohp(void**);
uint32_t be32tohp(void**);
uint64_t be64tohp(void**);


/* hfs_vfsops.c */
VFS_PROTOS(hfs);

int hfs_mountfs (struct vnode *, struct mount *, struct lwp *, const char *);
int hfs_vget_internal(struct mount *, ino_t, uint8_t, struct vnode **);

/* hfs_vnops.c */
extern int (**hfs_vnodeop_p) (void *);

#endif /* _KERNEL */

#endif /* !_FS_HFS_HFS_H_ */