/*
 * Copyright (c) 2018-2023 Apple Computer, Inc. All rights reserved.
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
#if __has_include(<sys/_types/_size_t.h>)
#include <sys/_types/_size_t.h>
#else
#define __need_size_t
#include <stddef.h>
#undef __need_size_t
#endif

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#include <malloc/_malloc_type.h>
#else
#define _MALLOC_TYPED(override, type_param_pos)
#endif

#include <malloc/_ptrcheck.h>
__ptrcheck_abi_assume_single()

__BEGIN_DECLS

void * __sized_by_or_null(__size) malloc(size_t __size) __result_use_check __alloc_size(1) _MALLOC_TYPED(malloc_type_malloc, 1);
void * __sized_by_or_null(__count * __size) calloc(size_t __count, size_t __size) __result_use_check __alloc_size(1,2) _MALLOC_TYPED(malloc_type_calloc, 2);
void  free(void * __unsafe_indexable);
void * __sized_by_or_null(__size) realloc(void * __unsafe_indexable __ptr, size_t __size) __result_use_check __alloc_size(2) _MALLOC_TYPED(malloc_type_realloc, 2);
#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
void * __sized_by_or_null(__size) reallocf(void * __unsafe_indexable __ptr, size_t __size) __result_use_check __alloc_size(2);
void * __sized_by_or_null(__size) valloc(size_t __size) __result_use_check __alloc_size(1) _MALLOC_TYPED(malloc_type_valloc, 1);
#endif /* !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)) */
#if (defined(__DARWIN_C_LEVEL) && defined(__DARWIN_C_FULL) && __DARWIN_C_LEVEL >= __DARWIN_C_FULL) || \
    (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L) || \
    (defined(__cplusplus) && __cplusplus >= 201703L)
void * __sized_by_or_null(__size) aligned_alloc(size_t __alignment, size_t __size) __result_use_check __alloc_align(1) __alloc_size(2) _MALLOC_TYPED(malloc_type_aligned_alloc, 2) __OSX_AVAILABLE(10.15) __IOS_AVAILABLE(13.0) __TVOS_AVAILABLE(13.0) __WATCHOS_AVAILABLE(6.0);
#endif
/* rdar://120689514 */
int   posix_memalign(void * __unsafe_indexable *__memptr, size_t __alignment, size_t __size) _MALLOC_TYPED(malloc_type_posix_memalign, 3)  __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_0);

#if defined(_MALLOC_TYPE_MALLOC_IS_BACKDEPLOYING) && _MALLOC_TYPE_MALLOC_IS_BACKDEPLOYING
static void * __sized_by_or_null(size) __attribute__((always_inline)) malloc_type_malloc_backdeploy(size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1) {
	__attribute__((weak_import)) void * __sized_by_or_null(size) malloc_type_malloc(size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1);
	__auto_type func = malloc;
	if (malloc_type_malloc) {
		return malloc_type_malloc(size, type_id);
	}
	return func(size);
}

static void * __sized_by_or_null(count * size) __attribute__((always_inline)) malloc_type_calloc_backdeploy(size_t count, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1,2) {
	__attribute__((weak_import)) void * __sized_by_or_null(count * size) malloc_type_calloc(size_t count, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1,2);
	__auto_type func = calloc;
	if (malloc_type_calloc) {
		return malloc_type_calloc(count, size, type_id);
	}
	return func(count, size);
}

static void __attribute__((always_inline)) malloc_type_free_backdeploy(void * __unsafe_indexable ptr, malloc_type_id_t type_id) {
	__attribute__((weak_import)) void  malloc_type_free(void * __unsafe_indexable ptr, malloc_type_id_t type_id);
	__auto_type func = free;
	if (malloc_type_free) {
		malloc_type_free(ptr, type_id);
	} else {
		func(ptr);
	}
}

static void * __sized_by_or_null(size) __attribute__((always_inline)) malloc_type_realloc_backdeploy(void * __unsafe_indexable ptr, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(2) {
	__attribute__((weak_import)) void * __sized_by_or_null(size) malloc_type_realloc(void * __unsafe_indexable ptr, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(2);
	__auto_type func = realloc;
	if (malloc_type_realloc) {
		return malloc_type_realloc(ptr, size, type_id);
	}
	return func(ptr, size);
}

static void * __sized_by_or_null(size) __attribute__((always_inline)) malloc_type_valloc_backdeploy(size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1) {
	__attribute__((weak_import)) void * __sized_by_or_null(size) malloc_type_valloc(size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1);
	__auto_type func = valloc;
	if (malloc_type_valloc) {
		return malloc_type_valloc(size, type_id);
	}
	return func(size);
}

#if (defined(__DARWIN_C_LEVEL) && defined(__DARWIN_C_FULL) && __DARWIN_C_LEVEL >= __DARWIN_C_FULL) || \
	(defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L) || \
	(defined(__cplusplus) && __cplusplus >= 201703L)
static void * __sized_by_or_null(size) __attribute__((always_inline)) malloc_type_aligned_alloc_backdeploy(size_t alignment, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_align(1) __alloc_size(2) {
	__attribute__((weak_import)) void * __sized_by_or_null(size) malloc_type_aligned_alloc(size_t alignment, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_align(1) __alloc_size(2);
	__auto_type func = aligned_alloc;
	if (malloc_type_aligned_alloc) {
		return malloc_type_aligned_alloc(alignment, size, type_id);
	}
	return func(alignment, size);
}
#endif

static int __attribute__((always_inline)) malloc_type_posix_memalign_backdeploy(void * __unsafe_indexable *memptr, size_t alignment, size_t size, malloc_type_id_t type_id) {
	__attribute__((weak_import)) int malloc_type_posix_memalign(void * __unsafe_indexable *memptr, size_t alignment, size_t size, malloc_type_id_t type_id);
	__auto_type func = posix_memalign;
	if (malloc_type_posix_memalign) {
		return malloc_type_posix_memalign(memptr, alignment, size, type_id);
	}
	return func(memptr, alignment, size);
}
#endif
__END_DECLS

#endif /* _MALLOC_UNDERSCORE_MALLOC_H_ */
