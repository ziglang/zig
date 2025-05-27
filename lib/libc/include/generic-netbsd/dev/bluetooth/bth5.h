/*	$NetBSD: bth5.h,v 1.2 2017/09/03 23:11:19 nat Exp $	*/
/*
 * Copyright (c) 2017 Nathanial Sloss <nathanialsloss@yahoo.com.au>
 * All rights reserved.
 *
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

#ifndef _DEV_BLUETOOTH_BTH5_H_
#define _DEV_BLUETOOTH_BTH5_H_

/*
 * BT UART H5 (3-wire) serial protocol definitions.
 */

/* BTH5 packet header */
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
} __packed bth5_hdr_t;

#define BTH5_FLAGS_SEQ_SHIFT	0
#define BTH5_FLAGS_SEQ_MASK	0x07
#define BTH5_FLAGS_SEQ(n) \
	(((n) & BTH5_FLAGS_SEQ_MASK) >> BTH5_FLAGS_SEQ_SHIFT)
#define BTH5_FLAGS_ACK_SHIFT	3
#define BTH5_FLAGS_ACK_MASK	0x38
#define BTH5_FLAGS_ACK(n) \
	(((n) & BTH5_FLAGS_ACK_MASK) >> BTH5_FLAGS_ACK_SHIFT)
#define BTH5_FLAGS_CRC_PRESENT	0x40
#define BTH5_FLAGS_PROTOCOL_TYPE 0x80
#define BTH5_FLAGS_PROTOCOL_REL	0x80

#define BTH5_CONFIG_ACK_MASK	0x07
#define BTH5_CONFIG_FLOW_MASK	(1 << 7)

#define BTH5_SET_PLEN(hdrp, n)				\
	do {						\
		(hdrp)->plen1 = ((n) & 0x00f);		\
		(hdrp)->plen2 = ((n) >> 4);		\
	} while (0)
#define BTH5_GET_PLEN(hdrp)	((hdrp)->plen1 | ((hdrp)->plen2 << 4))

#define BTH5_GET_CSUM(hdrp)						\
	(0xff - (uint8_t)((hdrp)->flags + ((hdrp)->plen1 << 4) +	\
	(hdrp)->ident + (hdrp)->plen2))
#define BTH5_SET_CSUM(hdrp)	((hdrp)->csum = BTH5_GET_CSUM(hdrp))


#define BTH5_IDENT_ACKPKT	0	/* Used by MUX Layer */

/* definitions of SLIP Layer */
#define BTH5_SLIP_PKTSTART	0xc0
#define BTH5_SLIP_PKTEND	BTH5_SLIP_PKTSTART
#define BTH5_SLIP_XON		0x11
#define BTH5_SLIP_XOFF		0x13
#define BTH5_SLIP_ESCAPE	0xdb
#define BTH5_SLIP_ESCAPE_PKTEND	0xdc
#define BTH5_SLIP_ESCAPE_ESCAPE	0xdd
#define BTH5_SLIP_ESCAPE_XON	0xde
#define BTH5_SLIP_ESCAPE_XOFF	0xdf


/* definitions of Sequencing Layer */
#define BTH5_SEQ_TX_TIMEOUT	(hz / 4)	/* 250 msec */
#define BTH5_SEQ_TX_WINSIZE	7
#define BTH5_SEQ_TX_RETRY_LIMIT	20


/*
 *   Channel Allocation
 */
#define BTH5_CHANNEL_HCI_CMD	1	/* HCI Command and Event */
#define BTH5_CHANNEL_HCI_EVT	4	/* HCI Command and Event */
#define BTH5_CHANNEL_HCI_ACL	2	/* HCI ACL data */
#define BTH5_CHANNEL_HCI_SCO	3	/* HCI SCO data */
#define BTH5_CHANNEL_LE		15	/* Link Establishment */


/*
 *   Link Establishment Protocol
 */
typedef enum {
	le_state_shy,
	le_state_curious,
	le_state_garrulous
} bth5_le_state_t;

#define BTH5_LE_SYNC		{ 0x01, 0x7e };
#define BTH5_LE_SYNCRESP	{ 0x02, 0x7d };
#define BTH5_LE_CONF		{ 0x03, 0xfc, 0x0f };
#define BTH5_LE_CONFRESP	{ 0x04, 0x7b, 0x0f };

#define BTH5_LE_TSHY_TIMEOUT	hz	/* XXXX: 1sec ? */
#define BTH5_LE_TCONF_TIMEOUT	hz	/* XXXX: 1sec ? */

#endif	/* !_DEV_BLUETOOTH_BTH5_H_ */