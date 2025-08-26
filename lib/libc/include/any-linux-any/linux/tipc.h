/* SPDX-License-Identifier: ((GPL-2.0 WITH Linux-syscall-note) OR BSD-3-Clause) */
/*
 * include/uapi/linux/tipc.h: Header for TIPC socket interface
 *
 * Copyright (c) 2003-2006, 2015-2016 Ericsson AB
 * Copyright (c) 2005, 2010-2011, Wind River Systems
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the names of the copyright holders nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * Alternatively, this software may be distributed under the terms of the
 * GNU General Public License ("GPL") version 2 as published by the Free
 * Software Foundation.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _LINUX_TIPC_H_
#define _LINUX_TIPC_H_

#include <linux/types.h>
#include <linux/sockios.h>

/*
 * TIPC addressing primitives
 */

struct tipc_socket_addr {
	__u32 ref;
	__u32 node;
};

struct tipc_service_addr {
	__u32 type;
	__u32 instance;
};

struct tipc_service_range {
	__u32 type;
	__u32 lower;
	__u32 upper;
};

/*
 * Application-accessible service types
 */

#define TIPC_NODE_STATE		0	/* node state service type */
#define TIPC_TOP_SRV		1	/* topology server service type */
#define TIPC_LINK_STATE		2	/* link state service type */
#define TIPC_RESERVED_TYPES	64	/* lowest user-allowed service type */

/*
 * Publication scopes when binding service / service range
 */
enum tipc_scope {
	TIPC_CLUSTER_SCOPE = 2, /* 0 can also be used */
	TIPC_NODE_SCOPE    = 3
};

/*
 * Limiting values for messages
 */

#define TIPC_MAX_USER_MSG_SIZE	66000U

/*
 * Message importance levels
 */

#define TIPC_LOW_IMPORTANCE		0
#define TIPC_MEDIUM_IMPORTANCE		1
#define TIPC_HIGH_IMPORTANCE		2
#define TIPC_CRITICAL_IMPORTANCE	3

/*
 * Msg rejection/connection shutdown reasons
 */

#define TIPC_OK			0
#define TIPC_ERR_NO_NAME	1
#define TIPC_ERR_NO_PORT	2
#define TIPC_ERR_NO_NODE	3
#define TIPC_ERR_OVERLOAD	4
#define TIPC_CONN_SHUTDOWN	5

/*
 * TIPC topology subscription service definitions
 */

#define TIPC_SUB_PORTS          0x01    /* filter: evt at each match */
#define TIPC_SUB_SERVICE        0x02    /* filter: evt at first up/last down */
#define TIPC_SUB_CANCEL         0x04    /* filter: cancel a subscription */

#define TIPC_WAIT_FOREVER	(~0)	/* timeout for permanent subscription */

struct tipc_subscr {
	struct tipc_service_range seq;	/* range of interest */
	__u32 timeout;			/* subscription duration (in ms) */
	__u32 filter;			/* bitmask of filter options */
	char usr_handle[8];		/* available for subscriber use */
};

#define TIPC_PUBLISHED		1	/* publication event */
#define TIPC_WITHDRAWN		2	/* withdrawal event */
#define TIPC_SUBSCR_TIMEOUT	3	/* subscription timeout event */

struct tipc_event {
	__u32 event;			/* event type */
	__u32 found_lower;		/* matching range */
	__u32 found_upper;		/*    "      "    */
	struct tipc_socket_addr port;	/* associated socket */
	struct tipc_subscr s;		/* associated subscription */
};

/*
 * Socket API
 */

#ifndef AF_TIPC
#define AF_TIPC		30
#endif

#ifndef PF_TIPC
#define PF_TIPC		AF_TIPC
#endif

#ifndef SOL_TIPC
#define SOL_TIPC	271
#endif

#define TIPC_ADDR_MCAST         1
#define TIPC_SERVICE_RANGE      1
#define TIPC_SERVICE_ADDR       2
#define TIPC_SOCKET_ADDR        3

struct sockaddr_tipc {
	unsigned short family;
	unsigned char  addrtype;
	signed   char  scope;
	union {
		struct tipc_socket_addr id;
		struct tipc_service_range nameseq;
		struct {
			struct tipc_service_addr name;
			__u32 domain;
		} name;
	} addr;
};

/*
 * Ancillary data objects supported by recvmsg()
 */

#define TIPC_ERRINFO	1	/* error info */
#define TIPC_RETDATA	2	/* returned data */
#define TIPC_DESTNAME	3	/* destination name */

/*
 * TIPC-specific socket option names
 */

#define TIPC_IMPORTANCE		127	/* Default: TIPC_LOW_IMPORTANCE */
#define TIPC_SRC_DROPPABLE	128	/* Default: based on socket type */
#define TIPC_DEST_DROPPABLE	129	/* Default: based on socket type */
#define TIPC_CONN_TIMEOUT	130	/* Default: 8000 (ms)  */
#define TIPC_NODE_RECVQ_DEPTH	131	/* Default: none (read only) */
#define TIPC_SOCK_RECVQ_DEPTH	132	/* Default: none (read only) */
#define TIPC_MCAST_BROADCAST    133     /* Default: TIPC selects. No arg */
#define TIPC_MCAST_REPLICAST    134     /* Default: TIPC selects. No arg */
#define TIPC_GROUP_JOIN         135     /* Takes struct tipc_group_req* */
#define TIPC_GROUP_LEAVE        136     /* No argument */
#define TIPC_SOCK_RECVQ_USED    137     /* Default: none (read only) */
#define TIPC_NODELAY            138     /* Default: false */

/*
 * Flag values
 */
#define TIPC_GROUP_LOOPBACK     0x1  /* Receive copy of sent msg when match */
#define TIPC_GROUP_MEMBER_EVTS  0x2  /* Receive membership events in socket */

struct tipc_group_req {
	__u32 type;      /* group id */
	__u32 instance;  /* member id */
	__u32 scope;     /* cluster/node */
	__u32 flags;
};

/*
 * Maximum sizes of TIPC bearer-related names (including terminating NULL)
 * The string formatting for each name element is:
 * media: media
 * interface: media:interface name
 * link: node:interface-node:interface
 */
#define TIPC_NODEID_LEN         16
#define TIPC_MAX_MEDIA_NAME	16
#define TIPC_MAX_IF_NAME	16
#define TIPC_MAX_BEARER_NAME	32
#define TIPC_MAX_LINK_NAME	68

#define SIOCGETLINKNAME        SIOCPROTOPRIVATE
#define SIOCGETNODEID          (SIOCPROTOPRIVATE + 1)

struct tipc_sioc_ln_req {
	__u32 peer;
	__u32 bearer_id;
	char linkname[TIPC_MAX_LINK_NAME];
};

struct tipc_sioc_nodeid_req {
	__u32 peer;
	char node_id[TIPC_NODEID_LEN];
};

/*
 * TIPC Crypto, AEAD
 */
#define TIPC_AEAD_ALG_NAME		(32)

struct tipc_aead_key {
	char alg_name[TIPC_AEAD_ALG_NAME];
	unsigned int keylen;	/* in bytes */
	char key[];
};

#define TIPC_AEAD_KEYLEN_MIN		(16 + 4)
#define TIPC_AEAD_KEYLEN_MAX		(32 + 4)
#define TIPC_AEAD_KEY_SIZE_MAX		(sizeof(struct tipc_aead_key) + \
							TIPC_AEAD_KEYLEN_MAX)

static __inline__ int tipc_aead_key_size(struct tipc_aead_key *key)
{
	return sizeof(*key) + key->keylen;
}

#define TIPC_REKEYING_NOW		(~0U)

/* The macros and functions below are deprecated:
 */

#define TIPC_CFG_SRV		0
#define TIPC_ZONE_SCOPE         1

#define TIPC_ADDR_NAMESEQ	1
#define TIPC_ADDR_NAME		2
#define TIPC_ADDR_ID		3

#define TIPC_NODE_BITS          12
#define TIPC_CLUSTER_BITS       12
#define TIPC_ZONE_BITS          8

#define TIPC_NODE_OFFSET        0
#define TIPC_CLUSTER_OFFSET     TIPC_NODE_BITS
#define TIPC_ZONE_OFFSET        (TIPC_CLUSTER_OFFSET + TIPC_CLUSTER_BITS)

#define TIPC_NODE_SIZE          ((1UL << TIPC_NODE_BITS) - 1)
#define TIPC_CLUSTER_SIZE       ((1UL << TIPC_CLUSTER_BITS) - 1)
#define TIPC_ZONE_SIZE          ((1UL << TIPC_ZONE_BITS) - 1)

#define TIPC_NODE_MASK		(TIPC_NODE_SIZE << TIPC_NODE_OFFSET)
#define TIPC_CLUSTER_MASK	(TIPC_CLUSTER_SIZE << TIPC_CLUSTER_OFFSET)
#define TIPC_ZONE_MASK		(TIPC_ZONE_SIZE << TIPC_ZONE_OFFSET)

#define TIPC_ZONE_CLUSTER_MASK (TIPC_ZONE_MASK | TIPC_CLUSTER_MASK)

#define tipc_portid tipc_socket_addr
#define tipc_name tipc_service_addr
#define tipc_name_seq tipc_service_range

static __inline__ __u32 tipc_addr(unsigned int zone,
			      unsigned int cluster,
			      unsigned int node)
{
	return (zone << TIPC_ZONE_OFFSET) |
		(cluster << TIPC_CLUSTER_OFFSET) |
		node;
}

static __inline__ unsigned int tipc_zone(__u32 addr)
{
	return addr >> TIPC_ZONE_OFFSET;
}

static __inline__ unsigned int tipc_cluster(__u32 addr)
{
	return (addr & TIPC_CLUSTER_MASK) >> TIPC_CLUSTER_OFFSET;
}

static __inline__ unsigned int tipc_node(__u32 addr)
{
	return addr & TIPC_NODE_MASK;
}

#endif