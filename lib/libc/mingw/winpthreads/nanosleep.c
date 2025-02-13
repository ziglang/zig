/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the w64 mingw-runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <errno.h>
#include <time.h>
#include <windows.h>
#include "pthread.h"
#include "pthread_time.h"
#include "winpthread_internal.h"

#define POW10_3                 1000
#define POW10_4                 10000
#define POW10_6                 1000000
#define POW10_9                 1000000000
#define MAX_SLEEP_IN_MS         4294967294UL

/**
 * Sleep for the specified time.
 * @param  request The desired amount of time to sleep.
 * @param  remain The remain amount of time to sleep.
 * @return If the function succeeds, the return value is 0.
 *         If the function fails, the return value is -1,
 *         with errno set to indicate the error.
 */
int nanosleep(const struct timespec *request, struct timespec *remain)
{
    unsigned long ms, rc = 0;
    unsigned __int64 u64, want, real;

    union {
        unsigned __int64 ns100;
        FILETIME ft;
    }  _start, _end;

    if (request->tv_sec < 0 || request->tv_nsec < 0 || request->tv_nsec >= POW10_9) {
        errno = EINVAL;
        return -1;
    }

    if (remain != NULL) GetSystemTimeAsFileTime(&_start.ft);

    want = u64 = request->tv_sec * POW10_3 + request->tv_nsec / POW10_6;
    while (u64 > 0 && rc == 0) {
        if (u64 >= MAX_SLEEP_IN_MS) ms = MAX_SLEEP_IN_MS;
        else ms = (unsigned long) u64;

        u64 -= ms;
        rc = pthread_delay_np_ms(ms);
    }

    if (rc != 0) { /* WAIT_IO_COMPLETION (192) */
        if (remain != NULL) {
            GetSystemTimeAsFileTime(&_end.ft);
            real = (_end.ns100 - _start.ns100) / POW10_4;

            if (real >= want) u64 = 0;
            else u64 = want - real;

            remain->tv_sec = u64 / POW10_3;
            remain->tv_nsec = (long) (u64 % POW10_3) * POW10_6;
        }

        errno = EINTR;
        return -1;
    }

    return 0;
}
