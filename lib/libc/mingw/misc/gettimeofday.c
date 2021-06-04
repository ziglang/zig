/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <time.h>
#include <sys/time.h>
#include <sys/timeb.h>
#include <errno.h>
#include <windows.h>

#define FILETIME_1970 116444736000000000ull /* seconds between 1/1/1601 and 1/1/1970 */
#define HECTONANOSEC_PER_SEC 10000000ull

int getntptimeofday (struct timespec *, struct timezone *);

int getntptimeofday (struct timespec *tp, struct timezone *z)
{
  int res = 0;
  union {
    unsigned long long ns100; /*time since 1 Jan 1601 in 100ns units */
    FILETIME ft;
  }  _now;
  TIME_ZONE_INFORMATION  TimeZoneInformation;
  DWORD tzi;

  if (z != NULL)
    {
      if ((tzi = GetTimeZoneInformation(&TimeZoneInformation)) != TIME_ZONE_ID_INVALID) {
	z->tz_minuteswest = TimeZoneInformation.Bias;
	if (tzi == TIME_ZONE_ID_DAYLIGHT)
	  z->tz_dsttime = 1;
	else
	  z->tz_dsttime = 0;
      }
    else
      {
	z->tz_minuteswest = 0;
	z->tz_dsttime = 0;
      }
    }

  if (tp != NULL) {
    typedef void (WINAPI * GetSystemTimeAsFileTime_t)(LPFILETIME);
    static GetSystemTimeAsFileTime_t GetSystemTimeAsFileTime_p /* = 0 */;

    /* Set function pointer during first call */
    GetSystemTimeAsFileTime_t get_time =
      __atomic_load_n (&GetSystemTimeAsFileTime_p, __ATOMIC_RELAXED);
    if (get_time == NULL) {
      /* Use GetSystemTimePreciseAsFileTime() if available (Windows 8 or later) */
      get_time = (GetSystemTimeAsFileTime_t)(intptr_t) GetProcAddress (
        GetModuleHandle ("kernel32.dll"),
        "GetSystemTimePreciseAsFileTime"); /* <1us precision on Windows 10 */
      if (get_time == NULL)
        get_time = GetSystemTimeAsFileTime; /* >15ms precision on Windows 10 */
      __atomic_store_n (&GetSystemTimeAsFileTime_p, get_time, __ATOMIC_RELAXED);
    }

    get_time (&_now.ft);	/* 100 nano-seconds since 1-1-1601 */
    _now.ns100 -= FILETIME_1970;	/* 100 nano-seconds since 1-1-1970 */
    tp->tv_sec = _now.ns100 / HECTONANOSEC_PER_SEC;	/* seconds since 1-1-1970 */
    tp->tv_nsec = (long) (_now.ns100 % HECTONANOSEC_PER_SEC) * 100; /* nanoseconds */
  }
  return res;
}

int __cdecl gettimeofday (struct timeval *p, void *z)
{
 struct timespec tp;

 if (getntptimeofday (&tp, (struct timezone *) z))
   return -1;
 p->tv_sec=tp.tv_sec;
 p->tv_usec=(tp.tv_nsec/1000);
 return 0;
}

int __cdecl mingw_gettimeofday (struct timeval *p, struct timezone *z)
{
  struct timespec tp;

  if (getntptimeofday (&tp, z))
    return -1;
  p->tv_sec=tp.tv_sec;
  p->tv_usec=(tp.tv_nsec/1000);
  return 0;
}
