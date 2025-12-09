/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024, Klara, Inc.
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
#ifndef _SSP_STDLIB_H_
#define _SSP_STDLIB_H_

#include <ssp/ssp.h>

#if __SSP_FORTIFY_LEVEL > 0

#include <limits.h>

__BEGIN_DECLS

__ssp_redirect(void, arc4random_buf, (void *__buf, size_t __len),
    (__buf, __len));

__ssp_redirect(int, getenv_r,
    (const char *name, char * _Nonnull __buf, size_t __len),
    (name, __buf, __len));

__ssp_redirect_raw_impl(char *, realpath, realpath,
    (const char *__restrict path, char *__restrict buf))
{
	if (__ssp_bos(buf) < PATH_MAX)
		__chk_fail();

	return (__ssp_real(realpath)(path, buf));
}

__END_DECLS

#endif /* __SSP_FORTIFY_LEVEL > 0 */
#endif /* _SSP_STDLIB_H_ */