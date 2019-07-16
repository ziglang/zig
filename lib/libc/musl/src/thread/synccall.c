#include "pthread_impl.h"
#include <semaphore.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <ctype.h>
#include "futex.h"
#include "atomic.h"
#include "../dirent/__dirent.h"
#include "lock.h"

static struct chain {
	struct chain *next;
	int tid;
	sem_t target_sem, caller_sem;
} *volatile head;

static volatile int synccall_lock[1];
static volatile int target_tid;
static void (*callback)(void *), *context;
static volatile int dummy = 0;
weak_alias(dummy, __block_new_threads);

static void handler(int sig)
{
	struct chain ch;
	int old_errno = errno;

	sem_init(&ch.target_sem, 0, 0);
	sem_init(&ch.caller_sem, 0, 0);

	ch.tid = __syscall(SYS_gettid);

	do ch.next = head;
	while (a_cas_p(&head, ch.next, &ch) != ch.next);

	if (a_cas(&target_tid, ch.tid, 0) == (ch.tid | 0x80000000))
		__syscall(SYS_futex, &target_tid, FUTEX_UNLOCK_PI|FUTEX_PRIVATE);

	sem_wait(&ch.target_sem);
	callback(context);
	sem_post(&ch.caller_sem);
	sem_wait(&ch.target_sem);

	errno = old_errno;
}

void __synccall(void (*func)(void *), void *ctx)
{
	sigset_t oldmask;
	int cs, i, r, pid, self;;
	DIR dir = {0};
	struct dirent *de;
	struct sigaction sa = { .sa_flags = SA_RESTART, .sa_handler = handler };
	struct chain *cp, *next;
	struct timespec ts;

	/* Blocking signals in two steps, first only app-level signals
	 * before taking the lock, then all signals after taking the lock,
	 * is necessary to achieve AS-safety. Blocking them all first would
	 * deadlock if multiple threads called __synccall. Waiting to block
	 * any until after the lock would allow re-entry in the same thread
	 * with the lock already held. */
	__block_app_sigs(&oldmask);
	LOCK(synccall_lock);
	__block_all_sigs(0);
	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);

	head = 0;

	if (!libc.threaded) goto single_threaded;

	callback = func;
	context = ctx;

	/* This atomic store ensures that any signaled threads will see the
	 * above stores, and prevents more than a bounded number of threads,
	 * those already in pthread_create, from creating new threads until
	 * the value is cleared to zero again. */
	a_store(&__block_new_threads, 1);

	/* Block even implementation-internal signals, so that nothing
	 * interrupts the SIGSYNCCALL handlers. The main possible source
	 * of trouble is asynchronous cancellation. */
	memset(&sa.sa_mask, -1, sizeof sa.sa_mask);
	__libc_sigaction(SIGSYNCCALL, &sa, 0);

	pid = __syscall(SYS_getpid);
	self = __syscall(SYS_gettid);

	/* Since opendir is not AS-safe, the DIR needs to be setup manually
	 * in automatic storage. Thankfully this is easy. */
	dir.fd = open("/proc/self/task", O_RDONLY|O_DIRECTORY|O_CLOEXEC);
	if (dir.fd < 0) goto out;

	/* Initially send one signal per counted thread. But since we can't
	 * synchronize with thread creation/exit here, there could be too
	 * few signals. This initial signaling is just an optimization, not
	 * part of the logic. */
	for (i=libc.threads_minus_1; i; i--)
		__syscall(SYS_kill, pid, SIGSYNCCALL);

	/* Loop scanning the kernel-provided thread list until it shows no
	 * threads that have not already replied to the signal. */
	for (;;) {
		int miss_cnt = 0;
		while ((de = readdir(&dir))) {
			if (!isdigit(de->d_name[0])) continue;
			int tid = atoi(de->d_name);
			if (tid == self || !tid) continue;

			/* Set the target thread as the PI futex owner before
			 * checking if it's in the list of caught threads. If it
			 * adds itself to the list after we check for it, then
			 * it will see its own tid in the PI futex and perform
			 * the unlock operation. */
			a_store(&target_tid, tid);

			/* Thread-already-caught is a success condition. */
			for (cp = head; cp && cp->tid != tid; cp=cp->next);
			if (cp) continue;

			r = -__syscall(SYS_tgkill, pid, tid, SIGSYNCCALL);

			/* Target thread exit is a success condition. */
			if (r == ESRCH) continue;

			/* The FUTEX_LOCK_PI operation is used to loan priority
			 * to the target thread, which otherwise may be unable
			 * to run. Timeout is necessary because there is a race
			 * condition where the tid may be reused by a different
			 * process. */
			clock_gettime(CLOCK_REALTIME, &ts);
			ts.tv_nsec += 10000000;
			if (ts.tv_nsec >= 1000000000) {
				ts.tv_sec++;
				ts.tv_nsec -= 1000000000;
			}
			r = -__syscall(SYS_futex, &target_tid,
				FUTEX_LOCK_PI|FUTEX_PRIVATE, 0, &ts);

			/* Obtaining the lock means the thread responded. ESRCH
			 * means the target thread exited, which is okay too. */
			if (!r || r == ESRCH) continue;

			miss_cnt++;
		}
		if (!miss_cnt) break;
		rewinddir(&dir);
	}
	close(dir.fd);

	/* Serialize execution of callback in caught threads. */
	for (cp=head; cp; cp=cp->next) {
		sem_post(&cp->target_sem);
		sem_wait(&cp->caller_sem);
	}

	sa.sa_handler = SIG_IGN;
	__libc_sigaction(SIGSYNCCALL, &sa, 0);

single_threaded:
	func(ctx);

	/* Only release the caught threads once all threads, including the
	 * caller, have returned from the callback function. */
	for (cp=head; cp; cp=next) {
		next = cp->next;
		sem_post(&cp->target_sem);
	}

out:
	a_store(&__block_new_threads, 0);
	__wake(&__block_new_threads, -1, 1);

	pthread_setcancelstate(cs, 0);
	UNLOCK(synccall_lock);
	__restore_sigs(&oldmask);
}
