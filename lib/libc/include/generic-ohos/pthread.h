#ifndef _PTHREAD_H
#define _PTHREAD_H
#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>

/* Musl did not provide the "owner" macro directly,
 * so users can not access the mutex-ower-ID.
 * Thus we added this macro for getting the owner-ID
 * of the mutex. */

/* These macros provides macros for accessing inner
 * attributes of the pthread_mutex_t struct.
 * It is intended for solving the coompiling failure
 * of Dopra codes which claims that .__data.* realm
 * can not be found in pthread_mutex_t. */

#define __NEED_time_t
#define __NEED_clockid_t
#define __NEED_struct_timespec
#define __NEED_sigset_t
#define __NEED_pthread_t
#define __NEED_pthread_attr_t
#define __NEED_pthread_mutexattr_t
#define __NEED_pthread_condattr_t
#define __NEED_pthread_rwlockattr_t
#define __NEED_pthread_barrierattr_t
#define __NEED_pthread_mutex_t
#define __NEED_pthread_cond_t
#define __NEED_pthread_rwlock_t
#define __NEED_pthread_barrier_t
#define __NEED_pthread_spinlock_t
#define __NEED_pthread_key_t
#define __NEED_pthread_once_t
#define __NEED_size_t

#include <bits/alltypes.h>

#include <sched.h>
#include <time.h>

#define PTHREAD_CREATE_JOINABLE 0
#define PTHREAD_CREATE_DETACHED 1

#define PTHREAD_MUTEX_NORMAL 0
#define PTHREAD_MUTEX_DEFAULT 0
#define PTHREAD_MUTEX_RECURSIVE 1
#define PTHREAD_MUTEX_ERRORCHECK 2

#define PTHREAD_MUTEX_STALLED 0
#define PTHREAD_MUTEX_ROBUST 1

#define PTHREAD_PRIO_NONE 0
#define PTHREAD_PRIO_INHERIT 1
#define PTHREAD_PRIO_PROTECT 2

#define PTHREAD_INHERIT_SCHED 0
#define PTHREAD_EXPLICIT_SCHED 1

#define PTHREAD_SCOPE_SYSTEM 0
#define PTHREAD_SCOPE_PROCESS 1

#define PTHREAD_PROCESS_PRIVATE 0
#define PTHREAD_PROCESS_SHARED 1


#define PTHREAD_MUTEX_INITIALIZER {{{0}}}
#define PTHREAD_RWLOCK_INITIALIZER {{{0}}}
#define PTHREAD_COND_INITIALIZER {{{0}}}
#define PTHREAD_ONCE_INIT 0


#define PTHREAD_CANCEL_ENABLE 0
#define PTHREAD_CANCEL_DISABLE 1
#define PTHREAD_CANCEL_MASKED 2

#define PTHREAD_CANCEL_DEFERRED 0
#define PTHREAD_CANCEL_ASYNCHRONOUS 1

#define PTHREAD_CANCELED ((void *)-1)


#define PTHREAD_BARRIER_SERIAL_THREAD (-1)


int pthread_create(pthread_t *__restrict, const pthread_attr_t *__restrict, void *(*)(void *), void *__restrict);
int pthread_detach(pthread_t);
_Noreturn void pthread_exit(void *);
int pthread_join(pthread_t, void **);
pid_t pthread_gettid_np(pthread_t);

#ifdef __GNUC__
__attribute__((const))
#endif
pthread_t pthread_self(void);

int pthread_equal(pthread_t, pthread_t);
#ifndef __cplusplus
#define pthread_equal(x,y) ((x)==(y))
#endif

int pthread_getschedparam(pthread_t, int *__restrict, struct sched_param *__restrict);
int pthread_setschedparam(pthread_t, int, const struct sched_param *);
int pthread_setschedprio(pthread_t, int);

int pthread_once(pthread_once_t *, void (*)(void));

int pthread_mutex_init(pthread_mutex_t *__restrict, const pthread_mutexattr_t *__restrict);
int pthread_mutex_lock(pthread_mutex_t *);
int pthread_mutex_unlock(pthread_mutex_t *);
int pthread_mutex_trylock(pthread_mutex_t *);
int pthread_mutex_timedlock(pthread_mutex_t *__restrict, const struct timespec *__restrict);
int pthread_mutex_destroy(pthread_mutex_t *);
/**
  * @brief lock the mutex object referenced by mutex. If the mutex is already locked,
  *        the calling thread shall block until the mutex becomes available as in the
  *        pthread_mutex_lock() function. If the mutex cannot be locked without waiting for
  *        another thread to unlock the mutex, this wait shall be terminated when the specified
  *        timeout expires. The timeout shall be based on the CLOCK_REALTIME or CLOCK_MONOTONIC clock.
  *        The resolution of the timeout shall be the resolution of the clock on which it is based.
  * @param mutex a robust mutex and the process containing the owning thread terminated while holding the mutex lock.
  * @param clock_id specified CLOCK_REALTIME or CLOCK_MONOTONIC clock.
  * @param timespec the timeout shall expire specified by abstime passes.
  * @return clocklock result.
  * @retval 0 is returned on success.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int pthread_mutex_clocklock(pthread_mutex_t *__restrict, clockid_t, const struct timespec *__restrict);
/**
  * @brief lock the mutex object referenced by mutex. If the mutex is already locked,
  *        the calling thread shall block until the mutex becomes available as in the
  *        pthread_mutex_lock() function. If the mutex cannot be locked without waiting for
  *        another thread to unlock the mutex, this wait shall be terminated when the specified
  *        timeout expires. The timeout shall be based on the CLOCK_MONOTONIC clock.
  *        The resolution of the timeout shall be the resolution of the clock on which it is based.
  * @param mutex a robust mutex and the process containing the owning thread terminated while holding the mutex lock.
  * @param timespec the timeout shall expire specified by abstime passes.
  * @return clocklock result.
  * @retval 0 is returned on success.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int pthread_mutex_timedlock_monotonic_np(pthread_mutex_t *__restrict, const struct timespec *__restrict);
/**
  * @brief lock the mutex object referenced by mutex. If the mutex is already locked,
  *        the calling thread shall block until the mutex becomes available as in the
  *        pthread_mutex_lock() function. If the mutex cannot be locked without waiting for
  *        another thread to unlock the mutex, this wait shall be terminated when the specified
  *        timeout expires. The timeout shall be based on the CLOCK_MONOTONIC clock.
  *        The resolution of the timeout shall be the resolution of the clock on which it is based.
  * @param mutex a robust mutex and the process containing the owning thread terminated while holding the mutex lock.
  * @param ms the timeout shall expire specified by relative time(ms) passes.
  * @return clocklock result.
  * @retval 0 is returned on success.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int pthread_mutex_lock_timeout_np(pthread_mutex_t *__restrict, unsigned int);

int pthread_cond_init(pthread_cond_t *__restrict, const pthread_condattr_t *__restrict);
int pthread_cond_destroy(pthread_cond_t *);
int pthread_cond_wait(pthread_cond_t *__restrict, pthread_mutex_t *__restrict);
int pthread_cond_timedwait(pthread_cond_t *__restrict, pthread_mutex_t *__restrict, const struct timespec *__restrict);
/**
  * @brief The thread waits for a signal to trigger, and if timeout or signal is triggered,
  *        the thread wakes up.
  * @param pthread_cond_t Condition variables for multithreading.
  * @param pthread_mutex_t Thread mutex variable.
  * @param clockid_t Clock ID used in clock and timer functions.
  * @param timespec The timeout shall expire specified by abstime passes.
  * @return pthread_cond_clockwait result.
  * @retval 0 pthread_cond_clockwait successful.
  * @retval ETIMEDOUT pthread_cond_clockwait Connection timed out.
  * @retval EINVAL pthread_cond_clockwait error.
  */
int pthread_cond_clockwait(pthread_cond_t *__restrict, pthread_mutex_t *__restrict,
                           clockid_t, const struct timespec *__restrict);

/**
  * @brief Condition variables have an initialization option to use CLOCK_MONOTONIC.
  *        The thread waits for a signal to trigger, and if timeout or signal is triggered,
  *        the thread wakes up.
  * @param pthread_cond_t Condition variables for multithreading.
  * @param pthread_mutex_t Thread mutex variable.
  * @param timespec The timeout shall expire specified by abstime passes.
  * @return pthread_cond_timedwait_monotonic_np result.
  * @retval 0 pthread_cond_timedwait_monotonic_np successful.
  * @retval ETIMEDOUT pthread_cond_timedwait_monotonic_np Connection timed out.
  * @retval EINVAL pthread_cond_timedwait_monotonic_np error.
  */
int pthread_cond_timedwait_monotonic_np(pthread_cond_t *__restrict, pthread_mutex_t *__restrict,
                                        const struct timespec *__restrict);

/**
  * @brief Condition variables have an initialization option to use CLOCK_MONOTONIC and The time
  *        parameter is in milliseconds. The thread waits for a signal to trigger, and if timeout or
  *        signal is triggered, the thread wakes up.
  * @param pthread_cond_t Condition variables for multithreading.
  * @param pthread_mutex_t Thread mutex variable.
  * @param unsigned Timeout, in milliseconds.
  * @return pthread_cond_timeout_np result.
  * @retval 0 pthread_cond_timeout_np successful.
  * @retval ETIMEDOUT pthread_cond_timeout_np Connection timed out.
  * @retval EINVAL pthread_cond_timeout_np error.
  */
int pthread_cond_timeout_np(pthread_cond_t* __restrict, pthread_mutex_t* __restrict, unsigned int);
int pthread_cond_broadcast(pthread_cond_t *);
int pthread_cond_signal(pthread_cond_t *);

int pthread_rwlock_init(pthread_rwlock_t *__restrict, const pthread_rwlockattr_t *__restrict);
int pthread_rwlock_destroy(pthread_rwlock_t *);
int pthread_rwlock_rdlock(pthread_rwlock_t *);
int pthread_rwlock_tryrdlock(pthread_rwlock_t *);
int pthread_rwlock_timedrdlock(pthread_rwlock_t *__restrict, const struct timespec *__restrict);
/**
  * @brief Apply a read lock to the read-write lock referenced by rwlock as in the
  *        pthread_rwlock_rdlock() function. However, if the lock cannot be acquired without
  *        waiting for other threads to unlock the lock, this wait shall be terminated when
  *        the specified timeout expires. The timeout shall expire when the absolute time specified by
  *        abstime passes, as measured by the clock on which timeouts are based, or if the absolute time
  *        specified by abstime has already been passed at the time of the call.
  *        The timeout shall be based on the CLOCK_REALTIME or CLOCK_MONOTONIC clock.
  * @param rw a read lock to the read-write lock referenced.
  * @param clock_id specified CLOCK_REALTIME or CLOCK_MONOTONIC clock.
  * @param timespec the timeout shall expire specified by abstime passes.
  * @return clockrdlock result.
  * @retval 0 is returned on success.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int pthread_rwlock_clockrdlock(pthread_rwlock_t *__restrict, clockid_t, const struct timespec *__restrict);
/**
  * @brief Apply a read lock to the read-write lock referenced by rwlock as in the
  *        pthread_rwlock_rdlock() function. However, if the lock cannot be acquired without
  *        waiting for other threads to unlock the lock, this wait shall be terminated when
  *        the specified timeout expires. The timeout shall expire when the absolute time specified by
  *        abstime passes, as measured by the clock on which timeouts are based, or if the absolute time
  *        specified by abstime has already been passed at the time of the call.
  *        The timeout shall be based on the CLOCK_MONOTONIC clock.
  * @param rw a read lock to the read-write lock referenced.
  * @param timespec the timeout shall expire specified by abstime passes.
  * @return clockrdlock result.
  * @retval 0 is returned on success.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int pthread_rwlock_timedrdlock_monotonic_np(pthread_rwlock_t *__restrict, const struct timespec *__restrict);
int pthread_rwlock_wrlock(pthread_rwlock_t *);
int pthread_rwlock_trywrlock(pthread_rwlock_t *);
int pthread_rwlock_timedwrlock(pthread_rwlock_t *__restrict, const struct timespec *__restrict);
int pthread_rwlock_unlock(pthread_rwlock_t *);
/**
  * @brief Read-write lock variables have an initialization option to use CLOCK_MONOTONIC.
  *        apply a read lock to the read-write lock referenced by rwlock as in the
  *        pthread_rwlock_wrlock() function. However, if the lock cannot be acquired without
  *        waiting for other threads to unlock the lock, this wait shall be terminated when
  *        the specified timeout expires. The timeout shall expire when the absolute time specified by
  *        abstime passes, as measured by the clock on which timeouts are based, or if the absolute time
  *        specified by abstime has already been passed at the time of the call.
  *        The timeout shall be based on the CLOCK_MONOTONIC clock.
  * @param rw a read lock to the read-write lock referenced.
  * @param timespec the timeout shall expire specified by abstime passes.
  * @return clockrdlock result.
  * @retval 0 is returned on success.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int pthread_rwlock_timedwrlock_monotonic_np(pthread_rwlock_t *__restrict, const struct timespec *__restrict);

/**
  * @brief Apply a read lock to the read-write lock referenced by rwlock as in the
  *        pthread_rwlock_wrlock() function. However, if the lock cannot be acquired without
  *        waiting for other threads to unlock the lock, this wait shall be terminated when
  *        the specified timeout expires. The timeout shall expire when the absolute time specified by
  *        abstime passes, as measured by the clock on which timeouts are based, or if the absolute time
  *        specified by abstime has already been passed at the time of the call.
  *        The timeout shall be based on the CLOCK_REALTIME or CLOCK_MONOTONIC clock.
  * @param rw a read lock to the read-write lock referenced.
  * @param clock_id specified CLOCK_REALTIME or CLOCK_MONOTONIC clock.
  * @param timespec the timeout shall expire specified by abstime passes.
  * @return clockrdlock result.
  * @retval 0 is returned on success.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int pthread_rwlock_clockwrlock(pthread_rwlock_t *__restrict, clockid_t, const struct timespec *__restrict);

int pthread_spin_init(pthread_spinlock_t *, int);
int pthread_spin_destroy(pthread_spinlock_t *);
int pthread_spin_lock(pthread_spinlock_t *);
int pthread_spin_trylock(pthread_spinlock_t *);
int pthread_spin_unlock(pthread_spinlock_t *);

int pthread_barrier_init(pthread_barrier_t *__restrict, const pthread_barrierattr_t *__restrict, unsigned);
int pthread_barrier_destroy(pthread_barrier_t *);
int pthread_barrier_wait(pthread_barrier_t *);

int pthread_key_create(pthread_key_t *, void (*)(void *));
int pthread_key_delete(pthread_key_t);
void *pthread_getspecific(pthread_key_t);
int pthread_setspecific(pthread_key_t, const void *);

int pthread_attr_init(pthread_attr_t *);
int pthread_attr_destroy(pthread_attr_t *);

int pthread_attr_getguardsize(const pthread_attr_t *__restrict, size_t *__restrict);
int pthread_attr_setguardsize(pthread_attr_t *, size_t);
int pthread_attr_getstacksize(const pthread_attr_t *__restrict, size_t *__restrict);
int pthread_attr_setstacksize(pthread_attr_t *, size_t);
int pthread_attr_getdetachstate(const pthread_attr_t *, int *);
int pthread_attr_setdetachstate(pthread_attr_t *, int);
int pthread_attr_getstack(const pthread_attr_t *__restrict, void **__restrict, size_t *__restrict);
int pthread_attr_setstack(pthread_attr_t *, void *, size_t);
int pthread_attr_getscope(const pthread_attr_t *__restrict, int *__restrict);
int pthread_attr_setscope(pthread_attr_t *, int);
int pthread_attr_getschedpolicy(const pthread_attr_t *__restrict, int *__restrict);
int pthread_attr_setschedpolicy(pthread_attr_t *, int);
int pthread_attr_getschedparam(const pthread_attr_t *__restrict, struct sched_param *__restrict);
int pthread_attr_setschedparam(pthread_attr_t *__restrict, const struct sched_param *__restrict);
int pthread_attr_getinheritsched(const pthread_attr_t *__restrict, int *__restrict);
int pthread_attr_setinheritsched(pthread_attr_t *, int);

int pthread_mutexattr_destroy(pthread_mutexattr_t *);
int pthread_mutexattr_getprotocol(const pthread_mutexattr_t *__restrict, int *__restrict);
int pthread_mutexattr_getpshared(const pthread_mutexattr_t *__restrict, int *__restrict);
int pthread_mutexattr_gettype(const pthread_mutexattr_t *__restrict, int *__restrict);
int pthread_mutexattr_init(pthread_mutexattr_t *);
int pthread_mutexattr_setprotocol(pthread_mutexattr_t *, int);
int pthread_mutexattr_setpshared(pthread_mutexattr_t *, int);
int pthread_mutexattr_settype(pthread_mutexattr_t *, int);

int pthread_condattr_init(pthread_condattr_t *);
int pthread_condattr_destroy(pthread_condattr_t *);
int pthread_condattr_setclock(pthread_condattr_t *, clockid_t);
int pthread_condattr_setpshared(pthread_condattr_t *, int);
int pthread_condattr_getclock(const pthread_condattr_t *__restrict, clockid_t *__restrict);
int pthread_condattr_getpshared(const pthread_condattr_t *__restrict, int *__restrict);

int pthread_rwlockattr_init(pthread_rwlockattr_t *);
int pthread_rwlockattr_destroy(pthread_rwlockattr_t *);
int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *, int);
int pthread_rwlockattr_getpshared(const pthread_rwlockattr_t *__restrict, int *__restrict);

int pthread_barrierattr_destroy(pthread_barrierattr_t *);
int pthread_barrierattr_getpshared(const pthread_barrierattr_t *__restrict, int *__restrict);
int pthread_barrierattr_init(pthread_barrierattr_t *);
int pthread_barrierattr_setpshared(pthread_barrierattr_t *, int);

int pthread_atfork(void (*)(void), void (*)(void), void (*)(void));

int pthread_getcpuclockid(pthread_t, clockid_t *);

struct __ptcb {
	void (*__f)(void *);
	void *__x;
	struct __ptcb *__next;
};

void _pthread_cleanup_push(struct __ptcb *, void (*)(void *), void *);
void _pthread_cleanup_pop(struct __ptcb *, int);

#define pthread_cleanup_push(f, x) do { struct __ptcb __cb; _pthread_cleanup_push(&__cb, f, x);
#define pthread_cleanup_pop(r) _pthread_cleanup_pop(&__cb, (r)); } while(0)

#ifdef _GNU_SOURCE
struct cpu_set_t;
int pthread_getattr_np(pthread_t, pthread_attr_t *);
int pthread_setname_np(pthread_t, const char *);
int pthread_getname_np(pthread_t, char *, size_t);
#endif

#if _REDIR_TIME64
__REDIR(pthread_mutex_timedlock, __pthread_mutex_timedlock_time64);
__REDIR(pthread_cond_timedwait, __pthread_cond_timedwait_time64);
__REDIR(pthread_rwlock_timedrdlock, __pthread_rwlock_timedrdlock_time64);
__REDIR(pthread_rwlock_timedwrlock, __pthread_rwlock_timedwrlock_time64);
#endif

#ifdef __cplusplus
}
#endif
#endif
