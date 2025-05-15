/*-
 * This file is in the public domain.
 */

#ifndef	_SYS_PRNG_H_
#define	_SYS_PRNG_H_

#define	PCG_USE_INLINE_ASM	1
#include <contrib/pcg-c/include/pcg_variants.h>

#ifdef	_KERNEL
__uint32_t prng32(void);
__uint32_t prng32_bounded(__uint32_t bound);
__uint64_t prng64(void);
__uint64_t prng64_bounded(__uint64_t bound);
#endif

#endif