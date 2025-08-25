/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EAPMETHODTYPES
#define _INC_EAPMETHODTYPES
#if (_WIN32_WINNT >= 0x0600)
#include <eaptypes.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef struct tagEapPacket {
  BYTE Code;
  BYTE Id;
  BYTE Length[2];
  BYTE Data[1];
} EapPacket;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_EAPMETHODTYPES*/
