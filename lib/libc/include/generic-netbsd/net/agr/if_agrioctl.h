/*	$NetBSD: if_agrioctl.h,v 1.2 2005/12/10 23:21:39 elad Exp $	*/

/*-
 * Copyright (c)2005 YAMAMOTO Takashi,
 * All rights reserved.
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
 */

#ifndef _NET_AGR_IF_AGRIOCTL_H_
#define	_NET_AGR_IF_AGRIOCTL_H_

/*
 * kernel-userland interface for agr(4) driver.
 *
 * it's only file exported to userland in this driver.
 */

struct agrreq {
	int ar_version; /* AGRREQ_VERSION */
	int ar_cmd;
	void *ar_buf;
	size_t ar_buflen;
};

#define	AGRREQ_VERSION	2

/* ar_cmd (SIOCSETAGR) */
#define	AGRCMD_ADDPORT	1
#define	AGRCMD_REMPORT	2

#define	SIOCSETAGR	SIOCSIFGENERIC

/* ar_cmd (SIOCGETAGR) */
#define	AGRCMD_PORTLIST	3	/* ar_buf points agrportlist */

#define	SIOCGETAGR	SIOCGIFGENERIC

struct agrportinfo {
	char api_ifname[IFNAMSIZ];
	int api_flags; /* AGRPORTINFO_ */
};
#define	AGRPORTINFO_COLLECTING		1
#define	AGRPORTINFO_DISTRIBUTING	2
#define	AGRPORTINFO_BITS \
	"\177\020" \
	"b\0COLLECTING\0" \
	"b\0DISTRIBUTING\0"

struct agrportlist {
	int apl_nports;
	/* struct agrportinfo apl_ports[]; */
};

#endif /* !_NET_AGR_IF_AGRIOCTL_H_ */