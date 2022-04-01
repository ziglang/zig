from rpython.tool.udir import udir
import os, sys, py
from rpython.rtyper.test.test_llinterp import interpret
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rarithmetic import intmask
from rpython.rlib import rmmap as mmap
from rpython.rlib.rmmap import RTypeError, RValueError, alloc, free
from rpython.rlib.rmmap import madvise_free


class TestMMap:
    def setup_class(cls):
        cls.tmpname = str(udir.join('mmap-'))
    
    def test_page_size(self):
        def f():
            assert mmap.PAGESIZE > 0
            assert isinstance(mmap.PAGESIZE, int)

        interpret(f, [])
    
    def test_attributes(self):
        def f():
            assert isinstance(mmap.ACCESS_READ, int)
            assert isinstance(mmap.ACCESS_WRITE, int)
            assert isinstance(mmap.ACCESS_COPY, int)
            if os.name == "posix":
                assert isinstance(mmap.MAP_ANON, int)
                assert isinstance(mmap.MAP_ANONYMOUS, int)
                assert isinstance(mmap.MAP_PRIVATE, int)
                assert isinstance(mmap.MAP_SHARED, int)
                assert isinstance(mmap.PROT_EXEC, int)
                assert isinstance(mmap.PROT_READ, int)
                assert isinstance(mmap.PROT_WRITE, int)

        interpret(f, [])

    def test_file_size(self):
        def func(no):

            try:
                mmap.mmap(no, 123)
            except RValueError:
                pass
            else:
                raise Exception("didn't raise")

        f = open(self.tmpname + "a", "w+")
        
        f.write("c")
        f.flush()

        interpret(func, [f.fileno()])
        f.close()

    def test_create(self):
        f = open(self.tmpname + "b", "w+")
        
        f.write("c")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 1)
            assert m.read(99) == "c"

        interpret(func, [f.fileno()])
        
        f.close()

    @py.test.mark.skipif("os.name != 'posix'")
    def test_unmap_range(self):
        f = open(self.tmpname + "-unmap-range", "w+")
        left, right, size = 100, 200, 500  # in pages

        f.write(size*4096*"c")
        f.flush()

        def func(no):
            m = mmap.mmap(no, size*4096)
            m.unmap_range(left*4096, (right-left)*4096)
            m.read(1)
            m.seek(right*4096)
            m.read(1)

            def in_map(m, offset):
                return rffi.ptradd(m.data, offset)
            def as_num(ptr):
                return rffi.cast(lltype.Unsigned, ptr)
            res = mmap.alloc_hinted(in_map(m, (left+right)/2 * 4096), 4096)
            assert as_num(in_map(m, left*4096)) <= as_num(res) < as_num(in_map(m, right*4096))
        interpret(func, [f.fileno()])
        f.close()

    def test_close(self):
        f = open(self.tmpname + "c", "w+")
        
        f.write("c")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 1)
            m.close()
            try:
                m.check_valid()
            except RValueError:
                pass
            else:
                raise Exception("Did not raise")
        interpret(func, [f.fileno()])
        f.close()

    def test_read_byte(self):
        f = open(self.tmpname + "d", "w+")

        f.write("c")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 1)
            assert m.read_byte() == "c"
            try:
                m.read_byte()
            except RValueError:
                pass
            else:
                raise Exception("Did not raise")
            m.close()
        interpret(func, [f.fileno()])
        f.close()

    def test_readline(self):
        import os
        f = open(self.tmpname + "e", "w+")

        f.write("foo\n")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 4)
            if os.name == "nt":
                # windows replaces \n with \r. it's time to change to \n only MS!
                assert m.readline() == "foo\r"
            elif os.name == "posix":
                assert m.readline() == "foo\n"
            assert m.readline() == ""
            m.close()

        interpret(func, [f.fileno()])
        f.close()

    def test_read(self):
        f = open(self.tmpname + "f", "w+")
        
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6)
            assert m.read(1) == "f"
            assert m.read(6) == "oobar"
            assert m.read(1) == ""
            m.close()

        interpret(func, [f.fileno()])
        f.close()

    def test_find_rfind(self):
        f = open(self.tmpname + "g", "w+")
        f.write("foobarfoobar\0")
        f.flush()
        m = mmap.mmap(f.fileno(), 13)

        for s1 in range(-20, 20):
            for e1 in range(-20, 20):
                expected = "foobarfoobar\0".find("ob", s1, e1)
                assert m.find("ob", s1, e1, False) == expected
                expected = "foobarfoobar\0".rfind("ob", s1, e1)
                assert m.find("ob", s1, e1, True) == expected

        m.close()
        f.close()

    def test_find(self):
        f = open(self.tmpname + "g", "w+")
        f.write("foobarfoobar\0")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 12)
            assert m.find("\0", 0, 13) == -1    # no searching past the stop
            assert m.find("\0", 0, 13, True) == -1
            m.close()
            #
            m = mmap.mmap(no, 13)
            assert m.find("b", 0, 7) == 3
            assert m.find("z", 0, 7) == -1
            assert m.find("o", 11, 13) == -1
            assert m.find("ob", 0, 7) == 2
            assert m.find("\0", 0, 13) == 12
            assert m.find("o", 1, 4) == 1
            assert m.find("o", 2, 4) == 2
            assert m.find("o", 2, -4) == 2
            assert m.find("o", 8, -5) == -1
            m.close()

        func(f.fileno())
        interpret(func, [f.fileno()])
        f.close()

    def test_is_modifiable(self):
        f = open(self.tmpname + "h", "w+")
        
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6, access=mmap.ACCESS_READ)
            try:
                m.check_writeable()
            except RTypeError:
                pass
            else:
                assert False
            try:
                m.check_resizeable()
            except RTypeError:
                pass
            else:
                assert False
            m.close()
        interpret(func, [f.fileno()])
        f.close()

    def test_seek(self):
        f = open(self.tmpname + "i", "w+")
        
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6)
            m.seek(0)
            assert m.tell() == 0
            m.read(1)
            m.seek(1, 1)
            assert m.tell() == 2
            m.seek(0)
            m.seek(-1, 2)
            assert m.tell() == 5
            m.close()
        interpret(func, [f.fileno()])
        f.close()

    def test_write(self):
        f = open(self.tmpname + "j", "w+")

        f.write("foobar")
        f.flush()
        def func(no):
            m = mmap.mmap(no, 6, access=mmap.ACCESS_WRITE)
            assert m.write("ciao\n") == 5
            m.seek(0)
            assert m.read(6) == "ciao\nr"
            m.close()
        interpret(func, [f.fileno()])
        f.close()

    def test_write_byte(self):
        f = open(self.tmpname + "k", "w+")
        
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6, access=mmap.ACCESS_READ)
            m = mmap.mmap(no, 6, access=mmap.ACCESS_WRITE)
            m.write_byte("x")
            m.seek(0)
            assert m.read(6) == "xoobar"
            m.close()
        interpret(func, [f.fileno()])
        f.close()

    def test_write_readonly(self):
        if os.name == "nt":
            py.test.skip("Needs PROT_READ")
        f = open(self.tmpname + "l", "w+")
        f.write("foobar")
        f.flush()
        m = mmap.mmap(f.fileno(), 6, prot=mmap.PROT_READ)
        py.test.raises(RTypeError, m.check_writeable)
        m.close()
        f.close()

    def test_write_without_protwrite(self):
        if os.name == "nt":
            py.test.skip("Needs PROT_WRITE")
        f = open(self.tmpname + "l2", "w+")
        f.write("foobar")
        f.flush()
        m = mmap.mmap(f.fileno(), 6, prot=mmap.PROT_READ|mmap.PROT_EXEC)
        py.test.raises(RTypeError, m.check_writeable)
        py.test.raises(RTypeError, m.check_writeable)
        m.close()
        f.close()

    def test_size(self):
        f = open(self.tmpname + "l3", "w+")
        
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 5)
            assert m.file_size() == 6 # size of the underline file, not the mmap
            m.close()

        interpret(func, [f.fileno()])
        f.close()

    def test_tell(self):
        f = open(self.tmpname + "m", "w+")
        
        f.write("c")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 1)
            assert m.tell() >= 0
            m.close()

        interpret(func, [f.fileno()])
        f.close()

    def test_move(self):
        f = open(self.tmpname + "o", "w+")
        
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6, access=mmap.ACCESS_WRITE)
            m.move(1, 3, 3)
            assert m.read(6) == "fbarar"
            m.seek(0)
            m.move(1, 3, 2)
            a = m.read(6)
            assert a == "frarar"
            m.close()

        interpret(func, [f.fileno()])
        f.close()
    
    def test_resize(self):
        if ("darwin" in sys.platform) or ("freebsd" in sys.platform):
            py.test.skip("resize does not work under OSX or FreeBSD")
        
        import os
        
        f = open(self.tmpname + "p", "w+")
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6, access=mmap.ACCESS_WRITE)
            f_size = os.fstat(no).st_size
            assert intmask(m.file_size()) == f_size == 6
            m.resize(10)
            f_size = os.fstat(no).st_size
            assert intmask(m.file_size()) == f_size == 10
            m.close()

        interpret(func, [f.fileno()])
        f.close()

    def test_len(self):
        
        f = open(self.tmpname + "q", "w+")
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6)
            assert m.len() == 6
            m.close()

        interpret(func, [f.fileno()])
        f.close()
     
    def test_get_item(self):
        
        f = open(self.tmpname + "r", "w+")
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6)
            assert m.getitem(0) == 'f'
            assert m.getitem(-1) == 'r'
        # sl = slice(1, 2)
        # assert m.get_item(sl) == 'o'
            m.close()

        interpret(func, [f.fileno()])
        f.close()
    
    def test_set_item(self):
        f = open(self.tmpname + "s", "w+")
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6, access=mmap.ACCESS_WRITE)

            # def f(m): m[1:3] = u'xx'
            # py.test.raises(IndexError, f, m)
            # def f(m): m[1:4] = "zz"
            # py.test.raises(IndexError, f, m)
            # def f(m): m[1:6] = "z" * 6
            # py.test.raises(IndexError, f, m)
            # def f(m): m[:2] = "z" * 5
            # m[1:3] = 'xx'
            # assert m.read(6) == "fxxbar"
            # m.seek(0)
            m.setitem(0, 'x')
            assert m.getitem(0) == 'x'
            m.setitem(-6, 'y')
            data = m.read(6)
            assert data == "yoobar" # yxxbar with slice's stuff
            m.close()

        interpret(func, [f.fileno()])
        f.close()

    def test_double_close(self):
        f = open(self.tmpname + "s", "w+")
        f.write("foobar")
        f.flush()

        def func(no):
            m = mmap.mmap(no, 6, access=mmap.ACCESS_WRITE)
            m.close()
            m.close() # didn't explode

        interpret(func, [f.fileno()])
        f.close()

    def test_translated(self):
        from rpython.translator.c.test.test_genc import compile

        def func(no):
            m = mmap.mmap(no, 1)
            r = m.read_byte()
            m.close()
            return r

        compile(func, [int], gcpolicy='boehm')

    @py.test.mark.skipif("not mmap.has_madvise")
    def test_translated_madvise_bug(self):
        from rpython.translator.c.test.test_genc import compile

        def func():
            m = mmap.mmap(-1, 8096)
            m.madvise(mmap.MADV_NORMAL, 0, 8096)
            m.close()

        compile(func, [], gcpolicy='boehm')

    def test_windows_crasher_1(self):
        if sys.platform != "win32":
            py.test.skip("Windows-only test")
        def func():
            m = mmap.mmap(-1, 1000, tagname="foo")
            # same tagname, but larger size
            try:
                m2 = mmap.mmap(-1, 5000, tagname="foo")
                m2.getitem(4500)
            except WindowsError:
                pass
            m.close()
        interpret(func, [])

    def test_windows_crasher_2(self):
        if sys.platform != "win32":
            py.test.skip("Windows-only test")

        f = open(self.tmpname + "t", "w+")
        f.write("foobar")
        f.flush()

        f = open(self.tmpname + "t", "r+b")
        m = mmap.mmap(f.fileno(), 0)
        f.close()
        py.test.raises(WindowsError, m.resize, 0)
        py.test.raises(RValueError, m.getitem, 0)
        m.close()

    @py.test.mark.skipif("not mmap.has_madvise")
    def test_madvise(self):
        m = mmap.mmap(-1, 8096)
        m.madvise(mmap.MADV_NORMAL, 0, 8096)
        m.close()


def test_alloc_free():
    map_size = 65536
    data = alloc(map_size)
    for i in range(0, map_size, 171):
        data[i] = chr(i & 0xff)
    for i in range(0, map_size, 171):
        assert data[i] == chr(i & 0xff)
    madvise_free(data, map_size)
    free(data, map_size)

def test_compile_alloc_free():
    from rpython.translator.c.test.test_genc import compile

    fn = compile(test_alloc_free, [], gcpolicy='boehm')
    fn()
