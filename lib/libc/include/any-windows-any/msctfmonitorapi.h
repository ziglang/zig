/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_MSCTFMONITORAPI
#define _INC_MSCTFMONITORAPI

#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

HRESULT CALLBACK UninitLocalMsCtfMonitor(void);
HRESULT CALLBACK InitLocalMsCtfMonitor(
  DWORD dwFlags
);

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /* _INC_MSCTFMONITORAPI */
