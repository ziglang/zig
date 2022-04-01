#encoding: utf-8
# spaceconfig = {"usemodules" : ["_locale", "array"]}
from pytest import raises
import _io
import os
import sys
import array
import codecs

def test_constructor():
    
    r = _io.BytesIO(b"\xc3\xa9\n\n")
    b = _io.BufferedReader(r, 1000)
    t = _io.TextIOWrapper(b)
    t.__init__(b, encoding="latin1", newline="\r\n")
    assert t.encoding == "latin1"
    assert t.line_buffering == False
    t.__init__(b, encoding="utf8", line_buffering=True)
    assert t.encoding == "utf8"
    assert t.line_buffering == True
    assert t.readline() == "\xe9\n"
    raises(TypeError, t.__init__, b, newline=42)
    raises(ValueError, t.__init__, b, newline='xyzzy')
    t = _io.TextIOWrapper(b)
    assert t.encoding

def test_properties():
    
    r = _io.BytesIO(b"\xc3\xa9\n\n")
    b = _io.BufferedReader(r, 1000)
    t = _io.TextIOWrapper(b)
    assert t.readable()
    assert t.seekable()
    #
    class CustomFile(object):
        def isatty(self): return 'YES'
        readable = writable = seekable = lambda self: False
    t = _io.TextIOWrapper(CustomFile())
    assert t.isatty() == 'YES'

def test_default_implementations():
    
    file = _io._TextIOBase()
    raises(_io.UnsupportedOperation, file.read)
    raises(_io.UnsupportedOperation, file.seek, 0)
    raises(_io.UnsupportedOperation, file.readline)
    raises(_io.UnsupportedOperation, file.detach)

def test_isatty():
    
    class Tty(_io.BytesIO):
        def isatty(self):
            return True
    txt = _io.TextIOWrapper(Tty())
    assert txt.isatty()

def test_unreadable():
    
    class UnReadable(_io.BytesIO):
        def readable(self):
            return False
    txt = _io.TextIOWrapper(UnReadable())
    raises(IOError, txt.read)

def test_unwritable():
    
    class UnWritable(_io.BytesIO):
        def writable(self):
            return False
    txt = _io.TextIOWrapper(UnWritable())
    raises(_io.UnsupportedOperation, txt.write, "blah")
    raises(_io.UnsupportedOperation, txt.writelines, ["blah\n"])

def test_invalid_seek():
    
    t = _io.TextIOWrapper(_io.BytesIO(b"\xc3\xa9\n\n"))
    raises(_io.UnsupportedOperation, t.seek, 1, 1)
    raises(_io.UnsupportedOperation, t.seek, 1, 2)

def test_unseekable():
    
    class Unseekable(_io.BytesIO):
        def seekable(self):
            return False
    txt = _io.TextIOWrapper(Unseekable())
    raises(_io.UnsupportedOperation, txt.tell)
    raises(_io.UnsupportedOperation, txt.seek, 0)

def test_detach():
    
    b = _io.BytesIO()
    f = _io.TextIOWrapper(b)
    assert f.detach() is b
    raises(ValueError, f.fileno)
    raises(ValueError, f.close)
    raises(ValueError, f.detach)
    raises(ValueError, f.flush)

    # Operations independent of the detached stream should still work
    repr(f)
    assert isinstance(f.encoding, str)
    assert f.errors == "strict"
    assert not f.line_buffering

    assert not b.closed
    b.close()

def test_newlinetranslate():
    
    r = _io.BytesIO(b"abc\r\ndef\rg")
    b = _io.BufferedReader(r, 1000)
    t = _io.TextIOWrapper(b)
    assert t.read() == "abc\ndef\ng"

def test_one_by_one():
    
    r = _io.BytesIO(b"abc\r\ndef\rg")
    t = _io.TextIOWrapper(r)
    reads = []
    while True:
        c = t.read(1)
        assert len(c) <= 1
        if not c:
            break
        reads.append(c)
    assert ''.join(reads) == "abc\ndef\ng"

def test_read_some_then_all():
    
    r = _io.BytesIO(b"abc\ndef\n")
    t = _io.TextIOWrapper(r)
    reads = t.read(4)
    reads += t.read()
    assert reads == "abc\ndef\n"

def test_read_some_then_readline():
    
    r = _io.BytesIO(b"abc\ndef\n")
    t = _io.TextIOWrapper(r)
    reads = t.read(4)
    reads += t.readline()
    assert reads == "abc\ndef\n"

def test_read_bug_unicode():
    
    r = _io.BytesIO(b"\xc3\xa4bc\ndef\n")
    t = _io.TextIOWrapper(r, encoding="utf-8")
    reads = t.read(4)
    assert reads == u"äbc\n"
    reads += t.readline()
    assert reads == u"äbc\ndef\n"

def test_encoded_writes():
    
    data = "1234567890"
    tests = ("utf-16",
             "utf-16-le",
             "utf-16-be",
             "utf-32",
             "utf-32-le",
             "utf-32-be")
    for encoding in tests:
        buf = _io.BytesIO()
        f = _io.TextIOWrapper(buf, encoding=encoding)
        # Check if the BOM is written only once (see issue1753).
        f.write(data)
        f.write(data)
        f.seek(0)
        assert f.read() == data * 2
        f.seek(0)
        assert f.read() == data * 2
        assert buf.getvalue() == (data * 2).encode(encoding)

def test_writelines_error():
    
    txt = _io.TextIOWrapper(_io.BytesIO())
    raises(TypeError, txt.writelines, [1, 2, 3])
    raises(TypeError, txt.writelines, None)
    raises(TypeError, txt.writelines, b'abc')

def test_tell():
    
    r = _io.BytesIO(b"abc\ndef\n")
    t = _io.TextIOWrapper(r)
    assert t.tell() == 0
    t.read(4)
    assert t.tell() == 4

def test_destructor():
    
    l = []
    class MyBytesIO(_io.BytesIO):
        def close(self):
            l.append(self.getvalue())
            _io.BytesIO.close(self)
    b = MyBytesIO()
    t = _io.TextIOWrapper(b, encoding="ascii")
    t.write("abc")
    del t
    import gc; gc.collect()
    assert l == [b"abc"]

def test_newlines():
    
    input_lines = [ "unix\n", "windows\r\n", "os9\r", "last\n", "nonl" ]

    tests = [
        [ None, [ 'unix\n', 'windows\n', 'os9\n', 'last\n', 'nonl' ] ],
        [ '', input_lines ],
        [ '\n', [ "unix\n", "windows\r\n", "os9\rlast\n", "nonl" ] ],
        [ '\r\n', [ "unix\nwindows\r\n", "os9\rlast\nnonl" ] ],
        [ '\r', [ "unix\nwindows\r", "\nos9\r", "last\nnonl" ] ],
    ]

    # Try a range of buffer sizes to test the case where \r is the last
    # character in TextIOWrapper._pending_line.
    encoding = "ascii"
    # XXX: str.encode() should return bytes
    data = bytes(''.join(input_lines).encode(encoding))
    for do_reads in (False, True):
        for bufsize in range(1, 10):
            for newline, exp_lines in tests:
                bufio = _io.BufferedReader(_io.BytesIO(data), bufsize)
                textio = _io.TextIOWrapper(bufio, newline=newline,
                                          encoding=encoding)
                if do_reads:
                    got_lines = []
                    while True:
                        c2 = textio.read(2)
                        if c2 == '':
                            break
                        len(c2) == 2
                        got_lines.append(c2 + textio.readline())
                else:
                    got_lines = list(textio)

                for got_line, exp_line in zip(got_lines, exp_lines):
                    assert got_line == exp_line
                assert len(got_lines) == len(exp_lines)

def test_readline():
    

    s = b"AAA\r\nBBB\rCCC\r\nDDD\nEEE\r\n"
    r = "AAA\nBBB\nCCC\nDDD\nEEE\n"
    txt = _io.TextIOWrapper(_io.BytesIO(s), encoding="ascii")
    txt._CHUNK_SIZE = 4

    reads = txt.read(4)
    reads += txt.read(4)
    reads += txt.readline()
    reads += txt.readline()
    reads += txt.readline()
    assert reads == r

def test_name():
    

    t = _io.TextIOWrapper(_io.BytesIO(b""))
    # CPython raises an AttributeError, we raise a TypeError.
    raises((AttributeError, TypeError), setattr, t, "name", "anything")

def test_repr():
    

    t = _io.TextIOWrapper(_io.BytesIO(b""), encoding="utf-8")
    assert repr(t) == "<_io.TextIOWrapper encoding='utf-8'>"
    t = _io.TextIOWrapper(_io.BytesIO(b""), encoding="ascii")
    assert repr(t) == "<_io.TextIOWrapper encoding='ascii'>"
    t = _io.TextIOWrapper(_io.BytesIO(b""), encoding="utf-8")
    assert repr(t) == "<_io.TextIOWrapper encoding='utf-8'>"
    b = _io.BytesIO(b"")
    t = _io.TextIOWrapper(b, encoding="utf-8")
    b.name = "dummy"
    assert repr(t) == "<_io.TextIOWrapper name='dummy' encoding='utf-8'>"
    t.mode = "r"
    assert repr(t) == "<_io.TextIOWrapper name='dummy' mode='r' encoding='utf-8'>"
    b.name = b"dummy"
    assert repr(t) == "<_io.TextIOWrapper name=b'dummy' mode='r' encoding='utf-8'>"

def test_rawio():
    # Issue #12591: TextIOWrapper must work with raw I/O objects, so
    # that subprocess.Popen() can have the required unbuffered
    # semantics with universal_newlines=True.
    
    raw = get_MockRawIO()([b'abc', b'def', b'ghi\njkl\nopq\n'])
    txt = _io.TextIOWrapper(raw, encoding='ascii', newline='\n')
    # Reads
    assert txt.read(4) == 'abcd'
    assert txt.readline() == 'efghi\n'
    assert list(txt) == ['jkl\n', 'opq\n']

def test_rawio_write_through():
    # Issue #12591: with write_through=True, writes don't need a flush
    
    raw = get_MockRawIO()([b'abc', b'def', b'ghi\njkl\nopq\n'])
    txt = _io.TextIOWrapper(raw, encoding='ascii', newline='\n',
                            write_through=True)
    txt.write('1')
    txt.write('23\n4')
    txt.write('5')
    assert b''.join(raw._write_stack) == b'123\n45'

def get_MockRawIO():
    
    class MockRawIO(_io._RawIOBase):
        def __init__(self, read_stack=()):
            self._read_stack = list(read_stack)
            self._write_stack = []
            self._reads = 0
            self._extraneous_reads = 0

        def write(self, b):
            self._write_stack.append(bytes(b))
            return len(b)

        def writable(self):
            return True

        def fileno(self):
            return 42

        def readable(self):
            return True

        def seekable(self):
            return True

        def seek(self, pos, whence):
            return 0   # wrong but we gotta return something

        def tell(self):
            return 0   # same comment as above

        def readinto(self, buf):
            self._reads += 1
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

        def truncate(self, pos=None):
            return pos

        def read(self, n=None):
            self._reads += 1
            try:
                return self._read_stack.pop(0)
            except:
                self._extraneous_reads += 1
                return b""
    return MockRawIO

def test_flush_error_on_close():
    
    txt = _io.TextIOWrapper(_io.BytesIO(b""), encoding="ascii")
    def bad_flush():
        raise IOError()
    txt.flush = bad_flush
    raises(IOError, txt.close)  # exception not swallowed
    assert txt.closed

def test_close_error_on_close():
    buffer = _io.BytesIO(b'testdata')
    def bad_flush():
        raise OSError('flush')
    def bad_close():
        raise OSError('close')
    buffer.close = bad_close
    txt = _io.TextIOWrapper(buffer, encoding="ascii")
    txt.flush = bad_flush
    err = raises(OSError, txt.close)
    assert err.value.args == ('close',)
    assert isinstance(err.value.__context__, OSError)
    assert err.value.__context__.args == ('flush',)
    assert not txt.closed

def test_illegal_decoder():
    
    raises(LookupError, _io.TextIOWrapper, _io.BytesIO(),
           encoding='quopri_codec')

def test_read_nonbytes():
    
    class NonbytesStream(_io.StringIO):
        read1 = _io.StringIO.read
    t = _io.TextIOWrapper(NonbytesStream(u'a'))
    raises(TypeError, t.read, 1)
    t = _io.TextIOWrapper(NonbytesStream(u'a'))
    raises(TypeError, t.readline)
    t = _io.TextIOWrapper(NonbytesStream(u'a'))
    raises(TypeError, t.read)

def test_read_byteslike():

    class MemviewBytesIO(_io.BytesIO):
        '''A BytesIO object whose read method returns memoryviews
           rather than bytes'''

        def read1(self, len_):
            return _to_memoryview(super().read1(len_))

        def read(self, len_):
            return _to_memoryview(super().read(len_))

    def _to_memoryview(buf):
        '''Convert bytes-object *buf* to a non-trivial memoryview'''

        arr = array.array('i')
        idx = len(buf) - len(buf) % arr.itemsize
        arr.frombytes(buf[:idx])
        return memoryview(arr)

    r = MemviewBytesIO(b'Just some random string\n')
    t = _io.TextIOWrapper(r, 'utf-8')

    # TextIOwrapper will not read the full string, because
    # we truncate it to a multiple of the native int size
    # so that we can construct a more complex memoryview.
    bytes_val =  _to_memoryview(r.getvalue()).tobytes()

    assert t.read(200) == bytes_val.decode('utf-8')

def test_device_encoding():
    encoding = os.device_encoding(sys.stderr.fileno())
    if not encoding:
        skip("Requires a result from "
             "os.device_encoding(sys.stderr.fileno())")
    
    f = _io.TextIOWrapper(sys.stderr.buffer)
    assert f.encoding == encoding

def test_device_encoding_ovf():
    
    b = _io.BytesIO()
    b.fileno = lambda: sys.maxsize + 1
    raises(OverflowError, _io.TextIOWrapper, b)

def test_uninitialized():
    
    t = _io.TextIOWrapper.__new__(_io.TextIOWrapper)
    del t
    t = _io.TextIOWrapper.__new__(_io.TextIOWrapper)
    raises(Exception, repr, t)
    raises(ValueError, t.read, 0)
    t.__init__(_io.BytesIO())
    assert t.read(0) == u''

def test_issue25862():
    # CPython issue #25862
    # Assertion failures occurred in tell() after read() and write().
    from _io import TextIOWrapper, BytesIO
    t = TextIOWrapper(BytesIO(b'test'), encoding='ascii')
    t.read(1)
    t.read()
    t.tell()
    t = TextIOWrapper(BytesIO(b'test'), encoding='ascii')
    t.read(1)
    t.write('x')
    t.tell()

def test_newline_decoder():
    
    def check_newline_decoding_utf8(decoder):
        # UTF-8 specific tests for a newline decoder
        def _check_decode(b, s, **kwargs):
            # We exercise getstate() / setstate() as well as decode()
            state = decoder.getstate()
            assert decoder.decode(b, **kwargs) == s
            decoder.setstate(state)
            assert decoder.decode(b, **kwargs) == s

        _check_decode(b'\xe8\xa2\x88', "\u8888")

        _check_decode(b'\xe8', "")
        _check_decode(b'\xa2', "")
        _check_decode(b'\x88', "\u8888")

        _check_decode(b'\xe8', "")
        _check_decode(b'\xa2', "")
        _check_decode(b'\x88', "\u8888")

        _check_decode(b'\xe8', "")
        raises(UnicodeDecodeError, decoder.decode, b'', final=True)

        decoder.reset()
        _check_decode(b'\n', "\n")
        _check_decode(b'\r', "")
        _check_decode(b'', "\n", final=True)
        _check_decode(b'\r', "\n", final=True)

        _check_decode(b'\r', "")
        _check_decode(b'a', "\na")

        _check_decode(b'\r\r\n', "\n\n")
        _check_decode(b'\r', "")
        _check_decode(b'\r', "\n")
        _check_decode(b'\na', "\na")

        _check_decode(b'\xe8\xa2\x88\r\n', "\u8888\n")
        _check_decode(b'\xe8\xa2\x88', "\u8888")
        _check_decode(b'\n', "\n")
        _check_decode(b'\xe8\xa2\x88\r', "\u8888")
        _check_decode(b'\n', "\n")

    def check_newline_decoding(decoder, encoding):
        result = []
        if encoding is not None:
            encoder = codecs.getincrementalencoder(encoding)()
            def _decode_bytewise(s):
                # Decode one byte at a time
                for b in encoder.encode(s):
                    result.append(decoder.decode(bytes([b])))
        else:
            encoder = None
            def _decode_bytewise(s):
                # Decode one char at a time
                for c in s:
                    result.append(decoder.decode(c))
        assert decoder.newlines == None
        _decode_bytewise("abc\n\r")
        assert decoder.newlines == '\n'
        _decode_bytewise("\nabc")
        assert decoder.newlines == ('\n', '\r\n')
        _decode_bytewise("abc\r")
        assert decoder.newlines == ('\n', '\r\n')
        _decode_bytewise("abc")
        assert decoder.newlines == ('\r', '\n', '\r\n')
        _decode_bytewise("abc\r")
        assert "".join(result) == "abc\n\nabcabc\nabcabc"
        decoder.reset()
        input = "abc"
        if encoder is not None:
            encoder.reset()
            input = encoder.encode(input)
        assert decoder.decode(input) == "abc"
        assert decoder.newlines is None

    encodings = (
        # None meaning the IncrementalNewlineDecoder takes unicode input
        # rather than bytes input
        None, 'utf-8', 'latin-1',
        'utf-16', 'utf-16-le', 'utf-16-be',
        'utf-32', 'utf-32-le', 'utf-32-be',
    )
    for enc in encodings:
        decoder = enc and codecs.getincrementaldecoder(enc)()
        decoder = _io.IncrementalNewlineDecoder(decoder, translate=True)
        check_newline_decoding(decoder, enc)
    decoder = codecs.getincrementaldecoder("utf-8")()
    decoder = _io.IncrementalNewlineDecoder(decoder, translate=True)
    check_newline_decoding_utf8(decoder)

def test_newline_bytes():
    
    # Issue 5433: Excessive optimization in IncrementalNewlineDecoder
    def _check(dec):
        assert dec.newlines is None
        assert dec.decode("\u0D00") == "\u0D00"
        assert dec.newlines is None
        assert dec.decode("\u0A00") == "\u0A00"
        assert dec.newlines is None
    dec = _io.IncrementalNewlineDecoder(None, translate=False)
    _check(dec)
    dec = _io.IncrementalNewlineDecoder(None, translate=True)
    _check(dec)

def test_newlines2():
    inner_decoder = codecs.getincrementaldecoder("utf-8")()
    decoder = _io.IncrementalNewlineDecoder(inner_decoder, translate=True)
    msg = b"abc\r\n\n\r\r\n\n"
    decoded = ''
    for ch in msg:
        decoded += decoder.decode(bytes([ch]))
    assert set(decoder.newlines) == {"\r", "\n", "\r\n"}

def test_reconfigure_line_buffering():
    r = _io.BytesIO()
    b = _io.BufferedWriter(r, 1000)
    t = _io.TextIOWrapper(b, newline="\n", line_buffering=False)
    t.write("AB\nC")
    assert r.getvalue() == b""

    t.reconfigure(line_buffering=True)   # implicit flush
    assert r.getvalue() == b"AB\nC"
    t.write("DEF\nG")
    assert r.getvalue() == b"AB\nCDEF\nG"
    t.write("H")
    assert r.getvalue() == b"AB\nCDEF\nG"
    t.reconfigure(line_buffering=False)   # implicit flush
    assert r.getvalue() == b"AB\nCDEF\nGH"
    t.write("IJ")
    assert r.getvalue() == b"AB\nCDEF\nGH"

    # Keeping default value
    t.reconfigure()
    t.reconfigure(line_buffering=None)
    assert t.line_buffering == False
    assert type(t.line_buffering) is bool
    t.reconfigure(line_buffering=True)
    t.reconfigure()
    t.reconfigure(line_buffering=None)
    assert t.line_buffering == True

def test_reconfigure_write_through():
    raw = get_MockRawIO()([])
    t = _io.TextIOWrapper(raw, encoding='ascii', newline='\n')
    t.write('1')
    t.reconfigure(write_through=True)  # implied flush
    assert t.write_through == True
    assert b''.join(raw._write_stack) == b'1'
    t.write('23')
    assert b''.join(raw._write_stack) == b'123'
    t.reconfigure(write_through=False)
    assert t.write_through == False
    t.write('45')
    t.flush()
    assert b''.join(raw._write_stack) == b'12345'
    # Keeping default value
    t.reconfigure()
    t.reconfigure(write_through=None)
    assert t.write_through == False
    t.reconfigure(write_through=True)
    t.reconfigure()
    t.reconfigure(write_through=None)
    assert t.write_through == True

def test_reconfigure_newline():
    import os
    raw = _io.BytesIO(b'CR\rEOF')
    txt = _io.TextIOWrapper(raw, 'ascii', newline='\n')
    txt.reconfigure(newline=None)
    assert txt.readline() == 'CR\n'
    raw = _io.BytesIO(b'CR\rEOF')
    txt = _io.TextIOWrapper(raw, 'ascii', newline='\n')
    txt.reconfigure(newline='')
    assert txt.readline() == 'CR\r'
    raw = _io.BytesIO(b'CR\rLF\nEOF')
    txt = _io.TextIOWrapper(raw, 'ascii', newline='\r')
    txt.reconfigure(newline='\n')
    assert txt.readline() == 'CR\rLF\n'
    raw = _io.BytesIO(b'LF\nCR\rEOF')
    txt = _io.TextIOWrapper(raw, 'ascii', newline='\n')
    txt.reconfigure(newline='\r')
    assert txt.readline() == 'LF\nCR\r'
    raw = _io.BytesIO(b'CR\rCRLF\r\nEOF')
    txt = _io.TextIOWrapper(raw, 'ascii', newline='\r')
    txt.reconfigure(newline='\r\n')
    assert txt.readline() == 'CR\rCRLF\r\n'

    txt = _io.TextIOWrapper(_io.BytesIO(), 'ascii', newline='\r')
    txt.reconfigure(newline=None)
    txt.write('linesep\n')
    txt.reconfigure(newline='')
    txt.write('LF\n')
    txt.reconfigure(newline='\n')
    txt.write('LF\n')
    txt.reconfigure(newline='\r')
    txt.write('CR\n')
    txt.reconfigure(newline='\r\n')
    txt.write('CRLF\n')
    expected = 'linesep' + os.linesep + 'LF\nLF\nCR\rCRLF\r\n'
    assert txt.detach().getvalue().decode('ascii') == expected

def test_reconfigure_encoding_read():
    # latin1 -> utf8
    # (latin1 can decode utf-8 encoded string)
    data = 'abc\xe9\n'.encode('latin1') + 'd\xe9f\n'.encode('utf8')
    raw = _io.BytesIO(data)
    txt = _io.TextIOWrapper(raw, encoding='latin1', newline='\n')
    assert txt.readline() == 'abc\xe9\n'
    with raises(_io.UnsupportedOperation):
        txt.reconfigure(encoding='utf-8')
    with raises(_io.UnsupportedOperation):
        txt.reconfigure(newline=None)

def test_reconfigure_write_fromascii():
    # ascii has a specific encodefunc in the C implementation,
    # but utf-8-sig has not. Make sure that we get rid of the
    # cached encodefunc when we switch encoders.
    raw = _io.BytesIO()
    txt = _io.TextIOWrapper(raw, encoding='ascii', newline='\n')
    txt.write('foo\n')
    txt.reconfigure(encoding='utf-8-sig')
    txt.write('\xe9\n')
    txt.flush()
    res = raw.getvalue()
    assert raw.getvalue() == b'foo\n\xc3\xa9\n'

def test_reconfigure_write():
    # latin -> utf8
    raw = _io.BytesIO()
    txt = _io.TextIOWrapper(raw, encoding='latin1', newline='\n')
    txt.write('abc\xe9\n')
    txt.reconfigure(encoding='utf-8')
    assert raw.getvalue() == b'abc\xe9\n'
    txt.write('d\xe9f\n')
    txt.flush()
    assert raw.getvalue() == b'abc\xe9\nd\xc3\xa9f\n'

    # ascii -> utf-8-sig: ensure that no BOM is written in the middle of
    # the file
    raw = _io.BytesIO()
    txt = _io.TextIOWrapper(raw, encoding='ascii', newline='\n')
    txt.write('abc\n')
    txt.reconfigure(encoding='utf-8-sig')
    txt.write('d\xe9f\n')
    txt.flush()
    assert raw.getvalue() == b'abc\nd\xc3\xa9f\n'

def test_reconfigure_write_non_seekable():
    raw = _io.BytesIO()
    raw.seekable = lambda: False
    raw.seek = None
    txt = _io.TextIOWrapper(raw, encoding='ascii', newline='\n')
    txt.write('abc\n')
    txt.reconfigure(encoding='utf-8-sig')
    txt.write('d\xe9f\n')
    txt.flush()

    # If the raw stream is not seekable, there'll be a BOM
    assert raw.getvalue() ==  b'abc\n\xef\xbb\xbfd\xc3\xa9f\n'

def test_reconfigure_defaults():
    txt = _io.TextIOWrapper(_io.BytesIO(), 'ascii', 'replace', '\n')
    txt.reconfigure(encoding=None)
    assert txt.encoding == 'ascii'
    assert txt.errors == 'replace'
    txt.write('LF\n')

    txt.reconfigure(newline='\r\n')
    assert txt.encoding == 'ascii'
    assert txt.errors == 'replace'

    txt.reconfigure(errors='ignore')
    assert txt.encoding == 'ascii'
    assert txt.errors == 'ignore'
    txt.write('CRLF\n')

    txt.reconfigure(encoding='utf-8', newline=None)
    assert txt.errors == 'strict'
    txt.seek(0)
    assert txt.read() == 'LF\nCRLF\n'

    assert txt.detach().getvalue() == b'LF\nCRLF\r\n'

