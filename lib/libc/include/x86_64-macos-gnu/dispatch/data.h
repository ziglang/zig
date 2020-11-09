/*
 * Copyright (c) 2009-2013 Apple Inc. All rights reserved.
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */

#ifndef __DISPATCH_DATA__
#define __DISPATCH_DATA__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

DISPATCH_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

/*! @header
 * Dispatch data objects describe contiguous or sparse regions of memory that
 * may be managed by the system or by the application.
 * Dispatch data objects are immutable, any direct access to memory regions
 * represented by dispatch objects must not modify that memory.
 */

/*!
 * @typedef dispatch_data_t
 * A dispatch object representing memory regions.
 */
DISPATCH_DATA_DECL(dispatch_data);

/*!
 * @var dispatch_data_empty
 * @discussion The singleton dispatch data object representing a zero-length
 * memory region.
 */
#define dispatch_data_empty \
		DISPATCH_GLOBAL_OBJECT(dispatch_data_t, _dispatch_data_empty)
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT struct dispatch_data_s _dispatch_data_empty;

/*!
 * @const DISPATCH_DATA_DESTRUCTOR_DEFAULT
 * @discussion The default destructor for dispatch data objects.
 * Used at data object creation to indicate that the supplied buffer should
 * be copied into internal storage managed by the system.
 */
#define DISPATCH_DATA_DESTRUCTOR_DEFAULT NULL

#ifdef __BLOCKS__
/*! @parseOnly */
#define DISPATCH_DATA_DESTRUCTOR_TYPE_DECL(name) \
	DISPATCH_EXPORT const dispatch_block_t _dispatch_data_destructor_##name
#else
#define DISPATCH_DATA_DESTRUCTOR_TYPE_DECL(name) \
	DISPATCH_EXPORT const dispatch_function_t \
	_dispatch_data_destructor_##name
#endif /* __BLOCKS__ */

/*!
 * @const DISPATCH_DATA_DESTRUCTOR_FREE
 * @discussion The destructor for dispatch data objects created from a malloc'd
 * buffer. Used at data object creation to indicate that the supplied buffer
 * was allocated by the malloc() family and should be destroyed with free(3).
 */
#define DISPATCH_DATA_DESTRUCTOR_FREE (_dispatch_data_destructor_free)
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_DATA_DESTRUCTOR_TYPE_DECL(free);

/*!
 * @const DISPATCH_DATA_DESTRUCTOR_MUNMAP
 * @discussion The destructor for dispatch data objects that have been created
 * from buffers that require deallocation with munmap(2).
 */
#define DISPATCH_DATA_DESTRUCTOR_MUNMAP (_dispatch_data_destructor_munmap)
API_AVAILABLE(macos(10.9), ios(7.0))
DISPATCH_DATA_DESTRUCTOR_TYPE_DECL(munmap);

#ifdef __BLOCKS__
/*!
 * @function dispatch_data_create
 * Creates a dispatch data object from the given contiguous buffer of memory. If
 * a non-default destructor is provided, ownership of the buffer remains with
 * the caller (i.e. the bytes will not be copied). The last release of the data
 * object will result in the invocation of the specified destructor on the
 * specified queue to free the buffer.
 *
 * If the DISPATCH_DATA_DESTRUCTOR_FREE destructor is provided the buffer will
 * be freed via free(3) and the queue argument ignored.
 *
 * If the DISPATCH_DATA_DESTRUCTOR_DEFAULT destructor is provided, data object
 * creation will copy the buffer into internal memory managed by the system.
 *
 * @param buffer	A contiguous buffer of data.
 * @param size		The size of the contiguous buffer of data.
 * @param queue		The queue to which the destructor should be submitted.
 * @param destructor	The destructor responsible for freeing the data when it
 *			is no longer needed.
 * @result		A newly created dispatch data object.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_RETURNS_RETAINED DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_data_t
dispatch_data_create(const void *buffer,
	size_t size,
	dispatch_queue_t _Nullable queue,
	dispatch_block_t _Nullable destructor);
#endif /* __BLOCKS__ */

/*!
 * @function dispatch_data_get_size
 * Returns the logical size of the memory region(s) represented by the specified
 * dispatch data object.
 *
 * @param data	The dispatch data object to query.
 * @result	The number of bytes represented by the data object.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_PURE DISPATCH_NONNULL1 DISPATCH_NOTHROW
size_t
dispatch_data_get_size(dispatch_data_t data);

/*!
 * @function dispatch_data_create_map
 * Maps the memory represented by the specified dispatch data object as a single
 * contiguous memory region and returns a new data object representing it.
 * If non-NULL references to a pointer and a size variable are provided, they
 * are filled with the location and extent of that region. These allow direct
 * read access to the represented memory, but are only valid until the returned
 * object is released. Under ARC, if that object is held in a variable with
 * automatic storage, care needs to be taken to ensure that it is not released
 * by the compiler before memory access via the pointer has been completed.
 *
 * @param data		The dispatch data object to map.
 * @param buffer_ptr	A pointer to a pointer variable to be filled with the
 *			location of the mapped contiguous memory region, or
 *			NULL.
 * @param size_ptr	A pointer to a size_t variable to be filled with the
 *			size of the mapped contiguous memory region, or NULL.
 * @result		A newly created dispatch data object.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_RETURNS_RETAINED
DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_data_t
dispatch_data_create_map(dispatch_data_t data,
	const void *_Nullable *_Nullable buffer_ptr,
	size_t *_Nullable size_ptr);

/*!
 * @function dispatch_data_create_concat
 * Returns a new dispatch data object representing the concatenation of the
 * specified data objects. Those objects may be released by the application
 * after the call returns (however, the system might not deallocate the memory
 * region(s) described by them until the newly created object has also been
 * released).
 *
 * @param data1	The data object representing the region(s) of memory to place
 *		at the beginning of the newly created object.
 * @param data2	The data object representing the region(s) of memory to place
 *		at the end of the newly created object.
 * @result	A newly created object representing the concatenation of the
 *		data1 and data2 objects.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_RETURNS_RETAINED
DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_data_t
dispatch_data_create_concat(dispatch_data_t data1, dispatch_data_t data2);

/*!
 * @function dispatch_data_create_subrange
 * Returns a new dispatch data object representing a subrange of the specified
 * data object, which may be released by the application after the call returns
 * (however, the system might not deallocate the memory region(s) described by
 * that object until the newly created object has also been released).
 *
 * @param data		The data object representing the region(s) of memory to
 *			create a subrange of.
 * @param offset	The offset into the data object where the subrange
 *			starts.
 * @param length	The length of the range.
 * @result		A newly created object representing the specified
 *			subrange of the data object.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_RETURNS_RETAINED
DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_data_t
dispatch_data_create_subrange(dispatch_data_t data,
	size_t offset,
	size_t length);

#ifdef __BLOCKS__
/*!
 * @typedef dispatch_data_applier_t
 * A block to be invoked for every contiguous memory region in a data object.
 *
 * @param region	A data object representing the current region.
 * @param offset	The logical offset of the current region to the start
 *			of the data object.
 * @param buffer	The location of the memory for the current region.
 * @param size		The size of the memory for the current region.
 * @result		A Boolean indicating whether traversal should continue.
 */
typedef bool (^dispatch_data_applier_t)(dispatch_data_t region,
	size_t offset,
	const void *buffer,
	size_t size);

/*!
 * @function dispatch_data_apply
 * Traverse the memory regions represented by the specified dispatch data object
 * in logical order and invoke the specified block once for every contiguous
 * memory region encountered.
 *
 * Each invocation of the block is passed a data object representing the current
 * region and its logical offset, along with the memory location and extent of
 * the region. These allow direct read access to the memory region, but are only
 * valid until the passed-in region object is released. Note that the region
 * object is released by the system when the block returns, it is the
 * responsibility of the application to retain it if the region object or the
 * associated memory location are needed after the block returns.
 *
 * @param data		The data object to traverse.
 * @param applier	The block to be invoked for every contiguous memory
 *			region in the data object.
 * @result		A Boolean indicating whether traversal completed
 *			successfully.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
bool
dispatch_data_apply(dispatch_data_t data,
	DISPATCH_NOESCAPE dispatch_data_applier_t applier);
#endif /* __BLOCKS__ */

/*!
 * @function dispatch_data_copy_region
 * Finds the contiguous memory region containing the specified location among
 * the regions represented by the specified object and returns a copy of the
 * internal dispatch data object representing that region along with its logical
 * offset in the specified object.
 *
 * @param data		The dispatch data object to query.
 * @param location	The logical position in the data object to query.
 * @param offset_ptr	A pointer to a size_t variable to be filled with the
 *			logical offset of the returned region object to the
 *			start of the queried data object.
 * @result		A newly created dispatch data object.
 */
API_AVAILABLE(macos(10.7), ios(5.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NONNULL3 DISPATCH_RETURNS_RETAINED
DISPATCH_WARN_RESULT DISPATCH_NOTHROW
dispatch_data_t
dispatch_data_copy_region(dispatch_data_t data,
	size_t location,
	size_t *offset_ptr);

__END_DECLS

DISPATCH_ASSUME_NONNULL_END

#endif /* __DISPATCH_DATA__ */
