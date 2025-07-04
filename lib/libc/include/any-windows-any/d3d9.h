#undef INTERFACE
/*
 * Copyright (C) 2002-2003 Jason Edmeades
 *                         Raphael Junqueira
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

#ifndef _D3D9_H_
#define _D3D9_H_

#ifndef DIRECT3D_VERSION
#define DIRECT3D_VERSION  0x0900
#endif

#include <stdlib.h>

#define COM_NO_WINDOWS_H
#include <objbase.h>
#include <windows.h>
#include <d3d9types.h>
#include <d3d9caps.h>

/*****************************************************************************
 * Behavior Flags for IDirect3D8::CreateDevice
 */
#define D3DCREATE_FPU_PRESERVE                  __MSABI_LONG(0x00000002)
#define D3DCREATE_MULTITHREADED                 __MSABI_LONG(0x00000004)
#define D3DCREATE_PUREDEVICE                    __MSABI_LONG(0x00000010)
#define D3DCREATE_SOFTWARE_VERTEXPROCESSING     __MSABI_LONG(0x00000020)
#define D3DCREATE_HARDWARE_VERTEXPROCESSING     __MSABI_LONG(0x00000040)
#define D3DCREATE_MIXED_VERTEXPROCESSING        __MSABI_LONG(0x00000080)
#define D3DCREATE_DISABLE_DRIVER_MANAGEMENT     __MSABI_LONG(0x00000100)
#define D3DCREATE_ADAPTERGROUP_DEVICE           __MSABI_LONG(0x00000200)
#define D3DCREATE_DISABLE_DRIVER_MANAGEMENT_EX  __MSABI_LONG(0x00000400)
#define D3DCREATE_NOWINDOWCHANGES               __MSABI_LONG(0x00000800)
#define D3DCREATE_DISABLE_PSGP_THREADING        __MSABI_LONG(0x00002000)
#define D3DCREATE_ENABLE_PRESENTSTATS           __MSABI_LONG(0x00004000)
#define D3DCREATE_DISABLE_PRINTSCREEN           __MSABI_LONG(0x00008000)
#define D3DCREATE_SCREENSAVER                   __MSABI_LONG(0x10000000)

/*****************************************************************************
 * Flags for SetPrivateData
 */
#define D3DSPD_IUNKNOWN                         __MSABI_LONG(0x00000001)


/*****************************************************************************
 * #defines and error codes
 */
#define D3D_SDK_VERSION                         32
#define D3DADAPTER_DEFAULT                      0
#define D3DENUM_WHQL_LEVEL                      __MSABI_LONG(0x00000002)
#define D3DPRESENT_DONOTWAIT                    __MSABI_LONG(1)
#define D3DPRESENT_LINEAR_CONTENT               __MSABI_LONG(2)
#define D3DPRESENT_BACK_BUFFERS_MAX             __MSABI_LONG(3)
#define D3DPRESENT_BACK_BUFFERS_MAX_EX          __MSABI_LONG(30)
#define D3DSGR_NO_CALIBRATION                   __MSABI_LONG(0x00000000)
#define D3DSGR_CALIBRATE                        __MSABI_LONG(0x00000001)
#define D3DCURSOR_IMMEDIATE_UPDATE              __MSABI_LONG(0x00000001)

#define _FACD3D  0x876
#define MAKE_D3DHRESULT( code )                 MAKE_HRESULT( 1, _FACD3D, code )
#define MAKE_D3DSTATUS( code )                  MAKE_HRESULT( 0, _FACD3D, code )

/*****************************************************************************
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
#define D3DERR_WASSTILLDRAWING                  MAKE_D3DHRESULT(540)
#define D3DOK_NOAUTOGEN                         MAKE_D3DSTATUS(2159)

#define D3DERR_DEVICEREMOVED                    MAKE_D3DHRESULT(2160)
#define D3DERR_DEVICEHUNG                       MAKE_D3DHRESULT(2164)
#define S_NOT_RESIDENT                          MAKE_D3DSTATUS(2165)
#define S_RESIDENT_IN_SHARED_MEMORY             MAKE_D3DSTATUS(2166)
#define S_PRESENT_MODE_CHANGED                  MAKE_D3DSTATUS(2167)
#define S_PRESENT_OCCLUDED                      MAKE_D3DSTATUS(2168)
#define D3DERR_UNSUPPORTEDOVERLAY               MAKE_D3DHRESULT(2171)
#define D3DERR_UNSUPPORTEDOVERLAYFORMAT         MAKE_D3DHRESULT(2172)
#define D3DERR_CANNOTPROTECTCONTENT             MAKE_D3DHRESULT(2173)
#define D3DERR_UNSUPPORTEDCRYPTO                MAKE_D3DHRESULT(2174)
#define D3DERR_PRESENT_STATISTICS_DISJOINT      MAKE_D3DHRESULT(2180)


/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(IID_IDirect3D9,                   0x81BDCBCA, 0x64D4, 0x426D, 0xAE, 0x8D, 0xAD, 0x1, 0x47, 0xF4, 0x27, 0x5C);
typedef struct IDirect3D9 *LPDIRECT3D9, *PDIRECT3D9;

DEFINE_GUID(IID_IDirect3DDevice9,             0xd0223b96, 0xbf7a, 0x43fd, 0x92, 0xbd, 0xa4, 0x3b, 0xd, 0x82, 0xb9, 0xeb);
typedef struct IDirect3DDevice9 *LPDIRECT3DDEVICE9;

DEFINE_GUID(IID_IDirect3DResource9,           0x5eec05d, 0x8f7d, 0x4362, 0xb9, 0x99, 0xd1, 0xba, 0xf3, 0x57, 0xc7, 0x4);
typedef struct IDirect3DResource9 *LPDIRECT3DRESOURCE9, *PDIRECT3DRESOURCE9;

DEFINE_GUID(IID_IDirect3DVertexBuffer9,       0xb64bb1b5, 0xfd70, 0x4df6, 0xbf, 0x91, 0x19, 0xd0, 0xa1, 0x24, 0x55, 0xe3);
typedef struct IDirect3DVertexBuffer9 *LPDIRECT3DVERTEXBUFFER9, *PDIRECT3DVERTEXBUFFER9;

DEFINE_GUID(IID_IDirect3DVolume9,             0x24f416e6, 0x1f67, 0x4aa7, 0xb8, 0x8e, 0xd3, 0x3f, 0x6f, 0x31, 0x28, 0xa1);
typedef struct IDirect3DVolume9 *LPDIRECT3DVOLUME9, *PDIRECT3DVOLUME9;

DEFINE_GUID(IID_IDirect3DSwapChain9,          0x794950f2, 0xadfc, 0x458a, 0x90, 0x5e, 0x10, 0xa1, 0xb, 0xb, 0x50, 0x3b);
typedef struct IDirect3DSwapChain9 *LPDIRECT3DSWAPCHAIN9, *PDIRECT3DSWAPCHAIN9;

DEFINE_GUID(IID_IDirect3DSurface9,            0xcfbaf3a, 0x9ff6, 0x429a, 0x99, 0xb3, 0xa2, 0x79, 0x6a, 0xf8, 0xb8, 0x9b);
typedef struct IDirect3DSurface9 *LPDIRECT3DSURFACE9, *PDIRECT3DSURFACE9;

DEFINE_GUID(IID_IDirect3DIndexBuffer9,        0x7c9dd65e, 0xd3f7, 0x4529, 0xac, 0xee, 0x78, 0x58, 0x30, 0xac, 0xde, 0x35);
typedef struct IDirect3DIndexBuffer9 *LPDIRECT3DINDEXBUFFER9, *PDIRECT3DINDEXBUFFER9;

DEFINE_GUID(IID_IDirect3DBaseTexture9,        0x580ca87e, 0x1d3c, 0x4d54, 0x99, 0x1d, 0xb7, 0xd3, 0xe3, 0xc2, 0x98, 0xce);
typedef struct IDirect3DBaseTexture9 *LPDIRECT3DBASETEXTURE9, *PDIRECT3DBASETEXTURE9;

DEFINE_GUID(IID_IDirect3DTexture9,            0x85c31227, 0x3de5, 0x4f00, 0x9b, 0x3a, 0xf1, 0x1a, 0xc3, 0x8c, 0x18, 0xb5);
typedef struct IDirect3DTexture9 *LPDIRECT3DTEXTURE9, *PDIRECT3DTEXTURE9;

DEFINE_GUID(IID_IDirect3DCubeTexture9,        0xfff32f81, 0xd953, 0x473a, 0x92, 0x23, 0x93, 0xd6, 0x52, 0xab, 0xa9, 0x3f);
typedef struct IDirect3DCubeTexture9 *LPDIRECT3DCUBETEXTURE9, *PDIRECT3DCUBETEXTURE9;

DEFINE_GUID(IID_IDirect3DVolumeTexture9,      0x2518526c, 0xe789, 0x4111, 0xa7, 0xb9, 0x47, 0xef, 0x32, 0x8d, 0x13, 0xe6);
typedef struct IDirect3DVolumeTexture9 *LPDIRECT3DVOLUMETEXTURE9, *PDIRECT3DVOLUMETEXTURE9;

DEFINE_GUID(IID_IDirect3DVertexDeclaration9,  0xdd13c59c, 0x36fa, 0x4098, 0xa8, 0xfb, 0xc7, 0xed, 0x39, 0xdc, 0x85, 0x46);
typedef struct IDirect3DVertexDeclaration9 *LPDIRECT3DVERTEXDECLARATION9;

DEFINE_GUID(IID_IDirect3DVertexShader9,       0xefc5557e, 0x6265, 0x4613, 0x8a, 0x94, 0x43, 0x85, 0x78, 0x89, 0xeb, 0x36);
typedef struct IDirect3DVertexShader9 *LPDIRECT3DVERTEXSHADER9;

DEFINE_GUID(IID_IDirect3DPixelShader9,        0x6d3bdbdc, 0x5b02, 0x4415, 0xb8, 0x52, 0xce, 0x5e, 0x8b, 0xcc, 0xb2, 0x89);
typedef struct IDirect3DPixelShader9 *LPDIRECT3DPIXELSHADER9;

DEFINE_GUID(IID_IDirect3DStateBlock9,         0xb07c4fe5, 0x310d, 0x4ba8, 0xa2, 0x3c, 0x4f, 0xf, 0x20, 0x6f, 0x21, 0x8b);
typedef struct IDirect3DStateBlock9 *LPDIRECT3DSTATEBLOCK9;

DEFINE_GUID(IID_IDirect3DQuery9,              0xd9771460, 0xa695, 0x4f26, 0xbb, 0xd3, 0x27, 0xb8, 0x40, 0xb5, 0x41, 0xcc);
typedef struct IDirect3DQuery9 *LPDIRECT3DQUERY9, *PDIRECT3DQUERY9;

/*****************************************************************************
 * IDirect3D9 interface
 */
#undef INTERFACE
#define INTERFACE IDirect3D9
DECLARE_INTERFACE_IID_(IDirect3D9,IUnknown,"81bdcbca-64d4-426d-ae8d-ad0147f4275c")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3D9 methods ***/
    STDMETHOD(RegisterSoftwareDevice)(THIS_ void* pInitializeFunction) PURE;
    STDMETHOD_(UINT, GetAdapterCount)(THIS) PURE;
    STDMETHOD(GetAdapterIdentifier)(THIS_ UINT Adapter, DWORD Flags, D3DADAPTER_IDENTIFIER9* pIdentifier) PURE;
    STDMETHOD_(UINT, GetAdapterModeCount)(THIS_ UINT Adapter, D3DFORMAT Format) PURE;
    STDMETHOD(EnumAdapterModes)(THIS_ UINT Adapter, D3DFORMAT Format, UINT Mode, D3DDISPLAYMODE* pMode) PURE;
    STDMETHOD(GetAdapterDisplayMode)(THIS_ UINT Adapter, D3DDISPLAYMODE* pMode) PURE;
    STDMETHOD(CheckDeviceType)(THIS_ UINT iAdapter, D3DDEVTYPE DevType, D3DFORMAT DisplayFormat, D3DFORMAT BackBufferFormat, WINBOOL bWindowed) PURE;
    STDMETHOD(CheckDeviceFormat)(THIS_ UINT Adapter, D3DDEVTYPE DeviceType, D3DFORMAT AdapterFormat, DWORD Usage, D3DRESOURCETYPE RType, D3DFORMAT CheckFormat) PURE;
    STDMETHOD(CheckDeviceMultiSampleType)(THIS_ UINT Adapter, D3DDEVTYPE DeviceType, D3DFORMAT SurfaceFormat, WINBOOL Windowed, D3DMULTISAMPLE_TYPE MultiSampleType, DWORD* pQualityLevels) PURE;
    STDMETHOD(CheckDepthStencilMatch)(THIS_ UINT Adapter, D3DDEVTYPE DeviceType, D3DFORMAT AdapterFormat, D3DFORMAT RenderTargetFormat, D3DFORMAT DepthStencilFormat) PURE;
    STDMETHOD(CheckDeviceFormatConversion)(THIS_ UINT Adapter, D3DDEVTYPE DeviceType, D3DFORMAT SourceFormat, D3DFORMAT TargetFormat) PURE;
    STDMETHOD(GetDeviceCaps)(THIS_ UINT Adapter, D3DDEVTYPE DeviceType, D3DCAPS9* pCaps) PURE;
    STDMETHOD_(HMONITOR, GetAdapterMonitor)(THIS_ UINT Adapter) PURE;
    STDMETHOD(CreateDevice)(THIS_ UINT Adapter, D3DDEVTYPE DeviceType, HWND hFocusWindow, DWORD BehaviorFlags, D3DPRESENT_PARAMETERS* pPresentationParameters, struct IDirect3DDevice9** ppReturnedDeviceInterface) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3D9,                   0x81BDCBCA, 0x64D4, 0x426D, 0xAE, 0x8D, 0xAD, 0x1, 0x47, 0xF4, 0x27, 0x5C);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3D9_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3D9_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3D9_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3D9 methods ***/
#define IDirect3D9_RegisterSoftwareDevice(p,a)                (p)->lpVtbl->RegisterSoftwareDevice(p,a)
#define IDirect3D9_GetAdapterCount(p)                         (p)->lpVtbl->GetAdapterCount(p)
#define IDirect3D9_GetAdapterIdentifier(p,a,b,c)              (p)->lpVtbl->GetAdapterIdentifier(p,a,b,c)
#define IDirect3D9_GetAdapterModeCount(p,a,b)                 (p)->lpVtbl->GetAdapterModeCount(p,a,b)
#define IDirect3D9_EnumAdapterModes(p,a,b,c,d)                (p)->lpVtbl->EnumAdapterModes(p,a,b,c,d)
#define IDirect3D9_GetAdapterDisplayMode(p,a,b)               (p)->lpVtbl->GetAdapterDisplayMode(p,a,b)
#define IDirect3D9_CheckDeviceType(p,a,b,c,d,e)               (p)->lpVtbl->CheckDeviceType(p,a,b,c,d,e)
#define IDirect3D9_CheckDeviceFormat(p,a,b,c,d,e,f)           (p)->lpVtbl->CheckDeviceFormat(p,a,b,c,d,e,f)
#define IDirect3D9_CheckDeviceMultiSampleType(p,a,b,c,d,e,f)  (p)->lpVtbl->CheckDeviceMultiSampleType(p,a,b,c,d,e,f)
#define IDirect3D9_CheckDepthStencilMatch(p,a,b,c,d,e)        (p)->lpVtbl->CheckDepthStencilMatch(p,a,b,c,d,e)
#define IDirect3D9_CheckDeviceFormatConversion(p,a,b,c,d)     (p)->lpVtbl->CheckDeviceFormatConversion(p,a,b,c,d)
#define IDirect3D9_GetDeviceCaps(p,a,b,c)                     (p)->lpVtbl->GetDeviceCaps(p,a,b,c)
#define IDirect3D9_GetAdapterMonitor(p,a)                     (p)->lpVtbl->GetAdapterMonitor(p,a)
#define IDirect3D9_CreateDevice(p,a,b,c,d,e,f)                (p)->lpVtbl->CreateDevice(p,a,b,c,d,e,f)
#else
/*** IUnknown methods ***/
#define IDirect3D9_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3D9_AddRef(p)             (p)->AddRef()
#define IDirect3D9_Release(p)            (p)->Release()
/*** IDirect3D9 methods ***/
#define IDirect3D9_RegisterSoftwareDevice(p,a)                (p)->RegisterSoftwareDevice(a)
#define IDirect3D9_GetAdapterCount(p)                         (p)->GetAdapterCount()
#define IDirect3D9_GetAdapterIdentifier(p,a,b,c)              (p)->GetAdapterIdentifier(a,b,c)
#define IDirect3D9_GetAdapterModeCount(p,a,b)                 (p)->GetAdapterModeCount(a,b)
#define IDirect3D9_EnumAdapterModes(p,a,b,c,d)                (p)->EnumAdapterModes(a,b,c,d)
#define IDirect3D9_GetAdapterDisplayMode(p,a,b)               (p)->GetAdapterDisplayMode(a,b)
#define IDirect3D9_CheckDeviceType(p,a,b,c,d,e)               (p)->CheckDeviceType(a,b,c,d,e)
#define IDirect3D9_CheckDeviceFormat(p,a,b,c,d,e,f)           (p)->CheckDeviceFormat(a,b,c,d,e,f)
#define IDirect3D9_CheckDeviceMultiSampleType(p,a,b,c,d,e,f)  (p)->CheckDeviceMultiSampleType(a,b,c,d,e,f)
#define IDirect3D9_CheckDepthStencilMatch(p,a,b,c,d,e)        (p)->CheckDepthStencilMatch(a,b,c,d,e)
#define IDirect3D9_CheckDeviceFormatConversion(p,a,b,c,d)     (p)->CheckDeviceFormatConversion(a,b,c,d)
#define IDirect3D9_GetDeviceCaps(p,a,b,c)                     (p)->GetDeviceCaps(a,b,c)
#define IDirect3D9_GetAdapterMonitor(p,a)                     (p)->GetAdapterMonitor(a)
#define IDirect3D9_CreateDevice(p,a,b,c,d,e,f)                (p)->CreateDevice(a,b,c,d,e,f)
#endif

/*****************************************************************************
 * IDirect3DVolume9 interface
 */
#define INTERFACE IDirect3DVolume9
DECLARE_INTERFACE_IID_(IDirect3DVolume9,IUnknown,"24f416e6-1f67-4aa7-b88e-d33f6f3128a1")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DVolume9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD(GetContainer)(THIS_ REFIID riid, void** ppContainer) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DVOLUME_DESC* pDesc) PURE;
    STDMETHOD(LockBox)(THIS_ D3DLOCKED_BOX *locked_box, const D3DBOX *box, DWORD flags) PURE;
    STDMETHOD(UnlockBox)(THIS) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DVolume9,             0x24f416e6, 0x1f67, 0x4aa7, 0xb8, 0x8e, 0xd3, 0x3f, 0x6f, 0x31, 0x28, 0xa1);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVolume9_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVolume9_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DVolume9_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DVolume9 methods ***/
#define IDirect3DVolume9_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DVolume9_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DVolume9_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DVolume9_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DVolume9_GetContainer(p,a,b)          (p)->lpVtbl->GetContainer(p,a,b)
#define IDirect3DVolume9_GetDesc(p,a)                 (p)->lpVtbl->GetDesc(p,a)
#define IDirect3DVolume9_LockBox(p,a,b,c)             (p)->lpVtbl->LockBox(p,a,b,c)
#define IDirect3DVolume9_UnlockBox(p)                 (p)->lpVtbl->UnlockBox(p)
#else
/*** IUnknown methods ***/
#define IDirect3DVolume9_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DVolume9_AddRef(p)                    (p)->AddRef()
#define IDirect3DVolume9_Release(p)                   (p)->Release()
/*** IDirect3DVolume9 methods ***/
#define IDirect3DVolume9_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DVolume9_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DVolume9_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DVolume9_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DVolume9_GetContainer(p,a,b)          (p)->GetContainer(a,b)
#define IDirect3DVolume9_GetDesc(p,a)                 (p)->GetDesc(a)
#define IDirect3DVolume9_LockBox(p,a,b,c)             (p)->LockBox(a,b,c)
#define IDirect3DVolume9_UnlockBox(p)                 (p)->UnlockBox()
#endif

/*****************************************************************************
 * IDirect3DSwapChain9 interface
 */
#define INTERFACE IDirect3DSwapChain9
DECLARE_INTERFACE_IID_(IDirect3DSwapChain9,IUnknown,"794950f2-adfc-458a-905e-10a10b0b503b")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DSwapChain9 methods ***/
    STDMETHOD(Present)(THIS_ const RECT *src_rect, const RECT *dst_rect, HWND dst_window_override,
            const RGNDATA *dirty_region, DWORD flags) PURE;
    STDMETHOD(GetFrontBufferData)(THIS_ struct IDirect3DSurface9 *pDestSurface) PURE;
    STDMETHOD(GetBackBuffer)(THIS_ UINT iBackBuffer, D3DBACKBUFFER_TYPE Type, struct IDirect3DSurface9 **ppBackBuffer) PURE;
    STDMETHOD(GetRasterStatus)(THIS_ D3DRASTER_STATUS *pRasterStatus) PURE;
    STDMETHOD(GetDisplayMode)(THIS_ D3DDISPLAYMODE *pMode) PURE;
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **ppDevice) PURE;
    STDMETHOD(GetPresentParameters)(THIS_ D3DPRESENT_PARAMETERS *pPresentationParameters) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DSwapChain9,          0x794950f2, 0xadfc, 0x458a, 0x90, 0x5e, 0x10, 0xa1, 0xb, 0xb, 0x50, 0x3b);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DSwapChain9_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DSwapChain9_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DSwapChain9_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DSwapChain9 methods ***/
#define IDirect3DSwapChain9_Present(p,a,b,c,d,e)         (p)->lpVtbl->Present(p,a,b,c,d,e)
#define IDirect3DSwapChain9_GetFrontBufferData(p,a)      (p)->lpVtbl->GetFrontBufferData(p,a)
#define IDirect3DSwapChain9_GetBackBuffer(p,a,b,c)       (p)->lpVtbl->GetBackBuffer(p,a,b,c)
#define IDirect3DSwapChain9_GetRasterStatus(p,a)         (p)->lpVtbl->GetRasterStatus(p,a)
#define IDirect3DSwapChain9_GetDisplayMode(p,a)          (p)->lpVtbl->GetDisplayMode(p,a)
#define IDirect3DSwapChain9_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DSwapChain9_GetPresentParameters(p,a)    (p)->lpVtbl->GetPresentParameters(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DSwapChain9_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DSwapChain9_AddRef(p)                    (p)->AddRef()
#define IDirect3DSwapChain9_Release(p)                   (p)->Release()
/*** IDirect3DSwapChain9 methods ***/
#define IDirect3DSwapChain9_Present(p,a,b,c,d,e)         (p)->Present(a,b,c,d,e)
#define IDirect3DSwapChain9_GetFrontBufferData(p,a)      (p)->GetFrontBufferData(a)
#define IDirect3DSwapChain9_GetBackBuffer(p,a,b,c)       (p)->GetBackBuffer(a,b,c)
#define IDirect3DSwapChain9_GetRasterStatus(p,a)         (p)->GetRasterStatus(a)
#define IDirect3DSwapChain9_GetDisplayMode(p,a)          (p)->GetDisplayMode(a)
#define IDirect3DSwapChain9_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DSwapChain9_GetPresentParameters(p,a)    (p)->GetPresentParameters(a)
#endif

/*****************************************************************************
 * IDirect3DResource9 interface
 */
#define INTERFACE IDirect3DResource9
DECLARE_INTERFACE_IID_(IDirect3DResource9,IUnknown,"05eec05d-8f7d-4362-b999-d1baf357c704")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD_(DWORD, SetPriority)(THIS_ DWORD PriorityNew) PURE;
    STDMETHOD_(DWORD, GetPriority)(THIS) PURE;
    STDMETHOD_(void, PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE, GetType)(THIS) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DResource9,           0x5eec05d, 0x8f7d, 0x4362, 0xb9, 0x99, 0xd1, 0xba, 0xf3, 0x57, 0xc7, 0x4);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DResource9_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DResource9_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DResource9_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DResource9 methods ***/
#define IDirect3DResource9_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DResource9_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DResource9_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DResource9_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DResource9_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DResource9_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DResource9_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DResource9_GetType(p)                   (p)->lpVtbl->GetType(p)
#else
/*** IUnknown methods ***/
#define IDirect3DResource9_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DResource9_AddRef(p)                    (p)->AddRef()
#define IDirect3DResource9_Release(p)                   (p)->Release()
/*** IDirect3DResource9 methods ***/
#define IDirect3DResource9_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DResource9_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DResource9_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DResource9_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DResource9_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DResource9_GetPriority(p)               (p)->GetPriority()
#define IDirect3DResource9_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DResource9_GetType(p)                   (p)->GetType()
#endif

/*****************************************************************************
 * IDirect3DSurface9 interface
 */
#define INTERFACE IDirect3DSurface9
DECLARE_INTERFACE_IID_(IDirect3DSurface9,IDirect3DResource9,"0cfbaf3a-9ff6-429a-99b3-a2796af8b89b")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD_(DWORD, SetPriority)(THIS_ DWORD PriorityNew) PURE;
    STDMETHOD_(DWORD, GetPriority)(THIS) PURE;
    STDMETHOD_(void, PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE, GetType)(THIS) PURE;
    /*** IDirect3DSurface9 methods ***/
    STDMETHOD(GetContainer)(THIS_ REFIID riid, void** ppContainer) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DSURFACE_DESC* pDesc) PURE;
    STDMETHOD(LockRect)(THIS_ D3DLOCKED_RECT *locked_rect, const RECT *rect, DWORD flags) PURE;
    STDMETHOD(UnlockRect)(THIS) PURE;
    STDMETHOD(GetDC)(THIS_ HDC* phdc) PURE;
    STDMETHOD(ReleaseDC)(THIS_ HDC hdc) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DSurface9,            0xcfbaf3a, 0x9ff6, 0x429a, 0x99, 0xb3, 0xa2, 0x79, 0x6a, 0xf8, 0xb8, 0x9b);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DSurface9_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DSurface9_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DSurface9_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DSurface9 methods: IDirect3DResource9 ***/
#define IDirect3DSurface9_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DSurface9_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DSurface9_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DSurface9_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DSurface9_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DSurface9_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DSurface9_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DSurface9_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DSurface9 methods ***/
#define IDirect3DSurface9_GetContainer(p,a,b)          (p)->lpVtbl->GetContainer(p,a,b)
#define IDirect3DSurface9_GetDesc(p,a)                 (p)->lpVtbl->GetDesc(p,a)
#define IDirect3DSurface9_LockRect(p,a,b,c)            (p)->lpVtbl->LockRect(p,a,b,c)
#define IDirect3DSurface9_UnlockRect(p)                (p)->lpVtbl->UnlockRect(p)
#define IDirect3DSurface9_GetDC(p,a)                   (p)->lpVtbl->GetDC(p,a)
#define IDirect3DSurface9_ReleaseDC(p,a)               (p)->lpVtbl->ReleaseDC(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DSurface9_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DSurface9_AddRef(p)                    (p)->AddRef()
#define IDirect3DSurface9_Release(p)                   (p)->Release()
/*** IDirect3DSurface9 methods: IDirect3DResource9 ***/
#define IDirect3DSurface9_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DSurface9_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DSurface9_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DSurface9_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DSurface9_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DSurface9_GetPriority(p)               (p)->GetPriority()
#define IDirect3DSurface9_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DSurface9_GetType(p)                   (p)->GetType()
/*** IDirect3DSurface9 methods ***/
#define IDirect3DSurface9_GetContainer(p,a,b)          (p)->GetContainer(a,b)
#define IDirect3DSurface9_GetDesc(p,a)                 (p)->GetDesc(a)
#define IDirect3DSurface9_LockRect(p,a,b,c)            (p)->LockRect(a,b,c)
#define IDirect3DSurface9_UnlockRect(p)                (p)->UnlockRect()
#define IDirect3DSurface9_GetDC(p,a)                   (p)->GetDC(a)
#define IDirect3DSurface9_ReleaseDC(p,a)               (p)->ReleaseDC(a)
#endif

/*****************************************************************************
 * IDirect3DVertexBuffer9 interface
 */
#define INTERFACE IDirect3DVertexBuffer9
DECLARE_INTERFACE_IID_(IDirect3DVertexBuffer9,IDirect3DResource9,"b64bb1b5-fd70-4df6-bf91-19d0a12455e3")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD_(DWORD, SetPriority)(THIS_ DWORD PriorityNew) PURE;
    STDMETHOD_(DWORD, GetPriority)(THIS) PURE;
    STDMETHOD_(void, PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE, GetType)(THIS) PURE;
    /*** IDirect3DVertexBuffer9 methods ***/
    STDMETHOD(Lock)(THIS_ UINT OffsetToLock, UINT SizeToLock, void** ppbData, DWORD Flags) PURE;
    STDMETHOD(Unlock)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DVERTEXBUFFER_DESC* pDesc) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DVertexBuffer9,       0xb64bb1b5, 0xfd70, 0x4df6, 0xbf, 0x91, 0x19, 0xd0, 0xa1, 0x24, 0x55, 0xe3);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVertexBuffer9_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVertexBuffer9_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DVertexBuffer9_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DVertexBuffer9 methods: IDirect3DResource9 ***/
#define IDirect3DVertexBuffer9_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DVertexBuffer9_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DVertexBuffer9_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DVertexBuffer9_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DVertexBuffer9_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DVertexBuffer9_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DVertexBuffer9_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DVertexBuffer9_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DVertexBuffer9 methods ***/
#define IDirect3DVertexBuffer9_Lock(p,a,b,c,d)              (p)->lpVtbl->Lock(p,a,b,c,d)
#define IDirect3DVertexBuffer9_Unlock(p)                    (p)->lpVtbl->Unlock(p)
#define IDirect3DVertexBuffer9_GetDesc(p,a)                 (p)->lpVtbl->GetDesc(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DVertexBuffer9_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DVertexBuffer9_AddRef(p)                    (p)->AddRef()
#define IDirect3DVertexBuffer9_Release(p)                   (p)->Release()
/*** IDirect3DVertexBuffer9 methods: IDirect3DResource9 ***/
#define IDirect3DVertexBuffer9_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DVertexBuffer9_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DVertexBuffer9_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DVertexBuffer9_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DVertexBuffer9_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DVertexBuffer9_GetPriority(p)               (p)->GetPriority()
#define IDirect3DVertexBuffer9_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DVertexBuffer9_GetType(p)                   (p)->GetType()
/*** IDirect3DVertexBuffer9 methods ***/
#define IDirect3DVertexBuffer9_Lock(p,a,b,c,d)              (p)->Lock(a,b,c,d)
#define IDirect3DVertexBuffer9_Unlock(p)                    (p)->Unlock()
#define IDirect3DVertexBuffer9_GetDesc(p,a)                 (p)->GetDesc(a)
#endif

/*****************************************************************************
 * IDirect3DIndexBuffer9 interface
 */
#define INTERFACE IDirect3DIndexBuffer9
DECLARE_INTERFACE_IID_(IDirect3DIndexBuffer9,IDirect3DResource9,"7c9dd65e-d3f7-4529-acee-785830acde35")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD_(DWORD, SetPriority)(THIS_ DWORD PriorityNew) PURE;
    STDMETHOD_(DWORD, GetPriority)(THIS) PURE;
    STDMETHOD_(void, PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE, GetType)(THIS) PURE;
    /*** IDirect3DIndexBuffer9 methods ***/
    STDMETHOD(Lock)(THIS_ UINT OffsetToLock, UINT SizeToLock, void** ppbData, DWORD Flags) PURE;
    STDMETHOD(Unlock)(THIS) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DINDEXBUFFER_DESC* pDesc) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DIndexBuffer9,        0x7c9dd65e, 0xd3f7, 0x4529, 0xac, 0xee, 0x78, 0x58, 0x30, 0xac, 0xde, 0x35);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DIndexBuffer9_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DIndexBuffer9_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirect3DIndexBuffer9_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirect3DIndexBuffer9 methods: IDirect3DResource9 ***/
#define IDirect3DIndexBuffer9_GetDevice(p,a)               (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DIndexBuffer9_SetPrivateData(p,a,b,c,d)    (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DIndexBuffer9_GetPrivateData(p,a,b,c)      (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DIndexBuffer9_FreePrivateData(p,a)         (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DIndexBuffer9_SetPriority(p,a)             (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DIndexBuffer9_GetPriority(p)               (p)->lpVtbl->GetPriority(p)
#define IDirect3DIndexBuffer9_PreLoad(p)                   (p)->lpVtbl->PreLoad(p)
#define IDirect3DIndexBuffer9_GetType(p)                   (p)->lpVtbl->GetType(p)
/*** IDirect3DIndexBuffer9 methods ***/
#define IDirect3DIndexBuffer9_Lock(p,a,b,c,d)              (p)->lpVtbl->Lock(p,a,b,c,d)
#define IDirect3DIndexBuffer9_Unlock(p)                    (p)->lpVtbl->Unlock(p)
#define IDirect3DIndexBuffer9_GetDesc(p,a)                 (p)->lpVtbl->GetDesc(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DIndexBuffer9_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirect3DIndexBuffer9_AddRef(p)                    (p)->AddRef()
#define IDirect3DIndexBuffer9_Release(p)                   (p)->Release()
/*** IDirect3DIndexBuffer9 methods: IDirect3DResource9 ***/
#define IDirect3DIndexBuffer9_GetDevice(p,a)               (p)->GetDevice(a)
#define IDirect3DIndexBuffer9_SetPrivateData(p,a,b,c,d)    (p)->SetPrivateData(a,b,c,d)
#define IDirect3DIndexBuffer9_GetPrivateData(p,a,b,c)      (p)->GetPrivateData(a,b,c)
#define IDirect3DIndexBuffer9_FreePrivateData(p,a)         (p)->FreePrivateData(a)
#define IDirect3DIndexBuffer9_SetPriority(p,a)             (p)->SetPriority(a)
#define IDirect3DIndexBuffer9_GetPriority(p)               (p)->GetPriority()
#define IDirect3DIndexBuffer9_PreLoad(p)                   (p)->PreLoad()
#define IDirect3DIndexBuffer9_GetType(p)                   (p)->GetType()
/*** IDirect3DIndexBuffer9 methods ***/
#define IDirect3DIndexBuffer9_Lock(p,a,b,c,d)              (p)->Lock(a,b,c,d)
#define IDirect3DIndexBuffer9_Unlock(p)                    (p)->Unlock()
#define IDirect3DIndexBuffer9_GetDesc(p,a)                 (p)->GetDesc(a)
#endif

/*****************************************************************************
 * IDirect3DBaseTexture9 interface
 */
#define INTERFACE IDirect3DBaseTexture9
DECLARE_INTERFACE_IID_(IDirect3DBaseTexture9,IDirect3DResource9,"580ca87e-1d3c-4d54-991d-b7d3e3c298ce")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD_(DWORD, SetPriority)(THIS_ DWORD PriorityNew) PURE;
    STDMETHOD_(DWORD, GetPriority)(THIS) PURE;
    STDMETHOD_(void, PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE, GetType)(THIS) PURE;
    /*** IDirect3DBaseTexture9 methods ***/
    STDMETHOD_(DWORD, SetLOD)(THIS_ DWORD LODNew) PURE;
    STDMETHOD_(DWORD, GetLOD)(THIS) PURE;
    STDMETHOD_(DWORD, GetLevelCount)(THIS) PURE;
    STDMETHOD(SetAutoGenFilterType)(THIS_ D3DTEXTUREFILTERTYPE FilterType) PURE;
    STDMETHOD_(D3DTEXTUREFILTERTYPE, GetAutoGenFilterType)(THIS) PURE;
    STDMETHOD_(void, GenerateMipSubLevels)(THIS) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DBaseTexture9,        0x580ca87e, 0x1d3c, 0x4d54, 0x99, 0x1d, 0xb7, 0xd3, 0xe3, 0xc2, 0x98, 0xce);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DBaseTexture9_QueryInterface(p,a,b)  (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DBaseTexture9_AddRef(p)              (p)->lpVtbl->AddRef(p)
#define IDirect3DBaseTexture9_Release(p)             (p)->lpVtbl->Release(p)
/*** IDirect3DBaseTexture9 methods: IDirect3DResource9 ***/
#define IDirect3DBaseTexture9_GetDevice(p,a)             (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DBaseTexture9_SetPrivateData(p,a,b,c,d)  (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DBaseTexture9_GetPrivateData(p,a,b,c)    (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DBaseTexture9_FreePrivateData(p,a)       (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DBaseTexture9_SetPriority(p,a)           (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DBaseTexture9_GetPriority(p)             (p)->lpVtbl->GetPriority(p)
#define IDirect3DBaseTexture9_PreLoad(p)                 (p)->lpVtbl->PreLoad(p)
#define IDirect3DBaseTexture9_GetType(p)                 (p)->lpVtbl->GetType(p)
/*** IDirect3DBaseTexture9 methods ***/
#define IDirect3DBaseTexture9_SetLOD(p,a)                (p)->lpVtbl->SetLOD(p,a)
#define IDirect3DBaseTexture9_GetLOD(p)                  (p)->lpVtbl->GetLOD(p)
#define IDirect3DBaseTexture9_GetLevelCount(p)           (p)->lpVtbl->GetLevelCount(p)
#define IDirect3DBaseTexture9_SetAutoGenFilterType(p,a)  (p)->lpVtbl->SetAutoGenFilterType(p,a)
#define IDirect3DBaseTexture9_GetAutoGenFilterType(p)    (p)->lpVtbl->GetAutoGenFilterType(p)
#define IDirect3DBaseTexture9_GenerateMipSubLevels(p)    (p)->lpVtbl->GenerateMipSubLevels(p)
#else
/*** IUnknown methods ***/
#define IDirect3DBaseTexture9_QueryInterface(p,a,b)  (p)->QueryInterface(a,b)
#define IDirect3DBaseTexture9_AddRef(p)              (p)->AddRef()
#define IDirect3DBaseTexture9_Release(p)             (p)->Release()
/*** IDirect3DBaseTexture9 methods: IDirect3DResource9 ***/
#define IDirect3DBaseTexture9_GetDevice(p,a)             (p)->GetDevice(a)
#define IDirect3DBaseTexture9_SetPrivateData(p,a,b,c,d)  (p)->SetPrivateData(a,b,c,d)
#define IDirect3DBaseTexture9_GetPrivateData(p,a,b,c)    (p)->GetPrivateData(a,b,c)
#define IDirect3DBaseTexture9_FreePrivateData(p,a)       (p)->FreePrivateData(a)
#define IDirect3DBaseTexture9_SetPriority(p,a)           (p)->SetPriority(a)
#define IDirect3DBaseTexture9_GetPriority(p)             (p)->GetPriority()
#define IDirect3DBaseTexture9_PreLoad(p)                 (p)->PreLoad()
#define IDirect3DBaseTexture9_GetType(p)                 (p)->GetType()
/*** IDirect3DBaseTexture9 methods ***/
#define IDirect3DBaseTexture9_SetLOD(p,a)                (p)->SetLOD(a)
#define IDirect3DBaseTexture9_GetLOD(p)                  (p)->GetLOD()
#define IDirect3DBaseTexture9_GetLevelCount(p)           (p)->GetLevelCount()
#define IDirect3DBaseTexture9_SetAutoGenFilterType(p,a)  (p)->SetAutoGenFilterType(a)
#define IDirect3DBaseTexture9_GetAutoGenFilterType(p)    (p)->GetAutoGenFilterType()
#define IDirect3DBaseTexture9_GenerateMipSubLevels(p)    (p)->GenerateMipSubLevels()
#endif

/*****************************************************************************
 * IDirect3DCubeTexture9 interface
 */
#define INTERFACE IDirect3DCubeTexture9
DECLARE_INTERFACE_IID_(IDirect3DCubeTexture9,IDirect3DBaseTexture9,"fff32f81-d953-473a-9223-93d652aba93f")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD_(DWORD, SetPriority)(THIS_ DWORD PriorityNew) PURE;
    STDMETHOD_(DWORD, GetPriority)(THIS) PURE;
    STDMETHOD_(void, PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE, GetType)(THIS) PURE;
    /*** IDirect3DBaseTexture9 methods ***/
    STDMETHOD_(DWORD, SetLOD)(THIS_ DWORD LODNew) PURE;
    STDMETHOD_(DWORD, GetLOD)(THIS) PURE;
    STDMETHOD_(DWORD, GetLevelCount)(THIS) PURE;
    STDMETHOD(SetAutoGenFilterType)(THIS_ D3DTEXTUREFILTERTYPE FilterType) PURE;
    STDMETHOD_(D3DTEXTUREFILTERTYPE, GetAutoGenFilterType)(THIS) PURE;
    STDMETHOD_(void, GenerateMipSubLevels)(THIS) PURE;
    /*** IDirect3DCubeTexture9 methods ***/
    STDMETHOD(GetLevelDesc)(THIS_ UINT Level,D3DSURFACE_DESC* pDesc) PURE;
    STDMETHOD(GetCubeMapSurface)(THIS_ D3DCUBEMAP_FACES FaceType, UINT Level, IDirect3DSurface9** ppCubeMapSurface) PURE;
    STDMETHOD(LockRect)(THIS_ D3DCUBEMAP_FACES face, UINT level,
            D3DLOCKED_RECT *locked_rect, const RECT *rect, DWORD flags) PURE;
    STDMETHOD(UnlockRect)(THIS_ D3DCUBEMAP_FACES FaceType, UINT Level) PURE;
    STDMETHOD(AddDirtyRect)(THIS_ D3DCUBEMAP_FACES face, const RECT *dirty_rect) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DCubeTexture9,        0xfff32f81, 0xd953, 0x473a, 0x92, 0x23, 0x93, 0xd6, 0x52, 0xab, 0xa9, 0x3f);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DCubeTexture9_QueryInterface(p,a,b)       (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DCubeTexture9_AddRef(p)                   (p)->lpVtbl->AddRef(p)
#define IDirect3DCubeTexture9_Release(p)                  (p)->lpVtbl->Release(p)
/*** IDirect3DCubeTexture9 methods: IDirect3DResource9 ***/
#define IDirect3DCubeTexture9_GetDevice(p,a)              (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DCubeTexture9_SetPrivateData(p,a,b,c,d)   (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DCubeTexture9_GetPrivateData(p,a,b,c)     (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DCubeTexture9_FreePrivateData(p,a)        (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DCubeTexture9_SetPriority(p,a)            (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DCubeTexture9_GetPriority(p)              (p)->lpVtbl->GetPriority(p)
#define IDirect3DCubeTexture9_PreLoad(p)                  (p)->lpVtbl->PreLoad(p)
#define IDirect3DCubeTexture9_GetType(p)                  (p)->lpVtbl->GetType(p)
/*** IDirect3DCubeTexture9 methods: IDirect3DBaseTexture9 ***/
#define IDirect3DCubeTexture9_SetLOD(p,a)                 (p)->lpVtbl->SetLOD(p,a)
#define IDirect3DCubeTexture9_GetLOD(p)                   (p)->lpVtbl->GetLOD(p)
#define IDirect3DCubeTexture9_GetLevelCount(p)            (p)->lpVtbl->GetLevelCount(p)
#define IDirect3DCubeTexture9_SetAutoGenFilterType(p,a)   (p)->lpVtbl->SetAutoGenFilterType(p,a)
#define IDirect3DCubeTexture9_GetAutoGenFilterType(p)     (p)->lpVtbl->GetAutoGenFilterType(p)
#define IDirect3DCubeTexture9_GenerateMipSubLevels(p)     (p)->lpVtbl->GenerateMipSubLevels(p)
/*** IDirect3DCubeTexture9 methods ***/
#define IDirect3DCubeTexture9_GetLevelDesc(p,a,b)         (p)->lpVtbl->GetLevelDesc(p,a,b)
#define IDirect3DCubeTexture9_GetCubeMapSurface(p,a,b,c)  (p)->lpVtbl->GetCubeMapSurface(p,a,b,c)
#define IDirect3DCubeTexture9_LockRect(p,a,b,c,d,e)       (p)->lpVtbl->LockRect(p,a,b,c,d,e)
#define IDirect3DCubeTexture9_UnlockRect(p,a,b)           (p)->lpVtbl->UnlockRect(p,a,b)
#define IDirect3DCubeTexture9_AddDirtyRect(p,a,b)         (p)->lpVtbl->AddDirtyRect(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DCubeTexture9_QueryInterface(p,a,b)       (p)->QueryInterface(a,b)
#define IDirect3DCubeTexture9_AddRef(p)                   (p)->AddRef()
#define IDirect3DCubeTexture9_Release(p)                  (p)->Release()
/*** IDirect3DCubeTexture9 methods: IDirect3DResource9 ***/
#define IDirect3DCubeTexture9_GetDevice(p,a)              (p)->GetDevice(a)
#define IDirect3DCubeTexture9_SetPrivateData(p,a,b,c,d)   (p)->SetPrivateData(a,b,c,d)
#define IDirect3DCubeTexture9_GetPrivateData(p,a,b,c)     (p)->GetPrivateData(a,b,c)
#define IDirect3DCubeTexture9_FreePrivateData(p,a)        (p)->FreePrivateData(a)
#define IDirect3DCubeTexture9_SetPriority(p,a)            (p)->SetPriority(a)
#define IDirect3DCubeTexture9_GetPriority(p)              (p)->GetPriority()
#define IDirect3DCubeTexture9_PreLoad(p)                  (p)->PreLoad()
#define IDirect3DCubeTexture9_GetType(p)                  (p)->GetType()
/*** IDirect3DCubeTexture9 methods: IDirect3DBaseTexture9 ***/
#define IDirect3DCubeTexture9_SetLOD(p,a)                 (p)->SetLOD(a)
#define IDirect3DCubeTexture9_GetLOD(p)                   (p)->GetLOD()
#define IDirect3DCubeTexture9_GetLevelCount(p)            (p)->GetLevelCount()
#define IDirect3DCubeTexture9_SetAutoGenFilterType(p,a)   (p)->SetAutoGenFilterType(a)
#define IDirect3DCubeTexture9_GetAutoGenFilterType(p)     (p)->GetAutoGenFilterType()
#define IDirect3DCubeTexture9_GenerateMipSubLevels(p)     (p)->GenerateMipSubLevels()
/*** IDirect3DCubeTexture9 methods ***/
#define IDirect3DCubeTexture9_GetLevelDesc(p,a,b)         (p)->GetLevelDesc(a,b)
#define IDirect3DCubeTexture9_GetCubeMapSurface(p,a,b,c)  (p)->GetCubeMapSurface(a,b,c)
#define IDirect3DCubeTexture9_LockRect(p,a,b,c,d,e)       (p)->LockRect(a,b,c,d,e)
#define IDirect3DCubeTexture9_UnlockRect(p,a,b)           (p)->UnlockRect(a,b)
#define IDirect3DCubeTexture9_AddDirtyRect(p,a,b)         (p)->AddDirtyRect(a,b)
#endif

/*****************************************************************************
 * IDirect3DTexture9 interface
 */
#define INTERFACE IDirect3DTexture9
DECLARE_INTERFACE_IID_(IDirect3DTexture9,IDirect3DBaseTexture9,"85c31227-3de5-4f00-9b3a-f11ac38c18b5")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD_(DWORD, SetPriority)(THIS_ DWORD PriorityNew) PURE;
    STDMETHOD_(DWORD, GetPriority)(THIS) PURE;
    STDMETHOD_(void, PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE, GetType)(THIS) PURE;
    /*** IDirect3DBaseTexture9 methods ***/
    STDMETHOD_(DWORD, SetLOD)(THIS_ DWORD LODNew) PURE;
    STDMETHOD_(DWORD, GetLOD)(THIS) PURE;
    STDMETHOD_(DWORD, GetLevelCount)(THIS) PURE;
    STDMETHOD(SetAutoGenFilterType)(THIS_ D3DTEXTUREFILTERTYPE FilterType) PURE;
    STDMETHOD_(D3DTEXTUREFILTERTYPE, GetAutoGenFilterType)(THIS) PURE;
    STDMETHOD_(void, GenerateMipSubLevels)(THIS) PURE;
    /*** IDirect3DTexture9 methods ***/
    STDMETHOD(GetLevelDesc)(THIS_ UINT Level, D3DSURFACE_DESC* pDesc) PURE;
    STDMETHOD(GetSurfaceLevel)(THIS_ UINT Level, IDirect3DSurface9** ppSurfaceLevel) PURE;
    STDMETHOD(LockRect)(THIS_ UINT level, D3DLOCKED_RECT *locked_rect, const RECT *rect, DWORD flags) PURE;
    STDMETHOD(UnlockRect)(THIS_ UINT Level) PURE;
    STDMETHOD(AddDirtyRect)(THIS_ const RECT *dirty_rect) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DTexture9,            0x85c31227, 0x3de5, 0x4f00, 0x9b, 0x3a, 0xf1, 0x1a, 0xc3, 0x8c, 0x18, 0xb5);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DTexture9_QueryInterface(p,a,b)      (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DTexture9_AddRef(p)                  (p)->lpVtbl->AddRef(p)
#define IDirect3DTexture9_Release(p)                 (p)->lpVtbl->Release(p)
/*** IDirect3DTexture9 methods: IDirect3DResource9 ***/
#define IDirect3DTexture9_GetDevice(p,a)             (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DTexture9_SetPrivateData(p,a,b,c,d)  (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DTexture9_GetPrivateData(p,a,b,c)    (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DTexture9_FreePrivateData(p,a)       (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DTexture9_SetPriority(p,a)           (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DTexture9_GetPriority(p)             (p)->lpVtbl->GetPriority(p)
#define IDirect3DTexture9_PreLoad(p)                 (p)->lpVtbl->PreLoad(p)
#define IDirect3DTexture9_GetType(p)                 (p)->lpVtbl->GetType(p)
/*** IDirect3DTexture9 methods: IDirect3DBaseTexture9 ***/
#define IDirect3DTexture9_SetLOD(p,a)                (p)->lpVtbl->SetLOD(p,a)
#define IDirect3DTexture9_GetLOD(p)                  (p)->lpVtbl->GetLOD(p)
#define IDirect3DTexture9_GetLevelCount(p)           (p)->lpVtbl->GetLevelCount(p)
#define IDirect3DTexture9_SetAutoGenFilterType(p,a)  (p)->lpVtbl->SetAutoGenFilterType(p,a)
#define IDirect3DTexture9_GetAutoGenFilterType(p)    (p)->lpVtbl->GetAutoGenFilterType(p)
#define IDirect3DTexture9_GenerateMipSubLevels(p)    (p)->lpVtbl->GenerateMipSubLevels(p)
/*** IDirect3DTexture9 methods ***/
#define IDirect3DTexture9_GetLevelDesc(p,a,b)        (p)->lpVtbl->GetLevelDesc(p,a,b)
#define IDirect3DTexture9_GetSurfaceLevel(p,a,b)     (p)->lpVtbl->GetSurfaceLevel(p,a,b)
#define IDirect3DTexture9_LockRect(p,a,b,c,d)        (p)->lpVtbl->LockRect(p,a,b,c,d)
#define IDirect3DTexture9_UnlockRect(p,a)            (p)->lpVtbl->UnlockRect(p,a)
#define IDirect3DTexture9_AddDirtyRect(p,a)          (p)->lpVtbl->AddDirtyRect(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DTexture9_QueryInterface(p,a,b)      (p)->QueryInterface(a,b)
#define IDirect3DTexture9_AddRef(p)                  (p)->AddRef()
#define IDirect3DTexture9_Release(p)                 (p)->Release()
/*** IDirect3DTexture9 methods: IDirect3DResource9 ***/
#define IDirect3DTexture9_GetDevice(p,a)             (p)->GetDevice(a)
#define IDirect3DTexture9_SetPrivateData(p,a,b,c,d)  (p)->SetPrivateData(a,b,c,d)
#define IDirect3DTexture9_GetPrivateData(p,a,b,c)    (p)->GetPrivateData(a,b,c)
#define IDirect3DTexture9_FreePrivateData(p,a)       (p)->FreePrivateData(a)
#define IDirect3DTexture9_SetPriority(p,a)           (p)->SetPriority(a)
#define IDirect3DTexture9_GetPriority(p)             (p)->GetPriority()
#define IDirect3DTexture9_PreLoad(p)                 (p)->PreLoad()
#define IDirect3DTexture9_GetType(p)                 (p)->GetType()
/*** IDirect3DTexture9 methods: IDirect3DBaseTexture9 ***/
#define IDirect3DTexture9_SetLOD(p,a)                (p)->SetLOD(a)
#define IDirect3DTexture9_GetLOD(p)                  (p)->GetLOD()
#define IDirect3DTexture9_GetLevelCount(p)           (p)->GetLevelCount()
#define IDirect3DTexture9_SetAutoGenFilterType(p,a)  (p)->SetAutoGenFilterType(a)
#define IDirect3DTexture9_GetAutoGenFilterType(p)    (p)->GetAutoGenFilterType()
#define IDirect3DTexture9_GenerateMipSubLevels(p)    (p)->GenerateMipSubLevels()
/*** IDirect3DTexture9 methods ***/
#define IDirect3DTexture9_GetLevelDesc(p,a,b)        (p)->GetLevelDesc(a,b)
#define IDirect3DTexture9_GetSurfaceLevel(p,a,b)     (p)->GetSurfaceLevel(a,b)
#define IDirect3DTexture9_LockRect(p,a,b,c,d)        (p)->LockRect(a,b,c,d)
#define IDirect3DTexture9_UnlockRect(p,a)            (p)->UnlockRect(a)
#define IDirect3DTexture9_AddDirtyRect(p,a)          (p)->AddDirtyRect(a)
#endif

/*****************************************************************************
 * IDirect3DVolumeTexture9 interface
 */
#define INTERFACE IDirect3DVolumeTexture9
DECLARE_INTERFACE_IID_(IDirect3DVolumeTexture9,IDirect3DBaseTexture9,"2518526c-e789-4111-a7b9-47ef328d13e6")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DResource9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(SetPrivateData)(THIS_ REFGUID guid, const void *data, DWORD data_size, DWORD flags) PURE;
    STDMETHOD(GetPrivateData)(THIS_ REFGUID refguid, void* pData, DWORD* pSizeOfData) PURE;
    STDMETHOD(FreePrivateData)(THIS_ REFGUID refguid) PURE;
    STDMETHOD_(DWORD, SetPriority)(THIS_ DWORD PriorityNew) PURE;
    STDMETHOD_(DWORD, GetPriority)(THIS) PURE;
    STDMETHOD_(void, PreLoad)(THIS) PURE;
    STDMETHOD_(D3DRESOURCETYPE, GetType)(THIS) PURE;
    /*** IDirect3DBaseTexture9 methods ***/
    STDMETHOD_(DWORD, SetLOD)(THIS_ DWORD LODNew) PURE;
    STDMETHOD_(DWORD, GetLOD)(THIS) PURE;
    STDMETHOD_(DWORD, GetLevelCount)(THIS) PURE;
    STDMETHOD(SetAutoGenFilterType)(THIS_ D3DTEXTUREFILTERTYPE FilterType) PURE;
    STDMETHOD_(D3DTEXTUREFILTERTYPE, GetAutoGenFilterType)(THIS) PURE;
    STDMETHOD_(void, GenerateMipSubLevels)(THIS) PURE;
    /*** IDirect3DVolumeTexture9 methods ***/
    STDMETHOD(GetLevelDesc)(THIS_ UINT Level, D3DVOLUME_DESC *pDesc) PURE;
    STDMETHOD(GetVolumeLevel)(THIS_ UINT Level, IDirect3DVolume9** ppVolumeLevel) PURE;
    STDMETHOD(LockBox)(THIS_ UINT level, D3DLOCKED_BOX *locked_box, const D3DBOX *box, DWORD flags) PURE;
    STDMETHOD(UnlockBox)(THIS_ UINT Level) PURE;
    STDMETHOD(AddDirtyBox)(THIS_ const D3DBOX *dirty_box) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DVolumeTexture9,      0x2518526c, 0xe789, 0x4111, 0xa7, 0xb9, 0x47, 0xef, 0x32, 0x8d, 0x13, 0xe6);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVolumeTexture9_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVolumeTexture9_AddRef(p) (p)->lpVtbl->AddRef(p)
#define IDirect3DVolumeTexture9_Release(p) (p)->lpVtbl->Release(p)
/*** IDirect3DVolumeTexture9 methods: IDirect3DResource9 ***/
#define IDirect3DVolumeTexture9_GetDevice(p,a) (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DVolumeTexture9_SetPrivateData(p,a,b,c,d) (p)->lpVtbl->SetPrivateData(p,a,b,c,d)
#define IDirect3DVolumeTexture9_GetPrivateData(p,a,b,c) (p)->lpVtbl->GetPrivateData(p,a,b,c)
#define IDirect3DVolumeTexture9_FreePrivateData(p,a) (p)->lpVtbl->FreePrivateData(p,a)
#define IDirect3DVolumeTexture9_SetPriority(p,a) (p)->lpVtbl->SetPriority(p,a)
#define IDirect3DVolumeTexture9_GetPriority(p) (p)->lpVtbl->GetPriority(p)
#define IDirect3DVolumeTexture9_PreLoad(p) (p)->lpVtbl->PreLoad(p)
#define IDirect3DVolumeTexture9_GetType(p) (p)->lpVtbl->GetType(p)
/*** IDirect3DVolumeTexture9 methods: IDirect3DBaseTexture9 ***/
#define IDirect3DVolumeTexture9_SetLOD(p,a) (p)->lpVtbl->SetLOD(p,a)
#define IDirect3DVolumeTexture9_GetLOD(p) (p)->lpVtbl->GetLOD(p)
#define IDirect3DVolumeTexture9_GetLevelCount(p) (p)->lpVtbl->GetLevelCount(p)
#define IDirect3DVolumeTexture9_SetAutoGenFilterType(p,a) (p)->lpVtbl->SetAutoGenFilterType(p,a)
#define IDirect3DVolumeTexture9_GetAutoGenFilterType(p) (p)->lpVtbl->GetAutoGenFilterType(p)
#define IDirect3DVolumeTexture9_GenerateMipSubLevels(p) (p)->lpVtbl->GenerateMipSubLevels(p)
/*** IDirect3DVolumeTexture9 methods ***/
#define IDirect3DVolumeTexture9_GetLevelDesc(p,a,b) (p)->lpVtbl->GetLevelDesc(p,a,b)
#define IDirect3DVolumeTexture9_GetVolumeLevel(p,a,b) (p)->lpVtbl->GetVolumeLevel(p,a,b)
#define IDirect3DVolumeTexture9_LockBox(p,a,b,c,d) (p)->lpVtbl->LockBox(p,a,b,c,d)
#define IDirect3DVolumeTexture9_UnlockBox(p,a) (p)->lpVtbl->UnlockBox(p,a)
#define IDirect3DVolumeTexture9_AddDirtyBox(p,a) (p)->lpVtbl->AddDirtyBox(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DVolumeTexture9_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DVolumeTexture9_AddRef(p) (p)->AddRef()
#define IDirect3DVolumeTexture9_Release(p) (p)->Release()
/*** IDirect3DVolumeTexture9 methods: IDirect3DResource9 ***/
#define IDirect3DVolumeTexture9_GetDevice(p,a) (p)->GetDevice(a)
#define IDirect3DVolumeTexture9_SetPrivateData(p,a,b,c,d) (p)->SetPrivateData(a,b,c,d)
#define IDirect3DVolumeTexture9_GetPrivateData(p,a,b,c) (p)->GetPrivateData(a,b,c)
#define IDirect3DVolumeTexture9_FreePrivateData(p,a) (p)->FreePrivateData(a)
#define IDirect3DVolumeTexture9_SetPriority(p,a) (p)->SetPriority(a)
#define IDirect3DVolumeTexture9_GetPriority(p) (p)->GetPriority()
#define IDirect3DVolumeTexture9_PreLoad(p) (p)->PreLoad()
#define IDirect3DVolumeTexture9_GetType(p) (p)->GetType()
/*** IDirect3DVolumeTexture9 methods: IDirect3DBaseTexture9 ***/
#define IDirect3DVolumeTexture9_SetLOD(p,a) (p)->SetLOD(a)
#define IDirect3DVolumeTexture9_GetLOD(p) (p)->GetLOD()
#define IDirect3DVolumeTexture9_GetLevelCount(p) (p)->GetLevelCount()
#define IDirect3DVolumeTexture9_SetAutoGenFilterType(p,a) (p)->SetAutoGenFilterType(a)
#define IDirect3DVolumeTexture9_GetAutoGenFilterType(p) (p)->GetAutoGenFilterType()
#define IDirect3DVolumeTexture9_GenerateMipSubLevels(p) (p)->GenerateMipSubLevels()
/*** IDirect3DVolumeTexture9 methods ***/
#define IDirect3DVolumeTexture9_GetLevelDesc(p,a,b) (p)->GetLevelDesc(a,b)
#define IDirect3DVolumeTexture9_GetVolumeLevel(p,a,b) (p)->GetVolumeLevel(a,b)
#define IDirect3DVolumeTexture9_LockBox(p,a,b,c,d) (p)->LockBox(a,b,c,d)
#define IDirect3DVolumeTexture9_UnlockBox(p,a) (p)->UnlockBox(a)
#define IDirect3DVolumeTexture9_AddDirtyBox(p,a) (p)->AddDirtyBox(a)
#endif

/*****************************************************************************
 * IDirect3DVertexDeclaration9 interface
 */
#define INTERFACE IDirect3DVertexDeclaration9
DECLARE_INTERFACE_IID_(IDirect3DVertexDeclaration9,IUnknown,"dd13c59c-36fa-4098-a8fb-c7ed39dc8546")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DVertexDeclaration9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(GetDeclaration)(THIS_ D3DVERTEXELEMENT9*, UINT* pNumElements) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DVertexDeclaration9,  0xdd13c59c, 0x36fa, 0x4098, 0xa8, 0xfb, 0xc7, 0xed, 0x39, 0xdc, 0x85, 0x46);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVertexDeclaration9_QueryInterface(p,a,b)  (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVertexDeclaration9_AddRef(p)              (p)->lpVtbl->AddRef(p)
#define IDirect3DVertexDeclaration9_Release(p)             (p)->lpVtbl->Release(p)
/*** IDirect3DVertexShader9 methods ***/
#define IDirect3DVertexDeclaration9_GetDevice(p,a)         (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DVertexDeclaration9_GetDeclaration(p,a,b)  (p)->lpVtbl->GetDeclaration(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DVertexDeclaration9_QueryInterface(p,a,b)  (p)->QueryInterface(a,b)
#define IDirect3DVertexDeclaration9_AddRef(p)              (p)->AddRef()
#define IDirect3DVertexDeclaration9_Release(p)             (p)->Release()
/*** IDirect3DVertexShader9 methods ***/
#define IDirect3DVertexDeclaration9_GetDevice(p,a)         (p)->GetDevice(a)
#define IDirect3DVertexDeclaration9_GetDeclaration(p,a,b)  (p)->GetDeclaration(a,b)
#endif

/*****************************************************************************
 * IDirect3DVertexShader9 interface
 */
#define INTERFACE IDirect3DVertexShader9
DECLARE_INTERFACE_IID_(IDirect3DVertexShader9,IUnknown,"efc5557e-6265-4613-8a94-43857889eb36")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DVertexShader9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(GetFunction)(THIS_ void*, UINT* pSizeOfData) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DVertexShader9,       0xefc5557e, 0x6265, 0x4613, 0x8a, 0x94, 0x43, 0x85, 0x78, 0x89, 0xeb, 0x36);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVertexShader9_QueryInterface(p,a,b)  (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVertexShader9_AddRef(p)              (p)->lpVtbl->AddRef(p)
#define IDirect3DVertexShader9_Release(p)             (p)->lpVtbl->Release(p)
/*** IDirect3DVertexShader9 methods ***/
#define IDirect3DVertexShader9_GetDevice(p,a)         (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DVertexShader9_GetFunction(p,a,b)     (p)->lpVtbl->GetFunction(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DVertexShader9_QueryInterface(p,a,b)  (p)->QueryInterface(a,b)
#define IDirect3DVertexShader9_AddRef(p)              (p)->AddRef()
#define IDirect3DVertexShader9_Release(p)             (p)->Release()
/*** IDirect3DVertexShader9 methods ***/
#define IDirect3DVertexShader9_GetDevice(p,a)         (p)->GetDevice(a)
#define IDirect3DVertexShader9_GetFunction(p,a,b)     (p)->GetFunction(a,b)
#endif

/*****************************************************************************
 * IDirect3DPixelShader9 interface
 */
#define INTERFACE IDirect3DPixelShader9
DECLARE_INTERFACE_IID_(IDirect3DPixelShader9,IUnknown,"6d3bdbdc-5b02-4415-b852-ce5e8bccb289")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DPixelShader9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(GetFunction)(THIS_ void*, UINT* pSizeOfData) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DPixelShader9,        0x6d3bdbdc, 0x5b02, 0x4415, 0xb8, 0x52, 0xce, 0x5e, 0x8b, 0xcc, 0xb2, 0x89);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DPixelShader9_QueryInterface(p,a,b)  (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DPixelShader9_AddRef(p)              (p)->lpVtbl->AddRef(p)
#define IDirect3DPixelShader9_Release(p)             (p)->lpVtbl->Release(p)
/*** IDirect3DPixelShader9 methods ***/
#define IDirect3DPixelShader9_GetDevice(p,a)         (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DPixelShader9_GetFunction(p,a,b)     (p)->lpVtbl->GetFunction(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DPixelShader9_QueryInterface(p,a,b)  (p)->QueryInterface(a,b)
#define IDirect3DPixelShader9_AddRef(p)              (p)->AddRef()
#define IDirect3DPixelShader9_Release(p)             (p)->Release()
/*** IDirect3DPixelShader9 methods ***/
#define IDirect3DPixelShader9_GetDevice(p,a)         (p)->GetDevice(a)
#define IDirect3DPixelShader9_GetFunction(p,a,b)     (p)->GetFunction(a,b)
#endif

/*****************************************************************************
 * IDirect3DStateBlock9 interface
 */
#define INTERFACE IDirect3DStateBlock9
DECLARE_INTERFACE_IID_(IDirect3DStateBlock9,IUnknown,"b07c4fe5-310d-4ba8-a23c-4f0f206f218b")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DStateBlock9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD(Capture)(THIS) PURE;
    STDMETHOD(Apply)(THIS) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DStateBlock9,         0xb07c4fe5, 0x310d, 0x4ba8, 0xa2, 0x3c, 0x4f, 0xf, 0x20, 0x6f, 0x21, 0x8b);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DStateBlock9_QueryInterface(p,a,b)  (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DStateBlock9_AddRef(p)              (p)->lpVtbl->AddRef(p)
#define IDirect3DStateBlock9_Release(p)             (p)->lpVtbl->Release(p)
/*** IDirect3DStateBlock9 methods ***/
#define IDirect3DStateBlock9_GetDevice(p,a)         (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DStateBlock9_Capture(p)             (p)->lpVtbl->Capture(p)
#define IDirect3DStateBlock9_Apply(p)               (p)->lpVtbl->Apply(p)
#else
/*** IUnknown methods ***/
#define IDirect3DStateBlock9_QueryInterface(p,a,b)  (p)->QueryInterface(a,b)
#define IDirect3DStateBlock9_AddRef(p)              (p)->AddRef()
#define IDirect3DStateBlock9_Release(p)             (p)->Release()
/*** IDirect3DStateBlock9 methods ***/
#define IDirect3DStateBlock9_GetDevice(p,a)         (p)->GetDevice(a)
#define IDirect3DStateBlock9_Capture(p)             (p)->Capture()
#define IDirect3DStateBlock9_Apply(p)               (p)->Apply()
#endif

/*****************************************************************************
 * IDirect3DQuery9 interface
 */
#define INTERFACE IDirect3DQuery9
DECLARE_INTERFACE_IID_(IDirect3DQuery9,IUnknown,"d9771460-a695-4f26-bbd3-27b840b541cc")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DQuery9 methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9** ppDevice) PURE;
    STDMETHOD_(D3DQUERYTYPE, GetType)(THIS) PURE;
    STDMETHOD_(DWORD, GetDataSize)(THIS) PURE;
    STDMETHOD(Issue)(THIS_ DWORD dwIssueFlags) PURE;
    STDMETHOD(GetData)(THIS_ void* pData, DWORD dwSize, DWORD dwGetDataFlags) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DQuery9,              0xd9771460, 0xa695, 0x4f26, 0xbb, 0xd3, 0x27, 0xb8, 0x40, 0xb5, 0x41, 0xcc);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DQuery9_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DQuery9_AddRef(p) (p)->lpVtbl->AddRef(p)
#define IDirect3DQuery9_Release(p) (p)->lpVtbl->Release(p)
/*** IDirect3DQuery9 ***/
#define IDirect3DQuery9_GetDevice(p,a) (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DQuery9_GetType(p) (p)->lpVtbl->GetType(p)
#define IDirect3DQuery9_GetDataSize(p) (p)->lpVtbl->GetDataSize(p)
#define IDirect3DQuery9_Issue(p,a) (p)->lpVtbl->Issue(p,a)
#define IDirect3DQuery9_GetData(p,a,b,c) (p)->lpVtbl->GetData(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirect3DQuery9_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DQuery9_AddRef(p) (p)->AddRef()
#define IDirect3DQuery9_Release(p) (p)->Release()
/*** IDirect3DQuery9 ***/
#define IDirect3DQuery9_GetDevice(p,a) (p)->GetDevice(a)
#define IDirect3DQuery9_GetType(p) (p)->GetType()
#define IDirect3DQuery9_GetDataSize(p) (p)->GetDataSize()
#define IDirect3DQuery9_Issue(p,a) (p)->Issue(a)
#define IDirect3DQuery9_GetData(p,a,b,c) (p)->GetData(a,b,c)
#endif

/*****************************************************************************
 * IDirect3DDevice9 interface
 */
#define INTERFACE IDirect3DDevice9
DECLARE_INTERFACE_IID_(IDirect3DDevice9,IUnknown,"d0223b96-bf7a-43fd-92bd-a43b0d82b9eb")
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DDevice9 methods ***/
    STDMETHOD(TestCooperativeLevel)(THIS) PURE;
    STDMETHOD_(UINT, GetAvailableTextureMem)(THIS) PURE;
    STDMETHOD(EvictManagedResources)(THIS) PURE;
    STDMETHOD(GetDirect3D)(THIS_ IDirect3D9** ppD3D9) PURE;
    STDMETHOD(GetDeviceCaps)(THIS_ D3DCAPS9* pCaps) PURE;
    STDMETHOD(GetDisplayMode)(THIS_ UINT iSwapChain, D3DDISPLAYMODE* pMode) PURE;
    STDMETHOD(GetCreationParameters)(THIS_ D3DDEVICE_CREATION_PARAMETERS *pParameters) PURE;
    STDMETHOD(SetCursorProperties)(THIS_ UINT XHotSpot, UINT YHotSpot, IDirect3DSurface9* pCursorBitmap) PURE;
    STDMETHOD_(void, SetCursorPosition)(THIS_ int X,int Y, DWORD Flags) PURE;
    STDMETHOD_(WINBOOL, ShowCursor)(THIS_ WINBOOL bShow) PURE;
    STDMETHOD(CreateAdditionalSwapChain)(THIS_ D3DPRESENT_PARAMETERS* pPresentationParameters, IDirect3DSwapChain9** pSwapChain) PURE;
    STDMETHOD(GetSwapChain)(THIS_ UINT iSwapChain, IDirect3DSwapChain9** pSwapChain) PURE;
    STDMETHOD_(UINT, GetNumberOfSwapChains)(THIS) PURE;
    STDMETHOD(Reset)(THIS_ D3DPRESENT_PARAMETERS* pPresentationParameters) PURE;
    STDMETHOD(Present)(THIS_ const RECT *src_rect, const RECT *dst_rect,
            HWND dst_window_override, const RGNDATA *dirty_region) PURE;
    STDMETHOD(GetBackBuffer)(THIS_ UINT iSwapChain, UINT iBackBuffer, D3DBACKBUFFER_TYPE Type, IDirect3DSurface9** ppBackBuffer) PURE;
    STDMETHOD(GetRasterStatus)(THIS_ UINT iSwapChain, D3DRASTER_STATUS* pRasterStatus) PURE;
    STDMETHOD(SetDialogBoxMode)(THIS_ WINBOOL bEnableDialogs) PURE;
    STDMETHOD_(void, SetGammaRamp)(THIS_ UINT swapchain_idx, DWORD flags, const D3DGAMMARAMP *ramp) PURE;
    STDMETHOD_(void, GetGammaRamp)(THIS_ UINT iSwapChain, D3DGAMMARAMP* pRamp) PURE;
    STDMETHOD(CreateTexture)(THIS_ UINT Width, UINT Height, UINT Levels, DWORD Usage, D3DFORMAT Format, D3DPOOL Pool, IDirect3DTexture9** ppTexture, HANDLE* pSharedHandle) PURE;
    STDMETHOD(CreateVolumeTexture)(THIS_ UINT Width, UINT Height, UINT Depth, UINT Levels, DWORD Usage, D3DFORMAT Format, D3DPOOL Pool, IDirect3DVolumeTexture9** ppVolumeTexture, HANDLE* pSharedHandle) PURE;
    STDMETHOD(CreateCubeTexture)(THIS_ UINT EdgeLength, UINT Levels, DWORD Usage, D3DFORMAT Format, D3DPOOL Pool, IDirect3DCubeTexture9** ppCubeTexture, HANDLE* pSharedHandle) PURE;
    STDMETHOD(CreateVertexBuffer)(THIS_ UINT Length, DWORD Usage, DWORD FVF, D3DPOOL Pool, IDirect3DVertexBuffer9** ppVertexBuffer, HANDLE* pSharedHandle) PURE;
    STDMETHOD(CreateIndexBuffer)(THIS_ UINT Length, DWORD Usage, D3DFORMAT Format, D3DPOOL Pool, IDirect3DIndexBuffer9** ppIndexBuffer, HANDLE* pSharedHandle) PURE;
    STDMETHOD(CreateRenderTarget)(THIS_ UINT Width, UINT Height, D3DFORMAT Format, D3DMULTISAMPLE_TYPE MultiSample, DWORD MultisampleQuality, WINBOOL Lockable, IDirect3DSurface9** ppSurface, HANDLE* pSharedHandle) PURE;
    STDMETHOD(CreateDepthStencilSurface)(THIS_ UINT Width, UINT Height, D3DFORMAT Format, D3DMULTISAMPLE_TYPE MultiSample, DWORD MultisampleQuality, WINBOOL Discard, IDirect3DSurface9** ppSurface, HANDLE* pSharedHandle) PURE;
    STDMETHOD(UpdateSurface)(THIS_ IDirect3DSurface9 *src_surface, const RECT *src_rect,
            IDirect3DSurface9 *dst_surface, const POINT *dst_point) PURE;
    STDMETHOD(UpdateTexture)(THIS_ IDirect3DBaseTexture9* pSourceTexture, IDirect3DBaseTexture9* pDestinationTexture) PURE;
    STDMETHOD(GetRenderTargetData)(THIS_ IDirect3DSurface9* pRenderTarget, IDirect3DSurface9* pDestSurface) PURE;
    STDMETHOD(GetFrontBufferData)(THIS_ UINT iSwapChain, IDirect3DSurface9* pDestSurface) PURE;
    STDMETHOD(StretchRect)(THIS_ IDirect3DSurface9 *src_surface, const RECT *src_rect,
            IDirect3DSurface9 *dst_surface, const RECT *dst_rect, D3DTEXTUREFILTERTYPE filter) PURE;
    STDMETHOD(ColorFill)(THIS_ IDirect3DSurface9 *surface, const RECT *rect, D3DCOLOR color) PURE;
    STDMETHOD(CreateOffscreenPlainSurface)(THIS_ UINT Width, UINT Height, D3DFORMAT Format, D3DPOOL Pool, IDirect3DSurface9** ppSurface, HANDLE* pSharedHandle) PURE;
    STDMETHOD(SetRenderTarget)(THIS_ DWORD RenderTargetIndex, IDirect3DSurface9* pRenderTarget) PURE;
    STDMETHOD(GetRenderTarget)(THIS_ DWORD RenderTargetIndex, IDirect3DSurface9** ppRenderTarget) PURE;
    STDMETHOD(SetDepthStencilSurface)(THIS_ IDirect3DSurface9* pNewZStencil) PURE;
    STDMETHOD(GetDepthStencilSurface)(THIS_ IDirect3DSurface9** ppZStencilSurface) PURE;
    STDMETHOD(BeginScene)(THIS) PURE;
    STDMETHOD(EndScene)(THIS) PURE;
    STDMETHOD(Clear)(THIS_ DWORD rect_count, const D3DRECT *rects, DWORD flags,
            D3DCOLOR color, float z, DWORD stencil) PURE;
    STDMETHOD(SetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, const D3DMATRIX *matrix) PURE;
    STDMETHOD(GetTransform)(THIS_ D3DTRANSFORMSTATETYPE State, D3DMATRIX* pMatrix) PURE;
    STDMETHOD(MultiplyTransform)(THIS_ D3DTRANSFORMSTATETYPE state, const D3DMATRIX *matrix) PURE;
    STDMETHOD(SetViewport)(THIS_ const D3DVIEWPORT9 *viewport) PURE;
    STDMETHOD(GetViewport)(THIS_ D3DVIEWPORT9* pViewport) PURE;
    STDMETHOD(SetMaterial)(THIS_ const D3DMATERIAL9 *material) PURE;
    STDMETHOD(GetMaterial)(THIS_ D3DMATERIAL9* pMaterial) PURE;
    STDMETHOD(SetLight)(THIS_ DWORD index, const D3DLIGHT9 *light) PURE;
    STDMETHOD(GetLight)(THIS_ DWORD Index, D3DLIGHT9*) PURE;
    STDMETHOD(LightEnable)(THIS_ DWORD Index, WINBOOL Enable) PURE;
    STDMETHOD(GetLightEnable)(THIS_ DWORD Index, WINBOOL* pEnable) PURE;
    STDMETHOD(SetClipPlane)(THIS_ DWORD index, const float *plane) PURE;
    STDMETHOD(GetClipPlane)(THIS_ DWORD Index, float* pPlane) PURE;
    STDMETHOD(SetRenderState)(THIS_ D3DRENDERSTATETYPE State, DWORD Value) PURE;
    STDMETHOD(GetRenderState)(THIS_ D3DRENDERSTATETYPE State, DWORD* pValue) PURE;
    STDMETHOD(CreateStateBlock)(THIS_ D3DSTATEBLOCKTYPE Type, IDirect3DStateBlock9** ppSB) PURE;
    STDMETHOD(BeginStateBlock)(THIS) PURE;
    STDMETHOD(EndStateBlock)(THIS_ IDirect3DStateBlock9** ppSB) PURE;
    STDMETHOD(SetClipStatus)(THIS_ const D3DCLIPSTATUS9 *clip_status) PURE;
    STDMETHOD(GetClipStatus)(THIS_ D3DCLIPSTATUS9* pClipStatus) PURE;
    STDMETHOD(GetTexture)(THIS_ DWORD Stage, IDirect3DBaseTexture9** ppTexture) PURE;
    STDMETHOD(SetTexture)(THIS_ DWORD Stage, IDirect3DBaseTexture9* pTexture) PURE;
    STDMETHOD(GetTextureStageState)(THIS_ DWORD Stage, D3DTEXTURESTAGESTATETYPE Type, DWORD* pValue) PURE;
    STDMETHOD(SetTextureStageState)(THIS_ DWORD Stage, D3DTEXTURESTAGESTATETYPE Type, DWORD Value) PURE;
    STDMETHOD(GetSamplerState)(THIS_ DWORD Sampler, D3DSAMPLERSTATETYPE Type, DWORD* pValue) PURE;
    STDMETHOD(SetSamplerState)(THIS_ DWORD Sampler, D3DSAMPLERSTATETYPE Type, DWORD Value) PURE;
    STDMETHOD(ValidateDevice)(THIS_ DWORD* pNumPasses) PURE;
    STDMETHOD(SetPaletteEntries)(THIS_ UINT palette_idx, const PALETTEENTRY *entries) PURE;
    STDMETHOD(GetPaletteEntries)(THIS_ UINT PaletteNumber,PALETTEENTRY* pEntries) PURE;
    STDMETHOD(SetCurrentTexturePalette)(THIS_ UINT PaletteNumber) PURE;
    STDMETHOD(GetCurrentTexturePalette)(THIS_ UINT *PaletteNumber) PURE;
    STDMETHOD(SetScissorRect)(THIS_ const RECT *rect) PURE;
    STDMETHOD(GetScissorRect)(THIS_ RECT* pRect) PURE;
    STDMETHOD(SetSoftwareVertexProcessing)(THIS_ WINBOOL bSoftware) PURE;
    STDMETHOD_(WINBOOL, GetSoftwareVertexProcessing)(THIS) PURE;
    STDMETHOD(SetNPatchMode)(THIS_ float nSegments) PURE;
    STDMETHOD_(float, GetNPatchMode)(THIS) PURE;
    STDMETHOD(DrawPrimitive)(THIS_ D3DPRIMITIVETYPE PrimitiveType, UINT StartVertex, UINT PrimitiveCount) PURE;
    STDMETHOD(DrawIndexedPrimitive)(THIS_ D3DPRIMITIVETYPE, INT BaseVertexIndex, UINT MinVertexIndex, UINT NumVertices, UINT startIndex, UINT primCount) PURE;
    STDMETHOD(DrawPrimitiveUP)(THIS_ D3DPRIMITIVETYPE primitive_type,
            UINT primitive_count, const void *data, UINT stride) PURE;
    STDMETHOD(DrawIndexedPrimitiveUP)(THIS_ D3DPRIMITIVETYPE primitive_type, UINT min_vertex_idx, UINT vertex_count,
            UINT primitive_count, const void *index_data, D3DFORMAT index_format, const void *data, UINT stride) PURE;
    STDMETHOD(ProcessVertices)(THIS_ UINT SrcStartIndex, UINT DestIndex, UINT VertexCount, IDirect3DVertexBuffer9* pDestBuffer, IDirect3DVertexDeclaration9* pVertexDecl, DWORD Flags) PURE;
    STDMETHOD(CreateVertexDeclaration)(THIS_ const D3DVERTEXELEMENT9 *elements,
            IDirect3DVertexDeclaration9 **declaration) PURE;
    STDMETHOD(SetVertexDeclaration)(THIS_ IDirect3DVertexDeclaration9* pDecl) PURE;
    STDMETHOD(GetVertexDeclaration)(THIS_ IDirect3DVertexDeclaration9** ppDecl) PURE;
    STDMETHOD(SetFVF)(THIS_ DWORD FVF) PURE;
    STDMETHOD(GetFVF)(THIS_ DWORD* pFVF) PURE;
    STDMETHOD(CreateVertexShader)(THIS_ const DWORD *byte_code, IDirect3DVertexShader9 **shader) PURE;
    STDMETHOD(SetVertexShader)(THIS_ IDirect3DVertexShader9* pShader) PURE;
    STDMETHOD(GetVertexShader)(THIS_ IDirect3DVertexShader9** ppShader) PURE;
    STDMETHOD(SetVertexShaderConstantF)(THIS_ UINT reg_idx, const float *data, UINT count) PURE;
    STDMETHOD(GetVertexShaderConstantF)(THIS_ UINT StartRegister, float* pConstantData, UINT Vector4fCount) PURE;
    STDMETHOD(SetVertexShaderConstantI)(THIS_ UINT reg_idx, const int *data, UINT count) PURE;
    STDMETHOD(GetVertexShaderConstantI)(THIS_ UINT StartRegister, int* pConstantData, UINT Vector4iCount) PURE;
    STDMETHOD(SetVertexShaderConstantB)(THIS_ UINT reg_idx, const WINBOOL *data, UINT count) PURE;
    STDMETHOD(GetVertexShaderConstantB)(THIS_ UINT StartRegister, WINBOOL* pConstantData, UINT BoolCount) PURE;
    STDMETHOD(SetStreamSource)(THIS_ UINT StreamNumber, IDirect3DVertexBuffer9* pStreamData, UINT OffsetInBytes, UINT Stride) PURE;
    STDMETHOD(GetStreamSource)(THIS_ UINT StreamNumber, IDirect3DVertexBuffer9** ppStreamData, UINT* OffsetInBytes, UINT* pStride) PURE;
    STDMETHOD(SetStreamSourceFreq)(THIS_ UINT StreamNumber, UINT Divider) PURE;
    STDMETHOD(GetStreamSourceFreq)(THIS_ UINT StreamNumber, UINT* Divider) PURE;
    STDMETHOD(SetIndices)(THIS_ IDirect3DIndexBuffer9* pIndexData) PURE;
    STDMETHOD(GetIndices)(THIS_ IDirect3DIndexBuffer9** ppIndexData) PURE;
    STDMETHOD(CreatePixelShader)(THIS_ const DWORD *byte_code, IDirect3DPixelShader9 **shader) PURE;
    STDMETHOD(SetPixelShader)(THIS_ IDirect3DPixelShader9* pShader) PURE;
    STDMETHOD(GetPixelShader)(THIS_ IDirect3DPixelShader9** ppShader) PURE;
    STDMETHOD(SetPixelShaderConstantF)(THIS_ UINT reg_idx, const float *data, UINT count) PURE;
    STDMETHOD(GetPixelShaderConstantF)(THIS_ UINT StartRegister, float* pConstantData, UINT Vector4fCount) PURE;
    STDMETHOD(SetPixelShaderConstantI)(THIS_ UINT reg_idx, const int *data, UINT count) PURE;
    STDMETHOD(GetPixelShaderConstantI)(THIS_ UINT StartRegister, int* pConstantData, UINT Vector4iCount) PURE;
    STDMETHOD(SetPixelShaderConstantB)(THIS_ UINT reg_idx, const WINBOOL *data, UINT count) PURE;
    STDMETHOD(GetPixelShaderConstantB)(THIS_ UINT StartRegister, WINBOOL* pConstantData, UINT BoolCount) PURE;
    STDMETHOD(DrawRectPatch)(THIS_ UINT handle, const float *segment_count, const D3DRECTPATCH_INFO *patch_info) PURE;
    STDMETHOD(DrawTriPatch)(THIS_ UINT handle, const float *segment_count, const D3DTRIPATCH_INFO *patch_info) PURE;
    STDMETHOD(DeletePatch)(THIS_ UINT Handle) PURE;
    STDMETHOD(CreateQuery)(THIS_ D3DQUERYTYPE Type, IDirect3DQuery9** ppQuery) PURE;
};
#undef INTERFACE

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DDevice9,             0xd0223b96, 0xbf7a, 0x43fd, 0x92, 0xbd, 0xa4, 0x3b, 0xd, 0x82, 0xb9, 0xeb);
#endif

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DDevice9_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DDevice9_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DDevice9_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DDevice9 methods ***/
#define IDirect3DDevice9_TestCooperativeLevel(p)                       (p)->lpVtbl->TestCooperativeLevel(p)
#define IDirect3DDevice9_GetAvailableTextureMem(p)                     (p)->lpVtbl->GetAvailableTextureMem(p)
#define IDirect3DDevice9_EvictManagedResources(p)                      (p)->lpVtbl->EvictManagedResources(p)
#define IDirect3DDevice9_GetDirect3D(p,a)                              (p)->lpVtbl->GetDirect3D(p,a)
#define IDirect3DDevice9_GetDeviceCaps(p,a)                            (p)->lpVtbl->GetDeviceCaps(p,a)
#define IDirect3DDevice9_GetDisplayMode(p,a,b)                         (p)->lpVtbl->GetDisplayMode(p,a,b)
#define IDirect3DDevice9_GetCreationParameters(p,a)                    (p)->lpVtbl->GetCreationParameters(p,a)
#define IDirect3DDevice9_SetCursorProperties(p,a,b,c)                  (p)->lpVtbl->SetCursorProperties(p,a,b,c)
#define IDirect3DDevice9_SetCursorPosition(p,a,b,c)                    (p)->lpVtbl->SetCursorPosition(p,a,b,c)
#define IDirect3DDevice9_ShowCursor(p,a)                               (p)->lpVtbl->ShowCursor(p,a)
#define IDirect3DDevice9_CreateAdditionalSwapChain(p,a,b)              (p)->lpVtbl->CreateAdditionalSwapChain(p,a,b)
#define IDirect3DDevice9_GetSwapChain(p,a,b)                           (p)->lpVtbl->GetSwapChain(p,a,b)
#define IDirect3DDevice9_GetNumberOfSwapChains(p)                      (p)->lpVtbl->GetNumberOfSwapChains(p)
#define IDirect3DDevice9_Reset(p,a)                                    (p)->lpVtbl->Reset(p,a)
#define IDirect3DDevice9_Present(p,a,b,c,d)                            (p)->lpVtbl->Present(p,a,b,c,d)
#define IDirect3DDevice9_GetBackBuffer(p,a,b,c,d)                      (p)->lpVtbl->GetBackBuffer(p,a,b,c,d)
#define IDirect3DDevice9_GetRasterStatus(p,a,b)                        (p)->lpVtbl->GetRasterStatus(p,a,b)
#define IDirect3DDevice9_SetDialogBoxMode(p,a)                         (p)->lpVtbl->SetDialogBoxMode(p,a)
#define IDirect3DDevice9_SetGammaRamp(p,a,b,c)                         (p)->lpVtbl->SetGammaRamp(p,a,b,c)
#define IDirect3DDevice9_GetGammaRamp(p,a,b)                           (p)->lpVtbl->GetGammaRamp(p,a,b)
#define IDirect3DDevice9_CreateTexture(p,a,b,c,d,e,f,g,h)              (p)->lpVtbl->CreateTexture(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9_CreateVolumeTexture(p,a,b,c,d,e,f,g,h,i)      (p)->lpVtbl->CreateVolumeTexture(p,a,b,c,d,e,f,g,h,i)
#define IDirect3DDevice9_CreateCubeTexture(p,a,b,c,d,e,f,g)            (p)->lpVtbl->CreateCubeTexture(p,a,b,c,d,e,f,g)
#define IDirect3DDevice9_CreateVertexBuffer(p,a,b,c,d,e,f)             (p)->lpVtbl->CreateVertexBuffer(p,a,b,c,d,e,f)
#define IDirect3DDevice9_CreateIndexBuffer(p,a,b,c,d,e,f)              (p)->lpVtbl->CreateIndexBuffer(p,a,b,c,d,e,f)
#define IDirect3DDevice9_CreateRenderTarget(p,a,b,c,d,e,f,g,h)         (p)->lpVtbl->CreateRenderTarget(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9_CreateDepthStencilSurface(p,a,b,c,d,e,f,g,h)  (p)->lpVtbl->CreateDepthStencilSurface(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9_UpdateSurface(p,a,b,c,d)                      (p)->lpVtbl->UpdateSurface(p,a,b,c,d)
#define IDirect3DDevice9_UpdateTexture(p,a,b)                          (p)->lpVtbl->UpdateTexture(p,a,b)
#define IDirect3DDevice9_GetRenderTargetData(p,a,b)                    (p)->lpVtbl->GetRenderTargetData(p,a,b)
#define IDirect3DDevice9_GetFrontBufferData(p,a,b)                     (p)->lpVtbl->GetFrontBufferData(p,a,b)
#define IDirect3DDevice9_StretchRect(p,a,b,c,d,e)                      (p)->lpVtbl->StretchRect(p,a,b,c,d,e)
#define IDirect3DDevice9_ColorFill(p,a,b,c)                            (p)->lpVtbl->ColorFill(p,a,b,c)
#define IDirect3DDevice9_CreateOffscreenPlainSurface(p,a,b,c,d,e,f)    (p)->lpVtbl->CreateOffscreenPlainSurface(p,a,b,c,d,e,f)
#define IDirect3DDevice9_SetRenderTarget(p,a,b)                        (p)->lpVtbl->SetRenderTarget(p,a,b)
#define IDirect3DDevice9_GetRenderTarget(p,a,b)                        (p)->lpVtbl->GetRenderTarget(p,a,b)
#define IDirect3DDevice9_SetDepthStencilSurface(p,a)                   (p)->lpVtbl->SetDepthStencilSurface(p,a)
#define IDirect3DDevice9_GetDepthStencilSurface(p,a)                   (p)->lpVtbl->GetDepthStencilSurface(p,a)
#define IDirect3DDevice9_BeginScene(p)                                 (p)->lpVtbl->BeginScene(p)
#define IDirect3DDevice9_EndScene(p)                                   (p)->lpVtbl->EndScene(p)
#define IDirect3DDevice9_Clear(p,a,b,c,d,e,f)                          (p)->lpVtbl->Clear(p,a,b,c,d,e,f)
#define IDirect3DDevice9_SetTransform(p,a,b)                           (p)->lpVtbl->SetTransform(p,a,b)
#define IDirect3DDevice9_GetTransform(p,a,b)                           (p)->lpVtbl->GetTransform(p,a,b)
#define IDirect3DDevice9_MultiplyTransform(p,a,b)                      (p)->lpVtbl->MultiplyTransform(p,a,b)
#define IDirect3DDevice9_SetViewport(p,a)                              (p)->lpVtbl->SetViewport(p,a)
#define IDirect3DDevice9_GetViewport(p,a)                              (p)->lpVtbl->GetViewport(p,a)
#define IDirect3DDevice9_SetMaterial(p,a)                              (p)->lpVtbl->SetMaterial(p,a)
#define IDirect3DDevice9_GetMaterial(p,a)                              (p)->lpVtbl->GetMaterial(p,a)
#define IDirect3DDevice9_SetLight(p,a,b)                               (p)->lpVtbl->SetLight(p,a,b)
#define IDirect3DDevice9_GetLight(p,a,b)                               (p)->lpVtbl->GetLight(p,a,b)
#define IDirect3DDevice9_LightEnable(p,a,b)                            (p)->lpVtbl->LightEnable(p,a,b)
#define IDirect3DDevice9_GetLightEnable(p,a,b)                         (p)->lpVtbl->GetLightEnable(p,a,b)
#define IDirect3DDevice9_SetClipPlane(p,a,b)                           (p)->lpVtbl->SetClipPlane(p,a,b)
#define IDirect3DDevice9_GetClipPlane(p,a,b)                           (p)->lpVtbl->GetClipPlane(p,a,b)
#define IDirect3DDevice9_SetRenderState(p,a,b)                         (p)->lpVtbl->SetRenderState(p,a,b)
#define IDirect3DDevice9_GetRenderState(p,a,b)                         (p)->lpVtbl->GetRenderState(p,a,b)
#define IDirect3DDevice9_CreateStateBlock(p,a,b)                       (p)->lpVtbl->CreateStateBlock(p,a,b)
#define IDirect3DDevice9_BeginStateBlock(p)                            (p)->lpVtbl->BeginStateBlock(p)
#define IDirect3DDevice9_EndStateBlock(p,a)                            (p)->lpVtbl->EndStateBlock(p,a)
#define IDirect3DDevice9_SetClipStatus(p,a)                            (p)->lpVtbl->SetClipStatus(p,a)
#define IDirect3DDevice9_GetClipStatus(p,a)                            (p)->lpVtbl->GetClipStatus(p,a)
#define IDirect3DDevice9_GetTexture(p,a,b)                             (p)->lpVtbl->GetTexture(p,a,b)
#define IDirect3DDevice9_SetTexture(p,a,b)                             (p)->lpVtbl->SetTexture(p,a,b)
#define IDirect3DDevice9_GetTextureStageState(p,a,b,c)                 (p)->lpVtbl->GetTextureStageState(p,a,b,c)
#define IDirect3DDevice9_SetTextureStageState(p,a,b,c)                 (p)->lpVtbl->SetTextureStageState(p,a,b,c)
#define IDirect3DDevice9_GetSamplerState(p,a,b,c)                      (p)->lpVtbl->GetSamplerState(p,a,b,c)
#define IDirect3DDevice9_SetSamplerState(p,a,b,c)                      (p)->lpVtbl->SetSamplerState(p,a,b,c)
#define IDirect3DDevice9_ValidateDevice(p,a)                           (p)->lpVtbl->ValidateDevice(p,a)
#define IDirect3DDevice9_SetPaletteEntries(p,a,b)                      (p)->lpVtbl->SetPaletteEntries(p,a,b)
#define IDirect3DDevice9_GetPaletteEntries(p,a,b)                      (p)->lpVtbl->GetPaletteEntries(p,a,b)
#define IDirect3DDevice9_SetCurrentTexturePalette(p,a)                 (p)->lpVtbl->SetCurrentTexturePalette(p,a)
#define IDirect3DDevice9_GetCurrentTexturePalette(p,a)                 (p)->lpVtbl->GetCurrentTexturePalette(p,a)
#define IDirect3DDevice9_SetScissorRect(p,a)                           (p)->lpVtbl->SetScissorRect(p,a)
#define IDirect3DDevice9_GetScissorRect(p,a)                           (p)->lpVtbl->GetScissorRect(p,a)
#define IDirect3DDevice9_SetSoftwareVertexProcessing(p,a)              (p)->lpVtbl->SetSoftwareVertexProcessing(p,a)
#define IDirect3DDevice9_GetSoftwareVertexProcessing(p)                (p)->lpVtbl->GetSoftwareVertexProcessing(p)
#define IDirect3DDevice9_SetNPatchMode(p,a)                            (p)->lpVtbl->SetNPatchMode(p,a)
#define IDirect3DDevice9_GetNPatchMode(p)                              (p)->lpVtbl->GetNPatchMode(p)
#define IDirect3DDevice9_DrawPrimitive(p,a,b,c)                        (p)->lpVtbl->DrawPrimitive(p,a,b,c)
#define IDirect3DDevice9_DrawIndexedPrimitive(p,a,b,c,d,e,f)           (p)->lpVtbl->DrawIndexedPrimitive(p,a,b,c,d,e,f)
#define IDirect3DDevice9_DrawPrimitiveUP(p,a,b,c,d)                    (p)->lpVtbl->DrawPrimitiveUP(p,a,b,c,d)
#define IDirect3DDevice9_DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h)     (p)->lpVtbl->DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9_ProcessVertices(p,a,b,c,d,e,f)                (p)->lpVtbl->ProcessVertices(p,a,b,c,d,e,f)
#define IDirect3DDevice9_CreateVertexDeclaration(p,a,b)                (p)->lpVtbl->CreateVertexDeclaration(p,a,b)
#define IDirect3DDevice9_SetVertexDeclaration(p,a)                     (p)->lpVtbl->SetVertexDeclaration(p,a)
#define IDirect3DDevice9_GetVertexDeclaration(p,a)                     (p)->lpVtbl->GetVertexDeclaration(p,a)
#define IDirect3DDevice9_SetFVF(p,a)                                   (p)->lpVtbl->SetFVF(p,a)
#define IDirect3DDevice9_GetFVF(p,a)                                   (p)->lpVtbl->GetFVF(p,a)
#define IDirect3DDevice9_CreateVertexShader(p,a,b)                     (p)->lpVtbl->CreateVertexShader(p,a,b)
#define IDirect3DDevice9_SetVertexShader(p,a)                          (p)->lpVtbl->SetVertexShader(p,a)
#define IDirect3DDevice9_GetVertexShader(p,a)                          (p)->lpVtbl->GetVertexShader(p,a)
#define IDirect3DDevice9_SetVertexShaderConstantF(p,a,b,c)             (p)->lpVtbl->SetVertexShaderConstantF(p,a,b,c)
#define IDirect3DDevice9_GetVertexShaderConstantF(p,a,b,c)             (p)->lpVtbl->GetVertexShaderConstantF(p,a,b,c)
#define IDirect3DDevice9_SetVertexShaderConstantI(p,a,b,c)             (p)->lpVtbl->SetVertexShaderConstantI(p,a,b,c)
#define IDirect3DDevice9_GetVertexShaderConstantI(p,a,b,c)             (p)->lpVtbl->GetVertexShaderConstantI(p,a,b,c)
#define IDirect3DDevice9_SetVertexShaderConstantB(p,a,b,c)             (p)->lpVtbl->SetVertexShaderConstantB(p,a,b,c)
#define IDirect3DDevice9_GetVertexShaderConstantB(p,a,b,c)             (p)->lpVtbl->GetVertexShaderConstantB(p,a,b,c)
#define IDirect3DDevice9_SetStreamSource(p,a,b,c,d)                    (p)->lpVtbl->SetStreamSource(p,a,b,c,d)
#define IDirect3DDevice9_GetStreamSource(p,a,b,c,d)                    (p)->lpVtbl->GetStreamSource(p,a,b,c,d)
#define IDirect3DDevice9_SetStreamSourceFreq(p,a,b)                    (p)->lpVtbl->SetStreamSourceFreq(p,a,b)
#define IDirect3DDevice9_GetStreamSourceFreq(p,a,b)                    (p)->lpVtbl->GetStreamSourceFreq(p,a,b)
#define IDirect3DDevice9_SetIndices(p,a)                               (p)->lpVtbl->SetIndices(p,a)
#define IDirect3DDevice9_GetIndices(p,a)                               (p)->lpVtbl->GetIndices(p,a)
#define IDirect3DDevice9_CreatePixelShader(p,a,b)                      (p)->lpVtbl->CreatePixelShader(p,a,b)
#define IDirect3DDevice9_SetPixelShader(p,a)                           (p)->lpVtbl->SetPixelShader(p,a)
#define IDirect3DDevice9_GetPixelShader(p,a)                           (p)->lpVtbl->GetPixelShader(p,a)
#define IDirect3DDevice9_SetPixelShaderConstantF(p,a,b,c)              (p)->lpVtbl->SetPixelShaderConstantF(p,a,b,c)
#define IDirect3DDevice9_GetPixelShaderConstantF(p,a,b,c)              (p)->lpVtbl->GetPixelShaderConstantF(p,a,b,c)
#define IDirect3DDevice9_SetPixelShaderConstantI(p,a,b,c)              (p)->lpVtbl->SetPixelShaderConstantI(p,a,b,c)
#define IDirect3DDevice9_GetPixelShaderConstantI(p,a,b,c)              (p)->lpVtbl->GetPixelShaderConstantI(p,a,b,c)
#define IDirect3DDevice9_SetPixelShaderConstantB(p,a,b,c)              (p)->lpVtbl->SetPixelShaderConstantB(p,a,b,c)
#define IDirect3DDevice9_GetPixelShaderConstantB(p,a,b,c)              (p)->lpVtbl->GetPixelShaderConstantB(p,a,b,c)
#define IDirect3DDevice9_DrawRectPatch(p,a,b,c)                        (p)->lpVtbl->DrawRectPatch(p,a,b,c)
#define IDirect3DDevice9_DrawTriPatch(p,a,b,c)                         (p)->lpVtbl->DrawTriPatch(p,a,b,c)
#define IDirect3DDevice9_DeletePatch(p,a)                              (p)->lpVtbl->DeletePatch(p,a)
#define IDirect3DDevice9_CreateQuery(p,a,b)                            (p)->lpVtbl->CreateQuery(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DDevice9_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DDevice9_AddRef(p)             (p)->AddRef()
#define IDirect3DDevice9_Release(p)            (p)->Release()
/*** IDirect3DDevice9 methods ***/
#define IDirect3DDevice9_TestCooperativeLevel(p)                       (p)->TestCooperativeLevel()
#define IDirect3DDevice9_GetAvailableTextureMem(p)                     (p)->GetAvailableTextureMem()
#define IDirect3DDevice9_EvictManagedResources(p)                      (p)->EvictManagedResources()
#define IDirect3DDevice9_GetDirect3D(p,a)                              (p)->GetDirect3D(a)
#define IDirect3DDevice9_GetDeviceCaps(p,a)                            (p)->GetDeviceCaps(a)
#define IDirect3DDevice9_GetDisplayMode(p,a,b)                         (p)->GetDisplayMode(a,b)
#define IDirect3DDevice9_GetCreationParameters(p,a)                    (p)->GetCreationParameters(a)
#define IDirect3DDevice9_SetCursorProperties(p,a,b,c)                  (p)->SetCursorProperties(a,b,c)
#define IDirect3DDevice9_SetCursorPosition(p,a,b,c)                    (p)->SetCursorPosition(a,b,c)
#define IDirect3DDevice9_ShowCursor(p,a)                               (p)->ShowCursor(a)
#define IDirect3DDevice9_CreateAdditionalSwapChain(p,a,b)              (p)->CreateAdditionalSwapChain(a,b)
#define IDirect3DDevice9_GetSwapChain(p,a,b)                           (p)->GetSwapChain(a,b)
#define IDirect3DDevice9_GetNumberOfSwapChains(p)                      (p)->GetNumberOfSwapChains()
#define IDirect3DDevice9_Reset(p,a)                                    (p)->Reset(a)
#define IDirect3DDevice9_Present(p,a,b,c,d)                            (p)->Present(a,b,c,d)
#define IDirect3DDevice9_GetBackBuffer(p,a,b,c,d)                      (p)->GetBackBuffer(a,b,c,d)
#define IDirect3DDevice9_GetRasterStatus(p,a,b)                        (p)->GetRasterStatus(a,b)
#define IDirect3DDevice9_SetDialogBoxMode(p,a)                         (p)->SetDialogBoxMode(a)
#define IDirect3DDevice9_SetGammaRamp(p,a,b,c)                         (p)->SetGammaRamp(a,b,c)
#define IDirect3DDevice9_GetGammaRamp(p,a,b)                           (p)->GetGammaRamp(a,b)
#define IDirect3DDevice9_CreateTexture(p,a,b,c,d,e,f,g,h)              (p)->CreateTexture(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9_CreateVolumeTexture(p,a,b,c,d,e,f,g,h,i)      (p)->CreateVolumeTexture(a,b,c,d,e,f,g,h,i)
#define IDirect3DDevice9_CreateCubeTexture(p,a,b,c,d,e,f,g)            (p)->CreateCubeTexture(a,b,c,d,e,f,g)
#define IDirect3DDevice9_CreateVertexBuffer(p,a,b,c,d,e,f)             (p)->CreateVertexBuffer(a,b,c,d,e,f)
#define IDirect3DDevice9_CreateIndexBuffer(p,a,b,c,d,e,f)              (p)->CreateIndexBuffer(a,b,c,d,e,f)
#define IDirect3DDevice9_CreateRenderTarget(p,a,b,c,d,e,f,g,h)         (p)->CreateRenderTarget(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9_CreateDepthStencilSurface(p,a,b,c,d,e,f,g,h)  (p)->CreateDepthStencilSurface(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9_UpdateSurface(p,a,b,c,d)                      (p)->UpdateSurface(a,b,c,d)
#define IDirect3DDevice9_UpdateTexture(p,a,b)                          (p)->UpdateTexture(a,b)
#define IDirect3DDevice9_GetRenderTargetData(p,a,b)                    (p)->GetRenderTargetData(a,b)
#define IDirect3DDevice9_GetFrontBufferData(p,a,b)                     (p)->GetFrontBufferData(a,b)
#define IDirect3DDevice9_StretchRect(p,a,b,c,d,e)                      (p)->StretchRect(a,b,c,d,e)
#define IDirect3DDevice9_ColorFill(p,a,b,c)                            (p)->ColorFill(a,b,c)
#define IDirect3DDevice9_CreateOffscreenPlainSurface(p,a,b,c,d,e,f)    (p)->CreateOffscreenPlainSurface(a,b,c,d,e,f)
#define IDirect3DDevice9_SetRenderTarget(p,a,b)                        (p)->SetRenderTarget(a,b)
#define IDirect3DDevice9_GetRenderTarget(p,a,b)                        (p)->GetRenderTarget(a,b)
#define IDirect3DDevice9_SetDepthStencilSurface(p,a)                   (p)->SetDepthStencilSurface(a)
#define IDirect3DDevice9_GetDepthStencilSurface(p,a)                   (p)->GetDepthStencilSurface(a)
#define IDirect3DDevice9_BeginScene(p)                                 (p)->BeginScene()
#define IDirect3DDevice9_EndScene(p)                                   (p)->EndScene()
#define IDirect3DDevice9_Clear(p,a,b,c,d,e,f)                          (p)->Clear(a,b,c,d,e,f)
#define IDirect3DDevice9_SetTransform(p,a,b)                           (p)->SetTransform(a,b)
#define IDirect3DDevice9_GetTransform(p,a,b)                           (p)->GetTransform(a,b)
#define IDirect3DDevice9_MultiplyTransform(p,a,b)                      (p)->MultiplyTransform(a,b)
#define IDirect3DDevice9_SetViewport(p,a)                              (p)->SetViewport(a)
#define IDirect3DDevice9_GetViewport(p,a)                              (p)->GetViewport(a)
#define IDirect3DDevice9_SetMaterial(p,a)                              (p)->SetMaterial(a)
#define IDirect3DDevice9_GetMaterial(p,a)                              (p)->GetMaterial(a)
#define IDirect3DDevice9_SetLight(p,a,b)                               (p)->SetLight(a,b)
#define IDirect3DDevice9_GetLight(p,a,b)                               (p)->GetLight(a,b)
#define IDirect3DDevice9_LightEnable(p,a,b)                            (p)->LightEnable(a,b)
#define IDirect3DDevice9_GetLightEnable(p,a,b)                         (p)->GetLightEnable(a,b)
#define IDirect3DDevice9_SetClipPlane(p,a,b)                           (p)->SetClipPlane(a,b)
#define IDirect3DDevice9_GetClipPlane(p,a,b)                           (p)->GetClipPlane(a,b)
#define IDirect3DDevice9_SetRenderState(p,a,b)                         (p)->SetRenderState(a,b)
#define IDirect3DDevice9_GetRenderState(p,a,b)                         (p)->GetRenderState(a,b)
#define IDirect3DDevice9_CreateStateBlock(p,a,b)                       (p)->CreateStateBlock(a,b)
#define IDirect3DDevice9_BeginStateBlock(p)                            (p)->BeginStateBlock()
#define IDirect3DDevice9_EndStateBlock(p,a)                            (p)->EndStateBlock(a)
#define IDirect3DDevice9_SetClipStatus(p,a)                            (p)->SetClipStatus(a)
#define IDirect3DDevice9_GetClipStatus(p,a)                            (p)->GetClipStatus(a)
#define IDirect3DDevice9_GetTexture(p,a,b)                             (p)->GetTexture(a,b)
#define IDirect3DDevice9_SetTexture(p,a,b)                             (p)->SetTexture(a,b)
#define IDirect3DDevice9_GetTextureStageState(p,a,b,c)                 (p)->GetTextureStageState(a,b,c)
#define IDirect3DDevice9_SetTextureStageState(p,a,b,c)                 (p)->SetTextureStageState(a,b,c)
#define IDirect3DDevice9_GetSamplerState(p,a,b,c)                      (p)->GetSamplerState(a,b,c)
#define IDirect3DDevice9_SetSamplerState(p,a,b,c)                      (p)->SetSamplerState(a,b,c)
#define IDirect3DDevice9_ValidateDevice(p,a)                           (p)->ValidateDevice(a)
#define IDirect3DDevice9_SetPaletteEntries(p,a,b)                      (p)->SetPaletteEntries(a,b)
#define IDirect3DDevice9_GetPaletteEntries(p,a,b)                      (p)->GetPaletteEntries(a,b)
#define IDirect3DDevice9_SetCurrentTexturePalette(p,a)                 (p)->SetCurrentTexturePalette(a)
#define IDirect3DDevice9_GetCurrentTexturePalette(p,a)                 (p)->GetCurrentTexturePalette(a)
#define IDirect3DDevice9_SetScissorRect(p,a)                           (p)->SetScissorRect(a)
#define IDirect3DDevice9_GetScissorRect(p,a)                           (p)->GetScissorRect(a)
#define IDirect3DDevice9_SetSoftwareVertexProcessing(p,a)              (p)->SetSoftwareVertexProcessing(a)
#define IDirect3DDevice9_GetSoftwareVertexProcessing(p)                (p)->GetSoftwareVertexProcessing()
#define IDirect3DDevice9_SetNPatchMode(p,a)                            (p)->SetNPatchMode(a)
#define IDirect3DDevice9_GetNPatchMode(p)                              (p)->GetNPatchMode()
#define IDirect3DDevice9_DrawPrimitive(p,a,b,c)                        (p)->DrawPrimitive(a,b,c)
#define IDirect3DDevice9_DrawIndexedPrimitive(p,a,b,c,d,e,f)           (p)->DrawIndexedPrimitive(a,b,c,d,e,f)
#define IDirect3DDevice9_DrawPrimitiveUP(p,a,b,c,d)                    (p)->DrawPrimitiveUP(a,b,c,d)
#define IDirect3DDevice9_DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h)     (p)->DrawIndexedPrimitiveUP(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9_ProcessVertices(p,a,b,c,d,e,f)                (p)->ProcessVertices(a,b,c,d,e,f)
#define IDirect3DDevice9_CreateVertexDeclaration(p,a,b)                (p)->CreateVertexDeclaration(a,b)
#define IDirect3DDevice9_SetVertexDeclaration(p,a)                     (p)->SetVertexDeclaration(a)
#define IDirect3DDevice9_GetVertexDeclaration(p,a)                     (p)->GetVertexDeclaration(a)
#define IDirect3DDevice9_SetFVF(p,a)                                   (p)->SetFVF(a)
#define IDirect3DDevice9_GetFVF(p,a)                                   (p)->GetFVF(a)
#define IDirect3DDevice9_CreateVertexShader(p,a,b)                     (p)->CreateVertexShader(a,b)
#define IDirect3DDevice9_SetVertexShader(p,a)                          (p)->SetVertexShader(a)
#define IDirect3DDevice9_GetVertexShader(p,a)                          (p)->GetVertexShader(a)
#define IDirect3DDevice9_SetVertexShaderConstantF(p,a,b,c)             (p)->SetVertexShaderConstantF(a,b,c)
#define IDirect3DDevice9_GetVertexShaderConstantF(p,a,b,c)             (p)->GetVertexShaderConstantF(a,b,c)
#define IDirect3DDevice9_SetVertexShaderConstantI(p,a,b,c)             (p)->SetVertexShaderConstantI(a,b,c)
#define IDirect3DDevice9_GetVertexShaderConstantI(p,a,b,c)             (p)->GetVertexShaderConstantI(a,b,c)
#define IDirect3DDevice9_SetVertexShaderConstantB(p,a,b,c)             (p)->SetVertexShaderConstantB(a,b,c)
#define IDirect3DDevice9_GetVertexShaderConstantB(p,a,b,c)             (p)->GetVertexShaderConstantB(a,b,c)
#define IDirect3DDevice9_SetStreamSource(p,a,b,c,d)                    (p)->SetStreamSource(a,b,c,d)
#define IDirect3DDevice9_GetStreamSource(p,a,b,c,d)                    (p)->GetStreamSource(a,b,c,d)
#define IDirect3DDevice9_SetStreamSourceFreq(p,a,b)                    (p)->SetStreamSourceFreq(a,b)
#define IDirect3DDevice9_GetStreamSourceFreq(p,a,b)                    (p)->GetStreamSourceFreq(a,b)
#define IDirect3DDevice9_SetIndices(p,a)                               (p)->SetIndices(a)
#define IDirect3DDevice9_GetIndices(p,a)                               (p)->GetIndices(a)
#define IDirect3DDevice9_CreatePixelShader(p,a,b)                      (p)->CreatePixelShader(a,b)
#define IDirect3DDevice9_SetPixelShader(p,a)                           (p)->SetPixelShader(a)
#define IDirect3DDevice9_GetPixelShader(p,a)                           (p)->GetPixelShader(a)
#define IDirect3DDevice9_SetPixelShaderConstantF(p,a,b,c)              (p)->SetPixelShaderConstantF(a,b,c)
#define IDirect3DDevice9_GetPixelShaderConstantF(p,a,b,c)              (p)->GetPixelShaderConstantF(a,b,c)
#define IDirect3DDevice9_SetPixelShaderConstantI(p,a,b,c)              (p)->SetPixelShaderConstantI(a,b,c)
#define IDirect3DDevice9_GetPixelShaderConstantI(p,a,b,c)              (p)->GetPixelShaderConstantI(a,b,c)
#define IDirect3DDevice9_SetPixelShaderConstantB(p,a,b,c)              (p)->SetPixelShaderConstantB(a,b,c)
#define IDirect3DDevice9_GetPixelShaderConstantB(p,a,b,c)              (p)->GetPixelShaderConstantB(a,b,c)
#define IDirect3DDevice9_DrawRectPatch(p,a,b,c)                        (p)->DrawRectPatch(a,b,c)
#define IDirect3DDevice9_DrawTriPatch(p,a,b,c)                         (p)->DrawTriPatch(a,b,c)
#define IDirect3DDevice9_DeletePatch(p,a)                              (p)->DeletePatch(a)
#define IDirect3DDevice9_CreateQuery(p,a,b)                            (p)->CreateQuery(a,b)
#endif


#if !defined(D3D_DISABLE_9EX)

typedef struct IDirect3D9Ex *LPDIRECT3D9EX, *PDIRECT3D9EX;
typedef struct IDirect3DSwapChain9Ex *LPDIRECT3DSWAPCHAIN9EX, *PDIRECT3DSWAPCHAIN9EX;
typedef struct IDirect3DDevice9Ex *LPDIRECT3DDEVICE9EX, *PDIRECT3DDEVICE9EX;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3D9Ex, 0x02177241, 0x69fc, 0x400c, 0x8f, 0xf1, 0x93, 0xa4, 0x4d, 0xf6, 0x86, 0x1d);
#endif
DEFINE_GUID(IID_IDirect3D9Ex, 0x02177241, 0x69fc, 0x400c, 0x8f, 0xf1, 0x93, 0xa4, 0x4d, 0xf6, 0x86, 0x1d);

#define INTERFACE IDirect3D9Ex
DECLARE_INTERFACE_IID_(IDirect3D9Ex,IDirect3D9,"02177241-69fc-400c-8ff1-93a44df6861d")
{
    /* IUnknown */
    STDMETHOD_(HRESULT, QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* IDirect3D9 */
    STDMETHOD(RegisterSoftwareDevice)(THIS_ void *init) PURE;
    STDMETHOD_(UINT, GetAdapterCount)(THIS) PURE;
    STDMETHOD(GetAdapterIdentifier)(THIS_ UINT adapter_idx, DWORD flags, D3DADAPTER_IDENTIFIER9 *identifier) PURE;
    STDMETHOD_(UINT, GetAdapterModeCount)(THIS_ UINT adapter_idx, D3DFORMAT format) PURE;
    STDMETHOD(EnumAdapterModes)(THIS_ UINT adapter_idx, D3DFORMAT format, UINT mode_idx, D3DDISPLAYMODE *mode) PURE;
    STDMETHOD(GetAdapterDisplayMode)(THIS_ UINT adapter_idx, D3DDISPLAYMODE *mode) PURE;
    STDMETHOD(CheckDeviceType)(THIS_ UINT adapter_idx, D3DDEVTYPE device_type,
            D3DFORMAT display_format, D3DFORMAT backbuffer_format, WINBOOL windowed) PURE;
    STDMETHOD(CheckDeviceFormat)(THIS_ UINT adapter_idx, D3DDEVTYPE device_type, D3DFORMAT adapter_format,
            DWORD usage, D3DRESOURCETYPE resource_type, D3DFORMAT format) PURE;
    STDMETHOD(CheckDeviceMultiSampleType)(THIS_ UINT adapter_idx, D3DDEVTYPE device_type, D3DFORMAT surface_format,
            WINBOOL windowed, D3DMULTISAMPLE_TYPE multisample_type, DWORD *quality_levels) PURE;
    STDMETHOD(CheckDepthStencilMatch)(THIS_ UINT adapter_idx, D3DDEVTYPE device_type,
            D3DFORMAT adapter_format, D3DFORMAT rt_format, D3DFORMAT ds_format) PURE;
    STDMETHOD(CheckDeviceFormatConversion)(THIS_ UINT adapter_idx, D3DDEVTYPE device_type,
            D3DFORMAT src_format, D3DFORMAT dst_format) PURE;
    STDMETHOD(GetDeviceCaps)(THIS_ UINT adapter_idx, D3DDEVTYPE device_type, D3DCAPS9 *caps) PURE;
    STDMETHOD_(HMONITOR, GetAdapterMonitor)(THIS_ UINT adapter_idx) PURE;
    STDMETHOD(CreateDevice)(THIS_ UINT adapter_idx, D3DDEVTYPE device_type, HWND focus_window, DWORD flags,
            D3DPRESENT_PARAMETERS *parameters, struct IDirect3DDevice9 **device) PURE;
    /* IDirect3D9Ex */
    STDMETHOD_(UINT, GetAdapterModeCountEx)(THIS_ UINT adapter_idx, const D3DDISPLAYMODEFILTER *filter) PURE;
    STDMETHOD(EnumAdapterModesEx)(THIS_ UINT adapter_idx, const D3DDISPLAYMODEFILTER *filter,
            UINT mode_idx, D3DDISPLAYMODEEX *mode) PURE;
    STDMETHOD(GetAdapterDisplayModeEx)(THIS_ UINT adapter_idx,
            D3DDISPLAYMODEEX *mode, D3DDISPLAYROTATION *rotation) PURE;
    STDMETHOD(CreateDeviceEx)(THIS_ UINT adapter_idx, D3DDEVTYPE device_type, HWND focus_window, DWORD flags,
            D3DPRESENT_PARAMETERS *parameters, D3DDISPLAYMODEEX *mode, struct IDirect3DDevice9Ex **device) PURE;
    STDMETHOD(GetAdapterLUID)(THIS_ UINT adapter_idx, LUID *luid) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/* IUnknown */
#define IDirect3D9Ex_QueryInterface(p,a,b)                      (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3D9Ex_AddRef(p)                                  (p)->lpVtbl->AddRef(p)
#define IDirect3D9Ex_Release(p)                                 (p)->lpVtbl->Release(p)
/* IDirect3D9 */
#define IDirect3D9Ex_RegisterSoftwareDevice(p,a)                (p)->lpVtbl->RegisterSoftwareDevice(p,a)
#define IDirect3D9Ex_GetAdapterCount(p)                         (p)->lpVtbl->GetAdapterCount(p)
#define IDirect3D9Ex_GetAdapterIdentifier(p,a,b,c)              (p)->lpVtbl->GetAdapterIdentifier(p,a,b,c)
#define IDirect3D9Ex_GetAdapterModeCount(p,a,b)                 (p)->lpVtbl->GetAdapterModeCount(p,a,b)
#define IDirect3D9Ex_EnumAdapterModes(p,a,b,c,d)                (p)->lpVtbl->EnumAdapterModes(p,a,b,c,d)
#define IDirect3D9Ex_GetAdapterDisplayMode(p,a,b)               (p)->lpVtbl->GetAdapterDisplayMode(p,a,b)
#define IDirect3D9Ex_CheckDeviceType(p,a,b,c,d,e)               (p)->lpVtbl->CheckDeviceType(p,a,b,c,d,e)
#define IDirect3D9Ex_CheckDeviceFormat(p,a,b,c,d,e,f)           (p)->lpVtbl->CheckDeviceFormat(p,a,b,c,d,e,f)
#define IDirect3D9Ex_CheckDeviceMultiSampleType(p,a,b,c,d,e,f)  (p)->lpVtbl->CheckDeviceMultiSampleType(p,a,b,c,d,e,f)
#define IDirect3D9Ex_CheckDepthStencilMatch(p,a,b,c,d,e)        (p)->lpVtbl->CheckDepthStencilMatch(p,a,b,c,d,e)
#define IDirect3D9Ex_CheckDeviceFormatConversion(p,a,b,c,d)     (p)->lpVtbl->CheckDeviceFormatConversion(p,a,b,c,d)
#define IDirect3D9Ex_GetDeviceCaps(p,a,b,c)                     (p)->lpVtbl->GetDeviceCaps(p,a,b,c)
#define IDirect3D9Ex_GetAdapterMonitor(p,a)                     (p)->lpVtbl->GetAdapterMonitor(p,a)
#define IDirect3D9Ex_CreateDevice(p,a,b,c,d,e,f)                (p)->lpVtbl->CreateDevice(p,a,b,c,d,e,f)
/* IDirect3D9Ex */
#define IDirect3D9Ex_GetAdapterModeCountEx(p,a,b)               (p)->lpVtbl->GetAdapterModeCountEx(p,a,b)
#define IDirect3D9Ex_EnumAdapterModesEx(p,a,b,c,d)              (p)->lpVtbl->EnumAdapterModesEx(p,a,b,c,d)
#define IDirect3D9Ex_GetAdapterDisplayModeEx(p,a,b,c)           (p)->lpVtbl->GetAdapterDisplayModeEx(p,a,b,c)
#define IDirect3D9Ex_CreateDeviceEx(p,a,b,c,d,e,f,g)            (p)->lpVtbl->CreateDeviceEx(p,a,b,c,d,e,f,g)
#define IDirect3D9Ex_GetAdapterLUID(p,a,b)                      (p)->lpVtbl->GetAdapterLUID(p,a,b)
#else
/* IUnknown */
#define IDirect3D9Ex_QueryInterface(p,a,b)                      (p)->QueryInterface(a,b)
#define IDirect3D9Ex_AddRef(p)                                  (p)->AddRef()
#define IDirect3D9Ex_Release(p)                                 (p)->Release()
/* IDirect3D9 */
#define IDirect3D9Ex_RegisterSoftwareDevice(p,a)                (p)->RegisterSoftwareDevice(a)
#define IDirect3D9Ex_GetAdapterCount(p)                         (p)->GetAdapterCount()
#define IDirect3D9Ex_GetAdapterIdentifier(p,a,b,c)              (p)->GetAdapterIdentifier(a,b,c)
#define IDirect3D9Ex_GetAdapterModeCount(p,a,b)                 (p)->GetAdapterModeCount(a,b)
#define IDirect3D9Ex_EnumAdapterModes(p,a,b,c,d)                (p)->EnumAdapterModes(a,b,c,d)
#define IDirect3D9Ex_GetAdapterDisplayMode(p,a,b)               (p)->GetAdapterDisplayMode(a,b)
#define IDirect3D9Ex_CheckDeviceType(p,a,b,c,d,e)               (p)->CheckDeviceType(a,b,c,d,e)
#define IDirect3D9Ex_CheckDeviceFormat(p,a,b,c,d,e,f)           (p)->CheckDeviceFormat(a,b,c,d,e,f)
#define IDirect3D9Ex_CheckDeviceMultiSampleType(p,a,b,c,d,e,f)  (p)->CheckDeviceMultiSampleType(a,b,c,d,e,f)
#define IDirect3D9Ex_CheckDepthStencilMatch(p,a,b,c,d,e)        (p)->CheckDepthStencilMatch(a,b,c,d,e)
#define IDirect3D9Ex_CheckDeviceFormatConversion(p,a,b,c,d)     (p)->CheckDeviceFormatConversion(a,b,c,d)
#define IDirect3D9Ex_GetDeviceCaps(p,a,b,c)                     (p)->GetDeviceCaps(a,b,c)
#define IDirect3D9Ex_GetAdapterMonitor(p,a)                     (p)->GetAdapterMonitor(a)
#define IDirect3D9Ex_CreateDevice(p,a,b,c,d,e,f)                (p)->CreateDevice(a,b,c,d,e,f)
/* IDirect3D9Ex */
#define IDirect3D9Ex_GetAdapterModeCountEx(p,a,b)               (p)->GetAdapterModeCountEx(a,b)
#define IDirect3D9Ex_EnumAdapterModesEx(p,a,b,c,d)              (p)->EnumAdapterModesEx(a,b,c,d)
#define IDirect3D9Ex_GetAdapterDisplayModeEx(p,a,b,c)           (p)->GetAdapterDisplayModeEx(a,b,c)
#define IDirect3D9Ex_CreateDeviceEx(p,a,b,c,d,e,f,g)            (p)->CreateDeviceEx(a,b,c,d,e,f,g)
#define IDirect3D9Ex_GetAdapterLUID(p,a,b)                      (p)->GetAdapterLUID(a,b)
#endif

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DSwapChain9Ex, 0x91886caf, 0x1c3d, 0x4d2e, 0xa0, 0xab, 0x3e, 0x4c, 0x7d, 0x8d, 0x33, 0x3);
#endif
DEFINE_GUID(IID_IDirect3DSwapChain9Ex, 0x91886caf, 0x1c3d, 0x4d2e, 0xa0, 0xab, 0x3e, 0x4c, 0x7d, 0x8d, 0x33, 0x3);

#define INTERFACE IDirect3DSwapChain9Ex
DECLARE_INTERFACE_IID_(IDirect3DSwapChain9Ex,IDirect3DSwapChain9,"91886caf-1c3d-4d2e-a0ab-3e4c7d8d3303")
{
    /* IUnknown */
    STDMETHOD_(HRESULT, QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* IDirect3DSwapChain9 */
    STDMETHOD(Present)(THIS_ const RECT *src_rect, const RECT *dst_rect, HWND dst_window_override,
            const RGNDATA *dirty_region, DWORD flags) PURE;
    STDMETHOD(GetFrontBufferData)(THIS_ struct IDirect3DSurface9 *dst_surface) PURE;
    STDMETHOD(GetBackBuffer)(THIS_ UINT backbuffer_idx, D3DBACKBUFFER_TYPE backbuffer_type,
            struct IDirect3DSurface9 **backbuffer) PURE;
    STDMETHOD(GetRasterStatus)(THIS_ D3DRASTER_STATUS *raster_status) PURE;
    STDMETHOD(GetDisplayMode)(THIS_ D3DDISPLAYMODE *mode) PURE;
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(GetPresentParameters)(THIS_ D3DPRESENT_PARAMETERS *parameters) PURE;
    /* IDirect3DSwapChain9Ex */
    STDMETHOD(GetLastPresentCount)(THIS_ UINT *last_present_count) PURE;
    STDMETHOD(GetPresentStats)(THIS_ D3DPRESENTSTATS *stats) PURE;
    STDMETHOD(GetDisplayModeEx)(THIS_ D3DDISPLAYMODEEX *mode, D3DDISPLAYROTATION *rotation) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/* IUnknown */
#define IDirect3DSwapChain9Ex_QueryInterface(p,a,b)             (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DSwapChain9Ex_AddRef(p)                         (p)->lpVtbl->AddRef(p)
#define IDirect3DSwapChain9Ex_Release(p)                        (p)->lpVtbl->Release(p)
/* IDirect3DSwapChain9 */
#define IDirect3DSwapChain9Ex_Present(p,a,b,c,d,e)              (p)->lpVtbl->Present(p,a,b,c,d,e)
#define IDirect3DSwapChain9Ex_GetFrontBufferData(p,a)           (p)->lpVtbl->GetFrontBufferData(p,a)
#define IDirect3DSwapChain9Ex_GetBackBuffer(p,a,b,c)            (p)->lpVtbl->GetBackBuffer(p,a,b,c)
#define IDirect3DSwapChain9Ex_GetRasterStatus(p,a)              (p)->lpVtbl->GetRasterStatus(p,a)
#define IDirect3DSwapChain9Ex_GetDisplayMode(p,a)               (p)->lpVtbl->GetDisplayMode(p,a)
#define IDirect3DSwapChain9Ex_GetDevice(p,a)                    (p)->lpVtbl->GetDevice(p,a)
#define IDirect3DSwapChain9Ex_GetPresentParameters(p,a)         (p)->lpVtbl->GetPresentParameters(p,a)
/* IDirect3DSwapChain9Ex */
#define IDirect3DSwapChain9Ex_GetLastPresentCount(p,a)          (p)->lpVtbl->GetLastPresentCount(p,a)
#define IDirect3DSwapChain9Ex_GetPresentStats(p,a)              (p)->lpVtbl->GetPresentStats(p,a)
#define IDirect3DSwapChain9Ex_GetDisplayModeEx(p,a,b)           (p)->lpVtbl->GetDisplayModeEx(p,a,b)
#else
/* IUnknown */
#define IDirect3DSwapChain9Ex_QueryInterface(p,a,b)             (p)->QueryInterface(a,b)
#define IDirect3DSwapChain9Ex_AddRef(p)                         (p)->AddRef()
#define IDirect3DSwapChain9Ex_Release(p)                        (p)->Release()
/* IDirect3DSwapChain9 */
#define IDirect3DSwapChain9Ex_Present(p,a,b,c,d,e)              (p)->Present(a,b,c,d,e)
#define IDirect3DSwapChain9Ex_GetFrontBufferData(p,a)           (p)->GetFrontBufferData(a)
#define IDirect3DSwapChain9Ex_GetBackBuffer(p,a,b,c)            (p)->GetBackBuffer(a,b,c)
#define IDirect3DSwapChain9Ex_GetRasterStatus(p,a)              (p)->GetRasterStatus(a)
#define IDirect3DSwapChain9Ex_GetDisplayMode(p,a)               (p)->GetDisplayMode(a)
#define IDirect3DSwapChain9Ex_GetDevice(p,a)                    (p)->GetDevice(a)
#define IDirect3DSwapChain9Ex_GetPresentParameters(p,a)         (p)->GetPresentParameters(a)
/* IDirect3DSwapChain9Ex */
#define IDirect3DSwapChain9Ex_GetLastPresentCount(p,a)          (p)->GetLastPresentCount(a)
#define IDirect3DSwapChain9Ex_GetPresentStats(p,a)              (p)->GetPresentStats(a)
#define IDirect3DSwapChain9Ex_GetDisplayModeEx(p,a,b)           (p)->GetDisplayModeEx(a,b)
#endif

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDirect3DDevice9Ex, 0xb18b10ce, 0x2649, 0x405a, 0x87, 0xf, 0x95, 0xf7, 0x77, 0xd4, 0x31, 0x3a);
#endif
DEFINE_GUID(IID_IDirect3DDevice9Ex, 0xb18b10ce, 0x2649, 0x405a, 0x87, 0xf, 0x95, 0xf7, 0x77, 0xd4, 0x31, 0x3a);

#define INTERFACE IDirect3DDevice9Ex
DECLARE_INTERFACE_IID_(IDirect3DDevice9Ex,IDirect3DDevice9,"b18b10ce-2649-405a-870f-95f777d4313a")
{
    /* IUnknown */
    STDMETHOD_(HRESULT, QueryInterface)(THIS_ REFIID iid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /* IDirect3DDevice9 */
    STDMETHOD(TestCooperativeLevel)(THIS) PURE;
    STDMETHOD_(UINT, GetAvailableTextureMem)(THIS) PURE;
    STDMETHOD(EvictManagedResources)(THIS) PURE;
    STDMETHOD(GetDirect3D)(THIS_ IDirect3D9 **d3d9) PURE;
    STDMETHOD(GetDeviceCaps)(THIS_ D3DCAPS9 *caps) PURE;
    STDMETHOD(GetDisplayMode)(THIS_ UINT swapchain_idx, D3DDISPLAYMODE *mode) PURE;
    STDMETHOD(GetCreationParameters)(THIS_ D3DDEVICE_CREATION_PARAMETERS *parameters) PURE;
    STDMETHOD(SetCursorProperties)(THIS_ UINT hotspot_x, UINT hotspot_y, IDirect3DSurface9 *bitmap) PURE;
    STDMETHOD_(void, SetCursorPosition)(THIS_ int x, int y, DWORD flags) PURE;
    STDMETHOD_(WINBOOL, ShowCursor)(THIS_ WINBOOL show) PURE;
    STDMETHOD(CreateAdditionalSwapChain)(THIS_ D3DPRESENT_PARAMETERS *parameters,
            IDirect3DSwapChain9 **swapchain) PURE;
    STDMETHOD(GetSwapChain)(THIS_ UINT swapchain_idx, IDirect3DSwapChain9 **swapchain) PURE;
    STDMETHOD_(UINT, GetNumberOfSwapChains)(THIS) PURE;
    STDMETHOD(Reset)(THIS_ D3DPRESENT_PARAMETERS *parameters) PURE;
    STDMETHOD(Present)(THIS_ const RECT *src_rect, const RECT *dst_rect,
            HWND dst_window_override, const RGNDATA *dirty_region) PURE;
    STDMETHOD(GetBackBuffer)(THIS_ UINT swapchain_idx, UINT backbuffer_idx,
            D3DBACKBUFFER_TYPE backbuffer_type, IDirect3DSurface9 **backbuffer) PURE;
    STDMETHOD(GetRasterStatus)(THIS_ UINT swapchain_idx, D3DRASTER_STATUS *raster_status) PURE;
    STDMETHOD(SetDialogBoxMode)(THIS_ WINBOOL enable) PURE;
    STDMETHOD_(void, SetGammaRamp)(THIS_ UINT swapchain_idx, DWORD flags, const D3DGAMMARAMP *ramp) PURE;
    STDMETHOD_(void, GetGammaRamp)(THIS_ UINT swapchain_idx, D3DGAMMARAMP *ramp) PURE;
    STDMETHOD(CreateTexture)(THIS_ UINT width, UINT height, UINT levels, DWORD usage,
            D3DFORMAT format, D3DPOOL pool, IDirect3DTexture9 **texture, HANDLE *shared_handle) PURE;
    STDMETHOD(CreateVolumeTexture)(THIS_ UINT width, UINT height, UINT depth, UINT levels, DWORD usage,
            D3DFORMAT format, D3DPOOL pool, IDirect3DVolumeTexture9 **texture, HANDLE *shared_handle) PURE;
    STDMETHOD(CreateCubeTexture)(THIS_ UINT edge_length, UINT levels, DWORD usage,
            D3DFORMAT format, D3DPOOL pool, IDirect3DCubeTexture9 **texture, HANDLE *shared_handle) PURE;
    STDMETHOD(CreateVertexBuffer)(THIS_ UINT size, DWORD usage, DWORD fvf, D3DPOOL pool,
            IDirect3DVertexBuffer9 **buffer, HANDLE *shared_handle) PURE;
    STDMETHOD(CreateIndexBuffer)(THIS_ UINT size, DWORD usage, D3DFORMAT format, D3DPOOL pool,
            IDirect3DIndexBuffer9 **buffer, HANDLE *shared_handle) PURE;
    STDMETHOD(CreateRenderTarget)(THIS_ UINT width, UINT height, D3DFORMAT format,
            D3DMULTISAMPLE_TYPE multisample_type, DWORD multisample_quality, WINBOOL lockable,
            IDirect3DSurface9 **surface, HANDLE *shared_handle) PURE;
    STDMETHOD(CreateDepthStencilSurface)(THIS_ UINT width, UINT height, D3DFORMAT format,
            D3DMULTISAMPLE_TYPE multisample_type, DWORD multisample_quality, WINBOOL discard,
            IDirect3DSurface9 **surface, HANDLE *shared_handle) PURE;
    STDMETHOD(UpdateSurface)(THIS_ IDirect3DSurface9 *src_surface, const RECT *src_rect,
            IDirect3DSurface9 *dst_surface, const POINT *dst_point) PURE;
    STDMETHOD(UpdateTexture)(THIS_ IDirect3DBaseTexture9 *src_texture, IDirect3DBaseTexture9 *dst_texture) PURE;
    STDMETHOD(GetRenderTargetData)(THIS_ IDirect3DSurface9 *render_target, IDirect3DSurface9 *dst_surface) PURE;
    STDMETHOD(GetFrontBufferData)(THIS_ UINT swapchain_idx, IDirect3DSurface9 *dst_surface) PURE;
    STDMETHOD(StretchRect)(THIS_ IDirect3DSurface9 *src_surface, const RECT *src_rect,
            IDirect3DSurface9 *dst_surface, const RECT *dst_rect, D3DTEXTUREFILTERTYPE filter) PURE;
    STDMETHOD(ColorFill)(THIS_ IDirect3DSurface9 *surface, const RECT *rect, D3DCOLOR colour) PURE;
    STDMETHOD(CreateOffscreenPlainSurface)(THIS_ UINT width, UINT height, D3DFORMAT format, D3DPOOL pool,
            IDirect3DSurface9 **surface, HANDLE *shared_handle) PURE;
    STDMETHOD(SetRenderTarget)(THIS_ DWORD idx, IDirect3DSurface9 *surface) PURE;
    STDMETHOD(GetRenderTarget)(THIS_ DWORD idx, IDirect3DSurface9 **surface) PURE;
    STDMETHOD(SetDepthStencilSurface)(THIS_ IDirect3DSurface9 *depth_stencil) PURE;
    STDMETHOD(GetDepthStencilSurface)(THIS_ IDirect3DSurface9 **depth_stencil) PURE;
    STDMETHOD(BeginScene)(THIS) PURE;
    STDMETHOD(EndScene)(THIS) PURE;
    STDMETHOD(Clear)(THIS_ DWORD rect_count, const D3DRECT *rects, DWORD flags,
            D3DCOLOR colour, float z, DWORD stencil) PURE;
    STDMETHOD(SetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, const D3DMATRIX *matrix) PURE;
    STDMETHOD(GetTransform)(THIS_ D3DTRANSFORMSTATETYPE State, D3DMATRIX *matrix) PURE;
    STDMETHOD(MultiplyTransform)(THIS_ D3DTRANSFORMSTATETYPE state, const D3DMATRIX *matrix) PURE;
    STDMETHOD(SetViewport)(THIS_ const D3DVIEWPORT9 *viewport) PURE;
    STDMETHOD(GetViewport)(THIS_ D3DVIEWPORT9 *viewport) PURE;
    STDMETHOD(SetMaterial)(THIS_ const D3DMATERIAL9 *material) PURE;
    STDMETHOD(GetMaterial)(THIS_ D3DMATERIAL9 *material) PURE;
    STDMETHOD(SetLight)(THIS_ DWORD idx, const D3DLIGHT9 *light) PURE;
    STDMETHOD(GetLight)(THIS_ DWORD idx, D3DLIGHT9 *light) PURE;
    STDMETHOD(LightEnable)(THIS_ DWORD idx, WINBOOL enable) PURE;
    STDMETHOD(GetLightEnable)(THIS_ DWORD idx, WINBOOL *enable) PURE;
    STDMETHOD(SetClipPlane)(THIS_ DWORD idx, const float *plane) PURE;
    STDMETHOD(GetClipPlane)(THIS_ DWORD idx, float *plane) PURE;
    STDMETHOD(SetRenderState)(THIS_ D3DRENDERSTATETYPE state, DWORD value) PURE;
    STDMETHOD(GetRenderState)(THIS_ D3DRENDERSTATETYPE state, DWORD *value) PURE;
    STDMETHOD(CreateStateBlock)(THIS_ D3DSTATEBLOCKTYPE type, IDirect3DStateBlock9 **stateblock) PURE;
    STDMETHOD(BeginStateBlock)(THIS) PURE;
    STDMETHOD(EndStateBlock)(THIS_ IDirect3DStateBlock9 **stateblock) PURE;
    STDMETHOD(SetClipStatus)(THIS_ const D3DCLIPSTATUS9 *clip_status) PURE;
    STDMETHOD(GetClipStatus)(THIS_ D3DCLIPSTATUS9 *clip_status) PURE;
    STDMETHOD(GetTexture)(THIS_ DWORD stage, IDirect3DBaseTexture9 **texture) PURE;
    STDMETHOD(SetTexture)(THIS_ DWORD stage, IDirect3DBaseTexture9 *texture) PURE;
    STDMETHOD(GetTextureStageState)(THIS_ DWORD stage, D3DTEXTURESTAGESTATETYPE state, DWORD *value) PURE;
    STDMETHOD(SetTextureStageState)(THIS_ DWORD stage, D3DTEXTURESTAGESTATETYPE state, DWORD value) PURE;
    STDMETHOD(GetSamplerState)(THIS_ DWORD sampler_idx, D3DSAMPLERSTATETYPE state, DWORD *value) PURE;
    STDMETHOD(SetSamplerState)(THIS_ DWORD sampler_idx, D3DSAMPLERSTATETYPE state, DWORD value) PURE;
    STDMETHOD(ValidateDevice)(THIS_ DWORD *pass_count) PURE;
    STDMETHOD(SetPaletteEntries)(THIS_ UINT palette_idx, const PALETTEENTRY *entries) PURE;
    STDMETHOD(GetPaletteEntries)(THIS_ UINT palette_idx, PALETTEENTRY *entries) PURE;
    STDMETHOD(SetCurrentTexturePalette)(THIS_ UINT palette_idx) PURE;
    STDMETHOD(GetCurrentTexturePalette)(THIS_ UINT *palette_idx) PURE;
    STDMETHOD(SetScissorRect)(THIS_ const RECT *rect) PURE;
    STDMETHOD(GetScissorRect)(THIS_ RECT *rect) PURE;
    STDMETHOD(SetSoftwareVertexProcessing)(THIS_ WINBOOL software) PURE;
    STDMETHOD_(WINBOOL, GetSoftwareVertexProcessing)(THIS) PURE;
    STDMETHOD(SetNPatchMode)(THIS_ float segment_count) PURE;
    STDMETHOD_(float, GetNPatchMode)(THIS) PURE;
    STDMETHOD(DrawPrimitive)(THIS_ D3DPRIMITIVETYPE primitive_type, UINT start_vertex, UINT primitive_count) PURE;
    STDMETHOD(DrawIndexedPrimitive)(THIS_ D3DPRIMITIVETYPE primitive_type, INT base_vertex_idx, UINT min_vertex_idx,
            UINT vertex_count, UINT start_idx, UINT primitive_count) PURE;
    STDMETHOD(DrawPrimitiveUP)(THIS_ D3DPRIMITIVETYPE primitive_type,
            UINT primitive_count, const void *data, UINT stride) PURE;
    STDMETHOD(DrawIndexedPrimitiveUP)(THIS_ D3DPRIMITIVETYPE primitive_type, UINT min_vertex_idx, UINT vertex_count,
            UINT primitive_count, const void *index_data, D3DFORMAT index_format, const void *data, UINT stride) PURE;
    STDMETHOD(ProcessVertices)(THIS_ UINT src_start_idx, UINT dst_idx, UINT vertex_count,
            IDirect3DVertexBuffer9 *dst_buffer, IDirect3DVertexDeclaration9 *declaration, DWORD flags) PURE;
    STDMETHOD(CreateVertexDeclaration)(THIS_ const D3DVERTEXELEMENT9 *elements,
            IDirect3DVertexDeclaration9 **declaration) PURE;
    STDMETHOD(SetVertexDeclaration)(THIS_ IDirect3DVertexDeclaration9 *declaration) PURE;
    STDMETHOD(GetVertexDeclaration)(THIS_ IDirect3DVertexDeclaration9 **declaration) PURE;
    STDMETHOD(SetFVF)(THIS_ DWORD fvf) PURE;
    STDMETHOD(GetFVF)(THIS_ DWORD *fvf) PURE;
    STDMETHOD(CreateVertexShader)(THIS_ const DWORD *byte_code, IDirect3DVertexShader9 **shader) PURE;
    STDMETHOD(SetVertexShader)(THIS_ IDirect3DVertexShader9 *shader) PURE;
    STDMETHOD(GetVertexShader)(THIS_ IDirect3DVertexShader9 **shader) PURE;
    STDMETHOD(SetVertexShaderConstantF)(THIS_ UINT reg_idx, const float *data, UINT count) PURE;
    STDMETHOD(GetVertexShaderConstantF)(THIS_ UINT reg_idx, float *data, UINT count) PURE;
    STDMETHOD(SetVertexShaderConstantI)(THIS_ UINT reg_idx, const int *data, UINT count) PURE;
    STDMETHOD(GetVertexShaderConstantI)(THIS_ UINT reg_idx, int *data, UINT count) PURE;
    STDMETHOD(SetVertexShaderConstantB)(THIS_ UINT reg_idx, const WINBOOL *data, UINT count) PURE;
    STDMETHOD(GetVertexShaderConstantB)(THIS_ UINT reg_idx, WINBOOL *data, UINT count) PURE;
    STDMETHOD(SetStreamSource)(THIS_ UINT stream_idx, IDirect3DVertexBuffer9 *buffer, UINT offset, UINT stride) PURE;
    STDMETHOD(GetStreamSource)(THIS_ UINT stream_idx, IDirect3DVertexBuffer9 **buffer, UINT *offset, UINT *stride) PURE;
    STDMETHOD(SetStreamSourceFreq)(THIS_ UINT stream_idx, UINT frequency) PURE;
    STDMETHOD(GetStreamSourceFreq)(THIS_ UINT stream_idx, UINT *frequency) PURE;
    STDMETHOD(SetIndices)(THIS_ IDirect3DIndexBuffer9 *buffer) PURE;
    STDMETHOD(GetIndices)(THIS_ IDirect3DIndexBuffer9 **buffer) PURE;
    STDMETHOD(CreatePixelShader)(THIS_ const DWORD *byte_code, IDirect3DPixelShader9 **shader) PURE;
    STDMETHOD(SetPixelShader)(THIS_ IDirect3DPixelShader9 *shader) PURE;
    STDMETHOD(GetPixelShader)(THIS_ IDirect3DPixelShader9 **shader) PURE;
    STDMETHOD(SetPixelShaderConstantF)(THIS_ UINT reg_idx, const float *data, UINT count) PURE;
    STDMETHOD(GetPixelShaderConstantF)(THIS_ UINT reg_idx, float *data, UINT count) PURE;
    STDMETHOD(SetPixelShaderConstantI)(THIS_ UINT reg_idx, const int *data, UINT count) PURE;
    STDMETHOD(GetPixelShaderConstantI)(THIS_ UINT reg_idx, int *data, UINT count) PURE;
    STDMETHOD(SetPixelShaderConstantB)(THIS_ UINT reg_idx, const WINBOOL *data, UINT count) PURE;
    STDMETHOD(GetPixelShaderConstantB)(THIS_ UINT reg_idx, WINBOOL *data, UINT count) PURE;
    STDMETHOD(DrawRectPatch)(THIS_ UINT handle, const float *segment_count, const D3DRECTPATCH_INFO *patch_info) PURE;
    STDMETHOD(DrawTriPatch)(THIS_ UINT handle, const float *segment_count, const D3DTRIPATCH_INFO *patch_info) PURE;
    STDMETHOD(DeletePatch)(THIS_ UINT handle) PURE;
    STDMETHOD(CreateQuery)(THIS_ D3DQUERYTYPE type, IDirect3DQuery9 **query) PURE;
    /* IDirect3DDevice9Ex */
    STDMETHOD(SetConvolutionMonoKernel)(THIS_ UINT width, UINT height, float *rows, float *columns) PURE;
    STDMETHOD(ComposeRects)(THIS_ IDirect3DSurface9 *src_surface, IDirect3DSurface9 *dst_surface,
            IDirect3DVertexBuffer9 *src_descs, UINT rect_count, IDirect3DVertexBuffer9 *dst_descs,
            D3DCOMPOSERECTSOP operation, INT offset_x, INT offset_y) PURE;
    STDMETHOD(PresentEx)(THIS_ const RECT *src_rect, const RECT *dst_rect,
            HWND dst_window_override, const RGNDATA *dirty_region, DWORD flags) PURE;
    STDMETHOD(GetGPUThreadPriority)(THIS_ INT *priority) PURE;
    STDMETHOD(SetGPUThreadPriority)(THIS_ INT priority) PURE;
    STDMETHOD(WaitForVBlank)(THIS_ UINT swapchain_idx) PURE;
    STDMETHOD(CheckResourceResidency)(THIS_ IDirect3DResource9 **resources, UINT32 resource_count) PURE;
    STDMETHOD(SetMaximumFrameLatency)(THIS_ UINT max_latency) PURE;
    STDMETHOD(GetMaximumFrameLatency)(THIS_ UINT *max_latency) PURE;
    STDMETHOD(CheckDeviceState)(THIS_ HWND dst_window) PURE;
    STDMETHOD(CreateRenderTargetEx)(THIS_ UINT width, UINT height, D3DFORMAT format,
            D3DMULTISAMPLE_TYPE multisample_type, DWORD multisample_quality, WINBOOL lockable,
            IDirect3DSurface9 **surface, HANDLE *shared_handle, DWORD usage) PURE;
    STDMETHOD(CreateOffscreenPlainSurfaceEx)(THIS_ UINT width, UINT Height, D3DFORMAT format,
            D3DPOOL pool, IDirect3DSurface9 **surface, HANDLE *shared_handle, DWORD usage) PURE;
    STDMETHOD(CreateDepthStencilSurfaceEx)(THIS_ UINT width, UINT height, D3DFORMAT format,
            D3DMULTISAMPLE_TYPE multisample_type, DWORD multisample_quality, WINBOOL discard,
            IDirect3DSurface9 **surface, HANDLE *shared_handle, DWORD usage) PURE;
    STDMETHOD(ResetEx)(THIS_ D3DPRESENT_PARAMETERS *parameters, D3DDISPLAYMODEEX *mode) PURE;
    STDMETHOD(GetDisplayModeEx)(THIS_ UINT swapchain_idx, D3DDISPLAYMODEEX *mode, D3DDISPLAYROTATION *rotation) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/* IUnknown */
#define IDirect3DDevice9Ex_QueryInterface(p,a,b)                            (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DDevice9Ex_AddRef(p)                                        (p)->lpVtbl->AddRef(p)
#define IDirect3DDevice9Ex_Release(p)                                       (p)->lpVtbl->Release(p)
/* IDirect3DDevice9 */
#define IDirect3DDevice9Ex_TestCooperativeLevel(p)                          (p)->lpVtbl->TestCooperativeLevel(p)
#define IDirect3DDevice9Ex_GetAvailableTextureMem(p)                        (p)->lpVtbl->GetAvailableTextureMem(p)
#define IDirect3DDevice9Ex_EvictManagedResources(p)                         (p)->lpVtbl->EvictManagedResources(p)
#define IDirect3DDevice9Ex_GetDirect3D(p,a)                                 (p)->lpVtbl->GetDirect3D(p,a)
#define IDirect3DDevice9Ex_GetDeviceCaps(p,a)                               (p)->lpVtbl->GetDeviceCaps(p,a)
#define IDirect3DDevice9Ex_GetDisplayMode(p,a,b)                            (p)->lpVtbl->GetDisplayMode(p,a,b)
#define IDirect3DDevice9Ex_GetCreationParameters(p,a)                       (p)->lpVtbl->GetCreationParameters(p,a)
#define IDirect3DDevice9Ex_SetCursorProperties(p,a,b,c)                     (p)->lpVtbl->SetCursorProperties(p,a,b,c)
#define IDirect3DDevice9Ex_SetCursorPosition(p,a,b,c)                       (p)->lpVtbl->SetCursorPosition(p,a,b,c)
#define IDirect3DDevice9Ex_ShowCursor(p,a)                                  (p)->lpVtbl->ShowCursor(p,a)
#define IDirect3DDevice9Ex_CreateAdditionalSwapChain(p,a,b)                 (p)->lpVtbl->CreateAdditionalSwapChain(p,a,b)
#define IDirect3DDevice9Ex_GetSwapChain(p,a,b)                              (p)->lpVtbl->GetSwapChain(p,a,b)
#define IDirect3DDevice9Ex_GetNumberOfSwapChains(p)                         (p)->lpVtbl->GetNumberOfSwapChains(p)
#define IDirect3DDevice9Ex_Reset(p,a)                                       (p)->lpVtbl->Reset(p,a)
#define IDirect3DDevice9Ex_Present(p,a,b,c,d)                               (p)->lpVtbl->Present(p,a,b,c,d)
#define IDirect3DDevice9Ex_GetBackBuffer(p,a,b,c,d)                         (p)->lpVtbl->GetBackBuffer(p,a,b,c,d)
#define IDirect3DDevice9Ex_GetRasterStatus(p,a,b)                           (p)->lpVtbl->GetRasterStatus(p,a,b)
#define IDirect3DDevice9Ex_SetDialogBoxMode(p,a)                            (p)->lpVtbl->SetDialogBoxMode(p,a)
#define IDirect3DDevice9Ex_SetGammaRamp(p,a,b,c)                            (p)->lpVtbl->SetGammaRamp(p,a,b,c)
#define IDirect3DDevice9Ex_GetGammaRamp(p,a,b)                              (p)->lpVtbl->GetGammaRamp(p,a,b)
#define IDirect3DDevice9Ex_CreateTexture(p,a,b,c,d,e,f,g,h)                 (p)->lpVtbl->CreateTexture(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_CreateVolumeTexture(p,a,b,c,d,e,f,g,h,i)         (p)->lpVtbl->CreateVolumeTexture(p,a,b,c,d,e,f,g,h,i)
#define IDirect3DDevice9Ex_CreateCubeTexture(p,a,b,c,d,e,f,g)               (p)->lpVtbl->CreateCubeTexture(p,a,b,c,d,e,f,g)
#define IDirect3DDevice9Ex_CreateVertexBuffer(p,a,b,c,d,e,f)                (p)->lpVtbl->CreateVertexBuffer(p,a,b,c,d,e,f)
#define IDirect3DDevice9Ex_CreateIndexBuffer(p,a,b,c,d,e,f)                 (p)->lpVtbl->CreateIndexBuffer(p,a,b,c,d,e,f)
#define IDirect3DDevice9Ex_CreateRenderTarget(p,a,b,c,d,e,f,g,h)            (p)->lpVtbl->CreateRenderTarget(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_CreateDepthStencilSurface(p,a,b,c,d,e,f,g,h)     (p)->lpVtbl->CreateDepthStencilSurface(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_UpdateSurface(p,a,b,c,d)                         (p)->lpVtbl->UpdateSurface(p,a,b,c,d)
#define IDirect3DDevice9Ex_UpdateTexture(p,a,b)                             (p)->lpVtbl->UpdateTexture(p,a,b)
#define IDirect3DDevice9Ex_GetRenderTargetData(p,a,b)                       (p)->lpVtbl->GetRenderTargetData(p,a,b)
#define IDirect3DDevice9Ex_GetFrontBufferData(p,a,b)                        (p)->lpVtbl->GetFrontBufferData(p,a,b)
#define IDirect3DDevice9Ex_StretchRect(p,a,b,c,d,e)                         (p)->lpVtbl->StretchRect(p,a,b,c,d,e)
#define IDirect3DDevice9Ex_ColorFill(p,a,b,c)                               (p)->lpVtbl->ColorFill(p,a,b,c)
#define IDirect3DDevice9Ex_CreateOffscreenPlainSurface(p,a,b,c,d,e,f)       (p)->lpVtbl->CreateOffscreenPlainSurface(p,a,b,c,d,e,f)
#define IDirect3DDevice9Ex_SetRenderTarget(p,a,b)                           (p)->lpVtbl->SetRenderTarget(p,a,b)
#define IDirect3DDevice9Ex_GetRenderTarget(p,a,b)                           (p)->lpVtbl->GetRenderTarget(p,a,b)
#define IDirect3DDevice9Ex_SetDepthStencilSurface(p,a)                      (p)->lpVtbl->SetDepthStencilSurface(p,a)
#define IDirect3DDevice9Ex_GetDepthStencilSurface(p,a)                      (p)->lpVtbl->GetDepthStencilSurface(p,a)
#define IDirect3DDevice9Ex_BeginScene(p)                                    (p)->lpVtbl->BeginScene(p)
#define IDirect3DDevice9Ex_EndScene(p)                                      (p)->lpVtbl->EndScene(p)
#define IDirect3DDevice9Ex_Clear(p,a,b,c,d,e,f)                             (p)->lpVtbl->Clear(p,a,b,c,d,e,f)
#define IDirect3DDevice9Ex_SetTransform(p,a,b)                              (p)->lpVtbl->SetTransform(p,a,b)
#define IDirect3DDevice9Ex_GetTransform(p,a,b)                              (p)->lpVtbl->GetTransform(p,a,b)
#define IDirect3DDevice9Ex_MultiplyTransform(p,a,b)                         (p)->lpVtbl->MultiplyTransform(p,a,b)
#define IDirect3DDevice9Ex_SetViewport(p,a)                                 (p)->lpVtbl->SetViewport(p,a)
#define IDirect3DDevice9Ex_GetViewport(p,a)                                 (p)->lpVtbl->GetViewport(p,a)
#define IDirect3DDevice9Ex_SetMaterial(p,a)                                 (p)->lpVtbl->SetMaterial(p,a)
#define IDirect3DDevice9Ex_GetMaterial(p,a)                                 (p)->lpVtbl->GetMaterial(p,a)
#define IDirect3DDevice9Ex_SetLight(p,a,b)                                  (p)->lpVtbl->SetLight(p,a,b)
#define IDirect3DDevice9Ex_GetLight(p,a,b)                                  (p)->lpVtbl->GetLight(p,a,b)
#define IDirect3DDevice9Ex_LightEnable(p,a,b)                               (p)->lpVtbl->LightEnable(p,a,b)
#define IDirect3DDevice9Ex_GetLightEnable(p,a,b)                            (p)->lpVtbl->GetLightEnable(p,a,b)
#define IDirect3DDevice9Ex_SetClipPlane(p,a,b)                              (p)->lpVtbl->SetClipPlane(p,a,b)
#define IDirect3DDevice9Ex_GetClipPlane(p,a,b)                              (p)->lpVtbl->GetClipPlane(p,a,b)
#define IDirect3DDevice9Ex_SetRenderState(p,a,b)                            (p)->lpVtbl->SetRenderState(p,a,b)
#define IDirect3DDevice9Ex_GetRenderState(p,a,b)                            (p)->lpVtbl->GetRenderState(p,a,b)
#define IDirect3DDevice9Ex_CreateStateBlock(p,a,b)                          (p)->lpVtbl->CreateStateBlock(p,a,b)
#define IDirect3DDevice9Ex_BeginStateBlock(p)                               (p)->lpVtbl->BeginStateBlock(p)
#define IDirect3DDevice9Ex_EndStateBlock(p,a)                               (p)->lpVtbl->EndStateBlock(p,a)
#define IDirect3DDevice9Ex_SetClipStatus(p,a)                               (p)->lpVtbl->SetClipStatus(p,a)
#define IDirect3DDevice9Ex_GetClipStatus(p,a)                               (p)->lpVtbl->GetClipStatus(p,a)
#define IDirect3DDevice9Ex_GetTexture(p,a,b)                                (p)->lpVtbl->GetTexture(p,a,b)
#define IDirect3DDevice9Ex_SetTexture(p,a,b)                                (p)->lpVtbl->SetTexture(p,a,b)
#define IDirect3DDevice9Ex_GetTextureStageState(p,a,b,c)                    (p)->lpVtbl->GetTextureStageState(p,a,b,c)
#define IDirect3DDevice9Ex_SetTextureStageState(p,a,b,c)                    (p)->lpVtbl->SetTextureStageState(p,a,b,c)
#define IDirect3DDevice9Ex_GetSamplerState(p,a,b,c)                         (p)->lpVtbl->GetSamplerState(p,a,b,c)
#define IDirect3DDevice9Ex_SetSamplerState(p,a,b,c)                         (p)->lpVtbl->SetSamplerState(p,a,b,c)
#define IDirect3DDevice9Ex_ValidateDevice(p,a)                              (p)->lpVtbl->ValidateDevice(p,a)
#define IDirect3DDevice9Ex_SetPaletteEntries(p,a,b)                         (p)->lpVtbl->SetPaletteEntries(p,a,b)
#define IDirect3DDevice9Ex_GetPaletteEntries(p,a,b)                         (p)->lpVtbl->GetPaletteEntries(p,a,b)
#define IDirect3DDevice9Ex_SetCurrentTexturePalette(p,a)                    (p)->lpVtbl->SetCurrentTexturePalette(p,a)
#define IDirect3DDevice9Ex_GetCurrentTexturePalette(p,a)                    (p)->lpVtbl->GetCurrentTexturePalette(p,a)
#define IDirect3DDevice9Ex_SetScissorRect(p,a)                              (p)->lpVtbl->SetScissorRect(p,a)
#define IDirect3DDevice9Ex_GetScissorRect(p,a)                              (p)->lpVtbl->GetScissorRect(p,a)
#define IDirect3DDevice9Ex_SetSoftwareVertexProcessing(p,a)                 (p)->lpVtbl->SetSoftwareVertexProcessing(p,a)
#define IDirect3DDevice9Ex_GetSoftwareVertexProcessing(p)                   (p)->lpVtbl->GetSoftwareVertexProcessing(p)
#define IDirect3DDevice9Ex_SetNPatchMode(p,a)                               (p)->lpVtbl->SetNPatchMode(p,a)
#define IDirect3DDevice9Ex_GetNPatchMode(p)                                 (p)->lpVtbl->GetNPatchMode(p)
#define IDirect3DDevice9Ex_DrawPrimitive(p,a,b,c)                           (p)->lpVtbl->DrawPrimitive(p,a,b,c)
#define IDirect3DDevice9Ex_DrawIndexedPrimitive(p,a,b,c,d,e,f)              (p)->lpVtbl->DrawIndexedPrimitive(p,a,b,c,d,e,f)
#define IDirect3DDevice9Ex_DrawPrimitiveUP(p,a,b,c,d)                       (p)->lpVtbl->DrawPrimitiveUP(p,a,b,c,d)
#define IDirect3DDevice9Ex_DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h)        (p)->lpVtbl->DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_ProcessVertices(p,a,b,c,d,e,f)                   (p)->lpVtbl->ProcessVertices(p,a,b,c,d,e,f)
#define IDirect3DDevice9Ex_CreateVertexDeclaration(p,a,b)                   (p)->lpVtbl->CreateVertexDeclaration(p,a,b)
#define IDirect3DDevice9Ex_SetVertexDeclaration(p,a)                        (p)->lpVtbl->SetVertexDeclaration(p,a)
#define IDirect3DDevice9Ex_GetVertexDeclaration(p,a)                        (p)->lpVtbl->GetVertexDeclaration(p,a)
#define IDirect3DDevice9Ex_SetFVF(p,a)                                      (p)->lpVtbl->SetFVF(p,a)
#define IDirect3DDevice9Ex_GetFVF(p,a)                                      (p)->lpVtbl->GetFVF(p,a)
#define IDirect3DDevice9Ex_CreateVertexShader(p,a,b)                        (p)->lpVtbl->CreateVertexShader(p,a,b)
#define IDirect3DDevice9Ex_SetVertexShader(p,a)                             (p)->lpVtbl->SetVertexShader(p,a)
#define IDirect3DDevice9Ex_GetVertexShader(p,a)                             (p)->lpVtbl->GetVertexShader(p,a)
#define IDirect3DDevice9Ex_SetVertexShaderConstantF(p,a,b,c)                (p)->lpVtbl->SetVertexShaderConstantF(p,a,b,c)
#define IDirect3DDevice9Ex_GetVertexShaderConstantF(p,a,b,c)                (p)->lpVtbl->GetVertexShaderConstantF(p,a,b,c)
#define IDirect3DDevice9Ex_SetVertexShaderConstantI(p,a,b,c)                (p)->lpVtbl->SetVertexShaderConstantI(p,a,b,c)
#define IDirect3DDevice9Ex_GetVertexShaderConstantI(p,a,b,c)                (p)->lpVtbl->GetVertexShaderConstantI(p,a,b,c)
#define IDirect3DDevice9Ex_SetVertexShaderConstantB(p,a,b,c)                (p)->lpVtbl->SetVertexShaderConstantB(p,a,b,c)
#define IDirect3DDevice9Ex_GetVertexShaderConstantB(p,a,b,c)                (p)->lpVtbl->GetVertexShaderConstantB(p,a,b,c)
#define IDirect3DDevice9Ex_SetStreamSource(p,a,b,c,d)                       (p)->lpVtbl->SetStreamSource(p,a,b,c,d)
#define IDirect3DDevice9Ex_GetStreamSource(p,a,b,c,d)                       (p)->lpVtbl->GetStreamSource(p,a,b,c,d)
#define IDirect3DDevice9Ex_SetStreamSourceFreq(p,a,b)                       (p)->lpVtbl->SetStreamSourceFreq(p,a,b)
#define IDirect3DDevice9Ex_GetStreamSourceFreq(p,a,b)                       (p)->lpVtbl->GetStreamSourceFreq(p,a,b)
#define IDirect3DDevice9Ex_SetIndices(p,a)                                  (p)->lpVtbl->SetIndices(p,a)
#define IDirect3DDevice9Ex_GetIndices(p,a)                                  (p)->lpVtbl->GetIndices(p,a)
#define IDirect3DDevice9Ex_CreatePixelShader(p,a,b)                         (p)->lpVtbl->CreatePixelShader(p,a,b)
#define IDirect3DDevice9Ex_SetPixelShader(p,a)                              (p)->lpVtbl->SetPixelShader(p,a)
#define IDirect3DDevice9Ex_GetPixelShader(p,a)                              (p)->lpVtbl->GetPixelShader(p,a)
#define IDirect3DDevice9Ex_SetPixelShaderConstantF(p,a,b,c)                 (p)->lpVtbl->SetPixelShaderConstantF(p,a,b,c)
#define IDirect3DDevice9Ex_GetPixelShaderConstantF(p,a,b,c)                 (p)->lpVtbl->GetPixelShaderConstantF(p,a,b,c)
#define IDirect3DDevice9Ex_SetPixelShaderConstantI(p,a,b,c)                 (p)->lpVtbl->SetPixelShaderConstantI(p,a,b,c)
#define IDirect3DDevice9Ex_GetPixelShaderConstantI(p,a,b,c)                 (p)->lpVtbl->GetPixelShaderConstantI(p,a,b,c)
#define IDirect3DDevice9Ex_SetPixelShaderConstantB(p,a,b,c)                 (p)->lpVtbl->SetPixelShaderConstantB(p,a,b,c)
#define IDirect3DDevice9Ex_GetPixelShaderConstantB(p,a,b,c)                 (p)->lpVtbl->GetPixelShaderConstantB(p,a,b,c)
#define IDirect3DDevice9Ex_DrawRectPatch(p,a,b,c)                           (p)->lpVtbl->DrawRectPatch(p,a,b,c)
#define IDirect3DDevice9Ex_DrawTriPatch(p,a,b,c)                            (p)->lpVtbl->DrawTriPatch(p,a,b,c)
#define IDirect3DDevice9Ex_DeletePatch(p,a)                                 (p)->lpVtbl->DeletePatch(p,a)
#define IDirect3DDevice9Ex_CreateQuery(p,a,b)                               (p)->lpVtbl->CreateQuery(p,a,b)
/* IDirect3DDevice9Ex */
#define IDirect3DDevice9Ex_SetConvolutionMonoKernel(p,a,b,c,d)              (p)->lpVtbl->SetConvolutionMonoKernel(p,a,b,c,d)
#define IDirect3DDevice9Ex_ComposeRects(p,a,b,c,d,e,f,g,h)                  (p)->lpVtbl->ComposeRects(p,a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_PresentEx(p,a,b,c,d,e)                           (p)->lpVtbl->PresentEx(p,a,b,c,d,e)
#define IDirect3DDevice9Ex_GetGPUThreadPriority(p,a)                        (p)->lpVtbl->GetGPUThreadPriority(p,a)
#define IDirect3DDevice9Ex_SetGPUThreadPriority(p,a)                        (p)->lpVtbl->SetGPUThreadPriority(p,a)
#define IDirect3DDevice9Ex_WaitForVBlank(p,a)                               (p)->lpVtbl->WaitForVBlank(p,a)
#define IDirect3DDevice9Ex_CheckResourceResidency(p,a,b)                    (p)->lpVtbl->CheckResourceResidency(p,a,b)
#define IDirect3DDevice9Ex_SetMaximumFrameLatency(p,a)                      (p)->lpVtbl->SetMaximumFrameLatency(p,a)
#define IDirect3DDevice9Ex_GetMaximumFrameLatency(p,a)                      (p)->lpVtbl->GetMaximumFrameLatency(p,a)
#define IDirect3DDevice9Ex_CheckDeviceState(p,a)                            (p)->lpVtbl->CheckDeviceState(p,a)
#define IDirect3DDevice9Ex_CreateRenderTargetEx(p,a,b,c,d,e,f,g,h,i)        (p)->lpVtbl->CreateRenderTargetEx(p,a,b,c,d,e,f,g,h,i)
#define IDirect3DDevice9Ex_CreateOffscreenPlainSurfaceEx(p,a,b,c,d,e,f,g)   (p)->lpVtbl->CreateOffscreenPlainSurfaceEx(p,a,b,c,d,e,f,g)
#define IDirect3DDevice9Ex_CreateDepthStencilSurfaceEx(p,a,b,c,d,e,f,g,h,i) (p)->lpVtbl->CreateDepthStencilSurfaceEx(p,a,b,c,d,e,f,g,h,i)
#define IDirect3DDevice9Ex_ResetEx(p,a,b)                                   (p)->lpVtbl->ResetEx(p,a,b)
#define IDirect3DDevice9Ex_GetDisplayModeEx(p,a,b,c)                        (p)->lpVtbl->GetDisplayModeEx(p,a,b,c)
#else
/* IUnknown */
#define IDirect3DDevice9Ex_QueryInterface(p,a,b)                            (p)->QueryInterface(a,b)
#define IDirect3DDevice9Ex_AddRef(p)                                        (p)->AddRef()
#define IDirect3DDevice9Ex_Release(p)                                       (p)->Release()
/* IDirect3DDevice9 */
#define IDirect3DDevice9Ex_TestCooperativeLevel(p)                          (p)->TestCooperativeLevel()
#define IDirect3DDevice9Ex_GetAvailableTextureMem(p)                        (p)->GetAvailableTextureMem()
#define IDirect3DDevice9Ex_EvictManagedResources(p)                         (p)->EvictManagedResources()
#define IDirect3DDevice9Ex_GetDirect3D(p,a)                                 (p)->GetDirect3D(a)
#define IDirect3DDevice9Ex_GetDeviceCaps(p,a)                               (p)->GetDeviceCaps(a)
#define IDirect3DDevice9Ex_GetDisplayMode(p,a,b)                            (p)->GetDisplayMode(a,b)
#define IDirect3DDevice9Ex_GetCreationParameters(p,a)                       (p)->GetCreationParameters(a)
#define IDirect3DDevice9Ex_SetCursorProperties(p,a,b,c)                     (p)->SetCursorProperties(a,b,c)
#define IDirect3DDevice9Ex_SetCursorPosition(p,a,b,c)                       (p)->SetCursorPosition(a,b,c)
#define IDirect3DDevice9Ex_ShowCursor(p,a)                                  (p)->ShowCursor(a)
#define IDirect3DDevice9Ex_CreateAdditionalSwapChain(p,a,b)                 (p)->CreateAdditionalSwapChain(a,b)
#define IDirect3DDevice9Ex_GetSwapChain(p,a,b)                              (p)->GetSwapChain(a,b)
#define IDirect3DDevice9Ex_GetNumberOfSwapChains(p)                         (p)->GetNumberOfSwapChains()
#define IDirect3DDevice9Ex_Reset(p,a)                                       (p)->Reset(a)
#define IDirect3DDevice9Ex_Present(p,a,b,c,d)                               (p)->Present(a,b,c,d)
#define IDirect3DDevice9Ex_GetBackBuffer(p,a,b,c,d)                         (p)->GetBackBuffer(a,b,c,d)
#define IDirect3DDevice9Ex_GetRasterStatus(p,a,b)                           (p)->GetRasterStatus(a,b)
#define IDirect3DDevice9Ex_SetDialogBoxMode(p,a)                            (p)->SetDialogBoxMode(a)
#define IDirect3DDevice9Ex_SetGammaRamp(p,a,b,c)                            (p)->SetGammaRamp(a,b,c)
#define IDirect3DDevice9Ex_GetGammaRamp(p,a,b)                              (p)->GetGammaRamp(a,b)
#define IDirect3DDevice9Ex_CreateTexture(p,a,b,c,d,e,f,g,h)                 (p)->CreateTexture(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_CreateVolumeTexture(p,a,b,c,d,e,f,g,h,i)         (p)->CreateVolumeTexture(a,b,c,d,e,f,g,h,i)
#define IDirect3DDevice9Ex_CreateCubeTexture(p,a,b,c,d,e,f,g)               (p)->CreateCubeTexture(a,b,c,d,e,f,g)
#define IDirect3DDevice9Ex_CreateVertexBuffer(p,a,b,c,d,e,f)                (p)->CreateVertexBuffer(a,b,c,d,e,f)
#define IDirect3DDevice9Ex_CreateIndexBuffer(p,a,b,c,d,e,f)                 (p)->CreateIndexBuffer(a,b,c,d,e,f)
#define IDirect3DDevice9Ex_CreateRenderTarget(p,a,b,c,d,e,f,g,h)            (p)->CreateRenderTarget(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_CreateDepthStencilSurface(p,a,b,c,d,e,f,g,h)     (p)->CreateDepthStencilSurface(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_UpdateSurface(p,a,b,c,d)                         (p)->UpdateSurface(a,b,c,d)
#define IDirect3DDevice9Ex_UpdateTexture(p,a,b)                             (p)->UpdateTexture(a,b)
#define IDirect3DDevice9Ex_GetRenderTargetData(p,a,b)                       (p)->GetRenderTargetData(a,b)
#define IDirect3DDevice9Ex_GetFrontBufferData(p,a,b)                        (p)->GetFrontBufferData(a,b)
#define IDirect3DDevice9Ex_StretchRect(p,a,b,c,d,e)                         (p)->StretchRect(a,b,c,d,e)
#define IDirect3DDevice9Ex_ColorFill(p,a,b,c)                               (p)->ColorFill(a,b,c)
#define IDirect3DDevice9Ex_CreateOffscreenPlainSurface(p,a,b,c,d,e,f)       (p)->CreateOffscreenPlainSurface(a,b,c,d,e,f)
#define IDirect3DDevice9Ex_SetRenderTarget(p,a,b)                           (p)->SetRenderTarget(a,b)
#define IDirect3DDevice9Ex_GetRenderTarget(p,a,b)                           (p)->GetRenderTarget(a,b)
#define IDirect3DDevice9Ex_SetDepthStencilSurface(p,a)                      (p)->SetDepthStencilSurface(a)
#define IDirect3DDevice9Ex_GetDepthStencilSurface(p,a)                      (p)->GetDepthStencilSurface(a)
#define IDirect3DDevice9Ex_BeginScene(p)                                    (p)->BeginScene()
#define IDirect3DDevice9Ex_EndScene(p)                                      (p)->EndScene()
#define IDirect3DDevice9Ex_Clear(p,a,b,c,d,e,f)                             (p)->Clear(a,b,c,d,e,f)
#define IDirect3DDevice9Ex_SetTransform(p,a,b)                              (p)->SetTransform(a,b)
#define IDirect3DDevice9Ex_GetTransform(p,a,b)                              (p)->GetTransform(a,b)
#define IDirect3DDevice9Ex_MultiplyTransform(p,a,b)                         (p)->MultiplyTransform(a,b)
#define IDirect3DDevice9Ex_SetViewport(p,a)                                 (p)->SetViewport(a)
#define IDirect3DDevice9Ex_GetViewport(p,a)                                 (p)->GetViewport(a)
#define IDirect3DDevice9Ex_SetMaterial(p,a)                                 (p)->SetMaterial(a)
#define IDirect3DDevice9Ex_GetMaterial(p,a)                                 (p)->GetMaterial(a)
#define IDirect3DDevice9Ex_SetLight(p,a,b)                                  (p)->SetLight(a,b)
#define IDirect3DDevice9Ex_GetLight(p,a,b)                                  (p)->GetLight(a,b)
#define IDirect3DDevice9Ex_LightEnable(p,a,b)                               (p)->LightEnable(a,b)
#define IDirect3DDevice9Ex_GetLightEnable(p,a,b)                            (p)->GetLightEnable(a,b)
#define IDirect3DDevice9Ex_SetClipPlane(p,a,b)                              (p)->SetClipPlane(a,b)
#define IDirect3DDevice9Ex_GetClipPlane(p,a,b)                              (p)->GetClipPlane(a,b)
#define IDirect3DDevice9Ex_SetRenderState(p,a,b)                            (p)->SetRenderState(a,b)
#define IDirect3DDevice9Ex_GetRenderState(p,a,b)                            (p)->GetRenderState(a,b)
#define IDirect3DDevice9Ex_CreateStateBlock(p,a,b)                          (p)->CreateStateBlock(a,b)
#define IDirect3DDevice9Ex_BeginStateBlock(p)                               (p)->BeginStateBlock()
#define IDirect3DDevice9Ex_EndStateBlock(p,a)                               (p)->EndStateBlock(a)
#define IDirect3DDevice9Ex_SetClipStatus(p,a)                               (p)->SetClipStatus(a)
#define IDirect3DDevice9Ex_GetClipStatus(p,a)                               (p)->GetClipStatus(a)
#define IDirect3DDevice9Ex_GetTexture(p,a,b)                                (p)->GetTexture(a,b)
#define IDirect3DDevice9Ex_SetTexture(p,a,b)                                (p)->SetTexture(a,b)
#define IDirect3DDevice9Ex_GetTextureStageState(p,a,b,c)                    (p)->GetTextureStageState(a,b,c)
#define IDirect3DDevice9Ex_SetTextureStageState(p,a,b,c)                    (p)->SetTextureStageState(a,b,c)
#define IDirect3DDevice9Ex_GetSamplerState(p,a,b,c)                         (p)->GetSamplerState(a,b,c)
#define IDirect3DDevice9Ex_SetSamplerState(p,a,b,c)                         (p)->SetSamplerState(a,b,c)
#define IDirect3DDevice9Ex_ValidateDevice(p,a)                              (p)->ValidateDevice(a)
#define IDirect3DDevice9Ex_SetPaletteEntries(p,a,b)                         (p)->SetPaletteEntries(a,b)
#define IDirect3DDevice9Ex_GetPaletteEntries(p,a,b)                         (p)->GetPaletteEntries(a,b)
#define IDirect3DDevice9Ex_SetCurrentTexturePalette(p,a)                    (p)->SetCurrentTexturePalette(a)
#define IDirect3DDevice9Ex_GetCurrentTexturePalette(p,a)                    (p)->GetCurrentTexturePalette(a)
#define IDirect3DDevice9Ex_SetScissorRect(p,a)                              (p)->SetScissorRect(a)
#define IDirect3DDevice9Ex_GetScissorRect(p,a)                              (p)->GetScissorRect(a)
#define IDirect3DDevice9Ex_SetSoftwareVertexProcessing(p,a)                 (p)->SetSoftwareVertexProcessing(a)
#define IDirect3DDevice9Ex_GetSoftwareVertexProcessing(p)                   (p)->GetSoftwareVertexProcessing()
#define IDirect3DDevice9Ex_SetNPatchMode(p,a)                               (p)->SetNPatchMode(a)
#define IDirect3DDevice9Ex_GetNPatchMode(p)                                 (p)->GetNPatchMode()
#define IDirect3DDevice9Ex_DrawPrimitive(p,a,b,c)                           (p)->DrawPrimitive(a,b,c)
#define IDirect3DDevice9Ex_DrawIndexedPrimitive(p,a,b,c,d,e,f)              (p)->DrawIndexedPrimitive(a,b,c,d,e,f)
#define IDirect3DDevice9Ex_DrawPrimitiveUP(p,a,b,c,d)                       (p)->DrawPrimitiveUP(a,b,c,d)
#define IDirect3DDevice9Ex_DrawIndexedPrimitiveUP(p,a,b,c,d,e,f,g,h)        (p)->DrawIndexedPrimitiveUP(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_ProcessVertices(p,a,b,c,d,e,f)                   (p)->ProcessVertices(a,b,c,d,e,f)
#define IDirect3DDevice9Ex_CreateVertexDeclaration(p,a,b)                   (p)->CreateVertexDeclaration(a,b)
#define IDirect3DDevice9Ex_SetVertexDeclaration(p,a)                        (p)->SetVertexDeclaration(a)
#define IDirect3DDevice9Ex_GetVertexDeclaration(p,a)                        (p)->GetVertexDeclaration(a)
#define IDirect3DDevice9Ex_SetFVF(p,a)                                      (p)->SetFVF(a)
#define IDirect3DDevice9Ex_GetFVF(p,a)                                      (p)->GetFVF(a)
#define IDirect3DDevice9Ex_CreateVertexShader(p,a,b)                        (p)->CreateVertexShader(a,b)
#define IDirect3DDevice9Ex_SetVertexShader(p,a)                             (p)->SetVertexShader(a)
#define IDirect3DDevice9Ex_GetVertexShader(p,a)                             (p)->GetVertexShader(a)
#define IDirect3DDevice9Ex_SetVertexShaderConstantF(p,a,b,c)                (p)->SetVertexShaderConstantF(a,b,c)
#define IDirect3DDevice9Ex_GetVertexShaderConstantF(p,a,b,c)                (p)->GetVertexShaderConstantF(a,b,c)
#define IDirect3DDevice9Ex_SetVertexShaderConstantI(p,a,b,c)                (p)->SetVertexShaderConstantI(a,b,c)
#define IDirect3DDevice9Ex_GetVertexShaderConstantI(p,a,b,c)                (p)->GetVertexShaderConstantI(a,b,c)
#define IDirect3DDevice9Ex_SetVertexShaderConstantB(p,a,b,c)                (p)->SetVertexShaderConstantB(a,b,c)
#define IDirect3DDevice9Ex_GetVertexShaderConstantB(p,a,b,c)                (p)->GetVertexShaderConstantB(a,b,c)
#define IDirect3DDevice9Ex_SetStreamSource(p,a,b,c,d)                       (p)->SetStreamSource(a,b,c,d)
#define IDirect3DDevice9Ex_GetStreamSource(p,a,b,c,d)                       (p)->GetStreamSource(a,b,c,d)
#define IDirect3DDevice9Ex_SetStreamSourceFreq(p,a,b)                       (p)->SetStreamSourceFreq(a,b)
#define IDirect3DDevice9Ex_GetStreamSourceFreq(p,a,b)                       (p)->GetStreamSourceFreq(a,b)
#define IDirect3DDevice9Ex_SetIndices(p,a)                                  (p)->SetIndices(a)
#define IDirect3DDevice9Ex_GetIndices(p,a)                                  (p)->GetIndices(a)
#define IDirect3DDevice9Ex_CreatePixelShader(p,a,b)                         (p)->CreatePixelShader(a,b)
#define IDirect3DDevice9Ex_SetPixelShader(p,a)                              (p)->SetPixelShader(a)
#define IDirect3DDevice9Ex_GetPixelShader(p,a)                              (p)->GetPixelShader(a)
#define IDirect3DDevice9Ex_SetPixelShaderConstantF(p,a,b,c)                 (p)->SetPixelShaderConstantF(a,b,c)
#define IDirect3DDevice9Ex_GetPixelShaderConstantF(p,a,b,c)                 (p)->GetPixelShaderConstantF(a,b,c)
#define IDirect3DDevice9Ex_SetPixelShaderConstantI(p,a,b,c)                 (p)->SetPixelShaderConstantI(a,b,c)
#define IDirect3DDevice9Ex_GetPixelShaderConstantI(p,a,b,c)                 (p)->GetPixelShaderConstantI(a,b,c)
#define IDirect3DDevice9Ex_SetPixelShaderConstantB(p,a,b,c)                 (p)->SetPixelShaderConstantB(a,b,c)
#define IDirect3DDevice9Ex_GetPixelShaderConstantB(p,a,b,c)                 (p)->GetPixelShaderConstantB(a,b,c)
#define IDirect3DDevice9Ex_DrawRectPatch(p,a,b,c)                           (p)->DrawRectPatch(a,b,c)
#define IDirect3DDevice9Ex_DrawTriPatch(p,a,b,c)                            (p)->DrawTriPatch(a,b,c)
#define IDirect3DDevice9Ex_DeletePatch(p,a)                                 (p)->DeletePatch(a)
#define IDirect3DDevice9Ex_CreateQuery(p,a,b)                               (p)->CreateQuery(a,b)
/* IDirect3DDevice9Ex */
#define IDirect3DDevice9Ex_SetConvolutionMonoKernel(p,a,b,c,d)              (p)->SetConvolutionMonoKernel(a,b,c,d)
#define IDirect3DDevice9Ex_ComposeRects(p,a,b,c,d,e,f,g,h)                  (p)->ComposeRects(a,b,c,d,e,f,g,h)
#define IDirect3DDevice9Ex_PresentEx(p,a,b,c,d,e)                           (p)->PresentEx(a,b,c,d,e)
#define IDirect3DDevice9Ex_GetGPUThreadPriority(p,a)                        (p)->GetGPUThreadPriority(a)
#define IDirect3DDevice9Ex_SetGPUThreadPriority(p,a)                        (p)->SetGPUThreadPriority(a)
#define IDirect3DDevice9Ex_WaitForVBlank(p,a)                               (p)->WaitForVBlank(a)
#define IDirect3DDevice9Ex_CheckResourceResidency(p,a,b)                    (p)->CheckResourceResidency(a,b)
#define IDirect3DDevice9Ex_SetMaximumFrameLatency(p,a)                      (p)->SetMaximumFrameLatency(a)
#define IDirect3DDevice9Ex_GetMaximumFrameLatency(p,a)                      (p)->GetMaximumFrameLatency(a)
#define IDirect3DDevice9Ex_CheckDeviceState(p,a)                            (p)->CheckDeviceState(a)
#define IDirect3DDevice9Ex_CreateRenderTargetEx(p,a,b,c,d,e,f,g,h,i)        (p)->CreateRenderTargetEx(a,b,c,d,e,f,g,h,i)
#define IDirect3DDevice9Ex_CreateOffscreenPlainSurfaceEx(p,a,b,c,d,e,f,g)   (p)->CreateOffscreenPlainSurfaceEx(a,b,c,d,e,f,g)
#define IDirect3DDevice9Ex_CreateDepthStencilSurfaceEx(p,a,b,c,d,e,f,g,h,i) (p)->CreateDepthStencilSurfaceEx(a,b,c,d,e,f,g,h,i)
#define IDirect3DDevice9Ex_ResetEx(p,a,b)                                   (p)->ResetEx(a,b)
#define IDirect3DDevice9Ex_GetDisplayModeEx(p,a,b,c)                        (p)->GetDisplayModeEx(a,b,c)
#endif

#endif /* !defined(D3D_DISABLE_9EX) */

#ifdef __cplusplus
extern "C" {
#endif  /* defined(__cplusplus) */

int WINAPI D3DPERF_BeginEvent(D3DCOLOR color, const WCHAR *name);
int WINAPI D3DPERF_EndEvent(void);
DWORD WINAPI D3DPERF_GetStatus(void);
WINBOOL WINAPI D3DPERF_QueryRepeatFrame(void);
void WINAPI D3DPERF_SetMarker(D3DCOLOR color, const WCHAR *name);
void WINAPI D3DPERF_SetOptions(DWORD options);
void WINAPI D3DPERF_SetRegion(D3DCOLOR color, const WCHAR *name);

IDirect3D9 * WINAPI Direct3DCreate9(UINT sdk_version);
#ifndef D3D_DISABLE_9EX
HRESULT WINAPI Direct3DCreate9Ex(UINT sdk_version, IDirect3D9Ex **d3d9ex);
#endif

#ifdef __cplusplus
} /* extern "C" */
#endif /* defined(__cplusplus) */


#endif /* _D3D9_H_ */
