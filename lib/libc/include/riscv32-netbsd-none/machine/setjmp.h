/* $NetBSD: setjmp.h,v 1.2 2015/03/27 06:57:21 matt Exp $ */

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

	/* magic + 16 reg + 1 fcsr + 12 fp + 4 sigmask + 8 spare */
#define _JBLEN		(_JB_SIGMASK + 4 + 8)
#define _JB_MAGIC	0
#define	_JB_RA		1
#define _JB_SP		2
#define _JB_GP		3
#define _JB_TP		4
#define _JB_S0		5
#define _JB_S1		6
#define _JB_S2		7
#define _JB_S3		8
#define _JB_S4		9
#define _JB_S5		10
#define _JB_S6		11
#define _JB_S7		12
#define _JB_S8		13
#define _JB_S9		14
#define _JB_S10		15
#define _JB_S11		16
#define _JB_FCSR	17

#define	_JB_FS0		18
#define	_JB_FS1		(_JB_FS0 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS2		(_JB_FS1 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS3		(_JB_FS2 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS4		(_JB_FS3 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS5		(_JB_FS4 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS6		(_JB_FS5 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS7		(_JB_FS6 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS8		(_JB_FS7 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS9		(_JB_FS8 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS10	(_JB_FS9 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))
#define	_JB_FS11	(_JB_FS10 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))

#define _JB_SIGMASK	(_JB_FS11 + sizeof(double) / sizeof(_BSD_JBSLOT_T_))

#ifndef _BSD_JBSLOT_T_
#define	_BSD_JBSLOT_T_	long long
#endif