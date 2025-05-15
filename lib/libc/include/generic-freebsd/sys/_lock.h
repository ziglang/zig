/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1997 Berkeley Software Design, Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Berkeley Software Design Inc's name may not be used to endorse or
 *    promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BERKELEY SOFTWARE DESIGN INC ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL BERKELEY SOFTWARE DESIGN INC BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS__LOCK_H_
#define	_SYS__LOCK_H_

struct lock_object {
	const	char *lo_name;		/* Individual lock name. */
	u_int	lo_flags;
	u_int	lo_data;		/* General class specific data. */
	struct	witness *lo_witness;	/* Data for witness. */
};

#ifdef _KERNEL
/*
 * If any of WITNESS, INVARIANTS, or KTR_LOCK KTR tracing has been enabled,
 * then turn on LOCK_DEBUG.  When this option is on, extra debugging
 * facilities such as tracking the file and line number of lock operations
 * are enabled.  Also, mutex locking operations are not inlined to avoid
 * bloat from all the extra debugging code.  We also have to turn on all the
 * calling conventions for this debugging code in modules so that modules can
 * work with both debug and non-debug kernels.
 */
#if (defined(KLD_MODULE) && !defined(KLD_TIED)) || defined(WITNESS) || defined(INVARIANTS) || \
    defined(LOCK_PROFILING) || defined(KTR)
#define	LOCK_DEBUG	1
#else
#define	LOCK_DEBUG	0
#endif

/*
 * In the LOCK_DEBUG case, use the filename and line numbers for debugging
 * operations.  Otherwise, use default values to avoid the unneeded bloat.
 */
#if LOCK_DEBUG > 0
#define LOCK_FILE_LINE_ARG_DEF	, const char *file, int line
#define LOCK_FILE_LINE_ARG	, file, line
#define	LOCK_FILE	__FILE__
#define	LOCK_LINE	__LINE__
#else
#define LOCK_FILE_LINE_ARG_DEF
#define LOCK_FILE_LINE_ARG
#define	LOCK_FILE	NULL
#define	LOCK_LINE	0
#endif
#endif /* _KERNEL */

#endif /* !_SYS__LOCK_H_ */