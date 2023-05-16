/*
 * Copyright (c) 2006 Apple Computer, Inc. All rights reserved.
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

#ifndef _OS_CACHE_CONTROL_H_
#define _OS_CACHE_CONTROL_H_

#include    <stddef.h>
#include    <sys/cdefs.h>
#include    <stdint.h>
#include    <Availability.h>

__BEGIN_DECLS


/* Functions performed by sys_cache_control(): */

/* Prepare memory for execution.  This should be called
 * after writing machine instructions to memory, before
 * executing them.  It syncs the dcache and icache.
 * On IA32 processors this function is a NOP, because
 * no synchronization is required.
 */
#define	kCacheFunctionPrepareForExecution	1

/* Flush data cache(s).  This ensures that cached data 
 * makes it all the way out to DRAM, and then removes
 * copies of the data from all processor caches.
 * It can be useful when dealing with cache incoherent
 * devices or DMA.
 */
#define	kCacheFunctionFlushDcache	2


/* perform one of the above cache functions: */
int	sys_cache_control( int function, void *start, size_t len) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
 
/* equivalent to sys_cache_control(kCacheFunctionPrepareForExecution): */
void	sys_icache_invalidate( void *start, size_t len) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

/* equivalent to sys_cache_control(kCacheFunctionFlushDcache): */
void	sys_dcache_flush( void *start, size_t len) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);


__END_DECLS

#endif /* _OS_CACHE_CONTROL_H_ */