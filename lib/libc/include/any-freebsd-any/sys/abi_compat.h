/*-
 * SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 *
 * Copyright (c) 2001 Doug Rabson
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
 * $FreeBSD$
 */

#ifndef _COMPAT_H_
#define	_COMPAT_H_

/*
 * Helper macros for translating objects between different ABIs.
 */

#define	PTRIN(v)	(void *)(uintptr_t)(v)
#define	PTROUT(v)	(uintptr_t)(v)

#define	CP(src, dst, fld) do {			\
	(dst).fld = (src).fld;			\
} while (0)

#define	CP2(src, dst, sfld, dfld) do {		\
	(dst).dfld = (src).sfld;		\
} while (0)

#define	PTRIN_CP(src, dst, fld) do {		\
	(dst).fld = PTRIN((src).fld);		\
} while (0)

#define	PTROUT_CP(src, dst, fld) do {		\
	(dst).fld = PTROUT((src).fld);		\
} while (0)

#define	TV_CP(src, dst, fld) do {		\
	CP((src).fld, (dst).fld, tv_sec);	\
	CP((src).fld, (dst).fld, tv_usec);	\
} while (0)

#define	TS_CP(src, dst, fld) do {		\
	CP((src).fld, (dst).fld, tv_sec);	\
	CP((src).fld, (dst).fld, tv_nsec);	\
} while (0)

#define	ITS_CP(src, dst) do {			\
	TS_CP((src), (dst), it_interval);	\
	TS_CP((src), (dst), it_value);		\
} while (0)

#define	BT_CP(src, dst, fld) do {				\
	CP((src).fld, (dst).fld, sec);				\
	*(uint64_t *)&(dst).fld.frac[0] = (src).fld.frac;	\
} while (0)

#endif /* !_COMPAT_H_ */
