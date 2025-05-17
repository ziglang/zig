/*	$NetBSD: udp_var.h,v 1.48 2021/02/03 11:53:43 roy Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1989, 1993
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
 *	@(#)udp_var.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET_UDP_VAR_H_
#define _NETINET_UDP_VAR_H_

/*
 * UDP kernel structures and variables.
 */
struct	udpiphdr {
	struct	ipovly ui_i;		/* overlaid ip structure */
	struct	udphdr ui_u;		/* udp header */
};
#ifdef CTASSERT
CTASSERT(sizeof(struct udpiphdr) == 28);
#endif
#define	ui_x1		ui_i.ih_x1
#define	ui_pr		ui_i.ih_pr
#define	ui_len		ui_i.ih_len
#define	ui_src		ui_i.ih_src
#define	ui_dst		ui_i.ih_dst
#define	ui_sport	ui_u.uh_sport
#define	ui_dport	ui_u.uh_dport
#define	ui_ulen		ui_u.uh_ulen
#define	ui_sum		ui_u.uh_sum

/*
 * UDP statistics.
 * Each counter is an unsigned 64-bit value.
 */
#define	UDP_STAT_IPACKETS	0	/* total input packets */
#define	UDP_STAT_HDROPS		1	/* packet shorter than header */
#define	UDP_STAT_BADSUM		2	/* checksum error */
#define	UDP_STAT_BADLEN		3	/* data length larger than packet */
#define	UDP_STAT_NOPORT		4	/* no socket on port */
#define	UDP_STAT_NOPORTBCAST	5	/* of above, arrived as broadcast */
#define	UDP_STAT_FULLSOCK	6	/* not delivered, input socket full */
#define	UDP_STAT_PCBHASHMISS	7	/* input packets missing PCB hash */
#define	UDP_STAT_OPACKETS	8	/* total output packets */

#define	UDP_NSTATS		9

/*
 * Names for UDP sysctl objects
 */
#define	UDPCTL_CHECKSUM		1	/* checksum UDP packets */
#define	UDPCTL_SENDSPACE	2	/* default send buffer */
#define	UDPCTL_RECVSPACE	3	/* default recv buffer */
#define	UDPCTL_LOOPBACKCKSUM	4	/* do UDP checksum on loopback */
#define	UDPCTL_STATS		5	/* UDP statistics */

#ifdef _KERNEL

extern struct inpcbtable udbtable;
extern const struct pr_usrreqs udp_usrreqs;

void *udp_ctlinput(int, const struct sockaddr *, void *);
int udp_ctloutput(int, struct socket *, struct sockopt *);
void udp_init(void);
void udp_init_common(void);
void udp_input(struct mbuf *, int, int);
int udp_output(struct mbuf *, struct inpcb *, struct mbuf *, struct lwp *);
int udp_send(struct socket *, struct mbuf *, struct sockaddr *,
    struct mbuf *, struct lwp *);
int udp_input_checksum(int af, struct mbuf *, const struct udphdr *, int, int);
void udp_statinc(u_int);
#endif /* _KERNEL */

#endif /* !_NETINET_UDP_VAR_H_ */