#include "pthread_impl.h"
#ifndef __wasilibc_unmodified_upstream
#include "assert.h"
#endif

#ifndef __wasilibc_unmodified_upstream
// Use WebAssembly's `wait` instruction to implement a futex. Note that `op` is
// unused but retained as a parameter to match the original signature of the
// syscall and that, for `max_wait_ns`, -1 (or any negative number) means wait
// indefinitely.
//
// Adapted from Emscripten: see
// https://github.com/emscripten-core/emscripten/blob/058a9fff/system/lib/pthread/emscripten_futex_wait.c#L111-L150.
int __wasilibc_futex_wait(volatile void *addr, int op, int val, int64_t max_wait_ns)
{
    if ((((intptr_t)addr) & 3) != 0) {
        return -EINVAL;
    }

    int ret = __builtin_wasm_memory_atomic_wait32((int *)addr, val, max_wait_ns);

    // memory.atomic.wait32 returns:
    //   0 => "ok", woken by another agent.
    //   1 => "not-equal", loaded value != expected value
    //   2 => "timed-out", the timeout expired
    if (ret == 1) {
        return -EWOULDBLOCK;
    }
    if (ret == 2) {
        return -ETIMEDOUT;
    }
    assert(ret == 0);
    return 0;
}
#endif

void __wait(volatile int *addr, volatile int *waiters, int val, int priv)
{
	int spins=100;
	if (priv) priv = FUTEX_PRIVATE;
	while (spins-- && (!waiters || !*waiters)) {
		if (*addr==val) a_spin();
		else return;
	}
	if (waiters) a_inc(waiters);
	while (*addr==val) {
#ifdef __wasilibc_unmodified_upstream
		__syscall(SYS_futex, addr, FUTEX_WAIT|priv, val, 0) != -ENOSYS
		|| __syscall(SYS_futex, addr, FUTEX_WAIT, val, 0);
#else
		__wasilibc_futex_wait(addr, FUTEX_WAIT, val, 0);
#endif
	}
	if (waiters) a_dec(waiters);
}
