/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_FWPMTYPES
#define _INC_FWPMTYPES
#include <fwptypes.h>
#include <ipsectypes.h>
#include <iketypes.h>

#ifdef __cplusplus
extern "C" {
#endif
#if (_WIN32_WINNT >= 0x0600)

typedef enum FWPM_PROVIDER_CONTEXT_TYPE_ {
  FWPM_IPSEC_KEYING_CONTEXT,
  FWPM_IPSEC_IKE_QM_TRANSPORT_CONTEXT,
  FWPM_IPSEC_IKE_QM_TUNNEL_CONTEXT,
  FWPM_IPSEC_AUTHIP_QM_TRANSPORT_CONTEXT,
  FWPM_IPSEC_AUTHIP_QM_TUNNEL_CONTEXT,
  FWPM_IPSEC_IKE_MM_CONTEXT,
  FWPM_IPSEC_AUTHIP_MM_CONTEXT,
  FWPM_CLASSIFY_OPTIONS_CONTEXT,
  FWPM_GENERAL_CONTEXT,
  FWPM_IPSEC_IKEV2_QM_TUNNEL_CONTEXT,
  FWPM_IPSEC_IKEV2_MM_CONTEXT,
  FWPM_DOSP_CONTEXT,
  FWPM_PROVIDER_CONTEXT_TYPE_MAX 
} FWPM_PROVIDER_CONTEXT_TYPE;

typedef enum FWPM_NET_EVENT_TYPE_ {
  FWPM_NET_EVENT_TYPE_IKEEXT_MM_FAILURE,
  FWPM_NET_EVENT_TYPE_IKEEXT_QM_FAILURE,
  FWPM_NET_EVENT_TYPE_IKEEXT_EM_FAILURE,
  FWPM_NET_EVENT_TYPE_CLASSIFY_DROP,
  FWPM_NET_EVENT_TYPE_IPSEC_KERNEL_DROP,
  FWPM_NET_EVENT_TYPE_IPSEC_DOSP_DROP,
  FWPM_NET_EVENT_TYPE_MAX 
} FWPM_NET_EVENT_TYPE;

typedef struct FWPM_ACTION0_ {
  FWP_ACTION_TYPE type;
  __C89_NAMELESS union {
    GUID filterType;
    GUID calloutKey;
  };
} FWPM_ACTION0;

typedef struct FWPM_DISPLAY_DATA0_ {
  wchar_t *name;
  wchar_t *description;
} FWPM_DISPLAY_DATA0;

typedef struct FWPM_SESSION0_ {
  GUID               sessionKey;
  FWPM_DISPLAY_DATA0 displayData;
  UINT32             flags;
  UINT32             txnWaitTimeoutInMSec;
  DWORD              processId;
  SID                *sid;
  wchar_t            *username;
  WINBOOL            kernelMode;
} FWPM_SESSION0;

typedef struct FWPM_CALLOUT_ENUM_TEMPLATE0_ {
  GUID *providerKey;
  GUID layerKey;
} FWPM_CALLOUT_ENUM_TEMPLATE0;

typedef struct FWPM_CALLOUT_SUBSCRIPTION0_ {
  FWPM_CALLOUT_ENUM_TEMPLATE0 *enumTemplate;
  UINT32                      flags;
  GUID                        sessionKey;
} FWPM_CALLOUT_SUBSCRIPTION0;

typedef enum FWPM_CHANGE_TYPE_ {
  FWPM_CHANGE_ADD        = 1,
  FWPM_CHANGE_DELETE,
  FWPM_CHANGE_TYPE_MAX 
} FWPM_CHANGE_TYPE;

typedef struct FWPM_CALLOUT_CHANGE0_ {
  FWPM_CHANGE_TYPE changeType;
  GUID             calloutKey;
  UINT32           calloutId;
} FWPM_CALLOUT_CHANGE0;

typedef struct FWPM_CALLOUT0_ {
  GUID               calloutKey;
  FWPM_DISPLAY_DATA0 displayData;
  UINT32             flags;
  GUID               *providerKey;
  FWP_BYTE_BLOB      providerData;
  GUID               applicableLayer;
  UINT32             calloutId;
} FWPM_CALLOUT0;

typedef struct FWPM_CLASSIFY_OPTION0_ {
  FWP_CLASSIFY_OPTION_TYPE type;
  FWP_VALUE0               value;
} FWPM_CLASSIFY_OPTION0;

typedef struct FWPM_CLASSIFY_OPTIONS0_ {
  UINT32                numOptions;
  FWPM_CLASSIFY_OPTION0 *options;
} FWPM_CLASSIFY_OPTIONS0;

typedef enum FWPM_ENGINE_OPTION_ {
  FWPM_ENGINE_COLLECT_NET_EVENTS,
  FWPM_ENGINE_NET_EVENT_MATCH_ANY_KEYWORDS,
  FWPM_ENGINE_NAME_CACHE,
  FWPM_ENGINE_OPTION_MAX 
} FWPM_ENGINE_OPTION;

typedef enum FWPM_FIELD_TYPE_ {
  FWPM_FIELD_RAW_DATA,
  FWPM_FIELD_IP_ADDRESS,
  FWPM_FIELD_FLAGS,
  FWPM_FIELD_TYPE_MAX 
} FWPM_FIELD_TYPE;

typedef struct FWPM_FIELD0_ {
  GUID            *fieldKey;
  FWPM_FIELD_TYPE type;
  FWP_DATA_TYPE   dataType;
} FWPM_FIELD0;

typedef struct FWPM_FILTER_CHANGE0_ {
  FWPM_CHANGE_TYPE changeType;
  GUID             filterKey;
  UINT64           filterId;
} FWPM_FILTER_CHANGE0;

typedef struct FWPM_FILTER_CONDITION0_ {
  GUID                 fieldKey;
  FWP_MATCH_TYPE       matchType;
  FWP_CONDITION_VALUE0 conditionValue;
} FWPM_FILTER_CONDITION0;

typedef struct FWPM_PROVIDER_CONTEXT_ENUM_TEMPLATE0_ {
  GUID                       *providerKey;
  FWPM_PROVIDER_CONTEXT_TYPE providerContextType;
} FWPM_PROVIDER_CONTEXT_ENUM_TEMPLATE0;

typedef struct FWPM_FILTER_ENUM_TEMPLATE0_ {
  GUID                                 *providerKey;
  GUID                                 layerKey;
  FWP_FILTER_ENUM_TYPE                 enumType;
  UINT32                               flags;
  FWPM_PROVIDER_CONTEXT_ENUM_TEMPLATE0 *providerContextTemplate;
  UINT32                               numFilterConditions;
  FWPM_FILTER_CONDITION0               *filterCondition;
  UINT32                               actionMask;
  GUID                                 *calloutKey;
} FWPM_FILTER_ENUM_TEMPLATE0;

typedef struct FWPM_FILTER_SUBSCRIPTION0_ {
  FWPM_FILTER_ENUM_TEMPLATE0 *enumTemplate;
  UINT32                     flags;
  GUID                       sessionKey;
} FWPM_FILTER_SUBSCRIPTION0;

typedef struct FWPM_FILTER0_ {
  GUID                   filterKey;
  FWPM_DISPLAY_DATA0     displayData;
  UINT32                 flags;
  GUID                   *providerKey;
  FWP_BYTE_BLOB          providerData;
  GUID                   layerKey;
  GUID                   subLayerKey;
  FWP_VALUE0             weight;
  UINT32                 numFilterConditions;
  FWPM_FILTER_CONDITION0 *filterCondition;
  FWPM_ACTION0           action;
  __C89_NAMELESS union {
    UINT64 rawContext;
    GUID   providerContextKey;
  };
  GUID                   *reserved;
  UINT64                 filterId;
  FWP_VALUE0             effectiveWeight;
} FWPM_FILTER0;

typedef struct FWPM_LAYER_ENUM_TEMPLATE0_ {
  UINT64 reserved;
} FWPM_LAYER_ENUM_TEMPLATE0;

typedef struct FWPM_LAYER0_ {
  GUID               layerKey;
  FWPM_DISPLAY_DATA0 displayData;
  UINT32             flags;
  UINT32             numFields;
  FWPM_FIELD0        *field;
  GUID               defaultSubLayerKey;
  UINT16             layerId;
} FWPM_LAYER0;

typedef struct FWPM_NET_EVENT_CLASSIFY_DROP0_ {
  UINT64 filterId;
  UINT16 layerId;
} FWPM_NET_EVENT_CLASSIFY_DROP0;

typedef struct FWPM_NET_EVENT_ENUM_TEMPLATE0_ {
  FILETIME               startTime;
  FILETIME               endTime;
  UINT32                 numFilterConditions;
  FWPM_FILTER_CONDITION0 *filterCondition;
} FWPM_NET_EVENT_ENUM_TEMPLATE0;

typedef struct FWPM_NET_EVENT_HEADER0_ {
  FILETIME       timeStamp;
  UINT32         flags;
  FWP_IP_VERSION ipVersion;
  UINT8          ipProtocol;
  __C89_NAMELESS union {
    UINT32           localAddrV4;
    FWP_BYTE_ARRAY16 localAddrV6;
  };
  __C89_NAMELESS union {
    UINT32           remoteAddrV4;
    FWP_BYTE_ARRAY16 remoteAddrV6;
  };
  UINT16         localPort;
  UINT16         remotePort;
  UINT32         scopeId;
  FWP_BYTE_BLOB  appId;
  SID            *userId;
} FWPM_NET_EVENT_HEADER0;

#define IKEEXT_CERT_HASH_LEN 20

typedef struct FWPM_NET_EVENT_IKEEXT_UM_FAILURE0_ {
  UINT32                            failureErrorCode;
  IPSEC_FAILURE_POINT               failurePoint;
  UINT32                            flags;
  IKEEXT_EM_SA_STATE                emState;
  IKEEXT_SA_ROLE                    saRole;
  IKEEXT_AUTHENTICATION_METHOD_TYPE emAuthMethod;
  UINT8                             endCertHash[IKEEXT_CERT_HASH_LEN];
  UINT64                            mmId;
  UINT64                            qmFilterId;
} FWPM_NET_EVENT_IKEEXT_UM_FAILURE0;

typedef struct FWPM_NET_EVENT_IKEEXT_MM_FAILURE0_ {
  UINT32                            failureErrorCode;
  IPSEC_FAILURE_POINT               failurePoint;
  UINT32                            flags;
  IKEEXT_KEY_MODULE_TYPE            keyingModuleType;
  IKEEXT_MM_SA_STATE                mmState;
  IKEEXT_SA_ROLE                    saRole;
  IKEEXT_AUTHENTICATION_METHOD_TYPE mmAuthMethod;
  UINT8                             endCertHash[IKEEXT_CERT_HASH_LEN];
  UINT64                            mmId;
  UINT64                            mmFilterId;
} FWPM_NET_EVENT_IKEEXT_MM_FAILURE0;

typedef struct FWPM_NET_EVENT_IKEEXT_QM_FAILURE0 {
  UINT32                 failureErrorCode;
  IPSEC_FAILURE_POINT    failurePoint;
  IKEEXT_KEY_MODULE_TYPE keyingModuleType;
  IKEEXT_QM_SA_STATE     qmState;
  IKEEXT_SA_ROLE         saRole;
  IPSEC_TRAFFIC_TYPE     saTrafficType;
  __C89_NAMELESS union {
    FWP_CONDITION_VALUE0 localSubNet;
  };
  __C89_NAMELESS union {
    FWP_CONDITION_VALUE0 remoteSubNet;
  };
  UINT64                 qmFilterId;
} FWPM_NET_EVENT_IKEEXT_QM_FAILURE0;

typedef UINT32 IPSEC_SA_SPI;

typedef struct FWPM_NET_EVENT_IPSEC_KERNEL_DROP0_ {
  INT32         failureStatus;
  FWP_DIRECTION direction;
  IPSEC_SA_SPI  spi;
  UINT64        filterId;
  UINT16        layerId;
} FWPM_NET_EVENT_IPSEC_KERNEL_DROP0;

#if (_WIN32_WINNT >= 0x0601)
typedef struct FWPM_NET_EVENT_IPSEC_DOSP_DROP0_ {
  FWP_IP_VERSION ipVersion;
  __C89_NAMELESS union {
    UINT32 publicHostV4Addr;
    UINT8  publicHostV6Addr[16];
  };
  __C89_NAMELESS union {
    UINT32 internalHostV4Addr;
    UINT8  internalHostV6Addr[16];
  };
  INT32          failureStatus;
  FWP_DIRECTION  direction;
} FWPM_NET_EVENT_IPSEC_DOSP_DROP0;
#endif /*(_WIN32_WINNT >= 0x0601)*/

typedef struct FWPM_NET_EVENT_IKEEXT_EM_FAILURE0_ {
  UINT32                            failureErrorCode;
  IPSEC_FAILURE_POINT               failurePoint;
  UINT32                            flags;
  IKEEXT_EM_SA_STATE                emState;
  IKEEXT_SA_ROLE                    saRole;
  IKEEXT_AUTHENTICATION_METHOD_TYPE emAuthMethod;
  UINT8                             endCertHash[IKEEXT_CERT_HASH_LEN];
  UINT64                            mmId;
  UINT64                            qmFilterId;
} FWPM_NET_EVENT_IKEEXT_EM_FAILURE0;

typedef struct FWPM_NET_EVENT0_ {
  FWPM_NET_EVENT_HEADER0 header;
  FWPM_NET_EVENT_TYPE    type;
  __C89_NAMELESS union {
    FWPM_NET_EVENT_IKEEXT_MM_FAILURE0 *ikeMmFailure;
    FWPM_NET_EVENT_IKEEXT_QM_FAILURE0 *ikeQmFailure;
    FWPM_NET_EVENT_IKEEXT_EM_FAILURE0 *ikeEmFailure;
    FWPM_NET_EVENT_CLASSIFY_DROP0     *classifyDrop;
    FWPM_NET_EVENT_IPSEC_KERNEL_DROP0 *ipsecDrop;
#if (_WIN32_WINNT >= 0x0601)
    FWPM_NET_EVENT_IPSEC_DOSP_DROP0   *idpDrop;
#endif /*(_WIN32_WINNT >= 0x0601)*/
  };
} FWPM_NET_EVENT0;

typedef struct FWPM_PROVIDER_CHANGE0_ {
  FWPM_CHANGE_TYPE changeType;
  GUID             providerKey;
} FWPM_PROVIDER_CHANGE0;

typedef struct FWPM_PROVIDER_CONTEXT_CHANGE0_ {
  FWPM_CHANGE_TYPE changeType;
  GUID             providerContextKey;
  UINT64           providerContextId;
} FWPM_PROVIDER_CONTEXT_CHANGE0;

typedef struct FWPM_PROVIDER_CONTEXT_SUBSCRIPTION0_ {
  FWPM_PROVIDER_CONTEXT_ENUM_TEMPLATE0 *enumTemplate;
  UINT32                               flags;
  GUID                                 sessionKey;
} FWPM_PROVIDER_CONTEXT_SUBSCRIPTION0;

typedef struct FWPM_PROVIDER_CONTEXT0_ {
  GUID                       providerContextKey;
  FWPM_DISPLAY_DATA0         displayData;
  UINT32                     flags;
  GUID                       *providerKey;
  FWP_BYTE_BLOB              providerData;
  FWPM_PROVIDER_CONTEXT_TYPE type;
  __C89_NAMELESS union {
    IPSEC_KEYING_POLICY0    *keyingPolicy;
    IPSEC_TRANSPORT_POLICY0 *ikeQmTransportPolicy;
    IPSEC_TUNNEL_POLICY0    *ikeQmTunnelPolicy;
    IPSEC_TRANSPORT_POLICY0 *authipQmTransportPolicy;
    IPSEC_TUNNEL_POLICY0    *authipQmTunnelPolicy;
    IKEEXT_POLICY0          *ikeMmPolicy;
    IKEEXT_POLICY0          *authIpMmPolicy;
    FWP_BYTE_BLOB           *dataBuffer;
    FWPM_CLASSIFY_OPTIONS0  *classifyOptions;
  };
  UINT64                     providerContextId;
} FWPM_PROVIDER_CONTEXT0;

typedef struct FWPM_PROVIDER_ENUM_TEMPLATE0_ {
  UINT64 reserved;
} FWPM_PROVIDER_ENUM_TEMPLATE0;

typedef struct FWPM_PROVIDER_SUBSCRIPTION0_ {
  FWPM_PROVIDER_ENUM_TEMPLATE0 *enumTemplate;
  UINT32                       flags;
  GUID                         sessionKey;
} FWPM_PROVIDER_SUBSCRIPTION0;

typedef struct FWPM_PROVIDER0_ {
  GUID               providerKey;
  FWPM_DISPLAY_DATA0 displayData;
  UINT32             flags;
  FWP_BYTE_BLOB      providerData;
  wchar_t            *serviceName;
} FWPM_PROVIDER0;

typedef struct FWPM_SESSION_ENUM_TEMPLATE0_ {
  UINT64 reserved;
} FWPM_SESSION_ENUM_TEMPLATE0;

typedef struct FWPM_SUBLAYER_CHANGE0_ {
  FWPM_CHANGE_TYPE changeType;
  GUID             subLayerKey;
} FWPM_SUBLAYER_CHANGE0;

typedef struct FWPM_SUBLAYER_ENUM_TEMPLATE0_ {
  GUID *providerKey;
} FWPM_SUBLAYER_ENUM_TEMPLATE0;

typedef struct FWPM_SUBLAYER_SUBSCRIPTION0_ {
  FWPM_SUBLAYER_ENUM_TEMPLATE0 *enumTemplate;
  UINT32                       flags;
  GUID                         sessionKey;
} FWPM_SUBLAYER_SUBSCRIPTION0;

typedef struct FWPM_SUBLAYER0_ {
  GUID               subLayerKey;
  FWPM_DISPLAY_DATA0 displayData;
  UINT16             flags;
  GUID               *providerKey;
  FWP_BYTE_BLOB      providerData;
  UINT16             weight;
} FWPM_SUBLAYER0;

#endif /*(_WIN32_WINNT >= 0x0600)*/

#if (_WIN32_WINNT >= 0x0601)

typedef enum FWPM_SYSTEM_PORT_TYPE_ {
  FWPM_SYSTEM_PORT_RPC_EPMAP,
  FWPM_SYSTEM_PORT_TEREDO,
  FWPM_SYSTEM_PORT_IPHTTPS_IN,
  FWPM_SYSTEM_PORT_IPHTTPS_OUT,
  FWPM_SYSTEM_PORT_TYPE_MAX 
} FWPM_SYSTEM_PORT_TYPE;

typedef enum  {
  DlUnicast,
  DlMulticast,
  DlBroadcast 
} DL_ADDRESS_TYPE, *PDL_ADDRESS_TYPE;

typedef struct FWPM_PROVIDER_CONTEXT1_ {
  GUID                       providerContextKey;
  FWPM_DISPLAY_DATA0         displayData;
  UINT32                     flags;
  GUID                       *providerKey;
  FWP_BYTE_BLOB              providerData;
  FWPM_PROVIDER_CONTEXT_TYPE type;
  __C89_NAMELESS union {
    IPSEC_KEYING_POLICY0    *keyingPolicy;
    IPSEC_TRANSPORT_POLICY1 *ikeQmTransportPolicy;
    IPSEC_TUNNEL_POLICY1    *ikeQmTunnelPolicy;
    IPSEC_TRANSPORT_POLICY1 *authipQmTransportPolicy;
    IPSEC_TUNNEL_POLICY1    *authipQmTunnelPolicy;
    IKEEXT_POLICY1          *ikeMmPolicy;
    IKEEXT_POLICY1          *authIpMmPolicy;
    FWP_BYTE_BLOB           *dataBuffer;
    FWPM_CLASSIFY_OPTIONS0  *classifyOptions;
    IPSEC_TUNNEL_POLICY1    *ikeV2QmTunnelPolicy;
    IKEEXT_POLICY1          *ikeV2MmPolicy;
    IPSEC_DOSP_OPTIONS0     *idpOptions;
  };
  UINT64                     providerContextId;
} FWPM_PROVIDER_CONTEXT1;

typedef struct FWPM_NET_EVENT_HEADER1_ {
  FILETIME       timeStamp;
  UINT32         flags;
  FWP_IP_VERSION ipVersion;
  UINT8          ipProtocol;
  __C89_NAMELESS union {
    UINT32           localAddrV4;
    FWP_BYTE_ARRAY16 localAddrV6;
  };
  __C89_NAMELESS union {
    UINT32           remoteAddrV4;
    FWP_BYTE_ARRAY16 remoteAddrV6;
  };
  UINT16         localPort;
  UINT16         remotePort;
  UINT32         scopeId;
  FWP_BYTE_BLOB  appId;
  SID            *userId;
  __C89_NAMELESS union {
    __C89_NAMELESS struct {
      FWP_AF addressFamily;
      __C89_NAMELESS union {
        __C89_NAMELESS struct {
          FWP_BYTE_ARRAY6        dstAddrEth;
          FWP_BYTE_ARRAY6        srcAddrEth;
          DL_ADDRESS_TYPE        addrType;
          FWP_ETHER_ENCAP_METHOD encapMethod;
          UINT16                 etherType;
          UINT32                 snapControl;
          UINT32                 snapOui;
          UINT16                 vlanTag;
          UINT64                 ifLuid;
        };
      };
    };
  };
} FWPM_NET_EVENT_HEADER1;

#define IKEEXT_CERT_HASH_LEN 20

typedef struct FWPM_NET_EVENT_IKEEXT_MM_FAILURE1_ {
  UINT32                            failureErrorCode;
  IPSEC_FAILURE_POINT               failurePoint;
  UINT32                            flags;
  IKEEXT_KEY_MODULE_TYPE            keyingModuleType;
  IKEEXT_MM_SA_STATE                mmState;
  IKEEXT_SA_ROLE                    saRole;
  IKEEXT_AUTHENTICATION_METHOD_TYPE mmAuthMethod;
  UINT8                             endCertHash[IKEEXT_CERT_HASH_LEN];
  UINT64                            mmId;
  UINT64                            mmFilterId;
  wchar_t                           *localPrincipalNameForAuth;
  wchar_t                           *remotePrincipalNameForAuth;
  UINT32                            numLocalPrincipalGroupSids;
  LPWSTR                            *localPrincipalGroupSids;
  UINT32                            numRemotePrincipalGroupSids;
  LPWSTR                            *remotePrincipalGroupSids;
} FWPM_NET_EVENT_IKEEXT_MM_FAILURE1;

typedef struct FWPM_NET_EVENT_IKEEXT_EM_FAILURE1_ {
  UINT32                            failureErrorCode;
  IPSEC_FAILURE_POINT               failurePoint;
  UINT32                            flags;
  IKEEXT_EM_SA_STATE                emState;
  IKEEXT_SA_ROLE                    saRole;
  IKEEXT_AUTHENTICATION_METHOD_TYPE emAuthMethod;
  UINT8                             endCertHash[IKEEXT_CERT_HASH_LEN];
  UINT64                            mmId;
  UINT64                            qmFilterId;
  wchar_t                           *localPrincipalNameForAuth;
  wchar_t                           *remotePrincipalNameForAuth;
  UINT32                            numLocalPrincipalGroupSids;
  LPWSTR                            *localPrincipalGroupSids;
  UINT32                            numRemotePrincipalGroupSids;
  LPWSTR                            *remotePrincipalGroupSids;
  IPSEC_TRAFFIC_TYPE                saTrafficType;
} FWPM_NET_EVENT_IKEEXT_EM_FAILURE1;

typedef struct FWPM_NET_EVENT_CLASSIFY_DROP1_ {
  UINT64 filterId;
  UINT16 layerId;
  UINT32 reauthReason;
  UINT32 originalProfile;
  UINT32 currentProfile;
  UINT32 msFwpDirection;
  BOOL   isLoopback;
} FWPM_NET_EVENT_CLASSIFY_DROP1;

typedef struct FWPM_NET_EVENT1_ {
  FWPM_NET_EVENT_HEADER1 header;
  FWPM_NET_EVENT_TYPE    type;
  __C89_NAMELESS union {
    FWPM_NET_EVENT_IKEEXT_MM_FAILURE1 *ikeMmFailure;
    FWPM_NET_EVENT_IKEEXT_QM_FAILURE0 *ikeQmFailure;
    FWPM_NET_EVENT_IKEEXT_EM_FAILURE1 *ikeEmFailure;
    FWPM_NET_EVENT_CLASSIFY_DROP1     *classifyDrop;
    FWPM_NET_EVENT_IPSEC_KERNEL_DROP0 *ipsecDrop;
    FWPM_NET_EVENT_IPSEC_DOSP_DROP0   *idpDrop;
  };
} FWPM_NET_EVENT1;

typedef struct FWPM_NET_EVENT_SUBSCRIPTION0_ {
  FWPM_NET_EVENT_ENUM_TEMPLATE0 *enumTemplate;
  UINT32                        flags;
  GUID                          sessionKey;
} FWPM_NET_EVENT_SUBSCRIPTION0;

typedef struct FWPM_SYSTEM_PORTS_BY_TYPE0_ {
  FWPM_SYSTEM_PORT_TYPE type;
  UINT32                numPorts;
  UINT16                *ports;
} FWPM_SYSTEM_PORTS_BY_TYPE0;

typedef struct FWPM_SYSTEM_PORTS0_ {
  UINT32                     numTypes;
  FWPM_SYSTEM_PORTS_BY_TYPE0 *types;
} FWPM_SYSTEM_PORTS0;

#endif /*(_WIN32_WINNT >= 0x0601)*/
#ifdef __cplusplus
}
#endif

#endif /*_INC_FWPMTYPES*/
