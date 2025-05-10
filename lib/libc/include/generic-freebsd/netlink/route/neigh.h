/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2022 Alexander V. Chernikov <melifaro@FreeBSD.org>
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Neighbors-related (RTM_<NEW|DEL|GET>NEIGH) message header and attributes.
 */

#ifndef _NETLINK_ROUTE_NEIGH_H_
#define _NETLINK_ROUTE_NEIGH_H_

/* Base header for all of the relevant messages */
struct ndmsg {
	uint8_t		ndm_family;
	uint8_t		ndm_pad1;
	uint16_t	ndm_pad2;
	int32_t		ndm_ifindex;
	uint16_t	ndm_state;
	uint8_t		ndm_flags;
	uint8_t		ndm_type;
};

/* Attributes */
enum {
	NDA_UNSPEC,
	NDA_DST,		/* binary: neigh l3 address */
	NDA_LLADDR,		/* binary: neigh link-level address */
	NDA_CACHEINFO,		/* binary, struct nda_cacheinfo */
	NDA_PROBES,		/* u32: number of probes sent */
	NDA_VLAN,		/* upper 802.1Q tag */
	NDA_PORT,		/* not supported */
	NDA_VNI,		/* not supported */
	NDA_IFINDEX,		/* interface index */
	NDA_MASTER,		/* not supported */
	NDA_LINK_NETNSID,	/* not supported */
	NDA_SRC_VNI,		/* not supported */
	NDA_PROTOCOL,		/* XXX */
	NDA_NH_ID,		/* not supported */
	NDA_FDB_EXT_ATTRS,	/* not supported */
	NDA_FLAGS_EXT,		/* u32: ndm_flags */
	NDA_NDM_STATE_MASK,	/* XXX */
	NDA_NDM_FLAGS_MASK,	/* XXX */
	NDA_FREEBSD,		/* nested: FreeBSD-specific */
	__NDA_MAX
};

#define	NDA_MAX	(__NDA_MAX - 1)

enum {
	NDAF_UNSPEC,
	NDAF_NEXT_STATE_TS,	/* (u32) seconds from time_uptime when moving to the next state */
};


/* ndm_flags / NDA_FLAGS_EXT */
#define	NTF_USE			0x0001	/* XXX */
#define	NTF_SELF		0x0002	/* local station */
#define	NTF_MASTER		0x0004	/* XXX */
#define	NTF_PROXY		0x0008	/* proxy entry */
#define	NTF_EXT_LEARNED		0x0010	/* not used */
#define	NTF_OFFLOADED		0x0020	/* not used */
#define	NTF_STICKY		0x0040	/* permanent entry */
#define	NTF_ROUTER		0x0080	/* dst indicated itself as a router */
/* start of NDA_FLAGS_EXT */
#define	NTF_EXT_MANAGED		0x0100	/* not used */

/* ndm_state */
#define	NUD_INCOMPLETE		0x01	/* No lladdr, address resolution in progress */
#define	NUD_REACHABLE		0x02	/* reachable & recently resolved */
#define	NUD_STALE		0x04	/* has lladdr but it's stale */
#define	NUD_DELAY		0x08	/* has lladdr, is stale, probes delayed */
#define	NUD_PROBE		0x10	/* has lladdr, is stale, probes sent */
#define	NUD_FAILED		0x20	/* unused */

/* Dummy states */
#define	NUD_NOARP		0x40	/* not used */
#define	NUD_PERMANENT		0x80	/* not flushed */
#define	NUD_NONE		0x00

/* NDA_CACHEINFO */
struct nda_cacheinfo {
	uint32_t	ndm_confirmed;	/* seconds since ARP/ND was received from neigh */
	uint32_t	ndm_used;	/* seconds since last used (not provided) */
	uint32_t	ndm_updated;	/* seconds since state was updated last */
	uint32_t	ndm_refcnt;	/* number of references held */
};

#endif