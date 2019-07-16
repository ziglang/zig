/*
 * Copyright (C) 2002 Alexandre Julliard
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

#ifndef __DMORT_H__
#define __DMORT_H__

HRESULT WINAPI MoCopyMediaType(DMO_MEDIA_TYPE*,const DMO_MEDIA_TYPE*);
HRESULT WINAPI MoCreateMediaType(DMO_MEDIA_TYPE**,DWORD);
HRESULT WINAPI MoDeleteMediaType(DMO_MEDIA_TYPE*);
HRESULT WINAPI MoDuplicateMediaType(DMO_MEDIA_TYPE**,const DMO_MEDIA_TYPE*);
HRESULT WINAPI MoFreeMediaType(DMO_MEDIA_TYPE*);
HRESULT WINAPI MoInitMediaType(DMO_MEDIA_TYPE*,DWORD);

#endif /* __DMORT_H__ */
