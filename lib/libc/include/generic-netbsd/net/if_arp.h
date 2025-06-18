/*	$NetBSD: if_arp.h,v 1.43 2021/02/19 14:51:59 christos Exp $	*/

/*
 * Copyright (c) 1986, 1993
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
 *	@(#)if_arp.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NET_IF_ARP_H_
#define _NET_IF_ARP_H_
/*
 * Address Resolution Protocol.
 *
 * See RFC 826 for protocol description.  ARP packets are variable
 * in size; the arphdr structure defines the fixed-length portion.
 * Protocol type values are the same as those for 10 Mb/s Ethernet.
 * It is followed by the variable-sized fields ar_sha, arp_spa,
 * arp_tha and arp_tpa in that order, according to the lengths
 * specified.  Field names used correspond to RFC 826.
 */
struct	arphdr {
	uint16_t ar_hrd;	/* format of hardware address */
#define ARPHRD_ETHER		1  /* ethernet hardware format */
#define ARPHRD_IEEE802		6  /* IEEE 802 hardware format */
#define ARPHRD_ARCNET		7  /* ethernet hardware format */
#define ARPHRD_FRELAY		15 /* frame relay hardware format */
#define ARPHRD_STRIP		23 /* Ricochet Starmode Radio hardware format */
#define	ARPHRD_IEEE1394		24 /* IEEE 1394 (FireWire) hardware format */
	uint16_t ar_pro;	   /* format of protocol address */
	uint8_t  ar_hln;	   /* length of hardware address */
	uint8_t  ar_pln;	   /* length of protocol address */
	uint16_t ar_op;		   /* one of: */
#define	ARPOP_REQUEST		1  /* request to resolve address */
#define	ARPOP_REPLY		2  /* response to previous request */
#define	ARPOP_REVREQUEST	3  /* request protocol address given hardware */
#define	ARPOP_REVREPLY		4  /* response giving protocol address */
#define	ARPOP_INVREQUEST	8  /* request to identify peer */
#define	ARPOP_INVREPLY		9  /* response identifying peer */
/*
 * The remaining fields are variable in size,
 * according to the sizes above.
 */
#ifdef COMMENT_ONLY
	uint8_t  ar_sha[];	/* sender hardware address */
	uint8_t  ar_spa[];	/* sender protocol address */
	uint8_t  ar_tha[];	/* target hardware address (!IEEE1394) */
	uint8_t  ar_tpa[];	/* target protocol address */
#endif
};

static __inline uint8_t *
ar_data(struct arphdr *ap)
{
	return (uint8_t *)(void *)(ap + 1);
}

static __inline uint8_t *
ar_sha(struct arphdr *ap)
{
	return ar_data(ap) + 0;
}

static __inline uint8_t *
ar_spa(struct arphdr *ap)
{
	return ar_data(ap) + ap->ar_hln;
}

static __inline uint8_t *
ar_tha(struct arphdr *ap)
{
	if (ntohs(ap->ar_hrd) == ARPHRD_IEEE1394) {
		return NULL;
	} else {
		return ar_data(ap) + ap->ar_hln + ap->ar_pln;
	}
}

static __inline uint8_t *
ar_tpa(struct arphdr *ap)
{
	if (ntohs(ap->ar_hrd) == ARPHRD_IEEE1394) {
		return ar_data(ap) + ap->ar_hln + ap->ar_pln;
	} else {
		return ar_data(ap) + ap->ar_hln + ap->ar_pln + ap->ar_hln;
	}
}

/*
 * ARP ioctl request
 */
struct arpreq {
	struct	sockaddr arp_pa;		/* protocol address */
	struct	sockaddr arp_ha;		/* hardware address */
	int	arp_flags;			/* flags */
};
/*  arp_flags and at_flags field values */
#define	ATF_INUSE	0x01	/* entry in use */
#define ATF_COM		0x02	/* completed entry (enaddr valid) */
#define	ATF_PERM	0x04	/* permanent entry */
#define	ATF_PUBL	0x08	/* publish entry (respond for other host) */
#define	ATF_USETRAILERS	0x10	/* has requested trailers */

/*
 * Kernel statistics about arp
 */
#define	ARP_STAT_SNDTOTAL	0	/* total packets sent */
#define	ARP_STAT_SNDREPLY	1	/* replies sent */
#define	ARP_STAT_SENDREQUEST	2	/* requests sent */
#define	ARP_STAT_RCVTOTAL	3	/* total packets received */
#define	ARP_STAT_RCVREQUEST	4	/* valid requests received */
#define	ARP_STAT_RCVREPLY	5	/* replies received */
#define	ARP_STAT_RCVMCAST	6	/* multicast/broadcast received */
#define	ARP_STAT_RCVBADPROTO	7	/* unknown protocol type received */
#define	ARP_STAT_RCVBADLEN	8	/* bad (short) length received */
#define	ARP_STAT_RCVZEROTPA	9	/* received w/ null target ip */
#define	ARP_STAT_RCVZEROSPA	10	/* received w/ null source ip */
#define	ARP_STAT_RCVNOINT	11	/* couldn't map to interface */
#define	ARP_STAT_RCVLOCALSHA	12	/* received from local hw address */
#define	ARP_STAT_RCVBCASTSHA	13	/* received w/ broadcast src */
#define	ARP_STAT_RCVLOCALSPA	14	/* received for a local ip [dup!] */
#define	ARP_STAT_RCVOVERPERM	15	/* attempts to overwrite static info */
#define	ARP_STAT_RCVOVERINT	16	/* attempts to overwrite wrong if */
#define	ARP_STAT_RCVOVER	17	/* entries overwritten! */
#define	ARP_STAT_RCVLENCHG	18	/* changes in hw address len */
#define	ARP_STAT_DFRTOTAL	19	/* deferred pending ARP resolution */
#define	ARP_STAT_DFRSENT	20	/* deferred, then sent */
#define	ARP_STAT_DFRDROPPED	21	/* deferred, then dropped */
#define	ARP_STAT_ALLOCFAIL	22	/* failures to allocate llinfo */

#define	ARP_NSTATS		23

void arp_stat_add(int, uint64_t);

#endif /* !_NET_IF_ARP_H_ */