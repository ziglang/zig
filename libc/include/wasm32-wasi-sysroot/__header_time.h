#ifndef __wasilibc___header_time_h
#define __wasilibc___header_time_h

#define __need_size_t
#define __need_NULL
#include <stddef.h>

#include <__typedef_time_t.h>
#include <__struct_timespec.h>
#include <__struct_tm.h>
#include <__typedef_clockid_t.h>

#include <wasi/core.h>

#define TIMER_ABSTIME __WASI_SUBSCRIPTION_CLOCK_ABSTIME

extern const struct __clockid _CLOCK_MONOTONIC;
#define CLOCK_MONOTONIC (&_CLOCK_MONOTONIC)
extern const struct __clockid _CLOCK_PROCESS_CPUTIME_ID;
#define CLOCK_PROCESS_CPUTIME_ID (&_CLOCK_PROCESS_CPUTIME_ID)
extern const struct __clockid _CLOCK_REALTIME;
#define CLOCK_REALTIME (&_CLOCK_REALTIME)
extern const struct __clockid _CLOCK_THREAD_CPUTIME_ID;
#define CLOCK_THREAD_CPUTIME_ID (&_CLOCK_THREAD_CPUTIME_ID)

#define TIME_UTC __WASI_CLOCK_REALTIME

/* FIXME: POSIX requires this to be 1000000, and that's what glibc and musl use. */
#define CLOCKS_PER_SEC (1000000000)

#endif
