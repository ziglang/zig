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

#ifndef __WINE_D3D8TYPES_H
#define __WINE_D3D8TYPES_H

#ifdef __i386__
#pragma pack(push,4)
#endif

/*****************************************************************************
 * Direct 3D v8 #defines
 */

#define D3DCLEAR_TARGET   1
#define D3DCLEAR_ZBUFFER  2
#define D3DCLEAR_STENCIL  4

#define D3DCLIPPLANE0 (1 << 0)
#define D3DCLIPPLANE1 (1 << 1)
#define D3DCLIPPLANE2 (1 << 2)
#define D3DCLIPPLANE3 (1 << 3)
#define D3DCLIPPLANE4 (1 << 4)
#define D3DCLIPPLANE5 (1 << 5)

#define D3DCOLOR_ARGB(a,r,g,b)        ((D3DCOLOR)((((a)&0xffu)<<24)|(((r)&0xffu)<<16)|(((g)&0xffu)<<8)|((b)&0xffu)))
#define D3DCOLOR_COLORVALUE(r,g,b,a)  D3DCOLOR_RGBA((DWORD)((r)*255.f),(DWORD)((g)*255.f),(DWORD)((b)*255.f),(DWORD)((a)*255.f))
#define D3DCOLOR_RGBA(r,g,b,a)        D3DCOLOR_ARGB(a,r,g,b)
#define D3DCOLOR_XRGB(r,g,b)          D3DCOLOR_ARGB(0xff,r,g,b)

#define D3DCS_LEFT                 0x001
#define D3DCS_RIGHT                0x002
#define D3DCS_TOP                  0x004
#define D3DCS_BOTTOM               0x008
#define D3DCS_FRONT                0x010
#define D3DCS_BACK                 0x020
#define D3DCS_PLANE0               0x040
#define D3DCS_PLANE1               0x080
#define D3DCS_PLANE2               0x100
#define D3DCS_PLANE3               0x200
#define D3DCS_PLANE4               0x400
#define D3DCS_PLANE5               0x800
#define D3DCS_ALL                  0xFFF

#define D3DFVF_TEXTUREFORMAT1 3
#define D3DFVF_TEXTUREFORMAT2 0
#define D3DFVF_TEXTUREFORMAT3 1
#define D3DFVF_TEXTUREFORMAT4 2
#define D3DFVF_TEXCOORDSIZE1(CoordIndex) (D3DFVF_TEXTUREFORMAT1 << (CoordIndex*2 + 16))
#define D3DFVF_TEXCOORDSIZE2(CoordIndex) (D3DFVF_TEXTUREFORMAT2)
#define D3DFVF_TEXCOORDSIZE3(CoordIndex) (D3DFVF_TEXTUREFORMAT3 << (CoordIndex*2 + 16))
#define D3DFVF_TEXCOORDSIZE4(CoordIndex) (D3DFVF_TEXTUREFORMAT4 << (CoordIndex*2 + 16))

#define D3DLOCK_READONLY           0x0010
#define D3DLOCK_NOSYSLOCK          0x0800
#define D3DLOCK_NOOVERWRITE        0x1000
#define D3DLOCK_DISCARD            0x2000
#define D3DLOCK_NO_DIRTY_UPDATE    0x8000

#define D3DMAXUSERCLIPPLANES       32

#define D3DRENDERSTATE_WRAPBIAS    0x80

#define D3DTSS_TCI_PASSTHRU                       0x00000
#define D3DTSS_TCI_CAMERASPACENORMAL              0x10000
#define D3DTSS_TCI_CAMERASPACEPOSITION            0x20000
#define D3DTSS_TCI_CAMERASPACEREFLECTIONVECTOR    0x30000


#define D3DTS_WORLD  D3DTS_WORLDMATRIX(0)
#define D3DTS_WORLD1 D3DTS_WORLDMATRIX(1)
#define D3DTS_WORLD2 D3DTS_WORLDMATRIX(2)
#define D3DTS_WORLD3 D3DTS_WORLDMATRIX(3)
#define D3DTS_WORLDMATRIX(index) (D3DTRANSFORMSTATETYPE)(index + 256)

#define D3DUSAGE_RENDERTARGET       0x01
#define D3DUSAGE_DEPTHSTENCIL       0x02
#define D3DUSAGE_WRITEONLY          0x08
#define D3DUSAGE_SOFTWAREPROCESSING 0x10
#define D3DUSAGE_DONOTCLIP          0x20
#define D3DUSAGE_POINTS             0x40
#define D3DUSAGE_RTPATCHES          0x80
#define D3DUSAGE_NPATCHES           0x100
#define D3DUSAGE_DYNAMIC            0x200

#define D3DWRAP_U        1
#define D3DWRAP_V        2
#define D3DWRAP_W        4
#define D3DWRAPCOORD_0   1
#define D3DWRAPCOORD_1   2
#define D3DWRAPCOORD_2   4
#define D3DWRAPCOORD_3   8

#define MAX_DEVICE_IDENTIFIER_STRING        512

#define D3DFVF_RESERVED0           0x0001
#define D3DFVF_POSITION_MASK       0x000E
#define D3DFVF_XYZ                 0x0002
#define D3DFVF_XYZRHW              0x0004
#define D3DFVF_XYZB1               0x0006
#define D3DFVF_XYZB2               0x0008
#define D3DFVF_XYZB3               0x000a
#define D3DFVF_XYZB4               0x000c
#define D3DFVF_XYZB5               0x000e
#define D3DFVF_NORMAL              0x0010
#define D3DFVF_PSIZE               0x0020
#define D3DFVF_DIFFUSE             0x0040
#define D3DFVF_SPECULAR            0x0080
#define D3DFVF_TEXCOUNT_MASK       0x0f00
#define D3DFVF_TEXCOUNT_SHIFT           8
#define D3DFVF_TEX0                0x0000
#define D3DFVF_TEX1                0x0100
#define D3DFVF_TEX2                0x0200
#define D3DFVF_TEX3                0x0300
#define D3DFVF_TEX4                0x0400
#define D3DFVF_TEX5                0x0500
#define D3DFVF_TEX6                0x0600
#define D3DFVF_TEX7                0x0700
#define D3DFVF_TEX8                0x0800
#define D3DFVF_LASTBETA_UBYTE4     0x1000
#define D3DFVF_RESERVED2           0xE000

#define D3DTA_SELECTMASK        0x0000000f
#define D3DTA_DIFFUSE           0x00000000
#define D3DTA_CURRENT           0x00000001
#define D3DTA_TEXTURE           0x00000002
#define D3DTA_TFACTOR           0x00000003
#define D3DTA_SPECULAR          0x00000004
#define D3DTA_COMPLEMENT        0x00000010
#define D3DTA_ALPHAREPLICATE    0x00000020
#define D3DTA_TEMP              0x00000005

#define D3DCOLORWRITEENABLE_RED   (__MSABI_LONG(1)<<0)
#define D3DCOLORWRITEENABLE_GREEN (__MSABI_LONG(1)<<1)
#define D3DCOLORWRITEENABLE_BLUE  (__MSABI_LONG(1)<<2)
#define D3DCOLORWRITEENABLE_ALPHA (__MSABI_LONG(1)<<3)

#define D3DDEVINFOID_RESOURCEMANAGER 5
#define D3DDEVINFOID_VERTEXSTATS     6


#ifndef MAKEFOURCC
#define MAKEFOURCC(ch0, ch1, ch2, ch3)  \
    ((DWORD)(BYTE)(ch0) | ((DWORD)(BYTE)(ch1) << 8) |  \
    ((DWORD)(BYTE)(ch2) << 16) | ((DWORD)(BYTE)(ch3) << 24 ))
#endif

/**************************** 
 * Vertex Shaders Declaration
 */

typedef enum _D3DVSD_TOKENTYPE {
  D3DVSD_TOKEN_NOP         = 0,
  D3DVSD_TOKEN_STREAM      = 1,
  D3DVSD_TOKEN_STREAMDATA  = 2,
  D3DVSD_TOKEN_TESSELLATOR = 3,
  D3DVSD_TOKEN_CONSTMEM    = 4,
  D3DVSD_TOKEN_EXT         = 5,
  /* RESERVED              = 6 */
  D3DVSD_TOKEN_END         = 7,
  D3DVSD_FORCE_DWORD       = 0x7FFFFFFF
} D3DVSD_TOKENTYPE;

/** input registers for vertex shaders functions */
/*
#define D3DVSDE_POSITION      0
#define D3DVSDE_BLENDWEIGHT   1
#define D3DVSDE_BLENDINDICES  2
#define D3DVSDE_NORMAL        3
#define D3DVSDE_PSIZE         4
#define D3DVSDE_DIFFUSE       5
#define D3DVSDE_SPECULAR      6
#define D3DVSDE_TEXCOORD0     7
#define D3DVSDE_TEXCOORD1     8
#define D3DVSDE_TEXCOORD2     9
#define D3DVSDE_TEXCOORD3    10
#define D3DVSDE_TEXCOORD4    11
#define D3DVSDE_TEXCOORD5    12
#define D3DVSDE_TEXCOORD6    13
#define D3DVSDE_TEXCOORD7    14
#define D3DVSDE_POSITION2    15
#define D3DVSDE_NORMAL2      16
*/
/** Address of the vertex register. 0 - 16 */
typedef enum _D3DVSDE_REGISTER {
  D3DVSDE_POSITION     =  0,
  D3DVSDE_BLENDWEIGHT  =  1,
  D3DVSDE_BLENDINDICES =  2,
  D3DVSDE_NORMAL       =  3,
  D3DVSDE_PSIZE        =  4,
  D3DVSDE_DIFFUSE      =  5,
  D3DVSDE_SPECULAR     =  6,
  D3DVSDE_TEXCOORD0    =  7,
  D3DVSDE_TEXCOORD1    =  8,
  D3DVSDE_TEXCOORD2    =  9,
  D3DVSDE_TEXCOORD3    = 10,
  D3DVSDE_TEXCOORD4    = 11,
  D3DVSDE_TEXCOORD5    = 12,
  D3DVSDE_TEXCOORD6    = 13,
  D3DVSDE_TEXCOORD7    = 14,
  D3DVSDE_POSITION2    = 15,
  D3DVSDE_NORMAL2      = 16
} D3DVSDE_REGISTER;

/** bit-field declaration for VertexRegister Type */
/*
#define D3DVSDT_FLOAT1      0x00
#define D3DVSDT_FLOAT2      0x01
#define D3DVSDT_FLOAT3      0x02
#define D3DVSDT_FLOAT4      0x03
#define D3DVSDT_D3DCOLOR    0x04
#define D3DVSDT_UBYTE4      0x05
#define D3DVSDT_SHORT2      0x06
#define D3DVSDT_SHORT4      0x07
*/
typedef enum _D3DVSDT_TYPE {
  D3DVSDT_FLOAT1   = 0x00,
  D3DVSDT_FLOAT2   = 0x01,
  D3DVSDT_FLOAT3   = 0x02,
  D3DVSDT_FLOAT4   = 0x03,
  D3DVSDT_D3DCOLOR = 0x04,
  D3DVSDT_UBYTE4   = 0x05,
  D3DVSDT_SHORT2   = 0x06,
  D3DVSDT_SHORT4   = 0x07
} D3DVSDT_TYPE;


#define D3DVSD_CONSTADDRESSSHIFT  0
#define D3DVSD_EXTINFOSHIFT       0
#define D3DVSD_STREAMNUMBERSHIFT  0
#define D3DVSD_VERTEXREGSHIFT     0
#define D3DVSD_CONSTRSSHIFT      16
#define D3DVSD_DATATYPESHIFT     16
#define D3DVSD_SKIPCOUNTSHIFT    16
#define D3DVSD_VERTEXREGINSHIFT  20
#define D3DVSD_EXTCOUNTSHIFT     24
#define D3DVSD_CONSTCOUNTSHIFT   25
#define D3DVSD_DATALOADTYPESHIFT 28
#define D3DVSD_STREAMTESSSHIFT   28
#define D3DVSD_TOKENTYPESHIFT    29

#define D3DVSD_CONSTADDRESSMASK  (0x7F     << D3DVSD_CONSTADDRESSSHIFT)
#define D3DVSD_EXTINFOMASK       (0xFFFFFF << D3DVSD_EXTINFOSHIFT)
#define D3DVSD_STREAMNUMBERMASK  (0xF      << D3DVSD_STREAMNUMBERSHIFT)
#define D3DVSD_VERTEXREGMASK     (0x1F     << D3DVSD_VERTEXREGSHIFT)
#define D3DVSD_CONSTRSMASK       (0x1FFF   << D3DVSD_CONSTRSSHIFT)
#define D3DVSD_DATATYPEMASK      (0xF      << D3DVSD_DATATYPESHIFT)
#define D3DVSD_SKIPCOUNTMASK     (0xF      << D3DVSD_SKIPCOUNTSHIFT)
#define D3DVSD_EXTCOUNTMASK      (0x1F     << D3DVSD_EXTCOUNTSHIFT)
#define D3DVSD_VERTEXREGINMASK   (0xF      << D3DVSD_VERTEXREGINSHIFT)
#define D3DVSD_CONSTCOUNTMASK    (0xF      << D3DVSD_CONSTCOUNTSHIFT)
#define D3DVSD_DATALOADTYPEMASK  (0x1      << D3DVSD_DATALOADTYPESHIFT)
#define D3DVSD_STREAMTESSMASK    (0x1      << D3DVSD_STREAMTESSSHIFT)
#define D3DVSD_TOKENTYPEMASK     (0x7u     << D3DVSD_TOKENTYPESHIFT)


#define D3DVSD_MAKETOKENTYPE(TokenType) \
  (((unsigned)TokenType << D3DVSD_TOKENTYPESHIFT) & D3DVSD_TOKENTYPEMASK)

#define D3DVSD_CONST(ConstantAddress, Count) \
  (D3DVSD_MAKETOKENTYPE(D3DVSD_TOKEN_CONSTMEM) | ((Count) << D3DVSD_CONSTCOUNTSHIFT) | (ConstantAddress))

#define D3DVSD_END() 0xFFFFFFFF

#define D3DVSD_NOP() 0x00000000

#define D3DVSD_REG(VertexRegister, Type) \
  (D3DVSD_MAKETOKENTYPE(D3DVSD_TOKEN_STREAMDATA) | ((Type) << D3DVSD_DATATYPESHIFT) | (VertexRegister))

#define D3DVSD_SKIP(Count) \
  (D3DVSD_MAKETOKENTYPE(D3DVSD_TOKEN_STREAMDATA) | 0x10000000 | ((Count) << D3DVSD_SKIPCOUNTSHIFT))

#define D3DVSD_STREAM(StreamNumber) \
  (D3DVSD_MAKETOKENTYPE(D3DVSD_TOKEN_STREAM) | (StreamNumber))

#define D3DVSD_STREAM_TESS() \
  (D3DVSD_MAKETOKENTYPE(D3DVSD_TOKEN_STREAM) | (D3DVSD_STREAMTESSMASK))

#define D3DVSD_TESSNORMAL(RegisterIn, RegisterOut) \
  (D3DVSD_MAKETOKENTYPE(D3DVSD_TOKEN_TESSELLATOR) | ((RegisterIn) << D3DVSD_VERTEXREGINSHIFT) | ((0x02) << D3DVSD_DATATYPESHIFT) | (RegisterOut))

#define D3DVSD_TESSUV(Register) \
  (D3DVSD_MAKETOKENTYPE(D3DVSD_TOKEN_TESSELLATOR) | 0x10000000 | ((0x01) << D3DVSD_DATATYPESHIFT) | (Register))


/********************************
 * Pixel/Vertex Shaders Functions
 */

/** Maximum number of supported texture coordinates sets operation */
#define D3DDP_MAXTEXCOORD   8

/** opcode token mask */
#define D3DSI_OPCODE_MASK 0x0000FFFF

/** opcodes types for PS and VS */
typedef enum _D3DSHADER_INSTRUCTION_OPCODE_TYPE {
  D3DSIO_NOP          =  0,
  D3DSIO_MOV          =  1,
  D3DSIO_ADD          =  2,
  D3DSIO_SUB          =  3,
  D3DSIO_MAD          =  4,
  D3DSIO_MUL          =  5,
  D3DSIO_RCP          =  6,
  D3DSIO_RSQ          =  7,
  D3DSIO_DP3          =  8,
  D3DSIO_DP4          =  9,
  D3DSIO_MIN          = 10,
  D3DSIO_MAX          = 11,
  D3DSIO_SLT          = 12,
  D3DSIO_SGE          = 13,
  D3DSIO_EXP          = 14,
  D3DSIO_LOG          = 15,
  D3DSIO_LIT          = 16,
  D3DSIO_DST          = 17,
  D3DSIO_LRP          = 18,
  D3DSIO_FRC          = 19,
  D3DSIO_M4x4         = 20,
  D3DSIO_M4x3         = 21,
  D3DSIO_M3x4         = 22,
  D3DSIO_M3x3         = 23,
  D3DSIO_M3x2         = 24,

  D3DSIO_TEXCOORD     = 64,
  D3DSIO_TEXKILL      = 65,
  D3DSIO_TEX          = 66,
  D3DSIO_TEXBEM       = 67,
  D3DSIO_TEXBEML      = 68,
  D3DSIO_TEXREG2AR    = 69,
  D3DSIO_TEXREG2GB    = 70,
  D3DSIO_TEXM3x2PAD   = 71,
  D3DSIO_TEXM3x2TEX   = 72,
  D3DSIO_TEXM3x3PAD   = 73,
  D3DSIO_TEXM3x3TEX   = 74,
  D3DSIO_TEXM3x3DIFF  = 75,
  D3DSIO_TEXM3x3SPEC  = 76,
  D3DSIO_TEXM3x3VSPEC = 77,
  D3DSIO_EXPP         = 78,
  D3DSIO_LOGP         = 79,
  D3DSIO_CND          = 80,
  D3DSIO_DEF          = 81,
  D3DSIO_TEXREG2RGB   = 82,
  D3DSIO_TEXDP3TEX    = 83,
  D3DSIO_TEXM3x2DEPTH = 84,
  D3DSIO_TEXDP3       = 85,
  D3DSIO_TEXM3x3      = 86,
  D3DSIO_TEXDEPTH     = 87,
  D3DSIO_CMP          = 88,
  D3DSIO_BEM          = 89,

  D3DSIO_PHASE        = 0xFFFD,
  D3DSIO_COMMENT      = 0xFFFE,
  D3DSIO_END          = 0XFFFF,

  D3DSIO_FORCE_DWORD  = 0X7FFFFFFF /** for 32-bit alignment */
} D3DSHADER_INSTRUCTION_OPCODE_TYPE;

/** for parallelism */
#define D3DSI_COISSUE 0x40000000

/** destination parameter modifiers (.xyzw) */
#define D3DSP_WRITEMASK_0       0x00010000 /* .x r */
#define D3DSP_WRITEMASK_1       0x00020000 /* .y g */
#define D3DSP_WRITEMASK_2       0x00040000 /* .z b */
#define D3DSP_WRITEMASK_3       0x00080000 /* .w a */
#define D3DSP_WRITEMASK_ALL     0x000F0000 /* all */

#define D3DSP_DSTMOD_SHIFT      20
#define D3DSP_DSTMOD_MASK       (0xF << D3DSP_DSTMOD_SHIFT)

typedef enum _D3DSHADER_PARAM_DSTMOD_TYPE {
  D3DSPDM_NONE         = 0 << D3DSP_DSTMOD_SHIFT,
  D3DSPDM_SATURATE     = 1 << D3DSP_DSTMOD_SHIFT,
  D3DSPDM_FORCE_DWORD  = 0X7FFFFFFF
} D3DSHADER_PARAM_DSTMOD_TYPE;

/** destination param */
#define D3DSP_DSTSHIFT_SHIFT     24
#define D3DSP_DSTSHIFT_MASK      (0xF << D3DSP_DSTSHIFT_SHIFT)

/** destination/source reg type */
#define D3DSP_REGTYPE_SHIFT      28
#define D3DSP_REGTYPE_MASK       (0x7 << D3DSP_REGTYPE_SHIFT)

typedef enum _D3DSHADER_PARAM_REGISTER_TYPE {
  D3DSPR_TEMP         = 0 << D3DSP_REGTYPE_SHIFT,
  D3DSPR_INPUT        = 1 << D3DSP_REGTYPE_SHIFT,
  D3DSPR_CONST        = 2 << D3DSP_REGTYPE_SHIFT,
  D3DSPR_ADDR         = 3 << D3DSP_REGTYPE_SHIFT,
  D3DSPR_TEXTURE      = 3 << D3DSP_REGTYPE_SHIFT,
  D3DSPR_RASTOUT      = 4 << D3DSP_REGTYPE_SHIFT,
  D3DSPR_ATTROUT      = 5 << D3DSP_REGTYPE_SHIFT,
  D3DSPR_TEXCRDOUT    = 6 << D3DSP_REGTYPE_SHIFT,
  D3DSPR_FORCE_DWORD  = 0x7FFFFFFF
} D3DSHADER_PARAM_REGISTER_TYPE;

typedef enum _D3DVS_RASTOUT_OFFSETS {
  D3DSRO_POSITION     = 0,
  D3DSRO_FOG          = 1,
  D3DSRO_POINT_SIZE   = 2,
  D3DSRO_FORCE_DWORD  = 0x7FFFFFFF
} D3DVS_RASTOUT_OFFSETS;

#define D3DVS_ADDRESSMODE_SHIFT  13
#define D3DVS_ADDRESSMODE_MASK   (0x1 << D3DVS_ADDRESSMODE_SHIFT)

typedef enum _D3DVS_ADDRESSMODE_TYPE {
  D3DVS_ADDRMODE_ABSOLUTE     = 0 << D3DVS_ADDRESSMODE_SHIFT,
  D3DVS_ADDRMODE_RELATIVE     = 1 << D3DVS_ADDRESSMODE_SHIFT,
  D3DVS_ADDRMODE_FORCE_DWORD  = 0x7FFFFFFF
} D3DVS_ADDRESSMODE_TYPE;

#define D3DVS_SWIZZLE_SHIFT      16
#define D3DVS_SWIZZLE_MASK       (0xFF << D3DVS_SWIZZLE_SHIFT)

#define D3DSP_SWIZZLE_SHIFT      16
#define D3DSP_SWIZZLE_MASK       (0xFF << D3DSP_SWIZZLE_SHIFT)

#define D3DVS_X_X       (0 << D3DVS_SWIZZLE_SHIFT)
#define D3DVS_X_Y       (1 << D3DVS_SWIZZLE_SHIFT)
#define D3DVS_X_Z       (2 << D3DVS_SWIZZLE_SHIFT)
#define D3DVS_X_W       (3 << D3DVS_SWIZZLE_SHIFT)

#define D3DVS_Y_X       (0 << (D3DVS_SWIZZLE_SHIFT + 2))
#define D3DVS_Y_Y       (1 << (D3DVS_SWIZZLE_SHIFT + 2))
#define D3DVS_Y_Z       (2 << (D3DVS_SWIZZLE_SHIFT + 2))
#define D3DVS_Y_W       (3 << (D3DVS_SWIZZLE_SHIFT + 2))

#define D3DVS_Z_X       (0 << (D3DVS_SWIZZLE_SHIFT + 4))
#define D3DVS_Z_Y       (1 << (D3DVS_SWIZZLE_SHIFT + 4))
#define D3DVS_Z_Z       (2 << (D3DVS_SWIZZLE_SHIFT + 4))
#define D3DVS_Z_W       (3 << (D3DVS_SWIZZLE_SHIFT + 4))

#define D3DVS_W_X       (0 << (D3DVS_SWIZZLE_SHIFT + 6))
#define D3DVS_W_Y       (1 << (D3DVS_SWIZZLE_SHIFT + 6))
#define D3DVS_W_Z       (2 << (D3DVS_SWIZZLE_SHIFT + 6))
#define D3DVS_W_W       (3 << (D3DVS_SWIZZLE_SHIFT + 6))

#define D3DVS_NOSWIZZLE (D3DVS_X_X | D3DVS_Y_Y | D3DVS_Z_Z | D3DVS_W_W)

#define D3DSP_NOSWIZZLE \
    ((0 << (D3DSP_SWIZZLE_SHIFT + 0)) | (1 << (D3DSP_SWIZZLE_SHIFT + 2)) | (2 << (D3DSP_SWIZZLE_SHIFT + 4)) | (3 << (D3DSP_SWIZZLE_SHIFT + 6)))

#define D3DSP_SRCMOD_SHIFT      24
#define D3DSP_SRCMOD_MASK       (0xF << D3DSP_SRCMOD_SHIFT)

typedef enum _D3DSHADER_PARAM_SRCMOD_TYPE {
  D3DSPSM_NONE         =  0 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_NEG          =  1 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_BIAS         =  2 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_BIASNEG      =  3 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_SIGN         =  4 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_SIGNNEG      =  5 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_COMP         =  6 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_X2           =  7 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_X2NEG        =  8 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_DZ           =  9 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_DW           = 10 << D3DSP_SRCMOD_SHIFT,
  D3DSPSM_FORCE_DWORD  = 0x7FFFFFFF
} D3DSHADER_PARAM_SRCMOD_TYPE;

#define D3DPS_VERSION(major, minor) (0xFFFF0000 | ((major) << 8) | (minor))
#define D3DVS_VERSION(major, minor) (0xFFFE0000 | ((major) << 8) | (minor))
#define D3DSHADER_VERSION_MAJOR(version) (((version) >> 8) & 0xFF)
#define D3DSHADER_VERSION_MINOR(version) (((version) >> 0) & 0xFF)

#define D3DSI_COMMENTSIZE_SHIFT 16
#define D3DSI_COMMENTSIZE_MASK (0x7FFF << D3DSI_COMMENTSIZE_SHIFT)

#define D3DSHADER_COMMENT(commentSize) \
  ((((commentSize) << D3DSI_COMMENTSIZE_SHIFT) & D3DSI_COMMENTSIZE_MASK) | D3DSIO_COMMENT)

#define D3DPS_END() 0x0000FFFF
#define D3DVS_END() 0x0000FFFF


/*****************************************************************************
 * Direct 3D v8 enumerated types
 */
typedef enum _D3DBACKBUFFER_TYPE {
    D3DBACKBUFFER_TYPE_MONO         = 0,
    D3DBACKBUFFER_TYPE_LEFT         = 1,
    D3DBACKBUFFER_TYPE_RIGHT        = 2,

    D3DBACKBUFFER_TYPE_FORCE_DWORD  = 0x7fffffff
} D3DBACKBUFFER_TYPE;

typedef enum _D3DBASISTYPE{
   D3DBASIS_BEZIER        = 0,
   D3DBASIS_BSPLINE       = 1,
   D3DBASIS_INTERPOLATE   = 2,

   D3DBASIS_FORCE_DWORD   = 0x7fffffff
} D3DBASISTYPE;

typedef enum _D3DBLEND {
    D3DBLEND_ZERO               =  1,
    D3DBLEND_ONE                =  2,
    D3DBLEND_SRCCOLOR           =  3,
    D3DBLEND_INVSRCCOLOR        =  4,
    D3DBLEND_SRCALPHA           =  5,
    D3DBLEND_INVSRCALPHA        =  6,
    D3DBLEND_DESTALPHA          =  7,
    D3DBLEND_INVDESTALPHA       =  8,
    D3DBLEND_DESTCOLOR          =  9,
    D3DBLEND_INVDESTCOLOR       = 10,
    D3DBLEND_SRCALPHASAT        = 11,
    D3DBLEND_BOTHSRCALPHA       = 12,
    D3DBLEND_BOTHINVSRCALPHA    = 13,

    D3DBLEND_FORCE_DWORD        = 0x7fffffff
} D3DBLEND;

typedef enum _D3DBLENDOP {
    D3DBLENDOP_ADD              = 1,
    D3DBLENDOP_SUBTRACT         = 2,
    D3DBLENDOP_REVSUBTRACT      = 3,
    D3DBLENDOP_MIN              = 4,
    D3DBLENDOP_MAX              = 5,

    D3DBLENDOP_FORCE_DWORD      = 0x7fffffff
} D3DBLENDOP;

typedef enum _D3DCMPFUNC {
    D3DCMP_NEVER                = 1,
    D3DCMP_LESS                 = 2,
    D3DCMP_EQUAL                = 3,
    D3DCMP_LESSEQUAL            = 4,
    D3DCMP_GREATER              = 5,
    D3DCMP_NOTEQUAL             = 6,
    D3DCMP_GREATEREQUAL         = 7,
    D3DCMP_ALWAYS               = 8,

    D3DCMP_FORCE_DWORD          = 0x7fffffff
} D3DCMPFUNC;

typedef enum _D3DCUBEMAP_FACES {
    D3DCUBEMAP_FACE_POSITIVE_X     = 0,
    D3DCUBEMAP_FACE_NEGATIVE_X     = 1,
    D3DCUBEMAP_FACE_POSITIVE_Y     = 2,
    D3DCUBEMAP_FACE_NEGATIVE_Y     = 3,
    D3DCUBEMAP_FACE_POSITIVE_Z     = 4,
    D3DCUBEMAP_FACE_NEGATIVE_Z     = 5,

    D3DCUBEMAP_FACE_FORCE_DWORD    = 0xffffffff
} D3DCUBEMAP_FACES;

typedef enum _D3DCULL {
    D3DCULL_NONE                = 1,
    D3DCULL_CW                  = 2,
    D3DCULL_CCW                 = 3,

    D3DCULL_FORCE_DWORD         = 0x7fffffff
} D3DCULL;

typedef enum _D3DDEBUGMONITORTOKENS {
    D3DDMT_ENABLE          = 0,
    D3DDMT_DISABLE         = 1,

    D3DDMT_FORCE_DWORD     = 0x7fffffff
} D3DDEBUGMONITORTOKENS;

typedef enum _D3DDEVTYPE {
    D3DDEVTYPE_HAL         = 1,
    D3DDEVTYPE_REF         = 2,
    D3DDEVTYPE_SW          = 3,

    D3DDEVTYPE_FORCE_DWORD = 0xffffffff
} D3DDEVTYPE;

typedef enum _D3DFILLMODE {
    D3DFILL_POINT               = 1,
    D3DFILL_WIREFRAME           = 2,
    D3DFILL_SOLID               = 3,

    D3DFILL_FORCE_DWORD         = 0x7fffffff
} D3DFILLMODE;

typedef enum _D3DFOGMODE {
    D3DFOG_NONE                 = 0,
    D3DFOG_EXP                  = 1,
    D3DFOG_EXP2                 = 2,
    D3DFOG_LINEAR               = 3,

    D3DFOG_FORCE_DWORD          = 0x7fffffff
} D3DFOGMODE;

typedef enum _D3DFORMAT {
    D3DFMT_UNKNOWN              =   0,

    D3DFMT_R8G8B8               =  20,
    D3DFMT_A8R8G8B8             =  21,
    D3DFMT_X8R8G8B8             =  22,
    D3DFMT_R5G6B5               =  23,
    D3DFMT_X1R5G5B5             =  24,
    D3DFMT_A1R5G5B5             =  25,
    D3DFMT_A4R4G4B4             =  26,
    D3DFMT_R3G3B2               =  27,
    D3DFMT_A8                   =  28,
    D3DFMT_A8R3G3B2             =  29,
    D3DFMT_X4R4G4B4             =  30,
    D3DFMT_A2B10G10R10          =  31,
    D3DFMT_G16R16               =  34,

    D3DFMT_A8P8                 =  40,
    D3DFMT_P8                   =  41,

    D3DFMT_L8                   =  50,
    D3DFMT_A8L8                 =  51,
    D3DFMT_A4L4                 =  52,

    D3DFMT_V8U8                 =  60,
    D3DFMT_L6V5U5               =  61,
    D3DFMT_X8L8V8U8             =  62,
    D3DFMT_Q8W8V8U8             =  63,
    D3DFMT_V16U16               =  64,
    D3DFMT_W11V11U10            =  65,
    D3DFMT_A2W10V10U10          =  67,

    D3DFMT_UYVY                 =  MAKEFOURCC('U', 'Y', 'V', 'Y'),
    D3DFMT_YUY2                 =  MAKEFOURCC('Y', 'U', 'Y', '2'),
    D3DFMT_DXT1                 =  MAKEFOURCC('D', 'X', 'T', '1'),
    D3DFMT_DXT2                 =  MAKEFOURCC('D', 'X', 'T', '2'),
    D3DFMT_DXT3                 =  MAKEFOURCC('D', 'X', 'T', '3'),
    D3DFMT_DXT4                 =  MAKEFOURCC('D', 'X', 'T', '4'),
    D3DFMT_DXT5                 =  MAKEFOURCC('D', 'X', 'T', '5'),

    D3DFMT_D16_LOCKABLE         =  70,
    D3DFMT_D32                  =  71,
    D3DFMT_D15S1                =  73,
    D3DFMT_D24S8                =  75,
    D3DFMT_D16                  =  80,
    D3DFMT_D24X8                =  77,
    D3DFMT_D24X4S4              =  79,

    D3DFMT_VERTEXDATA           = 100,
    D3DFMT_INDEX16              = 101,
    D3DFMT_INDEX32              = 102,

    D3DFMT_FORCE_DWORD          = 0xFFFFFFFF
} D3DFORMAT;

typedef enum _D3DLIGHTTYPE {
    D3DLIGHT_POINT          = 1,
    D3DLIGHT_SPOT           = 2,
    D3DLIGHT_DIRECTIONAL    = 3,

    D3DLIGHT_FORCE_DWORD    = 0x7fffffff
} D3DLIGHTTYPE;

typedef enum _D3DMATERIALCOLORSOURCE {
    D3DMCS_MATERIAL         = 0,
    D3DMCS_COLOR1           = 1,
    D3DMCS_COLOR2           = 2,

    D3DMCS_FORCE_DWORD      = 0x7fffffff
} D3DMATERIALCOLORSOURCE;

typedef enum _D3DMULTISAMPLE_TYPE {
    D3DMULTISAMPLE_NONE            =  0,
    D3DMULTISAMPLE_2_SAMPLES       =  2,
    D3DMULTISAMPLE_3_SAMPLES       =  3,
    D3DMULTISAMPLE_4_SAMPLES       =  4,
    D3DMULTISAMPLE_5_SAMPLES       =  5,
    D3DMULTISAMPLE_6_SAMPLES       =  6,
    D3DMULTISAMPLE_7_SAMPLES       =  7,
    D3DMULTISAMPLE_8_SAMPLES       =  8,
    D3DMULTISAMPLE_9_SAMPLES       =  9,
    D3DMULTISAMPLE_10_SAMPLES      = 10,
    D3DMULTISAMPLE_11_SAMPLES      = 11,
    D3DMULTISAMPLE_12_SAMPLES      = 12,
    D3DMULTISAMPLE_13_SAMPLES      = 13,
    D3DMULTISAMPLE_14_SAMPLES      = 14,
    D3DMULTISAMPLE_15_SAMPLES      = 15,
    D3DMULTISAMPLE_16_SAMPLES      = 16,

    D3DMULTISAMPLE_FORCE_DWORD     = 0x7fffffff
} D3DMULTISAMPLE_TYPE;

typedef enum _D3DORDERTYPE {
   D3DORDER_LINEAR      = 1,
   D3DORDER_QUADRATIC   = 2,
   D3DORDER_CUBIC       = 3,
   D3DORDER_QUINTIC     = 5,

   D3DORDER_FORCE_DWORD = 0x7fffffff
} D3DORDERTYPE;

typedef enum _D3DPATCHEDGESTYLE {
   D3DPATCHEDGE_DISCRETE    = 0,
   D3DPATCHEDGE_CONTINUOUS  = 1,

   D3DPATCHEDGE_FORCE_DWORD = 0x7fffffff,
} D3DPATCHEDGESTYLE;

typedef enum _D3DPOOL {
    D3DPOOL_DEFAULT                 = 0,
    D3DPOOL_MANAGED                 = 1,
    D3DPOOL_SYSTEMMEM               = 2,
    D3DPOOL_SCRATCH                 = 3,

    D3DPOOL_FORCE_DWORD             = 0x7fffffff
} D3DPOOL;

typedef enum _D3DPRIMITIVETYPE {
    D3DPT_POINTLIST             = 1,
    D3DPT_LINELIST              = 2,
    D3DPT_LINESTRIP             = 3,
    D3DPT_TRIANGLELIST          = 4,
    D3DPT_TRIANGLESTRIP         = 5,
    D3DPT_TRIANGLEFAN           = 6,

    D3DPT_FORCE_DWORD           = 0x7fffffff
} D3DPRIMITIVETYPE;

typedef enum _D3DRENDERSTATETYPE {
    D3DRS_ZENABLE                   =   7,
    D3DRS_FILLMODE                  =   8,
    D3DRS_SHADEMODE                 =   9,
    D3DRS_LINEPATTERN               =  10,
    D3DRS_ZWRITEENABLE              =  14,
    D3DRS_ALPHATESTENABLE           =  15,
    D3DRS_LASTPIXEL                 =  16,
    D3DRS_SRCBLEND                  =  19,
    D3DRS_DESTBLEND                 =  20,
    D3DRS_CULLMODE                  =  22,
    D3DRS_ZFUNC                     =  23,
    D3DRS_ALPHAREF                  =  24,
    D3DRS_ALPHAFUNC                 =  25,
    D3DRS_DITHERENABLE              =  26,
    D3DRS_ALPHABLENDENABLE          =  27,
    D3DRS_FOGENABLE                 =  28,
    D3DRS_SPECULARENABLE            =  29,
    D3DRS_ZVISIBLE                  =  30,
    D3DRS_FOGCOLOR                  =  34,
    D3DRS_FOGTABLEMODE              =  35,
    D3DRS_FOGSTART                  =  36,
    D3DRS_FOGEND                    =  37,
    D3DRS_FOGDENSITY                =  38,
    D3DRS_EDGEANTIALIAS             =  40,
    D3DRS_ZBIAS                     =  47,
    D3DRS_RANGEFOGENABLE            =  48,
    D3DRS_STENCILENABLE             =  52,
    D3DRS_STENCILFAIL               =  53,
    D3DRS_STENCILZFAIL              =  54,
    D3DRS_STENCILPASS               =  55,
    D3DRS_STENCILFUNC               =  56,
    D3DRS_STENCILREF                =  57,
    D3DRS_STENCILMASK               =  58,
    D3DRS_STENCILWRITEMASK          =  59,
    D3DRS_TEXTUREFACTOR             =  60,
    D3DRS_WRAP0                     = 128,
    D3DRS_WRAP1                     = 129,
    D3DRS_WRAP2                     = 130,
    D3DRS_WRAP3                     = 131,
    D3DRS_WRAP4                     = 132,
    D3DRS_WRAP5                     = 133,
    D3DRS_WRAP6                     = 134,
    D3DRS_WRAP7                     = 135,
    D3DRS_CLIPPING                  = 136,
    D3DRS_LIGHTING                  = 137,
    D3DRS_AMBIENT                   = 139,
    D3DRS_FOGVERTEXMODE             = 140,
    D3DRS_COLORVERTEX               = 141,
    D3DRS_LOCALVIEWER               = 142,
    D3DRS_NORMALIZENORMALS          = 143,
    D3DRS_DIFFUSEMATERIALSOURCE     = 145,
    D3DRS_SPECULARMATERIALSOURCE    = 146,
    D3DRS_AMBIENTMATERIALSOURCE     = 147,
    D3DRS_EMISSIVEMATERIALSOURCE    = 148,
    D3DRS_VERTEXBLEND               = 151,
    D3DRS_CLIPPLANEENABLE           = 152,
    D3DRS_SOFTWAREVERTEXPROCESSING  = 153,
    D3DRS_POINTSIZE                 = 154,
    D3DRS_POINTSIZE_MIN             = 155,
    D3DRS_POINTSPRITEENABLE         = 156,
    D3DRS_POINTSCALEENABLE          = 157,
    D3DRS_POINTSCALE_A              = 158,
    D3DRS_POINTSCALE_B              = 159,
    D3DRS_POINTSCALE_C              = 160,
    D3DRS_MULTISAMPLEANTIALIAS      = 161,
    D3DRS_MULTISAMPLEMASK           = 162,
    D3DRS_PATCHEDGESTYLE            = 163,
    D3DRS_PATCHSEGMENTS             = 164,
    D3DRS_DEBUGMONITORTOKEN         = 165,
    D3DRS_POINTSIZE_MAX             = 166,
    D3DRS_INDEXEDVERTEXBLENDENABLE  = 167,
    D3DRS_COLORWRITEENABLE          = 168,
    D3DRS_TWEENFACTOR               = 170,
    D3DRS_BLENDOP                   = 171,
    D3DRS_POSITIONORDER             = 172,
    D3DRS_NORMALORDER               = 173,

    D3DRS_FORCE_DWORD               = 0x7fffffff
} D3DRENDERSTATETYPE;

typedef enum _D3DRESOURCETYPE {
    D3DRTYPE_SURFACE                =  1,
    D3DRTYPE_VOLUME                 =  2,
    D3DRTYPE_TEXTURE                =  3,
    D3DRTYPE_VOLUMETEXTURE          =  4,
    D3DRTYPE_CUBETEXTURE            =  5,
    D3DRTYPE_VERTEXBUFFER           =  6,
    D3DRTYPE_INDEXBUFFER            =  7,

    D3DRTYPE_FORCE_DWORD            = 0x7fffffff
} D3DRESOURCETYPE;

typedef enum _D3DSHADEMODE {
    D3DSHADE_FLAT               = 1,
    D3DSHADE_GOURAUD            = 2,
    D3DSHADE_PHONG              = 3,

    D3DSHADE_FORCE_DWORD        = 0x7fffffff
} D3DSHADEMODE;

typedef enum _D3DSTATEBLOCKTYPE {
    D3DSBT_ALL           = 1,
    D3DSBT_PIXELSTATE    = 2,
    D3DSBT_VERTEXSTATE   = 3,

    D3DSBT_FORCE_DWORD   = 0xffffffff
} D3DSTATEBLOCKTYPE;

typedef enum _D3DSTENCILOP {
    D3DSTENCILOP_KEEP           = 1,
    D3DSTENCILOP_ZERO           = 2,
    D3DSTENCILOP_REPLACE        = 3,
    D3DSTENCILOP_INCRSAT        = 4,
    D3DSTENCILOP_DECRSAT        = 5,
    D3DSTENCILOP_INVERT         = 6,
    D3DSTENCILOP_INCR           = 7,
    D3DSTENCILOP_DECR           = 8,

    D3DSTENCILOP_FORCE_DWORD    = 0x7fffffff
} D3DSTENCILOP;

typedef enum _D3DSWAPEFFECT {
    D3DSWAPEFFECT_DISCARD         = 1,
    D3DSWAPEFFECT_FLIP            = 2,
    D3DSWAPEFFECT_COPY            = 3,
    D3DSWAPEFFECT_COPY_VSYNC      = 4,

    D3DSWAPEFFECT_FORCE_DWORD     = 0xFFFFFFFF
} D3DSWAPEFFECT;

typedef enum _D3DTEXTUREADDRESS {
    D3DTADDRESS_WRAP            = 1,
    D3DTADDRESS_MIRROR          = 2,
    D3DTADDRESS_CLAMP           = 3,
    D3DTADDRESS_BORDER          = 4,
    D3DTADDRESS_MIRRORONCE      = 5,

    D3DTADDRESS_FORCE_DWORD     = 0x7fffffff
} D3DTEXTUREADDRESS;

typedef enum _D3DTEXTUREFILTERTYPE {
    D3DTEXF_NONE            = 0,
    D3DTEXF_POINT           = 1,
    D3DTEXF_LINEAR          = 2,
    D3DTEXF_ANISOTROPIC     = 3,
    D3DTEXF_FLATCUBIC       = 4,
    D3DTEXF_GAUSSIANCUBIC   = 5,

    D3DTEXF_FORCE_DWORD     = 0x7fffffff
} D3DTEXTUREFILTERTYPE;

typedef enum _D3DTEXTUREOP {
    D3DTOP_DISABLE                   =  1,
    D3DTOP_SELECTARG1                =  2,
    D3DTOP_SELECTARG2                =  3,
    D3DTOP_MODULATE                  =  4,
    D3DTOP_MODULATE2X                =  5,
    D3DTOP_MODULATE4X                =  6,
    D3DTOP_ADD                       =  7,
    D3DTOP_ADDSIGNED                 =  8,
    D3DTOP_ADDSIGNED2X               =  9,
    D3DTOP_SUBTRACT                  = 10,
    D3DTOP_ADDSMOOTH                 = 11,
    D3DTOP_BLENDDIFFUSEALPHA         = 12,
    D3DTOP_BLENDTEXTUREALPHA         = 13,
    D3DTOP_BLENDFACTORALPHA          = 14,
    D3DTOP_BLENDTEXTUREALPHAPM       = 15,
    D3DTOP_BLENDCURRENTALPHA         = 16,
    D3DTOP_PREMODULATE               = 17,
    D3DTOP_MODULATEALPHA_ADDCOLOR    = 18,
    D3DTOP_MODULATECOLOR_ADDALPHA    = 19,
    D3DTOP_MODULATEINVALPHA_ADDCOLOR = 20,
    D3DTOP_MODULATEINVCOLOR_ADDALPHA = 21,
    D3DTOP_BUMPENVMAP                = 22,
    D3DTOP_BUMPENVMAPLUMINANCE       = 23,
    D3DTOP_DOTPRODUCT3               = 24,
    D3DTOP_MULTIPLYADD               = 25,
    D3DTOP_LERP                      = 26,

    D3DTOP_FORCE_DWORD               = 0x7fffffff,
} D3DTEXTUREOP;

typedef enum _D3DTEXTURESTAGESTATETYPE {
    D3DTSS_COLOROP               =  1,
    D3DTSS_COLORARG1             =  2,
    D3DTSS_COLORARG2             =  3,
    D3DTSS_ALPHAOP               =  4,
    D3DTSS_ALPHAARG1             =  5,
    D3DTSS_ALPHAARG2             =  6,
    D3DTSS_BUMPENVMAT00          =  7,
    D3DTSS_BUMPENVMAT01          =  8,
    D3DTSS_BUMPENVMAT10          =  9,
    D3DTSS_BUMPENVMAT11          = 10,
    D3DTSS_TEXCOORDINDEX         = 11,
    D3DTSS_ADDRESSU              = 13,
    D3DTSS_ADDRESSV              = 14,
    D3DTSS_BORDERCOLOR           = 15,
    D3DTSS_MAGFILTER             = 16,
    D3DTSS_MINFILTER             = 17,
    D3DTSS_MIPFILTER             = 18,
    D3DTSS_MIPMAPLODBIAS         = 19,
    D3DTSS_MAXMIPLEVEL           = 20,
    D3DTSS_MAXANISOTROPY         = 21,
    D3DTSS_BUMPENVLSCALE         = 22,
    D3DTSS_BUMPENVLOFFSET        = 23,
    D3DTSS_TEXTURETRANSFORMFLAGS = 24,
    D3DTSS_ADDRESSW              = 25,
    D3DTSS_COLORARG0             = 26,
    D3DTSS_ALPHAARG0             = 27,
    D3DTSS_RESULTARG             = 28,

    D3DTSS_FORCE_DWORD           = 0x7fffffff
} D3DTEXTURESTAGESTATETYPE;

typedef enum _D3DTEXTURETRANSFORMFLAGS {
    D3DTTFF_DISABLE         =   0,
    D3DTTFF_COUNT1          =   1,
    D3DTTFF_COUNT2          =   2,
    D3DTTFF_COUNT3          =   3,
    D3DTTFF_COUNT4          =   4,
    D3DTTFF_PROJECTED       = 256,

    D3DTTFF_FORCE_DWORD     = 0x7fffffff
} D3DTEXTURETRANSFORMFLAGS;

typedef enum _D3DTRANSFORMSTATETYPE {
    D3DTS_VIEW            =  2,
    D3DTS_PROJECTION      =  3,
    D3DTS_TEXTURE0        = 16,
    D3DTS_TEXTURE1        = 17,
    D3DTS_TEXTURE2        = 18,
    D3DTS_TEXTURE3        = 19,
    D3DTS_TEXTURE4        = 20,
    D3DTS_TEXTURE5        = 21,
    D3DTS_TEXTURE6        = 22,
    D3DTS_TEXTURE7        = 23,

    D3DTS_FORCE_DWORD     = 0x7fffffff
} D3DTRANSFORMSTATETYPE;

typedef enum _D3DVERTEXBLENDFLAGS {
    D3DVBF_DISABLE  =   0,
    D3DVBF_1WEIGHTS =   1,
    D3DVBF_2WEIGHTS =   2,
    D3DVBF_3WEIGHTS =   3,
    D3DVBF_TWEENING = 255,
    D3DVBF_0WEIGHTS = 256
} D3DVERTEXBLENDFLAGS;

typedef enum _D3DZBUFFERTYPE {
    D3DZB_FALSE                 = 0,
    D3DZB_TRUE                  = 1,
    D3DZB_USEW                  = 2,

    D3DZB_FORCE_DWORD           = 0x7fffffff
} D3DZBUFFERTYPE;


/*****************************************************************************
 * Direct 3D v8 typedefs
 */
typedef DWORD D3DCOLOR;

/*****************************************************************************
 * Direct 3D v8 structures
 */
typedef struct _D3DADAPTER_IDENTIFIER8 {
    char            Driver[MAX_DEVICE_IDENTIFIER_STRING];
    char            Description[MAX_DEVICE_IDENTIFIER_STRING];

    LARGE_INTEGER   DriverVersion;
    DWORD           VendorId;
    DWORD           DeviceId;
    DWORD           SubSysId;
    DWORD           Revision;

    GUID            DeviceIdentifier;

    DWORD           WHQLLevel;
} D3DADAPTER_IDENTIFIER8;

typedef struct _D3DBOX {
    UINT                Left;
    UINT                Top;
    UINT                Right;
    UINT                Bottom;
    UINT                Front;
    UINT                Back;
} D3DBOX;

typedef struct _D3DCLIPSTATUS8 {
   DWORD ClipUnion;
   DWORD ClipIntersection;
} D3DCLIPSTATUS8;

typedef struct _D3DCOLORVALUE {
    float r;
    float g;
    float b;
    float a;
} D3DCOLORVALUE;

typedef struct _D3DDEVICE_CREATION_PARAMETERS {
    UINT          AdapterOrdinal;
    D3DDEVTYPE    DeviceType;
    HWND          hFocusWindow;
    DWORD         BehaviorFlags;
} D3DDEVICE_CREATION_PARAMETERS;

typedef struct _D3DDISPLAYMODE {
    UINT            Width;
    UINT            Height;
    UINT            RefreshRate;
    D3DFORMAT       Format;
} D3DDISPLAYMODE;

typedef struct _D3DGAMMARAMP {
    WORD                red  [256];
    WORD                green[256];
    WORD                blue [256];
} D3DGAMMARAMP;

typedef struct _D3DINDEXBUFFER_DESC {
    D3DFORMAT           Format;
    D3DRESOURCETYPE     Type;
    DWORD               Usage;
    D3DPOOL             Pool;
    UINT                Size;
} D3DINDEXBUFFER_DESC;

#ifndef D3DVECTOR_DEFINED
typedef struct _D3DVECTOR {
    float x;
    float y;
    float z;
} D3DVECTOR;
#define D3DVECTOR_DEFINED
#endif

typedef struct _D3DLIGHT8 {
    D3DLIGHTTYPE    Type;
    D3DCOLORVALUE   Diffuse;
    D3DCOLORVALUE   Specular;
    D3DCOLORVALUE   Ambient;
    D3DVECTOR       Position;
    D3DVECTOR       Direction;
    float           Range;
    float           Falloff;
    float           Attenuation0;
    float           Attenuation1;
    float           Attenuation2;
    float           Theta;
    float           Phi;
} D3DLIGHT8;

typedef struct _D3DLINEPATTERN {
    WORD    wRepeatFactor;
    WORD    wLinePattern;
} D3DLINEPATTERN;

typedef struct _D3DLOCKED_BOX {
    INT                 RowPitch;
    INT                 SlicePitch;
    void*               pBits;
} D3DLOCKED_BOX;

typedef struct _D3DLOCKED_RECT {
    INT                 Pitch;
    void*               pBits;
} D3DLOCKED_RECT;

typedef struct _D3DMATERIAL8 {
    D3DCOLORVALUE   Diffuse;
    D3DCOLORVALUE   Ambient;
    D3DCOLORVALUE   Specular;
    D3DCOLORVALUE   Emissive;
    float           Power;
} D3DMATERIAL8;

typedef struct _D3DMATRIX {
    union {
        struct {
            float        _11, _12, _13, _14;
            float        _21, _22, _23, _24;
            float        _31, _32, _33, _34;
            float        _41, _42, _43, _44;
        } DUMMYSTRUCTNAME;
        float m[4][4];
    } DUMMYUNIONNAME;
} D3DMATRIX;

#define D3DPRESENT_RATE_DEFAULT 0
#define D3DPRESENT_RATE_UNLIMITED 0x7fffffff

typedef struct _D3DPRESENT_PARAMETERS_ {
    UINT                    BackBufferWidth;
    UINT                    BackBufferHeight;
    D3DFORMAT               BackBufferFormat;
    UINT                    BackBufferCount;

    D3DMULTISAMPLE_TYPE     MultiSampleType;

    D3DSWAPEFFECT           SwapEffect;
    HWND                    hDeviceWindow;
    WINBOOL                 Windowed;
    WINBOOL                 EnableAutoDepthStencil;
    D3DFORMAT               AutoDepthStencilFormat;
    DWORD                   Flags;

    UINT                    FullScreen_RefreshRateInHz;
    UINT                    FullScreen_PresentationInterval;

} D3DPRESENT_PARAMETERS;

#define D3DPRESENTFLAG_LOCKABLE_BACKBUFFER  0x00000001

typedef struct _D3DRANGE {
    UINT                Offset;
    UINT                Size;
} D3DRANGE;

typedef struct _D3DRASTER_STATUS {
    WINBOOL         InVBlank;
    UINT            ScanLine;
} D3DRASTER_STATUS;

typedef struct _D3DRECT {
    LONG x1;
    LONG y1;
    LONG x2;
    LONG y2;
} D3DRECT;

typedef struct _D3DRECTPATCH_INFO {
    UINT                StartVertexOffsetWidth;
    UINT                StartVertexOffsetHeight;
    UINT                Width;
    UINT                Height;
    UINT                Stride;
    D3DBASISTYPE        Basis;
    D3DORDERTYPE        Order;
} D3DRECTPATCH_INFO;

typedef struct _D3DSURFACE_DESC {
    D3DFORMAT           Format;
    D3DRESOURCETYPE     Type;
    DWORD               Usage;
    D3DPOOL             Pool;
    UINT                Size;
    D3DMULTISAMPLE_TYPE MultiSampleType;
    UINT                Width;
    UINT                Height;
} D3DSURFACE_DESC;

typedef struct _D3DTRIPATCH_INFO {
    UINT                StartVertexOffset;
    UINT                NumVertices;
    D3DBASISTYPE        Basis;
    D3DORDERTYPE        Order;
} D3DTRIPATCH_INFO;

typedef struct _D3DVERTEXBUFFER_DESC {
    D3DFORMAT           Format;
    D3DRESOURCETYPE     Type;
    DWORD               Usage;
    D3DPOOL             Pool;
    UINT                Size;
    DWORD               FVF;
} D3DVERTEXBUFFER_DESC;

typedef struct _D3DVIEWPORT8 {
    DWORD       X;
    DWORD       Y;
    DWORD       Width;
    DWORD       Height;
    float       MinZ;
    float       MaxZ;
} D3DVIEWPORT8;

typedef struct _D3DVOLUME_DESC {
    D3DFORMAT           Format;
    D3DRESOURCETYPE     Type;
    DWORD               Usage;
    D3DPOOL             Pool;
    UINT                Size;
    UINT                Width;
    UINT                Height;
    UINT                Depth;
} D3DVOLUME_DESC;

#ifdef __i386__
#pragma pack(pop)
#endif

#endif  /* __WINE_D3D8TYPES_H */
