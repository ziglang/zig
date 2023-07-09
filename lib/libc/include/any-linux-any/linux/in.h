/* SPDX-License-Identifier: GPL-2.0+ WITH Linux-syscall-note */
/*
 * INET		An implementation of the TCP/IP protocol suite for the LINUX
 *		operating system.  INET is implemented using the  BSD Socket
 *		interface as the means of communication with the user level.
 *
 *		Definitions of the Internet Protocol.
 *
 * Version:	@(#)in.h	1.0.1	04/21/93
 *
 * Authors:	Original taken from the GNU Project <netinet/in.h> file.
 *		Fred N. van Kempen, <waltje@uWalt.NL.Mugnet.ORG>
 *
 *		This program is free software; you can redistribute it and/or
 *		modify it under the terms of the GNU General Public License
 *		as published by the Free Software Foundation; either version
 *		2 of the License, or (at your option) any later version.
 */
#ifndef _LINUX_IN_H
#define _LINUX_IN_H

#include <linux/types.h>
#include <linux/stddef.h>
#include <linux/libc-compat.h>
#include <linux/socket.h>

#if __UAPI_DEF_IN_IPPROTO
/* Standard well-defined IP protocols.  */
enum {
  IPPROTO_IP = 0,		/* Dummy protocol for TCP		*/
#define IPPROTO_IP		IPPROTO_IP
  IPPROTO_ICMP = 1,		/* Internet Control Message Protocol	*/
#define IPPROTO_ICMP		IPPROTO_ICMP
  IPPROTO_IGMP = 2,		/* Internet Group Management Protocol	*/
#define IPPROTO_IGMP		IPPROTO_IGMP
  IPPROTO_IPIP = 4,		/* IPIP tunnels (older KA9Q tunnels use 94) */
#define IPPROTO_IPIP		IPPROTO_IPIP
  IPPROTO_TCP = 6,		/* Transmission Control Protocol	*/
#define IPPROTO_TCP		IPPROTO_TCP
  IPPROTO_EGP = 8,		/* Exterior Gateway Protocol		*/
#define IPPROTO_EGP		IPPROTO_EGP
  IPPROTO_PUP = 12,		/* PUP protocol				*/
#define IPPROTO_PUP		IPPROTO_PUP
  IPPROTO_UDP = 17,		/* User Datagram Protocol		*/
#define IPPROTO_UDP		IPPROTO_UDP
  IPPROTO_IDP = 22,		/* XNS IDP protocol			*/
#define IPPROTO_IDP		IPPROTO_IDP
  IPPROTO_TP = 29,		/* SO Transport Protocol Class 4	*/
#define IPPROTO_TP		IPPROTO_TP
  IPPROTO_DCCP = 33,		/* Datagram Congestion Control Protocol */
#define IPPROTO_DCCP		IPPROTO_DCCP
  IPPROTO_IPV6 = 41,		/* IPv6-in-IPv4 tunnelling		*/
#define IPPROTO_IPV6		IPPROTO_IPV6
  IPPROTO_RSVP = 46,		/* RSVP Protocol			*/
#define IPPROTO_RSVP		IPPROTO_RSVP
  IPPROTO_GRE = 47,		/* Cisco GRE tunnels (rfc 1701,1702)	*/
#define IPPROTO_GRE		IPPROTO_GRE
  IPPROTO_ESP = 50,		/* Encapsulation Security Payload protocol */
#define IPPROTO_ESP		IPPROTO_ESP
  IPPROTO_AH = 51,		/* Authentication Header protocol	*/
#define IPPROTO_AH		IPPROTO_AH
  IPPROTO_MTP = 92,		/* Multicast Transport Protocol		*/
#define IPPROTO_MTP		IPPROTO_MTP
  IPPROTO_BEETPH = 94,		/* IP option pseudo header for BEET	*/
#define IPPROTO_BEETPH		IPPROTO_BEETPH
  IPPROTO_ENCAP = 98,		/* Encapsulation Header			*/
#define IPPROTO_ENCAP		IPPROTO_ENCAP
  IPPROTO_PIM = 103,		/* Protocol Independent Multicast	*/
#define IPPROTO_PIM		IPPROTO_PIM
  IPPROTO_COMP = 108,		/* Compression Header Protocol		*/
#define IPPROTO_COMP		IPPROTO_COMP
  IPPROTO_L2TP = 115,		/* Layer 2 Tunnelling Protocol		*/
#define IPPROTO_L2TP		IPPROTO_L2TP
  IPPROTO_SCTP = 132,		/* Stream Control Transport Protocol	*/
#define IPPROTO_SCTP		IPPROTO_SCTP
  IPPROTO_UDPLITE = 136,	/* UDP-Lite (RFC 3828)			*/
#define IPPROTO_UDPLITE		IPPROTO_UDPLITE
  IPPROTO_MPLS = 137,		/* MPLS in IP (RFC 4023)		*/
#define IPPROTO_MPLS		IPPROTO_MPLS
  IPPROTO_ETHERNET = 143,	/* Ethernet-within-IPv6 Encapsulation	*/
#define IPPROTO_ETHERNET	IPPROTO_ETHERNET
  IPPROTO_RAW = 255,		/* Raw IP packets			*/
#define IPPROTO_RAW		IPPROTO_RAW
  IPPROTO_MPTCP = 262,		/* Multipath TCP connection		*/
#define IPPROTO_MPTCP		IPPROTO_MPTCP
  IPPROTO_MAX
};
#endif

#if __UAPI_DEF_IN_ADDR
/* Internet address. */
struct in_addr {
	__be32	s_addr;
};
#endif

#define IP_TOS		1
#define IP_TTL		2
#define IP_HDRINCL	3
#define IP_OPTIONS	4
#define IP_ROUTER_ALERT	5
#define IP_RECVOPTS	6
#define IP_RETOPTS	7
#define IP_PKTINFO	8
#define IP_PKTOPTIONS	9
#define IP_MTU_DISCOVER	10
#define IP_RECVERR	11
#define IP_RECVTTL	12
#define	IP_RECVTOS	13
#define IP_MTU		14
#define IP_FREEBIND	15
#define IP_IPSEC_POLICY	16
#define IP_XFRM_POLICY	17
#define IP_PASSSEC	18
#define IP_TRANSPARENT	19

/* BSD compatibility */
#define IP_RECVRETOPTS	IP_RETOPTS

/* TProxy original addresses */
#define IP_ORIGDSTADDR       20
#define IP_RECVORIGDSTADDR   IP_ORIGDSTADDR

#define IP_MINTTL       21
#define IP_NODEFRAG     22
#define IP_CHECKSUM	23
#define IP_BIND_ADDRESS_NO_PORT	24
#define IP_RECVFRAGSIZE	25
#define IP_RECVERR_RFC4884	26

/* IP_MTU_DISCOVER values */
#define IP_PMTUDISC_DONT		0	/* Never send DF frames */
#define IP_PMTUDISC_WANT		1	/* Use per route hints	*/
#define IP_PMTUDISC_DO			2	/* Always DF		*/
#define IP_PMTUDISC_PROBE		3       /* Ignore dst pmtu      */
/* Always use interface mtu (ignores dst pmtu) but don't set DF flag.
 * Also incoming ICMP frag_needed notifications will be ignored on
 * this socket to prevent accepting spoofed ones.
 */
#define IP_PMTUDISC_INTERFACE		4
/* weaker version of IP_PMTUDISC_INTERFACE, which allows packets to get
 * fragmented if they exeed the interface mtu
 */
#define IP_PMTUDISC_OMIT		5

#define IP_MULTICAST_IF			32
#define IP_MULTICAST_TTL 		33
#define IP_MULTICAST_LOOP 		34
#define IP_ADD_MEMBERSHIP		35
#define IP_DROP_MEMBERSHIP		36
#define IP_UNBLOCK_SOURCE		37
#define IP_BLOCK_SOURCE			38
#define IP_ADD_SOURCE_MEMBERSHIP	39
#define IP_DROP_SOURCE_MEMBERSHIP	40
#define IP_MSFILTER			41
#define MCAST_JOIN_GROUP		42
#define MCAST_BLOCK_SOURCE		43
#define MCAST_UNBLOCK_SOURCE		44
#define MCAST_LEAVE_GROUP		45
#define MCAST_JOIN_SOURCE_GROUP		46
#define MCAST_LEAVE_SOURCE_GROUP	47
#define MCAST_MSFILTER			48
#define IP_MULTICAST_ALL		49
#define IP_UNICAST_IF			50
#define IP_LOCAL_PORT_RANGE		51
#define IP_PROTOCOL			52

#define MCAST_EXCLUDE	0
#define MCAST_INCLUDE	1

/* These need to appear somewhere around here */
#define IP_DEFAULT_MULTICAST_TTL        1
#define IP_DEFAULT_MULTICAST_LOOP       1

/* Request struct for multicast socket ops */

#if __UAPI_DEF_IP_MREQ
struct ip_mreq  {
	struct in_addr imr_multiaddr;	/* IP multicast address of group */
	struct in_addr imr_interface;	/* local IP address of interface */
};

struct ip_mreqn {
	struct in_addr	imr_multiaddr;		/* IP multicast address of group */
	struct in_addr	imr_address;		/* local IP address of interface */
	int		imr_ifindex;		/* Interface index */
};

struct ip_mreq_source {
	__be32		imr_multiaddr;
	__be32		imr_interface;
	__be32		imr_sourceaddr;
};

struct ip_msfilter {
	__be32		imsf_multiaddr;
	__be32		imsf_interface;
	__u32		imsf_fmode;
	__u32		imsf_numsrc;
	union {
		__be32		imsf_slist[1];
		__DECLARE_FLEX_ARRAY(__be32, imsf_slist_flex);
	};
};

#define IP_MSFILTER_SIZE(numsrc) \
	(sizeof(struct ip_msfilter) - sizeof(__u32) \
	+ (numsrc) * sizeof(__u32))

struct group_req {
	__u32				 gr_interface;	/* interface index */
	struct __kernel_sockaddr_storage gr_group;	/* group address */
};

struct group_source_req {
	__u32				 gsr_interface;	/* interface index */
	struct __kernel_sockaddr_storage gsr_group;	/* group address */
	struct __kernel_sockaddr_storage gsr_source;	/* source address */
};

struct group_filter {
	union {
		struct {
			__u32				 gf_interface_aux; /* interface index */
			struct __kernel_sockaddr_storage gf_group_aux;	   /* multicast address */
			__u32				 gf_fmode_aux;	   /* filter mode */
			__u32				 gf_numsrc_aux;	   /* number of sources */
			struct __kernel_sockaddr_storage gf_slist[1];	   /* interface index */
		};
		struct {
			__u32				 gf_interface;	  /* interface index */
			struct __kernel_sockaddr_storage gf_group;	  /* multicast address */
			__u32				 gf_fmode;	  /* filter mode */
			__u32				 gf_numsrc;	  /* number of sources */
			struct __kernel_sockaddr_storage gf_slist_flex[]; /* interface index */
		};
	};
};

#define GROUP_FILTER_SIZE(numsrc) \
	(sizeof(struct group_filter) - sizeof(struct __kernel_sockaddr_storage) \
	+ (numsrc) * sizeof(struct __kernel_sockaddr_storage))
#endif

#if __UAPI_DEF_IN_PKTINFO
struct in_pktinfo {
	int		ipi_ifindex;
	struct in_addr	ipi_spec_dst;
	struct in_addr	ipi_addr;
};
#endif

/* Structure describing an Internet (IP) socket address. */
#if  __UAPI_DEF_SOCKADDR_IN
#define __SOCK_SIZE__	16		/* sizeof(struct sockaddr)	*/
struct sockaddr_in {
  __kernel_sa_family_t	sin_family;	/* Address family		*/
  __be16		sin_port;	/* Port number			*/
  struct in_addr	sin_addr;	/* Internet address		*/

  /* Pad to size of `struct sockaddr'. */
  unsigned char		__pad[__SOCK_SIZE__ - sizeof(short int) -
			sizeof(unsigned short int) - sizeof(struct in_addr)];
};
#define sin_zero	__pad		/* for BSD UNIX comp. -FvK	*/
#endif

#if __UAPI_DEF_IN_CLASS
/*
 * Definitions of the bits in an Internet address integer.
 * On subnets, host and network parts are found according
 * to the subnet mask, not these masks.
 */
#define	IN_CLASSA(a)		((((long int) (a)) & 0x80000000) == 0)
#define	IN_CLASSA_NET		0xff000000
#define	IN_CLASSA_NSHIFT	24
#define	IN_CLASSA_HOST		(0xffffffff & ~IN_CLASSA_NET)
#define	IN_CLASSA_MAX		128

#define	IN_CLASSB(a)		((((long int) (a)) & 0xc0000000) == 0x80000000)
#define	IN_CLASSB_NET		0xffff0000
#define	IN_CLASSB_NSHIFT	16
#define	IN_CLASSB_HOST		(0xffffffff & ~IN_CLASSB_NET)
#define	IN_CLASSB_MAX		65536

#define	IN_CLASSC(a)		((((long int) (a)) & 0xe0000000) == 0xc0000000)
#define	IN_CLASSC_NET		0xffffff00
#define	IN_CLASSC_NSHIFT	8
#define	IN_CLASSC_HOST		(0xffffffff & ~IN_CLASSC_NET)

#define	IN_CLASSD(a)		((((long int) (a)) & 0xf0000000) == 0xe0000000)
#define	IN_MULTICAST(a)		IN_CLASSD(a)
#define	IN_MULTICAST_NET	0xe0000000

#define	IN_BADCLASS(a)		(((long int) (a) ) == (long int)0xffffffff)
#define	IN_EXPERIMENTAL(a)	IN_BADCLASS((a))

#define	IN_CLASSE(a)		((((long int) (a)) & 0xf0000000) == 0xf0000000)
#define	IN_CLASSE_NET		0xffffffff
#define	IN_CLASSE_NSHIFT	0

/* Address to accept any incoming messages. */
#define	INADDR_ANY		((unsigned long int) 0x00000000)

/* Address to send to all hosts. */
#define	INADDR_BROADCAST	((unsigned long int) 0xffffffff)

/* Address indicating an error return. */
#define	INADDR_NONE		((unsigned long int) 0xffffffff)

/* Dummy address for src of ICMP replies if no real address is set (RFC7600). */
#define	INADDR_DUMMY		((unsigned long int) 0xc0000008)

/* Network number for local host loopback. */
#define	IN_LOOPBACKNET		127

/* Address to loopback in software to local host.  */
#define	INADDR_LOOPBACK		0x7f000001	/* 127.0.0.1   */
#define	IN_LOOPBACK(a)		((((long int) (a)) & 0xff000000) == 0x7f000000)

/* Defines for Multicast INADDR */
#define INADDR_UNSPEC_GROUP		0xe0000000U	/* 224.0.0.0   */
#define INADDR_ALLHOSTS_GROUP		0xe0000001U	/* 224.0.0.1   */
#define INADDR_ALLRTRS_GROUP		0xe0000002U	/* 224.0.0.2 */
#define INADDR_ALLSNOOPERS_GROUP	0xe000006aU	/* 224.0.0.106 */
#define INADDR_MAX_LOCAL_GROUP		0xe00000ffU	/* 224.0.0.255 */
#endif

/* <asm/byteorder.h> contains the htonl type stuff.. */
#include <asm/byteorder.h> 


#endif /* _LINUX_IN_H */