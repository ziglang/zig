/*	$NetBSD: mbuf.h,v 1.237 2022/12/16 08:42:55 msaitoh Exp $	*/

/*
 * Copyright (c) 1996, 1997, 1999, 2001, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center and Matt Thomas of 3am Software Foundry.
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

/*
 * Copyright (c) 1982, 1986, 1988, 1993
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
 *	@(#)mbuf.h	8.5 (Berkeley) 2/19/95
 */

#ifndef _SYS_MBUF_H_
#define _SYS_MBUF_H_

#ifdef _KERNEL_OPT
#include "opt_mbuftrace.h"
#endif

#ifndef M_WAITOK
#include <sys/malloc.h>
#endif
#include <sys/pool.h>
#include <sys/queue.h>
#if defined(_KERNEL)
#include <sys/percpu_types.h>
#include <sys/socket.h>	/* for AF_UNSPEC */
#include <sys/psref.h>
#endif /* defined(_KERNEL) */

/* For offsetof() */
#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/systm.h>
#else
#include <stddef.h>
#endif

#include <uvm/uvm_param.h>	/* for MIN_PAGE_SIZE */

#include <net/if.h>

/*
 * Mbufs are of a single size, MSIZE (machine/param.h), which
 * includes overhead.  An mbuf may add a single "mbuf cluster" of size
 * MCLBYTES (also in machine/param.h), which has no additional overhead
 * and is used instead of the internal data area; this is done when
 * at least MINCLSIZE of data must be stored.
 */

/* Packet tags structure */
struct m_tag {
	SLIST_ENTRY(m_tag)	m_tag_link;	/* List of packet tags */
	uint16_t		m_tag_id;	/* Tag ID */
	uint16_t		m_tag_len;	/* Length of data */
};

/* mbuf ownership structure */
struct mowner {
	char mo_name[16];		/* owner name (fxp0) */
	char mo_descr[16];		/* owner description (input) */
	LIST_ENTRY(mowner) mo_link;	/* */
	struct percpu *mo_counters;
};

#define MOWNER_INIT(x, y) { .mo_name = x, .mo_descr = y }

enum mowner_counter_index {
	MOWNER_COUNTER_CLAIMS,		/* # of small mbuf claimed */
	MOWNER_COUNTER_RELEASES,	/* # of small mbuf released */
	MOWNER_COUNTER_CLUSTER_CLAIMS,	/* # of cluster mbuf claimed */
	MOWNER_COUNTER_CLUSTER_RELEASES,/* # of cluster mbuf released */
	MOWNER_COUNTER_EXT_CLAIMS,	/* # of M_EXT mbuf claimed */
	MOWNER_COUNTER_EXT_RELEASES,	/* # of M_EXT mbuf released */

	MOWNER_COUNTER_NCOUNTERS,
};

#if defined(_KERNEL)
struct mowner_counter {
	u_long mc_counter[MOWNER_COUNTER_NCOUNTERS];
};
#endif

/* userland-exported version of struct mowner */
struct mowner_user {
	char mo_name[16];		/* owner name (fxp0) */
	char mo_descr[16];		/* owner description (input) */
	LIST_ENTRY(mowner) mo_link;	/* unused padding; for compatibility */
	u_long mo_counter[MOWNER_COUNTER_NCOUNTERS]; /* counters */
};

/*
 * Macros for type conversion
 * mtod(m,t) -	convert mbuf pointer to data pointer of correct type
 */
#define mtod(m, t)	((t)((m)->m_data))

/* header at beginning of each mbuf */
struct m_hdr {
	struct	mbuf *mh_next;		/* next buffer in chain */
	struct	mbuf *mh_nextpkt;	/* next chain in queue/record */
	char	*mh_data;		/* location of data */
	struct	mowner *mh_owner;	/* mbuf owner */
	int	mh_len;			/* amount of data in this mbuf */
	int	mh_flags;		/* flags; see below */
	paddr_t	mh_paddr;		/* physical address of mbuf */
	short	mh_type;		/* type of data in this mbuf */
};

/*
 * record/packet header in first mbuf of chain; valid if M_PKTHDR set
 *
 * A note about csum_data:
 *
 *  o For the out-bound direction, the low 16 bits indicates the offset after
 *    the L4 header where the final L4 checksum value is to be stored and the
 *    high 16 bits is the length of the L3 header (the start of the data to
 *    be checksummed).
 *
 *  o For the in-bound direction, it is only valid if the M_CSUM_DATA flag is
 *    set. In this case, an L4 checksum has been calculated by hardware and
 *    is stored in csum_data, but it is up to software to perform final
 *    verification.
 *
 * Note for in-bound TCP/UDP checksums: we expect the csum_data to NOT
 * be bit-wise inverted (the final step in the calculation of an IP
 * checksum) -- this is so we can accumulate the checksum for fragmented
 * packets during reassembly.
 *
 * Size ILP32: 40
 *       LP64: 56
 */
struct pkthdr {
	union {
		void		*ctx;		/* for M_GETCTX/M_SETCTX */
		if_index_t	index;		/* rcv interface index */
	} _rcvif;
#define rcvif_index		_rcvif.index
	SLIST_HEAD(packet_tags, m_tag) tags;	/* list of packet tags */
	int		len;			/* total packet length */
	int		csum_flags;		/* checksum flags */
	uint32_t	csum_data;		/* checksum data */
	u_int		segsz;			/* segment size */
	uint16_t	ether_vtag;		/* ethernet 802.1p+q vlan tag */
	uint16_t	pkthdr_flags;		/* flags for pkthdr, see blow */
#define PKTHDR_FLAG_IPSEC_SKIP_PFIL	0x0001	/* skip pfil_run_hooks() after ipsec decrypt */

	/*
	 * Following three fields are open-coded struct altq_pktattr
	 * to rearrange struct pkthdr fields flexibly.
	 */
	int	pattr_af;		/* ALTQ: address family */
	void	*pattr_class;		/* ALTQ: sched class set by classifier */
	void	*pattr_hdr;		/* ALTQ: saved header position in mbuf */
};

/* Checksumming flags (csum_flags). */
#define M_CSUM_TCPv4		0x00000001	/* TCP header/payload */
#define M_CSUM_UDPv4		0x00000002	/* UDP header/payload */
#define M_CSUM_TCP_UDP_BAD	0x00000004	/* TCP/UDP checksum bad */
#define M_CSUM_DATA		0x00000008	/* consult csum_data */
#define M_CSUM_TCPv6		0x00000010	/* IPv6 TCP header/payload */
#define M_CSUM_UDPv6		0x00000020	/* IPv6 UDP header/payload */
#define M_CSUM_IPv4		0x00000040	/* IPv4 header */
#define M_CSUM_IPv4_BAD		0x00000080	/* IPv4 header checksum bad */
#define M_CSUM_TSOv4		0x00000100	/* TCPv4 segmentation offload */
#define M_CSUM_TSOv6		0x00000200	/* TCPv6 segmentation offload */

/* Checksum-assist quirks: keep separate from jump-table bits. */
#define M_CSUM_BLANK		0x40000000	/* csum is missing */
#define M_CSUM_NO_PSEUDOHDR	0x80000000	/* Rx csum_data does not include
						 * the UDP/TCP pseudo-hdr, and
						 * is not yet 1s-complemented.
						 */

#define M_CSUM_BITS \
    "\20\1TCPv4\2UDPv4\3TCP_UDP_BAD\4DATA\5TCPv6\6UDPv6\7IPv4\10IPv4_BAD" \
    "\11TSOv4\12TSOv6\39BLANK\40NO_PSEUDOHDR"

/*
 * Macros for manipulating csum_data on outgoing packets. These are
 * used to pass information down from the L4/L3 to the L2.
 *
 *   _IPHL:   Length of the IPv{4/6} header, plus the options; in other
 *            words the offset of the UDP/TCP header in the packet.
 *   _OFFSET: Offset of the checksum field in the UDP/TCP header.
 */
#define M_CSUM_DATA_IPv4_IPHL(x)	((x) >> 16)
#define M_CSUM_DATA_IPv4_OFFSET(x)	((x) & 0xffff)
#define M_CSUM_DATA_IPv6_IPHL(x)	((x) >> 16)
#define M_CSUM_DATA_IPv6_OFFSET(x)	((x) & 0xffff)
#define M_CSUM_DATA_IPv6_SET(x, v)	(x) = ((x) & 0xffff) | ((v) << 16)

/*
 * Max # of pages we can attach to m_ext.  This is carefully chosen
 * to be able to handle SOSEND_LOAN_CHUNK with our minimum sized page.
 */
#ifdef MIN_PAGE_SIZE
#define M_EXT_MAXPAGES		((65536 / MIN_PAGE_SIZE) + 1)
#endif

/*
 * Description of external storage mapped into mbuf, valid if M_EXT set.
 */
struct _m_ext_storage {
	unsigned int ext_refcnt;
	char *ext_buf;			/* start of buffer */
	void (*ext_free)		/* free routine if not the usual */
		(struct mbuf *, void *, size_t, void *);
	void *ext_arg;			/* argument for ext_free */
	size_t ext_size;		/* size of buffer, for ext_free */

	union {
		/* M_EXT_CLUSTER: physical address */
		paddr_t extun_paddr;
#ifdef M_EXT_MAXPAGES
		/* M_EXT_PAGES: pages */
		struct vm_page *extun_pgs[M_EXT_MAXPAGES];
#endif
	} ext_un;
#define ext_paddr	ext_un.extun_paddr
#define ext_pgs		ext_un.extun_pgs
};

struct _m_ext {
	struct mbuf *ext_ref;
	struct _m_ext_storage ext_storage;
};

#define M_PADDR_INVALID		POOL_PADDR_INVALID

/*
 * Definition of "struct mbuf".
 * Don't change this without understanding how MHLEN/MLEN are defined.
 */
#define MBUF_DEFINE(name, mhlen, mlen)					\
	struct name {							\
		struct m_hdr m_hdr;					\
		union {							\
			struct {					\
				struct pkthdr MH_pkthdr;		\
				union {					\
					struct _m_ext MH_ext;		\
					char MH_databuf[(mhlen)];	\
				} MH_dat;				\
			} MH;						\
			char M_databuf[(mlen)];				\
		} M_dat;						\
	}
#define m_next		m_hdr.mh_next
#define m_len		m_hdr.mh_len
#define m_data		m_hdr.mh_data
#define m_owner		m_hdr.mh_owner
#define m_type		m_hdr.mh_type
#define m_flags		m_hdr.mh_flags
#define m_nextpkt	m_hdr.mh_nextpkt
#define m_paddr		m_hdr.mh_paddr
#define m_pkthdr	M_dat.MH.MH_pkthdr
#define m_ext_storage	M_dat.MH.MH_dat.MH_ext.ext_storage
#define m_ext_ref	M_dat.MH.MH_dat.MH_ext.ext_ref
#define m_ext		m_ext_ref->m_ext_storage
#define m_pktdat	M_dat.MH.MH_dat.MH_databuf
#define m_dat		M_dat.M_databuf

/*
 * Dummy mbuf structure to calculate the right values for MLEN/MHLEN, taking
 * into account inter-structure padding.
 */
MBUF_DEFINE(_mbuf_dummy, 1, 1);

/* normal data len */
#define MLEN		((int)(MSIZE - offsetof(struct _mbuf_dummy, m_dat)))
/* data len w/pkthdr */
#define MHLEN		((int)(MSIZE - offsetof(struct _mbuf_dummy, m_pktdat)))

#define MINCLSIZE	(MHLEN+MLEN+1)	/* smallest amount to put in cluster */

/*
 * The *real* struct mbuf
 */
MBUF_DEFINE(mbuf, MHLEN, MLEN);

/* mbuf flags */
#define M_EXT		0x00000001	/* has associated external storage */
#define M_PKTHDR	0x00000002	/* start of record */
#define M_EOR		0x00000004	/* end of record */
#define M_PROTO1	0x00000008	/* protocol-specific */

/* mbuf pkthdr flags, also in m_flags */
#define M_AUTHIPHDR	0x00000010	/* authenticated (IPsec) */
#define M_DECRYPTED	0x00000020	/* decrypted (IPsec) */
#define M_LOOP		0x00000040	/* received on loopback */
#define M_BCAST		0x00000100	/* send/received as L2 broadcast */
#define M_MCAST		0x00000200	/* send/received as L2 multicast */
#define M_CANFASTFWD	0x00000400	/* packet can be fast-forwarded */
#define M_ANYCAST6	0x00000800	/* received as IPv6 anycast */

#define M_LINK0		0x00001000	/* link layer specific flag */
#define M_LINK1		0x00002000	/* link layer specific flag */
#define M_LINK2		0x00004000	/* link layer specific flag */
#define M_LINK3		0x00008000	/* link layer specific flag */
#define M_LINK4		0x00010000	/* link layer specific flag */
#define M_LINK5		0x00020000	/* link layer specific flag */
#define M_LINK6		0x00040000	/* link layer specific flag */
#define M_LINK7		0x00080000	/* link layer specific flag */

#define M_VLANTAG	0x00100000	/* ether_vtag is valid */

/* additional flags for M_EXT mbufs */
#define M_EXT_FLAGS	0xff000000
#define M_EXT_CLUSTER	0x01000000	/* ext is a cluster */
#define M_EXT_PAGES	0x02000000	/* ext_pgs is valid */
#define M_EXT_ROMAP	0x04000000	/* ext mapping is r-o at MMU */
#define M_EXT_RW	0x08000000	/* ext storage is writable */

/* for source-level compatibility */
#define M_NOTIFICATION	M_PROTO1

#define M_FLAGS_BITS \
    "\20\1EXT\2PKTHDR\3EOR\4PROTO1\5AUTHIPHDR\6DECRYPTED\7LOOP\10NONE" \
    "\11BCAST\12MCAST\13CANFASTFWD\14ANYCAST6\15LINK0\16LINK1\17LINK2\20LINK3" \
    "\21LINK4\22LINK5\23LINK6\24LINK7" \
    "\25VLANTAG" \
    "\31EXT_CLUSTER\32EXT_PAGES\33EXT_ROMAP\34EXT_RW"

/* flags copied when copying m_pkthdr */
#define M_COPYFLAGS	(M_PKTHDR|M_EOR|M_BCAST|M_MCAST|M_CANFASTFWD| \
    M_ANYCAST6|M_LINK0|M_LINK1|M_LINK2|M_AUTHIPHDR|M_DECRYPTED|M_LOOP| \
    M_VLANTAG)

/* flag copied when shallow-copying external storage */
#define M_EXTCOPYFLAGS	(M_EXT|M_EXT_FLAGS)

/* mbuf types */
#define MT_FREE		0	/* should be on free list */
#define MT_DATA		1	/* dynamic (data) allocation */
#define MT_HEADER	2	/* packet header */
#define MT_SONAME	3	/* socket name */
#define MT_SOOPTS	4	/* socket options */
#define MT_FTABLE	5	/* fragment reassembly header */
#define MT_CONTROL	6	/* extra-data protocol message */
#define MT_OOBDATA	7	/* expedited data  */

#ifdef MBUFTYPES
const char * const mbuftypes[] = {
	"mbfree",
	"mbdata",
	"mbheader",
	"mbsoname",
	"mbsopts",
	"mbftable",
	"mbcontrol",
	"mboobdata",
};
#else
extern const char * const mbuftypes[];
#endif

/* flags to m_get/MGET */
#define M_DONTWAIT	M_NOWAIT
#define M_WAIT		M_WAITOK

#ifdef MBUFTRACE
/* Mbuf allocation tracing. */
void mowner_init_owner(struct mowner *, const char *, const char *);
void mowner_init(struct mbuf *, int);
void mowner_ref(struct mbuf *, int);
void m_claim(struct mbuf *, struct mowner *);
void mowner_revoke(struct mbuf *, bool, int);
void mowner_attach(struct mowner *);
void mowner_detach(struct mowner *);
void m_claimm(struct mbuf *, struct mowner *);
#else
#define mowner_init_owner(mo, n, d)	__nothing
#define mowner_init(m, type)		__nothing
#define mowner_ref(m, flags)		__nothing
#define mowner_revoke(m, all, flags)	__nothing
#define m_claim(m, mowner)		__nothing
#define mowner_attach(mo)		__nothing
#define mowner_detach(mo)		__nothing
#define m_claimm(m, mo)			__nothing
#endif

#define MCLAIM(m, mo)		m_claim((m), (mo))
#define MOWNER_ATTACH(mo)	mowner_attach(mo)
#define MOWNER_DETACH(mo)	mowner_detach(mo)

/*
 * mbuf allocation/deallocation macros:
 *
 *	MGET(struct mbuf *m, int how, int type)
 * allocates an mbuf and initializes it to contain internal data.
 *
 *	MGETHDR(struct mbuf *m, int how, int type)
 * allocates an mbuf and initializes it to contain a packet header
 * and internal data.
 *
 * If 'how' is M_WAIT, these macros (and the corresponding functions)
 * are guaranteed to return successfully.
 */
#define MGET(m, how, type)	m = m_get((how), (type))
#define MGETHDR(m, how, type)	m = m_gethdr((how), (type))

#if defined(_KERNEL)

#define MCLINITREFERENCE(m)						\
do {									\
	KASSERT(((m)->m_flags & M_EXT) == 0);				\
	(m)->m_ext_ref = (m);						\
	(m)->m_ext.ext_refcnt = 1;					\
} while (/* CONSTCOND */ 0)

/*
 * Macros for mbuf external storage.
 *
 * MCLGET allocates and adds an mbuf cluster to a normal mbuf;
 * the flag M_EXT is set upon success.
 *
 * MEXTMALLOC allocates external storage and adds it to
 * a normal mbuf; the flag M_EXT is set upon success.
 *
 * MEXTADD adds pre-allocated external storage to
 * a normal mbuf; the flag M_EXT is set upon success.
 */

#define MCLGET(m, how)	m_clget((m), (how))

#define MEXTMALLOC(m, size, how)					\
do {									\
	(m)->m_ext_storage.ext_buf = malloc((size), 0, (how));		\
	if ((m)->m_ext_storage.ext_buf != NULL) {			\
		MCLINITREFERENCE(m);					\
		(m)->m_data = (m)->m_ext.ext_buf;			\
		(m)->m_flags = ((m)->m_flags & ~M_EXTCOPYFLAGS) |	\
				M_EXT|M_EXT_RW;				\
		(m)->m_ext.ext_size = (size);				\
		(m)->m_ext.ext_free = NULL;				\
		(m)->m_ext.ext_arg = NULL;				\
		mowner_ref((m), M_EXT);					\
	}								\
} while (/* CONSTCOND */ 0)

#define MEXTADD(m, buf, size, type, free, arg)				\
do {									\
	MCLINITREFERENCE(m);						\
	(m)->m_data = (m)->m_ext.ext_buf = (char *)(buf);		\
	(m)->m_flags = ((m)->m_flags & ~M_EXTCOPYFLAGS) | M_EXT;	\
	(m)->m_ext.ext_size = (size);					\
	(m)->m_ext.ext_free = (free);					\
	(m)->m_ext.ext_arg = (arg);					\
	mowner_ref((m), M_EXT);						\
} while (/* CONSTCOND */ 0)

#define M_BUFADDR(m)							\
	(((m)->m_flags & M_EXT) ? (m)->m_ext.ext_buf :			\
	    ((m)->m_flags & M_PKTHDR) ? (m)->m_pktdat : (m)->m_dat)

#define M_BUFSIZE(m)							\
	(((m)->m_flags & M_EXT) ? (m)->m_ext.ext_size :			\
	    ((m)->m_flags & M_PKTHDR) ? MHLEN : MLEN)

#define MRESETDATA(m)	(m)->m_data = M_BUFADDR(m)

/*
 * Compute the offset of the beginning of the data buffer of a non-ext
 * mbuf.
 */
#define M_BUFOFFSET(m)							\
	(((m)->m_flags & M_PKTHDR) ?					\
	 offsetof(struct mbuf, m_pktdat) : offsetof(struct mbuf, m_dat))

/*
 * Determine if an mbuf's data area is read-only.  This is true
 * if external storage is read-only mapped, or not marked as R/W,
 * or referenced by more than one mbuf.
 */
#define M_READONLY(m)							\
	(((m)->m_flags & M_EXT) != 0 &&					\
	  (((m)->m_flags & (M_EXT_ROMAP|M_EXT_RW)) != M_EXT_RW ||	\
	  (m)->m_ext.ext_refcnt > 1))

#define M_UNWRITABLE(__m, __len)					\
	((__m)->m_len < (__len) || M_READONLY((__m)))

/*
 * Determine if an mbuf's data area is read-only at the MMU.
 */
#define M_ROMAP(m)							\
	(((m)->m_flags & (M_EXT|M_EXT_ROMAP)) == (M_EXT|M_EXT_ROMAP))

/*
 * Compute the amount of space available before the current start of
 * data in an mbuf.
 */
#define M_LEADINGSPACE(m)						\
	(M_READONLY((m)) ? 0 : ((m)->m_data - M_BUFADDR(m)))

/*
 * Compute the amount of space available
 * after the end of data in an mbuf.
 */
#define _M_TRAILINGSPACE(m)						\
	((m)->m_flags & M_EXT ? (m)->m_ext.ext_buf + (m)->m_ext.ext_size - \
	 ((m)->m_data + (m)->m_len) :					\
	 &(m)->m_dat[MLEN] - ((m)->m_data + (m)->m_len))

#define M_TRAILINGSPACE(m)						\
	(M_READONLY((m)) ? 0 : _M_TRAILINGSPACE((m)))

/*
 * Arrange to prepend space of size plen to mbuf m.
 * If a new mbuf must be allocated, how specifies whether to wait.
 * If how is M_DONTWAIT and allocation fails, the original mbuf chain
 * is freed and m is set to NULL.
 */
#define M_PREPEND(m, plen, how)						\
do {									\
	if (M_LEADINGSPACE(m) >= (plen)) {				\
		(m)->m_data -= (plen);					\
		(m)->m_len += (plen);					\
	} else								\
		(m) = m_prepend((m), (plen), (how));			\
	if ((m) && (m)->m_flags & M_PKTHDR)				\
		(m)->m_pkthdr.len += (plen);				\
} while (/* CONSTCOND */ 0)

/* change mbuf to new type */
#define MCHTYPE(m, t)							\
do {									\
	KASSERT((t) != MT_FREE);					\
	mbstat_type_add((m)->m_type, -1);				\
	mbstat_type_add(t, 1);						\
	(m)->m_type = t;						\
} while (/* CONSTCOND */ 0)

#ifdef DIAGNOSTIC
#define M_VERIFY_PACKET(m)	m_verify_packet(m)
#else
#define M_VERIFY_PACKET(m)	__nothing
#endif

/* The "copy all" special length. */
#define M_COPYALL	-1

/*
 * Allow drivers and/or protocols to store private context information.
 */
#define M_GETCTX(m, t)		((t)(m)->m_pkthdr._rcvif.ctx)
#define M_SETCTX(m, c)		((void)((m)->m_pkthdr._rcvif.ctx = (void *)(c)))
#define M_CLEARCTX(m)		M_SETCTX((m), NULL)

/*
 * M_REGION_GET ensures that the "len"-sized region of type "typ" starting
 * from "off" within "m" is located in a single mbuf, contiguously.
 *
 * The pointer to the region will be returned to pointer variable "val".
 */
#define M_REGION_GET(val, typ, m, off, len) \
do {									\
	struct mbuf *_t;						\
	int _tmp;							\
	if ((m)->m_len >= (off) + (len))				\
		(val) = (typ)(mtod((m), char *) + (off));		\
	else {								\
		_t = m_pulldown((m), (off), (len), &_tmp);		\
		if (_t) {						\
			if (_t->m_len < _tmp + (len))			\
				panic("m_pulldown malfunction");	\
			(val) = (typ)(mtod(_t, char *) + _tmp);	\
		} else {						\
			(val) = (typ)NULL;				\
			(m) = NULL;					\
		}							\
	}								\
} while (/*CONSTCOND*/ 0)

#endif /* defined(_KERNEL) */

/*
 * Simple mbuf queueing system
 *
 * this is basically a SIMPLEQ adapted to mbuf use (ie using
 * m_nextpkt instead of field.sqe_next).
 *
 * m_next is ignored, so queueing chains of mbufs is possible
 */
#define MBUFQ_HEAD(name)					\
struct name {							\
	struct mbuf *mq_first;					\
	struct mbuf **mq_last;					\
}

#define MBUFQ_INIT(q)		do {				\
	(q)->mq_first = NULL;					\
	(q)->mq_last = &(q)->mq_first;				\
} while (/*CONSTCOND*/0)

#define MBUFQ_ENQUEUE(q, m)	do {				\
	(m)->m_nextpkt = NULL;					\
	*(q)->mq_last = (m);					\
	(q)->mq_last = &(m)->m_nextpkt;				\
} while (/*CONSTCOND*/0)

#define MBUFQ_PREPEND(q, m)	do {				\
	if (((m)->m_nextpkt = (q)->mq_first) == NULL)		\
		(q)->mq_last = &(m)->m_nextpkt;			\
	(q)->mq_first = (m);					\
} while (/*CONSTCOND*/0)

#define MBUFQ_DEQUEUE(q, m)	do {				\
	if (((m) = (q)->mq_first) != NULL) {			\
		if (((q)->mq_first = (m)->m_nextpkt) == NULL)	\
			(q)->mq_last = &(q)->mq_first;		\
		else						\
			(m)->m_nextpkt = NULL;			\
	}							\
} while (/*CONSTCOND*/0)

#define MBUFQ_DRAIN(q)		do {				\
	struct mbuf *__m0;					\
	while ((__m0 = (q)->mq_first) != NULL) {		\
		(q)->mq_first = __m0->m_nextpkt;		\
		m_freem(__m0);					\
	}							\
	(q)->mq_last = &(q)->mq_first;				\
} while (/*CONSTCOND*/0)

#define MBUFQ_FIRST(q)		((q)->mq_first)
#define MBUFQ_NEXT(m)		((m)->m_nextpkt)
#define MBUFQ_LAST(q)		(*(q)->mq_last)

/*
 * Mbuf statistics.
 * For statistics related to mbuf and cluster allocations, see also the
 * pool headers (mb_cache and mcl_cache).
 */
struct mbstat {
	u_long	_m_spare;	/* formerly m_mbufs */
	u_long	_m_spare1;	/* formerly m_clusters */
	u_long	_m_spare2;	/* spare field */
	u_long	_m_spare3;	/* formely m_clfree - free clusters */
	u_long	m_drops;	/* times failed to find space */
	u_long	m_wait;		/* times waited for space */
	u_long	m_drain;	/* times drained protocols for space */
	u_short	m_mtypes[256];	/* type specific mbuf allocations */
};

struct mbstat_cpu {
	u_int	m_mtypes[256];	/* type specific mbuf allocations */
};

/*
 * Mbuf sysctl variables.
 */
#define MBUF_MSIZE		1	/* int: mbuf base size */
#define MBUF_MCLBYTES		2	/* int: mbuf cluster size */
#define MBUF_NMBCLUSTERS	3	/* int: limit on the # of clusters */
#define MBUF_MBLOWAT		4	/* int: mbuf low water mark */
#define MBUF_MCLLOWAT		5	/* int: mbuf cluster low water mark */
#define MBUF_STATS		6	/* struct: mbstat */
#define MBUF_MOWNERS		7	/* struct: m_owner[] */
#define MBUF_NMBCLUSTERS_LIMIT	8	/* int: limit of nmbclusters */

#ifdef _KERNEL
extern struct mbstat mbstat;
extern int nmbclusters;		/* limit on the # of clusters */
extern int mblowat;		/* mbuf low water mark */
extern int mcllowat;		/* mbuf cluster low water mark */
extern int max_linkhdr;		/* largest link-level header */
extern int max_protohdr;		/* largest protocol header */
extern int max_hdr;		/* largest link+protocol header */
extern int max_datalen;		/* MHLEN - max_hdr */
extern const int msize;			/* mbuf base size */
extern const int mclbytes;		/* mbuf cluster size */
extern pool_cache_t mb_cache;
#ifdef MBUFTRACE
LIST_HEAD(mownerhead, mowner);
extern struct mownerhead mowners;
extern struct mowner unknown_mowners[];
extern struct mowner revoked_mowner;
#endif

MALLOC_DECLARE(M_MBUF);
MALLOC_DECLARE(M_SONAME);

struct	mbuf *m_copym(struct mbuf *, int, int, int);
struct	mbuf *m_copypacket(struct mbuf *, int);
struct	mbuf *m_devget(char *, int, int, struct ifnet *);
struct	mbuf *m_dup(struct mbuf *, int, int, int);
struct	mbuf *m_get(int, int);
struct	mbuf *m_gethdr(int, int);
struct	mbuf *m_prepend(struct mbuf *,int, int);
struct	mbuf *m_pulldown(struct mbuf *, int, int, int *);
struct	mbuf *m_pullup(struct mbuf *, int);
struct	mbuf *m_copyup(struct mbuf *, int, int);
struct	mbuf *m_split(struct mbuf *,int, int);
struct	mbuf *m_getptr(struct mbuf *, int, int *);
void	m_adj(struct mbuf *, int);
struct	mbuf *m_defrag(struct mbuf *, int);
int	m_apply(struct mbuf *, int, int,
    int (*)(void *, void *, unsigned int), void *);
void	m_cat(struct mbuf *,struct mbuf *);
void	m_clget(struct mbuf *, int);
void	m_copyback(struct mbuf *, int, int, const void *);
struct	mbuf *m_copyback_cow(struct mbuf *, int, int, const void *, int);
int	m_makewritable(struct mbuf **, int, int, int);
struct	mbuf *m_getcl(int, int, int);
void	m_copydata(struct mbuf *, int, int, void *);
void	m_verify_packet(struct mbuf *);
struct	mbuf *m_free(struct mbuf *);
void	m_freem(struct mbuf *);
void	mbinit(void);
void	m_remove_pkthdr(struct mbuf *);
void	m_copy_pkthdr(struct mbuf *, struct mbuf *);
void	m_move_pkthdr(struct mbuf *, struct mbuf *);
void	m_align(struct mbuf *, int);

bool	m_ensure_contig(struct mbuf **, int);
struct mbuf *m_add(struct mbuf *, struct mbuf *);

/* Inline routines. */
static __inline u_int m_length(const struct mbuf *) __unused;

/* Statistics */
void mbstat_type_add(int, int);

/* Packet tag routines */
struct	m_tag *m_tag_get(int, int, int);
void	m_tag_free(struct m_tag *);
void	m_tag_prepend(struct mbuf *, struct m_tag *);
void	m_tag_unlink(struct mbuf *, struct m_tag *);
void	m_tag_delete(struct mbuf *, struct m_tag *);
void	m_tag_delete_chain(struct mbuf *);
struct	m_tag *m_tag_find(const struct mbuf *, int);
struct	m_tag *m_tag_copy(struct m_tag *);
int	m_tag_copy_chain(struct mbuf *, struct mbuf *);

/* Packet tag types */
#define PACKET_TAG_NONE			0  /* Nothing */
#define PACKET_TAG_SO			4  /* sending socket pointer */
#define PACKET_TAG_NPF			10 /* packet filter */
#define PACKET_TAG_PF			11 /* packet filter */
#define PACKET_TAG_ALTQ_QID		12 /* ALTQ queue id */
#define PACKET_TAG_IPSEC_OUT_DONE	18
#define PACKET_TAG_IPSEC_NAT_T_PORTS	25 /* two uint16_t */
#define PACKET_TAG_INET6		26 /* IPv6 info */
#define PACKET_TAG_TUNNEL_INFO		28 /* tunnel identification and
					    * protocol callback, for loop
					    * detection/recovery
					    */
#define PACKET_TAG_MPLS			29 /* Indicate it's for MPLS */
#define PACKET_TAG_SRCROUTE		30 /* IPv4 source routing */
#define PACKET_TAG_ETHERNET_SRC		31 /* Ethernet source address */

/*
 * Return the number of bytes in the mbuf chain, m.
 */
static __inline u_int
m_length(const struct mbuf *m)
{
	const struct mbuf *m0;
	u_int pktlen;

	if ((m->m_flags & M_PKTHDR) != 0)
		return m->m_pkthdr.len;

	pktlen = 0;
	for (m0 = m; m0 != NULL; m0 = m0->m_next)
		pktlen += m0->m_len;
	return pktlen;
}

static __inline void
m_set_rcvif(struct mbuf *m, const struct ifnet *ifp)
{
	KASSERT(m->m_flags & M_PKTHDR);
	m->m_pkthdr.rcvif_index = ifp->if_index;
}

static __inline void
m_reset_rcvif(struct mbuf *m)
{
	KASSERT(m->m_flags & M_PKTHDR);
	/* A caller may expect whole _rcvif union is zeroed */
	/* m->m_pkthdr.rcvif_index = 0; */
	m->m_pkthdr._rcvif.ctx = NULL;
}

static __inline void
m_copy_rcvif(struct mbuf *m, const struct mbuf *n)
{
	KASSERT(m->m_flags & M_PKTHDR);
	KASSERT(n->m_flags & M_PKTHDR);
	m->m_pkthdr.rcvif_index = n->m_pkthdr.rcvif_index;
}

#define M_GET_ALIGNED_HDR(m, type, linkhdr) \
    m_get_aligned_hdr((m), __alignof(type) - 1, sizeof(type), (linkhdr))

static __inline int
m_get_aligned_hdr(struct mbuf **m, int mask, size_t hlen, bool linkhdr)
{
#ifndef __NO_STRICT_ALIGNMENT
	if (((uintptr_t)mtod(*m, void *) & mask) != 0)
		*m = m_copyup(*m, hlen, 
		      linkhdr ? (max_linkhdr + mask) & ~mask : 0);
	else
#endif
	if (__predict_false((size_t)(*m)->m_len < hlen))
		*m = m_pullup(*m, hlen);

	return *m == NULL;
}

void m_print(const struct mbuf *, const char *, void (*)(const char *, ...)
    __printflike(1, 2));

/* from uipc_mbufdebug.c */
void	m_examine(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));

/* parsers for m_examine() */
void m_examine_ether(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_pppoe(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_ppp(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_arp(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_ip(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_icmp(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_ip6(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_icmp6(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_tcp(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_udp(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));
void m_examine_hex(const struct mbuf *, int, const char *,
    void (*)(const char *, ...) __printflike(1, 2));

/*
 * Get rcvif of a mbuf.
 *
 * The caller must call m_put_rcvif after using rcvif if the returned rcvif
 * isn't NULL. If the returned rcvif is NULL, the caller doesn't need to call
 * m_put_rcvif (although calling it is safe).
 *
 * The caller must not block or sleep while using rcvif. The API ensures a
 * returned rcvif isn't freed until m_put_rcvif is called.
 */
static __inline struct ifnet *
m_get_rcvif(const struct mbuf *m, int *s)
{
	struct ifnet *ifp;

	KASSERT(m->m_flags & M_PKTHDR);
	*s = pserialize_read_enter();
	ifp = if_byindex(m->m_pkthdr.rcvif_index);
	if (__predict_false(ifp == NULL))
		pserialize_read_exit(*s);

	return ifp;
}

static __inline void
m_put_rcvif(struct ifnet *ifp, int *s)
{

	if (ifp == NULL)
		return;
	pserialize_read_exit(*s);
}

/*
 * Get rcvif of a mbuf.
 *
 * The caller must call m_put_rcvif_psref after using rcvif. The API ensures
 * a got rcvif isn't be freed until m_put_rcvif_psref is called.
 */
static __inline struct ifnet *
m_get_rcvif_psref(const struct mbuf *m, struct psref *psref)
{
	KASSERT(m->m_flags & M_PKTHDR);
	return if_get_byindex(m->m_pkthdr.rcvif_index, psref);
}

static __inline void
m_put_rcvif_psref(struct ifnet *ifp, struct psref *psref)
{

	if (ifp == NULL)
		return;
	if_put(ifp, psref);
}

/*
 * Get rcvif of a mbuf.
 *
 * This is NOT an MP-safe API and shouldn't be used at where we want MP-safe.
 */
static __inline struct ifnet *
m_get_rcvif_NOMPSAFE(const struct mbuf *m)
{
	KASSERT(m->m_flags & M_PKTHDR);
	return if_byindex(m->m_pkthdr.rcvif_index);
}

#endif /* _KERNEL */
#endif /* !_SYS_MBUF_H_ */