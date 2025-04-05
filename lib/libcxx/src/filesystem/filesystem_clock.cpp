//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <__config>
#include <__system_error/throw_system_error.h>
#include <chrono>
#include <filesystem>
#include <time.h>

#if defined(_LIBCPP_WIN32API)
#  include "time_utils.h"
#endif

#if defined(_LIBCPP_WIN32API)
#  define WIN32_LEAN_AND_MEAN
#  define NOMINMAX
#  include <windows.h>
#endif

#if __has_include(<unistd.h>)
#  include <unistd.h> // _POSIX_TIMERS
#endif

#if __has_include(<sys/time.h>)
#  include <sys/time.h> // for gettimeofday and timeval
#endif

#if defined(__LLVM_LIBC__)
#  define _LIBCPP_HAS_TIMESPEC_GET
#endif

#if defined(__APPLE__) || defined(__gnu_hurd__) || defined(__AMDGPU__) || defined(__NVPTX__) ||                        \
    (defined(_POSIX_TIMERS) && _POSIX_TIMERS > 0)
#  define _LIBCPP_HAS_CLOCK_GETTIME
#endif

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_DIAGNOSTIC_PUSH
_LIBCPP_CLANG_DIAGNOSTIC_IGNORED("-Wdeprecated")
const bool _FilesystemClock::is_steady;
_LIBCPP_DIAGNOSTIC_POP

_FilesystemClock::time_point _FilesystemClock::now() noexcept {
  typedef chrono::duration<rep> __secs;
#if defined(_LIBCPP_WIN32API)
  typedef chrono::duration<rep, nano> __nsecs;
  FILETIME time;
  GetSystemTimeAsFileTime(&time);
  detail::TimeSpec tp = detail::filetime_to_timespec(time);
  return time_point(__secs(tp.tv_sec) + chrono::duration_cast<duration>(__nsecs(tp.tv_nsec)));
#elif defined(_LIBCPP_HAS_TIMESPEC_GET)
  typedef chrono::duration<rep, nano> __nsecs;
  struct timespec ts;
  if (timespec_get(&ts, TIME_UTC) != TIME_UTC)
    __throw_system_error(errno, "timespec_get(TIME_UTC) failed");
  return time_point(__secs(ts.tv_sec) + chrono::duration_cast<duration>(__nsecs(ts.tv_nsec)));
#elif defined(_LIBCPP_HAS_CLOCK_GETTIME)
  typedef chrono::duration<rep, nano> __nsecs;
  struct timespec tp;
  if (0 != clock_gettime(CLOCK_REALTIME, &tp))
    __throw_system_error(errno, "clock_gettime(CLOCK_REALTIME) failed");
  return time_point(__secs(tp.tv_sec) + chrono::duration_cast<duration>(__nsecs(tp.tv_nsec)));
#else
  typedef chrono::duration<rep, micro> __microsecs;
  timeval tv;
  gettimeofday(&tv, 0);
  return time_point(__secs(tv.tv_sec) + __microsecs(tv.tv_usec));
#endif
}

_LIBCPP_END_NAMESPACE_FILESYSTEM
