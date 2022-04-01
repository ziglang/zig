from __future__ import with_statement
from rpython.tool.udir import udir
import os, sys, py

class AppTestMMap:
    spaceconfig = dict(usemodules=('mmap',))

    def setup_class(cls):
        cls.w_tmpname = cls.space.wrap(str(udir.join('mmap-')))

    def setup_method(self, meth):
        if getattr(meth, 'is_large', False):
            if sys.maxsize < 2**32 and not self.runappdirect:
                # this fails because it uses ll2ctypes to call the posix
                # functions like 'open' and 'lseek', whereas a real compiled
                # C program would macro-define them to their longlong versions
                py.test.skip("emulation of files can't use "
                             "larger-than-long offsets")

    def test_page_size(self):
        import mmap
        assert mmap.PAGESIZE > 0
        assert mmap.ALLOCATIONGRANULARITY > 0
        assert isinstance(mmap.PAGESIZE, int)
        assert isinstance(mmap.ALLOCATIONGRANULARITY, int)
        assert mmap.ALLOCATIONGRANULARITY % mmap.PAGESIZE == 0

    def test_attributes(self):
        import mmap
        import os
        assert isinstance(mmap.ACCESS_READ, int)
        assert isinstance(mmap.ACCESS_WRITE, int)
        assert isinstance(mmap.ACCESS_COPY, int)
        assert isinstance(mmap.ACCESS_DEFAULT, int)
        if os.name == "posix":
            assert isinstance(mmap.MAP_ANON, int)
            assert isinstance(mmap.MAP_ANONYMOUS, int)
            assert isinstance(mmap.MAP_PRIVATE, int)
            assert isinstance(mmap.MAP_SHARED, int)
            assert isinstance(mmap.PROT_EXEC, int)
            assert isinstance(mmap.PROT_READ, int)
            assert isinstance(mmap.PROT_WRITE, int)

        assert mmap.error is OSError

    def test_args(self):
        from mmap import mmap
        import os
        import sys

        raises(TypeError, mmap, "foo")
        raises(TypeError, mmap, 0, "foo")

        if os.name == "posix":
            raises(ValueError, mmap, 0, 1, 2, 3, 4)
            raises(TypeError, mmap, 0, 1, 2, 3, "foo", 5)
            raises(TypeError, mmap, 0, 1, foo="foo")
            raises((TypeError, OverflowError), mmap, 0, -1)
            raises(OverflowError, mmap, 0, sys.maxsize ** 3)
            raises(ValueError, mmap, 0, 1, flags=2, access=3)
            raises(ValueError, mmap, 0, 1, access=123)
        elif os.name == "nt":
            raises(TypeError, mmap, 0, 1, 2, 3, 4)
            raises(TypeError, mmap, 0, 1, tagname=123)
            raises(TypeError, mmap, 0, 1, access="foo")
            raises(ValueError, mmap, 0, 1, access=-1)

    def test_subclass(self):
        import mmap
        class anon_mmap(mmap.mmap):
            def __new__(klass, *args, **kwargs):
                return mmap.mmap.__new__(klass, -1, *args, **kwargs)
        anon_mmap(mmap.PAGESIZE)

    def test_file_size(self):
        import os
        if os.name == "nt":
            skip("Only Unix checks file size")

        from mmap import mmap
        f = open(self.tmpname + "a", "wb+")

        f.write(b"c")
        ret = f.flush()
        assert ret is None
        raises(ValueError, mmap, f.fileno(), 123)
        f.close()

    def test_create(self):
        from mmap import mmap
        f = open(self.tmpname + "b", "wb+")

        f.write(b"c")
        f.flush()
        m = mmap(f.fileno(), 1)
        assert m.read(99) == b"c"

        f.close()

    def test_close(self):
        from mmap import mmap
        f = open(self.tmpname + "c", "wb+")

        f.write(b"c")
        f.flush()
        m = mmap(f.fileno(), 1)
        m.close()
        raises(ValueError, m.read, 1)

    def test_read_byte(self):
        from mmap import mmap
        f = open(self.tmpname + "d", "wb+")

        f.write(b"c")
        f.flush()
        m = mmap(f.fileno(), 1)
        assert m.read_byte() == ord(b"c")
        raises(ValueError, m.read_byte)
        m.close()
        f.close()

    def test_readline(self):
        from mmap import mmap
        import os
        with open(self.tmpname + "e", "wb+") as f:
            f.write(b"foo\n")
            f.flush()
            with mmap(f.fileno(), 4) as m:
                result = m.readline()
                assert result == b"foo\n"
                assert m.readline() == b""

    def test_read(self):
        from mmap import mmap
        f = open(self.tmpname + "f", "wb+")

        f.write(b"foobar")
        f.flush()
        m = mmap(f.fileno(), 6)
        raises(TypeError, m.read, b"foo")
        assert m.read(1) == b"f"
        assert m.read(6) == b"oobar"
        assert m.read(1) == b""
        m.close()
        f.close()

    def test_find(self):
        from mmap import mmap
        f = open(self.tmpname + "g", "wb+")

        f.write(b"foobar\0")
        f.flush()
        m = mmap(f.fileno(), 7)
        raises(TypeError, m.find, 123)
        raises(TypeError, m.find, b"foo", b"baz")
        assert m.find(b"b") == 3
        assert m.find(b"z") == -1
        assert m.find(b"o", 5) == -1
        assert m.find(b"ob") == 2
        assert m.find(b"\0") == 6
        assert m.find(b"ob", 1) == 2
        assert m.find(b"ob", 2) == 2
        assert m.find(b"ob", 3) == -1
        assert m.find(b"ob", -4) == -1
        assert m.find(b"ob", -5) == 2
        assert m.find(b"ob", -999999999) == 2
        assert m.find(b"ob", 1, 3) == -1
        assert m.find(b"ob", 1, 4) == 2
        assert m.find(b"ob", 1, 999999999) == 2
        assert m.find(b"ob", 1, 0) == -1
        assert m.find(b"ob", 1, -1) == 2
        assert m.find(b"ob", 1, -3) == 2
        assert m.find(b"ob", 1, -4) == -1
        #
        data = m.read(2)
        assert data == b"fo"
        assert m.find(b"o") == 2
        assert m.find(b"oo") == -1
        assert m.find(b"o", 0) == 1
        m.close()
        f.close()

    def test_rfind(self):
        from mmap import mmap
        f = open(self.tmpname + "g", "wb+")

        f.write(b"foobarfoobar\0")
        f.flush()
        m = mmap(f.fileno(), 13)
        raises(TypeError, m.rfind, 123)
        raises(TypeError, m.rfind, b"foo", b"baz")
        assert m.rfind(b"b") == 9
        assert m.rfind(b"z") == -1
        assert m.rfind(b"o", 11) == -1
        assert m.rfind(b"ob") == 8
        assert m.rfind(b"\0") == 12
        assert m.rfind(b"ob", 7) == 8
        assert m.rfind(b"ob", 8) == 8
        assert m.rfind(b"ob", 9) == -1
        assert m.rfind(b"ob", -4) == -1
        assert m.rfind(b"ob", -5) == 8
        assert m.rfind(b"ob", -999999999) == 8
        assert m.rfind(b"ob", 1, 3) == -1
        assert m.rfind(b"ob", 1, 4) == 2
        assert m.rfind(b"ob", 1, 999999999) == 8
        assert m.rfind(b"ob", 1, 0) == -1
        assert m.rfind(b"ob", 1, -1) == 8
        assert m.rfind(b"ob", 1, -3) == 8
        assert m.rfind(b"ob", 1, -4) == 2
        #
        data = m.read(8)
        assert data == b"foobarfo"
        assert m.rfind(b"o") == 8
        assert m.rfind(b"oo") == -1
        assert m.rfind(b"o", 0) == 8
        m.close()
        f.close()

    def test_is_modifiable(self):
        import mmap
        f = open(self.tmpname + "h", "wb+")

        f.write(b"foobar")
        f.flush()
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_READ)
        raises(TypeError, m.write, b'x')
        raises(TypeError, m.resize, 7)
        m.close()
        f.close()

    def test_seek(self):
        from mmap import mmap
        f = open(self.tmpname + "i", "wb+")

        f.write(b"foobar")
        f.flush()
        m = mmap(f.fileno(), 6)
        raises(TypeError, m.seek, b"foo")
        raises(TypeError, m.seek, 0, b"foo")
        raises(ValueError, m.seek, -1, 0)
        raises(ValueError, m.seek, -1, 1)
        raises(ValueError, m.seek, -7, 2)
        raises(ValueError, m.seek, 1, 3)
        raises(ValueError, m.seek, 10)
        m.seek(0)
        assert m.tell() == 0
        m.read(1)
        m.seek(1, 1)
        assert m.tell() == 2
        m.seek(0)
        m.seek(-1, 2)
        assert m.tell() == 5
        m.close()
        f.close()

    def test_write(self):
        import mmap
        f = open(self.tmpname + "j", "wb+")

        f.write(b"foobar")
        f.flush()
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_READ)
        raises(TypeError, m.write, b"foo")
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_WRITE)
        raises(TypeError, m.write, 123)
        raises(ValueError, m.write, b"c"*10)
        assert m.write(b"ciao\n") == 5
        m.seek(0)
        assert m.read(6) == b"ciao\nr"
        m.close()

    def test_write_byte(self):
        import mmap
        f = open(self.tmpname + "k", "wb+")

        f.write(b"foobar")
        f.flush()
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_READ)
        raises(TypeError, m.write_byte, b"f")
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_WRITE)
        raises(TypeError, m.write_byte, "a")
        raises(TypeError, m.write_byte, b"a")
        m.write_byte(ord("x"))
        m.seek(0)
        assert m.read(6) == b"xoobar"
        m.close()

    def test_size(self):
        from mmap import mmap
        f = open(self.tmpname + "l", "wb+")

        f.write(b"foobar")
        f.flush()
        m = mmap(f.fileno(), 5)
        assert m.size() == 6 # size of the underline file, not the mmap
        m.close()
        f.close()

    def test_tell(self):
        from mmap import mmap
        f = open(self.tmpname + "m", "wb+")

        f.write(b"c")
        f.flush()
        m = mmap(f.fileno(), 1)
        assert m.tell() >= 0
        m.close()
        f.close()

    def test_flush(self):
        from mmap import mmap
        f = open(self.tmpname + "n", "wb+")

        f.write(b"foobar")
        f.flush()
        m = mmap(f.fileno(), 6)
        raises(TypeError, m.flush, 1, 2, 3)
        raises(TypeError, m.flush, 1, b"a")
        raises(ValueError, m.flush, 0, 99)
        m.flush()    # return value is a bit meaningless, platform-dependent
        m.close()
        f.close()

    def test_length_0_large_offset(self):
        import mmap

        with open(self.tmpname, "wb") as f:
            f.write(115699 * b'm')
        with open(self.tmpname, "w+b") as f:
            raises(ValueError, mmap.mmap, f.fileno(), 0, offset=2147418112)

    def test_move(self):
        import mmap
        f = open(self.tmpname + "o", "wb+")

        f.write(b"foobar")
        f.flush()
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_READ)
        raises(TypeError, m.move, 1)
        raises(TypeError, m.move, 1, b"foo", 2)
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_WRITE)
        raises(ValueError, m.move, 7, 1, 2)
        raises(ValueError, m.move, 1, 7, 2)
        m.move(1, 3, 3)
        assert m.read(6) == b"fbarar"
        m.seek(0)
        m.move(1, 3, 2)
        a = m.read(6)
        assert a == b"frarar"
        m.close()
        f.close()

    def test_resize(self):
        import sys
        if ("darwin" in sys.platform) or ("freebsd" in sys.platform):
            skip("resize does not work under OSX or FreeBSD")

        import mmap
        import os

        f = open(self.tmpname + "p", "wb+")
        f.write(b"foobar")
        f.flush()
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_READ)
        raises(TypeError, m.resize, 1)
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_COPY)
        raises(TypeError, m.resize, 1)
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_WRITE)
        f_size = os.fstat(f.fileno()).st_size
        assert m.size() == f_size == 6
        m.resize(10)
        f_size = os.fstat(f.fileno()).st_size
        assert m.size() == f_size == 10
        m.close()
        f.close()

    def test_resize_bsd(self):
        import sys
        if ("darwin" not in sys.platform) and ("freebsd" not in sys.platform):
            skip("resize works under not OSX or FreeBSD")

        import mmap
        import os

        f = open(self.tmpname + "p", "wb+")
        f.write(b"foobar")
        f.flush()
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_READ)
        raises(TypeError, m.resize, 1)
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_COPY)
        raises(TypeError, m.resize, 1)
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_WRITE)
        f_size = os.fstat(f.fileno()).st_size
        assert m.size() == f_size == 6
        raises(SystemError, m.resize, 10)
        f_size = os.fstat(f.fileno()).st_size
        assert m.size() == f_size == 6

    def test_len(self):
        from mmap import mmap

        f = open(self.tmpname + "q", "wb+")
        f.write(b"foobar")
        f.flush()

        m = mmap(f.fileno(), 6)
        assert len(m) == 6
        m.close()
        f.close()

    def test_get_item(self):
        from mmap import mmap

        f = open(self.tmpname + "r", "wb+")
        f.write(b"foobar")
        f.flush()

        m = mmap(f.fileno(), 6)
        fn = lambda: m[b"foo"]
        raises(TypeError, fn)
        fn = lambda: m[-7]
        raises(IndexError, fn)
        assert m[0] == ord('f')
        assert m[-1] == ord('r')
        assert m[1::2] == b'obr'
        assert m[4:1:-2] == b'ao'
        m.close()
        f.close()

    def test_get_crash(self):
        import sys
        from mmap import mmap
        s = b'hallo!!!'
        m = mmap(-1, len(s))
        m[:] = s
        assert m[1:None:sys.maxsize] == b'a'
        m.close()

    def test_set_item(self):
        import mmap

        f = open(self.tmpname + "s", "wb+")
        f.write(b"foobar")
        f.flush()

        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_READ)
        def fn(): m[1] = b'a'
        raises(TypeError, fn)
        m = mmap.mmap(f.fileno(), 6, access=mmap.ACCESS_WRITE)
        def fn(): m[b"foo"] = b'a'
        raises(TypeError, fn)
        def fn(): m[-7] = b'a'
        raises(IndexError, fn)
        def fn(): m[1:3] = 'xx'
        raises((IndexError, TypeError), fn)      # IndexError is in CPython,
                                                 # but doesn't make much sense
        def fn(): m[1:4] = b"zz"
        raises((IndexError, ValueError), fn)
        def fn(): m[1:6] = b"z" * 6
        raises((IndexError, ValueError), fn)
        def fn(): m[:2] = b"z" * 5
        raises((IndexError, ValueError), fn)
        def fn(): m[0] = 256
        raises(ValueError, fn)
        m[1:3] = b'xx'
        assert m.read(6) == b"fxxbar"
        m[0] = ord('x')
        assert m[0] == ord('x')
        m[-6] = ord('y')
        m[3:6:2] = b'BR'
        m.seek(0)
        data = m.read(6)
        assert data == b"yxxBaR"
        m.close()
        f.close()

    def test_del_item(self):
        from mmap import mmap

        f = open(self.tmpname + "t", "wb+")
        f.write(b"foobar")
        f.flush()

        m = mmap(f.fileno(), 6)
        def fn(): del m[b"foo"]
        raises(TypeError, fn)
        def fn(): del m[1:3]
        raises(TypeError, fn)
        def fn(): del m[1]
        raises(TypeError, fn)
        m.close()
        f.close()

    def test_concatenation(self):
        from mmap import mmap

        f = open(self.tmpname + "u", "wb+")
        f.write(b"foobar")
        f.flush()

        m = mmap(f.fileno(), 6)
        def fn(): m + 1
        raises((SystemError, TypeError), fn)     # SystemError is in CPython,
        def fn(m): m += 1                        # but it doesn't make much
        raises((SystemError, TypeError), fn, m)  # sense
        def fn(): 1 + m
        raises(TypeError, fn)
        m.close()
        f.close()

    def test_repeatition(self):
        from mmap import mmap

        f = open(self.tmpname + "v", "wb+")
        f.write(b"foobar")
        f.flush()

        m = mmap(f.fileno(), 6)
        def fn(): m * 1
        raises((SystemError, TypeError), fn)      # SystemError is in CPython,
        def fn(m): m *= 1                         # but it
        raises((SystemError, TypeError), fn, m)   # doesn't
        def fn(): 1 * m                           # make much sense
        raises((SystemError, TypeError), fn)
        m.close()
        f.close()

    def test_slicing(self):
        from mmap import mmap

        f = open(self.tmpname + "v", "wb+")
        f.write(b"foobar")
        f.flush()

        f.seek(0)
        m = mmap(f.fileno(), 6)
        assert m[-3:7] == b"bar"

        assert m[1:0:1] == b""

        f.close()

    def test_memoryview(self):
        from mmap import mmap
        filename = self.tmpname + "y"
        with open(filename, "bw+") as f:
            f.write(b"foobar")
            f.flush()
            with mmap(f.fileno(), 6) as m:
                b = memoryview(m)
                assert len(b) == 6
                assert b.readonly is False
                assert b[3] == ord(b"b")
                assert b[:] == b"foobar"
                del b  # For CPython: "exported pointers exist"
        try:
            from mmap import PROT_READ
        except ImportError:
            skip('no PROT_READ') 
        with open(filename, "rb") as f:
            m = mmap(f.fileno(), 6, prot=PROT_READ)
            b = memoryview(m)
            assert b.readonly is True
            assert b[:] == b"foobar"
            del b
            m.close()

    def test_offset(self):
        from mmap import mmap, ALLOCATIONGRANULARITY
        filename = self.tmpname + "y"
        with open(filename, "wb+") as f:
            f.write(b"foobar" * ALLOCATIONGRANULARITY)
            f.flush()
            size = ALLOCATIONGRANULARITY
            offset = 2 * ALLOCATIONGRANULARITY
            m = mmap(f.fileno(), size, offset=offset)
            assert m[:] == (b"foobar" * ALLOCATIONGRANULARITY)[offset:offset+size]
            assert len(m) == size
            m.close()

    def test_offset_more(self):
        from mmap import mmap, ALLOCATIONGRANULARITY

        with open(self.tmpname, "w+b") as f:
            halfsize = ALLOCATIONGRANULARITY
            f.write(b"\0" * halfsize)
            f.write(b"foo")
            f.write(b"\0" * (halfsize - 3))
            m = mmap(f.fileno(), 0)
            m.close()

        with open(self.tmpname, "r+b") as f:
            m = mmap(f.fileno(), halfsize, offset=halfsize)
            assert m[0:3] == b"foo"

        try:
            m.resize(512)
        except SystemError:
            pass
        else:
            assert len(m) == 512
            raises(ValueError, m.seek, 513, 0)
            assert m[0:3] == b"foo"
            with open(self.tmpname) as f:
                f.seek(0, 2)
                assert f.tell() == halfsize + 512
            assert m.size() == halfsize + 512
        m.close()

    def test_large_offset(self):
        import mmap
        import sys
        size = 0x14FFFFFFF
        if sys.platform.startswith('win') or sys.platform == 'darwin':
            skip('test requires %s bytes and a long time to run' % size)

        with open(self.tmpname, "w+b") as f:
            f.seek(size)
            f.write(b"A")
            f.flush()
        with open(self.tmpname, 'rb') as f2:
            f2.seek(size)
            c = f2.read(1)
            assert c == b'A'
            m = mmap.mmap(f2.fileno(), 0, offset=0x140000000,
                          access=mmap.ACCESS_READ)
            try:
                assert m[0xFFFFFFF] == ord('A')
            finally:
                m.close()
    test_large_offset.is_large = True

    def test_large_filesize(self):
        import mmap
        import sys
        size = 0x17FFFFFFF
        if sys.platform.startswith('win') or sys.platform == 'darwin':
            skip('test requires %s bytes and a long time to run' % size)

        with open(self.tmpname, "w+b") as f:
            f.seek(size)
            f.write(b" ")
            f.flush()
            m = mmap.mmap(f.fileno(), 0x10000, access=mmap.ACCESS_READ)
            try:
                assert m.size() ==  0x180000000
            finally:
                m.close()
    test_large_filesize.is_large = True

    def test_context_manager(self):
        import mmap
        with mmap.mmap(-1, 10) as m:
            assert not m.closed
        assert m.closed

    def test_all(self):
        # this is a global test, ported from test_mmap.py
        import mmap
        from mmap import PAGESIZE
        import sys
        import os

        filename = self.tmpname + "w"

        f = open(filename, "wb+")

        # write 2 pages worth of data to the file
        f.write(b'\0' * PAGESIZE)
        f.write(b'foo')
        f.write(b'\0' * (PAGESIZE - 3))
        f.flush()
        m = mmap.mmap(f.fileno(), 2 * PAGESIZE)
        f.close()

        # sanity checks
        assert m.find(b"foo") == PAGESIZE
        assert len(m) == 2 * PAGESIZE
        assert m[0] == 0
        assert m[0:3] == b'\0\0\0'

        # modify the file's content
        m[0] = ord('3')
        m[PAGESIZE+3:PAGESIZE+3+3] = b'bar'

        # check that the modification worked
        assert m[0] == ord('3')
        assert m[0:3] == b'3\0\0'
        assert m[PAGESIZE-1:PAGESIZE+7] == b'\0foobar\0'

        m.flush()

        # test seeking around
        m.seek(0,0)
        assert m.tell() == 0
        m.seek(42, 1)
        assert m.tell() == 42
        m.seek(0, 2)
        assert m.tell() == len(m)

        raises(ValueError, m.seek, -1)
        raises(ValueError, m.seek, 1, 2)
        raises(ValueError, m.seek, -len(m) - 1, 2)

        # try resizing map
        if not (("darwin" in sys.platform) or ("freebsd" in sys.platform)):
            m.resize(512)

            assert len(m) == 512
            raises(ValueError, m.seek, 513, 0)

            # check that the underlying file is truncated too
            f = open(filename)
            f.seek(0, 2)
            assert f.tell() == 512
            f.close()
            assert m.size() == 512

        m.close()
        f.close()

        # test access=ACCESS_READ
        mapsize = 10
        f = open(filename, "wb")
        f.write(b"a" * mapsize)
        f.close()
        f = open(filename, "rb")
        m = mmap.mmap(f.fileno(), mapsize, access=mmap.ACCESS_READ)
        assert m[:] == b'a' * mapsize
        def f(m): m[:] = b'b' * mapsize
        raises(TypeError, f, m)
        def fn(): m[0] = b'b'
        raises(TypeError, fn)
        def fn(m): m.seek(0, 0); m.write(b"abc")
        raises(TypeError, fn, m)
        def fn(m): m.seek(0, 0); m.write_byte(b"d")
        raises(TypeError, fn, m)
        if not (("darwin" in sys.platform) or ("freebsd" in sys.platform)):
            raises(TypeError, m.resize, 2 * mapsize)
            assert open(filename, "rb").read() == b'a' * mapsize

        # opening with size too big
        f = open(filename, "r+b")
        if not os.name == "nt":
            # this should work under windows
            raises(ValueError, mmap.mmap, f.fileno(), mapsize + 1)
        f.close()

        # if _MS_WINDOWS:
        #     # repair damage from the resizing test.
        #     f = open(filename, 'r+b')
        #     f.truncate(mapsize)
        #     f.close()
        m.close()

        # test access=ACCESS_WRITE"
        f = open(filename, "r+b")
        m = mmap.mmap(f.fileno(), mapsize, access=mmap.ACCESS_WRITE)
        m.write(b'c' * mapsize)
        m.seek(0)
        data = m.read(mapsize)
        assert data == b'c' * mapsize
        m.flush()
        m.close()
        f.close()
        f = open(filename, 'rb')
        stuff = f.read()
        f.close()
        assert stuff == b'c' * mapsize

        # test access=ACCESS_COPY
        f = open(filename, "r+b")
        m = mmap.mmap(f.fileno(), mapsize, access=mmap.ACCESS_COPY)
        m.write(b'd' * mapsize)
        m.seek(0)
        data = m.read(mapsize)
        assert data == b'd' * mapsize
        m.flush()
        assert open(filename, "rb").read() == b'c' * mapsize
        if not (("darwin" in sys.platform) or ("freebsd" in sys.platform)):
            raises(TypeError, m.resize, 2 * mapsize)
        m.close()
        f.close()

        # test invalid access
        f = open(filename, "r+b")
        raises(ValueError, mmap.mmap, f.fileno(), mapsize, access=4)
        f.close()

        # test incompatible parameters
        if os.name == "posix":
            f = open(filename, "r+b")
            raises(ValueError, mmap.mmap, f.fileno(), mapsize, flags=mmap.MAP_PRIVATE,
                prot=mmap.PROT_READ, access=mmap.ACCESS_WRITE)
            f.close()


        # bad file descriptor
        raises(EnvironmentError, mmap.mmap, -2, 4096)

        # do a tougher .find() test.  SF bug 515943 pointed out that, in 2.2,
        # searching for data with embedded \0 bytes didn't work.
        f = open(filename, 'wb+')
        data = b'aabaac\x00deef\x00\x00aa\x00'
        n = len(data)
        f.write(data)
        f.flush()
        m = mmap.mmap(f.fileno(), n)
        f.close()

        for start in range(n + 1):
            for finish in range(start, n + 1):
                sl = data[start:finish]
                assert m.find(sl) == data.find(sl)
                assert m.find(sl + b'x') ==  -1
        m.close()

        # test mapping of entire file by passing 0 for map length
        f = open(filename, "wb+")
        f.write(2**16 * b'm')
        f.close()
        f = open(filename, "rb+")
        m = mmap.mmap(f.fileno(), 0)
        assert len(m) == 2**16
        assert m.read(2**16) == 2**16 * b"m"
        m.close()
        f.close()

        # make move works everywhere (64-bit format problem earlier)
        f = open(filename, 'wb+')
        f.write(b"ABCDEabcde")
        f.flush()
        m = mmap.mmap(f.fileno(), 10)
        m.move(5, 0, 5)
        assert m.read(10) == b"ABCDEABCDE"
        m.close()
        f.close()

    def test_empty_file(self):
        import mmap
        f = open(self.tmpname, 'w+b')
        f.close()
        with open(self.tmpname, 'rb') as f:
            try:
                m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
                m.close()
                assert False, "should not have been able to mmap empty file"
            except ValueError as e:
                assert str(e) == "cannot mmap an empty file"
            except BaseException as e:
                assert False, "unexpected exception: " + str(e)

    def test_read_all(self):
        from mmap import mmap
        f = open(self.tmpname + "f", "wb+")
        f.write(b"foobar")
        f.flush()

        m = mmap(f.fileno(), 6)
        assert m.read(None) == b"foobar"

    def test_resize_past_pos(self):
        import os, mmap, sys
        if os.name == "nt":
            skip("cannot resize anonymous mmaps on Windows")
        if sys.version_info < (2, 7, 13):
            skip("cannot resize anonymous mmaps before 2.7.13")
        m = mmap.mmap(-1, 8192)
        m.read(5000)
        try:
            m.resize(4096)
        except SystemError:
            skip("resizing not supported")
        assert m.tell() == 5000
        assert m.read(14) == b''
        assert m.read(-1) == b''
        raises(ValueError, m.read_byte)
        assert m.readline() == b''
        raises(ValueError, m.write_byte, ord(b'b'))
        raises(ValueError, m.write, b'abc')
        assert m.tell() == 5000
        m.close()

    def test_iter_yields_bytes(self):
        # issue 3282: inconsistency in Python 3
        from mmap import mmap
        f = open(self.tmpname + "iter", "wb+")
        f.write(b"AB")
        f.flush()

        m = mmap(f.fileno(), 2)
        assert [m[0], m[1]] == [65, 66]
        assert list(m) == [b"A", b"B"]
        assert list(iter(m)) == [b"A", b"B"]
        assert list(reversed(m)) == [b"B", b"A"]
        assert list(enumerate(m)) == [(0, b"A"), (1, b"B")]

    def test_madvise(self):
        import mmap, sys
        m = mmap.mmap(-1, 1024)
        if not hasattr(m, "madvise"):
            m.close()
            skip("no madvise")

        m.madvise(mmap.MADV_NORMAL)
        m.close()

    def test_repr(self):
        import mmap
        m = mmap.mmap(-1, 1024)
        assert repr(m) == "<mmap.mmap closed=False, access=ACCESS_DEFAULT, length=1024, pos=0, offset=0>"
        m.close()
        assert repr(m) == "<mmap.mmap closed=True>"
