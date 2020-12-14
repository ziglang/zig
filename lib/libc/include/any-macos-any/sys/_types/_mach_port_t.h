/*
 * Copyright (c) 2003-2012 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */

/*
 *	mach_port_t - a named port right
 *
 *	In user-space, "rights" are represented by the name of the
 *	right in the Mach port namespace.  Even so, this type is
 *	presented as a unique one to more clearly denote the presence
 *	of a right coming along with the name.
 *
 *	Often, various rights for a port held in a single name space
 *	will coalesce and are, therefore, be identified by a single name
 *	[this is the case for send and receive rights].  But not
 *	always [send-once rights currently get a unique name for
 *	each right].
 *
 *	This definition of mach_port_t is only for user-space.
 *
 */

#ifndef _MACH_PORT_T
#define _MACH_PORT_T
#include <sys/_types.h> /* __darwin_mach_port_t */
typedef __darwin_mach_port_t mach_port_t;
#endif /* _MACH_PORT_T */