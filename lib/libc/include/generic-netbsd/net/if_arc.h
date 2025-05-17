/*	$NetBSD: if_arc.h,v 1.23 2017/10/23 09:22:24 msaitoh Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 * from: NetBSD: if_ether.h,v 1.10 1994/06/29 06:37:55 cgd Exp
 *       @(#)if_ether.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NET_IF_ARC_H_
#define _NET_IF_ARC_H_

/*
 * Arcnet address - 1 octets
 * don't know who uses this.
 */
struct arc_addr {
	uint8_t  arc_addr_octet[1];
} __packed;

/*
 * Structure of a 2.5MB/s Arcnet header.
 * as given to interface code.
 */
struct	arc_header {
	uint8_t  arc_shost;
	uint8_t  arc_dhost;
	uint8_t  arc_type;
	/*
	 * only present for newstyle encoding with LL fragmentation.
	 * Don't use sizeof(anything), use ARC_HDR{,NEW}LEN instead.
	 */
	uint8_t  arc_flag;
	uint16_t arc_seqid;

	/*
	 * only present in exception packets (arc_flag == 0xff)
	 */
	uint8_t  arc_type2;	/* same as arc_type */
	uint8_t  arc_flag2;	/* real flag value */
	uint16_t arc_seqid2;	/* real seqid value */
} __packed;

#define	ARC_ADDR_LEN		1

#define	ARC_HDRLEN		3
#define	ARC_HDRNEWLEN		6
#define	ARC_HDRNEWLEN_EXC	10

/* these lengths are data link layer length - 2*ARC_ADDR_LEN */
#define	ARC_MIN_LEN		1
#define	ARC_MIN_FORBID_LEN	254
#define	ARC_MAX_FORBID_LEN	256
#define	ARC_MAX_LEN		508


/* RFC 1051 */
#define	ARCTYPE_IP_OLD		240	/* IP protocol */
#define	ARCTYPE_ARP_OLD		241	/* address resolution protocol */

/* RFC 1201 */
#define	ARCTYPE_IP		212	/* IP protocol */
#define	ARCTYPE_ARP		213	/* address resolution protocol */
#define	ARCTYPE_REVARP		214	/* reverse addr resolution protocol */

#define	ARCTYPE_ATALK		221	/* Appletalk */
#define	ARCTYPE_BANIAN		247	/* Banyan Vines */
#define	ARCTYPE_IPX		250	/* Novell IPX */

#define ARCTYPE_INET6		0xc4	/* IPng */
#define ARCTYPE_DIAGNOSE	0x80	/* as per ANSI/ATA 878.1 */

#define	ARCMTU			507
#define	ARCMIN			0

#define ARC_PHDS_MAXMTU		60480

struct	arccom {
	struct 	  ifnet ac_if;		/* network-visible interface */

	uint16_t ac_seqid;		/* seq. id used by PHDS encap. */

	struct ac_frag {
		uint8_t  af_maxflag;	/* from first packet */
		uint8_t  af_lastseen;	/* last split flag seen */
		uint16_t af_seqid;
		struct mbuf *af_packet;
	} ac_fragtab[256];		/* indexed by sender ll address */

};

#ifdef _KERNEL
extern uint8_t arcbroadcastaddr;
extern int arc_ipmtu;	/* XXX new ip only, no RFC 1051! */

int	arc_ifattach(struct ifnet *, uint8_t);
char	*arc_sprintf(uint8_t *);
int	arc_isphds(uint8_t);
#endif

#endif /* !_NET_IF_ARC_H_ */