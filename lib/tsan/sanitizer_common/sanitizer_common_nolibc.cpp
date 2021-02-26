//===-- sanitizer_common_nolibc.cpp ---------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains stubs for libc function to facilitate optional use of
// libc in no-libcdep sources.
//===----------------------------------------------------------------------===//

#include "sanitizer_platform.h"
#include "sanitizer_common.h"
#include "sanitizer_libc.h"

namespace __sanitizer {

// The Windows implementations of these functions use the win32 API directly,
// bypassing libc.
#if !SANITIZER_WINDOWS
#if SANITIZER_LINUX
void LogMessageOnPrintf(const char *str) {}
#endif
void WriteToSyslog(const char *buffer) {}
void Abort() { internal__exit(1); }
void SleepForSeconds(int seconds) { internal_sleep(seconds); }
#endif // !SANITIZER_WINDOWS

#if !SANITIZER_WINDOWS && !SANITIZER_MAC
void ListOfModules::init() {}
#endif

}  // namespace __sanitizer
