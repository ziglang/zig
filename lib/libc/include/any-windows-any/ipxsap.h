/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _IPXSAP_
#define _IPXSAP_

#include <ipxconst.h>

typedef struct _SAP_GLOBAL_INFO {
  DWORD EventLogMask;
} SAP_GLOBAL_INFO,*PSAP_GLOBAL_INFO;

typedef struct _SAP_IF_INFO {
  ULONG AdminState;
  ULONG UpdateMode;
  ULONG PacketType;
  ULONG Supply;
  ULONG Listen;
  ULONG GetNearestServerReply;
  ULONG PeriodicUpdateInterval;
  ULONG AgeIntervalMultiplier;
} SAP_IF_INFO,*PSAP_IF_INFO;

typedef struct _SAP_SERVICE_FILTER_INFO {
  __C89_NAMELESS union {
    USHORT ServiceType;
    ULONG ServiceType_align;
  };
  UCHAR ServiceName[48];
} SAP_SERVICE_FILTER_INFO,*PSAP_SERVICE_FILTER_INFO;

typedef struct _SAP_IF_FILTERS {
  ULONG SupplyFilterAction;
  ULONG SupplyFilterCount;
  ULONG ListenFilterAction;
  ULONG ListenFilterCount;
  SAP_SERVICE_FILTER_INFO ServiceFilter[1];
} SAP_IF_FILTERS,*PSAP_IF_FILTERS;

#define IPX_SERVICE_FILTER_PERMIT 1
#define IPX_SERVICE_FILTER_DENY 2

typedef struct _SAP_IF_CONFIG {
  SAP_IF_INFO SapIfInfo;
  SAP_IF_FILTERS SapIfFilters;
} SAP_IF_CONFIG,*PSAP_IF_CONFIG;

#define SAP_BASE_ENTRY 0
#define SAP_INTERFACE_TABLE 1

typedef struct _SAP_MIB_BASE {
  ULONG SapOperState;
} SAP_MIB_BASE,*PSAP_MIB_BASE;

typedef struct _SAP_IF_STATS {
  ULONG SapIfOperState;
  ULONG SapIfInputPackets;
  ULONG SapIfOutputPackets;
} SAP_IF_STATS,*PSAP_IF_STATS;

typedef struct _SAP_INTERFACE {
  ULONG InterfaceIndex;
  SAP_IF_INFO SapIfInfo;
  SAP_IF_STATS SapIfStats;
} SAP_INTERFACE,*PSAP_INTERFACE;

typedef struct _SAP_MIB_GET_INPUT_DATA {
  ULONG TableId;
  ULONG InterfaceIndex;
} SAP_MIB_GET_INPUT_DATA,*PSAP_MIB_GET_INPUT_DATA;

typedef struct _SAP_MIB_SET_INPUT_DATA {
  ULONG TableId;
  SAP_INTERFACE SapInterface;
} SAP_MIB_SET_INPUT_DATA,*PSAP_MIB_SET_INPUT_DATA;
#endif
