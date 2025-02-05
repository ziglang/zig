/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _TCPXCV_
#define _TCPXCV_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#if !defined(UNKNOWN_PROTOCOL)
#define UNKNOWN_PROTOCOL 0
#define PROTOCOL_UNKNOWN_TYPE UNKNOWN_PROTOCOL
#endif

#if !defined(RAWTCP)
#define RAWTCP 1
#define PROTOCOL_RAWTCP_TYPE RAWTCP
#endif

#if !defined(LPR)
#define LPR 2
#define PROTOCOL_LPR_TYPE LPR
#endif

#define MAX_PORTNAME_LEN 64
#define MAX_NETWORKNAME_LEN 49
#define MAX_NETWORKNAME2_LEN 128
#define MAX_SNMP_COMMUNITY_STR_LEN 33
#define MAX_QUEUENAME_LEN 33
#define MAX_IPADDR_STR_LEN 16
#define MAX_ADDRESS_STR_LEN 13
#define MAX_DEVICEDESCRIPTION_STR_LEN 257

typedef struct _PORT_DATA_1 {
  WCHAR sztPortName[MAX_PORTNAME_LEN];
  DWORD dwVersion;
  DWORD dwProtocol;
  DWORD cbSize;
  DWORD dwReserved;
  WCHAR sztHostAddress[MAX_NETWORKNAME_LEN];
  WCHAR sztSNMPCommunity[MAX_SNMP_COMMUNITY_STR_LEN];
  DWORD dwDoubleSpool;
  WCHAR sztQueue[MAX_QUEUENAME_LEN];
  WCHAR sztIPAddress[MAX_IPADDR_STR_LEN];
  BYTE Reserved[540];
  DWORD dwPortNumber;
  DWORD dwSNMPEnabled;
  DWORD dwSNMPDevIndex;
} PORT_DATA_1, *PPORT_DATA_1;

typedef struct _PORT_DATA_2 {
  WCHAR sztPortName[MAX_PORTNAME_LEN];
  DWORD dwVersion;
  DWORD dwProtocol;
  DWORD cbSize;
  DWORD dwReserved;
  WCHAR sztHostAddress [MAX_NETWORKNAME2_LEN];
  WCHAR sztSNMPCommunity[MAX_SNMP_COMMUNITY_STR_LEN];
  DWORD dwDoubleSpool;
  WCHAR sztQueue[MAX_QUEUENAME_LEN];
  BYTE Reserved[514];
  DWORD dwPortNumber;
  DWORD dwSNMPEnabled;
  DWORD dwSNMPDevIndex;
  DWORD dwPortMonitorMibIndex;
} PORT_DATA_2, *PPORT_DATA_2;

typedef struct _PORT_DATA_LIST_1 {
  DWORD dwVersion;
  DWORD cPortData;
  PORT_DATA_2 pPortData[1];
} PORT_DATA_LIST_1, *PPORT_DATA_LIST_1;

typedef struct _DELETE_PORT_DATA_1 {
  WCHAR psztPortName[MAX_PORTNAME_LEN];
  BYTE Reserved[98];
  DWORD dwVersion;
  DWORD dwReserved;
} DELETE_PORT_DATA_1, *PDELETE_PORT_DATA_1;

typedef struct _CONFIG_INFO_DATA_1 {
  BYTE Reserved[128];
  DWORD dwVersion;
} CONFIG_INFO_DATA_1, *PCONFIG_INFO_DATA_1;

#endif /* WINAPI_PARTITION_DESKTOP */

#endif /* _TCPXCV_ */
