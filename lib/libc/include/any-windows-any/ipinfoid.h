/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __ROUTING_IPINFOID_H__
#define __ROUTING_IPINFOID_H__

#ifdef __cplusplus
extern "C" {
#endif

#define IP_ROUTER_MANAGER_VERSION 1

#define IP_GENERAL_INFO_BASE 0xffff0000

#define IP_IN_FILTER_INFO IP_GENERAL_INFO_BASE + 1
#define IP_OUT_FILTER_INFO IP_GENERAL_INFO_BASE + 2
#define IP_GLOBAL_INFO IP_GENERAL_INFO_BASE + 3
#define IP_INTERFACE_STATUS_INFO IP_GENERAL_INFO_BASE + 4
#define IP_ROUTE_INFO IP_GENERAL_INFO_BASE + 5
#define IP_PROT_PRIORITY_INFO IP_GENERAL_INFO_BASE + 6
#define IP_ROUTER_DISC_INFO IP_GENERAL_INFO_BASE + 7

#define IP_DEMAND_DIAL_FILTER_INFO IP_GENERAL_INFO_BASE + 9
#define IP_MCAST_HEARBEAT_INFO IP_GENERAL_INFO_BASE + 10
#define IP_MCAST_BOUNDARY_INFO IP_GENERAL_INFO_BASE + 11
#define IP_IPINIP_CFG_INFO IP_GENERAL_INFO_BASE + 12
#define IP_IFFILTER_INFO IP_GENERAL_INFO_BASE + 13
#define IP_MCAST_LIMIT_INFO IP_GENERAL_INFO_BASE + 14

#ifdef __cplusplus
}
#endif
#endif
