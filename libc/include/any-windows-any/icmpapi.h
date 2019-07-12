/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _ICMP_INCLUDED_
#define _ICMP_INCLUDED_

#ifdef __cplusplus
extern "C" {
#endif

  HANDLE WINAPI IcmpCreateFile(VOID);
  HANDLE WINAPI Icmp6CreateFile(VOID);
  WINBOOL WINAPI IcmpCloseHandle(HANDLE IcmpHandle);
  DWORD WINAPI IcmpSendEcho(HANDLE IcmpHandle,IPAddr DestinationAddress,LPVOID RequestData,WORD RequestSize,PIP_OPTION_INFORMATION RequestOptions,LPVOID ReplyBuffer,DWORD ReplySize,DWORD Timeout);

#ifdef PIO_APC_ROUTINE_DEFINED
  DWORD WINAPI IcmpSendEcho2(HANDLE IcmpHandle,HANDLE Event,PIO_APC_ROUTINE ApcRoutine,PVOID ApcContext,IPAddr DestinationAddress,LPVOID RequestData,WORD RequestSize,PIP_OPTION_INFORMATION RequestOptions,LPVOID ReplyBuffer,DWORD ReplySize,DWORD Timeout);
  DWORD WINAPI Icmp6SendEcho2(HANDLE IcmpHandle,HANDLE Event,PIO_APC_ROUTINE ApcRoutine,PVOID ApcContext,struct sockaddr_in6 *SourceAddress,struct sockaddr_in6 *DestinationAddress,LPVOID RequestData,WORD RequestSize,PIP_OPTION_INFORMATION RequestOptions,LPVOID ReplyBuffer,DWORD ReplySize,DWORD Timeout);
#else
  DWORD WINAPI IcmpSendEcho2(HANDLE IcmpHandle,HANDLE Event,FARPROC ApcRoutine,PVOID ApcContext,IPAddr DestinationAddress,LPVOID RequestData,WORD RequestSize,PIP_OPTION_INFORMATION RequestOptions,LPVOID ReplyBuffer,DWORD ReplySize,DWORD Timeout);
  DWORD WINAPI Icmp6SendEcho2(HANDLE IcmpHandle,HANDLE Event,FARPROC ApcRoutine,PVOID ApcContext,struct sockaddr_in6 *SourceAddress,struct sockaddr_in6 *DestinationAddress,LPVOID RequestData,WORD RequestSize,PIP_OPTION_INFORMATION RequestOptions,LPVOID ReplyBuffer,DWORD ReplySize,DWORD Timeout);
#endif

  DWORD WINAPI IcmpParseReplies(LPVOID ReplyBuffer,DWORD ReplySize);
  DWORD WINAPI Icmp6ParseReplies(LPVOID ReplyBuffer,DWORD ReplySize);

#ifdef __cplusplus
}
#endif
#endif
