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

#ifndef __DMOREG_H__
#define __DMOREG_H__

#include "mediaobj.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _DMO_PARTIAL_MEDIATYPE
{
   GUID type;
   GUID subtype;
} DMO_PARTIAL_MEDIATYPE, *PDMO_PARTIAL_MEDIATYPE;

enum DMO_REGISTER_FLAGS
{
   DMO_REGISTERF_IS_KEYED = 1
};

enum DMO_ENUM_FLAGS
{
   DMO_ENUMF_INCLUDE_KEYED = 1
};

HRESULT WINAPI DMORegister(LPCWSTR,REFCLSID,REFGUID,DWORD,DWORD,const DMO_PARTIAL_MEDIATYPE*,
                           DWORD,const DMO_PARTIAL_MEDIATYPE*);
HRESULT WINAPI DMOUnregister(REFCLSID,REFGUID);
HRESULT WINAPI DMOEnum(REFGUID,DWORD,DWORD,const DMO_PARTIAL_MEDIATYPE*,DWORD,
                       const DMO_PARTIAL_MEDIATYPE*,IEnumDMO**);
HRESULT WINAPI DMOGetTypes(REFCLSID,ULONG,ULONG*,DMO_PARTIAL_MEDIATYPE*,
                           ULONG,ULONG*,DMO_PARTIAL_MEDIATYPE*);
HRESULT WINAPI DMOGetName(REFCLSID,WCHAR[80]);

DEFINE_GUID(DMOCATEGORY_AUDIO_DECODER,
            0x57f2db8b,0xe6bb,0x4513,0x9d,0x43,0xdc,0xd2,0xa6,0x59,0x31,0x25);
DEFINE_GUID(DMOCATEGORY_AUDIO_ENCODER,
            0x33d9a761,0x90c8,0x11d0,0xbd,0x43,0x00,0xa0,0xc9,0x11,0xce,0x86);
DEFINE_GUID(DMOCATEGORY_VIDEO_DECODER,
            0x4a69b442,0x28be,0x4991,0x96,0x9c,0xb5,0x00,0xad,0xf5,0xd8,0xa8);
DEFINE_GUID(DMOCATEGORY_VIDEO_ENCODER,
            0x33d9a760,0x90c8,0x11d0,0xbd,0x43,0x00,0xa0,0xc9,0x11,0xce,0x86);
DEFINE_GUID(DMOCATEGORY_AUDIO_EFFECT,
            0xf3602b3f,0x0592,0x48df,0xa4,0xcd,0x67,0x47,0x21,0xe7,0xeb,0xeb);
DEFINE_GUID(DMOCATEGORY_VIDEO_EFFECT,
            0xd990ee14,0x776c,0x4723,0xbe,0x46,0x3d,0xa2,0xf5,0x6f,0x10,0xb9);
DEFINE_GUID(DMOCATEGORY_AUDIO_CAPTURE_EFFECT,
            0xf665aaba,0x3e09,0x4920,0xaa,0x5f,0x21,0x98,0x11,0x14,0x8f,0x09);
DEFINE_GUID(DMOCATEGORY_ACOUSTIC_ECHO_CANCEL,
            0xbf963d80,0xc559,0x11d0,0x8a,0x2b,0x00,0xa0,0xc9,0x25,0x5a,0xc1);
DEFINE_GUID(DMOCATEGORY_AUDIO_NOISE_SUPPRESS,
            0xe07f903f,0x62fd,0x4e60,0x8c,0xdd,0xde,0xa7,0x23,0x66,0x65,0xb5);
DEFINE_GUID(DMOCATEGORY_AGC,
            0xe88c9ba0,0xc557,0x11d0,0x8a,0x2b,0x00,0xa0,0xc9,0x25,0x5a,0xc1);

#ifdef __cplusplus
}
#endif

#endif /* __DMOREG_H__ */
