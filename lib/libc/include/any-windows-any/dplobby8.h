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

#ifndef __WINE_DPLOBBY8_H
#define __WINE_DPLOBBY8_H

#include <ole2.h>

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */

/*****************************************************************************
 * DirectPlay8Lobby defines
 */
#define DPL_MSGID_LOBBY                   0x8000
#define DPL_MSGID_RECEIVE                 (0x0001 | DPL_MSGID_LOBBY)
#define DPL_MSGID_CONNECT                 (0x0002 | DPL_MSGID_LOBBY)
#define DPL_MSGID_DISCONNECT              (0x0003 | DPL_MSGID_LOBBY)
#define DPL_MSGID_SESSION_STATUS          (0x0004 | DPL_MSGID_LOBBY)
#define DPL_MSGID_CONNECTION_SETTINGS     (0x0005 | DPL_MSGID_LOBBY)
#define DPLHANDLE_ALLCONNECTIONS          0xFFFFFFFF
#define DPLSESSION_CONNECTED              0x0001
#define DPLSESSION_COULDNOTCONNECT        0x0002
#define DPLSESSION_DISCONNECTED           0x0003
#define DPLSESSION_TERMINATED             0x0004
#define DPLSESSION_HOSTMIGRATED           0x0005
#define DPLSESSION_HOSTMIGRATEDHERE       0x0006
#define DPLAVAILABLE_ALLOWMULTIPLECONNECT 0x0001
#define DPLCONNECT_LAUNCHNEW              0x0001
#define DPLCONNECT_LAUNCHNOTFOUND         0x0002
#define DPLCONNECTSETTINGS_HOST           0x0001
#define DPLINITIALIZE_DISABLEPARAMVAL     0x0001

/*****************************************************************************
 * DirectPlay8Lobby structures Typedefs
 */
typedef struct _DPL_APPLICATION_INFO {
  GUID    guidApplication;
  PWSTR   pwszApplicationName;
  DWORD   dwNumRunning;
  DWORD   dwNumWaiting;
  DWORD   dwFlags;
} DPL_APPLICATION_INFO, *PDPL_APPLICATION_INFO;

typedef struct _DPL_CONNECTION_SETTINGS {
  DWORD                 dwSize;
  DWORD                 dwFlags;
  DPN_APPLICATION_DESC  dpnAppDesc;
  IDirectPlay8Address*  pdp8HostAddress;
  IDirectPlay8Address** ppdp8DeviceAddresses;
  DWORD                 cNumDeviceAddresses;
  PWSTR                 pwszPlayerName;
} DPL_CONNECTION_SETTINGS, *PDPL_CONNECTION_SETTINGS;

typedef struct _DPL_CONNECT_INFO {
  DWORD	                   dwSize;
  DWORD	                   dwFlags;
  GUID                     guidApplication;
  PDPL_CONNECTION_SETTINGS pdplConnectionSettings;
  PVOID                    pvLobbyConnectData;
  DWORD                    dwLobbyConnectDataSize;
} DPL_CONNECT_INFO, *PDPL_CONNECT_INFO;

typedef struct  _DPL_PROGRAM_DESC {
  DWORD   dwSize;
  DWORD   dwFlags;
  GUID    guidApplication;
  PWSTR   pwszApplicationName;
  PWSTR   pwszCommandLine;
  PWSTR   pwszCurrentDirectory;
  PWSTR   pwszDescription;
  PWSTR   pwszExecutableFilename;
  PWSTR   pwszExecutablePath;
  PWSTR   pwszLauncherFilename;
  PWSTR   pwszLauncherPath;
} DPL_PROGRAM_DESC, *PDPL_PROGRAM_DESC;

typedef struct _DPL_MESSAGE_CONNECT {
  DWORD                    dwSize;
  DPNHANDLE                hConnectId;
  PDPL_CONNECTION_SETTINGS pdplConnectionSettings;
  PVOID	                   pvLobbyConnectData;
  DWORD	                   dwLobbyConnectDataSize;
  PVOID	                   pvConnectionContext;
} DPL_MESSAGE_CONNECT, *PDPL_MESSAGE_CONNECT;

typedef struct _DPL_MESSAGE_CONNECTION_SETTINGS {
  DWORD                     dwSize;
  DPNHANDLE                 hSender;
  PDPL_CONNECTION_SETTINGS  pdplConnectionSettings;
  PVOID	                    pvConnectionContext;
} DPL_MESSAGE_CONNECTION_SETTINGS, *PDPL_MESSAGE_CONNECTION_SETTINGS;

typedef struct _DPL_MESSAGE_DISCONNECT {
  DWORD	    dwSize;
  DPNHANDLE hDisconnectId;
  HRESULT   hrReason;
  PVOID	    pvConnectionContext;
} DPL_MESSAGE_DISCONNECT, *PDPL_MESSAGE_DISCONNECT;

typedef struct _DPL_MESSAGE_RECEIVE {
  DWORD	    dwSize;
  DPNHANDLE hSender;
  BYTE*     pBuffer;
  DWORD	    dwBufferSize;
  PVOID	    pvConnectionContext;
} DPL_MESSAGE_RECEIVE, *PDPL_MESSAGE_RECEIVE;

typedef struct _DPL_MESSAGE_SESSION_STATUS {
  DWORD     dwSize;
  DPNHANDLE hSender;
  DWORD     dwStatus;
  PVOID	    pvConnectionContext;
} DPL_MESSAGE_SESSION_STATUS, *PDPL_MESSAGE_SESSION_STATUS;

/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(CLSID_DirectPlay8LobbiedApplication,  0x667955ad,0x6b3b,0x43ca,0xb9,0x49,0xbc,0x69,0xb5,0xba,0xff,0x7f);
DEFINE_GUID(CLSID_DirectPlay8LobbyClient,         0x3b2b6775,0x70b6,0x45af,0x8d,0xea,0xa2,0x09,0xc6,0x95,0x59,0xf3);

DEFINE_GUID(IID_IDirectPlay8LobbiedApplication,   0x819074a3,0x16c,0x11d3,0xae,0x14,0x00,0x60,0x97,0xb0,0x14,0x11);
typedef struct IDirectPlay8LobbiedApplication *PDIRECTPLAY8LOBBIEDAPPLICATION;
DEFINE_GUID(IID_IDirectPlay8LobbyClient,          0x819074a2,0x16c,0x11d3,0xae,0x14,0x00,0x60,0x97,0xb0,0x14,0x11);
typedef struct IDirectPlay8LobbyClient *PDIRECTPLAY8LOBBYCLIENT;

/*****************************************************************************
 * IDirectPlay8LobbiedApplication interface
 */
#define INTERFACE IDirectPlay8LobbiedApplication
DECLARE_INTERFACE_(IDirectPlay8LobbiedApplication,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8LobbiedApplication methods ***/
    STDMETHOD(Initialize)(THIS_ PVOID pvUserContext, PFNDPNMESSAGEHANDLER pfn, DPNHANDLE* pdpnhConnection, DWORD dwFlags) PURE;
    STDMETHOD(RegisterProgram)(THIS_ PDPL_PROGRAM_DESC pdplProgramDesc, DWORD dwFlags) PURE;
    STDMETHOD(UnRegisterProgram)(THIS_ GUID* pguidApplication, DWORD dwFlags) PURE;
    STDMETHOD(Send)(THIS_ DPNHANDLE hConnection, BYTE* pBuffer, DWORD pBufferSize, DWORD dwFlags) PURE;
    STDMETHOD(SetAppAvailable)(THIS_ WINBOOL fAvailable, DWORD dwFlags) PURE;
    STDMETHOD(UpdateStatus)(THIS_ DPNHANDLE hConnection, DWORD dwStatus, DWORD dwFlags) PURE;
    STDMETHOD(Close)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(GetConnectionSettings)(THIS_ DPNHANDLE hConnection, DPL_CONNECTION_SETTINGS* pdplSessionInfo, DWORD* pdwInfoSize, DWORD dwFlags) PURE;
    STDMETHOD(SetConnectionSettings)(THIS_ DPNHANDLE hConnection, const DPL_CONNECTION_SETTINGS* pdplSessionInfo, DWORD dwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlay8LobbiedApplication_QueryInterface(p,a,b)                (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlay8LobbiedApplication_AddRef(p)                            (p)->lpVtbl->AddRef(p)
#define IDirectPlay8LobbiedApplication_Release(p)                           (p)->lpVtbl->Release(p)
/*** IDirectPlay8LobbiedApplication methods ***/
#define IDirectPlay8LobbiedApplication_Initialize(p,a,b,c,d)                (p)->lpVtbl->Initialize(p,a,b,c,d)
#define IDirectPlay8LobbiedApplication_RegisterProgram(p,a,b)               (p)->lpVtbl->RegisterProgram(p,a,b)
#define IDirectPlay8LobbiedApplication_UnRegisterProgram(p,a,b)             (p)->lpVtbl->UnRegisterProgram(p,a,b)
#define IDirectPlay8LobbiedApplication_Send(p,a,b,c,d)                      (p)->lpVtbl->Send(p,a,b,c,d)
#define IDirectPlay8LobbiedApplication_SetAppAvailable(p,a,b)               (p)->lpVtbl->SetAppAvailable(p,a,b)
#define IDirectPlay8LobbiedApplication_UpdateStatus(p,a,b,c)                (p)->lpVtbl->UpdateStatus(p,a,b,c)
#define IDirectPlay8LobbiedApplication_Close(p,a)                           (p)->lpVtbl->Close(p,a)
#define IDirectPlay8LobbiedApplication_GetConnectionSettings(p,a,b,c,d)     (p)->lpVtbl->GetConnectionSettings(p,a,b,c,d)
#define IDirectPlay8LobbiedApplication_SetConnectionSettings(p,a,b,c)       (p)->lpVtbl->SetConnectionSettings(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirectPlay8LobbiedApplication_QueryInterface(p,a,b)                (p)->QueryInterface(a,b)
#define IDirectPlay8LobbiedApplication_AddRef(p)                            (p)->AddRef()
#define IDirectPlay8LobbiedApplication_Release(p)                           (p)->Release()
/*** IDirectPlay8LobbiedApplication methods ***/
#define IDirectPlay8LobbiedApplication_Initialize(p,a,b,c,d)                (p)->Initialize(a,b,c,d)
#define IDirectPlay8LobbiedApplication_RegisterProgram(p,a,b)               (p)->RegisterProgram(a,b)
#define IDirectPlay8LobbiedApplication_UnRegisterProgram(p,a,b)             (p)->UnRegisterProgram(a,b)
#define IDirectPlay8LobbiedApplication_Send(p,a,b,c,d)                      (p)->Send(a,b,c,d)
#define IDirectPlay8LobbiedApplication_SetAppAvailable(p,a,b)               (p)->SetAppAvailable(a,b)
#define IDirectPlay8LobbiedApplication_UpdateStatus(p,a,b,c)                (p)->UpdateStatus(a,b,c)
#define IDirectPlay8LobbiedApplication_Close(p,a)                           (p)->Close(a)
#define IDirectPlay8LobbiedApplication_GetConnectionSettings(p,a,b,c,d)     (p)->GetConnectionSettings(a,b,c,d)
#define IDirectPlay8LobbiedApplication_SetConnectionSettings(p,a,b,c)       (p)->SetConnectionSettings(a,b,c)
#endif

/*****************************************************************************
 * IDirectPlay8LobbyClient interface
 */
#define INTERFACE IDirectPlay8LobbyClient
DECLARE_INTERFACE_(IDirectPlay8LobbyClient,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8LobbyClient methods ***/
    STDMETHOD(Initialize)(THIS_ PVOID pvUserContext, PFNDPNMESSAGEHANDLER pfn, DWORD dwFlags) PURE;
    STDMETHOD(EnumLocalPrograms)(THIS_ GUID* pGuidApplication, BYTE* pEnumData, DWORD* pdwEnumData, DWORD* pdwItems, DWORD dwFlags) PURE;
    STDMETHOD(ConnectApplication)(THIS_ DPL_CONNECT_INFO* pdplConnectionInfo, PVOID pvConnectionContext, DPNHANDLE* hApplication, DWORD dwTimeOut, DWORD dwFlags) PURE;
    STDMETHOD(Send)(THIS_ DPNHANDLE hConnection, BYTE* pBuffer, DWORD pBufferSize, DWORD dwFlags) PURE;
    STDMETHOD(ReleaseApplication)(THIS_ DPNHANDLE hConnection, DWORD dwFlags) PURE;
    STDMETHOD(Close)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(GetConnectionSettings)(THIS_ DPNHANDLE hConnection, DPL_CONNECTION_SETTINGS* pdplSessionInfo, DWORD* pdwInfoSize, DWORD dwFlags) PURE;
    STDMETHOD(SetConnectionSettings)(THIS_ DPNHANDLE hConnection, const DPL_CONNECTION_SETTINGS* pdplSessionInfo, DWORD dwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlay8LobbyClient_QueryInterface(p,a,b)                (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlay8LobbyClient_AddRef(p)                            (p)->lpVtbl->AddRef(p)
#define IDirectPlay8LobbyClient_Release(p)                           (p)->lpVtbl->Release(p)
/*** IDirectPlay8LobbyClient methods ***/
#define IDirectPlay8LobbyClient_Initialize(p,a,b,c)                  (p)->lpVtbl->Initialize(p,a,b,c)
#define IDirectPlay8LobbyClient_EnumLocalPrograms(p,a,b,c,d,e)       (p)->lpVtbl->EnumLocalPrograms(p,a,b,c,d,e)
#define IDirectPlay8LobbyClient_ConnectApplication(p,a,b,c,d,e)      (p)->lpVtbl->ConnectApplication(p,a,b,c,d,e)
#define IDirectPlay8LobbyClient_Send(p,a,b,c,d)                      (p)->lpVtbl->Send(p,a,b,c,d)
#define IDirectPlay8LobbyClient_ReleaseApplication(p,a,b)            (p)->lpVtbl->ReleaseApplication(p,a,b)
#define IDirectPlay8LobbyClient_Close(p,a)                           (p)->lpVtbl->Close(p,a)
#define IDirectPlay8LobbyClient_GetConnectionSettings(p,a,b,c,d)     (p)->lpVtbl->GetConnectionSettings(p,a,b,c,d)
#define IDirectPlay8LobbyClient_SetConnectionSettings(p,a,b,c)       (p)->lpVtbl->SetConnectionSettings(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirectPlay8LobbyClient_QueryInterface(p,a,b)                (p)->QueryInterface(a,b)
#define IDirectPlay8LobbyClient_AddRef(p)                            (p)->AddRef()
#define IDirectPlay8LobbyClient_Release(p)                           (p)->Release()
/*** IDirectPlay8LobbyClient methods ***/
#define IDirectPlay8LobbyClient_Initialize(p,a,b,c)                  (p)->Initialize(a,b,c)
#define IDirectPlay8LobbyClient_EnumLocalPrograms(p,a,b,c,d,e)       (p)->EnumLocalPrograms(a,b,c,d,e)
#define IDirectPlay8LobbyClient_ConnectApplication(p,a,b,c,d,e)      (p)->ConnectApplication(a,b,c,d,e)
#define IDirectPlay8LobbyClient_Send(p,a,b,c,d)                      (p)->Send(a,b,c,d)
#define IDirectPlay8LobbyClient_ReleaseApplication(p,a,b)            (p)->ReleaseApplication(a,b)
#define IDirectPlay8LobbyClient_Close(p,a)                           (p)->Close(a)
#define IDirectPlay8LobbyClient_GetConnectionSettings(p,a,b,c,d)     (p)->GetConnectionSettings(a,b,c,d)
#define IDirectPlay8LobbyClient_SetConnectionSettings(p,a,b,c)       (p)->SetConnectionSettings(a,b,c)
#endif


/* Export functions */

HRESULT WINAPI DirectPlay8LobbyCreate(const GUID* pcIID, LPVOID* ppvInterface, IUnknown* pUnknown);

#ifdef __cplusplus
}
#endif

#endif 
