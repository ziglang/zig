import os
import py
from rpython.tool.udir import udir

if os.name != 'posix':
    py.test.skip("fcntl module only available on unix")

def teardown_module(mod):
    for i in "abcde":
        if os.path.exists(i):
            os.unlink(i)

class AppTestFcntl:
    spaceconfig = dict(usemodules=('fcntl', 'array', 'struct', 'termios',
                                   'select', 'time'))

    def setup_class(cls):
        tmpprefix = str(udir.ensure('test_fcntl', dir=1).join('tmp_'))
        cls.w_tmp = cls.space.wrap(tmpprefix)

    def test_fcntl(self):
        import fcntl
        import os
        import sys
        import struct

        class F:
            def __init__(self, fn):
                self.fn = fn
            def fileno(self):
                return self.fn

        f = open(self.tmp + "b", "w+")

        original = fcntl.fcntl(f, 1, 0)
        fcntl.fcntl(f, 1)
        fcntl.fcntl(F(int(f.fileno())), 1)
        raises(TypeError, fcntl.fcntl, "foo")
        raises(TypeError, fcntl.fcntl, f, "foo")
        exc = raises(TypeError, fcntl.fcntl, F("foo"), 1)
        assert str(exc.value) == 'fileno() returned a non-integer'
        exc = raises(OverflowError, fcntl.fcntl, 2147483647 + 1, 1, 0)
        exc = raises(OverflowError, fcntl.fcntl, F(2147483647 + 1), 1, 0)
        exc = raises(OverflowError, fcntl.fcntl, -2147483648 - 1, 1, 0)
        exc = raises(OverflowError, fcntl.fcntl, F(-2147483648 - 1), 1, 0)
        raises(ValueError, fcntl.fcntl, -1, 1, 0)
        raises(ValueError, fcntl.fcntl, F(-1), 1, 0)
        raises(ValueError, fcntl.fcntl, F(int(-1)), 1, 0)
        assert fcntl.fcntl(f, 1, 0) == original
        assert fcntl.fcntl(f, 2, "foo") == b"foo"
        assert fcntl.fcntl(f, 2, b"foo") == b"foo"

        # This is supposed to work I think, but CPython 3.5 refuses it
        # for reasons I don't understand:
        #     >>> _testcapi.getargs_s_hash(memoryview(b"foo"))
        #     TypeError: must be read-only bytes-like object, not memoryview
        #
        # assert fcntl.fcntl(f, 2, memoryview(b"foo")) == b"foo"

        try:
            os.O_LARGEFILE
        except AttributeError:
            start_len = "ll"
        else:
            start_len = "qq"

        if any(substring in sys.platform.lower()
               for substring in ('netbsd', 'darwin', 'freebsd', 'bsdos',
                                 'openbsd')):
            if struct.calcsize('l') == 8:
                off_t = 'l'
                pid_t = 'i'
            else:
                off_t = 'lxxxx'
                pid_t = 'l'

            format = "%s%s%shh" % (off_t, off_t, pid_t)
            lockdata = struct.pack(format, 0, 0, 0, fcntl.F_WRLCK, 0)
        else:
            format = "hh%shh" % start_len
            lockdata = struct.pack(format, fcntl.F_WRLCK, 0, 0, 0, 0, 0)

        rv = fcntl.fcntl(f.fileno(), fcntl.F_SETLKW, lockdata)
        assert rv == lockdata
        assert fcntl.fcntl(f, fcntl.F_SETLKW, lockdata) == lockdata

        # test duplication of file descriptor
        rv = fcntl.fcntl(f, fcntl.F_DUPFD)
        assert rv > 2 # > (stdin, stdout, stderr) at least
        assert fcntl.fcntl(f, fcntl.F_DUPFD) > rv
        assert fcntl.fcntl(f, fcntl.F_DUPFD, 99) == 99

        # test descriptor flags
        assert fcntl.fcntl(f, fcntl.F_GETFD) == 0
        fcntl.fcntl(f, fcntl.F_SETFD, 1)
        assert fcntl.fcntl(f, fcntl.F_GETFD, fcntl.FD_CLOEXEC) == 1

        # test status flags
        assert fcntl.fcntl(f.fileno(), fcntl.F_SETFL, os.O_NONBLOCK) == 0
        assert fcntl.fcntl(f.fileno(), fcntl.F_SETFL, os.O_NDELAY) == 0
        assert fcntl.fcntl(f, fcntl.F_SETFL, os.O_NONBLOCK) == 0
        assert fcntl.fcntl(f, fcntl.F_SETFL, os.O_NDELAY) == 0

        if "linux" in sys.platform:
            # test managing signals
            assert fcntl.fcntl(f, fcntl.F_GETOWN) == 0
            fcntl.fcntl(f, fcntl.F_SETOWN, os.getpid())
            assert fcntl.fcntl(f, fcntl.F_GETOWN) == os.getpid()
            assert fcntl.fcntl(f, fcntl.F_GETSIG) == 0
            fcntl.fcntl(f, fcntl.F_SETSIG, 20)
            assert fcntl.fcntl(f, fcntl.F_GETSIG) == 20

            # test leases
            assert fcntl.fcntl(f, fcntl.F_GETLEASE) == fcntl.F_UNLCK
            fcntl.fcntl(f, fcntl.F_SETLEASE, fcntl.F_WRLCK)
            assert fcntl.fcntl(f, fcntl.F_GETLEASE) == fcntl.F_WRLCK
        else:
            # this tests should fail under BSD
            # with "Inappropriate ioctl for device"
            raises(IOError, fcntl.fcntl, f, fcntl.F_GETOWN)
            raises(IOError, fcntl.fcntl, f, fcntl.F_SETOWN, 20)

        f.close()

    def test_flock(self):
        import fcntl
        import os
        import errno

        f = open(self.tmp + "c", "w+")

        raises(TypeError, fcntl.flock, "foo")
        raises(TypeError, fcntl.flock, f, "foo")

        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)

        pid = os.fork()
        if pid == 0:
            rval = 2
            try:
                fcntl.flock(open(f.name, f.mode), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except IOError as e:
                if e.errno not in (errno.EACCES, errno.EAGAIN):
                    raise
                rval = 0
            else:
                rval = 1
            finally:
                os._exit(rval)

        assert pid > 0
        (pid, status) = os.waitpid(pid, 0)
        assert os.WIFEXITED(status) == True
        assert os.WEXITSTATUS(status) == 0

        fcntl.flock(f, fcntl.LOCK_UN)

        f.close()

    def test_lockf(self):
        import fcntl
        import os
        import errno

        f = open(self.tmp + "d", "w+")

        raises(TypeError, fcntl.lockf, f, "foo")
        raises(TypeError, fcntl.lockf, f, fcntl.LOCK_UN, "foo")
        raises(ValueError, fcntl.lockf, f, -256)
        raises(ValueError, fcntl.lockf, f, 256)

        fcntl.lockf(f, fcntl.LOCK_EX | fcntl.LOCK_NB)

        pid = os.fork()
        if pid == 0:
            rval = 2
            try:
                fcntl.lockf(open(f.name, f.mode), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except IOError as e:
                if e.errno not in (errno.EACCES, errno.EAGAIN):
                    raise
                rval = 0
            else:
                rval = 1
            finally:
                os._exit(rval)

        assert pid > 0
        (pid, status) = os.waitpid(pid, 0)
        assert os.WIFEXITED(status) == True
        assert os.WEXITSTATUS(status) == 0

        fcntl.lockf(f, fcntl.LOCK_UN)

        f.close()

    def test_ioctl(self):
        import fcntl
        import array
        import os
        import pty
        import time

        try:
            from termios import TIOCGPGRP
        except ImportError:
            skip("don't know how to test ioctl() on this platform")

        raises(TypeError, fcntl.ioctl, "foo")
        raises(TypeError, fcntl.ioctl, 0, "foo")
        #raises(TypeError, fcntl.ioctl, 0, TIOCGPGRP, float(0))
        raises(TypeError, fcntl.ioctl, 0, TIOCGPGRP, 1, "foo", "bar")

        child_pid, mfd = pty.fork()
        if child_pid == 0:
            # We're the child
            time.sleep(1)
            os._exit(0)
        try:
            # We're the parent, we want TIOCGPGRP calls after child started but before it dies
            time.sleep(0.5)

            buf = array.array('i', [0])
            res = fcntl.ioctl(mfd, TIOCGPGRP, buf, True)
            assert res == 0
            assert buf[0] != 0
            expected = buf.tobytes()

            buf = array.array('i', [0])
            res = fcntl.ioctl(mfd, TIOCGPGRP, buf)
            assert res == 0
            assert buf.tobytes() == expected

            buf = array.array('i', [0])
            res = fcntl.ioctl(mfd, TIOCGPGRP, memoryview(buf))
            assert res == 0
            assert buf.tobytes() == expected

            raises(TypeError, fcntl.ioctl, mfd, TIOCGPGRP, (), False)

            res = fcntl.ioctl(mfd, TIOCGPGRP, buf, False)
            assert res == expected

            # xxx this fails on CPython 3.5, that's a minor bug
            #raises(TypeError, fcntl.ioctl, mfd, TIOCGPGRP, "\x00\x00", True)

            res = fcntl.ioctl(mfd, TIOCGPGRP, "\x00\x00\x00\x00")
            assert res == expected
        finally:
            os.close(mfd)

    def test_ioctl_int(self):
        import os
        import fcntl
        import pty

        try:
            from termios import TCFLSH, TCIOFLUSH
        except ImportError:
            skip("don't know how to test ioctl() on this platform")

        mfd, sfd = pty.openpty()
        try:
            assert fcntl.ioctl(mfd, TCFLSH, TCIOFLUSH) == 0
        finally:
            os.close(mfd)
            os.close(sfd)

    def test_ioctl_signed_unsigned_code_param(self):
        import fcntl
        import os
        import pty
        import struct
        import termios

        mfd, sfd = pty.openpty()
        try:
            if termios.TIOCSWINSZ < 0:
                set_winsz_opcode_maybe_neg = termios.TIOCSWINSZ
                set_winsz_opcode_pos = termios.TIOCSWINSZ & 0xffffffff
            else:
                set_winsz_opcode_pos = termios.TIOCSWINSZ
                set_winsz_opcode_maybe_neg, = struct.unpack("i",
                        struct.pack("I", termios.TIOCSWINSZ))

            our_winsz = struct.pack("HHHH",80,25,0,0)
            # test both with a positive and potentially negative ioctl code
            new_winsz = fcntl.ioctl(mfd, set_winsz_opcode_pos, our_winsz)
            new_winsz = fcntl.ioctl(mfd, set_winsz_opcode_maybe_neg, our_winsz)
        finally:
            os.close(mfd)
            os.close(sfd)

    def test_ioctl_use_mask_on_op(self):
        import os
        import fcntl
        import pty
        try:
            from termios import TCFLSH, TCIOFLUSH
        except ImportError:
            skip("don't know how to test ioctl() on this platform")

        mfd, sfd = pty.openpty()
        try:
            assert fcntl.ioctl(mfd, TCFLSH | 0x1000000000000000000000, TCIOFLUSH) == 0
        finally:
            os.close(mfd)
            os.close(sfd)

    def test_large_flag(self):
        import sys
        if any(plat in sys.platform
               for plat in ('darwin', 'openbsd', 'freebsd')):
            skip("Mac OS doesn't have any large flag in fcntl.h")
        import fcntl, sys
        if sys.maxsize == 2147483647:
            assert fcntl.DN_MULTISHOT == -2147483648
        else:
            assert fcntl.DN_MULTISHOT == 2147483648
        fcntl.fcntl(0, fcntl.F_NOTIFY, fcntl.DN_MULTISHOT)
