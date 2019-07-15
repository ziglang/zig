#undef INTERFACE
/*
 * Copyright (C) 2003-2005 Raphael Junqueira
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __WINE_DPLAY8_H
#define __WINE_DPLAY8_H

#include <ole2.h>
#include <dpaddr.h>

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */


typedef HRESULT (WINAPI *PFNDPNMESSAGEHANDLER)(PVOID, DWORD, PVOID);
typedef DWORD	DPNID, *PDPNID;
typedef	DWORD	DPNHANDLE, *PDPNHANDLE;

/*****************************************************************************
 * DirectPlay8 Message Id
 */
#define	DPN_MSGID_OFFSET                        0xFFFF0000
#define DPN_MSGID_ADD_PLAYER_TO_GROUP           (DPN_MSGID_OFFSET | 0x0001)
#define DPN_MSGID_APPLICATION_DESC              (DPN_MSGID_OFFSET | 0x0002)
#define DPN_MSGID_ASYNC_OP_COMPLETE             (DPN_MSGID_OFFSET | 0x0003)
#define DPN_MSGID_CLIENT_INFO                   (DPN_MSGID_OFFSET | 0x0004)
#define DPN_MSGID_CONNECT_COMPLETE              (DPN_MSGID_OFFSET | 0x0005)
#define DPN_MSGID_CREATE_GROUP                  (DPN_MSGID_OFFSET | 0x0006)
#define DPN_MSGID_CREATE_PLAYER                 (DPN_MSGID_OFFSET | 0x0007)
#define DPN_MSGID_DESTROY_GROUP                 (DPN_MSGID_OFFSET | 0x0008)
#define DPN_MSGID_DESTROY_PLAYER                (DPN_MSGID_OFFSET | 0x0009)
#define DPN_MSGID_ENUM_HOSTS_QUERY              (DPN_MSGID_OFFSET | 0x000A)
#define DPN_MSGID_ENUM_HOSTS_RESPONSE           (DPN_MSGID_OFFSET | 0x000B)
#define DPN_MSGID_GROUP_INFO                    (DPN_MSGID_OFFSET | 0x000C)
#define DPN_MSGID_HOST_MIGRATE                  (DPN_MSGID_OFFSET | 0x000D)
#define DPN_MSGID_INDICATE_CONNECT              (DPN_MSGID_OFFSET | 0x000E)
#define DPN_MSGID_INDICATED_CONNECT_ABORTED     (DPN_MSGID_OFFSET | 0x000F)
#define DPN_MSGID_PEER_INFO                     (DPN_MSGID_OFFSET | 0x0010)
#define DPN_MSGID_RECEIVE                       (DPN_MSGID_OFFSET | 0x0011)
#define DPN_MSGID_REMOVE_PLAYER_FROM_GROUP      (DPN_MSGID_OFFSET | 0x0012)
#define	DPN_MSGID_RETURN_BUFFER                 (DPN_MSGID_OFFSET | 0x0013)
#define DPN_MSGID_SEND_COMPLETE                 (DPN_MSGID_OFFSET | 0x0014)
#define DPN_MSGID_SERVER_INFO                   (DPN_MSGID_OFFSET | 0x0015)
#define	DPN_MSGID_TERMINATE_SESSION             (DPN_MSGID_OFFSET | 0x0016)
#define DPN_MSGID_CREATE_THREAD                 (DPN_MSGID_OFFSET | 0x0017)
#define DPN_MSGID_DESTROY_THREAD                (DPN_MSGID_OFFSET | 0x0018)
#define DPN_MSGID_NAT_RESOLVER_QUERY            (DPN_MSGID_OFFSET | 0x0101)

/*****************************************************************************
 * DirectPlay8 Errors
 */
#define _DPN_FACILITY_CODE              0x015
#define _DPNHRESULT_BASE                0x8000
#define MAKE_DPNHRESULT(code)           MAKE_HRESULT(1, _DPN_FACILITY_CODE, (code + _DPNHRESULT_BASE))

#define DPNSUCCESS_EQUAL                MAKE_HRESULT(0, _DPN_FACILITY_CODE, (0x05 + _DPNHRESULT_BASE))
#define DPNSUCCESS_NOTEQUAL             MAKE_HRESULT(0, _DPN_FACILITY_CODE, (0x0A + _DPNHRESULT_BASE))
#define DPNSUCCESS_PENDING              MAKE_HRESULT(0, _DPN_FACILITY_CODE, (0x0E + _DPNHRESULT_BASE))

#define DPN_OK                          S_OK
#define DPNERR_GENERIC                  E_FAIL
#define DPNERR_INVALIDPARAM             E_INVALIDARG
#define DPNERR_UNSUPPORTED              E_NOTIMPL
#define DPNERR_NOINTERFACE              E_NOINTERFACE
#define DPNERR_OUTOFMEMORY              E_OUTOFMEMORY
#define DPNERR_INVALIDPOINTER           E_POINTER
#define DPNERR_PENDING                  DPNSUCCESS_PENDING
#define DPNERR_ABORTED                  MAKE_DPNHRESULT(0x030)
#define DPNERR_ADDRESSING               MAKE_DPNHRESULT(0x040)
#define DPNERR_ALREADYCLOSING           MAKE_DPNHRESULT(0x050)
#define DPNERR_ALREADYCONNECTED         MAKE_DPNHRESULT(0x060)
#define DPNERR_ALREADYDISCONNECTING     MAKE_DPNHRESULT(0x070)
#define DPNERR_ALREADYINITIALIZED       MAKE_DPNHRESULT(0x080)
#define DPNERR_ALREADYREGISTERED        MAKE_DPNHRESULT(0x090)
#define DPNERR_BUFFERTOOSMALL           MAKE_DPNHRESULT(0x100)
#define DPNERR_CANNOTCANCEL             MAKE_DPNHRESULT(0x110)
#define DPNERR_CANTCREATEGROUP          MAKE_DPNHRESULT(0x120)
#define DPNERR_CANTCREATEPLAYER         MAKE_DPNHRESULT(0x130)
#define DPNERR_CANTLAUNCHAPPLICATION    MAKE_DPNHRESULT(0x140)
#define DPNERR_CONNECTING               MAKE_DPNHRESULT(0x150)
#define DPNERR_CONNECTIONLOST           MAKE_DPNHRESULT(0x160)
#define DPNERR_CONVERSION               MAKE_DPNHRESULT(0x170)
#define DPNERR_DATATOOLARGE             MAKE_DPNHRESULT(0x175)
#define DPNERR_DOESNOTEXIST             MAKE_DPNHRESULT(0x180)
#define DPNERR_DPNSVRNOTAVAILABLE       MAKE_DPNHRESULT(0x185)
#define DPNERR_DUPLICATECOMMAND         MAKE_DPNHRESULT(0x190)
#define DPNERR_ENDPOINTNOTRECEIVING     MAKE_DPNHRESULT(0x200)
#define DPNERR_ENUMQUERYTOOLARGE        MAKE_DPNHRESULT(0x210)
#define DPNERR_ENUMRESPONSETOOLARGE     MAKE_DPNHRESULT(0x220)
#define DPNERR_EXCEPTION                MAKE_DPNHRESULT(0x230)
#define DPNERR_GROUPNOTEMPTY            MAKE_DPNHRESULT(0x240)
#define DPNERR_HOSTING                  MAKE_DPNHRESULT(0x250)
#define DPNERR_HOSTREJECTEDCONNECTION   MAKE_DPNHRESULT(0x260)
#define DPNERR_HOSTTERMINATEDSESSION    MAKE_DPNHRESULT(0x270)
#define DPNERR_INCOMPLETEADDRESS        MAKE_DPNHRESULT(0x280)
#define DPNERR_INVALIDADDRESSFORMAT     MAKE_DPNHRESULT(0x290)
#define DPNERR_INVALIDAPPLICATION       MAKE_DPNHRESULT(0x300)
#define DPNERR_INVALIDCOMMAND           MAKE_DPNHRESULT(0x310)
#define DPNERR_INVALIDDEVICEADDRESS     MAKE_DPNHRESULT(0x320)
#define DPNERR_INVALIDENDPOINT          MAKE_DPNHRESULT(0x330)
#define DPNERR_INVALIDFLAGS             MAKE_DPNHRESULT(0x340)
#define DPNERR_INVALIDGROUP             MAKE_DPNHRESULT(0x350)
#define DPNERR_INVALIDHANDLE            MAKE_DPNHRESULT(0x360)
#define DPNERR_INVALIDHOSTADDRESS       MAKE_DPNHRESULT(0x370)
#define DPNERR_INVALIDINSTANCE          MAKE_DPNHRESULT(0x380)
#define DPNERR_INVALIDINTERFACE         MAKE_DPNHRESULT(0x390)
#define DPNERR_INVALIDOBJECT            MAKE_DPNHRESULT(0x400)
#define DPNERR_INVALIDPASSWORD          MAKE_DPNHRESULT(0x410)
#define DPNERR_INVALIDPLAYER            MAKE_DPNHRESULT(0x420)
#define DPNERR_INVALIDPRIORITY          MAKE_DPNHRESULT(0x430)
#define DPNERR_INVALIDSTRING            MAKE_DPNHRESULT(0x440)
#define DPNERR_INVALIDURL               MAKE_DPNHRESULT(0x450)
#define DPNERR_INVALIDVERSION           MAKE_DPNHRESULT(0x460)
#define DPNERR_NOCAPS                   MAKE_DPNHRESULT(0x470)
#define DPNERR_NOCONNECTION             MAKE_DPNHRESULT(0x480)
#define DPNERR_NOHOSTPLAYER             MAKE_DPNHRESULT(0x490)
#define DPNERR_NOMOREADDRESSCOMPONENTS  MAKE_DPNHRESULT(0x500)
#define DPNERR_NORESPONSE               MAKE_DPNHRESULT(0x510)
#define DPNERR_NOTALLOWED               MAKE_DPNHRESULT(0x520)
#define DPNERR_NOTHOST                  MAKE_DPNHRESULT(0x530)
#define DPNERR_NOTREADY                 MAKE_DPNHRESULT(0x540)
#define DPNERR_NOTREGISTERED            MAKE_DPNHRESULT(0x550)
#define DPNERR_PLAYERALREADYINGROUP     MAKE_DPNHRESULT(0x560)
#define DPNERR_PLAYERLOST               MAKE_DPNHRESULT(0x570)
#define DPNERR_PLAYERNOTINGROUP         MAKE_DPNHRESULT(0x580)
#define DPNERR_PLAYERNOTREACHABLE       MAKE_DPNHRESULT(0x590)
#define DPNERR_SENDTOOLARGE             MAKE_DPNHRESULT(0x600)
#define DPNERR_SESSIONFULL              MAKE_DPNHRESULT(0x610)
#define DPNERR_TABLEFULL                MAKE_DPNHRESULT(0x620)
#define DPNERR_TIMEDOUT                 MAKE_DPNHRESULT(0x630)
#define DPNERR_UNINITIALIZED            MAKE_DPNHRESULT(0x640)
#define DPNERR_USERCANCEL               MAKE_DPNHRESULT(0x650)

/*****************************************************************************
 * DirectPlay8 defines
 */
#define DPNID_ALL_PLAYERS_GROUP                              0
#define DPNDESTROYGROUPREASON_NORMAL                    0x0001
#define DPNDESTROYGROUPREASON_AUTODESTRUCTED            0x0002
#define DPNDESTROYGROUPREASON_SESSIONTERMINATED         0x0003
#define DPNDESTROYPLAYERREASON_NORMAL                   0x0001
#define DPNDESTROYPLAYERREASON_CONNECTIONLOST           0x0002
#define DPNDESTROYPLAYERREASON_SESSIONTERMINATED        0x0003
#define DPNDESTROYPLAYERREASON_HOSTDESTROYEDPLAYER      0x0004
#define DPN_MAX_APPDESC_RESERVEDDATA_SIZE                   64

#define DPNOP_SYNC                                  0x80000000
#define DPNADDPLAYERTOGROUP_SYNC                    DPNOP_SYNC
#define DPNCANCEL_CONNECT                               0x0001
#define DPNCANCEL_ENUM                                  0x0002
#define DPNCANCEL_SEND                                  0x0004
#define DPNCANCEL_ALL_OPERATIONS                        0x8000
#define DPNCANCEL_PLAYER_SENDS                      0x80000000
#define DPNCANCEL_PLAYER_SENDS_PRIORITY_HIGH        (DPNCANCEL_PLAYER_SENDS | 0x00010000)
#define DPNCANCEL_PLAYER_SENDS_PRIORITY_NORMAL      (DPNCANCEL_PLAYER_SENDS | 0x00020000)
#define DPNCANCEL_PLAYER_SENDS_PRIORITY_LOW         (DPNCANCEL_PLAYER_SENDS | 0x00040000)
#define DPNCLOSE_IMMEDIATE                          0x00000001
#define DPNCONNECT_SYNC                             DPNOP_SYNC
#define DPNCONNECT_OKTOQUERYFORADDRESSING               0x0001
#define DPNCREATEGROUP_SYNC                         DPNOP_SYNC
#define DPNDESTROYGROUP_SYNC                        DPNOP_SYNC
#define DPNENUM_PLAYERS                                 0x0001
#define DPNENUM_GROUPS                                  0x0010
#define DPNENUMHOSTS_SYNC                           DPNOP_SYNC
#define DPNENUMHOSTS_OKTOQUERYFORADDRESSING             0x0001
#define DPNENUMHOSTS_NOBROADCASTFALLBACK                0x0002
#define DPNENUMSERVICEPROVIDERS_ALL                     0x0001
#define DPNGETLOCALHOSTADDRESSES_COMBINED               0x0001
#define DPNGETSENDQUEUEINFO_PRIORITY_NORMAL             0x0001
#define DPNGETSENDQUEUEINFO_PRIORITY_HIGH               0x0002
#define DPNGETSENDQUEUEINFO_PRIORITY_LOW                0x0004
#define DPNGROUP_AUTODESTRUCT                           0x0001
#define DPNHOST_OKTOQUERYFORADDRESSING                  0x0001
#define DPNINFO_NAME                                    0x0001
#define DPNINFO_DATA                                    0x0002
#define DPNINITIALIZE_DISABLEPARAMVAL                   0x0001
#define DPNINITIALIZE_HINT_LANSESSION                   0x0002
#define DPNINITIALIZE_DISABLELINKTUNING                 0x0004
#define DPNLOBBY_REGISTER                               0x0001
#define DPNLOBBY_UNREGISTER                             0x0002
#define DPNPLAYER_LOCAL                                 0x0002
#define DPNPLAYER_HOST                                  0x0004
#define DPNRECEIVE_GUARANTEED                           0x0001
#define DPNRECEIVE_COALESCED                            0x0002
#define DPNREMOVEPLAYERFROMGROUP_SYNC               DPNOP_SYNC
#define DPNSEND_SYNC                                DPNOP_SYNC
#define DPNSEND_NOCOPY                                  0x0001
#define DPNSEND_NOCOMPLETE                              0x0002
#define DPNSEND_COMPLETEONPROCESS                       0x0004
#define DPNSEND_GUARANTEED                              0x0008
#define DPNSEND_NONSEQUENTIAL                           0x0010
#define DPNSEND_NOLOOPBACK                              0x0020
#define DPNSEND_PRIORITY_LOW                            0x0040
#define DPNSEND_PRIORITY_HIGH                           0x0080
#define DPNSEND_COALESCE                                0x0100
#define DPNSENDCOMPLETE_GUARANTEED                      0x0001
#define DPNSENDCOMPLETE_COALESCED                       0x0002
#define DPNSESSION_CLIENT_SERVER                        0x0001
#define DPNSESSION_MIGRATE_HOST                         0x0004
#define DPNSESSION_NODPNSVR                             0x0040
#define DPNSESSION_REQUIREPASSWORD                      0x0080
#define DPNSESSION_NOENUMS                              0x0100
#define DPNSESSION_FAST_SIGNED                          0x0200
#define DPNSESSION_FULL_SIGNED                          0x0400
#define DPNSETCLIENTINFO_SYNC                       DPNOP_SYNC
#define DPNSETGROUPINFO_SYNC                        DPNOP_SYNC
#define DPNSETPEERINFO_SYNC                         DPNOP_SYNC
#define DPNSETSERVERINFO_SYNC                       DPNOP_SYNC
#define DPNSPCAPS_SUPPORTSDPNSRV                        0x0001
#define DPNSPCAPS_SUPPORTSBROADCAST                     0x0002
#define DPNSPCAPS_SUPPORTSALLADAPTERS                   0x0004
#define DPNSPCAPS_SUPPORTSTHREADPOOL			0x0008
#define DPNSPCAPS_NETWORKSIMULATOR                      0x0010
#define DPNSPINFO_NETWORKSIMULATORDEVICE                0x0001


/*****************************************************************************
 * DirectPlay8 structures Typedefs
 */
typedef struct _DPN_APPLICATION_DESC {
  DWORD   dwSize;
  DWORD   dwFlags;
  GUID    guidInstance;
  GUID	  guidApplication;
  DWORD   dwMaxPlayers;
  DWORD   dwCurrentPlayers;
  WCHAR*  pwszSessionName;
  WCHAR*  pwszPassword;
  PVOID   pvReservedData;
  DWORD   dwReservedDataSize;
  PVOID   pvApplicationReservedData;
  DWORD   dwApplicationReservedDataSize;
} DPN_APPLICATION_DESC, *PDPN_APPLICATION_DESC;

typedef struct _BUFFERDESC {
  DWORD	  dwBufferSize;		
  BYTE*   pBufferData;		
} BUFFERDESC, DPN_BUFFER_DESC, *PDPN_BUFFER_DESC, *PBUFFERDESC;

typedef struct _DPN_CAPS {
  DWORD   dwSize;
  DWORD   dwFlags;
  DWORD   dwConnectTimeout;
  DWORD   dwConnectRetries;
  DWORD   dwTimeoutUntilKeepAlive;
} DPN_CAPS, *PDPN_CAPS;

typedef struct	_DPN_CAPS_EX {
  DWORD   dwSize;
  DWORD   dwFlags;
  DWORD   dwConnectTimeout;
  DWORD   dwConnectRetries;
  DWORD   dwTimeoutUntilKeepAlive;
  DWORD   dwMaxRecvMsgSize;
  DWORD   dwNumSendRetries;
  DWORD   dwMaxSendRetryInterval;
  DWORD   dwDropThresholdRate;
  DWORD   dwThrottleRate;
  DWORD   dwNumHardDisconnectSends;
  DWORD   dwMaxHardDisconnectPeriod;
} DPN_CAPS_EX, *PDPN_CAPS_EX;

typedef struct _DPN_CONNECTION_INFO {
  DWORD   dwSize;
  DWORD   dwRoundTripLatencyMS;
  DWORD   dwThroughputBPS;
  DWORD   dwPeakThroughputBPS;
  DWORD   dwBytesSentGuaranteed;
  DWORD   dwPacketsSentGuaranteed;
  DWORD   dwBytesSentNonGuaranteed;
  DWORD   dwPacketsSentNonGuaranteed;
  DWORD   dwBytesRetried;
  DWORD   dwPacketsRetried;
  DWORD   dwBytesDropped;
  DWORD   dwPacketsDropped;
  DWORD   dwMessagesTransmittedHighPriority;
  DWORD   dwMessagesTimedOutHighPriority;
  DWORD   dwMessagesTransmittedNormalPriority;
  DWORD   dwMessagesTimedOutNormalPriority;
  DWORD   dwMessagesTransmittedLowPriority;
  DWORD   dwMessagesTimedOutLowPriority;
  DWORD   dwBytesReceivedGuaranteed;
  DWORD   dwPacketsReceivedGuaranteed;
  DWORD   dwBytesReceivedNonGuaranteed;
  DWORD   dwPacketsReceivedNonGuaranteed;
  DWORD   dwMessagesReceived;
} DPN_CONNECTION_INFO, *PDPN_CONNECTION_INFO;

typedef struct _DPN_GROUP_INFO {
  DWORD	  dwSize;
  DWORD	  dwInfoFlags;
  PWSTR	  pwszName;
  PVOID	  pvData;
  DWORD	  dwDataSize;
  DWORD	  dwGroupFlags;
} DPN_GROUP_INFO, *PDPN_GROUP_INFO;

typedef struct _DPN_PLAYER_INFO {
  DWORD	  dwSize;
  DWORD	  dwInfoFlags;
  PWSTR	  pwszName;
  PVOID	  pvData;
  DWORD	  dwDataSize;
  DWORD	  dwPlayerFlags;
} DPN_PLAYER_INFO, *PDPN_PLAYER_INFO;

typedef struct _DPN_SERVICE_PROVIDER_INFO {
  DWORD   dwFlags;
  GUID    guid;
  WCHAR*  pwszName;
  PVOID   pvReserved;	
  DWORD   dwReserved;
} DPN_SERVICE_PROVIDER_INFO, *PDPN_SERVICE_PROVIDER_INFO;

typedef struct _DPN_SP_CAPS {
  DWORD   dwSize;
  DWORD   dwFlags;
  DWORD   dwNumThreads;
  DWORD	  dwDefaultEnumCount;
  DWORD	  dwDefaultEnumRetryInterval;
  DWORD	  dwDefaultEnumTimeout;
  DWORD	  dwMaxEnumPayloadSize;
  DWORD	  dwBuffersPerThread;
  DWORD	  dwSystemBufferSize;
} DPN_SP_CAPS, *PDPN_SP_CAPS;

typedef struct _DPN_SECURITY_CREDENTIALS  DPN_SECURITY_CREDENTIALS, *PDPN_SECURITY_CREDENTIALS;
typedef struct _DPN_SECURITY_DESC         DPN_SECURITY_DESC, *PDPN_SECURITY_DESC;

typedef struct _DPNMSG_ADD_PLAYER_TO_GROUP {
  DWORD	  dwSize;
  DPNID	  dpnidGroup;
  PVOID	  pvGroupContext;
  DPNID	  dpnidPlayer;
  PVOID	  pvPlayerContext;
} DPNMSG_ADD_PLAYER_TO_GROUP, *PDPNMSG_ADD_PLAYER_TO_GROUP;

typedef struct _DPNMSG_ASYNC_OP_COMPLETE {
  DWORD      dwSize;
  DPNHANDLE  hAsyncOp;
  PVOID      pvUserContext;
  HRESULT    hResultCode;
} DPNMSG_ASYNC_OP_COMPLETE, *PDPNMSG_ASYNC_OP_COMPLETE;

typedef struct _DPNMSG_CLIENT_INFO {
  DWORD	  dwSize;
  DPNID	  dpnidClient;
  PVOID	  pvPlayerContext;
} DPNMSG_CLIENT_INFO, *PDPNMSG_CLIENT_INFO;

typedef struct _DPNMSG_CONNECT_COMPLETE {
  DWORD      dwSize;
  DPNHANDLE  hAsyncOp;
  PVOID      pvUserContext;
  HRESULT    hResultCode;
  PVOID      pvApplicationReplyData;
  DWORD      dwApplicationReplyDataSize;
  /** DirectX 9 */
  DPNID      dpnidLocal;
} DPNMSG_CONNECT_COMPLETE, *PDPNMSG_CONNECT_COMPLETE;

typedef struct _DPNMSG_CREATE_GROUP {
  DWORD   dwSize;
  DPNID   dpnidGroup;
  DPNID   dpnidOwner;
  PVOID   pvGroupContext;
  /** DirectX 9 */
  PVOID   pvOwnerContext;	
} DPNMSG_CREATE_GROUP, *PDPNMSG_CREATE_GROUP;

typedef struct _DPNMSG_CREATE_PLAYER {
  DWORD   dwSize;
  DPNID   dpnidPlayer;
  PVOID   pvPlayerContext;
} DPNMSG_CREATE_PLAYER, *PDPNMSG_CREATE_PLAYER;

typedef struct _DPNMSG_DESTROY_GROUP {
  DWORD   dwSize;
  DPNID   dpnidGroup;
  PVOID   pvGroupContext;
  DWORD   dwReason;
} DPNMSG_DESTROY_GROUP, *PDPNMSG_DESTROY_GROUP;

typedef struct _DPNMSG_DESTROY_PLAYER {
  DWORD  dwSize;
  DPNID  dpnidPlayer;
  PVOID  pvPlayerContext;
  DWORD  dwReason;
} DPNMSG_DESTROY_PLAYER, *PDPNMSG_DESTROY_PLAYER;

typedef	struct _DPNMSG_ENUM_HOSTS_QUERY {
  DWORD                 dwSize;
  IDirectPlay8Address*  pAddressSender;
  IDirectPlay8Address*  pAddressDevice;
  PVOID                 pvReceivedData;
  DWORD                 dwReceivedDataSize;
  DWORD                 dwMaxResponseDataSize;
  PVOID                 pvResponseData;
  DWORD                 dwResponseDataSize;
  PVOID                 pvResponseContext;
} DPNMSG_ENUM_HOSTS_QUERY, *PDPNMSG_ENUM_HOSTS_QUERY;

typedef	struct _DPNMSG_ENUM_HOSTS_RESPONSE {
  DWORD                        dwSize;
  IDirectPlay8Address*         pAddressSender;
  IDirectPlay8Address*         pAddressDevice;
  const DPN_APPLICATION_DESC*  pApplicationDescription;
  PVOID                        pvResponseData;
  DWORD                        dwResponseDataSize;
  PVOID                        pvUserContext;
  DWORD                        dwRoundTripLatencyMS;
} DPNMSG_ENUM_HOSTS_RESPONSE, *PDPNMSG_ENUM_HOSTS_RESPONSE;

typedef struct _DPNMSG_GROUP_INFO {
  DWORD   dwSize;
  DPNID   dpnidGroup;
  PVOID   pvGroupContext;
} DPNMSG_GROUP_INFO, *PDPNMSG_GROUP_INFO;

typedef struct _DPNMSG_HOST_MIGRATE {
  DWORD   dwSize;
  DPNID   dpnidNewHost;
  PVOID   pvPlayerContext;
} DPNMSG_HOST_MIGRATE, *PDPNMSG_HOST_MIGRATE;

typedef struct _DPNMSG_INDICATE_CONNECT {
  DWORD                 dwSize;
  PVOID                 pvUserConnectData;
  DWORD                 dwUserConnectDataSize;
  PVOID                 pvReplyData;
  DWORD                 dwReplyDataSize;
  PVOID                 pvReplyContext;
  PVOID                 pvPlayerContext;
  IDirectPlay8Address*  pAddressPlayer;
  IDirectPlay8Address*  pAddressDevice;
} DPNMSG_INDICATE_CONNECT, *PDPNMSG_INDICATE_CONNECT;

typedef struct _DPNMSG_INDICATED_CONNECT_ABORTED {
  DWORD   dwSize;
  PVOID   pvPlayerContext;
} DPNMSG_INDICATED_CONNECT_ABORTED, *PDPNMSG_INDICATED_CONNECT_ABORTED;

typedef struct _DPNMSG_PEER_INFO {
  DWORD   dwSize;
  DPNID   dpnidPeer;
  PVOID   pvPlayerContext;
} DPNMSG_PEER_INFO, *PDPNMSG_PEER_INFO;

typedef struct _DPNMSG_RECEIVE {
  DWORD      dwSize;
  DPNID      dpnidSender;
  PVOID      pvPlayerContext;
  PBYTE      pReceiveData;
  DWORD      dwReceiveDataSize;
  DPNHANDLE  hBufferHandle;
  /** DirectX 9 */
  DWORD      dwReceiveFlags;	
} DPNMSG_RECEIVE, *PDPNMSG_RECEIVE;

typedef struct _DPNMSG_REMOVE_PLAYER_FROM_GROUP {
  DWORD   dwSize;
  DPNID   dpnidGroup;
  PVOID   pvGroupContext;
  DPNID   dpnidPlayer;
  PVOID   pvPlayerContext;
} DPNMSG_REMOVE_PLAYER_FROM_GROUP, *PDPNMSG_REMOVE_PLAYER_FROM_GROUP;

typedef struct _DPNMSG_RETURN_BUFFER {
  DWORD     dwSize;
  HRESULT   hResultCode;
  PVOID     pvBuffer;
  PVOID     pvUserContext;
} DPNMSG_RETURN_BUFFER, *PDPNMSG_RETURN_BUFFER;

typedef struct _DPNMSG_SEND_COMPLETE {
  DWORD       dwSize;
  DPNHANDLE   hAsyncOp;
  PVOID       pvUserContext;
  HRESULT     hResultCode;
  DWORD       dwSendTime;
  /** DirectX 9 */
  DWORD            dwFirstFrameRTT;
  DWORD            dwFirstFrameRetryCount;
  DWORD            dwSendCompleteFlags;
  DPN_BUFFER_DESC* pBuffers;
  DWORD            dwNumBuffers;
} DPNMSG_SEND_COMPLETE, *PDPNMSG_SEND_COMPLETE;

typedef struct _DPNMSG_SERVER_INFO {
  DWORD   dwSize;
  DPNID   dpnidServer;
  PVOID   pvPlayerContext;
} DPNMSG_SERVER_INFO, *PDPNMSG_SERVER_INFO;

typedef struct _DPNMSG_TERMINATE_SESSION {
  DWORD    dwSize;
  HRESULT  hResultCode;
  PVOID    pvTerminateData;
  DWORD    dwTerminateDataSize;
} DPNMSG_TERMINATE_SESSION, *PDPNMSG_TERMINATE_SESSION;

typedef struct _DPNMSG_CREATE_THREAD {
  DWORD    dwSize;
  DWORD    dwFlags;
  DWORD    dwProcessorNum;
  PVOID    pvUserContext;
} DPNMSG_CREATE_THREAD, *PDPNMSG_CREATE_THREAD;

typedef struct _DPNMSG_DESTROY_THREAD {
  DWORD    dwSize;
  DWORD    dwProcessorNum;
  PVOID    pvUserContext;
} DPNMSG_DESTROY_THREAD, *PDPNMSG_DESTROY_THREAD;

typedef	struct _DPNMSG_NAT_RESOLVER_QUERY {
  DWORD    dwSize;
  IDirectPlay8Address* pAddressSender;
  IDirectPlay8Address* pAddressDevice;
  WCHAR*   pwszUserString;
} DPNMSG_NAT_RESOLVER_QUERY, *PDPNMSG_NAT_RESOLVER_QUERY;

/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(CLSID_DirectPlay8Peer,        0x286f484d,0x375e,0x4458,0xa2,0x72,0xb1,0x38,0xe2,0xf8,0x0a,0x6a);
DEFINE_GUID(CLSID_DirectPlay8Client,      0x743f1dc6,0x5aba,0x429f,0x8b,0xdf,0xc5,0x4d,0x03,0x25,0x3d,0xc2);
DEFINE_GUID(CLSID_DirectPlay8Server,      0xda825e1b,0x6830,0x43d7,0x83,0x5d,0x0b,0x5a,0xd8,0x29,0x56,0xa2);
/** DirectX 9 */
DEFINE_GUID(CLSID_DirectPlay8ThreadPool,  0xfc47060e,0x6153,0x4b34,0xb9,0x75,0x8e,0x41,0x21,0xeb,0x7f,0x3c);
DEFINE_GUID(CLSID_DirectPlay8NATResolver, 0xe4c1d9a2,0xcbf7,0x48bd,0x9a,0x69,0x34,0xa5,0x5e,0x0d,0x89,0x41);

DEFINE_GUID(IID_IDirectPlay8Peer,         0x5102dacf,0x241b,0x11d3,0xae,0xa7,0x0,0x60,0x97,0xb0,0x14,0x11);
typedef struct IDirectPlay8Peer *PDIRECTPLAY8PEER;
DEFINE_GUID(IID_IDirectPlay8Client,       0x5102dacd,0x241b,0x11d3,0xae,0xa7,0x0,0x60,0x97,0xb0,0x14,0x11);
typedef struct IDirectPlay8Client *PDIRECTPLAY8CLIENT;
DEFINE_GUID(IID_IDirectPlay8Server,       0x5102dace,0x241b,0x11d3,0xae,0xa7,0x0,0x60,0x97,0xb0,0x14,0x11);
typedef struct IDirectPlay8Server *PDIRECTPLAY8SERVER;
/** DirectX 9 */
DEFINE_GUID(IID_IDirectPlay8ThreadPool,   0x0d22ee73,0x4a46,0x4a0d,0x89,0xb2,0x04,0x5b,0x4d,0x66,0x64,0x25);
typedef	struct IDirectPlay8ThreadPool *PDIRECTPLAY8THREADPOOL;
DEFINE_GUID(IID_IDirectPlay8NATResolver,  0xa9e213f2,0x9a60,0x486f,0xbf,0x3b,0x53,0x40,0x8b,0x6d,0x1c,0xbb);
typedef	struct IDirectPlay8NATResolver *PDIRECTPLAY8NATRESOLVER;

DEFINE_GUID(CLSID_DP8SP_IPX,               0x53934290,0x628d,0x11d2,0xae,0x0f,0x0,0x60,0x97,0xb0,0x14,0x11);
DEFINE_GUID(CLSID_DP8SP_TCPIP,             0xebfe7ba0,0x628d,0x11d2,0xae,0x0f,0x0,0x60,0x97,0xb0,0x14,0x11);
DEFINE_GUID(CLSID_DP8SP_SERIAL,            0x743b5d60,0x628d,0x11d2,0xae,0x0f,0x0,0x60,0x97,0xb0,0x14,0x11);
DEFINE_GUID(CLSID_DP8SP_MODEM,             0x6d4a3650,0x628d,0x11d2,0xae,0x0f,0x0,0x60,0x97,0xb0,0x14,0x11);
/** DirectX 9 */
DEFINE_GUID(CLSID_DP8SP_BLUETOOTH,         0x995513af,0x3027,0x4b9a,0x95,0x6e,0xc7,0x72,0xb3,0xf7,0x80,0x06);

typedef struct IDirectPlay8LobbiedApplication	*PIDirectPlay8LobbiedApplication, DNLOBBIEDAPPLICATION;


/*****************************************************************************
 * IDirectPlay8Client interface
 */
#define INTERFACE IDirectPlay8Client
DECLARE_INTERFACE_(IDirectPlay8Client,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8Client methods ***/
    STDMETHOD(Initialize)(THIS_ PVOID pvUserContext, PFNDPNMESSAGEHANDLER pfn, DWORD dwFlags) PURE;
    STDMETHOD(EnumServiceProviders)(THIS_ const GUID *pguidServiceProvider, const GUID *pguidApplication, DPN_SERVICE_PROVIDER_INFO *pSPInfoBuffer, PDWORD pcbEnumData, PDWORD pcReturned, DWORD dwFlags) PURE;
    STDMETHOD(EnumHosts)(THIS_ PDPN_APPLICATION_DESC pApplicationDesc,IDirectPlay8Address *pAddrHost,IDirectPlay8Address *pDeviceInfo, PVOID pUserEnumData, DWORD dwUserEnumDataSize, DWORD dwEnumCount, DWORD dwRetryInterval, DWORD dwTimeOut, PVOID pvUserContext, DPNHANDLE *pAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(CancelAsyncOperation)(THIS_ DPNHANDLE hAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(Connect)(THIS_ const DPN_APPLICATION_DESC *pdnAppDesc,IDirectPlay8Address *pHostAddr,IDirectPlay8Address *pDeviceInfo, const DPN_SECURITY_DESC *pdnSecurity, const DPN_SECURITY_CREDENTIALS *pdnCredentials, const void *pvUserConnectData, DWORD dwUserConnectDataSize,void *pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(Send)(THIS_ const DPN_BUFFER_DESC *prgBufferDesc, DWORD cBufferDesc, DWORD dwTimeOut, void *pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetSendQueueInfo)(THIS_ DWORD *pdwNumMsgs, DWORD *pdwNumBytes, DWORD dwFlags) PURE;
    STDMETHOD(GetApplicationDesc)(THIS_ DPN_APPLICATION_DESC *pAppDescBuffer, DWORD *pcbDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetClientInfo)(THIS_ const DPN_PLAYER_INFO *pdpnPlayerInfo, PVOID pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetServerInfo)(THIS_ DPN_PLAYER_INFO *pdpnPlayerInfo, DWORD *pdwSize, DWORD dwFlags) PURE;
    STDMETHOD(GetServerAddress)(THIS_ IDirectPlay8Address ** pAddress, DWORD dwFlags) PURE;
    STDMETHOD(Close)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(ReturnBuffer)(THIS_ DPNHANDLE hBufferHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetCaps)(THIS_ DPN_CAPS *pdpCaps, DWORD dwFlags) PURE;
    STDMETHOD(SetCaps)(THIS_ const DPN_CAPS *pdpCaps, DWORD dwFlags) PURE;
    STDMETHOD(SetSPCaps)(THIS_ const GUID *pguidSP, const DPN_SP_CAPS *pdpspCaps, DWORD dwFlags ) PURE;
    STDMETHOD(GetSPCaps)(THIS_ const GUID *pguidSP, DPN_SP_CAPS *pdpspCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetConnectionInfo)(THIS_ DPN_CONNECTION_INFO *pdpConnectionInfo, DWORD dwFlags) PURE;
    STDMETHOD(RegisterLobby)(THIS_ DPNHANDLE dpnHandle, struct IDirectPlay8LobbiedApplication *pIDP8LobbiedApplication, DWORD dwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define	IDirectPlay8Client_QueryInterface(p,a,b)                (p)->lpVtbl->QueryInterface(p,a,b)
#define	IDirectPlay8Client_AddRef(p)                            (p)->lpVtbl->AddRef(p)
#define	IDirectPlay8Client_Release(p)                           (p)->lpVtbl->Release(p)
/*** IDirectPlay8Client methods ***/
#define	IDirectPlay8Client_Initialize(p,a,b,c)                  (p)->lpVtbl->Initialize(p,a,b,c)
#define	IDirectPlay8Client_EnumServiceProviders(p,a,b,c,d,e,f)  (p)->lpVtbl->EnumServiceProviders(p,a,b,c,d,e,f)
#define	IDirectPlay8Client_EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)   (p)->lpVtbl->EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)
#define	IDirectPlay8Client_CancelAsyncOperation(p,a,b)          (p)->lpVtbl->CancelAsyncOperation(p,a,b)
#define	IDirectPlay8Client_Connect(p,a,b,c,d,e,f,g,h,i,j)       (p)->lpVtbl->Connect(p,a,b,c,d,e,f,g,h,i,j)
#define	IDirectPlay8Client_Send(p,a,b,c,d,e,f)                  (p)->lpVtbl->Send(p,a,b,c,d,e,f)
#define	IDirectPlay8Client_GetSendQueueInfo(p,a,b,c)            (p)->lpVtbl->GetSendQueueInfo(p,a,b,c)
#define	IDirectPlay8Client_GetApplicationDesc(p,a,b,c)          (p)->lpVtbl->GetApplicationDesc(p,a,b,c)
#define	IDirectPlay8Client_SetClientInfo(p,a,b,c,d)             (p)->lpVtbl->SetClientInfo(p,a,b,c,d)
#define	IDirectPlay8Client_GetServerInfo(p,a,b,c)               (p)->lpVtbl->GetServerInfo(p,a,b,c)
#define	IDirectPlay8Client_GetServerAddress(p,a,b)              (p)->lpVtbl->GetServerAddress(p,a,b)
#define	IDirectPlay8Client_Close(p,a)                           (p)->lpVtbl->Close(p,a)
#define	IDirectPlay8Client_ReturnBuffer(p,a,b)                  (p)->lpVtbl->ReturnBuffer(p,a,b)
#define	IDirectPlay8Client_GetCaps(p,a,b)                       (p)->lpVtbl->GetCaps(p,a,b)
#define	IDirectPlay8Client_SetCaps(p,a,b)                       (p)->lpVtbl->SetCaps(p,a,b)
#define	IDirectPlay8Client_SetSPCaps(p,a,b,c)                   (p)->lpVtbl->SetSPCaps(p,a,b,c)
#define	IDirectPlay8Client_GetSPCaps(p,a,b,c)                   (p)->lpVtbl->GetSPCaps(p,a,b,c)
#define	IDirectPlay8Client_GetConnectionInfo(p,a,b)             (p)->lpVtbl->GetConnectionInfo(p,a,b)
#define	IDirectPlay8Client_RegisterLobby(p,a,b,c)               (p)->lpVtbl->RegisterLobby(p,a,b,c)
#else
/*** IUnknown methods ***/
#define	IDirectPlay8Client_QueryInterface(p,a,b)                (p)->QueryInterface(a,b)
#define	IDirectPlay8Client_AddRef(p)                            (p)->AddRef()
#define	IDirectPlay8Client_Release(p)                           (p)->Release()
/*** IDirectPlay8Client methods ***/
#define	IDirectPlay8Client_Initialize(p,a,b,c)                  (p)->Initialize(a,b,c)
#define	IDirectPlay8Client_EnumServiceProviders(p,a,b,c,d,e,f)  (p)->EnumServiceProviders(a,b,c,d,e,f)
#define	IDirectPlay8Client_EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)   (p)->EnumHosts(a,b,c,d,e,f,g,h,i,j,k)
#define	IDirectPlay8Client_CancelAsyncOperation(p,a,b)          (p)->CancelAsyncOperation(a,b)
#define	IDirectPlay8Client_Connect(p,a,b,c,d,e,f,g,h,i,j)       (p)->Connect(a,b,c,d,e,f,g,h,i,j)
#define	IDirectPlay8Client_Send(p,a,b,c,d,e,f)                  (p)->Send(a,b,c,d,e,f)
#define	IDirectPlay8Client_GetSendQueueInfo(p,a,b,c)            (p)->GetSendQueueInfo(a,b,c)
#define	IDirectPlay8Client_GetApplicationDesc(p,a,b,c)          (p)->GetApplicationDesc(a,b,c)
#define	IDirectPlay8Client_SetClientInfo(p,a,b,c,d)             (p)->SetClientInfo(a,b,c,d)
#define	IDirectPlay8Client_GetServerInfo(p,a,b,c)               (p)->GetServerInfo(a,b,c)
#define	IDirectPlay8Client_GetServerAddress(p,a,b)              (p)->GetServerAddress(a,b)
#define	IDirectPlay8Client_Close(p,a)                           (p)->Close(a)
#define	IDirectPlay8Client_ReturnBuffer(p,a,b)                  (p)->ReturnBuffer(a,b)
#define	IDirectPlay8Client_GetCaps(p,a,b)                       (p)->GetCaps(a,b)
#define	IDirectPlay8Client_SetCaps(p,a,b)                       (p)->SetCaps(a,b)
#define	IDirectPlay8Client_SetSPCaps(p,a,b,c)                   (p)->SetSPCaps(a,b,c)
#define	IDirectPlay8Client_GetSPCaps(p,a,b,c)                   (p)->GetSPCaps(a,b,c)
#define	IDirectPlay8Client_GetConnectionInfo(p,a,b)             (p)->GetConnectionInfo(a,b)
#define	IDirectPlay8Client_RegisterLobby(p,a,b,c)               (p)->RegisterLobby(a,b,c)
#endif

/*****************************************************************************
 * IDirectPlay8Server interface
 */
#define INTERFACE IDirectPlay8Server
DECLARE_INTERFACE_(IDirectPlay8Server,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8Server methods ***/
    STDMETHOD(Initialize)(THIS_ PVOID pvUserContext, PFNDPNMESSAGEHANDLER pfn, DWORD dwFlags) PURE;
    STDMETHOD(EnumServiceProviders)(THIS_ const GUID *pguidServiceProvider, const GUID *pguidApplication, DPN_SERVICE_PROVIDER_INFO *pSPInfoBuffer, PDWORD pcbEnumData, PDWORD pcReturned, DWORD dwFlags) PURE;
    STDMETHOD(CancelAsyncOperation)(THIS_ DPNHANDLE hAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetSendQueueInfo)(THIS_ DPNID dpnid, DWORD *pdwNumMsgs, DWORD *pdwNumBytes, DWORD dwFlags) PURE;
    STDMETHOD(GetApplicationDesc)(THIS_ DPN_APPLICATION_DESC *pAppDescBuffer, DWORD *pcbDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetServerInfo)(THIS_ const DPN_PLAYER_INFO *pdpnPlayerInfo, PVOID pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetClientInfo)(THIS_ DPNID dpnid, DPN_PLAYER_INFO *pdpnPlayerInfo, DWORD *pdwSize, DWORD dwFlags) PURE;
    STDMETHOD(GetClientAddress)(THIS_ DPNID dpnid, IDirectPlay8Address ** pAddress, DWORD dwFlags) PURE;
    STDMETHOD(GetLocalHostAddresses)(THIS_ IDirectPlay8Address ** prgpAddress, DWORD *pcAddress, DWORD dwFlags) PURE;
    STDMETHOD(SetApplicationDesc)(THIS_ const DPN_APPLICATION_DESC *pad, DWORD dwFlags) PURE;
    STDMETHOD(Host)(THIS_ const DPN_APPLICATION_DESC *pdnAppDesc, IDirectPlay8Address ** prgpDeviceInfo, DWORD cDeviceInfo, const DPN_SECURITY_DESC *pdnSecurity, const DPN_SECURITY_CREDENTIALS *pdnCredentials, void *pvPlayerContext, DWORD dwFlags) PURE;
    STDMETHOD(SendTo)(THIS_ DPNID dpnid, const DPN_BUFFER_DESC *prgBufferDesc, DWORD cBufferDesc, DWORD dwTimeOut, void *pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(CreateGroup)(THIS_ const DPN_GROUP_INFO *pdpnGroupInfo, void *pvGroupContext, void *pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(DestroyGroup)(THIS_ DPNID idGroup, PVOID pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(AddPlayerToGroup)(THIS_ DPNID idGroup, DPNID idClient, PVOID pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(RemovePlayerFromGroup)(THIS_ DPNID idGroup, DPNID idClient, PVOID pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(SetGroupInfo)(THIS_ DPNID dpnid, DPN_GROUP_INFO *pdpnGroupInfo, PVOID pvAsyncContext, DPNHANDLE *phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupInfo)(THIS_ DPNID dpnid, DPN_GROUP_INFO *pdpnGroupInfo, DWORD *pdwSize, DWORD dwFlags) PURE;
    STDMETHOD(EnumPlayersAndGroups)(THIS_ DPNID *prgdpnid, DWORD *pcdpnid, DWORD dwFlags) PURE;
    STDMETHOD(EnumGroupMembers)(THIS_ DPNID dpnid, DPNID *prgdpnid, DWORD *pcdpnid, DWORD dwFlags) PURE;
    STDMETHOD(Close)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(DestroyClient)(THIS_ DPNID dpnidClient, const void *pvDestroyData, DWORD dwDestroyDataSize, DWORD dwFlags) PURE;
    STDMETHOD(ReturnBuffer)(THIS_ DPNHANDLE hBufferHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetPlayerContext)(THIS_ DPNID dpnid, PVOID *ppvPlayerContext, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupContext)(THIS_ DPNID dpnid, PVOID *ppvGroupContext, DWORD dwFlags) PURE;
    STDMETHOD(GetCaps)(THIS_ DPN_CAPS *pdpCaps, DWORD dwFlags) PURE;
    STDMETHOD(SetCaps)(THIS_ const DPN_CAPS *pdpCaps, DWORD dwFlags) PURE;
    STDMETHOD(SetSPCaps)(THIS_ const GUID *pguidSP, const DPN_SP_CAPS *pdpspCaps, DWORD dwFlags ) PURE;
    STDMETHOD(GetSPCaps)(THIS_ const GUID *pguidSP, DPN_SP_CAPS *pdpspCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetConnectionInfo)(THIS_ DPNID dpnid, DPN_CONNECTION_INFO *pdpConnectionInfo, DWORD dwFlags) PURE;
    STDMETHOD(RegisterLobby)(THIS_ DPNHANDLE dpnHandle, struct IDirectPlay8LobbiedApplication *pIDP8LobbiedApplication, DWORD dwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define	IDirectPlay8Server_QueryInterface(p,a,b)                (p)->lpVtbl->QueryInterface(p,a,b)
#define	IDirectPlay8Server_AddRef(p)                            (p)->lpVtbl->AddRef(p)
#define	IDirectPlay8Server_Release(p)                           (p)->lpVtbl->Release(p)
/*** IDirectPlay8Server methods ***/
#define	IDirectPlay8Server_Initialize(p,a,b,c)                  (p)->lpVtbl->Initialize(p,a,b,c)
#define	IDirectPlay8Server_EnumServiceProviders(p,a,b,c,d,e,f)  (p)->lpVtbl->EnumServiceProviders(p,a,b,c,d,e,f)
#define	IDirectPlay8Server_CancelAsyncOperation(p,a,b)          (p)->lpVtbl->CancelAsyncOperation(p,a,b)
#define	IDirectPlay8Server_GetSendQueueInfo(p,a,b,c,d)          (p)->lpVtbl->GetSendQueueInfo(p,a,b,c,d)
#define	IDirectPlay8Server_GetApplicationDesc(p,a,b,c)          (p)->lpVtbl->GetApplicationDesc(p,a,b,c)
#define	IDirectPlay8Server_SetServerInfo(p,a,b,c,d)             (p)->lpVtbl->SetServerInfo(p,a,b,c,d)
#define	IDirectPlay8Server_GetClientInfo(p,a,b,c,d)             (p)->lpVtbl->GetClientInfo(p,a,b,c,d)
#define	IDirectPlay8Server_GetClientAddress(p,a,b,c)            (p)->lpVtbl->GetClientAddress(p,a,b,c)
#define	IDirectPlay8Server_GetLocalHostAddresses(p,a,b,c)       (p)->lpVtbl->GetLocalHostAddresses(p,a,b,c)
#define	IDirectPlay8Server_SetApplicationDesc(p,a,b)            (p)->lpVtbl->SetApplicationDesc(p,a,b)
#define	IDirectPlay8Server_Host(p,a,b,c,d,e,f,g)                (p)->lpVtbl->Host(p,a,b,c,d,e,f,g)
#define	IDirectPlay8Server_SendTo(p,a,b,c,d,e,f,g)              (p)->lpVtbl->SendTo(p,a,b,c,d,e,f,g)
#define	IDirectPlay8Server_CreateGroup(p,a,b,c,d,e)             (p)->lpVtbl->CreateGroup(p,a,b,c,d,e)
#define	IDirectPlay8Server_DestroyGroup(p,a,b,c,d)              (p)->lpVtbl->DestroyGroup(p,a,b,c,d)
#define	IDirectPlay8Server_AddPlayerToGroup(p,a,b,c,d,e)        (p)->lpVtbl->AddPlayerToGroup(p,a,b,c,d,e)
#define	IDirectPlay8Server_RemovePlayerFromGroup(p,a,b,c,d,e)   (p)->lpVtbl->RemovePlayerFromGroup(p,a,b,c,d,e)
#define	IDirectPlay8Server_SetGroupInfo(p,a,b,c,d,e)            (p)->lpVtbl->SetGroupInfo(p,a,b,c,d,e)
#define	IDirectPlay8Server_GetGroupInfo(p,a,b,c,d)              (p)->lpVtbl->GetGroupInfo(p,a,b,c,d)
#define	IDirectPlay8Server_EnumPlayersAndGroups(p,a,b,c)        (p)->lpVtbl->EnumPlayersAndGroups(p,a,b,c)
#define	IDirectPlay8Server_EnumGroupMembers(p,a,b,c,d)          (p)->lpVtbl->EnumGroupMembers(p,a,b,c,d)
#define	IDirectPlay8Server_Close(p,a)                           (p)->lpVtbl->Close(p,a)
#define	IDirectPlay8Server_DestroyClient(p,a,b,c,d)             (p)->lpVtbl->DestroyClient(p,a,b,c,d)
#define	IDirectPlay8Server_ReturnBuffer(p,a,b)                  (p)->lpVtbl->ReturnBuffer(p,a,b)
#define	IDirectPlay8Server_GetPlayerContext(p,a,b,c)            (p)->lpVtbl->GetPlayerContext(p,a,b,c)
#define	IDirectPlay8Server_GetGroupContext(p,a,b,c)             (p)->lpVtbl->GetGroupContext(p,a,b,c)
#define	IDirectPlay8Server_GetCaps(p,a,b)                       (p)->lpVtbl->GetCaps(p,a,b)
#define	IDirectPlay8Server_SetCaps(p,a,b)                       (p)->lpVtbl->SetCaps(p,a,b)
#define	IDirectPlay8Server_SetSPCaps(p,a,b,c)                   (p)->lpVtbl->SetSPCaps(p,a,b,c)
#define	IDirectPlay8Server_GetSPCaps(p,a,b,c)                   (p)->lpVtbl->GetSPCaps(p,a,b,c)
#define	IDirectPlay8Server_GetConnectionInfo(p,a,b,c)           (p)->lpVtbl->GetConnectionInfo(p,a,b,c)
#define	IDirectPlay8Server_RegisterLobby(p,a,b,c)               (p)->lpVtbl->RegisterLobby(p,a,b,c)
#else
/*** IUnknown methods ***/
#define	IDirectPlay8Server_QueryInterface(p,a,b)                (p)->QueryInterface(a,b)
#define	IDirectPlay8Server_AddRef(p)                            (p)->AddRef()
#define	IDirectPlay8Server_Release(p)                           (p)->Release()
/*** IDirectPlay8Server methods ***/
#define	IDirectPlay8Server_Initialize(p,a,b,c)                  (p)->Initialize(a,b,c)
#define	IDirectPlay8Server_EnumServiceProviders(p,a,b,c,d,e,f)  (p)->EnumServiceProviders(a,b,c,d,e,f)
#define	IDirectPlay8Server_CancelAsyncOperation(p,a,b)          (p)->CancelAsyncOperation(a,b)
#define	IDirectPlay8Server_GetSendQueueInfo(p,a,b,c,d)          (p)->GetSendQueueInfo(a,b,c,d)
#define	IDirectPlay8Server_GetApplicationDesc(p,a,b,c)          (p)->GetApplicationDesc(a,b,c)
#define	IDirectPlay8Server_SetServerInfo(p,a,b,c,d)             (p)->SetServerInfo(a,b,c,d)
#define	IDirectPlay8Server_GetClientInfo(p,a,b,c,d)             (p)->GetClientInfo(a,b,c,d)
#define	IDirectPlay8Server_GetClientAddress(p,a,b,c)            (p)->GetClientAddress(a,b,c)
#define	IDirectPlay8Server_GetLocalHostAddresses(p,a,b,c)       (p)->GetLocalHostAddresses(a,b,c)
#define	IDirectPlay8Server_SetApplicationDesc(p,a,b)            (p)->SetApplicationDesc(a,b)
#define	IDirectPlay8Server_Host(p,a,b,c,d,e,f,g)                (p)->Host(a,b,c,d,e,f,g)
#define	IDirectPlay8Server_SendTo(p,a,b,c,d,e,f,g)              (p)->SendTo(a,b,c,d,e,f,g)
#define	IDirectPlay8Server_CreateGroup(p,a,b,c,d,e)             (p)->CreateGroup(a,b,c,d,e)
#define	IDirectPlay8Server_DestroyGroup(p,a,b,c,d)              (p)->DestroyGroup(a,b,c,d)
#define	IDirectPlay8Server_AddPlayerToGroup(p,a,b,c,d,e)        (p)->AddPlayerToGroup(a,b,c,d,e)
#define	IDirectPlay8Server_RemovePlayerFromGroup(p,a,b,c,d,e)   (p)->RemovePlayerFromGroup(a,b,c,d,e)
#define	IDirectPlay8Server_SetGroupInfo(p,a,b,c,d,e)            (p)->SetGroupInfo(a,b,c,d,e)
#define	IDirectPlay8Server_GetGroupInfo(p,a,b,c,d)              (p)->GetGroupInfo(a,b,c,d)
#define	IDirectPlay8Server_EnumPlayersAndGroups(p,a,b,c)        (p)->EnumPlayersAndGroups(a,b,c)
#define	IDirectPlay8Server_EnumGroupMembers(p,a,b,c,d)          (p)->EnumGroupMembers(a,b,c,d)
#define	IDirectPlay8Server_Close(p,a)                           (p)->Close(a)
#define	IDirectPlay8Server_DestroyClient(p,a,b,c,d)             (p)->DestroyClient(a,b,c,d)
#define	IDirectPlay8Server_ReturnBuffer(p,a,b)                  (p)->ReturnBuffer(a,b)
#define	IDirectPlay8Server_GetPlayerContext(p,a,b,c)            (p)->GetPlayerContext(a,b,c)
#define	IDirectPlay8Server_GetGroupContext(p,a,b,c)             (p)->GetGroupContext(a,b,c)
#define	IDirectPlay8Server_GetCaps(p,a,b)                       (p)->GetCaps(a,b)
#define	IDirectPlay8Server_SetCaps(p,a,b)                       (p)->SetCaps(a,b)
#define	IDirectPlay8Server_SetSPCaps(p,a,b,c)                   (p)->SetSPCaps(a,b,c)
#define	IDirectPlay8Server_GetSPCaps(p,a,b,c)                   (p)->GetSPCaps(a,b,c)
#define	IDirectPlay8Server_GetConnectionInfo(p,a,b,c)           (p)->GetConnectionInfo(a,b,c)
#define	IDirectPlay8Server_RegisterLobby(p,a,b,c)               (p)->RegisterLobby(a,b,c)
#endif

/*****************************************************************************
 * IDirectPlay8Peer interface
 */
#define INTERFACE IDirectPlay8Peer
DECLARE_INTERFACE_(IDirectPlay8Peer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8Peer methods ***/
    STDMETHOD(Initialize)(THIS_ PVOID pvUserContext, PFNDPNMESSAGEHANDLER pfn, DWORD dwFlags) PURE;
    STDMETHOD(EnumServiceProviders)(THIS_ const GUID* pguidServiceProvider, const GUID* pguidApplication, DPN_SERVICE_PROVIDER_INFO* pSPInfoBuffer, DWORD* pcbEnumData, DWORD* pcReturned, DWORD dwFlags) PURE;
    STDMETHOD(CancelAsyncOperation)(THIS_ DPNHANDLE hAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(Connect)(THIS_ const DPN_APPLICATION_DESC* pdnAppDesc, IDirectPlay8Address* pHostAddr, IDirectPlay8Address* pDeviceInfo, const DPN_SECURITY_DESC* pdnSecurity, const DPN_SECURITY_CREDENTIALS* pdnCredentials, const void* pvUserConnectData, DWORD dwUserConnectDataSize, void* pvPlayerContext, void* pvAsyncContext, DPNHANDLE* phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(SendTo)(THIS_ DPNID dpnid, const DPN_BUFFER_DESC* prgBufferDesc, DWORD cBufferDesc, DWORD dwTimeOut, void* pvAsyncContext, DPNHANDLE* phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetSendQueueInfo)(THIS_ DPNID dpnid, DWORD* pdwNumMsgs, DWORD* pdwNumBytes, DWORD dwFlags) PURE;
    STDMETHOD(Host)(THIS_ const DPN_APPLICATION_DESC* pdnAppDesc, IDirectPlay8Address **prgpDeviceInfo, DWORD cDeviceInfo, const DPN_SECURITY_DESC* pdnSecurity, const DPN_SECURITY_CREDENTIALS* pdnCredentials, void* pvPlayerContext, DWORD dwFlags) PURE;
    STDMETHOD(GetApplicationDesc)(THIS_ DPN_APPLICATION_DESC* pAppDescBuffer, DWORD* pcbDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetApplicationDesc)(THIS_ const DPN_APPLICATION_DESC* pad, DWORD dwFlags) PURE;
    STDMETHOD(CreateGroup)(THIS_ const DPN_GROUP_INFO* pdpnGroupInfo, void* pvGroupContext, void* pvAsyncContext, DPNHANDLE* phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(DestroyGroup)(THIS_ DPNID idGroup, PVOID pvAsyncContext, DPNHANDLE* phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(AddPlayerToGroup)(THIS_ DPNID idGroup, DPNID idClient, PVOID pvAsyncContext, DPNHANDLE* phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(RemovePlayerFromGroup)(THIS_ DPNID idGroup, DPNID idClient, PVOID pvAsyncContext, DPNHANDLE* phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(SetGroupInfo)(THIS_ DPNID dpnid, DPN_GROUP_INFO* pdpnGroupInfo,PVOID pvAsyncContext, DPNHANDLE* phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupInfo)(THIS_ DPNID dpnid, DPN_GROUP_INFO* pdpnGroupInfo, DWORD* pdwSize, DWORD dwFlags) PURE;
    STDMETHOD(EnumPlayersAndGroups)(THIS_ DPNID* prgdpnid, DWORD* pcdpnid, DWORD dwFlags) PURE;
    STDMETHOD(EnumGroupMembers)(THIS_ DPNID dpnid, DPNID* prgdpnid, DWORD* pcdpnid, DWORD dwFlags) PURE;
    STDMETHOD(SetPeerInfo)(THIS_ const DPN_PLAYER_INFO* pdpnPlayerInfo,PVOID pvAsyncContext, DPNHANDLE* phAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetPeerInfo)(THIS_ DPNID dpnid, DPN_PLAYER_INFO* pdpnPlayerInfo, DWORD* pdwSize, DWORD dwFlags) PURE;
    STDMETHOD(GetPeerAddress)(THIS_ DPNID dpnid, IDirectPlay8Address** pAddress, DWORD dwFlags) PURE;
    STDMETHOD(GetLocalHostAddresses)(THIS_ IDirectPlay8Address** prgpAddress, DWORD* pcAddress, DWORD dwFlags) PURE;
    STDMETHOD(Close)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(EnumHosts)(THIS_ PDPN_APPLICATION_DESC pApplicationDesc, IDirectPlay8Address* pAddrHost, IDirectPlay8Address* pDeviceInfo,PVOID pUserEnumData, DWORD dwUserEnumDataSize, DWORD dwEnumCount, DWORD dwRetryInterval, DWORD dwTimeOut,PVOID pvUserContext, DPNHANDLE* pAsyncHandle, DWORD dwFlags) PURE;
    STDMETHOD(DestroyPeer)(THIS_ DPNID dpnidClient, const void* pvDestroyData, DWORD dwDestroyDataSize, DWORD dwFlags) PURE;
    STDMETHOD(ReturnBuffer)(THIS_ DPNHANDLE hBufferHandle, DWORD dwFlags) PURE;
    STDMETHOD(GetPlayerContext)(THIS_ DPNID dpnid,PVOID* ppvPlayerContext, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupContext)(THIS_ DPNID dpnid,PVOID* ppvGroupContext, DWORD dwFlags) PURE;
    STDMETHOD(GetCaps)(THIS_ DPN_CAPS* pdpCaps, DWORD dwFlags) PURE;
    STDMETHOD(SetCaps)(THIS_ const DPN_CAPS* pdpCaps, DWORD dwFlags) PURE;
    STDMETHOD(SetSPCaps)(THIS_ const GUID* pguidSP, const DPN_SP_CAPS* pdpspCaps, DWORD dwFlags ) PURE;
    STDMETHOD(GetSPCaps)(THIS_ const GUID* pguidSP, DPN_SP_CAPS* pdpspCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetConnectionInfo)(THIS_ DPNID dpnid, DPN_CONNECTION_INFO* pdpConnectionInfo, DWORD dwFlags) PURE;
    STDMETHOD(RegisterLobby)(THIS_ DPNHANDLE dpnHandle, struct IDirectPlay8LobbiedApplication* pIDP8LobbiedApplication, DWORD dwFlags) PURE;
    STDMETHOD(TerminateSession)(THIS_ void* pvTerminateData, DWORD dwTerminateDataSize, DWORD dwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define	IDirectPlay8Peer_QueryInterface(p,a,b)                  (p)->lpVtbl->QueryInterface(p,a,b)
#define	IDirectPlay8Peer_AddRef(p)                              (p)->lpVtbl->AddRef(p)
#define	IDirectPlay8Peer_Release(p)                             (p)->lpVtbl->Release(p)
/*** IDirectPlay8Peer methods ***/
#define	IDirectPlay8Peer_Initialize(p,a,b,c)                    (p)->lpVtbl->Initialize(p,a,b,c)
#define	IDirectPlay8Peer_EnumServiceProviders(p,a,b,c,d,e,f)    (p)->lpVtbl->EnumServiceProviders(p,a,b,c,d,e,f)
#define	IDirectPlay8Peer_EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)     (p)->lpVtbl->EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)
#define	IDirectPlay8Peer_CancelAsyncOperation(p,a,b)            (p)->lpVtbl->CancelAsyncOperation(p,a,b)
#define	IDirectPlay8Peer_Connect(p,a,b,c,d,e,f,g,h,i,j,k)       (p)->lpVtbl->Connect(p,a,b,c,d,e,f,g,h,i,j,k)
#define	IDirectPlay8Peer_SendTo(p,a,b,c,d,e,f,g)                (p)->lpVtbl->SendTo(p,a,b,c,d,e,f,g)
#define	IDirectPlay8Peer_GetSendQueueInfo(p,a,b,c,d)            (p)->lpVtbl->GetSendQueueInfo(p,a,b,c,d)
#define	IDirectPlay8Peer_Host(p,a,b,c,d,e,f,g)                  (p)->lpVtbl->Host(p,a,b,c,d,e,f,g)
#define	IDirectPlay8Peer_GetApplicationDesc(p,a,b,c)            (p)->lpVtbl->GetApplicationDesc(p,a,b,c)
#define	IDirectPlay8Peer_SetApplicationDesc(p,a,b)              (p)->lpVtbl->SetApplicationDesc(p,a,b)
#define	IDirectPlay8Peer_CreateGroup(p,a,b,c,d,e)               (p)->lpVtbl->CreateGroup(p,a,b,c,d,e)
#define	IDirectPlay8Peer_DestroyGroup(p,a,b,c,d)                (p)->lpVtbl->DestroyGroup(p,a,b,c,d)
#define	IDirectPlay8Peer_AddPlayerToGroup(p,a,b,c,d,e)          (p)->lpVtbl->AddPlayerToGroup(p,a,b,c,d,e)
#define	IDirectPlay8Peer_RemovePlayerFromGroup(p,a,b,c,d,e)     (p)->lpVtbl->RemovePlayerFromGroup(p,a,b,c,d,e)
#define	IDirectPlay8Peer_SetGroupInfo(p,a,b,c,d,e)              (p)->lpVtbl->SetGroupInfo(p,a,b,c,d,e)
#define	IDirectPlay8Peer_GetGroupInfo(p,a,b,c,d)                (p)->lpVtbl->GetGroupInfo(p,a,b,c,d)
#define	IDirectPlay8Peer_EnumPlayersAndGroups(p,a,b,c)          (p)->lpVtbl->EnumPlayersAndGroups(p,a,b,c)
#define	IDirectPlay8Peer_EnumGroupMembers(p,a,b,c,d)            (p)->lpVtbl->EnumGroupMembers(p,a,b,c,d)
#define	IDirectPlay8Peer_SetPeerInfo(p,a,b,c,d)                 (p)->lpVtbl->SetPeerInfo(p,a,b,c,d)
#define	IDirectPlay8Peer_GetPeerInfo(p,a,b,c,d)                 (p)->lpVtbl->GetPeerInfo(p,a,b,c,d)
#define	IDirectPlay8Peer_GetPeerAddress(p,a,b,c)                (p)->lpVtbl->GetPeerAddress(p,a,b,c)
#define	IDirectPlay8Peer_GetLocalHostAddresses(p,a,b,c)         (p)->lpVtbl->GetLocalHostAddresses(p,a,b,c)
#define	IDirectPlay8Peer_Close(p,a)                             (p)->lpVtbl->Close(p,a)
#define	IDirectPlay8Peer_EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)     (p)->lpVtbl->EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)
#define	IDirectPlay8Peer_DestroyPeer(p,a,b,c,d)                 (p)->lpVtbl->DestroyPeer(p,a,b,c,d)
#define	IDirectPlay8Peer_ReturnBuffer(p,a,b)                    (p)->lpVtbl->ReturnBuffer(p,a,b)
#define	IDirectPlay8Peer_GetPlayerContext(p,a,b,c)              (p)->lpVtbl->GetPlayerContext(p,a,b,c)
#define	IDirectPlay8Peer_GetGroupContext(p,a,b,c)               (p)->lpVtbl->GetGroupContext(p,a,b,c)
#define	IDirectPlay8Peer_GetCaps(p,a,b)                         (p)->lpVtbl->GetCaps(p,a,b)
#define	IDirectPlay8Peer_SetCaps(p,a,b)                         (p)->lpVtbl->SetCaps(p,a,b)
#define	IDirectPlay8Peer_SetSPCaps(p,a,b,c)                     (p)->lpVtbl->SetSPCaps(p,a,b,c)
#define	IDirectPlay8Peer_GetSPCaps(p,a,b,c)                     (p)->lpVtbl->GetSPCaps(p,a,b,c)
#define	IDirectPlay8Peer_GetConnectionInfo(p,a,b,c)             (p)->lpVtbl->GetConnectionInfo(p,a,b,c)
#define	IDirectPlay8Peer_RegisterLobby(p,a,b,c)                 (p)->lpVtbl->RegisterLobby(p,a,b,c)
#define	IDirectPlay8Peer_TerminateSession(p,a,b,c)              (p)->lpVtbl->TerminateSession(p,a,b,c)
#else
/*** IUnknown methods ***/
#define	IDirectPlay8Peer_QueryInterface(p,a,b)                  (p)->QueryInterface(a,b)
#define	IDirectPlay8Peer_AddRef(p)                              (p)->AddRef()
#define	IDirectPlay8Peer_Release(p)                             (p)->Release()
/*** IDirectPlay8Peer methods ***/
#define	IDirectPlay8Peer_Initialize(p,a,b,c)                    (p)->Initialize(a,b,c)
#define	IDirectPlay8Peer_EnumServiceProviders(p,a,b,c,d,e,f)    (p)->EnumServiceProviders(a,b,c,d,e,f)
#define	IDirectPlay8Peer_EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)     (p)->EnumHosts(a,b,c,d,e,f,g,h,i,j,k)
#define	IDirectPlay8Peer_CancelAsyncOperation(p,a,b)            (p)->CancelAsyncOperation(a,b)
#define	IDirectPlay8Peer_Connect(p,a,b,c,d,e,f,g,h,i,j,k)       (p)->Connect(a,b,c,d,e,f,g,h,i,j,k)
#define	IDirectPlay8Peer_SendTo(p,a,b,c,d,e,f,g)                (p)->SendTo(a,b,c,d,e,f,g)
#define	IDirectPlay8Peer_GetSendQueueInfo(p,a,b,c,d)            (p)->GetSendQueueInfo(a,b,c,d)
#define	IDirectPlay8Peer_Host(p,a,b,c,d,e,f,g)                  (p)->Host(a,b,c,d,e,f,g)
#define	IDirectPlay8Peer_GetApplicationDesc(p,a,b,c)            (p)->GetApplicationDesc(a,b,c)
#define	IDirectPlay8Peer_SetApplicationDesc(p,a,b)              (p)->SetApplicationDesc(a,b)
#define	IDirectPlay8Peer_CreateGroup(p,a,b,c,d,e)               (p)->CreateGroup(a,b,c,d,e)
#define	IDirectPlay8Peer_DestroyGroup(p,a,b,c,d)                (p)->DestroyGroup(a,b,c,d)
#define	IDirectPlay8Peer_AddPlayerToGroup(p,a,b,c,d,e)          (p)->AddPlayerToGroup(a,b,c,d,e)
#define	IDirectPlay8Peer_RemovePlayerFromGroup(p,a,b,c,d,e)     (p)->RemovePlayerFromGroup(a,b,c,d,e)
#define	IDirectPlay8Peer_SetGroupInfo(p,a,b,c,d,e)              (p)->SetGroupInfo(a,b,c,d,e)
#define	IDirectPlay8Peer_GetGroupInfo(p,a,b,c,d)                (p)->GetGroupInfo(a,b,c,d)
#define	IDirectPlay8Peer_EnumPlayersAndGroups(p,a,b,c)          (p)->EnumPlayersAndGroups(a,b,c)
#define	IDirectPlay8Peer_EnumGroupMembers(p,a,b,c,d)            (p)->EnumGroupMembers(a,b,c,d)
#define	IDirectPlay8Peer_SetPeerInfo(p,a,b,c,d)                 (p)->SetPeerInfo(a,b,c,d)
#define	IDirectPlay8Peer_GetPeerInfo(p,a,b,c,d)                 (p)->GetPeerInfo(a,b,c,d)
#define	IDirectPlay8Peer_GetPeerAddress(p,a,b,c)                (p)->GetPeerAddress(a,b,c)
#define	IDirectPlay8Peer_GetLocalHostAddresses(p,a,b,c)         (p)->GetLocalHostAddresses(a,b,c)
#define	IDirectPlay8Peer_Close(p,a)                             (p)->Close(a)
#define	IDirectPlay8Peer_EnumHosts(p,a,b,c,d,e,f,g,h,i,j,k)     (p)->EnumHosts(a,b,c,d,e,f,g,h,i,j,k)
#define	IDirectPlay8Peer_DestroyPeer(p,a,b,c,d)                 (p)->DestroyPeer(a,b,c,d)
#define	IDirectPlay8Peer_ReturnBuffer(p,a,b)                    (p)->ReturnBuffer(a,b)
#define	IDirectPlay8Peer_GetPlayerContext(p,a,b,c)              (p)->GetPlayerContext(a,b,c)
#define	IDirectPlay8Peer_GetGroupContext(p,a,b,c)               (p)->GetGroupContext(a,b,c)
#define	IDirectPlay8Peer_GetCaps(p,a,b)                         (p)->GetCaps(a,b)
#define	IDirectPlay8Peer_SetCaps(p,a,b)                         (p)->SetCaps(a,b)
#define	IDirectPlay8Peer_SetSPCaps(p,a,b,c)                     (p)->SetSPCaps(a,b,c)
#define	IDirectPlay8Peer_GetSPCaps(p,a,b,c)                     (p)->GetSPCaps(a,b,c)
#define	IDirectPlay8Peer_GetConnectionInfo(p,a,b,c)             (p)->GetConnectionInfo(a,b,c)
#define	IDirectPlay8Peer_RegisterLobby(p,a,b,c)                 (p)->RegisterLobby(a,b,c)
#define	IDirectPlay8Peer_TerminateSession(p,a,b,c)              (p)->TerminateSession(a,b,c)
#endif

/*****************************************************************************
 * IDirectPlay8ThreadPool interface
 */
#define INTERFACE IDirectPlay8ThreadPool
DECLARE_INTERFACE_(IDirectPlay8ThreadPool,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8ThreadPool methods ***/
    STDMETHOD(Initialize)(THIS_ PVOID pvUserContext, PFNDPNMESSAGEHANDLER pfn, DWORD dwFlags) PURE;
    STDMETHOD(Close)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(GetThreadCount)(THIS_ DWORD dwProcessorNum, DWORD* pdwNumThreads, DWORD dwFlags) PURE;
    STDMETHOD(SetThreadCount)(THIS_ DWORD dwProcessorNum, DWORD dwNumThreads, DWORD dwFlags) PURE;
    STDMETHOD(DoWork)(THIS_ DWORD dwAllowedTimeSlice, DWORD dwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define	IDirectPlay8ThreadPool_QueryInterface(p,a,b)                  (p)->lpVtbl->QueryInterface(p,a,b)
#define	IDirectPlay8ThreadPool_AddRef(p)                              (p)->lpVtbl->AddRef(p)
#define	IDirectPlay8ThreadPool_Release(p)                             (p)->lpVtbl->Release(p)
/*** IDirectPlay8ThreadPool methods ***/
#define IDirectPlay8ThreadPool_Initialize(p,a,b,c)                    (p)->lpVtbl->Initialize(p,a,b,c)
#define IDirectPlay8ThreadPool_Close(p,a)                             (p)->lpVtbl->Close(p,a)
#define IDirectPlay8ThreadPool_GetThreadCount(p,a,b,c)                (p)->lpVtbl->GetThreadCount(p,a,b,c)
#define IDirectPlay8ThreadPool_SetThreadCount(p,a,b,c)                (p)->lpVtbl->SetThreadCount(p,a,b,c)
#define IDirectPlay8ThreadPool_DoWork(p,a,b)                          (p)->lpVtbl->DoWork(p,a,b)
#else
/*** IUnknown methods ***/
#define	IDirectPlay8ThreadPool_QueryInterface(p,a,b)                  (p)->QueryInterface(a,b)
#define	IDirectPlay8ThreadPool_AddRef(p)                              (p)->AddRef()
#define	IDirectPlay8ThreadPool_Release(p)                             (p)->Release()
/*** IDirectPlay8ThreadPool methods ***/
#define IDirectPlay8ThreadPool_Initialize(p,a,b,c)                    (p)->Initialize(a,b,c)
#define IDirectPlay8ThreadPool_Close(p,a)                             (p)->Close(a)
#define IDirectPlay8ThreadPool_GetThreadCount(p,a,b,c)                (p)->GetThreadCount(a,b,c)
#define IDirectPlay8ThreadPool_SetThreadCount(p,a,b,c)                (p)->SetThreadCount(a,b,c)
#define IDirectPlay8ThreadPool_DoWork(p,a,b)                          (p)->DoWork(a,b)
#endif

/*****************************************************************************
 * IDirectPlay8NATResolver interface
 */
#define INTERFACE IDirectPlay8NATResolver
DECLARE_INTERFACE_(IDirectPlay8NATResolver,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8NATResolver methods ***/
    STDMETHOD(Initialize)(THIS_ PVOID pvUserContext, PFNDPNMESSAGEHANDLER pfn, DWORD dwFlags) PURE;
    STDMETHOD(Start)(THIS_ IDirectPlay8Address** ppDevices, DWORD dwNumDevices, DWORD dwFlags) PURE;
    STDMETHOD(Close)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(EnumDevices)(THIS_ DPN_SERVICE_PROVIDER_INFO* pSPInfoBuffer, PDWORD pdwBufferSize, PDWORD pdwNumDevices, DWORD dwFlags) PURE;
    STDMETHOD(GetAddresses)(THIS_ IDirectPlay8Address** ppAddresses, DWORD* pdwNumAddresses, DWORD dwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define	IDirectPlay8NATResolver_QueryInterface(p,a,b)                  (p)->lpVtbl->QueryInterface(p,a,b)
#define	IDirectPlay8NATResolver_AddRef(p)                              (p)->lpVtbl->AddRef(p)
#define	IDirectPlay8NATResolver_Release(p)                             (p)->lpVtbl->Release(p)
/*** IDirectPlay8NATResolver methods ***/
#define IDirectPlay8NATResolver_Initialize(p,a,b,c)                    (p)->lpVtbl->Initialize(p,a,b,c)
#define IDirectPlay8NATResolver_Start(p,a,b,c)                         (p)->lpVtbl->Start(p,a,b,c)
#define IDirectPlay8NATResolver_Close(p,a)                             (p)->lpVtbl->Close(p,a)
#define IDirectPlay8NATResolver_EnumDevices(p,a,b,c,d)                 (p)->lpVtbl->EnumDevices(p,a,b,c,d)
#define IDirectPlay8NATResolver_GetAddresses(p,a,b,c)                  (p)->lpVtbl->GetAddresses(p,a,b,c)
#else
/*** IUnknown methods ***/
#define	IDirectPlay8NATResolver_QueryInterface(p,a,b)                  (p)->QueryInterface(a,b)
#define	IDirectPlay8NATResolver_AddRef(p)                              (p)->AddRef()
#define	IDirectPlay8NATResolver_Release(p)                             (p)->Release()
/*** IDirectPlay8NATResolver methods ***/
#define IDirectPlay8NATResolver_Initialize(p,a,b,c)                    (p)->Initialize(a,b,c)
#define IDirectPlay8NATResolver_Start(p,a,b,c)                         (p)->Start(a,b,c)
#define IDirectPlay8NATResolver_Close(p,a)                             (p)->Close(a)
#define IDirectPlay8NATResolver_EnumDevices(p,a,b,c,d)                 (p)->EnumDevices(a,b,c,d)
#define IDirectPlay8NATResolver_GetAddresses(p,a,b,c)                  (p)->GetAddresses(a,b,c)
#endif

/* Export functions */

HRESULT WINAPI DirectPlay8Create(const CLSID* pcIID, LPVOID* ppvInterface, IUnknown* pUnknown);

#ifdef __cplusplus
}
#endif

#endif
