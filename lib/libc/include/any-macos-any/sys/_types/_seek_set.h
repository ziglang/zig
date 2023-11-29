/*
 * Copyright (c) 2003-2012 Apple Inc. All rights reserved.
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

#ifndef _SEEK_SET_H_
#define _SEEK_SET_H_

#include <sys/cdefs.h>

/* whence values for lseek(2) */
#ifndef SEEK_SET
#define SEEK_SET        0       /* set file offset to offset */
#define SEEK_CUR        1       /* set file offset to current plus offset */
#define SEEK_END        2       /* set file offset to EOF plus offset */
#endif  /* !SEEK_SET */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#ifndef SEEK_HOLE
#define SEEK_HOLE       3       /* set file offset to the start of the next hole greater than or equal to the supplied offset */
#endif

#ifndef SEEK_DATA
#define SEEK_DATA       4       /* set file offset to the start of the next non-hole file region greater than or equal to the supplied offset */
#endif
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

#endif /* _SEEK_SET_H_ */
