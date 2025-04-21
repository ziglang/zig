/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019, 2020 Jeffrey Roberson <jeff@FreeBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef _SYS__SMR_H_
#define	_SYS__SMR_H_

typedef uint32_t	smr_seq_t;
typedef int32_t		smr_delta_t;
typedef struct smr 	*smr_t;

#define	SMR_ENTERED(smr)						\
    (curthread->td_critnest != 0 && zpcpu_get((smr))->c_seq != SMR_SEQ_INVALID)

#define	SMR_ASSERT_ENTERED(smr)						\
    KASSERT(SMR_ENTERED(smr), ("Not in smr section"))

#define	SMR_ASSERT_NOT_ENTERED(smr)					\
    KASSERT(!SMR_ENTERED(smr), ("In smr section."));

#define SMR_ASSERT(ex, fn)						\
    KASSERT((ex), (fn ": Assertion " #ex " failed at %s:%d", __FILE__, __LINE__))

#endif	/* __SYS_SMR_H_ */