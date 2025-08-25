/*	$NetBSD: can.h,v 1.3 2017/05/30 13:30:51 bouyer Exp $	*/

/*-
 * Copyright (c) 2003, 2017 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Robert Swindells and Manuel Bouyer
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

#ifndef _NETCAN_CAN_H
#define _NETCAN_CAN_H

#include <sys/featuretest.h>
#include <sys/types.h>


/* Definitions compatible (as much as possible) with socketCAN */

/*
 * CAN id structure
 * bits 0-28	: CAN identifier (11/29 bits, see bit 31)
 * bit2 29-31	: see below
 */

typedef uint32_t canid_t;
typedef uint32_t can_err_mask_t;

/* canid_t bits 29-31 descriptions */
#define CAN_EFF_FLAG 0x80000000U	/* extended frame format */
#define CAN_RTR_FLAG 0x40000000U	/* remote transmission request */
#define CAN_ERR_FLAG 0x20000000U	/* error message frame */

/* valid bits in CAN ID for frame formats */
#define CAN_SFF_MASK 0x000007FFU /* standard frame format (SFF) */
#define CAN_EFF_MASK 0x1FFFFFFFU /* extended frame format (EFF) */
#define CAN_ERR_MASK 0x1FFFFFFFU /* error frame format */

/* CAN payload length and DLC definitions according to ISO 11898-1 */
#define CAN_MAX_DLC 8
#define CAN_MAX_DLEN 8

/* CAN frame */
struct can_frame {
	canid_t	can_id; /* ID + EFF/RTR/ERR flags */
	uint8_t	can_dlc; /* frame payload length in byte (0 .. CAN_MAX_DLEN) */
	uint8_t	__pad;
	uint8_t	__res0;
	uint8_t __res1;
	uint8_t	data[CAN_MAX_DLEN] __aligned(8);
};

#define CAN_MTU         (sizeof(struct can_frame))

/* protocols */
#define CAN_RAW         1 /* RAW sockets */
#define CAN_NPROTO	2

/*
 * Socket address, CAN style
 */
struct sockaddr_can {
	u_int8_t	can_len;
	sa_family_t	can_family;
	int 		can_ifindex;
	union {
		/* transport protocol class address information (e.g. ISOTP) */
		struct { canid_t rx_id, tx_id; } tp;
		/* reserved for future CAN protocols address information */
	} can_addr;
};

/*
 * Options for use with [gs]etsockopt for raw sockets
 * First word of comment is data type; bool is stored in int.
 */
#define SOL_CAN_RAW CAN_RAW

#define CAN_RAW_FILTER	1	/* struct can_filter: set filter */
#define CAN_RAW_LOOPBACK 4	/* bool: loopback to local sockets (default:on) */
#define CAN_RAW_RECV_OWN_MSGS 5	/* bool: receive my own msgs (default:off) */

/*
 * CAN ID based filter
 * checks received can_id & can_filter.can_mask against
 *   can_filter.can_id & can_filter.can_mask
 * valid flags for can_id:
 *     CAN_INV_FILTER: invert filter
 * valid flags for can_mask:
 *     CAN_ERR_FLAG: filter for error message frames
 */
struct can_filter {
	canid_t can_id;
	canid_t can_mask;
};

#define CAN_INV_FILTER 0x20000000U

#ifdef _NETBSD_SOURCE
#ifdef _KERNEL

#define	satoscan(sa)	((struct sockaddr_can *)(sa))
#define	scantosa(scan)	((struct sockaddr *)(scan))

#endif /* _KERNEL */
#endif /* _NETBSD_SOURCE */
#endif /* _NETCAN_CAN_H */