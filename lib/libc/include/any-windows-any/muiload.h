/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_MUILOAD
#define _INC_MUILOAD

/* TODO: These are functions provided in muiload library and aren't part
  of DLL. Here implementation of those functions in crt is necessary. */

#ifdef __cplusplus
extern "C" {
#endif

  WINBOOL WINAPI FreeMUILibrary(HMODULE hResModule);
  HINSTANCE WINAPI LoadMUILibrary(LPCTSTR pszFullModuleName,DWORD dwLangConvention,LANGID LangID);
  WINBOOL WINAPI GetUILanguageFallbackList(PWSTR pFallbackList,ULONG cchFallbackList,PULONG pcchFallbackListOut);

#ifdef __cplusplus
}
#endif
#endif /*_INC_MUILOAD*/
