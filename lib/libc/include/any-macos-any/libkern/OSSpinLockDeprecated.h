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

#ifndef _OSSPINLOCK_DEPRECATED_H_
#define _OSSPINLOCK_DEPRECATED_H_

/*! @header
 * These are deprecated legacy interfaces for userspace spinlocks.
 *
 * These interfaces should no longer be used, particularily in situations where
 * threads of differing priorities may contend on the same spinlock.
 *
 * The interfaces in <os/lock.h> should be used instead in cases where a very
 * low-level lock primitive is required. In general however, using higher level
 * synchronization primitives such as those provided by the pthread or dispatch
 * subsystems should be preferred.
 *
 * Define OSSPINLOCK_USE_INLINED=1 to get inline implementations of these
 * interfaces in terms of the <os/lock.h> primitives. This is intended as a
 * transition convenience, direct use of those primitives is preferred.
 */

#ifndef OSSPINLOCK_DEPRECATED
#define OSSPINLOCK_DEPRECATED 1
#define OSSPINLOCK_DEPRECATED_MSG(_r) "Use " #_r "() from <os/lock.h> instead"
#define OSSPINLOCK_DEPRECATED_REPLACE_WITH(_r) \
	__OS_AVAILABILITY_MSG(macosx, deprecated=10.12, OSSPINLOCK_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(ios, deprecated=10.0, OSSPINLOCK_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(tvos, deprecated=10.0, OSSPINLOCK_DEPRECATED_MSG(_r)) \
	__OS_AVAILABILITY_MSG(watchos, deprecated=3.0, OSSPINLOCK_DEPRECATED_MSG(_r))
#else
#undef OSSPINLOCK_DEPRECATED
#define OSSPINLOCK_DEPRECATED 0
#define OSSPINLOCK_DEPRECATED_REPLACE_WITH(_r)
#endif

#if !(defined(OSSPINLOCK_USE_INLINED) && OSSPINLOCK_USE_INLINED)

#include    <sys/cdefs.h>
#include    <stddef.h>
#include    <stdint.h>
#include    <stdbool.h>
#include    <Availability.h>

__BEGIN_DECLS

/*! @abstract The default value for an <code>OSSpinLock</code>.
    @discussion
	The convention is that unlocked is zero, locked is nonzero.
 */
#define	OS_SPINLOCK_INIT    0


/*! @abstract Data type for a spinlock.
    @discussion
	You should always initialize a spinlock to {@link OS_SPINLOCK_INIT} before
	using it.
 */
typedef int32_t OSSpinLock OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock);


/*! @abstract Locks a spinlock if it would not block
    @result
	Returns <code>false</code> if the lock was already held by another thread,
	<code>true</code> if it took the lock successfully.
 */
OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock_trylock)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
bool    OSSpinLockTry( volatile OSSpinLock *__lock );


/*! @abstract Locks a spinlock
    @discussion
	Although the lock operation spins, it employs various strategies to back
	off if the lock is held.
 */
OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock_lock)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
void    OSSpinLockLock( volatile OSSpinLock *__lock );


/*! @abstract Unlocks a spinlock */
OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock_unlock)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0)
void    OSSpinLockUnlock( volatile OSSpinLock *__lock );

__END_DECLS

#else /* OSSPINLOCK_USE_INLINED */

/*
 * Inline implementations of the legacy OSSpinLock interfaces in terms of the
 * of the <os/lock.h> primitives. Direct use of those primitives is preferred.
 *
 * NOTE: the locked value of os_unfair_lock is implementation defined and
 * subject to change, code that relies on the specific locked value used by the
 * legacy OSSpinLock interface WILL break when using these inline
 * implementations in terms of os_unfair_lock.
 */

#if !OSSPINLOCK_USE_INLINED_TRANSPARENT

#include <os/lock.h>

__BEGIN_DECLS

#if __has_attribute(always_inline)
#define OSSPINLOCK_INLINE static __inline
#else
#define OSSPINLOCK_INLINE static __inline __attribute__((__always_inline__))
#endif

#define OS_SPINLOCK_INIT 0
typedef int32_t OSSpinLock;

#if  __has_extension(c_static_assert)
_Static_assert(sizeof(OSSpinLock) == sizeof(os_unfair_lock),
		"Incompatible os_unfair_lock type");
#endif

OSSPINLOCK_INLINE
void
OSSpinLockLock(volatile OSSpinLock *__lock)
{
	os_unfair_lock_t lock = (os_unfair_lock_t)__lock;
	return os_unfair_lock_lock(lock);
}

OSSPINLOCK_INLINE
bool
OSSpinLockTry(volatile OSSpinLock *__lock)
{
	os_unfair_lock_t lock = (os_unfair_lock_t)__lock;
	return os_unfair_lock_trylock(lock);
}

OSSPINLOCK_INLINE
void
OSSpinLockUnlock(volatile OSSpinLock *__lock)
{
	os_unfair_lock_t lock = (os_unfair_lock_t)__lock;
	return os_unfair_lock_unlock(lock);
}

#undef OSSPINLOCK_INLINE

__END_DECLS

#else /* OSSPINLOCK_USE_INLINED_TRANSPARENT */

#include    <sys/cdefs.h>
#include    <stddef.h>
#include    <stdint.h>
#include    <stdbool.h>
#include    <Availability.h>

#define OS_NOSPIN_LOCK_AVAILABILITY \
		__OSX_AVAILABLE(10.12) __IOS_AVAILABLE(10.0) \
		__TVOS_AVAILABLE(10.0) __WATCHOS_AVAILABLE(3.0)

__BEGIN_DECLS

#define OS_SPINLOCK_INIT 0
typedef int32_t OSSpinLock OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock);
typedef volatile OSSpinLock *_os_nospin_lock_t
		OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock_t);

OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock_lock)
OS_NOSPIN_LOCK_AVAILABILITY
void _os_nospin_lock_lock(_os_nospin_lock_t lock);
#undef OSSpinLockLock
#define OSSpinLockLock(lock) _os_nospin_lock_lock(lock)

OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock_trylock)
OS_NOSPIN_LOCK_AVAILABILITY
bool _os_nospin_lock_trylock(_os_nospin_lock_t lock);
#undef OSSpinLockTry
#define OSSpinLockTry(lock) _os_nospin_lock_trylock(lock)

OSSPINLOCK_DEPRECATED_REPLACE_WITH(os_unfair_lock_unlock)
OS_NOSPIN_LOCK_AVAILABILITY
void _os_nospin_lock_unlock(_os_nospin_lock_t lock);
#undef OSSpinLockUnlock
#define OSSpinLockUnlock(lock) _os_nospin_lock_unlock(lock)

__END_DECLS

#endif /* OSSPINLOCK_USE_INLINED_TRANSPARENT */

#endif /* OSSPINLOCK_USE_INLINED */

#endif /* _OSSPINLOCK_DEPRECATED_H_ */
