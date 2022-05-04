#include <string.h>
#include <stdint.h>
#include "pthread_impl.h"

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

	__pthread_self()->canary = __stack_chk_guard;
}

void __stack_chk_fail(void)
{
	a_crash();
}

hidden void __stack_chk_fail_local(void);

weak_alias(__stack_chk_fail, __stack_chk_fail_local);
