/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef __sdoias_h__
#define __sdoias_h__

#ifndef __ISdoMachine_FWD_DEFINED__
#define __ISdoMachine_FWD_DEFINED__
typedef struct ISdoMachine ISdoMachine;
#endif

#ifndef __ISdoServiceControl_FWD_DEFINED__
#define __ISdoServiceControl_FWD_DEFINED__
typedef struct ISdoServiceControl ISdoServiceControl;
#endif

#ifndef __ISdo_FWD_DEFINED__
#define __ISdo_FWD_DEFINED__
typedef struct ISdo ISdo;
#endif

#ifndef __ISdoCollection_FWD_DEFINED__
#define __ISdoCollection_FWD_DEFINED__
typedef struct ISdoCollection ISdoCollection;
#endif

#ifndef __ISdoDictionaryOld_FWD_DEFINED__
#define __ISdoDictionaryOld_FWD_DEFINED__
typedef struct ISdoDictionaryOld ISdoDictionaryOld;
#endif

#ifndef __SdoMachine_FWD_DEFINED__
#define __SdoMachine_FWD_DEFINED__

#ifdef __cplusplus
typedef class SdoMachine SdoMachine;
#else
typedef struct SdoMachine SdoMachine;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __SDOIASLib_LIBRARY_DEFINED__
#define __SDOIASLib_LIBRARY_DEFINED__

  typedef enum _ATTRIBUTEID {
    ATTRIBUTE_UNDEFINED = 0,ATTRIBUTE_MIN_VALUE = 1,
    RADIUS_ATTRIBUTE_USER_PASSWORD,RADIUS_ATTRIBUTE_CHAP_PASSWORD,
    RADIUS_ATTRIBUTE_NAS_IP_ADDRESS,RADIUS_ATTRIBUTE_NAS_PORT,
    RADIUS_ATTRIBUTE_SERVICE_TYPE,RADIUS_ATTRIBUTE_FRAMED_PROTOCOL,
    RADIUS_ATTRIBUTE_FRAMED_IP_ADDRESS,RADIUS_ATTRIBUTE_FRAMED_IP_NETMASK,
    RADIUS_ATTRIBUTE_FRAMED_ROUTING,RADIUS_ATTRIBUTE_FILTER_ID,
    RADIUS_ATTRIBUTE_FRAMED_MTU,RADIUS_ATTRIBUTE_FRAMED_COMPRESSION,
    RADIUS_ATTRIBUTE_LOGIN_IP_HOST,RADIUS_ATTRIBUTE_LOGIN_SERVICE,
    RADIUS_ATTRIBUTE_LOGIN_TCP_PORT,RADIUS_ATTRIBUTE_UNASSIGNED1,
    RADIUS_ATTRIBUTE_REPLY_MESSAGE,RADIUS_ATTRIBUTE_CALLBACK_NUMBER,
    RADIUS_ATTRIBUTE_CALLBACK_ID,RADIUS_ATTRIBUTE_UNASSIGNED2,
    RADIUS_ATTRIBUTE_FRAMED_ROUTE,RADIUS_ATTRIBUTE_FRAMED_IPX_NETWORK,
    RADIUS_ATTRIBUTE_STATE,RADIUS_ATTRIBUTE_CLASS,
    RADIUS_ATTRIBUTE_VENDOR_SPECIFIC,RADIUS_ATTRIBUTE_SESSION_TIMEOUT,
    RADIUS_ATTRIBUTE_IDLE_TIMEOUT,RADIUS_ATTRIBUTE_TERMINATION_ACTION,
    RADIUS_ATTRIBUTE_CALLED_STATION_ID,RADIUS_ATTRIBUTE_CALLING_STATION_ID,
    RADIUS_ATTRIBUTE_NAS_IDENTIFIER,RADIUS_ATTRIBUTE_PROXY_STATE,
    RADIUS_ATTRIBUTE_LOGIN_LAT_SERVICE,RADIUS_ATTRIBUTE_LOGIN_LAT_NODE,
    RADIUS_ATTRIBUTE_LOGIN_LAT_GROUP,RADIUS_ATTRIBUTE_FRAMED_APPLETALK_LINK,
    RADIUS_ATTRIBUTE_FRAMED_APPLETALK_NET,RADIUS_ATTRIBUTE_FRAMED_APPLETALK_ZONE,
    RADIUS_ATTRIBUTE_ACCT_STATUS_TYPE,RADIUS_ATTRIBUTE_ACCT_DELAY_TIME,
    RADIUS_ATTRIBUTE_ACCT_INPUT_OCTETS,RADIUS_ATTRIBUTE_ACCT_OUTPUT_OCTETS,
    RADIUS_ATTRIBUTE_ACCT_SESSION_ID,RADIUS_ATTRIBUTE_ACCT_AUTHENTIC,
    RADIUS_ATTRIBUTE_ACCT_SESSION_TIME,RADIUS_ATTRIBUTE_ACCT_INPUT_PACKETS,
    RADIUS_ATTRIBUTE_ACCT_OUTPUT_PACKETS,RADIUS_ATTRIBUTE_ACCT_TERMINATE_CAUSE,
    RADIUS_ATTRIBUTE_ACCT_MULTI_SSN_ID,RADIUS_ATTRIBUTE_ACCT_LINK_COUNT,
    RADIUS_ATTRIBUTE_USER_NAME = ATTRIBUTE_MIN_VALUE,
    RADIUS_ATTRIBUTE_CHAP_CHALLENGE = 60,
    RADIUS_ATTRIBUTE_NAS_PORT_TYPE,RADIUS_ATTRIBUTE_PORT_LIMIT,
    RADIUS_ATTRIBUTE_LOGIN_LAT_PORT,RADIUS_ATTRIBUTE_TUNNEL_TYPE,
    RADIUS_ATTRIBUTE_TUNNEL_MEDIUM_TYPE,RADIUS_ATTRIBUTE_TUNNEL_CLIENT_ENDPT,
    RADIUS_ATTRIBUTE_TUNNEL_SERVER_ENDPT,RADIUS_ATTRIBUTE_ACCT_TUNNEL_CONN,
    RADIUS_ATTRIBUTE_TUNNEL_PASSWORD,RADIUS_ATTRIBUTE_ARAP_PASSWORD,
    RADIUS_ATTRIBUTE_ARAP_FEATURES,RADIUS_ATTRIBUTE_ARAP_ZONE_ACCESS,
    RADIUS_ATTRIBUTE_ARAP_SECURITY,RADIUS_ATTRIBUTE_ARAP_SECURITY_DATA,
    RADIUS_ATTRIBUTE_PASSWORD_RETRY,RADIUS_ATTRIBUTE_PROMPT,
    RADIUS_ATTRIBUTE_CONNECT_INFO,RADIUS_ATTRIBUTE_CONFIGURATION_TOKEN,
    RADIUS_ATTRIBUTE_EAP_MESSAGE,RADIUS_ATTRIBUTE_SIGNATURE,
    RADIUS_ATTRIBUTE_TUNNEL_PVT_GROUP_ID,RADIUS_ATTRIBUTE_TUNNEL_ASSIGNMENT_ID,
    RADIUS_ATTRIBUTE_TUNNEL_PREFERENCE,RADIUS_ATTRIBUTE_ARAP_CHALLENGE_RESPONSE,
    RADIUS_ATTRIBUTE_ACCT_INTERIM_INTERVAL,
    IAS_ATTRIBUTE_SAVED_RADIUS_FRAMED_IP_ADDRESS = 0x1000,
    IAS_ATTRIBUTE_SAVED_RADIUS_CALLBACK_NUMBER,IAS_ATTRIBUTE_NP_CALLING_STATION_ID,
    IAS_ATTRIBUTE_SAVED_NP_CALLING_STATION_ID,IAS_ATTRIBUTE_SAVED_RADIUS_FRAMED_ROUTE,
    IAS_ATTRIBUTE_IGNORE_USER_DIALIN_PROPERTIES,IAS_ATTRIBUTE_NP_TIME_OF_DAY,
    IAS_ATTRIBUTE_NP_CALLED_STATION_ID,IAS_ATTRIBUTE_NP_ALLOWED_PORT_TYPES,
    IAS_ATTRIBUTE_NP_AUTHENTICATION_TYPE,IAS_ATTRIBUTE_NP_ALLOWED_EAP_TYPE,
    IAS_ATTRIBUTE_SHARED_SECRET,IAS_ATTRIBUTE_CLIENT_IP_ADDRESS,
    IAS_ATTRIBUTE_CLIENT_PACKET_HEADER,IAS_ATTRIBUTE_TOKEN_GROUPS,
    IAS_ATTRIBUTE_ALLOW_DIALIN,IAS_ATTRIBUTE_REQUEST_ID,
    IAS_ATTRIBUTE_MANIPULATION_TARGET,IAS_ATTRIBUTE_MANIPULATION_RULE,
    IAS_ATTRIBUTE_ORIGINAL_USER_NAME,IAS_ATTRIBUTE_CLIENT_VENDOR_TYPE,
    IAS_ATTRIBUTE_CLIENT_UDP_PORT,MS_ATTRIBUTE_CHAP_CHALLENGE,
    MS_ATTRIBUTE_CHAP_RESPONSE,MS_ATTRIBUTE_CHAP_DOMAIN,
    MS_ATTRIBUTE_CHAP_ERROR,MS_ATTRIBUTE_CHAP_CPW1,
    MS_ATTRIBUTE_CHAP_CPW2,MS_ATTRIBUTE_CHAP_LM_ENC_PW,
    MS_ATTRIBUTE_CHAP_NT_ENC_PW,MS_ATTRIBUTE_CHAP_MPPE_KEYS,
    IAS_ATTRIBUTE_AUTHENTICATION_TYPE,IAS_ATTRIBUTE_CLIENT_NAME,
    IAS_ATTRIBUTE_NT4_ACCOUNT_NAME,IAS_ATTRIBUTE_FULLY_QUALIFIED_USER_NAME,
    IAS_ATTRIBUTE_NTGROUPS,IAS_ATTRIBUTE_EAP_FRIENDLY_NAME,
    IAS_ATTRIBUTE_AUTH_PROVIDER_TYPE,MS_ATTRIBUTE_ACCT_AUTH_TYPE,
    MS_ATTRIBUTE_ACCT_EAP_TYPE,IAS_ATTRIBUTE_PACKET_TYPE,
    IAS_ATTRIBUTE_AUTH_PROVIDER_NAME,IAS_ATTRIBUTE_ACCT_PROVIDER_TYPE,
    IAS_ATTRIBUTE_ACCT_PROVIDER_NAME,MS_ATTRIBUTE_MPPE_SEND_KEY,
    MS_ATTRIBUTE_MPPE_RECV_KEY,IAS_ATTRIBUTE_REASON_CODE,
    MS_ATTRIBUTE_FILTER,MS_ATTRIBUTE_CHAP2_RESPONSE,
    MS_ATTRIBUTE_CHAP2_SUCCESS,MS_ATTRIBUTE_CHAP2_CPW,
    MS_ATTRIBUTE_RAS_VENDOR,MS_ATTRIBUTE_RAS_VERSION,
    IAS_ATTRIBUTE_NP_NAME,MS_ATTRIBUTE_PRIMARY_DNS_SERVER,
    MS_ATTRIBUTE_SECONDARY_DNS_SERVER,MS_ATTRIBUTE_PRIMARY_NBNS_SERVER,
    MS_ATTRIBUTE_SECONDARY_NBNS_SERVER,IAS_ATTRIBUTE_PROXY_POLICY_NAME,
    IAS_ATTRIBUTE_PROVIDER_TYPE,IAS_ATTRIBUTE_PROVIDER_NAME,
    IAS_ATTRIBUTE_REMOTE_SERVER_ADDRESS,IAS_ATTRIBUTE_GENERATE_CLASS_ATTRIBUTE,
    MS_ATTRIBUTE_RAS_CLIENT_NAME,MS_ATTRIBUTE_RAS_CLIENT_VERSION,
    IAS_ATTRIBUTE_ALLOWED_CERTIFICATE_EKU,IAS_ATTRIBUTE_EXTENSION_STATE,
    IAS_ATTRIBUTE_GENERATE_SESSION_TIMEOUT,MS_ATTRIBUTE_SESSION_TIMEOUT,
    MS_ATTRIBUTE_QUARANTINE_IPFILTER,MS_ATTRIBUTE_QUARANTINE_SESSION_TIMEOUT,
    MS_ATTRIBUTE_USER_SECURITY_IDENTITY,IAS_ATTRIBUTE_REMOTE_RADIUS_TO_WINDOWS_USER_MAPPING,
    IAS_ATTRIBUTE_PASSPORT_USER_MAPPING_UPN_SUFFIX,IAS_ATTRIBUTE_TUNNEL_TAG,
    IAS_ATTRIBUTE_NP_PEAPUPFRONT_ENABLED,
    IAS_ATTRIBUTE_CERTIFICATE_EKU = 8097,
    IAS_ATTRIBUTE_EAP_CONFIG,MS_ATTRIBUTE_PEAP_EMBEDDED_EAP_TYPEID,
    MS_ATTRIBUTE_PEAP_FAST_ROAMED_SESSION,IAS_ATTRIBUTE_EAP_TYPEID,
    IAS_ATTRIBUTE_EAP_TLV,IAS_ATTRIBUTE_REJECT_REASON_CODE,
    IAS_ATTRIBUTE_PROXY_EAP_CONFIG,IAS_ATTRIBUTE_EAP_SESSION,
    IAS_ATTRIBUTE_IS_REPLAY,IAS_ATTRIBUTE_CLEAR_TEXT_PASSWORD,
    RAS_ATTRIBUTE_ENCRYPTION_TYPE = 0xffffffff - 89,
    RAS_ATTRIBUTE_ENCRYPTION_POLICY = 0xffffffff - 88,
    RAS_ATTRIBUTE_BAP_REQUIRED = 0xffffffff - 87,
    RAS_ATTRIBUTE_BAP_LINE_DOWN_TIME = 0xffffffff - 86,
    RAS_ATTRIBUTE_BAP_LINE_DOWN_LIMIT = 0xffffffff - 85
  } ATTRIBUTEID;

  typedef enum _NEW_LOG_FILE_FREQUENCY {
    IAS_LOGGING_UNLIMITED_SIZE = 0,
    IAS_LOGGING_DAILY,IAS_LOGGING_WEEKLY,IAS_LOGGING_MONTHLY,IAS_LOGGING_WHEN_FILE_SIZE_REACHES
  } NEW_LOG_FILE_FREQUENCY;

  typedef enum _AUTHENTICATION_TYPE {
    IAS_AUTH_INVALID = 0,
    IAS_AUTH_PAP,IAS_AUTH_MD5CHAP,IAS_AUTH_MSCHAP,IAS_AUTH_MSCHAP2,IAS_AUTH_EAP,
    IAS_AUTH_ARAP,IAS_AUTH_NONE,IAS_AUTH_CUSTOM,IAS_AUTH_MSCHAP_CPW,IAS_AUTH_MSCHAP2_CPW,
    IAS_AUTH_PEAP
  } AUTHENTICATION_TYPE;

  typedef enum _ATTRIBUTESYNTAX {
    IAS_SYNTAX_BOOLEAN = 1,
    IAS_SYNTAX_INTEGER,IAS_SYNTAX_ENUMERATOR,IAS_SYNTAX_INETADDR,IAS_SYNTAX_STRING,
    IAS_SYNTAX_OCTETSTRING,IAS_SYNTAX_UTCTIME,IAS_SYNTAX_PROVIDERSPECIFIC,
    IAS_SYNTAX_UNSIGNEDINTEGER
  } ATTRIBUTESYNTAX;

  typedef enum _ATTRIBUTERESTRICTIONS {
    MULTIVALUED = 0x1,ALLOWEDINPROFILE = 0x2,ALLOWEDINCONDITION = 0x4,ALLOWEDINPROXYPROFILE = 0x8,
    ALLOWEDINPROXYCONDITION = 0x10
  } ATTRIBUTERESTRICTIONS;

  typedef enum _ATTRIBUTEINFO {
    NAME = 1,
    SYNTAX,RESTRICTIONS,DESCRIPTION,VENDORID,LDAPNAME,VENDORTYPE
  } ATTRIBUTEINFO;

  typedef enum _IASCOMMONPROPERTIES {
    PROPERTY_SDO_RESERVED = 0,
    PROPERTY_SDO_CLASS,PROPERTY_SDO_NAME,PROPERTY_SDO_DESCRIPTION,PROPERTY_SDO_ID,
    PROPERTY_SDO_DATASTORE_NAME,
    PROPERTY_SDO_START = 0x400
  } IASCOMMONPROPERTIES;

  typedef enum _USERPROPERTIES {
    PROPERTY_USER_CALLING_STATION_ID = 0x400,
    PROPERTY_USER_SAVED_CALLING_STATION_ID,PROPERTY_USER_RADIUS_CALLBACK_NUMBER,
    PROPERTY_USER_RADIUS_FRAMED_ROUTE,PROPERTY_USER_RADIUS_FRAMED_IP_ADDRESS,
    PROPERTY_USER_SAVED_RADIUS_CALLBACK_NUMBER,PROPERTY_USER_SAVED_RADIUS_FRAMED_ROUTE,
    PROPERTY_USER_SAVED_RADIUS_FRAMED_IP_ADDRESS,PROPERTY_USER_ALLOW_DIALIN,
    PROPERTY_USER_SERVICE_TYPE
  } USERPROPERTIES;

  typedef enum _DICTIONARYPROPERTIES {
    PROPERTY_DICTIONARY_ATTRIBUTES_COLLECTION = 0x400,
    PROPERTY_DICTIONARY_LOCATION
  } DICTIONARYPROPERTIES;

  typedef enum _ATTRIBUTEPROPERTIES {
    PROPERTY_ATTRIBUTE_ID = 0x400,
    PROPERTY_ATTRIBUTE_VENDOR_ID,PROPERTY_ATTRIBUTE_VENDOR_TYPE_ID,
    PROPERTY_ATTRIBUTE_IS_ENUMERABLE,PROPERTY_ATTRIBUTE_ENUM_NAMES,
    PROPERTY_ATTRIBUTE_ENUM_VALUES,PROPERTY_ATTRIBUTE_SYNTAX,
    PROPERTY_ATTRIBUTE_ALLOW_MULTIPLE,PROPERTY_ATTRIBUTE_ALLOW_LOG_ORDINAL,
    PROPERTY_ATTRIBUTE_ALLOW_IN_PROFILE,PROPERTY_ATTRIBUTE_ALLOW_IN_CONDITION,
    PROPERTY_ATTRIBUTE_DISPLAY_NAME,PROPERTY_ATTRIBUTE_VALUE,
    PROPERTY_ATTRIBUTE_ALLOW_IN_PROXY_PROFILE,PROPERTY_ATTRIBUTE_ALLOW_IN_PROXY_CONDITION
  } ATTRIBUTEPROPERTIES;

  typedef enum _IASPROPERTIES {
    PROPERTY_IAS_RADIUSSERVERGROUPS_COLLECTION = 0x400,
    PROPERTY_IAS_POLICIES_COLLECTION,PROPERTY_IAS_PROFILES_COLLECTION,
    PROPERTY_IAS_PROTOCOLS_COLLECTION,PROPERTY_IAS_AUDITORS_COLLECTION,
    PROPERTY_IAS_REQUESTHANDLERS_COLLECTION,PROPERTY_IAS_PROXYPOLICIES_COLLECTION,
    PROPERTY_IAS_PROXYPROFILES_COLLECTION
  } IASPROPERTIES;

  typedef enum _CLIENTPROPERTIES {
    PROPERTY_CLIENT_REQUIRE_SIGNATURE = 0x400,
    PROPERTY_CLIENT_UNUSED,PROPERTY_CLIENT_SHARED_SECRET,
    PROPERTY_CLIENT_NAS_MANUFACTURER,PROPERTY_CLIENT_ADDRESS
  } CLIENTPROPERTIES;

  typedef enum _VENDORPROPERTIES {
    PROPERTY_NAS_VENDOR_ID = 0x400
  } VENDORPROPERTIES;

  typedef enum _PROFILEPROPERTIES {
    PROPERTY_PROFILE_ATTRIBUTES_COLLECTION = 0x400
  } PROFILEPROPERTIES;

  typedef enum _POLICYPROPERTIES {
    PROPERTY_POLICY_CONSTRAINT = 0x400,
    PROPERTY_POLICY_MERIT,PROPERTY_POLICY_UNUSED0,
    PROPERTY_POLICY_UNUSED1,PROPERTY_POLICY_PROFILE_NAME,
    PROPERTY_POLICY_ACTION,PROPERTY_POLICY_CONDITIONS_COLLECTION
  } POLICYPROPERTIES;

  typedef enum _CONDITIONPROPERTIES {
    PROPERTY_CONDITION_TEXT = 0x400
  } CONDITIONPROPERTIES;

  typedef enum _RADIUSSERVERGROUPPROPERTIES {
    PROPERTY_RADIUSSERVERGROUP_SERVERS_COLLECTION = 0x400
  } RADIUSSERVERGROUPPROPERTIES;

  typedef enum _RADIUSSERVERPROPERTIES {
    PROPERTY_RADIUSSERVER_AUTH_PORT = 0x400,
    PROPERTY_RADIUSSERVER_AUTH_SECRET,PROPERTY_RADIUSSERVER_ACCT_PORT,
    PROPERTY_RADIUSSERVER_ACCT_SECRET,PROPERTY_RADIUSSERVER_ADDRESS,
    PROPERTY_RADIUSSERVER_FORWARD_ACCT_ONOFF,PROPERTY_RADIUSSERVER_PRIORITY,
    PROPERTY_RADIUSSERVER_WEIGHT,PROPERTY_RADIUSSERVER_TIMEOUT,
    PROPERTY_RADIUSSERVER_MAX_LOST,PROPERTY_RADIUSSERVER_BLACKOUT
  } RADIUSSERVERPROPERTIES;

  typedef enum _IASCOMPONENTPROPERTIES {
    PROPERTY_COMPONENT_ID = 0x400,
    PROPERTY_COMPONENT_PROG_ID = 0x401,
    PROPERTY_COMPONENT_START = 0x402
  } IASCOMPONENTPROPERTIES;

  typedef enum _PROTOCOLPROPERTIES {
    PROPERTY_PROTOCOL_REQUEST_HANDLER = 0x402,
    PROPERTY_PROTOCOL_START = 0x403
  } PROTOCOLPROPERTIES;

  typedef enum _RADIUSPROPERTIES {
    PROPERTY_RADIUS_ACCOUNTING_PORT = 0x403,
    PROPERTY_RADIUS_AUTHENTICATION_PORT,PROPERTY_RADIUS_CLIENTS_COLLECTION,
    PROPERTY_RADIUS_VENDORS_COLLECTION
  } RADIUSPROPERTIES;

  typedef enum _NTEVENTLOGPROPERTIES {
    PROPERTY_EVENTLOG_LOG_APPLICATION_EVENTS = 0x402,
    PROPERTY_EVENTLOG_LOG_MALFORMED,
    PROPERTY_EVENTLOG_LOG_DEBUG
  } NTEVENTLOGPROPERTIES;

  typedef enum _NAMESPROPERTIES {
    PROPERTY_NAMES_REALMS = 0x402
  } NAMESPROPERTIES;

  typedef enum _NTSAMPROPERTIES {
    PROPERTY_NTSAM_ALLOW_LM_AUTHENTICATION = 0x402
  } NTSAMPROPERTIES;

  typedef enum _ACCOUNTINGPROPERTIES {
    PROPERTY_ACCOUNTING_LOG_ACCOUNTING = 0x402,
    PROPERTY_ACCOUNTING_LOG_ACCOUNTING_INTERIM,PROPERTY_ACCOUNTING_LOG_AUTHENTICATION,
    PROPERTY_ACCOUNTING_LOG_OPEN_NEW_FREQUENCY,PROPERTY_ACCOUNTING_LOG_OPEN_NEW_SIZE,
    PROPERTY_ACCOUNTING_LOG_FILE_DIRECTORY,PROPERTY_ACCOUNTING_LOG_IAS1_FORMAT,
    PROPERTY_ACCOUNTING_LOG_ENABLE_LOGGING,PROPERTY_ACCOUNTING_LOG_DELETE_IF_FULL,
    PROPERTY_ACCOUNTING_SQL_MAX_SESSIONS,PROPERTY_ACCOUNTING_LOG_AUTHENTICATION_INTERIM
  } ACCOUNTINGPROPERTIES;

  typedef enum _EAPWRAPPROPERTIES {
    PROPERTY_EAP_SESSION_TIMEOUT = 0x402,
    PROPERTY_EAP_MAX_SESSIONS
  } EAPWRAPPROPERTIES;

  typedef enum _NAPPROPERTIES {
    PROPERTY_NAP_POLICIES_COLLECTION = 0x402
  } NAPPROPERTIES;

  typedef enum _RADIUSPROXYPROPERTIES {
    PROPERTY_RADIUSPROXY_SERVERGROUPS = 0x402
  } RADIUSPROXYPROPERTIES;

  typedef enum _SERVICE_TYPE {
    SERVICE_TYPE_IAS = 0,
    SERVICE_TYPE_RAS,SERVICE_TYPE_MAX
  } SERVICE_TYPE;

  typedef enum _IASOSTYPE {
    SYSTEM_TYPE_NT4_WORKSTATION = 0,
    SYSTEM_TYPE_NT5_WORKSTATION,SYSTEM_TYPE_NT4_SERVER,SYSTEM_TYPE_NT5_SERVER
  } IASOSTYPE;

  typedef enum _IASOSTYPE *PIASOSTYPE;

  typedef enum _DOMAINTYPE {
    DOMAIN_TYPE_NONE = 0,
    DOMAIN_TYPE_NT4,DOMAIN_TYPE_NT5,DOMAIN_TYPE_MIXED
  } IASDOMAINTYPE;

  typedef enum _DOMAINTYPE *PIASDOMAINTYPE;

  typedef enum _IASDATASTORE {
    DATA_STORE_LOCAL = 0,
    DATA_STORE_DIRECTORY
  } IASDATASTORE;

  typedef enum _IASDATASTORE *PIASDATASTORE;

  EXTERN_C const IID LIBID_SDOIASLib;
#ifndef __ISdoMachine_INTERFACE_DEFINED__
#define __ISdoMachine_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISdoMachine;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISdoMachine : public IDispatch {
  public:
    virtual HRESULT WINAPI Attach(BSTR bstrComputerName) = 0;
    virtual HRESULT WINAPI GetDictionarySDO(IUnknown **ppDictionarySDO) = 0;
    virtual HRESULT WINAPI GetServiceSDO(IASDATASTORE eDataStore,BSTR bstrServiceName,IUnknown **ppServiceSDO) = 0;
    virtual HRESULT WINAPI GetUserSDO(IASDATASTORE eDataStore,BSTR bstrUserName,IUnknown **ppUserSDO) = 0;
    virtual HRESULT WINAPI GetOSType(IASOSTYPE *eOSType) = 0;
    virtual HRESULT WINAPI GetDomainType(IASDOMAINTYPE *eDomainType) = 0;
    virtual HRESULT WINAPI IsDirectoryAvailable(VARIANT_BOOL *boolDirectoryAvailable) = 0;
    virtual HRESULT WINAPI GetAttachedComputer(BSTR *bstrComputerName) = 0;
    virtual HRESULT WINAPI GetSDOSchema(IUnknown **ppSDOSchema) = 0;
  };
#else
  typedef struct ISdoMachineVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISdoMachine *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISdoMachine *This);
      ULONG (WINAPI *Release)(ISdoMachine *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISdoMachine *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISdoMachine *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISdoMachine *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISdoMachine *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Attach)(ISdoMachine *This,BSTR bstrComputerName);
      HRESULT (WINAPI *GetDictionarySDO)(ISdoMachine *This,IUnknown **ppDictionarySDO);
      HRESULT (WINAPI *GetServiceSDO)(ISdoMachine *This,IASDATASTORE eDataStore,BSTR bstrServiceName,IUnknown **ppServiceSDO);
      HRESULT (WINAPI *GetUserSDO)(ISdoMachine *This,IASDATASTORE eDataStore,BSTR bstrUserName,IUnknown **ppUserSDO);
      HRESULT (WINAPI *GetOSType)(ISdoMachine *This,IASOSTYPE *eOSType);
      HRESULT (WINAPI *GetDomainType)(ISdoMachine *This,IASDOMAINTYPE *eDomainType);
      HRESULT (WINAPI *IsDirectoryAvailable)(ISdoMachine *This,VARIANT_BOOL *boolDirectoryAvailable);
      HRESULT (WINAPI *GetAttachedComputer)(ISdoMachine *This,BSTR *bstrComputerName);
      HRESULT (WINAPI *GetSDOSchema)(ISdoMachine *This,IUnknown **ppSDOSchema);
    END_INTERFACE
  } ISdoMachineVtbl;
  struct ISdoMachine {
    CONST_VTBL struct ISdoMachineVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISdoMachine_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISdoMachine_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISdoMachine_Release(This) (This)->lpVtbl->Release(This)
#define ISdoMachine_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISdoMachine_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISdoMachine_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISdoMachine_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISdoMachine_Attach(This,bstrComputerName) (This)->lpVtbl->Attach(This,bstrComputerName)
#define ISdoMachine_GetDictionarySDO(This,ppDictionarySDO) (This)->lpVtbl->GetDictionarySDO(This,ppDictionarySDO)
#define ISdoMachine_GetServiceSDO(This,eDataStore,bstrServiceName,ppServiceSDO) (This)->lpVtbl->GetServiceSDO(This,eDataStore,bstrServiceName,ppServiceSDO)
#define ISdoMachine_GetUserSDO(This,eDataStore,bstrUserName,ppUserSDO) (This)->lpVtbl->GetUserSDO(This,eDataStore,bstrUserName,ppUserSDO)
#define ISdoMachine_GetOSType(This,eOSType) (This)->lpVtbl->GetOSType(This,eOSType)
#define ISdoMachine_GetDomainType(This,eDomainType) (This)->lpVtbl->GetDomainType(This,eDomainType)
#define ISdoMachine_IsDirectoryAvailable(This,boolDirectoryAvailable) (This)->lpVtbl->IsDirectoryAvailable(This,boolDirectoryAvailable)
#define ISdoMachine_GetAttachedComputer(This,bstrComputerName) (This)->lpVtbl->GetAttachedComputer(This,bstrComputerName)
#define ISdoMachine_GetSDOSchema(This,ppSDOSchema) (This)->lpVtbl->GetSDOSchema(This,ppSDOSchema)
#endif
#endif
  HRESULT WINAPI ISdoMachine_Attach_Proxy(ISdoMachine *This,BSTR bstrComputerName);
  void __RPC_STUB ISdoMachine_Attach_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoMachine_GetDictionarySDO_Proxy(ISdoMachine *This,IUnknown **ppDictionarySDO);
  void __RPC_STUB ISdoMachine_GetDictionarySDO_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoMachine_GetServiceSDO_Proxy(ISdoMachine *This,IASDATASTORE eDataStore,BSTR bstrServiceName,IUnknown **ppServiceSDO);
  void __RPC_STUB ISdoMachine_GetServiceSDO_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoMachine_GetUserSDO_Proxy(ISdoMachine *This,IASDATASTORE eDataStore,BSTR bstrUserName,IUnknown **ppUserSDO);
  void __RPC_STUB ISdoMachine_GetUserSDO_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoMachine_GetOSType_Proxy(ISdoMachine *This,IASOSTYPE *eOSType);
  void __RPC_STUB ISdoMachine_GetOSType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoMachine_GetDomainType_Proxy(ISdoMachine *This,IASDOMAINTYPE *eDomainType);
  void __RPC_STUB ISdoMachine_GetDomainType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoMachine_IsDirectoryAvailable_Proxy(ISdoMachine *This,VARIANT_BOOL *boolDirectoryAvailable);
  void __RPC_STUB ISdoMachine_IsDirectoryAvailable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoMachine_GetAttachedComputer_Proxy(ISdoMachine *This,BSTR *bstrComputerName);
  void __RPC_STUB ISdoMachine_GetAttachedComputer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoMachine_GetSDOSchema_Proxy(ISdoMachine *This,IUnknown **ppSDOSchema);
  void __RPC_STUB ISdoMachine_GetSDOSchema_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISdoServiceControl_INTERFACE_DEFINED__
#define __ISdoServiceControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISdoServiceControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISdoServiceControl : public IDispatch {
  public:
    virtual HRESULT WINAPI StartService(void) = 0;
    virtual HRESULT WINAPI StopService(void) = 0;
    virtual HRESULT WINAPI GetServiceStatus(LONG *status) = 0;
    virtual HRESULT WINAPI ResetService(void) = 0;
  };
#else
  typedef struct ISdoServiceControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISdoServiceControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISdoServiceControl *This);
      ULONG (WINAPI *Release)(ISdoServiceControl *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISdoServiceControl *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISdoServiceControl *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISdoServiceControl *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISdoServiceControl *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *StartService)(ISdoServiceControl *This);
      HRESULT (WINAPI *StopService)(ISdoServiceControl *This);
      HRESULT (WINAPI *GetServiceStatus)(ISdoServiceControl *This,LONG *status);
      HRESULT (WINAPI *ResetService)(ISdoServiceControl *This);
    END_INTERFACE
  } ISdoServiceControlVtbl;
  struct ISdoServiceControl {
    CONST_VTBL struct ISdoServiceControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISdoServiceControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISdoServiceControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISdoServiceControl_Release(This) (This)->lpVtbl->Release(This)
#define ISdoServiceControl_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISdoServiceControl_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISdoServiceControl_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISdoServiceControl_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISdoServiceControl_StartService(This) (This)->lpVtbl->StartService(This)
#define ISdoServiceControl_StopService(This) (This)->lpVtbl->StopService(This)
#define ISdoServiceControl_GetServiceStatus(This,status) (This)->lpVtbl->GetServiceStatus(This,status)
#define ISdoServiceControl_ResetService(This) (This)->lpVtbl->ResetService(This)
#endif
#endif
  HRESULT WINAPI ISdoServiceControl_StartService_Proxy(ISdoServiceControl *This);
  void __RPC_STUB ISdoServiceControl_StartService_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoServiceControl_StopService_Proxy(ISdoServiceControl *This);
  void __RPC_STUB ISdoServiceControl_StopService_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoServiceControl_GetServiceStatus_Proxy(ISdoServiceControl *This,LONG *status);
  void __RPC_STUB ISdoServiceControl_GetServiceStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoServiceControl_ResetService_Proxy(ISdoServiceControl *This);
  void __RPC_STUB ISdoServiceControl_ResetService_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISdo_INTERFACE_DEFINED__
#define __ISdo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISdo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISdo : public IDispatch {
  public:
    virtual HRESULT WINAPI GetPropertyInfo(LONG Id,IUnknown **ppPropertyInfo) = 0;
    virtual HRESULT WINAPI GetProperty(LONG Id,VARIANT *pValue) = 0;
    virtual HRESULT WINAPI PutProperty(LONG Id,VARIANT *pValue) = 0;
    virtual HRESULT WINAPI ResetProperty(LONG Id) = 0;
    virtual HRESULT WINAPI Apply(void) = 0;
    virtual HRESULT WINAPI Restore(void) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnumVARIANT) = 0;
  };
#else
  typedef struct ISdoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISdo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISdo *This);
      ULONG (WINAPI *Release)(ISdo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISdo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISdo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISdo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISdo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetPropertyInfo)(ISdo *This,LONG Id,IUnknown **ppPropertyInfo);
      HRESULT (WINAPI *GetProperty)(ISdo *This,LONG Id,VARIANT *pValue);
      HRESULT (WINAPI *PutProperty)(ISdo *This,LONG Id,VARIANT *pValue);
      HRESULT (WINAPI *ResetProperty)(ISdo *This,LONG Id);
      HRESULT (WINAPI *Apply)(ISdo *This);
      HRESULT (WINAPI *Restore)(ISdo *This);
      HRESULT (WINAPI *get__NewEnum)(ISdo *This,IUnknown **ppEnumVARIANT);
    END_INTERFACE
  } ISdoVtbl;
  struct ISdo {
    CONST_VTBL struct ISdoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISdo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISdo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISdo_Release(This) (This)->lpVtbl->Release(This)
#define ISdo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISdo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISdo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISdo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISdo_GetPropertyInfo(This,Id,ppPropertyInfo) (This)->lpVtbl->GetPropertyInfo(This,Id,ppPropertyInfo)
#define ISdo_GetProperty(This,Id,pValue) (This)->lpVtbl->GetProperty(This,Id,pValue)
#define ISdo_PutProperty(This,Id,pValue) (This)->lpVtbl->PutProperty(This,Id,pValue)
#define ISdo_ResetProperty(This,Id) (This)->lpVtbl->ResetProperty(This,Id)
#define ISdo_Apply(This) (This)->lpVtbl->Apply(This)
#define ISdo_Restore(This) (This)->lpVtbl->Restore(This)
#define ISdo_get__NewEnum(This,ppEnumVARIANT) (This)->lpVtbl->get__NewEnum(This,ppEnumVARIANT)
#endif
#endif
  HRESULT WINAPI ISdo_GetPropertyInfo_Proxy(ISdo *This,LONG Id,IUnknown **ppPropertyInfo);
  void __RPC_STUB ISdo_GetPropertyInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdo_GetProperty_Proxy(ISdo *This,LONG Id,VARIANT *pValue);
  void __RPC_STUB ISdo_GetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdo_PutProperty_Proxy(ISdo *This,LONG Id,VARIANT *pValue);
  void __RPC_STUB ISdo_PutProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdo_ResetProperty_Proxy(ISdo *This,LONG Id);
  void __RPC_STUB ISdo_ResetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdo_Apply_Proxy(ISdo *This);
  void __RPC_STUB ISdo_Apply_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdo_Restore_Proxy(ISdo *This);
  void __RPC_STUB ISdo_Restore_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdo_get__NewEnum_Proxy(ISdo *This,IUnknown **ppEnumVARIANT);
  void __RPC_STUB ISdo_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISdoCollection_INTERFACE_DEFINED__
#define __ISdoCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISdoCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISdoCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(__LONG32 *pCount) = 0;
    virtual HRESULT WINAPI Add(BSTR bstrName,IDispatch **ppItem) = 0;
    virtual HRESULT WINAPI Remove(IDispatch *pItem) = 0;
    virtual HRESULT WINAPI RemoveAll(void) = 0;
    virtual HRESULT WINAPI Reload(void) = 0;
    virtual HRESULT WINAPI IsNameUnique(BSTR bstrName,VARIANT_BOOL *pBool) = 0;
    virtual HRESULT WINAPI Item(VARIANT *Name,IDispatch **pItem) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnumVARIANT) = 0;
  };
#else
  typedef struct ISdoCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISdoCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISdoCollection *This);
      ULONG (WINAPI *Release)(ISdoCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISdoCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISdoCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISdoCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISdoCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ISdoCollection *This,__LONG32 *pCount);
      HRESULT (WINAPI *Add)(ISdoCollection *This,BSTR bstrName,IDispatch **ppItem);
      HRESULT (WINAPI *Remove)(ISdoCollection *This,IDispatch *pItem);
      HRESULT (WINAPI *RemoveAll)(ISdoCollection *This);
      HRESULT (WINAPI *Reload)(ISdoCollection *This);
      HRESULT (WINAPI *IsNameUnique)(ISdoCollection *This,BSTR bstrName,VARIANT_BOOL *pBool);
      HRESULT (WINAPI *Item)(ISdoCollection *This,VARIANT *Name,IDispatch **pItem);
      HRESULT (WINAPI *get__NewEnum)(ISdoCollection *This,IUnknown **ppEnumVARIANT);
    END_INTERFACE
  } ISdoCollectionVtbl;
  struct ISdoCollection {
    CONST_VTBL struct ISdoCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISdoCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISdoCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISdoCollection_Release(This) (This)->lpVtbl->Release(This)
#define ISdoCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISdoCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISdoCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISdoCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISdoCollection_get_Count(This,pCount) (This)->lpVtbl->get_Count(This,pCount)
#define ISdoCollection_Add(This,bstrName,ppItem) (This)->lpVtbl->Add(This,bstrName,ppItem)
#define ISdoCollection_Remove(This,pItem) (This)->lpVtbl->Remove(This,pItem)
#define ISdoCollection_RemoveAll(This) (This)->lpVtbl->RemoveAll(This)
#define ISdoCollection_Reload(This) (This)->lpVtbl->Reload(This)
#define ISdoCollection_IsNameUnique(This,bstrName,pBool) (This)->lpVtbl->IsNameUnique(This,bstrName,pBool)
#define ISdoCollection_Item(This,Name,pItem) (This)->lpVtbl->Item(This,Name,pItem)
#define ISdoCollection_get__NewEnum(This,ppEnumVARIANT) (This)->lpVtbl->get__NewEnum(This,ppEnumVARIANT)
#endif
#endif
  HRESULT WINAPI ISdoCollection_get_Count_Proxy(ISdoCollection *This,__LONG32 *pCount);
  void __RPC_STUB ISdoCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoCollection_Add_Proxy(ISdoCollection *This,BSTR bstrName,IDispatch **ppItem);
  void __RPC_STUB ISdoCollection_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoCollection_Remove_Proxy(ISdoCollection *This,IDispatch *pItem);
  void __RPC_STUB ISdoCollection_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoCollection_RemoveAll_Proxy(ISdoCollection *This);
  void __RPC_STUB ISdoCollection_RemoveAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoCollection_Reload_Proxy(ISdoCollection *This);
  void __RPC_STUB ISdoCollection_Reload_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoCollection_IsNameUnique_Proxy(ISdoCollection *This,BSTR bstrName,VARIANT_BOOL *pBool);
  void __RPC_STUB ISdoCollection_IsNameUnique_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoCollection_Item_Proxy(ISdoCollection *This,VARIANT *Name,IDispatch **pItem);
  void __RPC_STUB ISdoCollection_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoCollection_get__NewEnum_Proxy(ISdoCollection *This,IUnknown **ppEnumVARIANT);
  void __RPC_STUB ISdoCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISdoDictionaryOld_INTERFACE_DEFINED__
#define __ISdoDictionaryOld_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISdoDictionaryOld;
#if defined(__cplusplus) && !defined(CINTERFACE)

  struct ISdoDictionaryOld : public IDispatch {
  public:
    virtual HRESULT WINAPI EnumAttributes(VARIANT *Id,VARIANT *pValues) = 0;
    virtual HRESULT WINAPI GetAttributeInfo(ATTRIBUTEID Id,VARIANT *pInfoIDs,VARIANT *pInfoValues) = 0;
    virtual HRESULT WINAPI EnumAttributeValues(ATTRIBUTEID Id,VARIANT *pValueIds,VARIANT *pValuesDesc) = 0;
    virtual HRESULT WINAPI CreateAttribute(ATTRIBUTEID Id,IDispatch **ppAttributeObject) = 0;
    virtual HRESULT WINAPI GetAttributeID(BSTR bstrAttributeName,ATTRIBUTEID *pId) = 0;
  };
#else
  typedef struct ISdoDictionaryOldVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISdoDictionaryOld *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISdoDictionaryOld *This);
      ULONG (WINAPI *Release)(ISdoDictionaryOld *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISdoDictionaryOld *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISdoDictionaryOld *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISdoDictionaryOld *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISdoDictionaryOld *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *EnumAttributes)(ISdoDictionaryOld *This,VARIANT *Id,VARIANT *pValues);
      HRESULT (WINAPI *GetAttributeInfo)(ISdoDictionaryOld *This,ATTRIBUTEID Id,VARIANT *pInfoIDs,VARIANT *pInfoValues);
      HRESULT (WINAPI *EnumAttributeValues)(ISdoDictionaryOld *This,ATTRIBUTEID Id,VARIANT *pValueIds,VARIANT *pValuesDesc);
      HRESULT (WINAPI *CreateAttribute)(ISdoDictionaryOld *This,ATTRIBUTEID Id,IDispatch **ppAttributeObject);
      HRESULT (WINAPI *GetAttributeID)(ISdoDictionaryOld *This,BSTR bstrAttributeName,ATTRIBUTEID *pId);
    END_INTERFACE
  } ISdoDictionaryOldVtbl;
  struct ISdoDictionaryOld {
    CONST_VTBL struct ISdoDictionaryOldVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISdoDictionaryOld_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISdoDictionaryOld_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISdoDictionaryOld_Release(This) (This)->lpVtbl->Release(This)
#define ISdoDictionaryOld_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISdoDictionaryOld_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISdoDictionaryOld_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISdoDictionaryOld_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISdoDictionaryOld_EnumAttributes(This,Id,pValues) (This)->lpVtbl->EnumAttributes(This,Id,pValues)
#define ISdoDictionaryOld_GetAttributeInfo(This,Id,pInfoIDs,pInfoValues) (This)->lpVtbl->GetAttributeInfo(This,Id,pInfoIDs,pInfoValues)
#define ISdoDictionaryOld_EnumAttributeValues(This,Id,pValueIds,pValuesDesc) (This)->lpVtbl->EnumAttributeValues(This,Id,pValueIds,pValuesDesc)
#define ISdoDictionaryOld_CreateAttribute(This,Id,ppAttributeObject) (This)->lpVtbl->CreateAttribute(This,Id,ppAttributeObject)
#define ISdoDictionaryOld_GetAttributeID(This,bstrAttributeName,pId) (This)->lpVtbl->GetAttributeID(This,bstrAttributeName,pId)
#endif
#endif
  HRESULT WINAPI ISdoDictionaryOld_EnumAttributes_Proxy(ISdoDictionaryOld *This,VARIANT *Id,VARIANT *pValues);
  void __RPC_STUB ISdoDictionaryOld_EnumAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoDictionaryOld_GetAttributeInfo_Proxy(ISdoDictionaryOld *This,ATTRIBUTEID Id,VARIANT *pInfoIDs,VARIANT *pInfoValues);
  void __RPC_STUB ISdoDictionaryOld_GetAttributeInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoDictionaryOld_EnumAttributeValues_Proxy(ISdoDictionaryOld *This,ATTRIBUTEID Id,VARIANT *pValueIds,VARIANT *pValuesDesc);
  void __RPC_STUB ISdoDictionaryOld_EnumAttributeValues_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoDictionaryOld_CreateAttribute_Proxy(ISdoDictionaryOld *This,ATTRIBUTEID Id,IDispatch **ppAttributeObject);
  void __RPC_STUB ISdoDictionaryOld_CreateAttribute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISdoDictionaryOld_GetAttributeID_Proxy(ISdoDictionaryOld *This,BSTR bstrAttributeName,ATTRIBUTEID *pId);
  void __RPC_STUB ISdoDictionaryOld_GetAttributeID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_SdoMachine;
#ifdef __cplusplus
  class SdoMachine;
#endif
#endif

#if (_WIN32_WINNT >= 0x0600)
typedef enum _IDENTITY_TYPE {
  IAS_IDENTITY_NO_DEFAULT   = 1 
} IDENTITY_TYPE;

typedef enum _ATTRIBUTE_FILTER {
  ATTRIBUTE_FILTER_NONE = 0,
  ATTRIBUTE_FILTER_VPN_DIALUP,
  ATTRIBUTE_FILTER_IEEE_802_1x 
} ATTRIBUTEFILTER;

typedef enum REMEDIATIONSERVERGROUPPROPERTIES {
  PROPERTY_REMEDIATIONSERVERGROUP_SERVERS_COLLECTION   = PROPERTY_SDO_START 
} REMEDIATIONSERVERGROUPPROPERTIES;

typedef enum _REMEDIATIONSERVERPROPERTIES {
  PROPERTY_REMEDIATIONSERVER_ADDRESS         = PROPERTY_SDO_START,
  PROPERTY_REMEDIATIONSERVER_FRIENDLY_NAME 
} REMEDIATIONSERVERPROPERTIES;

typedef enum _REMEDIATIONSERVERPROPERTIES {
  PROPERTY_REMEDIATIONSERVERS_SERVERGROUPS   = PROPERTY_COMPONENT_START 
} REMEDIATIONSERVERPROPERTIES;

typedef enum _SHV_COMBINATION_TYPE {
  SHV_COMBINATION_TYPE_ALL_PASS                   = 0,
  SHV_COMBINATION_TYPE_ALL_FAIL,
  SHV_COMBINATION_TYPE_ONE_OR_MORE_PASS,
  SHV_COMBINATION_TYPE_ONE_OR_MORE_FAIL,
  SHV_COMBINATION_TYPE_ONE_OR_MORE_INFECTED,
  SHV_COMBINATION_TYPE_ONE_OR_MORE_TRANSITIONAL,
  SHV_COMBINATION_TYPE_ONE_OR_MORE_UNKNOWN,
  SHV_COMBINATION_TYPE_MAX 
} SHV_COMBINATION_TYPE;

typedef enum _SHVTEMPLATEPROPERTIES {
  PROPERTY_SHV_COMBINATION_TYPE   = PROPERTY_SDO_START,
  PROPERTY_SHV_LIST 
} SHVTEMPLATEPROPERTIES;

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif
#endif
