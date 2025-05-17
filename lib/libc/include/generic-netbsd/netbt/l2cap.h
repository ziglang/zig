/*	$NetBSD: l2cap.h,v 1.19 2015/11/28 07:50:37 plunky Exp $	*/

/*-
 * Copyright (c) 2005 Iain Hibbert.
 * Copyright (c) 2006 Itronix Inc.
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
 * Copyright (c) Maksim Yevmenkin <m_evmenkin@yahoo.com>
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
 * $Id: l2cap.h,v 1.19 2015/11/28 07:50:37 plunky Exp $
 * $FreeBSD: src/sys/netgraph/bluetooth/include/l2cap.h,v 1.4 2005/08/31 18:13:23 emax Exp $
 */

/*
 * This file contains everything that application needs to know about
 * Link Layer Control and Adaptation Protocol (L2CAP). All information
 * was obtained from Bluetooth Specification Books (v1.1 and up)
 *
 * This file can be included by both kernel and userland applications.
 */

#ifndef _NETBT_L2CAP_H_
#define _NETBT_L2CAP_H_

#include <sys/types.h>

/**************************************************************************
 **************************************************************************
 **                   Common defines and types (L2CAP)
 **************************************************************************
 **************************************************************************/

/*
 * Channel IDs are assigned per machine. So the total number of channels that
 * a machine can have open at the same time is 0xffff - 0x0040 = 0xffbf (65471).
 * This number does not depend on number of HCI connections.
 */

#define L2CAP_NULL_CID			0x0000	/* DO NOT USE THIS CID */
#define L2CAP_SIGNAL_CID		0x0001	/* signaling channel ID */
#define L2CAP_CLT_CID			0x0002	/* connectionless channel ID */
	/* 0x0003 - 0x003f Reserved */
#define L2CAP_FIRST_CID			0x0040	/* dynamically alloc. (start) */
#define L2CAP_LAST_CID			0xffff	/* dynamically alloc. (end) */

/* L2CAP MTU */
#define L2CAP_MTU_MINIMUM		48
#define L2CAP_MTU_DEFAULT		672
#define L2CAP_MTU_MAXIMUM		0xffff

/* L2CAP flush and link timeouts */
#define L2CAP_FLUSH_TIMO_DEFAULT	0xffff /* always retransmit */
#define L2CAP_LINK_TIMO_DEFAULT		0xffff

/* L2CAP Command Reject reasons */
#define L2CAP_REJ_NOT_UNDERSTOOD	0x0000
#define L2CAP_REJ_MTU_EXCEEDED		0x0001
#define L2CAP_REJ_INVALID_CID		0x0002
/* 0x0003 - 0xffff - reserved for future use */

/* Protocol/Service Multiplexer (PSM) values */
#define L2CAP_PSM_ANY			0x0000	/* Any/Invalid PSM */
#define L2CAP_PSM_SDP			0x0001	/* Service Discovery Protocol */
#define L2CAP_PSM_RFCOMM		0x0003	/* RFCOMM protocol */
#define L2CAP_PSM_TCP			0x0005	/* Telephony Control Protocol */
#define L2CAP_PSM_TCS			0x0007	/* TCS cordless */
#define L2CAP_PSM_BNEP			0x000f	/* Bluetooth Network */
						/*	Encapsulation Protocol*/
#define L2CAP_PSM_HID_CNTL		0x0011	/* HID Control */
#define L2CAP_PSM_HID_INTR		0x0013	/* HID Interrupt */
#define L2CAP_PSM_ESDP			0x0015	/* Extended Service */
						/*	Discovery Profile */
#define L2CAP_PSM_AVCTP			0x0017	/* Audio/Visual Control */
						/*	Transport Protocol */
#define L2CAP_PSM_AVDTP			0x0019	/* Audio/Visual Distribution */
						/*	Transport Protocol */
#define L2CAP_PSM_UDI_C_PLANE		0x001d	/* Unrestricted Digital */
						/*      Information Profile */
#define L2CAP_PSM_ATT			0x001f	/* Attribute Protocol */
#define L2CAP_PSM_3DSP			0x0021	/* 3D Synchronization Profile */
#define L2CAP_PSM_IPSP			0x0023	/* Internet Protocol */
						/*      Support Profile */
/* 0x0025 - 0x1000 - reserved for future use */

#define L2CAP_PSM_INVALID(psm)		(((psm) & 0x0101) != 0x0001)

/* L2CAP Connection response command result codes */
#define L2CAP_SUCCESS			0x0000
#define L2CAP_PENDING			0x0001
#define L2CAP_PSM_NOT_SUPPORTED		0x0002
#define L2CAP_SECURITY_BLOCK		0x0003
#define L2CAP_NO_RESOURCES		0x0004
#define L2CAP_TIMEOUT			0xeeee
#define L2CAP_UNKNOWN			0xffff
/* 0x0005 - 0xffff - reserved for future use */

/* L2CAP Connection response status codes */
#define L2CAP_NO_INFO			0x0000
#define L2CAP_AUTH_PENDING		0x0001
#define L2CAP_AUTZ_PENDING		0x0002
/* 0x0003 - 0xffff - reserved for future use */

/* L2CAP Configuration response result codes */
#define L2CAP_UNACCEPTABLE_PARAMS	0x0001
#define L2CAP_REJECT			0x0002
#define L2CAP_UNKNOWN_OPTION		0x0003
/* 0x0003 - 0xffff - reserved for future use */

/* L2CAP Configuration options */
#define L2CAP_OPT_CFLAG_BIT		0x0001
#define L2CAP_OPT_CFLAG(flags)		((flags) & L2CAP_OPT_CFLAG_BIT)
#define L2CAP_OPT_HINT_BIT		0x80
#define L2CAP_OPT_HINT(type)		((type) & L2CAP_OPT_HINT_BIT)
#define L2CAP_OPT_HINT_MASK		0x7f
#define L2CAP_OPT_MTU			0x01
#define L2CAP_OPT_MTU_SIZE		sizeof(uint16_t)
#define L2CAP_OPT_FLUSH_TIMO		0x02
#define L2CAP_OPT_FLUSH_TIMO_SIZE	sizeof(uint16_t)
#define L2CAP_OPT_QOS			0x03
#define L2CAP_OPT_QOS_SIZE		sizeof(l2cap_qos_t)
#define L2CAP_OPT_RFC			0x04
#define L2CAP_OPT_RFC_SIZE		sizeof(l2cap_rfc_t)
/* 0x05 - 0xff - reserved for future use */

/* L2CAP Information request type codes */
#define L2CAP_CONNLESS_MTU		0x0001
#define L2CAP_EXTENDED_FEATURES		0x0002
#define L2CAP_FIXED_CHANNELS		0x0003
/* 0x0004 - 0xffff - reserved for future use */

/* L2CAP Information response codes */
#define L2CAP_NOT_SUPPORTED		0x0001
/* 0x0002 - 0xffff - reserved for future use */

/* L2CAP Quality of Service option */
typedef struct {
	uint8_t  flags;			/* reserved for future use */
	uint8_t  service_type;		/* service type */
	uint32_t token_rate;		/* bytes per second */
	uint32_t token_bucket_size;	/* bytes */
	uint32_t peak_bandwidth;	/* bytes per second */
	uint32_t latency;		/* microseconds */
	uint32_t delay_variation;	/* microseconds */
} __packed l2cap_qos_t;

/* L2CAP QoS type */
#define L2CAP_QOS_NO_TRAFFIC	0x00
#define L2CAP_QOS_BEST_EFFORT	0x01       /* (default) */
#define L2CAP_QOS_GUARANTEED	0x02
/* 0x03 - 0xff - reserved for future use */

/* L2CAP Retransmission & Flow Control option */
typedef struct {
	uint8_t	mode;		   /* RFC mode */
	uint8_t	window_size;	   /* bytes */
	uint8_t	max_transmit;	   /* max retransmissions */
	uint16_t	retransmit_timo;   /* milliseconds */
	uint16_t	monitor_timo;	   /* milliseconds */
	uint16_t	max_pdu_size;	   /* bytes */
} __packed l2cap_rfc_t;

/* L2CAP RFC mode */
#define L2CAP_RFC_BASIC		0x00	   /* (default) */
#define L2CAP_RFC_RETRANSMIT	0x01
#define L2CAP_RFC_FLOW		0x02
/* 0x03 - 0xff - reserved for future use */

/**************************************************************************
 **************************************************************************
 **                 Link level defines, headers and types
 **************************************************************************
 **************************************************************************/

/* L2CAP header */
typedef struct {
	uint16_t	length;	/* payload size */
	uint16_t	dcid;	/* destination channel ID */
} __packed l2cap_hdr_t;

/* L2CAP ConnectionLess Traffic		(dcid == L2CAP_CLT_CID) */
typedef struct {
	uint16_t	psm; /* Protocol/Service Multiplexer */
} __packed l2cap_clt_hdr_t;

#define L2CAP_CLT_MTU_MAXIMUM \
	(L2CAP_MTU_MAXIMUM - sizeof(l2cap_clt_hdr_t))

/* L2CAP Command header			(dcid == L2CAP_SIGNAL_CID) */
typedef struct {
	uint8_t	code;   /* command OpCode */
	uint8_t	ident;  /* identifier to match request and response */
	uint16_t	length; /* command parameters length */
} __packed l2cap_cmd_hdr_t;

/* L2CAP Command Reject */
#define L2CAP_COMMAND_REJ			0x01
typedef struct {
	uint16_t	reason; /* reason to reject command */
	uint16_t	data[2];/* optional data */
} __packed l2cap_cmd_rej_cp;

/* L2CAP Connection Request */
#define L2CAP_CONNECT_REQ			0x02
typedef struct {
	uint16_t	psm;  /* Protocol/Service Multiplexer */
	uint16_t	scid; /* source channel ID */
} __packed l2cap_con_req_cp;

/* L2CAP Connection Response */
#define L2CAP_CONNECT_RSP			0x03
typedef struct {
	uint16_t	dcid;   /* destination channel ID */
	uint16_t	scid;   /* source channel ID */
	uint16_t	result; /* 0x00 - success */
	uint16_t	status; /* more info if result != 0x00 */
} __packed l2cap_con_rsp_cp;

/* L2CAP Configuration Request */
#define L2CAP_CONFIG_REQ			0x04
typedef struct {
	uint16_t	dcid;  /* destination channel ID */
	uint16_t	flags; /* flags */
/*	uint8_t	options[] --  options */
} __packed l2cap_cfg_req_cp;

/* L2CAP Configuration Response */
#define L2CAP_CONFIG_RSP			0x05
typedef struct {
	uint16_t	scid;   /* source channel ID */
	uint16_t	flags;  /* flags */
	uint16_t	result; /* 0x00 - success */
/*	uint8_t	options[] -- options */
} __packed l2cap_cfg_rsp_cp;

/* L2CAP configuration option */
typedef struct {
	uint8_t	type;
	uint8_t	length;
/*	uint8_t	value[] -- option value (depends on type) */
} __packed l2cap_cfg_opt_t;

/* L2CAP configuration option value */
typedef union {
	uint16_t		mtu;		/* L2CAP_OPT_MTU */
	uint16_t		flush_timo;	/* L2CAP_OPT_FLUSH_TIMO */
	l2cap_qos_t		qos;		/* L2CAP_OPT_QOS */
	l2cap_rfc_t		rfc;		/* L2CAP_OPT_RFC */
} l2cap_cfg_opt_val_t;

/* L2CAP Disconnect Request */
#define L2CAP_DISCONNECT_REQ			0x06
typedef struct {
	uint16_t	dcid; /* destination channel ID */
	uint16_t	scid; /* source channel ID */
} __packed l2cap_discon_req_cp;

/* L2CAP Disconnect Response */
#define L2CAP_DISCONNECT_RSP			0x07
typedef l2cap_discon_req_cp	l2cap_discon_rsp_cp;

/* L2CAP Echo Request */
#define L2CAP_ECHO_REQ				0x08
/* No command parameters, only optional data */

/* L2CAP Echo Response */
#define L2CAP_ECHO_RSP				0x09
#define L2CAP_MAX_ECHO_SIZE \
	(L2CAP_MTU_MAXIMUM - sizeof(l2cap_cmd_hdr_t))
/* No command parameters, only optional data */

/* L2CAP Information Request */
#define L2CAP_INFO_REQ				0x0a
typedef struct {
	uint16_t	type; /* requested information type */
} __packed l2cap_info_req_cp;

/* L2CAP Information Response */
#define L2CAP_INFO_RSP				0x0b
typedef struct {
	uint16_t	type;   /* requested information type */
	uint16_t	result; /* 0x00 - success */
/*	uint8_t	info[]  -- info data (depends on type)
 */
} __packed l2cap_info_rsp_cp;


/**************************************************************************
 **************************************************************************
 **		L2CAP Socket Definitions
 **************************************************************************
 **************************************************************************/

/* Socket options */
#define SO_L2CAP_IMTU		1	/* incoming MTU */
#define SO_L2CAP_OMTU		2	/* outgoing MTU */
#define SO_L2CAP_IQOS		3	/* incoming QoS */
#define SO_L2CAP_OQOS		4	/* outgoing QoS */
#define SO_L2CAP_FLUSH		5	/* flush timeout */
#define SO_L2CAP_LM		6	/* link mode */

/* L2CAP link mode flags */
#define L2CAP_LM_AUTH		(1<<0)	/* want authentication */
#define L2CAP_LM_ENCRYPT	(1<<1)	/* want encryption */
#define L2CAP_LM_SECURE		(1<<2)	/* want secured link */

#ifdef _KERNEL

LIST_HEAD(l2cap_channel_list, l2cap_channel);

/* global variables */
extern struct l2cap_channel_list l2cap_active_list;
extern struct l2cap_channel_list l2cap_listen_list;
extern struct pool l2cap_pdu_pool;
extern struct pool l2cap_req_pool;
extern const l2cap_qos_t l2cap_default_qos;

/* sysctl variables */
extern int l2cap_response_timeout;
extern int l2cap_response_extended_timeout;
extern int l2cap_sendspace, l2cap_recvspace;

/*
 * L2CAP Channel
 */
struct l2cap_channel {
	struct hci_link		*lc_link;	/* ACL connection (down) */
	uint16_t		 lc_state;	/* channel state */
	uint16_t		 lc_flags;	/* channel flags */
	uint8_t			 lc_ident;	/* cached request id */

	uint16_t		 lc_lcid;	/* local channel ID */
	struct sockaddr_bt	 lc_laddr;	/* local address */

	uint16_t		 lc_rcid;	/* remote channel ID */
	struct sockaddr_bt	 lc_raddr;	/* remote address */

	int			 lc_mode;	/* link mode */
	uint16_t		 lc_imtu;	/* incoming mtu */
	uint16_t		 lc_omtu;	/* outgoing mtu */
	uint16_t		 lc_flush;	/* flush timeout */
	l2cap_qos_t		 lc_iqos;	/* incoming QoS flow control */
	l2cap_qos_t		 lc_oqos;	/* outgoing Qos flow control */

	uint8_t			 lc_pending;	/* num of pending PDUs */
	MBUFQ_HEAD()		 lc_txq;	/* transmit queue */

	const struct btproto	*lc_proto;	/* upper layer callbacks */
	void			*lc_upper;	/* upper layer argument */

	LIST_ENTRY(l2cap_channel)lc_ncid;	/* next channel (ascending CID) */
};

/* l2cap_channel state */
#define L2CAP_CLOSED			0 /* closed */
#define L2CAP_WAIT_SEND_CONNECT_REQ	1 /* waiting to send connect request */
#define L2CAP_WAIT_RECV_CONNECT_RSP	2 /* waiting to recv connect response */
#define L2CAP_WAIT_SEND_CONNECT_RSP	3 /* waiting to send connect response */
#define L2CAP_WAIT_CONFIG		4 /* waiting for configuration */
#define L2CAP_OPEN			5 /* user data transfer state */
#define L2CAP_WAIT_DISCONNECT		6 /* have sent disconnect request */

/* l2cap_channel flags */
#define L2CAP_SHUTDOWN		(1<<0)	/* channel is closing */
#define L2CAP_WAIT_CONFIG_REQ	(1<<1)	/* waiting for config request */
#define L2CAP_WAIT_CONFIG_RSP	(1<<2)	/* waiting for config response */

/*
 * L2CAP Request
 */
struct l2cap_req {
	struct hci_link		*lr_link;	/* ACL connection */
	struct l2cap_channel	*lr_chan;	/* channel pointer */
	uint8_t			 lr_code;	/* request code */
	uint8_t			 lr_id;		/* request id */
	callout_t		 lr_rtx;	/* response timer */
	TAILQ_ENTRY(l2cap_req)	 lr_next;	/* next request on link */
};

/*
 * L2CAP Protocol Data Unit
 */
struct l2cap_pdu {
	struct l2cap_channel	*lp_chan;	/* PDU owner */
	MBUFQ_HEAD()		 lp_data;	/* PDU data */
	TAILQ_ENTRY(l2cap_pdu)	 lp_next;	/* next PDU on link */
	int			 lp_pending;	/* # of fragments pending */
};

/*
 * L2CAP function prototypes
 */

struct socket;
struct sockopt;
struct mbuf;

/* l2cap_lower.c */
void l2cap_close(struct l2cap_channel *, int);
void l2cap_recv_frame(struct mbuf *, struct hci_link *);
int l2cap_start(struct l2cap_channel *);

/* l2cap_misc.c */
int l2cap_setmode(struct l2cap_channel *);
int l2cap_cid_alloc(struct l2cap_channel *);
struct l2cap_channel *l2cap_cid_lookup(uint16_t);
int l2cap_request_alloc(struct l2cap_channel *, uint8_t);
struct l2cap_req *l2cap_request_lookup(struct hci_link *, uint8_t);
void l2cap_request_free(struct l2cap_req *);
void l2cap_rtx(void *);
void l2cap_init(void);

/* l2cap_signal.c */
void l2cap_recv_signal(struct mbuf *, struct hci_link *);
int l2cap_send_connect_req(struct l2cap_channel *);
int l2cap_send_config_req(struct l2cap_channel *);
int l2cap_send_disconnect_req(struct l2cap_channel *);
int l2cap_send_connect_rsp(struct hci_link *, uint8_t, uint16_t, uint16_t, uint16_t);

/* l2cap_socket.c */
int l2cap_ctloutput(int, struct socket *, struct sockopt *);

/* l2cap_upper.c */
int l2cap_attach_pcb(struct l2cap_channel **, const struct btproto *, void *);
int l2cap_bind_pcb(struct l2cap_channel *, struct sockaddr_bt *);
int l2cap_sockaddr_pcb(struct l2cap_channel *, struct sockaddr_bt *);
int l2cap_connect_pcb(struct l2cap_channel *, struct sockaddr_bt *);
int l2cap_peeraddr_pcb(struct l2cap_channel *, struct sockaddr_bt *);
int l2cap_disconnect_pcb(struct l2cap_channel *, int);
void l2cap_detach_pcb(struct l2cap_channel **);
int l2cap_listen_pcb(struct l2cap_channel *);
int l2cap_send_pcb(struct l2cap_channel *, struct mbuf *);
int l2cap_setopt(struct l2cap_channel *, const struct sockopt *);
int l2cap_getopt(struct l2cap_channel *, struct sockopt *);

#endif	/* _KERNEL */

#endif	/* _NETBT_L2CAP_H_ */