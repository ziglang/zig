/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)libkern.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _SYS_LIBKERN_H_
#define	_SYS_LIBKERN_H_

#include <sys/cdefs.h>
#include <sys/types.h>
#ifdef _KERNEL
#include <sys/systm.h>
#endif

#ifndef	LIBKERN_INLINE
#define	LIBKERN_INLINE  static __inline
#define	LIBKERN_BODY
#endif

/* BCD conversions. */
extern u_char const	bcd2bin_data[];
extern u_char const	bin2bcd_data[];
extern char const	hex2ascii_data[];

#define	LIBKERN_LEN_BCD2BIN	154
#define	LIBKERN_LEN_BIN2BCD	100
#define	LIBKERN_LEN_HEX2ASCII	36

static inline u_char
bcd2bin(int bcd)
{

	KASSERT(bcd >= 0 && bcd < LIBKERN_LEN_BCD2BIN,
	    ("invalid bcd %d", bcd));
	return (bcd2bin_data[bcd]);
}

static inline u_char
bin2bcd(int bin)
{

	KASSERT(bin >= 0 && bin < LIBKERN_LEN_BIN2BCD,
	    ("invalid bin %d", bin));
	return (bin2bcd_data[bin]);
}

static inline char
hex2ascii(int hex)
{

	KASSERT(hex >= 0 && hex < LIBKERN_LEN_HEX2ASCII,
	    ("invalid hex %d", hex));
	return (hex2ascii_data[hex]);
}

static inline bool
validbcd(int bcd)
{

	return (bcd == 0 || (bcd > 0 && bcd <= 0x99 && bcd2bin_data[bcd] != 0));
}
static __inline int imax(int a, int b) { return (a > b ? a : b); }
static __inline int imin(int a, int b) { return (a < b ? a : b); }
static __inline long lmax(long a, long b) { return (a > b ? a : b); }
static __inline long lmin(long a, long b) { return (a < b ? a : b); }
static __inline u_int max(u_int a, u_int b) { return (a > b ? a : b); }
static __inline u_int min(u_int a, u_int b) { return (a < b ? a : b); }
static __inline quad_t qmax(quad_t a, quad_t b) { return (a > b ? a : b); }
static __inline quad_t qmin(quad_t a, quad_t b) { return (a < b ? a : b); }
static __inline u_quad_t uqmax(u_quad_t a, u_quad_t b) { return (a > b ? a : b); }
static __inline u_quad_t uqmin(u_quad_t a, u_quad_t b) { return (a < b ? a : b); }
static __inline u_long ulmax(u_long a, u_long b) { return (a > b ? a : b); }
static __inline u_long ulmin(u_long a, u_long b) { return (a < b ? a : b); }
static __inline __uintmax_t ummax(__uintmax_t a, __uintmax_t b)
{

	return (a > b ? a : b);
}
static __inline __uintmax_t ummin(__uintmax_t a, __uintmax_t b)
{

	return (a < b ? a : b);
}
static __inline off_t omax(off_t a, off_t b) { return (a > b ? a : b); }
static __inline off_t omin(off_t a, off_t b) { return (a < b ? a : b); }
static __inline int abs(int a) { return (a < 0 ? -a : a); }
static __inline long labs(long a) { return (a < 0 ? -a : a); }
static __inline int64_t abs64(int64_t a) { return (a < 0 ? -a : a); }
static __inline quad_t qabs(quad_t a) { return (a < 0 ? -a : a); }

#ifndef RANDOM_FENESTRASX
#define	ARC4_ENTR_NONE	0	/* Don't have entropy yet. */
#define	ARC4_ENTR_HAVE	1	/* Have entropy. */
#define	ARC4_ENTR_SEED	2	/* Reseeding. */
extern int arc4rand_iniseed_state;
#endif

/* Prototypes for non-quad routines. */
struct malloc_type;
uint32_t arc4random(void);
void	 arc4random_buf(void *, size_t);
uint32_t arc4random_uniform(uint32_t);
void	 arc4rand(void *, u_int, int);
int	 timingsafe_bcmp(const void *, const void *, size_t);
void	*bsearch(const void *, const void *, size_t,
	    size_t, int (*)(const void *, const void *));

/*
 * MHTODO: remove the 'HAVE_INLINE_FOO' defines once use of these flags has
 * been purged everywhere. For now we provide them unconditionally.
 */
#define	HAVE_INLINE_FFS
#define	HAVE_INLINE_FFSL
#define	HAVE_INLINE_FFSLL
#define	HAVE_INLINE_FLS
#define	HAVE_INLINE_FLSL
#define	HAVE_INLINE_FLSLL

static __inline __pure2 int
ffs(int mask)
{

	return (__builtin_ffs((u_int)mask));
}

static __inline __pure2 int
ffsl(long mask)
{

	return (__builtin_ffsl((u_long)mask));
}

static __inline __pure2 int
ffsll(long long mask)
{

	return (__builtin_ffsll((unsigned long long)mask));
}

static __inline __pure2 int
fls(int mask)
{

	return (mask == 0 ? 0 :
	    8 * sizeof(mask) - __builtin_clz((u_int)mask));
}

static __inline __pure2 int
flsl(long mask)
{

	return (mask == 0 ? 0 :
	    8 * sizeof(mask) - __builtin_clzl((u_long)mask));
}

static __inline __pure2 int
flsll(long long mask)
{

	return (mask == 0 ? 0 :
	    8 * sizeof(mask) - __builtin_clzll((unsigned long long)mask));
}

#define	bitcount64(x)	__bitcount64((uint64_t)(x))
#define	bitcount32(x)	__bitcount32((uint32_t)(x))
#define	bitcount16(x)	__bitcount16((uint16_t)(x))
#define	bitcountl(x)	__bitcountl((u_long)(x))
#define	bitcount(x)	__bitcount((u_int)(x))

int	 fnmatch(const char *, const char *, int);
int	 locc(int, char *, u_int);
void	*memchr(const void *s, int c, size_t n);
void	*memcchr(const void *s, int c, size_t n);
void	*memmem(const void *l, size_t l_len, const void *s, size_t s_len);
void	 qsort(void *base, size_t nmemb, size_t size,
	    int (*compar)(const void *, const void *));
void	 qsort_r(void *base, size_t nmemb, size_t size,
	    int (*compar)(const void *, const void *, void *), void *thunk);
u_long	 random(void);
int	 scanc(u_int, const u_char *, const u_char *, int);
int	 strcasecmp(const char *, const char *);
char	*strcasestr(const char *, const char *);
char	*strcat(char * __restrict, const char * __restrict);
char	*strchr(const char *, int);
char	*strchrnul(const char *, int);
int	 strcmp(const char *, const char *);
char	*strcpy(char * __restrict, const char * __restrict);
char	*strdup_flags(const char *__restrict, struct malloc_type *, int);
size_t	 strcspn(const char *, const char *) __pure;
char	*strdup(const char *__restrict, struct malloc_type *);
char	*strncat(char *, const char *, size_t);
char	*strndup(const char *__restrict, size_t, struct malloc_type *);
size_t	 strlcat(char *, const char *, size_t);
size_t	 strlcpy(char *, const char *, size_t);
size_t	 strlen(const char *);
int	 strncasecmp(const char *, const char *, size_t);
int	 strncmp(const char *, const char *, size_t);
char	*strncpy(char * __restrict, const char * __restrict, size_t);
size_t	 strnlen(const char *, size_t);
char	*strnstr(const char *, const char *, size_t);
char	*strrchr(const char *, int);
char	*strsep(char **, const char *delim);
size_t	 strspn(const char *, const char *);
char	*strstr(const char *, const char *);
int	 strvalid(const char *, size_t);

#ifdef SAN_NEEDS_INTERCEPTORS
#ifndef SAN_INTERCEPTOR
#define	SAN_INTERCEPTOR(func)	\
	__CONCAT(SAN_INTERCEPTOR_PREFIX, __CONCAT(_, func))
#endif
char	*SAN_INTERCEPTOR(strcpy)(char *, const char *);
int	SAN_INTERCEPTOR(strcmp)(const char *, const char *);
size_t	SAN_INTERCEPTOR(strlen)(const char *);
#ifndef SAN_RUNTIME
#define	strcpy(d, s)	SAN_INTERCEPTOR(strcpy)((d), (s))
#define	strcmp(s1, s2)	SAN_INTERCEPTOR(strcmp)((s1), (s2))
#define	strlen(s)	SAN_INTERCEPTOR(strlen)(s)
#endif /* !SAN_RUNTIME */
#else /* !SAN_NEEDS_INTERCEPTORS */
#define strcpy(d, s)	__builtin_strcpy((d), (s))
#define strcmp(s1, s2)	__builtin_strcmp((s1), (s2))
#define strlen(s)	__builtin_strlen((s))
#endif /* SAN_NEEDS_INTERCEPTORS */

static __inline char *
index(const char *p, int ch)
{

	return (strchr(p, ch));
}

static __inline char *
rindex(const char *p, int ch)
{

	return (strrchr(p, ch));
}

static __inline int64_t
signed_extend64(uint64_t bitmap, int lsb, int width)
{

	return ((int64_t)(bitmap << (63 - lsb - (width - 1)))) >>
	    (63 - (width - 1));
}

static __inline int32_t
signed_extend32(uint32_t bitmap, int lsb, int width)
{

	return ((int32_t)(bitmap << (31 - lsb - (width - 1)))) >>
	    (31 - (width - 1));
}

/* fnmatch() return values. */
#define	FNM_NOMATCH	1	/* Match failed. */

/* fnmatch() flags. */
#define	FNM_NOESCAPE	0x01	/* Disable backslash escaping. */
#define	FNM_PATHNAME	0x02	/* Slash must be matched by slash. */
#define	FNM_PERIOD	0x04	/* Period must be matched by period. */
#define	FNM_LEADING_DIR	0x08	/* Ignore /<tail> after Imatch. */
#define	FNM_CASEFOLD	0x10	/* Case insensitive search. */
#define	FNM_IGNORECASE	FNM_CASEFOLD
#define	FNM_FILE_NAME	FNM_PATHNAME

#endif /* !_SYS_LIBKERN_H_ */