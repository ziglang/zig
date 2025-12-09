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
#ifndef _SSP_SOCKET_H_
#define _SSP_SOCKET_H_

#include <ssp/ssp.h>

#if __SSP_FORTIFY_LEVEL > 0

#include <sys/_null.h>

__BEGIN_DECLS

__ssp_inline void
__ssp_check_msghdr(struct msghdr *hdr)
{
	if (__ssp_bos(hdr->msg_name) < hdr->msg_namelen)
		__chk_fail();

	__ssp_check_iovec(hdr->msg_iov, hdr->msg_iovlen);

	if (__ssp_bos(hdr->msg_control) < hdr->msg_controllen)
		__chk_fail();
}

__ssp_redirect_raw_impl(int, getpeername, getpeername,
    (int fdes, struct sockaddr *__restrict name, socklen_t *__restrict namelen))
{
	size_t namesz = __ssp_bos(name);

	if (namesz != (size_t)-1 && namesz < *namelen)
		__chk_fail();

	return (__ssp_real(getpeername)(fdes, name, namelen));
}

__ssp_redirect_raw_impl(int, getsockname, getsockname,
    (int fdes, struct sockaddr *__restrict name,
    socklen_t *__restrict namelen))
{
	size_t namesz = __ssp_bos(name);

	if (namesz != (size_t)-1 && namesz < *namelen)
		__chk_fail();

	return (__ssp_real(getsockname)(fdes, name, namelen));
}

__ssp_redirect(ssize_t, recv, (int __sock, void *__buf, size_t __len,
    int __flags), (__sock, __buf, __len, __flags));

__ssp_redirect_raw_impl(ssize_t, recvfrom, recvfrom,
    (int s, void *buf, size_t len, int flags,
    struct sockaddr *__restrict from,
    socklen_t *__restrict fromlen))
{
	if (__ssp_bos(buf) < len)
		__chk_fail();
	if (from != NULL && __ssp_bos(from) < *fromlen)
		__chk_fail();

	return (__ssp_real(recvfrom)(s, buf, len, flags, from, fromlen));
}

__ssp_redirect_raw_impl(ssize_t, recvmsg, recvmsg,
    (int s, struct msghdr *hdr, int flags))
{
	__ssp_check_msghdr(hdr);
	return (__ssp_real(recvmsg)(s, hdr, flags));
}

#if __BSD_VISIBLE
struct timespec;

__ssp_redirect_raw_impl(ssize_t, recvmmsg, recvmmsg,
    (int s, struct mmsghdr *__restrict hdrvec, size_t vlen, int flags,
    const struct timespec *__restrict timeout))
{
	const size_t vecsz = __ssp_bos(hdrvec);
	size_t i;

	if (vecsz != (size_t)-1 && vecsz / sizeof(*hdrvec) < vlen)
		__chk_fail();

	for (i = 0; i < vlen; i++) {
		__ssp_check_msghdr(&hdrvec[i].msg_hdr);
	}

	return (__ssp_real(recvmmsg)(s, hdrvec, vlen, flags, timeout));
}
#endif

__END_DECLS

#endif /* __SSP_FORTIFY_LEVEL > 0 */
#endif /* _SSP_SOCKET_H_ */