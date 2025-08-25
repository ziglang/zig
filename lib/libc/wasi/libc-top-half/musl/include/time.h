#ifndef	_TIME_H
#define _TIME_H

#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>

#ifdef __wasilibc_unmodified_upstream /* Use the compiler's definition of NULL */
#if __cplusplus >= 201103L
#define NULL nullptr
#elif defined(__cplusplus)
#define NULL 0L
#else
#define NULL ((void*)0)
#endif
#else
#define __need_NULL
#include <stddef.h>
#endif


#define __NEED_size_t
#define __NEED_time_t
#define __NEED_clock_t
#define __NEED_struct_timespec

#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) \
 || defined(_BSD_SOURCE)
#define __NEED_clockid_t
#define __NEED_timer_t
#define __NEED_pid_t
#define __NEED_locale_t
#endif

#include <bits/alltypes.h>

#if defined(_BSD_SOURCE) || defined(_GNU_SOURCE)
#define __tm_gmtoff tm_gmtoff
#define __tm_zone tm_zone
#endif

#ifdef __wasilibc_unmodified_upstream /* Use alternate WASI libc headers */
struct tm {
	int tm_sec;
	int tm_min;
	int tm_hour;
	int tm_mday;
	int tm_mon;
	int tm_year;
	int tm_wday;
	int tm_yday;
	int tm_isdst;
	long __tm_gmtoff;
	const char *__tm_zone;
};
#else
#include <__header_time.h>
#endif

#if defined(__wasilibc_unmodified_upstream) || defined(_WASI_EMULATED_PROCESS_CLOCKS)
clock_t clock (void);
#else
__attribute__((__deprecated__(
"WASI lacks process-associated clocks; to enable emulation of the `clock` function using "
"the wall clock, which isn't sensitive to whether the program is running or suspended, "
"compile with -D_WASI_EMULATED_PROCESS_CLOCKS and link with -lwasi-emulated-process-clocks"
)))
clock_t clock (void);
#endif
time_t time (time_t *);
double difftime (time_t, time_t);
time_t mktime (struct tm *);
size_t strftime (char *__restrict, size_t, const char *__restrict, const struct tm *__restrict);
struct tm *gmtime (const time_t *);
struct tm *localtime (const time_t *);
char *asctime (const struct tm *);
char *ctime (const time_t *);
int timespec_get(struct timespec *, int);

#ifdef __wasilibc_unmodified_upstream /* Use alternate WASI libc headers */
#define CLOCKS_PER_SEC 1000000L

#define TIME_UTC 1
#endif

#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) \
 || defined(_BSD_SOURCE)

size_t strftime_l (char *  __restrict, size_t, const char *  __restrict, const struct tm *  __restrict, locale_t);

struct tm *gmtime_r (const time_t *__restrict, struct tm *__restrict);
struct tm *localtime_r (const time_t *__restrict, struct tm *__restrict);
char *asctime_r (const struct tm *__restrict, char *__restrict);
char *ctime_r (const time_t *, char *);

#ifdef __wasilibc_unmodified_upstream /* WASI has no timezone tables */
void tzset (void);
#endif

struct itimerspec {
	struct timespec it_interval;
	struct timespec it_value;
};

#ifdef __wasilibc_unmodified_upstream /* Use alternate WASI libc headers */
#define CLOCK_REALTIME           0
#define CLOCK_MONOTONIC          1
#define CLOCK_PROCESS_CPUTIME_ID 2
#define CLOCK_THREAD_CPUTIME_ID  3
#define CLOCK_MONOTONIC_RAW      4
#define CLOCK_REALTIME_COARSE    5
#define CLOCK_MONOTONIC_COARSE   6
#define CLOCK_BOOTTIME           7
#define CLOCK_REALTIME_ALARM     8
#define CLOCK_BOOTTIME_ALARM     9
#define CLOCK_SGI_CYCLE         10
#define CLOCK_TAI               11

#define TIMER_ABSTIME 1
#endif

int nanosleep (const struct timespec *, struct timespec *);
int clock_getres (clockid_t, struct timespec *);
int clock_gettime (clockid_t, struct timespec *);
#ifdef __wasilibc_unmodified_upstream /* WASI has no clock_settime */
int clock_settime (clockid_t, const struct timespec *);
#endif
int clock_nanosleep (clockid_t, int, const struct timespec *, struct timespec *);
#ifdef __wasilibc_unmodified_upstream /* WASI has no clock_getcpuclockid */
int clock_getcpuclockid (pid_t, clockid_t *);
#endif

#ifdef __wasilibc_unmodified_upstream /* WASI has no timers */
struct sigevent;
int timer_create (clockid_t, struct sigevent *__restrict, timer_t *__restrict);
int timer_delete (timer_t);
int timer_settime (timer_t, int, const struct itimerspec *__restrict, struct itimerspec *__restrict);
int timer_gettime (timer_t, struct itimerspec *);
int timer_getoverrun (timer_t);
#endif

#ifdef __wasilibc_unmodified_upstream /* WASI has no timezone tables */
extern char *tzname[2];
#endif

#endif


#if defined(_XOPEN_SOURCE) || defined(_BSD_SOURCE) || defined(_GNU_SOURCE)
char *strptime (const char *__restrict, const char *__restrict, struct tm *__restrict);
#ifdef __wasilibc_unmodified_upstream /* WASI has no timezone tables */
extern int daylight;
extern long timezone;
#endif
extern int getdate_err;
struct tm *getdate (const char *);
#endif


#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#ifdef __wasilibc_unmodified_upstream /* WASI has no stime */
int stime(const time_t *);
#endif
time_t timegm(struct tm *);
#endif

#if _REDIR_TIME64
__REDIR(time, __time64);
__REDIR(difftime, __difftime64);
__REDIR(mktime, __mktime64);
__REDIR(gmtime, __gmtime64);
__REDIR(localtime, __localtime64);
__REDIR(ctime, __ctime64);
__REDIR(timespec_get, __timespec_get_time64);
#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) \
 || defined(_BSD_SOURCE)
__REDIR(gmtime_r, __gmtime64_r);
__REDIR(localtime_r, __localtime64_r);
__REDIR(ctime_r, __ctime64_r);
__REDIR(nanosleep, __nanosleep_time64);
__REDIR(clock_getres, __clock_getres_time64);
__REDIR(clock_gettime, __clock_gettime64);
__REDIR(clock_settime, __clock_settime64);
__REDIR(clock_nanosleep, __clock_nanosleep_time64);
__REDIR(timer_settime, __timer_settime64);
__REDIR(timer_gettime, __timer_gettime64);
#endif
#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
__REDIR(stime, __stime64);
__REDIR(timegm, __timegm_time64);
#endif
#endif

#ifdef __cplusplus
}
#endif


#endif
