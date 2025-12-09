/*	$NetBSD: unistd.h,v 1.7 2015/06/25 18:41:03 joerg Exp $	*/

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
#ifndef _SSP_UNISTD_H_
#define _SSP_UNISTD_H_

#include <ssp/ssp.h>

#if __SSP_FORTIFY_LEVEL > 0
__BEGIN_DECLS

#ifndef _FORTIFY_SOURCE_read
#define	_FORTIFY_SOURCE_read	read
#endif

__ssp_inline size_t
__ssp_gid_bos(const void *ptr)
{
	size_t ptrsize = __ssp_bos(ptr);

	if (ptrsize == (size_t)-1)
		return (ptrsize);

	return (ptrsize / sizeof(gid_t));
}

__ssp_redirect_raw(int, getgrouplist, getgrouplist,
    (const char *__name, gid_t __base, gid_t *__buf, int *__lenp),
    (__name, __base, __buf, __lenp), 1, __ssp_gid_bos, *__lenp);

__ssp_redirect_raw(int, getgroups, getgroups, (int __len, gid_t *__buf),
    (__len, __buf), 1, __ssp_gid_bos, __len);

__ssp_redirect(int, getloginclass, (char *__buf, size_t __len),
    (__buf, __len));

__ssp_redirect(ssize_t, _FORTIFY_SOURCE_read, (int __fd, void *__buf,
    size_t __len), (__fd, __buf, __len));
__ssp_redirect(ssize_t, pread, (int __fd, void *__buf, size_t __len,
    off_t __offset), (__fd, __buf, __len, __offset));

__ssp_redirect(ssize_t, readlink, (const char *__restrict __path, \
    char *__restrict __buf, size_t __len), (__path, __buf, __len));
__ssp_redirect(ssize_t, readlinkat, (int __fd, const char *__restrict __path,
	char *__restrict __buf, size_t __len), (__fd, __path, __buf, __len));

__ssp_redirect_raw(char *, getcwd, getcwd, (char *__buf, size_t __len),
    (__buf, __len), __buf != 0, __ssp_bos, __len);

__ssp_redirect(int, getdomainname, (char *__buf, int __len), (__buf, __len));
__ssp_redirect(int, getentropy, (void *__buf, size_t __len), (__buf, __len));
__ssp_redirect(int, gethostname, (char *__buf, size_t __len), (__buf, __len));
__ssp_redirect(int, getlogin_r, (char *__buf, size_t __len), (__buf, __len));
__ssp_redirect(int, ttyname_r, (int __fd, char *__buf, size_t __len),
    (__fd, __buf, __len));

__END_DECLS

#endif /* __SSP_FORTIFY_LEVEL > 0 */
#endif /* _SSP_UNISTD_H_ */