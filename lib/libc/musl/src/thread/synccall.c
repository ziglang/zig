#include "pthread_impl.h"
#include <semaphore.h>
#include <string.h>

static void dummy_0(void)
{
}

weak_alias(dummy_0, __tl_lock);
weak_alias(dummy_0, __tl_unlock);

static int target_tid;
static void (*callback)(void *), *context;
static sem_t target_sem, caller_sem;

static void dummy(void *p)
{
}

static void handler(int sig)
{
	if (__pthread_self()->tid != target_tid) return;

	int old_errno = errno;

	/* Inform caller we have received signal and wait for
	 * the caller to let us make the callback. */
	sem_post(&caller_sem);
	sem_wait(&target_sem);

	callback(context);

	/* Inform caller we've complered the callback and wait
	 * for the caller to release us to return. */
	sem_post(&caller_sem);
	sem_wait(&target_sem);

	/* Inform caller we are returning and state is destroyable. */
	sem_post(&caller_sem);

	errno = old_errno;
}

void __synccall(void (*func)(void *), void *ctx)
{
	sigset_t oldmask;
	int cs, i, r;
	struct sigaction sa = { .sa_flags = SA_RESTART | SA_ONSTACK, .sa_handler = handler };
	pthread_t self = __pthread_self(), td;
	int count = 0;

	/* Blocking signals in two steps, first only app-level signals
	 * before taking the lock, then all signals after taking the lock,
	 * is necessary to achieve AS-safety. Blocking them all first would
	 * deadlock if multiple threads called __synccall. Waiting to block
	 * any until after the lock would allow re-entry in the same thread
	 * with the lock already held. */
	__block_app_sigs(&oldmask);
	__tl_lock();
	__block_all_sigs(0);
	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);

	sem_init(&target_sem, 0, 0);
	sem_init(&caller_sem, 0, 0);

	if (!libc.threads_minus_1 || __syscall(SYS_gettid) != self->tid)
		goto single_threaded;

	callback = func;
	context = ctx;

	/* Block even implementation-internal signals, so that nothing
	 * interrupts the SIGSYNCCALL handlers. The main possible source
	 * of trouble is asynchronous cancellation. */
	memset(&sa.sa_mask, -1, sizeof sa.sa_mask);
	__libc_sigaction(SIGSYNCCALL, &sa, 0);


	for (td=self->next; td!=self; td=td->next) {
		target_tid = td->tid;
		while ((r = -__syscall(SYS_tkill, td->tid, SIGSYNCCALL)) == EAGAIN);
		if (r) {
			/* If we failed to signal any thread, nop out the
			 * callback to abort the synccall and just release
			 * any threads already caught. */
			callback = func = dummy;
			break;
		}
		sem_wait(&caller_sem);
		count++;
	}
	target_tid = 0;

	/* Serialize execution of callback in caught threads, or just
	 * release them all if synccall is being aborted. */
	for (i=0; i<count; i++) {
		sem_post(&target_sem);
		sem_wait(&caller_sem);
	}

	sa.sa_handler = SIG_IGN;
	__libc_sigaction(SIGSYNCCALL, &sa, 0);

single_threaded:
	func(ctx);

	/* Only release the caught threads once all threads, including the
	 * caller, have returned from the callback function. */
	for (i=0; i<count; i++)
		sem_post(&target_sem);
	for (i=0; i<count; i++)
		sem_wait(&caller_sem);

	sem_destroy(&caller_sem);
	sem_destroy(&target_sem);

	pthread_setcancelstate(cs, 0);
	__tl_unlock();
	__restore_sigs(&oldmask);
}
