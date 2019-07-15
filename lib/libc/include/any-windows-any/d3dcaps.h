/*
 * Copyright (C) 2000 Peter Hunnisett
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

#ifndef __WINE_D3DCAPS_H
#define __WINE_D3DCAPS_H

#include <ddraw.h>

#ifdef __i386__
#include <pshpack4.h>
#endif

typedef struct _D3DTRANSFORMCAPS {
	DWORD dwSize;
	DWORD dwCaps;
} D3DTRANSFORMCAPS, *LPD3DTRANSFORMCAPS;

#define D3DTRANSFORMCAPS_CLIP           __MSABI_LONG(0x00000001)

typedef struct _D3DLIGHTINGCAPS {
	DWORD dwSize;
	DWORD dwCaps;
	DWORD dwLightingModel;
	DWORD dwNumLights;
} D3DLIGHTINGCAPS, *LPD3DLIGHTINGCAPS;

#define D3DLIGHTINGMODEL_RGB            0x00000001
#define D3DLIGHTINGMODEL_MONO           0x00000002

#define D3DLIGHTCAPS_POINT              0x00000001
#define D3DLIGHTCAPS_SPOT               0x00000002
#define D3DLIGHTCAPS_DIRECTIONAL        0x00000004
#define D3DLIGHTCAPS_PARALLELPOINT      0x00000008
#define D3DLIGHTCAPS_GLSPOT             0x00000010

typedef struct _D3dPrimCaps {
    DWORD dwSize;
    DWORD dwMiscCaps;
    DWORD dwRasterCaps;
    DWORD dwZCmpCaps;
    DWORD dwSrcBlendCaps;
    DWORD dwDestBlendCaps;
    DWORD dwAlphaCmpCaps;
    DWORD dwShadeCaps;
    DWORD dwTextureCaps;
    DWORD dwTextureFilterCaps;
    DWORD dwTextureBlendCaps;
    DWORD dwTextureAddressCaps;
    DWORD dwStippleWidth;
    DWORD dwStippleHeight;
} D3DPRIMCAPS, *LPD3DPRIMCAPS;

#define D3DPMISCCAPS_MASKPLANES         0x00000001
#define D3DPMISCCAPS_MASKZ              0x00000002
#define D3DPMISCCAPS_LINEPATTERNREP     0x00000004
#define D3DPMISCCAPS_CONFORMANT         0x00000008
#define D3DPMISCCAPS_CULLNONE           0x00000010
#define D3DPMISCCAPS_CULLCW             0x00000020
#define D3DPMISCCAPS_CULLCCW            0x00000040

#define D3DPRASTERCAPS_DITHER                     0x00000001
#define D3DPRASTERCAPS_ROP2                       0x00000002
#define D3DPRASTERCAPS_XOR                        0x00000004
#define D3DPRASTERCAPS_PAT                        0x00000008
#define D3DPRASTERCAPS_ZTEST                      0x00000010
#define D3DPRASTERCAPS_SUBPIXEL                   0x00000020
#define D3DPRASTERCAPS_SUBPIXELX                  0x00000040
#define D3DPRASTERCAPS_FOGVERTEX                  0x00000080
#define D3DPRASTERCAPS_FOGTABLE                   0x00000100
#define D3DPRASTERCAPS_STIPPLE                    0x00000200
#define D3DPRASTERCAPS_ANTIALIASSORTDEPENDENT     0x00000400
#define D3DPRASTERCAPS_ANTIALIASSORTINDEPENDENT   0x00000800
#define D3DPRASTERCAPS_ANTIALIASEDGES             0x00001000
#define D3DPRASTERCAPS_MIPMAPLODBIAS              0x00002000
#define D3DPRASTERCAPS_ZBIAS                      0x00004000
#define D3DPRASTERCAPS_ZBUFFERLESSHSR             0x00008000
#define D3DPRASTERCAPS_FOGRANGE                   0x00010000
#define D3DPRASTERCAPS_ANISOTROPY                 0x00020000
#define D3DPRASTERCAPS_WBUFFER                    0x00040000
#define D3DPRASTERCAPS_TRANSLUCENTSORTINDEPENDENT 0x00080000
#define D3DPRASTERCAPS_WFOG                       0x00100000
#define D3DPRASTERCAPS_ZFOG                       0x00200000

#define D3DPCMPCAPS_NEVER               0x00000001
#define D3DPCMPCAPS_LESS                0x00000002
#define D3DPCMPCAPS_EQUAL               0x00000004
#define D3DPCMPCAPS_LESSEQUAL           0x00000008
#define D3DPCMPCAPS_GREATER             0x00000010
#define D3DPCMPCAPS_NOTEQUAL            0x00000020
#define D3DPCMPCAPS_GREATEREQUAL        0x00000040
#define D3DPCMPCAPS_ALWAYS              0x00000080

#define D3DPBLENDCAPS_ZERO              0x00000001
#define D3DPBLENDCAPS_ONE               0x00000002
#define D3DPBLENDCAPS_SRCCOLOR          0x00000004
#define D3DPBLENDCAPS_INVSRCCOLOR       0x00000008
#define D3DPBLENDCAPS_SRCALPHA          0x00000010
#define D3DPBLENDCAPS_INVSRCALPHA       0x00000020
#define D3DPBLENDCAPS_DESTALPHA         0x00000040
#define D3DPBLENDCAPS_INVDESTALPHA      0x00000080
#define D3DPBLENDCAPS_DESTCOLOR         0x00000100
#define D3DPBLENDCAPS_INVDESTCOLOR      0x00000200
#define D3DPBLENDCAPS_SRCALPHASAT       0x00000400
#define D3DPBLENDCAPS_BOTHSRCALPHA      0x00000800
#define D3DPBLENDCAPS_BOTHINVSRCALPHA   0x00001000

#define D3DPSHADECAPS_COLORFLATMONO     0x00000001
#define D3DPSHADECAPS_COLORFLATRGB      0x00000002
#define D3DPSHADECAPS_COLORGOURAUDMONO  0x00000004
#define D3DPSHADECAPS_COLORGOURAUDRGB   0x00000008
#define D3DPSHADECAPS_COLORPHONGMONO    0x00000010
#define D3DPSHADECAPS_COLORPHONGRGB     0x00000020

#define D3DPSHADECAPS_SPECULARFLATMONO    0x00000040
#define D3DPSHADECAPS_SPECULARFLATRGB     0x00000080
#define D3DPSHADECAPS_SPECULARGOURAUDMONO 0x00000100
#define D3DPSHADECAPS_SPECULARGOURAUDRGB  0x00000200
#define D3DPSHADECAPS_SPECULARPHONGMONO   0x00000400
#define D3DPSHADECAPS_SPECULARPHONGRGB    0x00000800

#define D3DPSHADECAPS_ALPHAFLATBLEND       0x00001000
#define D3DPSHADECAPS_ALPHAFLATSTIPPLED    0x00002000
#define D3DPSHADECAPS_ALPHAGOURAUDBLEND    0x00004000
#define D3DPSHADECAPS_ALPHAGOURAUDSTIPPLED 0x00008000
#define D3DPSHADECAPS_ALPHAPHONGBLEND      0x00010000
#define D3DPSHADECAPS_ALPHAPHONGSTIPPLED   0x00020000

#define D3DPSHADECAPS_FOGFLAT           0x00040000
#define D3DPSHADECAPS_FOGGOURAUD        0x00080000
#define D3DPSHADECAPS_FOGPHONG          0x00100000

#define D3DPTEXTURECAPS_PERSPECTIVE              0x00000001
#define D3DPTEXTURECAPS_POW2                     0x00000002
#define D3DPTEXTURECAPS_ALPHA                    0x00000004
#define D3DPTEXTURECAPS_TRANSPARENCY             0x00000008
#define D3DPTEXTURECAPS_BORDER                   0x00000010
#define D3DPTEXTURECAPS_SQUAREONLY               0x00000020
#define D3DPTEXTURECAPS_TEXREPEATNOTSCALEDBYSIZE 0x00000040
#define D3DPTEXTURECAPS_ALPHAPALETTE             0x00000080
#define D3DPTEXTURECAPS_NONPOW2CONDITIONAL       __MSABI_LONG(0x00000100)
/* yes actually 0x00000200 is unused - or at least unreleased */
#define D3DPTEXTURECAPS_PROJECTED                0x00000400
#define D3DPTEXTURECAPS_CUBEMAP                  0x00000800
#define D3DPTEXTURECAPS_COLORKEYBLEND            0x00001000

#define D3DPTFILTERCAPS_NEAREST           0x00000001
#define D3DPTFILTERCAPS_LINEAR            0x00000002
#define D3DPTFILTERCAPS_MIPNEAREST        0x00000004
#define D3DPTFILTERCAPS_MIPLINEAR         0x00000008
#define D3DPTFILTERCAPS_LINEARMIPNEAREST  0x00000010
#define D3DPTFILTERCAPS_LINEARMIPLINEAR   0x00000020
/* yes - missing numbers */
#define D3DPTFILTERCAPS_MINFPOINT         0x00000100
#define D3DPTFILTERCAPS_MINFLINEAR        0x00000200
#define D3DPTFILTERCAPS_MINFANISOTROPIC   0x00000400
/* yes - missing numbers */
#define D3DPTFILTERCAPS_MIPFPOINT         0x00010000
#define D3DPTFILTERCAPS_MIPFLINEAR        0x00020000
/* yes - missing numbers */
#define D3DPTFILTERCAPS_MAGFPOINT         0x01000000
#define D3DPTFILTERCAPS_MAGFLINEAR        0x02000000
#define D3DPTFILTERCAPS_MAGFANISOTROPIC   0x04000000
#define D3DPTFILTERCAPS_MAGFAFLATCUBIC    0x08000000
#define D3DPTFILTERCAPS_MAGFGAUSSIANCUBIC 0x10000000

#define D3DPTBLENDCAPS_DECAL            0x00000001
#define D3DPTBLENDCAPS_MODULATE         0x00000002
#define D3DPTBLENDCAPS_DECALALPHA       0x00000004
#define D3DPTBLENDCAPS_MODULATEALPHA    0x00000008
#define D3DPTBLENDCAPS_DECALMASK        0x00000010
#define D3DPTBLENDCAPS_MODULATEMASK     0x00000020
#define D3DPTBLENDCAPS_COPY             0x00000040
#define D3DPTBLENDCAPS_ADD              0x00000080

#define D3DPTADDRESSCAPS_WRAP           0x00000001
#define D3DPTADDRESSCAPS_MIRROR         0x00000002
#define D3DPTADDRESSCAPS_CLAMP          0x00000004
#define D3DPTADDRESSCAPS_BORDER         0x00000008
#define D3DPTADDRESSCAPS_INDEPENDENTUV  0x00000010


typedef struct _D3DDeviceDesc {
        DWORD           dwSize;
        DWORD           dwFlags;
        D3DCOLORMODEL   dcmColorModel;
        DWORD           dwDevCaps;
        D3DTRANSFORMCAPS dtcTransformCaps;
        WINBOOL         bClipping;
        D3DLIGHTINGCAPS dlcLightingCaps;
        D3DPRIMCAPS     dpcLineCaps;
        D3DPRIMCAPS     dpcTriCaps;
        DWORD           dwDeviceRenderBitDepth;
        DWORD           dwDeviceZBufferBitDepth;
        DWORD           dwMaxBufferSize;
        DWORD           dwMaxVertexCount;

        DWORD           dwMinTextureWidth,dwMinTextureHeight;
        DWORD           dwMaxTextureWidth,dwMaxTextureHeight;
        DWORD           dwMinStippleWidth,dwMaxStippleWidth;
        DWORD           dwMinStippleHeight,dwMaxStippleHeight;

        DWORD       dwMaxTextureRepeat;
        DWORD       dwMaxTextureAspectRatio;
        DWORD       dwMaxAnisotropy;

        D3DVALUE    dvGuardBandLeft;
        D3DVALUE    dvGuardBandTop;
        D3DVALUE    dvGuardBandRight;
        D3DVALUE    dvGuardBandBottom;

        D3DVALUE    dvExtentsAdjust;
        DWORD       dwStencilCaps;

        DWORD       dwFVFCaps;
        DWORD       dwTextureOpCaps;
        WORD        wMaxTextureBlendStages;
        WORD        wMaxSimultaneousTextures;
} D3DDEVICEDESC,*LPD3DDEVICEDESC;
#define D3DDEVICEDESCSIZE (sizeof(D3DDEVICEDESC))

typedef struct _D3DDeviceDesc7 {
        DWORD            dwDevCaps;
        D3DPRIMCAPS      dpcLineCaps;
        D3DPRIMCAPS      dpcTriCaps;
        DWORD            dwDeviceRenderBitDepth;
        DWORD            dwDeviceZBufferBitDepth;

        DWORD       dwMinTextureWidth, dwMinTextureHeight;
        DWORD       dwMaxTextureWidth, dwMaxTextureHeight;

        DWORD       dwMaxTextureRepeat;
        DWORD       dwMaxTextureAspectRatio;
        DWORD       dwMaxAnisotropy;

        D3DVALUE    dvGuardBandLeft;
        D3DVALUE    dvGuardBandTop;
        D3DVALUE    dvGuardBandRight;
        D3DVALUE    dvGuardBandBottom;

        D3DVALUE    dvExtentsAdjust;
        DWORD       dwStencilCaps;
        DWORD       dwFVFCaps;
        DWORD       dwTextureOpCaps;
        WORD        wMaxTextureBlendStages;
        WORD        wMaxSimultaneousTextures;

        DWORD       dwMaxActiveLights;
        D3DVALUE    dvMaxVertexW;
        GUID        deviceGUID;

        WORD        wMaxUserClipPlanes;
        WORD        wMaxVertexBlendMatrices;

        DWORD       dwVertexProcessingCaps;

        DWORD       dwReserved1;
        DWORD       dwReserved2;
        DWORD       dwReserved3;
        DWORD       dwReserved4;
} D3DDEVICEDESC7, *LPD3DDEVICEDESC7;
#define D3DDEVICEDESC7SIZE (sizeof(D3DDEVICEDESC7))

#define D3DDD_COLORMODEL                0x00000001
#define D3DDD_DEVCAPS                   0x00000002
#define D3DDD_TRANSFORMCAPS             0x00000004
#define D3DDD_LIGHTINGCAPS              0x00000008
#define D3DDD_BCLIPPING                 0x00000010
#define D3DDD_LINECAPS                  0x00000020
#define D3DDD_TRICAPS                   0x00000040
#define D3DDD_DEVICERENDERBITDEPTH      0x00000080
#define D3DDD_DEVICEZBUFFERBITDEPTH     0x00000100
#define D3DDD_MAXBUFFERSIZE             0x00000200
#define D3DDD_MAXVERTEXCOUNT            0x00000400

#define D3DDEVCAPS_FLOATTLVERTEX           0x00000001
#define D3DDEVCAPS_SORTINCREASINGZ         0x00000002
#define D3DDEVCAPS_SORTDECREASINGZ         0X00000004
#define D3DDEVCAPS_SORTEXACT               0x00000008
#define D3DDEVCAPS_EXECUTESYSTEMMEMORY     0x00000010
#define D3DDEVCAPS_EXECUTEVIDEOMEMORY      0x00000020
#define D3DDEVCAPS_TLVERTEXSYSTEMMEMORY    0x00000040
#define D3DDEVCAPS_TLVERTEXVIDEOMEMORY     0x00000080
#define D3DDEVCAPS_TEXTURESYSTEMMEMORY     0x00000100
#define D3DDEVCAPS_TEXTUREVIDEOMEMORY      0x00000200
#define D3DDEVCAPS_DRAWPRIMTLVERTEX        0x00000400
#define D3DDEVCAPS_CANRENDERAFTERFLIP      0x00000800
#define D3DDEVCAPS_TEXTURENONLOCALVIDMEM   0x00001000
#define D3DDEVCAPS_DRAWPRIMITIVES2         0x00002000
#define D3DDEVCAPS_SEPARATETEXTUREMEMORIES 0x00004000
#define D3DDEVCAPS_DRAWPRIMITIVES2EX       0x00008000
#define D3DDEVCAPS_HWTRANSFORMANDLIGHT     0x00010000
#define D3DDEVCAPS_CANBLTSYSTONONLOCAL     0x00020000
#define D3DDEVCAPS_HWRASTERIZATION         0x00080000

#define D3DSTENCILCAPS_KEEP     0x00000001
#define D3DSTENCILCAPS_ZERO     0x00000002
#define D3DSTENCILCAPS_REPLACE  0x00000004
#define D3DSTENCILCAPS_INCRSAT  0x00000008
#define D3DSTENCILCAPS_DECRSAT  0x00000010
#define D3DSTENCILCAPS_INVERT   0x00000020
#define D3DSTENCILCAPS_INCR     0x00000040
#define D3DSTENCILCAPS_DECR     0x00000080

#define D3DTEXOPCAPS_DISABLE                    0x00000001
#define D3DTEXOPCAPS_SELECTARG1                 0x00000002
#define D3DTEXOPCAPS_SELECTARG2                 0x00000004
#define D3DTEXOPCAPS_MODULATE                   0x00000008
#define D3DTEXOPCAPS_MODULATE2X                 0x00000010
#define D3DTEXOPCAPS_MODULATE4X                 0x00000020
#define D3DTEXOPCAPS_ADD                        0x00000040
#define D3DTEXOPCAPS_ADDSIGNED                  0x00000080
#define D3DTEXOPCAPS_ADDSIGNED2X                0x00000100
#define D3DTEXOPCAPS_SUBTRACT                   0x00000200
#define D3DTEXOPCAPS_ADDSMOOTH                  0x00000400
#define D3DTEXOPCAPS_BLENDDIFFUSEALPHA          0x00000800
#define D3DTEXOPCAPS_BLENDTEXTUREALPHA          0x00001000
#define D3DTEXOPCAPS_BLENDFACTORALPHA           0x00002000
#define D3DTEXOPCAPS_BLENDTEXTUREALPHAPM        0x00004000
#define D3DTEXOPCAPS_BLENDCURRENTALPHA          0x00008000
#define D3DTEXOPCAPS_PREMODULATE                0x00010000
#define D3DTEXOPCAPS_MODULATEALPHA_ADDCOLOR     0x00020000
#define D3DTEXOPCAPS_MODULATECOLOR_ADDALPHA     0x00040000
#define D3DTEXOPCAPS_MODULATEINVALPHA_ADDCOLOR  0x00080000
#define D3DTEXOPCAPS_MODULATEINVCOLOR_ADDALPHA  0x00100000
#define D3DTEXOPCAPS_BUMPENVMAP                 0x00200000
#define D3DTEXOPCAPS_BUMPENVMAPLUMINANCE        0x00400000
#define D3DTEXOPCAPS_DOTPRODUCT3                0x00800000

#define D3DFVFCAPS_TEXCOORDCOUNTMASK    0x0000FFFF
#define D3DFVFCAPS_DONOTSTRIPELEMENTS   0x00080000

#define D3DVTXPCAPS_TEXGEN              0x00000001
#define D3DVTXPCAPS_MATERIALSOURCE7     0x00000002
#define D3DVTXPCAPS_VERTEXFOG           0x00000004
#define D3DVTXPCAPS_DIRECTIONALLIGHTS   0x00000008
#define D3DVTXPCAPS_POSITIONALLIGHTS    0x00000010
#define D3DVTXPCAPS_LOCALVIEWER         0x00000020

typedef HRESULT (CALLBACK *LPD3DENUMDEVICESCALLBACK)(GUID *guid, char *description, char *name,
        D3DDEVICEDESC *hal_desc, D3DDEVICEDESC *hel_desc, void *ctx);
typedef HRESULT (CALLBACK *LPD3DENUMDEVICESCALLBACK7)(char *description, char *name, D3DDEVICEDESC7 *desc, void *ctx);

#define D3DFDS_COLORMODEL          0x00000001
#define D3DFDS_GUID                0x00000002
#define D3DFDS_HARDWARE            0x00000004
#define D3DFDS_TRIANGLES           0x00000008
#define D3DFDS_LINES               0x00000010
#define D3DFDS_MISCCAPS            0x00000020
#define D3DFDS_RASTERCAPS          0x00000040
#define D3DFDS_ZCMPCAPS            0x00000080
#define D3DFDS_ALPHACMPCAPS        0x00000100
#define D3DFDS_SRCBLENDCAPS        0x00000200
#define D3DFDS_DSTBLENDCAPS        0x00000400
#define D3DFDS_SHADECAPS           0x00000800
#define D3DFDS_TEXTURECAPS         0x00001000
#define D3DFDS_TEXTUREFILTERCAPS   0x00002000
#define D3DFDS_TEXTUREBLENDCAPS    0x00004000
#define D3DFDS_TEXTUREADDRESSCAPS  0x00008000

typedef struct _D3DFINDDEVICESEARCH {
    DWORD               dwSize;
    DWORD               dwFlags;
    WINBOOL             bHardware;
    D3DCOLORMODEL       dcmColorModel;
    GUID                guid;
    DWORD               dwCaps;
    D3DPRIMCAPS         dpcPrimCaps;
} D3DFINDDEVICESEARCH,*LPD3DFINDDEVICESEARCH;

typedef struct _D3DFINDDEVICERESULT {
    DWORD               dwSize;
    GUID                guid;
    D3DDEVICEDESC       ddHwDesc;
    D3DDEVICEDESC       ddSwDesc;
} D3DFINDDEVICERESULT,*LPD3DFINDDEVICERESULT;

typedef struct _D3DExecuteBufferDesc {
  DWORD  dwSize;
  DWORD  dwFlags;
  DWORD  dwCaps;
  DWORD  dwBufferSize;
  void *lpData;
} D3DEXECUTEBUFFERDESC, *LPD3DEXECUTEBUFFERDESC;

#define D3DDEB_BUFSIZE          0x00000001
#define D3DDEB_CAPS             0x00000002
#define D3DDEB_LPDATA           0x00000004

#define D3DDEBCAPS_SYSTEMMEMORY 0x00000001
#define D3DDEBCAPS_VIDEOMEMORY  0x00000002
#define D3DDEBCAPS_MEM          (D3DDEBCAPS_SYSTEMMEMORY|D3DDEBCAPS_VIDEOMEMORY) /* = 0x3 */

typedef struct _D3DDEVINFO_TEXTUREMANAGER {
	WINBOOL bThrashing;
	DWORD   dwApproxBytesDownloaded;
	DWORD   dwNumEvicts;
	DWORD   dwNumVidCreates;
	DWORD   dwNumTexturesUsed;
	DWORD   dwNumUsedTexInVid;
	DWORD   dwWorkingSet;
	DWORD   dwWorkingSetBytes;
	DWORD   dwTotalManaged;
	DWORD   dwTotalBytes;
	DWORD   dwLastPri;
} D3DDEVINFO_TEXTUREMANAGER, *LPD3DDEVINFO_TEXTUREMANAGER;

typedef struct _D3DDEVINFO_TEXTURING {
	DWORD   dwNumLoads;
	DWORD   dwApproxBytesLoaded;
	DWORD   dwNumPreLoads;
	DWORD   dwNumSet;
	DWORD   dwNumCreates;
	DWORD   dwNumDestroys;
	DWORD   dwNumSetPriorities;
	DWORD   dwNumSetLODs;
	DWORD   dwNumLocks;
	DWORD   dwNumGetDCs;
} D3DDEVINFO_TEXTURING, *LPD3DDEVINFO_TEXTURING;

#ifdef __i386__
#include <poppack.h>
#endif

#endif
