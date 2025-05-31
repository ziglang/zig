/*	$NetBSD: at.h,v 1.8 2014/12/02 19:33:44 christos Exp $	*/

/*
 * Copyright (c) 1990,1991 Regents of The University of Michigan.
 * All Rights Reserved.
 *
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose and without fee is hereby granted,
 * provided that the above copyright notice appears in all copies and
 * that both that copyright notice and this permission notice appear
 * in supporting documentation, and that the name of The University
 * of Michigan not be used in advertising or publicity pertaining to
 * distribution of the software without specific, written prior
 * permission. This software is supplied as is without expressed or
 * implied warranties of any kind.
 *
 * This product includes software developed by the University of
 * California, Berkeley and its contributors.
 *
 *	Research Systems Unix Group
 *	The University of Michigan
 *	c/o Wesley Craig
 *	535 W. William Street
 *	Ann Arbor, Michigan
 *	+1-313-764-2278
 *	netatalk@umich.edu
 */

#ifndef _NETATALK_AT_H_
#define _NETATALK_AT_H_

#include <sys/ansi.h>

#ifndef sa_family_t
typedef __sa_family_t	sa_family_t;
#define sa_family_t	__sa_family_t
#endif

/*
 * Supported protocols
 */
#define ATPROTO_DDP	0
#define ATPROTO_AARP	254

#define DDP_MAXSZ	587

/*
 * If ATPORT_FIRST <= Port < ATPORT_RESERVED,
 * Port was created by a privileged process.
 * If ATPORT_RESERVED <= Port < ATPORT_LAST,
 * Port was not necessarily created by a
 * privileged process.
 */
#define ATPORT_FIRST	1
#define ATPORT_RESERVED	128
#define ATPORT_LAST	255

/*
 * AppleTalk address.
 */
struct at_addr {
	uint16_t         s_net;
	uint8_t          s_node;
};

#define ATADDR_ANYNET	(uint16_t)0x0000
#define ATADDR_ANYNODE	(uint8_t)0x00
#define ATADDR_ANYPORT	(uint8_t)0x00
#define ATADDR_BCAST	(uint8_t)0xff	/* There is no BCAST for NET */

struct netrange {
	uint8_t		nr_phase;
	uint16_t	nr_firstnet;
	uint16_t	nr_lastnet;
};

/*
 * Socket address, AppleTalk style.  We keep magic information in the
 * zero bytes.  There are three types, NONE, CONFIG which has the phase
 * and a net range, and IFACE which has the network address of an
 * interface.  IFACE may be filled in by the client, and is filled in
 * by the kernel.
 */
struct sockaddr_at {
	uint8_t		sat_len;
	sa_family_t	sat_family;
	uint8_t		sat_port;
	struct at_addr  sat_addr;
	union {
		struct netrange r_netrange;
		char            r_zero[8];	/* Hide a struct netrange in
						 * here */
	} sat_range;
};

#define sat_zero sat_range.r_zero

#ifdef _KERNEL
#include <sys/protosw.h>

extern struct domain atalkdomain;
extern const struct protosw atalksw[];
#endif

#if defined(_KERNEL) || defined(_TEST)
#define ATALK_ADDRSTRLEN 10

extern struct domain atalkdomain;
int at_print(char *, size_t, const struct at_addr *);
int sat_print(char *, size_t, const void *);
#endif

#endif	/* !_NETATALK_AT_H_ */