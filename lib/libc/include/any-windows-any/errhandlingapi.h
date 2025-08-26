/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _ERRHANDLING_H_
#define _ERRHANDLING_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
typedef LONG (WINAPI *PTOP_LEVEL_EXCEPTION_FILTER) (struct _EXCEPTION_POINTERS *ExceptionInfo);
typedef PTOP_LEVEL_EXCEPTION_FILTER LPTOP_LEVEL_EXCEPTION_FILTER;
    WINBASEAPI LPTOP_LEVEL_EXCEPTION_FILTER WINAPI SetUnhandledExceptionFilter (LPTOP_LEVEL_EXCEPTION_FILTER lpTopLevelExceptionFilter);
#endif /* WINAPI_PARTITION_APP */
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || defined(WINSTORECOMPAT)
    WINBASEAPI LONG WINAPI UnhandledExceptionFilter (struct _EXCEPTION_POINTERS *ExceptionInfo);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
    WINBASEAPI PVOID WINAPI AddVectoredExceptionHandler (ULONG First, PVECTORED_EXCEPTION_HANDLER Handler);
  WINBASEAPI ULONG WINAPI RemoveVectoredExceptionHandler (PVOID Handle);
  WINBASEAPI PVOID WINAPI AddVectoredContinueHandler (ULONG First, PVECTORED_EXCEPTION_HANDLER Handler);
  WINBASEAPI ULONG WINAPI RemoveVectoredContinueHandler (PVOID Handle);

#if !defined (RC_INVOKED) && defined (WINBASE_DECLARE_RESTORE_LAST_ERROR)
  WINBASEAPI VOID WINAPI RestoreLastError (DWORD dwErrCode);

  typedef VOID (WINAPI *PRESTORE_LAST_ERROR) (DWORD);

#define RESTORE_LAST_ERROR_NAME_A "RestoreLastError"
#define RESTORE_LAST_ERROR_NAME_W L"RestoreLastError"
#define RESTORE_LAST_ERROR_NAME TEXT ("RestoreLastError")
#endif

#endif

#if _WIN32_WINNT >= 0x0600 && (WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || NTDDI_VERSION >= NTDDI_WIN10_VB)
  WINBASEAPI UINT WINAPI GetErrorMode (VOID);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI VOID WINAPI RaiseException (DWORD dwExceptionCode, DWORD dwExceptionFlags, DWORD nNumberOfArguments, CONST ULONG_PTR *lpArguments);
  WINBASEAPI UINT WINAPI SetErrorMode (UINT uMode);
  WINBASEAPI DWORD WINAPI GetLastError (VOID);
  WINBASEAPI VOID WINAPI SetLastError (DWORD dwErrCode);
#endif

#ifdef __cplusplus
}
#endif
#endif
