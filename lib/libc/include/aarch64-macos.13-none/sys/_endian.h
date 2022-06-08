/*
 * Copyright (c) 2004, 2006 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */

/*
 * Copyright (c) 1995 NeXT Computer, Inc. All rights reserved.
 * Copyright (c) 2000-2002 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1987, 1991, 1993
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
 */

#ifndef _SYS__ENDIAN_H_
#define _SYS__ENDIAN_H_

#include <sys/cdefs.h>

/*
 * Macros for network/external number representation conversion.
 */

#if defined(lint)

__BEGIN_DECLS
__uint16_t      ntohs(__uint16_t);
__uint16_t      htons(__uint16_t);
__uint32_t      ntohl(__uint32_t);
__uint32_t      htonl(__uint32_t);
__END_DECLS

#elif __DARWIN_BYTE_ORDER == __DARWIN_BIG_ENDIAN

#define ntohl(x)        ((__uint32_t)(x))
#define ntohs(x)        ((__uint16_t)(x))
#define htonl(x)        ((__uint32_t)(x))
#define htons(x)        ((__uint16_t)(x))

#if     defined(KERNEL) || (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))

#define ntohll(x)       ((__uint64_t)(x))
#define htonll(x)       ((__uint64_t)(x))

#define NTOHL(x)        (x)
#define NTOHS(x)        (x)
#define NTOHLL(x)       (x)
#define HTONL(x)        (x)
#define HTONS(x)        (x)
#define HTONLL(x)       (x)
#endif /* defined(KERNEL) || (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)) */

#else   /* __DARWIN_BYTE_ORDER == __DARWIN_LITTLE_ENDIAN */

#include <libkern/_OSByteOrder.h>

#define ntohs(x)        __DARWIN_OSSwapInt16(x)
#define htons(x)        __DARWIN_OSSwapInt16(x)

#define ntohl(x)        __DARWIN_OSSwapInt32(x)
#define htonl(x)        __DARWIN_OSSwapInt32(x)

#if     defined(KERNEL) || (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))

#define ntohll(x)       __DARWIN_OSSwapInt64(x)
#define htonll(x)       __DARWIN_OSSwapInt64(x)

#define NTOHL(x)        (x) = ntohl((__uint32_t)x)
#define NTOHS(x)        (x) = ntohs((__uint16_t)x)
#define NTOHLL(x)       (x) = ntohll((__uint64_t)x)
#define HTONL(x)        (x) = htonl((__uint32_t)x)
#define HTONS(x)        (x) = htons((__uint16_t)x)
#define HTONLL(x)       (x) = htonll((__uint64_t)x)
#endif /* defined(KERNEL) || (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)) */
#endif /* __DARWIN_BYTE_ORDER */
#endif /* !_SYS__ENDIAN_H_ */