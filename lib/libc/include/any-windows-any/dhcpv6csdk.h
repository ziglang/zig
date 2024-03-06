/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_DHCPV6CSDK
#define _INC_DHCPV6CSDK

#ifdef __cplusplus
extern "C" {
#endif

#if (_WIN32_WINNT >= 0x0600)

#include <winapifamily.h>

#ifndef DHCPV6_OPTIONS_DEFINED
#define DHCPV6_OPTIONS_DEFINED

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

#define DHCPV6_OPTION_CLIENTID 1
#define DHCPV6_OPTION_SERVERID 2
#define DHCPV6_OPTION_IA_NA 3
#define DHCPV6_OPTION_IA_TA 4
#define DHCPV6_OPTION_ORO 6
#define DHCPV6_OPTION_PREFERENCE 7
#define DHCPV6_OPTION_UNICAST 12
#define DHCPV6_OPTION_RAPID_COMMIT 14
#define DHCPV6_OPTION_USER_CLASS 15
#define DHCPV6_OPTION_VENDOR_CLASS 16
#define DHCPV6_OPTION_VENDOR_OPTS 17
#define DHCPV6_OPTION_RECONF_MSG 19

#define DHCPV6_OPTION_SIP_SERVERS_NAMES 21
#define DHCPV6_OPTION_SIP_SERVERS_ADDRS 22
#define DHCPV6_OPTION_DNS_SERVERS 23
#define DHCPV6_OPTION_DOMAIN_LIST 24
#define DHCPV6_OPTION_IA_PD 25
#define DHCPV6_OPTION_NIS_SERVERS 27
#define DHCPV6_OPTION_NISP_SERVERS 28
#define DHCPV6_OPTION_NIS_DOMAIN_NAME 29
#define DHCPV6_OPTION_NISP_DOMAIN_NAME 30

#endif /* WINAPI_PARTITION_APP */

#endif /* DHCPV6_OPTIONS_DEFINED */

typedef enum _StatusCode {
  STATUS_NO_ERROR,
  STATUS_UNSPECIFIED_FAILURE,
  STATUS_NO_BINDING = 3,
  STATUS_NOPREFIX_AVAIL = 6
} StatusCode;

typedef struct _DHCPV6CAPI_CLASSID {
  ULONG  Flags;
  LPBYTE Data;
  ULONG  nBytesData;
} DHCPV6CAPI_CLASSID, *PDHCPV6CAPI_CLASSID, *LPDHCPV6CAPI_CLASSID;

#ifndef DHCPV6API_PARAMS_DEFINED
#define DHCPV6API_PARAMS_DEFINED

typedef struct _DHCPV6CAPI_PARAMS {
  ULONG   Flags;
  ULONG   OptionId;
  WINBOOL IsVendor;
  LPBYTE  Data;
  DWORD   nBytesData;
} DHCPV6CAPI_PARAMS, *PDHCPV6CAPI_PARAMS, *LPDHCPV6CAPI_PARAMS;

#endif /* DHCPV6API_PARAMS_DEFINED */

typedef struct _DHCPV6Prefix {
  UCHAR      prefix[16];
  DWORD      prefixLength;
  DWORD      preferredLifeTime;
  DWORD      validLifeTime;
  StatusCode status;
} DHCPV6Prefix, *PDHCPV6Prefix, *LPDHCPV6Prefix;

typedef struct _DHCPV6CAPI_PARAMS_ARRAY {
  ULONG               nParams;
  LPDHCPV6CAPI_PARAMS Params;
} DHCPV6CAPI_PARAMS_ARRAY, *PDHCPV6CAPI_PARAMS_ARRAY, *LPDHCPV6CAPI_PARAMS_ARRAY;

typedef struct _DHCPV6PrefixLeaseInformation {
  DWORD          nPrefixes;
  LPDHCPV6Prefix prefixArray;
  DWORD          iaid;
  time_t         T1;
  time_t         T2;
  time_t         MaxLeaseExpirationTime;
  time_t         LastRenewalTime;
  StatusCode     status;
  LPBYTE         ServerId;
  DWORD          ServerIdLen;
} DHCPV6PrefixLeaseInformation, *PDHCPV6PrefixLeaseInformation, *LPDHCPV6PrefixLeaseInformation, *LPDHCPV6CAPIPrefixLeaseInformation;

VOID APIENTRY Dhcpv6CApiCleanup(void);

VOID APIENTRY Dhcpv6CApiInitialize(
  LPDWORD Version
);

DWORD APIENTRY Dhcpv6RequestParams(
  WINBOOL forceNewInform,
  LPVOID reserved,
  LPWSTR adapterName,
  LPDHCPV6CAPI_CLASSID classId,
  DHCPV6CAPI_PARAMS_ARRAY recdParams,
  LPBYTE buffer,
  LPDWORD pSize
);

DWORD APIENTRY Dhcpv6ReleasePrefix(
  LPWSTR adapterName,
  LPDHCPV6CAPI_CLASSID classId,
  LPDHCPV6CAPIPrefixLeaseInformation prefixleaseInfo
);

DWORD APIENTRY Dhcpv6RenewPrefix(
  LPWSTR adapterName,
  LPDHCPV6CAPI_CLASSID classId,
  LPDHCPV6PrefixLeaseInformation prefixleaseInfo,
  DWORD *pdwTimeToWait,
  DWORD bValidatePrefix
);

DWORD APIENTRY Dhcpv6RequestPrefix(
  LPWSTR adapterName,
  LPDHCPV6CAPI_CLASSID classId,
  LPDHCPV6PrefixLeaseInformation prefixleaseInfo,
  DWORD *pdwTimeToWait
);

#endif /* (_WIN32_WINNT >= 0x0600) */

#ifdef __cplusplus
}
#endif

#endif /*_INC_DHCPV6CSDK*/
