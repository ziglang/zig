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

#ifndef __WINE_D3D9CAPS_H
#define __WINE_D3D9CAPS_H

#ifdef __i386__
#include <pshpack4.h>
#endif

/*
 * Definitions
 */
#define D3DCAPS_OVERLAY       __MSABI_LONG(0x00000800)
#define D3DCAPS_READ_SCANLINE __MSABI_LONG(0x00020000)

#define D3DCURSORCAPS_COLOR   1
#define D3DCURSORCAPS_LOWRES  2


#define D3DDEVCAPS2_STREAMOFFSET                        __MSABI_LONG(0x00000001)
#define D3DDEVCAPS2_DMAPNPATCH                          __MSABI_LONG(0x00000002)
#define D3DDEVCAPS2_ADAPTIVETESSRTPATCH                 __MSABI_LONG(0x00000004)
#define D3DDEVCAPS2_ADAPTIVETESSNPATCH                  __MSABI_LONG(0x00000008)
#define D3DDEVCAPS2_CAN_STRETCHRECT_FROM_TEXTURES       __MSABI_LONG(0x00000010)
#define D3DDEVCAPS2_PRESAMPLEDDMAPNPATCH                __MSABI_LONG(0x00000020)
#define D3DDEVCAPS2_VERTEXELEMENTSCANSHARESTREAMOFFSET  __MSABI_LONG(0x00000040)

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
#define D3DLINECAPS_ANTIALIAS         0x20

#define D3DPBLENDCAPS_ZERO            __MSABI_LONG(0x00000001)
#define D3DPBLENDCAPS_ONE             __MSABI_LONG(0x00000002)
#define D3DPBLENDCAPS_SRCCOLOR        __MSABI_LONG(0x00000004)
#define D3DPBLENDCAPS_INVSRCCOLOR     __MSABI_LONG(0x00000008)
#define D3DPBLENDCAPS_SRCALPHA        __MSABI_LONG(0x00000010)
#define D3DPBLENDCAPS_INVSRCALPHA     __MSABI_LONG(0x00000020)
#define D3DPBLENDCAPS_DESTALPHA       __MSABI_LONG(0x00000040)
#define D3DPBLENDCAPS_INVDESTALPHA    __MSABI_LONG(0x00000080)
#define D3DPBLENDCAPS_DESTCOLOR       __MSABI_LONG(0x00000100)
#define D3DPBLENDCAPS_INVDESTCOLOR    __MSABI_LONG(0x00000200)
#define D3DPBLENDCAPS_SRCALPHASAT     __MSABI_LONG(0x00000400)
#define D3DPBLENDCAPS_BOTHSRCALPHA    __MSABI_LONG(0x00000800)
#define D3DPBLENDCAPS_BOTHINVSRCALPHA __MSABI_LONG(0x00001000)
#define D3DPBLENDCAPS_BLENDFACTOR     __MSABI_LONG(0x00002000)
#ifndef D3D_DISABLE_9EX
#define D3DPBLENDCAPS_SRCCOLOR2       __MSABI_LONG(0x00004000)
#define D3DPBLENDCAPS_INVSRCCOLOR2    __MSABI_LONG(0x00008000)
#endif

#define D3DPCMPCAPS_NEVER        0x01
#define D3DPCMPCAPS_LESS         0x02
#define D3DPCMPCAPS_EQUAL        0x04
#define D3DPCMPCAPS_LESSEQUAL    0x08
#define D3DPCMPCAPS_GREATER      0x10
#define D3DPCMPCAPS_NOTEQUAL     0x20
#define D3DPCMPCAPS_GREATEREQUAL 0x40
#define D3DPCMPCAPS_ALWAYS       0x80

#define D3DPMISCCAPS_MASKZ                      __MSABI_LONG(0x00000002)
#define D3DPMISCCAPS_LINEPATTERNREP             __MSABI_LONG(0x00000004)
#define D3DPMISCCAPS_CULLNONE                   __MSABI_LONG(0x00000010)
#define D3DPMISCCAPS_CULLCW                     __MSABI_LONG(0x00000020)
#define D3DPMISCCAPS_CULLCCW                    __MSABI_LONG(0x00000040)
#define D3DPMISCCAPS_COLORWRITEENABLE           __MSABI_LONG(0x00000080)
#define D3DPMISCCAPS_CLIPPLANESCALEDPOINTS      __MSABI_LONG(0x00000100)
#define D3DPMISCCAPS_CLIPTLVERTS                __MSABI_LONG(0x00000200)
#define D3DPMISCCAPS_TSSARGTEMP                 __MSABI_LONG(0x00000400)
#define D3DPMISCCAPS_BLENDOP                    __MSABI_LONG(0x00000800)
#define D3DPMISCCAPS_NULLREFERENCE              __MSABI_LONG(0x00001000)
#define D3DPMISCCAPS_INDEPENDENTWRITEMASKS      __MSABI_LONG(0x00004000)
#define D3DPMISCCAPS_PERSTAGECONSTANT           __MSABI_LONG(0x00008000)
#define D3DPMISCCAPS_FOGANDSPECULARALPHA        __MSABI_LONG(0x00010000)
#define D3DPMISCCAPS_SEPARATEALPHABLEND         __MSABI_LONG(0x00020000)
#define D3DPMISCCAPS_MRTINDEPENDENTBITDEPTHS    __MSABI_LONG(0x00040000)
#define D3DPMISCCAPS_MRTPOSTPIXELSHADERBLENDING __MSABI_LONG(0x00080000)
#define D3DPMISCCAPS_FOGVERTEXCLAMPED           __MSABI_LONG(0x00100000)
#ifndef D3D_DISABLE_9EX
#define D3DPMISCCAPS_POSTBLENDSRGBCONVERT       __MSABI_LONG(0x00200000)
#endif

#define D3DPRASTERCAPS_DITHER                     __MSABI_LONG(0x00000001)
#define D3DPRASTERCAPS_PAT                        __MSABI_LONG(0x00000008)
#define D3DPRASTERCAPS_ZTEST                      __MSABI_LONG(0x00000010)
#define D3DPRASTERCAPS_FOGVERTEX                  __MSABI_LONG(0x00000080)
#define D3DPRASTERCAPS_FOGTABLE                   __MSABI_LONG(0x00000100)
#define D3DPRASTERCAPS_ANTIALIASEDGES             __MSABI_LONG(0x00001000)
#define D3DPRASTERCAPS_MIPMAPLODBIAS              __MSABI_LONG(0x00002000)
#define D3DPRASTERCAPS_ZBIAS                      __MSABI_LONG(0x00004000)
#define D3DPRASTERCAPS_ZBUFFERLESSHSR             __MSABI_LONG(0x00008000)
#define D3DPRASTERCAPS_FOGRANGE                   __MSABI_LONG(0x00010000)
#define D3DPRASTERCAPS_ANISOTROPY                 __MSABI_LONG(0x00020000)
#define D3DPRASTERCAPS_WBUFFER                    __MSABI_LONG(0x00040000)
#define D3DPRASTERCAPS_WFOG                       __MSABI_LONG(0x00100000)
#define D3DPRASTERCAPS_ZFOG                       __MSABI_LONG(0x00200000)
#define D3DPRASTERCAPS_COLORPERSPECTIVE           __MSABI_LONG(0x00400000)
#define D3DPRASTERCAPS_SCISSORTEST                __MSABI_LONG(0x01000000)
#define D3DPRASTERCAPS_SLOPESCALEDEPTHBIAS        __MSABI_LONG(0x02000000)
#define D3DPRASTERCAPS_DEPTHBIAS                  __MSABI_LONG(0x04000000)
#define D3DPRASTERCAPS_MULTISAMPLE_TOGGLE         __MSABI_LONG(0x08000000)

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

#define D3DPTEXTURECAPS_PERSPECTIVE              __MSABI_LONG(0x00000001)
#define D3DPTEXTURECAPS_POW2                     __MSABI_LONG(0x00000002)
#define D3DPTEXTURECAPS_ALPHA                    __MSABI_LONG(0x00000004)
#define D3DPTEXTURECAPS_SQUAREONLY               __MSABI_LONG(0x00000020)
#define D3DPTEXTURECAPS_TEXREPEATNOTSCALEDBYSIZE __MSABI_LONG(0x00000040)
#define D3DPTEXTURECAPS_ALPHAPALETTE             __MSABI_LONG(0x00000080)
#define D3DPTEXTURECAPS_NONPOW2CONDITIONAL       __MSABI_LONG(0x00000100)
#define D3DPTEXTURECAPS_PROJECTED                __MSABI_LONG(0x00000400)
#define D3DPTEXTURECAPS_CUBEMAP                  __MSABI_LONG(0x00000800)
#define D3DPTEXTURECAPS_VOLUMEMAP                __MSABI_LONG(0x00002000)
#define D3DPTEXTURECAPS_MIPMAP                   __MSABI_LONG(0x00004000)
#define D3DPTEXTURECAPS_MIPVOLUMEMAP             __MSABI_LONG(0x00008000)
#define D3DPTEXTURECAPS_MIPCUBEMAP               __MSABI_LONG(0x00010000)
#define D3DPTEXTURECAPS_CUBEMAP_POW2             __MSABI_LONG(0x00020000)
#define D3DPTEXTURECAPS_VOLUMEMAP_POW2           __MSABI_LONG(0x00040000)
#define D3DPTEXTURECAPS_NOPROJECTEDBUMPENV       __MSABI_LONG(0x00200000)

#define D3DPTFILTERCAPS_MINFPOINT                __MSABI_LONG(0x00000100)
#define D3DPTFILTERCAPS_MINFLINEAR               __MSABI_LONG(0x00000200)
#define D3DPTFILTERCAPS_MINFANISOTROPIC          __MSABI_LONG(0x00000400)
#define D3DPTFILTERCAPS_MINFPYRAMIDALQUAD        __MSABI_LONG(0x00000800)
#define D3DPTFILTERCAPS_MINFGAUSSIANQUAD         __MSABI_LONG(0x00001000)
#define D3DPTFILTERCAPS_MIPFPOINT                __MSABI_LONG(0x00010000)
#define D3DPTFILTERCAPS_MIPFLINEAR               __MSABI_LONG(0x00020000)
#ifndef D3D_DISABLE_9EX
#define D3DPTFILTERCAPS_CONVOLUTIONMONO          __MSABI_LONG(0x00040000)
#endif
#define D3DPTFILTERCAPS_MAGFPOINT                __MSABI_LONG(0x01000000)
#define D3DPTFILTERCAPS_MAGFLINEAR               __MSABI_LONG(0x02000000)
#define D3DPTFILTERCAPS_MAGFANISOTROPIC          __MSABI_LONG(0x04000000)
#define D3DPTFILTERCAPS_MAGFPYRAMIDALQUAD        __MSABI_LONG(0x08000000)
#define D3DPTFILTERCAPS_MAGFGAUSSIANQUAD         __MSABI_LONG(0x10000000)

#define D3DSTENCILCAPS_KEEP                      0x01
#define D3DSTENCILCAPS_ZERO                      0x02
#define D3DSTENCILCAPS_REPLACE                   0x04
#define D3DSTENCILCAPS_INCRSAT                   0x08
#define D3DSTENCILCAPS_DECRSAT                   0x10
#define D3DSTENCILCAPS_INVERT                    0x20
#define D3DSTENCILCAPS_INCR                      0x40
#define D3DSTENCILCAPS_DECR                      0x80
#define D3DSTENCILCAPS_TWOSIDED                  0x100

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

#define D3DVTXPCAPS_TEXGEN                         __MSABI_LONG(0x00000001)
#define D3DVTXPCAPS_MATERIALSOURCE7                __MSABI_LONG(0x00000002)
#define D3DVTXPCAPS_DIRECTIONALLIGHTS              __MSABI_LONG(0x00000008)
#define D3DVTXPCAPS_POSITIONALLIGHTS               __MSABI_LONG(0x00000010)
#define D3DVTXPCAPS_LOCALVIEWER                    __MSABI_LONG(0x00000020)
#define D3DVTXPCAPS_TWEENING                       __MSABI_LONG(0x00000040)
#define D3DVTXPCAPS_TEXGEN_SPHEREMAP               __MSABI_LONG(0x00000100)
#define D3DVTXPCAPS_NO_TEXGEN_NONLOCALVIEWER       __MSABI_LONG(0x00000200)

#define D3DDTCAPS_UBYTE4                           __MSABI_LONG(0x00000001)
#define D3DDTCAPS_UBYTE4N                          __MSABI_LONG(0x00000002)
#define D3DDTCAPS_SHORT2N                          __MSABI_LONG(0x00000004)
#define D3DDTCAPS_SHORT4N                          __MSABI_LONG(0x00000008)
#define D3DDTCAPS_USHORT2N                         __MSABI_LONG(0x00000010)
#define D3DDTCAPS_USHORT4N                         __MSABI_LONG(0x00000020)
#define D3DDTCAPS_UDEC3                            __MSABI_LONG(0x00000040)
#define D3DDTCAPS_DEC3N                            __MSABI_LONG(0x00000080)
#define D3DDTCAPS_FLOAT16_2                        __MSABI_LONG(0x00000100)
#define D3DDTCAPS_FLOAT16_4                        __MSABI_LONG(0x00000200)

#define D3DCAPS3_ALPHA_FULLSCREEN_FLIP_OR_DISCARD  __MSABI_LONG(0x00000020)
#define D3DCAPS3_LINEAR_TO_SRGB_PRESENTATION       __MSABI_LONG(0x00000080)
#define D3DCAPS3_COPY_TO_VIDMEM                    __MSABI_LONG(0x00000100)
#define D3DCAPS3_COPY_TO_SYSTEMMEM                 __MSABI_LONG(0x00000200)
#define D3DCAPS3_DXVAHD                            __MSABI_LONG(0x00000400)
#define D3DCAPS3_DXVAHD_LIMITED                    __MSABI_LONG(0x00000800)
#define D3DCAPS3_RESERVED                          __MSABI_LONG(0x8000001F)

#define D3DCAPS2_NO2DDURING3DSCENE                 __MSABI_LONG(0x00000002)
#define D3DCAPS2_FULLSCREENGAMMA                   __MSABI_LONG(0x00020000)
#define D3DCAPS2_CANRENDERWINDOWED                 __MSABI_LONG(0x00080000)
#define D3DCAPS2_CANCALIBRATEGAMMA                 __MSABI_LONG(0x00100000)
#define D3DCAPS2_RESERVED                          __MSABI_LONG(0x02000000)
#define D3DCAPS2_CANMANAGERESOURCE                 __MSABI_LONG(0x10000000)
#define D3DCAPS2_DYNAMICTEXTURES                   __MSABI_LONG(0x20000000)
#define D3DCAPS2_CANAUTOGENMIPMAP                  __MSABI_LONG(0x40000000)
#ifndef D3D_DISABLE_9EX
#define D3DCAPS2_CANSHARERESOURCE                  __MSABI_LONG(0x80000000)
#endif

#define D3DVS20_MAX_DYNAMICFLOWCONTROLDEPTH  24
#define D3DVS20_MIN_DYNAMICFLOWCONTROLDEPTH  0
#define D3DVS20_MAX_NUMTEMPS                 32
#define D3DVS20_MIN_NUMTEMPS                 12
#define D3DVS20_MAX_STATICFLOWCONTROLDEPTH   4
#define D3DVS20_MIN_STATICFLOWCONTROLDEPTH   1

#define D3DVS20CAPS_PREDICATION              (1 << 0)

#define D3DPS20CAPS_ARBITRARYSWIZZLE         (1 << 0)
#define D3DPS20CAPS_GRADIENTINSTRUCTIONS     (1 << 1)
#define D3DPS20CAPS_PREDICATION              (1 << 2)
#define D3DPS20CAPS_NODEPENDENTREADLIMIT     (1 << 3)
#define D3DPS20CAPS_NOTEXINSTRUCTIONLIMIT    (1 << 4)

#define D3DPS20_MAX_DYNAMICFLOWCONTROLDEPTH  24
#define D3DPS20_MIN_DYNAMICFLOWCONTROLDEPTH  0
#define D3DPS20_MAX_NUMTEMPS                 32
#define D3DPS20_MIN_NUMTEMPS                 12
#define D3DPS20_MAX_STATICFLOWCONTROLDEPTH   4
#define D3DPS20_MIN_STATICFLOWCONTROLDEPTH   0
#define D3DPS20_MAX_NUMINSTRUCTIONSLOTS      512
#define D3DPS20_MIN_NUMINSTRUCTIONSLOTS      96

#define D3DMIN30SHADERINSTRUCTIONS          512
#define D3DMAX30SHADERINSTRUCTIONS          32768


typedef struct _D3DVSHADERCAPS2_0 {
  DWORD  Caps;
  INT    DynamicFlowControlDepth;
  INT    NumTemps;
  INT    StaticFlowControlDepth;
} D3DVSHADERCAPS2_0;

typedef struct _D3DPSHADERCAPS2_0 {
  DWORD  Caps;
  INT    DynamicFlowControlDepth;
  INT    NumTemps;
  INT    StaticFlowControlDepth;
  INT    NumInstructionSlots;
} D3DPSHADERCAPS2_0;

/*
 * The d3dcaps9 structure
 */
typedef struct _D3DCAPS9 {
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
  float               PixelShader1xMaxValue;

  /* DX 9 */
  DWORD               DevCaps2;

  float               MaxNpatchTessellationLevel;
  DWORD               Reserved5;

  UINT                MasterAdapterOrdinal;   
  UINT                AdapterOrdinalInGroup;  
  UINT                NumberOfAdaptersInGroup;
  DWORD               DeclTypes;              
  DWORD               NumSimultaneousRTs;     
  DWORD               StretchRectFilterCaps;  
  D3DVSHADERCAPS2_0   VS20Caps;
  D3DPSHADERCAPS2_0   PS20Caps;
  DWORD               VertexTextureFilterCaps;
  DWORD               MaxVShaderInstructionsExecuted;
  DWORD               MaxPShaderInstructionsExecuted;
  DWORD               MaxVertexShader30InstructionSlots; 
  DWORD               MaxPixelShader30InstructionSlots;

} D3DCAPS9;

#ifdef __i386__
#include <poppack.h>
#endif

#endif
