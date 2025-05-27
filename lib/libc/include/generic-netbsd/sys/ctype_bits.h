/* $NetBSD: ctype_bits.h,v 1.6 2016/01/22 23:30:27 dholland Exp $ */

/*
 * Copyright (c) 1989 The Regents of the University of California.
 * All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)ctype.h	5.3 (Berkeley) 4/3/91
 *	NetBSD: ctype.h,v 1.30 2010/05/22 06:38:15 tnozaki Exp
 */

#ifndef _SYS_CTYPE_BITS_H_
#define _SYS_CTYPE_BITS_H_

#include <sys/cdefs.h>

#define	_CTYPE_A	0x0001	/* Alpha     */
#define	_CTYPE_C	0x0002	/* Control   */
#define	_CTYPE_D	0x0004	/* Digit     */
#define	_CTYPE_G	0x0008	/* Graph     */
#define	_CTYPE_L	0x0010	/* Lower     */
#define	_CTYPE_P	0x0020	/* Punct     */
#define	_CTYPE_S	0x0040	/* Space     */
#define	_CTYPE_U	0x0080	/* Upper     */
#define	_CTYPE_X	0x0100	/* X digit   */
#define	_CTYPE_BL	0x0200	/* Blank     */
#define	_CTYPE_R	0x0400	/* Print     */
#define	_CTYPE_I	0x0800	/* Ideogram  */
#define	_CTYPE_T	0x1000	/* Special   */
#define	_CTYPE_Q	0x2000	/* Phonogram */

__BEGIN_DECLS
extern const unsigned short	*_ctype_tab_;
extern const short	*_tolower_tab_;
extern const short	*_toupper_tab_;

extern const unsigned short _C_ctype_tab_[];
extern const short _C_toupper_tab_[];
extern const short _C_tolower_tab_[];
__END_DECLS

#endif /* !_SYS_CTYPE_BITS_H_ */