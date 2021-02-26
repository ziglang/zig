/*
 * Copyright (c) 2005 Apple Computer, Inc. All rights reserved.
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

#ifndef _XLOCALE__WCTYPE_H_
#define _XLOCALE__WCTYPE_H_

#include <__wctype.h>
#include <_types/_wctrans_t.h>
#include <xlocale/_ctype.h>

#if !defined(_DONT_USE_CTYPE_INLINE_) && \
    (defined(_USE_CTYPE_INLINE_) || defined(__GNUC__) || defined(__cplusplus))

__DARWIN_WCTYPE_TOP_inline int
iswblank_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_B, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswhexnumber_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_X, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswideogram_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_I, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswnumber_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_D, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswphonogram_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_Q, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswrune_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, 0xFFFFFFF0L, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswspecial_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_T, _l));
}

#else /* not using inlines */

__BEGIN_DECLS
int	iswblank_l(wint_t, locale_t);
wint_t	iswhexnumber_l(wint_t, locale_t);
wint_t	iswideogram_l(wint_t, locale_t);
wint_t	iswnumber_l(wint_t, locale_t);
wint_t	iswphonogram_l(wint_t, locale_t);
wint_t	iswrune_l(wint_t, locale_t);
wint_t	iswspecial_l(wint_t, locale_t);
__END_DECLS

#endif /* using inlines */

__BEGIN_DECLS
wint_t	nextwctype_l(wint_t, wctype_t, locale_t);
wint_t	towctrans_l(wint_t, wctrans_t, locale_t);
wctrans_t
	wctrans_l(const char *, locale_t);
__END_DECLS

#endif /* _XLOCALE__WCTYPE_H_ */