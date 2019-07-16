/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _IPXRTDEF_
#define _IPXRTDEF_

#include <ipxconst.h>
#include <ipxsap.h>
#include <ipxrip.h>
#include <stm.h>
#include <ipxtfflt.h>

#define IPX_ROUTER_VERSION_1 RTR_INFO_BLOCK_VERSION

#define IPX_PROTOCOL_LOCAL 1
#define IPX_PROTOCOL_STATIC 2

#define IF_TYPE_OTHER 1
#define IF_TYPE_LAN 2
#define IF_TYPE_WAN_ROUTER 3
#define IF_TYPE_WAN_WORKSTATION 4
#define IF_TYPE_INTERNAL 5
#define IF_TYPE_PERSONAL_WAN_ROUTER 6
#define IF_TYPE_ROUTER_WORKSTATION_DIALOUT 7
#define IF_TYPE_STANDALONE_WORKSTATION_DIALOUT 8

#define IPX_INTERFACE_INFO_TYPE 1
#define IPX_STATIC_ROUTE_INFO_TYPE 2
#define IPX_STATIC_SERVICE_INFO_TYPE 3
#define IPX_SERVICE_FILTER_INFO_TYPE 4
#define IPX_ROUTE_FILTER_INFO_TYPE 5
#define IPX_IN_TRAFFIC_FILTER_INFO_TYPE 6
#define IPX_ADAPTER_INFO_TYPE 7
#define IPXWAN_INTERFACE_INFO_TYPE 8
#define IPX_GLOBAL_INFO_TYPE 9
#define IPX_STATIC_NETBIOS_NAME_INFO_TYPE 10
#define IPX_IN_TRAFFIC_FILTER_GLOBAL_INFO_TYPE 11
#define IPX_OUT_TRAFFIC_FILTER_INFO_TYPE 12
#define IPX_OUT_TRAFFIC_FILTER_GLOBAL_INFO_TYPE 13

#define IPX_SMALL_ROUTING_TABLE_HASH_SIZE 31
#define IPX_MEDIUM_ROUTING_TABLE_HASH_SIZE 257
#define IPX_LARGE_ROUTING_TABLE_HASH_SIZE 2047

typedef struct _IPX_GLOBAL_INFO {
  ULONG RoutingTableHashSize;
  ULONG EventLogMask;
} IPX_GLOBAL_INFO,*PIPX_GLOBAL_INFO;

typedef struct _IPX_IF_INFO {
  ULONG AdminState;
  ULONG NetbiosAccept;
  ULONG NetbiosDeliver;
} IPX_IF_INFO,*PIPX_IF_INFO;

#define IPX_DEDICATED_LINK 1
#define IPX_DIALED_LINK 2

typedef struct _IPXWAN_IF_INFO {
  ULONG AdminState;
} IPXWAN_IF_INFO,*PIPXWAN_IF_INFO;

typedef struct _IPX_STATIC_ROUTE_INFO {
  __C89_NAMELESS union {
    ULONG DwordAlign;
    UCHAR Network[4];
  };
  USHORT TickCount;
  USHORT HopCount;
  UCHAR NextHopMacAddress[6];
} IPX_STATIC_ROUTE_INFO,*PIPX_STATIC_ROUTE_INFO;

typedef IPX_SERVER_ENTRY IPX_STATIC_SERVICE_INFO,*PIPX_STATIC_SERVICE_INFO;

typedef struct _IPX_STATIC_NETBIOS_NAME_INFO {
  __C89_NAMELESS union {
    ULONG DwordAlign;
    UCHAR Name[16];
  };
} IPX_STATIC_NETBIOS_NAME_INFO,*PIPX_STATIC_NETBIOS_NAME_INFO;

#define MAX_ADAPTER_NAME_LEN 48

typedef struct _IPX_ADAPTER_INFO {
  ULONG PacketType;
  WCHAR AdapterName[MAX_ADAPTER_NAME_LEN];
} IPX_ADAPTER_INFO,*PIPX_ADAPTER_INFO;

#define AUTO_DETECT_PACKET_TYPE 0xFFFFFFFF

#define IPX_BASE_ENTRY 0
#define IPX_INTERFACE_TABLE 1
#define IPX_DEST_TABLE 2
#define IPX_STATIC_ROUTE_TABLE 3
#define IPX_SERV_TABLE 4
#define IPX_STATIC_SERV_TABLE 5

#define MAX_IPX_MIB_TABLES 6

#define IPX_INTERFACE_ANSI_NAME_LEN 48

typedef struct _IF_TABLE_INDEX {
  ULONG InterfaceIndex;
} IF_TABLE_INDEX,*PIF_TABLE_INDEX;

typedef struct _ROUTING_TABLE_INDEX {
  UCHAR Network[4];
} ROUTING_TABLE_INDEX,*PROUTING_TABLE_INDEX;

typedef struct _STATIC_ROUTES_TABLE_INDEX {
  ULONG InterfaceIndex;
  UCHAR Network[4];
} STATIC_ROUTES_TABLE_INDEX,*PSTATIC_ROUTES_TABLE_INDEX;

typedef struct _SERVICES_TABLE_INDEX {
  USHORT ServiceType;
  UCHAR ServiceName[48];
} SERVICES_TABLE_INDEX,*PSERVICES_TABLE_INDEX;

typedef struct _STATIC_SERVICES_TABLE_INDEX {
  ULONG InterfaceIndex;
  USHORT ServiceType;
  UCHAR ServiceName[48];
} STATIC_SERVICES_TABLE_INDEX,*PSTATIC_SERVICES_TABLE_INDEX;

typedef union _IPX_MIB_INDEX {
  IF_TABLE_INDEX InterfaceTableIndex;
  ROUTING_TABLE_INDEX RoutingTableIndex;
  STATIC_ROUTES_TABLE_INDEX StaticRoutesTableIndex;
  SERVICES_TABLE_INDEX ServicesTableIndex;
  STATIC_SERVICES_TABLE_INDEX StaticServicesTableIndex;
} IPX_MIB_INDEX,*PIPX_MIB_INDEX;

typedef struct _IPX_MIB_GET_INPUT_DATA {
  ULONG TableId;
  IPX_MIB_INDEX MibIndex;
} IPX_MIB_GET_INPUT_DATA,*PIPX_MIB_GET_INPUT_DATA;

typedef struct _IPXMIB_BASE {
  ULONG OperState;
  UCHAR PrimaryNetNumber[4];
  UCHAR Node[6];
  UCHAR SysName[IPX_INTERFACE_ANSI_NAME_LEN];
  ULONG MaxPathSplits;
  ULONG IfCount;
  ULONG DestCount;
  ULONG ServCount;
} IPXMIB_BASE,*PIPXMIB_BASE;

typedef struct _IPX_IF_STATS {
  ULONG IfOperState;
  ULONG MaxPacketSize;
  ULONG InHdrErrors;
  ULONG InFiltered;
  ULONG InNoRoutes;
  ULONG InDiscards;
  ULONG InDelivers;
  ULONG OutFiltered;
  ULONG OutDiscards;
  ULONG OutDelivers;
  ULONG NetbiosReceived;
  ULONG NetbiosSent;
} IPX_IF_STATS,*PIPX_IF_STATS;

typedef struct _IPX_INTERFACE {
  ULONG InterfaceIndex;
  ULONG AdminState;
  ULONG AdapterIndex;
  UCHAR InterfaceName[IPX_INTERFACE_ANSI_NAME_LEN];
  ULONG InterfaceType;
  ULONG MediaType;
  UCHAR NetNumber[4];
  UCHAR MacAddress[6];
  ULONG Delay;
  ULONG Throughput;
  ULONG NetbiosAccept;
  ULONG NetbiosDeliver;
  ULONG EnableIpxWanNegotiation;
  IPX_IF_STATS IfStats;
} IPX_INTERFACE,*PIPX_INTERFACE;

typedef struct _IPX_ROUTE {
  ULONG InterfaceIndex;
  ULONG Protocol;
  UCHAR Network[4];
  USHORT TickCount;
  USHORT HopCount;
  UCHAR NextHopMacAddress[6];
  ULONG Flags;
} IPX_ROUTE,*PIPX_ROUTE;

typedef union _IPX_MIB_ROW {
  IPX_INTERFACE Interface;
  IPX_ROUTE Route;
  IPX_SERVICE Service;
} IPX_MIB_ROW,*PIPX_MIB_ROW;

typedef struct _IPX_MIB_SET_INPUT_DATA {
  ULONG TableId;
  IPX_MIB_ROW MibRow;
} IPX_MIB_SET_INPUT_DATA,*PIPX_MIB_SET_INPUT_DATA;
#endif
