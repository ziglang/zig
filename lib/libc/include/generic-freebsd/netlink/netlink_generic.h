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
 * Generic netlink message header and attributes
 */
#ifndef _NETLINK_NETLINK_GENERIC_H_
#define	_NETLINK_NETLINK_GENERIC_H_

#include <netlink/netlink.h>

/* Base header for all of the relevant messages */
struct genlmsghdr {
	uint8_t		cmd;		/* CTRL_CMD_ */
	uint8_t		version;	/* ABI version for the cmd */
	uint16_t	reserved;	/* reserved: set to 0 */
};
#define GENL_HDRLEN	NL_ITEM_ALIGN(sizeof(struct genlmsghdr))

/* Dynamic family number range, inclusive */
#define	GENL_MIN_ID	NLMSG_MIN_TYPE
#define	GENL_MAX_ID	1023

/* Pre-defined family numbers */
#define	GENL_ID_CTRL	GENL_MIN_ID

/* Available commands */
enum {
	CTRL_CMD_UNSPEC		= 0,
	CTRL_CMD_NEWFAMILY	= 1,
	CTRL_CMD_DELFAMILY	= 2,
	CTRL_CMD_GETFAMILY	= 3, /* lists all (or matching) genetlink families */
	CTRL_CMD_NEWOPS		= 4,
	CTRL_CMD_DELOPS		= 5,
	CTRL_CMD_GETOPS		= 6,
	CTRL_CMD_NEWMCAST_GRP	= 7,
	CTRL_CMD_DELMCAST_GRP	= 8,
	CTRL_CMD_GETMCAST_GRP	= 9,
	CTRL_CMD_GETPOLICY	= 10,
	__CTRL_CMD_MAX,
};
#define	CTRL_CMD_MAX	(__CTRL_CMD_MAX - 1)

/* Generic attributes */
enum {
	CTRL_ATTR_UNSPEC,
	CTRL_ATTR_FAMILY_ID	= 1, /* u16, dynamically-assigned ID */
	CTRL_ATTR_FAMILY_NAME	= 2, /* string, family name */
	CTRL_ATTR_VERSION	= 3, /* u32, command version */
	CTRL_ATTR_HDRSIZE	= 4, /* u32, family header size */
	CTRL_ATTR_MAXATTR	= 5, /* u32, maximum family attr # */
	CTRL_ATTR_OPS		= 6, /* nested, available operations */
	CTRL_ATTR_MCAST_GROUPS	= 7,
	CTRL_ATTR_POLICY	= 8,
	CTRL_ATTR_OP_POLICY	= 9,
	CTRL_ATTR_OP		= 10,
	__CTRL_ATTR_MAX,
};
#define	CTRL_ATTR_MAX	(__CTRL_ATTR_MAX - 1)

#define	GENL_NAMSIZ	16 /* max family name length including \0 */

/* CTRL_ATTR_OPS attributes */
enum {
	CTRL_ATTR_OP_UNSPEC,
	CTRL_ATTR_OP_ID		= 1, /* u32, operation # */
	CTRL_ATTR_OP_FLAGS	= 2, /* u32, flags-based op description */
	__CTRL_ATTR_OP_MAX,
};
#define	CTRL_ATTR_OP_MAX	(__CTRL_ATTR_OP_MAX - 1)

/* CTRL_ATTR_OP_FLAGS values */
#define GENL_ADMIN_PERM		0x0001 /* Requires elevated permissions */
#define GENL_CMD_CAP_DO		0x0002 /* Operation is a modification request */
#define GENL_CMD_CAP_DUMP	0x0004 /* Operation is a get/dump request */
#define GENL_CMD_CAP_HASPOL	0x0008 /* Operation has a validation policy */
#define GENL_UNS_ADMIN_PERM	0x0010

/* CTRL_ATTR_MCAST_GROUPS attributes */
enum {
	CTRL_ATTR_MCAST_GRP_UNSPEC,
	CTRL_ATTR_MCAST_GRP_NAME,	/* string, group name */
	CTRL_ATTR_MCAST_GRP_ID,		/* u32, dynamically-assigned group id */
	__CTRL_ATTR_MCAST_GRP_MAX,
};
#define	CTRL_ATTR_MCAST_GRP_MAX	(__CTRL_ATTR_MCAST_GRP_MAX - 1)


#endif