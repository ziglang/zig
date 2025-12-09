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
#ifndef _SSP_UIO_H_
#define _SSP_UIO_H_

#include <ssp/ssp.h>

#if __SSP_FORTIFY_LEVEL > 0

__BEGIN_DECLS

__ssp_redirect_raw_impl(ssize_t, readv, readv,
    (int fd, const struct iovec *iov, int iovcnt))
{
	__ssp_check_iovec(iov, iovcnt);
	return (__ssp_real(readv)(fd, iov, iovcnt));
}

__ssp_redirect_raw_impl(ssize_t, preadv, preadv,
    (int fd, const struct iovec *iov, int iovcnt, off_t offset))
{
	__ssp_check_iovec(iov, iovcnt);
	return (__ssp_real(preadv)(fd, iov, iovcnt, offset));
}

__END_DECLS

#endif /* __SSP_FORTIFY_LEVEL > 0 */
#endif /* _SSP_UIO_H_ */