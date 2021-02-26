/*
 * Copyright (c) 2000-2020 Apple Inc. All rights reserved.
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
 *	@(#)if.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NET_IF_H_
#define _NET_IF_H_

#include <sys/cdefs.h>
#include <net/net_kev.h>

#define IF_NAMESIZE     16

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <sys/appleapiopts.h>
#ifdef __APPLE__

#include <net/if_var.h>
#include <sys/types.h>
#include <sys/socket.h>

#endif

struct if_clonereq {
	int     ifcr_total;             /* total cloners (out) */
	int     ifcr_count;             /* room for this many in user buffer */
	char    *ifcr_buffer;           /* buffer for cloner names */
};


#define IFF_UP          0x1             /* interface is up */
#define IFF_BROADCAST   0x2             /* broadcast address valid */
#define IFF_DEBUG       0x4             /* turn on debugging */
#define IFF_LOOPBACK    0x8             /* is a loopback net */
#define IFF_POINTOPOINT 0x10            /* interface is point-to-point link */
#define IFF_NOTRAILERS  0x20            /* obsolete: avoid use of trailers */
#define IFF_RUNNING     0x40            /* resources allocated */
#define IFF_NOARP       0x80            /* no address resolution protocol */
#define IFF_PROMISC     0x100           /* receive all packets */
#define IFF_ALLMULTI    0x200           /* receive all multicast packets */
#define IFF_OACTIVE     0x400           /* transmission in progress */
#define IFF_SIMPLEX     0x800           /* can't hear own transmissions */
#define IFF_LINK0       0x1000          /* per link layer defined bit */
#define IFF_LINK1       0x2000          /* per link layer defined bit */
#define IFF_LINK2       0x4000          /* per link layer defined bit */
#define IFF_ALTPHYS     IFF_LINK2       /* use alternate physical connection */
#define IFF_MULTICAST   0x8000          /* supports multicast */



/*
 * Capabilities that interfaces can advertise.
 *
 * struct ifnet.if_capabilities
 *   contains the optional features & capabilities a particular interface
 *   supports (not only the driver but also the detected hw revision).
 *   Capabilities are defined by IFCAP_* below.
 * struct ifnet.if_capenable
 *   contains the enabled (either by default or through ifconfig) optional
 *   features & capabilities on this interface.
 *   Capabilities are defined by IFCAP_* below.
 * struct if_data.ifi_hwassist in IFNET_* form, defined in net/kpi_interface.h,
 *   contains the enabled optional features & capabilites that can be used
 *   individually per packet and are specified in the mbuf pkthdr.csum_flags
 *   field.  IFCAP_* and IFNET_* do not match one to one and IFNET_* may be
 *   more detailed or differentiated than IFCAP_*.
 *   IFNET_* hwassist flags have corresponding CSUM_* in sys/mbuf.h
 */
#define IFCAP_RXCSUM            0x00001 /* can offload checksum on RX */
#define IFCAP_TXCSUM            0x00002 /* can offload checksum on TX */
#define IFCAP_VLAN_MTU          0x00004 /* VLAN-compatible MTU */
#define IFCAP_VLAN_HWTAGGING    0x00008 /* hardware VLAN tag support */
#define IFCAP_JUMBO_MTU         0x00010 /* 9000 byte MTU supported */
#define IFCAP_TSO4              0x00020 /* can do TCP Segmentation Offload */
#define IFCAP_TSO6              0x00040 /* can do TCP6 Segmentation Offload */
#define IFCAP_LRO               0x00080 /* can do Large Receive Offload */
#define IFCAP_AV                0x00100 /* can do 802.1 AV Bridging */
#define IFCAP_TXSTATUS          0x00200 /* can return linklevel xmit status */
#define IFCAP_SKYWALK           0x00400 /* Skywalk mode supported/enabled */
#define IFCAP_HW_TIMESTAMP      0x00800 /* Time stamping in hardware */
#define IFCAP_SW_TIMESTAMP      0x01000 /* Time stamping in software */
#define IFCAP_CSUM_PARTIAL      0x02000 /* can offload partial checksum */
#define IFCAP_CSUM_ZERO_INVERT  0x04000 /* can invert 0 to -0 (0xffff) */

#define IFCAP_HWCSUM    (IFCAP_RXCSUM | IFCAP_TXCSUM)
#define IFCAP_TSO       (IFCAP_TSO4 | IFCAP_TSO6)

#define IFCAP_VALID (IFCAP_HWCSUM | IFCAP_TSO | IFCAP_LRO | IFCAP_VLAN_MTU | \
	IFCAP_VLAN_HWTAGGING | IFCAP_JUMBO_MTU | IFCAP_AV | IFCAP_TXSTATUS | \
	IFCAP_SKYWALK | IFCAP_SW_TIMESTAMP | IFCAP_HW_TIMESTAMP | \
	IFCAP_CSUM_PARTIAL | IFCAP_CSUM_ZERO_INVERT)

#define IFQ_MAXLEN      128
#define IFNET_SLOWHZ    1       /* granularity is 1 second */
#define IFQ_TARGET_DELAY        (10ULL * 1000 * 1000)   /* 10 ms */
#define IFQ_UPDATE_INTERVAL     (100ULL * 1000 * 1000)  /* 100 ms */

/*
 * Message format for use in obtaining information about interfaces
 * from sysctl and the routing socket
 */
struct if_msghdr {
	unsigned short  ifm_msglen;     /* to skip non-understood messages */
	unsigned char   ifm_version;    /* future binary compatability */
	unsigned char   ifm_type;       /* message type */
	int             ifm_addrs;      /* like rtm_addrs */
	int             ifm_flags;      /* value of if_flags */
	unsigned short  ifm_index;      /* index for associated ifp */
	struct  if_data ifm_data;       /* statistics and other data about if */
};

/*
 * Message format for use in obtaining information about interface addresses
 * from sysctl and the routing socket
 */
struct ifa_msghdr {
	unsigned short  ifam_msglen;    /* to skip non-understood messages */
	unsigned char   ifam_version;   /* future binary compatability */
	unsigned char   ifam_type;      /* message type */
	int             ifam_addrs;     /* like rtm_addrs */
	int             ifam_flags;     /* value of ifa_flags */
	unsigned short  ifam_index;     /* index for associated ifp */
	int             ifam_metric;    /* value of ifa_metric */
};

/*
 * Message format for use in obtaining information about multicast addresses
 * from the routing socket
 */
struct ifma_msghdr {
	unsigned short  ifmam_msglen;   /* to skip non-understood messages */
	unsigned char   ifmam_version;  /* future binary compatability */
	unsigned char   ifmam_type;     /* message type */
	int             ifmam_addrs;    /* like rtm_addrs */
	int             ifmam_flags;    /* value of ifa_flags */
	unsigned short  ifmam_index;    /* index for associated ifp */
};

/*
 * Message format for use in obtaining information about interfaces
 * from sysctl
 */
struct if_msghdr2 {
	u_short ifm_msglen;     /* to skip over non-understood messages */
	u_char  ifm_version;    /* future binary compatability */
	u_char  ifm_type;       /* message type */
	int     ifm_addrs;      /* like rtm_addrs */
	int     ifm_flags;      /* value of if_flags */
	u_short ifm_index;      /* index for associated ifp */
	int     ifm_snd_len;    /* instantaneous length of send queue */
	int     ifm_snd_maxlen; /* maximum length of send queue */
	int     ifm_snd_drops;  /* number of drops in send queue */
	int     ifm_timer;      /* time until if_watchdog called */
	struct if_data64        ifm_data;       /* statistics and other data */
};

/*
 * Message format for use in obtaining information about multicast addresses
 * from sysctl
 */
struct ifma_msghdr2 {
	u_short ifmam_msglen;   /* to skip over non-understood messages */
	u_char  ifmam_version;  /* future binary compatability */
	u_char  ifmam_type;     /* message type */
	int     ifmam_addrs;    /* like rtm_addrs */
	int     ifmam_flags;    /* value of ifa_flags */
	u_short ifmam_index;    /* index for associated ifp */
	int32_t ifmam_refcount;
};

/*
 * ifdevmtu: interface device mtu
 *    Used with SIOCGIFDEVMTU to get the current mtu in use by the device,
 *    as well as the minimum and maximum mtu allowed by the device.
 */
struct ifdevmtu {
	int     ifdm_current;
	int     ifdm_min;
	int     ifdm_max;
};

#pragma pack(4)

/*
 *  ifkpi: interface kpi ioctl
 *  Used with SIOCSIFKPI and SIOCGIFKPI.
 *
 *  ifk_module_id - From in the kernel, a value from kev_vendor_code_find. From
 *       user space, a value from SIOCGKEVVENDOR ioctl on a kernel event socket.
 *  ifk_type - The type. Types are specific to each module id.
 *  ifk_data - The data. ifk_ptr may be a 64bit pointer for 64 bit processes.
 *
 *  Copying data between user space and kernel space is done using copyin
 *  and copyout. A process may be running in 64bit mode. In such a case,
 *  the pointer will be a 64bit pointer, not a 32bit pointer. The following
 *  sample is a safe way to copy the data in to the kernel from either a
 *  32bit or 64bit process:
 *
 *  user_addr_t tmp_ptr;
 *  if (IS_64BIT_PROCESS(current_proc())) {
 *       tmp_ptr = CAST_USER_ADDR_T(ifkpi.ifk_data.ifk_ptr64);
 *  }
 *  else {
 *       tmp_ptr = CAST_USER_ADDR_T(ifkpi.ifk_data.ifk_ptr);
 *  }
 *  error = copyin(tmp_ptr, allocated_dst_buffer, size of allocated_dst_buffer);
 */

struct ifkpi {
	unsigned int    ifk_module_id;
	unsigned int    ifk_type;
	union {
		void            *ifk_ptr;
		int             ifk_value;
	} ifk_data;
};

/* Wake capabilities of a interface */
#define IF_WAKE_ON_MAGIC_PACKET         0x01


#pragma pack()

/*
 * Interface request structure used for socket
 * ioctl's.  All interface ioctl's must have parameter
 * definitions which begin with ifr_name.  The
 * remainder may be interface specific.
 */
struct  ifreq {
#ifndef IFNAMSIZ
#define IFNAMSIZ        IF_NAMESIZE
#endif
	char    ifr_name[IFNAMSIZ];             /* if name, e.g. "en0" */
	union {
		struct  sockaddr ifru_addr;
		struct  sockaddr ifru_dstaddr;
		struct  sockaddr ifru_broadaddr;
		short   ifru_flags;
		int     ifru_metric;
		int     ifru_mtu;
		int     ifru_phys;
		int     ifru_media;
		int     ifru_intval;
		caddr_t ifru_data;
		struct  ifdevmtu ifru_devmtu;
		struct  ifkpi   ifru_kpi;
		u_int32_t ifru_wake_flags;
		u_int32_t ifru_route_refcnt;
		int     ifru_cap[2];
		u_int32_t ifru_functional_type;
#define IFRTYPE_FUNCTIONAL_UNKNOWN              0
#define IFRTYPE_FUNCTIONAL_LOOPBACK             1
#define IFRTYPE_FUNCTIONAL_WIRED                2
#define IFRTYPE_FUNCTIONAL_WIFI_INFRA           3
#define IFRTYPE_FUNCTIONAL_WIFI_AWDL            4
#define IFRTYPE_FUNCTIONAL_CELLULAR             5
#define IFRTYPE_FUNCTIONAL_INTCOPROC            6
#define IFRTYPE_FUNCTIONAL_COMPANIONLINK        7
#define IFRTYPE_FUNCTIONAL_LAST                 7
	} ifr_ifru;
#define ifr_addr        ifr_ifru.ifru_addr      /* address */
#define ifr_dstaddr     ifr_ifru.ifru_dstaddr   /* other end of p-to-p link */
#define ifr_broadaddr   ifr_ifru.ifru_broadaddr /* broadcast address */
#ifdef __APPLE__
#define ifr_flags       ifr_ifru.ifru_flags     /* flags */
#else
#define ifr_flags       ifr_ifru.ifru_flags[0]  /* flags */
#define ifr_prevflags   ifr_ifru.ifru_flags[1]  /* flags */
#endif /* __APPLE__ */
#define ifr_metric      ifr_ifru.ifru_metric    /* metric */
#define ifr_mtu         ifr_ifru.ifru_mtu       /* mtu */
#define ifr_phys        ifr_ifru.ifru_phys      /* physical wire */
#define ifr_media       ifr_ifru.ifru_media     /* physical media */
#define ifr_data        ifr_ifru.ifru_data      /* for use by interface */
#define ifr_devmtu      ifr_ifru.ifru_devmtu
#define ifr_intval      ifr_ifru.ifru_intval    /* integer value */
#define ifr_kpi         ifr_ifru.ifru_kpi
#define ifr_wake_flags  ifr_ifru.ifru_wake_flags /* wake capabilities */
#define ifr_route_refcnt ifr_ifru.ifru_route_refcnt /* route references count */
#define ifr_reqcap      ifr_ifru.ifru_cap[0]    /* requested capabilities */
#define ifr_curcap      ifr_ifru.ifru_cap[1]    /* current capabilities */
};

#define _SIZEOF_ADDR_IFREQ(ifr) \
	((ifr).ifr_addr.sa_len > sizeof (struct sockaddr) ? \
	(sizeof (struct ifreq) - sizeof (struct sockaddr) + \
	(ifr).ifr_addr.sa_len) : sizeof (struct ifreq))

struct ifaliasreq {
	char    ifra_name[IFNAMSIZ];            /* if name, e.g. "en0" */
	struct  sockaddr ifra_addr;
	struct  sockaddr ifra_broadaddr;
	struct  sockaddr ifra_mask;
};

struct rslvmulti_req {
	struct sockaddr *sa;
	struct sockaddr **llsa;
};

#pragma pack(4)

struct ifmediareq {
	char    ifm_name[IFNAMSIZ];     /* if name, e.g. "en0" */
	int     ifm_current;            /* current media options */
	int     ifm_mask;               /* don't care mask */
	int     ifm_status;             /* media status */
	int     ifm_active;             /* active options */
	int     ifm_count;              /* # entries in ifm_ulist array */
	int     *ifm_ulist;             /* media words */
};

#pragma pack()



#pragma pack(4)
struct  ifdrv {
	char            ifd_name[IFNAMSIZ];     /* if name, e.g. "en0" */
	unsigned long   ifd_cmd;
	size_t          ifd_len;                /* length of ifd_data buffer */
	void            *ifd_data;
};
#pragma pack()


/*
 * Structure used to retrieve aux status data from interfaces.
 * Kernel suppliers to this interface should respect the formatting
 * needed by ifconfig(8): each line starts with a TAB and ends with
 * a newline.
 */

#define IFSTATMAX       800             /* 10 lines of text */
struct ifstat {
	char    ifs_name[IFNAMSIZ];     /* if name, e.g. "en0" */
	char    ascii[IFSTATMAX + 1];
};

/*
 * Structure used in SIOCGIFCONF request.
 * Used to retrieve interface configuration
 * for machine (useful for programs which
 * must know all networks accessible).
 */
#pragma pack(4)
struct  ifconf {
	int     ifc_len;                /* size of associated buffer */
	union {
		caddr_t ifcu_buf;
		struct  ifreq *ifcu_req;
	} ifc_ifcu;
};
#pragma pack()
#define ifc_buf ifc_ifcu.ifcu_buf       /* buffer address */
#define ifc_req ifc_ifcu.ifcu_req       /* array of structures returned */


/*
 * DLIL KEV_DL_PROTO_ATTACHED/DETACHED structure
 */
struct kev_dl_proto_data {
	struct net_event_data           link_data;
	u_int32_t                       proto_family;
	u_int32_t                       proto_remaining_count;
};


#endif /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */

struct if_nameindex {
	unsigned int     if_index;      /* 1, 2, ... */
	char            *if_name;       /* null terminated name: "le0", ... */
};

__BEGIN_DECLS
unsigned int     if_nametoindex(const char *);
char            *if_indextoname(unsigned int, char *);
struct           if_nameindex *if_nameindex(void);
void             if_freenameindex(struct if_nameindex *);
__END_DECLS


#endif /* !_NET_IF_H_ */