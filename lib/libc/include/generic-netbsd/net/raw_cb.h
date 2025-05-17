/*	$NetBSD: raw_cb.h,v 1.30 2018/09/07 06:13:14 maxv Exp $	*/

/*
 * Copyright (c) 1980, 1986, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)raw_cb.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NET_RAW_CB_H_
#define _NET_RAW_CB_H_

#ifdef _KERNEL

/*
 * Raw protocol interface control block.  Used
 * to tie a socket to the generic raw interface.
 */
struct rawcb {
	LIST_ENTRY(rawcb) rcb_list;	/* doubly linked list */
	struct	socket *rcb_socket;	/* back pointer to socket */
	struct	sockaddr *rcb_faddr;	/* destination address */
	struct	sockaddr *rcb_laddr;	/* socket's address */
	struct	sockproto rcb_proto;	/* protocol family, protocol */
	int	(*rcb_filter)(struct mbuf *, struct sockproto *,
		              struct rawcb *);
	size_t	rcb_len;
};

#define	sotorawcb(so)		((struct rawcb *)(so)->so_pcb)

/*
 * Nominal space allocated to a raw socket.
 */
#define	RAWSNDQ		8192
#define	RAWRCVQ		16384

LIST_HEAD(rawcbhead, rawcb);

int	raw_attach(struct socket *, int, struct rawcbhead *);
void	*raw_ctlinput(int, const struct sockaddr *, void *);
void	raw_detach(struct socket *);
void	raw_disconnect(struct rawcb *);
void	raw_input(struct mbuf *, struct sockproto *, struct sockaddr *,
	    struct sockaddr *, struct rawcbhead *);
int	raw_usrreq(struct socket *,
	    int, struct mbuf *, struct mbuf *, struct mbuf *, struct lwp *);
void	raw_setsockaddr(struct rawcb *, struct sockaddr *);
void	raw_setpeeraddr(struct rawcb *, struct sockaddr *);
int	raw_send(struct socket *,
	    struct mbuf *, struct sockaddr *, struct mbuf *, struct lwp *,
	    int (*)(struct mbuf *, struct socket *));

#endif /* _KERNEL */

#endif /* !_NET_RAW_CB_H_ */