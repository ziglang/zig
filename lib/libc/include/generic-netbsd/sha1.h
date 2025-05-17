/*	$NetBSD: sha1.h,v 1.15 2016/07/01 16:43:16 christos Exp $	*/

/*
 * SHA-1 in C
 * By Steve Reid <steve@edmweb.com>
 * 100% Public Domain
 */

#ifndef _SYS_SHA1_H_
#define	_SYS_SHA1_H_

#include <sys/cdefs.h>
#include <sys/types.h>

#define SHA1_DIGEST_LENGTH		20
#define SHA1_DIGEST_STRING_LENGTH	41
#define SHA1_BLOCK_LENGTH		64

typedef struct {
	uint32_t state[5];
	uint32_t count[2];
	uint8_t buffer[SHA1_BLOCK_LENGTH];
} SHA1_CTX;

__BEGIN_DECLS
void	SHA1Transform(uint32_t[5], const uint8_t[64]);
void	SHA1Init(SHA1_CTX *);
void	SHA1Update(SHA1_CTX *, const uint8_t *, unsigned int);
void	SHA1Final(uint8_t[SHA1_DIGEST_LENGTH], SHA1_CTX *);
#ifndef _KERNEL
char	*SHA1End(SHA1_CTX *, char *);
char	*SHA1FileChunk(const char *, char *, off_t, off_t);
char	*SHA1File(const char *, char *);
char	*SHA1Data(const uint8_t *, size_t, char *);
#endif /* _KERNEL */
__END_DECLS

#endif /* _SYS_SHA1_H_ */