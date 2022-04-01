# encoding: utf-8
from pypy.interpreter.gateway import interp2app
from rpython.tool.udir import udir
import os


class AppTestFileIO:
    spaceconfig = dict(usemodules=['_io', 'array'])
    if os.name != 'nt':
        spaceconfig['usemodules'].append('fcntl')

    def setup_method(self, meth):
        tmpfile = udir.join('tmpfile')
        tmpfile.write("a\nb\nc", mode='wb')
        self.w_tmpfile = self.space.wrap(str(tmpfile))
        self.w_tmpdir = self.space.wrap(str(udir))
        self.w_posix = self.space.appexec([], """():
            import %s as m;
            return m""" % os.name)
        if meth == self.test_readinto_optimized:
            bigfile = udir.join('bigfile')
            bigfile.write('a' * 1000, mode='wb')
            self.w_bigfile = self.space.wrap(self.space.wrap(str(bigfile)))

    def test_constructor(self):
        import _io
        f = _io.FileIO(self.tmpfile, 'a')
        assert f.name.endswith('tmpfile')
        assert f.mode == 'ab'
        assert f.closefd is True
        assert f._blksize >= 1024
        assert f._blksize % 1024 == 0
        f.close()

    def test_invalid_fd(self):
        import _io
        raises(ValueError, _io.FileIO, -10)
        raises(TypeError, _io.FileIO, 2 ** 31)
        raises(TypeError, _io.FileIO, -2 ** 31 - 1)

    def test_weakrefable(self):
        import _io
        from weakref import proxy
        f = _io.FileIO(self.tmpfile)
        p = proxy(f)
        assert p.mode == 'rb'
        f.close()

    def test_open_fd(self):
        import _io
        os = self.posix
        fd = os.open(self.tmpfile, os.O_RDONLY, 0o666)
        f = _io.FileIO(fd, "rb", closefd=False)
        assert f.fileno() == fd
        assert f.closefd is False
        f.close()
        os.close(fd)

    def test_open_directory(self):
        import _io
        import os, warnings
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter('always', ResourceWarning)
            raises(IOError, _io.FileIO, self.tmpdir, "rb")
            assert len(w) == 0
        if os.name != 'nt':
            fd = os.open(self.tmpdir, os.O_RDONLY)
            raises(IOError, _io.FileIO, fd, "rb")
            os.close(fd)

    def test_open_non_existent_unicode(self):
        import _io
        import os
        path = os.path.join(self.tmpdir, '_pypy-日本')
        try:
            os.fsencode(path)
        except UnicodeEncodeError:
            import sys
            skip("can't run this test with %s as filesystem encoding" %
                 sys.getfilesystemencoding())
        exc = raises(IOError, _io.FileIO, path)
        expected = "[Errno 2] No such file or directory: %r" % path
        assert str(exc.value) == expected

    def test_readline(self):
        import _io
        f = _io.FileIO(self.tmpfile, 'rb')
        assert f.readline() == b'a\n'
        assert f.readline() == b'b\n'
        assert f.readline() == b'c'
        assert f.readline() == b''
        f.close()

    def test_support_fspath(self):
        import _io
        class P(object):
            def __fspath__(x):
                return self.tmpfile
        f = _io.FileIO(P(), 'rb')
        assert f.readline() == b'a\n'
        f.close()

    def test_readlines(self):
        import _io
        f = _io.FileIO(self.tmpfile, 'rb')
        assert f.readlines() == [b"a\n", b"b\n", b"c"]
        f.seek(0)
        assert f.readlines(3) == [b"a\n", b"b\n"]
        f.close()

    def test_readall(self):
        import _io
        f = _io.FileIO(self.tmpfile, 'rb')
        assert f.readall() == b"a\nb\nc"
        f.close()

    def test_write(self):
        import _io
        filename = self.tmpfile + '_w'
        f = _io.FileIO(filename, 'wb')
        f.write(b"test")
        # try without flushing
        f2 = _io.FileIO(filename, 'rb')
        assert f2.read() == b"test"
        f.close()
        f2.close()

    def test_writelines(self):
        import _io
        filename = self.tmpfile + '_w'
        f = _io.FileIO(filename, 'wb')
        f.writelines([b"line1\n", b"line2", b"line3"])
        f2 = _io.FileIO(filename, 'rb')
        assert f2.read() == b"line1\nline2line3"
        f.close()
        f2.close()

    def test_seek(self):
        import _io
        f = _io.FileIO(self.tmpfile, 'rb')
        f.seek(0)
        self.posix.close(f.fileno())
        raises(IOError, f.seek, 0)

    def test_tell(self):
        import _io
        f = _io.FileIO(self.tmpfile, 'rb')
        f.seek(3)
        assert f.tell() == 3
        f.close()

    def test_truncate(self):
        import _io
        f = _io.FileIO(self.tmpfile, 'r+b')
        assert f.truncate(100) == 100 # grow the file
        f.close()
        f = _io.FileIO(self.tmpfile)
        assert len(f.read()) == 100
        f.close()
        #
        f = _io.FileIO(self.tmpfile, 'r+b')
        f.seek(50)
        assert f.truncate() == 50
        f.close()
        f = _io.FileIO(self.tmpfile)
        assert len(f.read()) == 50
        f.close()

    def test_readinto(self):
        import _io
        a = bytearray(b'x' * 10)
        f = _io.FileIO(self.tmpfile, 'r+')
        assert f.readinto(a) == 5
        f.seek(0)
        m = memoryview(bytearray(b"helloworld"))
        assert f.readinto(m) == 5
        #
        exc = raises(TypeError, f.readinto, u"hello")
        msg = str(exc.value)
        # print(msg)
        assert " read-write b" in msg and msg.endswith(", not str")
        #
        exc = raises(TypeError, f.readinto, memoryview(b"hello"))
        msg = str(exc.value)
        # print(msg)
        assert " read-write b" in msg and msg.endswith(", not memoryview")
        #
        f.close()
        assert a == b'a\nb\ncxxxxx'
        #
        a = bytearray(b'x' * 10)
        f = _io.FileIO(self.tmpfile, 'r+')
        f.truncate(3)
        assert f.readinto(a) == 3
        f.close()
        assert a == b'a\nbxxxxxxx'

    def test_readinto_optimized(self):
        import _io
        a = bytearray(b'x' * 1024)
        f = _io.FileIO(self.bigfile, 'r+')
        assert f.readinto(a) == 1000
        assert a == b'a' * 1000 + b'x' * 24

    def test_readinto_array(self):
        import _io, array
        buffer = array.array('i', [0]*10)
        m = memoryview(buffer)
        f = _io.FileIO(self.tmpfile, 'r+')
        assert f.readinto(m[1:9]) == 5
        assert buffer[1] in (0x610a620a, 0x0a620a61)

    def test_nonblocking_read(self):
        try:
            import os, fcntl
        except ImportError:
            skip("need fcntl to set nonblocking mode")
        r_fd, w_fd = os.pipe()
        # set nonblocking
        fcntl.fcntl(r_fd, fcntl.F_SETFL, os.O_NONBLOCK)
        import _io
        f = _io.FileIO(r_fd, 'r')
        # Read from stream sould return None
        assert f.read() is None
        assert f.read(10) is None
        a = bytearray(b'x' * 10)
        assert f.readinto(a) is None
        a2 = bytearray(b'x' * 1024)
        assert f.readinto(a2) is None

    def test_pipe_append(self):
        import os
        r, w = os.pipe()
        try:
            try:
                f = open(w, 'a') # does not crash!
            finally:
                f.close()
        finally:
            os.close(r)

    def test_repr(self):
        import _io
        f = _io.FileIO(self.tmpfile, 'r')
        assert repr(f) == ("<_io.FileIO name=%r mode='%s' closefd=True>"
                           % (f.name, f.mode))
        del f.name
        assert repr(f) == ("<_io.FileIO fd=%r mode='%s' closefd=True>"
                           % (f.fileno(), f.mode))
        f.close()
        assert repr(f) == "<_io.FileIO [closed]>"

    def test_unclosed_fd_on_exception(self):
        import _io
        import os
        class MyException(Exception): pass
        class MyFileIO(_io.FileIO):
            def __setattr__(self, name, value):
                if name == "name":
                    raise MyException("blocked setting name")
                return super(MyFileIO, self).__setattr__(name, value)
        fd = os.open(self.tmpfile, os.O_RDONLY)
        raises(MyException, MyFileIO, fd)
        os.close(fd)  # should not raise OSError(EBADF)

    def test_mode_strings(self):
        import _io
        import os
        for modes in [('w', 'wb'), ('wb', 'wb'), ('wb+', 'rb+'),
                      ('w+b', 'rb+'), ('a', 'ab'), ('ab', 'ab'),
                      ('ab+', 'ab+'), ('a+b', 'ab+'), ('r', 'rb'),
                      ('rb', 'rb'), ('rb+', 'rb+'), ('r+b', 'rb+')]:
            # read modes are last so that TESTFN will exist first
            with _io.FileIO(self.tmpfile, modes[0]) as f:
                assert f.mode == modes[1]

    def test_flush_error_on_close(self):
        # Test that the file is closed despite failed flush
        # and that flush() is called before file closed.
        import _io, os
        fd = os.open(self.tmpfile, os.O_RDONLY, 0o666)
        f = _io.FileIO(fd, 'r', closefd=False)
        closed = []
        def bad_flush():
            closed[:] = [f.closed]
            raise IOError()
        f.flush = bad_flush
        raises(IOError, f.close) # exception not swallowed
        assert f.closed
        assert closed         # flush() called
        assert not closed[0]  # flush() called before file closed
        os.close(fd)

    def test_open_exclusive(self):
        # XXX: should raise FileExistsError
        FileExistsError = OSError

        import _io
        filename = self.tmpfile + '_x1'
        raises(ValueError, _io.FileIO, filename, 'xw')
        with _io.FileIO(filename, 'x') as f:
            assert f.mode == 'xb'
        raises(FileExistsError, _io.FileIO, filename, 'x')

    def test_non_inheritable(self):
        import _io
        os = self.posix
        f = _io.FileIO(self.tmpfile, 'r')
        assert os.get_inheritable(f.fileno()) == False
        f.close()

    def test_FileIO_fd_does_not_change_inheritable(self):
        import _io
        os = self.posix
        fd1, fd2 = os.pipe()
        os.set_inheritable(fd1, True)
        os.set_inheritable(fd2, False)
        f1 = _io.FileIO(fd1, 'r')
        f2 = _io.FileIO(fd2, 'w')
        assert os.get_inheritable(fd1) == True
        assert os.get_inheritable(fd2) == False
        f1.close()
        f2.close()

    def test_close_upon_reinit(self):
        import _io
        os = self.posix
        f = _io.FileIO(self.tmpfile, 'r')
        fd1 = f.fileno()
        f.__init__(self.tmpfile, 'w')
        fd2 = f.fileno()
        if fd1 != fd2:
            raises(OSError, os.close, fd1)

    def test_opener_negative(self):
        import _io
        def opener(*args):
            return -1
        raises(ValueError, _io.FileIO, "foo", 'r', opener=opener)

    def test_seek_bom(self):
        # The BOM is not written again when seeking manually
        import _io
        filename = self.tmpfile + '_x3'
        for charset in ('utf-8-sig', 'utf-16', 'utf-32'):
            with _io.open(filename, 'w', encoding=charset) as f:
                f.write('aaa')
                pos = f.tell()
            with _io.open(filename, 'r+', encoding=charset) as f:
                f.seek(pos)
                f.write('zzz')
                f.seek(0)
                f.write('bbb')
            with _io.open(filename, 'rb') as f:
                assert f.read() == 'bbbzzz'.encode(charset)

    def test_seek_append_bom(self):
        # Same test, but first seek to the start and then to the end
        import _io, os
        filename = self.tmpfile + '_x3'
        for charset in ('utf-8-sig', 'utf-16', 'utf-32'):
            with _io.open(filename, 'w', encoding=charset) as f:
                f.write('aaa')
            with _io.open(filename, 'a', encoding=charset) as f:
                f.seek(0)
                f.seek(0, os.SEEK_END)
                f.write('xxx')
            with _io.open(filename, 'rb') as f:
                assert f.read() == 'aaaxxx'.encode(charset)


def test_flush_at_exit():
    from pypy import conftest
    from pypy.tool.option import make_config, make_objspace
    from rpython.tool.udir import udir

    tmpfile = udir.join('test_flush_at_exit')
    config = make_config(conftest.option)
    space = make_objspace(config)
    space.appexec([space.wrap(str(tmpfile))], """(tmpfile):
        import io
        f = io.open(tmpfile, 'w', encoding='ascii')
        f.write(u'42')
        # no flush() and no close()
        import sys; sys._keepalivesomewhereobscure = f
    """)
    space.finish()
    assert tmpfile.read() == '42'


def test_flush_at_exit_IOError_and_ValueError():
    from pypy import conftest
    from pypy.tool.option import make_config, make_objspace

    config = make_config(conftest.option)
    space = make_objspace(config)
    space.appexec([], """():
        import io
        class MyStream(io.IOBase):
            def flush(self):
                raise IOError

        class MyStream2(io.IOBase):
            def flush(self):
                raise ValueError

        s = MyStream()
        s2 = MyStream2()
        import sys; sys._keepalivesomewhereobscure = s
    """)
    space.finish() # the IOError has been ignored

def monkeypatch_may_ignore_finalize(monkeypatch):
    from rpython.rlib import rgc
    orig_func = rgc.may_ignore_finalizer

    calls = []
    def may_ignore_finalizer(obj):
        calls.append(obj)
        return orig_func(obj)

    monkeypatch.setattr(rgc, "may_ignore_finalizer", may_ignore_finalizer)
    return calls

def test_close_unregisters_finalizer(space, monkeypatch):
    from pypy.module._io.interp_iobase import W_IOBase
    calls = monkeypatch_may_ignore_finalize(monkeypatch)

    w_base = W_IOBase(space, add_to_autoflusher=False)
    w_base.close_w(space)
    assert calls == [w_base]

    w_base.close_w(space)
    assert calls == [w_base]

    # user-defined subclass with __del__, we must not see a call to
    # may_ignore_finalizer about it
    w_s = space.appexec([], """():
        import _io
        class SubclassWithDel(_io._IOBase):
            pass
        s = SubclassWithDel()
        s.close()
        return s
    """)

    assert w_s not in calls


def test_close_unregisters_finalizer_fileio(space, monkeypatch):
    from pypy.module._io.interp_fileio import W_FileIO
    calls = monkeypatch_may_ignore_finalize(monkeypatch)

    w_base = W_FileIO(space)
    w_base.close_w(space)
    assert calls == [w_base]

    w_base.close_w(space)
    assert calls == [w_base]

    # user-defined subclass with __del__, we must not see a call to
    # may_ignore_finalizer about it
    w_s = space.appexec([space.newtext(__file__)], """(fn):
        import _io
        class SubclassWithDel(_io.FileIO):
            pass
        s = SubclassWithDel(fn)
        s.close()
        return s
    """)

    assert w_s not in calls


def test_close_unregisters_finalizer_open(space, monkeypatch):
    from rpython.rlib import rgc
    calls = monkeypatch_may_ignore_finalize(monkeypatch)

    w_f = space.appexec([space.newtext(__file__)], """(fn):
        f = open(fn, "r", encoding="utf-8")
        f.close()
        return f
    """)

    assert w_f in calls
    assert w_f.w_buffer in calls
    assert w_f.w_buffer.w_raw in calls
