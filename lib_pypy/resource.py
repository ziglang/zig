"""http://docs.python.org/library/resource"""

from _resource_cffi import ffi, lib
from errno import EINVAL, EPERM
import _structseq, os, sys

try:
    from __pypy__ import builtinify
except ImportError:
    builtinify = lambda f: f


error = OSError

class struct_rusage(metaclass=_structseq.structseqtype):
    """struct_rusage: Result from getrusage.

This object may be accessed either as a tuple of
    (utime,stime,maxrss,ixrss,idrss,isrss,minflt,majflt,
    nswap,inblock,oublock,msgsnd,msgrcv,nsignals,nvcsw,nivcsw)
or via the attributes ru_utime, ru_stime, ru_maxrss, and so on."""

    __metaclass__ = _structseq.structseqtype
    name = "resource.struct_rusage"

    ru_utime = _structseq.structseqfield(0,    "user time used")
    ru_stime = _structseq.structseqfield(1,    "system time used")
    ru_maxrss = _structseq.structseqfield(2,   "max. resident set size")
    ru_ixrss = _structseq.structseqfield(3,    "shared memory size")
    ru_idrss = _structseq.structseqfield(4,    "unshared data size")
    ru_isrss = _structseq.structseqfield(5,    "unshared stack size")
    ru_minflt = _structseq.structseqfield(6,   "page faults not requiring I/O")
    ru_majflt = _structseq.structseqfield(7,   "page faults requiring I/O")
    ru_nswap = _structseq.structseqfield(8,    "number of swap outs")
    ru_inblock = _structseq.structseqfield(9,  "block input operations")
    ru_oublock = _structseq.structseqfield(10, "block output operations")
    ru_msgsnd = _structseq.structseqfield(11,  "IPC messages sent")
    ru_msgrcv = _structseq.structseqfield(12,  "IPC messages received")
    ru_nsignals = _structseq.structseqfield(13, "signals received")
    ru_nvcsw = _structseq.structseqfield(14,   "voluntary context switches")
    ru_nivcsw = _structseq.structseqfield(15,  "involuntary context switches")

def _make_struct_rusage(ru):
    return struct_rusage((
        lib.my_utime(ru),
        lib.my_stime(ru),
        ru.ru_maxrss,
        ru.ru_ixrss,
        ru.ru_idrss,
        ru.ru_isrss,
        ru.ru_minflt,
        ru.ru_majflt,
        ru.ru_nswap,
        ru.ru_inblock,
        ru.ru_oublock,
        ru.ru_msgsnd,
        ru.ru_msgrcv,
        ru.ru_nsignals,
        ru.ru_nvcsw,
        ru.ru_nivcsw,
    ))

@builtinify
def getrusage(who):
    ru = ffi.new("struct rusage *")
    if lib.getrusage(who, ru) == -1:
        if ffi.errno == EINVAL:
            raise ValueError("invalid who parameter")
        raise OSError(ffi.errno, os.strerror(ffi.errno))
    return _make_struct_rusage(ru)

@builtinify
def getrlimit(resource):
    if not (0 <= resource < lib.RLIM_NLIMITS):
        return ValueError("invalid resource specified")

    result = ffi.new("long long[2]")
    if lib.my_getrlimit(resource, result) == -1:
        raise OSError(ffi.errno, os.strerror(ffi.errno))
    return (result[0], result[1])

@builtinify
def setrlimit(resource, limits):
    if not (0 <= resource < lib.RLIM_NLIMITS):
        return ValueError("invalid resource specified")

    limits = tuple(limits)
    if len(limits) != 2:
        raise ValueError("expected a tuple of 2 integers")

    # accept and round down floats, like CPython does
    limit0 = int(limits[0])
    limit1 = int(limits[1])

    if lib.my_setrlimit(resource, limit0, limit1) == -1:
        if ffi.errno == EINVAL:
            raise ValueError("current limit exceeds maximum limit")
        elif ffi.errno == EPERM:
            raise ValueError("not allowed to raise maximum limit")
        else:
            raise OSError(ffi.errno, os.strerror(ffi.errno))

if sys.platform.startswith("linux") and hasattr(lib, '_prlimit'):
    @builtinify
    def prlimit(pid, resource, limits = None):
        if not (0 <= resource < lib.RLIM_NLIMITS):
            return ValueError("invalid resource specified")

        if limits is not None:
            limits = tuple(limits)
            if len(limits) != 2:
                raise ValueError("expected a tuple of 2 integers")

            # accept and round down floats, like CPython does
            limit0 = int(limits[0])
            limit1 = int(limits[1])
        else:
            limit0 = 0
            limit1 = 0

        result = ffi.new("long long[2]")

        if lib._prlimit(pid, resource, limits is not None, limit0, limit1, result) == -1:
            if ffi.errno == EINVAL:
                raise ValueError("current limit exceeds maximum limit")
            else:
                raise OSError(ffi.errno, os.strerror(ffi.errno))

        return (result[0], result[1])


@builtinify
def getpagesize():
    return os.sysconf("SC_PAGESIZE")


def _setup():
    all_constants = []
    p = lib.my_rlimit_consts
    while p.name:
        name = ffi.string(p.name).decode()
        globals()[name] = int(p.value)
        all_constants.append(name)
        p += 1
    return all_constants

__all__ = tuple(_setup()) + (
    'error', 'getpagesize', 'struct_rusage',
    'getrusage', 'getrlimit', 'setrlimit',
)
del _setup
