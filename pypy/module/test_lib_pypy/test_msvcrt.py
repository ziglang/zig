from rpython.tool.udir import udir
import py
import sys

# not an applevel test: errno is not preserved
class TestMsvcrt:
    def test_locking(self):
        if sys.platform != 'win32':
            py.test.skip("only on Windows")

        filename = udir.join('locking_test')
        filename.ensure()

        import os, msvcrt, errno
        msvcrt.locking

        fd = os.open(str(filename), 0)
        try:
            msvcrt.locking(fd, 1, 1)

            # lock again: it fails
            e = raises(IOError, msvcrt.locking, fd, 1, 1)
            assert e.value.errno == errno.EDEADLOCK

            # unlock and relock sucessfully
            msvcrt.locking(fd, 0, 1)
            msvcrt.locking(fd, 1, 1)
        finally:
            os.close(fd)
