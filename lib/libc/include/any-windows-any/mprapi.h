/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __ROUTING_MPRADMIN_H__
#define __ROUTING_MPRADMIN_H__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <lmcons.h>
#include <ras.h>
#include <in6addr.h>
#include <wincrypt.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef CALLBACK
#define CALLBACK WINAPI
#endif

#define RRAS_SERVICE_NAME TEXT("RemoteAccess")

#define PID_IPX 0x0000002B
#define PID_IP 0x00000021
#define PID_NBF 0x0000003F
#define PID_ATALK 0x00000029

#define MAX_INTERFACE_NAME_LEN 256
#define MAX_TRANSPORT_NAME_LEN 40
#define MAX_MEDIA_NAME 16
#define MAX_PORT_NAME 16
#define MAX_DEVICE_NAME 128
#define MAX_PHONE_NUMBER_LEN 128
#define MAX_DEVICETYPE_NAME 16

  typedef enum _ROUTER_INTERFACE_TYPE {
    ROUTER_IF_TYPE_CLIENT,ROUTER_IF_TYPE_HOME_ROUTER,ROUTER_IF_TYPE_FULL_ROUTER,ROUTER_IF_TYPE_DEDICATED,ROUTER_IF_TYPE_INTERNAL,
    ROUTER_IF_TYPE_LOOPBACK,ROUTER_IF_TYPE_TUNNEL1,ROUTER_IF_TYPE_DIALOUT
  } ROUTER_INTERFACE_TYPE;

  typedef enum _ROUTER_CONNECTION_STATE {
    ROUTER_IF_STATE_UNREACHABLE,ROUTER_IF_STATE_DISCONNECTED,ROUTER_IF_STATE_CONNECTING,ROUTER_IF_STATE_CONNECTED
  } ROUTER_CONNECTION_STATE;

#define MPR_INTERFACE_OUT_OF_RESOURCES 0x00000001
#define MPR_INTERFACE_ADMIN_DISABLED 0x00000002
#define MPR_INTERFACE_CONNECTION_FAILURE 0x00000004
#define MPR_INTERFACE_SERVICE_PAUSED 0x00000008
#define MPR_INTERFACE_DIALOUT_HOURS_RESTRICTION 0x00000010
#define MPR_INTERFACE_NO_MEDIA_SENSE 0x00000020
#define MPR_INTERFACE_NO_DEVICE 0x00000040

  typedef struct _MPR_INTERFACE_0 {
    WCHAR wszInterfaceName[MAX_INTERFACE_NAME_LEN+1];
    HANDLE hInterface;
    WINBOOL fEnabled;
    ROUTER_INTERFACE_TYPE dwIfType;
    ROUTER_CONNECTION_STATE dwConnectionState;
    DWORD fUnReachabilityReasons;
    DWORD dwLastError;
  } MPR_INTERFACE_0,*PMPR_INTERFACE_0;

  typedef struct _MPR_IPINIP_INTERFACE_0 {
    WCHAR wszFriendlyName[MAX_INTERFACE_NAME_LEN+1];
    GUID Guid;
  } MPR_IPINIP_INTERFACE_0,*PMPR_IPINIP_INTERFACE_0;

  typedef struct _MPR_INTERFACE_1 {
    WCHAR wszInterfaceName[MAX_INTERFACE_NAME_LEN+1];
    HANDLE hInterface;
    WINBOOL fEnabled;
    ROUTER_INTERFACE_TYPE dwIfType;
    ROUTER_CONNECTION_STATE dwConnectionState;
    DWORD fUnReachabilityReasons;
    DWORD dwLastError;
    LPWSTR lpwsDialoutHoursRestriction;

  } MPR_INTERFACE_1,*PMPR_INTERFACE_1;

#define MPR_MaxDeviceType RAS_MaxDeviceType
#define MPR_MaxPhoneNumber RAS_MaxPhoneNumber
#define MPR_MaxIpAddress RAS_MaxIpAddress
#define MPR_MaxIpxAddress RAS_MaxIpxAddress

#define MPR_MaxEntryName RAS_MaxEntryName
#define MPR_MaxDeviceName RAS_MaxDeviceName
#define MPR_MaxCallbackNumber RAS_MaxCallbackNumber

#define MPR_MaxAreaCode RAS_MaxAreaCode
#define MPR_MaxPadType RAS_MaxPadType
#define MPR_MaxX25Address RAS_MaxX25Address
#define MPR_MaxFacilities RAS_MaxFacilities
#define MPR_MaxUserData RAS_MaxUserData

#define MPRIO_SpecificIpAddr RASEO_SpecificIpAddr
#define MPRIO_SpecificNameServers RASEO_SpecificNameServers
#define MPRIO_IpHeaderCompression RASEO_IpHeaderCompression
#define MPRIO_RemoteDefaultGateway RASEO_RemoteDefaultGateway
#define MPRIO_DisableLcpExtensions RASEO_DisableLcpExtensions
#define MPRIO_SwCompression RASEO_SwCompression
#define MPRIO_RequireEncryptedPw RASEO_RequireEncryptedPw
#define MPRIO_RequireMsEncryptedPw RASEO_RequireMsEncryptedPw
#define MPRIO_RequireDataEncryption RASEO_RequireDataEncryption
#define MPRIO_NetworkLogon RASEO_NetworkLogon
#define MPRIO_PromoteAlternates RASEO_PromoteAlternates
#define MPRIO_SecureLocalFiles RASEO_SecureLocalFiles
#define MPRIO_RequireEAP RASEO_RequireEAP
#define MPRIO_RequirePAP RASEO_RequirePAP
#define MPRIO_RequireSPAP RASEO_RequireSPAP
#define MPRIO_SharedPhoneNumbers RASEO_SharedPhoneNumbers
#define MPRIO_RequireCHAP RASEO_RequireCHAP
#define MPRIO_RequireMsCHAP RASEO_RequireMsCHAP
#define MPRIO_RequireMsCHAP2 RASEO_RequireMsCHAP2
#define MPRIO_IpSecPreSharedKey 0x80000000

#define MPRNP_Ipx RASNP_Ipx
#define MPRNP_Ip RASNP_Ip

#define MPRDT_Modem RASDT_Modem
#define MPRDT_Isdn RASDT_Isdn
#define MPRDT_X25 RASDT_X25
#define MPRDT_Vpn RASDT_Vpn
#define MPRDT_Pad RASDT_Pad
#define MPRDT_Generic RASDT_Generic
#define MPRDT_Serial RASDT_Serial
#define MPRDT_FrameRelay RASDT_FrameRelay
#define MPRDT_Atm RASDT_Atm
#define MPRDT_Sonet RASDT_Sonet
#define MPRDT_SW56 RASDT_SW56
#define MPRDT_Irda RASDT_Irda
#define MPRDT_Parallel RASDT_Parallel

#define MPRET_Phone RASET_Phone
#define MPRET_Vpn RASET_Vpn
#define MPRET_Direct RASET_Direct

#define MPRDM_DialFirst 0
#define MPRDM_DialAll RASEDM_DialAll
#define MPRDM_DialAsNeeded RASEDM_DialAsNeeded

#define MPRIDS_Disabled RASIDS_Disabled
#define MPRIDS_UseGlobalValue RASIDS_UseGlobalValue

#define MPR_ET_None ET_None
#define MPR_ET_Require ET_Require
#define MPR_ET_RequireMax ET_RequireMax
#define MPR_ET_Optional ET_Optional

#define MPR_VS_Default VS_Default
#define MPR_VS_PptpOnly VS_PptpOnly
#define MPR_VS_PptpFirst VS_PptpFirst
#define MPR_VS_L2tpOnly VS_L2tpOnly
#define MPR_VS_L2tpFirst VS_L2tpFirst

  typedef struct _MPR_INTERFACE_2 {
    WCHAR wszInterfaceName[MAX_INTERFACE_NAME_LEN+1];
    HANDLE hInterface;
    WINBOOL fEnabled;
    ROUTER_INTERFACE_TYPE dwIfType;
    ROUTER_CONNECTION_STATE dwConnectionState;
    DWORD fUnReachabilityReasons;
    DWORD dwLastError;
    DWORD dwfOptions;
    WCHAR szLocalPhoneNumber[RAS_MaxPhoneNumber + 1 ];
    PWCHAR szAlternates;
    DWORD ipaddr;
    DWORD ipaddrDns;
    DWORD ipaddrDnsAlt;
    DWORD ipaddrWins;
    DWORD ipaddrWinsAlt;
    DWORD dwfNetProtocols;
    WCHAR szDeviceType[MPR_MaxDeviceType + 1 ];
    WCHAR szDeviceName[MPR_MaxDeviceName + 1 ];
    WCHAR szX25PadType[MPR_MaxPadType + 1 ];
    WCHAR szX25Address[MPR_MaxX25Address + 1 ];
    WCHAR szX25Facilities[MPR_MaxFacilities + 1 ];
    WCHAR szX25UserData[MPR_MaxUserData + 1 ];
    DWORD dwChannels;
    DWORD dwSubEntries;
    DWORD dwDialMode;
    DWORD dwDialExtraPercent;
    DWORD dwDialExtraSampleSeconds;
    DWORD dwHangUpExtraPercent;
    DWORD dwHangUpExtraSampleSeconds;
    DWORD dwIdleDisconnectSeconds;
    DWORD dwType;
    DWORD dwEncryptionType;
    DWORD dwCustomAuthKey;
    DWORD dwCustomAuthDataSize;
    LPBYTE lpbCustomAuthData;
    GUID guidId;
    DWORD dwVpnStrategy;
  } MPR_INTERFACE_2,*PMPR_INTERFACE_2;

#if (_WIN32_WINNT >= 0x0600)
  typedef struct _MPR_INTERFACE_3 {
    WCHAR                   wszInterfaceName[MAX_INTERFACE_NAME_LEN+1];
    HANDLE                  hInterface;
    WINBOOL                 fEnabled;
    ROUTER_INTERFACE_TYPE   dwIfType;
    ROUTER_CONNECTION_STATE dwConnectionState;
    DWORD                   fUnReachabilityReasons;
    DWORD                   dwLastError;
    DWORD                   dwfOptions;
    WCHAR                   szLocalPhoneNumber[RAS_MaxPhoneNumber + 1];
    PWCHAR                  szAlternates;
    DWORD                   ipaddr;
    DWORD                   ipaddrDns;
    DWORD                   ipaddrDnsAlt;
    DWORD                   ipaddrWins;
    DWORD                   ipaddrWinsAlt;
    DWORD                   dwfNetProtocols;
    WCHAR                   szDeviceType[MPR_MaxDeviceType + 1];
    WCHAR                   szDeviceName[MPR_MaxDeviceName + 1];
    WCHAR                   szX25PadType[MPR_MaxPadType + 1];
    WCHAR                   szX25Address[MPR_MaxX25Address + 1];
    WCHAR                   szX25Facilities[MPR_MaxFacilities + 1];
    WCHAR                   szX25UserData[MPR_MaxUserData + 1];
    DWORD                   dwChannels;
    DWORD                   dwSubEntries;
    DWORD                   dwDialMode;
    DWORD                   dwDialExtraPercent;
    DWORD                   dwDialExtraSampleSeconds;
    DWORD                   dwHangUpExtraPercent;
    DWORD                   dwHangUpExtraSampleSeconds;
    DWORD                   dwIdleDisconnectSeconds;
    DWORD                   dwType;
    DWORD                   dwEncryptionType;
    DWORD                   dwCustomAuthKey;
    DWORD                   dwCustomAuthDataSize;
    LPBYTE                  lpbCustomAuthData;
    GUID                    guidId;
    DWORD                   dwVpnStrategy;
    ULONG                   AddressCount;
    IN6_ADDR                ipv6addrDns;
    IN6_ADDR                ipv6addrDnsAlt;
    IN6_ADDR *              ipv6addr;
  } MPR_INTERFACE_3, *PMPR_INTERFACE_3;
#endif

  typedef struct _MPR_DEVICE_0 {
    WCHAR szDeviceType[MPR_MaxDeviceType + 1 ];
    WCHAR szDeviceName[MPR_MaxDeviceName + 1 ];
  } MPR_DEVICE_0,*PMPR_DEVICE_0;

  typedef struct _MPR_DEVICE_1 {
    WCHAR szDeviceType[MPR_MaxDeviceType + 1 ];
    WCHAR szDeviceName[MPR_MaxDeviceName + 1 ];
    WCHAR szLocalPhoneNumber[MPR_MaxPhoneNumber + 1 ];
    PWCHAR szAlternates;
  } MPR_DEVICE_1,*PMPR_DEVICE_1;

  typedef struct _MPR_CREDENTIALSEX_0 {
    DWORD dwSize;
    LPBYTE lpbCredentialsInfo;
  } MPR_CREDENTIALSEX_0,*PMPR_CREDENTIALSEX_0;

  typedef struct _MPR_CREDENTIALSEX_1 {
    DWORD dwSize;
    LPBYTE lpbCredentialsInfo;
  } MPR_CREDENTIALSEX_1,*PMPR_CREDENTIALSEX_1;

  typedef struct _MPR_TRANSPORT_0 {
    DWORD dwTransportId;
    HANDLE hTransport;
    WCHAR wszTransportName[MAX_TRANSPORT_NAME_LEN+1];
  } MPR_TRANSPORT_0,*PMPR_TRANSPORT_0;

  typedef struct _MPR_IFTRANSPORT_0
  {
    DWORD dwTransportId;
    HANDLE hIfTransport;
    WCHAR wszIfTransportName[MAX_TRANSPORT_NAME_LEN+1];

  }
  MPR_IFTRANSPORT_0,*PMPR_IFTRANSPORT_0;

  typedef struct _MPR_SERVER_0
  {
    WINBOOL fLanOnlyMode;
    DWORD dwUpTime;
    DWORD dwTotalPorts;
    DWORD dwPortsInUse;

  }
  MPR_SERVER_0,*PMPR_SERVER_0;

#define MPR_ENABLE_RAS_ON_DEVICE 0x00000001
#define MPR_ENABLE_ROUTING_ON_DEVICE 0x00000002

  typedef struct _MPR_SERVER_1 {
    DWORD dwNumPptpPorts;
    DWORD dwPptpPortFlags;
    DWORD dwNumL2tpPorts;
    DWORD dwL2tpPortFlags;
  } MPR_SERVER_1,*PMPR_SERVER_1;

  typedef enum _RAS_PORT_CONDITION {
    RAS_PORT_NON_OPERATIONAL,RAS_PORT_DISCONNECTED,RAS_PORT_CALLING_BACK,RAS_PORT_LISTENING,RAS_PORT_AUTHENTICATING,RAS_PORT_AUTHENTICATED,
    RAS_PORT_INITIALIZING
  } RAS_PORT_CONDITION;

  typedef enum _RAS_HARDWARE_CONDITION {
    RAS_HARDWARE_OPERATIONAL,RAS_HARDWARE_FAILURE
  } RAS_HARDWARE_CONDITION;

  typedef struct _RAS_PORT_0 {
    HANDLE hPort;
    HANDLE hConnection;
    RAS_PORT_CONDITION dwPortCondition;
    DWORD dwTotalNumberOfCalls;
    DWORD dwConnectDuration;
    WCHAR wszPortName[MAX_PORT_NAME + 1 ];
    WCHAR wszMediaName[MAX_MEDIA_NAME + 1 ];
    WCHAR wszDeviceName[MAX_DEVICE_NAME + 1 ];
    WCHAR wszDeviceType[MAX_DEVICETYPE_NAME + 1 ];
  } RAS_PORT_0,*PRAS_PORT_0;

  typedef struct _RAS_PORT_1 {
    HANDLE hPort;
    HANDLE hConnection;
    RAS_HARDWARE_CONDITION dwHardwareCondition;
    DWORD dwLineSpeed;
    DWORD dwBytesXmited;
    DWORD dwBytesRcved;
    DWORD dwFramesXmited;
    DWORD dwFramesRcved;
    DWORD dwCrcErr;
    DWORD dwTimeoutErr;
    DWORD dwAlignmentErr;
    DWORD dwHardwareOverrunErr;
    DWORD dwFramingErr;
    DWORD dwBufferOverrunErr;
    DWORD dwCompressionRatioIn;
    DWORD dwCompressionRatioOut;
  } RAS_PORT_1,*PRAS_PORT_1;

#define IPADDRESSLEN 15
#define IPXADDRESSLEN 22
#define ATADDRESSLEN 32
#define MAXIPADRESSLEN 64

  typedef struct _PPP_NBFCP_INFO {
    DWORD dwError;
    WCHAR wszWksta[NETBIOS_NAME_LEN + 1 ];
  } PPP_NBFCP_INFO;

  typedef struct _PPP_IPCP_INFO {
    DWORD dwError;
    WCHAR wszAddress[IPADDRESSLEN + 1 ];
    WCHAR wszRemoteAddress[IPADDRESSLEN + 1 ];
  } PPP_IPCP_INFO;

#define PPP_IPCP_VJ 0x00000001

  typedef struct _PPP_IPCP_INFO2 {
    DWORD dwError;
    WCHAR wszAddress[IPADDRESSLEN + 1 ];
    WCHAR wszRemoteAddress[IPADDRESSLEN + 1 ];
    DWORD dwOptions;
    DWORD dwRemoteOptions;
  } PPP_IPCP_INFO2;

  typedef struct _PPP_IPXCP_INFO {
    DWORD dwError;
    WCHAR wszAddress[IPXADDRESSLEN + 1 ];
  } PPP_IPXCP_INFO;

  typedef struct _PPP_ATCP_INFO {
    DWORD dwError;
    WCHAR wszAddress[ATADDRESSLEN + 1 ];
  } PPP_ATCP_INFO;

  typedef struct _PPP_INFO {
    PPP_NBFCP_INFO nbf;
    PPP_IPCP_INFO ip;
    PPP_IPXCP_INFO ipx;
    PPP_ATCP_INFO at;
  } PPP_INFO;

#define RASCCPCA_MPPC 0x00000006
#define RASCCPCA_STAC 0x00000005

#define PPP_CCP_COMPRESSION 0x00000001
#define PPP_CCP_ENCRYPTION40BITOLD 0x00000010
#define PPP_CCP_ENCRYPTION40BIT 0x00000020
#define PPP_CCP_ENCRYPTION128BIT 0x00000040
#define PPP_CCP_ENCRYPTION56BIT 0x00000080
#define PPP_CCP_HISTORYLESS 0x01000000

  typedef struct _PPP_CCP_INFO {
    DWORD dwError;
    DWORD dwCompressionAlgorithm;
    DWORD dwOptions;
    DWORD dwRemoteCompressionAlgorithm;
    DWORD dwRemoteOptions;
  } PPP_CCP_INFO;

#define PPP_LCP_PAP 0xC023
#define PPP_LCP_SPAP 0xC027
#define PPP_LCP_CHAP 0xC223
#define PPP_LCP_EAP 0xC227

#define PPP_LCP_CHAP_MD5 0x05
#define PPP_LCP_CHAP_MS 0x80
#define PPP_LCP_CHAP_MSV2 0x81

#define PPP_LCP_MULTILINK_FRAMING 0x00000001
#define PPP_LCP_PFC 0x00000002
#define PPP_LCP_ACFC 0x00000004
#define PPP_LCP_SSHF 0x00000008
#define PPP_LCP_DES_56 0x00000010
#define PPP_LCP_3_DES 0x00000020

  typedef struct _PPP_LCP_INFO {
    DWORD dwError;
    DWORD dwAuthenticationProtocol;
    DWORD dwAuthenticationData;
    DWORD dwRemoteAuthenticationProtocol;
    DWORD dwRemoteAuthenticationData;
    DWORD dwTerminateReason;
    DWORD dwRemoteTerminateReason;
    DWORD dwOptions;
    DWORD dwRemoteOptions;
    DWORD dwEapTypeId;
    DWORD dwRemoteEapTypeId;
  } PPP_LCP_INFO;

  typedef struct _PPP_INFO_2 {
    PPP_NBFCP_INFO nbf;
    PPP_IPCP_INFO2 ip;
    PPP_IPXCP_INFO ipx;
    PPP_ATCP_INFO at;
    PPP_CCP_INFO ccp;
    PPP_LCP_INFO lcp;
  } PPP_INFO_2;

#define RAS_FLAGS_PPP_CONNECTION 0x00000001
#define RAS_FLAGS_MESSENGER_PRESENT 0x00000002
#define RAS_FLAGS_QUARANTINE_PRESENT 0x00000008

  typedef struct _RAS_CONNECTION_0 {
    HANDLE hConnection;
    HANDLE hInterface;
    DWORD dwConnectDuration;
    ROUTER_INTERFACE_TYPE dwInterfaceType;
    DWORD dwConnectionFlags;
    WCHAR wszInterfaceName[MAX_INTERFACE_NAME_LEN + 1 ];
    WCHAR wszUserName[UNLEN + 1 ];
    WCHAR wszLogonDomain[DNLEN + 1 ];
    WCHAR wszRemoteComputer[NETBIOS_NAME_LEN + 1 ];
  } RAS_CONNECTION_0,*PRAS_CONNECTION_0;

  typedef struct _RAS_CONNECTION_1 {
    HANDLE hConnection;
    HANDLE hInterface;
    PPP_INFO PppInfo;
    DWORD dwBytesXmited;
    DWORD dwBytesRcved;
    DWORD dwFramesXmited;
    DWORD dwFramesRcved;
    DWORD dwCrcErr;
    DWORD dwTimeoutErr;
    DWORD dwAlignmentErr;
    DWORD dwHardwareOverrunErr;
    DWORD dwFramingErr;
    DWORD dwBufferOverrunErr;
    DWORD dwCompressionRatioIn;
    DWORD dwCompressionRatioOut;
  } RAS_CONNECTION_1,*PRAS_CONNECTION_1;

  typedef struct _RAS_CONNECTION_2 {
    HANDLE hConnection;
    WCHAR wszUserName[UNLEN + 1 ];
    ROUTER_INTERFACE_TYPE dwInterfaceType;
    GUID guid;
    PPP_INFO_2 PppInfo2;
  } RAS_CONNECTION_2,*PRAS_CONNECTION_2;

#define RASPRIV_NoCallback 0x01
#define RASPRIV_AdminSetCallback 0x02
#define RASPRIV_CallerSetCallback 0x04
#define RASPRIV_DialinPrivilege 0x08

#define RASPRIV2_DialinPolicy 0x1

#define RASPRIV_CallbackType (RASPRIV_AdminSetCallback | RASPRIV_CallerSetCallback | RASPRIV_NoCallback)

  typedef struct _RAS_USER_0 {
    BYTE bfPrivilege;
    WCHAR wszPhoneNumber[MAX_PHONE_NUMBER_LEN + 1];
  } RAS_USER_0,*PRAS_USER_0;

  typedef struct _RAS_USER_1 {
    BYTE bfPrivilege;
    WCHAR wszPhoneNumber[MAX_PHONE_NUMBER_LEN + 1];
    BYTE bfPrivilege2;
  } RAS_USER_1,*PRAS_USER_1;

  typedef HANDLE RAS_SERVER_HANDLE;
  typedef HANDLE MPR_SERVER_HANDLE;
  typedef HANDLE MIB_SERVER_HANDLE;

  DWORD WINAPI MprAdminConnectionEnum(RAS_SERVER_HANDLE hRasServer,DWORD dwLevel,LPBYTE *lplpbBuffer,DWORD dwPrefMaxLen,LPDWORD lpdwEntriesRead,LPDWORD lpdwTotalEntries,LPDWORD lpdwResumeHandle);
  DWORD WINAPI MprAdminPortEnum(RAS_SERVER_HANDLE hRasServer,DWORD dwLevel,HANDLE hConnection,LPBYTE *lplpbBuffer,DWORD dwPrefMaxLen,LPDWORD lpdwEntriesRead,LPDWORD lpdwTotalEntries,LPDWORD lpdwResumeHandle);
  DWORD WINAPI MprAdminConnectionGetInfo(RAS_SERVER_HANDLE hRasServer,DWORD dwLevel,HANDLE hConnection,LPBYTE *lplpbBuffer);
  DWORD WINAPI MprAdminPortGetInfo(RAS_SERVER_HANDLE hRasServer,DWORD dwLevel,HANDLE hPort,LPBYTE *lplpbBuffer);
  DWORD WINAPI MprAdminConnectionClearStats(RAS_SERVER_HANDLE hRasServer,HANDLE hConnection);
  DWORD WINAPI MprAdminPortClearStats(RAS_SERVER_HANDLE hRasServer,HANDLE hPort);
  DWORD WINAPI MprAdminPortReset(RAS_SERVER_HANDLE hRasServer,HANDLE hPort);
  DWORD WINAPI MprAdminPortDisconnect(RAS_SERVER_HANDLE hRasServer,HANDLE hPort);
  WINBOOL WINAPI MprAdminAcceptNewConnection(RAS_CONNECTION_0 *pRasConnection0,RAS_CONNECTION_1 *pRasConnection1);
  WINBOOL WINAPI MprAdminAcceptNewConnection2(RAS_CONNECTION_0 *pRasConnection0,RAS_CONNECTION_1 *pRasConnection1,RAS_CONNECTION_2 *pRasConnection2);
  WINBOOL WINAPI MprAdminAcceptNewLink (RAS_PORT_0 *pRasPort0,RAS_PORT_1 *pRasPort1);
  VOID WINAPI MprAdminConnectionHangupNotification(RAS_CONNECTION_0 *pRasConnection0,RAS_CONNECTION_1 *pRasConnection1);
  VOID WINAPI MprAdminConnectionHangupNotification2(RAS_CONNECTION_0 *pRasConnection0,RAS_CONNECTION_1 *pRasConnection1,RAS_CONNECTION_2 *pRasConnection2);
  DWORD WINAPI MprAdminConnectionRemoveQuarantine(HANDLE hRasServer,HANDLE hRasConnection,WINBOOL fIsIpAddress);
  VOID WINAPI MprAdminLinkHangupNotification (RAS_PORT_0 *pRasPort0,RAS_PORT_1 *pRasPort1);
  DWORD WINAPI MprAdminGetIpAddressForUser (WCHAR *lpwszUserName,WCHAR *lpwszPortName,DWORD *lpdwIpAddress,WINBOOL *bNotifyRelease);
  VOID WINAPI MprAdminReleaseIpAddress (WCHAR *lpszUserName,WCHAR *lpszPortName,DWORD *lpdwIpAddress);
  DWORD WINAPI MprAdminInitializeDll(VOID);
  DWORD WINAPI MprAdminTerminateDll(VOID);
  DWORD WINAPI MprAdminUserGetInfo(const WCHAR *lpszServer,const WCHAR *lpszUser,DWORD dwLevel,LPBYTE lpbBuffer);
  DWORD WINAPI MprAdminUserSetInfo(const WCHAR *lpszServer,const WCHAR *lpszUser,DWORD dwLevel,const LPBYTE lpbBuffer);
  DWORD WINAPI MprAdminSendUserMessage(MPR_SERVER_HANDLE hMprServer,HANDLE hConnection,LPWSTR lpwszMessage);
  DWORD WINAPI MprAdminGetPDCServer(const WCHAR *lpszDomain,const WCHAR *lpszServer,LPWSTR lpszPDCServer);
  WINBOOL WINAPI MprAdminIsServiceRunning(LPWSTR lpwsServerName);
  DWORD WINAPI MprAdminServerConnect(LPWSTR lpwsServerName,MPR_SERVER_HANDLE *phMprServer);
  VOID WINAPI MprAdminServerDisconnect(MPR_SERVER_HANDLE hMprServer);
  DWORD WINAPI MprAdminServerGetCredentials(MPR_SERVER_HANDLE hMprServer,DWORD dwLevel,LPBYTE *lplpbBuffer);
  DWORD WINAPI MprAdminServerSetCredentials(MPR_SERVER_HANDLE hMprServer,DWORD dwLevel,LPBYTE lpbBuffer);
  DWORD WINAPI MprAdminBufferFree(LPVOID pBuffer);
  DWORD WINAPI MprAdminGetErrorString(DWORD dwError,LPWSTR *lpwsErrorString);
  DWORD WINAPI MprAdminServerGetInfo(MPR_SERVER_HANDLE hMprServer,DWORD dwLevel,LPBYTE *lplpbBuffer);
  DWORD WINAPI MprAdminServerSetInfo(MPR_SERVER_HANDLE hMprServer,DWORD dwLevel,LPBYTE lpbBuffer);
  DWORD WINAPI MprAdminEstablishDomainRasServer (PWCHAR pszDomain,PWCHAR pszMachine,WINBOOL bEnable);
  DWORD WINAPI MprAdminIsDomainRasServer (PWCHAR pszDomain,PWCHAR pszMachine,PBOOL pbIsRasServer);
  DWORD WINAPI MprAdminTransportCreate(MPR_SERVER_HANDLE hMprServer,DWORD dwTransportId,LPWSTR lpwsTransportName,LPBYTE pGlobalInfo,DWORD dwGlobalInfoSize,LPBYTE pClientInterfaceInfo,DWORD dwClientInterfaceInfoSize,LPWSTR lpwsDLLPath);
  DWORD WINAPI MprAdminTransportSetInfo(MPR_SERVER_HANDLE hMprServer,DWORD dwTransportId,LPBYTE pGlobalInfo,DWORD dwGlobalInfoSize,LPBYTE pClientInterfaceInfo,DWORD dwClientInterfaceInfoSize);
  DWORD WINAPI MprAdminTransportGetInfo(MPR_SERVER_HANDLE hMprServer,DWORD dwTransportId,LPBYTE *ppGlobalInfo,LPDWORD lpdwGlobalInfoSize,LPBYTE *ppClientInterfaceInfo,LPDWORD lpdwClientInterfaceInfoSize);
  DWORD WINAPI MprAdminDeviceEnum(MPR_SERVER_HANDLE hMprServer,DWORD dwLevel,LPBYTE *lplpbBuffer,LPDWORD lpdwTotalEntries);
  DWORD WINAPI MprAdminInterfaceGetHandle(MPR_SERVER_HANDLE hMprServer,LPWSTR lpwsInterfaceName,HANDLE *phInterface,WINBOOL fIncludeClientInterfaces);
  DWORD WINAPI MprAdminInterfaceCreate(MPR_SERVER_HANDLE hMprServer,DWORD dwLevel,LPBYTE lpbBuffer,HANDLE *phInterface);
  DWORD WINAPI MprAdminInterfaceGetInfo(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwLevel,LPBYTE *lplpbBuffer);
  DWORD WINAPI MprAdminInterfaceSetInfo(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwLevel,LPBYTE lpbBuffer);
  DWORD WINAPI MprAdminInterfaceDelete(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface);
  DWORD WINAPI MprAdminInterfaceDeviceGetInfo(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwIndex,DWORD dwLevel,LPBYTE *lplpBuffer);
  DWORD WINAPI MprAdminInterfaceDeviceSetInfo(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwIndex,DWORD dwLevel,LPBYTE lplpBuffer);
  DWORD WINAPI MprAdminInterfaceTransportRemove(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwTransportId);
  DWORD WINAPI MprAdminInterfaceTransportAdd(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwTransportId,LPBYTE pInterfaceInfo,DWORD dwInterfaceInfoSize);
  DWORD WINAPI MprAdminInterfaceTransportGetInfo(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwTransportId,LPBYTE *ppInterfaceInfo,LPDWORD lpdwpInterfaceInfoSize);
  DWORD WINAPI MprAdminInterfaceTransportSetInfo(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwTransportId,LPBYTE pInterfaceInfo,DWORD dwInterfaceInfoSize);
  DWORD WINAPI MprAdminInterfaceEnum(MPR_SERVER_HANDLE hMprServer,DWORD dwLevel,LPBYTE *lplpbBuffer,DWORD dwPrefMaxLen,LPDWORD lpdwEntriesRead,LPDWORD lpdwTotalEntries,LPDWORD lpdwResumeHandle);
  DWORD WINAPI MprSetupIpInIpInterfaceFriendlyNameEnum(PWCHAR pwszMachineName,LPBYTE *lplpBuffer,LPDWORD lpdwEntriesRead);
  DWORD WINAPI MprSetupIpInIpInterfaceFriendlyNameFree(LPVOID lpBuffer);
  DWORD WINAPI MprSetupIpInIpInterfaceFriendlyNameCreate(PWCHAR pwszMachineName,PMPR_IPINIP_INTERFACE_0 pNameInformation);
  DWORD WINAPI MprSetupIpInIpInterfaceFriendlyNameDelete(PWCHAR pwszMachineName,GUID *pGuid);
  DWORD WINAPI MprAdminInterfaceSetCredentials(LPWSTR lpwsServer,LPWSTR lpwsInterfaceName,LPWSTR lpwsUserName,LPWSTR lpwsDomainName,LPWSTR lpwsPassword);
  DWORD WINAPI MprAdminInterfaceGetCredentials(LPWSTR lpwsServer,LPWSTR lpwsInterfaceName,LPWSTR lpwsUserName,LPWSTR lpwsPassword,LPWSTR lpwsDomainName);
  DWORD WINAPI MprAdminInterfaceSetCredentialsEx(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwLevel,LPBYTE lpbBuffer);
  DWORD WINAPI MprAdminInterfaceGetCredentialsEx(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwLevel,LPBYTE *lplpbBuffer);
  DWORD WINAPI MprAdminInterfaceConnect(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,HANDLE hEvent,WINBOOL fSynchronous);
  DWORD WINAPI MprAdminInterfaceDisconnect(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface);
  DWORD WINAPI MprAdminInterfaceUpdateRoutes(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwProtocolId,HANDLE hEvent);
  DWORD WINAPI MprAdminInterfaceQueryUpdateResult(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface,DWORD dwProtocolId,LPDWORD lpdwUpdateResult);
  DWORD WINAPI MprAdminInterfaceUpdatePhonebookInfo(MPR_SERVER_HANDLE hMprServer,HANDLE hInterface);
  DWORD WINAPI MprAdminRegisterConnectionNotification(MPR_SERVER_HANDLE hMprServer,HANDLE hEventNotification);
  DWORD WINAPI MprAdminDeregisterConnectionNotification(MPR_SERVER_HANDLE hMprServer,HANDLE hEventNotification);
  DWORD WINAPI MprAdminMIBServerConnect(LPWSTR lpwsServerName,MIB_SERVER_HANDLE *phMibServer);
  VOID WINAPI MprAdminMIBServerDisconnect(MIB_SERVER_HANDLE hMibServer);
  DWORD WINAPI MprAdminMIBEntryCreate(MIB_SERVER_HANDLE hMibServer,DWORD dwPid,DWORD dwRoutingPid,LPVOID lpEntry,DWORD dwEntrySize);
  DWORD WINAPI MprAdminMIBEntryDelete(MIB_SERVER_HANDLE hMibServer,DWORD dwProtocolId,DWORD dwRoutingPid,LPVOID lpEntry,DWORD dwEntrySize);
  DWORD WINAPI MprAdminMIBEntrySet(MIB_SERVER_HANDLE hMibServer,DWORD dwProtocolId,DWORD dwRoutingPid,LPVOID lpEntry,DWORD dwEntrySize);
  DWORD WINAPI MprAdminMIBEntryGet(MIB_SERVER_HANDLE hMibServer,DWORD dwProtocolId,DWORD dwRoutingPid,LPVOID lpInEntry,DWORD dwInEntrySize,LPVOID *lplpOutEntry,LPDWORD lpOutEntrySize);
  DWORD WINAPI MprAdminMIBEntryGetFirst(MIB_SERVER_HANDLE hMibServer,DWORD dwProtocolId,DWORD dwRoutingPid,LPVOID lpInEntry,DWORD dwInEntrySize,LPVOID *lplpOutEntry,LPDWORD lpOutEntrySize);
  DWORD WINAPI MprAdminMIBEntryGetNext(MIB_SERVER_HANDLE hMibServer,DWORD dwProtocolId,DWORD dwRoutingPid,LPVOID lpInEntry,DWORD dwInEntrySize,LPVOID *lplpOutEntry,LPDWORD lpOutEntrySize);
  DWORD WINAPI MprAdminMIBGetTrapInfo(MIB_SERVER_HANDLE hMibServer,DWORD dwProtocolId,DWORD dwRoutingPid,LPVOID lpInData,DWORD dwInDataSize,LPVOID *lplpOutData,LPDWORD lpOutDataSize);
  DWORD WINAPI MprAdminMIBSetTrapInfo(DWORD dwProtocolId,DWORD dwRoutingPid,HANDLE hEvent,LPVOID lpInData,DWORD dwInDataSize,LPVOID *lplpOutData,LPDWORD lpOutDataSize);
  DWORD WINAPI MprAdminMIBBufferFree(LPVOID pBuffer);
  DWORD WINAPI MprConfigServerInstall(DWORD dwLevel,PVOID pBuffer);
  DWORD WINAPI MprConfigServerConnect(LPWSTR lpwsServerName,HANDLE *phMprConfig);
  VOID WINAPI MprConfigServerDisconnect(HANDLE hMprConfig);
  DWORD WINAPI MprConfigServerRefresh(HANDLE hMprConfig);
  DWORD WINAPI MprConfigBufferFree(LPVOID pBuffer);
  DWORD WINAPI MprConfigServerGetInfo(HANDLE hMprConfig,DWORD dwLevel,LPBYTE *lplpbBuffer);
  DWORD WINAPI MprConfigServerSetInfo(MPR_SERVER_HANDLE hMprServer,DWORD dwLevel,LPBYTE lpbBuffer);
  DWORD WINAPI MprConfigServerBackup(HANDLE hMprConfig,LPWSTR lpwsPath);
  DWORD WINAPI MprConfigServerRestore(HANDLE hMprConfig,LPWSTR lpwsPath);
  DWORD WINAPI MprConfigTransportCreate(HANDLE hMprConfig,DWORD dwTransportId,LPWSTR lpwsTransportName,LPBYTE pGlobalInfo,DWORD dwGlobalInfoSize,LPBYTE pClientInterfaceInfo,DWORD dwClientInterfaceInfoSize,LPWSTR lpwsDLLPath,HANDLE *phRouterTransport);
  DWORD WINAPI MprConfigTransportDelete(HANDLE hMprConfig,HANDLE hRouterTransport);
  DWORD WINAPI MprConfigTransportGetHandle(HANDLE hMprConfig,DWORD dwTransportId,HANDLE *phRouterTransport);
  DWORD WINAPI MprConfigTransportSetInfo(HANDLE hMprConfig,HANDLE hRouterTransport,LPBYTE pGlobalInfo,DWORD dwGlobalInfoSize,LPBYTE pClientInterfaceInfo,DWORD dwClientInterfaceInfoSize,LPWSTR lpwsDLLPath);
  DWORD WINAPI MprConfigTransportGetInfo(HANDLE hMprConfig,HANDLE hRouterTransport,LPBYTE *ppGlobalInfo,LPDWORD lpdwGlobalInfoSize,LPBYTE *ppClientInterfaceInfo,LPDWORD lpdwClientInterfaceInfoSize,LPWSTR *lplpwsDLLPath);
  DWORD WINAPI MprConfigTransportEnum(HANDLE hMprConfig,DWORD dwLevel,LPBYTE *lplpBuffer,DWORD dwPrefMaxLen,LPDWORD lpdwEntriesRead,LPDWORD lpdwTotalEntries,LPDWORD lpdwResumeHandle);
  DWORD WINAPI MprConfigInterfaceCreate(HANDLE hMprConfig,DWORD dwLevel,LPBYTE lpbBuffer,HANDLE *phRouterInterface);
  DWORD WINAPI MprConfigInterfaceDelete(HANDLE hMprConfig,HANDLE hRouterInterface);
  DWORD WINAPI MprConfigInterfaceGetHandle(HANDLE hMprConfig,LPWSTR lpwsInterfaceName,HANDLE *phRouterInterface);
  DWORD WINAPI MprConfigInterfaceGetInfo(HANDLE hMprConfig,HANDLE hRouterInterface,DWORD dwLevel,LPBYTE *lplpBuffer,LPDWORD lpdwBufferSize);
  DWORD WINAPI MprConfigInterfaceSetInfo(HANDLE hMprConfig,HANDLE hRouterInterface,DWORD dwLevel,LPBYTE lpbBuffer);
  DWORD WINAPI MprConfigInterfaceEnum(HANDLE hMprConfig,DWORD dwLevel,LPBYTE *lplpBuffer,DWORD dwPrefMaxLen,LPDWORD lpdwEntriesRead,LPDWORD lpdwTotalEntries,LPDWORD lpdwResumeHandle);
  DWORD WINAPI MprConfigInterfaceTransportAdd(HANDLE hMprConfig,HANDLE hRouterInterface,DWORD dwTransportId,LPWSTR lpwsTransportName,LPBYTE pInterfaceInfo,DWORD dwInterfaceInfoSize,HANDLE *phRouterIfTransport);
  DWORD WINAPI MprConfigInterfaceTransportRemove(HANDLE hMprConfig,HANDLE hRouterInterface,HANDLE hRouterIfTransport);
  DWORD WINAPI MprConfigInterfaceTransportGetHandle(HANDLE hMprConfig,HANDLE hRouterInterface,DWORD dwTransportId,HANDLE *phRouterIfTransport);
  DWORD WINAPI MprConfigInterfaceTransportGetInfo(HANDLE hMprConfig,HANDLE hRouterInterface,HANDLE hRouterIfTransport,LPBYTE *ppInterfaceInfo,LPDWORD lpdwInterfaceInfoSize);
  DWORD WINAPI MprConfigInterfaceTransportSetInfo(HANDLE hMprConfig,HANDLE hRouterInterface,HANDLE hRouterIfTransport,LPBYTE pInterfaceInfo,DWORD dwInterfaceInfoSize);
  DWORD WINAPI MprConfigInterfaceTransportEnum(HANDLE hMprConfig,HANDLE hRouterInterface,DWORD dwLevel,LPBYTE *lplpBuffer,DWORD dwPrefMaxLen,LPDWORD lpdwEntriesRead,LPDWORD lpdwTotalEntries,LPDWORD lpdwResumeHandle);
  DWORD WINAPI MprConfigGetFriendlyName(HANDLE hMprConfig,PWCHAR pszGuidName,PWCHAR pszBuffer,DWORD dwBufferSize);
  DWORD WINAPI MprConfigGetGuidName(HANDLE hMprConfig,PWCHAR pszFriendlyName,PWCHAR pszBuffer,DWORD dwBufferSize);
  DWORD WINAPI MprInfoCreate(DWORD dwVersion,LPVOID *lplpNewHeader);
  DWORD WINAPI MprInfoDelete(LPVOID lpHeader);
  DWORD WINAPI MprInfoRemoveAll(LPVOID lpHeader,LPVOID *lplpNewHeader);
  DWORD WINAPI MprInfoDuplicate(LPVOID lpHeader,LPVOID *lplpNewHeader);
  DWORD WINAPI MprInfoBlockAdd(LPVOID lpHeader,DWORD dwInfoType,DWORD dwItemSize,DWORD dwItemCount,LPBYTE lpItemData,LPVOID *lplpNewHeader);
  DWORD WINAPI MprInfoBlockRemove(LPVOID lpHeader,DWORD dwInfoType,LPVOID *lplpNewHeader);
  DWORD WINAPI MprInfoBlockSet(LPVOID lpHeader,DWORD dwInfoType,DWORD dwItemSize,DWORD dwItemCount,LPBYTE lpItemData,LPVOID *lplpNewHeader);
  DWORD WINAPI MprInfoBlockFind(LPVOID lpHeader,DWORD dwInfoType,LPDWORD lpdwItemSize,LPDWORD lpdwItemCount,LPBYTE *lplpItemData);
  DWORD WINAPI MprInfoBlockQuerySize(LPVOID lpHeader);

#define MprInfoBlockExists(h,t) (MprInfoBlockFind((h),(t),NULL,NULL,NULL)==NO_ERROR)

#if (_WIN32_WINNT >= 0x0600)
typedef enum _RAS_QUARANTINE_STATE {
  RAS_QUAR_STATE_NORMAL,
  RAS_QUAR_STATE_QUARANTINE,
  RAS_QUAR_STATE_PROBATION,
  RAS_QUAR_STATE_NOT_CAPABLE
} RAS_QUARANTINE_STATE;

typedef struct _MPR_FILTER_0 {
  WINBOOL fEnabled;
} MPR_FILTER_0, *PMPR_FILTER_0;

typedef struct _MPR_SERVER_2 {
  DWORD dwNumPptpPorts;
  DWORD dwPptpPortFlags;
  DWORD dwNumL2tpPorts;
  DWORD dwL2tpPortFlags;
  DWORD dwNumSstpPorts;
  DWORD dwSstpPortFlags;
} MPR_SERVER_2, *PMPR_SERVER_2;

typedef struct _PPP_IPV6CP_INFO {
  DWORD dwVersion;
  DWORD dwSize;
  DWORD dwError;
  BYTE  bInterfaceIdentifier[8];
  BYTE  bRemoteInterfaceIdentifier[8];
  DWORD dwOptions;
  DWORD dwRemoteOptions;
  BYTE  bPrefix[8];
  DWORD dwPrefixLength;
} PPP_IPV6_CP_INFO, *PPPP_IPV6_CP_INFO;

typedef struct _PPP_INFO_3 {
  PPP_NBFCP_INFO   nbf;
  PPP_IPCP_INFO2   ip;
  PPP_IPV6_CP_INFO ipv6;
  PPP_CCP_INFO     ccp;
  PPP_LCP_INFO     lcp;
} PPP_INFO_3;

typedef struct _RAS_CONNECTION_3 {
  DWORD                 dwVersion;
  DWORD                 dwSize;
  HANDLE                hConnection;
  WCHAR                 wszUserName[UNLEN + 1];
  ROUTER_INTERFACE_TYPE dwInterfaceType;
  GUID                  guid;
  PPP_INFO_3            PppInfo3;
  RAS_QUARANTINE_STATE  rasQuarState;
  FILETIME              timer;
} RAS_CONNECTION_3, *PRAS_CONNECTION_3;

WINBOOL CALLBACK MprAdminAcceptNewConnection3(
  RAS_CONNECTION_0 *pRasConnection0,
  RAS_CONNECTION_1 *pRasConnection1,
  RAS_CONNECTION_2 *pRasConnection2,
  RAS_CONNECTION_3 *pRasConnection3
);

WINBOOL CALLBACK MprAdminAcceptReauthentication(
  RAS_CONNECTION_0 *pRasConnection0,
  RAS_CONNECTION_1 *pRasConnection1,
  RAS_CONNECTION_2 *pRasConnection2,
  RAS_CONNECTION_3 *pRasConnection3
);

void CALLBACK MprAdminConnectionHangupNotification3(
  RAS_CONNECTION_0 *pRasConnection0,
  RAS_CONNECTION_1 *pRasConnection1,
  RAS_CONNECTION_2 *pRasConnection2,
  RAS_CONNECTION_3 *pRasConnection3
);

DWORD CALLBACK MprAdminGetIpv6AddressForUser(
  WCHAR *lpwszUserName,
  WCHAR *lpwszPortName,
  IN6_ADDR *lpdwIpv6Address,
  WINBOOL *bNotifyRelease
);

DWORD CALLBACK MprAdminReleaseIpv6AddressForUser(
  WCHAR *lpwszUserName,
  WCHAR *lpwszPortName,
  IN6_ADDR *lpdwIpv6Address
);

DWORD WINAPI MprConfigFilterGetInfo(
  HANDLE hMprConfig,
  DWORD dwLevel,
  DWORD dwTransportId,
  LPBYTE lpBuffer
);

DWORD WINAPI MprConfigFilterSetInfo(
  HANDLE hMprConfig,
  DWORD dwLevel,
  DWORD dwTransportId,
  LPBYTE lpBuffer
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

#if (_WIN32_WINNT >= 0x0601)
#define MPRAPI_RAS_CONNECTION_OBJECT_REVISION_1 0x01
#define MPRAPI_MPR_SERVER_OBJECT_REVISION_1 0x01
#define MPRAPI_MPR_SERVER_SET_CONFIG_OBJECT_REVISION_1 0x01

typedef enum  {
  MPRAPI_OBJECT_TYPE_RAS_CONNECTION_OBJECT          = 0x1,
  MPRAPI_OBJECT_TYPE_MPR_SERVER_OBJECT              = 0x2,
  MPRAPI_OBJECT_TYPE_MPR_SERVER_SET_CONFIG_OBJECT   = 0x3,
  MPRAPI_OBJECT_TYPE_AUTH_VALIDATION_OBJECT         = 0x4,
  MPRAPI_OBJECT_TYPE_UPDATE_CONNECTION_OBJECT       = 0x5 
} MPRAPI_OBJECT_TYPE;

typedef struct _MPRAPI_OBJECT_HEADER {
  UCHAR revision;
  UCHAR  type;
  USHORT size;
} MPRAPI_OBJECT_HEADER, *PMPRAPI_OBJECT_HEADER;

typedef struct _AUTH_VALIDATION_EX {
  MPRAPI_OBJECT_HEADER         Header;
  HANDLE                       hRasConnection;
  WCHAR                        wszUserName[UNLEN + 1 ];
  WCHAR                        wszLogonDomain[DNLEN + 1 ];
  DWORD                        AuthInfoSize;
  BYTE                         AuthInfo[1];
} AUTH_VALIDATION_EX, *PAUTH_VALIDATION_EX;

#define RAS_FLAGS_PPP_CONNECTION 0x00000001
#define RAS_FLAGS_MESSENGER_PRESENT 0x00000002
#define RAS_FLAGS_QUARANTINE_PRESENT 0x00000008
#define RAS_FLAGS_ARAP_CONNECTION 0x00000010
#define RAS_FLAGS_IKEV2_CONNECTION 0x00000010
#define RAS_FLAGS_DORMANT 0x00000020

#define IPADDRESSLEN 15

typedef struct _PPP_PROJECTION_INFO {
  DWORD   dwIPv4NegotiationError;
  WCHAR   wszAddress[IPADDRESSLEN + 1];
  WCHAR   wszRemoteAddress[IPADDRESSLEN + 1];
  DWORD   dwIPv4Options;
  DWORD   dwIPv4RemoteOptions;
  ULONG64 IPv4SubInterfaceIndex;
  DWORD   dwIPv6NegotiationError;
  BYTE    bInterfaceIdentifier[8];
  BYTE    bRemoteInterfaceIdentifier[8];
  BYTE    bPrefix[8];
  DWORD   dwPrefixLength;
  ULONG64 IPv6SubInterfaceIndex;
  DWORD   dwLcpError;
  DWORD   dwAuthenticationProtocol;
  DWORD   dwAuthenticationData;
  DWORD   dwRemoteAuthenticationProtocol;
  DWORD   dwRemoteAuthenticationData;
  DWORD   dwLcpTerminateReason;
  DWORD   dwLcpRemoteTerminateReason;
  DWORD   dwLcpOptions;
  DWORD   dwLcpRemoteOptions;
  DWORD   dwEapTypeId;
  DWORD   dwRemoteEapTypeId;
  DWORD   dwCcpError;
  DWORD   dwCompressionAlgorithm;
  DWORD   dwCcpOptions;
  DWORD   dwRemoteCompressionAlgorithm;
  DWORD   dwCcpRemoteOptions;
} PPP_PROJECTION_INFO, *PPPP_PROJECTION_INFO;

typedef struct _IKEV2_PROJECTION_INFO {
  DWORD   dwIPv4NegotiationError;
  WCHAR   wszAddress[IPADDRESSLEN  + 1];
  WCHAR   wszRemoteAddress[IPADDRESSLEN  + 1];
  ULONG64 IPv4SubInterfaceIndex;
  DWORD   dwIPv6NegotiationError;
  BYTE    bInterfaceIdentifier[8];
  BYTE    bRemoteInterfaceIdentifier[8];
  BYTE    bPrefix[8];
  DWORD   dwPrefixLength;
  ULONG64 IPv6SubInterfaceIndex;
  DWORD   dwOptions;
  DWORD   dwAuthenticationProtocol;
  DWORD   dwEapTypeId;
  DWORD   dwCompressionAlgorithm;
  DWORD   dwEncryptionMethod;
} IKEV2_PROJECTION_INFO, *PIKEV2_PROJECTION_INFO;

typedef struct _PROJECTION_INFO {
  UCHAR projectionInfoType;
  __C89_NAMELESS union {
    IKEV2_PROJECTION_INFO Ikev2ProjectionInfo;
    PPP_PROJECTION_INFO   PppProjectionInfo;
  } DUMMYUNIONNAME;
} PROJECTION_INFO, *PPROJECTION_INFO;

typedef struct _RAS_CONNECTION_EX {
  MPRAPI_OBJECT_HEADER  Header;
  DWORD                 dwConnectDuration;
  ROUTER_INTERFACE_TYPE dwInterfaceType;
  DWORD                 dwConnectionFlags;
  WCHAR                 wszInterfaceName[MAX_INTERFACE_NAME_LEN + 1];
  WCHAR                 wszUserName[UNLEN + 1];
  WCHAR                 wszLogonDomain[DNLEN + 1];
  WCHAR                 wszRemoteComputer[NETBIOS_NAME_LEN + 1];
  GUID                  guid;
  RAS_QUARANTINE_STATE  rasQuarState;
  FILETIME              probationTime;
  DWORD                 dwBytesXmited;
  DWORD                 dwBytesRcved;
  DWORD                 dwFramesXmited;
  DWORD                 dwFramesRcved;
  DWORD                 dwCrcErr;
  DWORD                 dwTimeoutErr;
  DWORD                 dwAlignmentErr;
  DWORD                 dwHardwareOverrunErr;
  DWORD                 dwFramingErr;
  DWORD                 dwBufferOverrunErr;
  DWORD                 dwCompressionRatioIn;
  DWORD                 dwCompressionRatioOut;
  DWORD                 dwNumSwitchOvers;
  WCHAR                 wszRemoteEndpointAddress[MAXIPADRESSLEN+1];
  WCHAR                 wszLocalEndpointAddress[MAXIPADRESSLEN+1];
  PROJECTION_INFO       ProjectionInfo;
  HANDLE                hConnection;
  HANDLE                hInterface;
} RAS_CONNECTION_EX, *PRAS_CONNECTION_EX;

typedef struct _RAS_UPDATE_CONNECTION {
  MPRAPI_OBJECT_HEADER Header;
  DWORD                dwIfIndex;
  WCHAR                wszLocalEndpointAddress[MAXIPADRESSLEN+1];
  WCHAR                wszRemoteEndpointAddress[MAXIPADRESSLEN+1];
} RAS_UPDATE_CONNECTION, *PRAS_UPDATE_CONNECTION;

#define MPRAPI_IKEV2_SET_TUNNEL_CONFIG_PARAMS 0x01

typedef struct _IKEV2_TUNNEL_CONFIG_PARAMS {
  DWORD          dwIdleTimeout;
  DWORD          dwNetworkBlackoutTime;
  DWORD          dwSaLifeTime;
  DWORD          dwSaDataSizeForRenegotiation;
  DWORD          dwConfigOptions;
  DWORD          dwTotalCertificates;
  CERT_NAME_BLOB *certificateNames;
} IKEV2_TUNNEL_CONFIG_PARAMS, *PIKEV2_TUNNEL_CONFIG_PARAMS;

typedef struct _IKEV2_CONFIG_PARAMS {
  DWORD                      dwNumPorts;
  DWORD                      dwPortFlags;
  DWORD                      dwTunnelConfigParamFlags;
  IKEV2_TUNNEL_CONFIG_PARAMS TunnelConfigParams;
} IKEV2_CONFIG_PARAMS, *PIKEV2_CONFIG_PARAMS;

typedef struct _PPTP_CONFIG_PARAMS {
  DWORD dwNumPorts;
  DWORD dwPortFlags;
} PPTP_CONFIG_PARAMS, *PPPTP_CONFIG_PARAMS;

typedef struct _L2TP_CONFIG_PARAMS {
  DWORD dwNumPorts;
  DWORD dwPortFlags;
} L2TP_CONFIG_PARAMS, *PL2TP_CONFIG_PARAMS;

typedef struct _SSTP_CERT_INFO {
  BOOL            isDefault;
  CRYPT_HASH_BLOB certBlob;
} SSTP_CERT_INFO, *PSSTP_CERT_INFO;

typedef struct _SSTP_CONFIG_PARAMS {
  DWORD          dwNumPorts;
  DWORD          dwPortFlags;
  BOOL           isUseHttps;
  DWORD          certAlgorithm;
  SSTP_CERT_INFO sstpCertDetails;
} SSTP_CONFIG_PARAMS, *PSSTP_CONFIG_PARAMS;

typedef struct _MPRAPI_TUNNEL_CONFIG_PARAMS {
  IKEV2_CONFIG_PARAMS IkeConfigParams;
  PPTP_CONFIG_PARAMS  PptpConfigParams;
  L2TP_CONFIG_PARAMS  L2tpConfigParams;
  SSTP_CONFIG_PARAMS  SstpConfigParams;
} MPRAPI_TUNNEL_CONFIG_PARAMS, *PMPRAPI_TUNNEL_CONFIG_PARAMS;

typedef struct _MPR_SERVER_SET_CONFIG_EX {
  MPRAPI_OBJECT_HEADER        Header;
  DWORD                       setConfigForProtocols;
  MPRAPI_TUNNEL_CONFIG_PARAMS ConfigParams;
} MPR_SERVER_SET_CONFIG_EX, *PMPR_SERVER_SET_CONFIG_EX;

typedef struct _MPR_SERVER_EX {
  MPRAPI_OBJECT_HEADER        Header;
  DWORD                       fLanOnlyMode;
  DWORD                       dwUpTime;
  DWORD                       dwTotalPorts;
  DWORD                       dwPortsInUse;
  DWORD                       Reserved;
  MPRAPI_TUNNEL_CONFIG_PARAMS ConfigParams;
} MPR_SERVER_EX, *PMPR_SERVER_EX;

typedef DWORD (APIENTRY * PMPRADMINGETIPADDRESSFORUSER)(WCHAR *, WCHAR *, DWORD *, WINBOOL *);
typedef VOID  (APIENTRY * PMPRADMINRELEASEIPADRESS)(WCHAR *, WCHAR *, DWORD *);
typedef DWORD (APIENTRY * PMPRADMINGETIPV6ADDRESSFORUSER)(WCHAR *, WCHAR *, IN6_ADDR *, WINBOOL *);
typedef VOID  (APIENTRY * PMPRADMINRELEASEIPV6ADDRESSFORUSER)(WCHAR *, WCHAR *, IN6_ADDR *);
typedef WINBOOL (APIENTRY * PMPRADMINACCEPTNEWLINK)(RAS_PORT_0 *, RAS_PORT_1 *);
typedef VOID  (APIENTRY * PMPRADMINLINKHANGUPNOTIFICATION)(RAS_PORT_0 *, RAS_PORT_1 *);
typedef DWORD (APIENTRY * PMPRADMINTERMINATEDLL)();
typedef BOOL  (APIENTRY * PMPRADMINACCEPTNEWCONNECTIONEX)(RAS_CONNECTION_EX *);
typedef BOOL  (APIENTRY * PMPRADMINACCEPTREAUTHENTICATIONEX)(RAS_CONNECTION_EX *);
typedef VOID  (APIENTRY * PMPRADMINCONNECTIONHANGUPNOTIFICATIONEX)(RAS_CONNECTION_EX *);

typedef struct _MPRAPI_ADMIN_DLL_CALLBACKS {
  UCHAR                                   revision;
  PMPRADMINGETIPADDRESSFORUSER            lpfnMprAdminGetIpAddressForUser;
  PMPRADMINRELEASEIPADRESS                lpfnMprAdminReleaseIpAddress;
  PMPRADMINGETIPV6ADDRESSFORUSER          lpfnMprAdminGetIpv6AddressForUser;
  PMPRADMINRELEASEIPV6ADDRESSFORUSER      lpfnMprAdminReleaseIpV6AddressForUser;
  PMPRADMINACCEPTNEWLINK                  lpfnRasAdminAcceptNewLink;
  PMPRADMINLINKHANGUPNOTIFICATION         lpfnRasAdminLinkHangupNotification;
  PMPRADMINTERMINATEDLL                   lpfnRasAdminTerminateDll;
  PMPRADMINACCEPTNEWCONNECTIONEX          lpfnRasAdminAcceptNewConnectionEx;
  PMPRADMINACCEPTREAUTHENTICATIONEX       lpfnRasAdminAcceptReauthenticationEx;
  PMPRADMINCONNECTIONHANGUPNOTIFICATIONEX lpfnRasAdminConnectionHangupNotificationEx;
} MPRAPI_ADMIN_DLL_CALLBACKS, *PMPRAPI_ADMIN_DLL_CALLBACKS;

DWORD APIENTRY MprConfigServerSetInfoEx(HANDLE hMprConfig,MPR_SERVER_SET_CONFIG_EX *pSetServerConfig);

DWORD APIENTRY MprConfigServerGetInfoEx(
  HANDLE hMprConfig,
  MPR_SERVER_EX *pServerInfo
);

DWORD APIENTRY MprAdminConnectionEnumEx(
  RAS_SERVER_HANDLE hRasServer,
  PMPRAPI_OBJECT_HEADER pObjectHeader,
  DWORD dwPreferedMaxLen,
  LPDWORD lpdwEntriesRead,
  LPDWORD lpdwTotalEntries,
  PRAS_CONNECTION_EX *ppRasConn,
  LPDWORD lpdwResumeHandle
);

DWORD APIENTRY MprAdminConnectionGetInfoEx(
  RAS_SERVER_HANDLE hRasServer,
  HANDLE hConnection,
  PRAS_CONNECTION_EX pRasConnection
);

DWORD APIENTRY MprAdminInitializeDllEx(
  PMPRAPI_ADMIN_DLL_CALLBACKS pAdminCallbacks
);

DWORD APIENTRY MprAdminIsServiceInitialized(
  LPWSTR   lpwsServerName,
  WINBOOL  *fIsServiceInitialized
);

DWORD APIENTRY MprAdminServerGetInfoEx(
  MPR_SERVER_HANDLE hMprServer,
  MPR_SERVER_EX *pServerInfo
);

DWORD APIENTRY MprAdminServerSetInfoEx(
  MPR_SERVER_HANDLE hMprServer,
  MPR_SERVER_SET_CONFIG_EX *pServerInfo
);

#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) */

#endif /* __ROUTING_MPRADMIN_H__ */
