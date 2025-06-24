/*	$NetBSD: nfsrtt.h,v 1.10 2014/09/05 05:34:41 matt Exp $	*/

/*
 * Copyright (c) 1992, 1993
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
 *	@(#)nfsrtt.h	8.2 (Berkeley) 3/30/95
 */


#ifndef _NFS_NFSRTT_H_
#define _NFS_NFSRTT_H_

/*
 * Definitions for performance monitor.
 * The client and server logging are turned on by setting the global
 * constant "nfsrtton" to 1.
 */
#define	NFSRTTLOGSIZ	128

/*
 * Circular log of client side rpc activity. Each log entry is for one
 * rpc filled in upon completion. (ie. in order of completion)
 * The "pos" is the table index for the "next" entry, therefore the
 * list goes from nfsrtt.rttl[pos] --> nfsrtt.rttl[pos - 1] in
 * chronological order of completion.
 */
struct rttl {
	u_int32_t	proc;			/* NFS procedure number */
	int		rtt;			/* Measured round trip time */
	int		rto;			/* Round Trip Timeout */
	int		sent;			/* # rpcs in progress */
	int		cwnd;			/* Send window */
	int		srtt;			/* Ave Round Trip Time */
	int		sdrtt;			/* Ave mean deviation of RTT */
	fsid_t		fsid;			/* Fsid for mount point */
	struct timeval	tstamp;			/* Timestamp of log entry */
};

struct nfsrtt {
	int pos;			/* Position in array for next entry */
	struct rttl rttl[NFSRTTLOGSIZ];
};

/*
 * And definitions for server side performance monitor.
 * The log organization is the same as above except it is filled in at the
 * time the server sends the rpc reply.
 */

/*
 * Bits for the flags field.
 */
#define	DRT_TCP		0x02	/* Client used TCP transport */
#define	DRT_CACHEREPLY	0x04	/* Reply was from recent request cache */
#define	DRT_CACHEDROP	0x08	/* Rpc request dropped, due to recent reply */
#define DRT_NFSV3	0x10	/* Rpc used NFS Version 3 */

/*
 * Server log structure
 * NB: ipadr == INADDR_ANY indicates a client using a non IP protocol.
 *	(ISO perhaps?)
 */
struct nfsdrt {
	int pos;			/* Position of next log entry */
	struct drt {
		int       flag;		/* Bits as defined above */
		u_int32_t proc;		/* NFS procedure number */
		u_int32_t ipadr;	/* IP address of client */
		int       resptime;	/* Response time (usec) */
		struct timeval tstamp;	/* Timestamp of log entry */
	} drt[NFSRTTLOGSIZ];
};

#ifdef _KERNEL
extern int nfsrtton;
#endif

#endif