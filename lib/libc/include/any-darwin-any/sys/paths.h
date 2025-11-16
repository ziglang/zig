/*
 * Copyright (c) 2000-2002 Apple Computer, Inc. All rights reserved.
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
/*	@(#)paths.h	1.0	11/13/00	*/

#ifndef _SYS_PATHS_H_
#define _SYS_PATHS_H_

#include <sys/appleapiopts.h>

#ifdef __APPLE_API_PRIVATE

/* Provides support for system wide forks */
#define _PATH_FORKSPECIFIER    "/..namedfork/"
#define _PATH_DATANAME         "data"
#define _PATH_RSRCNAME         "rsrc"
#define _PATH_RSRCFORKSPEC     "/..namedfork/rsrc"

/* Prefix Path Namespace */
#define RESOLVE_NOFOLLOW_ANY  0x00000001       /* no symlinks allowed in path */
#define RESOLVE_NODOTDOT      0x00000002       /* prevent '..' path traversal */
#define RESOLVE_LOCAL         0x00000004       /* prevent a path lookup into a network filesystem */
#define RESOLVE_NODEVFS       0x00000008       /* prevent a path lookup into `devfs` filesystem */
#define RESOLVE_IMMOVABLE     0x00000010       /* prevent a path lookup into a removable filesystem */
#define RESOLVE_UNIQUE        0x00000020       /* prevent a path lookup on a vnode with multiple links */
#define RESOLVE_NOXATTRS      0x00000040       /* prevent a path lookup on named streams */

#define RESOLVE_VALIDMASK     0x0000007F

#endif /* __APPLE_API_PRIVATE */
#endif /* !_SYS_PATHS_H_ */
