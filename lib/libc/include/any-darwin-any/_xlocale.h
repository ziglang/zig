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

#ifndef _XLOCALE_H_
#define _XLOCALE_H_

#include <sys/cdefs.h>
#include <_bounds.h>

#ifndef _USE_EXTENDED_LOCALES_
#define _USE_EXTENDED_LOCALES_
#endif /* _USE_EXTENDED_LOCALES_ */

#include <_locale.h>
#include <_locale_posix2008.h>
#include <__xlocale.h>

_LIBC_SINGLE_BY_DEFAULT()

__BEGIN_DECLS
extern const locale_t _c_locale;

struct lconv *	localeconv_l(locale_t);
__const char *	querylocale(int, locale_t);
__END_DECLS

#endif /* _XLOCALE_H_ */
