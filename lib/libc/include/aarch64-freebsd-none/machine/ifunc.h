/*-
 * Copyright (c) 2015-2018 The FreeBSD Foundation
 *
 * This software was developed by Konstantin Belousov <kib@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef __ARM64_IFUNC_H
#define	__ARM64_IFUNC_H

#define	DEFINE_IFUNC(qual, ret_type, name, args)			\
    static ret_type (*name##_resolver(void))args __used;		\
    qual ret_type name args __attribute__((ifunc(#name "_resolver")));	\
    static ret_type (*name##_resolver(void))args

#define	DEFINE_UIFUNC(qual, ret_type, name, args)			\
    static ret_type (*name##_resolver(uint64_t, uint64_t,		\
	uint64_t, uint64_t, uint64_t, uint64_t, uint64_t,		\
	uint64_t))args __used;						\
    qual ret_type name args __attribute__((ifunc(#name "_resolver")));	\
    static ret_type (*name##_resolver(uint64_t _arg1 __unused,		\
	uint64_t _arg2 __unused, uint64_t _arg3 __unused,		\
	uint64_t _arg4 __unused, uint64_t _arg5 __unused,		\
	uint64_t _arg6 __unused, uint64_t _arg7 __unused,		\
	uint64_t _arg8 __unused))args

#endif