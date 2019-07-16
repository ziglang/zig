/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _GB18030_H_
#define _GB18030_H_

#define NLS_CP_CPINFO 0x10000000
#define NLS_CP_MBTOWC 0x40000000
#define NLS_CP_WCTOMB 0x80000000

STDAPI_(DWORD) NlsDllCodePageTranslation(DWORD CodePage,DWORD dwFlags,LPSTR lpMultiByteStr,int cchMultiByte,LPWSTR lpWideCharStr,int cchWideChar,LPCPINFO lpCPInfo);
STDAPI_(DWORD) BytesToUnicode(BYTE *lpMultiByteStr,UINT cchMultiByte,UINT *pcchLeftOverBytes,LPWSTR lpWideCharStr,UINT cchWideChar);
STDAPI_(DWORD) UnicodeToBytes(LPWSTR lpWideCharStr,UINT cchWideChar,LPSTR lpMultiByteStr,UINT cchMultiByte);

#endif /* _GB18030_H_ */
