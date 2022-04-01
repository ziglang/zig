# spaceconfig = {"usemodules" : ["_locale", "array", "struct"]}
import _io
import array

import pytest

@pytest.fixture
def tempfile(tmpdir):
    tempfile = (tmpdir / 'tempfile').ensure()
    return str(tempfile)

def test_iobase_overriding():
    class WithIter(_io._IOBase):
        def __iter__(self):
            yield 'foo'
    assert WithIter().readlines() == ['foo']
    assert WithIter().readlines(1) == ['foo']

    class WithNext(_io._IOBase):
        def __next__(self):
            raise StopIteration
    assert WithNext().readlines() == []
    assert WithNext().readlines(1) == []

def test_openclose():
    with _io._BufferedIOBase() as f:
        assert not f.closed
        f._checkClosed()
    assert f.closed
    with pytest.raises(ValueError):
        f._checkClosed()

def test_iter():
    class MyFile(_io._IOBase):
        def __init__(self):
            self.lineno = 0
        def readline(self):
            self.lineno += 1
            if self.lineno == 1:
                return "line1"
            elif self.lineno == 2:
                return "line2"
            return ""

    assert list(MyFile()) == ["line1", "line2"]

def test_exception():
    e = _io.UnsupportedOperation("seek")

def test_default_implementations():
    file = _io._IOBase()
    raises(_io.UnsupportedOperation, file.seek, 0, 1)
    raises(_io.UnsupportedOperation, file.fileno)
    raises(_io.UnsupportedOperation, file.truncate)

def test_blockingerror():
    try:
        raise _io.BlockingIOError(42, "test blocking", 123)
    except OSError as e:
        assert isinstance(e, _io.BlockingIOError)
        assert e.errno == 42
        assert e.strerror == "test blocking"
        assert e.characters_written == 123

def test_dict():
    f = _io.BytesIO()
    f.x = 42
    assert f.x == 42
    #
    def write(data):
        try:
            data = data.tobytes().upper()
        except AttributeError:
            data = data.upper()
        return _io.BytesIO.write(f, data)
    f.write = write
    bufio = _io.BufferedWriter(f)
    bufio.write(b"abc")
    bufio.flush()
    assert f.getvalue() == b"ABC"

def test_destructor_1():
    record = []
    class MyIO(_io._IOBase):
        def __del__(self):
            record.append(1)
            # doesn't call the inherited __del__, so file not closed
        def close(self):
            record.append(2)
            super(MyIO, self).close()
        def flush(self):
            record.append(3)
            super(MyIO, self).flush()
    MyIO()
    import gc; gc.collect()
    assert record == [1]

def test_destructor_2():
    record = []
    class MyIO(_io._IOBase):
        def __del__(self):
            record.append(1)
            super(MyIO, self).__del__()
        def close(self):
            record.append(2)
            super(MyIO, self).close()
        def flush(self):
            record.append(3)
            super(MyIO, self).flush()
    MyIO()
    import gc; gc.collect()
    assert record == [1, 2, 3]

def test_tell():
    class MyIO(_io._IOBase):
        def seek(self, pos, whence=0):
            return 42
    assert MyIO().tell() == 42

def test_weakref():
    import weakref
    f = _io.BytesIO()
    ref = weakref.ref(f)
    assert ref() is f

def test_rawio_read():
    class MockRawIO(_io._RawIOBase):
        stack = [b'abc', b'de', b'']
        def readinto(self, buf):
            data = self.stack.pop(0)
            buf[:len(data)] = data
            return len(data)
    assert MockRawIO().read() == b'abcde'

def test_rawio_read_pieces():
    class MockRawIO(_io._RawIOBase):
        stack = [b'abc', b'de', None, b'fg', b'']
        def readinto(self, buf):
            data = self.stack.pop(0)
            if data is None:
                return None
            if len(data) <= len(buf):
                buf[:len(data)] = data
                return len(data)
            else:
                buf[:] = data[:len(buf)]
                self.stack.insert(0, data[len(buf):])
                return len(buf)
    r = MockRawIO()
    assert r.read(2) == b'ab'
    assert r.read(2) == b'c'
    assert r.read(2) == b'de'
    assert r.read(2) is None
    assert r.read(2) == b'fg'
    assert r.read(2) == b''

def test_rawio_readall_none():
    class MockRawIO(_io._RawIOBase):
        read_stack = [None, None, b"a"]
        def readinto(self, buf):
            v = self.read_stack.pop()
            if v is None:
                return v
            buf[:len(v)] = v
            return len(v)

    r = MockRawIO()
    s = r.readall()
    assert s == b"a"
    s = r.readall()
    assert s is None

def test_open(tempfile):
    f = _io.open(tempfile, "rb")
    assert f.name.endswith('tempfile')
    assert f.mode == 'rb'
    f.close()

    with _io.open(tempfile, "rt") as f:
        assert f.mode == "rt"

def test_open_writable(tempfile):
    f = _io.open(tempfile, "w+b")
    f.close()

def test_valid_mode(tempfile):
    raises(ValueError, _io.open, tempfile, "ww")
    raises(ValueError, _io.open, tempfile, "rwa")
    raises(ValueError, _io.open, tempfile, "b", newline="\n")
    raises(ValueError, _io.open, tempfile, "U+")
    raises(ValueError, _io.open, tempfile, "xU")

def test_array_write(tempfile):
    a = array.array('i', range(10))
    n = len(a.tobytes())
    with _io.open(tempfile, "wb", 0) as f:
        res = f.write(a)
        assert res == n

    with _io.open(tempfile, "wb") as f:
        res = f.write(a)
        assert res == n

def test_attributes(tempfile):
    import warnings
    with _io.open(tempfile, "wb", buffering=0) as f:
        assert f.mode == "wb"

    with warnings.catch_warnings(record=True) as l:
        warnings.simplefilter("always")
        with _io.open(tempfile, "U") as f:
            assert f.name == tempfile
            assert f.buffer.name == tempfile
            assert f.buffer.raw.name == tempfile
            assert f.mode == "U"
            assert f.buffer.mode == "rb"
            assert f.buffer.raw.mode == "rb"
    assert isinstance(l[0].message, DeprecationWarning)

    with _io.open(tempfile, "w+") as f:
        assert f.mode == "w+"
        assert f.buffer.mode == "rb+"
        assert f.buffer.raw.mode == "rb+"

        with _io.open(f.fileno(), "wb", closefd=False) as g:
            assert g.mode == "wb"
            assert g.raw.mode == "wb"
            assert g.name == f.fileno()
            assert g.raw.name == f.fileno()

def test_buffer_warning(tempfile):
    import warnings

    with warnings.catch_warnings(record=True) as collector:
        warnings.simplefilter("always")
        with _io.open(tempfile, "wb", buffering=1) as f:
            pass

    assert len(collector) == 1
    assert isinstance(collector[0].message, RuntimeWarning)

def test_opener(tempfile):
    import os
    with _io.open(tempfile, "w") as f:
        f.write("egg\n")
    fd = os.open(tempfile, os.O_RDONLY)
    def opener(path, flags):
        return fd
    with _io.open("non-existent", "r", opener=opener) as f:
        assert f.read() == "egg\n"

def test_seek_and_tell(tempfile):
    with _io.open(tempfile, "wb") as f:
        f.write(b"abcd")

    with _io.open(tempfile) as f:
        decoded = f.read()

    # seek positions
    for i in range(len(decoded) + 1):
        # read lenghts
        for j in [1, 5, len(decoded) - i]:
            with _io.open(tempfile) as f:
                res = f.read(i)
                assert res == decoded[:i]
                cookie = f.tell()
                res = f.read(j)
                assert res == decoded[i:i + j]
                f.seek(cookie)
                res = f.read()
                assert res == decoded[i:]

def test_telling(tempfile):
    with _io.open(tempfile, "w+", encoding="utf8") as f:
        p0 = f.tell()
        f.write("\xff\n")
        p1 = f.tell()
        f.write("\xff\n")
        p2 = f.tell()
        f.seek(0)

        assert f.tell() == p0
        res = f.readline()
        assert res == "\xff\n"
        assert f.tell() == p1
        res = f.readline()
        assert res == "\xff\n"
        assert f.tell() == p2
        f.seek(0)

        for line in f:
            assert line == "\xff\n"
            raises(IOError, f.tell)
        assert f.tell() == p2

def test_chunk_size(tempfile):
    with _io.open(tempfile) as f:
        assert f._CHUNK_SIZE >= 1
        f._CHUNK_SIZE = 4096
        assert f._CHUNK_SIZE == 4096
        raises(ValueError, setattr, f, "_CHUNK_SIZE", 0)

def test_truncate(tempfile):
    with _io.open(tempfile, "w+") as f:
        f.write("abc")

    with _io.open(tempfile, "w+") as f:
        f.truncate()

    with _io.open(tempfile, "r+") as f:
        res = f.read()
        assert res == ""

def test_errors_property(tempfile):
    with _io.open(tempfile, "w") as f:
        assert f.errors == "strict"
    with _io.open(tempfile, "w", errors="replace") as f:
        assert f.errors == "replace"

def test_append_bom(tempfile):
    # The BOM is not written again when appending to a non-empty file
    for charset in ["utf-8-sig", "utf-16", "utf-32"]:
        with _io.open(tempfile, "w", encoding=charset) as f:
            f.write("aaa")
            pos = f.tell()
        with _io.open(tempfile, "rb") as f:
            res = f.read()
            assert res == "aaa".encode(charset)
        with _io.open(tempfile, "a", encoding=charset) as f:
            f.write("xxx")
        with _io.open(tempfile, "rb") as f:
            res = f.read()
            assert res == "aaaxxx".encode(charset)

def test_newlines_attr(tempfile):
    with _io.open(tempfile, "r") as f:
        assert f.newlines is None

    with _io.open(tempfile, "wb") as f:
        f.write(b"hello\nworld\n")

    with _io.open(tempfile, "r") as f:
        res = f.readline()
        assert res == "hello\n"
        res = f.readline()
        assert res == "world\n"
        assert f.newlines == "\n"
        assert type(f.newlines) is str

def _check_warn_on_dealloc(*args, **kwargs):
    import gc
    import warnings

    f = open(*args, **kwargs)
    r = repr(f)
    gc.collect()
    with warnings.catch_warnings(record=True) as w:
        warnings.simplefilter('always')
        f = None
        gc.collect()
    assert len(w) == 1, len(w)
    assert r in str(w[0])

def test_warn_on_dealloc(tempfile):
    _check_warn_on_dealloc(tempfile, 'wb', buffering=0)
    _check_warn_on_dealloc(tempfile, 'wb')
    _check_warn_on_dealloc(tempfile, 'w')

def test_pickling(tempfile):
    import pickle
    # Pickling file objects is forbidden
    for kwargs in [
            {"mode": "w"},
            {"mode": "wb"},
            {"mode": "wb", "buffering": 0},
            {"mode": "r"},
            {"mode": "rb"},
            {"mode": "rb", "buffering": 0},
            {"mode": "w+"},
            {"mode": "w+b"},
            {"mode": "w+b", "buffering": 0},
        ]:
        for protocol in range(pickle.HIGHEST_PROTOCOL + 1):
            with _io.open(tempfile, **kwargs) as f:
                raises(TypeError, pickle.dumps, f, protocol)

def test_mod():
    typemods = dict((t, t.__module__) for name, t in vars(_io).items()
                    if isinstance(t, type) and name != '__loader__')
    for t, mod in typemods.items():
        if t is _io.BlockingIOError:
            assert mod == 'builtins'
        elif t is _io.UnsupportedOperation:
            assert mod == 'io'
        else:
            assert mod == '_io'

def test_issue1902(tempfile):
    with _io.open(tempfile, 'w+b', 4096) as f:
        f.write(b'\xff' * 13569)
        f.flush()
        f.seek(0, 0)
        f.read(1)
        f.seek(-1, 1)
        f.write(b'')

def test_issue1902_2(tempfile):
    with _io.open(tempfile, 'w+b', 4096) as f:
        f.write(b'\xff' * 13569)
        f.flush()
        f.seek(0, 0)

        f.read(1)
        f.seek(-1, 1)
        f.write(b'\xff')
        f.seek(1, 0)
        f.read(4123)
        f.seek(-4123, 1)

def test_issue1902_3(tempfile):
    buffer_size = 4096
    with _io.open(tempfile, 'w+b', buffer_size) as f:
        f.write(b'\xff' * buffer_size * 3)
        f.flush()
        f.seek(0, 0)

        f.read(1)
        f.seek(-1, 1)
        f.write(b'\xff')
        f.seek(1, 0)
        f.read(buffer_size * 2)
        assert f.tell() == 1 + buffer_size * 2

def test_open_exclusive(tempfile):
    # XXX: should raise FileExistsError
    FileExistsError = OSError

    filename = tempfile + '_x2'
    raises(ValueError, _io.open, filename, 'xw')
    with _io.open(filename, 'x') as f:
        assert f.mode == 'x'
    raises(FileExistsError, _io.open, filename, 'x')

def test_nonbuffered_textio(tempfile):
    import warnings
    filename = tempfile + '_x2'
    warnings.simplefilter("always", category=ResourceWarning)
    with warnings.catch_warnings(record=True) as recorded:
        raises(ValueError, _io.open, filename, 'w', buffering=0)
    assert recorded == []

def test_invalid_newline(tempfile):
    import warnings
    filename = tempfile + '_x2'
    warnings.simplefilter("always", category=ResourceWarning)
    with warnings.catch_warnings(record=True) as recorded:
        raises(ValueError, _io.open, filename, 'w', newline='invalid')
    assert recorded == []


def test_io_after_close(tempfile):
    for kwargs in [
            {"mode": "w"},
            {"mode": "wb"},
            {"mode": "w", "buffering": 1},
            {"mode": "w", "buffering": 2},
            {"mode": "wb", "buffering": 0},
            {"mode": "r"},
            {"mode": "rb"},
            {"mode": "r", "buffering": 1},
            {"mode": "r", "buffering": 2},
            {"mode": "rb", "buffering": 0},
            {"mode": "w+"},
            {"mode": "w+b"},
            {"mode": "w+", "buffering": 1},
            {"mode": "w+", "buffering": 2},
            {"mode": "w+b", "buffering": 0},
        ]:
        if "b" not in kwargs["mode"]:
            kwargs["encoding"] = "ascii"
        f = _io.open(tempfile, **kwargs)
        f.close()
        raises(ValueError, f.flush)
        raises(ValueError, f.fileno)
        raises(ValueError, f.isatty)
        raises(ValueError, f.__iter__)
        if hasattr(f, "peek"):
            raises(ValueError, f.peek, 1)
        raises(ValueError, f.read)
        if hasattr(f, "read1"):
            raises(ValueError, f.read1, 1024)
        if hasattr(f, "readall"):
            raises(ValueError, f.readall)
        if hasattr(f, "readinto"):
            raises(ValueError, f.readinto, bytearray(1024))
        raises(ValueError, f.readline)
        raises(ValueError, f.readlines)
        raises(ValueError, f.seek, 0)
        raises(ValueError, f.tell)
        raises(ValueError, f.truncate)
        raises(ValueError, f.write, b"" if "b" in kwargs['mode'] else u"")
        raises(ValueError, f.writelines, [])
        raises(ValueError, next, f)
