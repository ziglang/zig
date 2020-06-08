/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _IO_APISET_H_
#define _IO_APISET_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10
  WINBASEAPI WINBOOL WINAPI GetOverlappedResult (HANDLE hFile, LPOVERLAPPED lpOverlapped, LPDWORD lpNumberOfBytesTransferred, WINBOOL bWait);
  WINBASEAPI HANDLE WINAPI CreateIoCompletionPort (HANDLE FileHandle, HANDLE ExistingCompletionPort, ULONG_PTR CompletionKey, DWORD NumberOfConcurrentThreads);
  WINBASEAPI WINBOOL WINAPI GetQueuedCompletionStatus (HANDLE CompletionPort, LPDWORD lpNumberOfBytesTransferred, PULONG_PTR lpCompletionKey, LPOVERLAPPED *lpOverlapped, DWORD dwMilliseconds);
  WINBASEAPI WINBOOL WINAPI PostQueuedCompletionStatus (HANDLE CompletionPort, DWORD dwNumberOfBytesTransferred, ULONG_PTR dwCompletionKey, LPOVERLAPPED lpOverlapped);
  WINBASEAPI WINBOOL WINAPI DeviceIoControl (HANDLE hDevice, DWORD dwIoControlCode, LPVOID lpInBuffer, DWORD nInBufferSize, LPVOID lpOutBuffer, DWORD nOutBufferSize, LPDWORD lpBytesReturned, LPOVERLAPPED lpOverlapped);
  WINBASEAPI WINBOOL WINAPI CancelIo (HANDLE hFile);
  WINBASEAPI WINBOOL WINAPI GetOverlappedResultEx (HANDLE hFile, LPOVERLAPPED lpOverlapped, LPDWORD lpNumberOfBytesTransferred, DWORD dwMilliseconds, WINBOOL bAlertable);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI GetQueuedCompletionStatusEx (HANDLE CompletionPort, LPOVERLAPPED_ENTRY lpCompletionPortEntries, ULONG ulCount, PULONG ulNumEntriesRemoved, DWORD dwMilliseconds, WINBOOL fAlertable);
  WINBASEAPI WINBOOL WINAPI CancelIoEx (HANDLE hFile, LPOVERLAPPED lpOverlapped);
#if _WIN32_WINNT >= _WIN32_WINNT_WIN8
  WINBASEAPI WINBOOL WINAPI GetOverlappedResultEx (HANDLE hFile, LPOVERLAPPED lpOverlapped, LPDWORD lpNumberOfBytesTransferred, DWORD dwMilliseconds, WINBOOL bAlertable);
#endif
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI CancelSynchronousIo (HANDLE hThread);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
