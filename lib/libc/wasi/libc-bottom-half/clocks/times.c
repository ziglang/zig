#define _WASI_EMULATED_PROCESS_CLOCKS
#include <time.h>
#include <sys/times.h>
#include <wasi/api.h>
#include <common/time.h>

_Static_assert(
    CLOCKS_PER_SEC == NSEC_PER_SEC,
    "This implementation assumes that `clock` is in nanoseconds"
);

// `clock` is a weak symbol so that application code can override it.
// We want to use the function in libc, so use the libc-internal name.
clock_t __clock(void);

clock_t times(struct tms *buffer) {
    __wasi_timestamp_t user = __clock();
    *buffer = (struct tms){
        .tms_utime = user,
        .tms_cutime = user
    };

    __wasi_timestamp_t realtime = 0;
    (void)__wasi_clock_time_get(__WASI_CLOCKID_MONOTONIC, 0, &realtime);
    return realtime;
}
