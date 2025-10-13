/* $NetBSD: setjmp.h,v 1.2 2020/05/10 14:05:59 skrll Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

#ifdef __aarch64__

#define	_JB_MAGIC_AARCH64__SETJMP	0x4545524348363400
#define	_JB_MAGIC_AARCH64_SETJMP	0x4545524348363401

			/* magic + 13 reg + 8 simd + 4 sigmask + 6 slop */
#define _JBLEN		(32 * sizeof(_BSD_JBSLOT_T_)/sizeof(long))
#define _JB_MAGIC	0
#define	_JB_SP		1
#define _JB_X19		2
#define _JB_X20		3
#define _JB_X21		4
#define _JB_X22		5
#define _JB_X23		6
#define _JB_X24		7
#define _JB_X25		8
#define _JB_X26		9
#define _JB_X27		10
#define _JB_X28		11
#define _JB_X29		12
#define _JB_X30		13
#define _JB_D8		16
#define _JB_D9		17
#define _JB_D10		18
#define _JB_D11		19
#define _JB_D12		20
#define _JB_D13		21
#define _JB_D14		22
#define _JB_D15		23

#define _JB_SIGMASK	24

#ifndef _BSD_JBSLOT_T_
#define	_BSD_JBSLOT_T_	long long
#endif
#elif defined(__arm__)

#include <arm/setjmp.h>

#endif