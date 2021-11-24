/*
 * Copyright (c) 2006 Apple Computer, Inc. All rights reserved.
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

/*
 * [SPN] Support for _POSIX_SPAWN
 *
 * This header contains information that is shared between the user space
 * and kernel versions of the posix_spawn() code.  Shared elements are all
 * manifest constants, at the current time.
 */

#ifndef _SYS_SPAWN_H_
#define _SYS_SPAWN_H_

/*
 * Possible bit values which may be OR'ed together and provided as the second
 * parameter to posix_spawnattr_setflags() or implicit returned in the value of
 * the second parameter to posix_spawnattr_getflags().
 */
#define POSIX_SPAWN_RESETIDS            0x0001  /* [SPN] R[UG]ID not E[UG]ID */
#define POSIX_SPAWN_SETPGROUP           0x0002  /* [SPN] set non-parent PGID */
#define POSIX_SPAWN_SETSIGDEF           0x0004  /* [SPN] reset sigset default */
#define POSIX_SPAWN_SETSIGMASK          0x0008  /* [SPN] set signal mask */

#if 0   /* _POSIX_PRIORITY_SCHEDULING [PS] : not supported */
#define POSIX_SPAWN_SETSCHEDPARAM       0x0010
#define POSIX_SPAWN_SETSCHEDULER        0x0020
#endif  /* 0 */

#if     !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
/*
 * Darwin-specific flags
 */
#define POSIX_SPAWN_SETEXEC             0x0040
#define POSIX_SPAWN_START_SUSPENDED     0x0080
#define POSIX_SPAWN_SETSID              0x0400
#define POSIX_SPAWN_CLOEXEC_DEFAULT     0x4000

/*
 * Possible values to be set for the process control actions on resource starvation.
 * POSIX_SPAWN_PCONTROL_THROTTLE indicates that the process is to be throttled on starvation.
 * POSIX_SPAWN_PCONTROL_SUSPEND indicates that the process is to be suspended on starvation.
 * POSIX_SPAWN_PCONTROL_KILL indicates that the process is to be terminated  on starvation.
 */
#define POSIX_SPAWN_PCONTROL_NONE       0x0000
#define POSIX_SPAWN_PCONTROL_THROTTLE   0x0001
#define POSIX_SPAWN_PCONTROL_SUSPEND    0x0002
#define POSIX_SPAWN_PCONTROL_KILL       0x0003

#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

#endif  /* _SYS_SPAWN_H_ */