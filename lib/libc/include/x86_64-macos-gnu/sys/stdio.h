/*
 * Copyright (c) 2013 Apple Inc. All rights reserved.
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

#ifndef _SYS_STDIO_H_
#define _SYS_STDIO_H_

#include <sys/cdefs.h>

#if __DARWIN_C_LEVEL >= 200809L
#include <Availability.h>

__BEGIN_DECLS

int     renameat(int, const char *, int, const char *) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL

#define RENAME_SECLUDE          0x00000001
#define RENAME_SWAP                     0x00000002
#define RENAME_EXCL                     0x00000004
int renamex_np(const char *, const char *, unsigned int) __OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);
int renameatx_np(int, const char *, int, const char *, unsigned int) __OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) __TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0);

#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

__END_DECLS

#endif /* __DARWIN_C_LEVEL >= 200809L */

#endif /* _SYS_STDIO_H_ */
