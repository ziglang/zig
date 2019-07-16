/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _STLLOCK_H_
#define _STLLOCK_H_

#ifdef __cplusplus

class CCritSec : public CRITICAL_SECTION {
public:
  CCritSec() { InitializeCriticalSection(this); }
  ~CCritSec() { DeleteCriticalSection(this); }
  void Enter() { EnterCriticalSection(this); }
  void Leave() { LeaveCriticalSection(this); }
};

#endif /* __cplusplus */

#endif
