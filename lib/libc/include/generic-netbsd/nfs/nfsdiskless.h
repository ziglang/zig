/*	$NetBSD: nfsdiskless.h,v 1.32 2015/05/21 02:04:22 rtr Exp $	*/

/*-
 * Copyright (c) 1995, 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Adam Glass and Gordon W. Ross.
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
 *
 *	@(#)nfsdiskless.h	8.1 (Berkeley) 6/10/93
 */
#ifndef _NFS_NFSDISKLESS_H_
#define _NFS_NFSDISKLESS_H_

/*
 * Structure holds parameters needed by nfs_mountroot(),
 * which are filled in by nfs_boot_init() using either
 * BOOTP (RFC951, RFC1048) or Sun RPC/bootparams.  These
 * parameters are INET specific because nfs_boot_init()
 * currently supports only AF_INET protocols.
 *
 * NB: All fields are stored in net byte order to avoid hassles
 * with client/server byte ordering differences.
 */
struct nfs_dlmount {
	struct nfs_args ndm_args;
	struct sockaddr ndm_saddr;  		/* Address of file server */
	char		ndm_host[MNAMELEN]; 	/* server:pathname */
	u_char		ndm_fh[NFSX_V3FHMAX]; 	/* The file's file handle */
};
struct nfs_diskless {
	/* the interface used */
	struct ifnet *nd_ifp;
	/* A collection of IP addresses, for convenience. */
	struct in_addr nd_myip; /* My IP address */
	struct in_addr nd_mask; /* My netmask */
	struct in_addr nd_gwip; /* My gateway */
	int nd_mtu;		/* Interface MTU */
	/* Information for each mount point we need. */
	struct nfs_dlmount nd_root; 	/* Mount info for root */
#ifdef TFTPROOT
	char nd_bootfile[MNAMELEN];	/* Boot file */
	int nd_nomount;
#endif
};

#ifdef _KERNEL
int nfs_boot_init (struct nfs_diskless *, struct lwp *);
void nfs_boot_cleanup (struct nfs_diskless *, struct lwp *);
int nfs_boot_ifupdown (struct ifnet *, struct lwp *, int);
int nfs_boot_setaddress (struct ifnet *, struct lwp *,
			     uint32_t, uint32_t, uint32_t);
void nfs_boot_setmtu (struct ifnet *, int, struct lwp *);
int nfs_boot_deladdress (struct ifnet *, struct lwp *, uint32_t);
void nfs_boot_flushrt (struct ifnet *);
int nfs_boot_setrecvtimo (struct socket *);
int nfs_boot_enbroadcast (struct socket *);
int nfs_boot_sobind_ipport (struct socket *, uint16_t, struct lwp *);
int nfs_boot_sendrecv (struct socket *, struct sockaddr_in *,
			   int (*)(struct mbuf*, void*, int), struct mbuf*,
			   int (*)(struct mbuf**, void*), struct mbuf**,
			   struct mbuf**, void*, struct lwp *);

int nfs_bootdhcp  (struct nfs_diskless *, struct lwp *, int *);
int nfs_bootparam (struct nfs_diskless *, struct lwp *, int *);
int nfs_bootstatic (struct nfs_diskless *, struct lwp *, int *);

extern int (*nfs_bootstatic_callback)(struct nfs_diskless *);

#define NFS_BOOT_HAS_MYIP	0x01
#define NFS_BOOT_HAS_GWIP	0x02
#define NFS_BOOT_HAS_MASK	0x04
#define NFS_BOOT_HAS_SERVADDR	0x08
#define NFS_BOOT_HAS_SERVER	0x10
#define NFS_BOOT_NOSTATIC	0x20
#define NFS_BOOT_HAS_ROOTPATH	0x40

#define NFS_BOOT_ALLINFO	(NFS_BOOT_HAS_MYIP|NFS_BOOT_HAS_GWIP|NFS_BOOT_HAS_MASK|NFS_BOOT_HAS_SERVADDR|NFS_BOOT_HAS_SERVER|NFS_BOOT_HAS_ROOTPATH)

#endif /* _KERNEL */

#endif /* _NFS_NFSDISKLESS_H_ */