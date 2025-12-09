/*	$NetBSD: strings.h,v 1.3 2008/04/28 20:22:54 martin Exp $	*/

/*-
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2007 The NetBSD Foundation, Inc.
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
#ifndef _SSP_STRINGS_H_
#define _SSP_STRINGS_H_

#include <ssp/ssp.h>
#include <string.h>

#if __SSP_FORTIFY_LEVEL > 0

#define _ssp_bcopy(srcvar, src, dstvar, dst, lenvar,  len) __extension__ ({ \
    const void *srcvar = (src);			\
    void *dstvar = (dst);			\
    size_t lenvar = (len);			\
    ((__ssp_bos0(dstvar) != (size_t)-1) ?	\
    __builtin___memmove_chk(dstvar, srcvar, lenvar,	\
        __ssp_bos0(dstvar)) :			\
    __memmove_ichk(dstvar, srcvar, lenvar));	\
})

#define	bcopy(src, dst, len)			\
    _ssp_bcopy(__ssp_var(srcv), src, __ssp_var(dstv), dst, __ssp_var(lenv), len)

#define _ssp_bzero(dstvar, dst, lenvar, len) __extension__ ({		\
    void *dstvar = (dst);			\
    size_t lenvar = (len);			\
    ((__ssp_bos0(dstvar) != (size_t)-1) ?	\
    __builtin___memset_chk(dstvar, 0, lenvar,	\
        __ssp_bos0(dstvar)) : \
    __memset_ichk(dstvar, 0, lenvar));		\
})

#define	bzero(dst, len)	_ssp_bzero(__ssp_var(dstv), dst, __ssp_var(lenv), len)

__BEGIN_DECLS
__ssp_redirect(void, explicit_bzero, (void *__buf, size_t __len),
    (__buf, __len));
__END_DECLS

#endif /* __SSP_FORTIFY_LEVEL > 0 */
#endif /* _SSP_STRINGS_H_ */