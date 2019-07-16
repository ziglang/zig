/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _P2P_H_
#define _P2P_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#ifndef __WIDL__
#include <winsock2.h>
#include <pnrpns.h>
#include <ws2tcpip.h>
#include <specstrings.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if NTDDI_VERSION < 0x06000000
#ifndef NO_P2P_PNRP
#define NO_P2P_PNRP
#endif

#ifndef NO_P2P_COLLABORATION
#define NO_P2P_COLLABORATION
#endif
#endif

  typedef enum peer_record_change_type_tag {
    PEER_RECORD_ADDED = 1,
    PEER_RECORD_UPDATED = 2,
    PEER_RECORD_DELETED = 3,
    PEER_RECORD_EXPIRED = 4,
  } PEER_RECORD_CHANGE_TYPE;

  typedef enum peer_connection_status_tag {
    PEER_CONNECTED = 1,
    PEER_DISCONNECTED = 2,
    PEER_CONNECTION_FAILED = 3,
  } PEER_CONNECTION_STATUS;

  typedef enum peer_connection_flags_tag {
    PEER_CONNECTION_NEIGHBOR = 0x0001,
    PEER_CONNECTION_DIRECT = 0x0002,
  } PEER_CONNECTION_FLAGS;

  typedef enum peer_record_flags_tag {
    PEER_RECORD_FLAG_AUTOREFRESH = 0x0001,
    PEER_RECORD_FLAG_DELETED = 0x0002,
  } PEER_RECORD_FLAGS;

  typedef
#ifdef __WIDL__
  [context_handle]
#endif
  void *HPEEREVENT;
  typedef HPEEREVENT *PHPEEREVENT;
  typedef
#ifdef __WIDL__
  [context_handle]
#endif
  void *HPEERENUM;
  typedef HPEERENUM *PHPEERENUM;
  typedef struct peer_version_data_tag {
    WORD wVersion;
    WORD wHighestVersion;
  } PEER_VERSION_DATA,*PPEER_VERSION_DATA;

  typedef struct peer_data_tag {
    ULONG cbData;
#ifdef __WIDL__
    [size_is (cbData)]
#endif
    PBYTE pbData;
  } PEER_DATA,*PPEER_DATA;

  typedef const PEER_DATA *PCPEER_DATA;

  typedef struct peer_record_tag {
    DWORD dwSize;
    GUID type;
    GUID id;
    DWORD dwVersion;
    DWORD dwFlags;
    PWSTR pwzCreatorId;
    PWSTR pwzModifiedById;
    PWSTR pwzAttributes;
    FILETIME ftCreation;
    FILETIME ftExpiration;
    FILETIME ftLastModified;
    PEER_DATA securityData;
    PEER_DATA data;
  } PEER_RECORD,*PPEER_RECORD;
  typedef struct peer_address_tag {
    DWORD dwSize;
    SOCKADDR_IN6 sin6;
  } PEER_ADDRESS,*PPEER_ADDRESS;

  typedef const PEER_ADDRESS *PCPEER_ADDRESS;

  typedef struct peer_connection_info_tag {
    DWORD dwSize;
    DWORD dwFlags;
    ULONGLONG ullConnectionId;
    ULONGLONG ullNodeId;
    PWSTR pwzPeerId;
    PEER_ADDRESS address;
  } PEER_CONNECTION_INFO;

  typedef struct peer_event_incoming_data_tag {
    DWORD dwSize;
    ULONGLONG ullConnectionId;
    GUID type;
    PEER_DATA data;
  } PEER_EVENT_INCOMING_DATA,*PPEER_EVENT_INCOMING_DATA;

  typedef struct peer_event_record_change_data_tag {
    DWORD dwSize;
    PEER_RECORD_CHANGE_TYPE changeType;
    GUID recordId;
    GUID recordType;
  } PEER_EVENT_RECORD_CHANGE_DATA,*PPEER_EVENT_RECORD_CHANGE_DATA;

  typedef struct peer_event_connection_change_data_tag {
    DWORD dwSize;
    PEER_CONNECTION_STATUS status;
    ULONGLONG ullConnectionId;
    ULONGLONG ullNodeId;
#if NTDDI_VERSION >= 0x06000000
    ULONGLONG ullNextConnectionId;
    HRESULT hrConnectionFailedReason;
#endif
  } PEER_EVENT_CONNECTION_CHANGE_DATA,*PPEER_EVENT_CONNECTION_CHANGE_DATA;

  typedef struct peer_event_synchronized_data_tag {
    DWORD dwSize;
    GUID recordType;
  } PEER_EVENT_SYNCHRONIZED_DATA,*PPEER_EVENT_SYNCHRONIZED_DATA;

#if !defined (NO_P2P_GRAPH) && !defined (__WIDL__)
#define PEER_GRAPH_VERSION MAKEWORD (1, 0)

  typedef PVOID HGRAPH,*PHGRAPH;

  typedef enum peer_graph_event_type_tag {
    PEER_GRAPH_EVENT_STATUS_CHANGED = 1,
    PEER_GRAPH_EVENT_PROPERTY_CHANGED = 2,
    PEER_GRAPH_EVENT_RECORD_CHANGED = 3,
    PEER_GRAPH_EVENT_DIRECT_CONNECTION = 4,
    PEER_GRAPH_EVENT_NEIGHBOR_CONNECTION = 5,
    PEER_GRAPH_EVENT_INCOMING_DATA = 6,
    PEER_GRAPH_EVENT_CONNECTION_REQUIRED = 7,
    PEER_GRAPH_EVENT_NODE_CHANGED = 8,
    PEER_GRAPH_EVENT_SYNCHRONIZED = 9,
  } PEER_GRAPH_EVENT_TYPE;

  typedef enum peer_node_change_type_tag {
    PEER_NODE_CHANGE_CONNECTED = 1,
    PEER_NODE_CHANGE_DISCONNECTED = 2,
    PEER_NODE_CHANGE_UPDATED = 3,
  } PEER_NODE_CHANGE_TYPE;

  typedef enum peer_graph_status_flags_tag {
    PEER_GRAPH_STATUS_LISTENING = 0x0001,
    PEER_GRAPH_STATUS_HAS_CONNECTIONS = 0x0002,
    PEER_GRAPH_STATUS_SYNCHRONIZED = 0x0004,
  } PEER_GRAPH_STATUS_FLAGS;

  typedef enum peer_graph_property_flags_tag {
    PEER_GRAPH_PROPERTY_HEARTBEATS = 0x0001,
    PEER_GRAPH_PROPERTY_DEFER_EXPIRATION = 0x0002,
  } PEER_GRAPH_PROPERTY_FLAGS;

  typedef enum peer_graph_scope_tag {
    PEER_GRAPH_SCOPE_ANY = 0,
    PEER_GRAPH_SCOPE_GLOBAL = 1,
    PEER_GRAPH_SCOPE_SITELOCAL = 2,
    PEER_GRAPH_SCOPE_LINKLOCAL = 3,
    PEER_GRAPH_SCOPE_LOOPBACK = 4
  } PEER_GRAPH_SCOPE;

  typedef struct peer_graph_properties_tag {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwScope;
    DWORD dwMaxRecordSize;
    PWSTR pwzGraphId;
    PWSTR pwzCreatorId;
    PWSTR pwzFriendlyName;
    PWSTR pwzComment;
    ULONG ulPresenceLifetime;
    ULONG cPresenceMax;
  } PEER_GRAPH_PROPERTIES,*PPEER_GRAPH_PROPERTIES;

  typedef struct peer_node_info_tag {
    DWORD dwSize;
    ULONGLONG ullNodeId;
    PWSTR pwzPeerId;
    ULONG cAddresses;
    PPEER_ADDRESS pAddresses;
    PWSTR pwzAttributes;
  } PEER_NODE_INFO,*PPEER_NODE_INFO;

  typedef struct peer_event_node_change_data_tag {
    DWORD dwSize;
    PEER_NODE_CHANGE_TYPE changeType;
    ULONGLONG ullNodeId;
    PWSTR pwzPeerId;
  } PEER_EVENT_NODE_CHANGE_DATA,*PPEER_EVENT_NODE_CHANGE_DATA;

  typedef struct peer_graph_event_registration_tag {
    PEER_GRAPH_EVENT_TYPE eventType;
    GUID *pType;
  } PEER_GRAPH_EVENT_REGISTRATION,*PPEER_GRAPH_EVENT_REGISTRATION;

  typedef struct peer_graph_event_data_tag {
    PEER_GRAPH_EVENT_TYPE eventType;
    __C89_NAMELESS union {
      PEER_GRAPH_STATUS_FLAGS dwStatus;
      PEER_EVENT_INCOMING_DATA incomingData;
      PEER_EVENT_RECORD_CHANGE_DATA recordChangeData;
      PEER_EVENT_CONNECTION_CHANGE_DATA connectionChangeData;
      PEER_EVENT_NODE_CHANGE_DATA nodeChangeData;
      PEER_EVENT_SYNCHRONIZED_DATA synchronizedData;
    };
  } PEER_GRAPH_EVENT_DATA,*PPEER_GRAPH_EVENT_DATA;

  typedef HRESULT (CALLBACK *PFNPEER_VALIDATE_RECORD) (HGRAPH hGraph, PVOID pvContext, PPEER_RECORD pRecord, PEER_RECORD_CHANGE_TYPE changeType);
  typedef HRESULT (CALLBACK *PFNPEER_SECURE_RECORD) (HGRAPH hGraph, PVOID pvContext, PPEER_RECORD pRecord, PEER_RECORD_CHANGE_TYPE changeType, PPEER_DATA *ppSecurityData);
  typedef HRESULT (CALLBACK *PFNPEER_FREE_SECURITY_DATA) (HGRAPH hGraph, PVOID pvContext, PPEER_DATA pSecurityData);
  typedef HRESULT (CALLBACK *PFNPEER_ON_PASSWORD_AUTH_FAILED) (HGRAPH hGraph, PVOID pvContext);

  typedef struct peer_security_interface_tag {
    DWORD dwSize;
    PWSTR pwzSspFilename;
    PWSTR pwzPackageName;
    ULONG cbSecurityInfo;
    PBYTE pbSecurityInfo;
    PVOID pvContext;
    PFNPEER_VALIDATE_RECORD pfnValidateRecord;
    PFNPEER_SECURE_RECORD pfnSecureRecord;
    PFNPEER_FREE_SECURITY_DATA pfnFreeSecurityData;
    PFNPEER_ON_PASSWORD_AUTH_FAILED pfnAuthFailed;
  } PEER_SECURITY_INTERFACE,*PPEER_SECURITY_INTERFACE;

  HRESULT WINAPI PeerGraphStartup (WORD wVersionRequested, PPEER_VERSION_DATA pVersionData);
  HRESULT WINAPI PeerGraphShutdown ();
  VOID WINAPI PeerGraphFreeData (PVOID pvData);
  HRESULT WINAPI PeerGraphGetItemCount (HPEERENUM hPeerEnum, ULONG *pCount);
  HRESULT WINAPI PeerGraphGetNextItem (HPEERENUM hPeerEnum, ULONG *pCount, PVOID **pppvItems);
  HRESULT WINAPI PeerGraphEndEnumeration (HPEERENUM hPeerEnum);
  HRESULT WINAPI PeerGraphCreate (PPEER_GRAPH_PROPERTIES pGraphProperties, PCWSTR pwzDatabaseName, PPEER_SECURITY_INTERFACE pSecurityInterface, HGRAPH *phGraph);
  HRESULT WINAPI PeerGraphOpen (PCWSTR pwzGraphId, PCWSTR pwzPeerId, PCWSTR pwzDatabaseName, PPEER_SECURITY_INTERFACE pSecurityInterface, ULONG cRecordTypeSyncPrecedence, const GUID *pRecordTypeSyncPrecedence, HGRAPH *phGraph);
  HRESULT WINAPI PeerGraphListen (HGRAPH hGraph, DWORD dwScope, DWORD dwScopeId, WORD wPort);
  HRESULT WINAPI PeerGraphConnect (HGRAPH hGraph, PCWSTR pwzPeerId, PPEER_ADDRESS pAddress, ULONGLONG *pullConnectionId);
  HRESULT WINAPI PeerGraphClose (HGRAPH hGraph);
  HRESULT WINAPI PeerGraphDelete (PCWSTR pwzGraphId, PCWSTR pwzPeerId, PCWSTR pwzDatabaseName);
  HRESULT WINAPI PeerGraphGetStatus (HGRAPH hGraph, DWORD *pdwStatus);
  HRESULT WINAPI PeerGraphGetProperties (HGRAPH hGraph, PPEER_GRAPH_PROPERTIES *ppGraphProperties);
  HRESULT WINAPI PeerGraphSetProperties (HGRAPH hGraph, PPEER_GRAPH_PROPERTIES pGraphProperties);
  HRESULT WINAPI PeerGraphRegisterEvent (HGRAPH hGraph, HANDLE hEvent, ULONG cEventRegistrations, PEER_GRAPH_EVENT_REGISTRATION *pEventRegistrations, HPEEREVENT *phPeerEvent);
  HRESULT WINAPI PeerGraphUnregisterEvent (HPEEREVENT hPeerEvent);
  HRESULT WINAPI PeerGraphGetEventData (HPEEREVENT hPeerEvent, PPEER_GRAPH_EVENT_DATA *ppEventData);
  HRESULT WINAPI PeerGraphGetRecord (HGRAPH hGraph, const GUID *pRecordId, PPEER_RECORD *ppRecord);
  HRESULT WINAPI PeerGraphAddRecord (HGRAPH hGraph, PPEER_RECORD pRecord, GUID *pRecordId);
  HRESULT WINAPI PeerGraphUpdateRecord (HGRAPH hGraph, PPEER_RECORD pRecord);
  HRESULT WINAPI PeerGraphDeleteRecord (HGRAPH hGraph, const GUID *pRecordId, WINBOOL fLocal);
  HRESULT WINAPI PeerGraphEnumRecords (HGRAPH hGraph, const GUID *pRecordType, PCWSTR pwzPeerId, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerGraphSearchRecords (HGRAPH hGraph, PCWSTR pwzCriteria, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerGraphExportDatabase (HGRAPH hGraph, PCWSTR pwzFilePath);
  HRESULT WINAPI PeerGraphImportDatabase (HGRAPH hGraph, PCWSTR pwzFilePath);
  HRESULT WINAPI PeerGraphValidateDeferredRecords (HGRAPH hGraph, ULONG cRecordIds, const GUID *pRecordIds);
  HRESULT WINAPI PeerGraphOpenDirectConnection (HGRAPH hGraph, PCWSTR pwzPeerId, PPEER_ADDRESS pAddress, ULONGLONG *pullConnectionId);
  HRESULT WINAPI PeerGraphSendData (HGRAPH hGraph, ULONGLONG ullConnectionId, const GUID *pType, ULONG cbData, PVOID pvData);
  HRESULT WINAPI PeerGraphCloseDirectConnection (HGRAPH hGraph, ULONGLONG ullConnectionId);
  HRESULT WINAPI PeerGraphEnumConnections (HGRAPH hGraph, DWORD dwFlags, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerGraphEnumNodes (HGRAPH hGraph, PCWSTR pwzPeerId, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerGraphSetPresence (HGRAPH hGraph, WINBOOL fPresent);
  HRESULT WINAPI PeerGraphGetNodeInfo (HGRAPH hGraph, ULONGLONG ullNodeId, PPEER_NODE_INFO *ppNodeInfo);
  HRESULT WINAPI PeerGraphSetNodeAttributes (HGRAPH hGraph, PCWSTR pwzAttributes);
  HRESULT WINAPI PeerGraphPeerTimeToUniversalTime (HGRAPH hGraph, FILETIME *pftPeerTime, FILETIME *pftUniversalTime);
  HRESULT WINAPI PeerGraphUniversalTimeToPeerTime (HGRAPH hGraph, FILETIME *pftUniversalTime, FILETIME *pftPeerTime);
#endif

#if !(defined (NO_P2P_GROUP) && defined (NO_P2P_IDENTITY)) && !defined (__WIDL__)
#include <wincrypt.h>
  VOID WINAPI PeerFreeData (LPCVOID pvData);
  HRESULT WINAPI PeerGetItemCount (HPEERENUM hPeerEnum, ULONG *pCount);
  HRESULT WINAPI PeerGetNextItem (HPEERENUM hPeerEnum, ULONG *pCount, PVOID **pppvItems);
  HRESULT WINAPI PeerEndEnumeration (HPEERENUM hPeerEnum);
#endif

#ifndef NO_P2P_GROUP
  typedef PVOID HGROUP,*PHGROUP;
  typedef GUID PEER_ROLE_ID;
#if NTDDI_VERSION >= 0x06000000
#define PEER_GROUP_VERSION MAKEWORD (1, 1)
#else
#define PEER_GROUP_VERSION MAKEWORD (1, 0)
#endif

  typedef enum peer_group_event_type_tag {
    PEER_GROUP_EVENT_STATUS_CHANGED = 1,
    PEER_GROUP_EVENT_PROPERTY_CHANGED = 2,
    PEER_GROUP_EVENT_RECORD_CHANGED = 3,
    PEER_GROUP_EVENT_DIRECT_CONNECTION = 4,
    PEER_GROUP_EVENT_NEIGHBOR_CONNECTION = 5,
    PEER_GROUP_EVENT_INCOMING_DATA = 6,
    PEER_GROUP_EVENT_MEMBER_CHANGED = 8,
    PEER_GROUP_EVENT_CONNECTION_FAILED = 10,
    PEER_GROUP_EVENT_AUTHENTICATION_FAILED = 11
  } PEER_GROUP_EVENT_TYPE;

  typedef enum peer_group_status_tag {
    PEER_GROUP_STATUS_LISTENING = 0x0001,
    PEER_GROUP_STATUS_HAS_CONNECTIONS = 0x0002,
  } PEER_GROUP_STATUS;

  typedef enum peer_group_property_flags_tag {
    PEER_MEMBER_DATA_OPTIONAL = 0x0001,
    PEER_DISABLE_PRESENCE = 0x0002,
    PEER_DEFER_EXPIRATION = 0x0004,
  } PEER_GROUP_PROPERTY_FLAGS;

#if NTDDI_VERSION >= 0x06000000
  typedef enum peer_group_authentication_scheme_tag {
    PEER_GROUP_GMC_AUTHENTICATION = 0x00000001,
    PEER_GROUP_PASSWORD_AUTHENTICATION = 0x00000002,
  } PEER_GROUP_AUTHENTICATION_SCHEME;
#endif

  typedef enum peer_member_flags_tag {
    PEER_MEMBER_PRESENT = 0x0001,
  } PEER_MEMBER_FLAGS;

  typedef enum peer_member_change_type_tag {
    PEER_MEMBER_CONNECTED = 1,
    PEER_MEMBER_DISCONNECTED = 2,
    PEER_MEMBER_UPDATED = 3,
    PEER_MEMBER_JOINED = 4,
    PEER_MEMBER_LEFT = 5,
  } PEER_MEMBER_CHANGE_TYPE;

  typedef enum peer_issue_credential_flags_tag {
    PEER_GROUP_STORE_CREDENTIALS = 0x0001,
  } PEER_GROUP_ISSUE_CREDENTIAL_FLAGS;

#ifndef __WIDL__
  typedef struct peer_credential_info_tag {
    DWORD dwSize;
    DWORD dwFlags;
    PWSTR pwzFriendlyName;
    CERT_PUBLIC_KEY_INFO *pPublicKey;
    PWSTR pwzIssuerPeerName;
    PWSTR pwzIssuerFriendlyName;
    FILETIME ftValidityStart;
    FILETIME ftValidityEnd;
    ULONG cRoles;
    PEER_ROLE_ID *pRoles;
  } PEER_CREDENTIAL_INFO,*PPEER_CREDENTIAL_INFO;

  typedef struct peer_member_tag {
    DWORD dwSize;
    DWORD dwFlags;
    PWSTR pwzIdentity;
    PWSTR pwzAttributes;
    ULONGLONG ullNodeId;
    ULONG cAddresses;
    PEER_ADDRESS *pAddresses;
    PEER_CREDENTIAL_INFO *pCredentialInfo;
  } PEER_MEMBER,*PPEER_MEMBER;

  typedef struct peer_invitation_info_tag {
    DWORD dwSize;
    DWORD dwFlags;
    PWSTR pwzCloudName;
    DWORD dwScope;
    DWORD dwCloudFlags;
    PWSTR pwzGroupPeerName;
    PWSTR pwzIssuerPeerName;
    PWSTR pwzSubjectPeerName;
    PWSTR pwzGroupFriendlyName;
    PWSTR pwzIssuerFriendlyName;
    PWSTR pwzSubjectFriendlyName;
    FILETIME ftValidityStart;
    FILETIME ftValidityEnd;
    ULONG cRoles;
    PEER_ROLE_ID *pRoles;
    ULONG cClassifiers;
    PWSTR *ppwzClassifiers;
    CERT_PUBLIC_KEY_INFO *pSubjectPublicKey;
#if NTDDI_VERSION >= 0x06000000
    PEER_GROUP_AUTHENTICATION_SCHEME authScheme;
#endif
  } PEER_INVITATION_INFO,*PPEER_INVITATION_INFO;
#endif

  typedef struct peer_group_properties_tag {
    DWORD dwSize;
    DWORD dwFlags;
    PWSTR pwzCloud;
    PWSTR pwzClassifier;
    PWSTR pwzGroupPeerName;
    PWSTR pwzCreatorPeerName;
    PWSTR pwzFriendlyName;
    PWSTR pwzComment;
    ULONG ulMemberDataLifetime;
    ULONG ulPresenceLifetime;
#if NTDDI_VERSION >= 0x06000000
    DWORD dwAuthenticationSchemes;
    PWSTR pwzGroupPassword;
    PEER_ROLE_ID groupPasswordRole;
#endif
  } PEER_GROUP_PROPERTIES,*PPEER_GROUP_PROPERTIES;

  typedef struct peer_event_member_change_data_tag {
    DWORD dwSize;
    PEER_MEMBER_CHANGE_TYPE changeType;
    PWSTR pwzIdentity;
  } PEER_EVENT_MEMBER_CHANGE_DATA,*PPEER_EVENT_MEMBER_CHANGE_DATA;

  typedef struct peer_group_event_registration_tag {
    PEER_GROUP_EVENT_TYPE eventType;
    GUID *pType;
  } PEER_GROUP_EVENT_REGISTRATION,*PPEER_GROUP_EVENT_REGISTRATION;

#ifdef __WIDL__
  typedef struct peer_group_event_data_tag {
    PEER_GROUP_EVENT_TYPE eventType;
    [switch_is (eventType)] union {
      [case (PEER_GROUP_EVENT_STATUS_CHANGED)] PEER_GROUP_STATUS dwStatus;
      [case (PEER_GROUP_EVENT_PROPERTY_CHANGED)] ;
      [case (PEER_GROUP_EVENT_RECORD_CHANGED)] PEER_EVENT_RECORD_CHANGE_DATA recordChangeData;
      [case (PEER_GROUP_EVENT_NEIGHBOR_CONNECTION, PEER_GROUP_EVENT_DIRECT_CONNECTION)] PEER_EVENT_CONNECTION_CHANGE_DATA connectionChangeData;
      [case (PEER_GROUP_EVENT_INCOMING_DATA)] PEER_EVENT_INCOMING_DATA incomingData;
      [case (PEER_GROUP_EVENT_MEMBER_CHANGED)] PEER_EVENT_MEMBER_CHANGE_DATA memberChangeData;
      [case (PEER_GROUP_EVENT_CONNECTION_FAILED)] HRESULT hrConnectionFailedReason;
      [default] ;
    };
  } PEER_GROUP_EVENT_DATA,*PPEER_GROUP_EVENT_DATA;
#else
  typedef struct peer_group_event_data_tag {
    PEER_GROUP_EVENT_TYPE eventType;
    __C89_NAMELESS union {
      PEER_GROUP_STATUS dwStatus;
      PEER_EVENT_INCOMING_DATA incomingData;
      PEER_EVENT_RECORD_CHANGE_DATA recordChangeData;
      PEER_EVENT_CONNECTION_CHANGE_DATA connectionChangeData;
      PEER_EVENT_MEMBER_CHANGE_DATA memberChangeData;
      HRESULT hrConnectionFailedReason;
    };
  } PEER_GROUP_EVENT_DATA,*PPEER_GROUP_EVENT_DATA;
#endif

  typedef struct peer_name_pair_tag {
    DWORD dwSize;
    PWSTR pwzPeerName;
    PWSTR pwzFriendlyName;
  } PEER_NAME_PAIR,*PPEER_NAME_PAIR;

#ifndef __WIDL__
  HRESULT WINAPI PeerGroupStartup (WORD wVersionRequested, PPEER_VERSION_DATA pVersionData);
  HRESULT WINAPI PeerGroupShutdown ();
  HRESULT WINAPI PeerGroupCreate (PPEER_GROUP_PROPERTIES pProperties, HGROUP *phGroup);
  HRESULT WINAPI PeerGroupOpen (PCWSTR pwzIdentity, PCWSTR pwzGroupPeerName, PCWSTR pwzCloud, HGROUP *phGroup);
  HRESULT WINAPI PeerGroupJoin (PCWSTR pwzIdentity, PCWSTR pwzInvitation, PCWSTR pwzCloud, HGROUP *phGroup);
  HRESULT WINAPI PeerGroupConnect (HGROUP hGroup);
  HRESULT WINAPI PeerGroupClose (HGROUP hGroup);
  HRESULT WINAPI PeerGroupDelete (PCWSTR pwzIdentity, PCWSTR pwzGroupPeerName);
  HRESULT WINAPI PeerGroupCreateInvitation (HGROUP hGroup, PCWSTR pwzIdentityInfo, FILETIME *pftExpiration, ULONG cRoles, const GUID *pRoles, PWSTR *ppwzInvitation);
  HRESULT WINAPI PeerGroupParseInvitation (PCWSTR pwzInvitation, PPEER_INVITATION_INFO *ppInvitationInfo);
  HRESULT WINAPI PeerGroupGetStatus (HGROUP hGroup, DWORD *pdwStatus);
  HRESULT WINAPI PeerGroupGetProperties (HGROUP hGroup, PPEER_GROUP_PROPERTIES *ppProperties);
  HRESULT WINAPI PeerGroupSetProperties (HGROUP hGroup, PPEER_GROUP_PROPERTIES pProperties);
  HRESULT WINAPI PeerGroupEnumMembers (HGROUP hGroup, DWORD dwFlags, PCWSTR pwzIdentity, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerGroupOpenDirectConnection (HGROUP hGroup, PCWSTR pwzIdentity, PPEER_ADDRESS pAddress, ULONGLONG *pullConnectionId);
  HRESULT WINAPI PeerGroupCloseDirectConnection (HGROUP hGroup, ULONGLONG ullConnectionId);
  HRESULT WINAPI PeerGroupEnumConnections (HGROUP hGroup, DWORD dwFlags, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerGroupSendData (HGROUP hGroup, ULONGLONG ullConnectionId, const GUID *pType, ULONG cbData, PVOID pvData);
  HRESULT WINAPI PeerGroupRegisterEvent (HGROUP hGroup, HANDLE hEvent, DWORD cEventRegistration, PEER_GROUP_EVENT_REGISTRATION *pEventRegistrations, HPEEREVENT *phPeerEvent);
  HRESULT WINAPI PeerGroupUnregisterEvent (HPEEREVENT hPeerEvent);
  HRESULT WINAPI PeerGroupGetEventData (HPEEREVENT hPeerEvent, PPEER_GROUP_EVENT_DATA *ppEventData);
  HRESULT WINAPI PeerGroupGetRecord (HGROUP hGroup, const GUID *pRecordId, PPEER_RECORD *ppRecord);
  HRESULT WINAPI PeerGroupAddRecord (HGROUP hGroup, PPEER_RECORD pRecord, GUID *pRecordId);
  HRESULT WINAPI PeerGroupUpdateRecord (HGROUP hGroup, PPEER_RECORD pRecord);
  HRESULT WINAPI PeerGroupDeleteRecord (HGROUP hGroup, const GUID *pRecordId);
  HRESULT WINAPI PeerGroupEnumRecords (HGROUP hGroup, const GUID *pRecordType, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerGroupSearchRecords (HGROUP hGroup, PCWSTR pwzCriteria, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerGroupExportDatabase (HGROUP hGroup, PCWSTR pwzFilePath);
  HRESULT WINAPI PeerGroupImportDatabase (HGROUP hGroup, PCWSTR pwzFilePath);
  HRESULT WINAPI PeerGroupIssueCredentials (HGROUP hGroup, PCWSTR pwzSubjectIdentity, PEER_CREDENTIAL_INFO *pCredentialInfo, DWORD dwFlags, PWSTR *ppwzInvitation);
  HRESULT WINAPI PeerGroupExportConfig (HGROUP hGroup, PCWSTR pwzPassword, PWSTR *ppwzXML);
  HRESULT WINAPI PeerGroupImportConfig (PCWSTR pwzXML, PCWSTR pwzPassword, WINBOOL fOverwrite, PWSTR *ppwzIdentity, PWSTR *ppwzGroup);
  HRESULT WINAPI PeerGroupPeerTimeToUniversalTime (HGROUP hGroup, FILETIME *pftPeerTime, FILETIME *pftUniversalTime);
  HRESULT WINAPI PeerGroupUniversalTimeToPeerTime (HGROUP hGroup, FILETIME *pftUniversalTime, FILETIME *pftPeerTime);
#if NTDDI_VERSION >= 0x06000000
  HRESULT WINAPI PeerGroupPasswordJoin (PCWSTR pwzIdentity, PCWSTR pwzInvitation, PCWSTR pwzPassword, PCWSTR pwzCloud, HGROUP *phGroup);
  HRESULT WINAPI PeerGroupConnectByAddress (HGROUP hGroup, ULONG cAddresses, PPEER_ADDRESS pAddresses);
  HRESULT WINAPI PeerGroupCreatePasswordInvitation (HGROUP hGroup, PWSTR *ppwzInvitation);
#endif
#if NTDDI_VERSION >= 0x06010000
  HRESULT WINAPI PeerGroupResumePasswordAuthentication (HGROUP hGroup, HPEEREVENT hPeerEventHandle);
#endif
#endif
#endif

#if !defined (NO_P2P_IDENTITY) && !defined (__WIDL__)
  HRESULT WINAPI PeerIdentityCreate (PCWSTR pwzClassifier, PCWSTR pwzFriendlyName, HCRYPTPROV hCryptProv, PWSTR *ppwzIdentity);
  HRESULT WINAPI PeerIdentityGetFriendlyName (PCWSTR pwzIdentity, PWSTR *ppwzFriendlyName);
  HRESULT WINAPI PeerIdentitySetFriendlyName (PCWSTR pwzIdentity, PCWSTR pwzFriendlyName);
  HRESULT WINAPI PeerIdentityGetCryptKey (PCWSTR pwzIdentity, HCRYPTPROV *phCryptProv);
  HRESULT WINAPI PeerIdentityDelete (PCWSTR pwzIdentity);
  HRESULT WINAPI PeerEnumIdentities (HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerEnumGroups (PCWSTR pwzIdentity, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerCreatePeerName (PCWSTR pwzIdentity, PCWSTR pwzClassifier, PWSTR *ppwzPeerName);
  HRESULT WINAPI PeerIdentityGetXML (PCWSTR pwzIdentity, PWSTR *ppwzIdentityXML);
  HRESULT WINAPI PeerIdentityExport (PCWSTR pwzIdentity, PCWSTR pwzPassword, PWSTR *ppwzExportXML);
  HRESULT WINAPI PeerIdentityImport (PCWSTR pwzImportXML, PCWSTR pwzPassword, PWSTR *ppwzIdentity);
  HRESULT WINAPI PeerIdentityGetDefault (PWSTR *ppwzPeerName);
#endif

#ifndef NO_P2P_COLLABORATION
#define PEER_COLLAB_VERSION MAKEWORD (1, 0)

  typedef enum peer_signin_flags_tag {
    PEER_SIGNIN_NONE = 0x0,
    PEER_SIGNIN_NEAR_ME = 0x1,
    PEER_SIGNIN_INTERNET = 0x2,
    PEER_SIGNIN_ALL = PEER_SIGNIN_INTERNET | PEER_SIGNIN_NEAR_ME
  } PEER_SIGNIN_FLAGS;

  typedef enum peer_watch_permission_tag {
    PEER_WATCH_BLOCKED = 0,
    PEER_WATCH_ALLOWED = 1
  } PEER_WATCH_PERMISSION;

  typedef enum peer_publication_scope_tag {
    PEER_PUBLICATION_SCOPE_NONE = 0x0,
    PEER_PUBLICATION_SCOPE_NEAR_ME = 0x1,
    PEER_PUBLICATION_SCOPE_INTERNET = 0x2,
    PEER_PUBLICATION_SCOPE_ALL = PEER_PUBLICATION_SCOPE_NEAR_ME | PEER_PUBLICATION_SCOPE_INTERNET
  } PEER_PUBLICATION_SCOPE;

  typedef struct peer_application_tag {
    GUID id;
    PEER_DATA data;
    PWSTR pwzDescription;
  } PEER_APPLICATION,*PPEER_APPLICATION;

  typedef const PEER_APPLICATION *PCPEER_APPLICATION;

  typedef struct peer_object_tag {
    GUID id;
    PEER_DATA data;
    DWORD dwPublicationScope;
  } PEER_OBJECT,*PPEER_OBJECT;

  typedef const PEER_OBJECT *PCPEER_OBJECT;

  typedef struct peer_contact_tag {
    PWSTR pwzPeerName;
    PWSTR pwzNickName;
    PWSTR pwzDisplayName;
    PWSTR pwzEmailAddress;
    WINBOOL fWatch;
    PEER_WATCH_PERMISSION WatcherPermissions;
    PEER_DATA credentials;
  } PEER_CONTACT,*PPEER_CONTACT;

  typedef const PEER_CONTACT *PCPEER_CONTACT;

  typedef struct peer_endpoint_tag {
    PEER_ADDRESS address;
    PWSTR pwzEndpointName;
  } PEER_ENDPOINT,*PPEER_ENDPOINT;

  typedef const PEER_ENDPOINT *PCPEER_ENDPOINT;

  typedef struct peer_people_near_me_tag {
    PWSTR pwzNickName;
    PEER_ENDPOINT endpoint;
    GUID id;
  } PEER_PEOPLE_NEAR_ME,*PPEER_PEOPLE_NEAR_ME;

  typedef const PEER_PEOPLE_NEAR_ME *PCPEER_PEOPLE_NEAR_ME;

  typedef PPEER_PEOPLE_NEAR_ME *PPPEER_PEOPLE_NEAR_ME;

#ifndef __WIDL__
  HRESULT WINAPI PeerCollabStartup (WORD wVersionRequested);
  HRESULT WINAPI PeerCollabShutdown ();
  HRESULT WINAPI PeerCollabSignin (HWND hwndParent, DWORD dwSigninOptions);
  HRESULT WINAPI PeerCollabSignout (DWORD dwSigninOptions);
  HRESULT WINAPI PeerCollabGetSigninOptions (DWORD *pdwSigninOptions);
#endif

  typedef enum peer_invitation_response_type_tag {
    PEER_INVITATION_RESPONSE_DECLINED = 0,
    PEER_INVITATION_RESPONSE_ACCEPTED = 1,
    PEER_INVITATION_RESPONSE_EXPIRED = 2,
    PEER_INVITATION_RESPONSE_ERROR = 3
  } PEER_INVITATION_RESPONSE_TYPE;

  typedef enum peer_application_registration_type_tag {
    PEER_APPLICATION_CURRENT_USER = 0,
    PEER_APPLICATION_ALL_USERS = 1
  } PEER_APPLICATION_REGISTRATION_TYPE;

  typedef struct peer_invitation_tag {
    GUID applicationId;
    PEER_DATA applicationData;
    PWSTR pwzMessage;
  } PEER_INVITATION,*PPEER_INVITATION;

  typedef const PEER_INVITATION *PCPEER_INVITATION;

  typedef struct peer_invitation_response_tag {
    PEER_INVITATION_RESPONSE_TYPE action;
    PWSTR pwzMessage;
    HRESULT hrExtendedInfo;
  } PEER_INVITATION_RESPONSE,*PPEER_INVITATION_RESPONSE;

  typedef const PEER_INVITATION_RESPONSE *PCPEER_INVITATION_RESPONSE;

  typedef struct peer_app_launch_info_tag {
    PPEER_CONTACT pContact;
    PPEER_ENDPOINT pEndpoint;
    PPEER_INVITATION pInvitation;
  } PEER_APP_LAUNCH_INFO,*PPEER_APP_LAUNCH_INFO;

  typedef const PEER_APP_LAUNCH_INFO *PCPEER_APP_LAUNCH_INFO;

  typedef struct peer_application_registration_info_tag {
    PEER_APPLICATION application;
    PWSTR pwzApplicationToLaunch;
    PWSTR pwzApplicationArguments;
    DWORD dwPublicationScope;
  } PEER_APPLICATION_REGISTRATION_INFO,*PPEER_APPLICATION_REGISTRATION_INFO;

  typedef const PEER_APPLICATION_REGISTRATION_INFO *PCPEER_APPLICATION_REGISTRATION_INFO;

#ifndef __WIDL__
  HRESULT WINAPI PeerCollabAsyncInviteContact (PCPEER_CONTACT pcContact, PCPEER_ENDPOINT pcEndpoint, PCPEER_INVITATION pcInvitation, HANDLE hEvent, HANDLE *phInvitation);
  HRESULT WINAPI PeerCollabGetInvitationResponse (HANDLE hInvitation, PPEER_INVITATION_RESPONSE *ppInvitationResponse);
  HRESULT WINAPI PeerCollabCancelInvitation (HANDLE hInvitation);
  HRESULT WINAPI PeerCollabCloseHandle (HANDLE hInvitation);
  HRESULT WINAPI PeerCollabInviteContact (PCPEER_CONTACT pcContact, PCPEER_ENDPOINT pcEndpoint, PCPEER_INVITATION pcInvitation, PPEER_INVITATION_RESPONSE *ppResponse);
  HRESULT WINAPI PeerCollabAsyncInviteEndpoint (PCPEER_ENDPOINT pcEndpoint, PCPEER_INVITATION pcInvitation, HANDLE hEvent, HANDLE *phInvitation);
  HRESULT WINAPI PeerCollabInviteEndpoint (PCPEER_ENDPOINT pcEndpoint, PCPEER_INVITATION pcInvitation, PPEER_INVITATION_RESPONSE *ppResponse);
  HRESULT WINAPI PeerCollabGetAppLaunchInfo (PPEER_APP_LAUNCH_INFO *ppLaunchInfo);
  HRESULT WINAPI PeerCollabRegisterApplication (PCPEER_APPLICATION_REGISTRATION_INFO pcApplication, PEER_APPLICATION_REGISTRATION_TYPE registrationType);
  HRESULT WINAPI PeerCollabUnregisterApplication (const GUID *pApplicationId, PEER_APPLICATION_REGISTRATION_TYPE registrationType);
  HRESULT WINAPI PeerCollabGetApplicationRegistrationInfo (const GUID *pApplicationId, PEER_APPLICATION_REGISTRATION_TYPE registrationType, PPEER_APPLICATION_REGISTRATION_INFO *ppApplication);
  HRESULT WINAPI PeerCollabEnumApplicationRegistrationInfo (PEER_APPLICATION_REGISTRATION_TYPE registrationType, HPEERENUM *phPeerEnum);
#endif

  typedef enum peer_presence_status_tag {
    PEER_PRESENCE_OFFLINE = 0,
    PEER_PRESENCE_OUT_TO_LUNCH = 1,
    PEER_PRESENCE_AWAY = 2,
    PEER_PRESENCE_BE_RIGHT_BACK = 3,
    PEER_PRESENCE_IDLE = 4,
    PEER_PRESENCE_BUSY = 5,
    PEER_PRESENCE_ON_THE_PHONE = 6,
    PEER_PRESENCE_ONLINE = 7
  } PEER_PRESENCE_STATUS;

  typedef struct peer_presence_info_tag {
    PEER_PRESENCE_STATUS status;
    PWSTR pwzDescriptiveText;
  } PEER_PRESENCE_INFO,*PPEER_PRESENCE_INFO;

  typedef const PEER_PRESENCE_INFO *PCPEER_PRESENCE_INFO;

#ifndef __WIDL__
  HRESULT WINAPI PeerCollabGetPresenceInfo (PCPEER_ENDPOINT pcEndpoint, PPEER_PRESENCE_INFO *ppPresenceInfo);
  HRESULT WINAPI PeerCollabEnumApplications (PCPEER_ENDPOINT pcEndpoint, const GUID *pApplicationId, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerCollabEnumObjects (PCPEER_ENDPOINT pcEndpoint, const GUID *pObjectId, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerCollabEnumEndpoints (PCPEER_CONTACT pcContact, HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerCollabRefreshEndpointData (PCPEER_ENDPOINT pcEndpoint);
  HRESULT WINAPI PeerCollabDeleteEndpointData (PCPEER_ENDPOINT pcEndpoint);
  HRESULT WINAPI PeerCollabQueryContactData (PCPEER_ENDPOINT pcEndpoint, PWSTR *ppwzContactData);
  HRESULT WINAPI PeerCollabSubscribeEndpointData (const PCPEER_ENDPOINT pcEndpoint);
  HRESULT WINAPI PeerCollabUnsubscribeEndpointData (const PCPEER_ENDPOINT pcEndpoint);
  HRESULT WINAPI PeerCollabSetPresenceInfo (PCPEER_PRESENCE_INFO pcPresenceInfo);
  HRESULT WINAPI PeerCollabGetEndpointName (PWSTR *ppwzEndpointName);
  HRESULT WINAPI PeerCollabSetEndpointName (PCWSTR pwzEndpointName);
  HRESULT WINAPI PeerCollabSetObject (PCPEER_OBJECT pcObject);
  HRESULT WINAPI PeerCollabDeleteObject (const GUID *pObjectId);
#endif

  typedef enum peer_change_type_tag {
    PEER_CHANGE_ADDED = 0,
    PEER_CHANGE_DELETED = 1,
    PEER_CHANGE_UPDATED = 2
  } PEER_CHANGE_TYPE;

  typedef enum peer_collab_event_type_tag {
    PEER_EVENT_WATCHLIST_CHANGED = 1,
    PEER_EVENT_ENDPOINT_CHANGED = 2,
    PEER_EVENT_ENDPOINT_PRESENCE_CHANGED = 3,
    PEER_EVENT_ENDPOINT_APPLICATION_CHANGED = 4,
    PEER_EVENT_ENDPOINT_OBJECT_CHANGED = 5,
    PEER_EVENT_MY_ENDPOINT_CHANGED = 6,
    PEER_EVENT_MY_PRESENCE_CHANGED = 7,
    PEER_EVENT_MY_APPLICATION_CHANGED = 8,
    PEER_EVENT_MY_OBJECT_CHANGED = 9,
    PEER_EVENT_PEOPLE_NEAR_ME_CHANGED = 10,
    PEER_EVENT_REQUEST_STATUS_CHANGED = 11
  } PEER_COLLAB_EVENT_TYPE;

  typedef struct peer_collab_event_registration_tag {
    PEER_COLLAB_EVENT_TYPE eventType;
#ifdef __WIDL__
    [unique]
#endif
    GUID *pInstance;
  } PEER_COLLAB_EVENT_REGISTRATION,*PPEER_COLLAB_EVENT_REGISTRATION;

  typedef struct peer_event_watchlist_changed_data_tag {
    PPEER_CONTACT pContact;
    PEER_CHANGE_TYPE changeType;
  } PEER_EVENT_WATCHLIST_CHANGED_DATA,*PPEER_EVENT_WATCHLIST_CHANGED_DATA;

  typedef struct peer_event_presence_changed_data_tag {
    PPEER_CONTACT pContact;
    PPEER_ENDPOINT pEndpoint;
    PEER_CHANGE_TYPE changeType;
    PPEER_PRESENCE_INFO pPresenceInfo;
  } PEER_EVENT_PRESENCE_CHANGED_DATA,*PPEER_EVENT_PRESENCE_CHANGED_DATA;

  typedef struct peer_event_application_changed_data_tag {
    PPEER_CONTACT pContact;
    PPEER_ENDPOINT pEndpoint;
    PEER_CHANGE_TYPE changeType;
    PPEER_APPLICATION pApplication;
  } PEER_EVENT_APPLICATION_CHANGED_DATA,*PPEER_EVENT_APPLICATION_CHANGED_DATA;

  typedef struct peer_event_object_changed_data_tag {
    PPEER_CONTACT pContact;
    PPEER_ENDPOINT pEndpoint;
    PEER_CHANGE_TYPE changeType;
    PPEER_OBJECT pObject;
  } PEER_EVENT_OBJECT_CHANGED_DATA,*PPEER_EVENT_OBJECT_CHANGED_DATA;

  typedef struct peer_event_endpoint_changed_data_tag {
    PPEER_CONTACT pContact;
    PPEER_ENDPOINT pEndpoint;
  } PEER_EVENT_ENDPOINT_CHANGED_DATA,*PPEER_EVENT_ENDPOINT_CHANGED_DATA;

  typedef struct peer_event_people_near_me_changed_data_tag {
    PEER_CHANGE_TYPE changeType;
    PPEER_PEOPLE_NEAR_ME pPeopleNearMe;
  } PEER_EVENT_PEOPLE_NEAR_ME_CHANGED_DATA,*PPEER_EVENT_PEOPLE_NEAR_ME_CHANGED_DATA;

  typedef struct peer_event_request_status_changed_data_tag {
    PPEER_ENDPOINT pEndpoint;
    HRESULT hrChange;
  } PEER_EVENT_REQUEST_STATUS_CHANGED_DATA,*PPEER_EVENT_REQUEST_STATUS_CHANGED_DATA;

#ifdef __WIDL__
  typedef struct peer_collab_event_data_tag {
    PEER_COLLAB_EVENT_TYPE eventType;
    [switch_is (eventType)]
    union {
      [case (PEER_EVENT_WATCHLIST_CHANGED)] PEER_EVENT_WATCHLIST_CHANGED_DATA watchListChangedData;
      [case (PEER_EVENT_ENDPOINT_PRESENCE_CHANGED, PEER_EVENT_MY_PRESENCE_CHANGED)] PEER_EVENT_PRESENCE_CHANGED_DATA presenceChangedData;
      [case (PEER_EVENT_ENDPOINT_APPLICATION_CHANGED, PEER_EVENT_MY_APPLICATION_CHANGED)] PEER_EVENT_APPLICATION_CHANGED_DATA applicationChangedData;
      [case (PEER_EVENT_ENDPOINT_OBJECT_CHANGED, PEER_EVENT_MY_OBJECT_CHANGED)] PEER_EVENT_OBJECT_CHANGED_DATA objectChangedData;
      [case (PEER_EVENT_ENDPOINT_CHANGED, PEER_EVENT_MY_ENDPOINT_CHANGED)] PEER_EVENT_ENDPOINT_CHANGED_DATA endpointChangedData;
      [case (PEER_EVENT_PEOPLE_NEAR_ME_CHANGED)] PEER_EVENT_PEOPLE_NEAR_ME_CHANGED_DATA peopleNearMeChangedData;
      [case (PEER_EVENT_REQUEST_STATUS_CHANGED)] PEER_EVENT_REQUEST_STATUS_CHANGED_DATA requestStatusChangedData;
      [default] ;
    };
  } PEER_COLLAB_EVENT_DATA,*PPEER_COLLAB_EVENT_DATA;
#else
  typedef struct peer_collab_event_data_tag {
    PEER_COLLAB_EVENT_TYPE eventType;
    __C89_NAMELESS union {
      PEER_EVENT_WATCHLIST_CHANGED_DATA watchListChangedData;
      PEER_EVENT_PRESENCE_CHANGED_DATA presenceChangedData;
      PEER_EVENT_APPLICATION_CHANGED_DATA applicationChangedData;
      PEER_EVENT_OBJECT_CHANGED_DATA objectChangedData;
      PEER_EVENT_ENDPOINT_CHANGED_DATA endpointChangedData;
      PEER_EVENT_PEOPLE_NEAR_ME_CHANGED_DATA peopleNearMeChangedData;
      PEER_EVENT_REQUEST_STATUS_CHANGED_DATA requestStatusChangedData;
    };
  } PEER_COLLAB_EVENT_DATA,*PPEER_COLLAB_EVENT_DATA;

  HRESULT WINAPI PeerCollabRegisterEvent (HANDLE hEvent, DWORD cEventRegistration, PEER_COLLAB_EVENT_REGISTRATION *pEventRegistrations, HPEEREVENT *phPeerEvent);
  HRESULT WINAPI PeerCollabGetEventData (HPEEREVENT hPeerEvent, PPEER_COLLAB_EVENT_DATA *ppEventData);
  HRESULT WINAPI PeerCollabUnregisterEvent (HPEEREVENT hPeerEvent);
  HRESULT WINAPI PeerCollabEnumPeopleNearMe (HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerCollabAddContact (PCWSTR pwzContactData, PPEER_CONTACT *ppContact);
  HRESULT WINAPI PeerCollabDeleteContact (PCWSTR pwzPeerName);
  HRESULT WINAPI PeerCollabGetContact (PCWSTR pwzPeerName, PPEER_CONTACT *ppContact);
  HRESULT WINAPI PeerCollabUpdateContact (PCPEER_CONTACT pContact);
  HRESULT WINAPI PeerCollabEnumContacts (HPEERENUM *phPeerEnum);
  HRESULT WINAPI PeerCollabExportContact (PCWSTR pwzPeerName, PWSTR *ppwzContactData);
  HRESULT WINAPI PeerCollabParseContact (PCWSTR pwzContactData, PPEER_CONTACT *ppContact);
#endif
#endif

#if !defined (NO_P2P_PNRP) && !defined (__WIDL__)
#define PNRP_VERSION MAKEWORD (2, 0)

#define PEER_PNRP_ALL_LINK_CLOUDS L"PEER_PNRP_ALL_LINKS"
#define PEER_PNRP_AUTO_ADDRESSES ((ULONG) (-1))

  typedef PVOID HRESOLUTION, HREGISTRATION;

  typedef struct peer_pnrp_endpoint_info_tag {
    PWSTR pwzPeerName;
    ULONG cAddresses;
    SOCKADDR **ppAddresses;
    PWSTR pwzComment;
    PEER_DATA payload;
  } PEER_PNRP_ENDPOINT_INFO,*PPEER_PNRP_ENDPOINT_INFO;

  typedef struct peer_pnrp_cloud_info_tag {
    PWSTR pwzCloudName;
    PNRP_SCOPE dwScope;
    DWORD dwScopeId;
  } PEER_PNRP_CLOUD_INFO,*PPEER_PNRP_CLOUD_INFO;

  typedef struct peer_pnrp_registration_info_tag {
    PWSTR pwzCloudName;
    PWSTR pwzPublishingIdentity;
    ULONG cAddresses;
    SOCKADDR **ppAddresses;
    WORD wPort;
    PWSTR pwzComment;
    PEER_DATA payload;
  } PEER_PNRP_REGISTRATION_INFO,*PPEER_PNRP_REGISTRATION_INFO;
  
  HRESULT WINAPI PeerNameToPeerHostName (PCWSTR pwzPeerName, PWSTR *ppwzHostName);
  HRESULT WINAPI PeerHostNameToPeerName (PCWSTR pwzHostName, PWSTR *ppwzPeerName);
  HRESULT WINAPI PeerPnrpStartup (WORD wVersionRequested);
  HRESULT WINAPI PeerPnrpShutdown ();
  HRESULT WINAPI PeerPnrpRegister (PCWSTR pcwzPeerName, PPEER_PNRP_REGISTRATION_INFO pRegistrationInfo, HREGISTRATION *phRegistration);
  HRESULT WINAPI PeerPnrpUpdateRegistration (HREGISTRATION hRegistration, PPEER_PNRP_REGISTRATION_INFO pRegistrationInfo);
  HRESULT WINAPI PeerPnrpUnregister (HREGISTRATION hRegistration);
  HRESULT WINAPI PeerPnrpResolve (PCWSTR pcwzPeerName, PCWSTR pcwzCloudName, ULONG *pcEndpoints, PPEER_PNRP_ENDPOINT_INFO *ppEndpoints);
  HRESULT WINAPI PeerPnrpStartResolve (PCWSTR pcwzPeerName, PCWSTR pcwzCloudName, ULONG cMaxEndpoints, HANDLE hEvent, HRESOLUTION *phResolve);
  HRESULT WINAPI PeerPnrpGetCloudInfo (ULONG *pcNumClouds, PPEER_PNRP_CLOUD_INFO *ppCloudInfo);
  HRESULT WINAPI PeerPnrpGetEndpoint (HRESOLUTION hResolve, PPEER_PNRP_ENDPOINT_INFO *ppEndpoint);
  HRESULT WINAPI PeerPnrpEndResolve (HRESOLUTION hResolve);
#endif

#ifdef __cplusplus
}
#endif

#define WSA_PNRP_ERROR_BASE 11500
#define WSA_PNRP_CLOUD_NOT_FOUND (WSA_PNRP_ERROR_BASE + 1)
#define WSA_PNRP_CLOUD_DISABLED (WSA_PNRP_ERROR_BASE + 2)
#define WSA_PNRP_INVALID_IDENTITY (WSA_PNRP_ERROR_BASE + 3)
#define WSA_PNRP_TOO_MUCH_LOAD (WSA_PNRP_ERROR_BASE + 4)
#define WSA_PNRP_CLOUD_IS_SEARCH_ONLY (WSA_PNRP_ERROR_BASE + 5)
#define WSA_PNRP_CLIENT_INVALID_COMPARTMENT_ID (WSA_PNRP_ERROR_BASE + 6)
#define WSA_PNRP_DUPLICATE_PEER_NAME (WSA_PNRP_ERROR_BASE + 8)
#define WSA_PNRP_CLOUD_IS_DEAD (WSA_PNRP_ERROR_BASE + 9)

#define PEER_E_CLOUD_NOT_FOUND MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, WSA_PNRP_CLOUD_NOT_FOUND)
#define PEER_E_CLOUD_DISABLED MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, WSA_PNRP_CLOUD_DISABLED)
#define PEER_E_INVALID_IDENTITY MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, WSA_PNRP_INVALID_IDENTITY)
#define PEER_E_TOO_MUCH_LOAD MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, WSA_PNRP_TOO_MUCH_LOAD)
#define PEER_E_CLOUD_IS_SEARCH_ONLY MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, WSA_PNRP_CLOUD_IS_SEARCH_ONLY)
#define PEER_E_CLIENT_INVALID_COMPARTMENT_ID MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, WSA_PNRP_CLIENT_INVALID_COMPARTMENT_ID)
#define PEER_E_DUPLICATE_PEER_NAME MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, WSA_PNRP_DUPLICATE_PEER_NAME)
#define PEER_E_CLOUD_IS_DEAD MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, WSA_PNRP_CLOUD_IS_DEAD)
#define PEER_E_NOT_FOUND MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_NOT_FOUND)
#define PEER_E_DISK_FULL MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_DISK_FULL)
#define PEER_E_ALREADY_EXISTS MAKE_HRESULT (SEVERITY_ERROR, FACILITY_WIN32, ERROR_ALREADY_EXISTS)
#endif
#endif

#ifdef DEFINE_GUID
#ifndef NO_P2P_GROUP
DEFINE_GUID (PEER_GROUP_ROLE_ADMIN, 0x04387127, 0xaa56, 0x450a, 0x8c, 0xe5, 0x4f, 0x56, 0x5c, 0x67, 0x90, 0xf4);
DEFINE_GUID (PEER_GROUP_ROLE_MEMBER, 0xf12dc4c7, 0x0857, 0x4ca0, 0x93, 0xfc, 0xb1, 0xbb, 0x19, 0xa3, 0xd8, 0xc2);
#if NTDDI_VERSION >= 0x06000000
DEFINE_GUID (PEER_GROUP_ROLE_INVITING_MEMBER, 0x4370fd89, 0xdc18, 0x4cfb, 0x8d, 0xbf, 0x98, 0x53, 0xa8, 0xa9, 0xf9, 0x05);
#endif
#endif
#ifndef NO_P2P_COLLABORATION
DEFINE_GUID (PEER_COLLAB_OBJECTID_USER_PICTURE, 0xdd15f41f, 0xfc4e, 0x4922, 0xb0, 0x35, 0x4c, 0x06, 0xa7, 0x54, 0xd0, 0x1d);
#endif
#endif
