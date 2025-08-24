/*	$NetBSD: rmd160.h,v 1.3 2016/07/01 16:43:16 christos Exp $	*/
/*	$KAME: rmd160.h,v 1.2 2003/07/25 09:37:55 itojun Exp $	*/
/*	$OpenBSD: rmd160.h,v 1.3 2002/03/14 01:26:51 millert Exp $	*/
/*
 * Copyright (c) 2001 Markus Friedl.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef  _RMD160_H
#define  _RMD160_H

#include <sys/cdefs.h>
#include <sys/types.h>

#define RMD160_DIGEST_LENGTH		20
#define RMD160_DIGEST_STRING_LENGTH	41
#define RMD160_BLOCK_LENGTH		64

/* RMD160 context. */
typedef struct RMD160Context {
	uint32_t state[5];	/* state */
	uint64_t count;		/* number of bits, modulo 2^64 */
	u_char buffer[RMD160_BLOCK_LENGTH];	/* input buffer */
} RMD160_CTX;

__BEGIN_DECLS
void	 RMD160Init(RMD160_CTX *);
void	 RMD160Transform(uint32_t [5], const u_char [64]);
void	 RMD160Update(RMD160_CTX *, const u_char *, uint32_t);
void	 RMD160Final(u_char [RMD160_DIGEST_LENGTH], RMD160_CTX *);
#ifndef _KERNEL
char	*RMD160End(RMD160_CTX *, char *);
char	*RMD160FileChunk(const char *, char *, off_t, off_t);
char	*RMD160File(const char *, char *);
char	*RMD160Data(const u_char *, size_t, char *);
#endif /* _KERNEL */
__END_DECLS

#endif  /* _RMD160_H */