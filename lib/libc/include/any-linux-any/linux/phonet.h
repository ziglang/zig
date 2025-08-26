/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/**
 * file phonet.h
 *
 * Phonet sockets kernel interface
 *
 * Copyright (C) 2008 Nokia Corporation. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA
 */

#ifndef LINUX_PHONET_H
#define LINUX_PHONET_H

#include <linux/types.h>
#include <linux/socket.h>

/* Automatic protocol selection */
#define PN_PROTO_TRANSPORT	0
/* Phonet datagram socket */
#define PN_PROTO_PHONET		1
/* Phonet pipe */
#define PN_PROTO_PIPE		2
#define PHONET_NPROTO		3

/* Socket options for SOL_PNPIPE level */
#define PNPIPE_ENCAP		1
#define PNPIPE_IFINDEX		2
#define PNPIPE_HANDLE		3
#define PNPIPE_INITSTATE	4

#define PNADDR_ANY		0
#define PNADDR_BROADCAST	0xFC
#define PNPORT_RESOURCE_ROUTING	0

/* Values for PNPIPE_ENCAP option */
#define PNPIPE_ENCAP_NONE	0
#define PNPIPE_ENCAP_IP		1

/* ioctls */
#define SIOCPNGETOBJECT		(SIOCPROTOPRIVATE + 0)
#define SIOCPNENABLEPIPE	(SIOCPROTOPRIVATE + 13)
#define SIOCPNADDRESOURCE	(SIOCPROTOPRIVATE + 14)
#define SIOCPNDELRESOURCE	(SIOCPROTOPRIVATE + 15)

/* Phonet protocol header */
struct phonethdr {
	__u8	pn_rdev;
	__u8	pn_sdev;
	__u8	pn_res;
	__be16	pn_length;
	__u8	pn_robj;
	__u8	pn_sobj;
} __attribute__((packed));

/* Common Phonet payload header */
struct phonetmsg {
	__u8	pn_trans_id;	/* transaction ID */
	__u8	pn_msg_id;	/* message type */
	union {
		struct {
			__u8	pn_submsg_id;	/* message subtype */
			__u8	pn_data[5];
		} base;
		struct {
			__u16	pn_e_res_id;	/* extended resource ID */
			__u8	pn_e_submsg_id;	/* message subtype */
			__u8	pn_e_data[3];
		} ext;
	} pn_msg_u;
};
#define PN_COMMON_MESSAGE	0xF0
#define PN_COMMGR		0x10
#define PN_PREFIX		0xE0 /* resource for extended messages */
#define pn_submsg_id		pn_msg_u.base.pn_submsg_id
#define pn_e_submsg_id		pn_msg_u.ext.pn_e_submsg_id
#define pn_e_res_id		pn_msg_u.ext.pn_e_res_id
#define pn_data			pn_msg_u.base.pn_data
#define pn_e_data		pn_msg_u.ext.pn_e_data

/* data for unreachable errors */
#define PN_COMM_SERVICE_NOT_IDENTIFIED_RESP	0x01
#define PN_COMM_ISA_ENTITY_NOT_REACHABLE_RESP	0x14
#define pn_orig_msg_id		pn_data[0]
#define pn_status		pn_data[1]
#define pn_e_orig_msg_id	pn_e_data[0]
#define pn_e_status		pn_e_data[1]

/* Phonet socket address structure */
struct sockaddr_pn {
	__kernel_sa_family_t spn_family;
	__u8 spn_obj;
	__u8 spn_dev;
	__u8 spn_resource;
	__u8 spn_zero[sizeof(struct sockaddr) - sizeof(__kernel_sa_family_t) - 3];
} __attribute__((packed));

/* Well known address */
#define PN_DEV_PC	0x10

static __inline__ __u16 pn_object(__u8 addr, __u16 port)
{
	return (addr << 8) | (port & 0x3ff);
}

static __inline__ __u8 pn_obj(__u16 handle)
{
	return handle & 0xff;
}

static __inline__ __u8 pn_dev(__u16 handle)
{
	return handle >> 8;
}

static __inline__ __u16 pn_port(__u16 handle)
{
	return handle & 0x3ff;
}

static __inline__ __u8 pn_addr(__u16 handle)
{
	return (handle >> 8) & 0xfc;
}

static __inline__ void pn_sockaddr_set_addr(struct sockaddr_pn *spn, __u8 addr)
{
	spn->spn_dev &= 0x03;
	spn->spn_dev |= addr & 0xfc;
}

static __inline__ void pn_sockaddr_set_port(struct sockaddr_pn *spn, __u16 port)
{
	spn->spn_dev &= 0xfc;
	spn->spn_dev |= (port >> 8) & 0x03;
	spn->spn_obj = port & 0xff;
}

static __inline__ void pn_sockaddr_set_object(struct sockaddr_pn *spn,
						__u16 handle)
{
	spn->spn_dev = pn_dev(handle);
	spn->spn_obj = pn_obj(handle);
}

static __inline__ void pn_sockaddr_set_resource(struct sockaddr_pn *spn,
						__u8 resource)
{
	spn->spn_resource = resource;
}

static __inline__ __u8 pn_sockaddr_get_addr(const struct sockaddr_pn *spn)
{
	return spn->spn_dev & 0xfc;
}

static __inline__ __u16 pn_sockaddr_get_port(const struct sockaddr_pn *spn)
{
	return ((spn->spn_dev & 0x03) << 8) | spn->spn_obj;
}

static __inline__ __u16 pn_sockaddr_get_object(const struct sockaddr_pn *spn)
{
	return pn_object(spn->spn_dev, spn->spn_obj);
}

static __inline__ __u8 pn_sockaddr_get_resource(const struct sockaddr_pn *spn)
{
	return spn->spn_resource;
}

/* Phonet device ioctl requests */

#endif /* LINUX_PHONET_H */