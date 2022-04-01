import _io

def test_init():
    raises(TypeError, _io.BytesIO, "12345")
    buf = b"1234567890"
    b = _io.BytesIO(buf)
    assert b.getvalue() == buf
    b = _io.BytesIO(None)
    assert b.getvalue() == b""
    b.__init__(buf * 2)
    assert b.getvalue() == buf * 2
    b.__init__(buf)
    assert b.getvalue() == buf

def test_init_kwargs():
    buf = b"1234567890"
    b = _io.BytesIO(initial_bytes=buf)
    assert b.read() == buf
    raises(TypeError, _io.BytesIO, buf, foo=None)

def test_new():
    f = _io.BytesIO.__new__(_io.BytesIO)
    assert not f.closed

def test_capabilities():
    f = _io.BytesIO()
    assert f.readable()
    assert f.writable()
    assert f.seekable()
    f.close()
    raises(ValueError, f.readable)
    raises(ValueError, f.writable)
    raises(ValueError, f.seekable)

def test_write():
    f = _io.BytesIO()
    assert f.write(b"") == 0
    assert f.write(b"hello") == 5
    exc = raises(TypeError, f.write, u"lo")
    assert str(exc.value) == "'str' does not support the buffer interface"
    import gc; gc.collect()
    assert f.getvalue() == b"hello"
    f.close()

def test_read():
    f = _io.BytesIO(b"hello")
    assert f.read() == b"hello"
    import gc; gc.collect()
    assert f.read(8192) == b""
    f.close()

def test_seek():
    f = _io.BytesIO(b"hello")
    assert f.tell() == 0
    assert f.seek(-1, 2) == 4
    assert f.tell() == 4
    assert f.seek(0) == 0

def test_truncate():
    f = _io.BytesIO()
    f.write(b"hello")
    assert f.truncate(0) == 0
    assert f.tell() == 5
    f.seek(0)
    f.write(b"hello")
    f.seek(3)
    assert f.truncate() == 3
    assert f.getvalue() == b"hel"
    assert f.truncate(2) == 2
    assert f.tell() == 3

def test_setstate():
    # state is (content, position, __dict__)
    f = _io.BytesIO(b"hello")
    content, pos, __dict__ = f.__getstate__()
    assert (content, pos) == (b"hello", 0)
    assert __dict__ is None or __dict__ == {}
    f.__setstate__((b"world", 3, {"a": 1}))
    assert f.getvalue() == b"world"
    assert f.read() == b"ld"
    assert f.a == 1
    assert f.__getstate__() == (b"world", 5, {"a": 1})
    raises(TypeError, f.__setstate__, (b"", 0))
    f.close()
    raises(ValueError, f.__getstate__)
    raises(ValueError, f.__setstate__, ("world", 3, {"a": 1}))

def test_readinto():
    for methodname in ["readinto", "readinto1"]:
        b = _io.BytesIO(b"hello")
        readinto = getattr(b, methodname)
        a1 = bytearray(b't')
        a2 = bytearray(b'testing')
        assert readinto(a1) == 1
        assert readinto(a2) == 4
        b.seek(0)
        m = memoryview(bytearray(b"world"))
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
        b.close()
        assert a1 == b"h"
        assert a2 == b"elloing"
        raises(ValueError, readinto, bytearray(b"hello"))

def test_getbuffer():
    memio = _io.BytesIO(b"1234567890")
    buf = memio.getbuffer()
    assert bytes(buf) == b"1234567890"
    memio.seek(5)
    buf = memio.getbuffer()
    assert bytes(buf) == b"1234567890"
    assert buf[5] == ord(b"6")
    # Mutating the buffer updates the BytesIO
    buf[3:6] = b"abc"
    assert bytes(buf) == b"123abc7890"
    assert memio.getvalue() == b"123abc7890"
    # After the buffer gets released, we can resize the BytesIO again
    del buf
    memio.truncate()
    memio.close()
    raises(ValueError, memio.getbuffer)

def test_read1():
    memio = _io.BytesIO(b"1234567890")
    assert memio.read1() == b"1234567890"

def test_readline():
    f = _io.BytesIO(b'abc\ndef\nxyzzy\nfoo\x00bar\nanother line')
    assert f.readline() == b'abc\n'
    assert f.readline(10) == b'def\n'
    assert f.readline(2) == b'xy'
    assert f.readline(4) == b'zzy\n'
    assert f.readline() == b'foo\x00bar\n'
    assert f.readline(None) == b'another line'
    raises(TypeError, f.readline, 5.3)

def test_overread():
    f = _io.BytesIO(b'abc')
    assert f.readline(10) == b'abc'
