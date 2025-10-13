/*	$NetBSD: ip_carp.h,v 1.14 2021/02/03 18:13:13 roy Exp $	*/
/*	$OpenBSD: ip_carp.h,v 1.18 2005/04/20 23:00:41 mpf Exp $	*/

/*
 * Copyright (c) 2002 Michael Shalayeff. All rights reserved.
 * Copyright (c) 2003 Ryan McBride. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR OR HIS RELATIVES BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF MIND, USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _NETINET_IP_CARP_H_
#define _NETINET_IP_CARP_H_

/*
 * The CARP header layout is as follows:
 *
 *     0                   1                   2                   3
 *     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |Version| Type  | VirtualHostID |    AdvSkew    |    Auth Len   |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |   Reserved    |     AdvBase   |          Checksum             |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |                         Counter (1)                           |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |                         Counter (2)                           |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |                        SHA-1 HMAC (1)                         |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |                        SHA-1 HMAC (2)                         |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |                        SHA-1 HMAC (3)                         |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |                        SHA-1 HMAC (4)                         |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *    |                        SHA-1 HMAC (5)                         |
 *    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *
 */

struct carp_header {
#if BYTE_ORDER == LITTLE_ENDIAN
	unsigned int	carp_type:4,
			carp_version:4;
#endif
#if BYTE_ORDER == BIG_ENDIAN
	unsigned int	carp_version:4,
			carp_type:4;
#endif
	u_int8_t	carp_vhid;	/* virtual host id */
	u_int8_t	carp_advskew;	/* advertisement skew */
	u_int8_t	carp_authlen;   /* size of counter+md, 32bit chunks */
	u_int8_t	carp_pad1;	/* reserved */
	u_int8_t	carp_advbase;	/* advertisement interval */
	u_int16_t	carp_cksum;
	u_int32_t	carp_counter[2];
	unsigned char	carp_md[20];	/* SHA1 HMAC */
};

#ifdef __CTASSERT
__CTASSERT(sizeof(struct carp_header) == 36);
#endif

#define	CARP_DFLTTL		255

/* carp_version */
#define	CARP_VERSION		2

/* carp_type */
#define	CARP_ADVERTISEMENT	0x01

#define	CARP_KEY_LEN		20	/* a sha1 hash of a passphrase */

/* carp_advbase */
#define	CARP_DFLTINTV		1

/*
 * Statistics.
 */
#define	CARP_STAT_IPACKETS	0	/* total input packets, IPv4 */
#define	CARP_STAT_IPACKETS6	1	/* total input packets, IPv6 */
#define	CARP_STAT_BADIF		2	/* wrong interface */
#define	CARP_STAT_BADTTL	3	/* TTL is not CARP_DFLTTL */
#define	CARP_STAT_HDROPS	4	/* packets shorter than hdr */
#define	CARP_STAT_BADSUM	5	/* bad checksum */
#define	CARP_STAT_BADVER	6	/* bad (incl unsupported) version */
#define	CARP_STAT_BADLEN	7	/* data length does not match */
#define	CARP_STAT_BADAUTH	8	/* bad authentication */
#define	CARP_STAT_BADVHID	9	/* bad VHID */
#define	CARP_STAT_BADADDRS	10	/* bad address list */
#define	CARP_STAT_OPACKETS	11	/* total output packets, IPv4 */
#define	CARP_STAT_OPACKETS6	12	/* total output packets, IPv6 */
#define	CARP_STAT_ONOMEM	13	/* no memory for an mbuf */
#define	CARP_STAT_OSTATES	14	/* total state updates sent */
#define	CARP_STAT_PREEMPT	15	/* in enabled, preemptions */

#define	CARP_NSTATS		16

#define CARPDEVNAMSIZ	16
#ifdef IFNAMSIZ
#if CARPDEVNAMSIZ != IFNAMSIZ
#error
#endif
#endif

/*
 * Configuration structure for SIOCSVH SIOCGVH
 */
struct carpreq {
	int		carpr_state;
#define	CARP_STATES	"INIT", "BACKUP", "MASTER"
#define	CARP_MAXSTATE	2

	char		carpr_carpdev[CARPDEVNAMSIZ];
	int		carpr_vhid;
	int		carpr_advskew;
	int		carpr_advbase;
	unsigned char	carpr_key[CARP_KEY_LEN];
};

/*
 * Names for CARP sysctl objects
 */
#define	CARPCTL_ALLOW		1	/* accept incoming CARP packets */
#define	CARPCTL_PREEMPT		2	/* high-pri backup preemption mode */
#define	CARPCTL_LOG		3	/* log bad packets */
#define	CARPCTL_ARPBALANCE	4	/* balance arp responses */
#define CARPCTL_STATS		5	/* carp statistics */
#define	CARPCTL_MAXID		6

#ifdef _KERNEL
void		 carp_init(void);
void		 carp_ifdetach(struct ifnet *);
void		 carp_proto_input(struct mbuf *, int, int);
void		 carp_carpdev_state(void *);
int		 carp6_proto_input(struct mbuf **, int *, int);
int		 carp_iamatch(struct in_ifaddr *, u_char *,
		     u_int32_t *, u_int32_t);
struct ifaddr	*carp_iamatch6(void *, struct in6_addr *);
struct ifnet	*carp_ourether(void *, struct ether_header *, u_char, int);
int		 carp_input(struct mbuf *, u_int8_t *, u_int8_t *, u_int16_t);
int		 carp_output(struct ifnet *, struct mbuf *,
		     const struct sockaddr *, const struct rtentry *);
#endif /* _KERNEL */
#endif /* _NETINET_IP_CARP_H_ */