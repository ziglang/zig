/*	$NetBSD: sco.h,v 1.11 2014/08/05 07:55:32 rtr Exp $	*/

/*-
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

#ifndef _NETBT_SCO_H_
#define _NETBT_SCO_H_

#define SO_SCO_MTU		1
#define SO_SCO_HANDLE		2

#ifdef _KERNEL
/*
 * SCO protocol control block
 */
struct sco_pcb {
	struct hci_link		*sp_link;	/* SCO link */
	unsigned int		 sp_flags;	/* flags */
	bdaddr_t		 sp_laddr;	/* local address */
	bdaddr_t		 sp_raddr;	/* remote address */
	unsigned int		 sp_mtu;	/* link MTU */
	int			 sp_pending;	/* number of packets pending */

	const struct btproto	*sp_proto;	/* upper layer protocol */
	void			*sp_upper;	/* upper layer argument */

	LIST_ENTRY(sco_pcb)	 sp_next;
};

LIST_HEAD(sco_pcb_list, sco_pcb);
extern struct sco_pcb_list sco_pcb;

/* sp_flags */
#define SP_LISTENING		(1<<0)		/* is listening pcb */

struct socket;
struct sockopt;

/* sco_socket.c */
extern int sco_sendspace;
extern int sco_recvspace;
int sco_ctloutput(int, struct socket *, struct sockopt *);

/* sco_upper.c */
int sco_attach_pcb(struct sco_pcb **, const struct btproto *, void *);
int sco_bind_pcb(struct sco_pcb *, struct sockaddr_bt *);
int sco_sockaddr_pcb(struct sco_pcb *, struct sockaddr_bt *);
int sco_connect_pcb(struct sco_pcb *, struct sockaddr_bt *);
int sco_peeraddr_pcb(struct sco_pcb *, struct sockaddr_bt *);
int sco_disconnect_pcb(struct sco_pcb *, int);
void sco_detach_pcb(struct sco_pcb **);
int sco_listen_pcb(struct sco_pcb *);
int sco_send_pcb(struct sco_pcb *, struct mbuf *);
int sco_setopt(struct sco_pcb *, const struct sockopt *);
int sco_getopt(struct sco_pcb *, struct sockopt *);

#endif	/* _KERNEL */

#endif	/* _NETBT_SCO_H_ */