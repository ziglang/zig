from cffi import FFI
from ctypes import util, CDLL
import sys

ffi = FFI()

# Note: we don't directly expose 'struct timeval' or 'struct rlimit'


rlimit_consts = '''
RLIMIT_CPU
RLIMIT_FSIZE
RLIMIT_DATA
RLIMIT_STACK
RLIMIT_CORE
RLIMIT_NOFILE
RLIMIT_OFILE
RLIMIT_VMEM
RLIMIT_AS
RLIMIT_RSS
RLIMIT_NPROC
RLIMIT_MEMLOCK
RLIMIT_SBSIZE
RLIM_INFINITY
RUSAGE_SELF
RUSAGE_CHILDREN
RUSAGE_BOTH
'''.split()

rlimit_consts = ['#ifdef %s\n\t{"%s", %s},\n#endif\n' % (s, s, s)
                 for s in rlimit_consts]

src = """
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/wait.h>

const struct my_rlimit_def {
    const char *name;
    long long value;
} my_rlimit_consts[] = {
$RLIMIT_CONSTS
    { NULL, 0 }
};

#define doubletime(TV) ((double)(TV).tv_sec + (TV).tv_usec * 0.000001)

static double my_utime(struct rusage *input)
{
    return doubletime(input->ru_utime);
}

static double my_stime(struct rusage *input)
{
    return doubletime(input->ru_stime);
}

static int my_getrlimit(int resource, long long result[2])
{
    struct rlimit rl;
    if (getrlimit(resource, &rl) == -1)
        return -1;
    result[0] = rl.rlim_cur;
    result[1] = rl.rlim_max;
    return 0;
}

static int my_setrlimit(int resource, long long cur, long long max)
{
    struct rlimit rl;
    rl.rlim_cur = cur & RLIM_INFINITY;
    rl.rlim_max = max & RLIM_INFINITY;
    return setrlimit(resource, &rl);
}
""".replace('$RLIMIT_CONSTS', ''.join(rlimit_consts))


ffi.cdef("""

#define RLIM_NLIMITS ...

extern const struct my_rlimit_def {
    const char *name;
    long long value;
} my_rlimit_consts[];

struct rusage {
    long ru_maxrss;
    long ru_ixrss;
    long ru_idrss;
    long ru_isrss;
    long ru_minflt;
    long ru_majflt;
    long ru_nswap;
    long ru_inblock;
    long ru_oublock;
    long ru_msgsnd;
    long ru_msgrcv;
    long ru_nsignals;
    long ru_nvcsw;
    long ru_nivcsw;
    ...;
};

static double my_utime(struct rusage *);
static double my_stime(struct rusage *);
void getrusage(int who, struct rusage *result);
int my_getrlimit(int resource, long long result[2]);
int my_setrlimit(int resource, long long cur, long long max);

int wait3(int *status, int options, struct rusage *rusage);
int wait4(int pid, int *status, int options, struct rusage *rusage);
""")


libname = util.find_library('c')
glibc = CDLL(util.find_library('c'))
if hasattr(glibc, 'prlimit'):
    src += """

static int _prlimit(int pid, int resource, int set, long long cur, long long max, long long result[2])
{
    struct rlimit new_rl, old_rl;
    new_rl.rlim_cur = cur & RLIM_INFINITY;
    new_rl.rlim_max = max & RLIM_INFINITY;

    if(prlimit(pid, resource, (set ? &new_rl : NULL), &old_rl) == -1)
        return -1;

    result[0] = old_rl.rlim_cur;
    result[1] = old_rl.rlim_max;
    return 0;
}
"""
    ffi.cdef("""
int _prlimit(int pid, int resource, int set, long long cur, long long max, long long result[2]);
""")

ffi.set_source("_resource_cffi", src)

if __name__ == "__main__":
    ffi.compile()
