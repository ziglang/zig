from __future__ import with_statement
from rpython import rlib
from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import interp2app
from rpython.tool.udir import udir
from pypy.module._io import interp_bufferedio
from pypy.interpreter.error import OperationError
import py.test
import os


class AppTestBufferedReader:
    spaceconfig = dict(usemodules=['_io'])
    if os.name != 'nt':
        spaceconfig['usemodules'].append('fcntl')
        
    def setup_class(cls):
        tmpfile = udir.join('tmpfile')
        tmpfile.write("a\nb\nc", mode='wb')
        cls.w_tmpfile = cls.space.wrap(str(tmpfile))
        bigtmpfile = udir.join('bigtmpfile')
        bigtmpfile.write("a\nb\nc" * 20, mode='wb')
        cls.w_bigtmpfile = cls.space.wrap(str(bigtmpfile))
        #
        cls.w_posix = cls.space.appexec([], """():
            import %s as m;
            return m""" % os.name)

    def test_simple_read(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        f = _io.BufferedReader(raw)
        assert f.read() == b"a\nb\nc"
        raises(ValueError, f.read, -2)
        f.close()
        #
        raw = _io.FileIO(self.tmpfile, 'r+')
        f = _io.BufferedReader(raw)
        r = f.read(4)
        assert r == b"a\nb\n"
        assert f.readable() is True
        assert f.writable() is False
        f.close()

    def test_read_pieces(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        f = _io.BufferedReader(raw)
        assert f.read(3) == b"a\nb"
        assert f.read(3) == b"\nc"
        assert f.read(3) == b""
        assert f.read(3) == b""
        f.close()

    def test_slow_provider(self):
        import _io
        class MockIO(_io._IOBase):
            def readable(self):
                return True
            def readinto(self, buf):
                buf[:3] = b"abc"
                return 3
        bufio = _io.BufferedReader(MockIO())
        r = bufio.read(5)
        assert r == b"abcab"

    def test_read_past_eof(self):
        import _io
        class MockIO(_io._IOBase):
            stack = [b"abc", b"d", b"efg"]
            def readable(self):
                return True
            def readinto(self, buf):
                if self.stack:
                    data = self.stack.pop(0)
                    buf[:len(data)] = data
                    return len(data)
                else:
                    return 0
        bufio = _io.BufferedReader(MockIO())
        assert bufio.read(9000) == b"abcdefg"

    def test_valid_buffer(self):
        import _io

        class MockIO(_io._IOBase):
            def readable(self):
                return True

            def readinto(self, buf):
                # Check that `buf` is a valid memoryview object
                assert buf.itemsize == 1
                assert buf.strides == (1,)
                assert buf.shape == (len(buf),)
                return len(bytes(buf))

        bufio = _io.BufferedReader(MockIO())
        assert len(bufio.read(5)) == 5  # Note: PyPy zeros the buffer, CPython does not

    def test_buffering(self):
        import _io
        data = b"abcdefghi"
        dlen = len(data)
        class MockFileIO(_io.BytesIO):
            def __init__(self, data):
                self.read_history = []
                _io.BytesIO.__init__(self, data)

            def read(self, n=None):
                res = _io.BytesIO.read(self, n)
                self.read_history.append(None if res is None else len(res))
                return res

            def readinto(self, b):
                res = _io.BytesIO.readinto(self, b)
                self.read_history.append(res)
                return res


        tests = [
            [ 100, [ 3, 1, 4, 8 ], [ dlen, 0 ] ],
            [ 100, [ 3, 3, 3],     [ dlen ]    ],
            [   4, [ 1, 2, 4, 2 ], [ 4, 4, 1 ] ],
        ]

        for bufsize, buf_read_sizes, raw_read_sizes in tests:
            rawio = MockFileIO(data)
            bufio = _io.BufferedReader(rawio, buffer_size=bufsize)
            pos = 0
            for nbytes in buf_read_sizes:
                assert bufio.read(nbytes) == data[pos:pos+nbytes]
                pos += nbytes
            # this is mildly implementation-dependent
            assert rawio.read_history == raw_read_sizes

    def test_peek(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        f = _io.BufferedReader(raw)
        assert f.read(2) == b'a\n'
        assert f.peek().startswith(b'b\nc')
        assert f.read(3) == b'b\nc'
        assert f.peek() == b''

    def test_read1(self):
        import _io
        class RecordingFileIO(_io.FileIO):
            def read(self, size=-1):
                self.nbreads += 1
                return _io.FileIO.read(self, size)
            def readinto(self, buf):
                self.nbreads += 1
                return _io.FileIO.readinto(self, buf)
        raw = RecordingFileIO(self.tmpfile)
        raw.nbreads = 0
        f = _io.BufferedReader(raw, buffer_size=3)
        assert f.read(1) == b'a'
        assert f.read1(1) == b'\n'
        assert raw.nbreads == 1
        assert f.read1(100) == b'b'
        assert raw.nbreads == 1
        assert f.read1(100) == b'\nc'
        assert raw.nbreads == 2
        assert f.read1(100) == b''
        assert raw.nbreads == 3
        f.close()

        # a negative argument (or no argument) leads to using the default
        # buffer size
        raw = _io.BytesIO(b'aaaa\nbbbb\ncccc\n')
        f = _io.BufferedReader(raw, buffer_size=3)
        assert f.read1(-1) == b'aaa'
        assert f.read1() == b'a\nb'


    def test_readinto(self):
        import _io
        for methodname in ["readinto", "readinto1"]:
            a = bytearray(b'x' * 10)
            raw = _io.FileIO(self.tmpfile)
            f = _io.BufferedReader(raw)
            readinto = getattr(f, methodname)
            assert readinto(a) == 5
            f.seek(0)
            m = memoryview(bytearray(b"hello"))
            assert readinto(m) == 5
            #
            exc = raises(TypeError, readinto, u"hello")
            msg = str(exc.value)
            # print(msg)
            assert " read-write b" in msg and msg.endswith(", not str")
            #
            exc = raises(TypeError, readinto, memoryview(b"hello"))
            msg = str(exc.value)
            # print(msg)
            assert " read-write b" in msg and msg.endswith(", not memoryview")
            #
            f.close()
            assert a == b'a\nb\ncxxxxx'

    def test_readinto_buffer_overflow(self):
        import _io
        class BadReader(_io._BufferedIOBase):
            def read(self, n=-1):
                return b'x' * 10**6
        bufio = BadReader()
        b = bytearray(2)
        raises(ValueError, bufio.readinto, b)

    def test_readinto1(self):
        import _io

        class MockIO(_io._IOBase):
            def readable(self):
                return True

            def readinto(self, buf):
                buf[:3] = b"abc"
                return 3

            def writable(self):
                return True

            def write(self, b):
                return len(b)

            def seekable(self):
                return True

            def seek(self, pos, whence):
                return 0

        bufio = _io.BufferedReader(MockIO(), buffer_size=5)
        buf = bytearray(10)
        bufio.read(2)
        n = bufio.readinto1(buf)
        assert n == 4
        assert buf[:n] == b'cabc'

        # Yes, CPython's observable behavior depends on buffer_size!
        bufio = _io.BufferedReader(MockIO(), buffer_size=20)
        buf = bytearray(10)
        bufio.read(2)
        n = bufio.readinto1(buf)
        assert n == 1
        assert buf[:n] == b'c'

        bufio = _io.BufferedReader(MockIO(), buffer_size=20)
        buf = bytearray(2)
        bufio.peek(3)
        assert bufio.readinto1(buf) == 2
        assert buf == b'ab'
        n = bufio.readinto1(buf)
        assert n == 1
        assert buf[:n] == b'c'

        bufio = _io.BufferedRandom(MockIO(), buffer_size=10)
        buf = bytearray(20)
        bufio.peek(3)
        assert bufio.readinto1(buf) == 6
        assert buf[:6] == b'abcabc'

        bufio = _io.BufferedWriter(MockIO(), buffer_size=10)
        raises(_io.UnsupportedOperation, bufio.readinto1, bytearray(10))

    def test_seek(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        f = _io.BufferedReader(raw)
        assert f.read() == b"a\nb\nc"
        f.seek(0)
        assert f.read() == b"a\nb\nc"
        f.seek(-2, 2)
        assert f.read() == b"\nc"
        f.close()

    def test_readlines(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        f = _io.BufferedReader(raw)
        assert f.readlines() == [b'a\n', b'b\n', b'c']

    def test_detach(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        f = _io.BufferedReader(raw)
        assert f.fileno() == raw.fileno()
        assert f.detach() is raw
        raises(ValueError, f.fileno)
        raises(ValueError, f.close)
        raises(ValueError, f.detach)
        raises(ValueError, f.flush)
        assert not raw.closed
        raw.close()

    def test_detached(self):
        import _io
        class MockRawIO(_io._RawIOBase):
            def readable(self):
                return True
        raw = MockRawIO()
        buf = _io.BufferedReader(raw)
        assert buf.detach() is raw
        raises(ValueError, buf.detach)

        raises(ValueError, getattr, buf, 'mode')
        raises(ValueError, buf.isatty)
        repr(buf)  # Should still work

    def test_tell(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        f = _io.BufferedReader(raw, buffer_size=2)
        assert f.tell() == 0
        d1 = f.read(1)
        assert f.tell() == 1
        d2 = f.read(2)
        assert f.tell() == 3
        assert f.seek(0) == 0
        assert f.tell() == 0
        d3 = f.read(3)
        assert f.tell() == 3
        assert d1 + d2 == d3
        f.close()

    def test_repr(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        f = _io.BufferedReader(raw)
        assert repr(f) == '<_io.BufferedReader name=%r>' % (self.tmpfile,)

    def test_read_interrupted(self):
        import _io, errno
        class MockRawIO(_io._RawIOBase):
            def __init__(self):
                self.count = 0
            def readable(self):
                return True
            def readinto(self, buf):
                self.count += 1
                if self.count < 3:
                    raise IOError(errno.EINTR, "interrupted")
                else:
                    buf[:3] = b"abc"
                    return 3
        rawio = MockRawIO()
        bufio = _io.BufferedReader(rawio)
        r = bufio.read(4)
        assert r == b"abca"
        assert rawio.count == 4

    def test_unseekable(self):
        import _io
        class Unseekable(_io.BytesIO):
            def seekable(self):
                return False
            def seek(self, *args):
                raise _io.UnsupportedOperation("not seekable")
            def tell(self, *args):
                raise _io.UnsupportedOperation("not seekable")
        bufio = _io.BufferedReader(Unseekable(b"A" * 10))
        raises(_io.UnsupportedOperation, bufio.tell)
        raises(_io.UnsupportedOperation, bufio.seek, 0)
        bufio.read(1)
        raises(_io.UnsupportedOperation, bufio.seek, 0)
        raises(_io.UnsupportedOperation, bufio.tell)

    def test_bufio_write_through(self):
        import _io as io
        # Issue #21396: write_through=True doesn't force a flush()
        # on the underlying binary buffered object.
        flush_called, write_called = [], []
        class BufferedWriter(io.BufferedWriter):
            def flush(self, *args, **kwargs):
                flush_called.append(True)
                return super().flush(*args, **kwargs)
            def write(self, *args, **kwargs):
                write_called.append(True)
                return super().write(*args, **kwargs)

        rawio = io.BytesIO()
        data = b"a"
        bufio = BufferedWriter(rawio, len(data)*2)
        textio = io.TextIOWrapper(bufio, encoding='ascii',
                                  write_through=True)
        # write to the buffered io but don't overflow the buffer
        text = data.decode('ascii')
        textio.write(text)

        # buffer.flush is not called with write_through=True
        assert not flush_called
        # buffer.write *is* called with write_through=True
        assert write_called
        assert rawio.getvalue() == b"" # no flush

        write_called = [] # reset
        textio.write(text * 10) # total content is larger than bufio buffer
        assert write_called
        assert rawio.getvalue() == data * 11 # all flushed

    def test_readline_issue3042(self):
        import _io as io
        try:
            import fcntl
        except ImportError:
            skip('fcntl missing')
        fdin, fdout = self.posix.pipe()
        f = io.open(fdin, "rb")
        fl = fcntl.fcntl(f, fcntl.F_GETFL)
        fcntl.fcntl(f, fcntl.F_SETFL, fl | self.posix.O_NONBLOCK)
        s = f.readline()
        assert s == b''
        f.close()
        self.posix.close(fdout)

    def test_read_nonblocking_crash(self):
        import _io as io
        try:
            import fcntl
        except ImportError:
            skip('fcntl missing')
        fdin, fdout = self.posix.pipe()
        f = io.open(fdin, "rb")
        fl = fcntl.fcntl(f, fcntl.F_GETFL)
        fcntl.fcntl(f, fcntl.F_SETFL, fl | self.posix.O_NONBLOCK)
        s = f.read(12)
        assert s == None
        self.posix.close(fdout)

        s = f.read(12)
        assert s == b''
        f.close()


class AppTestBufferedReaderWithThreads(AppTestBufferedReader):
    spaceconfig = dict(usemodules=['_io', 'thread', 'time'])
    if os.name != 'nt':
        spaceconfig['usemodules'].append('fcntl')
        

    def test_readinto_small_parts(self):
        import _io, os, _thread, time
        read_fd, write_fd = os.pipe()
        raw = _io.FileIO(read_fd)
        f = _io.BufferedReader(raw)
        a = bytearray(b'x' * 10)
        os.write(write_fd, b"abcde")
        def write_more():
            time.sleep(0.5)
            os.write(write_fd, b"fghij")
        _thread.start_new_thread(write_more, ())
        assert f.readinto(a) == 10
        assert a == b'abcdefghij'

@py.test.yield_fixture
def forbid_nonmoving_raw_ptr_for_resizable_list(space):
    orig_nonmoving_raw_ptr_for_resizable_list = rlib.buffer.nonmoving_raw_ptr_for_resizable_list
    def fail(l):
        raise oefmt(space.w_ValueError, "rgc.nonmoving_raw_ptr_for_resizable_list() not supported under RevDB")
    rlib.buffer.nonmoving_raw_ptr_for_resizable_list = fail
    yield
    rlib.buffer.nonmoving_raw_ptr_for_resizable_list = orig_nonmoving_raw_ptr_for_resizable_list

@py.test.mark.usefixtures('forbid_nonmoving_raw_ptr_for_resizable_list')
class AppTestForbidRawPtrForResizableList(object):
    spaceconfig = dict(usemodules=['_io'])

    @py.test.mark.skipif("py.test.config.option.runappdirect")
    def test_monkeypatch_works(self):
        import _io, os
        raw = _io.FileIO(os.devnull)
        f = _io.BufferedReader(raw)
        with raises(ValueError) as e:
            f.read(1024)
        assert e.value.args[0] == "rgc.nonmoving_raw_ptr_for_resizable_list() not supported under RevDB"

@py.test.mark.usefixtures('forbid_nonmoving_raw_ptr_for_resizable_list')
class AppTestBufferedReaderOnRevDB(AppTestBufferedReader):
    spaceconfig = {'usemodules': ['_io'], 'translation.reverse_debugger': True}


class AppTestBufferedWriter:
    spaceconfig = dict(usemodules=['_io', 'thread'])

    def setup_class(cls):
        tmpfile = udir.join('tmpfile')
        cls.w_tmpfile = cls.space.wrap(str(tmpfile))

    def w_readfile(self):
        with open(self.tmpfile, 'rb') as f:
            return f.read()

    def test_write(self):
        import _io
        raw = _io.FileIO(self.tmpfile, 'w+')
        f = _io.BufferedWriter(raw)
        f.write(b"abcd")
        raises(TypeError, f.write, u"cd")
        assert f.writable() is True
        assert f.readable() is False
        f.close()
        assert self.readfile() == b"abcd"

    def test_largewrite(self):
        import _io
        raw = _io.FileIO(self.tmpfile, 'w')
        f = _io.BufferedWriter(raw)
        f.write(b"abcd" * 5000)
        f.close()
        assert self.readfile() == b"abcd" * 5000

    def test_incomplete(self):
        import _io
        raw = _io.FileIO(self.tmpfile)
        b = _io.BufferedWriter.__new__(_io.BufferedWriter)
        raises(IOError, b.__init__, raw) # because file is not writable
        raises(ValueError, getattr, b, 'closed')
        raises(ValueError, b.flush)
        raises(ValueError, b.close)

    def test_check_several_writes(self):
        import _io
        raw = _io.FileIO(self.tmpfile, 'w')
        b = _io.BufferedWriter(raw, 13)

        for i in range(4):
            assert b.write(b'x' * 10) == 10
        b.flush()
        assert self.readfile() == b'x' * 40

    def test_destructor_1(self):
        import _io

        record = []
        class MyIO(_io.BufferedWriter):
            def __del__(self):
                record.append(1)
                # doesn't call the inherited __del__, so file not closed
            def close(self):
                record.append(2)
                super(MyIO, self).close()
            def flush(self):
                record.append(3)
                super(MyIO, self).flush()
        raw = _io.FileIO(self.tmpfile, 'w')
        MyIO(raw)
        import gc; gc.collect()
        assert record == [1]

    def test_destructor_2(self):
        import _io

        record = []
        class MyIO(_io.BufferedWriter):
            def __del__(self):
                record.append(1)
                super(MyIO, self).__del__()
            def close(self):
                record.append(2)
                super(MyIO, self).close()
            def flush(self):
                record.append(3)
                super(MyIO, self).flush()
        raw = _io.FileIO(self.tmpfile, 'w')
        MyIO(raw)
        import gc; gc.collect()
        assert record == [1, 2, 3]

    def test_truncate(self):
        import _io
        raw = _io.FileIO(self.tmpfile, 'w+')
        raw.write(b'x' * 20)
        b = _io.BufferedReader(raw)
        assert b.seek(8) == 8
        assert b.truncate() == 8
        assert b.tell() == 8

    def test_truncate_after_write(self):
        import _io
        raw = _io.FileIO(self.tmpfile, 'rb+')
        raw.write(b'\x00' * 50)
        raw.seek(0)
        b = _io.BufferedRandom(raw, 10)
        b.write(b'\x00' * 11)
        b.read(1)
        b.truncate()
        assert b.tell() == 12

    def test_write_non_blocking(self):
        import _io, io
        class MockNonBlockWriterIO(io.RawIOBase):
            def __init__(self):
                self._write_stack = []
                self._blocker_char = None

            def writable(self):
                return True
            closed = False

            def pop_written(self):
                s = b''.join(self._write_stack)
                self._write_stack[:] = []
                return s

            def block_on(self, char):
                """Block when a given char is encountered."""
                self._blocker_char = char

            def write(self, b):
                try:
                    b = b.tobytes()
                except AttributeError:
                    pass
                n = -1
                if self._blocker_char:
                    try:
                        n = b.index(self._blocker_char)
                    except ValueError:
                        pass
                    else:
                        if n > 0:
                            # write data up to the first blocker
                            self._write_stack.append(b[:n])
                            return n
                        else:
                            # cancel blocker and indicate would block
                            self._blocker_char = None
                            return None
                self._write_stack.append(b)
                return len(b)

        raw = MockNonBlockWriterIO()
        bufio = _io.BufferedWriter(raw, 8)

        assert bufio.write(b"abcd") == 4
        assert bufio.write(b"efghi") == 5
        # 1 byte will be written, the rest will be buffered
        raw.block_on(b"k")
        assert bufio.write(b"jklmn") == 5

        # 8 bytes will be written, 8 will be buffered and the rest will be lost
        raw.block_on(b"0")
        try:
            bufio.write(b"opqrwxyz0123456789")
        except _io.BlockingIOError as e:
            written = e.characters_written
        else:
            self.fail("BlockingIOError should have been raised")
        assert written == 16
        assert raw.pop_written() == b"abcdefghijklmnopqrwxyz"

        assert bufio.write(b"ABCDEFGHI") == 9
        s = raw.pop_written()
        # Previously buffered bytes were flushed
        assert s.startswith(b"01234567A")

    def test_nonblock_pipe_write_bigbuf(self):
        self.test_nonblock_pipe_write(16*1024)

    def test_nonblock_pipe_write_smallbuf(self):
        self.test_nonblock_pipe_write(1024)

    def w_test_nonblock_pipe_write(self, bufsize):
        import _io as io
        class NonBlockingPipe(io._BufferedIOBase):
            "write() returns None when buffer is full"
            def __init__(self, buffersize=4096):
                self.buffersize = buffersize
                self.buffer = b''
            def readable(self): return True
            def writable(self): return True

            def write(self, data):
                available = self.buffersize - len(self.buffer)
                if available <= 0:
                    return None
                add_data = data[:available]
                if isinstance(add_data, memoryview):
                    add_data = add_data.tobytes()
                self.buffer += add_data
                return len(add_data)
            def read(self, size=-1):
                if not self.buffer:
                    return None
                if size == -1:
                    size = len(self.buffer)
                data = self.buffer[:size]
                self.buffer = self.buffer[size:]
                return data

        sent = []
        received = []
        pipe = NonBlockingPipe()
        rf = io.BufferedReader(pipe, bufsize)
        wf = io.BufferedWriter(pipe, bufsize)

        for N in 9999, 7574:
            try:
                i = 0
                while True:
                    msg = bytes([i % 26 + 97] * N)
                    sent.append(msg)
                    wf.write(msg)
                    i += 1
            except io.BlockingIOError as e:
                sent[-1] = sent[-1][:e.characters_written]
                received.append(rf.read())
                msg = b'BLOCKED'
                wf.write(msg)
                sent.append(msg)
        while True:
            try:
                wf.flush()
                break
            except io.BlockingIOError as e:
                received.append(rf.read())
        received += iter(rf.read, None)
        rf.close()
        wf.close()
        sent, received = b''.join(sent), b''.join(received)
        assert sent == received

    def test_read_non_blocking(self):
        import _io
        class MockRawIO(_io._RawIOBase):
            def __init__(self, read_stack=()):
                self._read_stack = list(read_stack)
            def readable(self):
                return True
            def readinto(self, buf):
                max_len = len(buf)
                try:
                    data = self._read_stack[0]
                except IndexError:
                    self._extraneous_reads += 1
                    return 0
                if data is None:
                    del self._read_stack[0]
                    return None
                n = len(data)
                if len(data) <= max_len:
                    del self._read_stack[0]
                    buf[:n] = data
                    return n
                else:
                    buf[:] = data[:max_len]
                    self._read_stack[0] = data[max_len:]
                    return max_len
            def read(self, n=None):
                try:
                    return self._read_stack.pop(0)
                except IndexError:
                    return b""
        # Inject some None's in there to simulate EWOULDBLOCK
        rawio = MockRawIO((b"abc", b"d", None, b"efg", None, None, None))
        bufio = _io.BufferedReader(rawio)

        assert bufio.read(6) == b"abcd"
        assert bufio.read(1) == b"e"
        assert bufio.read() == b"fg"
        assert bufio.peek(1) == b""
        assert bufio.read() is None
        assert bufio.read() == b""

    def test_write_interrupted(self):
        import _io, errno
        class MockRawIO(_io._RawIOBase):
            def __init__(self):
                self.count = 0
            def writable(self):
                return True
            def write(self, data):
                self.count += 1
                if self.count < 3:
                    raise IOError(errno.EINTR, "interrupted")
                else:
                    return len(data)
        rawio = MockRawIO()
        bufio = _io.BufferedWriter(rawio)
        assert bufio.write(b"test") == 4
        bufio.flush()
        assert rawio.count == 3

    def test_reentrant_write(self):
        import _thread  # Reentrant-safe is only enabled with threads
        import _io, errno
        class MockRawIO(_io._RawIOBase):
            def writable(self):
                return True
            def write(self, data):
                bufio.write(b"something else")
                return len(data)

        rawio = MockRawIO()
        bufio = _io.BufferedWriter(rawio)
        bufio.write(b"test")
        exc = raises(RuntimeError, bufio.flush)
        assert "reentrant" in str(exc.value)  # And not e.g. recursion limit.

    def test_write_error_on_close(self):
        import _io
        class MockRawIO(_io._RawIOBase):
            def writable(self):
                return True
            def write(self, data):
                raise IOError()
        raw = MockRawIO()
        b = _io.BufferedWriter(raw)
        b.write(b'spam')
        raises(IOError, b.close)  # exception not swallowed
        assert b.closed

    def test_close_error_on_close(self):
        import _io
        class MockRawIO(_io._RawIOBase):
            def writable(self):
                return True
            def close(self):
                raise IOError('close')
        def bad_flush():
            raise IOError('flush')
        raw = MockRawIO()
        b = _io.BufferedWriter(raw)
        b.flush = bad_flush
        err = raises(IOError, b.close)  # exception not swallowed
        assert err.value.args == ('close',)
        assert err.value.__context__.args == ('flush',)
        assert not b.closed

    def test_truncate_after_close(self):
        import _io
        raw = _io.FileIO(self.tmpfile, 'w+')
        b = _io.BufferedWriter(raw)
        b.close()
        with raises(ValueError) as exc:
            b.truncate()
        assert exc.value.args[0] == "truncate of closed file"

class AppTestBufferedRWPair:
    def test_pair(self):
        import _io
        pair = _io.BufferedRWPair(_io.BytesIO(b"abc"), _io.BytesIO())
        assert not pair.closed
        assert pair.readable()
        assert pair.writable()
        assert not pair.isatty()
        assert pair.read() == b"abc"
        assert pair.write(b"abc") == 3

    def test_constructor_with_not_readable(self):
        import _io
        class NotReadable:
            def readable(self):
                return False

        raises(IOError, _io.BufferedRWPair, NotReadable(), _io.BytesIO())

    def test_constructor_with_not_writable(self):
        import _io
        class NotWritable:
            def writable(self):
                return False

        raises(IOError, _io.BufferedRWPair, _io.BytesIO(), NotWritable())

    def test_writer_close_error_on_close(self):
        import _io
        class MockRawIO(_io._IOBase):
            def readable(self):
                return True
            def writable(self):
                return True
        def writer_close():
            writer_non_existing
        reader = MockRawIO()
        writer = MockRawIO()
        writer.close = writer_close
        pair = _io.BufferedRWPair(reader, writer)
        err = raises(NameError, pair.close)
        assert 'writer_non_existing' in str(err.value)
        assert not pair.closed
        assert reader.closed
        assert not writer.closed

    def test_reader_writer_close_error_on_close(self):
        import _io
        class MockRawIO(_io._IOBase):
            def readable(self):
                return True
            def writable(self):
                return True
        def reader_close():
            reader_non_existing
        def writer_close():
            writer_non_existing
        reader = MockRawIO()
        reader.close = reader_close
        writer = MockRawIO()
        writer.close = writer_close
        pair = _io.BufferedRWPair(reader, writer)
        err = raises(NameError, pair.close)
        assert 'reader_non_existing' in str(err.value)
        assert 'writer_non_existing' in str(err.value.__context__)
        assert not pair.closed
        assert not reader.closed
        assert not writer.closed

class AppTestBufferedRandom:
    spaceconfig = dict(usemodules=['_io'])

    def setup_class(cls):
        tmpfile = udir.join('tmpfile')
        tmpfile.write(b"a\nb\nc", mode='wb')
        cls.w_tmpfile = cls.space.wrap(str(tmpfile))

    def test_simple_read(self):
        import _io
        raw = _io.FileIO(self.tmpfile, 'rb+')
        f = _io.BufferedRandom(raw)
        assert f.read(3) == b'a\nb'
        f.write(b'xxxx')
        f.seek(0)
        assert f.read() == b'a\nbxxxx'

    def test_simple_read_after_write(self):
        import _io
        raw = _io.FileIO(self.tmpfile, 'wb+')
        f = _io.BufferedRandom(raw)
        f.write(b'abc')
        f.seek(0)
        assert f.read() == b'abc'

    def test_write_rewind_write(self):
        # Various combinations of reading / writing / seeking
        # backwards / writing again
        import _io, errno
        def mutate(bufio, pos1, pos2):
            assert pos2 >= pos1
            # Fill the buffer
            bufio.seek(pos1)
            bufio.read(pos2 - pos1)
            bufio.write(b'\x02')
            # This writes earlier than the previous write, but still inside
            # the buffer.
            bufio.seek(pos1)
            bufio.write(b'\x01')

        b = b"\x80\x81\x82\x83\x84"
        for i in range(0, len(b)):
            for j in range(i, len(b)):
                raw = _io.BytesIO(b)
                bufio = _io.BufferedRandom(raw, 100)
                mutate(bufio, i, j)
                bufio.flush()
                expected = bytearray(b)
                expected[j] = 2
                expected[i] = 1
                assert raw.getvalue() == expected

    def test_interleaved_read_write(self):
        import _io as io
        # Test for issue #12213
        with io.BytesIO(b'abcdefgh') as raw:
            with io.BufferedRandom(raw, 100) as f:
                f.write(b"1")
                assert f.read(1) == b'b'
                f.write(b'2')
                assert f.read1(1) == b'd'
                f.write(b'3')
                buf = bytearray(1)
                f.readinto(buf)
                assert buf ==  b'f'
                f.write(b'4')
                assert f.peek(1) == b'h'
                f.flush()
                assert raw.getvalue() == b'1b2d3f4h'

        with io.BytesIO(b'abc') as raw:
            with io.BufferedRandom(raw, 100) as f:
                assert f.read(1) == b'a'
                f.write(b"2")
                assert f.read(1) == b'c'
                f.flush()
                assert raw.getvalue() == b'a2c'

    def test_interleaved_readline_write(self):
        import _io as io
        with io.BytesIO(b'ab\ncdef\ng\n') as raw:
            with io.BufferedRandom(raw) as f:
                f.write(b'1')
                assert f.readline() == b'b\n'
                f.write(b'2')
                assert f.readline() == b'def\n'
                f.write(b'3')
                assert f.readline() == b'\n'
                f.flush()
                assert raw.getvalue() == b'1b\n2def\n3\n'

    def test_readline(self):
        import _io as io
        with io.BytesIO(b"abc\ndef\nxyzzy\nfoo\x00bar\nanother line") as raw:
            with io.BufferedRandom(raw, buffer_size=10) as f:
                assert f.readline() == b"abc\n"
                assert f.readline(10) == b"def\n"
                assert f.readline(2) == b"xy"
                assert f.readline(4) == b"zzy\n"
                assert f.readline() == b"foo\x00bar\n"
                assert f.readline(None) == b"another line"
                raises(TypeError, f.readline, 5.3)


class AppTestMaxBuffer:

    def w_check_max_buffer_size_removal(self, test):
        import _io
        raises(TypeError, test, _io.BytesIO(), 8, 12)

    def test_max_buffer_size_removal(self):
        import _io
        self.check_max_buffer_size_removal(_io.BufferedWriter)
        self.check_max_buffer_size_removal(_io.BufferedRandom)
        self.check_max_buffer_size_removal (
            lambda raw, *args: _io.BufferedRWPair(raw, raw, *args))


class TestNonReentrantLock:
    spaceconfig = dict(usemodules=['thread'])

    def test_trylock(self, space):
        lock = interp_bufferedio.TryLock(space)
        with lock:
            pass
        with lock:
            exc = py.test.raises(OperationError, "with lock: pass")
        assert exc.value.match(space, space.w_RuntimeError)

    def test_fast_closed_check(self, space):
        from pypy.module._io.interp_fileio import W_FileIO
        from pypy.module._io.interp_bufferedio import W_BufferedRandom
        tmpfile = udir.join('tmpfile')
        tmpfile.write("a\nb\nc", mode='wb')
        w_fn = space.appexec([space.newtext(str(tmpfile))], """(fn):
            return open(fn, "rb")""")
        assert w_fn._fast_closed_check == True

