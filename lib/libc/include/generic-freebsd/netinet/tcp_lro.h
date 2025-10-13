/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2006, Myricom Inc.
 * Copyright (c) 2008, Intel Corporation.
 * Copyright (c) 2016-2021 Mellanox Technologies.
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _TCP_LRO_H_
#define _TCP_LRO_H_

#include <sys/time.h>
#include <sys/param.h>
#include <sys/mbuf.h>
#include <netinet/in.h>

#ifndef TCP_LRO_ENTRIES
/* Define default number of LRO entries per RX queue */
#define	TCP_LRO_ENTRIES	8
#endif

/*
 * Flags for ACK entry for compression
 * the bottom 12 bits has the th_x2|th_flags.
 * LRO itself adds only the TSTMP flags
 * to indicate if either of the types
 * of timestamps are filled and the
 * HAS_TSTMP option to indicate if the
 * TCP timestamp option is valid.
 *
 * The other 1 flag bits are for processing
 * by a stack.
 *
 */
#define TSTMP_LRO		0x1000
#define TSTMP_HDWR		0x2000
#define HAS_TSTMP		0x4000
/*
 * Default number of interrupts on the same cpu in a row
 * that will cause us to declare a "affinity cpu".
 */
#define TCP_LRO_CPU_DECLARATION_THRESH 50

struct inpcb;

/* Precompute the LRO_RAW_ADDRESS_MAX value: */
#define	LRO_RAW_ADDRESS_MAX \
	howmany(12 + 2 * sizeof(struct in6_addr), sizeof(u_long))

union lro_address {
	u_long raw[LRO_RAW_ADDRESS_MAX];
	struct {
		uint8_t lro_type;	/* internal */
#define	LRO_TYPE_NONE     0
#define	LRO_TYPE_IPV4_TCP 1
#define	LRO_TYPE_IPV6_TCP 2
#define	LRO_TYPE_IPV4_UDP 3
#define	LRO_TYPE_IPV6_UDP 4
		uint8_t lro_flags;
#define	LRO_FLAG_DECRYPTED 1
		uint16_t vlan_id;	/* VLAN identifier */
		uint16_t s_port;	/* source TCP/UDP port */
		uint16_t d_port;	/* destination TCP/UDP port */
		uint32_t vxlan_vni;	/* VXLAN virtual network identifier */
		union {
			struct in_addr v4;
			struct in6_addr v6;
		} s_addr;	/* source IPv4/IPv6 address */
		union {
			struct in_addr v4;
			struct in6_addr v6;
		} d_addr;	/* destination IPv4/IPv6 address */
	};
};

_Static_assert(sizeof(union lro_address) == sizeof(u_long) * LRO_RAW_ADDRESS_MAX,
    "The raw field in the lro_address union does not cover the whole structure.");

/* Optimize address comparison by comparing one unsigned long at a time: */

static inline bool
lro_address_compare(const union lro_address *pa, const union lro_address *pb)
{
	if (pa->lro_type == LRO_TYPE_NONE && pb->lro_type == LRO_TYPE_NONE) {
		return (true);
	} else for (unsigned i = 0; i < LRO_RAW_ADDRESS_MAX; i++) {
		if (pa->raw[i] != pb->raw[i])
			return (false);
	}
	return (true);
}

struct lro_parser {
	union lro_address data;
	union {
		uint8_t *l3;
		struct ip *ip4;
		struct ip6_hdr *ip6;
	};
	union {
		uint8_t *l4;
		struct tcphdr *tcp;
		struct udphdr *udp;
	};
	uint16_t total_hdr_len;
};

/* This structure is zeroed frequently, try to keep it small. */
struct lro_entry {
	LIST_ENTRY(lro_entry)	next;
	LIST_ENTRY(lro_entry)	hash_next;
	struct mbuf		*m_head;
	struct mbuf		*m_tail;
	struct mbuf		*m_last_mbuf;
	struct lro_parser	outer;
	struct lro_parser	inner;
	uint32_t		next_seq;	/* tcp_seq */
	uint32_t		ack_seq;	/* tcp_seq */
	uint32_t		tsval;
	uint32_t		tsecr;
	uint16_t		compressed;
	uint16_t		uncompressed;
	uint16_t		window;
	uint16_t		flags : 12,	/* 12 TCP header bits */
				timestamp : 1,
				needs_merge : 1,
				reserved : 2;	/* unused */
	struct bintime		alloc_time;	/* time when entry was allocated */
};

LIST_HEAD(lro_head, lro_entry);

struct lro_mbuf_sort {
	uint64_t seq;
	struct mbuf *mb;
};

/* NB: This is part of driver structs. */
struct lro_ctrl {
	struct ifnet	*ifp;
	struct lro_mbuf_sort *lro_mbuf_data;
	struct bintime	lro_last_queue_time;	/* last time data was queued */
	uint64_t	lro_queued;
	uint64_t	lro_flushed;
	uint64_t	lro_bad_csum;
	unsigned	lro_cnt;
	unsigned	lro_mbuf_count;
	unsigned	lro_mbuf_max;
	unsigned short	lro_ackcnt_lim;		/* max # of aggregated ACKs */
	unsigned short	lro_cpu;		/* Guess at the cpu we have affinity too */
	unsigned 	lro_length_lim;		/* max len of aggregated data */
	u_long		lro_hashsz;
	uint32_t	lro_last_cpu;
	uint32_t 	lro_cnt_of_same_cpu;
	struct lro_head	*lro_hash;
	struct lro_head	lro_active;
	struct lro_head	lro_free;
	uint8_t		lro_cpu_is_set;		/* Flag to say its ok to set the CPU on the inp */
};

struct tcp_ackent {
	uint64_t timestamp;	/* hardware or sofware timestamp, valid if TSTMP_LRO or TSTMP_HDRW set */
	uint32_t seq;		/* th_seq value */
	uint32_t ack;		/* th_ack value */
	uint32_t ts_value;	/* If ts option value, valid if HAS_TSTMP is set */
	uint32_t ts_echo;	/* If ts option echo, valid if HAS_TSTMP is set */
	uint16_t win;		/* TCP window */
	uint16_t flags;		/* Flags to say if TS is present and type of timestamp and th_flags */
	uint8_t  codepoint;	/* IP level codepoint including ECN bits */
	uint8_t  ack_val_set;	/* Classification of ack used by the stack */
	uint8_t  pad[2];	/* To 32 byte boundary */
};

/* We use two M_PROTO on the mbuf */
#define M_ACKCMP	M_PROTO4   /* Indicates LRO is sending in a  Ack-compression mbuf */
#define M_LRO_EHDRSTRP	M_PROTO6   /* Indicates that LRO has stripped the etherenet header */

#define	TCP_LRO_LENGTH_MAX	(65535 - 255)	/* safe value with room for outer headers */
#define	TCP_LRO_ACKCNT_MAX	65535		/* unlimited */

#define	TCP_LRO_TS_OPTION	ntohl((TCPOPT_NOP << 24) | (TCPOPT_NOP << 16) |\
    (TCPOPT_TIMESTAMP << 8) | TCPOLEN_TIMESTAMP)

static inline struct tcphdr *
tcp_lro_get_th(struct mbuf *m)
{
	return ((struct tcphdr *)((char *)m->m_data +
	    m->m_pkthdr.lro_tcp_h_off));
}

extern long tcplro_stacks_wanting_mbufq;

int tcp_lro_init(struct lro_ctrl *);
int tcp_lro_init_args(struct lro_ctrl *, struct ifnet *, unsigned, unsigned);
void tcp_lro_free(struct lro_ctrl *);
void tcp_lro_flush_inactive(struct lro_ctrl *, const struct timeval *);
void tcp_lro_flush_all(struct lro_ctrl *);
extern int (*tcp_lro_flush_tcphpts)(struct lro_ctrl *, struct lro_entry *);
int tcp_lro_rx(struct lro_ctrl *, struct mbuf *, uint32_t);
void tcp_lro_queue_mbuf(struct lro_ctrl *, struct mbuf *);
void tcp_lro_reg_mbufq(void);
void tcp_lro_dereg_mbufq(void);

#define	TCP_LRO_NO_ENTRIES	-2
#define	TCP_LRO_CANNOT		-1
#define	TCP_LRO_NOT_SUPPORTED	1

#endif /* _TCP_LRO_H_ */