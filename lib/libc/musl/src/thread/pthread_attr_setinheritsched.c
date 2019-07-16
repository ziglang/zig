#include "pthread_impl.h"
#include "syscall.h"

hidden void *__start_sched(void *p)
{
	struct start_sched_args *ssa = p;
	void *start_arg = ssa->start_arg;
	void *(*start_fn)(void *) = ssa->start_fn;
	pthread_t self = __pthread_self();

	int ret = -__syscall(SYS_sched_setscheduler, self->tid,
		ssa->attr->_a_policy, &ssa->attr->_a_prio);
	if (!ret) __restore_sigs(&ssa->mask);
	a_store(&ssa->futex, ret);
	__wake(&ssa->futex, 1, 1);
	if (ret) {
		self->detach_state = DT_DYNAMIC;
		return 0;
	}
	return start_fn(start_arg);
}

int pthread_attr_setinheritsched(pthread_attr_t *a, int inherit)
{
	if (inherit > 1U) return EINVAL;
	a->_a_sched = inherit;
	return 0;
}
