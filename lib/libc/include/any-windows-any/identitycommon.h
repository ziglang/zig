/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __IDENTIYCOMMON_H__
#define __IDENTIYCOMMON_H__
#if (_WIN32_WINNT >= 0x0601)

typedef enum _IDENTITY_TYPE {
  IDENTITIES_ALL       = 0,
  IDENTITIES_ME_ONLY   = 0x1 
} IDENTITY_TYPE;


#endif /*(_WIN32_WINNT >= 0x0601)*/
#endif /*__IDENTIYCOMMON_H__*/
