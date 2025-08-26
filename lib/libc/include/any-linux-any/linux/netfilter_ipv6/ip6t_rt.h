/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _IP6T_RT_H
#define _IP6T_RT_H

#include <linux/types.h>
#include <linux/in6.h>

#define IP6T_RT_HOPS 16

struct ip6t_rt {
	__u32 rt_type;			/* Routing Type */
	__u32 segsleft[2];			/* Segments Left */
	__u32 hdrlen;			/* Header Length */
	__u8  flags;			/*  */
	__u8  invflags;			/* Inverse flags */
	struct in6_addr addrs[IP6T_RT_HOPS];	/* Hops */
	__u8 addrnr;			/* Nr of Addresses */
};

#define IP6T_RT_TYP 		0x01
#define IP6T_RT_SGS 		0x02
#define IP6T_RT_LEN 		0x04
#define IP6T_RT_RES 		0x08
#define IP6T_RT_FST_MASK	0x30
#define IP6T_RT_FST 		0x10
#define IP6T_RT_FST_NSTRICT	0x20

/* Values for "invflags" field in struct ip6t_rt. */
#define IP6T_RT_INV_TYP		0x01	/* Invert the sense of type. */
#define IP6T_RT_INV_SGS		0x02	/* Invert the sense of Segments. */
#define IP6T_RT_INV_LEN		0x04	/* Invert the sense of length. */
#define IP6T_RT_INV_MASK	0x07	/* All possible flags. */

#endif /*_IP6T_RT_H*/