/*
 * Copyright 2013 Nikolay Sivov for CodeWeavers
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

#ifndef _D2DBASETYPES_INCLUDED
#define _D2DBASETYPES_INCLUDED

#ifndef D3DCOLORVALUE_DEFINED
typedef struct D3DCOLORVALUE
{
    float r;
    float g;
    float b;
    float a;
} D3DCOLORVALUE;
#define D3DCOLORVALUE_DEFINED
#endif

typedef D3DCOLORVALUE D2D_COLOR_F;

typedef struct D2D_RECT_F
{
    float left;
    float top;
    float right;
    float bottom;
} D2D_RECT_F;

typedef struct D2D_SIZE_F
{
    float width;
    float height;
} D2D_SIZE_F;

typedef struct D2D_POINT_2U
{
    UINT32 x;
    UINT32 y;
} D2D_POINT_2U;

typedef struct D2D_RECT_U
{
    UINT32 left;
    UINT32 top;
    UINT32 right;
    UINT32 bottom;
} D2D_RECT_U;

#endif /* _D2DBASETYPES_INCLUDED */
