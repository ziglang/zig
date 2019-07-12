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

#ifndef __WINE_D3D_H
#define __WINE_D3D_H

#include <stdlib.h>

#define COM_NO_WINDOWS_H
#include <objbase.h>
#include <d3dtypes.h> /* must precede d3dcaps.h */
#include <d3dcaps.h>

/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(IID_IDirect3D,              0x3BBA0080,0x2421,0x11CF,0xA3,0x1A,0x00,0xAA,0x00,0xB9,0x33,0x56);
DEFINE_GUID(IID_IDirect3D2,             0x6aae1ec1,0x662a,0x11d0,0x88,0x9d,0x00,0xaa,0x00,0xbb,0xb7,0x6a);
DEFINE_GUID(IID_IDirect3D3,             0xbb223240,0xe72b,0x11d0,0xa9,0xb4,0x00,0xaa,0x00,0xc0,0x99,0x3e);
DEFINE_GUID(IID_IDirect3D7,             0xf5049e77,0x4861,0x11d2,0xa4,0x07,0x00,0xa0,0xc9,0x06,0x29,0xa8);

DEFINE_GUID(IID_IDirect3DRampDevice,	0xF2086B20,0x259F,0x11CF,0xA3,0x1A,0x00,0xAA,0x00,0xB9,0x33,0x56);
DEFINE_GUID(IID_IDirect3DRGBDevice,	0xA4665C60,0x2673,0x11CF,0xA3,0x1A,0x00,0xAA,0x00,0xB9,0x33,0x56);
DEFINE_GUID(IID_IDirect3DHALDevice,	0x84E63dE0,0x46AA,0x11CF,0x81,0x6F,0x00,0x00,0xC0,0x20,0x15,0x6E);
DEFINE_GUID(IID_IDirect3DMMXDevice,	0x881949a1,0xd6f3,0x11d0,0x89,0xab,0x00,0xa0,0xc9,0x05,0x41,0x29);
DEFINE_GUID(IID_IDirect3DRefDevice,     0x50936643,0x13e9,0x11d1,0x89,0xaa,0x00,0xa0,0xc9,0x05,0x41,0x29);
DEFINE_GUID(IID_IDirect3DTnLHalDevice,  0xf5049e78,0x4861,0x11d2,0xa4,0x07,0x00,0xa0,0xc9,0x06,0x29,0xa8);
DEFINE_GUID(IID_IDirect3DNullDevice,    0x8767df22,0xbacc,0x11d1,0x89,0x69,0x00,0xa0,0xc9,0x06,0x29,0xa8);

DEFINE_GUID(IID_IDirect3DDevice,	0x64108800,0x957d,0x11D0,0x89,0xAB,0x00,0xA0,0xC9,0x05,0x41,0x29);
DEFINE_GUID(IID_IDirect3DDevice2,	0x93281501,0x8CF8,0x11D0,0x89,0xAB,0x00,0xA0,0xC9,0x05,0x41,0x29);
DEFINE_GUID(IID_IDirect3DDevice3,       0xb0ab3b60,0x33d7,0x11d1,0xa9,0x81,0x00,0xc0,0x4f,0xd7,0xb1,0x74);
DEFINE_GUID(IID_IDirect3DDevice7,       0xf5049e79,0x4861,0x11d2,0xa4,0x07,0x00,0xa0,0xc9,0x06,0x29,0xa8);

DEFINE_GUID(IID_IDirect3DTexture,	0x2CDCD9E0,0x25A0,0x11CF,0xA3,0x1A,0x00,0xAA,0x00,0xB9,0x33,0x56);
DEFINE_GUID(IID_IDirect3DTexture2,	0x93281502,0x8CF8,0x11D0,0x89,0xAB,0x00,0xA0,0xC9,0x05,0x41,0x29);

DEFINE_GUID(IID_IDirect3DLight,		0x4417C142,0x33AD,0x11CF,0x81,0x6F,0x00,0x00,0xC0,0x20,0x15,0x6E);

DEFINE_GUID(IID_IDirect3DMaterial,	0x4417C144,0x33AD,0x11CF,0x81,0x6F,0x00,0x00,0xC0,0x20,0x15,0x6E);
DEFINE_GUID(IID_IDirect3DMaterial2,	0x93281503,0x8CF8,0x11D0,0x89,0xAB,0x00,0xA0,0xC9,0x05,0x41,0x29);
DEFINE_GUID(IID_IDirect3DMaterial3,     0xca9c46f4,0xd3c5,0x11d1,0xb7,0x5a,0x00,0x60,0x08,0x52,0xb3,0x12);

DEFINE_GUID(IID_IDirect3DExecuteBuffer,	0x4417C145,0x33AD,0x11CF,0x81,0x6F,0x00,0x00,0xC0,0x20,0x15,0x6E);

DEFINE_GUID(IID_IDirect3DViewport,	0x4417C146,0x33AD,0x11CF,0x81,0x6F,0x00,0x00,0xC0,0x20,0x15,0x6E);
DEFINE_GUID(IID_IDirect3DViewport2,	0x93281500,0x8CF8,0x11D0,0x89,0xAB,0x00,0xA0,0xC9,0x05,0x41,0x29);
DEFINE_GUID(IID_IDirect3DViewport3,     0xb0ab3b61,0x33d7,0x11d1,0xa9,0x81,0x00,0xc0,0x4f,0xd7,0xb1,0x74);

DEFINE_GUID(IID_IDirect3DVertexBuffer,  0x7a503555,0x4a83,0x11d1,0xa5,0xdb,0x00,0xa0,0xc9,0x03,0x67,0xf8);
DEFINE_GUID(IID_IDirect3DVertexBuffer7, 0xf5049e7d,0x4861,0x11d2,0xa4,0x07,0x00,0xa0,0xc9,0x06,0x29,0xa8);


typedef struct IDirect3D *LPDIRECT3D;
typedef struct IDirect3D2 *LPDIRECT3D2;
typedef struct IDirect3D3 *LPDIRECT3D3;
typedef struct IDirect3D7 *LPDIRECT3D7;

typedef struct IDirect3DLight *LPDIRECT3DLIGHT;

typedef struct IDirect3DDevice *LPDIRECT3DDEVICE;
typedef struct IDirect3DDevice2 *LPDIRECT3DDEVICE2;
typedef struct IDirect3DDevice3 *LPDIRECT3DDEVICE3;
typedef struct IDirect3DDevice7 *LPDIRECT3DDEVICE7;

typedef struct IDirect3DViewport *LPDIRECT3DVIEWPORT;
typedef struct IDirect3DViewport2 *LPDIRECT3DVIEWPORT2;
typedef struct IDirect3DViewport3 *LPDIRECT3DVIEWPORT3;

typedef struct IDirect3DMaterial *LPDIRECT3DMATERIAL;
typedef struct IDirect3DMaterial2 *LPDIRECT3DMATERIAL2;
typedef struct IDirect3DMaterial3 *LPDIRECT3DMATERIAL3;

typedef struct IDirect3DTexture *LPDIRECT3DTEXTURE;
typedef struct IDirect3DTexture2 *LPDIRECT3DTEXTURE2;

typedef struct IDirect3DExecuteBuffer *LPDIRECT3DEXECUTEBUFFER;

typedef struct IDirect3DVertexBuffer *LPDIRECT3DVERTEXBUFFER;
typedef struct IDirect3DVertexBuffer7 *LPDIRECT3DVERTEXBUFFER7;

/* ********************************************************************
   Error Codes
   ******************************************************************** */
#define D3D_OK                          DD_OK
#define D3DERR_BADMAJORVERSION          MAKE_DDHRESULT(700)
#define D3DERR_BADMINORVERSION          MAKE_DDHRESULT(701)
#define D3DERR_INVALID_DEVICE           MAKE_DDHRESULT(705)
#define D3DERR_INITFAILED               MAKE_DDHRESULT(706)
#define D3DERR_DEVICEAGGREGATED         MAKE_DDHRESULT(707)
#define D3DERR_EXECUTE_CREATE_FAILED    MAKE_DDHRESULT(710)
#define D3DERR_EXECUTE_DESTROY_FAILED   MAKE_DDHRESULT(711)
#define D3DERR_EXECUTE_LOCK_FAILED      MAKE_DDHRESULT(712)
#define D3DERR_EXECUTE_UNLOCK_FAILED    MAKE_DDHRESULT(713)
#define D3DERR_EXECUTE_LOCKED           MAKE_DDHRESULT(714)
#define D3DERR_EXECUTE_NOT_LOCKED       MAKE_DDHRESULT(715)
#define D3DERR_EXECUTE_FAILED           MAKE_DDHRESULT(716)
#define D3DERR_EXECUTE_CLIPPED_FAILED   MAKE_DDHRESULT(717)
#define D3DERR_TEXTURE_NO_SUPPORT       MAKE_DDHRESULT(720)
#define D3DERR_TEXTURE_CREATE_FAILED    MAKE_DDHRESULT(721)
#define D3DERR_TEXTURE_DESTROY_FAILED   MAKE_DDHRESULT(722)
#define D3DERR_TEXTURE_LOCK_FAILED      MAKE_DDHRESULT(723)
#define D3DERR_TEXTURE_UNLOCK_FAILED    MAKE_DDHRESULT(724)
#define D3DERR_TEXTURE_LOAD_FAILED      MAKE_DDHRESULT(725)
#define D3DERR_TEXTURE_SWAP_FAILED      MAKE_DDHRESULT(726)
#define D3DERR_TEXTURE_LOCKED           MAKE_DDHRESULT(727)
#define D3DERR_TEXTURE_NOT_LOCKED       MAKE_DDHRESULT(728)
#define D3DERR_TEXTURE_GETSURF_FAILED   MAKE_DDHRESULT(729)
#define D3DERR_MATRIX_CREATE_FAILED     MAKE_DDHRESULT(730)
#define D3DERR_MATRIX_DESTROY_FAILED    MAKE_DDHRESULT(731)
#define D3DERR_MATRIX_SETDATA_FAILED    MAKE_DDHRESULT(732)
#define D3DERR_MATRIX_GETDATA_FAILED    MAKE_DDHRESULT(733)
#define D3DERR_SETVIEWPORTDATA_FAILED   MAKE_DDHRESULT(734)
#define D3DERR_INVALIDCURRENTVIEWPORT   MAKE_DDHRESULT(735)
#define D3DERR_INVALIDPRIMITIVETYPE     MAKE_DDHRESULT(736)
#define D3DERR_INVALIDVERTEXTYPE        MAKE_DDHRESULT(737)
#define D3DERR_TEXTURE_BADSIZE          MAKE_DDHRESULT(738)
#define D3DERR_INVALIDRAMPTEXTURE       MAKE_DDHRESULT(739)
#define D3DERR_MATERIAL_CREATE_FAILED   MAKE_DDHRESULT(740)
#define D3DERR_MATERIAL_DESTROY_FAILED  MAKE_DDHRESULT(741)
#define D3DERR_MATERIAL_SETDATA_FAILED  MAKE_DDHRESULT(742)
#define D3DERR_MATERIAL_GETDATA_FAILED  MAKE_DDHRESULT(743)
#define D3DERR_INVALIDPALETTE           MAKE_DDHRESULT(744)
#define D3DERR_ZBUFF_NEEDS_SYSTEMMEMORY MAKE_DDHRESULT(745)
#define D3DERR_ZBUFF_NEEDS_VIDEOMEMORY  MAKE_DDHRESULT(746)
#define D3DERR_SURFACENOTINVIDMEM       MAKE_DDHRESULT(747)
#define D3DERR_LIGHT_SET_FAILED         MAKE_DDHRESULT(750)
#define D3DERR_LIGHTHASVIEWPORT         MAKE_DDHRESULT(751)
#define D3DERR_LIGHTNOTINTHISVIEWPORT   MAKE_DDHRESULT(752)
#define D3DERR_SCENE_IN_SCENE           MAKE_DDHRESULT(760)
#define D3DERR_SCENE_NOT_IN_SCENE       MAKE_DDHRESULT(761)
#define D3DERR_SCENE_BEGIN_FAILED       MAKE_DDHRESULT(762)
#define D3DERR_SCENE_END_FAILED         MAKE_DDHRESULT(763)
#define D3DERR_INBEGIN                  MAKE_DDHRESULT(770)
#define D3DERR_NOTINBEGIN               MAKE_DDHRESULT(771)
#define D3DERR_NOVIEWPORTS              MAKE_DDHRESULT(772)
#define D3DERR_VIEWPORTDATANOTSET       MAKE_DDHRESULT(773)
#define D3DERR_VIEWPORTHASNODEVICE      MAKE_DDHRESULT(774)
#define D3DERR_NOCURRENTVIEWPORT        MAKE_DDHRESULT(775)
#define D3DERR_INVALIDVERTEXFORMAT	MAKE_DDHRESULT(2048)
#define D3DERR_COLORKEYATTACHED         MAKE_DDHRESULT(2050)
#define D3DERR_VERTEXBUFFEROPTIMIZED	MAKE_DDHRESULT(2060)
#define D3DERR_VBUF_CREATE_FAILED	MAKE_DDHRESULT(2061)
#define D3DERR_VERTEXBUFFERLOCKED	MAKE_DDHRESULT(2062)
#define D3DERR_VERTEXBUFFERUNLOCKFAILED	MAKE_DDHRESULT(2063)
#define D3DERR_ZBUFFER_NOTPRESENT	MAKE_DDHRESULT(2070)
#define D3DERR_STENCILBUFFER_NOTPRESENT	MAKE_DDHRESULT(2071)

#define D3DERR_WRONGTEXTUREFORMAT		MAKE_DDHRESULT(2072)
#define D3DERR_UNSUPPORTEDCOLOROPERATION	MAKE_DDHRESULT(2073)
#define D3DERR_UNSUPPORTEDCOLORARG		MAKE_DDHRESULT(2074)
#define D3DERR_UNSUPPORTEDALPHAOPERATION	MAKE_DDHRESULT(2075)
#define D3DERR_UNSUPPORTEDALPHAARG		MAKE_DDHRESULT(2076)
#define D3DERR_TOOMANYOPERATIONS		MAKE_DDHRESULT(2077)
#define D3DERR_CONFLICTINGTEXTUREFILTER		MAKE_DDHRESULT(2078)
#define D3DERR_UNSUPPORTEDFACTORVALUE		MAKE_DDHRESULT(2079)
#define D3DERR_CONFLICTINGRENDERSTATE		MAKE_DDHRESULT(2081)
#define D3DERR_UNSUPPORTEDTEXTUREFILTER		MAKE_DDHRESULT(2082)
#define D3DERR_TOOMANYPRIMITIVES		MAKE_DDHRESULT(2083)
#define D3DERR_INVALIDMATRIX			MAKE_DDHRESULT(2084)
#define D3DERR_TOOMANYVERTICES			MAKE_DDHRESULT(2085)
#define D3DERR_CONFLICTINGTEXTUREPALETTE	MAKE_DDHRESULT(2086)

#define D3DERR_INVALIDSTATEBLOCK	MAKE_DDHRESULT(2100)
#define D3DERR_INBEGINSTATEBLOCK	MAKE_DDHRESULT(2101)
#define D3DERR_NOTINBEGINSTATEBLOCK	MAKE_DDHRESULT(2102)

/* ********************************************************************
   Enums
   ******************************************************************** */
#define D3DNEXT_NEXT __MSABI_LONG(0x01)
#define D3DNEXT_HEAD __MSABI_LONG(0x02)
#define D3DNEXT_TAIL __MSABI_LONG(0x04)

#define D3DDP_WAIT               __MSABI_LONG(0x00000001)
#define D3DDP_OUTOFORDER         __MSABI_LONG(0x00000002)
#define D3DDP_DONOTCLIP          __MSABI_LONG(0x00000004)
#define D3DDP_DONOTUPDATEEXTENTS __MSABI_LONG(0x00000008)
#define D3DDP_DONOTLIGHT         __MSABI_LONG(0x00000010)

/* ********************************************************************
   Types and structures
   ******************************************************************** */
typedef DWORD D3DVIEWPORTHANDLE, *LPD3DVIEWPORTHANDLE;


/*****************************************************************************
 * IDirect3D interface
 */
#undef INTERFACE
#define INTERFACE IDirect3D
DECLARE_INTERFACE_(IDirect3D,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3D methods ***/
    STDMETHOD(Initialize)(THIS_ REFIID riid) PURE;
    STDMETHOD(EnumDevices)(THIS_ LPD3DENUMDEVICESCALLBACK cb, void *ctx) PURE;
    STDMETHOD(CreateLight)(THIS_ struct IDirect3DLight **light, IUnknown *outer) PURE;
    STDMETHOD(CreateMaterial)(THIS_ struct IDirect3DMaterial **material, IUnknown *outer) PURE;
    STDMETHOD(CreateViewport)(THIS_ struct IDirect3DViewport **viewport, IUnknown *outer) PURE;
    STDMETHOD(FindDevice)(THIS_ D3DFINDDEVICESEARCH *search, D3DFINDDEVICERESULT *result) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3D_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3D_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3D_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3D methods ***/
#define IDirect3D_Initialize(p,a)       (p)->lpVtbl->Initialize(p,a)
#define IDirect3D_EnumDevices(p,a,b)    (p)->lpVtbl->EnumDevices(p,a,b)
#define IDirect3D_CreateLight(p,a,b)    (p)->lpVtbl->CreateLight(p,a,b)
#define IDirect3D_CreateMaterial(p,a,b) (p)->lpVtbl->CreateMaterial(p,a,b)
#define IDirect3D_CreateViewport(p,a,b) (p)->lpVtbl->CreateViewport(p,a,b)
#define IDirect3D_FindDevice(p,a,b)     (p)->lpVtbl->FindDevice(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3D_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3D_AddRef(p)             (p)->AddRef()
#define IDirect3D_Release(p)            (p)->Release()
/*** IDirect3D methods ***/
#define IDirect3D_Initialize(p,a)       (p)->Initialize(a)
#define IDirect3D_EnumDevices(p,a,b)    (p)->EnumDevices(a,b)
#define IDirect3D_CreateLight(p,a,b)    (p)->CreateLight(a,b)
#define IDirect3D_CreateMaterial(p,a,b) (p)->CreateMaterial(a,b)
#define IDirect3D_CreateViewport(p,a,b) (p)->CreateViewport(a,b)
#define IDirect3D_FindDevice(p,a,b)     (p)->FindDevice(a,b)
#endif


/*****************************************************************************
 * IDirect3D2 interface
 */
#define INTERFACE IDirect3D2
DECLARE_INTERFACE_(IDirect3D2,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3D2 methods ***/
    STDMETHOD(EnumDevices)(THIS_ LPD3DENUMDEVICESCALLBACK cb, void *ctx) PURE;
    STDMETHOD(CreateLight)(THIS_ struct IDirect3DLight **light, IUnknown *outer) PURE;
    STDMETHOD(CreateMaterial)(THIS_ struct IDirect3DMaterial2 **material, IUnknown *outer) PURE;
    STDMETHOD(CreateViewport)(THIS_ struct IDirect3DViewport2 **viewport, IUnknown *outer) PURE;
    STDMETHOD(FindDevice)(THIS_ D3DFINDDEVICESEARCH *search, D3DFINDDEVICERESULT *result) PURE;
    STDMETHOD(CreateDevice)(THIS_ REFCLSID rclsid, IDirectDrawSurface *surface,
            struct IDirect3DDevice2 **device) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3D2_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3D2_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3D2_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3D2 methods ***/
#define IDirect3D2_EnumDevices(p,a,b)    (p)->lpVtbl->EnumDevices(p,a,b)
#define IDirect3D2_CreateLight(p,a,b)    (p)->lpVtbl->CreateLight(p,a,b)
#define IDirect3D2_CreateMaterial(p,a,b) (p)->lpVtbl->CreateMaterial(p,a,b)
#define IDirect3D2_CreateViewport(p,a,b) (p)->lpVtbl->CreateViewport(p,a,b)
#define IDirect3D2_FindDevice(p,a,b)     (p)->lpVtbl->FindDevice(p,a,b)
#define IDirect3D2_CreateDevice(p,a,b,c) (p)->lpVtbl->CreateDevice(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirect3D2_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3D2_AddRef(p)             (p)->AddRef()
#define IDirect3D2_Release(p)            (p)->Release()
/*** IDirect3D2 methods ***/
#define IDirect3D2_EnumDevices(p,a,b)    (p)->EnumDevices(a,b)
#define IDirect3D2_CreateLight(p,a,b)    (p)->CreateLight(a,b)
#define IDirect3D2_CreateMaterial(p,a,b) (p)->CreateMaterial(a,b)
#define IDirect3D2_CreateViewport(p,a,b) (p)->CreateViewport(a,b)
#define IDirect3D2_FindDevice(p,a,b)     (p)->FindDevice(a,b)
#define IDirect3D2_CreateDevice(p,a,b,c) (p)->CreateDevice(a,b,c)
#endif


/*****************************************************************************
 * IDirect3D3 interface
 */
#define INTERFACE IDirect3D3
DECLARE_INTERFACE_(IDirect3D3,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3D3 methods ***/
    STDMETHOD(EnumDevices)(THIS_ LPD3DENUMDEVICESCALLBACK cb, void *ctx) PURE;
    STDMETHOD(CreateLight)(THIS_ struct IDirect3DLight **light, IUnknown *outer) PURE;
    STDMETHOD(CreateMaterial)(THIS_ struct IDirect3DMaterial3 **material, IUnknown *outer) PURE;
    STDMETHOD(CreateViewport)(THIS_ struct IDirect3DViewport3 **viewport, IUnknown *outer) PURE;
    STDMETHOD(FindDevice)(THIS_ D3DFINDDEVICESEARCH *search, D3DFINDDEVICERESULT *result) PURE;
    STDMETHOD(CreateDevice)(THIS_ REFCLSID rclsid, IDirectDrawSurface4 *surface,
            struct IDirect3DDevice3 **device, IUnknown *outer) PURE;
    STDMETHOD(CreateVertexBuffer)(THIS_ D3DVERTEXBUFFERDESC *desc, struct IDirect3DVertexBuffer **buffer,
            DWORD flags, IUnknown *outer) PURE;
    STDMETHOD(EnumZBufferFormats)(THIS_ REFCLSID device_iid, LPD3DENUMPIXELFORMATSCALLBACK cb, void *ctx) PURE;
    STDMETHOD(EvictManagedTextures)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3D3_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3D3_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3D3_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3D3 methods ***/
#define IDirect3D3_EnumDevices(p,a,b)            (p)->lpVtbl->EnumDevices(p,a,b)
#define IDirect3D3_CreateLight(p,a,b)            (p)->lpVtbl->CreateLight(p,a,b)
#define IDirect3D3_CreateMaterial(p,a,b)         (p)->lpVtbl->CreateMaterial(p,a,b)
#define IDirect3D3_CreateViewport(p,a,b)         (p)->lpVtbl->CreateViewport(p,a,b)
#define IDirect3D3_FindDevice(p,a,b)             (p)->lpVtbl->FindDevice(p,a,b)
#define IDirect3D3_CreateDevice(p,a,b,c,d)       (p)->lpVtbl->CreateDevice(p,a,b,c,d)
#define IDirect3D3_CreateVertexBuffer(p,a,b,c,d) (p)->lpVtbl->CreateVertexBuffer(p,a,b,c,d)
#define IDirect3D3_EnumZBufferFormats(p,a,b,c)   (p)->lpVtbl->EnumZBufferFormats(p,a,b,c)
#define IDirect3D3_EvictManagedTextures(p)       (p)->lpVtbl->EvictManagedTextures(p)
#else
/*** IUnknown methods ***/
#define IDirect3D3_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3D3_AddRef(p)             (p)->AddRef()
#define IDirect3D3_Release(p)            (p)->Release()
/*** IDirect3D3 methods ***/
#define IDirect3D3_EnumDevices(p,a,b)            (p)->EnumDevices(a,b)
#define IDirect3D3_CreateLight(p,a,b)            (p)->CreateLight(a,b)
#define IDirect3D3_CreateMaterial(p,a,b)         (p)->CreateMaterial(a,b)
#define IDirect3D3_CreateViewport(p,a,b)         (p)->CreateViewport(a,b)
#define IDirect3D3_FindDevice(p,a,b)             (p)->FindDevice(a,b)
#define IDirect3D3_CreateDevice(p,a,b,c,d)       (p)->CreateDevice(a,b,c,d)
#define IDirect3D3_CreateVertexBuffer(p,a,b,c,d) (p)->CreateVertexBuffer(a,b,c,d)
#define IDirect3D3_EnumZBufferFormats(p,a,b,c)   (p)->EnumZBufferFormats(a,b,c)
#define IDirect3D3_EvictManagedTextures(p)       (p)->EvictManagedTextures()
#endif

/*****************************************************************************
 * IDirect3D7 interface
 */
#define INTERFACE IDirect3D7
DECLARE_INTERFACE_(IDirect3D7,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3D7 methods ***/
    STDMETHOD(EnumDevices)(THIS_ LPD3DENUMDEVICESCALLBACK7 cb, void *ctx) PURE;
    STDMETHOD(CreateDevice)(THIS_ REFCLSID rclsid, IDirectDrawSurface7 *surface,
            struct IDirect3DDevice7 **device) PURE;
    STDMETHOD(CreateVertexBuffer)(THIS_ D3DVERTEXBUFFERDESC *desc,
            struct IDirect3DVertexBuffer7 **buffer, DWORD flags) PURE;
    STDMETHOD(EnumZBufferFormats)(THIS_ REFCLSID device_iid, LPD3DENUMPIXELFORMATSCALLBACK cb, void *ctx) PURE;
    STDMETHOD(EvictManagedTextures)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3D7_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3D7_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3D7_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3D3 methods ***/
#define IDirect3D7_EnumDevices(p,a,b)            (p)->lpVtbl->EnumDevices(p,a,b)
#define IDirect3D7_CreateDevice(p,a,b,c)         (p)->lpVtbl->CreateDevice(p,a,b,c)
#define IDirect3D7_CreateVertexBuffer(p,a,b,c)   (p)->lpVtbl->CreateVertexBuffer(p,a,b,c)
#define IDirect3D7_EnumZBufferFormats(p,a,b,c)   (p)->lpVtbl->EnumZBufferFormats(p,a,b,c)
#define IDirect3D7_EvictManagedTextures(p)       (p)->lpVtbl->EvictManagedTextures(p)
#else
/*** IUnknown methods ***/
#define IDirect3D7_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3D7_AddRef(p)             (p)->AddRef()
#define IDirect3D7_Release(p)            (p)->Release()
/*** IDirect3D3 methods ***/
#define IDirect3D7_EnumDevices(p,a,b)            (p)->EnumDevices(a,b)
#define IDirect3D7_CreateDevice(p,a,b,c)         (p)->CreateDevice(a,b,c)
#define IDirect3D7_CreateVertexBuffer(p,a,b,c)   (p)->CreateVertexBuffer(a,b,c)
#define IDirect3D7_EnumZBufferFormats(p,a,b,c)   (p)->EnumZBufferFormats(a,b,c)
#define IDirect3D7_EvictManagedTextures(p)       (p)->EvictManagedTextures()
#endif


/*****************************************************************************
 * IDirect3DLight interface
 */
#define INTERFACE IDirect3DLight
DECLARE_INTERFACE_(IDirect3DLight,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DLight methods ***/
    STDMETHOD(Initialize)(THIS_ IDirect3D *d3d) PURE;
    STDMETHOD(SetLight)(THIS_ D3DLIGHT *data) PURE;
    STDMETHOD(GetLight)(THIS_ D3DLIGHT *data) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DLight_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DLight_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DLight_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DLight methods ***/
#define IDirect3DLight_Initialize(p,a) (p)->lpVtbl->Initialize(p,a)
#define IDirect3DLight_SetLight(p,a)   (p)->lpVtbl->SetLight(p,a)
#define IDirect3DLight_GetLight(p,a)   (p)->lpVtbl->GetLight(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DLight_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DLight_AddRef(p)             (p)->AddRef()
#define IDirect3DLight_Release(p)            (p)->Release()
/*** IDirect3DLight methods ***/
#define IDirect3DLight_Initialize(p,a) (p)->Initialize(a)
#define IDirect3DLight_SetLight(p,a)   (p)->SetLight(a)
#define IDirect3DLight_GetLight(p,a)   (p)->GetLight(a)
#endif


/*****************************************************************************
 * IDirect3DMaterial interface
 */
#define INTERFACE IDirect3DMaterial
DECLARE_INTERFACE_(IDirect3DMaterial,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DMaterial methods ***/
    STDMETHOD(Initialize)(THIS_ IDirect3D *d3d) PURE;
    STDMETHOD(SetMaterial)(THIS_ D3DMATERIAL *data) PURE;
    STDMETHOD(GetMaterial)(THIS_ D3DMATERIAL *data) PURE;
    STDMETHOD(GetHandle)(THIS_ struct IDirect3DDevice *device, D3DMATERIALHANDLE *handle) PURE;
    STDMETHOD(Reserve)(THIS) PURE;
    STDMETHOD(Unreserve)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DMaterial_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DMaterial_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DMaterial_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DMaterial methods ***/
#define IDirect3DMaterial_Initialize(p,a)  (p)->lpVtbl->Initialize(p,a)
#define IDirect3DMaterial_SetMaterial(p,a) (p)->lpVtbl->SetMaterial(p,a)
#define IDirect3DMaterial_GetMaterial(p,a) (p)->lpVtbl->GetMaterial(p,a)
#define IDirect3DMaterial_GetHandle(p,a,b) (p)->lpVtbl->GetHandle(p,a,b)
#define IDirect3DMaterial_Reserve(p)       (p)->lpVtbl->Reserve(p)
#define IDirect3DMaterial_Unreserve(p)     (p)->lpVtbl->Unreserve(p)
#else
/*** IUnknown methods ***/
#define IDirect3DMaterial_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DMaterial_AddRef(p)             (p)->AddRef()
#define IDirect3DMaterial_Release(p)            (p)->Release()
/*** IDirect3DMaterial methods ***/
#define IDirect3DMaterial_Initialize(p,a)  (p)->Initialize(a)
#define IDirect3DMaterial_SetMaterial(p,a) (p)->SetMaterial(a)
#define IDirect3DMaterial_GetMaterial(p,a) (p)->GetMaterial(a)
#define IDirect3DMaterial_GetHandle(p,a,b) (p)->GetHandle(a,b)
#define IDirect3DMaterial_Reserve(p)       (p)->Reserve()
#define IDirect3DMaterial_Unreserve(p)     (p)->Unreserve()
#endif


/*****************************************************************************
 * IDirect3DMaterial2 interface
 */
#define INTERFACE IDirect3DMaterial2
DECLARE_INTERFACE_(IDirect3DMaterial2,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DMaterial2 methods ***/
    STDMETHOD(SetMaterial)(THIS_ D3DMATERIAL *data) PURE;
    STDMETHOD(GetMaterial)(THIS_ D3DMATERIAL *data) PURE;
    STDMETHOD(GetHandle)(THIS_ struct IDirect3DDevice2 *device, D3DMATERIALHANDLE *handle) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DMaterial2_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DMaterial2_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DMaterial2_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DMaterial2 methods ***/
#define IDirect3DMaterial2_SetMaterial(p,a) (p)->lpVtbl->SetMaterial(p,a)
#define IDirect3DMaterial2_GetMaterial(p,a) (p)->lpVtbl->GetMaterial(p,a)
#define IDirect3DMaterial2_GetHandle(p,a,b) (p)->lpVtbl->GetHandle(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DMaterial2_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DMaterial2_AddRef(p)             (p)->AddRef()
#define IDirect3DMaterial2_Release(p)            (p)->Release()
/*** IDirect3DMaterial2 methods ***/
#define IDirect3DMaterial2_SetMaterial(p,a) (p)->SetMaterial(a)
#define IDirect3DMaterial2_GetMaterial(p,a) (p)->GetMaterial(a)
#define IDirect3DMaterial2_GetHandle(p,a,b) (p)->GetHandle(a,b)
#endif


/*****************************************************************************
 * IDirect3DMaterial3 interface
 */
#define INTERFACE IDirect3DMaterial3
DECLARE_INTERFACE_(IDirect3DMaterial3,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DMaterial3 methods ***/
    STDMETHOD(SetMaterial)(THIS_ D3DMATERIAL *data) PURE;
    STDMETHOD(GetMaterial)(THIS_ D3DMATERIAL *data) PURE;
    STDMETHOD(GetHandle)(THIS_ struct IDirect3DDevice3 *device, D3DMATERIALHANDLE *handle) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DMaterial3_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DMaterial3_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DMaterial3_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DMaterial3 methods ***/
#define IDirect3DMaterial3_SetMaterial(p,a) (p)->lpVtbl->SetMaterial(p,a)
#define IDirect3DMaterial3_GetMaterial(p,a) (p)->lpVtbl->GetMaterial(p,a)
#define IDirect3DMaterial3_GetHandle(p,a,b) (p)->lpVtbl->GetHandle(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DMaterial3_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DMaterial3_AddRef(p)             (p)->AddRef()
#define IDirect3DMaterial3_Release(p)            (p)->Release()
/*** IDirect3DMaterial3 methods ***/
#define IDirect3DMaterial3_SetMaterial(p,a) (p)->SetMaterial(a)
#define IDirect3DMaterial3_GetMaterial(p,a) (p)->GetMaterial(a)
#define IDirect3DMaterial3_GetHandle(p,a,b) (p)->GetHandle(a,b)
#endif


/*****************************************************************************
 * IDirect3DTexture interface
 */
#define INTERFACE IDirect3DTexture
DECLARE_INTERFACE_(IDirect3DTexture,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DTexture methods ***/
    STDMETHOD(Initialize)(THIS_ struct IDirect3DDevice *device, IDirectDrawSurface *surface) PURE;
    STDMETHOD(GetHandle)(THIS_ struct IDirect3DDevice *device, D3DTEXTUREHANDLE *handle) PURE;
    STDMETHOD(PaletteChanged)(THIS_ DWORD dwStart, DWORD dwCount) PURE;
    STDMETHOD(Load)(THIS_ IDirect3DTexture *texture) PURE;
    STDMETHOD(Unload)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DTexture_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DTexture_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DTexture_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DTexture methods ***/
#define IDirect3DTexture_Initialize(p,a,b) (p)->lpVtbl->Initialize(p,a,b)
#define IDirect3DTexture_GetHandle(p,a,b) (p)->lpVtbl->GetHandle(p,a,b)
#define IDirect3DTexture_PaletteChanged(p,a,b) (p)->lpVtbl->PaletteChanged(p,a,b)
#define IDirect3DTexture_Load(p,a) (p)->lpVtbl->Load(p,a)
#define IDirect3DTexture_Unload(p) (p)->lpVtbl->Unload(p)
#else
/*** IUnknown methods ***/
#define IDirect3DTexture_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DTexture_AddRef(p)             (p)->AddRef()
#define IDirect3DTexture_Release(p)            (p)->Release()
/*** IDirect3DTexture methods ***/
#define IDirect3DTexture_Initialize(p,a,b) (p)->Initialize(a,b)
#define IDirect3DTexture_GetHandle(p,a,b) (p)->GetHandle(a,b)
#define IDirect3DTexture_PaletteChanged(p,a,b) (p)->PaletteChanged(a,b)
#define IDirect3DTexture_Load(p,a) (p)->Load(a)
#define IDirect3DTexture_Unload(p) (p)->Unload()
#endif


/*****************************************************************************
 * IDirect3DTexture2 interface
 */
#define INTERFACE IDirect3DTexture2
DECLARE_INTERFACE_(IDirect3DTexture2,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DTexture2 methods ***/
    STDMETHOD(GetHandle)(THIS_ struct IDirect3DDevice2 *device, D3DTEXTUREHANDLE *handle) PURE;
    STDMETHOD(PaletteChanged)(THIS_ DWORD dwStart, DWORD dwCount) PURE;
    STDMETHOD(Load)(THIS_ IDirect3DTexture2 *texture) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DTexture2_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DTexture2_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DTexture2_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DTexture2 methods ***/
#define IDirect3DTexture2_GetHandle(p,a,b)      (p)->lpVtbl->GetHandle(p,a,b)
#define IDirect3DTexture2_PaletteChanged(p,a,b) (p)->lpVtbl->PaletteChanged(p,a,b)
#define IDirect3DTexture2_Load(p,a)             (p)->lpVtbl->Load(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DTexture2_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DTexture2_AddRef(p)             (p)->AddRef()
#define IDirect3DTexture2_Release(p)            (p)->Release()
/*** IDirect3DTexture2 methods ***/
#define IDirect3DTexture2_GetHandle(p,a,b)      (p)->GetHandle(a,b)
#define IDirect3DTexture2_PaletteChanged(p,a,b) (p)->PaletteChanged(a,b)
#define IDirect3DTexture2_Load(p,a)             (p)->Load(a)
#endif


/*****************************************************************************
 * IDirect3DViewport interface
 */
#define INTERFACE IDirect3DViewport
DECLARE_INTERFACE_(IDirect3DViewport,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DViewport methods ***/
    STDMETHOD(Initialize)(THIS_ IDirect3D *d3d) PURE;
    STDMETHOD(GetViewport)(THIS_ D3DVIEWPORT *data) PURE;
    STDMETHOD(SetViewport)(THIS_ D3DVIEWPORT *data) PURE;
    STDMETHOD(TransformVertices)(THIS_ DWORD vertex_count, D3DTRANSFORMDATA *data, DWORD flags, DWORD *offscreen) PURE;
    STDMETHOD(LightElements)(THIS_ DWORD element_count, D3DLIGHTDATA *data) PURE;
    STDMETHOD(SetBackground)(THIS_ D3DMATERIALHANDLE hMat) PURE;
    STDMETHOD(GetBackground)(THIS_ D3DMATERIALHANDLE *material, WINBOOL *valid) PURE;
    STDMETHOD(SetBackgroundDepth)(THIS_ IDirectDrawSurface *surface) PURE;
    STDMETHOD(GetBackgroundDepth)(THIS_ IDirectDrawSurface **surface, WINBOOL *valid) PURE;
    STDMETHOD(Clear)(THIS_ DWORD count, D3DRECT *rects, DWORD flags) PURE;
    STDMETHOD(AddLight)(THIS_ IDirect3DLight *light) PURE;
    STDMETHOD(DeleteLight)(THIS_ IDirect3DLight *light) PURE;
    STDMETHOD(NextLight)(THIS_ IDirect3DLight *ref, IDirect3DLight **light, DWORD flags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DViewport_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DViewport_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DViewport_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DViewport methods ***/
#define IDirect3DViewport_Initialize(p,a)              (p)->lpVtbl->Initialize(p,a)
#define IDirect3DViewport_GetViewport(p,a)             (p)->lpVtbl->GetViewport(p,a)
#define IDirect3DViewport_SetViewport(p,a)             (p)->lpVtbl->SetViewport(p,a)
#define IDirect3DViewport_TransformVertices(p,a,b,c,d) (p)->lpVtbl->TransformVertices(p,a,b,c,d)
#define IDirect3DViewport_LightElements(p,a,b)         (p)->lpVtbl->LightElements(p,a,b)
#define IDirect3DViewport_SetBackground(p,a)           (p)->lpVtbl->SetBackground(p,a)
#define IDirect3DViewport_GetBackground(p,a,b)         (p)->lpVtbl->GetBackground(p,a,b)
#define IDirect3DViewport_SetBackgroundDepth(p,a)      (p)->lpVtbl->SetBackgroundDepth(p,a)
#define IDirect3DViewport_GetBackgroundDepth(p,a,b)    (p)->lpVtbl->GetBackgroundDepth(p,a,b)
#define IDirect3DViewport_Clear(p,a,b,c)               (p)->lpVtbl->Clear(p,a,b,c)
#define IDirect3DViewport_AddLight(p,a)                (p)->lpVtbl->AddLight(p,a)
#define IDirect3DViewport_DeleteLight(p,a)             (p)->lpVtbl->DeleteLight(p,a)
#define IDirect3DViewport_NextLight(p,a,b,c)           (p)->lpVtbl->NextLight(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirect3DViewport_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DViewport_AddRef(p)             (p)->AddRef()
#define IDirect3DViewport_Release(p)            (p)->Release()
/*** IDirect3DViewport methods ***/
#define IDirect3DViewport_Initialize(p,a)              (p)->Initialize(a)
#define IDirect3DViewport_GetViewport(p,a)             (p)->GetViewport(a)
#define IDirect3DViewport_SetViewport(p,a)             (p)->SetViewport(a)
#define IDirect3DViewport_TransformVertices(p,a,b,c,d) (p)->TransformVertices(a,b,c,d)
#define IDirect3DViewport_LightElements(p,a,b)         (p)->LightElements(a,b)
#define IDirect3DViewport_SetBackground(p,a)           (p)->SetBackground(a)
#define IDirect3DViewport_GetBackground(p,a,b)         (p)->GetBackground(a,b)
#define IDirect3DViewport_SetBackgroundDepth(p,a)      (p)->SetBackgroundDepth(a)
#define IDirect3DViewport_GetBackgroundDepth(p,a,b)    (p)->GetBackgroundDepth(a,b)
#define IDirect3DViewport_Clear(p,a,b,c)               (p)->Clear(a,b,c)
#define IDirect3DViewport_AddLight(p,a)                (p)->AddLight(a)
#define IDirect3DViewport_DeleteLight(p,a)             (p)->DeleteLight(a)
#define IDirect3DViewport_NextLight(p,a,b,c)           (p)->NextLight(a,b,c)
#endif


/*****************************************************************************
 * IDirect3DViewport2 interface
 */
#define INTERFACE IDirect3DViewport2
DECLARE_INTERFACE_(IDirect3DViewport2,IDirect3DViewport)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DViewport methods ***/
    STDMETHOD(Initialize)(THIS_ IDirect3D *d3d) PURE;
    STDMETHOD(GetViewport)(THIS_ D3DVIEWPORT *data) PURE;
    STDMETHOD(SetViewport)(THIS_ D3DVIEWPORT *data) PURE;
    STDMETHOD(TransformVertices)(THIS_ DWORD vertex_count, D3DTRANSFORMDATA *data, DWORD flags, DWORD *offscreen) PURE;
    STDMETHOD(LightElements)(THIS_ DWORD element_count, D3DLIGHTDATA *data) PURE;
    STDMETHOD(SetBackground)(THIS_ D3DMATERIALHANDLE hMat) PURE;
    STDMETHOD(GetBackground)(THIS_ D3DMATERIALHANDLE *material, WINBOOL *valid) PURE;
    STDMETHOD(SetBackgroundDepth)(THIS_ IDirectDrawSurface *surface) PURE;
    STDMETHOD(GetBackgroundDepth)(THIS_ IDirectDrawSurface **surface, WINBOOL *valid) PURE;
    STDMETHOD(Clear)(THIS_ DWORD count, D3DRECT *rects, DWORD flags) PURE;
    STDMETHOD(AddLight)(THIS_ IDirect3DLight *light) PURE;
    STDMETHOD(DeleteLight)(THIS_ IDirect3DLight *light) PURE;
    STDMETHOD(NextLight)(THIS_ IDirect3DLight *ref, IDirect3DLight **light, DWORD flags) PURE;
    /*** IDirect3DViewport2 methods ***/
    STDMETHOD(GetViewport2)(THIS_ D3DVIEWPORT2 *data) PURE;
    STDMETHOD(SetViewport2)(THIS_ D3DVIEWPORT2 *data) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DViewport2_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DViewport2_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DViewport2_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3Viewport methods ***/
#define IDirect3DViewport2_Initialize(p,a)              (p)->lpVtbl->Initialize(p,a)
#define IDirect3DViewport2_GetViewport(p,a)             (p)->lpVtbl->GetViewport(p,a)
#define IDirect3DViewport2_SetViewport(p,a)             (p)->lpVtbl->SetViewport(p,a)
#define IDirect3DViewport2_TransformVertices(p,a,b,c,d) (p)->lpVtbl->TransformVertices(p,a,b,c,d)
#define IDirect3DViewport2_LightElements(p,a,b)         (p)->lpVtbl->LightElements(p,a,b)
#define IDirect3DViewport2_SetBackground(p,a)           (p)->lpVtbl->SetBackground(p,a)
#define IDirect3DViewport2_GetBackground(p,a,b)         (p)->lpVtbl->GetBackground(p,a,b)
#define IDirect3DViewport2_SetBackgroundDepth(p,a)      (p)->lpVtbl->SetBackgroundDepth(p,a)
#define IDirect3DViewport2_GetBackgroundDepth(p,a,b)    (p)->lpVtbl->GetBackgroundDepth(p,a,b)
#define IDirect3DViewport2_Clear(p,a,b,c)               (p)->lpVtbl->Clear(p,a,b,c)
#define IDirect3DViewport2_AddLight(p,a)                (p)->lpVtbl->AddLight(p,a)
#define IDirect3DViewport2_DeleteLight(p,a)             (p)->lpVtbl->DeleteLight(p,a)
#define IDirect3DViewport2_NextLight(p,a,b,c)           (p)->lpVtbl->NextLight(p,a,b,c)
/*** IDirect3DViewport2 methods ***/
#define IDirect3DViewport2_GetViewport2(p,a) (p)->lpVtbl->GetViewport2(p,a)
#define IDirect3DViewport2_SetViewport2(p,a) (p)->lpVtbl->SetViewport2(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DViewport2_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DViewport2_AddRef(p)             (p)->AddRef()
#define IDirect3DViewport2_Release(p)            (p)->Release()
/*** IDirect3Viewport methods ***/
#define IDirect3DViewport2_Initialize(p,a)              (p)->Initialize(a)
#define IDirect3DViewport2_GetViewport(p,a)             (p)->GetViewport(a)
#define IDirect3DViewport2_SetViewport(p,a)             (p)->SetViewport(a)
#define IDirect3DViewport2_TransformVertices(p,a,b,c,d) (p)->TransformVertices(a,b,c,d)
#define IDirect3DViewport2_LightElements(p,a,b)         (p)->LightElements(a,b)
#define IDirect3DViewport2_SetBackground(p,a)           (p)->SetBackground(a)
#define IDirect3DViewport2_GetBackground(p,a,b)         (p)->GetBackground(a,b)
#define IDirect3DViewport2_SetBackgroundDepth(p,a)      (p)->SetBackgroundDepth(a)
#define IDirect3DViewport2_GetBackgroundDepth(p,a,b)    (p)->GetBackgroundDepth(a,b)
#define IDirect3DViewport2_Clear(p,a,b,c)               (p)->Clear(a,b,c)
#define IDirect3DViewport2_AddLight(p,a)                (p)->AddLight(a)
#define IDirect3DViewport2_DeleteLight(p,a)             (p)->DeleteLight(a)
#define IDirect3DViewport2_NextLight(p,a,b,c)           (p)->NextLight(a,b,c)
/*** IDirect3DViewport2 methods ***/
#define IDirect3DViewport2_GetViewport2(p,a) (p)->GetViewport2(a)
#define IDirect3DViewport2_SetViewport2(p,a) (p)->SetViewport2(a)
#endif

/*****************************************************************************
 * IDirect3DViewport3 interface
 */
#define INTERFACE IDirect3DViewport3
DECLARE_INTERFACE_(IDirect3DViewport3,IDirect3DViewport2)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DViewport methods ***/
    STDMETHOD(Initialize)(THIS_ IDirect3D *d3d) PURE;
    STDMETHOD(GetViewport)(THIS_ D3DVIEWPORT *data) PURE;
    STDMETHOD(SetViewport)(THIS_ D3DVIEWPORT *data) PURE;
    STDMETHOD(TransformVertices)(THIS_ DWORD vertex_count, D3DTRANSFORMDATA *data, DWORD flags, DWORD *offscreen) PURE;
    STDMETHOD(LightElements)(THIS_ DWORD element_count, D3DLIGHTDATA *data) PURE;
    STDMETHOD(SetBackground)(THIS_ D3DMATERIALHANDLE hMat) PURE;
    STDMETHOD(GetBackground)(THIS_ D3DMATERIALHANDLE *material, WINBOOL *valid) PURE;
    STDMETHOD(SetBackgroundDepth)(THIS_ IDirectDrawSurface *surface) PURE;
    STDMETHOD(GetBackgroundDepth)(THIS_ IDirectDrawSurface **surface, WINBOOL *valid) PURE;
    STDMETHOD(Clear)(THIS_ DWORD count, D3DRECT *rects, DWORD flags) PURE;
    STDMETHOD(AddLight)(THIS_ IDirect3DLight *light) PURE;
    STDMETHOD(DeleteLight)(THIS_ IDirect3DLight *light) PURE;
    STDMETHOD(NextLight)(THIS_ IDirect3DLight *ref, IDirect3DLight **light, DWORD flags) PURE;
    /*** IDirect3DViewport2 methods ***/
    STDMETHOD(GetViewport2)(THIS_ D3DVIEWPORT2 *data) PURE;
    STDMETHOD(SetViewport2)(THIS_ D3DVIEWPORT2 *data) PURE;
    /*** IDirect3DViewport3 methods ***/
    STDMETHOD(SetBackgroundDepth2)(THIS_ IDirectDrawSurface4 *surface) PURE;
    STDMETHOD(GetBackgroundDepth2)(THIS_ IDirectDrawSurface4 **surface, WINBOOL *valid) PURE;
    STDMETHOD(Clear2)(THIS_ DWORD count, D3DRECT *rects, DWORD flags, DWORD color, D3DVALUE z, DWORD stencil) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DViewport3_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DViewport3_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DViewport3_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3Viewport methods ***/
#define IDirect3DViewport3_Initialize(p,a)              (p)->lpVtbl->Initialize(p,a)
#define IDirect3DViewport3_GetViewport(p,a)             (p)->lpVtbl->GetViewport(p,a)
#define IDirect3DViewport3_SetViewport(p,a)             (p)->lpVtbl->SetViewport(p,a)
#define IDirect3DViewport3_TransformVertices(p,a,b,c,d) (p)->lpVtbl->TransformVertices(p,a,b,c,d)
#define IDirect3DViewport3_LightElements(p,a,b)         (p)->lpVtbl->LightElements(p,a,b)
#define IDirect3DViewport3_SetBackground(p,a)           (p)->lpVtbl->SetBackground(p,a)
#define IDirect3DViewport3_GetBackground(p,a,b)         (p)->lpVtbl->GetBackground(p,a,b)
#define IDirect3DViewport3_SetBackgroundDepth(p,a)      (p)->lpVtbl->SetBackgroundDepth(p,a)
#define IDirect3DViewport3_GetBackgroundDepth(p,a,b)    (p)->lpVtbl->GetBackgroundDepth(p,a,b)
#define IDirect3DViewport3_Clear(p,a,b,c)               (p)->lpVtbl->Clear(p,a,b,c)
#define IDirect3DViewport3_AddLight(p,a)                (p)->lpVtbl->AddLight(p,a)
#define IDirect3DViewport3_DeleteLight(p,a)             (p)->lpVtbl->DeleteLight(p,a)
#define IDirect3DViewport3_NextLight(p,a,b,c)           (p)->lpVtbl->NextLight(p,a,b,c)
/*** IDirect3DViewport2 methods ***/
#define IDirect3DViewport3_GetViewport2(p,a) (p)->lpVtbl->GetViewport2(p,a)
#define IDirect3DViewport3_SetViewport2(p,a) (p)->lpVtbl->SetViewport2(p,a)
/*** IDirect3DViewport3 methods ***/
#define IDirect3DViewport3_SetBackgroundDepth2(p,a)   (p)->lpVtbl->SetBackgroundDepth2(p,a)
#define IDirect3DViewport3_GetBackgroundDepth2(p,a,b) (p)->lpVtbl->GetBackgroundDepth2(p,a,b)
#define IDirect3DViewport3_Clear2(p,a,b,c,d,e,f)      (p)->lpVtbl->Clear2(p,a,b,c,d,e,f)
#else
/*** IUnknown methods ***/
#define IDirect3DViewport3_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DViewport3_AddRef(p)             (p)->AddRef()
#define IDirect3DViewport3_Release(p)            (p)->Release()
/*** IDirect3Viewport methods ***/
#define IDirect3DViewport3_Initialize(p,a)              (p)->Initialize(a)
#define IDirect3DViewport3_GetViewport(p,a)             (p)->GetViewport(a)
#define IDirect3DViewport3_SetViewport(p,a)             (p)->SetViewport(a)
#define IDirect3DViewport3_TransformVertices(p,a,b,c,d) (p)->TransformVertices(a,b,c,d)
#define IDirect3DViewport3_LightElements(p,a,b)         (p)->LightElements(a,b)
#define IDirect3DViewport3_SetBackground(p,a)           (p)->SetBackground(a)
#define IDirect3DViewport3_GetBackground(p,a,b)         (p)->GetBackground(a,b)
#define IDirect3DViewport3_SetBackgroundDepth(p,a)      (p)->SetBackgroundDepth(a)
#define IDirect3DViewport3_GetBackgroundDepth(p,a,b)    (p)->GetBackgroundDepth(a,b)
#define IDirect3DViewport3_Clear(p,a,b,c)               (p)->Clear(a,b,c)
#define IDirect3DViewport3_AddLight(p,a)                (p)->AddLight(a)
#define IDirect3DViewport3_DeleteLight(p,a)             (p)->DeleteLight(a)
#define IDirect3DViewport3_NextLight(p,a,b,c)           (p)->NextLight(a,b,c)
/*** IDirect3DViewport2 methods ***/
#define IDirect3DViewport3_GetViewport2(p,a) (p)->GetViewport2(a)
#define IDirect3DViewport3_SetViewport2(p,a) (p)->SetViewport2(a)
/*** IDirect3DViewport3 methods ***/
#define IDirect3DViewport3_SetBackgroundDepth2(p,a)   (p)->SetBackgroundDepth2(a)
#define IDirect3DViewport3_GetBackgroundDepth2(p,a,b) (p)->GetBackgroundDepth2(a,b)
#define IDirect3DViewport3_Clear2(p,a,b,c,d,e,f)      (p)->Clear2(a,b,c,d,e,f)
#endif



/*****************************************************************************
 * IDirect3DExecuteBuffer interface
 */
#define INTERFACE IDirect3DExecuteBuffer
DECLARE_INTERFACE_(IDirect3DExecuteBuffer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DExecuteBuffer methods ***/
    STDMETHOD(Initialize)(THIS_ struct IDirect3DDevice *device, D3DEXECUTEBUFFERDESC *desc) PURE;
    STDMETHOD(Lock)(THIS_ D3DEXECUTEBUFFERDESC *desc) PURE;
    STDMETHOD(Unlock)(THIS) PURE;
    STDMETHOD(SetExecuteData)(THIS_ D3DEXECUTEDATA *data) PURE;
    STDMETHOD(GetExecuteData)(THIS_ D3DEXECUTEDATA *data) PURE;
    STDMETHOD(Validate)(THIS_ DWORD *offset, LPD3DVALIDATECALLBACK cb, void *ctx, DWORD reserved) PURE;
    STDMETHOD(Optimize)(THIS_ DWORD dwDummy) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DExecuteBuffer_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DExecuteBuffer_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DExecuteBuffer_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DExecuteBuffer methods ***/
#define IDirect3DExecuteBuffer_Initialize(p,a,b)   (p)->lpVtbl->Initialize(p,a,b)
#define IDirect3DExecuteBuffer_Lock(p,a)           (p)->lpVtbl->Lock(p,a)
#define IDirect3DExecuteBuffer_Unlock(p)           (p)->lpVtbl->Unlock(p)
#define IDirect3DExecuteBuffer_SetExecuteData(p,a) (p)->lpVtbl->SetExecuteData(p,a)
#define IDirect3DExecuteBuffer_GetExecuteData(p,a) (p)->lpVtbl->GetExecuteData(p,a)
#define IDirect3DExecuteBuffer_Validate(p,a,b,c,d) (p)->lpVtbl->Validate(p,a,b,c,d)
#define IDirect3DExecuteBuffer_Optimize(p,a)       (p)->lpVtbl->Optimize(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DExecuteBuffer_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DExecuteBuffer_AddRef(p)             (p)->AddRef()
#define IDirect3DExecuteBuffer_Release(p)            (p)->Release()
/*** IDirect3DExecuteBuffer methods ***/
#define IDirect3DExecuteBuffer_Initialize(p,a,b)   (p)->Initialize(a,b)
#define IDirect3DExecuteBuffer_Lock(p,a)           (p)->Lock(a)
#define IDirect3DExecuteBuffer_Unlock(p)           (p)->Unlock()
#define IDirect3DExecuteBuffer_SetExecuteData(p,a) (p)->SetExecuteData(a)
#define IDirect3DExecuteBuffer_GetExecuteData(p,a) (p)->GetExecuteData(a)
#define IDirect3DExecuteBuffer_Validate(p,a,b,c,d) (p)->Validate(a,b,c,d)
#define IDirect3DExecuteBuffer_Optimize(p,a)       (p)->Optimize(a)
#endif


/*****************************************************************************
 * IDirect3DDevice interface
 */
#define INTERFACE IDirect3DDevice
DECLARE_INTERFACE_(IDirect3DDevice,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DDevice methods ***/
    STDMETHOD(Initialize)(THIS_ IDirect3D *d3d, GUID *guid, D3DDEVICEDESC *desc) PURE;
    STDMETHOD(GetCaps)(THIS_ D3DDEVICEDESC *hal_desc, D3DDEVICEDESC *hel_desc) PURE;
    STDMETHOD(SwapTextureHandles)(THIS_ IDirect3DTexture *tex1, IDirect3DTexture *tex2) PURE;
    STDMETHOD(CreateExecuteBuffer)(THIS_ D3DEXECUTEBUFFERDESC *desc,
            IDirect3DExecuteBuffer **buffer, IUnknown *outer) PURE;
    STDMETHOD(GetStats)(THIS_ D3DSTATS *stats) PURE;
    STDMETHOD(Execute)(THIS_ IDirect3DExecuteBuffer *buffer, IDirect3DViewport *viewport,
            DWORD flags) PURE;
    STDMETHOD(AddViewport)(THIS_ IDirect3DViewport *viewport) PURE;
    STDMETHOD(DeleteViewport)(THIS_ IDirect3DViewport *viewport) PURE;
    STDMETHOD(NextViewport)(THIS_ IDirect3DViewport *ref,
            IDirect3DViewport **viewport, DWORD flags) PURE;
    STDMETHOD(Pick)(THIS_ IDirect3DExecuteBuffer *buffer, IDirect3DViewport *viewport,
            DWORD flags, D3DRECT *rect) PURE;
    STDMETHOD(GetPickRecords)(THIS_ DWORD *count, D3DPICKRECORD *records) PURE;
    STDMETHOD(EnumTextureFormats)(THIS_ LPD3DENUMTEXTUREFORMATSCALLBACK cb, void *ctx) PURE;
    STDMETHOD(CreateMatrix)(THIS_ D3DMATRIXHANDLE *matrix) PURE;
    STDMETHOD(SetMatrix)(THIS_ D3DMATRIXHANDLE handle, D3DMATRIX *matrix) PURE;
    STDMETHOD(GetMatrix)(THIS_ D3DMATRIXHANDLE handle, D3DMATRIX *matrix) PURE;
    STDMETHOD(DeleteMatrix)(THIS_ D3DMATRIXHANDLE D3DMatHandle) PURE;
    STDMETHOD(BeginScene)(THIS) PURE;
    STDMETHOD(EndScene)(THIS) PURE;
    STDMETHOD(GetDirect3D)(THIS_ IDirect3D **d3d) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DDevice_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DDevice_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DDevice_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DDevice methods ***/
#define IDirect3DDevice_Initialize(p,a,b,c)          (p)->lpVtbl->Initialize(p,a,b,c)
#define IDirect3DDevice_GetCaps(p,a,b)               (p)->lpVtbl->GetCaps(p,a,b)
#define IDirect3DDevice_SwapTextureHandles(p,a,b)    (p)->lpVtbl->SwapTextureHandles(p,a,b)
#define IDirect3DDevice_CreateExecuteBuffer(p,a,b,c) (p)->lpVtbl->CreateExecuteBuffer(p,a,b,c)
#define IDirect3DDevice_GetStats(p,a)                (p)->lpVtbl->GetStats(p,a)
#define IDirect3DDevice_Execute(p,a,b,c)             (p)->lpVtbl->Execute(p,a,b,c)
#define IDirect3DDevice_AddViewport(p,a)             (p)->lpVtbl->AddViewport(p,a)
#define IDirect3DDevice_DeleteViewport(p,a)          (p)->lpVtbl->DeleteViewport(p,a)
#define IDirect3DDevice_NextViewport(p,a,b,c)        (p)->lpVtbl->NextViewport(p,a,b,c)
#define IDirect3DDevice_Pick(p,a,b,c,d)              (p)->lpVtbl->Pick(p,a,b,c,d)
#define IDirect3DDevice_GetPickRecords(p,a,b)        (p)->lpVtbl->GetPickRecords(p,a,b)
#define IDirect3DDevice_EnumTextureFormats(p,a,b)    (p)->lpVtbl->EnumTextureFormats(p,a,b)
#define IDirect3DDevice_CreateMatrix(p,a)            (p)->lpVtbl->CreateMatrix(p,a)
#define IDirect3DDevice_SetMatrix(p,a,b)             (p)->lpVtbl->SetMatrix(p,a,b)
#define IDirect3DDevice_GetMatrix(p,a,b)             (p)->lpVtbl->GetMatrix(p,a,b)
#define IDirect3DDevice_DeleteMatrix(p,a)            (p)->lpVtbl->DeleteMatrix(p,a)
#define IDirect3DDevice_BeginScene(p)                (p)->lpVtbl->BeginScene(p)
#define IDirect3DDevice_EndScene(p)                  (p)->lpVtbl->EndScene(p)
#define IDirect3DDevice_GetDirect3D(p,a)             (p)->lpVtbl->GetDirect3D(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DDevice_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DDevice_AddRef(p)             (p)->AddRef()
#define IDirect3DDevice_Release(p)            (p)->Release()
/*** IDirect3DDevice methods ***/
#define IDirect3DDevice_Initialize(p,a,b,c)          (p)->Initialize(a,b,c)
#define IDirect3DDevice_GetCaps(p,a,b)               (p)->GetCaps(a,b)
#define IDirect3DDevice_SwapTextureHandles(p,a,b)    (p)->SwapTextureHandles(a,b)
#define IDirect3DDevice_CreateExecuteBuffer(p,a,b,c) (p)->CreateExecuteBuffer(a,b,c)
#define IDirect3DDevice_GetStats(p,a)                (p)->GetStats(a)
#define IDirect3DDevice_Execute(p,a,b,c)             (p)->Execute(a,b,c)
#define IDirect3DDevice_AddViewport(p,a)             (p)->AddViewport(a)
#define IDirect3DDevice_DeleteViewport(p,a)          (p)->DeleteViewport(a)
#define IDirect3DDevice_NextViewport(p,a,b,c)        (p)->NextViewport(a,b,c)
#define IDirect3DDevice_Pick(p,a,b,c,d)              (p)->Pick(a,b,c,d)
#define IDirect3DDevice_GetPickRecords(p,a,b)        (p)->GetPickRecords(a,b)
#define IDirect3DDevice_EnumTextureFormats(p,a,b)    (p)->EnumTextureFormats(a,b)
#define IDirect3DDevice_CreateMatrix(p,a)            (p)->CreateMatrix(a)
#define IDirect3DDevice_SetMatrix(p,a,b)             (p)->SetMatrix(a,b)
#define IDirect3DDevice_GetMatrix(p,a,b)             (p)->GetMatrix(a,b)
#define IDirect3DDevice_DeleteMatrix(p,a)            (p)->DeleteMatrix(a)
#define IDirect3DDevice_BeginScene(p)                (p)->BeginScene()
#define IDirect3DDevice_EndScene(p)                  (p)->EndScene()
#define IDirect3DDevice_GetDirect3D(p,a)             (p)->GetDirect3D(a)
#endif


/*****************************************************************************
 * IDirect3DDevice2 interface
 */
#define INTERFACE IDirect3DDevice2
DECLARE_INTERFACE_(IDirect3DDevice2,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DDevice2 methods ***/
    STDMETHOD(GetCaps)(THIS_ D3DDEVICEDESC *hal_desc, D3DDEVICEDESC *hel_desc) PURE;
    STDMETHOD(SwapTextureHandles)(THIS_ IDirect3DTexture2 *tex1, IDirect3DTexture2 *tex2) PURE;
    STDMETHOD(GetStats)(THIS_ D3DSTATS *stats) PURE;
    STDMETHOD(AddViewport)(THIS_ IDirect3DViewport2 *viewport) PURE;
    STDMETHOD(DeleteViewport)(THIS_ IDirect3DViewport2 *viewport) PURE;
    STDMETHOD(NextViewport)(THIS_ IDirect3DViewport2 *ref,
            IDirect3DViewport2 **viewport, DWORD flags) PURE;
    STDMETHOD(EnumTextureFormats)(THIS_ LPD3DENUMTEXTUREFORMATSCALLBACK cb, void *ctx) PURE;
    STDMETHOD(BeginScene)(THIS) PURE;
    STDMETHOD(EndScene)(THIS) PURE;
    STDMETHOD(GetDirect3D)(THIS_ IDirect3D2 **d3d) PURE;
    /*** DrawPrimitive API ***/
    STDMETHOD(SetCurrentViewport)(THIS_ IDirect3DViewport2 *viewport) PURE;
    STDMETHOD(GetCurrentViewport)(THIS_ IDirect3DViewport2 **viewport) PURE;
    STDMETHOD(SetRenderTarget)(THIS_ IDirectDrawSurface *surface, DWORD flags) PURE;
    STDMETHOD(GetRenderTarget)(THIS_ IDirectDrawSurface **surface) PURE;
    STDMETHOD(Begin)(THIS_ D3DPRIMITIVETYPE d3dpt,D3DVERTEXTYPE dwVertexTypeDesc,DWORD dwFlags) PURE;
    STDMETHOD(BeginIndexed)(THIS_ D3DPRIMITIVETYPE primitive_type, D3DVERTEXTYPE vertex_type,
            void *vertices, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(Vertex)(THIS_ void *vertex) PURE;
    STDMETHOD(Index)(THIS_ WORD wVertexIndex) PURE;
    STDMETHOD(End)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(GetRenderState)(THIS_ D3DRENDERSTATETYPE dwRenderStateType, LPDWORD lpdwRenderState) PURE;
    STDMETHOD(SetRenderState)(THIS_ D3DRENDERSTATETYPE dwRenderStateType, DWORD dwRenderState) PURE;
    STDMETHOD(GetLightState)(THIS_ D3DLIGHTSTATETYPE dwLightStateType, LPDWORD lpdwLightState) PURE;
    STDMETHOD(SetLightState)(THIS_ D3DLIGHTSTATETYPE dwLightStateType, DWORD dwLightState) PURE;
    STDMETHOD(SetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(GetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(MultiplyTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(DrawPrimitive)(THIS_ D3DPRIMITIVETYPE primitive_type, D3DVERTEXTYPE vertex_type,
            void *vertices, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(DrawIndexedPrimitive)(THIS_ D3DPRIMITIVETYPE primitive_type, D3DVERTEXTYPE vertex_type,
            void *vertices, DWORD vertex_count, WORD *indices, DWORD index_count, DWORD flags) PURE;
    STDMETHOD(SetClipStatus)(THIS_ D3DCLIPSTATUS *clip_status) PURE;
    STDMETHOD(GetClipStatus)(THIS_ D3DCLIPSTATUS *clip_status) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DDevice2_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DDevice2_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DDevice2_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DDevice2 methods ***/
#define IDirect3DDevice2_GetCaps(p,a,b)                        (p)->lpVtbl->GetCaps(p,a,b)
#define IDirect3DDevice2_SwapTextureHandles(p,a,b)             (p)->lpVtbl->SwapTextureHandles(p,a,b)
#define IDirect3DDevice2_GetStats(p,a)                         (p)->lpVtbl->GetStats(p,a)
#define IDirect3DDevice2_AddViewport(p,a)                      (p)->lpVtbl->AddViewport(p,a)
#define IDirect3DDevice2_DeleteViewport(p,a)                   (p)->lpVtbl->DeleteViewport(p,a)
#define IDirect3DDevice2_NextViewport(p,a,b,c)                 (p)->lpVtbl->NextViewport(p,a,b,c)
#define IDirect3DDevice2_EnumTextureFormats(p,a,b)             (p)->lpVtbl->EnumTextureFormats(p,a,b)
#define IDirect3DDevice2_BeginScene(p)                         (p)->lpVtbl->BeginScene(p)
#define IDirect3DDevice2_EndScene(p)                           (p)->lpVtbl->EndScene(p)
#define IDirect3DDevice2_GetDirect3D(p,a)                      (p)->lpVtbl->GetDirect3D(p,a)
#define IDirect3DDevice2_SetCurrentViewport(p,a)               (p)->lpVtbl->SetCurrentViewport(p,a)
#define IDirect3DDevice2_GetCurrentViewport(p,a)               (p)->lpVtbl->GetCurrentViewport(p,a)
#define IDirect3DDevice2_SetRenderTarget(p,a,b)                (p)->lpVtbl->SetRenderTarget(p,a,b)
#define IDirect3DDevice2_GetRenderTarget(p,a)                  (p)->lpVtbl->GetRenderTarget(p,a)
#define IDirect3DDevice2_Begin(p,a,b,c)                        (p)->lpVtbl->Begin(p,a,b,c)
#define IDirect3DDevice2_BeginIndexed(p,a,b,c,d,e)             (p)->lpVtbl->BeginIndexed(p,a,b,c,d,e)
#define IDirect3DDevice2_Vertex(p,a)                           (p)->lpVtbl->Vertex(p,a)
#define IDirect3DDevice2_Index(p,a)                            (p)->lpVtbl->Index(p,a)
#define IDirect3DDevice2_End(p,a)                              (p)->lpVtbl->End(p,a)
#define IDirect3DDevice2_GetRenderState(p,a,b)                 (p)->lpVtbl->GetRenderState(p,a,b)
#define IDirect3DDevice2_SetRenderState(p,a,b)                 (p)->lpVtbl->SetRenderState(p,a,b)
#define IDirect3DDevice2_GetLightState(p,a,b)                  (p)->lpVtbl->GetLightState(p,a,b)
#define IDirect3DDevice2_SetLightState(p,a,b)                  (p)->lpVtbl->SetLightState(p,a,b)
#define IDirect3DDevice2_SetTransform(p,a,b)                   (p)->lpVtbl->SetTransform(p,a,b)
#define IDirect3DDevice2_GetTransform(p,a,b)                   (p)->lpVtbl->GetTransform(p,a,b)
#define IDirect3DDevice2_MultiplyTransform(p,a,b)              (p)->lpVtbl->MultiplyTransform(p,a,b)
#define IDirect3DDevice2_DrawPrimitive(p,a,b,c,d,e)            (p)->lpVtbl->DrawPrimitive(p,a,b,c,d,e)
#define IDirect3DDevice2_DrawIndexedPrimitive(p,a,b,c,d,e,f,g) (p)->lpVtbl->DrawIndexedPrimitive(p,a,b,c,d,e,f,g)
#define IDirect3DDevice2_SetClipStatus(p,a)                    (p)->lpVtbl->SetClipStatus(p,a)
#define IDirect3DDevice2_GetClipStatus(p,a)                    (p)->lpVtbl->GetClipStatus(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DDevice2_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DDevice2_AddRef(p)             (p)->AddRef()
#define IDirect3DDevice2_Release(p)            (p)->Release()
/*** IDirect3DDevice2 methods ***/
#define IDirect3DDevice2_GetCaps(p,a,b)                        (p)->GetCaps(a,b)
#define IDirect3DDevice2_SwapTextureHandles(p,a,b)             (p)->SwapTextureHandles(a,b)
#define IDirect3DDevice2_GetStats(p,a)                         (p)->GetStats(a)
#define IDirect3DDevice2_AddViewport(p,a)                      (p)->AddViewport(a)
#define IDirect3DDevice2_DeleteViewport(p,a)                   (p)->DeleteViewport(a)
#define IDirect3DDevice2_NextViewport(p,a,b,c)                 (p)->NextViewport(a,b,c)
#define IDirect3DDevice2_EnumTextureFormats(p,a,b)             (p)->EnumTextureFormats(a,b)
#define IDirect3DDevice2_BeginScene(p)                         (p)->BeginScene()
#define IDirect3DDevice2_EndScene(p)                           (p)->EndScene()
#define IDirect3DDevice2_GetDirect3D(p,a)                      (p)->GetDirect3D(a)
#define IDirect3DDevice2_SetCurrentViewport(p,a)               (p)->SetCurrentViewport(a)
#define IDirect3DDevice2_GetCurrentViewport(p,a)               (p)->GetCurrentViewport(a)
#define IDirect3DDevice2_SetRenderTarget(p,a,b)                (p)->SetRenderTarget(a,b)
#define IDirect3DDevice2_GetRenderTarget(p,a)                  (p)->GetRenderTarget(a)
#define IDirect3DDevice2_Begin(p,a,b,c)                        (p)->Begin(a,b,c)
#define IDirect3DDevice2_BeginIndexed(p,a,b,c,d,e)             (p)->BeginIndexed(a,b,c,d,e)
#define IDirect3DDevice2_Vertex(p,a)                           (p)->Vertex(a)
#define IDirect3DDevice2_Index(p,a)                            (p)->Index(a)
#define IDirect3DDevice2_End(p,a)                              (p)->End(a)
#define IDirect3DDevice2_GetRenderState(p,a,b)                 (p)->GetRenderState(a,b)
#define IDirect3DDevice2_SetRenderState(p,a,b)                 (p)->SetRenderState(a,b)
#define IDirect3DDevice2_GetLightState(p,a,b)                  (p)->GetLightState(a,b)
#define IDirect3DDevice2_SetLightState(p,a,b)                  (p)->SetLightState(a,b)
#define IDirect3DDevice2_SetTransform(p,a,b)                   (p)->SetTransform(a,b)
#define IDirect3DDevice2_GetTransform(p,a,b)                   (p)->GetTransform(a,b)
#define IDirect3DDevice2_MultiplyTransform(p,a,b)              (p)->MultiplyTransform(a,b)
#define IDirect3DDevice2_DrawPrimitive(p,a,b,c,d,e)            (p)->DrawPrimitive(a,b,c,d,e)
#define IDirect3DDevice2_DrawIndexedPrimitive(p,a,b,c,d,e,f,g) (p)->DrawIndexedPrimitive(a,b,c,d,e,f,g)
#define IDirect3DDevice2_SetClipStatus(p,a)                    (p)->SetClipStatus(a)
#define IDirect3DDevice2_GetClipStatus(p,a)                    (p)->GetClipStatus(a)
#endif

/*****************************************************************************
 * IDirect3DDevice3 interface
 */
#define INTERFACE IDirect3DDevice3
DECLARE_INTERFACE_(IDirect3DDevice3,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DDevice3 methods ***/
    STDMETHOD(GetCaps)(THIS_ D3DDEVICEDESC *hal_desc, D3DDEVICEDESC *hel_desc) PURE;
    STDMETHOD(GetStats)(THIS_ D3DSTATS *stats) PURE;
    STDMETHOD(AddViewport)(THIS_ IDirect3DViewport3 *viewport) PURE;
    STDMETHOD(DeleteViewport)(THIS_ IDirect3DViewport3 *viewport) PURE;
    STDMETHOD(NextViewport)(THIS_ IDirect3DViewport3 *ref,
            IDirect3DViewport3 **viewport, DWORD flags) PURE;
    STDMETHOD(EnumTextureFormats)(THIS_ LPD3DENUMPIXELFORMATSCALLBACK cb, void *ctx) PURE;
    STDMETHOD(BeginScene)(THIS) PURE;
    STDMETHOD(EndScene)(THIS) PURE;
    STDMETHOD(GetDirect3D)(THIS_ IDirect3D3 **d3d) PURE;
    /*** DrawPrimitive API ***/
    STDMETHOD(SetCurrentViewport)(THIS_ IDirect3DViewport3 *viewport) PURE;
    STDMETHOD(GetCurrentViewport)(THIS_ IDirect3DViewport3 **viewport) PURE;
    STDMETHOD(SetRenderTarget)(THIS_ IDirectDrawSurface4 *surface, DWORD flags) PURE;
    STDMETHOD(GetRenderTarget)(THIS_ IDirectDrawSurface4 **surface) PURE;
    STDMETHOD(Begin)(THIS_ D3DPRIMITIVETYPE d3dptPrimitiveType,DWORD dwVertexTypeDesc, DWORD dwFlags) PURE;
    STDMETHOD(BeginIndexed)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD fvf,
            void *vertices, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(Vertex)(THIS_ void *vertex) PURE;
    STDMETHOD(Index)(THIS_ WORD wVertexIndex) PURE;
    STDMETHOD(End)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(GetRenderState)(THIS_ D3DRENDERSTATETYPE dwRenderStateType, LPDWORD lpdwRenderState) PURE;
    STDMETHOD(SetRenderState)(THIS_ D3DRENDERSTATETYPE dwRenderStateType, DWORD dwRenderState) PURE;
    STDMETHOD(GetLightState)(THIS_ D3DLIGHTSTATETYPE dwLightStateType, LPDWORD lpdwLightState) PURE;
    STDMETHOD(SetLightState)(THIS_ D3DLIGHTSTATETYPE dwLightStateType, DWORD dwLightState) PURE;
    STDMETHOD(SetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(GetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(MultiplyTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(DrawPrimitive)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD vertex_type,
            void *vertices, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(DrawIndexedPrimitive)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD fvf,
            void *vertices, DWORD vertex_count, WORD *indices, DWORD index_count, DWORD flags) PURE;
    STDMETHOD(SetClipStatus)(THIS_ D3DCLIPSTATUS *clip_status) PURE;
    STDMETHOD(GetClipStatus)(THIS_ D3DCLIPSTATUS *clip_status) PURE;
    STDMETHOD(DrawPrimitiveStrided)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD fvf,
            D3DDRAWPRIMITIVESTRIDEDDATA *strided_data, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(DrawIndexedPrimitiveStrided)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD fvf,
            D3DDRAWPRIMITIVESTRIDEDDATA *strided_data, DWORD vertex_count, WORD *indices, DWORD index_count,
            DWORD flags) PURE;
    STDMETHOD(DrawPrimitiveVB)(THIS_ D3DPRIMITIVETYPE primitive_type, struct IDirect3DVertexBuffer *vb,
            DWORD start_vertex, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(DrawIndexedPrimitiveVB)(THIS_ D3DPRIMITIVETYPE primitive_type, struct IDirect3DVertexBuffer *vb,
            WORD *indices, DWORD index_count, DWORD flags) PURE;
    STDMETHOD(ComputeSphereVisibility)(THIS_ D3DVECTOR *centers, D3DVALUE *radii, DWORD sphere_count,
            DWORD flags, DWORD *ret) PURE;
    STDMETHOD(GetTexture)(THIS_ DWORD stage, IDirect3DTexture2 **texture) PURE;
    STDMETHOD(SetTexture)(THIS_ DWORD stage, IDirect3DTexture2 *texture) PURE;
    STDMETHOD(GetTextureStageState)(THIS_ DWORD dwStage,D3DTEXTURESTAGESTATETYPE d3dTexStageStateType,LPDWORD lpdwState) PURE;
    STDMETHOD(SetTextureStageState)(THIS_ DWORD dwStage,D3DTEXTURESTAGESTATETYPE d3dTexStageStateType,DWORD dwState) PURE;
    STDMETHOD(ValidateDevice)(THIS_ LPDWORD lpdwPasses) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DDevice3_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DDevice3_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DDevice3_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DDevice3 methods ***/
#define IDirect3DDevice3_GetCaps(p,a,b)                        (p)->lpVtbl->GetCaps(p,a,b)
#define IDirect3DDevice3_GetStats(p,a)                         (p)->lpVtbl->GetStats(p,a)
#define IDirect3DDevice3_AddViewport(p,a)                      (p)->lpVtbl->AddViewport(p,a)
#define IDirect3DDevice3_DeleteViewport(p,a)                   (p)->lpVtbl->DeleteViewport(p,a)
#define IDirect3DDevice3_NextViewport(p,a,b,c)                 (p)->lpVtbl->NextViewport(p,a,b,c)
#define IDirect3DDevice3_EnumTextureFormats(p,a,b)             (p)->lpVtbl->EnumTextureFormats(p,a,b)
#define IDirect3DDevice3_BeginScene(p)                         (p)->lpVtbl->BeginScene(p)
#define IDirect3DDevice3_EndScene(p)                           (p)->lpVtbl->EndScene(p)
#define IDirect3DDevice3_GetDirect3D(p,a)                      (p)->lpVtbl->GetDirect3D(p,a)
#define IDirect3DDevice3_SetCurrentViewport(p,a)               (p)->lpVtbl->SetCurrentViewport(p,a)
#define IDirect3DDevice3_GetCurrentViewport(p,a)               (p)->lpVtbl->GetCurrentViewport(p,a)
#define IDirect3DDevice3_SetRenderTarget(p,a,b)                (p)->lpVtbl->SetRenderTarget(p,a,b)
#define IDirect3DDevice3_GetRenderTarget(p,a)                  (p)->lpVtbl->GetRenderTarget(p,a)
#define IDirect3DDevice3_Begin(p,a,b,c)                        (p)->lpVtbl->Begin(p,a,b,c)
#define IDirect3DDevice3_BeginIndexed(p,a,b,c,d,e)             (p)->lpVtbl->BeginIndexed(p,a,b,c,d,e)
#define IDirect3DDevice3_Vertex(p,a)                           (p)->lpVtbl->Vertex(p,a)
#define IDirect3DDevice3_Index(p,a)                            (p)->lpVtbl->Index(p,a)
#define IDirect3DDevice3_End(p,a)                              (p)->lpVtbl->End(p,a)
#define IDirect3DDevice3_GetRenderState(p,a,b)                 (p)->lpVtbl->GetRenderState(p,a,b)
#define IDirect3DDevice3_SetRenderState(p,a,b)                 (p)->lpVtbl->SetRenderState(p,a,b)
#define IDirect3DDevice3_GetLightState(p,a,b)                  (p)->lpVtbl->GetLightState(p,a,b)
#define IDirect3DDevice3_SetLightState(p,a,b)                  (p)->lpVtbl->SetLightState(p,a,b)
#define IDirect3DDevice3_SetTransform(p,a,b)                   (p)->lpVtbl->SetTransform(p,a,b)
#define IDirect3DDevice3_GetTransform(p,a,b)                   (p)->lpVtbl->GetTransform(p,a,b)
#define IDirect3DDevice3_MultiplyTransform(p,a,b)              (p)->lpVtbl->MultiplyTransform(p,a,b)
#define IDirect3DDevice3_DrawPrimitive(p,a,b,c,d,e)            (p)->lpVtbl->DrawPrimitive(p,a,b,c,d,e)
#define IDirect3DDevice3_DrawIndexedPrimitive(p,a,b,c,d,e,f,g) (p)->lpVtbl->DrawIndexedPrimitive(p,a,b,c,d,e,f,g)
#define IDirect3DDevice3_SetClipStatus(p,a)                    (p)->lpVtbl->SetClipStatus(p,a)
#define IDirect3DDevice3_GetClipStatus(p,a)                    (p)->lpVtbl->GetClipStatus(p,a)
#define IDirect3DDevice3_DrawPrimitiveStrided(p,a,b,c,d,e)     (p)->lpVtbl->DrawPrimitiveStrided(p,a,b,c,d,e)
#define IDirect3DDevice3_DrawIndexedPrimitiveStrided(p,a,b,c,d,e,f,g) (p)->lpVtbl->DrawIndexedPrimitiveStrided(p,a,b,c,d,e,f,g)
#define IDirect3DDevice3_DrawPrimitiveVB(p,a,b,c,d,e)          (p)->lpVtbl->DrawPrimitiveVB(p,a,b,c,d,e)
#define IDirect3DDevice3_DrawIndexedPrimitiveVB(p,a,b,c,d,e)   (p)->lpVtbl->DrawIndexedPrimitiveVB(p,a,b,c,d,e)
#define IDirect3DDevice3_ComputeSphereVisibility(p,a,b,c,d,e)  (p)->lpVtbl->ComputeSphereVisibility(p,a,b,c,d,e)
#define IDirect3DDevice3_GetTexture(p,a,b)                     (p)->lpVtbl->GetTexture(p,a,b)
#define IDirect3DDevice3_SetTexture(p,a,b)                     (p)->lpVtbl->SetTexture(p,a,b)
#define IDirect3DDevice3_GetTextureStageState(p,a,b,c)         (p)->lpVtbl->GetTextureStageState(p,a,b,c)
#define IDirect3DDevice3_SetTextureStageState(p,a,b,c)         (p)->lpVtbl->SetTextureStageState(p,a,b,c)
#define IDirect3DDevice3_ValidateDevice(p,a)                   (p)->lpVtbl->ValidateDevice(p,a)
#else
/*** IUnknown methods ***/
#define IDirect3DDevice3_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DDevice3_AddRef(p)             (p)->AddRef()
#define IDirect3DDevice3_Release(p)            (p)->Release()
/*** IDirect3DDevice3 methods ***/
#define IDirect3DDevice3_GetCaps(p,a,b)                        (p)->GetCaps(a,b)
#define IDirect3DDevice3_GetStats(p,a)                         (p)->GetStats(a)
#define IDirect3DDevice3_AddViewport(p,a)                      (p)->AddViewport(a)
#define IDirect3DDevice3_DeleteViewport(p,a)                   (p)->DeleteViewport(a)
#define IDirect3DDevice3_NextViewport(p,a,b,c)                 (p)->NextViewport(a,b,c)
#define IDirect3DDevice3_EnumTextureFormats(p,a,b)             (p)->EnumTextureFormats(a,b)
#define IDirect3DDevice3_BeginScene(p)                         (p)->BeginScene()
#define IDirect3DDevice3_EndScene(p)                           (p)->EndScene()
#define IDirect3DDevice3_GetDirect3D(p,a)                      (p)->GetDirect3D(a)
#define IDirect3DDevice3_SetCurrentViewport(p,a)               (p)->SetCurrentViewport(a)
#define IDirect3DDevice3_GetCurrentViewport(p,a)               (p)->GetCurrentViewport(a)
#define IDirect3DDevice3_SetRenderTarget(p,a,b)                (p)->SetRenderTarget(a,b)
#define IDirect3DDevice3_GetRenderTarget(p,a)                  (p)->GetRenderTarget(a)
#define IDirect3DDevice3_Begin(p,a,b,c)                        (p)->Begin(a,b,c)
#define IDirect3DDevice3_BeginIndexed(p,a,b,c,d,e)             (p)->BeginIndexed(a,b,c,d,e)
#define IDirect3DDevice3_Vertex(p,a)                           (p)->Vertex(a)
#define IDirect3DDevice3_Index(p,a)                            (p)->Index(a)
#define IDirect3DDevice3_End(p,a)                              (p)->End(a)
#define IDirect3DDevice3_GetRenderState(p,a,b)                 (p)->GetRenderState(a,b)
#define IDirect3DDevice3_SetRenderState(p,a,b)                 (p)->SetRenderState(a,b)
#define IDirect3DDevice3_GetLightState(p,a,b)                  (p)->GetLightState(a,b)
#define IDirect3DDevice3_SetLightState(p,a,b)                  (p)->SetLightState(a,b)
#define IDirect3DDevice3_SetTransform(p,a,b)                   (p)->SetTransform(a,b)
#define IDirect3DDevice3_GetTransform(p,a,b)                   (p)->GetTransform(a,b)
#define IDirect3DDevice3_MultiplyTransform(p,a,b)              (p)->MultiplyTransform(a,b)
#define IDirect3DDevice3_DrawPrimitive(p,a,b,c,d,e)            (p)->DrawPrimitive(a,b,c,d,e)
#define IDirect3DDevice3_DrawIndexedPrimitive(p,a,b,c,d,e,f,g) (p)->DrawIndexedPrimitive(a,b,c,d,e,f,g)
#define IDirect3DDevice3_SetClipStatus(p,a)                    (p)->SetClipStatus(a)
#define IDirect3DDevice3_GetClipStatus(p,a)                    (p)->GetClipStatus(a)
#define IDirect3DDevice3_DrawPrimitiveStrided(p,a,b,c,d,e)     (p)->DrawPrimitiveStrided(a,b,c,d,e)
#define IDirect3DDevice3_DrawIndexedPrimitiveStrided(p,a,b,c,d,e,f,g) (p)->DrawIndexedPrimitiveStrided(a,b,c,d,e,f,g)
#define IDirect3DDevice3_DrawPrimitiveVB(p,a,b,c,d,e)          (p)->DrawPrimitiveVB(a,b,c,d,e)
#define IDirect3DDevice3_DrawIndexedPrimitiveVB(p,a,b,c,d,e)   (p)->DrawIndexedPrimitiveVB(a,b,c,d,e)
#define IDirect3DDevice3_ComputeSphereVisibility(p,a,b,c,d,e)  (p)->ComputeSphereVisibility(a,b,c,d,e)
#define IDirect3DDevice3_GetTexture(p,a,b)                     (p)->GetTexture(a,b)
#define IDirect3DDevice3_SetTexture(p,a,b)                     (p)->SetTexture(a,b)
#define IDirect3DDevice3_GetTextureStageState(p,a,b,c)         (p)->GetTextureStageState(a,b,c)
#define IDirect3DDevice3_SetTextureStageState(p,a,b,c)         (p)->SetTextureStageState(a,b,c)
#define IDirect3DDevice3_ValidateDevice(p,a)                   (p)->ValidateDevice(a)
#endif

/*****************************************************************************
 * IDirect3DDevice7 interface
 */
#define INTERFACE IDirect3DDevice7
DECLARE_INTERFACE_(IDirect3DDevice7,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DDevice7 methods ***/
    STDMETHOD(GetCaps)(THIS_ D3DDEVICEDESC7 *desc) PURE;
    STDMETHOD(EnumTextureFormats)(THIS_ LPD3DENUMPIXELFORMATSCALLBACK cb, void *ctx) PURE;
    STDMETHOD(BeginScene)(THIS) PURE;
    STDMETHOD(EndScene)(THIS) PURE;
    STDMETHOD(GetDirect3D)(THIS_ IDirect3D7 **d3d) PURE;
    STDMETHOD(SetRenderTarget)(THIS_ IDirectDrawSurface7 *surface, DWORD flags) PURE;
    STDMETHOD(GetRenderTarget)(THIS_ IDirectDrawSurface7 **surface) PURE;
    STDMETHOD(Clear)(THIS_ DWORD count, D3DRECT *rects, DWORD flags, D3DCOLOR color, D3DVALUE z, DWORD stencil) PURE;
    STDMETHOD(SetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(GetTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(SetViewport)(THIS_ D3DVIEWPORT7 *data) PURE;
    STDMETHOD(MultiplyTransform)(THIS_ D3DTRANSFORMSTATETYPE state, D3DMATRIX *matrix) PURE;
    STDMETHOD(GetViewport)(THIS_ D3DVIEWPORT7 *data) PURE;
    STDMETHOD(SetMaterial)(THIS_ D3DMATERIAL7 *data) PURE;
    STDMETHOD(GetMaterial)(THIS_ D3DMATERIAL7 *data) PURE;
    STDMETHOD(SetLight)(THIS_ DWORD idx, D3DLIGHT7 *data) PURE;
    STDMETHOD(GetLight)(THIS_ DWORD idx, D3DLIGHT7 *data) PURE;
    STDMETHOD(SetRenderState)(THIS_ D3DRENDERSTATETYPE dwRenderStateType, DWORD dwRenderState) PURE;
    STDMETHOD(GetRenderState)(THIS_ D3DRENDERSTATETYPE dwRenderStateType, LPDWORD lpdwRenderState) PURE;
    STDMETHOD(BeginStateBlock)(THIS) PURE;
    STDMETHOD(EndStateBlock)(THIS_ LPDWORD lpdwBlockHandle) PURE;
    STDMETHOD(PreLoad)(THIS_ IDirectDrawSurface7 *surface) PURE;
    STDMETHOD(DrawPrimitive)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD fvf,
            void *vertices, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(DrawIndexedPrimitive)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD fvf,
            void *vertices, DWORD vertex_count, WORD *indices, DWORD index_count, DWORD flags) PURE;
    STDMETHOD(SetClipStatus)(THIS_ D3DCLIPSTATUS *clip_status) PURE;
    STDMETHOD(GetClipStatus)(THIS_ D3DCLIPSTATUS *clip_status) PURE;
    STDMETHOD(DrawPrimitiveStrided)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD fvf,
            D3DDRAWPRIMITIVESTRIDEDDATA *strided_data, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(DrawIndexedPrimitiveStrided)(THIS_ D3DPRIMITIVETYPE primitive_type, DWORD fvf,
            D3DDRAWPRIMITIVESTRIDEDDATA *strided_data, DWORD vertex_count, WORD *indices, DWORD index_count,
            DWORD flags) PURE;
    STDMETHOD(DrawPrimitiveVB)(THIS_ D3DPRIMITIVETYPE primitive_type, struct IDirect3DVertexBuffer7 *vb,
            DWORD start_vertex, DWORD vertex_count, DWORD flags) PURE;
    STDMETHOD(DrawIndexedPrimitiveVB)(THIS_ D3DPRIMITIVETYPE primitive_type, struct IDirect3DVertexBuffer7 *vb,
            DWORD start_vertex, DWORD vertex_count, WORD *indices, DWORD index_count, DWORD flags) PURE;
    STDMETHOD(ComputeSphereVisibility)(THIS_ D3DVECTOR *centers, D3DVALUE *radii, DWORD sphere_count,
            DWORD flags, DWORD *ret) PURE;
    STDMETHOD(GetTexture)(THIS_ DWORD stage, IDirectDrawSurface7 **surface) PURE;
    STDMETHOD(SetTexture)(THIS_ DWORD stage, IDirectDrawSurface7 *surface) PURE;
    STDMETHOD(GetTextureStageState)(THIS_ DWORD dwStage,D3DTEXTURESTAGESTATETYPE d3dTexStageStateType,LPDWORD lpdwState) PURE;
    STDMETHOD(SetTextureStageState)(THIS_ DWORD dwStage,D3DTEXTURESTAGESTATETYPE d3dTexStageStateType,DWORD dwState) PURE;
    STDMETHOD(ValidateDevice)(THIS_ LPDWORD lpdwPasses) PURE;
    STDMETHOD(ApplyStateBlock)(THIS_ DWORD dwBlockHandle) PURE;
    STDMETHOD(CaptureStateBlock)(THIS_ DWORD dwBlockHandle) PURE;
    STDMETHOD(DeleteStateBlock)(THIS_ DWORD dwBlockHandle) PURE;
    STDMETHOD(CreateStateBlock)(THIS_ D3DSTATEBLOCKTYPE d3dsbType,LPDWORD lpdwBlockHandle) PURE;
    STDMETHOD(Load)(THIS_ IDirectDrawSurface7 *dst_surface, POINT *dst_point,
            IDirectDrawSurface7 *src_surface, RECT *src_rect, DWORD flags) PURE;
    STDMETHOD(LightEnable)(THIS_ DWORD dwLightIndex,WINBOOL bEnable) PURE;
    STDMETHOD(GetLightEnable)(THIS_ DWORD dwLightIndex,WINBOOL *pbEnable) PURE;
    STDMETHOD(SetClipPlane)(THIS_ DWORD dwIndex,D3DVALUE *pPlaneEquation) PURE;
    STDMETHOD(GetClipPlane)(THIS_ DWORD dwIndex,D3DVALUE *pPlaneEquation) PURE;
    STDMETHOD(GetInfo)(THIS_ DWORD info_id, void *info, DWORD info_size) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DDevice7_QueryInterface(p,a,b)                        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DDevice7_AddRef(p)                                    (p)->lpVtbl->AddRef(p)
#define IDirect3DDevice7_Release(p)                                   (p)->lpVtbl->Release(p)
/*** IDirect3DDevice7 methods ***/
#define IDirect3DDevice7_GetCaps(p,a)                                 (p)->lpVtbl->GetCaps(p,a)
#define IDirect3DDevice7_EnumTextureFormats(p,a,b)                    (p)->lpVtbl->EnumTextureFormats(p,a,b)
#define IDirect3DDevice7_BeginScene(p)                                (p)->lpVtbl->BeginScene(p)
#define IDirect3DDevice7_EndScene(p)                                  (p)->lpVtbl->EndScene(p)
#define IDirect3DDevice7_GetDirect3D(p,a)                             (p)->lpVtbl->GetDirect3D(p,a)
#define IDirect3DDevice7_SetRenderTarget(p,a,b)                       (p)->lpVtbl->SetRenderTarget(p,a,b)
#define IDirect3DDevice7_GetRenderTarget(p,a)                         (p)->lpVtbl->GetRenderTarget(p,a)
#define IDirect3DDevice7_Clear(p,a,b,c,d,e,f)                         (p)->lpVtbl->Clear(p,a,b,c,d,e,f)
#define IDirect3DDevice7_SetTransform(p,a,b)                          (p)->lpVtbl->SetTransform(p,a,b)
#define IDirect3DDevice7_GetTransform(p,a,b)                          (p)->lpVtbl->GetTransform(p,a,b)
#define IDirect3DDevice7_SetViewport(p,a)                             (p)->lpVtbl->SetViewport(p,a)
#define IDirect3DDevice7_MultiplyTransform(p,a,b)                     (p)->lpVtbl->MultiplyTransform(p,a,b)
#define IDirect3DDevice7_GetViewport(p,a)                             (p)->lpVtbl->GetViewport(p,a)
#define IDirect3DDevice7_SetMaterial(p,a)                             (p)->lpVtbl->SetMaterial(p,a)
#define IDirect3DDevice7_GetMaterial(p,a)                             (p)->lpVtbl->GetMaterial(p,a)
#define IDirect3DDevice7_SetLight(p,a,b)                              (p)->lpVtbl->SetLight(p,a,b)
#define IDirect3DDevice7_GetLight(p,a,b)                              (p)->lpVtbl->GetLight(p,a,b)
#define IDirect3DDevice7_SetRenderState(p,a,b)                        (p)->lpVtbl->SetRenderState(p,a,b)
#define IDirect3DDevice7_GetRenderState(p,a,b)                        (p)->lpVtbl->GetRenderState(p,a,b)
#define IDirect3DDevice7_BeginStateBlock(p)                           (p)->lpVtbl->BeginStateBlock(p)
#define IDirect3DDevice7_EndStateBlock(p,a)                           (p)->lpVtbl->EndStateBlock(p,a)
#define IDirect3DDevice7_PreLoad(p,a)                                 (p)->lpVtbl->PreLoad(p,a)
#define IDirect3DDevice7_DrawPrimitive(p,a,b,c,d,e)                   (p)->lpVtbl->DrawPrimitive(p,a,b,c,d,e)
#define IDirect3DDevice7_DrawIndexedPrimitive(p,a,b,c,d,e,f,g)        (p)->lpVtbl->DrawIndexedPrimitive(p,a,b,c,d,e,f,g)
#define IDirect3DDevice7_SetClipStatus(p,a)                           (p)->lpVtbl->SetClipStatus(p,a)
#define IDirect3DDevice7_GetClipStatus(p,a)                           (p)->lpVtbl->GetClipStatus(p,a)
#define IDirect3DDevice7_DrawPrimitiveStrided(p,a,b,c,d,e)            (p)->lpVtbl->DrawPrimitiveStrided(p,a,b,c,d,e)
#define IDirect3DDevice7_DrawIndexedPrimitiveStrided(p,a,b,c,d,e,f,g) (p)->lpVtbl->DrawIndexedPrimitiveStrided(p,a,b,c,d,e,f,g)
#define IDirect3DDevice7_DrawPrimitiveVB(p,a,b,c,d,e)                 (p)->lpVtbl->DrawPrimitiveVB(p,a,b,c,d,e)
#define IDirect3DDevice7_DrawIndexedPrimitiveVB(p,a,b,c,d,e,f,g)      (p)->lpVtbl->DrawIndexedPrimitiveVB(p,a,b,c,d,e,f,g)
#define IDirect3DDevice7_ComputeSphereVisibility(p,a,b,c,d,e)         (p)->lpVtbl->ComputeSphereVisibility(p,a,b,c,d,e)
#define IDirect3DDevice7_GetTexture(p,a,b)                            (p)->lpVtbl->GetTexture(p,a,b)
#define IDirect3DDevice7_SetTexture(p,a,b)                            (p)->lpVtbl->SetTexture(p,a,b)
#define IDirect3DDevice7_GetTextureStageState(p,a,b,c)                (p)->lpVtbl->GetTextureStageState(p,a,b,c)
#define IDirect3DDevice7_SetTextureStageState(p,a,b,c)                (p)->lpVtbl->SetTextureStageState(p,a,b,c)
#define IDirect3DDevice7_ValidateDevice(p,a)                          (p)->lpVtbl->ValidateDevice(p,a)
#define IDirect3DDevice7_ApplyStateBlock(p,a)                         (p)->lpVtbl->ApplyStateBlock(p,a)
#define IDirect3DDevice7_CaptureStateBlock(p,a)                       (p)->lpVtbl->CaptureStateBlock(p,a)
#define IDirect3DDevice7_DeleteStateBlock(p,a)                        (p)->lpVtbl->DeleteStateBlock(p,a)
#define IDirect3DDevice7_CreateStateBlock(p,a,b)                      (p)->lpVtbl->CreateStateBlock(p,a,b)
#define IDirect3DDevice7_Load(p,a,b,c,d,e)                            (p)->lpVtbl->Load(p,a,b,c,d,e)
#define IDirect3DDevice7_LightEnable(p,a,b)                           (p)->lpVtbl->LightEnable(p,a,b)
#define IDirect3DDevice7_GetLightEnable(p,a,b)                        (p)->lpVtbl->GetLightEnable(p,a,b)
#define IDirect3DDevice7_SetClipPlane(p,a,b)                          (p)->lpVtbl->SetClipPlane(p,a,b)
#define IDirect3DDevice7_GetClipPlane(p,a,b)                          (p)->lpVtbl->GetClipPlane(p,a,b)
#define IDirect3DDevice7_GetInfo(p,a,b,c)                             (p)->lpVtbl->GetInfo(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirect3DDevice7_QueryInterface(p,a,b)                        (p)->QueryInterface(a,b)
#define IDirect3DDevice7_AddRef(p)                                    (p)->AddRef()
#define IDirect3DDevice7_Release(p)                                   (p)->Release()
/*** IDirect3DDevice7 methods ***/
#define IDirect3DDevice7_GetCaps(p,a)                                 (p)->GetCaps(a)
#define IDirect3DDevice7_EnumTextureFormats(p,a,b)                    (p)->EnumTextureFormats(a,b)
#define IDirect3DDevice7_BeginScene(p)                                (p)->BeginScene()
#define IDirect3DDevice7_EndScene(p)                                  (p)->EndScene()
#define IDirect3DDevice7_GetDirect3D(p,a)                             (p)->GetDirect3D(a)
#define IDirect3DDevice7_SetRenderTarget(p,a,b)                       (p)->SetRenderTarget(a,b)
#define IDirect3DDevice7_GetRenderTarget(p,a)                         (p)->GetRenderTarget(a)
#define IDirect3DDevice7_Clear(p,a,b,c,d,e,f)                         (p)->Clear(a,b,c,d,e,f)
#define IDirect3DDevice7_SetTransform(p,a,b)                          (p)->SetTransform(a,b)
#define IDirect3DDevice7_GetTransform(p,a,b)                          (p)->GetTransform(a,b)
#define IDirect3DDevice7_SetViewport(p,a)                             (p)->SetViewport(a)
#define IDirect3DDevice7_MultiplyTransform(p,a,b)                     (p)->MultiplyTransform(a,b)
#define IDirect3DDevice7_GetViewport(p,a)                             (p)->GetViewport(a)
#define IDirect3DDevice7_SetMaterial(p,a)                             (p)->SetMaterial(a)
#define IDirect3DDevice7_GetMaterial(p,a)                             (p)->GetMaterial(a)
#define IDirect3DDevice7_SetLight(p,a,b)                              (p)->SetLight(a,b)
#define IDirect3DDevice7_GetLight(p,a,b)                              (p)->GetLight(a,b)
#define IDirect3DDevice7_SetRenderState(p,a,b)                        (p)->SetRenderState(a,b)
#define IDirect3DDevice7_GetRenderState(p,a,b)                        (p)->GetRenderState(a,b)
#define IDirect3DDevice7_BeginStateBlock(p)                           (p)->BeginStateBlock()
#define IDirect3DDevice7_EndStateBlock(p,a)                           (p)->EndStateBlock(a)
#define IDirect3DDevice7_PreLoad(p,a)                                 (p)->PreLoad(a)
#define IDirect3DDevice7_DrawPrimitive(p,a,b,c,d,e)                   (p)->DrawPrimitive(a,b,c,d,e)
#define IDirect3DDevice7_DrawIndexedPrimitive(p,a,b,c,d,e,f,g)        (p)->DrawIndexedPrimitive(a,b,c,d,e,f,g)
#define IDirect3DDevice7_SetClipStatus(p,a)                           (p)->SetClipStatus(a)
#define IDirect3DDevice7_GetClipStatus(p,a)                           (p)->GetClipStatus(a)
#define IDirect3DDevice7_DrawPrimitiveStrided(p,a,b,c,d,e)            (p)->DrawPrimitiveStrided(a,b,c,d,e)
#define IDirect3DDevice7_DrawIndexedPrimitiveStrided(p,a,b,c,d,e,f,g) (p)->DrawIndexedPrimitiveStrided(a,b,c,d,e,f,g)
#define IDirect3DDevice7_DrawPrimitiveVB(p,a,b,c,d,e)                 (p)->DrawPrimitiveVB(a,b,c,d,e)
#define IDirect3DDevice7_DrawIndexedPrimitiveVB(p,a,b,c,d,e,f,g)      (p)->DrawIndexedPrimitiveVB(a,b,c,d,e,f,g)
#define IDirect3DDevice7_ComputeSphereVisibility(p,a,b,c,d,e)         (p)->ComputeSphereVisibility(a,b,c,d,e)
#define IDirect3DDevice7_GetTexture(p,a,b)                            (p)->GetTexture(a,b)
#define IDirect3DDevice7_SetTexture(p,a,b)                            (p)->SetTexture(a,b)
#define IDirect3DDevice7_GetTextureStageState(p,a,b,c)                (p)->GetTextureStageState(a,b,c)
#define IDirect3DDevice7_SetTextureStageState(p,a,b,c)                (p)->SetTextureStageState(a,b,c)
#define IDirect3DDevice7_ValidateDevice(p,a)                          (p)->ValidateDevice(a)
#define IDirect3DDevice7_ApplyStateBlock(p,a)                         (p)->ApplyStateBlock(a)
#define IDirect3DDevice7_CaptureStateBlock(p,a)                       (p)->CaptureStateBlock(a)
#define IDirect3DDevice7_DeleteStateBlock(p,a)                        (p)->DeleteStateBlock(a)
#define IDirect3DDevice7_CreateStateBlock(p,a,b)                      (p)->CreateStateBlock(a,b)
#define IDirect3DDevice7_Load(p,a,b,c,d,e)                            (p)->Load(a,b,c,d,e)
#define IDirect3DDevice7_LightEnable(p,a,b)                           (p)->LightEnable(a,b)
#define IDirect3DDevice7_GetLightEnable(p,a,b)                        (p)->GetLightEnable(a,b)
#define IDirect3DDevice7_SetClipPlane(p,a,b)                          (p)->SetClipPlane(a,b)
#define IDirect3DDevice7_GetClipPlane(p,a,b)                          (p)->GetClipPlane(a,b)
#define IDirect3DDevice7_GetInfo(p,a,b,c)                             (p)->GetInfo(a,b,c)
#endif



/*****************************************************************************
 * IDirect3DVertexBuffer interface
 */
#define INTERFACE IDirect3DVertexBuffer
DECLARE_INTERFACE_(IDirect3DVertexBuffer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DVertexBuffer methods ***/
    STDMETHOD(Lock)(THIS_ DWORD flags, void **data, DWORD *data_size) PURE;
    STDMETHOD(Unlock)(THIS) PURE;
    STDMETHOD(ProcessVertices)(THIS_ DWORD vertex_op, DWORD dst_idx, DWORD count,
            IDirect3DVertexBuffer *src_buffer, DWORD src_idx,
            IDirect3DDevice3 *device, DWORD flags) PURE;
    STDMETHOD(GetVertexBufferDesc)(THIS_ D3DVERTEXBUFFERDESC *desc) PURE;
    STDMETHOD(Optimize)(THIS_ IDirect3DDevice3 *device, DWORD flags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVertexBuffer_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVertexBuffer_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirect3DVertexBuffer_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirect3DVertexBuffer methods ***/
#define IDirect3DVertexBuffer_Lock(p,a,b,c)                    (p)->lpVtbl->Lock(p,a,b,c)
#define IDirect3DVertexBuffer_Unlock(p)                        (p)->lpVtbl->Unlock(p)
#define IDirect3DVertexBuffer_ProcessVertices(p,a,b,c,d,e,f,g) (p)->lpVtbl->ProcessVertices(p,a,b,c,d,e,f,g)
#define IDirect3DVertexBuffer_GetVertexBufferDesc(p,a)         (p)->lpVtbl->GetVertexBufferDesc(p,a)
#define IDirect3DVertexBuffer_Optimize(p,a,b)                  (p)->lpVtbl->Optimize(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirect3DVertexBuffer_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirect3DVertexBuffer_AddRef(p)             (p)->AddRef()
#define IDirect3DVertexBuffer_Release(p)            (p)->Release()
/*** IDirect3DVertexBuffer methods ***/
#define IDirect3DVertexBuffer_Lock(p,a,b,c)                    (p)->Lock(a,b,c)
#define IDirect3DVertexBuffer_Unlock(p)                        (p)->Unlock()
#define IDirect3DVertexBuffer_ProcessVertices(p,a,b,c,d,e,f,g) (p)->ProcessVertices(a,b,c,d,e,f,g)
#define IDirect3DVertexBuffer_GetVertexBufferDesc(p,a)         (p)->GetVertexBufferDesc(a)
#define IDirect3DVertexBuffer_Optimize(p,a,b)                  (p)->Optimize(a,b)
#endif

/*****************************************************************************
 * IDirect3DVertexBuffer7 interface
 */
#define INTERFACE IDirect3DVertexBuffer7
DECLARE_INTERFACE_(IDirect3DVertexBuffer7,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirect3DVertexBuffer7 methods ***/
    STDMETHOD(Lock)(THIS_ DWORD flags, void **data, DWORD *data_size) PURE;
    STDMETHOD(Unlock)(THIS) PURE;
    STDMETHOD(ProcessVertices)(THIS_ DWORD vertex_op, DWORD dst_idx, DWORD count,
            IDirect3DVertexBuffer7 *src_buffer, DWORD src_idx,
            IDirect3DDevice7 *device, DWORD flags) PURE;
    STDMETHOD(GetVertexBufferDesc)(THIS_ D3DVERTEXBUFFERDESC *desc) PURE;
    STDMETHOD(Optimize)(THIS_ IDirect3DDevice7 *device, DWORD flags) PURE;
    STDMETHOD(ProcessVerticesStrided)(THIS_ DWORD vertex_op, DWORD dst_idx, DWORD count,
            D3DDRAWPRIMITIVESTRIDEDDATA *data, DWORD fvf, IDirect3DDevice7 *device, DWORD flags) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirect3DVertexBuffer7_QueryInterface(p,a,b)                   (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirect3DVertexBuffer7_AddRef(p)                               (p)->lpVtbl->AddRef(p)
#define IDirect3DVertexBuffer7_Release(p)                              (p)->lpVtbl->Release(p)
/*** IDirect3DVertexBuffer7 methods ***/
#define IDirect3DVertexBuffer7_Lock(p,a,b,c)                           (p)->lpVtbl->Lock(p,a,b,c)
#define IDirect3DVertexBuffer7_Unlock(p)                               (p)->lpVtbl->Unlock(p)
#define IDirect3DVertexBuffer7_ProcessVertices(p,a,b,c,d,e,f,g)        (p)->lpVtbl->ProcessVertices(p,a,b,c,d,e,f,g)
#define IDirect3DVertexBuffer7_GetVertexBufferDesc(p,a)                (p)->lpVtbl->GetVertexBufferDesc(p,a)
#define IDirect3DVertexBuffer7_Optimize(p,a,b)                         (p)->lpVtbl->Optimize(p,a,b)
#define IDirect3DVertexBuffer7_ProcessVerticesStrided(p,a,b,c,d,e,f,g) (p)->lpVtbl->ProcessVerticesStrided(p,a,b,c,d,e,f,g)
#else
/*** IUnknown methods ***/
#define IDirect3DVertexBuffer7_QueryInterface(p,a,b)                   (p)->QueryInterface(a,b)
#define IDirect3DVertexBuffer7_AddRef(p)                               (p)->AddRef()
#define IDirect3DVertexBuffer7_Release(p)                              (p)->Release()
/*** IDirect3DVertexBuffer7 methods ***/
#define IDirect3DVertexBuffer7_Lock(p,a,b,c)                           (p)->Lock(a,b,c)
#define IDirect3DVertexBuffer7_Unlock(p)                               (p)->Unlock()
#define IDirect3DVertexBuffer7_ProcessVertices(p,a,b,c,d,e,f,g)        (p)->ProcessVertices(a,b,c,d,e,f,g)
#define IDirect3DVertexBuffer7_GetVertexBufferDesc(p,a)                (p)->GetVertexBufferDesc(a)
#define IDirect3DVertexBuffer7_Optimize(p,a,b)                         (p)->Optimize(a,b)
#define IDirect3DVertexBuffer7_ProcessVerticesStrided(p,a,b,c,d,e,f,g) (p)->ProcessVerticesStrided(a,b,c,d,e,f,g)
#endif

#endif /* __WINE_D3D_H */
