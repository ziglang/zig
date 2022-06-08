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

#ifndef _XLOCALE___WCTYPE_H_
#define _XLOCALE___WCTYPE_H_

#include <__wctype.h>
#include <xlocale/_ctype.h>

#if !defined(_DONT_USE_CTYPE_INLINE_) && \
    (defined(_USE_CTYPE_INLINE_) || defined(__GNUC__) || defined(__cplusplus))

__DARWIN_WCTYPE_TOP_inline int
iswalnum_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_A|_CTYPE_D, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswalpha_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_A, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswcntrl_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_C, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswctype_l(wint_t _wc, wctype_t _charclass, locale_t _l)
{
	return (__istype_l(_wc, _charclass, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswdigit_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_D, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswgraph_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_G, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswlower_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_L, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswprint_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_R, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswpunct_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_P, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswspace_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_S, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswupper_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_U, _l));
}

__DARWIN_WCTYPE_TOP_inline int
iswxdigit_l(wint_t _wc, locale_t _l)
{
	return (__istype_l(_wc, _CTYPE_X, _l));
}

__DARWIN_WCTYPE_TOP_inline wint_t
towlower_l(wint_t _wc, locale_t _l)
{
        return (__tolower_l(_wc, _l));
}

__DARWIN_WCTYPE_TOP_inline wint_t
towupper_l(wint_t _wc, locale_t _l)
{
        return (__toupper_l(_wc, _l));
}

#else /* not using inlines */

__BEGIN_DECLS
int	iswalnum_l(wint_t, locale_t);
int	iswalpha_l(wint_t, locale_t);
int	iswcntrl_l(wint_t, locale_t);
int	iswctype_l(wint_t, wctype_t, locale_t);
int	iswdigit_l(wint_t, locale_t);
int	iswgraph_l(wint_t, locale_t);
int	iswlower_l(wint_t, locale_t);
int	iswprint_l(wint_t, locale_t);
int	iswpunct_l(wint_t, locale_t);
int	iswspace_l(wint_t, locale_t);
int	iswupper_l(wint_t, locale_t);
int	iswxdigit_l(wint_t, locale_t);
wint_t	towlower_l(wint_t, locale_t);
wint_t	towupper_l(wint_t, locale_t);
__END_DECLS

#endif /* using inlines */

__BEGIN_DECLS
wctype_t
	wctype_l(const char *, locale_t);
__END_DECLS

#endif /* _XLOCALE___WCTYPE_H_ */