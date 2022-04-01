from hypothesis import given, strategies as st, assume
import pytest

from rpython.rtyper.test.test_llinterp import interpret
from rpython.translator.c.test.test_genc import compile
from rpython.tool.pytest.expecttest import ExpectTest
from rpython.tool.udir import udir
from rpython.rlib import rposix, rposix_stat, rstring
import os, sys
import errno
import py

def rposix_requires(funcname):
    return pytest.mark.skipif(not hasattr(rposix, funcname),
        reason="Requires rposix.%s()" % funcname)

win_only = pytest.mark.skipif("os.name != 'nt'")

class TestPosixFunction:
    def test_access(self):
        filename = str(udir.join('test_access.txt'))
        fd = file(filename, 'w')
        fd.close()

        for mode in os.R_OK, os.W_OK, os.X_OK, os.R_OK | os.W_OK | os.X_OK:
            result = rposix.access(filename, mode)
            assert result == os.access(filename, mode)

    def test_times(self):
        """
        posix.times should compile as an RPython function and should return a
        five-tuple giving float-representations (seconds, effectively) of the four
        fields from the underlying struct tms and the return value.
        """
        times = eval(compile(lambda: str(os.times()), ())())
        assert isinstance(times, tuple)
        assert len(times) == 5
        for value in times:
            assert isinstance(value, float)

    @py.test.mark.skipif("not hasattr(os, 'getlogin')")
    def test_getlogin(self):
        try:
            expected = os.getlogin()
        except OSError as e:
            py.test.skip("the underlying os.getlogin() failed: %s" % e)
        data = rposix.getlogin()
        assert data == expected

    @win_only
    def test_utimes(self):
        # Windows support centiseconds
        def f(fname, t1):
            os.utime(fname, (t1, t1))

        fname = udir.join('test_utimes.txt')
        fname.ensure()
        t1 = 1159195039.25
        compile(f, (str, float))(str(fname), t1)
        assert t1 == os.stat(str(fname)).st_mtime
        t1 = 5000000000.0
        compile(f, (str, float))(str(fname), t1)
        assert t1 == os.stat(str(fname)).st_mtime

    def test_utime_negative_fraction(self):
        def f(fname, t1):
            os.utime(fname, (t1, t1))

        fname = udir.join('test_utime_negative_fraction.txt')
        fname.ensure()
        t1 = -123.75
        compile(f, (str, float))(str(fname), t1)
        got = os.stat(str(fname)).st_mtime
        assert got == -123 or got == -123.75

    @win_only
    def test__getfullpathname(self):
        posix = __import__(os.name)
        sysdrv = os.getenv('SystemDrive', 'C:')
        stuff = sysdrv + 'stuff'
        data = rposix.getfullpathname(stuff)
        assert data == posix._getfullpathname(stuff)
        # the most intriguing failure of ntpath.py should not repeat, here:
        assert not data.endswith(stuff)

    @win_only
    def test__getfullpathname_long(self):
        stuff = "C:" + "\\abcd" * 100
        py.test.raises(WindowsError, rposix.getfullpathname, stuff)
        ustuff = u"C:" + u"\\abcd" * 100
        res = rposix.getfullpathname(ustuff)
        assert res == ustuff

    def test_getcwd(self):
        assert rposix.getcwd() == os.getcwd()

    def test_chdir(self):
        def check_special_envvar():
            if sys.platform != 'win32':
                return
            pwd = os.getcwd()
            import ctypes
            buf = ctypes.create_string_buffer(1000)
            len = ctypes.windll.kernel32.GetEnvironmentVariableA('=%c:' % pwd[0], buf, 1000)
            if (len == 0) and "WINGDB_PYTHON" in os.environ:
                # the ctypes call seems not to work in the Wing debugger
                return
            assert str(buf.value).lower() == pwd.lower()
            # ctypes returns the drive letter in uppercase,
            # os.getcwd does not,
            # but there may be uppercase in os.getcwd path

        pwd = os.getcwd()
        try:
            check_special_envvar()
            rposix.chdir('..')
            assert os.getcwd() == os.path.dirname(pwd)
            check_special_envvar()
        finally:
            os.chdir(pwd)

    def test_mkdir(self):
        filename = str(udir.join('test_mkdir.dir'))
        rposix.mkdir(filename, 0777)
        with py.test.raises(OSError) as excinfo:
            rposix.mkdir(filename, 0777)
        assert excinfo.value.errno == errno.EEXIST
        if sys.platform == 'win32':
            assert excinfo.type is WindowsError

    @rposix_requires('mkdirat')
    def test_mkdirat(self):
        relpath = 'test_mkdirat.dir'
        filename = str(udir.join(relpath))
        dirfd = os.open(os.path.dirname(filename), os.O_RDONLY)
        try:
            rposix.mkdirat(relpath, 0777, dir_fd=dirfd)
            with py.test.raises(OSError) as excinfo:
                rposix.mkdirat(relpath, 0777, dir_fd=dirfd)
            assert excinfo.value.errno == errno.EEXIST
        finally:
            os.close(dirfd)

    def test_strerror(self):
        assert rposix.strerror(2) == os.strerror(2)

    def test_system(self):
        filename = str(udir.join('test_system.txt'))
        arg = '%s -c "print 1+1" > %s' % (sys.executable, filename)
        data = rposix.system(arg)
        assert data == 0
        with file(filename) as f:
            assert f.read().strip() == '2'
        os.unlink(filename)


    @py.test.mark.skipif("os.name != 'posix'")
    def test_execve(self):
        EXECVE_ENV = {"foo": "bar", "baz": "quux"}

        def run_execve(program, args=None, env=None, do_path_lookup=False):
            if args is None:
                args = [program]
            else:
                args = [program] + args
            if env is None:
                env = {}
            # we cannot directly call execve() because it replaces the
            # current process.
            fd_read, fd_write = os.pipe()
            childpid = os.fork()
            if childpid == 0:
                # in the child
                os.close(fd_read)
                os.dup2(fd_write, 1)     # stdout
                os.close(fd_write)
                if do_path_lookup:
                    os.execvp(program, args)
                else:
                    rposix.execve(program, args, env)
                assert 0, "should not arrive here"
            else:
                # in the parent
                os.close(fd_write)
                child_stdout = []
                while True:
                    data = os.read(fd_read, 4096)
                    if not data: break     # closed
                    child_stdout.append(data)
                pid, status = os.waitpid(childpid, 0)
                os.close(fd_read)
                return status, ''.join(child_stdout)

        # Test exit status and code
        result, child_stdout = run_execve("/usr/bin/which", ["true"], do_path_lookup=True)
        result, child_stdout = run_execve(child_stdout.strip()) # /bin/true or /usr/bin/true
        assert os.WIFEXITED(result)
        assert os.WEXITSTATUS(result) == 0
        result, child_stdout = run_execve("/usr/bin/which", ["false"], do_path_lookup=True)
        result, child_stdout = run_execve(child_stdout.strip()) # /bin/false or /usr/bin/false
        assert os.WIFEXITED(result)
        assert os.WEXITSTATUS(result) == 1

        # Test environment
        result, child_stdout = run_execve("/usr/bin/env", env=EXECVE_ENV)
        assert os.WIFEXITED(result)
        assert os.WEXITSTATUS(result) == 0
        assert dict([line.split('=') for line in child_stdout.splitlines()]) == EXECVE_ENV

        # The following won't actually execute anything, so they don't need
        # a child process helper.

        # If the target does not exist, an OSError should result
        info = py.test.raises(
            OSError, rposix.execve, "this/file/is/non/existent", [], {})
        assert info.value.errno == errno.ENOENT

        # If the target is not executable, an OSError should result
        info = py.test.raises(
            OSError, rposix.execve, "/etc/passwd", [], {})
        assert info.value.errno == errno.EACCES

    def test_os_write(self):
        #Same as test in rpython/test/test_rbuiltin
        fname = str(udir.join('os_test.txt'))
        fd = os.open(fname, os.O_WRONLY|os.O_CREAT, 0777)
        assert fd >= 0
        rposix.write(fd, 'Hello world')
        os.close(fd)
        with open(fname) as fid:
            assert fid.read() == "Hello world"
        fd = os.open(fname, os.O_WRONLY|os.O_CREAT, 0777)
        os.close(fd)
        py.test.raises(OSError, rposix.write, fd, 'Hello world')

    def test_os_close(self):
        fname = str(udir.join('os_test.txt'))
        fd = os.open(fname, os.O_WRONLY|os.O_CREAT, 0777)
        assert fd >= 0
        os.write(fd, 'Hello world')
        rposix.close(fd)
        py.test.raises(OSError, rposix.close, fd)

    def test_os_lseek(self):
        fname = str(udir.join('os_test.txt'))
        fd = os.open(fname, os.O_RDWR|os.O_CREAT, 0777)
        assert fd >= 0
        os.write(fd, 'Hello world')
        rposix.lseek(fd,0,0)
        assert os.read(fd, 11) == 'Hello world'
        os.close(fd)
        py.test.raises(OSError, rposix.lseek, fd, 0, 0)

    def test_os_fsync(self):
        fname = str(udir.join('os_test.txt'))
        fd = os.open(fname, os.O_WRONLY|os.O_CREAT, 0777)
        assert fd >= 0
        os.write(fd, 'Hello world')
        rposix.fsync(fd)
        os.close(fd)
        fid = open(fname)
        assert fid.read() == 'Hello world'
        fid.close()
        py.test.raises(OSError, rposix.fsync, fd)

    @py.test.mark.skipif("not hasattr(os, 'fdatasync')")
    def test_os_fdatasync(self):
        fname = str(udir.join('os_test.txt'))
        fd = os.open(fname, os.O_WRONLY|os.O_CREAT, 0777)
        assert fd >= 0
        os.write(fd, 'Hello world')
        rposix.fdatasync(fd)
        fid = open(fname)
        assert fid.read() == 'Hello world'
        os.close(fd)
        py.test.raises(OSError, rposix.fdatasync, fd)

    def test_os_kill(self):
        import subprocess
        import signal
        proc = subprocess.Popen([sys.executable, "-c",
                             "import time;"
                             "time.sleep(10)",
                             ],
                            )
        rposix.kill(proc.pid, signal.SIGTERM)
        if os.name == 'nt':
            expected = signal.SIGTERM
        else:
            expected = -signal.SIGTERM
        assert proc.wait() == expected

    def test_isatty(self):
        assert rposix.isatty(-1) is False

    @py.test.mark.skipif("not hasattr(rposix, 'makedev')")
    def test_makedev(self):
        dev = rposix.makedev(24, 7)
        assert rposix.major(dev) == 24
        assert rposix.minor(dev) == 7

    @py.test.mark.skipif("not hasattr(rposix, 'memfd_create')")
    def test_memfd_create(self):
        fd = rposix.memfd_create("abc", rposix.MFD_CLOEXEC)
        try:
            s = "defghi?"
            os.write(fd, s)
        finally:
            os.close(fd)

@py.test.mark.skipif("not hasattr(os, 'ttyname')")
class TestOsExpect(ExpectTest):
    def test_ttyname(self):
        def f():
            import os
            from rpython.rtyper.test.test_llinterp import interpret

            def ll_to_string(s):
                return ''.join(s.chars)

            def f(num):
                try:
                    return os.ttyname(num)
                except OSError:
                    return ''

            assert ll_to_string(interpret(f, [0])) == f(0)
            assert ll_to_string(interpret(f, [338])) == ''

        self.run_test(f)


def ll_to_string(s):
    return ''.join(s.chars)

class UnicodeWithEncoding:
    is_unicode = True

    def __init__(self, unistr):
        self.unistr = unistr

    if sys.platform == 'win32':
        def as_bytes(self):
            from rpython.rlib.runicode import unicode_encode_mbcs
            res = unicode_encode_mbcs(self.unistr, len(self.unistr),
                                      "strict")
            return rstring.assert_str0(res)
    else:
        def as_bytes(self):
            from rpython.rlib.runicode import unicode_encode_utf_8
            res = unicode_encode_utf_8(self.unistr, len(self.unistr),
                                       "strict")
            return rstring.assert_str0(res)

    def as_unicode(self):
        return self.unistr

class BasePosixUnicodeOrAscii:
    def setup_method(self, method):
        self.ufilename = self._get_filename()
        try:
            f = file(self.ufilename, 'w')
        except UnicodeEncodeError:
            py.test.skip("encoding not good enough")
        f.write("test")
        f.close()
        if sys.platform == 'win32' and isinstance(self.ufilename, str):
            self.path = self.ufilename
            self.path2 = self.ufilename + ".new"
        else:
            self.path  = UnicodeWithEncoding(self.ufilename)
            self.path2 = UnicodeWithEncoding(self.ufilename + ".new")

    def _teardown_method(self, method):
        for path in [self.ufilename + ".new", self.ufilename]:
            if os.path.exists(path):
                os.unlink(path)

    def test_open(self):
        def f():
            try:
                fd = os.open(self.path, os.O_RDONLY, 0777)
                try:
                    text = os.read(fd, 50)
                    return text
                finally:
                    os.close(fd)
            except OSError:
                return ''

        assert ll_to_string(interpret(f, [])) == "test"

    def test_stat(self):
        def f():
            return rposix_stat.stat(self.path).st_mtime
        if sys.platform == 'win32':
            # double vs. float, be satisfied with sub-millisec resolution
            assert abs(interpret(f, []) - os.stat(self.ufilename).st_mtime) < 1e-4
        else:
            assert interpret(f, []) == os.stat(self.ufilename).st_mtime

    def test_access(self):
        def f():
            return rposix.access(self.path, os.R_OK)

        assert interpret(f, []) == 1

    def test_utime(self):
        def f():
            return rposix.utime(self.path, None)

        interpret(f, []) # does not crash

    def test_chmod(self):
        def f():
            return rposix.chmod(self.path, 0777)

        interpret(f, []) # does not crash

    def test_unlink(self):
        def f():
            return rposix.unlink(self.path)

        interpret(f, [])
        assert not os.path.exists(self.ufilename)

    def test_rename(self):
        def f():
            return rposix.rename(self.path, self.path2)

        interpret(f, [])
        assert not os.path.exists(self.ufilename)
        assert os.path.exists(self.ufilename + '.new')

    def test_replace(self):
        def f():
            return rposix.replace(self.path, self.path2)

        interpret(f, [])
        assert not os.path.exists(self.ufilename)
        assert os.path.exists(self.ufilename + '.new')

    def test_listdir(self):
        udir = UnicodeWithEncoding(os.path.dirname(self.ufilename))

        if sys.platform == 'win32':
            def f():
                if isinstance(udir.as_unicode(), str):
                    _udir = udir.as_unicode()
                    _res = ', '
                else:
                    _udir = udir
                    _res = u', '
                return _res.join(rposix.listdir(_udir))
            result = interpret(f, [])
            assert os.path.basename(self.ufilename) in ll_to_string(result)
        else:
            def f():
                return ', '.join(rposix.listdir(udir))
            result = interpret(f, [])
            assert (os.path.basename(self.ufilename).encode('utf-8') in
                    ll_to_string(result))

    def test_chdir(self):
        os.unlink(self.ufilename)

        def f():
            rposix.mkdir(self.path, 0777)
            rposix.chdir(self.path)

        curdir = os.getcwd()
        try:
            interpret(f, [])
            assert os.getcwdu() == os.path.realpath(self.ufilename)
        finally:
            os.chdir(curdir)

        def g():
            rposix.rmdir(self.path)

        try:
            interpret(g, [])
        finally:
            try:
                os.rmdir(self.ufilename)
            except Exception:
                pass

    def test_putenv(self):
        from rpython.rlib import rposix_environ

        def f():
            rposix.putenv(self.path, self.path)
            rposix.unsetenv(self.path)

        interpret(f, [],     # does not crash
                  malloc_check=rposix_environ.REAL_UNSETENV)
        # If we have a real unsetenv(), check that it frees the string
        # kept alive by putenv().  Otherwise, we can't check that,
        # because unsetenv() will keep another string alive itself.
    test_putenv.dont_track_allocations = True


class TestPosixAscii(BasePosixUnicodeOrAscii):
    def _get_filename(self):
        return unicode(udir.join('test_open_ascii'))

    @rposix_requires('openat')
    def test_openat(self):
        def f(dirfd):
            try:
                fd = rposix.openat('test_open_ascii', os.O_RDONLY, 0777, dirfd)
                try:
                    text = os.read(fd, 50)
                    return text
                finally:
                    os.close(fd)
            except OSError:
                return ''

        dirfd = os.open(os.path.dirname(self.ufilename), os.O_RDONLY)
        try:
            assert ll_to_string(interpret(f, [dirfd])) == "test"
        finally:
            os.close(dirfd)

    @rposix_requires('unlinkat')
    def test_unlinkat(self):
        def f(dirfd):
            return rposix.unlinkat('test_open_ascii', dir_fd=dirfd)

        dirfd = os.open(os.path.dirname(self.ufilename), os.O_RDONLY)
        try:
            interpret(f, [dirfd])
        finally:
            os.close(dirfd)
        assert not os.path.exists(self.ufilename)

    @rposix_requires('utimensat')
    def test_utimensat(self):
        def f(dirfd):
            return rposix.utimensat('test_open_ascii',
                0, rposix.UTIME_NOW, 0, rposix.UTIME_NOW, dir_fd=dirfd)

        dirfd = os.open(os.path.dirname(self.ufilename), os.O_RDONLY)
        try:
            interpret(f, [dirfd])  # does not crash
        finally:
            os.close(dirfd)

    @rposix_requires('fchmodat')
    def test_fchmodat(self):
        def f(dirfd):
            return rposix.fchmodat('test_open_ascii', 0777, dirfd)

        dirfd = os.open(os.path.dirname(self.ufilename), os.O_RDONLY)
        try:
            interpret(f, [dirfd])  # does not crash
        finally:
            os.close(dirfd)


class TestPosixUnicode(BasePosixUnicodeOrAscii):
    def _get_filename(self):
        return (unicode(udir.join('test_open')) +
                u'\u65e5\u672c.txt') # "Japan"

class TestRegisteredFunctions:
    def test_dup(self):
        def f():
            os.dup(4)
            os.dup2(5, 6)
        compile(f, ())

    def test_open(self):
        def f():
            os.open('/tmp/t', 0, 0)
            os.open(u'/tmp/t', 0, 0)
        compile(f, ())


@rposix_requires('fdlistdir')
def test_fdlistdir(tmpdir):
    tmpdir.join('file').write('text')
    dirfd = os.open(str(tmpdir), os.O_RDONLY)
    result = rposix.fdlistdir(dirfd)
    # Note: fdlistdir() always closes dirfd
    assert result == ['file']

@rposix_requires('fdlistdir')
def test_fdlistdir_rewinddir(tmpdir):
    tmpdir.join('file').write('text')
    dirfd = os.open(str(tmpdir), os.O_RDONLY)
    result1 = rposix.fdlistdir(os.dup(dirfd))
    result2 = rposix.fdlistdir(dirfd)
    assert result1 == result2 == ['file']

@rposix_requires('symlinkat')
def test_symlinkat(tmpdir):
    tmpdir.join('file').write('text')
    dirfd = os.open(str(tmpdir), os.O_RDONLY)
    try:
        rposix.symlinkat('file', 'link', dir_fd=dirfd)
        assert os.readlink(str(tmpdir.join('link'))) == 'file'
    finally:
        os.close(dirfd)

@rposix_requires('renameat')
def test_renameat(tmpdir):
    tmpdir.join('file').write('text')
    dirfd = os.open(str(tmpdir), os.O_RDONLY)
    try:
        rposix.renameat('file', 'file2', src_dir_fd=dirfd, dst_dir_fd=dirfd)
    finally:
        os.close(dirfd)
    assert tmpdir.join('file').check(exists=False)
    assert tmpdir.join('file2').check(exists=True)

def test_set_inheritable():
    fd1, fd2 = os.pipe()
    rposix.set_inheritable(fd1, True)
    assert rposix.get_inheritable(fd1) == True
    rposix.set_inheritable(fd1, False)
    assert rposix.get_inheritable(fd1) == False
    os.close(fd1)
    os.close(fd2)

def test_SetNonInheritableCache():
    cache = rposix.SetNonInheritableCache()
    fd1, fd2 = os.pipe()
    if sys.platform == 'win32':
        rposix.set_inheritable(fd1, True)
        rposix.set_inheritable(fd2, True)
    assert rposix.get_inheritable(fd1) == True
    assert rposix.get_inheritable(fd1) == True
    assert cache.cached_inheritable == -1
    cache.set_non_inheritable(fd1)
    assert cache.cached_inheritable == 1
    cache.set_non_inheritable(fd2)
    assert cache.cached_inheritable == 1
    assert rposix.get_inheritable(fd1) == False
    assert rposix.get_inheritable(fd1) == False
    os.close(fd1)
    os.close(fd2)

def test_dup_dup2_non_inheritable():
    for preset in [False, True]:
        fd1, fd2 = os.pipe()
        rposix.set_inheritable(fd1, preset)
        rposix.set_inheritable(fd2, preset)
        fd3 = rposix.dup(fd1, True)
        assert rposix.get_inheritable(fd3) == True
        fd4 = rposix.dup(fd1, False)
        assert rposix.get_inheritable(fd4) == False
        rposix.dup2(fd2, fd4, False)
        assert rposix.get_inheritable(fd4) == False
        rposix.dup2(fd2, fd3, True)
        assert rposix.get_inheritable(fd3) == True
        os.close(fd1)
        os.close(fd2)
        os.close(fd3)
        os.close(fd4)

def test_sync():
    if sys.platform != 'win32':
        rposix.sync()

def test_cpu_count():
    cc = rposix.cpu_count()
    assert cc >= 1

@rposix_requires('set_status_flags')
def test_set_status_flags():
    fd1, fd2 = os.pipe()
    try:
        flags = rposix.get_status_flags(fd1)
        assert flags & rposix.O_NONBLOCK == 0
        rposix.set_status_flags(fd1, flags | rposix.O_NONBLOCK)
        assert rposix.get_status_flags(fd1) & rposix.O_NONBLOCK != 0
    finally:
        os.close(fd1)
        os.close(fd2)

@rposix_requires('getpriority')
def test_getpriority():
    # a "don't crash" kind of test only
    prio = rposix.getpriority(rposix.PRIO_PROCESS, 0)
    rposix.setpriority(rposix.PRIO_PROCESS, 0, prio)
    py.test.raises(OSError, rposix.getpriority, rposix.PRIO_PGRP, 123456789)

if sys.platform != 'win32':
    def test_sendfile():
        from rpython.rlib import rsocket
        s1, s2 = rsocket.socketpair()
        relpath = 'test_sendfile'
        filename = str(udir.join(relpath))
        fd = os.open(filename, os.O_RDWR|os.O_CREAT, 0777)
        os.write(fd, 'abcdefghij')
        res = rposix.sendfile(s1.fd, fd, 3, 5)
        assert res == 5
        data = os.read(s2.fd, 10)
        assert data == 'defgh'
        os.close(fd)
        s2.close()
        s1.close()

    def test_sendfile_invalid_offset():
        from rpython.rlib import rsocket
        s1, s2 = rsocket.socketpair()
        relpath = 'test_sendfile_invalid_offset'
        filename = str(udir.join(relpath))
        fd = os.open(filename, os.O_RDWR|os.O_CREAT, 0777)
        os.write(fd, 'abcdefghij')
        with py.test.raises(OSError) as excinfo:
            rposix.sendfile(s1.fd, fd, -1, 5)
        assert excinfo.value.errno == errno.EINVAL
        os.close(fd)
        s2.close()
        s1.close()

if sys.platform.startswith('linux'):
    def test_sendfile_no_offset():
        from rpython.rlib import rsocket
        s1, s2 = rsocket.socketpair()
        relpath = 'test_sendfile'
        filename = str(udir.join(relpath))
        fd = os.open(filename, os.O_RDWR|os.O_CREAT, 0777)
        os.write(fd, 'abcdefghij')
        os.lseek(fd, 3, 0)
        res = rposix.sendfile_no_offset(s1.fd, fd, 5)
        assert res == 5
        data = os.read(s2.fd, 10)
        assert data == 'defgh'
        os.close(fd)
        s2.close()
        s1.close()

@rposix_requires('pread')
def test_pread():
    fname = str(udir.join('os_test.txt'))
    fd = os.open(fname, os.O_RDWR | os.O_CREAT)
    try:
        assert fd >= 0
        os.write(fd, b'Hello world')
        os.lseek(fd, 0, 0)
        assert rposix.pread(fd, 2, 1) == b'el'
    finally:
        os.close(fd)
    py.test.raises(OSError, rposix.pread, fd, 2, 1)

@rposix_requires('pwrite')
def test_pwrite():
    fname = str(udir.join('os_test.txt'))
    fd = os.open(fname, os.O_RDWR | os.O_CREAT, 0777)
    try:
        assert fd >= 0
        os.write(fd, b'Hello world')
        os.lseek(fd, 0, 0)
        rposix.pwrite(fd, b'ea', 1)
        assert os.read(fd, 4) == b'Heal'
    finally:
        os.close(fd)
    py.test.raises(OSError, rposix.pwrite, fd, b'ea', 1)

@rposix_requires('posix_fadvise')
def test_posix_fadvise():
    if sys.maxint <= 2**32:
        py.test.skip("ll2ctypes run of posix_fadvise() on 32-bit "
                     "gets confused by the size of OFF_T")
    fname = str(udir.join('test_os_posix_fadvise'))
    fd = os.open(fname, os.O_CREAT | os.O_RDWR)
    try:
        os.write(fd, b"foobar")
        assert rposix.posix_fadvise(fd, 0, 1, rposix.POSIX_FADV_WILLNEED) is None
        assert rposix.posix_fadvise(fd, 1, 1, rposix.POSIX_FADV_NORMAL) is None
        assert rposix.posix_fadvise(fd, 2, 1, rposix.POSIX_FADV_SEQUENTIAL) is None
        assert rposix.posix_fadvise(fd, 3, 1, rposix.POSIX_FADV_RANDOM) is None
        assert rposix.posix_fadvise(fd, 4, 1, rposix.POSIX_FADV_NOREUSE) is None
        assert rposix.posix_fadvise(fd, 5, 1, rposix.POSIX_FADV_DONTNEED) is None
        py.test.raises(OSError, rposix.posix_fadvise, fd, 6, 1, 1234567)
    finally:
        os.close(fd)

@rposix_requires('posix_fallocate')
def test_posix_fallocate():
    if sys.maxint <= 2**32:
        py.test.skip("ll2ctypes run of posix_fallocate() on 32-bit "
                     "gets confused by the size of OFF_T")
    fname = str(udir.join('os_test.txt'))
    fd = os.open(fname, os.O_WRONLY | os.O_CREAT, 0777)
    try:
        assert rposix.posix_fallocate(fd, 0, 10) == 0
    except OSError as inst:
        """ ZFS seems not to support fallocate.
        so skipping solaris-based since it is likely to come with ZFS
        """
        if inst.errno != errno.EINVAL or not sys.platform.startswith("sunos"):
            raise
    finally:
        os.close(fd)

@rposix_requires('sched_get_priority_max')
def test_sched_get_priority_max():
    assert rposix.sched_get_priority_max(rposix.SCHED_FIFO) != -1
    assert rposix.sched_get_priority_max(rposix.SCHED_RR) != -1
    assert rposix.sched_get_priority_max(rposix.SCHED_OTHER) != -1
    assert rposix.sched_get_priority_max(rposix.SCHED_BATCH) != -1

@rposix_requires('sched_get_priority_min')
def test_sched_get_priority_min():
    assert rposix.sched_get_priority_min(rposix.SCHED_FIFO) != -1
    assert rposix.sched_get_priority_min(rposix.SCHED_RR) != -1
    assert rposix.sched_get_priority_min(rposix.SCHED_OTHER) != -1
    assert rposix.sched_get_priority_min(rposix.SCHED_BATCH) != -1

@rposix_requires('sched_get_priority_min')
def test_os_sched_priority_max_greater_than_min():
    policy = rposix.SCHED_RR
    low = rposix.sched_get_priority_min(policy)
    high = rposix.sched_get_priority_max(policy)
    assert isinstance(low, int) == True
    assert isinstance(high, int) == True
    assert  high > low

@rposix_requires('sched_yield')
def test_sched_yield():
    if sys.platform != 'win32':
        rposix.sched_yield()

@rposix_requires('lockf')
def test_os_lockf():
    fname = str(udir.join('os_test.txt'))
    fd = os.open(fname, os.O_WRONLY | os.O_CREAT, 0777)
    try:
        os.write(fd, b'test')
        os.lseek(fd, 0, 0)
        rposix.lockf(fd, rposix.F_LOCK, 4)
        rposix.lockf(fd, rposix.F_ULOCK, 4)
    finally:
        os.close(fd)

def check_working_xattr():
    fname = str(udir.join('xattr_test0.txt'))
    with open(fname, 'wb'):
        pass
    try:
        rposix.setxattr(fname, 'user.foo', '')
    except OSError:
        return False
    else:
        return True

@pytest.mark.skipif(not (hasattr(rposix, 'getxattr') and check_working_xattr()),
    reason="Requires working rposix.getxattr()")
@given(
    name=st.text(
        alphabet=st.characters(min_codepoint=1), min_size=1, max_size=10),
    value=st.binary(max_size=10),
    follow_symlinks=st.booleans(), use_fd=st.booleans())
def test_xattr(name, value, follow_symlinks, use_fd):
    assume(follow_symlinks or not use_fd)
    name = 'user.' + name.encode('utf-8')
    fname = str(udir.join('xattr_test.txt'))
    try:
        os.unlink(fname)
    except OSError:
        pass
    with open(fname, 'wb'):
        pass
    if use_fd:
        file_id = os.open(fname, os.O_CREAT, 0777)
        read, write, delete = rposix.fgetxattr, rposix.fsetxattr, rposix.fremovexattr
        all_names = rposix.flistxattr
    else:
        file_id = fname
        if follow_symlinks:
            read, write, delete = rposix.getxattr, rposix.setxattr, rposix.removexattr
            all_names = rposix.listxattr
        else:
            read = lambda *args, **kwargs: rposix.getxattr(*args, follow_symlinks=False, **kwargs)
            write = lambda *args, **kwargs: rposix.setxattr(*args, follow_symlinks=False, **kwargs)
            delete = lambda *args, **kwargs: rposix.removexattr(*args, follow_symlinks=False, **kwargs)
            all_names = lambda *args, **kwargs: rposix.listxattr(*args, follow_symlinks=False, **kwargs)
    try:
        init_names = all_names(file_id)
        with pytest.raises(OSError):
            read(file_id, name)
        write(file_id, name, value)
        assert read(file_id, name) == value
        assert set(all_names(file_id)) == set(init_names + [name])
        assert '' not in all_names(file_id)
        delete(file_id, name)
        with pytest.raises(OSError):
            read(file_id, name)
        assert set(all_names(file_id)) == set(init_names)
    finally:
        if use_fd:
            os.close(file_id)

@pytest.mark.skipif(not hasattr(rposix, 'getgrouplist'),
    reason="Requires working rposix.getgrouplist()")
@rposix_requires('getgrouplist')
def test_getgrouplist():
    import pwd
    user = pwd.getpwuid(os.getuid())[0]
    group = pwd.getpwuid(os.getuid())[3]
    assert group in rposix.getgrouplist(user, group)

@pytest.mark.skipif(not hasattr(rposix, 'sched_rr_get_interval'),
    reason="Requires working rposix.sched_rr_get_interval()")
def test_sched_rr_get_interval():
    try:
        interval = rposix.sched_rr_get_interval(0)
    except OSError as e:
        # This likely means that sched_rr_get_interval is only valid for
        # processes with the SCHED_RR scheduler in effect.
        if e.errno != errno.EINVAL:
                raise
        pytest.mark.skip("only works on SCHED_RR processes")
    assert isinstance(interval, float)
    # Reasonable constraints, I think.
    assert interval > 0
    assert interval < 1.

@pytest.mark.skipif(not hasattr(rposix, 'sched_getscheduler'),
    reason="Requires working rposix.sched_getscheduler()")
def test_get_and_set_scheduler_and_param():
    possible_schedulers = [sched for name, sched in rposix.__dict__.items()
                                   if name.startswith("SCHED_")]
    mine = rposix.sched_getscheduler(0)
    assert mine in possible_schedulers
    try:
        parent = rposix.sched_getscheduler(os.getppid())
    except OSError as e:
        if e.errno != errno.EPERM:
            raise
    else:
        assert parent in possible_schedulers
    with pytest.raises(OSError):
        rposix.sched_getscheduler(-1)
    with pytest.raises(OSError):
        rposix.sched_getparam(-1)
    param = rposix.sched_getparam(0)
    assert param == 0

    # POSIX states that calling sched_setparam() or sched_setscheduler() on
    # a process with a scheduling policy other than SCHED_FIFO or SCHED_RR
    # is implementation-defined: NetBSD and FreeBSD can return EINVAL.
    if not sys.platform.startswith(('freebsd', 'netbsd')):
        try:
            rposix.sched_setscheduler(0, mine, param)
            rposix.sched_setparam(0, param)
        except OSError as e:
            if e.errno != errno.EPERM:
                raise
        with pytest.raises(OSError):
            rposix.sched_setparam(-1, param)
    with pytest.raises(OSError):
        rposix.sched_setscheduler(-1, mine, param)

    large = 214748364700
    if large < sys.maxint:
        param = large # rposix.sched_param(large)
        with pytest.raises(OSError):
            rposix.sched_setparam(0, param)
        # param = rposix.sched_param(sched_priority=-large)
        # with pytest.raises(OverflowError):
        #    rposix.sched_setparam(0, param)
