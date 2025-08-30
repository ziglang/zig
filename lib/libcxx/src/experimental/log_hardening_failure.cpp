//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <__config>
#include <__log_hardening_failure>
#include <cstdio>

#ifdef __BIONIC__
#  include <syslog.h>
#endif // __BIONIC__

_LIBCPP_BEGIN_NAMESPACE_STD

void __log_hardening_failure(const char* message) noexcept {
  // Always log the message to `stderr` in case the platform-specific system calls fail.
  std::fputs(message, stderr);

#if defined(__BIONIC__)
  // Show error in logcat. The latter two arguments are ignored on Android.
  openlog("libc++", 0, 0);
  syslog(LOG_CRIT, "%s", message);
  closelog();
#endif
}

_LIBCPP_END_NAMESPACE_STD
