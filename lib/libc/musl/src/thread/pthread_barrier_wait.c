#include "pthread_impl.h"

static int pshared_barrier_wait(pthread_barrier_t *b)
{
	int limit = (b->_b_limit & INT_MAX) + 1;
	int ret = 0;
	int v, w;

	if (limit==1) return PTHREAD_BARRIER_SERIAL_THREAD;

	while ((v=a_cas(&b->_b_lock, 0, limit)))
		__wait(&b->_b_lock, &b->_b_waiters, v, 0);

	/* Wait for <limit> threads to get to the barrier */
	if (++b->_b_count == limit) {
		a_store(&b->_b_count, 0);
		ret = PTHREAD_BARRIER_SERIAL_THREAD;
		if (b->_b_waiters2) __wake(&b->_b_count, -1, 0);
	} else {
		a_store(&b->_b_lock, 0);
		if (b->_b_waiters) __wake(&b->_b_lock, 1, 0);
		while ((v=b->_b_count)>0)
			__wait(&b->_b_count, &b->_b_waiters2, v, 0);
	}

	__vm_lock();

	/* Ensure all threads have a vm lock before proceeding */
	if (a_fetch_add(&b->_b_count, -1)==1-limit) {
		a_store(&b->_b_count, 0);
		if (b->_b_waiters2) __wake(&b->_b_count, -1, 0);
	} else {
		while ((v=b->_b_count))
			__wait(&b->_b_count, &b->_b_waiters2, v, 0);
	}
	
	/* Perform a recursive unlock suitable for self-sync'd destruction */
	do {
		v = b->_b_lock;
		w = b->_b_waiters;
	} while (a_cas(&b->_b_lock, v, v==INT_MIN+1 ? 0 : v-1) != v);

	/* Wake a thread waiting to reuse or destroy the barrier */
	if (v==INT_MIN+1 || (v==1 && w))
		__wake(&b->_b_lock, 1, 0);

	__vm_unlock();

	return ret;
}

struct instance
{
	volatile int count;
	volatile int last;
	volatile int waiters;
	volatile int finished;
};

int pthread_barrier_wait(pthread_barrier_t *b)
{
	int limit = b->_b_limit;
	struct instance *inst;

	/* Trivial case: count was set at 1 */
	if (!limit) return PTHREAD_BARRIER_SERIAL_THREAD;

	/* Process-shared barriers require a separate, inefficient wait */
	if (limit < 0) return pshared_barrier_wait(b);

	/* Otherwise we need a lock on the barrier object */
	while (a_swap(&b->_b_lock, 1))
		__wait(&b->_b_lock, &b->_b_waiters, 1, 1);
	inst = b->_b_inst;

	/* First thread to enter the barrier becomes the "instance owner" */
	if (!inst) {
		struct instance new_inst = { 0 };
		int spins = 200;
		b->_b_inst = inst = &new_inst;
		a_store(&b->_b_lock, 0);
		if (b->_b_waiters) __wake(&b->_b_lock, 1, 1);
		while (spins-- && !inst->finished)
			a_spin();
		a_inc(&inst->finished);
		while (inst->finished == 1)
			__syscall(SYS_futex,&inst->finished,FUTEX_WAIT|FUTEX_PRIVATE,1,0) != -ENOSYS
			|| __syscall(SYS_futex,&inst->finished,FUTEX_WAIT,1,0);
		return PTHREAD_BARRIER_SERIAL_THREAD;
	}

	/* Last thread to enter the barrier wakes all non-instance-owners */
	if (++inst->count == limit) {
		b->_b_inst = 0;
		a_store(&b->_b_lock, 0);
		if (b->_b_waiters) __wake(&b->_b_lock, 1, 1);
		a_store(&inst->last, 1);
		if (inst->waiters)
			__wake(&inst->last, -1, 1);
	} else {
		a_store(&b->_b_lock, 0);
		if (b->_b_waiters) __wake(&b->_b_lock, 1, 1);
		__wait(&inst->last, &inst->waiters, 0, 1);
	}

	/* Last thread to exit the barrier wakes the instance owner */
	if (a_fetch_add(&inst->count,-1)==1 && a_fetch_add(&inst->finished,1))
		__wake(&inst->finished, 1, 1);

	return 0;
}
