#include <sys/membarrier.h>
#include <semaphore.h>
#include <signal.h>
#include <string.h>
#include "pthread_impl.h"
#include "syscall.h"

static void dummy_0(void)
{
}

weak_alias(dummy_0, __tl_lock);
weak_alias(dummy_0, __tl_unlock);

static sem_t barrier_sem;

static void bcast_barrier(int s)
{
	sem_post(&barrier_sem);
}

int __membarrier(int cmd, int flags)
{
	int r = __syscall(SYS_membarrier, cmd, flags);
	/* Emulate the private expedited command, which is needed by the
	 * dynamic linker for installation of dynamic TLS, for older
	 * kernels that lack the syscall. Unlike the syscall, this only
	 * synchronizes with threads of the process, not other processes
	 * sharing the VM, but such sharing is not a supported usage
	 * anyway. */
	if (r && cmd == MEMBARRIER_CMD_PRIVATE_EXPEDITED && !flags) {
		pthread_t self=__pthread_self(), td;
		sigset_t set;
		__block_app_sigs(&set);
		__tl_lock();
		sem_init(&barrier_sem, 0, 0);
		struct sigaction sa = {
			.sa_flags = SA_RESTART,
			.sa_handler = bcast_barrier
		};
		memset(&sa.sa_mask, -1, sizeof sa.sa_mask);
		if (!__libc_sigaction(SIGSYNCCALL, &sa, 0)) {
			for (td=self->next; td!=self; td=td->next)
				__syscall(SYS_tkill, td->tid, SIGSYNCCALL);
			for (td=self->next; td!=self; td=td->next)
				sem_wait(&barrier_sem);
			r = 0;
			sa.sa_handler = SIG_IGN;
			__libc_sigaction(SIGSYNCCALL, &sa, 0);
		}
		sem_destroy(&barrier_sem);
		__tl_unlock();
		__restore_sigs(&set);
	}
	return __syscall_ret(r);
}

void __membarrier_init(void)
{
	/* If membarrier is linked, attempt to pre-register to be able to use
	 * the private expedited command before the process becomes multi-
	 * threaded, since registering later has bad, potentially unbounded
	 * latency. This syscall should be essentially free, and it's arguably
	 * a mistake in the API design that registration was even required.
	 * For other commands, registration may impose some cost, so it's left
	 * to the application to do so if desired. Unfortunately this means
	 * library code initialized after the process becomes multi-threaded
	 * cannot use these features without accepting registration latency. */
	__syscall(SYS_membarrier, MEMBARRIER_CMD_REGISTER_PRIVATE_EXPEDITED, 0);
}

weak_alias(__membarrier, membarrier);
