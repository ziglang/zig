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
 * Interface address-related (RTM_<NEW|DEL|GET>ADDR) message header and attributes.
 */

#ifndef _NETLINK_ROUTE_IFADDRS_H_
#define _NETLINK_ROUTE_IFADDRS_H_

/* Base header for all of the relevant messages */
struct ifaddrmsg {
	uint8_t		ifa_family;	/* Address family */
	uint8_t		ifa_prefixlen;	/* Prefix length */
	uint8_t		ifa_flags;	/* Address-specific flags */
	uint8_t		ifa_scope;	/* Address scope */
	uint32_t	ifa_index;	/* Link ifindex */
};

#ifndef _KERNEL
#define	_NL_IFA_HDRLEN		((int)sizeof(struct ifaddrmsg))
#define	IFA_RTA(_ifa)		((struct rtattr *)(NL_ITEM_DATA(_ifa, _NL_IFA_HDRLEN)))
#define	IFA_PAYLOAD(_hdr)	NLMSG_PAYLOAD(_hdr, _NL_IFA_HDRLEN)
#endif

/* Defined attributes */
enum {
	IFA_UNSPEC,
	IFA_ADDRESS		= 1, /* binary, prefix address (destination for p2p) */
	IFA_LOCAL		= 2, /* binary, interface address */
	IFA_LABEL		= 3, /* string, interface name */
	IFA_BROADCAST		= 4, /* binary, broadcast ifa */
	IFA_ANYCAST		= 5, /* not supported */
	IFA_CACHEINFO		= 6, /* binary, struct ifa_cacheinfo */
	IFA_MULTICAST		= 7, /* not supported */
	IFA_FLAGS		= 8, /* u32, IFA_F flags */
	IFA_RT_PRIORITY		= 9, /* not supported */
	IFA_TARGET_NETNSID	= 10, /* not supported */
	IFA_FREEBSD		= 11, /* nested, FreeBSD-specific */
	__IFA_MAX,
};
#define IFA_MAX		(__IFA_MAX - 1)

enum {
	IFAF_UNSPEC,
	IFAF_VHID		= 1, /* u32: carp vhid */
	IFAF_FLAGS		= 2, /* u32: FreeBSD-specific ifa flags */
	__IFAF_MAX,
};
#define IFAF_MAX	(__IFAF_MAX - 1)

/* IFA_FLAGS attribute flags */
#define IFA_F_SECONDARY		0x0001
#define IFA_F_TEMPORARY		IFA_F_SECONDARY
#define IFA_F_NODAD		0x0002
#define IFA_F_OPTIMISTIC	0x0004
#define IFA_F_DADFAILED		0x0008
#define IFA_F_HOMEADDRESS	0x0010
#define IFA_F_DEPRECATED	0x0020
#define IFA_F_TENTATIVE		0x0040
#define IFA_F_PERMANENT		0x0080
#define IFA_F_MANAGETEMPADDR	0x0100
#define IFA_F_NOPREFIXROUTE	0x0200
#define IFA_F_MCAUTOJOIN	0x0400
#define IFA_F_STABLE_PRIVACY	0x0800

/* IFA_CACHEINFO value */
struct ifa_cacheinfo {
	uint32_t ifa_prefered;	/* seconds till the end of the prefix considered preferred */
	uint32_t ifa_valid;	/* seconds till the end of the prefix considered valid */
	uint32_t cstamp;	/* creation time in 1ms intervals from the boot time */
	uint32_t tstamp;	/* update time in 1ms intervals from the boot time */
};

#endif