/*	$NetBSD: rfcomm.h,v 1.19 2022/05/28 21:14:57 andvar Exp $	*/

/*-
 * Copyright (c) 2006 Itronix Inc.
 * All rights reserved.
 *
 * Written by Iain Hibbert for Itronix Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of Itronix Inc. may not be used to endorse
 *    or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ITRONIX INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL ITRONIX INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
/*-
 * Copyright (c) 2001-2003 Maksim Yevmenkin <m_evmenkin@yahoo.com>
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
 * $Id: rfcomm.h,v 1.19 2022/05/28 21:14:57 andvar Exp $
 * $FreeBSD: src/sys/netgraph/bluetooth/include/ng_btsocket_rfcomm.h,v 1.4 2005/01/11 01:39:53 emax Exp $
 */

#ifndef _NETBT_RFCOMM_H_
#define _NETBT_RFCOMM_H_

#include <sys/types.h>

/*************************************************************************
 *************************************************************************
 **				RFCOMM					**
 *************************************************************************
 *************************************************************************/

#define RFCOMM_MTU_MAX			32767
#define RFCOMM_MTU_MIN			23
#define RFCOMM_MTU_DEFAULT		127

#define RFCOMM_CREDITS_MAX		255	/* in any single packet */
#define RFCOMM_CREDITS_DEFAULT		7	/* default initial value */

#define RFCOMM_CHANNEL_ANY		0
#define RFCOMM_CHANNEL_MIN		1
#define RFCOMM_CHANNEL_MAX		30

/* RFCOMM frame types */
#define RFCOMM_FRAME_SABM		0x2f
#define RFCOMM_FRAME_DISC		0x43
#define RFCOMM_FRAME_UA			0x63
#define RFCOMM_FRAME_DM			0x0f
#define RFCOMM_FRAME_UIH		0xef

/* RFCOMM MCC commands */
#define RFCOMM_MCC_TEST			0x08	/* Test */
#define RFCOMM_MCC_FCON			0x28	/* Flow Control on */
#define RFCOMM_MCC_FCOFF		0x18	/* Flow Control off */
#define RFCOMM_MCC_MSC			0x38	/* Modem Status Command */
#define RFCOMM_MCC_RPN			0x24	/* Remote Port Negotiation */
#define RFCOMM_MCC_RLS			0x14	/* Remote Line Status */
#define RFCOMM_MCC_PN			0x20	/* Port Negotiation */
#define RFCOMM_MCC_NSC			0x04	/* Non Supported Command */

/* RFCOMM modem signals */
#define RFCOMM_MSC_FC			0x02	/* Flow Control asserted */
#define RFCOMM_MSC_RTC			0x04	/* Ready To Communicate */
#define RFCOMM_MSC_RTR			0x08	/* Ready To Receive */
#define RFCOMM_MSC_IC			0x40	/* Incoming Call (RING) */
#define RFCOMM_MSC_DV			0x80	/* Data Valid */

/* RPN parameters - baud rate */
#define RFCOMM_RPN_BR_2400		0x0
#define RFCOMM_RPN_BR_4800		0x1
#define RFCOMM_RPN_BR_7200		0x2
#define RFCOMM_RPN_BR_9600		0x3
#define RFCOMM_RPN_BR_19200		0x4
#define RFCOMM_RPN_BR_38400		0x5
#define RFCOMM_RPN_BR_57600		0x6
#define RFCOMM_RPN_BR_115200		0x7
#define RFCOMM_RPN_BR_230400		0x8

/* RPN parameters - data bits */
#define RFCOMM_RPN_DATA_5		0x0
#define RFCOMM_RPN_DATA_6		0x1
#define RFCOMM_RPN_DATA_7		0x2
#define RFCOMM_RPN_DATA_8		0x3

/* RPN parameters - stop bit */
#define RFCOMM_RPN_STOP_1		0
#define RFCOMM_RPN_STOP_15		1

/* RPN parameters - parity enable */
#define RFCOMM_RPN_PARITY_NONE		0x0

/* RPN parameters - parity type */
#define RFCOMM_RPN_PARITY_ODD		0x0
#define RFCOMM_RPN_PARITY_EVEN		0x1
#define RFCOMM_RPN_PARITY_MARK		0x2
#define RFCOMM_RPN_PARITY_SPACE		0x3

/* RPN parameters - default line_setting */
#define RFCOMM_RPN_8_N_1		0x03

/* RPN parameters - flow control */
#define RFCOMM_RPN_XON_CHAR		0x11
#define RFCOMM_RPN_XOFF_CHAR		0x13
#define RFCOMM_RPN_FLOW_NONE		0x00

/* RPN parameters - mask */
#define RFCOMM_RPN_PM_RATE		0x0001
#define RFCOMM_RPN_PM_DATA		0x0002
#define RFCOMM_RPN_PM_STOP		0x0004
#define RFCOMM_RPN_PM_PARITY		0x0008
#define RFCOMM_RPN_PM_PTYPE		0x0010
#define RFCOMM_RPN_PM_XON		0x0020
#define RFCOMM_RPN_PM_XOFF		0x0040

#define RFCOMM_RPN_PM_FLOW		0x3f00

#define RFCOMM_RPN_PM_ALL		0x3f7f

/* RFCOMM command frame header */
struct rfcomm_cmd_hdr
{
	uint8_t		address;
	uint8_t		control;
	uint8_t		length;
	uint8_t		fcs;
} __packed;

/* RFCOMM MSC command */
struct rfcomm_mcc_msc
{
	uint8_t		address;
	uint8_t		modem;
	uint8_t		brk;
} __packed;

/* RFCOMM RPN command */
struct rfcomm_mcc_rpn
{
	uint8_t		dlci;
	uint8_t		bit_rate;
	uint8_t		line_settings;
	uint8_t		flow_control;
	uint8_t		xon_char;
	uint8_t		xoff_char;
	uint16_t	param_mask;
} __packed;

/* RFCOMM RLS command */
struct rfcomm_mcc_rls
{
	uint8_t		address;
	uint8_t		status;
} __packed;

/* RFCOMM PN command */
struct rfcomm_mcc_pn
{
	uint8_t		dlci;
	uint8_t		flow_control;
	uint8_t		priority;
	uint8_t		ack_timer;
	uint16_t	mtu;
	uint8_t		max_retrans;
	uint8_t		credits;
} __packed;

/* RFCOMM frame parsing macros */
#define RFCOMM_DLCI(b)			(((b) & 0xfc) >> 2)
#define RFCOMM_TYPE(b)			(((b) & 0xef))

#define RFCOMM_EA(b)			(((b) & 0x01))
#define RFCOMM_CR(b)			(((b) & 0x02) >> 1)
#define RFCOMM_PF(b)			(((b) & 0x10) >> 4)

#define RFCOMM_CHANNEL(dlci)		(((dlci) >> 1) & 0x2f)
#define RFCOMM_DIRECTION(dlci)		((dlci) & 0x1)

#define RFCOMM_MKADDRESS(cr, dlci) \
	((((dlci) & 0x3f) << 2) | ((cr) << 1) | 0x01)

#define RFCOMM_MKCONTROL(type, pf)	((((type) & 0xef) | ((pf) << 4)))
#define RFCOMM_MKDLCI(dir, channel)	((((channel) & 0x1f) << 1) | (dir))

/* RFCOMM MCC macros */
#define RFCOMM_MCC_TYPE(b)		(((b) & 0xfc) >> 2)
#define RFCOMM_MCC_LENGTH(b)		(((b) & 0xfe) >> 1)
#define RFCOMM_MKMCC_TYPE(cr, type)	((((type) << 2) | ((cr) << 1) | 0x01))

/* RPN macros */
#define RFCOMM_RPN_DATA_BITS(line)	((line) & 0x3)
#define RFCOMM_RPN_STOP_BITS(line)	(((line) >> 2) & 0x1)
#define RFCOMM_RPN_PARITY(line)		(((line) >> 3) & 0x1)

/*************************************************************************
 *************************************************************************
 **			SOCK_STREAM RFCOMM sockets			**
 *************************************************************************
 *************************************************************************/

/* Socket options */
#define SO_RFCOMM_MTU		1	/* mtu */
#define SO_RFCOMM_FC_INFO	2	/* flow control info (below) */
#define SO_RFCOMM_LM		3	/* link mode */

/* Flow control information */
struct rfcomm_fc_info {
	uint8_t		lmodem;		/* modem signals (local) */
	uint8_t		rmodem;		/* modem signals (remote) */
	uint8_t		tx_cred;	/* TX credits */
	uint8_t		rx_cred;	/* RX credits */
	uint8_t		cfc;		/* credit flow control */
	uint8_t		reserved;
};

/* RFCOMM link mode flags */
#define RFCOMM_LM_AUTH		(1<<0)	/* want authentication */
#define RFCOMM_LM_ENCRYPT	(1<<1)	/* want encryption */
#define RFCOMM_LM_SECURE	(1<<2)	/* want secured link */

#ifdef _KERNEL

/* sysctl variables */
extern int rfcomm_sendspace;
extern int rfcomm_recvspace;
extern int rfcomm_mtu_default;
extern int rfcomm_ack_timeout;
extern int rfcomm_mcc_timeout;

/*
 * Bluetooth RFCOMM session data
 * One L2CAP connection == one RFCOMM session
 */

/* Credit note */
struct rfcomm_credit {
	struct rfcomm_dlc		*rc_dlc;	/* owner */
	uint16_t			 rc_len;	/* length */
	SIMPLEQ_ENTRY(rfcomm_credit)	 rc_next;	/* next credit */
};

/* RFCOMM session data (one L2CAP channel) */
struct rfcomm_session {
	struct l2cap_channel		*rs_l2cap;	/* L2CAP pointer */
	uint16_t			 rs_flags;	/* session flags */
	uint16_t			 rs_state;	/* session state */
	uint16_t			 rs_mtu;	/* default MTU */

	SIMPLEQ_HEAD(,rfcomm_credit)	 rs_credits;	/* credit notes */
	LIST_HEAD(,rfcomm_dlc)		 rs_dlcs;	/* DLC list */

	callout_t			 rs_timeout;	/* timeout */

	LIST_ENTRY(rfcomm_session)	 rs_next;	/* next session */
};

LIST_HEAD(rfcomm_session_list, rfcomm_session);
extern struct rfcomm_session_list rfcomm_session_active;
extern struct rfcomm_session_list rfcomm_session_listen;

/* Session state */
#define RFCOMM_SESSION_CLOSED		0
#define RFCOMM_SESSION_WAIT_CONNECT	1
#define RFCOMM_SESSION_OPEN		2
#define RFCOMM_SESSION_WAIT_DISCONNECT	3
#define RFCOMM_SESSION_LISTEN		4

/* Session flags */
#define RFCOMM_SESSION_INITIATOR	(1 << 0) /* we are initiator */
#define RFCOMM_SESSION_CFC		(1 << 1) /* credit flow control */
#define RFCOMM_SESSION_LFC		(1 << 2) /* local flow control */
#define RFCOMM_SESSION_RFC		(1 << 3) /* remote flow control */
#define RFCOMM_SESSION_FREE		(1 << 4) /* self lock out for free */

#define IS_INITIATOR(rs)	((rs)->rs_flags & RFCOMM_SESSION_INITIATOR)

/* Bluetooth RFCOMM DLC data (connection) */
struct rfcomm_dlc {
	struct rfcomm_session	*rd_session; /* RFCOMM session */
	uint8_t			 rd_dlci;    /* RFCOMM DLCI */

	uint16_t		 rd_flags;   /* DLC flags */
	uint16_t		 rd_state;   /* DLC state */
	uint16_t		 rd_mtu;     /* MTU */
	int			 rd_mode;    /* link mode */

	struct sockaddr_bt	 rd_laddr;   /* local address */
	struct sockaddr_bt	 rd_raddr;   /* remote address */

	uint8_t			 rd_lmodem;  /* local modem signls */
	uint8_t			 rd_rmodem;  /* remote modem signals */

	int			 rd_rxcred;  /* receive credits (sent) */
	size_t			 rd_rxsize;  /* receive buffer (bytes, avail) */
	int			 rd_txcred;  /* transmit credits (unused) */
	int			 rd_pending; /* packets sent but not complete */

	callout_t		 rd_timeout; /* timeout */
	struct mbuf		*rd_txbuf;   /* transmit buffer */

	const struct btproto	*rd_proto;   /* upper layer callbacks */
	void			*rd_upper;   /* upper layer argument */

	LIST_ENTRY(rfcomm_dlc)	 rd_next;    /* next dlc on session */
};

/*
 * Credit Flow Control works in the following way.
 *
 * txcred is how many packets we can send. Received credit
 * is added to this value, and it is decremented each time
 * we send a packet.
 *
 * rxsize is the number of bytes that are available in the
 * upstream receive buffer.
 *
 * rxcred is the number of credits that we have previously
 * sent that are still unused. This value will be decreased
 * for each packet we receive and we will add to it when we
 * send credits. We calculate the amount of credits to send
 * by the cunning formula "(space / mtu) - sent" so that if
 * we get a bunch of small packets, we can continue sending
 * credits without risking buffer overflow.
 */

/* DLC flags */
#define RFCOMM_DLC_DETACH		(1 << 0) /* DLC to be detached */
#define RFCOMM_DLC_SHUTDOWN		(1 << 1) /* DLC to be shutdown */

/* DLC state */
#define RFCOMM_DLC_CLOSED		0	/* no session */
#define RFCOMM_DLC_WAIT_SESSION		1	/* waiting for session */
#define RFCOMM_DLC_WAIT_CONNECT		2	/* waiting for connect */
#define RFCOMM_DLC_WAIT_SEND_SABM	3	/* waiting to send SABM */
#define RFCOMM_DLC_WAIT_SEND_UA		4	/* waiting to send UA */
#define RFCOMM_DLC_WAIT_RECV_UA		5	/* waiting to receive UA */
#define RFCOMM_DLC_OPEN			6	/* can send/receive */
#define RFCOMM_DLC_WAIT_DISCONNECT	7	/* waiting for disconnect */
#define RFCOMM_DLC_LISTEN		8	/* listening DLC */

/*
 * Bluetooth RFCOMM socket kernel prototypes
 */

struct socket;
struct sockopt;

/* rfcomm_dlc.c */
struct rfcomm_dlc *rfcomm_dlc_lookup(struct rfcomm_session *, int);
struct rfcomm_dlc *rfcomm_dlc_newconn(struct rfcomm_session *, int);
void rfcomm_dlc_close(struct rfcomm_dlc *, int);
void rfcomm_dlc_timeout(void *);
int rfcomm_dlc_setmode(struct rfcomm_dlc *);
int rfcomm_dlc_connect(struct rfcomm_dlc *);
int rfcomm_dlc_open(struct rfcomm_dlc *);
void rfcomm_dlc_start(struct rfcomm_dlc *);

/* rfcomm_session.c */
struct rfcomm_session *rfcomm_session_alloc(struct rfcomm_session_list *, struct sockaddr_bt *);
struct rfcomm_session *rfcomm_session_lookup(struct sockaddr_bt *, struct sockaddr_bt *);
void rfcomm_session_free(struct rfcomm_session *);
int rfcomm_session_send_frame(struct rfcomm_session *, int, int);
int rfcomm_session_send_uih(struct rfcomm_session *, struct rfcomm_dlc *, int, struct mbuf *);
int rfcomm_session_send_mcc(struct rfcomm_session *, int, uint8_t, void *, int);
void rfcomm_init(void);

/* rfcomm_socket.c */
int rfcomm_ctloutput(int, struct socket *, struct sockopt *);

/* rfcomm_upper.c */
int rfcomm_attach_pcb(struct rfcomm_dlc **, const struct btproto *, void *);
int rfcomm_bind_pcb(struct rfcomm_dlc *, struct sockaddr_bt *);
int rfcomm_sockaddr_pcb(struct rfcomm_dlc *, struct sockaddr_bt *);
int rfcomm_connect_pcb(struct rfcomm_dlc *, struct sockaddr_bt *);
int rfcomm_peeraddr_pcb(struct rfcomm_dlc *, struct sockaddr_bt *);
int rfcomm_disconnect_pcb(struct rfcomm_dlc *, int);
void rfcomm_detach_pcb(struct rfcomm_dlc **);
int rfcomm_listen_pcb(struct rfcomm_dlc *);
int rfcomm_send_pcb(struct rfcomm_dlc *, struct mbuf *);
int rfcomm_rcvd_pcb(struct rfcomm_dlc *, size_t);
int rfcomm_setopt(struct rfcomm_dlc *, const struct sockopt *);
int rfcomm_getopt(struct rfcomm_dlc *, struct sockopt *);

#endif /* _KERNEL */

#endif /* _NETBT_RFCOMM_H_ */