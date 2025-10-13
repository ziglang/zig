/*	$NetBSD: uvm_stat.h,v 1.56 2021/12/11 19:24:22 mrg Exp $	*/

/*
 * Copyright (c) 2011 Matthew R. Green
 * All rights reserved.
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
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Backwards compat for UVMHIST, in the new KERNHIST form.
 */

#ifndef _UVM_UVM_STAT_H_
#define _UVM_UVM_STAT_H_

#if defined(_KERNEL_OPT)
#include "opt_uvmhist.h"
#include "opt_kernhist.h"
#endif

/*
 * Make UVMHIST_PRINT force on KERNHIST_PRINT for at least UVMHIST_* usage.
 */
#if defined(UVMHIST_PRINT) && !defined(KERNHIST_PRINT)
#define KERNHIST_PRINT 1
#endif

#include <sys/kernhist.h>

#ifdef UVMHIST

#define UVMHIST_DECL(NAME)			KERNHIST_DECL(NAME)
#define UVMHIST_DEFINE(NAME)			KERNHIST_DEFINE(NAME)
#define UVMHIST_INIT(NAME,N)			KERNHIST_INIT(NAME,N)
#define UVMHIST_INITIALIZER(NAME,BUF)		KERNHIST_INITIALIZER(NAME,BUF)
#define UVMHIST_LINK_STATIC(NAME)		KERNHIST_LINK_STATIC(NAME)
#define UVMHIST_LOG(NAME,FMT,A,B,C,D)		KERNHIST_LOG(NAME,FMT,A,B,C,D)
#define UVMHIST_CALLED(NAME)			KERNHIST_CALLED(NAME)
#define UVMHIST_CALLARGS(NAME,FMT,A,B,C,D)	KERNHIST_CALLARGS(NAME,FMT,A,B,C,D)
#define UVMHIST_FUNC(FNAME)			KERNHIST_FUNC(FNAME)

#else

#define UVMHIST_DECL(NAME)
#define UVMHIST_DEFINE(NAME)
#define UVMHIST_INIT(NAME,N)
#define UVMHIST_INITIALIZER(NAME,BUF)
#define UVMHIST_LINK_STATIC(NAME)
#define UVMHIST_LOG(NAME,FMT,A,B,C,D)
#define UVMHIST_CALLED(NAME)
#define UVMHIST_CALLARGS(NAME,FMT,A,B,C,D)
#define UVMHIST_FUNC(FNAME)

#endif

#endif /* _UVM_UVM_STAT_H_ */