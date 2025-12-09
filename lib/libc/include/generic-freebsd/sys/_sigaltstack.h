/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1989, 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS__SIGALTSTACK_H_
#define	_SYS__SIGALTSTACK_H_

#include <sys/_types.h>

#if __XSI_VISIBLE
#if __BSD_VISIBLE
#define	__stack_t sigaltstack
#endif
typedef	struct __stack_t stack_t;

#define	SS_ONSTACK	0x0001	/* take signal on alternate stack */
#define	SS_DISABLE	0x0004	/* disable taking signals on alternate stack */
#define	MINSIGSTKSZ	__MINSIGSTKSZ		/* minimum stack size */
#define	SIGSTKSZ	(MINSIGSTKSZ + 32768)	/* recommended stack size */
#endif

/*
 * Structure used in sigaltstack call.  Its definition is always
 * needed for __ucontext.  If __BSD_VISIBLE is defined, the structure
 * tag is actually sigaltstack.
 */
struct __stack_t {
	void	*ss_sp;			/* signal stack base */
	__size_t ss_size;		/* signal stack length */
	int	ss_flags;		/* SS_DISABLE and/or SS_ONSTACK */
};

#endif /* !_SYS__SIGALTSTACK_H_ */