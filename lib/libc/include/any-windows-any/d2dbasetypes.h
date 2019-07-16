/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.

 * d2dbasetypes.h - Header file for the Direct2D API
 * No original Microsoft headers were used in the creation of this
 * file.
 *API docs available at: http://msdn.microsoft.com/en-us/library/dd372349%28v=VS.85%29.aspx
 */

#ifndef _D2DBASETYPES_H
#define _D2DBASETYPES_H

#include <d3d9types.h>

typedef D3DCOLORVALUE D2D_COLOR_F;

struct D2D_MATRIX_3X2_F {
  FLOAT _11;
  FLOAT _12;
  FLOAT _21;
  FLOAT _22;
  FLOAT _31;
  FLOAT _32;
};

typedef struct D2D_MATRIX_4X3_F {
    __C89_NAMELESS union {
        __C89_NAMELESS struct {
            FLOAT _11, _12, _13;
            FLOAT _21, _22, _23;
            FLOAT _31, _32, _33;
            FLOAT _41, _42, _43;
        };
        FLOAT m[4][3];
    };
} D2D_MATRIX_4X3_F;

typedef struct D2D_MATRIX_4X4_F {
    __C89_NAMELESS union {
        __C89_NAMELESS struct {
            FLOAT _11, _12, _13, _14;
            FLOAT _21, _22, _23, _24;
            FLOAT _31, _32, _33, _34;
            FLOAT _41, _42, _43, _44;
        };
        FLOAT m[4][4];
    };
} D2D_MATRIX_4X4_F;

typedef struct D2D_MATRIX_5X4_F {
    __C89_NAMELESS union {
        __C89_NAMELESS struct {
            FLOAT _11, _12, _13, _14;
            FLOAT _21, _22, _23, _24;
            FLOAT _31, _32, _33, _34;
            FLOAT _41, _42, _43, _44;
            FLOAT _51, _52, _53, _54;
        };
        FLOAT m[5][4];
    };
} D2D_MATRIX_5X4_F;

struct D2D_POINT_2F {
  FLOAT x;
  FLOAT y;
};

struct D2D_POINT_2U {
  UINT32 x;
  UINT32 y;
};

struct D2D_RECT_F {
  FLOAT left;
  FLOAT top;
  FLOAT right;
  FLOAT bottom;
};

struct D2D_RECT_U {
  UINT32 left;
  UINT32 top;
  UINT32 right;
  UINT32 bottom;
};

typedef RECT D2D_RECT_L;

struct D2D_SIZE_F {
  FLOAT width;
  FLOAT height;
};

typedef D2D_COLOR_F D2D1_COLOR_F;

typedef struct D2D_POINT_2F D2D1_POINT_2F;

typedef struct D2D_POINT_2U D2D1_POINT_2U;

typedef struct D2D_RECT_F D2D1_RECT_F;

typedef struct D2D_RECT_U D2D1_RECT_U;

typedef struct D2D_SIZE_F D2D1_SIZE_F;

typedef struct D2D_VECTOR_2F {
    FLOAT x;
    FLOAT y;
} D2D_VECTOR_2F;

typedef struct D2D_VECTOR_3F {
    FLOAT x;
    FLOAT y;
    FLOAT z;
} D2D_VECTOR_3F;

typedef struct D2D_VECTOR_4F {
    FLOAT x;
    FLOAT y;
    FLOAT z;
    FLOAT w;
} D2D_VECTOR_4F;

#endif /* _D2DBASETYPES_H */
