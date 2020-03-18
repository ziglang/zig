/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _NAMEDPIPE_H_
#define _NAMEDPIPE_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINADVAPI WINBOOL WINAPI ImpersonateNamedPipeClient (HANDLE hNamedPipe);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10
  WINBASEAPI WINBOOL WINAPI CreatePipe (PHANDLE hReadPipe, PHANDLE hWritePipe, LPSECURITY_ATTRIBUTES lpPipeAttributes, DWORD nSize);
  WINBASEAPI WINBOOL WINAPI ConnectNamedPipe (HANDLE hNamedPipe, LPOVERLAPPED lpOverlapped);
  WINBASEAPI WINBOOL WINAPI DisconnectNamedPipe (HANDLE hNamedPipe);
  WINBASEAPI WINBOOL WINAPI SetNamedPipeHandleState (HANDLE hNamedPipe, LPDWORD lpMode, LPDWORD lpMaxCollectionCount, LPDWORD lpCollectDataTimeout);
  WINBASEAPI WINBOOL WINAPI PeekNamedPipe (HANDLE hNamedPipe, LPVOID lpBuffer, DWORD nBufferSize, LPDWORD lpBytesRead, LPDWORD lpTotalBytesAvail, LPDWORD lpBytesLeftThisMessage);
  WINBASEAPI WINBOOL WINAPI TransactNamedPipe (HANDLE hNamedPipe, LPVOID lpInBuffer, DWORD nInBufferSize, LPVOID lpOutBuffer, DWORD nOutBufferSize, LPDWORD lpBytesRead, LPOVERLAPPED lpOverlapped);
  WINBASEAPI HANDLE WINAPI CreateNamedPipeW (LPCWSTR lpName, DWORD dwOpenMode, DWORD dwPipeMode, DWORD nMaxInstances, DWORD nOutBufferSize, DWORD nInBufferSize, DWORD nDefaultTimeOut, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  WINBASEAPI WINBOOL WINAPI WaitNamedPipeW (LPCWSTR lpNamedPipeName, DWORD nTimeOut);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI GetNamedPipeClientComputerNameW (HANDLE Pipe, LPWSTR ClientComputerName, ULONG ClientComputerNameLength);
#endif

#ifdef UNICODE
#define CreateNamedPipe CreateNamedPipeW
#define WaitNamedPipe WaitNamedPipeW
#define GetNamedPipeClientComputerName GetNamedPipeClientComputerNameW
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
