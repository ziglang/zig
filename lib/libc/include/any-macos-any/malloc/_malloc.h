/*
 * Copyright (c) 2018 Apple Computer, Inc. All rights reserved.
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

#ifndef _MALLOC_UNDERSCORE_MALLOC_H_
#define _MALLOC_UNDERSCORE_MALLOC_H_

/*
 * This header is included from <stdlib.h>, so the contents of this file have
 * broad source compatibility and POSIX conformance implications.
 * Be cautious about what is included and declared here.
 */

#include <Availability.h>
#include <sys/cdefs.h>
#include <_types.h>
#include <sys/_types/_size_t.h>
#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#include <malloc/_malloc_type.h>
#else
#define _MALLOC_TYPED(override, type_param_pos)
#endif

__BEGIN_DECLS

void *malloc(size_t __size) __result_use_check __alloc_size(1) _MALLOC_TYPED(malloc_type_malloc, 1);
void *calloc(size_t __count, size_t __size) __result_use_check __alloc_size(1,2) _MALLOC_TYPED(malloc_type_calloc, 2);
void  free(void *);
void *realloc(void *__ptr, size_t __size) __result_use_check __alloc_size(2) _MALLOC_TYPED(malloc_type_realloc, 2);
#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
void *valloc(size_t) __alloc_size(1) _MALLOC_TYPED(malloc_type_valloc, 1);
#endif /* !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)) */
#if (__DARWIN_C_LEVEL >= __DARWIN_C_FULL) || \
    (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L) || \
    (defined(__cplusplus) && __cplusplus >= 201703L)
void *aligned_alloc(size_t __alignment, size_t __size) __result_use_check __alloc_size(2) _MALLOC_TYPED(malloc_type_aligned_alloc, 2) __OSX_AVAILABLE(10.15) __IOS_AVAILABLE(13.0) __TVOS_AVAILABLE(13.0) __WATCHOS_AVAILABLE(6.0);
#endif
int   posix_memalign(void **__memptr, size_t __alignment, size_t __size) /*__alloc_size(3)*/ _MALLOC_TYPED(malloc_type_posix_memalign, 3)  __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_0);

__END_DECLS

#endif /* _MALLOC_UNDERSCORE_MALLOC_H_ */
