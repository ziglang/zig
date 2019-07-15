/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef _ADTGEN_H
#define _ADTGEN_H

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#define AUDIT_TYPE_LEGACY 1
#define AUDIT_TYPE_WMI 2

typedef enum _AUDIT_PARAM_TYPE {
  APT_None = 1,
  APT_String,
  APT_Ulong,
  APT_Pointer,
  APT_Sid,
  APT_LogonId,
  APT_ObjectTypeList,
  APT_Luid,
  APT_Guid,
  APT_Time,
  APT_Int64,
  APT_IpAddress,
  APT_LogonIdWithSid
} AUDIT_PARAM_TYPE;

#define AP_ParamTypeBits 8
#define AP_ParamTypeMask __MSABI_LONG(0xff)

#define AP_FormatHex (__MSABI_LONG(0x1) << AP_ParamTypeBits)
#define AP_AccessMask (__MSABI_LONG(0x2) << AP_ParamTypeBits)
#define AP_Filespec (__MSABI_LONG(0x1) << AP_ParamTypeBits)
#define AP_SidAsLogonId (__MSABI_LONG(0x1) << AP_ParamTypeBits)
#define AP_PrimaryLogonId (__MSABI_LONG(0x1) << AP_ParamTypeBits)
#define AP_ClientLogonId (__MSABI_LONG(0x2) << AP_ParamTypeBits)
#define ApExtractType(TypeFlags) ((AUDIT_PARAM_TYPE) (TypeFlags & AP_ParamTypeMask))
#define ApExtractFlags(TypeFlags) ((TypeFlags & ~AP_ParamTypeMask))

#define _AUTHZ_SS_MAXSIZE 128

#define APF_AuditFailure 0x0
#define APF_AuditSuccess 0x1

#define APF_ValidFlags (APF_AuditSuccess)

#define AUTHZ_ALLOW_MULTIPLE_SOURCE_INSTANCES 0x1
#define AUTHZ_MIGRATED_LEGACY_PUBLISHER 0x2

#define AUTHZ_AUDIT_INSTANCE_INFORMATION 0x2

typedef struct _AUDIT_OBJECT_TYPE {
  GUID ObjectType;
  USHORT Flags;
  USHORT Level;
  ACCESS_MASK AccessMask;
} AUDIT_OBJECT_TYPE,*PAUDIT_OBJECT_TYPE;

typedef struct _AUDIT_OBJECT_TYPES {
  USHORT Count;
  USHORT Flags;
#ifdef __WIDL__
  [size_is (Count)]
#endif
  AUDIT_OBJECT_TYPE *pObjectTypes;
} AUDIT_OBJECT_TYPES,*PAUDIT_OBJECT_TYPES;

typedef struct _AUDIT_IP_ADDRESS {
  BYTE pIpAddress[_AUTHZ_SS_MAXSIZE];
} AUDIT_IP_ADDRESS,*PAUDIT_IP_ADDRESS;

typedef struct _AUDIT_PARAM {
  AUDIT_PARAM_TYPE Type;
  ULONG Length;
  DWORD Flags;
#ifdef __WIDL__
  [switch_type (AUDIT_PARAM_TYPE), switch_is (Type)]
#else
  __C89_NAMELESS
#endif
  union {
#ifdef __WIDL__
    [default]
#endif
    ULONG_PTR Data0;
#ifdef __WIDL__
    [case (APT_String)]
    [string]
#endif
    PWSTR String;
#ifdef __WIDL__
    [case (APT_Ulong, APT_Pointer)]
#endif
    ULONG_PTR u;
#ifdef __WIDL__
    [case (APT_Sid)]
#endif
    SID *psid;
#ifdef __WIDL__
    [case (APT_Guid)]
#endif
    GUID *pguid;
#ifdef __WIDL__
    [case (APT_LogonId)]
#endif
    ULONG LogonId_LowPart;
#ifdef __WIDL__
    [case (APT_ObjectTypeList)]
#endif
    AUDIT_OBJECT_TYPES *pObjectTypes;
#ifdef __WIDL__
    [case (APT_IpAddress)]
#endif
    AUDIT_IP_ADDRESS *pIpAddress;
  };
#ifdef __WIDL__
  [switch_type (AUDIT_PARAM_TYPE), switch_is (Type)]
#else
  __C89_NAMELESS
#endif
  union {
#ifdef __WIDL__
    [default]
#endif
    ULONG_PTR Data1;
#ifdef __WIDL__
    [case (APT_LogonId)]
#endif
    LONG LogonId_HighPart;
  };
} AUDIT_PARAM,*PAUDIT_PARAM;

typedef struct _AUDIT_PARAMS {
  ULONG Length;
  DWORD Flags;
  USHORT Count;
#ifdef __WIDL__
  [size_is (Count)]
#endif
  AUDIT_PARAM *Parameters;
} AUDIT_PARAMS,*PAUDIT_PARAMS;
typedef struct _AUTHZ_AUDIT_EVENT_TYPE_LEGACY {
  USHORT CategoryId;
  USHORT AuditId;
  USHORT ParameterCount;
} AUTHZ_AUDIT_EVENT_TYPE_LEGACY,*PAUTHZ_AUDIT_EVENT_TYPE_LEGACY;

typedef
#ifdef __WIDL__
[switch_type (BYTE)]
#endif
union _AUTHZ_AUDIT_EVENT_TYPE_UNION {
#ifdef __WIDL__
  [case (AUDIT_TYPE_LEGACY)]
#endif
  AUTHZ_AUDIT_EVENT_TYPE_LEGACY Legacy;
} AUTHZ_AUDIT_EVENT_TYPE_UNION,*PAUTHZ_AUDIT_EVENT_TYPE_UNION;

typedef
struct _AUTHZ_AUDIT_EVENT_TYPE_OLD {
  ULONG Version;
  DWORD dwFlags;
  LONG RefCount;
  ULONG_PTR hAudit;
  LUID LinkId;
#ifdef __WIDL__
  [switch_is (Version)]
#endif
  AUTHZ_AUDIT_EVENT_TYPE_UNION u;
} AUTHZ_AUDIT_EVENT_TYPE_OLD;

typedef
#ifdef __WIDL__
[handle]
#endif
AUTHZ_AUDIT_EVENT_TYPE_OLD *PAUTHZ_AUDIT_EVENT_TYPE_OLD;
#define AUTHZP_WPD_EVENT 0x10

typedef
#ifdef __WIDL__
[context_handle]
#endif
PVOID AUDIT_HANDLE,*PAUDIT_HANDLE;

#endif
#endif
