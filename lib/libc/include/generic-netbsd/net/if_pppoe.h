/* $NetBSD: if_pppoe.h,v 1.15 2017/10/12 09:50:55 knakahara Exp $ */

/*-
 * Copyright (c) 2002 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Martin Husemann <martin@NetBSD.org>.
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

#ifndef _NET_IF_PPPOE_H_
#define _NET_IF_PPPOE_H_

#include <sys/ioccom.h>

struct pppoediscparms {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	char	eth_ifname[IFNAMSIZ];	/* external ethernet interface name */
	const char *ac_name;		/* access concentrator name (or NULL) */
	size_t	ac_name_len;		/* on write: length of buffer for ac_name */
	const char *service_name;	/* service name (or NULL) */
	size_t	service_name_len;	/* on write: length of buffer for service name */
};

#define	PPPOESETPARMS	_IOW('i', 110, struct pppoediscparms)
#define	PPPOEGETPARMS	_IOWR('i', 111, struct pppoediscparms)

#define PPPOE_STATE_INITIAL	0
#define PPPOE_STATE_PADI_SENT	1
#define	PPPOE_STATE_PADR_SENT	2
#define	PPPOE_STATE_SESSION	3
#define	PPPOE_STATE_CLOSING	4
/* passive */
#define	PPPOE_STATE_PADO_SENT	1

struct pppoeconnectionstate {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	u_int	state;			/* one of the PPPOE_STATE_ states above */
	u_int	session_id;		/* if state == PPPOE_STATE_SESSION */
	u_int	padi_retry_no;		/* number of retries already sent */
	u_int	padr_retry_no;
};

#define PPPOEGETSESSION	_IOWR('i', 112, struct pppoeconnectionstate)

#ifdef _KERNEL

void pppoe_input(struct ifnet *, struct mbuf *);
void pppoedisc_input(struct ifnet *, struct mbuf *);
#endif /* _KERNEL */
/*
 * Locking notes:
 * + pppoe_softc_list is protected by pppoe_softc_list_lock (an rwlock)
 *     pppoe_softc_list is a list of all pppoe_softc, and it is used to
 *     find pppoe interface by session id or host unique tag.
 * + pppoe_softc is protected by pppoe_softc->sc_lock (an rwlock)
 *     pppoe_softc holds session id and parameters to establish the id
 *
 * Locking order:
 *    - pppoe_softc_list_lock => pppoe_softc->sc_lock
 */
#endif /* !_NET_IF_PPPOE_H_ */