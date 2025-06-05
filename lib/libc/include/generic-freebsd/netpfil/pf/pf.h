/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2001 Daniel Hartmeier
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    - Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *    - Redistributions in binary form must reproduce the above
 *      copyright notice, this list of conditions and the following
 *      disclaimer in the documentation and/or other materials provided
 *      with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 *	$OpenBSD: pfvar.h,v 1.282 2009/01/29 15:12:28 pyr Exp $
 */

#ifndef	_NET_PF_H_
#define	_NET_PF_H_

#include <sys/tree.h>

#define	PF_TCPS_PROXY_SRC	((TCP_NSTATES)+0)
#define	PF_TCPS_PROXY_DST	((TCP_NSTATES)+1)

#define	PF_MD5_DIGEST_LENGTH	16
#ifdef MD5_DIGEST_LENGTH
#if PF_MD5_DIGEST_LENGTH != MD5_DIGEST_LENGTH
#error
#endif
#endif

enum	{ PF_INOUT, PF_IN, PF_OUT };
enum	{ PF_PASS, PF_DROP, PF_SCRUB, PF_NOSCRUB, PF_NAT, PF_NONAT,
	  PF_BINAT, PF_NOBINAT, PF_RDR, PF_NORDR, PF_SYNPROXY_DROP, PF_DEFER,
	  PF_MATCH };
enum	{ PF_RULESET_SCRUB, PF_RULESET_FILTER, PF_RULESET_NAT,
	  PF_RULESET_BINAT, PF_RULESET_RDR, PF_RULESET_MAX };
enum	{ PF_OP_NONE, PF_OP_IRG, PF_OP_EQ, PF_OP_NE, PF_OP_LT,
	  PF_OP_LE, PF_OP_GT, PF_OP_GE, PF_OP_XRG, PF_OP_RRG };
enum	{ PF_DEBUG_NONE, PF_DEBUG_URGENT, PF_DEBUG_MISC, PF_DEBUG_NOISY };
enum	{ PF_CHANGE_NONE, PF_CHANGE_ADD_HEAD, PF_CHANGE_ADD_TAIL,
	  PF_CHANGE_ADD_BEFORE, PF_CHANGE_ADD_AFTER,
	  PF_CHANGE_REMOVE, PF_CHANGE_GET_TICKET };
enum	{ PF_GET_NONE, PF_GET_CLR_CNTR };
enum	{ PF_SK_WIRE, PF_SK_STACK, PF_SK_BOTH };
enum	{ PF_PEER_SRC, PF_PEER_DST, PF_PEER_BOTH };

/*
 * Note about PFTM_*: real indices into pf_rule.timeout[] come before
 * PFTM_MAX, special cases afterwards. See pf_state_expires().
 */
enum	{
	PFTM_TCP_FIRST_PACKET	= 0,
	PFTM_TCP_OPENING	= 1,
	PFTM_TCP_ESTABLISHED	= 2,
	PFTM_TCP_CLOSING	= 3,
	PFTM_TCP_FIN_WAIT	= 4,
	PFTM_TCP_CLOSED		= 5,
	PFTM_UDP_FIRST_PACKET	= 6,
	PFTM_UDP_SINGLE		= 7,
	PFTM_UDP_MULTIPLE	= 8,
	PFTM_ICMP_FIRST_PACKET	= 9,
	PFTM_ICMP_ERROR_REPLY	= 10,
	PFTM_OTHER_FIRST_PACKET	= 11,
	PFTM_OTHER_SINGLE	= 12,
	PFTM_OTHER_MULTIPLE	= 13,
	PFTM_FRAG		= 14,
	PFTM_INTERVAL		= 15,
	PFTM_ADAPTIVE_START	= 16,
	PFTM_ADAPTIVE_END	= 17,
	PFTM_SRC_NODE		= 18,
	PFTM_TS_DIFF		= 19,
	PFTM_OLD_MAX		= 20, /* Legacy limit, for binary compatibility with old kernels. */
	PFTM_SCTP_FIRST_PACKET	= 20,
	PFTM_SCTP_OPENING	= 21,
	PFTM_SCTP_ESTABLISHED	= 22,
	PFTM_SCTP_CLOSING	= 23,
	PFTM_SCTP_CLOSED	= 24,
	PFTM_MAX		= 25,
	PFTM_PURGE		= 26,
	PFTM_UNLINKED		= 27,
};

/* PFTM default values */
#define PFTM_TCP_FIRST_PACKET_VAL	120	/* First TCP packet */
#define PFTM_TCP_OPENING_VAL		30	/* No response yet */
#define PFTM_TCP_ESTABLISHED_VAL	24*60*60/* Established */
#define PFTM_TCP_CLOSING_VAL		15 * 60	/* Half closed */
#define PFTM_TCP_FIN_WAIT_VAL		45	/* Got both FINs */
#define PFTM_TCP_CLOSED_VAL		90	/* Got a RST */
#define PFTM_UDP_FIRST_PACKET_VAL	60	/* First UDP packet */
#define PFTM_UDP_SINGLE_VAL		30	/* Unidirectional */
#define PFTM_UDP_MULTIPLE_VAL		60	/* Bidirectional */
#define PFTM_ICMP_FIRST_PACKET_VAL	20	/* First ICMP packet */
#define PFTM_ICMP_ERROR_REPLY_VAL	10	/* Got error response */
#define PFTM_OTHER_FIRST_PACKET_VAL	60	/* First packet */
#define PFTM_OTHER_SINGLE_VAL		30	/* Unidirectional */
#define PFTM_OTHER_MULTIPLE_VAL		60	/* Bidirectional */
#define PFTM_FRAG_VAL			30	/* Fragment expire */
#define PFTM_INTERVAL_VAL		10	/* Expire interval */
#define PFTM_SRC_NODE_VAL		0	/* Source tracking */
#define PFTM_TS_DIFF_VAL		30	/* Allowed TS diff */

enum	{ PF_NOPFROUTE, PF_FASTROUTE, PF_ROUTETO, PF_DUPTO, PF_REPLYTO };
enum	{ PF_LIMIT_STATES, PF_LIMIT_SRC_NODES, PF_LIMIT_FRAGS,
	  PF_LIMIT_TABLE_ENTRIES, PF_LIMIT_MAX };
#define PF_POOL_IDMASK		0x0f
enum	{ PF_POOL_NONE, PF_POOL_BITMASK, PF_POOL_RANDOM,
	  PF_POOL_SRCHASH, PF_POOL_ROUNDROBIN };
enum	{ PF_ADDR_ADDRMASK, PF_ADDR_NOROUTE, PF_ADDR_DYNIFTL,
	  PF_ADDR_TABLE, PF_ADDR_URPFFAILED,
	  PF_ADDR_RANGE };
#define PF_POOL_TYPEMASK	0x0f
#define PF_POOL_STICKYADDR	0x20
#define	PF_WSCALE_FLAG		0x80
#define	PF_WSCALE_MASK		0x0f

#define	PF_LOG			0x01
#define	PF_LOG_ALL		0x02
#define	PF_LOG_SOCKET_LOOKUP	0x04
#define	PF_LOG_FORCE		0x08

/* Reasons code for passing/dropping a packet */
#define PFRES_MATCH	0		/* Explicit match of a rule */
#define PFRES_BADOFF	1		/* Bad offset for pull_hdr */
#define PFRES_FRAG	2		/* Dropping following fragment */
#define PFRES_SHORT	3		/* Dropping short packet */
#define PFRES_NORM	4		/* Dropping by normalizer */
#define PFRES_MEMORY	5		/* Dropped due to lacking mem */
#define PFRES_TS	6		/* Bad TCP Timestamp (RFC1323) */
#define PFRES_CONGEST	7		/* Congestion (of ipintrq) */
#define PFRES_IPOPTIONS 8		/* IP option */
#define PFRES_PROTCKSUM 9		/* Protocol checksum invalid */
#define PFRES_BADSTATE	10		/* State mismatch */
#define PFRES_STATEINS	11		/* State insertion failure */
#define PFRES_MAXSTATES	12		/* State limit */
#define PFRES_SRCLIMIT	13		/* Source node/conn limit */
#define PFRES_SYNPROXY	14		/* SYN proxy */
#define PFRES_MAPFAILED	15		/* pf_map_addr() failed */
#define PFRES_MAX	16		/* total+1 */

#define PFRES_NAMES { \
	"match", \
	"bad-offset", \
	"fragment", \
	"short", \
	"normalize", \
	"memory", \
	"bad-timestamp", \
	"congestion", \
	"ip-option", \
	"proto-cksum", \
	"state-mismatch", \
	"state-insert", \
	"state-limit", \
	"src-limit", \
	"synproxy", \
	"map-failed", \
	NULL \
}

/* Counters for other things we want to keep track of */
#define LCNT_STATES		0	/* states */
#define LCNT_SRCSTATES		1	/* max-src-states */
#define LCNT_SRCNODES		2	/* max-src-nodes */
#define LCNT_SRCCONN		3	/* max-src-conn */
#define LCNT_SRCCONNRATE	4	/* max-src-conn-rate */
#define LCNT_OVERLOAD_TABLE	5	/* entry added to overload table */
#define LCNT_OVERLOAD_FLUSH	6	/* state entries flushed */
#define LCNT_MAX		7	/* total+1 */
/* Only available via the nvlist-based API */
#define KLCNT_SYNFLOODS		7	/* synfloods detected */
#define KLCNT_SYNCOOKIES_SENT	8	/* syncookies sent */
#define KLCNT_SYNCOOKIES_VALID	9	/* syncookies validated */
#define KLCNT_MAX		10	/* total+1 */

#define LCNT_NAMES { \
	"max states per rule", \
	"max-src-states", \
	"max-src-nodes", \
	"max-src-conn", \
	"max-src-conn-rate", \
	"overload table insertion", \
	"overload flush states", \
	NULL \
}
#define KLCNT_NAMES { \
	"max states per rule", \
	"max-src-states", \
	"max-src-nodes", \
	"max-src-conn", \
	"max-src-conn-rate", \
	"overload table insertion", \
	"overload flush states", \
	"synfloods detected", \
	"syncookies sent", \
	"syncookies validated", \
	NULL \
}

/* state operation counters */
#define FCNT_STATE_SEARCH	0
#define FCNT_STATE_INSERT	1
#define FCNT_STATE_REMOVALS	2
#define FCNT_MAX		3

#ifdef _KERNEL
#define FCNT_NAMES { \
	"searches", \
	"inserts", \
	"removals", \
	NULL \
}
#endif

/* src_node operation counters */
#define SCNT_SRC_NODE_SEARCH	0
#define SCNT_SRC_NODE_INSERT	1
#define SCNT_SRC_NODE_REMOVALS	2
#define SCNT_MAX		3

#define	PF_TABLE_NAME_SIZE	32
#define	PF_QNAME_SIZE		64

struct pfioc_nv {
	void            *data;
	size_t           len;   /* The length of the nvlist data. */
	size_t           size;  /* The total size of the data buffer. */
};

struct pf_rule;

/* keep synced with pfi_kif, used in RB_FIND */
struct pfi_kif_cmp {
	char				 pfik_name[IFNAMSIZ];
};

struct pfi_kif {
	char				 pfik_name[IFNAMSIZ];
	union {
		RB_ENTRY(pfi_kif)	 pfik_tree;
		LIST_ENTRY(pfi_kif)	 pfik_list;
	};
	u_int64_t			 pfik_packets[2][2][2];
	u_int64_t			 pfik_bytes[2][2][2];
	u_int32_t			 pfik_tzero;
	u_int				 pfik_flags;
	struct ifnet			*pfik_ifp;
	struct ifg_group		*pfik_group;
	u_int				 pfik_rulerefs;
	TAILQ_HEAD(, pfi_dynaddr)	 pfik_dynaddrs;
};

struct pf_status {
	uint64_t	counters[PFRES_MAX];
	uint64_t	lcounters[LCNT_MAX];
	uint64_t	fcounters[FCNT_MAX];
	uint64_t	scounters[SCNT_MAX];
	uint64_t	pcounters[2][2][3];
	uint64_t	bcounters[2][2];
	uint32_t	running;
	uint32_t	states;
	uint32_t	src_nodes;
	uint32_t	since;
	uint32_t	debug;
	uint32_t	hostid;
	char		ifname[IFNAMSIZ];
	uint8_t		pf_chksum[PF_MD5_DIGEST_LENGTH];
};

#define PF_REASS_ENABLED	0x01
#define PF_REASS_NODF		0x02

struct pf_addr {
	union {
		struct in_addr		v4;
		struct in6_addr		v6;
		u_int8_t		addr8[16];
		u_int16_t		addr16[8];
		u_int32_t		addr32[4];
	};		    /* 128-bit address */
};

#define PFI_AFLAG_NETWORK	0x01
#define PFI_AFLAG_BROADCAST	0x02
#define PFI_AFLAG_PEER		0x04
#define PFI_AFLAG_MODEMASK	0x07
#define PFI_AFLAG_NOALIAS	0x08

struct pf_addr_wrap {
	union {
		struct {
			struct pf_addr		 addr;
			struct pf_addr		 mask;
		}			 a;
		char			 ifname[IFNAMSIZ];
		char			 tblname[PF_TABLE_NAME_SIZE];
	}			 v;
	union {
		struct pfi_dynaddr	*dyn;
		struct pfr_ktable	*tbl;
		int			 dyncnt;
		int			 tblcnt;
	}			 p;
	u_int8_t		 type;		/* PF_ADDR_* */
	u_int8_t		 iflags;	/* PFI_AFLAG_* */
};

union pf_rule_ptr {
	struct pf_rule		*ptr;
	u_int32_t		 nr;
};

struct pf_rule_uid {
	uid_t		 uid[2];
	u_int8_t	 op;
};

struct pf_rule_gid {
	uid_t		 gid[2];
	u_int8_t	 op;
};

struct pf_rule_addr {
	struct pf_addr_wrap	 addr;
	u_int16_t		 port[2];
	u_int8_t		 neg;
	u_int8_t		 port_op;
};

struct pf_pooladdr {
	struct pf_addr_wrap		 addr;
	TAILQ_ENTRY(pf_pooladdr)	 entries;
	char				 ifname[IFNAMSIZ];
	struct pfi_kif			*kif;
};

TAILQ_HEAD(pf_palist, pf_pooladdr);

struct pf_poolhashkey {
	union {
		u_int8_t		key8[16];
		u_int16_t		key16[8];
		u_int32_t		key32[4];
	};		    /* 128-bit hash key */
};

struct pf_mape_portset {
	u_int8_t		offset;
	u_int8_t		psidlen;
	u_int16_t		psid;
};

struct pf_pool {
	struct pf_palist	 list;
	struct pf_pooladdr	*cur;
	struct pf_poolhashkey	 key;
	struct pf_addr		 counter;
	int			 tblidx;
	u_int16_t		 proxy_port[2];
	u_int8_t		 opts;
};

/* A packed Operating System description for fingerprinting */
typedef u_int32_t pf_osfp_t;
#define PF_OSFP_ANY	((pf_osfp_t)0)
#define PF_OSFP_UNKNOWN	((pf_osfp_t)-1)
#define PF_OSFP_NOMATCH	((pf_osfp_t)-2)

struct pf_osfp_entry {
	SLIST_ENTRY(pf_osfp_entry) fp_entry;
	pf_osfp_t		fp_os;
	int			fp_enflags;
#define PF_OSFP_EXPANDED	0x001		/* expanded entry */
#define PF_OSFP_GENERIC		0x002		/* generic signature */
#define PF_OSFP_NODETAIL	0x004		/* no p0f details */
#define PF_OSFP_LEN	32
	char			fp_class_nm[PF_OSFP_LEN];
	char			fp_version_nm[PF_OSFP_LEN];
	char			fp_subtype_nm[PF_OSFP_LEN];
};
#define PF_OSFP_ENTRY_EQ(a, b) \
    ((a)->fp_os == (b)->fp_os && \
    memcmp((a)->fp_class_nm, (b)->fp_class_nm, PF_OSFP_LEN) == 0 && \
    memcmp((a)->fp_version_nm, (b)->fp_version_nm, PF_OSFP_LEN) == 0 && \
    memcmp((a)->fp_subtype_nm, (b)->fp_subtype_nm, PF_OSFP_LEN) == 0)

/* handle pf_osfp_t packing */
#define _FP_RESERVED_BIT	1  /* For the special negative #defines */
#define _FP_UNUSED_BITS		1
#define _FP_CLASS_BITS		10 /* OS Class (Windows, Linux) */
#define _FP_VERSION_BITS	10 /* OS version (95, 98, NT, 2.4.54, 3.2) */
#define _FP_SUBTYPE_BITS	10 /* patch level (NT SP4, SP3, ECN patch) */
#define PF_OSFP_UNPACK(osfp, class, version, subtype) do { \
	(class) = ((osfp) >> (_FP_VERSION_BITS+_FP_SUBTYPE_BITS)) & \
	    ((1 << _FP_CLASS_BITS) - 1); \
	(version) = ((osfp) >> _FP_SUBTYPE_BITS) & \
	    ((1 << _FP_VERSION_BITS) - 1);\
	(subtype) = (osfp) & ((1 << _FP_SUBTYPE_BITS) - 1); \
} while(0)
#define PF_OSFP_PACK(osfp, class, version, subtype) do { \
	(osfp) = ((class) & ((1 << _FP_CLASS_BITS) - 1)) << (_FP_VERSION_BITS \
	    + _FP_SUBTYPE_BITS); \
	(osfp) |= ((version) & ((1 << _FP_VERSION_BITS) - 1)) << \
	    _FP_SUBTYPE_BITS; \
	(osfp) |= (subtype) & ((1 << _FP_SUBTYPE_BITS) - 1); \
} while(0)

/* the fingerprint of an OSes TCP SYN packet */
typedef u_int64_t	pf_tcpopts_t;
struct pf_os_fingerprint {
	SLIST_HEAD(pf_osfp_enlist, pf_osfp_entry) fp_oses; /* list of matches */
	pf_tcpopts_t		fp_tcpopts;	/* packed TCP options */
	u_int16_t		fp_wsize;	/* TCP window size */
	u_int16_t		fp_psize;	/* ip->ip_len */
	u_int16_t		fp_mss;		/* TCP MSS */
	u_int16_t		fp_flags;
#define PF_OSFP_WSIZE_MOD	0x0001		/* Window modulus */
#define PF_OSFP_WSIZE_DC	0x0002		/* Window don't care */
#define PF_OSFP_WSIZE_MSS	0x0004		/* Window multiple of MSS */
#define PF_OSFP_WSIZE_MTU	0x0008		/* Window multiple of MTU */
#define PF_OSFP_PSIZE_MOD	0x0010		/* packet size modulus */
#define PF_OSFP_PSIZE_DC	0x0020		/* packet size don't care */
#define PF_OSFP_WSCALE		0x0040		/* TCP window scaling */
#define PF_OSFP_WSCALE_MOD	0x0080		/* TCP window scale modulus */
#define PF_OSFP_WSCALE_DC	0x0100		/* TCP window scale dont-care */
#define PF_OSFP_MSS		0x0200		/* TCP MSS */
#define PF_OSFP_MSS_MOD		0x0400		/* TCP MSS modulus */
#define PF_OSFP_MSS_DC		0x0800		/* TCP MSS dont-care */
#define PF_OSFP_DF		0x1000		/* IPv4 don't fragment bit */
#define PF_OSFP_TS0		0x2000		/* Zero timestamp */
#define PF_OSFP_INET6		0x4000		/* IPv6 */
	u_int8_t		fp_optcnt;	/* TCP option count */
	u_int8_t		fp_wscale;	/* TCP window scaling */
	u_int8_t		fp_ttl;		/* IPv4 TTL */
#define PF_OSFP_MAXTTL_OFFSET	40
/* TCP options packing */
#define PF_OSFP_TCPOPT_NOP	0x0		/* TCP NOP option */
#define PF_OSFP_TCPOPT_WSCALE	0x1		/* TCP window scaling option */
#define PF_OSFP_TCPOPT_MSS	0x2		/* TCP max segment size opt */
#define PF_OSFP_TCPOPT_SACK	0x3		/* TCP SACK OK option */
#define PF_OSFP_TCPOPT_TS	0x4		/* TCP timestamp option */
#define PF_OSFP_TCPOPT_BITS	3		/* bits used by each option */
#define PF_OSFP_MAX_OPTS \
    (sizeof(((struct pf_os_fingerprint *)0)->fp_tcpopts) * 8) \
    / PF_OSFP_TCPOPT_BITS

	SLIST_ENTRY(pf_os_fingerprint)	fp_next;
};

struct pf_osfp_ioctl {
	struct pf_osfp_entry	fp_os;
	pf_tcpopts_t		fp_tcpopts;	/* packed TCP options */
	u_int16_t		fp_wsize;	/* TCP window size */
	u_int16_t		fp_psize;	/* ip->ip_len */
	u_int16_t		fp_mss;		/* TCP MSS */
	u_int16_t		fp_flags;
	u_int8_t		fp_optcnt;	/* TCP option count */
	u_int8_t		fp_wscale;	/* TCP window scaling */
	u_int8_t		fp_ttl;		/* IPv4 TTL */

	int			fp_getnum;	/* DIOCOSFPGET number */
};

#define	PF_ANCHOR_NAME_SIZE	 64

struct pf_rule {
	struct pf_rule_addr	 src;
	struct pf_rule_addr	 dst;
#define PF_SKIP_IFP		0
#define PF_SKIP_DIR		1
#define PF_SKIP_AF		2
#define PF_SKIP_PROTO		3
#define PF_SKIP_SRC_ADDR	4
#define PF_SKIP_SRC_PORT	5
#define PF_SKIP_DST_ADDR	6
#define PF_SKIP_DST_PORT	7
#define PF_SKIP_COUNT		8
	union pf_rule_ptr	 skip[PF_SKIP_COUNT];
#define PF_RULE_LABEL_SIZE	 64
#define PF_RULE_MAX_LABEL_COUNT	 5
	char			 label[PF_RULE_LABEL_SIZE];
	char			 ifname[IFNAMSIZ];
	char			 qname[PF_QNAME_SIZE];
	char			 pqname[PF_QNAME_SIZE];
#define	PF_TAG_NAME_SIZE	 64
	char			 tagname[PF_TAG_NAME_SIZE];
	char			 match_tagname[PF_TAG_NAME_SIZE];

	char			 overload_tblname[PF_TABLE_NAME_SIZE];

	TAILQ_ENTRY(pf_rule)	 entries;
	struct pf_pool		 rpool;

	u_int64_t		 evaluations;
	u_int64_t		 packets[2];
	u_int64_t		 bytes[2];

	struct pfi_kif		*kif;
	struct pf_anchor	*anchor;
	struct pfr_ktable	*overload_tbl;

	pf_osfp_t		 os_fingerprint;

	int			 rtableid;
	u_int32_t		 timeout[PFTM_OLD_MAX];
	u_int32_t		 max_states;
	u_int32_t		 max_src_nodes;
	u_int32_t		 max_src_states;
	u_int32_t		 max_src_conn;
	struct {
		u_int32_t		limit;
		u_int32_t		seconds;
	}			 max_src_conn_rate;
	u_int32_t		 qid;
	u_int32_t		 pqid;
	u_int32_t		 rt_listid;
	u_int32_t		 nr;
	u_int32_t		 prob;
	uid_t			 cuid;
	pid_t			 cpid;

	counter_u64_t		 states_cur;
	counter_u64_t		 states_tot;
	counter_u64_t		 src_nodes;

	u_int16_t		 return_icmp;
	u_int16_t		 return_icmp6;
	u_int16_t		 max_mss;
	u_int16_t		 tag;
	u_int16_t		 match_tag;
	u_int16_t		 scrub_flags;

	struct pf_rule_uid	 uid;
	struct pf_rule_gid	 gid;

	u_int32_t		 rule_flag;
	u_int8_t		 action;
	u_int8_t		 direction;
	u_int8_t		 log;
	u_int8_t		 logif;
	u_int8_t		 quick;
	u_int8_t		 ifnot;
	u_int8_t		 match_tag_not;
	u_int8_t		 natpass;

#define PF_STATE_NORMAL		0x1
#define PF_STATE_MODULATE	0x2
#define PF_STATE_SYNPROXY	0x3
	u_int8_t		 keep_state;
	sa_family_t		 af;
	u_int8_t		 proto;
	u_int8_t		 type;
	u_int8_t		 code;
	u_int8_t		 flags;
	u_int8_t		 flagset;
	u_int8_t		 min_ttl;
	u_int8_t		 allow_opts;
	u_int8_t		 rt;
	u_int8_t		 return_ttl;
	u_int8_t		 tos;
	u_int8_t		 set_tos;
	u_int8_t		 anchor_relative;
	u_int8_t		 anchor_wildcard;

#define PF_FLUSH		0x01
#define PF_FLUSH_GLOBAL		0x02
	u_int8_t		 flush;
#define PF_PRIO_ZERO		0xff		/* match "prio 0" packets */
#define PF_PRIO_MAX		7
	u_int8_t		 prio;
	u_int8_t		 set_prio[2];

	struct {
		struct pf_addr		addr;
		u_int16_t		port;
	}			divert;

	uint64_t		 u_states_cur;
	uint64_t		 u_states_tot;
	uint64_t		 u_src_nodes;
};

/* pf_krule->rule_flag and old-style scrub flags */
#define	PFRULE_DROP		0x00000000
#define	PFRULE_RETURNRST	0x00000001
#define	PFRULE_FRAGMENT		0x00000002
#define	PFRULE_RETURNICMP	0x00000004
#define	PFRULE_RETURN		0x00000008
#define	PFRULE_NOSYNC		0x00000010
#define	PFRULE_SRCTRACK		0x00000020  /* track source states */
#define	PFRULE_RULESRCTRACK	0x00000040  /* per rule */
#define	PFRULE_NODF		0x00000100
#define	PFRULE_FRAGMENT_NOREASS	0x00000200
#define	PFRULE_RANDOMID		0x00000800
#define	PFRULE_REASSEMBLE_TCP	0x00001000
#define	PFRULE_SET_TOS		0x00002000
#define	PFRULE_IFBOUND		0x00010000 /* if-bound */
#define	PFRULE_STATESLOPPY	0x00020000 /* sloppy state tracking */

#ifdef _KERNEL
#define	PFRULE_REFS		0x0080	/* rule has references */
#endif

/* pf_rule_actions->dnflags */
#define	PFRULE_DN_IS_PIPE	0x0040
#define	PFRULE_DN_IS_QUEUE	0x0080

/* pf_state->state_flags, pf_rule_actions->flags, pf_krule->scrub_flags */
#define	PFSTATE_ALLOWOPTS	0x0001
#define	PFSTATE_SLOPPY		0x0002
/*  was	PFSTATE_PFLOW		0x0004 */
#define	PFSTATE_NOSYNC		0x0008
#define	PFSTATE_ACK		0x0010
#define	PFSTATE_NODF		0x0020
#define	PFSTATE_SETTOS		0x0040
#define	PFSTATE_RANDOMID	0x0080
#define	PFSTATE_SCRUB_TCP	0x0100
#define	PFSTATE_SETPRIO		0x0200
/* was	PFSTATE_INP_UNLINKED	0x0400 */
/* FreeBSD-specific flags are added from the end to keep space for porting
 * flags from OpenBSD */
#define	PFSTATE_DN_IS_PIPE	0x4000
#define	PFSTATE_DN_IS_QUEUE	0x8000
#define	PFSTATE_SCRUBMASK (PFSTATE_NODF|PFSTATE_RANDOMID|PFSTATE_SCRUB_TCP)
#define	PFSTATE_SETMASK   (PFSTATE_SETTOS|PFSTATE_SETPRIO)

#define PFSTATE_HIWAT		100000	/* default state table size */
#define PFSTATE_ADAPT_START	60000	/* default adaptive timeout start */
#define PFSTATE_ADAPT_END	120000	/* default adaptive timeout end */


struct pf_threshold {
	u_int32_t	limit;
#define	PF_THRESHOLD_MULT	1000
#define PF_THRESHOLD_MAX	0xffffffff / PF_THRESHOLD_MULT
	u_int32_t	seconds;
	u_int32_t	count;
	u_int32_t	last;
};

struct pf_src_node {
	LIST_ENTRY(pf_src_node) entry;
	struct pf_addr	 addr;
	struct pf_addr	 raddr;
	union pf_rule_ptr rule;
	struct pfi_kif	*kif;
	u_int64_t	 bytes[2];
	u_int64_t	 packets[2];
	u_int32_t	 states;
	u_int32_t	 conn;
	struct pf_threshold	conn_rate;
	u_int32_t	 creation;
	u_int32_t	 expire;
	sa_family_t	 af;
	u_int8_t	 ruletype;
};

#define PFSNODE_HIWAT		10000	/* default source node table size */

TAILQ_HEAD(pf_rulequeue, pf_rule);

struct pf_anchor;

struct pf_ruleset {
	struct {
		struct pf_rulequeue	 queues[2];
		struct {
			struct pf_rulequeue	*ptr;
			struct pf_rule		**ptr_array;
			u_int32_t		 rcount;
			u_int32_t		 ticket;
			int			 open;
		}			 active, inactive;
	}			 rules[PF_RULESET_MAX];
	struct pf_anchor	*anchor;
	u_int32_t		 tticket;
	int			 tables;
	int			 topen;
};

RB_HEAD(pf_anchor_global, pf_anchor);
RB_HEAD(pf_anchor_node, pf_anchor);
struct pf_anchor {
	RB_ENTRY(pf_anchor)	 entry_global;
	RB_ENTRY(pf_anchor)	 entry_node;
	struct pf_anchor	*parent;
	struct pf_anchor_node	 children;
	char			 name[PF_ANCHOR_NAME_SIZE];
	char			 path[MAXPATHLEN];
	struct pf_ruleset	 ruleset;
	int			 refcnt;	/* anchor rules */
	int			 match;	/* XXX: used for pfctl black magic */
};
RB_PROTOTYPE(pf_anchor_global, pf_anchor, entry_global, pf_anchor_compare);
RB_PROTOTYPE(pf_anchor_node, pf_anchor, entry_node, pf_anchor_compare);

int	 pf_get_ruleset_number(u_int8_t);

#endif	/* _NET_PF_H_ */