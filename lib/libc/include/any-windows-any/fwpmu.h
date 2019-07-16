/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_FWPMU
#define _INC_FWPMU
#include <rpc.h>
#include <fwptypes.h>
#include <fwpmtypes.h>
#include <iketypes.h>
#include <ipsectypes.h>

#ifdef __cplusplus
extern "C" {
#endif

#if (_WIN32_WINNT >= 0x0600)

#ifndef MAXUINT64
#define MAXUINT64 (0xFFFFFFFFFFFFFFFFULL)
#endif /* MAXUINT64 */

#define FWPM_AUTO_WEIGHT_BITS (60)
#define FWPM_AUTO_WEIGHT_MAX (MAXUINT64 >> 4)
#define FWPM_WEIGHT_RANGE_IKE_EXEMPTIONS (0xC)
#define FWPM_WEIGHT_RANGE_IPSEC (0x0)
#define FWPM_WEIGHT_RANGE_MAX (MAXUINT64 >> 60)

DEFINE_GUID(FWPM_PROVIDER_IKEEXT,0x10AD9216,0xCCDE,0x456C,0x8B,0x16,0xE9,0xF0,0x4E,0x60,0xA9,0x0B);
DEFINE_GUID(FWPM_PROVIDER_TCP_CHIMNEY_OFFLOAD,0x896AA19E,0x9A34,0x4BCB,0xAE,0x79,0xBE,0xB9,0x12,0x7C,0x84,0xB9);

typedef UINT32 IPSEC_SA_SPI;

typedef void ( CALLBACK *FWPM_CALLOUT_CHANGE_CALLBACK0 )(
  void *context,
  const FWPM_CALLOUT_CHANGE0 *change
);

typedef void ( CALLBACK *FWPM_FILTER_CHANGE_CALLBACK0 )(
  void *context,
  const FWPM_FILTER_CHANGE0 *change
);

typedef void ( CALLBACK *FWPM_PROVIDER_CHANGE_CALLBACK0 )(
  void *context,
  const FWPM_PROVIDER_CHANGE0 *change
);

typedef void ( CALLBACK *FWPM_PROVIDER_CONTEXT_CHANGE_CALLBACK0 )(
  void *context,
  const FWPM_PROVIDER_CONTEXT_CHANGE0 *change
);

typedef void ( CALLBACK *FWPM_SUBLAYER_CHANGE_CALLBACK0 )(
  void *context,
  const FWPM_SUBLAYER_CHANGE0 *change
);

DWORD WINAPI FwpmCalloutSubscribeChanges0(
  HANDLE engineHandle,
  const FWPM_CALLOUT_SUBSCRIPTION0 *subscription,
  FWPM_CALLOUT_CHANGE_CALLBACK0 callback,
  void *context,
  HANDLE *changeHandle
);

DWORD WINAPI FwpmEngineOpen0(
  const wchar_t *serverName,
  UINT32 authnService,
  SEC_WINNT_AUTH_IDENTITY_W *authIdentity,
  const FWPM_SESSION0 *session,
  HANDLE *engineHandle
);

DWORD WINAPI FwpmCalloutAdd0(
  HANDLE engineHandle,
  const FWPM_CALLOUT0 *callout,
  PSECURITY_DESCRIPTOR sd,
  UINT32 *id
);

DWORD WINAPI FwpmFilterAdd0(
  HANDLE engineHandle,
  const FWPM_FILTER0 *filter,
  PSECURITY_DESCRIPTOR sd,
  UINT64 *id
);

DWORD WINAPI FwpmEngineClose0(
  HANDLE engineHandle
);

DWORD WINAPI FwpmFilterSubscribeChanges0(
  HANDLE engineHandle,
  const FWPM_FILTER_SUBSCRIPTION0 *subscription,
  FWPM_FILTER_CHANGE_CALLBACK0 callback,
  void *context,
  HANDLE *changeHandle
);

DWORD WINAPI FwpmProviderSubscribeChanges0(
  HANDLE engineHandle,
  const FWPM_PROVIDER_SUBSCRIPTION0 *subscription,
  FWPM_PROVIDER_CHANGE_CALLBACK0 callback,
  void *context,
  HANDLE *changeHandle
);

DWORD WINAPI FwpmProviderContextSubscribeChanges0(
  HANDLE engineHandle,
  const FWPM_PROVIDER_CONTEXT_SUBSCRIPTION0 *subscription,
  FWPM_PROVIDER_CONTEXT_CHANGE_CALLBACK0 callback,
  void *context,
  HANDLE *changeHandle
);

DWORD WINAPI FwpmProviderContextAdd0(
  HANDLE engineHandle,
  const FWPM_PROVIDER_CONTEXT0 *providerContext,
  PSECURITY_DESCRIPTOR sd,
  UINT64 *id
);

DWORD WINAPI FwpmSubLayerSubscribeChanges0(
  HANDLE engineHandle,
  const FWPM_SUBLAYER_SUBSCRIPTION0 *subscription,
  FWPM_SUBLAYER_CHANGE_CALLBACK0 callback,
  void *context,
  HANDLE *changeHandle
);

DWORD WINAPI FwpmSubLayerAdd0(
  HANDLE engineHandle,
  const FWPM_SUBLAYER0 *subLayer,
  PSECURITY_DESCRIPTOR sd
);

DWORD WINAPI FwpmCalloutCreateEnumHandle0(
  HANDLE engineHandle,
  const FWPM_CALLOUT_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI FwpmCalloutDeleteById0(
  HANDLE engineHandle,
  UINT32 id
);

DWORD WINAPI FwpmCalloutDeleteByKey0(
  HANDLE engineHandle,
  const GUID *key
);

DWORD WINAPI FwpmCalloutDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmCalloutEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_CALLOUT0 ***entries,
  UINT32 *numEntriesReturned
);

void WINAPI FwpmFreeMemory0(
  void **p
);

DWORD WINAPI FwpmCalloutGetById0(
  HANDLE engineHandle,
  UINT32 id,
  FWPM_CALLOUT0 **callout
);

DWORD WINAPI FwpmCalloutGetByKey0(
  HANDLE engineHandle,
  const GUID *key,
  FWPM_CALLOUT0 **callout
);

DWORD WINAPI FwpmCalloutGetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI FwpmCalloutSetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI FwpmCalloutSubscriptionsGet0(
  HANDLE engineHandle,
  FWPM_CALLOUT_SUBSCRIPTION0 ***entries,
  UINT32 *numEntries
);

DWORD WINAPI FwpmCalloutUnsubscribeChanges0(
  HANDLE engineHandle,
  HANDLE changeHandle
);

#define FWPM_NET_EVENT_KEYWORD_INBOUND_MCAST 1
#define FWPM_NET_EVENT_KEYWORD_INBOUND_BCAST 2

DWORD WINAPI FwpmEngineGetOption0(
  HANDLE engineHandle,
  FWPM_ENGINE_OPTION option,
  FWP_VALUE0 **value
);

DWORD WINAPI FwpmEngineGetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI FwpmEngineSetOption0(
  HANDLE engineHandle,
  FWPM_ENGINE_OPTION option,
  const FWP_VALUE0 *newValue
);

DWORD WINAPI IPsecSaDbSetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI FwpmFilterCreateEnumHandle0(
  HANDLE engineHandle,
  const FWPM_FILTER_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI FwpmFilterDeleteById0(
  HANDLE engineHandle,
  UINT64 id
);

DWORD WINAPI FwpmFilterDeleteByKey0(
  HANDLE engineHandle,
  const GUID *key
);

DWORD WINAPI FwpmFilterDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmFilterEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_FILTER0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmFilterGetById0(
  HANDLE engineHandle,
  UINT64 id,
  FWPM_FILTER0 **filter
);

DWORD WINAPI FwpmFilterGetByKey0(
  HANDLE engineHandle,
  const GUID *key,
  FWPM_FILTER0 **filter
);

DWORD WINAPI FwpmFilterGetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI FwpmFilterSetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI FwpmFilterSubscriptionsGet0(
  HANDLE engineHandle,
  FWPM_FILTER_SUBSCRIPTION0 ***entries,
  UINT32 *numEntries
);

DWORD WINAPI FwpmFilterUnsubscribeChanges0(
  HANDLE engineHandle,
  HANDLE changeHandle
);

DWORD WINAPI FwpmGetAppIdFromFileName0(
  const wchar_t *fileName,
  FWP_BYTE_BLOB **appId
);

DWORD WINAPI FwpmIpsecTunnelAdd0(
  HANDLE engineHandle,
  UINT32 flags,
  const FWPM_PROVIDER_CONTEXT0 *mainModePolicy,
  const FWPM_PROVIDER_CONTEXT0 *tunnelPolicy,
  UINT32 numFilterConditions,
  const FWPM_FILTER_CONDITION0 *filterConditions,
  PSECURITY_DESCRIPTOR sd
);

DWORD WINAPI FwpmIPsecTunnelDeleteByKey0(
  HANDLE engineHandle,
  const GUID *key
);

DWORD WINAPI FwpmLayerCreateEnumHandle0(
  HANDLE engineHandle,
  const FWPM_LAYER_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI FwpmLayerDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmLayerEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_LAYER0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmLayerGetById0(
  HANDLE engineHandle,
  UINT16 id,
  FWPM_LAYER0 **layer
);

DWORD WINAPI FwpmLayerGetByKey0(
  HANDLE engineHandle,
  const GUID *key,
  FWPM_LAYER0 **layer
);

DWORD WINAPI FwpmLayerGetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI FwpmLayerSetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI FwpmNetEventCreateEnumHandle0(
  HANDLE engineHandle,
  const FWPM_NET_EVENT_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI FwpmNetEventDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmNetEventEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_NET_EVENT0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmNetEventsGetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI FwpmNetEventsSetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI FwpmProviderAdd0(
  HANDLE engineHandle,
  const FWPM_PROVIDER0 *provider,
  PSECURITY_DESCRIPTOR sd
);

DWORD WINAPI FwpmProviderContextCreateEnumHandle0(
  HANDLE engineHandle,
  const FWPM_PROVIDER_CONTEXT_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI FwpmProviderContextDeleteById0(
  HANDLE engineHandle,
  UINT64 id
);

DWORD WINAPI FwpmProviderContextDeleteByKey0(
  HANDLE engineHandle,
  const GUID *key
);

DWORD WINAPI FwpmProviderContextDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmProviderContextEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_PROVIDER_CONTEXT0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmProviderContextGetById0(
  HANDLE engineHandle,
  UINT64 id,
  FWPM_PROVIDER_CONTEXT0 **providerContext
);

DWORD WINAPI FwpmProviderContextGetByKey0(
  HANDLE engineHandle,
  const GUID *key,
  FWPM_PROVIDER_CONTEXT0 **providerContext
);

DWORD WINAPI FwpmProviderContextGetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI FwpmProviderContextSetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI FwpmProviderContextSubscriptionsGet0(
  HANDLE engineHandle,
  FWPM_PROVIDER_CONTEXT_SUBSCRIPTION0 ***entries,
  UINT32 *numEntries
);

DWORD WINAPI FwpmProviderContextUnsubscribeChanges0(
  HANDLE engineHandle,
  HANDLE changeHandle
);

DWORD WINAPI FwpmProviderCreateEnumHandle0(
  HANDLE engineHandle,
  const FWPM_PROVIDER_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI FwpmProviderDeleteByKey0(
  HANDLE engineHandle,
  const GUID *key
);

DWORD WINAPI FwpmProviderDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmProviderEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_PROVIDER0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmProviderGetByKey0(
  HANDLE engineHandle,
  const GUID *key,
  FWPM_PROVIDER0 **provider
);

DWORD WINAPI FwpmProviderGetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI FwpmProviderSetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI FwpmProviderSubscriptionsGet0(
  HANDLE engineHandle,
  FWPM_PROVIDER_SUBSCRIPTION0 ***entries,
  UINT32 *numEntries
);

DWORD WINAPI FwpmProviderUnsubscribeChanges0(
  HANDLE engineHandle,
  HANDLE changeHandle
);

DWORD WINAPI FwpmSessionCreateEnumHandle0(
  HANDLE engineHandle,
  const FWPM_SESSION_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI FwpmSessionDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmSessionEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_SESSION0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmSubLayerCreateEnumHandle0(
  HANDLE engineHandle,
  const FWPM_SUBLAYER_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI FwpmSubLayerDeleteByKey0(
  HANDLE engineHandle,
  const GUID *key
);

DWORD WINAPI FwpmSubLayerDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmSubLayerEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_SUBLAYER0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmSubLayerGetByKey0(
  HANDLE engineHandle,
  const GUID *key,
  FWPM_SUBLAYER0 **subLayer
);

DWORD WINAPI FwpmSubLayerGetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI FwpmCalloutSetSecurityInfoByKey0(
  HANDLE engineHandle,
  const GUID *key,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI FwpmSubLayerSubscriptionsGet0(
  HANDLE engineHandle,
  FWPM_SUBLAYER_SUBSCRIPTION0 ***entries,
  UINT32 *numEntries
);

DWORD WINAPI FwpmSubLayerUnsubscribeChanges0(
  HANDLE engineHandle,
  HANDLE changeHandle
);

DWORD WINAPI FwpmTransactionAbort0(
  HANDLE engineHandle
);

DWORD WINAPI FwpmTransactionBegin0(
  HANDLE engineHandle,
  UINT32 flags
);

DWORD WINAPI FwpmTransactionCommit0(
  HANDLE engineHandle
);

DWORD WINAPI IkeextGetStatistics0(
  HANDLE engineHandle,
  IKEEXT_STATISTICS0 *ikeextStatistics
);

DWORD WINAPI IkeextSaDbGetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI IkeextSaCreateEnumHandle0(
  HANDLE engineHandle,
  const IKEEXT_SA_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI IkeextSaDbSetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI IkeextSaDeleteById0(
  HANDLE engineHandle,
  UINT64 id
);

DWORD WINAPI IkeextSaDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI IkeextSaEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  IKEEXT_SA_DETAILS0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI IkeextSaGetById0(
  HANDLE engineHandle,
  UINT64 id,
  IKEEXT_SA_DETAILS0 **sa
);

DWORD WINAPI IPsecGetStatistics0(
  HANDLE engineHandle,
  IPSEC_STATISTICS0 *ipsecStatistics
);

DWORD WINAPI IPsecSaContextAddInbound0(
  HANDLE engineHandle,
  UINT64 id,
  const IPSEC_SA_BUNDLE0 *inboundBundle
);

DWORD WINAPI IPsecSaContextAddOutbound0(
  HANDLE engineHandle,
  UINT64 id,
  const IPSEC_SA_BUNDLE0 *outboundBundle
);

DWORD WINAPI IPsecSaContextCreate0(
  HANDLE engineHandle,
  const IPSEC_TRAFFIC0 *outboundTraffic,
  UINT64 *inboundFilterId,
  UINT64 *id
);

DWORD WINAPI IPsecSaContextCreateEnumHandle0(
  HANDLE engineHandle,
  const IPSEC_SA_CONTEXT_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI IPsecSaContextDeleteById0(
  HANDLE engineHandle,
  UINT64 id
);

DWORD WINAPI IPsecSaContextDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI FwpmEngineSetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI IPsecSaContextEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  IPSEC_SA_CONTEXT0 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI IPsecSaContextExpire0(
  HANDLE engineHandle,
  UINT64 id
);

DWORD WINAPI IPsecSaContextGetById0(
  HANDLE engineHandle,
  UINT64 id,
  IPSEC_SA_CONTEXT0 **saContext
);

DWORD WINAPI IPsecSaContextGetSpi0(
  HANDLE engineHandle,
  UINT64 id,
  const IPSEC_GETSPI0 *getSpi,
  IPSEC_SA_SPI *inboundSpi
);

DWORD WINAPI IPsecSaCreateEnumHandle0(
  HANDLE engineHandle,
  const IPSEC_SA_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI IPsecSaDbGetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI IPsecSaDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI IPsecSaEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  IPSEC_SA_DETAILS0 ***entries,
  UINT32 *numEntriesReturned
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

#if (_WIN32_WINNT >= 0x0601)

DEFINE_GUID(FWPM_PROVIDER_IPSEC_DOS_CONFIG,0x3C6C0519,0xC05C,0x4BB9,0x83,0x38,0x23,0x27,0x81,0x4C,0xE8,0xBF);

typedef void ( CALLBACK *FWPM_NET_EVENT_CALLBACK0 )(
  void *context,
  const FWPM_NET_EVENT1 *event
);

typedef void ( CALLBACK *FWPM_SYSTEM_PORTS_CALLBACK0 )(
  void *context,
  const FWPM_SYSTEM_PORTS0 *sysPorts
);

DWORD WINAPI IkeextGetStatistics1(
  HANDLE engineHandle,
  IKEEXT_STATISTICS1 *ikeextStatistics
);

DWORD WINAPI IkeextSaEnum1(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  IKEEXT_SA_DETAILS1 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI IkeextSaGetById1(
  HANDLE engineHandle,
  UINT64 id,
  GUID *saLookupContext,
  IKEEXT_SA_DETAILS1 **sa
);

DWORD WINAPI FwpmIpsecTunnelAdd1(
  HANDLE engineHandle,
  UINT32 flags,
  const FWPM_PROVIDER_CONTEXT1 *mainModePolicy,
  const FWPM_PROVIDER_CONTEXT1 *tunnelPolicy,
  UINT32 numFilterConditions,
  const FWPM_FILTER_CONDITION0 *filterConditions,
  const GUID *keyModKey,
  PSECURITY_DESCRIPTOR sd
);

DWORD WINAPI IPsecDospGetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  PSID *sidOwner,
  PSID *sidGroup,
  PACL *dacl,
  PACL *sacl,
  PSECURITY_DESCRIPTOR *securityDescriptor
);

DWORD WINAPI IPsecDospGetStatistics0(
  HANDLE engineHandle,
  IPSEC_DOSP_STATISTICS0 *idpStatistics
);

DWORD WINAPI IPsecDospSetSecurityInfo0(
  HANDLE engineHandle,
  SECURITY_INFORMATION securityInfo,
  const SID *sidOwner,
  const SID *sidGroup,
  const ACL *dacl,
  const ACL *sacl
);

DWORD WINAPI IPsecDospStateCreateEnumHandle0(
  HANDLE engineHandle,
  const IPSEC_DOSP_STATE_ENUM_TEMPLATE0 *enumTemplate,
  HANDLE *enumHandle
);

DWORD WINAPI IPsecDospStateDestroyEnumHandle0(
  HANDLE engineHandle,
  HANDLE enumHandle
);

DWORD WINAPI IPsecDospStateEnum0(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  IPSEC_DOSP_STATE0 ***entries,
  UINT32 *numEntries
);

DWORD WINAPI IPsecGetStatistics1(
  HANDLE engineHandle,
  IPSEC_STATISTICS1 *ipsecStatistics
);

DWORD WINAPI IPsecSaContextAddInbound1(
  HANDLE engineHandle,
  UINT64 id,
  const IPSEC_SA_BUNDLE1 *inboundBundle
);

DWORD WINAPI IPsecSaContextAddOutbound1(
  HANDLE engineHandle,
  UINT64 id,
  const IPSEC_SA_BUNDLE1 *outboundBundle
);

DWORD WINAPI IPsecSaContextCreate1(
  HANDLE engineHandle,
  const IPSEC_TRAFFIC1 *outboundTraffic,
  const IPSEC_VIRTUAL_IF_TUNNEL_INFO0 *virtualIfTunnelInfo,
  UINT64 *inboundFilterId,
  UINT64 *id
);

DWORD WINAPI FwpmNetEventEnum1(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_NET_EVENT1 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmNetEventSubscribe0(
  HANDLE engineHandle,
  const FWPM_NET_EVENT_SUBSCRIPTION0 *subscription,
  FWPM_NET_EVENT_CALLBACK0 callback,
  void *context,
  HANDLE *eventsHandle
);

DWORD WINAPI FwpmNetEventSubscriptionsGet0(
  HANDLE engineHandle,
  FWPM_NET_EVENT_SUBSCRIPTION0 ***entries,
  UINT32 *numEntries
);

DWORD WINAPI FwpmNetEventUnsubscribe0(
  HANDLE engineHandle,
  HANDLE eventsHandle
);

DWORD WINAPI FwpmProviderContextAdd1(
  HANDLE engineHandle,
  const FWPM_PROVIDER_CONTEXT1 *providerContext,
  PSECURITY_DESCRIPTOR sd,
  UINT64 *id
);

DWORD WINAPI FwpmProviderContextEnum1(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  FWPM_PROVIDER_CONTEXT1 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI FwpmProviderContextGetById1(
  HANDLE engineHandle,
  UINT64 id,
  FWPM_PROVIDER_CONTEXT1 **providerContext
);

DWORD WINAPI FwpmProviderContextGetByKey1(
  HANDLE engineHandle,
  const GUID *key,
  FWPM_PROVIDER_CONTEXT1 **providerContext
);

DWORD WINAPI FwpmSystemPortsGet0(
  HANDLE engineHandle,
  FWPM_SYSTEM_PORTS0 **sysPorts
);

DWORD WINAPI FwpmSystemPortsSubscribe0(
  HANDLE engineHandle,
  void *reserved,
  FWPM_SYSTEM_PORTS_CALLBACK0 callback,
  void *context,
  HANDLE *sysPortsHandle
);

DWORD WINAPI FwpmSystemPortsUnsubscribe0(
  HANDLE engineHandle,
  HANDLE sysPortsHandle
);

DWORD WINAPI IPsecSaContextEnum1(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  IPSEC_SA_CONTEXT1 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI IPsecSaContextGetById1(
  HANDLE engineHandle,
  UINT64 id,
  IPSEC_SA_CONTEXT1 **saContext
);

DWORD WINAPI IPsecSaContextGetSpi1(
  HANDLE engineHandle,
  UINT64 id,
  const IPSEC_GETSPI1 *getSpi,
  IPSEC_SA_SPI *inboundSpi
);

DWORD WINAPI IPsecSaContextUpdate0(
  HANDLE engineHandle,
  UINT32 flags,
  const IPSEC_SA_CONTEXT1 *newValues
);

DWORD WINAPI IPsecSaEnum1(
  HANDLE engineHandle,
  HANDLE enumHandle,
  UINT32 numEntriesRequested,
  IPSEC_SA_DETAILS1 ***entries,
  UINT32 *numEntriesReturned
);

DWORD WINAPI IPsecSaContextSetSpi0(
  HANDLE engineHandle,
  UINT64 id,
  const IPSEC_GETSPI1 *getSpi,
  IPSEC_SA_SPI inboundSpi
);

#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif
#endif /*_INC_FWPMU*/
