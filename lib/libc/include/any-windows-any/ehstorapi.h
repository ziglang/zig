/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EHSTORAPI
#define _INC_EHSTORAPI

#if (_WIN32_WINNT >= 0x0601)
#ifdef __cplusplus
extern "C" {
#endif

typedef struct _ACT_AUTHORIZATION_STATE {
  ULONG ulState;
} ACT_AUTHORIZATION_STATE, *PACT_AUTHORIZATION_STATE;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0601)*/
#endif /*_INC_EHSTORAPI*/
