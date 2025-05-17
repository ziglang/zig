/*	$NetBSD: if_ieee1394.h,v 1.9 2008/04/28 20:24:09 martin Exp $	*/

/*
 * Copyright (c) 2000 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Atsushi Onoe.
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

#ifndef _NET_IF_IEEE1394_H_
#define _NET_IF_IEEE1394_H_

/* hardware address information for arp / nd */
struct ieee1394_hwaddr {
	uint8_t	iha_uid[8];		/* node unique ID */
	uint8_t	iha_maxrec;		/* max_rec in the config ROM */
	uint8_t	iha_speed;		/* min of link/PHY speed */
	uint8_t	iha_offset[6];		/* unicast FIFO address */
};

/*
 * BPF wants to see one of these.
 */
struct ieee1394_bpfhdr {
	uint8_t		ibh_dhost[8];
	uint8_t		ibh_shost[8];
	uint16_t	ibh_type;
};

#ifdef _KERNEL

/* pseudo header */
struct ieee1394_header {
	uint8_t	ih_uid[8];		/* dst/src uid */
	uint8_t	ih_maxrec;		/* dst maxrec for tx */
	uint8_t	ih_speed;		/* speed */
	uint8_t	ih_offset[6];		/* dst offset */
};

/* unfragment encapsulation header */
struct ieee1394_unfraghdr {
	uint16_t	iuh_ft;			/* fragment type == 0 */
	uint16_t	iuh_etype;		/* ether_type */
};

/* fragmented encapsulation header */
struct ieee1394_fraghdr {
	uint16_t	ifh_ft_size;		/* fragment type, data size-1 */
	uint16_t	ifh_etype_off;		/* etype for first fragment */
						/* offset for subseq frag */
	uint16_t	ifh_dgl;		/* datagram label */
	uint16_t	ifh_reserved;
};

#define	IEEE1394_FT_SUBSEQ	0x8000
#define	IEEE1394_FT_MORE	0x4000

#define	IEEE1394MTU		1500

#define	IEEE1394_GASP_LEN	8		/* GASP header for Stream */
#define	IEEE1394_ADDR_LEN	8
#define	IEEE1394_CRC_LEN	4

struct ieee1394_reass_pkt {
	LIST_ENTRY(ieee1394_reass_pkt) rp_next;
	struct mbuf	*rp_m;
	uint16_t	rp_size;
	uint16_t	rp_etype;
	uint16_t	rp_off;
	uint16_t	rp_dgl;
	uint16_t	rp_len;
	uint16_t	rp_ttl;
};

struct ieee1394_reassq {
	LIST_ENTRY(ieee1394_reassq) rq_node;
	LIST_HEAD(, ieee1394_reass_pkt) rq_pkt;
	uint32_t	fr_id;
};

struct ieee1394com {
	struct ifnet	fc_if;
	struct ieee1394_hwaddr ic_hwaddr;
	uint16_t	ic_dgl;
	LIST_HEAD(, ieee1394_reassq) ic_reassq;
};

const char *ieee1394_sprintf(const uint8_t *);
void ieee1394_input(struct ifnet *, struct mbuf *, uint16_t);
void ieee1394_ifattach(struct ifnet *, const struct ieee1394_hwaddr *);
void ieee1394_ifdetach(struct ifnet *);
int  ieee1394_ioctl(struct ifnet *, u_long, void *);
struct mbuf * ieee1394_fragment(struct ifnet *, struct mbuf *, int, uint16_t);
void ieee1394_drain(struct ifnet *);
void ieee1394_watchdog(struct ifnet *);
#endif /* _KERNEL */

#endif /* !_NET_IF_IEEE1394_H_ */