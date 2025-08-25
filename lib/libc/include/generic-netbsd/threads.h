/*	$NetBSD: threads.h,v 1.3 2019/09/10 22:34:19 kamil Exp $	*/

/*-
 * Copyright (c) 2016 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Kamil Rytarowski.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _THREADS_H_
#define _THREADS_H_

#include <sys/cdefs.h>
#include <limits.h>
#include <pthread.h>
#include <stdint.h>
#include <time.h>

/* ISO/IEC 9899:201x 7.26.1/3 */
#ifndef __thread_local_is_defined
#if ((__cplusplus - 0) < 201103L)
#define thread_local _Thread_local
#endif
#define __thread_local_is_defined
#endif /* __thread_local_is_defined */

#ifndef ONCE_FLAG_INIT
#define ONCE_FLAG_INIT	PTHREAD_ONCE_INIT
#endif /* ONCE_FLAG_INIT */

#ifndef TSS_DTOR_ITERATIONS
#define TSS_DTOR_ITERATIONS	PTHREAD_DESTRUCTOR_ITERATIONS
#endif /* TSS_DTOR_ITERATIONS */

/* ISO/IEC 9899:201x 7.26.1/4 */
typedef pthread_cond_t	  cnd_t;
typedef pthread_t	  thrd_t;
typedef pthread_key_t	  tss_t;
typedef pthread_mutex_t	  mtx_t;
typedef void		(*tss_dtor_t)	(void *);
typedef int		(*thrd_start_t)	(void *);
typedef	pthread_once_t	  once_flag;

/* ISO/IEC 9899:201x 7.26.1/5 */
enum {
	mtx_plain	= 1,
	mtx_recursive	= 2,
	mtx_timed	= 4,
	_MTX_MAXTYPE	= 0x7fffffff
};

enum {
	thrd_timedout	= -1,
	thrd_success	=  0,
	thrd_busy	=  1,
	thrd_error	=  2,
	thrd_nomem	=  3,
	_THRD_MAXTYPE	=  0x7fffffff
};

__BEGIN_DECLS
/* ISO/IEC 9899:201x 7.26.2 Initialization functions */
void	call_once(once_flag *, void (*)(void));

/* ISO/IEC 9899:201x 7.26.3 Condition variable functions */
int	cnd_broadcast(cnd_t *);
void	cnd_destroy(cnd_t *);
int	cnd_init(cnd_t *);
int	cnd_signal(cnd_t *);
int	cnd_timedwait(cnd_t * __restrict, mtx_t * __restrict,
	    const struct timespec * __restrict);
int	cnd_wait(cnd_t *, mtx_t *);

/* ISO/IEC 9899:201x 7.26.4 Mutex functions */
void	mtx_destroy(mtx_t *);
int	mtx_init(mtx_t *, int);
int	mtx_lock(mtx_t *);
int	mtx_timedlock(mtx_t *__restrict, const struct timespec *__restrict);
int	mtx_trylock(mtx_t *);
int	mtx_unlock(mtx_t *);

/* ISO/IEC 9899:201x 7.26.5 Thread functions */
int	thrd_create(thrd_t *, thrd_start_t, void *);
thrd_t	thrd_current(void);
int	thrd_detach(thrd_t);
int	thrd_equal(thrd_t, thrd_t);
__dead void	thrd_exit(int);
int	thrd_join(thrd_t, int *);
int	thrd_sleep(const struct timespec *, struct timespec *);
void	thrd_yield(void);

/* ISO/IEC 9899:201x 7.26.6 Thread-specific storage functions */
int	tss_create(tss_t *, tss_dtor_t);
void	tss_delete(tss_t);
void	*tss_get(tss_t);
int	tss_set(tss_t, void *);
__END_DECLS

#endif