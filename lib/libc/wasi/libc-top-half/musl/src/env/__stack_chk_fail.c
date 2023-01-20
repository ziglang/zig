#include <string.h>
#include <stdint.h>
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
#include "pthread_impl.h"
#else
// In non-_REENTRANT, include it for `a_crash`
# include "atomic.h"
#endif

uintptr_t __stack_chk_guard;

void __init_ssp(void *entropy)
{
	if (entropy) memcpy(&__stack_chk_guard, entropy, sizeof(uintptr_t));
	else __stack_chk_guard = (uintptr_t)&__stack_chk_guard * 1103515245;

#if UINTPTR_MAX >= 0xffffffffffffffff
	/* Sacrifice 8 bits of entropy on 64bit to prevent leaking/
	 * overwriting the canary via string-manipulation functions.
	 * The NULL byte is on the second byte so that off-by-ones can
	 * still be detected. Endianness is taken care of
	 * automatically. */
	((char *)&__stack_chk_guard)[1] = 0;
#endif

#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	__pthread_self()->canary = __stack_chk_guard;
#endif
}

void __stack_chk_fail(void)
{
	a_crash();
}

hidden void __stack_chk_fail_local(void);

weak_alias(__stack_chk_fail, __stack_chk_fail_local);

#ifndef __wasilibc_unmodified_upstream
# include <wasi/api.h>

__attribute__((constructor(60)))
static void __wasilibc_init_ssp(void) {
	uintptr_t entropy;
	int r = __wasi_random_get((uint8_t *)&entropy, sizeof(uintptr_t));
	__init_ssp(r ? NULL : &entropy);
}
#endif
