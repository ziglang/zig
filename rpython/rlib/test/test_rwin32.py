# encoding: utf-8
import os, py
if os.name != 'nt':
    py.test.skip('tests for win32 only')

from rpython.rlib import rwin32
from rpython.tool.udir import udir
from rpython.rlib.rarithmetic import is_emulated_long

arch = '_64' if is_emulated_long else '_32'
loadtest_dir = os.path.dirname(__file__) + '/loadtest'
test1 = os.path.abspath(loadtest_dir + '/loadtest1' + arch + '.dll')
test0 = os.path.abspath(loadtest_dir + '/loadtest0' + arch + '.dll')

if not os.path.exists(test1) or not os.path.exists(test0):
    # This is how the files, which are checked into the repo, were created
    from rpython.translator.tool.cbuild import ExternalCompilationInfo
    from rpython.translator.platform import platform
    from rpython.translator import cdir
    if not os.path.exists(loadtest_dir):
        os.mkdir(loadtest_dir)
    c_file = udir.ensure("test_rwin32", dir=1).join("test0.c")
    c_file.write(py.code.Source('''
    #include "src/precommondefs.h"
    RPY_EXPORTED
    int internal_sum(int a, int b) {
        return a + b;
    }
    '''))
    eci = ExternalCompilationInfo(include_dirs=[cdir])
    lib_name = str(platform.compile([c_file], eci, test0[:-4],
                   standalone=False))
    assert os.path.abspath(lib_name) == os.path.abspath(test0)

    c_file = udir.ensure("test_rwin32", dir=1).join("test1.c")
    c_file.write(py.code.Source('''
    #include "src/precommondefs.h"
    int internal_sum(int a, int b);
    RPY_EXPORTED
    int sum(int a, int b) {
        return internal_sum(a, b);
    }
    '''))
    eci = ExternalCompilationInfo(include_dirs=[cdir], 
                        libraries=[loadtest_dir + '/loadtest0' + arch])
    lib_name = str(platform.compile([c_file], eci, test1[:-4],
                   standalone=False, ))
    assert os.path.abspath(lib_name) == os.path.abspath(test1)

def test_get_osfhandle():
    fid = open(str(udir.join('validate_test.txt')), 'w')
    fd = fid.fileno()
    rwin32.get_osfhandle(fd)
    fid.close()
    # Somehow the SuppressIPH's c_enter_suppress_iph, which resolves
    # to calling _set_thread_local_invalid_parameter_handler, does not work
    # untranslated. After translation it does work.
    # py.test.raises(OSError, rwin32.get_osfhandle, fd)
    rwin32.get_osfhandle(0)

def test_open_process():
    pid = rwin32.GetCurrentProcessId()
    assert pid != 0
    handle = rwin32.OpenProcess(rwin32.PROCESS_QUERY_INFORMATION, False, pid)
    rwin32.CloseHandle(handle)
    py.test.raises(WindowsError, rwin32.OpenProcess, rwin32.PROCESS_TERMINATE, False, 0)

def test_terminate_process():
    import subprocess, signal, sys
    proc = subprocess.Popen([sys.executable, "-c",
                         "import time;"
                         "time.sleep(10)",
                         ],
                        )
    print proc.pid
    handle = rwin32.OpenProcess(rwin32.PROCESS_ALL_ACCESS, False, proc.pid)
    assert rwin32.TerminateProcess(handle, signal.SIGTERM) == 1
    rwin32.CloseHandle(handle)
    assert proc.wait() == signal.SIGTERM

@py.test.mark.dont_track_allocations('putenv intentionally keeps strings alive')
def test_wenviron():
    name, value = u'PYPY_TEST_日本', u'foobar日本'
    rwin32._wputenv(name, value)
    assert rwin32._wgetenv(name) == value
    env = dict(rwin32._wenviron_items())
    assert env[name] == value
    for key, value in env.iteritems():
        assert type(key) is unicode
        assert type(value) is unicode

def test_formaterror():
    # choose one with formatting characters and newlines
    msg = rwin32.FormatError(34)
    assert '%2' in msg

def test_formaterror_unicode():
    msg, lgt = rwin32.FormatErrorW(34)
    assert type(msg) is str
    assert '%2' in msg

def test_loadlibraryA():
    # test0 can be loaded alone, but test1 requires the modified search path
    hdll = rwin32.LoadLibrary(test0)
    assert hdll
    faddr = rwin32.GetProcAddress(hdll, 'internal_sum')
    assert faddr
    assert rwin32.FreeLibrary(hdll)

    hdll = rwin32.LoadLibrary(test1)
    assert not hdll

    assert os.path.exists(test1)

    hdll = rwin32.LoadLibraryExA(test1, rwin32.LOAD_WITH_ALTERED_SEARCH_PATH)
    assert hdll
    faddr = rwin32.GetProcAddress(hdll, 'sum')
    assert faddr
    assert rwin32.FreeLibrary(hdll)

def test_loadlibraryW():
    # test0 can be loaded alone, but test1 requires the modified search path
    hdll = rwin32.LoadLibraryW(unicode(test0))
    assert hdll
    faddr = rwin32.GetProcAddress(hdll, 'internal_sum')
    assert faddr
    assert rwin32.FreeLibrary(hdll)

    hdll = rwin32.LoadLibraryW(unicode(test1))
    assert not hdll

    assert os.path.exists(unicode(test1))

    hdll = rwin32.LoadLibraryExW(unicode(test1), rwin32.LOAD_WITH_ALTERED_SEARCH_PATH)
    assert hdll
    faddr = rwin32.GetProcAddress(hdll, 'sum')
    assert faddr
    assert rwin32.FreeLibrary(hdll)

def test_loadlibrary_unicode():
    import shutil
    test0u = unicode(udir.join(u'load\u03betest' + arch + '.dll'))
    shutil.copyfile(test0, test0u)
    hdll = rwin32.LoadLibraryW(test0u)
    assert hdll
