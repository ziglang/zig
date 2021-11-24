/*
 * Copyright (c) 2004-2016 Apple Inc. All rights reserved.
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

#ifndef _OSATOMIC_DEPRECATED_H_
#define _OSATOMIC_DEPRECATED_H_

/*! @header
 * These are deprecated legacy interfaces for atomic operations.
 * The C11 interfaces in <stdatomic.h> resp. C++11 interfaces in <atomic>
 * should be used instead.
 *
 * Define OSATOMIC_USE_INLINED=1 to get inline implementations of these
 * interfaces in terms of the <stdatomic.h> resp. <atomic> primitives.
 * This is intended as a transition convenience, direct use of those primitives
 * is preferred.
 */

#if !(defined(OSATOMIC_USE_INLINED) && OSATOMIC_USE_INLINED)

#include    <sys/cdefs.h>
#include    <stddef.h>
#include    <stdint.h>
#include    <stdbool.h>
#include    <Availability.h>

#ifndef OSATOMIC_DEPRECATED
#define OSATOMIC_DEPRECATED 1
#ifndef __cplusplus
#define OSATOMIC_BARRIER_DEPRECATED_MSG(_r) \
		"Use " #_r "() from <stdatomic.h> instead"
#define OSATOMIC_DEPRECATED_MSG(_r) \
		"Use " #_r "_explicit(memory_order_relaxed) from <stdatomic.h> instead"
#else
#define OSATOMIC_BARRIER_DEPRECATED_MSG(_r) \
		"Use std::" #_r "() from <atomic> instead"
#define OSATOMIC_DEPRECATED_MSG(_r) \
		"Use std::" #_r "_explicit(std::memory_order_relaxed) from <atomic> instead"
#endif
#define OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(_r) \
	__OS_AVAILABILITY_MSG(macosx, deprecated=10.12, OSATOMIC_BARRIER_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(ios, deprecated=10.0, OSATOMIC_BARRIER_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(tvos, deprecated=10.0, OSATOMIC_BARRIER_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(watchos, deprecated=3.0, OSATOMIC_BARRIER_DEPRECATED_MSG(_r))
#define OSATOMIC_DEPRECATED_REPLACE_WITH(_r) \
	__OS_AVAILABILITY_MSG(macosx, deprecated=10.12, OSATOMIC_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(ios, deprecated=10.0, OSATOMIC_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(tvos, deprecated=10.0, OSATOMIC_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(watchos, deprecated=3.0, OSATOMIC_DEPRECATED_MSG(_r))
#else
#undef OSATOMIC_DEPRECATED
#define OSATOMIC_DEPRECATED 0
#define OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(_r)
#define OSATOMIC_DEPRECATED_REPLACE_WITH(_r)
#endif

/*
 * WARNING: all addresses passed to these functions must be "naturally aligned",
 * i.e. <code>int32_t</code> pointers must be 32-bit aligned (low 2 bits of
 * address are zeroes), and <code>int64_t</code> pointers must be 64-bit
 * aligned (low 3 bits of address are zeroes.).
 * Note that this is not the default alignment of the <code>int64_t</code> type
 * in the iOS ARMv7 ABI, see
 * {@link //apple_ref/doc/uid/TP40009021-SW8 iPhoneOSABIReference}
 *
 * Note that some versions of the atomic functions incorporate memory barriers
 * and some do not.  Barriers strictly order memory access on weakly-ordered
 * architectures such as ARM.  All loads and stores that appear (in sequential
 * program order) before the barrier are guaranteed to complete before any
 * load or store that appears after the barrier.
 *
 * The barrier operation is typically a no-op on uniprocessor systems and
 * fully enabled on multiprocessor systems. On some platforms, such as ARM,
 * the barrier can be quite expensive.
 *
 * Most code should use the barrier functions to ensure that memory shared
 * between threads is properly synchronized.  For example, if you want to
 * initialize a shared data structure and then atomically increment a variable
 * to indicate that the initialization is complete, you must use
 * {@link OSAtomicIncrement32Barrier} to ensure that the stores to your data
 * structure complete before the atomic increment.
 *
 * Likewise, the consumer of that data structure must use
 * {@link OSAtomicDecrement32Barrier},
 * in order to ensure that their loads of the structure are not executed before
 * the atomic decrement.  On the other hand, if you are simply incrementing a
 * global counter, then it is safe and potentially faster to use
 * {@link OSAtomicIncrement32}.
 *
 * If you are unsure which version to use, prefer the barrier variants as they
 * are safer.
 *
 * For the kernel-space version of this header, see
 * {@link //apple_ref/doc/header/OSAtomic.h OSAtomic.h (Kernel Framework)}
 *
 * @apiuid //apple_ref/doc/header/user_space_OSAtomic.h
 */

__BEGIN_DECLS

/*! @typedef OSAtomic_int64_aligned64_t
 * 64-bit aligned <code>int64_t</code> type.
 * Use for variables whose addresses are passed to OSAtomic*64() functions to
 * get the compiler to generate the required alignment.
 */

#if __has_attribute(aligned)
typedef int64_t __attribute__((__aligned__((sizeof(int64_t)))))
		OSAtomic_int64_aligned64_t;
#else
typedef int64_t OSAtomic_int64_aligned64_t;
#endif

/*! @group Arithmetic functions
    All functions in this group return the new value.
 */

/*! @abstract Atomically adds two 32-bit values.
    @discussion
	This function adds the value given by <code>__theAmount</code> to the
	value in the memory location referenced by <code>__theValue</code>,
 	storing the result back to that memory location atomically.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_add)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int32_t	OSAtomicAdd32( int32_t __theAmount, volatile int32_t *__theValue );


/*! @abstract Atomically adds two 32-bit values.
    @discussion
	This function adds the value given by <code>__theAmount</code> to the
	value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.

	This function is equivalent to {@link OSAtomicAdd32}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_add)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int32_t	OSAtomicAdd32Barrier( int32_t __theAmount, volatile int32_t *__theValue );


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_10 || __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_1

/*! @abstract Atomically increments a 32-bit value.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_add)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_1)
int32_t	OSAtomicIncrement32( volatile int32_t *__theValue );


/*! @abstract Atomically increments a 32-bit value with a barrier.
    @discussion
	This function is equivalent to {@link OSAtomicIncrement32}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_add)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_1)
int32_t	OSAtomicIncrement32Barrier( volatile int32_t *__theValue );


/*! @abstract Atomically decrements a 32-bit value.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_sub)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_1)
int32_t	OSAtomicDecrement32( volatile int32_t *__theValue );


/*! @abstract Atomically decrements a 32-bit value with a barrier.
    @discussion
	This function is equivalent to {@link OSAtomicDecrement32}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_sub)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_1)
int32_t	OSAtomicDecrement32Barrier( volatile int32_t *__theValue );

#else
__inline static
int32_t	OSAtomicIncrement32( volatile int32_t *__theValue )
            { return OSAtomicAdd32(  1, __theValue); }

__inline static
int32_t	OSAtomicIncrement32Barrier( volatile int32_t *__theValue )
            { return OSAtomicAdd32Barrier(  1, __theValue); }

__inline static
int32_t	OSAtomicDecrement32( volatile int32_t *__theValue )
            { return OSAtomicAdd32( -1, __theValue); }

__inline static
int32_t	OSAtomicDecrement32Barrier( volatile int32_t *__theValue )
            { return OSAtomicAdd32Barrier( -1, __theValue); }
#endif


/*! @abstract Atomically adds two 64-bit values.
    @discussion
	This function adds the value given by <code>__theAmount</code> to the
	value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_add)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int64_t	OSAtomicAdd64( int64_t __theAmount,
		volatile OSAtomic_int64_aligned64_t *__theValue );


/*! @abstract Atomically adds two 64-bit values with a barrier.
    @discussion
	This function adds the value given by <code>__theAmount</code> to the
	value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.

	This function is equivalent to {@link OSAtomicAdd64}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_add)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_3_2)
int64_t	OSAtomicAdd64Barrier( int64_t __theAmount,
		volatile OSAtomic_int64_aligned64_t *__theValue );


#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_10 || __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_1

/*! @abstract Atomically increments a 64-bit value.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_add)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_1)
int64_t	OSAtomicIncrement64( volatile OSAtomic_int64_aligned64_t *__theValue );


/*! @abstract Atomically increments a 64-bit value with a barrier.
    @discussion
	This function is equivalent to {@link OSAtomicIncrement64}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_add)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_1)
int64_t	OSAtomicIncrement64Barrier( volatile OSAtomic_int64_aligned64_t *__theValue );


/*! @abstract Atomically decrements a 64-bit value.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_sub)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_1)
int64_t	OSAtomicDecrement64( volatile OSAtomic_int64_aligned64_t *__theValue );


/*! @abstract Atomically decrements a 64-bit value with a barrier.
    @discussion
	This function is equivalent to {@link OSAtomicDecrement64}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_sub)
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_1)
int64_t	OSAtomicDecrement64Barrier( volatile OSAtomic_int64_aligned64_t *__theValue );

#else
__inline static
int64_t	OSAtomicIncrement64( volatile OSAtomic_int64_aligned64_t *__theValue )
            { return OSAtomicAdd64(  1, __theValue); }

__inline static
int64_t	OSAtomicIncrement64Barrier( volatile OSAtomic_int64_aligned64_t *__theValue )
            { return OSAtomicAdd64Barrier(  1, __theValue); }

__inline static
int64_t	OSAtomicDecrement64( volatile OSAtomic_int64_aligned64_t *__theValue )
            { return OSAtomicAdd64( -1, __theValue); }

__inline static
int64_t	OSAtomicDecrement64Barrier( volatile OSAtomic_int64_aligned64_t *__theValue )
            { return OSAtomicAdd64Barrier( -1, __theValue); }
#endif


/*! @group Boolean functions (AND, OR, XOR)
 *
 * @discussion Functions in this group come in four variants for each operation:
 * with and without barriers, and functions that return the original value or
 * the result value of the operation.
 *
 * The "Orig" versions return the original value, (before the operation); the non-Orig
 * versions return the value after the operation.  All are layered on top of
 * {@link OSAtomicCompareAndSwap32} and similar.
 */

/*! @abstract Atomic bitwise OR of two 32-bit values.
    @discussion
	This function performs the bitwise OR of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_or)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int32_t	OSAtomicOr32( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise OR of two 32-bit values with barrier.
    @discussion
	This function performs the bitwise OR of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.

	This function is equivalent to {@link OSAtomicOr32}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_or)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int32_t	OSAtomicOr32Barrier( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise OR of two 32-bit values returning original.
    @discussion
	This function performs the bitwise OR of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.
    @result Returns the original value referenced by <code>__theValue</code>.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_or)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_2)
int32_t	OSAtomicOr32Orig( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise OR of two 32-bit values returning original with barrier.
    @discussion
	This function performs the bitwise OR of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.
 
	This function is equivalent to {@link OSAtomicOr32Orig}
	except that it also introduces a barrier.
    @result Returns the original value referenced by <code>__theValue</code>.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_or)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_2)
int32_t	OSAtomicOr32OrigBarrier( uint32_t __theMask, volatile uint32_t *__theValue );




/*! @abstract Atomic bitwise AND of two 32-bit values.
    @discussion
	This function performs the bitwise AND of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_and)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int32_t	OSAtomicAnd32( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise AND of two 32-bit values with barrier.
    @discussion
	This function performs the bitwise AND of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.

	This function is equivalent to {@link OSAtomicAnd32}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_and)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int32_t	OSAtomicAnd32Barrier( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise AND of two 32-bit values returning original.
    @discussion
	This function performs the bitwise AND of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.
    @result Returns the original value referenced by <code>__theValue</code>.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_and)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_2)
int32_t	OSAtomicAnd32Orig( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise AND of two 32-bit values returning original with barrier.
    @discussion
	This function performs the bitwise AND of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.

	This function is equivalent to {@link OSAtomicAnd32Orig}
	except that it also introduces a barrier.
    @result Returns the original value referenced by <code>__theValue</code>.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_and)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_2)
int32_t	OSAtomicAnd32OrigBarrier( uint32_t __theMask, volatile uint32_t *__theValue );




/*! @abstract Atomic bitwise XOR of two 32-bit values.
    @discussion
	This function performs the bitwise XOR of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.
    @result Returns the new value.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_xor)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int32_t	OSAtomicXor32( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise XOR of two 32-bit values with barrier.
    @discussion
	This function performs the bitwise XOR of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.

	This function is equivalent to {@link OSAtomicXor32}
	except that it also introduces a barrier.
    @result Returns the new value.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_xor)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
int32_t	OSAtomicXor32Barrier( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise XOR of two 32-bit values returning original.
    @discussion
	This function performs the bitwise XOR of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.
    @result Returns the original value referenced by <code>__theValue</code>.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_xor)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_2)
int32_t	OSAtomicXor32Orig( uint32_t __theMask, volatile uint32_t *__theValue );


/*! @abstract Atomic bitwise XOR of two 32-bit values returning original with barrier.
    @discussion
	This function performs the bitwise XOR of the value given by <code>__theMask</code>
	with the value in the memory location referenced by <code>__theValue</code>,
	storing the result back to that memory location atomically.

	This function is equivalent to {@link OSAtomicXor32Orig}
	except that it also introduces a barrier.
    @result Returns the original value referenced by <code>__theValue</code>.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_xor)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_3_2)
int32_t	OSAtomicXor32OrigBarrier( uint32_t __theMask, volatile uint32_t *__theValue );
 

/*! @group Compare and swap
 * Functions in this group return true if the swap occured.  There are several versions,
 * depending on data type and on whether or not a barrier is used.
 */


/*! @abstract Compare and swap for 32-bit values.
    @discussion
	This function compares the value in <code>__oldValue</code> to the value
	in the memory location referenced by <code>__theValue</code>.  If the values
	match, this function stores the value from <code>__newValue</code> into
	that memory location atomically.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
bool    OSAtomicCompareAndSwap32( int32_t __oldValue, int32_t __newValue, volatile int32_t *__theValue );


/*! @abstract Compare and swap for 32-bit values with barrier.
    @discussion
	This function compares the value in <code>__oldValue</code> to the value
	in the memory location referenced by <code>__theValue</code>.  If the values
	match, this function stores the value from <code>__newValue</code> into
	that memory location atomically.

	This function is equivalent to {@link OSAtomicCompareAndSwap32}
	except that it also introduces a barrier.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
bool    OSAtomicCompareAndSwap32Barrier( int32_t __oldValue, int32_t __newValue, volatile int32_t *__theValue );


/*! @abstract Compare and swap pointers.
    @discussion
	This function compares the pointer stored in <code>__oldValue</code> to the pointer
	in the memory location referenced by <code>__theValue</code>.  If the pointers
	match, this function stores the pointer from <code>__newValue</code> into
	that memory location atomically.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0)
bool	OSAtomicCompareAndSwapPtr( void *__oldValue, void *__newValue, void * volatile *__theValue );


/*! @abstract Compare and swap pointers with barrier.
    @discussion
	This function compares the pointer stored in <code>__oldValue</code> to the pointer
	in the memory location referenced by <code>__theValue</code>.  If the pointers
	match, this function stores the pointer from <code>__newValue</code> into
	that memory location atomically.

	This function is equivalent to {@link OSAtomicCompareAndSwapPtr}
	except that it also introduces a barrier.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0)
bool	OSAtomicCompareAndSwapPtrBarrier( void *__oldValue, void *__newValue, void * volatile *__theValue );


/*! @abstract Compare and swap for <code>int</code> values.
    @discussion
	This function compares the value in <code>__oldValue</code> to the value
	in the memory location referenced by <code>__theValue</code>.  If the values
	match, this function stores the value from <code>__newValue</code> into
	that memory location atomically.

	This function is equivalent to {@link OSAtomicCompareAndSwap32}.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0)
bool	OSAtomicCompareAndSwapInt( int __oldValue, int __newValue, volatile int *__theValue );


/*! @abstract Compare and swap for <code>int</code> values.
    @discussion
	This function compares the value in <code>__oldValue</code> to the value
	in the memory location referenced by <code>__theValue</code>.  If the values
	match, this function stores the value from <code>__newValue</code> into
	that memory location atomically.

	This function is equivalent to {@link OSAtomicCompareAndSwapInt}
	except that it also introduces a barrier.

	This function is equivalent to {@link OSAtomicCompareAndSwap32Barrier}.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0)
bool	OSAtomicCompareAndSwapIntBarrier( int __oldValue, int __newValue, volatile int *__theValue );


/*! @abstract Compare and swap for <code>long</code> values.
    @discussion
	This function compares the value in <code>__oldValue</code> to the value
	in the memory location referenced by <code>__theValue</code>.  If the values
	match, this function stores the value from <code>__newValue</code> into
	that memory location atomically.

	This function is equivalent to {@link OSAtomicCompareAndSwap32} on 32-bit architectures, 
	or {@link OSAtomicCompareAndSwap64} on 64-bit architectures.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0)
bool	OSAtomicCompareAndSwapLong( long __oldValue, long __newValue, volatile long *__theValue );


/*! @abstract Compare and swap for <code>long</code> values.
    @discussion
	This function compares the value in <code>__oldValue</code> to the value
	in the memory location referenced by <code>__theValue</code>.  If the values
	match, this function stores the value from <code>__newValue</code> into
	that memory location atomically.

	This function is equivalent to {@link OSAtomicCompareAndSwapLong}
	except that it also introduces a barrier.

	This function is equivalent to {@link OSAtomicCompareAndSwap32} on 32-bit architectures, 
	or {@link OSAtomicCompareAndSwap64} on 64-bit architectures.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0)
bool	OSAtomicCompareAndSwapLongBarrier( long __oldValue, long __newValue, volatile long *__theValue );


/*! @abstract Compare and swap for <code>uint64_t</code> values.
    @discussion
	This function compares the value in <code>__oldValue</code> to the value
	in the memory location referenced by <code>__theValue</code>.  If the values
	match, this function stores the value from <code>__newValue</code> into
	that memory location atomically.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
bool    OSAtomicCompareAndSwap64( int64_t __oldValue, int64_t __newValue,
		volatile OSAtomic_int64_aligned64_t *__theValue );


/*! @abstract Compare and swap for <code>uint64_t</code> values.
    @discussion
	This function compares the value in <code>__oldValue</code> to the value
	in the memory location referenced by <code>__theValue</code>.  If the values
	match, this function stores the value from <code>__newValue</code> into
	that memory location atomically.

	This function is equivalent to {@link OSAtomicCompareAndSwap64}
	except that it also introduces a barrier.
    @result Returns TRUE on a match, FALSE otherwise.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_compare_exchange_strong)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_3_2)
bool    OSAtomicCompareAndSwap64Barrier( int64_t __oldValue, int64_t __newValue,
		volatile OSAtomic_int64_aligned64_t *__theValue );


/* Test and set.
 * They return the original value of the bit, and operate on bit (0x80>>(n&7))
 * in byte ((char*)theAddress + (n>>3)).
 */
/*! @abstract Atomic test and set
    @discussion
	This function tests a bit in the value referenced by
	<code>__theAddress</code> and if it is not set, sets it.

	The bit is chosen by the value of <code>__n</code> such that the
	operation will be performed on bit <code>(0x80 >> (__n & 7))</code>
	of byte <code>((char *)__theAddress + (n >> 3))</code>.

	For example, if <code>__theAddress</code> points to a 64-bit value,
	to compare the value of the most significant bit, you would specify
	<code>56</code> for <code>__n</code>.
    @result
	Returns the original value of the bit being tested.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_or)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
bool    OSAtomicTestAndSet( uint32_t __n, volatile void *__theAddress );


/*! @abstract Atomic test and set with barrier
    @discussion
	This function tests a bit in the value referenced by <code>__theAddress</code>
	and if it is not set, sets it.

	The bit is chosen by the value of <code>__n</code> such that the
	operation will be performed on bit <code>(0x80 >> (__n & 7))</code>
	of byte <code>((char *)__theAddress + (n >> 3))</code>.

	For example, if <code>__theAddress</code> points to a 64-bit value,
	to compare the value of the most significant bit, you would specify
	<code>56</code> for <code>__n</code>.

	This function is equivalent to {@link OSAtomicTestAndSet}
	except that it also introduces a barrier.
    @result
	Returns the original value of the bit being tested.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_or)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
bool    OSAtomicTestAndSetBarrier( uint32_t __n, volatile void *__theAddress );



/*! @abstract Atomic test and clear
    @discussion
	This function tests a bit in the value referenced by <code>__theAddress</code>
	and if it is not cleared, clears it.

	The bit is chosen by the value of <code>__n</code> such that the
	operation will be performed on bit <code>(0x80 >> (__n & 7))</code>
	of byte <code>((char *)__theAddress + (n >> 3))</code>.

	For example, if <code>__theAddress</code> points to a 64-bit value,
	to compare the value of the most significant bit, you would specify
	<code>56</code> for <code>__n</code>.
 
    @result
	Returns the original value of the bit being tested.
 */
OSATOMIC_DEPRECATED_REPLACE_WITH(atomic_fetch_and)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
bool    OSAtomicTestAndClear( uint32_t __n, volatile void *__theAddress );


/*! @abstract Atomic test and clear
    @discussion
	This function tests a bit in the value referenced by <code>__theAddress</code>
	and if it is not cleared, clears it.
 
	The bit is chosen by the value of <code>__n</code> such that the
	operation will be performed on bit <code>(0x80 >> (__n & 7))</code>
	of byte <code>((char *)__theAddress + (n >> 3))</code>.
 
	For example, if <code>__theAddress</code> points to a 64-bit value,
	to compare the value of the most significant bit, you would specify
	<code>56</code> for <code>__n</code>.
 
	This function is equivalent to {@link OSAtomicTestAndSet}
	except that it also introduces a barrier.
    @result
	Returns the original value of the bit being tested.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_fetch_and)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
bool    OSAtomicTestAndClearBarrier( uint32_t __n, volatile void *__theAddress );
 

/*! @group Memory barriers */

/*! @abstract Memory barrier.
    @discussion
	This function serves as both a read and write barrier.
 */
OSATOMIC_BARRIER_DEPRECATED_REPLACE_WITH(atomic_thread_fence)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
void    OSMemoryBarrier( void );

__END_DECLS

#else // defined(OSATOMIC_USE_INLINED) && OSATOMIC_USE_INLINED

/*
 * Inline implementations of the legacy OSAtomic interfaces in terms of
 * C11 <stdatomic.h> resp. C++11 <atomic> primitives.
 * Direct use of those primitives is preferred.
 */

#include <sys/cdefs.h>

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C++" {
#if !(__has_include(<atomic>) && __has_extension(cxx_atomic))
#error Cannot use inlined OSAtomic without <atomic> and C++11 atomics
#endif
#include <atomic>
typedef std::atomic<uint8_t> _OSAtomic_uint8_t;
typedef std::atomic<int32_t> _OSAtomic_int32_t;
typedef std::atomic<uint32_t> _OSAtomic_uint32_t;
typedef std::atomic<int64_t> _OSAtomic_int64_t;
typedef std::atomic<void*> _OSAtomic_void_ptr_t;
#define OSATOMIC_STD(_a) std::_a
__BEGIN_DECLS
#else
#if !(__has_include(<stdatomic.h>) && __has_extension(c_atomic))
#error Cannot use inlined OSAtomic without <stdatomic.h> and C11 atomics
#endif
#include <stdatomic.h>
typedef _Atomic(uint8_t) _OSAtomic_uint8_t;
typedef _Atomic(int32_t) _OSAtomic_int32_t;
typedef _Atomic(uint32_t) _OSAtomic_uint32_t;
typedef _Atomic(int64_t) _OSAtomic_int64_t;
typedef _Atomic(void*) _OSAtomic_void_ptr_t;
#define OSATOMIC_STD(_a) _a
#endif

#if __has_extension(c_alignof) && __has_attribute(aligned)
typedef int64_t __attribute__((__aligned__(_Alignof(_OSAtomic_int64_t))))
		OSAtomic_int64_aligned64_t;
#elif __has_attribute(aligned)
typedef int64_t __attribute__((__aligned__((sizeof(_OSAtomic_int64_t)))))
		OSAtomic_int64_aligned64_t;
#else
typedef int64_t OSAtomic_int64_aligned64_t;
#endif

#if __has_attribute(always_inline)
#define OSATOMIC_INLINE static __inline __attribute__((__always_inline__))
#else
#define OSATOMIC_INLINE static __inline
#endif

OSATOMIC_INLINE
int32_t
OSAtomicAdd32(int32_t __theAmount, volatile int32_t *__theValue)
{
	return (OSATOMIC_STD(atomic_fetch_add_explicit)(
			(volatile _OSAtomic_int32_t*) __theValue, __theAmount,
			OSATOMIC_STD(memory_order_relaxed)) + __theAmount);
}

OSATOMIC_INLINE
int32_t
OSAtomicAdd32Barrier(int32_t __theAmount, volatile int32_t *__theValue)
{
	return (OSATOMIC_STD(atomic_fetch_add_explicit)(
			(volatile _OSAtomic_int32_t*) __theValue, __theAmount,
			OSATOMIC_STD(memory_order_seq_cst)) + __theAmount);
}

OSATOMIC_INLINE
int32_t
OSAtomicIncrement32(volatile int32_t *__theValue)
{
	return OSAtomicAdd32(1, __theValue);
}

OSATOMIC_INLINE
int32_t
OSAtomicIncrement32Barrier(volatile int32_t *__theValue)
{
	return OSAtomicAdd32Barrier(1, __theValue);
}

OSATOMIC_INLINE
int32_t
OSAtomicDecrement32(volatile int32_t *__theValue)
{
	return OSAtomicAdd32(-1, __theValue);
}

OSATOMIC_INLINE
int32_t
OSAtomicDecrement32Barrier(volatile int32_t *__theValue)
{
	return OSAtomicAdd32Barrier(-1, __theValue);
}

OSATOMIC_INLINE
int64_t
OSAtomicAdd64(int64_t __theAmount,
		volatile OSAtomic_int64_aligned64_t *__theValue)
{
	return (OSATOMIC_STD(atomic_fetch_add_explicit)(
			(volatile _OSAtomic_int64_t*) __theValue, __theAmount,
			OSATOMIC_STD(memory_order_relaxed)) + __theAmount);
}

OSATOMIC_INLINE
int64_t
OSAtomicAdd64Barrier(int64_t __theAmount,
		volatile OSAtomic_int64_aligned64_t *__theValue)
{
	return (OSATOMIC_STD(atomic_fetch_add_explicit)(
			(volatile _OSAtomic_int64_t*) __theValue, __theAmount,
			OSATOMIC_STD(memory_order_seq_cst)) + __theAmount);
}

OSATOMIC_INLINE
int64_t
OSAtomicIncrement64(volatile OSAtomic_int64_aligned64_t *__theValue)
{
	return OSAtomicAdd64(1, __theValue);
}

OSATOMIC_INLINE
int64_t
OSAtomicIncrement64Barrier(volatile OSAtomic_int64_aligned64_t *__theValue)
{
	return OSAtomicAdd64Barrier(1, __theValue);
}

OSATOMIC_INLINE
int64_t
OSAtomicDecrement64(volatile OSAtomic_int64_aligned64_t *__theValue)
{
	return OSAtomicAdd64(-1, __theValue);
}

OSATOMIC_INLINE
int64_t
OSAtomicDecrement64Barrier(volatile OSAtomic_int64_aligned64_t *__theValue)
{
	return OSAtomicAdd64Barrier(-1, __theValue);
}

OSATOMIC_INLINE
int32_t
OSAtomicOr32(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_or_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_relaxed)) | __theMask);
}

OSATOMIC_INLINE
int32_t
OSAtomicOr32Barrier(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_or_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_seq_cst)) | __theMask);
}

OSATOMIC_INLINE
int32_t
OSAtomicOr32Orig(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_or_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
int32_t
OSAtomicOr32OrigBarrier(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_or_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_seq_cst)));
}

OSATOMIC_INLINE
int32_t
OSAtomicAnd32(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_and_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_relaxed)) & __theMask);
}

OSATOMIC_INLINE
int32_t
OSAtomicAnd32Barrier(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_and_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_seq_cst)) & __theMask);
}

OSATOMIC_INLINE
int32_t
OSAtomicAnd32Orig(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_and_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
int32_t
OSAtomicAnd32OrigBarrier(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_and_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_seq_cst)));
}

OSATOMIC_INLINE
int32_t
OSAtomicXor32(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_xor_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_relaxed)) ^ __theMask);
}

OSATOMIC_INLINE
int32_t
OSAtomicXor32Barrier(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_xor_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_seq_cst)) ^ __theMask);
}

OSATOMIC_INLINE
int32_t
OSAtomicXor32Orig(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_xor_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
int32_t
OSAtomicXor32OrigBarrier(uint32_t __theMask, volatile uint32_t *__theValue)
{
	return (int32_t)(OSATOMIC_STD(atomic_fetch_xor_explicit)(
			(volatile _OSAtomic_uint32_t*)__theValue, __theMask,
			OSATOMIC_STD(memory_order_seq_cst)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwap32(int32_t __oldValue, int32_t __newValue,
		volatile int32_t *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile _OSAtomic_int32_t*)__theValue, &__oldValue, __newValue,
			OSATOMIC_STD(memory_order_relaxed),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwap32Barrier(int32_t __oldValue, int32_t __newValue,
		volatile int32_t *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile _OSAtomic_int32_t*)__theValue, &__oldValue, __newValue,
			OSATOMIC_STD(memory_order_seq_cst),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwapPtr(void *__oldValue, void *__newValue,
		void * volatile *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile _OSAtomic_void_ptr_t*)__theValue, &__oldValue, __newValue,
			OSATOMIC_STD(memory_order_relaxed),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwapPtrBarrier(void *__oldValue, void *__newValue,
		void * volatile *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile _OSAtomic_void_ptr_t*)__theValue, &__oldValue, __newValue,
			OSATOMIC_STD(memory_order_seq_cst),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwapInt(int __oldValue, int __newValue,
		volatile int *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile OSATOMIC_STD(atomic_int)*)__theValue, &__oldValue,
			__newValue, OSATOMIC_STD(memory_order_relaxed),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwapIntBarrier(int __oldValue, int __newValue,
		volatile int *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile OSATOMIC_STD(atomic_int)*)__theValue, &__oldValue,
			__newValue, OSATOMIC_STD(memory_order_seq_cst),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwapLong(long __oldValue, long __newValue,
		volatile long *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile OSATOMIC_STD(atomic_long)*)__theValue, &__oldValue,
			__newValue, OSATOMIC_STD(memory_order_relaxed),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwapLongBarrier(long __oldValue, long __newValue,
		volatile long *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile OSATOMIC_STD(atomic_long)*)__theValue, &__oldValue,
			__newValue, OSATOMIC_STD(memory_order_seq_cst),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwap64(int64_t __oldValue, int64_t __newValue,
		volatile OSAtomic_int64_aligned64_t *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile _OSAtomic_int64_t*)__theValue, &__oldValue, __newValue,
			OSATOMIC_STD(memory_order_relaxed),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicCompareAndSwap64Barrier(int64_t __oldValue, int64_t __newValue,
		volatile OSAtomic_int64_aligned64_t *__theValue)
{
	return (OSATOMIC_STD(atomic_compare_exchange_strong_explicit)(
			(volatile _OSAtomic_int64_t*)__theValue, &__oldValue, __newValue,
			OSATOMIC_STD(memory_order_seq_cst),
			OSATOMIC_STD(memory_order_relaxed)));
}

OSATOMIC_INLINE
bool
OSAtomicTestAndSet(uint32_t __n, volatile void *__theAddress)
{
	uintptr_t a = (uintptr_t)__theAddress + (__n >> 3);
	uint8_t v = (0x80u >> (__n & 7));
	return (OSATOMIC_STD(atomic_fetch_or_explicit)((_OSAtomic_uint8_t*)a, v,
			OSATOMIC_STD(memory_order_relaxed)) & v);
}

OSATOMIC_INLINE
bool
OSAtomicTestAndSetBarrier(uint32_t __n, volatile void *__theAddress)
{
	uintptr_t a = (uintptr_t)__theAddress + (__n >> 3);
	uint8_t v = (0x80u >> (__n & 7));
	return (OSATOMIC_STD(atomic_fetch_or_explicit)((_OSAtomic_uint8_t*)a, v,
			OSATOMIC_STD(memory_order_seq_cst)) & v);
}

OSATOMIC_INLINE
bool
OSAtomicTestAndClear(uint32_t __n, volatile void *__theAddress)
{
	uintptr_t a = (uintptr_t)__theAddress + (__n >> 3);
	uint8_t v = (0x80u >> (__n & 7));
	return (OSATOMIC_STD(atomic_fetch_and_explicit)((_OSAtomic_uint8_t*)a,
			(uint8_t)~v, OSATOMIC_STD(memory_order_relaxed)) & v);
}

OSATOMIC_INLINE
bool
OSAtomicTestAndClearBarrier(uint32_t __n, volatile void *__theAddress)
{
	uintptr_t a = (uintptr_t)__theAddress + (__n >> 3);
	uint8_t v = (0x80u >> (__n & 7));
	return (OSATOMIC_STD(atomic_fetch_and_explicit)((_OSAtomic_uint8_t*)a,
			(uint8_t)~v, OSATOMIC_STD(memory_order_seq_cst)) & v);
}

OSATOMIC_INLINE
void
OSMemoryBarrier(void)
{
	OSATOMIC_STD(atomic_thread_fence)(OSATOMIC_STD(memory_order_seq_cst));
}

#undef OSATOMIC_INLINE
#undef OSATOMIC_STD
#ifdef __cplusplus
__END_DECLS
} // extern "C++"
#endif

#endif // defined(OSATOMIC_USE_INLINED) && OSATOMIC_USE_INLINED

#endif /* _OSATOMIC_DEPRECATED_H_ */