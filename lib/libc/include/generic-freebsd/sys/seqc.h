/*-
 * Copyright (c) 2014 Mateusz Guzik <mjg@FreeBSD.org>
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

#ifndef _SYS_SEQC_H_
#define _SYS_SEQC_H_

#ifdef _KERNEL
#include <sys/systm.h>
#endif
#include <sys/types.h>

/*
 * seqc_t may be included in structs visible to userspace
 */
#include <sys/_seqc.h>

#ifdef _KERNEL

/* A hack to get MPASS macro */
#include <sys/lock.h>

#include <machine/cpu.h>

#define	SEQC_MOD	1

/*
 * Predicts from inline functions are not honored by clang.
 */
#define seqc_in_modify(seqc)	({			\
	seqc_t __seqc = (seqc);				\
							\
	__predict_false(__seqc & SEQC_MOD);		\
})

static __inline void
seqc_write_begin(seqc_t *seqcp)
{

	critical_enter();
	MPASS(!seqc_in_modify(*seqcp));
	*seqcp += SEQC_MOD;
	atomic_thread_fence_rel();
}

static __inline void
seqc_write_end(seqc_t *seqcp)
{

	atomic_thread_fence_rel();
	*seqcp += SEQC_MOD;
	MPASS(!seqc_in_modify(*seqcp));
	critical_exit();
}

static __inline seqc_t
seqc_read_any(const seqc_t *seqcp)
{

	return (atomic_load_acq_int(__DECONST(seqc_t *, seqcp)));
}

static __inline seqc_t
seqc_read_notmodify(const seqc_t *seqcp)
{

	return (atomic_load_acq_int(__DECONST(seqc_t *, seqcp)) & ~SEQC_MOD);
}

static __inline seqc_t
seqc_read(const seqc_t *seqcp)
{
	seqc_t ret;

	for (;;) {
		ret = seqc_read_any(seqcp);
		if (seqc_in_modify(ret)) {
			cpu_spinwait();
			continue;
		}
		break;
	}

	return (ret);
}

#define seqc_consistent_no_fence(seqcp, oldseqc)({	\
	const seqc_t *__seqcp = (seqcp);		\
	seqc_t __oldseqc = (oldseqc);			\
							\
	MPASS(!(seqc_in_modify(__oldseqc)));		\
	__predict_true(*__seqcp == __oldseqc);		\
})

#define seqc_consistent(seqcp, oldseqc)		({	\
	atomic_thread_fence_acq();			\
	seqc_consistent_no_fence(seqcp, oldseqc);	\
})

/*
 * Variant which does not critical enter/exit.
 */
static __inline void
seqc_sleepable_write_begin(seqc_t *seqcp)
{

	MPASS(!seqc_in_modify(*seqcp));
	*seqcp += SEQC_MOD;
	atomic_thread_fence_rel();
}

static __inline void
seqc_sleepable_write_end(seqc_t *seqcp)
{

	atomic_thread_fence_rel();
	*seqcp += SEQC_MOD;
	MPASS(!seqc_in_modify(*seqcp));
}

#endif	/* _KERNEL */
#endif	/* _SYS_SEQC_H_ */