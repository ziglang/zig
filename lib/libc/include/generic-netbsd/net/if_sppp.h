/*	$NetBSD: if_sppp.h,v 1.36 2021/05/14 08:41:25 yamaguchi Exp $	*/

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

#ifndef _NET_IF_SPPP_H_
#define _NET_IF_SPPP_H_

/* ioctls used by the if_spppsubr.c driver */

#include <sys/ioccom.h>


#define	SPPP_AUTHPROTO_NONE	0
#define SPPP_AUTHPROTO_PAP	1
#define SPPP_AUTHPROTO_CHAP	2
#define SPPP_AUTHPROTO_NOCHG	3

#define SPPP_AUTHFLAG_NOCALLOUT		1	/* do not require authentication on */
						/* callouts */
#define SPPP_AUTHFLAG_NORECHALLENGE	2	/* do not re-challenge CHAP */
#define SPPP_AUTHFLAG_PASSIVEAUTHPROTO	4	/* use authproto proposed by peer */

struct spppauthcfg {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	u_int	hisauth;		/* one of SPPP_AUTHPROTO_* above */
	u_int	myauth;			/* one of SPPP_AUTHPROTO_* above */
	u_int	myname_length;		/* includes terminating 0 */
	u_int	mysecret_length;	/* includes terminating 0 */
	u_int	hisname_length;		/* includes terminating 0 */
	u_int	hissecret_length;	/* includes terminating 0 */
	u_int	myauthflags;
	u_int	hisauthflags;
	char	*myname;
	char	*mysecret;
	char	*hisname;
	char	*hissecret;
};

#define	SPPPGETAUTHCFG	_IOWR('i', 120, struct spppauthcfg)
#define	SPPPSETAUTHCFG	_IOW('i', 121, struct spppauthcfg)

struct sppplcpcfg {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	int	lcp_timeout;		/* LCP timeout, in ticks */
};

#define	SPPPGETLCPCFG	_IOWR('i', 122, struct sppplcpcfg)
#define	SPPPSETLCPCFG	_IOW('i', 123, struct sppplcpcfg)

/*
 * Don't change the order of this.  Ordering the phases this way allows
 * for a comparison of ``pp_phase >= PHASE_AUTHENTICATE'' in order to
 * know whether LCP is up.
 */
#define	SPPP_PHASE_DEAD		0
#define	SPPP_PHASE_ESTABLISH	1
#define	SPPP_PHASE_TERMINATE	2
#define	SPPP_PHASE_AUTHENTICATE	3
#define	SPPP_PHASE_NETWORK	4

struct spppstatus {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	int	phase;			/* one of SPPP_PHASE_* above */
};

#define	SPPPGETSTATUS	_IOWR('i', 124, struct spppstatus)

struct spppstatusncp {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	int	phase;			/* one of SPPP_PHASE_* above */
	int	ncpup;			/* != 0 if at least on NCP is up */
};

#define	SPPPGETSTATUSNCP	_IOWR('i', 134, struct spppstatusncp)

struct spppidletimeout {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	time_t	idle_seconds;		/* number of seconds idle before
					 * disconnect, 0 to disable idle-timeout */
};

struct spppidletimeout50 {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	uint32_t idle_seconds;		/* number of seconds idle before
					 * disconnect, 0 to disable idle-timeout */
};

#define	SPPPGETIDLETO	_IOWR('i', 125, struct spppidletimeout)
#define	SPPPSETIDLETO	_IOW('i', 126, struct spppidletimeout)
#define	__SPPPGETIDLETO50	_IOWR('i', 125, struct spppidletimeout50)
#define	__SPPPSETIDLETO50	_IOW('i', 126, struct spppidletimeout50)

struct spppauthfailurestats {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	int	auth_failures;		/* number of LCP failures since last successful TLU */
	int	max_failures;		/* max. allowed authorization failures */
};

#define	SPPPGETAUTHFAILURES	_IOWR('i', 127, struct spppauthfailurestats)

struct spppauthfailuresettings {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	int	max_failures;		/* max. allowed authorization failures */
};
#define	SPPPSETAUTHFAILURE	_IOW('i', 128, struct spppauthfailuresettings)

/* set the DNS options we would like to query during PPP negotiation */
struct spppdnssettings {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	int	query_dns;		/* bitmask (bits 0 and 1) for DNS options to query in IPCP */
};
#define	SPPPSETDNSOPTS		_IOW('i', 129, struct spppdnssettings)
#define	SPPPGETDNSOPTS		_IOWR('i', 130, struct spppdnssettings)

/* get the DNS addresses we received from the peer */
struct spppdnsaddrs {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	uint32_t dns[2];		/* IP addresses */
};

#define SPPPGETDNSADDRS		_IOWR('i', 131, struct spppdnsaddrs)

/* set LCP keepalive/timeout options */
struct spppkeepalivesettings {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	u_int	maxalive;		/* number of LCP echo req. w/o reply */
	time_t	max_noreceive;		/* (sec.) grace period before we start
					   sending LCP echo requests. */
	u_int	alive_interval;		/* number of keepalive between echo req. */
};
struct spppkeepalivesettings50 {
	char	ifname[IFNAMSIZ];	/* pppoe interface name */
	u_int	maxalive;		/* number of LCP echo req. w/o reply */
	uint32_t max_noreceive;		/* (sec.) grace period before we start
					   sending LCP echo requests. */
};
#define	SPPPSETKEEPALIVE	_IOW('i', 132, struct spppkeepalivesettings)
#define	SPPPGETKEEPALIVE	_IOWR('i', 133, struct spppkeepalivesettings)
#define	__SPPPSETKEEPALIVE50	_IOW('i', 132, struct spppkeepalivesettings50)
#define	__SPPPGETKEEPALIVE50	_IOWR('i', 133, struct spppkeepalivesettings50)

/* 134 already used! */

/* states are named and numbered according to RFC 1661 */
#define SPPP_STATE_INITIAL	0
#define SPPP_STATE_STARTING	1
#define SPPP_STATE_CLOSED	2
#define SPPP_STATE_STOPPED	3
#define SPPP_STATE_CLOSING	4
#define SPPP_STATE_STOPPING	5
#define SPPP_STATE_REQ_SENT	6
#define SPPP_STATE_ACK_RCVD	7
#define SPPP_STATE_ACK_SENT	8
#define SPPP_STATE_OPENED	9

#define SPPP_LCP_OPT_MRU		__BIT(1)
#define SPPP_LCP_OPT_ASYNC_MAP		__BIT(2)
#define SPPP_LCP_OPT_AUTH_PROTO		__BIT(3)
#define SPPP_LCP_OPT_QUAL_PROTO		__BIT(4)
#define SPPP_LCP_OPT_MAGIC		__BIT(5)
#define SPPP_LCP_OPT_RESERVED		__BIT(6)
#define SPPP_LCP_OPT_PROTO_COMP		__BIT(7)
#define SPPP_LCP_OPT_ADDR_COMP		__BIT(8)
#define SPPP_LCP_OPT_FCS_ALTS		__BIT(9)
#define SPPP_LCP_OPT_SELF_DESC_PAD	__BIT(10)
#define SPPP_LCP_OPT_CALL_BACK		__BIT(13)
#define SPPP_LCP_OPT_COMPOUND_FRMS	__BIT(15)
#define SPPP_LCP_OPT_MP_MRRU		__BIT(17)
#define SPPP_LCP_OPT_MP_SSNHF		__BIT(18)
#define SPPP_LCP_OPT_MP_EID		__BIT(19)

/* #define SPPP_OPT_ADDRESSES	__BIT(0) */
#define SPPP_IPCP_OPT_COMPRESSION	__BIT(1)
#define SPPP_IPCP_OPT_ADDRESS		__BIT(2)
#define SPPP_IPCP_OPT_PRIMDNS		__BIT(3)
#define SPPP_IPCP_OPT_SECDNS		__BIT(4)

#define SPPP_IPV6CP_OPT_IFID		__BIT(1)
#define SPPP_IPV6CP_OPT_COMPRESSION	__BIT(2)

struct sppplcpstatus {
	char	ifname[IFNAMSIZ];
	int	state;
	int	timeout;
	u_long	opts;
	u_long	magic;
	u_long	mru;
};

#define SPPPGETLCPSTATUS	_IOWR('i', 135, struct sppplcpstatus)

struct spppipcpstatus {
	char		ifname[IFNAMSIZ];
	int		state;
	u_long		opts;
	u_int32_t	myaddr;
};

#define SPPPGETIPCPSTATUS	_IOWR('i', 136, struct spppipcpstatus)

struct spppipv6cpstatus {
	char		ifname[IFNAMSIZ];
	int		state;
	u_long		opts;
	u_int8_t	my_ifid[8];
	u_int8_t	his_ifid[8];
};

#define SPPPGETIPV6CPSTATUS	_IOWR('i', 137, struct spppipv6cpstatus)

#define SPPP_NCP_IPCP		__BIT(0)
#define SPPP_NCP_IPV6CP		__BIT(1)
struct spppncpcfg {
	char		ifname[IFNAMSIZ];
	u_int		ncp_flags;
};

#define SPPPGETNCPCFG		_IOWR('i', 138, struct spppncpcfg)
#define SPPPSETNCPCFG		_IOW('i', 139, struct spppncpcfg)

#endif /* !_NET_IF_SPPP_H_ */