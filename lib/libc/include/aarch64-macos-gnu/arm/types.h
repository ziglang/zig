/*
 * Copyright (c) 2000-2008 Apple Inc. All rights reserved.
 */
/*
 * Copyright 1995 NeXT Computer, Inc. All rights reserved.
 */
/*
 * Copyright (c) 1990, 1993
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
 *	@(#)types.h	8.3 (Berkeley) 1/5/94
 */

#ifndef _MACHTYPES_H_
#define _MACHTYPES_H_

#ifndef __ASSEMBLER__
#include <arm/_types.h>
#include <sys/cdefs.h>
/*
 * Basic integral types.  Omit the typedef if
 * not possible for a machine/compiler combination.
 */
#include <sys/_types/_int8_t.h>
#include <sys/_types/_int16_t.h>
#include <sys/_types/_int32_t.h>
#include <sys/_types/_int64_t.h>

#include <sys/_types/_u_int8_t.h>
#include <sys/_types/_u_int16_t.h>
#include <sys/_types/_u_int32_t.h>
#include <sys/_types/_u_int64_t.h>

#if __LP64__
typedef int64_t                 register_t;
#else
typedef int32_t                 register_t;
#endif

#include <sys/_types/_intptr_t.h>
#include <sys/_types/_uintptr_t.h>

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
/* These types are used for reserving the largest possible size. */
#ifdef __arm64__
typedef u_int64_t               user_addr_t;
typedef u_int64_t               user_size_t;
typedef int64_t                 user_ssize_t;
typedef int64_t                 user_long_t;
typedef u_int64_t               user_ulong_t;
typedef int64_t                 user_time_t;
typedef int64_t                 user_off_t;
#else
typedef u_int32_t               user_addr_t;
typedef u_int32_t               user_size_t;
typedef int32_t                 user_ssize_t;
typedef int32_t                 user_long_t;
typedef u_int32_t               user_ulong_t;
typedef int32_t                 user_time_t;
typedef int64_t                 user_off_t;
#endif

#define USER_ADDR_NULL  ((user_addr_t) 0)
#define CAST_USER_ADDR_T(a_ptr)   ((user_addr_t)((uintptr_t)(a_ptr)))


#endif /* !_ANSI_SOURCE && (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

/* This defines the size of syscall arguments after copying into the kernel: */
#if defined(__arm__)
typedef u_int32_t               syscall_arg_t;
#elif defined(__arm64__)
typedef u_int64_t               syscall_arg_t;
#else
#error Unknown architecture.
#endif

#endif /* __ASSEMBLER__ */
#endif  /* _MACHTYPES_H_ */
