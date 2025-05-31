/*	$NetBSD: kernfs.h,v 1.44 2020/04/07 08:14:42 jdolecek Exp $	*/

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
 *	@(#)kernfs.h	8.6 (Berkeley) 3/29/95
 */

#define	_PATH_KERNFS	"/kern"		/* Default mountpoint */

#ifdef _KERNEL
#include <sys/queue.h>
#include <sys/tree.h>
#include <sys/mutex.h>

/*
 * The different types of node in a kernfs filesystem
 */
typedef enum {
	KFSkern,		/* the filesystem itself (.) */
	KFSroot,		/* the filesystem root (..) */
	KFSnull,		/* none aplicable */
	KFStime,		/* time */
	KFSboottime,		/* boottime */
	KFSint,			/* integer */
	KFSstring,		/* string */
	KFShostname,		/* hostname */
	KFSavenrun,		/* loadavg */
	KFSdevice,		/* device file (rootdev/rrootdev) */
	KFSmsgbuf,		/* msgbuf */
	KFSsubdir,		/* directory */
	KFSlasttype,		/* last used type */
	KFSmaxtype = (1<<6) - 1	/* last possible type */
} kfstype;

/*
 * Control data for the kern file system.
 */
struct kern_target {
	u_char		kt_type;
	u_char		kt_namlen;
	const char	*kt_name;
	void		*kt_data;
	kfstype		kt_tag;
	u_char		kt_vtype;
	mode_t		kt_mode;
};

struct dyn_kern_target {
	struct kern_target		dkt_kt;
	SIMPLEQ_ENTRY(dyn_kern_target)	dkt_queue;
};

struct kernfs_subdir {
	SIMPLEQ_HEAD(,dyn_kern_target)	ks_entries;
	unsigned int			ks_nentries;
	unsigned int			ks_dirs;
	const struct kern_target	*ks_parent;
};

struct kernfs_node {
	LIST_ENTRY(kernfs_node) kfs_hash; /* hash chain */
	TAILQ_ENTRY(kernfs_node) kfs_list; /* flat list */
	struct vnode	*kfs_vnode;	/* vnode associated with this kernfs_node */
	kfstype		kfs_type;	/* type of kernfs node */
	mode_t		kfs_mode;	/* mode bits for stat() */
	long		kfs_fileno;	/* unique file id */
	const struct kern_target *kfs_kt;
	void		*kfs_v;		/* dynamic node private data */
	long		kfs_cookie;	/* fileno cookie */
};

struct kernfs_mount {
	TAILQ_HEAD(, kernfs_node) nodelist;
	long fileno_cookie;
};

#define UIO_MX	32

#define KERNFS_FILENO(kt, typ, cookie) \
	((kt >= &kern_targets[0] && kt < &kern_targets[static_nkern_targets]) \
	    ? 2 + ((kt) - &kern_targets[0]) \
	      : (((cookie + 1) << 6) | (typ)))
#define KERNFS_TYPE_FILENO(typ, cookie) \
	(((cookie + 1) << 6) | (typ))

#define VFSTOKERNFS(mp)	((struct kernfs_mount *)((mp)->mnt_data))
#define	VTOKERN(vp)	((struct kernfs_node *)(vp)->v_data)
#define KERNFSTOV(kfs)	((kfs)->kfs_vnode)

#define KERNFS_MAXNAMLEN	255

extern const struct kern_target kern_targets[];
extern int nkern_targets;
extern const int static_nkern_targets;
extern int (**kernfs_vnodeop_p)(void *);
extern int (**kernfs_specop_p)(void *);
extern struct vfsops kernfs_vfsops;
extern dev_t rrootdev;
extern kmutex_t kfs_lock;

int kernfs_root(struct mount *, int, struct vnode **);

/*
 * Data types for the kernfs file operations.
 */
typedef enum {
	KERNFS_XREAD,
	KERNFS_XWRITE,
	KERNFS_FILEOP_CLOSE,
	KERNFS_FILEOP_GETATTR,
	KERNFS_FILEOP_IOCTL,
	KERNFS_FILEOP_OPEN,
	KERNFS_FILEOP_READ,
	KERNFS_FILEOP_WRITE,
} kfsfileop;

struct kernfs_fileop {
	kfstype				kf_type;
	kfsfileop			kf_fileop;
	union {
		int			(*_kf_vop)(void *);
		int			(*_kf_xread)
			(const struct kernfs_node *, char **, size_t);
		int			(*_kf_xwrite)
			(const struct kernfs_node *, char *, size_t);
	} _kf_opfn;
	SPLAY_ENTRY(kernfs_fileop)	kf_node;
};

#define	kf_vop		_kf_opfn._kf_vop
#define	kf_xread	_kf_opfn._kf_xread
#define	kf_xwrite	_kf_opfn._kf_xwrite

typedef struct kern_target kernfs_parentdir_t;
typedef struct dyn_kern_target kernfs_entry_t;

/*
 * Functions for adding kernfs datatypes and nodes.
 */
kfstype kernfs_alloctype(int, const struct kernfs_fileop *);
#define	KERNFS_ALLOCTYPE(kf) kernfs_alloctype(sizeof((kf)) / \
	sizeof((kf)[0]), (kf))
#define	KERNFS_ALLOCENTRY(dkt, km_flags)				\
	dkt = (kernfs_entry_t *)kmem_zalloc(				\
		sizeof(struct dyn_kern_target), (km_flags))
#define	KERNFS_INITENTRY(dkt, type, name, data, tag, vtype, mode) do {	\
	(dkt)->dkt_kt.kt_type = (type);					\
	(dkt)->dkt_kt.kt_namlen = strlen((name));			\
	(dkt)->dkt_kt.kt_name = (name);					\
	(dkt)->dkt_kt.kt_data = (data);					\
	(dkt)->dkt_kt.kt_tag = (tag);					\
	(dkt)->dkt_kt.kt_vtype = (vtype);				\
	(dkt)->dkt_kt.kt_mode = (mode);					\
} while (/*CONSTCOND*/0)
#define	KERNFS_ENTOPARENTDIR(dkt) &(dkt)->dkt_kt
int kernfs_addentry(kernfs_parentdir_t *, kernfs_entry_t *);

#ifdef IPSEC
__weak_extern(key_freesp)
__weak_extern(key_getspbyid)
__weak_extern(key_setdumpsa_spi)
__weak_extern(key_setdumpsp)
__weak_extern(satailq)
__weak_extern(sptailq)
#endif

#endif /* _KERNEL */