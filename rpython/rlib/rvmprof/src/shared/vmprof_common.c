#include "vmprof_common.h"

#include <assert.h>
#include <errno.h>

#ifdef RPYTHON_VMPROF

int get_stack_trace(PY_THREAD_STATE_T * current, void** result, int max_depth, intptr_t pc);

#ifdef RPYTHON_LL2CTYPES
   /* only for testing: ll2ctypes sets RPY_EXTERN from the command-line */

#else
#  include "common_header.h"
#  include "structdef.h"
#  include "src/threadlocal.h"
#  include "rvmprof.h"
#  include "forwarddecl.h"
#endif
#endif

#ifdef VMP_SUPPORTS_NATIVE_PROFILING
#include "vmp_stack.h" // reduces warings
#endif


static volatile int is_enabled = 0;
static long prepare_interval_usec = 0;
static long profile_interval_usec = 0;

#ifdef VMPROF_UNIX
static int signal_type = SIGPROF;
static int itimer_type = ITIMER_PROF;
static pthread_t *threads = NULL;
static size_t threads_size = 0;
static size_t thread_count = 0;
static size_t threads_size_step = 8;

int vmprof_get_itimer_type(void) {
    return itimer_type;
}

int vmprof_get_signal_type(void) {
    return signal_type;
}
#endif

#ifdef VMPROF_WINDOWS
#include "vmprof_win.h"
#endif


int vmprof_is_enabled(void) {
    return is_enabled;
}

void vmprof_set_enabled(int value) {
    is_enabled = value;
}

long vmprof_get_prepare_interval_usec(void) {
    return prepare_interval_usec;
}

long vmprof_get_profile_interval_usec(void) {
    return profile_interval_usec;
}

void vmprof_set_prepare_interval_usec(long value) {
    prepare_interval_usec = value;
}

void vmprof_set_profile_interval_usec(long value) {
    profile_interval_usec = value;
}

char *vmprof_init(int fd, double interval, int memory,
                  int proflines, const char *interp_name, int native, int real_time)
{
    if (!(interval >= 1e-6 && interval < 1.0)) {   /* also if it is NaN */
        return "bad value for 'interval'";
    }
    prepare_interval_usec = (int)(interval * 1000000.0);

    if (prepare_concurrent_bufs() < 0)
        return "out of memory";
#if VMPROF_UNIX
    if (real_time) {
        signal_type = SIGALRM;
        itimer_type = ITIMER_REAL;
    } else {
        signal_type = SIGPROF;
        itimer_type = ITIMER_PROF;
    }
    set_current_codes(NULL);
    assert(fd >= 0);
#else
    if (memory) {
        return "memory tracking only supported on unix";
    }
    if (native) {
        return "native profiling only supported on unix";
    }
#endif
    vmp_set_profile_fileno(fd);
    if (opened_profile(interp_name, memory, proflines, native, real_time) < 0) {
        vmp_set_profile_fileno(0);
        return strerror(errno);
    }
    return NULL;
}

int opened_profile(const char *interp_name, int memory, int proflines, int native, int real_time)
{
    int success;
    int bits;
    struct {
        long hdr[5];
        char interp_name[259];
    } header;

    const char * machine;
    size_t namelen = strnlen(interp_name, 255);

    machine = vmp_machine_os_name();

    header.hdr[0] = 0;
    header.hdr[1] = 3;
    header.hdr[2] = 0;
    header.hdr[3] = prepare_interval_usec;
    if (strstr(machine, "win64") != 0) {
        header.hdr[4] = 1;
    } else {
        header.hdr[4] = 0;
    }
    header.interp_name[0] = MARKER_HEADER;
    header.interp_name[1] = '\x00';
    header.interp_name[2] = VERSION_TIMESTAMP;
    header.interp_name[3] = memory*PROFILE_MEMORY + proflines*PROFILE_LINES + \
                            native*PROFILE_NATIVE + real_time*PROFILE_REAL_TIME;
#ifdef RPYTHON_VMPROF
    header.interp_name[3] += PROFILE_RPYTHON;
#endif
    header.interp_name[4] = (char)namelen;

    memcpy(&header.interp_name[5], interp_name, namelen);
    success = vmp_write_all((char*)&header, 5 * sizeof(long) + 5 + namelen);
    if (success < 0) {
        return success;
    }

    /* Write the time and the zone to the log file, profiling will start now */
    (void)vmp_write_time_now(MARKER_TIME_N_ZONE);

    /* write some more meta information */
    vmp_write_meta("os", machine);
    bits = vmp_machine_bits();
    if (bits == 64) {
        vmp_write_meta("bits", "64");
    } else if (bits == 32) {
        vmp_write_meta("bits", "32");
    }

    return success;
}


#ifdef RPYTHON_VMPROF
#ifndef RPYTHON_LL2CTYPES
PY_STACK_FRAME_T *get_vmprof_stack(void)
{
    struct pypy_threadlocal_s *tl;
    _OP_THREADLOCALREF_ADDR_SIGHANDLER(tl);
    if (tl == NULL) {
        return NULL;
    } else {
        return tl->vmprof_tl_stack;
    }
}
#else
PY_STACK_FRAME_T *get_vmprof_stack(void)
{
    return 0;
}
#endif

intptr_t vmprof_get_traceback(void *stack, void *ucontext,
                              void **result_p, intptr_t result_length)
{
    int n;
    int enabled;
#ifdef VMPROF_WINDOWS
    intptr_t pc = 0;   /* XXX implement me */
#else
    intptr_t pc = ucontext ? (intptr_t)GetPC((ucontext_t *)ucontext) : 0;
#endif
    if (stack == NULL) {
        stack = get_vmprof_stack();
    }
#ifdef VMP_SUPPORTS_NATIVE_PROFILING
    enabled = vmp_native_enabled();
    vmp_native_disable();
#endif
    n = get_stack_trace(stack, result_p, result_length - 2, pc);
#ifdef VMP_SUPPORTS_NATIVE_PROFILING
    if (enabled) {
        vmp_native_enable();
    }
#endif
    return (intptr_t)n;
}
#endif

#ifdef VMPROF_UNIX

ssize_t search_thread(pthread_t tid, ssize_t i)
{
    if (i < 0)
        i = 0;
    while ((size_t)i < thread_count) {
        if (pthread_equal(threads[i], tid))
            return i;
        i++;
    }
    return -1;
}

ssize_t insert_thread(pthread_t tid, ssize_t i)
{
    assert(signal_type == SIGALRM);
    i = search_thread(tid, i);
    if (i > 0)
        return -1;
    if (thread_count == threads_size) {
        threads_size += threads_size_step;
        threads = realloc(threads, sizeof(pthread_t) * threads_size);
        assert(threads != NULL);
        memset(threads + thread_count, 0, sizeof(pthread_t) * threads_size_step);
    }
    threads[thread_count++] = tid;
    return thread_count;
}

ssize_t remove_thread(pthread_t tid, ssize_t i)
{
    assert(signal_type == SIGALRM);
    if (thread_count == 0)
        return -1;
    if (threads == NULL)
        return -1;
    i = search_thread(tid, i);
    if (i < 0)
        return -1;
    threads[i] = threads[--thread_count];
    threads[thread_count] = 0;
    return thread_count;
}

ssize_t remove_threads(void)
{
    assert(signal_type == SIGALRM);
    if (threads != NULL) {
        free(threads);
        threads = NULL;
    }
    thread_count = 0;
    threads_size = 0;
    return 0;
}

int broadcast_signal_for_threads(void)
{
    int done = 1;
    size_t i = 0;
    pthread_t self = pthread_self();
    pthread_t tid;
    while (i < thread_count) {
        tid = threads[i];
        if (pthread_equal(tid, self)) {
            done = 0;
        } else if (pthread_kill(tid, SIGALRM)) {
            remove_thread(tid, i);
        }
        i++;
    }
    return done;
}

int is_main_thread(void)
{
#ifdef VMPROF_LINUX
    pid_t pid = getpid();
    pid_t tid = (pid_t) syscall(SYS_gettid);
    return (pid == tid);
#elif defined(VMPROF_APPLE)
    return pthread_main_np();
#endif
}

#endif
