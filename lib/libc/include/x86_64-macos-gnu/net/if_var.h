/*
 * Copyright (c) 2000-2019 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1982, 1986, 1989, 1993
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	From: @(#)if.h	8.1 (Berkeley) 6/10/93
 * $FreeBSD: src/sys/net/if_var.h,v 1.18.2.7 2001/07/24 19:10:18 brooks Exp $
 */

#ifndef _NET_IF_VAR_H_
#define _NET_IF_VAR_H_

#include <sys/appleapiopts.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/queue.h>          /* get TAILQ macros */
#ifdef BSD_KERN_PRIVATE
#include <sys/eventhandler.h>
#endif


#ifdef __APPLE__
#define APPLE_IF_FAM_LOOPBACK  1
#define APPLE_IF_FAM_ETHERNET  2
#define APPLE_IF_FAM_SLIP      3
#define APPLE_IF_FAM_TUN       4
#define APPLE_IF_FAM_VLAN      5
#define APPLE_IF_FAM_PPP       6
#define APPLE_IF_FAM_PVC       7
#define APPLE_IF_FAM_DISC      8
#define APPLE_IF_FAM_MDECAP    9
#define APPLE_IF_FAM_GIF       10
#define APPLE_IF_FAM_FAITH     11       /* deprecated */
#define APPLE_IF_FAM_STF       12
#define APPLE_IF_FAM_FIREWIRE  13
#define APPLE_IF_FAM_BOND      14
#define APPLE_IF_FAM_CELLULAR  15
#define APPLE_IF_FAM_6LOWPAN   16
#define APPLE_IF_FAM_UTUN      17
#define APPLE_IF_FAM_IPSEC     18
#endif /* __APPLE__ */

/*
 * 72 was chosen below because it is the size of a TCP/IP
 * header (40) + the minimum mss (32).
 */
#define IF_MINMTU       72
#define IF_MAXMTU       65535

/*
 * Structures defining a network interface, providing a packet
 * transport mechanism (ala level 0 of the PUP protocols).
 *
 * Each interface accepts output datagrams of a specified maximum
 * length, and provides higher level routines with input datagrams
 * received from its medium.
 *
 * Output occurs when the routine if_output is called, with three parameters:
 *	(*ifp->if_output)(ifp, m, dst, rt)
 * Here m is the mbuf chain to be sent and dst is the destination address.
 * The output routine encapsulates the supplied datagram if necessary,
 * and then transmits it on its medium.
 *
 * On input, each interface unwraps the data received by it, and either
 * places it on the input queue of a internetwork datagram routine
 * and posts the associated software interrupt, or passes the datagram to a raw
 * packet input routine.
 *
 * Routines exist for locating interfaces by their addresses
 * or for locating a interface on a certain network, as well as more general
 * routing and gateway routines maintaining information used to locate
 * interfaces.  These routines live in the files if.c and route.c
 */

#define IFNAMSIZ        16

/* This belongs up in socket.h or socketvar.h, depending on how far the
 *   event bubbles up.
 */

struct net_event_data {
	u_int32_t       if_family;
	u_int32_t       if_unit;
	char            if_name[IFNAMSIZ];
};

#if defined(__LP64__)
#include <sys/_types/_timeval32.h>
#define IF_DATA_TIMEVAL timeval32
#else
#define IF_DATA_TIMEVAL timeval
#endif

#pragma pack(4)

/*
 * Structure describing information about an interface
 * which may be of interest to management entities.
 */
struct if_data {
	/* generic interface information */
	u_char          ifi_type;       /* ethernet, tokenring, etc */
	u_char          ifi_typelen;    /* Length of frame type id */
	u_char          ifi_physical;   /* e.g., AUI, Thinnet, 10base-T, etc */
	u_char          ifi_addrlen;    /* media address length */
	u_char          ifi_hdrlen;     /* media header length */
	u_char          ifi_recvquota;  /* polling quota for receive intrs */
	u_char          ifi_xmitquota;  /* polling quota for xmit intrs */
	u_char          ifi_unused1;    /* for future use */
	u_int32_t       ifi_mtu;        /* maximum transmission unit */
	u_int32_t       ifi_metric;     /* routing metric (external only) */
	u_int32_t       ifi_baudrate;   /* linespeed */
	/* volatile statistics */
	u_int32_t       ifi_ipackets;   /* packets received on interface */
	u_int32_t       ifi_ierrors;    /* input errors on interface */
	u_int32_t       ifi_opackets;   /* packets sent on interface */
	u_int32_t       ifi_oerrors;    /* output errors on interface */
	u_int32_t       ifi_collisions; /* collisions on csma interfaces */
	u_int32_t       ifi_ibytes;     /* total number of octets received */
	u_int32_t       ifi_obytes;     /* total number of octets sent */
	u_int32_t       ifi_imcasts;    /* packets received via multicast */
	u_int32_t       ifi_omcasts;    /* packets sent via multicast */
	u_int32_t       ifi_iqdrops;    /* dropped on input, this interface */
	u_int32_t       ifi_noproto;    /* destined for unsupported protocol */
	u_int32_t       ifi_recvtiming; /* usec spent receiving when timing */
	u_int32_t       ifi_xmittiming; /* usec spent xmitting when timing */
	struct IF_DATA_TIMEVAL ifi_lastchange;  /* time of last administrative change */
	u_int32_t       ifi_unused2;    /* used to be the default_proto */
	u_int32_t       ifi_hwassist;   /* HW offload capabilities */
	u_int32_t       ifi_reserved1;  /* for future use */
	u_int32_t       ifi_reserved2;  /* for future use */
};

/*
 * Structure describing information about an interface
 * which may be of interest to management entities.
 */
struct if_data64 {
	/* generic interface information */
	u_char          ifi_type;               /* ethernet, tokenring, etc */
	u_char          ifi_typelen;            /* Length of frame type id */
	u_char          ifi_physical;           /* e.g., AUI, Thinnet, 10base-T, etc */
	u_char          ifi_addrlen;            /* media address length */
	u_char          ifi_hdrlen;             /* media header length */
	u_char          ifi_recvquota;          /* polling quota for receive intrs */
	u_char          ifi_xmitquota;          /* polling quota for xmit intrs */
	u_char          ifi_unused1;            /* for future use */
	u_int32_t       ifi_mtu;                /* maximum transmission unit */
	u_int32_t       ifi_metric;             /* routing metric (external only) */
	u_int64_t       ifi_baudrate;           /* linespeed */
	/* volatile statistics */
	u_int64_t       ifi_ipackets;           /* packets received on interface */
	u_int64_t       ifi_ierrors;            /* input errors on interface */
	u_int64_t       ifi_opackets;           /* packets sent on interface */
	u_int64_t       ifi_oerrors;            /* output errors on interface */
	u_int64_t       ifi_collisions;         /* collisions on csma interfaces */
	u_int64_t       ifi_ibytes;             /* total number of octets received */
	u_int64_t       ifi_obytes;             /* total number of octets sent */
	u_int64_t       ifi_imcasts;            /* packets received via multicast */
	u_int64_t       ifi_omcasts;            /* packets sent via multicast */
	u_int64_t       ifi_iqdrops;            /* dropped on input, this interface */
	u_int64_t       ifi_noproto;            /* destined for unsupported protocol */
	u_int32_t       ifi_recvtiming;         /* usec spent receiving when timing */
	u_int32_t       ifi_xmittiming;         /* usec spent xmitting when timing */
	struct IF_DATA_TIMEVAL ifi_lastchange;  /* time of last administrative change */
};


#pragma pack()

/*
 * Structure defining a queue for a network interface.
 */
struct  ifqueue {
	void    *ifq_head;
	void    *ifq_tail;
	int     ifq_len;
	int     ifq_maxlen;
	int     ifq_drops;
};






#endif /* !_NET_IF_VAR_H_ */
