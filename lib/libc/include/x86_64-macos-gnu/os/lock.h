/*
 * Copyright (c) 2016 Apple Inc. All rights reserved.
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

#ifndef __OS_LOCK__
#define __OS_LOCK__

#include <Availability.h>
#include <sys/cdefs.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <os/base.h>

OS_ASSUME_NONNULL_BEGIN

/*! @header
 * Low-level lock API.
 */

#define OS_LOCK_API_VERSION 20160309

__BEGIN_DECLS

#define OS_UNFAIR_LOCK_AVAILABILITY \
		__API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))

/*!
 * @typedef os_unfair_lock
 *
 * @abstract
 * Low-level lock that allows waiters to block efficiently on contention.
 *
 * In general, higher level synchronization primitives such as those provided by
 * the pthread or dispatch subsystems should be preferred.
 *
 * The values stored in the lock should be considered opaque and implementation
 * defined, they contain thread ownership information that the system may use
 * to attempt to resolve priority inversions.
 *
 * This lock must be unlocked from the same thread that locked it, attempts to
 * unlock from a different thread will cause an assertion aborting the process.
 *
 * This lock must not be accessed from multiple processes or threads via shared
 * or multiply-mapped memory, the lock implementation relies on the address of
 * the lock value and owning process.
 *
 * Must be initialized with OS_UNFAIR_LOCK_INIT
 *
 * @discussion
 * Replacement for the deprecated OSSpinLock. Does not spin on contention but
 * waits in the kernel to be woken up by an unlock.
 *
 * As with OSSpinLock there is no attempt at fairness or lock ordering, e.g. an
 * unlocker can potentially immediately reacquire the lock before a woken up
 * waiter gets an opportunity to attempt to acquire the lock. This may be
 * advantageous for performance reasons, but also makes starvation of waiters a
 * possibility.
 */
OS_UNFAIR_LOCK_AVAILABILITY
typedef struct os_unfair_lock_s {
	uint32_t _os_unfair_lock_opaque;
} os_unfair_lock, *os_unfair_lock_t;

#ifndef OS_UNFAIR_LOCK_INIT
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
#define OS_UNFAIR_LOCK_INIT ((os_unfair_lock){0})
#elif defined(__cplusplus) && __cplusplus >= 201103L
#define OS_UNFAIR_LOCK_INIT (os_unfair_lock{})
#elif defined(__cplusplus)
#define OS_UNFAIR_LOCK_INIT (os_unfair_lock())
#else
#define OS_UNFAIR_LOCK_INIT {0}
#endif
#endif // OS_UNFAIR_LOCK_INIT

/*!
 * @function os_unfair_lock_lock
 *
 * @abstract
 * Locks an os_unfair_lock.
 *
 * @param lock
 * Pointer to an os_unfair_lock.
 */
OS_UNFAIR_LOCK_AVAILABILITY
OS_EXPORT OS_NOTHROW OS_NONNULL_ALL
void os_unfair_lock_lock(os_unfair_lock_t lock);

/*!
 * @function os_unfair_lock_trylock
 *
 * @abstract
 * Locks an os_unfair_lock if it is not already locked.
 *
 * @discussion
 * It is invalid to surround this function with a retry loop, if this function
 * returns false, the program must be able to proceed without having acquired
 * the lock, or it must call os_unfair_lock_lock() directly (a retry loop around
 * os_unfair_lock_trylock() amounts to an inefficient implementation of
 * os_unfair_lock_lock() that hides the lock waiter from the system and prevents
 * resolution of priority inversions).
 *
 * @param lock
 * Pointer to an os_unfair_lock.
 *
 * @result
 * Returns true if the lock was succesfully locked and false if the lock was
 * already locked.
 */
OS_UNFAIR_LOCK_AVAILABILITY
OS_EXPORT OS_NOTHROW OS_WARN_RESULT OS_NONNULL_ALL
bool os_unfair_lock_trylock(os_unfair_lock_t lock);

/*!
 * @function os_unfair_lock_unlock
 *
 * @abstract
 * Unlocks an os_unfair_lock.
 *
 * @param lock
 * Pointer to an os_unfair_lock.
 */
OS_UNFAIR_LOCK_AVAILABILITY
OS_EXPORT OS_NOTHROW OS_NONNULL_ALL
void os_unfair_lock_unlock(os_unfair_lock_t lock);

/*!
 * @function os_unfair_lock_assert_owner
 *
 * @abstract
 * Asserts that the calling thread is the current owner of the specified
 * unfair lock.
 *
 * @discussion
 * If the lock is currently owned by the calling thread, this function returns.
 *
 * If the lock is unlocked or owned by a different thread, this function
 * asserts and terminates the process.
 *
 * @param lock
 * Pointer to an os_unfair_lock.
 */
OS_UNFAIR_LOCK_AVAILABILITY
OS_EXPORT OS_NOTHROW OS_NONNULL_ALL
void os_unfair_lock_assert_owner(os_unfair_lock_t lock);

/*!
 * @function os_unfair_lock_assert_not_owner
 *
 * @abstract
 * Asserts that the calling thread is not the current owner of the specified
 * unfair lock.
 *
 * @discussion
 * If the lock is unlocked or owned by a different thread, this function
 * returns.
 *
 * If the lock is currently owned by the current thread, this function asserts
 * and terminates the process.
 *
 * @param lock
 * Pointer to an os_unfair_lock.
 */
OS_UNFAIR_LOCK_AVAILABILITY
OS_EXPORT OS_NOTHROW OS_NONNULL_ALL
void os_unfair_lock_assert_not_owner(os_unfair_lock_t lock);

__END_DECLS

OS_ASSUME_NONNULL_END

#endif // __OS_LOCK__
