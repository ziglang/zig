'POSIX shared memory module'

from _posixshmem_cffi import lib, ffi

import errno
import os

def shm_open(path, flags, mode=0o777):
    'Open a shared memory object.  Returns a file descriptor (integer).'
    path_utf8 = path.encode("utf-8")
    while 1:
        fd = lib.shm_open(path_utf8, flags, mode)
        if fd < 0:
            e = ffi.errno
            if e != errno.EINTR:
                raise OSError(e, os.strerror(e))
        else:
            return fd

def shm_unlink(path):
    '''Remove a shared memory object (similar to unlink()).

Remove a shared memory object name, and, once all processes  have  unmapped
the object, de-allocates and destroys the contents of the associated memory
region.
    '''

    path_utf8 = path.encode("utf-8")
    while 1:
        rv = lib.shm_unlink(path_utf8)
        if rv < 0:
            e = ffi.errno
            if e != errno.EINTR:
                raise OSError(e, os.strerror(e))
        else:
            return
