/*-
 * Copyright (c)1999 Citrus Project,
 * All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */

/*
 * Common header for wctype.h and wchar.h
 *
 * Contains everything required by wctype.h except:
 *
 *	#include <_types/_wctrans_t.h>
 *	int iswblank(wint_t);
 *	wint_t towctrans(wint_t, wctrans_t);
 *	wctrans_t wctrans(const char *);
 */

#ifndef __WCTYPE_H_
#define __WCTYPE_H_

#include <__wctype.h>

/*
 * Use inline functions if we are allowed to and the compiler supports them.
 */
#if !defined(_DONT_USE_CTYPE_INLINE_) && \
    (defined(_USE_CTYPE_INLINE_) || defined(__GNUC__) || defined(__cplusplus))

__DARWIN_WCTYPE_TOP_inline int
iswalnum(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_A|_CTYPE_D));
}

__DARWIN_WCTYPE_TOP_inline int
iswalpha(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_A));
}

__DARWIN_WCTYPE_TOP_inline int
iswcntrl(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_C));
}

__DARWIN_WCTYPE_TOP_inline int
iswctype(wint_t _wc, wctype_t _charclass)
{
	return (__istype(_wc, _charclass));
}

__DARWIN_WCTYPE_TOP_inline int
iswdigit(wint_t _wc)
{
	return (__isctype(_wc, _CTYPE_D));
}

__DARWIN_WCTYPE_TOP_inline int
iswgraph(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_G));
}

__DARWIN_WCTYPE_TOP_inline int
iswlower(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_L));
}

__DARWIN_WCTYPE_TOP_inline int
iswprint(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_R));
}

__DARWIN_WCTYPE_TOP_inline int
iswpunct(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_P));
}

__DARWIN_WCTYPE_TOP_inline int
iswspace(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_S));
}

__DARWIN_WCTYPE_TOP_inline int
iswupper(wint_t _wc)
{
	return (__istype(_wc, _CTYPE_U));
}

__DARWIN_WCTYPE_TOP_inline int
iswxdigit(wint_t _wc)
{
	return (__isctype(_wc, _CTYPE_X));
}

__DARWIN_WCTYPE_TOP_inline wint_t
towlower(wint_t _wc)
{
        return (__tolower(_wc));
}

__DARWIN_WCTYPE_TOP_inline wint_t
towupper(wint_t _wc)
{
        return (__toupper(_wc));
}

#else /* not using inlines */

__BEGIN_DECLS
int	iswalnum(wint_t);
int	iswalpha(wint_t);
int	iswcntrl(wint_t);
int	iswctype(wint_t, wctype_t);
int	iswdigit(wint_t);
int	iswgraph(wint_t);
int	iswlower(wint_t);
int	iswprint(wint_t);
int	iswpunct(wint_t);
int	iswspace(wint_t);
int	iswupper(wint_t);
int	iswxdigit(wint_t);
wint_t	towlower(wint_t);
wint_t	towupper(wint_t);
__END_DECLS

#endif /* using inlines */

__BEGIN_DECLS
wctype_t
	wctype(const char *);
__END_DECLS

#ifdef _USE_EXTENDED_LOCALES_
#include <xlocale/__wctype.h>
#endif /* _USE_EXTENDED_LOCALES_ */

#endif /* __WCTYPE_H_ */
