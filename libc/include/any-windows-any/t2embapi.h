/*
 * Copyright (c) 2009 Andrew Nguyen
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

#ifndef __WINE_T2EMBAPI_H
#define __WINE_T2EMBAPI_H

#ifdef __cplusplus
extern "C" {
#endif

#define CHARSET_UNICODE   1
#define CHARSET_DEFAULT   1
#define CHARSET_SYMBOL    2
#define CHARSET_GLYPHIDX  3

#define LICENSE_INSTALLABLE   0x0000
#define LICENSE_DEFAULT       0x0000
#define LICENSE_NOEMBEDDING   0x0002
#define LICENSE_PREVIEWPRINT  0x0004
#define LICENSE_EDITABLE      0x0008

#define TTLOAD_PRIVATE  0x0001

/* Possible return values. */
#define E_NONE                              __MSABI_LONG(0x0000)
#define E_API_NOTIMPL                       __MSABI_LONG(0x0001)
#define E_HDCINVALID                        __MSABI_LONG(0x0006)
#define E_NOFREEMEMORY                      __MSABI_LONG(0x0007)
#define E_NOTATRUETYPEFONT                  __MSABI_LONG(0x000a)
#define E_ERRORACCESSINGFONTDATA            __MSABI_LONG(0x000c)
#define E_ERRORACCESSINGFACENAME            __MSABI_LONG(0x000d)
#define E_FACENAMEINVALID                   __MSABI_LONG(0x0113)
#define E_PERMISSIONSINVALID                __MSABI_LONG(0x0117)
#define E_PBENABLEDINVALID                  __MSABI_LONG(0x0118)

typedef ULONG (WINAPIV * READEMBEDPROC)(void*,void*,ULONG);
typedef ULONG (WINAPIV * WRITEEMBEDPROC)(void*,void*,ULONG);

typedef struct
{
    unsigned short usStructSize;
    unsigned short usRefStrSize;
    unsigned short *pusRefStr;
} TTLOADINFO;

typedef struct
{
    unsigned short usStructSize;
    unsigned short usRootStrSize;
    unsigned short *pusRootStr;
} TTEMBEDINFO;

LONG WINAPI TTLoadEmbeddedFont(HANDLE*,ULONG,ULONG*,ULONG,ULONG*,READEMBEDPROC,
                               LPVOID,LPWSTR,LPSTR,TTLOADINFO*);
LONG WINAPI TTDeleteEmbeddedFont(HANDLE,ULONG,ULONG*);

/* embedding privileges */
#define EMBED_PREVIEWPRINT  1
#define EMBED_EDITABLE      2
#define EMBED_INSTALLABLE   3
#define EMBED_NOEMBEDDING   4

LONG WINAPI TTGetEmbeddingType(HDC, ULONG*);
LONG WINAPI TTIsEmbeddingEnabledForFacename(LPCSTR facename, WINBOOL *enabled);
LONG WINAPI TTIsEmbeddingEnabled(HDC hdc, WINBOOL *enabled);

#ifdef __cplusplus
}
#endif

#endif
