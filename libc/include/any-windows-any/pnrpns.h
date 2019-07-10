/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _PNRPNS_H_
#define _PNRPNS_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include "pnrpdef.h"

#ifndef NS_PNRPNAME
#define NS_PNRPNAME (38)
#endif

#ifndef NS_PNRPCLOUD
#define NS_PNRPCLOUD (39)
#endif

#define PNRPINFO_HINT 0x1

typedef struct _PNRPINFO_V1 {
  DWORD dwSize;
  LPWSTR lpwszIdentity;
  DWORD nMaxResolve;
  DWORD dwTimeout;
  DWORD dwLifetime;
  PNRP_RESOLVE_CRITERIA enResolveCriteria;
  DWORD dwFlags;
  SOCKET_ADDRESS saHint;
  PNRP_REGISTERED_ID_STATE enNameState;
} PNRPINFO_V1,*PPNRPINFO_V1;

typedef struct _PNRPINFO_V2 {
  DWORD dwSize;
  LPWSTR lpwszIdentity;
  DWORD nMaxResolve;
  DWORD dwTimeout;
  DWORD dwLifetime;
  PNRP_RESOLVE_CRITERIA enResolveCriteria;
  DWORD dwFlags;
  SOCKET_ADDRESS saHint;
  PNRP_REGISTERED_ID_STATE enNameState;
  PNRP_EXTENDED_PAYLOAD_TYPE enExtendedPayloadType;
  __C89_NAMELESS union {
    BLOB blobPayload;
    PWSTR pwszPayload;
  };
} PNRPINFO_V2,*PPNRPINFO_V2;

#ifdef PNRP_USE_V1_API
typedef PNRPINFO_V1 PNRPINFO;
typedef PPNRPINFO_V1 PPNRPINFO;
#else
typedef PNRPINFO_V2 PNRPINFO;
typedef PPNRPINFO_V2 PPNRPINFO;
#endif

typedef struct _PNRPCLOUDINFO {
  DWORD dwSize;
  PNRP_CLOUD_ID Cloud;
  PNRP_CLOUD_STATE enCloudState;
  PNRP_CLOUD_FLAGS enCloudFlags;
} PNRPCLOUDINFO,*PPNRPCLOUDINFO;

#endif
#endif

#ifdef DEFINE_GUID
DEFINE_GUID (NS_PROVIDER_PNRPNAME, 0x03fe89cd, 0x766d, 0x4976, 0xb9, 0xc1, 0xbb, 0x9b, 0xc4, 0x2c, 0x7b, 0x4d);
DEFINE_GUID (NS_PROVIDER_PNRPCLOUD, 0x03fe89ce, 0x766d, 0x4976, 0xb9, 0xc1, 0xbb, 0x9b, 0xc4, 0x2c, 0x7b, 0x4d);
DEFINE_GUID (SVCID_PNRPCLOUD, 0xc2239ce6, 0x00c0, 0x4fbf, 0xba, 0xd6, 0x18, 0x13, 0x93, 0x85, 0xa4, 0x9a);
DEFINE_GUID (SVCID_PNRPNAME_V1, 0xc2239ce5, 0x00c0, 0x4fbf, 0xba, 0xd6, 0x18, 0x13, 0x93, 0x85, 0xa4, 0x9a);
DEFINE_GUID (SVCID_PNRPNAME_V2, 0xc2239ce7, 0x00c0, 0x4fbf, 0xba, 0xd6, 0x18, 0x13, 0x93, 0x85, 0xa4, 0x9a);
#ifdef PNRP_USE_V1_API
#define SVCID_PNRPNAME SVCID_PNRPNAME_V1
#else
#define SVCID_PNRPNAME SVCID_PNRPNAME_V2
#endif
#endif
