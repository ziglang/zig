/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _IPX_ADAPTER_
#define _IPX_ADAPTER_

typedef struct _ADDRESS_RESERVED {
  UCHAR Reserved[28];
} ADDRESS_RESERVED,*PADDRESS_RESERVED;

HANDLE WINAPI CreateSocketPort(USHORT Socket);
DWORD WINAPI DeleteSocketPort(HANDLE Handle);
DWORD WINAPI IpxRecvPacket(HANDLE Handle,PUCHAR IpxPacket,ULONG IpxPacketLength,PADDRESS_RESERVED lpReserved,LPOVERLAPPED lpOverlapped,LPOVERLAPPED_COMPLETION_ROUTINE CompletionRoutine);
DWORD WINAPI IpxSendPacket(HANDLE Handle,ULONG AdapterIdx,PUCHAR IpxPacket,ULONG IpxPacketLength,PADDRESS_RESERVED lpReserved,LPOVERLAPPED lpOverlapped,LPOVERLAPPED_COMPLETION_ROUTINE CompletionRoutine);

#define GetNicIdx(pReserved) ((ULONG)*((USHORT *)(pReserved+2)))

#endif
