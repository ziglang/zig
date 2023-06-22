#include <unistd.h>
#include <errno.h>
#include "libc.h"
#include "lock.h"
#include "pthread_impl.h"
#include "fork_impl.h"

static volatile int *const dummy_lockptr = 0;

weak_alias(dummy_lockptr, __at_quick_exit_lockptr);
weak_alias(dummy_lockptr, __atexit_lockptr);
weak_alias(dummy_lockptr, __gettext_lockptr);
weak_alias(dummy_lockptr, __locale_lockptr);
weak_alias(dummy_lockptr, __random_lockptr);
weak_alias(dummy_lockptr, __sem_open_lockptr);
weak_alias(dummy_lockptr, __stdio_ofl_lockptr);
weak_alias(dummy_lockptr, __syslog_lockptr);
weak_alias(dummy_lockptr, __timezone_lockptr);
weak_alias(dummy_lockptr, __bump_lockptr);

weak_alias(dummy_lockptr, __vmlock_lockptr);

static volatile int *const *const atfork_locks[] = {
	&__at_quick_exit_lockptr,
	&__atexit_lockptr,
	&__gettext_lockptr,
	&__locale_lockptr,
	&__random_lockptr,
	&__sem_open_lockptr,
	&__stdio_ofl_lockptr,
	&__syslog_lockptr,
	&__timezone_lockptr,
	&__bump_lockptr,
};

static void dummy(int x) { }
weak_alias(dummy, __fork_handler);
weak_alias(dummy, __malloc_atfork);
weak_alias(dummy, __aio_atfork);
weak_alias(dummy, __pthread_key_atfork);
weak_alias(dummy, __ldso_atfork);

static void dummy_0(void) { }
weak_alias(dummy_0, __tl_lock);
weak_alias(dummy_0, __tl_unlock);

pid_t fork(void)
{
	sigset_t set;
	__fork_handler(-1);
	__block_app_sigs(&set);
	int need_locks = libc.need_locks > 0;
	if (need_locks) {
		__ldso_atfork(-1);
		__pthread_key_atfork(-1);
		__aio_atfork(-1);
		__inhibit_ptc();
		for (int i=0; i<sizeof atfork_locks/sizeof *atfork_locks; i++)
			if (*atfork_locks[i]) LOCK(*atfork_locks[i]);
		__malloc_atfork(-1);
		__tl_lock();
	}
	pthread_t self=__pthread_self(), next=self->next;
	pid_t ret = _Fork();
	int errno_save = errno;
	if (need_locks) {
		if (!ret) {
			for (pthread_t td=next; td!=self; td=td->next)
				td->tid = -1;
			if (__vmlock_lockptr) {
				__vmlock_lockptr[0] = 0;
				__vmlock_lockptr[1] = 0;
			}
		}
		__tl_unlock();
		__malloc_atfork(!ret);
		for (int i=0; i<sizeof atfork_locks/sizeof *atfork_locks; i++)
			if (*atfork_locks[i])
				if (ret) UNLOCK(*atfork_locks[i]);
				else **atfork_locks[i] = 0;
		__release_ptc();
		if (ret) __aio_atfork(0);
		__pthread_key_atfork(!ret);
		__ldso_atfork(!ret);
	}
	__restore_sigs(&set);
	__fork_handler(!ret);
	if (ret<0) errno = errno_save;
	return ret;
}
