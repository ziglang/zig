/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#if !defined(WABMEM_H)
#define WABMEM_H

#ifndef MAPIX_H
typedef SCODE (WINAPI MAPIALLOCATEBUFFER)(ULONG cbSize,LPVOID *lppBuffer);
typedef SCODE (WINAPI MAPIALLOCATEMORE)(ULONG cbSize,LPVOID lpObject,LPVOID *lppBuffer);
typedef ULONG (WINAPI MAPIFREEBUFFER)(LPVOID lpBuffer);
typedef MAPIALLOCATEBUFFER *LPMAPIALLOCATEBUFFER;
typedef MAPIALLOCATEMORE *LPMAPIALLOCATEMORE;
typedef MAPIFREEBUFFER *LPMAPIFREEBUFFER;
#endif
typedef SCODE (WINAPI WABALLOCATEBUFFER)(LPWABOBJECT lpWABObject,ULONG cbSize,LPVOID *lppBuffer);
typedef SCODE (WINAPI WABALLOCATEMORE)(LPWABOBJECT lpWABObject,ULONG cbSize,LPVOID lpObject,LPVOID *lppBuffer);
typedef ULONG (WINAPI WABFREEBUFFER)(LPWABOBJECT lpWABObject,LPVOID lpBuffer);
typedef WABALLOCATEBUFFER *LPWABALLOCATEBUFFER;
typedef WABALLOCATEMORE *LPWABALLOCATEMORE;
typedef WABFREEBUFFER *LPWABFREEBUFFER;

#endif
