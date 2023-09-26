/*
 * Copyright (c) 2011 Apple Inc. All rights reserved.
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

#ifndef _XLOCALE__REGEX_H_
#define _XLOCALE__REGEX_H_

#ifndef _REGEX_H_
#include <_regex.h>
#endif // _REGEX_H_
#include <_xlocale.h>

__BEGIN_DECLS

int	regcomp_l(regex_t * __restrict, const char * __restrict, int,
	    locale_t __restrict)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_NA);

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL

int	regncomp_l(regex_t * __restrict, const char * __restrict, size_t,
	    int, locale_t __restrict)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_NA);
int	regwcomp_l(regex_t * __restrict, const wchar_t * __restrict,
	    int, locale_t __restrict)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_NA);
int	regwnexec_l(const regex_t * __restrict, const wchar_t * __restrict,
	    size_t, size_t, regmatch_t __pmatch[ __restrict], int,
	    locale_t __restrict)
	    __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_NA);

#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

__END_DECLS

#endif /* _XLOCALE__REGEX_H_ */
