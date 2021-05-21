#include "stdio_impl.h"
#include "pthread_impl.h"
#include <limits.h>

void __do_orphaned_stdio_locks()
{
	FILE *f;
	for (f=__pthread_self()->stdio_locks; f; f=f->next_locked)
		a_store(&f->lock, 0x40000000);
}

void __unlist_locked_file(FILE *f)
{
	if (f->lockcount) {
		if (f->next_locked) f->next_locked->prev_locked = f->prev_locked;
		if (f->prev_locked) f->prev_locked->next_locked = f->next_locked;
		else __pthread_self()->stdio_locks = f->next_locked;
	}
}

void __register_locked_file(FILE *f, pthread_t self)
{
	f->lockcount = 1;
	f->prev_locked = 0;
	f->next_locked = self->stdio_locks;
	if (f->next_locked) f->next_locked->prev_locked = f;
	self->stdio_locks = f;
}

int ftrylockfile(FILE *f)
{
	pthread_t self = __pthread_self();
	int tid = self->tid;
	int owner = f->lock;
	if ((owner & ~MAYBE_WAITERS) == tid) {
		if (f->lockcount == LONG_MAX)
			return -1;
		f->lockcount++;
		return 0;
	}
	if (owner < 0) f->lock = owner = 0;
	if (owner || a_cas(&f->lock, 0, tid))
		return -1;
	__register_locked_file(f, self);
	return 0;
}
