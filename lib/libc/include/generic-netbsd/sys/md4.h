/*	$NetBSD: md4.h,v 1.9 2018/11/28 05:19:13 kamil Exp $	*/

/*
 * This file is derived from the RSA Data Security, Inc. MD4 Message-Digest
 * Algorithm and has been modified by Jason R. Thorpe <thorpej@NetBSD.org>
 * for portability and formatting.
 */

/*
 * Copyright (C) 1991-2, RSA Data Security, Inc. Created 1991. All
 * rights reserved.
 *
 * License to copy and use this software is granted provided that it
 * is identified as the "RSA Data Security, Inc. MD4 Message-Digest
 * Algorithm" in all material mentioning or referencing this software
 * or this function.
 *
 * License is also granted to make and use derivative works provided
 * that such works are identified as "derived from the RSA Data
 * Security, Inc. MD4 Message-Digest Algorithm" in all material
 * mentioning or referencing the derived work.
 *
 * RSA Data Security, Inc. makes no representations concerning either
 * the merchantability of this software or the suitability of this
 * software for any particular purpose. It is provided "as is"
 * without express or implied warranty of any kind.
 *
 * These notices must be retained in any copies of any part of this
 * documentation and/or software.
 */

#ifndef _SYS_MD4_H_
#define _SYS_MD4_H_

#include <sys/cdefs.h>
#include <sys/types.h>

#define MD4_DIGEST_LENGTH 16
#define MD4_DIGEST_STRING_LENGTH 33
#define MD4_BLOCK_LENGTH 64

/* MD4 context. */
typedef struct MD4Context {
	uint32_t state[4];	/* state (ABCD) */
	uint32_t count[2];	/* number of bits, modulo 2^64 (lsb first) */
	unsigned char buffer[MD4_BLOCK_LENGTH]; /* input buffer */
} MD4_CTX;

__BEGIN_DECLS
void	MD4Init(MD4_CTX *);
void	MD4Update(MD4_CTX *, const unsigned char *, unsigned int);
void	MD4Final(unsigned char[MD4_DIGEST_LENGTH], MD4_CTX *);
#ifndef _KERNEL
char	*MD4End(MD4_CTX *, char *);
char	*MD4File(const char *, char *);
char	*MD4Data(const unsigned char *, unsigned int, char *);
#endif /* _KERNEL */
__END_DECLS

#endif /* _SYS_MD4_H_ */