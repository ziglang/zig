/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * include/linux/nfsd/export.h
 * 
 * Public declarations for NFS exports. The definitions for the
 * syscall interface are in nfsctl.h
 *
 * Copyright (C) 1995-1997 Olaf Kirch <okir@monad.swb.de>
 */

#ifndef NFSD_EXPORT_H
#define NFSD_EXPORT_H

# include <linux/types.h>

/*
 * Important limits for the exports stuff.
 */
#define NFSCLNT_IDMAX		1024
#define NFSCLNT_ADDRMAX		16
#define NFSCLNT_KEYMAX		32

/*
 * Export flags.
 *
 * Please update the expflags[] array in fs/nfsd/export.c when adding
 * a new flag.
 */
#define NFSEXP_READONLY		0x0001
#define NFSEXP_INSECURE_PORT	0x0002
#define NFSEXP_ROOTSQUASH	0x0004
#define NFSEXP_ALLSQUASH	0x0008
#define NFSEXP_ASYNC		0x0010
#define NFSEXP_GATHERED_WRITES	0x0020
#define NFSEXP_NOREADDIRPLUS    0x0040
#define NFSEXP_SECURITY_LABEL	0x0080
/* 0x100 currently unused */
#define NFSEXP_NOHIDE		0x0200
#define NFSEXP_NOSUBTREECHECK	0x0400
#define	NFSEXP_NOAUTHNLM	0x0800		/* Don't authenticate NLM requests - just trust */
#define NFSEXP_MSNFS		0x1000	/* do silly things that MS clients expect; no longer supported */
#define NFSEXP_FSID		0x2000
#define	NFSEXP_CROSSMOUNT	0x4000
#define	NFSEXP_NOACL		0x8000	/* reserved for possible ACL related use */
/*
 * The NFSEXP_V4ROOT flag causes the kernel to give access only to NFSv4
 * clients, and only to the single directory that is the root of the
 * export; further lookup and readdir operations are treated as if every
 * subdirectory was a mountpoint, and ignored if they are not themselves
 * exported.  This is used by nfsd and mountd to construct the NFSv4
 * pseudofilesystem, which provides access only to paths leading to each
 * exported filesystem.
 */
#define	NFSEXP_V4ROOT		0x10000
#define NFSEXP_PNFS		0x20000

/* All flags that we claim to support.  (Note we don't support NOACL.) */
#define NFSEXP_ALLFLAGS		0x3FEFF

/* The flags that may vary depending on security flavor: */
#define NFSEXP_SECINFO_FLAGS	(NFSEXP_READONLY | NFSEXP_ROOTSQUASH \
					| NFSEXP_ALLSQUASH \
					| NFSEXP_INSECURE_PORT)

/*
 * Transport layer security policies that are permitted to access
 * an export
 */
#define NFSEXP_XPRTSEC_NONE	0x0001
#define NFSEXP_XPRTSEC_TLS	0x0002
#define NFSEXP_XPRTSEC_MTLS	0x0004

#define NFSEXP_XPRTSEC_NUM	(3)

#define NFSEXP_XPRTSEC_ALL	(NFSEXP_XPRTSEC_NONE | \
				 NFSEXP_XPRTSEC_TLS | \
				 NFSEXP_XPRTSEC_MTLS)

#endif /* NFSD_EXPORT_H */