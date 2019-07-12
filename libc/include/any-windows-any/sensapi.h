/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __SENSAPI_H__
#define __SENSAPI_H__

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NETWORK_ALIVE_LAN 0x00000001
#define NETWORK_ALIVE_WAN 0x00000002
#define NETWORK_ALIVE_AOL 0x00000004

  typedef struct tagQOCINFO {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwInSpeed;
    DWORD dwOutSpeed;
  } QOCINFO,*LPQOCINFO;

#define IsDestinationReachable __MINGW_NAME_AW(IsDestinationReachable)

  WINBOOL WINAPI IsDestinationReachableA(LPCSTR lpszDestination,LPQOCINFO lpQOCInfo);
  WINBOOL WINAPI IsDestinationReachableW(LPCWSTR lpszDestination,LPQOCINFO lpQOCInfo);
  WINBOOL WINAPI IsNetworkAlive(LPDWORD lpdwFlags);

#ifdef __cplusplus
}
#endif
#endif
