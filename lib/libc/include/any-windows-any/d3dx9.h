/*
 * Copyright (C) 2007 David Adam
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

#ifndef __D3DX9_H__
#define __D3DX9_H__

#include <limits.h>

#define D3DX_DEFAULT         ((UINT)-1)
#define D3DX_DEFAULT_NONPOW2 ((UINT)-2)
#define D3DX_DEFAULT_FLOAT   FLT_MAX
#define D3DX_FROM_FILE       ((UINT)-3)
#define D3DFMT_FROM_FILE     ((D3DFORMAT)-3)

#include "d3d9.h"
#include "d3dx9math.h"
#include "d3dx9core.h"
#include "d3dx9xof.h"
#include "d3dx9mesh.h"
#include "d3dx9shader.h"
#include "d3dx9effect.h"
#include "d3dx9shape.h"
#include "d3dx9anim.h"
#include "d3dx9tex.h"

#define _FACDD 0x876
#define MAKE_DDHRESULT(code) MAKE_HRESULT(1, _FACDD, code)

enum _D3DXERR {
    D3DXERR_CANNOTMODIFYINDEXBUFFER = MAKE_DDHRESULT(2900),
    D3DXERR_INVALIDMESH             = MAKE_DDHRESULT(2901),
    D3DXERR_CANNOTATTRSORT          = MAKE_DDHRESULT(2902),
    D3DXERR_SKINNINGNOTSUPPORTED    = MAKE_DDHRESULT(2903),
    D3DXERR_TOOMANYINFLUENCES       = MAKE_DDHRESULT(2904),
    D3DXERR_INVALIDDATA             = MAKE_DDHRESULT(2905),
    D3DXERR_LOADEDMESHASNODATA      = MAKE_DDHRESULT(2906),
    D3DXERR_DUPLICATENAMEDFRAGMENT  = MAKE_DDHRESULT(2907),
    D3DXERR_CANNOTREMOVELASTITEM    = MAKE_DDHRESULT(2908),
};

#endif
