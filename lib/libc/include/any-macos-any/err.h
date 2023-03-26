/*
 * Copyright (c) 2000, 2003, 2004, 2008 Apple Inc. All rights reserved.
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
/*-
 * Copyright (c) 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *
 *	@(#)err.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _ERR_H_
#define	_ERR_H_

/*
 * Don't use va_list in the err/warn prototypes.   Va_list is typedef'd in two
 * places (<machine/varargs.h> and <machine/stdarg.h>), so if we include one
 * of them here we may collide with the utility's includes.  It's unreasonable
 * for utilities to have to include one of them to include err.h, so we get
 * __darwin_va_list from <machine/_type.h> and use it.
 */
#include <sys/cdefs.h>
#include <_types.h>
#include <Availability.h>

__BEGIN_DECLS
void	err(int, const char *, ...) __cold __dead2 __printflike(2, 3);
void	verr(int, const char *, __darwin_va_list) __cold __dead2 __printflike(2, 0);
void	errc(int, int, const char *, ...) __cold __dead2 __printflike(3, 4);
void	verrc(int, int, const char *, __darwin_va_list) __cold __dead2 __printflike(3, 0);
void	errx(int, const char *, ...) __cold __dead2 __printflike(2, 3);
void	verrx(int, const char *, __darwin_va_list) __cold __dead2 __printflike(2, 0);
void	warn(const char *, ...) __cold __printflike(1, 2);
void	vwarn(const char *, __darwin_va_list) __cold __printflike(1, 0);
void	warnc(int, const char *, ...) __cold __printflike(2, 3);
void	vwarnc(int, const char *, __darwin_va_list) __cold __printflike(2, 0);
void	warnx(const char *, ...) __cold __printflike(1, 2);
void	vwarnx(const char *, __darwin_va_list) __cold __printflike(1, 0);
void	err_set_file(void *);
void	err_set_exit(void (* _Nullable)(int));
#ifdef __BLOCKS__
void	err_set_exit_b(void (^ _Nullable)(int)) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#endif /* __BLOCKS__ */

__END_DECLS

#endif /* !_ERR_H_ */