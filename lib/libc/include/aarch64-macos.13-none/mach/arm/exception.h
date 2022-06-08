/*
 * Copyright (c) 2007 Apple Inc. All rights reserved.
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

#ifndef _MACH_ARM_EXCEPTION_H_
#define _MACH_ARM_EXCEPTION_H_

#if defined (__arm__) || defined (__arm64__)

#define EXC_TYPES_COUNT         14      /* incl. illegal exception 0 */

#define EXC_MASK_MACHINE         0

#define EXCEPTION_CODE_MAX       2      /*  code and subcode */


/*
 *	Trap numbers as defined by the hardware exception vectors.
 */

/*
 *      EXC_BAD_INSTRUCTION
 */

#define EXC_ARM_UNDEFINED       1       /* Undefined */

/*
 *      EXC_ARITHMETIC
 */

#define EXC_ARM_FP_UNDEFINED    0       /* Undefined Floating Point Exception */
#define EXC_ARM_FP_IO           1       /* Invalid Floating Point Operation */
#define EXC_ARM_FP_DZ           2       /* Floating Point Divide by Zero */
#define EXC_ARM_FP_OF           3       /* Floating Point Overflow */
#define EXC_ARM_FP_UF           4       /* Floating Point Underflow */
#define EXC_ARM_FP_IX           5       /* Inexact Floating Point Result */
#define EXC_ARM_FP_ID           6       /* Floating Point Denormal Input */

/*
 *      EXC_BAD_ACCESS
 *      Note: do not conflict with kern_return_t values returned by vm_fault
 */

#define EXC_ARM_DA_ALIGN        0x101   /* Alignment Fault */
#define EXC_ARM_DA_DEBUG        0x102   /* Debug (watch/break) Fault */
#define EXC_ARM_SP_ALIGN        0x103   /* SP Alignment Fault */
#define EXC_ARM_SWP             0x104   /* SWP instruction */
#define EXC_ARM_PAC_FAIL        0x105   /* PAC authentication failure */

/*
 *	EXC_BREAKPOINT
 */

#define EXC_ARM_BREAKPOINT      1       /* breakpoint trap */

#endif /* defined (__arm__) || defined (__arm64__) */

#endif  /* _MACH_ARM_EXCEPTION_H_ */