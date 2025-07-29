/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2000-2015, 2017 Mark R. V. Murray
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer
 *    in this position and unchanged.
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
 */

#ifndef	_SYS_RANDOM_H_
#define	_SYS_RANDOM_H_

#include <sys/types.h>

#ifdef _KERNEL

struct uio;

/*
 * In the loadable random world, there are set of dangling pointers left in the
 * core kernel:
 *   * read_random, read_random_uio, is_random_seeded are function pointers,
 *     rather than functions.
 *   * p_random_alg_context is a true pointer in loadable random kernels.
 *
 * These are initialized at SI_SUB_RANDOM:SI_ORDER_SECOND during boot.  The
 * read-type pointers are initialized by random_alg_context_init() in
 * randomdev.c and p_random_alg_context in the algorithm, e.g., fortuna.c's
 * random_fortuna_init_alg().  The nice thing about function pointers is they
 * have a similar calling convention to ordinary functions.
 *
 * (In !loadable, the read_random, etc, routines are just plain functions;
 * p_random_alg_context is a macro for the public visibility
 * &random_alg_context.)
 */
#if defined(RANDOM_LOADABLE)
extern void (*_read_random)(void *, u_int);
extern int (*_read_random_uio)(struct uio *, bool);
extern bool (*_is_random_seeded)(void);
#define	read_random(a, b)	(*_read_random)(a, b)
#define	read_random_uio(a, b)	(*_read_random_uio)(a, b)
#define	is_random_seeded()	(*_is_random_seeded)()
#else
void read_random(void *, u_int);
int read_random_uio(struct uio *, bool);
bool is_random_seeded(void);
#endif

/*
 * Note: if you add or remove members of random_entropy_source, remember to
 * also update the strings in the static array random_source_descr[] in
 * random_harvestq.c.
 */
enum random_entropy_source {
	RANDOM_START = 0,
	RANDOM_CACHED = 0,
	/* Environmental sources */
	RANDOM_ATTACH,
	RANDOM_KEYBOARD,
	RANDOM_MOUSE,
	RANDOM_NET_TUN,
	RANDOM_NET_ETHER,
	RANDOM_NET_NG,
	RANDOM_INTERRUPT,
	RANDOM_SWI,
	RANDOM_FS_ATIME,
	RANDOM_UMA,	/* Special!! UMA/SLAB Allocator */
	RANDOM_CALLOUT,
	RANDOM_ENVIRONMENTAL_END = RANDOM_CALLOUT,
	/* Fast hardware random-number sources from here on. */
	RANDOM_PURE_START,
	RANDOM_PURE_OCTEON = RANDOM_PURE_START,
	RANDOM_PURE_SAFE,
	RANDOM_PURE_GLXSB,
	RANDOM_PURE_HIFN,
	RANDOM_PURE_RDRAND,
	RANDOM_PURE_NEHEMIAH,
	RANDOM_PURE_RNDTEST,
	RANDOM_PURE_VIRTIO,
	RANDOM_PURE_BROADCOM,
	RANDOM_PURE_CCP,
	RANDOM_PURE_DARN,
	RANDOM_PURE_TPM,
	RANDOM_PURE_VMGENID,
	RANDOM_PURE_QUALCOMM,
	RANDOM_PURE_ARMV8,
	ENTROPYSOURCE
};
_Static_assert(ENTROPYSOURCE <= 32,
    "hardcoded assumption that values fit in a typical word-sized bitset");

#define RANDOM_CACHED_BOOT_ENTROPY_MODULE	"boot_entropy_cache"
#define RANDOM_PLATFORM_BOOT_ENTROPY_MODULE	"boot_entropy_platform"

extern u_int hc_source_mask;
void random_harvest_queue_(const void *, u_int, enum random_entropy_source);
void random_harvest_fast_(const void *, u_int);
void random_harvest_direct_(const void *, u_int, enum random_entropy_source);

static __inline void
random_harvest_queue(const void *entropy, u_int size, enum random_entropy_source origin)
{

	if (hc_source_mask & (1 << origin))
		random_harvest_queue_(entropy, size, origin);
}

static __inline void
random_harvest_fast(const void *entropy, u_int size, enum random_entropy_source origin)
{

	if (hc_source_mask & (1 << origin))
		random_harvest_fast_(entropy, size);
}

static __inline void
random_harvest_direct(const void *entropy, u_int size, enum random_entropy_source origin)
{

	if (hc_source_mask & (1 << origin))
		random_harvest_direct_(entropy, size, origin);
}

void random_harvest_register_source(enum random_entropy_source);
void random_harvest_deregister_source(enum random_entropy_source);

#if defined(RANDOM_ENABLE_UMA)
#define random_harvest_fast_uma(a, b, c)	random_harvest_fast(a, b, c)
#else /* !defined(RANDOM_ENABLE_UMA) */
#define random_harvest_fast_uma(a, b, c)	do {} while (0)
#endif /* defined(RANDOM_ENABLE_UMA) */

#if defined(RANDOM_ENABLE_ETHER)
#define random_harvest_queue_ether(a, b)	random_harvest_queue(a, b, RANDOM_NET_ETHER)
#else /* !defined(RANDOM_ENABLE_ETHER) */
#define random_harvest_queue_ether(a, b)	do {} while (0)
#endif /* defined(RANDOM_ENABLE_ETHER) */

#endif /* _KERNEL */

#define GRND_NONBLOCK	0x1
#define GRND_RANDOM	0x2
#define GRND_INSECURE	0x4

__BEGIN_DECLS
ssize_t getrandom(void *buf, size_t buflen, unsigned int flags);
__END_DECLS

#endif /* _SYS_RANDOM_H_ */