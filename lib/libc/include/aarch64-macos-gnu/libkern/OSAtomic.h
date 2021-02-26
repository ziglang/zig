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

#ifndef _OSATOMIC_H_
#define _OSATOMIC_H_

/*! @header
 * These are deprecated legacy interfaces for atomic and synchronization
 * operations.
 *
 * Define OSATOMIC_USE_INLINED=1 to get inline implementations of the
 * OSAtomic interfaces in terms of the <stdatomic.h> primitives.
 *
 * Define OSSPINLOCK_USE_INLINED=1 to get inline implementations of the
 * OSSpinLock interfaces in terms of the <os/lock.h> primitives.
 *
 * These are intended as a transition convenience, direct use of those
 * primitives should be preferred.
 */

#include <sys/cdefs.h>

#include "OSAtomicDeprecated.h"
#include "OSSpinLockDeprecated.h"
#include "OSAtomicQueue.h"

#endif /* _OSATOMIC_H_ */