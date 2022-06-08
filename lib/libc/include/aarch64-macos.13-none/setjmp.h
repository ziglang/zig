/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
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
#ifndef _BSD_SETJMP_H
#define _BSD_SETJMP_H

#include <sys/cdefs.h>
#include <Availability.h>

#if defined(__x86_64__)
/*
 * _JBLEN is number of ints required to save the following:
 * rflags, rip, rbp, rsp, rbx, r12, r13, r14, r15... these are 8 bytes each
 * mxcsr, fp control word, sigmask... these are 4 bytes each
 * add 16 ints for future expansion needs...
 */
#define _JBLEN ((9 * 2) + 3 + 16)
typedef int jmp_buf[_JBLEN];
typedef int sigjmp_buf[_JBLEN + 1];

#elif defined(__i386__)

/*
 * _JBLEN is number of ints required to save the following:
 * eax, ebx, ecx, edx, edi, esi, ebp, esp, ss, eflags, eip,
 * cs, de, es, fs, gs == 16 ints
 * onstack, mask = 2 ints
 */

#define _JBLEN (18)
typedef int jmp_buf[_JBLEN];
typedef int sigjmp_buf[_JBLEN + 1];

#elif defined(__arm__) && !defined(__ARM_ARCH_7K__)

#include <machine/signal.h>

/*
 *	_JBLEN is number of ints required to save the following:
 *	r4-r8, r10, fp, sp, lr, sig  == 10 register_t sized
 *	s16-s31 == 16 register_t sized + 1 int for FSTMX
 *	1 extra int for future use
 */
#define _JBLEN		(10 + 16 + 2)
#define _JBLEN_MAX	_JBLEN

typedef int jmp_buf[_JBLEN];
typedef int sigjmp_buf[_JBLEN + 1];

#elif defined(__arm64__) || defined(__ARM_ARCH_7K__)
/*
 * _JBLEN is the number of ints required to save the following:
 * r21-r29, sp, fp, lr == 12 registers, 8 bytes each. d8-d15
 * are another 8 registers, each 8 bytes long. (aapcs64 specifies
 * that only 64-bit versions of FP registers need to be saved).
 * Finally, two 8-byte fields for signal handling purposes.
 */
#define _JBLEN		((14 + 8 + 2) * 2)

typedef int jmp_buf[_JBLEN];
typedef int sigjmp_buf[_JBLEN + 1];

#else
#	error Undefined platform for setjmp
#endif

__BEGIN_DECLS
extern int	setjmp(jmp_buf);
extern void longjmp(jmp_buf, int) __dead2;

#ifndef _ANSI_SOURCE
int	_setjmp(jmp_buf);
void	_longjmp(jmp_buf, int) __dead2;
int	sigsetjmp(sigjmp_buf, int);
void	siglongjmp(sigjmp_buf, int) __dead2;
#endif /* _ANSI_SOURCE  */

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
void	longjmperror(void);
#endif /* neither ANSI nor POSIX */
__END_DECLS

#endif /* _BSD_SETJMP_H */