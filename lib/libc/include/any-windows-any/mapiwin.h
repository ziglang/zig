/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __MAPIWIN_H__
#define __MAPIWIN_H__

#include "mapinls.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MULDIV(x,y,z) MulDiv(x,y,z)

  extern LPVOID pinstX;
#define PvGetInstanceGlobals() pinstX
#define ScSetInstanceGlobals(_pv) (pinstX = _pv,0)
#define PvGetVerifyInstanceGlobals(_pid) pinstX
#define ScSetVerifyInstanceGlobals(_pv,_pid) (pinstX = _pv,0)
#define PvSlowGetInstanceGlobals(_pid) pinstX

#define szMAPIDLLSuffix "32"

#define GetTempFileName32(_szPath,_szPfx,_n,_lpbuf) GetTempFileName(_szPath,_szPfx,_n,_lpbuf)
#define CloseMutexHandle CloseHandle
#define Cbtszsize(_a) ((lstrlen(_a)+1)*sizeof(TCHAR))
#define CbtszsizeA(_a) ((lstrlenA(_a) + 1))
#define CbtszsizeW(_a) ((lstrlenW(_a) + 1)*sizeof(WCHAR))
#define HexCchOf(_s) (sizeof(_s)*2+1)
#define HexSizeOf(_s) (HexCchOf(_s)*sizeof(TCHAR))

  WINBOOL WINAPI IsBadBoundedStringPtr(const void *lpsz,UINT cchMax);

#ifdef __cplusplus
}
#endif
#endif
