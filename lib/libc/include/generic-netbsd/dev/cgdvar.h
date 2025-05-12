/* $NetBSD: cgdvar.h,v 1.21 2020/06/13 22:15:58 riastradh Exp $ */

/*-
 * Copyright (c) 2002 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Roland C. Dowdeswell.
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

#ifndef _DEV_CGDVAR_H_
#define	_DEV_CGDVAR_H_

#include <sys/ioccom.h>

/* ioctl(2) code: used by CGDIOCSET and CGDIOCCLR */
struct cgd_ioctl {
	const char	*ci_disk;
	int		 ci_flags;
	int		 ci_unit;
	size_t		 ci_size;
	const char	*ci_alg;
	const char	*ci_ivmethod;
	size_t		 ci_keylen;
	const char	*ci_key;
	size_t		 ci_blocksize;
};

/* ioctl(2) code: used by CGDIOCGET */
struct cgd_user {
	int		cgu_unit;	/* which cgd unit */
	dev_t		cgu_dev;	/* target device */
	char		cgu_alg[32];	/* algorithm name */
	size_t		cgu_blocksize;	/* block size (in bytes) */
	int		cgu_mode;	/* Cipher Mode and IV Gen method */
#define CGD_CIPHER_CBC_ENCBLKNO8 1	/* CBC Mode w/ Enc Block Number
					 * 8 passes (compat only)
					 */
#define CGD_CIPHER_CBC_ENCBLKNO1 2	/* CBC Mode w/ Enc Block Number
					 * 1 pass (default)
					 */
	int		cgu_keylen;	/* keylength */
};

#ifdef _KERNEL

#include <dev/cgd_crypto.h>
#include <dev/dkvar.h>

/* This cryptdata structure is here rather than cgd_crypto.h, since
 * it stores local state which will not be generalised beyond the
 * cgd driver.
 */

struct cryptdata {
	size_t		 cf_blocksize;	/* block size (in bytes) */
	int		 cf_keylen;	/* key length */
	int		 cf_mode;	/* Cipher Mode and IV Gen method
					 * (see cgu_mode above for defines) */
	void		*cf_priv;	/* enc alg private data */
};

struct cgd_xfer {
	struct work		 cx_work;
	struct cgd_softc	*cx_sc;
	struct buf		*cx_obp;
	struct buf		*cx_nbp;
	void			*cx_dstv;
	const void		*cx_srcv;
	size_t			 cx_len;
	daddr_t			 cx_blkno;
	size_t			 cx_secsize;
	int			 cx_dir;
};

struct cgd_worker {
	struct workqueue	*cw_wq;		/* work queue */
	struct pool		*cw_cpool;	/* cgd_xfer contexts */
	u_int		 	 cw_busy;	/* number of busy contexts */
	u_int			 cw_last;	/* index of last CPU used */
	kmutex_t		 cw_lock;
};

struct cgd_softc {
	struct dk_softc		 sc_dksc;	/* generic disk interface */
	struct vnode		*sc_tvn;	/* target device's vnode */
	dev_t			 sc_tdev;	/* target device */
	char			*sc_tpath;	/* target device's path */
	void			*sc_data;	/* emergency buffer */
	bool			 sc_data_used;	/* Really lame, we'll change */
	size_t			 sc_tpathlen;	/* length of prior string */
	struct cryptdata	 sc_cdata;	/* crypto data */
	const struct cryptfuncs	*sc_cfuncs;	/* encryption functions */
	kmutex_t		 sc_lock;
	kcondvar_t		 sc_cv;
	bool			 sc_busy;
	struct cgd_worker	*sc_worker;	/* shared worker data */
};
#endif

/* XXX XAX XXX elric:  check these out properly. */
#define CGDIOCSET	_IOWR('F', 18, struct cgd_ioctl)
#define CGDIOCCLR	_IOW('F', 19, struct cgd_ioctl)
#define CGDIOCGET	_IOWR('F', 20, struct cgd_user)

/* Maximum block sized to be used by the ciphers */
#define CGD_MAXBLOCKSIZE	128

#endif /* _DEV_CGDVAR_H_ */