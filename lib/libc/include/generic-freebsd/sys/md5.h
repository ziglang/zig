/* MD5.H - header file for MD5C.C
 */

/*-
 SPDX-License-Identifier: RSA-MD

 Copyright (C) 1991-2, RSA Data Security, Inc. Created 1991. All
rights reserved.

License to copy and use this software is granted provided that it
is identified as the "RSA Data Security, Inc. MD5 Message-Digest
Algorithm" in all material mentioning or referencing this software
or this function.

License is also granted to make and use derivative works provided
that such works are identified as "derived from the RSA Data
Security, Inc. MD5 Message-Digest Algorithm" in all material
mentioning or referencing the derived work.

RSA Data Security, Inc. makes no representations concerning either
the merchantability of this software or the suitability of this
software for any particular purpose. It is provided "as is"
without express or implied warranty of any kind.

These notices must be retained in any copies of any part of this
documentation and/or software.
 */

#ifndef _SYS_MD5_H_
#define _SYS_MD5_H_

#include <sys/types.h>

#define MD5_BLOCK_LENGTH		64
#define MD5_DIGEST_LENGTH		16
#define MD5_DIGEST_STRING_LENGTH	(MD5_DIGEST_LENGTH * 2 + 1)

/* MD5 context. */
typedef struct MD5Context {
  u_int32_t state[4];	/* state (ABCD) */
  u_int32_t count[2];	/* number of bits, modulo 2^64 (lsb first) */
  unsigned char buffer[64];	/* input buffer */
} MD5_CTX;

#ifndef _KERNEL

/* Ensure libmd symbols do not clash with libcrypto */

#ifndef MD5Init
#define MD5Init		_libmd_MD5Init
#endif
#ifndef MD5Update
#define MD5Update	_libmd_MD5Update
#endif
#ifndef MD5Pad
#define MD5Pad		_libmd_MD5Pad
#endif
#ifndef MD5Final
#define MD5Final	_libmd_MD5Final
#endif
#ifndef MD5Transform
#define MD5Transform	_libmd_MD5Transform
#endif
#ifndef MD5End
#define MD5End		_libmd_MD5End
#endif
#ifndef MD5Fd
#define MD5Fd		_libmd_MD5Fd
#endif
#ifndef MD5FdChunk
#define MD5FdChunk	_libmd_MD5FdChunk
#endif
#ifndef MD5File
#define MD5File		_libmd_MD5File
#endif
#ifndef MD5FileChunk
#define MD5FileChunk	_libmd_MD5FileChunk
#endif
#ifndef MD5Data
#define MD5Data		_libmd_MD5Data
#endif

#endif

#include <sys/cdefs.h>

__BEGIN_DECLS
void   MD5Init (MD5_CTX *);
void   MD5Update (MD5_CTX *, const void *, unsigned int);
void   MD5Final (unsigned char[__min_size(MD5_DIGEST_LENGTH)], MD5_CTX *);
#ifndef _KERNEL
char * MD5End(MD5_CTX *, char *);
char * MD5Fd(int, char *);
char * MD5FdChunk(int, char *, off_t, off_t);
char * MD5File(const char *, char *);
char * MD5FileChunk(const char *, char *, off_t, off_t);
char * MD5Data(const void *, unsigned int, char *);
#endif
__END_DECLS
#endif /* _SYS_MD5_H_ */