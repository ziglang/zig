/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the w64 mingw-runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <errno.h>
#include <stdint.h>
#include <time.h>
#include <windows.h>
#ifndef IN_WINPTHREAD
#define IN_WINPTHREAD 1
#endif
#include "pthread.h"
#include "pthread_time.h"
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
int clock_getres(clockid_t clock_id, struct timespec *res)
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
int clock_gettime(clockid_t clock_id, struct timespec *tp)
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
int clock_nanosleep(clockid_t clock_id, int flags,
                           const struct timespec *request,
                           struct timespec *remain)
{
    struct timespec tp;

    if (clock_id != CLOCK_REALTIME)
        return lc_set_errno(EINVAL);

    if (flags == 0)
        return nanosleep(request, remain);

    /* TIMER_ABSTIME = 1 */
    clock_gettime(CLOCK_REALTIME, &tp);

    tp.tv_sec = request->tv_sec - tp.tv_sec;
    tp.tv_nsec = request->tv_nsec - tp.tv_nsec;
    if (tp.tv_nsec < 0) {
        tp.tv_nsec += POW10_9;
        tp.tv_sec --;
    }

    return nanosleep(&tp, remain);
}

/**
 * Set the time of the specified clock clock_id.
 * @param  clock_id This argument should always be CLOCK_REALTIME (0).
 * @param  tp The requested time.
 * @return If the function succeeds, the return value is 0.
 *         If the function fails, the return value is -1,
 *         with errno set to indicate the error.
 */
int clock_settime(clockid_t clock_id, const struct timespec *tp)
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
