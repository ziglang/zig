/*
 * Copyright (c) 2005, 2007 Apple Inc. All rights reserved.
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
 * This is called from sys/select.h and sys/time.h for the common prototype
 * of select().  Setting _DARWIN_C_SOURCE or _DARWIN_UNLIMITED_SELECT uses
 * the version of select() that does not place a limit on the first argument
 * (nfds).  In the UNIX conformance case, values of nfds greater than
 * FD_SETSIZE will return an error of EINVAL.
 */
#ifndef _SYS__SELECT_H_
#define _SYS__SELECT_H_

#include <sys/cdefs.h> /* __DARWIN_EXTSN_C, __DARWIN_1050, __DARWIN_ALIAS_C */
#include <sys/_types/_fd_def.h> /* fd_set */
#include <sys/_types/_timeval.h> /* struct timeval */

int      select(int, fd_set * __restrict, fd_set * __restrict,
    fd_set * __restrict, struct timeval * __restrict)

#if defined(_DARWIN_C_SOURCE) || defined(_DARWIN_UNLIMITED_SELECT)
__DARWIN_EXTSN_C(select)
#else /* !_DARWIN_C_SOURCE && !_DARWIN_UNLIMITED_SELECT */
#  if defined(__LP64__) && !__DARWIN_NON_CANCELABLE
__DARWIN_1050(select)
#  else /* !__LP64__ || __DARWIN_NON_CANCELABLE */
__DARWIN_ALIAS_C(select)
#  endif /* __LP64__ && !__DARWIN_NON_CANCELABLE */
#endif /* _DARWIN_C_SOURCE || _DARWIN_UNLIMITED_SELECT */
;

#endif /* !_SYS__SELECT_H_ */
