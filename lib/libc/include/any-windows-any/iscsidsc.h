/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_ISCSIDSC
#define _INC_ISCSIDSC
#include <ntddscsi.h>
#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

  typedef enum  {
    ISCSI_NO_AUTH_TYPE             = 0,
    ISCSI_CHAP_AUTH_TYPE           = 1,
    ISCSI_MUTUAL_CHAP_AUTH_TYPE    = 2 
  } ISCSI_AUTH_TYPES;

  typedef enum  {
    ISCSI_DIGEST_TYPE_NONE     = 0,
    ISCSI_DIGEST_TYPE_CRC32C   = 1 
  } ISCSI_DIGEST_TYPES;

  typedef ULONG ISCSI_LOGIN_OPTIONS_INFO_SPECIFIED,
	      *PISCSI_LOGIN_OPTIONS_INFO_SPECIFIED;
#define ISCSI_LOGIN_OPTIONS_HEADER_DIGEST            0x00000001
#define ISCSI_LOGIN_OPTIONS_DATA_DIGEST              0x00000002
#define ISCSI_LOGIN_OPTIONS_MAXIMUM_CONNECTIONS      0x00000004
#define ISCSI_LOGIN_OPTIONS_DEFAULT_TIME_2_WAIT      0x00000008
#define ISCSI_LOGIN_OPTIONS_DEFAULT_TIME_2_RETAIN    0x00000010
#define ISCSI_LOGIN_OPTIONS_USERNAME                 0x00000020
#define ISCSI_LOGIN_OPTIONS_PASSWORD                 0x00000040
#define ISCSI_LOGIN_OPTIONS_AUTH_TYPE                0x00000080

#define ISCSI_LOGIN_OPTIONS_VERSION                  0x00000000

  typedef ULONG ISCSI_LOGIN_FLAGS,
	      *PISCSI_LOGIN_FLAGS;

#define ISCSI_LOGIN_FLAG_REQUIRE_IPSEC               0x00000001
#define ISCSI_LOGIN_FLAG_MULTIPATH_ENABLED           0x00000002
#define ISCSI_LOGIN_FLAG_RESERVED1                   0x00000004
#define ISCSI_LOGIN_FLAG_ALLOW_PORTAL_HOPPING        0x00000008
#define ISCSI_LOGIN_FLAG_USE_RADIUS_RESPONSE         0x00000010
#define ISCSI_LOGIN_FLAG_USE_RADIUS_VERIFICATION     0x00000020

  typedef ULONGLONG ISCSI_SECURITY_FLAGS,
		  *PISCSI_SECURITY_FLAGS;

#define ISCSI_SECURITY_FLAG_VALID                    0x00000001
#define ISCSI_SECURITY_FLAG_IKE_IPSEC_ENABLED        0x00000002
#define ISCSI_SECURITY_FLAG_MAIN_MODE_ENABLED        0x00000004
#define ISCSI_SECURITY_FLAG_AGGRESSIVE_MODE_ENABLED  0x00000008
#define ISCSI_SECURITY_FLAG_PFS_ENABLED              0x00000010
#define ISCSI_SECURITY_FLAG_TRANSPORT_MODE_PREFERRED 0x00000020
#define ISCSI_SECURITY_FLAG_TUNNEL_MODE_PREFERRED    0x00000040


#define AddIScsiConnection __MINGW_NAME_AW(AddIScsiConnection)
#define AddIScsiSendTargetPortal __MINGW_NAME_AW(AddIScsiSendTargetPortal)
#define AddIScsiStaticTarget __MINGW_NAME_AW(AddIScsiStaticTarget)
#define RemoveIScsiStaticTarget __MINGW_NAME_AW(RemoveIScsiStaticTarget)
#define AddISNSServer __MINGW_NAME_AW(AddISNSServer)
#define AddPersistentiScsiDevice __MINGW_NAME_AW(AddPersistentiScsiDevice)
#define RemoveIScsiPersistentTarget __MINGW_NAME_AW(RemoveIScsiPersistentTarget)
#define RemovePersistentIScsiDevice __MINGW_NAME_AW(RemovePersistentIScsiDevice)
#define PERSISTENT_ISCSI_LOGIN_INFO __MINGW_NAME_AW(PERSISTENT_ISCSI_LOGIN_INFO)
#define AddRadiusServer __MINGW_NAME_AW(AddRadiusServer)
#define RemoveRadiusServer __MINGW_NAME_AW(RemoveRadiusServer)

#define MAX_ISCSI_PORTAL_NAME_LEN 256
#define MAX_ISCSI_PORTAL_ADDRESS_LEN 256
#define MAX_ISCSI_HBANAME_LEN 256

typedef enum _TARGET_INFORMATION_CLASS {
  ProtocolType,
  TargetAlias,
  DiscoveryMechanisms,
  PortalGroups,
  PersistentTargetMappings,
  InitiatorName,
  TargetFlags,
  LoginOptions 
} TARGET_INFORMATION_CLASS;

typedef enum _TARGETPROTOCOLTYPE {
  ISCSI_TCP_PROTOCOL_TYPE 
} TARGETPROTOCOLTYPE;

typedef enum _IKE_AUTHENTICATION_METHOD {
  IKE_AUTHENTICATION_PRESHARED_KEY_METHOD    = 1 
} IKE_AUTHENTICATION_METHOD, *PIKE_AUTHENTICATION_METHOD;

typedef struct _ISCSI_LOGIN_OPTIONS {
  ULONG                              Version;
  ISCSI_LOGIN_OPTIONS_INFO_SPECIFIED InformationSpecified;
  ISCSI_LOGIN_FLAGS                  LoginFlags;
  ISCSI_AUTH_TYPES                   AuthType;
  ISCSI_DIGEST_TYPES                 HeaderDigest;
  ISCSI_DIGEST_TYPES                 DataDigest;
  ULONG                              MaximumConnections;
  ULONG                              DefaultTime2Wait;
  ULONG                              DefaultTime2Retain;
  ULONG                              UsernameLength;
  ULONG                              PasswordLength;
  PUCHAR                             Username;
  PUCHAR                             Password;
} ISCSI_LOGIN_OPTIONS, *PISCSI_LOGIN_OPTIONS, *PSCSI_LOGIN_OPTIONS, *PISCI_LOGIN_OPTIONS;

typedef struct _ISCSI_TARGET_PORTALA {
  CHAR  SymbolicName[MAX_ISCSI_PORTAL_NAME_LEN];
  CHAR  Address[MAX_ISCSI_PORTAL_ADDRESS_LEN];
  USHORT Socket;
} ISCSI_TARGET_PORTALA, *PISCSI_TARGET_PORTALA;

typedef struct _ISCSI_TARGET_PORTALW {
  WCHAR  SymbolicName[MAX_ISCSI_PORTAL_NAME_LEN];
  WCHAR  Address[MAX_ISCSI_PORTAL_ADDRESS_LEN];
  USHORT Socket;
} ISCSI_TARGET_PORTALW, *PISCSI_TARGET_PORTALW;

typedef struct _ISCSI_TARGET_PORTAL_GROUPA {
  ULONG               Count;
  ISCSI_TARGET_PORTALA Portals[1];
} ISCSI_TARGET_PORTAL_GROUPA, *PISCSI_TARGET_PORTAL_GROUPA;

typedef struct _ISCSI_TARGET_PORTAL_GROUPW {
  ULONG               Count;
  ISCSI_TARGET_PORTALW Portals[1];
} ISCSI_TARGET_PORTAL_GROUPW, *PISCSI_TARGET_PORTAL_GROUPW;

typedef struct _ISCSI_LUN_LIST {
  ULONG     OSLUN;
  ULONGLONG TargetLUN;
} SCSI_LUN_LIST, *PSCSI_LUN_LIST;

typedef struct _ISCSI_UNIQUE_SESSION_ID {
  ULONGLONG AdapterUnique;
  ULONGLONG AdapterSpecific;
}
ISCSI_UNIQUE_SESSION_ID,    *PISCSI_UNIQUE_SESSION_ID,
ISCSI_UNIQUE_CONNECTION_ID, *PISCSI_UNIQUE_CONNECTION_ID;

typedef struct _ISCSI_TARGET_MAPPINGA {
  CHAR                    InitiatorName[MAX_ISCSI_HBANAME_LEN];
  CHAR                    TargetName[MAX_ISCSI_NAME_LEN];
  CHAR                    OSDeviceName[MAX_PATH];
  ISCSI_UNIQUE_SESSION_ID SessionId;
  ULONG                   OSBusNumber;
  ULONG                   OSTargetNumber;
  ULONG                   LUNCount;
  PSCSI_LUN_LIST          LUNList;
} ISCSI_TARGET_MAPPINGA, *PISCSI_TARGET_MAPPINGA;

typedef struct _ISCSI_TARGET_MAPPINGW {
  WCHAR                   InitiatorName[MAX_ISCSI_HBANAME_LEN];
  WCHAR                   TargetName[MAX_ISCSI_NAME_LEN];
  WCHAR                   OSDeviceName[MAX_PATH];
  ISCSI_UNIQUE_SESSION_ID SessionId;
  ULONG                   OSBusNumber;
  ULONG                   OSTargetNumber;
  ULONG                   LUNCount;
  PSCSI_LUN_LIST          LUNList;
} ISCSI_TARGET_MAPPINGW, *PISCSI_TARGET_MAPPINGW;

typedef struct _PERSISTENT_ISCSI_LOGIN_INFOA {
  CHAR                   TargetName[MAX_ISCSI_NAME_LEN];
  BOOLEAN                IsInformationalSession;
  CHAR                   InitiatorInstance[MAX_ISCSI_HBANAME_LEN];
  ULONG                  InitiatorPortNumber;
  ISCSI_TARGET_PORTALA   TargetPortal;
  ISCSI_SECURITY_FLAGS   SecurityFlags;
  PISCSI_TARGET_MAPPINGA Mappings;
  ISCSI_LOGIN_OPTIONS    LoginOptions;
} PERSISTENT_ISCSI_LOGIN_INFOA, *PPERSISTENT_ISCSI_LOGIN_INFOA;

typedef struct _PERSISTENT_ISCSI_LOGIN_INFOW {
  CHAR                   TargetName[MAX_ISCSI_NAME_LEN];
  BOOLEAN                IsInformationalSession;
  CHAR                   InitiatorInstance[MAX_ISCSI_HBANAME_LEN];
  ULONG                  InitiatorPortNumber;
  ISCSI_TARGET_PORTALW   TargetPortal;
  ISCSI_SECURITY_FLAGS   SecurityFlags;
  PISCSI_TARGET_MAPPINGW Mappings;
  ISCSI_LOGIN_OPTIONS    LoginOptions;
} PERSISTENT_ISCSI_LOGIN_INFOW, *PPERSISTENT_ISCSI_LOGIN_INFOW;

typedef UCHAR IKE_IDENTIFICATION_PAYLOAD_TYPE, *PIKE_IDENTIFICATION_PAYLOAD_TYPE;

typedef struct _IKE_AUTHENTICATION_PRESHARED_KEY {
  ISCSI_SECURITY_FLAGS            SecurityFlags;
  IKE_IDENTIFICATION_PAYLOAD_TYPE IdType;
  ULONG                           IdLengthInBytes;
  PUCHAR                          Id;
  ULONG                           KeyLengthInBytes;
  PUCHAR                          Key;
} IKE_AUTHENTICATION_PRESHARED_KEY, *PIKE_AUTHENTICATION_PRESHARED_KEY;

typedef struct _IKE_AUTHENTICATION_INFORMATION {
  IKE_AUTHENTICATION_METHOD AuthMethod;
  __C89_NAMELESS union {
    IKE_AUTHENTICATION_PRESHARED_KEY PsKey;
  };
} IKE_AUTHENTICATION_INFORMATION, *PIKE_AUTHENTICATION_INFORMATION;

typedef struct _ISCSI_CONNECTION_INFOA {
  ISCSI_UNIQUE_CONNECTION_ID ConnectionId;
  CHAR                       InitiatorAddress;
  CHAR                       TargetAddress;
  USHORT                     InitiatorSocket;
  USHORT                     TargetSocket;
  UCHAR                      CID[2];
} ISCSI_CONNECTION_INFOA, *PISCSI_CONNECTION_INFOA;

typedef struct _ISCSI_CONNECTION_INFO {
  ISCSI_UNIQUE_CONNECTION_ID ConnectionId;
  TCHAR                      InitiatorAddress;
  TCHAR                      TargetAddress;
  USHORT                     InitiatorSocket;
  USHORT                     TargetSocket;
  UCHAR                      CID[2];
} ISCSI_CONNECTION_INFOW, *PISCSI_CONNECTION_INFOW;

typedef struct _ISCSI_SESSION_INFOA {
  ISCSI_UNIQUE_SESSION_ID SessionId;
  CHAR                    InitiatorName;
  CHAR                    TargetName;
  CHAR                    TargetNodeName;
  UCHAR                   ISID[6];
  UCHAR                   TSID[2];
  ULONG                   ConnectionCount;
  PISCSI_CONNECTION_INFOA Connections;
} ISCSI_SESSION_INFOA, *PISCSI_SESSION_INFOA;

typedef struct _ISCSI_SESSION_INFO {
  ISCSI_UNIQUE_SESSION_ID SessionId;
  WCHAR                   InitiatorName;
  WCHAR                   TargetName;
  WCHAR                   TargetNodeName;
  UCHAR                   ISID[6];
  UCHAR                   TSID[2];
  ULONG                   ConnectionCount;
  PISCSI_CONNECTION_INFOW Connections;
} ISCSI_SESSION_INFOW, *PISCSI_SESSION_INFOW;

typedef struct _ISCSI_VERSION_INFO {
  ULONG MajorVersion;
  ULONG MinorVersion;
  ULONG BuildNumber;
} ISCSI_VERSION_INFO, *PISCSI_VERSION_INFO;

typedef struct _ISCSI_TARGET_PORTAL_INFOA {
  CHAR   InitiatorName[MAX_ISCSI_HBANAME_LEN];
  ULONG  InitiatorPortNumber;
  CHAR   SymbolicName[MAX_ISCSI_PORTAL_NAME_LEN];
  CHAR   Address[MAX_ISCSI_PORTAL_ADDRESS_LEN];
  USHORT Socket;
} ISCSI_TARGET_PORTAL_INFOA, *PISCSI_TARGET_PORTAL_INFOA;

typedef struct _ISCSI_TARGET_PORTAL_INFOW {
  WCHAR  InitiatorName[MAX_ISCSI_HBANAME_LEN];
  ULONG  InitiatorPortNumber;
  WCHAR  SymbolicName[MAX_ISCSI_PORTAL_NAME_LEN];
  WCHAR  Address[MAX_ISCSI_PORTAL_ADDRESS_LEN];
  USHORT Socket;
} ISCSI_TARGET_PORTAL_INFOW, *PISCSI_TARGET_PORTAL_INFOW;

typedef struct _ISCSI_TARGET_PORTAL_INFO_EXA {
  CHAR   InitiatorName[MAX_ISCSI_HBANAME_LEN];
  ULONG  InitiatorPortNumber;
  CHAR   SymbolicName[MAX_ISCSI_PORTAL_NAME_LEN];
  CHAR   Address[MAX_ISCSI_PORTAL_ADDRESS_LEN];
  USHORT Socket;
  ISCSI_SECURITY_FLAGS SecurityFlags;
  ISCSI_LOGIN_OPTIONS  LoginOptions;
} ISCSI_TARGET_PORTAL_INFO_EX, *PISCSI_TARGET_PORTAL_INFO_EX;

typedef struct _ISCSI_TARGET_PORTAL_INFO_EXW {
  WCHAR  InitiatorName[MAX_ISCSI_HBANAME_LEN];
  ULONG  InitiatorPortNumber;
  WCHAR  SymbolicName[MAX_ISCSI_PORTAL_NAME_LEN];
  WCHAR  Address[MAX_ISCSI_PORTAL_ADDRESS_LEN];
  USHORT Socket;
  ISCSI_SECURITY_FLAGS SecurityFlags;
  ISCSI_LOGIN_OPTIONS  LoginOptions;
} ISCSI_TARGET_PORTAL_INFO_EX, *PISCSI_TARGET_PORTAL_INFO_EX;

__MINGW_TYPEDEF_AW(ISCSI_CONNECTION_INFO)
__MINGW_TYPEDEF_AW(PISCSI_CONNECTION_INFO)
__MINGW_TYPEDEF_AW(ISCSI_SESSION_INFO)
__MINGW_TYPEDEF_AW(PISCSI_SESSION_INFO)
__MINGW_TYPEDEF_AW(ISCSI_TARGET_PORTAL_GROUP)
__MINGW_TYPEDEF_AW(PISCSI_TARGET_PORTAL_GROUP)
__MINGW_TYPEDEF_AW(ISCSI_TARGET_PORTAL)
__MINGW_TYPEDEF_AW(PISCSI_TARGET_PORTAL)
__MINGW_TYPEDEF_AW(ISCSI_TARGET_MAPPING)
__MINGW_TYPEDEF_AW(PISCSI_TARGET_MAPPING)
__MINGW_TYPEDEF_AW(ISCSI_TARGET_PORTAL_INFO)
__MINGW_TYPEDEF_AW(PISCSI_TARGET_PORTAL_INFO)
__MINGW_TYPEDEF_AW(ISCSI_TARGET_PORTAL_INFO_EX)
__MINGW_TYPEDEF_AW(PISCSI_TARGET_PORTAL_INFO_EX)

typedef ULONG ISCSI_TARGET_FLAGS;

  HRESULT WINAPI AddIScsiConnectionA(PISCSI_UNIQUE_SESSION_ID UniqueSessionId,PVOID Reserved,ULONG InitiatorPortNumber,PISCSI_TARGET_PORTALA TargetPortal,ISCSI_SECURITY_FLAGS SecurityFlags,PSCSI_LOGIN_OPTIONS LoginOptions,ULONG KeySize,PCHAR Key,PISCSI_UNIQUE_CONNECTION_ID ConnectionId);
  HRESULT WINAPI AddIScsiConnectionW(PISCSI_UNIQUE_SESSION_ID UniqueSessionId,PVOID Reserved,ULONG InitiatorPortNumber,PISCSI_TARGET_PORTALW TargetPortal,ISCSI_SECURITY_FLAGS SecurityFlags,PSCSI_LOGIN_OPTIONS LoginOptions,ULONG KeySize,PCHAR Key,PISCSI_UNIQUE_CONNECTION_ID ConnectionId);

  HRESULT WINAPI AddIScsiSendTargetPortalA(PCHAR InitiatorName,ULONG InitiatorPortNumber,PISCI_LOGIN_OPTIONS LoginOptions,ISCSI_SECURITY_FLAGS SecurityFlags,PISCSI_TARGET_PORTALA Portal);

  HRESULT WINAPI AddIScsiSendTargetPortalW(PWCHAR InitiatorName,ULONG InitiatorPortNumber,PISCI_LOGIN_OPTIONS LoginOptions,ISCSI_SECURITY_FLAGS SecurityFlags,PISCSI_TARGET_PORTALW Portal);

  HRESULT WINAPI AddIScsiStaticTargetA(PCHAR TargetName,PCHAR TargetAlias,ISCSI_TARGET_FLAGS TargetFlags,BOOLEAN Persist,PISCSI_TARGET_MAPPINGA Mappings,PISCSI_LOGIN_OPTIONS LoginOptions,PISCSI_TARGET_PORTAL_GROUPA PortalGroup);

  HRESULT WINAPI AddIScsiStaticTargetW(PWCHAR TargetName,PWCHAR TargetAlias,ISCSI_TARGET_FLAGS TargetFlags,BOOLEAN Persist,PISCSI_TARGET_MAPPINGW Mappings,PISCSI_LOGIN_OPTIONS LoginOptions,PISCSI_TARGET_PORTAL_GROUPW PortalGroup);

  HRESULT WINAPI AddISNSServerA(PCHAR Address);
  HRESULT WINAPI AddISNSServerW(PWCHAR Address);

  HRESULT WINAPI AddRadiusServerA(PCHAR Address);
  HRESULT WINAPI AddRadiusServerW(PWCHAR Address);

  HRESULT WINAPI AddPersistentiScsiDeviceA(PCHAR VolumePath);
  HRESULT WINAPI AddPersistentiScsiDeviceW(PWCHAR VolumePath);

  HRESULT WINAPI ClearPersistentiScsiDevices(void);

  HRESULT WINAPI RemoveIScsiPersistentTargetA(PCHAR InitiatorInstance,ULONG InitiatorPortNumber,PCHAR TargetName,PISCSI_TARGET_PORTALA Portal);
  HRESULT WINAPI RemoveIScsiPersistentTargetW(PWCHAR InitiatorInstance,ULONG InitiatorPortNumber,PWCHAR TargetName,PISCSI_TARGET_PORTALW Portal);

  HRESULT WINAPI RemoveIScsiStaticTargetA(PCHAR TargetName);
  HRESULT WINAPI RemoveIScsiStaticTargetW(PWCHAR TargetName);

  HRESULT WINAPI RemovePersistentIScsiDeviceA(PCHAR VolumePath);
  HRESULT WINAPI RemovePersistentIScsiDeviceW(PWCHAR VolumePath);

  HRESULT WINAPI RemoveRadiusServerA(PCHAR Address);
  HRESULT WINAPI RemoveRadiusServerW(PWCHAR Address);

  HRESULT WINAPI SetupPersistentIScsiDevices(void);

  HRESULT WINAPI SendScsiInquiry(PISCSI_UNIQUE_SESSION_ID *UniqueSessionId,ULONGLONG Lun,UCHAR EvpdCmddt,UCHAR PageCode,PUCHAR *ScsiStatus,PULONG *ReponseSize,PUCHAR ReponseBuffer,PULONG *SenseSize,PUCHAR SenseBuffer);

  HRESULT WINAPI SendScsiReadCapacity(PISCSI_UNIQUE_SESSION_ID UniqueSessionId,ULONGLONG Lun,PUCHAR *ScsiStatus,PULONG *ResponseSize,PUCHAR ResponseBuffer,PULONG *SenseSize,PUCHAR SenseBuffer);

  HRESULT WINAPI SendScsiReportLuns(PISCSI_UNIQUE_SESSION_ID UniqueSessionId,PUCHAR *ScsiStatus,PULONG *ResponseSize,PUCHAR ResponseBuffer,PULONG *SenseSize,PUCHAR SenseBuffer);

typedef struct _ISCSI_DEVICE_ON_SESSION {
  TCHAR                 InitiatorName[MAX_ISCSI_HBANAME_LEN];
  TCHAR                 TargetName[MAX_ISCSI_NAME_LEN + 1];
  SCSI_ADDRESS          ScsiAddress;
  GUID                  DeviceInterfaceType;
  TCHAR                 DeviceInterfaceName[MAX_PATH];
  TCHAR                 LegacyName[MAX_PATH];
  STORAGE_DEVICE_NUMBER StorageDeviceNumber;
  DWORD                 DeviceInstance;
} ISCSI_DEVICE_ON_SESSION, *PISCSI_DEVICE_ON_SESSION;

HRESULT WINAPI GetDevicesForiSCSISession(
  PISCSI_UNIQUE_SESSION_ID UniqueSessionId,
  ULONG *DeviceCount,
  PISCSI_DEVICE_ON_SESSION Devices
);

#define GetIScsiIKEInfo __MINGW_NAME_AW(GetIScsiIKEInfo)

HRESULT WINAPI GetIScsiIKEInfoA(
  PCHAR InitiatorName,
  ULONG PortNumber,
  PULONG Reserved,
  PIKE_AUTHENTICATION_INFORMATION *AuthInfo
);

HRESULT WINAPI GetIScsiIKEInfoW(
  PWCHAR InitiatorName,
  ULONG PortNumber,
  PULONG Reserved,
  PIKE_AUTHENTICATION_INFORMATION *AuthInfo
);

#define GetIScsiInitiatorNodeName __MINGW_NAME_AW(GetIScsiInitiatorNodeName)

HRESULT WINAPI GetIScsiInitiatorNodeNameA(
    PCHAR InitiatorNodeName
);

HRESULT WINAPI GetIScsiInitiatorNodeNameW(
    PWCHAR InitiatorNodeName
);

#define GetIScsiSessionList __MINGW_NAME_AW(GetIScsiSessionList)

HRESULT WINAPI GetIScsiSessionListA(
  ULONG *BufferSize,
  ULONG *SessionCount,
  PISCSI_SESSION_INFOA SessionInfo
);

HRESULT WINAPI GetIScsiSessionListW(
  ULONG *BufferSize,
  ULONG *SessionCount,
  PISCSI_SESSION_INFOW SessionInfo
);

#define GetIScsiTargetInformation __MINGW_NAME_AW(GetIScsiTargetInformation)

HRESULT WINAPI GetIScsiTargetInformationA(
  PCHAR  TargetName,
  PCHAR  DiscoveryMechanism,
  TARGET_INFORMATION_CLASS InfoClass,
  PULONG BufferSize,
  PVOID Buffer
);

HRESULT WINAPI GetIScsiTargetInformationW(
  PWCHAR TargetName,
  PWCHAR DiscoveryMechanism,
  TARGET_INFORMATION_CLASS InfoClass,
  PULONG BufferSize,
  PVOID Buffer
);

HRESULT WINAPI GetIScsiVersionInformation(
    PISCSI_VERSION_INFO VersionInfo
);

HRESULT WINAPI LoginIScsiTargetA(
  PCHAR TargetName,
  BOOLEAN IsInformationalSession,
  PCHAR InitiatorName,
  ULONG InitiatorPortNumber,
  PISCSI_TARGET_PORTALA TargetPortal,
  ISCSI_SECURITY_FLAGS SecurityFlags,
  PISCSI_TARGET_MAPPINGA Mappings,
  PISCSI_LOGIN_OPTIONS LoginOptions,
  ULONG KeySize,
  PCHAR Key,
  BOOLEAN IsPersistent,
  PISCSI_UNIQUE_SESSION_ID UniqueSessionId,
  PISCSI_UNIQUE_CONNECTION_ID UniqueConnectionId
);

HRESULT WINAPI LoginIScsiTargetW(
  PWCHAR TargetName,
  BOOLEAN IsInformationalSession,
  PWCHAR InitiatorName,
  ULONG InitiatorPortNumber,
  PISCSI_TARGET_PORTALW TargetPortal,
  ISCSI_SECURITY_FLAGS SecurityFlags,
  PISCSI_TARGET_MAPPINGW Mappings,
  PISCSI_LOGIN_OPTIONS LoginOptions,
  ULONG KeySize,
  PCHAR Key,
  BOOLEAN IsPersistent,
  PISCSI_UNIQUE_SESSION_ID UniqueSessionId,
  PISCSI_UNIQUE_CONNECTION_ID UniqueConnectionId
);

HRESULT WINAPI LogoutIScsiTarget(
  PISCSI_UNIQUE_SESSION_ID UniqueSessionId
);

HRESULT WINAPI RefreshIScsiSendTargetPortalA(
  PCHAR InitiatorInstance,
  ULONG InitiatorPortNumber,
  PISCSI_TARGET_PORTALA Portal
);

HRESULT WINAPI RefreshIScsiSendTargetPortalW(
  PWCHAR InitiatorInstance,
  ULONG InitiatorPortNumber,
  PISCSI_TARGET_PORTALW Portal
);

#define RefreshIScsiSendTargetPortal __MINGW_NAME_AW(RefreshIScsiSendTargetPortal)

HRESULT WINAPI RefreshISNSServerA(
  PCHAR Address
);

HRESULT WINAPI RefreshISNSServerW(
  PWCHAR Address
);

#define RefreshISNSServer __MINGW_NAME_AW(RefreshISNSServer)

HRESULT WINAPI RemoveIScsiConnection(
  PISCSI_UNIQUE_SESSION_ID UniqueSessionId,
  PISCSI_UNIQUE_CONNECTION_ID UniqueConnectionId
);

HRESULT WINAPI RemoveIScsiPersistentTargetA(
  PCHAR InitiatorInstance,
  ULONG InitiatorPortNumber,
  PCHAR TargetName,
  PISCSI_TARGET_PORTALA Portal
);

HRESULT WINAPI RemoveIScsiPersistentTargetW(
  PWCHAR InitiatorInstance,
  ULONG InitiatorPortNumber,
  PWCHAR TargetName,
  PISCSI_TARGET_PORTALW Portal
);

#define RemoveIScsiPersistentTarget __MINGW_NAME_AW(RemoveIScsiPersistentTarget)

HRESULT WINAPI RemoveIScsiSendTargetPortalA(
  PCHAR InitiatorInstance,
  ULONG InitiatorPortNumber,
  PISCSI_TARGET_PORTALA Portal
);

HRESULT WINAPI RemoveIScsiSendTargetPortalW(
  PWCHAR InitiatorInstance,
  ULONG InitiatorPortNumber,
  PISCSI_TARGET_PORTALW Portal
);

#define RemoveIScsiSendTargetPortal __MINGW_NAME_AW(RemoveIScsiSendTargetPortal)

HRESULT WINAPI RemoveIScsiStaticTargetA(
  PCHAR TargetName
);

HRESULT WINAPI RemoveIScsiStaticTargetW(
  PWCHAR TargetName
);
#define RemoveIScsiStaticTarget __MINGW_NAME_AW(RemoveIScsiStaticTarget)

HRESULT WINAPI RemoveISNSServerA(
  PCHAR Address
);

HRESULT WINAPI RemoveISNSServerW(
  PWCHAR Address
);
#define RemoveISNSServer __MINGW_NAME_AW(RemoveISNSServer)

HRESULT WINAPI RemovePersistentIScsiDeviceA(
  PCHAR VolumePath
);

HRESULT WINAPI RemovePersistentIScsiDeviceW(
  PWCHAR VolumePath
);
#define RemovePersistentIScsiDevice __MINGW_NAME_AW(RemovePersistentIScsiDevice)

HRESULT WINAPI RemoveRadiusServerA(
  PCHAR Address
);

HRESULT WINAPI RemoveRadiusServerW(
  PWCHAR Address
);
#define RemoveRadiusServer __MINGW_NAME_AW(RemoveRadiusServer)

HRESULT WINAPI ReportIScsiInitiatorListA(
  ULONG *BufferSize,
  PCHAR Buffer
);

HRESULT WINAPI ReportIScsiInitiatorListW(
  ULONG *BufferSize,
  PWCHAR Buffer
);

HRESULT WINAPI ReportIScsiPersistentLoginsA(
  ULONG *Count,
  PPERSISTENT_ISCSI_LOGIN_INFOA PersistentLoginInfo,
  PULONG BufferSizeInBytes
);

HRESULT WINAPI ReportIScsiPersistentLoginsW(
  ULONG *Count,
  PPERSISTENT_ISCSI_LOGIN_INFOW PersistentLoginInfo,
  PULONG BufferSizeInBytes
);
#define ReportIScsiPersistentLogins __MINGW_NAME_AW(ReportIScsiPersistentLogins)

HRESULT WINAPI ReportIScsiSendTargetPortalsA(
  PULONG PortalCount,
  PISCSI_TARGET_PORTAL_INFOA PortalInfo
);

HRESULT WINAPI ReportIScsiSendTargetPortalsW(
  PULONG PortalCount,
  PISCSI_TARGET_PORTAL_INFOA PortalInfo
);

#define ReportIScsiSendTargetPortals __MINGW_NAME_AW(ReportIScsiSendTargetPortals)

HRESULT WINAPI ReportActiveIScsiTargetMappingsA(
  PULONG BufferSize,
  PULONG MappingCount,
  PISCSI_TARGET_MAPPINGA Mappings
);

HRESULT WINAPI ReportActiveIScsiTargetMappingsW(
  PULONG BufferSize,
  PULONG MappingCount,
  PISCSI_TARGET_MAPPINGW Mappings
);
#define ReportActiveIScsiTargetMappings __MINGW_NAME_AW(ReportActiveIScsiTargetMappings)

HRESULT WINAPI ReportIScsiSendTargetPortalsExA(
  PULONG PortalCount,
  PULONG PortalInfoSize,
  PISCSI_TARGET_PORTAL_INFO_EXA PortalInfo
);

HRESULT WINAPI ReportIScsiSendTargetPortalsExW(
  PULONG PortalCount,
  PULONG PortalInfoSize,
  PISCSI_TARGET_PORTAL_INFO_EXW PortalInfo
);

#define ReportIScsiSendTargetPortalsEx __MINGW_NAME_AW(ReportIScsiSendTargetPortalsEx)

HRESULT WINAPI ReportIScsiTargetPortalsA(
  PCHAR  InitiatorName,
  PCHAR  TargetName,
  PUSHORT TargetPortalTag,
  PULONG ElementCount,
  PISCSI_TARGET_PORTALA Portals
);

HRESULT WINAPI ReportIScsiTargetPortalsW(
  PWCHAR InitiatorName,
  PWCHAR TargetName,
  PUSHORT TargetPortalTag,
  PULONG ElementCount,
  PISCSI_TARGET_PORTALW Portals
);

#define ReportIScsiTargetPortals __MINGW_NAME_AW(ReportIScsiTargetPortals)

HRESULT WINAPI ReportIScsiTargetsA(
  BOOLEAN ForceUpdate,
  PULONG BufferSize,
  PCHAR  Buffer
);

HRESULT WINAPI ReportIScsiTargetsW(
  BOOLEAN ForceUpdate,
  PULONG BufferSize,
  PWCHAR Buffer
);
#define ReportIScsiTargets __MINGW_NAME_AW(ReportIScsiTargets)

HRESULT WINAPI ReportISNSServerListA(
  PULONG BufferSizeInChar,
  PCHAR  Buffer
);

HRESULT WINAPI ReportISNSServerListW(
  PULONG BufferSizeInChar,
  PWCHAR Buffer
);

#define ReportISNSServerList __MINGW_NAME_AW(ReportISNSServerList)

HRESULT WINAPI ReportPersistentiScsiDevicesA(
  PULONG BufferSizeInChar,
  PCHAR  Buffer
);

HRESULT WINAPI ReportPersistentiScsiDevicesW(
  PULONG BufferSizeInChar,
  PWCHAR Buffer
);

#define ReportPersistentiScsiDevices __MINGW_NAME_AW(ReportPersistentiScsiDevices)

HRESULT WINAPI ReportRadiusServerListA(
  PULONG BufferSizeInChar,
  PCHAR  Buffer
);

HRESULT WINAPI ReportRadiusServerListW(
  PULONG BufferSizeInChar,
  PCHAR  Buffer
);
#define ReportRadiusServerList __MINGW_NAME_AW(ReportRadiusServerList)

HRESULT WINAPI SendScsiReadCapacity(
  PISCSI_UNIQUE_SESSION_ID UniqueSessionId,
  ULONGLONG Lun,
  PUCHAR *ScsiStatus,
  PULONG *ResponseSize,
  PUCHAR ResponseBuffer,
  PULONG *SenseSize,
  PUCHAR SenseBuffer
);

HRESULT WINAPI SendScsiReportLuns(
  PISCSI_UNIQUE_SESSION_ID UniqueSessionId,
  PUCHAR *ScsiStatus,
  PULONG *ResponseSize,
  PUCHAR ResponseBuffer,
  PULONG *SenseSize,
  PUCHAR SenseBuffer
);

HRESULT WINAPI SendScsiInquiry(
  PISCSI_UNIQUE_SESSION_ID *UniqueSessionId,
  ULONGLONG Lun,
  UCHAR EvpdCmddt,
  UCHAR PageCode,
  PUCHAR *ScsiStatus,
  PULONG *ReponseSize,
  PUCHAR ReponseBuffer,
  PULONG *SenseSize,
  PUCHAR SenseBuffer
);

HRESULT WINAPI SetIScsiGroupPresharedKey(
  ULONG KeyLength,
  PUCHAR Key,
  BOOLEAN Persist
);

HRESULT WINAPI SetIScsiInitiatorCHAPSharedSecret(
  ULONG SharedSecretLength,
  PUCHAR SharedSecret
);

HRESULT WINAPI SetIScsiInitiatorNodeNameA(
  PCHAR InitiatorNodeName
);

HRESULT WINAPI SetIScsiInitiatorNodeNameW(
  PWCHAR InitiatorNodeName
);

#define SetIScsiInitiatorNodeName __MINGW_NAME_AW(SetIScsiInitiatorNodeName)

HRESULT WINAPI SetIscsiInitiatorRADIUSSharedSecret(
  ULONG SharedSecretLength,
  PUCHAR SharedSecret
);

HRESULT WINAPI SetIScsiTunnelModeOuterAddressA(
  PCHAR InitiatorName,
  ULONG InitiatorPortNumber,
  PCHAR DestinationAddress,
  PCHAR OuterModeAddress,
  BOOLEAN Persist
);

HRESULT WINAPI SetIScsiTunnelModeOuterAddressW(
  PWCHAR InitiatorName,
  ULONG  InitiatorPortNumber,
  PWCHAR DestinationAddress,
  PWCHAR OuterModeAddress,
  BOOLEAN Persist
);

#define SetIScsiTunnelModeOuterAddress __MINGW_NAME_AW(SetIScsiTunnelModeOuterAddress)

HRESULT WINAPI SetupPersistentIScsiDevices(void);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif
