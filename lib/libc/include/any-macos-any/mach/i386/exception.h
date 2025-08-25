/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
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
 * Copyright (c) 1991,1990,1989,1988 Carnegie Mellon University
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

#ifndef _MACH_I386_EXCEPTION_H_
#define _MACH_I386_EXCEPTION_H_

#if defined (__i386__) || defined (__x86_64__)

/*
 * No machine dependent types for the 80386
 */

#define EXC_TYPES_COUNT 14      /* incl. illegal exception 0 */

/*
 *	Codes and subcodes for 80386 exceptions.
 */

#define EXCEPTION_CODE_MAX      2       /* currently code and subcode */

/*
 *	EXC_BAD_INSTRUCTION
 */

#define EXC_I386_INVOP                  1

/*
 *	EXC_ARITHMETIC
 */

#define EXC_I386_DIV                    1
#define EXC_I386_INTO                   2
#define EXC_I386_NOEXT                  3
#define EXC_I386_EXTOVR                 4
#define EXC_I386_EXTERR                 5
#define EXC_I386_EMERR                  6
#define EXC_I386_BOUND                  7
#define EXC_I386_SSEEXTERR              8

/*
 *	EXC_SOFTWARE
 *	Note: 0x10000-0x10003 in use for unix signal
 */

/*
 *	EXC_BAD_ACCESS
 */

/*
 *	EXC_BREAKPOINT
 */

#define EXC_I386_SGL                    1
#define EXC_I386_BPT                    2

#define EXC_I386_DIVERR         0       /* divide by 0 eprror		*/
#define EXC_I386_SGLSTP         1       /* single step			*/
#define EXC_I386_NMIFLT         2       /* NMI				*/
#define EXC_I386_BPTFLT         3       /* breakpoint fault		*/
#define EXC_I386_INTOFLT        4       /* INTO overflow fault		*/
#define EXC_I386_BOUNDFLT       5       /* BOUND instruction fault	*/
#define EXC_I386_INVOPFLT       6       /* invalid opcode fault		*/
#define EXC_I386_NOEXTFLT       7       /* extension not available fault*/
#define EXC_I386_DBLFLT         8       /* double fault			*/
#define EXC_I386_EXTOVRFLT      9       /* extension overrun fault	*/
#define EXC_I386_INVTSSFLT      10      /* invalid TSS fault		*/
#define EXC_I386_SEGNPFLT       11      /* segment not present fault	*/
#define EXC_I386_STKFLT         12      /* stack fault			*/
#define EXC_I386_GPFLT          13      /* general protection fault	*/
#define EXC_I386_PGFLT          14      /* page fault			*/
#define EXC_I386_EXTERRFLT      16      /* extension error fault	*/
#define EXC_I386_ALIGNFLT       17      /* Alignment fault */
#define EXC_I386_ENDPERR        33      /* emulated extension error flt	*/
#define EXC_I386_ENOEXTFLT      32      /* emulated ext not present	*/


/*
 *	machine dependent exception masks
 */
#define EXC_MASK_MACHINE        0

#endif /* defined (__i386__) || defined (__x86_64__) */

#endif  /* _MACH_I386_EXCEPTION_H_ */
