/*	$NetBSD: puffs_msgif.h,v 1.87 2021/12/03 13:08:10 pho Exp $	*/

/*
 * Copyright (c) 2005, 2006, 2007  Antti Kantee.  All Rights Reserved.
 *
 * Development of this software was supported by the
 * Google Summer of Code program and the Ulla Tuominen Foundation.
 * The Google SoC project was mentored by Bill Studenmund.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _FS_PUFFS_PUFFS_MSGIF_H_
#define _FS_PUFFS_PUFFS_MSGIF_H_

#include <sys/param.h>
#include <sys/time.h>
#include <sys/ioccom.h>
#include <sys/uio.h>
#include <sys/vnode.h>
#include <sys/ucred.h>
#include <sys/statvfs.h>
#include <sys/dirent.h>
#include <sys/fcntl.h>

#include <dev/putter/putter.h>

#include <uvm/uvm_prot.h>

#define PUFFSOP_VFS		0x01	/* kernel-> */
#define PUFFSOP_VN		0x02	/* kernel-> */
#define PUFFSOP_CACHE		0x03	/* only kernel-> */
#define PUFFSOP_ERROR		0x04	/* only kernel-> */
#define PUFFSOP_FLUSH		0x05	/* ->kernel */
#define PUFFSOP_SUSPEND		0x06	/* ->kernel */
#define PUFFSOP_UNMOUNT		0x07	/* ->kernel */

#define PUFFSOPFLAG_FAF		0x10	/* fire-and-forget */
#define PUFFSOPFLAG_ISRESPONSE	0x20	/* req is actually a resp */

#define PUFFSOP_OPCMASK		0x07
#define PUFFSOP_OPCLASS(a)	((a) & PUFFSOP_OPCMASK)
#define PUFFSOP_WANTREPLY(a)	(((a) & PUFFSOPFLAG_FAF) == 0)

enum puffs_vfs {
	PUFFS_VFS_MOUNT,	PUFFS_VFS_START,	PUFFS_VFS_UNMOUNT,
	PUFFS_VFS_ROOT,		PUFFS_VFS_QUOTACTL,	PUFFS_VFS_STATVFS,
	PUFFS_VFS_SYNC,		PUFFS_VFS_VGET,		PUFFS_VFS_FHTOVP,
	PUFFS_VFS_VPTOFH,	PUFFS_VFS_INIT,		PUFFS_VFS_DONE,
	PUFFS_VFS_SNAPSHOT,	PUFFS_VFS_EXTATTRCTL,	PUFFS_VFS_SUSPEND
};
#define PUFFS_VFS_MAX PUFFS_VFS_SUSPEND

enum puffs_vn {
	PUFFS_VN_LOOKUP,	PUFFS_VN_CREATE,	PUFFS_VN_MKNOD,
	PUFFS_VN_OPEN,		PUFFS_VN_CLOSE,		PUFFS_VN_ACCESS,
	PUFFS_VN_GETATTR,	PUFFS_VN_SETATTR,	PUFFS_VN_READ,
	PUFFS_VN_WRITE,		PUFFS_VN_IOCTL,		PUFFS_VN_FCNTL,
	PUFFS_VN_POLL,		PUFFS_VN_KQFILTER,	PUFFS_VN_REVOKE,
	PUFFS_VN_MMAP,		PUFFS_VN_FSYNC,		PUFFS_VN_SEEK,
	PUFFS_VN_REMOVE,	PUFFS_VN_LINK,		PUFFS_VN_RENAME,
	PUFFS_VN_MKDIR,		PUFFS_VN_RMDIR,		PUFFS_VN_SYMLINK,
	PUFFS_VN_READDIR,	PUFFS_VN_READLINK,	PUFFS_VN_ABORTOP,
	PUFFS_VN_INACTIVE,	PUFFS_VN_RECLAIM,	PUFFS_VN_LOCK,
	PUFFS_VN_UNLOCK,	PUFFS_VN_BMAP,		PUFFS_VN_STRATEGY,
	PUFFS_VN_PRINT,		PUFFS_VN_ISLOCKED,	PUFFS_VN_PATHCONF,
	PUFFS_VN_ADVLOCK,	PUFFS_VN_LEASE,		PUFFS_VN_WHITEOUT,
	PUFFS_VN_GETPAGES,	PUFFS_VN_PUTPAGES,	PUFFS_VN_GETEXTATTR,
	PUFFS_VN_LISTEXTATTR,	PUFFS_VN_OPENEXTATTR,	PUFFS_VN_DELETEEXTATTR,
	PUFFS_VN_SETEXTATTR,	PUFFS_VN_CLOSEEXTATTR,	PUFFS_VN_FALLOCATE,
	PUFFS_VN_FDISCARD,
	/* NOTE: If you add an op, decrement PUFFS_VN_SPARE accordingly */
};
#define PUFFS_VN_MAX PUFFS_VN_FDISCARD
#define PUFFS_VN_SPARE 30

/*
 * These signal invalid parameters the file system returned.
 */
enum puffs_err {
	PUFFS_ERR_ERROR,
	PUFFS_ERR_MAKENODE,	PUFFS_ERR_LOOKUP,	PUFFS_ERR_READDIR,
	PUFFS_ERR_READLINK,	PUFFS_ERR_READ,		PUFFS_ERR_WRITE,
	PUFFS_ERR_VPTOFH,	PUFFS_ERR_GETEXTATTR,	PUFFS_ERR_LISTEXTATTR
};
#define PUFFS_ERR_MAX PUFFS_ERR_LISTEXTATTR

#define PUFFSVERSION	30
#define PUFFSNAMESIZE	32

#define PUFFS_TYPEPREFIX "puffs|"

#define PUFFS_TYPELEN (_VFS_NAMELEN - (sizeof(PUFFS_TYPEPREFIX)+1))
#define PUFFS_NAMELEN (_VFS_MNAMELEN-1)

/* really statvfs90 */
struct puffs_statvfs {
	unsigned long	f_flag;		/* copy of mount exported flags */
	unsigned long	f_bsize;	/* file system block size */
	unsigned long	f_frsize;	/* fundamental file system block size */
	unsigned long	f_iosize;	/* optimal file system block size */

	/* The following are in units of f_frsize */
	fsblkcnt_t	f_blocks;	/* number of blocks in file system, */
	fsblkcnt_t	f_bfree;	/* free blocks avail in file system */
	fsblkcnt_t	f_bavail;	/* free blocks avail to non-root */
	fsblkcnt_t	f_bresvd;	/* blocks reserved for root */

	fsfilcnt_t	f_files;	/* total file nodes in file system */
	fsfilcnt_t	f_ffree;	/* free file nodes in file system */
	fsfilcnt_t	f_favail;	/* free file nodes avail to non-root */
	fsfilcnt_t	f_fresvd;	/* file nodes reserved for root */

	uint64_t  	f_syncreads;	/* count of sync reads since mount */
	uint64_t  	f_syncwrites;	/* count of sync writes since mount */

	uint64_t  	f_asyncreads;	/* count of async reads since mount */
	uint64_t  	f_asyncwrites;	/* count of async writes since mount */

	fsid_t		f_fsidx;	/* NetBSD compatible fsid */
	unsigned long	f_fsid;		/* Posix compatible fsid */
	unsigned long	f_namemax;	/* maximum filename length */
	uid_t		f_owner;	/* user that mounted the file system */

	uint32_t	f_spare[4];	/* spare space */

	char	f_fstypename[_VFS_NAMELEN]; /* fs type name */
	char	f_mntonname[_VFS_MNAMELEN];  /* directory on which mounted */
	char	f_mntfromname[_VFS_MNAMELEN];  /* mounted file system */
};

#ifndef _KERNEL
#include <string.h>
#endif

static __inline void
statvfs_to_puffs_statvfs(const struct statvfs *s, struct puffs_statvfs *ps)
{
	ps->f_flag = s->f_flag;
	ps->f_bsize = s->f_bsize;
	ps->f_frsize = s->f_frsize;
	ps->f_iosize = s->f_iosize;

	ps->f_blocks = s->f_blocks;
	ps->f_bfree = s->f_bfree;
	ps->f_bavail = s->f_bavail;
	ps->f_bresvd = s->f_bresvd;

	ps->f_files = s->f_files;
	ps->f_ffree = s->f_ffree;
	ps->f_favail = s->f_favail;
	ps->f_fresvd = s->f_fresvd;

	ps->f_syncreads = s->f_syncreads;
	ps->f_syncwrites = s->f_syncwrites;

	ps->f_asyncreads = s->f_asyncreads;
	ps->f_asyncwrites = s->f_asyncwrites;

	ps->f_fsidx = s->f_fsidx;
	ps->f_fsid = s->f_fsid;
	ps->f_namemax = s->f_namemax;
	ps->f_owner = s->f_owner;

	memset(ps->f_spare, 0, sizeof(ps->f_spare));

	memcpy(ps->f_fstypename, s->f_fstypename, sizeof(ps->f_fstypename));
	memcpy(ps->f_mntonname, s->f_mntonname, sizeof(ps->f_mntonname));
	memcpy(ps->f_mntfromname, s->f_mntfromname, sizeof(ps->f_mntfromname));
}

static __inline void
puffs_statvfs_to_statvfs(const struct puffs_statvfs *ps, struct statvfs *s)
{
	s->f_flag = ps->f_flag;
	s->f_bsize = ps->f_bsize;
	s->f_frsize = ps->f_frsize;
	s->f_iosize = ps->f_iosize;

	s->f_blocks = ps->f_blocks;
	s->f_bfree = ps->f_bfree;
	s->f_bavail = ps->f_bavail;
	s->f_bresvd = ps->f_bresvd;

	s->f_files = ps->f_files;
	s->f_ffree = ps->f_ffree;
	s->f_favail = ps->f_favail;
	s->f_fresvd = ps->f_fresvd;

	s->f_syncreads = ps->f_syncreads;
	s->f_syncwrites = ps->f_syncwrites;

	s->f_asyncreads = ps->f_asyncreads;
	s->f_asyncwrites = ps->f_asyncwrites;

	s->f_fsidx = ps->f_fsidx;
	s->f_fsid = ps->f_fsid;
	s->f_namemax = ps->f_namemax;
	s->f_owner = ps->f_owner;

	memset(s->f_spare, 0, sizeof(s->f_spare));

	memcpy(s->f_fstypename, ps->f_fstypename, sizeof(s->f_fstypename));
	memcpy(s->f_mntonname, ps->f_mntonname, sizeof(s->f_mntonname));
	memcpy(s->f_mntfromname, ps->f_mntfromname, sizeof(s->f_mntfromname));
	memset(s->f_mntfromlabel, 0, sizeof(s->f_mntfromlabel));
}

/* 
 * Just a weak typedef for code clarity.  Additionally, we have a
 * more appropriate vanity type for puffs:
 * <uep> it should be croissant, not cookie.
 */
typedef void *puffs_cookie_t;
typedef puffs_cookie_t puffs_croissant_t;

struct puffs_kargs {
	unsigned int	pa_vers;
	int		pa_fd;

	uint32_t	pa_flags;

	size_t		pa_maxmsglen;
	int		pa_nhashbuckets;

	size_t		pa_fhsize;
	int		pa_fhflags;

	uint8_t		pa_vnopmask[PUFFS_VN_MAX + PUFFS_VN_SPARE];

	char		pa_typename[_VFS_NAMELEN];
	char		pa_mntfromname[_VFS_MNAMELEN];

	puffs_cookie_t	pa_root_cookie;
	enum vtype	pa_root_vtype;
	voff_t		pa_root_vsize;
	union {
		dev_t		dev;
		uint64_t	container;
	} devunion;

	struct puffs_statvfs	pa_svfsb;

	uint32_t	pa_time32;

	uint32_t	pa_spare[127];
};
#define pa_root_rdev devunion.dev

#define PUFFS_KFLAG_NOCACHE_NAME	0x001	/* don't use name cache     */
#define PUFFS_KFLAG_NOCACHE_PAGE	0x002	/* don't use page cache	    */
#define PUFFS_KFLAG_NOCACHE		0x003	/* no cache whatsoever      */
#define PUFFS_KFLAG_ALLOPS		0x004	/* ignore pa_vnopmask       */
#define PUFFS_KFLAG_WTCACHE		0x008	/* write-through page cache */
#define PUFFS_KFLAG_IAONDEMAND		0x010	/* inactive only on demand  */
#define PUFFS_KFLAG_LOOKUP_FULLPNBUF	0x020	/* full pnbuf in lookup     */
#define PUFFS_KFLAG_NOCACHE_ATTR	0x040	/* no attrib cache (unused) */
#define PUFFS_KFLAG_CACHE_FS_TTL	0x080	/* cache use TTL from FS    */
#define PUFFS_KFLAG_CACHE_DOTDOT	0x100	/* don't send lookup for .. */
#define PUFFS_KFLAG_NOFLUSH_META	0x200	/* don't flush metadata cache*/
#define PUFFS_KFLAG_MASK		0x3bf

#define PUFFS_FHFLAG_DYNAMIC		0x01
#define PUFFS_FHFLAG_NFSV2		0x02
#define PUFFS_FHFLAG_NFSV3		0x04
#define PUFFS_FHFLAG_PROTOMASK		0x06
#define PUFFS_FHFLAG_PASSTHROUGH	0x08
#define PUFFS_FHFLAG_MASK		0x0f

#define PUFFS_FHSIZE_MAX	1020	/* FHANDLE_SIZE_MAX - 4 */

struct puffs_req {
	struct putter_hdr	preq_pth;

	uint64_t		preq_id;
	puffs_cookie_t		preq_cookie;

	uint16_t		preq_opclass;
	uint16_t		preq_optype;
	int			preq_rv;

	uint32_t		preq_setbacks;

	/* Who is making the call?  Eventually host id is also needed. */
	pid_t			preq_pid;
	lwpid_t			preq_lid;

	/*
	 * the following helper pads the struct size to md alignment
	 * multiple (should size_t not cut it).  it makes sure that
	 * whatever comes after this struct is aligned
	 */
	size_t  		preq_buflen;
	uint8_t	preq_buf[0] __aligned(ALIGNBYTES+1);
};

#define PUFFS_SETBACK_INACT_N1	0x01	/* set VOP_INACTIVE for node 1 */
#define PUFFS_SETBACK_INACT_N2	0x02	/* set VOP_INACTIVE for node 2 */
#define PUFFS_SETBACK_NOREF_N1	0x04	/* set pn PN_NOREFS for node 1 */
#define PUFFS_SETBACK_NOREF_N2	0x08	/* set pn PN_NOREFS for node 2 */
#define PUFFS_SETBACK_MASK	0x0f

/*
 * Flush operation.  This can be used to invalidate:
 * 1) name cache for one node
 * 2) name cache for all children 
 * 3) name cache for the entire mount
 * 4) page cache for a set of ranges in one node
 * 5) page cache for one entire node
 *
 * It can be used to flush:
 * 1) page cache for a set of ranges in one node
 * 2) page cache for one entire node
 */

struct puffs_flush {
	struct puffs_req	pf_req;

	puffs_cookie_t		pf_cookie;

	int			pf_op;
	off_t			pf_start;
	off_t			pf_end;
};
#define PUFFS_INVAL_NAMECACHE_NODE		0
#define PUFFS_INVAL_NAMECACHE_DIR		1
#define PUFFS_INVAL_NAMECACHE_ALL		2
#define PUFFS_INVAL_PAGECACHE_NODE_RANGE	3
#define PUFFS_FLUSH_PAGECACHE_NODE_RANGE	4

/*
 * Credentials for an operation.  Can be either struct uucred for
 * ops called from a credential context or NOCRED/FSCRED for ops
 * called from within the kernel.  It is up to the implementation
 * if it makes a difference between these two and the super-user.
 */
struct puffs_kcred {
	struct uucred	pkcr_uuc;
	uint8_t		pkcr_type;
	uint8_t		pkcr_internal;
};
#define PUFFCRED_TYPE_UUC	1
#define PUFFCRED_TYPE_INTERNAL	2
#define PUFFCRED_CRED_NOCRED	1
#define PUFFCRED_CRED_FSCRED	2

/*
 * 2*MAXPHYS is the max size the system will attempt to copy,
 * else treated as garbage
 */
#define PUFFS_MSG_MAXSIZE	2*MAXPHYS
#define PUFFS_MSGSTRUCT_MAX	4096 /* approximate */

#define PUFFS_EXTNAMELEN KERNEL_NAME_MAX /* currently same as EXTATTR_MAXNAMELEN */

#define PUFFS_TOMOVE(a,b) (MIN((a), b->pmp_msg_maxsize - PUFFS_MSGSTRUCT_MAX))

/* puffs struct componentname built by kernel */
struct puffs_kcn {
	/* args */
	uint32_t		pkcn_nameiop;	/* namei operation	*/
	uint32_t		pkcn_flags;	/* flags		*/

	char pkcn_name[MAXPATHLEN];	/* nulterminated path component */
	size_t pkcn_namelen;		/* current component length	*/
	size_t pkcn_consume;		/* IN: extra chars server ate   */
};


/*
 * Next come the individual requests.  They are all subclassed from
 * puffs_req and contain request-specific fields in addition.  Note
 * that there are some requests which have to handle arbitrary-length
 * buffers.
 *
 * The division is the following: puffs_req is to be touched only
 * by generic routines while the other stuff is supposed to be
 * modified only by specific routines.
 */

/*
 * aux structures for vfs operations.
 */
struct puffs_vfsmsg_unmount {
	struct puffs_req	pvfsr_pr;

	int			pvfsr_flags;
};

struct puffs_vfsmsg_statvfs {
	struct puffs_req	pvfsr_pr;

	struct puffs_statvfs	pvfsr_sb;
};

struct puffs_vfsmsg_sync {
	struct puffs_req	pvfsr_pr;

	struct puffs_kcred	pvfsr_cred;
	int			pvfsr_waitfor;
};

struct puffs_vfsmsg_fhtonode {
	struct puffs_req	pvfsr_pr;

	void			*pvfsr_fhcookie;	/* IN	*/
	enum vtype		pvfsr_vtype;		/* IN	*/
	voff_t			pvfsr_size;		/* IN	*/
	dev_t			pvfsr_rdev;		/* IN	*/

	size_t			pvfsr_dsize;		/* OUT */
	uint8_t			pvfsr_data[0]		/* OUT, XXX */
				    __aligned(ALIGNBYTES+1);
};

struct puffs_vfsmsg_nodetofh {
	struct puffs_req	pvfsr_pr;

	void			*pvfsr_fhcookie;	/* OUT	*/

	size_t			pvfsr_dsize;		/* OUT/IN  */
	uint8_t			pvfsr_data[0]		/* IN, XXX */
				    __aligned(ALIGNBYTES+1);
};

struct puffs_vfsmsg_suspend {
	struct puffs_req	pvfsr_pr;

	int			pvfsr_status;
};
#define PUFFS_SUSPEND_START	0
#define PUFFS_SUSPEND_SUSPENDED	1
#define PUFFS_SUSPEND_RESUME	2
#define PUFFS_SUSPEND_ERROR	3

#define PUFFS_EXTATTRCTL_HASNODE	0x01
#define PUFFS_EXTATTRCTL_HASATTRNAME	0x02

#define	PUFFS_OPEN_IO_DIRECT	0x01

struct puffs_vfsmsg_extattrctl {
	struct puffs_req	pvfsr_pr;

	int			pvfsr_cmd;			  /* OUT */
	int			pvfsr_attrnamespace;		  /* OUT */
	int			pvfsr_flags;			  /* OUT */
	char			pvfsr_attrname[PUFFS_EXTNAMELEN]; /* OUT */
};

/*
 * aux structures for vnode operations.
 */

struct puffs_vnmsg_lookup {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/

	puffs_cookie_t		pvnr_newnode;		/* IN	*/
	enum vtype		pvnr_vtype;		/* IN	*/
	voff_t			pvnr_size;		/* IN	*/
	dev_t			pvnr_rdev;		/* IN	*/
	/* Used only if PUFFS_KFLAG_CACHE_USE_TTL */
	struct vattr		pvnr_va;		/* IN	*/
	struct timespec		pvnr_va_ttl;		/* IN	*/
	struct timespec		pvnr_cn_ttl;		/* IN	*/
};

struct puffs_vnmsg_create {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/

	struct vattr		pvnr_va;		/* OUT	*/
	puffs_cookie_t		pvnr_newnode;		/* IN	*/
	/* Used only if PUFFS_KFLAG_CACHE_USE_TTL */
	struct timespec		pvnr_va_ttl;		/* IN	*/
	struct timespec		pvnr_cn_ttl;		/* IN	*/
};

struct puffs_vnmsg_mknod {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/

	struct vattr		pvnr_va;		/* OUT	*/
	puffs_cookie_t		pvnr_newnode;		/* IN	*/
	/* Used only if PUFFS_KFLAG_CACHE_USE_TTL */
	struct timespec		pvnr_va_ttl;		/* IN	*/
	struct timespec		pvnr_cn_ttl;		/* IN	*/
};

struct puffs_vnmsg_open {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT	*/
	int			pvnr_mode;		/* OUT	*/
	int			pvnr_oflags;		/* IN	*/
};

struct puffs_vnmsg_close {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT	*/
	int			pvnr_fflag;		/* OUT	*/
};

struct puffs_vnmsg_access {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT	*/
	int			pvnr_mode;		/* OUT	*/
};

#define puffs_vnmsg_setattr puffs_vnmsg_setgetattr
#define puffs_vnmsg_getattr puffs_vnmsg_setgetattr
struct puffs_vnmsg_setgetattr {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT	*/
	struct vattr		pvnr_va;		/* IN/OUT (op depend) */
	/* Used only if PUFFS_KFLAG_CACHE_USE_TTL */
	struct timespec		pvnr_va_ttl;		/* IN	*/
};

#define puffs_vnmsg_read puffs_vnmsg_rw
#define puffs_vnmsg_write puffs_vnmsg_rw
struct puffs_vnmsg_rw {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT	  */
	off_t			pvnr_offset;		/* OUT	  */
	size_t			pvnr_resid;		/* IN/OUT */
	int			pvnr_ioflag;		/* OUT	  */

	uint8_t			pvnr_data[0];		/* IN/OUT (wr/rd) */
};

#define puffs_vnmsg_ioctl puffs_vnreq_fcnioctl
#define puffs_vnmsg_fcntl puffs_vnreq_fcnioctl
struct puffs_vnmsg_fcnioctl {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;
	u_long			pvnr_command;
	pid_t			pvnr_pid;
	int			pvnr_fflag;

	void			*pvnr_data;
	size_t			pvnr_datalen;
	int			pvnr_copyback;
};

struct puffs_vnmsg_poll {
	struct puffs_req	pvn_pr;

	int			pvnr_events;		/* IN/OUT */
};

struct puffs_vnmsg_fsync {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT	*/
	off_t			pvnr_offlo;		/* OUT	*/
	off_t			pvnr_offhi;		/* OUT	*/
	int			pvnr_flags;		/* OUT	*/
};

struct puffs_vnmsg_seek {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT	*/
	off_t			pvnr_oldoff;		/* OUT	*/
	off_t			pvnr_newoff;		/* OUT	*/
};

struct puffs_vnmsg_remove {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/

	puffs_cookie_t		pvnr_cookie_targ;	/* OUT	*/
};

struct puffs_vnmsg_mkdir {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/

	struct vattr		pvnr_va;		/* OUT	*/
	puffs_cookie_t		pvnr_newnode;		/* IN	*/
	/* Used only if PUFFS_KFLAG_CACHE_USE_TTL */
	struct timespec		pvnr_va_ttl;		/* IN	*/
	struct timespec		pvnr_cn_ttl;		/* IN	*/
};

struct puffs_vnmsg_rmdir {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/

	puffs_cookie_t		pvnr_cookie_targ;	/* OUT	*/
};

struct puffs_vnmsg_link {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/

	puffs_cookie_t		pvnr_cookie_targ;	/* OUT	*/
};

struct puffs_vnmsg_rename {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn_src;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_src_cred;	/* OUT	*/
	struct puffs_kcn	pvnr_cn_targ;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_targ_cred;	/* OUT	*/

	puffs_cookie_t		pvnr_cookie_src;	/* OUT	*/
	puffs_cookie_t		pvnr_cookie_targ;	/* OUT	*/
	puffs_cookie_t		pvnr_cookie_targdir;	/* OUT	*/
};

struct puffs_vnmsg_symlink {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/

	struct vattr		pvnr_va;		/* OUT	*/
	puffs_cookie_t		pvnr_newnode;		/* IN	*/
	char			pvnr_link[MAXPATHLEN];	/* OUT	*/
	/* Used only if PUFFS_KFLAG_CACHE_USE_TTL */
	struct timespec		pvnr_va_ttl;		/* IN	*/
	struct timespec		pvnr_cn_ttl;		/* IN	*/
};

struct puffs_vnmsg_readdir {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT	  */
	off_t			pvnr_offset;		/* IN/OUT */
	size_t			pvnr_resid;		/* IN/OUT */
	size_t			pvnr_ncookies;		/* IN/OUT */
	int			pvnr_eofflag;		/* IN     */

	size_t			pvnr_dentoff;		/* OUT    */
	uint8_t			pvnr_data[0]		/* IN  	  */
				    __aligned(ALIGNBYTES+1);
};

struct puffs_vnmsg_readlink {
	struct puffs_req	pvn_pr;

	struct puffs_kcred	pvnr_cred;		/* OUT */
	size_t			pvnr_linklen;		/* IN  */
	char			pvnr_link[MAXPATHLEN];	/* IN  */
};

struct puffs_vnmsg_reclaim {
	struct puffs_req	pvn_pr;

	int			pvnr_nlookup;		/* OUT */
};

struct puffs_vnmsg_inactive {
	struct puffs_req	pvn_pr;
};

struct puffs_vnmsg_print {
	struct puffs_req	pvn_pr;

	/* empty */
};

struct puffs_vnmsg_pathconf {
	struct puffs_req	pvn_pr;

	int			pvnr_name;		/* OUT	*/
	__register_t		pvnr_retval;		/* IN	*/
};

struct puffs_vnmsg_advlock {
	struct puffs_req	pvn_pr;

	struct flock		pvnr_fl;		/* OUT	*/
	void			*pvnr_id;		/* OUT	*/
	int			pvnr_op;		/* OUT	*/
	int			pvnr_flags;		/* OUT	*/
};

struct puffs_vnmsg_mmap {
	struct puffs_req	pvn_pr;

	vm_prot_t		pvnr_prot;		/* OUT	*/
	struct puffs_kcred	pvnr_cred;		/* OUT	*/
};

struct puffs_vnmsg_abortop {
	struct puffs_req	pvn_pr;

	struct puffs_kcn	pvnr_cn;		/* OUT	*/
	struct puffs_kcred	pvnr_cn_cred;		/* OUT	*/
};

struct puffs_vnmsg_getextattr {
	struct puffs_req	pvn_pr;

	int			pvnr_attrnamespace;		/* OUT	  */
	char			pvnr_attrname[PUFFS_EXTNAMELEN];/* OUT	  */

	struct puffs_kcred	pvnr_cred;			/* OUT	  */
	size_t			pvnr_datasize;			/* IN	  */

	size_t			pvnr_resid;			/* IN/OUT */
	uint8_t			pvnr_data[0]			/* IN	  */
				    __aligned(ALIGNBYTES+1);
};

struct puffs_vnmsg_setextattr {
	struct puffs_req	pvn_pr;

	int			pvnr_attrnamespace;		/* OUT	  */
	char			pvnr_attrname[PUFFS_EXTNAMELEN];/* OUT	  */

	struct puffs_kcred	pvnr_cred;			/* OUT	*/

	size_t			pvnr_resid;			/* IN/OUT */
	uint8_t			pvnr_data[0]			/* OUT	  */
				    __aligned(ALIGNBYTES+1);
};

struct puffs_vnmsg_listextattr {
	struct puffs_req	pvn_pr;

	int			pvnr_attrnamespace;		/* OUT	  */

	struct puffs_kcred	pvnr_cred;			/* OUT	*/
	size_t			pvnr_datasize;			/* IN	  */

	size_t			pvnr_resid;			/* IN/OUT */
	int			pvnr_flag;			/* OUT */
	uint8_t			pvnr_data[0]			/* IN	  */
				    __aligned(ALIGNBYTES+1);
};

struct puffs_vnmsg_deleteextattr {
	struct puffs_req	pvn_pr;

	int			pvnr_attrnamespace;		/* OUT	  */
	char			pvnr_attrname[PUFFS_EXTNAMELEN];/* OUT	  */

	struct puffs_kcred	pvnr_cred;			/* OUT	*/
};

#define PUFFS_HAVE_FALLOCATE 1
struct puffs_vnmsg_fallocate {
	struct puffs_req	pvn_pr;
	off_t			pvnr_off;			/* OUT    */
	off_t			pvnr_len;			/* OUT    */
};

struct puffs_vnmsg_fdiscard {
	struct puffs_req	pvn_pr;
	off_t			pvnr_off;			/* OUT    */
	off_t			pvnr_len;			/* OUT    */
};

/*
 * For cache reports.  Everything is always out-out-out, no replies
 */

struct puffs_cacherun {
	off_t			pcache_runstart;
	off_t			pcache_runend;
};

/* cache info.  old used for write now */
struct puffs_cacheinfo {
	struct puffs_req	pcache_pr;

	int			pcache_type;
	size_t			pcache_nruns;		
	struct puffs_cacherun	pcache_runs[0];
};
#define PCACHE_TYPE_READ	0
#define PCACHE_TYPE_WRITE	1

/*
 * Error notification.  Always outgoing, no response, no remorse.
 */
struct puffs_error {
	struct puffs_req	perr_pr;

	int			perr_error;
	char			perr_str[256];
};

#endif /* _FS_PUFFS_PUFFS_MSGIF_H_ */