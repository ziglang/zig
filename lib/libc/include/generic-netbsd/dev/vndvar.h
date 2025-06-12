/*	$NetBSD: vndvar.h,v 1.38 2018/10/07 11:51:26 mlelstv Exp $	*/

/*-
 * Copyright (c) 1996, 1997, 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department.
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
 * from: Utah $Hdr: fdioctl.h 1.1 90/07/09$
 *
 *	@(#)vnioctl.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _SYS_DEV_VNDVAR_H_
#define _SYS_DEV_VNDVAR_H_

#include <sys/ioccom.h>
#include <sys/pool.h>

/*
 * Vnode disk pseudo-geometry information.
 */
struct vndgeom {
	u_int32_t	vng_secsize;	/* # bytes per sector */
	u_int32_t	vng_nsectors;	/* # data sectors per track */
	u_int32_t	vng_ntracks;	/* # tracks per cylinder */
	u_int32_t	vng_ncylinders;	/* # cylinders per unit */
};

/*
 * Ioctl definitions for file (vnode) disk pseudo-device.
 */
struct vnd_ioctl {
	char		*vnd_file;	/* pathname of file to mount */
	int		vnd_flags;	/* flags; see below */
	struct vndgeom	vnd_geom;	/* geometry to emulate */
	unsigned int	vnd_osize;	/* (returned) size of disk */
	uint64_t	vnd_size;	/* (returned) size of disk */
};

/* vnd_flags */
#define	VNDIOF_HASGEOM	0x01		/* use specified geometry */
#define	VNDIOF_READONLY	0x02		/* as read-only device */
#define	VNDIOF_FORCE	0x04		/* force close */
#define	VNDIOF_FILEIO	0x08		/* have to use read/write */
#define	VNDIOF_COMP	0x0400		/* must stay the same as VNF_COMP */

#ifdef _KERNEL

struct vnode;

/*
 * A vnode disk's state information.
 */
struct vnd_softc {
	device_t	 sc_dev;
	int		 sc_flags;	/* flags */
	uint64_t	 sc_size;	/* size of vnd */
	struct vnode	*sc_vp;		/* vnode */
	u_int		 sc_iosize;	/* smallest I/O size for backend */
	kauth_cred_t	 sc_cred;	/* credentials */
	int		 sc_maxactive;	/* max # of active requests */
	struct bufq_state *sc_tab;	/* transfer queue */
	int		 sc_pending;	/* number of pending transfers */
	int		 sc_active;	/* number of active transfers */
	struct disk	 sc_dkdev;	/* generic disk device info */
	struct vndgeom	 sc_geom;	/* virtual geometry */
	struct pool	 sc_vxpool;	/* vndxfer pool */
	struct pool	 sc_vbpool;	/* vndbuf pool */
	struct lwp 	*sc_kthread;	/* kernel thread */
	u_int32_t	 sc_comp_blksz;	/* precompressed block size */
	u_int32_t	 sc_comp_numoffs;/* count of compressed block offsets */
	u_int64_t	*sc_comp_offsets;/* file idx's to compressed blocks */
	unsigned char	*sc_comp_buff;	/* compressed data buffer */
	unsigned char	*sc_comp_decombuf;/* decompressed data buffer */
	int32_t		 sc_comp_buffblk;/*current decompressed block */
	z_stream	 sc_comp_stream;/* decompress descriptor */
};
#endif

/* sc_flags */
#define	VNF_INITED	0x001	/* unit has been initialized */
#define	VNF_WLABEL	0x002	/* label area is writable */
#define	VNF_LABELLING	0x004	/* unit is currently being labelled */
#define	VNF_WANTED	0x008	/* someone is waiting to obtain a lock */
#define	VNF_LOCKED	0x010	/* unit is locked */
#define	VNF_READONLY	0x020	/* unit is read-only */
#define	VNF_KLABEL	0x040	/* keep label on close */
#define	VNF_VLABEL	0x080	/* label is valid */
#define	VNF_KTHREAD	0x100	/* thread is running */
#define	VNF_VUNCONF	0x200	/* device is unconfiguring */
#define VNF_COMP	0x400	/* file is compressed */
#define VNF_CLEARING	0x800	/* unit is being torn down */
#define VNF_USE_VN_RDWR	0x1000	/* have to use vn_rdwr() */

/* structure of header in a compressed file */
struct vnd_comp_header {
	char preamble[128];
	u_int32_t block_size;
	u_int32_t num_blocks;
};

/*
 * A simple structure for describing which vnd units are in use.
 */

struct vnd_user {
	int		vnu_unit;	/* which vnd unit */
	dev_t		vnu_dev;	/* file is on this device... */
	ino_t		vnu_ino;	/* ...at this inode */
};

/*
 * Before you can use a unit, it must be configured with VNDIOCSET.
 * The configuration persists across opens and closes of the device;
 * an VNDIOCCLR must be used to reset a configuration.  An attempt to
 * VNDIOCSET an already active unit will return EBUSY.
 */
#define VNDIOCSET	_IOWR('F', 0, struct vnd_ioctl)	/* enable disk */
#define VNDIOCCLR	_IOW('F', 1, struct vnd_ioctl)	/* disable disk */
#define VNDIOCGET	_IOWR('F', 3, struct vnd_user)	/* get list */

#ifdef _KERNEL
/*
 * Everything else is kernel-private, mostly exported for compat/netbsd32.
 *
 * NetBSD 3.0 had a 32-bit value for vnu_ino.
 *
 * NetBSD 5.0 had a 32-bit value for vnu_dev, and vnd_size.
 */
struct vnd_user30 {
	int		vnu_unit;	/* which vnd unit */
	uint32_t	vnu_dev;	/* file is on this device... */
	uint32_t	vnu_ino;	/* ...at this inode */
};
#define VNDIOCGET30	_IOWR('F', 2, struct vnd_user30)	/* get list */

struct vnd_user50 {
	int		vnu_unit;	/* which vnd unit */
	uint32_t	vnu_dev;	/* file is on this device... */
	ino_t		vnu_ino;	/* ...at this inode */
};
#define VNDIOCGET50	_IOWR('F', 3, struct vnd_user50)	/* get list */

struct vnd_ioctl50 {
	char		*vnd_file;	/* pathname of file to mount */
	int		vnd_flags;	/* flags; see below */
	struct vndgeom	vnd_geom;	/* geometry to emulate */
	unsigned int	vnd_size;	/* (returned) size of disk */
};
#define VNDIOCSET50	_IOWR('F', 0, struct vnd_ioctl50)
#define VNDIOCCLR50	_IOW('F', 1, struct vnd_ioctl50)

#endif /* _KERNEL */

#endif /* _SYS_DEV_VNDVAR_H_ */