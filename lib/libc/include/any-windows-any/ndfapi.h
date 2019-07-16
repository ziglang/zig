/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_NDFAPI
#define _INC_NDFAPI

#include <ndattrib.h>

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

HRESULT NdfCloseIncident(
  NDFHANDLE handle
);

HRESULT WINAPI NdfCreateConnectivityIncident(
  NDFHANDLE *handle
);

HRESULT WINAPI NdfCreateDNSIncident(
  LPCWSTR hostname,
  WORD querytype,
  NDFHANDLE *handle
);

HRESULT NdfCreateIncident(
  LPCWSTR helperClassName,
  ULONG celt,
  HELPER_ATTRIBUTE *attributes,
  NDFHANDLE *handle
);

HRESULT WINAPI NdfCreateSharingIncident(
  LPCWSTR sharename,
  NDFHANDLE *handle
);

HRESULT WINAPI NdfCreateWebIncident(
  LPCWSTR url,
  NDFHANDLE *handle
);

HRESULT WINAPI NdfCreateWebIncidentEx(
  LPCWSTR url,
  WINBOOL useWinHTTP,
  LPWSTR moduleName,
  NDFHANDLE *handle
);

HRESULT NdfCreateWinSockIncident(
  SOCKET sock,
  LPCWSTR host,
  USHORT port,
  LPCWSTR appID,
  SID *userId,
  NDFHANDLE *handle
);

HRESULT NdfExecuteDiagnosis(
  NDFHANDLE handle,
  HWND hwnd
);

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /*_INC_NDFAPI*/
