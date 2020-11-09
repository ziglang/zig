/*
 * Copyright (c) 2000-2005 Apple Computer, Inc. All rights reserved.
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
 * @OSF_COPYRIGHT@
 */
/*
 * Mach Operating System
 * Copyright (c) 1991,1990,1989 Carnegie Mellon University
 * All Rights Reserved.
 *
 * Permission to use, copy, modify and distribute this software and its
 * documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND FOR
 * ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie Mellon
 * the rights to redistribute these changes.
 */
/*
 */

#ifndef _I386_EFLAGS_H_
#define _I386_EFLAGS_H_

/*
 *	i386 flags register
 */

#ifndef EFL_CF
#define EFL_CF          0x00000001              /* carry */
#define EFL_PF          0x00000004              /* parity of low 8 bits */
#define EFL_AF          0x00000010              /* carry out of bit 3 */
#define EFL_ZF          0x00000040              /* zero */
#define EFL_SF          0x00000080              /* sign */
#define EFL_TF          0x00000100              /* trace trap */
#define EFL_IF          0x00000200              /* interrupt enable */
#define EFL_DF          0x00000400              /* direction */
#define EFL_OF          0x00000800              /* overflow */
#define EFL_IOPL        0x00003000              /* IO privilege level: */
#define EFL_IOPL_KERNEL 0x00000000                      /* kernel */
#define EFL_IOPL_USER   0x00003000                      /* user */
#define EFL_NT          0x00004000              /* nested task */
#define EFL_RF          0x00010000              /* resume without tracing */
#define EFL_VM          0x00020000              /* virtual 8086 mode */
#define EFL_AC          0x00040000              /* alignment check */
#define EFL_VIF         0x00080000              /* virtual interrupt flag */
#define EFL_VIP         0x00100000              /* virtual interrupt pending */
#define EFL_ID          0x00200000              /* cpuID instruction */
#endif

#define EFL_CLR         0xfff88028
#define EFL_SET         0x00000002

#define EFL_USER_SET    (EFL_IF)
#define EFL_USER_CLEAR  (EFL_IOPL|EFL_NT|EFL_RF)

#endif  /* _I386_EFLAGS_H_ */
