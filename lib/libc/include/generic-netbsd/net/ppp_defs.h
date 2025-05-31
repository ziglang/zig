/*	$NetBSD: ppp_defs.h,v 1.14 2020/04/04 19:46:01 is Exp $	*/
/*	Id: ppp_defs.h,v 1.11 1997/04/30 05:46:24 paulus Exp 	*/

/*
 * ppp_defs.h - PPP definitions.
 *
 * Copyright (c) 1989-2002 Paul Mackerras. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The name(s) of the authors of this software must not be used to
 *    endorse or promote products derived from this software without
 *    prior written permission.
 *
 * 4. Redistributions of any form whatsoever must retain the following
 *    acknowledgment:
 *    "This product includes software developed by Paul Mackerras
 *     <paulus@samba.org>".
 *
 * THE AUTHORS OF THIS SOFTWARE DISCLAIM ALL WARRANTIES WITH REGARD TO
 * THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS, IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
 * SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef _NET_PPP_DEFS_H_
#define _NET_PPP_DEFS_H_

/*
 * The basic PPP frame.
 */
#define PPP_HDRLEN	4	/* octets for standard ppp header */
#define PPP_FCSLEN	2	/* octets for FCS */

/*
 * Packet sizes
 *
 * Note - lcp shouldn't be allowed to negotiate stuff outside these
 *	  limits.  See lcp.h in the pppd directory.
 * (XXX - these constants should simply be shared by lcp.c instead
 *	  of living in lcp.h)
 */
#define	PPP_MTU		1500	/* Default MTU (size of Info field) */
#define PPP_MAXMTU	65535 - (PPP_HDRLEN + PPP_FCSLEN)
#define PPP_MINMTU	64
#define PPP_MRU		1500	/* default MRU = max length of info field */
#define PPP_MAXMRU	65000	/* Largest MRU we allow */
#define PPP_MINMRU	128

#define PPP_ADDRESS(p)	(((const u_char *)(p))[0])
#define PPP_CONTROL(p)	(((const u_char *)(p))[1])
#define PPP_PROTOCOL(p)	\
    ((((const u_char *)(p))[2] << 8) + ((const u_char *)(p))[3])

/*
 * Significant octet values.
 */
#define	PPP_ALLSTATIONS	0xff	/* All-Stations broadcast address */
#define	PPP_UI		0x03	/* Unnumbered Information */
#define	PPP_FLAG	0x7e	/* Flag Sequence */
#define	PPP_ESCAPE	0x7d	/* Asynchronous Control Escape */
#define	PPP_TRANS	0x20	/* Asynchronous transparency modifier */

/*
 * Protocol field values.
 */
#define PPP_IP		0x0021		/* Internet Protocol */
#define PPP_ISO		0x0023		/* ISO OSI Protocol */
#define PPP_XNS		0x0025		/* Xerox NS Protocol */
#define PPP_AT		0x0029		/* AppleTalk Protocol */
#define PPP_IPX		0x002b		/* IPX protocol */
#define	PPP_VJC_COMP	0x002d		/* VJ compressed TCP */
#define	PPP_VJC_UNCOMP	0x002f		/* VJ uncompressed TCP */
#define PPP_MP		0x003d		/* Multilink PPP Fragment */
#define PPP_IPV6	0x0057		/* Internet Protocol Version 6 */
#define PPP_COMP	0x00fd		/* compressed packet */
#define PPP_IPCP	0x8021		/* IP Control Protocol */
#define PPP_ATCP	0x8029		/* AppleTalk Control Protocol */
#define PPP_IPXCP	0x802b		/* IPX Control Protocol */
#define PPP_IPV6CP	0x8057		/* IPv6 Control Protocol */
#define PPP_CCP		0x80fd		/* Compression Control Protocol */
#define PPP_ECP		0x8053		/* Encryption Control Protocol */
#define PPP_LCP		0xc021		/* Link Control Protocol */
#define PPP_PAP		0xc023		/* Password Authentication Protocol */
#define PPP_LQR		0xc025		/* Link Quality Report protocol */
#define PPP_CHAP	0xc223		/* Crypto Handshake Auth. Protocol */
#define PPP_CBCP	0xc029		/* Callback Control Protocol */
#define PPP_EAP		0xc227		/* Extensible Authentication Protocol */

/*
 * Values for FCS calculations.
 */
#define PPP_INITFCS	0xffff	/* Initial FCS value */
#define PPP_GOODFCS	0xf0b8	/* Good final FCS value */
#define PPP_FCS(fcs, c)	(((fcs) >> 8) ^ fcstab[((fcs) ^ (c)) & 0xff])

/*
 * Extended asyncmap - allows any character to be escaped.
 */
typedef uint32_t	ext_accm[8];

/*
 * What to do with network protocol (NP) packets.
 */
enum NPmode {
    NPMODE_PASS,		/* pass the packet through */
    NPMODE_DROP,		/* silently drop the packet */
    NPMODE_ERROR,		/* return an error */
    NPMODE_QUEUE		/* save it up for later. */
};

/*
 * Statistics.
 */
struct pppstat	{
    unsigned int ppp_ibytes;	/* bytes received */
    unsigned int ppp_ipackets;	/* packets received */
    unsigned int ppp_ierrors;	/* receive errors */
    unsigned int ppp_obytes;	/* bytes sent */
    unsigned int ppp_opackets;	/* packets sent */
    unsigned int ppp_oerrors;	/* transmit errors */
};

struct vjstat {
    unsigned int vjs_packets;	/* outbound packets */
    unsigned int vjs_compressed; /* outbound compressed packets */
    unsigned int vjs_searches;	/* searches for connection state */
    unsigned int vjs_misses;	/* times couldn't find conn. state */
    unsigned int vjs_uncompressedin; /* inbound uncompressed packets */
    unsigned int vjs_compressedin; /* inbound compressed packets */
    unsigned int vjs_errorin;	/* inbound unknown type packets */
    unsigned int vjs_tossed;	/* inbound packets tossed because of error */
};

struct ppp_stats {
    struct pppstat p;		/* basic PPP statistics */
    struct vjstat vj;		/* VJ header compression statistics */
};

struct compstat {
    unsigned int unc_bytes;	/* total uncompressed bytes */
    unsigned int unc_packets;	/* total uncompressed packets */
    unsigned int comp_bytes;	/* compressed bytes */
    unsigned int comp_packets;	/* compressed packets */
    unsigned int inc_bytes;	/* incompressible bytes */
    unsigned int inc_packets;	/* incompressible packets */
    unsigned int ratio;		/* recent compression ratio << 8 */
};

struct ppp_comp_stats {
    struct compstat c;		/* packet compression statistics */
    struct compstat d;		/* packet decompression statistics */
};

/*
 * The following structure records the time in seconds since
 * the last NP packet was sent or received.
 */
struct ppp_idle {
    time_t xmit_idle;		/* time since last NP packet sent */
    time_t recv_idle;		/* time since last NP packet received */
};

#endif /* !_NET_PPP_DEFS_H_ */