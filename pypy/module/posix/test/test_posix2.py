# -*- coding: utf-8 -*-

import os
import py
import pytest
import sys
import signal

from rpython.tool.udir import udir
from pypy.tool.pytest.objspace import gettestobjspace
from pypy.interpreter.gateway import interp2app
from rpython.translator.c.test.test_extfunc import need_sparse_files
from rpython.rlib import rposix

USEMODULES = ['binascii', 'posix', 'signal', 'struct', 'time', '_socket']

def setup_module(mod):
    mod.space = gettestobjspace(usemodules=USEMODULES)
    mod.path = udir.join('posixtestfile.txt')
    mod.path.write("this is a test")
    mod.path2 = udir.join('test_posix2-')
    mod.path3 = udir.join('unlinktestfile.txt')
    mod.path3.write("delete me!")
    pdir = udir.ensure('posixtestdir', dir=True)
    pdir = udir.ensure('posixtestdir', dir=True)
    pdir.join('file1').write("test1")
    os.chmod(str(pdir.join('file1')), 0o600)
    pdir.join('file2').write("test2")
    pdir.join('another_longer_file_name').write("test3")
    mod.pdir = pdir
    if sys.platform == 'darwin':
        # see issue https://bugs.python.org/issue31380
        bytes_dir = udir.ensure('fixc5x9fier.txt', dir=True)
        file_name = 'cafxe9'
        surrogate_name = 'foo'
    else:
        bytes_dir = udir.ensure('fi\xc5\x9fier.txt', dir=True)
        file_name = 'caf\xe9'
        surrogate_name = 'foo\x80'
    bytes_dir.join('somefile').write('who cares?')
    bytes_dir.join(file_name).write('who knows?')
    mod.bytes_dir = bytes_dir
    # an escaped surrogate
    mod.esurrogate_dir = udir.ensure(surrogate_name, dir=True)

    try:
        mod.dir_unicode = udir.ensure(u'dir_extra', dir=True)
        mod.dir_unicode.join(u'ca\u2014f\xe9').write('test')
    except UnicodeEncodeError:    # fsencoding can't encode that, skip tests
        mod.dir_unicode = None

    # Initialize sys.filesystemencoding
    # space.call_method(space.getbuiltinmodule('sys'), 'getfilesystemencoding')


GET_POSIX = "(): import %s as m ; return m" % os.name


class AppTestPosix:
    spaceconfig = {'usemodules': USEMODULES}

    def setup_class(cls):
        space = cls.space
        cls.w_runappdirect = space.wrap(cls.runappdirect)
        cls.w_posix = space.appexec([], GET_POSIX)
        cls.w_path = space.wrap(str(path))
        cls.w_path2 = space.wrap(str(path2))
        cls.w_path3 = space.wrap(str(path3))
        cls.w_pdir = space.wrap(str(pdir))
        cls.w_bytes_dir = space.newbytes(str(bytes_dir))
        cls.w_esurrogate_dir = space.newbytes(str(esurrogate_dir))
        cls.w_dir_unicode = space.wrap(unicode(dir_unicode)
                                       if dir_unicode is not None else None)
        if hasattr(os, 'getuid'):
            cls.w_getuid = space.wrap(os.getuid())
            cls.w_geteuid = space.wrap(os.geteuid())
        if hasattr(os, 'getgid'):
            cls.w_getgid = space.wrap(os.getgid())
        if hasattr(os, 'getgroups'):
            cls.w_getgroups = space.newlist([space.wrap(e) for e in os.getgroups()])
        if hasattr(os, 'getpgid'):
            cls.w_getpgid = space.wrap(os.getpgid(os.getpid()))
        if hasattr(os, 'getsid'):
            cls.w_getsid0 = space.wrap(os.getsid(0))
        if hasattr(os, 'sysconf'):
            sysconf_name = os.sysconf_names.keys()[0]
            cls.w_sysconf_name = space.wrap(sysconf_name)
            cls.w_sysconf_value = space.wrap(os.sysconf_names[sysconf_name])
            cls.w_sysconf_result = space.wrap(os.sysconf(sysconf_name))
        if hasattr(os, 'confstr'):
            confstr_name = os.confstr_names.keys()[0]
            cls.w_confstr_name = space.wrap(confstr_name)
            cls.w_confstr_value = space.wrap(os.confstr_names[confstr_name])
            cls.w_confstr_result = space.wrap(os.confstr(confstr_name))
        cls.w_SIGABRT = space.wrap(signal.SIGABRT)
        cls.w_python = space.wrap(sys.executable)
        cls.w_platform = space.wrap(sys.platform)
        if hasattr(os, 'major'):
            cls.w_expected_major_12345 = space.wrap(os.major(12345))
            cls.w_expected_minor_12345 = space.wrap(os.minor(12345))
        cls.w_udir = space.wrap(str(udir))
        cls.w_env_path = space.wrap(os.environ['PATH'])
        cls.w_Path = space.appexec([], """():
            class Path:
                def __init__(self, _path):
                    self._path =_path
                def __fspath__(self):
                    return self._path
            return Path
            """)

    def setup_method(self, meth):
        if getattr(meth, 'need_sparse_files', False):
            if sys.maxsize < 2**32 and not self.runappdirect:
                # this fails because it uses ll2ctypes to call the posix
                # functions like 'open' and 'lseek', whereas a real compiled
                # C program would macro-define them to their longlong versions
                pytest.skip("emulation of files can't use "
                             "larger-than-long offsets")
            need_sparse_files()

    def test_posix_is_pypy_s(self):
        assert hasattr(self.posix, '_statfields')

    def test_some_posix_basic_operation(self):
        path = self.path
        posix = self.posix
        fd = posix.open(path, posix.O_RDONLY, 0o777)
        fd2 = posix.dup(fd)
        assert posix.get_inheritable(fd2) == False
        assert not posix.isatty(fd2)
        s = posix.read(fd, 1)
        assert s == b't'
        posix.lseek(fd, 5, 0)
        s = posix.read(fd, 1)
        assert s == b'i'
        st = posix.fstat(fd)
        assert st == posix.stat(fd)
        posix.close(fd2)
        posix.close(fd)

        import sys, stat
        assert st[0] == st.st_mode
        assert st[1] == st.st_ino
        assert st[2] == st.st_dev
        assert st[3] == st.st_nlink
        assert st[4] == st.st_uid
        assert st[5] == st.st_gid
        assert st[6] == st.st_size
        assert st[7] == int(st.st_atime)   # in complete corner cases, rounding
        assert st[8] == int(st.st_mtime)   # here could maybe get the wrong
        assert st[9] == int(st.st_ctime)   # integer...

        assert stat.S_IMODE(st.st_mode) & stat.S_IRUSR
        assert stat.S_IMODE(st.st_mode) & stat.S_IWUSR
        if not sys.platform.startswith('win'):
            assert not (stat.S_IMODE(st.st_mode) & stat.S_IXUSR)

        assert st.st_size == 14
        assert st.st_nlink == 1

        if sys.platform.startswith('linux'):
            assert isinstance(st.st_atime, float)
            assert isinstance(st.st_mtime, float)
            assert isinstance(st.st_ctime, float)
            assert hasattr(st, 'st_rdev')

        assert isinstance(st.st_atime_ns, int)
        assert abs(st.st_atime_ns - 1e9*st.st_atime) < 500
        assert abs(st.st_mtime_ns - 1e9*st.st_mtime) < 500
        assert abs(st.st_ctime_ns - 1e9*st.st_ctime) < 500

    def test_stat_float_times(self):
        path = self.path
        posix = self.posix
        import warnings
        with warnings.catch_warnings(record=True) as l:
            warnings.simplefilter('always')
            current = posix.stat_float_times()
            assert current is True
        assert "stat_float_times" in repr(l[0].message)
        try:
            posix.stat_float_times(True)
            st = posix.stat(path)
            assert isinstance(st.st_mtime, float)
            assert st[7] == int(st.st_atime)
            assert posix.stat_float_times(-1) is True

            posix.stat_float_times(False)
            st = posix.stat(path)
            assert isinstance(st.st_mtime, int)
            assert st[7] == st.st_atime
            assert posix.stat_float_times(-1) is False

        finally:
            posix.stat_float_times(current)


    def test_stat_result(self):
        st = self.posix.stat_result((0, 0, 0, 0, 0, 0, 0, 41, 42.1, 43))
        assert st.st_atime == 41
        assert st.st_mtime == 42.1
        assert st.st_ctime == 43
        assert repr(st).startswith('os.stat_result')

    def test_stat_lstat(self):
        import stat
        st = self.posix.stat(".")
        assert stat.S_ISDIR(st.st_mode)
        st = self.posix.stat(b".")
        assert stat.S_ISDIR(st.st_mode)
        st = self.posix.stat(bytearray(b"."))
        assert stat.S_ISDIR(st.st_mode)
        st = self.posix.lstat(".")
        assert stat.S_ISDIR(st.st_mode)

    def test_stat_exception(self):
        import sys
        import errno
        for fn in [self.posix.stat, self.posix.lstat]:
            with raises(OSError) as exc:
                fn("nonexistentdir/nonexistentfile")
            assert exc.value.errno == errno.ENOENT
            assert exc.value.filename == "nonexistentdir/nonexistentfile"
            with raises(OSError) as exc:
                fn("")
            assert exc.value.errno == errno.ENOENT

        with raises(TypeError) as excinfo:
            self.posix.stat(None)
        assert "should be string, bytes, os.PathLike or integer, not None" in str(excinfo.value)
        with raises(TypeError) as excinfo:
            self.posix.stat(2.)
        assert "should be string, bytes, os.PathLike or integer, not float" in str(excinfo.value)
        with raises(OSError):
            self.posix.stat(-1)
        with raises(ValueError):
            self.posix.stat(b"abc\x00def")
        with raises(ValueError):
            self.posix.stat(u"abc\x00def")

    def test_path_t_convertor(self):
        posix = self.posix

        class FakePath:
            """Simple implementing of the path protocol.
            """
            def __init__(self, path):
                self.path = path

            def __repr__(self):
                return '<FakePath {}>'.format(self.path)

            def __fspath__(self):
                if (isinstance(self.path, BaseException) or
                    isinstance(self.path, type) and
                        issubclass(self.path, BaseException)):
                    raise self.path
                else:
                    return self.path
        fd = posix.open(self.path, posix.O_RDONLY, 0o777)
        with raises(TypeError) as exc:
            posix.stat(FakePath(fd))
        assert 'to return str or bytes' in exc.value.args[0]


    if hasattr(__import__(os.name), "statvfs"):
        def test_statvfs(self):
            st = self.posix.statvfs(".")
            assert isinstance(st, self.posix.statvfs_result)
            for field in [
                'f_bsize', 'f_frsize', 'f_blocks', 'f_bfree', 'f_bavail',
                'f_files', 'f_ffree', 'f_favail', 'f_flag', 'f_namemax',
                'f_fsid',
            ]:
                assert hasattr(st, field)

        def test_statvfs_result(self):
            st = self.posix.statvfs_result(
                (4096, 4096, 20971520, 17750785, 17750785, 1600000, 1275269,
                    1275269, 4096, 255, 99999))
            with raises(IndexError):
                st[10]
            assert st.f_fsid == 99999
            st = self.posix.statvfs_result(
                (4096, 4096, 20971520, 17750785, 17750785, 1600000, 1275269,
                    1275269, 4096, 255))
            assert st.f_fsid is None

    def test_open_exception(self):
        posix = self.posix
        try:
            posix.open('qowieuqwoeiu', 0, 0)
        except OSError as e:
            assert e.filename == 'qowieuqwoeiu'
        else:
            assert 0

    def test_filename_exception(self):
        for fname in ['unlink', 'remove',
                      'chdir', 'mkdir', 'rmdir',
                      'listdir', 'readlink',
                      'chroot']:
            if hasattr(self.posix, fname):
                func = getattr(self.posix, fname)
                try:
                    func('qowieuqw/oeiu')
                except OSError as e:
                    assert e.filename == 'qowieuqw/oeiu'
                else:
                    assert 0

    def test_chmod_exception(self):
        try:
            self.posix.chmod('qowieuqw/oeiu', 0)
        except OSError as e:
            assert e.filename == 'qowieuqw/oeiu'
        else:
            assert 0

    def test_chown_exception(self):
        if hasattr(self.posix, 'chown'):
            try:
                self.posix.chown('qowieuqw/oeiu', 0, 0)
            except OSError as e:
                assert e.filename == 'qowieuqw/oeiu'
            else:
                assert 0

    def test_utime_exception(self):
        for arg in [None, (0, 0)]:
            try:
                self.posix.utime('qowieuqw/oeiu', arg)
            except OSError as e:
                pass
            else:
                assert 0

    def test_functions_raise_error(self):
        import sys
        def ex(func, *args):
            try:
                func(*args)
            except OSError:
                pass
            else:
                raise AssertionError("%s(%s) did not raise" %(
                                     func.__name__,
                                     ", ".join([str(x) for x in args])))
        UNUSEDFD = 123123
        ex(self.posix.open, "qweqwe", 0, 0)
        ex(self.posix.lseek, UNUSEDFD, 123, 0)
        #apparently not posix-required: ex(self.posix.isatty, UNUSEDFD)
        ex(self.posix.read, UNUSEDFD, 123)
        ex(self.posix.write, UNUSEDFD, b"x")
        ex(self.posix.close, UNUSEDFD)
        #UMPF cpython raises IOError ex(self.posix.ftruncate, UNUSEDFD, 123)
        if sys.platform == 'win32' and self.runappdirect:
            # XXX kills the host interpreter untranslated
            ex(self.posix.fstat, UNUSEDFD)
            ex(self.posix.stat, "qweqwehello")
            # how can getcwd() raise?
            ex(self.posix.dup, UNUSEDFD)

    def test_getcwd(self):
        posix = self.posix
        import sys

        # avoid importing stdlib os, copy fsencode instead
        def fsencode(filename):
            encoding = sys.getfilesystemencoding()
            errors = sys.getfilesystemencodeerrors()
            filename = posix.fspath(filename)  # Does type-checking of `filename`.
            if isinstance(filename, str):
                return filename.encode(encoding, errors)
            else:
                return filename

        assert isinstance(posix.getcwd(), str)
        cwdb = posix.getcwdb()
        posix.chdir(self.esurrogate_dir)
        try:
            cwd = posix.getcwd()
            assert fsencode(cwd) == posix.getcwdb()
        finally:
            posix.chdir(cwdb)

    def test_getcwdb(self):
        assert isinstance(self.posix.getcwdb(), bytes)

    def test_listdir(self):
        pdir = self.pdir
        posix = self.posix
        result = posix.listdir(pdir)
        result.sort()
        assert result == ['another_longer_file_name',
                          'file1',
                          'file2']

    def test_listdir_default(self):
        import sys
        posix = self.posix
        for v in ['', b'']:
            with raises(FileNotFoundError):
                posix.listdir(v)
        for v in ['.', None]:
            assert posix.listdir() == posix.listdir(v)

    def test_listdir_bytes(self):
        import sys
        bytes_dir = self.bytes_dir
        posix = self.posix
        result = posix.listdir(bytes_dir)
        assert all(type(x) is bytes for x in result)
        assert b'somefile' in result
        expected = b'caf%E9' if sys.platform == 'darwin' else b'caf\xe9'
        assert expected in result

    def test_listdir_unicode(self):
        if self.dir_unicode is None:
            skip("couldn't encode unicode file name")
        posix = self.posix
        result = posix.listdir(self.dir_unicode)
        assert all(type(x) is str for x in result)
        assert u'ca\u2014f\xe9' in result
        raises(OSError, posix.listdir, self.dir_unicode + "NONEXISTENT")

    def test_listdir_memoryview_returns_unicode(self):
        import sys
        # XXX unknown why CPython has this behaviour

        # avoid importing stdlib os, copy fsencode instead
        def fsencode(filename):
            encoding = sys.getfilesystemencoding()
            errors = sys.getfilesystemencodeerrors()
            filename = posix.fspath(filename)  # Does type-checking of `filename`.
            if isinstance(filename, str):
                return filename.encode(encoding, errors)
            else:
                return filename


        bytes_dir = self.bytes_dir
        posix = self.posix
        result1 = posix.listdir(bytes_dir)              # -> list of bytes
        result2 = posix.listdir(memoryview(bytes_dir))  # -> list of unicodes
        assert [fsencode(x) for x in result2] == result1

    @py.test.mark.skipif("sys.platform == 'win32'")
    def test_fdlistdir(self):
        posix = self.posix
        dirfd = posix.open('.', posix.O_RDONLY)
        lst1 = posix.listdir(dirfd)   # does not close dirfd
        lst2 = posix.listdir('.')
        assert lst1 == lst2
        #
        lst3 = posix.listdir(dirfd)   # rewinddir() was used
        assert lst3 == lst1
        posix.close(dirfd)

    def test_undecodable_filename(self):
        import sys
        posix = self.posix
        try:
            'caf\xe9'.encode(sys.getfilesystemencoding(), 'surrogateescape')
        except UnicodeEncodeError:
            pass # probably ascii
        else:
            assert posix.access('caf\xe9', posix.R_OK) is False
        assert posix.access(b'caf\xe9', posix.R_OK) is False
        assert posix.access('caf\udcc0', posix.R_OK) is False
        assert posix.access(b'caf\xc3', posix.R_OK) is False

    def test_access(self):
        pdir = self.pdir + '/file1'
        posix = self.posix

        assert posix.access(pdir, posix.R_OK) is True
        assert posix.access(pdir, posix.W_OK) is True
        import sys
        if sys.platform != "win32":
            assert posix.access(pdir, posix.X_OK) is False

    def test_unlink(self):
        os = self.posix
        path = self.path3
        with open(path, 'wb'):
            pass
        os.unlink(path)

    def test_times(self):
        """
        posix.times() should return a posix.times_result object giving
        float-representations (seconds, effectively) of the four fields from
        the underlying struct tms and the return value.
        """
        result = self.posix.times()
        assert isinstance(self.posix.times(), self.posix.times_result)
        assert isinstance(self.posix.times(), tuple)
        assert len(result) == 5
        for value in result:
            assert isinstance(value, float)
        assert isinstance(result.user, float)
        assert isinstance(result.system, float)
        assert isinstance(result.children_user, float)
        assert isinstance(result.children_system, float)
        assert isinstance(result.elapsed, float)
    def test_strerror(self):
        assert isinstance(self.posix.strerror(0), str)
        assert isinstance(self.posix.strerror(1), str)

    if hasattr(__import__(os.name), "fork"):
        def test_fork(self):
            os = self.posix
            pid = os.fork()
            if pid == 0:   # child
                os._exit(4)
            pid1, status1 = os.waitpid(pid, 0)
            assert pid1 == pid
            assert os.WIFEXITED(status1)
            assert os.WEXITSTATUS(status1) == 4
            assert os.waitstatus_to_exitcode(status1) == 4
        pass # <- please, inspect.getsource(), don't crash


    if hasattr(__import__(os.name), "openpty"):
        def test_openpty(self):
            os = self.posix
            master_fd, slave_fd = os.openpty()
            assert isinstance(master_fd, int)
            assert isinstance(slave_fd, int)
            os.write(slave_fd, b'x\n')
            data = os.read(master_fd, 100)
            assert data.startswith(b'x')
            os.close(master_fd)
            os.close(slave_fd)

        def test_openpty_non_inheritable(self):
            os = self.posix
            master_fd, slave_fd = os.openpty()
            assert os.get_inheritable(master_fd) == False
            assert os.get_inheritable(slave_fd) == False
            os.close(master_fd)
            os.close(slave_fd)

    if hasattr(__import__(os.name), "forkpty"):
        def test_forkpty(self):
            import sys
            if 'freebsd' in sys.platform:
                skip("hangs indifinitly on FreeBSD (also on CPython).")
            os = self.posix
            childpid, master_fd = os.forkpty()
            assert isinstance(childpid, int)
            assert isinstance(master_fd, int)
            if childpid == 0:
                data = os.read(0, 100)
                if data.startswith(b'abc'):
                    os._exit(42)
                else:
                    os._exit(43)
            os.write(master_fd, b'abc\n')
            _, status = os.waitpid(childpid, 0)
            assert status >> 8 == 42

    def test_utime(self):
        os = self.posix
        # XXX utimes & float support
        path = self.path2 + "test_utime.txt"
        fh = open(path, "wb")
        fh.write(b"x")
        fh.close()
        from time import time, sleep
        t0 = time()
        sleep(1.1)
        os.utime(path, None)
        assert os.stat(path).st_atime > t0
        os.utime(path, (int(t0), int(t0)))
        assert int(os.stat(path).st_atime) == int(t0)
        t1 = time()
        os.utime(path, (int(t1), int(t1)))
        assert int(os.stat(path).st_atime) == int(t1)

    def test_utime_raises(self):
        os = self.posix
        import errno
        with raises(TypeError):
            os.utime('xxx', 3)
        with raises(TypeError):
            os.utime('xxx', [5, 5])
        with raises(TypeError):
            os.utime('xxx', ns=[5, 5])
        with raises(OSError) as exc:
            os.utime('somefilewhichihopewouldneverappearhere', None)
        assert exc.value.errno == errno.ENOENT

    for name in rposix.WAIT_MACROS:
        if hasattr(os, name):
            values = [0, 1, 127, 128, 255]
            code = py.code.Source("""
            def test_wstar(self):
                os = self.posix
                %s
            """ % "\n    ".join(["assert os.%s(%d) == %d" % (name, value,
                             getattr(os, name)(value)) for value in values]))
            d = {}
            exec code.compile() in d
            locals()['test_' + name] = d['test_wstar']

    if hasattr(os, 'WIFSIGNALED'):
        def test_wifsignaled(self):
            os = self.posix
            assert os.WIFSIGNALED(0) == False
            assert os.WIFSIGNALED(1) == True

    if hasattr(os, 'uname'):
        def test_os_uname(self):
            os = self.posix
            res = os.uname()
            assert len(res) == 5
            for i in res:
                assert isinstance(i, str)
            assert isinstance(res, tuple)
            assert res == (res.sysname, res.nodename,
                           res.release, res.version, res.machine)

    if hasattr(os, 'getuid'):
        def test_os_getuid(self):
            os = self.posix
            assert os.getuid() == self.getuid
            assert os.geteuid() == self.geteuid

    if hasattr(os, 'setuid'):
        @py.test.mark.skipif("sys.version_info < (2, 7, 4)")
        def test_os_setuid_error(self):
            os = self.posix
            with raises(OverflowError):
                os.setuid(-2)
            with raises(OverflowError):
                os.setuid(2**32)
            with raises(OSError):
                os.setuid(-1)

    if hasattr(os, 'getgid'):
        def test_os_getgid(self):
            os = self.posix
            assert os.getgid() == self.getgid

    if hasattr(os, 'getgroups'):
        def test_os_getgroups(self):
            os = self.posix
            assert os.getgroups() == self.getgroups

    if hasattr(os, 'setgroups'):
        def test_os_setgroups(self):
            os = self.posix
            with raises(TypeError):
                os.setgroups([2, 5, "hello"])
            try:
                os.setgroups(os.getgroups())
            except OSError:
                pass

    if hasattr(os, 'initgroups'):
        def test_os_initgroups(self):
            os = self.posix
            with raises(OSError):
                os.initgroups("crW2hTQC", 100)

    if hasattr(os, 'tcgetpgrp'):
        def test_os_tcgetpgrp(self):
            os = self.posix
            with raises(OSError):
                os.tcgetpgrp(9999)

    if hasattr(os, 'tcsetpgrp'):
        def test_os_tcsetpgrp(self):
            os = self.posix
            with raises(OSError):
                os.tcsetpgrp(9999, 1)

    if hasattr(os, 'getpgid'):
        def test_os_getpgid(self):
            os = self.posix
            assert os.getpgid(os.getpid()) == self.getpgid
            with raises(OSError):
                os.getpgid(1234567)

    if hasattr(os, 'setgid'):
        @pytest.mark.skipif("sys.version_info < (2, 7, 4)")
        def test_os_setgid_error(self):
            os = self.posix
            with raises(OverflowError):
                os.setgid(-2)
            with raises(OverflowError):
                os.setgid(2**32)
            with raises(OSError):
                os.setgid(-1)
            with raises(OSError):
                os.setgid(2**32-1)

    if hasattr(os, 'getsid'):
        def test_os_getsid(self):
            os = self.posix
            assert os.getsid(0) == self.getsid0
            with raises(OSError):
                os.getsid(-100000)

    if hasattr(os, 'getresuid'):
        def test_os_getresuid(self):
            os = self.posix
            res = os.getresuid()
            assert len(res) == 3

    if hasattr(os, 'getresgid'):
        def test_os_getresgid(self):
            os = self.posix
            res = os.getresgid()
            assert len(res) == 3

    if hasattr(os, 'setresuid'):
        def test_os_setresuid(self):
            os = self.posix
            a, b, c = os.getresuid()
            os.setresuid(a, b, c)

    if hasattr(os, 'setresgid'):
        def test_os_setresgid(self):
            os = self.posix
            a, b, c = os.getresgid()
            os.setresgid(a, b, c)

    if hasattr(os, 'sysconf'):
        def test_os_sysconf(self):
            os = self.posix
            assert os.sysconf(self.sysconf_value) == self.sysconf_result
            assert os.sysconf(self.sysconf_name) == self.sysconf_result
            assert os.sysconf_names[self.sysconf_name] == self.sysconf_value

        def test_os_sysconf_error(self):
            os = self.posix
            with raises(ValueError):
                os.sysconf("!@#$%!#$!@#")

    if hasattr(os, 'fpathconf'):
        def test_os_fpathconf(self):
            os = self.posix
            assert os.fpathconf(1, "PC_PIPE_BUF") >= 128
            with raises(OSError):
                os.fpathconf(-1, "PC_PIPE_BUF")
            with raises(ValueError):
                os.fpathconf(1, "##")

    if hasattr(os, 'pathconf'):
        def test_os_pathconf(self):
            os = self.posix
            assert os.pathconf("/tmp", "PC_NAME_MAX") >= 31
            # Linux: the following gets 'No such file or directory'
            with raises(OSError):
                os.pathconf("", "PC_PIPE_BUF")
            with raises(ValueError):
                os.pathconf("/tmp", "##")

    if hasattr(os, 'confstr'):
        def test_os_confstr(self):
            os = self.posix
            assert os.confstr(self.confstr_value) == self.confstr_result
            assert os.confstr(self.confstr_name) == self.confstr_result
            assert os.confstr_names[self.confstr_name] == self.confstr_value

        def test_os_confstr_error(self):
            os = self.posix
            with raises(ValueError):
                os.confstr("!@#$%!#$!@#")

    if hasattr(os, 'wait'):
        def test_os_wait(self):
            os = self.posix
            exit_status = 0x33

            if not hasattr(os, "fork"):
                skip("Need fork() to test wait()")
            if hasattr(os, "waitpid") and hasattr(os, "WNOHANG"):
                try:
                    while os.waitpid(-1, os.WNOHANG)[0]:
                        pass
                except OSError:  # until we get "No child processes", hopefully
                    pass
            child = os.fork()
            if child == 0: # in child
                os._exit(exit_status)
            else:
                pid, status = os.wait()
                assert child == pid
                assert os.WIFEXITED(status)
                assert os.WEXITSTATUS(status) == exit_status

    if hasattr(os, 'getloadavg'):
        def test_os_getloadavg(self):
            os = self.posix
            l0, l1, l2 = os.getloadavg()
            assert type(l0) is float and l0 >= 0.0
            assert type(l1) is float and l0 >= 0.0
            assert type(l2) is float and l0 >= 0.0

    if hasattr(os, 'major'):
        def test_major_minor(self):
            os = self.posix
            assert os.major(12345) == self.expected_major_12345
            assert os.minor(12345) == self.expected_minor_12345
            assert os.makedev(self.expected_major_12345,
                              self.expected_minor_12345) == 12345
            with raises((ValueError, OverflowError)):
                os.major(-1)

    if hasattr(os, 'fsync'):
        def test_fsync(self):
            os = self.posix
            f = open(self.path2, "w")
            try:
                fd = f.fileno()
                os.fsync(fd)
                os.fsync(f)     # <- should also work with a file, or anything
            finally:            #    with a fileno() method
                f.close()
            try:
                # May not raise anything with a buggy libc (or eatmydata)
                os.fsync(fd)
            except OSError:
                pass
            with raises(ValueError):
                os.fsync(-1)

    if hasattr(os, 'fdatasync'):
        def test_fdatasync(self):
            os = self.posix
            f = open(self.path2, "w")
            try:
                fd = f.fileno()
                os.fdatasync(fd)
            finally:
                f.close()
            try:
                # May not raise anything with a buggy libc (or eatmydata)
                os.fdatasync(fd)
            except OSError:
                pass
            with raises(ValueError):
                os.fdatasync(-1)

    if hasattr(os, 'fchdir'):
        def test_fchdir(self):
            os = self.posix
            localdir = os.getcwd()
            os.mkdir(self.path2 + 'fchdir')
            for func in [os.fchdir, os.chdir]:
                fd = os.open(self.path2 + 'fchdir', os.O_RDONLY)
                try:
                    func(fd)
                    mypath = os.getcwd()
                finally:
                    os.close(fd)
                    os.chdir(localdir)
                assert mypath.endswith('test_posix2-fchdir')
                with raises(OSError):
                    func(fd)
            with raises(ValueError):
                os.fchdir(-1)

    if hasattr(rposix, 'pread'):
        def test_os_pread(self):
            os = self.posix
            fd = os.open(self.path2 + 'test_os_pread', os.O_RDWR | os.O_CREAT)
            try:
                os.write(fd, b'test')
                os.lseek(fd, 0, 0)
                assert os.pread(fd, 2, 1) == b'es'
                assert os.read(fd, 2) == b'te'
            finally:
                os.close(fd)

    if hasattr(rposix, 'pwrite'):
        def test_os_pwrite(self):
            os = self.posix
            fd = os.open(self.path2 + 'test_os_pwrite', os.O_RDWR | os.O_CREAT)
            try:
                os.write(fd, b'test')
                os.lseek(fd, 0, 0)
                os.pwrite(fd, b'xx', 1)
                assert os.read(fd, 4) == b'txxt'
            finally:
                os.close(fd)

    if hasattr(rposix, 'posix_fadvise'):
        def test_os_posix_fadvise(self):
            posix = self.posix
            fd = posix.open(self.path2 + 'test_os_posix_fadvise', posix.O_CREAT | posix.O_RDWR)
            try:
                posix.write(fd, b"foobar")
                assert posix.posix_fadvise(fd, 0, 1, posix.POSIX_FADV_WILLNEED) is None
                assert posix.posix_fadvise(fd, 1, 1, posix.POSIX_FADV_NORMAL) is None
                assert posix.posix_fadvise(fd, 2, 1, posix.POSIX_FADV_SEQUENTIAL) is None
                assert posix.posix_fadvise(fd, 3, 1, posix.POSIX_FADV_RANDOM) is None
                assert posix.posix_fadvise(fd, 4, 1, posix.POSIX_FADV_NOREUSE) is None
                assert posix.posix_fadvise(fd, 5, 1, posix.POSIX_FADV_DONTNEED) is None
                # Does not raise untranslated on a 32-bit chroot/docker
                if self.runappdirect:
                    raises(OSError, posix.posix_fadvise, fd, 6, 1, 1234567)
            finally:
                posix.close(fd)

    if hasattr(rposix, 'posix_fallocate'):
        def test_os_posix_posix_fallocate(self):
            os = self.posix
            import errno
            fd = os.open(self.path2 + 'test_os_posix_fallocate', os.O_WRONLY | os.O_CREAT)
            try:
                ret = os.posix_fallocate(fd, 0, 10)
                if ret == errno.EINVAL and not self.runappdirect:
                    # Does not work untranslated on a 32-bit chroot/docker
                    pass
                else:
                    assert ret == 0
            except OSError as inst:
                """ ZFS seems not to support fallocate.
                so skipping solaris-based since it is likely to come with ZFS
                """
                if inst.errno != errno.EINVAL or not sys.platform.startswith("sunos"):
                    raise
            finally:
                os.close(fd)


    def test_largefile(self):
        os = self.posix
        fd = os.open(self.path2 + 'test_largefile',
                     os.O_RDWR | os.O_CREAT, 0o666)
        os.ftruncate(fd, 10000000000)
        res = os.lseek(fd, 9900000000, 0)
        assert res == 9900000000
        res = os.lseek(fd, -5000000000, 1)
        assert res == 4900000000
        res = os.lseek(fd, -5200000000, 2)
        assert res == 4800000000
        os.close(fd)

        st = os.stat(self.path2 + 'test_largefile')
        assert st.st_size == 10000000000
    test_largefile.need_sparse_files = True

    if hasattr(rposix, 'getpriority'):
        def test_os_set_get_priority(self):
            posix = os = self.posix
            childpid = os.fork()
            if childpid == 0:
                # in the child (avoids changing the priority of the parent
                # process)
                orig_priority = posix.getpriority(posix.PRIO_PROCESS,
                                                  os.getpid())
                orig_grp_priority = posix.getpriority(posix.PRIO_PGRP,
                                                      os.getpgrp())
                posix.setpriority(posix.PRIO_PROCESS, os.getpid(),
                                  orig_priority + 1)
                new_priority = posix.getpriority(posix.PRIO_PROCESS,
                                                 os.getpid())
                assert new_priority == orig_priority + 1
                assert posix.getpriority(posix.PRIO_PGRP, os.getpgrp()) == (
                    orig_grp_priority)
                os._exit(0)    # ok
            #
            pid1, status1 = os.waitpid(childpid, 0)
            assert pid1 == childpid
            assert os.WIFEXITED(status1)
            assert os.WEXITSTATUS(status1) == 0   # else, test failure

    if hasattr(rposix, 'sched_get_priority_max'):
        def test_os_sched_get_priority_max(self):
            import sys
            posix = self.posix
            assert posix.sched_get_priority_max(posix.SCHED_FIFO) != -1
            assert posix.sched_get_priority_max(posix.SCHED_RR) != -1
            assert posix.sched_get_priority_max(posix.SCHED_OTHER) != -1
            if getattr(posix, 'SCHED_BATCH', None):
                assert posix.sched_get_priority_max(posix.SCHED_BATCH) != -1

    if hasattr(rposix, 'sched_get_priority_min'):
        def test_os_sched_get_priority_min(self):
            import sys
            posix = self.posix
            assert posix.sched_get_priority_min(posix.SCHED_FIFO) != -1
            assert posix.sched_get_priority_min(posix.SCHED_RR) != -1
            assert posix.sched_get_priority_min(posix.SCHED_OTHER) != -1
            if getattr(posix, 'SCHED_BATCH', None):
                assert posix.sched_get_priority_min(posix.SCHED_BATCH) != -1

    if hasattr(rposix, 'sched_get_priority_min'):
        def test_os_sched_priority_max_greater_than_min(self):
            posix = self.posix
            policy = posix.SCHED_RR
            low = posix.sched_get_priority_min(policy)
            high = posix.sched_get_priority_max(policy)
            assert isinstance(low, int) == True
            assert isinstance(high, int) == True
            assert  high > low

    if hasattr(rposix, 'sched_yield'):
        def test_sched_yield(self):
            os = self.posix
            #Always suceeds on Linux
            os.sched_yield()

    if hasattr(rposix, 'sched_getparam'):
        def test_sched_param_kwargs(self):
            os = self.posix
            sp = os.sched_param(sched_priority=1)
            assert sp.sched_priority == 1

    def test_write_buffer(self):
        os = self.posix
        fd = os.open(self.path2 + 'test_write_buffer',
                     os.O_RDWR | os.O_CREAT, 0o666)
        def writeall(s):
            while s:
                count = os.write(fd, s)
                assert count > 0
                s = s[count:]
        writeall(b'hello, ')
        writeall(memoryview(b'world!\n'))
        res = os.lseek(fd, 0, 0)
        assert res == 0
        data = b''
        while True:
            s = os.read(fd, 100)
            if not s:
                break
            data += s
        assert data == b'hello, world!\n'
        os.close(fd)

    def test_write_unicode(self):
        os = self.posix
        fd = os.open(self.path2 + 'test_write_unicode',
                     os.O_RDWR | os.O_CREAT, 0o666)
        with raises(TypeError):
            os.write(fd, 'X')
        os.close(fd)

    if hasattr(__import__(os.name), "fork"):
        def test_abort(self):
            os = self.posix
            pid = os.fork()
            if pid == 0:
                os.abort()
            pid1, status1 = os.waitpid(pid, 0)
            assert pid1 == pid
            assert os.WIFSIGNALED(status1)
            assert os.WTERMSIG(status1) == self.SIGABRT
            assert os.waitstatus_to_exitcode(status1) == -self.SIGABRT
        pass # <- please, inspect.getsource(), don't crash

    def test_closerange(self):
        os = self.posix
        if not hasattr(os, 'closerange'):
            skip("missing os.closerange()")
        fds = [os.open(self.path + str(i), os.O_CREAT|os.O_WRONLY, 0o777)
               for i in range(15)]
        fds.sort()
        start = fds.pop()
        stop = start + 1
        while len(fds) > 3 and fds[-1] == start - 1:
            start = fds.pop()
        os.closerange(start, stop)
        for fd in fds:
            os.close(fd)     # should not have been closed
        if self.platform == 'win32' and self.runappdirect:
            # XXX kills the host interpreter untranslated
            for fd in range(start, stop):
                with raises(OSError):
                    os.fstat(fd)   # should have been closed

    if hasattr(os, 'chown'):
        def test_chown(self):
            my_path = self.path2 + 'test_chown'
            os = self.posix
            with raises(OSError):
                os.chown(my_path, os.getuid(), os.getgid())
            open(my_path, 'w').close()
            os.chown(my_path, os.getuid(), os.getgid())

    if hasattr(os, 'lchown'):
        def test_lchown(self):
            my_path = self.path2 + 'test_lchown'
            os = self.posix
            with raises(OSError):
                os.lchown(my_path, os.getuid(), os.getgid())
            os.symlink('foobar', my_path)
            os.lchown(my_path, os.getuid(), os.getgid())

    if hasattr(os, 'fchown'):
        def test_fchown(self):
            my_path = self.path2 + 'test_fchown'
            os = self.posix
            f = open(my_path, "w")
            os.fchown(f.fileno(), os.getuid(), os.getgid())
            f.close()

    if hasattr(os, 'chmod'):
        def test_chmod(self):
            import sys
            my_path = self.path2 + 'test_chmod'
            os = self.posix
            with raises(OSError):
                os.chmod(my_path, 0o600)
            open(my_path, "w").close()
            if sys.platform == 'win32':
                os.chmod(my_path, 0o400)
                assert (os.stat(my_path).st_mode & 0o600) == 0o400
                os.chmod(self.path, 0o700)
            else:
                os.chmod(my_path, 0o200)
                assert (os.stat(my_path).st_mode & 0o777) == 0o200
                os.chmod(self.path, 0o700)

    if hasattr(os, 'fchmod'):
        def test_fchmod(self):
            my_path = self.path2 + 'test_fchmod'
            os = self.posix
            f = open(my_path, "w")
            os.fchmod(f.fileno(), 0o200)
            assert (os.fstat(f.fileno()).st_mode & 0o777) == 0o200
            f.close()
            assert (os.stat(my_path).st_mode & 0o777) == 0o200

    if hasattr(os, 'mkfifo'):
        def test_mkfifo(self):
            os = self.posix
            os.mkfifo(self.path2 + 'test_mkfifo', 0o666)
            st = os.lstat(self.path2 + 'test_mkfifo')
            import stat
            assert stat.S_ISFIFO(st.st_mode)

    if hasattr(os, 'mknod'):
        def test_mknod(self):
            import stat
            os = self.posix
            # os.mknod() may require root priviledges to work at all
            try:
                # not very useful: os.mknod() without specifying 'mode'
                os.mknod(self.path2 + 'test_mknod-1')
            except OSError as e:
                skip("os.mknod(): got %r" % (e,))
            st = os.lstat(self.path2 + 'test_mknod-1')
            assert stat.S_ISREG(st.st_mode)
            # os.mknod() with S_IFIFO
            os.mknod(self.path2 + 'test_mknod-2', 0o600 | stat.S_IFIFO)
            st = os.lstat(self.path2 + 'test_mknod-2')
            assert stat.S_ISFIFO(st.st_mode)

        def test_mknod_with_ifchr(self):
            # os.mknod() with S_IFCHR
            # -- usually requires root priviledges --
            os = self.posix
            if hasattr(os.lstat('.'), 'st_rdev'):
                import stat
                try:
                    os.mknod(self.path2 + 'test_mknod-3', 0o600 | stat.S_IFCHR,
                             0x105)
                except OSError as e:
                    skip("os.mknod() with S_IFCHR: got %r" % (e,))
                else:
                    st = os.lstat(self.path2 + 'test_mknod-3')
                    assert stat.S_ISCHR(st.st_mode)
                    assert st.st_rdev == 0x105

    if hasattr(os, 'nice') and hasattr(os, 'fork') and hasattr(os, 'waitpid'):
        def test_nice(self):
            os = self.posix
            myprio = os.nice(0)
            #
            pid = os.fork()
            if pid == 0:    # in the child
                res = os.nice(3)
                os._exit(res)
            #
            pid1, status1 = os.waitpid(pid, 0)
            assert pid1 == pid
            assert os.WIFEXITED(status1)
            expected = min(myprio + 3, 19)
            assert os.WEXITSTATUS(status1) == expected

    if sys.platform != 'win32':
        def test_symlink(self):
            posix = self.posix
            bytes_dir = self.bytes_dir
            if bytes_dir is None:
                skip("encoding not good enough")
            dest = bytes_dir + b"/file.txt"
            posix.symlink(bytes_dir + b"/somefile", dest)
            try:
                with open(dest) as f:
                    data = f.read()
                    assert data == "who cares?"
            finally:
                posix.unlink(dest)
            posix.symlink(memoryview(bytes_dir + b"/somefile"), dest)
            try:
                with open(dest) as f:
                    data = f.read()
                    assert data == "who cares?"
            finally:
                posix.unlink(dest)

        # XXX skip test if dir_fd is unsupported
        def test_symlink_fd(self):
            posix = self.posix
            bytes_dir = self.bytes_dir
            f = posix.open(bytes_dir, posix.O_RDONLY)
            try:
                posix.symlink('somefile', 'somelink', dir_fd=f)
                assert (posix.readlink(bytes_dir + '/somelink'.encode()) ==
                        'somefile'.encode())
            finally:
                posix.close(f)
                posix.unlink(bytes_dir + '/somelink'.encode())

        def test_symlink_fspath(self):
            posix = self.posix
            bytes_dir = self.bytes_dir
            if bytes_dir is None:
                skip("encoding not good enough")
            dest = self.Path(bytes_dir + b"/file.txt")
            posix.symlink(self.Path(bytes_dir + b"/somefile"), dest)
            try:
                with open(dest) as f:
                    data = f.read()
                    assert data == "who cares?"
            finally:
                posix.unlink(dest)

        def test_readlink(self):
            os = self.posix
            pdir = self.pdir
            src = pdir + "/somefile"
            dest = pdir + "/file.txt"
            os.symlink(dest, src)
            try:
                assert os.readlink(src) == dest
                assert os.readlink(src.encode()) == dest.encode()
                assert os.readlink(self.Path(src)) == dest
                assert os.readlink(self.Path(src.encode())) == dest.encode()
            finally:
                os.unlink(src)

    else:
        def test_symlink(self):
            posix = self.posix
            with raises(NotImplementedError):
                posix.symlink('a', 'b')

    if hasattr(os, 'ftruncate'):
        def test_truncate(self):
            posix = self.posix
            dest = self.path2

            def mkfile(dest, size=4):
                with open(dest, 'wb') as f:
                    f.write(b'd' * size)

            # Check invalid inputs
            mkfile(dest)
            with raises(OSError):
                posix.truncate(dest, -1)
            with open(dest, 'rb') as f:  # f is read-only so cannot be truncated
                with raises(OSError):
                    posix.truncate(f.fileno(), 1)
            with raises(TypeError):
                posix.truncate(dest, None)
            with raises(TypeError):
                posix.truncate(None, None)

            # Truncate via file descriptor
            mkfile(dest)
            with open(dest, 'wb') as f:
                posix.truncate(f.fileno(), 1)
            assert 1 == posix.stat(dest).st_size

            # Truncate via filename
            mkfile(dest)
            posix.truncate(dest, 1)
            assert 1 == posix.stat(dest).st_size

            # File does not exist
            with raises(OSError) as e:
                posix.truncate(dest + '-DOESNT-EXIST', 0)
            assert e.value.filename == dest + '-DOESNT-EXIST'
            posix = self.posix
            dest = self.path2

            def mkfile(dest, size=4):
                with open(dest, 'wb') as f:
                    f.write(b'd' * size)

            # Check invalid inputs
            mkfile(dest)
            with raises(OSError):
                posix.truncate(dest, -1)
            with open(dest, 'rb') as f:  # f is read-only so cannot be truncated
                with raises(OSError):
                    posix.truncate(f.fileno(), 1)
            with raises(TypeError):
                posix.truncate(dest, None)
            with raises(TypeError):
                posix.truncate(None, None)

            # Truncate via file descriptor
            mkfile(dest)
            with open(dest, 'wb') as f:
                posix.truncate(f.fileno(), 1)
            assert 1 == posix.stat(dest).st_size

            # Truncate via filename
            mkfile(dest)
            posix.truncate(dest, 1)
            assert 1 == posix.stat(dest).st_size

            # File does not exist
            with raises(OSError) as e:
                posix.truncate(dest + '-DOESNT-EXIST', 0)
            assert e.value.filename == dest + '-DOESNT-EXIST'

    try:
        os.getlogin()
    except (AttributeError, OSError):
        pass
    else:
        def test_getlogin(self):
            assert isinstance(self.posix.getlogin(), str)
            # How else could we test that getlogin is properly
            # working?

    def test_has_kill(self):
        os = self.posix
        assert hasattr(os, 'kill')

    def test_pipe_flush(self):
        import io
        ffd, gfd = self.posix.pipe()
        f = io.open(ffd, 'r')
        g = io.open(gfd, 'w')
        g.write('he')
        g.flush()
        x = f.read(1)
        assert x == 'h'
        f.flush()
        x = f.read(1)
        assert x == 'e'

    def test_pipe_inheritable(self):
        fd1, fd2 = self.posix.pipe()
        assert self.posix.get_inheritable(fd1) == False
        assert self.posix.get_inheritable(fd2) == False
        self.posix.close(fd1)
        self.posix.close(fd2)

    def test_pipe2(self):
        if not hasattr(self.posix, 'pipe2'):
            skip("no pipe2")
        fd1, fd2 = self.posix.pipe2(0)
        assert self.posix.get_inheritable(fd1) == True
        assert self.posix.get_inheritable(fd2) == True
        self.posix.close(fd1)
        self.posix.close(fd2)

    def test_O_CLOEXEC(self):
        if not hasattr(self.posix, 'pipe2'):
            skip("no pipe2")
        if not hasattr(self.posix, 'O_CLOEXEC'):
            skip("no O_CLOEXEC")
        fd1, fd2 = self.posix.pipe2(self.posix.O_CLOEXEC)
        assert self.posix.get_inheritable(fd1) == False
        assert self.posix.get_inheritable(fd2) == False
        self.posix.close(fd1)
        self.posix.close(fd2)

    def test_dup2_inheritable(self):
        fd1, fd2 = self.posix.pipe()
        assert self.posix.get_inheritable(fd2) == False
        self.posix.dup2(fd1, fd2)
        assert self.posix.get_inheritable(fd2) == True
        self.posix.dup2(fd1, fd2, False)
        assert self.posix.get_inheritable(fd2) == False
        self.posix.dup2(fd1, fd2, True)
        assert self.posix.get_inheritable(fd2) == True
        self.posix.close(fd1)
        self.posix.close(fd2)

    def test_open_inheritable(self):
        os = self.posix
        fd = os.open(self.path2 + 'test_open_inheritable',
                     os.O_RDWR | os.O_CREAT, 0o666)
        assert os.get_inheritable(fd) == False
        os.close(fd)

    if sys.platform != 'win32':
        def test_sync(self):
            self.posix.sync()   # does not raise

        def test_blocking(self):
            posix = self.posix
            fd = posix.open(self.path, posix.O_RDONLY)
            assert posix.get_blocking(fd) is True
            posix.set_blocking(fd, False)
            assert posix.get_blocking(fd) is False
            posix.set_blocking(fd, True)
            assert posix.get_blocking(fd) is True
            posix.close(fd)

        def test_blocking_error(self):
            posix = self.posix
            with raises(OSError):
                posix.get_blocking(1234567)
            with raises(OSError):
                posix.set_blocking(1234567, True)

        def test_sendfile(self):
            import _socket, posix
            s1, s2 = _socket.socketpair()
            fd = posix.open(self.path, posix.O_RDONLY)
            res = posix.sendfile(s1.fileno(), fd, 3, 5)
            assert res == 5
            assert posix.lseek(fd, 0, 1) == 0
            data = s2.recv(10)
            expected = b'this is a test'[3:8]
            assert data == expected
            posix.close(fd)
            s2.close()
            s1.close()

        def test_filename_can_be_a_buffer(self):
            import posix, sys
            fsencoding = sys.getfilesystemencoding()
            pdir = (self.pdir + '/file1').encode(fsencoding)
            fd = posix.open(pdir, posix.O_RDONLY)
            posix.close(fd)
            fd = posix.open(memoryview(pdir), posix.O_RDONLY)
            posix.close(fd)

        def test_getgrouplist(self):
            import posix, getpass
            gid = posix.getgid()
            user = getpass.getuser()
            groups = posix.getgrouplist(user, gid)
            assert gid in groups

    if sys.platform.startswith('linux'):
        def test_sendfile_no_offset(self):
            import _socket, posix
            s1, s2 = _socket.socketpair()
            fd = posix.open(self.path, posix.O_RDONLY)
            posix.lseek(fd, 3, 0)
            res = posix.sendfile(s1.fileno(), fd, None, 5)
            assert res == 5
            assert posix.lseek(fd, 0, 1) == 8
            data = s2.recv(10)
            expected = b'this is a test'[3:8]
            assert data == expected
            posix.close(fd)
            s2.close()
            s1.close()

        def test_os_lockf(self):
            posix = os = self.posix
            fd = os.open(self.path2 + 'test_os_lockf', os.O_WRONLY | os.O_CREAT)
            try:
                os.write(fd, b'test')
                os.lseek(fd, 0, 0)
                posix.lockf(fd, posix.F_LOCK, 4)
                posix.lockf(fd, posix.F_ULOCK, 4)
            finally:
                os.close(fd)

    def test_urandom(self):
        os = self.posix
        raises(ValueError, os.urandom, -1)
        s = os.urandom(5)
        assert isinstance(s, bytes)
        assert len(s) == 5
        for x in range(50):
            if s != os.urandom(5):
                break
        else:
            assert False, "urandom() always returns the same string"
            # Or very unlucky

    if hasattr(os, 'startfile'):
        def test_startfile(self):
            if not self.runappdirect:
                skip("should not try to import cffi at app-level")
            startfile = self.posix.startfile
            for t1 in [str, unicode]:
                for t2 in [str, unicode]:
                    with raises(WindowsError) as e:
                        startfile(t1("\\"), t2("close"))
                    assert e.value.args[0] == 1155
                    assert e.value.args[1] == (
                        "No application is associated with the "
                        "specified file for this operation")
                    if len(e.value.args) > 2:
                        assert e.value.args[2] == t1("\\")
            #
            with raises(WindowsError) as e:
                startfile("\\foo\\bar\\baz")
            assert e.value.args[0] == 2
            assert e.value.args[1] == (
                "The system cannot find the file specified")
            if len(e.value.args) > 2:
                assert e.value.args[2] == "\\foo\\bar\\baz"

    @pytest.mark.skipif("sys.platform != 'win32'")
    def test_rename(self):
        os = self.posix
        fname = self.path2 + 'rename.txt'
        with open(fname, "w") as f:
            f.write("this is a rename test")
        str_name = str(self.pdir) + '/test_rename.txt'
        os.rename(fname, str_name)
        with open(str_name) as f:
            assert f.read() == 'this is a rename test'
        os.rename(str_name, fname)
        unicode_name = str(self.udir) + u'/test\u03be.txt'
        os.rename(fname, unicode_name)
        with open(unicode_name) as f:
            assert f.read() == 'this is a rename test'
        os.rename(unicode_name, fname)

        os.rename(bytes(fname, 'utf-8'), bytes(str_name, 'utf-8'))
        with open(str_name) as f:
            assert f.read() == 'this is a rename test'
        os.rename(str_name, fname)
        with open(fname) as f:
            assert f.read() == 'this is a rename test'
        os.unlink(fname)


    def test_device_encoding(self):
        import sys
        encoding = self.posix.device_encoding(sys.stdout.fileno())
        # just ensure it returns something reasonable
        assert encoding is None or type(encoding) is str

    if os.name == 'nt':
        def test__getfileinformation(self):
            os = self.posix
            path = '\\'.join([self.pdir, 'file1'])
            with open(path) as fp:
                info = self.posix._getfileinformation(fp.fileno())
            assert len(info) == 3
            assert all(isinstance(obj, int) for obj in info)

        def test__getfinalpathname(self):
            os = self.posix
            path = '\\'.join([self.pdir, 'file1'])
            try:
                result = self.posix._getfinalpathname(path)
            except NotImplementedError:
                skip("_getfinalpathname not supported on this platform")
            assert os.stat(result) is not None

    @py.test.mark.skipif("sys.platform == 'win32'")
    def test_rtld_constants(self):
        # check presence of major RTLD_* constants
        self.posix.RTLD_LAZY
        self.posix.RTLD_NOW
        self.posix.RTLD_GLOBAL
        self.posix.RTLD_LOCAL

    @py.test.mark.skipif("sys.platform != 'win32'")
    def test_win_constants(self):
        win_constants =['_LOAD_LIBRARY_SEARCH_DEFAULT_DIRS',
                        '_LOAD_LIBRARY_SEARCH_APPLICATION_DIR',
                        '_LOAD_LIBRARY_SEARCH_SYSTEM32',
                        '_LOAD_LIBRARY_SEARCH_USER_DIRS',
                        '_LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR',
                       ]
        for name in win_constants:
            print(name, getattr(self.posix, name))

    @py.test.mark.skipif("sys.platform != 'darwin'")
    def test_darwin_constants(self):
        darwin_constants =['_COPYFILE_DATA']
        for name in darwin_constants:
            getattr(self.posix, name)


    def test_error_message(self):
        import sys
        with raises(OSError) as e:
            self.posix.open('nonexistentfile1', 0)
        assert str(e.value).endswith(": 'nonexistentfile1'")

        with raises(OSError) as e:
            self.posix.link('nonexistentfile1', 'bok')
        assert str(e.value).endswith(": 'nonexistentfile1' -> 'bok'")
        with raises(OSError) as e:
            self.posix.rename('nonexistentfile1', 'bok')
        assert str(e.value).endswith(": 'nonexistentfile1' -> 'bok'")
        with raises(OSError) as e:
            self.posix.replace('nonexistentfile1', 'bok')
        assert str(e.value).endswith(": 'nonexistentfile1' -> 'bok'")

        if sys.platform != 'win32':
            with raises(OSError) as e:
                self.posix.symlink('bok', '/nonexistentdir/boz')
            assert str(e.value).endswith(": 'bok' -> '/nonexistentdir/boz'")

    def test_os_fspath(self):
        assert hasattr(self.posix, 'fspath')
        with raises(TypeError):
            self.posix.fspath(None)
        with raises(TypeError) as e:
            self.posix.fspath(42)
        assert str(e.value).endswith('int')
        string = 'string'
        assert self.posix.fspath(string) == string
        assert self.posix.fspath(b'bytes') == b'bytes'
        class Sample:
            def __fspath__(self):
                return 'sample'

        assert self.posix.fspath(Sample()) == 'sample'

        class BSample:
            def __fspath__(self):
                return b'binary sample'

        assert self.posix.fspath(BSample()) == b'binary sample'

        class WrongSample:
            def __fspath__(self):
                return 4

        with raises(TypeError):
            self.posix.fspath(WrongSample())
        with raises(OSError):
            self.posix.replace(self.Path('nonexistentfile1'), 'bok')

    if hasattr(rposix, 'getxattr'):
        def test_xattr_simple(self):
            # Minimal testing here, lib-python has better tests.
            os = self.posix
            with open(self.path, 'wb'):
                pass
            init_names = os.listxattr(self.path)
            with raises(OSError) as excinfo:
                os.getxattr(self.path, 'user.test')
            assert excinfo.value.filename == self.path
            os.setxattr(self.path, 'user.test', b'', os.XATTR_CREATE, follow_symlinks=False)
            with raises(OSError):
                os.setxattr(self.path, 'user.test', b'', os.XATTR_CREATE)
            assert os.getxattr(self.path, 'user.test') == b''
            os.setxattr(self.path, b'user.test', b'foo', os.XATTR_REPLACE)
            assert os.getxattr(self.path, 'user.test', follow_symlinks=False) == b'foo'
            assert set(os.listxattr(self.path)) == set(
                init_names + ['user.test'])
            os.removexattr(self.path, 'user.test', follow_symlinks=False)
            with raises(OSError):
                os.getxattr(self.path, 'user.test')
            assert os.listxattr(self.path, follow_symlinks=False) == init_names

    if hasattr(rposix, 'memfd_create'):
        # minimal testing
        def test_memfd_create(self):
            os = self.posix
            fd = os.memfd_create("abc")
            try:
                s = b"defghi?"
                os.write(fd, s)
            finally:
                os.close(fd)

    def test_get_terminal_size(self):
        os = self.posix
        for args in [(), (1,), (0,), (42421,)]:
            try:
                w, h = os.get_terminal_size(*args)
            except (ValueError, OSError):
                continue
            assert isinstance(w, int)
            assert isinstance(h, int)

    def test_scandir(self):
        retU = [x.name for x in self.posix.scandir(u'.')]
        retP = [x.name for x in self.posix.scandir(self.Path('.'))]
        assert retU == retP

    def test_scandir_fd(self):
        os = self.posix
        fd = None
        try:
            fd = os.open(self.Path('.'), os.O_RDONLY)
        except PermissionError:
            skip("Cannot open '.'")
        try:
            with os.scandir(fd) as it:
                entries = list(it)
            names = os.listdir(fd)
            assert len(entries) == len(names)
        finally:
            os.close(fd)

    def test_execv_no_args(self):
        posix = self.posix
        with raises(ValueError):
            posix.execv("notepad", [])
        # PyPy needs at least one arg, CPython 2.7 is fine without
        with raises(ValueError):
            posix.execve("notepad", [], {})

    def test_execv_bad_args(self):
        posix = self.posix
        with raises(ValueError):
            posix.execv("notepad", ('',))
        with raises(OSError):
            posix.execv("notepad", (' ',))

    def test_execve_invalid_env(self):
        import sys
        os = self.posix
        args = ['notepad', '-c', 'pass']
        newenv = os.environ.copy()
        newenv["FRUIT=VEGETABLE"] = "cabbage"
        with raises(ValueError):
            os.execve(args[0], args, newenv)


@py.test.mark.skipif("sys.platform != 'win32'")
class AppTestNt(object):
    spaceconfig = {'usemodules': USEMODULES}
    def setup_class(cls):
        cls.w_path = space.wrap(str(path))
        cls.w_posix = space.appexec([], GET_POSIX)
        cls.w_Path = space.appexec([], """():
            class Path:
                def __init__(self, _path):
                    self._path =_path
                def __fspath__(self):
                    return self._path
            return Path
            """)


    def test_handle_inheritable(self):
        import _socket
        posix = self.posix
        if hasattr(posix, 'get_handle_inheritable'):
            # PEP 446, python 3.4+
            s = _socket.socket()
            assert not posix.get_handle_inheritable(s.fileno())
            posix.set_handle_inheritable(s.fileno(), True)
            assert posix.get_handle_inheritable(s.fileno())

    def test__getfullpathname(self):
        # issue 3343
        nt = self.posix
        path = nt._getfullpathname(self.path)
        assert self.path in path
        path = nt._getfullpathname(self.Path(self.path))
        assert self.path in path

        # now as bytes
        bpath = self.path.encode()
        path = nt._getfullpathname(bpath)
        assert bpath in path
        path = nt._getfullpathname(self.Path(bpath))
        assert bpath in path

        with raises(TypeError):
            nt._getfullpathname(None)

        with raises(TypeError):
            nt._getfullpathname(1)

        sysdrv = nt.environ.get("SystemDrive", "C:")
        # just see if it does anything
        path = sysdrv + 'hubber'
        assert '\\' in nt._getfullpathname(path)
        assert type(nt._getfullpathname(b'C:')) is bytes

    def test__path_splitroot(self):
        nt = self.posix
        ret = nt._path_splitroot(u'c:\\abc\\def.txt')
        assert ret == (u'c:\\', u'abc\\def.txt') 
        ret = nt._path_splitroot(u'//server/abc/xyz/def.txt')
        assert ret == (u'//server/abc/', u'xyz/def.txt') 

    def test_dll_directory(self):
        nt = self.posix
        ret = nt._add_dll_directory(b'c:\\')
        assert nt._remove_dll_directory(ret)
        ret = nt._add_dll_directory(u'c:\\')
        assert nt._remove_dll_directory(ret)


class AppTestEnvironment(object):
    def setup_class(cls):
        cls.w_path = space.wrap(str(path))
        cls.w_posix = space.appexec([], GET_POSIX)
        cls.w_python = space.wrap(sys.executable)

    def test_environ(self):
        import sys
        environ = self.posix.environ
        if not environ:
            skip('environ not filled in for untranslated tests')
        if sys.platform == 'win32':
            rawenv = str
        else:
            rawenv = bytes
        for k, v in environ.items():
            assert type(k) is rawenv
            assert type(v) is rawenv
        name = next(iter(environ))
        assert environ[name] is not None
        del environ[name]
        with raises(KeyError):
            environ[name]

    @pytest.mark.dont_track_allocations('putenv intentionally keeps strings alive')
    def test_environ_nonascii(self):
        import sys
        os = self.posix
        name, value = 'PYPY_TEST_日本', 'foobar日本'
        if not sys.platform == 'win32':
            fsencoding = sys.getfilesystemencoding()
            for s in name, value:
                try:
                    s.encode(fsencoding, 'surrogateescape')
                except UnicodeEncodeError:
                    skip("Requires %s.encode(sys.getfilesystemencoding(), "
                         "'surogateescape') to succeed (or win32)" % ascii(s))

        os.environ[name] = value
        assert os.environ[name] == value
        del os.environ[name]
        assert os.environ.get(name) is None

    def test_unsetenv_nonexisting(self):
        os = self.posix
        os.unsetenv("XYZABC") #does not raise
        try:
            os.environ["ABCABC"]
        except KeyError:
            pass
        else:
            raise AssertionError("did not raise KeyError")
        os.environ["ABCABC"] = "1"
        assert os.environ["ABCABC"] == "1"
        os.unsetenv("ABCABC")
        cmd = ('%s -c "import os, sys; '
               'sys.exit(int(\'ABCABC\' in os.environ))" '
               % self.python)
        res = os.system(cmd)
        assert res == 0


@py.test.fixture
def check_fsencoding(space, pytestconfig):
    if pytestconfig.getvalue('runappdirect'):
        fsencoding = sys.getfilesystemencoding()
    else:
        fsencoding = space.sys.filesystemencoding
    try:
        u"ą".encode(fsencoding)
    except UnicodeEncodeError:
        py.test.skip("encoding not good enough")

@py.test.mark.usefixtures('check_fsencoding')
class AppTestPosixUnicode:
    spaceconfig = {'usemodules': USEMODULES}
    def setup_class(cls):
        cls.w_posix = space.appexec([], GET_POSIX)

    def test_stat_unicode(self):
        # test that passing unicode would not raise UnicodeDecodeError
        try:
            self.posix.stat(u"ą")
        except OSError:
            pass

    def test_open_unicode(self):
        os = self.posix
        # Ensure passing unicode doesn't raise UnicodeEncodeError
        try:
            os.open(u"ą", os.O_WRONLY)
        except OSError:
            pass

    def test_remove_unicode(self):
        # See 2 above ;)
        try:
            self.posix.remove(u"ą")
        except OSError:
            pass


class AppTestUnicodeFilename:
    def setup_class(cls):
        ufilename = (unicode(udir.join('test_unicode_filename_')) +
                     '\u65e5\u672c.txt') # "Japan"
        try:
            f = file(ufilename, 'w')
        except (UnicodeEncodeError, IOError):
            pytest.skip("encoding not good enough")
        f.write("test")
        f.close()
        cls.space = space
        cls.w_filename = space.wrap(ufilename)
        cls.w_posix = space.appexec([], GET_POSIX)

    def test_open(self):
        fd = self.posix.open(self.filename, self.posix.O_RDONLY)
        try:
            content = self.posix.read(fd, 50)
        finally:
            self.posix.close(fd)
        assert content == b"test"


class AppTestPep475Retry:
    spaceconfig = {'usemodules': USEMODULES}

    def setup_class(cls):
        if os.name != 'posix':
            skip("xxx tests are posix-only")
        if cls.runappdirect:
            skip("xxx does not work with -A")

        def fd_data_after_delay(space):
            g = os.popen("sleep 5 && echo hello", "r")
            cls._keepalive_g = g
            return space.wrap(g.fileno())

        cls.w_posix = space.appexec([], GET_POSIX)
        cls.w_fd_data_after_delay = cls.space.wrap(
            interp2app(fd_data_after_delay))

    def test_pep475_retry_read(self):
        import _signal as signal
        signalled = []

        def foo(*args):
            signalled.append("ALARM")

        signal.signal(signal.SIGALRM, foo)
        try:
            fd = self.fd_data_after_delay()
            signal.alarm(1)
            got = self.posix.read(fd, 100)
            self.posix.close(fd)
        finally:
            signal.signal(signal.SIGALRM, signal.SIG_DFL)

        assert signalled != []
        assert got.startswith(b'h')

        
