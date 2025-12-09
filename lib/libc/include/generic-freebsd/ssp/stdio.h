/*	$NetBSD: stdio.h,v 1.5 2011/07/17 20:54:34 joerg Exp $	*/

/*-
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
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
#if __SSP_FORTIFY_LEVEL > 0
#if __POSIX_VISIBLE
__ssp_redirect_raw(char *, ctermid, ctermid, (char *__buf), (__buf),
    __buf != NULL, __ssp_bos, L_ctermid);
#if __BSD_VISIBLE
__ssp_redirect_raw(char *, ctermid_r, ctermid_r, (char *__buf), (__buf),
    __buf != NULL, __ssp_bos, L_ctermid);
#endif /* __BSD_VISIBLE */
#endif /* __POSIX_VISIBLE */
__ssp_redirect(size_t, fread, (void *__restrict __buf, size_t __len,
    size_t __nmemb, FILE *__restrict __fp), (__buf, __len, __nmemb, __fp));
__ssp_redirect(size_t, fread_unlocked, (void *__restrict __buf, size_t __len,
    size_t __nmemb, FILE *__restrict __fp), (__buf, __len, __nmemb, __fp));
#if __EXT1_VISIBLE
__ssp_redirect(char *, gets_s, (char *__buf, rsize_t __len), (__buf, __len));
#endif /* __EXT1_VISIBLE */
__ssp_redirect_raw(char *, tmpnam, tmpnam, (char *__buf), (__buf), 1,
    __ssp_bos, L_tmpnam);
#endif

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
char *__fgets_chk(char *, int, size_t, FILE *);
__END_DECLS

#if __SSP_FORTIFY_LEVEL > 0

#define sprintf(str, ...) __extension__ ({	\
    char *_ssp_str = (str);	\
    __builtin___sprintf_chk(_ssp_str, 0, __ssp_bos(_ssp_str),		\
        __VA_ARGS__); \
})

#define vsprintf(str, fmt, ap) __extension__ ({	\
    char *_ssp_str = (str);		\
    __builtin___vsprintf_chk(_ssp_str, 0, __ssp_bos(_ssp_str), fmt,	\
        ap);				\
})

#define snprintf(str, len, ...) __extension__ ({	\
    char *_ssp_str = (str);		\
    __builtin___snprintf_chk(_ssp_str, len, 0, __ssp_bos(_ssp_str),	\
        __VA_ARGS__);			\
})

#define vsnprintf(str, len, fmt, ap) __extension__ ({	\
    char *_ssp_str = (str);		\
    __builtin___vsnprintf_chk(_ssp_str, len, 0, __ssp_bos(_ssp_str),	\
        fmt, ap);			\
})

#define fgets(str, len, fp) __extension__ ({		\
    char *_ssp_str = (str);		\
    __fgets_chk(_ssp_str, len, __ssp_bos(_ssp_str), fp);	\
})

#endif /* __SSP_FORTIFY_LEVEL > 0 */

#endif /* _SSP_STDIO_H_ */