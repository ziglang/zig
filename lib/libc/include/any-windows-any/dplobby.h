#include <_mingw_unicode.h>
#undef INTERFACE
/*
 * Copyright (C) 1999 Francois Gouget
 * Copyright (C) 1999 Peter Hunnisett
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

#ifndef __WINE_DPLOBBY_H
#define __WINE_DPLOBBY_H

#include <dplay.h>

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */

/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(CLSID_DirectPlayLobby, 0x2fe8f810, 0xb2a5, 0x11d0, 0xa7, 0x87, 0x0, 0x0, 0xf8, 0x3, 0xab, 0xfc);

DEFINE_GUID(IID_IDirectPlayLobby, 0xaf465c71, 0x9588, 0x11cf, 0xa0, 0x20, 0x0, 0xaa, 0x0, 0x61, 0x57, 0xac);
typedef struct IDirectPlayLobby *LPDIRECTPLAYLOBBY;

DEFINE_GUID(IID_IDirectPlayLobbyA, 0x26c66a70, 0xb367, 0x11cf, 0xa0, 0x24, 0x0, 0xaa, 0x0, 0x61, 0x57, 0xac);
typedef struct IDirectPlayLobby IDirectPlayLobbyA,*LPDIRECTPLAYLOBBYA;

DEFINE_GUID(IID_IDirectPlayLobby2, 0x194c220, 0xa303, 0x11d0, 0x9c, 0x4f, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);
typedef struct IDirectPlayLobby2 *LPDIRECTPLAYLOBBY2;

DEFINE_GUID(IID_IDirectPlayLobby2A, 0x1bb4af80, 0xa303, 0x11d0, 0x9c, 0x4f, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);
typedef struct IDirectPlayLobby2 IDirectPlayLobby2A, *LPDIRECTPLAYLOBBY2A;

DEFINE_GUID(IID_IDirectPlayLobby3, 0x2db72490, 0x652c, 0x11d1, 0xa7, 0xa8, 0x0, 0x0, 0xf8, 0x3, 0xab, 0xfc);
typedef struct IDirectPlayLobby3 *LPDIRECTPLAYLOBBY3;

DEFINE_GUID(IID_IDirectPlayLobby3A, 0x2db72491, 0x652c, 0x11d1, 0xa7, 0xa8, 0x0, 0x0, 0xf8, 0x3, 0xab, 0xfc);
typedef struct IDirectPlayLobby3 IDirectPlayLobby3A, *LPDIRECTPLAYLOBBY3A;


/*****************************************************************************
 * DirectPlayLobby Property GUIDs used in lobby messages
 */

/* DPLPROPERTY_MessagesSupported {762CCDA1-D916-11d0-BA39-00C04FD7ED67}.
 * Purpose: Request if the lobby supports standard (?).
 * Response: Answer is a WINBOOL. TRUE if supports the standard (?) and FALSE otherwise. Of course, it might not respond at all.
 */
DEFINE_GUID(DPLPROPERTY_MessagesSupported, 0x762ccda1, 0xd916, 0x11d0, 0xba, 0x39, 0x0, 0xc0, 0x4f, 0xd7, 0xed, 0x67);

/* DPLPROPERTY_LobbyGuid {F56920A0-D218-11d0-BA39-00C04FD7ED67}.
 * Purpose: Request the GUID that identifies the lobby version that the application is communicating with.
 * Response: The GUID which identifies the lobby version
 */
DEFINE_GUID(DPLPROPERTY_LobbyGuid, 0xf56920a0, 0xd218, 0x11d0, 0xba, 0x39, 0x0, 0xc0, 0x4f, 0xd7, 0xed, 0x67);

/* DPLPROPERTY_PlayerGuid {B4319322-D20D-11d0-BA39-00C04FD7ED67}
 * Purpose: Request the GUID that identifies the player for this particular machine.
 * Response: DPLDATA_PLAYERDATA structure.
 */
DEFINE_GUID(DPLPROPERTY_PlayerGuid, 0xb4319322, 0xd20d, 0x11d0, 0xba, 0x39, 0x0, 0xc0, 0x4f, 0xd7, 0xed, 0x67);

/* DPLPROPERTY_PlayerScore {48784000-D219-11d0-BA39-00C04FD7ED67}
 * Purpose: Used to send a score of a player to the lobby. The format is an array of long integers.
 * Response: I don't think there is one.
 */
DEFINE_GUID(DPLPROPERTY_PlayerScore, 0x48784000, 0xd219, 0x11d0, 0xba, 0x39, 0x0, 0xc0, 0x4f, 0xd7, 0xed, 0x67);



/*****************************************************************************
 * LOBBY structures associated with GUID messages
 */

typedef struct tagDPLDATA_PLAYERGUID
{
        GUID    guidPlayer;
        DWORD   dwPlayerFlags;
} DPLDATA_PLAYERGUID, *LPDPLDATA_PLAYERGUID;

typedef struct tagDPLDATA_PLAYERSCORE
{
        DWORD   dwScoreCount;
        LONG    Score[1];
} DPLDATA_PLAYERSCORE, *LPDPLDATA_PLAYERSCORE;


/*****************************************************************************
 * LOBBY messages and message data structures.
 *
 * System messages can be identified by dwMessageFlags having a value of DPLMSG_SYSTEM
 * after a call to ReceiveLobbyMessage.
 *
 * Standard messages can be identified by dwMessageFlags having a value of DPLMSG_STANDARD
 * after a call to ReceiveLobbyMessage.
 */

/* DPLobby1 definition required for backwards compatibility */
#define DPLMSG_SYSTEM                                   0x00000001
#define DPLMSG_STANDARD                                 0x00000002
#define DPLAD_SYSTEM          DPLMSG_SYSTEM


/* System messages  - dwType field for messages */
#define DPLSYS_CONNECTIONSETTINGSREAD   0x00000001
#define DPLSYS_DPLAYCONNECTFAILED       0x00000002
#define DPLSYS_DPLAYCONNECTSUCCEEDED    0x00000003
#define DPLSYS_APPTERMINATED            0x00000004
#define DPLSYS_SETPROPERTY              0x00000005
#define DPLSYS_SETPROPERTYRESPONSE      0x00000006
#define DPLSYS_GETPROPERTY              0x00000007
#define DPLSYS_GETPROPERTYRESPONSE      0x00000008
#define DPLSYS_NEWSESSIONHOST           0x00000009
#define DPLSYS_NEWCONNECTIONSETTINGS    0x0000000A



/* Used to identify the message type */
typedef struct tagDPLMSG_GENERIC
{
    DWORD       dwType;         /* Message type */
} DPLMSG_GENERIC, *LPDPLMSG_GENERIC;

/* Generic format for system messages - see above */
typedef struct tagDPLMSG_SYSTEMMESSAGE
{
    DWORD       dwType;         /* Message type */
    GUID        guidInstance;   /* Instance GUID of the dplay session the message corresponds to */
} DPLMSG_SYSTEMMESSAGE, *LPDPLMSG_SYSTEMMESSAGE;

/* Generic message to set a property - see property GUIDs above */
typedef struct tagDPLMSG_SETPROPERTY
{
        DWORD   dwType;              /* Message type */
        DWORD   dwRequestID;         /* Request ID (DPL_NOCONFIRMATION if no confirmation desired) */
        GUID    guidPlayer;          /* Player GUID */
        GUID    guidPropertyTag;     /* Property GUID */
        DWORD   dwDataSize;          /* Size of data */
        DWORD   dwPropertyData[1];   /* Buffer containing data */
} DPLMSG_SETPROPERTY, *LPDPLMSG_SETPROPERTY;

#define DPL_NOCONFIRMATION      0

/* Reply to DPLMSG_SETPROPERTY */
typedef struct tagDPLMSG_SETPROPERTYRESPONSE
{
        DWORD   dwType;              /* Message type */
        DWORD   dwRequestID;         /* Request ID */
        GUID    guidPlayer;          /* Player GUID */
        GUID    guidPropertyTag;     /* Property GUID */
        HRESULT hr;                  /* Return Code */
} DPLMSG_SETPROPERTYRESPONSE, *LPDPLMSG_SETPROPERTYRESPONSE;

/* Request to get the present value of a property */
typedef struct tagDPLMSG_GETPROPERTY
{
        DWORD   dwType;           /* Message type */
        DWORD   dwRequestID;      /* Request ID */
        GUID    guidPlayer;       /* Player GUID */
        GUID    guidPropertyTag;  /* Property GUID */
} DPLMSG_GETPROPERTY, *LPDPLMSG_GETPROPERTY;

/* Response to a request to get the present value of a property */
typedef struct tagDPLMSG_GETPROPERTYRESPONSE
{
        DWORD   dwType;              /* Message type */
        DWORD   dwRequestID;         /* Request ID */
        GUID    guidPlayer;          /* Player GUID */
        GUID    guidPropertyTag;     /* Property GUID */
        HRESULT hr;                  /* Return Code */
        DWORD   dwDataSize;          /* Size of data */
        DWORD   dwPropertyData[1];   /* Buffer containing data */
} DPLMSG_GETPROPERTYRESPONSE, *LPDPLMSG_GETPROPERTYRESPONSE;

/* Standard message in response to a session host migration to a new client */
typedef struct tagDPLMSG_NEWSESSIONHOST
{
    DWORD   dwType;        /* Message type */
    GUID    guidInstance;  /* GUID Instance of the session */
} DPLMSG_NEWSESSIONHOST, *LPDPLMSG_NEWSESSIONHOST;

/*****************************************************************************
 * DirectPlay Address ID's
 * A DirectPlay address is composed of multiple data chunks, each associated with
 * a GUID to give significance to the type of data. All chunks have an associated
 * size so that unknown chunks can be ignored for backwards compatibility!
 * EnumAddresses function is used to parse the address data chunks.
 */

/* DPAID_TotalSize {1318F560-912C-11d0-9DAA-00A0C90A43CB}
 * Chunk purpose: Chunk is a DWORD containing the size of the entire DPADDRESS struct
 */
DEFINE_GUID(DPAID_TotalSize, 0x1318f560, 0x912c, 0x11d0, 0x9d, 0xaa, 0x0, 0xa0, 0xc9, 0xa, 0x43, 0xcb);

/* DPAID_ServiceProvider {07D916C0-E0AF-11cf-9C4E-00A0C905425E}
 * Chunk purpose: Chunk is a GUID indicated what service provider created the chunk.
 */
DEFINE_GUID(DPAID_ServiceProvider, 0x7d916c0, 0xe0af, 0x11cf, 0x9c, 0x4e, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);

/* DPAID_LobbyProvider {59B95640-9667-11d0-A77D-0000F803ABFC}
 * Chunk purpose: Chunk is a GUID indicating what lobby provider created the chunk.
 */
DEFINE_GUID(DPAID_LobbyProvider, 0x59b95640, 0x9667, 0x11d0, 0xa7, 0x7d, 0x0, 0x0, 0xf8, 0x3, 0xab, 0xfc);

/* DPAID_Phone  {78EC89A0-E0AF-11cf-9C4E-00A0C905425E} -- ANSI
 * DPAID_PhoneW {BA5A7A70-9DBF-11d0-9CC1-00A0C905425E} -- UNICODE
 * Chunk purpose: Chunk is a phone number in ANSI or UNICODE format
 */
DEFINE_GUID(DPAID_Phone, 0x78ec89a0, 0xe0af, 0x11cf, 0x9c, 0x4e, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);
DEFINE_GUID(DPAID_PhoneW, 0xba5a7a70, 0x9dbf, 0x11d0, 0x9c, 0xc1, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);

/* DPAID_Modem  {F6DCC200-A2FE-11d0-9C4F-00A0C905425E} -- ANSI
 * DPAID_ModemW {01FD92E0-A2FF-11d0-9C4F-00A0C905425E} -- UNICODE
 * Chunk purpose: Chunk is a modem name registered with TAPI
 */
DEFINE_GUID(DPAID_Modem, 0xf6dcc200, 0xa2fe, 0x11d0, 0x9c, 0x4f, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);
DEFINE_GUID(DPAID_ModemW, 0x1fd92e0, 0xa2ff, 0x11d0, 0x9c, 0x4f, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);

/* DPAID_INet  {C4A54DA0-E0AF-11cf-9C4E-00A0C905425E} -- ANSI
 * DPAID_INetW {E63232A0-9DBF-11d0-9CC1-00A0C905425E} -- UNICODE
 * Chunk purpose: Chunk is a string containing a TCP/IP host name or IP address
 */
DEFINE_GUID(DPAID_INet, 0xc4a54da0, 0xe0af, 0x11cf, 0x9c, 0x4e, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);
DEFINE_GUID(DPAID_INetW, 0xe63232a0, 0x9dbf, 0x11d0, 0x9c, 0xc1, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);

/* DPAID_INetPort {E4524541-8EA5-11d1-8A96-006097B01411}
 * Chunk purpose: Chunk is a port number used for creating TCP and UDP sockets. (WORD)
 */
DEFINE_GUID(DPAID_INetPort, 0xe4524541, 0x8ea5, 0x11d1, 0x8a, 0x96, 0x0, 0x60, 0x97, 0xb0, 0x14, 0x11);

/* DPAID_ComPort {F2F0CE00-E0AF-11cf-9C4E-00A0C905425E}
 * Chunk purpose: Chunk contains the description of a serial port.
 */
DEFINE_GUID(DPAID_ComPort, 0xf2f0ce00, 0xe0af, 0x11cf, 0x9c, 0x4e, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);


/* Header block for address data elements */
typedef struct tagDPADDRESS
{
    GUID                guidDataType;
    DWORD               dwDataSize;
} DPADDRESS, *LPDPADDRESS;


/* Used for specification of a communication port. Baud rate, stop bits and
 * parity bits can be found in winbase.h. These are flow control constants only.
 */
#define DPCPA_NOFLOW        0           /* no flow control */
#define DPCPA_XONXOFFFLOW   1           /* software flow control */
#define DPCPA_RTSFLOW       2           /* hardware flow control with RTS */
#define DPCPA_DTRFLOW       3           /* hardware flow control with DTR */
#define DPCPA_RTSDTRFLOW    4           /* hardware flow control with RTS and DTR */

typedef struct tagDPCOMPORTADDRESS
{
    DWORD   dwComPort;                  /* COM port to use (1-4) */
    DWORD   dwBaudRate;                 /* baud rate (100-256k) */
    DWORD   dwStopBits;                 /* no. stop bits (1-2) */
    DWORD   dwParity;                   /* parity (none, odd, even, mark) */
    DWORD   dwFlowControl;              /* flow control (none, xon/xoff, rts, dtr) */
} DPCOMPORTADDRESS, *LPDPCOMPORTADDRESS;



/****************************************************************************
 * Miscellaneous
 */

typedef struct tagDPLAPPINFO
{
    DWORD       dwSize;
    GUID        guidApplication;

    union
    {
        LPSTR   lpszAppNameA;
        LPWSTR  lpszAppName;
    } DUMMYUNIONNAME;

} DPLAPPINFO, *LPDPLAPPINFO;
typedef const DPLAPPINFO *LPCDPLAPPINFO;

typedef struct DPCOMPOUNDADDRESSELEMENT
{
    GUID    guidDataType;
    DWORD   dwDataSize;
    LPVOID  lpData;
} DPCOMPOUNDADDRESSELEMENT, *LPDPCOMPOUNDADDRESSELEMENT;
typedef const DPCOMPOUNDADDRESSELEMENT *LPCDPCOMPOUNDADDRESSELEMENT;

typedef struct tagDPAPPLICATIONDESC
{
    DWORD       dwSize;
    DWORD       dwFlags;

    union
    {
        LPSTR       lpszApplicationNameA;
        LPWSTR      lpszApplicationName;
    } DUMMYUNIONNAME1;

    GUID        guidApplication;

    union
    {
        LPSTR       lpszFilenameA;
        LPWSTR      lpszFilename;
    } DUMMYUNIONNAME2;

    union
    {
        LPSTR       lpszCommandLineA;
        LPWSTR      lpszCommandLine;
    } DUMMYUNIONNAME3;

    union
    {
        LPSTR       lpszPathA;
        LPWSTR      lpszPath;
    } DUMMYUNIONNAME4;

    union
    {
        LPSTR       lpszCurrentDirectoryA;
        LPWSTR      lpszCurrentDirectory;
    } DUMMYUNIONNAME5;

    LPSTR       lpszDescriptionA;
    LPWSTR      lpszDescriptionW;

} DPAPPLICATIONDESC, *LPDPAPPLICATIONDESC;



extern HRESULT WINAPI DirectPlayLobbyCreateW(LPGUID, LPDIRECTPLAYLOBBY*,  IUnknown*, LPVOID, DWORD );
extern HRESULT WINAPI DirectPlayLobbyCreateA(LPGUID, LPDIRECTPLAYLOBBYA*, IUnknown*, LPVOID, DWORD );
#define DirectPlayLobbyCreate __MINGW_NAME_AW(DirectPlayLobbyCreate)


typedef WINBOOL (CALLBACK *LPDPENUMADDRESSCALLBACK)(
    REFGUID         guidDataType,
    DWORD           dwDataSize,
    LPCVOID         lpData,
    LPVOID          lpContext );

typedef WINBOOL (CALLBACK *LPDPLENUMADDRESSTYPESCALLBACK)(
    REFGUID         guidDataType,
    LPVOID          lpContext,
    DWORD           dwFlags );

typedef WINBOOL (CALLBACK *LPDPLENUMLOCALAPPLICATIONSCALLBACK)(
    LPCDPLAPPINFO   lpAppInfo,
    LPVOID          lpContext,
    DWORD           dwFlags );

/*****************************************************************************
 * IDirectPlayLobby and IDirectPlayLobbyA interface
 */
#define INTERFACE IDirectPlayLobby
DECLARE_INTERFACE_(IDirectPlayLobby,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlayLobby methods ***/
    STDMETHOD(Connect)(THIS_ DWORD, LPDIRECTPLAY2*, IUnknown*) PURE;
    STDMETHOD(CreateAddress)(THIS_ REFGUID, REFGUID, LPCVOID, DWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(EnumAddress)(THIS_ LPDPENUMADDRESSCALLBACK, LPCVOID, DWORD, LPVOID) PURE;
    STDMETHOD(EnumAddressTypes)(THIS_ LPDPLENUMADDRESSTYPESCALLBACK, REFGUID, LPVOID, DWORD) PURE;
    STDMETHOD(EnumLocalApplications)(THIS_ LPDPLENUMLOCALAPPLICATIONSCALLBACK, LPVOID, DWORD) PURE;
    STDMETHOD(GetConnectionSettings)(THIS_ DWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(ReceiveLobbyMessage)(THIS_ DWORD, DWORD, LPDWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(RunApplication)(THIS_ DWORD, LPDWORD, LPDPLCONNECTION, HANDLE) PURE;
    STDMETHOD(SendLobbyMessage)(THIS_ DWORD, DWORD, LPVOID, DWORD) PURE;
    STDMETHOD(SetConnectionSettings)(THIS_ DWORD, DWORD, LPDPLCONNECTION) PURE;
    STDMETHOD(SetLobbyMessageEvent)(THIS_ DWORD, DWORD, HANDLE) PURE;
};
#undef INTERFACE

/*****************************************************************************
 * IDirectPlayLobby2 and IDirectPlayLobby2A interface
 */
#define INTERFACE IDirectPlayLobby2
DECLARE_INTERFACE_(IDirectPlayLobby2,IDirectPlayLobby)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlayLobby methods ***/
    STDMETHOD(Connect)(THIS_ DWORD, LPDIRECTPLAY2*, IUnknown*) PURE;
    STDMETHOD(CreateAddress)(THIS_ REFGUID, REFGUID, LPCVOID, DWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(EnumAddress)(THIS_ LPDPENUMADDRESSCALLBACK, LPCVOID, DWORD, LPVOID) PURE;
    STDMETHOD(EnumAddressTypes)(THIS_ LPDPLENUMADDRESSTYPESCALLBACK, REFGUID, LPVOID, DWORD) PURE;
    STDMETHOD(EnumLocalApplications)(THIS_ LPDPLENUMLOCALAPPLICATIONSCALLBACK, LPVOID, DWORD) PURE;
    STDMETHOD(GetConnectionSettings)(THIS_ DWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(ReceiveLobbyMessage)(THIS_ DWORD, DWORD, LPDWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(RunApplication)(THIS_ DWORD, LPDWORD, LPDPLCONNECTION, HANDLE) PURE;
    STDMETHOD(SendLobbyMessage)(THIS_ DWORD, DWORD, LPVOID, DWORD) PURE;
    STDMETHOD(SetConnectionSettings)(THIS_ DWORD, DWORD, LPDPLCONNECTION) PURE;
    STDMETHOD(SetLobbyMessageEvent)(THIS_ DWORD, DWORD, HANDLE) PURE;
    /*** IDirectPlayLobby2 methods ***/
    STDMETHOD(CreateCompoundAddress)(THIS_ LPCDPCOMPOUNDADDRESSELEMENT, DWORD, LPVOID, LPDWORD) PURE;
};
#undef INTERFACE

/*****************************************************************************
 * IDirectPlayLobby3 and IDirectPlayLobby3A interface
 */
#define INTERFACE IDirectPlayLobby3
DECLARE_INTERFACE_(IDirectPlayLobby3,IDirectPlayLobby2)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlayLobby methods ***/
    STDMETHOD(Connect)(THIS_ DWORD, LPDIRECTPLAY2*, IUnknown*) PURE;
    STDMETHOD(CreateAddress)(THIS_ REFGUID, REFGUID, LPCVOID, DWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(EnumAddress)(THIS_ LPDPENUMADDRESSCALLBACK, LPCVOID, DWORD, LPVOID) PURE;
    STDMETHOD(EnumAddressTypes)(THIS_ LPDPLENUMADDRESSTYPESCALLBACK, REFGUID, LPVOID, DWORD) PURE;
    STDMETHOD(EnumLocalApplications)(THIS_ LPDPLENUMLOCALAPPLICATIONSCALLBACK, LPVOID, DWORD) PURE;
    STDMETHOD(GetConnectionSettings)(THIS_ DWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(ReceiveLobbyMessage)(THIS_ DWORD, DWORD, LPDWORD, LPVOID, LPDWORD) PURE;
    STDMETHOD(RunApplication)(THIS_ DWORD, LPDWORD, LPDPLCONNECTION, HANDLE) PURE;
    STDMETHOD(SendLobbyMessage)(THIS_ DWORD, DWORD, LPVOID, DWORD) PURE;
    STDMETHOD(SetConnectionSettings)(THIS_ DWORD, DWORD, LPDPLCONNECTION) PURE;
    STDMETHOD(SetLobbyMessageEvent)(THIS_ DWORD, DWORD, HANDLE) PURE;
    /*** IDirectPlayLobby2 methods ***/
    STDMETHOD(CreateCompoundAddress)(THIS_ LPCDPCOMPOUNDADDRESSELEMENT, DWORD, LPVOID, LPDWORD) PURE;
    /*** IDirectPlayLobby3 methods ***/
    STDMETHOD(ConnectEx)(THIS_ DWORD, REFIID, LPVOID *, IUnknown *) PURE;
    STDMETHOD(RegisterApplication)(THIS_ DWORD, LPDPAPPLICATIONDESC) PURE;
    STDMETHOD(UnregisterApplication)(THIS_ DWORD, REFGUID) PURE;
    STDMETHOD(WaitForConnectionSettings)(THIS_ DWORD) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlayLobby_QueryInterface(p,a,b)              (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlayLobby_AddRef(p)                          (p)->lpVtbl->AddRef(p)
#define IDirectPlayLobby_Release(p)                         (p)->lpVtbl->Release(p)
/*** IDirectPlayLobby methods ***/
#define IDirectPlayLobby_Connect(p,a,b,c)                   (p)->lpVtbl->Connect(p,a,b,c)
#define IDirectPlayLobby_CreateAddress(p,a,b,c,d,e,f)       (p)->lpVtbl->CreateAddress(p,a,b,c,d,e,f)
#define IDirectPlayLobby_EnumAddress(p,a,b,c,d)             (p)->lpVtbl->EnumAddress(p,a,b,c,d)
#define IDirectPlayLobby_EnumAddressTypes(p,a,b,c,d)        (p)->lpVtbl->EnumAddressTypes(p,a,b,c,d)
#define IDirectPlayLobby_EnumLocalApplications(p,a,b,c)     (p)->lpVtbl->EnumLocalApplications(p,a,b,c)
#define IDirectPlayLobby_GetConnectionSettings(p,a,b,c)     (p)->lpVtbl->GetConnectionSettings(p,a,b,c)
#define IDirectPlayLobby_ReceiveLobbyMessage(p,a,b,c,d,e)   (p)->lpVtbl->ReceiveLobbyMessage(p,a,b,c,d,e)
#define IDirectPlayLobby_RunApplication(p,a,b,c,d)          (p)->lpVtbl->RunApplication(p,a,b,c,d)
#define IDirectPlayLobby_SendLobbyMessage(p,a,b,c,d)        (p)->lpVtbl->SendLobbyMessage(p,a,b,c,d)
#define IDirectPlayLobby_SetConnectionSettings(p,a,b,c)     (p)->lpVtbl->SetConnectionSettings(p,a,b,c)
#define IDirectPlayLobby_SetLobbyMessageEvent(p,a,b,c)      (p)->lpVtbl->SetLobbyMessageEvent(p,a,b,c)
/*** IDirectPlayLobby2 methods ***/
#define IDirectPlayLobby_CreateCompoundAddress(p,a,b,c,d)   (p)->lpVtbl->CreateCompoundAddress(p,a,b,c,d)
/*** IDirectPlayLobby3 methods ***/
#define IDirectPlayLobby_ConnectEx(p,a,b,c,d)               (p)->lpVtbl->ConnectEx(p,a,b,c,d)
#define IDirectPlayLobby_RegisterApplication(p,a,b)         (p)->lpVtbl->RegisterApplication(p,a,b)
#define IDirectPlayLobby_UnregisterApplication(p,a,b)       (p)->lpVtbl->UnregisterApplication(p,a,b)
#define IDirectPlayLobby_WaitForConnectionSettings(p,a)     (p)->lpVtbl->WaitForConnectionSettings(p,a)
#else
/*** IUnknown methods ***/
#define IDirectPlayLobby_QueryInterface(p,a,b)              (p)->QueryInterface(a,b)
#define IDirectPlayLobby_AddRef(p)                          (p)->AddRef()
#define IDirectPlayLobby_Release(p)                         (p)->Release()
/*** IDirectPlayLobby methods ***/
#define IDirectPlayLobby_Connect(p,a,b,c)                   (p)->Connect(a,b,c)
#define IDirectPlayLobby_CreateAddress(p,a,b,c,d,e,f)       (p)->CreateAddress(a,b,c,d,e,f)
#define IDirectPlayLobby_EnumAddress(p,a,b,c,d)             (p)->EnumAddress(a,b,c,d)
#define IDirectPlayLobby_EnumAddressTypes(p,a,b,c,d)        (p)->EnumAddressTypes(a,b,c,d)
#define IDirectPlayLobby_EnumLocalApplications(p,a,b,c)     (p)->EnumLocalApplications(a,b,c)
#define IDirectPlayLobby_GetConnectionSettings(p,a,b,c)     (p)->GetConnectionSettings(a,b,c)
#define IDirectPlayLobby_ReceiveLobbyMessage(p,a,b,c,d,e)   (p)->ReceiveLobbyMessage(a,b,c,d,e)
#define IDirectPlayLobby_RunApplication(p,a,b,c,d)          (p)->RunApplication(a,b,c,d)
#define IDirectPlayLobby_SendLobbyMessage(p,a,b,c,d)        (p)->SendLobbyMessage(a,b,c,d)
#define IDirectPlayLobby_SetConnectionSettings(p,a,b,c)     (p)->SetConnectionSettings(a,b,c)
#define IDirectPlayLobby_SetLobbyMessageEvent(p,a,b,c)      (p)->SetLobbyMessageEvent(a,b,c)
/*** IDirectPlayLobby2 methods ***/
#define IDirectPlayLobby_CreateCompoundAddress(p,a,b,c,d)   (p)->CreateCompoundAddress(a,b,c,d)
/*** IDirectPlayLobby3 methods ***/
#define IDirectPlayLobby_ConnectEx(p,a,b,c,d)               (p)->ConnectEx(a,b,c,d)
#define IDirectPlayLobby_RegisterApplication(p,a,b)         (p)->RegisterApplication(a,b)
#define IDirectPlayLobby_UnregisterApplication(p,a,b)       (p)->UnregisterApplication(a,b)
#define IDirectPlayLobby_WaitForConnectionSettings(p,a)     (p)->WaitForConnectionSettings(a)
#endif

/* Used for WaitForConnectionSettings */
#define DPLWAIT_CANCEL                  0x00000001

#ifdef __cplusplus
} /* extern "C" */
#endif /* defined(__cplusplus) */

#endif /* __WINE_DPLOBBY_H */
