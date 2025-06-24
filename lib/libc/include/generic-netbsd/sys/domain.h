/*	$NetBSD: domain.h,v 1.35 2022/09/03 02:53:18 thorpej Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1993
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
 *	@(#)domain.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _SYS_DOMAIN_H_
#define _SYS_DOMAIN_H_

/*
 * Structure per communications domain.
 */
#include <sys/mbuf.h>
#include <sys/socket.h>
#include <net/route.h>

/*
 * Forward structure declarations for function prototypes [sic].
 */
struct	lwp;
struct	mbuf;
struct	ifnet;
struct	ifqueue;
struct  sockaddr;

LIST_HEAD(dom_rtlist, route);

struct	domain {
	int	dom_family;		/* AF_xxx */
	const char *dom_name;
	void	(*dom_init)		/* initialize domain data structures */
			(void);
	int	(*dom_externalize)	/* externalize access rights */
			(struct mbuf *, struct lwp *, int);
	void	(*dom_dispose)		/* dispose of internalized rights */
			(struct mbuf *);
	const struct protosw *dom_protosw, *dom_protoswNPROTOSW;
	int	(*dom_rtattach)		/* initialize routing table */
			(rtbl_t **, int);
	int	dom_rtoffset;		/* an arg to rtattach, in bits */
	int	dom_maxrtkey;		/* for routing layer */
	void	(*dom_if_up)		/* ifnet brought up */
			(struct ifnet *);
	void	(*dom_if_down)		/* ifnet brought down */
			(struct ifnet *);
	void	*(*dom_ifattach)	/* attach af-dependent data on ifnet */
			(struct ifnet *);
	void	(*dom_ifdetach)		/* detach af-dependent data on ifnet */
			(struct ifnet *, void *);
	void	(*dom_if_link_state_change)
			(struct ifnet *, int);
	const void *(*dom_sockaddr_const_addr)(const struct sockaddr *,
					       socklen_t *);
	void	*(*dom_sockaddr_addr)(struct sockaddr *, socklen_t *);
	int	(*dom_sockaddr_cmp)(const struct sockaddr *,
	                            const struct sockaddr *);
	struct sockaddr *(*dom_sockaddr_externalize)(struct sockaddr *,
	                                             socklen_t,
						     const struct sockaddr *);
	const struct sockaddr *dom_sa_any;
	struct ifqueue *dom_ifqueues[2]; /* XXX G/C ifqueue for domain */
	STAILQ_ENTRY(domain) dom_link;
	struct	mowner dom_mowner;
	uint_fast8_t	dom_sa_cmpofs;
	uint_fast8_t	dom_sa_cmplen;
};

STAILQ_HEAD(domainhead,domain);

#ifdef _KERNEL
#define	DOMAIN_DEFINE(name)	\
	extern struct domain name; \
	__link_set_add_data(domains, name)

#define	DOMAIN_FOREACH(dom)	STAILQ_FOREACH(dom, &domains, dom_link)
extern struct domainhead domains;
void domain_attach(struct domain *);
void domaininit(bool);
void domaininit_post(void);
#endif

#endif /* !_SYS_DOMAIN_H_ */