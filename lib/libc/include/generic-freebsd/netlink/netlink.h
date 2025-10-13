/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 Ng Peng Nam Sean
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
 *
 * Copyright (C) The Internet Society (2003).  All Rights Reserved.
 *
 * This document and translations of it may be copied and furnished to
 * others, and derivative works that comment on or otherwise explain it
 * or assist in its implementation may be prepared, copied, published
 * and distributed, in whole or in part, without restriction of any
 * kind, provided that the above copyright notice and this paragraph are
 * included on all such copies and derivative works.  However, this
 * document itself may not be modified in any way, such as by removing
 * the copyright notice or references to the Internet Society or other
 * Internet organizations, except as needed for the purpose of
 * developing Internet standards in which case the procedures for
 * copyrights defined in the Internet Standards process must be
 * followed, or as required to translate it into languages other than
 * English.
 *
 * The limited permissions granted above are perpetual and will not be
 * revoked by the Internet Society or its successors or assignees.
 *
 * This document and the information contained herein is provided on an
 * "AS IS" basis and THE INTERNET SOCIETY AND THE INTERNET ENGINEERING
 * TASK FORCE DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO ANY WARRANTY THAT THE USE OF THE INFORMATION
 * HEREIN WILL NOT INFRINGE ANY RIGHTS OR ANY IMPLIED WARRANTIES OF
 * MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

 */

/*
 * This file contains structures and constants for RFC 3549 (Netlink)
 * protocol. Some values have been taken from Linux implementation.
 */

#ifndef _NETLINK_NETLINK_H_
#define _NETLINK_NETLINK_H_

#include <sys/types.h>
#include <sys/socket.h>

struct sockaddr_nl {
	uint8_t		nl_len;		/* sizeof(sockaddr_nl) */
	sa_family_t	nl_family;	/* netlink family */
	uint16_t	nl_pad;		/* reserved, set to 0 */
	uint32_t	nl_pid;		/* desired port ID, 0 for auto-select */
	uint32_t	nl_groups;	/* multicast groups mask to bind to */
};

#define	SOL_NETLINK			270

/* Netlink socket options */
#define NETLINK_ADD_MEMBERSHIP		1 /* Subscribe for the specified group notifications */
#define NETLINK_DROP_MEMBERSHIP		2 /* Unsubscribe from the specified group */
#define NETLINK_PKTINFO			3 /* XXX: not supported */
#define NETLINK_BROADCAST_ERROR		4 /* XXX: not supported */
#define NETLINK_NO_ENOBUFS		5 /* XXX: not supported */
#define NETLINK_RX_RING			6 /* XXX: not supported */
#define NETLINK_TX_RING			7 /* XXX: not supported */
#define NETLINK_LISTEN_ALL_NSID		8 /* XXX: not supported */

#define NETLINK_LIST_MEMBERSHIPS	9
#define NETLINK_CAP_ACK			10 /* Send only original message header in the reply */
#define NETLINK_EXT_ACK			11 /* Ack support for receiving additional TLVs in ack */
#define NETLINK_GET_STRICT_CHK		12 /* Strict header checking */

#define	NETLINK_MSG_INFO		257 /* (FreeBSD-specific) Receive message originator data in cmsg */

/*
 * RFC 3549, 2.3.2 Netlink Message Header
 */
struct nlmsghdr {
	uint32_t nlmsg_len;   /* Length of message including header */
	uint16_t nlmsg_type;  /* Message type identifier */
	uint16_t nlmsg_flags; /* Flags (NLM_F_) */
	uint32_t nlmsg_seq;   /* Sequence number */
	uint32_t nlmsg_pid;   /* Sending process port ID */
};

/*
 * RFC 3549, 2.3.2 standard flag bits (nlmsg_flags)
 */
#define NLM_F_REQUEST		0x01	/* Indicateds request to kernel */
#define NLM_F_MULTI		0x02	/* Message is part of a group terminated by NLMSG_DONE msg */
#define NLM_F_ACK		0x04	/* Reply with ack message containing resulting error code */
#define NLM_F_ECHO		0x08	/* (not supported) Echo this request back */
#define NLM_F_DUMP_INTR		0x10	/* Dump was inconsistent due to sequence change */
#define NLM_F_DUMP_FILTERED	0x20	/* Dump was filtered as requested */

/*
 * RFC 3549, 2.3.2 Additional flag bits for GET requests
 */
#define NLM_F_ROOT		0x100	/* Return the complete table */
#define NLM_F_MATCH		0x200	/* Return all entries matching criteria */
#define NLM_F_ATOMIC		0x400	/* Return an atomic snapshot (ignored) */
#define NLM_F_DUMP		(NLM_F_ROOT | NLM_F_MATCH)

/*
 * RFC 3549, 2.3.2 Additional flag bits for NEW requests
 */
#define NLM_F_REPLACE		0x100	/* Replace existing matching config object */
#define NLM_F_EXCL		0x200	/* Don't replace the object if exists */
#define NLM_F_CREATE		0x400	/* Create if it does not exist */
#define NLM_F_APPEND		0x800	/* Add to end of list */

/* Modifiers to DELETE requests */
#define NLM_F_NONREC		0x100	/* Do not delete recursively */

/* Flags for ACK message */
#define NLM_F_CAPPED		0x100	/* request was capped */
#define NLM_F_ACK_TLVS		0x200	/* extended ACK TVLs were included */

/*
 * RFC 3549, 2.3.2 standard message types (nlmsg_type).
 */
#define NLMSG_NOOP		0x1	/* Message is ignored. */
#define NLMSG_ERROR		0x2	/* reply error code reporting */
#define NLMSG_DONE		0x3	/* Message terminates a multipart message. */
#define NLMSG_OVERRUN		0x4	/* overrun detected, data is lost */

#define NLMSG_MIN_TYPE		0x10	/* < 0x10: reserved control messages */

/*
 * Defition of numbers assigned to the netlink subsystems.
 */
#define NETLINK_ROUTE		0	/* Routing/device hook */
#define NETLINK_UNUSED		1	/* not supported */
#define NETLINK_USERSOCK	2	/* not supported */
#define NETLINK_FIREWALL	3	/* not supported */
#define NETLINK_SOCK_DIAG	4	/* not supported */
#define NETLINK_NFLOG		5	/* not supported */
#define NETLINK_XFRM		6	/* (not supported) PF_SETKEY */
#define NETLINK_SELINUX		7	/* not supported */
#define NETLINK_ISCSI		8	/* not supported */
#define NETLINK_AUDIT		9	/* not supported */
#define NETLINK_FIB_LOOKUP	10	/* not supported */
#define NETLINK_CONNECTOR	11	/* not supported */
#define NETLINK_NETFILTER	12	/* not supported */
#define NETLINK_IP6_FW		13	/* not supported  */
#define NETLINK_DNRTMSG		14	/* not supported */
#define NETLINK_KOBJECT_UEVENT	15	/* not supported */
#define NETLINK_GENERIC		16	/* Generic netlink (dynamic families) */

/*
 * RFC 3549, 2.3.2.2 The ACK Netlink Message
 */
struct nlmsgerr {
	int	error;
	struct	nlmsghdr msg;
};

enum nlmsgerr_attrs {
	NLMSGERR_ATTR_UNUSED,
	NLMSGERR_ATTR_MSG	= 1, /* string, error message */
	NLMSGERR_ATTR_OFFS	= 2, /* u32, offset of the invalid attr from nl header */
	NLMSGERR_ATTR_COOKIE	= 3, /* binary, data to pass to userland */
	NLMSGERR_ATTR_POLICY	= 4, /* not supported */
	__NLMSGERR_ATTR_MAX,
	NLMSGERR_ATTR_MAX = __NLMSGERR_ATTR_MAX - 1
};

/* FreeBSD-specific debugging info */

enum nlmsginfo_attrs {
	NLMSGINFO_ATTR_UNUSED,
	NLMSGINFO_ATTR_PROCESS_ID	= 1, /* u32, source process PID */
	NLMSGINFO_ATTR_PORT_ID		= 2, /* u32, source socket nl_pid */
	NLMSGINFO_ATTR_SEQ_ID		= 3, /* u32, source message seq_id */
};


#ifndef roundup2
#define	roundup2(x, y)	(((x)+((y)-1))&(~((y)-1))) /* if y is powers of two */
#endif
#define	NL_ITEM_ALIGN_SIZE		sizeof(uint32_t)
#define	NL_ITEM_ALIGN(_len)		roundup2(_len, NL_ITEM_ALIGN_SIZE)
#define	NL_ITEM_DATA(_ptr, _off)	((void *)((char *)(_ptr) + _off))
#define	NL_ITEM_DATA_CONST(_ptr, _off)	((const void *)((const char *)(_ptr) + _off))

#define	NL_ITEM_OK(_ptr, _len, _hlen, _LEN_M)	\
	((_len) >= _hlen && _LEN_M(_ptr) >= _hlen && _LEN_M(_ptr) <= (_len))
#define	NL_ITEM_NEXT(_ptr, _LEN_M)	((__typeof(_ptr))((char *)(_ptr) + _LEN_M(_ptr)))
#define	NL_ITEM_ITER(_ptr, _len, _LEN_MACRO)	\
	((_len) -= _LEN_MACRO(_ptr), NL_ITEM_NEXT(_ptr, _LEN_MACRO))


#ifndef _KERNEL
/* part of netlink(3) API */
#define NLMSG_ALIGNTO			NL_ITEM_ALIGN_SIZE
#define NLMSG_ALIGN(_len)		NL_ITEM_ALIGN(_len)
#define NLMSG_HDRLEN			((int)sizeof(struct nlmsghdr))
#define NLMSG_LENGTH(_len)		((_len) + NLMSG_HDRLEN)
#define NLMSG_SPACE(_len)		NLMSG_ALIGN(NLMSG_LENGTH(_len))
#define NLMSG_DATA(_hdr)		NL_ITEM_DATA(_hdr, NLMSG_HDRLEN)
#define	_NLMSG_LEN(_hdr)		((int)(_hdr)->nlmsg_len)
#define	_NLMSG_ALIGNED_LEN(_hdr)	NLMSG_ALIGN(_NLMSG_LEN(_hdr))
#define	NLMSG_OK(_hdr, _len)		NL_ITEM_OK(_hdr, _len, NLMSG_HDRLEN, _NLMSG_LEN)
#define NLMSG_PAYLOAD(_hdr,_len)	(_NLMSG_LEN(_hdr) - NLMSG_SPACE((_len)))
#define	NLMSG_NEXT(_hdr, _len)		NL_ITEM_ITER(_hdr, _len, _NLMSG_ALIGNED_LEN)

#else
#define NLMSG_ALIGNTO 4U
#define NLMSG_ALIGN(len) (((len) + NLMSG_ALIGNTO - 1) & ~(NLMSG_ALIGNTO - 1))
#define NLMSG_HDRLEN ((int)NLMSG_ALIGN(sizeof(struct nlmsghdr)))
#endif

/*
 * Base netlink attribute TLV header.
 */
struct nlattr {
	uint16_t nla_len;	/* Total attribute length */
	uint16_t nla_type;	/* Attribute type */
};

/*
 *
 * nl_type field enconding:
 *
 * 0                   1
 * 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6
 * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 * |N|O|  Attribute type           |
 * +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 * N - attribute contains other attributes (mostly unused)
 * O - encoded in network byte order (mostly unused)
 * Note: N & O are mutually exclusive
 *
 * Note: attribute type value scope normally is either parent attribute
 * or the message/message group.
 */

#define NLA_F_NESTED (1 << 15)
#define NLA_F_NET_BYTEORDER (1 << 14)
#define NLA_TYPE_MASK ~(NLA_F_NESTED | NLA_F_NET_BYTEORDER)

#ifndef _KERNEL
#define	NLA_ALIGNTO	NL_ITEM_ALIGN_SIZE
#define	NLA_ALIGN(_len)	NL_ITEM_ALIGN(_len)
#define	NLA_HDRLEN	((int)sizeof(struct nlattr))
#endif

#endif