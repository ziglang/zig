/* Copyright (c) 2010 Apple Inc. All rights reserved.
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

#ifndef _CDEFS_H_
# error "Never use <sys/_posix_availability.h> directly.  Use <sys/cdefs.h> instead."
#endif

#if !defined(_DARWIN_C_SOURCE) && defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 198808L
#define ___POSIX_C_DEPRECATED_STARTING_198808L __deprecated
#else
#define ___POSIX_C_DEPRECATED_STARTING_198808L
#endif

#if !defined(_DARWIN_C_SOURCE) && defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 199009L
#define ___POSIX_C_DEPRECATED_STARTING_199009L __deprecated
#else
#define ___POSIX_C_DEPRECATED_STARTING_199009L
#endif

#if !defined(_DARWIN_C_SOURCE) && defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 199209L
#define ___POSIX_C_DEPRECATED_STARTING_199209L __deprecated
#else
#define ___POSIX_C_DEPRECATED_STARTING_199209L
#endif

#if !defined(_DARWIN_C_SOURCE) && defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 199309L
#define ___POSIX_C_DEPRECATED_STARTING_199309L __deprecated
#else
#define ___POSIX_C_DEPRECATED_STARTING_199309L
#endif

#if !defined(_DARWIN_C_SOURCE) && defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 199506L
#define ___POSIX_C_DEPRECATED_STARTING_199506L __deprecated
#else
#define ___POSIX_C_DEPRECATED_STARTING_199506L
#endif

#if !defined(_DARWIN_C_SOURCE) && defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 200112L
#define ___POSIX_C_DEPRECATED_STARTING_200112L __deprecated
#else
#define ___POSIX_C_DEPRECATED_STARTING_200112L
#endif

#if !defined(_DARWIN_C_SOURCE) && defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 200809L
#define ___POSIX_C_DEPRECATED_STARTING_200809L __deprecated
#else
#define ___POSIX_C_DEPRECATED_STARTING_200809L
#endif

