from pytest import raises
from _io import StringIO

def test_stringio():
    sio = StringIO()
    sio.write(u'Hello ')
    sio.write(u'world')
    assert sio.getvalue() == u'Hello world'

    assert StringIO(u"hello").read() == u'hello'

def test_capabilities():
    sio = StringIO()
    assert sio.readable()
    assert sio.writable()
    assert sio.seekable()
    assert not sio.isatty()
    assert not sio.closed
    assert not sio.line_buffering
    sio.close()
    raises(ValueError, sio.readable)
    raises(ValueError, sio.writable)
    raises(ValueError, sio.seekable)
    raises(ValueError, sio.isatty)
    assert sio.closed
    assert sio.errors is None

def test_closed():
    sio = StringIO()
    sio.close()
    raises(ValueError, sio.read, 1)
    raises(ValueError, sio.write, u"text")

def test_read():
    buf = u"1234567890"
    sio = StringIO(buf)

    assert sio.read(0) == ''
    assert buf[:1] == sio.read(1)
    assert buf[1:5] == sio.read(4)
    assert buf[5:] == sio.read(900)
    assert u"" == sio.read()

def test_read_binary():
    # data is from a test_imghdr test for a GIF file
    buf_in = (u'\x47\x49\x46\x38\x39\x61\x10\x00\x10\x00\xf6\x64\x00\xeb'
              u'\xbb\x18\xeb\xbe\x21\xf3\xc1\x1a\xfa\xc7\x19\xfd\xcb\x1b'
              u'\xff\xcc\x1c\xeb')
    assert len(buf_in) == 32
    sio = StringIO(buf_in)
    buf_out = sio.read(32)
    assert buf_in == buf_out

def test_readline():
    sio = StringIO(u'123\n456')
    assert sio.readline(0) == ''
    assert sio.readline(2) == '12'
    assert sio.readline(None) == '3\n'
    assert sio.readline() == '456'

def test_seek():

    s = u"1234567890"
    sio = StringIO(s)

    sio.read(5)
    sio.seek(0)
    r = sio.read()
    assert r == s

    sio.seek(3)
    r = sio.read()
    assert r == s[3:]
    raises(TypeError, sio.seek, 0.0)

    exc_info = raises(ValueError, sio.seek, -3)
    assert exc_info.value.args[0] == "Negative seek position -3"

    raises(ValueError, sio.seek, 3, -1)
    raises(ValueError, sio.seek, 3, -3)

    sio.close()
    raises(ValueError, sio.seek, 0)

def test_overseek():

    s = u"1234567890"
    sio = StringIO(s)

    res = sio.seek(11)
    assert res == 11
    res = sio.read()
    assert res == u""
    assert sio.tell() == 11
    assert sio.getvalue() == s
    sio.write(u"")
    assert sio.getvalue() == s
    sio.write(s)
    assert sio.getvalue() == s + u"\0" + s

def test_tell():

    s = u"1234567890"
    sio = StringIO(s)

    assert sio.tell() == 0
    sio.seek(5)
    assert sio.tell() == 5
    sio.seek(10000)
    assert sio.tell() == 10000

    sio.close()
    raises(ValueError, sio.tell)

def test_truncate():

    s = u"1234567890"
    sio = StringIO(s)

    raises(ValueError, sio.truncate, -1)
    sio.seek(6)
    res = sio.truncate()
    assert res == 6
    assert sio.getvalue() == s[:6]
    res = sio.truncate(4)
    assert res == 4
    assert sio.getvalue() == s[:4]
    assert sio.tell() == 6
    sio.seek(0, 2)
    sio.write(s)
    assert sio.getvalue() == s[:4] + s
    pos = sio.tell()
    res = sio.truncate(None)
    assert res == pos
    assert sio.tell() == pos
    raises(TypeError, sio.truncate, '0')
    sio.close()
    raises(ValueError, sio.truncate, 0)

def test_write_error():

    exc_info = raises(TypeError, StringIO, 3)
    assert "int" in exc_info.value.args[0]

    sio = StringIO(u"")
    exc_info = raises(TypeError, sio.write, 3)
    assert "int" in exc_info.value.args[0]

def test_newline_none():

    sio = StringIO(u"a\nb\r\nc\rd", newline=None)
    res = list(sio)
    assert res == [u"a\n", u"b\n", u"c\n", u"d"]
    sio.seek(0)
    res = sio.read(1)
    assert res == u"a"
    res = sio.read(2)
    assert res == u"\nb"
    res = sio.read(2)
    assert res == u"\nc"
    res = sio.read(1)
    assert res == u"\n"

    sio = StringIO(newline=None)
    res = sio.write(u"a\n")
    assert res == 2
    res = sio.write(u"b\r\n")
    assert res == 3
    res = sio.write(u"c\rd")
    assert res == 3
    sio.seek(0)
    res = sio.read()
    assert res == u"a\nb\nc\nd"
    sio = StringIO(u"a\r\nb", newline=None)
    res = sio.read(3)
    assert res == u"a\nb"

def test_newline_empty():

    sio = StringIO(u"a\nb\r\nc\rd", newline="")
    res = list(sio)
    assert res == [u"a\n", u"b\r\n", u"c\r", u"d"]
    sio.seek(0)
    res = sio.read(4)
    assert res == u"a\nb\r"
    res = sio.read(2)
    assert res == u"\nc"
    res = sio.read(1)
    assert res == u"\r"

    sio = StringIO(newline="")
    res = sio.write(u"a\n")
    assert res == 2
    res = sio.write(u"b\r")
    assert res == 2
    res = sio.write(u"\nc")
    assert res == 2
    res = sio.write(u"\rd")
    assert res == 2
    sio.seek(0)
    res = list(sio)
    assert res == [u"a\n", u"b\r\n", u"c\r", u"d"]

def test_newline_lf():

    sio = StringIO(u"a\nb\r\nc\rd")
    res = list(sio)
    assert res == [u"a\n", u"b\r\n", u"c\rd"]

def test_newline_cr():

    sio = StringIO(u"a\nb\r\nc\rd", newline="\r")
    res = sio.read()
    assert res == u"a\rb\r\rc\rd"
    sio.seek(0)
    res = list(sio)
    assert res == [u"a\r", u"b\r", u"\r", u"c\r", u"d"]

def test_newline_crlf():

    sio = StringIO(u"a\nb\r\nc\rd", newline="\r\n")
    res = sio.read()
    assert res == u"a\r\nb\r\r\nc\rd"
    sio.seek(0)
    res = list(sio)
    assert res == [u"a\r\n", u"b\r\r\n", u"c\rd"]

def test_newline_property():

    sio = StringIO(newline=None)
    assert sio.newlines is None
    sio.write(u"a\n")
    assert sio.newlines == "\n"
    sio.write(u"b\r\n")
    assert sio.newlines == ("\n", "\r\n")
    sio.write(u"c\rd")
    assert sio.newlines == ("\r", "\n", "\r\n")
    exc = raises(TypeError, StringIO, newline=b'\n')
    assert 'bytes' in str(exc.value)

def test_iterator():

    s = u"1234567890\n"
    sio = StringIO(s * 10)

    assert iter(sio) is sio
    assert hasattr(sio, "__iter__")
    assert hasattr(sio, "__next__")

    i = 0
    for line in sio:
        assert line == s
        i += 1
    assert i == 10
    sio.seek(0)
    i = 0
    for line in sio:
        assert line == s
        i += 1
    assert i == 10
    sio.seek(len(s) * 10 +1)
    assert list(sio) == []
    sio = StringIO(s * 2)
    sio.close()
    raises(ValueError, next, sio)

def test_getstate():

    sio = StringIO()
    state = sio.__getstate__()
    assert len(state) == 4
    assert isinstance(state[0], str)
    assert isinstance(state[1], str)
    assert isinstance(state[2], int)
    assert state[3] is None or isinstance(state[3], dict)
    sio.close()
    raises(ValueError, sio.__getstate__)

def test_setstate():

    sio = StringIO()
    sio.__setstate__((u"no error", u"\n", 0, None))
    sio.__setstate__((u"no error", u"", 0, {"spam": 3}))
    raises(ValueError, sio.__setstate__, (u"", u"f", 0, None))
    raises(ValueError, sio.__setstate__, (u"", u"", -1, None))
    raises(TypeError, sio.__setstate__, (b"", u"", 0, None))
    raises(TypeError, sio.__setstate__, (u"", u"", 0.0, None))
    raises(TypeError, sio.__setstate__, (u"", u"", 0, 0))
    raises(TypeError, sio.__setstate__, (u"len-test", 0))
    raises(TypeError, sio.__setstate__)
    raises(TypeError, sio.__setstate__, 0)
    sio.close()
    raises(ValueError, sio.__setstate__, (u"closed", u"", 0, None))

def test_roundtrip_translation():
    sio1 = StringIO(u'a\nb', newline='\r\n')
    pos = sio1.seek(1)
    assert sio1.getvalue() == u'a\r\nb'
    state = sio1.__getstate__()
    sio2 = StringIO()
    sio2.__setstate__(state)
    assert sio2.getvalue() == u'a\r\nb'
    assert sio2.tell() == pos

def test_roundtrip_state():
    s = u'12345678'
    sio1 = StringIO(s)
    sio1.foo = 42
    sio1.seek(2)
    assert sio1.getvalue() == s
    state = sio1.__getstate__()
    sio2 = StringIO()
    sio2.__setstate__(state)
    assert sio2.getvalue() == s
    assert sio2.foo == 42
    assert sio2.tell() == 2

