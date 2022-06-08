/*
 * Copyright (c) 2000-2006 Apple Computer, Inc. All rights reserved.
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
/*	@(#)semaphore.h	1.0	2/29/00		*/



/*
 * semaphore.h - POSIX semaphores
 *
 * HISTORY
 * 29-Feb-00	A.Ramesh at Apple
 *	Created for Mac OS X
 */

#ifndef _SYS_SEMAPHORE_H_
#define _SYS_SEMAPHORE_H_

typedef int sem_t;

/* this should go in limits.h> */
#define SEM_VALUE_MAX 32767
#define SEM_FAILED ((sem_t *)-1)

#include <sys/cdefs.h>

__BEGIN_DECLS
int sem_close(sem_t *);
int sem_destroy(sem_t *) __deprecated;
int sem_getvalue(sem_t * __restrict, int * __restrict) __deprecated;
int sem_init(sem_t *, int, unsigned int) __deprecated;
sem_t * sem_open(const char *, int, ...);
int sem_post(sem_t *);
int sem_trywait(sem_t *);
int sem_unlink(const char *);
int sem_wait(sem_t *) __DARWIN_ALIAS_C(sem_wait);
__END_DECLS


#endif  /* _SYS_SEMAPHORE_H_ */