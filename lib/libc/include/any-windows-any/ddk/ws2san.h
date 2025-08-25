/*
 * ws2san.h
 *
 * WinSock Direct (SAN) support
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#pragma once

#define _WS2SAN_H_

#ifdef __cplusplus
extern "C" {
#endif

#define SO_MAX_RDMA_SIZE                  0x700D
#define SO_RDMA_THRESHOLD_SIZE            0x700E

#define MEM_READ                          1
#define MEM_WRITE                         2
#define MEM_READWRITE                     3

#define WSAID_REGISTERMEMORY \
  {0xC0B422F5, 0xF58C, 0x11d1, {0xAD, 0x6C, 0x00, 0xC0, 0x4F, 0xA3, 0x4A, 0x2D}}

#define WSAID_DEREGISTERMEMORY \
  {0xC0B422F6, 0xF58C, 0x11d1, {0xAD, 0x6C, 0x00, 0xC0, 0x4F, 0xA3, 0x4A, 0x2D}}

#define WSAID_REGISTERRDMAMEMORY \
  {0xC0B422F7, 0xF58C, 0x11d1, {0xAD, 0x6C, 0x00, 0xC0, 0x4F, 0xA3, 0x4A, 0x2D}}

#define WSAID_DEREGISTERRDMAMEMORY \
  {0xC0B422F8, 0xF58C, 0x11d1, {0xAD, 0x6C, 0x00, 0xC0, 0x4F, 0xA3, 0x4A, 0x2D}}

#define WSAID_RDMAWRITE \
  {0xC0B422F9, 0xF58C, 0x11d1, {0xAD, 0x6C, 0x00, 0xC0, 0x4F, 0xA3, 0x4A, 0x2D}}

#define WSAID_RDMAREAD \
  {0xC0B422FA, 0xF58C, 0x11d1, {0xAD, 0x6C, 0x00, 0xC0, 0x4F, 0xA3, 0x4A, 0x2D}}

#if(_WIN32_WINNT >= 0x0501)
#define WSAID_MEMORYREGISTRATIONCACHECALLBACK \
  {0xE5DA4AF8, 0xD824, 0x48CD, {0xA7, 0x99, 0x63, 0x37, 0xA9, 0x8E, 0xD2, 0xAF}}
#endif

typedef struct _WSPUPCALLTABLEEX {
  LPWPUCLOSEEVENT lpWPUCloseEvent;
  LPWPUCLOSESOCKETHANDLE lpWPUCloseSocketHandle;
  LPWPUCREATEEVENT lpWPUCreateEvent;
  LPWPUCREATESOCKETHANDLE lpWPUCreateSocketHandle;
  LPWPUFDISSET lpWPUFDIsSet;
  LPWPUGETPROVIDERPATH lpWPUGetProviderPath;
  LPWPUMODIFYIFSHANDLE lpWPUModifyIFSHandle;
  LPWPUPOSTMESSAGE lpWPUPostMessage;
  LPWPUQUERYBLOCKINGCALLBACK lpWPUQueryBlockingCallback;
  LPWPUQUERYSOCKETHANDLECONTEXT lpWPUQuerySocketHandleContext;
  LPWPUQUEUEAPC lpWPUQueueApc;
  LPWPURESETEVENT lpWPUResetEvent;
  LPWPUSETEVENT lpWPUSetEvent;
  LPWPUOPENCURRENTTHREAD lpWPUOpenCurrentThread;
  LPWPUCLOSETHREAD lpWPUCloseThread;
  LPWPUCOMPLETEOVERLAPPEDREQUEST lpWPUCompleteOverlappedRequest;
} WSPUPCALLTABLEEX, FAR *LPWSPUPCALLTABLEEX;

typedef struct _WSABUFEX {
  u_long len;
  char FAR *buf;
  HANDLE handle;
} WSABUFEX, FAR * LPWSABUFEX;

typedef int
(WSPAPI *LPWSPSTARTUPEX)(
  IN WORD wVersionRequested,
  OUT LPWSPDATA lpWSPData,
  IN LPWSAPROTOCOL_INFOW lpProtocolInfo,
  IN LPWSPUPCALLTABLEEX lpUpcallTable,
  OUT LPWSPPROC_TABLE lpProcTable);

typedef HANDLE
(WSPAPI *LPFN_WSPREGISTERMEMORY)(
  IN SOCKET s,
  IN PVOID lpBuffer,
  IN DWORD dwBufferLength,
  IN DWORD dwFlags,
  OUT LPINT lpErrno);

typedef int
(WSPAPI *LPFN_WSPDEREGISTERMEMORY)(
  IN SOCKET s,
  IN HANDLE Handle,
  OUT LPINT lpErrno);

typedef int
(WSPAPI *LPFN_WSPREGISTERRDMAMEMORY)(
  IN SOCKET s,
  IN PVOID lpBuffer,
  IN DWORD dwBufferLength,
  IN DWORD dwFlags,
  OUT LPVOID lpRdmaBufferDescriptor,
  IN OUT LPDWORD lpdwDescriptorLength,
  OUT LPINT lpErrno);

typedef int
(WSPAPI *LPFN_WSPDEREGISTERRDMAMEMORY)(
  IN SOCKET s,
  IN LPVOID lpRdmaBufferDescriptor,
  IN DWORD dwDescriptorLength,
  OUT LPINT lpErrno);

typedef int
(WSPAPI *LPFN_WSPRDMAWRITE)(
  IN SOCKET s,
  IN LPWSABUFEX lpBuffers,
  IN DWORD dwBufferCount,
  IN LPVOID lpTargetBufferDescriptor,
  IN DWORD dwTargetDescriptorLength,
  IN DWORD dwTargetBufferOffset,
  OUT LPDWORD lpdwNumberOfBytesWritten,
  IN DWORD dwFlags,
  IN LPWSAOVERLAPPED lpOverlapped OPTIONAL,
  IN LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine OPTIONAL,
  IN LPWSATHREADID lpThreadId,
  OUT LPINT lpErrno);

typedef int
(WSPAPI *LPFN_WSPRDMAREAD)(
  IN SOCKET s,
  IN LPWSABUFEX lpBuffers,
  IN DWORD dwBufferCount,
  IN LPVOID lpTargetBufferDescriptor,
  IN DWORD dwTargetDescriptorLength,
  IN DWORD dwTargetBufferOffset,
  OUT LPDWORD lpdwNumberOfBytesRead,
  IN DWORD dwFlags,
  IN LPWSAOVERLAPPED lpOverlapped OPTIONAL,
  IN LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine OPTIONAL,
  IN LPWSATHREADID lpThreadId,
  OUT LPINT lpErrno);

#if(_WIN32_WINNT >= 0x0501)
typedef int
(WSPAPI *LPFN_WSPMEMORYREGISTRATIONCACHECALLBACK)(
  IN PVOID lpvAddress,
  IN SIZE_T Size,
  OUT LPINT lpErrno);
#endif

int
WSPAPI
WSPStartupEx(
  IN WORD wVersionRequested,
  OUT LPWSPDATA lpWSPData,
  IN LPWSAPROTOCOL_INFOW lpProtocolInfo,
  IN LPWSPUPCALLTABLEEX lpUpcallTable,
  OUT LPWSPPROC_TABLE lpProcTable);

HANDLE
WSPAPI
WSPRegisterMemory(
  IN SOCKET s,
  IN PVOID lpBuffer,
  IN DWORD dwBufferLength,
  IN DWORD dwFlags,
  OUT LPINT lpErrno);

int
WSPAPI
WSPDeregisterMemory(
  IN SOCKET s,
  IN HANDLE Handle,
  OUT LPINT lpErrno);

int
WSPAPI
WSPRegisterRdmaMemory(
  IN SOCKET s,
  IN PVOID lpBuffer,
  IN DWORD dwBufferLength,
  IN DWORD dwFlags,
  OUT LPVOID lpRdmaBufferDescriptor,
  IN OUT LPDWORD lpdwDescriptorLength,
  OUT LPINT lpErrno);

int
WSPAPI
WSPDeregisterRdmaMemory(
  IN SOCKET s,
  IN LPVOID lpRdmaBufferDescriptor,
  IN DWORD dwDescriptorLength,
  OUT LPINT lpErrno);

int
WSPAPI
WSPRdmaWrite(
  IN SOCKET s,
  IN LPWSABUFEX lpBuffers,
  IN DWORD dwBufferCount,
  IN LPVOID lpTargetBufferDescriptor,
  IN DWORD dwTargetDescriptorLength,
  IN DWORD dwTargetBufferOffset,
  OUT LPDWORD lpdwNumberOfBytesWritten,
  IN DWORD dwFlags,
  IN LPWSAOVERLAPPED lpOverlapped OPTIONAL,
  IN LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine OPTIONAL,
  IN LPWSATHREADID lpThreadId,
  OUT LPINT lpErrno);

int
WSPAPI
WSPRdmaRead(
  IN SOCKET s,
  IN LPWSABUFEX lpBuffers,
  IN DWORD dwBufferCount,
  IN LPVOID lpTargetBufferDescriptor,
  IN DWORD dwTargetDescriptorLength,
  IN DWORD dwTargetBufferOffset,
  OUT LPDWORD lpdwNumberOfBytesRead,
  IN DWORD dwFlags,
  IN LPWSAOVERLAPPED lpOverlapped OPTIONAL,
  IN LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine OPTIONAL,
  IN LPWSATHREADID lpThreadId,
  OUT LPINT lpErrno);

#if(_WIN32_WINNT >= 0x0501)
int
WSPAPI
WSPMemoryRegistrationCacheCallback(
  IN PVOID lpvAddress,
  IN SIZE_T Size,
  OUT LPINT lpErrno);
#endif

#ifdef __cplusplus
}
#endif
