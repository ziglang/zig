/*	$NetBSD: pthread_types.h,v 1.27 2022/04/10 10:38:33 riastradh Exp $	*/

/*-
 * Copyright (c) 2001, 2008, 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Nathan J. Williams.
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

#ifndef _LIB_PTHREAD_TYPES_H
#define _LIB_PTHREAD_TYPES_H

/*
 * We use the "pthread_spin_t" name internally; "pthread_spinlock_t" is the
 * POSIX spinlock object.
 *
 * C++ expects to be using PTHREAD_FOO_INITIALIZER as a member initializer.
 * This does not work for volatile types.  Since C++ does not touch the guts
 * of those types, we do not include volatile in the C++ definitions.
 */
typedef __cpu_simple_lock_t pthread_spin_t;
#ifdef __cplusplus
typedef __cpu_simple_lock_nv_t __pthread_spin_t;
#define __pthread_volatile
#else
typedef pthread_spin_t __pthread_spin_t;
#define __pthread_volatile volatile
#endif

/*
 * Copied from PTQ_HEAD in pthread_queue.h
 */
#define _PTQ_HEAD(name, type)	       				\
struct name {								\
	struct type *ptqh_first;/* first element */			\
	struct type **ptqh_last;/* addr of last next element */		\
}

_PTQ_HEAD(pthread_queue_struct_t, __pthread_st);
typedef struct pthread_queue_struct_t pthread_queue_t;

struct	__pthread_st;
struct	__pthread_attr_st;
struct	__pthread_mutex_st;
struct	__pthread_mutexattr_st;
struct	__pthread_cond_st;
struct	__pthread_condattr_st;
struct	__pthread_spin_st;
struct	__pthread_rwlock_st;
struct	__pthread_rwlockattr_st;
struct	__pthread_barrier_st;
struct	__pthread_barrierattr_st;

typedef struct __pthread_st *pthread_t;
typedef struct __pthread_attr_st pthread_attr_t;
typedef struct __pthread_mutex_st pthread_mutex_t;
typedef struct __pthread_mutexattr_st pthread_mutexattr_t;
typedef struct __pthread_cond_st pthread_cond_t;
typedef struct __pthread_condattr_st pthread_condattr_t;
typedef struct __pthread_once_st pthread_once_t;
typedef struct __pthread_spinlock_st pthread_spinlock_t;
typedef struct __pthread_rwlock_st pthread_rwlock_t;
typedef struct __pthread_rwlockattr_st pthread_rwlockattr_t;
typedef struct __pthread_barrier_st pthread_barrier_t;
typedef struct __pthread_barrierattr_st pthread_barrierattr_t;
typedef int pthread_key_t;

struct	__pthread_attr_st {
	unsigned int	pta_magic;

	int	pta_flags;
	void	*pta_private;
};

/*
 * ptm_owner is the actual lock field which is locked via CAS operation.
 * This structure's layout is designed to compatible with the previous
 * version used in SA pthreads.
 */
#ifdef __CPU_SIMPLE_LOCK_PAD
/*
 * If __SIMPLE_UNLOCKED != 0 and we have to pad, we have to worry about
 * endianness.  Currently that isn't an issue but put in a check in case
 * something changes in the future.
 */
#if __SIMPLELOCK_UNLOCKED != 0
#error __CPU_SIMPLE_LOCK_PAD incompatible with __SIMPLELOCK_UNLOCKED == 0
#endif
#endif
struct	__pthread_mutex_st {
	unsigned int	ptm_magic;
	__pthread_spin_t ptm_errorcheck;
#ifdef __CPU_SIMPLE_LOCK_PAD
	uint8_t		ptm_pad1[3];
#if (__STDC_VERSION__ - 0) >= 199901L
#define _PTHREAD_MUTEX_PAD(a)	.a = { 0, 0, 0 },
#else
#define _PTHREAD_MUTEX_PAD(a)	{ 0, 0, 0 },
#endif
#else
#define _PTHREAD_MUTEX_PAD(a)
#endif
	union {
		unsigned char ptm_ceiling;
		__pthread_spin_t ptm_unused;
	};
#ifdef __CPU_SIMPLE_LOCK_PAD
	uint8_t		ptm_pad2[3];
#endif
	__pthread_volatile pthread_t ptm_owner;
	void * __pthread_volatile ptm_waiters;
	unsigned int	ptm_recursed;
	void		*ptm_spare2;	/* unused - backwards compat */
};

#define	_PT_MUTEX_MAGIC	0x33330003
#define	_PT_MUTEX_DEAD	0xDEAD0003

#if (__STDC_VERSION__ - 0) >= 199901L
#define _PTHREAD_MUTEX_INI(a, b) .a = b
#define _PTHREAD_MUTEX_UNI(a) .a = 0
#else
#define _PTHREAD_MUTEX_INI(a, b) b
#define _PTHREAD_MUTEX_UNI(a) { 0 }
#endif

#define _PTHREAD_MUTEX_INITIALIZER {					\
	_PTHREAD_MUTEX_INI(ptm_magic, _PT_MUTEX_MAGIC), 		\
	_PTHREAD_MUTEX_INI(ptm_errorcheck, __SIMPLELOCK_UNLOCKED),	\
	_PTHREAD_MUTEX_PAD(ptm_pad1)					\
	_PTHREAD_MUTEX_UNI(ptm_ceiling),				\
	_PTHREAD_MUTEX_PAD(ptm_pad2)					\
	_PTHREAD_MUTEX_INI(ptm_owner, NULL),				\
	_PTHREAD_MUTEX_INI(ptm_waiters, NULL),				\
	_PTHREAD_MUTEX_INI(ptm_recursed, 0),				\
	_PTHREAD_MUTEX_INI(ptm_spare2, NULL),				\
}

struct	__pthread_mutexattr_st {
	unsigned int	ptma_magic;
	void	*ptma_private;
};

#define _PT_MUTEXATTR_MAGIC	0x44440004
#define _PT_MUTEXATTR_DEAD	0xDEAD0004


struct	__pthread_cond_st {
	unsigned int	ptc_magic;

	/* Protects the queue of waiters */
	__pthread_spin_t ptc_lock;
	void *__pthread_volatile ptc_waiters;
	void *ptc_spare;

	pthread_mutex_t	*ptc_mutex;	/* Current mutex */
	void	*ptc_private;
};

#define	_PT_COND_MAGIC	0x55550005
#define	_PT_COND_DEAD	0xDEAD0005

#define _PTHREAD_COND_INITIALIZER { _PT_COND_MAGIC,			\
				   __SIMPLELOCK_UNLOCKED,		\
				   NULL,				\
				   NULL,				\
				   NULL,				\
				   NULL  				\
				 }

struct	__pthread_condattr_st {
	unsigned int	ptca_magic;
	void	*ptca_private;
};

#define	_PT_CONDATTR_MAGIC	0x66660006
#define	_PT_CONDATTR_DEAD	0xDEAD0006

struct	__pthread_once_st {
	pthread_mutex_t	pto_mutex;
	int	pto_done;
};

#define _PTHREAD_ONCE_INIT	{ PTHREAD_MUTEX_INITIALIZER, 0 }

struct	__pthread_spinlock_st {
	unsigned int	pts_magic;
	__pthread_spin_t pts_spin;
	int		pts_flags;
};

#define	_PT_SPINLOCK_MAGIC	0x77770007
#define	_PT_SPINLOCK_DEAD	0xDEAD0007
#define _PT_SPINLOCK_PSHARED	0x00000001

/* PTHREAD_SPINLOCK_INITIALIZER is an extension not specified by POSIX. */
#define _PTHREAD_SPINLOCK_INITIALIZER { _PT_SPINLOCK_MAGIC,		\
				       __SIMPLELOCK_UNLOCKED,		\
				       0				\
				     }

struct	__pthread_rwlock_st {
	unsigned int	ptr_magic;

	/* Protects data below */
	__pthread_spin_t ptr_interlock;

	pthread_queue_t	ptr_rblocked;
	pthread_queue_t	ptr_wblocked;
	unsigned int	ptr_nreaders;
	__pthread_volatile pthread_t ptr_owner;
	void	*ptr_private;
};

#define	_PT_RWLOCK_MAGIC	0x99990009
#define	_PT_RWLOCK_DEAD		0xDEAD0009

#define _PTHREAD_RWLOCK_INITIALIZER { _PT_RWLOCK_MAGIC,			\
				     __SIMPLELOCK_UNLOCKED,		\
				     {NULL, NULL},			\
				     {NULL, NULL},			\
				     0,					\
				     NULL,				\
				     NULL,				\
				   }

struct	__pthread_rwlockattr_st {
	unsigned int	ptra_magic;
	void *ptra_private;
};

#define _PT_RWLOCKATTR_MAGIC	0x99990909
#define _PT_RWLOCKATTR_DEAD	0xDEAD0909

struct	__pthread_barrier_st {
	unsigned int	ptb_magic;

	/* Protects data below */
	pthread_spin_t	ptb_lock;

	pthread_queue_t	ptb_waiters;
	unsigned int	ptb_initcount;
	unsigned int	ptb_curcount;
	unsigned int	ptb_generation;

	void		*ptb_private;
};

#define	_PT_BARRIER_MAGIC	0x88880008
#define	_PT_BARRIER_DEAD	0xDEAD0008

struct	__pthread_barrierattr_st {
	unsigned int	ptba_magic;
	void		*ptba_private;
};

#define	_PT_BARRIERATTR_MAGIC	0x88880808
#define	_PT_BARRIERATTR_DEAD	0xDEAD0808

#endif	/* _LIB_PTHREAD_TYPES_H */