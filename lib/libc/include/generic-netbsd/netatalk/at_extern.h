/*	$NetBSD: at_extern.h,v 1.21 2022/09/03 01:48:22 thorpej Exp $	*/

/*
 * Copyright (c) 1990,1994 Regents of The University of Michigan.
 * All Rights Reserved.
 *
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose and without fee is hereby granted,
 * provided that the above copyright notice appears in all copies and
 * that both that copyright notice and this permission notice appear
 * in supporting documentation, and that the name of The University
 * of Michigan not be used in advertising or publicity pertaining to
 * distribution of the software without specific, written prior
 * permission. This software is supplied as is without expressed or
 * implied warranties of any kind.
 *
 * This product includes software developed by the University of
 * California, Berkeley and its contributors.
 *
 *	Research Systems Unix Group
 *	The University of Michigan
 *	c/o Wesley Craig
 *	535 W. William Street
 *	Ann Arbor, Michigan
 *	+1-313-764-2278
 *	netatalk@umich.edu
 */

#ifndef _NETATALK_AT_EXTERN_H_
#define _NETATALK_AT_EXTERN_H_

struct ifnet;
struct mbuf;
struct sockaddr_at;
struct proc;
struct ifaddr;
struct at_ifaddr;
struct route;
struct socket;
struct ddpcb;

extern struct mowner atalk_rx_mowner;
extern struct mowner atalk_tx_mowner;

extern const struct pr_usrreqs ddp_usrreqs;

void	atintr1(void *);
void	atintr2(void *);
void	aarpprobe(void *);
int	aarpresolve(struct ifnet *, struct mbuf *, const struct sockaddr_at *,
    u_char *);
void	aarpinput(struct ifnet *, struct mbuf *);
int	at_broadcast(const struct sockaddr_at *);
int	at_control(u_long, void *, struct ifnet *);
int	at_inithead(void **, int);
void	at_purgeaddr(struct ifaddr *);
void	at_purgeif(struct ifnet *);
u_int16_t
	at_cksum(struct mbuf *, int);
void	ddp_init(void);
struct ifaddr *
	at_ifawithnet(const struct sockaddr_at *, struct ifnet *);
int	ddp_output(struct mbuf *, struct ddpcb *);
struct ddpcb  *
	ddp_search(struct sockaddr_at *, struct sockaddr_at *,
    struct at_ifaddr *);
int     ddp_route(struct mbuf *, struct route *);
char *	prsockaddr(const void *);

#endif /* !_NETATALK_AT_EXTERN_H_ */