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

#ifndef __WINE_DPLAY8_DPADDR_H
#define __WINE_DPLAY8_DPADDR_H

#include <ole2.h>
#include <dplay8.h>

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */

typedef REFIID	        DPNAREFIID;
#ifndef _WINSOCK2API_
typedef struct sockaddr SOCKADDR;
#endif

/*****************************************************************************
 * DirectPlay8Addr defines
 */
#define DPNA_DATATYPE_STRING                0x00000001
#define DPNA_DATATYPE_DWORD                 0x00000002
#define DPNA_DATATYPE_GUID                  0x00000003
#define DPNA_DATATYPE_BINARY                0x00000004
#define DPNA_DATATYPE_STRING_ANSI           0x00000005
#define DPNA_DPNSVR_PORT                          6073
#define DPNA_INDEX_INVALID                  0xFFFFFFFF

#define DPNA_SEPARATOR_KEYVALUE             L'='
#define DPNA_SEPARATOR_KEYVALUE_A           '='
#define DPNA_SEPARATOR_USERDATA             L'#'
#define DPNA_SEPARATOR_USERDATA_A           '#'
#define DPNA_SEPARATOR_COMPONENT            L';'
#define DPNA_SEPARATOR_COMPONENT_A          ';'
#define DPNA_ESCAPECHAR                     L'%'
#define DPNA_ESCAPECHAR_A                   '%'

#define DPNA_HEADER_A                       "x-directplay:/"
#define DPNA_KEY_APPLICATION_INSTANCE_A     "applicationinstance"
#define DPNA_KEY_BAUD_A                     "baud"
#define DPNA_KEY_DEVICE_A                   "device"
#define DPNA_KEY_FLOWCONTROL_A              "flowcontrol"
#define DPNA_KEY_HOSTNAME_A                 "hostname"
#define DPNA_KEY_NAMEINFO_A                 "nameinfo"
#define DPNA_KEY_PARITY_A                   "parity"
#define DPNA_KEY_PHONENUMBER_A              "phonenumber"
#define DPNA_KEY_PORT_A                     "port"
#define DPNA_KEY_PROCESSOR_A                "processor"
#define DPNA_KEY_PROGRAM_A                  "program"
#define DPNA_KEY_PROVIDER_A                 "provider"
#define DPNA_KEY_SCOPE_A                     "scope"
#define DPNA_KEY_STOPBITS_A                 "stopbits"
#define DPNA_KEY_TRAVERSALMODE_A             "traversalmode"

#define DPNA_STOP_BITS_ONE_A                "1"
#define DPNA_STOP_BITS_ONE_FIVE_A           "1.5"
#define DPNA_STOP_BITS_TWO_A                "2"
#define DPNA_PARITY_NONE_A                  "NONE"
#define DPNA_PARITY_EVEN_A                  "EVEN"
#define DPNA_PARITY_ODD_A                   "ODD"
#define DPNA_PARITY_MARK_A                  "MARK"
#define DPNA_PARITY_SPACE_A                 "SPACE"
#define DPNA_FLOW_CONTROL_NONE_A            "NONE"
#define DPNA_FLOW_CONTROL_XONXOFF_A         "XONXOFF"
#define DPNA_FLOW_CONTROL_RTS_A             "RTS"
#define DPNA_FLOW_CONTROL_DTR_A             "DTR"
#define DPNA_FLOW_CONTROL_RTSDTR_A          "RTSDTR"
#define DPNA_VALUE_TCPIPPROVIDER_A          "IP"
#define DPNA_VALUE_IPXPROVIDER_A            "IPX"
#define DPNA_VALUE_MODEMPROVIDER_A          "MODEM"
#define DPNA_VALUE_SERIALPROVIDER_A         "SERIAL"

/* And now the same thing but as Unicode strings */
#if defined(_MSC_VER) || defined(__MINGW32__)

# define DPNA_HEADER                   L"x-directplay:/"
# define DPNA_KEY_APPLICATION_INSTANCE L"applicationinstance"
# define DPNA_KEY_BAUD                 L"baud"
# define DPNA_KEY_DEVICE               L"device"
# define DPNA_KEY_FLOWCONTROL          L"flowcontrol"
# define DPNA_KEY_HOSTNAME             L"hostname"
# define DPNA_KEY_NAMEINFO             L"nameinfo"
# define DPNA_KEY_PARITY               L"parity"
# define DPNA_KEY_PHONENUMBER          L"phonenumber"
# define DPNA_KEY_PORT                 L"port"
# define DPNA_KEY_PROCESSOR            L"processor"
# define DPNA_KEY_PROGRAM              L"program"
# define DPNA_KEY_PROVIDER             L"provider"
# define DPNA_KEY_SCOPE                L"scope"
# define DPNA_KEY_STOPBITS             L"stopbits"
# define DPNA_KEY_TRAVERSALMODE        L"traversalmode"
# define DPNA_STOP_BITS_ONE            L"1"
# define DPNA_STOP_BITS_ONE_FIVE       L"1.5"
# define DPNA_STOP_BITS_TWO            L"2"
# define DPNA_PARITY_NONE              L"NONE"
# define DPNA_PARITY_EVEN              L"EVEN"
# define DPNA_PARITY_ODD               L"ODD"
# define DPNA_PARITY_MARK              L"MARK"
# define DPNA_PARITY_SPACE             L"SPACE"
# define DPNA_FLOW_CONTROL_NONE        L"NONE"
# define DPNA_FLOW_CONTROL_XONXOFF     L"XONXOFF"
# define DPNA_FLOW_CONTROL_RTS         L"RTS"
# define DPNA_FLOW_CONTROL_DTR         L"DTR"
# define DPNA_FLOW_CONTROL_RTSDTR      L"RTSDTR"
# define DPNA_VALUE_TCPIPPROVIDER      L"IP"
# define DPNA_VALUE_IPXPROVIDER        L"IPX"
# define DPNA_VALUE_MODEMPROVIDER      L"MODEM"
# define DPNA_VALUE_SERIALPROVIDER     L"SERIAL"

#else

static const WCHAR DPNA_HEADER[] = { 'x','-','d','i','r','e','c','t','p','l','a','y',':','/',0 };
static const WCHAR DPNA_KEY_APPLICATION_INSTANCE[] = { 'a','p','p','l','i','c','a','t','i','o','n','i','n','s','t','a','n','c','e',0 };
static const WCHAR DPNA_KEY_BAUD[] = { 'b','a','u','d',0 };
static const WCHAR DPNA_KEY_DEVICE[] = { 'd','e','v','i','c','e',0 };
static const WCHAR DPNA_KEY_FLOWCONTROL[] = { 'f','l','o','w','c','o','n','t','r','o','l',0 };
static const WCHAR DPNA_KEY_HOSTNAME[] = { 'h','o','s','t','n','a','m','e',0 };
static const WCHAR DPNA_KEY_NAMEINFO[] = { 'n','a','m','e','i','n','f','o',0 };
static const WCHAR DPNA_KEY_PARITY[] = { 'p','a','r','i','t','y',0 };
static const WCHAR DPNA_KEY_PHONENUMBER[] = { 'p','h','o','n','e','n','u','m','b','e','r',0 };
static const WCHAR DPNA_KEY_PORT[] =   { 'p','o','r','t',0 };
static const WCHAR DPNA_KEY_PROCESSOR[] = { 'p','r','o','c','e','s','s','o','r',0 };
static const WCHAR DPNA_KEY_PROGRAM[] = { 'p','r','o','g','r','a','m',0 };
static const WCHAR DPNA_KEY_PROVIDER[] = { 'p','r','o','v','i','d','e','r',0 };
static const WCHAR DPNA_KEY_SCOPE[] = { 's','c','o','p','e',0 };
static const WCHAR DPNA_KEY_STOPBITS[] = { 's','t','o','p','b','i','t','s',0 };
static const WCHAR DPNA_KEY_TRAVERSALMODE[] = { 't','r','a','v','e','r','s','a','l','m','o','d','e',0 };
static const WCHAR DPNA_STOP_BITS_ONE[] = { '1',0 };
static const WCHAR DPNA_STOP_BITS_ONE_FIVE[] = { '1','.','5',0 };
static const WCHAR DPNA_STOP_BITS_TWO[] = { '2',0 };
static const WCHAR DPNA_PARITY_NONE[] = { 'N','O','N','E',0 };
static const WCHAR DPNA_PARITY_EVEN[] = { 'E','V','E','N',0 };
static const WCHAR DPNA_PARITY_ODD[] = { 'O','D','D',0 };
static const WCHAR DPNA_PARITY_MARK[] = { 'M','A','R','K',0 };
static const WCHAR DPNA_PARITY_SPACE[] = { 'S','P','A','C','E',0 };
static const WCHAR DPNA_FLOW_CONTROL_NONE[] = { 'N','O','N','E',0 };
static const WCHAR DPNA_FLOW_CONTROL_XONXOFF[] = { 'X','O','N','X','O','F','F',0 };
static const WCHAR DPNA_FLOW_CONTROL_RTS[] = { 'R','T','S',0 };
static const WCHAR DPNA_FLOW_CONTROL_DTR[] = { 'D','T','R',0 };
static const WCHAR DPNA_FLOW_CONTROL_RTSDTR[] = { 'R','T','S','D','T','R',0 };
static const WCHAR DPNA_VALUE_TCPIPPROVIDER[] = { 'I','P',0 };
static const WCHAR DPNA_VALUE_IPXPROVIDER[] = { 'I','P','X',0 };
static const WCHAR DPNA_VALUE_MODEMPROVIDER[] = { 'M','O','D','E','M',0 };
static const WCHAR DPNA_VALUE_SERIALPROVIDER[] = { 'S','E','R','I','A','L',0 };


#endif

#define DPNA_BAUD_RATE_9600                   9600
#define DPNA_BAUD_RATE_14400                 14400
#define DPNA_BAUD_RATE_19200                 19200
#define DPNA_BAUD_RATE_38400                 38400
#define DPNA_BAUD_RATE_56000                 56000
#define DPNA_BAUD_RATE_57600                 57600
#define DPNA_BAUD_RATE_115200               115200

/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(CLSID_DirectPlay8Address,      0x934a9523, 0xa3ca, 0x4bc5, 0xad, 0xa0, 0xd6, 0xd9, 0x5d, 0x97, 0x94, 0x21);

DEFINE_GUID(IID_IDirectPlay8Address,       0x83783300, 0x4063, 0x4c8a, 0x9d, 0xb3, 0x82, 0x83, 0xa, 0x7f, 0xeb, 0x31);
typedef struct IDirectPlay8Address *PDIRECTPLAY8ADDRESS, *LPDIRECTPLAY8ADDRESS;
DEFINE_GUID(IID_IDirectPlay8AddressIP,     0xe5a0e990, 0x2bad, 0x430b, 0x87, 0xda, 0xa1, 0x42, 0xcf, 0x75, 0xde, 0x58);
typedef struct IDirectPlay8AddressIP *PDIRECTPLAY8ADDRESSIP, *LPDIRECTPLAY8ADDRESSIP;


/*****************************************************************************
 * IDirectPlay8Address interface
 */
#define INTERFACE IDirectPlay8Address
DECLARE_INTERFACE_(IDirectPlay8Address,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8Address methods ***/
    STDMETHOD(BuildFromURLW)(THIS_ WCHAR* pwszSourceURL) PURE;
    STDMETHOD(BuildFromURLA)(THIS_ CHAR* pszSourceURL) PURE;
    STDMETHOD(Duplicate)(THIS_ PDIRECTPLAY8ADDRESS* ppdpaNewAddress) PURE;
    STDMETHOD(SetEqual)(THIS_ PDIRECTPLAY8ADDRESS pdpaAddress) PURE;
    STDMETHOD(IsEqual)(THIS_  PDIRECTPLAY8ADDRESS pdpaAddress) PURE;
    STDMETHOD(Clear)(THIS) PURE;
    STDMETHOD(GetURLW)(THIS_ WCHAR* pwszURL, PDWORD pdwNumChars) PURE;
    STDMETHOD(GetURLA)(THIS_ CHAR* pszURL, PDWORD pdwNumChars) PURE;
    STDMETHOD(GetSP)(THIS_ GUID* pguidSP) PURE;
    STDMETHOD(GetUserData)(THIS_ LPVOID pvUserData, PDWORD pdwBufferSize) PURE;
    STDMETHOD(SetSP)(THIS_ const GUID* pguidSP) PURE;
    STDMETHOD(SetUserData)(THIS_ const void* pvUserData, DWORD dwDataSize) PURE;
    STDMETHOD(GetNumComponents)(THIS_ PDWORD pdwNumComponents) PURE;
    STDMETHOD(GetComponentByName)(THIS_ const WCHAR* pwszName, LPVOID pvBuffer, PDWORD pdwBufferSize, PDWORD pdwDataType) PURE;
    STDMETHOD(GetComponentByIndex)(THIS_ DWORD dwComponentID, WCHAR* pwszName, PDWORD pdwNameLen, void* pvBuffer, PDWORD pdwBufferSize, PDWORD pdwDataType) PURE;
    STDMETHOD(AddComponent)(THIS_ const WCHAR* pwszName, const void* lpvData, DWORD dwDataSize, DWORD dwDataType) PURE;
    STDMETHOD(GetDevice)(THIS_ GUID* pDevGuid) PURE;
    STDMETHOD(SetDevice)(THIS_ const GUID* devGuid) PURE;
    STDMETHOD(BuildFromDirectPlay4Address)(THIS_ LPVOID pvAddress, DWORD dwDataSize) PURE;
};
#undef INTERFACE


#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlay8Address_QueryInterface(p,a,b)               (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlay8Address_AddRef(p)                           (p)->lpVtbl->AddRef(p)
#define IDirectPlay8Address_Release(p)                          (p)->lpVtbl->Release(p)
/*** IDirectPlay8Address methods ***/
#define IDirectPlay8Address_BuildFromURLW(p,a)                  (p)->lpVtbl->BuildFromURLW(p,a)
#define IDirectPlay8Address_BuildFromURLA(p,a)                  (p)->lpVtbl->BuildFromURLA(p,a)
#define IDirectPlay8Address_Duplicate(p,a)                      (p)->lpVtbl->Duplicate(p,a)
#define IDirectPlay8Address_SetEqual(p,a)                       (p)->lpVtbl->SetEqual(p,a)
#define IDirectPlay8Address_IsEqual(p,a)                        (p)->lpVtbl->IsEqual(p,a)
#define IDirectPlay8Address_Clear(p)                            (p)->lpVtbl->Clear(p)
#define IDirectPlay8Address_GetURLW(p,a,b)                      (p)->lpVtbl->GetURLW(p,a,b)
#define IDirectPlay8Address_GetURLA(p,a,b)                      (p)->lpVtbl->GetURLA(p,a,b)
#define IDirectPlay8Address_GetSP(p,a)                          (p)->lpVtbl->GetSP(p,a)
#define IDirectPlay8Address_GetUserData(p,a,b)                  (p)->lpVtbl->GetUserData(p,a,b)
#define IDirectPlay8Address_SetSP(p,a)                          (p)->lpVtbl->SetSP(p,a)
#define IDirectPlay8Address_SetUserData(p,a,b)                  (p)->lpVtbl->SetUserData(p,a,b)
#define IDirectPlay8Address_GetNumComponents(p,a)               (p)->lpVtbl->GetNumComponents(p,a)
#define IDirectPlay8Address_GetComponentByName(p,a,b,c,d)       (p)->lpVtbl->GetComponentByName(p,a,b,c,d)
#define IDirectPlay8Address_GetComponentByIndex(p,a,b,c,d,e,f)  (p)->lpVtbl->GetComponentByIndex(p,a,b,c,d,e,f)
#define IDirectPlay8Address_AddComponent(p,a,b,c,d)             (p)->lpVtbl->AddComponent(p,a,b,c,d)
#define IDirectPlay8Address_SetDevice(p,a)                      (p)->lpVtbl->SetDevice(p,a)
#define IDirectPlay8Address_GetDevice(p,a)                      (p)->lpVtbl->GetDevice(p,a)
#define IDirectPlay8Address_BuildFromDirectPlay4Address(p,a,b)  (p)->lpVtbl->BuildFromDirectPlay4Address(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirectPlay8Address_QueryInterface(p,a,b)               (p)->QueryInterface(a,b)
#define IDirectPlay8Address_AddRef(p)                           (p)->AddRef()
#define IDirectPlay8Address_Release(p)                          (p)->Release()
/*** IDirectPlay8Address methods ***/
#define IDirectPlay8Address_BuildFromURLW(p,a)                  (p)->BuildFromURLW(a)
#define IDirectPlay8Address_BuildFromURLA(p,a)                  (p)->BuildFromURLA(a)
#define IDirectPlay8Address_Duplicate(p,a)                      (p)->Duplicate(a)
#define IDirectPlay8Address_SetEqual(p,a)                       (p)->SetEqual(a)
#define IDirectPlay8Address_IsEqual(p,a)                        (p)->IsEqual(a)
#define IDirectPlay8Address_Clear(p)                            (p)->Clear()
#define IDirectPlay8Address_GetURLW(p,a,b)                      (p)->GetURLW(a,b)
#define IDirectPlay8Address_GetURLA(p,a,b)                      (p)->GetURLA(a,b)
#define IDirectPlay8Address_GetSP(p,a)                          (p)->GetSP(a)
#define IDirectPlay8Address_GetUserData(p,a,b)                  (p)->GetUserData(a,b)
#define IDirectPlay8Address_SetSP(p,a)                          (p)->SetSP(a)
#define IDirectPlay8Address_SetUserData(p,a,b)                  (p)->SetUserData(a,b)
#define IDirectPlay8Address_GetNumComponents(p,a)               (p)->GetNumComponents(a)
#define IDirectPlay8Address_GetComponentByName(p,a,b,c,d)       (p)->GetComponentByName(a,b,c,d)
#define IDirectPlay8Address_GetComponentByIndex(p,a,b,c,d,e,f)  (p)->GetComponentByIndex(a,b,c,d,e,f)
#define IDirectPlay8Address_AddComponent(p,a,b,c,d)             (p)->AddComponent(a,b,c,d)
#define IDirectPlay8Address_SetDevice(p,a)                      (p)->SetDevice(a)
#define IDirectPlay8Address_GetDevice(p,a)                      (p)->GetDevice(a)
#define IDirectPlay8Address_BuildFromDirectPlay4Address(p,a,b)  (p)->BuildFromDirectPlay4Address(a,b)
#endif

/*****************************************************************************
 * IDirectPlay8AddressIP interface
 */
#define INTERFACE IDirectPlay8AddressIP
DECLARE_INTERFACE_(IDirectPlay8AddressIP,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectPlay8AddressIP methods ***/
    STDMETHOD(BuildFromSockAddr)(THIS_ const SOCKADDR* pSockAddr) PURE;
    STDMETHOD(BuildAddress)(THIS_ const WCHAR* wszAddress, USHORT usPort) PURE;
    STDMETHOD(BuildLocalAddress)(THIS_ const GUID* pguidAdapter, USHORT usPort) PURE;
    STDMETHOD(GetSockAddress)(THIS_ SOCKADDR* pSockAddr, PDWORD) PURE;
    STDMETHOD(GetLocalAddress)(THIS_ GUID* pguidAdapter, USHORT* pusPort) PURE;
    STDMETHOD(GetAddress)(THIS_ WCHAR* wszAddress, PDWORD pdwAddressLength, USHORT* psPort) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectPlay8AddressIP_QueryInterface(p,a,b)         (p)->lpVtbl->QueryInterface(a,b)
#define IDirectPlay8AddressIP_AddRef(p)                     (p)->lpVtbl->AddRef()
#define IDirectPlay8AddressIP_Release(p)                    (p)->lpVtbl->Release()
/*** IDirectPlay8AddressIP methods ***/
#define IDirectPlay8AddressIP_BuildFromSockAddr(p,a)        (p)->lpVtbl->BuildFromSockAddr(a)
#define IDirectPlay8AddressIP_BuildAddress(p,a,b)           (p)->lpVtbl->BuildAddress(a,b)
#define IDirectPlay8AddressIP_BuildLocalAddress(p,a,b)      (p)->lpVtbl->BuildLocalAddress(a,b)
#define IDirectPlay8AddressIP_GetSockAddress(p,a,b)         (p)->lpVtbl->GetSockAddress(a,b)
#define IDirectPlay8AddressIP_GetLocalAddress(p,a,b)        (p)->lpVtbl->GetLocalAddress(a,b)
#define IDirectPlay8AddressIP_GetAddress(p,a,b,c)           (p)->lpVtbl->GetAddress(a,b,c)
#else
/*** IUnknown methods ***/
#define IDirectPlay8AddressIP_QueryInterface(p,a,b)         (p)->QueryInterface(a,b)
#define IDirectPlay8AddressIP_AddRef(p)                     (p)->AddRef()
#define IDirectPlay8AddressIP_Release(p)                    (p)->Release()
/*** IDirectPlay8AddressIP methods ***/
#define IDirectPlay8AddressIP_BuildFromSockAddr(p,a)        (p)->BuildFromSockAddr(a)
#define IDirectPlay8AddressIP_BuildAddress(p,a,b)           (p)->BuildAddress(a,b)
#define IDirectPlay8AddressIP_BuildLocalAddress(p,a,b)      (p)->BuildLocalAddress(a,b)
#define IDirectPlay8AddressIP_GetSockAddress(p,a,b)         (p)->GetSockAddress(a,b)
#define IDirectPlay8AddressIP_GetLocalAddress(p,a,b)        (p)->GetLocalAddress(a,b)
#define IDirectPlay8AddressIP_GetAddress(p,a,b,c)           (p)->GetAddress(a,b,c)
#endif

/* Export functions */

HRESULT WINAPI DirectPlay8AddressCreate(const GUID* pcIID, LPVOID* ppvInterface, IUnknown* pUnknown);

#ifdef __cplusplus
}
#endif

#endif
