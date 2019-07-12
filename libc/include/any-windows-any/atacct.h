/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _ATACCT_H_
#define _ATACCT_H_
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#ifdef __cplusplus
extern "C" {
#endif

  STDAPI GetNetScheduleAccountInformation (LPCWSTR pwszServerName, DWORD ccAccount, WCHAR wszAccount[]);
  STDAPI SetNetScheduleAccountInformation (LPCWSTR pwszServerName, LPCWSTR pwszAccount, LPCWSTR pwszPassword);

#ifdef __cplusplus
}
#endif
#endif

#endif
