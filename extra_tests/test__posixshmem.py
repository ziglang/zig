import pytest

_posixshmem = pytest.importorskip('_posixshmem')

import os
import mmap

def test_simple():
    mode = 0o600
    tmp_path = "/psm_%s" % (hex(id(hex)), ) # hack to get a uniquish path
    flags = os.O_RDWR | os.O_CREAT | os.O_EXCL
    fd = _posixshmem.shm_open(tmp_path, flags, mode)
    try:
        size = 1024
        os.ftruncate(fd, size)
        mem1 = mmap.mmap(fd, size)

        fd2 = _posixshmem.shm_open(tmp_path, flags & ~os.O_CREAT, mode)
        mem2 = mmap.mmap(fd2, size)
        mem1[0] = 14
        assert mem1[0] == 14
    finally:
        _posixshmem.shm_unlink(tmp_path)

