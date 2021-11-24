/*
 * Copyright (c) 2003-2013 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 * 
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */

#ifndef _SYS__PTHREAD_TYPES_H_
#define _SYS__PTHREAD_TYPES_H_

#include <sys/cdefs.h>

// pthread opaque structures
#if defined(__LP64__)
#define __PTHREAD_SIZE__		8176
#define __PTHREAD_ATTR_SIZE__		56
#define __PTHREAD_MUTEXATTR_SIZE__	8
#define __PTHREAD_MUTEX_SIZE__		56
#define __PTHREAD_CONDATTR_SIZE__	8
#define __PTHREAD_COND_SIZE__		40
#define __PTHREAD_ONCE_SIZE__		8
#define __PTHREAD_RWLOCK_SIZE__		192
#define __PTHREAD_RWLOCKATTR_SIZE__	16
#else // !__LP64__
#define __PTHREAD_SIZE__		4088
#define __PTHREAD_ATTR_SIZE__		36
#define __PTHREAD_MUTEXATTR_SIZE__	8
#define __PTHREAD_MUTEX_SIZE__		40
#define __PTHREAD_CONDATTR_SIZE__	4
#define __PTHREAD_COND_SIZE__		24
#define __PTHREAD_ONCE_SIZE__		4
#define __PTHREAD_RWLOCK_SIZE__		124
#define __PTHREAD_RWLOCKATTR_SIZE__	12
#endif // !__LP64__

struct __darwin_pthread_handler_rec {
	void (*__routine)(void *);	// Routine to call
	void *__arg;			// Argument to pass
	struct __darwin_pthread_handler_rec *__next;
};

struct _opaque_pthread_attr_t {
	long __sig;
	char __opaque[__PTHREAD_ATTR_SIZE__];
};

struct _opaque_pthread_cond_t {
	long __sig;
	char __opaque[__PTHREAD_COND_SIZE__];
};

struct _opaque_pthread_condattr_t {
	long __sig;
	char __opaque[__PTHREAD_CONDATTR_SIZE__];
};

struct _opaque_pthread_mutex_t {
	long __sig;
	char __opaque[__PTHREAD_MUTEX_SIZE__];
};

struct _opaque_pthread_mutexattr_t {
	long __sig;
	char __opaque[__PTHREAD_MUTEXATTR_SIZE__];
};

struct _opaque_pthread_once_t {
	long __sig;
	char __opaque[__PTHREAD_ONCE_SIZE__];
};

struct _opaque_pthread_rwlock_t {
	long __sig;
	char __opaque[__PTHREAD_RWLOCK_SIZE__];
};

struct _opaque_pthread_rwlockattr_t {
	long __sig;
	char __opaque[__PTHREAD_RWLOCKATTR_SIZE__];
};

struct _opaque_pthread_t {
	long __sig;
	struct __darwin_pthread_handler_rec  *__cleanup_stack;
	char __opaque[__PTHREAD_SIZE__];
};

typedef struct _opaque_pthread_attr_t __darwin_pthread_attr_t;
typedef struct _opaque_pthread_cond_t __darwin_pthread_cond_t;
typedef struct _opaque_pthread_condattr_t __darwin_pthread_condattr_t;
typedef unsigned long __darwin_pthread_key_t;
typedef struct _opaque_pthread_mutex_t __darwin_pthread_mutex_t;
typedef struct _opaque_pthread_mutexattr_t __darwin_pthread_mutexattr_t;
typedef struct _opaque_pthread_once_t __darwin_pthread_once_t;
typedef struct _opaque_pthread_rwlock_t __darwin_pthread_rwlock_t;
typedef struct _opaque_pthread_rwlockattr_t __darwin_pthread_rwlockattr_t;
typedef struct _opaque_pthread_t *__darwin_pthread_t;

#endif // _SYS__PTHREAD_TYPES_H_