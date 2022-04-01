#-*- coding: utf-8 -*-

import sys, os
from cffi import FFI as _FFI

_ffi = _FFI()

_ffi.cdef("""
typedef int... mode_t;
int shm_open(const char *name, int oflag, mode_t mode);
int shm_unlink(const char *name);
""")

SOURCE = """
#include <sys/mman.h>
#include <sys/stat.h>        /* For mode constants */
#include <fcntl.h>           /* For O_* constants */
"""

if sys.platform == 'darwin':
    libraries = []
else:
    libraries=['rt']
_ffi.set_source("_posixshmem_cffi", SOURCE, libraries=libraries)


if __name__ == "__main__":
    _ffi.compile()
