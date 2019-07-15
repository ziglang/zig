#undef INTERFACE
/*
 * Copyright (C) the Wine project
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

#ifndef __WINE_DPLAY_H
#define __WINE_DPLAY_H

#include <ole2.h>

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */

typedef LPVOID (*LPRGLPVOID)[];
typedef LPRGLPVOID PRGPVOID, LPRGPVOID, PRGLPVOID, PAPVOID, LPAPVOID, PALPVOID, LPALPVOID;

#define VOL volatile
typedef VOID * volatile LPVOIDV;


/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(CLSID_DirectPlay,0xd1eb6d20, 0x8923, 0x11d0, 0x9d, 0x97, 0x0, 0xa0, 0xc9, 0xa, 0x43, 0xcb);

DEFINE_GUID(IID_IDirectPlay, 0x5454e9a0, 0xdb65, 0x11ce, 0x92, 0x1c, 0x00, 0xaa, 0x00, 0x6c, 0x49, 0x72);
typedef struct IDirectPlay *LPDIRECTPLAY;

DEFINE_GUID(IID_IDirectPlay2, 0x2b74f7c0, 0x9154, 0x11cf, 0xa9, 0xcd, 0x0, 0xaa, 0x0, 0x68, 0x86, 0xe3);
typedef struct IDirectPlay2 *LPDIRECTPLAY2;

DEFINE_GUID(IID_IDirectPlay2A,0x9d460580, 0xa822, 0x11cf, 0x96, 0xc, 0x0, 0x80, 0xc7, 0x53, 0x4e, 0x82);
typedef struct IDirectPlay2 IDirectPlay2A,*LPDIRECTPLAY2A;

DEFINE_GUID(IID_IDirectPlay3, 0x133efe40, 0x32dc, 0x11d0, 0x9c, 0xfb, 0x0, 0xa0, 0xc9, 0xa, 0x43, 0xcb);
typedef struct IDirectPlay3 *LPDIRECTPLAY3;

DEFINE_GUID(IID_IDirectPlay3A,0x133efe41, 0x32dc, 0x11d0, 0x9c, 0xfb, 0x0, 0xa0, 0xc9, 0xa, 0x43, 0xcb);
typedef struct IDirectPlay3 IDirectPlay3A,*LPDIRECTPLAY3A;

DEFINE_GUID(IID_IDirectPlay4, 0xab1c530, 0x4745, 0x11d1, 0xa7, 0xa1, 0x0, 0x0, 0xf8, 0x3, 0xab, 0xfc);
typedef struct IDirectPlay4 *LPDIRECTPLAY4;

DEFINE_GUID(IID_IDirectPlay4A,0xab1c531, 0x4745, 0x11d1, 0xa7, 0xa1, 0x0, 0x0, 0xf8, 0x3, 0xab, 0xfc);
typedef struct IDirectPlay4 IDirectPlay4A,*LPDIRECTPLAY4A;


/*
 * GUIDS used by Service Providers shipped with DirectPlay
 * Use these to identify Service Provider returned by EnumConnections
 */

/* GUID for IPX service provider {685BC400-9D2C-11cf-A9CD-00AA006886E3} */
DEFINE_GUID(DPSPGUID_IPX, 0x685bc400, 0x9d2c, 0x11cf, 0xa9, 0xcd, 0x0, 0xaa, 0x0, 0x68, 0x86, 0xe3);

/* GUID for TCP/IP service provider {36E95EE0-8577-11cf-960C-0080C7534E82} */
DEFINE_GUID(DPSPGUID_TCPIP, 0x36E95EE0, 0x8577, 0x11cf, 0x96, 0xc, 0x0, 0x80, 0xc7, 0x53, 0x4e, 0x82);

/* GUID for Serial service provider {0F1D6860-88D9-11cf-9C4E-00A0C905425E} */
DEFINE_GUID(DPSPGUID_SERIAL, 0xf1d6860, 0x88d9, 0x11cf, 0x9c, 0x4e, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);

/* GUID for Modem service provider {44EAA760-CB68-11cf-9C4E-00A0C905425E} */
DEFINE_GUID(DPSPGUID_MODEM, 0x44eaa760, 0xcb68, 0x11cf, 0x9c, 0x4e, 0x0, 0xa0, 0xc9, 0x5, 0x42, 0x5e);


/*****************************************************************************
 * Miscellaneous
 */

/* Return Values for Direct Play */
#define _FACDP  0x877
#define MAKE_DPHRESULT( code )    MAKE_HRESULT( 1, _FACDP, code )

#define DP_OK                           S_OK
#define DPERR_ALREADYINITIALIZED        MAKE_DPHRESULT(   5 )
#define DPERR_ACCESSDENIED              MAKE_DPHRESULT(  10 )
#define DPERR_ACTIVEPLAYERS             MAKE_DPHRESULT(  20 )
#define DPERR_BUFFERTOOSMALL            MAKE_DPHRESULT(  30 )
#define DPERR_CANTADDPLAYER             MAKE_DPHRESULT(  40 )
#define DPERR_CANTCREATEGROUP           MAKE_DPHRESULT(  50 )
#define DPERR_CANTCREATEPLAYER          MAKE_DPHRESULT(  60 )
#define DPERR_CANTCREATESESSION         MAKE_DPHRESULT(  70 )
#define DPERR_CAPSNOTAVAILABLEYET       MAKE_DPHRESULT(  80 )
#define DPERR_EXCEPTION                 MAKE_DPHRESULT(  90 )
#define DPERR_GENERIC                   E_FAIL
#define DPERR_INVALIDFLAGS              MAKE_DPHRESULT( 120 )
#define DPERR_INVALIDOBJECT             MAKE_DPHRESULT( 130 )
#define DPERR_INVALIDPARAM              E_INVALIDARG
#define DPERR_INVALIDPARAMS             DPERR_INVALIDPARAM
#define DPERR_INVALIDPLAYER             MAKE_DPHRESULT( 150 )
#define DPERR_INVALIDGROUP              MAKE_DPHRESULT( 155 )
#define DPERR_NOCAPS                    MAKE_DPHRESULT( 160 )
#define DPERR_NOCONNECTION              MAKE_DPHRESULT( 170 )
#define DPERR_NOMEMORY                  E_OUTOFMEMORY
#define DPERR_OUTOFMEMORY               DPERR_NOMEMORY
#define DPERR_NOMESSAGES                MAKE_DPHRESULT( 190 )
#define DPERR_NONAMESERVERFOUND         MAKE_DPHRESULT( 200 )
#define DPERR_NOPLAYERS                 MAKE_DPHRESULT( 210 )
#define DPERR_NOSESSIONS                MAKE_DPHRESULT( 220 )
#define DPERR_PENDING                   E_PENDING
#define DPERR_SENDTOOBIG                MAKE_DPHRESULT( 230 )
#define DPERR_TIMEOUT                   MAKE_DPHRESULT( 240 )
#define DPERR_UNAVAILABLE               MAKE_DPHRESULT( 250 )
#define DPERR_UNSUPPORTED               E_NOTIMPL
#define DPERR_BUSY                      MAKE_DPHRESULT( 270 )
#define DPERR_USERCANCEL                MAKE_DPHRESULT( 280 )
#define DPERR_NOINTERFACE               E_NOINTERFACE
#define DPERR_CANNOTCREATESERVER        MAKE_DPHRESULT( 290 )
#define DPERR_PLAYERLOST                MAKE_DPHRESULT( 300 )
#define DPERR_SESSIONLOST               MAKE_DPHRESULT( 310 )
#define DPERR_UNINITIALIZED             MAKE_DPHRESULT( 320 )
#define DPERR_NONEWPLAYERS              MAKE_DPHRESULT( 330 )
#define DPERR_INVALIDPASSWORD           MAKE_DPHRESULT( 340 )
#define DPERR_CONNECTING                MAKE_DPHRESULT( 350 )
#define DPERR_CONNECTIONLOST            MAKE_DPHRESULT( 360 )
#define DPERR_UNKNOWNMESSAGE            MAKE_DPHRESULT( 370 )
#define DPERR_CANCELFAILED              MAKE_DPHRESULT( 380 )
#define DPERR_INVALIDPRIORITY           MAKE_DPHRESULT( 390 )
#define DPERR_NOTHANDLED                MAKE_DPHRESULT( 400 )
#define DPERR_CANCELLED                 MAKE_DPHRESULT( 410 )
#define DPERR_ABORTED                   MAKE_DPHRESULT( 420 )
#define DPERR_BUFFERTOOLARGE            MAKE_DPHRESULT( 1000 )
#define DPERR_CANTCREATEPROCESS         MAKE_DPHRESULT( 1010 )
#define DPERR_APPNOTSTARTED             MAKE_DPHRESULT( 1020 )
#define DPERR_INVALIDINTERFACE          MAKE_DPHRESULT( 1030 )
#define DPERR_NOSERVICEPROVIDER         MAKE_DPHRESULT( 1040 )
#define DPERR_UNKNOWNAPPLICATION        MAKE_DPHRESULT( 1050 )
#define DPERR_NOTLOBBIED                MAKE_DPHRESULT( 1070 )
#define DPERR_SERVICEPROVIDERLOADED     MAKE_DPHRESULT( 1080 )
#define DPERR_ALREADYREGISTERED         MAKE_DPHRESULT( 1090 )
#define DPERR_NOTREGISTERED             MAKE_DPHRESULT( 1100 )
#define DPERR_AUTHENTICATIONFAILED      MAKE_DPHRESULT( 2000 )
#define DPERR_CANTLOADSSPI              MAKE_DPHRESULT( 2010 )
#define DPERR_ENCRYPTIONFAILED          MAKE_DPHRESULT( 2020 )
#define DPERR_SIGNFAILED                MAKE_DPHRESULT( 2030 )
#define DPERR_CANTLOADSECURITYPACKAGE   MAKE_DPHRESULT( 2040 )
#define DPERR_ENCRYPTIONNOTSUPPORTED    MAKE_DPHRESULT( 2050 )
#define DPERR_CANTLOADCAPI              MAKE_DPHRESULT( 2060 )
#define DPERR_NOTLOGGEDIN               MAKE_DPHRESULT( 2070 )
#define DPERR_LOGONDENIED               MAKE_DPHRESULT( 2080 )


/* DPID - DirectPlay player and group ID */
typedef DWORD DPID, *LPDPID;

/* DPID from whence originate messages - just an ID */
#define DPID_SYSMSG             0           /* DPID of system */
#define DPID_ALLPLAYERS         0           /* DPID of all players */
#define DPID_SERVERPLAYER       1           /* DPID of the server player */
#define DPID_UNKNOWN            0xFFFFFFFF  /* Player ID is unknown */

/*  DPCAPS -  Used to obtain the capabilities of a DirectPlay object */
typedef struct tagDPCAPS
{
    DWORD dwSize;               /* Size of structure in bytes */
    DWORD dwFlags;
    DWORD dwMaxBufferSize;
    DWORD dwMaxQueueSize;       /* Obsolete. */
    DWORD dwMaxPlayers;         /* Maximum players/groups (local + remote) */
    DWORD dwHundredBaud;        /* Bandwidth in 100 bits per second units;
                                 * i.e. 24 is 2400, 96 is 9600, etc.
                                 */
    DWORD dwLatency;            /* Estimated latency; 0 = unknown */
    DWORD dwMaxLocalPlayers;    /* Maximum # of locally created players */
    DWORD dwHeaderLength;       /* Maximum header length in bytes */
    DWORD dwTimeout;            /* Service provider's suggested timeout value
                                 * This is how long DirectPlay will wait for
                                 * responses to system messages
                                 */
} DPCAPS, *LPDPCAPS;

typedef struct tagDPNAME
{
    DWORD   dwSize;
    DWORD   dwFlags;            /* Not used must be 0 */

    union /*playerShortName */      /* Player's Handle? */
    {
        LPWSTR  lpszShortName;
        LPSTR   lpszShortNameA;
    } DUMMYUNIONNAME1;

    union /*playerLongName */       /* Player's formal/real name */
    {
        LPWSTR  lpszLongName;
        LPSTR   lpszLongNameA;
    } DUMMYUNIONNAME2;

} DPNAME, *LPDPNAME;

#define DPLONGNAMELEN     52
#define DPSHORTNAMELEN    20
#define DPSESSIONNAMELEN  32
#define DPPASSWORDLEN     16
#define DPUSERRESERVED    16

typedef struct tagDPSESSIONDESC
{
    DWORD   dwSize;
    GUID    guidSession;
    DWORD   dwSession;
    DWORD   dwMaxPlayers;
    DWORD   dwCurrentPlayers;
    DWORD   dwFlags;
    char    szSessionName[ DPSESSIONNAMELEN ];
    char    szUserField[ DPUSERRESERVED ];
    DWORD   dwReserved1;
    char    szPassword[ DPPASSWORDLEN ];
    DWORD   dwReserved2;
    DWORD   dwUser1;
    DWORD   dwUser2;
    DWORD   dwUser3;
    DWORD   dwUser4;
} DPSESSIONDESC, *LPDPSESSIONDESC;

typedef struct tagDPSESSIONDESC2
{
    DWORD   dwSize;
    DWORD   dwFlags;
    GUID    guidInstance;
    GUID    guidApplication;   /* GUID of the DP application, GUID_NULL if
                                * all applications! */

    DWORD   dwMaxPlayers;
    DWORD   dwCurrentPlayers;   /* (read only value) */

    union  /* Session name */
    {
        LPWSTR  lpszSessionName;
        LPSTR   lpszSessionNameA;
    } DUMMYUNIONNAME1;

    union  /* Optional password */
    {
        LPWSTR  lpszPassword;
        LPSTR   lpszPasswordA;
    } DUMMYUNIONNAME2;

    DWORD   dwReserved1;
    DWORD   dwReserved2;

    DWORD   dwUser1;        /* For use by the application */
    DWORD   dwUser2;
    DWORD   dwUser3;
    DWORD   dwUser4;
} DPSESSIONDESC2, *LPDPSESSIONDESC2;
typedef const DPSESSIONDESC2* LPCDPSESSIONDESC2;

#define DPOPEN_JOIN                     0x00000001
#define DPOPEN_CREATE                   0x00000002
#define DPOPEN_RETURNSTATUS             DPENUMSESSIONS_RETURNSTATUS

#define DPSESSION_NEWPLAYERSDISABLED    0x00000001
#define DPSESSION_MIGRATEHOST           0x00000004
#define DPSESSION_NOMESSAGEID           0x00000008
#define DPSESSION_JOINDISABLED          0x00000020
#define DPSESSION_KEEPALIVE             0x00000040
#define DPSESSION_NODATAMESSAGES        0x00000080
#define DPSESSION_SECURESERVER          0x00000100
#define DPSESSION_PRIVATE               0x00000200
#define DPSESSION_PASSWORDREQUIRED      0x00000400
#define DPSESSION_MULTICASTSERVER       0x00000800
#define DPSESSION_CLIENTSERVER          0x00001000
#define DPSESSION_DIRECTPLAYPROTOCOL    0x00002000
#define DPSESSION_NOPRESERVEORDER       0x00004000
#define DPSESSION_OPTIMIZELATENCY       0x00008000

typedef struct tagDPLCONNECTION
{
    DWORD               dwSize;
    DWORD               dwFlags;
    LPDPSESSIONDESC2    lpSessionDesc;  /* Ptr to session desc to use for connect */
    LPDPNAME            lpPlayerName;   /* Ptr to player name structure */
    GUID                guidSP;         /* GUID of Service Provider to use */
    LPVOID              lpAddress;      /* Ptr to Address of Service Provider to use */
    DWORD               dwAddressSize;  /* Size of address data */
} DPLCONNECTION, *LPDPLCONNECTION;

/* DPLCONNECTION flags (for dwFlags) */
#define DPLCONNECTION_CREATESESSION DPOPEN_CREATE
#define DPLCONNECTION_JOINSESSION   DPOPEN_JOIN

typedef struct tagDPCHAT
{
    DWORD               dwSize;
    DWORD               dwFlags;
    union
    {                          /* Message string */
        LPWSTR  lpszMessage;   /* Unicode */
        LPSTR   lpszMessageA;  /* ANSI */
    } DUMMYUNIONNAME;
} DPCHAT, *LPDPCHAT;

typedef struct
{
  UINT   len;
  PUCHAR pData;
} SGBUFFER, *PSGBUFFER, *LPSGBUFFER;


typedef struct tagDPSECURITYDESC
{
    DWORD dwSize;                   /* Size of structure */
    DWORD dwFlags;                  /* Not used. Must be zero. */
    union
    {                               /* SSPI provider name */
        LPWSTR  lpszSSPIProvider;   /* Unicode */
        LPSTR   lpszSSPIProviderA;  /* ANSI */
    } DUMMYUNIONNAME1;
    union
    {                               /* CAPI provider name */
        LPWSTR lpszCAPIProvider;    /* Unicode */
        LPSTR  lpszCAPIProviderA;   /* ANSI */
    } DUMMYUNIONNAME2;
    DWORD dwCAPIProviderType;       /* Crypto Service Provider type */
    DWORD dwEncryptionAlgorithm;    /* Encryption Algorithm type */
} DPSECURITYDESC, *LPDPSECURITYDESC;

typedef const DPSECURITYDESC *LPCDPSECURITYDESC;

typedef struct tagDPCREDENTIALS
{
    DWORD dwSize;               /* Size of structure */
    DWORD dwFlags;              /* Not used. Must be zero. */
    union
    {                           /* User name of the account */
        LPWSTR  lpszUsername;   /* Unicode */
        LPSTR   lpszUsernameA;  /* ANSI */
    } DUMMYUNIONNAME1;
    union
    {                           /* Password of the account */
        LPWSTR  lpszPassword;   /* Unicode */
        LPSTR   lpszPasswordA;  /* ANSI */
    } DUMMYUNIONNAME2;
    union
    {                           /* Domain name of the account */
        LPWSTR  lpszDomain;     /* Unicode */
        LPSTR   lpszDomainA;    /* ANSI */
    } DUMMYUNIONNAME3;
} DPCREDENTIALS, *LPDPCREDENTIALS;

typedef const DPCREDENTIALS *LPCDPCREDENTIALS;



typedef WINBOOL (CALLBACK *LPDPENUMDPCALLBACKW)(
    LPGUID      lpguidSP,
    LPWSTR      lpSPName,
    DWORD       dwMajorVersion,
    DWORD       dwMinorVersion,
    LPVOID      lpContext);

typedef WINBOOL (CALLBACK *LPDPENUMDPCALLBACKA)(
    LPGUID      lpguidSP,
    LPSTR       lpSPName,       /* ptr to str w/ driver description */
    DWORD       dwMajorVersion, /* Major # of driver spec in lpguidSP */
    DWORD       dwMinorVersion, /* Minor # of driver spec in lpguidSP */
    LPVOID      lpContext);     /* User given */

#ifndef __LPCGUID_DEFINED__
#define __LPCGUID_DEFINED__
typedef const GUID *LPCGUID;
#endif

typedef const DPNAME *LPCDPNAME;

typedef WINBOOL (CALLBACK *LPDPENUMCONNECTIONSCALLBACK)(
    LPCGUID     lpguidSP,
    LPVOID      lpConnection,
    DWORD       dwConnectionSize,
    LPCDPNAME   lpName,
    DWORD       dwFlags,
    LPVOID      lpContext);

typedef WINBOOL (CALLBACK *LPDPENUMSESSIONSCALLBACK)(
    LPDPSESSIONDESC lpDPSessionDesc,
    LPVOID      lpContext,
    LPDWORD     lpdwTimeOut,
    DWORD       dwFlags);


extern HRESULT WINAPI DirectPlayEnumerateA( LPDPENUMDPCALLBACKA, LPVOID );
extern HRESULT WINAPI DirectPlayEnumerateW( LPDPENUMDPCALLBACKW, LPVOID );
extern HRESULT WINAPI DirectPlayCreate( LPGUID lpGUID, LPDIRECTPLAY *lplpDP, IUnknown *pUnk );

typedef WINBOOL (CALLBACK *LPDPENUMPLAYERSCALLBACK)(
    DPID   dpId,
    LPSTR  lpFriendlyName,
    LPSTR  lpFormalName,
    DWORD  dwFlags,
    LPVOID          lpContext );

typedef WINBOOL (CALLBACK *LPDPENUMPLAYERSCALLBACK2)(
    DPID            dpId,
    DWORD           dwPlayerType,
    LPCDPNAME       lpName,
    DWORD           dwFlags,
    LPVOID          lpContext );

typedef WINBOOL (CALLBACK *LPDPENUMSESSIONSCALLBACK2)(
    LPCDPSESSIONDESC2   lpThisSD,
    LPDWORD             lpdwTimeOut,
    DWORD               dwFlags,
    LPVOID              lpContext );

#define DPESC_TIMEDOUT          0x00000001

/*****************************************************************************
 * IDirectPlay interface
 */
#define INTERFACE IDirectPlay
DECLARE_INTERFACE_(IDirectPlay,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay methods ***/
    STDMETHOD(AddPlayerToGroup)(THIS_ DPID idGroup, DPID idPlayer) PURE;
    STDMETHOD(Close)(THIS) PURE;
    STDMETHOD(CreatePlayer)(THIS_ LPDPID lpidPlayer, LPSTR lpPlayerName, LPSTR, LPHANDLE) PURE;
    STDMETHOD(CreateGroup)(THIS_ LPDPID lpidGroup, LPSTR lpGroupName, LPSTR) PURE;
    STDMETHOD(DeletePlayerFromGroup)(THIS_ DPID idGroup, DPID idPlayer) PURE;
    STDMETHOD(DestroyPlayer)(THIS_ DPID idPlayer) PURE;
    STDMETHOD(DestroyGroup)(THIS_ DPID idGroup) PURE;
    STDMETHOD(EnableNewPlayers)(THIS_ WINBOOL) PURE;
    STDMETHOD(EnumGroupPlayers)(THIS_ DPID idGroup, LPDPENUMPLAYERSCALLBACK lpEnumPlayersCallback, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumGroups)(THIS_ DWORD, LPDPENUMPLAYERSCALLBACK lpEnumPlayersCallback, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumPlayers)(THIS_ DWORD, LPDPENUMPLAYERSCALLBACK lpEnumPlayersCallback, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumSessions)(THIS_ LPDPSESSIONDESC lpsd, DWORD dwTimeout, LPDPENUMSESSIONSCALLBACK lpEnumSessionsCallback, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(GetCaps)(THIS_ LPDPCAPS lpDPCaps) PURE;
    STDMETHOD(GetMessageCount)(THIS_ DPID idPlayer, LPDWORD lpdwCount) PURE;
    STDMETHOD(GetPlayerCaps)(THIS_ DPID idPlayer, LPDPCAPS lpPlayerCaps) PURE;
    STDMETHOD(GetPlayerName)(THIS_ DPID idPlayer, LPSTR, LPDWORD, LPSTR, LPDWORD) PURE;
    STDMETHOD(Initialize)(THIS_ LPGUID lpGUID) PURE;
    STDMETHOD(Open)(THIS_ LPDPSESSIONDESC lpsd) PURE;
    STDMETHOD(Receive)(THIS_ LPDPID lpidFrom, LPDPID lpidTo, DWORD dwFlags, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(SaveSession)(THIS_ LPSTR) PURE;
    STDMETHOD(Send)(THIS_ DPID idFrom, DPID idTo, DWORD dwFlags, LPVOID lpData, DWORD dwDataSize) PURE;
    STDMETHOD(SetPlayerName)(THIS_ DPID idPlayer, LPSTR lpPlayerName, LPSTR) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlay_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlay_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectPlay_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectPlay methods ***/
#define IDirectPlay_AddPlayerToGroup(p,a,b)      (p)->lpVtbl->AddPlayerToGroup(p,a,b)
#define IDirectPlay_Close(p)                     (p)->lpVtbl->Close(p)
#define IDirectPlay_CreatePlayer(p,a,b,c,d)      (p)->lpVtbl->CreatePlayer(p,a,b,c,d)
#define IDirectPlay_CreateGroup(p,a,b,c)         (p)->lpVtbl->CreateGroup(p,a,b,c)
#define IDirectPlay_DeletePlayerFromGroup(p,a,b) (p)->lpVtbl->DeletePlayerFromGroup(p,a,b)
#define IDirectPlay_DestroyPlayer(p,a)           (p)->lpVtbl->DestroyPlayer(p,a)
#define IDirectPlay_DestroyGroup(p,a)            (p)->lpVtbl->DestroyGroup(p,a)
#define IDirectPlay_EnableNewPlayers(p,a)        (p)->lpVtbl->EnableNewPlayers(p,a)
#define IDirectPlay_EnumGroupPlayers(p,a,b,c,d)  (p)->lpVtbl->EnumGroupPlayers(p,a,b,c,d)
#define IDirectPlay_EnumGroups(p,a,b,c,d)        (p)->lpVtbl->EnumGroups(p,a,b,c,d)
#define IDirectPlay_EnumPlayers(p,a,b,c,d)       (p)->lpVtbl->EnumPlayers(p,a,b,c,d)
#define IDirectPlay_EnumSessions(p,a,b,c,d,e)    (p)->lpVtbl->EnumSessions(p,a,b,c,d,e)
#define IDirectPlay_GetCaps(p,a)                 (p)->lpVtbl->GetCaps(p,a)
#define IDirectPlay_GetMessageCount(p,a,b)       (p)->lpVtbl->GetMessageCount(p,a,b)
#define IDirectPlay_GetPlayerCaps(p,a,b)         (p)->lpVtbl->GetPlayerCaps(p,a,b)
#define IDirectPlay_GetPlayerName(p,a,b,c,d,e)   (p)->lpVtbl->GetPlayerName(p,a,b,c,d,e)
#define IDirectPlay_Initialize(p,a)              (p)->lpVtbl->Initialize(p,a)
#define IDirectPlay_Open(p,a)                    (p)->lpVtbl->Open(p,a)
#define IDirectPlay_Receive(p,a,b,c,d,e)         (p)->lpVtbl->Receive(p,a,b,c,d,e)
#define IDirectPlay_SaveSession(p,a)             (p)->lpVtbl->SaveSession(p,a)
#define IDirectPlay_Send(p,a,b,c,d,e)            (p)->lpVtbl->Send(p,a,b,c,d,e)
#define IDirectPlay_SetPlayerName(p,a,b,c)       (p)->lpVtbl->SetPlayerName(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirectPlay_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectPlay_AddRef(p)             (p)->AddRef()
#define IDirectPlay_Release(p)            (p)->Release()
/*** IDirectPlay methods ***/
#define IDirectPlay_AddPlayerToGroup(p,a,b)      (p)->AddPlayerToGroup(a,b)
#define IDirectPlay_Close(p)                     (p)->Close()
#define IDirectPlay_CreatePlayer(p,a,b,c,d)      (p)->CreatePlayer(a,b,c,d)
#define IDirectPlay_CreateGroup(p,a,b,c)         (p)->CreateGroup(a,b,c)
#define IDirectPlay_DeletePlayerFromGroup(p,a,b) (p)->DeletePlayerFromGroup(a,b)
#define IDirectPlay_DestroyPlayer(p,a)           (p)->DestroyPlayer(a)
#define IDirectPlay_DestroyGroup(p,a)            (p)->DestroyGroup(a)
#define IDirectPlay_EnableNewPlayers(p,a)        (p)->EnableNewPlayers(a)
#define IDirectPlay_EnumGroupPlayers(p,a,b,c,d)  (p)->EnumGroupPlayers(a,b,c,d)
#define IDirectPlay_EnumGroups(p,a,b,c,d)        (p)->EnumGroups(a,b,c,d)
#define IDirectPlay_EnumPlayers(p,a,b,c,d)       (p)->EnumPlayers(a,b,c,d)
#define IDirectPlay_EnumSessions(p,a,b,c,d,e)    (p)->EnumSessions(a,b,c,d,e)
#define IDirectPlay_GetCaps(p,a)                 (p)->GetCaps(a)
#define IDirectPlay_GetMessageCount(p,a,b)       (p)->GetMessageCount(a,b)
#define IDirectPlay_GetPlayerCaps(p,a,b)         (p)->GetPlayerCaps(a,b)
#define IDirectPlay_GetPlayerName(p,a,b,c,d,e)   (p)->GetPlayerName(a,b,c,d,e)
#define IDirectPlay_Initialize(p,a)              (p)->Initialize(a)
#define IDirectPlay_Open(p,a)                    (p)->Open(a)
#define IDirectPlay_Receive(p,a,b,c,d,e)         (p)->Receive(a,b,c,d,e)
#define IDirectPlay_SaveSession(p,a)             (p)->SaveSession(a)
#define IDirectPlay_Send(p,a,b,c,d,e)            (p)->Send(a,b,c,d,e)
#define IDirectPlay_SetPlayerName(p,a,b,c)       (p)->SetPlayerName(a,b,c)
#endif


/*****************************************************************************
 * IDirectPlay2 and IDirectPlay2A interface
 */
#define INTERFACE IDirectPlay2
DECLARE_INTERFACE_(IDirectPlay2,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay2 methods ***/
    STDMETHOD(AddPlayerToGroup)(THIS_ DPID idGroup, DPID idPlayer) PURE;
    STDMETHOD(Close)(THIS) PURE;
    STDMETHOD(CreateGroup)(THIS_ LPDPID lpidGroup, LPDPNAME lpGroupName, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(CreatePlayer)(THIS_ LPDPID lpidPlayer, LPDPNAME lpPlayerName, HANDLE hEvent, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(DeletePlayerFromGroup)(THIS_ DPID idGroup, DPID idPlayer) PURE;
    STDMETHOD(DestroyGroup)(THIS_ DPID idGroup) PURE;
    STDMETHOD(DestroyPlayer)(THIS_ DPID idPlayer) PURE;
    STDMETHOD(EnumGroupPlayers)(THIS_ DPID idGroup, LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumGroups)(THIS_ LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumPlayers)(THIS_ LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumSessions)(THIS_ LPDPSESSIONDESC2 lpsd, DWORD dwTimeout, LPDPENUMSESSIONSCALLBACK2 lpEnumSessionsCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(GetCaps)(THIS_ LPDPCAPS lpDPCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupData)(THIS_ DPID idGroup, LPVOID lpData, LPDWORD lpdwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupName)(THIS_ DPID idGroup, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetMessageCount)(THIS_ DPID idPlayer, LPDWORD lpdwCount) PURE;
    STDMETHOD(GetPlayerAddress)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetPlayerCaps)(THIS_ DPID idPlayer, LPDPCAPS lpPlayerCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetPlayerData)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(GetPlayerName)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetSessionDesc)(THIS_ LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(Initialize)(THIS_ LPGUID lpGUID) PURE;
    STDMETHOD(Open)(THIS_ LPDPSESSIONDESC2 lpsd, DWORD dwFlags) PURE;
    STDMETHOD(Receive)(THIS_ LPDPID lpidFrom, LPDPID lpidTo, DWORD dwFlags, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(Send)(THIS_ DPID idFrom, DPID idTo, DWORD dwFlags, LPVOID lpData, DWORD dwDataSize) PURE;
    STDMETHOD(SetGroupData)(THIS_ DPID idGroup, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetGroupName)(THIS_ DPID idGroup, LPDPNAME lpGroupName, DWORD dwFlags) PURE;
    STDMETHOD(SetPlayerData)(THIS_ DPID idPlayer, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetPlayerName)(THIS_ DPID idPlayer, LPDPNAME lpPlayerName, DWORD dwFlags) PURE;
    STDMETHOD(SetSessionDesc)(THIS_ LPDPSESSIONDESC2 lpSessDesc, DWORD dwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlay2_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlay2_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectPlay2_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectPlay2 methods ***/
#define IDirectPlay2_AddPlayerToGroup(p,a,b)       (p)->lpVtbl->AddPlayerToGroup(p,a,b)
#define IDirectPlay2_Close(p)                      (p)->lpVtbl->Close(p)
#define IDirectPlay2_CreateGroup(p,a,b,c,d,e)      (p)->lpVtbl->CreateGroup(p,a,b,c,d,e)
#define IDirectPlay2_CreatePlayer(p,a,b,c,d,e,f)   (p)->lpVtbl->CreatePlayer(p,a,b,c,d,e,f)
#define IDirectPlay2_DeletePlayerFromGroup(p,a,b)  (p)->lpVtbl->DeletePlayerFromGroup(p,a,b)
#define IDirectPlay2_DestroyGroup(p,a)             (p)->lpVtbl->DestroyGroup(p,a)
#define IDirectPlay2_DestroyPlayer(p,a)            (p)->lpVtbl->DestroyPlayer(p,a)
#define IDirectPlay2_EnumGroupPlayers(p,a,b,c,d,e) (p)->lpVtbl->EnumGroupPlayers(p,a,b,c,d,e)
#define IDirectPlay2_EnumGroups(p,a,b,c,d)         (p)->lpVtbl->EnumGroups(p,a,b,c,d)
#define IDirectPlay2_EnumPlayers(p,a,b,c,d)        (p)->lpVtbl->EnumPlayers(p,a,b,c,d)
#define IDirectPlay2_EnumSessions(p,a,b,c,d,e)     (p)->lpVtbl->EnumSessions(p,a,b,c,d,e)
#define IDirectPlay2_GetCaps(p,a,b)                (p)->lpVtbl->GetCaps(p,a,b)
#define IDirectPlay2_GetGroupData(p,a,b,c,d)       (p)->lpVtbl->GetGroupData(p,a,b,c,d)
#define IDirectPlay2_GetGroupName(p,a,b,c)         (p)->lpVtbl->GetGroupName(p,a,b,c)
#define IDirectPlay2_GetMessageCount(p,a,b)        (p)->lpVtbl->GetMessageCount(p,a,b)
#define IDirectPlay2_GetPlayerAddress(p,a,b,c)     (p)->lpVtbl->GetPlayerAddress(p,a,b,c)
#define IDirectPlay2_GetPlayerCaps(p,a,b,c)        (p)->lpVtbl->GetPlayerCaps(p,a,b,c)
#define IDirectPlay2_GetPlayerData(p,a,b,c,d)      (p)->lpVtbl->GetPlayerData(p,a,b,c,d)
#define IDirectPlay2_GetPlayerName(p,a,b,c)        (p)->lpVtbl->GetPlayerName(p,a,b,c)
#define IDirectPlay2_GetSessionDesc(p,a,b)         (p)->lpVtbl->GetSessionDesc(p,a,b)
#define IDirectPlay2_Initialize(p,a)               (p)->lpVtbl->Initialize(p,a)
#define IDirectPlay2_Open(p,a,b)                   (p)->lpVtbl->Open(p,a,b)
#define IDirectPlay2_Receive(p,a,b,c,d,e)          (p)->lpVtbl->Receive(p,a,b,c,d,e)
#define IDirectPlay2_Send(p,a,b,c,d,e)             (p)->lpVtbl->Send(p,a,b,c,d,e)
#define IDirectPlay2_SetGroupData(p,a,b,c,d)       (p)->lpVtbl->SetGroupData(p,a,b,c,d)
#define IDirectPlay2_SetGroupName(p,a,b,c)         (p)->lpVtbl->SetGroupName(p,a,b,c)
#define IDirectPlay2_SetPlayerData(p,a,b,c,d)      (p)->lpVtbl->SetPlayerData(p,a,b,c,d)
#define IDirectPlay2_SetPlayerName(p,a,b,c)        (p)->lpVtbl->SetPlayerName(p,a,b,c)
#define IDirectPlay2_SetSessionDesc(p,a,b)         (p)->lpVtbl->SetSessionDesc(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirectPlay2_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectPlay2_AddRef(p)             (p)->AddRef()
#define IDirectPlay2_Release(p)            (p)->Release()
/*** IDirectPlay2 methods ***/
#define IDirectPlay2_AddPlayerToGroup(p,a,b)       (p)->AddPlayerToGroup(a,b)
#define IDirectPlay2_Close(p)                      (p)->Close()
#define IDirectPlay2_CreateGroup(p,a,b,c,d,e)      (p)->CreateGroup(a,b,c,d,e)
#define IDirectPlay2_CreatePlayer(p,a,b,c,d,e,f)   (p)->CreatePlayer(a,b,c,d,e,f)
#define IDirectPlay2_DeletePlayerFromGroup(p,a,b)  (p)->DeletePlayerFromGroup(a,b)
#define IDirectPlay2_DestroyGroup(p,a)             (p)->DestroyGroup(a)
#define IDirectPlay2_DestroyPlayer(p,a)            (p)->DestroyPlayer(a)
#define IDirectPlay2_EnumGroupPlayers(p,a,b,c,d,e) (p)->EnumGroupPlayers(a,b,c,d,e)
#define IDirectPlay2_EnumGroups(p,a,b,c,d)         (p)->EnumGroups(a,b,c,d)
#define IDirectPlay2_EnumPlayers(p,a,b,c,d)        (p)->EnumPlayers(a,b,c,d)
#define IDirectPlay2_EnumSessions(p,a,b,c,d,e)     (p)->EnumSessions(a,b,c,d,e)
#define IDirectPlay2_GetCaps(p,a,b)                (p)->GetCaps(a,b)
#define IDirectPlay2_GetGroupData(p,a,b,c,d)       (p)->GetGroupData(a,b,c,d)
#define IDirectPlay2_GetGroupName(p,a,b,c)         (p)->GetGroupName(a,b,c)
#define IDirectPlay2_GetMessageCount(p,a,b)        (p)->GetMessageCount(a,b)
#define IDirectPlay2_GetPlayerAddress(p,a,b,c)     (p)->GetPlayerAddress(a,b,c)
#define IDirectPlay2_GetPlayerCaps(p,a,b,c)        (p)->GetPlayerCaps(a,b,c)
#define IDirectPlay2_GetPlayerData(p,a,b,c,d)      (p)->GetPlayerData(a,b,c,d)
#define IDirectPlay2_GetPlayerName(p,a,b,c)        (p)->GetPlayerName(a,b,c)
#define IDirectPlay2_GetSessionDesc(p,a,b)         (p)->GetSessionDesc(a,b)
#define IDirectPlay2_Initialize(p,a)               (p)->Initialize(a)
#define IDirectPlay2_Open(p,a,b)                   (p)->Open(a,b)
#define IDirectPlay2_Receive(p,a,b,c,d,e)          (p)->Receive(a,b,c,d,e)
#define IDirectPlay2_Send(p,a,b,c,d,e)             (p)->Send(a,b,c,d,e)
#define IDirectPlay2_SetGroupData(p,a,b,c,d)       (p)->SetGroupData(a,b,c,d)
#define IDirectPlay2_SetGroupName(p,a,b,c)         (p)->SetGroupName(a,b,c)
#define IDirectPlay2_SetPlayerData(p,a,b,c,d)      (p)->SetPlayerData(a,b,c,d)
#define IDirectPlay2_SetPlayerName(p,a,b,c)        (p)->SetPlayerName(a,b,c)
#define IDirectPlay2_SetSessionDesc(p,a,b)         (p)->SetSessionDesc(a,b)
#endif


/*****************************************************************************
 * IDirectPlay3 and IDirectPlay3A interface
 */
#define INTERFACE IDirectPlay3
DECLARE_INTERFACE_(IDirectPlay3,IDirectPlay2)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay2 methods ***/
    STDMETHOD(AddPlayerToGroup)(THIS_ DPID idGroup, DPID idPlayer) PURE;
    STDMETHOD(Close)(THIS) PURE;
    STDMETHOD(CreateGroup)(THIS_ LPDPID lpidGroup, LPDPNAME lpGroupName, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(CreatePlayer)(THIS_ LPDPID lpidPlayer, LPDPNAME lpPlayerName, HANDLE hEvent, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(DeletePlayerFromGroup)(THIS_ DPID idGroup, DPID idPlayer) PURE;
    STDMETHOD(DestroyGroup)(THIS_ DPID idGroup) PURE;
    STDMETHOD(DestroyPlayer)(THIS_ DPID idPlayer) PURE;
    STDMETHOD(EnumGroupPlayers)(THIS_ DPID idGroup, LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumGroups)(THIS_ LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumPlayers)(THIS_ LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumSessions)(THIS_ LPDPSESSIONDESC2 lpsd, DWORD dwTimeout, LPDPENUMSESSIONSCALLBACK2 lpEnumSessionsCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(GetCaps)(THIS_ LPDPCAPS lpDPCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupData)(THIS_ DPID idGroup, LPVOID lpData, LPDWORD lpdwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupName)(THIS_ DPID idGroup, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetMessageCount)(THIS_ DPID idPlayer, LPDWORD lpdwCount) PURE;
    STDMETHOD(GetPlayerAddress)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetPlayerCaps)(THIS_ DPID idPlayer, LPDPCAPS lpPlayerCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetPlayerData)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(GetPlayerName)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetSessionDesc)(THIS_ LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(Initialize)(THIS_ LPGUID lpGUID) PURE;
    STDMETHOD(Open)(THIS_ LPDPSESSIONDESC2 lpsd, DWORD dwFlags) PURE;
    STDMETHOD(Receive)(THIS_ LPDPID lpidFrom, LPDPID lpidTo, DWORD dwFlags, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(Send)(THIS_ DPID idFrom, DPID idTo, DWORD dwFlags, LPVOID lpData, DWORD dwDataSize) PURE;
    STDMETHOD(SetGroupData)(THIS_ DPID idGroup, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetGroupName)(THIS_ DPID idGroup, LPDPNAME lpGroupName, DWORD dwFlags) PURE;
    STDMETHOD(SetPlayerData)(THIS_ DPID idPlayer, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetPlayerName)(THIS_ DPID idPlayer, LPDPNAME lpPlayerName, DWORD dwFlags) PURE;
    STDMETHOD(SetSessionDesc)(THIS_ LPDPSESSIONDESC2 lpSessDesc, DWORD dwFlags) PURE;
    /*** IDirectPlay3 methods ***/
    STDMETHOD(AddGroupToGroup)(THIS_ DPID idParentGroup, DPID idGroup) PURE;
    STDMETHOD(CreateGroupInGroup)(THIS_ DPID idParentGroup, LPDPID lpidGroup, LPDPNAME lpGroupName, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(DeleteGroupFromGroup)(THIS_ DPID idParentGroup, DPID idGroup) PURE;
    STDMETHOD(EnumConnections)(THIS_ LPCGUID lpguidApplication, LPDPENUMCONNECTIONSCALLBACK lpEnumCallback, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumGroupsInGroup)(THIS_ DPID idGroup, LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumCallback, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupConnectionSettings)(THIS_ DWORD dwFlags, DPID idGroup, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(InitializeConnection)(THIS_ LPVOID lpConnection, DWORD dwFlags) PURE;
    STDMETHOD(SecureOpen)(THIS_ LPCDPSESSIONDESC2 lpsd, DWORD dwFlags, LPCDPSECURITYDESC lpSecurity, LPCDPCREDENTIALS lpCredentials) PURE;
    STDMETHOD(SendChatMessage)(THIS_ DPID idFrom, DPID idTo, DWORD dwFlags, LPDPCHAT lpChatMessage) PURE;
    STDMETHOD(SetGroupConnectionSettings)(THIS_ DWORD dwFlags, DPID idGroup, LPDPLCONNECTION lpConnection) PURE;
    STDMETHOD(StartSession)(THIS_ DWORD dwFlags, DPID idGroup) PURE;
    STDMETHOD(GetGroupFlags)(THIS_ DPID idGroup, LPDWORD lpdwFlags) PURE;
    STDMETHOD(GetGroupParent)(THIS_ DPID idGroup, LPDPID lpidParent) PURE;
    STDMETHOD(GetPlayerAccount)(THIS_ DPID idPlayer, DWORD dwFlags, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetPlayerFlags)(THIS_ DPID idPlayer, LPDWORD lpdwFlags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlay3_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlay3_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectPlay3_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectPlay2 methods ***/
#define IDirectPlay3_AddPlayerToGroup(p,a,b)       (p)->lpVtbl->AddPlayerToGroup(p,a,b)
#define IDirectPlay3_Close(p)                      (p)->lpVtbl->Close(p)
#define IDirectPlay3_CreateGroup(p,a,b,c,d,e)      (p)->lpVtbl->CreateGroup(p,a,b,c,d,e)
#define IDirectPlay3_CreatePlayer(p,a,b,c,d,e,f)   (p)->lpVtbl->CreatePlayer(p,a,b,c,d,e,f)
#define IDirectPlay3_DeletePlayerFromGroup(p,a,b)  (p)->lpVtbl->DeletePlayerFromGroup(p,a,b)
#define IDirectPlay3_DestroyGroup(p,a)             (p)->lpVtbl->DestroyGroup(p,a)
#define IDirectPlay3_DestroyPlayer(p,a)            (p)->lpVtbl->DestroyPlayer(p,a)
#define IDirectPlay3_EnumGroupPlayers(p,a,b,c,d,e) (p)->lpVtbl->EnumGroupPlayers(p,a,b,c,d,e)
#define IDirectPlay3_EnumGroups(p,a,b,c,d)         (p)->lpVtbl->EnumGroups(p,a,b,c,d)
#define IDirectPlay3_EnumPlayers(p,a,b,c,d)        (p)->lpVtbl->EnumPlayers(p,a,b,c,d)
#define IDirectPlay3_EnumSessions(p,a,b,c,d,e)     (p)->lpVtbl->EnumSessions(p,a,b,c,d,e)
#define IDirectPlay3_GetCaps(p,a,b)                (p)->lpVtbl->GetCaps(p,a,b)
#define IDirectPlay3_GetGroupData(p,a,b,c,d)       (p)->lpVtbl->GetGroupData(p,a,b,c,d)
#define IDirectPlay3_GetGroupName(p,a,b,c)         (p)->lpVtbl->GetGroupName(p,a,b,c)
#define IDirectPlay3_GetMessageCount(p,a,b)        (p)->lpVtbl->GetMessageCount(p,a,b)
#define IDirectPlay3_GetPlayerAddress(p,a,b,c)     (p)->lpVtbl->GetPlayerAddress(p,a,b,c)
#define IDirectPlay3_GetPlayerCaps(p,a,b,c)        (p)->lpVtbl->GetPlayerCaps(p,a,b,c)
#define IDirectPlay3_GetPlayerData(p,a,b,c,d)      (p)->lpVtbl->GetPlayerData(p,a,b,c,d)
#define IDirectPlay3_GetPlayerName(p,a,b,c)        (p)->lpVtbl->GetPlayerName(p,a,b,c)
#define IDirectPlay3_GetSessionDesc(p,a,b)         (p)->lpVtbl->GetSessionDesc(p,a,b)
#define IDirectPlay3_Initialize(p,a)               (p)->lpVtbl->Initialize(p,a)
#define IDirectPlay3_Open(p,a,b)                   (p)->lpVtbl->Open(p,a,b)
#define IDirectPlay3_Receive(p,a,b,c,d,e)          (p)->lpVtbl->Receive(p,a,b,c,d,e)
#define IDirectPlay3_Send(p,a,b,c,d,e)             (p)->lpVtbl->Send(p,a,b,c,d,e)
#define IDirectPlay3_SetGroupData(p,a,b,c,d)       (p)->lpVtbl->SetGroupData(p,a,b,c,d)
#define IDirectPlay3_SetGroupName(p,a,b,c)         (p)->lpVtbl->SetGroupName(p,a,b,c)
#define IDirectPlay3_SetPlayerData(p,a,b,c,d)      (p)->lpVtbl->SetPlayerData(p,a,b,c,d)
#define IDirectPlay3_SetPlayerName(p,a,b,c)        (p)->lpVtbl->SetPlayerName(p,a,b,c)
#define IDirectPlay3_SetSessionDesc(p,a,b)         (p)->lpVtbl->SetSessionDesc(p,a,b)
/*** IDirectPlay3 methods ***/
#define IDirectPlay3_AddGroupToGroup(p,a,b)                (p)->lpVtbl->AddGroupToGroup(p,a,b)
#define IDirectPlay3_CreateGroupInGroup(p,a,b,c,d,e,f)     (p)->lpVtbl->CreateGroupInGroup(p,a,b,c,d,e,f)
#define IDirectPlay3_DeleteGroupFromGroup(p,a,b)           (p)->lpVtbl->DeleteGroupFromGroup(p,a,b)
#define IDirectPlay3_EnumConnections(p,a,b,c,d)            (p)->lpVtbl->EnumConnections(p,a,b,c,d)
#define IDirectPlay3_EnumGroupsInGroup(p,a,b,c,d,e)        (p)->lpVtbl->EnumGroupsInGroup(p,a,b,c,d,e)
#define IDirectPlay3_GetGroupConnectionSettings(p,a,b,c,d) (p)->lpVtbl->GetGroupConnectionSettings(p,a,b,c,d)
#define IDirectPlay3_InitializeConnection(p,a,b)           (p)->lpVtbl->InitializeConnection(p,a,b)
#define IDirectPlay3_SecureOpen(p,a,b,c,d)                 (p)->lpVtbl->SecureOpen(p,a,b,c,d)
#define IDirectPlay3_SendChatMessage(p,a,b,c,d)            (p)->lpVtbl->SendChatMessage(p,a,b,c,d)
#define IDirectPlay3_SetGroupConnectionSettings(p,a,b,c)   (p)->lpVtbl->SetGroupConnectionSettings(p,a,b,c)
#define IDirectPlay3_StartSession(p,a,b)                   (p)->lpVtbl->StartSession(p,a,b)
#define IDirectPlay3_GetGroupFlags(p,a,b)                  (p)->lpVtbl->GetGroupFlags(p,a,b)
#define IDirectPlay3_GetGroupParent(p,a,b)                 (p)->lpVtbl->GetGroupParent(p,a,b)
#define IDirectPlay3_GetPlayerAccount(p,a,b,c,d)           (p)->lpVtbl->GetPlayerAccount(p,a,b,c,d)
#define IDirectPlay3_GetPlayerFlags(p,a,b)                 (p)->lpVtbl->GetPlayerFlags(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirectPlay3_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectPlay3_AddRef(p)             (p)->AddRef()
#define IDirectPlay3_Release(p)            (p)->Release()
/*** IDirectPlay2 methods ***/
#define IDirectPlay3_AddPlayerToGroup(p,a,b)       (p)->AddPlayerToGroup(a,b)
#define IDirectPlay3_Close(p)                      (p)->Close()
#define IDirectPlay3_CreateGroup(p,a,b,c,d,e)      (p)->CreateGroup(a,b,c,d,e)
#define IDirectPlay3_CreatePlayer(p,a,b,c,d,e,f)   (p)->CreatePlayer(a,b,c,d,e,f)
#define IDirectPlay3_DeletePlayerFromGroup(p,a,b)  (p)->DeletePlayerFromGroup(a,b)
#define IDirectPlay3_DestroyGroup(p,a)             (p)->DestroyGroup(a)
#define IDirectPlay3_DestroyPlayer(p,a)            (p)->DestroyPlayer(a)
#define IDirectPlay3_EnumGroupPlayers(p,a,b,c,d,e) (p)->EnumGroupPlayers(a,b,c,d,e)
#define IDirectPlay3_EnumGroups(p,a,b,c,d)         (p)->EnumGroups(a,b,c,d)
#define IDirectPlay3_EnumPlayers(p,a,b,c,d)        (p)->EnumPlayers(a,b,c,d)
#define IDirectPlay3_EnumSessions(p,a,b,c,d,e)     (p)->EnumSessions(a,b,c,d,e)
#define IDirectPlay3_GetCaps(p,a,b)                (p)->GetCaps(a,b)
#define IDirectPlay3_GetGroupData(p,a,b,c,d)       (p)->GetGroupData(a,b,c,d)
#define IDirectPlay3_GetGroupName(p,a,b,c)         (p)->GetGroupName(a,b,c)
#define IDirectPlay3_GetMessageCount(p,a,b)        (p)->GetMessageCount(a,b)
#define IDirectPlay3_GetPlayerAddress(p,a,b,c)     (p)->GetPlayerAddress(a,b,c)
#define IDirectPlay3_GetPlayerCaps(p,a,b,c)        (p)->GetPlayerCaps(a,b,c)
#define IDirectPlay3_GetPlayerData(p,a,b,c,d)      (p)->GetPlayerData(a,b,c,d)
#define IDirectPlay3_GetPlayerName(p,a,b,c)        (p)->GetPlayerName(a,b,c)
#define IDirectPlay3_GetSessionDesc(p,a,b)         (p)->GetSessionDesc(a,b)
#define IDirectPlay3_Initialize(p,a)               (p)->Initialize(a)
#define IDirectPlay3_Open(p,a,b)                   (p)->Open(a,b)
#define IDirectPlay3_Receive(p,a,b,c,d,e)          (p)->Receive(a,b,c,d,e)
#define IDirectPlay3_Send(p,a,b,c,d,e)             (p)->Send(a,b,c,d,e)
#define IDirectPlay3_SetGroupData(p,a,b,c,d)       (p)->SetGroupData(a,b,c,d)
#define IDirectPlay3_SetGroupName(p,a,b,c)         (p)->SetGroupName(a,b,c)
#define IDirectPlay3_SetPlayerData(p,a,b,c,d)      (p)->SetPlayerData(a,b,c,d)
#define IDirectPlay3_SetPlayerName(p,a,b,c)        (p)->SetPlayerName(a,b,c)
#define IDirectPlay3_SetSessionDesc(p,a,b)         (p)->SetSessionDesc(a,b)
/*** IDirectPlay3 methods ***/
#define IDirectPlay3_AddGroupToGroup(p,a,b)                (p)->AddGroupToGroup(a,b)
#define IDirectPlay3_CreateGroupInGroup(p,a,b,c,d,e,f)     (p)->CreateGroupInGroup(a,b,c,d,e,f)
#define IDirectPlay3_DeleteGroupFromGroup(p,a,b)           (p)->DeleteGroupFromGroup(a,b)
#define IDirectPlay3_EnumConnections(p,a,b,c,d)            (p)->EnumConnections(a,b,c,d)
#define IDirectPlay3_EnumGroupsInGroup(p,a,b,c,d,e)        (p)->EnumGroupsInGroup(a,b,c,d,e)
#define IDirectPlay3_GetGroupConnectionSettings(p,a,b,c,d) (p)->GetGroupConnectionSettings(a,b,c,d)
#define IDirectPlay3_InitializeConnection(p,a,b)           (p)->InitializeConnection(a,b)
#define IDirectPlay3_SecureOpen(p,a,b,c,d)                 (p)->SecureOpen(a,b,c,d)
#define IDirectPlay3_SendChatMessage(p,a,b,c,d)            (p)->SendChatMessage(a,b,c,d)
#define IDirectPlay3_SetGroupConnectionSettings(p,a,b,c)   (p)->SetGroupConnectionSettings(a,b,c)
#define IDirectPlay3_StartSession(p,a,b)                   (p)->StartSession(a,b)
#define IDirectPlay3_GetGroupFlags(p,a,b)                  (p)->GetGroupFlags(a,b)
#define IDirectPlay3_GetGroupParent(p,a,b)                 (p)->GetGroupParent(a,b)
#define IDirectPlay3_GetPlayerAccount(p,a,b,c,d)           (p)->GetPlayerAccount(a,b,c,d)
#define IDirectPlay3_GetPlayerFlags(p,a,b)                 (p)->GetPlayerFlags(a,b)
#endif

/*****************************************************************************
 * IDirectPlay4 and IDirectPlay4A interface
 */
#define INTERFACE IDirectPlay4
DECLARE_INTERFACE_(IDirectPlay4,IDirectPlay3)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay2 methods ***/
    STDMETHOD(AddPlayerToGroup)(THIS_ DPID idGroup, DPID idPlayer) PURE;
    STDMETHOD(Close)(THIS) PURE;
    STDMETHOD(CreateGroup)(THIS_ LPDPID lpidGroup, LPDPNAME lpGroupName, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(CreatePlayer)(THIS_ LPDPID lpidPlayer, LPDPNAME lpPlayerName, HANDLE hEvent, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(DeletePlayerFromGroup)(THIS_ DPID idGroup, DPID idPlayer) PURE;
    STDMETHOD(DestroyGroup)(THIS_ DPID idGroup) PURE;
    STDMETHOD(DestroyPlayer)(THIS_ DPID idPlayer) PURE;
    STDMETHOD(EnumGroupPlayers)(THIS_ DPID idGroup, LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumGroups)(THIS_ LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumPlayers)(THIS_ LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumPlayersCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumSessions)(THIS_ LPDPSESSIONDESC2 lpsd, DWORD dwTimeout, LPDPENUMSESSIONSCALLBACK2 lpEnumSessionsCallback2, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(GetCaps)(THIS_ LPDPCAPS lpDPCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupData)(THIS_ DPID idGroup, LPVOID lpData, LPDWORD lpdwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupName)(THIS_ DPID idGroup, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetMessageCount)(THIS_ DPID idPlayer, LPDWORD lpdwCount) PURE;
    STDMETHOD(GetPlayerAddress)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetPlayerCaps)(THIS_ DPID idPlayer, LPDPCAPS lpPlayerCaps, DWORD dwFlags) PURE;
    STDMETHOD(GetPlayerData)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(GetPlayerName)(THIS_ DPID idPlayer, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetSessionDesc)(THIS_ LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(Initialize)(THIS_ LPGUID lpGUID) PURE;
    STDMETHOD(Open)(THIS_ LPDPSESSIONDESC2 lpsd, DWORD dwFlags) PURE;
    STDMETHOD(Receive)(THIS_ LPDPID lpidFrom, LPDPID lpidTo, DWORD dwFlags, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(Send)(THIS_ DPID idFrom, DPID idTo, DWORD dwFlags, LPVOID lpData, DWORD dwDataSize) PURE;
    STDMETHOD(SetGroupData)(THIS_ DPID idGroup, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetGroupName)(THIS_ DPID idGroup, LPDPNAME lpGroupName, DWORD dwFlags) PURE;
    STDMETHOD(SetPlayerData)(THIS_ DPID idPlayer, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(SetPlayerName)(THIS_ DPID idPlayer, LPDPNAME lpPlayerName, DWORD dwFlags) PURE;
    STDMETHOD(SetSessionDesc)(THIS_ LPDPSESSIONDESC2 lpSessDesc, DWORD dwFlags) PURE;
    /*** IDirectPlay3 methods ***/
    STDMETHOD(AddGroupToGroup)(THIS_ DPID idParentGroup, DPID idGroup) PURE;
    STDMETHOD(CreateGroupInGroup)(THIS_ DPID idParentGroup, LPDPID lpidGroup, LPDPNAME lpGroupName, LPVOID lpData, DWORD dwDataSize, DWORD dwFlags) PURE;
    STDMETHOD(DeleteGroupFromGroup)(THIS_ DPID idParentGroup, DPID idGroup) PURE;
    STDMETHOD(EnumConnections)(THIS_ LPCGUID lpguidApplication, LPDPENUMCONNECTIONSCALLBACK lpEnumCallback, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(EnumGroupsInGroup)(THIS_ DPID idGroup, LPGUID lpguidInstance, LPDPENUMPLAYERSCALLBACK2 lpEnumCallback, LPVOID lpContext, DWORD dwFlags) PURE;
    STDMETHOD(GetGroupConnectionSettings)(THIS_ DWORD dwFlags, DPID idGroup, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(InitializeConnection)(THIS_ LPVOID lpConnection, DWORD dwFlags) PURE;
    STDMETHOD(SecureOpen)(THIS_ LPCDPSESSIONDESC2 lpsd, DWORD dwFlags, LPCDPSECURITYDESC lpSecurity, LPCDPCREDENTIALS lpCredentials) PURE;
    STDMETHOD(SendChatMessage)(THIS_ DPID idFrom, DPID idTo, DWORD dwFlags, LPDPCHAT lpChatMessage) PURE;
    STDMETHOD(SetGroupConnectionSettings)(THIS_ DWORD dwFlags, DPID idGroup, LPDPLCONNECTION lpConnection) PURE;
    STDMETHOD(StartSession)(THIS_ DWORD dwFlags, DPID idGroup) PURE;
    STDMETHOD(GetGroupFlags)(THIS_ DPID idGroup, LPDWORD lpdwFlags) PURE;
    STDMETHOD(GetGroupParent)(THIS_ DPID idGroup, LPDPID lpidParent) PURE;
    STDMETHOD(GetPlayerAccount)(THIS_ DPID idPlayer, DWORD dwFlags, LPVOID lpData, LPDWORD lpdwDataSize) PURE;
    STDMETHOD(GetPlayerFlags)(THIS_ DPID idPlayer, LPDWORD lpdwFlags) PURE;
    /*** IDirectPlay4 methods ***/
    STDMETHOD(GetGroupOwner)(THIS_ DPID , LPDPID  ) PURE;
    STDMETHOD(SetGroupOwner)(THIS_ DPID , DPID  ) PURE;
    STDMETHOD(SendEx)(THIS_ DPID , DPID , DWORD , LPVOID , DWORD , DWORD , DWORD , LPVOID , LPDWORD  ) PURE;
    STDMETHOD(GetMessageQueue)(THIS_ DPID , DPID , DWORD , LPDWORD , LPDWORD  ) PURE;
    STDMETHOD(CancelMessage)(THIS_ DWORD , DWORD  ) PURE;
    STDMETHOD(CancelPriority)(THIS_ DWORD , DWORD , DWORD  ) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlayX_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlayX_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectPlayX_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectPlay2 methods ***/
#define IDirectPlayX_AddPlayerToGroup(p,a,b)       (p)->lpVtbl->AddPlayerToGroup(p,a,b)
#define IDirectPlayX_Close(p)                      (p)->lpVtbl->Close(p)
#define IDirectPlayX_CreateGroup(p,a,b,c,d,e)      (p)->lpVtbl->CreateGroup(p,a,b,c,d,e)
#define IDirectPlayX_CreatePlayer(p,a,b,c,d,e,f)   (p)->lpVtbl->CreatePlayer(p,a,b,c,d,e,f)
#define IDirectPlayX_DeletePlayerFromGroup(p,a,b)  (p)->lpVtbl->DeletePlayerFromGroup(p,a,b)
#define IDirectPlayX_DestroyGroup(p,a)             (p)->lpVtbl->DestroyGroup(p,a)
#define IDirectPlayX_DestroyPlayer(p,a)            (p)->lpVtbl->DestroyPlayer(p,a)
#define IDirectPlayX_EnumGroupPlayers(p,a,b,c,d,e) (p)->lpVtbl->EnumGroupPlayers(p,a,b,c,d,e)
#define IDirectPlayX_EnumGroups(p,a,b,c,d)         (p)->lpVtbl->EnumGroups(p,a,b,c,d)
#define IDirectPlayX_EnumPlayers(p,a,b,c,d)        (p)->lpVtbl->EnumPlayers(p,a,b,c,d)
#define IDirectPlayX_EnumSessions(p,a,b,c,d,e)     (p)->lpVtbl->EnumSessions(p,a,b,c,d,e)
#define IDirectPlayX_GetCaps(p,a,b)                (p)->lpVtbl->GetCaps(p,a,b)
#define IDirectPlayX_GetGroupData(p,a,b,c,d)       (p)->lpVtbl->GetGroupData(p,a,b,c,d)
#define IDirectPlayX_GetGroupName(p,a,b,c)         (p)->lpVtbl->GetGroupName(p,a,b,c)
#define IDirectPlayX_GetMessageCount(p,a,b)        (p)->lpVtbl->GetMessageCount(p,a,b)
#define IDirectPlayX_GetPlayerAddress(p,a,b,c)     (p)->lpVtbl->GetPlayerAddress(p,a,b,c)
#define IDirectPlayX_GetPlayerCaps(p,a,b,c)        (p)->lpVtbl->GetPlayerCaps(p,a,b,c)
#define IDirectPlayX_GetPlayerData(p,a,b,c,d)      (p)->lpVtbl->GetPlayerData(p,a,b,c,d)
#define IDirectPlayX_GetPlayerName(p,a,b,c)        (p)->lpVtbl->GetPlayerName(p,a,b,c)
#define IDirectPlayX_GetSessionDesc(p,a,b)         (p)->lpVtbl->GetSessionDesc(p,a,b)
#define IDirectPlayX_Initialize(p,a)               (p)->lpVtbl->Initialize(p,a)
#define IDirectPlayX_Open(p,a,b)                   (p)->lpVtbl->Open(p,a,b)
#define IDirectPlayX_Receive(p,a,b,c,d,e)          (p)->lpVtbl->Receive(p,a,b,c,d,e)
#define IDirectPlayX_Send(p,a,b,c,d,e)             (p)->lpVtbl->Send(p,a,b,c,d,e)
#define IDirectPlayX_SetGroupData(p,a,b,c,d)       (p)->lpVtbl->SetGroupData(p,a,b,c,d)
#define IDirectPlayX_SetGroupName(p,a,b,c)         (p)->lpVtbl->SetGroupName(p,a,b,c)
#define IDirectPlayX_SetPlayerData(p,a,b,c,d)      (p)->lpVtbl->SetPlayerData(p,a,b,c,d)
#define IDirectPlayX_SetPlayerName(p,a,b,c)        (p)->lpVtbl->SetPlayerName(p,a,b,c)
#define IDirectPlayX_SetSessionDesc(p,a,b)         (p)->lpVtbl->SetSessionDesc(p,a,b)
/*** IDirectPlay3 methods ***/
#define IDirectPlayX_AddGroupToGroup(p,a,b)                (p)->lpVtbl->AddGroupToGroup(p,a,b)
#define IDirectPlayX_CreateGroupInGroup(p,a,b,c,d,e,f)     (p)->lpVtbl->CreateGroupInGroup(p,a,b,c,d,e,f)
#define IDirectPlayX_DeleteGroupFromGroup(p,a,b)           (p)->lpVtbl->DeleteGroupFromGroup(p,a,b)
#define IDirectPlayX_EnumConnections(p,a,b,c,d)            (p)->lpVtbl->EnumConnections(p,a,b,c,d)
#define IDirectPlayX_EnumGroupsInGroup(p,a,b,c,d,e)        (p)->lpVtbl->EnumGroupsInGroup(p,a,b,c,d,e)
#define IDirectPlayX_GetGroupConnectionSettings(p,a,b,c,d) (p)->lpVtbl->GetGroupConnectionSettings(p,a,b,c,d)
#define IDirectPlayX_InitializeConnection(p,a,b)           (p)->lpVtbl->InitializeConnection(p,a,b)
#define IDirectPlayX_SecureOpen(p,a,b,c,d)                 (p)->lpVtbl->SecureOpen(p,a,b,c,d)
#define IDirectPlayX_SendChatMessage(p,a,b,c,d)            (p)->lpVtbl->SendChatMessage(p,a,b,c,d)
#define IDirectPlayX_SetGroupConnectionSettings(p,a,b,c)   (p)->lpVtbl->SetGroupConnectionSettings(p,a,b,c)
#define IDirectPlayX_StartSession(p,a,b)                   (p)->lpVtbl->StartSession(p,a,b)
#define IDirectPlayX_GetGroupFlags(p,a,b)                  (p)->lpVtbl->GetGroupFlags(p,a,b)
#define IDirectPlayX_GetGroupParent(p,a,b)                 (p)->lpVtbl->GetGroupParent(p,a,b)
#define IDirectPlayX_GetPlayerAccount(p,a,b,c,d)           (p)->lpVtbl->GetPlayerAccount(p,a,b,c,d)
#define IDirectPlayX_GetPlayerFlags(p,a,b)                 (p)->lpVtbl->GetPlayerFlags(p,a,b)
/*** IDirectPlay4 methods ***/
#define IDirectPlayX_GetGroupOwner(p,a,b)                  (p)->lpVtbl->GetGroupOwner(p,a,b)
#define IDirectPlayX_SetGroupOwner(p,a,b)                  (p)->lpVtbl->SetGroupOwner(p,a,b)
#define IDirectPlayX_SendEx(p,a,b,c,d,e,f,g,h,i)           (p)->lpVtbl->SendEx(p,a,b,c,d,e,f,g,h,i)
#define IDirectPlayX_GetMessageQueue(p,a,b,c,d,e)          (p)->lpVtbl->GetMessageQueue(p,a,b,c,d,e)
#define IDirectPlayX_CancelMessage(p,a,b)                  (p)->lpVtbl->CancelMessage(p,a,b)
#define IDirectPlayX_CancelPriority(p,a,b,c)               (p)->lpVtbl->CancelPriority(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirectPlayX_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectPlayX_AddRef(p)             (p)->AddRef()
#define IDirectPlayX_Release(p)            (p)->Release()
/*** IDirectPlay2 methods ***/
#define IDirectPlayX_AddPlayerToGroup(p,a,b)       (p)->AddPlayerToGroup(a,b)
#define IDirectPlayX_Close(p)                      (p)->Close()
#define IDirectPlayX_CreateGroup(p,a,b,c,d,e)      (p)->CreateGroup(a,b,c,d,e)
#define IDirectPlayX_CreatePlayer(p,a,b,c,d,e,f)   (p)->CreatePlayer(a,b,c,d,e,f)
#define IDirectPlayX_DeletePlayerFromGroup(p,a,b)  (p)->DeletePlayerFromGroup(a,b)
#define IDirectPlayX_DestroyGroup(p,a)             (p)->DestroyGroup(a)
#define IDirectPlayX_DestroyPlayer(p,a)            (p)->DestroyPlayer(a)
#define IDirectPlayX_EnumGroupPlayers(p,a,b,c,d,e) (p)->EnumGroupPlayers(a,b,c,d,e)
#define IDirectPlayX_EnumGroups(p,a,b,c,d)         (p)->EnumGroups(a,b,c,d)
#define IDirectPlayX_EnumPlayers(p,a,b,c,d)        (p)->EnumPlayers(a,b,c,d)
#define IDirectPlayX_EnumSessions(p,a,b,c,d,e)     (p)->EnumSessions(a,b,c,d,e)
#define IDirectPlayX_GetCaps(p,a,b)                (p)->GetCaps(a,b)
#define IDirectPlayX_GetGroupData(p,a,b,c,d)       (p)->GetGroupData(a,b,c,d)
#define IDirectPlayX_GetGroupName(p,a,b,c)         (p)->GetGroupName(a,b,c)
#define IDirectPlayX_GetMessageCount(p,a,b)        (p)->GetMessageCount(a,b)
#define IDirectPlayX_GetPlayerAddress(p,a,b,c)     (p)->GetPlayerAddress(a,b,c)
#define IDirectPlayX_GetPlayerCaps(p,a,b,c)        (p)->GetPlayerCaps(a,b,c)
#define IDirectPlayX_GetPlayerData(p,a,b,c,d)      (p)->GetPlayerData(a,b,c,d)
#define IDirectPlayX_GetPlayerName(p,a,b,c)        (p)->GetPlayerName(a,b,c)
#define IDirectPlayX_GetSessionDesc(p,a,b)         (p)->GetSessionDesc(a,b)
#define IDirectPlayX_Initialize(p,a)               (p)->Initialize(a)
#define IDirectPlayX_Open(p,a,b)                   (p)->Open(a,b)
#define IDirectPlayX_Receive(p,a,b,c,d,e)          (p)->Receive(a,b,c,d,e)
#define IDirectPlayX_Send(p,a,b,c,d,e)             (p)->Send(a,b,c,d,e)
#define IDirectPlayX_SetGroupData(p,a,b,c,d)       (p)->SetGroupData(a,b,c,d)
#define IDirectPlayX_SetGroupName(p,a,b,c)         (p)->SetGroupName(a,b,c)
#define IDirectPlayX_SetPlayerData(p,a,b,c,d)      (p)->SetPlayerData(a,b,c,d)
#define IDirectPlayX_SetPlayerName(p,a,b,c)        (p)->SetPlayerName(a,b,c)
#define IDirectPlayX_SetSessionDesc(p,a,b)         (p)->SetSessionDesc(a,b)
/*** IDirectPlay3 methods ***/
#define IDirectPlayX_AddGroupToGroup(p,a,b)                (p)->AddGroupToGroup(a,b)
#define IDirectPlayX_CreateGroupInGroup(p,a,b,c,d,e,f)     (p)->CreateGroupInGroup(a,b,c,d,e,f)
#define IDirectPlayX_DeleteGroupFromGroup(p,a,b)           (p)->DeleteGroupFromGroup(a,b)
#define IDirectPlayX_EnumConnections(p,a,b,c,d)            (p)->EnumConnections(a,b,c,d)
#define IDirectPlayX_EnumGroupsInGroup(p,a,b,c,d,e)        (p)->EnumGroupsInGroup(a,b,c,d,e)
#define IDirectPlayX_GetGroupConnectionSettings(p,a,b,c,d) (p)->GetGroupConnectionSettings(a,b,c,d)
#define IDirectPlayX_InitializeConnection(p,a,b)           (p)->InitializeConnection(a,b)
#define IDirectPlayX_SecureOpen(p,a,b,c,d)                 (p)->SecureOpen(a,b,c,d)
#define IDirectPlayX_SendChatMessage(p,a,b,c,d)            (p)->SendChatMessage(a,b,c,d)
#define IDirectPlayX_SetGroupConnectionSettings(p,a,b,c)   (p)->SetGroupConnectionSettings(a,b,c)
#define IDirectPlayX_StartSession(p,a,b)                   (p)->StartSession(a,b)
#define IDirectPlayX_GetGroupFlags(p,a,b)                  (p)->GetGroupFlags(a,b)
#define IDirectPlayX_GetGroupParent(p,a,b)                 (p)->GetGroupParent(a,b)
#define IDirectPlayX_GetPlayerAccount(p,a,b,c,d)           (p)->GetPlayerAccount(a,b,c,d)
#define IDirectPlayX_GetPlayerFlags(p,a,b)                 (p)->GetPlayerFlags(a,b)
/*** IDirectPlay4 methods ***/
#define IDirectPlayX_GetGroupOwner(p,a,b)                  (p)->GetGroupOwner(a,b)
#define IDirectPlayX_SetGroupOwner(p,a,b)                  (p)->SetGroupOwner(a,b)
#define IDirectPlayX_SendEx(p,a,b,c,d,e,f,g,h,i)           (p)->SendEx(a,b,c,d,e,f,g,h,i)
#define IDirectPlayX_GetMessageQueue(p,a,b,c,d,e)          (p)->GetMessageQueue(a,b,c,d,e)
#define IDirectPlayX_CancelMessage(p,a,b)                  (p)->CancelMessage(a,b)
#define IDirectPlayX_CancelPriority(p,a,b,c)               (p)->CancelPriority(a,b,c)
#endif


/* For DirectPlay::EnumConnections */
#define DPCONNECTION_DIRECTPLAY      0x00000001
#define DPCONNECTION_DIRECTPLAYLOBBY 0x00000002

/* For DirectPlay::EnumPlayers and DirectPlay::EnumGroups */
#define DPENUMPLAYERS_ALL           0x00000000
#define DPENUMPLAYERS_LOCAL         0x00000008
#define DPENUMPLAYERS_REMOTE        0x00000010
#define DPENUMPLAYERS_GROUP         0x00000020
#define DPENUMPLAYERS_SESSION       0x00000080
#define DPENUMPLAYERS_SERVERPLAYER  0x00000100
#define DPENUMPLAYERS_SPECTATOR     0x00000200
#define DPENUMPLAYERS_OWNER         0x00002000

#define DPENUMGROUPS_ALL            DPENUMPLAYERS_ALL
#define DPENUMGROUPS_LOCAL          DPENUMPLAYERS_LOCAL
#define DPENUMGROUPS_REMOTE         DPENUMPLAYERS_REMOTE
#define DPENUMGROUPS_SESSION        DPENUMPLAYERS_SESSION
#define DPENUMGROUPS_SHORTCUT       0x00000400
#define DPENUMGROUPS_STAGINGAREA    0x00000800
#define DPENUMGROUPS_HIDDEN         0x00001000


/* For DirectPlay::CreatePlayer */
#define DPPLAYER_SERVERPLAYER  DPENUMPLAYERS_SERVERPLAYER
#define DPPLAYER_SPECTATOR     DPENUMPLAYERS_SPECTATOR
#define DPPLAYER_LOCAL         DPENUMPLAYERS_LOCAL
#define DPPLAYER_OWNER         DPENUMPLAYERS_OWNER

/* For DirectPlay::CreateGroup */
#define DPGROUP_STAGINGAREA  DPENUMGROUPS_STAGINGAREA
#define DPGROUP_LOCAL        DPENUMGROUPS_LOCAL
#define DPGROUP_HIDDEN       DPENUMGROUPS_HIDDEN

/* For DirectPlay::EnumSessions */
#define DPENUMSESSIONS_AVAILABLE         0x00000001
#define DPENUMSESSIONS_ALL               0x00000002
#define DPENUMSESSIONS_ASYNC             0x00000010
#define DPENUMSESSIONS_STOPASYNC         0x00000020
#define DPENUMSESSIONS_PASSWORDREQUIRED  0x00000040
#define DPENUMSESSIONS_RETURNSTATUS      0x00000080

/* For DirectPlay::GetCaps and DirectPlay::GetPlayerCaps */
#define DPGETCAPS_GUARANTEED  0x00000001

/* For DirectPlay::GetGroupData and DirectPlay::GetPlayerData */
#define DPGET_REMOTE  0x00000000
#define DPGET_LOCAL   0x00000001

/* For DirectPlay::Receive */
#define DPRECEIVE_ALL         0x00000001
#define DPRECEIVE_TOPLAYER    0x00000002
#define DPRECEIVE_FROMPLAYER  0x00000004
#define DPRECEIVE_PEEK        0x00000008

/* For DirectPlay::Send */
#define DPSEND_NONGUARANTEED       0x00000000
#define DPSEND_GUARANTEED          0x00000001
#define DPSEND_HIGHPRIORITY        0x00000002
#define DPSEND_OPENSTREAM          0x00000008
#define DPSEND_CLOSESTREAM         0x00000010
#define DPSEND_SIGNED              0x00000020
#define DPSEND_ENCRYPTED           0x00000040
#define DPSEND_LOBBYSYSTEMMESSAGE  0x00000080
#define DPSEND_ASYNC               0x00000200
#define DPSEND_NOSENDCOMPLETEMSG   0x00000400

#define DPSEND_MAX_PRI       0x0000FFFF
#define DPSEND_MAX_PRIORITY  DPSEND_MAX_PRI


/* For  DirectPlay::SetGroupData, DirectPlay::SetGroupName,
 * DirectPlay::SetPlayerData, DirectPlay::SetPlayerName and
 * DirectPlay::SetSessionDesc.
 */
#define DPSET_REMOTE      0x00000000
#define DPSET_LOCAL       0x00000001
#define DPSET_GUARANTEED  0x00000002

/* For DirectPlay::GetMessageQueue */
#define DPMESSAGEQUEUE_SEND    0x00000001
#define DPMESSAGEQUEUE_RECEIVE 0x00000002

/* DirectPlay::Connect */
#define DPCONNECT_RETURNSTATUS  (DPENUMSESSIONS_RETURNSTATUS)

/* DirectPlay::GetCaps and DirectPlay::GetPlayerCaps */
#define DPCAPS_ISHOST                  0x00000002
#define DPCAPS_GROUPOPTIMIZED          0x00000008
#define DPCAPS_KEEPALIVEOPTIMIZED      0x00000010
#define DPCAPS_GUARANTEEDOPTIMIZED     0x00000020
#define DPCAPS_GUARANTEEDSUPPORTED     0x00000040
#define DPCAPS_SIGNINGSUPPORTED        0x00000080
#define DPCAPS_ENCRYPTIONSUPPORTED     0x00000100
#define DPPLAYERCAPS_LOCAL             0x00000800
#define DPCAPS_ASYNCCANCELSUPPORTED    0x00001000
#define DPCAPS_ASYNCCANCELALLSUPPORTED 0x00002000
#define DPCAPS_SENDTIMEOUTSUPPORTED    0x00004000
#define DPCAPS_SENDPRIORITYSUPPORTED   0x00008000
#define DPCAPS_ASYNCSUPPORTED          0x00010000

/** DirectPlay system messages **/

/* A new player or group has been created in the session */
#define DPSYS_CREATEPLAYERORGROUP   0x0003

/* A player or group has been deleted from the session */
#define DPSYS_DESTROYPLAYERORGROUP  0x0005

/* A player has been added to a group */
#define DPSYS_ADDPLAYERTOGROUP      0x0007

/* A player has been deleted from a group */
#define DPSYS_DELETEPLAYERFROMGROUP 0x0021

/* Session lost for this object - ie lost contact with all players */
#define DPSYS_SESSIONLOST           0x0031

/* The current host has left the session */
#define DPSYS_HOST                  0x0101

/* Player or group data has changed */
#define DPSYS_SETPLAYERORGROUPDATA  0x0102

/* The name of a player or group has changed */
#define DPSYS_SETPLAYERORGROUPNAME  0x0103

/* The session description has changed */
#define DPSYS_SETSESSIONDESC        0x0104

/* A group has been added to a group */
#define DPSYS_ADDGROUPTOGROUP           0x0105

/* A group has been deleted from a group */
#define DPSYS_DELETEGROUPFROMGROUP      0x0106

/* A secure player to player message has arrived */
#define DPSYS_SECUREMESSAGE         0x0107

/* Start a new session */
#define DPSYS_STARTSESSION          0x0108

/* A chat message has arrived */
#define DPSYS_CHAT                  0x0109

/* The owner of a group has changed */
#define DPSYS_SETGROUPOWNER         0x010A

/* An async send is done (finished normally, failed or cancelled) */
#define DPSYS_SENDCOMPLETE          0x010d

/** DirectPlay System Messages **/

#define DPPLAYERTYPE_GROUP   0x00000000
#define DPPLAYERTYPE_PLAYER  0x00000001


/* NOTE: DPMSG_HOST and DPMSG_GENERIC share the same format */
typedef struct tagDPMSG_GENERIC
{
   DWORD       dwType; /* Use message type as described above */
} DPMSG_GENERIC,     *LPDPMSG_GENERIC,
  DPMSG_HOST,        *LPDPMSG_HOST,
  DPMSG_SESSIONLOST, *LPDPMSG_SESSIONLOST;

typedef struct tagDPMSG_CREATEPLAYERORGROUP
{
   DWORD   dwType;           /* Use message type as described above */
   DWORD   dwPlayerType;     /* Use DPPLAYERTYPE_GROUP or DPPLAYERTYPE_PLAYER */
   DPID    dpId;             /* ID of the player/group */
   DWORD   dwCurrentPlayers; /* Current number of players/groups in session */
   LPVOID  lpData;           /* Pointer to data */
   DWORD   dwDataSize;       /* Size of data */
   DPNAME  dpnName;          /* Name info */

   /* dpIdParent and dwFlags are only valid in DirectPlay3 and later. What
    * does that mean about the message size before? -PH */
   DPID   dpIdParent;  /* id of parent group */
   DWORD  dwFlags;     /* Flags for the player/group */
} DPMSG_CREATEPLAYERORGROUP, *LPDPMSG_CREATEPLAYERORGROUP;

typedef struct tagDPMSG_DESTROYPLAYERORGROUP
{
   DWORD   dwType;           /* Use message type as described above */
   DWORD   dwPlayerType;     /* Use DPPLAYERTYPE_GROUP or DPPLAYERTYPE_PLAYER */
   DPID    dpId;             /* ID of player/group to be deleted */
   LPVOID  lpLocalData;      /* Pointer to local data */
   DWORD   dwLocalDataSize;  /* Sizeof local data */
   LPVOID  lpRemoteData;     /* Pointer to remote data */
   DWORD   dwRemoteDataSize; /* Sizeof remote data */

   /* dpnName, dpIdParent and dwFlags are only valid in DirectPlay3 and later. What
    * does that mean about the message size before? -PH */
   DPNAME  dpnName;     /* Name info */
   DPID    dpIdParent;  /* id of parent group */
   DWORD   dwFlags;     /* Flags for the player/group */
} DPMSG_DESTROYPLAYERORGROUP, *LPDPMSG_DESTROYPLAYERORGROUP;

/* NOTE: DPMSG_ADDPLAYERTOGROUP and DPMSG_DELETEPLAYERFROMGROUP are the same */
typedef struct tagDPMSG_ADDPLAYERTOGROUP
{
   DWORD  dwType;      /* Use message type as described above */
   DPID   dpIdGroup;   /* Group ID to add player into */
   DPID   dpIdPlayer;  /* ID of player to add */
} DPMSG_ADDPLAYERTOGROUP,      *LPDPMSG_ADDPLAYERTOGROUP,
  DPMSG_DELETEPLAYERFROMGROUP, *LPDPMSG_DELETEPLAYERFROMGROUP;

/* NOTE: DPMSG_ADDGROUPTOGROUP and DPMSG_DELETEGROUPFROMGROUP are the same */
typedef struct tagDPMSG_ADDGROUPTOGROUP
{
   DWORD  dwType;          /* Use message type as described above */
   DPID   dpIdParentGroup; /* Group ID to add group into */
   DPID   dpIdGroup;       /* ID of group to add */
} DPMSG_ADDGROUPTOGROUP,      *LPDPMSG_ADDGROUPTOGROUP,
  DPMSG_DELETEGROUPFROMGROUP, *LPDPMSG_DELETEGROUPFROMGROUP;

typedef struct tagDPMSG_SETPLAYERORGROUPDATA
{
   DWORD   dwType;       /* Use message type as described above */
   DWORD   dwPlayerType; /* Use DPPLAYERTYPE_GROUP or DPPLAYERTYPE_PLAYER */
   DPID    dpId;         /* ID of player/group */
   LPVOID  lpData;       /* Pointer to data */
   DWORD   dwDataSize;   /* Size of data */
} DPMSG_SETPLAYERORGROUPDATA, *LPDPMSG_SETPLAYERORGROUPDATA;

typedef struct tagDPMSG_SETPLAYERORGROUPNAME
{
   DWORD  dwType;       /* Use message type as described above */
   DWORD  dwPlayerType; /* Use DPPLAYERTYPE_GROUP or DPPLAYERTYPE_PLAYER */
   DPID   dpId;         /* ID of player/group */
   DPNAME dpnName;      /* New name */
} DPMSG_SETPLAYERORGROUPNAME, *LPDPMSG_SETPLAYERORGROUPNAME;

typedef struct tagDPMSG_SETSESSIONDESC
{
   DWORD           dwType; /* Use message type as described above */
   DPSESSIONDESC2  dpDesc; /* New session desc */
} DPMSG_SETSESSIONDESC, *LPDPMSG_SETSESSIONDESC;

typedef struct tagDPMSG_SECUREMESSAGE
{
   DWORD   dwType;     /* Use message type as described above */
   DWORD   dwFlags;    /* Signed/Encrypted */
   DPID    dpIdFrom;   /* ID of from player */
   LPVOID  lpData;     /* Message sent */
   DWORD   dwDataSize; /* Size of message */
} DPMSG_SECUREMESSAGE, *LPDPMSG_SECUREMESSAGE;

typedef struct tagDPMSG_STARTSESSION
{
   DWORD            dwType; /* Use message type as described above */
   LPDPLCONNECTION  lpConn; /* DPLCONNECTION structure */
} DPMSG_STARTSESSION, *LPDPMSG_STARTSESSION;

typedef struct tagDPMSG_CHAT
{
   DWORD     dwType;       /* Use message type as described above */
   DWORD     dwFlags;      /* Message flags */
   DPID      idFromPlayer; /* ID of sender */
   DPID      idToPlayer;   /* ID of who msg is for */
   DPID      idToGroup;    /* ID of what group msg is for */
   LPDPCHAT  lpChat;       /* Chat message */
} DPMSG_CHAT, *LPDPMSG_CHAT;

typedef struct tagDPMSG_SETGROUPOWNER
{
   DWORD  dwType;     /* Use message type as described above */
   DPID   idGroup;    /* Group ID */
   DPID   idNewOwner; /* ID of player who now owns group */
   DPID   idOldOwner; /* ID of player who used to own group */
} DPMSG_SETGROUPOWNER, *LPDPMSG_SETGROUPOWNER;

typedef struct
{
   DWORD    dwType;      /* Use message type as described above */
   DPID     idFrom;      /* ID from */
   DPID     idTo;        /* ID to */
   DWORD    dwFlags;
   DWORD    dwPriority;
   DWORD    dwTimeout;
   LPVOID   lpvContext;
   DWORD    dwMsgID;
   HRESULT  hr;
   DWORD    dwSendTime;  /* When sent ? */
} DPMSG_SENDCOMPLETE, *LPDPMSG_SENDCOMPLETE;



#ifdef __cplusplus
} /* extern "C" */
#endif /* defined(__cplusplus) */

#endif /* __WINE_DPLAY_H */
