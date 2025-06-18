/*-
 * SPDX-License-Identifier: MIT-CMU
 *
 * Copyright (c) 1994, 1995, 1996 Carnegie-Mellon University.
 * All rights reserved.
 *
 * Author: Chris G. Demetriou
 * 
 * Permission to use, copy, modify and distribute this software and
 * its documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 * 
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS" 
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND 
 * FOR ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 * 
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie the
 * rights to redistribute these changes.
 *
 *	from: NetBSD: profile.h,v 1.9 1997/04/06 08:47:37 cgd Exp
 *	from: FreeBSD: src/sys/alpha/include/profile.h,v 1.4 1999/12/29
 */

#ifdef __arm__
#include <arm/profile.h>
#else /* !__arm__ */

#ifndef _MACHINE_PROFILE_H_
#define	_MACHINE_PROFILE_H_

#define	FUNCTION_ALIGNMENT	32

typedef u_long	fptrdiff_t;

#ifndef _KERNEL

#include <sys/cdefs.h>

typedef __uintfptr_t    uintfptr_t;

#define	_MCOUNT_DECL \
static void _mcount(uintfptr_t frompc, uintfptr_t selfpc) __used; \
static void _mcount

/*
 * Call into _mcount. On arm64 the .mcount is a function so callers will
 * handle caller saved registers. As we don't directly touch any callee
 * saved registers we can just load the two arguments and use a tail call
 * into the MI _mcount function.
 *
 * When building with gcc frompc will be in x0, however this is not the
 * case on clang. As such we need to load it from the stack. As long as
 * the caller follows the ABI this will load the correct value.
 */
#define	MCOUNT __asm(					\
"	.text					\n"	\
"	.align	6				\n"	\
"	.type	.mcount,#function		\n"	\
"	.globl	.mcount				\n"	\
"	.mcount:				\n"	\
"	.cfi_startproc				\n"	\
	/* Allow this to work with BTI, see BTI_C in asm.h */ \
"	hint	#34				\n"	\
	/* Load the caller return address as frompc */	\
"	ldr	x0, [x29, #8]			\n"	\
	/* Use our return address as selfpc */		\
"	mov	x1, lr				\n"	\
"	b	_mcount				\n"	\
"	.cfi_endproc				\n"	\
"	.size	.mcount, . - .mcount		\n"	\
	);
#if 0
/*
 * If clang passed frompc correctly we could implement it like this, however
 * all clang versions we care about would need to be fixed before we could
 * make this change.
 */
void
mcount(uintfptr_t frompc)
{
	_mcount(frompc, __builtin_return_address(0));
}
#endif

#endif /* !_KERNEL */

#endif /* !_MACHINE_PROFILE_H_ */

#endif /* !__arm__ */