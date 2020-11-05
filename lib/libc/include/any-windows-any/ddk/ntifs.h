/*
 * ntifs.h
 *
 * Windows NT Filesystem Driver Developer Kit
 *
 * This file is part of the ReactOS DDK package.
 *
 * Contributors:
 *   Amine Khaldi
 *   Timo Kreuzer (timo.kreuzer@reactos.org)
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#pragma once

#define _NTIFS_INCLUDED_
#define _GNU_NTIFS_

#ifdef __cplusplus
extern "C" {
#endif

/* Dependencies */
#include <ntddk.h>
#include <excpt.h>
#include <ntdef.h>
#include <ntnls.h>
#include <ntstatus.h>
#include <bugcodes.h>
#include <ntiologc.h>


#ifndef FlagOn
#define FlagOn(_F,_SF)        ((_F) & (_SF))
#endif

#ifndef BooleanFlagOn
#define BooleanFlagOn(F,SF)   ((BOOLEAN)(((F) & (SF)) != 0))
#endif

#ifndef SetFlag
#define SetFlag(_F,_SF)       ((_F) |= (_SF))
#endif

#ifndef ClearFlag
#define ClearFlag(_F,_SF)     ((_F) &= ~(_SF))
#endif

typedef UNICODE_STRING LSA_UNICODE_STRING, *PLSA_UNICODE_STRING;
typedef STRING LSA_STRING, *PLSA_STRING;
typedef OBJECT_ATTRIBUTES LSA_OBJECT_ATTRIBUTES, *PLSA_OBJECT_ATTRIBUTES;

/******************************************************************************
 *                            Security Manager Types                          *
 ******************************************************************************/
#ifndef SID_IDENTIFIER_AUTHORITY_DEFINED
#define SID_IDENTIFIER_AUTHORITY_DEFINED
typedef struct _SID_IDENTIFIER_AUTHORITY {
  UCHAR Value[6];
} SID_IDENTIFIER_AUTHORITY,*PSID_IDENTIFIER_AUTHORITY,*LPSID_IDENTIFIER_AUTHORITY;
#endif

#ifndef SID_DEFINED
#define SID_DEFINED
typedef struct _SID {
  UCHAR Revision;
  UCHAR SubAuthorityCount;
  SID_IDENTIFIER_AUTHORITY IdentifierAuthority;
  ULONG SubAuthority[ANYSIZE_ARRAY];
} SID, *PISID;
#endif

#define SID_REVISION                    1
#define SID_MAX_SUB_AUTHORITIES         15
#define SID_RECOMMENDED_SUB_AUTHORITIES 1

typedef enum _SID_NAME_USE {
  SidTypeUser = 1,
  SidTypeGroup,
  SidTypeDomain,
  SidTypeAlias,
  SidTypeWellKnownGroup,
  SidTypeDeletedAccount,
  SidTypeInvalid,
  SidTypeUnknown,
  SidTypeComputer,
  SidTypeLabel,
  SidTypeLogonSession
} SID_NAME_USE, *PSID_NAME_USE;

typedef struct _SID_AND_ATTRIBUTES {
  PSID Sid;
  ULONG Attributes;
} SID_AND_ATTRIBUTES, *PSID_AND_ATTRIBUTES;
typedef SID_AND_ATTRIBUTES SID_AND_ATTRIBUTES_ARRAY[ANYSIZE_ARRAY];
typedef SID_AND_ATTRIBUTES_ARRAY *PSID_AND_ATTRIBUTES_ARRAY;

#define SID_HASH_SIZE 32
typedef ULONG_PTR SID_HASH_ENTRY, *PSID_HASH_ENTRY;

typedef struct _SID_AND_ATTRIBUTES_HASH {
  ULONG SidCount;
  PSID_AND_ATTRIBUTES SidAttr;
  SID_HASH_ENTRY Hash[SID_HASH_SIZE];
} SID_AND_ATTRIBUTES_HASH, *PSID_AND_ATTRIBUTES_HASH;

/* Universal well-known SIDs */

#define SECURITY_NULL_SID_AUTHORITY         {0,0,0,0,0,0}
#define SECURITY_WORLD_SID_AUTHORITY        {0,0,0,0,0,1}
#define SECURITY_LOCAL_SID_AUTHORITY        {0,0,0,0,0,2}
#define SECURITY_CREATOR_SID_AUTHORITY      {0,0,0,0,0,3}
#define SECURITY_NON_UNIQUE_AUTHORITY       {0,0,0,0,0,4}
#define SECURITY_RESOURCE_MANAGER_AUTHORITY {0,0,0,0,0,9}

#define SECURITY_NULL_RID                 (0x00000000L)
#define SECURITY_WORLD_RID                (0x00000000L)
#define SECURITY_LOCAL_RID                (0x00000000L)
#define SECURITY_LOCAL_LOGON_RID          (0x00000001L)

#define SECURITY_CREATOR_OWNER_RID        (0x00000000L)
#define SECURITY_CREATOR_GROUP_RID        (0x00000001L)
#define SECURITY_CREATOR_OWNER_SERVER_RID (0x00000002L)
#define SECURITY_CREATOR_GROUP_SERVER_RID (0x00000003L)
#define SECURITY_CREATOR_OWNER_RIGHTS_RID (0x00000004L)

/* NT well-known SIDs */

#define SECURITY_NT_AUTHORITY           {0,0,0,0,0,5}

#define SECURITY_DIALUP_RID             (0x00000001L)
#define SECURITY_NETWORK_RID            (0x00000002L)
#define SECURITY_BATCH_RID              (0x00000003L)
#define SECURITY_INTERACTIVE_RID        (0x00000004L)
#define SECURITY_LOGON_IDS_RID          (0x00000005L)
#define SECURITY_LOGON_IDS_RID_COUNT    (3L)
#define SECURITY_SERVICE_RID            (0x00000006L)
#define SECURITY_ANONYMOUS_LOGON_RID    (0x00000007L)
#define SECURITY_PROXY_RID              (0x00000008L)
#define SECURITY_ENTERPRISE_CONTROLLERS_RID (0x00000009L)
#define SECURITY_SERVER_LOGON_RID       SECURITY_ENTERPRISE_CONTROLLERS_RID
#define SECURITY_PRINCIPAL_SELF_RID     (0x0000000AL)
#define SECURITY_AUTHENTICATED_USER_RID (0x0000000BL)
#define SECURITY_RESTRICTED_CODE_RID    (0x0000000CL)
#define SECURITY_TERMINAL_SERVER_RID    (0x0000000DL)
#define SECURITY_REMOTE_LOGON_RID       (0x0000000EL)
#define SECURITY_THIS_ORGANIZATION_RID  (0x0000000FL)
#define SECURITY_IUSER_RID              (0x00000011L)
#define SECURITY_LOCAL_SYSTEM_RID       (0x00000012L)
#define SECURITY_LOCAL_SERVICE_RID      (0x00000013L)
#define SECURITY_NETWORK_SERVICE_RID    (0x00000014L)
#define SECURITY_NT_NON_UNIQUE          (0x00000015L)
#define SECURITY_NT_NON_UNIQUE_SUB_AUTH_COUNT  (3L)
#define SECURITY_ENTERPRISE_READONLY_CONTROLLERS_RID (0x00000016L)

#define SECURITY_BUILTIN_DOMAIN_RID     (0x00000020L)
#define SECURITY_WRITE_RESTRICTED_CODE_RID (0x00000021L)


#define SECURITY_PACKAGE_BASE_RID       (0x00000040L)
#define SECURITY_PACKAGE_RID_COUNT      (2L)
#define SECURITY_PACKAGE_NTLM_RID       (0x0000000AL)
#define SECURITY_PACKAGE_SCHANNEL_RID   (0x0000000EL)
#define SECURITY_PACKAGE_DIGEST_RID     (0x00000015L)

#define SECURITY_CRED_TYPE_BASE_RID             (0x00000041L)
#define SECURITY_CRED_TYPE_RID_COUNT            (2L)
#define SECURITY_CRED_TYPE_THIS_ORG_CERT_RID    (0x00000001L)

#define SECURITY_MIN_BASE_RID		(0x00000050L)
#define SECURITY_SERVICE_ID_BASE_RID    (0x00000050L)
#define SECURITY_SERVICE_ID_RID_COUNT   (6L)
#define SECURITY_RESERVED_ID_BASE_RID   (0x00000051L)
#define SECURITY_APPPOOL_ID_BASE_RID    (0x00000052L)
#define SECURITY_APPPOOL_ID_RID_COUNT   (6L)
#define SECURITY_VIRTUALSERVER_ID_BASE_RID    (0x00000053L)
#define SECURITY_VIRTUALSERVER_ID_RID_COUNT   (6L)
#define SECURITY_USERMODEDRIVERHOST_ID_BASE_RID  (0x00000054L)
#define SECURITY_USERMODEDRIVERHOST_ID_RID_COUNT (6L)
#define SECURITY_CLOUD_INFRASTRUCTURE_SERVICES_ID_BASE_RID  (0x00000055L)
#define SECURITY_CLOUD_INFRASTRUCTURE_SERVICES_ID_RID_COUNT (6L)
#define SECURITY_WMIHOST_ID_BASE_RID  (0x00000056L)
#define SECURITY_WMIHOST_ID_RID_COUNT (6L)
#define SECURITY_TASK_ID_BASE_RID                 (0x00000057L)
#define SECURITY_NFS_ID_BASE_RID        (0x00000058L)
#define SECURITY_COM_ID_BASE_RID        (0x00000059L)
#define SECURITY_VIRTUALACCOUNT_ID_RID_COUNT   (6L)

#define SECURITY_MAX_BASE_RID		(0x0000006FL)

#define SECURITY_MAX_ALWAYS_FILTERED    (0x000003E7L)
#define SECURITY_MIN_NEVER_FILTERED     (0x000003E8L)

#define SECURITY_OTHER_ORGANIZATION_RID (0x000003E8L)

#define SECURITY_WINDOWSMOBILE_ID_BASE_RID (0x00000070L)

/* Well-known domain relative sub-authority values (RIDs) */

#define DOMAIN_GROUP_RID_ENTERPRISE_READONLY_DOMAIN_CONTROLLERS (0x000001F2L)

#define FOREST_USER_RID_MAX            (0x000001F3L)

/* Well-known users */

#define DOMAIN_USER_RID_ADMIN          (0x000001F4L)
#define DOMAIN_USER_RID_GUEST          (0x000001F5L)
#define DOMAIN_USER_RID_KRBTGT         (0x000001F6L)

#define DOMAIN_USER_RID_MAX            (0x000003E7L)

/* Well-known groups */

#define DOMAIN_GROUP_RID_ADMINS               (0x00000200L)
#define DOMAIN_GROUP_RID_USERS                (0x00000201L)
#define DOMAIN_GROUP_RID_GUESTS               (0x00000202L)
#define DOMAIN_GROUP_RID_COMPUTERS            (0x00000203L)
#define DOMAIN_GROUP_RID_CONTROLLERS          (0x00000204L)
#define DOMAIN_GROUP_RID_CERT_ADMINS          (0x00000205L)
#define DOMAIN_GROUP_RID_SCHEMA_ADMINS        (0x00000206L)
#define DOMAIN_GROUP_RID_ENTERPRISE_ADMINS    (0x00000207L)
#define DOMAIN_GROUP_RID_POLICY_ADMINS        (0x00000208L)
#define DOMAIN_GROUP_RID_READONLY_CONTROLLERS (0x00000209L)

/* Well-known aliases */

#define DOMAIN_ALIAS_RID_ADMINS                         (0x00000220L)
#define DOMAIN_ALIAS_RID_USERS                          (0x00000221L)
#define DOMAIN_ALIAS_RID_GUESTS                         (0x00000222L)
#define DOMAIN_ALIAS_RID_POWER_USERS                    (0x00000223L)

#define DOMAIN_ALIAS_RID_ACCOUNT_OPS                    (0x00000224L)
#define DOMAIN_ALIAS_RID_SYSTEM_OPS                     (0x00000225L)
#define DOMAIN_ALIAS_RID_PRINT_OPS                      (0x00000226L)
#define DOMAIN_ALIAS_RID_BACKUP_OPS                     (0x00000227L)

#define DOMAIN_ALIAS_RID_REPLICATOR                     (0x00000228L)
#define DOMAIN_ALIAS_RID_RAS_SERVERS                    (0x00000229L)
#define DOMAIN_ALIAS_RID_PREW2KCOMPACCESS               (0x0000022AL)
#define DOMAIN_ALIAS_RID_REMOTE_DESKTOP_USERS           (0x0000022BL)
#define DOMAIN_ALIAS_RID_NETWORK_CONFIGURATION_OPS      (0x0000022CL)
#define DOMAIN_ALIAS_RID_INCOMING_FOREST_TRUST_BUILDERS (0x0000022DL)

#define DOMAIN_ALIAS_RID_MONITORING_USERS               (0x0000022EL)
#define DOMAIN_ALIAS_RID_LOGGING_USERS                  (0x0000022FL)
#define DOMAIN_ALIAS_RID_AUTHORIZATIONACCESS            (0x00000230L)
#define DOMAIN_ALIAS_RID_TS_LICENSE_SERVERS             (0x00000231L)
#define DOMAIN_ALIAS_RID_DCOM_USERS                     (0x00000232L)
#define DOMAIN_ALIAS_RID_IUSERS                         (0x00000238L)
#define DOMAIN_ALIAS_RID_CRYPTO_OPERATORS               (0x00000239L)
#define DOMAIN_ALIAS_RID_CACHEABLE_PRINCIPALS_GROUP     (0x0000023BL)
#define DOMAIN_ALIAS_RID_NON_CACHEABLE_PRINCIPALS_GROUP (0x0000023CL)
#define DOMAIN_ALIAS_RID_EVENT_LOG_READERS_GROUP        (0x0000023DL)
#define DOMAIN_ALIAS_RID_CERTSVC_DCOM_ACCESS_GROUP      (0x0000023EL)

#define SECURITY_MANDATORY_LABEL_AUTHORITY          {0,0,0,0,0,16}
#define SECURITY_MANDATORY_UNTRUSTED_RID            (0x00000000L)
#define SECURITY_MANDATORY_LOW_RID                  (0x00001000L)
#define SECURITY_MANDATORY_MEDIUM_RID               (0x00002000L)
#define SECURITY_MANDATORY_HIGH_RID                 (0x00003000L)
#define SECURITY_MANDATORY_SYSTEM_RID               (0x00004000L)
#define SECURITY_MANDATORY_PROTECTED_PROCESS_RID    (0x00005000L)

/* SECURITY_MANDATORY_MAXIMUM_USER_RID is the highest RID that
   can be set by a usermode caller.*/

#define SECURITY_MANDATORY_MAXIMUM_USER_RID   SECURITY_MANDATORY_SYSTEM_RID

#define MANDATORY_LEVEL_TO_MANDATORY_RID(IL) (IL * 0x1000)

/* Allocate the System Luid.  The first 1000 LUIDs are reserved.
   Use #999 here (0x3e7 = 999) */

#define SYSTEM_LUID                     {0x3e7, 0x0}
#define ANONYMOUS_LOGON_LUID            {0x3e6, 0x0}
#define LOCALSERVICE_LUID               {0x3e5, 0x0}
#define NETWORKSERVICE_LUID             {0x3e4, 0x0}
#define IUSER_LUID                      {0x3e3, 0x0}

typedef struct _ACE_HEADER {
  UCHAR AceType;
  UCHAR AceFlags;
  USHORT AceSize;
} ACE_HEADER, *PACE_HEADER;

/* also in winnt.h */
#define ACCESS_MIN_MS_ACE_TYPE                  (0x0)
#define ACCESS_ALLOWED_ACE_TYPE                 (0x0)
#define ACCESS_DENIED_ACE_TYPE                  (0x1)
#define SYSTEM_AUDIT_ACE_TYPE                   (0x2)
#define SYSTEM_ALARM_ACE_TYPE                   (0x3)
#define ACCESS_MAX_MS_V2_ACE_TYPE               (0x3)
#define ACCESS_ALLOWED_COMPOUND_ACE_TYPE        (0x4)
#define ACCESS_MAX_MS_V3_ACE_TYPE               (0x4)
#define ACCESS_MIN_MS_OBJECT_ACE_TYPE           (0x5)
#define ACCESS_ALLOWED_OBJECT_ACE_TYPE          (0x5)
#define ACCESS_DENIED_OBJECT_ACE_TYPE           (0x6)
#define SYSTEM_AUDIT_OBJECT_ACE_TYPE            (0x7)
#define SYSTEM_ALARM_OBJECT_ACE_TYPE            (0x8)
#define ACCESS_MAX_MS_OBJECT_ACE_TYPE           (0x8)
#define ACCESS_MAX_MS_V4_ACE_TYPE               (0x8)
#define ACCESS_MAX_MS_ACE_TYPE                  (0x8)
#define ACCESS_ALLOWED_CALLBACK_ACE_TYPE        (0x9)
#define ACCESS_DENIED_CALLBACK_ACE_TYPE         (0xA)
#define ACCESS_ALLOWED_CALLBACK_OBJECT_ACE_TYPE (0xB)
#define ACCESS_DENIED_CALLBACK_OBJECT_ACE_TYPE  (0xC)
#define SYSTEM_AUDIT_CALLBACK_ACE_TYPE          (0xD)
#define SYSTEM_ALARM_CALLBACK_ACE_TYPE          (0xE)
#define SYSTEM_AUDIT_CALLBACK_OBJECT_ACE_TYPE   (0xF)
#define SYSTEM_ALARM_CALLBACK_OBJECT_ACE_TYPE   (0x10)
#define ACCESS_MAX_MS_V5_ACE_TYPE               (0x11)
#define SYSTEM_MANDATORY_LABEL_ACE_TYPE         (0x11)

/* The following are the inherit flags that go into the AceFlags field
   of an Ace header. */

#define OBJECT_INHERIT_ACE                (0x1)
#define CONTAINER_INHERIT_ACE             (0x2)
#define NO_PROPAGATE_INHERIT_ACE          (0x4)
#define INHERIT_ONLY_ACE                  (0x8)
#define INHERITED_ACE                     (0x10)
#define VALID_INHERIT_FLAGS               (0x1F)

#define SUCCESSFUL_ACCESS_ACE_FLAG        (0x40)
#define FAILED_ACCESS_ACE_FLAG            (0x80)

typedef struct _ACCESS_ALLOWED_ACE {
  ACE_HEADER Header;
  ACCESS_MASK Mask;
  ULONG SidStart;
} ACCESS_ALLOWED_ACE, *PACCESS_ALLOWED_ACE;

typedef struct _ACCESS_DENIED_ACE {
  ACE_HEADER Header;
  ACCESS_MASK Mask;
  ULONG SidStart;
} ACCESS_DENIED_ACE, *PACCESS_DENIED_ACE;

typedef struct _SYSTEM_AUDIT_ACE {
  ACE_HEADER Header;
  ACCESS_MASK Mask;
  ULONG SidStart;
} SYSTEM_AUDIT_ACE, *PSYSTEM_AUDIT_ACE;

typedef struct _SYSTEM_ALARM_ACE {
  ACE_HEADER Header;
  ACCESS_MASK Mask;
  ULONG SidStart;
} SYSTEM_ALARM_ACE, *PSYSTEM_ALARM_ACE;

typedef struct _SYSTEM_MANDATORY_LABEL_ACE {
  ACE_HEADER Header;
  ACCESS_MASK Mask;
  ULONG SidStart;
} SYSTEM_MANDATORY_LABEL_ACE, *PSYSTEM_MANDATORY_LABEL_ACE;

#define SYSTEM_MANDATORY_LABEL_NO_WRITE_UP         0x1
#define SYSTEM_MANDATORY_LABEL_NO_READ_UP          0x2
#define SYSTEM_MANDATORY_LABEL_NO_EXECUTE_UP       0x4
#define SYSTEM_MANDATORY_LABEL_VALID_MASK (SYSTEM_MANDATORY_LABEL_NO_WRITE_UP   | \
                                           SYSTEM_MANDATORY_LABEL_NO_READ_UP    | \
                                           SYSTEM_MANDATORY_LABEL_NO_EXECUTE_UP)

#define SECURITY_DESCRIPTOR_MIN_LENGTH   (sizeof(SECURITY_DESCRIPTOR))

typedef USHORT SECURITY_DESCRIPTOR_CONTROL,*PSECURITY_DESCRIPTOR_CONTROL;

#define SE_OWNER_DEFAULTED              0x0001
#define SE_GROUP_DEFAULTED              0x0002
#define SE_DACL_PRESENT                 0x0004
#define SE_DACL_DEFAULTED               0x0008
#define SE_SACL_PRESENT                 0x0010
#define SE_SACL_DEFAULTED               0x0020
#define SE_DACL_UNTRUSTED               0x0040
#define SE_SERVER_SECURITY              0x0080
#define SE_DACL_AUTO_INHERIT_REQ        0x0100
#define SE_SACL_AUTO_INHERIT_REQ        0x0200
#define SE_DACL_AUTO_INHERITED          0x0400
#define SE_SACL_AUTO_INHERITED          0x0800
#define SE_DACL_PROTECTED               0x1000
#define SE_SACL_PROTECTED               0x2000
#define SE_RM_CONTROL_VALID             0x4000
#define SE_SELF_RELATIVE                0x8000

typedef struct _SECURITY_DESCRIPTOR_RELATIVE {
  UCHAR Revision;
  UCHAR Sbz1;
  SECURITY_DESCRIPTOR_CONTROL Control;
  ULONG Owner;
  ULONG Group;
  ULONG Sacl;
  ULONG Dacl;
} SECURITY_DESCRIPTOR_RELATIVE, *PISECURITY_DESCRIPTOR_RELATIVE;

typedef struct _SECURITY_DESCRIPTOR {
  UCHAR Revision;
  UCHAR Sbz1;
  SECURITY_DESCRIPTOR_CONTROL Control;
  PSID Owner;
  PSID Group;
  PACL Sacl;
  PACL Dacl;
} SECURITY_DESCRIPTOR, *PISECURITY_DESCRIPTOR;

typedef struct _OBJECT_TYPE_LIST {
  USHORT Level;
  USHORT Sbz;
  GUID *ObjectType;
} OBJECT_TYPE_LIST, *POBJECT_TYPE_LIST;

#define ACCESS_OBJECT_GUID       0
#define ACCESS_PROPERTY_SET_GUID 1
#define ACCESS_PROPERTY_GUID     2
#define ACCESS_MAX_LEVEL         4

typedef enum _AUDIT_EVENT_TYPE {
  AuditEventObjectAccess,
  AuditEventDirectoryServiceAccess
} AUDIT_EVENT_TYPE, *PAUDIT_EVENT_TYPE;

#define AUDIT_ALLOW_NO_PRIVILEGE 0x1

#define ACCESS_DS_SOURCE_A "DS"
#define ACCESS_DS_SOURCE_W L"DS"
#define ACCESS_DS_OBJECT_TYPE_NAME_A "Directory Service Object"
#define ACCESS_DS_OBJECT_TYPE_NAME_W L"Directory Service Object"

#define ACCESS_REASON_TYPE_MASK 0xffff0000
#define ACCESS_REASON_DATA_MASK 0x0000ffff

typedef enum _ACCESS_REASON_TYPE {
  AccessReasonNone = 0x00000000,
  AccessReasonAllowedAce = 0x00010000,
  AccessReasonDeniedAce = 0x00020000,
  AccessReasonAllowedParentAce = 0x00030000,
  AccessReasonDeniedParentAce = 0x00040000,
  AccessReasonMissingPrivilege = 0x00100000,
  AccessReasonFromPrivilege = 0x00200000,
  AccessReasonIntegrityLevel = 0x00300000,
  AccessReasonOwnership = 0x00400000,
  AccessReasonNullDacl = 0x00500000,
  AccessReasonEmptyDacl = 0x00600000,
  AccessReasonNoSD = 0x00700000,
  AccessReasonNoGrant = 0x00800000
} ACCESS_REASON_TYPE;

typedef ULONG ACCESS_REASON;

typedef struct _ACCESS_REASONS {
  ACCESS_REASON Data[32];
} ACCESS_REASONS, *PACCESS_REASONS;

#define SE_SECURITY_DESCRIPTOR_FLAG_NO_OWNER_ACE    0x00000001
#define SE_SECURITY_DESCRIPTOR_FLAG_NO_LABEL_ACE    0x00000002
#define SE_SECURITY_DESCRIPTOR_VALID_FLAGS          0x00000003

typedef struct _SE_SECURITY_DESCRIPTOR {
  ULONG Size;
  ULONG Flags;
  PSECURITY_DESCRIPTOR SecurityDescriptor;
} SE_SECURITY_DESCRIPTOR, *PSE_SECURITY_DESCRIPTOR;

typedef struct _SE_ACCESS_REQUEST {
  ULONG Size;
  PSE_SECURITY_DESCRIPTOR SeSecurityDescriptor;
  ACCESS_MASK DesiredAccess;
  ACCESS_MASK PreviouslyGrantedAccess;
  PSID PrincipalSelfSid;
  PGENERIC_MAPPING GenericMapping;
  ULONG ObjectTypeListCount;
  POBJECT_TYPE_LIST ObjectTypeList;
} SE_ACCESS_REQUEST, *PSE_ACCESS_REQUEST;

typedef struct _SE_ACCESS_REPLY {
  ULONG Size;
  ULONG ResultListCount;
  PACCESS_MASK GrantedAccess;
  PNTSTATUS AccessStatus;
  PACCESS_REASONS AccessReason;
  PPRIVILEGE_SET* Privileges;
} SE_ACCESS_REPLY, *PSE_ACCESS_REPLY;

typedef enum _SE_AUDIT_OPERATION {
  AuditPrivilegeObject,
  AuditPrivilegeService,
  AuditAccessCheck,
  AuditOpenObject,
  AuditOpenObjectWithTransaction,
  AuditCloseObject,
  AuditDeleteObject,
  AuditOpenObjectForDelete,
  AuditOpenObjectForDeleteWithTransaction,
  AuditCloseNonObject,
  AuditOpenNonObject,
  AuditObjectReference,
  AuditHandleCreation,
} SE_AUDIT_OPERATION, *PSE_AUDIT_OPERATION;

typedef struct _SE_AUDIT_INFO {
  ULONG Size;
  AUDIT_EVENT_TYPE AuditType;
  SE_AUDIT_OPERATION AuditOperation;
  ULONG AuditFlags;
  UNICODE_STRING SubsystemName;
  UNICODE_STRING ObjectTypeName;
  UNICODE_STRING ObjectName;
  PVOID HandleId;
  GUID* TransactionId;
  LUID* OperationId;
  BOOLEAN ObjectCreation;
  BOOLEAN GenerateOnClose;
} SE_AUDIT_INFO, *PSE_AUDIT_INFO;

#define TOKEN_ASSIGN_PRIMARY            (0x0001)
#define TOKEN_DUPLICATE                 (0x0002)
#define TOKEN_IMPERSONATE               (0x0004)
#define TOKEN_QUERY                     (0x0008)
#define TOKEN_QUERY_SOURCE              (0x0010)
#define TOKEN_ADJUST_PRIVILEGES         (0x0020)
#define TOKEN_ADJUST_GROUPS             (0x0040)
#define TOKEN_ADJUST_DEFAULT            (0x0080)
#define TOKEN_ADJUST_SESSIONID          (0x0100)

#define TOKEN_ALL_ACCESS_P (STANDARD_RIGHTS_REQUIRED  |\
                            TOKEN_ASSIGN_PRIMARY      |\
                            TOKEN_DUPLICATE           |\
                            TOKEN_IMPERSONATE         |\
                            TOKEN_QUERY               |\
                            TOKEN_QUERY_SOURCE        |\
                            TOKEN_ADJUST_PRIVILEGES   |\
                            TOKEN_ADJUST_GROUPS       |\
                            TOKEN_ADJUST_DEFAULT )

#if ((defined(_WIN32_WINNT) && (_WIN32_WINNT > 0x0400)) || (!defined(_WIN32_WINNT)))
#define TOKEN_ALL_ACCESS  (TOKEN_ALL_ACCESS_P |\
                           TOKEN_ADJUST_SESSIONID )
#else
#define TOKEN_ALL_ACCESS  (TOKEN_ALL_ACCESS_P)
#endif

#define TOKEN_READ       (STANDARD_RIGHTS_READ     |\
                          TOKEN_QUERY)

#define TOKEN_WRITE      (STANDARD_RIGHTS_WRITE    |\
                          TOKEN_ADJUST_PRIVILEGES  |\
                          TOKEN_ADJUST_GROUPS      |\
                          TOKEN_ADJUST_DEFAULT)

#define TOKEN_EXECUTE    (STANDARD_RIGHTS_EXECUTE)

typedef enum _TOKEN_TYPE {
  TokenPrimary = 1,
  TokenImpersonation
} TOKEN_TYPE,*PTOKEN_TYPE;

typedef enum _TOKEN_INFORMATION_CLASS {
  TokenUser = 1,
  TokenGroups,
  TokenPrivileges,
  TokenOwner,
  TokenPrimaryGroup,
  TokenDefaultDacl,
  TokenSource,
  TokenType,
  TokenImpersonationLevel,
  TokenStatistics,
  TokenRestrictedSids,
  TokenSessionId,
  TokenGroupsAndPrivileges,
  TokenSessionReference,
  TokenSandBoxInert,
  TokenAuditPolicy,
  TokenOrigin,
  TokenElevationType,
  TokenLinkedToken,
  TokenElevation,
  TokenHasRestrictions,
  TokenAccessInformation,
  TokenVirtualizationAllowed,
  TokenVirtualizationEnabled,
  TokenIntegrityLevel,
  TokenUIAccess,
  TokenMandatoryPolicy,
  TokenLogonSid,
  MaxTokenInfoClass
} TOKEN_INFORMATION_CLASS, *PTOKEN_INFORMATION_CLASS;

typedef struct _TOKEN_USER {
  SID_AND_ATTRIBUTES User;
} TOKEN_USER, *PTOKEN_USER;

typedef struct _TOKEN_GROUPS {
  ULONG GroupCount;
  SID_AND_ATTRIBUTES Groups[ANYSIZE_ARRAY];
} TOKEN_GROUPS,*PTOKEN_GROUPS,*LPTOKEN_GROUPS;

typedef struct _TOKEN_PRIVILEGES {
  ULONG PrivilegeCount;
  LUID_AND_ATTRIBUTES Privileges[ANYSIZE_ARRAY];
} TOKEN_PRIVILEGES,*PTOKEN_PRIVILEGES,*LPTOKEN_PRIVILEGES;

typedef struct _TOKEN_OWNER {
  PSID Owner;
} TOKEN_OWNER,*PTOKEN_OWNER;

typedef struct _TOKEN_PRIMARY_GROUP {
  PSID PrimaryGroup;
} TOKEN_PRIMARY_GROUP,*PTOKEN_PRIMARY_GROUP;

typedef struct _TOKEN_DEFAULT_DACL {
  PACL DefaultDacl;
} TOKEN_DEFAULT_DACL,*PTOKEN_DEFAULT_DACL;

typedef struct _TOKEN_GROUPS_AND_PRIVILEGES {
  ULONG SidCount;
  ULONG SidLength;
  PSID_AND_ATTRIBUTES Sids;
  ULONG RestrictedSidCount;
  ULONG RestrictedSidLength;
  PSID_AND_ATTRIBUTES RestrictedSids;
  ULONG PrivilegeCount;
  ULONG PrivilegeLength;
  PLUID_AND_ATTRIBUTES Privileges;
  LUID AuthenticationId;
} TOKEN_GROUPS_AND_PRIVILEGES, *PTOKEN_GROUPS_AND_PRIVILEGES;

typedef struct _TOKEN_LINKED_TOKEN {
  HANDLE LinkedToken;
} TOKEN_LINKED_TOKEN, *PTOKEN_LINKED_TOKEN;

typedef struct _TOKEN_ELEVATION {
  ULONG TokenIsElevated;
} TOKEN_ELEVATION, *PTOKEN_ELEVATION;

typedef struct _TOKEN_MANDATORY_LABEL {
  SID_AND_ATTRIBUTES Label;
} TOKEN_MANDATORY_LABEL, *PTOKEN_MANDATORY_LABEL;

#define TOKEN_MANDATORY_POLICY_OFF             0x0
#define TOKEN_MANDATORY_POLICY_NO_WRITE_UP     0x1
#define TOKEN_MANDATORY_POLICY_NEW_PROCESS_MIN 0x2

#define TOKEN_MANDATORY_POLICY_VALID_MASK    (TOKEN_MANDATORY_POLICY_NO_WRITE_UP | \
                                              TOKEN_MANDATORY_POLICY_NEW_PROCESS_MIN)

typedef struct _TOKEN_MANDATORY_POLICY {
  ULONG Policy;
} TOKEN_MANDATORY_POLICY, *PTOKEN_MANDATORY_POLICY;

typedef struct _TOKEN_ACCESS_INFORMATION {
  PSID_AND_ATTRIBUTES_HASH SidHash;
  PSID_AND_ATTRIBUTES_HASH RestrictedSidHash;
  PTOKEN_PRIVILEGES Privileges;
  LUID AuthenticationId;
  TOKEN_TYPE TokenType;
  SECURITY_IMPERSONATION_LEVEL ImpersonationLevel;
  TOKEN_MANDATORY_POLICY MandatoryPolicy;
  ULONG Flags;
} TOKEN_ACCESS_INFORMATION, *PTOKEN_ACCESS_INFORMATION;

#define POLICY_AUDIT_SUBCATEGORY_COUNT (53)

typedef struct _TOKEN_AUDIT_POLICY {
  UCHAR PerUserPolicy[((POLICY_AUDIT_SUBCATEGORY_COUNT) >> 1) + 1];
} TOKEN_AUDIT_POLICY, *PTOKEN_AUDIT_POLICY;

#define TOKEN_SOURCE_LENGTH 8

typedef struct _TOKEN_SOURCE {
  CHAR SourceName[TOKEN_SOURCE_LENGTH];
  LUID SourceIdentifier;
} TOKEN_SOURCE,*PTOKEN_SOURCE;

typedef struct _TOKEN_STATISTICS {
  LUID TokenId;
  LUID AuthenticationId;
  LARGE_INTEGER ExpirationTime;
  TOKEN_TYPE TokenType;
  SECURITY_IMPERSONATION_LEVEL ImpersonationLevel;
  ULONG DynamicCharged;
  ULONG DynamicAvailable;
  ULONG GroupCount;
  ULONG PrivilegeCount;
  LUID ModifiedId;
} TOKEN_STATISTICS, *PTOKEN_STATISTICS;

typedef struct _TOKEN_CONTROL {
  LUID TokenId;
  LUID AuthenticationId;
  LUID ModifiedId;
  TOKEN_SOURCE TokenSource;
} TOKEN_CONTROL,*PTOKEN_CONTROL;

typedef struct _TOKEN_ORIGIN {
  LUID OriginatingLogonSession;
} TOKEN_ORIGIN, *PTOKEN_ORIGIN;

typedef enum _MANDATORY_LEVEL {
  MandatoryLevelUntrusted = 0,
  MandatoryLevelLow,
  MandatoryLevelMedium,
  MandatoryLevelHigh,
  MandatoryLevelSystem,
  MandatoryLevelSecureProcess,
  MandatoryLevelCount
} MANDATORY_LEVEL, *PMANDATORY_LEVEL;

#define TOKEN_HAS_TRAVERSE_PRIVILEGE    0x0001
#define TOKEN_HAS_BACKUP_PRIVILEGE      0x0002
#define TOKEN_HAS_RESTORE_PRIVILEGE     0x0004
#define TOKEN_WRITE_RESTRICTED          0x0008
#define TOKEN_IS_RESTRICTED             0x0010
#define TOKEN_SESSION_NOT_REFERENCED    0x0020
#define TOKEN_SANDBOX_INERT             0x0040
#define TOKEN_HAS_IMPERSONATE_PRIVILEGE 0x0080
#define SE_BACKUP_PRIVILEGES_CHECKED    0x0100
#define TOKEN_VIRTUALIZE_ALLOWED        0x0200
#define TOKEN_VIRTUALIZE_ENABLED        0x0400
#define TOKEN_IS_FILTERED               0x0800
#define TOKEN_UIACCESS                  0x1000
#define TOKEN_NOT_LOW                   0x2000

typedef struct _SE_EXPORTS {
  LUID SeCreateTokenPrivilege;
  LUID SeAssignPrimaryTokenPrivilege;
  LUID SeLockMemoryPrivilege;
  LUID SeIncreaseQuotaPrivilege;
  LUID SeUnsolicitedInputPrivilege;
  LUID SeTcbPrivilege;
  LUID SeSecurityPrivilege;
  LUID SeTakeOwnershipPrivilege;
  LUID SeLoadDriverPrivilege;
  LUID SeCreatePagefilePrivilege;
  LUID SeIncreaseBasePriorityPrivilege;
  LUID SeSystemProfilePrivilege;
  LUID SeSystemtimePrivilege;
  LUID SeProfileSingleProcessPrivilege;
  LUID SeCreatePermanentPrivilege;
  LUID SeBackupPrivilege;
  LUID SeRestorePrivilege;
  LUID SeShutdownPrivilege;
  LUID SeDebugPrivilege;
  LUID SeAuditPrivilege;
  LUID SeSystemEnvironmentPrivilege;
  LUID SeChangeNotifyPrivilege;
  LUID SeRemoteShutdownPrivilege;
  PSID SeNullSid;
  PSID SeWorldSid;
  PSID SeLocalSid;
  PSID SeCreatorOwnerSid;
  PSID SeCreatorGroupSid;
  PSID SeNtAuthoritySid;
  PSID SeDialupSid;
  PSID SeNetworkSid;
  PSID SeBatchSid;
  PSID SeInteractiveSid;
  PSID SeLocalSystemSid;
  PSID SeAliasAdminsSid;
  PSID SeAliasUsersSid;
  PSID SeAliasGuestsSid;
  PSID SeAliasPowerUsersSid;
  PSID SeAliasAccountOpsSid;
  PSID SeAliasSystemOpsSid;
  PSID SeAliasPrintOpsSid;
  PSID SeAliasBackupOpsSid;
  PSID SeAuthenticatedUsersSid;
  PSID SeRestrictedSid;
  PSID SeAnonymousLogonSid;
  LUID SeUndockPrivilege;
  LUID SeSyncAgentPrivilege;
  LUID SeEnableDelegationPrivilege;
  PSID SeLocalServiceSid;
  PSID SeNetworkServiceSid;
  LUID SeManageVolumePrivilege;
  LUID SeImpersonatePrivilege;
  LUID SeCreateGlobalPrivilege;
  LUID SeTrustedCredManAccessPrivilege;
  LUID SeRelabelPrivilege;
  LUID SeIncreaseWorkingSetPrivilege;
  LUID SeTimeZonePrivilege;
  LUID SeCreateSymbolicLinkPrivilege;
  PSID SeIUserSid;
  PSID SeUntrustedMandatorySid;
  PSID SeLowMandatorySid;
  PSID SeMediumMandatorySid;
  PSID SeHighMandatorySid;
  PSID SeSystemMandatorySid;
  PSID SeOwnerRightsSid;
} SE_EXPORTS, *PSE_EXPORTS;

typedef NTSTATUS
(NTAPI *PSE_LOGON_SESSION_TERMINATED_ROUTINE)(
  IN PLUID LogonId);
/******************************************************************************
 *                           Runtime Library Types                            *
 ******************************************************************************/


#define RTL_SYSTEM_VOLUME_INFORMATION_FOLDER    L"System Volume Information"

typedef PVOID
(NTAPI *PRTL_ALLOCATE_STRING_ROUTINE)(
  IN SIZE_T NumberOfBytes);

#if _WIN32_WINNT >= 0x0600
typedef PVOID
(NTAPI *PRTL_REALLOCATE_STRING_ROUTINE)(
  IN SIZE_T NumberOfBytes,
  IN PVOID Buffer);
#endif

typedef VOID
(NTAPI *PRTL_FREE_STRING_ROUTINE)(
  IN PVOID Buffer);

extern const PRTL_ALLOCATE_STRING_ROUTINE RtlAllocateStringRoutine;
extern const PRTL_FREE_STRING_ROUTINE RtlFreeStringRoutine;

#if _WIN32_WINNT >= 0x0600
extern const PRTL_REALLOCATE_STRING_ROUTINE RtlReallocateStringRoutine;
#endif

typedef NTSTATUS
(NTAPI * PRTL_HEAP_COMMIT_ROUTINE) (
  IN PVOID Base,
  IN OUT PVOID *CommitAddress,
  IN OUT PSIZE_T CommitSize);

typedef struct _RTL_HEAP_PARAMETERS {
  ULONG Length;
  SIZE_T SegmentReserve;
  SIZE_T SegmentCommit;
  SIZE_T DeCommitFreeBlockThreshold;
  SIZE_T DeCommitTotalFreeThreshold;
  SIZE_T MaximumAllocationSize;
  SIZE_T VirtualMemoryThreshold;
  SIZE_T InitialCommit;
  SIZE_T InitialReserve;
  PRTL_HEAP_COMMIT_ROUTINE CommitRoutine;
  SIZE_T Reserved[2];
} RTL_HEAP_PARAMETERS, *PRTL_HEAP_PARAMETERS;

#if (NTDDI_VERSION >= NTDDI_WIN2K)

typedef struct _GENERATE_NAME_CONTEXT {
  USHORT Checksum;
  BOOLEAN CheckSumInserted;
  UCHAR NameLength;
  WCHAR NameBuffer[8];
  ULONG ExtensionLength;
  WCHAR ExtensionBuffer[4];
  ULONG LastIndexValue;
} GENERATE_NAME_CONTEXT, *PGENERATE_NAME_CONTEXT;

typedef struct _PREFIX_TABLE_ENTRY {
  CSHORT NodeTypeCode;
  CSHORT NameLength;
  struct _PREFIX_TABLE_ENTRY *NextPrefixTree;
  RTL_SPLAY_LINKS Links;
  PSTRING Prefix;
} PREFIX_TABLE_ENTRY, *PPREFIX_TABLE_ENTRY;

typedef struct _PREFIX_TABLE {
  CSHORT NodeTypeCode;
  CSHORT NameLength;
  PPREFIX_TABLE_ENTRY NextPrefixTree;
} PREFIX_TABLE, *PPREFIX_TABLE;

typedef struct _UNICODE_PREFIX_TABLE_ENTRY {
  CSHORT NodeTypeCode;
  CSHORT NameLength;
  struct _UNICODE_PREFIX_TABLE_ENTRY *NextPrefixTree;
  struct _UNICODE_PREFIX_TABLE_ENTRY *CaseMatch;
  RTL_SPLAY_LINKS Links;
  PUNICODE_STRING Prefix;
} UNICODE_PREFIX_TABLE_ENTRY, *PUNICODE_PREFIX_TABLE_ENTRY;

typedef struct _UNICODE_PREFIX_TABLE {
  CSHORT NodeTypeCode;
  CSHORT NameLength;
  PUNICODE_PREFIX_TABLE_ENTRY NextPrefixTree;
  PUNICODE_PREFIX_TABLE_ENTRY LastNextEntry;
} UNICODE_PREFIX_TABLE, *PUNICODE_PREFIX_TABLE;

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)
typedef struct _COMPRESSED_DATA_INFO {
  USHORT CompressionFormatAndEngine;
  UCHAR CompressionUnitShift;
  UCHAR ChunkShift;
  UCHAR ClusterShift;
  UCHAR Reserved;
  USHORT NumberOfChunks;
  ULONG CompressedChunkSizes[ANYSIZE_ARRAY];
} COMPRESSED_DATA_INFO, *PCOMPRESSED_DATA_INFO;
#endif

/******************************************************************************
 *                         Runtime Library Functions                          *
 ******************************************************************************/

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTSYSAPI
PVOID
NTAPI
RtlAllocateHeap(
  IN HANDLE HeapHandle,
  IN ULONG Flags OPTIONAL,
  IN SIZE_T Size);

NTSYSAPI
BOOLEAN
NTAPI
RtlFreeHeap(
  IN PVOID HeapHandle,
  IN ULONG Flags OPTIONAL,
  IN PVOID BaseAddress);

NTSYSAPI
VOID
NTAPI
RtlCaptureContext(
  OUT PCONTEXT ContextRecord);

NTSYSAPI
ULONG
NTAPI
RtlRandom(
  IN OUT PULONG Seed);

NTSYSAPI
BOOLEAN
NTAPI
RtlCreateUnicodeString(
  OUT PUNICODE_STRING DestinationString,
  IN PCWSTR SourceString);

NTSYSAPI
NTSTATUS
NTAPI
RtlAppendStringToString(
  IN OUT PSTRING Destination,
  IN const STRING *Source);

NTSYSAPI
NTSTATUS
NTAPI
RtlOemStringToUnicodeString(
  IN OUT PUNICODE_STRING DestinationString,
  IN PCOEM_STRING SourceString,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeStringToOemString(
  IN OUT POEM_STRING DestinationString,
  IN PCUNICODE_STRING SourceString,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUpcaseUnicodeStringToOemString(
  IN OUT POEM_STRING DestinationString,
  IN PCUNICODE_STRING SourceString,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
NTSTATUS
NTAPI
RtlOemStringToCountedUnicodeString(
  IN OUT PUNICODE_STRING DestinationString,
  IN PCOEM_STRING SourceString,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeStringToCountedOemString(
  IN OUT POEM_STRING DestinationString,
  IN PCUNICODE_STRING SourceString,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUpcaseUnicodeStringToCountedOemString(
  IN OUT POEM_STRING DestinationString,
  IN PCUNICODE_STRING SourceString,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
NTSTATUS
NTAPI
RtlDowncaseUnicodeString(
  IN OUT PUNICODE_STRING UniDest,
  IN PCUNICODE_STRING UniSource,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
VOID
NTAPI
RtlFreeOemString (
  IN OUT POEM_STRING OemString);

NTSYSAPI
ULONG
NTAPI
RtlxUnicodeStringToOemSize(
  IN PCUNICODE_STRING UnicodeString);

NTSYSAPI
ULONG
NTAPI
RtlxOemStringToUnicodeSize(
  IN PCOEM_STRING OemString);

NTSYSAPI
NTSTATUS
NTAPI
RtlMultiByteToUnicodeN(
  OUT PWCH UnicodeString,
  IN ULONG MaxBytesInUnicodeString,
  OUT PULONG BytesInUnicodeString OPTIONAL,
  IN const CHAR *MultiByteString,
  IN ULONG BytesInMultiByteString);

NTSYSAPI
NTSTATUS
NTAPI
RtlMultiByteToUnicodeSize(
  OUT PULONG BytesInUnicodeString,
  IN const CHAR *MultiByteString,
  IN ULONG BytesInMultiByteString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeToMultiByteSize(
  OUT PULONG BytesInMultiByteString,
  IN PCWCH UnicodeString,
  IN ULONG BytesInUnicodeString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeToMultiByteN(
  OUT PCHAR MultiByteString,
  IN ULONG MaxBytesInMultiByteString,
  OUT PULONG BytesInMultiByteString OPTIONAL,
  IN PCWCH UnicodeString,
  IN ULONG BytesInUnicodeString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUpcaseUnicodeToMultiByteN(
  OUT PCHAR MultiByteString,
  IN ULONG MaxBytesInMultiByteString,
  OUT PULONG BytesInMultiByteString OPTIONAL,
  IN PCWCH UnicodeString,
  IN ULONG BytesInUnicodeString);

NTSYSAPI
NTSTATUS
NTAPI
RtlOemToUnicodeN(
  OUT PWSTR UnicodeString,
  IN ULONG MaxBytesInUnicodeString,
  OUT PULONG BytesInUnicodeString OPTIONAL,
  IN PCCH OemString,
  IN ULONG BytesInOemString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeToOemN(
  OUT PCHAR OemString,
  IN ULONG MaxBytesInOemString,
  OUT PULONG BytesInOemString OPTIONAL,
  IN PCWCH UnicodeString,
  IN ULONG BytesInUnicodeString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUpcaseUnicodeToOemN(
  OUT PCHAR OemString,
  IN ULONG MaxBytesInOemString,
  OUT PULONG BytesInOemString OPTIONAL,
  IN PCWCH UnicodeString,
  IN ULONG BytesInUnicodeString);

#if (NTDDI_VERSION >= NTDDI_VISTASP1)
NTSYSAPI
NTSTATUS
NTAPI
RtlGenerate8dot3Name(
  IN PCUNICODE_STRING Name,
  IN BOOLEAN AllowExtendedCharacters,
  IN OUT PGENERATE_NAME_CONTEXT Context,
  IN OUT PUNICODE_STRING Name8dot3);
#else
NTSYSAPI
VOID
NTAPI
RtlGenerate8dot3Name(
  IN PCUNICODE_STRING Name,
  IN BOOLEAN AllowExtendedCharacters,
  IN OUT PGENERATE_NAME_CONTEXT Context,
  IN OUT PUNICODE_STRING Name8dot3);
#endif

NTSYSAPI
BOOLEAN
NTAPI
RtlIsNameLegalDOS8Dot3(
  IN PCUNICODE_STRING Name,
  IN OUT POEM_STRING OemName OPTIONAL,
  IN OUT PBOOLEAN NameContainsSpaces OPTIONAL);

NTSYSAPI
BOOLEAN
NTAPI
RtlIsValidOemCharacter(
  IN OUT PWCHAR Char);

NTSYSAPI
VOID
NTAPI
PfxInitialize(
  OUT PPREFIX_TABLE PrefixTable);

NTSYSAPI
BOOLEAN
NTAPI
PfxInsertPrefix(
  IN PPREFIX_TABLE PrefixTable,
  IN PSTRING Prefix,
  OUT PPREFIX_TABLE_ENTRY PrefixTableEntry);

NTSYSAPI
VOID
NTAPI
PfxRemovePrefix(
  IN PPREFIX_TABLE PrefixTable,
  IN PPREFIX_TABLE_ENTRY PrefixTableEntry);

NTSYSAPI
PPREFIX_TABLE_ENTRY
NTAPI
PfxFindPrefix(
  IN PPREFIX_TABLE PrefixTable,
  IN PSTRING FullName);

NTSYSAPI
VOID
NTAPI
RtlInitializeUnicodePrefix(
  OUT PUNICODE_PREFIX_TABLE PrefixTable);

NTSYSAPI
BOOLEAN
NTAPI
RtlInsertUnicodePrefix(
  IN PUNICODE_PREFIX_TABLE PrefixTable,
  IN PUNICODE_STRING Prefix,
  OUT PUNICODE_PREFIX_TABLE_ENTRY PrefixTableEntry);

NTSYSAPI
VOID
NTAPI
RtlRemoveUnicodePrefix(
  IN PUNICODE_PREFIX_TABLE PrefixTable,
  IN PUNICODE_PREFIX_TABLE_ENTRY PrefixTableEntry);

NTSYSAPI
PUNICODE_PREFIX_TABLE_ENTRY
NTAPI
RtlFindUnicodePrefix(
  IN PUNICODE_PREFIX_TABLE PrefixTable,
  IN PUNICODE_STRING FullName,
  IN ULONG CaseInsensitiveIndex);

NTSYSAPI
PUNICODE_PREFIX_TABLE_ENTRY
NTAPI
RtlNextUnicodePrefix(
  IN PUNICODE_PREFIX_TABLE PrefixTable,
  IN BOOLEAN Restart);

NTSYSAPI
SIZE_T
NTAPI
RtlCompareMemoryUlong(
  IN PVOID Source,
  IN SIZE_T Length,
  IN ULONG Pattern);

NTSYSAPI
BOOLEAN
NTAPI
RtlTimeToSecondsSince1980(
  IN PLARGE_INTEGER Time,
  OUT PULONG ElapsedSeconds);

NTSYSAPI
VOID
NTAPI
RtlSecondsSince1980ToTime(
  IN ULONG ElapsedSeconds,
  OUT PLARGE_INTEGER Time);

NTSYSAPI
BOOLEAN
NTAPI
RtlTimeToSecondsSince1970(
  IN PLARGE_INTEGER Time,
  OUT PULONG ElapsedSeconds);

NTSYSAPI
VOID
NTAPI
RtlSecondsSince1970ToTime(
  IN ULONG ElapsedSeconds,
  OUT PLARGE_INTEGER Time);

NTSYSAPI
BOOLEAN
NTAPI
RtlValidSid(
  IN PSID Sid);

NTSYSAPI
BOOLEAN
NTAPI
RtlEqualSid(
  IN PSID Sid1,
  IN PSID Sid2);

NTSYSAPI
BOOLEAN
NTAPI
RtlEqualPrefixSid(
  IN PSID Sid1,
  IN PSID Sid2);

NTSYSAPI
ULONG
NTAPI
RtlLengthRequiredSid(
  IN ULONG SubAuthorityCount);

NTSYSAPI
PVOID
NTAPI
RtlFreeSid(
  IN PSID Sid);

NTSYSAPI
NTSTATUS
NTAPI
RtlAllocateAndInitializeSid(
  IN PSID_IDENTIFIER_AUTHORITY IdentifierAuthority,
  IN UCHAR SubAuthorityCount,
  IN ULONG SubAuthority0,
  IN ULONG SubAuthority1,
  IN ULONG SubAuthority2,
  IN ULONG SubAuthority3,
  IN ULONG SubAuthority4,
  IN ULONG SubAuthority5,
  IN ULONG SubAuthority6,
  IN ULONG SubAuthority7,
  OUT PSID *Sid);

NTSYSAPI
NTSTATUS
NTAPI
RtlInitializeSid(
  OUT PSID Sid,
  IN PSID_IDENTIFIER_AUTHORITY IdentifierAuthority,
  IN UCHAR SubAuthorityCount);

NTSYSAPI
PULONG
NTAPI
RtlSubAuthoritySid(
  IN PSID Sid,
  IN ULONG SubAuthority);

NTSYSAPI
ULONG
NTAPI
RtlLengthSid(
  IN PSID Sid);

NTSYSAPI
NTSTATUS
NTAPI
RtlCopySid(
  IN ULONG Length,
  IN PSID Destination,
  IN PSID Source);

NTSYSAPI
NTSTATUS
NTAPI
RtlConvertSidToUnicodeString(
  IN OUT PUNICODE_STRING UnicodeString,
  IN PSID Sid,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
VOID
NTAPI
RtlCopyLuid(
  OUT PLUID DestinationLuid,
  IN PLUID SourceLuid);

NTSYSAPI
NTSTATUS
NTAPI
RtlCreateAcl(
  OUT PACL Acl,
  IN ULONG AclLength,
  IN ULONG AclRevision);

NTSYSAPI
NTSTATUS
NTAPI
RtlAddAce(
  IN OUT PACL Acl,
  IN ULONG AceRevision,
  IN ULONG StartingAceIndex,
  IN PVOID AceList,
  IN ULONG AceListLength);

NTSYSAPI
NTSTATUS
NTAPI
RtlDeleteAce(
  IN OUT PACL Acl,
  IN ULONG AceIndex);

NTSYSAPI
NTSTATUS
NTAPI
RtlGetAce(
  IN PACL Acl,
  IN ULONG AceIndex,
  OUT PVOID *Ace);

NTSYSAPI
NTSTATUS
NTAPI
RtlAddAccessAllowedAce(
  IN OUT PACL Acl,
  IN ULONG AceRevision,
  IN ACCESS_MASK AccessMask,
  IN PSID Sid);

NTSYSAPI
NTSTATUS
NTAPI
RtlAddAccessAllowedAceEx(
  IN OUT PACL Acl,
  IN ULONG AceRevision,
  IN ULONG AceFlags,
  IN ACCESS_MASK AccessMask,
  IN PSID Sid);

NTSYSAPI
NTSTATUS
NTAPI
RtlCreateSecurityDescriptorRelative(
  OUT PISECURITY_DESCRIPTOR_RELATIVE SecurityDescriptor,
  IN ULONG Revision);

NTSYSAPI
NTSTATUS
NTAPI
RtlGetDaclSecurityDescriptor(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  OUT PBOOLEAN DaclPresent,
  OUT PACL *Dacl,
  OUT PBOOLEAN DaclDefaulted);

NTSYSAPI
NTSTATUS
NTAPI
RtlSetOwnerSecurityDescriptor(
  IN OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSID Owner OPTIONAL,
  IN BOOLEAN OwnerDefaulted);

NTSYSAPI
NTSTATUS
NTAPI
RtlGetOwnerSecurityDescriptor(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  OUT PSID *Owner,
  OUT PBOOLEAN OwnerDefaulted);

NTSYSAPI
ULONG
NTAPI
RtlNtStatusToDosError(
  IN NTSTATUS Status);

NTSYSAPI
NTSTATUS
NTAPI
RtlCustomCPToUnicodeN(
  IN PCPTABLEINFO CustomCP,
  OUT PWCH UnicodeString,
  IN ULONG MaxBytesInUnicodeString,
  OUT PULONG BytesInUnicodeString OPTIONAL,
  IN PCH CustomCPString,
  IN ULONG BytesInCustomCPString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeToCustomCPN(
  IN PCPTABLEINFO CustomCP,
  OUT PCH CustomCPString,
  IN ULONG MaxBytesInCustomCPString,
  OUT PULONG BytesInCustomCPString OPTIONAL,
  IN PWCH UnicodeString,
  IN ULONG BytesInUnicodeString);

NTSYSAPI
NTSTATUS
NTAPI
RtlUpcaseUnicodeToCustomCPN(
  IN PCPTABLEINFO CustomCP,
  OUT PCH CustomCPString,
  IN ULONG MaxBytesInCustomCPString,
  OUT PULONG BytesInCustomCPString OPTIONAL,
  IN PWCH UnicodeString,
  IN ULONG BytesInUnicodeString);

NTSYSAPI
VOID
NTAPI
RtlInitCodePageTable(
  IN PUSHORT TableBase,
  IN OUT PCPTABLEINFO CodePageTable);


#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */


#if (NTDDI_VERSION >= NTDDI_WINXP)

NTSYSAPI
PVOID
NTAPI
RtlCreateHeap(
  IN ULONG Flags,
  IN PVOID HeapBase OPTIONAL,
  IN SIZE_T ReserveSize OPTIONAL,
  IN SIZE_T CommitSize OPTIONAL,
  IN PVOID Lock OPTIONAL,
  IN PRTL_HEAP_PARAMETERS Parameters OPTIONAL);

NTSYSAPI
PVOID
NTAPI
RtlDestroyHeap(
  IN PVOID HeapHandle);

NTSYSAPI
USHORT
NTAPI
RtlCaptureStackBackTrace(
  IN ULONG FramesToSkip,
  IN ULONG FramesToCapture,
  OUT PVOID *BackTrace,
  OUT PULONG BackTraceHash OPTIONAL);

NTSYSAPI
ULONG
NTAPI
RtlRandomEx(
  IN OUT PULONG Seed);

NTSYSAPI
NTSTATUS
NTAPI
RtlInitUnicodeStringEx(
  OUT PUNICODE_STRING DestinationString,
  IN PCWSTR SourceString OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
RtlValidateUnicodeString(
  IN ULONG Flags,
  IN PCUNICODE_STRING String);

NTSYSAPI
NTSTATUS
NTAPI
RtlDuplicateUnicodeString(
  IN ULONG Flags,
  IN PCUNICODE_STRING SourceString,
  OUT PUNICODE_STRING DestinationString);

NTSYSAPI
NTSTATUS
NTAPI
RtlGetCompressionWorkSpaceSize(
  IN USHORT CompressionFormatAndEngine,
  OUT PULONG CompressBufferWorkSpaceSize,
  OUT PULONG CompressFragmentWorkSpaceSize);

NTSYSAPI
NTSTATUS
NTAPI
RtlCompressBuffer(
  IN USHORT CompressionFormatAndEngine,
  IN PUCHAR UncompressedBuffer,
  IN ULONG UncompressedBufferSize,
  OUT PUCHAR CompressedBuffer,
  IN ULONG CompressedBufferSize,
  IN ULONG UncompressedChunkSize,
  OUT PULONG FinalCompressedSize,
  IN PVOID WorkSpace);

NTSYSAPI
NTSTATUS
NTAPI
RtlDecompressBuffer(
  IN USHORT CompressionFormat,
  OUT PUCHAR UncompressedBuffer,
  IN ULONG UncompressedBufferSize,
  IN PUCHAR CompressedBuffer,
  IN ULONG CompressedBufferSize,
  OUT PULONG FinalUncompressedSize);

NTSYSAPI
NTSTATUS
NTAPI
RtlDecompressFragment(
  IN USHORT CompressionFormat,
  OUT PUCHAR UncompressedFragment,
  IN ULONG UncompressedFragmentSize,
  IN PUCHAR CompressedBuffer,
  IN ULONG CompressedBufferSize,
  IN ULONG FragmentOffset,
  OUT PULONG FinalUncompressedSize,
  IN PVOID WorkSpace);

NTSYSAPI
NTSTATUS
NTAPI
RtlDescribeChunk(
  IN USHORT CompressionFormat,
  IN OUT PUCHAR *CompressedBuffer,
  IN PUCHAR EndOfCompressedBufferPlus1,
  OUT PUCHAR *ChunkBuffer,
  OUT PULONG ChunkSize);

NTSYSAPI
NTSTATUS
NTAPI
RtlReserveChunk(
  IN USHORT CompressionFormat,
  IN OUT PUCHAR *CompressedBuffer,
  IN PUCHAR EndOfCompressedBufferPlus1,
  OUT PUCHAR *ChunkBuffer,
  IN ULONG ChunkSize);

NTSYSAPI
NTSTATUS
NTAPI
RtlDecompressChunks(
  OUT PUCHAR UncompressedBuffer,
  IN ULONG UncompressedBufferSize,
  IN PUCHAR CompressedBuffer,
  IN ULONG CompressedBufferSize,
  IN PUCHAR CompressedTail,
  IN ULONG CompressedTailSize,
  IN PCOMPRESSED_DATA_INFO CompressedDataInfo);

NTSYSAPI
NTSTATUS
NTAPI
RtlCompressChunks(
  IN PUCHAR UncompressedBuffer,
  IN ULONG UncompressedBufferSize,
  OUT PUCHAR CompressedBuffer,
  IN ULONG CompressedBufferSize,
  IN OUT PCOMPRESSED_DATA_INFO CompressedDataInfo,
  IN ULONG CompressedDataInfoLength,
  IN PVOID WorkSpace);

NTSYSAPI
PSID_IDENTIFIER_AUTHORITY
NTAPI
RtlIdentifierAuthoritySid(
  IN PSID Sid);

NTSYSAPI
PUCHAR
NTAPI
RtlSubAuthorityCountSid(
  IN PSID Sid);

NTSYSAPI
ULONG
NTAPI
RtlNtStatusToDosErrorNoTeb(
  IN NTSTATUS Status);

NTSYSAPI
NTSTATUS
NTAPI
RtlCreateSystemVolumeInformationFolder(
  IN PCUNICODE_STRING VolumeRootPath);

#if defined(_M_AMD64)

FORCEINLINE
VOID
RtlFillMemoryUlong (
  OUT PVOID Destination,
  IN SIZE_T Length,
  IN ULONG Pattern)
{
  PULONG Address = (PULONG)Destination;
  if ((Length /= 4) != 0) {
    if (((ULONG64)Address & 4) != 0) {
      *Address = Pattern;
      if ((Length -= 1) == 0) {
        return;
      }
      Address += 1;
    }
    __stosq((PULONG64)(Address), Pattern | ((ULONG64)Pattern << 32), Length / 2);
    if ((Length & 1) != 0) Address[Length - 1] = Pattern;
  }
  return;
}

#define RtlFillMemoryUlonglong(Destination, Length, Pattern)                \
    __stosq((PULONG64)(Destination), Pattern, (Length) / 8)

#else

NTSYSAPI
VOID
NTAPI
RtlFillMemoryUlong(
  OUT PVOID Destination,
  IN SIZE_T Length,
  IN ULONG Pattern);

NTSYSAPI
VOID
NTAPI
RtlFillMemoryUlonglong(
  OUT PVOID Destination,
  IN SIZE_T Length,
  IN ULONGLONG Pattern);

#endif /* defined(_M_AMD64) */

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WS03)
NTSYSAPI
NTSTATUS
NTAPI
RtlInitAnsiStringEx(
  OUT PANSI_STRING DestinationString,
  IN PCSZ SourceString OPTIONAL);
#endif

#if (NTDDI_VERSION >= NTDDI_WS03SP1)

NTSYSAPI
NTSTATUS
NTAPI
RtlGetSaclSecurityDescriptor(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  OUT PBOOLEAN SaclPresent,
  OUT PACL *Sacl,
  OUT PBOOLEAN SaclDefaulted);

NTSYSAPI
NTSTATUS
NTAPI
RtlSetGroupSecurityDescriptor(
  IN OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSID Group OPTIONAL,
  IN BOOLEAN GroupDefaulted OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
RtlGetGroupSecurityDescriptor(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  OUT PSID *Group,
  OUT PBOOLEAN GroupDefaulted);

NTSYSAPI
NTSTATUS
NTAPI
RtlAbsoluteToSelfRelativeSD(
  IN PSECURITY_DESCRIPTOR AbsoluteSecurityDescriptor,
  OUT PSECURITY_DESCRIPTOR SelfRelativeSecurityDescriptor OPTIONAL,
  IN OUT PULONG BufferLength);

NTSYSAPI
NTSTATUS
NTAPI
RtlSelfRelativeToAbsoluteSD(
  IN PSECURITY_DESCRIPTOR SelfRelativeSecurityDescriptor,
  OUT PSECURITY_DESCRIPTOR AbsoluteSecurityDescriptor OPTIONAL,
  IN OUT PULONG AbsoluteSecurityDescriptorSize,
  OUT PACL Dacl OPTIONAL,
  IN OUT PULONG DaclSize,
  OUT PACL Sacl OPTIONAL,
  IN OUT PULONG SaclSize,
  OUT PSID Owner OPTIONAL,
  IN OUT PULONG OwnerSize,
  OUT PSID PrimaryGroup OPTIONAL,
  IN OUT PULONG PrimaryGroupSize);

#endif /* (NTDDI_VERSION >= NTDDI_WS03SP1) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTSYSAPI
NTSTATUS
NTAPI
RtlNormalizeString(
  IN ULONG NormForm,
  IN PCWSTR SourceString,
  IN LONG SourceStringLength,
  OUT PWSTR DestinationString,
  IN OUT PLONG DestinationStringLength);

NTSYSAPI
NTSTATUS
NTAPI
RtlIsNormalizedString(
  IN ULONG NormForm,
  IN PCWSTR SourceString,
  IN LONG SourceStringLength,
  OUT PBOOLEAN Normalized);

NTSYSAPI
NTSTATUS
NTAPI
RtlIdnToAscii(
  IN ULONG Flags,
  IN PCWSTR SourceString,
  IN LONG SourceStringLength,
  OUT PWSTR DestinationString,
  IN OUT PLONG DestinationStringLength);

NTSYSAPI
NTSTATUS
NTAPI
RtlIdnToUnicode(
  IN ULONG Flags,
  IN PCWSTR SourceString,
  IN LONG SourceStringLength,
  OUT PWSTR DestinationString,
  IN OUT PLONG DestinationStringLength);

NTSYSAPI
NTSTATUS
NTAPI
RtlIdnToNameprepUnicode(
  IN ULONG Flags,
  IN PCWSTR SourceString,
  IN LONG SourceStringLength,
  OUT PWSTR DestinationString,
  IN OUT PLONG DestinationStringLength);

NTSYSAPI
NTSTATUS
NTAPI
RtlCreateServiceSid(
  IN PUNICODE_STRING ServiceName,
  OUT PSID ServiceSid,
  IN OUT PULONG ServiceSidLength);

NTSYSAPI
LONG
NTAPI
RtlCompareAltitudes(
  IN PCUNICODE_STRING Altitude1,
  IN PCUNICODE_STRING Altitude2);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeToUTF8N(
  OUT PCHAR UTF8StringDestination,
  IN ULONG UTF8StringMaxByteCount,
  OUT PULONG UTF8StringActualByteCount,
  IN PCWCH UnicodeStringSource,
  IN ULONG UnicodeStringByteCount);

NTSYSAPI
NTSTATUS
NTAPI
RtlUTF8ToUnicodeN(
  OUT PWSTR UnicodeStringDestination,
  IN ULONG UnicodeStringMaxByteCount,
  OUT PULONG UnicodeStringActualByteCount,
  IN PCCH UTF8StringSource,
  IN ULONG UTF8StringByteCount);

NTSYSAPI
NTSTATUS
NTAPI
RtlReplaceSidInSd(
  IN OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSID OldSid,
  IN PSID NewSid,
  OUT ULONG *NumChanges);

NTSYSAPI
NTSTATUS
NTAPI
RtlCreateVirtualAccountSid(
  IN PCUNICODE_STRING Name,
  IN ULONG BaseSubAuthority,
  OUT PSID Sid,
  IN OUT PULONG SidLength);

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */


#if defined(_AMD64_) || defined(_IA64_)


#endif /* defined(_AMD64_) || defined(_IA64_) */



#define RTL_DUPLICATE_UNICODE_STRING_NULL_TERMINATE 1
#define RTL_DUPLICATE_UNICODE_STRING_ALLOCATE_NULL_STRING 2

#define RtlUnicodeStringToOemSize(STRING) (NLS_MB_OEM_CODE_PAGE_TAG ?                                \
                                           RtlxUnicodeStringToOemSize(STRING) :                      \
                                           ((STRING)->Length + sizeof(UNICODE_NULL)) / sizeof(WCHAR) \
)

#define RtlOemStringToUnicodeSize(STRING) (                 \
    NLS_MB_OEM_CODE_PAGE_TAG ?                              \
    RtlxOemStringToUnicodeSize(STRING) :                    \
    ((STRING)->Length + sizeof(ANSI_NULL)) * sizeof(WCHAR)  \
)

#define RtlOemStringToCountedUnicodeSize(STRING) (                    \
    (ULONG)(RtlOemStringToUnicodeSize(STRING) - sizeof(UNICODE_NULL)) \
)

#define RtlOffsetToPointer(B,O) ((PCHAR)(((PCHAR)(B)) + ((ULONG_PTR)(O))))
#define RtlPointerToOffset(B,P) ((ULONG)(((PCHAR)(P)) - ((PCHAR)(B))))

typedef enum _OBJECT_INFORMATION_CLASS {
  ObjectBasicInformation = 0,
  ObjectNameInformation = 1, /* FIXME, not in WDK */
  ObjectTypeInformation = 2,
  ObjectTypesInformation = 3, /* FIXME, not in WDK */
  ObjectHandleFlagInformation = 4, /* FIXME, not in WDK */
  ObjectSessionInformation = 5, /* FIXME, not in WDK */
  MaxObjectInfoClass /* FIXME, not in WDK */
} OBJECT_INFORMATION_CLASS;

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryObject(
  IN HANDLE Handle OPTIONAL,
  IN OBJECT_INFORMATION_CLASS ObjectInformationClass,
  OUT PVOID ObjectInformation OPTIONAL,
  IN ULONG ObjectInformationLength,
  OUT PULONG ReturnLength OPTIONAL);

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenThreadToken(
  IN HANDLE ThreadHandle,
  IN ACCESS_MASK DesiredAccess,
  IN BOOLEAN OpenAsSelf,
  OUT PHANDLE TokenHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenProcessToken(
  IN HANDLE ProcessHandle,
  IN ACCESS_MASK DesiredAccess,
  OUT PHANDLE TokenHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryInformationToken(
  IN HANDLE TokenHandle,
  IN TOKEN_INFORMATION_CLASS TokenInformationClass,
  OUT PVOID TokenInformation OPTIONAL,
  IN ULONG TokenInformationLength,
  OUT PULONG ReturnLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtAdjustPrivilegesToken(
  IN HANDLE TokenHandle,
  IN BOOLEAN DisableAllPrivileges,
  IN PTOKEN_PRIVILEGES NewState OPTIONAL,
  IN ULONG BufferLength,
  OUT PTOKEN_PRIVILEGES PreviousState,
  OUT PULONG ReturnLength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCreateFile(
  OUT PHANDLE FileHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PLARGE_INTEGER AllocationSize OPTIONAL,
  IN ULONG FileAttributes,
  IN ULONG ShareAccess,
  IN ULONG CreateDisposition,
  IN ULONG CreateOptions,
  IN PVOID EaBuffer,
  IN ULONG EaLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtDeviceIoControlFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN ULONG IoControlCode,
  IN PVOID InputBuffer OPTIONAL,
  IN ULONG InputBufferLength,
  OUT PVOID OutputBuffer OPTIONAL,
  IN ULONG OutputBufferLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtFsControlFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN ULONG FsControlCode,
  IN PVOID InputBuffer OPTIONAL,
  IN ULONG InputBufferLength,
  OUT PVOID OutputBuffer OPTIONAL,
  IN ULONG OutputBufferLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtLockFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PLARGE_INTEGER ByteOffset,
  IN PLARGE_INTEGER Length,
  IN ULONG Key,
  IN BOOLEAN FailImmediately,
  IN BOOLEAN ExclusiveLock);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenFile(
  OUT PHANDLE FileHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN ULONG ShareAccess,
  IN ULONG OpenOptions);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryDirectoryFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID FileInformation,
  IN ULONG Length,
  IN FILE_INFORMATION_CLASS FileInformationClass,
  IN BOOLEAN ReturnSingleEntry,
  IN PUNICODE_STRING FileName OPTIONAL,
  IN BOOLEAN RestartScan);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID FileInformation,
  IN ULONG Length,
  IN FILE_INFORMATION_CLASS FileInformationClass);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryQuotaInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID Buffer,
  IN ULONG Length,
  IN BOOLEAN ReturnSingleEntry,
  IN PVOID SidList,
  IN ULONG SidListLength,
  IN PSID StartSid OPTIONAL,
  IN BOOLEAN RestartScan);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryVolumeInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID FsInformation,
  IN ULONG Length,
  IN FS_INFORMATION_CLASS FsInformationClass);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtReadFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID Buffer,
  IN ULONG Length,
  IN PLARGE_INTEGER ByteOffset OPTIONAL,
  IN PULONG Key OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PVOID FileInformation,
  IN ULONG Length,
  IN FILE_INFORMATION_CLASS FileInformationClass);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetQuotaInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PVOID Buffer,
  IN ULONG Length);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetVolumeInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PVOID FsInformation,
  IN ULONG Length,
  IN FS_INFORMATION_CLASS FsInformationClass);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtWriteFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PVOID Buffer,
  IN ULONG Length,
  IN PLARGE_INTEGER ByteOffset OPTIONAL,
  IN PULONG Key OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtUnlockFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PLARGE_INTEGER ByteOffset,
  IN PLARGE_INTEGER Length,
  IN ULONG Key);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetSecurityObject(
  IN HANDLE Handle,
  IN SECURITY_INFORMATION SecurityInformation,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQuerySecurityObject(
  IN HANDLE Handle,
  IN SECURITY_INFORMATION SecurityInformation,
  OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN ULONG Length,
  OUT PULONG LengthNeeded);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtClose(
  IN HANDLE Handle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtAllocateVirtualMemory(
  IN HANDLE ProcessHandle,
  IN OUT PVOID *BaseAddress,
  IN ULONG_PTR ZeroBits,
  IN OUT PSIZE_T RegionSize,
  IN ULONG AllocationType,
  IN ULONG Protect);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtFreeVirtualMemory(
  IN HANDLE ProcessHandle,
  IN OUT PVOID *BaseAddress,
  IN OUT PSIZE_T RegionSize,
  IN ULONG FreeType);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenThreadTokenEx(
  IN HANDLE ThreadHandle,
  IN ACCESS_MASK DesiredAccess,
  IN BOOLEAN OpenAsSelf,
  IN ULONG HandleAttributes,
  OUT PHANDLE TokenHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenProcessTokenEx(
  IN HANDLE ProcessHandle,
  IN ACCESS_MASK DesiredAccess,
  IN ULONG HandleAttributes,
  OUT PHANDLE TokenHandle);

NTSYSAPI
NTSTATUS
NTAPI
NtOpenJobObjectToken(
  IN HANDLE JobHandle,
  IN ACCESS_MASK DesiredAccess,
  OUT PHANDLE TokenHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtDuplicateToken(
  IN HANDLE ExistingTokenHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN BOOLEAN EffectiveOnly,
  IN TOKEN_TYPE TokenType,
  OUT PHANDLE NewTokenHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtFilterToken(
  IN HANDLE ExistingTokenHandle,
  IN ULONG Flags,
  IN PTOKEN_GROUPS SidsToDisable OPTIONAL,
  IN PTOKEN_PRIVILEGES PrivilegesToDelete OPTIONAL,
  IN PTOKEN_GROUPS RestrictedSids OPTIONAL,
  OUT PHANDLE NewTokenHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtImpersonateAnonymousToken(
  IN HANDLE ThreadHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetInformationToken(
  IN HANDLE TokenHandle,
  IN TOKEN_INFORMATION_CLASS TokenInformationClass,
  IN PVOID TokenInformation,
  IN ULONG TokenInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtAdjustGroupsToken(
  IN HANDLE TokenHandle,
  IN BOOLEAN ResetToDefault,
  IN PTOKEN_GROUPS NewState OPTIONAL,
  IN ULONG BufferLength OPTIONAL,
  OUT PTOKEN_GROUPS PreviousState,
  OUT PULONG ReturnLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPrivilegeCheck(
  IN HANDLE ClientToken,
  IN OUT PPRIVILEGE_SET RequiredPrivileges,
  OUT PBOOLEAN Result);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtAccessCheckAndAuditAlarm(
  IN PUNICODE_STRING SubsystemName,
  IN PVOID HandleId OPTIONAL,
  IN PUNICODE_STRING ObjectTypeName,
  IN PUNICODE_STRING ObjectName,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN ACCESS_MASK DesiredAccess,
  IN PGENERIC_MAPPING GenericMapping,
  IN BOOLEAN ObjectCreation,
  OUT PACCESS_MASK GrantedAccess,
  OUT PNTSTATUS AccessStatus,
  OUT PBOOLEAN GenerateOnClose);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtAccessCheckByTypeAndAuditAlarm(
  IN PUNICODE_STRING SubsystemName,
  IN PVOID HandleId,
  IN PUNICODE_STRING ObjectTypeName,
  IN PUNICODE_STRING ObjectName,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSID PrincipalSelfSid OPTIONAL,
  IN ACCESS_MASK DesiredAccess,
  IN AUDIT_EVENT_TYPE AuditType,
  IN ULONG Flags,
  IN POBJECT_TYPE_LIST ObjectTypeList OPTIONAL,
  IN ULONG ObjectTypeLength,
  IN PGENERIC_MAPPING GenericMapping,
  IN BOOLEAN ObjectCreation,
  OUT PACCESS_MASK GrantedAccess,
  OUT PNTSTATUS AccessStatus,
  OUT PBOOLEAN GenerateOnClose);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtAccessCheckByTypeResultListAndAuditAlarm(
  IN PUNICODE_STRING SubsystemName,
  IN PVOID HandleId OPTIONAL,
  IN PUNICODE_STRING ObjectTypeName,
  IN PUNICODE_STRING ObjectName,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSID PrincipalSelfSid OPTIONAL,
  IN ACCESS_MASK DesiredAccess,
  IN AUDIT_EVENT_TYPE AuditType,
  IN ULONG Flags,
  IN POBJECT_TYPE_LIST ObjectTypeList OPTIONAL,
  IN ULONG ObjectTypeLength,
  IN PGENERIC_MAPPING GenericMapping,
  IN BOOLEAN ObjectCreation,
  OUT PACCESS_MASK GrantedAccess,
  OUT PNTSTATUS AccessStatus,
  OUT PBOOLEAN GenerateOnClose);

NTSTATUS
NTAPI
NtAccessCheckByTypeResultListAndAuditAlarmByHandle(
  IN PUNICODE_STRING SubsystemName,
  IN PVOID HandleId OPTIONAL,
  IN HANDLE ClientToken,
  IN PUNICODE_STRING ObjectTypeName,
  IN PUNICODE_STRING ObjectName,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSID PrincipalSelfSid OPTIONAL,
  IN ACCESS_MASK DesiredAccess,
  IN AUDIT_EVENT_TYPE AuditType,
  IN ULONG Flags,
  IN POBJECT_TYPE_LIST ObjectTypeList OPTIONAL,
  IN ULONG ObjectTypeLength,
  IN PGENERIC_MAPPING GenericMapping,
  IN BOOLEAN ObjectCreation,
  OUT PACCESS_MASK GrantedAccess,
  OUT PNTSTATUS AccessStatus,
  OUT PBOOLEAN GenerateOnClose);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenObjectAuditAlarm(
  IN PUNICODE_STRING SubsystemName,
  IN PVOID HandleId OPTIONAL,
  IN PUNICODE_STRING ObjectTypeName,
  IN PUNICODE_STRING ObjectName,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor OPTIONAL,
  IN HANDLE ClientToken,
  IN ACCESS_MASK DesiredAccess,
  IN ACCESS_MASK GrantedAccess,
  IN PPRIVILEGE_SET Privileges OPTIONAL,
  IN BOOLEAN ObjectCreation,
  IN BOOLEAN AccessGranted,
  OUT PBOOLEAN GenerateOnClose);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPrivilegeObjectAuditAlarm(
  IN PUNICODE_STRING SubsystemName,
  IN PVOID HandleId OPTIONAL,
  IN HANDLE ClientToken,
  IN ACCESS_MASK DesiredAccess,
  IN PPRIVILEGE_SET Privileges,
  IN BOOLEAN AccessGranted);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCloseObjectAuditAlarm(
  IN PUNICODE_STRING SubsystemName,
  IN PVOID HandleId OPTIONAL,
  IN BOOLEAN GenerateOnClose);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtDeleteObjectAuditAlarm(
  IN PUNICODE_STRING SubsystemName,
  IN PVOID HandleId OPTIONAL,
  IN BOOLEAN GenerateOnClose);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPrivilegedServiceAuditAlarm(
  IN PUNICODE_STRING SubsystemName,
  IN PUNICODE_STRING ServiceName,
  IN HANDLE ClientToken,
  IN PPRIVILEGE_SET Privileges,
  IN BOOLEAN AccessGranted);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetInformationThread(
  IN HANDLE ThreadHandle,
  IN THREADINFOCLASS ThreadInformationClass,
  IN PVOID ThreadInformation,
  IN ULONG ThreadInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCreateSection(
  OUT PHANDLE SectionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN PLARGE_INTEGER MaximumSize OPTIONAL,
  IN ULONG SectionPageProtection,
  IN ULONG AllocationAttributes,
  IN HANDLE FileHandle OPTIONAL);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#define COMPRESSION_FORMAT_NONE         (0x0000)
#define COMPRESSION_FORMAT_DEFAULT      (0x0001)
#define COMPRESSION_FORMAT_LZNT1        (0x0002)
#define COMPRESSION_ENGINE_STANDARD     (0x0000)
#define COMPRESSION_ENGINE_MAXIMUM      (0x0100)
#define COMPRESSION_ENGINE_HIBER        (0x0200)

#define MAX_UNICODE_STACK_BUFFER_LENGTH 256

#define METHOD_FROM_CTL_CODE(ctrlCode)  ((ULONG)(ctrlCode & 3))

#define METHOD_DIRECT_TO_HARDWARE       METHOD_IN_DIRECT
#define METHOD_DIRECT_FROM_HARDWARE     METHOD_OUT_DIRECT

typedef ULONG LSA_OPERATIONAL_MODE, *PLSA_OPERATIONAL_MODE;

typedef enum _SECURITY_LOGON_TYPE {
  UndefinedLogonType = 0,
  Interactive = 2,
  Network,
  Batch,
  Service,
  Proxy,
  Unlock,
  NetworkCleartext,
  NewCredentials,
#if (_WIN32_WINNT >= 0x0501)
  RemoteInteractive,
  CachedInteractive,
#endif
#if (_WIN32_WINNT >= 0x0502)
  CachedRemoteInteractive,
  CachedUnlock
#endif
} SECURITY_LOGON_TYPE, *PSECURITY_LOGON_TYPE;

#ifndef _NTLSA_AUDIT_
#define _NTLSA_AUDIT_

#ifndef GUID_DEFINED
#include <guiddef.h>
#endif

#endif /* _NTLSA_AUDIT_ */

NTSTATUS
NTAPI
LsaRegisterLogonProcess(
  IN PLSA_STRING LogonProcessName,
  OUT PHANDLE LsaHandle,
  OUT PLSA_OPERATIONAL_MODE SecurityMode);

NTSTATUS
NTAPI
LsaLogonUser(
  IN HANDLE LsaHandle,
  IN PLSA_STRING OriginName,
  IN SECURITY_LOGON_TYPE LogonType,
  IN ULONG AuthenticationPackage,
  IN PVOID AuthenticationInformation,
  IN ULONG AuthenticationInformationLength,
  IN PTOKEN_GROUPS LocalGroups OPTIONAL,
  IN PTOKEN_SOURCE SourceContext,
  OUT PVOID *ProfileBuffer,
  OUT PULONG ProfileBufferLength,
  OUT PLUID LogonId,
  OUT PHANDLE Token,
  OUT PQUOTA_LIMITS Quotas,
  OUT PNTSTATUS SubStatus);

NTSTATUS
NTAPI
LsaFreeReturnBuffer(
  IN PVOID Buffer);

#ifndef _NTLSA_IFS_
#define _NTLSA_IFS_
#endif

#define MSV1_0_PACKAGE_NAME     "MICROSOFT_AUTHENTICATION_PACKAGE_V1_0"
#define MSV1_0_PACKAGE_NAMEW    L"MICROSOFT_AUTHENTICATION_PACKAGE_V1_0"
#define MSV1_0_PACKAGE_NAMEW_LENGTH sizeof(MSV1_0_PACKAGE_NAMEW) - sizeof(WCHAR)

#define MSV1_0_SUBAUTHENTICATION_KEY "SYSTEM\\CurrentControlSet\\Control\\Lsa\\MSV1_0"
#define MSV1_0_SUBAUTHENTICATION_VALUE "Auth"

#define MSV1_0_CHALLENGE_LENGTH                8
#define MSV1_0_USER_SESSION_KEY_LENGTH         16
#define MSV1_0_LANMAN_SESSION_KEY_LENGTH       8

#define MSV1_0_CLEARTEXT_PASSWORD_ALLOWED      0x02
#define MSV1_0_UPDATE_LOGON_STATISTICS         0x04
#define MSV1_0_RETURN_USER_PARAMETERS          0x08
#define MSV1_0_DONT_TRY_GUEST_ACCOUNT          0x10
#define MSV1_0_ALLOW_SERVER_TRUST_ACCOUNT      0x20
#define MSV1_0_RETURN_PASSWORD_EXPIRY          0x40
#define MSV1_0_USE_CLIENT_CHALLENGE            0x80
#define MSV1_0_TRY_GUEST_ACCOUNT_ONLY          0x100
#define MSV1_0_RETURN_PROFILE_PATH             0x200
#define MSV1_0_TRY_SPECIFIED_DOMAIN_ONLY       0x400
#define MSV1_0_ALLOW_WORKSTATION_TRUST_ACCOUNT 0x800

#define MSV1_0_DISABLE_PERSONAL_FALLBACK     0x00001000
#define MSV1_0_ALLOW_FORCE_GUEST             0x00002000

#if (_WIN32_WINNT >= 0x0502)
#define MSV1_0_CLEARTEXT_PASSWORD_SUPPLIED   0x00004000
#define MSV1_0_USE_DOMAIN_FOR_ROUTING_ONLY   0x00008000
#endif

#define MSV1_0_SUBAUTHENTICATION_DLL_EX      0x00100000
#define MSV1_0_ALLOW_MSVCHAPV2               0x00010000

#if (_WIN32_WINNT >= 0x0600)
#define MSV1_0_S4U2SELF                      0x00020000
#define MSV1_0_CHECK_LOGONHOURS_FOR_S4U      0x00040000
#endif

#define MSV1_0_SUBAUTHENTICATION_DLL         0xFF000000
#define MSV1_0_SUBAUTHENTICATION_DLL_SHIFT   24
#define MSV1_0_MNS_LOGON                     0x01000000

#define MSV1_0_SUBAUTHENTICATION_DLL_RAS     2
#define MSV1_0_SUBAUTHENTICATION_DLL_IIS     132

#define LOGON_GUEST                 0x01
#define LOGON_NOENCRYPTION          0x02
#define LOGON_CACHED_ACCOUNT        0x04
#define LOGON_USED_LM_PASSWORD      0x08
#define LOGON_EXTRA_SIDS            0x20
#define LOGON_SUBAUTH_SESSION_KEY   0x40
#define LOGON_SERVER_TRUST_ACCOUNT  0x80
#define LOGON_NTLMV2_ENABLED        0x100
#define LOGON_RESOURCE_GROUPS       0x200
#define LOGON_PROFILE_PATH_RETURNED 0x400
#define LOGON_NT_V2                 0x800
#define LOGON_LM_V2                 0x1000
#define LOGON_NTLM_V2               0x2000

#if (_WIN32_WINNT >= 0x0600)

#define LOGON_OPTIMIZED             0x4000
#define LOGON_WINLOGON              0x8000
#define LOGON_PKINIT               0x10000
#define LOGON_NO_OPTIMIZED         0x20000

#endif

#define MSV1_0_SUBAUTHENTICATION_FLAGS 0xFF000000

#define LOGON_GRACE_LOGON              0x01000000

#define MSV1_0_OWF_PASSWORD_LENGTH 16
#define MSV1_0_CRED_LM_PRESENT 0x1
#define MSV1_0_CRED_NT_PRESENT 0x2
#define MSV1_0_CRED_VERSION 0

#define MSV1_0_NTLM3_RESPONSE_LENGTH 16
#define MSV1_0_NTLM3_OWF_LENGTH 16

#if (_WIN32_WINNT == 0x0500)
#define MSV1_0_MAX_NTLM3_LIFE 1800
#else
#define MSV1_0_MAX_NTLM3_LIFE 129600
#endif
#define MSV1_0_MAX_AVL_SIZE 64000

#if (_WIN32_WINNT >= 0x0501)

#define MSV1_0_AV_FLAG_FORCE_GUEST                  0x00000001

#if (_WIN32_WINNT >= 0x0600)
#define MSV1_0_AV_FLAG_MIC_HANDSHAKE_MESSAGES       0x00000002
#endif

#endif

#define MSV1_0_NTLM3_INPUT_LENGTH (sizeof(MSV1_0_NTLM3_RESPONSE) - MSV1_0_NTLM3_RESPONSE_LENGTH)

#if(_WIN32_WINNT >= 0x0502)
#define MSV1_0_NTLM3_MIN_NT_RESPONSE_LENGTH RTL_SIZEOF_THROUGH_FIELD(MSV1_0_NTLM3_RESPONSE, AvPairsOff)
#endif

#define USE_PRIMARY_PASSWORD            0x01
#define RETURN_PRIMARY_USERNAME         0x02
#define RETURN_PRIMARY_LOGON_DOMAINNAME 0x04
#define RETURN_NON_NT_USER_SESSION_KEY  0x08
#define GENERATE_CLIENT_CHALLENGE       0x10
#define GCR_NTLM3_PARMS                 0x20
#define GCR_TARGET_INFO                 0x40
#define RETURN_RESERVED_PARAMETER       0x80
#define GCR_ALLOW_NTLM                 0x100
#define GCR_USE_OEM_SET                0x200
#define GCR_MACHINE_CREDENTIAL         0x400
#define GCR_USE_OWF_PASSWORD           0x800
#define GCR_ALLOW_LM                  0x1000
#define GCR_ALLOW_NO_TARGET           0x2000

typedef enum _MSV1_0_LOGON_SUBMIT_TYPE {
  MsV1_0InteractiveLogon = 2,
  MsV1_0Lm20Logon,
  MsV1_0NetworkLogon,
  MsV1_0SubAuthLogon,
  MsV1_0WorkstationUnlockLogon = 7,
  MsV1_0S4ULogon = 12,
  MsV1_0VirtualLogon = 82
} MSV1_0_LOGON_SUBMIT_TYPE, *PMSV1_0_LOGON_SUBMIT_TYPE;

typedef enum _MSV1_0_PROFILE_BUFFER_TYPE {
  MsV1_0InteractiveProfile = 2,
  MsV1_0Lm20LogonProfile,
  MsV1_0SmartCardProfile
} MSV1_0_PROFILE_BUFFER_TYPE, *PMSV1_0_PROFILE_BUFFER_TYPE;

typedef struct _MSV1_0_INTERACTIVE_LOGON {
  MSV1_0_LOGON_SUBMIT_TYPE MessageType;
  UNICODE_STRING LogonDomainName;
  UNICODE_STRING UserName;
  UNICODE_STRING Password;
} MSV1_0_INTERACTIVE_LOGON, *PMSV1_0_INTERACTIVE_LOGON;

typedef struct _MSV1_0_INTERACTIVE_PROFILE {
  MSV1_0_PROFILE_BUFFER_TYPE MessageType;
  USHORT LogonCount;
  USHORT BadPasswordCount;
  LARGE_INTEGER LogonTime;
  LARGE_INTEGER LogoffTime;
  LARGE_INTEGER KickOffTime;
  LARGE_INTEGER PasswordLastSet;
  LARGE_INTEGER PasswordCanChange;
  LARGE_INTEGER PasswordMustChange;
  UNICODE_STRING LogonScript;
  UNICODE_STRING HomeDirectory;
  UNICODE_STRING FullName;
  UNICODE_STRING ProfilePath;
  UNICODE_STRING HomeDirectoryDrive;
  UNICODE_STRING LogonServer;
  ULONG UserFlags;
} MSV1_0_INTERACTIVE_PROFILE, *PMSV1_0_INTERACTIVE_PROFILE;

typedef struct _MSV1_0_LM20_LOGON {
  MSV1_0_LOGON_SUBMIT_TYPE MessageType;
  UNICODE_STRING LogonDomainName;
  UNICODE_STRING UserName;
  UNICODE_STRING Workstation;
  UCHAR ChallengeToClient[MSV1_0_CHALLENGE_LENGTH];
  STRING CaseSensitiveChallengeResponse;
  STRING CaseInsensitiveChallengeResponse;
  ULONG ParameterControl;
} MSV1_0_LM20_LOGON, * PMSV1_0_LM20_LOGON;

typedef struct _MSV1_0_SUBAUTH_LOGON {
  MSV1_0_LOGON_SUBMIT_TYPE MessageType;
  UNICODE_STRING LogonDomainName;
  UNICODE_STRING UserName;
  UNICODE_STRING Workstation;
  UCHAR ChallengeToClient[MSV1_0_CHALLENGE_LENGTH];
  STRING AuthenticationInfo1;
  STRING AuthenticationInfo2;
  ULONG ParameterControl;
  ULONG SubAuthPackageId;
} MSV1_0_SUBAUTH_LOGON, * PMSV1_0_SUBAUTH_LOGON;

#if (_WIN32_WINNT >= 0x0600)

#define MSV1_0_S4U_LOGON_FLAG_CHECK_LOGONHOURS 0x2

typedef struct _MSV1_0_S4U_LOGON {
  MSV1_0_LOGON_SUBMIT_TYPE MessageType;
  ULONG Flags;
  UNICODE_STRING UserPrincipalName;
  UNICODE_STRING DomainName;
} MSV1_0_S4U_LOGON, *PMSV1_0_S4U_LOGON;

#endif

typedef struct _MSV1_0_LM20_LOGON_PROFILE {
  MSV1_0_PROFILE_BUFFER_TYPE MessageType;
  LARGE_INTEGER KickOffTime;
  LARGE_INTEGER LogoffTime;
  ULONG UserFlags;
  UCHAR UserSessionKey[MSV1_0_USER_SESSION_KEY_LENGTH];
  UNICODE_STRING LogonDomainName;
  UCHAR LanmanSessionKey[MSV1_0_LANMAN_SESSION_KEY_LENGTH];
  UNICODE_STRING LogonServer;
  UNICODE_STRING UserParameters;
} MSV1_0_LM20_LOGON_PROFILE, * PMSV1_0_LM20_LOGON_PROFILE;

typedef struct _MSV1_0_SUPPLEMENTAL_CREDENTIAL {
  ULONG Version;
  ULONG Flags;
  UCHAR LmPassword[MSV1_0_OWF_PASSWORD_LENGTH];
  UCHAR NtPassword[MSV1_0_OWF_PASSWORD_LENGTH];
} MSV1_0_SUPPLEMENTAL_CREDENTIAL, *PMSV1_0_SUPPLEMENTAL_CREDENTIAL;

typedef struct _MSV1_0_NTLM3_RESPONSE {
  UCHAR Response[MSV1_0_NTLM3_RESPONSE_LENGTH];
  UCHAR RespType;
  UCHAR HiRespType;
  USHORT Flags;
  ULONG MsgWord;
  ULONGLONG TimeStamp;
  UCHAR ChallengeFromClient[MSV1_0_CHALLENGE_LENGTH];
  ULONG AvPairsOff;
  UCHAR Buffer[1];
} MSV1_0_NTLM3_RESPONSE, *PMSV1_0_NTLM3_RESPONSE;

typedef enum _MSV1_0_AVID {
  MsvAvEOL,
  MsvAvNbComputerName,
  MsvAvNbDomainName,
  MsvAvDnsComputerName,
  MsvAvDnsDomainName,
#if (_WIN32_WINNT >= 0x0501)
  MsvAvDnsTreeName,
  MsvAvFlags,
#if (_WIN32_WINNT >= 0x0600)
  MsvAvTimestamp,
  MsvAvRestrictions,
  MsvAvTargetName,
  MsvAvChannelBindings,
#endif
#endif
} MSV1_0_AVID;

typedef struct _MSV1_0_AV_PAIR {
  USHORT AvId;
  USHORT AvLen;
} MSV1_0_AV_PAIR, *PMSV1_0_AV_PAIR;

typedef enum _MSV1_0_PROTOCOL_MESSAGE_TYPE {
  MsV1_0Lm20ChallengeRequest = 0,
  MsV1_0Lm20GetChallengeResponse,
  MsV1_0EnumerateUsers,
  MsV1_0GetUserInfo,
  MsV1_0ReLogonUsers,
  MsV1_0ChangePassword,
  MsV1_0ChangeCachedPassword,
  MsV1_0GenericPassthrough,
  MsV1_0CacheLogon,
  MsV1_0SubAuth,
  MsV1_0DeriveCredential,
  MsV1_0CacheLookup,
#if (_WIN32_WINNT >= 0x0501)
  MsV1_0SetProcessOption,
#endif
#if (_WIN32_WINNT >= 0x0600)
  MsV1_0ConfigLocalAliases,
  MsV1_0ClearCachedCredentials,
#endif
} MSV1_0_PROTOCOL_MESSAGE_TYPE, *PMSV1_0_PROTOCOL_MESSAGE_TYPE;

typedef struct _MSV1_0_LM20_CHALLENGE_REQUEST {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
} MSV1_0_LM20_CHALLENGE_REQUEST, *PMSV1_0_LM20_CHALLENGE_REQUEST;

typedef struct _MSV1_0_LM20_CHALLENGE_RESPONSE {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
  UCHAR ChallengeToClient[MSV1_0_CHALLENGE_LENGTH];
} MSV1_0_LM20_CHALLENGE_RESPONSE, *PMSV1_0_LM20_CHALLENGE_RESPONSE;

typedef struct _MSV1_0_GETCHALLENRESP_REQUEST_V1 {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
  ULONG ParameterControl;
  LUID LogonId;
  UNICODE_STRING Password;
  UCHAR ChallengeToClient[MSV1_0_CHALLENGE_LENGTH];
} MSV1_0_GETCHALLENRESP_REQUEST_V1, *PMSV1_0_GETCHALLENRESP_REQUEST_V1;

typedef struct _MSV1_0_GETCHALLENRESP_REQUEST {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
  ULONG ParameterControl;
  LUID LogonId;
  UNICODE_STRING Password;
  UCHAR ChallengeToClient[MSV1_0_CHALLENGE_LENGTH];
  UNICODE_STRING UserName;
  UNICODE_STRING LogonDomainName;
  UNICODE_STRING ServerName;
} MSV1_0_GETCHALLENRESP_REQUEST, *PMSV1_0_GETCHALLENRESP_REQUEST;

typedef struct _MSV1_0_GETCHALLENRESP_RESPONSE {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
  STRING CaseSensitiveChallengeResponse;
  STRING CaseInsensitiveChallengeResponse;
  UNICODE_STRING UserName;
  UNICODE_STRING LogonDomainName;
  UCHAR UserSessionKey[MSV1_0_USER_SESSION_KEY_LENGTH];
  UCHAR LanmanSessionKey[MSV1_0_LANMAN_SESSION_KEY_LENGTH];
} MSV1_0_GETCHALLENRESP_RESPONSE, *PMSV1_0_GETCHALLENRESP_RESPONSE;

typedef struct _MSV1_0_ENUMUSERS_REQUEST {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
} MSV1_0_ENUMUSERS_REQUEST, *PMSV1_0_ENUMUSERS_REQUEST;

typedef struct _MSV1_0_ENUMUSERS_RESPONSE {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
  ULONG NumberOfLoggedOnUsers;
  PLUID LogonIds;
  PULONG EnumHandles;
} MSV1_0_ENUMUSERS_RESPONSE, *PMSV1_0_ENUMUSERS_RESPONSE;

typedef struct _MSV1_0_GETUSERINFO_REQUEST {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
  LUID LogonId;
} MSV1_0_GETUSERINFO_REQUEST, *PMSV1_0_GETUSERINFO_REQUEST;

typedef struct _MSV1_0_GETUSERINFO_RESPONSE {
  MSV1_0_PROTOCOL_MESSAGE_TYPE MessageType;
  PSID UserSid;
  UNICODE_STRING UserName;
  UNICODE_STRING LogonDomainName;
  UNICODE_STRING LogonServer;
  SECURITY_LOGON_TYPE LogonType;
} MSV1_0_GETUSERINFO_RESPONSE, *PMSV1_0_GETUSERINFO_RESPONSE;



#define FILE_OPLOCK_BROKEN_TO_LEVEL_2   0x00000007
#define FILE_OPLOCK_BROKEN_TO_NONE      0x00000008
#define FILE_OPBATCH_BREAK_UNDERWAY     0x00000009

/* also in winnt.h */
#define FILE_NOTIFY_CHANGE_FILE_NAME    0x00000001
#define FILE_NOTIFY_CHANGE_DIR_NAME     0x00000002
#define FILE_NOTIFY_CHANGE_NAME         0x00000003
#define FILE_NOTIFY_CHANGE_ATTRIBUTES   0x00000004
#define FILE_NOTIFY_CHANGE_SIZE         0x00000008
#define FILE_NOTIFY_CHANGE_LAST_WRITE   0x00000010
#define FILE_NOTIFY_CHANGE_LAST_ACCESS  0x00000020
#define FILE_NOTIFY_CHANGE_CREATION     0x00000040
#define FILE_NOTIFY_CHANGE_EA           0x00000080
#define FILE_NOTIFY_CHANGE_SECURITY     0x00000100
#define FILE_NOTIFY_CHANGE_STREAM_NAME  0x00000200
#define FILE_NOTIFY_CHANGE_STREAM_SIZE  0x00000400
#define FILE_NOTIFY_CHANGE_STREAM_WRITE 0x00000800
#define FILE_NOTIFY_VALID_MASK          0x00000fff

#define FILE_ACTION_ADDED                   0x00000001
#define FILE_ACTION_REMOVED                 0x00000002
#define FILE_ACTION_MODIFIED                0x00000003
#define FILE_ACTION_RENAMED_OLD_NAME        0x00000004
#define FILE_ACTION_RENAMED_NEW_NAME        0x00000005
#define FILE_ACTION_ADDED_STREAM            0x00000006
#define FILE_ACTION_REMOVED_STREAM          0x00000007
#define FILE_ACTION_MODIFIED_STREAM         0x00000008
#define FILE_ACTION_REMOVED_BY_DELETE       0x00000009
#define FILE_ACTION_ID_NOT_TUNNELLED        0x0000000A
#define FILE_ACTION_TUNNELLED_ID_COLLISION  0x0000000B
/* end  winnt.h */

#define FILE_PIPE_BYTE_STREAM_TYPE          0x00000000
#define FILE_PIPE_MESSAGE_TYPE              0x00000001

#define FILE_PIPE_ACCEPT_REMOTE_CLIENTS     0x00000000
#define FILE_PIPE_REJECT_REMOTE_CLIENTS     0x00000002

#define FILE_PIPE_TYPE_VALID_MASK           0x00000003

#define FILE_PIPE_BYTE_STREAM_MODE          0x00000000
#define FILE_PIPE_MESSAGE_MODE              0x00000001

#define FILE_PIPE_QUEUE_OPERATION           0x00000000
#define FILE_PIPE_COMPLETE_OPERATION        0x00000001

#define FILE_PIPE_INBOUND                   0x00000000
#define FILE_PIPE_OUTBOUND                  0x00000001
#define FILE_PIPE_FULL_DUPLEX               0x00000002

#define FILE_PIPE_DISCONNECTED_STATE        0x00000001
#define FILE_PIPE_LISTENING_STATE           0x00000002
#define FILE_PIPE_CONNECTED_STATE           0x00000003
#define FILE_PIPE_CLOSING_STATE             0x00000004

#define FILE_PIPE_CLIENT_END                0x00000000
#define FILE_PIPE_SERVER_END                0x00000001

#define FILE_CASE_SENSITIVE_SEARCH          0x00000001
#define FILE_CASE_PRESERVED_NAMES           0x00000002
#define FILE_UNICODE_ON_DISK                0x00000004
#define FILE_PERSISTENT_ACLS                0x00000008
#define FILE_FILE_COMPRESSION               0x00000010
#define FILE_VOLUME_QUOTAS                  0x00000020
#define FILE_SUPPORTS_SPARSE_FILES          0x00000040
#define FILE_SUPPORTS_REPARSE_POINTS        0x00000080
#define FILE_SUPPORTS_REMOTE_STORAGE        0x00000100
#define FILE_VOLUME_IS_COMPRESSED           0x00008000
#define FILE_SUPPORTS_OBJECT_IDS            0x00010000
#define FILE_SUPPORTS_ENCRYPTION            0x00020000
#define FILE_NAMED_STREAMS                  0x00040000
#define FILE_READ_ONLY_VOLUME               0x00080000
#define FILE_SEQUENTIAL_WRITE_ONCE          0x00100000
#define FILE_SUPPORTS_TRANSACTIONS          0x00200000
#define FILE_SUPPORTS_HARD_LINKS            0x00400000
#define FILE_SUPPORTS_EXTENDED_ATTRIBUTES   0x00800000
#define FILE_SUPPORTS_OPEN_BY_FILE_ID       0x01000000
#define FILE_SUPPORTS_USN_JOURNAL           0x02000000

#define FILE_NEED_EA                    0x00000080

#define FILE_EA_TYPE_BINARY             0xfffe
#define FILE_EA_TYPE_ASCII              0xfffd
#define FILE_EA_TYPE_BITMAP             0xfffb
#define FILE_EA_TYPE_METAFILE           0xfffa
#define FILE_EA_TYPE_ICON               0xfff9
#define FILE_EA_TYPE_EA                 0xffee
#define FILE_EA_TYPE_MVMT               0xffdf
#define FILE_EA_TYPE_MVST               0xffde
#define FILE_EA_TYPE_ASN1               0xffdd
#define FILE_EA_TYPE_FAMILY_IDS         0xff01

typedef struct _FILE_NOTIFY_INFORMATION {
  ULONG NextEntryOffset;
  ULONG Action;
  ULONG FileNameLength;
  WCHAR FileName[1];
} FILE_NOTIFY_INFORMATION, *PFILE_NOTIFY_INFORMATION;

typedef struct _FILE_DIRECTORY_INFORMATION {
  ULONG NextEntryOffset;
  ULONG FileIndex;
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  LARGE_INTEGER EndOfFile;
  LARGE_INTEGER AllocationSize;
  ULONG FileAttributes;
  ULONG FileNameLength;
  WCHAR FileName[1];
} FILE_DIRECTORY_INFORMATION, *PFILE_DIRECTORY_INFORMATION;

typedef struct _FILE_FULL_DIR_INFORMATION {
  ULONG NextEntryOffset;
  ULONG FileIndex;
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  LARGE_INTEGER EndOfFile;
  LARGE_INTEGER AllocationSize;
  ULONG FileAttributes;
  ULONG FileNameLength;
  ULONG EaSize;
  WCHAR FileName[1];
} FILE_FULL_DIR_INFORMATION, *PFILE_FULL_DIR_INFORMATION;

typedef struct _FILE_ID_FULL_DIR_INFORMATION {
  ULONG NextEntryOffset;
  ULONG FileIndex;
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  LARGE_INTEGER EndOfFile;
  LARGE_INTEGER AllocationSize;
  ULONG FileAttributes;
  ULONG FileNameLength;
  ULONG EaSize;
  LARGE_INTEGER FileId;
  WCHAR FileName[1];
} FILE_ID_FULL_DIR_INFORMATION, *PFILE_ID_FULL_DIR_INFORMATION;

typedef struct _FILE_BOTH_DIR_INFORMATION {
  ULONG NextEntryOffset;
  ULONG FileIndex;
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  LARGE_INTEGER EndOfFile;
  LARGE_INTEGER AllocationSize;
  ULONG FileAttributes;
  ULONG FileNameLength;
  ULONG EaSize;
  CCHAR ShortNameLength;
  WCHAR ShortName[12];
  WCHAR FileName[1];
} FILE_BOTH_DIR_INFORMATION, *PFILE_BOTH_DIR_INFORMATION;

typedef struct _FILE_ID_BOTH_DIR_INFORMATION {
  ULONG NextEntryOffset;
  ULONG FileIndex;
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  LARGE_INTEGER EndOfFile;
  LARGE_INTEGER AllocationSize;
  ULONG FileAttributes;
  ULONG FileNameLength;
  ULONG EaSize;
  CCHAR ShortNameLength;
  WCHAR ShortName[12];
  LARGE_INTEGER FileId;
  WCHAR FileName[1];
} FILE_ID_BOTH_DIR_INFORMATION, *PFILE_ID_BOTH_DIR_INFORMATION;

typedef struct _FILE_NAMES_INFORMATION {
  ULONG NextEntryOffset;
  ULONG FileIndex;
  ULONG FileNameLength;
  WCHAR FileName[1];
} FILE_NAMES_INFORMATION, *PFILE_NAMES_INFORMATION;

typedef struct _FILE_ID_GLOBAL_TX_DIR_INFORMATION {
  ULONG NextEntryOffset;
  ULONG FileIndex;
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  LARGE_INTEGER EndOfFile;
  LARGE_INTEGER AllocationSize;
  ULONG FileAttributes;
  ULONG FileNameLength;
  LARGE_INTEGER FileId;
  GUID LockingTransactionId;
  ULONG TxInfoFlags;
  WCHAR FileName[1];
} FILE_ID_GLOBAL_TX_DIR_INFORMATION, *PFILE_ID_GLOBAL_TX_DIR_INFORMATION;

#define FILE_ID_GLOBAL_TX_DIR_INFO_FLAG_WRITELOCKED         0x00000001
#define FILE_ID_GLOBAL_TX_DIR_INFO_FLAG_VISIBLE_TO_TX       0x00000002
#define FILE_ID_GLOBAL_TX_DIR_INFO_FLAG_VISIBLE_OUTSIDE_TX  0x00000004

typedef struct _FILE_OBJECTID_INFORMATION {
  LONGLONG FileReference;
  UCHAR ObjectId[16];
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      UCHAR BirthVolumeId[16];
      UCHAR BirthObjectId[16];
      UCHAR DomainId[16];
    } DUMMYSTRUCTNAME;
    UCHAR ExtendedInfo[48];
  } DUMMYUNIONNAME;
} FILE_OBJECTID_INFORMATION, *PFILE_OBJECTID_INFORMATION;

#define ANSI_DOS_STAR                   ('<')
#define ANSI_DOS_QM                     ('>')
#define ANSI_DOS_DOT                    ('"')

#define DOS_STAR                        (L'<')
#define DOS_QM                          (L'>')
#define DOS_DOT                         (L'"')

typedef struct _FILE_INTERNAL_INFORMATION {
  LARGE_INTEGER IndexNumber;
} FILE_INTERNAL_INFORMATION, *PFILE_INTERNAL_INFORMATION;

typedef struct _FILE_EA_INFORMATION {
  ULONG EaSize;
} FILE_EA_INFORMATION, *PFILE_EA_INFORMATION;

typedef struct _FILE_ACCESS_INFORMATION {
  ACCESS_MASK AccessFlags;
} FILE_ACCESS_INFORMATION, *PFILE_ACCESS_INFORMATION;

typedef struct _FILE_MODE_INFORMATION {
  ULONG Mode;
} FILE_MODE_INFORMATION, *PFILE_MODE_INFORMATION;

typedef struct _FILE_ALL_INFORMATION {
  FILE_BASIC_INFORMATION BasicInformation;
  FILE_STANDARD_INFORMATION StandardInformation;
  FILE_INTERNAL_INFORMATION InternalInformation;
  FILE_EA_INFORMATION EaInformation;
  FILE_ACCESS_INFORMATION AccessInformation;
  FILE_POSITION_INFORMATION PositionInformation;
  FILE_MODE_INFORMATION ModeInformation;
  FILE_ALIGNMENT_INFORMATION AlignmentInformation;
  FILE_NAME_INFORMATION NameInformation;
} FILE_ALL_INFORMATION, *PFILE_ALL_INFORMATION;

typedef struct _FILE_ALLOCATION_INFORMATION {
  LARGE_INTEGER AllocationSize;
} FILE_ALLOCATION_INFORMATION, *PFILE_ALLOCATION_INFORMATION;

typedef struct _FILE_COMPRESSION_INFORMATION {
  LARGE_INTEGER CompressedFileSize;
  USHORT CompressionFormat;
  UCHAR CompressionUnitShift;
  UCHAR ChunkShift;
  UCHAR ClusterShift;
  UCHAR Reserved[3];
} FILE_COMPRESSION_INFORMATION, *PFILE_COMPRESSION_INFORMATION;

typedef struct _FILE_LINK_INFORMATION {
  BOOLEAN ReplaceIfExists;
  HANDLE RootDirectory;
  ULONG FileNameLength;
  WCHAR FileName[1];
} FILE_LINK_INFORMATION, *PFILE_LINK_INFORMATION;

typedef struct _FILE_MOVE_CLUSTER_INFORMATION {
  ULONG ClusterCount;
  HANDLE RootDirectory;
  ULONG FileNameLength;
  WCHAR FileName[1];
} FILE_MOVE_CLUSTER_INFORMATION, *PFILE_MOVE_CLUSTER_INFORMATION;

typedef struct _FILE_RENAME_INFORMATION {
  BOOLEAN ReplaceIfExists;
  HANDLE RootDirectory;
  ULONG FileNameLength;
  WCHAR FileName[1];
} FILE_RENAME_INFORMATION, *PFILE_RENAME_INFORMATION;

typedef struct _FILE_STREAM_INFORMATION {
  ULONG NextEntryOffset;
  ULONG StreamNameLength;
  LARGE_INTEGER StreamSize;
  LARGE_INTEGER StreamAllocationSize;
  WCHAR StreamName[1];
} FILE_STREAM_INFORMATION, *PFILE_STREAM_INFORMATION;

typedef struct _FILE_TRACKING_INFORMATION {
  HANDLE DestinationFile;
  ULONG ObjectInformationLength;
  CHAR ObjectInformation[1];
} FILE_TRACKING_INFORMATION, *PFILE_TRACKING_INFORMATION;

typedef struct _FILE_COMPLETION_INFORMATION {
  HANDLE Port;
  PVOID Key;
} FILE_COMPLETION_INFORMATION, *PFILE_COMPLETION_INFORMATION;

typedef struct _FILE_PIPE_INFORMATION {
  ULONG ReadMode;
  ULONG CompletionMode;
} FILE_PIPE_INFORMATION, *PFILE_PIPE_INFORMATION;

typedef struct _FILE_PIPE_LOCAL_INFORMATION {
  ULONG NamedPipeType;
  ULONG NamedPipeConfiguration;
  ULONG MaximumInstances;
  ULONG CurrentInstances;
  ULONG InboundQuota;
  ULONG ReadDataAvailable;
  ULONG OutboundQuota;
  ULONG WriteQuotaAvailable;
  ULONG NamedPipeState;
  ULONG NamedPipeEnd;
} FILE_PIPE_LOCAL_INFORMATION, *PFILE_PIPE_LOCAL_INFORMATION;

typedef struct _FILE_PIPE_REMOTE_INFORMATION {
  LARGE_INTEGER CollectDataTime;
  ULONG MaximumCollectionCount;
} FILE_PIPE_REMOTE_INFORMATION, *PFILE_PIPE_REMOTE_INFORMATION;

typedef struct _FILE_MAILSLOT_QUERY_INFORMATION {
  ULONG MaximumMessageSize;
  ULONG MailslotQuota;
  ULONG NextMessageSize;
  ULONG MessagesAvailable;
  LARGE_INTEGER ReadTimeout;
} FILE_MAILSLOT_QUERY_INFORMATION, *PFILE_MAILSLOT_QUERY_INFORMATION;

typedef struct _FILE_MAILSLOT_SET_INFORMATION {
  PLARGE_INTEGER ReadTimeout;
} FILE_MAILSLOT_SET_INFORMATION, *PFILE_MAILSLOT_SET_INFORMATION;

typedef struct _FILE_REPARSE_POINT_INFORMATION {
  LONGLONG FileReference;
  ULONG Tag;
} FILE_REPARSE_POINT_INFORMATION, *PFILE_REPARSE_POINT_INFORMATION;

typedef struct _FILE_LINK_ENTRY_INFORMATION {
  ULONG NextEntryOffset;
  LONGLONG ParentFileId;
  ULONG FileNameLength;
  WCHAR FileName[1];
} FILE_LINK_ENTRY_INFORMATION, *PFILE_LINK_ENTRY_INFORMATION;

typedef struct _FILE_LINKS_INFORMATION {
  ULONG BytesNeeded;
  ULONG EntriesReturned;
  FILE_LINK_ENTRY_INFORMATION Entry;
} FILE_LINKS_INFORMATION, *PFILE_LINKS_INFORMATION;

typedef struct _FILE_NETWORK_PHYSICAL_NAME_INFORMATION {
  ULONG FileNameLength;
  WCHAR FileName[1];
} FILE_NETWORK_PHYSICAL_NAME_INFORMATION, *PFILE_NETWORK_PHYSICAL_NAME_INFORMATION;

typedef struct _FILE_STANDARD_LINK_INFORMATION {
  ULONG NumberOfAccessibleLinks;
  ULONG TotalNumberOfLinks;
  BOOLEAN DeletePending;
  BOOLEAN Directory;
} FILE_STANDARD_LINK_INFORMATION, *PFILE_STANDARD_LINK_INFORMATION;

typedef struct _FILE_GET_EA_INFORMATION {
  ULONG NextEntryOffset;
  UCHAR EaNameLength;
  CHAR  EaName[1];
} FILE_GET_EA_INFORMATION, *PFILE_GET_EA_INFORMATION;

#define REMOTE_PROTOCOL_FLAG_LOOPBACK       0x00000001
#define REMOTE_PROTOCOL_FLAG_OFFLINE        0x00000002

typedef struct _FILE_REMOTE_PROTOCOL_INFORMATION {
  USHORT StructureVersion;
  USHORT StructureSize;
  ULONG  Protocol;
  USHORT ProtocolMajorVersion;
  USHORT ProtocolMinorVersion;
  USHORT ProtocolRevision;
  USHORT Reserved;
  ULONG  Flags;
  struct {
    ULONG Reserved[8];
  } GenericReserved;
  struct {
    ULONG Reserved[16];
  } ProtocolSpecificReserved;
} FILE_REMOTE_PROTOCOL_INFORMATION, *PFILE_REMOTE_PROTOCOL_INFORMATION;

typedef struct _FILE_GET_QUOTA_INFORMATION {
  ULONG NextEntryOffset;
  ULONG SidLength;
  SID Sid;
} FILE_GET_QUOTA_INFORMATION, *PFILE_GET_QUOTA_INFORMATION;

typedef struct _FILE_QUOTA_INFORMATION {
  ULONG NextEntryOffset;
  ULONG SidLength;
  LARGE_INTEGER ChangeTime;
  LARGE_INTEGER QuotaUsed;
  LARGE_INTEGER QuotaThreshold;
  LARGE_INTEGER QuotaLimit;
  SID Sid;
} FILE_QUOTA_INFORMATION, *PFILE_QUOTA_INFORMATION;

typedef struct _FILE_FS_ATTRIBUTE_INFORMATION {
  ULONG FileSystemAttributes;
  ULONG MaximumComponentNameLength;
  ULONG FileSystemNameLength;
  WCHAR FileSystemName[1];
} FILE_FS_ATTRIBUTE_INFORMATION, *PFILE_FS_ATTRIBUTE_INFORMATION;

typedef struct _FILE_FS_DRIVER_PATH_INFORMATION {
  BOOLEAN DriverInPath;
  ULONG DriverNameLength;
  WCHAR DriverName[1];
} FILE_FS_DRIVER_PATH_INFORMATION, *PFILE_FS_DRIVER_PATH_INFORMATION;

typedef struct _FILE_FS_VOLUME_FLAGS_INFORMATION {
  ULONG Flags;
} FILE_FS_VOLUME_FLAGS_INFORMATION, *PFILE_FS_VOLUME_FLAGS_INFORMATION;

#define FILE_VC_QUOTA_NONE              0x00000000
#define FILE_VC_QUOTA_TRACK             0x00000001
#define FILE_VC_QUOTA_ENFORCE           0x00000002
#define FILE_VC_QUOTA_MASK              0x00000003
#define FILE_VC_CONTENT_INDEX_DISABLED  0x00000008
#define FILE_VC_LOG_QUOTA_THRESHOLD     0x00000010
#define FILE_VC_LOG_QUOTA_LIMIT         0x00000020
#define FILE_VC_LOG_VOLUME_THRESHOLD    0x00000040
#define FILE_VC_LOG_VOLUME_LIMIT        0x00000080
#define FILE_VC_QUOTAS_INCOMPLETE       0x00000100
#define FILE_VC_QUOTAS_REBUILDING       0x00000200
#define FILE_VC_VALID_MASK              0x000003ff

typedef struct _FILE_FS_CONTROL_INFORMATION {
  LARGE_INTEGER FreeSpaceStartFiltering;
  LARGE_INTEGER FreeSpaceThreshold;
  LARGE_INTEGER FreeSpaceStopFiltering;
  LARGE_INTEGER DefaultQuotaThreshold;
  LARGE_INTEGER DefaultQuotaLimit;
  ULONG FileSystemControlFlags;
} FILE_FS_CONTROL_INFORMATION, *PFILE_FS_CONTROL_INFORMATION;

#ifndef _FILESYSTEMFSCTL_
#define _FILESYSTEMFSCTL_

#define FSCTL_REQUEST_OPLOCK_LEVEL_1    CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  0, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_REQUEST_OPLOCK_LEVEL_2    CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  1, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_REQUEST_BATCH_OPLOCK      CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  2, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_OPLOCK_BREAK_ACKNOWLEDGE  CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  3, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_OPBATCH_ACK_CLOSE_PENDING CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  4, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_OPLOCK_BREAK_NOTIFY       CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  5, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_LOCK_VOLUME               CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  6, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_UNLOCK_VOLUME             CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  7, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_DISMOUNT_VOLUME           CTL_CODE(FILE_DEVICE_FILE_SYSTEM,  8, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_IS_VOLUME_MOUNTED         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 10, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_IS_PATHNAME_VALID         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 11, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_MARK_VOLUME_DIRTY         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 12, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_QUERY_RETRIEVAL_POINTERS  CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 14, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_GET_COMPRESSION           CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 15, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_SET_COMPRESSION           CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 16, METHOD_BUFFERED, FILE_READ_DATA | FILE_WRITE_DATA)
#define FSCTL_SET_BOOTLOADER_ACCESSED   CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 19, METHOD_NEITHER,  FILE_ANY_ACCESS)

#define FSCTL_OPLOCK_BREAK_ACK_NO_2     CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 20, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_INVALIDATE_VOLUMES        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 21, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_QUERY_FAT_BPB             CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 22, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_REQUEST_FILTER_OPLOCK     CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 23, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_FILESYSTEM_GET_STATISTICS CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 24, METHOD_BUFFERED, FILE_ANY_ACCESS)

#if (_WIN32_WINNT >= 0x0400)

#define FSCTL_GET_NTFS_VOLUME_DATA      CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 25, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_GET_NTFS_FILE_RECORD      CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 26, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_GET_VOLUME_BITMAP         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 27, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_GET_RETRIEVAL_POINTERS    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 28, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_MOVE_FILE                 CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 29, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_IS_VOLUME_DIRTY           CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 30, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_ALLOW_EXTENDED_DASD_IO    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 32, METHOD_NEITHER,  FILE_ANY_ACCESS)

#endif

#if (_WIN32_WINNT >= 0x0500)

#define FSCTL_FIND_FILES_BY_SID         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 35, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_SET_OBJECT_ID             CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 38, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_GET_OBJECT_ID             CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 39, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_DELETE_OBJECT_ID          CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 40, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_SET_REPARSE_POINT         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 41, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_GET_REPARSE_POINT         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 42, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_DELETE_REPARSE_POINT      CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 43, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_ENUM_USN_DATA             CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 44, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_SECURITY_ID_CHECK         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 45, METHOD_NEITHER,  FILE_READ_DATA)
#define FSCTL_READ_USN_JOURNAL          CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 46, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_SET_OBJECT_ID_EXTENDED    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 47, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_CREATE_OR_GET_OBJECT_ID   CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 48, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_SET_SPARSE                CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 49, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_SET_ZERO_DATA             CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 50, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_QUERY_ALLOCATED_RANGES    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 51, METHOD_NEITHER,  FILE_READ_DATA)
#define FSCTL_ENABLE_UPGRADE            CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 52, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_SET_ENCRYPTION            CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 53, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_ENCRYPTION_FSCTL_IO       CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 54, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_WRITE_RAW_ENCRYPTED       CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 55, METHOD_NEITHER,  FILE_SPECIAL_ACCESS)
#define FSCTL_READ_RAW_ENCRYPTED        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 56, METHOD_NEITHER,  FILE_SPECIAL_ACCESS)
#define FSCTL_CREATE_USN_JOURNAL        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 57, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_READ_FILE_USN_DATA        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 58, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_WRITE_USN_CLOSE_RECORD    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 59, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_EXTEND_VOLUME             CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 60, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_QUERY_USN_JOURNAL         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 61, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_DELETE_USN_JOURNAL        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 62, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_MARK_HANDLE               CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 63, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_SIS_COPYFILE              CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 64, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_SIS_LINK_FILES            CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 65, METHOD_BUFFERED, FILE_READ_DATA | FILE_WRITE_DATA)
#define FSCTL_RECALL_FILE               CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 69, METHOD_NEITHER, FILE_ANY_ACCESS)
#define FSCTL_READ_FROM_PLEX            CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 71, METHOD_OUT_DIRECT, FILE_READ_DATA)
#define FSCTL_FILE_PREFETCH             CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 72, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)

#endif

#if (_WIN32_WINNT >= 0x0600)

#define FSCTL_MAKE_MEDIA_COMPATIBLE         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 76, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_SET_DEFECT_MANAGEMENT         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 77, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_QUERY_SPARING_INFO            CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 78, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_QUERY_ON_DISK_VOLUME_INFO     CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 79, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_SET_VOLUME_COMPRESSION_STATE  CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 80, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_TXFS_MODIFY_RM                CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 81, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_QUERY_RM_INFORMATION     CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 82, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_TXFS_ROLLFORWARD_REDO         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 84, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_ROLLFORWARD_UNDO         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 85, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_START_RM                 CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 86, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_SHUTDOWN_RM              CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 87, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_READ_BACKUP_INFORMATION  CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 88, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_TXFS_WRITE_BACKUP_INFORMATION CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 89, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_CREATE_SECONDARY_RM      CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 90, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_GET_METADATA_INFO        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 91, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_TXFS_GET_TRANSACTED_VERSION   CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 92, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_TXFS_SAVEPOINT_INFORMATION    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 94, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_CREATE_MINIVERSION       CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 95, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_TXFS_TRANSACTION_ACTIVE       CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 99, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_SET_ZERO_ON_DEALLOCATION      CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 101, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_SET_REPAIR                    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 102, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_GET_REPAIR                    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 103, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_WAIT_FOR_REPAIR               CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 104, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_INITIATE_REPAIR               CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 106, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_CSC_INTERNAL                  CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 107, METHOD_NEITHER,  FILE_ANY_ACCESS)
#define FSCTL_SHRINK_VOLUME                 CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 108, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
#define FSCTL_SET_SHORT_NAME_BEHAVIOR       CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 109, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_DFSR_SET_GHOST_HANDLE_STATE   CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 110, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define FSCTL_TXFS_LIST_TRANSACTION_LOCKED_FILES \
                                            CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 120, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_TXFS_LIST_TRANSACTIONS        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 121, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_QUERY_PAGEFILE_ENCRYPTION     CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 122, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_RESET_VOLUME_ALLOCATION_HINTS CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 123, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_TXFS_READ_BACKUP_INFORMATION2 CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 126, METHOD_BUFFERED, FILE_ANY_ACCESS)

#endif

#if (_WIN32_WINNT >= 0x0601)

#define FSCTL_QUERY_DEPENDENT_VOLUME        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 124, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_SD_GLOBAL_CHANGE              CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 125, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_LOOKUP_STREAM_FROM_CLUSTER    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 127, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_TXFS_WRITE_BACKUP_INFORMATION2 CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 128, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_FILE_TYPE_NOTIFICATION        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 129, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_GET_BOOT_AREA_INFO            CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 140, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_GET_RETRIEVAL_POINTER_BASE    CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 141, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_SET_PERSISTENT_VOLUME_STATE   CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 142, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_QUERY_PERSISTENT_VOLUME_STATE CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 143, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define FSCTL_REQUEST_OPLOCK                CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 144, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define FSCTL_CSV_TUNNEL_REQUEST            CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 145, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_IS_CSV_FILE                   CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 146, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define FSCTL_QUERY_FILE_SYSTEM_RECOGNITION CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 147, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_CSV_GET_VOLUME_PATH_NAME      CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 148, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_CSV_GET_VOLUME_NAME_FOR_VOLUME_MOUNT_POINT CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 149, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_CSV_GET_VOLUME_PATH_NAMES_FOR_VOLUME_NAME CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 150,  METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_IS_FILE_ON_CSV_VOLUME         CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 151,  METHOD_BUFFERED, FILE_ANY_ACCESS)

typedef struct _CSV_NAMESPACE_INFO {
  ULONG Version;
  ULONG DeviceNumber;
  LARGE_INTEGER StartingOffset;
  ULONG SectorSize;
} CSV_NAMESPACE_INFO, *PCSV_NAMESPACE_INFO;

#define CSV_NAMESPACE_INFO_V1 (sizeof(CSV_NAMESPACE_INFO))
#define CSV_INVALID_DEVICE_NUMBER 0xFFFFFFFF

#endif

#define FSCTL_MARK_AS_SYSTEM_HIVE           FSCTL_SET_BOOTLOADER_ACCESSED

typedef struct _PATHNAME_BUFFER {
  ULONG PathNameLength;
  WCHAR Name[1];
} PATHNAME_BUFFER, *PPATHNAME_BUFFER;

typedef struct _FSCTL_QUERY_FAT_BPB_BUFFER {
  UCHAR First0x24BytesOfBootSector[0x24];
} FSCTL_QUERY_FAT_BPB_BUFFER, *PFSCTL_QUERY_FAT_BPB_BUFFER;

#if (_WIN32_WINNT >= 0x0400)

typedef struct _NTFS_VOLUME_DATA_BUFFER {
  LARGE_INTEGER VolumeSerialNumber;
  LARGE_INTEGER NumberSectors;
  LARGE_INTEGER TotalClusters;
  LARGE_INTEGER FreeClusters;
  LARGE_INTEGER TotalReserved;
  ULONG BytesPerSector;
  ULONG BytesPerCluster;
  ULONG BytesPerFileRecordSegment;
  ULONG ClustersPerFileRecordSegment;
  LARGE_INTEGER MftValidDataLength;
  LARGE_INTEGER MftStartLcn;
  LARGE_INTEGER Mft2StartLcn;
  LARGE_INTEGER MftZoneStart;
  LARGE_INTEGER MftZoneEnd;
} NTFS_VOLUME_DATA_BUFFER, *PNTFS_VOLUME_DATA_BUFFER;

typedef struct _NTFS_EXTENDED_VOLUME_DATA {
  ULONG ByteCount;
  USHORT MajorVersion;
  USHORT MinorVersion;
} NTFS_EXTENDED_VOLUME_DATA, *PNTFS_EXTENDED_VOLUME_DATA;

typedef struct _STARTING_LCN_INPUT_BUFFER {
  LARGE_INTEGER StartingLcn;
} STARTING_LCN_INPUT_BUFFER, *PSTARTING_LCN_INPUT_BUFFER;

typedef struct _VOLUME_BITMAP_BUFFER {
  LARGE_INTEGER StartingLcn;
  LARGE_INTEGER BitmapSize;
  UCHAR Buffer[1];
} VOLUME_BITMAP_BUFFER, *PVOLUME_BITMAP_BUFFER;

typedef struct _STARTING_VCN_INPUT_BUFFER {
  LARGE_INTEGER StartingVcn;
} STARTING_VCN_INPUT_BUFFER, *PSTARTING_VCN_INPUT_BUFFER;

typedef struct _RETRIEVAL_POINTERS_BUFFER {
  ULONG ExtentCount;
  LARGE_INTEGER StartingVcn;
  struct {
    LARGE_INTEGER NextVcn;
    LARGE_INTEGER Lcn;
  } Extents[1];
} RETRIEVAL_POINTERS_BUFFER, *PRETRIEVAL_POINTERS_BUFFER;

typedef struct _NTFS_FILE_RECORD_INPUT_BUFFER {
  LARGE_INTEGER FileReferenceNumber;
} NTFS_FILE_RECORD_INPUT_BUFFER, *PNTFS_FILE_RECORD_INPUT_BUFFER;

typedef struct _NTFS_FILE_RECORD_OUTPUT_BUFFER {
  LARGE_INTEGER FileReferenceNumber;
  ULONG FileRecordLength;
  UCHAR FileRecordBuffer[1];
} NTFS_FILE_RECORD_OUTPUT_BUFFER, *PNTFS_FILE_RECORD_OUTPUT_BUFFER;

typedef struct _MOVE_FILE_DATA {
  HANDLE FileHandle;
  LARGE_INTEGER StartingVcn;
  LARGE_INTEGER StartingLcn;
  ULONG ClusterCount;
} MOVE_FILE_DATA, *PMOVE_FILE_DATA;

typedef struct _MOVE_FILE_RECORD_DATA {
  HANDLE FileHandle;
  LARGE_INTEGER SourceFileRecord;
  LARGE_INTEGER TargetFileRecord;
} MOVE_FILE_RECORD_DATA, *PMOVE_FILE_RECORD_DATA;

#if defined(_WIN64)
typedef struct _MOVE_FILE_DATA32 {
  UINT32 FileHandle;
  LARGE_INTEGER StartingVcn;
  LARGE_INTEGER StartingLcn;
  ULONG ClusterCount;
} MOVE_FILE_DATA32, *PMOVE_FILE_DATA32;
#endif

#endif /* (_WIN32_WINNT >= 0x0400) */

#if (_WIN32_WINNT >= 0x0500)

typedef struct _FIND_BY_SID_DATA {
  ULONG Restart;
  SID Sid;
} FIND_BY_SID_DATA, *PFIND_BY_SID_DATA;

typedef struct _FIND_BY_SID_OUTPUT {
  ULONG NextEntryOffset;
  ULONG FileIndex;
  ULONG FileNameLength;
  WCHAR FileName[1];
} FIND_BY_SID_OUTPUT, *PFIND_BY_SID_OUTPUT;

typedef struct _MFT_ENUM_DATA {
  ULONGLONG StartFileReferenceNumber;
  USN LowUsn;
  USN HighUsn;
} MFT_ENUM_DATA, *PMFT_ENUM_DATA;

typedef struct _CREATE_USN_JOURNAL_DATA {
  ULONGLONG MaximumSize;
  ULONGLONG AllocationDelta;
} CREATE_USN_JOURNAL_DATA, *PCREATE_USN_JOURNAL_DATA;

typedef struct _READ_USN_JOURNAL_DATA {
  USN StartUsn;
  ULONG ReasonMask;
  ULONG ReturnOnlyOnClose;
  ULONGLONG Timeout;
  ULONGLONG BytesToWaitFor;
  ULONGLONG UsnJournalID;
} READ_USN_JOURNAL_DATA, *PREAD_USN_JOURNAL_DATA;

typedef struct _USN_RECORD {
  ULONG RecordLength;
  USHORT MajorVersion;
  USHORT MinorVersion;
  ULONGLONG FileReferenceNumber;
  ULONGLONG ParentFileReferenceNumber;
  USN Usn;
  LARGE_INTEGER TimeStamp;
  ULONG Reason;
  ULONG SourceInfo;
  ULONG SecurityId;
  ULONG FileAttributes;
  USHORT FileNameLength;
  USHORT FileNameOffset;
  WCHAR FileName[1];
} USN_RECORD, *PUSN_RECORD;

#define USN_PAGE_SIZE                    (0x1000)

#define USN_REASON_DATA_OVERWRITE        (0x00000001)
#define USN_REASON_DATA_EXTEND           (0x00000002)
#define USN_REASON_DATA_TRUNCATION       (0x00000004)
#define USN_REASON_NAMED_DATA_OVERWRITE  (0x00000010)
#define USN_REASON_NAMED_DATA_EXTEND     (0x00000020)
#define USN_REASON_NAMED_DATA_TRUNCATION (0x00000040)
#define USN_REASON_FILE_CREATE           (0x00000100)
#define USN_REASON_FILE_DELETE           (0x00000200)
#define USN_REASON_EA_CHANGE             (0x00000400)
#define USN_REASON_SECURITY_CHANGE       (0x00000800)
#define USN_REASON_RENAME_OLD_NAME       (0x00001000)
#define USN_REASON_RENAME_NEW_NAME       (0x00002000)
#define USN_REASON_INDEXABLE_CHANGE      (0x00004000)
#define USN_REASON_BASIC_INFO_CHANGE     (0x00008000)
#define USN_REASON_HARD_LINK_CHANGE      (0x00010000)
#define USN_REASON_COMPRESSION_CHANGE    (0x00020000)
#define USN_REASON_ENCRYPTION_CHANGE     (0x00040000)
#define USN_REASON_OBJECT_ID_CHANGE      (0x00080000)
#define USN_REASON_REPARSE_POINT_CHANGE  (0x00100000)
#define USN_REASON_STREAM_CHANGE         (0x00200000)
#define USN_REASON_TRANSACTED_CHANGE     (0x00400000)
#define USN_REASON_CLOSE                 (0x80000000)

typedef struct _USN_JOURNAL_DATA {
  ULONGLONG UsnJournalID;
  USN FirstUsn;
  USN NextUsn;
  USN LowestValidUsn;
  USN MaxUsn;
  ULONGLONG MaximumSize;
  ULONGLONG AllocationDelta;
} USN_JOURNAL_DATA, *PUSN_JOURNAL_DATA;

typedef struct _DELETE_USN_JOURNAL_DATA {
  ULONGLONG UsnJournalID;
  ULONG DeleteFlags;
} DELETE_USN_JOURNAL_DATA, *PDELETE_USN_JOURNAL_DATA;

#define USN_DELETE_FLAG_DELETE              (0x00000001)
#define USN_DELETE_FLAG_NOTIFY              (0x00000002)
#define USN_DELETE_VALID_FLAGS              (0x00000003)

typedef struct _MARK_HANDLE_INFO {
  ULONG UsnSourceInfo;
  HANDLE VolumeHandle;
  ULONG HandleInfo;
} MARK_HANDLE_INFO, *PMARK_HANDLE_INFO;

#if defined(_WIN64)
typedef struct _MARK_HANDLE_INFO32 {
  ULONG UsnSourceInfo;
  UINT32 VolumeHandle;
  ULONG HandleInfo;
} MARK_HANDLE_INFO32, *PMARK_HANDLE_INFO32;
#endif

#define USN_SOURCE_DATA_MANAGEMENT          (0x00000001)
#define USN_SOURCE_AUXILIARY_DATA           (0x00000002)
#define USN_SOURCE_REPLICATION_MANAGEMENT   (0x00000004)

#define MARK_HANDLE_PROTECT_CLUSTERS        (0x00000001)
#define MARK_HANDLE_TXF_SYSTEM_LOG          (0x00000004)
#define MARK_HANDLE_NOT_TXF_SYSTEM_LOG      (0x00000008)

typedef struct _BULK_SECURITY_TEST_DATA {
  ACCESS_MASK DesiredAccess;
  ULONG SecurityIds[1];
} BULK_SECURITY_TEST_DATA, *PBULK_SECURITY_TEST_DATA;

#define VOLUME_IS_DIRTY                  (0x00000001)
#define VOLUME_UPGRADE_SCHEDULED         (0x00000002)
#define VOLUME_SESSION_OPEN              (0x00000004)

typedef struct _FILE_PREFETCH {
  ULONG Type;
  ULONG Count;
  ULONGLONG Prefetch[1];
} FILE_PREFETCH, *PFILE_PREFETCH;

typedef struct _FILE_PREFETCH_EX {
  ULONG Type;
  ULONG Count;
  PVOID Context;
  ULONGLONG Prefetch[1];
} FILE_PREFETCH_EX, *PFILE_PREFETCH_EX;

#define FILE_PREFETCH_TYPE_FOR_CREATE       0x1
#define FILE_PREFETCH_TYPE_FOR_DIRENUM      0x2
#define FILE_PREFETCH_TYPE_FOR_CREATE_EX    0x3
#define FILE_PREFETCH_TYPE_FOR_DIRENUM_EX   0x4

#define FILE_PREFETCH_TYPE_MAX              0x4

typedef struct _FILE_OBJECTID_BUFFER {
  UCHAR ObjectId[16];
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      UCHAR BirthVolumeId[16];
      UCHAR BirthObjectId[16];
      UCHAR DomainId[16];
    } DUMMYSTRUCTNAME;
    UCHAR ExtendedInfo[48];
  } DUMMYUNIONNAME;
} FILE_OBJECTID_BUFFER, *PFILE_OBJECTID_BUFFER;

typedef struct _FILE_SET_SPARSE_BUFFER {
  BOOLEAN SetSparse;
} FILE_SET_SPARSE_BUFFER, *PFILE_SET_SPARSE_BUFFER;

typedef struct _FILE_ZERO_DATA_INFORMATION {
  LARGE_INTEGER FileOffset;
  LARGE_INTEGER BeyondFinalZero;
} FILE_ZERO_DATA_INFORMATION, *PFILE_ZERO_DATA_INFORMATION;

typedef struct _FILE_ALLOCATED_RANGE_BUFFER {
  LARGE_INTEGER FileOffset;
  LARGE_INTEGER Length;
} FILE_ALLOCATED_RANGE_BUFFER, *PFILE_ALLOCATED_RANGE_BUFFER;

typedef struct _ENCRYPTION_BUFFER {
  ULONG EncryptionOperation;
  UCHAR Private[1];
} ENCRYPTION_BUFFER, *PENCRYPTION_BUFFER;

#define FILE_SET_ENCRYPTION         0x00000001
#define FILE_CLEAR_ENCRYPTION       0x00000002
#define STREAM_SET_ENCRYPTION       0x00000003
#define STREAM_CLEAR_ENCRYPTION     0x00000004

#define MAXIMUM_ENCRYPTION_VALUE    0x00000004

typedef struct _DECRYPTION_STATUS_BUFFER {
  BOOLEAN NoEncryptedStreams;
} DECRYPTION_STATUS_BUFFER, *PDECRYPTION_STATUS_BUFFER;

#define ENCRYPTION_FORMAT_DEFAULT        (0x01)

#define COMPRESSION_FORMAT_SPARSE        (0x4000)

typedef struct _REQUEST_RAW_ENCRYPTED_DATA {
  LONGLONG FileOffset;
  ULONG Length;
} REQUEST_RAW_ENCRYPTED_DATA, *PREQUEST_RAW_ENCRYPTED_DATA;

typedef struct _ENCRYPTED_DATA_INFO {
  ULONGLONG StartingFileOffset;
  ULONG OutputBufferOffset;
  ULONG BytesWithinFileSize;
  ULONG BytesWithinValidDataLength;
  USHORT CompressionFormat;
  UCHAR DataUnitShift;
  UCHAR ChunkShift;
  UCHAR ClusterShift;
  UCHAR EncryptionFormat;
  USHORT NumberOfDataBlocks;
  ULONG DataBlockSize[ANYSIZE_ARRAY];
} ENCRYPTED_DATA_INFO, *PENCRYPTED_DATA_INFO;

typedef struct _PLEX_READ_DATA_REQUEST {
  LARGE_INTEGER ByteOffset;
  ULONG ByteLength;
  ULONG PlexNumber;
} PLEX_READ_DATA_REQUEST, *PPLEX_READ_DATA_REQUEST;

typedef struct _SI_COPYFILE {
  ULONG SourceFileNameLength;
  ULONG DestinationFileNameLength;
  ULONG Flags;
  WCHAR FileNameBuffer[1];
} SI_COPYFILE, *PSI_COPYFILE;

#define COPYFILE_SIS_LINK       0x0001
#define COPYFILE_SIS_REPLACE    0x0002
#define COPYFILE_SIS_FLAGS      0x0003

#endif /* (_WIN32_WINNT >= 0x0500) */

#if (_WIN32_WINNT >= 0x0600)

typedef struct _FILE_MAKE_COMPATIBLE_BUFFER {
  BOOLEAN CloseDisc;
} FILE_MAKE_COMPATIBLE_BUFFER, *PFILE_MAKE_COMPATIBLE_BUFFER;

typedef struct _FILE_SET_DEFECT_MGMT_BUFFER {
  BOOLEAN Disable;
} FILE_SET_DEFECT_MGMT_BUFFER, *PFILE_SET_DEFECT_MGMT_BUFFER;

typedef struct _FILE_QUERY_SPARING_BUFFER {
  ULONG SparingUnitBytes;
  BOOLEAN SoftwareSparing;
  ULONG TotalSpareBlocks;
  ULONG FreeSpareBlocks;
} FILE_QUERY_SPARING_BUFFER, *PFILE_QUERY_SPARING_BUFFER;

typedef struct _FILE_QUERY_ON_DISK_VOL_INFO_BUFFER {
  LARGE_INTEGER DirectoryCount;
  LARGE_INTEGER FileCount;
  USHORT FsFormatMajVersion;
  USHORT FsFormatMinVersion;
  WCHAR FsFormatName[12];
  LARGE_INTEGER FormatTime;
  LARGE_INTEGER LastUpdateTime;
  WCHAR CopyrightInfo[34];
  WCHAR AbstractInfo[34];
  WCHAR FormattingImplementationInfo[34];
  WCHAR LastModifyingImplementationInfo[34];
} FILE_QUERY_ON_DISK_VOL_INFO_BUFFER, *PFILE_QUERY_ON_DISK_VOL_INFO_BUFFER;

#define SET_REPAIR_ENABLED                                      (0x00000001)
#define SET_REPAIR_VOLUME_BITMAP_SCAN                           (0x00000002)
#define SET_REPAIR_DELETE_CROSSLINK                             (0x00000004)
#define SET_REPAIR_WARN_ABOUT_DATA_LOSS                         (0x00000008)
#define SET_REPAIR_DISABLED_AND_BUGCHECK_ON_CORRUPT             (0x00000010)
#define SET_REPAIR_VALID_MASK                                   (0x0000001F)

typedef enum _SHRINK_VOLUME_REQUEST_TYPES {
  ShrinkPrepare = 1,
  ShrinkCommit,
  ShrinkAbort
} SHRINK_VOLUME_REQUEST_TYPES, *PSHRINK_VOLUME_REQUEST_TYPES;

typedef struct _SHRINK_VOLUME_INFORMATION {
  SHRINK_VOLUME_REQUEST_TYPES ShrinkRequestType;
  ULONGLONG Flags;
  LONGLONG NewNumberOfSectors;
} SHRINK_VOLUME_INFORMATION, *PSHRINK_VOLUME_INFORMATION;

#define TXFS_RM_FLAG_LOGGING_MODE                           0x00000001
#define TXFS_RM_FLAG_RENAME_RM                              0x00000002
#define TXFS_RM_FLAG_LOG_CONTAINER_COUNT_MAX                0x00000004
#define TXFS_RM_FLAG_LOG_CONTAINER_COUNT_MIN                0x00000008
#define TXFS_RM_FLAG_LOG_GROWTH_INCREMENT_NUM_CONTAINERS    0x00000010
#define TXFS_RM_FLAG_LOG_GROWTH_INCREMENT_PERCENT           0x00000020
#define TXFS_RM_FLAG_LOG_AUTO_SHRINK_PERCENTAGE             0x00000040
#define TXFS_RM_FLAG_LOG_NO_CONTAINER_COUNT_MAX             0x00000080
#define TXFS_RM_FLAG_LOG_NO_CONTAINER_COUNT_MIN             0x00000100
#define TXFS_RM_FLAG_GROW_LOG                               0x00000400
#define TXFS_RM_FLAG_SHRINK_LOG                             0x00000800
#define TXFS_RM_FLAG_ENFORCE_MINIMUM_SIZE                   0x00001000
#define TXFS_RM_FLAG_PRESERVE_CHANGES                       0x00002000
#define TXFS_RM_FLAG_RESET_RM_AT_NEXT_START                 0x00004000
#define TXFS_RM_FLAG_DO_NOT_RESET_RM_AT_NEXT_START          0x00008000
#define TXFS_RM_FLAG_PREFER_CONSISTENCY                     0x00010000
#define TXFS_RM_FLAG_PREFER_AVAILABILITY                    0x00020000

#define TXFS_LOGGING_MODE_SIMPLE        (0x0001)
#define TXFS_LOGGING_MODE_FULL          (0x0002)

#define TXFS_TRANSACTION_STATE_NONE         0x00
#define TXFS_TRANSACTION_STATE_ACTIVE       0x01
#define TXFS_TRANSACTION_STATE_PREPARED     0x02
#define TXFS_TRANSACTION_STATE_NOTACTIVE    0x03

#define TXFS_MODIFY_RM_VALID_FLAGS (TXFS_RM_FLAG_LOGGING_MODE                        | \
                                    TXFS_RM_FLAG_RENAME_RM                           | \
                                    TXFS_RM_FLAG_LOG_CONTAINER_COUNT_MAX             | \
                                    TXFS_RM_FLAG_LOG_CONTAINER_COUNT_MIN             | \
                                    TXFS_RM_FLAG_LOG_GROWTH_INCREMENT_NUM_CONTAINERS | \
                                    TXFS_RM_FLAG_LOG_GROWTH_INCREMENT_PERCENT        | \
                                    TXFS_RM_FLAG_LOG_AUTO_SHRINK_PERCENTAGE          | \
                                    TXFS_RM_FLAG_LOG_NO_CONTAINER_COUNT_MAX          | \
                                    TXFS_RM_FLAG_LOG_NO_CONTAINER_COUNT_MIN          | \
                                    TXFS_RM_FLAG_SHRINK_LOG                          | \
                                    TXFS_RM_FLAG_GROW_LOG                            | \
                                    TXFS_RM_FLAG_ENFORCE_MINIMUM_SIZE                | \
                                    TXFS_RM_FLAG_PRESERVE_CHANGES                    | \
                                    TXFS_RM_FLAG_RESET_RM_AT_NEXT_START              | \
                                    TXFS_RM_FLAG_DO_NOT_RESET_RM_AT_NEXT_START       | \
                                    TXFS_RM_FLAG_PREFER_CONSISTENCY                  | \
                                    TXFS_RM_FLAG_PREFER_AVAILABILITY)

typedef struct _TXFS_MODIFY_RM {
  ULONG Flags;
  ULONG LogContainerCountMax;
  ULONG LogContainerCountMin;
  ULONG LogContainerCount;
  ULONG LogGrowthIncrement;
  ULONG LogAutoShrinkPercentage;
  ULONGLONG Reserved;
  USHORT LoggingMode;
} TXFS_MODIFY_RM, *PTXFS_MODIFY_RM;

#define TXFS_RM_STATE_NOT_STARTED       0
#define TXFS_RM_STATE_STARTING          1
#define TXFS_RM_STATE_ACTIVE            2
#define TXFS_RM_STATE_SHUTTING_DOWN     3

#define TXFS_QUERY_RM_INFORMATION_VALID_FLAGS                           \
                (TXFS_RM_FLAG_LOG_GROWTH_INCREMENT_NUM_CONTAINERS   |   \
                 TXFS_RM_FLAG_LOG_GROWTH_INCREMENT_PERCENT          |   \
                 TXFS_RM_FLAG_LOG_NO_CONTAINER_COUNT_MAX            |   \
                 TXFS_RM_FLAG_LOG_NO_CONTAINER_COUNT_MIN            |   \
                 TXFS_RM_FLAG_RESET_RM_AT_NEXT_START                |   \
                 TXFS_RM_FLAG_DO_NOT_RESET_RM_AT_NEXT_START         |   \
                 TXFS_RM_FLAG_PREFER_CONSISTENCY                    |   \
                 TXFS_RM_FLAG_PREFER_AVAILABILITY)

typedef struct _TXFS_QUERY_RM_INFORMATION {
  ULONG BytesRequired;
  ULONGLONG TailLsn;
  ULONGLONG CurrentLsn;
  ULONGLONG ArchiveTailLsn;
  ULONGLONG LogContainerSize;
  LARGE_INTEGER HighestVirtualClock;
  ULONG LogContainerCount;
  ULONG LogContainerCountMax;
  ULONG LogContainerCountMin;
  ULONG LogGrowthIncrement;
  ULONG LogAutoShrinkPercentage;
  ULONG Flags;
  USHORT LoggingMode;
  USHORT Reserved;
  ULONG RmState;
  ULONGLONG LogCapacity;
  ULONGLONG LogFree;
  ULONGLONG TopsSize;
  ULONGLONG TopsUsed;
  ULONGLONG TransactionCount;
  ULONGLONG OnePCCount;
  ULONGLONG TwoPCCount;
  ULONGLONG NumberLogFileFull;
  ULONGLONG OldestTransactionAge;
  GUID RMName;
  ULONG TmLogPathOffset;
} TXFS_QUERY_RM_INFORMATION, *PTXFS_QUERY_RM_INFORMATION;

#define TXFS_ROLLFORWARD_REDO_FLAG_USE_LAST_REDO_LSN        0x01
#define TXFS_ROLLFORWARD_REDO_FLAG_USE_LAST_VIRTUAL_CLOCK   0x02

#define TXFS_ROLLFORWARD_REDO_VALID_FLAGS                               \
                (TXFS_ROLLFORWARD_REDO_FLAG_USE_LAST_REDO_LSN |         \
                 TXFS_ROLLFORWARD_REDO_FLAG_USE_LAST_VIRTUAL_CLOCK)

typedef struct _TXFS_ROLLFORWARD_REDO_INFORMATION {
  LARGE_INTEGER LastVirtualClock;
  ULONGLONG LastRedoLsn;
  ULONGLONG HighestRecoveryLsn;
  ULONG Flags;
} TXFS_ROLLFORWARD_REDO_INFORMATION, *PTXFS_ROLLFORWARD_REDO_INFORMATION;

#define TXFS_START_RM_FLAG_LOG_CONTAINER_COUNT_MAX              0x00000001
#define TXFS_START_RM_FLAG_LOG_CONTAINER_COUNT_MIN              0x00000002
#define TXFS_START_RM_FLAG_LOG_CONTAINER_SIZE                   0x00000004
#define TXFS_START_RM_FLAG_LOG_GROWTH_INCREMENT_NUM_CONTAINERS  0x00000008
#define TXFS_START_RM_FLAG_LOG_GROWTH_INCREMENT_PERCENT         0x00000010
#define TXFS_START_RM_FLAG_LOG_AUTO_SHRINK_PERCENTAGE           0x00000020
#define TXFS_START_RM_FLAG_LOG_NO_CONTAINER_COUNT_MAX           0x00000040
#define TXFS_START_RM_FLAG_LOG_NO_CONTAINER_COUNT_MIN           0x00000080

#define TXFS_START_RM_FLAG_RECOVER_BEST_EFFORT                  0x00000200
#define TXFS_START_RM_FLAG_LOGGING_MODE                         0x00000400
#define TXFS_START_RM_FLAG_PRESERVE_CHANGES                     0x00000800

#define TXFS_START_RM_FLAG_PREFER_CONSISTENCY                   0x00001000
#define TXFS_START_RM_FLAG_PREFER_AVAILABILITY                  0x00002000

#define TXFS_START_RM_VALID_FLAGS                                           \
                (TXFS_START_RM_FLAG_LOG_CONTAINER_COUNT_MAX             |   \
                 TXFS_START_RM_FLAG_LOG_CONTAINER_COUNT_MIN             |   \
                 TXFS_START_RM_FLAG_LOG_CONTAINER_SIZE                  |   \
                 TXFS_START_RM_FLAG_LOG_GROWTH_INCREMENT_NUM_CONTAINERS |   \
                 TXFS_START_RM_FLAG_LOG_GROWTH_INCREMENT_PERCENT        |   \
                 TXFS_START_RM_FLAG_LOG_AUTO_SHRINK_PERCENTAGE          |   \
                 TXFS_START_RM_FLAG_RECOVER_BEST_EFFORT                 |   \
                 TXFS_START_RM_FLAG_LOG_NO_CONTAINER_COUNT_MAX          |   \
                 TXFS_START_RM_FLAG_LOGGING_MODE                        |   \
                 TXFS_START_RM_FLAG_PRESERVE_CHANGES                    |   \
                 TXFS_START_RM_FLAG_PREFER_CONSISTENCY                  |   \
                 TXFS_START_RM_FLAG_PREFER_AVAILABILITY)

typedef struct _TXFS_START_RM_INFORMATION {
  ULONG Flags;
  ULONGLONG LogContainerSize;
  ULONG LogContainerCountMin;
  ULONG LogContainerCountMax;
  ULONG LogGrowthIncrement;
  ULONG LogAutoShrinkPercentage;
  ULONG TmLogPathOffset;
  USHORT TmLogPathLength;
  USHORT LoggingMode;
  USHORT LogPathLength;
  USHORT Reserved;
  WCHAR LogPath[1];
} TXFS_START_RM_INFORMATION, *PTXFS_START_RM_INFORMATION;

typedef struct _TXFS_GET_METADATA_INFO_OUT {
  struct {
    LONGLONG LowPart;
    LONGLONG HighPart;
  } TxfFileId;
  GUID LockingTransaction;
  ULONGLONG LastLsn;
  ULONG TransactionState;
} TXFS_GET_METADATA_INFO_OUT, *PTXFS_GET_METADATA_INFO_OUT;

#define TXFS_LIST_TRANSACTION_LOCKED_FILES_ENTRY_FLAG_CREATED   0x00000001
#define TXFS_LIST_TRANSACTION_LOCKED_FILES_ENTRY_FLAG_DELETED   0x00000002

typedef struct _TXFS_LIST_TRANSACTION_LOCKED_FILES_ENTRY {
  ULONGLONG Offset;
  ULONG NameFlags;
  LONGLONG FileId;
  ULONG Reserved1;
  ULONG Reserved2;
  LONGLONG Reserved3;
  WCHAR FileName[1];
} TXFS_LIST_TRANSACTION_LOCKED_FILES_ENTRY, *PTXFS_LIST_TRANSACTION_LOCKED_FILES_ENTRY;

typedef struct _TXFS_LIST_TRANSACTION_LOCKED_FILES {
  GUID KtmTransaction;
  ULONGLONG NumberOfFiles;
  ULONGLONG BufferSizeRequired;
  ULONGLONG Offset;
} TXFS_LIST_TRANSACTION_LOCKED_FILES, *PTXFS_LIST_TRANSACTION_LOCKED_FILES;

typedef struct _TXFS_LIST_TRANSACTIONS_ENTRY {
  GUID TransactionId;
  ULONG TransactionState;
  ULONG Reserved1;
  ULONG Reserved2;
  LONGLONG Reserved3;
} TXFS_LIST_TRANSACTIONS_ENTRY, *PTXFS_LIST_TRANSACTIONS_ENTRY;

typedef struct _TXFS_LIST_TRANSACTIONS {
  ULONGLONG NumberOfTransactions;
  ULONGLONG BufferSizeRequired;
} TXFS_LIST_TRANSACTIONS, *PTXFS_LIST_TRANSACTIONS;

typedef struct _TXFS_READ_BACKUP_INFORMATION_OUT {
  _ANONYMOUS_UNION union {
    ULONG BufferLength;
    UCHAR Buffer[1];
  } DUMMYUNIONNAME;
} TXFS_READ_BACKUP_INFORMATION_OUT, *PTXFS_READ_BACKUP_INFORMATION_OUT;

typedef struct _TXFS_WRITE_BACKUP_INFORMATION {
  UCHAR Buffer[1];
} TXFS_WRITE_BACKUP_INFORMATION, *PTXFS_WRITE_BACKUP_INFORMATION;

#define TXFS_TRANSACTED_VERSION_NONTRANSACTED   0xFFFFFFFE
#define TXFS_TRANSACTED_VERSION_UNCOMMITTED     0xFFFFFFFF

typedef struct _TXFS_GET_TRANSACTED_VERSION {
  ULONG ThisBaseVersion;
  ULONG LatestVersion;
  USHORT ThisMiniVersion;
  USHORT FirstMiniVersion;
  USHORT LatestMiniVersion;
} TXFS_GET_TRANSACTED_VERSION, *PTXFS_GET_TRANSACTED_VERSION;

#define TXFS_SAVEPOINT_SET                      0x00000001
#define TXFS_SAVEPOINT_ROLLBACK                 0x00000002
#define TXFS_SAVEPOINT_CLEAR                    0x00000004
#define TXFS_SAVEPOINT_CLEAR_ALL                0x00000010

typedef struct _TXFS_SAVEPOINT_INFORMATION {
  HANDLE KtmTransaction;
  ULONG ActionCode;
  ULONG SavepointId;
} TXFS_SAVEPOINT_INFORMATION, *PTXFS_SAVEPOINT_INFORMATION;

typedef struct _TXFS_CREATE_MINIVERSION_INFO {
  USHORT StructureVersion;
  USHORT StructureLength;
  ULONG BaseVersion;
  USHORT MiniVersion;
} TXFS_CREATE_MINIVERSION_INFO, *PTXFS_CREATE_MINIVERSION_INFO;

typedef struct _TXFS_TRANSACTION_ACTIVE_INFO {
  BOOLEAN TransactionsActiveAtSnapshot;
} TXFS_TRANSACTION_ACTIVE_INFO, *PTXFS_TRANSACTION_ACTIVE_INFO;

#endif /* (_WIN32_WINNT >= 0x0600) */

#if (_WIN32_WINNT >= 0x0601)

#define MARK_HANDLE_REALTIME                (0x00000020)
#define MARK_HANDLE_NOT_REALTIME            (0x00000040)

#define NO_8DOT3_NAME_PRESENT               (0x00000001)
#define REMOVED_8DOT3_NAME                  (0x00000002)

#define PERSISTENT_VOLUME_STATE_SHORT_NAME_CREATION_DISABLED        (0x00000001)

typedef struct _BOOT_AREA_INFO {
  ULONG BootSectorCount;
  struct {
    LARGE_INTEGER Offset;
  } BootSectors[2];
} BOOT_AREA_INFO, *PBOOT_AREA_INFO;

typedef struct _RETRIEVAL_POINTER_BASE {
  LARGE_INTEGER FileAreaOffset;
} RETRIEVAL_POINTER_BASE, *PRETRIEVAL_POINTER_BASE;

typedef struct _FILE_FS_PERSISTENT_VOLUME_INFORMATION {
  ULONG VolumeFlags;
  ULONG FlagMask;
  ULONG Version;
  ULONG Reserved;
} FILE_FS_PERSISTENT_VOLUME_INFORMATION, *PFILE_FS_PERSISTENT_VOLUME_INFORMATION;

typedef struct _FILE_SYSTEM_RECOGNITION_INFORMATION {
  CHAR FileSystem[9];
} FILE_SYSTEM_RECOGNITION_INFORMATION, *PFILE_SYSTEM_RECOGNITION_INFORMATION;

#define OPLOCK_LEVEL_CACHE_READ         (0x00000001)
#define OPLOCK_LEVEL_CACHE_HANDLE       (0x00000002)
#define OPLOCK_LEVEL_CACHE_WRITE        (0x00000004)

#define REQUEST_OPLOCK_INPUT_FLAG_REQUEST               (0x00000001)
#define REQUEST_OPLOCK_INPUT_FLAG_ACK                   (0x00000002)
#define REQUEST_OPLOCK_INPUT_FLAG_COMPLETE_ACK_ON_CLOSE (0x00000004)

#define REQUEST_OPLOCK_CURRENT_VERSION          1

typedef struct _REQUEST_OPLOCK_INPUT_BUFFER {
  USHORT StructureVersion;
  USHORT StructureLength;
  ULONG RequestedOplockLevel;
  ULONG Flags;
} REQUEST_OPLOCK_INPUT_BUFFER, *PREQUEST_OPLOCK_INPUT_BUFFER;

#define REQUEST_OPLOCK_OUTPUT_FLAG_ACK_REQUIRED     (0x00000001)
#define REQUEST_OPLOCK_OUTPUT_FLAG_MODES_PROVIDED   (0x00000002)

typedef struct _REQUEST_OPLOCK_OUTPUT_BUFFER {
  USHORT StructureVersion;
  USHORT StructureLength;
  ULONG OriginalOplockLevel;
  ULONG NewOplockLevel;
  ULONG Flags;
  ACCESS_MASK AccessMode;
  USHORT ShareMode;
} REQUEST_OPLOCK_OUTPUT_BUFFER, *PREQUEST_OPLOCK_OUTPUT_BUFFER;

#define SD_GLOBAL_CHANGE_TYPE_MACHINE_SID   1

typedef struct _SD_CHANGE_MACHINE_SID_INPUT {
  USHORT CurrentMachineSIDOffset;
  USHORT CurrentMachineSIDLength;
  USHORT NewMachineSIDOffset;
  USHORT NewMachineSIDLength;
} SD_CHANGE_MACHINE_SID_INPUT, *PSD_CHANGE_MACHINE_SID_INPUT;

typedef struct _SD_CHANGE_MACHINE_SID_OUTPUT {
  ULONGLONG NumSDChangedSuccess;
  ULONGLONG NumSDChangedFail;
  ULONGLONG NumSDUnused;
  ULONGLONG NumSDTotal;
  ULONGLONG NumMftSDChangedSuccess;
  ULONGLONG NumMftSDChangedFail;
  ULONGLONG NumMftSDTotal;
} SD_CHANGE_MACHINE_SID_OUTPUT, *PSD_CHANGE_MACHINE_SID_OUTPUT;

typedef struct _SD_GLOBAL_CHANGE_INPUT {
  ULONG Flags;
  ULONG ChangeType;
  _ANONYMOUS_UNION union {
    SD_CHANGE_MACHINE_SID_INPUT SdChange;
  } DUMMYUNIONNAME;
} SD_GLOBAL_CHANGE_INPUT, *PSD_GLOBAL_CHANGE_INPUT;

typedef struct _SD_GLOBAL_CHANGE_OUTPUT {
  ULONG Flags;
  ULONG ChangeType;
  _ANONYMOUS_UNION union {
    SD_CHANGE_MACHINE_SID_OUTPUT SdChange;
  } DUMMYUNIONNAME;
} SD_GLOBAL_CHANGE_OUTPUT, *PSD_GLOBAL_CHANGE_OUTPUT;

#define ENCRYPTED_DATA_INFO_SPARSE_FILE    1

typedef struct _EXTENDED_ENCRYPTED_DATA_INFO {
  ULONG ExtendedCode;
  ULONG Length;
  ULONG Flags;
  ULONG Reserved;
} EXTENDED_ENCRYPTED_DATA_INFO, *PEXTENDED_ENCRYPTED_DATA_INFO;

typedef struct _LOOKUP_STREAM_FROM_CLUSTER_INPUT {
  ULONG Flags;
  ULONG NumberOfClusters;
  LARGE_INTEGER Cluster[1];
} LOOKUP_STREAM_FROM_CLUSTER_INPUT, *PLOOKUP_STREAM_FROM_CLUSTER_INPUT;

typedef struct _LOOKUP_STREAM_FROM_CLUSTER_OUTPUT {
  ULONG Offset;
  ULONG NumberOfMatches;
  ULONG BufferSizeRequired;
} LOOKUP_STREAM_FROM_CLUSTER_OUTPUT, *PLOOKUP_STREAM_FROM_CLUSTER_OUTPUT;

#define LOOKUP_STREAM_FROM_CLUSTER_ENTRY_FLAG_PAGE_FILE          0x00000001
#define LOOKUP_STREAM_FROM_CLUSTER_ENTRY_FLAG_DENY_DEFRAG_SET    0x00000002
#define LOOKUP_STREAM_FROM_CLUSTER_ENTRY_FLAG_FS_SYSTEM_FILE     0x00000004
#define LOOKUP_STREAM_FROM_CLUSTER_ENTRY_FLAG_TXF_SYSTEM_FILE    0x00000008

#define LOOKUP_STREAM_FROM_CLUSTER_ENTRY_ATTRIBUTE_MASK          0xff000000
#define LOOKUP_STREAM_FROM_CLUSTER_ENTRY_ATTRIBUTE_DATA          0x01000000
#define LOOKUP_STREAM_FROM_CLUSTER_ENTRY_ATTRIBUTE_INDEX         0x02000000
#define LOOKUP_STREAM_FROM_CLUSTER_ENTRY_ATTRIBUTE_SYSTEM        0x03000000

typedef struct _LOOKUP_STREAM_FROM_CLUSTER_ENTRY {
  ULONG OffsetToNext;
  ULONG Flags;
  LARGE_INTEGER Reserved;
  LARGE_INTEGER Cluster;
  WCHAR FileName[1];
} LOOKUP_STREAM_FROM_CLUSTER_ENTRY, *PLOOKUP_STREAM_FROM_CLUSTER_ENTRY;

typedef struct _FILE_TYPE_NOTIFICATION_INPUT {
  ULONG Flags;
  ULONG NumFileTypeIDs;
  GUID FileTypeID[1];
} FILE_TYPE_NOTIFICATION_INPUT, *PFILE_TYPE_NOTIFICATION_INPUT;

#define FILE_TYPE_NOTIFICATION_FLAG_USAGE_BEGIN     0x00000001
#define FILE_TYPE_NOTIFICATION_FLAG_USAGE_END       0x00000002

DEFINE_GUID(FILE_TYPE_NOTIFICATION_GUID_PAGE_FILE,         0x0d0a64a1, 0x38fc, 0x4db8, 0x9f, 0xe7, 0x3f, 0x43, 0x52, 0xcd, 0x7c, 0x5c);
DEFINE_GUID(FILE_TYPE_NOTIFICATION_GUID_HIBERNATION_FILE,  0xb7624d64, 0xb9a3, 0x4cf8, 0x80, 0x11, 0x5b, 0x86, 0xc9, 0x40, 0xe7, 0xb7);
DEFINE_GUID(FILE_TYPE_NOTIFICATION_GUID_CRASHDUMP_FILE,    0x9d453eb7, 0xd2a6, 0x4dbd, 0xa2, 0xe3, 0xfb, 0xd0, 0xed, 0x91, 0x09, 0xa9);

#ifndef _VIRTUAL_STORAGE_TYPE_DEFINED
#define _VIRTUAL_STORAGE_TYPE_DEFINED
typedef struct _VIRTUAL_STORAGE_TYPE {
  ULONG DeviceId;
  GUID VendorId;
} VIRTUAL_STORAGE_TYPE, *PVIRTUAL_STORAGE_TYPE;
#endif

typedef struct _STORAGE_QUERY_DEPENDENT_VOLUME_REQUEST {
  ULONG RequestLevel;
  ULONG RequestFlags;
} STORAGE_QUERY_DEPENDENT_VOLUME_REQUEST, *PSTORAGE_QUERY_DEPENDENT_VOLUME_REQUEST;

#define QUERY_DEPENDENT_VOLUME_REQUEST_FLAG_HOST_VOLUMES    0x1
#define QUERY_DEPENDENT_VOLUME_REQUEST_FLAG_GUEST_VOLUMES   0x2

typedef struct _STORAGE_QUERY_DEPENDENT_VOLUME_LEV1_ENTRY {
  ULONG EntryLength;
  ULONG DependencyTypeFlags;
  ULONG ProviderSpecificFlags;
  VIRTUAL_STORAGE_TYPE VirtualStorageType;
} STORAGE_QUERY_DEPENDENT_VOLUME_LEV1_ENTRY, *PSTORAGE_QUERY_DEPENDENT_VOLUME_LEV1_ENTRY;

typedef struct _STORAGE_QUERY_DEPENDENT_VOLUME_LEV2_ENTRY {
  ULONG EntryLength;
  ULONG DependencyTypeFlags;
  ULONG ProviderSpecificFlags;
  VIRTUAL_STORAGE_TYPE VirtualStorageType;
  ULONG AncestorLevel;
  ULONG HostVolumeNameOffset;
  ULONG HostVolumeNameSize;
  ULONG DependentVolumeNameOffset;
  ULONG DependentVolumeNameSize;
  ULONG RelativePathOffset;
  ULONG RelativePathSize;
  ULONG DependentDeviceNameOffset;
  ULONG DependentDeviceNameSize;
} STORAGE_QUERY_DEPENDENT_VOLUME_LEV2_ENTRY, *PSTORAGE_QUERY_DEPENDENT_VOLUME_LEV2_ENTRY;

typedef struct _STORAGE_QUERY_DEPENDENT_VOLUME_RESPONSE {
  ULONG ResponseLevel;
  ULONG NumberEntries;
  _ANONYMOUS_UNION union {
    STORAGE_QUERY_DEPENDENT_VOLUME_LEV1_ENTRY Lev1Depends[0];
    STORAGE_QUERY_DEPENDENT_VOLUME_LEV2_ENTRY Lev2Depends[0];
  } DUMMYUNIONNAME;
} STORAGE_QUERY_DEPENDENT_VOLUME_RESPONSE, *PSTORAGE_QUERY_DEPENDENT_VOLUME_RESPONSE;

#endif /* (_WIN32_WINNT >= 0x0601) */

typedef struct _FILESYSTEM_STATISTICS {
  USHORT FileSystemType;
  USHORT Version;
  ULONG SizeOfCompleteStructure;
  ULONG UserFileReads;
  ULONG UserFileReadBytes;
  ULONG UserDiskReads;
  ULONG UserFileWrites;
  ULONG UserFileWriteBytes;
  ULONG UserDiskWrites;
  ULONG MetaDataReads;
  ULONG MetaDataReadBytes;
  ULONG MetaDataDiskReads;
  ULONG MetaDataWrites;
  ULONG MetaDataWriteBytes;
  ULONG MetaDataDiskWrites;
} FILESYSTEM_STATISTICS, *PFILESYSTEM_STATISTICS;

#define FILESYSTEM_STATISTICS_TYPE_NTFS     1
#define FILESYSTEM_STATISTICS_TYPE_FAT      2
#define FILESYSTEM_STATISTICS_TYPE_EXFAT    3

typedef struct _FAT_STATISTICS {
  ULONG CreateHits;
  ULONG SuccessfulCreates;
  ULONG FailedCreates;
  ULONG NonCachedReads;
  ULONG NonCachedReadBytes;
  ULONG NonCachedWrites;
  ULONG NonCachedWriteBytes;
  ULONG NonCachedDiskReads;
  ULONG NonCachedDiskWrites;
} FAT_STATISTICS, *PFAT_STATISTICS;

typedef struct _EXFAT_STATISTICS {
  ULONG CreateHits;
  ULONG SuccessfulCreates;
  ULONG FailedCreates;
  ULONG NonCachedReads;
  ULONG NonCachedReadBytes;
  ULONG NonCachedWrites;
  ULONG NonCachedWriteBytes;
  ULONG NonCachedDiskReads;
  ULONG NonCachedDiskWrites;
} EXFAT_STATISTICS, *PEXFAT_STATISTICS;

typedef struct _NTFS_STATISTICS {
  ULONG LogFileFullExceptions;
  ULONG OtherExceptions;
  ULONG MftReads;
  ULONG MftReadBytes;
  ULONG MftWrites;
  ULONG MftWriteBytes;
  struct {
    USHORT Write;
    USHORT Create;
    USHORT SetInfo;
    USHORT Flush;
  } MftWritesUserLevel;
  USHORT MftWritesFlushForLogFileFull;
  USHORT MftWritesLazyWriter;
  USHORT MftWritesUserRequest;
  ULONG Mft2Writes;
  ULONG Mft2WriteBytes;
  struct {
    USHORT Write;
    USHORT Create;
    USHORT SetInfo;
    USHORT Flush;
  } Mft2WritesUserLevel;
  USHORT Mft2WritesFlushForLogFileFull;
  USHORT Mft2WritesLazyWriter;
  USHORT Mft2WritesUserRequest;
  ULONG RootIndexReads;
  ULONG RootIndexReadBytes;
  ULONG RootIndexWrites;
  ULONG RootIndexWriteBytes;
  ULONG BitmapReads;
  ULONG BitmapReadBytes;
  ULONG BitmapWrites;
  ULONG BitmapWriteBytes;
  USHORT BitmapWritesFlushForLogFileFull;
  USHORT BitmapWritesLazyWriter;
  USHORT BitmapWritesUserRequest;
  struct {
    USHORT Write;
    USHORT Create;
    USHORT SetInfo;
  } BitmapWritesUserLevel;
  ULONG MftBitmapReads;
  ULONG MftBitmapReadBytes;
  ULONG MftBitmapWrites;
  ULONG MftBitmapWriteBytes;
  USHORT MftBitmapWritesFlushForLogFileFull;
  USHORT MftBitmapWritesLazyWriter;
  USHORT MftBitmapWritesUserRequest;
  struct {
    USHORT Write;
    USHORT Create;
    USHORT SetInfo;
    USHORT Flush;
  } MftBitmapWritesUserLevel;
  ULONG UserIndexReads;
  ULONG UserIndexReadBytes;
  ULONG UserIndexWrites;
  ULONG UserIndexWriteBytes;
  ULONG LogFileReads;
  ULONG LogFileReadBytes;
  ULONG LogFileWrites;
  ULONG LogFileWriteBytes;
  struct {
    ULONG Calls;
    ULONG Clusters;
    ULONG Hints;
    ULONG RunsReturned;
    ULONG HintsHonored;
    ULONG HintsClusters;
    ULONG Cache;
    ULONG CacheClusters;
    ULONG CacheMiss;
    ULONG CacheMissClusters;
  } Allocate;
} NTFS_STATISTICS, *PNTFS_STATISTICS;

#endif /* _FILESYSTEMFSCTL_ */

#define SYMLINK_FLAG_RELATIVE   1

typedef struct _REPARSE_DATA_BUFFER {
  ULONG ReparseTag;
  USHORT ReparseDataLength;
  USHORT Reserved;
  _ANONYMOUS_UNION union {
    struct {
      USHORT SubstituteNameOffset;
      USHORT SubstituteNameLength;
      USHORT PrintNameOffset;
      USHORT PrintNameLength;
      ULONG Flags;
      WCHAR PathBuffer[1];
    } SymbolicLinkReparseBuffer;
    struct {
      USHORT SubstituteNameOffset;
      USHORT SubstituteNameLength;
      USHORT PrintNameOffset;
      USHORT PrintNameLength;
      WCHAR PathBuffer[1];
    } MountPointReparseBuffer;
    struct {
      UCHAR DataBuffer[1];
    } GenericReparseBuffer;
  } DUMMYUNIONNAME;
} REPARSE_DATA_BUFFER, *PREPARSE_DATA_BUFFER;

#define REPARSE_DATA_BUFFER_HEADER_SIZE   FIELD_OFFSET(REPARSE_DATA_BUFFER, GenericReparseBuffer)

typedef struct _REPARSE_GUID_DATA_BUFFER {
  ULONG ReparseTag;
  USHORT ReparseDataLength;
  USHORT Reserved;
  GUID ReparseGuid;
  struct {
    UCHAR DataBuffer[1];
  } GenericReparseBuffer;
} REPARSE_GUID_DATA_BUFFER, *PREPARSE_GUID_DATA_BUFFER;

#define REPARSE_GUID_DATA_BUFFER_HEADER_SIZE   FIELD_OFFSET(REPARSE_GUID_DATA_BUFFER, GenericReparseBuffer)

#define MAXIMUM_REPARSE_DATA_BUFFER_SIZE      ( 16 * 1024 )

/* Reserved reparse tags */
#define IO_REPARSE_TAG_RESERVED_ZERO            (0)
#define IO_REPARSE_TAG_RESERVED_ONE             (1)
#define IO_REPARSE_TAG_RESERVED_RANGE           IO_REPARSE_TAG_RESERVED_ONE

#define IsReparseTagMicrosoft(_tag)             (((_tag) & 0x80000000))
#define IsReparseTagNameSurrogate(_tag)         (((_tag) & 0x20000000))

#define IO_REPARSE_TAG_VALID_VALUES             (0xF000FFFF)

#define IsReparseTagValid(tag) (                               \
                  !((tag) & ~IO_REPARSE_TAG_VALID_VALUES) &&   \
                  ((tag) > IO_REPARSE_TAG_RESERVED_RANGE)      \
                )

/* MicroSoft reparse point tags */
#define IO_REPARSE_TAG_MOUNT_POINT              (0xA0000003L)
#define IO_REPARSE_TAG_HSM                      (0xC0000004L)
#define IO_REPARSE_TAG_DRIVE_EXTENDER           (0x80000005L)
#define IO_REPARSE_TAG_HSM2                     (0x80000006L)
#define IO_REPARSE_TAG_SIS                      (0x80000007L)
#define IO_REPARSE_TAG_WIM                      (0x80000008L)
#define IO_REPARSE_TAG_CSV                      (0x80000009L)
#define IO_REPARSE_TAG_DFS                      (0x8000000AL)
#define IO_REPARSE_TAG_FILTER_MANAGER           (0x8000000BL)
#define IO_REPARSE_TAG_SYMLINK                  (0xA000000CL)
#define IO_REPARSE_TAG_IIS_CACHE                (0xA0000010L)
#define IO_REPARSE_TAG_DFSR                     (0x80000012L)

#pragma pack(4)
typedef struct _REPARSE_INDEX_KEY {
  ULONG FileReparseTag;
  LARGE_INTEGER FileId;
} REPARSE_INDEX_KEY, *PREPARSE_INDEX_KEY;
#pragma pack()

#define FSCTL_LMR_GET_LINK_TRACKING_INFORMATION   CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM,58,METHOD_BUFFERED,FILE_ANY_ACCESS)
#define FSCTL_LMR_SET_LINK_TRACKING_INFORMATION   CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM,59,METHOD_BUFFERED,FILE_ANY_ACCESS)
#define IOCTL_LMR_ARE_FILE_OBJECTS_ON_SAME_SERVER CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM,60,METHOD_BUFFERED,FILE_ANY_ACCESS)

#define FSCTL_PIPE_ASSIGN_EVENT             CTL_CODE(FILE_DEVICE_NAMED_PIPE, 0, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_DISCONNECT               CTL_CODE(FILE_DEVICE_NAMED_PIPE, 1, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_LISTEN                   CTL_CODE(FILE_DEVICE_NAMED_PIPE, 2, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_PEEK                     CTL_CODE(FILE_DEVICE_NAMED_PIPE, 3, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_PIPE_QUERY_EVENT              CTL_CODE(FILE_DEVICE_NAMED_PIPE, 4, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_TRANSCEIVE               CTL_CODE(FILE_DEVICE_NAMED_PIPE, 5, METHOD_NEITHER,  FILE_READ_DATA | FILE_WRITE_DATA)
#define FSCTL_PIPE_WAIT                     CTL_CODE(FILE_DEVICE_NAMED_PIPE, 6, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_IMPERSONATE              CTL_CODE(FILE_DEVICE_NAMED_PIPE, 7, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_SET_CLIENT_PROCESS       CTL_CODE(FILE_DEVICE_NAMED_PIPE, 8, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_QUERY_CLIENT_PROCESS     CTL_CODE(FILE_DEVICE_NAMED_PIPE, 9, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_GET_PIPE_ATTRIBUTE       CTL_CODE(FILE_DEVICE_NAMED_PIPE, 10, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_SET_PIPE_ATTRIBUTE       CTL_CODE(FILE_DEVICE_NAMED_PIPE, 11, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_GET_CONNECTION_ATTRIBUTE CTL_CODE(FILE_DEVICE_NAMED_PIPE, 12, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_SET_CONNECTION_ATTRIBUTE CTL_CODE(FILE_DEVICE_NAMED_PIPE, 13, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_GET_HANDLE_ATTRIBUTE     CTL_CODE(FILE_DEVICE_NAMED_PIPE, 14, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_SET_HANDLE_ATTRIBUTE     CTL_CODE(FILE_DEVICE_NAMED_PIPE, 15, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_PIPE_FLUSH                    CTL_CODE(FILE_DEVICE_NAMED_PIPE, 16, METHOD_BUFFERED, FILE_WRITE_DATA)

#define FSCTL_PIPE_INTERNAL_READ            CTL_CODE(FILE_DEVICE_NAMED_PIPE, 2045, METHOD_BUFFERED, FILE_READ_DATA)
#define FSCTL_PIPE_INTERNAL_WRITE           CTL_CODE(FILE_DEVICE_NAMED_PIPE, 2046, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_PIPE_INTERNAL_TRANSCEIVE      CTL_CODE(FILE_DEVICE_NAMED_PIPE, 2047, METHOD_NEITHER, FILE_READ_DATA | FILE_WRITE_DATA)
#define FSCTL_PIPE_INTERNAL_READ_OVFLOW     CTL_CODE(FILE_DEVICE_NAMED_PIPE, 2048, METHOD_BUFFERED, FILE_READ_DATA)

#define FILE_PIPE_READ_DATA                 0x00000000
#define FILE_PIPE_WRITE_SPACE               0x00000001

typedef struct _FILE_PIPE_ASSIGN_EVENT_BUFFER {
  HANDLE EventHandle;
  ULONG KeyValue;
} FILE_PIPE_ASSIGN_EVENT_BUFFER, *PFILE_PIPE_ASSIGN_EVENT_BUFFER;

typedef struct _FILE_PIPE_EVENT_BUFFER {
  ULONG NamedPipeState;
  ULONG EntryType;
  ULONG ByteCount;
  ULONG KeyValue;
  ULONG NumberRequests;
} FILE_PIPE_EVENT_BUFFER, *PFILE_PIPE_EVENT_BUFFER;

typedef struct _FILE_PIPE_PEEK_BUFFER {
  ULONG NamedPipeState;
  ULONG ReadDataAvailable;
  ULONG NumberOfMessages;
  ULONG MessageLength;
  CHAR Data[1];
} FILE_PIPE_PEEK_BUFFER, *PFILE_PIPE_PEEK_BUFFER;

typedef struct _FILE_PIPE_WAIT_FOR_BUFFER {
  LARGE_INTEGER Timeout;
  ULONG NameLength;
  BOOLEAN TimeoutSpecified;
  WCHAR Name[1];
} FILE_PIPE_WAIT_FOR_BUFFER, *PFILE_PIPE_WAIT_FOR_BUFFER;

typedef struct _FILE_PIPE_CLIENT_PROCESS_BUFFER {
#if !defined(BUILD_WOW6432)
  PVOID ClientSession;
  PVOID ClientProcess;
#else
  ULONGLONG ClientSession;
  ULONGLONG ClientProcess;
#endif
} FILE_PIPE_CLIENT_PROCESS_BUFFER, *PFILE_PIPE_CLIENT_PROCESS_BUFFER;

#define FILE_PIPE_COMPUTER_NAME_LENGTH 15

typedef struct _FILE_PIPE_CLIENT_PROCESS_BUFFER_EX {
#if !defined(BUILD_WOW6432)
  PVOID ClientSession;
  PVOID ClientProcess;
#else
  ULONGLONG ClientSession;
  ULONGLONG ClientProcess;
#endif
  USHORT ClientComputerNameLength;
  WCHAR ClientComputerBuffer[FILE_PIPE_COMPUTER_NAME_LENGTH+1];
} FILE_PIPE_CLIENT_PROCESS_BUFFER_EX, *PFILE_PIPE_CLIENT_PROCESS_BUFFER_EX;

#define FSCTL_MAILSLOT_PEEK             CTL_CODE(FILE_DEVICE_MAILSLOT, 0, METHOD_NEITHER, FILE_READ_DATA)

typedef enum _LINK_TRACKING_INFORMATION_TYPE {
  NtfsLinkTrackingInformation,
  DfsLinkTrackingInformation
} LINK_TRACKING_INFORMATION_TYPE, *PLINK_TRACKING_INFORMATION_TYPE;

typedef struct _LINK_TRACKING_INFORMATION {
  LINK_TRACKING_INFORMATION_TYPE Type;
  UCHAR VolumeId[16];
} LINK_TRACKING_INFORMATION, *PLINK_TRACKING_INFORMATION;

typedef struct _REMOTE_LINK_TRACKING_INFORMATION {
  PVOID TargetFileObject;
  ULONG TargetLinkTrackingInformationLength;
  UCHAR TargetLinkTrackingInformationBuffer[1];
} REMOTE_LINK_TRACKING_INFORMATION, *PREMOTE_LINK_TRACKING_INFORMATION;

#define IO_OPEN_PAGING_FILE                 0x0002
#define IO_OPEN_TARGET_DIRECTORY            0x0004
#define IO_STOP_ON_SYMLINK                  0x0008
#define IO_MM_PAGING_FILE                   0x0010

typedef VOID
(NTAPI *PDRIVER_FS_NOTIFICATION) (
  IN PDEVICE_OBJECT DeviceObject,
  IN BOOLEAN FsActive);

typedef enum _FS_FILTER_SECTION_SYNC_TYPE {
  SyncTypeOther = 0,
  SyncTypeCreateSection
} FS_FILTER_SECTION_SYNC_TYPE, *PFS_FILTER_SECTION_SYNC_TYPE;

typedef enum _FS_FILTER_STREAM_FO_NOTIFICATION_TYPE {
  NotifyTypeCreate = 0,
  NotifyTypeRetired
} FS_FILTER_STREAM_FO_NOTIFICATION_TYPE, *PFS_FILTER_STREAM_FO_NOTIFICATION_TYPE;

typedef union _FS_FILTER_PARAMETERS {
  struct {
    PLARGE_INTEGER EndingOffset;
    PERESOURCE *ResourceToRelease;
  } AcquireForModifiedPageWriter;
  struct {
    PERESOURCE ResourceToRelease;
  } ReleaseForModifiedPageWriter;
  struct {
    FS_FILTER_SECTION_SYNC_TYPE SyncType;
    ULONG PageProtection;
  } AcquireForSectionSynchronization;
  struct {
    FS_FILTER_STREAM_FO_NOTIFICATION_TYPE NotificationType;
    BOOLEAN POINTER_ALIGNMENT SafeToRecurse;
  } NotifyStreamFileObject;
  struct {
    PVOID Argument1;
    PVOID Argument2;
    PVOID Argument3;
    PVOID Argument4;
    PVOID Argument5;
  } Others;
} FS_FILTER_PARAMETERS, *PFS_FILTER_PARAMETERS;

#define FS_FILTER_ACQUIRE_FOR_SECTION_SYNCHRONIZATION      (UCHAR)-1
#define FS_FILTER_RELEASE_FOR_SECTION_SYNCHRONIZATION      (UCHAR)-2
#define FS_FILTER_ACQUIRE_FOR_MOD_WRITE                    (UCHAR)-3
#define FS_FILTER_RELEASE_FOR_MOD_WRITE                    (UCHAR)-4
#define FS_FILTER_ACQUIRE_FOR_CC_FLUSH                     (UCHAR)-5
#define FS_FILTER_RELEASE_FOR_CC_FLUSH                     (UCHAR)-6

typedef struct _FS_FILTER_CALLBACK_DATA {
  ULONG SizeOfFsFilterCallbackData;
  UCHAR Operation;
  UCHAR Reserved;
  struct _DEVICE_OBJECT *DeviceObject;
  struct _FILE_OBJECT *FileObject;
  FS_FILTER_PARAMETERS Parameters;
} FS_FILTER_CALLBACK_DATA, *PFS_FILTER_CALLBACK_DATA;

typedef NTSTATUS
(NTAPI *PFS_FILTER_CALLBACK) (
  IN PFS_FILTER_CALLBACK_DATA Data,
  OUT PVOID *CompletionContext);

typedef VOID
(NTAPI *PFS_FILTER_COMPLETION_CALLBACK) (
  IN PFS_FILTER_CALLBACK_DATA Data,
  IN NTSTATUS OperationStatus,
  IN PVOID CompletionContext);

typedef struct _FS_FILTER_CALLBACKS {
  ULONG SizeOfFsFilterCallbacks;
  ULONG Reserved;
  PFS_FILTER_CALLBACK PreAcquireForSectionSynchronization;
  PFS_FILTER_COMPLETION_CALLBACK PostAcquireForSectionSynchronization;
  PFS_FILTER_CALLBACK PreReleaseForSectionSynchronization;
  PFS_FILTER_COMPLETION_CALLBACK PostReleaseForSectionSynchronization;
  PFS_FILTER_CALLBACK PreAcquireForCcFlush;
  PFS_FILTER_COMPLETION_CALLBACK PostAcquireForCcFlush;
  PFS_FILTER_CALLBACK PreReleaseForCcFlush;
  PFS_FILTER_COMPLETION_CALLBACK PostReleaseForCcFlush;
  PFS_FILTER_CALLBACK PreAcquireForModifiedPageWriter;
  PFS_FILTER_COMPLETION_CALLBACK PostAcquireForModifiedPageWriter;
  PFS_FILTER_CALLBACK PreReleaseForModifiedPageWriter;
  PFS_FILTER_COMPLETION_CALLBACK PostReleaseForModifiedPageWriter;
} FS_FILTER_CALLBACKS, *PFS_FILTER_CALLBACKS;

#if (NTDDI_VERSION >= NTDDI_WINXP)
NTKERNELAPI
NTSTATUS
NTAPI
FsRtlRegisterFileSystemFilterCallbacks(
  IN struct _DRIVER_OBJECT *FilterDriverObject,
  IN PFS_FILTER_CALLBACKS Callbacks);
#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_VISTA)
NTKERNELAPI
NTSTATUS
NTAPI
FsRtlNotifyStreamFileObject(
  IN struct _FILE_OBJECT * StreamFileObject,
  IN struct _DEVICE_OBJECT *DeviceObjectHint OPTIONAL,
  IN FS_FILTER_STREAM_FO_NOTIFICATION_TYPE NotificationType,
  IN BOOLEAN SafeToRecurse);
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#define DO_VERIFY_VOLUME                    0x00000002
#define DO_BUFFERED_IO                      0x00000004
#define DO_EXCLUSIVE                        0x00000008
#define DO_DIRECT_IO                        0x00000010
#define DO_MAP_IO_BUFFER                    0x00000020
#define DO_DEVICE_HAS_NAME                  0x00000040
#define DO_DEVICE_INITIALIZING              0x00000080
#define DO_SYSTEM_BOOT_PARTITION            0x00000100
#define DO_LONG_TERM_REQUESTS               0x00000200
#define DO_NEVER_LAST_DEVICE                0x00000400
#define DO_SHUTDOWN_REGISTERED              0x00000800
#define DO_BUS_ENUMERATED_DEVICE            0x00001000
#define DO_POWER_PAGABLE                    0x00002000
#define DO_POWER_INRUSH                     0x00004000
#define DO_LOW_PRIORITY_FILESYSTEM          0x00010000
#define DO_SUPPORTS_TRANSACTIONS            0x00040000
#define DO_FORCE_NEITHER_IO                 0x00080000
#define DO_VOLUME_DEVICE_OBJECT             0x00100000
#define DO_SYSTEM_SYSTEM_PARTITION          0x00200000
#define DO_SYSTEM_CRITICAL_PARTITION        0x00400000
#define DO_DISALLOW_EXECUTE                 0x00800000

extern KSPIN_LOCK                   IoStatisticsLock;
extern ULONG                        IoReadOperationCount;
extern ULONG                        IoWriteOperationCount;
extern ULONG                        IoOtherOperationCount;
extern LARGE_INTEGER                IoReadTransferCount;
extern LARGE_INTEGER                IoWriteTransferCount;
extern LARGE_INTEGER                IoOtherTransferCount;

#define IO_FILE_OBJECT_NON_PAGED_POOL_CHARGE    64
#define IO_FILE_OBJECT_PAGED_POOL_CHARGE        1024

#if (NTDDI_VERSION >= NTDDI_VISTA)
typedef struct _IO_PRIORITY_INFO {
  ULONG Size;
  ULONG ThreadPriority;
  ULONG PagePriority;
  IO_PRIORITY_HINT IoPriority;
} IO_PRIORITY_INFO, *PIO_PRIORITY_INFO;
#endif

typedef struct _PUBLIC_OBJECT_BASIC_INFORMATION {
  ULONG Attributes;
  ACCESS_MASK GrantedAccess;
  ULONG HandleCount;
  ULONG PointerCount;
  ULONG Reserved[10];
} PUBLIC_OBJECT_BASIC_INFORMATION, *PPUBLIC_OBJECT_BASIC_INFORMATION;

typedef struct _PUBLIC_OBJECT_TYPE_INFORMATION {
  UNICODE_STRING TypeName;
  ULONG Reserved [22];
} PUBLIC_OBJECT_TYPE_INFORMATION, *PPUBLIC_OBJECT_TYPE_INFORMATION;

typedef struct _SECURITY_CLIENT_CONTEXT {
  SECURITY_QUALITY_OF_SERVICE SecurityQos;
  PACCESS_TOKEN ClientToken;
  BOOLEAN DirectlyAccessClientToken;
  BOOLEAN DirectAccessEffectiveOnly;
  BOOLEAN ServerIsRemote;
  TOKEN_CONTROL ClientTokenControl;
} SECURITY_CLIENT_CONTEXT, *PSECURITY_CLIENT_CONTEXT;

#define SYSTEM_PAGE_PRIORITY_BITS       3
#define SYSTEM_PAGE_PRIORITY_LEVELS     (1 << SYSTEM_PAGE_PRIORITY_BITS)

typedef struct _KAPC_STATE {
  LIST_ENTRY ApcListHead[MaximumMode];
  PKPROCESS Process;
  BOOLEAN KernelApcInProgress;
  BOOLEAN KernelApcPending;
  BOOLEAN UserApcPending;
} KAPC_STATE, *PKAPC_STATE, *RESTRICTED_POINTER PRKAPC_STATE;

#define KAPC_STATE_ACTUAL_LENGTH (FIELD_OFFSET(KAPC_STATE, UserApcPending) + sizeof(BOOLEAN))

#define ASSERT_QUEUE(Q) ASSERT(((Q)->Header.Type & KOBJECT_TYPE_MASK) == QueueObject);

typedef struct _KQUEUE {
  DISPATCHER_HEADER Header;
  LIST_ENTRY EntryListHead;
  volatile ULONG CurrentCount;
  ULONG MaximumCount;
  LIST_ENTRY ThreadListHead;
} KQUEUE, *PKQUEUE, *RESTRICTED_POINTER PRKQUEUE;

/******************************************************************************
 *                              Kernel Functions                              *
 ******************************************************************************/

NTSTATUS
NTAPI
KeGetProcessorNumberFromIndex(
  IN ULONG ProcIndex,
  OUT PPROCESSOR_NUMBER ProcNumber);

ULONG
NTAPI
KeGetProcessorIndexFromNumber(
  IN PPROCESSOR_NUMBER ProcNumber);

#if (NTDDI_VERSION >= NTDDI_WIN2K)




NTKERNELAPI
VOID
NTAPI
KeInitializeMutant(
  OUT PRKMUTANT Mutant,
  IN BOOLEAN InitialOwner);

NTKERNELAPI
LONG
NTAPI
KeReadStateMutant(
  IN PRKMUTANT Mutant);

NTKERNELAPI
LONG
NTAPI
KeReleaseMutant(
  IN OUT PRKMUTANT Mutant,
  IN KPRIORITY Increment,
  IN BOOLEAN Abandoned,
  IN BOOLEAN Wait);

NTKERNELAPI
VOID
NTAPI
KeInitializeQueue(
  OUT PRKQUEUE Queue,
  IN ULONG Count);

NTKERNELAPI
LONG
NTAPI
KeReadStateQueue(
  IN PRKQUEUE Queue);

NTKERNELAPI
LONG
NTAPI
KeInsertQueue(
  IN OUT PRKQUEUE Queue,
  IN OUT PLIST_ENTRY Entry);

NTKERNELAPI
LONG
NTAPI
KeInsertHeadQueue(
  IN OUT PRKQUEUE Queue,
  IN OUT PLIST_ENTRY Entry);

NTKERNELAPI
PLIST_ENTRY
NTAPI
KeRemoveQueue(
  IN OUT PRKQUEUE Queue,
  IN KPROCESSOR_MODE WaitMode,
  IN PLARGE_INTEGER Timeout OPTIONAL);

NTKERNELAPI
VOID
NTAPI
KeAttachProcess(
  IN OUT PKPROCESS Process);

NTKERNELAPI
VOID
NTAPI
KeDetachProcess(
  VOID);

NTKERNELAPI
PLIST_ENTRY
NTAPI
KeRundownQueue(
  IN OUT PRKQUEUE Queue);

NTKERNELAPI
VOID
NTAPI
KeStackAttachProcess(
  IN OUT PKPROCESS Process,
  OUT PKAPC_STATE ApcState);

NTKERNELAPI
VOID
NTAPI
KeUnstackDetachProcess(
  IN PKAPC_STATE ApcState);

NTKERNELAPI
UCHAR
NTAPI
KeSetIdealProcessorThread(
  IN OUT PKTHREAD Thread,
  IN UCHAR Processor);

NTKERNELAPI
BOOLEAN
NTAPI
KeSetKernelStackSwapEnable(
  IN BOOLEAN Enable);

#if defined(_X86_)
NTHALAPI
KIRQL
FASTCALL
KeAcquireSpinLockRaiseToSynch(
  IN OUT PKSPIN_LOCK SpinLock);
#else
NTKERNELAPI
KIRQL
KeAcquireSpinLockRaiseToSynch(
  IN OUT PKSPIN_LOCK SpinLock);
#endif

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

_DECL_HAL_KE_IMPORT
KIRQL
FASTCALL
KeAcquireQueuedSpinLock(
  IN OUT KSPIN_LOCK_QUEUE_NUMBER Number);

_DECL_HAL_KE_IMPORT
VOID
FASTCALL
KeReleaseQueuedSpinLock(
  IN OUT KSPIN_LOCK_QUEUE_NUMBER Number,
  IN KIRQL OldIrql);

_DECL_HAL_KE_IMPORT
LOGICAL
FASTCALL
KeTryToAcquireQueuedSpinLock(
  IN KSPIN_LOCK_QUEUE_NUMBER Number,
  OUT PKIRQL OldIrql);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */



#if (NTDDI_VERSION >= NTDDI_VISTA)

NTKERNELAPI
VOID
KeQueryOwnerMutant(
  IN PKMUTANT Mutant,
  OUT PCLIENT_ID ClientId);

NTKERNELAPI
ULONG
KeRemoveQueueEx (
  IN OUT PKQUEUE Queue,
  IN KPROCESSOR_MODE WaitMode,
  IN BOOLEAN Alertable,
  IN PLARGE_INTEGER Timeout OPTIONAL,
  OUT PLIST_ENTRY *EntryArray,
  IN ULONG Count);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */



#define INVALID_PROCESSOR_INDEX     0xffffffff

#define EX_PUSH_LOCK ULONG_PTR
#define PEX_PUSH_LOCK PULONG_PTR

/******************************************************************************
 *                          Executive Functions                               *
 ******************************************************************************/

#define ExDisableResourceBoost ExDisableResourceBoostLite

VOID
ExInitializePushLock (
  OUT PEX_PUSH_LOCK PushLock);

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
SIZE_T
NTAPI
ExQueryPoolBlockSize(
  IN PVOID PoolBlock,
  OUT PBOOLEAN QuotaCharged);

VOID
ExAdjustLookasideDepth(
  VOID);

NTKERNELAPI
VOID
NTAPI
ExDisableResourceBoostLite(
  IN PERESOURCE Resource);
#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

PSLIST_ENTRY
FASTCALL
InterlockedPushListSList(
  IN OUT PSLIST_HEADER ListHead,
  IN OUT PSLIST_ENTRY List,
  IN OUT PSLIST_ENTRY ListEnd,
  IN ULONG Count);
#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

/******************************************************************************
 *                            Security Manager Functions                      *
 ******************************************************************************/

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
VOID
NTAPI
SeReleaseSubjectContext(
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext);

NTKERNELAPI
BOOLEAN
NTAPI
SePrivilegeCheck(
  IN OUT PPRIVILEGE_SET RequiredPrivileges,
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext,
  IN KPROCESSOR_MODE AccessMode);

NTKERNELAPI
VOID
NTAPI
SeOpenObjectAuditAlarm(
  IN PUNICODE_STRING ObjectTypeName,
  IN PVOID Object OPTIONAL,
  IN PUNICODE_STRING AbsoluteObjectName OPTIONAL,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PACCESS_STATE AccessState,
  IN BOOLEAN ObjectCreated,
  IN BOOLEAN AccessGranted,
  IN KPROCESSOR_MODE AccessMode,
  OUT PBOOLEAN GenerateOnClose);

NTKERNELAPI
VOID
NTAPI
SeOpenObjectForDeleteAuditAlarm(
  IN PUNICODE_STRING ObjectTypeName,
  IN PVOID Object OPTIONAL,
  IN PUNICODE_STRING AbsoluteObjectName OPTIONAL,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PACCESS_STATE AccessState,
  IN BOOLEAN ObjectCreated,
  IN BOOLEAN AccessGranted,
  IN KPROCESSOR_MODE AccessMode,
  OUT PBOOLEAN GenerateOnClose);

NTKERNELAPI
VOID
NTAPI
SeDeleteObjectAuditAlarm(
  IN PVOID Object,
  IN HANDLE Handle);

NTKERNELAPI
TOKEN_TYPE
NTAPI
SeTokenType(
  IN PACCESS_TOKEN Token);

NTKERNELAPI
BOOLEAN
NTAPI
SeTokenIsAdmin(
  IN PACCESS_TOKEN Token);

NTKERNELAPI
BOOLEAN
NTAPI
SeTokenIsRestricted(
  IN PACCESS_TOKEN Token);

NTKERNELAPI
NTSTATUS
NTAPI
SeQueryAuthenticationIdToken(
  IN PACCESS_TOKEN Token,
  OUT PLUID AuthenticationId);

NTKERNELAPI
NTSTATUS
NTAPI
SeQuerySessionIdToken(
  IN PACCESS_TOKEN Token,
  OUT PULONG SessionId);

NTKERNELAPI
NTSTATUS
NTAPI
SeCreateClientSecurity(
  IN PETHREAD ClientThread,
  IN PSECURITY_QUALITY_OF_SERVICE ClientSecurityQos,
  IN BOOLEAN RemoteSession,
  OUT PSECURITY_CLIENT_CONTEXT ClientContext);

NTKERNELAPI
VOID
NTAPI
SeImpersonateClient(
  IN PSECURITY_CLIENT_CONTEXT ClientContext,
  IN PETHREAD ServerThread OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
SeImpersonateClientEx(
  IN PSECURITY_CLIENT_CONTEXT ClientContext,
  IN PETHREAD ServerThread OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
SeCreateClientSecurityFromSubjectContext(
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext,
  IN PSECURITY_QUALITY_OF_SERVICE ClientSecurityQos,
  IN BOOLEAN ServerIsRemote,
  OUT PSECURITY_CLIENT_CONTEXT ClientContext);

NTKERNELAPI
NTSTATUS
NTAPI
SeQuerySecurityDescriptorInfo(
  IN PSECURITY_INFORMATION SecurityInformation,
  OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN OUT PULONG Length,
  IN OUT PSECURITY_DESCRIPTOR *ObjectsSecurityDescriptor);

NTKERNELAPI
NTSTATUS
NTAPI
SeSetSecurityDescriptorInfo(
  IN PVOID Object OPTIONAL,
  IN PSECURITY_INFORMATION SecurityInformation,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN OUT PSECURITY_DESCRIPTOR *ObjectsSecurityDescriptor,
  IN POOL_TYPE PoolType,
  IN PGENERIC_MAPPING GenericMapping);

NTKERNELAPI
NTSTATUS
NTAPI
SeSetSecurityDescriptorInfoEx(
  IN PVOID Object OPTIONAL,
  IN PSECURITY_INFORMATION SecurityInformation,
  IN PSECURITY_DESCRIPTOR ModificationDescriptor,
  IN OUT PSECURITY_DESCRIPTOR *ObjectsSecurityDescriptor,
  IN ULONG AutoInheritFlags,
  IN POOL_TYPE PoolType,
  IN PGENERIC_MAPPING GenericMapping);

NTKERNELAPI
NTSTATUS
NTAPI
SeAppendPrivileges(
  IN OUT PACCESS_STATE AccessState,
  IN PPRIVILEGE_SET Privileges);

NTKERNELAPI
BOOLEAN
NTAPI
SeAuditingFileEvents(
  IN BOOLEAN AccessGranted,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);

NTKERNELAPI
BOOLEAN
NTAPI
SeAuditingFileOrGlobalEvents(
  IN BOOLEAN AccessGranted,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSECURITY_SUBJECT_CONTEXT SubjectSecurityContext);

VOID
NTAPI
SeSetAccessStateGenericMapping(
  IN OUT PACCESS_STATE AccessState,
  IN PGENERIC_MAPPING GenericMapping);

NTKERNELAPI
NTSTATUS
NTAPI
SeRegisterLogonSessionTerminatedRoutine(
  IN PSE_LOGON_SESSION_TERMINATED_ROUTINE CallbackRoutine);

NTKERNELAPI
NTSTATUS
NTAPI
SeUnregisterLogonSessionTerminatedRoutine(
  IN PSE_LOGON_SESSION_TERMINATED_ROUTINE CallbackRoutine);

NTKERNELAPI
NTSTATUS
NTAPI
SeMarkLogonSessionForTerminationNotification(
  IN PLUID LogonId);

NTKERNELAPI
NTSTATUS
NTAPI
SeQueryInformationToken(
  IN PACCESS_TOKEN Token,
  IN TOKEN_INFORMATION_CLASS TokenInformationClass,
  OUT PVOID *TokenInformation);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */
#if (NTDDI_VERSION >= NTDDI_WIN2KSP3)
NTKERNELAPI
BOOLEAN
NTAPI
SeAuditingHardLinkEvents(
  IN BOOLEAN AccessGranted,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);
#endif

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
NTSTATUS
NTAPI
SeFilterToken(
  IN PACCESS_TOKEN ExistingToken,
  IN ULONG Flags,
  IN PTOKEN_GROUPS SidsToDisable OPTIONAL,
  IN PTOKEN_PRIVILEGES PrivilegesToDelete OPTIONAL,
  IN PTOKEN_GROUPS RestrictedSids OPTIONAL,
  OUT PACCESS_TOKEN *FilteredToken);

NTKERNELAPI
VOID
NTAPI
SeAuditHardLinkCreation(
  IN PUNICODE_STRING FileName,
  IN PUNICODE_STRING LinkName,
  IN BOOLEAN bSuccess);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WINXPSP2)

NTKERNELAPI
BOOLEAN
NTAPI
SeAuditingFileEventsWithContext(
  IN BOOLEAN AccessGranted,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSECURITY_SUBJECT_CONTEXT SubjectSecurityContext OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
SeAuditingHardLinkEventsWithContext(
  IN BOOLEAN AccessGranted,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSECURITY_SUBJECT_CONTEXT SubjectSecurityContext OPTIONAL);

#endif


#if (NTDDI_VERSION >= NTDDI_VISTA)

NTKERNELAPI
VOID
NTAPI
SeOpenObjectAuditAlarmWithTransaction(
  IN PUNICODE_STRING ObjectTypeName,
  IN PVOID Object OPTIONAL,
  IN PUNICODE_STRING AbsoluteObjectName OPTIONAL,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PACCESS_STATE AccessState,
  IN BOOLEAN ObjectCreated,
  IN BOOLEAN AccessGranted,
  IN KPROCESSOR_MODE AccessMode,
  IN GUID *TransactionId OPTIONAL,
  OUT PBOOLEAN GenerateOnClose);

NTKERNELAPI
VOID
NTAPI
SeOpenObjectForDeleteAuditAlarmWithTransaction(
  IN PUNICODE_STRING ObjectTypeName,
  IN PVOID Object OPTIONAL,
  IN PUNICODE_STRING AbsoluteObjectName OPTIONAL,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PACCESS_STATE AccessState,
  IN BOOLEAN ObjectCreated,
  IN BOOLEAN AccessGranted,
  IN KPROCESSOR_MODE AccessMode,
  IN GUID *TransactionId OPTIONAL,
  OUT PBOOLEAN GenerateOnClose);

NTKERNELAPI
VOID
NTAPI
SeExamineSacl(
  IN PACL Sacl,
  IN PACCESS_TOKEN Token,
  IN ACCESS_MASK DesiredAccess,
  IN BOOLEAN AccessGranted,
  OUT PBOOLEAN GenerateAudit,
  OUT PBOOLEAN GenerateAlarm);

NTKERNELAPI
VOID
NTAPI
SeDeleteObjectAuditAlarmWithTransaction(
  IN PVOID Object,
  IN HANDLE Handle,
  IN GUID *TransactionId OPTIONAL);

NTKERNELAPI
VOID
NTAPI
SeQueryTokenIntegrity(
  IN PACCESS_TOKEN Token,
  IN OUT PSID_AND_ATTRIBUTES IntegritySA);

NTKERNELAPI
NTSTATUS
NTAPI
SeSetSessionIdToken(
  IN PACCESS_TOKEN Token,
  IN ULONG SessionId);

NTKERNELAPI
VOID
NTAPI
SeAuditHardLinkCreationWithTransaction(
  IN PUNICODE_STRING FileName,
  IN PUNICODE_STRING LinkName,
  IN BOOLEAN bSuccess,
  IN GUID *TransactionId OPTIONAL);

NTKERNELAPI
VOID
NTAPI
SeAuditTransactionStateChange(
  IN GUID *TransactionId,
  IN GUID *ResourceManagerId,
  IN ULONG NewTransactionState);
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_VISTA || (NTDDI_VERSION >= NTDDI_WINXPSP2 && NTDDI_VERSION < NTDDI_WS03))
NTKERNELAPI
BOOLEAN
NTAPI
SeTokenIsWriteRestricted(
  IN PACCESS_TOKEN Token);
#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTKERNELAPI
BOOLEAN
NTAPI
SeAuditingAnyFileEventsWithContext(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSECURITY_SUBJECT_CONTEXT SubjectSecurityContext OPTIONAL);

NTKERNELAPI
VOID
NTAPI
SeExamineGlobalSacl(
  IN PUNICODE_STRING ObjectType,
  IN PACCESS_TOKEN Token,
  IN ACCESS_MASK DesiredAccess,
  IN BOOLEAN AccessGranted,
  IN OUT PBOOLEAN GenerateAudit,
  IN OUT PBOOLEAN GenerateAlarm OPTIONAL);

NTKERNELAPI
VOID
NTAPI
SeMaximumAuditMaskFromGlobalSacl(
  IN PUNICODE_STRING ObjectTypeName OPTIONAL,
  IN ACCESS_MASK GrantedAccess,
  IN PACCESS_TOKEN Token,
  IN OUT PACCESS_MASK AuditMask);

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

NTSTATUS
NTAPI
SeReportSecurityEventWithSubCategory(
  IN ULONG Flags,
  IN PUNICODE_STRING SourceName,
  IN PSID UserSid OPTIONAL,
  IN PSE_ADT_PARAMETER_ARRAY AuditParameters,
  IN ULONG AuditSubcategoryId);

BOOLEAN
NTAPI
SeAccessCheckFromState(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PTOKEN_ACCESS_INFORMATION PrimaryTokenInformation,
  IN PTOKEN_ACCESS_INFORMATION ClientTokenInformation OPTIONAL,
  IN ACCESS_MASK DesiredAccess,
  IN ACCESS_MASK PreviouslyGrantedAccess,
  OUT PPRIVILEGE_SET *Privileges OPTIONAL,
  IN PGENERIC_MAPPING GenericMapping,
  IN KPROCESSOR_MODE AccessMode,
  OUT PACCESS_MASK GrantedAccess,
  OUT PNTSTATUS AccessStatus);

NTKERNELAPI
VOID
NTAPI
SeFreePrivileges(
  IN PPRIVILEGE_SET Privileges);

NTSTATUS
NTAPI
SeLocateProcessImageName(
  IN OUT PEPROCESS Process,
  OUT PUNICODE_STRING *pImageFileName);

#define SeLengthSid( Sid ) \
    (8 + (4 * ((SID *)Sid)->SubAuthorityCount))

#define SeDeleteClientSecurity(C)  {                                           \
            if (SeTokenType((C)->ClientToken) == TokenPrimary) {               \
                PsDereferencePrimaryToken( (C)->ClientToken );                 \
            } else {                                                           \
                PsDereferenceImpersonationToken( (C)->ClientToken );           \
            }                                                                  \
}

#define SeStopImpersonatingClient() PsRevertToSelf()

#define SeQuerySubjectContextToken( SubjectContext )                \
    ( ARGUMENT_PRESENT(                                             \
        ((PSECURITY_SUBJECT_CONTEXT) SubjectContext)->ClientToken   \
        ) ?                                                         \
    ((PSECURITY_SUBJECT_CONTEXT) SubjectContext)->ClientToken :     \
    ((PSECURITY_SUBJECT_CONTEXT) SubjectContext)->PrimaryToken )

extern NTKERNELAPI PSE_EXPORTS SeExports;
/******************************************************************************
 *                          Process Manager Functions                         *
 ******************************************************************************/

NTKERNELAPI
NTSTATUS
NTAPI
PsLookupProcessByProcessId(
  IN HANDLE ProcessId,
  OUT PEPROCESS *Process);

NTKERNELAPI
NTSTATUS
NTAPI
PsLookupThreadByThreadId(
  IN HANDLE UniqueThreadId,
  OUT PETHREAD *Thread);

#if (NTDDI_VERSION >= NTDDI_WIN2K)


NTKERNELAPI
PACCESS_TOKEN
NTAPI
PsReferenceImpersonationToken(
  IN OUT PETHREAD Thread,
  OUT PBOOLEAN CopyOnOpen,
  OUT PBOOLEAN EffectiveOnly,
  OUT PSECURITY_IMPERSONATION_LEVEL ImpersonationLevel);

NTKERNELAPI
LARGE_INTEGER
NTAPI
PsGetProcessExitTime(VOID);

NTKERNELAPI
BOOLEAN
NTAPI
PsIsThreadTerminating(
  IN PETHREAD Thread);

NTKERNELAPI
NTSTATUS
NTAPI
PsImpersonateClient(
  IN OUT PETHREAD Thread,
  IN PACCESS_TOKEN Token,
  IN BOOLEAN CopyOnOpen,
  IN BOOLEAN EffectiveOnly,
  IN SECURITY_IMPERSONATION_LEVEL ImpersonationLevel);

NTKERNELAPI
BOOLEAN
NTAPI
PsDisableImpersonation(
  IN OUT PETHREAD Thread,
  IN OUT PSE_IMPERSONATION_STATE ImpersonationState);

NTKERNELAPI
VOID
NTAPI
PsRestoreImpersonation(
  IN PETHREAD Thread,
  IN PSE_IMPERSONATION_STATE ImpersonationState);

NTKERNELAPI
VOID
NTAPI
PsRevertToSelf(VOID);

NTKERNELAPI
VOID
NTAPI
PsChargePoolQuota(
  IN PEPROCESS Process,
  IN POOL_TYPE PoolType,
  IN ULONG_PTR Amount);

NTKERNELAPI
VOID
NTAPI
PsReturnPoolQuota(
  IN PEPROCESS Process,
  IN POOL_TYPE PoolType,
  IN ULONG_PTR Amount);

NTKERNELAPI
NTSTATUS
NTAPI
PsAssignImpersonationToken(
  IN PETHREAD Thread,
  IN HANDLE Token OPTIONAL);

NTKERNELAPI
HANDLE
NTAPI
PsReferencePrimaryToken(
  IN OUT PEPROCESS Process);
#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */
#if (NTDDI_VERSION >= NTDDI_WINXP)


NTKERNELAPI
VOID
NTAPI
PsDereferencePrimaryToken(
  IN PACCESS_TOKEN PrimaryToken);

NTKERNELAPI
VOID
NTAPI
PsDereferenceImpersonationToken(
  IN PACCESS_TOKEN ImpersonationToken);

NTKERNELAPI
NTSTATUS
NTAPI
PsChargeProcessPoolQuota(
  IN PEPROCESS Process,
  IN POOL_TYPE PoolType,
  IN ULONG_PTR Amount);

NTKERNELAPI
BOOLEAN
NTAPI
PsIsSystemThread(
  IN PETHREAD Thread);
#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

/******************************************************************************
 *                         I/O Manager Functions                              *
 ******************************************************************************/

#define IoIsFileOpenedExclusively(FileObject) ( \
    (BOOLEAN) !(                                \
    (FileObject)->SharedRead ||                 \
    (FileObject)->SharedWrite ||                \
    (FileObject)->SharedDelete                  \
    )                                           \
)

#if (NTDDI_VERSION == NTDDI_WIN2K)
NTKERNELAPI
NTSTATUS
NTAPI
IoRegisterFsRegistrationChangeEx(
  IN PDRIVER_OBJECT DriverObject,
  IN PDRIVER_FS_NOTIFICATION DriverNotificationRoutine);
#endif
#if (NTDDI_VERSION >= NTDDI_WIN2K)


NTKERNELAPI
VOID
NTAPI
IoAcquireVpbSpinLock(
  OUT PKIRQL Irql);

NTKERNELAPI
NTSTATUS
NTAPI
IoCheckDesiredAccess(
  IN OUT PACCESS_MASK DesiredAccess,
  IN ACCESS_MASK GrantedAccess);

NTKERNELAPI
NTSTATUS
NTAPI
IoCheckEaBufferValidity(
  IN PFILE_FULL_EA_INFORMATION EaBuffer,
  IN ULONG EaLength,
  OUT PULONG ErrorOffset);

NTKERNELAPI
NTSTATUS
NTAPI
IoCheckFunctionAccess(
  IN ACCESS_MASK GrantedAccess,
  IN UCHAR MajorFunction,
  IN UCHAR MinorFunction,
  IN ULONG IoControlCode,
  IN PVOID Argument1 OPTIONAL,
  IN PVOID Argument2 OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
IoCheckQuerySetFileInformation(
  IN FILE_INFORMATION_CLASS FileInformationClass,
  IN ULONG Length,
  IN BOOLEAN SetOperation);

NTKERNELAPI
NTSTATUS
NTAPI
IoCheckQuerySetVolumeInformation(
  IN FS_INFORMATION_CLASS FsInformationClass,
  IN ULONG Length,
  IN BOOLEAN SetOperation);

NTKERNELAPI
NTSTATUS
NTAPI
IoCheckQuotaBufferValidity(
  IN PFILE_QUOTA_INFORMATION QuotaBuffer,
  IN ULONG QuotaLength,
  OUT PULONG ErrorOffset);

NTKERNELAPI
PFILE_OBJECT
NTAPI
IoCreateStreamFileObject(
  IN PFILE_OBJECT FileObject OPTIONAL,
  IN PDEVICE_OBJECT DeviceObject OPTIONAL);

NTKERNELAPI
PFILE_OBJECT
NTAPI
IoCreateStreamFileObjectLite(
  IN PFILE_OBJECT FileObject OPTIONAL,
  IN PDEVICE_OBJECT DeviceObject OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
IoFastQueryNetworkAttributes(
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN ACCESS_MASK DesiredAccess,
  IN ULONG OpenOptions,
  OUT PIO_STATUS_BLOCK IoStatus,
  OUT PFILE_NETWORK_OPEN_INFORMATION Buffer);

NTKERNELAPI
NTSTATUS
NTAPI
IoPageRead(
  IN PFILE_OBJECT FileObject,
  IN PMDL Mdl,
  IN PLARGE_INTEGER Offset,
  IN PKEVENT Event,
  OUT PIO_STATUS_BLOCK IoStatusBlock);

NTKERNELAPI
PDEVICE_OBJECT
NTAPI
IoGetBaseFileSystemDeviceObject(
  IN PFILE_OBJECT FileObject);

NTKERNELAPI
PCONFIGURATION_INFORMATION
NTAPI
IoGetConfigurationInformation(VOID);

NTKERNELAPI
ULONG
NTAPI
IoGetRequestorProcessId(
  IN PIRP Irp);

NTKERNELAPI
PEPROCESS
NTAPI
IoGetRequestorProcess(
  IN PIRP Irp);

NTKERNELAPI
PIRP
NTAPI
IoGetTopLevelIrp(VOID);

NTKERNELAPI
BOOLEAN
NTAPI
IoIsOperationSynchronous(
  IN PIRP Irp);

NTKERNELAPI
BOOLEAN
NTAPI
IoIsSystemThread(
  IN PETHREAD Thread);

NTKERNELAPI
BOOLEAN
NTAPI
IoIsValidNameGraftingBuffer(
  IN PIRP Irp,
  IN PREPARSE_DATA_BUFFER ReparseBuffer);

NTKERNELAPI
NTSTATUS
NTAPI
IoQueryFileInformation(
  IN PFILE_OBJECT FileObject,
  IN FILE_INFORMATION_CLASS FileInformationClass,
  IN ULONG Length,
  OUT PVOID FileInformation,
  OUT PULONG ReturnedLength);

NTKERNELAPI
NTSTATUS
NTAPI
IoQueryVolumeInformation(
  IN PFILE_OBJECT FileObject,
  IN FS_INFORMATION_CLASS FsInformationClass,
  IN ULONG Length,
  OUT PVOID FsInformation,
  OUT PULONG ReturnedLength);

NTKERNELAPI
VOID
NTAPI
IoQueueThreadIrp(
  IN PIRP Irp);

NTKERNELAPI
VOID
NTAPI
IoRegisterFileSystem(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoRegisterFsRegistrationChange(
  IN PDRIVER_OBJECT DriverObject,
  IN PDRIVER_FS_NOTIFICATION DriverNotificationRoutine);

NTKERNELAPI
VOID
NTAPI
IoReleaseVpbSpinLock(
  IN KIRQL Irql);

NTKERNELAPI
VOID
NTAPI
IoSetDeviceToVerify(
  IN PETHREAD Thread,
  IN PDEVICE_OBJECT DeviceObject OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
IoSetInformation(
  IN PFILE_OBJECT FileObject,
  IN FILE_INFORMATION_CLASS FileInformationClass,
  IN ULONG Length,
  IN PVOID FileInformation);

NTKERNELAPI
VOID
NTAPI
IoSetTopLevelIrp(
  IN PIRP Irp OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
IoSynchronousPageWrite(
  IN PFILE_OBJECT FileObject,
  IN PMDL Mdl,
  IN PLARGE_INTEGER FileOffset,
  IN PKEVENT Event,
  OUT PIO_STATUS_BLOCK IoStatusBlock);

NTKERNELAPI
PEPROCESS
NTAPI
IoThreadToProcess(
  IN PETHREAD Thread);

NTKERNELAPI
VOID
NTAPI
IoUnregisterFileSystem(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
VOID
NTAPI
IoUnregisterFsRegistrationChange(
  IN PDRIVER_OBJECT DriverObject,
  IN PDRIVER_FS_NOTIFICATION DriverNotificationRoutine);

NTKERNELAPI
NTSTATUS
NTAPI
IoVerifyVolume(
  IN PDEVICE_OBJECT DeviceObject,
  IN BOOLEAN AllowRawMount);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetRequestorSessionId(
  IN PIRP Irp,
  OUT PULONG pSessionId);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */


#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
PFILE_OBJECT
NTAPI
IoCreateStreamFileObjectEx(
  IN PFILE_OBJECT FileObject OPTIONAL,
  IN PDEVICE_OBJECT DeviceObject OPTIONAL,
  OUT PHANDLE FileObjectHandle OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
IoQueryFileDosDeviceName(
  IN PFILE_OBJECT FileObject,
  OUT POBJECT_NAME_INFORMATION *ObjectNameInformation);

NTKERNELAPI
NTSTATUS
NTAPI
IoEnumerateDeviceObjectList(
  IN PDRIVER_OBJECT DriverObject,
  OUT PDEVICE_OBJECT *DeviceObjectList,
  IN ULONG DeviceObjectListSize,
  OUT PULONG ActualNumberDeviceObjects);

NTKERNELAPI
PDEVICE_OBJECT
NTAPI
IoGetLowerDeviceObject(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
PDEVICE_OBJECT
NTAPI
IoGetDeviceAttachmentBaseRef(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetDiskDeviceObject(
  IN PDEVICE_OBJECT FileSystemDeviceObject,
  OUT PDEVICE_OBJECT *DiskDeviceObject);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WS03SP1)

NTKERNELAPI
NTSTATUS
NTAPI
IoEnumerateRegisteredFiltersList(
  OUT PDRIVER_OBJECT *DriverObjectList,
  IN ULONG DriverObjectListSize,
  OUT PULONG ActualNumberDriverObjects);
#endif /* (NTDDI_VERSION >= NTDDI_WS03SP1) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

FORCEINLINE
VOID
NTAPI
IoInitializePriorityInfo(
  IN PIO_PRIORITY_INFO PriorityInfo)
{
  PriorityInfo->Size = sizeof(IO_PRIORITY_INFO);
  PriorityInfo->ThreadPriority = 0xffff;
  PriorityInfo->IoPriority = IoPriorityNormal;
  PriorityInfo->PagePriority = 0;
}
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTKERNELAPI
NTSTATUS
NTAPI
IoRegisterFsRegistrationChangeMountAware(
  IN PDRIVER_OBJECT DriverObject,
  IN PDRIVER_FS_NOTIFICATION DriverNotificationRoutine,
  IN BOOLEAN SynchronizeWithMounts);

NTKERNELAPI
NTSTATUS
NTAPI
IoReplaceFileObjectName(
  IN PFILE_OBJECT FileObject,
  IN PWSTR NewFileName,
  IN USHORT FileNameLength);
#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */


#define PO_CB_SYSTEM_POWER_POLICY       0
#define PO_CB_AC_STATUS                 1
#define PO_CB_BUTTON_COLLISION          2
#define PO_CB_SYSTEM_STATE_LOCK         3
#define PO_CB_LID_SWITCH_STATE          4
#define PO_CB_PROCESSOR_POWER_POLICY    5


#if (NTDDI_VERSION >= NTDDI_WINXP)
NTKERNELAPI
NTSTATUS
NTAPI
PoQueueShutdownWorkItem(
  IN OUT PWORK_QUEUE_ITEM WorkItem);
#endif

/******************************************************************************
 *                         Memory manager Types                               *
 ******************************************************************************/

typedef enum _MMFLUSH_TYPE {
  MmFlushForDelete,
  MmFlushForWrite
} MMFLUSH_TYPE;

typedef struct _READ_LIST {
  PFILE_OBJECT FileObject;
  ULONG NumberOfEntries;
  LOGICAL IsImage;
  FILE_SEGMENT_ELEMENT List[ANYSIZE_ARRAY];
} READ_LIST, *PREAD_LIST;

#if (NTDDI_VERSION >= NTDDI_WINXP)

typedef union _MM_PREFETCH_FLAGS {
  struct {
    ULONG Priority : SYSTEM_PAGE_PRIORITY_BITS;
    ULONG RepurposePriority : SYSTEM_PAGE_PRIORITY_BITS;
  } Flags;
  ULONG AllFlags;
} MM_PREFETCH_FLAGS, *PMM_PREFETCH_FLAGS;

#define MM_PREFETCH_FLAGS_MASK ((1 << (2*SYSTEM_PAGE_PRIORITY_BITS)) - 1)

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#define HEAP_NO_SERIALIZE               0x00000001
#define HEAP_GROWABLE                   0x00000002
#define HEAP_GENERATE_EXCEPTIONS        0x00000004
#define HEAP_ZERO_MEMORY                0x00000008
#define HEAP_REALLOC_IN_PLACE_ONLY      0x00000010
#define HEAP_TAIL_CHECKING_ENABLED      0x00000020
#define HEAP_FREE_CHECKING_ENABLED      0x00000040
#define HEAP_DISABLE_COALESCE_ON_FREE   0x00000080

#define HEAP_CREATE_ALIGN_16            0x00010000
#define HEAP_CREATE_ENABLE_TRACING      0x00020000
#define HEAP_CREATE_ENABLE_EXECUTE      0x00040000

#define HEAP_SETTABLE_USER_VALUE        0x00000100
#define HEAP_SETTABLE_USER_FLAG1        0x00000200
#define HEAP_SETTABLE_USER_FLAG2        0x00000400
#define HEAP_SETTABLE_USER_FLAG3        0x00000800
#define HEAP_SETTABLE_USER_FLAGS        0x00000E00

#define HEAP_CLASS_0                    0x00000000
#define HEAP_CLASS_1                    0x00001000
#define HEAP_CLASS_2                    0x00002000
#define HEAP_CLASS_3                    0x00003000
#define HEAP_CLASS_4                    0x00004000
#define HEAP_CLASS_5                    0x00005000
#define HEAP_CLASS_6                    0x00006000
#define HEAP_CLASS_7                    0x00007000
#define HEAP_CLASS_8                    0x00008000
#define HEAP_CLASS_MASK                 0x0000F000

#define HEAP_MAXIMUM_TAG                0x0FFF
#define HEAP_GLOBAL_TAG                 0x0800
#define HEAP_PSEUDO_TAG_FLAG            0x8000
#define HEAP_TAG_SHIFT                  18
#define HEAP_TAG_MASK                  (HEAP_MAXIMUM_TAG << HEAP_TAG_SHIFT)

#define HEAP_CREATE_VALID_MASK         (HEAP_NO_SERIALIZE             |   \
                                        HEAP_GROWABLE                 |   \
                                        HEAP_GENERATE_EXCEPTIONS      |   \
                                        HEAP_ZERO_MEMORY              |   \
                                        HEAP_REALLOC_IN_PLACE_ONLY    |   \
                                        HEAP_TAIL_CHECKING_ENABLED    |   \
                                        HEAP_FREE_CHECKING_ENABLED    |   \
                                        HEAP_DISABLE_COALESCE_ON_FREE |   \
                                        HEAP_CLASS_MASK               |   \
                                        HEAP_CREATE_ALIGN_16          |   \
                                        HEAP_CREATE_ENABLE_TRACING    |   \
                                        HEAP_CREATE_ENABLE_EXECUTE)

/******************************************************************************
 *                       Memory manager Functions                             *
 ******************************************************************************/

FORCEINLINE
ULONG
HEAP_MAKE_TAG_FLAGS(
  IN ULONG TagBase,
  IN ULONG Tag)
{
  //__assume_bound(TagBase); // FIXME
  return ((ULONG)((TagBase) + ((Tag) << HEAP_TAG_SHIFT)));
}

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
BOOLEAN
NTAPI
MmIsRecursiveIoFault(
  VOID);

NTKERNELAPI
BOOLEAN
NTAPI
MmForceSectionClosed(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN BOOLEAN DelayClose);

NTKERNELAPI
BOOLEAN
NTAPI
MmFlushImageSection(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN MMFLUSH_TYPE FlushType);

NTKERNELAPI
BOOLEAN
NTAPI
MmCanFileBeTruncated(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN PLARGE_INTEGER NewFileSize OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
MmSetAddressRangeModified(
  IN PVOID Address,
  IN SIZE_T Length);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
NTSTATUS
NTAPI
MmPrefetchPages(
  IN ULONG NumberOfLists,
  IN PREAD_LIST *ReadLists);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */


#if (NTDDI_VERSION >= NTDDI_VISTA)

NTKERNELAPI
ULONG
NTAPI
MmDoesFileHaveUserWritableReferences(
  IN PSECTION_OBJECT_POINTERS SectionPointer);
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */


#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
NTSTATUS
NTAPI
ObInsertObject(
  IN PVOID Object,
  IN OUT PACCESS_STATE PassedAccessState OPTIONAL,
  IN ACCESS_MASK DesiredAccess OPTIONAL,
  IN ULONG ObjectPointerBias,
  OUT PVOID *NewObject OPTIONAL,
  OUT PHANDLE Handle OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
ObOpenObjectByPointer(
  IN PVOID Object,
  IN ULONG HandleAttributes,
  IN PACCESS_STATE PassedAccessState OPTIONAL,
  IN ACCESS_MASK DesiredAccess OPTIONAL,
  IN POBJECT_TYPE ObjectType OPTIONAL,
  IN KPROCESSOR_MODE AccessMode,
  OUT PHANDLE Handle);

NTKERNELAPI
VOID
NTAPI
ObMakeTemporaryObject(
  IN PVOID Object);

NTKERNELAPI
NTSTATUS
NTAPI
ObQueryNameString(
  IN PVOID Object,
  OUT POBJECT_NAME_INFORMATION ObjectNameInfo OPTIONAL,
  IN ULONG Length,
  OUT PULONG ReturnLength);

NTKERNELAPI
NTSTATUS
NTAPI
ObQueryObjectAuditingByHandle(
  IN HANDLE Handle,
  OUT PBOOLEAN GenerateOnClose);
#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTKERNELAPI
BOOLEAN
NTAPI
ObIsKernelHandle(
  IN HANDLE Handle);
#endif


#if (NTDDI_VERSION >= NTDDI_WIN7)

NTKERNELAPI
NTSTATUS
NTAPI
ObOpenObjectByPointerWithTag(
  IN PVOID Object,
  IN ULONG HandleAttributes,
  IN PACCESS_STATE PassedAccessState OPTIONAL,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_TYPE ObjectType OPTIONAL,
  IN KPROCESSOR_MODE AccessMode,
  IN ULONG Tag,
  OUT PHANDLE Handle);
#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

/* FSRTL Types */

typedef ULONG LBN;
typedef LBN *PLBN;

typedef ULONG VBN;
typedef VBN *PVBN;

#define FSRTL_COMMON_FCB_HEADER_LAYOUT \
  CSHORT NodeTypeCode; \
  CSHORT NodeByteSize; \
  UCHAR Flags; \
  UCHAR IsFastIoPossible; \
  UCHAR Flags2; \
  UCHAR Reserved:4; \
  UCHAR Version:4; \
  PERESOURCE Resource; \
  PERESOURCE PagingIoResource; \
  LARGE_INTEGER AllocationSize; \
  LARGE_INTEGER FileSize; \
  LARGE_INTEGER ValidDataLength;

typedef struct _FSRTL_COMMON_FCB_HEADER {
  FSRTL_COMMON_FCB_HEADER_LAYOUT
} FSRTL_COMMON_FCB_HEADER, *PFSRTL_COMMON_FCB_HEADER;

#ifdef __cplusplus
typedef struct _FSRTL_ADVANCED_FCB_HEADER:FSRTL_COMMON_FCB_HEADER {
#else /* __cplusplus */
typedef struct _FSRTL_ADVANCED_FCB_HEADER {
  FSRTL_COMMON_FCB_HEADER_LAYOUT
#endif  /* __cplusplus */
  PFAST_MUTEX FastMutex;
  LIST_ENTRY FilterContexts;
#if (NTDDI_VERSION >= NTDDI_VISTA)
  EX_PUSH_LOCK PushLock;
  PVOID *FileContextSupportPointer;
#endif
} FSRTL_ADVANCED_FCB_HEADER, *PFSRTL_ADVANCED_FCB_HEADER;

#define FSRTL_FCB_HEADER_V0             (0x00)
#define FSRTL_FCB_HEADER_V1             (0x01)

#define FSRTL_FLAG_FILE_MODIFIED        (0x01)
#define FSRTL_FLAG_FILE_LENGTH_CHANGED  (0x02)
#define FSRTL_FLAG_LIMIT_MODIFIED_PAGES (0x04)
#define FSRTL_FLAG_ACQUIRE_MAIN_RSRC_EX (0x08)
#define FSRTL_FLAG_ACQUIRE_MAIN_RSRC_SH (0x10)
#define FSRTL_FLAG_USER_MAPPED_FILE     (0x20)
#define FSRTL_FLAG_ADVANCED_HEADER      (0x40)
#define FSRTL_FLAG_EOF_ADVANCE_ACTIVE   (0x80)

#define FSRTL_FLAG2_DO_MODIFIED_WRITE        (0x01)
#define FSRTL_FLAG2_SUPPORTS_FILTER_CONTEXTS (0x02)
#define FSRTL_FLAG2_PURGE_WHEN_MAPPED        (0x04)
#define FSRTL_FLAG2_IS_PAGING_FILE           (0x08)

#define FSRTL_FSP_TOP_LEVEL_IRP         (0x01)
#define FSRTL_CACHE_TOP_LEVEL_IRP       (0x02)
#define FSRTL_MOD_WRITE_TOP_LEVEL_IRP   (0x03)
#define FSRTL_FAST_IO_TOP_LEVEL_IRP     (0x04)
#define FSRTL_NETWORK1_TOP_LEVEL_IRP    ((LONG_PTR)0x05)
#define FSRTL_NETWORK2_TOP_LEVEL_IRP    ((LONG_PTR)0x06)
#define FSRTL_MAX_TOP_LEVEL_IRP_FLAG    ((LONG_PTR)0xFFFF)

typedef struct _FSRTL_AUXILIARY_BUFFER {
  PVOID Buffer;
  ULONG Length;
  ULONG Flags;
  PMDL Mdl;
} FSRTL_AUXILIARY_BUFFER, *PFSRTL_AUXILIARY_BUFFER;

#define FSRTL_AUXILIARY_FLAG_DEALLOCATE 0x00000001

typedef enum _FSRTL_COMPARISON_RESULT {
  LessThan = -1,
  EqualTo = 0,
  GreaterThan = 1
} FSRTL_COMPARISON_RESULT;

#define FSRTL_FAT_LEGAL                 0x01
#define FSRTL_HPFS_LEGAL                0x02
#define FSRTL_NTFS_LEGAL                0x04
#define FSRTL_WILD_CHARACTER            0x08
#define FSRTL_OLE_LEGAL                 0x10
#define FSRTL_NTFS_STREAM_LEGAL         (FSRTL_NTFS_LEGAL | FSRTL_OLE_LEGAL)

#define FSRTL_VOLUME_DISMOUNT           1
#define FSRTL_VOLUME_DISMOUNT_FAILED    2
#define FSRTL_VOLUME_LOCK               3
#define FSRTL_VOLUME_LOCK_FAILED        4
#define FSRTL_VOLUME_UNLOCK             5
#define FSRTL_VOLUME_MOUNT              6
#define FSRTL_VOLUME_NEEDS_CHKDSK       7
#define FSRTL_VOLUME_WORM_NEAR_FULL     8
#define FSRTL_VOLUME_WEARING_OUT        9
#define FSRTL_VOLUME_FORCED_CLOSED      10
#define FSRTL_VOLUME_INFO_MAKE_COMPAT   11
#define FSRTL_VOLUME_PREPARING_EJECT    12
#define FSRTL_VOLUME_CHANGE_SIZE        13
#define FSRTL_VOLUME_BACKGROUND_FORMAT  14

typedef VOID
(NTAPI *PFSRTL_STACK_OVERFLOW_ROUTINE) (
  IN PVOID Context,
  IN PKEVENT Event);

#if (NTDDI_VERSION >= NTDDI_VISTA)

#define FSRTL_UNC_PROVIDER_FLAGS_MAILSLOTS_SUPPORTED    0x00000001
#define FSRTL_UNC_PROVIDER_FLAGS_CSC_ENABLED            0x00000002
#define FSRTL_UNC_PROVIDER_FLAGS_DOMAIN_SVC_AWARE       0x00000004

#define FSRTL_ALLOCATE_ECPLIST_FLAG_CHARGE_QUOTA           0x00000001

#define FSRTL_ALLOCATE_ECP_FLAG_CHARGE_QUOTA               0x00000001
#define FSRTL_ALLOCATE_ECP_FLAG_NONPAGED_POOL              0x00000002

#define FSRTL_ECP_LOOKASIDE_FLAG_NONPAGED_POOL             0x00000002

#define FSRTL_VIRTDISK_FULLY_ALLOCATED  0x00000001
#define FSRTL_VIRTDISK_NO_DRIVE_LETTER  0x00000002

typedef struct _FSRTL_MUP_PROVIDER_INFO_LEVEL_1 {
  ULONG32 ProviderId;
} FSRTL_MUP_PROVIDER_INFO_LEVEL_1, *PFSRTL_MUP_PROVIDER_INFO_LEVEL_1;

typedef struct _FSRTL_MUP_PROVIDER_INFO_LEVEL_2 {
  ULONG32 ProviderId;
  UNICODE_STRING ProviderName;
} FSRTL_MUP_PROVIDER_INFO_LEVEL_2, *PFSRTL_MUP_PROVIDER_INFO_LEVEL_2;

typedef VOID
(*PFSRTL_EXTRA_CREATE_PARAMETER_CLEANUP_CALLBACK) (
  IN OUT PVOID EcpContext,
  IN LPCGUID EcpType);

typedef struct _ECP_LIST ECP_LIST, *PECP_LIST;

typedef ULONG FSRTL_ALLOCATE_ECPLIST_FLAGS;
typedef ULONG FSRTL_ALLOCATE_ECP_FLAGS;
typedef ULONG FSRTL_ECP_LOOKASIDE_FLAGS;

typedef enum _FSRTL_CHANGE_BACKING_TYPE {
  ChangeDataControlArea,
  ChangeImageControlArea,
  ChangeSharedCacheMap
} FSRTL_CHANGE_BACKING_TYPE, *PFSRTL_CHANGE_BACKING_TYPE;

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

typedef struct _FSRTL_PER_FILE_CONTEXT {
  LIST_ENTRY Links;
  PVOID OwnerId;
  PVOID InstanceId;
  PFREE_FUNCTION FreeCallback;
} FSRTL_PER_FILE_CONTEXT, *PFSRTL_PER_FILE_CONTEXT;

typedef struct _FSRTL_PER_STREAM_CONTEXT {
  LIST_ENTRY Links;
  PVOID OwnerId;
  PVOID InstanceId;
  PFREE_FUNCTION FreeCallback;
} FSRTL_PER_STREAM_CONTEXT, *PFSRTL_PER_STREAM_CONTEXT;

#if (NTDDI_VERSION >= NTDDI_WIN2K)
typedef VOID
(*PFN_FSRTLTEARDOWNPERSTREAMCONTEXTS) (
  IN PFSRTL_ADVANCED_FCB_HEADER AdvancedHeader);
#endif

typedef struct _FSRTL_PER_FILEOBJECT_CONTEXT {
  LIST_ENTRY Links;
  PVOID OwnerId;
  PVOID InstanceId;
} FSRTL_PER_FILEOBJECT_CONTEXT, *PFSRTL_PER_FILEOBJECT_CONTEXT;

#define FSRTL_CC_FLUSH_ERROR_FLAG_NO_HARD_ERROR  0x1
#define FSRTL_CC_FLUSH_ERROR_FLAG_NO_LOG_ENTRY   0x2

typedef NTSTATUS
(NTAPI *PCOMPLETE_LOCK_IRP_ROUTINE) (
  IN PVOID Context,
  IN PIRP Irp);

typedef struct _FILE_LOCK_INFO {
  LARGE_INTEGER StartingByte;
  LARGE_INTEGER Length;
  BOOLEAN ExclusiveLock;
  ULONG Key;
  PFILE_OBJECT FileObject;
  PVOID ProcessId;
  LARGE_INTEGER EndingByte;
} FILE_LOCK_INFO, *PFILE_LOCK_INFO;

typedef VOID
(NTAPI *PUNLOCK_ROUTINE) (
  IN PVOID Context,
  IN PFILE_LOCK_INFO FileLockInfo);

typedef struct _FILE_LOCK {
  PCOMPLETE_LOCK_IRP_ROUTINE CompleteLockIrpRoutine;
  PUNLOCK_ROUTINE UnlockRoutine;
  BOOLEAN FastIoIsQuestionable;
  BOOLEAN SpareC[3];
  PVOID LockInformation;
  FILE_LOCK_INFO LastReturnedLockInfo;
  PVOID LastReturnedLock;
  LONG volatile LockRequestsInProgress;
} FILE_LOCK, *PFILE_LOCK;

typedef struct _TUNNEL {
  FAST_MUTEX Mutex;
  PRTL_SPLAY_LINKS Cache;
  LIST_ENTRY TimerQueue;
  USHORT NumEntries;
} TUNNEL, *PTUNNEL;

typedef struct _BASE_MCB {
  ULONG MaximumPairCount;
  ULONG PairCount;
  USHORT PoolType;
  USHORT Flags;
  PVOID Mapping;
} BASE_MCB, *PBASE_MCB;

typedef struct _LARGE_MCB {
  PKGUARDED_MUTEX GuardedMutex;
  BASE_MCB BaseMcb;
} LARGE_MCB, *PLARGE_MCB;

#define MCB_FLAG_RAISE_ON_ALLOCATION_FAILURE 1

typedef struct _MCB {
  LARGE_MCB DummyFieldThatSizesThisStructureCorrectly;
} MCB, *PMCB;

typedef enum _FAST_IO_POSSIBLE {
  FastIoIsNotPossible = 0,
  FastIoIsPossible,
  FastIoIsQuestionable
} FAST_IO_POSSIBLE;

typedef struct _EOF_WAIT_BLOCK {
  LIST_ENTRY EofWaitLinks;
  KEVENT Event;
} EOF_WAIT_BLOCK, *PEOF_WAIT_BLOCK;

typedef PVOID OPLOCK, *POPLOCK;

typedef VOID
(NTAPI *POPLOCK_WAIT_COMPLETE_ROUTINE) (
  IN PVOID Context,
  IN PIRP Irp);

typedef VOID
(NTAPI *POPLOCK_FS_PREPOST_IRP) (
  IN PVOID Context,
  IN PIRP Irp);

#if (NTDDI_VERSION >= NTDDI_VISTASP1)
#define OPLOCK_FLAG_COMPLETE_IF_OPLOCKED    0x00000001
#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)
#define OPLOCK_FLAG_OPLOCK_KEY_CHECK_ONLY   0x00000002
#define OPLOCK_FLAG_BACK_OUT_ATOMIC_OPLOCK  0x00000004
#define OPLOCK_FLAG_IGNORE_OPLOCK_KEYS      0x00000008
#define OPLOCK_FSCTRL_FLAG_ALL_KEYS_MATCH   0x00000001
#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)

typedef struct _OPLOCK_KEY_ECP_CONTEXT {
  GUID OplockKey;
  ULONG Reserved;
} OPLOCK_KEY_ECP_CONTEXT, *POPLOCK_KEY_ECP_CONTEXT;

DEFINE_GUID(GUID_ECP_OPLOCK_KEY, 0x48850596, 0x3050, 0x4be7, 0x98, 0x63, 0xfe, 0xc3, 0x50, 0xce, 0x8d, 0x7f);

#endif

typedef PVOID PNOTIFY_SYNC;

#if (NTDDI_VERSION >= NTDDI_WIN7)
typedef struct _ECP_HEADER ECP_HEADER, *PECP_HEADER;
#endif

typedef BOOLEAN
(NTAPI *PCHECK_FOR_TRAVERSE_ACCESS) (
  IN PVOID NotifyContext,
  IN PVOID TargetContext OPTIONAL,
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext);

typedef BOOLEAN
(NTAPI *PFILTER_REPORT_CHANGE) (
  IN PVOID NotifyContext,
  IN PVOID FilterContext);
/* FSRTL Functions */

#define FsRtlEnterFileSystem    KeEnterCriticalRegion
#define FsRtlExitFileSystem     KeLeaveCriticalRegion

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlCopyRead(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Wait,
  IN ULONG LockKey,
  OUT PVOID Buffer,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlCopyWrite(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Wait,
  IN ULONG LockKey,
  IN PVOID Buffer,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlMdlReadDev(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG LockKey,
  OUT PMDL *MdlChain,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN PDEVICE_OBJECT DeviceObject OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlMdlReadCompleteDev(
  IN PFILE_OBJECT FileObject,
  IN PMDL MdlChain,
  IN PDEVICE_OBJECT DeviceObject OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlPrepareMdlWriteDev(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG LockKey,
  OUT PMDL *MdlChain,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlMdlWriteCompleteDev(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN PMDL MdlChain,
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
VOID
NTAPI
FsRtlAcquireFileExclusive(
  IN PFILE_OBJECT FileObject);

NTKERNELAPI
VOID
NTAPI
FsRtlReleaseFile(
  IN PFILE_OBJECT FileObject);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlGetFileSize(
  IN PFILE_OBJECT FileObject,
  OUT PLARGE_INTEGER FileSize);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsTotalDeviceFailure(
  IN NTSTATUS Status);

NTKERNELAPI
PFILE_LOCK
NTAPI
FsRtlAllocateFileLock(
  IN PCOMPLETE_LOCK_IRP_ROUTINE CompleteLockIrpRoutine OPTIONAL,
  IN PUNLOCK_ROUTINE UnlockRoutine OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlFreeFileLock(
  IN PFILE_LOCK FileLock);

NTKERNELAPI
VOID
NTAPI
FsRtlInitializeFileLock(
  IN PFILE_LOCK FileLock,
  IN PCOMPLETE_LOCK_IRP_ROUTINE CompleteLockIrpRoutine OPTIONAL,
  IN PUNLOCK_ROUTINE UnlockRoutine OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlUninitializeFileLock(
  IN PFILE_LOCK FileLock);

/*
  FsRtlProcessFileLock:

  ret:
    -STATUS_INVALID_DEVICE_REQUEST
    -STATUS_RANGE_NOT_LOCKED from unlock routines.
    -STATUS_PENDING, STATUS_LOCK_NOT_GRANTED from FsRtlPrivateLock
    (redirected IoStatus->Status).

  Internals:
    -switch ( Irp->CurrentStackLocation->MinorFunction )
        lock: return FsRtlPrivateLock;
        unlocksingle: return FsRtlFastUnlockSingle;
        unlockall: return FsRtlFastUnlockAll;
        unlockallbykey: return FsRtlFastUnlockAllByKey;
        default: IofCompleteRequest with STATUS_INVALID_DEVICE_REQUEST;
                 return STATUS_INVALID_DEVICE_REQUEST;

    -'AllwaysZero' is passed thru as 'AllwaysZero' to lock / unlock routines.
    -'Irp' is passet thru as 'Irp' to FsRtlPrivateLock.
*/
NTKERNELAPI
NTSTATUS
NTAPI
FsRtlProcessFileLock(
  IN PFILE_LOCK FileLock,
  IN PIRP Irp,
  IN PVOID Context OPTIONAL);

/*
  FsRtlCheckLockForReadAccess:

  All this really does is pick out the lock parameters from the irp (io stack
  location?), get IoGetRequestorProcess, and pass values on to
  FsRtlFastCheckLockForRead.
*/
NTKERNELAPI
BOOLEAN
NTAPI
FsRtlCheckLockForReadAccess(
  IN PFILE_LOCK FileLock,
  IN PIRP Irp);

/*
  FsRtlCheckLockForWriteAccess:

  All this really does is pick out the lock parameters from the irp (io stack
  location?), get IoGetRequestorProcess, and pass values on to
  FsRtlFastCheckLockForWrite.
*/
NTKERNELAPI
BOOLEAN
NTAPI
FsRtlCheckLockForWriteAccess(
  IN PFILE_LOCK FileLock,
  IN PIRP Irp);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlFastCheckLockForRead(
  IN PFILE_LOCK FileLock,
  IN PLARGE_INTEGER FileOffset,
  IN PLARGE_INTEGER Length,
  IN ULONG Key,
  IN PFILE_OBJECT FileObject,
  IN PVOID Process);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlFastCheckLockForWrite(
  IN PFILE_LOCK FileLock,
  IN PLARGE_INTEGER FileOffset,
  IN PLARGE_INTEGER Length,
  IN ULONG Key,
  IN PFILE_OBJECT FileObject,
  IN PVOID Process);

/*
  FsRtlGetNextFileLock:

  ret: NULL if no more locks

  Internals:
    FsRtlGetNextFileLock uses FileLock->LastReturnedLockInfo and
    FileLock->LastReturnedLock as storage.
    LastReturnedLock is a pointer to the 'raw' lock inkl. double linked
    list, and FsRtlGetNextFileLock needs this to get next lock on subsequent
    calls with Restart = FALSE.
*/
NTKERNELAPI
PFILE_LOCK_INFO
NTAPI
FsRtlGetNextFileLock(
  IN PFILE_LOCK FileLock,
  IN BOOLEAN Restart);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlFastUnlockSingle(
  IN PFILE_LOCK FileLock,
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN PLARGE_INTEGER Length,
  IN PEPROCESS Process,
  IN ULONG Key,
  IN PVOID Context OPTIONAL,
  IN BOOLEAN AlreadySynchronized);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlFastUnlockAll(
  IN PFILE_LOCK FileLock,
  IN PFILE_OBJECT FileObject,
  IN PEPROCESS Process,
  IN PVOID Context OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlFastUnlockAllByKey(
  IN PFILE_LOCK FileLock,
  IN PFILE_OBJECT FileObject,
  IN PEPROCESS Process,
  IN ULONG Key,
  IN PVOID Context OPTIONAL);

/*
  FsRtlPrivateLock:

  ret: IoStatus->Status: STATUS_PENDING, STATUS_LOCK_NOT_GRANTED

  Internals:
    -Calls IoCompleteRequest if Irp
    -Uses exception handling / ExRaiseStatus with STATUS_INSUFFICIENT_RESOURCES
*/
NTKERNELAPI
BOOLEAN
NTAPI
FsRtlPrivateLock(
  IN PFILE_LOCK FileLock,
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN PLARGE_INTEGER Length,
  IN PEPROCESS Process,
  IN ULONG Key,
  IN BOOLEAN FailImmediately,
  IN BOOLEAN ExclusiveLock,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN PIRP Irp OPTIONAL,
  IN PVOID Context,
  IN BOOLEAN AlreadySynchronized);

NTKERNELAPI
VOID
NTAPI
FsRtlInitializeTunnelCache(
  IN PTUNNEL Cache);

NTKERNELAPI
VOID
NTAPI
FsRtlAddToTunnelCache(
  IN PTUNNEL Cache,
  IN ULONGLONG DirectoryKey,
  IN PUNICODE_STRING ShortName,
  IN PUNICODE_STRING LongName,
  IN BOOLEAN KeyByShortName,
  IN ULONG DataLength,
  IN PVOID Data);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlFindInTunnelCache(
  IN PTUNNEL Cache,
  IN ULONGLONG DirectoryKey,
  IN PUNICODE_STRING Name,
  OUT PUNICODE_STRING ShortName,
  OUT PUNICODE_STRING LongName,
  IN OUT PULONG DataLength,
  OUT PVOID Data);

NTKERNELAPI
VOID
NTAPI
FsRtlDeleteKeyFromTunnelCache(
  IN PTUNNEL Cache,
  IN ULONGLONG DirectoryKey);

NTKERNELAPI
VOID
NTAPI
FsRtlDeleteTunnelCache(
  IN PTUNNEL Cache);

NTKERNELAPI
VOID
NTAPI
FsRtlDissectDbcs(
  IN ANSI_STRING Name,
  OUT PANSI_STRING FirstPart,
  OUT PANSI_STRING RemainingPart);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlDoesDbcsContainWildCards(
  IN PANSI_STRING Name);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsDbcsInExpression(
  IN PANSI_STRING Expression,
  IN PANSI_STRING Name);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsFatDbcsLegal(
  IN ANSI_STRING DbcsName,
  IN BOOLEAN WildCardsPermissible,
  IN BOOLEAN PathNamePermissible,
  IN BOOLEAN LeadingBackslashPermissible);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsHpfsDbcsLegal(
  IN ANSI_STRING DbcsName,
  IN BOOLEAN WildCardsPermissible,
  IN BOOLEAN PathNamePermissible,
  IN BOOLEAN LeadingBackslashPermissible);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlNormalizeNtstatus(
  IN NTSTATUS Exception,
  IN NTSTATUS GenericException);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsNtstatusExpected(
  IN NTSTATUS Ntstatus);

NTKERNELAPI
PERESOURCE
NTAPI
FsRtlAllocateResource(
  VOID);

NTKERNELAPI
VOID
NTAPI
FsRtlInitializeLargeMcb(
  IN PLARGE_MCB Mcb,
  IN POOL_TYPE PoolType);

NTKERNELAPI
VOID
NTAPI
FsRtlUninitializeLargeMcb(
  IN PLARGE_MCB Mcb);

NTKERNELAPI
VOID
NTAPI
FsRtlResetLargeMcb(
  IN PLARGE_MCB Mcb,
  IN BOOLEAN SelfSynchronized);

NTKERNELAPI
VOID
NTAPI
FsRtlTruncateLargeMcb(
  IN PLARGE_MCB Mcb,
  IN LONGLONG Vbn);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlAddLargeMcbEntry(
  IN PLARGE_MCB Mcb,
  IN LONGLONG Vbn,
  IN LONGLONG Lbn,
  IN LONGLONG SectorCount);

NTKERNELAPI
VOID
NTAPI
FsRtlRemoveLargeMcbEntry(
  IN PLARGE_MCB Mcb,
  IN LONGLONG Vbn,
  IN LONGLONG SectorCount);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlLookupLargeMcbEntry(
  IN PLARGE_MCB Mcb,
  IN LONGLONG Vbn,
  OUT PLONGLONG Lbn OPTIONAL,
  OUT PLONGLONG SectorCountFromLbn OPTIONAL,
  OUT PLONGLONG StartingLbn OPTIONAL,
  OUT PLONGLONG SectorCountFromStartingLbn OPTIONAL,
  OUT PULONG Index OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlLookupLastLargeMcbEntry(
  IN PLARGE_MCB Mcb,
  OUT PLONGLONG Vbn,
  OUT PLONGLONG Lbn);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlLookupLastLargeMcbEntryAndIndex(
  IN PLARGE_MCB OpaqueMcb,
  OUT PLONGLONG LargeVbn,
  OUT PLONGLONG LargeLbn,
  OUT PULONG Index);

NTKERNELAPI
ULONG
NTAPI
FsRtlNumberOfRunsInLargeMcb(
  IN PLARGE_MCB Mcb);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlGetNextLargeMcbEntry(
  IN PLARGE_MCB Mcb,
  IN ULONG RunIndex,
  OUT PLONGLONG Vbn,
  OUT PLONGLONG Lbn,
  OUT PLONGLONG SectorCount);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlSplitLargeMcb(
  IN PLARGE_MCB Mcb,
  IN LONGLONG Vbn,
  IN LONGLONG Amount);

NTKERNELAPI
VOID
NTAPI
FsRtlInitializeMcb(
  IN PMCB Mcb,
  IN POOL_TYPE PoolType);

NTKERNELAPI
VOID
NTAPI
FsRtlUninitializeMcb(
  IN PMCB Mcb);

NTKERNELAPI
VOID
NTAPI
FsRtlTruncateMcb(
  IN PMCB Mcb,
  IN VBN Vbn);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlAddMcbEntry(
  IN PMCB Mcb,
  IN VBN Vbn,
  IN LBN Lbn,
  IN ULONG SectorCount);

NTKERNELAPI
VOID
NTAPI
FsRtlRemoveMcbEntry(
  IN PMCB Mcb,
  IN VBN Vbn,
  IN ULONG SectorCount);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlLookupMcbEntry(
  IN PMCB Mcb,
  IN VBN Vbn,
  OUT PLBN Lbn,
  OUT PULONG SectorCount OPTIONAL,
  OUT PULONG Index);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlLookupLastMcbEntry(
  IN PMCB Mcb,
  OUT PVBN Vbn,
  OUT PLBN Lbn);

NTKERNELAPI
ULONG
NTAPI
FsRtlNumberOfRunsInMcb(
  IN PMCB Mcb);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlGetNextMcbEntry(
  IN PMCB Mcb,
  IN ULONG RunIndex,
  OUT PVBN Vbn,
  OUT PLBN Lbn,
  OUT PULONG SectorCount);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlBalanceReads(
  IN PDEVICE_OBJECT TargetDevice);

NTKERNELAPI
VOID
NTAPI
FsRtlInitializeOplock(
  IN OUT POPLOCK Oplock);

NTKERNELAPI
VOID
NTAPI
FsRtlUninitializeOplock(
  IN OUT POPLOCK Oplock);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlOplockFsctrl(
  IN POPLOCK Oplock,
  IN PIRP Irp,
  IN ULONG OpenCount);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlCheckOplock(
  IN POPLOCK Oplock,
  IN PIRP Irp,
  IN PVOID Context,
  IN POPLOCK_WAIT_COMPLETE_ROUTINE CompletionRoutine OPTIONAL,
  IN POPLOCK_FS_PREPOST_IRP PostIrpRoutine OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlOplockIsFastIoPossible(
  IN POPLOCK Oplock);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlCurrentBatchOplock(
  IN POPLOCK Oplock);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlNotifyVolumeEvent(
  IN PFILE_OBJECT FileObject,
  IN ULONG EventCode);

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyInitializeSync(
  IN PNOTIFY_SYNC *NotifySync);

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyUninitializeSync(
  IN PNOTIFY_SYNC *NotifySync);

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyFullChangeDirectory(
  IN PNOTIFY_SYNC NotifySync,
  IN PLIST_ENTRY NotifyList,
  IN PVOID FsContext,
  IN PSTRING FullDirectoryName,
  IN BOOLEAN WatchTree,
  IN BOOLEAN IgnoreBuffer,
  IN ULONG CompletionFilter,
  IN PIRP NotifyIrp OPTIONAL,
  IN PCHECK_FOR_TRAVERSE_ACCESS TraverseCallback OPTIONAL,
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyFilterReportChange(
  IN PNOTIFY_SYNC NotifySync,
  IN PLIST_ENTRY NotifyList,
  IN PSTRING FullTargetName,
  IN USHORT TargetNameOffset,
  IN PSTRING StreamName OPTIONAL,
  IN PSTRING NormalizedParentName OPTIONAL,
  IN ULONG FilterMatch,
  IN ULONG Action,
  IN PVOID TargetContext OPTIONAL,
  IN PVOID FilterContext OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyFullReportChange(
  IN PNOTIFY_SYNC NotifySync,
  IN PLIST_ENTRY NotifyList,
  IN PSTRING FullTargetName,
  IN USHORT TargetNameOffset,
  IN PSTRING StreamName OPTIONAL,
  IN PSTRING NormalizedParentName OPTIONAL,
  IN ULONG FilterMatch,
  IN ULONG Action,
  IN PVOID TargetContext OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyCleanup(
  IN PNOTIFY_SYNC NotifySync,
  IN PLIST_ENTRY NotifyList,
  IN PVOID FsContext);

NTKERNELAPI
VOID
NTAPI
FsRtlDissectName(
  IN UNICODE_STRING Name,
  OUT PUNICODE_STRING FirstPart,
  OUT PUNICODE_STRING RemainingPart);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlDoesNameContainWildCards(
  IN PUNICODE_STRING Name);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlAreNamesEqual(
  IN PCUNICODE_STRING Name1,
  IN PCUNICODE_STRING Name2,
  IN BOOLEAN IgnoreCase,
  IN PCWCH UpcaseTable OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsNameInExpression(
  IN PUNICODE_STRING Expression,
  IN PUNICODE_STRING Name,
  IN BOOLEAN IgnoreCase,
  IN PWCHAR UpcaseTable OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlPostPagingFileStackOverflow(
  IN PVOID Context,
  IN PKEVENT Event,
  IN PFSRTL_STACK_OVERFLOW_ROUTINE StackOverflowRoutine);

NTKERNELAPI
VOID
NTAPI
FsRtlPostStackOverflow (
  IN PVOID Context,
  IN PKEVENT Event,
  IN PFSRTL_STACK_OVERFLOW_ROUTINE StackOverflowRoutine);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlRegisterUncProvider(
  OUT PHANDLE MupHandle,
  IN PUNICODE_STRING RedirectorDeviceName,
  IN BOOLEAN MailslotsSupported);

NTKERNELAPI
VOID
NTAPI
FsRtlDeregisterUncProvider(
  IN HANDLE Handle);

NTKERNELAPI
VOID
NTAPI
FsRtlTeardownPerStreamContexts(
  IN PFSRTL_ADVANCED_FCB_HEADER AdvancedHeader);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlCreateSectionForDataScan(
  OUT PHANDLE SectionHandle,
  OUT PVOID *SectionObject,
  OUT PLARGE_INTEGER SectionFileSize OPTIONAL,
  IN PFILE_OBJECT FileObject,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN PLARGE_INTEGER MaximumSize OPTIONAL,
  IN ULONG SectionPageProtection,
  IN ULONG AllocationAttributes,
  IN ULONG Flags);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyFilterChangeDirectory(
  IN PNOTIFY_SYNC NotifySync,
  IN PLIST_ENTRY NotifyList,
  IN PVOID FsContext,
  IN PSTRING FullDirectoryName,
  IN BOOLEAN WatchTree,
  IN BOOLEAN IgnoreBuffer,
  IN ULONG CompletionFilter,
  IN PIRP NotifyIrp OPTIONAL,
  IN PCHECK_FOR_TRAVERSE_ACCESS TraverseCallback OPTIONAL,
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext OPTIONAL,
  IN PFILTER_REPORT_CHANGE FilterCallback OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlInsertPerStreamContext(
  IN PFSRTL_ADVANCED_FCB_HEADER PerStreamContext,
  IN PFSRTL_PER_STREAM_CONTEXT Ptr);

NTKERNELAPI
PFSRTL_PER_STREAM_CONTEXT
NTAPI
FsRtlLookupPerStreamContextInternal(
  IN PFSRTL_ADVANCED_FCB_HEADER StreamContext,
  IN PVOID OwnerId OPTIONAL,
  IN PVOID InstanceId OPTIONAL);

NTKERNELAPI
PFSRTL_PER_STREAM_CONTEXT
NTAPI
FsRtlRemovePerStreamContext(
  IN PFSRTL_ADVANCED_FCB_HEADER StreamContext,
  IN PVOID OwnerId OPTIONAL,
  IN PVOID InstanceId OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlIncrementCcFastReadNotPossible(
  VOID);

NTKERNELAPI
VOID
NTAPI
FsRtlIncrementCcFastReadWait(
  VOID);

NTKERNELAPI
VOID
NTAPI
FsRtlIncrementCcFastReadNoWait(
  VOID);

NTKERNELAPI
VOID
NTAPI
FsRtlIncrementCcFastReadResourceMiss(
  VOID);

NTKERNELAPI
LOGICAL
NTAPI
FsRtlIsPagingFile(
  IN PFILE_OBJECT FileObject);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WS03)

NTKERNELAPI
VOID
NTAPI
FsRtlInitializeBaseMcb(
  IN PBASE_MCB Mcb,
  IN POOL_TYPE PoolType);

NTKERNELAPI
VOID
NTAPI
FsRtlUninitializeBaseMcb(
  IN PBASE_MCB Mcb);

NTKERNELAPI
VOID
NTAPI
FsRtlResetBaseMcb(
  IN PBASE_MCB Mcb);

NTKERNELAPI
VOID
NTAPI
FsRtlTruncateBaseMcb(
  IN PBASE_MCB Mcb,
  IN LONGLONG Vbn);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlAddBaseMcbEntry(
  IN PBASE_MCB Mcb,
  IN LONGLONG Vbn,
  IN LONGLONG Lbn,
  IN LONGLONG SectorCount);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlRemoveBaseMcbEntry(
  IN PBASE_MCB Mcb,
  IN LONGLONG Vbn,
  IN LONGLONG SectorCount);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlLookupBaseMcbEntry(
  IN PBASE_MCB Mcb,
  IN LONGLONG Vbn,
  OUT PLONGLONG Lbn OPTIONAL,
  OUT PLONGLONG SectorCountFromLbn OPTIONAL,
  OUT PLONGLONG StartingLbn OPTIONAL,
  OUT PLONGLONG SectorCountFromStartingLbn OPTIONAL,
  OUT PULONG Index OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlLookupLastBaseMcbEntry(
  IN PBASE_MCB Mcb,
  OUT PLONGLONG Vbn,
  OUT PLONGLONG Lbn);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlLookupLastBaseMcbEntryAndIndex(
  IN PBASE_MCB OpaqueMcb,
  IN OUT PLONGLONG LargeVbn,
  IN OUT PLONGLONG LargeLbn,
  IN OUT PULONG Index);

NTKERNELAPI
ULONG
NTAPI
FsRtlNumberOfRunsInBaseMcb(
  IN PBASE_MCB Mcb);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlGetNextBaseMcbEntry(
  IN PBASE_MCB Mcb,
  IN ULONG RunIndex,
  OUT PLONGLONG Vbn,
  OUT PLONGLONG Lbn,
  OUT PLONGLONG SectorCount);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlSplitBaseMcb(
  IN PBASE_MCB Mcb,
  IN LONGLONG Vbn,
  IN LONGLONG Amount);

#endif /* (NTDDI_VERSION >= NTDDI_WS03) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

BOOLEAN
NTAPI
FsRtlInitializeBaseMcbEx(
  IN PBASE_MCB Mcb,
  IN POOL_TYPE PoolType,
  IN USHORT Flags);

NTSTATUS
NTAPI
FsRtlAddBaseMcbEntryEx(
  IN PBASE_MCB Mcb,
  IN LONGLONG Vbn,
  IN LONGLONG Lbn,
  IN LONGLONG SectorCount);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlCurrentOplock(
  IN POPLOCK Oplock);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlOplockBreakToNone(
  IN OUT POPLOCK Oplock,
  IN PIO_STACK_LOCATION IrpSp OPTIONAL,
  IN PIRP Irp,
  IN PVOID Context OPTIONAL,
  IN POPLOCK_WAIT_COMPLETE_ROUTINE CompletionRoutine OPTIONAL,
  IN POPLOCK_FS_PREPOST_IRP PostIrpRoutine OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlNotifyVolumeEventEx(
  IN PFILE_OBJECT FileObject,
  IN ULONG EventCode,
  IN PTARGET_DEVICE_CUSTOM_NOTIFICATION Event);

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyCleanupAll(
  IN PNOTIFY_SYNC NotifySync,
  IN PLIST_ENTRY NotifyList);

NTSTATUS
NTAPI
FsRtlRegisterUncProviderEx(
  OUT PHANDLE MupHandle,
  IN PUNICODE_STRING RedirDevName,
  IN PDEVICE_OBJECT DeviceObject,
  IN ULONG Flags);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlCancellableWaitForSingleObject(
  IN PVOID Object,
  IN PLARGE_INTEGER Timeout OPTIONAL,
  IN PIRP Irp OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlCancellableWaitForMultipleObjects(
  IN ULONG Count,
  IN PVOID ObjectArray[],
  IN WAIT_TYPE WaitType,
  IN PLARGE_INTEGER Timeout OPTIONAL,
  IN PKWAIT_BLOCK WaitBlockArray OPTIONAL,
  IN PIRP Irp OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlMupGetProviderInfoFromFileObject(
  IN PFILE_OBJECT pFileObject,
  IN ULONG Level,
  OUT PVOID pBuffer,
  IN OUT PULONG pBufferSize);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlMupGetProviderIdFromName(
  IN PUNICODE_STRING pProviderName,
  OUT PULONG32 pProviderId);

NTKERNELAPI
VOID
NTAPI
FsRtlIncrementCcFastMdlReadWait(
  VOID);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlValidateReparsePointBuffer(
  IN ULONG BufferLength,
  IN PREPARSE_DATA_BUFFER ReparseBuffer);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlRemoveDotsFromPath(
  IN OUT PWSTR OriginalString,
  IN USHORT PathLength,
  OUT USHORT *NewLength);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlAllocateExtraCreateParameterList(
  IN FSRTL_ALLOCATE_ECPLIST_FLAGS Flags,
  OUT PECP_LIST *EcpList);

NTKERNELAPI
VOID
NTAPI
FsRtlFreeExtraCreateParameterList(
  IN PECP_LIST EcpList);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlAllocateExtraCreateParameter(
  IN LPCGUID EcpType,
  IN ULONG SizeOfContext,
  IN FSRTL_ALLOCATE_ECP_FLAGS Flags,
  IN PFSRTL_EXTRA_CREATE_PARAMETER_CLEANUP_CALLBACK CleanupCallback OPTIONAL,
  IN ULONG PoolTag,
  OUT PVOID *EcpContext);

NTKERNELAPI
VOID
NTAPI
FsRtlFreeExtraCreateParameter(
  IN PVOID EcpContext);

NTKERNELAPI
VOID
NTAPI
FsRtlInitExtraCreateParameterLookasideList(
  IN OUT PVOID Lookaside,
  IN FSRTL_ECP_LOOKASIDE_FLAGS Flags,
  IN SIZE_T Size,
  IN ULONG Tag);

VOID
NTAPI
FsRtlDeleteExtraCreateParameterLookasideList(
  IN OUT PVOID Lookaside,
  IN FSRTL_ECP_LOOKASIDE_FLAGS Flags);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlAllocateExtraCreateParameterFromLookasideList(
  IN LPCGUID EcpType,
  IN ULONG SizeOfContext,
  IN FSRTL_ALLOCATE_ECP_FLAGS Flags,
  IN PFSRTL_EXTRA_CREATE_PARAMETER_CLEANUP_CALLBACK CleanupCallback OPTIONAL,
  IN OUT PVOID LookasideList,
  OUT PVOID *EcpContext);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlInsertExtraCreateParameter(
  IN OUT PECP_LIST EcpList,
  IN OUT PVOID EcpContext);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlFindExtraCreateParameter(
  IN PECP_LIST EcpList,
  IN LPCGUID EcpType,
  OUT PVOID *EcpContext OPTIONAL,
  OUT ULONG *EcpContextSize OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlRemoveExtraCreateParameter(
  IN OUT PECP_LIST EcpList,
  IN LPCGUID EcpType,
  OUT PVOID *EcpContext,
  OUT ULONG *EcpContextSize OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlGetEcpListFromIrp(
  IN PIRP Irp,
  OUT PECP_LIST *EcpList OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlSetEcpListIntoIrp(
  IN OUT PIRP Irp,
  IN PECP_LIST EcpList);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlGetNextExtraCreateParameter(
  IN PECP_LIST EcpList,
  IN PVOID CurrentEcpContext OPTIONAL,
  OUT LPGUID NextEcpType OPTIONAL,
  OUT PVOID *NextEcpContext OPTIONAL,
  OUT ULONG *NextEcpContextSize OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlAcknowledgeEcp(
  IN PVOID EcpContext);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsEcpAcknowledged(
  IN PVOID EcpContext);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsEcpFromUserMode(
  IN PVOID EcpContext);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlChangeBackingFileObject(
  IN PFILE_OBJECT CurrentFileObject OPTIONAL,
  IN PFILE_OBJECT NewFileObject,
  IN FSRTL_CHANGE_BACKING_TYPE ChangeBackingType,
  IN ULONG Flags);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlLogCcFlushError(
  IN PUNICODE_STRING FileName,
  IN PDEVICE_OBJECT DeviceObject,
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN NTSTATUS FlushError,
  IN ULONG Flags);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlAreVolumeStartupApplicationsComplete(
  VOID);

NTKERNELAPI
ULONG
NTAPI
FsRtlQueryMaximumVirtualDiskNestingLevel(
  VOID);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlGetVirtualDiskNestingLevel(
  IN PDEVICE_OBJECT DeviceObject,
  OUT PULONG NestingLevel,
  OUT PULONG NestingFlags OPTIONAL);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_VISTASP1)
NTKERNELAPI
NTSTATUS
NTAPI
FsRtlCheckOplockEx(
  IN POPLOCK Oplock,
  IN PIRP Irp,
  IN ULONG Flags,
  IN PVOID Context OPTIONAL,
  IN POPLOCK_WAIT_COMPLETE_ROUTINE CompletionRoutine OPTIONAL,
  IN POPLOCK_FS_PREPOST_IRP PostIrpRoutine OPTIONAL);

#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlAreThereCurrentOrInProgressFileLocks(
  IN PFILE_LOCK FileLock);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlOplockIsSharedRequest(
  IN PIRP Irp);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlOplockBreakH(
  IN POPLOCK Oplock,
  IN PIRP Irp,
  IN ULONG Flags,
  IN PVOID Context OPTIONAL,
  IN POPLOCK_WAIT_COMPLETE_ROUTINE CompletionRoutine OPTIONAL,
  IN POPLOCK_FS_PREPOST_IRP PostIrpRoutine OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlCurrentOplockH(
  IN POPLOCK Oplock);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlOplockBreakToNoneEx(
  IN OUT POPLOCK Oplock,
  IN PIRP Irp,
  IN ULONG Flags,
  IN PVOID Context OPTIONAL,
  IN POPLOCK_WAIT_COMPLETE_ROUTINE CompletionRoutine OPTIONAL,
  IN POPLOCK_FS_PREPOST_IRP PostIrpRoutine OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlOplockFsctrlEx(
  IN POPLOCK Oplock,
  IN PIRP Irp,
  IN ULONG OpenCount,
  IN ULONG Flags);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlOplockKeysEqual(
  IN PFILE_OBJECT Fo1 OPTIONAL,
  IN PFILE_OBJECT Fo2 OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlInitializeExtraCreateParameterList(
  IN OUT PECP_LIST EcpList);

NTKERNELAPI
VOID
NTAPI
FsRtlInitializeExtraCreateParameter(
  IN PECP_HEADER Ecp,
  IN ULONG EcpFlags,
  IN PFSRTL_EXTRA_CREATE_PARAMETER_CLEANUP_CALLBACK CleanupCallback OPTIONAL,
  IN ULONG TotalSize,
  IN LPCGUID EcpType,
  IN PVOID ListAllocatedFrom OPTIONAL);

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlInsertPerFileContext(
  IN PVOID* PerFileContextPointer,
  IN PFSRTL_PER_FILE_CONTEXT Ptr);

NTKERNELAPI
PFSRTL_PER_FILE_CONTEXT
NTAPI
FsRtlLookupPerFileContext(
  IN PVOID* PerFileContextPointer,
  IN PVOID OwnerId OPTIONAL,
  IN PVOID InstanceId OPTIONAL);

NTKERNELAPI
PFSRTL_PER_FILE_CONTEXT
NTAPI
FsRtlRemovePerFileContext(
  IN PVOID* PerFileContextPointer,
  IN PVOID OwnerId OPTIONAL,
  IN PVOID InstanceId OPTIONAL);

NTKERNELAPI
VOID
NTAPI
FsRtlTeardownPerFileContexts(
  IN PVOID* PerFileContextPointer);

NTKERNELAPI
NTSTATUS
NTAPI
FsRtlInsertPerFileObjectContext(
  IN PFILE_OBJECT FileObject,
  IN PFSRTL_PER_FILEOBJECT_CONTEXT Ptr);

NTKERNELAPI
PFSRTL_PER_FILEOBJECT_CONTEXT
NTAPI
FsRtlLookupPerFileObjectContext(
  IN PFILE_OBJECT FileObject,
  IN PVOID OwnerId OPTIONAL,
  IN PVOID InstanceId OPTIONAL);

NTKERNELAPI
PFSRTL_PER_FILEOBJECT_CONTEXT
NTAPI
FsRtlRemovePerFileObjectContext(
  IN PFILE_OBJECT FileObject,
  IN PVOID OwnerId OPTIONAL,
  IN PVOID InstanceId OPTIONAL);

#define FsRtlFastLock(A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) (       \
     FsRtlPrivateLock(A1, A2, A3, A4, A5, A6, A7, A8, A9, NULL, A10, A11)   \
)

#define FsRtlAreThereCurrentFileLocks(FL) ( \
    ((FL)->FastIoIsQuestionable)            \
)

#define FsRtlIncrementLockRequestsInProgress(FL) {                           \
    ASSERT( (FL)->LockRequestsInProgress >= 0 );                             \
    (void)                                                                   \
    (InterlockedIncrement((LONG volatile *)&((FL)->LockRequestsInProgress)));\
}

#define FsRtlDecrementLockRequestsInProgress(FL) {                           \
    ASSERT( (FL)->LockRequestsInProgress > 0 );                              \
    (void)                                                                   \
    (InterlockedDecrement((LONG volatile *)&((FL)->LockRequestsInProgress)));\
}

/* GCC compatible definition, MS one is retarded */
extern NTKERNELAPI const UCHAR * const FsRtlLegalAnsiCharacterArray;
#define LEGAL_ANSI_CHARACTER_ARRAY        FsRtlLegalAnsiCharacterArray

#define FsRtlIsAnsiCharacterWild(C) (                                       \
    FlagOn(FsRtlLegalAnsiCharacterArray[(UCHAR)(C)], FSRTL_WILD_CHARACTER ) \
)

#define FsRtlIsAnsiCharacterLegalFat(C, WILD) (                                \
    FlagOn(FsRtlLegalAnsiCharacterArray[(UCHAR)(C)], (FSRTL_FAT_LEGAL) |       \
                                        ((WILD) ? FSRTL_WILD_CHARACTER : 0 ))  \
)

#define FsRtlIsAnsiCharacterLegalHpfs(C, WILD) (                               \
    FlagOn(FsRtlLegalAnsiCharacterArray[(UCHAR)(C)], (FSRTL_HPFS_LEGAL) |      \
                                        ((WILD) ? FSRTL_WILD_CHARACTER : 0 ))  \
)

#define FsRtlIsAnsiCharacterLegalNtfs(C, WILD) (                               \
    FlagOn(FsRtlLegalAnsiCharacterArray[(UCHAR)(C)], (FSRTL_NTFS_LEGAL) |      \
                                        ((WILD) ? FSRTL_WILD_CHARACTER : 0 ))  \
)

#define FsRtlIsAnsiCharacterLegalNtfsStream(C,WILD_OK) (                    \
    FsRtlTestAnsiCharacter((C), TRUE, (WILD_OK), FSRTL_NTFS_STREAM_LEGAL)   \
)

#define FsRtlIsAnsiCharacterLegal(C,FLAGS) (          \
    FsRtlTestAnsiCharacter((C), TRUE, FALSE, (FLAGS)) \
)

#define FsRtlTestAnsiCharacter(C, DEFAULT_RET, WILD_OK, FLAGS) (            \
        ((SCHAR)(C) < 0) ? DEFAULT_RET :                                    \
                           FlagOn( LEGAL_ANSI_CHARACTER_ARRAY[(C)],         \
                                   (FLAGS) |                                \
                                   ((WILD_OK) ? FSRTL_WILD_CHARACTER : 0) ) \
)

#define FsRtlIsLeadDbcsCharacter(DBCS_CHAR) (                               \
    (BOOLEAN)((UCHAR)(DBCS_CHAR) < 0x80 ? FALSE :                           \
              (NLS_MB_CODE_PAGE_TAG &&                                      \
               (NLS_OEM_LEAD_BYTE_INFO[(UCHAR)(DBCS_CHAR)] != 0)))          \
)

#define FsRtlIsUnicodeCharacterWild(C) (                                    \
    (((C) >= 0x40) ?                                                        \
    FALSE :                                                                 \
    FlagOn(FsRtlLegalAnsiCharacterArray[(C)], FSRTL_WILD_CHARACTER ))       \
)

#define FsRtlInitPerFileContext( _fc, _owner, _inst, _cb)   \
    ((_fc)->OwnerId = (_owner),                               \
     (_fc)->InstanceId = (_inst),                             \
     (_fc)->FreeCallback = (_cb))

#define FsRtlGetPerFileContextPointer(_fo) \
    (FsRtlSupportsPerFileContexts(_fo) ? \
        FsRtlGetPerStreamContextPointer(_fo)->FileContextSupportPointer : \
        NULL)

#define FsRtlSupportsPerFileContexts(_fo)                     \
    ((FsRtlGetPerStreamContextPointer(_fo) != NULL) &&        \
     (FsRtlGetPerStreamContextPointer(_fo)->Version >= FSRTL_FCB_HEADER_V1) &&  \
     (FsRtlGetPerStreamContextPointer(_fo)->FileContextSupportPointer != NULL))

#define FsRtlSetupAdvancedHeaderEx( _advhdr, _fmutx, _fctxptr )                     \
{                                                                                   \
    FsRtlSetupAdvancedHeader( _advhdr, _fmutx );                                    \
    if ((_fctxptr) != NULL) {                                                       \
        (_advhdr)->FileContextSupportPointer = (_fctxptr);                          \
    }                                                                               \
}

#define FsRtlGetPerStreamContextPointer(FO) (   \
    (PFSRTL_ADVANCED_FCB_HEADER)(FO)->FsContext \
)

#define FsRtlInitPerStreamContext(PSC, O, I, FC) ( \
    (PSC)->OwnerId = (O),                          \
    (PSC)->InstanceId = (I),                       \
    (PSC)->FreeCallback = (FC)                     \
)

#define FsRtlSupportsPerStreamContexts(FO) (                       \
    (BOOLEAN)((NULL != FsRtlGetPerStreamContextPointer(FO) &&     \
              FlagOn(FsRtlGetPerStreamContextPointer(FO)->Flags2, \
              FSRTL_FLAG2_SUPPORTS_FILTER_CONTEXTS))               \
)

#define FsRtlLookupPerStreamContext(_sc, _oid, _iid)                          \
 (((NULL != (_sc)) &&                                                         \
   FlagOn((_sc)->Flags2,FSRTL_FLAG2_SUPPORTS_FILTER_CONTEXTS) &&              \
   !IsListEmpty(&(_sc)->FilterContexts)) ?                                    \
        FsRtlLookupPerStreamContextInternal((_sc), (_oid), (_iid)) :          \
        NULL)

FORCEINLINE
VOID
NTAPI
FsRtlSetupAdvancedHeader(
  IN PVOID AdvHdr,
  IN PFAST_MUTEX FMutex )
{
  PFSRTL_ADVANCED_FCB_HEADER localAdvHdr = (PFSRTL_ADVANCED_FCB_HEADER)AdvHdr;

  localAdvHdr->Flags |= FSRTL_FLAG_ADVANCED_HEADER;
  localAdvHdr->Flags2 |= FSRTL_FLAG2_SUPPORTS_FILTER_CONTEXTS;
#if (NTDDI_VERSION >= NTDDI_VISTA)
  localAdvHdr->Version = FSRTL_FCB_HEADER_V1;
#else
  localAdvHdr->Version = FSRTL_FCB_HEADER_V0;
#endif
  InitializeListHead( &localAdvHdr->FilterContexts );
  if (FMutex != NULL) {
    localAdvHdr->FastMutex = FMutex;
  }
#if (NTDDI_VERSION >= NTDDI_VISTA)
  *((PULONG_PTR)(&localAdvHdr->PushLock)) = 0;
  localAdvHdr->FileContextSupportPointer = NULL;
#endif
}

#define FsRtlInitPerFileObjectContext(_fc, _owner, _inst)         \
           ((_fc)->OwnerId = (_owner), (_fc)->InstanceId = (_inst))

#define FsRtlCompleteRequest(IRP,STATUS) {         \
    (IRP)->IoStatus.Status = (STATUS);             \
    IoCompleteRequest( (IRP), IO_DISK_INCREMENT ); \
}
/* Common Cache Types */

#define VACB_MAPPING_GRANULARITY        (0x40000)
#define VACB_OFFSET_SHIFT               (18)

typedef struct _PUBLIC_BCB {
  CSHORT NodeTypeCode;
  CSHORT NodeByteSize;
  ULONG MappedLength;
  LARGE_INTEGER MappedFileOffset;
} PUBLIC_BCB, *PPUBLIC_BCB;

typedef struct _CC_FILE_SIZES {
  LARGE_INTEGER AllocationSize;
  LARGE_INTEGER FileSize;
  LARGE_INTEGER ValidDataLength;
} CC_FILE_SIZES, *PCC_FILE_SIZES;

typedef BOOLEAN
(NTAPI *PACQUIRE_FOR_LAZY_WRITE) (
  IN PVOID Context,
  IN BOOLEAN Wait);

typedef VOID
(NTAPI *PRELEASE_FROM_LAZY_WRITE) (
  IN PVOID Context);

typedef BOOLEAN
(NTAPI *PACQUIRE_FOR_READ_AHEAD) (
  IN PVOID Context,
  IN BOOLEAN Wait);

typedef VOID
(NTAPI *PRELEASE_FROM_READ_AHEAD) (
  IN PVOID Context);

typedef struct _CACHE_MANAGER_CALLBACKS {
  PACQUIRE_FOR_LAZY_WRITE AcquireForLazyWrite;
  PRELEASE_FROM_LAZY_WRITE ReleaseFromLazyWrite;
  PACQUIRE_FOR_READ_AHEAD AcquireForReadAhead;
  PRELEASE_FROM_READ_AHEAD ReleaseFromReadAhead;
} CACHE_MANAGER_CALLBACKS, *PCACHE_MANAGER_CALLBACKS;

typedef struct _CACHE_UNINITIALIZE_EVENT {
  struct _CACHE_UNINITIALIZE_EVENT *Next;
  KEVENT Event;
} CACHE_UNINITIALIZE_EVENT, *PCACHE_UNINITIALIZE_EVENT;

typedef VOID
(NTAPI *PDIRTY_PAGE_ROUTINE) (
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN PLARGE_INTEGER OldestLsn,
  IN PLARGE_INTEGER NewestLsn,
  IN PVOID Context1,
  IN PVOID Context2);

typedef VOID
(NTAPI *PFLUSH_TO_LSN) (
  IN PVOID LogHandle,
  IN LARGE_INTEGER Lsn);

typedef VOID
(NTAPI *PCC_POST_DEFERRED_WRITE) (
  IN PVOID Context1,
  IN PVOID Context2);

#define UNINITIALIZE_CACHE_MAPS          (1)
#define DO_NOT_RETRY_PURGE               (2)
#define DO_NOT_PURGE_DIRTY_PAGES         (0x4)

#define CC_FLUSH_AND_PURGE_NO_PURGE     (0x1)
/* Common Cache Functions */

#define CcIsFileCached(FO) (                                                         \
    ((FO)->SectionObjectPointer != NULL) &&                                          \
    (((PSECTION_OBJECT_POINTERS)(FO)->SectionObjectPointer)->SharedCacheMap != NULL) \
)

extern ULONG CcFastMdlReadWait;

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
VOID
NTAPI
CcInitializeCacheMap(
  IN PFILE_OBJECT FileObject,
  IN PCC_FILE_SIZES FileSizes,
  IN BOOLEAN PinAccess,
  IN PCACHE_MANAGER_CALLBACKS Callbacks,
  IN PVOID LazyWriteContext);

NTKERNELAPI
BOOLEAN
NTAPI
CcUninitializeCacheMap(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER TruncateSize OPTIONAL,
  IN PCACHE_UNINITIALIZE_EVENT UninitializeCompleteEvent OPTIONAL);

NTKERNELAPI
VOID
NTAPI
CcSetFileSizes(
  IN PFILE_OBJECT FileObject,
  IN PCC_FILE_SIZES FileSizes);

NTKERNELAPI
VOID
NTAPI
CcSetDirtyPageThreshold(
  IN PFILE_OBJECT FileObject,
  IN ULONG DirtyPageThreshold);

NTKERNELAPI
VOID
NTAPI
CcFlushCache(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN PLARGE_INTEGER FileOffset OPTIONAL,
  IN ULONG Length,
  OUT PIO_STATUS_BLOCK IoStatus OPTIONAL);

NTKERNELAPI
LARGE_INTEGER
NTAPI
CcGetFlushedValidData(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN BOOLEAN BcbListHeld);

NTKERNELAPI
BOOLEAN
NTAPI
CcZeroData(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER StartOffset,
  IN PLARGE_INTEGER EndOffset,
  IN BOOLEAN Wait);

NTKERNELAPI
PVOID
NTAPI
CcRemapBcb(
  IN PVOID Bcb);

NTKERNELAPI
VOID
NTAPI
CcRepinBcb(
  IN PVOID Bcb);

NTKERNELAPI
VOID
NTAPI
CcUnpinRepinnedBcb(
  IN PVOID Bcb,
  IN BOOLEAN WriteThrough,
  OUT PIO_STATUS_BLOCK IoStatus);

NTKERNELAPI
PFILE_OBJECT
NTAPI
CcGetFileObjectFromSectionPtrs(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer);

NTKERNELAPI
PFILE_OBJECT
NTAPI
CcGetFileObjectFromBcb(
  IN PVOID Bcb);

NTKERNELAPI
BOOLEAN
NTAPI
CcCanIWrite(
  IN PFILE_OBJECT FileObject,
  IN ULONG BytesToWrite,
  IN BOOLEAN Wait,
  IN BOOLEAN Retrying);

NTKERNELAPI
VOID
NTAPI
CcDeferWrite(
  IN PFILE_OBJECT FileObject,
  IN PCC_POST_DEFERRED_WRITE PostRoutine,
  IN PVOID Context1,
  IN PVOID Context2,
  IN ULONG BytesToWrite,
  IN BOOLEAN Retrying);

NTKERNELAPI
BOOLEAN
NTAPI
CcCopyRead(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Wait,
  OUT PVOID Buffer,
  OUT PIO_STATUS_BLOCK IoStatus);

NTKERNELAPI
VOID
NTAPI
CcFastCopyRead(
  IN PFILE_OBJECT FileObject,
  IN ULONG FileOffset,
  IN ULONG Length,
  IN ULONG PageCount,
  OUT PVOID Buffer,
  OUT PIO_STATUS_BLOCK IoStatus);

NTKERNELAPI
BOOLEAN
NTAPI
CcCopyWrite(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Wait,
  IN PVOID Buffer);

NTKERNELAPI
VOID
NTAPI
CcFastCopyWrite(
  IN PFILE_OBJECT FileObject,
  IN ULONG FileOffset,
  IN ULONG Length,
  IN PVOID Buffer);

NTKERNELAPI
VOID
NTAPI
CcMdlRead(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  OUT PMDL *MdlChain,
  OUT PIO_STATUS_BLOCK IoStatus);

NTKERNELAPI
VOID
NTAPI
CcMdlReadComplete(
  IN PFILE_OBJECT FileObject,
  IN PMDL MdlChain);

NTKERNELAPI
VOID
NTAPI
CcPrepareMdlWrite(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  OUT PMDL *MdlChain,
  OUT PIO_STATUS_BLOCK IoStatus);

NTKERNELAPI
VOID
NTAPI
CcMdlWriteComplete(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN PMDL MdlChain);

NTKERNELAPI
VOID
NTAPI
CcScheduleReadAhead(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length);

NTKERNELAPI
NTSTATUS
NTAPI
CcWaitForCurrentLazyWriterActivity(
  VOID);

NTKERNELAPI
VOID
NTAPI
CcSetReadAheadGranularity(
  IN PFILE_OBJECT FileObject,
  IN ULONG Granularity);

NTKERNELAPI
BOOLEAN
NTAPI
CcPinRead(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG Flags,
  OUT PVOID *Bcb,
  OUT PVOID *Buffer);

NTKERNELAPI
BOOLEAN
NTAPI
CcPinMappedData(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG Flags,
  IN OUT PVOID *Bcb);

NTKERNELAPI
BOOLEAN
NTAPI
CcPreparePinWrite(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Zero,
  IN ULONG Flags,
  OUT PVOID *Bcb,
  OUT PVOID *Buffer);

NTKERNELAPI
VOID
NTAPI
CcSetDirtyPinnedData(
  IN PVOID BcbVoid,
  IN PLARGE_INTEGER Lsn OPTIONAL);

NTKERNELAPI
VOID
NTAPI
CcUnpinData(
  IN PVOID Bcb);

NTKERNELAPI
VOID
NTAPI
CcSetBcbOwnerPointer(
  IN PVOID Bcb,
  IN PVOID OwnerPointer);

NTKERNELAPI
VOID
NTAPI
CcUnpinDataForThread(
  IN PVOID Bcb,
  IN ERESOURCE_THREAD ResourceThreadId);

NTKERNELAPI
VOID
NTAPI
CcSetAdditionalCacheAttributes(
  IN PFILE_OBJECT FileObject,
  IN BOOLEAN DisableReadAhead,
  IN BOOLEAN DisableWriteBehind);

NTKERNELAPI
BOOLEAN
NTAPI
CcIsThereDirtyData(
  IN PVPB Vpb);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
VOID
NTAPI
CcMdlWriteAbort(
  IN PFILE_OBJECT FileObject,
  IN PMDL MdlChain);

NTKERNELAPI
VOID
NTAPI
CcSetLogHandleForFile(
  IN PFILE_OBJECT FileObject,
  IN PVOID LogHandle,
  IN PFLUSH_TO_LSN FlushToLsnRoutine);

NTKERNELAPI
LARGE_INTEGER
NTAPI
CcGetDirtyPages(
  IN PVOID LogHandle,
  IN PDIRTY_PAGE_ROUTINE DirtyPageRoutine,
  IN PVOID Context1,
  IN PVOID Context2);

#endif

#if (NTDDI_VERSION >= NTDDI_WINXP)
NTKERNELAPI
BOOLEAN
NTAPI
CcMapData(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG Flags,
  OUT PVOID *Bcb,
  OUT PVOID *Buffer);
#elif (NTDDI_VERSION >= NTDDI_WIN2K)
NTKERNELAPI
BOOLEAN
NTAPI
CcMapData(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Wait,
  OUT PVOID *Bcb,
  OUT PVOID *Buffer);
#endif

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTKERNELAPI
NTSTATUS
NTAPI
CcSetFileSizesEx(
  IN PFILE_OBJECT FileObject,
  IN PCC_FILE_SIZES FileSizes);

NTKERNELAPI
PFILE_OBJECT
NTAPI
CcGetFileObjectFromSectionPtrsRef(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer);

NTKERNELAPI
VOID
NTAPI
CcSetParallelFlushFile(
  IN PFILE_OBJECT FileObject,
  IN BOOLEAN EnableParallelFlush);

NTKERNELAPI
BOOLEAN
CcIsThereDirtyDataEx(
  IN PVPB Vpb,
  IN PULONG NumberOfDirtyPages OPTIONAL);

#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)
NTKERNELAPI
VOID
NTAPI
CcCoherencyFlushAndPurgeCache(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN PLARGE_INTEGER FileOffset OPTIONAL,
  IN ULONG Length,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN ULONG Flags OPTIONAL);
#endif

#define CcGetFileSizePointer(FO) (                                     \
    ((PLARGE_INTEGER)((FO)->SectionObjectPointer->SharedCacheMap) + 1) \
)

#if (NTDDI_VERSION >= NTDDI_VISTA)
NTKERNELAPI
BOOLEAN
NTAPI
CcPurgeCacheSection(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN PLARGE_INTEGER FileOffset OPTIONAL,
  IN ULONG Length,
  IN ULONG Flags);
#elif (NTDDI_VERSION >= NTDDI_WIN2K)
NTKERNELAPI
BOOLEAN
NTAPI
CcPurgeCacheSection(
  IN PSECTION_OBJECT_POINTERS SectionObjectPointer,
  IN PLARGE_INTEGER FileOffset OPTIONAL,
  IN ULONG Length,
  IN BOOLEAN UninitializeCacheMaps);
#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)
NTKERNELAPI
BOOLEAN
NTAPI
CcCopyWriteWontFlush(
  IN PFILE_OBJECT FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length);
#else
#define CcCopyWriteWontFlush(FO, FOFF, LEN) ((LEN) <= 0x10000)
#endif

#define CcReadAhead(FO, FOFF, LEN) (                \
    if ((LEN) >= 256) {                             \
        CcScheduleReadAhead((FO), (FOFF), (LEN));   \
    }                                               \
)


/******************************************************************************
 *                            ZwXxx Functions                                 *
 ******************************************************************************/

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryEaFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID Buffer,
  IN ULONG Length,
  IN BOOLEAN ReturnSingleEntry,
  IN PVOID EaList OPTIONAL,
  IN ULONG EaListLength,
  IN PULONG EaIndex OPTIONAL,
  IN BOOLEAN RestartScan);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetEaFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID Buffer,
  IN ULONG Length);

NTSYSAPI
NTSTATUS
NTAPI
ZwDuplicateToken(
  IN HANDLE ExistingTokenHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN BOOLEAN EffectiveOnly,
  IN TOKEN_TYPE TokenType,
  OUT PHANDLE NewTokenHandle);

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryObject(
  IN HANDLE Handle OPTIONAL,
  IN OBJECT_INFORMATION_CLASS ObjectInformationClass,
  OUT PVOID ObjectInformation OPTIONAL,
  IN ULONG ObjectInformationLength,
  OUT PULONG ReturnLength OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwNotifyChangeKey(
  IN HANDLE KeyHandle,
  IN HANDLE EventHandle OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN ULONG NotifyFilter,
  IN BOOLEAN WatchSubtree,
  OUT PVOID Buffer,
  IN ULONG BufferLength,
  IN BOOLEAN Asynchronous);

NTSYSAPI
NTSTATUS
NTAPI
ZwCreateEvent(
  OUT PHANDLE EventHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN EVENT_TYPE EventType,
  IN BOOLEAN InitialState);

NTSYSAPI
NTSTATUS
NTAPI
ZwDeleteFile(
  IN POBJECT_ATTRIBUTES ObjectAttributes);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryDirectoryFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID FileInformation,
  IN ULONG Length,
  IN FILE_INFORMATION_CLASS FileInformationClass,
  IN BOOLEAN ReturnSingleEntry,
  IN PUNICODE_STRING FileName OPTIONAL,
  IN BOOLEAN RestartScan);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetVolumeInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PVOID FsInformation,
  IN ULONG Length,
  IN FS_INFORMATION_CLASS FsInformationClass);

NTSYSAPI
NTSTATUS
NTAPI
ZwFsControlFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN ULONG FsControlCode,
  IN PVOID InputBuffer OPTIONAL,
  IN ULONG InputBufferLength,
  OUT PVOID OutputBuffer OPTIONAL,
  IN ULONG OutputBufferLength);

NTSYSAPI
NTSTATUS
NTAPI
ZwDuplicateObject(
  IN HANDLE SourceProcessHandle,
  IN HANDLE SourceHandle,
  IN HANDLE TargetProcessHandle OPTIONAL,
  OUT PHANDLE TargetHandle OPTIONAL,
  IN ACCESS_MASK DesiredAccess,
  IN ULONG HandleAttributes,
  IN ULONG Options);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenDirectoryObject(
  OUT PHANDLE DirectoryHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes);

NTSYSAPI
NTSTATUS
NTAPI
ZwAllocateVirtualMemory(
  IN HANDLE ProcessHandle,
  IN OUT PVOID *BaseAddress,
  IN ULONG_PTR ZeroBits,
  IN OUT PSIZE_T RegionSize,
  IN ULONG AllocationType,
  IN ULONG Protect);

NTSYSAPI
NTSTATUS
NTAPI
ZwFreeVirtualMemory(
  IN HANDLE ProcessHandle,
  IN OUT PVOID *BaseAddress,
  IN OUT PSIZE_T RegionSize,
  IN ULONG FreeType);

NTSYSAPI
NTSTATUS
NTAPI
ZwWaitForSingleObject(
  IN HANDLE Handle,
  IN BOOLEAN Alertable,
  IN PLARGE_INTEGER Timeout OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetEvent(
  IN HANDLE EventHandle,
  OUT PLONG PreviousState OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwFlushVirtualMemory(
  IN HANDLE ProcessHandle,
  IN OUT PVOID *BaseAddress,
  IN OUT PSIZE_T RegionSize,
  OUT PIO_STATUS_BLOCK IoStatusBlock);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryInformationToken(
  IN HANDLE TokenHandle,
  IN TOKEN_INFORMATION_CLASS TokenInformationClass,
  OUT PVOID TokenInformation,
  IN ULONG Length,
  OUT PULONG ResultLength);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetSecurityObject(
  IN HANDLE Handle,
  IN SECURITY_INFORMATION SecurityInformation,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);

NTSYSAPI
NTSTATUS
NTAPI
ZwQuerySecurityObject(
  IN HANDLE FileHandle,
  IN SECURITY_INFORMATION SecurityInformation,
  OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN ULONG Length,
  OUT PULONG ResultLength);
#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenProcessTokenEx(
  IN HANDLE ProcessHandle,
  IN ACCESS_MASK DesiredAccess,
  IN ULONG HandleAttributes,
  OUT PHANDLE TokenHandle);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenThreadTokenEx(
  IN HANDLE ThreadHandle,
  IN ACCESS_MASK DesiredAccess,
  IN BOOLEAN OpenAsSelf,
  IN ULONG HandleAttributes,
  OUT PHANDLE TokenHandle);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTSYSAPI
NTSTATUS
NTAPI
ZwLockFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PLARGE_INTEGER ByteOffset,
  IN PLARGE_INTEGER Length,
  IN ULONG Key,
  IN BOOLEAN FailImmediately,
  IN BOOLEAN ExclusiveLock);

NTSYSAPI
NTSTATUS
NTAPI
ZwUnlockFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PLARGE_INTEGER ByteOffset,
  IN PLARGE_INTEGER Length,
  IN ULONG Key);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryQuotaInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID Buffer,
  IN ULONG Length,
  IN BOOLEAN ReturnSingleEntry,
  IN PVOID SidList,
  IN ULONG SidListLength,
  IN PSID StartSid OPTIONAL,
  IN BOOLEAN RestartScan);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetQuotaInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PVOID Buffer,
  IN ULONG Length);

NTSYSAPI
NTSTATUS
NTAPI
ZwFlushBuffersFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock);
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTSYSAPI
NTSTATUS
NTAPI
ZwSetInformationToken(
  IN HANDLE TokenHandle,
  IN TOKEN_INFORMATION_CLASS TokenInformationClass,
  IN PVOID TokenInformation,
  IN ULONG TokenInformationLength);
#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */


/* #if !defined(_X86AMD64_)  FIXME : WHAT ?! */
#if defined(_WIN64)

C_ASSERT(sizeof(ERESOURCE) == 0x68);
C_ASSERT(FIELD_OFFSET(ERESOURCE,ActiveCount) == 0x18);
C_ASSERT(FIELD_OFFSET(ERESOURCE,Flag) == 0x1a);

#else

C_ASSERT(sizeof(ERESOURCE) == 0x38);
C_ASSERT(FIELD_OFFSET(ERESOURCE,ActiveCount) == 0x0c);
C_ASSERT(FIELD_OFFSET(ERESOURCE,Flag) == 0x0e);

#endif
/* #endif */

#if defined(_IA64_)
#if (NTDDI_VERSION >= NTDDI_WIN2K)
//DECLSPEC_DEPRECATED_DDK
NTHALAPI
ULONG
NTAPI
HalGetDmaAlignmentRequirement(
  VOID);
#endif
#endif

#if defined(_M_IX86) || defined(_M_AMD64)
#define HalGetDmaAlignmentRequirement() 1L
#endif

extern NTKERNELAPI PUSHORT NlsOemLeadByteInfo;
#define NLS_OEM_LEAD_BYTE_INFO            NlsOemLeadByteInfo

#ifdef NLS_MB_CODE_PAGE_TAG
#undef NLS_MB_CODE_PAGE_TAG
#endif
#define NLS_MB_CODE_PAGE_TAG              NlsMbOemCodePageTag

#if (NTDDI_VERSION >= NTDDI_VISTA)

typedef enum _NETWORK_OPEN_LOCATION_QUALIFIER {
  NetworkOpenLocationAny,
  NetworkOpenLocationRemote,
  NetworkOpenLocationLoopback
} NETWORK_OPEN_LOCATION_QUALIFIER;

typedef enum _NETWORK_OPEN_INTEGRITY_QUALIFIER {
  NetworkOpenIntegrityAny,
  NetworkOpenIntegrityNone,
  NetworkOpenIntegritySigned,
  NetworkOpenIntegrityEncrypted,
  NetworkOpenIntegrityMaximum
} NETWORK_OPEN_INTEGRITY_QUALIFIER;

#if (NTDDI_VERSION >= NTDDI_WIN7)

#define NETWORK_OPEN_ECP_IN_FLAG_DISABLE_HANDLE_COLLAPSING 0x1
#define NETWORK_OPEN_ECP_IN_FLAG_DISABLE_HANDLE_DURABILITY 0x2
#define NETWORK_OPEN_ECP_IN_FLAG_FORCE_BUFFERED_SYNCHRONOUS_IO_HACK 0x80000000

typedef struct _NETWORK_OPEN_ECP_CONTEXT {
  USHORT Size;
  USHORT Reserved;
  _ANONYMOUS_STRUCT struct {
    struct {
      NETWORK_OPEN_LOCATION_QUALIFIER Location;
      NETWORK_OPEN_INTEGRITY_QUALIFIER Integrity;
      ULONG Flags;
    } in;
    struct {
      NETWORK_OPEN_LOCATION_QUALIFIER Location;
      NETWORK_OPEN_INTEGRITY_QUALIFIER Integrity;
      ULONG Flags;
    } out;
  } DUMMYSTRUCTNAME;
} NETWORK_OPEN_ECP_CONTEXT, *PNETWORK_OPEN_ECP_CONTEXT;

typedef struct _NETWORK_OPEN_ECP_CONTEXT_V0 {
  USHORT Size;
  USHORT Reserved;
  _ANONYMOUS_STRUCT struct {
    struct {
    NETWORK_OPEN_LOCATION_QUALIFIER Location;
    NETWORK_OPEN_INTEGRITY_QUALIFIER Integrity;
    } in;
    struct {
      NETWORK_OPEN_LOCATION_QUALIFIER Location;
      NETWORK_OPEN_INTEGRITY_QUALIFIER Integrity;
    } out;
  } DUMMYSTRUCTNAME;
} NETWORK_OPEN_ECP_CONTEXT_V0, *PNETWORK_OPEN_ECP_CONTEXT_V0;

#elif (NTDDI_VERSION >= NTDDI_VISTA)
typedef struct _NETWORK_OPEN_ECP_CONTEXT {
  USHORT Size;
  USHORT Reserved;
  _ANONYMOUS_STRUCT struct {
    struct {
      NETWORK_OPEN_LOCATION_QUALIFIER Location;
      NETWORK_OPEN_INTEGRITY_QUALIFIER Integrity;
    } in;
    struct {
      NETWORK_OPEN_LOCATION_QUALIFIER Location;
      NETWORK_OPEN_INTEGRITY_QUALIFIER Integrity;
    } out;
  } DUMMYSTRUCTNAME;
} NETWORK_OPEN_ECP_CONTEXT, *PNETWORK_OPEN_ECP_CONTEXT;
#endif

DEFINE_GUID(GUID_ECP_NETWORK_OPEN_CONTEXT, 0xc584edbf, 0x00df, 0x4d28, 0xb8, 0x84, 0x35, 0xba, 0xca, 0x89, 0x11, 0xe8);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */


#if (NTDDI_VERSION >= NTDDI_VISTA)

typedef struct _PREFETCH_OPEN_ECP_CONTEXT {
  PVOID Context;
} PREFETCH_OPEN_ECP_CONTEXT, *PPREFETCH_OPEN_ECP_CONTEXT;

DEFINE_GUID(GUID_ECP_PREFETCH_OPEN, 0xe1777b21, 0x847e, 0x4837, 0xaa, 0x45, 0x64, 0x16, 0x1d, 0x28, 0x6, 0x55);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WIN7)

DEFINE_GUID (GUID_ECP_NFS_OPEN, 0xf326d30c, 0xe5f8, 0x4fe7, 0xab, 0x74, 0xf5, 0xa3, 0x19, 0x6d, 0x92, 0xdb);
DEFINE_GUID (GUID_ECP_SRV_OPEN, 0xbebfaebc, 0xaabf, 0x489d, 0x9d, 0x2c, 0xe9, 0xe3, 0x61, 0x10, 0x28, 0x53);

typedef struct sockaddr_storage *PSOCKADDR_STORAGE_NFS;

typedef struct _NFS_OPEN_ECP_CONTEXT {
  PUNICODE_STRING ExportAlias;
  PSOCKADDR_STORAGE_NFS ClientSocketAddress;
} NFS_OPEN_ECP_CONTEXT, *PNFS_OPEN_ECP_CONTEXT, **PPNFS_OPEN_ECP_CONTEXT;

typedef struct _SRV_OPEN_ECP_CONTEXT {
  PUNICODE_STRING ShareName;
  PSOCKADDR_STORAGE_NFS SocketAddress;
  BOOLEAN OplockBlockState;
  BOOLEAN OplockAppState;
  BOOLEAN OplockFinalState;
} SRV_OPEN_ECP_CONTEXT, *PSRV_OPEN_ECP_CONTEXT;

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

#define PIN_WAIT                        (1)
#define PIN_EXCLUSIVE                   (2)
#define PIN_NO_READ                     (4)
#define PIN_IF_BCB                      (8)
#define PIN_CALLER_TRACKS_DIRTY_DATA    (32)
#define PIN_HIGH_PRIORITY               (64)

#define MAP_WAIT                        1
#define MAP_NO_READ                     (16)
#define MAP_HIGH_PRIORITY               (64)

#define IOCTL_REDIR_QUERY_PATH          CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 99, METHOD_NEITHER, FILE_ANY_ACCESS)
#define IOCTL_REDIR_QUERY_PATH_EX       CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 100, METHOD_NEITHER, FILE_ANY_ACCESS)

typedef struct _QUERY_PATH_REQUEST {
  ULONG PathNameLength;
  PIO_SECURITY_CONTEXT SecurityContext;
  WCHAR FilePathName[1];
} QUERY_PATH_REQUEST, *PQUERY_PATH_REQUEST;

typedef struct _QUERY_PATH_REQUEST_EX {
  PIO_SECURITY_CONTEXT pSecurityContext;
  ULONG EaLength;
  PVOID pEaBuffer;
  UNICODE_STRING PathName;
  UNICODE_STRING DomainServiceName;
  ULONG_PTR Reserved[ 3 ];
} QUERY_PATH_REQUEST_EX, *PQUERY_PATH_REQUEST_EX;

typedef struct _QUERY_PATH_RESPONSE {
  ULONG LengthAccepted;
} QUERY_PATH_RESPONSE, *PQUERY_PATH_RESPONSE;

#define VOLSNAPCONTROLTYPE                              0x00000053
#define IOCTL_VOLSNAP_FLUSH_AND_HOLD_WRITES             CTL_CODE(VOLSNAPCONTROLTYPE, 0, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

/* FIXME : These definitions below don't belong here (or anywhere in ddk really) */
#pragma pack(push,4)

#ifndef VER_PRODUCTBUILD
#define VER_PRODUCTBUILD 10000
#endif

#include "csq.h"

extern PACL                         SePublicDefaultDacl;
extern PACL                         SeSystemDefaultDacl;

#define FS_LFN_APIS                             0x00004000

#define FILE_STORAGE_TYPE_SPECIFIED             0x00000041  /* FILE_DIRECTORY_FILE | FILE_NON_DIRECTORY_FILE */
#define FILE_STORAGE_TYPE_DEFAULT               (StorageTypeDefault << FILE_STORAGE_TYPE_SHIFT)
#define FILE_STORAGE_TYPE_DIRECTORY             (StorageTypeDirectory << FILE_STORAGE_TYPE_SHIFT)
#define FILE_STORAGE_TYPE_FILE                  (StorageTypeFile << FILE_STORAGE_TYPE_SHIFT)
#define FILE_STORAGE_TYPE_DOCFILE               (StorageTypeDocfile << FILE_STORAGE_TYPE_SHIFT)
#define FILE_STORAGE_TYPE_JUNCTION_POINT        (StorageTypeJunctionPoint << FILE_STORAGE_TYPE_SHIFT)
#define FILE_STORAGE_TYPE_CATALOG               (StorageTypeCatalog << FILE_STORAGE_TYPE_SHIFT)
#define FILE_STORAGE_TYPE_STRUCTURED_STORAGE    (StorageTypeStructuredStorage << FILE_STORAGE_TYPE_SHIFT)
#define FILE_STORAGE_TYPE_EMBEDDING             (StorageTypeEmbedding << FILE_STORAGE_TYPE_SHIFT)
#define FILE_STORAGE_TYPE_STREAM                (StorageTypeStream << FILE_STORAGE_TYPE_SHIFT)
#define FILE_MINIMUM_STORAGE_TYPE               FILE_STORAGE_TYPE_DEFAULT
#define FILE_MAXIMUM_STORAGE_TYPE               FILE_STORAGE_TYPE_STREAM
#define FILE_STORAGE_TYPE_MASK                  0x000f0000
#define FILE_STORAGE_TYPE_SHIFT                 16

#define FILE_VC_QUOTAS_LOG_VIOLATIONS           0x00000004

#ifdef _X86_
#define HARDWARE_PTE    HARDWARE_PTE_X86
#define PHARDWARE_PTE   PHARDWARE_PTE_X86
#endif

#define IO_ATTACH_DEVICE_API            0x80000000

#define IO_TYPE_APC                     18
#define IO_TYPE_DPC                     19
#define IO_TYPE_DEVICE_QUEUE            20
#define IO_TYPE_EVENT_PAIR              21
#define IO_TYPE_INTERRUPT               22
#define IO_TYPE_PROFILE                 23

#define IRP_BEING_VERIFIED              0x10

#define MAILSLOT_CLASS_FIRSTCLASS       1
#define MAILSLOT_CLASS_SECONDCLASS      2

#define MAILSLOT_SIZE_AUTO              0

#define MEM_DOS_LIM                     0x40000000

#define OB_TYPE_TYPE                    1
#define OB_TYPE_DIRECTORY               2
#define OB_TYPE_SYMBOLIC_LINK           3
#define OB_TYPE_TOKEN                   4
#define OB_TYPE_PROCESS                 5
#define OB_TYPE_THREAD                  6
#define OB_TYPE_EVENT                   7
#define OB_TYPE_EVENT_PAIR              8
#define OB_TYPE_MUTANT                  9
#define OB_TYPE_SEMAPHORE               10
#define OB_TYPE_TIMER                   11
#define OB_TYPE_PROFILE                 12
#define OB_TYPE_WINDOW_STATION          13
#define OB_TYPE_DESKTOP                 14
#define OB_TYPE_SECTION                 15
#define OB_TYPE_KEY                     16
#define OB_TYPE_PORT                    17
#define OB_TYPE_ADAPTER                 18
#define OB_TYPE_CONTROLLER              19
#define OB_TYPE_DEVICE                  20
#define OB_TYPE_DRIVER                  21
#define OB_TYPE_IO_COMPLETION           22
#define OB_TYPE_FILE                    23

#define SEC_BASED 0x00200000

/* end winnt.h */

#define TOKEN_HAS_ADMIN_GROUP           0x08

#if (VER_PRODUCTBUILD >= 1381)
#define FSCTL_GET_HFS_INFORMATION       CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 31, METHOD_BUFFERED, FILE_ANY_ACCESS)
#endif /* (VER_PRODUCTBUILD >= 1381) */

#if (VER_PRODUCTBUILD >= 2195)

#define FSCTL_READ_PROPERTY_DATA        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 33, METHOD_NEITHER, FILE_ANY_ACCESS)
#define FSCTL_WRITE_PROPERTY_DATA       CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 34, METHOD_NEITHER, FILE_ANY_ACCESS)

#define FSCTL_DUMP_PROPERTY_DATA        CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 37,  METHOD_NEITHER, FILE_ANY_ACCESS)

#define FSCTL_HSM_MSG                   CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 66, METHOD_BUFFERED, FILE_READ_DATA | FILE_WRITE_DATA)
#define FSCTL_NSS_CONTROL               CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 67, METHOD_BUFFERED, FILE_WRITE_DATA)
#define FSCTL_HSM_DATA                  CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 68, METHOD_NEITHER, FILE_READ_DATA | FILE_WRITE_DATA)
#define FSCTL_NSS_RCONTROL              CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 70, METHOD_BUFFERED, FILE_READ_DATA)
#endif /* (VER_PRODUCTBUILD >= 2195) */

#define FSCTL_NETWORK_SET_CONFIGURATION_INFO    CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 102, METHOD_IN_DIRECT, FILE_ANY_ACCESS)
#define FSCTL_NETWORK_GET_CONFIGURATION_INFO    CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 103, METHOD_OUT_DIRECT, FILE_ANY_ACCESS)
#define FSCTL_NETWORK_GET_CONNECTION_INFO       CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 104, METHOD_NEITHER, FILE_ANY_ACCESS)
#define FSCTL_NETWORK_ENUMERATE_CONNECTIONS     CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 105, METHOD_NEITHER, FILE_ANY_ACCESS)
#define FSCTL_NETWORK_DELETE_CONNECTION         CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 107, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_NETWORK_GET_STATISTICS            CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 116, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_NETWORK_SET_DOMAIN_NAME           CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 120, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define FSCTL_NETWORK_REMOTE_BOOT_INIT_SCRT     CTL_CODE(FILE_DEVICE_NETWORK_FILE_SYSTEM, 250, METHOD_BUFFERED, FILE_ANY_ACCESS)

typedef enum _FILE_STORAGE_TYPE {
    StorageTypeDefault = 1,
    StorageTypeDirectory,
    StorageTypeFile,
    StorageTypeJunctionPoint,
    StorageTypeCatalog,
    StorageTypeStructuredStorage,
    StorageTypeEmbedding,
    StorageTypeStream
} FILE_STORAGE_TYPE;

typedef struct _OBJECT_BASIC_INFORMATION
{
    ULONG Attributes;
    ACCESS_MASK GrantedAccess;
    ULONG HandleCount;
    ULONG PointerCount;
    ULONG PagedPoolCharge;
    ULONG NonPagedPoolCharge;
    ULONG Reserved[ 3 ];
    ULONG NameInfoSize;
    ULONG TypeInfoSize;
    ULONG SecurityDescriptorSize;
    LARGE_INTEGER CreationTime;
} OBJECT_BASIC_INFORMATION, *POBJECT_BASIC_INFORMATION;

typedef struct _BITMAP_RANGE {
    LIST_ENTRY      Links;
    LONGLONG        BasePage;
    ULONG           FirstDirtyPage;
    ULONG           LastDirtyPage;
    ULONG           DirtyPages;
    PULONG          Bitmap;
} BITMAP_RANGE, *PBITMAP_RANGE;

typedef struct _FILE_COPY_ON_WRITE_INFORMATION {
    BOOLEAN ReplaceIfExists;
    HANDLE  RootDirectory;
    ULONG   FileNameLength;
    WCHAR   FileName[1];
} FILE_COPY_ON_WRITE_INFORMATION, *PFILE_COPY_ON_WRITE_INFORMATION;

typedef struct _FILE_FULL_DIRECTORY_INFORMATION {
    ULONG           NextEntryOffset;
    ULONG           FileIndex;
    LARGE_INTEGER   CreationTime;
    LARGE_INTEGER   LastAccessTime;
    LARGE_INTEGER   LastWriteTime;
    LARGE_INTEGER   ChangeTime;
    LARGE_INTEGER   EndOfFile;
    LARGE_INTEGER   AllocationSize;
    ULONG           FileAttributes;
    ULONG           FileNameLength;
    ULONG           EaSize;
    WCHAR           FileName[ANYSIZE_ARRAY];
} FILE_FULL_DIRECTORY_INFORMATION, *PFILE_FULL_DIRECTORY_INFORMATION;

/* raw internal file lock struct returned from FsRtlGetNextFileLock */
typedef struct _FILE_SHARED_LOCK_ENTRY {
    PVOID           Unknown1;
    PVOID           Unknown2;
    FILE_LOCK_INFO  FileLock;
} FILE_SHARED_LOCK_ENTRY, *PFILE_SHARED_LOCK_ENTRY;

/* raw internal file lock struct returned from FsRtlGetNextFileLock */
typedef struct _FILE_EXCLUSIVE_LOCK_ENTRY {
    LIST_ENTRY      ListEntry;
    PVOID           Unknown1;
    PVOID           Unknown2;
    FILE_LOCK_INFO  FileLock;
} FILE_EXCLUSIVE_LOCK_ENTRY, *PFILE_EXCLUSIVE_LOCK_ENTRY;

typedef struct _FILE_MAILSLOT_PEEK_BUFFER {
    ULONG ReadDataAvailable;
    ULONG NumberOfMessages;
    ULONG MessageLength;
} FILE_MAILSLOT_PEEK_BUFFER, *PFILE_MAILSLOT_PEEK_BUFFER;

typedef struct _FILE_OLE_CLASSID_INFORMATION {
    GUID ClassId;
} FILE_OLE_CLASSID_INFORMATION, *PFILE_OLE_CLASSID_INFORMATION;

typedef struct _FILE_OLE_ALL_INFORMATION {
    FILE_BASIC_INFORMATION          BasicInformation;
    FILE_STANDARD_INFORMATION       StandardInformation;
    FILE_INTERNAL_INFORMATION       InternalInformation;
    FILE_EA_INFORMATION             EaInformation;
    FILE_ACCESS_INFORMATION         AccessInformation;
    FILE_POSITION_INFORMATION       PositionInformation;
    FILE_MODE_INFORMATION           ModeInformation;
    FILE_ALIGNMENT_INFORMATION      AlignmentInformation;
    USN                             LastChangeUsn;
    USN                             ReplicationUsn;
    LARGE_INTEGER                   SecurityChangeTime;
    FILE_OLE_CLASSID_INFORMATION    OleClassIdInformation;
    FILE_OBJECTID_INFORMATION       ObjectIdInformation;
    FILE_STORAGE_TYPE               StorageType;
    ULONG                           OleStateBits;
    ULONG                           OleId;
    ULONG                           NumberOfStreamReferences;
    ULONG                           StreamIndex;
    ULONG                           SecurityId;
    BOOLEAN                         ContentIndexDisable;
    BOOLEAN                         InheritContentIndexDisable;
    FILE_NAME_INFORMATION           NameInformation;
} FILE_OLE_ALL_INFORMATION, *PFILE_OLE_ALL_INFORMATION;

typedef struct _FILE_OLE_DIR_INFORMATION {
    ULONG               NextEntryOffset;
    ULONG               FileIndex;
    LARGE_INTEGER       CreationTime;
    LARGE_INTEGER       LastAccessTime;
    LARGE_INTEGER       LastWriteTime;
    LARGE_INTEGER       ChangeTime;
    LARGE_INTEGER       EndOfFile;
    LARGE_INTEGER       AllocationSize;
    ULONG               FileAttributes;
    ULONG               FileNameLength;
    FILE_STORAGE_TYPE   StorageType;
    GUID                OleClassId;
    ULONG               OleStateBits;
    BOOLEAN             ContentIndexDisable;
    BOOLEAN             InheritContentIndexDisable;
    WCHAR               FileName[1];
} FILE_OLE_DIR_INFORMATION, *PFILE_OLE_DIR_INFORMATION;

typedef struct _FILE_OLE_INFORMATION {
    LARGE_INTEGER                   SecurityChangeTime;
    FILE_OLE_CLASSID_INFORMATION    OleClassIdInformation;
    FILE_OBJECTID_INFORMATION       ObjectIdInformation;
    FILE_STORAGE_TYPE               StorageType;
    ULONG                           OleStateBits;
    BOOLEAN                         ContentIndexDisable;
    BOOLEAN                         InheritContentIndexDisable;
} FILE_OLE_INFORMATION, *PFILE_OLE_INFORMATION;

typedef struct _FILE_OLE_STATE_BITS_INFORMATION {
    ULONG StateBits;
    ULONG StateBitsMask;
} FILE_OLE_STATE_BITS_INFORMATION, *PFILE_OLE_STATE_BITS_INFORMATION;

typedef struct _MAPPING_PAIR {
    ULONGLONG Vcn;
    ULONGLONG Lcn;
} MAPPING_PAIR, *PMAPPING_PAIR;

typedef struct _GET_RETRIEVAL_DESCRIPTOR {
    ULONG           NumberOfPairs;
    ULONGLONG       StartVcn;
    MAPPING_PAIR    Pair[1];
} GET_RETRIEVAL_DESCRIPTOR, *PGET_RETRIEVAL_DESCRIPTOR;

typedef struct _MBCB {
    CSHORT          NodeTypeCode;
    CSHORT          NodeIsInZone;
    ULONG           PagesToWrite;
    ULONG           DirtyPages;
    ULONG           Reserved;
    LIST_ENTRY      BitmapRanges;
    LONGLONG        ResumeWritePage;
    BITMAP_RANGE    BitmapRange1;
    BITMAP_RANGE    BitmapRange2;
    BITMAP_RANGE    BitmapRange3;
} MBCB, *PMBCB;

typedef struct _MOVEFILE_DESCRIPTOR {
     HANDLE         FileHandle;
     ULONG          Reserved;
     LARGE_INTEGER  StartVcn;
     LARGE_INTEGER  TargetLcn;
     ULONG          NumVcns;
     ULONG          Reserved1;
} MOVEFILE_DESCRIPTOR, *PMOVEFILE_DESCRIPTOR;

typedef struct _OBJECT_BASIC_INFO {
    ULONG           Attributes;
    ACCESS_MASK     GrantedAccess;
    ULONG           HandleCount;
    ULONG           ReferenceCount;
    ULONG           PagedPoolUsage;
    ULONG           NonPagedPoolUsage;
    ULONG           Reserved[3];
    ULONG           NameInformationLength;
    ULONG           TypeInformationLength;
    ULONG           SecurityDescriptorLength;
    LARGE_INTEGER   CreateTime;
} OBJECT_BASIC_INFO, *POBJECT_BASIC_INFO;

typedef struct _OBJECT_HANDLE_ATTRIBUTE_INFO {
    BOOLEAN Inherit;
    BOOLEAN ProtectFromClose;
} OBJECT_HANDLE_ATTRIBUTE_INFO, *POBJECT_HANDLE_ATTRIBUTE_INFO;

typedef struct _OBJECT_NAME_INFO {
    UNICODE_STRING  ObjectName;
    WCHAR           ObjectNameBuffer[1];
} OBJECT_NAME_INFO, *POBJECT_NAME_INFO;

typedef struct _OBJECT_PROTECTION_INFO {
    BOOLEAN Inherit;
    BOOLEAN ProtectHandle;
} OBJECT_PROTECTION_INFO, *POBJECT_PROTECTION_INFO;

typedef struct _OBJECT_TYPE_INFO {
    UNICODE_STRING  ObjectTypeName;
    UCHAR           Unknown[0x58];
    WCHAR           ObjectTypeNameBuffer[1];
} OBJECT_TYPE_INFO, *POBJECT_TYPE_INFO;

typedef struct _OBJECT_ALL_TYPES_INFO {
    ULONG               NumberOfObjectTypes;
    OBJECT_TYPE_INFO    ObjectsTypeInfo[1];
} OBJECT_ALL_TYPES_INFO, *POBJECT_ALL_TYPES_INFO;

#if defined(USE_LPC6432)
#define LPC_CLIENT_ID CLIENT_ID64
#define LPC_SIZE_T ULONGLONG
#define LPC_PVOID ULONGLONG
#define LPC_HANDLE ULONGLONG
#else
#define LPC_CLIENT_ID CLIENT_ID
#define LPC_SIZE_T SIZE_T
#define LPC_PVOID PVOID
#define LPC_HANDLE HANDLE
#endif

typedef struct _PORT_MESSAGE
{
    union
    {
        struct
        {
            CSHORT DataLength;
            CSHORT TotalLength;
        } s1;
        ULONG Length;
    } u1;
    union
    {
        struct
        {
            CSHORT Type;
            CSHORT DataInfoOffset;
        } s2;
        ULONG ZeroInit;
    } u2;
    __GNU_EXTENSION union
    {
        LPC_CLIENT_ID ClientId;
        double DoNotUseThisField;
    };
    ULONG MessageId;
    __GNU_EXTENSION union
    {
        LPC_SIZE_T ClientViewSize;
        ULONG CallbackId;
    };
} PORT_MESSAGE, *PPORT_MESSAGE;

#define LPC_KERNELMODE_MESSAGE      (CSHORT)((USHORT)0x8000)

typedef struct _PORT_VIEW
{
    ULONG Length;
    LPC_HANDLE SectionHandle;
    ULONG SectionOffset;
    LPC_SIZE_T ViewSize;
    LPC_PVOID ViewBase;
    LPC_PVOID ViewRemoteBase;
} PORT_VIEW, *PPORT_VIEW;

typedef struct _REMOTE_PORT_VIEW
{
    ULONG Length;
    LPC_SIZE_T ViewSize;
    LPC_PVOID ViewBase;
} REMOTE_PORT_VIEW, *PREMOTE_PORT_VIEW;

typedef struct _VAD_HEADER {
    PVOID       StartVPN;
    PVOID       EndVPN;
    struct _VAD_HEADER* ParentLink;
    struct _VAD_HEADER* LeftLink;
    struct _VAD_HEADER* RightLink;
    ULONG       Flags;          /* LSB = CommitCharge */
    PVOID       ControlArea;
    PVOID       FirstProtoPte;
    PVOID       LastPTE;
    ULONG       Unknown;
    LIST_ENTRY  Secured;
} VAD_HEADER, *PVAD_HEADER;

NTKERNELAPI
LARGE_INTEGER
NTAPI
CcGetLsnForFileObject (
    IN PFILE_OBJECT     FileObject,
    OUT PLARGE_INTEGER  OldestLsn OPTIONAL
);

NTKERNELAPI
PVOID
NTAPI
FsRtlAllocatePool (
    IN POOL_TYPE    PoolType,
    IN ULONG        NumberOfBytes
);

NTKERNELAPI
PVOID
NTAPI
FsRtlAllocatePoolWithQuota (
    IN POOL_TYPE    PoolType,
    IN ULONG        NumberOfBytes
);

NTKERNELAPI
PVOID
NTAPI
FsRtlAllocatePoolWithQuotaTag (
    IN POOL_TYPE    PoolType,
    IN ULONG        NumberOfBytes,
    IN ULONG        Tag
);

NTKERNELAPI
PVOID
NTAPI
FsRtlAllocatePoolWithTag (
    IN POOL_TYPE    PoolType,
    IN ULONG        NumberOfBytes,
    IN ULONG        Tag
);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlIsFatDbcsLegal (
    IN ANSI_STRING  DbcsName,
    IN BOOLEAN      WildCardsPermissible,
    IN BOOLEAN      PathNamePermissible,
    IN BOOLEAN      LeadingBackslashPermissible
);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlMdlReadComplete (
    IN PFILE_OBJECT     FileObject,
    IN PMDL             MdlChain
);

NTKERNELAPI
BOOLEAN
NTAPI
FsRtlMdlWriteComplete (
    IN PFILE_OBJECT     FileObject,
    IN PLARGE_INTEGER   FileOffset,
    IN PMDL             MdlChain
);

NTKERNELAPI
VOID
NTAPI
FsRtlNotifyChangeDirectory (
    IN PNOTIFY_SYNC NotifySync,
    IN PVOID        FsContext,
    IN PSTRING      FullDirectoryName,
    IN PLIST_ENTRY  NotifyList,
    IN BOOLEAN      WatchTree,
    IN ULONG        CompletionFilter,
    IN PIRP         NotifyIrp
);

NTKERNELAPI
NTSTATUS
NTAPI
ObCreateObject (
    IN KPROCESSOR_MODE      ObjectAttributesAccessMode OPTIONAL,
    IN POBJECT_TYPE         ObjectType,
    IN POBJECT_ATTRIBUTES   ObjectAttributes OPTIONAL,
    IN KPROCESSOR_MODE      AccessMode,
    IN OUT PVOID            ParseContext OPTIONAL,
    IN ULONG                ObjectSize,
    IN ULONG                PagedPoolCharge OPTIONAL,
    IN ULONG                NonPagedPoolCharge OPTIONAL,
    OUT PVOID               *Object
);

NTKERNELAPI
ULONG
NTAPI
ObGetObjectPointerCount (
    IN PVOID Object
);

NTKERNELAPI
NTSTATUS
NTAPI
ObReferenceObjectByName (
    IN PUNICODE_STRING  ObjectName,
    IN ULONG            Attributes,
    IN PACCESS_STATE    PassedAccessState OPTIONAL,
    IN ACCESS_MASK      DesiredAccess OPTIONAL,
    IN POBJECT_TYPE     ObjectType,
    IN KPROCESSOR_MODE  AccessMode,
    IN OUT PVOID        ParseContext OPTIONAL,
    OUT PVOID           *Object
);

#define PsDereferenceImpersonationToken(T)  \
            {if (ARGUMENT_PRESENT(T)) {     \
                (ObDereferenceObject((T))); \
            } else {                        \
                ;                           \
            }                               \
}

NTKERNELAPI
NTSTATUS
NTAPI
PsLookupProcessThreadByCid (
    IN PCLIENT_ID   Cid,
    OUT PEPROCESS   *Process OPTIONAL,
    OUT PETHREAD    *Thread
);

NTSYSAPI
NTSTATUS
NTAPI
RtlSetSaclSecurityDescriptor (
    IN OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
    IN BOOLEAN                  SaclPresent,
    IN PACL                     Sacl,
    IN BOOLEAN                  SaclDefaulted
);

#define SeEnableAccessToExports() SeExports = *(PSE_EXPORTS *)SeExports;

#if (VER_PRODUCTBUILD >= 2195)

NTSYSAPI
NTSTATUS
NTAPI
ZwAdjustPrivilegesToken (
    IN HANDLE               TokenHandle,
    IN BOOLEAN              DisableAllPrivileges,
    IN PTOKEN_PRIVILEGES    NewState,
    IN ULONG                BufferLength,
    OUT PTOKEN_PRIVILEGES   PreviousState OPTIONAL,
    OUT PULONG              ReturnLength
);

#endif /* (VER_PRODUCTBUILD >= 2195) */

NTSYSAPI
NTSTATUS
NTAPI
ZwAlertThread (
    IN HANDLE ThreadHandle
);

NTSYSAPI
NTSTATUS
NTAPI
ZwAccessCheckAndAuditAlarm (
    IN PUNICODE_STRING      SubsystemName,
    IN PVOID                HandleId,
    IN PUNICODE_STRING      ObjectTypeName,
    IN PUNICODE_STRING      ObjectName,
    IN PSECURITY_DESCRIPTOR SecurityDescriptor,
    IN ACCESS_MASK          DesiredAccess,
    IN PGENERIC_MAPPING     GenericMapping,
    IN BOOLEAN              ObjectCreation,
    OUT PACCESS_MASK        GrantedAccess,
    OUT PBOOLEAN            AccessStatus,
    OUT PBOOLEAN            GenerateOnClose
);

#if (VER_PRODUCTBUILD >= 2195)

NTSYSAPI
NTSTATUS
NTAPI
ZwCancelIoFile (
    IN HANDLE               FileHandle,
    OUT PIO_STATUS_BLOCK    IoStatusBlock
);

#endif /* (VER_PRODUCTBUILD >= 2195) */

NTSYSAPI
NTSTATUS
NTAPI
ZwClearEvent (
    IN HANDLE EventHandle
);

NTSYSAPI
NTSTATUS
NTAPI
ZwCloseObjectAuditAlarm (
    IN PUNICODE_STRING  SubsystemName,
    IN PVOID            HandleId,
    IN BOOLEAN          GenerateOnClose
);

NTSYSAPI
NTSTATUS
NTAPI
ZwCreateSymbolicLinkObject (
    OUT PHANDLE             SymbolicLinkHandle,
    IN ACCESS_MASK          DesiredAccess,
    IN POBJECT_ATTRIBUTES   ObjectAttributes,
    IN PUNICODE_STRING      TargetName
);

NTSYSAPI
NTSTATUS
NTAPI
ZwFlushInstructionCache (
    IN HANDLE   ProcessHandle,
    IN PVOID    BaseAddress OPTIONAL,
    IN ULONG    FlushSize
);

NTSYSAPI
NTSTATUS
NTAPI
ZwFlushBuffersFile(
    IN HANDLE FileHandle,
    OUT PIO_STATUS_BLOCK IoStatusBlock
);

#if (VER_PRODUCTBUILD >= 2195)

NTSYSAPI
NTSTATUS
NTAPI
ZwInitiatePowerAction (
    IN POWER_ACTION         SystemAction,
    IN SYSTEM_POWER_STATE   MinSystemState,
    IN ULONG                Flags,
    IN BOOLEAN              Asynchronous
);

#endif /* (VER_PRODUCTBUILD >= 2195) */

NTSYSAPI
NTSTATUS
NTAPI
ZwLoadKey (
    IN POBJECT_ATTRIBUTES KeyObjectAttributes,
    IN POBJECT_ATTRIBUTES FileObjectAttributes
);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenProcessToken (
    IN HANDLE       ProcessHandle,
    IN ACCESS_MASK  DesiredAccess,
    OUT PHANDLE     TokenHandle
);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenThread (
    OUT PHANDLE             ThreadHandle,
    IN ACCESS_MASK          DesiredAccess,
    IN POBJECT_ATTRIBUTES   ObjectAttributes,
    IN PCLIENT_ID           ClientId
);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenThreadToken (
    IN HANDLE       ThreadHandle,
    IN ACCESS_MASK  DesiredAccess,
    IN BOOLEAN      OpenAsSelf,
    OUT PHANDLE     TokenHandle
);

NTSYSAPI
NTSTATUS
NTAPI
ZwPulseEvent (
    IN HANDLE   EventHandle,
    OUT PLONG   PreviousState OPTIONAL
);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryDefaultLocale (
    IN BOOLEAN  ThreadOrSystem,
    OUT PLCID   Locale
);

#if (VER_PRODUCTBUILD >= 2195)

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryDirectoryObject (
    IN HANDLE       DirectoryHandle,
    OUT PVOID       Buffer,
    IN ULONG        Length,
    IN BOOLEAN      ReturnSingleEntry,
    IN BOOLEAN      RestartScan,
    IN OUT PULONG   Context,
    OUT PULONG      ReturnLength OPTIONAL
);

#endif /* (VER_PRODUCTBUILD >= 2195) */

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryInformationProcess (
    IN HANDLE           ProcessHandle,
    IN PROCESSINFOCLASS ProcessInformationClass,
    OUT PVOID           ProcessInformation,
    IN ULONG            ProcessInformationLength,
    OUT PULONG          ReturnLength OPTIONAL
);

NTSYSAPI
NTSTATUS
NTAPI
ZwReplaceKey (
    IN POBJECT_ATTRIBUTES   NewFileObjectAttributes,
    IN HANDLE               KeyHandle,
    IN POBJECT_ATTRIBUTES   OldFileObjectAttributes
);

NTSYSAPI
NTSTATUS
NTAPI
ZwResetEvent (
    IN HANDLE   EventHandle,
    OUT PLONG   PreviousState OPTIONAL
);

#if (VER_PRODUCTBUILD >= 2195)

NTSYSAPI
NTSTATUS
NTAPI
ZwRestoreKey (
    IN HANDLE   KeyHandle,
    IN HANDLE   FileHandle,
    IN ULONG    Flags
);

#endif /* (VER_PRODUCTBUILD >= 2195) */

NTSYSAPI
NTSTATUS
NTAPI
ZwSaveKey (
    IN HANDLE KeyHandle,
    IN HANDLE FileHandle
);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetDefaultLocale (
    IN BOOLEAN  ThreadOrSystem,
    IN LCID     Locale
);

#if (VER_PRODUCTBUILD >= 2195)

NTSYSAPI
NTSTATUS
NTAPI
ZwSetDefaultUILanguage (
    IN LANGID LanguageId
);

#endif /* (VER_PRODUCTBUILD >= 2195) */

NTSYSAPI
NTSTATUS
NTAPI
ZwSetInformationProcess (
    IN HANDLE           ProcessHandle,
    IN PROCESSINFOCLASS ProcessInformationClass,
    IN PVOID            ProcessInformation,
    IN ULONG            ProcessInformationLength
);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetSystemTime (
    IN PLARGE_INTEGER   NewTime,
    OUT PLARGE_INTEGER  OldTime OPTIONAL
);

NTSYSAPI
NTSTATUS
NTAPI
ZwUnloadKey (
    IN POBJECT_ATTRIBUTES KeyObjectAttributes
);

NTSYSAPI
NTSTATUS
NTAPI
ZwWaitForMultipleObjects (
    IN ULONG            HandleCount,
    IN PHANDLE          Handles,
    IN WAIT_TYPE        WaitType,
    IN BOOLEAN          Alertable,
    IN PLARGE_INTEGER   Timeout OPTIONAL
);

NTSYSAPI
NTSTATUS
NTAPI
ZwYieldExecution (
    VOID
);

#pragma pack(pop)

#ifdef __cplusplus
}
#endif
