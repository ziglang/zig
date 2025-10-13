/*	$NetBSD: xdr_subs.h,v 1.15 2005/12/11 12:25:17 christos Exp $	*/

/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Rick Macklem at The University of Guelph.
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
 *	@(#)xdr_subs.h	8.3 (Berkeley) 3/30/95
 */


#ifndef _NFS_XDR_SUBS_H_
#define _NFS_XDR_SUBS_H_

/*
 * Macros used for conversion to/from xdr representation by nfs...
 * These use the MACHINE DEPENDENT routines ntohl, htonl
 * As defined by "XDR: External Data Representation Standard" RFC1014
 *
 * To simplify the implementation, we use ntohl/htonl even on big-endian
 * machines, and count on them being `#define'd away.  Some of these
 * might be slightly more efficient as quad_t copies on a big-endian,
 * but we cannot count on their alignment anyway.
 */

#define	fxdr_unsigned(t, v)	((t)ntohl((int32_t)(v)))
#define	txdr_unsigned(v)	(htonl((int32_t)(v)))

/*
 * Directory cookies shouldn't really be XDR-ed, these functions
 * are just here to attempt to keep information within 32 bits. And
 * make things look better. See nfs_cookieheuristic.
 */
#define fxdr_cookie3(v) (((off_t)((v)[0]) << 32) | ((off_t) (v)[1]))
#define fxdr_swapcookie3(v) (((off_t)((v)[1]) << 32) | ((off_t) (v)[0]))

#define txdr_cookie3(f, v) { \
	(v)[1] = (u_int32_t)((f) & 0xffffffffLL); \
	(v)[0] = (u_int32_t)((f) >> 32); \
}
#define txdr_swapcookie3(f, v) { \
	(v)[0] = (u_int32_t)((f) & 0xffffffffLL); \
	(v)[1] = (u_int32_t)((f) >> 32); \
}

#define	fxdr_nfsv2time(f, t) { \
	(t)->tv_sec = ntohl(((struct nfsv2_time *)(f))->nfsv2_sec); \
	if (((struct nfsv2_time *)(f))->nfsv2_usec != 0xffffffff) \
		(t)->tv_nsec = 1000 * ntohl(((struct nfsv2_time *)(f))->nfsv2_usec); \
	else \
		(t)->tv_nsec = 0; \
}
#define	txdr_nfsv2time(f, t) { \
	((struct nfsv2_time *)(t))->nfsv2_sec = htonl((f)->tv_sec); \
	if ((f)->tv_nsec != -1) \
		((struct nfsv2_time *)(t))->nfsv2_usec = htonl((f)->tv_nsec / 1000); \
	else \
		((struct nfsv2_time *)(t))->nfsv2_usec = 0xffffffff; \
}

#define	fxdr_nfsv3time(f, t) { \
	(t)->tv_sec = ntohl(((struct nfsv3_time *)(f))->nfsv3_sec); \
	(t)->tv_nsec = ntohl(((struct nfsv3_time *)(f))->nfsv3_nsec); \
}
#define	txdr_nfsv3time(f, t) { \
	((struct nfsv3_time *)(t))->nfsv3_sec = htonl((f)->tv_sec); \
	((struct nfsv3_time *)(t))->nfsv3_nsec = htonl((f)->tv_nsec); \
}

#define	fxdr_hyper(f) 						\
        ((((u_quad_t)ntohl(((u_int32_t *)(f))[0])) << 32) |	\
	 (u_quad_t)(ntohl(((u_int32_t *)(f))[1])))


#define	txdr_hyper(f, t) {						\
	((u_int32_t *)(t))[0] = htonl((u_int32_t)((f) >> 32));		\
	((u_int32_t *)(t))[1] = htonl((u_int32_t)((f) & 0xffffffff));	\
}

#endif