#undef INTERFACE
/*
 * Copyright (C) 2006 Maarten Lankhorst
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

#ifndef __DPNATHLP_H__
#define __DPNATHLP_H__

#include <ole2.h>

#ifdef __cplusplus
extern "C" {
#endif

HRESULT DirectPlayNATHelpCreate(LPCGUID pIID, LPVOID *ppvInterface);

DEFINE_GUID(CLSID_DirectPlayNATHelpUPnP, 0xb9c2e9c4,0x68c1,0x4d42,0xa7,0xa1,0xe7,0x6a,0x26,0x98,0x2a,0xd6);
DEFINE_GUID(CLSID_DirectPlayNATHelpPAST, 0x963ab779,0x16a1,0x477c,0xa3,0x6d,0xcb,0x5e,0x71,0x19,0x38,0xf7);
DEFINE_GUID(IID_IDirectPlayNATHelp,      0x154940b6,0x2278,0x4a2f,0x91,0x01,0x9b,0xa9,0xf4,0x31,0xf6,0x03);

#define DPNHGETCAPS_UPDATESERVERSTATUS  0x01

#define DPNHREGISTERPORTS_TCP           0x01
#define DPNHREGISTERPORTS_FIXEDPORTS    0x02
#define DPNHREGISTERPORTS_SHAREDPORTS   0x04

#define DPNHADDRESSTYPE_TCP             0x01
#define DPNHADDRESSTYPE_FIXEDPORTS      0x02
#define DPNHADDRESSTYPE_SHAREDPORTS     0x04
#define DPNHADDRESSTYPE_LOCALFIREWALL   0x08
#define DPNHADDRESSTYPE_GATEWAY         0x10
#define DPNHADDRESSTYPE_GATEWAYISLOCAL  0x20

#define DPNHCAPSFLAG_LOCALFIREWALLPRESENT       0x01
#define DPNHCAPSFLAG_GATEWAYPRESENT             0x02
#define DPNHCAPSFLAG_GATEWAYISLOCAL             0x04
#define DPNHCAPSFLAG_PUBLICADDRESSAVAILABLE     0x08
#define DPNHCAPSFLAG_NOTALLSUPPORTACTIVENOTIFY  0x10

#define DPNHINITIALIZE_DISABLEGATEWAYSUPPORT        0x01
#define DPNHINITIALIZE_DISABLELOCALFIREWALLSUPPORT  0x02

#define DPNHQUERYADDRESS_TCP                        0x01
#define DPNHQUERYADDRESS_CACHEFOUND                 0x02
#define DPNHQUERYADDRESS_CACHENOTFOUND              0x04
#define DPNHQUERYADDRESS_CHECKFORPRIVATEBUTUNMAPPED 0x08

#define DPNHGETREGISTEREDADDRESSES_LOCALFIREWALLREMAPONLY 0x01

#define _DPNH_FACILITY_CODE   0x015
#define _DPNH_HRESULT_BASE    0xF000

#define MAKE_DPNHSUCCESS(code) \
               MAKE_HRESULT(0, _DPNH_FACILITY_CODE, (code + _DPNH_HRESULT_BASE))
#define MAKE_DPNHFAILURE(code) \
               MAKE_HRESULT(1, _DPNH_FACILITY_CODE, (code + _DPNH_HRESULT_BASE))

#define DPNH_OK                         S_OK
#define DPNHSUCCESS_ADDRESSESCHANGED    MAKE_DPNHSUCCESS(0x10)

#define DPNHERR_ALREADYINITIALIZED      MAKE_DPNHFAILURE(0x10)
#define DPNHERR_BUFFERTOOSMALL          MAKE_DPNHFAILURE(0x20)
#define DPNHERR_GENERIC                 E_FAIL
#define DPNHERR_INVALIDFLAGS            MAKE_DPNHFAILURE(0x30)
#define DPNHERR_INVALIDOBJECT           MAKE_DPNHFAILURE(0x40)
#define DPNHERR_INVALIDPARAM            E_INVALIDARG
#define DPNHERR_INVALIDPOINTER          E_POINTER
#define DPNHERR_NOMAPPING               MAKE_DPNHFAILURE(0x50)
#define DPNHERR_NOMAPPINGBUTPRIVATE     MAKE_DPNHFAILURE(0x60)
#define DPNHERR_NOTINITIALIZED          MAKE_DPNHFAILURE(0x70)
#define DPNHERR_OUTOFMEMORY             E_OUTOFMEMORY
#define DPNHERR_PORTALREADYREGISTERED   MAKE_DPNHFAILURE(0x80)
#define DPNHERR_PORTUNAVAILABLE         MAKE_DPNHFAILURE(0x90)
#define DPNHERR_REENTRANT               MAKE_DPNHFAILURE(0x95)
#define DPNHERR_SERVERNOTAVAILABLE      MAKE_DPNHFAILURE(0xA0)
#define DPNHERR_UPDATESERVERSTATUS      MAKE_DPNHFAILURE(0xC0)
	
typedef DWORD_PTR DPNHHANDLE;
typedef DWORD_PTR *PDPNHHANDLE;

typedef struct _DPNHCAPS
{
   DWORD dwSize;
   DWORD dwFlags;
   DWORD dwNumRegisteredPorts;
   DWORD dwMinLeaseTimeRemaining;
   DWORD dwRecommendedGetCapsInterval;
} DPNHCAPS, *PDPNHCAPS;


#define INTERFACE IDirectPlayNATHelp
DECLARE_INTERFACE_(IDirectPlayNATHelp,IUnknown)
{
   /*** IUnknown methods ***/
   STDMETHOD(QueryInterface) (THIS_
                              REFIID riid,
                              void** ppvObject) PURE;

   STDMETHOD_(ULONG,AddRef)  (THIS) PURE;

   STDMETHOD_(ULONG,Release) (THIS) PURE;

   /*** IDirectPlayNATHelp functions ***/
   STDMETHOD(Initialize)     (THIS_
                              DWORD dwFlags) PURE;

   STDMETHOD(Close)          (THIS_
                              DWORD dwFlags) PURE;

   STDMETHOD(GetCaps)        (THIS_
                              PDPNHCAPS pCaps,
                              DWORD dwFlags) PURE;

   STDMETHOD(RegisterPorts)  (THIS_
                              PSOCKADDR aLocalAddresses,
                              DWORD dwAddressSize,
                              DWORD dwAddresses,
                              DWORD dwTime,
                              PDPNHHANDLE phRegisteredPorts,
                              DWORD dwFlags) PURE;

   STDMETHOD(GetRegisteredAddresses) (THIS_
                              PDPNHHANDLE hRegisteredPorts,
                              PSOCKADDR paPublicAddresses,
                              const DWORD *dwAddressSize,
                              const DWORD *dwAddressFlags,
                              const DWORD *dwRemaining,
                              DWORD dwFlags) PURE;

   STDMETHOD(DeregisterPorts)(THIS_
                              DPNHHANDLE hRegPorts,
                              DWORD dwFlags) PURE;

   STDMETHOD(QueryAddress)   (THIS_
                              PSOCKADDR pSource,
                              PSOCKADDR pQuery,
                              PSOCKADDR pResponse,
                              INT iAddresses,
                              DWORD dwFlags) PURE;

   STDMETHOD(SetAlertEvent)  (THIS_
                              HANDLE hEvent,
                              DWORD dwFlags) PURE;

   STDMETHOD(SetAlertIOCompletionPort)(THIS_
                              HANDLE hIOCompletionPort,
                              DWORD dwCompletion,
                              DWORD dwMaxThreads,
                              DWORD dwFlags) PURE;

   STDMETHOD(ExtendRegisteredPortsLease)(THIS_
                              DPNHHANDLE hRegisteredPorts,
                              DWORD dwLeaseTime,
                              DWORD dwFlags) PURE;
};

#undef INTERFACE

#ifdef COBJMACROS
#define IDirectPlayNATHelp_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectPlayNATHelp_AddRef(p)  (p)->lpVtbl->AddRef(p)
#define IDirectPlayNATHelp_Release(p) (p)->lpVtbl->Release(p)
#define IDirectPlayNATHelp_Initialize(p,a) (p)->lpVtbl->Initialize(p,a)
#define IDirectPlayNATHelp_Close(p,a) (p)->lpVtbl->Close(p,a)
#define IDirectPlayNATHelp_GetCaps(p,a,b) (p)->lpVtbl->GetCaps(p,a,b)
#define IDirectPlayNATHelp_RegisterPorts(p,a,b,c,d,e,f) (p)->lpVtbl->RegisterPorts(p,a,b,c,d,e,f)
#define IDirectPlayNATHelp_GetRegisteredAddresses(p,a,b,c,d,e,f) (p)->lpVtbl->GetRegisteredAddresses(p,a,b,c,d,e,f)
#define IDirectPlayNATHelp_DeregisterPorts(p,a,b) (p)->lpVtbl->DeregisterPorts(p,a,b)
#define IDirectPlayNATHelp_QueryAddress(p,a,b,c,d,e) (p)->lpVtbl->QueryAddress(p,a,b,c,d,e)
#define IDirectPlayNATHelp_SetAlertEvent(p,a,b) (p)->lpVtbl->SetAlertEvent(p,a,b)
#define IDirectPlayNATHelp_SetAlertIOCompletionPort(p,a,b,c,d) (p)->lpVtbl->SetAlertIOCompletionPort(p,a,b,c,d)
#define IDirectPlayNATHelp_ExtendRegisteredPortsLease(p,a,b,c) (p)->lpVtbl->SetAlertIOCompletionPort(p,a,b,c)
#endif

#ifdef __cplusplus
}
#endif

#endif /* __DPNATHLP_H__ */
