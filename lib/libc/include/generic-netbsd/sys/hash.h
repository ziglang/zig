/*	$NetBSD: hash.h,v 1.8 2014/09/05 05:46:15 matt Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Luke Mewburn.
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

#ifndef	_SYS_HASH_H_
#define	_SYS_HASH_H_

#include <sys/types.h>

#ifdef __HAVE_MACHINE_HASH_H
#include <machine/hash.h>
#endif

#ifndef __HAVE_HASH32_BUF			/* not overridden by MD hash */

#define	HASH32_BUF_INIT	5381

/*
 * uint32_t
 * hash32_buf(const void *bf, size_t len, uint32_t hash)
 *	return a 32 bit hash of the binary buffer buf (size len),
 *	seeded with an initial hash value of hash (usually HASH32_BUF_INIT).
 */
static __inline uint32_t
hash32_buf(const void *bf, size_t len, uint32_t hash)
{
	const uint8_t *s = (const uint8_t *)bf;

	while (len-- != 0)			/* "nemesi": k=257, r=r*257 */
		hash = hash * 257 + *s++;
	return (hash * 257);
}
#endif	/* __HAVE_HASH32_BUF */


#ifndef __HAVE_HASH32_STR			/* not overridden by MD hash */

#define	HASH32_STR_INIT	5381
/*
 * uint32_t
 * hash32_str(const void *bf, uint32_t hash)
 *	return a 32 bit hash of NUL terminated ASCII string buf,
 *	seeded with an initial hash value of hash (usually HASH32_STR_INIT).
 */
static __inline uint32_t
hash32_str(const void *bf, uint32_t hash)
{
	const uint8_t *s = (const uint8_t *)bf;
	uint8_t	c;

	while ((c = *s++) != 0)
		hash = hash * 33 + c;		/* "perl": k=33, r=r+r/32 */
	return (hash + (hash >> 5));
}

/*
 * uint32_t
 * hash32_strn(const void *bf, size_t len, uint32_t hash)
 *	return a 32 bit hash of NUL terminated ASCII string buf up to
 *	a maximum of len bytes,
 *	seeded with an initial hash value of hash (usually HASH32_STR_INIT).
 */
static __inline uint32_t
hash32_strn(const void *bf, size_t len, uint32_t hash)
{
	const uint8_t *s = (const uint8_t *)bf;
	uint8_t	c;

	while ((c = *s++) != 0 && len-- != 0)
		hash = hash * 33 + c;		/* "perl": k=33, r=r+r/32 */
	return (hash + (hash >> 5));
}
#endif	/* __HAVE_HASH32_STR */

__BEGIN_DECLS
uint32_t	murmurhash2(const void *, size_t, uint32_t);
__END_DECLS

#endif	/* !_SYS_HASH_H_ */