
/* Posix threads interface (from CPython) */

#include <unistd.h>   /* for the _POSIX_xxx and _POSIX_THREAD_xxx defines */
#include <stdlib.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <errno.h>
#include <assert.h>
#include <sys/time.h>

/* The following is hopefully equivalent to what CPython does
   (which is trying to compile a snippet of code using it) */
#ifdef PTHREAD_SCOPE_SYSTEM
#  ifndef PTHREAD_SYSTEM_SCHED_SUPPORTED
#    define PTHREAD_SYSTEM_SCHED_SUPPORTED
#  endif
#endif

#if !defined(pthread_attr_default)
#  define pthread_attr_default ((pthread_attr_t *)NULL)
#endif
#if !defined(pthread_mutexattr_default)
#  define pthread_mutexattr_default ((pthread_mutexattr_t *)NULL)
#endif
#if !defined(pthread_condattr_default)
#  define pthread_condattr_default ((pthread_condattr_t *)NULL)
#endif

#define CHECK_STATUS(name)  if (status != 0) { perror(name); error = 1; }

/* The POSIX spec requires that use of pthread_attr_setstacksize
   be conditional on _POSIX_THREAD_ATTR_STACKSIZE being defined. */
#ifdef _POSIX_THREAD_ATTR_STACKSIZE
# ifndef THREAD_STACK_SIZE
#  define THREAD_STACK_SIZE   0   /* use default stack size */
# endif

# if (defined(__APPLE__) || defined(__FreeBSD__) || defined(__FreeBSD_kernel__)) && defined(THREAD_STACK_SIZE) && THREAD_STACK_SIZE == 0
   /* The default stack size for new threads on OSX is small enough that
    * we'll get hard crashes instead of 'maximum recursion depth exceeded'
    * exceptions.
    *
    * The default stack size below is the minimal stack size where a
    * simple recursive function doesn't cause a hard crash.
    */
#  undef  THREAD_STACK_SIZE
#  define THREAD_STACK_SIZE       0x400000
# endif
/* for safety, ensure a viable minimum stacksize */
# define THREAD_STACK_MIN    0x8000  /* 32kB */
#else  /* !_POSIX_THREAD_ATTR_STACKSIZE */
# ifdef THREAD_STACK_SIZE
#  error "THREAD_STACK_SIZE defined but _POSIX_THREAD_ATTR_STACKSIZE undefined"
# endif
#endif

static long _pypythread_stacksize = 0;

Signed RPyThreadStart(void (*func)(void))
{
    /* a kind-of-invalid cast, but the 'func' passed here doesn't expect
       any argument, so it's unlikely to cause problems */
    return RPyThreadStartEx((void(*)(void *))func, NULL);
}

Signed RPyThreadStartEx(void (*func)(void *), void *arg)
{
	pthread_t th;
	int status;
#if defined(THREAD_STACK_SIZE) || defined(PTHREAD_SYSTEM_SCHED_SUPPORTED)
	pthread_attr_t attrs;
#endif
#if defined(THREAD_STACK_SIZE)
	size_t tss;
#endif

#if defined(THREAD_STACK_SIZE) || defined(PTHREAD_SYSTEM_SCHED_SUPPORTED)
	pthread_attr_init(&attrs);
#endif
#ifdef THREAD_STACK_SIZE
	tss = (_pypythread_stacksize != 0) ? _pypythread_stacksize
		: THREAD_STACK_SIZE;
	if (tss != 0)
		pthread_attr_setstacksize(&attrs, tss);
#endif
#if defined(PTHREAD_SYSTEM_SCHED_SUPPORTED) && !(defined(__FreeBSD__) || defined(__FreeBSD_kernel__))
        pthread_attr_setscope(&attrs, PTHREAD_SCOPE_SYSTEM);
#endif

	status = pthread_create(&th, 
#if defined(THREAD_STACK_SIZE) || defined(PTHREAD_SYSTEM_SCHED_SUPPORTED)
				 &attrs,
#else
				 (pthread_attr_t*)NULL,
#endif
    /* the next line does an invalid cast: pthread_create() will see a
       function that returns random garbage.  The code is the same as
       CPython: this random garbage will be stored for pthread_join() 
       to return, but in this case pthread_join() is never called. */
				 (void* (*)(void *))func,
				 (void *)arg
				 );

#if defined(THREAD_STACK_SIZE) || defined(PTHREAD_SYSTEM_SCHED_SUPPORTED)
	pthread_attr_destroy(&attrs);
#endif
	if (status != 0)
            return -1;

        pthread_detach(th);

#ifdef __CYGWIN__
	/* typedef __uint32_t pthread_t; */
	return (Signed) th;
#else
	if (sizeof(pthread_t) <= sizeof(Signed))
		return (Signed) th;
	else
		return (Signed) *(Signed *) &th;
#endif
}

Signed RPyThreadGetStackSize(void)
{
	return _pypythread_stacksize;
}

Signed RPyThreadSetStackSize(Signed newsize)
{
#if defined(THREAD_STACK_SIZE)
	pthread_attr_t attrs;
	size_t tss_min;
	int rc;
#endif

	if (newsize == 0) {    /* set to default */
		_pypythread_stacksize = 0;
		return 0;
	}

#if defined(THREAD_STACK_SIZE)
# if defined(PTHREAD_STACK_MIN)
	tss_min = PTHREAD_STACK_MIN > THREAD_STACK_MIN ? PTHREAD_STACK_MIN
		: THREAD_STACK_MIN;
# else
	tss_min = THREAD_STACK_MIN;
# endif
	if (newsize >= tss_min) {
		/* validate stack size by setting thread attribute */
		if (pthread_attr_init(&attrs) == 0) {
			rc = pthread_attr_setstacksize(&attrs, newsize);
			pthread_attr_destroy(&attrs);
			if (rc == 0) {
				_pypythread_stacksize = newsize;
				return 0;
			}
		}
	}
	return -1;
#else
	return -2;
#endif
}

#ifdef GETTIMEOFDAY_NO_TZ
#define RPY_GETTIMEOFDAY(ptv) gettimeofday(ptv)
#else
#define RPY_GETTIMEOFDAY(ptv) gettimeofday(ptv, (struct timezone *)NULL)
#endif

#define RPY_MICROSECONDS_TO_TIMESPEC(microseconds, ts) \
do { \
    struct timeval tv; \
    RPY_GETTIMEOFDAY(&tv); \
    tv.tv_usec += microseconds % 1000000; \
    tv.tv_sec += microseconds / 1000000; \
    tv.tv_sec += tv.tv_usec / 1000000; \
    tv.tv_usec %= 1000000; \
    ts.tv_sec = tv.tv_sec; \
    ts.tv_nsec = tv.tv_usec * 1000; \
} while(0)

int RPyThreadAcquireLock(struct RPyOpaque_ThreadLock *lock, int waitflag)
{
    return RPyThreadAcquireLockTimed(lock, waitflag ? -1 : 0, /*intr_flag=*/0);
}

/************************************************************/
#ifdef USE_SEMAPHORES
/************************************************************/

#include <semaphore.h>

void RPyThreadAfterFork(void)
{
}

int RPyThreadLockInit(struct RPyOpaque_ThreadLock *lock)
{
	int status, error = 0;
	lock->initialized = 0;
	status = sem_init(&lock->sem, 0, 1);
	CHECK_STATUS("sem_init");
	if (error)
		return 0;
	lock->initialized = 1;
	return 1;
}

void RPyOpaqueDealloc_ThreadLock(struct RPyOpaque_ThreadLock *lock)
{
	int status, error = 0;
	if (lock->initialized) {
		status = sem_destroy(&lock->sem);
		CHECK_STATUS("sem_destroy");
		/* 'error' is ignored;
		   CHECK_STATUS already printed an error message */
	}
}

/*
 * As of February 2002, Cygwin thread implementations mistakenly report error
 * codes in the return value of the sem_ calls (like the pthread_ functions).
 * Correct implementations return -1 and put the code in errno. This supports
 * either.
 */
static int
rpythread_fix_status(int status)
{
	return (status == -1) ? errno : status;
}

RPyLockStatus
RPyThreadAcquireLockTimed(struct RPyOpaque_ThreadLock *lock,
			  RPY_TIMEOUT_T microseconds, int intr_flag)
{
	RPyLockStatus success;
	sem_t *thelock = &lock->sem;
	int status, error = 0;
	struct timespec ts;

	if (microseconds > 0)
		RPY_MICROSECONDS_TO_TIMESPEC(microseconds, ts);
	do {
	    if (microseconds > 0)
		status = rpythread_fix_status(sem_timedwait(thelock, &ts));
	    else if (microseconds == 0)
		status = rpythread_fix_status(sem_trywait(thelock));
	    else
		status = rpythread_fix_status(sem_wait(thelock));
	    /* Retry if interrupted by a signal, unless the caller wants to be
	       notified.  */
	} while (!intr_flag && status == EINTR);

	/* Don't check the status if we're stopping because of an interrupt.  */
	if (!(intr_flag && status == EINTR)) {
	    if (microseconds > 0) {
		if (status != ETIMEDOUT)
		    CHECK_STATUS("sem_timedwait");
	    }
	    else if (microseconds == 0) {
		if (status != EAGAIN)
		    CHECK_STATUS("sem_trywait");
	    }
	    else {
		CHECK_STATUS("sem_wait");
	    }
	}

	if (status == 0) {
	    success = RPY_LOCK_ACQUIRED;
	} else if (intr_flag && status == EINTR) {
	    success = RPY_LOCK_INTR;
	} else {
	    success = RPY_LOCK_FAILURE;
	}
	return success;
}

Signed RPyThreadReleaseLock(struct RPyOpaque_ThreadLock *lock)
{
    sem_t *thelock = &lock->sem;
    int status, error = 0;
    int current_value;

    /* If the current value is > 0, then the lock is not acquired so far.
       Oops. */
    sem_getvalue(thelock, &current_value);
    if (current_value > 0) {
        return -1;
    }

    status = sem_post(thelock);
    CHECK_STATUS("sem_post");

    return 0;
}

/************************************************************/
#else                                      /* no semaphores */
/************************************************************/

struct RPyOpaque_ThreadLock *alllocks;   /* doubly-linked list */

void RPyThreadAfterFork(void)
{
	/* Mess.  We have no clue about how it works on CPython on OSX,
	   but the issue is that the state of mutexes is not really
	   preserved across a fork().  So we need to walk over all lock
	   objects here, and rebuild their mutex and condition variable.

	   See e.g. http://hackage.haskell.org/trac/ghc/ticket/1391 for
	   a similar bug about GHC.
	*/
	struct RPyOpaque_ThreadLock *p = alllocks;
	alllocks = NULL;
	while (p) {
		struct RPyOpaque_ThreadLock *next = p->next;
		int was_locked = p->locked;
		RPyThreadLockInit(p);
		p->locked = was_locked;
		p = next;
	}
    /* Also reinitialize the 'mutex_gil' mutexes, and resets the
       number of other waiting threads to zero. */
    RPyGilAllocate();
}

int RPyThreadLockInit(struct RPyOpaque_ThreadLock *lock)
{
	int status, error = 0;

	lock->initialized = 0;
	lock->locked = 0;

	status = pthread_mutex_init(&lock->mut,
				    pthread_mutexattr_default);
	CHECK_STATUS("pthread_mutex_init");

	status = pthread_cond_init(&lock->lock_released,
				   pthread_condattr_default);
	CHECK_STATUS("pthread_cond_init");

	if (error)
		return 0;
	lock->initialized = 1;
	/* add 'lock' in the doubly-linked list */
	if (alllocks)
		alllocks->prev = lock;
	lock->next = alllocks;
	lock->prev = NULL;
	alllocks = lock;
	return 1;
}

void RPyOpaqueDealloc_ThreadLock(struct RPyOpaque_ThreadLock *lock)
{
	int status, error = 0;
	if (lock->initialized) {
		/* remove 'lock' from the doubly-linked list */
		if (lock->prev)
			lock->prev->next = lock->next;
		else {
			assert(alllocks == lock);
			alllocks = lock->next;
		}
		if (lock->next)
			lock->next->prev = lock->prev;

		status = pthread_cond_destroy(&lock->lock_released);
		CHECK_STATUS("pthread_cond_destroy");

		status = pthread_mutex_destroy(&lock->mut);
		CHECK_STATUS("pthread_mutex_destroy");

		/* 'error' is ignored;
		   CHECK_STATUS already printed an error message */
	}
}

RPyLockStatus
RPyThreadAcquireLockTimed(struct RPyOpaque_ThreadLock *lock,
			  RPY_TIMEOUT_T microseconds, int intr_flag)
{
	RPyLockStatus success;
	int status, error = 0;

	status = pthread_mutex_lock( &lock->mut );
	CHECK_STATUS("pthread_mutex_lock[1]");

	if (lock->locked == 0) {
	    success = RPY_LOCK_ACQUIRED;
	} else if (microseconds == 0) {
	    success = RPY_LOCK_FAILURE;
	} else {
		struct timespec ts;
		if (microseconds > 0)
		    RPY_MICROSECONDS_TO_TIMESPEC(microseconds, ts);
		/* continue trying until we get the lock */

		/* mut must be locked by me -- part of the condition
		 * protocol */
		success = RPY_LOCK_FAILURE;
		while (success == RPY_LOCK_FAILURE) {
		    if (microseconds > 0) {
			status = pthread_cond_timedwait(
			    &lock->lock_released,
			    &lock->mut, &ts);
			if (status == ETIMEDOUT)
			    break;
			CHECK_STATUS("pthread_cond_timed_wait");
		    }
		    else {
			status = pthread_cond_wait(
			    &lock->lock_released,
			    &lock->mut);
			CHECK_STATUS("pthread_cond_wait");
		    }

		    if (intr_flag && status == 0 && lock->locked) {
			/* We were woken up, but didn't get the lock.  We probably received
			 * a signal.  Return RPY_LOCK_INTR to allow the caller to handle
			 * it and retry.  */
			success = RPY_LOCK_INTR;
			break;
		    } else if (status == 0 && !lock->locked) {
			success = RPY_LOCK_ACQUIRED;
		    } else {
			success = RPY_LOCK_FAILURE;
		    }
		}
	}
	if (success == RPY_LOCK_ACQUIRED) lock->locked = 1;
	status = pthread_mutex_unlock( &lock->mut );
	CHECK_STATUS("pthread_mutex_unlock[1]");

	if (error) success = RPY_LOCK_FAILURE;
	return success;
}

Signed RPyThreadReleaseLock(struct RPyOpaque_ThreadLock *lock)
{
	int status, error = 0;
    Signed result;

	status = pthread_mutex_lock( &lock->mut );
	CHECK_STATUS("pthread_mutex_lock[3]");

        /* If the lock was non-locked, then oops, we return -1 for failure.
           Otherwise, we return 0 for success. */
        result = (lock->locked == 0) ? -1 : 0;

	lock->locked = 0;

	/* wake up someone (anyone, if any) waiting on the lock */
	status = pthread_cond_signal( &lock->lock_released );
	CHECK_STATUS("pthread_cond_signal");

	status = pthread_mutex_unlock( &lock->mut );
	CHECK_STATUS("pthread_mutex_unlock[3]");

        return result;
}

/************************************************************/
#endif                                     /* no semaphores */
/************************************************************/


/************************************************************/
/* GIL code                                                 */
/************************************************************/

#include <time.h>

#define ASSERT_STATUS(call)                             \
    if (call != 0) {                                    \
        perror("Fatal error: " #call);                  \
        abort();                                        \
    }

static inline void timespec_delay(struct timespec *t, double incr)
{
#ifdef CLOCK_REALTIME
    clock_gettime(CLOCK_REALTIME, t);
#else
    struct timeval tv;
    RPY_GETTIMEOFDAY(&tv);
    t->tv_sec = tv.tv_sec;
    t->tv_nsec = tv.tv_usec * 1000 + 999;
#endif
    /* assumes that "incr" is not too large, less than 1 second */
    long nsec = t->tv_nsec + (long)(incr * 1000000000.0);
    if (nsec >= 1000000000) {
        t->tv_sec += 1;
        nsec -= 1000000000;
        assert(nsec < 1000000000);
    }
    t->tv_nsec = nsec;
}

typedef pthread_mutex_t mutex1_t;

static inline void mutex1_init(mutex1_t *mutex) {
    ASSERT_STATUS(pthread_mutex_init(mutex, pthread_mutexattr_default));
}
static inline void mutex1_lock(mutex1_t *mutex) {
    ASSERT_STATUS(pthread_mutex_lock(mutex));
}
static inline void mutex1_unlock(mutex1_t *mutex) {
    ASSERT_STATUS(pthread_mutex_unlock(mutex));
}

typedef struct {
    char locked;
    pthread_mutex_t mut;
    pthread_cond_t cond;
} mutex2_t;

static inline void mutex2_init_locked(mutex2_t *mutex) {
    mutex->locked = 1;
    ASSERT_STATUS(pthread_mutex_init(&mutex->mut, pthread_mutexattr_default));
    ASSERT_STATUS(pthread_cond_init(&mutex->cond, pthread_condattr_default));
}
static inline void mutex2_unlock(mutex2_t *mutex) {
    ASSERT_STATUS(pthread_mutex_lock(&mutex->mut));
    mutex->locked = 0;
    ASSERT_STATUS(pthread_mutex_unlock(&mutex->mut));
    ASSERT_STATUS(pthread_cond_signal(&mutex->cond));
}
static inline void mutex2_loop_start(mutex2_t *mutex) {
    ASSERT_STATUS(pthread_mutex_lock(&mutex->mut));
}
static inline void mutex2_loop_stop(mutex2_t *mutex) {
    ASSERT_STATUS(pthread_mutex_unlock(&mutex->mut));
}
static inline int mutex2_lock_timeout(mutex2_t *mutex, double delay) {
    if (mutex->locked) {
        struct timespec t;
        timespec_delay(&t, delay);
        int error_from_timedwait = pthread_cond_timedwait(
                                       &mutex->cond, &mutex->mut, &t);
        if (error_from_timedwait != ETIMEDOUT) {
            ASSERT_STATUS(error_from_timedwait);
        }
    }
    int result = !mutex->locked;
    mutex->locked = 1;
    return result;
}

//#define pypy_lock_test_and_set(ptr, value)  see thread_pthread.h
#define atomic_increment(ptr)          __sync_add_and_fetch(ptr, 1)
#define atomic_decrement(ptr)          __sync_sub_and_fetch(ptr, 1)
#define RPy_CompilerMemoryBarrier()    asm("":::"memory")
#define HAVE_PTHREAD_ATFORK            1

#include "src/asm.h"   /* for RPy_YieldProcessor() */
#ifndef RPy_YieldProcessor
#  define RPy_YieldProcessor()   /* nothing */
#endif

#include "src/thread_gil.c"
