#define _WASI_EMULATED_PROCESS_CLOCKS
#include <sys/resource.h>
#include <errno.h>
#include <time.h>
#include <wasi/api.h>
#include <common/time.h>

// `clock` is a weak symbol so that application code can override it.
// We want to use the function in libc, so use the libc-internal name.
clock_t __clock(void);

int getrusage(int who, struct rusage *r_usage) {
    switch (who) {
    case RUSAGE_SELF: {
        __wasi_timestamp_t usertime = __clock();
        *r_usage = (struct rusage) {
            .ru_utime = timestamp_to_timeval(usertime)
	};
        return 0;
    }
    case RUSAGE_CHILDREN:
        *r_usage = (struct rusage) {};
        return 0;
    default:
        errno = EINVAL;
        return -1;
    }
}
