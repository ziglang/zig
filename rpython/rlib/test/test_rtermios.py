import py, re, sys
from rpython.tool.udir import udir
from rpython.tool.pytest.expecttest import ExpectTest
# tests here are run as snippets through a pexpected python subprocess

def setup_module(mod):
    try:
        import termios
        mod.termios = termios
    except ImportError:
        py.test.skip("termios not found")
    try:
        import pexpect
    except ImportError:
        py.test.skip("pexpect not found")
    fname = udir.join('expect_test.py')
    fname.write('''
import termios
print str(termios.tcgetattr(2)[:-1])
''')
    child = pexpect.spawn('python', [str(fname)], logfile=sys.stderr)
    child.expect(pexpect.EOF)
    mod.TCGETATTR = child.before[:-2]
    child.close()
    assert child.exitstatus == 0

class TestLLTermios(object):

    def run(self, arg, expected):
        import pexpect
        child = pexpect.spawn(str(arg.builder.executable_name))
        child.expect(re.escape(expected))
        assert child.status is None

    def test_tcgetattr(self):
        from rpython.translator.c.test.test_genc import compile
        from rpython.rlib import rtermios
        def runs_tcgetattr():
            tpl = list(rtermios.tcgetattr(2)[:-1])
            return str(tpl)

        fn = compile(runs_tcgetattr, [], backendopt=False)
        self.run(fn, TCGETATTR)

    def test_tcgetattr2(self):
        from rpython.translator.c.test.test_genc import compile
        from rpython.rlib import rtermios
        import os, errno
        def runs_tcgetattr():
            fd = os.open('.', 0, 0777)
            try:
                rtermios.tcgetattr(fd)
            except OSError as e:
                assert e.errno == errno.ENOTTY
                print "ok"

        fn = compile(runs_tcgetattr, [], backendopt=False)
        self.run(fn, "ok")

    def test_tcsetattr(self):
        # a test, which doesn't even check anything.
        # I've got no idea how to test it to be honest :-(
        from rpython.translator.c.test.test_genc import compile
        from rpython.rlib import rtermios
        import time
        def runs_tcsetattr():
            tp = rtermios.tcgetattr(2)
            a, b, c, d, e, f, g = tp
            rtermios.tcsetattr(2, rtermios.TCSANOW, (a, b, c, d, e, f, g))
            time.sleep(.1)
            tp = rtermios.tcgetattr(2)
            assert tp[5] == f
            print "ok"

        fn = compile(runs_tcsetattr, [], backendopt=False)
        self.run(fn, "ok")

    def test_tcrest(self):
        from rpython.translator.c.test.test_genc import compile
        from rpython.rlib import rtermios
        def runs_tcall():
            rtermios.tcsendbreak(2, 0)
            rtermios.tcdrain(2)
            rtermios.tcflush(2, rtermios.TCIOFLUSH)
            rtermios.tcflow(2, rtermios.TCOON)
            print "ok"

        fn = compile(runs_tcall, [], backendopt=False)
        self.run(fn, "ok")

class TestTermios(ExpectTest):
    def test_tcsetattr_icanon(self):
        def f():
            from rpython.rlib import rtermios
            import termios
            def check(fd, when, attributes):
                count = len([i for i in attributes[-1] if isinstance(i, int)])
                assert count == 2
            termios.tcsetattr = check
            attr = list(rtermios.tcgetattr(2))
            attr[3] |= termios.ICANON
            rtermios.tcsetattr(2, termios.TCSANOW, attr)
        self.run_test(f)
