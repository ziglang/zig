/*	$NetBSD: bcsp.h,v 1.2 2007/10/02 05:40:10 junyoung Exp $	*/
/*
 * Copyright (c) 2007 KIYOHARA Takashi
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _DEV_BLUETOOTH_BCSP_H_
#define _DEV_BLUETOOTH_BCSP_H_

/*
 * BlueCore Serial Protocol definitions
 */

/*
 * Reference to bcore-sp-012p.
 */
/* BCSP packet header */
typedef struct {
	uint8_t flags;
#if BYTE_ORDER == BIG_ENDIAN
	uint8_t plen1 :4;		/* Payload Length (bits 0-3) */
	uint8_t ident :4;		/* Protocol Identifier */
#else
	uint8_t ident :4;		/* Protocol Identifier */
	uint8_t plen1 :4;		/* Payload Length (bits 0-3) */
#endif
	uint8_t plen2;			/* Payload Length (bits 4-11) */
	uint8_t csum;			/* Checksum */
	u_char payload[0];
} __packed bcsp_hdr_t;

#define BCSP_FLAGS_SEQ_SHIFT	0
#define BCSP_FLAGS_SEQ_MASK	0x07
#define BCSP_FLAGS_SEQ(n) \
	(((n) & BCSP_FLAGS_SEQ_MASK) >> BCSP_FLAGS_SEQ_SHIFT)
#define BCSP_FLAGS_ACK_SHIFT	3
#define BCSP_FLAGS_ACK_MASK	0x38
#define BCSP_FLAGS_ACK(n) \
	(((n) & BCSP_FLAGS_ACK_MASK) >> BCSP_FLAGS_ACK_SHIFT)
#define BCSP_FLAGS_CRC_PRESENT	0x40
#define BCSP_FLAGS_PROTOCOL_TYPE 0x80
#define BCSP_FLAGS_PROTOCOL_REL	0x80

#define BCSP_SET_PLEN(hdrp, n)				\
	do {						\
		(hdrp)->plen1 = ((n) & 0x00f);		\
		(hdrp)->plen2 = ((n) >> 4);		\
	} while (0)
#define BCSP_GET_PLEN(hdrp)	((hdrp)->plen1 | ((hdrp)->plen2 << 4))

#define BCSP_GET_CSUM(hdrp)						\
	(0xff - (uint8_t)((hdrp)->flags + ((hdrp)->plen1 << 4) +	\
	(hdrp)->ident + (hdrp)->plen2))
#define BCSP_SET_CSUM(hdrp)	((hdrp)->csum = BCSP_GET_CSUM(hdrp))


#define BCSP_IDENT_ACKPKT	0	/* Used by MUX Layer */
/* Other Protocol Identifier values described to bcore-sp-007P */


/* definitions of SLIP Layer */
#define BCSP_SLIP_PKTSTART	0xc0
#define BCSP_SLIP_PKTEND	BCSP_SLIP_PKTSTART
#define BCSP_SLIP_ESCAPE	0xdb
#define BCSP_SLIP_ESCAPE_PKTEND	0xdc
#define BCSP_SLIP_ESCAPE_ESCAPE	0xdd


/* definitions of Sequencing Layer */
#define BCSP_SEQ_TX_TIMEOUT	(hz / 4)	/* 250 msec */
#define BCSP_SEQ_TX_WINSIZE	4
#define BCSP_SEQ_TX_RETRY_LIMIT	20


/*
 * Reference to bcore-sp-007p.
 *   Channel Allocation
 */
#define BCSP_CHANNEL_LE		1	/* defined in [BCSPLE] */
#define BCSP_CHANNEL_BCCMD	2	/* defined in [BCCMD] */
#define BCSP_CHANNEL_HQ		3	/* defined in [HQ] */
#define BCSP_CHANNEL_DEVMGT	4	/* defined by BlueStack */
#define BCSP_CHANNEL_HCI_CMDEVT	5	/* HCI Command and Event */
#define BCSP_CHANNEL_HCI_ACL	6	/* HCI ACL data */
#define BCSP_CHANNEL_HCI_SCO	7	/* HCI SCO data */
#define BCSP_CHANNEL_L2CAP	8	/* defined by BlueStack */
#define BCSP_CHANNEL_RFCOMM	9	/* defined by BlueStack */
#define BCSP_CHANNEL_SDP	10	/* defined by BlueStack */

#define BCSP_CHANNEL_DFU	12	/* defined in [DFUPROT] */
#define BCSP_CHANNEL_VM		13	/* Virtual Machine */


/*
 * Reference to bcore-sp-008p ??
 *   Link Establishment Protocol
 */
typedef enum {
	le_state_shy,
	le_state_curious,
	le_state_garrulous
} bcsp_le_state_t;

#define BCSP_LE_SYNC		{ 0xda, 0xdc, 0xed, 0xed }
#define BCSP_LE_SYNCRESP	{ 0xac, 0xaf, 0xef, 0xee }
#define BCSP_LE_CONF		{ 0xad, 0xef, 0xac, 0xed }
#define BCSP_LE_CONFRESP	{ 0xde, 0xad, 0xd0, 0xd0 }

#define BCSP_LE_TSHY_TIMEOUT	hz	/* XXXX: 1sec ? */
#define BCSP_LE_TCONF_TIMEOUT	hz	/* XXXX: 1sec ? */

#endif	/* !_DEV_BLUETOOTH_BCSP_H_ */