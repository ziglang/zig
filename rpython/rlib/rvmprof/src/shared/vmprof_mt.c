#include "vmprof_mt.h"
/* Support for multithreaded write() operations (implementation) */

#include <assert.h>

#if defined(__i386__) || defined(__amd64__)
  static inline void write_fence(void) { asm("" : : : "memory"); }
#else
  static inline void write_fence(void) { __sync_synchronize(); }
#endif

static char volatile profbuf_state[MAX_NUM_BUFFERS];
static struct profbuf_s *profbuf_all_buffers = NULL;
static int volatile profbuf_write_lock = 2;
static long profbuf_pending_write;


static void unprepare_concurrent_bufs(void)
{
    if (profbuf_all_buffers != NULL) {
        munmap(profbuf_all_buffers, sizeof(struct profbuf_s) * MAX_NUM_BUFFERS);
        profbuf_all_buffers = NULL;
    }
}

int prepare_concurrent_bufs(void)
{
    assert(sizeof(struct profbuf_s) == 8192);

    unprepare_concurrent_bufs();
    profbuf_all_buffers = mmap(NULL, sizeof(struct profbuf_s) * MAX_NUM_BUFFERS,
                               PROT_READ | PROT_WRITE,
                               MAP_PRIVATE | MAP_ANONYMOUS,
                               -1, 0);
    if (profbuf_all_buffers == MAP_FAILED) {
        profbuf_all_buffers = NULL;
        return -1;
    }
    memset((char *)profbuf_state, PROFBUF_UNUSED, sizeof(profbuf_state));
    profbuf_write_lock = 0;
    profbuf_pending_write = -1;
    return 0;
}

static int _write_single_ready_buffer(int fd, long i)
{
    /* Try to write to disk the buffer number 'i'.  This function must
       only be called while we hold the write lock. */
    assert(profbuf_write_lock != 0);

    if (profbuf_pending_write >= 0) {
        /* A partially written buffer is waiting.  We'll write the
           rest of this buffer now, instead of 'i'. */
        i = profbuf_pending_write;
        assert(profbuf_state[i] == PROFBUF_READY);
    }

    if (profbuf_state[i] != PROFBUF_READY) {
        /* this used to be a race condition: the buffer was written by a
           different thread already, nothing to do now */
        return 0;
    }

    int err;
    struct profbuf_s *p = &profbuf_all_buffers[i];
    ssize_t count = write(fd, p->data + p->data_offset, p->data_size);
    if (count == p->data_size) {
        profbuf_state[i] = PROFBUF_UNUSED;
        profbuf_pending_write = -1;
    }
    else {
        if (count > 0) {
            p->data_offset += count;
            p->data_size -= count;
        }
        profbuf_pending_write = i;
        if (count < 0)
            return -1;
    }
    return 0;
}

static void _write_ready_buffers(int fd)
{
    long i;
    int has_write_lock = 0;

    for (i = 0; i < MAX_NUM_BUFFERS; i++) {
        if (profbuf_state[i] == PROFBUF_READY) {
            if (!has_write_lock) {
                if (!__sync_bool_compare_and_swap(&profbuf_write_lock, 0, 1))
                    return;   /* can't acquire the write lock, give up */
                has_write_lock = 1;
            }
            if (_write_single_ready_buffer(fd, i) < 0)
                break;
        }
    }
    if (has_write_lock)
        profbuf_write_lock = 0;
}

struct profbuf_s *reserve_buffer(int fd)
{
    /* Tries to enter a region of code that fills one buffer.  If
       successful, returns the profbuf_s.  It fails only if the
       concurrent buffers are all busy (extreme multithreaded usage).

       This might call write() to emit the data sitting in
       previously-prepared buffers.  In case of write() error, the
       error is ignored but unwritten data stays in the buffers.
    */
    long i;

    _write_ready_buffers(fd);

    for (i = 0; i < MAX_NUM_BUFFERS; i++) {
        if (profbuf_state[i] == PROFBUF_UNUSED &&
            __sync_bool_compare_and_swap(&profbuf_state[i], PROFBUF_UNUSED,
                                         PROFBUF_FILLING)) {
            struct profbuf_s *p = &profbuf_all_buffers[i];
            p->data_size = 0;
            p->data_offset = 0;
            return p;
        }
    }
    /* no unused buffer found */
    return NULL;
}

void commit_buffer(int fd, struct profbuf_s *buf)
{
    /* Leaves a region of code that filled 'buf'.

       This might call write() to emit the data now ready.  In case of
       write() error, the error is ignored but unwritten data stays in
       the buffers.
    */

    /* Make sure every thread sees the full content of 'buf' */
    write_fence();

    /* Then set the 'ready' flag */
    long i = buf - profbuf_all_buffers;
    assert(profbuf_state[i] == PROFBUF_FILLING);
    profbuf_state[i] = PROFBUF_READY;

    if (!__sync_bool_compare_and_swap(&profbuf_write_lock, 0, 1)) {
        /* can't acquire the write lock, ignore */
    }
    else {
        _write_single_ready_buffer(fd, i);
        profbuf_write_lock = 0;
    }
}

void cancel_buffer(struct profbuf_s *buf)
{
    long i = buf - profbuf_all_buffers;
    assert(profbuf_state[i] == PROFBUF_FILLING);
    profbuf_state[i] = PROFBUF_UNUSED;
}

int shutdown_concurrent_bufs(int fd)
{
    /* no signal handler can be running concurrently here, because we
       already did vmprof_ignore_signals(1) */
    assert(profbuf_write_lock == 0);
    profbuf_write_lock = 2;

    /* last attempt to flush buffers */
    int i;
    for (i = 0; i < MAX_NUM_BUFFERS; i++) {
        while (profbuf_state[i] == PROFBUF_READY) {
            if (_write_single_ready_buffer(fd, i) < 0)
                return -1;
        }
    }
    unprepare_concurrent_bufs();
    return 0;
}
