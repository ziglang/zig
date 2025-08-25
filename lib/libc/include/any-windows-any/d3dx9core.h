#include <_mingw_unicode.h>
#undef INTERFACE
/*
 * Copyright (C) 2007, 2008 Tony Wasserka
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

#include "d3dx9.h"

#ifndef __WINE_D3DX9CORE_H
#define __WINE_D3DX9CORE_H

/**********************************************
 ***************** Definitions ****************
 **********************************************/
#define D3DX_VERSION 0x0902
#ifndef D3DX_SDK_VERSION
#define D3DX_SDK_VERSION 43
#endif
#define D3DXSPRITE_DONOTSAVESTATE          0x00000001
#define D3DXSPRITE_DONOTMODIFY_RENDERSTATE 0x00000002
#define D3DXSPRITE_OBJECTSPACE             0x00000004
#define D3DXSPRITE_BILLBOARD               0x00000008
#define D3DXSPRITE_ALPHABLEND              0x00000010
#define D3DXSPRITE_SORT_TEXTURE            0x00000020
#define D3DXSPRITE_SORT_DEPTH_FRONTTOBACK  0x00000040
#define D3DXSPRITE_SORT_DEPTH_BACKTOFRONT  0x00000080
#define D3DXSPRITE_DO_NOT_ADDREF_TEXTURE   0x00000100

/**********************************************
 ******************** GUIDs *******************
 **********************************************/
DEFINE_GUID(IID_ID3DXBuffer, 0x8ba5fb08, 0x5195, 0x40e2, 0xac, 0x58, 0xd, 0x98, 0x9c, 0x3a, 0x1, 0x2);
DEFINE_GUID(IID_ID3DXFont, 0xd79dbb70, 0x5f21, 0x4d36, 0xbb, 0xc2, 0xff, 0x52, 0x5c, 0x21, 0x3c, 0xdc);
DEFINE_GUID(IID_ID3DXLine, 0xd379ba7f, 0x9042, 0x4ac4, 0x9f, 0x5e, 0x58, 0x19, 0x2a, 0x4c, 0x6b, 0xd8);
DEFINE_GUID(IID_ID3DXRenderToEnvMap, 0x313f1b4b, 0xc7b0, 0x4fa2, 0x9d, 0x9d, 0x8d, 0x38, 0xb, 0x64, 0x38, 0x5e);
DEFINE_GUID(IID_ID3DXRenderToSurface, 0x6985f346, 0x2c3d, 0x43b3, 0xbe, 0x8b, 0xda, 0xae, 0x8a, 0x3, 0xd8, 0x94);
DEFINE_GUID(IID_ID3DXSprite, 0xba0b762d, 0x7d28, 0x43ec, 0xb9, 0xdc, 0x2f, 0x84, 0x44, 0x3b, 0x6, 0x14);

/**********************************************
 ****************** typedefs ******************
 **********************************************/
typedef struct ID3DXBuffer *LPD3DXBUFFER;
typedef struct ID3DXFont *LPD3DXFONT;
typedef struct ID3DXLine *LPD3DXLINE;
typedef struct ID3DXRenderToEnvMap *LPD3DXRenderToEnvMap;
typedef struct ID3DXRenderToSurface *LPD3DXRENDERTOSURFACE;
typedef struct ID3DXSprite *LPD3DXSPRITE;

/**********************************************
 *********** interface declarations ***********
 **********************************************/
#define INTERFACE ID3DXBuffer
DECLARE_INTERFACE_(ID3DXBuffer, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXBuffer methods ***/
    STDMETHOD_(void *, GetBufferPointer)(THIS) PURE;
    STDMETHOD_(DWORD, GetBufferSize)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define ID3DXBuffer_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define ID3DXBuffer_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define ID3DXBuffer_Release(p)            (p)->lpVtbl->Release(p)
/*** ID3DXBuffer methods ***/
#define ID3DXBuffer_GetBufferPointer(p)   (p)->lpVtbl->GetBufferPointer(p)
#define ID3DXBuffer_GetBufferSize(p)      (p)->lpVtbl->GetBufferSize(p)
#else
/*** IUnknown methods ***/
#define ID3DXBuffer_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define ID3DXBuffer_AddRef(p)             (p)->AddRef()
#define ID3DXBuffer_Release(p)            (p)->Release()
/*** ID3DXBuffer methods ***/
#define ID3DXBuffer_GetBufferPointer(p)   (p)->GetBufferPointer()
#define ID3DXBuffer_GetBufferSize(p)      (p)->GetBufferSize()
#endif

typedef struct _D3DXFONT_DESCA
{
    INT Height;
    UINT Width;
    UINT Weight;
    UINT MipLevels;
    WINBOOL Italic;
    BYTE CharSet;
    BYTE OutputPrecision;
    BYTE Quality;
    BYTE PitchAndFamily;
    CHAR FaceName[LF_FACESIZE];
} D3DXFONT_DESCA, *LPD3DXFONT_DESCA;

typedef struct _D3DXFONT_DESCW
{
    INT Height;
    UINT Width;
    UINT Weight;
    UINT MipLevels;
    WINBOOL Italic;
    BYTE CharSet;
    BYTE OutputPrecision;
    BYTE Quality;
    BYTE PitchAndFamily;
    WCHAR FaceName[LF_FACESIZE];
} D3DXFONT_DESCW, *LPD3DXFONT_DESCW;

__MINGW_TYPEDEF_AW(D3DXFONT_DESC)
__MINGW_TYPEDEF_AW(LPD3DXFONT_DESC)

#define INTERFACE ID3DXFont
DECLARE_INTERFACE_(ID3DXFont, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXFont methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(GetDescA)(THIS_ D3DXFONT_DESCA *desc) PURE;
    STDMETHOD(GetDescW)(THIS_ D3DXFONT_DESCW *desc) PURE;
    STDMETHOD_(WINBOOL, GetTextMetricsA)(THIS_ TEXTMETRICA *metrics) PURE;
    STDMETHOD_(WINBOOL, GetTextMetricsW)(THIS_ TEXTMETRICW *metrics) PURE;

    STDMETHOD_(HDC, GetDC)(THIS) PURE;
    STDMETHOD(GetGlyphData)(THIS_ UINT glyph, struct IDirect3DTexture9 **texture,
            RECT *blackbox, POINT *cellinc) PURE;

    STDMETHOD(PreloadCharacters)(THIS_ UINT first, UINT last) PURE;
    STDMETHOD(PreloadGlyphs)(THIS_ UINT first, UINT last) PURE;
    STDMETHOD(PreloadTextA)(THIS_ const char *string, INT count) PURE;
    STDMETHOD(PreloadTextW)(THIS_ const WCHAR *string, INT count) PURE;

    STDMETHOD_(INT, DrawTextA)(THIS_ struct ID3DXSprite *sprite, const char *string,
            INT count, RECT *rect, DWORD format, D3DCOLOR color) PURE;
    STDMETHOD_(INT, DrawTextW)(THIS_ struct ID3DXSprite *sprite, const WCHAR *string,
            INT count, RECT *rect, DWORD format, D3DCOLOR color) PURE;

    STDMETHOD(OnLostDevice)(THIS) PURE;
    STDMETHOD(OnResetDevice)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)

/*** IUnknown methods ***/
#define ID3DXFont_QueryInterface(p,a,b)    (p)->lpVtbl->QueryInterface(p,a,b)
#define ID3DXFont_AddRef(p)                (p)->lpVtbl->AddRef(p)
#define ID3DXFont_Release(p)               (p)->lpVtbl->Release(p)
/*** ID3DXFont methods ***/
#define ID3DXFont_GetDevice(p,a)           (p)->lpVtbl->GetDevice(p,a)
#define ID3DXFont_GetDescA(p,a)            (p)->lpVtbl->GetDescA(p,a)
#define ID3DXFont_GetDescW(p,a)            (p)->lpVtbl->GetDescW(p,a)
#define ID3DXFont_GetTextMetricsA(p,a)     (p)->lpVtbl->GetTextMetricsA(p,a)
#define ID3DXFont_GetTextMetricsW(p,a)     (p)->lpVtbl->GetTextMetricsW(p,a)
#define ID3DXFont_GetDC(p)                 (p)->lpVtbl->GetDC(p)
#define ID3DXFont_GetGlyphData(p,a,b,c,d)  (p)->lpVtbl->GetGlyphData(p,a,b,c,d)
#define ID3DXFont_PreloadCharacters(p,a,b) (p)->lpVtbl->PreloadCharacters(p,a,b)
#define ID3DXFont_PreloadGlyphs(p,a,b)     (p)->lpVtbl->PreloadGlyphs(p,a,b)
#define ID3DXFont_PreloadTextA(p,a,b)      (p)->lpVtbl->PreloadTextA(p,a,b)
#define ID3DXFont_PreloadTextW(p,a,b)      (p)->lpVtbl->PreloadTextW(p,a,b)
#define ID3DXFont_DrawTextA(p,a,b,c,d,e,f) (p)->lpVtbl->DrawTextA(p,a,b,c,d,e,f)
#define ID3DXFont_DrawTextW(p,a,b,c,d,e,f) (p)->lpVtbl->DrawTextW(p,a,b,c,d,e,f)
#define ID3DXFont_OnLostDevice(p)          (p)->lpVtbl->OnLostDevice(p)
#define ID3DXFont_OnResetDevice(p)         (p)->lpVtbl->OnResetDevice(p)
#else
/*** IUnknown methods ***/
#define ID3DXFont_QueryInterface(p,a,b)    (p)->QueryInterface(a,b)
#define ID3DXFont_AddRef(p)                (p)->AddRef()
#define ID3DXFont_Release(p)               (p)->Release()
/*** ID3DXFont methods ***/
#define ID3DXFont_GetDevice(p,a)           (p)->GetDevice(a)
#define ID3DXFont_GetDescA(p,a)            (p)->GetDescA(a)
#define ID3DXFont_GetDescW(p,a)            (p)->GetDescW(a)
#define ID3DXFont_GetTextMetricsA(p,a)     (p)->GetTextMetricsA(a)
#define ID3DXFont_GetTextMetricsW(p,a)     (p)->GetTextMetricsW(a)
#define ID3DXFont_GetDC(p)                 (p)->GetDC()
#define ID3DXFont_GetGlyphData(p,a,b,c,d)  (p)->GetGlyphData(a,b,c,d)
#define ID3DXFont_PreloadCharacters(p,a,b) (p)->PreloadCharacters(a,b)
#define ID3DXFont_PreloadGlyphs(p,a,b)     (p)->PreloadGlyphs(a,b)
#define ID3DXFont_PreloadTextA(p,a,b)      (p)->PreloadTextA(a,b)
#define ID3DXFont_PreloadTextW(p,a,b)      (p)->PreloadTextW(a,b)
#define ID3DXFont_DrawTextA(p,a,b,c,d,e,f) (p)->DrawTextA(a,b,c,d,e,f)
#define ID3DXFont_DrawTextW(p,a,b,c,d,e,f) (p)->DrawTextW(a,b,c,d,e,f)
#define ID3DXFont_OnLostDevice(p)          (p)->OnLostDevice()
#define ID3DXFont_OnResetDevice(p)         (p)->OnResetDevice()
#endif
#define ID3DXFont_DrawText       __MINGW_NAME_AW(ID3DXFont_DrawText)
#define ID3DXFont_GetDesc        __MINGW_NAME_AW(ID3DXFont_GetDesc)
#define ID3DXFont_GetTextMetrics __MINGW_NAME_AW(ID3DXFont_GetTextMetrics)
#define ID3DXFont_PreloadText    __MINGW_NAME_AW(ID3DXFont_PreloadText)

#define INTERFACE ID3DXLine
DECLARE_INTERFACE_(ID3DXLine, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /*** ID3DXLine methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;

    STDMETHOD(Begin)(THIS) PURE;
    STDMETHOD(Draw)(THIS_ const D3DXVECTOR2 *vertexlist, DWORD vertexlistcount, D3DCOLOR color) PURE;
    STDMETHOD(DrawTransform)(THIS_ const D3DXVECTOR3 *vertexlist, DWORD vertexlistcount,
            const D3DXMATRIX *transform, D3DCOLOR color) PURE;
    STDMETHOD(SetPattern)(THIS_ DWORD pattern) PURE;
    STDMETHOD_(DWORD, GetPattern)(THIS) PURE;
    STDMETHOD(SetPatternScale)(THIS_ FLOAT scale) PURE;
    STDMETHOD_(FLOAT, GetPatternScale)(THIS) PURE;
    STDMETHOD(SetWidth)(THIS_ FLOAT width) PURE;
    STDMETHOD_(FLOAT, GetWidth)(THIS) PURE;
    STDMETHOD(SetAntialias)(THIS_ WINBOOL antialias) PURE;
    STDMETHOD_(WINBOOL, GetAntialias)(THIS) PURE;
    STDMETHOD(SetGLLines)(THIS_ WINBOOL gl_lines) PURE;
    STDMETHOD_(WINBOOL, GetGLLines)(THIS) PURE;
    STDMETHOD(End)(THIS) PURE;

    STDMETHOD(OnLostDevice)(THIS) PURE;
    STDMETHOD(OnResetDevice)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define ID3DXLine_QueryInterface(p,a,b)    (p)->lpVtbl->QueryInterface(p,a,b)
#define ID3DXLine_AddRef(p)                (p)->lpVtbl->AddRef(p)
#define ID3DXLine_Release(p)               (p)->lpVtbl->Release(p)
/*** ID3DXLine methods ***/
#define ID3DXLine_GetDevice(p,a)           (p)->lpVtbl->GetDevice(p,a)
#define ID3DXLine_Begin(p)                 (p)->lpVtbl->Begin(p)
#define ID3DXLine_Draw(p,a,b,c)            (p)->lpVtbl->Draw(p,a,b,c)
#define ID3DXLine_DrawTransform(p,a,b,c,d) (p)->lpVtbl->DrawTransform(p,a,b,c,d)
#define ID3DXLine_SetPattern(p,a)          (p)->lpVtbl->SetPattern(p,a)
#define ID3DXLine_GetPattern(p)            (p)->lpVtbl->GetPattern(p)
#define ID3DXLine_SetPatternScale(p,a)     (p)->lpVtbl->SetPatternScale(p,a)
#define ID3DXLine_GetPatternScale(p)       (p)->lpVtbl->GetPatternScale(p)
#define ID3DXLine_SetWidth(p,a)            (p)->lpVtbl->SetWidth(p,a)
#define ID3DXLine_GetWidth(p)              (p)->lpVtbl->GetWidth(p)
#define ID3DXLine_SetAntialias(p,a)        (p)->lpVtbl->SetAntialias(p,a)
#define ID3DXLine_GetAntialias(p)          (p)->lpVtbl->GetAntialias(p)
#define ID3DXLine_SetGLLines(p,a)          (p)->lpVtbl->SetGLLines(p,a)
#define ID3DXLine_GetGLLines(p)            (p)->lpVtbl->GetGLLines(p)
#define ID3DXLine_End(p)                   (p)->lpVtbl->End(p)
#define ID3DXLine_OnLostDevice(p)          (p)->lpVtbl->OnLostDevice(p)
#define ID3DXLine_OnResetDevice(p)         (p)->lpVtbl->OnResetDevice(p)
#else
/*** IUnknown methods ***/
#define ID3DXLine_QueryInterface(p,a,b)    (p)->QueryInterface(a,b)
#define ID3DXLine_AddRef(p)                (p)->AddRef()
#define ID3DXLine_Release(p)               (p)->Release()
/*** ID3DXLine methods ***/
#define ID3DXLine_GetDevice(p,a)           (p)->GetDevice(a)
#define ID3DXLine_Begin(p)                 (p)->Begin()
#define ID3DXLine_Draw(p,a,b,c)            (p)->Draw(a,b,c)
#define ID3DXLine_DrawTransform(p,a,b,c,d) (p)->DrawTransform(a,b,c,d)
#define ID3DXLine_SetPattern(p,a)          (p)->SetPattern(a)
#define ID3DXLine_GetPattern(p)            (p)->GetPattern()
#define ID3DXLine_SetPatternScale(p,a)     (p)->SetPatternScale(a)
#define ID3DXLine_GetPatternScale(p)       (p)->GetPatternScale()
#define ID3DXLine_SetWidth(p,a)            (p)->SetWidth(a)
#define ID3DXLine_GetWidth(p)              (p)->GetWidth()
#define ID3DXLine_SetAntialias(p,a)        (p)->SetAntialias(a)
#define ID3DXLine_GetAntialias(p)          (p)->GetAntialias()
#define ID3DXLine_SetGLLines(p,a)          (p)->SetGLLines(a)
#define ID3DXLine_GetGLLines(p)            (p)->GetGLLines()
#define ID3DXLine_End(p)                   (p)->End()
#define ID3DXLine_OnLostDevice(p)          (p)->OnLostDevice()
#define ID3DXLine_OnResetDevice(p)         (p)->OnResetDevice()
#endif

typedef struct _D3DXRTE_DESC
{
    UINT Size;
    UINT MipLevels;
    D3DFORMAT Format;
    WINBOOL DepthStencil;
    D3DFORMAT DepthStencilFormat;
} D3DXRTE_DESC;

#define INTERFACE ID3DXRenderToEnvMap
DECLARE_INTERFACE_(ID3DXRenderToEnvMap, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /*** ID3DXRenderToEnvMap methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DXRTE_DESC *desc) PURE;

    STDMETHOD(BeginCube)(THIS_ struct IDirect3DCubeTexture9 *cubetex) PURE;
    STDMETHOD(BeginSphere)(THIS_ struct IDirect3DTexture9 *tex) PURE;
    STDMETHOD(BeginHemisphere)(THIS_ struct IDirect3DTexture9 *texzpos, struct IDirect3DTexture9 *texzneg) PURE;
    STDMETHOD(BeginParabolic)(THIS_ struct IDirect3DTexture9 *texzpos, struct IDirect3DTexture9 *texzneg) PURE;

    STDMETHOD(Face)(THIS_ D3DCUBEMAP_FACES face, DWORD mipfilter) PURE;
    STDMETHOD(End)(THIS_ DWORD mipfilter) PURE;

    STDMETHOD(OnLostDevice)(THIS) PURE;
    STDMETHOD(OnResetDevice)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define ID3DXRenderToEnvMap_QueryInterface(p,a,b)  (p)->lpVtbl->QueryInterface(p,a,b)
#define ID3DXRenderToEnvMap_AddRef(p)              (p)->lpVtbl->AddRef(p)
#define ID3DXRenderToEnvMap_Release(p)             (p)->lpVtbl->Release(p)
/*** ID3DXRenderToEnvMap methods ***/
#define ID3DXRenderToEnvMap_GetDevice(p,a)         (p)->lpVtbl->GetDevice(p,a)
#define ID3DXRenderToEnvMap_GetDesc(p,a)           (p)->lpVtbl->GetDesc(p,a)
#define ID3DXRenderToEnvMap_BeginCube(p,a)         (p)->lpVtbl->BeginCube(p,a)
#define ID3DXRenderToEnvMap_BeginSphere(p,a)       (p)->lpVtbl->BeginSphere(p,a)
#define ID3DXRenderToEnvMap_BeginHemisphere(p,a,b) (p)->lpVtbl->BeginHemisphere(p,a,b)
#define ID3DXRenderToEnvMap_BeginParabolic(p,a,b)  (p)->lpVtbl->BeginParabolic(p,a,b)
#define ID3DXRenderToEnvMap_Face(p,a,b)            (p)->lpVtbl->Face(p,a,b)
#define ID3DXRenderToEnvMap_End(p,a)               (p)->lpVtbl->End(p,a)
#define ID3DXRenderToEnvMap_OnLostDevice(p)        (p)->lpVtbl->OnLostDevice(p)
#define ID3DXRenderToEnvMap_OnLostDevice(p)        (p)->lpVtbl->OnLostDevice(p)
#else
/*** IUnknown methods ***/
#define ID3DXRenderToEnvMap_QueryInterface(p,a,b)  (p)->QueryInterface(a,b)
#define ID3DXRenderToEnvMap_AddRef(p)              (p)->AddRef()
#define ID3DXRenderToEnvMap_Release(p)             (p)->Release()
/*** ID3DXRenderToEnvMap methods ***/
#define ID3DXRenderToEnvMap_GetDevice(p,a)         (p)->GetDevice(a)
#define ID3DXRenderToEnvMap_GetDesc(p,a)           (p)->GetDesc(a)
#define ID3DXRenderToEnvMap_BeginCube(p,a)         (p)->BeginCube(a)
#define ID3DXRenderToEnvMap_BeginSphere(p,a)       (p)->BeginSphere(a)
#define ID3DXRenderToEnvMap_BeginHemisphere(p,a,b) (p)->BeginHemisphere(a,b)
#define ID3DXRenderToEnvMap_BeginParabolic(p,a,b)  (p)->BeginParabolic(a,b)
#define ID3DXRenderToEnvMap_Face(p,a,b)            (p)->Face(a,b)
#define ID3DXRenderToEnvMap_End(p,a)               (p)->End(a)
#define ID3DXRenderToEnvMap_OnLostDevice(p)        (p)->OnLostDevice()
#define ID3DXRenderToEnvMap_OnLostDevice(p)        (p)->OnLostDevice()
#endif

typedef struct _D3DXRTS_DESC
{
    UINT Width;
    UINT Height;
    D3DFORMAT Format;
    WINBOOL DepthStencil;
    D3DFORMAT DepthStencilFormat;
} D3DXRTS_DESC;

#define INTERFACE ID3DXRenderToSurface
DECLARE_INTERFACE_(ID3DXRenderToSurface, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **out) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXRenderToSurface methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;
    STDMETHOD(GetDesc)(THIS_ D3DXRTS_DESC *desc) PURE;

    STDMETHOD(BeginScene)(THIS_ struct IDirect3DSurface9 *surface, const D3DVIEWPORT9 *viewport) PURE;
    STDMETHOD(EndScene)(THIS_ DWORD mipfilter) PURE;

    STDMETHOD(OnLostDevice)(THIS) PURE;
    STDMETHOD(OnResetDevice)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define ID3DXRenderToSurface_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define ID3DXRenderToSurface_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define ID3DXRenderToSurface_Release(p)            (p)->lpVtbl->Release(p)
/*** ID3DXRenderToSurface methods ***/
#define ID3DXRenderToSurface_GetDevice(p,a)        (p)->lpVtbl->GetDevice(p,a)
#define ID3DXRenderToSurface_GetDesc(p,a)          (p)->lpVtbl->GetDesc(p,a)
#define ID3DXRenderToSurface_BeginScene(p,a,b)     (p)->lpVtbl->BeginScene(p,a,b)
#define ID3DXRenderToSurface_EndScene(p,a)         (p)->lpVtbl->EndScene(p,a)
#define ID3DXRenderToSurface_OnLostDevice(p)       (p)->lpVtbl->OnLostDevice(p)
#define ID3DXRenderToSurface_OnResetDevice(p)      (p)->lpVtbl->OnResetDevice(p)
#else
/*** IUnknown methods ***/
#define ID3DXRenderToSurface_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define ID3DXRenderToSurface_AddRef(p)             (p)->AddRef()
#define ID3DXRenderToSurface_Release(p)            (p)->Release()
/*** ID3DXRenderToSurface methods ***/
#define ID3DXRenderToSurface_GetDevice(p,a)        (p)->GetDevice(a)
#define ID3DXRenderToSurface_GetDesc(p,a)          (p)->GetDesc(a)
#define ID3DXRenderToSurface_BeginScene(p,a,b)     (p)->BeginScene(a,b)
#define ID3DXRenderToSurface_EndScene(p,a)         (p)->EndScene(a)
#define ID3DXRenderToSurface_OnLostDevice(p)       (p)->OnLostDevice()
#define ID3DXRenderToSurface_OnResetDevice(p)      (p)->OnResetDevice()
#endif

#define INTERFACE ID3DXSprite
DECLARE_INTERFACE_(ID3DXSprite, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **object) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;
    /*** ID3DXSprite methods ***/
    STDMETHOD(GetDevice)(THIS_ struct IDirect3DDevice9 **device) PURE;

    STDMETHOD(GetTransform)(THIS_ D3DXMATRIX *transform) PURE;
    STDMETHOD(SetTransform)(THIS_ const D3DXMATRIX *transform) PURE;
    STDMETHOD(SetWorldViewRH)(THIS_ const D3DXMATRIX *world, const D3DXMATRIX *view) PURE;
    STDMETHOD(SetWorldViewLH)(THIS_ const D3DXMATRIX *world, const D3DXMATRIX *view) PURE;

    STDMETHOD(Begin)(THIS_ DWORD flags) PURE;
    STDMETHOD(Draw)(THIS_ struct IDirect3DTexture9 *texture, const RECT *rect,
            const D3DXVECTOR3 *center, const D3DXVECTOR3 *position, D3DCOLOR color) PURE;
    STDMETHOD(Flush)(THIS) PURE;
    STDMETHOD(End)(THIS) PURE;

    STDMETHOD(OnLostDevice)(THIS) PURE;
    STDMETHOD(OnResetDevice)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define ID3DXSprite_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define ID3DXSprite_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define ID3DXSprite_Release(p)            (p)->lpVtbl->Release(p)
/*** ID3DXSprite methods ***/
#define ID3DXSprite_GetDevice(p,a)        (p)->lpVtbl->GetDevice(p,a)
#define ID3DXSprite_GetTransform(p,a)     (p)->lpVtbl->GetTransform(p,a)
#define ID3DXSprite_SetTransform(p,a)     (p)->lpVtbl->SetTransform(p,a)
#define ID3DXSprite_SetWorldViewRH(p,a,b) (p)->lpVtbl->SetWorldViewRH(p,a,b)
#define ID3DXSprite_SetWorldViewLH(p,a,b) (p)->lpVtbl->SetWorldViewLH(p,a,b)
#define ID3DXSprite_Begin(p,a)            (p)->lpVtbl->Begin(p,a)
#define ID3DXSprite_Draw(p,a,b,c,d,e)     (p)->lpVtbl->Draw(p,a,b,c,d,e)
#define ID3DXSprite_Flush(p)              (p)->lpVtbl->Flush(p)
#define ID3DXSprite_End(p)                (p)->lpVtbl->End(p)
#define ID3DXSprite_OnLostDevice(p)       (p)->lpVtbl->OnLostDevice(p)
#define ID3DXSprite_OnResetDevice(p)      (p)->lpVtbl->OnResetDevice(p)
#else
/*** IUnknown methods ***/
#define ID3DXSprite_QueryInterface(p,a,b)    (p)->QueryInterface(a,b)
#define ID3DXSprite_AddRef(p)                (p)->AddRef()
#define ID3DXSprite_Release(p)               (p)->Release()
/*** ID3DXSprite methods ***/
#define ID3DXSprite_GetDevice(p,a)        (p)->GetDevice(a)
#define ID3DXSprite_GetTransform(p,a)     (p)->GetTransform(a)
#define ID3DXSprite_SetTransform(p,a)     (p)->SetTransform(a)
#define ID3DXSprite_SetWorldViewRH(p,a,b) (p)->SetWorldViewRH(a,b)
#define ID3DXSprite_SetWorldViewLH(p,a,b) (p)->SetWorldViewLH(a,b)
#define ID3DXSprite_Begin(p,a)            (p)->Begin(a)
#define ID3DXSprite_Draw(p,a,b,c,d,e)     (p)->Draw(a,b,c,d,e)
#define ID3DXSprite_Flush(p)              (p)->Flush()
#define ID3DXSprite_End(p)                (p)->End()
#define ID3DXSprite_OnLostDevice(p)       (p)->OnLostDevice()
#define ID3DXSprite_OnResetDevice(p)      (p)->OnResetDevice()
#endif

/**********************************************
 ****************** functions *****************
 **********************************************/
#ifdef __cplusplus
extern "C" {
#endif

WINBOOL WINAPI D3DXCheckVersion(UINT d3dsdkvers, UINT d3dxsdkvers);
HRESULT WINAPI D3DXCreateFontA(struct IDirect3DDevice9 *device, INT height, UINT width, UINT weight,
        UINT miplevels, WINBOOL italic, DWORD charset, DWORD precision, DWORD quality, DWORD pitchandfamily,
        const char *facename, struct ID3DXFont **font);
HRESULT WINAPI D3DXCreateFontW(struct IDirect3DDevice9 *device, INT height, UINT width, UINT weight,
        UINT miplevels, WINBOOL italic, DWORD charset, DWORD precision, DWORD quality, DWORD pitchandfamily,
        const WCHAR *facename, struct ID3DXFont **font);
#define D3DXCreateFont __MINGW_NAME_AW(D3DXCreateFont)
HRESULT WINAPI D3DXCreateFontIndirectA(struct IDirect3DDevice9 *device,
        const D3DXFONT_DESCA *desc, struct ID3DXFont **font);
HRESULT WINAPI D3DXCreateFontIndirectW(struct IDirect3DDevice9 *device,
        const D3DXFONT_DESCW *desc, struct ID3DXFont **font);
#define D3DXCreateFontIndirect __MINGW_NAME_AW(D3DXCreateFontIndirect)
HRESULT WINAPI D3DXCreateLine(struct IDirect3DDevice9 *device, struct ID3DXLine **line);
HRESULT WINAPI D3DXCreateRenderToEnvMap(struct IDirect3DDevice9 *device, UINT size, UINT miplevels,
        D3DFORMAT format, WINBOOL stencil, D3DFORMAT stencil_format, struct ID3DXRenderToEnvMap **rtem);
HRESULT WINAPI D3DXCreateRenderToSurface(struct IDirect3DDevice9 *device, UINT width, UINT height,
        D3DFORMAT format, WINBOOL stencil, D3DFORMAT stencil_format, struct ID3DXRenderToSurface **rts);
HRESULT WINAPI D3DXCreateSprite(struct IDirect3DDevice9 *device, struct ID3DXSprite **sprite);
WINBOOL WINAPI D3DXDebugMute(WINBOOL mute);
UINT WINAPI D3DXGetDriverLevel(struct IDirect3DDevice9 *device);

#ifdef __cplusplus
}
#endif

#endif /* __WINE_D3DX9CORE_H */
