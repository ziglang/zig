//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#if defined(__MVS__)
// As part of monotonic clock support on z/OS we need macro _LARGE_TIME_API
// to be defined before any system header to include definition of struct timespec64.
#define _LARGE_TIME_API
#endif

#include <cerrno>        // errno
#include <chrono>
#include <system_error>  // __throw_system_error

#if defined(__MVS__)
#include <__support/ibm/gettod_zos.h> // gettimeofdayMonotonic
#endif

#include <time.h>        // clock_gettime and CLOCK_{MONOTONIC,REALTIME,MONOTONIC_RAW}
#include "include/apple_availability.h"

#if __has_include(<unistd.h>)
# include <unistd.h>
#endif

#if __has_include(<sys/time.h>)
# include <sys/time.h> // for gettimeofday and timeval
#endif

#if !defined(__APPLE__) && defined(_POSIX_TIMERS) && _POSIX_TIMERS > 0
# define _LIBCPP_USE_CLOCK_GETTIME
#endif

#if defined(_LIBCPP_WIN32API)
#  define WIN32_LEAN_AND_MEAN
#  define VC_EXTRA_LEAN
#  include <windows.h>
#  if _WIN32_WINNT >= _WIN32_WINNT_WIN8
#    include <winapifamily.h>
#  endif
#endif // defined(_LIBCPP_WIN32API)

#if defined(__Fuchsia__)
#  include <zircon/syscalls.h>
#endif

#if __has_include(<mach/mach_time.h>)
# include <mach/mach_time.h>
#endif

#if defined(__ELF__) && defined(_LIBCPP_LINK_RT_LIB)
#  pragma comment(lib, "rt")
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

namespace chrono
{

//
// system_clock
//

#if defined(_LIBCPP_WIN32API)

#if _WIN32_WINNT < _WIN32_WINNT_WIN8

namespace {

typedef void(WINAPI *GetSystemTimeAsFileTimePtr)(LPFILETIME);

class GetSystemTimeInit {
public:
  GetSystemTimeInit() {
    fp = (GetSystemTimeAsFileTimePtr)GetProcAddress(
        GetModuleHandleW(L"kernel32.dll"), "GetSystemTimePreciseAsFileTime");
    if (fp == nullptr)
      fp = GetSystemTimeAsFileTime;
  }
  GetSystemTimeAsFileTimePtr fp;
};

// Pretend we're inside a system header so the compiler doesn't flag the use of the init_priority
// attribute with a value that's reserved for the implementation (we're the implementation).
#include "chrono_system_time_init.h"
} // namespace

#endif

static system_clock::time_point __libcpp_system_clock_now() {
  // FILETIME is in 100ns units
  using filetime_duration =
      _VSTD::chrono::duration<__int64,
                              _VSTD::ratio_multiply<_VSTD::ratio<100, 1>,
                                                    nanoseconds::period>>;

  // The Windows epoch is Jan 1 1601, the Unix epoch Jan 1 1970.
  static _LIBCPP_CONSTEXPR const seconds nt_to_unix_epoch{11644473600};

  FILETIME ft;
#if (_WIN32_WINNT >= _WIN32_WINNT_WIN8 && WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)) || \
    (_WIN32_WINNT >= _WIN32_WINNT_WIN10)
  GetSystemTimePreciseAsFileTime(&ft);
#elif !WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
  GetSystemTimeAsFileTime(&ft);
#else
  GetSystemTimeAsFileTimeFunc.fp(&ft);
#endif

  filetime_duration d{(static_cast<__int64>(ft.dwHighDateTime) << 32) |
                       static_cast<__int64>(ft.dwLowDateTime)};
  return system_clock::time_point(duration_cast<system_clock::duration>(d - nt_to_unix_epoch));
}

#elif defined(CLOCK_REALTIME) && defined(_LIBCPP_USE_CLOCK_GETTIME)

static system_clock::time_point __libcpp_system_clock_now() {
  struct timespec tp;
  if (0 != clock_gettime(CLOCK_REALTIME, &tp))
    __throw_system_error(errno, "clock_gettime(CLOCK_REALTIME) failed");
  return system_clock::time_point(seconds(tp.tv_sec) + microseconds(tp.tv_nsec / 1000));
}

#else

static system_clock::time_point __libcpp_system_clock_now() {
    timeval tv;
    gettimeofday(&tv, 0);
    return system_clock::time_point(seconds(tv.tv_sec) + microseconds(tv.tv_usec));
}

#endif

const bool system_clock::is_steady;

system_clock::time_point
system_clock::now() noexcept
{
    return __libcpp_system_clock_now();
}

time_t
system_clock::to_time_t(const time_point& t) noexcept
{
    return time_t(duration_cast<seconds>(t.time_since_epoch()).count());
}

system_clock::time_point
system_clock::from_time_t(time_t t) noexcept
{
    return system_clock::time_point(seconds(t));
}

//
// steady_clock
//
// Warning:  If this is not truly steady, then it is non-conforming.  It is
//  better for it to not exist and have the rest of libc++ use system_clock
//  instead.
//

#ifndef _LIBCPP_HAS_NO_MONOTONIC_CLOCK

#if defined(__APPLE__)

// TODO(ldionne):
// This old implementation of steady_clock is retained until Chrome drops supports
// for macOS < 10.12. The issue is that they link libc++ statically into their
// application, which means that libc++ must support being built for such deployment
// targets. See https://llvm.org/D74489 for details.
#if (defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__) && __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ < 101200) || \
    (defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__) && __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ < 100000) || \
    (defined(__ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__) && __ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__ < 100000) || \
    (defined(__ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__) && __ENVIRONMENT_WATCH_OS_VERSION_MIN_REQUIRED__ < 30000)
# define _LIBCPP_USE_OLD_MACH_ABSOLUTE_TIME
#endif

#if defined(_LIBCPP_USE_OLD_MACH_ABSOLUTE_TIME)

//   mach_absolute_time() * MachInfo.numer / MachInfo.denom is the number of
//   nanoseconds since the computer booted up.  MachInfo.numer and MachInfo.denom
//   are run time constants supplied by the OS.  This clock has no relationship
//   to the Gregorian calendar.  It's main use is as a high resolution timer.

// MachInfo.numer / MachInfo.denom is often 1 on the latest equipment.  Specialize
//   for that case as an optimization.

static steady_clock::rep steady_simplified() {
    return static_cast<steady_clock::rep>(mach_absolute_time());
}
static double compute_steady_factor() {
    mach_timebase_info_data_t MachInfo;
    mach_timebase_info(&MachInfo);
    return static_cast<double>(MachInfo.numer) / MachInfo.denom;
}

static steady_clock::rep steady_full() {
    static const double factor = compute_steady_factor();
    return static_cast<steady_clock::rep>(mach_absolute_time() * factor);
}

typedef steady_clock::rep (*FP)();

static FP init_steady_clock() {
    mach_timebase_info_data_t MachInfo;
    mach_timebase_info(&MachInfo);
    if (MachInfo.numer == MachInfo.denom)
        return &steady_simplified;
    return &steady_full;
}

static steady_clock::time_point __libcpp_steady_clock_now() {
    static FP fp = init_steady_clock();
    return steady_clock::time_point(steady_clock::duration(fp()));
}

#else // vvvvv default behavior for Apple platforms  vvvvv

// On Apple platforms, only CLOCK_UPTIME_RAW, CLOCK_MONOTONIC_RAW or
// mach_absolute_time are able to time functions in the nanosecond range.
// Furthermore, only CLOCK_MONOTONIC_RAW is truly monotonic, because it
// also counts cycles when the system is asleep. Thus, it is the only
// acceptable implementation of steady_clock.
static steady_clock::time_point __libcpp_steady_clock_now() {
    struct timespec tp;
    if (0 != clock_gettime(CLOCK_MONOTONIC_RAW, &tp))
        __throw_system_error(errno, "clock_gettime(CLOCK_MONOTONIC_RAW) failed");
    return steady_clock::time_point(seconds(tp.tv_sec) + nanoseconds(tp.tv_nsec));
}

#endif

#elif defined(_LIBCPP_WIN32API)

// https://msdn.microsoft.com/en-us/library/windows/desktop/ms644905(v=vs.85).aspx says:
//    If the function fails, the return value is zero. <snip>
//    On systems that run Windows XP or later, the function will always succeed
//      and will thus never return zero.

static LARGE_INTEGER
__QueryPerformanceFrequency()
{
    LARGE_INTEGER val;
    (void) QueryPerformanceFrequency(&val);
    return val;
}

static steady_clock::time_point __libcpp_steady_clock_now() {
  static const LARGE_INTEGER freq = __QueryPerformanceFrequency();

  LARGE_INTEGER counter;
  (void) QueryPerformanceCounter(&counter);
  auto seconds = counter.QuadPart / freq.QuadPart;
  auto fractions = counter.QuadPart % freq.QuadPart;
  auto dur = seconds * nano::den + fractions * nano::den / freq.QuadPart;
  return steady_clock::time_point(steady_clock::duration(dur));
}

#elif defined(__MVS__)

static steady_clock::time_point __libcpp_steady_clock_now() {
  struct timespec64 ts;
  if (0 != gettimeofdayMonotonic(&ts))
    __throw_system_error(errno, "failed to obtain time of day");

  return steady_clock::time_point(seconds(ts.tv_sec) + nanoseconds(ts.tv_nsec));
}

#  elif defined(__Fuchsia__)

static steady_clock::time_point __libcpp_steady_clock_now() noexcept {
  // Implicitly link against the vDSO system call ABI without
  // requiring the final link to specify -lzircon explicitly when
  // statically linking libc++.
#    pragma comment(lib, "zircon")

  return steady_clock::time_point(nanoseconds(_zx_clock_get_monotonic()));
}

#  elif defined(CLOCK_MONOTONIC)

static steady_clock::time_point __libcpp_steady_clock_now() {
    struct timespec tp;
    if (0 != clock_gettime(CLOCK_MONOTONIC, &tp))
        __throw_system_error(errno, "clock_gettime(CLOCK_MONOTONIC) failed");
    return steady_clock::time_point(seconds(tp.tv_sec) + nanoseconds(tp.tv_nsec));
}

#  else
#    error "Monotonic clock not implemented on this platform"
#  endif

const bool steady_clock::is_steady;

steady_clock::time_point
steady_clock::now() noexcept
{
    return __libcpp_steady_clock_now();
}

#endif // !_LIBCPP_HAS_NO_MONOTONIC_CLOCK

}

_LIBCPP_END_NAMESPACE_STD
