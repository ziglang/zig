/*
 * Copyright (c) 2000-2019 Apple Inc. All rights reserved.
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
/* Copyright (c) 1998, 1999 Apple Computer, Inc. All Rights Reserved */
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1982, 1985, 1986, 1988, 1993, 1994
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
 *	@(#)socket.h	8.4 (Berkeley) 2/21/94
 * $FreeBSD: src/sys/sys/socket.h,v 1.39.2.7 2001/07/03 11:02:01 ume Exp $
 */
/*
 * NOTICE: This file was modified by SPARTA, Inc. in 2005 to introduce
 * support for mandatory and extensible security protections.  This notice
 * is included in support of clause 2.2 (b) of the Apple Public License,
 * Version 2.0.
 */

#ifndef _SYS_SOCKET_H_
#define _SYS_SOCKET_H_

#include <sys/types.h>
#include <sys/cdefs.h>
#include <machine/_param.h>
#include <net/net_kev.h>


#include <Availability.h>

/*
 * Definitions related to sockets: types, address families, options.
 */

/*
 * Data types.
 */

#include <sys/_types/_gid_t.h>
#include <sys/_types/_off_t.h>
#include <sys/_types/_pid_t.h>
#include <sys/_types/_sa_family_t.h>
#include <sys/_types/_socklen_t.h>

/* XXX Not explicitly defined by POSIX, but function return types are */
#include <sys/_types/_size_t.h>

/* XXX Not explicitly defined by POSIX, but function return types are */
#include <sys/_types/_ssize_t.h>

/*
 * [XSI] The iovec structure shall be defined as described in <sys/uio.h>.
 */
#include <sys/_types/_iovec_t.h>

/*
 * Types
 */
#define SOCK_STREAM     1               /* stream socket */
#define SOCK_DGRAM      2               /* datagram socket */
#define SOCK_RAW        3               /* raw-protocol interface */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define SOCK_RDM        4               /* reliably-delivered message */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define SOCK_SEQPACKET  5               /* sequenced packet stream */

/*
 * Option flags per-socket.
 */
#define SO_DEBUG        0x0001          /* turn on debugging info recording */
#define SO_ACCEPTCONN   0x0002          /* socket has had listen() */
#define SO_REUSEADDR    0x0004          /* allow local address reuse */
#define SO_KEEPALIVE    0x0008          /* keep connections alive */
#define SO_DONTROUTE    0x0010          /* just use interface addresses */
#define SO_BROADCAST    0x0020          /* permit sending of broadcast msgs */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define SO_USELOOPBACK  0x0040          /* bypass hardware when possible */
#define SO_LINGER       0x0080          /* linger on close if data present (in ticks) */
#else
#define SO_LINGER       0x1080          /* linger on close if data present (in seconds) */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define SO_OOBINLINE    0x0100          /* leave received OOB data in line */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define SO_REUSEPORT    0x0200          /* allow local address & port reuse */
#define SO_TIMESTAMP    0x0400          /* timestamp received dgram traffic */
#define SO_TIMESTAMP_MONOTONIC  0x0800  /* Monotonically increasing timestamp on rcvd dgram */
#ifndef __APPLE__
#define SO_ACCEPTFILTER 0x1000          /* there is an accept filter */
#else
#define SO_DONTTRUNC    0x2000          /* APPLE: Retain unread data */
                                        /*  (ATOMIC proto) */
#define SO_WANTMORE     0x4000          /* APPLE: Give hint when more data ready */
#define SO_WANTOOBFLAG  0x8000          /* APPLE: Want OOB in MSG_FLAG on receive */


#endif  /* (!__APPLE__) */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * Additional options, not kept in so_options.
 */
#define SO_SNDBUF       0x1001          /* send buffer size */
#define SO_RCVBUF       0x1002          /* receive buffer size */
#define SO_SNDLOWAT     0x1003          /* send low-water mark */
#define SO_RCVLOWAT     0x1004          /* receive low-water mark */
#define SO_SNDTIMEO     0x1005          /* send timeout */
#define SO_RCVTIMEO     0x1006          /* receive timeout */
#define SO_ERROR        0x1007          /* get error status and clear */
#define SO_TYPE         0x1008          /* get socket type */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define SO_LABEL        0x1010          /* socket's MAC label */
#define SO_PEERLABEL    0x1011          /* socket's peer MAC label */
#ifdef __APPLE__
#define SO_NREAD        0x1020          /* APPLE: get 1st-packet byte count */
#define SO_NKE          0x1021          /* APPLE: Install socket-level NKE */
#define SO_NOSIGPIPE    0x1022          /* APPLE: No SIGPIPE on EPIPE */
#define SO_NOADDRERR    0x1023          /* APPLE: Returns EADDRNOTAVAIL when src is not available anymore */
#define SO_NWRITE       0x1024          /* APPLE: Get number of bytes currently in send socket buffer */
#define SO_REUSESHAREUID        0x1025          /* APPLE: Allow reuse of port/socket by different userids */
#ifdef __APPLE_API_PRIVATE
#define SO_NOTIFYCONFLICT       0x1026  /* APPLE: send notification if there is a bind on a port which is already in use */
#define SO_UPCALLCLOSEWAIT      0x1027  /* APPLE: block on close until an upcall returns */
#endif
#define SO_LINGER_SEC   0x1080          /* linger on close if data present (in seconds) */
#define SO_RANDOMPORT   0x1082  /* APPLE: request local port randomization */
#define SO_NP_EXTENSIONS        0x1083  /* To turn off some POSIX behavior */
#endif

#define SO_NUMRCVPKT            0x1112  /* number of datagrams in receive socket buffer */
#define SO_NET_SERVICE_TYPE     0x1116  /* Network service type */


#define SO_NETSVC_MARKING_LEVEL 0x1119  /* Get QoS marking in effect for socket */

/*
 * Network Service Type for option SO_NET_SERVICE_TYPE
 *
 * The vast majority of sockets should use Best Effort that is the default
 * Network Service Type. Other Network Service Types have to be used only if
 * the traffic actually matches the description of the Network Service Type.
 *
 * Network Service Types do not represent priorities but rather describe
 * different categories of delay, jitter and loss parameters.
 * Those parameters may influence protocols from layer 4 protocols like TCP
 * to layer 2 protocols like Wi-Fi. The Network Service Type can determine
 * how the traffic is queued and scheduled by the host networking stack and
 * by other entities on the network like switches and routers. For example
 * for Wi-Fi, the Network Service Type can select the marking of the
 * layer 2 packet with the appropriate WMM Access Category.
 *
 * There is no point in attempting to game the system and use
 * a Network Service Type that does not correspond to the actual
 * traffic characteristic but one that seems to have a higher precedence.
 * The reason is that for service classes that have lower tolerance
 * for delay and jitter, the queues size is lower than for service
 * classes that are more tolerant to delay and jitter.
 *
 * For example using a voice service type for bulk data transfer will lead
 * to disastrous results as soon as congestion happens because the voice
 * queue overflows and packets get dropped. This is not only bad for the bulk
 * data transfer but it is also bad for VoIP apps that legitimately are using
 * the voice  service type.
 *
 * The characteristics of the Network Service Types are based on the service
 * classes defined in RFC 4594 "Configuration Guidelines for DiffServ Service
 * Classes"
 *
 * When system detects the outgoing interface belongs to a DiffServ domain
 * that follows the recommendation of the IETF draft "Guidelines for DiffServ to
 * IEEE 802.11 Mapping", the packet will marked at layer 3 with a DSCP value
 * that corresponds to Network Service Type.
 *
 * NET_SERVICE_TYPE_BE
 *	"Best Effort", unclassified/standard.  This is the default service
 *	class and cover the majority of the traffic.
 *
 * NET_SERVICE_TYPE_BK
 *	"Background", high delay tolerant, loss tolerant. elastic flow,
 *	variable size & long-lived. E.g: non-interactive network bulk transfer
 *	like synching or backup.
 *
 * NET_SERVICE_TYPE_RD
 *	"Responsive Data", a notch higher than "Best Effort", medium delay
 *	tolerant, elastic & inelastic flow, bursty, long-lived. E.g. email,
 *	instant messaging, for which there is a sense of interactivity and
 *	urgency (user waiting for output).
 *
 * NET_SERVICE_TYPE_OAM
 *	"Operations, Administration, and Management", medium delay tolerant,
 *	low-medium loss tolerant, elastic & inelastic flows, variable size.
 *	E.g. VPN tunnels.
 *
 * NET_SERVICE_TYPE_AV
 *	"Multimedia Audio/Video Streaming", medium delay tolerant, low-medium
 *	loss tolerant, elastic flow, constant packet interval, variable rate
 *	and size. E.g. video and audio playback with buffering.
 *
 * NET_SERVICE_TYPE_RV
 *	"Responsive Multimedia Audio/Video", low delay tolerant, low-medium
 *	loss tolerant, elastic flow, variable packet interval, rate and size.
 *	E.g. screen sharing.
 *
 * NET_SERVICE_TYPE_VI
 *	"Interactive Video", low delay tolerant, low-medium loss tolerant,
 *	elastic flow, constant packet interval, variable rate & size. E.g.
 *	video telephony.
 *
 * NET_SERVICE_TYPE_SIG
 *	"Signaling", low delay tolerant, low loss tolerant, inelastic flow,
 *	jitter tolerant, rate is bursty but short, variable size. E.g. SIP.
 *
 * NET_SERVICE_TYPE_VO
 *	"Interactive Voice", very low delay tolerant, very low loss tolerant,
 *	inelastic flow, constant packet rate, somewhat fixed size.
 *	E.g. VoIP.
 */

#define NET_SERVICE_TYPE_BE     0 /* Best effort */
#define NET_SERVICE_TYPE_BK     1 /* Background system initiated */
#define NET_SERVICE_TYPE_SIG    2 /* Signaling */
#define NET_SERVICE_TYPE_VI     3 /* Interactive Video */
#define NET_SERVICE_TYPE_VO     4 /* Interactive Voice */
#define NET_SERVICE_TYPE_RV     5 /* Responsive Multimedia Audio/Video */
#define NET_SERVICE_TYPE_AV     6 /* Multimedia Audio/Video Streaming */
#define NET_SERVICE_TYPE_OAM    7 /* Operations, Administration, and Management */
#define NET_SERVICE_TYPE_RD     8 /* Responsive Data */


/* These are supported values for SO_NETSVC_MARKING_LEVEL */
#define NETSVC_MRKNG_UNKNOWN            0       /* The outgoing network interface is not known */
#define NETSVC_MRKNG_LVL_L2             1       /* Default marking at layer 2 (for example Wi-Fi WMM) */
#define NETSVC_MRKNG_LVL_L3L2_ALL       2       /* Layer 3 DSCP marking and layer 2 marking for all Network Service Types */
#define NETSVC_MRKNG_LVL_L3L2_BK        3       /* The system policy limits layer 3 DSCP marking and layer 2 marking
	                                         * to background Network Service Types */


typedef __uint32_t sae_associd_t;
#define SAE_ASSOCID_ANY 0
#define SAE_ASSOCID_ALL ((sae_associd_t)(-1ULL))

typedef __uint32_t sae_connid_t;
#define SAE_CONNID_ANY  0
#define SAE_CONNID_ALL  ((sae_connid_t)(-1ULL))

/* connectx() flag parameters */
#define CONNECT_RESUME_ON_READ_WRITE    0x1 /* resume connect() on read/write */
#define CONNECT_DATA_IDEMPOTENT         0x2 /* data is idempotent */
#define CONNECT_DATA_AUTHENTICATED      0x4 /* data includes security that replaces the TFO-cookie */

/* sockaddr endpoints */
typedef struct sa_endpoints {
	unsigned int            sae_srcif;      /* optional source interface */
	const struct sockaddr   *sae_srcaddr;   /* optional source address */
	socklen_t               sae_srcaddrlen; /* size of source address */
	const struct sockaddr   *sae_dstaddr;   /* destination address */
	socklen_t               sae_dstaddrlen; /* size of destination address */
} sa_endpoints_t;
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * Structure used for manipulating linger option.
 */
struct  linger {
	int     l_onoff;                /* option on/off */
	int     l_linger;               /* linger time */
};

#ifndef __APPLE__
struct  accept_filter_arg {
	char    af_name[16];
	char    af_arg[256 - 16];
};
#endif

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#ifdef __APPLE__

/*
 * Structure to control non-portable Sockets extension to POSIX
 */
struct so_np_extensions {
	u_int32_t       npx_flags;
	u_int32_t       npx_mask;
};

#define SONPX_SETOPTSHUT        0x000000001     /* flag for allowing setsockopt after shutdown */



#endif
#endif

/*
 * Level number for (get/set)sockopt() to apply to socket itself.
 */
#define SOL_SOCKET      0xffff          /* options for socket level */


/*
 * Address families.
 */
#define AF_UNSPEC       0               /* unspecified */
#define AF_UNIX         1               /* local to host (pipes) */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define AF_LOCAL        AF_UNIX         /* backward compatibility */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define AF_INET         2               /* internetwork: UDP, TCP, etc. */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define AF_IMPLINK      3               /* arpanet imp addresses */
#define AF_PUP          4               /* pup protocols: e.g. BSP */
#define AF_CHAOS        5               /* mit CHAOS protocols */
#define AF_NS           6               /* XEROX NS protocols */
#define AF_ISO          7               /* ISO protocols */
#define AF_OSI          AF_ISO
#define AF_ECMA         8               /* European computer manufacturers */
#define AF_DATAKIT      9               /* datakit protocols */
#define AF_CCITT        10              /* CCITT protocols, X.25 etc */
#define AF_SNA          11              /* IBM SNA */
#define AF_DECnet       12              /* DECnet */
#define AF_DLI          13              /* DEC Direct data link interface */
#define AF_LAT          14              /* LAT */
#define AF_HYLINK       15              /* NSC Hyperchannel */
#define AF_APPLETALK    16              /* Apple Talk */
#define AF_ROUTE        17              /* Internal Routing Protocol */
#define AF_LINK         18              /* Link layer interface */
#define pseudo_AF_XTP   19              /* eXpress Transfer Protocol (no AF) */
#define AF_COIP         20              /* connection-oriented IP, aka ST II */
#define AF_CNT          21              /* Computer Network Technology */
#define pseudo_AF_RTIP  22              /* Help Identify RTIP packets */
#define AF_IPX          23              /* Novell Internet Protocol */
#define AF_SIP          24              /* Simple Internet Protocol */
#define pseudo_AF_PIP   25              /* Help Identify PIP packets */
#define AF_NDRV         27              /* Network Driver 'raw' access */
#define AF_ISDN         28              /* Integrated Services Digital Network */
#define AF_E164         AF_ISDN         /* CCITT E.164 recommendation */
#define pseudo_AF_KEY   29              /* Internal key-management function */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#define AF_INET6        30              /* IPv6 */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define AF_NATM         31              /* native ATM access */
#define AF_SYSTEM       32              /* Kernel event messages */
#define AF_NETBIOS      33              /* NetBIOS */
#define AF_PPP          34              /* PPP communication protocol */
#define pseudo_AF_HDRCMPLT 35           /* Used by BPF to not rewrite headers
	                                 *  in interface output routine */
#define AF_RESERVED_36  36              /* Reserved for internal usage */
#define AF_IEEE80211    37              /* IEEE 802.11 protocol */
#define AF_UTUN         38
#define AF_MAX          40
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * [XSI] Structure used by kernel to store most addresses.
 */
struct sockaddr {
	__uint8_t       sa_len;         /* total length */
	sa_family_t     sa_family;      /* [XSI] address family */
	char            sa_data[14];    /* [XSI] addr value (actually larger) */
};

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define SOCK_MAXADDRLEN 255             /* longest possible addresses */

/*
 * Structure used by kernel to pass protocol
 * information in raw sockets.
 */
struct sockproto {
	__uint16_t      sp_family;              /* address family */
	__uint16_t      sp_protocol;            /* protocol */
};
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * RFC 2553: protocol-independent placeholder for socket addresses
 */
#define _SS_MAXSIZE     128
#define _SS_ALIGNSIZE   (sizeof(__int64_t))
#define _SS_PAD1SIZE    \
	        (_SS_ALIGNSIZE - sizeof(__uint8_t) - sizeof(sa_family_t))
#define _SS_PAD2SIZE    \
	        (_SS_MAXSIZE - sizeof(__uint8_t) - sizeof(sa_family_t) - \
	                        _SS_PAD1SIZE - _SS_ALIGNSIZE)

/*
 * [XSI] sockaddr_storage
 */
struct sockaddr_storage {
	__uint8_t       ss_len;         /* address length */
	sa_family_t     ss_family;      /* [XSI] address family */
	char                    __ss_pad1[_SS_PAD1SIZE];
	__int64_t       __ss_align;     /* force structure storage alignment */
	char                    __ss_pad2[_SS_PAD2SIZE];
};

/*
 * Protocol families, same as address families for now.
 */
#define PF_UNSPEC       AF_UNSPEC
#define PF_LOCAL        AF_LOCAL
#define PF_UNIX         PF_LOCAL        /* backward compatibility */
#define PF_INET         AF_INET
#define PF_IMPLINK      AF_IMPLINK
#define PF_PUP          AF_PUP
#define PF_CHAOS        AF_CHAOS
#define PF_NS           AF_NS
#define PF_ISO          AF_ISO
#define PF_OSI          AF_ISO
#define PF_ECMA         AF_ECMA
#define PF_DATAKIT      AF_DATAKIT
#define PF_CCITT        AF_CCITT
#define PF_SNA          AF_SNA
#define PF_DECnet       AF_DECnet
#define PF_DLI          AF_DLI
#define PF_LAT          AF_LAT
#define PF_HYLINK       AF_HYLINK
#define PF_APPLETALK    AF_APPLETALK
#define PF_ROUTE        AF_ROUTE
#define PF_LINK         AF_LINK
#define PF_XTP          pseudo_AF_XTP   /* really just proto family, no AF */
#define PF_COIP         AF_COIP
#define PF_CNT          AF_CNT
#define PF_SIP          AF_SIP
#define PF_IPX          AF_IPX          /* same format as AF_NS */
#define PF_RTIP         pseudo_AF_RTIP  /* same format as AF_INET */
#define PF_PIP          pseudo_AF_PIP
#define PF_NDRV         AF_NDRV
#define PF_ISDN         AF_ISDN
#define PF_KEY          pseudo_AF_KEY
#define PF_INET6        AF_INET6
#define PF_NATM         AF_NATM
#define PF_SYSTEM       AF_SYSTEM
#define PF_NETBIOS      AF_NETBIOS
#define PF_PPP          AF_PPP
#define PF_RESERVED_36  AF_RESERVED_36
#define PF_UTUN         AF_UTUN
#define PF_MAX          AF_MAX

/*
 * These do not have socket-layer support:
 */
#define PF_VLAN         ((uint32_t)0x766c616e)  /* 'vlan' */
#define PF_BOND         ((uint32_t)0x626f6e64)  /* 'bond' */

/*
 * Definitions for network related sysctl, CTL_NET.
 *
 * Second level is protocol family.
 * Third level is protocol number.
 *
 * Further levels are defined by the individual families below.
 */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define NET_MAXID       AF_MAX
#endif /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */


#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * PF_ROUTE - Routing table
 *
 * Three additional levels are defined:
 *	Fourth: address family, 0 is wildcard
 *	Fifth: type of info, defined below
 *	Sixth: flag(s) to mask with for NET_RT_FLAGS
 */
#define NET_RT_DUMP             1       /* dump; may limit to a.f. */
#define NET_RT_FLAGS            2       /* by flags, e.g. RESOLVING */
#define NET_RT_IFLIST           3       /* survey interface list */
#define NET_RT_STAT             4       /* routing statistics */
#define NET_RT_TRASH            5       /* routes not in table but not freed */
#define NET_RT_IFLIST2          6       /* interface list with addresses */
#define NET_RT_DUMP2            7       /* dump; may limit to a.f. */
/*
 * Allows read access non-local host's MAC address
 * if the process has neighbor cache entitlement.
 */
#define NET_RT_FLAGS_PRIV       10
#define NET_RT_MAXID            11
#endif /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */




/*
 * Maximum queue length specifiable by listen.
 */
#define SOMAXCONN       128

/*
 * [XSI] Message header for recvmsg and sendmsg calls.
 * Used value-result for recvmsg, value only for sendmsg.
 */
struct msghdr {
	void            *msg_name;      /* [XSI] optional address */
	socklen_t       msg_namelen;    /* [XSI] size of address */
	struct          iovec *msg_iov; /* [XSI] scatter/gather array */
	int             msg_iovlen;     /* [XSI] # elements in msg_iov */
	void            *msg_control;   /* [XSI] ancillary data, see below */
	socklen_t       msg_controllen; /* [XSI] ancillary data buffer len */
	int             msg_flags;      /* [XSI] flags on received message */
};



#define MSG_OOB         0x1             /* process out-of-band data */
#define MSG_PEEK        0x2             /* peek at incoming message */
#define MSG_DONTROUTE   0x4             /* send without using routing tables */
#define MSG_EOR         0x8             /* data completes record */
#define MSG_TRUNC       0x10            /* data discarded before delivery */
#define MSG_CTRUNC      0x20            /* control data lost before delivery */
#define MSG_WAITALL     0x40            /* wait for full request or error */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define MSG_DONTWAIT    0x80            /* this message should be nonblocking */
#define MSG_EOF         0x100           /* data completes connection */
#ifdef __APPLE__
#ifdef __APPLE_API_OBSOLETE
#define MSG_WAITSTREAM  0x200           /* wait up to full request.. may return partial */
#endif
#define MSG_FLUSH       0x400           /* Start of 'hold' seq; dump so_temp, deprecated */
#define MSG_HOLD        0x800           /* Hold frag in so_temp, deprecated */
#define MSG_SEND        0x1000          /* Send the packet in so_temp, deprecated */
#define MSG_HAVEMORE    0x2000          /* Data ready to be read */
#define MSG_RCVMORE     0x4000          /* Data remains in current pkt */
#endif
#define MSG_NEEDSA      0x10000         /* Fail receive if socket address cannot be allocated */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * Header for ancillary data objects in msg_control buffer.
 * Used for additional information with/about a datagram
 * not expressible by flags.  The format is a sequence
 * of message elements headed by cmsghdr structures.
 */
struct cmsghdr {
	socklen_t       cmsg_len;       /* [XSI] data byte count, including hdr */
	int             cmsg_level;     /* [XSI] originating protocol */
	int             cmsg_type;      /* [XSI] protocol-specific type */
/* followed by	unsigned char  cmsg_data[]; */
};

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#ifndef __APPLE__
/*
 * While we may have more groups than this, the cmsgcred struct must
 * be able to fit in an mbuf, and NGROUPS_MAX is too large to allow
 * this.
 */
#define CMGROUP_MAX 16

/*
 * Credentials structure, used to verify the identity of a peer
 * process that has sent us a message. This is allocated by the
 * peer process but filled in by the kernel. This prevents the
 * peer from lying about its identity. (Note that cmcred_groups[0]
 * is the effective GID.)
 */
struct cmsgcred {
	pid_t   cmcred_pid;             /* PID of sending process */
	uid_t   cmcred_uid;             /* real UID of sending process */
	uid_t   cmcred_euid;            /* effective UID of sending process */
	gid_t   cmcred_gid;             /* real GID of sending process */
	short   cmcred_ngroups;         /* number or groups */
	gid_t   cmcred_groups[CMGROUP_MAX];     /* groups */
};
#endif
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/* given pointer to struct cmsghdr, return pointer to data */
#define CMSG_DATA(cmsg)         ((unsigned char *)(cmsg) + \
	__DARWIN_ALIGN32(sizeof(struct cmsghdr)))

/*
 * RFC 2292 requires to check msg_controllen, in case that the kernel returns
 * an empty list for some reasons.
 */
#define CMSG_FIRSTHDR(mhdr) \
	((mhdr)->msg_controllen >= sizeof(struct cmsghdr) ? \
	    (struct cmsghdr *)(mhdr)->msg_control : \
	    (struct cmsghdr *)0L)


/*
 * Given pointer to struct cmsghdr, return pointer to next cmsghdr
 * RFC 2292 says that CMSG_NXTHDR(mhdr, NULL) is equivalent to CMSG_FIRSTHDR(mhdr)
 */
#define CMSG_NXTHDR(mhdr, cmsg)                                         \
	((char *)(cmsg) == (char *)0L ? CMSG_FIRSTHDR(mhdr) :           \
	    ((((unsigned char *)(cmsg) +                                \
	    __DARWIN_ALIGN32((__uint32_t)(cmsg)->cmsg_len) +            \
	    __DARWIN_ALIGN32(sizeof(struct cmsghdr))) >                 \
	    ((unsigned char *)(mhdr)->msg_control +                     \
	    (mhdr)->msg_controllen)) ?                                  \
	        (struct cmsghdr *)0L /* NULL */ :                       \
	        (struct cmsghdr *)(void *)((unsigned char *)(cmsg) +    \
	            __DARWIN_ALIGN32((__uint32_t)(cmsg)->cmsg_len))))

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/* RFC 2292 additions */
#define CMSG_SPACE(l)           (__DARWIN_ALIGN32(sizeof(struct cmsghdr)) + __DARWIN_ALIGN32(l))
#define CMSG_LEN(l)             (__DARWIN_ALIGN32(sizeof(struct cmsghdr)) + (l))

#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/* "Socket"-level control message types: */
#define SCM_RIGHTS                      0x01    /* access rights (array of int) */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define SCM_TIMESTAMP                   0x02    /* timestamp (struct timeval) */
#define SCM_CREDS                       0x03    /* process creds (struct cmsgcred) */
#define SCM_TIMESTAMP_MONOTONIC         0x04    /* timestamp (uint64_t) */


#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * howto arguments for shutdown(2), specified by Posix.1g.
 */
#define SHUT_RD         0               /* shut down the reading side */
#define SHUT_WR         1               /* shut down the writing side */
#define SHUT_RDWR       2               /* shut down both sides */

#if !defined(_POSIX_C_SOURCE)
/*
 * sendfile(2) header/trailer struct
 */
struct sf_hdtr {
	struct iovec *headers;  /* pointer to an array of header struct iovec's */
	int hdr_cnt;            /* number of header iovec's */
	struct iovec *trailers; /* pointer to an array of trailer struct iovec's */
	int trl_cnt;            /* number of trailer iovec's */
};


#endif  /* !_POSIX_C_SOURCE */


__BEGIN_DECLS

int     accept(int, struct sockaddr * __restrict, socklen_t * __restrict)
__DARWIN_ALIAS_C(accept);
int     bind(int, const struct sockaddr *, socklen_t) __DARWIN_ALIAS(bind);
int     connect(int, const struct sockaddr *, socklen_t) __DARWIN_ALIAS_C(connect);
int     getpeername(int, struct sockaddr * __restrict, socklen_t * __restrict)
__DARWIN_ALIAS(getpeername);
int     getsockname(int, struct sockaddr * __restrict, socklen_t * __restrict)
__DARWIN_ALIAS(getsockname);
int     getsockopt(int, int, int, void * __restrict, socklen_t * __restrict);
int     listen(int, int) __DARWIN_ALIAS(listen);
ssize_t recv(int, void *, size_t, int) __DARWIN_ALIAS_C(recv);
ssize_t recvfrom(int, void *, size_t, int, struct sockaddr * __restrict,
    socklen_t * __restrict) __DARWIN_ALIAS_C(recvfrom);
ssize_t recvmsg(int, struct msghdr *, int) __DARWIN_ALIAS_C(recvmsg);
ssize_t send(int, const void *, size_t, int) __DARWIN_ALIAS_C(send);
ssize_t sendmsg(int, const struct msghdr *, int) __DARWIN_ALIAS_C(sendmsg);
ssize_t sendto(int, const void *, size_t,
    int, const struct sockaddr *, socklen_t) __DARWIN_ALIAS_C(sendto);
int     setsockopt(int, int, int, const void *, socklen_t);
int     shutdown(int, int);
int     sockatmark(int) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int     socket(int, int, int);
int     socketpair(int, int, int, int *) __DARWIN_ALIAS(socketpair);

#if !defined(_POSIX_C_SOURCE)
int     sendfile(int, int, off_t, off_t *, struct sf_hdtr *, int);
#endif  /* !_POSIX_C_SOURCE */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
void    pfctlinput(int, struct sockaddr *);

__API_AVAILABLE(macosx(10.11), ios(9.0), tvos(9.0), watchos(2.0))
int connectx(int, const sa_endpoints_t *, sae_associd_t, unsigned int,
    const struct iovec *, unsigned int, size_t *, sae_connid_t *);

__API_AVAILABLE(macosx(10.11), ios(9.0), tvos(9.0), watchos(2.0))
int disconnectx(int, sae_associd_t, sae_connid_t);
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
__END_DECLS


#endif /* !_SYS_SOCKET_H_ */
