/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EVCOLL
#define _INC_EVCOLL
#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

typedef enum _EC_SUBSCRIPTION_CONFIGURATION_MODE {
  EcConfigurationModeNormal         = 0,
  EcConfigurationModeCustom         = 1,
  EcConfigurationModeMinLatency     = 2,
  EcConfigurationModeMinBandwidth   = 3 
} EC_SUBSCRIPTION_CONFIGURATION_MODE;

typedef enum _EC_SUBSCRIPTION_CONTENT_FORMAT {
  EcContentFormatEvents         = 1,
  EcContentFormatRenderedText   = 2 
} EC_SUBSCRIPTION_CONTENT_FORMAT;

typedef enum _EC_SUBSCRIPTION_CREDENTIALS_TYPE {
  EcSubscriptionCredDefault        = 0,
  EcSubscriptionCredNegotiate      = 1,
  EcSubscriptionCredDigest         = 2,
  EcSubscriptionCredBasic          = 3,
  EcSubscriptionCredLocalMachine   = 4 
} EC_SUBSCRIPTION_CREDENTIALS_TYPE;

typedef enum _EC_SUBSCRIPTION_DELIVERY_MODE {
  EcDeliveryModePull   = 1,
  EcDeliveryModePush   = 2 
} EC_SUBSCRIPTION_DELIVERY_MODE;

typedef enum _EC_SUBSCRIPTION_PROPERTY_ID {
  EcSubscriptionEnabled                        = 0,
  EcSubscriptionEventSources                   = 1,
  EcSubscriptionEventSourceAddress             = 2,
  EcSubscriptionEventSourceEnabled             = 3,
  EcSubscriptionEventSourceUserName            = 4,
  EcSubscriptionEventSourcePassword            = 5,
  EcSubscriptionDescription                    = 6,
  EcSubscriptionURI                            = 7,
  EcSubscriptionConfigurationMode              = 8,
  EcSubscriptionExpires                        = 9,
  EcSubscriptionQuery                          = 10,
  EcSubscriptionTransportName                  = 11,
  EcSubscriptionTransportPort                  = 12,
  EcSubscriptionDeliveryMode                   = 13,
  EcSubscriptionDeliveryMaxItems               = 14,
  EcSubscriptionDeliveryMaxLatencyTime         = 15,
  EcSubscriptionHeartbeatInterval              = 16,
  EcSubscriptionLocale                         = 17,
  EcSubscriptionContentFormat                  = 18,
  EcSubscriptionLogFile                        = 19,
  EcSubscriptionPublisherName                  = 20,
  EcSubscriptionCredentialsType                = 21,
  EcSubscriptionCommonUserName                 = 22,
  EcSubscriptionCommonPassword                 = 23,
  EcSubscriptionHostName                       = 24,
  EcSubscriptionReadExistingEvents             = 25,
  EcSubscriptionDialect                        = 26,
  EcSubscriptionType                           = 27,
  EcSubscriptionAllowedIssuerCAs               = 28,
  EcSubscriptionAllowedSubjects                = 29,
  EcSubscriptionDeniedSubjects                 = 30,
  EcSubscriptionAllowedSourceDomainComputers   = 31 
} EC_SUBSCRIPTION_PROPERTY_ID;

typedef enum _EC_SUBSCRIPTION_RUNTIME_STATUS_ACTIVE_STATUS {
  EcRuntimeStatusActiveStatusDisabled   = 1,
  EcRuntimeStatusActiveStatusActive     = 2,
  EcRuntimeStatusActiveStatusInactive   = 3,
  EcRuntimeStatusActiveStatusTrying     = 4 
} EC_SUBSCRIPTION_RUNTIME_STATUS_ACTIVE_STATUS;

typedef enum _EC_SUBSCRIPTION_TYPE {
  EcSubscriptionTypeSourceInitiated      = 0,
  EcSubscriptionTypeCollectorInitiated   = 1 
} EC_SUBSCRIPTION_TYPE;

typedef enum _EC_SUBSCRIPTION_RUNTIME_STATUS_INFO_ID {
  EcSubscriptionRunTimeStatusActive              = 0,
  EcSubscriptionRunTimeStatusLastError           = 1,
  EcSubscriptionRunTimeStatusLastErrorMessage    = 2,
  EcSubscriptionRunTimeStatusLastErrorTime       = 3,
  EcSubscriptionRunTimeStatusNextRetryTime       = 4,
  EcSubscriptionRunTimeStatusEventSources        = 5,
  EcSubscriptionRunTimeStatusLastHeartbeatTime   = 6 
} EC_SUBSCRIPTION_RUNTIME_STATUS_INFO_ID;

typedef struct _EC_VARIANT {
  __C89_NAMELESS union {
    BOOL      BooleanVal;
    UINT32    UInt32Val;
    ULONGLONG DateTimeVal;
    LPCWSTR   StringVal;
    PBYTE     BinaryVal;
    WINBOOL   *BooleanArr;
    INT32*    Int32Arr;
    LPWSTR    *StringArr;
  };
  DWORD Count;
  DWORD Type;
} EC_VARIANT, *PEC_VARIANT;

typedef enum _EC_VARIANT_TYPE {
  EcVarTypeNull                    = 0,
  EcVarTypeBoolean                 = 1,
  EcVarTypeUInt32                  = 2,
  EcVarTypeDateTime                = 3,
  EcVarTypeString                  = 4,
  EcVarObjectArrayPropertyHandle   = 5 
} EC_VARIANT_TYPE;

typedef LPVOID EC_HANDLE;

WINBOOL WINAPI EcClose(
  EC_HANDLE Object
);

WINBOOL WINAPI EcDeleteSubscription(
  LPCWSTR SubscriptionName,
  DWORD Flags
);

WINBOOL WINAPI EcEnumNextSubscription(
  EC_HANDLE SubscriptionEnum,
  DWORD SubscriptionNameBufferSize,
  LPWSTR SubscriptionNameBuffer,
  PDWORD SubscriptionNameBufferUsed
);

WINBOOL WINAPI EcGetObjectArrayProperty(
  EC_OBJECT_ARRAY_PROPERTY_HANDLE ObjectArray,
  EC_SUBSCRIPTION_PROPERTY_ID PropertyId,
  DWORD ArrayIndex,
  DWORD Flags,
  DWORD PropertyValueBufferSize,
  PEC_VARIANT PropertyValueBuffer,
  PDWORD PropertyValueBufferUsed
);

WINBOOL WINAPI EcGetObjectArraySize(
  EC_OBJECT_ARRAY_PROPERTY_HANDLE ObjectArray,
  PDWORD ObjectArraySize
);

WINBOOL WINAPI EcGetSubscriptionProperty(
  EC_HANDLE Subscription,
  EC_SUBSCRIPTION_PROPERTY_ID PropertyId,
  DWORD Flags,
  DWORD PropertyValueBufferSize,
  PEC_VARIANT PropertyValueBuffer,
  PDWORD PropertyValueBufferUsed
);

WINBOOL WINAPI EcGetSubscriptionRunTimeStatus(
  LPCWSTR SubscriptionName,
  EC_SUBSCRIPTION_RUNTIME_STATUS_INFO_ID StatusInfoId,
  LPCWSTR EventSourceName,
  DWORD Flags,
  DWORD StatusValueBufferSize,
  PEC_VARIANT StatusValueBuffer,
  PDWORD StatusValueBufferUsed
);

WINBOOL WINAPI EcInsertObjectArrayElement(
  EC_OBJECT_ARRAY_PROPERTY_HANDLE ObjectArray,
  DWORD ArrayIndex
);

EC_HANDLE WINAPI EcOpenSubscription(
  LPCWSTR SubscriptionName,
  DWORD AccessMask,
  DWORD Flags
);

EC_HANDLE WINAPI EcOpenSubscriptionEnum(
  DWORD Flags
);

WINBOOL WINAPI EcRemoveObjectArrayElement(
  EC_OBJECT_ARRAY_PROPERTY_HANDLE ObjectArray,
  DWORD ArrayIndex
);

WINBOOL WINAPI EcRetrySubscription(
  LPCWSTR SubscriptionName,
  LPCWSTR EventSourceName,
  DWORD Flags
);

WINBOOL WINAPI EcSaveSubscription(
  EC_HANDLE Subscription,
  DWORD Flags
);

WINBOOL WINAPI EcSetObjectArrayProperty(
  EC_OBJECT_ARRAY_PROPERTY_HANDLE ObjectArray,
  EC_SUBSCRIPTION_PROPERTY_ID PropertyId,
  DWORD ArrayIndex,
  DWORD Flags,
  PEC_VARIANT PropertyValue
);

WINBOOL WINAPI EcSetSubscriptionProperty(
  EC_HANDLE Subscription,
  EC_SUBSCRIPTION_PROPERTY_ID PropertyId,
  DWORD Flags,
  PEC_VARIANT PropertyValue
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EVCOLL*/
