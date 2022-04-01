import os
import sys
import py
from pypy import pypydir
from rpython.tool.udir import udir

if os.name != 'posix':
    py.test.skip('termios module only available on unix')

class TestTermios(object):
    def setup_class(cls):
        try:
            import pexpect
        except ImportError:
            py.test.skip("Pexpect not found")
        try:
            import termios
        except ImportError:
            py.test.skip("termios not found")
        py_py = py.path.local(pypydir).join('bin', 'pyinteractive.py')
        assert py_py.check()
        cls.py_py = py_py
        cls.termios = termios
        cls.pexpect = pexpect

    def _spawn(self, *args, **kwds):
        print 'SPAWN:', args, kwds
        child = self.pexpect.spawn(timeout=600, maxread=5000, *args, **kwds)
        child.logfile = sys.stdout
        return child

    def spawn(self, argv):
        return self._spawn(sys.executable, [str(self.py_py), '-S'] + argv)

    def test_one(self):
        child = self.spawn(['--withmod-termios'])
        child.expect("Python ")
        child.expect('>>> ')
        child.sendline('import termios')
        child.expect('>>> ')
        child.sendline('termios.tcgetattr(0)')
        # output of the first time is ignored: it contains the compilation
        # of more C stuff relating to errno
        child.expect('>>> ')
        child.sendline('print("attr=", termios.tcgetattr(0))')
        child.expect('attr= (\[.*?\[.*?\]\])')
        lst = eval(child.match.group(1))
        assert len(lst) == 7
         # Length of the last element is 32 on Linux, 20 on MacOSX.
        assert len(lst[-1]) in (20, 32)

    def test_tcall(self):
        """ Again - a test that doesnt really test anything
        """
        source = py.code.Source("""
        import termios
        f = termios.tcgetattr(2)
        termios.tcsetattr(2, termios.TCSANOW, f)
        termios.tcsendbreak(2, 0)
        termios.tcdrain(2)
        termios.tcflush(2, termios.TCIOFLUSH)
        termios.tcflow(2, termios.TCOON)
        print('ok!')
        """)
        f = udir.join("test_tcall.py")
        f.write(source)
        child = self.spawn(['--withmod-termios', str(f)])
        child.expect('ok!')

    def test_tcsetattr(self):
        # The last element of the third parameter for termios.tcsetattr()
        # can't be a constant, because it varies from one OS to another.
        # (Its length must be 32 on Linux, 20 on MacOSX, for example.)
        # Use termios.tcgetattr() to get a value that will hopefully be
        # valid for whatever OS we are running on right now.
        source = py.code.Source("""
        import sys
        import termios
        cc = termios.tcgetattr(sys.stdin)[-1]
        termios.tcsetattr(sys.stdin, 1, [16640, 4, 191, 2608, 15, 15, cc])
        print('ok!')
        """)
        f = udir.join("test_tcsetattr.py")
        f.write(source)
        child = self.spawn(['--withmod-termios', str(f)])
        child.expect('ok!')

    def test_ioctl_termios(self):
        source = py.code.Source(r"""
        import termios
        import fcntl
        lgt = len(fcntl.ioctl(2, termios.TIOCGWINSZ, b'\000'*8))
        assert lgt == 8
        print('ok!')
        """)
        f = udir.join("test_ioctl_termios.py")
        f.write(source)
        child = self.spawn(['--withmod-termios', '--withmod-fcntl', str(f)])
        child.expect('ok!')

    def test_icanon(self):
        source = py.code.Source("""
        import termios
        import fcntl
        import termios
        f = termios.tcgetattr(2)
        f[3] |= termios.ICANON
        termios.tcsetattr(2, termios.TCSANOW, f)
        f = termios.tcgetattr(2)
        assert len([i for i in f[-1] if isinstance(i, int)]) == 2
        assert isinstance(f[-1][termios.VMIN], int)
        assert isinstance(f[-1][termios.VTIME], int)
        print('ok!')
        """)
        f = udir.join("test_ioctl_termios.py")
        f.write(source)
        child = self.spawn(['--withmod-termios', '--withmod-fcntl', str(f)])
        child.expect('ok!')

class AppTestTermios(object):
    spaceconfig = dict(usemodules=['termios'])

    def setup_class(cls):
        d = {}
        import termios
        for name in dir(termios):
            val = getattr(termios, name)
            if name.isupper() and type(val) is int:
                d[name] = val
        cls.w_orig_module_dict = cls.space.appexec([], "(): return %r" % (d,))

    def test_values(self):
        import termios
        d = {}
        for name in dir(termios):
            val = getattr(termios, name)
            if name.isupper() and type(val) is int:
                d[name] = val
        assert sorted(d.items()) == sorted(self.orig_module_dict.items())

    def test_error(self):
        import termios, errno, os
        fd = os.open('.', 0)
        try:
            exc = raises(termios.error, termios.tcgetattr, fd)
            assert exc.value.args[0] == errno.ENOTTY
        finally:
            os.close(fd)

    def test_error_tcsetattr(self):
        import termios
        exc = raises(TypeError, termios.tcsetattr, 0, 1, (1, 2))
        assert str(exc.value) == "tcsetattr, arg 3: must be 7 element list"
        exc = raises(TypeError, termios.tcsetattr, 0, 1, (1, 2, 3, 4, 5, 6, 7))
        assert str(exc.value) == "tcsetattr, arg 3: must be 7 element list"
