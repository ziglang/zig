import os
from errno import EINTR
from resource import ffi, lib, _make_struct_rusage

__all__ = ["wait3", "wait4"]


def wait3(options):
    status = ffi.new("int *")
    ru = ffi.new("struct rusage *")
    while True:
        pid = lib.wait3(status, options, ru)
        if pid != -1:
            break
        errno = ffi.errno
        if errno != EINTR:
            raise OSError(errno, os.strerror(errno))

    rusage = _make_struct_rusage(ru)

    return pid, status[0], rusage

def wait4(pid, options):
    status = ffi.new("int *")
    ru = ffi.new("struct rusage *")
    while True:
        pid = lib.wait4(pid, status, options, ru)
        if pid != -1:
            break
        errno = ffi.errno
        if errno != EINTR:
            raise OSError(errno, os.strerror(errno))

    rusage = _make_struct_rusage(ru)

    return pid, status[0], rusage
