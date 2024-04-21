/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __RPCDCE_H__
#define __RPCDCE_H__

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _NO_W32_PSEUDO_MODIFIERS
#ifndef IN
#define IN
#endif
#ifndef OUT
#define OUT
#endif
#ifndef OPTIONAL
#define OPTIONAL
#endif
#endif

#ifndef DECLSPEC_NORETURN
#define DECLSPEC_NORETURN __declspec(noreturn)
#endif

#include <specstrings.h>

  typedef unsigned char *RPC_CSTR;
  typedef unsigned short *RPC_WSTR;
  typedef I_RPC_HANDLE RPC_BINDING_HANDLE;
  typedef RPC_BINDING_HANDLE handle_t;

#define rpc_binding_handle_t RPC_BINDING_HANDLE

#include <guiddef.h>

#ifndef UUID_DEFINED
#define UUID_DEFINED
  typedef GUID UUID;
#ifndef uuid_t
#define uuid_t UUID
#endif
#endif

  typedef struct _RPC_BINDING_VECTOR {
    unsigned __LONG32 Count;
    RPC_BINDING_HANDLE BindingH[1];
  } RPC_BINDING_VECTOR;
#ifndef rpc_binding_vector_t
#define rpc_binding_vector_t RPC_BINDING_VECTOR
#endif

  typedef struct _UUID_VECTOR {
    unsigned __LONG32 Count;
    UUID *Uuid[1];
  } UUID_VECTOR;
#ifndef uuid_vector_t
#define uuid_vector_t UUID_VECTOR
#endif

  typedef void *RPC_IF_HANDLE;

#ifndef IFID_DEFINED
#define IFID_DEFINED
  typedef struct _RPC_IF_ID {
    UUID Uuid;
    unsigned short VersMajor;
    unsigned short VersMinor;
  } RPC_IF_ID;
#endif

#define RPC_C_BINDING_INFINITE_TIMEOUT 10
#define RPC_C_BINDING_MIN_TIMEOUT 0
#define RPC_C_BINDING_DEFAULT_TIMEOUT 5
#define RPC_C_BINDING_MAX_TIMEOUT 9

#define RPC_C_CANCEL_INFINITE_TIMEOUT -1

#define RPC_C_LISTEN_MAX_CALLS_DEFAULT 1234
#define RPC_C_PROTSEQ_MAX_REQS_DEFAULT 10

#define RPC_C_BIND_TO_ALL_NICS 1
#define RPC_C_USE_INTERNET_PORT 0x1
#define RPC_C_USE_INTRANET_PORT 0x2
#define RPC_C_DONT_FAIL 0x4

#define RPC_C_MQ_TEMPORARY 0x0000
#define RPC_C_MQ_PERMANENT 0x0001
#define RPC_C_MQ_CLEAR_ON_OPEN 0x0002
#define RPC_C_MQ_USE_EXISTING_SECURITY 0x0004
#define RPC_C_MQ_AUTHN_LEVEL_NONE 0x0000
#define RPC_C_MQ_AUTHN_LEVEL_PKT_INTEGRITY 0x0008
#define RPC_C_MQ_AUTHN_LEVEL_PKT_PRIVACY 0x0010

#define RPC_C_OPT_MQ_DELIVERY 1
#define RPC_C_OPT_MQ_PRIORITY 2
#define RPC_C_OPT_MQ_JOURNAL 3
#define RPC_C_OPT_MQ_ACKNOWLEDGE 4
#define RPC_C_OPT_MQ_AUTHN_SERVICE 5
#define RPC_C_OPT_MQ_AUTHN_LEVEL 6
#define RPC_C_OPT_MQ_TIME_TO_REACH_QUEUE 7
#define RPC_C_OPT_MQ_TIME_TO_BE_RECEIVED 8
#define RPC_C_OPT_BINDING_NONCAUSAL 9
#define RPC_C_OPT_SECURITY_CALLBACK 10
#define RPC_C_OPT_UNIQUE_BINDING 11
#define RPC_C_OPT_CALL_TIMEOUT 12
#define RPC_C_OPT_DONT_LINGER 13
#define RPC_C_OPT_MAX_OPTIONS 14

#define RPC_C_MQ_EXPRESS 0
#define RPC_C_MQ_RECOVERABLE 1

#define RPC_C_MQ_JOURNAL_NONE 0
#define RPC_C_MQ_JOURNAL_DEADLETTER 1
#define RPC_C_MQ_JOURNAL_ALWAYS 2

#define RPC_C_FULL_CERT_CHAIN 0x0001

  typedef struct _RPC_PROTSEQ_VECTORA {
    unsigned int Count;
    unsigned char *Protseq[1];
  } RPC_PROTSEQ_VECTORA;

  typedef struct _RPC_PROTSEQ_VECTORW {
    unsigned int Count;
    unsigned short *Protseq[1];
  } RPC_PROTSEQ_VECTORW;

#define RPC_PROTSEQ_VECTOR __MINGW_NAME_AW(RPC_PROTSEQ_VECTOR)

  typedef struct _RPC_POLICY {
    unsigned int Length;
    unsigned __LONG32 EndpointFlags;
    unsigned __LONG32 NICFlags;
  } RPC_POLICY,*PRPC_POLICY;

  typedef void __RPC_API RPC_OBJECT_INQ_FN(UUID *ObjectUuid,UUID *TypeUuid,RPC_STATUS *Status);
  typedef RPC_STATUS RPC_ENTRY RPC_IF_CALLBACK_FN(RPC_IF_HANDLE InterfaceUuid,void *Context);
  typedef void RPC_ENTRY RPC_SECURITY_CALLBACK_FN(void *Context);

#define RPC_MGR_EPV void

  typedef struct {
    unsigned int Count;
    unsigned __LONG32 Stats[1];
  } RPC_STATS_VECTOR;

#define RPC_C_STATS_CALLS_IN 0
#define RPC_C_STATS_CALLS_OUT 1
#define RPC_C_STATS_PKTS_IN 2
#define RPC_C_STATS_PKTS_OUT 3

  typedef struct {
    unsigned __LONG32 Count;
    RPC_IF_ID *IfId[1];
  } RPC_IF_ID_VECTOR;

#define RpcBindingFromStringBinding __MINGW_NAME_AW(RpcBindingFromStringBinding)
#define RpcBindingToStringBinding __MINGW_NAME_AW(RpcBindingToStringBinding)
#define RpcStringBindingCompose __MINGW_NAME_AW(RpcStringBindingCompose)
#define RpcStringBindingParse __MINGW_NAME_AW(RpcStringBindingParse)
#define RpcStringFree __MINGW_NAME_AW(RpcStringFree)
#define RpcNetworkIsProtseqValid __MINGW_NAME_AW(RpcNetworkIsProtseqValid)
#define RpcNetworkInqProtseqs __MINGW_NAME_AW(RpcNetworkInqProtseqs)
#define RpcProtseqVectorFree __MINGW_NAME_AW(RpcProtseqVectorFree)
#define RpcServerUseProtseq __MINGW_NAME_AW(RpcServerUseProtseq)
#define RpcServerUseProtseqEx __MINGW_NAME_AW(RpcServerUseProtseqEx)
#define RpcServerUseProtseqEp __MINGW_NAME_AW(RpcServerUseProtseqEp)
#define RpcServerUseProtseqEpEx __MINGW_NAME_AW(RpcServerUseProtseqEpEx)
#define RpcServerUseProtseqIf __MINGW_NAME_AW(RpcServerUseProtseqIf)
#define RpcServerUseProtseqIfEx __MINGW_NAME_AW(RpcServerUseProtseqIfEx)
#define RpcMgmtInqServerPrincName __MINGW_NAME_AW(RpcMgmtInqServerPrincName)
#define RpcServerInqDefaultPrincName __MINGW_NAME_AW(RpcServerInqDefaultPrincName)
#define RpcNsBindingInqEntryName __MINGW_NAME_AW(RpcNsBindingInqEntryName)

  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingCopy(RPC_BINDING_HANDLE SourceBinding,RPC_BINDING_HANDLE *DestinationBinding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingFree(RPC_BINDING_HANDLE *Binding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingSetOption(RPC_BINDING_HANDLE hBinding,unsigned __LONG32 option,ULONG_PTR optionValue);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqOption(RPC_BINDING_HANDLE hBinding,unsigned __LONG32 option,ULONG_PTR *pOptionValue);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingFromStringBindingA(RPC_CSTR StringBinding,RPC_BINDING_HANDLE *Binding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingFromStringBindingW(RPC_WSTR StringBinding,RPC_BINDING_HANDLE *Binding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSsGetContextBinding(void *ContextHandle,RPC_BINDING_HANDLE *Binding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqObject(RPC_BINDING_HANDLE Binding,UUID *ObjectUuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingReset(RPC_BINDING_HANDLE Binding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingSetObject(RPC_BINDING_HANDLE Binding,UUID *ObjectUuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtInqDefaultProtectLevel(unsigned __LONG32 AuthnSvc,unsigned __LONG32 *AuthnLevel);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingToStringBindingA(RPC_BINDING_HANDLE Binding,RPC_CSTR *StringBinding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingToStringBindingW(RPC_BINDING_HANDLE Binding,RPC_WSTR *StringBinding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingVectorFree(RPC_BINDING_VECTOR **BindingVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcStringBindingComposeA(RPC_CSTR ObjUuid,RPC_CSTR Protseq,RPC_CSTR NetworkAddr,RPC_CSTR Endpoint,RPC_CSTR Options,RPC_CSTR *StringBinding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcStringBindingComposeW(RPC_WSTR ObjUuid,RPC_WSTR Protseq,RPC_WSTR NetworkAddr,RPC_WSTR Endpoint,RPC_WSTR Options,RPC_WSTR *StringBinding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcStringBindingParseA(RPC_CSTR StringBinding,RPC_CSTR *ObjUuid,RPC_CSTR *Protseq,RPC_CSTR *NetworkAddr,RPC_CSTR *Endpoint,RPC_CSTR *NetworkOptions);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcStringBindingParseW(RPC_WSTR StringBinding,RPC_WSTR *ObjUuid,RPC_WSTR *Protseq,RPC_WSTR *NetworkAddr,RPC_WSTR *Endpoint,RPC_WSTR *NetworkOptions);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcStringFreeA(RPC_CSTR *String);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcStringFreeW(RPC_WSTR *String);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcIfInqId(RPC_IF_HANDLE RpcIfHandle,RPC_IF_ID *RpcIfId);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcNetworkIsProtseqValidA(RPC_CSTR Protseq);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcNetworkIsProtseqValidW(RPC_WSTR Protseq);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtInqComTimeout(RPC_BINDING_HANDLE Binding,unsigned int *Timeout);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtSetComTimeout(RPC_BINDING_HANDLE Binding,unsigned int Timeout);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtSetCancelTimeout(__LONG32 Timeout);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcNetworkInqProtseqsA (RPC_PROTSEQ_VECTORA **ProtseqVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcNetworkInqProtseqsW (RPC_PROTSEQ_VECTORW **ProtseqVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcObjectInqType(UUID *ObjUuid,UUID *TypeUuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcObjectSetInqFn(RPC_OBJECT_INQ_FN *InquiryFn);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcObjectSetType(UUID *ObjUuid,UUID *TypeUuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcProtseqVectorFreeA(RPC_PROTSEQ_VECTORA **ProtseqVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcProtseqVectorFreeW(RPC_PROTSEQ_VECTORW **ProtseqVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerInqBindings (RPC_BINDING_VECTOR **BindingVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerInqIf(RPC_IF_HANDLE IfSpec,UUID *MgrTypeUuid,RPC_MGR_EPV **MgrEpv);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerListen(unsigned int MinimumCallThreads,unsigned int MaxCalls,unsigned int DontWait);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerRegisterIf(RPC_IF_HANDLE IfSpec,UUID *MgrTypeUuid,RPC_MGR_EPV *MgrEpv);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerRegisterIfEx(RPC_IF_HANDLE IfSpec,UUID *MgrTypeUuid,RPC_MGR_EPV *MgrEpv,unsigned int Flags,unsigned int MaxCalls,RPC_IF_CALLBACK_FN *IfCallback);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerRegisterIf2(RPC_IF_HANDLE IfSpec,UUID *MgrTypeUuid,RPC_MGR_EPV *MgrEpv,unsigned int Flags,unsigned int MaxCalls,unsigned int MaxRpcSize,RPC_IF_CALLBACK_FN *IfCallbackFn);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUnregisterIf(RPC_IF_HANDLE IfSpec,UUID *MgrTypeUuid,unsigned int WaitForCallsToComplete);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUnregisterIfEx(RPC_IF_HANDLE IfSpec,UUID *MgrTypeUuid,int RundownContextHandles);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseAllProtseqs(unsigned int MaxCalls,void *SecurityDescriptor);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseAllProtseqsEx(unsigned int MaxCalls,void *SecurityDescriptor,PRPC_POLICY Policy);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseAllProtseqsIf(unsigned int MaxCalls,RPC_IF_HANDLE IfSpec,void *SecurityDescriptor);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseAllProtseqsIfEx(unsigned int MaxCalls,RPC_IF_HANDLE IfSpec,void *SecurityDescriptor,PRPC_POLICY Policy);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqA(RPC_CSTR Protseq,unsigned int MaxCalls,void *SecurityDescriptor);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqExA(RPC_CSTR Protseq,unsigned int MaxCalls,void *SecurityDescriptor,PRPC_POLICY Policy);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqW(RPC_WSTR Protseq,unsigned int MaxCalls,void *SecurityDescriptor);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqExW(RPC_WSTR Protseq,unsigned int MaxCalls,void *SecurityDescriptor,PRPC_POLICY Policy);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqEpA(RPC_CSTR Protseq,unsigned int MaxCalls,RPC_CSTR Endpoint,void *SecurityDescriptor);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqEpExA(RPC_CSTR Protseq,unsigned int MaxCalls,RPC_CSTR Endpoint,void *SecurityDescriptor,PRPC_POLICY Policy);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqEpW(RPC_WSTR Protseq,unsigned int MaxCalls,RPC_WSTR Endpoint,void *SecurityDescriptor);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqEpExW(RPC_WSTR Protseq,unsigned int MaxCalls,RPC_WSTR Endpoint,void *SecurityDescriptor,PRPC_POLICY Policy);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqIfA(RPC_CSTR Protseq,unsigned int MaxCalls,RPC_IF_HANDLE IfSpec,void *SecurityDescriptor);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqIfExA(RPC_CSTR Protseq,unsigned int MaxCalls,RPC_IF_HANDLE IfSpec,void *SecurityDescriptor,PRPC_POLICY Policy);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqIfW(RPC_WSTR Protseq,unsigned int MaxCalls,RPC_IF_HANDLE IfSpec,void *SecurityDescriptor);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerUseProtseqIfExW(RPC_WSTR Protseq,unsigned int MaxCalls,RPC_IF_HANDLE IfSpec,void *SecurityDescriptor,PRPC_POLICY Policy);
  RPCRTAPI void RPC_ENTRY RpcServerYield (void);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtStatsVectorFree(RPC_STATS_VECTOR **StatsVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtInqStats(RPC_BINDING_HANDLE Binding,RPC_STATS_VECTOR **Statistics);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtIsServerListening(RPC_BINDING_HANDLE Binding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtStopServerListening(RPC_BINDING_HANDLE Binding);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtWaitServerListen(void);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtSetServerStackSize(unsigned __LONG32 ThreadStackSize);
  RPCRTAPI void RPC_ENTRY RpcSsDontSerializeContext(void);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtEnableIdleCleanup(void);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtInqIfIds(RPC_BINDING_HANDLE Binding,RPC_IF_ID_VECTOR **IfIdVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcIfIdVectorFree(RPC_IF_ID_VECTOR **IfIdVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtInqServerPrincNameA(RPC_BINDING_HANDLE Binding,unsigned __LONG32 AuthnSvc,RPC_CSTR *ServerPrincName);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtInqServerPrincNameW(RPC_BINDING_HANDLE Binding,unsigned __LONG32 AuthnSvc,RPC_WSTR *ServerPrincName);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerInqDefaultPrincNameA(unsigned __LONG32 AuthnSvc,RPC_CSTR *PrincName);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerInqDefaultPrincNameW(unsigned __LONG32 AuthnSvc,RPC_WSTR *PrincName);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcEpResolveBinding(RPC_BINDING_HANDLE Binding,RPC_IF_HANDLE IfSpec);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcNsBindingInqEntryNameA(RPC_BINDING_HANDLE Binding,unsigned __LONG32 EntryNameSyntax,RPC_CSTR *EntryName);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcNsBindingInqEntryNameW(RPC_BINDING_HANDLE Binding,unsigned __LONG32 EntryNameSyntax,RPC_WSTR *EntryName);

  typedef void *RPC_AUTH_IDENTITY_HANDLE;
  typedef void *RPC_AUTHZ_HANDLE;

#define RPC_C_AUTHN_LEVEL_DEFAULT 0
#define RPC_C_AUTHN_LEVEL_NONE 1
#define RPC_C_AUTHN_LEVEL_CONNECT 2
#define RPC_C_AUTHN_LEVEL_CALL 3
#define RPC_C_AUTHN_LEVEL_PKT 4
#define RPC_C_AUTHN_LEVEL_PKT_INTEGRITY 5
#define RPC_C_AUTHN_LEVEL_PKT_PRIVACY 6

#define RPC_C_IMP_LEVEL_DEFAULT 0
#define RPC_C_IMP_LEVEL_ANONYMOUS 1
#define RPC_C_IMP_LEVEL_IDENTIFY 2
#define RPC_C_IMP_LEVEL_IMPERSONATE 3
#define RPC_C_IMP_LEVEL_DELEGATE 4

#define RPC_C_QOS_IDENTITY_STATIC 0
#define RPC_C_QOS_IDENTITY_DYNAMIC 1

#define RPC_C_QOS_CAPABILITIES_DEFAULT 0x0
#define RPC_C_QOS_CAPABILITIES_MUTUAL_AUTH 0x1
#define RPC_C_QOS_CAPABILITIES_MAKE_FULLSIC 0x2
#define RPC_C_QOS_CAPABILITIES_ANY_AUTHORITY 0x4
#define RPC_C_QOS_CAPABILITIES_IGNORE_DELEGATE_FAILURE 0x8
#define RPC_C_QOS_CAPABILITIES_LOCAL_MA_HINT 0x10

#define RPC_C_PROTECT_LEVEL_DEFAULT (RPC_C_AUTHN_LEVEL_DEFAULT)
#define RPC_C_PROTECT_LEVEL_NONE (RPC_C_AUTHN_LEVEL_NONE)
#define RPC_C_PROTECT_LEVEL_CONNECT (RPC_C_AUTHN_LEVEL_CONNECT)
#define RPC_C_PROTECT_LEVEL_CALL (RPC_C_AUTHN_LEVEL_CALL)
#define RPC_C_PROTECT_LEVEL_PKT (RPC_C_AUTHN_LEVEL_PKT)
#define RPC_C_PROTECT_LEVEL_PKT_INTEGRITY (RPC_C_AUTHN_LEVEL_PKT_INTEGRITY)
#define RPC_C_PROTECT_LEVEL_PKT_PRIVACY (RPC_C_AUTHN_LEVEL_PKT_PRIVACY)

#define RPC_C_AUTHN_NONE 0
#define RPC_C_AUTHN_DCE_PRIVATE 1
#define RPC_C_AUTHN_DCE_PUBLIC 2
#define RPC_C_AUTHN_DEC_PUBLIC 4
#define RPC_C_AUTHN_GSS_NEGOTIATE 9
#define RPC_C_AUTHN_WINNT 10
#define RPC_C_AUTHN_GSS_SCHANNEL 14
#define RPC_C_AUTHN_GSS_KERBEROS 16
#define RPC_C_AUTHN_DPA 17
#define RPC_C_AUTHN_MSN 18
#define RPC_C_AUTHN_DIGEST 21
#define RPC_C_AUTHN_MQ 100
#define RPC_C_AUTHN_DEFAULT __MSABI_LONG(0xFFFFFFFF)

#define RPC_C_NO_CREDENTIALS ((RPC_AUTH_IDENTITY_HANDLE) MAXUINT_PTR)

#define RPC_C_SECURITY_QOS_VERSION __MSABI_LONG(1)
#define RPC_C_SECURITY_QOS_VERSION_1 __MSABI_LONG(1)

  typedef struct _RPC_SECURITY_QOS {
    unsigned __LONG32 Version;
    unsigned __LONG32 Capabilities;
    unsigned __LONG32 IdentityTracking;
    unsigned __LONG32 ImpersonationType;
  } RPC_SECURITY_QOS,*PRPC_SECURITY_QOS;

#ifndef _AUTH_IDENTITY_DEFINED
#define _AUTH_IDENTITY_DEFINED

#define SEC_WINNT_AUTH_IDENTITY_ANSI 0x1
#define SEC_WINNT_AUTH_IDENTITY_UNICODE 0x2

  typedef struct _SEC_WINNT_AUTH_IDENTITY_W {
    unsigned short *User;
    unsigned __LONG32 UserLength;
    unsigned short *Domain;
    unsigned __LONG32 DomainLength;
    unsigned short *Password;
    unsigned __LONG32 PasswordLength;
    unsigned __LONG32 Flags;
  } SEC_WINNT_AUTH_IDENTITY_W,*PSEC_WINNT_AUTH_IDENTITY_W;

  typedef struct _SEC_WINNT_AUTH_IDENTITY_A {
    unsigned char *User;
    unsigned __LONG32 UserLength;
    unsigned char *Domain;
    unsigned __LONG32 DomainLength;
    unsigned char *Password;
    unsigned __LONG32 PasswordLength;
    unsigned __LONG32 Flags;
  } SEC_WINNT_AUTH_IDENTITY_A,*PSEC_WINNT_AUTH_IDENTITY_A;

#define SEC_WINNT_AUTH_IDENTITY __MINGW_NAME_UAW(SEC_WINNT_AUTH_IDENTITY)
#define PSEC_WINNT_AUTH_IDENTITY __MINGW_NAME_UAW(PSEC_WINNT_AUTH_IDENTITY)
#define _SEC_WINNT_AUTH_IDENTITY __MINGW_NAME_UAW(_SEC_WINNT_AUTH_IDENTITY)

#define RPC_C_SECURITY_QOS_VERSION_2 __MSABI_LONG(2)

#define RPC_C_AUTHN_INFO_TYPE_HTTP 1

#define RPC_C_HTTP_AUTHN_TARGET_SERVER 1
#define RPC_C_HTTP_AUTHN_TARGET_PROXY 2

#define RPC_C_HTTP_AUTHN_SCHEME_BASIC 0x00000001
#define RPC_C_HTTP_AUTHN_SCHEME_NTLM 0x00000002
#define RPC_C_HTTP_AUTHN_SCHEME_PASSPORT 0x00000004
#define RPC_C_HTTP_AUTHN_SCHEME_DIGEST 0x00000008
#define RPC_C_HTTP_AUTHN_SCHEME_NEGOTIATE 0x00000010
#define RPC_C_HTTP_AUTHN_SCHEME_CERT 0x00010000

#define RPC_C_HTTP_FLAG_USE_SSL 1
#define RPC_C_HTTP_FLAG_USE_FIRST_AUTH_SCHEME 2
#define RPC_C_HTTP_FLAG_IGNORE_CERT_CN_INVALID 8

  typedef struct _RPC_HTTP_TRANSPORT_CREDENTIALS_W {
    SEC_WINNT_AUTH_IDENTITY_W *TransportCredentials;
    unsigned __LONG32 Flags;
    unsigned __LONG32 AuthenticationTarget;
    unsigned __LONG32 NumberOfAuthnSchemes;
    unsigned __LONG32 *AuthnSchemes;
    unsigned short *ServerCertificateSubject;
  } RPC_HTTP_TRANSPORT_CREDENTIALS_W,*PRPC_HTTP_TRANSPORT_CREDENTIALS_W;

  typedef struct _RPC_HTTP_TRANSPORT_CREDENTIALS_A {
    SEC_WINNT_AUTH_IDENTITY_A *TransportCredentials;
    unsigned __LONG32 Flags;
    unsigned __LONG32 AuthenticationTarget;
    unsigned __LONG32 NumberOfAuthnSchemes;
    unsigned __LONG32 *AuthnSchemes;
    unsigned char *ServerCertificateSubject;
  } RPC_HTTP_TRANSPORT_CREDENTIALS_A,*PRPC_HTTP_TRANSPORT_CREDENTIALS_A;

  typedef struct _RPC_SECURITY_QOS_V2_W {
    unsigned __LONG32 Version;
    unsigned __LONG32 Capabilities;
    unsigned __LONG32 IdentityTracking;
    unsigned __LONG32 ImpersonationType;
    unsigned __LONG32 AdditionalSecurityInfoType;
    union {
      RPC_HTTP_TRANSPORT_CREDENTIALS_W *HttpCredentials;
    } u;
  } RPC_SECURITY_QOS_V2_W,*PRPC_SECURITY_QOS_V2_W;

  typedef struct _RPC_SECURITY_QOS_V2_A {
    unsigned __LONG32 Version;
    unsigned __LONG32 Capabilities;
    unsigned __LONG32 IdentityTracking;
    unsigned __LONG32 ImpersonationType;
    unsigned __LONG32 AdditionalSecurityInfoType;
    union {
      RPC_HTTP_TRANSPORT_CREDENTIALS_A *HttpCredentials;
    } u;
  } RPC_SECURITY_QOS_V2_A,*PRPC_SECURITY_QOS_V2_A;

#define RPC_C_SECURITY_QOS_VERSION_3 __MSABI_LONG(3)

  typedef struct _RPC_SECURITY_QOS_V3_W {
    unsigned __LONG32 Version;
    unsigned __LONG32 Capabilities;
    unsigned __LONG32 IdentityTracking;
    unsigned __LONG32 ImpersonationType;
    unsigned __LONG32 AdditionalSecurityInfoType;
    union {
      RPC_HTTP_TRANSPORT_CREDENTIALS_W *HttpCredentials;
    } u;
    void *Sid;
  } RPC_SECURITY_QOS_V3_W,*PRPC_SECURITY_QOS_V3_W;

  typedef struct _RPC_SECURITY_QOS_V3_A {
    unsigned __LONG32 Version;
    unsigned __LONG32 Capabilities;
    unsigned __LONG32 IdentityTracking;
    unsigned __LONG32 ImpersonationType;
    unsigned __LONG32 AdditionalSecurityInfoType;
    union {
      RPC_HTTP_TRANSPORT_CREDENTIALS_A *HttpCredentials;
    } u;
    void *Sid;
  } RPC_SECURITY_QOS_V3_A,*PRPC_SECURITY_QOS_V3_A;
#endif

#define RPC_SECURITY_QOS_V2 __MINGW_NAME_UAW(RPC_SECURITY_QOS_V2)
#define PRPC_SECURITY_QOS_V2 __MINGW_NAME_UAW(PRPC_SECURITY_QOS_V2)
#define _RPC_SECURITY_QOS_V2 __MINGW_NAME_UAW(_RPC_SECURITY_QOS_V2)
#define RPC_HTTP_TRANSPORT_CREDENTIALS __MINGW_NAME_UAW(RPC_HTTP_TRANSPORT_CREDENTIALS)
#define PRPC_HTTP_TRANSPORT_CREDENTIALS __MINGW_NAME_UAW(PRPC_HTTP_TRANSPORT_CREDENTIALS)
#define _RPC_HTTP_TRANSPORT_CREDENTIALS __MINGW_NAME_UAW(_RPC_HTTP_TRANSPORT_CREDENTIALS)
#define RPC_SECURITY_QOS_V3 __MINGW_NAME_UAW(RPC_SECURITY_QOS_V3)
#define PRPC_SECURITY_QOS_V3 __MINGW_NAME_UAW(PRPC_SECURITY_QOS_V3)
#define _RPC_SECURITY_QOS_V3 __MINGW_NAME_UAW(_RPC_SECURITY_QOS_V3)

  typedef enum _RPC_HTTP_REDIRECTOR_STAGE {
    RPCHTTP_RS_REDIRECT = 1,RPCHTTP_RS_ACCESS_1,RPCHTTP_RS_SESSION,RPCHTTP_RS_ACCESS_2,RPCHTTP_RS_INTERFACE
  } RPC_HTTP_REDIRECTOR_STAGE;

  typedef RPC_STATUS (__RPC_API *RPC_NEW_HTTP_PROXY_CHANNEL)(RPC_HTTP_REDIRECTOR_STAGE RedirectorStage,unsigned short *ServerName,unsigned short *ServerPort,unsigned short *RemoteUser,unsigned short *AuthType,void *ResourceUuid,void *Metadata,void *SessionId,void *Interface,void *Reserved,unsigned __LONG32 Flags,unsigned short **NewServerName,unsigned short **NewServerPort);
  typedef void (__RPC_API *RPC_HTTP_PROXY_FREE_STRING)(unsigned short *String);

#define RPC_C_AUTHZ_NONE 0
#define RPC_C_AUTHZ_NAME 1
#define RPC_C_AUTHZ_DCE 2
#define RPC_C_AUTHZ_DEFAULT 0xffffffff

  RPCRTAPI RPC_STATUS RPC_ENTRY RpcImpersonateClient(RPC_BINDING_HANDLE BindingHandle);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcRevertToSelfEx(RPC_BINDING_HANDLE BindingHandle);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcRevertToSelf(void);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqAuthClientA(RPC_BINDING_HANDLE ClientBinding,RPC_AUTHZ_HANDLE *Privs,RPC_CSTR *ServerPrincName,unsigned __LONG32 *AuthnLevel,unsigned __LONG32 *AuthnSvc,unsigned __LONG32 *AuthzSvc);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqAuthClientW(RPC_BINDING_HANDLE ClientBinding,RPC_AUTHZ_HANDLE *Privs,RPC_WSTR *ServerPrincName,unsigned __LONG32 *AuthnLevel,unsigned __LONG32 *AuthnSvc,unsigned __LONG32 *AuthzSvc);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqAuthClientExA(RPC_BINDING_HANDLE ClientBinding,RPC_AUTHZ_HANDLE *Privs,RPC_CSTR *ServerPrincName,unsigned __LONG32 *AuthnLevel,unsigned __LONG32 *AuthnSvc,unsigned __LONG32 *AuthzSvc,unsigned __LONG32 Flags);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqAuthClientExW(RPC_BINDING_HANDLE ClientBinding,RPC_AUTHZ_HANDLE *Privs,RPC_WSTR *ServerPrincName,unsigned __LONG32 *AuthnLevel,unsigned __LONG32 *AuthnSvc,unsigned __LONG32 *AuthzSvc,unsigned __LONG32 Flags);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqAuthInfoA(RPC_BINDING_HANDLE Binding,RPC_CSTR *ServerPrincName,unsigned __LONG32 *AuthnLevel,unsigned __LONG32 *AuthnSvc,RPC_AUTH_IDENTITY_HANDLE *AuthIdentity,unsigned __LONG32 *AuthzSvc);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqAuthInfoW(RPC_BINDING_HANDLE Binding,RPC_WSTR *ServerPrincName,unsigned __LONG32 *AuthnLevel,unsigned __LONG32 *AuthnSvc,RPC_AUTH_IDENTITY_HANDLE *AuthIdentity,unsigned __LONG32 *AuthzSvc);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingSetAuthInfoA(RPC_BINDING_HANDLE Binding,RPC_CSTR ServerPrincName,unsigned __LONG32 AuthnLevel,unsigned __LONG32 AuthnSvc,RPC_AUTH_IDENTITY_HANDLE AuthIdentity,unsigned __LONG32 AuthzSvc);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingSetAuthInfoExA(RPC_BINDING_HANDLE Binding,RPC_CSTR ServerPrincName,unsigned __LONG32 AuthnLevel,unsigned __LONG32 AuthnSvc,RPC_AUTH_IDENTITY_HANDLE AuthIdentity,unsigned __LONG32 AuthzSvc,RPC_SECURITY_QOS *SecurityQos);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingSetAuthInfoW(RPC_BINDING_HANDLE Binding,RPC_WSTR ServerPrincName,unsigned __LONG32 AuthnLevel,unsigned __LONG32 AuthnSvc,RPC_AUTH_IDENTITY_HANDLE AuthIdentity,unsigned __LONG32 AuthzSvc);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingSetAuthInfoExW(RPC_BINDING_HANDLE Binding,RPC_WSTR ServerPrincName,unsigned __LONG32 AuthnLevel,unsigned __LONG32 AuthnSvc,RPC_AUTH_IDENTITY_HANDLE AuthIdentity,unsigned __LONG32 AuthzSvc,RPC_SECURITY_QOS *SecurityQOS);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqAuthInfoExA(RPC_BINDING_HANDLE Binding,RPC_CSTR *ServerPrincName,unsigned __LONG32 *AuthnLevel,unsigned __LONG32 *AuthnSvc,RPC_AUTH_IDENTITY_HANDLE *AuthIdentity,unsigned __LONG32 *AuthzSvc,unsigned __LONG32 RpcQosVersion,RPC_SECURITY_QOS *SecurityQOS);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingInqAuthInfoExW(RPC_BINDING_HANDLE Binding,RPC_WSTR *ServerPrincName,unsigned __LONG32 *AuthnLevel,unsigned __LONG32 *AuthnSvc,RPC_AUTH_IDENTITY_HANDLE *AuthIdentity,unsigned __LONG32 *AuthzSvc,unsigned __LONG32 RpcQosVersion,RPC_SECURITY_QOS *SecurityQOS);

  typedef void (__RPC_API *RPC_AUTH_KEY_RETRIEVAL_FN)(void *Arg,unsigned short *ServerPrincName,unsigned __LONG32 KeyVer,void **Key,RPC_STATUS *Status);

  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerRegisterAuthInfoA(RPC_CSTR ServerPrincName,unsigned __LONG32 AuthnSvc,RPC_AUTH_KEY_RETRIEVAL_FN GetKeyFn,void *Arg);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerRegisterAuthInfoW(RPC_WSTR ServerPrincName,unsigned __LONG32 AuthnSvc,RPC_AUTH_KEY_RETRIEVAL_FN GetKeyFn,void *Arg);

#define RpcBindingInqAuthClient __MINGW_NAME_AW(RpcBindingInqAuthClient)
#define RpcBindingInqAuthClientEx __MINGW_NAME_AW(RpcBindingInqAuthClientEx)
#define RpcBindingInqAuthInfo __MINGW_NAME_AW(RpcBindingInqAuthInfo)
#define RpcBindingSetAuthInfo __MINGW_NAME_AW(RpcBindingSetAuthInfo)
#define RpcServerRegisterAuthInfo __MINGW_NAME_AW(RpcServerRegisterAuthInfo)
#define RpcBindingInqAuthInfoEx __MINGW_NAME_AW(RpcBindingInqAuthInfoEx)
#define RpcBindingSetAuthInfoEx __MINGW_NAME_AW(RpcBindingSetAuthInfoEx)

#ifndef __ia64__
  typedef struct {
    unsigned char *UserName;
    unsigned char *ComputerName;
    unsigned short Privilege;
    unsigned __LONG32 AuthFlags;
  } RPC_CLIENT_INFORMATION1,*PRPC_CLIENT_INFORMATION1;
#endif

#define UuidFromString __MINGW_NAME_AW(UuidFromString)
#define UuidToString __MINGW_NAME_AW(UuidToString)
#define RpcEpRegisterNoReplace __MINGW_NAME_AW(RpcEpRegisterNoReplace)
#define RpcEpRegister __MINGW_NAME_AW(RpcEpRegister)
#define DceErrorInqText __MINGW_NAME_AW(DceErrorInqText)

#define DCE_C_ERROR_STRING_LEN 256

  RPCRTAPI RPC_STATUS RPC_ENTRY RpcBindingServerFromClient(RPC_BINDING_HANDLE ClientBinding,RPC_BINDING_HANDLE *ServerBinding);
  RPCRTAPI DECLSPEC_NORETURN void RPC_ENTRY RpcRaiseException(RPC_STATUS exception);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcTestCancel(void);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcServerTestCancel(RPC_BINDING_HANDLE BindingHandle);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcCancelThread(void *Thread);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcCancelThreadEx(void *Thread,__LONG32 Timeout);
  RPCRTAPI RPC_STATUS RPC_ENTRY UuidCreate(UUID *Uuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY UuidCreateSequential(UUID *Uuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY UuidToStringA(const UUID *Uuid,RPC_CSTR *StringUuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY UuidFromStringA(RPC_CSTR StringUuid,UUID *Uuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY UuidToStringW(const UUID *Uuid,RPC_WSTR *StringUuid);
  RPCRTAPI RPC_STATUS RPC_ENTRY UuidFromStringW(RPC_WSTR StringUuid,UUID *Uuid);
  RPCRTAPI signed int RPC_ENTRY UuidCompare(UUID *Uuid1,UUID *Uuid2,RPC_STATUS *Status);
  RPCRTAPI RPC_STATUS RPC_ENTRY UuidCreateNil(UUID *NilUuid);
  RPCRTAPI int RPC_ENTRY UuidEqual(UUID *Uuid1,UUID *Uuid2,RPC_STATUS *Status);
  RPCRTAPI unsigned short RPC_ENTRY UuidHash(UUID *Uuid,RPC_STATUS *Status);
  RPCRTAPI int RPC_ENTRY UuidIsNil(UUID *Uuid,RPC_STATUS *Status);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcEpRegisterNoReplaceA(RPC_IF_HANDLE IfSpec,RPC_BINDING_VECTOR *BindingVector,UUID_VECTOR *UuidVector,RPC_CSTR Annotation);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcEpRegisterNoReplaceW(RPC_IF_HANDLE IfSpec,RPC_BINDING_VECTOR *BindingVector,UUID_VECTOR *UuidVector,RPC_WSTR Annotation);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcEpRegisterA(RPC_IF_HANDLE IfSpec,RPC_BINDING_VECTOR *BindingVector,UUID_VECTOR *UuidVector,RPC_CSTR Annotation);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcEpRegisterW(RPC_IF_HANDLE IfSpec,RPC_BINDING_VECTOR *BindingVector,UUID_VECTOR *UuidVector,RPC_WSTR Annotation);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcEpUnregister(RPC_IF_HANDLE IfSpec,RPC_BINDING_VECTOR *BindingVector,UUID_VECTOR *UuidVector);
  RPCRTAPI RPC_STATUS RPC_ENTRY DceErrorInqTextA(RPC_STATUS RpcStatus,RPC_CSTR ErrorText);
  RPCRTAPI RPC_STATUS RPC_ENTRY DceErrorInqTextW(RPC_STATUS RpcStatus,RPC_WSTR ErrorText);

  typedef I_RPC_HANDLE *RPC_EP_INQ_HANDLE;

#define RPC_C_EP_ALL_ELTS 0
#define RPC_C_EP_MATCH_BY_IF 1
#define RPC_C_EP_MATCH_BY_OBJ 2
#define RPC_C_EP_MATCH_BY_BOTH 3

#define RPC_C_VERS_ALL 1
#define RPC_C_VERS_COMPATIBLE 2
#define RPC_C_VERS_EXACT 3
#define RPC_C_VERS_MAJOR_ONLY 4
#define RPC_C_VERS_UPTO 5

#define RpcMgmtEpEltInqNext __MINGW_NAME_AW(RpcMgmtEpEltInqNext)

  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtEpEltInqBegin(RPC_BINDING_HANDLE EpBinding,unsigned __LONG32 InquiryType,RPC_IF_ID *IfId,unsigned __LONG32 VersOption,UUID *ObjectUuid,RPC_EP_INQ_HANDLE *InquiryContext);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtEpEltInqDone(RPC_EP_INQ_HANDLE *InquiryContext);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtEpEltInqNextA(RPC_EP_INQ_HANDLE InquiryContext,RPC_IF_ID *IfId,RPC_BINDING_HANDLE *Binding,UUID *ObjectUuid,RPC_CSTR *Annotation);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtEpEltInqNextW(RPC_EP_INQ_HANDLE InquiryContext,RPC_IF_ID *IfId,RPC_BINDING_HANDLE *Binding,UUID *ObjectUuid,RPC_WSTR *Annotation);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtEpUnregister(RPC_BINDING_HANDLE EpBinding,RPC_IF_ID *IfId,RPC_BINDING_HANDLE Binding,UUID *ObjectUuid);

  typedef int (__RPC_API *RPC_MGMT_AUTHORIZATION_FN)(RPC_BINDING_HANDLE ClientBinding,unsigned __LONG32 RequestedMgmtOperation,RPC_STATUS *Status);

#define RPC_C_MGMT_INQ_IF_IDS 0
#define RPC_C_MGMT_INQ_PRINC_NAME 1
#define RPC_C_MGMT_INQ_STATS 2
#define RPC_C_MGMT_IS_SERVER_LISTEN 3
#define RPC_C_MGMT_STOP_SERVER_LISTEN 4

  RPCRTAPI RPC_STATUS RPC_ENTRY RpcMgmtSetAuthorizationFn(RPC_MGMT_AUTHORIZATION_FN AuthorizationFn);

#define RPC_C_PARM_MAX_PACKET_LENGTH 1
#define RPC_C_PARM_BUFFER_LENGTH 2

#define RPC_IF_AUTOLISTEN 0x0001
#define RPC_IF_OLE 0x0002
#define RPC_IF_ALLOW_UNKNOWN_AUTHORITY 0x0004
#define RPC_IF_ALLOW_SECURE_ONLY 0x0008
#define RPC_IF_ALLOW_CALLBACKS_WITH_NO_AUTH 0x0010
#define RPC_IF_ALLOW_LOCAL_ONLY 0x0020
#define RPC_IF_SEC_NO_CACHE 0x0040

#if (_WIN32_WINNT >= 0x0600)

typedef struct _RPC_BINDING_HANDLE_OPTIONS_V1 {
  unsigned __LONG32 Version;
  unsigned __LONG32 Flags;
  unsigned __LONG32 ComTimeout;
  unsigned __LONG32 CallTimeout;
} RPC_BINDING_HANDLE_OPTIONS_V1, RPC_BINDING_HANDLE_OPTIONS;

typedef struct {
  unsigned __LONG32       Version;
  unsigned short          *ServerPrincName;
  unsigned __LONG32       AuthnLevel;
  unsigned __LONG32       AuthnSvc;
  SEC_WINNT_AUTH_IDENTITY *AuthIdentity;
  RPC_SECURITY_QOS        *SecurityQos;
} RPC_BINDING_HANDLE_SECURITY_V1, RPC_BINDING_HANDLE_SECURITY;

typedef struct _RPC_BINDING_HANDLE_TEMPLATE {
  unsigned __LONG32  Version;
  unsigned __LONG32  Flags;
  unsigned __LONG32  ProtocolSequence;
  unsigned short *NetworkAddress;
  unsigned short *StringEndpoint;
  union {
    unsigned short *Reserved;
  } u1;
  UUID           ObjectUuid;
} RPC_BINDING_HANDLE_TEMPLATE_V1, RPC_BINDING_HANDLE_TEMPLATE;

#define RPC_CALL_STATUS_IN_PROGRESS 0x01
#define RPC_CALL_STATUS_CANCELLED 0x02
#define RPC_CALL_STATUS_DISCONNECTED 0x03

RPC_STATUS RPC_ENTRY RpcBindingCreateA(
  RPC_BINDING_HANDLE_TEMPLATE *Template,
  RPC_BINDING_HANDLE_SECURITY *Security,
  RPC_BINDING_HANDLE_OPTIONS *Options,
  RPC_BINDING_HANDLE *Binding
);

RPC_STATUS RPC_ENTRY RpcBindingCreateW(
  RPC_BINDING_HANDLE_TEMPLATE *Template,
  RPC_BINDING_HANDLE_SECURITY *Security,
  RPC_BINDING_HANDLE_OPTIONS *Options,
  RPC_BINDING_HANDLE *Binding
);
#define RpcBindingCreate __MINGW_NAME_AW(RpcBindingCreate)

RPC_STATUS RpcServerInqBindingHandle(
    RPC_BINDING_HANDLE *Binding
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

#include <rpcdcep.h>

#ifdef __cplusplus
}
#endif
#endif
