/*
 * Copyright (c) 2022 Apple Computer, Inc. All rights reserved.
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

#ifndef _MALLOC_UNDERSCORE_MALLOC_TYPE_H_
#define _MALLOC_UNDERSCORE_MALLOC_TYPE_H_

#include <malloc/_ptrcheck.h>
__ptrcheck_abi_assume_single()

typedef unsigned long long malloc_type_id_t;

#if defined(__LP64__) /* MALLOC_TARGET_64BIT */

// Included from <malloc/_malloc.h> so carefully manage what we include here.
#include <Availability.h> /* __SPI_AVAILABLE */
#if __has_include(<sys/_types/_size_t.h>)
#include <sys/_types/_size_t.h>
#else
#define __need_size_t
#include <stddef.h>
#undef __need_size_t
#endif
#include <sys/cdefs.h> /* __BEGIN_DECLS */

#define _MALLOC_TYPE_AVAILABILITY __API_AVAILABLE(macos(14.0), ios(17.0), tvos(17.0), watchos(10.0), visionos(1.0), driverkit(23.0))

__BEGIN_DECLS

/* <malloc/_malloc.h> */

_MALLOC_TYPE_AVAILABILITY void * __sized_by_or_null(size) malloc_type_malloc(size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1);
_MALLOC_TYPE_AVAILABILITY void * __sized_by_or_null(count * size) malloc_type_calloc(size_t count, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1,2);
_MALLOC_TYPE_AVAILABILITY void  malloc_type_free(void * __unsafe_indexable ptr, malloc_type_id_t type_id);
_MALLOC_TYPE_AVAILABILITY void * __sized_by_or_null(size) malloc_type_realloc(void * __unsafe_indexable ptr, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(2);
_MALLOC_TYPE_AVAILABILITY void * __sized_by_or_null(size) malloc_type_valloc(size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(1);
_MALLOC_TYPE_AVAILABILITY void * __sized_by_or_null(size) malloc_type_aligned_alloc(size_t alignment, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(2);
/* rdar://120689514 */
_MALLOC_TYPE_AVAILABILITY int   malloc_type_posix_memalign(void * __unsafe_indexable *memptr, size_t alignment, size_t size, malloc_type_id_t type_id) /*__alloc_size(3)*/;


/* <malloc/malloc.h> */

typedef struct _malloc_zone_t malloc_zone_t;

_MALLOC_TYPE_AVAILABILITY void * __sized_by_or_null(size) malloc_type_zone_malloc(malloc_zone_t *zone, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(2);
_MALLOC_TYPE_AVAILABILITY void * __sized_by_or_null(count * size) malloc_type_zone_calloc(malloc_zone_t *zone, size_t count, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(2,3);
_MALLOC_TYPE_AVAILABILITY void  malloc_type_zone_free(malloc_zone_t *zone, void * __unsafe_indexable ptr, malloc_type_id_t type_id);
_MALLOC_TYPE_AVAILABILITY void * __sized_by_or_null(size) malloc_type_zone_realloc(malloc_zone_t *zone, void * __unsafe_indexable ptr, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(3);
_MALLOC_TYPE_AVAILABILITY void *__sized_by_or_null(size) malloc_type_zone_valloc(malloc_zone_t *zone, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(2);
_MALLOC_TYPE_AVAILABILITY void *__sized_by_or_null(size) malloc_type_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size, malloc_type_id_t type_id) __result_use_check __alloc_size(3);

__END_DECLS

/* Rewrite enablement */
#if defined(__has_feature) && __has_feature(typed_memory_operations)
#if __has_builtin(__is_target_os) && (__is_target_os(ios) || __is_target_os(driverkit) || __is_target_os(macos) || (__has_builtin(__is_target_environment) && (__is_target_environment(exclavekit) || __is_target_environment(exclavecore))))
#define _MALLOC_TYPED(override, type_param_pos) __attribute__((typed_memory_operation(override, type_param_pos)))
#define _MALLOC_TYPE_ENABLED 1
#endif 
#endif /* defined(__has_feature) && __has_feature(typed_memory_operations) */

#endif /* MALLOC_TARGET_64BIT */

#if !defined(_MALLOC_TYPED)
#define _MALLOC_TYPED(override, type_param_pos)
#endif

#endif /* _MALLOC_UNDERSCORE_MALLOC_TYPE_H_ */
