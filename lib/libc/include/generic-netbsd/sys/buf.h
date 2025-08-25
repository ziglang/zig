/*     $NetBSD: buf.h,v 1.134 2020/07/31 04:07:30 chs Exp $ */

/*-
 * Copyright (c) 1999, 2000, 2007, 2008 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center, and by Andrew Doran.
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
 * Copyright (c) 1982, 1986, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)buf.h	8.9 (Berkeley) 3/30/95
 */

#ifndef _SYS_BUF_H_
#define	_SYS_BUF_H_

#include <sys/pool.h>
#include <sys/queue.h>
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/rbtree.h>
#if defined(_KERNEL)
#include <sys/workqueue.h>
#endif /* defined(_KERNEL) */

struct buf;
struct mount;
struct vnode;
struct kauth_cred;

#define NOLIST ((struct buf *)0x87654321)

extern kmutex_t bufcache_lock;
extern kmutex_t buffer_lock;

#if defined(_KERNEL)
extern void (*biodone_vfs)(buf_t *);
#endif

/*
 * The buffer header describes an I/O operation in the kernel.
 *
 * Field markings and the corresponding locks:
 *
 * b	thread of execution that holds BC_BUSY, does not correspond
 *	  directly to any particular LWP
 * c	bufcache_lock
 * o	b_objlock
 *
 * For buffers associated with a vnode, b_objlock points to vp->v_interlock.
 * If not associated with a vnode, it points to the generic buffer_lock.
 */

/* required for the conditional union member below to be ~safe */
#if defined(_KERNEL)
__CTASSERT(sizeof(struct work) <= sizeof(TAILQ_ENTRY(buf)));
#endif

struct buf {
	union {
		TAILQ_ENTRY(buf) u_actq;
		rb_node_t u_rbnode;
#if defined(_KERNEL)
		/* u_work is smaller than u_actq */
		struct work u_work;
#endif
	} b_u;					/* b: device driver queue */
#define	b_actq	b_u.u_actq
#define	b_work	b_u.u_work
	void			(*b_iodone)(struct buf *);/* b: call when done */
	int			b_error;	/* b: errno value. */
	int			b_resid;	/* b: remaining I/O. */
	u_int			b_flags;	/* b: B_* flags */
	int			b_prio;		/* b: priority for queue */
	int			b_bufsize;	/* b: allocated size */
	int			b_bcount;	/* b: valid bytes in buffer */
	dev_t			b_dev;		/* b: associated device */
	void			*b_data;	/* b: fs private data */
	daddr_t			b_blkno;	/* b: physical block number
						      (partition relative) */
	daddr_t			b_rawblkno;	/* b: raw physical block number
						      (volume relative) */
	struct proc		*b_proc;	/* b: proc if BB_PHYS */
	void			*b_saveaddr;	/* b: saved b_data for physio */
	struct cpu_info		*b_ci;		/* b: originating CPU */

	/*
	 * b: private data for owner.
	 *  - buffer cache buffers are owned by corresponding filesystem.
	 *  - non-buffer cache buffers are owned by subsystem which
	 *    allocated them. (filesystem, disk driver, etc)
	 */
	void	*b_private;
	off_t	b_dcookie;		/* NFS: Offset cookie if dir block */

	kcondvar_t		b_busy;		/* c: threads waiting on buf */
	void			*b_unused;	/*  : unused */
	LIST_ENTRY(buf)		b_hash;		/* c: hash chain */
	LIST_ENTRY(buf)		b_vnbufs;	/* c: associated vnode */
	TAILQ_ENTRY(buf)	b_freelist;	/* c: position if not active */
	TAILQ_ENTRY(buf)	b_wapbllist;	/* c: transaction buffer list */
	daddr_t			b_lblkno;	/* c: logical block number */
	int			b_freelistindex;/* c: free list index (BQ_) */
	u_int			b_cflags;	/* c: BC_* flags */
	struct vnode		*b_vp;		/* c: file vnode */

	kcondvar_t		b_done;		/* o: waiting on completion */
	u_int			b_oflags;	/* o: BO_* flags */
	kmutex_t		*b_objlock;	/* o: completion lock */
};

/*
 * For portability with historic industry practice, the cylinder number has
 * to be maintained in the `b_resid' field.
 */
#define	b_cylinder b_resid		/* Cylinder number for disksort(). */

/*
 * These flags are kept in b_cflags (owned by buffer cache).
 */
#define	BC_AGE		0x00000001	/* Move to age queue when I/O done. */
#define	BC_BUSY		0x00000010	/* I/O in progress. */
#define	BC_INVAL	0x00002000	/* Does not contain valid info. */
#define	BC_NOCACHE	0x00008000	/* Do not cache block after use. */
#define	BC_WANTED	0x00800000	/* Process wants this buffer. */
#define	BC_VFLUSH	0x04000000	/* Buffer is being synced. */

/*
 * These flags are kept in b_oflags (owned by associated object).
 */
#define	BO_DELWRI	0x00000080	/* Delay I/O until buffer reused. */
#define	BO_DONE		0x00000200	/* I/O completed. */

/*
 * These flags are kept in b_flags (owned by buffer holder).
 */
#define	B_WRITE		0x00000000	/* Write buffer (pseudo flag). */
#define	B_ASYNC		0x00000004	/* Start I/O, do not wait. */
#define	B_COWDONE	0x00000400	/* Copy-on-write already done. */
#define	B_GATHERED	0x00001000	/* LFS: already in a segment. */
#define	B_LOCKED	0x00004000	/* Locked in core (not reusable). */
#define	B_PHYS		0x00040000	/* I/O to user memory. */
#define	B_RAW		0x00080000	/* Set by physio for raw transfers. */
#define	B_READ		0x00100000	/* Read buffer. */
#define	B_DEVPRIVATE	0x02000000	/* Device driver private flag. */
#define	B_MEDIA_FUA	0x08000000	/* Set Force Unit Access for media. */
#define	B_MEDIA_DPO	0x10000000	/* Set Disable Page Out for media. */

#define BUF_FLAGBITS \
    "\20\1AGE\3ASYNC\4BAD\5BUSY\10DELWRI" \
    "\12DONE\13COWDONE\15GATHERED\16INVAL\17LOCKED\20NOCACHE" \
    "\23PHYS\24RAW\25READ\32DEVPRIVATE\33VFLUSH\34MEDIA_FUA\35MEDIA_DPO"

/* Avoid weird code due to B_WRITE being a "pseudo flag" */
#define BUF_ISREAD(bp)	(((bp)->b_flags & B_READ) == B_READ)
#define BUF_ISWRITE(bp)	(((bp)->b_flags & B_READ) == B_WRITE)

/* Media flags, to be passed for nested I/O */
#define B_MEDIA_FLAGS	(B_MEDIA_FUA|B_MEDIA_DPO)

/*
 * This structure describes a clustered I/O.  It is stored in the b_saveaddr
 * field of the buffer on which I/O is done.  At I/O completion, cluster
 * callback uses the structure to parcel I/O's to individual buffers, and
 * then free's this structure.
 */
struct cluster_save {
	long	bs_bcount;		/* Saved b_bcount. */
	long	bs_bufsize;		/* Saved b_bufsize. */
	void	*bs_saveaddr;		/* Saved b_addr. */
	int	bs_nchildren;		/* Number of associated buffers. */
	struct buf *bs_children;	/* List of associated buffers. */
};

/*
 * Zero out the buffer's data area.
 */
#define	clrbuf(bp)							\
do {									\
	memset((bp)->b_data, 0, (u_int)(bp)->b_bcount);			\
	(bp)->b_resid = 0;						\
} while (/* CONSTCOND */ 0)

/* Flags to low-level allocation routines. */
#define B_CLRBUF	0x01	/* Request allocated buffer be cleared. */
#define B_SYNC		0x02	/* Do all allocations synchronously. */
#define B_METAONLY	0x04	/* Return indirect block buffer. */
#define B_CONTIG	0x08	/* Allocate file contiguously. */

/* Flags to bread() and breadn(). */
#define B_MODIFY	0x01	/* Hint: caller might modify buffer */

#ifdef _KERNEL

#define	BIO_GETPRIO(bp)		((bp)->b_prio)
#define	BIO_SETPRIO(bp, prio)	(bp)->b_prio = (prio)
#define	BIO_COPYPRIO(bp1, bp2)	BIO_SETPRIO(bp1, BIO_GETPRIO(bp2))

#define	BPRIO_NPRIO		3
#define	BPRIO_TIMECRITICAL	2
#define	BPRIO_TIMELIMITED	1
#define	BPRIO_TIMENONCRITICAL	0
#define	BPRIO_DEFAULT		BPRIO_TIMELIMITED

__BEGIN_DECLS
/*
 * bufferio(9) ops
 */
void	biodone(buf_t *);
int	biowait(buf_t *);
buf_t	*getiobuf(struct vnode *, bool);
void	putiobuf(buf_t *);
void	nestiobuf_setup(buf_t *, buf_t *, int, size_t);
void	nestiobuf_done(buf_t *, int, int);

void	nestiobuf_iodone(buf_t *);
int	physio(void (*)(buf_t *), buf_t *, dev_t, int,
	       void (*)(buf_t *), struct uio *);

/*
 * buffercache(9) ops
 */
int	bread(struct vnode *, daddr_t, int, int, buf_t **);
int	breadn(struct vnode *, daddr_t, int, daddr_t *, int *, int,
	       int, buf_t **);
int	bwrite(buf_t *);
void	bawrite(buf_t *);
void	bdwrite(buf_t *);
buf_t	*getblk(struct vnode *, daddr_t, int, int, int);
buf_t	*geteblk(int);
buf_t	*incore(struct vnode *, daddr_t);
int	allocbuf(buf_t *, int, int);
void	brelsel(buf_t *, int);
void	brelse(buf_t *, int);
void	binvalbuf(struct vnode *, daddr_t);

/*
 * So-far indeterminate ops that might belong to either
 * bufferio(9) or buffercache(9).
 */
void	bremfree(buf_t *);
void	bufinit(void);
void	bufinit2(void);
void	minphys(buf_t *);
void	brelvp(buf_t *);
void	reassignbuf(buf_t *, struct vnode *);
void	bgetvp(struct vnode *, buf_t *);
u_long	buf_memcalc(void);
int	buf_drain(int);
int	buf_setvalimit(vsize_t);
#if defined(DDB) || defined(DEBUGPRINT)
void	vfs_buf_print(buf_t *, int, void (*)(const char *, ...)
    __printflike(1, 2));
#endif
void	buf_init(buf_t *);
void	buf_destroy(buf_t *);
int	bbusy(buf_t *, bool, int, kmutex_t *);
u_int	buf_nbuf(void);

void	biohist_init(void);

__END_DECLS
#endif /* _KERNEL */
#endif /* !_SYS_BUF_H_ */