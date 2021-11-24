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

#ifndef _PTHREAD_IMPL_H_
#define _PTHREAD_IMPL_H_
/*
 * Internal implementation details
 */

/* This whole header file will disappear, so don't depend on it... */

#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull begin")
#endif

#ifndef __POSIX_LIB__

/*
 * [Internal] data structure signatures
 */
#define _PTHREAD_MUTEX_SIG_init		0x32AAABA7

#define _PTHREAD_ERRORCHECK_MUTEX_SIG_init      0x32AAABA1
#define _PTHREAD_RECURSIVE_MUTEX_SIG_init       0x32AAABA2
#define _PTHREAD_FIRSTFIT_MUTEX_SIG_init       0x32AAABA3

#define _PTHREAD_COND_SIG_init		0x3CB0B1BB
#define _PTHREAD_ONCE_SIG_init		0x30B1BCBA
#define _PTHREAD_RWLOCK_SIG_init    0x2DA8B3B4

/*
 * POSIX scheduling policies
 */
#define SCHED_OTHER                1
#define SCHED_FIFO                 4
#define SCHED_RR                   2

#define __SCHED_PARAM_SIZE__       4

#endif /* __POSIX_LIB__ */

#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull end")
#endif

#endif /* _PTHREAD_IMPL_H_ */