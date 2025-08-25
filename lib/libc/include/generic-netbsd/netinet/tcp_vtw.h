/*	$NetBSD: tcp_vtw.h,v 1.10 2022/12/11 08:09:20 mlelstv Exp $	*/
/*
 * Copyright (c) 2011 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Coyote Point Systems, Inc.
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
 * Vestigial time-wait.
 *
 * This implementation uses cache-efficient techniques, which will
 * appear somewhat peculiar.  The main philosophy is to optimise the
 * amount of information available within a cache line.  Cache miss is
 * expensive.  So we employ ad-hoc techniques to pull a series of
 * linked-list follows into a cache line.  One cache line, multiple
 * linked-list equivalents.
 *
 * One such ad-hoc technique is fat pointers.  Additional degrees of
 * ad-hoqueness result from having to hand tune it for pointer size
 * and for cache line size.
 *
 * The 'fat pointer' approach aggregates, for x86_32, 15 linked-list
 * data structures into one cache line.  The additional 32 bits in the
 * cache line are used for linking fat pointers, and for
 * allocation/bookkeeping.
 *
 * The 15 32-bit tags encode the pointers to the linked list elements,
 * and also encode the results of a search comparison.
 *
 * First, some more assumptions/restrictions.
 *
 * All the fat pointers are from a contiguous allocation arena.  Thus,
 * we can refer to them by offset from a base, not as full pointers.
 *
 * All the linked list data elements are also from a contiguous
 * allocation arena, again so that we can refer to them as offset from
 * a base.
 *
 * In order to add a data element to a fat pointer, a key value is
 * computed, based on unique data within the data element.  It is the
 * linear searching of the linked lists of these elements based on
 * these unique data that are being optimised here.
 *
 * Lets call the function that computes the key k(e), where e is the
 * data element.  In this example, k(e) returns 32-bits.
 *
 * Consider a set E (say of order 15) of data elements.  Let K be
 * the set of the k(e) for e in E.
 *
 * Let O be the set of the offsets from the base of the data elements in E.
 *
 * For each x in K, for each matching o in O, let t be x ^ o.  These
 * are the tags. (More or less).
 *
 * In order to search all the data elements in E, we compute the
 * search key, and one at a time, XOR the key into the tags.  If any
 * result is a valid data element index, we have a possible match.  If
 * not, there is no match.
 *
 * The no-match cases mean we do not have to de-reference the pointer
 * to the data element in question.  We save cache miss penalty and
 * cache load decreases.  Only in the case of a valid looking data
 * element index, do we have to look closer.
 *
 * Thus, in the absence of false positives, 15 data elements can be
 * searched with one cache line fill, as opposed to 15 cache line
 * fills for the usual implementation.
 *
 * The vestigial time waits (vtw_t), the data elements in the above, are
 * searched by faddr, fport, laddr, lport.  The key is a function of
 * these values.
 *
 * We hash these keys into the traditional hash chains to reduce the
 * search time, and use fat pointers to reduce the cache impacts of
 * searching.
 *
 * The vtw_t are, per requirement, in a contiguous chunk.  Allocation
 * is done with a clock hand, and all vtw_t within one allocation
 * domain have the same lifetime, so they will always be sorted by
 * age.
 *
 * A vtw_t will be allocated, timestamped, and have a fixed future
 * expiration.  It will be added to a hash bucket implemented with fat
 * pointers, which means that a cache line will be allocated in the
 * hash bucket, placed at the head (more recent in time) and the vtw_t
 * will be added to this.  As more entries are added, the fat pointer
 * cache line will fill, requiring additional cache lines for fat
 * pointers to be allocated. These will be added at the head, and the
 * aged entries will hang down, tapeworm like.  As the vtw_t entries
 * expire, the corresponding slot in the fat pointer will be
 * reclaimed, and eventually the cache line will completely empty and
 * be re-cycled, if not at the head of the chain.
 *
 * At times, a time-wait timer is restarted.  This corresponds to
 * deleting the current entry and re-adding it.
 *
 * Most of the time, they are just placed here to die.
 */
#ifndef _NETINET_TCP_VTW_H
#define _NETINET_TCP_VTW_H

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/in_pcb.h>
#include <netinet/in_var.h>
#include <netinet/ip_var.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netinet/tcp_timer.h>
#include <netinet/tcp_var.h>
#include <netinet6/in6.h>
#include <netinet/ip6.h>
#include <netinet6/ip6_var.h>
#include <netinet6/in6_pcb.h>
#include <netinet6/ip6_var.h>
#include <netinet6/in6_var.h>
#include <netinet/icmp6.h>

#define	VTW_NCLASS	(1+3)		/* # different classes */

/*
 * fat pointers, MI.
 */
struct fatp_mi;

#if CACHE_LINE_SIZE == 128
typedef uint64_t fatp_word_t;
#else
typedef uint32_t fatp_word_t;
#endif

typedef struct fatp_mi	fatp_t;

/* Supported cacheline sizes: 32 64 128 bytes.  See fatp_key(),
 * fatp_slot_from_key(), fatp_xtra[].
 */
#define	FATP_NTAGS	(CACHE_LINE_SIZE / sizeof(fatp_word_t) - 1)
#define	FATP_NXT_WIDTH	(sizeof(fatp_word_t) * NBBY - FATP_NTAGS)

#define	FATP_MAX	(1 << (FATP_NXT_WIDTH < 31 ? FATP_NXT_WIDTH : 31))

/* Worked example: ULP32 with 64-byte cacheline (32-bit x86):
 * 15 tags per cacheline.  At most 2^17 fat pointers per fatp_ctl_t.
 * The comments on the fatp_mi members, below, correspond to the worked
 * example.
 */
struct fatp_mi {
	fatp_word_t	inuse	: FATP_NTAGS;	/* (1+15)*4 == CL_SIZE */
	fatp_word_t	nxt	: FATP_NXT_WIDTH;/* at most 2^17 fat pointers */
	fatp_word_t	tag[FATP_NTAGS];	/* 15 tags per CL */
};

static __inline int
fatp_ntags(void)
{
	return FATP_NTAGS;
}

static __inline int
fatp_full(fatp_t *fp) 
{
	fatp_t full;

	full.inuse = (1U << FATP_NTAGS) - 1U;

	return (fp->inuse == full.inuse);
}

struct vtw_common;
struct vtw_v4;
struct vtw_v6;
struct vtw_ctl;

/*!\brief common to all vtw
 */
typedef struct vtw_common {
	struct timeval	expire;		/* date of birth+msl */
	uint32_t	key;		/* hash key: full hash */
	uint32_t	port_key;	/* hash key: local port hash */
	uint32_t	rcv_nxt;
	uint32_t	rcv_wnd;
	uint32_t	snd_nxt;
	uint32_t	snd_scale	: 8;	/* window scaling for send win */
	uint32_t	msl_class	: 2;	/* TCP MSL class {0,1,2,3} */
	uint32_t	reuse_port	: 1;
	uint32_t	reuse_addr	: 1;
	uint32_t	v6only		: 1;
	uint32_t	hashed		: 1;	/* reachable via FATP */
	uint32_t	uid;
} vtw_t;

/*!\brief vestigial timewait for IPv4
 */
typedef struct vtw_v4 {
	vtw_t		common;		/*  must be first */
	uint16_t	lport;
	uint16_t	fport;
	uint32_t	laddr;
	uint32_t	faddr;
} vtw_v4_t;

/*!\brief vestigial timewait for IPv6
 */
typedef struct vtw_v6 {
	vtw_t		common;		/* must be first */
	uint16_t	lport;
	uint16_t	fport;
	struct in6_addr	laddr;
	struct in6_addr	faddr;
} vtw_v6_t;

struct fatp_ctl;
typedef struct vtw_ctl		vtw_ctl_t;
typedef struct fatp_ctl		fatp_ctl_t;

/*
 * The vestigial time waits are kept in a contiguous chunk.
 * Allocation and free pointers run as clock hands thru this array.
 */
struct vtw_ctl {
	fatp_ctl_t	*fat;		/* collection of fatp to use	*/
	vtw_ctl_t	*ctl;		/* <! controller's controller	*/
	union {
		vtw_t		*v;	/* common			*/
		struct vtw_v4	*v4;	/* IPv4 resources		*/
		struct vtw_v6	*v6;	/* IPv6 resources		*/
	}		base,		/* base of vtw_t array		*/
		/**/	lim,		/* extent of vtw_t array	*/
		/**/	alloc,		/* allocation pointer		*/
		/**/	oldest;		/* ^ to oldest			*/
	uint32_t	nfree;		/* # free			*/
	uint32_t	nalloc;		/* # allocated			*/
	uint32_t	idx_mask;	/* mask capturing all index bits*/
	uint32_t	is_v4	: 1;
	uint32_t	is_v6	: 1;
	uint32_t	idx_bits: 6;
	uint32_t	clidx	: 3;	/* <! class index */
};

/*!\brief Collections of fat pointers.
 */
struct fatp_ctl {
	vtw_ctl_t	*vtw;		/* associated VTWs		*/
	fatp_t		*base;		/* base of fatp_t array		*/
	fatp_t		*lim;		/* extent of fatp_t array	*/
	fatp_t		*free;		/* free list			*/
	uint32_t	mask;		/* hash mask			*/
	uint32_t	nfree;		/* # free			*/
	uint32_t	nalloc;		/* # allocated			*/
	fatp_t		**hash;		/* hash anchors			*/
	fatp_t		**port;		/* port hash anchors		*/
};

/*!\brief stats
 */
struct vtw_stats {
	uint64_t	ins;		/* <! inserts */
	uint64_t	del;		/* <! deleted */
	uint64_t	kill;		/* <! assassination */
	uint64_t	look[2];	/* <! lookup: full hash, port hash */
	uint64_t	hit[2];		/* <! lookups that hit */
	uint64_t	miss[2];	/* <! lookups that miss */
	uint64_t	probe[2];	/* <! hits+miss */
	uint64_t	losing[2];	/* <! misses requiring dereference */
	uint64_t	max_chain[2];	/* <! max fatp chain traversed */
	uint64_t	max_probe[2];	/* <! max probes in any one chain */
	uint64_t	max_loss[2];	/* <! max losing probes in any one
					 * chain
					 */
};

typedef struct vtw_stats	vtw_stats_t;

/*!\brief	follow fatp next 'pointer'
 */
static __inline fatp_t *
fatp_next(fatp_ctl_t *fat, fatp_t *fp)
{
	return fp->nxt ? fat->base + fp->nxt-1 : 0;
}

/*!\brief determine a collection-relative fat pointer index.
 */
static __inline uint32_t
fatp_index(fatp_ctl_t *fat, fatp_t *fp)
{
	return fp ? 1 + (fp - fat->base) : 0;
}


static __inline uint32_t
v4_tag(uint32_t faddr, uint32_t fport, uint32_t laddr, uint32_t lport)
{
	return (ntohl(faddr)   + ntohs(fport)
		+ ntohl(laddr) + ntohs(lport));
}

static __inline uint32_t
v6_tag(const struct in6_addr *faddr, uint16_t fport,
       const struct in6_addr *laddr, uint16_t lport)
{
#ifdef IN6_HASH
	return IN6_HASH(faddr, fport, laddr, lport);
#else
	return 0;
#endif
}

static __inline uint32_t
v4_port_tag(uint16_t lport)
{
	uint32_t tag = lport ^ (lport << 11);

	tag ^= tag << 3;
	tag += tag >> 5;
	tag ^= tag << 4;
	tag += tag >> 17;
	tag ^= tag << 25;
	tag += tag >> 6;

	return tag;
}

static __inline uint32_t
v6_port_tag(uint16_t lport)
{
	return v4_port_tag(lport);
}

struct tcpcb;
struct tcphdr;

int  vtw_add(int, struct tcpcb *);
void vtw_del(vtw_ctl_t *, vtw_t *);
int vtw_lookup_v4(const struct ip *ip, const struct tcphdr *th,
		  uint32_t faddr, uint16_t fport,
		  uint32_t laddr, uint16_t lport);
struct ip6_hdr;
struct in6_addr;

int vtw_lookup_v6(const struct ip6_hdr *ip, const struct tcphdr *th,
		  const struct in6_addr *faddr, uint16_t fport,
		  const struct in6_addr *laddr, uint16_t lport);

typedef struct vestigial_inpcb {
	union {
		struct in_addr	v4;
		struct in6_addr	v6;
	} faddr, laddr;
	uint16_t		fport, lport;
	uint32_t		valid		: 1;
	uint32_t		v4		: 1;
	uint32_t		reuse_addr	: 1;
	uint32_t		reuse_port	: 1;
	uint32_t		v6only		: 1;
	uint32_t		more_tbd	: 1;
	uint32_t		uid;
	uint32_t		rcv_nxt;
	uint32_t		rcv_wnd;
	uint32_t		snd_nxt;
	struct vtw_common	*vtw;
	struct vtw_ctl		*ctl;
} vestigial_inpcb_t;

#ifdef _KERNEL
void vtw_restart(vestigial_inpcb_t*);
int vtw_earlyinit(void);
int sysctl_tcp_vtw_enable(SYSCTLFN_PROTO);
#endif /* _KERNEL */

#ifdef VTW_DEBUG
typedef struct sin_either {
	uint8_t		sin_len;
	uint8_t		sin_family;
	uint16_t	sin_port;
	union {
		struct in_addr	v4;
		struct in6_addr	v6;
	}		sin_addr;
} sin_either_t;

int vtw_debug_add(int af, sin_either_t *, sin_either_t *, int, int);

typedef struct vtw_sysargs {
	uint32_t	op;
	sin_either_t	fa;
	sin_either_t	la;
} vtw_sysargs_t;

#endif /* VTW_DEBUG */

#endif /* _NETINET_TCP_VTW_H */