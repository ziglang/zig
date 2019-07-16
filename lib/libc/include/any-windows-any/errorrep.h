/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __ERRORREP_H__
#define __ERRORREP_H__

#include <_mingw_unicode.h>

typedef enum tagEFaultRepRetVal {
  frrvOk = 0,
  frrvOkManifest,frrvOkQueued,frrvErr,frrvErrNoDW,frrvErrTimeout,frrvLaunchDebugger,frrvOkHeadless
} EFaultRepRetVal;

EFaultRepRetVal WINAPI ReportFault(LPEXCEPTION_POINTERS pep,DWORD dwOpt);
WINBOOL WINAPI AddERExcludedApplicationA(LPCSTR szApplication);
WINBOOL WINAPI AddERExcludedApplicationW(LPCWSTR wszApplication);

typedef EFaultRepRetVal (WINAPI *pfn_REPORTFAULT)(LPEXCEPTION_POINTERS,DWORD);
typedef EFaultRepRetVal (WINAPI *pfn_ADDEREXCLUDEDAPPLICATIONA)(LPCSTR);
typedef EFaultRepRetVal (WINAPI *pfn_ADDEREXCLUDEDAPPLICATIONW)(LPCWSTR);

#define AddERExcludedApplication __MINGW_NAME_AW(AddERExcludedApplication)
#define pfn_ADDEREXCLUDEDAPPLICATION __MINGW_NAME_AW(pfn_ADDEREXCLUDEDAPPLICATION)

#endif
