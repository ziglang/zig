#undef INTERFACE
/*
 * Copyright (C) 2002 Jason Edmeades
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

#ifndef __WINE_D3D8_H
#define __WINE_D3D8_H

#ifndef DIRECT3D_VERSION
#define DIRECT3D_VERSION  0x0800
#endif

#include <stdlib.h>

#define COM_NO_WINDOWS_H
#include <objbase.h>
#include <windows.h>
#include <d3d8types.h>
#include <d3d8caps.h>

/*****************************************************************************
 * Behavior Flags for IDirect3D8::CreateDevice
 */
#define D3DCREATE_FPU_PRESERVE                  __MSABI_LONG(0x00000002)
#define D3DCREATE_MULTITHREADED                 __MSABI_LONG(0x00000004)
#define D3DCREATE_PUREDEVICE                    __MSABI_LONG(0x00000010)
#define D3DCREATE_SOFTWARE_VERTEXPROCESSING     __MSABI_LONG(0x00000020)
#define D3DCREATE_HARDWARE_VERTEXPROCESSING     __MSABI_LONG(0x00000040)
#define D3DCREATE_MIXED_VERTEXPROCESSING        __MSABI_LONG(0x00000080)

/*****************************************************************************
 * Flags for SetPrivateData
 */
#define D3DSPD_IUNKNOWN                         __MSABI_LONG(0x00000001)

/*****************************************************************************
 * #defines and error codes
 */
#define D3D_SDK_VERSION              220
#define D3DADAPTER_DEFAULT           0
#define D3DENUM_NO_WHQL_LEVEL        2

#define _FACD3D  0x876
#define MAKE_D3DHRESULT( code )  MAKE_HRESULT( 1, _FACD3D, code )

/*
 * Direct3D Errors
 */
#define D3D_OK                                  S_OK
#define D3DERR_WRONGTEXTUREFORMAT               MAKE_D3DHRESULT(2072)
#define D3DERR_UNSUPPORTEDCOLOROPERATION        MAKE_D3DHRESULT(2073)
#define D3DERR_UNSUPPORTEDCOLORARG              MAKE_D3DHRESULT(2074)
#define D3DERR_UNSUPPORTEDALPHAOPERATION        MAKE_D3DHRESULT(2075)
#define D3DERR_UNSUPPORTEDALPHAARG              MAKE_D3DHRESULT(2076)
#define D3DERR_TOOMANYOPERATIONS                MAKE_D3DHRESULT(2077)
#define D3DERR_CONFLICTINGTEXTUREFILTER         MAKE_D3DHRESULT(2078)
#define D3DERR_UNSUPPORTEDFACTORVALUE           MAKE_D3DHRESULT(2079)
#define D3DERR_CONFLICTINGRENDERSTATE           MAKE_D3DHRESULT(2081)
#define D3DERR_UNSUPPORTEDTEXTUREFILTER         MAKE_D3DHRESULT(2082)
#define D3DERR_CONFLICTINGTEXTUREPALETTE        MAKE_D3DHRESULT(2086)
#define D3DERR_DRIVERINTERNALERROR              MAKE_D3DHRESULT(2087)

#define D3DERR_NOTFOUND                         MAKE_D3DHRESULT(2150)
#define D3DERR_MOREDATA                         MAKE_D3DHRESULT(2151)
#define D3DERR_DEVICELOST                       MAKE_D3DHRESULT(2152)
#define D3DERR_DEVICENOTRESET                   MAKE_D3DHRESULT(2153)
#define D3DERR_NOTAVAILABLE                     MAKE_D3DHRESULT(2154)
#define D3DERR_OUTOFVIDEOMEMORY                 MAKE_D3DHRESULT(380)
#define D3DERR_INVALIDDEVICE                    MAKE_D3DHRESULT(2155)
#define D3DERR_INVALIDCALL                      MAKE_D3DHRESULT(2156)
#define D3DERR_DRIVERINVALIDCALL                MAKE_D3DHRESULT(2157)

/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(IID_IDirect3D8,              0x1DD9E8DA,0x1C77,0x4D40,0xB0,0xCF,0x98,0xFE,0xFD,0xFF,0x95,0x12);
typedef struct IDirect3D8 *LPDIRECT3D8;

DEFINE_GUID(IID_IDirect3DDevice8,        0x7385E5DF,0x8FE8,0x41D5,0x86,0xB6,0xD7,0xB4,0x85,0x47,0xB6,0xCF);
typedef struct IDirect3DDevice8 *LPDIRECT3DDEVICE8;

DEFINE_GUID(IID_IDirect3DResource8,      0x1B36BB7B,0x09B7,0x410A,0xB4,0x45,0x7D,0x14,0x30,0xD7,0xB3,0x3F);
typedef struct IDirect3DResource8 *LPDIRECT3DRESOURCE8, *PDIRECT3DRESOURCE8;

DEFINE_GUID(IID_IDirect3DVertexBuffer8,  0x8AEEEAC7,0x05F9,0x44D4,0xB5,0x91,0x00,0x0B,0x0D,0xF1,0xCB,0x95);
typedef struct IDirect3DVertexBuffer8 *LPDIRECT3DVERTEXBUFFER8, *PDIRECT3DVERTEXBUFFER8;

DEFINE_GUID(IID_IDirect3DVolume8,        0xBD7349F5,0x14F1,0x42E4,0x9C,0x79,0x97,0x23,0x80,0xDB,0x40,0xC0);
typedef struct IDirect3DVolume8 *LPDIRECT3DVOLUME8, *PDIRECT3DVOLUME8;

DEFINE_GUID(IID_IDirect3DSwapChain8,     0x928C088B,0x76B9,0x4C6B,0xA5,0x36,0xA5,0x90,0x85,0x38,0x76,0xCD);
typedef struct IDirect3DSwapChain8 *LPDIRECT3DSWAPCHAIN8, *PDIRECT3DSWAPCHAIN8;

DEFINE_GUID(IID_IDirect3DSurface8,       0xB96EEBCA,0xB326,0x4EA5,0x88,0x2F,0x2F,0xF5,0xBA,0xE0,0x21,0xDD);
typedef struct IDirect3DSurface8 *LPDIRECT3DSURFACE8, *PDIRECT3DSURFACE8;

DEFINE_GUID(IID_IDirect3DIndexBuffer8,   0x0E689C9A,0x053D,0x44A0,0x9D,0x92,0xDB,0x0E,0x3D,0x75,0x0F,0x86);
typedef struct IDirect3DIndexBuffer8 *LPDIRECT3DINDEXBUFFER8, *PDIRECT3DINDEXBUFFER8;

DEFINE_GUID(IID_IDirect3DBaseTexture8,   0xB4211CFA,0x51B9,0x4A9F,0xAB,0x78,0xDB,0x99,0xB2,0xBB,0x67,0x8E);
typedef struct IDirect3DBaseTexture8 *LPDIRECT3DBASETEXTURE8, *PDIRECT3DBASETEXTURE8;

DEFINE_GUID(IID_IDirect3DTexture8,       0xE4CDD575,0x2866,0x4F01,0xB1,0x2E,0x7E,0xEC,0xE1,0xEC,0x93,0x58);
typedef struct IDirect3DTexture8 *LPDIRECT3DTEXTURE8, *PDIRECT3DTEXTURE8;

DEFINE_GUID(IID_IDirect3DCubeTexture8,   0x3EE5B968,0x2ACA,0x4C34,0x8B,0xB5,0x7E,0x0C,0x3D,0x19,0xB7,0x50);
typedef struct IDirect3DCubeTexture8 *LPDIRECT3DCUBETEXTURE8, *PDIRECT3DCUBETEXTURE8;

DEFINE_GUID(IID_IDirect3DVolumeTexture8, 0x4B8AAAFA,0x140F,0x42BA,0x91,0x31,0x59,0x7E,0xAF,0xAA,0x2E,0xAD);
typedef struct IDirect3DVolumeTexture8 *LPDIRECT3DVOLUMETEXTURE8, *PDIRECT3DVOLUMETEXTURE8;

/*****************************************************************************
 * IDirect3D8 interface
 */
#undef INTERFACE
#define INTERFACE IDirect3D8
DECLARE_INTERFACE_IID_(IDirect3D8,IUnknown,"1dd9e8da-1c77-4d40-b0cf-98fefdff9512")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3D8 methods ***/
    STDMETHOD(RegisterSoftwareDevice)(THIS_ void * pInitializeFunction) PURE;
    STDMETHOD_(UINT,GetAdapterCount             )(THIS) PURE;
    STDMETHOD(GetAdapterIdentifier)(THIS_ UINT  Adapter, DWORD  Flags, D3DADAPTER_IDENTIFIER8 * pIdentifier) PURE;
    STDMETHOD_(UINT,GetAdapterModeCount)(THIS_ UINT  Adapter) PURE;
    STDMETHOD(EnumAdapterModes)(THIS_ UINT  Adapter, UINT  Mode, D3DDISPLAYMODE * pMode) PURE;
    STDMETHOD(GetAdapterDisplayMode)(THIS_ UINT  Adapter, D3DDISPLAYMODE * pMode) PURE;
    STDMETHOD(CheckDeviceType)(THIS_ UINT  Adapter, D3DDEVTYPE  CheckType, D3DFORMAT  DisplayFormat, D3DFORMAT  BackBufferFormat, WINBOOL  Windowed) PURE;
    STDMETHOD(CheckDeviceFormat)(THIS_ UINT  Adapter, D3DDEVTYPE  DeviceType, D3DFORMAT  AdapterFormat, DWORD  Usage, D3DRESOURCETYPE  RType, D3DFORMAT  CheckFormat) PURE;
    STDMETHOD(CheckDeviceMultiSampleType)(THIS_ UINT  Adapter, D3DDEVTYPE  DeviceType, D3DFORMAT  SurfaceFormat, WINBOOL  Windowed, D3DMULTISAMPLE_TYPE  MultiSampleType) PURE;
    STDMETHOD(CheckDepthStencilMatch)(THIS_ UINT  Adapter, D3DDEVTYPE  DeviceType, D3DFORMAT  AdapterFormat, D3DFORMAT  RenderTargetFormat, D3DFORMAT  DepthStencilFormat) PURE;
    STDMETHOD(GetDeviceCaps)(THIS_ UINT  Adapter, D3DDEVTYPE  DeviceType, D3DCAPS8 * pCaps) PURE;
    STDMETHOD_(HMONITOR,GetAdapterMonitor)(THIS_ UINT  Adapter) PURE;
    STDMETHOD(CreateDevice)(THIS_ UINT  Adapter, D3DDEVTYPE  DeviceType,HWND  hFocusWindow, DWORD  BehaviorFlags, D3DPRESENT_PARAMETERS * pPresentationParameters, struct IDirect3DDevice8 ** ppReturnedDeviceInterface) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3D8_QueryInterface(p,a,b)                    (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3D8_AddRef(p)                                (p)->lpVtbl->AddRef(p)
#define IDirect3D8_Release(p)                               (p)->lpVtbl->Release(p)
/*** IDirect3D8 methods ***/
#define IDirect3D8_RegisterSoftwareDevice(p,a)              (p)->lpVtbl->RegisterSoftwareDevice(p,a)
#define IDirect3D8_GetAdapterCount(p)                       (p)->lpVtbl->GetAdapterCount(p)
#define IDirect3D8_GetAdapterIdentifier(p,a,b,c)            (p)->lpVtbl->GetAdapterIdentifier(p,a,b,c)
#define IDirect3D8_GetAdapterModeCount(p,a)                 (p)->lpVtbl->GetAdapterModeCount(p,a)
#define IDirect3D8_EnumAdapterModes(p,a,b,c)                (p)->lpVtbl->EnumAdapterModes(p,a,b,c)
#define IDirect3D8_GetAdapterDisplayMode(p,a,b)             (p)->lpVtbl->GetAdapterDisplayMode(p,a,b)
#define IDirect3D8_CheckDeviceType(p,a,b,c,d,e)             (p)->lpVtbl->CheckDeviceType(p,a,b,c,d,e)
#define IDirect3D8_CheckDeviceFormat(p,a,b,c,d,e,f)         (p)->lpVtbl->CheckDeviceFormat(p,a,b,c,d,e,f)
#define IDirect3D8_CheckDeviceMultiSampleType(p,a,b,c,d,e)  (p)->lpVtbl->CheckDeviceMultiSampleType(p,a,b,c,d,e)
#define IDirect3D8_CheckDepthStencilMatch(p,a,b,c,d,e)      (p)->lpVtbl->CheckDepthStencilMatch(p,a,b,c,d,e)
#define IDirect3D8_GetDeviceCaps(p,a,b,c)                   (p)->lpVtbl->GetDeviceCaps(p,a,b,c)
#define IDirect3D8_GetAdapterMonitor(p,a)                   (p)->lpVtbl->GetAdapterMonitor(p,a)
#define IDirect3D8_CreateDevice(p,a,b,c,d,e,f)              (p)->lpVtbl->CreateDevice(p,a,b,c,d,e,f)
#else
/*** IUnknown methods ***/
#define IDirect3D8_QueryInterface(p,a,b)                    (p)->QueryInterface(a,b)
#define IDirect3D8_AddRef(p)                                (p)->AddRef()
#define IDirect3D8_Release(p)                               (p)->Release()
/*** IDirect3D8 methods ***/
#define IDirect3D8_RegisterSoftwareDevice(p,a)              (p)->RegisterSoftwareDevice(a)
#define IDirect3D8_GetAdapterCount(p)                       (p)->GetAdapterCount()
#define IDirect3D8_GetAdapterIdentifier(p,a,b,c)            (p)->GetAdapterIdentifier(a,b,c)
#define IDirect3D8_GetAdapterModeCount(p,a)                 (p)->GetAdapterModeCount(a)
#define IDirect3D8_EnumAdapterModes(p,a,b,c)                (p)->EnumAdapterModes(a,b,c)
#define IDirect3D8_GetAdapterDisplayMode(p,a,b)             (p)->GetAdapterDisplayMode(a,b)
#define IDirect3D8_CheckDeviceType(p,a,b,c,d,e)             (p)->CheckDeviceType(a,b,c,d,e)
#define IDirect3D8_CheckDeviceFormat(p,a,b,c,d,e,f)         (p)->CheckDeviceFormat(a,b,c,d,e,f)
#define IDirect3D8_CheckDeviceMultiSampleType(p,a,b,c,d,e)  (p)->CheckDeviceMultiSampleType(a,b,c,d,e)
#define IDirect3D8_CheckDepthStencilMatch(p,a,b,c,d,e)      (p)->CheckDepthStencilMatch(a,b,c,d,e)
#define IDirect3D8_GetDeviceCaps(p,a,b,c)                   (p)->GetDeviceCaps(a,b,c)
#define IDirect3D8_GetAdapterMonitor(p,a)                   (p)->GetAdapterMonitor(a)
#define IDirect3D8_CreateDevice(p,a,b,c,d,e,f)              (p)->CreateDevice(a,b,c,d,e,f)
#endif

/*****************************************************************************
 * IDirect3DVolume8 interface
 */
#define INTERFACE IDirect3DVolume8
DECLARE_INTERFACE_IID_(IDirect3DVolume8,IUnknown,"bd7349f5-14f1-42e4-9c79-972380db40c0")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DVolume8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID   refguid,void * pData, DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD(GetContainer)(THIS_ REFIID  riid, void ** ppContainer) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DVOLUME_DESC * pDesc) PURE;
    STDMETHOD(LockBox)(THIS_ D3DLOCKED_BOX *locked_box, const D3DBOX *box, DWORD flags) PURE;
    STDMETHOD(UnlockBox)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVolume8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVolume8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DVolume8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DVolume8 methods ***/
#define IDirect3DVolume8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DVolume8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DVolume8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DVolume8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DVolume8_GetContainer(p,a,b)          (p)->lpVtbl->GetContainer(p,a,b)
#define IDirect3DVolume8_GetDesc(p,a)                 (p)->lpVtbl->GetDesc(p,a)
#define IDirect3DVolume8_LockBox(p,a,b,c)             (p)->lpVtbl->LockBox(p,a,b,c)
#define IDirect3DVolume8_UnlockBox(p)                 (p)->lpVtbl->UnlockBox(p)
#else
/*** IUnknown methods ***/
#define IDirect3DVolume8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DVolume8_AddRef(p)                    (p)->AddRef()
#define IDirect3DVolume8_Release(p)                   (p)->Release()
/*** IDirect3DVolume8 methods ***/
#define IDirect3DVolume8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DVolume8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DVolume8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DVolume8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DVolume8_GetContainer(p,a,b)          (p)->GetContainer(a,b)
#define IDirect3DVolume8_GetDesc(p,a)                 (p)->GetDesc(a)
#define IDirect3DVolume8_LockBox(p,a,b,c)             (p)->LockBox(a,b,c)
#define IDirect3DVolume8_UnlockBox(p)                 (p)->UnlockBox()
#endif

/*****************************************************************************
 * IDirect3DSwapChain8 interface
 */
#define INTERFACE IDirect3DSwapChain8
DECLARE_INTERFACE_IID_(IDirect3DSwapChain8,IUnknown,"928c088b-76b9-4c6b-a536-a590853876cd")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DSwapChain8 methods ***/
    STDMETHOD(Present)(THIS_ const RECT *src_rect, const RECT *dst_rect, HWND dst_window_override,
            const RGNDATA *dirty_region) PURE;
    STDMETHOD(GetBackBuffer)(THIS_ UINT  BackBuffer, D3DBACKBUFFER_TYPE  Type, struct IDirect3DSurface8 ** ppBackBuffer) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DSwapChain8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DSwapChain8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DSwapChain8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DSwapChain8 methods ***/
#define IDirect3DSwapChain8_Present(p,a,b,c,d)           (p)->lpVtbl->Present(p,a,b,c,d)
#define IDirect3DSwapChain8_GetBackBuffer(p,a,b,c)       (p)->lpVtbl->GetBackBuffer(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirect3DSwapChain8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DSwapChain8_AddRef(p)                    (p)->AddRef()
#define IDirect3DSwapChain8_Release(p)                   (p)->Release()
/*** IDirect3DSwapChain8 methods ***/
#define IDirect3DSwapChain8_Present(p,a,b,c,d)           (p)->Present(a,b,c,d)
#define IDirect3DSwapChain8_GetBackBuffer(p,a,b,c)       (p)->GetBackBuffer(a,b,c)
#endif

/*****************************************************************************
 * IDirect3DSurface8 interface
 */
#define INTERFACE IDirect3DSurface8
DECLARE_INTERFACE_IID_(IDirect3DSurface8,IUnknown,"b96eebca-b326-4ea5-882f-2ff5bae021dd")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DSurface8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID  refguid,void * pData,DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD(GetContainer)(THIS_ REFIID  riid, void ** ppContainer) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DSURFACE_DESC * pDesc) PURE;
    STDMETHOD(LockRect)(THIS_ D3DLOCKED_RECT *locked_rect, const RECT *rect, DWORD flags) PURE;
    STDMETHOD(UnlockRect)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DSurface8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DSurface8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DSurface8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DSurface8 methods ***/
#define IDirect3DSurface8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DSurface8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DSurface8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DSurface8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DSurface8_GetContainer(p,a,b)          (p)->lpVtbl->GetContainer(p,a,b)
#define IDirect3DSurface8_GetDesc(p,a)                 (p)->lpVtbl->GetDesc(p,a)
#define IDirect3DSurface8_LockRect(p,a,b,c)            (p)->lpVtbl->LockRect(p,a,b,c)
#define IDirect3DSurface8_UnlockRect(p)                (p)->lpVtbl->UnlockRect(p)
#else
/*** IUnknown methods ***/
#define IDirect3DSurface8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DSurface8_AddRef(p)                    (p)->AddRef()
#define IDirect3DSurface8_Release(p)                   (p)->Release()
/*** IDirect3DSurface8 methods ***/
#define IDirect3DSurface8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DSurface8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DSurface8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DSurface8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DSurface8_GetContainer(p,a,b)          (p)->GetContainer(a,b)
#define IDirect3DSurface8_GetDesc(p,a)                 (p)->GetDesc(a)
#define IDirect3DSurface8_LockRect(p,a,b,c)            (p)->LockRect(a,b,c)
#define IDirect3DSurface8_UnlockRect(p)                (p)->UnlockRect()
#endif

/*****************************************************************************
 * IDirect3DResource8 interface
 */
#define INTERFACE IDirect3DResource8
DECLARE_INTERFACE_IID_(IDirect3DResource8,IUnknown,"1b36bb7b-09b7-410a-b445-7d1430d7b33f")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID  refguid, void * pData, DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD_(DWORD,SetPriority)(THIS_ DWORD  PriorityNew) PURE;
    STDMETHOD_(DWORD,GetPriority)(THIS) PURE;
    STDMETHOD_(void,PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE,GetType)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DResource8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DResource8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DResource8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DResource8 methods ***/
#define IDirect3DResource8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DResource8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DResource8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DResource8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DResource8_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DResource8_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DResource8_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DResource8_GetType(p)                   (p)->lpVtbl->GetType(p)
#else
/*** IUnknown methods ***/
#define IDirect3DResource8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DResource8_AddRef(p)                    (p)->AddRef()
#define IDirect3DResource8_Release(p)                   (p)->Release()
/*** IDirect3DResource8 methods ***/
#define IDirect3DResource8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DResource8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DResource8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DResource8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DResource8_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DResource8_GetPriority(p)               (p)->GetPriority()
#define IDirect3DResource8_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DResource8_GetType(p)                   (p)->GetType()
#endif

/*****************************************************************************
 * IDirect3DVertexBuffer8 interface
 */
#define INTERFACE IDirect3DVertexBuffer8
DECLARE_INTERFACE_IID_(IDirect3DVertexBuffer8,IDirect3DResource8,"8aeeeac7-05f9-44d4-b591-000b0df1cb95")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID  refguid, void * pData, DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD_(DWORD,SetPriority)(THIS_ DWORD  PriorityNew) PURE;
    STDMETHOD_(DWORD,GetPriority)(THIS) PURE;
    STDMETHOD_(void,PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE,GetType)(THIS) PURE;
    /*** IDirect3DVertexBuffer8 methods ***/
    STDMETHOD(Lock)(THIS_ UINT  OffsetToLock, UINT  SizeToLock, BYTE ** ppbData, DWORD  Flags) PURE;
    STDMETHOD(Unlock)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DVERTEXBUFFER_DESC  * pDesc) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVertexBuffer8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVertexBuffer8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DVertexBuffer8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DVertexBuffer8 methods: IDirect3DResource8 ***/
#define IDirect3DVertexBuffer8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DVertexBuffer8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DVertexBuffer8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DVertexBuffer8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DVertexBuffer8_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DVertexBuffer8_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DVertexBuffer8_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DVertexBuffer8_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DVertexBuffer8 methods ***/
#define IDirect3DVertexBuffer8_Lock(p,a,b,c,d)              (p)->lpVtbl->Lock(p,a,b,c,d)
#define IDirect3DVertexBuffer8_Unlock(p)                    (p)->lpVtbl->Unlock(p)
#define IDirect3DVertexBuffer8_GetDesc(p,a)                 (p)->lpVtbl->GetDesc(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DVertexBuffer8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DVertexBuffer8_AddRef(p)                    (p)->AddRef()
#define IDirect3DVertexBuffer8_Release(p)                   (p)->Release()
/*** IDirect3DVertexBuffer8 methods: IDirect3DResource8 ***/
#define IDirect3DVertexBuffer8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DVertexBuffer8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DVertexBuffer8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DVertexBuffer8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DVertexBuffer8_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DVertexBuffer8_GetPriority(p)               (p)->GetPriority()
#define IDirect3DVertexBuffer8_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DVertexBuffer8_GetType(p)                   (p)->GetType()
/*** IDirect3DVertexBuffer8 methods ***/
#define IDirect3DVertexBuffer8_Lock(p,a,b,c,d)              (p)->Lock(a,b,c,d)
#define IDirect3DVertexBuffer8_Unlock(p)                    (p)->Unlock()
#define IDirect3DVertexBuffer8_GetDesc(p,a)                 (p)->GetDesc(a)
#endif

/*****************************************************************************
 * IDirect3DIndexBuffer8 interface
 */
#define INTERFACE IDirect3DIndexBuffer8
DECLARE_INTERFACE_IID_(IDirect3DIndexBuffer8,IDirect3DResource8,"0e689c9a-053d-44a0-9d92-db0e3d750f86")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID  refguid, void * pData, DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD_(DWORD,SetPriority)(THIS_ DWORD  PriorityNew) PURE;
    STDMETHOD_(DWORD,GetPriority)(THIS) PURE;
    STDMETHOD_(void,PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE,GetType)(THIS) PURE;
    /*** IDirect3DIndexBuffer8 methods ***/
    STDMETHOD(Lock)(THIS_ UINT  OffsetToLock, UINT  SizeToLock, BYTE ** ppbData, DWORD  Flags) PURE;
    STDMETHOD(Unlock)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DINDEXBUFFER_DESC * pDesc) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DIndexBuffer8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DIndexBuffer8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DIndexBuffer8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DIndexBuffer8 methods: IDirect3DResource8 ***/
#define IDirect3DIndexBuffer8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DIndexBuffer8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DIndexBuffer8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DIndexBuffer8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DIndexBuffer8_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DIndexBuffer8_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DIndexBuffer8_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DIndexBuffer8_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DIndexBuffer8 methods ***/
#define IDirect3DIndexBuffer8_Lock(p,a,b,c,d)              (p)->lpVtbl->Lock(p,a,b,c,d)
#define IDirect3DIndexBuffer8_Unlock(p)                    (p)->lpVtbl->Unlock(p)
#define IDirect3DIndexBuffer8_GetDesc(p,a)                 (p)->lpVtbl->GetDesc(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DIndexBuffer8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DIndexBuffer8_AddRef(p)                    (p)->AddRef()
#define IDirect3DIndexBuffer8_Release(p)                   (p)->Release()
/*** IDirect3DIndexBuffer8 methods: IDirect3DResource8 ***/
#define IDirect3DIndexBuffer8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DIndexBuffer8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DIndexBuffer8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DIndexBuffer8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DIndexBuffer8_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DIndexBuffer8_GetPriority(p)               (p)->GetPriority()
#define IDirect3DIndexBuffer8_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DIndexBuffer8_GetType(p)                   (p)->GetType()
/*** IDirect3DIndexBuffer8 methods ***/
#define IDirect3DIndexBuffer8_Lock(p,a,b,c,d)              (p)->Lock(a,b,c,d)
#define IDirect3DIndexBuffer8_Unlock(p)                    (p)->Unlock()
#define IDirect3DIndexBuffer8_GetDesc(p,a)                 (p)->GetDesc(a)
#endif

/*****************************************************************************
 * IDirect3DBaseTexture8 interface
 */
#define INTERFACE IDirect3DBaseTexture8
DECLARE_INTERFACE_IID_(IDirect3DBaseTexture8,IDirect3DResource8,"b4211cfa-51b9-4a9f-ab78-db99b2bb678e")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID  refguid, void * pData, DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD_(DWORD,SetPriority)(THIS_ DWORD  PriorityNew) PURE;
    STDMETHOD_(DWORD,GetPriority)(THIS) PURE;
    STDMETHOD_(void,PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE,GetType)(THIS) PURE;
    /*** IDirect3DBaseTexture8 methods ***/
    STDMETHOD_(DWORD,SetLOD)(THIS_ DWORD  LODNew) PURE;
    STDMETHOD_(DWORD,GetLOD)(THIS) PURE;
    STDMETHOD_(DWORD,GetLevelCount)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DBaseTexture8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DBaseTexture8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DBaseTexture8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DBaseTexture8 methods: IDirect3DResource8 ***/
#define IDirect3DBaseTexture8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DBaseTexture8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DBaseTexture8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DBaseTexture8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DBaseTexture8_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DBaseTexture8_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DBaseTexture8_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DBaseTexture8_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DBaseTexture8 methods ***/
#define IDirect3DBaseTexture8_SetLOD(p,a)                  (p)->lpVtbl->SetLOD(p,a)
#define IDirect3DBaseTexture8_GetLOD(p)                    (p)->lpVtbl->GetLOD(p)
#define IDirect3DBaseTexture8_GetLevelCount(p)             (p)->lpVtbl->GetLevelCount(p)
#else
/*** IUnknown methods ***/
#define IDirect3DBaseTexture8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DBaseTexture8_AddRef(p)                    (p)->AddRef()
#define IDirect3DBaseTexture8_Release(p)                   (p)->Release()
/*** IDirect3DBaseTexture8 methods: IDirect3DResource8 ***/
#define IDirect3DBaseTexture8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DBaseTexture8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DBaseTexture8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DBaseTexture8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DBaseTexture8_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DBaseTexture8_GetPriority(p)               (p)->GetPriority()
#define IDirect3DBaseTexture8_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DBaseTexture8_GetType(p)                   (p)->GetType()
/*** IDirect3DBaseTexture8 methods ***/
#define IDirect3DBaseTexture8_SetLOD(p,a)                  (p)->SetLOD(a)
#define IDirect3DBaseTexture8_GetLOD(p)                    (p)->GetLOD()
#define IDirect3DBaseTexture8_GetLevelCount(p)             (p)->GetLevelCount()
#endif

/*****************************************************************************
 * IDirect3DCubeTexture8 interface
 */
#define INTERFACE IDirect3DCubeTexture8
DECLARE_INTERFACE_IID_(IDirect3DCubeTexture8,IDirect3DBaseTexture8,"3ee5b968-2aca-4c34-8bb5-7e0c3d19b750")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID  refguid, void * pData, DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD_(DWORD,SetPriority)(THIS_ DWORD  PriorityNew) PURE;
    STDMETHOD_(DWORD,GetPriority)(THIS) PURE;
    STDMETHOD_(void,PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE,GetType)(THIS) PURE;
    /*** IDirect3DBaseTexture8 methods ***/
    STDMETHOD_(DWORD,SetLOD)(THIS_ DWORD  LODNew) PURE;
    STDMETHOD_(DWORD,GetLOD)(THIS) PURE;
    STDMETHOD_(DWORD,GetLevelCount)(THIS) PURE;
    /*** IDirect3DCubeTexture8 methods ***/
    STDMETHOD(GetLevelDesc)(THIS_ UINT  Level,D3DSURFACE_DESC * pDesc) PURE;
    STDMETHOD(GetCubeMapSurface)(THIS_ D3DCUBEMAP_FACES  FaceType,UINT  Level,IDirect3DSurface8 ** ppCubeMapSurface) PURE;
    STDMETHOD(LockRect)(THIS_ D3DCUBEMAP_FACES face, UINT level, D3DLOCKED_RECT *locked_rect,
            const RECT *rect, DWORD flags) PURE;
    STDMETHOD(UnlockRect)(THIS_ D3DCUBEMAP_FACES  FaceType,UINT  Level) PURE;
    STDMETHOD(AddDirtyRect)(THIS_ D3DCUBEMAP_FACES face, const RECT *dirty_rect) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DCubeTexture8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DCubeTexture8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DCubeTexture8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DCubeTexture8 methods: IDirect3DResource8 ***/
#define IDirect3DCubeTexture8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DCubeTexture8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DCubeTexture8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DCubeTexture8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DCubeTexture8_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DCubeTexture8_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DCubeTexture8_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DCubeTexture8_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DCubeTexture8 methods: IDirect3DBaseTexture8 ***/
#define IDirect3DCubeTexture8_SetLOD(p,a)                  (p)->lpVtbl->SetLOD(p,a)
#define IDirect3DCubeTexture8_GetLOD(p)                    (p)->lpVtbl->GetLOD(p)
#define IDirect3DCubeTexture8_GetLevelCount(p)             (p)->lpVtbl->GetLevelCount(p)
/*** IDirect3DCubeTexture8 methods ***/
#define IDirect3DCubeTexture8_GetLevelDesc(p,a,b)          (p)->lpVtbl->GetLevelDesc(p,a,b)
#define IDirect3DCubeTexture8_GetCubeMapSurface(p,a,b,c)   (p)->lpVtbl->GetCubeMapSurface(p,a,b,c)
#define IDirect3DCubeTexture8_LockRect(p,a,b,c,d,e)        (p)->lpVtbl->LockRect(p,a,b,c,d,e)
#define IDirect3DCubeTexture8_UnlockRect(p,a,b)            (p)->lpVtbl->UnlockRect(p,a,b)
#define IDirect3DCubeTexture8_AddDirtyRect(p,a,b)          (p)->lpVtbl->AddDirtyRect(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DCubeTexture8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DCubeTexture8_AddRef(p)                    (p)->AddRef()
#define IDirect3DCubeTexture8_Release(p)                   (p)->Release()
/*** IDirect3DCubeTexture8 methods: IDirect3DResource8 ***/
#define IDirect3DCubeTexture8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DCubeTexture8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DCubeTexture8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DCubeTexture8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DCubeTexture8_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DCubeTexture8_GetPriority(p)               (p)->GetPriority()
#define IDirect3DCubeTexture8_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DCubeTexture8_GetType(p)                   (p)->GetType()
/*** IDirect3DCubeTexture8 methods: IDirect3DBaseTexture8 ***/
#define IDirect3DCubeTexture8_SetLOD(p,a)                  (p)->SetLOD(a)
#define IDirect3DCubeTexture8_GetLOD(p)                    (p)->GetLOD()
#define IDirect3DCubeTexture8_GetLevelCount(p)             (p)->GetLevelCount()
/*** IDirect3DCubeTexture8 methods ***/
#define IDirect3DCubeTexture8_GetLevelDesc(p,a,b)          (p)->GetLevelDesc(a,b)
#define IDirect3DCubeTexture8_GetCubeMapSurface(p,a,b,c)   (p)->GetCubeMapSurface(a,b,c)
#define IDirect3DCubeTexture8_LockRect(p,a,b,c,d,e)        (p)->LockRect(a,b,c,d,e)
#define IDirect3DCubeTexture8_UnlockRect(p,a,b)            (p)->UnlockRect(a,b)
#define IDirect3DCubeTexture8_AddDirtyRect(p,a,b)          (p)->AddDirtyRect(a,b)
#endif

/*****************************************************************************
 * IDirect3DTexture8 interface
 */
#define INTERFACE IDirect3DTexture8
DECLARE_INTERFACE_IID_(IDirect3DTexture8,IDirect3DBaseTexture8,"e4cdd575-2866-4f01-b12e-7eece1ec9358")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID  refguid, void * pData, DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD_(DWORD,SetPriority)(THIS_ DWORD  PriorityNew) PURE;
    STDMETHOD_(DWORD,GetPriority)(THIS) PURE;
    STDMETHOD_(void,PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE,GetType)(THIS) PURE;
    /*** IDirect3DBaseTexture8 methods ***/
    STDMETHOD_(DWORD,SetLOD)(THIS_ DWORD  LODNew) PURE;
    STDMETHOD_(DWORD,GetLOD)(THIS) PURE;
    STDMETHOD_(DWORD,GetLevelCount)(THIS) PURE;
    /*** IDirect3DTexture8 methods ***/
    STDMETHOD(GetLevelDesc)(THIS_ UINT  Level,D3DSURFACE_DESC * pDesc) PURE;
    STDMETHOD(GetSurfaceLevel)(THIS_ UINT  Level,IDirect3DSurface8 ** ppSurfaceLevel) PURE;
    STDMETHOD(LockRect)(THIS_ UINT level, D3DLOCKED_RECT *locked_rect, const RECT *rect, DWORD flags) PURE;
    STDMETHOD(UnlockRect)(THIS_ UINT  Level) PURE;
    STDMETHOD(AddDirtyRect)(THIS_ const RECT *dirty_rect) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DTexture8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DTexture8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DTexture8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DTexture8 methods: IDirect3DResource8 ***/
#define IDirect3DTexture8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DTexture8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DTexture8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DTexture8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DTexture8_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DTexture8_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DTexture8_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DTexture8_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DTexture8 methods: IDirect3DBaseTexture8 ***/
#define IDirect3DTexture8_SetLOD(p,a)                  (p)->lpVtbl->SetLOD(p,a)
#define IDirect3DTexture8_GetLOD(p)                    (p)->lpVtbl->GetLOD(p)
#define IDirect3DTexture8_GetLevelCount(p)             (p)->lpVtbl->GetLevelCount(p)
/*** IDirect3DTexture8 methods ***/
#define IDirect3DTexture8_GetLevelDesc(p,a,b)          (p)->lpVtbl->GetLevelDesc(p,a,b)
#define IDirect3DTexture8_GetSurfaceLevel(p,a,b)       (p)->lpVtbl->GetSurfaceLevel(p,a,b)
#define IDirect3DTexture8_LockRect(p,a,b,c,d)          (p)->lpVtbl->LockRect(p,a,b,c,d)
#define IDirect3DTexture8_UnlockRect(p,a)              (p)->lpVtbl->UnlockRect(p,a)
#define IDirect3DTexture8_AddDirtyRect(p,a)            (p)->lpVtbl->AddDirtyRect(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DTexture8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DTexture8_AddRef(p)                    (p)->AddRef()
#define IDirect3DTexture8_Release(p)                   (p)->Release()
/*** IDirect3DTexture8 methods: IDirect3DResource8 ***/
#define IDirect3DTexture8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DTexture8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DTexture8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DTexture8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DTexture8_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DTexture8_GetPriority(p)               (p)->GetPriority()
#define IDirect3DTexture8_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DTexture8_GetType(p)                   (p)->GetType()
/*** IDirect3DTexture8 methods: IDirect3DBaseTexture8 ***/
#define IDirect3DTexture8_SetLOD(p,a)                  (p)->SetLOD(a)
#define IDirect3DTexture8_GetLOD(p)                    (p)->GetLOD()
#define IDirect3DTexture8_GetLevelCount(p)             (p)->GetLevelCount()
/*** IDirect3DTexture8 methods ***/
#define IDirect3DTexture8_GetLevelDesc(p,a,b)          (p)->GetLevelDesc(a,b)
#define IDirect3DTexture8_GetSurfaceLevel(p,a,b)       (p)->GetSurfaceLevel(a,b)
#define IDirect3DTexture8_LockRect(p,a,b,c,d)          (p)->LockRect(a,b,c,d)
#define IDirect3DTexture8_UnlockRect(p,a)              (p)->UnlockRect(a)
#define IDirect3DTexture8_AddDirtyRect(p,a)            (p)->AddDirtyRect(a)
#endif

/*****************************************************************************
 * IDirect3DVolumeTexture8 interface
 */
#define INTERFACE IDirect3DVolumeTexture8
DECLARE_INTERFACE_IID_(IDirect3DVolumeTexture8,IDirect3DBaseTexture8,"4b8aaafa-140f-42ba-9131-597eafaa2ead")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource8 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice8 ** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID refguid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID  refguid, void * pData, DWORD * pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID  refguid) PURE;
    STDMETHOD_(DWORD,SetPriority)(THIS_ DWORD  PriorityNew) PURE;
    STDMETHOD_(DWORD,GetPriority)(THIS) PURE;
    STDMETHOD_(void,PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE,GetType)(THIS) PURE;
    /*** IDirect3DBaseTexture8 methods ***/
    STDMETHOD_(DWORD,SetLOD)(THIS_ DWORD  LODNew) PURE;
    STDMETHOD_(DWORD,GetLOD)(THIS) PURE;
    STDMETHOD_(DWORD,GetLevelCount)(THIS) PURE;
    /*** IDirect3DVolumeTexture8 methods ***/
    STDMETHOD(GetLevelDesc)(THIS_ UINT  Level,D3DVOLUME_DESC * pDesc) PURE;
    STDMETHOD(GetVolumeLevel)(THIS_ UINT  Level,IDirect3DVolume8 ** ppVolumeLevel) PURE;
    STDMETHOD(LockBox)(THIS_ UINT level, D3DLOCKED_BOX *locked_box, const D3DBOX *box, DWORD flags) PURE;
    STDMETHOD(UnlockBox)(THIS_ UINT  Level) PURE;
    STDMETHOD(AddDirtyBox)(THIS_ const D3DBOX *dirty_box) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVolumeTexture8_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVolumeTexture8_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DVolumeTexture8_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DVolumeTexture8 methods: IDirect3DResource8 ***/
#define IDirect3DVolumeTexture8_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DVolumeTexture8_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DVolumeTexture8_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DVolumeTexture8_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DVolumeTexture8_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DVolumeTexture8_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DVolumeTexture8_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DVolumeTexture8_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DVolumeTexture8 methods: IDirect3DBaseTexture8 ***/
#define IDirect3DVolumeTexture8_SetLOD(p,a)                  (p)->lpVtbl->SetLOD(p,a)
#define IDirect3DVolumeTexture8_GetLOD(p)                    (p)->lpVtbl->GetLOD(p)
#define IDirect3DVolumeTexture8_GetLevelCount(p)             (p)->lpVtbl->GetLevelCount(p)
/*** IDirect3DVolumeTexture8 methods ***/
#define IDirect3DVolumeTexture8_GetLevelDesc(p,a,b)          (p)->lpVtbl->GetLevelDesc(p,a,b)
#define IDirect3DVolumeTexture8_GetVolumeLevel(p,a,b)        (p)->lpVtbl->GetVolumeLevel(p,a,b)
#define IDirect3DVolumeTexture8_LockBox(p,a,b,c,d)           (p)->lpVtbl->LockBox(p,a,b,c,d)
#define IDirect3DVolumeTexture8_UnlockBox(p,a)               (p)->lpVtbl->UnlockBox(p,a)
#define IDirect3DVolumeTexture8_AddDirtyBox(p,a)             (p)->lpVtbl->AddDirtyBox(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DVolumeTexture8_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DVolumeTexture8_AddRef(p)                    (p)->AddRef()
#define IDirect3DVolumeTexture8_Release(p)                   (p)->Release()
/*** IDirect3DVolumeTexture8 methods: IDirect3DResource8 ***/
#define IDirect3DVolumeTexture8_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DVolumeTexture8_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DVolumeTexture8_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DVolumeTexture8_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DVolumeTexture8_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DVolumeTexture8_GetPriority(p)               (p)->GetPriority()
#define IDirect3DVolumeTexture8_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DVolumeTexture8_GetType(p)                   (p)->GetType()
/*** IDirect3DVolumeTexture8 methods: IDirect3DBaseTexture8 ***/
#define IDirect3DVolumeTexture8_SetLOD(p,a)                  (p)->SetLOD(a)
#define IDirect3DVolumeTexture8_GetLOD(p)                    (p)->GetLOD()
#define IDirect3DVolumeTexture8_GetLevelCount(p)             (p)->GetLevelCount()
/*** IDirect3DVolumeTexture8 methods ***/
#define IDirect3DVolumeTexture8_GetLevelDesc(p,a,b)          (p)->GetLevelDesc(a,b)
#define IDirect3DVolumeTexture8_GetVolumeLevel(p,a,b)        (p)->GetVolumeLevel(a,b)
#define IDirect3DVolumeTexture8_LockBox(p,a,b,c,d)           (p)->LockBox(a,b,c,d)
#define IDirect3DVolumeTexture8_UnlockBox(p,a)               (p)->UnlockBox(a)
#define IDirect3DVolumeTexture8_AddDirtyBox(p,a)             (p)->AddDirtyBox(a)
#endif

/*****************************************************************************
 * IDirect3DDevice8 interface
 */
#define INTERFACE IDirect3DDevice8
DECLARE_INTERFACE_IID_(IDirect3DDevice8,IUnknown,"7385e5df-8fe8-41d5-86b6-d7b48547b6cf")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DDevice8 methods ***/
    STDMETHOD(TestCooperativeLevel)(THIS) PURE;
    STDMETHOD_(UINT,GetAvailableTextureMem)(THIS) PURE;
    STDMETHOD(ResourceManagerDiscardBytes)(THIS_ DWORD  Bytes) PURE;
    STDMETHOD(GetDirect3D)(THIS_ IDirect3D8 ** ppD3D8) PURE;
    STDMETHOD(GetDeviceCaps)(THIS_ D3DCAPS8 * pCaps) PURE;
    STDMETHOD(GetDisplayMode)(THIS_ D3DDISPLAYMODE * pMode) PURE;
    STDMETHOD(GetCreationParameters)(THIS_ D3DDEVICE_CREATION_PARAMETERS  * pParameters) PURE;
    STDMETHOD(SetCursorProperties)(THIS_ UINT  XHotSpot, UINT  YHotSpot, IDirect3DSurface8 * pCursorBitmap) PURE;
    STDMETHOD_(void,SetCursorPosition)(THIS_ UINT  XScreenSpace, UINT  YScreenSpace,DWORD  Flags) PURE;
    STDMETHOD_(WINBOOL,ShowCursor)(THIS_ WINBOOL  bShow) PURE;
    STDMETHOD(CreateAdditionalSwapChain)(THIS_ D3DPRESENT_PARAMETERS * pPresentationParameters, IDirect3DSwapChain8 ** pSwapChain) PURE;
    STDMETHOD(Reset)(THIS_ D3DPRESENT_PARAMETERS * pPresentationParameters) PURE;
    STDMETHOD(Present)(THIS_ const RECT *src_rect, const RECT *dst_rect, HWND dst_window_override,
            const RGNDATA *dirty_region) PURE;
    STDMETHOD(GetBackBuffer)(THIS_ UINT  BackBuffer,D3DBACKBUFFER_TYPE  Type,IDirect3DSurface8 ** ppBackBuffer) PURE;
    STDMETHOD(GetRasterStatus)(THIS_ D3DRASTER_STATUS * pRasterStatus) PURE;
    STDMETHOD_(void, SetGammaRamp)(THIS_ DWORD flags, const D3DGAMMARAMP *ramp) PURE;
    STDMETHOD_(void,GetGammaRamp)(THIS_ D3DGAMMARAMP * pRamp) PURE;
    STDMETHOD(CreateTexture)(THIS_ UINT  Width,UINT  Height,UINT  Levels,DWORD  Usage,D3DFORMAT  Format,D3DPOOL  Pool,IDirect3DTexture8 ** ppTexture) PURE;
    STDMETHOD(CreateVolumeTexture)(THIS_ UINT  Width,UINT  Height,UINT  Depth,UINT  Levels,DWORD  Usage,D3DFORMAT  Format,D3DPOOL  Pool,IDirect3DVolumeTexture8 ** ppVolumeTexture) PURE;
    STDMETHOD(CreateCubeTexture)(THIS_ UINT  EdgeLength,UINT  Levels,DWORD  Usage,D3DFORMAT  Format,D3DPOOL  Pool,IDirect3DCubeTexture8 ** ppCubeTexture) PURE;
    STDMETHOD(CreateVertexBuffer)(THIS_ UINT  Length,DWORD  Usage,DWORD  FVF,D3DPOOL  Pool,IDirect3DVertexBuffer8 ** ppVertexBuffer) PURE;
    STDMETHOD(CreateIndexBuffer)(THIS_ UINT  Length,DWORD  Usage,D3DFORMAT  Format,D3DPOOL  Pool,IDirect3DIndexBuffer8 ** ppIndexBuffer) PURE;
    STDMETHOD(CreateRenderTarget)(THIS_ UINT  Width,UINT  Height,D3DFORMAT  Format,D3DMULTISAMPLE_TYPE  MultiSample,WINBOOL  Lockable,IDirect3DSurface8 ** ppSurface) PURE;
    STDMETHOD(CreateDepthStencilSurface)(THIS_ UINT  Width,UINT  Height,D3DFORMAT  Format,D3DMULTISAMPLE_TYPE  MultiSample,IDirect3DSurface8 ** ppSurface) PURE;
    STDMETHOD(CreateImageSurface)(THIS_ UINT  Width,UINT  Height,D3DFORMAT  Format,IDirect3DSurface8 ** ppSurface) PURE;
    STDMETHOD(CopyRects)(THIS_ IDirect3DSurface8 *src_surface, const RECT *src_rects,
            UINT rect_count, IDirect3DSurface8 *dst_surface, const POINT *dst_points) PURE;
    STDMETHOD(UpdateTexture)(THIS_ IDirect3DBaseTexture8 * pSourceTexture,IDirect3DBaseTexture8 * pDestinationTexture) PURE;
    STDMETHOD(GetFrontBuffer)(THIS_ IDirect3DSurface8 * pDestSurface) PURE;
    STDMETHOD(SetRenderTarget)(THIS_ IDirect3DSurface8 * pRenderTarget,IDirect3DSurface8 * pNewZStencil) PURE;
    STDMETHOD(GetRenderTarget)(THIS_ IDirect3DSurface8 ** ppRenderTarget) PURE;
    STDMETHOD(GetDepthStencilSurface)(THIS_ IDirect3DSurface8 ** ppZStencilSurface) PURE;
    STDMETHOD(BeginScene)(THIS) PURE;
    STDMETHOD(EndScene)(THIS) PURE;
    STDMETHOD(Clear)(THIS_ DWORD rect_count, const D3DRECT *rects, DWORD flags, D3DCOLOR color,
            float z, DWORD stencil) PURE;
    STDMETHOD(SetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, const D3DMATRIX *matrix) PURE;
    STDMETHOD(GetTransform)(THIS_ D3DTRANSFORMSTATETYPE  State,D3DMATRIX * pMatrix) PURE;
    STDMETHOD(MultiplyTransform)(THIS_ D3DTRANSFORMSTATETYPE state, const D3DMATRIX *matrix) PURE;
    STDMETHOD(SetViewport)(THIS_ const D3DVIEWPORT8 *viewport) PURE;
    STDMETHOD(GetViewport)(THIS_ D3DVIEWPORT8 * pViewport) PURE;
    STDMETHOD(SetMaterial)(THIS_ const D3DMATERIAL8 *material) PURE;
    STDMETHOD(GetMaterial)(THIS_ D3DMATERIAL8 *pMaterial) PURE;
    STDMETHOD(SetLight)(THIS_ DWORD index, const D3DLIGHT8 *light) PURE;
    STDMETHOD(GetLight)(THIS_ DWORD  Index,D3DLIGHT8 * pLight) PURE;
    STDMETHOD(LightEnable)(THIS_ DWORD  Index,WINBOOL  Enable) PURE;
    STDMETHOD(GetLightEnable)(THIS_ DWORD  Index,WINBOOL * pEnable) PURE;
    STDMETHOD(SetClipPlane)(THIS_ DWORD index, const float *plane) PURE;
    STDMETHOD(GetClipPlane)(THIS_ DWORD  Index,float * pPlane) PURE;
    STDMETHOD(SetRenderState)(THIS_ D3DRENDERSTATETYPE  State,DWORD  Value) PURE;
    STDMETHOD(GetRenderState)(THIS_ D3DRENDERSTATETYPE  State,DWORD * pValue) PURE;
    STDMETHOD(BeginStateBlock)(THIS) PURE;
    STDMETHOD(EndStateBlock)(THIS_ DWORD * pToken) PURE;
    STDMETHOD(ApplyStateBlock)(THIS_ DWORD  Token) PURE;
    STDMETHOD(CaptureStateBlock)(THIS_ DWORD  Token) PURE;
    STDMETHOD(DeleteStateBlock)(THIS_ DWORD  Token) PURE;
    STDMETHOD(CreateStateBlock)(THIS_ D3DSTATEBLOCKTYPE  Type,DWORD * pToken) PURE;
    STDMETHOD(SetClipStatus)(THIS_ const D3DCLIPSTATUS8 *clip_status) PURE;
    STDMETHOD(GetClipStatus)(THIS_ D3DCLIPSTATUS8 * pClipStatus) PURE;
    STDMETHOD(GetTexture)(THIS_ DWORD  Stage,IDirect3DBaseTexture8 ** ppTexture) PURE;
    STDMETHOD(SetTexture)(THIS_ DWORD  Stage,IDirect3DBaseTexture8 * pTexture) PURE;
    STDMETHOD(GetTextureStageState)(THIS_ DWORD  Stage,D3DTEXTURESTAGESTATETYPE  Type,DWORD * pValue) PURE;
    STDMETHOD(SetTextureStageState)(THIS_ DWORD  Stage,D3DTEXTURESTAGESTATETYPE  Type,DWORD  Value) PURE;
    STDMETHOD(ValidateDevice)(THIS_ DWORD * pNumPasses) PURE;
    STDMETHOD(GetInfo)(THIS_ DWORD  DevInfoID,void * pDevInfoStruct,DWORD  DevInfoStructSize) PURE;
    STDMETHOD(SetPaletteEntries)(THIS_ UINT palette_idx, const PALETTEENTRY *entries) PURE;
    STDMETHOD(GetPaletteEntries)(THIS_ UINT  PaletteNumber,PALETTEENTRY * pEntries) PURE;
    STDMETHOD(SetCurrentTexturePalette)(THIS_ UINT  PaletteNumber) PURE;
    STDMETHOD(GetCurrentTexturePalette)(THIS_ UINT  * PaletteNumber) PURE;
    STDMETHOD(DrawPrimitive)(THIS_ D3DPRIMITIVETYPE  PrimitiveType,UINT  StartVertex,UINT  PrimitiveCount) PURE;
    STDMETHOD(DrawIndexedPrimitive)(THIS_ D3DPRIMITIVETYPE  PrimitiveType,UINT  minIndex,UINT  NumVertices,UINT  startIndex,UINT  primCount) PURE;
    STDMETHOD(DrawPrimitiveUP)(THIS_ D3DPRIMITIVETYPE primitive_type, UINT primitive_count,
            const void *data, UINT stride) PURE;
    STDMETHOD(DrawIndexedPrimitiveUP)(THIS_ D3DPRIMITIVETYPE primitive_type, UINT min_vertex_idx,
            UINT vertex_count, UINT primitive_count, const void *index_data, D3DFORMAT index_format,
            const void *data, UINT stride) PURE;
    STDMETHOD(ProcessVertices)(THIS_ UINT  SrcStartIndex,UINT  DestIndex,UINT  VertexCount,IDirect3DVertexBuffer8 * pDestBuffer,DWORD  Flags) PURE;
    STDMETHOD(CreateVertexShader)(THIS_ const DWORD *declaration, const DWORD *byte_code,
            DWORD *shader, DWORD usage) PURE;
    STDMETHOD(SetVertexShader)(THIS_ DWORD  Handle) PURE;
    STDMETHOD(GetVertexShader)(THIS_ DWORD * pHandle) PURE;
    STDMETHOD(DeleteVertexShader)(THIS_ DWORD  Handle) PURE;
    STDMETHOD(SetVertexShaderConstant)(THIS_ DWORD reg_idx, const void *data, DWORD count) PURE;
    STDMETHOD(GetVertexShaderConstant)(THIS_ DWORD  Register,void * pConstantData,DWORD  ConstantCount) PURE;
    STDMETHOD(GetVertexShaderDeclaration)(THIS_ DWORD  Handle,void * pData,DWORD * pSizeOfData) PURE;
    STDMETHOD(GetVertexShaderFunction)(THIS_ DWORD  Handle,void * pData,DWORD * pSizeOfData) PURE;
    STDMETHOD(SetStreamSource)(THIS_ UINT  StreamNumber,IDirect3DVertexBuffer8 * pStreamData,UINT  Stride) PURE;
    STDMETHOD(GetStreamSource)(THIS_ UINT  StreamNumber,IDirect3DVertexBuffer8 ** ppStreamData,UINT * pStride) PURE;
    STDMETHOD(SetIndices)(THIS_ IDirect3DIndexBuffer8 * pIndexData,UINT  BaseVertexIndex) PURE;
    STDMETHOD(GetIndices)(THIS_ IDirect3DIndexBuffer8 ** ppIndexData,UINT * pBaseVertexIndex) PURE;
    STDMETHOD(CreatePixelShader)(THIS_ const DWORD *byte_code, DWORD *shader) PURE;
    STDMETHOD(SetPixelShader)(THIS_ DWORD  Handle) PURE;
    STDMETHOD(GetPixelShader)(THIS_ DWORD * pHandle) PURE;
    STDMETHOD(DeletePixelShader)(THIS_ DWORD  Handle) PURE;
    STDMETHOD(SetPixelShaderConstant)(THIS_ DWORD reg_idx, const void *data, DWORD count) PURE;
    STDMETHOD(GetPixelShaderConstant)(THIS_ DWORD  Register,void * pConstantData,DWORD  ConstantCount) PURE;
    STDMETHOD(GetPixelShaderFunction)(THIS_ DWORD  Handle,void * pData,DWORD * pSizeOfData) PURE;
    STDMETHOD(DrawRectPatch)(THIS_ UINT handle, const float *segment_count,
            const D3DRECTPATCH_INFO *patch_info) PURE;
    STDMETHOD(DrawTriPatch)(THIS_ UINT handle, const float *segment_count,
            const D3DTRIPATCH_INFO *patch_info) PURE;
    STDMETHOD(DeletePatch)(THIS_ UINT  Handle) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DDevice8_QueryInterface(p,a,b)                     (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DDevice8_AddRef(p)                                 (p)->lpVtbl->AddRef(p)
#define IDirect3DDevice8_Release(p)                                (p)->lpVtbl->Release(p)
/*** IDirect3DDevice8 methods ***/
#define IDirect3DDevice8_TestCooperativeLevel(p)                   (p)->lpVtbl->TestCooperativeLevel(p)
#define IDirect3DDevice8_GetAvailableTextureMem(p)                 (p)->lpVtbl->GetAvailableTextureMem(p)
#define IDirect3DDevice8_ResourceManagerDiscardBytes(p,a)          (p)->lpVtbl->ResourceManagerDiscardBytes(p,a)
#define IDirect3DDevice8_GetDirect3D(p,a)                          (p)->lpVtbl->GetDirect3D(p,a)
#define IDirect3DDevice8_GetDeviceCaps(p,a)                        (p)->lpVtbl->GetDeviceCaps(p,a)
#define IDirect3DDevice8_GetDisplayMode(p,a)                       (p)->lpVtbl->GetDisplayMode(p,a)
#define IDirect3DDevice8_GetCreationParameters(p,a)                (p)->lpVtbl->GetCreationParameters(p,a)
#define IDirect3DDevice8_SetCursorProperties(p,a,b,c)              (p)->lpVtbl->SetCursorProperties(p,a,b,c)
#define IDirect3DDevice8_SetCursorPosition(p,a,b,c)                (p)->lpVtbl->SetCursorPosition(p,a,b,c)
#define IDirect3DDevice8_ShowCursor(p,a)                           (p)->lpVtbl->ShowCursor(p,a)
#define IDirect3DDevice8_CreateAdditionalSwapChain(p,a,b)          (p)->lpVtbl->CreateAdditionalSwapChain(p,a,b)
#define IDirect3DDevice8_Reset(p,a)                                (p)->lpVtbl->Reset(p,a)
#define IDirect3DDevice8_Present(p,a,b,c,d)                        (p)->lpVtbl->Present(p,a,b,c,d)
#define IDirect3DDevice8_GetBackBuffer(p,a,b,c)                    (p)->lpVtbl->GetBackBuffer(p,a,b,c)
#define IDirect3DDevice8_GetRasterStatus(p,a)                      (p)->lpVtbl->GetRasterStatus(p,a)
#define IDirect3DDevice8_SetGammaRamp(p,a,b)                       (p)->lpVtbl->SetGammaRamp(p,a,b)
#define IDirect3DDevice8_GetGammaRamp(p,a)                         (p)->lpVtbl->GetGammaRamp(p,a)
#define IDirect3DDevice8_CreateTexture(p,a,b,c,d,e,f,g)            (p)->lpVtbl->CreateTexture(p,a,b,c,d,e,f,g)
#define IDirect3DDevice8_CreateVolumeTexture(p,a,b,c,d,e,f,g,h)    (p)->lpVtbl->CreateVolumeTexture(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice8_CreateCubeTexture(p,a,b,c,d,e,f)          (p)->lpVtbl->CreateCubeTexture(p,a,b,c,d,e,f)
#define IDirect3DDevice8_CreateVertexBuffer(p,a,b,c,d,e)           (p)->lpVtbl->CreateVertexBuffer(p,a,b,c,d,e)
#define IDirect3DDevice8_CreateIndexBuffer(p,a,b,c,d,e)            (p)->lpVtbl->CreateIndexBuffer(p,a,b,c,d,e)
#define IDirect3DDevice8_CreateRenderTarget(p,a,b,c,d,e,f)         (p)->lpVtbl->CreateRenderTarget(p,a,b,c,d,e,f)
#define IDirect3DDevice8_CreateDepthStencilSurface(p,a,b,c,d,e)    (p)->lpVtbl->CreateDepthStencilSurface(p,a,b,c,d,e)
#define IDirect3DDevice8_CreateImageSurface(p,a,b,c,d)             (p)->lpVtbl->CreateImageSurface(p,a,b,c,d)
#define IDirect3DDevice8_CopyRects(p,a,b,c,d,e)                    (p)->lpVtbl->CopyRects(p,a,b,c,d,e)
#define IDirect3DDevice8_UpdateTexture(p,a,b)                      (p)->lpVtbl->UpdateTexture(p,a,b)
#define IDirect3DDevice8_GetFrontBuffer(p,a)                       (p)->lpVtbl->GetFrontBuffer(p,a)
#define IDirect3DDevice8_SetRenderTarget(p,a,b)                    (p)->lpVtbl->SetRenderTarget(p,a,b)
#define IDirect3DDevice8_GetRenderTarget(p,a)                      (p)->lpVtbl->GetRenderTarget(p,a)
#define IDirect3DDevice8_GetDepthStencilSurface(p,a)               (p)->lpVtbl->GetDepthStencilSurface(p,a)
#define IDirect3DDevice8_BeginScene(p)                             (p)->lpVtbl->BeginScene(p)
#define IDirect3DDevice8_EndScene(p)                               (p)->lpVtbl->EndScene(p)
#define IDirect3DDevice8_Clear(p,a,b,c,d,e,f)                      (p)->lpVtbl->Clear(p,a,b,c,d,e,f)
#define IDirect3DDevice8_SetTransform(p,a,b)                       (p)->lpVtbl->SetTransform(p,a,b)
#define IDirect3DDevice8_GetTransform(p,a,b)                       (p)->lpVtbl->GetTransform(p,a,b)
#define IDirect3DDevice8_MultiplyTransform(p,a,b)                  (p)->lpVtbl->MultiplyTransform(p,a,b)
#define IDirect3DDevice8_SetViewport(p,a)                          (p)->lpVtbl->SetViewport(p,a)
#define IDirect3DDevice8_GetViewport(p,a)                          (p)->lpVtbl->GetViewport(p,a)
#define IDirect3DDevice8_SetMaterial(p,a)                          (p)->lpVtbl->SetMaterial(p,a)
#define IDirect3DDevice8_GetMaterial(p,a)                          (p)->lpVtbl->GetMaterial(p,a)
#define IDirect3DDevice8_SetLight(p,a,b)                           (p)->lpVtbl->SetLight(p,a,b)
#define IDirect3DDevice8_GetLight(p,a,b)                           (p)->lpVtbl->GetLight(p,a,b)
#define IDirect3DDevice8_LightEnable(p,a,b)                        (p)->lpVtbl->LightEnable(p,a,b)
#define IDirect3DDevice8_GetLightEnable(p,a,b)                     (p)->lpVtbl->GetLightEnable(p,a,b)
#define IDirect3DDevice8_SetClipPlane(p,a,b)                       (p)->lpVtbl->SetClipPlane(p,a,b)
#define IDirect3DDevice8_GetClipPlane(p,a,b)                       (p)->lpVtbl->GetClipPlane(p,a,b)
#define IDirect3DDevice8_SetRenderState(p,a,b)                     (p)->lpVtbl->SetRenderState(p,a,b)
#define IDirect3DDevice8_GetRenderState(p,a,b)                     (p)->lpVtbl->GetRenderState(p,a,b)
#define IDirect3DDevice8_BeginStateBlock(p)                        (p)->lpVtbl->BeginStateBlock(p)
#define IDirect3DDevice8_EndStateBlock(p,a)                        (p)->lpVtbl->EndStateBlock(p,a)
#define IDirect3DDevice8_ApplyStateBlock(p,a)                      (p)->lpVtbl->ApplyStateBlock(p,a)
#define IDirect3DDevice8_CaptureStateBlock(p,a)                    (p)->lpVtbl->CaptureStateBlock(p,a)
#define IDirect3DDevice8_DeleteStateBlock(p,a)                     (p)->lpVtbl->DeleteStateBlock(p,a)
#define IDirect3DDevice8_CreateStateBlock(p,a,b)                   (p)->lpVtbl->CreateStateBlock(p,a,b)
#define IDirect3DDevice8_SetClipStatus(p,a)                        (p)->lpVtbl->SetClipStatus(p,a)
#define IDirect3DDevice8_GetClipStatus(p,a)                        (p)->lpVtbl->GetClipStatus(p,a)
#define IDirect3DDevice8_GetTexture(p,a,b)                         (p)->lpVtbl->GetTexture(p,a,b)
#define IDirect3DDevice8_SetTexture(p,a,b)                         (p)->lpVtbl->SetTexture(p,a,b)
#define IDirect3DDevice8_GetTextureStageState(p,a,b,c)             (p)->lpVtbl->GetTextureStageState(p,a,b,c)
#define IDirect3DDevice8_SetTextureStageState(p,a,b,c)             (p)->lpVtbl->SetTextureStageState(p,a,b,c)
#define IDirect3DDevice8_ValidateDevice(p,a)                       (p)->lpVtbl->ValidateDevice(p,a)
#define IDirect3DDevice8_GetInfo(p,a,b,c)                          (p)->lpVtbl->GetInfo(p,a,b,c)
#define IDirect3DDevice8_SetPaletteEntries(p,a,b)                  (p)->lpVtbl->SetPaletteEntries(p,a,b)
#define IDirect3DDevice8_GetPaletteEntries(p,a,b)                  (p)->lpVtbl->GetPaletteEntries(p,a,b)
#define IDirect3DDevice8_SetCurrentTexturePalette(p,a)             (p)->lpVtbl->SetCurrentTexturePalette(p,a)
#define IDirect3DDevice8_GetCurrentTexturePalette(p,a)             (p)->lpVtbl->GetCurrentTexturePalette(p,a)
#define IDirect3DDevice8_DrawPrimitive(p,a,b,c)                    (p)->lpVtbl->DrawPrimitive(p,a,b,c)
#define IDirect3DDevice8_DrawIndexedPrimitive(p,a,b,c,d,e)         (p)->lpVtbl->DrawIndexedPrimitive(p,a,b,c,d,e)
#define IDirect3DDevice8_DrawPrimitiveUP(p,a,b,c,d)                (p)->lpVtbl->DrawPrimitiveUP(p,a,b,c,d)
#define IDirect3DDevice8_DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h) (p)->lpVtbl->DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice8_ProcessVertices(p,a,b,c,d,e)              (p)->lpVtbl->ProcessVertices(p,a,b,c,d,e)
#define IDirect3DDevice8_CreateVertexShader(p,a,b,c,d)             (p)->lpVtbl->CreateVertexShader(p,a,b,c,d)
#define IDirect3DDevice8_SetVertexShader(p,a)                      (p)->lpVtbl->SetVertexShader(p,a)
#define IDirect3DDevice8_GetVertexShader(p,a)                      (p)->lpVtbl->GetVertexShader(p,a)
#define IDirect3DDevice8_DeleteVertexShader(p,a)                   (p)->lpVtbl->DeleteVertexShader(p,a)
#define IDirect3DDevice8_SetVertexShaderConstant(p,a,b,c)          (p)->lpVtbl->SetVertexShaderConstant(p,a,b,c)
#define IDirect3DDevice8_GetVertexShaderConstant(p,a,b,c)          (p)->lpVtbl->GetVertexShaderConstant(p,a,b,c)
#define IDirect3DDevice8_GetVertexShaderDeclaration(p,a,b,c)       (p)->lpVtbl->GetVertexShaderDeclaration(p,a,b,c)
#define IDirect3DDevice8_GetVertexShaderFunction(p,a,b,c)          (p)->lpVtbl->GetVertexShaderFunction(p,a,b,c)
#define IDirect3DDevice8_SetStreamSource(p,a,b,c)                  (p)->lpVtbl->SetStreamSource(p,a,b,c)
#define IDirect3DDevice8_GetStreamSource(p,a,b,c)                  (p)->lpVtbl->GetStreamSource(p,a,b,c)
#define IDirect3DDevice8_SetIndices(p,a,b)                         (p)->lpVtbl->SetIndices(p,a,b)
#define IDirect3DDevice8_GetIndices(p,a,b)                         (p)->lpVtbl->GetIndices(p,a,b)
#define IDirect3DDevice8_CreatePixelShader(p,a,b)                  (p)->lpVtbl->CreatePixelShader(p,a,b)
#define IDirect3DDevice8_SetPixelShader(p,a)                       (p)->lpVtbl->SetPixelShader(p,a)
#define IDirect3DDevice8_GetPixelShader(p,a)                       (p)->lpVtbl->GetPixelShader(p,a)
#define IDirect3DDevice8_DeletePixelShader(p,a)                    (p)->lpVtbl->DeletePixelShader(p,a)
#define IDirect3DDevice8_SetPixelShaderConstant(p,a,b,c)           (p)->lpVtbl->SetPixelShaderConstant(p,a,b,c)
#define IDirect3DDevice8_GetPixelShaderConstant(p,a,b,c)           (p)->lpVtbl->GetPixelShaderConstant(p,a,b,c)
#define IDirect3DDevice8_GetPixelShaderFunction(p,a,b,c)           (p)->lpVtbl->GetPixelShaderFunction(p,a,b,c)
#define IDirect3DDevice8_DrawRectPatch(p,a,b,c)                    (p)->lpVtbl->DrawRectPatch(p,a,b,c)
#define IDirect3DDevice8_DrawTriPatch(p,a,b,c)                     (p)->lpVtbl->DrawTriPatch(p,a,b,c)
#define IDirect3DDevice8_DeletePatch(p,a)                          (p)->lpVtbl->DeletePatch(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DDevice8_QueryInterface(p,a,b)                     (p)->QueryInterface(a,b)
#define IDirect3DDevice8_AddRef(p)                                 (p)->AddRef()
#define IDirect3DDevice8_Release(p)                                (p)->Release()
/*** IDirect3DDevice8 methods ***/
#define IDirect3DDevice8_TestCooperativeLevel(p)                   (p)->TestCooperativeLevel()
#define IDirect3DDevice8_GetAvailableTextureMem(p)                 (p)->GetAvailableTextureMem()
#define IDirect3DDevice8_ResourceManagerDiscardBytes(p,a)          (p)->ResourceManagerDiscardBytes(a)
#define IDirect3DDevice8_GetDirect3D(p,a)                          (p)->GetDirect3D(a)
#define IDirect3DDevice8_GetDeviceCaps(p,a)                        (p)->GetDeviceCaps(a)
#define IDirect3DDevice8_GetDisplayMode(p,a)                       (p)->GetDisplayMode(a)
#define IDirect3DDevice8_GetCreationParameters(p,a)                (p)->GetCreationParameters(a)
#define IDirect3DDevice8_SetCursorProperties(p,a,b,c)              (p)->SetCursorProperties(a,b,c)
#define IDirect3DDevice8_SetCursorPosition(p,a,b,c)                (p)->SetCursorPosition(a,b,c)
#define IDirect3DDevice8_ShowCursor(p,a)                           (p)->ShowCursor(a)
#define IDirect3DDevice8_CreateAdditionalSwapChain(p,a,b)          (p)->CreateAdditionalSwapChain(a,b)
#define IDirect3DDevice8_Reset(p,a)                                (p)->Reset(a)
#define IDirect3DDevice8_Present(p,a,b,c,d)                        (p)->Present(a,b,c,d)
#define IDirect3DDevice8_GetBackBuffer(p,a,b,c)                    (p)->GetBackBuffer(a,b,c)
#define IDirect3DDevice8_GetRasterStatus(p,a)                      (p)->GetRasterStatus(a)
#define IDirect3DDevice8_SetGammaRamp(p,a,b)                       (p)->SetGammaRamp(a,b)
#define IDirect3DDevice8_GetGammaRamp(p,a)                         (p)->GetGammaRamp(a)
#define IDirect3DDevice8_CreateTexture(p,a,b,c,d,e,f,g)            (p)->CreateTexture(a,b,c,d,e,f,g)
#define IDirect3DDevice8_CreateVolumeTexture(p,a,b,c,d,e,f,g,h)    (p)->CreateVolumeTexture(a,b,c,d,e,f,g,h)
#define IDirect3DDevice8_CreateCubeTexture(p,a,b,c,d,e,f)          (p)->CreateCubeTexture(a,b,c,d,e,f)
#define IDirect3DDevice8_CreateVertexBuffer(p,a,b,c,d,e)           (p)->CreateVertexBuffer(a,b,c,d,e)
#define IDirect3DDevice8_CreateIndexBuffer(p,a,b,c,d,e)            (p)->CreateIndexBuffer(a,b,c,d,e)
#define IDirect3DDevice8_CreateRenderTarget(p,a,b,c,d,e,f)         (p)->CreateRenderTarget(a,b,c,d,e,f)
#define IDirect3DDevice8_CreateDepthStencilSurface(p,a,b,c,d,e)    (p)->CreateDepthStencilSurface(a,b,c,d,e)
#define IDirect3DDevice8_CreateImageSurface(p,a,b,c,d)             (p)->CreateImageSurface(a,b,c,d)
#define IDirect3DDevice8_CopyRects(p,a,b,c,d,e)                    (p)->CopyRects(a,b,c,d,e)
#define IDirect3DDevice8_UpdateTexture(p,a,b)                      (p)->UpdateTexture(a,b)
#define IDirect3DDevice8_GetFrontBuffer(p,a)                       (p)->GetFrontBuffer(a)
#define IDirect3DDevice8_SetRenderTarget(p,a,b)                    (p)->SetRenderTarget(a,b)
#define IDirect3DDevice8_GetRenderTarget(p,a)                      (p)->GetRenderTarget(a)
#define IDirect3DDevice8_GetDepthStencilSurface(p,a)               (p)->GetDepthStencilSurface(a)
#define IDirect3DDevice8_BeginScene(p)                             (p)->BeginScene()
#define IDirect3DDevice8_EndScene(p)                               (p)->EndScene()
#define IDirect3DDevice8_Clear(p,a,b,c,d,e,f)                      (p)->Clear(a,b,c,d,e,f)
#define IDirect3DDevice8_SetTransform(p,a,b)                       (p)->SetTransform(a,b)
#define IDirect3DDevice8_GetTransform(p,a,b)                       (p)->GetTransform(a,b)
#define IDirect3DDevice8_MultiplyTransform(p,a,b)                  (p)->MultiplyTransform(a,b)
#define IDirect3DDevice8_SetViewport(p,a)                          (p)->SetViewport(a)
#define IDirect3DDevice8_GetViewport(p,a)                          (p)->GetViewport(a)
#define IDirect3DDevice8_SetMaterial(p,a)                          (p)->SetMaterial(a)
#define IDirect3DDevice8_GetMaterial(p,a)                          (p)->GetMaterial(a)
#define IDirect3DDevice8_SetLight(p,a,b)                           (p)->SetLight(a,b)
#define IDirect3DDevice8_GetLight(p,a,b)                           (p)->GetLight(a,b)
#define IDirect3DDevice8_LightEnable(p,a,b)                        (p)->LightEnable(a,b)
#define IDirect3DDevice8_GetLightEnable(p,a,b)                     (p)->GetLightEnable(a,b)
#define IDirect3DDevice8_SetClipPlane(p,a,b)                       (p)->SetClipPlane(a,b)
#define IDirect3DDevice8_GetClipPlane(p,a,b)                       (p)->GetClipPlane(a,b)
#define IDirect3DDevice8_SetRenderState(p,a,b)                     (p)->SetRenderState(a,b)
#define IDirect3DDevice8_GetRenderState(p,a,b)                     (p)->GetRenderState(a,b)
#define IDirect3DDevice8_BeginStateBlock(p)                        (p)->BeginStateBlock()
#define IDirect3DDevice8_EndStateBlock(p,a)                        (p)->EndStateBlock(a)
#define IDirect3DDevice8_ApplyStateBlock(p,a)                      (p)->ApplyStateBlock(a)
#define IDirect3DDevice8_CaptureStateBlock(p,a)                    (p)->CaptureStateBlock(a)
#define IDirect3DDevice8_DeleteStateBlock(p,a)                     (p)->DeleteStateBlock(a)
#define IDirect3DDevice8_CreateStateBlock(p,a,b)                   (p)->CreateStateBlock(a,b)
#define IDirect3DDevice8_SetClipStatus(p,a)                        (p)->SetClipStatus(a)
#define IDirect3DDevice8_GetClipStatus(p,a)                        (p)->GetClipStatus(a)
#define IDirect3DDevice8_GetTexture(p,a,b)                         (p)->GetTexture(a,b)
#define IDirect3DDevice8_SetTexture(p,a,b)                         (p)->SetTexture(a,b)
#define IDirect3DDevice8_GetTextureStageState(p,a,b,c)             (p)->GetTextureStageState(a,b,c)
#define IDirect3DDevice8_SetTextureStageState(p,a,b,c)             (p)->SetTextureStageState(a,b,c)
#define IDirect3DDevice8_ValidateDevice(p,a)                       (p)->ValidateDevice(a)
#define IDirect3DDevice8_GetInfo(p,a,b,c)                          (p)->GetInfo(a,b,c)
#define IDirect3DDevice8_SetPaletteEntries(p,a,b)                  (p)->SetPaletteEntries(a,b)
#define IDirect3DDevice8_GetPaletteEntries(p,a,b)                  (p)->GetPaletteEntries(a,b)
#define IDirect3DDevice8_SetCurrentTexturePalette(p,a)             (p)->SetCurrentTexturePalette(a)
#define IDirect3DDevice8_GetCurrentTexturePalette(p,a)             (p)->GetCurrentTexturePalette(a)
#define IDirect3DDevice8_DrawPrimitive(p,a,b,c)                    (p)->DrawPrimitive(a,b,c)
#define IDirect3DDevice8_DrawIndexedPrimitive(p,a,b,c,d,e)         (p)->DrawIndexedPrimitive(a,b,c,d,e)
#define IDirect3DDevice8_DrawPrimitiveUP(p,a,b,c,d)                (p)->DrawPrimitiveUP(a,b,c,d)
#define IDirect3DDevice8_DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h) (p)->DrawIndexedPrimitiveUP(a,b,c,d,e,f,g,h)
#define IDirect3DDevice8_ProcessVertices(p,a,b,c,d,e)              (p)->ProcessVertices(a,b,c,d,e)
#define IDirect3DDevice8_CreateVertexShader(p,a,b,c,d)             (p)->CreateVertexShader(a,b,c,d)
#define IDirect3DDevice8_SetVertexShader(p,a)                      (p)->SetVertexShader(a)
#define IDirect3DDevice8_GetVertexShader(p,a)                      (p)->GetVertexShader(a)
#define IDirect3DDevice8_DeleteVertexShader(p,a)                   (p)->DeleteVertexShader(a)
#define IDirect3DDevice8_SetVertexShaderConstant(p,a,b,c)          (p)->SetVertexShaderConstant(a,b,c)
#define IDirect3DDevice8_GetVertexShaderConstant(p,a,b,c)          (p)->GetVertexShaderConstant(a,b,c)
#define IDirect3DDevice8_GetVertexShaderDeclaration(p,a,b,c)       (p)->GetVertexShaderDeclaration(a,b,c)
#define IDirect3DDevice8_GetVertexShaderFunction(p,a,b,c)          (p)->GetVertexShaderFunction(a,b,c)
#define IDirect3DDevice8_SetStreamSource(p,a,b,c)                  (p)->SetStreamSource(a,b,c)
#define IDirect3DDevice8_GetStreamSource(p,a,b,c)                  (p)->GetStreamSource(a,b,c)
#define IDirect3DDevice8_SetIndices(p,a,b)                         (p)->SetIndices(a,b)
#define IDirect3DDevice8_GetIndices(p,a,b)                         (p)->GetIndices(a,b)
#define IDirect3DDevice8_CreatePixelShader(p,a,b)                  (p)->CreatePixelShader(a,b)
#define IDirect3DDevice8_SetPixelShader(p,a)                       (p)->SetPixelShader(a)
#define IDirect3DDevice8_GetPixelShader(p,a)                       (p)->GetPixelShader(a)
#define IDirect3DDevice8_DeletePixelShader(p,a)                    (p)->DeletePixelShader(a)
#define IDirect3DDevice8_SetPixelShaderConstant(p,a,b,c)           (p)->SetPixelShaderConstant(a,b,c)
#define IDirect3DDevice8_GetPixelShaderConstant(p,a,b,c)           (p)->GetPixelShaderConstant(a,b,c)
#define IDirect3DDevice8_GetPixelShaderFunction(p,a,b,c)           (p)->GetPixelShaderFunction(a,b,c)
#define IDirect3DDevice8_DrawRectPatch(p,a,b,c)                    (p)->DrawRectPatch(a,b,c)
#define IDirect3DDevice8_DrawTriPatch(p,a,b,c)                     (p)->DrawTriPatch(a,b,c)
#define IDirect3DDevice8_DeletePatch(p,a)                          (p)->DeletePatch(a)
#endif

#ifdef __cplusplus
extern "C" {
#endif  /* defined(__cplusplus) */

/* Define the main entrypoint as well */
IDirect3D8* WINAPI Direct3DCreate8(UINT SDKVersion);

#ifdef __cplusplus
} /* extern "C" */
#endif /* defined(__cplusplus) */

#endif /* __WINE_D3D8_H */
