/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __STRALIGN_H_S_
#define __STRALIGN_H_S_

#include <stralign.h>

#ifdef __cplusplus
extern "C" {
#endif

#if !defined(_X86_) && defined(_WSTRING_S_DEFINED)
#if defined(__cplusplus) && defined(_WConst_Return)
  static __inline PUWSTR ua_wcscpy_s(PUWSTR Destination,size_t DestinationSize,PCUWSTR Source) {
    if(WSTR_ALIGNED(Source) && WSTR_ALIGNED(Destination)) return (wcscpy_s((PWSTR)Destination,DestinationSize,(PCWSTR)Source)==0 ? Destination : NULL);
    return uaw_wcscpy((PCUWSTR)String,Character);
  }
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
