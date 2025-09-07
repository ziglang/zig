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

/* FIXME: Need to add C++ code for certain structs for headers - this is going to be a problem
          if WINE continues to only use C code  - I suppose that we could always inline in
          the header file to get around that little problem... */
/* FIXME: We need to implement versioning on everything directx 5 and up if these headers
          are going to be generically useful for directx stuff */

#ifndef __WINE_D3DTYPES_H
#define __WINE_D3DTYPES_H

#include <windows.h>
#include <float.h>
#include <ddraw.h>

#ifdef __i386__
#pragma pack(push,4)
#endif

#define D3DVALP(val, prec)      ((float)(val))
#define D3DVAL(val)             ((float)(val))
#define D3DDivide(a, b)         (float)((double) (a) / (double) (b))
#define D3DMultiply(a, b)       ((a) * (b))

typedef LONG D3DFIXED;


#ifndef RGB_MAKE
#define CI_GETALPHA(ci)    ((ci) >> 24)
#define CI_GETINDEX(ci)    (((ci) >> 8) & 0xffff)
#define CI_GETFRACTION(ci) ((ci) & 0xff)
#define CI_ROUNDINDEX(ci)  CI_GETINDEX((ci) + 0x80)
#define CI_MASKALPHA(ci)   ((ci) & 0xffffff)
#define CI_MAKE(a, i, f)    (((a) << 24) | ((i) << 8) | (f))

#define RGBA_GETALPHA(rgb)      ((rgb) >> 24)
#define RGBA_GETRED(rgb)        (((rgb) >> 16) & 0xff)
#define RGBA_GETGREEN(rgb)      (((rgb) >> 8) & 0xff)
#define RGBA_GETBLUE(rgb)       ((rgb) & 0xff)
#define RGBA_MAKE(r, g, b, a)   ((D3DCOLOR) (((a) << 24) | ((r) << 16) | ((g) << 8) | (b)))

#define D3DRGB(r, g, b) \
    (0xff000000 | ( ((LONG)((r) * 255)) << 16) | (((LONG)((g) * 255)) << 8) | (LONG)((b) * 255))
#define D3DRGBA(r, g, b, a) \
    (   (((LONG)((a) * 255)) << 24) | (((LONG)((r) * 255)) << 16) \
    |   (((LONG)((g) * 255)) << 8) | (LONG)((b) * 255) \
    )

#define RGB_GETRED(rgb)         (((rgb) >> 16) & 0xff)
#define RGB_GETGREEN(rgb)       (((rgb) >> 8) & 0xff)
#define RGB_GETBLUE(rgb)        ((rgb) & 0xff)
#define RGBA_SETALPHA(rgba, x) (((x) << 24) | ((rgba) & 0x00ffffff))
#define RGB_MAKE(r, g, b)       ((D3DCOLOR) (((r) << 16) | ((g) << 8) | (b)))
#define RGBA_TORGB(rgba)       ((D3DCOLOR) ((rgba) & 0xffffff))
#define RGB_TORGBA(rgb)        ((D3DCOLOR) ((rgb) | 0xff000000))

#endif

#define D3DENUMRET_CANCEL                        DDENUMRET_CANCEL
#define D3DENUMRET_OK                            DDENUMRET_OK

typedef HRESULT (CALLBACK *LPD3DVALIDATECALLBACK)(void *ctx, DWORD offset);
typedef HRESULT (CALLBACK *LPD3DENUMTEXTUREFORMATSCALLBACK)(DDSURFACEDESC *surface_desc, void *ctx);
typedef HRESULT (CALLBACK *LPD3DENUMPIXELFORMATSCALLBACK)(DDPIXELFORMAT *format, void *ctx);

#ifndef DX_SHARED_DEFINES

typedef float D3DVALUE,*LPD3DVALUE;

#ifndef D3DCOLOR_DEFINED
typedef DWORD D3DCOLOR, *LPD3DCOLOR;
#define D3DCOLOR_DEFINED
#endif

#ifndef D3DVECTOR_DEFINED
typedef struct _D3DVECTOR {
  union {
        D3DVALUE        x;
    D3DVALUE dvX;
  } DUMMYUNIONNAME1;
  union {
        D3DVALUE        y;
    D3DVALUE dvY;
  } DUMMYUNIONNAME2;
  union {
        D3DVALUE        z;
    D3DVALUE dvZ;
  } DUMMYUNIONNAME3;
#if defined(__cplusplus) && defined(D3D_OVERLOADS)
  /* the definitions for these methods are in d3dvec.inl */
public:
  /*** constructors ***/
  _D3DVECTOR() {}
  _D3DVECTOR(D3DVALUE f);
  _D3DVECTOR(D3DVALUE _x, D3DVALUE _y, D3DVALUE _z);
  _D3DVECTOR(const D3DVALUE f[3]);

  /*** assignment operators ***/
  _D3DVECTOR& operator += (const _D3DVECTOR& v);
  _D3DVECTOR& operator -= (const _D3DVECTOR& v);
  _D3DVECTOR& operator *= (const _D3DVECTOR& v);
  _D3DVECTOR& operator /= (const _D3DVECTOR& v);
  _D3DVECTOR& operator *= (D3DVALUE s);
  _D3DVECTOR& operator /= (D3DVALUE s);

  /*** unary operators ***/
  friend _D3DVECTOR operator + (const _D3DVECTOR& v);
  friend _D3DVECTOR operator - (const _D3DVECTOR& v);

  /*** binary operators ***/
  friend _D3DVECTOR operator + (const _D3DVECTOR& v1, const _D3DVECTOR& v2);
  friend _D3DVECTOR operator - (const _D3DVECTOR& v1, const _D3DVECTOR& v2);

  friend _D3DVECTOR operator * (const _D3DVECTOR& v, D3DVALUE s);
  friend _D3DVECTOR operator * (D3DVALUE s, const _D3DVECTOR& v);
  friend _D3DVECTOR operator / (const _D3DVECTOR& v, D3DVALUE s);

  friend D3DVALUE SquareMagnitude(const _D3DVECTOR& v);
  friend D3DVALUE Magnitude(const _D3DVECTOR& v);

  friend _D3DVECTOR Normalize(const _D3DVECTOR& v);

  friend D3DVALUE DotProduct(const _D3DVECTOR& v1, const _D3DVECTOR& v2);
  friend _D3DVECTOR CrossProduct(const _D3DVECTOR& v1, const _D3DVECTOR& v2);
#endif
} D3DVECTOR,*LPD3DVECTOR;
#define D3DVECTOR_DEFINED
#endif

#define DX_SHARED_DEFINES
#endif /* DX_SHARED_DEFINES */

typedef DWORD D3DMATERIALHANDLE, *LPD3DMATERIALHANDLE;
typedef DWORD D3DTEXTUREHANDLE,  *LPD3DTEXTUREHANDLE;
typedef DWORD D3DMATRIXHANDLE,   *LPD3DMATRIXHANDLE;

typedef struct _D3DCOLORVALUE {
        union {
                D3DVALUE r;
                D3DVALUE dvR;
        } DUMMYUNIONNAME1;
        union {
                D3DVALUE g;
                D3DVALUE dvG;
        } DUMMYUNIONNAME2;
        union {
                D3DVALUE b;
                D3DVALUE dvB;
        } DUMMYUNIONNAME3;
        union {
                D3DVALUE a;
                D3DVALUE dvA;
        } DUMMYUNIONNAME4;
} D3DCOLORVALUE,*LPD3DCOLORVALUE;

typedef struct _D3DRECT {
  union {
    LONG x1;
    LONG lX1;
  } DUMMYUNIONNAME1;
  union {
    LONG y1;
    LONG lY1;
  } DUMMYUNIONNAME2;
  union {
    LONG x2;
    LONG lX2;
  } DUMMYUNIONNAME3;
  union {
    LONG y2;
    LONG lY2;
  } DUMMYUNIONNAME4;
} D3DRECT, *LPD3DRECT;

typedef struct _D3DHVERTEX {
    DWORD         dwFlags;
 union {
    D3DVALUE    hx;
    D3DVALUE    dvHX;
  } DUMMYUNIONNAME1;
  union {
    D3DVALUE    hy;
    D3DVALUE    dvHY;
  } DUMMYUNIONNAME2;
  union {
    D3DVALUE    hz;
    D3DVALUE    dvHZ;
  } DUMMYUNIONNAME3;
} D3DHVERTEX, *LPD3DHVERTEX;

/*
 * Transformed/lit vertices
 */
typedef struct _D3DTLVERTEX {
  union {
    D3DVALUE    sx;
    D3DVALUE    dvSX;
  } DUMMYUNIONNAME1;
  union {
    D3DVALUE    sy;
    D3DVALUE    dvSY;
  } DUMMYUNIONNAME2;
  union {
    D3DVALUE    sz;
    D3DVALUE    dvSZ;
  } DUMMYUNIONNAME3;
  union {
    D3DVALUE    rhw;
    D3DVALUE    dvRHW;
  } DUMMYUNIONNAME4;
  union {
    D3DCOLOR    color;
    D3DCOLOR    dcColor;
  } DUMMYUNIONNAME5;
  union {
    D3DCOLOR    specular;
    D3DCOLOR    dcSpecular;
  } DUMMYUNIONNAME6;
  union {
    D3DVALUE    tu;
    D3DVALUE    dvTU;
  } DUMMYUNIONNAME7;
  union {
    D3DVALUE    tv;
    D3DVALUE    dvTV;
  } DUMMYUNIONNAME8;
#if defined(__cplusplus) && defined(D3D_OVERLOADS)
public:
  _D3DTLVERTEX() {}
  _D3DTLVERTEX(const D3DVECTOR& v, float _rhw, D3DCOLOR _color, D3DCOLOR _specular, float _tu, float _tv) {
    sx = v.x; sy = v.y; sz = v.z; rhw = _rhw;
    color = _color; specular = _specular;
    tu = _tu; tv = _tv;
  }
#endif
} D3DTLVERTEX, *LPD3DTLVERTEX;

typedef struct _D3DLVERTEX {
  union {
    D3DVALUE x;
    D3DVALUE dvX;
  } DUMMYUNIONNAME1;
  union {
    D3DVALUE y;
    D3DVALUE dvY;
  } DUMMYUNIONNAME2;
  union {
    D3DVALUE z;
    D3DVALUE dvZ;
  } DUMMYUNIONNAME3;
  DWORD            dwReserved;
  union {
    D3DCOLOR     color;
    D3DCOLOR     dcColor;
  } DUMMYUNIONNAME4;
  union {
    D3DCOLOR     specular;
    D3DCOLOR     dcSpecular;
  } DUMMYUNIONNAME5;
  union {
    D3DVALUE     tu;
    D3DVALUE     dvTU;
  } DUMMYUNIONNAME6;
  union {
    D3DVALUE     tv;
    D3DVALUE     dvTV;
  } DUMMYUNIONNAME7;
} D3DLVERTEX, *LPD3DLVERTEX;

typedef struct _D3DVERTEX {
  union {
    D3DVALUE     x;
    D3DVALUE     dvX;
  } DUMMYUNIONNAME1;
  union {
    D3DVALUE     y;
    D3DVALUE     dvY;
  } DUMMYUNIONNAME2;
  union {
    D3DVALUE     z;
    D3DVALUE     dvZ;
  } DUMMYUNIONNAME3;
  union {
    D3DVALUE     nx;
    D3DVALUE     dvNX;
  } DUMMYUNIONNAME4;
  union {
    D3DVALUE     ny;
    D3DVALUE     dvNY;
  } DUMMYUNIONNAME5;
  union {
    D3DVALUE     nz;
    D3DVALUE     dvNZ;
  } DUMMYUNIONNAME6;
  union {
    D3DVALUE     tu;
    D3DVALUE     dvTU;
  } DUMMYUNIONNAME7;
  union {
    D3DVALUE     tv;
    D3DVALUE     dvTV;
  } DUMMYUNIONNAME8;
#if defined(__cplusplus) && defined(D3D_OVERLOADS)
public:
  _D3DVERTEX() {}
  _D3DVERTEX(const D3DVECTOR& v, const D3DVECTOR& n, float _tu, float _tv) {
    x  = v.x; y  = v.y; z  = v.z;
    nx = n.x; ny = n.y; nz = n.z;
    tu = _tu; tv = _tv;
  }
#endif
} D3DVERTEX, *LPD3DVERTEX;

typedef struct _D3DMATRIX {
  D3DVALUE        _11, _12, _13, _14;
  D3DVALUE        _21, _22, _23, _24;
  D3DVALUE        _31, _32, _33, _34;
  D3DVALUE        _41, _42, _43, _44;
#if defined(__cplusplus) && defined(D3D_OVERLOADS)
  _D3DMATRIX() { }

    /* This is different from MS, but avoids anonymous structs. */
    D3DVALUE &operator () (int r, int c)
	{ return (&_11)[r*4 + c]; }
    const D3DVALUE &operator() (int r, int c) const
	{ return (&_11)[r*4 + c]; }
#endif
} D3DMATRIX, *LPD3DMATRIX;

#if defined(__cplusplus) && defined(D3D_OVERLOADS)
#include <d3dvec.inl>
#endif

typedef struct _D3DVIEWPORT {
  DWORD       dwSize;
  DWORD       dwX;
  DWORD       dwY;
  DWORD       dwWidth;
  DWORD       dwHeight;
  D3DVALUE    dvScaleX;
  D3DVALUE    dvScaleY;
  D3DVALUE    dvMaxX;
  D3DVALUE    dvMaxY;
  D3DVALUE    dvMinZ;
  D3DVALUE    dvMaxZ;
} D3DVIEWPORT, *LPD3DVIEWPORT;

typedef struct _D3DVIEWPORT2 {
  DWORD       dwSize;
  DWORD       dwX;
  DWORD       dwY;
  DWORD       dwWidth;
  DWORD       dwHeight;
  D3DVALUE    dvClipX;
  D3DVALUE    dvClipY;
  D3DVALUE    dvClipWidth;
  D3DVALUE    dvClipHeight;
  D3DVALUE    dvMinZ;
  D3DVALUE    dvMaxZ;
} D3DVIEWPORT2, *LPD3DVIEWPORT2;

typedef struct _D3DVIEWPORT7 {
  DWORD       dwX;
  DWORD       dwY;
  DWORD       dwWidth;
  DWORD       dwHeight;
  D3DVALUE    dvMinZ;
  D3DVALUE    dvMaxZ;
} D3DVIEWPORT7, *LPD3DVIEWPORT7;

#define D3DMAXUSERCLIPPLANES 32

#define D3DCLIPPLANE0 (1 << 0)
#define D3DCLIPPLANE1 (1 << 1)
#define D3DCLIPPLANE2 (1 << 2)
#define D3DCLIPPLANE3 (1 << 3)
#define D3DCLIPPLANE4 (1 << 4)
#define D3DCLIPPLANE5 (1 << 5)

#define D3DCLIP_LEFT     0x00000001
#define D3DCLIP_RIGHT    0x00000002
#define D3DCLIP_TOP      0x00000004
#define D3DCLIP_BOTTOM   0x00000008
#define D3DCLIP_FRONT    0x00000010
#define D3DCLIP_BACK     0x00000020
#define D3DCLIP_GEN0     0x00000040
#define D3DCLIP_GEN1     0x00000080
#define D3DCLIP_GEN2     0x00000100
#define D3DCLIP_GEN3     0x00000200
#define D3DCLIP_GEN4     0x00000400
#define D3DCLIP_GEN5     0x00000800

#define D3DSTATUS_CLIPUNIONLEFT                 D3DCLIP_LEFT
#define D3DSTATUS_CLIPUNIONRIGHT                D3DCLIP_RIGHT
#define D3DSTATUS_CLIPUNIONTOP                  D3DCLIP_TOP
#define D3DSTATUS_CLIPUNIONBOTTOM               D3DCLIP_BOTTOM
#define D3DSTATUS_CLIPUNIONFRONT                D3DCLIP_FRONT
#define D3DSTATUS_CLIPUNIONBACK                 D3DCLIP_BACK
#define D3DSTATUS_CLIPUNIONGEN0                 D3DCLIP_GEN0
#define D3DSTATUS_CLIPUNIONGEN1                 D3DCLIP_GEN1
#define D3DSTATUS_CLIPUNIONGEN2                 D3DCLIP_GEN2
#define D3DSTATUS_CLIPUNIONGEN3                 D3DCLIP_GEN3
#define D3DSTATUS_CLIPUNIONGEN4                 D3DCLIP_GEN4
#define D3DSTATUS_CLIPUNIONGEN5                 D3DCLIP_GEN5

#define D3DSTATUS_CLIPINTERSECTIONLEFT          0x00001000
#define D3DSTATUS_CLIPINTERSECTIONRIGHT         0x00002000
#define D3DSTATUS_CLIPINTERSECTIONTOP           0x00004000
#define D3DSTATUS_CLIPINTERSECTIONBOTTOM        0x00008000
#define D3DSTATUS_CLIPINTERSECTIONFRONT         0x00010000
#define D3DSTATUS_CLIPINTERSECTIONBACK          0x00020000
#define D3DSTATUS_CLIPINTERSECTIONGEN0          0x00040000
#define D3DSTATUS_CLIPINTERSECTIONGEN1          0x00080000
#define D3DSTATUS_CLIPINTERSECTIONGEN2          0x00100000
#define D3DSTATUS_CLIPINTERSECTIONGEN3          0x00200000
#define D3DSTATUS_CLIPINTERSECTIONGEN4          0x00400000
#define D3DSTATUS_CLIPINTERSECTIONGEN5          0x00800000
#define D3DSTATUS_ZNOTVISIBLE                   0x01000000

#define D3DSTATUS_CLIPUNIONALL  (               \
            D3DSTATUS_CLIPUNIONLEFT     |       \
            D3DSTATUS_CLIPUNIONRIGHT    |       \
            D3DSTATUS_CLIPUNIONTOP      |       \
            D3DSTATUS_CLIPUNIONBOTTOM   |       \
            D3DSTATUS_CLIPUNIONFRONT    |       \
            D3DSTATUS_CLIPUNIONBACK     |       \
            D3DSTATUS_CLIPUNIONGEN0     |       \
            D3DSTATUS_CLIPUNIONGEN1     |       \
            D3DSTATUS_CLIPUNIONGEN2     |       \
            D3DSTATUS_CLIPUNIONGEN3     |       \
            D3DSTATUS_CLIPUNIONGEN4     |       \
            D3DSTATUS_CLIPUNIONGEN5             \
            )

#define D3DSTATUS_CLIPINTERSECTIONALL   (               \
            D3DSTATUS_CLIPINTERSECTIONLEFT      |       \
            D3DSTATUS_CLIPINTERSECTIONRIGHT     |       \
            D3DSTATUS_CLIPINTERSECTIONTOP       |       \
            D3DSTATUS_CLIPINTERSECTIONBOTTOM    |       \
            D3DSTATUS_CLIPINTERSECTIONFRONT     |       \
            D3DSTATUS_CLIPINTERSECTIONBACK      |       \
            D3DSTATUS_CLIPINTERSECTIONGEN0      |       \
            D3DSTATUS_CLIPINTERSECTIONGEN1      |       \
            D3DSTATUS_CLIPINTERSECTIONGEN2      |       \
            D3DSTATUS_CLIPINTERSECTIONGEN3      |       \
            D3DSTATUS_CLIPINTERSECTIONGEN4      |       \
            D3DSTATUS_CLIPINTERSECTIONGEN5              \
            )

#define D3DSTATUS_DEFAULT       (                       \
            D3DSTATUS_CLIPINTERSECTIONALL       |       \
            D3DSTATUS_ZNOTVISIBLE)

#define D3DTRANSFORM_CLIPPED       0x00000001
#define D3DTRANSFORM_UNCLIPPED     0x00000002

typedef struct _D3DTRANSFORMDATA {
  DWORD           dwSize;
  void            *lpIn;
  DWORD           dwInSize;
  void            *lpOut;
  DWORD           dwOutSize;
  D3DHVERTEX      *lpHOut;
  DWORD           dwClip;
  DWORD           dwClipIntersection;
  DWORD           dwClipUnion;
  D3DRECT         drExtent;
} D3DTRANSFORMDATA, *LPD3DTRANSFORMDATA;

typedef struct _D3DLIGHTINGELEMENT {
  D3DVECTOR dvPosition;
  D3DVECTOR dvNormal;
} D3DLIGHTINGELEMENT, *LPD3DLIGHTINGELEMENT;

typedef struct _D3DMATERIAL {
  DWORD               dwSize;
  union {
    D3DCOLORVALUE   diffuse;
    D3DCOLORVALUE   dcvDiffuse;
  } DUMMYUNIONNAME;
  union {
    D3DCOLORVALUE   ambient;
    D3DCOLORVALUE   dcvAmbient;
  } DUMMYUNIONNAME1;
  union {
    D3DCOLORVALUE   specular;
    D3DCOLORVALUE   dcvSpecular;
  } DUMMYUNIONNAME2;
  union {
    D3DCOLORVALUE   emissive;
    D3DCOLORVALUE   dcvEmissive;
  } DUMMYUNIONNAME3;
  union {
    D3DVALUE        power;
    D3DVALUE        dvPower;
  } DUMMYUNIONNAME4;
  D3DTEXTUREHANDLE    hTexture;
  DWORD               dwRampSize;
} D3DMATERIAL, *LPD3DMATERIAL;

typedef struct _D3DMATERIAL7 {
  union {
    D3DCOLORVALUE   diffuse;
    D3DCOLORVALUE   dcvDiffuse;
  } DUMMYUNIONNAME;
  union {
    D3DCOLORVALUE   ambient;
    D3DCOLORVALUE   dcvAmbient;
  } DUMMYUNIONNAME1;
  union {
    D3DCOLORVALUE   specular;
    D3DCOLORVALUE   dcvSpecular;
  } DUMMYUNIONNAME2;
  union {
    D3DCOLORVALUE   emissive;
    D3DCOLORVALUE   dcvEmissive;
  } DUMMYUNIONNAME3;
  union {
    D3DVALUE        power;
    D3DVALUE        dvPower;
  } DUMMYUNIONNAME4;
} D3DMATERIAL7, *LPD3DMATERIAL7;

typedef enum {
  D3DLIGHT_POINT          = 1,
  D3DLIGHT_SPOT           = 2,
  D3DLIGHT_DIRECTIONAL    = 3,
  D3DLIGHT_PARALLELPOINT  = 4,
  D3DLIGHT_GLSPOT         = 5,
  D3DLIGHT_FORCE_DWORD    = 0x7fffffff
} D3DLIGHTTYPE;

typedef struct _D3DLIGHT {
    DWORD           dwSize;
    D3DLIGHTTYPE    dltType;
    D3DCOLORVALUE   dcvColor;
    D3DVECTOR       dvPosition;
    D3DVECTOR       dvDirection;
    D3DVALUE        dvRange;
    D3DVALUE        dvFalloff;
    D3DVALUE        dvAttenuation0;
    D3DVALUE        dvAttenuation1;
    D3DVALUE        dvAttenuation2;
    D3DVALUE        dvTheta;
    D3DVALUE        dvPhi;
} D3DLIGHT,*LPD3DLIGHT;

typedef struct _D3DLIGHT7 {
    D3DLIGHTTYPE    dltType;
    D3DCOLORVALUE   dcvDiffuse;
    D3DCOLORVALUE   dcvSpecular;
    D3DCOLORVALUE   dcvAmbient;
    D3DVECTOR       dvPosition;
    D3DVECTOR       dvDirection;
    D3DVALUE        dvRange;
    D3DVALUE        dvFalloff;
    D3DVALUE        dvAttenuation0;
    D3DVALUE        dvAttenuation1;
    D3DVALUE        dvAttenuation2;
    D3DVALUE        dvTheta;
    D3DVALUE        dvPhi;
} D3DLIGHT7, *LPD3DLIGHT7;

#define D3DLIGHT_ACTIVE         0x00000001
#define D3DLIGHT_NO_SPECULAR    0x00000002
#define D3DLIGHT_ALL (D3DLIGHT_ACTIVE | D3DLIGHT_NO_SPECULAR) /* 0x3 */

#define D3DLIGHT_RANGE_MAX              ((float)sqrt(FLT_MAX))

typedef struct _D3DLIGHT2 {
  DWORD           dwSize;
  D3DLIGHTTYPE    dltType;
  D3DCOLORVALUE   dcvColor;
  D3DVECTOR       dvPosition;
  D3DVECTOR       dvDirection;
  D3DVALUE        dvRange;
  D3DVALUE        dvFalloff;
  D3DVALUE        dvAttenuation0;
  D3DVALUE        dvAttenuation1;
  D3DVALUE        dvAttenuation2;
  D3DVALUE        dvTheta;
  D3DVALUE        dvPhi;
  DWORD           dwFlags;
} D3DLIGHT2, *LPD3DLIGHT2;

typedef struct _D3DLIGHTDATA {
  DWORD                dwSize;
  D3DLIGHTINGELEMENT   *lpIn;
  DWORD                dwInSize;
  D3DTLVERTEX          *lpOut;
  DWORD                dwOutSize;
} D3DLIGHTDATA, *LPD3DLIGHTDATA;

#define D3DCOLOR_MONO   1
#define D3DCOLOR_RGB    2

typedef DWORD D3DCOLORMODEL;


#define D3DCLEAR_TARGET   0x00000001
#define D3DCLEAR_ZBUFFER  0x00000002
#define D3DCLEAR_STENCIL  0x00000004

typedef enum _D3DOPCODE {
  D3DOP_POINT           = 1,
  D3DOP_LINE            = 2,
  D3DOP_TRIANGLE        = 3,
  D3DOP_MATRIXLOAD      = 4,
  D3DOP_MATRIXMULTIPLY  = 5,
  D3DOP_STATETRANSFORM  = 6,
  D3DOP_STATELIGHT      = 7,
  D3DOP_STATERENDER     = 8,
  D3DOP_PROCESSVERTICES = 9,
  D3DOP_TEXTURELOAD     = 10,
  D3DOP_EXIT            = 11,
  D3DOP_BRANCHFORWARD   = 12,
  D3DOP_SPAN            = 13,
  D3DOP_SETSTATUS       = 14,

  D3DOP_FORCE_DWORD     = 0x7fffffff
} D3DOPCODE;

typedef struct _D3DINSTRUCTION {
  BYTE bOpcode;
  BYTE bSize;
  WORD wCount;
} D3DINSTRUCTION, *LPD3DINSTRUCTION;

typedef struct _D3DTEXTURELOAD {
  D3DTEXTUREHANDLE hDestTexture;
  D3DTEXTUREHANDLE hSrcTexture;
} D3DTEXTURELOAD, *LPD3DTEXTURELOAD;

typedef struct _D3DPICKRECORD {
  BYTE     bOpcode;
  BYTE     bPad;
  DWORD    dwOffset;
  D3DVALUE dvZ;
} D3DPICKRECORD, *LPD3DPICKRECORD;

typedef enum {
  D3DSHADE_FLAT         = 1,
  D3DSHADE_GOURAUD      = 2,
  D3DSHADE_PHONG        = 3,
  D3DSHADE_FORCE_DWORD  = 0x7fffffff
} D3DSHADEMODE;

typedef enum {
  D3DFILL_POINT         = 1,
  D3DFILL_WIREFRAME     = 2,
  D3DFILL_SOLID         = 3,
  D3DFILL_FORCE_DWORD   = 0x7fffffff
} D3DFILLMODE;

typedef struct _D3DLINEPATTERN {
  WORD    wRepeatFactor;
  WORD    wLinePattern;
} D3DLINEPATTERN;

typedef enum {
  D3DFILTER_NEAREST          = 1,
  D3DFILTER_LINEAR           = 2,
  D3DFILTER_MIPNEAREST       = 3,
  D3DFILTER_MIPLINEAR        = 4,
  D3DFILTER_LINEARMIPNEAREST = 5,
  D3DFILTER_LINEARMIPLINEAR  = 6,
  D3DFILTER_FORCE_DWORD      = 0x7fffffff
} D3DTEXTUREFILTER;

typedef enum {
  D3DBLEND_ZERO            = 1,
  D3DBLEND_ONE             = 2,
  D3DBLEND_SRCCOLOR        = 3,
  D3DBLEND_INVSRCCOLOR     = 4,
  D3DBLEND_SRCALPHA        = 5,
  D3DBLEND_INVSRCALPHA     = 6,
  D3DBLEND_DESTALPHA       = 7,
  D3DBLEND_INVDESTALPHA    = 8,
  D3DBLEND_DESTCOLOR       = 9,
  D3DBLEND_INVDESTCOLOR    = 10,
  D3DBLEND_SRCALPHASAT     = 11,
  D3DBLEND_BOTHSRCALPHA    = 12,
  D3DBLEND_BOTHINVSRCALPHA = 13,
  D3DBLEND_FORCE_DWORD     = 0x7fffffff
} D3DBLEND;

typedef enum {
  D3DTBLEND_DECAL         = 1,
  D3DTBLEND_MODULATE      = 2,
  D3DTBLEND_DECALALPHA    = 3,
  D3DTBLEND_MODULATEALPHA = 4,
  D3DTBLEND_DECALMASK     = 5,
  D3DTBLEND_MODULATEMASK  = 6,
  D3DTBLEND_COPY          = 7,
  D3DTBLEND_ADD           = 8,
  D3DTBLEND_FORCE_DWORD   = 0x7fffffff
} D3DTEXTUREBLEND;

typedef enum _D3DTEXTUREADDRESS {
    D3DTADDRESS_WRAP           = 1,
    D3DTADDRESS_MIRROR         = 2,
    D3DTADDRESS_CLAMP          = 3,
    D3DTADDRESS_BORDER         = 4,
    D3DTADDRESS_FORCE_DWORD    = 0x7fffffff
} D3DTEXTUREADDRESS;

typedef enum {
  D3DCULL_NONE        = 1,
  D3DCULL_CW          = 2,
  D3DCULL_CCW         = 3,
  D3DCULL_FORCE_DWORD = 0x7fffffff
} D3DCULL;

typedef enum {
  D3DCMP_NEVER        = 1,
  D3DCMP_LESS         = 2,
  D3DCMP_EQUAL        = 3,
  D3DCMP_LESSEQUAL    = 4,
  D3DCMP_GREATER      = 5,
  D3DCMP_NOTEQUAL     = 6,
  D3DCMP_GREATEREQUAL = 7,
  D3DCMP_ALWAYS       = 8,
  D3DCMP_FORCE_DWORD  = 0x7fffffff
} D3DCMPFUNC;

typedef enum _D3DSTENCILOP {
  D3DSTENCILOP_KEEP        = 1,
  D3DSTENCILOP_ZERO        = 2,
  D3DSTENCILOP_REPLACE     = 3,
  D3DSTENCILOP_INCRSAT     = 4,
  D3DSTENCILOP_DECRSAT     = 5,
  D3DSTENCILOP_INVERT      = 6,
  D3DSTENCILOP_INCR        = 7,
  D3DSTENCILOP_DECR        = 8,
  D3DSTENCILOP_FORCE_DWORD = 0x7fffffff
} D3DSTENCILOP;

typedef enum _D3DFOGMODE {
  D3DFOG_NONE         = 0,
  D3DFOG_EXP          = 1,
  D3DFOG_EXP2         = 2,
  D3DFOG_LINEAR       = 3,
  D3DFOG_FORCE_DWORD  = 0x7fffffff
} D3DFOGMODE;

typedef enum _D3DZBUFFERTYPE {
  D3DZB_FALSE        = 0,
  D3DZB_TRUE         = 1,
  D3DZB_USEW         = 2,
  D3DZB_FORCE_DWORD  = 0x7fffffff
} D3DZBUFFERTYPE;

typedef enum _D3DANTIALIASMODE {
  D3DANTIALIAS_NONE            = 0,
  D3DANTIALIAS_SORTDEPENDENT   = 1,
  D3DANTIALIAS_SORTINDEPENDENT = 2,
  D3DANTIALIAS_FORCE_DWORD     = 0x7fffffff
} D3DANTIALIASMODE;

typedef enum {
  D3DVT_VERTEX        = 1,
  D3DVT_LVERTEX       = 2,
  D3DVT_TLVERTEX      = 3,
  D3DVT_FORCE_DWORD   = 0x7fffffff
} D3DVERTEXTYPE;

typedef enum {
  D3DPT_POINTLIST     = 1,
  D3DPT_LINELIST      = 2,
  D3DPT_LINESTRIP     = 3,
  D3DPT_TRIANGLELIST  = 4,
  D3DPT_TRIANGLESTRIP = 5,
  D3DPT_TRIANGLEFAN   = 6,
  D3DPT_FORCE_DWORD   = 0x7fffffff
} D3DPRIMITIVETYPE;

#define D3DSTATE_OVERRIDE_BIAS      256

#define D3DSTATE_OVERRIDE(type) (D3DRENDERSTATETYPE)(((DWORD) (type) + D3DSTATE_OVERRIDE_BIAS))

typedef enum _D3DTRANSFORMSTATETYPE {
    D3DTRANSFORMSTATE_WORLD         = 1,
    D3DTRANSFORMSTATE_VIEW          = 2,
    D3DTRANSFORMSTATE_PROJECTION    = 3,
    D3DTRANSFORMSTATE_WORLD1        = 4,
    D3DTRANSFORMSTATE_WORLD2        = 5,
    D3DTRANSFORMSTATE_WORLD3        = 6,
    D3DTRANSFORMSTATE_TEXTURE0      = 16,
    D3DTRANSFORMSTATE_TEXTURE1      = 17,
    D3DTRANSFORMSTATE_TEXTURE2      = 18,
    D3DTRANSFORMSTATE_TEXTURE3      = 19,
    D3DTRANSFORMSTATE_TEXTURE4      = 20,
    D3DTRANSFORMSTATE_TEXTURE5      = 21,
    D3DTRANSFORMSTATE_TEXTURE6      = 22,
    D3DTRANSFORMSTATE_TEXTURE7      = 23,
    D3DTRANSFORMSTATE_FORCE_DWORD   = 0x7fffffff
} D3DTRANSFORMSTATETYPE;

typedef enum {
  D3DLIGHTSTATE_MATERIAL      = 1,
  D3DLIGHTSTATE_AMBIENT       = 2,
  D3DLIGHTSTATE_COLORMODEL    = 3,
  D3DLIGHTSTATE_FOGMODE       = 4,
  D3DLIGHTSTATE_FOGSTART      = 5,
  D3DLIGHTSTATE_FOGEND        = 6,
  D3DLIGHTSTATE_FOGDENSITY    = 7,
  D3DLIGHTSTATE_COLORVERTEX   = 8,
  D3DLIGHTSTATE_FORCE_DWORD   = 0x7fffffff
} D3DLIGHTSTATETYPE;

typedef enum {
  D3DRENDERSTATE_TEXTUREHANDLE      = 1,
  D3DRENDERSTATE_ANTIALIAS          = 2,
  D3DRENDERSTATE_TEXTUREADDRESS     = 3,
  D3DRENDERSTATE_TEXTUREPERSPECTIVE = 4,
  D3DRENDERSTATE_WRAPU              = 5, /* <= d3d6 */
  D3DRENDERSTATE_WRAPV              = 6, /* <= d3d6 */
  D3DRENDERSTATE_ZENABLE            = 7,
  D3DRENDERSTATE_FILLMODE           = 8,
  D3DRENDERSTATE_SHADEMODE          = 9,
  D3DRENDERSTATE_LINEPATTERN        = 10,
  D3DRENDERSTATE_MONOENABLE         = 11, /* <= d3d6 */
  D3DRENDERSTATE_ROP2               = 12, /* <= d3d6 */
  D3DRENDERSTATE_PLANEMASK          = 13, /* <= d3d6 */
  D3DRENDERSTATE_ZWRITEENABLE       = 14,
  D3DRENDERSTATE_ALPHATESTENABLE    = 15,
  D3DRENDERSTATE_LASTPIXEL          = 16,
  D3DRENDERSTATE_TEXTUREMAG         = 17,
  D3DRENDERSTATE_TEXTUREMIN         = 18,
  D3DRENDERSTATE_SRCBLEND           = 19,
  D3DRENDERSTATE_DESTBLEND          = 20,
  D3DRENDERSTATE_TEXTUREMAPBLEND    = 21,
  D3DRENDERSTATE_CULLMODE           = 22,
  D3DRENDERSTATE_ZFUNC              = 23,
  D3DRENDERSTATE_ALPHAREF           = 24,
  D3DRENDERSTATE_ALPHAFUNC          = 25,
  D3DRENDERSTATE_DITHERENABLE       = 26,
  D3DRENDERSTATE_ALPHABLENDENABLE   = 27,
  D3DRENDERSTATE_FOGENABLE          = 28,
  D3DRENDERSTATE_SPECULARENABLE     = 29,
  D3DRENDERSTATE_ZVISIBLE           = 30,
  D3DRENDERSTATE_SUBPIXEL           = 31, /* <= d3d6 */
  D3DRENDERSTATE_SUBPIXELX          = 32, /* <= d3d6 */
  D3DRENDERSTATE_STIPPLEDALPHA      = 33,
  D3DRENDERSTATE_FOGCOLOR           = 34,
  D3DRENDERSTATE_FOGTABLEMODE       = 35,
  D3DRENDERSTATE_FOGTABLESTART      = 36,
  D3DRENDERSTATE_FOGTABLEEND        = 37,
  D3DRENDERSTATE_FOGTABLEDENSITY    = 38,
  D3DRENDERSTATE_FOGSTART           = 36,
  D3DRENDERSTATE_FOGEND             = 37,
  D3DRENDERSTATE_FOGDENSITY         = 38,
  D3DRENDERSTATE_STIPPLEENABLE      = 39, /* <= d3d6 */
  /* d3d5 */
  D3DRENDERSTATE_EDGEANTIALIAS      = 40,
  D3DRENDERSTATE_COLORKEYENABLE     = 41,
  D3DRENDERSTATE_BORDERCOLOR        = 43,
  D3DRENDERSTATE_TEXTUREADDRESSU    = 44,
  D3DRENDERSTATE_TEXTUREADDRESSV    = 45,
  D3DRENDERSTATE_MIPMAPLODBIAS      = 46, /* <= d3d6 */
  D3DRENDERSTATE_ZBIAS              = 47,
  D3DRENDERSTATE_RANGEFOGENABLE     = 48,
  D3DRENDERSTATE_ANISOTROPY         = 49, /* <= d3d6 */
  D3DRENDERSTATE_FLUSHBATCH         = 50, /* <= d3d6 */
  /* d3d6 */
  D3DRENDERSTATE_TRANSLUCENTSORTINDEPENDENT = 51, /* <= d3d6 */

  D3DRENDERSTATE_STENCILENABLE      = 52,
  D3DRENDERSTATE_STENCILFAIL        = 53,
  D3DRENDERSTATE_STENCILZFAIL       = 54,
  D3DRENDERSTATE_STENCILPASS        = 55,
  D3DRENDERSTATE_STENCILFUNC        = 56,
  D3DRENDERSTATE_STENCILREF         = 57,
  D3DRENDERSTATE_STENCILMASK        = 58,
  D3DRENDERSTATE_STENCILWRITEMASK   = 59,
  D3DRENDERSTATE_TEXTUREFACTOR      = 60,

  D3DRENDERSTATE_STIPPLEPATTERN00   = 64,
  D3DRENDERSTATE_STIPPLEPATTERN01   = 65,
  D3DRENDERSTATE_STIPPLEPATTERN02   = 66,
  D3DRENDERSTATE_STIPPLEPATTERN03   = 67,
  D3DRENDERSTATE_STIPPLEPATTERN04   = 68,
  D3DRENDERSTATE_STIPPLEPATTERN05   = 69,
  D3DRENDERSTATE_STIPPLEPATTERN06   = 70,
  D3DRENDERSTATE_STIPPLEPATTERN07   = 71,
  D3DRENDERSTATE_STIPPLEPATTERN08   = 72,
  D3DRENDERSTATE_STIPPLEPATTERN09   = 73,
  D3DRENDERSTATE_STIPPLEPATTERN10   = 74,
  D3DRENDERSTATE_STIPPLEPATTERN11   = 75,
  D3DRENDERSTATE_STIPPLEPATTERN12   = 76,
  D3DRENDERSTATE_STIPPLEPATTERN13   = 77,
  D3DRENDERSTATE_STIPPLEPATTERN14   = 78,
  D3DRENDERSTATE_STIPPLEPATTERN15   = 79,
  D3DRENDERSTATE_STIPPLEPATTERN16   = 80,
  D3DRENDERSTATE_STIPPLEPATTERN17   = 81,
  D3DRENDERSTATE_STIPPLEPATTERN18   = 82,
  D3DRENDERSTATE_STIPPLEPATTERN19   = 83,
  D3DRENDERSTATE_STIPPLEPATTERN20   = 84,
  D3DRENDERSTATE_STIPPLEPATTERN21   = 85,
  D3DRENDERSTATE_STIPPLEPATTERN22   = 86,
  D3DRENDERSTATE_STIPPLEPATTERN23   = 87,
  D3DRENDERSTATE_STIPPLEPATTERN24   = 88,
  D3DRENDERSTATE_STIPPLEPATTERN25   = 89,
  D3DRENDERSTATE_STIPPLEPATTERN26   = 90,
  D3DRENDERSTATE_STIPPLEPATTERN27   = 91,
  D3DRENDERSTATE_STIPPLEPATTERN28   = 92,
  D3DRENDERSTATE_STIPPLEPATTERN29   = 93,
  D3DRENDERSTATE_STIPPLEPATTERN30   = 94,
  D3DRENDERSTATE_STIPPLEPATTERN31   = 95,

  D3DRENDERSTATE_WRAP0              = 128,
  D3DRENDERSTATE_WRAP1              = 129,
  D3DRENDERSTATE_WRAP2              = 130,
  D3DRENDERSTATE_WRAP3              = 131,
  D3DRENDERSTATE_WRAP4              = 132,
  D3DRENDERSTATE_WRAP5              = 133,
  D3DRENDERSTATE_WRAP6              = 134,
  D3DRENDERSTATE_WRAP7              = 135,
  /* d3d7 */
  D3DRENDERSTATE_CLIPPING            = 136,
  D3DRENDERSTATE_LIGHTING            = 137,
  D3DRENDERSTATE_EXTENTS             = 138,
  D3DRENDERSTATE_AMBIENT             = 139,
  D3DRENDERSTATE_FOGVERTEXMODE       = 140,
  D3DRENDERSTATE_COLORVERTEX         = 141,
  D3DRENDERSTATE_LOCALVIEWER         = 142,
  D3DRENDERSTATE_NORMALIZENORMALS    = 143,
  D3DRENDERSTATE_COLORKEYBLENDENABLE = 144,
  D3DRENDERSTATE_DIFFUSEMATERIALSOURCE    = 145,
  D3DRENDERSTATE_SPECULARMATERIALSOURCE   = 146,
  D3DRENDERSTATE_AMBIENTMATERIALSOURCE    = 147,
  D3DRENDERSTATE_EMISSIVEMATERIALSOURCE   = 148,
  D3DRENDERSTATE_VERTEXBLEND              = 151,
  D3DRENDERSTATE_CLIPPLANEENABLE          = 152,

  D3DRENDERSTATE_FORCE_DWORD        = 0x7fffffff

  /* FIXME: We have some retired values that are being reused for DirectX 7 */
} D3DRENDERSTATETYPE;

typedef enum _D3DMATERIALCOLORSOURCE
{
    D3DMCS_MATERIAL = 0,
    D3DMCS_COLOR1   = 1,
    D3DMCS_COLOR2   = 2,
    D3DMCS_FORCE_DWORD = 0x7fffffff
} D3DMATERIALCOLORSOURCE;

#define D3DRENDERSTATE_BLENDENABLE      D3DRENDERSTATE_ALPHABLENDENABLE
#define D3DRENDERSTATE_WRAPBIAS         __MSABI_LONG(128U)
#define D3DWRAP_U   __MSABI_LONG(0x00000001)
#define D3DWRAP_V   __MSABI_LONG(0x00000002)

#define D3DWRAPCOORD_0   __MSABI_LONG(0x00000001)
#define D3DWRAPCOORD_1   __MSABI_LONG(0x00000002)
#define D3DWRAPCOORD_2   __MSABI_LONG(0x00000004)
#define D3DWRAPCOORD_3   __MSABI_LONG(0x00000008)

#define D3DRENDERSTATE_STIPPLEPATTERN(y) (D3DRENDERSTATE_STIPPLEPATTERN00 + (y))

typedef struct _D3DSTATE {
  union {
    D3DTRANSFORMSTATETYPE dtstTransformStateType;
    D3DLIGHTSTATETYPE     dlstLightStateType;
    D3DRENDERSTATETYPE    drstRenderStateType;
  } DUMMYUNIONNAME1;
  union {
    DWORD                 dwArg[1];
    D3DVALUE              dvArg[1];
  } DUMMYUNIONNAME2;
} D3DSTATE, *LPD3DSTATE;

typedef struct _D3DMATRIXLOAD {
  D3DMATRIXHANDLE hDestMatrix;
  D3DMATRIXHANDLE hSrcMatrix;
} D3DMATRIXLOAD, *LPD3DMATRIXLOAD;

typedef struct _D3DMATRIXMULTIPLY {
  D3DMATRIXHANDLE hDestMatrix;
  D3DMATRIXHANDLE hSrcMatrix1;
  D3DMATRIXHANDLE hSrcMatrix2;
} D3DMATRIXMULTIPLY, *LPD3DMATRIXMULTIPLY;

typedef struct _D3DPROCESSVERTICES {
  DWORD dwFlags;
  WORD  wStart;
  WORD  wDest;
  DWORD dwCount;
  DWORD dwReserved;
} D3DPROCESSVERTICES, *LPD3DPROCESSVERTICES;

#define D3DPROCESSVERTICES_TRANSFORMLIGHT       __MSABI_LONG(0x00000000)
#define D3DPROCESSVERTICES_TRANSFORM            __MSABI_LONG(0x00000001)
#define D3DPROCESSVERTICES_COPY                 __MSABI_LONG(0x00000002)
#define D3DPROCESSVERTICES_OPMASK               __MSABI_LONG(0x00000007)

#define D3DPROCESSVERTICES_UPDATEEXTENTS        __MSABI_LONG(0x00000008)
#define D3DPROCESSVERTICES_NOCOLOR              __MSABI_LONG(0x00000010)

typedef enum _D3DTEXTURESTAGESTATETYPE
{
    D3DTSS_COLOROP        =  1,
    D3DTSS_COLORARG1      =  2,
    D3DTSS_COLORARG2      =  3,
    D3DTSS_ALPHAOP        =  4,
    D3DTSS_ALPHAARG1      =  5,
    D3DTSS_ALPHAARG2      =  6,
    D3DTSS_BUMPENVMAT00   =  7,
    D3DTSS_BUMPENVMAT01   =  8,
    D3DTSS_BUMPENVMAT10   =  9,
    D3DTSS_BUMPENVMAT11   = 10,
    D3DTSS_TEXCOORDINDEX  = 11,
    D3DTSS_ADDRESS        = 12,
    D3DTSS_ADDRESSU       = 13,
    D3DTSS_ADDRESSV       = 14,
    D3DTSS_BORDERCOLOR    = 15,
    D3DTSS_MAGFILTER      = 16,
    D3DTSS_MINFILTER      = 17,
    D3DTSS_MIPFILTER      = 18,
    D3DTSS_MIPMAPLODBIAS  = 19,
    D3DTSS_MAXMIPLEVEL    = 20,
    D3DTSS_MAXANISOTROPY  = 21,
    D3DTSS_BUMPENVLSCALE  = 22,
    D3DTSS_BUMPENVLOFFSET = 23,
    D3DTSS_TEXTURETRANSFORMFLAGS = 24,
    D3DTSS_FORCE_DWORD   = 0x7fffffff
} D3DTEXTURESTAGESTATETYPE;

#define D3DTSS_TCI_PASSTHRU                             0x00000000
#define D3DTSS_TCI_CAMERASPACENORMAL                    0x00010000
#define D3DTSS_TCI_CAMERASPACEPOSITION                  0x00020000
#define D3DTSS_TCI_CAMERASPACEREFLECTIONVECTOR          0x00030000

typedef enum _D3DTEXTUREOP
{
    D3DTOP_DISABLE    = 1,
    D3DTOP_SELECTARG1 = 2,
    D3DTOP_SELECTARG2 = 3,

    D3DTOP_MODULATE   = 4,
    D3DTOP_MODULATE2X = 5,
    D3DTOP_MODULATE4X = 6,

    D3DTOP_ADD          =  7,
    D3DTOP_ADDSIGNED    =  8,
    D3DTOP_ADDSIGNED2X  =  9,
    D3DTOP_SUBTRACT     = 10,
    D3DTOP_ADDSMOOTH    = 11,

    D3DTOP_BLENDDIFFUSEALPHA    = 12,
    D3DTOP_BLENDTEXTUREALPHA    = 13,
    D3DTOP_BLENDFACTORALPHA     = 14,
    D3DTOP_BLENDTEXTUREALPHAPM  = 15,
    D3DTOP_BLENDCURRENTALPHA    = 16,

    D3DTOP_PREMODULATE            = 17,
    D3DTOP_MODULATEALPHA_ADDCOLOR = 18,
    D3DTOP_MODULATECOLOR_ADDALPHA = 19,
    D3DTOP_MODULATEINVALPHA_ADDCOLOR = 20,
    D3DTOP_MODULATEINVCOLOR_ADDALPHA = 21,

    D3DTOP_BUMPENVMAP           = 22,
    D3DTOP_BUMPENVMAPLUMINANCE  = 23,
    D3DTOP_DOTPRODUCT3          = 24,

    D3DTOP_FORCE_DWORD = 0x7fffffff
} D3DTEXTUREOP;

#define D3DTA_SELECTMASK        0x0000000f
#define D3DTA_DIFFUSE           0x00000000
#define D3DTA_CURRENT           0x00000001
#define D3DTA_TEXTURE           0x00000002
#define D3DTA_TFACTOR           0x00000003
#define D3DTA_SPECULAR          0x00000004
#define D3DTA_COMPLEMENT        0x00000010
#define D3DTA_ALPHAREPLICATE    0x00000020

typedef enum _D3DTEXTUREMAGFILTER
{
    D3DTFG_POINT        = 1,
    D3DTFG_LINEAR       = 2,
    D3DTFG_FLATCUBIC    = 3,
    D3DTFG_GAUSSIANCUBIC = 4,
    D3DTFG_ANISOTROPIC  = 5,
    D3DTFG_FORCE_DWORD  = 0x7fffffff
} D3DTEXTUREMAGFILTER;

typedef enum _D3DTEXTUREMINFILTER
{
    D3DTFN_POINT        = 1,
    D3DTFN_LINEAR       = 2,
    D3DTFN_ANISOTROPIC  = 3,
    D3DTFN_FORCE_DWORD  = 0x7fffffff
} D3DTEXTUREMINFILTER;

typedef enum _D3DTEXTUREMIPFILTER
{
    D3DTFP_NONE         = 1,
    D3DTFP_POINT        = 2,
    D3DTFP_LINEAR       = 3,
    D3DTFP_FORCE_DWORD  = 0x7fffffff
} D3DTEXTUREMIPFILTER;

#define D3DTRIFLAG_START                        __MSABI_LONG(0x00000000)
#define D3DTRIFLAG_STARTFLAT(len) (len)
#define D3DTRIFLAG_ODD                          __MSABI_LONG(0x0000001e)
#define D3DTRIFLAG_EVEN                         __MSABI_LONG(0x0000001f)

#define D3DTRIFLAG_EDGEENABLE1                  __MSABI_LONG(0x00000100)
#define D3DTRIFLAG_EDGEENABLE2                  __MSABI_LONG(0x00000200)
#define D3DTRIFLAG_EDGEENABLE3                  __MSABI_LONG(0x00000400)
#define D3DTRIFLAG_EDGEENABLETRIANGLE \
        (D3DTRIFLAG_EDGEENABLE1 | D3DTRIFLAG_EDGEENABLE2 | D3DTRIFLAG_EDGEENABLE3)

typedef struct _D3DTRIANGLE {
  union {
    WORD v1;
    WORD wV1;
  } DUMMYUNIONNAME1;
  union {
    WORD v2;
    WORD wV2;
  } DUMMYUNIONNAME2;
  union {
    WORD v3;
    WORD wV3;
  } DUMMYUNIONNAME3;
  WORD     wFlags;
} D3DTRIANGLE, *LPD3DTRIANGLE;

typedef struct _D3DLINE {
  union {
    WORD v1;
    WORD wV1;
  } DUMMYUNIONNAME1;
  union {
    WORD v2;
    WORD wV2;
  } DUMMYUNIONNAME2;
} D3DLINE, *LPD3DLINE;

typedef struct _D3DSPAN {
  WORD wCount;
  WORD wFirst;
} D3DSPAN, *LPD3DSPAN;

typedef struct _D3DPOINT {
  WORD wCount;
  WORD wFirst;
} D3DPOINT, *LPD3DPOINT;

typedef struct _D3DBRANCH {
  DWORD dwMask;
  DWORD dwValue;
  WINBOOL  bNegate;
  DWORD dwOffset;
} D3DBRANCH, *LPD3DBRANCH;

typedef struct _D3DSTATUS {
  DWORD   dwFlags;
  DWORD   dwStatus;
  D3DRECT drExtent;
} D3DSTATUS, *LPD3DSTATUS;

#define D3DSETSTATUS_STATUS   __MSABI_LONG(0x00000001)
#define D3DSETSTATUS_EXTENTS  __MSABI_LONG(0x00000002)
#define D3DSETSTATUS_ALL      (D3DSETSTATUS_STATUS | D3DSETSTATUS_EXTENTS)

typedef struct _D3DCLIPSTATUS {
  DWORD dwFlags;
  DWORD dwStatus;
  float minx, maxx;
  float miny, maxy;
  float minz, maxz;
} D3DCLIPSTATUS, *LPD3DCLIPSTATUS;

#define D3DCLIPSTATUS_STATUS        __MSABI_LONG(0x00000001)
#define D3DCLIPSTATUS_EXTENTS2      __MSABI_LONG(0x00000002)
#define D3DCLIPSTATUS_EXTENTS3      __MSABI_LONG(0x00000004)

typedef struct {
  DWORD        dwSize;
  DWORD        dwTrianglesDrawn;
  DWORD        dwLinesDrawn;
  DWORD        dwPointsDrawn;
  DWORD        dwSpansDrawn;
  DWORD        dwVerticesProcessed;
} D3DSTATS, *LPD3DSTATS;

#define D3DEXECUTE_CLIPPED       __MSABI_LONG(0x00000001)
#define D3DEXECUTE_UNCLIPPED     __MSABI_LONG(0x00000002)

typedef struct _D3DEXECUTEDATA {
  DWORD     dwSize;
  DWORD     dwVertexOffset;
  DWORD     dwVertexCount;
  DWORD     dwInstructionOffset;
  DWORD     dwInstructionLength;
  DWORD     dwHVertexOffset;
  D3DSTATUS dsStatus;
} D3DEXECUTEDATA, *LPD3DEXECUTEDATA;

#define D3DPAL_FREE 0x00
#define D3DPAL_READONLY 0x40
#define D3DPAL_RESERVED 0x80

typedef struct _D3DVERTEXBUFFERDESC {
  DWORD dwSize;
  DWORD dwCaps;
  DWORD dwFVF;
  DWORD dwNumVertices;
} D3DVERTEXBUFFERDESC, *LPD3DVERTEXBUFFERDESC;

#define D3DVBCAPS_SYSTEMMEMORY      __MSABI_LONG(0x00000800)
#define D3DVBCAPS_WRITEONLY         __MSABI_LONG(0x00010000)
#define D3DVBCAPS_OPTIMIZED         __MSABI_LONG(0x80000000)
#define D3DVBCAPS_DONOTCLIP         __MSABI_LONG(0x00000001)

#define D3DVOP_LIGHT       (1 << 10)
#define D3DVOP_TRANSFORM   (1 << 0)
#define D3DVOP_CLIP        (1 << 2)
#define D3DVOP_EXTENTS     (1 << 3)

#define D3DMAXNUMVERTICES    ((1<<16) - 1)

#define D3DMAXNUMPRIMITIVES  ((1<<16) - 1)

#define D3DPV_DONOTCOPYDATA (1 << 0)

#define D3DFVF_RESERVED0        0x001
#define D3DFVF_POSITION_MASK    0x00E
#define D3DFVF_XYZ              0x002
#define D3DFVF_XYZRHW           0x004
#define D3DFVF_XYZB1            0x006
#define D3DFVF_XYZB2            0x008
#define D3DFVF_XYZB3            0x00a
#define D3DFVF_XYZB4            0x00c
#define D3DFVF_XYZB5            0x00e

#define D3DFVF_NORMAL           0x010
#define D3DFVF_RESERVED1        0x020
#define D3DFVF_DIFFUSE          0x040
#define D3DFVF_SPECULAR         0x080
#define D3DFVF_TEXCOUNT_MASK    0xf00
#define D3DFVF_TEXCOUNT_SHIFT   8
#define D3DFVF_TEX0             0x000
#define D3DFVF_TEX1             0x100
#define D3DFVF_TEX2             0x200
#define D3DFVF_TEX3             0x300
#define D3DFVF_TEX4             0x400
#define D3DFVF_TEX5             0x500
#define D3DFVF_TEX6             0x600
#define D3DFVF_TEX7             0x700
#define D3DFVF_TEX8             0x800

#define D3DFVF_RESERVED2        0xf000

#define D3DFVF_VERTEX ( D3DFVF_XYZ | D3DFVF_NORMAL | D3DFVF_TEX1 )
#define D3DFVF_LVERTEX ( D3DFVF_XYZ | D3DFVF_RESERVED1 | D3DFVF_DIFFUSE | \
                         D3DFVF_SPECULAR | D3DFVF_TEX1 )
#define D3DFVF_TLVERTEX ( D3DFVF_XYZRHW | D3DFVF_DIFFUSE | D3DFVF_SPECULAR | \
                          D3DFVF_TEX1 )

typedef struct _D3DDP_PTRSTRIDE
{
  void *lpvData;
  DWORD dwStride;
} D3DDP_PTRSTRIDE;

#define D3DDP_MAXTEXCOORD 8

typedef struct _D3DDRAWPRIMITIVESTRIDEDDATA  {
  D3DDP_PTRSTRIDE position;
  D3DDP_PTRSTRIDE normal;
  D3DDP_PTRSTRIDE diffuse;
  D3DDP_PTRSTRIDE specular;
  D3DDP_PTRSTRIDE textureCoords[D3DDP_MAXTEXCOORD];
} D3DDRAWPRIMITIVESTRIDEDDATA ,*LPD3DDRAWPRIMITIVESTRIDEDDATA;

#define D3DVIS_INSIDE_FRUSTUM       0
#define D3DVIS_INTERSECT_FRUSTUM    1
#define D3DVIS_OUTSIDE_FRUSTUM      2
#define D3DVIS_INSIDE_LEFT          0
#define D3DVIS_INTERSECT_LEFT       (1 << 2)
#define D3DVIS_OUTSIDE_LEFT         (2 << 2)
#define D3DVIS_INSIDE_RIGHT         0
#define D3DVIS_INTERSECT_RIGHT      (1 << 4)
#define D3DVIS_OUTSIDE_RIGHT        (2 << 4)
#define D3DVIS_INSIDE_TOP           0
#define D3DVIS_INTERSECT_TOP        (1 << 6)
#define D3DVIS_OUTSIDE_TOP          (2 << 6)
#define D3DVIS_INSIDE_BOTTOM        0
#define D3DVIS_INTERSECT_BOTTOM     (1 << 8)
#define D3DVIS_OUTSIDE_BOTTOM       (2 << 8)
#define D3DVIS_INSIDE_NEAR          0
#define D3DVIS_INTERSECT_NEAR       (1 << 10)
#define D3DVIS_OUTSIDE_NEAR         (2 << 10)
#define D3DVIS_INSIDE_FAR           0
#define D3DVIS_INTERSECT_FAR        (1 << 12)
#define D3DVIS_OUTSIDE_FAR          (2 << 12)

#define D3DVIS_MASK_FRUSTUM         (3 << 0)
#define D3DVIS_MASK_LEFT            (3 << 2)
#define D3DVIS_MASK_RIGHT           (3 << 4)
#define D3DVIS_MASK_TOP             (3 << 6)
#define D3DVIS_MASK_BOTTOM          (3 << 8)
#define D3DVIS_MASK_NEAR            (3 << 10)
#define D3DVIS_MASK_FAR             (3 << 12)

#define D3DDEVINFOID_TEXTUREMANAGER    1
#define D3DDEVINFOID_D3DTEXTUREMANAGER 2
#define D3DDEVINFOID_TEXTURING         3

typedef enum _D3DSTATEBLOCKTYPE
{
    D3DSBT_ALL           = 1,
    D3DSBT_PIXELSTATE    = 2,
    D3DSBT_VERTEXSTATE   = 3,
    D3DSBT_FORCE_DWORD   = 0xffffffff
} D3DSTATEBLOCKTYPE;

typedef enum _D3DVERTEXBLENDFLAGS
{
    D3DVBLEND_DISABLE  = 0,
    D3DVBLEND_1WEIGHT  = 1,
    D3DVBLEND_2WEIGHTS = 2,
    D3DVBLEND_3WEIGHTS = 3,
} D3DVERTEXBLENDFLAGS;

typedef enum _D3DTEXTURETRANSFORMFLAGS {
    D3DTTFF_DISABLE         = 0,
    D3DTTFF_COUNT1          = 1,
    D3DTTFF_COUNT2          = 2,
    D3DTTFF_COUNT3          = 3,
    D3DTTFF_COUNT4          = 4,
    D3DTTFF_PROJECTED       = 256,
    D3DTTFF_FORCE_DWORD     = 0x7fffffff
} D3DTEXTURETRANSFORMFLAGS;

#define D3DFVF_TEXTUREFORMAT2 0
#define D3DFVF_TEXTUREFORMAT1 3
#define D3DFVF_TEXTUREFORMAT3 1
#define D3DFVF_TEXTUREFORMAT4 2

#define D3DFVF_TEXCOORDSIZE3(CoordIndex) (D3DFVF_TEXTUREFORMAT3 << (CoordIndex*2 + 16))
#define D3DFVF_TEXCOORDSIZE2(CoordIndex) (D3DFVF_TEXTUREFORMAT2)
#define D3DFVF_TEXCOORDSIZE4(CoordIndex) (D3DFVF_TEXTUREFORMAT4 << (CoordIndex*2 + 16))
#define D3DFVF_TEXCOORDSIZE1(CoordIndex) (D3DFVF_TEXTUREFORMAT1 << (CoordIndex*2 + 16))

#ifdef __i386__
#pragma pack(pop)
#endif

#endif
