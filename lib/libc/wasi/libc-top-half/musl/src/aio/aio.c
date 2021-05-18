#include <aio.h>
#include <pthread.h>
#include <semaphore.h>
#include <limits.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/auxv.h>
#include "syscall.h"
#include "atomic.h"
#include "pthread_impl.h"
#include "aio_impl.h"

#define malloc __libc_malloc
#define calloc __libc_calloc
#define realloc __libc_realloc
#define free __libc_free

/* The following is a threads-based implementation of AIO with minimal
 * dependence on implementation details. Most synchronization is
 * performed with pthread primitives, but atomics and futex operations
 * are used for notification in a couple places where the pthread
 * primitives would be inefficient or impractical.
 *
 * For each fd with outstanding aio operations, an aio_queue structure
 * is maintained. These are reference-counted and destroyed by the last
 * aio worker thread to exit. Accessing any member of the aio_queue
 * structure requires a lock on the aio_queue. Adding and removing aio
 * queues themselves requires a write lock on the global map object,
 * a 4-level table mapping file descriptor numbers to aio queues. A
 * read lock on the map is used to obtain locks on existing queues by
 * excluding destruction of the queue by a different thread while it is
 * being locked.
 *
 * Each aio queue has a list of active threads/operations. Presently there
 * is a one to one relationship between threads and operations. The only
 * members of the aio_thread structure which are accessed by other threads
 * are the linked list pointers, op (which is immutable), running (which
 * is updated atomically), and err (which is synchronized via running),
 * so no locking is necessary. Most of the other other members are used
 * for sharing data between the main flow of execution and cancellation
 * cleanup handler.
 *
 * Taking any aio locks requires having all signals blocked. This is
 * necessary because aio_cancel is needed by close, and close is required
 * to be async-signal safe. All aio worker threads run with all signals
 * blocked permanently.
 */

struct aio_thread {
	pthread_t td;
	struct aiocb *cb;
	struct aio_thread *next, *prev;
	struct aio_queue *q;
	volatile int running;
	int err, op;
	ssize_t ret;
};

struct aio_queue {
	int fd, seekable, append, ref, init;
	pthread_mutex_t lock;
	pthread_cond_t cond;
	struct aio_thread *head;
};

struct aio_args {
	struct aiocb *cb;
	struct aio_queue *q;
	int op;
	sem_t sem;
};

static pthread_rwlock_t maplock = PTHREAD_RWLOCK_INITIALIZER;
static struct aio_queue *****map;
static volatile int aio_fd_cnt;
volatile int __aio_fut;

static size_t io_thread_stack_size;

#define MAX(a,b) ((a)>(b) ? (a) : (b))

static struct aio_queue *__aio_get_queue(int fd, int need)
{
	if (fd < 0) {
		errno = EBADF;
		return 0;
	}
	int a=fd>>24;
	unsigned char b=fd>>16, c=fd>>8, d=fd;
	struct aio_queue *q = 0;
	pthread_rwlock_rdlock(&maplock);
	if ((!map || !map[a] || !map[a][b] || !map[a][b][c] || !(q=map[a][b][c][d])) && need) {
		pthread_rwlock_unlock(&maplock);
		if (fcntl(fd, F_GETFD) < 0) return 0;
		pthread_rwlock_wrlock(&maplock);
		if (!io_thread_stack_size) {
			unsigned long val = __getauxval(AT_MINSIGSTKSZ);
			io_thread_stack_size = MAX(MINSIGSTKSZ+2048, val+512);
		}
		if (!map) map = calloc(sizeof *map, (-1U/2+1)>>24);
		if (!map) goto out;
		if (!map[a]) map[a] = calloc(sizeof **map, 256);
		if (!map[a]) goto out;
		if (!map[a][b]) map[a][b] = calloc(sizeof ***map, 256);
		if (!map[a][b]) goto out;
		if (!map[a][b][c]) map[a][b][c] = calloc(sizeof ****map, 256);
		if (!map[a][b][c]) goto out;
		if (!(q = map[a][b][c][d])) {
			map[a][b][c][d] = q = calloc(sizeof *****map, 1);
			if (q) {
				q->fd = fd;
				pthread_mutex_init(&q->lock, 0);
				pthread_cond_init(&q->cond, 0);
				a_inc(&aio_fd_cnt);
			}
		}
	}
	if (q) pthread_mutex_lock(&q->lock);
out:
	pthread_rwlock_unlock(&maplock);
	return q;
}

static void __aio_unref_queue(struct aio_queue *q)
{
	if (q->ref > 1) {
		q->ref--;
		pthread_mutex_unlock(&q->lock);
		return;
	}

	/* This is potentially the last reference, but a new reference
	 * may arrive since we cannot free the queue object without first
	 * taking the maplock, which requires releasing the queue lock. */
	pthread_mutex_unlock(&q->lock);
	pthread_rwlock_wrlock(&maplock);
	pthread_mutex_lock(&q->lock);
	if (q->ref == 1) {
		int fd=q->fd;
		int a=fd>>24;
		unsigned char b=fd>>16, c=fd>>8, d=fd;
		map[a][b][c][d] = 0;
		a_dec(&aio_fd_cnt);
		pthread_rwlock_unlock(&maplock);
		pthread_mutex_unlock(&q->lock);
		free(q);
	} else {
		q->ref--;
		pthread_rwlock_unlock(&maplock);
		pthread_mutex_unlock(&q->lock);
	}
}

static void cleanup(void *ctx)
{
	struct aio_thread *at = ctx;
	struct aio_queue *q = at->q;
	struct aiocb *cb = at->cb;
	struct sigevent sev = cb->aio_sigevent;

	/* There are four potential types of waiters we could need to wake:
	 *   1. Callers of aio_cancel/close.
	 *   2. Callers of aio_suspend with a single aiocb.
	 *   3. Callers of aio_suspend with a list.
	 *   4. AIO worker threads waiting for sequenced operations.
	 * Types 1-3 are notified via atomics/futexes, mainly for AS-safety
	 * considerations. Type 4 is notified later via a cond var. */

	cb->__ret = at->ret;
	if (a_swap(&at->running, 0) < 0)
		__wake(&at->running, -1, 1);
	if (a_swap(&cb->__err, at->err) != EINPROGRESS)
		__wake(&cb->__err, -1, 1);
	if (a_swap(&__aio_fut, 0))
		__wake(&__aio_fut, -1, 1);

	pthread_mutex_lock(&q->lock);

	if (at->next) at->next->prev = at->prev;
	if (at->prev) at->prev->next = at->next;
	else q->head = at->next;

	/* Signal aio worker threads waiting for sequenced operations. */
	pthread_cond_broadcast(&q->cond);

	__aio_unref_queue(q);

	if (sev.sigev_notify == SIGEV_SIGNAL) {
		siginfo_t si = {
			.si_signo = sev.sigev_signo,
			.si_value = sev.sigev_value,
			.si_code = SI_ASYNCIO,
			.si_pid = getpid(),
			.si_uid = getuid()
		};
		__syscall(SYS_rt_sigqueueinfo, si.si_pid, si.si_signo, &si);
	}
	if (sev.sigev_notify == SIGEV_THREAD) {
		a_store(&__pthread_self()->cancel, 0);
		sev.sigev_notify_function(sev.sigev_value);
	}
}

static void *io_thread_func(void *ctx)
{
	struct aio_thread at, *p;

	struct aio_args *args = ctx;
	struct aiocb *cb = args->cb;
	int fd = cb->aio_fildes;
	int op = args->op;
	void *buf = (void *)cb->aio_buf;
	size_t len = cb->aio_nbytes;
	off_t off = cb->aio_offset;

	struct aio_queue *q = args->q;
	ssize_t ret;

	pthread_mutex_lock(&q->lock);
	sem_post(&args->sem);

	at.op = op;
	at.running = 1;
	at.ret = -1;
	at.err = ECANCELED;
	at.q = q;
	at.td = __pthread_self();
	at.cb = cb;
	at.prev = 0;
	if ((at.next = q->head)) at.next->prev = &at;
	q->head = &at;

	if (!q->init) {
		int seekable = lseek(fd, 0, SEEK_CUR) >= 0;
		q->seekable = seekable;
		q->append = !seekable || (fcntl(fd, F_GETFL) & O_APPEND);
		q->init = 1;
	}

	pthread_cleanup_push(cleanup, &at);

	/* Wait for sequenced operations. */
	if (op!=LIO_READ && (op!=LIO_WRITE || q->append)) {
		for (;;) {
			for (p=at.next; p && p->op!=LIO_WRITE; p=p->next);
			if (!p) break;
			pthread_cond_wait(&q->cond, &q->lock);
		}
	}

	pthread_mutex_unlock(&q->lock);

	switch (op) {
	case LIO_WRITE:
		ret = q->append ? write(fd, buf, len) : pwrite(fd, buf, len, off);
		break;
	case LIO_READ:
		ret = !q->seekable ? read(fd, buf, len) : pread(fd, buf, len, off);
		break;
	case O_SYNC:
		ret = fsync(fd);
		break;
	case O_DSYNC:
		ret = fdatasync(fd);
		break;
	}
	at.ret = ret;
	at.err = ret<0 ? errno : 0;
	
	pthread_cleanup_pop(1);

	return 0;
}

static int submit(struct aiocb *cb, int op)
{
	int ret = 0;
	pthread_attr_t a;
	sigset_t allmask, origmask;
	pthread_t td;
	struct aio_queue *q = __aio_get_queue(cb->aio_fildes, 1);
	struct aio_args args = { .cb = cb, .op = op, .q = q };
	sem_init(&args.sem, 0, 0);

	if (!q) {
		if (errno != EBADF) errno = EAGAIN;
		cb->__ret = -1;
		cb->__err = errno;
		return -1;
	}
	q->ref++;
	pthread_mutex_unlock(&q->lock);

	if (cb->aio_sigevent.sigev_notify == SIGEV_THREAD) {
		if (cb->aio_sigevent.sigev_notify_attributes)
			a = *cb->aio_sigevent.sigev_notify_attributes;
		else
			pthread_attr_init(&a);
	} else {
		pthread_attr_init(&a);
		pthread_attr_setstacksize(&a, io_thread_stack_size);
		pthread_attr_setguardsize(&a, 0);
	}
	pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED);
	sigfillset(&allmask);
	pthread_sigmask(SIG_BLOCK, &allmask, &origmask);
	cb->__err = EINPROGRESS;
	if (pthread_create(&td, &a, io_thread_func, &args)) {
		pthread_mutex_lock(&q->lock);
		__aio_unref_queue(q);
		cb->__err = errno = EAGAIN;
		cb->__ret = ret = -1;
	}
	pthread_sigmask(SIG_SETMASK, &origmask, 0);

	if (!ret) {
		while (sem_wait(&args.sem));
	}

	return ret;
}

int aio_read(struct aiocb *cb)
{
	return submit(cb, LIO_READ);
}

int aio_write(struct aiocb *cb)
{
	return submit(cb, LIO_WRITE);
}

int aio_fsync(int op, struct aiocb *cb)
{
	if (op != O_SYNC && op != O_DSYNC) {
		errno = EINVAL;
		return -1;
	}
	return submit(cb, op);
}

ssize_t aio_return(struct aiocb *cb)
{
	return cb->__ret;
}

int aio_error(const struct aiocb *cb)
{
	a_barrier();
	return cb->__err & 0x7fffffff;
}

int aio_cancel(int fd, struct aiocb *cb)
{
	sigset_t allmask, origmask;
	int ret = AIO_ALLDONE;
	struct aio_thread *p;
	struct aio_queue *q;

	/* Unspecified behavior case. Report an error. */
	if (cb && fd != cb->aio_fildes) {
		errno = EINVAL;
		return -1;
	}

	sigfillset(&allmask);
	pthread_sigmask(SIG_BLOCK, &allmask, &origmask);

	errno = ENOENT;
	if (!(q = __aio_get_queue(fd, 0))) {
		if (errno == EBADF) ret = -1;
		goto done;
	}

	for (p = q->head; p; p = p->next) {
		if (cb && cb != p->cb) continue;
		/* Transition target from running to running-with-waiters */
		if (a_cas(&p->running, 1, -1)) {
			pthread_cancel(p->td);
			__wait(&p->running, 0, -1, 1);
			if (p->err == ECANCELED) ret = AIO_CANCELED;
		}
	}

	pthread_mutex_unlock(&q->lock);
done:
	pthread_sigmask(SIG_SETMASK, &origmask, 0);
	return ret;
}

int __aio_close(int fd)
{
	a_barrier();
	if (aio_fd_cnt) aio_cancel(fd, 0);
	return fd;
}

void __aio_atfork(int who)
{
	if (who<0) {
		pthread_rwlock_rdlock(&maplock);
		return;
	}
	if (who>0 && map) for (int a=0; a<(-1U/2+1)>>24; a++)
		if (map[a]) for (int b=0; b<256; b++)
			if (map[a][b]) for (int c=0; c<256; c++)
				if (map[a][b][c]) for (int d=0; d<256; d++)
					map[a][b][c][d] = 0;
	pthread_rwlock_unlock(&maplock);
}

weak_alias(aio_cancel, aio_cancel64);
weak_alias(aio_error, aio_error64);
weak_alias(aio_fsync, aio_fsync64);
weak_alias(aio_read, aio_read64);
weak_alias(aio_write, aio_write64);
weak_alias(aio_return, aio_return64);
