"""Unit tests for streamio (new standard I/O)."""

import os
import time
import random

import pytest

from rpython.rlib import streamio
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.tool.udir import udir


class TSource(streamio.Stream):
    def __init__(self, packets, tell=True, seek=True):
        for x in packets:
            assert x
        self.orig_packets = packets[:]
        self.packets = packets[:]
        self.pos = 0
        self.chunks = []
        self._tell = tell
        self._seek = seek

    def tell(self):
        if not self._tell:
            raise streamio.MyNotImplementedError
        return self.pos

    def seek(self, offset, whence=0):
        if not self._seek:
            raise streamio.MyNotImplementedError
        if whence == 1:
            offset += self.pos
        elif whence == 2:
            for packet in self.orig_packets:
                offset += len(packet)
        else:
            assert whence == 0
        self.packets = list(self.orig_packets)
        self.pos = 0
        while self.pos < offset:
            data = self.read(offset - self.pos)
            assert data
        assert self.pos == offset

    def read(self, n):
        assert n >= 0
        try:
            data = self.packets.pop(0)
        except IndexError:
            return ""
        if len(data) > n:
            data, rest = data[:n], data[n:]
            self.packets.insert(0, rest)
        self.chunks.append((n, len(data), self.pos))
        self.pos += len(data)
        return data

    def close(self):
        pass

class TReader(TSource):

    def flush(self):
        pass

class TWriter(streamio.Stream):

    def __init__(self, data=''):
        self.buf = data
        self.chunks = []
        self.pos = 0

    def write(self, data):
        self.chunks.append((self.pos, data))
        if self.pos >= len(self.buf):
            self.buf += "\0" * (self.pos - len(self.buf)) + data
            self.pos = len(self.buf)
        else:
            start = self.pos
            assert start >= 0
            self.buf = (self.buf[:start] + data +
                        self.buf[start + len(data):])
            self.pos += len(data)

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        if whence == 0:
            pass
        elif whence == 1:
            offset += self.pos
        elif whence == 2:
            offset += len(self.buf)
        else:
            raise ValueError("whence should be 0, 1 or 2")
        if offset < 0:
            offset = 0
        self.pos = offset

    def close(self):
        pass

    def truncate(self, size=None):
        if size is None:
            size = self.pos
        if size <= len(self.buf):
            self.buf = self.buf[:size]
        else:
            self.buf += '\0' * (size - len(self.buf))

    def flush(self):
        pass

class TReaderWriter(TWriter):

    def read(self, n=-1):
        start = self.pos
        assert start >= 0
        if n < 1:
            result = self.buf[start: ]
            self.pos = len(self.buf)
        else:
            if n > len(self.buf) - start:
                n = len(self.buf) - start
            stop = start + n
            assert stop >= 0
            result = self.buf[start: stop]
            self.pos += n
        return result

class BaseTestBufferingInputStreamTests(BaseRtypingTest):

    packets = ["a", "b", "\n", "def", "\nxy\npq\nuv", "wx"]
    lines = ["ab\n", "def\n", "xy\n", "pq\n", "uvwx"]

    def _freeze_(self):
        return True

    def makeStream(self, tell=False, seek=False, bufsize=-1):
        base = TSource(self.packets)
        self.source = base
        def f(*args):
            raise NotImplementedError
        if not tell:
            base.tell = f
        if not seek:
            base.seek = f

        return streamio.BufferingInputStream(base, bufsize)

    def test_readline(self):
        for file in [self.makeStream(), self.makeStream(bufsize=1)]:
            def f():
                i = 0
                result = True
                while 1:
                    r = file.readline()
                    if r == "":
                        break
                    result = result and self.lines[i] == r
                    i += 1
                return result
            res = self.interpret(f, [])
            assert res

    def test_readall(self):
        file = self.makeStream()
        def f():
            return file.readall() == "".join(self.lines)
        res = self.interpret(f, [])
        assert res

    def test_readall_small_bufsize(self):
        file = self.makeStream(bufsize=1)
        def f():
            return file.readall() == "".join(self.lines)
        res = self.interpret(f, [])
        assert res

    def test_readall_after_readline(self):
        file = self.makeStream()
        def f():
            return (file.readline() == self.lines[0] and
                    file.readline() == self.lines[1] and
                    file.readall() == "".join(self.lines[2:]))
        res = self.interpret(f, [])
        assert res

    def test_read_1_after_readline(self):
        file = self.makeStream()
        def f():
            assert file.readline() == "ab\n"
            assert file.readline() == "def\n"
            blocks = []
            while 1:
                block = file.read(1)
                if not block:
                    break
                blocks.append(block)
                assert file.read(0) == ""
            return "".join(blocks) == "".join(self.lines)[7:]
        res = self.interpret(f, [])
        assert res

    def test_read_1(self):
        file = self.makeStream()
        def f():
            blocks = []
            while 1:
                block = file.read(1)
                if not block:
                    break
                blocks.append(block)
                assert file.read(0) == ""
            return "".join(blocks) == "".join(self.lines)
        res = self.interpret(f, [])
        assert res

    def test_read_2(self):
        file = self.makeStream()
        def f():
            blocks = []
            while 1:
                block = file.read(2)
                if not block:
                    break
                blocks.append(block)
                assert file.read(0) == ""
            return blocks == ["ab", "\nd", "ef", "\nx", "y\n", "pq",
                              "\nu", "vw", "x"]
        res = self.interpret(f, [])
        assert res

    def test_read_4(self):
        file = self.makeStream()
        def f():
            blocks = []
            while 1:
                block = file.read(4)
                if not block:
                    break
                blocks.append(block)
                assert file.read(0) == ""
            return blocks == ["ab\nd", "ef\nx", "y\npq", "\nuvw", "x"]
        res = self.interpret(f, [])
        assert res

    def test_read_4_after_readline(self):
        file = self.makeStream()
        def f():
            res = file.readline()
            assert res == "ab\n"
            assert file.readline() == "def\n"
            blocks = [file.read(4)]
            while 1:
                block = file.read(4)
                if not block:
                    break
                blocks.append(block)
                assert file.read(0) == ""
            return blocks == ["xy\np", "q\nuv", "wx"]
        res = self.interpret(f, [])
        assert res

    def test_read_4_small_bufsize(self):
        file = self.makeStream(bufsize=1)
        def f():
            blocks = []
            while 1:
                block = file.read(4)
                if not block:
                    break
                blocks.append(block)
            return blocks == ["ab\nd", "ef\nx", "y\npq", "\nuvw", "x"]
        res = self.interpret(f, [])
        assert res

    def test_tell_1(self):
        file = self.makeStream(tell=True)
        def f():
            pos = 0
            while 1:
                assert file.tell() == pos
                n = len(file.read(1))
                if not n:
                    break
                pos += n
            return True
        res = self.interpret(f, [])
        assert res

    def test_tell_1_after_readline(self):
        file = self.makeStream(tell=True)
        def f():
            pos = 0
            pos += len(file.readline())
            assert file.tell() == pos
            pos += len(file.readline())
            assert file.tell() == pos
            while 1:
                assert file.tell() == pos
                n = len(file.read(1))
                if not n:
                    break
                pos += n
            return True
        res = self.interpret(f, [])
        assert res

    def test_tell_2(self):
        file = self.makeStream(tell=True)
        def f():
            pos = 0
            while 1:
                assert file.tell() == pos
                n = len(file.read(2))
                if not n:
                    break
                pos += n
            return True
        res = self.interpret(f, [])
        assert res

    def test_tell_4(self):
        file = self.makeStream(tell=True)
        def f():
            pos = 0
            while 1:
                assert file.tell() == pos
                n = len(file.read(4))
                if not n:
                    break
                pos += n
            return True
        res = self.interpret(f, [])
        assert res

    def test_tell_readline(self):
        file = self.makeStream(tell=True)
        def f():
            pos = 0
            while 1:
                assert file.tell() == pos
                n = len(file.readline())
                if not n:
                    break
                pos += n
            return True
        res = self.interpret(f, [])
        assert res

    def test_seek(self):
        file = self.makeStream(tell=True, seek=True)
        end = len(file.readall())
        file.seek(0, 0)
        cases = [(readto, seekto, whence) for readto in range(0, end+1)
                                          for seekto in range(0, end+1)
                                          for whence in [0, 1, 2]]
        random.shuffle(cases)
        cases = cases[:7]      # pick some cases at random - too slow!
        def f():
            all = file.readall()
            assert end == len(all)
            for readto, seekto, whence in cases:
                file.seek(0, 0)
                assert file.tell() == 0
                head = file.read(readto)
                assert head == all[:readto]
                if whence == 1:
                    offset = seekto - readto
                elif whence == 2:
                    offset = seekto - end
                else:
                    offset = seekto
                file.seek(offset, whence)
                here = file.tell()
                assert here == seekto
                rest = file.readall()
                assert rest == all[seekto:]
            return True
        res = self.interpret(f, [])
        assert res

    def test_seek_noseek(self):
        file = self.makeStream()
        all = file.readall()
        end = len(all)
        cases = [(readto, seekto, whence) for readto in range(0, end+1)
                                          for seekto in range(0, end+1)
                                          for whence in [0, 1, 2]]
        random.shuffle(cases)
        cases = cases[:7]      # pick some cases at random - too slow!
        def f():
            for readto, seekto, whence in cases:
                base = TSource(self.packets, seek=False)
                file = streamio.BufferingInputStream(base)
                head = file.read(readto)
                assert head == all[:readto]
                if whence == 1:
                    offset = seekto - readto
                elif whence == 2:
                    offset = seekto - end
                else:
                    offset = seekto
                if whence == 2 and seekto < file.tell() or seekto < file.tell() - file.pos:
                    try:
                        file.seek(offset, whence)
                    except streamio.MyNotImplementedError:
                        assert whence in (0, 1)
                    except streamio.StreamError:
                        assert whence == 2
                    else:
                        assert False
                else:
                    file.seek(offset, whence)
                    rest = file.readall()
                    assert rest == all[seekto:]
            return True
        res = self.interpret(f, [])
        assert res

class TestBufferingInputStreamTests(BaseTestBufferingInputStreamTests):
    def interpret(self, func, args, **kwds):
        return func(*args)

class TestBufferingInputStreamTestsLLinterp(BaseTestBufferingInputStreamTests):
    pass

class TestBufferedRead:
    packets = ["a", "b", "\n", "def", "\nxy\npq\nuv", "wx"]
    lines = ["ab\n", "def\n", "xy\n", "pq\n", "uvwx"]

    def makeStream(self, tell=False, seek=False, bufsize=-1):
        base = TSource(self.packets)
        self.source = base
        def f(*args):
            raise NotImplementedError
        if not tell:
            base.tell = f
        if not seek:
            base.seek = f
        return streamio.BufferingInputStream(base, bufsize)

    def test_dont_read_small(self):
        file = self.makeStream(bufsize=4)
        while file.read(1): pass
        for want, got, pos in self.source.chunks:
            assert want >= 4

class BaseTestBufferingOutputStream(BaseRtypingTest):

    def test_write(self):
        def f():
            base = TWriter()
            filter = streamio.BufferingOutputStream(base, 4)
            filter.write("123")
            assert not base.chunks
            assert filter.tell() == 3
            filter.write("456")
            filter.write("789ABCDEF")
            filter.write("0123")
            assert filter.tell() == 19
            filter.close()
            assert base.buf == "123456789ABCDEF0123"
            for chunk in base.chunks[:-1]:
                assert len(chunk[1]) >= 4
        self.interpret(f, [])

    def test_write_seek(self):
        def f():
            base = TWriter()
            filter = streamio.BufferingOutputStream(base, 4)
            filter.write("x"*6)
            filter.seek(3, 0)
            filter.write("y"*2)
            filter.close()
            assert base.buf == "x"*3 + "y"*2 + "x"*1
        self.interpret(f, [])

    def test_write_seek_beyond_end(self):
        "Linux behaviour. May be different on other platforms."
        def f():
            base = TWriter()
            filter = streamio.BufferingOutputStream(base, 4)
            filter.seek(3, 0)
            filter.write("y"*2)
            filter.close()
            assert base.buf == "\0"*3 + "y"*2
        self.interpret(f, [])

    def test_truncate(self):
        "Linux behaviour. May be different on other platforms."
        def f():
            base = TWriter()
            filter = streamio.BufferingOutputStream(base, 4)
            filter.write('x')
            filter.truncate(4)
            filter.write('y')
            filter.close()
            assert base.buf == 'xy' + '\0' * 2
        self.interpret(f, [])

    def test_truncate2(self):
        "Linux behaviour. May be different on other platforms."
        def f():
            base = TWriter()
            filter = streamio.BufferingOutputStream(base, 4)
            filter.write('12345678')
            filter.truncate(4)
            filter.write('y')
            filter.close()
            assert base.buf == '1234' + '\0' * 4 + 'y'
        self.interpret(f, [])

class TestBufferingOutputStream(BaseTestBufferingOutputStream):
    def interpret(self, func, args, **kwds):
        return func(*args)

class TestBufferingOutputStreamLLinterp(BaseTestBufferingOutputStream):
    pass


class BaseTestLineBufferingOutputStream(BaseRtypingTest):

    def test_write(self):
        base = TWriter()
        filter = streamio.LineBufferingOutputStream(base)
        def f():
            filter.bufsize = 4 # More handy for testing than the default
            filter.write("123")
            assert base.buf == ""
            assert filter.tell() == 3
            filter.write("456")
            assert base.buf == "1234"
            filter.write("789ABCDEF\n")
            assert base.buf == "123456789ABCDEF\n"
            filter.write("0123")
            assert base.buf == "123456789ABCDEF\n0123"
            assert filter.tell() == 20
            filter.close()
            assert base.buf == "123456789ABCDEF\n0123"
        self.interpret(f, [])

    def test_write_seek(self):
        base = TWriter()
        filter = streamio.BufferingOutputStream(base, 4)
        def f():
            filter.write("x"*6)
            filter.seek(3, 0)
            filter.write("y"*2)
            filter.close()
            assert base.buf == "x"*3 + "y"*2 + "x"*1
        self.interpret(f, [])

class TestLineBufferingOutputStream(BaseTestLineBufferingOutputStream):
    def interpret(self, func, args, **kwds):
        return func(*args)

class TestLineBufferingOutputStreamLLinterp(BaseTestLineBufferingOutputStream):
    pass


class BaseTestCRLFFilter(BaseRtypingTest):

    def test_filter(self):
        packets = ["abc\ndef\rghi\r\nxyz\r", "123\r", "\n456"]
        expected = ["abc\ndef\nghi\nxyz\n", "123\n", "456"]
        crlf = streamio.CRLFFilter(TSource(packets))
        def f():
            blocks = []
            while 1:
                block = crlf.read(100)
                if not block:
                    break
                blocks.append(block)
            assert blocks == expected
        self.interpret(f, [])

class TestCRLFFilter(BaseTestCRLFFilter):
    def interpret(self, func, args, **kwds):
        return func(*args)

class TestCRLFFilterLLinterp(BaseTestCRLFFilter):
    pass

class BaseTestTextCRLFFilter(BaseRtypingTest):
    def test_simple(self):
        packets = ["abc\r\n", "abc\r", "\nd\r\nef\r\ngh", "a\rbc\r", "def\n",
                   "\r", "\n\r"]
        expected = ["abc\n", "abc\n", "d\nef\ngh", "a\rbc\r", "def\n", "\n",
                    "\r"]
        crlf = streamio.TextCRLFFilter(TSource(packets))
        def f():
            blocks = []
            while True:
                block = crlf.read(100)
                if not block:
                    break
                blocks.append(block)
            assert blocks == expected
        self.interpret(f, [])

    def test_readline_and_seek(self):
        packets = ["abc\r\n", "abc\r", "\nd\r\nef\r\ngh", "a\rbc\r", "def\n",
                   "\r", "\n\r"]
        expected = ["abc\n", "abc\n", "d\n","ef\n", "gha\rbc\rdef\n", "\n",
                    "\r"]
        crlf = streamio.TextCRLFFilter(TSource(packets))
        def f():
            lines = []
            while True:
                pos = crlf.tell()
                line = crlf.readline()
                if not line:
                    break
                crlf.seek(pos, 0)
                line2 = crlf.readline()
                assert line2 == line
                lines.append(line)
            assert lines == expected
        self.interpret(f, [])

    def test_seek_relative(self):
        packets = ["abc\r\n", "abc\r", "\nd\r\nef\r"]
        expected = ["abc\n", "abc\n", "d\n","ef\r"]

        crlf = streamio.TextCRLFFilter(TSource(packets))
        def f():
            lines = []
            while True:
                pos = crlf.tell()
                line = crlf.readline()
                if not line:
                    break
                crlf.seek(0, 1)
                lines.append(line)
            assert lines == expected
        self.interpret(f, [])

    def test_write(self):
        data = "line1\r\nline2\rline3\r\n"
        crlf = streamio.TextCRLFFilter(TReaderWriter(data))
        def f():
            line = crlf.readline()
            assert line == 'line1\n'
            line = crlf.read(6)
            assert line == 'line2\r'
            pos = crlf.tell()
            crlf.write('line3\n')
            crlf.seek(pos,0)
            line = crlf.readline()
            assert line == 'line3\n'
            line = crlf.readline()
            assert line == ''
        self.interpret(f, [])

    def test_read1(self):
        s_input = "abc\r\nabc\nd\r\nef\r\ngha\rbc\rdef\n\r\n\r"
        s_output = "abc\nabc\nd\nef\ngha\rbc\rdef\n\n\r"
        assert s_output == s_input.replace('\r\n', '\n')
        packets = list(s_input)
        expected = list(s_output)
        crlf = streamio.TextCRLFFilter(TSource(packets))
        def f():
            blocks = []
            while True:
                block = crlf.read(1)
                if not block:
                    break
                blocks.append(block)
            assert blocks == expected
        self.interpret(f, [])

class TestTextCRLFFilterLLInterp(BaseTestTextCRLFFilter):
    pass


class TestMMapFile(BaseTestBufferingInputStreamTests):
    tfn = None
    fd = None
    Counter = 0

    def interpret(self, func, args, **kwargs):
        return func(*args)

    def teardown_method(self, method):
        tfn = self.tfn
        if tfn:
            self.tfn = None
            try:
                os.remove(tfn)
            except os.error as msg:
                print "can't remove %s: %s" % (tfn, msg)

    def makeStream(self, tell=None, seek=None, bufsize=-1, mode="r"):
        mmapmode = 0
        filemode = 0
        import mmap
        if "r" in mode:
            mmapmode = mmap.ACCESS_READ
            filemode = os.O_RDONLY
        if "w" in mode:
            mmapmode |= mmap.ACCESS_WRITE
            filemode |= os.O_WRONLY
        self.teardown_method(None) # for tests calling makeStream() several time
        self.tfn = str(udir.join('streamio%03d' % TestMMapFile.Counter))
        TestMMapFile.Counter += 1
        f = open(self.tfn, "wb")
        f.writelines(self.packets)
        f.close()
        self.fd = os.open(self.tfn, filemode)
        return streamio.MMapFile(self.fd, mmapmode)

    def test_write(self):
        if os.name == "posix" or os.name == 'nt':
            return # write() does't work on Unix nor on win32:-(
        file = self.makeStream(mode="w")
        file.write("BooHoo\n")
        file.write("Barf\n")
        file.writelines(["a\n", "b\n", "c\n"])
        assert file.tell() == len("BooHoo\nBarf\na\nb\nc\n")
        file.seek(0, 0)
        assert file.read() == "BooHoo\nBarf\na\nb\nc\n"
        file.seek(0, 0)
        assert file.readlines() == (
                         ["BooHoo\n", "Barf\n", "a\n", "b\n", "c\n"])
        assert file.tell() == len("BooHoo\nBarf\na\nb\nc\n")


class BaseTestBufferingInputOutputStreamTests(BaseRtypingTest):

    def test_write(self):
        import sys
        base = TReaderWriter()
        filter = streamio.BufferingInputStream(
                streamio.BufferingOutputStream(base, 4), 4)
        def f():
            filter.write("123456789")
            for chunk in base.chunks:
                assert len(chunk[1]) >= 4
            s = filter.read(sys.maxint)
            assert base.buf == "123456789"
            base.chunks = []
            filter.write("abc")
            assert not base.chunks
            s = filter.read(sys.maxint)
            assert base.buf == "123456789abc"
            base.chunks = []
            filter.write("012")
            assert not base.chunks
            filter.seek(4, 0)
            assert base.buf == "123456789abc012"
            assert filter.read(3) == "567"
            filter.write('x')
            filter.flush()
            assert base.buf == "1234567x9abc012"
        self.interpret(f, [])

    def test_write_seek_beyond_end(self):
        "Linux behaviour. May be different on other platforms."
        base = TReaderWriter()
        filter = streamio.BufferingInputStream(
            streamio.BufferingOutputStream(base, 4), 4)
        def f():
            filter.seek(3, 0)
            filter.write("y"*2)
            filter.close()
            assert base.buf == "\0"*3 + "y"*2
        self.interpret(f, [])

class TestBufferingInputOutputStreamTests(
        BaseTestBufferingInputOutputStreamTests):
    def interpret(self, func, args):
        return func(*args)

class TestBufferingInputOutputStreamTestsLLinterp(
        BaseTestBufferingInputOutputStreamTests):
    pass


class BaseTestTextInputFilter(BaseRtypingTest):

    def _freeze_(self):
        return True

    packets = [
        "foo\r",
        "bar\r",
        "\nfoo\r\n",
        "abc\ndef\rghi\r\nxyz",
        "\nuvw\npqr\r",
        "\n",
        "abc\n",
        ]
    expected = [
        ("foo\n", 4),
        ("bar\n", 9),
        ("foo\n", 14),
        ("abc\ndef\nghi\nxyz", 30),
        ("\nuvw\npqr\n", 40),
        ("abc\n", 44),
        ("", 44),
        ("", 44),
        ]

    expected_with_tell = [
        ("foo\n", 4),
        ("b", 5),
        ("ar\n", 9),
        ("foo\n", 14),
        ("abc\ndef\nghi\nxyz", 30),
        ("\nuvw\npqr\n", 40),
        ("abc\n", 44),
        ("", 44),
        ("", 44),
        ]

    expected_newlines = [
        (["abcd"], [0]),
        (["abcd\n"], [2]),
        (["abcd\r\n"],[4]),
        (["abcd\r"],[0]), # wrong, but requires precognition to fix
        (["abcd\r", "\nefgh"], [0, 4]),
        (["abcd", "\nefg\r", "hij", "k\r\n"], [0, 2, 3, 7]),
        (["abcd", "\refg\r", "\nhij", "k\n"], [0, 1, 5, 7])
        ]

    def test_read(self):
        base = TReader(self.packets)
        filter = streamio.TextInputFilter(base)
        def f():
            for data, pos in self.expected:
                assert filter.read(100) == data
        self.interpret(f, [])

    def test_read_tell(self):
        base = TReader(self.packets)
        filter = streamio.TextInputFilter(base)
        def f():
            for data, pos in self.expected_with_tell:
                assert filter.read(100) == data
                assert filter.tell() == pos
                assert filter.tell() == pos # Repeat the tell() !
        self.interpret(f, [])

    def test_seek(self):
        base = TReader(self.packets)
        filter = streamio.TextInputFilter(base)
        def f():
            sofar = ""
            pairs = []
            while True:
                pairs.append((sofar, filter.tell()))
                c = filter.read(1)
                if not c:
                    break
                assert len(c) == 1
                sofar += c
            all = sofar
            for i in range(len(pairs)):
                sofar, pos = pairs[i]
                filter.seek(pos, 0)
                assert filter.tell() == pos
                assert filter.tell() == pos
                bufs = [sofar]
                while True:
                    data = filter.read(100)
                    if not data:
                        assert filter.read(100) == ""
                        break
                    bufs.append(data)
                assert "".join(bufs) == all
        self.interpret(f, [])

    def test_newlines_attribute(self):
        for packets, expected in self.expected_newlines:
            base = TReader(packets)
            filter = streamio.TextInputFilter(base)
            def f():
                for e in expected:
                    filter.read(100)
                    assert filter.getnewlines() == e
            self.interpret(f, [])


class TestTextInputFilter(BaseTestTextInputFilter):
    def interpret(self, func, args):
        return func(*args)

class TestTextInputFilterLLinterp(BaseTestTextInputFilter):
    pass


class BaseTestTextOutputFilter(BaseRtypingTest):

    def test_write_nl(self):
        def f():
            base = TWriter()
            filter = streamio.TextOutputFilter(base, linesep="\n")
            filter.write("abc")
            filter.write("def\npqr\nuvw")
            filter.write("\n123\n")
            assert base.buf == "abcdef\npqr\nuvw\n123\n"
        self.interpret(f, [])

    def test_write_cr(self):
        def f():
            base = TWriter()
            filter = streamio.TextOutputFilter(base, linesep="\r")
            filter.write("abc")
            filter.write("def\npqr\nuvw")
            filter.write("\n123\n")
            assert base.buf == "abcdef\rpqr\ruvw\r123\r"
        self.interpret(f, [])

    def test_write_crnl(self):
        def f():
            base = TWriter()
            filter = streamio.TextOutputFilter(base, linesep="\r\n")
            filter.write("abc")
            filter.write("def\npqr\nuvw")
            filter.write("\n123\n")
            assert base.buf == "abcdef\r\npqr\r\nuvw\r\n123\r\n"
        self.interpret(f, [])

    def test_write_tell_nl(self):
        def f():
            base = TWriter()
            filter = streamio.TextOutputFilter(base, linesep="\n")
            filter.write("xxx")
            assert filter.tell() == 3
            filter.write("\nabc\n")
            assert filter.tell() == 8
        self.interpret(f, [])

    def test_write_tell_cr(self):
        def f():
            base = TWriter()
            filter = streamio.TextOutputFilter(base, linesep="\r")
            filter.write("xxx")
            assert filter.tell() == 3
            filter.write("\nabc\n")
            assert filter.tell() == 8
        self.interpret(f, [])

    def test_write_tell_crnl(self):
        def f():
            base = TWriter()
            filter = streamio.TextOutputFilter(base, linesep="\r\n")
            filter.write("xxx")
            assert filter.tell() == 3
            filter.write("\nabc\n")
            assert filter.tell() == 10
        self.interpret(f, [])

    def test_write_seek(self):
        def f():
            base = TWriter()
            filter = streamio.TextOutputFilter(base, linesep="\n")
            filter.write("x"*100)
            filter.seek(50, 0)
            filter.write("y"*10)
            assert base.buf == "x"*50 + "y"*10 + "x"*40
        self.interpret(f, [])

class TestTextOutputFilter(BaseTestTextOutputFilter):
    def interpret(self, func, args):
        return func(*args)

class TestTextOutputFilterLLinterp(BaseTestTextOutputFilter):
    pass


class TestDecodingInputFilter:

    def test_read(self):
        chars = u"abc\xff\u1234\u4321\x80xyz"
        data = chars.encode("utf8")
        base = TReader([data])
        filter = streamio.DecodingInputFilter(base)
        bufs = []
        for n in range(1, 11):
            while 1:
                c = filter.read(n)
                assert type(c) == unicode
                if not c:
                    break
                bufs.append(c)
            assert u"".join(bufs) == chars

class TestEncodingOutputFilterTests:

    def test_write(self):
        chars = u"abc\xff\u1234\u4321\x80xyz"
        data = chars.encode("utf8")
        for n in range(1, 11):
            base = TWriter()
            filter = streamio.EncodingOutputFilter(base)
            pos = 0
            while 1:
                c = chars[pos:pos+n]
                if not c:
                    break
                pos += len(c)
                filter.write(c)
            assert base.buf == data


class TestReadlineInputStream:

    packets = ["a", "b", "\n", "def", "\nxy\npq\nuv", "wx"]
    lines = ["ab\n", "def\n", "xy\n", "pq\n", "uvwx"]

    def makeStream(self, seek=False, tell=False, bufsize=-1):
        base = TSource(self.packets)
        self.source = base
        def f(*args):
            if seek is False:
                raise NotImplementedError     # a bug!
            if seek is None:
                raise streamio.MyNotImplementedError   # can be caught
            raise ValueError(seek)  # uh?
        if not tell:
            base.tell = f
        if not seek:
            base.seek = f
        return base

    def test_readline(self):
        for file in [self.makeStream(), self.makeStream(bufsize=2)]:
            i = 0
            while 1:
                r = file.readline()
                if r == "":
                    break
                assert self.lines[i] == r
                i += 1
            assert i == len(self.lines)

    def test_readline_and_read_interleaved(self):
        for file in [self.makeStream(seek=True),
                     self.makeStream(seek=True, bufsize=2)]:
            i = 0
            while 1:
                firstchar = file.read(1)
                if firstchar == "":
                    break
                r = file.readline()
                assert r != ""
                assert self.lines[i] == firstchar + r
                i += 1
            assert i == len(self.lines)

    def test_readline_and_read_interleaved_no_seek(self):
        for file in [self.makeStream(seek=None),
                     self.makeStream(seek=None, bufsize=2)]:
            i = 0
            while 1:
                firstchar = file.read(1)
                if firstchar == "":
                    break
                r = file.readline()
                assert r != ""
                assert self.lines[i] == firstchar + r
                i += 1
            assert i == len(self.lines)

    def test_readline_and_readall(self):
        file = self.makeStream(seek=True, tell=True, bufsize=2)
        r = file.readline()
        assert r == 'ab\n'
        assert file.tell() == 3
        r = file.readall()
        assert r == 'def\nxy\npq\nuvwx'
        r = file.readall()
        assert r == ''


class TestDiskFile:
    def test_read_interrupted(self):
        try:
            from signal import alarm, signal, SIG_DFL, SIGALRM
        except ImportError:
            pytest.skip('no alarm on this platform')
        try:
            read_fd, write_fd = os.pipe()
            file = streamio.DiskFile(read_fd)
            def handler(*a):
                os.write(write_fd, "hello")
            signal(SIGALRM, handler)
            alarm(1)
            assert file.read(10) == "hello"
        finally:
            alarm(0)
            signal(SIGALRM, SIG_DFL)

    def test_write_interrupted(self):
        try:
            from signal import alarm, signal, SIG_DFL, SIGALRM
        except ImportError:
            pytest.skip('no alarm on this platform')
        try:
            read_fd, write_fd = os.pipe()
            file = streamio.DiskFile(write_fd)
            def handler(*a):
                os.read(read_fd, 2000)
                alarm(1)
            signal(SIGALRM, handler)
            alarm(1)
            # Write to the pipe until it is full
            buf = "FILL THE PIPE" * 1000
            while True:
                if os.write(write_fd, buf) < len(buf):
                    break
            # Write more, this should block, the write() syscall is
            # interrupted, signal handler is called, and next write()
            # can succeed.
            file.write("hello")
        finally:
            alarm(0)
            signal(SIGALRM, SIG_DFL)

    def test_append_mode(self):
        tfn = str(udir.join('streamio-append-mode'))
        fo = streamio.open_file_as_stream # shorthand
        x = fo(tfn, 'w')
        x.write('abc123')
        x.close()

        x = fo(tfn, 'a')
        x.seek(0, 0)
        x.write('456')
        x.close()
        x = fo(tfn, 'r')
        assert x.read() == 'abc123456'
        x.close()

    def test_seek_changed_underlying_position(self):
        tfn = str(udir.join('seek_changed_underlying_position'))
        fo = streamio.open_file_as_stream # shorthand
        x = fo(tfn, 'w')
        x.write('abc123')
        x.close()

        x = fo(tfn, 'r')
        fd = x.try_to_find_file_descriptor()
        assert fd >= 0
        got = x.read(1)
        assert got == 'a'
        assert x.tell() == 1
        os.lseek(fd, 0, 0)
        assert x.tell() == 0    # detected in this case.  not always.
        # the point of the test is that we don't crash in an assert.

    def test_ignore_ioerror_in_readall_if_nonempty_result(self):
        # this is the behavior of regular files in CPython 2.7, as
        # well as of _io.FileIO at least in CPython 3.3.  This is
        # *not* the behavior of _io.FileIO in CPython 3.4 or 3.5;
        # see CPython's issue #21090.
        try:
            from os import openpty
        except ImportError:
            pytest.skip('no openpty on this platform')
        read_fd, write_fd = openpty()
        os.write(write_fd, 'Abc\n')
        os.close(write_fd)
        x = streamio.DiskFile(read_fd)
        s = x.readall()
        assert s == 'Abc\r\n'
        pytest.raises(OSError, x.readall)
        x.close()


# Speed test

FN = "BIG"

def timeit(fn=FN, opener=streamio.MMapFile):
    f = opener(fn, "r")
    lines = bytes = 0
    t0 = time.clock()
    for line in iter(f.readline, ""):
        lines += 1
        bytes += len(line)
    t1 = time.clock()
    print "%d lines (%d bytes) in %.3f seconds for %s" % (
        lines, bytes, t1-t0, opener.__name__)

def speed_main():
    def diskopen(fn, mode):
        filemode = 0
        if "r" in mode:
            filemode = os.O_RDONLY
        if "w" in mode:
            filemode |= os.O_WRONLY
        fd = os.open(fn, filemode)
        base = streamio.DiskFile(fd)
        return streamio.BufferingInputStream(base)

    def mmapopen(fn, mode):
        mmapmode = 0
        filemode = 0
        import mmap
        if "r" in mode:
            mmapmode = mmap.ACCESS_READ
            filemode = os.O_RDONLY
        if "w" in mode:
            mmapmode |= mmap.ACCESS_WRITE
            filemode |= os.O_WRONLY
        fd = os.open(fn, filemode)
        return streamio.MMapFile(fd, mmapmode)

    timeit(opener=diskopen)
    timeit(opener=mmapopen)
    timeit(opener=open)
