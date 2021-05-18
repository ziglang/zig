#ifndef _WASI_EMULATED_PROCESS_CLOCKS
#error WASI lacks process-associated clocks; to enable emulation of the `times` function using \
the wall clock, which isn't sensitive to whether the program is running or suspended, \
compile with -D_WASI_EMULATED_PROCESS_CLOCKS and link with -lwasi-emulated-process-clocks
#else
#ifndef	_SYS_TIMES_H
#define	_SYS_TIMES_H

#ifdef __cplusplus
extern "C" {
#endif

#define __NEED_clock_t
#include <bits/alltypes.h>

#ifdef __wasilibc_unmodified_upstream /* Use alternate WASI libc headers */
struct tms {
	clock_t tms_utime;
	clock_t tms_stime;
	clock_t tms_cutime;
	clock_t tms_cstime;
};
#else
#include <__struct_tms.h>
#endif

clock_t times (struct tms *);

#ifdef __cplusplus
}
#endif

#endif
#endif
