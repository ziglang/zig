/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WTSAPI
#define _INC_WTSAPI

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#define WTS_CURRENT_SERVER ((HANDLE)NULL)
#define WTS_CURRENT_SERVER_HANDLE ((HANDLE)NULL)
#define WTS_CURRENT_SERVER_NAME (NULL)

#define WTS_CURRENT_SESSION ((DWORD)-1)
#define WTS_ANY_SESSION ((DWORD)-2)

#ifndef IDTIMEOUT
#define IDTIMEOUT 32000
#endif
#ifndef IDASYNC
#define IDASYNC 32001
#endif

#define USERNAME_LENGTH         20
#define CLIENTNAME_LENGTH       20
#define CLIENTADDRESS_LENGTH    30
#define WINSTATIONNAME_LENGTH   32
#define DOMAIN_LENGTH           17

#define WTS_WSD_LOGOFF 0x1
#define WTS_WSD_SHUTDOWN 0x2
#define WTS_WSD_REBOOT 0x4
#define WTS_WSD_POWEROFF 0x8

#define WTS_WSD_FASTREBOOT 0x10

#define MAX_ELAPSED_TIME_LENGTH 15
#define MAX_DATE_TIME_LENGTH 56
#define WINSTATIONNAME_LENGTH 32
#define DOMAIN_LENGTH 17

#define WTS_DRIVE_LENGTH 3
#define WTS_LISTENER_NAME_LENGTH 32
#define WTS_COMMENT_LENGTH 60

#define WTS_LISTENER_CREATE 0x00000001
#define WTS_LISTENER_UPDATE 0x00000010

#define WTS_SECURITY_QUERY_INFORMATION 0x00000001
#define WTS_SECURITY_SET_INFORMATION 0x00000002
#define WTS_SECURITY_RESET 0x00000004
#define WTS_SECURITY_VIRTUAL_CHANNELS 0x00000008
#define WTS_SECURITY_REMOTE_CONTROL 0x00000010
#define WTS_SECURITY_LOGON 0x00000020
#define WTS_SECURITY_LOGOFF 0x00000040
#define WTS_SECURITY_MESSAGE 0x00000080
#define WTS_SECURITY_CONNECT 0x00000100
#define WTS_SECURITY_DISCONNECT 0x00000200

#define WTS_SECURITY_GUEST_ACCESS (WTS_SECURITY_LOGON)

#define WTS_SECURITY_CURRENT_GUEST_ACCESS (WTS_SECURITY_VIRTUAL_CHANNELS | WTS_SECURITY_LOGOFF)

#define WTS_SECURITY_USER_ACCESS (WTS_SECURITY_CURRENT_GUEST_ACCESS | WTS_SECURITY_QUERY_INFORMATION | WTS_SECURITY_CONNECT)

#define WTS_SECURITY_CURRENT_USER_ACCESS (WTS_SECURITY_SET_INFORMATION | WTS_SECURITY_RESET | WTS_SECURITY_VIRTUAL_CHANNELS | WTS_SECURITY_LOGOFF | WTS_SECURITY_DISCONNECT)

#define WTS_SECURITY_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | WTS_SECURITY_QUERY_INFORMATION | WTS_SECURITY_SET_INFORMATION | WTS_SECURITY_RESET | WTS_SECURITY_VIRTUAL_CHANNELS | WTS_SECURITY_REMOTE_CONTROL | WTS_SECURITY_LOGON | WTS_SECURITY_MESSAGE | WTS_SECURITY_CONNECT | WTS_SECURITY_DISCONNECT)

  typedef enum _WTS_CONNECTSTATE_CLASS {
    WTSActive,WTSConnected,WTSConnectQuery,WTSShadow,WTSDisconnected,WTSIdle,WTSListen,WTSReset,WTSDown,WTSInit
  } WTS_CONNECTSTATE_CLASS;

  typedef struct _WTS_SERVER_INFOW {
    LPWSTR pServerName;
  } WTS_SERVER_INFOW,*PWTS_SERVER_INFOW;

  typedef struct _WTS_SERVER_INFOA {
    LPSTR pServerName;
  } WTS_SERVER_INFOA,*PWTS_SERVER_INFOA;

#define WTS_SERVER_INFO __MINGW_NAME_AW(WTS_SERVER_INFO)
#define PWTS_SERVER_INFO __MINGW_NAME_AW(PWTS_SERVER_INFO)

  typedef struct _WTS_SESSION_INFOW {
    DWORD SessionId;
    LPWSTR pWinStationName;
    WTS_CONNECTSTATE_CLASS State;
  } WTS_SESSION_INFOW,*PWTS_SESSION_INFOW;

  typedef struct _WTS_SESSION_INFOA {
    DWORD SessionId;
    LPSTR pWinStationName;
    WTS_CONNECTSTATE_CLASS State;
  } WTS_SESSION_INFOA,*PWTS_SESSION_INFOA;

#define WTS_SESSION_INFO __MINGW_NAME_AW(WTS_SESSION_INFO)
#define PWTS_SESSION_INFO __MINGW_NAME_AW(PWTS_SESSION_INFO)

  typedef struct _WTS_PROCESS_INFOW {
    DWORD SessionId;
    DWORD ProcessId;
    LPWSTR pProcessName;
    PSID pUserSid;
  } WTS_PROCESS_INFOW,*PWTS_PROCESS_INFOW;

  typedef struct _WTS_PROCESS_INFOA {
    DWORD SessionId;
    DWORD ProcessId;
    LPSTR pProcessName;
    PSID pUserSid;
  } WTS_PROCESS_INFOA,*PWTS_PROCESS_INFOA;

#define WTS_PROCESS_INFO __MINGW_NAME_AW(WTS_PROCESS_INFO)
#define PWTS_PROCESS_INFO __MINGW_NAME_AW(PWTS_PROCESS_INFO)

#define WTS_PROTOCOL_TYPE_CONSOLE 0
#define WTS_PROTOCOL_TYPE_ICA 1
#define WTS_PROTOCOL_TYPE_RDP 2

  typedef enum _WTS_INFO_CLASS {
    WTSInitialProgram       = 0,
    WTSApplicationName      = 1,
    WTSWorkingDirectory     = 2,
    WTSOEMId                = 3,
    WTSSessionId            = 4,
    WTSUserName             = 5,
    WTSWinStationName       = 6,
    WTSDomainName           = 7,
    WTSConnectState         = 8,
    WTSClientBuildNumber    = 9,
    WTSClientName           = 10,
    WTSClientDirectory      = 11,
    WTSClientProductId      = 12,
    WTSClientHardwareId     = 13,
    WTSClientAddress        = 14,
    WTSClientDisplay        = 15,
    WTSClientProtocolType   = 16,
    WTSIdleTime             = 17,
    WTSLogonTime            = 18,
    WTSIncomingBytes        = 19,
    WTSOutgoingBytes        = 20,
    WTSIncomingFrames       = 21,
    WTSOutgoingFrames       = 22,
    WTSClientInfo           = 23,
    WTSSessionInfo          = 24,
    WTSSessionInfoEx        = 25,
    WTSConfigInfo           = 26,
    WTSValidationInfo       = 27,
    WTSSessionAddressV4     = 28,
    WTSIsRemoteSession      = 29
  } WTS_INFO_CLASS;

  typedef struct _WTSCONFIGINFOW {
    ULONG version;
    ULONG fConnectClientDrivesAtLogon;
    ULONG fConnectPrinterAtLogon;
    ULONG fDisablePrinterRedirection;
    ULONG fDisableDefaultMainClientPrinter;
    ULONG ShadowSettings;
    WCHAR LogonUserName[USERNAME_LENGTH + 1 ];
    WCHAR LogonDomain[DOMAIN_LENGTH + 1 ];
    WCHAR WorkDirectory[MAX_PATH + 1 ];
    WCHAR InitialProgram[MAX_PATH + 1 ];
    WCHAR ApplicationName[MAX_PATH + 1 ];
  } WTSCONFIGINFOW, *PWTSCONFIGINFOW;

  typedef struct _WTSCONFIGINFOA {
    ULONG version;
    ULONG fConnectClientDrivesAtLogon;
    ULONG fConnectPrinterAtLogon;
    ULONG fDisablePrinterRedirection;
    ULONG fDisableDefaultMainClientPrinter;
    ULONG ShadowSettings;
    CHAR LogonUserName[USERNAME_LENGTH + 1 ];
    CHAR LogonDomain[DOMAIN_LENGTH + 1 ];
    CHAR WorkDirectory[MAX_PATH + 1 ];
    CHAR InitialProgram[MAX_PATH + 1 ];
    CHAR ApplicationName[MAX_PATH + 1 ];
  } WTSCONFIGINFOA, *PWTSCONFIGINFOA;

__MINGW_TYPEDEF_AW(WTSCONFIGINFO)
__MINGW_TYPEDEF_AW(PWTSCONFIGINFO)

  typedef struct _WTS_CLIENT_ADDRESS {
    DWORD AddressFamily;
    BYTE Address[20];
  } WTS_CLIENT_ADDRESS,*PWTS_CLIENT_ADDRESS;

  typedef struct _WTS_CLIENT_DISPLAY {
    DWORD HorizontalResolution;
    DWORD VerticalResolution;
    DWORD ColorDepth;
  } WTS_CLIENT_DISPLAY,*PWTS_CLIENT_DISPLAY;

  typedef enum _WTS_CONFIG_CLASS {
    WTSUserConfigInitialProgram,WTSUserConfigWorkingDirectory,WTSUserConfigfInheritInitialProgram,WTSUserConfigfAllowLogonTerminalServer,
    WTSUserConfigTimeoutSettingsConnections,WTSUserConfigTimeoutSettingsDisconnections,WTSUserConfigTimeoutSettingsIdle,
    WTSUserConfigfDeviceClientDrives,WTSUserConfigfDeviceClientPrinters,WTSUserConfigfDeviceClientDefaultPrinter,WTSUserConfigBrokenTimeoutSettings,
    WTSUserConfigReconnectSettings,WTSUserConfigModemCallbackSettings,WTSUserConfigModemCallbackPhoneNumber,WTSUserConfigShadowingSettings,
    WTSUserConfigTerminalServerProfilePath,WTSUserConfigTerminalServerHomeDir,WTSUserConfigTerminalServerHomeDirDrive,
    WTSUserConfigfTerminalServerRemoteHomeDir,WTSUserConfigUser
  } WTS_CONFIG_CLASS;

  typedef enum _WTS_CONFIG_SOURCE {
    WTSUserConfigSourceSAM
  } WTS_CONFIG_SOURCE;

  typedef struct _WTSUSERCONFIGA {
    DWORD Source;
    DWORD InheritInitialProgram;
    DWORD AllowLogonTerminalServer;
    DWORD TimeoutSettingsConnections;
    DWORD TimeoutSettingsDisconnections;
    DWORD TimeoutSettingsIdle;
    DWORD DeviceClientDrives;
    DWORD DeviceClientPrinters;
    DWORD ClientDefaultPrinter;
    DWORD BrokenTimeoutSettings;
    DWORD ReconnectSettings;
    DWORD ShadowingSettings;
    DWORD TerminalServerRemoteHomeDir;
    CHAR InitialProgram[ MAX_PATH + 1 ];
    CHAR WorkDirectory[ MAX_PATH + 1 ];
    CHAR TerminalServerProfilePath[ MAX_PATH + 1 ];
    CHAR TerminalServerHomeDir[ MAX_PATH + 1 ];
    CHAR TerminalServerHomeDirDrive[ WTS_DRIVE_LENGTH + 1 ];
  } WTSUSERCONFIGA, *PWTSUSERCONFIGA;

  typedef struct _WTSUSERCONFIGW {
    DWORD Source;
    DWORD InheritInitialProgram;
    DWORD AllowLogonTerminalServer;
    DWORD TimeoutSettingsConnections;
    DWORD TimeoutSettingsDisconnections;
    DWORD TimeoutSettingsIdle;
    DWORD DeviceClientDrives;
    DWORD DeviceClientPrinters;
    DWORD ClientDefaultPrinter;
    DWORD BrokenTimeoutSettings;
    DWORD ReconnectSettings;
    DWORD ShadowingSettings;
    DWORD TerminalServerRemoteHomeDir;
    WCHAR InitialProgram[ MAX_PATH + 1 ];
    WCHAR WorkDirectory[ MAX_PATH + 1 ];
    WCHAR TerminalServerProfilePath[ MAX_PATH + 1 ];
    WCHAR TerminalServerHomeDir[ MAX_PATH + 1 ];
    WCHAR TerminalServerHomeDirDrive[ WTS_DRIVE_LENGTH + 1 ];
  } WTSUSERCONFIGW, *PWTSUSERCONFIGW;

__MINGW_TYPEDEF_AW(WTSUSERCONFIG)
__MINGW_TYPEDEF_AW(PWTSUSERCONFIG)

#define WTS_EVENT_NONE 0x0
#define WTS_EVENT_CREATE 0x1
#define WTS_EVENT_DELETE 0x2
#define WTS_EVENT_RENAME 0x4
#define WTS_EVENT_CONNECT 0x8
#define WTS_EVENT_DISCONNECT 0x10
#define WTS_EVENT_LOGON 0x20
#define WTS_EVENT_LOGOFF 0x40
#define WTS_EVENT_STATECHANGE 0x80
#define WTS_EVENT_LICENSE 0x100
#define WTS_EVENT_ALL 0x7fffffff
#define WTS_EVENT_FLUSH 0x80000000

#define REMOTECONTROL_KBDSHIFT_HOTKEY 0x1
#define REMOTECONTROL_KBDCTRL_HOTKEY 0x2
#define REMOTECONTROL_KBDALT_HOTKEY 0x4

  typedef enum _WTS_VIRTUAL_CLASS {
    WTSVirtualClientData,WTSVirtualFileHandle
  } WTS_VIRTUAL_CLASS;

  typedef struct _WTS_SESSION_ADDRESS {
    DWORD AddressFamily;
    BYTE Address[20];
  } WTS_SESSION_ADDRESS, *PWTS_SESSION_ADDRESS;

#define WTSEnumerateServers __MINGW_NAME_AW(WTSEnumerateServers)
#define WTSOpenServer __MINGW_NAME_AW(WTSOpenServer)
#define WTSOpenServerEx __MINGW_NAME_AW(WTSOpenServerEx)
#define WTSEnumerateSessions __MINGW_NAME_AW(WTSEnumerateSessions)
#define WTSEnumerateProcesses __MINGW_NAME_AW(WTSEnumerateProcesses)
#define WTSQuerySessionInformation __MINGW_NAME_AW(WTSQuerySessionInformation)
#define WTSQueryUserConfig __MINGW_NAME_AW(WTSQueryUserConfig)
#define WTSSetUserConfig __MINGW_NAME_AW(WTSSetUserConfig)
#define WTSSendMessage __MINGW_NAME_AW(WTSSendMessage)

  WINBOOL WINAPI WTSEnumerateServersW(LPWSTR pDomainName,DWORD Reserved,DWORD Version,PWTS_SERVER_INFOW *ppServerInfo,DWORD *pCount);
  WINBOOL WINAPI WTSEnumerateServersA(LPSTR pDomainName,DWORD Reserved,DWORD Version,PWTS_SERVER_INFOA *ppServerInfo,DWORD *pCount);
  HANDLE WINAPI WTSOpenServerW(LPWSTR pServerName);
  HANDLE WINAPI WTSOpenServerA(LPSTR pServerName);
  HANDLE WINAPI WTSOpenServerExW(LPWSTR pServerName);
  HANDLE WINAPI WTSOpenServerExA(LPSTR pServerName);
  VOID WINAPI WTSCloseServer(HANDLE hServer);
  WINBOOL WINAPI WTSEnumerateSessionsW(HANDLE hServer,DWORD Reserved,DWORD Version,PWTS_SESSION_INFOW *ppSessionInfo,DWORD *pCount);
  WINBOOL WINAPI WTSEnumerateSessionsA(HANDLE hServer,DWORD Reserved,DWORD Version,PWTS_SESSION_INFOA *ppSessionInfo,DWORD *pCount);
  WINBOOL WINAPI WTSEnumerateProcessesW(HANDLE hServer,DWORD Reserved,DWORD Version,PWTS_PROCESS_INFOW *ppProcessInfo,DWORD *pCount);
  WINBOOL WINAPI WTSEnumerateProcessesA(HANDLE hServer,DWORD Reserved,DWORD Version,PWTS_PROCESS_INFOA *ppProcessInfo,DWORD *pCount);
  WINBOOL WINAPI WTSTerminateProcess(HANDLE hServer,DWORD ProcessId,DWORD ExitCode);
  WINBOOL WINAPI WTSQuerySessionInformationW(HANDLE hServer,DWORD SessionId,WTS_INFO_CLASS WTSInfoClass,LPWSTR *ppBuffer,DWORD *pBytesReturned);
  WINBOOL WINAPI WTSQuerySessionInformationA(HANDLE hServer,DWORD SessionId,WTS_INFO_CLASS WTSInfoClass,LPSTR *ppBuffer,DWORD *pBytesReturned);
  WINBOOL WINAPI WTSQueryUserConfigW(LPWSTR pServerName,LPWSTR pUserName,WTS_CONFIG_CLASS WTSConfigClass,LPWSTR *ppBuffer,DWORD *pBytesReturned);
  WINBOOL WINAPI WTSQueryUserConfigA(LPSTR pServerName,LPSTR pUserName,WTS_CONFIG_CLASS WTSConfigClass,LPSTR *ppBuffer,DWORD *pBytesReturned);
  WINBOOL WINAPI WTSSetUserConfigW(LPWSTR pServerName,LPWSTR pUserName,WTS_CONFIG_CLASS WTSConfigClass,LPWSTR pBuffer,DWORD DataLength);
  WINBOOL WINAPI WTSSetUserConfigA(LPSTR pServerName,LPSTR pUserName,WTS_CONFIG_CLASS WTSConfigClass,LPSTR pBuffer,DWORD DataLength);
  WINBOOL WINAPI WTSSendMessageW(HANDLE hServer,DWORD SessionId,LPWSTR pTitle,DWORD TitleLength,LPWSTR pMessage,DWORD MessageLength,DWORD Style,DWORD Timeout,DWORD *pResponse,WINBOOL bWait);
  WINBOOL WINAPI WTSSendMessageA(HANDLE hServer,DWORD SessionId,LPSTR pTitle,DWORD TitleLength,LPSTR pMessage,DWORD MessageLength,DWORD Style,DWORD Timeout,DWORD *pResponse,WINBOOL bWait);
  WINBOOL WINAPI WTSDisconnectSession(HANDLE hServer,DWORD SessionId,WINBOOL bWait);
  WINBOOL WINAPI WTSLogoffSession(HANDLE hServer,DWORD SessionId,WINBOOL bWait);
  WINBOOL WINAPI WTSShutdownSystem(HANDLE hServer,DWORD ShutdownFlag);
  WINBOOL WINAPI WTSWaitSystemEvent(HANDLE hServer,DWORD EventMask,DWORD *pEventFlags);
  HANDLE WINAPI WTSVirtualChannelOpen(HANDLE hServer,DWORD SessionId,LPSTR pVirtualName);
  WINBOOL WINAPI WTSVirtualChannelClose(HANDLE hChannelHandle);
  WINBOOL WINAPI WTSVirtualChannelRead(HANDLE hChannelHandle,ULONG TimeOut,PCHAR Buffer,ULONG BufferSize,PULONG pBytesRead);
  WINBOOL WINAPI WTSVirtualChannelWrite(HANDLE hChannelHandle,PCHAR Buffer,ULONG Length,PULONG pBytesWritten);
  WINBOOL WINAPI WTSVirtualChannelPurgeInput(HANDLE hChannelHandle);
  WINBOOL WINAPI WTSVirtualChannelPurgeOutput(HANDLE hChannelHandle);
  WINBOOL WINAPI WTSVirtualChannelQuery(HANDLE hChannelHandle,WTS_VIRTUAL_CLASS,PVOID *ppBuffer,DWORD *pBytesReturned);
  VOID WINAPI WTSFreeMemory(PVOID pMemory);

#define NOTIFY_FOR_ALL_SESSIONS 1
#define NOTIFY_FOR_THIS_SESSION 0

  WINBOOL WINAPI WTSRegisterSessionNotification(HWND hWnd,DWORD dwFlags);
  WINBOOL WINAPI WTSUnRegisterSessionNotification(HWND hWnd);
  WINBOOL WINAPI WTSQueryUserToken(ULONG SessionId,PHANDLE phToken);

#if (_WIN32_WINNT >= 0x0600)
typedef struct _WTSCLIENTW {
  WCHAR   ClientName[CLIENTNAME_LENGTH + 1];
  WCHAR   Domain[DOMAIN_LENGTH + 1 ];
  WCHAR   UserName[USERNAME_LENGTH + 1];
  WCHAR   WorkDirectory[MAX_PATH + 1];
  WCHAR   InitialProgram[MAX_PATH + 1];
  BYTE    EncryptionLevel;
  ULONG   ClientAddressFamily;
  USHORT  ClientAddress[CLIENTADDRESS_LENGTH + 1];
  USHORT  HRes;
  USHORT  VRes;
  USHORT  ColorDepth;
  WCHAR   ClientDirectory[MAX_PATH + 1];
  ULONG   ClientBuildNumber;
  ULONG   ClientHardwareId;
  USHORT  ClientProductId;
  USHORT  OutBufCountHost;
  USHORT  OutBufCountClient;
  USHORT  OutBufLength;
  WCHAR     DeviceId[MAX_PATH + 1];
} WTSCLIENTW, *PWTSCLIENTW;

typedef struct _WTSCLIENTA {
  CHAR   ClientName[CLIENTNAME_LENGTH + 1];
  CHAR   Domain[DOMAIN_LENGTH + 1 ];
  CHAR   UserName[USERNAME_LENGTH + 1];
  CHAR   WorkDirectory[MAX_PATH + 1];
  CHAR   InitialProgram[MAX_PATH + 1];
  BYTE    EncryptionLevel;
  ULONG   ClientAddressFamily;
  USHORT  ClientAddress[CLIENTADDRESS_LENGTH + 1];
  USHORT  HRes;
  USHORT  VRes;
  USHORT  ColorDepth;
  CHAR   ClientDirectory[MAX_PATH + 1];
  ULONG   ClientBuildNumber;
  ULONG   ClientHardwareId;
  USHORT  ClientProductId;
  USHORT  OutBufCountHost;
  USHORT  OutBufCountClient;
  USHORT  OutBufLength;
  CHAR     DeviceId[MAX_PATH + 1];
} WTSCLIENTA, *PWTSCLIENTA;

__MINGW_TYPEDEF_AW(WTSCLIENT)
__MINGW_TYPEDEF_AW(PWTSCLIENT)

#define PRODUCTINFO_COMPANYNAME_LENGTH 256
#define PRODUCTINFO_PRODUCTID_LENGTH 4

  typedef struct _WTS_PRODUCT_INFOA {
    CHAR CompanyName[PRODUCTINFO_COMPANYNAME_LENGTH];
    CHAR ProductID[PRODUCTINFO_PRODUCTID_LENGTH];
  } PRODUCT_INFOA;

  typedef struct _WTS_PRODUCT_INFOW {
    WCHAR CompanyName[PRODUCTINFO_COMPANYNAME_LENGTH];
    WCHAR ProductID[PRODUCTINFO_PRODUCTID_LENGTH];
  } PRODUCT_INFOW;

__MINGW_TYPEDEF_AW(PRODUCT_INFO)

#define VALIDATIONINFORMATION_LICENSE_LENGTH 16384
#define VALIDATIONINFORMATION_HARDWAREID_LENGTH 20

  typedef struct _WTS_VALIDATION_INFORMATIONA {
    PRODUCT_INFOA ProductInfo;
    BYTE License[VALIDATIONINFORMATION_LICENSE_LENGTH];
    DWORD LicenseLength;
    BYTE HardwareID[VALIDATIONINFORMATION_HARDWAREID_LENGTH];
    DWORD HardwareIDLength;
  } WTS_VALIDATION_INFORMATIONA, *PWTS_VALIDATION_INFORMATIONA;

  typedef struct _WTS_VALIDATION_INFORMATIONW {
    PRODUCT_INFOW ProductInfo;
    BYTE License[VALIDATIONINFORMATION_LICENSE_LENGTH];
    DWORD LicenseLength;
    BYTE HardwareID[VALIDATIONINFORMATION_HARDWAREID_LENGTH];
    DWORD HardwareIDLength;
  } WTS_VALIDATION_INFORMATIONW, *PWTS_VALIDATION_INFORMATIONW;

__MINGW_TYPEDEF_AW(WTS_VALIDATION_INFORMATION)
__MINGW_TYPEDEF_AW(PWTS_VALIDATION_INFORMATION)

typedef struct _WTSINFOW {
  WTS_CONNECTSTATE_CLASS State;
  DWORD                  SessionId;
  DWORD                  IncomingBytes;
  DWORD                  OutgoingBytes;
  DWORD                  IncomingFrames;
  DWORD                  OutgoingFrames;
  DWORD                  IncomingCompressedBytes;
  DWORD                  OutgoingCompressedBytes;
  WCHAR                  WinStationName[WINSTATIONNAME_LENGTH];
  WCHAR                  Domain[DOMAIN_LENGTH];
  WCHAR                  UserName[USERNAME_LENGTH+1];
  LARGE_INTEGER          ConnectTime;
  LARGE_INTEGER          DisconnectTime;
  LARGE_INTEGER          LastInputTime;
  LARGE_INTEGER          LogonTime;
  LARGE_INTEGER          CurrentTime;
} WTSINFOW, *PWTSINFOW;

typedef struct _WTSINFOA {
  WTS_CONNECTSTATE_CLASS State;
  DWORD                  SessionId;
  DWORD                  IncomingBytes;
  DWORD                  OutgoingBytes;
  DWORD                  IncomingFrames;
  DWORD                  OutgoingFrames;
  DWORD                  IncomingCompressedBytes;
  DWORD                  OutgoingCompressedBytes;
  CHAR                   WinStationName[WINSTATIONNAME_LENGTH];
  CHAR                   Domain[DOMAIN_LENGTH];
  CHAR                   UserName[USERNAME_LENGTH+1];
  LARGE_INTEGER          ConnectTime;
  LARGE_INTEGER          DisconnectTime;
  LARGE_INTEGER          LastInputTime;
  LARGE_INTEGER          LogonTime;
  LARGE_INTEGER          CurrentTime;
} WTSINFOA, *PWTSINFOA;

__MINGW_TYPEDEF_AW(WTSINFO)
__MINGW_TYPEDEF_AW(PWTSINFO)

#define WTS_SESSIONSTATE_UNKNOWN 0xffffffff
#define WTS_SESSIONSTATE_LOCK 0x00000000
#define WTS_SESSIONSTATE_UNLOCK 0x00000001

  typedef struct _WTSINFOEX_LEVEL1_W {
    ULONG SessionId;
    WTS_CONNECTSTATE_CLASS SessionState;
    LONG SessionFlags;
    WCHAR WinStationName[WINSTATIONNAME_LENGTH + 1];
    WCHAR UserName[USERNAME_LENGTH + 1];
    WCHAR DomainName[DOMAIN_LENGTH + 1];
    LARGE_INTEGER LogonTime;
    LARGE_INTEGER ConnectTime;
    LARGE_INTEGER DisconnectTime;
    LARGE_INTEGER LastInputTime;
    LARGE_INTEGER CurrentTime;
    DWORD IncomingBytes;
    DWORD OutgoingBytes;
    DWORD IncomingFrames;
    DWORD OutgoingFrames;
    DWORD IncomingCompressedBytes;
    DWORD OutgoingCompressedBytes;
  } WTSINFOEX_LEVEL1_W, *PWTSINFOEX_LEVEL1_W;

  typedef struct _WTSINFOEX_LEVEL1_A {
    ULONG SessionId;
    WTS_CONNECTSTATE_CLASS SessionState;
    LONG SessionFlags;
    CHAR WinStationName[WINSTATIONNAME_LENGTH + 1];
    CHAR UserName[USERNAME_LENGTH + 1];
    CHAR DomainName[DOMAIN_LENGTH + 1];
    LARGE_INTEGER LogonTime;
    LARGE_INTEGER ConnectTime;
    LARGE_INTEGER DisconnectTime;
    LARGE_INTEGER LastInputTime;
    LARGE_INTEGER CurrentTime;
    DWORD IncomingBytes;
    DWORD OutgoingBytes;
    DWORD IncomingFrames;
    DWORD OutgoingFrames;
    DWORD IncomingCompressedBytes;
    DWORD OutgoingCompressedBytes;
  } WTSINFOEX_LEVEL1_A, *PWTSINFOEX_LEVEL1_A;

__MINGW_TYPEDEF_UAW(WTSINFOEX_LEVEL1)
__MINGW_TYPEDEF_UAW(PWTSINFOEX_LEVEL1)

  typedef union _WTSINFOEX_LEVEL_W {
    WTSINFOEX_LEVEL1_W WTSInfoExLevel1;
  } WTSINFOEX_LEVEL_W, *PWTSINFOEX_LEVEL_W;

  typedef union _WTSINFOEX_LEVEL_A {
    WTSINFOEX_LEVEL1_A WTSInfoExLevel1;
  } WTSINFOEX_LEVEL_A, *PWTSINFOEX_LEVEL_A;

__MINGW_TYPEDEF_UAW(WTSINFOEX_LEVEL)
__MINGW_TYPEDEF_UAW(PWTSINFOEX_LEVEL)

  typedef struct _WTSINFOEXW {
    DWORD Level;
    WTSINFOEX_LEVEL_W Data;
  } WTSINFOEXW, *PWTSINFOEXW;

  typedef struct _WTSINFOEXA {
    DWORD Level;
    WTSINFOEX_LEVEL_A Data;
  } WTSINFOEXA, *PWTSINFOEXA;

__MINGW_TYPEDEF_AW(WTSINFOEX)
__MINGW_TYPEDEF_AW(PWTSINFOEX)

WINBOOL WINAPI WTSConnectSessionA(
  ULONG LogonId,
  ULONG TargetLogonId,
  PSTR   pPassword,
  WINBOOL bWait
);

WINBOOL WINAPI WTSConnectSessionW(
  ULONG LogonId,
  ULONG TargetLogonId,
  PWSTR  pPassword,
  WINBOOL bWait
);

WINBOOL WTSRegisterSessionNotificationEx(
  HANDLE hServer,
  HWND hWnd,
  DWORD dwFlags
);

WINBOOL WINAPI WTSStartRemoteControlSessionA(
  LPSTR pTargetServerName,
  ULONG TargetLogonId,
  BYTE HotkeyVk,
  USHORT HotkeyModifiers
);

WINBOOL WINAPI WTSStartRemoteControlSessionW(
  LPWSTR pTargetServerName,
  ULONG TargetLogonId,
  BYTE HotkeyVk,
  USHORT HotkeyModifiers
);

#define WTSStartRemoteControlSession __MINGW_NAME_AW(WTSStartRemoteControlSession)
#define WTSConnectSession __MINGW_NAME_AW(WTSConnectSession)

WINBOOL WINAPI WTSStopRemoteControlSession(
  ULONG LogonId
);

WINBOOL WINAPI WTSUnRegisterSessionNotificationEx(
  HANDLE hServer,
  HWND hWnd
);

#define WTS_CHANNEL_OPTION_DYNAMIC 0x00000001
#define WTS_CHANNEL_OPTION_DYNAMIC_PRI_LOW 0x00000000
#define WTS_CHANNEL_OPTION_DYNAMIC_PRI_MED 0x00000002
#define WTS_CHANNEL_OPTION_DYNAMIC_PRI_HIGH 0x00000004
#define WTS_CHANNEL_OPTION_DYNAMIC_PRI_REAL 0x00000006
#define WTS_CHANNEL_OPTION_DYNAMIC_NO_COMPRESS 0x00000008

HANDLE WINAPI WTSVirtualChannelOpenEx(
  DWORD SessionId,
  LPSTR pVirtualName,
  DWORD flags
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

#if (_WIN32_WINNT >= 0x0601)

typedef struct _WTS_SESSION_INFO_1A {
  DWORD ExecEnvId;
  WTS_CONNECTSTATE_CLASS State;
  DWORD SessionId;
  LPSTR pSessionName;
  LPSTR pHostName;
  LPSTR pUserName;
  LPSTR pDomainName;
  LPSTR pFarmName;
} WTS_SESSION_INFO_1A, *PWTS_SESSION_INFO_1A;

typedef struct _WTS_SESSION_INFO_1W {
  DWORD ExecEnvId;
  WTS_CONNECTSTATE_CLASS State;
  DWORD SessionId;
  LPWSTR pSessionName;
  LPWSTR pHostName;
  LPWSTR pUserName;
  LPWSTR pDomainName;
  LPWSTR pFarmName;
} WTS_SESSION_INFO_1W, * PWTS_SESSION_INFO_1W;

#define WTS_SESSION_INFO_1 __MINGW_NAME_AW(WTS_SESSION_INFO_1)
#define PWTS_SESSION_INFO_1 __MINGW_NAME_AW(PWTS_SESSION_INFO_1)

WINBOOL WINAPI WTSEnumerateSessionsExA(HANDLE hServer,DWORD* pLevel,DWORD Filter,PWTS_SESSION_INFO_1A* ppSessionInfo,DWORD* pCount);
WINBOOL WINAPI WTSEnumerateSessionsExW(HANDLE hServer,DWORD* pLevel,DWORD Filter,PWTS_SESSION_INFO_1W* ppSessionInfo,DWORD* pCount);
#define WTSEnumerateSessionsEx __MINGW_NAME_AW(WTSEnumerateSessionsEx)

typedef enum _WTS_TYPE_CLASS {
  WTSTypeProcessInfoLevel0,
  WTSTypeProcessInfoLevel1,
  WTSTypeSessionInfoLevel1
} WTS_TYPE_CLASS;
WINBOOL WINAPI WTSFreeMemoryExA(WTS_TYPE_CLASS WTSTypeClass,PVOID pMemory,ULONG NumberOfEntries);
WINBOOL WINAPI WTSFreeMemoryExW(WTS_TYPE_CLASS WTSTypeClass,PVOID pMemory,ULONG NumberOfEntries);
#define WTSFreeMemoryEx __MINGW_NAME_AW(WTSFreeMemoryEx)

#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif
#endif
