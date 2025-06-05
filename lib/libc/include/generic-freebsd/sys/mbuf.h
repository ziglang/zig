/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1988, 1993
 *	The Regents of the University of California.
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
 *	@(#)mbuf.h	8.5 (Berkeley) 2/19/95
 */

#ifndef _SYS_MBUF_H_
#define	_SYS_MBUF_H_

/* XXX: These includes suck. Sorry! */
#include <sys/queue.h>
#ifdef _KERNEL
#include <sys/systm.h>
#include <sys/refcount.h>
#include <vm/uma.h>

#include <sys/sdt.h>

#define	MBUF_PROBE1(probe, arg0)					\
	SDT_PROBE1(sdt, , , probe, arg0)
#define	MBUF_PROBE2(probe, arg0, arg1)					\
	SDT_PROBE2(sdt, , , probe, arg0, arg1)
#define	MBUF_PROBE3(probe, arg0, arg1, arg2)				\
	SDT_PROBE3(sdt, , , probe, arg0, arg1, arg2)
#define	MBUF_PROBE4(probe, arg0, arg1, arg2, arg3)			\
	SDT_PROBE4(sdt, , , probe, arg0, arg1, arg2, arg3)
#define	MBUF_PROBE5(probe, arg0, arg1, arg2, arg3, arg4)		\
	SDT_PROBE5(sdt, , , probe, arg0, arg1, arg2, arg3, arg4)

SDT_PROBE_DECLARE(sdt, , , m__init);
SDT_PROBE_DECLARE(sdt, , , m__gethdr_raw);
SDT_PROBE_DECLARE(sdt, , , m__gethdr);
SDT_PROBE_DECLARE(sdt, , , m__get_raw);
SDT_PROBE_DECLARE(sdt, , , m__get);
SDT_PROBE_DECLARE(sdt, , , m__getcl);
SDT_PROBE_DECLARE(sdt, , , m__getjcl);
SDT_PROBE_DECLARE(sdt, , , m__clget);
SDT_PROBE_DECLARE(sdt, , , m__cljget);
SDT_PROBE_DECLARE(sdt, , , m__cljset);
SDT_PROBE_DECLARE(sdt, , , m__free);
SDT_PROBE_DECLARE(sdt, , , m__freem);
SDT_PROBE_DECLARE(sdt, , , m__freemp);

#endif /* _KERNEL */

/*
 * Mbufs are of a single size, MSIZE (sys/param.h), which includes overhead.
 * An mbuf may add a single "mbuf cluster" of size MCLBYTES (also in
 * sys/param.h), which has no additional overhead and is used instead of the
 * internal data area; this is done when at least MINCLSIZE of data must be
 * stored.  Additionally, it is possible to allocate a separate buffer
 * externally and attach it to the mbuf in a way similar to that of mbuf
 * clusters.
 *
 * NB: These calculation do not take actual compiler-induced alignment and
 * padding inside the complete struct mbuf into account.  Appropriate
 * attention is required when changing members of struct mbuf.
 *
 * MLEN is data length in a normal mbuf.
 * MHLEN is data length in an mbuf with pktheader.
 * MINCLSIZE is a smallest amount of data that should be put into cluster.
 *
 * Compile-time assertions in uipc_mbuf.c test these values to ensure that
 * they are sensible.
 */
struct mbuf;
#define	MHSIZE		offsetof(struct mbuf, m_dat)
#define	MPKTHSIZE	offsetof(struct mbuf, m_pktdat)
#define	MLEN		((int)(MSIZE - MHSIZE))
#define	MHLEN		((int)(MSIZE - MPKTHSIZE))
#define	MINCLSIZE	(MHLEN + 1)
#define	M_NODOM		255

#ifdef _KERNEL
/*-
 * Macro for type conversion: convert mbuf pointer to data pointer of correct
 * type:
 *
 * mtod(m, t)	-- Convert mbuf pointer to data pointer of correct type.
 * mtodo(m, o) -- Same as above but with offset 'o' into data.
 */
#define	mtod(m, t)	((t)((m)->m_data))
#define	mtodo(m, o)	((void *)(((m)->m_data) + (o)))

/*
 * Argument structure passed to UMA routines during mbuf and packet
 * allocations.
 */
struct mb_args {
	int	flags;	/* Flags for mbuf being allocated */
	short	type;	/* Type of mbuf being allocated */
};
#endif /* _KERNEL */

/*
 * Packet tag structure (see below for details).
 */
struct m_tag {
	SLIST_ENTRY(m_tag)	m_tag_link;	/* List of packet tags */
	u_int16_t		m_tag_id;	/* Tag ID */
	u_int16_t		m_tag_len;	/* Length of data */
	u_int32_t		m_tag_cookie;	/* ABI/Module ID */
	void			(*m_tag_free)(struct m_tag *);
};

/*
 * Static network interface owned tag.
 * Allocated through ifp->if_snd_tag_alloc().
 */
struct if_snd_tag_sw;

struct m_snd_tag {
	struct ifnet *ifp;		/* network interface tag belongs to */
	const struct if_snd_tag_sw *sw;
	volatile u_int refcount;
};

/*
 * Record/packet header in first mbuf of chain; valid only if M_PKTHDR is set.
 * Size ILP32: 56
 *	 LP64: 64
 * Compile-time assertions in uipc_mbuf.c test these values to ensure that
 * they are correct.
 */
struct pkthdr {
	union {
		struct m_snd_tag *snd_tag;	/* send tag, if any */
		struct ifnet	*rcvif;		/* rcv interface */
		struct {
			uint16_t rcvidx;	/* rcv interface index ... */
			uint16_t rcvgen;	/* ... and generation count */
		};
	};
	union {
		struct ifnet	*leaf_rcvif;	/* leaf rcv interface */
		struct {
			uint16_t leaf_rcvidx;	/* leaf rcv interface index ... */
			uint16_t leaf_rcvgen;	/* ... and generation count */
		};
	};
	SLIST_HEAD(packet_tags, m_tag) tags; /* list of packet tags */
	int32_t		 len;		/* total packet length */

	/* Layer crossing persistent information. */
	uint32_t	 flowid;	/* packet's 4-tuple system */
	uint32_t	 csum_flags;	/* checksum and offload features */
	uint16_t	 fibnum;	/* this packet should use this fib */
	uint8_t		 numa_domain;	/* NUMA domain of recvd pkt */
	uint8_t		 rsstype;	/* hash type */
#if !defined(__LP64__)
	uint32_t	 pad;		/* pad for 64bit alignment */
#endif
	union {
		uint64_t	rcv_tstmp;	/* timestamp in ns */
		struct {
			uint8_t		 l2hlen;	/* layer 2 hdr len */
			uint8_t		 l3hlen;	/* layer 3 hdr len */
			uint8_t		 l4hlen;	/* layer 4 hdr len */
			uint8_t		 l5hlen;	/* layer 5 hdr len */
			uint8_t		 inner_l2hlen;
			uint8_t		 inner_l3hlen;
			uint8_t		 inner_l4hlen;
			uint8_t		 inner_l5hlen;
		};
	};
	union {
		uint8_t  eight[8];
		uint16_t sixteen[4];
		uint32_t thirtytwo[2];
		uint64_t sixtyfour[1];
		uintptr_t unintptr[1];
		void	*ptr;
	} PH_per;

	/* Layer specific non-persistent local storage for reassembly, etc. */
	union {
		union {
			uint8_t  eight[8];
			uint16_t sixteen[4];
			uint32_t thirtytwo[2];
			uint64_t sixtyfour[1];
			uintptr_t unintptr[1];
			void 	*ptr;
		} PH_loc;
		/* Upon allocation: total packet memory consumption. */
		u_int	memlen;
	};
};
#define	ether_vtag	PH_per.sixteen[0]
#define tcp_tun_port	PH_per.sixteen[0] /* outbound */
#define	vt_nrecs	PH_per.sixteen[0]	  /* mld and v6-ND */
#define	tso_segsz	PH_per.sixteen[1] /* inbound after LRO */
#define	lro_nsegs	tso_segsz	  /* inbound after LRO */
#define	csum_data	PH_per.thirtytwo[1] /* inbound from hardware up */
#define	lro_tcp_d_len	PH_loc.sixteen[0] /* inbound during LRO (no reassembly) */
#define	lro_tcp_d_csum	PH_loc.sixteen[1] /* inbound during LRO (no reassembly) */
#define	lro_tcp_h_off	PH_loc.sixteen[2] /* inbound during LRO (no reassembly) */
#define	lro_etype	PH_loc.sixteen[3] /* inbound during LRO (no reassembly) */
/* Note PH_loc is used during IP reassembly (all 8 bytes as a ptr) */

/*
 * TLS records for TLS 1.0-1.2 can have the following header lengths:
 * - 5 (AES-CBC with implicit IV)
 * - 21 (AES-CBC with explicit IV)
 * - 13 (AES-GCM with 8 byte explicit IV)
 */
#define	MBUF_PEXT_HDR_LEN	23

/*
 * TLS records for TLS 1.0-1.2 can have the following maximum trailer
 * lengths:
 * - 16 (AES-GCM)
 * - 36 (AES-CBC with SHA1 and up to 16 bytes of padding)
 * - 48 (AES-CBC with SHA2-256 and up to 16 bytes of padding)
 * - 64 (AES-CBC with SHA2-384 and up to 16 bytes of padding)
 */
#define	MBUF_PEXT_TRAIL_LEN	64

#if defined(__LP64__)
#define MBUF_PEXT_MAX_PGS (40 / sizeof(vm_paddr_t))
#else
#define MBUF_PEXT_MAX_PGS (64 / sizeof(vm_paddr_t))
#endif

#define	MBUF_PEXT_MAX_BYTES						\
    (MBUF_PEXT_MAX_PGS * PAGE_SIZE + MBUF_PEXT_HDR_LEN + MBUF_PEXT_TRAIL_LEN)

struct ktls_session;
struct socket;

/*
 * Description of external storage mapped into mbuf; valid only if M_EXT is
 * set.
 * Size ILP32: 28
 *	 LP64: 48
 * Compile-time assertions in uipc_mbuf.c test these values to ensure that
 * they are correct.
 */
typedef	void m_ext_free_t(struct mbuf *);
struct m_ext {
	union {
		/*
		 * If EXT_FLAG_EMBREF is set, then we use refcount in the
		 * mbuf, the 'ext_count' member.  Otherwise, we have a
		 * shadow copy and we use pointer 'ext_cnt'.  The original
		 * mbuf is responsible to carry the pointer to free routine
		 * and its arguments.  They aren't copied into shadows in
		 * mb_dupcl() to avoid dereferencing next cachelines.
		 */
		volatile u_int	 ext_count;
		volatile u_int	*ext_cnt;
	};
	uint32_t	 ext_size;	/* size of buffer, for ext_free */
	uint32_t	 ext_type:8,	/* type of external storage */
			 ext_flags:24;	/* external storage mbuf flags */
	union {
		struct {
			/*
			 * Regular M_EXT mbuf:
			 * o ext_buf always points to the external buffer.
			 * o ext_free (below) and two optional arguments
			 *   ext_arg1 and ext_arg2 store the free context for
			 *   the external storage.  They are set only in the
			 *   refcount carrying mbuf, the one with
			 *   EXT_FLAG_EMBREF flag, with exclusion for
			 *   EXT_EXTREF type, where the free context is copied
			 *   into all mbufs that use same external storage.
			 */
			char 	*ext_buf;	/* start of buffer */
#define	m_ext_copylen	offsetof(struct m_ext, ext_arg2)
			void	*ext_arg2;
		};
		struct {
			/*
			 * Multi-page M_EXTPG mbuf:
			 * o extpg_pa - page vector.
			 * o extpg_trail and extpg_hdr - TLS trailer and
			 *   header.
			 * Uses ext_free and may also use ext_arg1.
			 */
			vm_paddr_t	extpg_pa[MBUF_PEXT_MAX_PGS];
			char		extpg_trail[MBUF_PEXT_TRAIL_LEN];
			char		extpg_hdr[MBUF_PEXT_HDR_LEN];
			/* Pretend these 3 fields are part of mbuf itself. */
#define	m_epg_pa	m_ext.extpg_pa
#define	m_epg_trail	m_ext.extpg_trail
#define	m_epg_hdr	m_ext.extpg_hdr
#define	m_epg_ext_copylen	offsetof(struct m_ext, ext_free)
		};
	};
	/*
	 * Free method and optional argument pointer, both
	 * used by M_EXT and M_EXTPG.
	 */
	m_ext_free_t	*ext_free;
	void		*ext_arg1;
};

/*
 * The core of the mbuf object along with some shortcut defines for practical
 * purposes.
 */
struct mbuf {
	/*
	 * Header present at the beginning of every mbuf.
	 * Size ILP32: 24
	 *      LP64: 32
	 * Compile-time assertions in uipc_mbuf.c test these values to ensure
	 * that they are correct.
	 */
	union {	/* next buffer in chain */
		struct mbuf		*m_next;
		SLIST_ENTRY(mbuf)	m_slist;
		STAILQ_ENTRY(mbuf)	m_stailq;
	};
	union {	/* next chain in queue/record */
		struct mbuf		*m_nextpkt;
		SLIST_ENTRY(mbuf)	m_slistpkt;
		STAILQ_ENTRY(mbuf)	m_stailqpkt;
	};
	caddr_t		 m_data;	/* location of data */
	int32_t		 m_len;		/* amount of data in this mbuf */
	uint32_t	 m_type:8,	/* type of data in this mbuf */
			 m_flags:24;	/* flags; see below */
#if !defined(__LP64__)
	uint32_t	 m_pad;		/* pad for 64bit alignment */
#endif

	/*
	 * A set of optional headers (packet header, external storage header)
	 * and internal data storage.  Historically, these arrays were sized
	 * to MHLEN (space left after a packet header) and MLEN (space left
	 * after only a regular mbuf header); they are now variable size in
	 * order to support future work on variable-size mbufs.
	 */
	union {
		struct {
			union {
				/* M_PKTHDR set. */
				struct pkthdr	m_pkthdr;

				/* M_EXTPG set.
				 * Multi-page M_EXTPG mbuf has its meta data
				 * split between the below anonymous structure
				 * and m_ext.  It carries vector of pages,
				 * optional header and trailer char vectors
				 * and pointers to socket/TLS data.
				 */
#define	m_epg_startcopy		m_epg_npgs
#define	m_epg_endcopy		m_epg_stailq
				struct {
					/* Overall count of pages and count of
					 * pages with I/O pending. */
					uint8_t	m_epg_npgs;
					uint8_t	m_epg_nrdy;
					/* TLS header and trailer lengths.
					 * The data itself resides in m_ext. */
					uint8_t	m_epg_hdrlen;
					uint8_t	m_epg_trllen;
					/* Offset into 1st page and length of
					 * data in the last page. */
					uint16_t m_epg_1st_off;
					uint16_t m_epg_last_len;
					uint8_t	m_epg_flags;
#define	EPG_FLAG_ANON	0x1	/* Data can be encrypted in place. */
#define	EPG_FLAG_2FREE	0x2	/* Scheduled for free. */
					uint8_t	m_epg_record_type;
					uint8_t	__spare[2];
					int	m_epg_enc_cnt;
					struct ktls_session *m_epg_tls;
					struct socket	*m_epg_so;
					uint64_t	m_epg_seqno;
					STAILQ_ENTRY(mbuf) m_epg_stailq;
				};
			};
			union {
				/* M_EXT or M_EXTPG set. */
				struct m_ext	m_ext;
				/* M_PKTHDR set, neither M_EXT nor M_EXTPG. */
				char		m_pktdat[0];
			};
		};
		char	m_dat[0];			/* !M_PKTHDR, !M_EXT */
	};
};

#ifdef _KERNEL
static inline int
m_epg_pagelen(const struct mbuf *m, int pidx, int pgoff)
{

	KASSERT(pgoff == 0 || pidx == 0,
	    ("page %d with non-zero offset %d in %p", pidx, pgoff, m));

	if (pidx == m->m_epg_npgs - 1) {
		return (m->m_epg_last_len);
	} else {
		return (PAGE_SIZE - pgoff);
	}
}

#ifdef INVARIANTS
#define	MCHECK(ex, msg)	KASSERT((ex),				\
	    ("Multi page mbuf %p with " #msg " at %s:%d",	\
	    m, __FILE__, __LINE__))
/*
 * NB: This expects a non-empty buffer (npgs > 0 and
 * last_pg_len > 0).
 */
#define	MBUF_EXT_PGS_ASSERT_SANITY(m)	do {				\
	MCHECK(m->m_epg_npgs > 0, "no valid pages");		\
	MCHECK(m->m_epg_npgs <= nitems(m->m_epg_pa),		\
	    "too many pages");						\
	MCHECK(m->m_epg_nrdy <= m->m_epg_npgs,			\
	    "too many ready pages");					\
	MCHECK(m->m_epg_1st_off < PAGE_SIZE,			\
		"too large page offset");				\
	MCHECK(m->m_epg_last_len > 0, "zero last page length");	\
	MCHECK(m->m_epg_last_len <= PAGE_SIZE,			\
	    "too large last page length");				\
	if (m->m_epg_npgs == 1)					\
		MCHECK(m->m_epg_1st_off +			\
		    m->m_epg_last_len <=	 PAGE_SIZE,		\
		    "single page too large");				\
	MCHECK(m->m_epg_hdrlen <= sizeof(m->m_epg_hdr),		\
	    "too large header length");					\
	MCHECK(m->m_epg_trllen <= sizeof(m->m_epg_trail),	\
	    "too large header length");					\
} while (0)
#else
#define	MBUF_EXT_PGS_ASSERT_SANITY(m)	do {} while (0)
#endif
#endif

/*
 * mbuf flags of global significance and layer crossing.
 * Those of only protocol/layer specific significance are to be mapped
 * to M_PROTO[1-11] and cleared at layer handoff boundaries.
 * NB: Limited to the lower 24 bits.
 */
#define	M_EXT		0x00000001 /* has associated external storage */
#define	M_PKTHDR	0x00000002 /* start of record */
#define	M_EOR		0x00000004 /* end of record */
#define	M_RDONLY	0x00000008 /* associated data is marked read-only */
#define	M_BCAST		0x00000010 /* send/received as link-level broadcast */
#define	M_MCAST		0x00000020 /* send/received as link-level multicast */
#define	M_PROMISC	0x00000040 /* packet was not for us */
#define	M_VLANTAG	0x00000080 /* ether_vtag is valid */
#define	M_EXTPG		0x00000100 /* has array of unmapped pages and TLS */
#define	M_NOFREE	0x00000200 /* do not free mbuf, embedded in cluster */
#define	M_TSTMP		0x00000400 /* rcv_tstmp field is valid */
#define	M_TSTMP_HPREC	0x00000800 /* rcv_tstmp is high-prec, typically
				      hw-stamped on port (useful for IEEE 1588
				      and 802.1AS) */
#define M_TSTMP_LRO	0x00001000 /* Time LRO pushed in pkt is valid in (PH_loc) */

#define	M_PROTO1	0x00002000 /* protocol-specific */
#define	M_PROTO2	0x00004000 /* protocol-specific */
#define	M_PROTO3	0x00008000 /* protocol-specific */
#define	M_PROTO4	0x00010000 /* protocol-specific */
#define	M_PROTO5	0x00020000 /* protocol-specific */
#define	M_PROTO6	0x00040000 /* protocol-specific */
#define	M_PROTO7	0x00080000 /* protocol-specific */
#define	M_PROTO8	0x00100000 /* protocol-specific */
#define	M_PROTO9	0x00200000 /* protocol-specific */
#define	M_PROTO10	0x00400000 /* protocol-specific */
#define	M_PROTO11	0x00800000 /* protocol-specific */

/*
 * Flags to purge when crossing layers.
 */
#define	M_PROTOFLAGS \
    (M_PROTO1|M_PROTO2|M_PROTO3|M_PROTO4|M_PROTO5|M_PROTO6|M_PROTO7|M_PROTO8|\
     M_PROTO9|M_PROTO10|M_PROTO11)

/*
 * Flags preserved when copying m_pkthdr.
 */
#define M_COPYFLAGS \
    (M_PKTHDR|M_EOR|M_RDONLY|M_BCAST|M_MCAST|M_PROMISC|M_VLANTAG|M_TSTMP| \
     M_TSTMP_HPREC|M_TSTMP_LRO|M_PROTOFLAGS)

/*
 * Flags preserved during demote.
 */
#define	M_DEMOTEFLAGS \
    (M_EXT | M_RDONLY | M_NOFREE | M_EXTPG)

/*
 * Mbuf flag description for use with printf(9) %b identifier.
 */
#define	M_FLAG_BITS \
    "\20\1M_EXT\2M_PKTHDR\3M_EOR\4M_RDONLY\5M_BCAST\6M_MCAST" \
    "\7M_PROMISC\10M_VLANTAG\11M_EXTPG\12M_NOFREE\13M_TSTMP\14M_TSTMP_HPREC\15M_TSTMP_LRO"
#define	M_FLAG_PROTOBITS \
    "\16M_PROTO1\17M_PROTO2\20M_PROTO3\21M_PROTO4" \
    "\22M_PROTO5\23M_PROTO6\24M_PROTO7\25M_PROTO8\26M_PROTO9" \
    "\27M_PROTO10\28M_PROTO11"
#define	M_FLAG_PRINTF (M_FLAG_BITS M_FLAG_PROTOBITS)

/*
 * Network interface cards are able to hash protocol fields (such as IPv4
 * addresses and TCP port numbers) classify packets into flows.  These flows
 * can then be used to maintain ordering while delivering packets to the OS
 * via parallel input queues, as well as to provide a stateless affinity
 * model.  NIC drivers can pass up the hash via m->m_pkthdr.flowid, and set
 * m_flag fields to indicate how the hash should be interpreted by the
 * network stack.
 *
 * Most NICs support RSS, which provides ordering and explicit affinity, and
 * use the hash m_flag bits to indicate what header fields were covered by
 * the hash.  M_HASHTYPE_OPAQUE and M_HASHTYPE_OPAQUE_HASH can be set by non-
 * RSS cards or configurations that provide an opaque flow identifier, allowing
 * for ordering and distribution without explicit affinity.  Additionally,
 * M_HASHTYPE_OPAQUE_HASH indicates that the flow identifier has hash
 * properties.
 *
 * The meaning of the IPV6_EX suffix:
 * "o  Home address from the home address option in the IPv6 destination
 *     options header.  If the extension header is not present, use the Source
 *     IPv6 Address.
 *  o  IPv6 address that is contained in the Routing-Header-Type-2 from the
 *     associated extension header.  If the extension header is not present,
 *     use the Destination IPv6 Address."
 * Quoted from:
 * https://docs.microsoft.com/en-us/windows-hardware/drivers/network/rss-hashing-types#ndishashipv6ex
 */
#define	M_HASHTYPE_HASHPROP		0x80	/* has hash properties */
#define	M_HASHTYPE_INNER		0x40	/* calculated from inner headers */
#define	M_HASHTYPE_HASH(t)		(M_HASHTYPE_HASHPROP | (t))
/* Microsoft RSS standard hash types */
#define	M_HASHTYPE_NONE			0
#define	M_HASHTYPE_RSS_IPV4		M_HASHTYPE_HASH(1) /* IPv4 2-tuple */
#define	M_HASHTYPE_RSS_TCP_IPV4		M_HASHTYPE_HASH(2) /* TCPv4 4-tuple */
#define	M_HASHTYPE_RSS_IPV6		M_HASHTYPE_HASH(3) /* IPv6 2-tuple */
#define	M_HASHTYPE_RSS_TCP_IPV6		M_HASHTYPE_HASH(4) /* TCPv6 4-tuple */
#define	M_HASHTYPE_RSS_IPV6_EX		M_HASHTYPE_HASH(5) /* IPv6 2-tuple +
							    * ext hdrs */
#define	M_HASHTYPE_RSS_TCP_IPV6_EX	M_HASHTYPE_HASH(6) /* TCPv6 4-tuple +
							    * ext hdrs */
#define	M_HASHTYPE_RSS_UDP_IPV4		M_HASHTYPE_HASH(7) /* IPv4 UDP 4-tuple*/
#define	M_HASHTYPE_RSS_UDP_IPV6		M_HASHTYPE_HASH(9) /* IPv6 UDP 4-tuple*/
#define	M_HASHTYPE_RSS_UDP_IPV6_EX	M_HASHTYPE_HASH(10)/* IPv6 UDP 4-tuple +
							    * ext hdrs */

#define	M_HASHTYPE_OPAQUE		0x3f	/* ordering, not affinity */
#define	M_HASHTYPE_OPAQUE_HASH		M_HASHTYPE_HASH(M_HASHTYPE_OPAQUE)
						/* ordering+hash, not affinity*/

#define	M_HASHTYPE_CLEAR(m)	((m)->m_pkthdr.rsstype = 0)
#define	M_HASHTYPE_GET(m)	((m)->m_pkthdr.rsstype & ~M_HASHTYPE_INNER)
#define	M_HASHTYPE_SET(m, v)	((m)->m_pkthdr.rsstype = (v))
#define	M_HASHTYPE_TEST(m, v)	(M_HASHTYPE_GET(m) == (v))
#define	M_HASHTYPE_ISHASH(m)	\
    (((m)->m_pkthdr.rsstype & M_HASHTYPE_HASHPROP) != 0)
#define	M_HASHTYPE_SETINNER(m)	do {			\
	(m)->m_pkthdr.rsstype |= M_HASHTYPE_INNER;	\
    } while (0)

/*
 * External mbuf storage buffer types.
 */
#define	EXT_CLUSTER	1	/* mbuf cluster */
#define	EXT_SFBUF	2	/* sendfile(2)'s sf_buf */
#define	EXT_JUMBOP	3	/* jumbo cluster page sized */
#define	EXT_JUMBO9	4	/* jumbo cluster 9216 bytes */
#define	EXT_JUMBO16	5	/* jumbo cluster 16184 bytes */
#define	EXT_PACKET	6	/* mbuf+cluster from packet zone */
#define	EXT_MBUF	7	/* external mbuf reference */
#define	EXT_RXRING	8	/* data in NIC receive ring */

#define	EXT_VENDOR1	224	/* for vendor-internal use */
#define	EXT_VENDOR2	225	/* for vendor-internal use */
#define	EXT_VENDOR3	226	/* for vendor-internal use */
#define	EXT_VENDOR4	227	/* for vendor-internal use */

#define	EXT_EXP1	244	/* for experimental use */
#define	EXT_EXP2	245	/* for experimental use */
#define	EXT_EXP3	246	/* for experimental use */
#define	EXT_EXP4	247	/* for experimental use */

#define	EXT_NET_DRV	252	/* custom ext_buf provided by net driver(s) */
#define	EXT_MOD_TYPE	253	/* custom module's ext_buf type */
#define	EXT_DISPOSABLE	254	/* can throw this buffer away w/page flipping */
#define	EXT_EXTREF	255	/* has externally maintained ext_cnt ptr */

/*
 * Flags for external mbuf buffer types.
 * NB: limited to the lower 24 bits.
 */
#define	EXT_FLAG_EMBREF		0x000001	/* embedded ext_count */
#define	EXT_FLAG_EXTREF		0x000002	/* external ext_cnt, notyet */

#define	EXT_FLAG_NOFREE		0x000010	/* don't free mbuf to pool, notyet */

#define	EXT_FLAG_VENDOR1	0x010000	/* These flags are vendor */
#define	EXT_FLAG_VENDOR2	0x020000	/* or submodule specific, */
#define	EXT_FLAG_VENDOR3	0x040000	/* not used by mbuf code. */
#define	EXT_FLAG_VENDOR4	0x080000	/* Set/read by submodule. */

#define	EXT_FLAG_EXP1		0x100000	/* for experimental use */
#define	EXT_FLAG_EXP2		0x200000	/* for experimental use */
#define	EXT_FLAG_EXP3		0x400000	/* for experimental use */
#define	EXT_FLAG_EXP4		0x800000	/* for experimental use */

/*
 * EXT flag description for use with printf(9) %b identifier.
 */
#define	EXT_FLAG_BITS \
    "\20\1EXT_FLAG_EMBREF\2EXT_FLAG_EXTREF\5EXT_FLAG_NOFREE" \
    "\21EXT_FLAG_VENDOR1\22EXT_FLAG_VENDOR2\23EXT_FLAG_VENDOR3" \
    "\24EXT_FLAG_VENDOR4\25EXT_FLAG_EXP1\26EXT_FLAG_EXP2\27EXT_FLAG_EXP3" \
    "\30EXT_FLAG_EXP4"

/*
 * Flags indicating checksum, segmentation and other offload work to be
 * done, or already done, by hardware or lower layers.  It is split into
 * separate inbound and outbound flags.
 *
 * Outbound flags that are set by upper protocol layers requesting lower
 * layers, or ideally the hardware, to perform these offloading tasks.
 * For outbound packets this field and its flags can be directly tested
 * against ifnet if_hwassist.  Note that the outbound and the inbound flags do
 * not collide right now but they could be allowed to (as long as the flags are
 * scrubbed appropriately when the direction of an mbuf changes).  CSUM_BITS
 * would also have to split into CSUM_BITS_TX and CSUM_BITS_RX.
 *
 * CSUM_INNER_<x> is the same as CSUM_<x> but it applies to the inner frame.
 * The CSUM_ENCAP_<x> bits identify the outer encapsulation.
 */
#define	CSUM_IP			0x00000001	/* IP header checksum offload */
#define	CSUM_IP_UDP		0x00000002	/* UDP checksum offload */
#define	CSUM_IP_TCP		0x00000004	/* TCP checksum offload */
#define	CSUM_IP_SCTP		0x00000008	/* SCTP checksum offload */
#define	CSUM_IP_TSO		0x00000010	/* TCP segmentation offload */
#define	CSUM_IP_ISCSI		0x00000020	/* iSCSI checksum offload */

#define	CSUM_INNER_IP6_UDP	0x00000040
#define	CSUM_INNER_IP6_TCP	0x00000080
#define	CSUM_INNER_IP6_TSO	0x00000100
#define	CSUM_IP6_UDP		0x00000200	/* UDP checksum offload */
#define	CSUM_IP6_TCP		0x00000400	/* TCP checksum offload */
#define	CSUM_IP6_SCTP		0x00000800	/* SCTP checksum offload */
#define	CSUM_IP6_TSO		0x00001000	/* TCP segmentation offload */
#define	CSUM_IP6_ISCSI		0x00002000	/* iSCSI checksum offload */

#define	CSUM_INNER_IP		0x00004000
#define	CSUM_INNER_IP_UDP	0x00008000
#define	CSUM_INNER_IP_TCP	0x00010000
#define	CSUM_INNER_IP_TSO	0x00020000

#define	CSUM_ENCAP_VXLAN	0x00040000	/* VXLAN outer encapsulation */
#define	CSUM_ENCAP_RSVD1	0x00080000

/* Inbound checksum support where the checksum was verified by hardware. */
#define	CSUM_INNER_L3_CALC	0x00100000
#define	CSUM_INNER_L3_VALID	0x00200000
#define	CSUM_INNER_L4_CALC	0x00400000
#define	CSUM_INNER_L4_VALID	0x00800000
#define	CSUM_L3_CALC		0x01000000	/* calculated layer 3 csum */
#define	CSUM_L3_VALID		0x02000000	/* checksum is correct */
#define	CSUM_L4_CALC		0x04000000	/* calculated layer 4 csum */
#define	CSUM_L4_VALID		0x08000000	/* checksum is correct */
#define	CSUM_L5_CALC		0x10000000	/* calculated layer 5 csum */
#define	CSUM_L5_VALID		0x20000000	/* checksum is correct */
#define	CSUM_COALESCED		0x40000000	/* contains merged segments */

#define	CSUM_SND_TAG		0x80000000	/* Packet header has send tag */

#define CSUM_FLAGS_TX (CSUM_IP | CSUM_IP_UDP | CSUM_IP_TCP | CSUM_IP_SCTP | \
    CSUM_IP_TSO | CSUM_IP_ISCSI | CSUM_INNER_IP6_UDP | CSUM_INNER_IP6_TCP | \
    CSUM_INNER_IP6_TSO | CSUM_IP6_UDP | CSUM_IP6_TCP | CSUM_IP6_SCTP | \
    CSUM_IP6_TSO | CSUM_IP6_ISCSI | CSUM_INNER_IP | CSUM_INNER_IP_UDP | \
    CSUM_INNER_IP_TCP | CSUM_INNER_IP_TSO | CSUM_ENCAP_VXLAN | \
    CSUM_ENCAP_RSVD1 | CSUM_SND_TAG)

#define CSUM_FLAGS_RX (CSUM_INNER_L3_CALC | CSUM_INNER_L3_VALID | \
    CSUM_INNER_L4_CALC | CSUM_INNER_L4_VALID | CSUM_L3_CALC | CSUM_L3_VALID | \
    CSUM_L4_CALC | CSUM_L4_VALID | CSUM_L5_CALC | CSUM_L5_VALID | \
    CSUM_COALESCED)

/*
 * CSUM flag description for use with printf(9) %b identifier.
 */
#define	CSUM_BITS \
    "\20\1CSUM_IP\2CSUM_IP_UDP\3CSUM_IP_TCP\4CSUM_IP_SCTP\5CSUM_IP_TSO" \
    "\6CSUM_IP_ISCSI\7CSUM_INNER_IP6_UDP\10CSUM_INNER_IP6_TCP" \
    "\11CSUM_INNER_IP6_TSO\12CSUM_IP6_UDP\13CSUM_IP6_TCP\14CSUM_IP6_SCTP" \
    "\15CSUM_IP6_TSO\16CSUM_IP6_ISCSI\17CSUM_INNER_IP\20CSUM_INNER_IP_UDP" \
    "\21CSUM_INNER_IP_TCP\22CSUM_INNER_IP_TSO\23CSUM_ENCAP_VXLAN" \
    "\24CSUM_ENCAP_RSVD1\25CSUM_INNER_L3_CALC\26CSUM_INNER_L3_VALID" \
    "\27CSUM_INNER_L4_CALC\30CSUM_INNER_L4_VALID\31CSUM_L3_CALC" \
    "\32CSUM_L3_VALID\33CSUM_L4_CALC\34CSUM_L4_VALID\35CSUM_L5_CALC" \
    "\36CSUM_L5_VALID\37CSUM_COALESCED\40CSUM_SND_TAG"

/* CSUM flags compatibility mappings. */
#define	CSUM_IP_CHECKED		CSUM_L3_CALC
#define	CSUM_IP_VALID		CSUM_L3_VALID
#define	CSUM_DATA_VALID		CSUM_L4_VALID
#define	CSUM_PSEUDO_HDR		CSUM_L4_CALC
#define	CSUM_SCTP_VALID		CSUM_L4_VALID
#define	CSUM_DELAY_DATA		(CSUM_TCP|CSUM_UDP)
#define	CSUM_DELAY_IP		CSUM_IP		/* Only v4, no v6 IP hdr csum */
#define	CSUM_DELAY_DATA_IPV6	(CSUM_TCP_IPV6|CSUM_UDP_IPV6)
#define	CSUM_DATA_VALID_IPV6	CSUM_DATA_VALID
#define	CSUM_TCP		CSUM_IP_TCP
#define	CSUM_UDP		CSUM_IP_UDP
#define	CSUM_SCTP		CSUM_IP_SCTP
#define	CSUM_TSO		(CSUM_IP_TSO|CSUM_IP6_TSO)
#define	CSUM_INNER_TSO		(CSUM_INNER_IP_TSO|CSUM_INNER_IP6_TSO)
#define	CSUM_UDP_IPV6		CSUM_IP6_UDP
#define	CSUM_TCP_IPV6		CSUM_IP6_TCP
#define	CSUM_SCTP_IPV6		CSUM_IP6_SCTP
#define	CSUM_TLS_MASK		(CSUM_L5_CALC|CSUM_L5_VALID)
#define	CSUM_TLS_DECRYPTED	CSUM_L5_CALC

/*
 * mbuf types describing the content of the mbuf (including external storage).
 */
#define	MT_NOTMBUF	0	/* USED INTERNALLY ONLY! Object is not mbuf */
#define	MT_DATA		1	/* dynamic (data) allocation */
#define	MT_HEADER	MT_DATA	/* packet header, use M_PKTHDR instead */

#define	MT_VENDOR1	4	/* for vendor-internal use */
#define	MT_VENDOR2	5	/* for vendor-internal use */
#define	MT_VENDOR3	6	/* for vendor-internal use */
#define	MT_VENDOR4	7	/* for vendor-internal use */

#define	MT_SONAME	8	/* socket name */

#define	MT_EXP1		9	/* for experimental use */
#define	MT_EXP2		10	/* for experimental use */
#define	MT_EXP3		11	/* for experimental use */
#define	MT_EXP4		12	/* for experimental use */

#define	MT_CONTROL	14	/* extra-data protocol message */
#define	MT_EXTCONTROL	15	/* control message with externalized contents */
#define	MT_OOBDATA	16	/* expedited data  */

#define	MT_NOINIT	255	/* Not a type but a flag to allocate
				   a non-initialized mbuf */

/*
 * String names of mbuf-related UMA(9) and malloc(9) types.  Exposed to
 * !_KERNEL so that monitoring tools can look up the zones with
 * libmemstat(3).
 */
#define	MBUF_MEM_NAME		"mbuf"
#define	MBUF_CLUSTER_MEM_NAME	"mbuf_cluster"
#define	MBUF_PACKET_MEM_NAME	"mbuf_packet"
#define	MBUF_JUMBOP_MEM_NAME	"mbuf_jumbo_page"
#define	MBUF_JUMBO9_MEM_NAME	"mbuf_jumbo_9k"
#define	MBUF_JUMBO16_MEM_NAME	"mbuf_jumbo_16k"
#define	MBUF_TAG_MEM_NAME	"mbuf_tag"
#define	MBUF_EXTREFCNT_MEM_NAME	"mbuf_ext_refcnt"
#define	MBUF_EXTPGS_MEM_NAME	"mbuf_extpgs"

#ifdef _KERNEL
union if_snd_tag_alloc_params;

#define	MBUF_CHECKSLEEP(how) do {					\
	if (how == M_WAITOK)						\
		WITNESS_WARN(WARN_GIANTOK | WARN_SLEEPOK, NULL,		\
		    "Sleeping in \"%s\"", __func__);			\
} while (0)

/*
 * Network buffer allocation API
 *
 * The rest of it is defined in kern/kern_mbuf.c
 */
extern uma_zone_t	zone_mbuf;
extern uma_zone_t	zone_clust;
extern uma_zone_t	zone_pack;
extern uma_zone_t	zone_jumbop;
extern uma_zone_t	zone_jumbo9;
extern uma_zone_t	zone_jumbo16;
extern uma_zone_t	zone_extpgs;

void		 mb_dupcl(struct mbuf *, struct mbuf *);
void		 mb_free_ext(struct mbuf *);
void		 mb_free_extpg(struct mbuf *);
void		 mb_free_mext_pgs(struct mbuf *);
struct mbuf	*mb_alloc_ext_pgs(int, m_ext_free_t);
struct mbuf	*mb_alloc_ext_plus_pages(int, int);
struct mbuf	*mb_mapped_to_unmapped(struct mbuf *, int, int, int,
		    struct mbuf **);
int		 mb_unmapped_compress(struct mbuf *m);
struct mbuf 	*mb_unmapped_to_ext(struct mbuf *m);
void		 mb_free_notready(struct mbuf *m, int count);
void		 m_adj(struct mbuf *, int);
void		 m_adj_decap(struct mbuf *, int);
int		 m_apply(struct mbuf *, int, int,
		    int (*)(void *, void *, u_int), void *);
int		 m_append(struct mbuf *, int, c_caddr_t);
void		 m_cat(struct mbuf *, struct mbuf *);
void		 m_catpkt(struct mbuf *, struct mbuf *);
int		 m_clget(struct mbuf *m, int how);
void 		*m_cljget(struct mbuf *m, int how, int size);
struct mbuf	*m_collapse(struct mbuf *, int, int);
void		 m_copyback(struct mbuf *, int, int, c_caddr_t);
void		 m_copydata(const struct mbuf *, int, int, caddr_t);
struct mbuf	*m_copym(struct mbuf *, int, int, int);
struct mbuf	*m_copypacket(struct mbuf *, int);
void		 m_copy_pkthdr(struct mbuf *, struct mbuf *);
struct mbuf	*m_copyup(struct mbuf *, int, int);
struct mbuf	*m_defrag(struct mbuf *, int);
void		 m_demote_pkthdr(struct mbuf *);
void		 m_demote(struct mbuf *, int, int);
struct mbuf	*m_devget(char *, int, int, struct ifnet *,
		    void (*)(char *, caddr_t, u_int));
void		 m_dispose_extcontrolm(struct mbuf *m);
struct mbuf	*m_dup(const struct mbuf *, int);
int		 m_dup_pkthdr(struct mbuf *, const struct mbuf *, int);
void		 m_extadd(struct mbuf *, char *, u_int, m_ext_free_t,
		    void *, void *, int, int);
u_int		 m_fixhdr(struct mbuf *);
struct mbuf	*m_fragment(struct mbuf *, int, int);
void		 m_freem(struct mbuf *);
void		 m_freemp(struct mbuf *);
void		 m_free_raw(struct mbuf *);
struct mbuf	*m_get2(int, int, short, int);
struct mbuf	*m_get3(int, int, short, int);
struct mbuf	*m_getjcl(int, short, int, int);
struct mbuf	*m_getm2(struct mbuf *, int, int, short, int);
struct mbuf	*m_getptr(struct mbuf *, int, int *);
u_int		 m_length(struct mbuf *, struct mbuf **);
int		 m_mbuftouio(struct uio *, const struct mbuf *, int);
void		 m_move_pkthdr(struct mbuf *, struct mbuf *);
int		 m_pkthdr_init(struct mbuf *, int);
struct mbuf	*m_prepend(struct mbuf *, int, int);
void		 m_print(const struct mbuf *, int);
struct mbuf	*m_pulldown(struct mbuf *, int, int, int *);
struct mbuf	*m_pullup(struct mbuf *, int);
int		 m_sanity(struct mbuf *, int);
struct mbuf	*m_split(struct mbuf *, int, int);
struct mbuf	*m_uiotombuf(struct uio *, int, int, int, int);
int		 m_unmapped_uiomove(const struct mbuf *, int, struct uio *,
		    int);
struct mbuf	*m_unshare(struct mbuf *, int);
int		 m_snd_tag_alloc(struct ifnet *,
		    union if_snd_tag_alloc_params *, struct m_snd_tag **);
void		 m_snd_tag_init(struct m_snd_tag *, struct ifnet *,
		    const struct if_snd_tag_sw *);
void		 m_snd_tag_destroy(struct m_snd_tag *);
void		 m_rcvif_serialize(struct mbuf *);
struct ifnet	*m_rcvif_restore(struct mbuf *);

static __inline int
m_gettype(int size)
{
	int type;

	switch (size) {
	case MSIZE:
		type = EXT_MBUF;
		break;
	case MCLBYTES:
		type = EXT_CLUSTER;
		break;
	case MJUMPAGESIZE:
		type = EXT_JUMBOP;
		break;
	case MJUM9BYTES:
		type = EXT_JUMBO9;
		break;
	case MJUM16BYTES:
		type = EXT_JUMBO16;
		break;
	default:
		panic("%s: invalid cluster size %d", __func__, size);
	}

	return (type);
}

/*
 * Associated an external reference counted buffer with an mbuf.
 */
static __inline void
m_extaddref(struct mbuf *m, char *buf, u_int size, u_int *ref_cnt,
    m_ext_free_t freef, void *arg1, void *arg2)
{

	KASSERT(ref_cnt != NULL, ("%s: ref_cnt not provided", __func__));

	atomic_add_int(ref_cnt, 1);
	m->m_flags |= M_EXT;
	m->m_ext.ext_buf = buf;
	m->m_ext.ext_cnt = ref_cnt;
	m->m_data = m->m_ext.ext_buf;
	m->m_ext.ext_size = size;
	m->m_ext.ext_free = freef;
	m->m_ext.ext_arg1 = arg1;
	m->m_ext.ext_arg2 = arg2;
	m->m_ext.ext_type = EXT_EXTREF;
	m->m_ext.ext_flags = 0;
}

static __inline uma_zone_t
m_getzone(int size)
{
	uma_zone_t zone;

	switch (size) {
	case MCLBYTES:
		zone = zone_clust;
		break;
	case MJUMPAGESIZE:
		zone = zone_jumbop;
		break;
	case MJUM9BYTES:
		zone = zone_jumbo9;
		break;
	case MJUM16BYTES:
		zone = zone_jumbo16;
		break;
	default:
		panic("%s: invalid cluster size %d", __func__, size);
	}

	return (zone);
}

/*
 * Initialize an mbuf with linear storage.
 *
 * Inline because the consumer text overhead will be roughly the same to
 * initialize or call a function with this many parameters and M_PKTHDR
 * should go away with constant propagation for !MGETHDR.
 */
static __inline int
m_init(struct mbuf *m, int how, short type, int flags)
{
	int error;

	m->m_next = NULL;
	m->m_nextpkt = NULL;
	m->m_data = m->m_dat;
	m->m_len = 0;
	m->m_flags = flags;
	m->m_type = type;
	if (flags & M_PKTHDR)
		error = m_pkthdr_init(m, how);
	else
		error = 0;

	MBUF_PROBE5(m__init, m, how, type, flags, error);
	return (error);
}

static __inline struct mbuf *
m_get_raw(int how, short type)
{
	struct mbuf *m;
	struct mb_args args;

	args.flags = 0;
	args.type = type | MT_NOINIT;
	m = uma_zalloc_arg(zone_mbuf, &args, how);
	MBUF_PROBE3(m__get_raw, how, type, m);
	return (m);
}

static __inline struct mbuf *
m_get(int how, short type)
{
	struct mbuf *m;
	struct mb_args args;

	args.flags = 0;
	args.type = type;
	m = uma_zalloc_arg(zone_mbuf, &args, how);
	MBUF_PROBE3(m__get, how, type, m);
	return (m);
}

static __inline struct mbuf *
m_gethdr_raw(int how, short type)
{
	struct mbuf *m;
	struct mb_args args;

	args.flags = M_PKTHDR;
	args.type = type | MT_NOINIT;
	m = uma_zalloc_arg(zone_mbuf, &args, how);
	MBUF_PROBE3(m__gethdr_raw, how, type, m);
	return (m);
}

static __inline struct mbuf *
m_gethdr(int how, short type)
{
	struct mbuf *m;
	struct mb_args args;

	args.flags = M_PKTHDR;
	args.type = type;
	m = uma_zalloc_arg(zone_mbuf, &args, how);
	MBUF_PROBE3(m__gethdr, how, type, m);
	return (m);
}

static __inline struct mbuf *
m_getcl(int how, short type, int flags)
{
	struct mbuf *m;
	struct mb_args args;

	args.flags = flags;
	args.type = type;
	m = uma_zalloc_arg(zone_pack, &args, how);
	MBUF_PROBE4(m__getcl, how, type, flags, m);
	return (m);
}

/*
 * XXX: m_cljset() is a dangerous API.  One must attach only a new,
 * unreferenced cluster to an mbuf(9).  It is not possible to assert
 * that, so care can be taken only by users of the API.
 */
static __inline void
m_cljset(struct mbuf *m, void *cl, int type)
{
	int size;

	switch (type) {
	case EXT_CLUSTER:
		size = MCLBYTES;
		break;
	case EXT_JUMBOP:
		size = MJUMPAGESIZE;
		break;
	case EXT_JUMBO9:
		size = MJUM9BYTES;
		break;
	case EXT_JUMBO16:
		size = MJUM16BYTES;
		break;
	default:
		panic("%s: unknown cluster type %d", __func__, type);
		break;
	}

	m->m_data = m->m_ext.ext_buf = cl;
	m->m_ext.ext_free = m->m_ext.ext_arg1 = m->m_ext.ext_arg2 = NULL;
	m->m_ext.ext_size = size;
	m->m_ext.ext_type = type;
	m->m_ext.ext_flags = EXT_FLAG_EMBREF;
	m->m_ext.ext_count = 1;
	m->m_flags |= M_EXT;
	MBUF_PROBE3(m__cljset, m, cl, type);
}

static __inline void
m_chtype(struct mbuf *m, short new_type)
{

	m->m_type = new_type;
}

static __inline void
m_clrprotoflags(struct mbuf *m)
{

	while (m) {
		m->m_flags &= ~M_PROTOFLAGS;
		m = m->m_next;
	}
}

static __inline struct mbuf *
m_last(struct mbuf *m)
{

	while (m->m_next)
		m = m->m_next;
	return (m);
}

static inline u_int
m_extrefcnt(struct mbuf *m)
{

	KASSERT(m->m_flags & M_EXT, ("%s: M_EXT missing", __func__));

	return ((m->m_ext.ext_flags & EXT_FLAG_EMBREF) ? m->m_ext.ext_count :
	    *m->m_ext.ext_cnt);
}

/*
 * mbuf, cluster, and external object allocation macros (for compatibility
 * purposes).
 */
#define	M_MOVE_PKTHDR(to, from)	m_move_pkthdr((to), (from))
#define	MGET(m, how, type)	((m) = m_get((how), (type)))
#define	MGETHDR(m, how, type)	((m) = m_gethdr((how), (type)))
#define	MCLGET(m, how)		m_clget((m), (how))
#define	MEXTADD(m, buf, size, free, arg1, arg2, flags, type)		\
    m_extadd((m), (char *)(buf), (size), (free), (arg1), (arg2),	\
    (flags), (type))
#define	m_getm(m, len, how, type)					\
    m_getm2((m), (len), (how), (type), M_PKTHDR)

/*
 * Evaluate TRUE if it's safe to write to the mbuf m's data region (this can
 * be both the local data payload, or an external buffer area, depending on
 * whether M_EXT is set).
 */
#define	M_WRITABLE(m)	(((m)->m_flags & (M_RDONLY | M_EXTPG)) == 0 &&	\
			 (!(((m)->m_flags & M_EXT)) ||			\
			 (m_extrefcnt(m) == 1)))

/* Check if the supplied mbuf has a packet header, or else panic. */
#define	M_ASSERTPKTHDR(m)						\
	KASSERT((m) != NULL && (m)->m_flags & M_PKTHDR,			\
	    ("%s: no mbuf packet header!", __func__))

/* Check if the supplied mbuf has no send tag, or else panic. */
#define	M_ASSERT_NO_SND_TAG(m)						\
	KASSERT((m) != NULL && (m)->m_flags & M_PKTHDR &&		\
	       ((m)->m_pkthdr.csum_flags & CSUM_SND_TAG) == 0,		\
	    ("%s: receive mbuf has send tag!", __func__))

/* Check if mbuf is multipage. */
#define M_ASSERTEXTPG(m)						\
	KASSERT(((m)->m_flags & (M_EXTPG|M_PKTHDR)) == M_EXTPG,		\
	    ("%s: m %p is not multipage!", __func__, m))

/*
 * Ensure that the supplied mbuf is a valid, non-free mbuf.
 *
 * XXX: Broken at the moment.  Need some UMA magic to make it work again.
 */
#define	M_ASSERTVALID(m)						\
	KASSERT((((struct mbuf *)m)->m_flags & 0) == 0,			\
	    ("%s: attempted use of a free mbuf!", __func__))

/* Check whether any mbuf in the chain is unmapped. */
#ifdef INVARIANTS
#define	M_ASSERTMAPPED(m) do {						\
	for (struct mbuf *__m = (m); __m != NULL; __m = __m->m_next)	\
		KASSERT((__m->m_flags & M_EXTPG) == 0,			\
		    ("%s: chain %p contains an unmapped mbuf", __func__, (m)));\
} while (0)
#else
#define	M_ASSERTMAPPED(m) do {} while (0)
#endif

/*
 * Return the address of the start of the buffer associated with an mbuf,
 * handling external storage, packet-header mbufs, and regular data mbufs.
 */
#define	M_START(m)							\
	(((m)->m_flags & M_EXTPG) ? NULL :				\
	 ((m)->m_flags & M_EXT) ? (m)->m_ext.ext_buf :			\
	 ((m)->m_flags & M_PKTHDR) ? &(m)->m_pktdat[0] :		\
	 &(m)->m_dat[0])

/*
 * Return the size of the buffer associated with an mbuf, handling external
 * storage, packet-header mbufs, and regular data mbufs.
 */
#define	M_SIZE(m)							\
	(((m)->m_flags & M_EXT) ? (m)->m_ext.ext_size :			\
	 ((m)->m_flags & M_PKTHDR) ? MHLEN :				\
	 MLEN)

/*
 * Set the m_data pointer of a newly allocated mbuf to place an object of the
 * specified size at the end of the mbuf, longword aligned.
 *
 * NB: Historically, we had M_ALIGN(), MH_ALIGN(), and MEXT_ALIGN() as
 * separate macros, each asserting that it was called at the proper moment.
 * This required callers to themselves test the storage type and call the
 * right one.  Rather than require callers to be aware of those layout
 * decisions, we centralize here.
 */
static __inline void
m_align(struct mbuf *m, int len)
{
#ifdef INVARIANTS
	const char *msg = "%s: not a virgin mbuf";
#endif
	int adjust;

	KASSERT(m->m_data == M_START(m), (msg, __func__));

	adjust = M_SIZE(m) - len;
	m->m_data += adjust &~ (sizeof(long)-1);
}

#define	M_ALIGN(m, len)		m_align(m, len)
#define	MH_ALIGN(m, len)	m_align(m, len)
#define	MEXT_ALIGN(m, len)	m_align(m, len)

/*
 * Compute the amount of space available before the current start of data in
 * an mbuf.
 *
 * The M_WRITABLE() is a temporary, conservative safety measure: the burden
 * of checking writability of the mbuf data area rests solely with the caller.
 *
 * NB: In previous versions, M_LEADINGSPACE() would only check M_WRITABLE()
 * for mbufs with external storage.  We now allow mbuf-embedded data to be
 * read-only as well.
 */
#define	M_LEADINGSPACE(m)						\
	(M_WRITABLE(m) ? ((m)->m_data - M_START(m)) : 0)

/*
 * So M_TRAILINGROOM() is for when you want to know how much space
 * would be there if it was writable. This can be used to
 * detect changes in mbufs by knowing the value at one point
 * and then being able to compare it later to the current M_TRAILINGROOM().
 * The TRAILINGSPACE() macro is not suitable for this since an mbuf
 * at one point might not be writable and then later it becomes writable
 * even though the space at the back of it has not changed.
 */
#define M_TRAILINGROOM(m) ((M_START(m) + M_SIZE(m)) - ((m)->m_data + (m)->m_len))
/*
 * Compute the amount of space available after the end of data in an mbuf.
 *
 * The M_WRITABLE() is a temporary, conservative safety measure: the burden
 * of checking writability of the mbuf data area rests solely with the caller.
 *
 * NB: In previous versions, M_TRAILINGSPACE() would only check M_WRITABLE()
 * for mbufs with external storage.  We now allow mbuf-embedded data to be
 * read-only as well.
 */
#define	M_TRAILINGSPACE(m) (M_WRITABLE(m) ? M_TRAILINGROOM(m) : 0)

/*
 * Arrange to prepend space of size plen to mbuf m.  If a new mbuf must be
 * allocated, how specifies whether to wait.  If the allocation fails, the
 * original mbuf chain is freed and m is set to NULL.
 */
#define	M_PREPEND(m, plen, how) do {					\
	struct mbuf **_mmp = &(m);					\
	struct mbuf *_mm = *_mmp;					\
	int _mplen = (plen);						\
	int __mhow = (how);						\
									\
	MBUF_CHECKSLEEP(how);						\
	if (M_LEADINGSPACE(_mm) >= _mplen) {				\
		_mm->m_data -= _mplen;					\
		_mm->m_len += _mplen;					\
	} else								\
		_mm = m_prepend(_mm, _mplen, __mhow);			\
	if (_mm != NULL && _mm->m_flags & M_PKTHDR)			\
		_mm->m_pkthdr.len += _mplen;				\
	*_mmp = _mm;							\
} while (0)

/*
 * Change mbuf to new type.  This is a relatively expensive operation and
 * should be avoided.
 */
#define	MCHTYPE(m, t)	m_chtype((m), (t))

/* Return the rcvif of a packet header. */
static __inline struct ifnet *
m_rcvif(struct mbuf *m)
{

	M_ASSERTPKTHDR(m);
	if (m->m_pkthdr.csum_flags & CSUM_SND_TAG)
		return (NULL);
	return (m->m_pkthdr.rcvif);
}

/* Length to m_copy to copy all. */
#define	M_COPYALL	1000000000

extern u_int		max_linkhdr;	/* Largest link-level header */
extern u_int		max_hdr;	/* Largest link + protocol header */
extern u_int		max_protohdr;	/* Largest protocol header */
void max_linkhdr_grow(u_int);
void max_protohdr_grow(u_int);

extern int		nmbclusters;	/* Maximum number of clusters */
extern bool		mb_use_ext_pgs;	/* Use ext_pgs for sendfile */

/*-
 * Network packets may have annotations attached by affixing a list of
 * "packet tags" to the pkthdr structure.  Packet tags are dynamically
 * allocated semi-opaque data structures that have a fixed header
 * (struct m_tag) that specifies the size of the memory block and a
 * <cookie,type> pair that identifies it.  The cookie is a 32-bit unique
 * unsigned value used to identify a module or ABI.  By convention this value
 * is chosen as the date+time that the module is created, expressed as the
 * number of seconds since the epoch (e.g., using date -u +'%s').  The type
 * value is an ABI/module-specific value that identifies a particular
 * annotation and is private to the module.  For compatibility with systems
 * like OpenBSD that define packet tags w/o an ABI/module cookie, the value
 * PACKET_ABI_COMPAT is used to implement m_tag_get and m_tag_find
 * compatibility shim functions and several tag types are defined below.
 * Users that do not require compatibility should use a private cookie value
 * so that packet tag-related definitions can be maintained privately.
 *
 * Note that the packet tag returned by m_tag_alloc has the default memory
 * alignment implemented by malloc.  To reference private data one can use a
 * construct like:
 *
 *	struct m_tag *mtag = m_tag_alloc(...);
 *	struct foo *p = (struct foo *)(mtag+1);
 *
 * if the alignment of struct m_tag is sufficient for referencing members of
 * struct foo.  Otherwise it is necessary to embed struct m_tag within the
 * private data structure to insure proper alignment; e.g.,
 *
 *	struct foo {
 *		struct m_tag	tag;
 *		...
 *	};
 *	struct foo *p = (struct foo *) m_tag_alloc(...);
 *	struct m_tag *mtag = &p->tag;
 */

/*
 * Persistent tags stay with an mbuf until the mbuf is reclaimed.  Otherwise
 * tags are expected to ``vanish'' when they pass through a network
 * interface.  For most interfaces this happens normally as the tags are
 * reclaimed when the mbuf is free'd.  However in some special cases
 * reclaiming must be done manually.  An example is packets that pass through
 * the loopback interface.  Also, one must be careful to do this when
 * ``turning around'' packets (e.g., icmp_reflect).
 *
 * To mark a tag persistent bit-or this flag in when defining the tag id.
 * The tag will then be treated as described above.
 */
#define	MTAG_PERSISTENT				0x800

#define	PACKET_TAG_NONE				0  /* Nadda */

/* Packet tags for use with PACKET_ABI_COMPAT. */
#define	PACKET_TAG_IPSEC_IN_DONE		1  /* IPsec applied, in */
#define	PACKET_TAG_IPSEC_OUT_DONE		2  /* IPsec applied, out */
#define	PACKET_TAG_IPSEC_IN_CRYPTO_DONE		3  /* NIC IPsec crypto done */
#define	PACKET_TAG_IPSEC_OUT_CRYPTO_NEEDED	4  /* NIC IPsec crypto req'ed */
#define	PACKET_TAG_IPSEC_IN_COULD_DO_CRYPTO	5  /* NIC notifies IPsec */
#define	PACKET_TAG_IPSEC_PENDING_TDB		6  /* Reminder to do IPsec */
#define	PACKET_TAG_BRIDGE			7  /* Bridge processing done */
#define	PACKET_TAG_GIF				8  /* GIF processing done */
#define	PACKET_TAG_GRE				9  /* GRE processing done */
#define	PACKET_TAG_IN_PACKET_CHECKSUM		10 /* NIC checksumming done */
#define	PACKET_TAG_ENCAP			11 /* Encap.  processing */
#define	PACKET_TAG_IPSEC_SOCKET			12 /* IPSEC socket ref */
#define	PACKET_TAG_IPSEC_HISTORY		13 /* IPSEC history */
#define	PACKET_TAG_IPV6_INPUT			14 /* IPV6 input processing */
#define	PACKET_TAG_DUMMYNET			15 /* dummynet info */
#define	PACKET_TAG_DIVERT			17 /* divert info */
#define	PACKET_TAG_IPFORWARD			18 /* ipforward info */
#define	PACKET_TAG_MACLABEL	(19 | MTAG_PERSISTENT) /* MAC label */
#define	PACKET_TAG_PF				21 /* PF/ALTQ information */
/* was	PACKET_TAG_RTSOCKFAM			25    rtsock sa family */
#define	PACKET_TAG_IPOPTIONS			27 /* Saved IP options */
#define	PACKET_TAG_CARP				28 /* CARP info */
#define	PACKET_TAG_IPSEC_NAT_T_PORTS		29 /* two uint16_t */
#define	PACKET_TAG_ND_OUTGOING			30 /* ND outgoing */
#define	PACKET_TAG_PF_REASSEMBLED		31

/* Specific cookies and tags. */

/* Packet tag routines. */
struct m_tag	*m_tag_alloc(uint32_t, uint16_t, int, int);
void		 m_tag_delete(struct mbuf *, struct m_tag *);
void		 m_tag_delete_chain(struct mbuf *, struct m_tag *);
void		 m_tag_free_default(struct m_tag *);
struct m_tag	*m_tag_locate(struct mbuf *, uint32_t, uint16_t,
    struct m_tag *);
struct m_tag	*m_tag_copy(struct m_tag *, int);
int		 m_tag_copy_chain(struct mbuf *, const struct mbuf *, int);
void		 m_tag_delete_nonpersistent(struct mbuf *);

/*
 * Initialize the list of tags associated with an mbuf.
 */
static __inline void
m_tag_init(struct mbuf *m)
{

	SLIST_INIT(&m->m_pkthdr.tags);
}

/*
 * Set up the contents of a tag.  Note that this does not fill in the free
 * method; the caller is expected to do that.
 *
 * XXX probably should be called m_tag_init, but that was already taken.
 */
static __inline void
m_tag_setup(struct m_tag *t, uint32_t cookie, uint16_t type, int len)
{

	t->m_tag_id = type;
	t->m_tag_len = len;
	t->m_tag_cookie = cookie;
}

/*
 * Reclaim resources associated with a tag.
 */
static __inline void
m_tag_free(struct m_tag *t)
{

	(*t->m_tag_free)(t);
}

/*
 * Return the first tag associated with an mbuf.
 */
static __inline struct m_tag *
m_tag_first(struct mbuf *m)
{

	return (SLIST_FIRST(&m->m_pkthdr.tags));
}

/*
 * Return the next tag in the list of tags associated with an mbuf.
 */
static __inline struct m_tag *
m_tag_next(struct mbuf *m __unused, struct m_tag *t)
{

	return (SLIST_NEXT(t, m_tag_link));
}

/*
 * Prepend a tag to the list of tags associated with an mbuf.
 */
static __inline void
m_tag_prepend(struct mbuf *m, struct m_tag *t)
{

	SLIST_INSERT_HEAD(&m->m_pkthdr.tags, t, m_tag_link);
}

/*
 * Unlink a tag from the list of tags associated with an mbuf.
 */
static __inline void
m_tag_unlink(struct mbuf *m, struct m_tag *t)
{

	SLIST_REMOVE(&m->m_pkthdr.tags, t, m_tag, m_tag_link);
}

/* These are for OpenBSD compatibility. */
#define	MTAG_ABI_COMPAT		0		/* compatibility ABI */

static __inline struct m_tag *
m_tag_get(uint16_t type, int length, int wait)
{
	return (m_tag_alloc(MTAG_ABI_COMPAT, type, length, wait));
}

static __inline struct m_tag *
m_tag_find(struct mbuf *m, uint16_t type, struct m_tag *start)
{
	return (SLIST_EMPTY(&m->m_pkthdr.tags) ? (struct m_tag *)NULL :
	    m_tag_locate(m, MTAG_ABI_COMPAT, type, start));
}

static inline struct m_snd_tag *
m_snd_tag_ref(struct m_snd_tag *mst)
{

	refcount_acquire(&mst->refcount);
	return (mst);
}

static inline void
m_snd_tag_rele(struct m_snd_tag *mst)
{

	if (refcount_release(&mst->refcount))
		m_snd_tag_destroy(mst);
}

static __inline struct mbuf *
m_free(struct mbuf *m)
{
	struct mbuf *n = m->m_next;

	MBUF_PROBE1(m__free, m);
	if ((m->m_flags & (M_PKTHDR|M_NOFREE)) == (M_PKTHDR|M_NOFREE))
		m_tag_delete_chain(m, NULL);
	if (m->m_flags & M_PKTHDR && m->m_pkthdr.csum_flags & CSUM_SND_TAG)
		m_snd_tag_rele(m->m_pkthdr.snd_tag);
	if (m->m_flags & M_EXTPG)
		mb_free_extpg(m);
	else if (m->m_flags & M_EXT)
		mb_free_ext(m);
	else if ((m->m_flags & M_NOFREE) == 0)
		uma_zfree(zone_mbuf, m);
	return (n);
}

static __inline int
rt_m_getfib(struct mbuf *m)
{
	KASSERT(m->m_flags & M_PKTHDR , ("Attempt to get FIB from non header mbuf."));
	return (m->m_pkthdr.fibnum);
}

#define M_GETFIB(_m)   rt_m_getfib(_m)

#define M_SETFIB(_m, _fib) do {						\
        KASSERT((_m)->m_flags & M_PKTHDR, ("Attempt to set FIB on non header mbuf."));	\
	((_m)->m_pkthdr.fibnum) = (_fib);				\
} while (0)

/* flags passed as first argument for "m_xxx_tcpip_hash()" */
#define	MBUF_HASHFLAG_L2	(1 << 2)
#define	MBUF_HASHFLAG_L3	(1 << 3)
#define	MBUF_HASHFLAG_L4	(1 << 4)

/* mbuf hashing helper routines */
uint32_t	m_ether_tcpip_hash_init(void);
uint32_t	m_ether_tcpip_hash(const uint32_t, const struct mbuf *, uint32_t);
uint32_t	m_infiniband_tcpip_hash_init(void);
uint32_t	m_infiniband_tcpip_hash(const uint32_t, const struct mbuf *, uint32_t);

#ifdef MBUF_PROFILING
 void m_profile(struct mbuf *m);
 #define M_PROFILE(m) m_profile(m)
#else
 #define M_PROFILE(m)
#endif

struct mbufq {
	STAILQ_HEAD(, mbuf)	mq_head;
	int			mq_len;
	int			mq_maxlen;
};

static inline void
mbufq_init(struct mbufq *mq, int maxlen)
{

	STAILQ_INIT(&mq->mq_head);
	mq->mq_maxlen = maxlen;
	mq->mq_len = 0;
}

static inline struct mbuf *
mbufq_flush(struct mbufq *mq)
{
	struct mbuf *m;

	m = STAILQ_FIRST(&mq->mq_head);
	STAILQ_INIT(&mq->mq_head);
	mq->mq_len = 0;
	return (m);
}

static inline void
mbufq_drain(struct mbufq *mq)
{
	struct mbuf *m, *n;

	n = mbufq_flush(mq);
	while ((m = n) != NULL) {
		n = STAILQ_NEXT(m, m_stailqpkt);
		m_freem(m);
	}
}

static inline struct mbuf *
mbufq_first(const struct mbufq *mq)
{

	return (STAILQ_FIRST(&mq->mq_head));
}

static inline struct mbuf *
mbufq_last(const struct mbufq *mq)
{

	return (STAILQ_LAST(&mq->mq_head, mbuf, m_stailqpkt));
}

static inline bool
mbufq_empty(const struct mbufq *mq)
{
	return (mq->mq_len == 0);
}

static inline int
mbufq_full(const struct mbufq *mq)
{

	return (mq->mq_maxlen > 0 && mq->mq_len >= mq->mq_maxlen);
}

static inline int
mbufq_len(const struct mbufq *mq)
{

	return (mq->mq_len);
}

static inline int
mbufq_enqueue(struct mbufq *mq, struct mbuf *m)
{

	if (mbufq_full(mq))
		return (ENOBUFS);
	STAILQ_INSERT_TAIL(&mq->mq_head, m, m_stailqpkt);
	mq->mq_len++;
	return (0);
}

static inline struct mbuf *
mbufq_dequeue(struct mbufq *mq)
{
	struct mbuf *m;

	m = STAILQ_FIRST(&mq->mq_head);
	if (m) {
		STAILQ_REMOVE_HEAD(&mq->mq_head, m_stailqpkt);
		m->m_nextpkt = NULL;
		mq->mq_len--;
	}
	return (m);
}

static inline void
mbufq_prepend(struct mbufq *mq, struct mbuf *m)
{

	STAILQ_INSERT_HEAD(&mq->mq_head, m, m_stailqpkt);
	mq->mq_len++;
}

/*
 * Note: this doesn't enforce the maximum list size for dst.
 */
static inline void
mbufq_concat(struct mbufq *mq_dst, struct mbufq *mq_src)
{

	mq_dst->mq_len += mq_src->mq_len;
	STAILQ_CONCAT(&mq_dst->mq_head, &mq_src->mq_head);
	mq_src->mq_len = 0;
}

#ifdef _SYS_TIMESPEC_H_
static inline void
mbuf_tstmp2timespec(struct mbuf *m, struct timespec *ts)
{

	KASSERT((m->m_flags & M_PKTHDR) != 0, ("mbuf %p no M_PKTHDR", m));
	KASSERT((m->m_flags & (M_TSTMP|M_TSTMP_LRO)) != 0,
	    ("mbuf %p no M_TSTMP or M_TSTMP_LRO", m));
	ts->tv_sec = m->m_pkthdr.rcv_tstmp / 1000000000;
	ts->tv_nsec = m->m_pkthdr.rcv_tstmp % 1000000000;
}
#endif

static inline void
mbuf_tstmp2timeval(struct mbuf *m, struct timeval *tv)
{

	KASSERT((m->m_flags & M_PKTHDR) != 0, ("mbuf %p no M_PKTHDR", m));
	KASSERT((m->m_flags & (M_TSTMP|M_TSTMP_LRO)) != 0,
	    ("mbuf %p no M_TSTMP or M_TSTMP_LRO", m));
	tv->tv_sec = m->m_pkthdr.rcv_tstmp / 1000000000;
	tv->tv_usec = (m->m_pkthdr.rcv_tstmp % 1000000000) / 1000;
}

#ifdef DEBUGNET
/* Invoked from the debugnet client code. */
void	debugnet_mbuf_drain(void);
void	debugnet_mbuf_start(void);
void	debugnet_mbuf_finish(void);
void	debugnet_mbuf_reinit(int nmbuf, int nclust, int clsize);
#endif

static inline bool
mbuf_has_tls_session(struct mbuf *m)
{

	if (m->m_flags & M_EXTPG) {
		if (m->m_epg_tls != NULL) {
			return (true);
		}
	}
	return (false);
}

#endif /* _KERNEL */
#endif /* !_SYS_MBUF_H_ */