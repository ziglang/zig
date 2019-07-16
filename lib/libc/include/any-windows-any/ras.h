/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef _RAS_H_
#define _RAS_H_

#include <_mingw_unicode.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <inaddr.h>
#include <in6addr.h>
#include <naptypes.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct in_addr RASIPV4ADDR;
typedef struct in6_addr RASIPV6ADDR;


#ifndef UNLEN
#include <lmcons.h>
#endif

#include <pshpack4.h>

#define RAS_MaxDeviceType 16
#define RAS_MaxPhoneNumber 128
#define RAS_MaxIpAddress 15
#define RAS_MaxIpxAddress 21

#define RAS_MaxEntryName 256
#define RAS_MaxDeviceName 128
#define RAS_MaxCallbackNumber RAS_MaxPhoneNumber
#define RAS_MaxAreaCode 10
#define RAS_MaxPadType 32
#define RAS_MaxX25Address 200
#define RAS_MaxFacilities 200
#define RAS_MaxUserData 200
#define RAS_MaxReplyMessage 1024
#define RAS_MaxDnsSuffix 256

  DECLARE_HANDLE(HRASCONN);
#define LPHRASCONN HRASCONN*

#define RASCF_AllUsers 0x00000001
#define RASCF_GlobalCreds 0x00000002

#define RASCONNW struct tagRASCONNW
  RASCONNW {
    DWORD dwSize;
    HRASCONN hrasconn;
    WCHAR szEntryName[RAS_MaxEntryName + 1 ];

    WCHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    WCHAR szDeviceName[RAS_MaxDeviceName + 1 ];
    WCHAR szPhonebook [MAX_PATH ];
    DWORD dwSubEntry;
    GUID guidEntry;
    DWORD dwFlags;
    LUID luid;
  };

#define RASCONNA struct tagRASCONNA
  RASCONNA {
    DWORD dwSize;
    HRASCONN hrasconn;
    CHAR szEntryName[RAS_MaxEntryName + 1 ];
    CHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    CHAR szDeviceName[RAS_MaxDeviceName + 1 ];
    CHAR szPhonebook [MAX_PATH ];
    DWORD dwSubEntry;
    GUID guidEntry;
    DWORD dwFlags;
    LUID luid;
  };

#define RASCONN __MINGW_NAME_AW(RASCONN)

#define LPRASCONNW RASCONNW*
#define LPRASCONNA RASCONNA*
#define LPRASCONN RASCONN*

#define RASCS_PAUSED 0x1000
#define RASCS_DONE 0x2000

#define RASCONNSTATE enum tagRASCONNSTATE
  RASCONNSTATE {
    RASCS_OpenPort = 0,RASCS_PortOpened,RASCS_ConnectDevice,RASCS_DeviceConnected,RASCS_AllDevicesConnected,RASCS_Authenticate,
    RASCS_AuthNotify,RASCS_AuthRetry,RASCS_AuthCallback,RASCS_AuthChangePassword,RASCS_AuthProject,RASCS_AuthLinkSpeed,
    RASCS_AuthAck,RASCS_ReAuthenticate,RASCS_Authenticated,RASCS_PrepareForCallback,RASCS_WaitForModemReset,RASCS_WaitForCallback,RASCS_Projected,
    RASCS_StartAuthentication,RASCS_CallbackComplete,RASCS_LogonNetwork,RASCS_SubEntryConnected,
    RASCS_SubEntryDisconnected,RASCS_Interactive = RASCS_PAUSED,RASCS_RetryAuthentication,RASCS_CallbackSetByCaller,RASCS_PasswordExpired,
    RASCS_InvokeEapUI,RASCS_Connected = RASCS_DONE,RASCS_Disconnected
  };

#define LPRASCONNSTATE RASCONNSTATE*

#define RASCONNSTATUSW struct tagRASCONNSTATUSW
  RASCONNSTATUSW {
    DWORD dwSize;
    RASCONNSTATE rasconnstate;
    DWORD dwError;
    WCHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    WCHAR szDeviceName[RAS_MaxDeviceName + 1 ];
    WCHAR szPhoneNumber[RAS_MaxPhoneNumber + 1 ];
  };

#define RASCONNSTATUSA struct tagRASCONNSTATUSA
  RASCONNSTATUSA {
    DWORD dwSize;
    RASCONNSTATE rasconnstate;
    DWORD dwError;
    CHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    CHAR szDeviceName[RAS_MaxDeviceName + 1 ];
    CHAR szPhoneNumber[RAS_MaxPhoneNumber + 1 ];
  };

#define RASCONNSTATUS __MINGW_NAME_AW(RASCONNSTATUS)

#define LPRASCONNSTATUSW RASCONNSTATUSW*
#define LPRASCONNSTATUSA RASCONNSTATUSA*
#define LPRASCONNSTATUS RASCONNSTATUS*

#define RASDIALPARAMSW struct tagRASDIALPARAMSW
  RASDIALPARAMSW {
    DWORD dwSize;
    WCHAR szEntryName[RAS_MaxEntryName + 1 ];
    WCHAR szPhoneNumber[RAS_MaxPhoneNumber + 1 ];
    WCHAR szCallbackNumber[RAS_MaxCallbackNumber + 1 ];
    WCHAR szUserName[UNLEN + 1 ];
    WCHAR szPassword[PWLEN + 1 ];
    WCHAR szDomain[DNLEN + 1 ];
    DWORD dwSubEntry;
    ULONG_PTR dwCallbackId;
#if _WIN32_WINNT >= 0x0601
    DWORD dwIfIndex;
#endif
  };

#define RASDIALPARAMSA struct tagRASDIALPARAMSA
  RASDIALPARAMSA {
    DWORD dwSize;
    CHAR szEntryName[RAS_MaxEntryName + 1 ];
    CHAR szPhoneNumber[RAS_MaxPhoneNumber + 1 ];
    CHAR szCallbackNumber[RAS_MaxCallbackNumber + 1 ];
    CHAR szUserName[UNLEN + 1 ];
    CHAR szPassword[PWLEN + 1 ];
    CHAR szDomain[DNLEN + 1 ];
    DWORD dwSubEntry;
    ULONG_PTR dwCallbackId;
#if _WIN32_WINNT >= 0x0601
    DWORD dwIfIndex;
#endif
  };

#define RASDIALPARAMS __MINGW_NAME_AW(RASDIALPARAMS)

#define LPRASDIALPARAMSW RASDIALPARAMSW*
#define LPRASDIALPARAMSA RASDIALPARAMSA*
#define LPRASDIALPARAMS RASDIALPARAMS*

#define RASEAPINFO struct tagRASEAPINFO
  RASEAPINFO {
    DWORD dwSizeofEapInfo;
    BYTE *pbEapInfo;
  };

#define RASDIALEXTENSIONS struct tagRASDIALEXTENSIONS
  RASDIALEXTENSIONS {
    DWORD dwSize;
    DWORD dwfOptions;
    HWND hwndParent;
    ULONG_PTR reserved;
    ULONG_PTR reserved1;
    RASEAPINFO RasEapInfo;
  };

#define LPRASDIALEXTENSIONS RASDIALEXTENSIONS*

#define RDEOPT_UsePrefixSuffix 0x00000001
#define RDEOPT_PausedStates 0x00000002
#define RDEOPT_IgnoreModemSpeaker 0x00000004
#define RDEOPT_SetModemSpeaker 0x00000008
#define RDEOPT_IgnoreSoftwareCompression 0x00000010
#define RDEOPT_SetSoftwareCompression 0x00000020
#define RDEOPT_DisableConnectedUI 0x00000040
#define RDEOPT_DisableReconnectUI 0x00000080
#define RDEOPT_DisableReconnect 0x00000100
#define RDEOPT_NoUser 0x00000200
#define RDEOPT_PauseOnScript 0x00000400
#define RDEOPT_Router 0x00000800
#define RDEOPT_CustomDial 0x00001000
#define RDEOPT_UseCustomScripting 0x00002000

#define REN_User 0x00000000
#define REN_AllUsers 0x00000001

#define RASENTRYNAMEW struct tagRASENTRYNAMEW
  RASENTRYNAMEW {
    DWORD dwSize;
    WCHAR szEntryName[RAS_MaxEntryName + 1 ];
    DWORD dwFlags;
    WCHAR szPhonebookPath[MAX_PATH + 1];
  };

#define RASENTRYNAMEA struct tagRASENTRYNAMEA
  RASENTRYNAMEA {
    DWORD dwSize;
    CHAR szEntryName[RAS_MaxEntryName + 1 ];
    DWORD dwFlags;
    CHAR szPhonebookPath[MAX_PATH + 1];
  };

#define RASENTRYNAME __MINGW_NAME_AW(RASENTRYNAME)

#define LPRASENTRYNAMEW RASENTRYNAMEW*
#define LPRASENTRYNAMEA RASENTRYNAMEA*
#define LPRASENTRYNAME RASENTRYNAME*

#define RASPROJECTION enum tagRASPROJECTION
  RASPROJECTION {
    RASP_Amb = 0x10000,RASP_PppNbf = 0x803F,RASP_PppIpx = 0x802B,RASP_PppIp = 0x8021,
    RASP_PppCcp = 0x80FD,RASP_PppLcp = 0xC021,RASP_Slip = 0x20000
  };

#define LPRASPROJECTION RASPROJECTION *

#define RASAMBW struct tagRASAMBW
  RASAMBW {
    DWORD dwSize;
    DWORD dwError;
    WCHAR szNetBiosError[NETBIOS_NAME_LEN + 1 ];
    BYTE bLana;
  };

#define RASAMBA struct tagRASAMBA
  RASAMBA {
    DWORD dwSize;
    DWORD dwError;
    CHAR szNetBiosError[NETBIOS_NAME_LEN + 1 ];
    BYTE bLana;
  };

#define RASAMB __MINGW_NAME_AW(RASAMB)

#define LPRASAMBW RASAMBW*
#define LPRASAMBA RASAMBA*
#define LPRASAMB RASAMB*

#define RASPPPNBFW struct tagRASPPPNBFW
  RASPPPNBFW {
    DWORD dwSize;
    DWORD dwError;
    DWORD dwNetBiosError;
    WCHAR szNetBiosError[NETBIOS_NAME_LEN + 1 ];
    WCHAR szWorkstationName[NETBIOS_NAME_LEN + 1 ];
    BYTE bLana;
  };

#define RASPPPNBFA struct tagRASPPPNBFA
  RASPPPNBFA {
    DWORD dwSize;
    DWORD dwError;
    DWORD dwNetBiosError;
    CHAR szNetBiosError[NETBIOS_NAME_LEN + 1 ];
    CHAR szWorkstationName[NETBIOS_NAME_LEN + 1 ];
    BYTE bLana;
  };

#define RASPPPNBF __MINGW_NAME_AW(RASPPPNBF)

#define LPRASPPPNBFW RASPPPNBFW*
#define LPRASPPPNBFA RASPPPNBFA*
#define LPRASPPPNBF RASPPPNBF*

#define RASPPPIPXW struct tagRASIPXW
  RASPPPIPXW {
    DWORD dwSize;
    DWORD dwError;
    WCHAR szIpxAddress[RAS_MaxIpxAddress + 1 ];
  };

#define RASPPPIPXA struct tagRASPPPIPXA
  RASPPPIPXA {
    DWORD dwSize;
    DWORD dwError;
    CHAR szIpxAddress[RAS_MaxIpxAddress + 1 ];
  };

#define RASPPPIPX __MINGW_NAME_AW(RASPPPIPX)

#define LPRASPPPIPXW RASPPPIPXW *
#define LPRASPPPIPXA RASPPPIPXA *
#define LPRASPPPIPX RASPPPIPX *

#define RASIPO_VJ 0x00000001

#define RASPPPIPW struct tagRASPPPIPW
  RASPPPIPW {
    DWORD dwSize;
    DWORD dwError;
    WCHAR szIpAddress[RAS_MaxIpAddress + 1 ];

#ifndef WINNT35COMPATIBLE

    WCHAR szServerIpAddress[RAS_MaxIpAddress + 1 ];
#endif
    DWORD dwOptions;
    DWORD dwServerOptions;
  };

#define RASPPPIPA struct tagRASPPPIPA
  RASPPPIPA {
    DWORD dwSize;
    DWORD dwError;
    CHAR szIpAddress[RAS_MaxIpAddress + 1 ];
#ifndef WINNT35COMPATIBLE
    CHAR szServerIpAddress[RAS_MaxIpAddress + 1 ];
#endif
    DWORD dwOptions;
    DWORD dwServerOptions;
  };

#define RASPPPIP __MINGW_NAME_AW(RASPPPIP)

#define LPRASPPPIPW RASPPPIPW*
#define LPRASPPPIPA RASPPPIPA*
#define LPRASPPPIP RASPPPIP*

#define RASLCPAP_PAP 0xC023
#define RASLCPAP_SPAP 0xC027
#define RASLCPAP_CHAP 0xC223
#define RASLCPAP_EAP 0xC227

#define RASLCPAD_CHAP_MD5 0x05
#define RASLCPAD_CHAP_MS 0x80
#define RASLCPAD_CHAP_MSV2 0x81

#define RASLCPO_PFC 0x00000001
#define RASLCPO_ACFC 0x00000002
#define RASLCPO_SSHF 0x00000004
#define RASLCPO_DES_56 0x00000008
#define RASLCPO_3_DES 0x00000010

#define RASPPPLCPW struct tagRASPPPLCPW
  RASPPPLCPW {
    DWORD dwSize;
    WINBOOL fBundled;
    DWORD dwError;
    DWORD dwAuthenticationProtocol;
    DWORD dwAuthenticationData;
    DWORD dwEapTypeId;
    DWORD dwServerAuthenticationProtocol;
    DWORD dwServerAuthenticationData;
    DWORD dwServerEapTypeId;
    WINBOOL fMultilink;
    DWORD dwTerminateReason;
    DWORD dwServerTerminateReason;
    WCHAR szReplyMessage[RAS_MaxReplyMessage];
    DWORD dwOptions;
    DWORD dwServerOptions;
  };

#define RASPPPLCPA struct tagRASPPPLCPA
  RASPPPLCPA {
    DWORD dwSize;
    WINBOOL fBundled;
    DWORD dwError;
    DWORD dwAuthenticationProtocol;
    DWORD dwAuthenticationData;
    DWORD dwEapTypeId;
    DWORD dwServerAuthenticationProtocol;
    DWORD dwServerAuthenticationData;
    DWORD dwServerEapTypeId;
    WINBOOL fMultilink;
    DWORD dwTerminateReason;
    DWORD dwServerTerminateReason;
    CHAR szReplyMessage[RAS_MaxReplyMessage];
    DWORD dwOptions;
    DWORD dwServerOptions;
  };

#define RASPPPLCP __MINGW_NAME_AW(RASPPPLCP)

#define LPRASPPPLCPW RASPPPLCPW *
#define LPRASPPPLCPA RASPPPLCPA *
#define LPRASPPPLCP RASPPPLCP *

#define RASSLIPW struct tagRASSLIPW
  RASSLIPW {
    DWORD dwSize;
    DWORD dwError;
    WCHAR szIpAddress[RAS_MaxIpAddress + 1 ];
  };

#define RASSLIPA struct tagRASSLIPA
  RASSLIPA {
    DWORD dwSize;
    DWORD dwError;
    CHAR szIpAddress[RAS_MaxIpAddress + 1 ];
  };

#define RASSLIP __MINGW_NAME_AW(RASSLIP)

#define LPRASSLIPW RASSLIPW*
#define LPRASSLIPA RASSLIPA*
#define LPRASSLIP RASSLIP*

#define RASCCPCA_MPPC 0x00000006
#define RASCCPCA_STAC 0x00000005

#define RASCCPO_Compression 0x00000001
#define RASCCPO_HistoryLess 0x00000002
#define RASCCPO_Encryption56bit 0x00000010
#define RASCCPO_Encryption40bit 0x00000020
#define RASCCPO_Encryption128bit 0x00000040

#define RASPPPCCP struct tagRASPPPCCP
  RASPPPCCP {
    DWORD dwSize;
    DWORD dwError;
    DWORD dwCompressionAlgorithm;
    DWORD dwOptions;
    DWORD dwServerCompressionAlgorithm;
    DWORD dwServerOptions;
  };

#define LPRASPPPCCP RASPPPCCP *

#define RASDIALEVENT "RasDialEvent"
#define WM_RASDIALEVENT 0xCCCD

  typedef VOID (WINAPI *RASDIALFUNC)(UINT,RASCONNSTATE,DWORD);
  typedef VOID (WINAPI *RASDIALFUNC1)(HRASCONN,UINT,RASCONNSTATE,DWORD,DWORD);
  typedef DWORD (WINAPI *RASDIALFUNC2)(ULONG_PTR,DWORD,HRASCONN,UINT,RASCONNSTATE,DWORD,DWORD);

#define RASDEVINFOW struct tagRASDEVINFOW
  RASDEVINFOW {
    DWORD dwSize;
    WCHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    WCHAR szDeviceName[RAS_MaxDeviceName + 1 ];
  };

#define RASDEVINFOA struct tagRASDEVINFOA
  RASDEVINFOA {
    DWORD dwSize;
    CHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    CHAR szDeviceName[RAS_MaxDeviceName + 1 ];
  };

#define RASDEVINFO __MINGW_NAME_AW(RASDEVINFO)

#define LPRASDEVINFOW RASDEVINFOW*
#define LPRASDEVINFOA RASDEVINFOA*
#define LPRASDEVINFO RASDEVINFO*

#define RASCTRYINFO struct RASCTRYINFO
  RASCTRYINFO {
    DWORD dwSize;
    DWORD dwCountryID;
    DWORD dwNextCountryID;
    DWORD dwCountryCode;
    DWORD dwCountryNameOffset;
  };

#define RASCTRYINFOW RASCTRYINFO
#define RASCTRYINFOA RASCTRYINFO

#define LPRASCTRYINFOW RASCTRYINFOW*
#define LPRASCTRYINFOA RASCTRYINFOW*
#define LPRASCTRYINFO RASCTRYINFO*

#define RASIPADDR struct RASIPADDR
  RASIPADDR {
    BYTE a;
    BYTE b;
    BYTE c;
    BYTE d;
  };

#define ET_None 0
#define ET_Require 1
#define ET_RequireMax 2
#define ET_Optional 3

#define VS_Default 0
#define VS_PptpOnly 1
#define VS_PptpFirst 2
#define VS_L2tpOnly 3
#define VS_L2tpFirst 4

#define RASENTRYA struct tagRASENTRYA
  RASENTRYA {
    DWORD dwSize;
    DWORD dwfOptions;
    DWORD dwCountryID;
    DWORD dwCountryCode;
    CHAR szAreaCode[RAS_MaxAreaCode + 1 ];
    CHAR szLocalPhoneNumber[RAS_MaxPhoneNumber + 1 ];
    DWORD dwAlternateOffset;
    RASIPADDR ipaddr;
    RASIPADDR ipaddrDns;
    RASIPADDR ipaddrDnsAlt;
    RASIPADDR ipaddrWins;
    RASIPADDR ipaddrWinsAlt;
    DWORD dwFrameSize;
    DWORD dwfNetProtocols;
    DWORD dwFramingProtocol;
    CHAR szScript[MAX_PATH ];
    CHAR szAutodialDll[MAX_PATH ];
    CHAR szAutodialFunc[MAX_PATH ];
    CHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    CHAR szDeviceName[RAS_MaxDeviceName + 1 ];
    CHAR szX25PadType[RAS_MaxPadType + 1 ];
    CHAR szX25Address[RAS_MaxX25Address + 1 ];
    CHAR szX25Facilities[RAS_MaxFacilities + 1 ];
    CHAR szX25UserData[RAS_MaxUserData + 1 ];
    DWORD dwChannels;
    DWORD dwReserved1;
    DWORD dwReserved2;
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
    GUID guidId;
    CHAR szCustomDialDll[MAX_PATH];
    DWORD dwVpnStrategy;
    DWORD dwfOptions2;
    DWORD dwfOptions3;
    CHAR szDnsSuffix[RAS_MaxDnsSuffix];
    DWORD dwTcpWindowSize;
    CHAR szPrerequisitePbk[MAX_PATH];
    CHAR szPrerequisiteEntry[RAS_MaxEntryName + 1];
    DWORD dwRedialCount;
    DWORD dwRedialPause;
  };

#define RASENTRYW struct tagRASENTRYW
  RASENTRYW {
    DWORD dwSize;
    DWORD dwfOptions;
    DWORD dwCountryID;
    DWORD dwCountryCode;
    WCHAR szAreaCode[RAS_MaxAreaCode + 1 ];
    WCHAR szLocalPhoneNumber[RAS_MaxPhoneNumber + 1 ];
    DWORD dwAlternateOffset;
    RASIPADDR ipaddr;
    RASIPADDR ipaddrDns;
    RASIPADDR ipaddrDnsAlt;
    RASIPADDR ipaddrWins;
    RASIPADDR ipaddrWinsAlt;
    DWORD dwFrameSize;
    DWORD dwfNetProtocols;
    DWORD dwFramingProtocol;
    WCHAR szScript[MAX_PATH ];
    WCHAR szAutodialDll[MAX_PATH ];
    WCHAR szAutodialFunc[MAX_PATH ];
    WCHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    WCHAR szDeviceName[RAS_MaxDeviceName + 1 ];
    WCHAR szX25PadType[RAS_MaxPadType + 1 ];
    WCHAR szX25Address[RAS_MaxX25Address + 1 ];
    WCHAR szX25Facilities[RAS_MaxFacilities + 1 ];
    WCHAR szX25UserData[RAS_MaxUserData + 1 ];
    DWORD dwChannels;
    DWORD dwReserved1;
    DWORD dwReserved2;
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
    GUID guidId;
    WCHAR szCustomDialDll[MAX_PATH];
    DWORD dwVpnStrategy;
    DWORD dwfOptions2;
    DWORD dwfOptions3;
    WCHAR szDnsSuffix[RAS_MaxDnsSuffix];
    DWORD dwTcpWindowSize;
    WCHAR szPrerequisitePbk[MAX_PATH];
    WCHAR szPrerequisiteEntry[RAS_MaxEntryName + 1];
    DWORD dwRedialCount;
    DWORD dwRedialPause;
  };

#define RASENTRY __MINGW_NAME_AW(RASENTRY)

#define LPRASENTRYW RASENTRYW*
#define LPRASENTRYA RASENTRYA*
#define LPRASENTRY RASENTRY*

#define RASEO_UseCountryAndAreaCodes 0x00000001
#define RASEO_SpecificIpAddr 0x00000002
#define RASEO_SpecificNameServers 0x00000004
#define RASEO_IpHeaderCompression 0x00000008
#define RASEO_RemoteDefaultGateway 0x00000010
#define RASEO_DisableLcpExtensions 0x00000020
#define RASEO_TerminalBeforeDial 0x00000040
#define RASEO_TerminalAfterDial 0x00000080
#define RASEO_ModemLights 0x00000100
#define RASEO_SwCompression 0x00000200
#define RASEO_RequireEncryptedPw 0x00000400
#define RASEO_RequireMsEncryptedPw 0x00000800
#define RASEO_RequireDataEncryption 0x00001000
#define RASEO_NetworkLogon 0x00002000
#define RASEO_UseLogonCredentials 0x00004000
#define RASEO_PromoteAlternates 0x00008000
#define RASEO_SecureLocalFiles 0x00010000
#define RASEO_RequireEAP 0x00020000
#define RASEO_RequirePAP 0x00040000
#define RASEO_RequireSPAP 0x00080000
#define RASEO_Custom 0x00100000
#define RASEO_PreviewPhoneNumber 0x00200000
#define RASEO_SharedPhoneNumbers 0x00800000
#define RASEO_PreviewUserPw 0x01000000
#define RASEO_PreviewDomain 0x02000000
#define RASEO_ShowDialingProgress 0x04000000
#define RASEO_RequireCHAP 0x08000000
#define RASEO_RequireMsCHAP 0x10000000
#define RASEO_RequireMsCHAP2 0x20000000
#define RASEO_RequireW95MSCHAP 0x40000000
#define RASEO_CustomScript 0x80000000

#define RASEO2_SecureFileAndPrint 0x00000001
#define RASEO2_SecureClientForMSNet 0x00000002
#define RASEO2_DontNegotiateMultilink 0x00000004
#define RASEO2_DontUseRasCredentials 0x00000008
#define RASEO2_UsePreSharedKey 0x00000010
#define RASEO2_Internet 0x00000020
#define RASEO2_DisableNbtOverIP 0x00000040
#define RASEO2_UseGlobalDeviceSettings 0x00000080
#define RASEO2_ReconnectIfDropped 0x00000100
#define RASEO2_SharePhoneNumbers 0x00000200

#define RASNP_NetBEUI 0x00000001
#define RASNP_Ipx 0x00000002
#define RASNP_Ip 0x00000004

#define RASFP_Ppp 0x00000001
#define RASFP_Slip 0x00000002
#define RASFP_Ras 0x00000004

#define RASDT_Modem TEXT("modem")
#define RASDT_Isdn TEXT("isdn")
#define RASDT_X25 TEXT("x25")
#define RASDT_Vpn TEXT("vpn")
#define RASDT_Pad TEXT("pad")
#define RASDT_Generic TEXT("GENERIC")
#define RASDT_Serial TEXT("SERIAL")
#define RASDT_FrameRelay TEXT("FRAMERELAY")
#define RASDT_Atm TEXT("ATM")
#define RASDT_Sonet TEXT("SONET")
#define RASDT_SW56 TEXT("SW56")
#define RASDT_Irda TEXT("IRDA")
#define RASDT_Parallel TEXT("PARALLEL")
#define RASDT_PPPoE TEXT("PPPoE")

#define RASET_Phone 1
#define RASET_Vpn 2
#define RASET_Direct 3
#define RASET_Internet 4
#define RASET_Broadband 5

  typedef WINBOOL (WINAPI *ORASADFUNC)(HWND,LPSTR,DWORD,LPDWORD);

#define RASCN_Connection 0x00000001
#define RASCN_Disconnection 0x00000002
#define RASCN_BandwidthAdded 0x00000004
#define RASCN_BandwidthRemoved 0x00000008

#define RASEDM_DialAll 1
#define RASEDM_DialAsNeeded 2

#define RASIDS_Disabled 0xffffffff
#define RASIDS_UseGlobalValue 0

#define RASADPARAMS struct tagRASADPARAMS
  RASADPARAMS {
    DWORD dwSize;
    HWND hwndOwner;
    DWORD dwFlags;
    LONG xDlg;
    LONG yDlg;
  };

#define LPRASADPARAMS RASADPARAMS*

#define RASADFLG_PositionDlg 0x00000001

  typedef WINBOOL (WINAPI *RASADFUNCA)(LPSTR,LPSTR,LPRASADPARAMS,LPDWORD);
  typedef WINBOOL (WINAPI *RASADFUNCW)(LPWSTR,LPWSTR,LPRASADPARAMS,LPDWORD);

#define RASADFUNC __MINGW_NAME_AW(RASADFUNC)

#define RASSUBENTRYA struct tagRASSUBENTRYA
  RASSUBENTRYA {
    DWORD dwSize;
    DWORD dwfFlags;
    CHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    CHAR szDeviceName[RAS_MaxDeviceName + 1 ];
    CHAR szLocalPhoneNumber[RAS_MaxPhoneNumber + 1 ];
    DWORD dwAlternateOffset;
  };

#define RASSUBENTRYW struct tagRASSUBENTRYW
  RASSUBENTRYW {
    DWORD dwSize;
    DWORD dwfFlags;
    WCHAR szDeviceType[RAS_MaxDeviceType + 1 ];
    WCHAR szDeviceName[RAS_MaxDeviceName + 1 ];
    WCHAR szLocalPhoneNumber[RAS_MaxPhoneNumber + 1 ];
    DWORD dwAlternateOffset;
  };

#define RASSUBENTRY __MINGW_NAME_AW(RASSUBENTRY)

#define LPRASSUBENTRYW RASSUBENTRYW*
#define LPRASSUBENTRYA RASSUBENTRYA*
#define LPRASSUBENTRY RASSUBENTRY*

#define RASCREDENTIALSA struct tagRASCREDENTIALSA
  RASCREDENTIALSA {
    DWORD dwSize;
    DWORD dwMask;
    CHAR szUserName[UNLEN + 1 ];
    CHAR szPassword[PWLEN + 1 ];
    CHAR szDomain[DNLEN + 1 ];
  };

#define RASCREDENTIALSW struct tagRASCREDENTIALSW
  RASCREDENTIALSW {
    DWORD dwSize;
    DWORD dwMask;
    WCHAR szUserName[UNLEN + 1 ];
    WCHAR szPassword[PWLEN + 1 ];
    WCHAR szDomain[DNLEN + 1 ];
  };

#define RASCREDENTIALS __MINGW_NAME_AW(RASCREDENTIALS)

#define LPRASCREDENTIALSW RASCREDENTIALSW*
#define LPRASCREDENTIALSA RASCREDENTIALSA*
#define LPRASCREDENTIALS RASCREDENTIALS*

#define RASCM_UserName 0x00000001
#define RASCM_Password 0x00000002
#define RASCM_Domain 0x00000004
#define RASCM_DefaultCreds 0x00000008
#define RASCM_PreSharedKey 0x00000010
#define RASCM_ServerPreSharedKey 0x00000020
#define RASCM_DDMPreSharedKey 0x00000040

#define RASAUTODIALENTRYA struct tagRASAUTODIALENTRYA
  RASAUTODIALENTRYA {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwDialingLocation;
    CHAR szEntry[RAS_MaxEntryName + 1];
  };

#define RASAUTODIALENTRYW struct tagRASAUTODIALENTRYW
  RASAUTODIALENTRYW {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwDialingLocation;
    WCHAR szEntry[RAS_MaxEntryName + 1];
  };

#define RASAUTODIALENTRY __MINGW_NAME_AW(RASAUTODIALENTRY)

#define LPRASAUTODIALENTRYW RASAUTODIALENTRYW*
#define LPRASAUTODIALENTRYA RASAUTODIALENTRYA*
#define LPRASAUTODIALENTRY RASAUTODIALENTRY*

#define RASADP_DisableConnectionQuery 0
#define RASADP_LoginSessionDisable 1
#define RASADP_SavedAddressesLimit 2
#define RASADP_FailedConnectionTimeout 3
#define RASADP_ConnectionQueryTimeout 4

#define RASEAPF_NonInteractive 0x00000002
#define RASEAPF_Logon 0x00000004
#define RASEAPF_Preview 0x00000008

#define RASEAPUSERIDENTITYA struct tagRASEAPUSERIDENTITYA
  RASEAPUSERIDENTITYA {
    CHAR szUserName[UNLEN + 1 ];
    DWORD dwSizeofEapInfo;
    BYTE pbEapInfo[1 ];
  };

#define RASEAPUSERIDENTITYW struct tagRASEAPUSERIDENTITYW
  RASEAPUSERIDENTITYW {
    WCHAR szUserName[UNLEN + 1 ];
    DWORD dwSizeofEapInfo;
    BYTE pbEapInfo[1 ];
  };

#define RASEAPUSERIDENTITY __MINGW_NAME_AW(RASEAPUSERIDENTITY)

#define LPRASEAPUSERIDENTITYW RASEAPUSERIDENTITYW*
#define LPRASEAPUSERIDENTITYA RASEAPUSERIDENTITYA*

  typedef DWORD (WINAPI *PFNRASGETBUFFER) (PBYTE *ppBuffer,PDWORD pdwSize);
  typedef DWORD (WINAPI *PFNRASFREEBUFFER) (PBYTE pBufer);
  typedef DWORD (WINAPI *PFNRASSENDBUFFER) (HANDLE hPort,PBYTE pBuffer,DWORD dwSize);
  typedef DWORD (WINAPI *PFNRASRECEIVEBUFFER) (HANDLE hPort,PBYTE pBuffer,PDWORD pdwSize,DWORD dwTimeOut,HANDLE hEvent);
  typedef DWORD (WINAPI *PFNRASRETRIEVEBUFFER) (HANDLE hPort,PBYTE pBuffer,PDWORD pdwSize);
  typedef DWORD (WINAPI *RasCustomScriptExecuteFn) (HANDLE hPort,LPCWSTR lpszPhonebook,LPCWSTR lpszEntryName,PFNRASGETBUFFER pfnRasGetBuffer,PFNRASFREEBUFFER pfnRasFreeBuffer,PFNRASSENDBUFFER pfnRasSendBuffer,PFNRASRECEIVEBUFFER pfnRasReceiveBuffer,PFNRASRETRIEVEBUFFER pfnRasRetrieveBuffer,HWND hWnd,RASDIALPARAMS *pRasDialParams,PVOID pvReserved);

#define RASCOMMSETTINGS struct tagRASCOMMSETTINGS
  RASCOMMSETTINGS {
    DWORD dwSize;
    BYTE bParity;
    BYTE bStop;
    BYTE bByteSize;
    BYTE bAlign;
  };

  typedef DWORD (WINAPI *PFNRASSETCOMMSETTINGS) (HANDLE hPort,RASCOMMSETTINGS *pRasCommSettings,PVOID pvReserved);

#define RASCUSTOMSCRIPTEXTENSIONS struct tagRASCUSTOMSCRIPTEXTENSIONS
  RASCUSTOMSCRIPTEXTENSIONS {
    DWORD dwSize;
    PFNRASSETCOMMSETTINGS pfnRasSetCommSettings;
  };

  DWORD WINAPI RasDialA(LPRASDIALEXTENSIONS,LPCSTR,LPRASDIALPARAMSA,DWORD,LPVOID,LPHRASCONN);
  DWORD WINAPI RasDialW(LPRASDIALEXTENSIONS,LPCWSTR,LPRASDIALPARAMSW,DWORD,LPVOID,LPHRASCONN);
  DWORD WINAPI RasEnumConnectionsA(LPRASCONNA,LPDWORD,LPDWORD);
  DWORD WINAPI RasEnumConnectionsW(LPRASCONNW,LPDWORD,LPDWORD);
  DWORD WINAPI RasEnumEntriesA(LPCSTR,LPCSTR,LPRASENTRYNAMEA,LPDWORD,LPDWORD);
  DWORD WINAPI RasEnumEntriesW(LPCWSTR,LPCWSTR,LPRASENTRYNAMEW,LPDWORD,LPDWORD);
  DWORD WINAPI RasGetConnectStatusA(HRASCONN,LPRASCONNSTATUSA);
  DWORD WINAPI RasGetConnectStatusW(HRASCONN,LPRASCONNSTATUSW);
  DWORD WINAPI RasGetErrorStringA(UINT,LPSTR,DWORD);
  DWORD WINAPI RasGetErrorStringW(UINT,LPWSTR,DWORD);
  DWORD WINAPI RasHangUpA(HRASCONN);
  DWORD WINAPI RasHangUpW(HRASCONN);
  DWORD WINAPI RasGetProjectionInfoA(HRASCONN,RASPROJECTION,LPVOID,LPDWORD);
  DWORD WINAPI RasGetProjectionInfoW(HRASCONN,RASPROJECTION,LPVOID,LPDWORD);
  DWORD WINAPI RasCreatePhonebookEntryA(HWND,LPCSTR);
  DWORD WINAPI RasCreatePhonebookEntryW(HWND,LPCWSTR);
  DWORD WINAPI RasEditPhonebookEntryA(HWND,LPCSTR,LPCSTR);
  DWORD WINAPI RasEditPhonebookEntryW(HWND,LPCWSTR,LPCWSTR);
  DWORD WINAPI RasSetEntryDialParamsA(LPCSTR,LPRASDIALPARAMSA,WINBOOL);
  DWORD WINAPI RasSetEntryDialParamsW(LPCWSTR,LPRASDIALPARAMSW,WINBOOL);
  DWORD WINAPI RasGetEntryDialParamsA(LPCSTR,LPRASDIALPARAMSA,LPBOOL);
  DWORD WINAPI RasGetEntryDialParamsW(LPCWSTR,LPRASDIALPARAMSW,LPBOOL);
  DWORD WINAPI RasEnumDevicesA(LPRASDEVINFOA,LPDWORD,LPDWORD);
  DWORD WINAPI RasEnumDevicesW(LPRASDEVINFOW,LPDWORD,LPDWORD);
  DWORD WINAPI RasGetCountryInfoA(LPRASCTRYINFOA,LPDWORD);
  DWORD WINAPI RasGetCountryInfoW(LPRASCTRYINFOW,LPDWORD);
  DWORD WINAPI RasGetEntryPropertiesA(LPCSTR,LPCSTR,LPRASENTRYA,LPDWORD,LPBYTE,LPDWORD);
  DWORD WINAPI RasGetEntryPropertiesW(LPCWSTR,LPCWSTR,LPRASENTRYW,LPDWORD,LPBYTE,LPDWORD);
  DWORD WINAPI RasSetEntryPropertiesA(LPCSTR,LPCSTR,LPRASENTRYA,DWORD,LPBYTE,DWORD);
  DWORD WINAPI RasSetEntryPropertiesW(LPCWSTR,LPCWSTR,LPRASENTRYW,DWORD,LPBYTE,DWORD);
  DWORD WINAPI RasRenameEntryA(LPCSTR,LPCSTR,LPCSTR);
  DWORD WINAPI RasRenameEntryW(LPCWSTR,LPCWSTR,LPCWSTR);
  DWORD WINAPI RasDeleteEntryA(LPCSTR,LPCSTR);
  DWORD WINAPI RasDeleteEntryW(LPCWSTR,LPCWSTR);
  DWORD WINAPI RasValidateEntryNameA(LPCSTR,LPCSTR);
  DWORD WINAPI RasValidateEntryNameW(LPCWSTR,LPCWSTR);
  DWORD WINAPI RasConnectionNotificationA(HRASCONN,HANDLE,DWORD);
  DWORD WINAPI RasConnectionNotificationW(HRASCONN,HANDLE,DWORD);
  DWORD WINAPI RasGetSubEntryHandleA(HRASCONN,DWORD,LPHRASCONN);
  DWORD WINAPI RasGetSubEntryHandleW(HRASCONN,DWORD,LPHRASCONN);
  DWORD WINAPI RasGetCredentialsA(LPCSTR,LPCSTR,LPRASCREDENTIALSA);
  DWORD WINAPI RasGetCredentialsW(LPCWSTR,LPCWSTR,LPRASCREDENTIALSW);
  DWORD WINAPI RasSetCredentialsA(LPCSTR,LPCSTR,LPRASCREDENTIALSA,WINBOOL);
  DWORD WINAPI RasSetCredentialsW(LPCWSTR,LPCWSTR,LPRASCREDENTIALSW,WINBOOL);
  DWORD WINAPI RasGetSubEntryPropertiesA(LPCSTR,LPCSTR,DWORD,LPRASSUBENTRYA,LPDWORD,LPBYTE,LPDWORD);
  DWORD WINAPI RasGetSubEntryPropertiesW(LPCWSTR,LPCWSTR,DWORD,LPRASSUBENTRYW,LPDWORD,LPBYTE,LPDWORD);
  DWORD WINAPI RasSetSubEntryPropertiesA(LPCSTR,LPCSTR,DWORD,LPRASSUBENTRYA,DWORD,LPBYTE,DWORD);
  DWORD WINAPI RasSetSubEntryPropertiesW(LPCWSTR,LPCWSTR,DWORD,LPRASSUBENTRYW,DWORD,LPBYTE,DWORD);
  DWORD WINAPI RasGetAutodialAddressA(LPCSTR,LPDWORD,LPRASAUTODIALENTRYA,LPDWORD,LPDWORD);
  DWORD WINAPI RasGetAutodialAddressW(LPCWSTR,LPDWORD,LPRASAUTODIALENTRYW,LPDWORD,LPDWORD);
  DWORD WINAPI RasSetAutodialAddressA(LPCSTR,DWORD,LPRASAUTODIALENTRYA,DWORD,DWORD);
  DWORD WINAPI RasSetAutodialAddressW(LPCWSTR,DWORD,LPRASAUTODIALENTRYW,DWORD,DWORD);
  DWORD WINAPI RasEnumAutodialAddressesA(LPSTR *,LPDWORD,LPDWORD);
  DWORD WINAPI RasEnumAutodialAddressesW(LPWSTR *,LPDWORD,LPDWORD);
  DWORD WINAPI RasGetAutodialEnableA(DWORD,LPBOOL);
  DWORD WINAPI RasGetAutodialEnableW(DWORD,LPBOOL);
  DWORD WINAPI RasSetAutodialEnableA(DWORD,WINBOOL);
  DWORD WINAPI RasSetAutodialEnableW(DWORD,WINBOOL);
  DWORD WINAPI RasGetAutodialParamA(DWORD,LPVOID,LPDWORD);
  DWORD WINAPI RasGetAutodialParamW(DWORD,LPVOID,LPDWORD);
  DWORD WINAPI RasSetAutodialParamA(DWORD,LPVOID,DWORD);
  DWORD WINAPI RasSetAutodialParamW(DWORD,LPVOID,DWORD);

  typedef struct _RAS_STATS {
    DWORD dwSize;
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
    DWORD dwBps;
    DWORD dwConnectDuration;
  } RAS_STATS,*PRAS_STATS;

  typedef DWORD (WINAPI *RasCustomHangUpFn)(HRASCONN hRasConn);
  typedef DWORD (WINAPI *RasCustomDialFn)(HINSTANCE hInstDll,LPRASDIALEXTENSIONS lpRasDialExtensions,LPCWSTR lpszPhonebook,LPRASDIALPARAMS lpRasDialParams,DWORD dwNotifierType,LPVOID lpvNotifier,LPHRASCONN lphRasConn,DWORD dwFlags);
  typedef DWORD (WINAPI *RasCustomDeleteEntryNotifyFn)(LPCWSTR lpszPhonebook,LPCWSTR lpszEntry,DWORD dwFlags);

#define RCD_SingleUser 0
#define RCD_AllUsers 0x00000001
#define RCD_Eap 0x00000002
#define RCD_Logon 0x00000004

  DWORD WINAPI RasInvokeEapUI(HRASCONN,DWORD,LPRASDIALEXTENSIONS,HWND);
  DWORD WINAPI RasGetLinkStatistics(HRASCONN hRasConn,DWORD dwSubEntry,RAS_STATS *lpStatistics);
  DWORD WINAPI RasGetConnectionStatistics(HRASCONN hRasConn,RAS_STATS *lpStatistics);
  DWORD WINAPI RasClearLinkStatistics(HRASCONN hRasConn,DWORD dwSubEntry);
  DWORD WINAPI RasClearConnectionStatistics(HRASCONN hRasConn);
  DWORD WINAPI RasGetEapUserDataA(HANDLE hToken,LPCSTR pszPhonebook,LPCSTR pszEntry,BYTE *pbEapData,DWORD *pdwSizeofEapData);
  DWORD WINAPI RasGetEapUserDataW(HANDLE hToken,LPCWSTR pszPhonebook,LPCWSTR pszEntry,BYTE *pbEapData,DWORD *pdwSizeofEapData);
  DWORD WINAPI RasSetEapUserDataA(HANDLE hToken,LPCSTR pszPhonebook,LPCSTR pszEntry,BYTE *pbEapData,DWORD dwSizeofEapData);
  DWORD WINAPI RasSetEapUserDataW(HANDLE hToken,LPCWSTR pszPhonebook,LPCWSTR pszEntry,BYTE *pbEapData,DWORD dwSizeofEapData);
  DWORD WINAPI RasGetCustomAuthDataA(LPCSTR pszPhonebook,LPCSTR pszEntry,BYTE *pbCustomAuthData,DWORD *pdwSizeofCustomAuthData);
  DWORD WINAPI RasGetCustomAuthDataW(LPCWSTR pszPhonebook,LPCWSTR pszEntry,BYTE *pbCustomAuthData,DWORD *pdwSizeofCustomAuthData);
  DWORD WINAPI RasSetCustomAuthDataA(LPCSTR pszPhonebook,LPCSTR pszEntry,BYTE *pbCustomAuthData,DWORD dwSizeofCustomAuthData);
  DWORD WINAPI RasSetCustomAuthDataW(LPCWSTR pszPhonebook,LPCWSTR pszEntry,BYTE *pbCustomAuthData,DWORD dwSizeofCustomAuthData);
  DWORD WINAPI RasGetEapUserIdentityW(LPCWSTR pszPhonebook,LPCWSTR pszEntry,DWORD dwFlags,HWND hwnd,LPRASEAPUSERIDENTITYW *ppRasEapUserIdentity);
  DWORD WINAPI RasGetEapUserIdentityA(LPCSTR pszPhonebook,LPCSTR pszEntry,DWORD dwFlags,HWND hwnd,LPRASEAPUSERIDENTITYA *ppRasEapUserIdentity);
  VOID WINAPI RasFreeEapUserIdentityW(LPRASEAPUSERIDENTITYW pRasEapUserIdentity);
  VOID WINAPI RasFreeEapUserIdentityA(LPRASEAPUSERIDENTITYA pRasEapUserIdentity);
  DWORD WINAPI RasDeleteSubEntryA(LPCSTR pszPhonebook,LPCSTR pszEntry,DWORD dwSubentryId);
  DWORD WINAPI RasDeleteSubEntryW(LPCWSTR pszPhonebook,LPCWSTR pszEntry,DWORD dwSubEntryId);

#define RasDial __MINGW_NAME_AW(RasDial)
#define RasEnumConnections __MINGW_NAME_AW(RasEnumConnections)
#define RasEnumEntries __MINGW_NAME_AW(RasEnumEntries)
#define RasGetConnectStatus __MINGW_NAME_AW(RasGetConnectStatus)
#define RasGetErrorString __MINGW_NAME_AW(RasGetErrorString)
#define RasHangUp __MINGW_NAME_AW(RasHangUp)
#define RasGetProjectionInfo __MINGW_NAME_AW(RasGetProjectionInfo)
#define RasCreatePhonebookEntry __MINGW_NAME_AW(RasCreatePhonebookEntry)
#define RasEditPhonebookEntry __MINGW_NAME_AW(RasEditPhonebookEntry)
#define RasSetEntryDialParams __MINGW_NAME_AW(RasSetEntryDialParams)
#define RasGetEntryDialParams __MINGW_NAME_AW(RasGetEntryDialParams)
#define RasEnumDevices __MINGW_NAME_AW(RasEnumDevices)
#define RasGetCountryInfo __MINGW_NAME_AW(RasGetCountryInfo)
#define RasGetEntryProperties __MINGW_NAME_AW(RasGetEntryProperties)
#define RasSetEntryProperties __MINGW_NAME_AW(RasSetEntryProperties)
#define RasRenameEntry __MINGW_NAME_AW(RasRenameEntry)
#define RasDeleteEntry __MINGW_NAME_AW(RasDeleteEntry)
#define RasValidateEntryName __MINGW_NAME_AW(RasValidateEntryName)
#define RasGetSubEntryHandle __MINGW_NAME_AW(RasGetSubEntryHandle)
#define RasConnectionNotification __MINGW_NAME_AW(RasConnectionNotification)
#define RasGetSubEntryProperties __MINGW_NAME_AW(RasGetSubEntryProperties)
#define RasSetSubEntryProperties __MINGW_NAME_AW(RasSetSubEntryProperties)
#define RasGetCredentials __MINGW_NAME_AW(RasGetCredentials)
#define RasSetCredentials __MINGW_NAME_AW(RasSetCredentials)
#define RasGetAutodialAddress __MINGW_NAME_AW(RasGetAutodialAddress)
#define RasSetAutodialAddress __MINGW_NAME_AW(RasSetAutodialAddress)
#define RasEnumAutodialAddresses __MINGW_NAME_AW(RasEnumAutodialAddresses)
#define RasGetAutodialEnable __MINGW_NAME_AW(RasGetAutodialEnable)
#define RasSetAutodialEnable __MINGW_NAME_AW(RasSetAutodialEnable)
#define RasGetAutodialParam __MINGW_NAME_AW(RasGetAutodialParam)
#define RasSetAutodialParam __MINGW_NAME_AW(RasSetAutodialParam)
#define RasGetEapUserData __MINGW_NAME_AW(RasGetEapUserData)
#define RasSetEapUserData __MINGW_NAME_AW(RasSetEapUserData)
#define RasGetCustomAuthData __MINGW_NAME_AW(RasGetCustomAuthData)
#define RasSetCustomAuthData __MINGW_NAME_AW(RasSetCustomAuthData)
#define RasGetEapUserIdentity __MINGW_NAME_AW(RasGetEapUserIdentity)
#define RasFreeEapUserIdentity __MINGW_NAME_AW(RasFreeEapUserIdentity)
#define RasDeleteSubEntry __MINGW_NAME_AW(RasDeleteSubEntry)

#if (_WIN32_WINNT >= 0x0600)

typedef struct _tagRasNapState {
  DWORD          dwSize;
  DWORD          dwFlags;
  IsolationState isolationState;
  ProbationTime  probationTime;
} RASNAPSTATE, *LPRASNAPSTATE;

typedef struct _RASPPPIPV6 {
  DWORD dwSize;
  DWORD dwError;
  BYTE  bLocalInterfaceIdentifier[8];
  BYTE  bPeerInterfaceIdentifier[8];
  BYTE  bLocalCompressionProtocol[2];
  BYTE  bPeerCompressionProtocol[2];
} RASPPPIPV6, *LPRASPPPIPV6;

DWORD rasgetnapstatus(
  HRASCONN hRasConn,
  LPRASNAPSTATE pNapState
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

#if (_WIN32_WINNT >= 0x0601)
typedef enum  {
  RASAPIVERSION_500   = 1,
  RASAPIVERSION_501   = 2,
  RASAPIVERSION_600   = 3,
  RASAPIVERSION_601   = 4 
} RASAPIVERSION;

typedef struct _RASTUNNELENDPOINT {
  DWORD dwType;
  __C89_NAMELESS union {
    RASIPV4ADDR ipv4;
    RASIPV6ADDR ipv6;
  } DUMMYUNIONNAME;
} RASTUNNELENDPOINT, *PRASTUNNELENDPOINT;

typedef struct _RASUPDATECONN {
  RASAPIVERSION     version;
  DWORD             dwSize;
  DWORD             dwFlags;
  DWORD             dwIfIndex;
  RASTUNNELENDPOINT  localEndPoint;
  RASTUNNELENDPOINT  remoteEndPoint;
} RASUPDATECONN, *LPRASUPDATECONN;
#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif

#include <poppack.h>
#endif
#endif
