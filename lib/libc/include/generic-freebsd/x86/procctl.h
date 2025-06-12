/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019,2020 The FreeBSD Foundation
 *
 * Portions of this software were developed by Konstantin Belousov
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
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _X86_PROCCTL_H
#define	_X86_PROCCTL_H

#define	PROC_KPTI_CTL		(PROC_PROCCTL_MD_MIN + 0)
#define	PROC_KPTI_STATUS	(PROC_PROCCTL_MD_MIN + 1)
#define	PROC_LA_CTL		(PROC_PROCCTL_MD_MIN + 2)
#define	PROC_LA_STATUS		(PROC_PROCCTL_MD_MIN + 3)

#define	PROC_KPTI_CTL_ENABLE_ON_EXEC	1
#define	PROC_KPTI_CTL_DISABLE_ON_EXEC	2
#define	PROC_KPTI_STATUS_ACTIVE		0x80000000

#define	PROC_LA_CTL_LA48_ON_EXEC	1
#define	PROC_LA_CTL_LA57_ON_EXEC	2
#define	PROC_LA_CTL_DEFAULT_ON_EXEC	3

#define	PROC_LA_STATUS_LA48		0x01000000
#define	PROC_LA_STATUS_LA57		0x02000000

#endif