/*	$NetBSD: ip_icmp.h,v 1.44 2022/05/24 20:50:20 andvar Exp $	*/

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
 *	@(#)ip_icmp.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NETINET_IP_ICMP_H_
#define _NETINET_IP_ICMP_H_

/*
 * Interface Control Message Protocol Definitions.
 * Per RFC 792, September 1981.
 */

/*
 * Internal of an ICMP Router Advertisement
 */
struct icmp_ra_addr {
	uint32_t ira_addr;
	uint32_t ira_preference;
};

/*
 * Structure of an icmp header.
 */
struct icmp {
	uint8_t  icmp_type;		/* type of message, see below */
	uint8_t  icmp_code;		/* type sub code */
	uint16_t icmp_cksum;		/* ones complement cksum of struct */

	union {
		int32_t ih_void;

		/* Extended Header (RFC4884) */
		struct ih_exthdr {
			uint8_t iex_void1;
			uint8_t iex_length;
			uint16_t iex_void2;
		} ih_exthdr;

		/* ICMP_PARAMPROB */
		uint8_t ih_pptr;

		/* ICMP_REDIRECT */
		struct in_addr ih_gwaddr;

		/* ICMP_ECHO and friends */
		struct ih_idseq {
			uint16_t icd_id;
			uint16_t icd_seq;
		} ih_idseq;

		/* ICMP_UNREACH_NEEDFRAG (Path MTU Discovery, RFC1191) */
		struct ih_pmtu {
			uint16_t ipm_void;
			uint16_t ipm_nextmtu;
		} ih_pmtu;

		/* ICMP_ROUTERADVERT */
		struct ih_rtradv {
			uint8_t irt_num_addrs;
			uint8_t irt_wpa;
			uint16_t irt_lifetime;
		} ih_rtradv;
	} icmp_hun;

#define icmp_pptr	icmp_hun.ih_pptr
#define icmp_gwaddr	icmp_hun.ih_gwaddr
#define icmp_id		icmp_hun.ih_idseq.icd_id
#define icmp_seq	icmp_hun.ih_idseq.icd_seq
#define icmp_void	icmp_hun.ih_void
#define icmp_pmvoid	icmp_hun.ih_pmtu.ipm_void
#define icmp_nextmtu	icmp_hun.ih_pmtu.ipm_nextmtu
#define icmp_num_addrs	icmp_hun.ih_rtradv.irt_num_addrs
#define icmp_wpa	icmp_hun.ih_rtradv.irt_wpa
#define icmp_lifetime	icmp_hun.ih_rtradv.irt_lifetime

	union {
		/* ICMP_TSTAMP and friends */
		struct id_ts {
			uint32_t its_otime;
			uint32_t its_rtime;
			uint32_t its_ttime;
		} id_ts;

		struct id_ip {
			struct ip idi_ip;
			/* options and then 64 bits of data */
		} id_ip;

		/* ICMP_ROUTERADVERT */
		struct icmp_ra_addr id_radv;

		/* ICMP_MASKREQ and friends */
		uint32_t id_mask;

		int8_t id_data[1];
	} icmp_dun;

#define icmp_otime	icmp_dun.id_ts.its_otime
#define icmp_rtime	icmp_dun.id_ts.its_rtime
#define icmp_ttime	icmp_dun.id_ts.its_ttime
#define icmp_ip		icmp_dun.id_ip.idi_ip
#define icmp_radv	icmp_dun.id_radv
#define icmp_mask	icmp_dun.id_mask
#define icmp_data	icmp_dun.id_data
};

#define ICMP_EXT_VERSION	2
#define ICMP_EXT_OFFSET		128

/*
 * ICMP Extension Structure Header (RFC4884).
 */
struct icmp_ext_hdr {
#if BYTE_ORDER == BIG_ENDIAN
	uint8_t version:4;
	uint8_t rsvd1:4;
#else
	uint8_t rsvd1:4;
	uint8_t version:4;
#endif
	uint8_t rsvd2;
	uint16_t checksum;
};

/*
 * ICMP Extension Object Header (RFC4884).
 */
struct icmp_ext_obj_hdr {
	uint16_t length;
	uint8_t class_num;
	uint8_t c_type;
};

#ifdef __CTASSERT
__CTASSERT(sizeof(struct icmp_ra_addr) == 8);
__CTASSERT(sizeof(struct icmp) == 28);
__CTASSERT(sizeof(struct icmp_ext_hdr) == 4);
__CTASSERT(sizeof(struct icmp_ext_obj_hdr) == 4);
#endif

/*
 * Lower bounds on packet lengths for various types.
 * For the error advice packets must first insure that the
 * packet is large enough to contain the returned ip header.
 * Only then can we do the check to see if 64 bits of packet
 * data have been returned, since we need to check the returned
 * ip header length.
 */
#define ICMP_MINLEN	8				/* abs minimum */
#define ICMP_TSLEN	(8 + 3 * sizeof(uint32_t))	/* timestamp */
#define ICMP_MASKLEN	12				/* address mask */
#define ICMP_ADVLENMIN	(8 + sizeof(struct ip) + 8)	/* min */
#define ICMP_ADVLEN(p)	(8 + ((p)->icmp_ip.ip_hl << 2) + 8)
	/* N.B.: must separately check that ip_hl >= 5 */

/*
 * Definition of type and code field values.
 */
#define ICMP_ECHOREPLY		0		/* echo reply */
#define ICMP_UNREACH		3		/* dest unreachable, codes: */
#define		ICMP_UNREACH_NET	0		/* bad net */
#define		ICMP_UNREACH_HOST	1		/* bad host */
#define		ICMP_UNREACH_PROTOCOL	2		/* bad protocol */
#define		ICMP_UNREACH_PORT	3		/* bad port */
#define		ICMP_UNREACH_NEEDFRAG	4		/* IP_DF caused drop */
#define		ICMP_UNREACH_SRCFAIL	5		/* src route failed */
#define		ICMP_UNREACH_NET_UNKNOWN 6		/* unknown net */
#define		ICMP_UNREACH_HOST_UNKNOWN 7		/* unknown host */
#define		ICMP_UNREACH_ISOLATED	8		/* src host isolated */
#define		ICMP_UNREACH_NET_PROHIB 9		/* prohibited access */
#define		ICMP_UNREACH_HOST_PROHIB 10		/* ditto */
#define		ICMP_UNREACH_TOSNET	11		/* bad tos for net */
#define		ICMP_UNREACH_TOSHOST	12		/* bad tos for host */
#define		ICMP_UNREACH_ADMIN_PROHIBIT 13		/* communication
							   administratively
							   prohibited */
#define		ICMP_UNREACH_HOST_PREC	14		/* host precedence
							   violation */
#define		ICMP_UNREACH_PREC_CUTOFF 15		/* precedence cutoff */
#define ICMP_SOURCEQUENCH	4		/* packet lost, slow down */
#define ICMP_REDIRECT		5		/* shorter route, codes: */
#define		ICMP_REDIRECT_NET	0		/* for network */
#define		ICMP_REDIRECT_HOST	1		/* for host */
#define		ICMP_REDIRECT_TOSNET	2		/* for tos and net */
#define		ICMP_REDIRECT_TOSHOST	3		/* for tos and host */
#define ICMP_ALTHOSTADDR	6		/* alternative host address */
#define ICMP_ECHO		8		/* echo service */
#define ICMP_ROUTERADVERT	9		/* router advertisement */
#define		ICMP_ROUTERADVERT_NORMAL 0
#define		ICMP_ROUTERADVERT_NOROUTE 16
#define ICMP_ROUTERSOLICIT	10		/* router solicitation */
#define ICMP_TIMXCEED		11		/* time exceeded, code: */
#define		ICMP_TIMXCEED_INTRANS	0		/* ttl==0 in transit */
#define		ICMP_TIMXCEED_REASS	1		/* ttl==0 in reass */
#define ICMP_PARAMPROB		12		/* ip header bad */
#define		ICMP_PARAMPROB_ERRATPTR 0
#define		ICMP_PARAMPROB_OPTABSENT 1
#define		ICMP_PARAMPROB_LENGTH	2
#define ICMP_TSTAMP		13		/* timestamp request */
#define ICMP_TSTAMPREPLY	14		/* timestamp reply */
#define ICMP_IREQ		15		/* information request */
#define ICMP_IREQREPLY		16		/* information reply */
#define ICMP_MASKREQ		17		/* address mask request */
#define ICMP_MASKREPLY		18		/* address mask reply */
#define ICMP_TRACEROUTE		30		/* traceroute */
#define ICMP_DATACONVERR	31		/* data conversion error */
#define ICMP_MOBILE_REDIRECT	32		/* mobile redirect */
#define ICMP_IPV6_WHEREAREYOU	33		/* ipv6 where are you */
#define ICMP_IPV6_IAMHERE	34		/* ipv6 i am here */
#define ICMP_MOBILE_REGREQUEST	35		/* mobile registration req */
#define ICMP_MOBILE_REGREPLY	36		/* mobile registration reply */
#define ICMP_SKIP		39		/* SKIP */
#define ICMP_PHOTURIS		40		/* security */
#define		ICMP_PHOTURIS_UNKNOWN_INDEX	0	/* unknown sec index */
#define		ICMP_PHOTURIS_AUTH_FAILED	1	/* auth failed */
#define		ICMP_PHOTURIS_DECOMPRESS_FAILED 2	/* decompress failed */
#define		ICMP_PHOTURIS_DECRYPT_FAILED	3	/* decrypt failed */
#define		ICMP_PHOTURIS_NEED_AUTHN	4	/* no authentication */
#define		ICMP_PHOTURIS_NEED_AUTHZ	5	/* no authorization */

#define ICMP_MAXTYPE		40
#define ICMP_NTYPES		(ICMP_MAXTYPE + 1)

#ifdef ICMP_STRINGS
static const char *icmp_type[] = {
	"echoreply", "unassigned_1", "unassigned_2", "unreach",
	"sourcequench", "redirect", "althostaddr", "unassigned_7",
	"echo", "routeradvert", "routersolicit", "timxceed",
	"paramprob", "tstamp", "tstampreply", "ireq",
	"ireqreply", "maskreq", "maskreply", "reserved_19",
	"reserved_20", "reserved_21", "reserved_22", "reserved_23",
	"reserved_24", "reserved_25", "reserved_26", "reserved_27",
	"reserved_28", "reserved_29", "traceroute", "dataconverr",
	"mobile_redirect", "ipv6_whereareyou", "ipv6_iamhere",
	"mobile_regrequest", "mobile_regreply", "reserved_37",
	"reserved_38", "skip", "photuris", NULL
};
static const char *icmp_code_none[] = { "none", NULL };
static const char *icmp_code_unreach[] = {
	"net", "host", "oprt", "needfrag", "srcfail", "net_unknown",
	"host_unknown", "isolated", "net_prohib", "host_prohib",
	"tosnet", "toshost", "admin_prohibit", "host_prec", "prec_cutoff", NULL
};
static const char *icmp_code_redirect[] = {
	"net", "host", "tosnet", "toshost", NULL
};
static const char *icmp_code_routeradvert[] = {
	"normal", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
	"noroute", NULL
};
static const char *icmp_code_timxceed[] = {
	"intrans", "reass", NULL
};
static const char *icmp_code_paramprob[] = {
	"erratptr", "optabsent", "length", NULL
};
static const char *icmp_code_photuris[] = {
	"unknown_index", "auth_failed", "decompress_failed",
	"decrypt_failed", "need_authn", "need_authz", NULL
};
#endif

#define ICMP_INFOTYPE(type) \
	((type) == ICMP_ECHOREPLY || (type) == ICMP_ECHO || \
	(type) == ICMP_ROUTERADVERT || (type) == ICMP_ROUTERSOLICIT || \
	(type) == ICMP_TSTAMP || (type) == ICMP_TSTAMPREPLY || \
	(type) == ICMP_IREQ || (type) == ICMP_IREQREPLY || \
	(type) == ICMP_MASKREQ || (type) == ICMP_MASKREPLY)

#ifdef _KERNEL
void icmp_error(struct mbuf *, int, int, n_long, int);
void icmp_mtudisc(struct icmp *, struct in_addr);
void icmp_input(struct mbuf *, int, int);
void icmp_init(void);
void icmp_reflect(struct mbuf *);

void icmp_mtudisc_callback_register(void (*)(struct in_addr));
int icmp_ratelimit(const struct in_addr *, const int, const int);
void icmp_mtudisc_lock(void);
void icmp_mtudisc_unlock(void);
#endif

#endif /* !_NETINET_IP_ICMP_H_ */