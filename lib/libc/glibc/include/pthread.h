#include_next <pthread.h>

#ifndef _ISOMAC
/* Prototypes repeated instead of using __typeof because pthread.h is
   included in C++ tests, and declaring functions with __typeof and
   __THROW doesn't work for C++.  */
extern int __pthread_barrier_init (pthread_barrier_t *__restrict __barrier,
				 const pthread_barrierattr_t *__restrict
				 __attr, unsigned int __count)
     __THROW __nonnull ((1));
extern int __pthread_barrier_wait (pthread_barrier_t *__barrier)
     __THROWNL __nonnull ((1));

/* This function is called to initialize the pthread library.  */
extern void __pthread_initialize (void) __attribute__ ((weak));
#endif
