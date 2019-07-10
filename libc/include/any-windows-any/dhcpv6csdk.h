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

typedef enum _StatusCode {
  STATUS_NO_ERROR,
  STATUS_UNSPECIFIED_FAILURE,
  STATUS_NO_BINDING,
  STATUS_NOPREFIX_AVAIL 
} StatusCode;

typedef struct _DHCPV6CAPI_CLASSID {
  ULONG  Flags;
  LPBYTE Data;
  ULONG  nBytesData;
} DHCPV6CAPI_CLASSID, *PDHCPV6CAPI_CLASSID, *LPDHCPV6CAPI_CLASSID;

typedef struct _DHCPV6CAPI_PARAMS {
  ULONG   Flags;
  ULONG   OptionId;
  WINBOOL IsVendor;
  LPBYTE  Data;
  DWORD   nBytesData;
} DHCPV6CAPI_PARAMS, *PDHCPV6CAPI_PARAMS, *LPDHCPV6CAPI_PARAMS;

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

DWORD APIENTRY Dhcpv6CApiInitialize(
  LPDWORD Version
);

DWORD APIENTRY Dhcpv6RenewPrefix(
  LPWSTR adapterName,
  LPDHCPV6CAPI_CLASSID classId,
  LPDHCPV6CAPIPrefixLeaseInformation prefixleaseInfo
);

DWORD APIENTRY Dhcpv6RenewPrefix(
  LPWSTR adapterName,
  LPDHCPV6CAPI_CLASSID classId,
  LPDHCPV6PrefixLeaseInformation prefixleaseInfo,
  DWORD pdwTimeToWait,
  DWORD bValidatePrefix
);

DWORD APIENTRY Dhcpv6RequestPrefix(
  LPWSTR adapterName,
  LPDHCPV6CAPI_CLASSID classId,
  LPDHCPV6PrefixLeaseInformation prefixleaseInfo,
  DWORD pdwTimeToWait
);

#endif /* (_WIN32_WINNT >= 0x0600) */

#ifdef __cplusplus
}
#endif

#endif /*_INC_DHCPV6CSDK*/
