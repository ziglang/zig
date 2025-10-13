/*
 * Copyright (c) 2024 Apple Inc. All rights reserved.
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

#ifndef _LIBC_BOUNDS_H_
#define _LIBC_BOUNDS_H_

#include <sys/cdefs.h>

#ifdef __LIBC_STAGED_BOUNDS_SAFETY_ATTRIBUTES /* compiler-defined */

#define _LIBC_COUNT(x)		__counted_by(x)
#define _LIBC_COUNT_OR_NULL(x)	__counted_by_or_null(x)
#define _LIBC_SIZE(x)		__sized_by(x)
#define _LIBC_SIZE_OR_NULL(x)	__sized_by_or_null(x)
#define _LIBC_ENDED_BY(x)	__ended_by(x)
#define _LIBC_SINGLE		__single
#define _LIBC_UNSAFE_INDEXABLE	__unsafe_indexable
#define _LIBC_CSTR		__null_terminated
#define _LIBC_NULL_TERMINATED   __null_terminated
#define _LIBC_FLEX_COUNT(FIELD, INTCOUNT)	__counted_by(FIELD)

#define _LIBC_SINGLE_BY_DEFAULT()	__ptrcheck_abi_assume_single()
#define _LIBC_PTRCHECK_REPLACED(R)  __ptrcheck_unavailable_r(R)

#define _LIBC_FORGE_PTR(P, S) __unsafe_forge_bidi_indexable(__typeof__(*P) *, P, S)

#else /* _LIBC_ANNOTATE_BOUNDS */

#define _LIBC_COUNT(x)
#define _LIBC_COUNT_OR_NULL(x)
#define _LIBC_SIZE(x)
#define _LIBC_SIZE_OR_NULL(x)
#define _LIBC_ENDED_BY(x)
#define _LIBC_SINGLE
#define _LIBC_UNSAFE_INDEXABLE
#define _LIBC_CSTR
#define _LIBC_NULL_TERMINATED
#define _LIBC_FLEX_COUNT(FIELD, INTCOUNT)	(INTCOUNT)

#define _LIBC_SINGLE_BY_DEFAULT()
#define _LIBC_PTRCHECK_REPLACED(R)

#define _LIBC_FORGE_PTR(P, S) (P)

#endif /* _LIBC_ANNOTATE_BOUNDS */

#endif /* _LIBC_BOUNDS_H_ */
