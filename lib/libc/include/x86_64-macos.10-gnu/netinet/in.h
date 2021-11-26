/*
 * Copyright (c) 2000-2018 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1982, 1986, 1990, 1993
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)in.h	8.3 (Berkeley) 1/3/94
 * $FreeBSD: src/sys/netinet/in.h,v 1.48.2.2 2001/04/21 14:53:06 ume Exp $
 */

#ifndef _NETINET_IN_H_
#define _NETINET_IN_H_
#include <sys/appleapiopts.h>
#include <sys/_types.h>
#include <stdint.h>             /* uint(8|16|32)_t */

#include <Availability.h>

#include <sys/_types/_in_addr_t.h>

#include <sys/_types/_in_port_t.h>

/*
 * POSIX 1003.1-2003
 * "Inclusion of the <netinet/in.h> header may also make visible all
 *  symbols from <inttypes.h> and <sys/socket.h>".
 */
#include <sys/socket.h>

/*
 * The following two #includes insure htonl and family are defined
 */
#include <machine/endian.h>
#include <sys/_endian.h>

/*
 * Constants and structures defined by the internet system,
 * Per RFC 790, September 1981, and numerous additions.
 */

/*
 * Protocols (RFC 1700)
 */
#define IPPROTO_IP              0               /* dummy for IP */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define IPPROTO_HOPOPTS 0               /* IP6 hop-by-hop options */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define IPPROTO_ICMP            1               /* control message protocol */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define IPPROTO_IGMP            2               /* group mgmt protocol */
#define IPPROTO_GGP             3               /* gateway^2 (deprecated) */
#define IPPROTO_IPV4            4               /* IPv4 encapsulation */
#define IPPROTO_IPIP            IPPROTO_IPV4    /* for compatibility */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define IPPROTO_TCP             6               /* tcp */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define IPPROTO_ST              7               /* Stream protocol II */
#define IPPROTO_EGP             8               /* exterior gateway protocol */
#define IPPROTO_PIGP            9               /* private interior gateway */
#define IPPROTO_RCCMON          10              /* BBN RCC Monitoring */
#define IPPROTO_NVPII           11              /* network voice protocol*/
#define IPPROTO_PUP             12              /* pup */
#define IPPROTO_ARGUS           13              /* Argus */
#define IPPROTO_EMCON           14              /* EMCON */
#define IPPROTO_XNET            15              /* Cross Net Debugger */
#define IPPROTO_CHAOS           16              /* Chaos*/
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define IPPROTO_UDP             17              /* user datagram protocol */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define IPPROTO_MUX             18              /* Multiplexing */
#define IPPROTO_MEAS            19              /* DCN Measurement Subsystems */
#define IPPROTO_HMP             20              /* Host Monitoring */
#define IPPROTO_PRM             21              /* Packet Radio Measurement */
#define IPPROTO_IDP             22              /* xns idp */
#define IPPROTO_TRUNK1          23              /* Trunk-1 */
#define IPPROTO_TRUNK2          24              /* Trunk-2 */
#define IPPROTO_LEAF1           25              /* Leaf-1 */
#define IPPROTO_LEAF2           26              /* Leaf-2 */
#define IPPROTO_RDP             27              /* Reliable Data */
#define IPPROTO_IRTP            28              /* Reliable Transaction */
#define IPPROTO_TP              29              /* tp-4 w/ class negotiation */
#define IPPROTO_BLT             30              /* Bulk Data Transfer */
#define IPPROTO_NSP             31              /* Network Services */
#define IPPROTO_INP             32              /* Merit Internodal */
#define IPPROTO_SEP             33              /* Sequential Exchange */
#define IPPROTO_3PC             34              /* Third Party Connect */
#define IPPROTO_IDPR            35              /* InterDomain Policy Routing */
#define IPPROTO_XTP             36              /* XTP */
#define IPPROTO_DDP             37              /* Datagram Delivery */
#define IPPROTO_CMTP            38              /* Control Message Transport */
#define IPPROTO_TPXX            39              /* TP++ Transport */
#define IPPROTO_IL              40              /* IL transport protocol */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define         IPPROTO_IPV6            41              /* IP6 header */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define IPPROTO_SDRP            42              /* Source Demand Routing */
#define         IPPROTO_ROUTING 43              /* IP6 routing header */
#define         IPPROTO_FRAGMENT        44              /* IP6 fragmentation header */
#define IPPROTO_IDRP            45              /* InterDomain Routing*/
#define         IPPROTO_RSVP            46              /* resource reservation */
#define IPPROTO_GRE             47              /* General Routing Encap. */
#define IPPROTO_MHRP            48              /* Mobile Host Routing */
#define IPPROTO_BHA             49              /* BHA */
#define IPPROTO_ESP             50              /* IP6 Encap Sec. Payload */
#define IPPROTO_AH              51              /* IP6 Auth Header */
#define IPPROTO_INLSP           52              /* Integ. Net Layer Security */
#define IPPROTO_SWIPE           53              /* IP with encryption */
#define IPPROTO_NHRP            54              /* Next Hop Resolution */
/* 55-57: Unassigned */
#define IPPROTO_ICMPV6          58              /* ICMP6 */
#define IPPROTO_NONE            59              /* IP6 no next header */
#define IPPROTO_DSTOPTS         60              /* IP6 destination option */
#define IPPROTO_AHIP            61              /* any host internal protocol */
#define IPPROTO_CFTP            62              /* CFTP */
#define IPPROTO_HELLO           63              /* "hello" routing protocol */
#define IPPROTO_SATEXPAK        64              /* SATNET/Backroom EXPAK */
#define IPPROTO_KRYPTOLAN       65              /* Kryptolan */
#define IPPROTO_RVD             66              /* Remote Virtual Disk */
#define IPPROTO_IPPC            67              /* Pluribus Packet Core */
#define IPPROTO_ADFS            68              /* Any distributed FS */
#define IPPROTO_SATMON          69              /* Satnet Monitoring */
#define IPPROTO_VISA            70              /* VISA Protocol */
#define IPPROTO_IPCV            71              /* Packet Core Utility */
#define IPPROTO_CPNX            72              /* Comp. Prot. Net. Executive */
#define IPPROTO_CPHB            73              /* Comp. Prot. HeartBeat */
#define IPPROTO_WSN             74              /* Wang Span Network */
#define IPPROTO_PVP             75              /* Packet Video Protocol */
#define IPPROTO_BRSATMON        76              /* BackRoom SATNET Monitoring */
#define IPPROTO_ND              77              /* Sun net disk proto (temp.) */
#define IPPROTO_WBMON           78              /* WIDEBAND Monitoring */
#define IPPROTO_WBEXPAK         79              /* WIDEBAND EXPAK */
#define IPPROTO_EON             80              /* ISO cnlp */
#define IPPROTO_VMTP            81              /* VMTP */
#define IPPROTO_SVMTP           82              /* Secure VMTP */
#define IPPROTO_VINES           83              /* Banyon VINES */
#define IPPROTO_TTP             84              /* TTP */
#define IPPROTO_IGP             85              /* NSFNET-IGP */
#define IPPROTO_DGP             86              /* dissimilar gateway prot. */
#define IPPROTO_TCF             87              /* TCF */
#define IPPROTO_IGRP            88              /* Cisco/GXS IGRP */
#define IPPROTO_OSPFIGP         89              /* OSPFIGP */
#define IPPROTO_SRPC            90              /* Strite RPC protocol */
#define IPPROTO_LARP            91              /* Locus Address Resoloution */
#define IPPROTO_MTP             92              /* Multicast Transport */
#define IPPROTO_AX25            93              /* AX.25 Frames */
#define IPPROTO_IPEIP           94              /* IP encapsulated in IP */
#define IPPROTO_MICP            95              /* Mobile Int.ing control */
#define IPPROTO_SCCSP           96              /* Semaphore Comm. security */
#define IPPROTO_ETHERIP         97              /* Ethernet IP encapsulation */
#define IPPROTO_ENCAP           98              /* encapsulation header */
#define IPPROTO_APES            99              /* any private encr. scheme */
#define IPPROTO_GMTP            100             /* GMTP*/
/* 101-252: Partly Unassigned */
#define IPPROTO_PIM             103             /* Protocol Independent Mcast */
#define IPPROTO_IPCOMP          108             /* payload compression (IPComp) */
#define IPPROTO_PGM             113             /* PGM */
#define IPPROTO_SCTP            132             /* SCTP */
/* 253-254: Experimentation and testing; 255: Reserved (RFC3692) */
/* BSD Private, local use, namespace incursion */
#define IPPROTO_DIVERT          254             /* divert pseudo-protocol */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define IPPROTO_RAW             255             /* raw IP packet */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define IPPROTO_MAX             256

/* last return value of *_input(), meaning "all job for this pkt is done".  */
#define IPPROTO_DONE            257
#endif /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */

/*
 * Local port number conventions:
 *
 * When a user does a bind(2) or connect(2) with a port number of zero,
 * a non-conflicting local port address is chosen.
 * The default range is IPPORT_RESERVED through
 * IPPORT_USERRESERVED, although that is settable by sysctl.
 *
 * A user may set the IPPROTO_IP option IP_PORTRANGE to change this
 * default assignment range.
 *
 * The value IP_PORTRANGE_DEFAULT causes the default behavior.
 *
 * The value IP_PORTRANGE_HIGH changes the range of candidate port numbers
 * into the "high" range.  These are reserved for client outbound connections
 * which do not want to be filtered by any firewalls.
 *
 * The value IP_PORTRANGE_LOW changes the range to the "low" are
 * that is (by convention) restricted to privileged processes.  This
 * convention is based on "vouchsafe" principles only.  It is only secure
 * if you trust the remote host to restrict these ports.
 *
 * The default range of ports and the high range can be changed by
 * sysctl(3).  (net.inet.ip.port{hi,low}{first,last}_auto)
 *
 * Changing those values has bad security implications if you are
 * using a a stateless firewall that is allowing packets outside of that
 * range in order to allow transparent outgoing connections.
 *
 * Such a firewall configuration will generally depend on the use of these
 * default values.  If you change them, you may find your Security
 * Administrator looking for you with a heavy object.
 *
 * For a slightly more orthodox text view on this:
 *
 *            ftp://ftp.isi.edu/in-notes/iana/assignments/port-numbers
 *
 *    port numbers are divided into three ranges:
 *
 *                0 -  1023 Well Known Ports
 *             1024 - 49151 Registered Ports
 *            49152 - 65535 Dynamic and/or Private Ports
 *
 */

#define __DARWIN_IPPORT_RESERVED        1024

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * Ports < IPPORT_RESERVED are reserved for
 * privileged processes (e.g. root).         (IP_PORTRANGE_LOW)
 * Ports > IPPORT_USERRESERVED are reserved
 * for servers, not necessarily privileged.  (IP_PORTRANGE_DEFAULT)
 */
#ifndef IPPORT_RESERVED
#define IPPORT_RESERVED         __DARWIN_IPPORT_RESERVED
#endif
#define IPPORT_USERRESERVED     5000

/*
 * Default local port range to use by setting IP_PORTRANGE_HIGH
 */
#define IPPORT_HIFIRSTAUTO      49152
#define IPPORT_HILASTAUTO       65535

/*
 * Scanning for a free reserved port return a value below IPPORT_RESERVED,
 * but higher than IPPORT_RESERVEDSTART.  Traditionally the start value was
 * 512, but that conflicts with some well-known-services that firewalls may
 * have a fit if we use.
 */
#define IPPORT_RESERVEDSTART    600
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * Internet address (a structure for historical reasons)
 */
struct in_addr {
	in_addr_t s_addr;
};

/*
 * Definitions of bits in internet address integers.
 * On subnets, the decomposition of addresses to host and net parts
 * is done according to subnet mask, not the masks here.
 */
#define INADDR_ANY              (u_int32_t)0x00000000
#define INADDR_BROADCAST        (u_int32_t)0xffffffff   /* must be masked */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define IN_CLASSA(i)            (((u_int32_t)(i) & 0x80000000) == 0)
#define IN_CLASSA_NET           0xff000000
#define IN_CLASSA_NSHIFT        24
#define IN_CLASSA_HOST          0x00ffffff
#define IN_CLASSA_MAX           128

#define IN_CLASSB(i)            (((u_int32_t)(i) & 0xc0000000) == 0x80000000)
#define IN_CLASSB_NET           0xffff0000
#define IN_CLASSB_NSHIFT        16
#define IN_CLASSB_HOST          0x0000ffff
#define IN_CLASSB_MAX           65536

#define IN_CLASSC(i)            (((u_int32_t)(i) & 0xe0000000) == 0xc0000000)
#define IN_CLASSC_NET           0xffffff00
#define IN_CLASSC_NSHIFT        8
#define IN_CLASSC_HOST          0x000000ff

#define IN_CLASSD(i)            (((u_int32_t)(i) & 0xf0000000) == 0xe0000000)
#define IN_CLASSD_NET           0xf0000000      /* These ones aren't really */
#define IN_CLASSD_NSHIFT        28              /* net and host fields, but */
#define IN_CLASSD_HOST          0x0fffffff      /* routing needn't know.    */
#define IN_MULTICAST(i)         IN_CLASSD(i)

#define IN_EXPERIMENTAL(i)      (((u_int32_t)(i) & 0xf0000000) == 0xf0000000)
#define IN_BADCLASS(i)          (((u_int32_t)(i) & 0xf0000000) == 0xf0000000)

#define INADDR_LOOPBACK         (u_int32_t)0x7f000001

#define INADDR_NONE             0xffffffff              /* -1 return */

#define INADDR_UNSPEC_GROUP     (u_int32_t)0xe0000000   /* 224.0.0.0 */
#define INADDR_ALLHOSTS_GROUP   (u_int32_t)0xe0000001   /* 224.0.0.1 */
#define INADDR_ALLRTRS_GROUP    (u_int32_t)0xe0000002   /* 224.0.0.2 */
#define INADDR_ALLRPTS_GROUP    (u_int32_t)0xe0000016   /* 224.0.0.22, IGMPv3 */
#define INADDR_CARP_GROUP       (u_int32_t)0xe0000012   /* 224.0.0.18 */
#define INADDR_PFSYNC_GROUP     (u_int32_t)0xe00000f0   /* 224.0.0.240 */
#define INADDR_ALLMDNS_GROUP    (u_int32_t)0xe00000fb   /* 224.0.0.251 */
#define INADDR_MAX_LOCAL_GROUP  (u_int32_t)0xe00000ff   /* 224.0.0.255 */

#ifdef __APPLE__
#define IN_LINKLOCALNETNUM      (u_int32_t)0xA9FE0000 /* 169.254.0.0 */
#define IN_LINKLOCAL(i)         (((u_int32_t)(i) & IN_CLASSB_NET) == IN_LINKLOCALNETNUM)
#define IN_LOOPBACK(i)          (((u_int32_t)(i) & 0xff000000) == 0x7f000000)
#define IN_ZERONET(i)           (((u_int32_t)(i) & 0xff000000) == 0)

#define IN_PRIVATE(i)   ((((u_int32_t)(i) & 0xff000000) == 0x0a000000) || \
	                 (((u_int32_t)(i) & 0xfff00000) == 0xac100000) || \
	                 (((u_int32_t)(i) & 0xffff0000) == 0xc0a80000))


#define IN_LOCAL_GROUP(i)       (((u_int32_t)(i) & 0xffffff00) == 0xe0000000)

#define IN_ANY_LOCAL(i)         (IN_LINKLOCAL(i) || IN_LOCAL_GROUP(i))
#endif /* __APPLE__ */

#define IN_LOOPBACKNET          127                     /* official! */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * Socket address, internet style.
 */
struct sockaddr_in {
	__uint8_t       sin_len;
	sa_family_t     sin_family;
	in_port_t       sin_port;
	struct  in_addr sin_addr;
	char            sin_zero[8];
};

#define IN_ARE_ADDR_EQUAL(a, b) \
    (bcmp(&(a)->s_addr, &(b)->s_addr, \
	sizeof (struct in_addr)) == 0)


#define INET_ADDRSTRLEN                 16

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * Structure used to describe IP options.
 * Used to store options internally, to pass them to a process,
 * or to restore options retrieved earlier.
 * The ip_dst is used for the first-hop gateway when using a source route
 * (this gets put into the header proper).
 */
struct ip_opts {
	struct  in_addr ip_dst;         /* first hop, 0 w/o src rt */
	char    ip_opts[40];            /* actually variable in size */
};

/*
 * Options for use with [gs]etsockopt at the IP level.
 * First word of comment is data type; bool is stored in int.
 */
#define IP_OPTIONS              1    /* buf/ip_opts; set/get IP options */
#define IP_HDRINCL              2    /* int; header is included with data */
#define IP_TOS                  3    /* int; IP type of service and preced. */
#define IP_TTL                  4    /* int; IP time to live */
#define IP_RECVOPTS             5    /* bool; receive all IP opts w/dgram */
#define IP_RECVRETOPTS          6    /* bool; receive IP opts for response */
#define IP_RECVDSTADDR          7    /* bool; receive IP dst addr w/dgram */
#define IP_RETOPTS              8    /* ip_opts; set/get IP options */
#define IP_MULTICAST_IF         9    /* u_char; set/get IP multicast i/f  */
#define IP_MULTICAST_TTL        10   /* u_char; set/get IP multicast ttl */
#define IP_MULTICAST_LOOP       11   /* u_char; set/get IP multicast loopback */
#define IP_ADD_MEMBERSHIP       12   /* ip_mreq; add an IP group membership */
#define IP_DROP_MEMBERSHIP      13   /* ip_mreq; drop an IP group membership */
#define IP_MULTICAST_VIF        14   /* set/get IP mcast virt. iface */
#define IP_RSVP_ON              15   /* enable RSVP in kernel */
#define IP_RSVP_OFF             16   /* disable RSVP in kernel */
#define IP_RSVP_VIF_ON          17   /* set RSVP per-vif socket */
#define IP_RSVP_VIF_OFF         18   /* unset RSVP per-vif socket */
#define IP_PORTRANGE            19   /* int; range to choose for unspec port */
#define IP_RECVIF               20   /* bool; receive reception if w/dgram */
/* for IPSEC */
#define IP_IPSEC_POLICY         21   /* int; set/get security policy */
#define IP_FAITH                22   /* deprecated */
#ifdef __APPLE__
#define IP_STRIPHDR             23   /* bool: drop receive of raw IP header */
#endif
#define IP_RECVTTL              24   /* bool; receive reception TTL w/dgram */
#define IP_BOUND_IF             25   /* int; set/get bound interface */
#define IP_PKTINFO              26   /* get pktinfo on recv socket, set src on sent dgram  */
#define IP_RECVPKTINFO          IP_PKTINFO      /* receive pktinfo w/dgram */
#define IP_RECVTOS              27   /* bool; receive IP TOS w/dgram */

#define IP_FW_ADD               40   /* add a firewall rule to chain */
#define IP_FW_DEL               41   /* delete a firewall rule from chain */
#define IP_FW_FLUSH             42   /* flush firewall rule chain */
#define IP_FW_ZERO              43   /* clear single/all firewall counter(s) */
#define IP_FW_GET               44   /* get entire firewall rule chain */
#define IP_FW_RESETLOG          45   /* reset logging counters */

/* These older firewall socket option codes are maintained for backward compatibility. */
#define IP_OLD_FW_ADD           50   /* add a firewall rule to chain */
#define IP_OLD_FW_DEL           51   /* delete a firewall rule from chain */
#define IP_OLD_FW_FLUSH         52   /* flush firewall rule chain */
#define IP_OLD_FW_ZERO          53   /* clear single/all firewall counter(s) */
#define IP_OLD_FW_GET           54   /* get entire firewall rule chain */
#define IP_NAT__XXX                     55   /* set/get NAT opts XXX Deprecated, do not use */
#define IP_OLD_FW_RESETLOG      56   /* reset logging counters */

#define IP_DUMMYNET_CONFIGURE   60   /* add/configure a dummynet pipe */
#define IP_DUMMYNET_DEL         61   /* delete a dummynet pipe from chain */
#define IP_DUMMYNET_FLUSH       62   /* flush dummynet */
#define IP_DUMMYNET_GET         64   /* get entire dummynet pipes */

#define IP_TRAFFIC_MGT_BACKGROUND       65   /* int*; get background IO flags; set background IO */
#define IP_MULTICAST_IFINDEX    66   /* int*; set/get IP multicast i/f index */

/* IPv4 Source Filter Multicast API [RFC3678] */
#define IP_ADD_SOURCE_MEMBERSHIP        70   /* join a source-specific group */
#define IP_DROP_SOURCE_MEMBERSHIP       71   /* drop a single source */
#define IP_BLOCK_SOURCE                 72   /* block a source */
#define IP_UNBLOCK_SOURCE               73   /* unblock a source */

/* The following option is private; do not use it from user applications. */
#define IP_MSFILTER                     74   /* set/get filter list */

/* Protocol Independent Multicast API [RFC3678] */
#define MCAST_JOIN_GROUP                80   /* join an any-source group */
#define MCAST_LEAVE_GROUP               81   /* leave all sources for group */
#define MCAST_JOIN_SOURCE_GROUP         82   /* join a source-specific group */
#define MCAST_LEAVE_SOURCE_GROUP        83   /* leave a single source */
#define MCAST_BLOCK_SOURCE              84   /* block a source */
#define MCAST_UNBLOCK_SOURCE            85   /* unblock a source */


/*
 * Defaults and limits for options
 */
#define IP_DEFAULT_MULTICAST_TTL  1     /* normally limit m'casts to 1 hop  */
#define IP_DEFAULT_MULTICAST_LOOP 1     /* normally hear sends if a member  */

/*
 * The imo_membership vector for each socket is now dynamically allocated at
 * run-time, bounded by USHRT_MAX, and is reallocated when needed, sized
 * according to a power-of-two increment.
 */
#define IP_MIN_MEMBERSHIPS      31
#define IP_MAX_MEMBERSHIPS      4095

/*
 * Default resource limits for IPv4 multicast source filtering.
 * These may be modified by sysctl.
 */
#define IP_MAX_GROUP_SRC_FILTER         512     /* sources per group */
#define IP_MAX_SOCK_SRC_FILTER          128     /* sources per socket/group */
#define IP_MAX_SOCK_MUTE_FILTER         128     /* XXX no longer used */

/*
 * Argument structure for IP_ADD_MEMBERSHIP and IP_DROP_MEMBERSHIP.
 */
struct ip_mreq {
	struct  in_addr imr_multiaddr;  /* IP multicast address of group */
	struct  in_addr imr_interface;  /* local IP address of interface */
};

/*
 * Modified argument structure for IP_MULTICAST_IF, obtained from Linux.
 * This is used to specify an interface index for multicast sends, as
 * the IPv4 legacy APIs do not support this (unless IP_SENDIF is available).
 */
struct ip_mreqn {
	struct  in_addr imr_multiaddr;  /* IP multicast address of group */
	struct  in_addr imr_address;    /* local IP address of interface */
	int             imr_ifindex;    /* Interface index; cast to uint32_t */
};

#pragma pack(4)
/*
 * Argument structure for IPv4 Multicast Source Filter APIs. [RFC3678]
 */
struct ip_mreq_source {
	struct  in_addr imr_multiaddr;  /* IP multicast address of group */
	struct  in_addr imr_sourceaddr; /* IP address of source */
	struct  in_addr imr_interface;  /* local IP address of interface */
};

/*
 * Argument structures for Protocol-Independent Multicast Source
 * Filter APIs. [RFC3678]
 */
struct group_req {
	uint32_t                gr_interface;   /* interface index */
	struct sockaddr_storage gr_group;       /* group address */
};

struct group_source_req {
	uint32_t                gsr_interface;  /* interface index */
	struct sockaddr_storage gsr_group;      /* group address */
	struct sockaddr_storage gsr_source;     /* source address */
};

#ifndef __MSFILTERREQ_DEFINED
#define __MSFILTERREQ_DEFINED
/*
 * The following structure is private; do not use it from user applications.
 * It is used to communicate IP_MSFILTER/IPV6_MSFILTER information between
 * the RFC 3678 libc functions and the kernel.
 */
struct __msfilterreq {
	uint32_t                 msfr_ifindex;  /* interface index */
	uint32_t                 msfr_fmode;    /* filter mode for group */
	uint32_t                 msfr_nsrcs;    /* # of sources in msfr_srcs */
	uint32_t                __msfr_align;
	struct sockaddr_storage  msfr_group;    /* group address */
	struct sockaddr_storage *msfr_srcs;
};

#endif /* __MSFILTERREQ_DEFINED */

#pragma pack()
struct sockaddr;

/*
 * Advanced (Full-state) APIs [RFC3678]
 * The RFC specifies uint_t for the 6th argument to [sg]etsourcefilter().
 * We use uint32_t here to be consistent.
 */
int     setipv4sourcefilter(int, struct in_addr, struct in_addr, uint32_t,
    uint32_t, struct in_addr *) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
int     getipv4sourcefilter(int, struct in_addr, struct in_addr, uint32_t *,
    uint32_t *, struct in_addr *) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
int     setsourcefilter(int, uint32_t, struct sockaddr *, socklen_t,
    uint32_t, uint32_t, struct sockaddr_storage *) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
int     getsourcefilter(int, uint32_t, struct sockaddr *, socklen_t,
    uint32_t *, uint32_t *, struct sockaddr_storage *) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);

/*
 * Filter modes; also used to represent per-socket filter mode internally.
 */
#define MCAST_UNDEFINED 0       /* fmode: not yet defined */
#define MCAST_INCLUDE   1       /* fmode: include these source(s) */
#define MCAST_EXCLUDE   2       /* fmode: exclude these source(s) */

/*
 * Argument for IP_PORTRANGE:
 * - which range to search when port is unspecified at bind() or connect()
 */
#define IP_PORTRANGE_DEFAULT    0       /* default range */
#define IP_PORTRANGE_HIGH       1       /* "high" - request firewall bypass */
#define IP_PORTRANGE_LOW        2       /* "low" - vouchsafe security */


/*
 * IP_PKTINFO: Packet information (equivalent to  RFC2292 sec 5 for IPv4)
 * This structure is used for
 *
 * 1) Receiving ancilliary data about the datagram if IP_PKTINFO sockopt is
 *    set on the socket. In this case ipi_ifindex will contain the interface
 *    index the datagram was received on, ipi_addr is the IP address the
 *    datagram was received to.
 *
 * 2) Sending a datagram using a specific interface or IP source address.
 *    if ipi_ifindex is set to non-zero when in_pktinfo is passed as
 *    ancilliary data of type IP_PKTINFO, this will be used as the source
 *    interface to send the datagram from. If ipi_ifindex is null, ip_spec_dst
 *    will be used for the source address.
 *
 *    Note: if IP_BOUND_IF is set on the socket, ipi_ifindex in the ancillary
 *    IP_PKTINFO option silently overrides the bound interface when it is
 *    specified during send time.
 */
struct in_pktinfo {
	unsigned int    ipi_ifindex;    /* send/recv interface index */
	struct in_addr  ipi_spec_dst;   /* Local address */
	struct in_addr  ipi_addr;       /* IP Header dst address */
};

/*
 * Definitions for inet sysctl operations.
 *
 * Third level is protocol number.
 * Fourth level is desired variable within that protocol.
 */
#define IPPROTO_MAXID   (IPPROTO_AH + 1)        /* don't list to IPPROTO_MAX */


/*
 * Names for IP sysctl objects
 */
#define IPCTL_FORWARDING        1       /* act as router */
#define IPCTL_SENDREDIRECTS     2       /* may send redirects when forwarding */
#define IPCTL_DEFTTL            3       /* default TTL */
#ifdef notyet
#define IPCTL_DEFMTU            4       /* default MTU */
#endif
#define IPCTL_RTEXPIRE          5       /* cloned route expiration time */
#define IPCTL_RTMINEXPIRE       6       /* min value for expiration time */
#define IPCTL_RTMAXCACHE        7       /* trigger level for dynamic expire */
#define IPCTL_SOURCEROUTE       8       /* may perform source routes */
#define IPCTL_DIRECTEDBROADCAST 9       /* may re-broadcast received packets */
#define IPCTL_INTRQMAXLEN       10      /* max length of netisr queue */
#define IPCTL_INTRQDROPS        11      /* number of netisr q drops */
#define IPCTL_STATS             12      /* ipstat structure */
#define IPCTL_ACCEPTSOURCEROUTE 13      /* may accept source routed packets */
#define IPCTL_FASTFORWARDING    14      /* use fast IP forwarding code */
#define IPCTL_KEEPFAITH         15      /* deprecated */
#define IPCTL_GIF_TTL           16      /* default TTL for gif encap packet */
#define IPCTL_MAXID             17

#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/* INET6 stuff */
#define __KAME_NETINET_IN_H_INCLUDED_
#include <netinet6/in6.h>
#undef __KAME_NETINET_IN_H_INCLUDED_



#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
__BEGIN_DECLS
int        bindresvport(int, struct sockaddr_in *);
struct sockaddr;
int        bindresvport_sa(int, struct sockaddr *);
__END_DECLS
#endif
#endif /* _NETINET_IN_H_ */