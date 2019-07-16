/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _COMM_H_
#define _COMM_H_

#include <winapifamily.h>
#include <apiset.h>
#include <apisetcconv.h>
#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI ClearCommBreak (HANDLE hFile);
  WINBASEAPI WINBOOL WINAPI ClearCommError (HANDLE hFile, LPDWORD lpErrors, LPCOMSTAT lpStat);
  WINBASEAPI WINBOOL WINAPI SetupComm (HANDLE hFile, DWORD dwInQueue, DWORD dwOutQueue);
  WINBASEAPI WINBOOL WINAPI EscapeCommFunction (HANDLE hFile, DWORD dwFunc);
  WINBASEAPI WINBOOL WINAPI GetCommConfig (HANDLE hCommDev, LPCOMMCONFIG lpCC, LPDWORD lpdwSize);
  WINBASEAPI WINBOOL WINAPI GetCommMask (HANDLE hFile, LPDWORD lpEvtMask);
  WINBASEAPI WINBOOL WINAPI GetCommModemStatus (HANDLE hFile, LPDWORD lpModemStat);
  WINBASEAPI WINBOOL WINAPI GetCommProperties (HANDLE hFile, LPCOMMPROP lpCommProp);
  WINBASEAPI WINBOOL WINAPI GetCommState (HANDLE hFile, LPDCB lpDCB);
  WINBASEAPI WINBOOL WINAPI GetCommTimeouts (HANDLE hFile, LPCOMMTIMEOUTS lpCommTimeouts);
  WINBASEAPI WINBOOL WINAPI PurgeComm (HANDLE hFile, DWORD dwFlags);
  WINBASEAPI WINBOOL WINAPI SetCommBreak (HANDLE hFile);
  WINBASEAPI WINBOOL WINAPI SetCommConfig (HANDLE hCommDev, LPCOMMCONFIG lpCC, DWORD dwSize);
  WINBASEAPI WINBOOL WINAPI SetCommMask (HANDLE hFile, DWORD dwEvtMask);
  WINBASEAPI WINBOOL WINAPI SetCommState (HANDLE hFile, LPDCB lpDCB);
  WINBASEAPI WINBOOL WINAPI SetCommTimeouts (HANDLE hFile, LPCOMMTIMEOUTS lpCommTimeouts);
  WINBASEAPI WINBOOL WINAPI TransmitCommChar (HANDLE hFile, char cChar);
  WINBASEAPI WINBOOL WINAPI WaitCommEvent (HANDLE hFile, LPDWORD lpEvtMask, LPOVERLAPPED lpOverlapped);
#endif

#ifdef __cplusplus
}
#endif
#endif
