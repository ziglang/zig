/*	$NetBSD: udp6_var.h,v 1.31 2022/10/28 05:18:39 ozaki-r Exp $	*/
/*	$KAME: udp6_var.h,v 1.11 2000/06/05 00:14:31 itojun Exp $	*/

/*
 * Copyright (C) 1995, 1996, 1997, and 1998 WIDE Project.
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
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

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

#ifndef _NETINET6_UDP6_VAR_H_
#define _NETINET6_UDP6_VAR_H_

/*
 * UDP Kernel structures and variables.
 */

#define	UDP6_STAT_IPACKETS	0	/* total input packets */
#define	UDP6_STAT_HDROPS	1	/* packet shorter than header */
#define	UDP6_STAT_BADSUM	2	/* checksum error */
#define	UDP6_STAT_NOSUM		3	/* no checksum */
#define	UDP6_STAT_BADLEN	4	/* data length larger than packet */
#define	UDP6_STAT_NOPORT	5	/* no socket on port */
#define	UDP6_STAT_NOPORTMCAST	6	/* of above, arrived as multicast */
#define	UDP6_STAT_FULLSOCK	7	/* not delivered, input socket full */
#define	UDP6_STAT_PCBCACHEMISS	8	/* input packets missing pcb cache */
#define	UDP6_STAT_OPACKETS	9	/* total output packets */

#define	UDP6_NSTATS		10

/*
 * Names for UDP6 sysctl objects
 */
#define	UDP6CTL_SENDSPACE	1	/* default send buffer */
#define	UDP6CTL_RECVSPACE	2	/* default recv buffer */
#define	UDP6CTL_LOOPBACKCKSUM	3	/* do UDP checksum on loopback? */
#define	UDP6CTL_STATS		4	/* udp6 statistics */

#ifdef _KERNEL

extern const struct pr_usrreqs udp6_usrreqs;

void	*udp6_ctlinput(int, const struct sockaddr *, void *);
int	udp6_ctloutput(int, struct socket *, struct sockopt *);
void	udp6_init(void);
int	udp6_input(struct mbuf **, int *, int);
int	udp6_output(struct inpcb *, struct mbuf *, struct sockaddr_in6 *,
    struct mbuf *, struct lwp *);
int	udp6_sysctl(int *, u_int, void *, size_t *, void *, size_t);
int	udp6_usrreq(struct socket *, int, struct mbuf *, struct mbuf *,
    struct mbuf *, struct lwp *);
int	udp6_realinput(int, struct sockaddr_in6 *, struct sockaddr_in6 *,
    struct mbuf **, int);
int	udp6_input_checksum(struct mbuf *, const struct udphdr *, int, int);

void	udp6_statinc(u_int);
#endif /* _KERNEL */

#endif /* !_NETINET6_UDP6_VAR_H_ */