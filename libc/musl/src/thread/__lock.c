#include "pthread_impl.h"

/* This lock primitive combines a flag (in the sign bit) and a
 * congestion count (= threads inside the critical section, CS) in a
 * single int that is accessed through atomic operations. The states
 * of the int for value x are:
 *
 * x == 0: unlocked and no thread inside the critical section
 *
 * x < 0: locked with a congestion of x-INT_MIN, including the thread
 * that holds the lock
 *
 * x > 0: unlocked with a congestion of x
 *
 * or in an equivalent formulation x is the congestion count or'ed
 * with INT_MIN as a lock flag.
 */

void __lock(volatile int *l)
{
	if (!libc.threads_minus_1) return;
	/* fast path: INT_MIN for the lock, +1 for the congestion */
	int current = a_cas(l, 0, INT_MIN + 1);
	if (!current) return;
	/* A first spin loop, for medium congestion. */
	for (unsigned i = 0; i < 10; ++i) {
		if (current < 0) current -= INT_MIN + 1;
		// assertion: current >= 0
		int val = a_cas(l, current, INT_MIN + (current + 1));
		if (val == current) return;
		current = val;
	}
	// Spinning failed, so mark ourselves as being inside the CS.
	current = a_fetch_add(l, 1) + 1;
	/* The main lock acquisition loop for heavy congestion. The only
	 * change to the value performed inside that loop is a successful
	 * lock via the CAS that acquires the lock. */
	for (;;) {
		/* We can only go into wait, if we know that somebody holds the
		 * lock and will eventually wake us up, again. */
		if (current < 0) {
			__futexwait(l, current, 1);
			current -= INT_MIN + 1;
		}
		/* assertion: current > 0, the count includes us already. */
		int val = a_cas(l, current, INT_MIN + current);
		if (val == current) return;
		current = val;
	}
}

void __unlock(volatile int *l)
{
	/* Check l[0] to see if we are multi-threaded. */
	if (l[0] < 0) {
		if (a_fetch_add(l, -(INT_MIN + 1)) != (INT_MIN + 1)) {
			__wake(l, 1, 1);
		}
	}
}
