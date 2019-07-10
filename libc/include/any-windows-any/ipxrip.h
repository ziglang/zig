/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _IPXRIP_
#define _IPXRIP_

#include <ipxconst.h>

typedef struct _RIP_GLOBAL_INFO {
  DWORD EventLogMask;
} RIP_GLOBAL_INFO,*PRIP_GLOBAL_INFO;

typedef struct _RIP_IF_INFO {
  ULONG AdminState;
  ULONG UpdateMode;
  ULONG PacketType;
  ULONG Supply;
  ULONG Listen;
  ULONG PeriodicUpdateInterval;
  ULONG AgeIntervalMultiplier;
} RIP_IF_INFO,*PRIP_IF_INFO;

typedef struct _RIP_ROUTE_FILTER_INFO {
  UCHAR Network[4];
  UCHAR Mask[4];
} RIP_ROUTE_FILTER_INFO,*PRIP_ROUTE_FILTER_INFO;

typedef struct _RIP_IF_FILTERS {
  ULONG SupplyFilterAction;
  ULONG SupplyFilterCount;
  ULONG ListenFilterAction;
  ULONG ListenFilterCount;
  RIP_ROUTE_FILTER_INFO RouteFilter[1];
} RIP_IF_FILTERS,*PRIP_IF_FILTERS;

#define IPX_ROUTE_FILTER_PERMIT 1
#define IPX_ROUTE_FILTER_DENY 2

typedef struct _RIP_IF_CONFIG {
  RIP_IF_INFO RipIfInfo;
  RIP_IF_FILTERS RipIfFilters;
} RIP_IF_CONFIG,*PRIP_IF_CONFIG;

#define RIP_BASE_ENTRY 0
#define RIP_INTERFACE_TABLE 1

typedef struct _RIPMIB_BASE {
  ULONG RIPOperState;
} RIPMIB_BASE,*PRIPMIB_BASE;

typedef struct _RIP_IF_STATS {
  ULONG RipIfOperState;
  ULONG RipIfInputPackets;
  ULONG RipIfOutputPackets;
} RIP_IF_STATS,*PRIP_IF_STATS;

typedef struct _RIP_INTERFACE {
  ULONG InterfaceIndex;
  RIP_IF_INFO RipIfInfo;
  RIP_IF_STATS RipIfStats;
} RIP_INTERFACE,*PRIP_INTERFACE;

typedef struct _RIP_MIB_GET_INPUT_DATA {
  ULONG TableId;
  ULONG InterfaceIndex;
} RIP_MIB_GET_INPUT_DATA,*PRIP_MIB_GET_INPUT_DATA;

typedef struct _RIP_MIB_SET_INPUT_DATA {
  ULONG TableId;
  RIP_INTERFACE RipInterface;
} RIP_MIB_SET_INPUT_DATA,*PRIP_MIB_SET_INPUT_DATA;
#endif
