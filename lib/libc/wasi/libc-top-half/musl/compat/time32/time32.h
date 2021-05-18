#ifndef TIME32_H
#define TIME32_H

#include <sys/types.h>

typedef long time32_t;

struct timeval32 {
	long tv_sec;
	long tv_usec;
};

struct itimerval32 {
	struct timeval32 it_interval;
	struct timeval32 it_value;
};

struct timespec32 {
	long tv_sec;
	long tv_nsec;
};

struct itimerspec32 {
	struct timespec32 it_interval;
	struct timespec32 it_value;
};

int __adjtime32() __asm__("adjtime");
int __adjtimex_time32() __asm__("adjtimex");
int __aio_suspend_time32() __asm__("aio_suspend");
int __clock_adjtime32() __asm__("clock_adjtime");
int __clock_getres_time32() __asm__("clock_getres");
int __clock_gettime32() __asm__("clock_gettime");
int __clock_nanosleep_time32() __asm__("clock_nanosleep");
int __clock_settime32() __asm__("clock_settime");
int __cnd_timedwait_time32() __asm__("cnd_timedwait");
char *__ctime32() __asm__("ctime");
char *__ctime32_r() __asm__("ctime_r");
double __difftime32() __asm__("difftime");
int __fstat_time32() __asm__("fstat");
int __fstatat_time32() __asm__("fstatat");
int __ftime32() __asm__("ftime");
int __futimens_time32() __asm__("futimens");
int __futimes_time32() __asm__("futimes");
int __futimesat_time32() __asm__("futimesat");
int __getitimer_time32() __asm__("getitimer");
int __getrusage_time32() __asm__("getrusage");
int __gettimeofday_time32() __asm__("gettimeofday");
struct tm *__gmtime32() __asm__("gmtime");
struct tm *__gmtime32_r() __asm__("gmtime_r");
struct tm *__localtime32() __asm__("localtime");
struct tm *__localtime32_r() __asm__("localtime_r");
int __lstat_time32() __asm__("lstat");
int __lutimes_time32() __asm__("lutimes");
time32_t __mktime32() __asm__("mktime");
ssize_t __mq_timedreceive_time32() __asm__("mq_timedreceive");
int __mq_timedsend_time32() __asm__("mq_timedsend");
int __mtx_timedlock_time32() __asm__("mtx_timedlock");
int __nanosleep_time32() __asm__("nanosleep");
int __ppoll_time32() __asm__("ppoll");
int __pselect_time32() __asm__("pselect");
int __pthread_cond_timedwait_time32() __asm__("pthread_cond_timedwait");
int __pthread_mutex_timedlock_time32() __asm__("pthread_mutex_timedlock");
int __pthread_rwlock_timedrdlock_time32() __asm__("pthread_rwlock_timedrdlock");
int __pthread_rwlock_timedwrlock_time32() __asm__("pthread_rwlock_timedwrlock");
int __pthread_timedjoin_np_time32() __asm__("pthread_timedjoin_np");
int __recvmmsg_time32() __asm__("recvmmsg");
int __sched_rr_get_interval_time32() __asm__("sched_rr_get_interval");
int __select_time32() __asm__("select");
int __sem_timedwait_time32() __asm__("sem_timedwait");
int __semtimedop_time32() __asm__("semtimedop");
int __setitimer_time32() __asm__("setitimer");
int __settimeofday_time32() __asm__("settimeofday");
int __sigtimedwait_time32() __asm__("sigtimedwait");
int __stat_time32() __asm__("stat");
int __stime32() __asm__("stime");
int __thrd_sleep_time32() __asm__("thrd_sleep");
time32_t __time32() __asm__("time");
time32_t __time32gm() __asm__("timegm");
int __timer_gettime32() __asm__("timer_gettime");
int __timer_settime32() __asm__("timer_settime");
int __timerfd_gettime32() __asm__("timerfd_gettime");
int __timerfd_settime32() __asm__("timerfd_settime");
int __timespec_get_time32() __asm__("timespec_get");
int __utime_time32() __asm__("utime");
int __utimensat_time32() __asm__("utimensat");
int __utimes_time32() __asm__("utimes");
pid_t __wait3_time32() __asm__("wait3");
pid_t __wait4_time32() __asm__("wait4");

#endif
