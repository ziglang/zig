/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Isilon Systems, LLC.
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

#pragma once

#ifndef DEBUGNET_INTERNAL
#error "Don't include this"
#endif

#define	DNETDEBUG(f, ...) do {						\
	if (debugnet_debug > 0)						\
		printf(("%s: " f), __func__, ## __VA_ARGS__);		\
} while (0)
#define	DNETDEBUG_IF(i, f, ...) do {					\
	if (debugnet_debug > 0)						\
		if_printf((i), ("%s: " f), __func__, ## __VA_ARGS__);	\
} while (0)
#define	DNETDEBUGV(f, ...) do {						\
	if (debugnet_debug > 1)						\
		printf(("%s: " f), __func__, ## __VA_ARGS__);		\
} while (0)

enum dnet_pcb_st {
	DN_STATE_INIT = 1,
	DN_STATE_HAVE_GW_MAC,
	DN_STATE_GOT_HERALD_PORT,
	DN_STATE_REMOTE_CLOSED,
};

struct debugnet_pcb {
	uint64_t		dp_rcvd_acks;

	in_addr_t		dp_client;
	in_addr_t		dp_server;
	in_addr_t		dp_gateway;
	uint32_t		dp_seqno;

	struct ether_addr	dp_gw_mac;
	uint16_t		dp_server_port;

	struct ifnet		*dp_ifp;
	/* Saved driver if_input to restore on close. */
	void			(*dp_drv_input)(struct ifnet *, struct mbuf *);

	/* RX handler for bidirectional protocols. */
	int			(*dp_rx_handler)(struct mbuf *);

	/* Cleanup signal for bidirectional protocols. */
	void			(*dp_finish_handler)(void);

	enum dnet_pcb_st	dp_state;
	uint16_t		dp_client_port;
	bool			dp_event_started;
};

/* TODO(CEM): Obviate this assertion by using a BITSET(9) for acks. */
CTASSERT(sizeof(((struct debugnet_pcb *)0)->dp_rcvd_acks) * NBBY >=
    DEBUGNET_MAX_IN_FLIGHT);

extern unsigned debugnet_debug;
SYSCTL_DECL(_net_debugnet);

int debugnet_ether_output(struct mbuf *, struct ifnet *, struct ether_addr,
    u_short);
void debugnet_handle_udp(struct debugnet_pcb *, struct mbuf **);

#ifdef INET
int debugnet_arp_gw(struct debugnet_pcb *);
void debugnet_handle_arp(struct debugnet_pcb *, struct mbuf **);
void debugnet_handle_ip(struct debugnet_pcb *, struct mbuf **);
int debugnet_ip_output(struct debugnet_pcb *, struct mbuf *);
#endif