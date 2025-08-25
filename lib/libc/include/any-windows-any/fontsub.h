/*
 * Copyright 2016 Nikolay Sivov for CodeWeavers
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

#ifndef __WINE_FONTSUB_H
#define __WINE_FONTSUB_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void *(__cdecl *CFP_ALLOCPROC)(size_t);
typedef void *(__cdecl *CFP_REALLOCPROC)(void *, size_t);
typedef void (__cdecl *CFP_FREEPROC)(void *);

#define TTFCFP_SUBSET  0
#define TTFCFP_SUBSET1 1
#define TTFCFP_DELTA   2

#define TTFCFP_UNICODE_PLATFORMID 0
#define TTFCFP_APPLE_PLATFORMID   1
#define TTFCFP_ISO_PLATFORMID     2
#define TTFCFP_MS_PLATFORMID      3

#define TTFCFP_STD_MAC_CHAR_SET   0
#define TTFCFP_SYMBOL_CHAR_SET    0
#define TTFCFP_UNICODE_CHAR_SET   1
#define TTFCFP_DONT_CARE          0xffff

#define TTFCFP_LANG_KEEP_ALL      0

#define TTFCFP_FLAGS_SUBSET       0x0001
#define TTFCFP_FLAGS_COMPRESS     0x0002
#define TTFCFP_FLAGS_TTC          0x0004
#define TTFCFP_FLAGS_GLYPHLIST    0x0008

#define ERR_GENERIC 1000
#define ERR_MEM     1005

ULONG __cdecl CreateFontPackage(const unsigned char *src, const ULONG src_len, unsigned char **dest,
    ULONG *dest_len, ULONG *written, const unsigned short flags, const unsigned short face_index,
    const unsigned short format, const unsigned short lang, const unsigned short platform,
    const unsigned short encoding, const unsigned short *keep_list, const unsigned short keep_len,
    CFP_ALLOCPROC allocproc, CFP_REALLOCPROC reallocproc, CFP_FREEPROC freeproc, void *reserved);

#ifdef __cplusplus
}
#endif

#endif
