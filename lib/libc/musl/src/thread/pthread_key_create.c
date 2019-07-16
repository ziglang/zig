#include "pthread_impl.h"

volatile size_t __pthread_tsd_size = sizeof(void *) * PTHREAD_KEYS_MAX;
void *__pthread_tsd_main[PTHREAD_KEYS_MAX] = { 0 };

static void (*keys[PTHREAD_KEYS_MAX])(void *);

static pthread_rwlock_t key_lock = PTHREAD_RWLOCK_INITIALIZER;

static pthread_key_t next_key;

static void nodtor(void *dummy)
{
}

static void dirty(void *dummy)
{
}

struct cleanup_args {
	pthread_t caller;
	int ret;
};

static void clean_dirty_tsd_callback(void *p)
{
	struct cleanup_args *args = p;
	pthread_t self = __pthread_self();
	pthread_key_t i;
	for (i=0; i<PTHREAD_KEYS_MAX; i++) {
		if (keys[i] == dirty && self->tsd[i])
			self->tsd[i] = 0;
	}
	/* Arbitrary choice to avoid data race. */
	if (args->caller == self) args->ret = 0;
}

static void dummy2(void (*f)(void *), void *p)
{
}

weak_alias(dummy2, __pthread_key_delete_synccall);

static int clean_dirty_tsd(void)
{
	struct cleanup_args args = {
		.caller = __pthread_self(),
		.ret = EAGAIN
	};
	__pthread_key_delete_synccall(clean_dirty_tsd_callback, &args);
	return args.ret;
}

int __pthread_key_create(pthread_key_t *k, void (*dtor)(void *))
{
	pthread_key_t j = next_key;
	pthread_t self = __pthread_self();
	int found_dirty = 0;

	/* This can only happen in the main thread before
	 * pthread_create has been called. */
	if (!self->tsd) self->tsd = __pthread_tsd_main;

	/* Purely a sentinel value since null means slot is free. */
	if (!dtor) dtor = nodtor;

	pthread_rwlock_wrlock(&key_lock);
	do {
		if (!keys[j]) {
			keys[next_key = *k = j] = dtor;
			pthread_rwlock_unlock(&key_lock);
			return 0;
		} else if (keys[j] == dirty) {
			found_dirty = 1;
		}
	} while ((j=(j+1)%PTHREAD_KEYS_MAX) != next_key);

	/* It's possible that all slots are in use or __synccall fails. */
	if (!found_dirty || clean_dirty_tsd()) {
		pthread_rwlock_unlock(&key_lock);
		return EAGAIN;
	}

	/* If this point is reached there is necessarily a newly-cleaned
	 * slot to allocate to satisfy the caller's request. Find it and
	 * mark any additional previously-dirty slots clean. */
	for (j=0; j<PTHREAD_KEYS_MAX; j++) {
		if (keys[j] == dirty) {
			if (dtor) {
				keys[next_key = *k = j] = dtor;
				dtor = 0;
			} else {
				keys[j] = 0;
			}
		}
	}

	pthread_rwlock_unlock(&key_lock);
	return 0;
}

int __pthread_key_delete_impl(pthread_key_t k)
{
	pthread_rwlock_wrlock(&key_lock);
	keys[k] = dirty;
	pthread_rwlock_unlock(&key_lock);
	return 0;
}

void __pthread_tsd_run_dtors()
{
	pthread_t self = __pthread_self();
	int i, j;
	for (j=0; self->tsd_used && j<PTHREAD_DESTRUCTOR_ITERATIONS; j++) {
		pthread_rwlock_rdlock(&key_lock);
		self->tsd_used = 0;
		for (i=0; i<PTHREAD_KEYS_MAX; i++) {
			void *val = self->tsd[i];
			void (*dtor)(void *) = keys[i];
			self->tsd[i] = 0;
			if (val && dtor && dtor != nodtor && dtor != dirty) {
				pthread_rwlock_unlock(&key_lock);
				dtor(val);
				pthread_rwlock_rdlock(&key_lock);
			}
		}
		pthread_rwlock_unlock(&key_lock);
	}
}

weak_alias(__pthread_key_create, pthread_key_create);
