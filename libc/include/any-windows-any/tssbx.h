/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_TSSBX
#define _INC_TSSBX

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _WTSSBX_ADDRESS_FAMILY {
  WTSSBX_ADDRESS_FAMILY_AF_UNSPEC    = 0,
  WTSSBX_ADDRESS_FAMILY_AF_INET      = 1,
  WTSSBX_ADDRESS_FAMILY_AF_INET6     = 2,
  WTSSBX_ADDRESS_FAMILY_AF_IPX       = 3,
  WTSSBX_ADDRESS_FAMILY_AF_NETBIOS   = 4
} WTSSBX_ADDRESS_FAMILY;

typedef enum _WTSSBX_MACHINE_DRAIN {
  WTSSBX_MACHINE_DRAIN_UNSPEC   = 0,
  WTSSBX_MACHINE_DRAIN_OFF      = 1,
  WTSSBX_MACHINE_DRAIN_ON       = 2
} WTSSBX_MACHINE_DRAIN;

typedef enum _WTSSBX_NOTIFICATION_TYPE {
  WTSSBX_MACHINE_SESSION_MODE_UNSPEC     = 0,
  WTSSBX_MACHINE_SESSION_MODE_SINGLE     = 1,
  WTSSBX_MACHINE_SESSION_MODE_MULTIPLE   = 2
} WTSSBX_NOTIFICATION_TYPE;

typedef enum _WTSSBX_MACHINE_STATE {
  WTSSBX_MACHINE_STATE_UNSPEC          = 0,
  WTSSBX_MACHINE_STATE_READY           = 1,
  WTSSBX_MACHINE_STATE_SYNCHRONIZING   = 2
} WTSSBX_MACHINE_STATE;

typedef enum _WTSSBX_NOTIFICATION_TYPE {
  WTSSBX_NOTIFICATION_REMOVED   = 1,
  WTSSBX_NOTIFICATION_CHANGED   = 2,
  WTSSBX_NOTIFICATION_ADDED     = 4,
  WTSSBX_NOTIFICATION_RESYNC    = 8
} WTSSBX_NOTIFICATION_TYPE;

typedef enum _WTSSBX_SESSION_STATE {
  WTSSBX_SESSION_STATE_UNSPEC         = 0,
  WTSSBX_SESSION_STATE_ACTIVE         = 1,
  WTSSBX_SESSION_STATE_DISCONNECTED   = 2
} WTSSBX_SESSION_STATE;

typedef struct _WTSSBX_IP_ADDRESS {
  WTSSBX_ADDRESS_FAMILY  AddressFamily;
  BYTE                   Address[16];
  unsigned short         PortNumber;
  DWORD                  dwScope;
} WTSSBX_IP_ADDRESS;

#define MaxFQDN_Len 256
#define MaxNetBiosName_Len 16

typedef struct _WTSSBX_MACHINE_CONNECT_INFO {
  WCHAR              wczMachineFQDN[MaxFQDN_Len + 1];
  WCHAR              wczMachineNetBiosName[MaxNetBiosName_Len + 1];
  DWORD              dwNumOfIPAddr;
  WTSSBX_IP_ADDRESS  IPaddr[MaxNumOfExposed_IPs];
} WTSSBX_MACHINE_CONNECT_INFO;

#define MaxFarm_Len 256

typedef struct _WTSSBX_MACHINE_INFO {
  WTSSBX_MACHINE_CONNECT_INFO  ClientConnectInfo;
  WCHAR                        wczFarmName[MaxFarm_Len + 1];
  WTSSBX_IP_ADDRESS            InternalIPAddress;
  DWORD                        dwMaxSessionsLimit;
  DWORD                        ServerWeight;
  WTSSBX_MACHINE_SESSION_MODE  SingleSessionMode;
  WTSSBX_MACHINE_DRAIN         InDrain;
  WTSSBX_MACHINE_STATE         MachineState;
} WTSSBX_MACHINE_INFO;

#define MaxUserName_Len 104
#define MaxDomainName_Len 256
#define MaxAppName_Len 256

typedef struct _WTSSBX_SESSION_INFO {
  WCHAR                 wszUserName[MaxUserName_Len + 1];
  WCHAR                 wszDomainName[MaxDomainName_Len + 1];
  WCHAR                 ApplicationType[MaxAppName_Len + 1];
  DWORD                 dwSessionId;
  FILETIME              CreateTime;
  FILETIME              DisconnectTime;
  WTSSBX_SESSION_STATE  SessionState;
} WTSSBX_SESSION_INFO;

/* IID_IWTSSBPlugin is defined as DC44BE78-B18D-4399-B210-641BF67A002C */

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /*_INC_TSSBX*/
