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
#ifndef _SSP_WCHAR_H_
#define _SSP_WCHAR_H_

#include <ssp/ssp.h>

#if __SSP_FORTIFY_LEVEL > 0

__ssp_inline int
__ssp_wchar_overlap(const void *leftp, const void *rightp, size_t len)
{

	if (len > __SIZE_T_MAX / sizeof(wchar_t))
		return (1);
	return (__ssp_overlap(leftp, rightp, len * sizeof(wchar_t)));
}

/*
 * __ssp_wbos for w*() calls where the size parameters are in sizeof(wchar_t)
 * units, so the result needs to be scaled appropriately.
 */
__ssp_inline size_t
__ssp_wbos(void *ptr)
{
	const size_t ptrsize = __ssp_bos(ptr);

	if (ptrsize == (size_t)-1)
		return (ptrsize);

	return (ptrsize / sizeof(wchar_t));
}

__BEGIN_DECLS
__ssp_redirect_raw_impl(wchar_t *, wmemcpy, wmemcpy,
    (wchar_t *__restrict buf, const wchar_t *__restrict src, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len > slen)
		__chk_fail();
	if (__ssp_wchar_overlap(src, buf, len))
		__chk_fail();

	return (__ssp_real(wmemcpy)(buf, src, len));
}

__ssp_redirect_raw_impl(wchar_t *, wmempcpy, wmempcpy,
    (wchar_t *__restrict buf, const wchar_t *__restrict src, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len > slen)
		__chk_fail();
	if (__ssp_wchar_overlap(src, buf, len))
		__chk_fail();

	return (__ssp_real(wmempcpy)(buf, src, len));
}

__ssp_redirect_raw_impl(wchar_t *, wmemmove, wmemmove,
    (wchar_t *buf, const wchar_t *src, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len > slen)
		__chk_fail();

	return (__ssp_real(wmemmove)(buf, src, len));
}

__ssp_redirect_raw_impl(wchar_t *, wmemset, wmemset,
    (wchar_t *buf, wchar_t c, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len > slen)
		__chk_fail();
	return (__ssp_real(wmemset)(buf, c, len));
}

__ssp_redirect_raw_impl(wchar_t *, wcpcpy, wcpcpy,
    (wchar_t *__restrict buf, const wchar_t *__restrict src))
{
	const size_t slen = __ssp_wbos(buf);
	const size_t len = wcslen(src);

	if (len >= slen)
		__chk_fail();
	if (__ssp_wchar_overlap(buf, src, len))
		__chk_fail();

	(void)__ssp_real(wmemcpy)(buf, src, len + 1);
	return (buf + len);
}

__ssp_redirect_raw_impl(wchar_t *, wcpncpy, wcpncpy,
    (wchar_t *__restrict buf, const wchar_t *__restrict src, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len > slen)
		__chk_fail();
	if (__ssp_wchar_overlap(buf, src, len))
		__chk_fail();

	return (__ssp_real(wcpncpy)(buf, src, len));
}

__ssp_redirect_raw_impl(wchar_t *, wcscat, wcscat,
   (wchar_t *__restrict buf, const wchar_t *__restrict src))
{
	size_t slen = __ssp_wbos(buf);
	wchar_t *cp;

	cp = buf;
	while (*cp != L'\0') {
		cp++;
		if (slen-- == 0)
			__chk_fail();
	}

	while (*src != L'\0') {
		if (slen-- == 0)
			__chk_fail();
		*cp++ = *src++;
	}

	if (slen-- == 0)
		__chk_fail();
	*cp = '\0';
	return (buf);
}

__ssp_redirect_raw_impl(wchar_t *, wcscpy, wcscpy,
   (wchar_t *__restrict buf, const wchar_t *__restrict src))
{
	const size_t slen = __ssp_wbos(buf);
	size_t len = wcslen(src) + 1;

	if (len > slen)
		__chk_fail();
	if (__ssp_wchar_overlap(buf, src, len))
		__chk_fail();

	return (__ssp_real(wmemcpy)(buf, src, len));
}

__ssp_redirect_raw_impl(wchar_t *, wcsncat, wcsncat,
    (wchar_t *__restrict buf, const wchar_t *__restrict src, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len == 0)
		return (buf);
	if (len > slen)
		__chk_fail();
	if (__ssp_wchar_overlap(buf, src, len))
		__chk_fail();

	return (__ssp_real(wcsncat)(buf, src, len));
}

__ssp_redirect_raw_impl(size_t, wcslcat, wcslcat,
    (wchar_t *__restrict buf, const wchar_t *__restrict src, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len > slen)
		__chk_fail();
	if (__ssp_wchar_overlap(buf, src, len))
		__chk_fail();

	return (__ssp_real(wcslcat)(buf, src, len));
}

__ssp_redirect_raw_impl(wchar_t *, wcsncpy, wcsncpy,
    (wchar_t *__restrict buf, const wchar_t *__restrict src, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len > slen)
		__chk_fail();
	if (__ssp_wchar_overlap(buf, src, len))
		__chk_fail();

	return (__ssp_real(wcsncpy)(buf, src, len));
}

__ssp_redirect_raw_impl(size_t, wcslcpy, wcslcpy,
    (wchar_t *__restrict buf, const wchar_t *__restrict src, size_t len))
{
	const size_t slen = __ssp_wbos(buf);

	if (len > slen)
		__chk_fail();
	if (__ssp_wchar_overlap(buf, src, len))
		__chk_fail();

	return (__ssp_real(wcslcpy)(buf, src, len));
}
__END_DECLS

#endif /* __SSP_FORTIFY_LEVEL > 0 */
#endif /* _SSP_WCHAR_H_ */