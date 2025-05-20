/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the w64 mingw-runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <time.h>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#define WINPTHREAD_CLOCK_DECL WINPTHREAD_API

/* public header files */
#include "pthread_time.h"
/* internal header files */
#include "misc.h"

#define POW10_7                 10000000
#define POW10_9                 1000000000

/* Number of 100ns-seconds between the beginning of the Windows epoch
 * (Jan. 1, 1601) and the Unix epoch (Jan. 1, 1970)
 */
#define DELTA_EPOCH_IN_100NS    INT64_C(116444736000000000)

static WINPTHREADS_INLINE int lc_set_errno(int result)
{
    if (result != 0) {
        errno = result;
        return -1;
    }
    return 0;
}

/**
 * Get the resolution of the specified clock clock_id and
 * stores it in the struct timespec pointed to by res.
 * @param  clock_id The clock_id argument is the identifier of the particular
 *         clock on which to act. The following clocks are supported:
 * <pre>
 *     CLOCK_REALTIME  System-wide real-time clock. Setting this clock
 *                 requires appropriate privileges.
 *     CLOCK_MONOTONIC Clock that cannot be set and represents monotonic
 *                 time since some unspecified starting point.
 *     CLOCK_PROCESS_CPUTIME_ID High-resolution per-process timer from the CPU.
 *     CLOCK_THREAD_CPUTIME_ID  Thread-specific CPU-time clock.
 * </pre>
 * @param  res The pointer to a timespec structure to receive the time
 *         resolution.
 * @return If the function succeeds, the return value is 0.
 *         If the function fails, the return value is -1,
 *         with errno set to indicate the error.
 */
static int __clock_getres(clockid_t clock_id, struct _timespec64 *res)
{
    clockid_t id = clock_id;

    if (id == CLOCK_REALTIME && _pthread_get_system_time_best_as_file_time == GetSystemTimeAsFileTime)
        id = CLOCK_REALTIME_COARSE; /* GetSystemTimePreciseAsFileTime() not available */

    switch(id) {
    case CLOCK_REALTIME:
    case CLOCK_MONOTONIC:
        {
            LARGE_INTEGER pf;

            if (QueryPerformanceFrequency(&pf) == 0)
                return lc_set_errno(EINVAL);

            res->tv_sec = 0;
            res->tv_nsec = (int) ((POW10_9 + (pf.QuadPart >> 1)) / pf.QuadPart);
            if (res->tv_nsec < 1)
                res->tv_nsec = 1;

            return 0;
        }

    case CLOCK_REALTIME_COARSE:
    case CLOCK_PROCESS_CPUTIME_ID:
    case CLOCK_THREAD_CPUTIME_ID:
        {
            DWORD   timeAdjustment, timeIncrement;
            BOOL    isTimeAdjustmentDisabled;

            (void) GetSystemTimeAdjustment(&timeAdjustment, &timeIncrement, &isTimeAdjustmentDisabled);
            res->tv_sec = 0;
            res->tv_nsec = timeIncrement * 100;

            return 0;
        }
    default:
        break;
    }

    return lc_set_errno(EINVAL);
}

/**
 * Get the time of the specified clock clock_id and stores it in the struct
 * timespec pointed to by tp.
 * @param  clock_id The clock_id argument is the identifier of the particular
 *         clock on which to act. The following clocks are supported:
 * <pre>
 *     CLOCK_REALTIME  System-wide real-time clock. Setting this clock
 *                 requires appropriate privileges.
 *     CLOCK_MONOTONIC Clock that cannot be set and represents monotonic
 *                 time since some unspecified starting point.
 *     CLOCK_PROCESS_CPUTIME_ID High-resolution per-process timer from the CPU.
 *     CLOCK_THREAD_CPUTIME_ID  Thread-specific CPU-time clock.
 * </pre>
 * @param  tp The pointer to a timespec structure to receive the time.
 * @return If the function succeeds, the return value is 0.
 *         If the function fails, the return value is -1,
 *         with errno set to indicate the error.
 */
static int __clock_gettime(clockid_t clock_id, struct _timespec64 *tp)
{
    unsigned __int64 t;
    LARGE_INTEGER pf, pc;
    union {
        unsigned __int64 u64;
        FILETIME ft;
    }  ct, et, kt, ut;

    switch(clock_id) {
    case CLOCK_REALTIME:
        {
            _pthread_get_system_time_best_as_file_time(&ct.ft);
            t = ct.u64 - DELTA_EPOCH_IN_100NS;
            tp->tv_sec = t / POW10_7;
            tp->tv_nsec = ((int) (t % POW10_7)) * 100;

            return 0;
        }

    case CLOCK_REALTIME_COARSE:
        {
            GetSystemTimeAsFileTime(&ct.ft);
            t = ct.u64 - DELTA_EPOCH_IN_100NS;
            tp->tv_sec = t / POW10_7;
            tp->tv_nsec = ((int) (t % POW10_7)) * 100;

            return 0;
        }

    case CLOCK_MONOTONIC:
        {
            if (QueryPerformanceFrequency(&pf) == 0)
                return lc_set_errno(EINVAL);

            if (QueryPerformanceCounter(&pc) == 0)
                return lc_set_errno(EINVAL);

            tp->tv_sec = pc.QuadPart / pf.QuadPart;
            tp->tv_nsec = (int) (((pc.QuadPart % pf.QuadPart) * POW10_9 + (pf.QuadPart >> 1)) / pf.QuadPart);
            if (tp->tv_nsec >= POW10_9) {
                tp->tv_sec ++;
                tp->tv_nsec -= POW10_9;
            }

            return 0;
        }

    case CLOCK_PROCESS_CPUTIME_ID:
        {
        if(0 == GetProcessTimes(GetCurrentProcess(), &ct.ft, &et.ft, &kt.ft, &ut.ft))
            return lc_set_errno(EINVAL);
        t = kt.u64 + ut.u64;
        tp->tv_sec = t / POW10_7;
        tp->tv_nsec = ((int) (t % POW10_7)) * 100;

        return 0;
        }

    case CLOCK_THREAD_CPUTIME_ID:
        {
            if(0 == GetThreadTimes(GetCurrentThread(), &ct.ft, &et.ft, &kt.ft, &ut.ft))
                return lc_set_errno(EINVAL);
            t = kt.u64 + ut.u64;
            tp->tv_sec = t / POW10_7;
            tp->tv_nsec = ((int) (t % POW10_7)) * 100;

            return 0;
        }

    default:
        break;
    }

    return lc_set_errno(EINVAL);
}

/**
 * Sleep for the specified time.
 * @param  clock_id This argument should always be CLOCK_REALTIME (0).
 * @param  flags 0 for relative sleep interval, others for absolute waking up.
 * @param  request The desired sleep interval or absolute waking up time.
 * @param  remain The remain amount of time to sleep.
 *         The current implemention just ignore it.
 * @return If the function succeeds, the return value is 0.
 *         If the function fails, the return value is -1,
 *         with errno set to indicate the error.
 */
static int __clock_nanosleep(clockid_t clock_id, int flags,
                           const struct _timespec64 *request,
                           struct _timespec64 *remain)
{
    struct _timespec64 tp;

    if (clock_id != CLOCK_REALTIME)
        return lc_set_errno(EINVAL);

    if (flags == 0)
        return nanosleep64(request, remain);

    /* TIMER_ABSTIME = 1 */
    __clock_gettime(CLOCK_REALTIME, &tp);

    tp.tv_sec = request->tv_sec - tp.tv_sec;
    tp.tv_nsec = request->tv_nsec - tp.tv_nsec;
    if (tp.tv_nsec < 0) {
        tp.tv_nsec += POW10_9;
        tp.tv_sec --;
    }

    return nanosleep64(&tp, remain);
}

/**
 * Set the time of the specified clock clock_id.
 * @param  clock_id This argument should always be CLOCK_REALTIME (0).
 * @param  tp The requested time.
 * @return If the function succeeds, the return value is 0.
 *         If the function fails, the return value is -1,
 *         with errno set to indicate the error.
 */
static int __clock_settime(clockid_t clock_id, const struct _timespec64 *tp)
{
    SYSTEMTIME st;

    union {
        unsigned __int64 u64;
        FILETIME ft;
    }  t;

    if (clock_id != CLOCK_REALTIME)
        return lc_set_errno(EINVAL);

    t.u64 = tp->tv_sec * (__int64) POW10_7 + tp->tv_nsec / 100 + DELTA_EPOCH_IN_100NS;
    if (FileTimeToSystemTime(&t.ft, &st) == 0)
        return lc_set_errno(EINVAL);

    if (SetSystemTime(&st) == 0)
        return lc_set_errno(EPERM);

    return 0;
}

/**
 * Versions to use with 64-bit time_t (struct _timespec64)
 */

int clock_getres64 (clockid_t clock_id, struct _timespec64 *tp)
{
    return __clock_getres (clock_id, tp);
}

int clock_gettime64 (clockid_t clock_id, struct _timespec64 *tp)
{
    return __clock_gettime (clock_id, tp);
}

int clock_settime64 (clockid_t clock_id, const struct _timespec64 *tp)
{
    return __clock_settime (clock_id, tp);
}

int clock_nanosleep64 (clockid_t clock_id, int flags,
                const struct _timespec64 *request, struct _timespec64 *remain)
{
    return __clock_nanosleep (clock_id, flags, request, remain);
}

/**
 * Versions to use with 32-bit time_t (struct _timespec32)
 */

int clock_getres32 (clockid_t clock_id, struct _timespec32 *tp)
{
    struct _timespec64 tp64 = {0};

    if (__clock_getres (clock_id, &tp64) == -1)
        return -1;

    tp->tv_sec = (__time32_t) tp64.tv_sec;
    tp->tv_nsec = tp64.tv_nsec;

    return 0;
}

int clock_gettime32 (clockid_t clock_id, struct _timespec32 *tp)
{
    struct _timespec64 tp64 = {0};

    if (__clock_gettime (clock_id, &tp64) == -1)
        return -1;

    if (tp64.tv_sec > INT_MAX)
    {
        _set_errno (EOVERFLOW);
        return -1;
    }

    tp->tv_sec = (__time32_t) tp64.tv_sec;
    tp->tv_nsec = tp64.tv_nsec;

    return 0;
}

int clock_settime32 (clockid_t clock_id, const struct _timespec32 *tp)
{
    struct _timespec64 tp64 = {.tv_sec = tp->tv_sec, .tv_nsec = tp->tv_nsec};
    return __clock_settime (clock_id, &tp64);
}

int clock_nanosleep32 (clockid_t clock_id, int flags,
                const struct _timespec32 *request, struct _timespec32 *remain)
{
    struct _timespec64 request64 = {
        .tv_sec = request->tv_sec,
        .tv_nsec = request->tv_nsec
    };
    struct _timespec64 remain64 = {0};

    if (__clock_nanosleep (clock_id, flags, &request64, &remain64) == -1)
        return -1;

    assert (remain64.tv_sec <= INT_MAX);

    if (remain != NULL) {
        remain->tv_sec = (__time32_t)remain64.tv_sec;
        remain->tv_nsec = remain64.tv_nsec;
    }

    return 0;
}
