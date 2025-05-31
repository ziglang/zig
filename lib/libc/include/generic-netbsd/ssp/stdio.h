/*	$NetBSD: stdio.h,v 1.5 2011/07/17 20:54:34 joerg Exp $	*/

/*-
 * Copyright (c) 2006 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christos Zoulas.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef _SSP_STDIO_H_
#define _SSP_STDIO_H_

#include <ssp/ssp.h>

__BEGIN_DECLS
int __sprintf_chk(char *__restrict, int, size_t, const char *__restrict, ...)
    __printflike(4, 5);
int __vsprintf_chk(char *__restrict, int, size_t, const char *__restrict,
    __va_list)
    __printflike(4, 0);
int __snprintf_chk(char *__restrict, size_t, int, size_t,
    const char *__restrict, ...)
    __printflike(5, 6);
int __vsnprintf_chk(char *__restrict, size_t, int, size_t,
     const char *__restrict, __va_list)
    __printflike(5, 0);
char *__gets_chk(char *, size_t);
char *__fgets_chk(char *, int, size_t, FILE *);
__END_DECLS

#if __SSP_FORTIFY_LEVEL > 0


#define sprintf(str, ...) \
    __builtin___sprintf_chk(str, 0, __ssp_bos(str), __VA_ARGS__)

#define vsprintf(str, fmt, ap) \
    __builtin___vsprintf_chk(str, 0, __ssp_bos(str), fmt, ap)

#define snprintf(str, len, ...) \
    __builtin___snprintf_chk(str, len, 0, __ssp_bos(str), __VA_ARGS__)

#define vsnprintf(str, len, fmt, ap) \
    __builtin___vsnprintf_chk(str, len, 0, __ssp_bos(str), fmt, ap)

#define gets(str) \
    __gets_chk(str, __ssp_bos(str))

#define fgets(str, len, fp) \
    __fgets_chk(str, len, __ssp_bos(str), fp)
#endif /* __SSP_FORTIFY_LEVEL > 0 */

#endif /* _SSP_STDIO_H_ */