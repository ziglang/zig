/*
 * Copyright (c) 2000-2007 Apple Inc. All rights reserved.
 */
/*
 * Copyright (c) 1988, 1993
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)limits.h	8.3 (Berkeley) 1/4/94
 */

#ifndef _ARM_LIMITS_H_
#define _ARM_LIMITS_H_

#include <sys/cdefs.h>
#include <arm/_limits.h>

#define CHAR_BIT        8               /* number of bits in a char */
#define MB_LEN_MAX      6               /* Allow 31 bit UTF2 */

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#define CLK_TCK         __DARWIN_CLK_TCK        /* ticks per second */
#endif /* !_ANSI_SOURCE && (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/*
 * According to ANSI (section 2.2.4.2), the values below must be usable by
 * #if preprocessing directives.  Additionally, the expression must have the
 * same type as would an expression that is an object of the corresponding
 * type converted according to the integral promotions.  The subtraction for
 * INT_MIN and LONG_MIN is so the value is not unsigned; 2147483648 is an
 * unsigned int for 32-bit two's complement ANSI compilers (section 3.1.3.2).
 * These numbers work for pcc as well.  The UINT_MAX and ULONG_MAX values
 * are written as hex so that GCC will be quiet about large integer constants.
 */
#define SCHAR_MAX       127             /* min value for a signed char */
#define SCHAR_MIN       (-128)          /* max value for a signed char */

#define UCHAR_MAX       255             /* max value for an unsigned char */
#define CHAR_MAX        127             /* max value for a char */
#define CHAR_MIN        (-128)          /* min value for a char */

#define USHRT_MAX       65535           /* max value for an unsigned short */
#define SHRT_MAX        32767           /* max value for a short */
#define SHRT_MIN        (-32768)        /* min value for a short */

#define UINT_MAX        0xffffffff      /* max value for an unsigned int */
#define INT_MAX         2147483647      /* max value for an int */
#define INT_MIN         (-2147483647-1) /* min value for an int */

#ifdef __LP64__
#define ULONG_MAX       0xffffffffffffffffUL    /* max unsigned long */
#define LONG_MAX        0x7fffffffffffffffL     /* max signed long */
#define LONG_MIN        (-0x7fffffffffffffffL-1) /* min signed long */
#else /* !__LP64__ */
#define ULONG_MAX       0xffffffffUL    /* max unsigned long */
#define LONG_MAX        2147483647L     /* max signed long */
#define LONG_MIN        (-2147483647L-1) /* min signed long */
#endif /* __LP64__ */

#define ULLONG_MAX      0xffffffffffffffffULL   /* max unsigned long long */
#define LLONG_MAX       0x7fffffffffffffffLL    /* max signed long long */
#define LLONG_MIN       (-0x7fffffffffffffffLL-1) /* min signed long long */

#if !defined(_ANSI_SOURCE)
#ifdef __LP64__
#define LONG_BIT        64
#else /* !__LP64__ */
#define LONG_BIT        32
#endif /* __LP64__ */
#define SSIZE_MAX       LONG_MAX        /* max value for a ssize_t */
#define WORD_BIT        32

#if (!defined(_POSIX_C_SOURCE) && !defined(_XOPEN_SOURCE)) || defined(_DARWIN_C_SOURCE)
#define SIZE_T_MAX      ULONG_MAX       /* max value for a size_t */

#define UQUAD_MAX       ULLONG_MAX
#define QUAD_MAX        LLONG_MAX
#define QUAD_MIN        LLONG_MIN

#endif /* (!_POSIX_C_SOURCE && !_XOPEN_SOURCE) || _DARWIN_C_SOURCE */
#endif /* !_ANSI_SOURCE */

#endif /* _ARM_LIMITS_H_ */