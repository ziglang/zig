/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1989, 1993
 *	The Regents of the University of California.
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
#define	_NETINET_UDP_VAR_H_

#include <sys/types.h>
#include <netinet/ip_var.h>
#include <netinet/udp.h>

/*
 * UDP kernel structures and variables.
 */
struct udpiphdr {
	struct ipovly	ui_i;		/* overlaid ip structure */
	struct udphdr	ui_u;		/* udp header */
};
#define	ui_x1		ui_i.ih_x1
#define	ui_v		ui_i.ih_x1[0]
#define	ui_pr		ui_i.ih_pr
#define	ui_len		ui_i.ih_len
#define	ui_src		ui_i.ih_src
#define	ui_dst		ui_i.ih_dst
#define	ui_sport	ui_u.uh_sport
#define	ui_dport	ui_u.uh_dport
#define	ui_ulen		ui_u.uh_ulen
#define	ui_sum		ui_u.uh_sum

/*
 * Identifiers for UDP sysctl nodes.
 */
#define	UDPCTL_CHECKSUM		1	/* checksum UDP packets */
#define	UDPCTL_STATS		2	/* statistics (read-only) */
#define	UDPCTL_MAXDGRAM		3	/* max datagram size */
#define	UDPCTL_RECVSPACE	4	/* default receive buffer space */
#define	UDPCTL_PCBLIST		5	/* list of PCBs for UDP sockets */

				/* IPsec: ESP in UDP tunneling: */
#define	UF_ESPINUDP_NON_IKE	0x00000001	/* w/ non-IKE marker .. */
	/* .. per draft-ietf-ipsec-nat-t-ike-0[01],
	 * and draft-ietf-ipsec-udp-encaps-(00/)01.txt */
#define	UF_ESPINUDP		0x00000002	/* w/ non-ESP marker. */

struct udpstat {
				/* input statistics: */
	uint64_t udps_ipackets;		/* total input packets */
	uint64_t udps_hdrops;		/* packet shorter than header */
	uint64_t udps_badsum;		/* checksum error */
	uint64_t udps_nosum;		/* no checksum */
	uint64_t udps_badlen;		/* data length larger than packet */
	uint64_t udps_noport;		/* no socket on port */
	uint64_t udps_noportbcast;	/* of above, arrived as broadcast */
	uint64_t udps_fullsock;		/* not delivered, input socket full */
	uint64_t udpps_pcbcachemiss;	/* input packets missing pcb cache */
	uint64_t udpps_pcbhashmiss;	/* input packets not for hashed pcb */
				/* output statistics: */
	uint64_t udps_opackets;		/* total output packets */
	uint64_t udps_fastout;		/* output packets on fast path */
	/* of no socket on port, arrived as multicast */
	uint64_t udps_noportmcast;
	uint64_t udps_filtermcast;	/* blocked by multicast filter */
};

#ifdef _KERNEL
#include <netinet/in_pcb.h>
#include <sys/counter.h>
struct mbuf;

typedef bool	udp_tun_func_t(struct mbuf *, int, struct inpcb *,
		    const struct sockaddr *, void *);
typedef union {
	struct icmp *icmp;
	struct ip6ctlparam *ip6cp;
} udp_tun_icmp_param_t __attribute__((__transparent_union__));
typedef void	udp_tun_icmp_t(udp_tun_icmp_param_t);

/*
 * UDP control block; one per udp.
 */
struct udpcb {
	struct inpcb	u_inpcb;
#define	u_start_zero	u_tun_func
#define	u_zero_size	(sizeof(struct udpcb) - \
			    offsetof(struct udpcb, u_start_zero))
	udp_tun_func_t	*u_tun_func;	/* UDP kernel tunneling callback. */
	udp_tun_icmp_t  *u_icmp_func;	/* UDP kernel tunneling icmp callback */
	u_int		u_flags;	/* Generic UDP flags. */
	uint16_t	u_rxcslen;	/* Coverage for incoming datagrams. */
	uint16_t	u_txcslen;	/* Coverage for outgoing datagrams. */
	void 		*u_tun_ctx;	/* Tunneling callback context. */
};

#define	intoudpcb(ip)	__containerof((inp), struct udpcb, u_inpcb)
#define	sotoudpcb(so)	(intoudpcb(sotoinpcb(so)))

VNET_PCPUSTAT_DECLARE(struct udpstat, udpstat);
/*
 * In-kernel consumers can use these accessor macros directly to update
 * stats.
 */
#define	UDPSTAT_ADD(name, val)  \
    VNET_PCPUSTAT_ADD(struct udpstat, udpstat, name, (val))
#define	UDPSTAT_INC(name)	UDPSTAT_ADD(name, 1)

/*
 * Kernel module consumers must use this accessor macro.
 */
void	kmod_udpstat_inc(int statnum);
#define	KMOD_UDPSTAT_INC(name)	\
    kmod_udpstat_inc(offsetof(struct udpstat, name) / sizeof(uint64_t))

SYSCTL_DECL(_net_inet_udp);

VNET_DECLARE(struct inpcbinfo, udbinfo);
VNET_DECLARE(struct inpcbinfo, ulitecbinfo);
#define	V_udbinfo		VNET(udbinfo)
#define	V_ulitecbinfo		VNET(ulitecbinfo)

extern u_long			udp_sendspace;
extern u_long			udp_recvspace;
VNET_DECLARE(int, udp_cksum);
VNET_DECLARE(int, udp_blackhole);
VNET_DECLARE(bool, udp_blackhole_local);
VNET_DECLARE(int, udp_log_in_vain);
#define	V_udp_cksum		VNET(udp_cksum)
#define	V_udp_blackhole		VNET(udp_blackhole)
#define	V_udp_blackhole_local	VNET(udp_blackhole_local)
#define	V_udp_log_in_vain	VNET(udp_log_in_vain)

VNET_DECLARE(int, zero_checksum_port);
#define	V_zero_checksum_port	VNET(zero_checksum_port)

static __inline struct inpcbinfo *
udp_get_inpcbinfo(int protocol)
{
	return (protocol == IPPROTO_UDP) ? &V_udbinfo : &V_ulitecbinfo;
}

int		udp_ctloutput(struct socket *, struct sockopt *);
void		udplite_input(struct mbuf *, int);
struct inpcb	*udp_notify(struct inpcb *inp, int errno);
int		udp_shutdown(struct socket *so);

int		udp_set_kernel_tunneling(struct socket *so, udp_tun_func_t f,
		    udp_tun_icmp_t i, void *ctx);

#ifdef _SYS_PROTOSW_H_
pr_abort_t	udp_abort;
pr_disconnect_t	udp_disconnect;
pr_send_t	udp_send;
#endif

#endif /* _KERNEL */

#endif /* _NETINET_UDP_VAR_H_ */