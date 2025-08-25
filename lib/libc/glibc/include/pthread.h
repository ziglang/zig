#include_next <pthread.h>

#ifndef _ISOMAC
/* Prototypes repeated instead of using __typeof because pthread.h is
   included in C++ tests, and declaring functions with __typeof and
   __THROW doesn't work for C++.  */
extern int __pthread_barrier_init (pthread_barrier_t *__restrict __barrier,
				 const pthread_barrierattr_t *__restrict
				 __attr, unsigned int __count)
     __THROW __nonnull ((1));
#if PTHREAD_IN_LIBC
libc_hidden_proto (__pthread_barrier_init)
#endif
extern int __pthread_barrier_wait (pthread_barrier_t *__barrier)
     __THROWNL __nonnull ((1));
#if PTHREAD_IN_LIBC
libc_hidden_proto (__pthread_barrier_wait)
#endif

/* This function is called to initialize the pthread library.  */
extern void __pthread_initialize (void) __attribute__ ((weak));

extern int __pthread_kill (pthread_t threadid, int signo);

extern pthread_t __pthread_self (void);

#endif
