/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _NTSECPKG_
#define _NTSECPKG_

#ifdef __cplusplus
extern "C" {
#endif

  typedef PVOID *PLSA_CLIENT_REQUEST;

  typedef enum _LSA_TOKEN_INFORMATION_TYPE {
    LsaTokenInformationNull,
    LsaTokenInformationV1,
    LsaTokenInformationV2
  } LSA_TOKEN_INFORMATION_TYPE,*PLSA_TOKEN_INFORMATION_TYPE;

  typedef struct _LSA_TOKEN_INFORMATION_NULL {
    LARGE_INTEGER ExpirationTime;
    PTOKEN_GROUPS Groups;
  } LSA_TOKEN_INFORMATION_NULL,*PLSA_TOKEN_INFORMATION_NULL;

  typedef struct _LSA_TOKEN_INFORMATION_V1 {
    LARGE_INTEGER ExpirationTime;
    TOKEN_USER User;
    PTOKEN_GROUPS Groups;
    TOKEN_PRIMARY_GROUP PrimaryGroup;
    PTOKEN_PRIVILEGES Privileges;
    TOKEN_OWNER Owner;
    TOKEN_DEFAULT_DACL DefaultDacl;
  } LSA_TOKEN_INFORMATION_V1,*PLSA_TOKEN_INFORMATION_V1;

  typedef LSA_TOKEN_INFORMATION_V1 LSA_TOKEN_INFORMATION_V2,*PLSA_TOKEN_INFORMATION_V2;
  typedef NTSTATUS (NTAPI LSA_CREATE_LOGON_SESSION)(PLUID LogonId);
  typedef NTSTATUS (NTAPI LSA_DELETE_LOGON_SESSION)(PLUID LogonId);
  typedef NTSTATUS (NTAPI LSA_ADD_CREDENTIAL)(PLUID LogonId,ULONG AuthenticationPackage,PLSA_STRING PrimaryKeyValue,PLSA_STRING Credentials);
  typedef NTSTATUS (NTAPI LSA_GET_CREDENTIALS)(PLUID LogonId,ULONG AuthenticationPackage,PULONG QueryContext,BOOLEAN RetrieveAllCredentials,PLSA_STRING PrimaryKeyValue,PULONG PrimaryKeyLength,PLSA_STRING Credentials);
  typedef NTSTATUS (NTAPI LSA_DELETE_CREDENTIAL)(PLUID LogonId,ULONG AuthenticationPackage,PLSA_STRING PrimaryKeyValue);
  typedef PVOID (NTAPI LSA_ALLOCATE_LSA_HEAP)(ULONG Length);
  typedef VOID (NTAPI LSA_FREE_LSA_HEAP)(PVOID Base);
  typedef PVOID (NTAPI LSA_ALLOCATE_PRIVATE_HEAP)(SIZE_T Length);
  typedef VOID (NTAPI LSA_FREE_PRIVATE_HEAP)(PVOID Base);
  typedef NTSTATUS (NTAPI LSA_ALLOCATE_CLIENT_BUFFER)(PLSA_CLIENT_REQUEST ClientRequest,ULONG LengthRequired,PVOID *ClientBaseAddress);
  typedef NTSTATUS (NTAPI LSA_FREE_CLIENT_BUFFER)(PLSA_CLIENT_REQUEST ClientRequest,PVOID ClientBaseAddress);
  typedef NTSTATUS (NTAPI LSA_COPY_TO_CLIENT_BUFFER)(PLSA_CLIENT_REQUEST ClientRequest,ULONG Length,PVOID ClientBaseAddress,PVOID BufferToCopy);
  typedef NTSTATUS (NTAPI LSA_COPY_FROM_CLIENT_BUFFER)(PLSA_CLIENT_REQUEST ClientRequest,ULONG Length,PVOID BufferToCopy,PVOID ClientBaseAddress);

  typedef LSA_CREATE_LOGON_SESSION *PLSA_CREATE_LOGON_SESSION;
  typedef LSA_DELETE_LOGON_SESSION *PLSA_DELETE_LOGON_SESSION;
  typedef LSA_ADD_CREDENTIAL *PLSA_ADD_CREDENTIAL;
  typedef LSA_GET_CREDENTIALS *PLSA_GET_CREDENTIALS;
  typedef LSA_DELETE_CREDENTIAL *PLSA_DELETE_CREDENTIAL;
  typedef LSA_ALLOCATE_LSA_HEAP *PLSA_ALLOCATE_LSA_HEAP;
  typedef LSA_FREE_LSA_HEAP *PLSA_FREE_LSA_HEAP;
  typedef LSA_ALLOCATE_PRIVATE_HEAP *PLSA_ALLOCATE_PRIVATE_HEAP;
  typedef LSA_FREE_PRIVATE_HEAP *PLSA_FREE_PRIVATE_HEAP;
  typedef LSA_ALLOCATE_CLIENT_BUFFER *PLSA_ALLOCATE_CLIENT_BUFFER;
  typedef LSA_FREE_CLIENT_BUFFER *PLSA_FREE_CLIENT_BUFFER;
  typedef LSA_COPY_TO_CLIENT_BUFFER *PLSA_COPY_TO_CLIENT_BUFFER;
  typedef LSA_COPY_FROM_CLIENT_BUFFER *PLSA_COPY_FROM_CLIENT_BUFFER;

  typedef struct _LSA_DISPATCH_TABLE {
    PLSA_CREATE_LOGON_SESSION CreateLogonSession;
    PLSA_DELETE_LOGON_SESSION DeleteLogonSession;
    PLSA_ADD_CREDENTIAL AddCredential;
    PLSA_GET_CREDENTIALS GetCredentials;
    PLSA_DELETE_CREDENTIAL DeleteCredential;
    PLSA_ALLOCATE_LSA_HEAP AllocateLsaHeap;
    PLSA_FREE_LSA_HEAP FreeLsaHeap;
    PLSA_ALLOCATE_CLIENT_BUFFER AllocateClientBuffer;
    PLSA_FREE_CLIENT_BUFFER FreeClientBuffer;
    PLSA_COPY_TO_CLIENT_BUFFER CopyToClientBuffer;
    PLSA_COPY_FROM_CLIENT_BUFFER CopyFromClientBuffer;
  } LSA_DISPATCH_TABLE,*PLSA_DISPATCH_TABLE;

#define LSA_AP_NAME_INITIALIZE_PACKAGE "LsaApInitializePackage\0"
#define LSA_AP_NAME_LOGON_USER "LsaApLogonUser\0"
#define LSA_AP_NAME_LOGON_USER_EX "LsaApLogonUserEx\0"
#define LSA_AP_NAME_CALL_PACKAGE "LsaApCallPackage\0"
#define LSA_AP_NAME_LOGON_TERMINATED "LsaApLogonTerminated\0"
#define LSA_AP_NAME_CALL_PACKAGE_UNTRUSTED "LsaApCallPackageUntrusted\0"
#define LSA_AP_NAME_CALL_PACKAGE_PASSTHROUGH "LsaApCallPackagePassthrough\0"

  typedef NTSTATUS (NTAPI LSA_AP_INITIALIZE_PACKAGE)(ULONG AuthenticationPackageId,PLSA_DISPATCH_TABLE LsaDispatchTable,PLSA_STRING Database,PLSA_STRING Confidentiality,PLSA_STRING *AuthenticationPackageName);
  typedef NTSTATUS (NTAPI LSA_AP_LOGON_USER)(PLSA_CLIENT_REQUEST ClientRequest,SECURITY_LOGON_TYPE LogonType,PVOID AuthenticationInformation,PVOID ClientAuthenticationBase,ULONG AuthenticationInformationLength,PVOID *ProfileBuffer,PULONG ProfileBufferLength,PLUID LogonId,PNTSTATUS SubStatus,PLSA_TOKEN_INFORMATION_TYPE TokenInformationType,PVOID *TokenInformation,PLSA_UNICODE_STRING *AccountName,PLSA_UNICODE_STRING *AuthenticatingAuthority);
  typedef NTSTATUS (NTAPI LSA_AP_LOGON_USER_EX)(PLSA_CLIENT_REQUEST ClientRequest,SECURITY_LOGON_TYPE LogonType,PVOID AuthenticationInformation,PVOID ClientAuthenticationBase,ULONG AuthenticationInformationLength,PVOID *ProfileBuffer,PULONG ProfileBufferLength,PLUID LogonId,PNTSTATUS SubStatus,PLSA_TOKEN_INFORMATION_TYPE TokenInformationType,PVOID *TokenInformation,PUNICODE_STRING *AccountName,PUNICODE_STRING *AuthenticatingAuthority,PUNICODE_STRING *MachineName);
  typedef NTSTATUS (NTAPI LSA_AP_CALL_PACKAGE)(PLSA_CLIENT_REQUEST ClientRequest,PVOID ProtocolSubmitBuffer,PVOID ClientBufferBase,ULONG SubmitBufferLength,PVOID *ProtocolReturnBuffer,PULONG ReturnBufferLength,PNTSTATUS ProtocolStatus);
  typedef NTSTATUS (NTAPI LSA_AP_CALL_PACKAGE_PASSTHROUGH)(PLSA_CLIENT_REQUEST ClientRequest,PVOID ProtocolSubmitBuffer,PVOID ClientBufferBase,ULONG SubmitBufferLength,PVOID *ProtocolReturnBuffer,PULONG ReturnBufferLength,PNTSTATUS ProtocolStatus);
  typedef VOID (NTAPI LSA_AP_LOGON_TERMINATED)(PLUID LogonId);

  typedef LSA_AP_CALL_PACKAGE LSA_AP_CALL_PACKAGE_UNTRUSTED;
  typedef LSA_AP_INITIALIZE_PACKAGE *PLSA_AP_INITIALIZE_PACKAGE;
  typedef LSA_AP_LOGON_USER *PLSA_AP_LOGON_USER;
  typedef LSA_AP_LOGON_USER_EX *PLSA_AP_LOGON_USER_EX;
  typedef LSA_AP_CALL_PACKAGE *PLSA_AP_CALL_PACKAGE;
  typedef LSA_AP_CALL_PACKAGE_PASSTHROUGH *PLSA_AP_CALL_PACKAGE_PASSTHROUGH;
  typedef LSA_AP_LOGON_TERMINATED *PLSA_AP_LOGON_TERMINATED;
  typedef LSA_AP_CALL_PACKAGE_UNTRUSTED *PLSA_AP_CALL_PACKAGE_UNTRUSTED;

#ifndef _SAM_CREDENTIAL_UPDATE_DEFINED
#define _SAM_CREDENTIAL_UPDATE_DEFINED

  typedef NTSTATUS (*PSAM_CREDENTIAL_UPDATE_NOTIFY_ROUTINE)(PUNICODE_STRING ClearPassword,PVOID OldCredentials,ULONG OldCredentialSize,ULONG UserAccountControl,PUNICODE_STRING UPN,PUNICODE_STRING UserName,PUNICODE_STRING NetbiosDomainName,PUNICODE_STRING DnsDomainName,PVOID *NewCredentials,ULONG *NewCredentialSize);

#define SAM_CREDENTIAL_UPDATE_NOTIFY_ROUTINE "CredentialUpdateNotify"

  typedef BOOLEAN (*PSAM_CREDENTIAL_UPDATE_REGISTER_ROUTINE)(PUNICODE_STRING CredentialName);

#define SAM_CREDENTIAL_UPDATE_REGISTER_ROUTINE "CredentialUpdateRegister"

  typedef VOID (*PSAM_CREDENTIAL_UPDATE_FREE_ROUTINE)(PVOID p);

#define SAM_CREDENTIAL_UPDATE_FREE_ROUTINE "CredentialUpdateFree"
#endif

#ifdef SECURITY_KERNEL

  typedef PVOID SEC_THREAD_START;
  typedef PVOID SEC_ATTRS;
#else
  typedef LPTHREAD_START_ROUTINE SEC_THREAD_START;
  typedef LPSECURITY_ATTRIBUTES SEC_ATTRS;
#endif

#define SecEqualLuid(L1,L2) ((((PLUID)L1)->LowPart==((PLUID)L2)->LowPart) && (((PLUID)L1)->HighPart==((PLUID)L2)->HighPart))
#define SecIsZeroLuid(L1) ((L1->LowPart | L1->HighPart)==0)

  typedef struct _SECPKG_CLIENT_INFO {
    LUID LogonId;
    ULONG ProcessID;
    ULONG ThreadID;
    BOOLEAN HasTcbPrivilege;
    BOOLEAN Impersonating;
    BOOLEAN Restricted;

    UCHAR ClientFlags;
    SECURITY_IMPERSONATION_LEVEL ImpersonationLevel;

  } SECPKG_CLIENT_INFO,*PSECPKG_CLIENT_INFO;

#define SECPKG_CLIENT_PROCESS_TERMINATED 0x01
#define SECPKG_CLIENT_THREAD_TERMINATED 0x02

  typedef struct _SECPKG_CALL_INFO {
    ULONG ProcessId;
    ULONG ThreadId;
    ULONG Attributes;
    ULONG CallCount;
  } SECPKG_CALL_INFO,*PSECPKG_CALL_INFO;

#define SECPKG_CALL_KERNEL_MODE 0x00000001
#define SECPKG_CALL_ANSI 0x00000002
#define SECPKG_CALL_URGENT 0x00000004
#define SECPKG_CALL_RECURSIVE 0x00000008
#define SECPKG_CALL_IN_PROC 0x00000010
#define SECPKG_CALL_CLEANUP 0x00000020
#define SECPKG_CALL_WOWCLIENT 0x00000040
#define SECPKG_CALL_THREAD_TERM 0x00000080
#define SECPKG_CALL_PROCESS_TERM 0x00000100
#define SECPKG_CALL_IS_TCB 0x00000200

  typedef struct _SECPKG_SUPPLEMENTAL_CRED {
    UNICODE_STRING PackageName;
    ULONG CredentialSize;
    PUCHAR Credentials;
  } SECPKG_SUPPLEMENTAL_CRED,*PSECPKG_SUPPLEMENTAL_CRED;

  typedef ULONG_PTR LSA_SEC_HANDLE;
  typedef LSA_SEC_HANDLE *PLSA_SEC_HANDLE;
  typedef struct _SECPKG_SUPPLEMENTAL_CRED_ARRAY {
    ULONG CredentialCount;
    SECPKG_SUPPLEMENTAL_CRED Credentials[1];
  } SECPKG_SUPPLEMENTAL_CRED_ARRAY,*PSECPKG_SUPPLEMENTAL_CRED_ARRAY;

#define SECBUFFER_UNMAPPED 0x40000000

#define SECBUFFER_KERNEL_MAP 0x20000000

  typedef NTSTATUS (NTAPI LSA_CALLBACK_FUNCTION)(ULONG_PTR Argument1,ULONG_PTR Argument2,PSecBuffer InputBuffer,PSecBuffer OutputBuffer);

  typedef LSA_CALLBACK_FUNCTION *PLSA_CALLBACK_FUNCTION;

#define PRIMARY_CRED_CLEAR_PASSWORD 0x1
#define PRIMARY_CRED_OWF_PASSWORD 0x2
#define PRIMARY_CRED_UPDATE 0x4
#define PRIMARY_CRED_CACHED_LOGON 0x8
#define PRIMARY_CRED_LOGON_NO_TCB 0x10

#define PRIMARY_CRED_LOGON_PACKAGE_SHIFT 24
#define PRIMARY_CRED_PACKAGE_MASK 0xff000000

  typedef struct _SECPKG_PRIMARY_CRED {
    LUID LogonId;
    UNICODE_STRING DownlevelName;
    UNICODE_STRING DomainName;
    UNICODE_STRING Password;
    UNICODE_STRING OldPassword;
    PSID UserSid;
    ULONG Flags;
    UNICODE_STRING DnsDomainName;
    UNICODE_STRING Upn;
    UNICODE_STRING LogonServer;
    UNICODE_STRING Spare1;
    UNICODE_STRING Spare2;
    UNICODE_STRING Spare3;
    UNICODE_STRING Spare4;
  } SECPKG_PRIMARY_CRED,*PSECPKG_PRIMARY_CRED;

#define MAX_CRED_SIZE 1024

#define SECPKG_STATE_ENCRYPTION_PERMITTED 0x01
#define SECPKG_STATE_STRONG_ENCRYPTION_PERMITTED 0x02
#define SECPKG_STATE_DOMAIN_CONTROLLER 0x04
#define SECPKG_STATE_WORKSTATION 0x08
#define SECPKG_STATE_STANDALONE 0x10

  typedef struct _SECPKG_PARAMETERS {
    ULONG Version;
    ULONG MachineState;
    ULONG SetupMode;
    PSID DomainSid;
    UNICODE_STRING DomainName;
    UNICODE_STRING DnsDomainName;
    GUID DomainGuid;
  } SECPKG_PARAMETERS,*PSECPKG_PARAMETERS;

  typedef enum _SECPKG_EXTENDED_INFORMATION_CLASS {
    SecpkgGssInfo = 1,
    SecpkgContextThunks,
    SecpkgMutualAuthLevel,
    SecpkgWowClientDll,
    SecpkgExtraOids,
    SecpkgMaxInfo
  } SECPKG_EXTENDED_INFORMATION_CLASS;

  typedef struct _SECPKG_GSS_INFO {
    ULONG EncodedIdLength;
    UCHAR EncodedId[4];
  } SECPKG_GSS_INFO,*PSECPKG_GSS_INFO;

  typedef struct _SECPKG_CONTEXT_THUNKS {
    ULONG InfoLevelCount;
    ULONG Levels[1];
  } SECPKG_CONTEXT_THUNKS,*PSECPKG_CONTEXT_THUNKS;

  typedef struct _SECPKG_MUTUAL_AUTH_LEVEL {
    ULONG MutualAuthLevel;
  } SECPKG_MUTUAL_AUTH_LEVEL,*PSECPKG_MUTUAL_AUTH_LEVEL;

  typedef struct _SECPKG_WOW_CLIENT_DLL {
    SECURITY_STRING WowClientDllPath;
  } SECPKG_WOW_CLIENT_DLL,*PSECPKG_WOW_CLIENT_DLL;

#define SECPKG_MAX_OID_LENGTH 32

  typedef struct _SECPKG_SERIALIZED_OID {
    ULONG OidLength;
    ULONG OidAttributes;
    UCHAR OidValue[SECPKG_MAX_OID_LENGTH ];
  } SECPKG_SERIALIZED_OID,*PSECPKG_SERIALIZED_OID;

  typedef struct _SECPKG_EXTRA_OIDS {
    ULONG OidCount;
    SECPKG_SERIALIZED_OID Oids[1 ];
  } SECPKG_EXTRA_OIDS,*PSECPKG_EXTRA_OIDS;

  typedef struct _SECPKG_EXTENDED_INFORMATION {
    SECPKG_EXTENDED_INFORMATION_CLASS Class;
    union {
      SECPKG_GSS_INFO GssInfo;
      SECPKG_CONTEXT_THUNKS ContextThunks;
      SECPKG_MUTUAL_AUTH_LEVEL MutualAuthLevel;
      SECPKG_WOW_CLIENT_DLL WowClientDll;
      SECPKG_EXTRA_OIDS ExtraOids;
    } Info;
  } SECPKG_EXTENDED_INFORMATION,*PSECPKG_EXTENDED_INFORMATION;

#define SECPKG_ATTR_SASL_CONTEXT 0x00010000

  typedef struct _SecPkgContext_SaslContext {
    PVOID SaslContext;
  } SecPkgContext_SaslContext,*PSecPkgContext_SaslContext;

#define SECPKG_ATTR_THUNK_ALL 0x00010000

#ifndef SECURITY_USER_DATA_DEFINED
#define SECURITY_USER_DATA_DEFINED

  typedef struct _SECURITY_USER_DATA {
    SECURITY_STRING UserName;
    SECURITY_STRING LogonDomainName;
    SECURITY_STRING LogonServer;
    PSID pSid;
  } SECURITY_USER_DATA,*PSECURITY_USER_DATA;

  typedef SECURITY_USER_DATA SecurityUserData,*PSecurityUserData;

#define UNDERSTANDS_LONG_NAMES 1
#define NO_LONG_NAMES 2
#endif

  typedef NTSTATUS (NTAPI LSA_IMPERSONATE_CLIENT)(VOID);
  typedef NTSTATUS (NTAPI LSA_UNLOAD_PACKAGE)(VOID);
  typedef NTSTATUS (NTAPI LSA_DUPLICATE_HANDLE)(HANDLE SourceHandle,PHANDLE DestionationHandle);
  typedef NTSTATUS (NTAPI LSA_SAVE_SUPPLEMENTAL_CREDENTIALS)(PLUID LogonId,ULONG SupplementalCredSize,PVOID SupplementalCreds,BOOLEAN Synchronous);
  typedef HANDLE (NTAPI LSA_CREATE_THREAD)(SEC_ATTRS SecurityAttributes,ULONG StackSize,SEC_THREAD_START StartFunction,PVOID ThreadParameter,ULONG CreationFlags,PULONG ThreadId);
  typedef NTSTATUS (NTAPI LSA_GET_CLIENT_INFO)(PSECPKG_CLIENT_INFO ClientInfo);
  typedef HANDLE (NTAPI LSA_REGISTER_NOTIFICATION)(SEC_THREAD_START StartFunction,PVOID Parameter,ULONG NotificationType,ULONG NotificationClass,ULONG NotificationFlags,ULONG IntervalMinutes,HANDLE WaitEvent);
  typedef NTSTATUS (NTAPI LSA_CANCEL_NOTIFICATION)(HANDLE NotifyHandle);
  typedef NTSTATUS (NTAPI LSA_MAP_BUFFER)(PSecBuffer InputBuffer,PSecBuffer OutputBuffer);
  typedef NTSTATUS (NTAPI LSA_CREATE_TOKEN)(PLUID LogonId,PTOKEN_SOURCE TokenSource,SECURITY_LOGON_TYPE LogonType,SECURITY_IMPERSONATION_LEVEL ImpersonationLevel,LSA_TOKEN_INFORMATION_TYPE TokenInformationType,PVOID TokenInformation,PTOKEN_GROUPS TokenGroups,PUNICODE_STRING AccountName,PUNICODE_STRING AuthorityName,PUNICODE_STRING Workstation,PUNICODE_STRING ProfilePath,PHANDLE Token,PNTSTATUS SubStatus);

  typedef enum _SECPKG_SESSIONINFO_TYPE {
    SecSessionPrimaryCred
  } SECPKG_SESSIONINFO_TYPE;

  typedef NTSTATUS (NTAPI LSA_CREATE_TOKEN_EX)(PLUID LogonId,PTOKEN_SOURCE TokenSource,SECURITY_LOGON_TYPE LogonType,SECURITY_IMPERSONATION_LEVEL ImpersonationLevel,LSA_TOKEN_INFORMATION_TYPE TokenInformationType,PVOID TokenInformation,PTOKEN_GROUPS TokenGroups,PUNICODE_STRING Workstation,PUNICODE_STRING ProfilePath,PVOID SessionInformation,SECPKG_SESSIONINFO_TYPE SessionInformationType,PHANDLE Token,PNTSTATUS SubStatus);
  typedef VOID (NTAPI LSA_AUDIT_LOGON)(NTSTATUS Status,NTSTATUS SubStatus,PUNICODE_STRING AccountName,PUNICODE_STRING AuthenticatingAuthority,PUNICODE_STRING WorkstationName,PSID UserSid,SECURITY_LOGON_TYPE LogonType,PTOKEN_SOURCE TokenSource,PLUID LogonId);
  typedef NTSTATUS (NTAPI LSA_CALL_PACKAGE)(PUNICODE_STRING AuthenticationPackage,PVOID ProtocolSubmitBuffer,ULONG SubmitBufferLength,PVOID *ProtocolReturnBuffer,PULONG ReturnBufferLength,PNTSTATUS ProtocolStatus);
  typedef NTSTATUS (NTAPI LSA_CALL_PACKAGEEX)(PUNICODE_STRING AuthenticationPackage,PVOID ClientBufferBase,PVOID ProtocolSubmitBuffer,ULONG SubmitBufferLength,PVOID *ProtocolReturnBuffer,PULONG ReturnBufferLength,PNTSTATUS ProtocolStatus);
  typedef NTSTATUS (NTAPI LSA_CALL_PACKAGE_PASSTHROUGH)(PUNICODE_STRING AuthenticationPackage,PVOID ClientBufferBase,PVOID ProtocolSubmitBuffer,ULONG SubmitBufferLength,PVOID *ProtocolReturnBuffer,PULONG ReturnBufferLength,PNTSTATUS ProtocolStatus);
  typedef BOOLEAN (NTAPI LSA_GET_CALL_INFO)(PSECPKG_CALL_INFO Info);
  typedef PVOID (NTAPI LSA_CREATE_SHARED_MEMORY)(ULONG MaxSize,ULONG InitialSize);
  typedef PVOID (NTAPI LSA_ALLOCATE_SHARED_MEMORY)(PVOID SharedMem,ULONG Size);
  typedef VOID (NTAPI LSA_FREE_SHARED_MEMORY)(PVOID SharedMem,PVOID Memory);
  typedef BOOLEAN (NTAPI LSA_DELETE_SHARED_MEMORY)(PVOID SharedMem);

  typedef enum _SECPKG_NAME_TYPE {
    SecNameSamCompatible,
    SecNameAlternateId,
    SecNameFlat,
    SecNameDN,
    SecNameSPN
  } SECPKG_NAME_TYPE;

  typedef NTSTATUS (NTAPI LSA_OPEN_SAM_USER)(PSECURITY_STRING Name,SECPKG_NAME_TYPE NameType,PSECURITY_STRING Prefix,BOOLEAN AllowGuest,ULONG Reserved,PVOID *UserHandle);
  typedef NTSTATUS (NTAPI LSA_GET_USER_CREDENTIALS)(PVOID UserHandle,PVOID *PrimaryCreds,PULONG PrimaryCredsSize,PVOID *SupplementalCreds,PULONG SupplementalCredsSize);
  typedef NTSTATUS (NTAPI LSA_GET_USER_AUTH_DATA)(PVOID UserHandle,PUCHAR *UserAuthData,PULONG UserAuthDataSize);
  typedef NTSTATUS (NTAPI LSA_CLOSE_SAM_USER)(PVOID UserHandle);
  typedef NTSTATUS (NTAPI LSA_GET_AUTH_DATA_FOR_USER)(PSECURITY_STRING Name,SECPKG_NAME_TYPE NameType,PSECURITY_STRING Prefix,PUCHAR *UserAuthData,PULONG UserAuthDataSize,PUNICODE_STRING UserFlatName);
  typedef NTSTATUS (NTAPI LSA_CONVERT_AUTH_DATA_TO_TOKEN)(PVOID UserAuthData,ULONG UserAuthDataSize,SECURITY_IMPERSONATION_LEVEL ImpersonationLevel,PTOKEN_SOURCE TokenSource,SECURITY_LOGON_TYPE LogonType,PUNICODE_STRING AuthorityName,PHANDLE Token,PLUID LogonId,PUNICODE_STRING AccountName,PNTSTATUS SubStatus);
  typedef NTSTATUS (NTAPI LSA_CRACK_SINGLE_NAME)(ULONG FormatOffered,BOOLEAN PerformAtGC,PUNICODE_STRING NameInput,PUNICODE_STRING Prefix,ULONG RequestedFormat,PUNICODE_STRING CrackedName,PUNICODE_STRING DnsDomainName,PULONG SubStatus);
  typedef NTSTATUS (NTAPI LSA_AUDIT_ACCOUNT_LOGON)(ULONG AuditId,BOOLEAN Success,PUNICODE_STRING Source,PUNICODE_STRING ClientName,PUNICODE_STRING MappedName,NTSTATUS Status);
  typedef NTSTATUS (NTAPI LSA_CLIENT_CALLBACK)(PCHAR Callback,ULONG_PTR Argument1,ULONG_PTR Argument2,PSecBuffer Input,PSecBuffer Output);
  typedef NTSTATUS (NTAPI LSA_REGISTER_CALLBACK)(ULONG CallbackId,PLSA_CALLBACK_FUNCTION Callback);

#define NOTIFIER_FLAG_NEW_THREAD 0x00000001
#define NOTIFIER_FLAG_ONE_SHOT 0x00000002
#define NOTIFIER_FLAG_SECONDS 0x80000000

#define NOTIFIER_TYPE_INTERVAL 1
#define NOTIFIER_TYPE_HANDLE_WAIT 2
#define NOTIFIER_TYPE_STATE_CHANGE 3
#define NOTIFIER_TYPE_NOTIFY_EVENT 4
#define NOTIFIER_TYPE_IMMEDIATE 16

#define NOTIFY_CLASS_PACKAGE_CHANGE 1
#define NOTIFY_CLASS_ROLE_CHANGE 2
#define NOTIFY_CLASS_DOMAIN_CHANGE 3
#define NOTIFY_CLASS_REGISTRY_CHANGE 4

  typedef struct _SECPKG_EVENT_PACKAGE_CHANGE {
    ULONG ChangeType;
    LSA_SEC_HANDLE PackageId;
    SECURITY_STRING PackageName;
  } SECPKG_EVENT_PACKAGE_CHANGE,*PSECPKG_EVENT_PACKAGE_CHANGE;

#define SECPKG_PACKAGE_CHANGE_LOAD 0
#define SECPKG_PACKAGE_CHANGE_UNLOAD 1
#define SECPKG_PACKAGE_CHANGE_SELECT 2

  typedef struct _SECPKG_EVENT_ROLE_CHANGE {
    ULONG PreviousRole;
    ULONG NewRole;
  } SECPKG_EVENT_ROLE_CHANGE,*PSECPKG_EVENT_ROLE_CHANGE;

  typedef struct _SECPKG_PARAMETERS SECPKG_EVENT_DOMAIN_CHANGE;
  typedef struct _SECPKG_PARAMETERS *PSECPKG_EVENT_DOMAIN_CHANGE;

  typedef struct _SECPKG_EVENT_NOTIFY {
    ULONG EventClass;
    ULONG Reserved;
    ULONG EventDataSize;
    PVOID EventData;
    PVOID PackageParameter;
  } SECPKG_EVENT_NOTIFY,*PSECPKG_EVENT_NOTIFY;

  typedef NTSTATUS (NTAPI LSA_UPDATE_PRIMARY_CREDENTIALS)(PSECPKG_PRIMARY_CRED PrimaryCredentials,PSECPKG_SUPPLEMENTAL_CRED_ARRAY Credentials);
  typedef VOID (NTAPI LSA_PROTECT_MEMORY)(PVOID Buffer,ULONG BufferSize);
  typedef NTSTATUS (NTAPI LSA_OPEN_TOKEN_BY_LOGON_ID)(PLUID LogonId,HANDLE *RetTokenHandle);
  typedef NTSTATUS (NTAPI LSA_EXPAND_AUTH_DATA_FOR_DOMAIN)(PUCHAR UserAuthData,ULONG UserAuthDataSize,PVOID Reserved,PUCHAR *ExpandedAuthData,PULONG ExpandedAuthDataSize);

  typedef LSA_IMPERSONATE_CLIENT *PLSA_IMPERSONATE_CLIENT;
  typedef LSA_UNLOAD_PACKAGE *PLSA_UNLOAD_PACKAGE;
  typedef LSA_DUPLICATE_HANDLE *PLSA_DUPLICATE_HANDLE;
  typedef LSA_SAVE_SUPPLEMENTAL_CREDENTIALS *PLSA_SAVE_SUPPLEMENTAL_CREDENTIALS;
  typedef LSA_CREATE_THREAD *PLSA_CREATE_THREAD;
  typedef LSA_GET_CLIENT_INFO *PLSA_GET_CLIENT_INFO;
  typedef LSA_REGISTER_NOTIFICATION *PLSA_REGISTER_NOTIFICATION;
  typedef LSA_CANCEL_NOTIFICATION *PLSA_CANCEL_NOTIFICATION;
  typedef LSA_MAP_BUFFER *PLSA_MAP_BUFFER;
  typedef LSA_CREATE_TOKEN *PLSA_CREATE_TOKEN;
  typedef LSA_AUDIT_LOGON *PLSA_AUDIT_LOGON;
  typedef LSA_CALL_PACKAGE *PLSA_CALL_PACKAGE;
  typedef LSA_CALL_PACKAGEEX *PLSA_CALL_PACKAGEEX;
  typedef LSA_GET_CALL_INFO *PLSA_GET_CALL_INFO;
  typedef LSA_CREATE_SHARED_MEMORY *PLSA_CREATE_SHARED_MEMORY;
  typedef LSA_ALLOCATE_SHARED_MEMORY *PLSA_ALLOCATE_SHARED_MEMORY;
  typedef LSA_FREE_SHARED_MEMORY *PLSA_FREE_SHARED_MEMORY;
  typedef LSA_DELETE_SHARED_MEMORY *PLSA_DELETE_SHARED_MEMORY;
  typedef LSA_OPEN_SAM_USER *PLSA_OPEN_SAM_USER;
  typedef LSA_GET_USER_CREDENTIALS *PLSA_GET_USER_CREDENTIALS;
  typedef LSA_GET_USER_AUTH_DATA *PLSA_GET_USER_AUTH_DATA;
  typedef LSA_CLOSE_SAM_USER *PLSA_CLOSE_SAM_USER;
  typedef LSA_CONVERT_AUTH_DATA_TO_TOKEN *PLSA_CONVERT_AUTH_DATA_TO_TOKEN;
  typedef LSA_CLIENT_CALLBACK *PLSA_CLIENT_CALLBACK;
  typedef LSA_REGISTER_CALLBACK *PLSA_REGISTER_CALLBACK;
  typedef LSA_UPDATE_PRIMARY_CREDENTIALS *PLSA_UPDATE_PRIMARY_CREDENTIALS;
  typedef LSA_GET_AUTH_DATA_FOR_USER *PLSA_GET_AUTH_DATA_FOR_USER;
  typedef LSA_CRACK_SINGLE_NAME *PLSA_CRACK_SINGLE_NAME;
  typedef LSA_AUDIT_ACCOUNT_LOGON *PLSA_AUDIT_ACCOUNT_LOGON;
  typedef LSA_CALL_PACKAGE_PASSTHROUGH *PLSA_CALL_PACKAGE_PASSTHROUGH;
  typedef LSA_PROTECT_MEMORY *PLSA_PROTECT_MEMORY;
  typedef LSA_OPEN_TOKEN_BY_LOGON_ID *PLSA_OPEN_TOKEN_BY_LOGON_ID;
  typedef LSA_EXPAND_AUTH_DATA_FOR_DOMAIN *PLSA_EXPAND_AUTH_DATA_FOR_DOMAIN;
  typedef LSA_CREATE_TOKEN_EX *PLSA_CREATE_TOKEN_EX;

#ifdef _WINCRED_H_

#ifndef _ENCRYPTED_CREDENTIAL_DEFINED
#define _ENCRYPTED_CREDENTIAL_DEFINED

  typedef struct _ENCRYPTED_CREDENTIALW {
    CREDENTIALW Cred;
    ULONG ClearCredentialBlobSize;
  } ENCRYPTED_CREDENTIALW,*PENCRYPTED_CREDENTIALW;
#endif

#define CREDP_FLAGS_IN_PROCESS 0x01
#define CREDP_FLAGS_USE_MIDL_HEAP 0x02
#define CREDP_FLAGS_DONT_CACHE_TI 0x04
#define CREDP_FLAGS_CLEAR_PASSWORD 0x08
#define CREDP_FLAGS_USER_ENCRYPTED_PASSWORD 0x10

  typedef NTSTATUS (NTAPI CredReadFn)(PLUID LogonId,ULONG CredFlags,LPWSTR TargetName,ULONG Type,ULONG Flags,PENCRYPTED_CREDENTIALW *Credential);
  typedef NTSTATUS (NTAPI CredReadDomainCredentialsFn)(PLUID LogonId,ULONG CredFlags,PCREDENTIAL_TARGET_INFORMATIONW TargetInfo,ULONG Flags,PULONG Count,PENCRYPTED_CREDENTIALW **Credential);
  typedef VOID (NTAPI CredFreeCredentialsFn)(ULONG Count,PENCRYPTED_CREDENTIALW *Credentials);
  typedef NTSTATUS (NTAPI CredWriteFn)(PLUID LogonId,ULONG CredFlags,PENCRYPTED_CREDENTIALW Credential,ULONG Flags);

  NTSTATUS CredMarshalTargetInfo (PCREDENTIAL_TARGET_INFORMATIONW InTargetInfo,PUSHORT *Buffer,PULONG BufferSize);
  NTSTATUS CredUnmarshalTargetInfo (PUSHORT Buffer,ULONG BufferSize,PCREDENTIAL_TARGET_INFORMATIONW *RetTargetInfo,PULONG RetActualSize);

#define CRED_MARSHALED_TI_SIZE_SIZE 12
#endif

  typedef struct _SEC_WINNT_AUTH_IDENTITY32 {
    ULONG User;
    ULONG UserLength;
    ULONG Domain;
    ULONG DomainLength;
    ULONG Password;
    ULONG PasswordLength;
    ULONG Flags;
  } SEC_WINNT_AUTH_IDENTITY32,*PSEC_WINNT_AUTH_IDENTITY32;

  typedef struct _SEC_WINNT_AUTH_IDENTITY_EX32 {
    ULONG Version;
    ULONG Length;
    ULONG User;
    ULONG UserLength;
    ULONG Domain;
    ULONG DomainLength;
    ULONG Password;
    ULONG PasswordLength;
    ULONG Flags;
    ULONG PackageList;
    ULONG PackageListLength;
  } SEC_WINNT_AUTH_IDENTITY_EX32,*PSEC_WINNT_AUTH_IDENTITY_EX32;

  typedef struct _LSA_SECPKG_FUNCTION_TABLE {
    PLSA_CREATE_LOGON_SESSION CreateLogonSession;
    PLSA_DELETE_LOGON_SESSION DeleteLogonSession;
    PLSA_ADD_CREDENTIAL AddCredential;
    PLSA_GET_CREDENTIALS GetCredentials;
    PLSA_DELETE_CREDENTIAL DeleteCredential;
    PLSA_ALLOCATE_LSA_HEAP AllocateLsaHeap;
    PLSA_FREE_LSA_HEAP FreeLsaHeap;
    PLSA_ALLOCATE_CLIENT_BUFFER AllocateClientBuffer;
    PLSA_FREE_CLIENT_BUFFER FreeClientBuffer;
    PLSA_COPY_TO_CLIENT_BUFFER CopyToClientBuffer;
    PLSA_COPY_FROM_CLIENT_BUFFER CopyFromClientBuffer;
    PLSA_IMPERSONATE_CLIENT ImpersonateClient;
    PLSA_UNLOAD_PACKAGE UnloadPackage;
    PLSA_DUPLICATE_HANDLE DuplicateHandle;
    PLSA_SAVE_SUPPLEMENTAL_CREDENTIALS SaveSupplementalCredentials;
    PLSA_CREATE_THREAD CreateThread;
    PLSA_GET_CLIENT_INFO GetClientInfo;
    PLSA_REGISTER_NOTIFICATION RegisterNotification;
    PLSA_CANCEL_NOTIFICATION CancelNotification;
    PLSA_MAP_BUFFER MapBuffer;
    PLSA_CREATE_TOKEN CreateToken;
    PLSA_AUDIT_LOGON AuditLogon;
    PLSA_CALL_PACKAGE CallPackage;
    PLSA_FREE_LSA_HEAP FreeReturnBuffer;
    PLSA_GET_CALL_INFO GetCallInfo;
    PLSA_CALL_PACKAGEEX CallPackageEx;
    PLSA_CREATE_SHARED_MEMORY CreateSharedMemory;
    PLSA_ALLOCATE_SHARED_MEMORY AllocateSharedMemory;
    PLSA_FREE_SHARED_MEMORY FreeSharedMemory;
    PLSA_DELETE_SHARED_MEMORY DeleteSharedMemory;
    PLSA_OPEN_SAM_USER OpenSamUser;
    PLSA_GET_USER_CREDENTIALS GetUserCredentials;
    PLSA_GET_USER_AUTH_DATA GetUserAuthData;
    PLSA_CLOSE_SAM_USER CloseSamUser;
    PLSA_CONVERT_AUTH_DATA_TO_TOKEN ConvertAuthDataToToken;
    PLSA_CLIENT_CALLBACK ClientCallback;
    PLSA_UPDATE_PRIMARY_CREDENTIALS UpdateCredentials;
    PLSA_GET_AUTH_DATA_FOR_USER GetAuthDataForUser;
    PLSA_CRACK_SINGLE_NAME CrackSingleName;
    PLSA_AUDIT_ACCOUNT_LOGON AuditAccountLogon;
    PLSA_CALL_PACKAGE_PASSTHROUGH CallPackagePassthrough;
#ifdef _WINCRED_H_
    CredReadFn *CrediRead;
    CredReadDomainCredentialsFn *CrediReadDomainCredentials;
    CredFreeCredentialsFn *CrediFreeCredentials;
#else
    PLSA_PROTECT_MEMORY DummyFunction1;
    PLSA_PROTECT_MEMORY DummyFunction2;
    PLSA_PROTECT_MEMORY DummyFunction3;
#endif
    PLSA_PROTECT_MEMORY LsaProtectMemory;
    PLSA_PROTECT_MEMORY LsaUnprotectMemory;
    PLSA_OPEN_TOKEN_BY_LOGON_ID OpenTokenByLogonId;
    PLSA_EXPAND_AUTH_DATA_FOR_DOMAIN ExpandAuthDataForDomain;
    PLSA_ALLOCATE_PRIVATE_HEAP AllocatePrivateHeap;
    PLSA_FREE_PRIVATE_HEAP FreePrivateHeap;
    PLSA_CREATE_TOKEN_EX CreateTokenEx;
#ifdef _WINCRED_H_
    CredWriteFn *CrediWrite;
#else
    PLSA_PROTECT_MEMORY DummyFunction4;
#endif
  } LSA_SECPKG_FUNCTION_TABLE,*PLSA_SECPKG_FUNCTION_TABLE;

  typedef struct _SECPKG_DLL_FUNCTIONS {
    PLSA_ALLOCATE_LSA_HEAP AllocateHeap;
    PLSA_FREE_LSA_HEAP FreeHeap;
    PLSA_REGISTER_CALLBACK RegisterCallback;
  } SECPKG_DLL_FUNCTIONS,*PSECPKG_DLL_FUNCTIONS;

  typedef NTSTATUS (NTAPI SpInitializeFn)(ULONG_PTR PackageId,PSECPKG_PARAMETERS Parameters,PLSA_SECPKG_FUNCTION_TABLE FunctionTable);
  typedef NTSTATUS (NTAPI SpShutdownFn)(VOID);
  typedef NTSTATUS (NTAPI SpGetInfoFn)(PSecPkgInfo PackageInfo);
  typedef NTSTATUS (NTAPI SpGetExtendedInformationFn)(SECPKG_EXTENDED_INFORMATION_CLASS Class,PSECPKG_EXTENDED_INFORMATION *ppInformation);
  typedef NTSTATUS (NTAPI SpSetExtendedInformationFn)(SECPKG_EXTENDED_INFORMATION_CLASS Class,PSECPKG_EXTENDED_INFORMATION Info);
  typedef NTSTATUS (LSA_AP_LOGON_USER_EX2)(PLSA_CLIENT_REQUEST ClientRequest,SECURITY_LOGON_TYPE LogonType,PVOID AuthenticationInformation,PVOID ClientAuthenticationBase,ULONG AuthenticationInformationLength,PVOID *ProfileBuffer,PULONG ProfileBufferLength,PLUID LogonId,PNTSTATUS SubStatus,PLSA_TOKEN_INFORMATION_TYPE TokenInformationType,PVOID *TokenInformation,PUNICODE_STRING *AccountName,PUNICODE_STRING *AuthenticatingAuthority,PUNICODE_STRING *MachineName,PSECPKG_PRIMARY_CRED PrimaryCredentials,PSECPKG_SUPPLEMENTAL_CRED_ARRAY *CachedCredentials);

  typedef LSA_AP_LOGON_USER_EX2 *PLSA_AP_LOGON_USER_EX2;

#define LSA_AP_NAME_LOGON_USER_EX2 "LsaApLogonUserEx2\0"

  typedef NTSTATUS (NTAPI SpAcceptCredentialsFn)(SECURITY_LOGON_TYPE LogonType,PUNICODE_STRING AccountName,PSECPKG_PRIMARY_CRED PrimaryCredentials,PSECPKG_SUPPLEMENTAL_CRED SupplementalCredentials);

#define SP_ACCEPT_CREDENTIALS_NAME "SpAcceptCredentials\0"

  typedef NTSTATUS (NTAPI SpAcquireCredentialsHandleFn)(PUNICODE_STRING PrincipalName,ULONG CredentialUseFlags,PLUID LogonId,PVOID AuthorizationData,PVOID GetKeyFunciton,PVOID GetKeyArgument,PLSA_SEC_HANDLE CredentialHandle,PTimeStamp ExpirationTime);
  typedef NTSTATUS (NTAPI SpFreeCredentialsHandleFn)(LSA_SEC_HANDLE CredentialHandle);
  typedef NTSTATUS (NTAPI SpQueryCredentialsAttributesFn)(LSA_SEC_HANDLE CredentialHandle,ULONG CredentialAttribute,PVOID Buffer);
  typedef NTSTATUS (NTAPI SpSetCredentialsAttributesFn)(LSA_SEC_HANDLE CredentialHandle,ULONG CredentialAttribute,PVOID Buffer,ULONG BufferSize);
  typedef NTSTATUS (NTAPI SpAddCredentialsFn)(LSA_SEC_HANDLE CredentialHandle,PUNICODE_STRING PrincipalName,PUNICODE_STRING Package,ULONG CredentialUseFlags,PVOID AuthorizationData,PVOID GetKeyFunciton,PVOID GetKeyArgument,PTimeStamp ExpirationTime);
  typedef NTSTATUS (NTAPI SpSaveCredentialsFn)(LSA_SEC_HANDLE CredentialHandle,PSecBuffer Credentials);
  typedef NTSTATUS (NTAPI SpGetCredentialsFn)(LSA_SEC_HANDLE CredentialHandle,PSecBuffer Credentials);
  typedef NTSTATUS (NTAPI SpDeleteCredentialsFn)(LSA_SEC_HANDLE CredentialHandle,PSecBuffer Key);
  typedef NTSTATUS (NTAPI SpInitLsaModeContextFn)(LSA_SEC_HANDLE CredentialHandle,LSA_SEC_HANDLE ContextHandle,PUNICODE_STRING TargetName,ULONG ContextRequirements,ULONG TargetDataRep,PSecBufferDesc InputBuffers,PLSA_SEC_HANDLE NewContextHandle,PSecBufferDesc OutputBuffers,PULONG ContextAttributes,PTimeStamp ExpirationTime,PBOOLEAN MappedContext,PSecBuffer ContextData);
  typedef NTSTATUS (NTAPI SpDeleteContextFn)(LSA_SEC_HANDLE ContextHandle);
  typedef NTSTATUS (NTAPI SpApplyControlTokenFn)(LSA_SEC_HANDLE ContextHandle,PSecBufferDesc ControlToken);
  typedef NTSTATUS (NTAPI SpAcceptLsaModeContextFn)(LSA_SEC_HANDLE CredentialHandle,LSA_SEC_HANDLE ContextHandle,PSecBufferDesc InputBuffer,ULONG ContextRequirements,ULONG TargetDataRep,PLSA_SEC_HANDLE NewContextHandle,PSecBufferDesc OutputBuffer,PULONG ContextAttributes,PTimeStamp ExpirationTime,PBOOLEAN MappedContext,PSecBuffer ContextData);
  typedef NTSTATUS (NTAPI SpGetUserInfoFn)(PLUID LogonId,ULONG Flags,PSecurityUserData *UserData);
  typedef NTSTATUS (NTAPI SpQueryContextAttributesFn)(LSA_SEC_HANDLE ContextHandle,ULONG ContextAttribute,PVOID Buffer);
  typedef NTSTATUS (NTAPI SpSetContextAttributesFn)(LSA_SEC_HANDLE ContextHandle,ULONG ContextAttribute,PVOID Buffer,ULONG BufferSize);

  typedef struct _SECPKG_FUNCTION_TABLE {
    PLSA_AP_INITIALIZE_PACKAGE InitializePackage;
    PLSA_AP_LOGON_USER LogonUser;
    PLSA_AP_CALL_PACKAGE CallPackage;
    PLSA_AP_LOGON_TERMINATED LogonTerminated;
    PLSA_AP_CALL_PACKAGE_UNTRUSTED CallPackageUntrusted;
    PLSA_AP_CALL_PACKAGE_PASSTHROUGH CallPackagePassthrough;
    PLSA_AP_LOGON_USER_EX LogonUserEx;
    PLSA_AP_LOGON_USER_EX2 LogonUserEx2;
    SpInitializeFn *Initialize;
    SpShutdownFn *Shutdown;
    SpGetInfoFn *GetInfo;
    SpAcceptCredentialsFn *AcceptCredentials;
    SpAcquireCredentialsHandleFn *AcquireCredentialsHandle;
    SpQueryCredentialsAttributesFn *QueryCredentialsAttributes;
    SpFreeCredentialsHandleFn *FreeCredentialsHandle;
    SpSaveCredentialsFn *SaveCredentials;
    SpGetCredentialsFn *GetCredentials;
    SpDeleteCredentialsFn *DeleteCredentials;
    SpInitLsaModeContextFn *InitLsaModeContext;
    SpAcceptLsaModeContextFn *AcceptLsaModeContext;
    SpDeleteContextFn *DeleteContext;
    SpApplyControlTokenFn *ApplyControlToken;
    SpGetUserInfoFn *GetUserInfo;
    SpGetExtendedInformationFn *GetExtendedInformation;
    SpQueryContextAttributesFn *QueryContextAttributes;
    SpAddCredentialsFn *AddCredentials;
    SpSetExtendedInformationFn *SetExtendedInformation;
    SpSetContextAttributesFn *SetContextAttributes;
    SpSetCredentialsAttributesFn *SetCredentialsAttributes;
  } SECPKG_FUNCTION_TABLE,*PSECPKG_FUNCTION_TABLE;

  typedef NTSTATUS (NTAPI SpInstanceInitFn)(ULONG Version,PSECPKG_DLL_FUNCTIONS FunctionTable,PVOID *UserFunctions);
  typedef NTSTATUS (NTAPI SpInitUserModeContextFn)(LSA_SEC_HANDLE ContextHandle,PSecBuffer PackedContext);
  typedef NTSTATUS (NTAPI SpMakeSignatureFn)(LSA_SEC_HANDLE ContextHandle,ULONG QualityOfProtection,PSecBufferDesc MessageBuffers,ULONG MessageSequenceNumber);
  typedef NTSTATUS (NTAPI SpVerifySignatureFn)(LSA_SEC_HANDLE ContextHandle,PSecBufferDesc MessageBuffers,ULONG MessageSequenceNumber,PULONG QualityOfProtection);
  typedef NTSTATUS (NTAPI SpSealMessageFn)(LSA_SEC_HANDLE ContextHandle,ULONG QualityOfProtection,PSecBufferDesc MessageBuffers,ULONG MessageSequenceNumber);
  typedef NTSTATUS (NTAPI SpUnsealMessageFn)(LSA_SEC_HANDLE ContextHandle,PSecBufferDesc MessageBuffers,ULONG MessageSequenceNumber,PULONG QualityOfProtection);
  typedef NTSTATUS (NTAPI SpGetContextTokenFn)(LSA_SEC_HANDLE ContextHandle,PHANDLE ImpersonationToken);
  typedef NTSTATUS (NTAPI SpExportSecurityContextFn)(LSA_SEC_HANDLE phContext,ULONG fFlags,PSecBuffer pPackedContext,PHANDLE pToken);
  typedef NTSTATUS (NTAPI SpImportSecurityContextFn)(PSecBuffer pPackedContext,HANDLE Token,PLSA_SEC_HANDLE phContext);
  typedef NTSTATUS (NTAPI SpCompleteAuthTokenFn)(LSA_SEC_HANDLE ContextHandle,PSecBufferDesc InputBuffer);
  typedef NTSTATUS (NTAPI SpFormatCredentialsFn)(PSecBuffer Credentials,PSecBuffer FormattedCredentials);
  typedef NTSTATUS (NTAPI SpMarshallSupplementalCredsFn)(ULONG CredentialSize,PUCHAR Credentials,PULONG MarshalledCredSize,PVOID *MarshalledCreds);

  typedef struct _SECPKG_USER_FUNCTION_TABLE {
    SpInstanceInitFn *InstanceInit;
    SpInitUserModeContextFn *InitUserModeContext;
    SpMakeSignatureFn *MakeSignature;
    SpVerifySignatureFn *VerifySignature;
    SpSealMessageFn *SealMessage;
    SpUnsealMessageFn *UnsealMessage;
    SpGetContextTokenFn *GetContextToken;
    SpQueryContextAttributesFn *QueryContextAttributes;
    SpCompleteAuthTokenFn *CompleteAuthToken;
    SpDeleteContextFn *DeleteUserModeContext;
    SpFormatCredentialsFn *FormatCredentials;
    SpMarshallSupplementalCredsFn *MarshallSupplementalCreds;
    SpExportSecurityContextFn *ExportContext;
    SpImportSecurityContextFn *ImportContext;
  } SECPKG_USER_FUNCTION_TABLE,*PSECPKG_USER_FUNCTION_TABLE;

  typedef NTSTATUS (SEC_ENTRY *SpLsaModeInitializeFn)(ULONG LsaVersion,PULONG PackageVersion,PSECPKG_FUNCTION_TABLE *ppTables,PULONG pcTables);
  typedef NTSTATUS (SEC_ENTRY *SpUserModeInitializeFn)(ULONG LsaVersion,PULONG PackageVersion,PSECPKG_USER_FUNCTION_TABLE *ppTables,PULONG pcTables);

#define SECPKG_LSAMODEINIT_NAME "SpLsaModeInitialize"
#define SECPKG_USERMODEINIT_NAME "SpUserModeInitialize"

#define SECPKG_INTERFACE_VERSION 0x00010000
#define SECPKG_INTERFACE_VERSION_2 0x00020000
#define SECPKG_INTERFACE_VERSION_3 0x00040000

  typedef enum _KSEC_CONTEXT_TYPE {
    KSecPaged,KSecNonPaged
  } KSEC_CONTEXT_TYPE;

  typedef struct _KSEC_LIST_ENTRY {
    LIST_ENTRY List;
    LONG RefCount;
    ULONG Signature;
    PVOID OwningList;
    PVOID Reserved;
  } KSEC_LIST_ENTRY,*PKSEC_LIST_ENTRY;

#define KsecInitializeListEntry(Entry,SigValue) ((PKSEC_LIST_ENTRY) Entry)->List.Flink = ((PKSEC_LIST_ENTRY) Entry)->List.Blink = NULL; ((PKSEC_LIST_ENTRY) Entry)->RefCount = 1; ((PKSEC_LIST_ENTRY) Entry)->Signature = SigValue; ((PKSEC_LIST_ENTRY) Entry)->OwningList = NULL; ((PKSEC_LIST_ENTRY) Entry)->Reserved = NULL;

  typedef PVOID (SEC_ENTRY KSEC_CREATE_CONTEXT_LIST)(KSEC_CONTEXT_TYPE Type);
  typedef VOID (SEC_ENTRY KSEC_INSERT_LIST_ENTRY)(PVOID List,PKSEC_LIST_ENTRY Entry);
  typedef NTSTATUS (SEC_ENTRY KSEC_REFERENCE_LIST_ENTRY)(PKSEC_LIST_ENTRY Entry,ULONG Signature,BOOLEAN RemoveNoRef);
  typedef VOID (SEC_ENTRY KSEC_DEREFERENCE_LIST_ENTRY)(PKSEC_LIST_ENTRY Entry,BOOLEAN *Delete);
  typedef NTSTATUS (SEC_ENTRY KSEC_SERIALIZE_WINNT_AUTH_DATA)(PVOID pvAuthData,PULONG Size,PVOID *SerializedData);
  typedef NTSTATUS (SEC_ENTRY KSEC_SERIALIZE_SCHANNEL_AUTH_DATA)(PVOID pvAuthData,PULONG Size,PVOID *SerializedData);

  KSEC_CREATE_CONTEXT_LIST KSecCreateContextList;
  KSEC_INSERT_LIST_ENTRY KSecInsertListEntry;
  KSEC_REFERENCE_LIST_ENTRY KSecReferenceListEntry;
  KSEC_DEREFERENCE_LIST_ENTRY KSecDereferenceListEntry;
  KSEC_SERIALIZE_WINNT_AUTH_DATA KSecSerializeWinntAuthData;
  KSEC_SERIALIZE_SCHANNEL_AUTH_DATA KSecSerializeSchannelAuthData;

  typedef KSEC_CREATE_CONTEXT_LIST *PKSEC_CREATE_CONTEXT_LIST;
  typedef KSEC_INSERT_LIST_ENTRY *PKSEC_INSERT_LIST_ENTRY;
  typedef KSEC_REFERENCE_LIST_ENTRY *PKSEC_REFERENCE_LIST_ENTRY;
  typedef KSEC_DEREFERENCE_LIST_ENTRY *PKSEC_DEREFERENCE_LIST_ENTRY;
  typedef KSEC_SERIALIZE_WINNT_AUTH_DATA *PKSEC_SERIALIZE_WINNT_AUTH_DATA;
  typedef KSEC_SERIALIZE_SCHANNEL_AUTH_DATA *PKSEC_SERIALIZE_SCHANNEL_AUTH_DATA;

  typedef struct _SECPKG_KERNEL_FUNCTIONS {
    PLSA_ALLOCATE_LSA_HEAP AllocateHeap;
    PLSA_FREE_LSA_HEAP FreeHeap;
    PKSEC_CREATE_CONTEXT_LIST CreateContextList;
    PKSEC_INSERT_LIST_ENTRY InsertListEntry;
    PKSEC_REFERENCE_LIST_ENTRY ReferenceListEntry;
    PKSEC_DEREFERENCE_LIST_ENTRY DereferenceListEntry;
    PKSEC_SERIALIZE_WINNT_AUTH_DATA SerializeWinntAuthData;
    PKSEC_SERIALIZE_SCHANNEL_AUTH_DATA SerializeSchannelAuthData;
  } SECPKG_KERNEL_FUNCTIONS,*PSECPKG_KERNEL_FUNCTIONS;

  typedef NTSTATUS (NTAPI KspInitPackageFn)(PSECPKG_KERNEL_FUNCTIONS FunctionTable);
  typedef NTSTATUS (NTAPI KspDeleteContextFn)(LSA_SEC_HANDLE ContextId,PLSA_SEC_HANDLE LsaContextId);
  typedef NTSTATUS (NTAPI KspInitContextFn)(LSA_SEC_HANDLE ContextId,PSecBuffer ContextData,PLSA_SEC_HANDLE NewContextId);
  typedef NTSTATUS (NTAPI KspMakeSignatureFn)(LSA_SEC_HANDLE ContextId,ULONG fQOP,PSecBufferDesc Message,ULONG MessageSeqNo);
  typedef NTSTATUS (NTAPI KspVerifySignatureFn)(LSA_SEC_HANDLE ContextId,PSecBufferDesc Message,ULONG MessageSeqNo,PULONG pfQOP);
  typedef NTSTATUS (NTAPI KspSealMessageFn)(LSA_SEC_HANDLE ContextId,ULONG fQOP,PSecBufferDesc Message,ULONG MessageSeqNo);
  typedef NTSTATUS (NTAPI KspUnsealMessageFn)(LSA_SEC_HANDLE ContextId,PSecBufferDesc Message,ULONG MessageSeqNo,PULONG pfQOP);
  typedef NTSTATUS (NTAPI KspGetTokenFn)(LSA_SEC_HANDLE ContextId,PHANDLE ImpersonationToken,PACCESS_TOKEN *RawToken);
  typedef NTSTATUS (NTAPI KspQueryAttributesFn)(LSA_SEC_HANDLE ContextId,ULONG Attribute,PVOID Buffer);
  typedef NTSTATUS (NTAPI KspCompleteTokenFn)(LSA_SEC_HANDLE ContextId,PSecBufferDesc Token);
  typedef NTSTATUS (NTAPI KspMapHandleFn)(LSA_SEC_HANDLE ContextId,PLSA_SEC_HANDLE LsaContextId);
  typedef NTSTATUS (NTAPI KspSetPagingModeFn)(BOOLEAN PagingMode);
  typedef NTSTATUS (NTAPI KspSerializeAuthDataFn)(PVOID pvAuthData,PULONG Size,PVOID *SerializedData);

  typedef struct _SECPKG_KERNEL_FUNCTION_TABLE {
    KspInitPackageFn *Initialize;
    KspDeleteContextFn *DeleteContext;
    KspInitContextFn *InitContext;
    KspMapHandleFn *MapHandle;
    KspMakeSignatureFn *Sign;
    KspVerifySignatureFn *Verify;
    KspSealMessageFn *Seal;
    KspUnsealMessageFn *Unseal;
    KspGetTokenFn *GetToken;
    KspQueryAttributesFn *QueryAttributes;
    KspCompleteTokenFn *CompleteToken;
    SpExportSecurityContextFn *ExportContext;
    SpImportSecurityContextFn *ImportContext;
    KspSetPagingModeFn *SetPackagePagingMode;
    KspSerializeAuthDataFn *SerializeAuthData;
  } SECPKG_KERNEL_FUNCTION_TABLE,*PSECPKG_KERNEL_FUNCTION_TABLE;

  SECURITY_STATUS SEC_ENTRY KSecRegisterSecurityProvider(PSECURITY_STRING ProviderName,PSECPKG_KERNEL_FUNCTION_TABLE Table);

  extern SECPKG_KERNEL_FUNCTIONS KspKernelFunctions;

#ifdef __cplusplus
}
#endif
#endif
