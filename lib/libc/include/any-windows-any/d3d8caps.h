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

#ifndef __WINE_D3D8CAPS_H
#define __WINE_D3D8CAPS_H

#ifdef __i386__
#include <pshpack4.h>
#endif

/*
 * Definitions
 */

#define D3DCAPS_READ_SCANLINE 0x20000

#define D3DCURSORCAPS_COLOR   1
#define D3DCURSORCAPS_LOWRES  2

#define D3DDEVCAPS_EXECUTESYSTEMMEMORY     0x0000010
#define D3DDEVCAPS_EXECUTEVIDEOMEMORY      0x0000020
#define D3DDEVCAPS_TLVERTEXSYSTEMMEMORY    0x0000040
#define D3DDEVCAPS_TLVERTEXVIDEOMEMORY     0x0000080
#define D3DDEVCAPS_TEXTURESYSTEMMEMORY     0x0000100
#define D3DDEVCAPS_TEXTUREVIDEOMEMORY      0x0000200
#define D3DDEVCAPS_DRAWPRIMTLVERTEX        0x0000400
#define D3DDEVCAPS_CANRENDERAFTERFLIP      0x0000800
#define D3DDEVCAPS_TEXTURENONLOCALVIDMEM   0x0001000
#define D3DDEVCAPS_DRAWPRIMITIVES2         0x0002000
#define D3DDEVCAPS_SEPARATETEXTUREMEMORIES 0x0004000
#define D3DDEVCAPS_DRAWPRIMITIVES2EX       0x0008000
#define D3DDEVCAPS_HWTRANSFORMANDLIGHT     0x0010000
#define D3DDEVCAPS_CANBLTSYSTONONLOCAL     0x0020000
#define D3DDEVCAPS_HWRASTERIZATION         0x0080000
#define D3DDEVCAPS_PUREDEVICE              0x0100000
#define D3DDEVCAPS_QUINTICRTPATCHES        0x0200000
#define D3DDEVCAPS_RTPATCHES               0x0400000
#define D3DDEVCAPS_RTPATCHHANDLEZERO       0x0800000
#define D3DDEVCAPS_NPATCHES                0x1000000

#define D3DFVFCAPS_TEXCOORDCOUNTMASK  0x00FFFF
#define D3DFVFCAPS_DONOTSTRIPELEMENTS 0x080000
#define D3DFVFCAPS_PSIZE              0x100000

#define D3DLINECAPS_TEXTURE           0x01
#define D3DLINECAPS_ZTEST             0x02
#define D3DLINECAPS_BLEND             0x04
#define D3DLINECAPS_ALPHACMP          0x08
#define D3DLINECAPS_FOG               0x10

#define D3DPBLENDCAPS_ZERO            0x0001
#define D3DPBLENDCAPS_ONE             0x0002
#define D3DPBLENDCAPS_SRCCOLOR        0x0004
#define D3DPBLENDCAPS_INVSRCCOLOR     0x0008
#define D3DPBLENDCAPS_SRCALPHA        0x0010
#define D3DPBLENDCAPS_INVSRCALPHA     0x0020
#define D3DPBLENDCAPS_DESTALPHA       0x0040
#define D3DPBLENDCAPS_INVDESTALPHA    0x0080
#define D3DPBLENDCAPS_DESTCOLOR       0x0100
#define D3DPBLENDCAPS_INVDESTCOLOR    0x0200
#define D3DPBLENDCAPS_SRCALPHASAT     0x0400
#define D3DPBLENDCAPS_BOTHSRCALPHA    0x0800
#define D3DPBLENDCAPS_BOTHINVSRCALPHA 0x1000

#define D3DPCMPCAPS_NEVER        0x01
#define D3DPCMPCAPS_LESS         0x02
#define D3DPCMPCAPS_EQUAL        0x04
#define D3DPCMPCAPS_LESSEQUAL    0x08
#define D3DPCMPCAPS_GREATER      0x10
#define D3DPCMPCAPS_NOTEQUAL     0x20
#define D3DPCMPCAPS_GREATEREQUAL 0x40
#define D3DPCMPCAPS_ALWAYS       0x80

#define D3DPMISCCAPS_MASKZ                 __MSABI_LONG(0x00000002)
#define D3DPMISCCAPS_LINEPATTERNREP        __MSABI_LONG(0x00000004)
#define D3DPMISCCAPS_CULLNONE              __MSABI_LONG(0x00000010)
#define D3DPMISCCAPS_CULLCW                __MSABI_LONG(0x00000020)
#define D3DPMISCCAPS_CULLCCW               __MSABI_LONG(0x00000040)
#define D3DPMISCCAPS_COLORWRITEENABLE      __MSABI_LONG(0x00000080)
#define D3DPMISCCAPS_CLIPPLANESCALEDPOINTS __MSABI_LONG(0x00000100)
#define D3DPMISCCAPS_CLIPTLVERTS           __MSABI_LONG(0x00000200)
#define D3DPMISCCAPS_TSSARGTEMP            __MSABI_LONG(0x00000400)
#define D3DPMISCCAPS_BLENDOP               __MSABI_LONG(0x00000800)
#define D3DPMISCCAPS_NULLREFERENCE         __MSABI_LONG(0x00001000)

#define D3DPRASTERCAPS_DITHER                     0x00000001
#define D3DPRASTERCAPS_PAT                        0x00000008
#define D3DPRASTERCAPS_ZTEST                      0x00000010
#define D3DPRASTERCAPS_FOGVERTEX                  0x00000080
#define D3DPRASTERCAPS_FOGTABLE                   0x00000100
#define D3DPRASTERCAPS_ANTIALIASEDGES             0x00001000
#define D3DPRASTERCAPS_MIPMAPLODBIAS              0x00002000
#define D3DPRASTERCAPS_ZBIAS                      0x00004000
#define D3DPRASTERCAPS_ZBUFFERLESSHSR             0x00008000
#define D3DPRASTERCAPS_FOGRANGE                   0x00010000
#define D3DPRASTERCAPS_ANISOTROPY                 0x00020000
#define D3DPRASTERCAPS_WBUFFER                    0x00040000
#define D3DPRASTERCAPS_WFOG                       0x00100000
#define D3DPRASTERCAPS_ZFOG                       0x00200000
#define D3DPRASTERCAPS_COLORPERSPECTIVE           0x00400000
#define D3DPRASTERCAPS_STRETCHBLTMULTISAMPLE      0x00800000

#define D3DPRESENT_INTERVAL_DEFAULT               0x00000000
#define D3DPRESENT_INTERVAL_ONE                   0x00000001
#define D3DPRESENT_INTERVAL_TWO                   0x00000002
#define D3DPRESENT_INTERVAL_THREE                 0x00000004
#define D3DPRESENT_INTERVAL_FOUR                  0x00000008
#define D3DPRESENT_INTERVAL_IMMEDIATE             0x80000000

#define D3DPSHADECAPS_COLORGOURAUDRGB             0x00008
#define D3DPSHADECAPS_SPECULARGOURAUDRGB          0x00200
#define D3DPSHADECAPS_ALPHAGOURAUDBLEND           0x04000
#define D3DPSHADECAPS_FOGGOURAUD                  0x80000

#define D3DPTADDRESSCAPS_WRAP                     0x01
#define D3DPTADDRESSCAPS_MIRROR                   0x02
#define D3DPTADDRESSCAPS_CLAMP                    0x04
#define D3DPTADDRESSCAPS_BORDER                   0x08
#define D3DPTADDRESSCAPS_INDEPENDENTUV            0x10
#define D3DPTADDRESSCAPS_MIRRORONCE               0x20

#define D3DPTEXTURECAPS_PERSPECTIVE              0x00001
#define D3DPTEXTURECAPS_POW2                     0x00002
#define D3DPTEXTURECAPS_ALPHA                    0x00004
#define D3DPTEXTURECAPS_SQUAREONLY               0x00020
#define D3DPTEXTURECAPS_TEXREPEATNOTSCALEDBYSIZE 0x00040
#define D3DPTEXTURECAPS_ALPHAPALETTE             0x00080
#define D3DPTEXTURECAPS_NONPOW2CONDITIONAL       0x00100
#define D3DPTEXTURECAPS_PROJECTED                0x00400
#define D3DPTEXTURECAPS_CUBEMAP                  0x00800
#define D3DPTEXTURECAPS_VOLUMEMAP                0x02000
#define D3DPTEXTURECAPS_MIPMAP                   0x04000
#define D3DPTEXTURECAPS_MIPVOLUMEMAP             0x08000
#define D3DPTEXTURECAPS_MIPCUBEMAP               0x10000
#define D3DPTEXTURECAPS_CUBEMAP_POW2             0x20000
#define D3DPTEXTURECAPS_VOLUMEMAP_POW2           0x40000

#define D3DPTFILTERCAPS_MINFPOINT                0x00000100
#define D3DPTFILTERCAPS_MINFLINEAR               0x00000200
#define D3DPTFILTERCAPS_MINFANISOTROPIC          0x00000400
#define D3DPTFILTERCAPS_MIPFPOINT                0x00010000
#define D3DPTFILTERCAPS_MIPFLINEAR               0x00020000
#define D3DPTFILTERCAPS_MAGFPOINT                0x01000000
#define D3DPTFILTERCAPS_MAGFLINEAR               0x02000000
#define D3DPTFILTERCAPS_MAGFANISOTROPIC          0x04000000
#define D3DPTFILTERCAPS_MAGFAFLATCUBIC           0x08000000
#define D3DPTFILTERCAPS_MAGFGAUSSIANCUBIC        0x10000000

#define D3DSTENCILCAPS_KEEP                      0x01
#define D3DSTENCILCAPS_ZERO                      0x02
#define D3DSTENCILCAPS_REPLACE                   0x04
#define D3DSTENCILCAPS_INCRSAT                   0x08
#define D3DSTENCILCAPS_DECRSAT                   0x10
#define D3DSTENCILCAPS_INVERT                    0x20
#define D3DSTENCILCAPS_INCR                      0x40
#define D3DSTENCILCAPS_DECR                      0x80

#define D3DTEXOPCAPS_DISABLE                     0x0000001
#define D3DTEXOPCAPS_SELECTARG1                  0x0000002
#define D3DTEXOPCAPS_SELECTARG2                  0x0000004
#define D3DTEXOPCAPS_MODULATE                    0x0000008
#define D3DTEXOPCAPS_MODULATE2X                  0x0000010
#define D3DTEXOPCAPS_MODULATE4X                  0x0000020
#define D3DTEXOPCAPS_ADD                         0x0000040
#define D3DTEXOPCAPS_ADDSIGNED                   0x0000080
#define D3DTEXOPCAPS_ADDSIGNED2X                 0x0000100
#define D3DTEXOPCAPS_SUBTRACT                    0x0000200
#define D3DTEXOPCAPS_ADDSMOOTH                   0x0000400
#define D3DTEXOPCAPS_BLENDDIFFUSEALPHA           0x0000800
#define D3DTEXOPCAPS_BLENDTEXTUREALPHA           0x0001000
#define D3DTEXOPCAPS_BLENDFACTORALPHA            0x0002000
#define D3DTEXOPCAPS_BLENDTEXTUREALPHAPM         0x0004000
#define D3DTEXOPCAPS_BLENDCURRENTALPHA           0x0008000
#define D3DTEXOPCAPS_PREMODULATE                 0x0010000
#define D3DTEXOPCAPS_MODULATEALPHA_ADDCOLOR      0x0020000
#define D3DTEXOPCAPS_MODULATECOLOR_ADDALPHA      0x0040000
#define D3DTEXOPCAPS_MODULATEINVALPHA_ADDCOLOR   0x0080000
#define D3DTEXOPCAPS_MODULATEINVCOLOR_ADDALPHA   0x0100000
#define D3DTEXOPCAPS_BUMPENVMAP                  0x0200000
#define D3DTEXOPCAPS_BUMPENVMAPLUMINANCE         0x0400000
#define D3DTEXOPCAPS_DOTPRODUCT3                 0x0800000
#define D3DTEXOPCAPS_MULTIPLYADD                 0x1000000
#define D3DTEXOPCAPS_LERP                        0x2000000

#define D3DVTXPCAPS_TEXGEN                       __MSABI_LONG(0x00000001)
#define D3DVTXPCAPS_MATERIALSOURCE7              __MSABI_LONG(0x00000002)
#define D3DVTXPCAPS_DIRECTIONALLIGHTS            __MSABI_LONG(0x00000008)
#define D3DVTXPCAPS_POSITIONALLIGHTS             __MSABI_LONG(0x00000010)
#define D3DVTXPCAPS_LOCALVIEWER                  __MSABI_LONG(0x00000020)
#define D3DVTXPCAPS_TWEENING                     __MSABI_LONG(0x00000040)
#define D3DVTXPCAPS_NO_VSDT_UBYTE4               __MSABI_LONG(0x00000080)

#define D3DCAPS3_ALPHA_FULLSCREEN_FLIP_OR_DISCARD  0x00000020
#define D3DCAPS3_RESERVED                          0x8000001f

#define D3DCAPS2_CANCALIBRATEGAMMA                 0x0100000
#define D3DCAPS2_CANRENDERWINDOWED                 0x0080000
#define D3DCAPS2_CANMANAGERESOURCE                 0x10000000
#define D3DCAPS2_DYNAMICTEXTURES                   0x20000000
#define D3DCAPS2_FULLSCREENGAMMA                   0x0020000
#define D3DCAPS2_NO2DDURING3DSCENE                 0x0000002
#define D3DCAPS2_RESERVED                          0x2000000

/*
 * The d3dcaps8 structure
 */
typedef struct _D3DCAPS8 {
    D3DDEVTYPE          DeviceType;
    UINT                AdapterOrdinal;

    DWORD               Caps;
    DWORD               Caps2;
    DWORD               Caps3;
    DWORD               PresentationIntervals;

    DWORD               CursorCaps;

    DWORD               DevCaps;

    DWORD               PrimitiveMiscCaps;
    DWORD               RasterCaps;
    DWORD               ZCmpCaps;
    DWORD               SrcBlendCaps;
    DWORD               DestBlendCaps;
    DWORD               AlphaCmpCaps;
    DWORD               ShadeCaps;
    DWORD               TextureCaps;
    DWORD               TextureFilterCaps;
    DWORD               CubeTextureFilterCaps;
    DWORD               VolumeTextureFilterCaps;
    DWORD               TextureAddressCaps;
    DWORD               VolumeTextureAddressCaps;

    DWORD               LineCaps;

    DWORD               MaxTextureWidth, MaxTextureHeight;
    DWORD               MaxVolumeExtent;

    DWORD               MaxTextureRepeat;
    DWORD               MaxTextureAspectRatio;
    DWORD               MaxAnisotropy;
    float               MaxVertexW;

    float               GuardBandLeft;
    float               GuardBandTop;
    float               GuardBandRight;
    float               GuardBandBottom;

    float               ExtentsAdjust;
    DWORD               StencilCaps;

    DWORD               FVFCaps;
    DWORD               TextureOpCaps;
    DWORD               MaxTextureBlendStages;
    DWORD               MaxSimultaneousTextures;

    DWORD               VertexProcessingCaps;
    DWORD               MaxActiveLights;
    DWORD               MaxUserClipPlanes;
    DWORD               MaxVertexBlendMatrices;
    DWORD               MaxVertexBlendMatrixIndex;

    float               MaxPointSize;

    DWORD               MaxPrimitiveCount;
    DWORD               MaxVertexIndex;
    DWORD               MaxStreams;
    DWORD               MaxStreamStride;

    DWORD               VertexShaderVersion;
    DWORD               MaxVertexShaderConst;

    DWORD               PixelShaderVersion;
    float               MaxPixelShaderValue;
} D3DCAPS8;

#ifdef __i386__
#include <poppack.h>
#endif

#endif  /* __WINE_D3D8CAPS_H */
