/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WDSBP
#define _INC_WDSBP
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef WDSBPAPI
#define WDSBPAPI WINAPI
#endif

/* Wdsbp.dll is missing an implib because Vista clients don't have the dll to generate it from */

HRESULT WDSBPAPI WdsBpAddOption(
  HANDLE hHandle,
  ULONG uOption,
  ULONG uValueLen,
  PVOID pValue
);

HRESULT WDSBPAPI WdsBpCloseHandle(
  HANDLE hHandle
);

HRESULT WDSBPAPI WdsBpGetOptionBuffer(
  HANDLE hHandle,
  ULONG uBufferLen,
  PVOID pBuffer,
  PULONG puBytes
);

#define WDSBP_PK_TYPE_DHCP 1
#define WDSBP_PK_TYPE_WDSNBP 2
#define WDSBP_PK_TYPE_BCD 4

HRESULT WDSBPAPI WdsBpInitialize(
  BYTE bPacketType,
  HANDLE *phHandle
);

HRESULT WDSBPAPI WdsBpParseInitialize(
  PVOID pPacket,
  ULONG uPacketLen,
  PBYTE pbPacketType,
  HANDLE *phHandle
);

HRESULT WDSBPAPI WdsBpQueryOption(
  HANDLE hHandle,
  ULONG uOption,
  ULONG uValueLen,
  PVOID pValue,
  PULONG puBytes
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WDSBP*/
