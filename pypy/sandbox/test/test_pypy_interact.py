import os, stat, errno, py
from pypy.sandbox.pypy_interact import PyPySandboxedProc
from rpython.translator.interactive import Translation

from pypy.module.sys.version import CPYTHON_VERSION
from pypy.tool.lib_pypy import LIB_PYTHON

VERSION = '%d' % CPYTHON_VERSION[0]
SITE_PY_CONTENT = LIB_PYTHON.join('site.py').read()
ERROR_TEXT = os.strerror(errno.ENOENT)

if os.name == 'nt':
    py.test.skip('sandbox not supported on windows')

def assert_(cond, text):
    if not cond:
        print "assert failed:", text
        raise AssertionError

def mini_pypy_like_entry_point(argv):
    """An RPython standalone executable that does the same kind of I/O as
    PyPy when it starts up.
    """
    assert_(len(argv) == 3, "expected len(argv) == 3")
    assert_(argv[1] == 'foo', "bad argv[1]")
    assert_(argv[2] == 'bar', "bad argv[2]")
    env = os.environ.items()
    assert_(len(env) == 0, "empty environment expected")
    assert_(argv[0] == '/bin/pypy3-c', "bad argv[0]")
    st = os.lstat('/bin/pypy3-c')
    assert_(stat.S_ISREG(st.st_mode), "bad st_mode for /bin/pypy3-c")
    for dirname in ['/bin/lib-python/' + VERSION, '/bin/lib_pypy']:
        st = os.stat(dirname)
        assert_(stat.S_ISDIR(st.st_mode), "bad st_mode for " + dirname)
    assert_(os.environ.get('PYTHONPATH') is None, "unexpected $PYTHONPATH")
    try:
        os.stat('site')
    except OSError:
        pass
    else:
        assert_(False, "os.stat('site') should have failed")

    try:
        os.stat('/bin/lib-python/%s/site.pyc' % VERSION)
    except OSError:
        pass
    else:
        assert_(False, "os.stat('....pyc') should have failed")
    fd = os.open('/bin/lib-python/%s/site.py' % VERSION,
                 os.O_RDONLY, 0666)
    length = 8192
    ofs = 0
    while True:
        data = os.read(fd, length)
        if not data: break
        end = ofs+length
        if end > len(SITE_PY_CONTENT):
            end = len(SITE_PY_CONTENT)
        assert_(data == SITE_PY_CONTENT[ofs:end], "bad data from site.py")
        ofs = end
    os.close(fd)
    assert_(ofs == len(SITE_PY_CONTENT), "not enough data from site.py")
    assert_(os.getcwd() == '/tmp', "bad cwd")
    assert_(os.strerror(errno.ENOENT) == ERROR_TEXT, "bad strerror(ENOENT)")
    assert_(os.isatty(0), "isatty(0) returned False")
    # an obvious 'attack'
    try:
        os.open('/spam', os.O_RDWR | os.O_CREAT, 0666)
    except OSError:
        pass
    else:
        assert_(False, "os.open('/spam') should have failed")
    return 0


def setup_module(mod):
    t = Translation(mini_pypy_like_entry_point, backend='c', sandbox=True,
                    lldebug=True)
    mod.executable = str(t.compile())


def test_run():
    sandproc = PyPySandboxedProc(executable, ['foo', 'bar'])
    returncode = sandproc.interact()
    assert returncode == 0
