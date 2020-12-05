/*
 * Copyright (c) 2016-2018 Apple Inc. All rights reserved.
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

#ifndef _NET_NETKEV_H_
#define _NET_NETKEV_H_

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)

/* Kernel event subclass identifiers for KEV_NETWORK_CLASS */
#define KEV_INET_SUBCLASS       1       /* inet subclass */
/* KEV_INET_SUBCLASS event codes */
#define KEV_INET_NEW_ADDR               1 /* Userland configured IP address */
#define KEV_INET_CHANGED_ADDR           2 /* Address changed event */
#define KEV_INET_ADDR_DELETED           3 /* IPv6 address was deleted */
#define KEV_INET_SIFDSTADDR             4 /* Dest. address was set */
#define KEV_INET_SIFBRDADDR             5 /* Broadcast address was set */
#define KEV_INET_SIFNETMASK             6 /* Netmask was set */
#define KEV_INET_ARPCOLLISION           7 /* ARP collision detected */
#ifdef __APPLE_API_PRIVATE
#define KEV_INET_PORTINUSE              8 /* use ken_in_portinuse */
#endif
#define KEV_INET_ARPRTRFAILURE          9 /* ARP resolution failed for router */
#define KEV_INET_ARPRTRALIVE            10 /* ARP resolution succeeded for router */

#define KEV_DL_SUBCLASS 2               /* Data Link subclass */
/*
 * Define Data-Link event subclass, and associated
 * events.
 */
#define KEV_DL_SIFFLAGS                         1
#define KEV_DL_SIFMETRICS                       2
#define KEV_DL_SIFMTU                           3
#define KEV_DL_SIFPHYS                          4
#define KEV_DL_SIFMEDIA                         5
#define KEV_DL_SIFGENERIC                       6
#define KEV_DL_ADDMULTI                         7
#define KEV_DL_DELMULTI                         8
#define KEV_DL_IF_ATTACHED                      9
#define KEV_DL_IF_DETACHING                     10
#define KEV_DL_IF_DETACHED                      11
#define KEV_DL_LINK_OFF                         12
#define KEV_DL_LINK_ON                          13
#define KEV_DL_PROTO_ATTACHED                   14
#define KEV_DL_PROTO_DETACHED                   15
#define KEV_DL_LINK_ADDRESS_CHANGED             16
#define KEV_DL_WAKEFLAGS_CHANGED                17
#define KEV_DL_IF_IDLE_ROUTE_REFCNT             18
#define KEV_DL_IFCAP_CHANGED                    19
#define KEV_DL_LINK_QUALITY_METRIC_CHANGED      20
#define KEV_DL_NODE_PRESENCE                    21
#define KEV_DL_NODE_ABSENCE                     22
#define KEV_DL_MASTER_ELECTED                   23
#define KEV_DL_ISSUES                           24
#define KEV_DL_IFDELEGATE_CHANGED               25
#define KEV_DL_AWDL_RESTRICTED                  26
#define KEV_DL_AWDL_UNRESTRICTED                27
#define KEV_DL_RRC_STATE_CHANGED                28
#define KEV_DL_QOS_MODE_CHANGED                 29
#define KEV_DL_LOW_POWER_MODE_CHANGED           30


#define KEV_INET6_SUBCLASS      6       /* inet6 subclass */
/* KEV_INET6_SUBCLASS event codes */
#define KEV_INET6_NEW_USER_ADDR         1 /* Userland configured IPv6 address */
#define KEV_INET6_CHANGED_ADDR          2 /* Address changed event (future) */
#define KEV_INET6_ADDR_DELETED          3 /* IPv6 address was deleted */
#define KEV_INET6_NEW_LL_ADDR           4 /* Autoconf LL address appeared */
#define KEV_INET6_NEW_RTADV_ADDR        5 /* Autoconf address has appeared */
#define KEV_INET6_DEFROUTER             6 /* Default router detected */
#define KEV_INET6_REQUEST_NAT64_PREFIX  7 /* Asking for the NAT64-prefix */

#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#endif /* _NET_NETKEV_H_ */
