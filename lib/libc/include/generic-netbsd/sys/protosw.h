/*	$NetBSD: protosw.h,v 1.69 2018/09/14 05:09:51 maxv Exp $	*/

/*-
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
 *	@(#)protosw.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _SYS_PROTOSW_H_
#define _SYS_PROTOSW_H_

/*
 * Protocol switch table.
 *
 * Each protocol has a handle initializing one of these structures,
 * which is used for protocol-protocol and system-protocol communication.
 *
 * A protocol is called through the pr_init entry before any other.
 * Thereafter it is called every 200ms through the pr_fasttimo entry and
 * every 500ms through the pr_slowtimo for timer based actions.
 * The system will call the pr_drain entry if it is low on space and
 * this should throw away any non-critical data.
 *
 * Protocols pass data between themselves as chains of mbufs using
 * the pr_input and pr_output hooks.  Pr_input passes data up (towards
 * UNIX) and pr_output passes it down (towards the imps); control
 * information passes up and down on pr_ctlinput and pr_ctloutput.
 * The protocol is responsible for the space occupied by any the
 * arguments to these entries and must dispose it.
 *
 * The userreq routine interfaces protocols to the system and is
 * described below.
 */

struct mbuf;
struct ifnet;
struct sockaddr;
struct socket;
struct sockopt;
struct stat;
struct domain;
struct proc;
struct lwp;
struct pr_usrreqs;

struct protosw {
	int 	pr_type;		/* socket type used for */
	struct	domain *pr_domain;	/* domain protocol a member of */
	short	pr_protocol;		/* protocol number */
	short	pr_flags;		/* see below */

/* protocol-protocol hooks */
	void	(*pr_input)		/* input to protocol (from below) */
			(struct mbuf *, int, int);
	void	*(*pr_ctlinput)		/* control input (from below) */
			(int, const struct sockaddr *, void *);
	int	(*pr_ctloutput)		/* control output (from above) */
			(int, struct socket *, struct sockopt *);

/* user-protocol hooks */
	const struct pr_usrreqs *pr_usrreqs;

/* utility hooks */
	void	(*pr_init)		/* initialization hook */
			(void);

	void	(*pr_fasttimo)		/* fast timeout (200ms) */
			(void);
	void	(*pr_slowtimo)		/* slow timeout (500ms) */
			(void);
	void	(*pr_drain)		/* flush any excess space possible */
			(void);
};

#define	PR_SLOWHZ	2		/* 2 slow timeouts per second */
#define	PR_FASTHZ	5		/* 5 fast timeouts per second */

/*
 * Values for pr_flags.
 * PR_ADDR requires PR_ATOMIC;
 * PR_ADDR and PR_CONNREQUIRED are mutually exclusive.
 */
#define	PR_ATOMIC	0x01		/* exchange atomic messages only */
#define	PR_ADDR		0x02		/* addresses given with messages */
#define	PR_CONNREQUIRED	0x04		/* connection required by protocol */
#define	PR_WANTRCVD	0x08		/* want pr_rcvd() calls */
#define	PR_RIGHTS	0x10		/* passes capabilities */
#define	PR_LISTEN	0x20		/* supports listen(2) and accept(2) */
#define	PR_LASTHDR	0x40		/* enforce ipsec policy; last header */
#define	PR_ABRTACPTDIS	0x80		/* abort on accept(2) to disconnected
					   socket */
#define PR_PURGEIF	0x100		/* might store struct ifnet pointer;
					   pr_purgeif() must be called on ifnet
					   deletion */
#define	PR_ADDR_OPT	0x200		/* Allow address during delivery */


/*
 * The arguments to usrreq are:
 *	(*protosw[].pr_usrreq)(up, req, m, nam, opt, p);
 * where up is a (struct socket *), req is one of these requests,
 * m is a optional mbuf chain containing a message,
 * nam is an optional mbuf chain containing an address,
 * opt is an optional mbuf containing socket options,
 * and p is a pointer to the process requesting the action (if any).
 * The protocol is responsible for disposal of the mbuf chains m and opt,
 * the caller is responsible for any space held by nam.
 * A non-zero return from usrreq gives an
 * UNIX error number which should be passed to higher level software.
 */
#define	PRU_ATTACH		0	/* attach protocol to up */
#define	PRU_DETACH		1	/* detach protocol from up */
#define	PRU_BIND		2	/* bind socket to address */
#define	PRU_LISTEN		3	/* listen for connection */
#define	PRU_CONNECT		4	/* establish connection to peer */
#define	PRU_ACCEPT		5	/* accept connection from peer */
#define	PRU_DISCONNECT		6	/* disconnect from peer */
#define	PRU_SHUTDOWN		7	/* won't send any more data */
#define	PRU_RCVD		8	/* have taken data; more room now */
#define	PRU_SEND		9	/* send this data */
#define	PRU_ABORT		10	/* abort (fast DISCONNECT, DETACH) */
#define	PRU_CONTROL		11	/* control operations on protocol */
#define	PRU_SENSE		12	/* return status into m */
#define	PRU_RCVOOB		13	/* retrieve out of band data */
#define	PRU_SENDOOB		14	/* send out of band data */
#define	PRU_SOCKADDR		15	/* fetch socket's address */
#define	PRU_PEERADDR		16	/* fetch peer's address */
#define	PRU_CONNECT2		17	/* connect two sockets */
/* begin for protocols internal use */
#define	PRU_FASTTIMO		18	/* 200ms timeout */
#define	PRU_SLOWTIMO		19	/* 500ms timeout */
#define	PRU_PROTORCV		20	/* receive from below */
#define	PRU_PROTOSEND		21	/* send to below */
#define	PRU_PURGEIF		22	/* purge specified if */

#define	PRU_NREQ		23

#ifdef PRUREQUESTS
static const char * const prurequests[] = {
	"ATTACH",	"DETACH",	"BIND",		"LISTEN",
	"CONNECT",	"ACCEPT",	"DISCONNECT",	"SHUTDOWN",
	"RCVD",		"SEND",		"ABORT",	"CONTROL",
	"SENSE",	"RCVOOB",	"SENDOOB",	"SOCKADDR",
	"PEERADDR",	"CONNECT2",	"FASTTIMO",	"SLOWTIMO",
	"PROTORCV",	"PROTOSEND",	"PURGEIF",
};
#endif

/*
 * The arguments to the ctlinput routine are
 *	(*protosw[].pr_ctlinput)(cmd, sa, arg);
 * where cmd is one of the commands below, sa is a pointer to a sockaddr,
 * and arg is an optional void *argument used within a protocol family.
 */
#define	PRC_IFDOWN		0	/* interface transition */
#define	PRC_ROUTEDEAD		1	/* select new route if possible ??? */
#define	PRC_QUENCH2		3	/* DEC congestion bit says slow down */
#define	PRC_QUENCH		4	/* some one said to slow down */
#define	PRC_MSGSIZE		5	/* message size forced drop */
#define	PRC_HOSTDEAD		6	/* host appears to be down */
#define	PRC_HOSTUNREACH		7	/* deprecated (use PRC_UNREACH_HOST) */
#define	PRC_UNREACH_NET		8	/* no route to network */
#define	PRC_UNREACH_HOST	9	/* no route to host */
#define	PRC_UNREACH_PROTOCOL	10	/* dst says bad protocol */
#define	PRC_UNREACH_PORT	11	/* bad port # */
/* was	PRC_UNREACH_NEEDFRAG	12	   (use PRC_MSGSIZE) */
#define	PRC_UNREACH_SRCFAIL	13	/* source route failed */
#define	PRC_REDIRECT_NET	14	/* net routing redirect */
#define	PRC_REDIRECT_HOST	15	/* host routing redirect */
#define	PRC_REDIRECT_TOSNET	16	/* redirect for type of service & net */
#define	PRC_REDIRECT_TOSHOST	17	/* redirect for tos & host */
#define	PRC_TIMXCEED_INTRANS	18	/* packet lifetime expired in transit */
#define	PRC_TIMXCEED_REASS	19	/* lifetime expired on reass q */
#define	PRC_PARAMPROB		20	/* header incorrect */

#define	PRC_NCMDS		21

#define	PRC_IS_REDIRECT(cmd)	\
	((cmd) >= PRC_REDIRECT_NET && (cmd) <= PRC_REDIRECT_TOSHOST)

#ifdef PRCREQUESTS
static const char * const prcrequests[] = {
	"IFDOWN", "ROUTEDEAD", "#2", "DEC-BIT-QUENCH2",
	"QUENCH", "MSGSIZE", "HOSTDEAD", "#7",
	"NET-UNREACH", "HOST-UNREACH", "PROTO-UNREACH", "PORT-UNREACH",
	"#12", "SRCFAIL-UNREACH", "NET-REDIRECT", "HOST-REDIRECT",
	"TOSNET-REDIRECT", "TOSHOST-REDIRECT", "TX-INTRANS", "TX-REASS",
	"PARAMPROB"
};
#endif

/*
 * The arguments to ctloutput are:
 *	(*protosw[].pr_ctloutput)(req, so, sopt);
 * req is one of the actions listed below, so is a (struct socket *),
 * sopt is a (struct sockopt *)
 * A non-zero return from usrreq gives an
 * UNIX error number which should be passed to higher level software.
 */
#define	PRCO_GETOPT	0
#define	PRCO_SETOPT	1

#define	PRCO_NCMDS	2

#ifdef PRCOREQUESTS
static const char * const prcorequests[] = {
	"GETOPT", "SETOPT",
};
#endif

#ifdef _KERNEL

struct pr_usrreqs {
	int	(*pr_attach)(struct socket *, int);
	void	(*pr_detach)(struct socket *);
	int	(*pr_accept)(struct socket *, struct sockaddr *);
	int	(*pr_connect)(struct socket *, struct sockaddr *, struct lwp *);
	int	(*pr_connect2)(struct socket *, struct socket *);
	int	(*pr_bind)(struct socket *, struct sockaddr *, struct lwp *);
	int	(*pr_listen)(struct socket *, struct lwp *);
	int	(*pr_disconnect)(struct socket *);
	int	(*pr_shutdown)(struct socket *);
	int	(*pr_abort)(struct socket *);
	int	(*pr_ioctl)(struct socket *, u_long, void *, struct ifnet *);
	int	(*pr_stat)(struct socket *, struct stat *);
	int	(*pr_peeraddr)(struct socket *, struct sockaddr *);
	int	(*pr_sockaddr)(struct socket *, struct sockaddr *);
	int	(*pr_rcvd)(struct socket *, int, struct lwp *);
	int	(*pr_recvoob)(struct socket *, struct mbuf *, int);
	int	(*pr_send)(struct socket *, struct mbuf *, struct sockaddr *,
	    struct mbuf *, struct lwp *);
	int	(*pr_sendoob)(struct socket *, struct mbuf *, struct mbuf *);
	int	(*pr_purgeif)(struct socket *, struct ifnet *);
};

/*
 * Monotonically increasing time values for slow and fast timers.
 */
extern	u_int pfslowtimo_now;
extern	u_int pffasttimo_now;

#define	PRT_SLOW_ARM(t, nticks)	(t) = (pfslowtimo_now + (nticks))
#define	PRT_FAST_ARM(t, nticks)	(t) = (pffasttimo_now + (nticks))

#define	PRT_SLOW_DISARM(t)	(t) = 0
#define	PRT_FAST_DISARM(t)	(t) = 0

#define	PRT_SLOW_ISARMED(t)	((t) != 0)
#define	PRT_FAST_ISARMED(t)	((t) != 0)

#define	PRT_SLOW_ISEXPIRED(t)	(PRT_SLOW_ISARMED((t)) && (t) <= pfslowtimo_now)
#define	PRT_FAST_ISEXPIRED(t)	(PRT_FAST_ISARMED((t)) && (t) <= pffasttimo_now)

struct sockaddr;
const struct protosw *pffindproto(int, int, int);
const struct protosw *pffindtype(int, int);
struct domain *pffinddomain(int);
void pfctlinput(int, const struct sockaddr *);
void pfctlinput2(int, const struct sockaddr *, void *);

/*
 * Wrappers for non-MPSAFE protocols
 */
#include <sys/systm.h>	/* kernel_lock */

#define	PR_WRAP_USRREQS(name)				\
static int						\
name##_attach_wrapper(struct socket *a, int b)		\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_attach(a, b);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static void						\
name##_detach_wrapper(struct socket *a)			\
{							\
	KERNEL_LOCK(1, NULL);				\
	name##_detach(a);				\
	KERNEL_UNLOCK_ONE(NULL);			\
}							\
static int						\
name##_accept_wrapper(struct socket *a,			\
    struct sockaddr *b)					\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_accept(a, b);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_bind_wrapper(struct socket *a,			\
    struct sockaddr *b,	struct lwp *c)			\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_bind(a, b, c);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_connect_wrapper(struct socket *a,		\
    struct sockaddr *b, struct lwp *c)			\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_connect(a, b, c);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_connect2_wrapper(struct socket *a,		\
    struct socket *b)					\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_connect2(a, b);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_listen_wrapper(struct socket *a, struct lwp *b)	\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_listen(a, b);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_disconnect_wrapper(struct socket *a)		\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_disconnect(a);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_shutdown_wrapper(struct socket *a)		\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_shutdown(a);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_abort_wrapper(struct socket *a)			\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_abort(a);				\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_ioctl_wrapper(struct socket *a, u_long b,	\
    void *c, struct ifnet *d)				\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_ioctl(a, b, c, d);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_stat_wrapper(struct socket *a, struct stat *b)	\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_stat(a, b);				\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_peeraddr_wrapper(struct socket *a,		\
    struct sockaddr *b)					\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_peeraddr(a, b);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_sockaddr_wrapper(struct socket *a,		\
    struct sockaddr *b)					\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_sockaddr(a, b);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_rcvd_wrapper(struct socket *a, int b,		\
    struct lwp *c)					\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_rcvd(a, b, c);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_recvoob_wrapper(struct socket *a,		\
    struct mbuf *b, int c)				\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_recvoob(a, b, c);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_send_wrapper(struct socket *a, struct mbuf *b,	\
    struct sockaddr *c, struct mbuf *d, struct lwp *e)	\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_send(a, b, c, d, e);		\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_sendoob_wrapper(struct socket *a,		\
    struct mbuf *b, struct mbuf *c)			\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_sendoob(a, b, c);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}							\
static int						\
name##_purgeif_wrapper(struct socket *a,		\
    struct ifnet *b)					\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name##_purgeif(a, b);			\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}

#define	PR_WRAP_CTLOUTPUT(name)				\
static int						\
name##_wrapper(int a, struct socket *b,			\
    struct sockopt *c)					\
{							\
	int rv;						\
	KERNEL_LOCK(1, NULL);				\
	rv = name(a, b, c);				\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}

#define	PR_WRAP_CTLINPUT(name)				\
static void *						\
name##_wrapper(int a, const struct sockaddr *b, void *c)\
{							\
	void *rv;					\
	KERNEL_LOCK(1, NULL);				\
	rv = name(a, b, c);				\
	KERNEL_UNLOCK_ONE(NULL);			\
	return rv;					\
}

#include <sys/socketvar.h> /* for softnet_lock */

#define	PR_WRAP_INPUT(name)				\
static void						\
name##_wrapper(struct mbuf *m, int off, int proto)	\
{							\
	mutex_enter(softnet_lock);			\
	name(m, off, proto);				\
	mutex_exit(softnet_lock);			\
}

#endif /* _KERNEL */

#endif /* !_SYS_PROTOSW_H_ */