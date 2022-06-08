/*
 * Copyright (c) 2002, 2008, 2009 Apple Inc. All rights reserved.
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

/*
 * These routines are DEPRECATED and should not be used.
 */
#ifndef _UCONTEXT_H_
#define _UCONTEXT_H_

#include <sys/cdefs.h>

#ifdef _XOPEN_SOURCE
#include <sys/ucontext.h>
#include <Availability.h>

__BEGIN_DECLS
__API_DEPRECATED("No longer supported", macos(10.5, 10.6))
int  getcontext(ucontext_t *);

__API_DEPRECATED("No longer supported", macos(10.5, 10.6))
void makecontext(ucontext_t *, void (*)(), int, ...);

__API_DEPRECATED("No longer supported", macos(10.5, 10.6))
int  setcontext(const ucontext_t *);

__API_DEPRECATED("No longer supported", macos(10.5, 10.6))
int  swapcontext(ucontext_t * __restrict, const ucontext_t * __restrict);

__END_DECLS
#else /* !_XOPEN_SOURCE */
#error The deprecated ucontext routines require _XOPEN_SOURCE to be defined
#endif /* _XOPEN_SOURCE */

#endif /* _UCONTEXT_H_ */