/*
 * Copyright (c) 2000-2003 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef _SCHED_H_
#define _SCHED_H_

#include <sys/cdefs.h>
#include <pthread/pthread_impl.h>

__BEGIN_DECLS
/*
 * Scheduling paramters
 */
#ifndef __POSIX_LIB__
struct sched_param { int sched_priority;  char __opaque[__SCHED_PARAM_SIZE__]; };
#else
struct sched_param;
#endif

extern int sched_yield(void);
extern int sched_get_priority_min(int);
extern int sched_get_priority_max(int);
__END_DECLS

#endif /* _SCHED_H_ */