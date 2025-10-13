/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * Copyright (c) 2014 Andrey V. Elsukov <ae@FreeBSD.org>
 * All rights reserved
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Heiko W.Rupp <hwr@pilhuhn.de>
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
 *
 * $NetBSD: if_gre.h,v 1.13 2003/11/10 08:51:52 wiz Exp $
 */

#ifndef _NET_IF_GRE_H_
#define _NET_IF_GRE_H_

#ifdef _KERNEL
/* GRE header according to RFC 2784 and RFC 2890 */
struct grehdr {
	uint16_t	gre_flags;	/* GRE flags */
#define	GRE_FLAGS_CP	0x8000		/* checksum present */
#define	GRE_FLAGS_KP	0x2000		/* key present */
#define	GRE_FLAGS_SP	0x1000		/* sequence present */
#define	GRE_FLAGS_MASK	(GRE_FLAGS_CP|GRE_FLAGS_KP|GRE_FLAGS_SP)
	uint16_t	gre_proto;	/* protocol type */
	uint32_t	gre_opts[0];	/* optional fields */
} __packed;

#ifdef INET
struct greip {
	struct ip	gi_ip;
	struct grehdr	gi_gre;
} __packed;

struct greudp {
	struct ip	gi_ip;
	struct udphdr	gi_udp;
	struct grehdr	gi_gre;
} __packed;
#endif /* INET */

#ifdef INET6
struct greip6 {
	struct ip6_hdr	gi6_ip6;
	struct grehdr	gi6_gre;
} __packed;

struct greudp6 {
	struct ip6_hdr	gi6_ip6;
	struct udphdr	gi6_udp;
	struct grehdr	gi6_gre;
} __packed;
#endif /* INET6 */

CK_LIST_HEAD(gre_list, gre_softc);
CK_LIST_HEAD(gre_sockets, gre_socket);
struct gre_socket {
	struct socket		*so;
	struct gre_list		list;
	CK_LIST_ENTRY(gre_socket) chain;
	struct epoch_context	epoch_ctx;
};

struct gre_softc {
	struct ifnet		*gre_ifp;
	int			gre_family;	/* AF of delivery header */
	uint32_t		gre_iseq;
	uint32_t		gre_oseq;
	uint32_t		gre_key;
	uint32_t		gre_options;
	uint32_t		gre_csumflags;
	uint32_t		gre_port;
	u_int			gre_fibnum;
	u_int			gre_hlen;	/* header size */
	union {
		void		*hdr;
#ifdef INET
		struct greip	*iphdr;
		struct greudp	*udphdr;
#endif
#ifdef INET6
		struct greip6	*ip6hdr;
		struct greudp6	*udp6hdr;
#endif
	} gre_uhdr;
	struct gre_socket	*gre_so;

	CK_LIST_ENTRY(gre_softc) chain;
	CK_LIST_ENTRY(gre_softc) srchash;
};
MALLOC_DECLARE(M_GRE);

#ifndef GRE_HASH_SIZE
#define	GRE_HASH_SIZE	(1 << 4)
#endif

#define	GRE2IFP(sc)		((sc)->gre_ifp)
#define	GRE_RLOCK_TRACKER	struct epoch_tracker gre_et
#define	GRE_RLOCK()		epoch_enter_preempt(net_epoch_preempt, &gre_et)
#define	GRE_RUNLOCK()		epoch_exit_preempt(net_epoch_preempt, &gre_et)
#define	GRE_WAIT()		epoch_wait_preempt(net_epoch_preempt)

#define	gre_hdr			gre_uhdr.hdr
#define	gre_iphdr		gre_uhdr.iphdr
#define	gre_ip6hdr		gre_uhdr.ip6hdr
#define	gre_udphdr		gre_uhdr.udphdr
#define	gre_udp6hdr		gre_uhdr.udp6hdr

#define	gre_oip			gre_iphdr->gi_ip
#define	gre_udp			gre_udphdr->gi_udp
#define	gre_oip6		gre_ip6hdr->gi6_ip6
#define	gre_udp6		gre_udp6hdr->gi6_udp

struct gre_list *gre_hashinit(void);
void gre_hashdestroy(struct gre_list *);

int	gre_input(struct mbuf *, int, int, void *);
void	gre_update_hdr(struct gre_softc *, struct grehdr *);
void	gre_update_udphdr(struct gre_softc *, struct udphdr *, uint16_t);
void	gre_sofree(epoch_context_t);

void	in_gre_init(void);
void	in_gre_uninit(void);
int	in_gre_setopts(struct gre_softc *, u_long, uint32_t);
int	in_gre_ioctl(struct gre_softc *, u_long, caddr_t);
int	in_gre_output(struct mbuf *, int, int);

void	in6_gre_init(void);
void	in6_gre_uninit(void);
int	in6_gre_setopts(struct gre_softc *, u_long, uint32_t);
int	in6_gre_ioctl(struct gre_softc *, u_long, caddr_t);
int	in6_gre_output(struct mbuf *, int, int, uint32_t);
/*
 * CISCO uses special type for GRE tunnel created as part of WCCP
 * connection, while in fact those packets are just IPv4 encapsulated
 * into GRE.
 */
#define ETHERTYPE_WCCP		0x883E
#endif /* _KERNEL */

#define GRESADDRS	_IOW('i', 101, struct ifreq)
#define GRESADDRD	_IOW('i', 102, struct ifreq)
#define GREGADDRS	_IOWR('i', 103, struct ifreq)
#define GREGADDRD	_IOWR('i', 104, struct ifreq)
#define GRESPROTO	_IOW('i' , 105, struct ifreq)
#define GREGPROTO	_IOWR('i', 106, struct ifreq)

#define	GREGKEY		_IOWR('i', 107, struct ifreq)
#define	GRESKEY		_IOW('i', 108, struct ifreq)
#define	GREGOPTS	_IOWR('i', 109, struct ifreq)
#define	GRESOPTS	_IOW('i', 110, struct ifreq)
#define	GREGPORT	_IOWR('i', 111, struct ifreq)
#define	GRESPORT	_IOW('i', 112, struct ifreq)

/* GRE-in-UDP encapsulation destination port as defined in RFC8086 */
#define	GRE_UDPPORT		4754

#define	GRE_ENABLE_CSUM		0x0001
#define	GRE_ENABLE_SEQ		0x0002
#define	GRE_UDPENCAP		0x0004
#define	GRE_OPTMASK		(GRE_ENABLE_CSUM|GRE_ENABLE_SEQ|GRE_UDPENCAP)

#endif /* _NET_IF_GRE_H_ */