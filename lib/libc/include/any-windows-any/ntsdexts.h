/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _NTSDEXTNS_
#define _NTSDEXTNS_

#ifdef __cplusplus
extern "C" {
#endif

  typedef VOID (__cdecl *PNTSD_OUTPUT_ROUTINE)(char *,...);
  typedef ULONG_PTR (*PNTSD_GET_EXPRESSION)(char *);
  typedef VOID (*PNTSD_GET_SYMBOL)(ULONG_PTR offset,PUCHAR pchBuffer,ULONG_PTR *pDisplacement);
  typedef DWORD (*PNTSD_DISASM)(ULONG_PTR *lpOffset,LPSTR lpBuffer,ULONG fShowEfeectiveAddress);
  typedef WINBOOL (*PNTSD_CHECK_CONTROL_C)(VOID);

  typedef struct _NTSD_EXTENSION_APIS {
    DWORD nSize;
    PNTSD_OUTPUT_ROUTINE lpOutputRoutine;
    PNTSD_GET_EXPRESSION lpGetExpressionRoutine;
    PNTSD_GET_SYMBOL lpGetSymbolRoutine;
    PNTSD_DISASM lpDisasmRoutine;
    PNTSD_CHECK_CONTROL_C lpCheckControlCRoutine;
  } NTSD_EXTENSION_APIS,*PNTSD_EXTENSION_APIS;

  typedef VOID (*PNTSD_EXTENSION_ROUTINE)(HANDLE hCurrentProcess,HANDLE hCurrentThread,DWORD dwCurrentPc,PNTSD_EXTENSION_APIS lpExtensionApis,LPSTR lpArgumentString);

#ifdef __cplusplus
}
#endif
#endif
