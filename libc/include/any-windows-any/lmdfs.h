/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _LMDFS_
#define _LMDFS_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef NET_API_FUNCTION
#define NET_API_FUNCTION WINAPI
#endif

#define DFS_VOLUME_STATES 0xF

#define DFS_VOLUME_STATE_OK 1
#define DFS_VOLUME_STATE_INCONSISTENT 2
#define DFS_VOLUME_STATE_OFFLINE 3
#define DFS_VOLUME_STATE_ONLINE 4

#define DFS_VOLUME_STATE_RESYNCHRONIZE 0x10
#define DFS_VOLUME_STATE_STANDBY 0x20

#define DFS_VOLUME_FLAVORS 0x0300

#define DFS_VOLUME_FLAVOR_UNUSED1 0x0000
#define DFS_VOLUME_FLAVOR_STANDALONE 0x0100
#define DFS_VOLUME_FLAVOR_AD_BLOB 0x0200
#define DFS_STORAGE_FLAVOR_UNUSED2 0x0300

#define DFS_STORAGE_STATES 0xF
#define DFS_STORAGE_STATE_OFFLINE 1
#define DFS_STORAGE_STATE_ONLINE 2
#define DFS_STORAGE_STATE_ACTIVE 4

  typedef enum _DFS_TARGET_PRIORITY_CLASS {
    DfsInvalidPriorityClass = -1,DfsSiteCostNormalPriorityClass = 0,DfsGlobalHighPriorityClass,DfsSiteCostHighPriorityClass,
    DfsSiteCostLowPriorityClass,DfsGlobalLowPriorityClass
  } DFS_TARGET_PRIORITY_CLASS;

  typedef struct _DFS_TARGET_PRIORITY {
    DFS_TARGET_PRIORITY_CLASS TargetPriorityClass;
    USHORT TargetPriorityRank;
    USHORT Reserved;
  } DFS_TARGET_PRIORITY,*PDFS_TARGET_PRIORITY;

  typedef struct _DFS_INFO_1 {
    LPWSTR EntryPath;
  } DFS_INFO_1,*PDFS_INFO_1,*LPDFS_INFO_1;

  typedef struct _DFS_INFO_2 {
    LPWSTR EntryPath;
    LPWSTR Comment;
    DWORD State;
    DWORD NumberOfStorages;
  } DFS_INFO_2,*PDFS_INFO_2,*LPDFS_INFO_2;

  typedef struct _DFS_STORAGE_INFO {
    ULONG State;
    LPWSTR ServerName;
    LPWSTR ShareName;
  } DFS_STORAGE_INFO,*PDFS_STORAGE_INFO,*LPDFS_STORAGE_INFO;

#ifdef _WIN64
  typedef struct _DFS_STORAGE_INFO_0_32 {
    ULONG State;
    ULONG ServerName;
    ULONG ShareName;
  } DFS_STORAGE_INFO_0_32,*PDFS_STORAGE_INFO_0_32,*LPDFS_STORAGE_INFO_0_32;
#endif

  typedef struct _DFS_STORAGE_INFO_1 {
    ULONG State;
    LPWSTR ServerName;
    LPWSTR ShareName;
    DFS_TARGET_PRIORITY TargetPriority;
  } DFS_STORAGE_INFO_1,*PDFS_STORAGE_INFO_1,*LPDFS_STORAGE_INFO_1;

  typedef struct _DFS_INFO_3 {
    LPWSTR EntryPath;
    LPWSTR Comment;
    DWORD State;
    DWORD NumberOfStorages;
    LPDFS_STORAGE_INFO Storage;
  } DFS_INFO_3,*PDFS_INFO_3,*LPDFS_INFO_3;

#ifdef _WIN64
  typedef struct _DFS_INFO_3_32 {
    ULONG EntryPath;
    ULONG Comment;
    DWORD State;
    DWORD NumberOfStorages;
    ULONG Storage;
  } DFS_INFO_3_32,*PDFS_INFO_3_32,*LPDFS_INFO_3_32;
#endif

  typedef struct _DFS_INFO_4 {
    LPWSTR EntryPath;
    LPWSTR Comment;
    DWORD State;
    ULONG Timeout;
    GUID Guid;
    DWORD NumberOfStorages;
    LPDFS_STORAGE_INFO Storage;
  } DFS_INFO_4,*PDFS_INFO_4,*LPDFS_INFO_4;

#ifdef _WIN64
  typedef struct _DFS_INFO_4_32 {
    ULONG EntryPath;
    ULONG Comment;
    DWORD State;
    ULONG Timeout;
    GUID Guid;
    DWORD NumberOfStorages;
    ULONG Storage;
  } DFS_INFO_4_32,*PDFS_INFO_4_32,*LPDFS_INFO_4_32;
#endif

  typedef struct _DFS_INFO_5 {
    LPWSTR EntryPath;
    LPWSTR Comment;
    DWORD State;
    ULONG Timeout;
    GUID Guid;
    ULONG PropertyFlags;
    ULONG MetadataSize;
    DWORD NumberOfStorages;
  } DFS_INFO_5,*PDFS_INFO_5,*LPDFS_INFO_5;

  typedef struct _DFS_INFO_6 {
    LPWSTR EntryPath;
    LPWSTR Comment;
    DWORD State;
    ULONG Timeout;
    GUID Guid;
    ULONG PropertyFlags;
    ULONG MetadataSize;
    DWORD NumberOfStorages;
    LPDFS_STORAGE_INFO_1 Storage;
  } DFS_INFO_6,*PDFS_INFO_6,*LPDFS_INFO_6;

  typedef struct _DFS_INFO_7 {
    GUID GenerationGuid;
  } DFS_INFO_7,*PDFS_INFO_7,*LPDFS_INFO_7;

#define DFS_PROPERTY_FLAG_INSITE_REFERRALS 0x00000001
#define DFS_PROPERTY_FLAG_ROOT_SCALABILITY 0x00000002
#define DFS_PROPERTY_FLAG_SITE_COSTING 0x00000004
#define DFS_PROPERTY_FLAG_TARGET_FAILBACK 0x00000008
#define DFS_PROPERTY_FLAG_CLUSTER_ENABLED 0x00000010
#define DFS_PROPERTY_FLAG_ABDE 0x00000020

  typedef struct _DFS_INFO_100 {
    LPWSTR Comment;
  } DFS_INFO_100,*PDFS_INFO_100,*LPDFS_INFO_100;

  typedef struct _DFS_INFO_101 {
    DWORD State;
  } DFS_INFO_101,*PDFS_INFO_101,*LPDFS_INFO_101;

  typedef struct _DFS_INFO_102 {
    ULONG Timeout;
  } DFS_INFO_102,*PDFS_INFO_102,*LPDFS_INFO_102;

  typedef struct _DFS_INFO_103 {
    ULONG PropertyFlagMask;
    ULONG PropertyFlags;
  } DFS_INFO_103,*PDFS_INFO_103,*LPDFS_INFO_103;

  typedef struct _DFS_INFO_104 {
    DFS_TARGET_PRIORITY TargetPriority;
  } DFS_INFO_104,*PDFS_INFO_104,*LPDFS_INFO_104;

  typedef struct _DFS_INFO_105 {
    LPWSTR Comment;
    DWORD State;
    ULONG Timeout;
    ULONG PropertyFlagMask;
    ULONG PropertyFlags;
  } DFS_INFO_105,*PDFS_INFO_105,*LPDFS_INFO_105;

  typedef struct _DFS_INFO_106 {
    DWORD State;
    DFS_TARGET_PRIORITY TargetPriority;
  } DFS_INFO_106,*PDFS_INFO_106,*LPDFS_INFO_106;

#if (_WIN32_WINNT >= 0x0600)
#define DFS_NAMESPACE_CAPABILITY_ABDE 0x0000000000000001

  typedef enum _DFS_NAMESPACE_VERSION_ORIGIN {
    DFS_NAMESPACE_VERSION_ORIGIN_COMBINED   = 0,
    DFS_NAMESPACE_VERSION_ORIGIN_SERVER     = 1,
    DFS_NAMESPACE_VERSION_ORIGIN_DOMAIN     = 2 
  } DFS_NAMESPACE_VERSION_ORIGIN;

typedef struct _DFS_SUPPORTED_NAMESPACE_VERSION_INFO {
  ULONG     DomainDfsMajorVersion;
  ULONG     NamespaceMinorVersion;
  ULONGLONG DomainDfsCapabilities;
  ULONG     StandaloneDfsMajorVersion;
  ULONG     StandaloneDfsMinorVersion;
  ULONGLONG StandaloneDfsCapabilities;
} DFS_SUPPORTED_NAMESPACE_VERSION_INFO, *PDFS_SUPPORTED_NAMESPACE_VERSION_INFO;

  typedef struct _DFS_INFO_8 {
    LPWSTR               EntryPath;
    LPWSTR               Comment;
    DWORD                State;
    ULONG                Timeout;
    GUID                 Guid;
    ULONG                PropertyFlags;
    ULONG                MetadataSize;
    ULONG                SdLengthReserved;
    PSECURITY_DESCRIPTOR pSecurityDescriptor;
    DWORD                NumberOfStorages;
  } DFS_INFO_8, *PDFS_INFO_8;

  typedef struct _DFS_INFO_9 {
    LPWSTR               EntryPath;
    LPWSTR               Comment;
    DWORD                State;
    ULONG                Timeout;
    GUID                 Guid;
    ULONG                PropertyFlags;
    ULONG                MetadataSize;
    ULONG                SdLengthReserved;
    PSECURITY_DESCRIPTOR pSecurityDescriptor;
    DWORD                NumberOfStorages;
    LPDFS_STORAGE_INFO_1 Storage;
  } DFS_INFO_9, *PDFS_INFO_9;

  typedef struct _DFS_INFO_50 {
    ULONG     NamespaceMajorVersion;
    ULONG     NamespaceMinorVersion;
    ULONGLONG NamespaceCapabilities;
  } DFS_INFO_50, *PDFS_INFO_50;

  typedef struct _DFS_INFO_107 {
    LPWSTR               Comment;
    DWORD                State;
    ULONG                Timeout;
    ULONG                PropertyFlagMask;
    ULONG                PropertyFlags;
    ULONG                SdLengthReserved;
    PSECURITY_DESCRIPTOR pSecurityDescriptor;
  } DFS_INFO_107, *PDFS_INFO_107;

  typedef struct _DFS_INFO_150 {
    ULONG                SdLengthReserved;
    PSECURITY_DESCRIPTOR pSecurityDescriptor;
  } DFS_INFO_150, *PDFS_INFO_150;

NET_API_STATUS NET_API_FUNCTION NetDfsAddRootTarget(
  LPWSTR pDfsPath,
  LPWSTR pTargetPath,
  ULONG MajorVersion,
  LPWSTR pComment,
  ULONG Flags
);

NET_API_STATUS NET_API_FUNCTION NetDfsGetSupportedNamespaceVersion(
  DFS_NAMESPACE_VERSION_ORIGIN Origin,
  PWSTR pName,
  PDFS_SUPPORTED_NAMESPACE_VERSION_INFO *ppVersionInfo
);

NET_API_STATUS NET_API_FUNCTION NetDfsRemoveRootTarget(
  LPWSTR pDfsPath,
  LPWSTR pTargetPath,
  ULONG Flags
);

NET_API_STATUS WINAPI NetShareDelEx(
  LMSTR servername,
  DWORD level,
  LPBYTE buf
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

  typedef struct _DFS_INFO_200 {
    LPWSTR FtDfsName;
  } DFS_INFO_200,*PDFS_INFO_200,*LPDFS_INFO_200;

  typedef struct _DFS_INFO_300 {
    DWORD Flags;
    LPWSTR DfsName;
  } DFS_INFO_300,*PDFS_INFO_300,*LPDFS_INFO_300;

#define DFS_ADD_VOLUME 1
#define DFS_RESTORE_VOLUME 2

  NET_API_STATUS WINAPI NetDfsAdd(LPWSTR DfsEntryPath,LPWSTR ServerName,LPWSTR ShareName,LPWSTR Comment,DWORD Flags);
  NET_API_STATUS WINAPI NetDfsAddStdRoot(LPWSTR ServerName,LPWSTR RootShare,LPWSTR Comment,DWORD Flags);
  NET_API_STATUS WINAPI NetDfsRemoveStdRoot(LPWSTR ServerName,LPWSTR RootShare,DWORD Flags);
  NET_API_STATUS WINAPI NetDfsAddFtRoot(LPWSTR ServerName,LPWSTR RootShare,LPWSTR FtDfsName,LPWSTR Comment,DWORD Flags);
  NET_API_STATUS WINAPI NetDfsRemoveFtRoot(LPWSTR ServerName,LPWSTR RootShare,LPWSTR FtDfsName,DWORD Flags);
  NET_API_STATUS WINAPI NetDfsRemoveFtRootForced(LPWSTR DomainName,LPWSTR ServerName,LPWSTR RootShare,LPWSTR FtDfsName,DWORD Flags);
  NET_API_STATUS WINAPI NetDfsManagerInitialize(LPWSTR ServerName,DWORD Flags);
  NET_API_STATUS WINAPI NetDfsAddStdRootForced(LPWSTR ServerName,LPWSTR RootShare,LPWSTR Comment,LPWSTR Store);
  NET_API_STATUS WINAPI NetDfsGetDcAddress(LPWSTR ServerName,LPWSTR *DcIpAddress,BOOLEAN *IsRoot,ULONG *Timeout);

#define NET_DFS_SETDC_FLAGS 0x00000000
#define NET_DFS_SETDC_TIMEOUT 0x00000001
#define NET_DFS_SETDC_INITPKT 0x00000002

  typedef struct {
    ULONG SiteFlags;
    LPWSTR SiteName;
  } DFS_SITENAME_INFO,*PDFS_SITENAME_INFO,*LPDFS_SITENAME_INFO;

#define DFS_SITE_PRIMARY 0x1

  typedef struct {
    ULONG cSites;
    DFS_SITENAME_INFO Site[1];
  } DFS_SITELIST_INFO,*PDFS_SITELIST_INFO,*LPDFS_SITELIST_INFO;

  NET_API_STATUS WINAPI NetDfsRemove(LPWSTR DfsEntryPath,LPWSTR ServerName,LPWSTR ShareName);
  NET_API_STATUS WINAPI NetDfsEnum(LPWSTR DfsName,DWORD Level,DWORD PrefMaxLen,LPBYTE *Buffer,LPDWORD EntriesRead,LPDWORD ResumeHandle);
  NET_API_STATUS WINAPI NetDfsGetInfo(LPWSTR DfsEntryPath,LPWSTR ServerName,LPWSTR ShareName,DWORD Level,LPBYTE *Buffer);
  NET_API_STATUS WINAPI NetDfsSetInfo(LPWSTR DfsEntryPath,LPWSTR ServerName,LPWSTR ShareName,DWORD Level,LPBYTE Buffer);
  NET_API_STATUS WINAPI NetDfsGetClientInfo(LPWSTR DfsEntryPath,LPWSTR ServerName,LPWSTR ShareName,DWORD Level,LPBYTE *Buffer);
  NET_API_STATUS WINAPI NetDfsSetClientInfo(LPWSTR DfsEntryPath,LPWSTR ServerName,LPWSTR ShareName,DWORD Level,LPBYTE Buffer);
  NET_API_STATUS WINAPI NetDfsMove(LPWSTR DfsEntryPath,LPWSTR DfsNewEntryPath,ULONG Flags);

#define DFS_MOVE_FLAG_REPLACE_IF_EXISTS 0x00000001

  NET_API_STATUS WINAPI NetDfsRename(LPWSTR Path,LPWSTR NewPath);
  NET_API_STATUS WINAPI NetDfsGetSecurity(LPWSTR DfsEntryPath,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR *ppSecurityDescriptor,LPDWORD lpcbSecurityDescriptor);
  NET_API_STATUS WINAPI NetDfsSetSecurity(LPWSTR DfsEntryPath,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR pSecurityDescriptor);
  NET_API_STATUS WINAPI NetDfsGetStdContainerSecurity(LPWSTR MachineName,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR *ppSecurityDescriptor,LPDWORD lpcbSecurityDescriptor);
  NET_API_STATUS WINAPI NetDfsSetStdContainerSecurity(LPWSTR MachineName,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR pSecurityDescriptor);
  NET_API_STATUS WINAPI NetDfsGetFtContainerSecurity(LPWSTR DomainName,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR *ppSecurityDescriptor,LPDWORD lpcbSecurityDescriptor);
  NET_API_STATUS WINAPI NetDfsSetFtContainerSecurity(LPWSTR DomainName,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR pSecurityDescriptor);

#ifdef __cplusplus
}
#endif
#endif
