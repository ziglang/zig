/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_UDPMIB
#define _INC_UDPMIB

#ifndef ANY_SIZE
#define ANY_SIZE 1
#endif

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _MIB_UDP6ROW {
  IN6_ADDR dwLocalAddr;
  DWORD    dwLocalScopeId;
  DWORD    dwLocalPort;
} MIB_UDP6ROW, *PMIB_UDP6ROW;

typedef struct _MIB_UDP6TABLE {
  DWORD       dwNumEntries;
  MIB_UDP6ROW table[ANY_SIZE];
} MIB_UDP6TABLE, *PMIB_UDP6TABLE;

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /*_INC_UDPMIB*/
