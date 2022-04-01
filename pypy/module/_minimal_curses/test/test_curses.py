from pypy import pypydir
from rpython.tool.udir import udir
import py
import sys
# tests here are run as snippets through a pexpected python subprocess


def setup_module(mod):
    try:
        import curses
        curses.setupterm()
    except:
        py.test.skip("Cannot test this here")

class TestCurses(object):
    """ We need to fork here, to prevent
    the setup to be done
    """
    def _spawn(self, *args, **kwds):
        import pexpect
        kwds.setdefault('timeout', 600)
        print 'SPAWN:', args, kwds
        child = pexpect.spawn(*args, **kwds)
        child.logfile = sys.stdout
        return child

    def spawn(self, argv):
        py_py = py.path.local(pypydir).join('bin', 'pyinteractive.py')
        return self._spawn(sys.executable, [str(py_py), '-S'] + argv)

    def setup_class(self):
        try:
            import pexpect
        except ImportError:
            py.test.skip('pexpect not found')

    def test_setupterm(self):
        source = py.code.Source("""
        import _minimal_curses
        try:
            _minimal_curses.tigetstr('cup')
        except _minimal_curses.error:
            print('ok!')
        """)
        f = udir.join("test_setupterm.py")
        f.write(source)
        child = self.spawn(['--withmod-_minimal_curses', str(f)])
        child.expect('ok!')

    def test_tigetstr(self):
        source = py.code.Source("""
        import _minimal_curses
        _minimal_curses.setupterm()
        assert _minimal_curses.tigetstr('cup') == b'\x1b[%i%p1%d;%p2%dH'
        print('ok!')
        """)
        f = udir.join("test_tigetstr.py")
        f.write(source)
        child = self.spawn(['--withmod-_minimal_curses', str(f)])
        child.expect('ok!')

    def test_tparm(self):
        source = py.code.Source("""
        import _minimal_curses
        _minimal_curses.setupterm()
        assert _minimal_curses.tparm(_minimal_curses.tigetstr('cup'), 5, 3) == b'\033[6;4H'
        print('ok!')
        """)
        f = udir.join("test_tparm.py")
        f.write(source)
        child = self.spawn(['--withmod-_minimal_curses', str(f)])
        child.expect('ok!')

class TestCCurses(object):
    """ Test compiled version
    """
    def test_csetupterm(self):
        from rpython.translator.c.test.test_genc import compile
        from rpython.rtyper.lltypesystem import lltype, rffi
        from pypy.module._minimal_curses import fficurses

        def runs_setupterm():
            null = lltype.nullptr(rffi.CCHARP.TO)
            p_errret = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
            errval = fficurses.setupterm(null, 1, p_errret)

        fn = compile(runs_setupterm, [])
        fn()

    def test_ctgetstr(self):
        from rpython.translator.c.test.test_genc import compile
        from rpython.rtyper.lltypesystem import lltype, rffi
        from pypy.module._minimal_curses import fficurses

        def runs_ctgetstr():
            p_errret = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
            with rffi.scoped_str2charp("xterm") as ll_term:
                errval = fficurses.setupterm(ll_term, 1, p_errret)
            with rffi.scoped_str2charp("cup") as ll_capname:
                ll = fficurses.rpy_curses_tigetstr(ll_capname)
                return rffi.charp2str(ll)

        fn = compile(runs_ctgetstr, [])
        res = fn()
        assert res == '\x1b[%i%p1%d;%p2%dH'

    def test_ctparm(self):
        from rpython.translator.c.test.test_genc import compile
        from rpython.rtyper.lltypesystem import lltype, rffi
        from pypy.module._minimal_curses import fficurses

        def runs_tparm():
            p_errret = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
            with rffi.scoped_str2charp("xterm") as ll_term:
                errval = fficurses.setupterm(ll_term, 1, p_errret)
            with rffi.scoped_str2charp("cup") as ll_capname:
                cup = fficurses.rpy_curses_tigetstr(ll_capname)
                res = fficurses.rpy_curses_tparm(cup, 5, 3, 0, 0, 0, 0, 0, 0, 0)
                return rffi.charp2str(res)

        fn = compile(runs_tparm, [])
        res = fn()
        assert res == '\033[6;4H'

