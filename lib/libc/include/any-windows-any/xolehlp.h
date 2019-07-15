/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __XOLEHLP__H__
#define __XOLEHLP__H__

#include <_mingw_unicode.h>

#define EXPORTAPI __declspec(dllexport) HRESULT

const DWORD OLE_TM_CONFIG_VERSION_1 = 1;
const DWORD OLE_TM_FLAG_NONE = 0x00000000;
const DWORD OLE_TM_FLAG_NODEMANDSTART = 0x00000001;

const DWORD OLE_TM_FLAG_QUERY_SERVICE_LOCKSTATUS = 0x80000000;
const DWORD OLE_TM_FLAG_INTERNAL_TO_TM = 0x40000000;

typedef struct _OLE_TM_CONFIG_PARAMS_V1 {
  DWORD dwVersion;
  DWORD dwcConcurrencyHint;
} OLE_TM_CONFIG_PARAMS_V1;

#define DtcGetTransactionManagerEx __MINGW_NAME_AW(DtcGetTransactionManagerEx)

EXPORTAPI __cdecl DtcGetTransactionManager(char *i_pszHost,char *i_pszTmName,REFIID i_riid,DWORD i_dwReserved1,WORD i_wcbReserved2,void *i_pvReserved2,void **o_ppvObject);
EXTERN_C HRESULT __cdecl DtcGetTransactionManagerC(char *i_pszHost,char *i_pszTmName,REFIID i_riid,DWORD i_dwReserved1,WORD i_wcbReserved2,void *i_pvReserved2,void **o_ppvObject);
EXTERN_C EXPORTAPI __cdecl DtcGetTransactionManagerExA(char *i_pszHost,char *i_pszTmName,REFIID i_riid,DWORD i_grfOptions,void *i_pvConfigParams,void **o_ppvObject);
EXTERN_C EXPORTAPI __cdecl DtcGetTransactionManagerExW(WCHAR *i_pwszHost,WCHAR *i_pwszTmName,REFIID i_riid,DWORD i_grfOptions,void *i_pvConfigParams,void **o_ppvObject);

#ifndef EXTERN_GUID
#define EXTERN_GUID(g,l1,s1,s2,c1,c2,c3,c4,c5,c6,c7,c8) DEFINE_GUID(g,l1,s1,s2,c1,c2,c3,c4,c5,c6,c7,c8)
#endif

EXTERN_GUID(CLSID_MSDtcTransactionManager,0x5b18ab61,0x91d,0x11d1,0x97,0xdf,0x0,0xc0,0x4f,0xb9,0x61,0x8a);
EXTERN_GUID(CLSID_MSDtcTransaction,0x39f8d76b,0x928,0x11d1,0x97,0xdf,0x0,0xc0,0x4f,0xb9,0x61,0x8a);
#endif
