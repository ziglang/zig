/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Isilon Systems, LLC.
 * Copyright (c) 2005-2014 Sandvine Incorporated
 * Copyright (c) 2000 Darrell Anderson <anderson@cs.duke.edu>
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
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Debugnet provides a reliable, bidirectional, UDP-encapsulated datagram
 * transport while a machine is in a debug state.  (N-1 CPUs stopped,
 * interrupts disabled, may or may not be in a panic(9) state.)  Only one
 * stream may be active at a time.  A dedicated server must be running to
 * accept connections.
 */

#pragma once

#include <sys/types.h>
#include <netinet/in.h>

/*
 * Debugnet protocol details.
 */
#define	DEBUGNET_HERALD		1	/* Connection handshake. */
#define	DEBUGNET_FINISHED	2	/* Close the connection. */
#define	DEBUGNET_DATA		3	/* Contains data. */

struct debugnet_msg_hdr {
	uint32_t	mh_type;	/* Debugnet message type. */
	uint32_t	mh_seqno;	/* Match acks with msgs. */
	uint64_t	mh_offset;	/* Offset in fragment. */
	uint32_t	mh_len;		/* Attached data (bytes). */
	uint32_t	mh_aux2;	/* Consumer-specific. */
} __packed;

struct debugnet_ack {
	uint32_t	da_seqno;	/* Match acks with msgs. */
} __packed;

#define	DEBUGNET_MAX_IN_FLIGHT	64

#ifdef _KERNEL
/*
 * Hook API for network drivers.
 */
enum debugnet_ev {
	DEBUGNET_START,
	DEBUGNET_END,
};

struct ifnet;
struct mbuf;
typedef void debugnet_init_t(struct ifnet *, int *nrxr, int *ncl, int *clsize);
typedef void debugnet_event_t(struct ifnet *, enum debugnet_ev);
typedef int debugnet_transmit_t(struct ifnet *, struct mbuf *);
typedef int debugnet_poll_t(struct ifnet *, int);

struct debugnet_methods {
	debugnet_init_t		*dn_init;
	debugnet_event_t	*dn_event;
	debugnet_transmit_t	*dn_transmit;
	debugnet_poll_t		*dn_poll;
};

#define	DEBUGNET_SUPPORTED_NIC(ifp)				\
	((ifp)->if_debugnet_methods != NULL && (ifp)->if_type == IFT_ETHER)

struct debugnet_pcb; /* opaque */

/*
 * Debugnet consumer API.
 */
struct debugnet_conn_params {
	struct ifnet	*dc_ifp;
	in_addr_t	dc_client;
	in_addr_t	dc_server;
	in_addr_t	dc_gateway;

	uint16_t	dc_herald_port;
	uint16_t	dc_client_port;

	const void	*dc_herald_data;
	uint32_t	dc_herald_datalen;

	/*
	 * Consistent with debugnet_send(), aux parameters to debugnet
	 * functions are provided host-endian (but converted to
	 * network endian on the wire).
	 */
	uint32_t	dc_herald_aux2;
	uint64_t	dc_herald_offset;

	/*
	 * If NULL, debugnet is a unidirectional channel from panic machine to
	 * remote server (like netdump).
	 *
	 * If handler is non-NULL, packets received on the client port that are
	 * not just tx acks are forwarded to the provided handler.
	 *
	 * The mbuf chain will have all non-debugnet framing headers removed
	 * (ethernet, inet, udp).  It will start with a debugnet_msg_hdr, of
	 * which the header is guaranteed to be contiguous.  If m_pullup is
	 * used, the supplied in-out mbuf pointer should be updated
	 * appropriately.
	 *
	 * If the handler frees the mbuf chain, it should set the mbuf pointer
	 * to NULL.  Otherwise, the debugnet input framework will free the
	 * chain.
	 *
	 * The handler should ACK receieved packets with debugnet_ack_output.
	 */
	int			(*dc_rx_handler)(struct mbuf *);

	/* Cleanup signal for bidirectional protocols. */
	void		(*dc_finish_handler)(void);
};

/*
 * Open a stream to the specified server's herald port.
 *
 * If all goes well, the server will send ACK from a different port to our ack
 * port.  This allows servers to somewhat gracefully handle multiple debugnet
 * clients.  (Clients are limited to single connections.)
 *
 * Returns zero on success, or errno.
 */
int debugnet_connect(const struct debugnet_conn_params *,
    struct debugnet_pcb **pcb_out);

/*
 * Free a debugnet stream that was previously successfully opened.
 *
 * No attempt is made to cleanly terminate communication with the remote
 * server.  Consumers should first send an empty DEBUGNET_FINISHED message, or
 * otherwise let the remote know they are signing off.
 */
void debugnet_free(struct debugnet_pcb *);

/*
 * Send a message, with common debugnet_msg_hdr header, to the connected remote
 * server.
 *
 * - mhtype translates directly to mh_type (e.g., DEBUGNET_DATA, or some other
 *   protocol-specific type).
 * - Data and datalen describe the attached data; datalen may be zero.
 * - If auxdata is NULL, mh_offset's initial value and mh_aux2 will be zero.
 *   Otherwise, mh_offset's initial value will be auxdata->dp_offset_start and
 *   mh_aux2 will have the value of auxdata->dp_aux2.
 *
 * Returns zero on success, or an errno on failure.
 */
struct debugnet_proto_aux {
	uint64_t dp_offset_start;
	uint32_t dp_aux2;
};
int debugnet_send(struct debugnet_pcb *, uint32_t mhtype, const void *data,
    uint32_t datalen, const struct debugnet_proto_aux *auxdata);

/*
 * A simple wrapper around the above when no data or auxdata is needed.
 */
static inline int
debugnet_sendempty(struct debugnet_pcb *pcb, uint32_t mhtype)
{
	return (debugnet_send(pcb, mhtype, NULL, 0, NULL));
}

/*
 * Full-duplex RX should ACK received messages.
 */
int debugnet_ack_output(struct debugnet_pcb *, uint32_t seqno /*net endian*/);

/*
 * Check and/or wait for further packets.
 */
void debugnet_network_poll(struct debugnet_pcb *);

/*
 * PCB accessors.
 */

/*
 * Get the 48-bit MAC address of the discovered next hop (gateway, or
 * destination server if it is on the same segment.
 */
const unsigned char *debugnet_get_gw_mac(const struct debugnet_pcb *);

/*
 * Get the connected server address.
 */
const in_addr_t *debugnet_get_server_addr(const struct debugnet_pcb *);

/*
 * Get the connected server port.
 */
const uint16_t debugnet_get_server_port(const struct debugnet_pcb *);

/*
 * Callbacks from core mbuf code.
 */
void debugnet_any_ifnet_update(struct ifnet *);

/*
 * DDB parsing helper for common debugnet options.
 *
 * -s <server> [-g <gateway -c <localip> -i <interface>]
 *
 * Order is not significant.  Interface is an online interface that supports
 * debugnet and can route to the debugnet server.  The other parameters are all
 * IP addresses.  Only the server parameter is required.  The others are
 * inferred automatically from the routing table, if not explicitly provided.
 *
 * Provides basic '-h' using provided 'cmd' string.
 *
 * Returns zero on success, or errno.
 */
struct debugnet_ddb_config {
	struct ifnet	*dd_ifp;	/* not ref'd */
	in_addr_t	dd_client;
	in_addr_t	dd_server;
	in_addr_t	dd_gateway;
	bool		dd_has_client : 1;
	bool		dd_has_gateway : 1;
};
int debugnet_parse_ddb_cmd(const char *cmd,
    struct debugnet_ddb_config *result);

/* Expose sysctl variables for netdump(4) to alias. */
extern int debugnet_npolls;
extern int debugnet_nretries;
extern int debugnet_arp_nretries;

/*
 * Conditionally-defined macros for device drivers so we can avoid ifdef
 * wrappers in every single implementation.
 */
#ifdef DEBUGNET
#define	DEBUGNET_DEFINE(driver)					\
	static debugnet_init_t driver##_debugnet_init;		\
	static debugnet_event_t driver##_debugnet_event;	\
	static debugnet_transmit_t driver##_debugnet_transmit;	\
	static debugnet_poll_t driver##_debugnet_poll;		\
								\
	static struct debugnet_methods driver##_debugnet_methods = { \
		.dn_init = driver##_debugnet_init,		\
		.dn_event = driver##_debugnet_event,		\
		.dn_transmit = driver##_debugnet_transmit,	\
		.dn_poll = driver##_debugnet_poll,		\
	}

#define	DEBUGNET_NOTIFY_MTU(ifp)	debugnet_any_ifnet_update(ifp)

#define	DEBUGNET_SET(ifp, driver)				\
	if_setdebugnet_methods((ifp), &driver##_debugnet_methods)

#else /* !DEBUGNET || !INET */

#define	DEBUGNET_DEFINE(driver)
#define	DEBUGNET_NOTIFY_MTU(ifp)
#define	DEBUGNET_SET(ifp, driver)

#endif /* DEBUGNET && INET */
#endif /* _KERNEL */