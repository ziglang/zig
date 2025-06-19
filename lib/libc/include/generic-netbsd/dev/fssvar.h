/*	$NetBSD: fssvar.h,v 1.32 2019/02/20 10:03:25 hannken Exp $	*/

/*-
 * Copyright (c) 2003, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Juergen Hannken-Illjes.
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

#ifndef _SYS_DEV_FSSVAR_H
#define _SYS_DEV_FSSVAR_H

#include <sys/ioccom.h>

#define FSS_UNCONFIG_ON_CLOSE	0x01	/* Unconfigure on last close */
#define FSS_UNLINK_ON_CREATE	0x02	/* Unlink backing store on create */

struct fss_set {
	char		*fss_mount;	/* Mount point of file system */
	char		*fss_bstore;	/* Path of backing store */
	blksize_t	fss_csize;	/* Preferred cluster size */
	int		fss_flags;	/* Initial flags */
};

struct fss_get {
	char		fsg_mount[MNAMELEN]; /* Mount point of file system */
	struct timeval	fsg_time;	/* Time this snapshot was taken */
	blksize_t	fsg_csize;	/* Current cluster size */
	blkcnt_t	fsg_mount_size;	/* # clusters on file system */
	blkcnt_t	fsg_bs_size;	/* # clusters on backing store */
};

#define FSSIOCSET	_IOW('F', 5, struct fss_set)	/* Configure */
#define FSSIOCGET	_IOR('F', 1, struct fss_get)	/* Status */
#define FSSIOCCLR	_IO('F', 2)			/* Unconfigure */
#define FSSIOFSET	_IOW('F', 3, int)		/* Set flags */
#define FSSIOFGET	_IOR('F', 4, int)		/* Get flags */
#ifdef _KERNEL
#include <compat/sys/time_types.h>

struct fss_set50 {
	char		*fss_mount;	/* Mount point of file system */
	char		*fss_bstore;	/* Path of backing store */
	blksize_t	fss_csize;	/* Preferred cluster size */
};

struct fss_get50 {
	char		fsg_mount[MNAMELEN]; /* Mount point of file system */
	struct timeval50 fsg_time;	/* Time this snapshot was taken */
	blksize_t	fsg_csize;	/* Current cluster size */
	blkcnt_t	fsg_mount_size;	/* # clusters on file system */
	blkcnt_t	fsg_bs_size;	/* # clusters on backing store */
};

#define FSSIOCSET50	_IOW('F', 0, struct fss_set50)	/* Old configure */
#define FSSIOCGET50	_IOR('F', 1, struct fss_get50)	/* Old Status */

#include <sys/bufq.h>

#define FSS_CLUSTER_MAX	(1<<24)		/* Upper bound of clusters. The
					   sc_copied map uses up to
					   FSS_CLUSTER_MAX/NBBY bytes */

/* Offset to cluster */
#define FSS_BTOCL(sc, off) \
	((off) >> (sc)->sc_clshift)

/* Cluster to offset */
#define FSS_CLTOB(sc, cl) \
	((off_t)(cl) << (sc)->sc_clshift)

/* Offset from start of cluster */
#define FSS_CLOFF(sc, off) \
	((off) & (sc)->sc_clmask)

/* Size of cluster */
#define FSS_CLSIZE(sc) \
	(1 << (sc)->sc_clshift)

/* Offset to backing store block */
#define FSS_BTOFSB(sc, off) \
	((off) >> (sc)->sc_bs_bshift)

/* Backing store block to offset */
#define FSS_FSBTOB(sc, blk) \
	((off_t)(blk) << (sc)->sc_bs_bshift)

/* Offset from start of backing store block */
#define FSS_FSBOFF(sc, off) \
	((off) & (sc)->sc_bs_bmask)

/* Size of backing store block */
#define FSS_FSBSIZE(sc) \
	(1 << (sc)->sc_bs_bshift)

typedef enum {
	FSS_READ,
	FSS_WRITE
} fss_io_type;

typedef enum {
	FSS_CACHE_FREE	= 0,		/* Cache entry is free */
	FSS_CACHE_BUSY	= 1,		/* Cache entry is read from device */
	FSS_CACHE_VALID	= 2		/* Cache entry contains valid data */
} fss_cache_type;

struct fss_cache {
	fss_cache_type	fc_type;	/* Current state */
	u_int32_t	fc_cluster;	/* Cluster number of this entry */
	kcondvar_t	fc_state_cv;	/* Signals state change from busy */
	void *		fc_data;	/* Data */
};

typedef enum {
	FSS_IDLE,			/* Device is unconfigured */
	FSS_CREATING,			/* Device is currently configuring */
	FSS_ACTIVE,			/* Device is configured */
	FSS_DESTROYING			/* Device is currently unconfiguring */
} fss_state_t;

struct fss_softc {
	device_t	sc_dev;		/* Self */
	kmutex_t	sc_slock;	/* Protect this softc */
	kcondvar_t	sc_work_cv;	/* Signals work for the kernel thread */
	kcondvar_t	sc_cache_cv;	/* Signals free cache slot */
	fss_state_t	sc_state;	/* Current state */
	volatile int	sc_flags;	/* Flags */
#define FSS_ERROR	0x01		/* Device had errors. */
#define FSS_BS_THREAD	0x04		/* Kernel thread is running */
#define FSS_PERSISTENT	0x20		/* File system internal snapshot */
#define FSS_CDEV_OPEN	0x40		/* character device open */
#define FSS_BDEV_OPEN	0x80		/* block device open */
	int		sc_uflags;	/* User visible flags */
	struct disk	*sc_dkdev;	/* Generic disk device info */
	struct mount	*sc_mount;	/* Mount point */
	char		sc_mntname[MNAMELEN]; /* Mount point */
	struct timeval	sc_time;	/* Time this snapshot was taken */
	dev_t		sc_bdev;	/* Underlying block device */
	struct vnode	*sc_bs_vp;	/* Our backing store */
	int		sc_bs_bshift;	/* Shift of backing store block */
	u_int32_t	sc_bs_bmask;	/* Mask of backing store block */
	struct lwp	*sc_bs_lwp;	/* Our kernel thread */
	int		sc_clshift;	/* Shift of cluster size */
	u_int32_t	sc_clmask;	/* Mask of cluster size */
	u_int32_t	sc_clcount;	/* # clusters in file system */
	u_int8_t	*sc_copied;	/* Map of clusters already copied */
	long		sc_clresid;	/* Bytes in last cluster */
	int		sc_cache_size;	/* Number of entries in sc_cache */
	struct fss_cache *sc_cache;	/* Cluster cache */
	struct bufq_state *sc_bufq;	/* Transfer queue */
	u_int32_t	sc_clnext;	/* Next free cluster on backing store */
	int		sc_indir_size;	/* # clusters for indirect mapping */
	u_int8_t	*sc_indir_valid; /* Map of valid indirect clusters */
	u_int32_t	sc_indir_cur;	/* Current indir cluster number */
	int		sc_indir_dirty;	/* Current indir cluster modified */
	u_int32_t	*sc_indir_data;	/* Current indir cluster data */
};

#endif /* _KERNEL */

#endif /* !_SYS_DEV_FSSVAR_H */