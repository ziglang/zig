#include <unistd.h>
#include <limits.h>
#include <errno.h>
#ifdef __wasilibc_unmodified_upstream // WASI has no process-level accounting
#include <sys/resource.h>
#endif
#ifdef __wasilibc_unmodified_upstream // WASI has no realtime signals
#include <signal.h>
#endif
#include <sys/sysinfo.h>
#ifdef __wasilibc_unmodified_upstream
#include "syscall.h"
#endif
#include "libc.h"

#define JT(x) (-256|(x))
#define VER JT(1)
#define JT_ARG_MAX JT(2)
#ifdef __wasilibc_unmodified_upstream // WASI has no mq
#define JT_MQ_PRIO_MAX JT(3)
#endif
#define JT_PAGE_SIZE JT(4)
#ifdef __wasilibc_unmodified_upstream // WASI has no semaphores
#define JT_SEM_VALUE_MAX JT(5)
#endif
#define JT_NPROCESSORS_CONF JT(6)
#define JT_NPROCESSORS_ONLN JT(7)
#define JT_PHYS_PAGES JT(8)
#define JT_AVPHYS_PAGES JT(9)
#define JT_ZERO JT(10)
#define JT_DELAYTIMER_MAX JT(11)

#define RLIM(x) (-32768|(RLIMIT_ ## x))

long sysconf(int name)
{
	static const short values[] = {
		[_SC_ARG_MAX] = JT_ARG_MAX,
#ifdef __wasilibc_unmodified_upstream // WASI has no processes
		[_SC_CHILD_MAX] = RLIM(NPROC),
#else
		// Not supported on wasi.
		[_SC_CHILD_MAX] = -1,
#endif
		[_SC_CLK_TCK] = 100,
		[_SC_NGROUPS_MAX] = 32,
#ifdef __wasilibc_unmodified_upstream // WASI has no rlimit
		[_SC_OPEN_MAX] = RLIM(NOFILE),
#else
		// Rlimit is not supported on wasi.
		[_SC_OPEN_MAX] = -1,
#endif

		[_SC_STREAM_MAX] = -1,
		[_SC_TZNAME_MAX] = TZNAME_MAX,
		[_SC_JOB_CONTROL] = 1,
		[_SC_SAVED_IDS] = 1,
		[_SC_REALTIME_SIGNALS] = VER,
		[_SC_PRIORITY_SCHEDULING] = -1,
		[_SC_TIMERS] = VER,
		[_SC_ASYNCHRONOUS_IO] = VER,
		[_SC_PRIORITIZED_IO] = -1,
		[_SC_SYNCHRONIZED_IO] = -1,
		[_SC_FSYNC] = VER,
		[_SC_MAPPED_FILES] = VER,
		[_SC_MEMLOCK] = VER,
		[_SC_MEMLOCK_RANGE] = VER,
		[_SC_MEMORY_PROTECTION] = VER,
		[_SC_MESSAGE_PASSING] = VER,
		[_SC_SEMAPHORES] = VER,
		[_SC_SHARED_MEMORY_OBJECTS] = VER,
		[_SC_AIO_LISTIO_MAX] = -1,
		[_SC_AIO_MAX] = -1,
		[_SC_AIO_PRIO_DELTA_MAX] = JT_ZERO, /* ?? */
		[_SC_DELAYTIMER_MAX] = JT_DELAYTIMER_MAX,
#ifdef __wasilibc_unmodified_upstream // WASI has no mq
		[_SC_MQ_OPEN_MAX] = -1,
		[_SC_MQ_PRIO_MAX] = JT_MQ_PRIO_MAX,
#endif
		[_SC_VERSION] = VER,
		[_SC_PAGE_SIZE] = JT_PAGE_SIZE,
#ifdef __wasilibc_unmodified_upstream // WASI has no realtime signals
		[_SC_RTSIG_MAX] = _NSIG - 1 - 31 - 3,
#else
		// Not supported on wasi.
		[_SC_RTSIG_MAX] = -1,
#endif
#ifdef __wasilibc_unmodified_upstream // WASI has no semaphores
		[_SC_SEM_NSEMS_MAX] = SEM_NSEMS_MAX,
		[_SC_SEM_VALUE_MAX] = JT_SEM_VALUE_MAX,
#else
		[_SC_SEM_NSEMS_MAX] = -1,
		[_SC_SEM_VALUE_MAX] = -1,
#endif
		[_SC_SIGQUEUE_MAX] = -1,
		[_SC_TIMER_MAX] = -1,
#ifdef __wasilibc_unmodified_upstream // WASI has no shell commands
		[_SC_BC_BASE_MAX] = _POSIX2_BC_BASE_MAX,
		[_SC_BC_DIM_MAX] = _POSIX2_BC_DIM_MAX,
		[_SC_BC_SCALE_MAX] = _POSIX2_BC_SCALE_MAX,
		[_SC_BC_STRING_MAX] = _POSIX2_BC_STRING_MAX,
#else
		[_SC_BC_BASE_MAX] = -1,
		[_SC_BC_DIM_MAX] = -1,
		[_SC_BC_SCALE_MAX] = -1,
		[_SC_BC_STRING_MAX] = -1,
#endif
		[_SC_COLL_WEIGHTS_MAX] = COLL_WEIGHTS_MAX,
		[_SC_EXPR_NEST_MAX] = -1,
		[_SC_LINE_MAX] = -1,
		[_SC_RE_DUP_MAX] = RE_DUP_MAX,
		[_SC_2_VERSION] = VER,
		[_SC_2_C_BIND] = VER,
		[_SC_2_C_DEV] = -1,
		[_SC_2_FORT_DEV] = -1,
		[_SC_2_FORT_RUN] = -1,
		[_SC_2_SW_DEV] = -1,
		[_SC_2_LOCALEDEF] = -1,
		[_SC_IOV_MAX] = IOV_MAX,
		[_SC_THREADS] = VER,
		[_SC_THREAD_SAFE_FUNCTIONS] = VER,
		[_SC_GETGR_R_SIZE_MAX] = -1,
		[_SC_GETPW_R_SIZE_MAX] = -1,
		[_SC_LOGIN_NAME_MAX] = 256,
		[_SC_TTY_NAME_MAX] = TTY_NAME_MAX,
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
		[_SC_THREAD_DESTRUCTOR_ITERATIONS] = PTHREAD_DESTRUCTOR_ITERATIONS,
		[_SC_THREAD_KEYS_MAX] = PTHREAD_KEYS_MAX,
		[_SC_THREAD_STACK_MIN] = PTHREAD_STACK_MIN,
#else
		[_SC_THREAD_DESTRUCTOR_ITERATIONS] = -1,
		[_SC_THREAD_KEYS_MAX] = -1,
		[_SC_THREAD_STACK_MIN] = -1,
#endif
		[_SC_THREAD_THREADS_MAX] = -1,
		[_SC_THREAD_ATTR_STACKADDR] = VER,
		[_SC_THREAD_ATTR_STACKSIZE] = VER,
		[_SC_THREAD_PRIORITY_SCHEDULING] = VER,
		[_SC_THREAD_PRIO_INHERIT] = -1,
		[_SC_THREAD_PRIO_PROTECT] = -1,
		[_SC_THREAD_PROCESS_SHARED] = VER,
		[_SC_NPROCESSORS_CONF] = JT_NPROCESSORS_CONF,
		[_SC_NPROCESSORS_ONLN] = JT_NPROCESSORS_ONLN,
		[_SC_PHYS_PAGES] = JT_PHYS_PAGES,
		[_SC_AVPHYS_PAGES] = JT_AVPHYS_PAGES,
		[_SC_ATEXIT_MAX] = -1,
		[_SC_PASS_MAX] = -1,
		[_SC_XOPEN_VERSION] = _XOPEN_VERSION,
		[_SC_XOPEN_XCU_VERSION] = _XOPEN_VERSION,
		[_SC_XOPEN_UNIX] = 1,
		[_SC_XOPEN_CRYPT] = -1,
		[_SC_XOPEN_ENH_I18N] = 1,
		[_SC_XOPEN_SHM] = 1,
		[_SC_2_CHAR_TERM] = -1,
		[_SC_2_UPE] = -1,
		[_SC_XOPEN_XPG2] = -1,
		[_SC_XOPEN_XPG3] = -1,
		[_SC_XOPEN_XPG4] = -1,
		[_SC_NZERO] = NZERO,
		[_SC_XBS5_ILP32_OFF32] = -1,
		[_SC_XBS5_ILP32_OFFBIG] = sizeof(long)==4 ? 1 : -1,
		[_SC_XBS5_LP64_OFF64] = sizeof(long)==8 ? 1 : -1,
		[_SC_XBS5_LPBIG_OFFBIG] = -1,
		[_SC_XOPEN_LEGACY] = -1,
		[_SC_XOPEN_REALTIME] = -1,
		[_SC_XOPEN_REALTIME_THREADS] = -1,
		[_SC_ADVISORY_INFO] = VER,
		[_SC_BARRIERS] = VER,
		[_SC_CLOCK_SELECTION] = VER,
		[_SC_CPUTIME] = VER,
		[_SC_THREAD_CPUTIME] = VER,
		[_SC_MONOTONIC_CLOCK] = VER,
		[_SC_READER_WRITER_LOCKS] = VER,
		[_SC_SPIN_LOCKS] = VER,
		[_SC_REGEXP] = 1,
		[_SC_SHELL] = 1,
		[_SC_SPAWN] = VER,
		[_SC_SPORADIC_SERVER] = -1,
		[_SC_THREAD_SPORADIC_SERVER] = -1,
		[_SC_TIMEOUTS] = VER,
		[_SC_TYPED_MEMORY_OBJECTS] = -1,
		[_SC_2_PBS] = -1,
		[_SC_2_PBS_ACCOUNTING] = -1,
		[_SC_2_PBS_LOCATE] = -1,
		[_SC_2_PBS_MESSAGE] = -1,
		[_SC_2_PBS_TRACK] = -1,
		[_SC_SYMLOOP_MAX] = SYMLOOP_MAX,
		[_SC_STREAMS] = JT_ZERO,
		[_SC_2_PBS_CHECKPOINT] = -1,
		[_SC_V6_ILP32_OFF32] = -1,
		[_SC_V6_ILP32_OFFBIG] = sizeof(long)==4 ? 1 : -1,
		[_SC_V6_LP64_OFF64] = sizeof(long)==8 ? 1 : -1,
		[_SC_V6_LPBIG_OFFBIG] = -1,
		[_SC_HOST_NAME_MAX] = HOST_NAME_MAX,
		[_SC_TRACE] = -1,
		[_SC_TRACE_EVENT_FILTER] = -1,
		[_SC_TRACE_INHERIT] = -1,
		[_SC_TRACE_LOG] = -1,

		[_SC_IPV6] = VER,
		[_SC_RAW_SOCKETS] = VER,
		[_SC_V7_ILP32_OFF32] = -1,
		[_SC_V7_ILP32_OFFBIG] = sizeof(long)==4 ? 1 : -1,
		[_SC_V7_LP64_OFF64] = sizeof(long)==8 ? 1 : -1,
		[_SC_V7_LPBIG_OFFBIG] = -1,
		[_SC_SS_REPL_MAX] = -1,
		[_SC_TRACE_EVENT_NAME_MAX] = -1,
		[_SC_TRACE_NAME_MAX] = -1,
		[_SC_TRACE_SYS_MAX] = -1,
		[_SC_TRACE_USER_EVENT_MAX] = -1,
		[_SC_XOPEN_STREAMS] = JT_ZERO,
		[_SC_THREAD_ROBUST_PRIO_INHERIT] = -1,
		[_SC_THREAD_ROBUST_PRIO_PROTECT] = -1,
	};

	if (name >= sizeof(values)/sizeof(values[0]) || !values[name]) {
		errno = EINVAL;
		return -1;
	} else if (values[name] >= -1) {
		return values[name];
	} else if (values[name] < -256) {
#ifdef __wasilibc_unmodified_upstream // WASI has no getrlimit
		struct rlimit lim;
		getrlimit(values[name]&16383, &lim);
		if (lim.rlim_cur == RLIM_INFINITY)
			return -1;
		return lim.rlim_cur > LONG_MAX ? LONG_MAX : lim.rlim_cur;
#else
		// Not supported on wasi.
		errno = EINVAL;
		return -1;
#endif
	}

	switch ((unsigned char)values[name]) {
	case VER & 255:
		return _POSIX_VERSION;
	case JT_ARG_MAX & 255:
		return ARG_MAX;
#ifdef __wasilibc_unmodified_upstream // WASI has no mq
	case JT_MQ_PRIO_MAX & 255:
		return MQ_PRIO_MAX;
#endif
	case JT_PAGE_SIZE & 255:
		return PAGE_SIZE;
#ifdef __wasilibc_unmodified_upstream // WASI has no semaphores
	case JT_SEM_VALUE_MAX & 255:
		return SEM_VALUE_MAX;
#endif
	case JT_DELAYTIMER_MAX & 255:
		return DELAYTIMER_MAX;
	case JT_NPROCESSORS_CONF & 255:
	case JT_NPROCESSORS_ONLN & 255: ;
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
		unsigned char set[128] = {1};
		int i, cnt;
		__syscall(SYS_sched_getaffinity, 0, sizeof set, set);
		for (i=cnt=0; i<sizeof set; i++)
			for (; set[i]; set[i]&=set[i]-1, cnt++);
		return cnt;
#else
		// With no thread support, just say there's 1 processor.
		return 1;
#endif
#ifdef __wasilibc_unmodified_upstream // WASI has no sysinfo
	case JT_PHYS_PAGES & 255:
	case JT_AVPHYS_PAGES & 255: ;
		unsigned long long mem;
		struct sysinfo si;
		__lsysinfo(&si);
		if (!si.mem_unit) si.mem_unit = 1;
		if (name==_SC_PHYS_PAGES) mem = si.totalram;
		else mem = si.freeram + si.bufferram;
		mem *= si.mem_unit;
		mem /= PAGE_SIZE;
		return (mem > LONG_MAX) ? LONG_MAX : mem;
#endif
	case JT_ZERO & 255:
		return 0;
	}
	return values[name];
}
