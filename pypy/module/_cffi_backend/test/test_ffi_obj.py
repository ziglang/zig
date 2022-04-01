from pypy.module._cffi_backend import newtype
from pypy.module._cffi_backend.newtype import _clean_cache


class TestFFIObj:
    spaceconfig = dict(usemodules=('_cffi_backend', 'array'))

    def teardown_method(self, meth):
        _clean_cache(self.space)

    def test_new_function_type_during_translation(self):
        space = self.space
        BInt = newtype.new_primitive_type(space, "int")
        BFunc = newtype.new_function_type(space, space.wrap([BInt]), BInt)
        assert BFunc is newtype.new_function_type(space,space.wrap([BInt]),BInt)
        unique_cache = space.fromcache(newtype.UniqueCache)
        unique_cache._cleanup_()
        assert BFunc is newtype.new_function_type(space,space.wrap([BInt]),BInt)


class AppTestFFIObj:
    spaceconfig = dict(usemodules=('_cffi_backend', 'array'))

    def teardown_method(self, meth):
        _clean_cache(self.space)

    def test_ffi_new(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        p = ffi.new("int *")
        p[0] = -42
        assert p[0] == -42
        assert type(ffi) is ffi.__class__ is _cffi1_backend.FFI

    def test_ffi_subclass(self):
        import _cffi_backend as _cffi1_backend
        class FOO(_cffi1_backend.FFI):
            def __init__(self, x):
                self.x = x
        foo = FOO(42)
        assert foo.x == 42
        p = foo.new("int *")
        assert p[0] == 0
        assert type(foo) is foo.__class__ is FOO

    def test_ffi_no_argument(self):
        import _cffi_backend as _cffi1_backend
        raises(TypeError, _cffi1_backend.FFI, 42)

    def test_ffi_cache_type(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        t1 = ffi.typeof("int **")
        t2 = ffi.typeof("int *")
        assert t2.item is t1.item.item
        assert t2 is t1.item
        assert ffi.typeof("int[][10]") is ffi.typeof("int[][10]")
        assert ffi.typeof("int(*)()") is ffi.typeof("int(*)()")

    def test_ffi_cache_type_globally(self):
        import _cffi_backend as _cffi1_backend
        ffi1 = _cffi1_backend.FFI()
        ffi2 = _cffi1_backend.FFI()
        t1 = ffi1.typeof("int *")
        t2 = ffi2.typeof("int *")
        assert t1 is t2

    def test_ffi_invalid(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        # array of 10 times an "int[]" is invalid
        raises(ValueError, ffi.typeof, "int[10][]")

    def test_ffi_docstrings(self):
        import _cffi_backend as _cffi1_backend
        # check that all methods of the FFI class have a docstring.
        check_type = type(_cffi1_backend.FFI.new)
        for methname in dir(_cffi1_backend.FFI):
            if not methname.startswith('_'):
                method = getattr(_cffi1_backend.FFI, methname)
                if isinstance(method, check_type):
                    assert method.__doc__, "method FFI.%s() has no docstring" % (
                        methname,)

    def test_ffi_NULL(self):
        import _cffi_backend as _cffi1_backend
        NULL = _cffi1_backend.FFI.NULL
        assert _cffi1_backend.FFI().typeof(NULL).cname == "void *"

    def test_ffi_no_attr(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        raises(AttributeError, "ffi.no_such_name")
        raises(AttributeError, "ffi.no_such_name = 42")
        raises(AttributeError, "del ffi.no_such_name")

    def test_ffi_string(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        p = ffi.new("char[]", init=b"foobar\x00baz")
        assert ffi.string(p) == b"foobar"

    def test_ffi_errno(self):
        import _cffi_backend as _cffi1_backend
        # xxx not really checking errno, just checking that we can read/write it
        ffi = _cffi1_backend.FFI()
        ffi.errno = 42
        assert ffi.errno == 42

    def test_ffi_alignof(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        assert ffi.alignof("int") == 4
        assert ffi.alignof("int[]") == 4
        assert ffi.alignof("int[41]") == 4
        assert ffi.alignof("short[41]") == 2
        assert ffi.alignof(ffi.new("int[41]")) == 4
        assert ffi.alignof(ffi.new("int[]", 41)) == 4

    def test_ffi_sizeof(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        assert ffi.sizeof("int") == 4
        raises(ffi.error, ffi.sizeof, "int[]")
        assert ffi.sizeof("int[41]") == 41 * 4
        assert ffi.sizeof(ffi.new("int[41]")) == 41 * 4
        assert ffi.sizeof(ffi.new("int[]", 41)) == 41 * 4

    def test_ffi_callback(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        assert ffi.callback("int(int)", lambda x: x + 42)(10) == 52
        assert ffi.callback("int(*)(int)", lambda x: x + 42)(10) == 52
        assert ffi.callback("int(int)", lambda x: x + "", -66)(10) == -66
        assert ffi.callback("int(int)", lambda x: x + "", error=-66)(10) == -66

    def test_ffi_callback_onerror(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        seen = []
        def myerror(exc, val, tb):
            seen.append(exc)
        cb = ffi.callback("int(int)", lambda x: x + "", onerror=myerror)
        assert cb(10) == 0
        cb = ffi.callback("int(int)", lambda x:int(1E100), -66, onerror=myerror)
        assert cb(10) == -66
        assert seen == [TypeError, OverflowError]

    def test_ffi_callback_decorator(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        assert ffi.callback(ffi.typeof("int(*)(int)"))(lambda x: x + 42)(10) == 52
        deco = ffi.callback("int(int)", error=-66)
        assert deco(lambda x: x + "")(10) == -66
        assert deco(lambda x: x + 42)(10) == 52

    def test_ffi_callback_onerror(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        seen = []
        def oops(*args):
            seen.append(args)

        @ffi.callback("int(int)", onerror=oops)
        def fn1(x):
            return x + ""
        assert fn1(10) == 0

        @ffi.callback("int(int)", onerror=oops, error=-66)
        def fn2(x):
            return x + ""
        assert fn2(10) == -66

        assert len(seen) == 2
        exc, val, tb = seen[0]
        assert exc is TypeError
        assert isinstance(val, TypeError)
        assert tb.tb_frame.f_code.co_name == "fn1"
        exc, val, tb = seen[1]
        assert exc is TypeError
        assert isinstance(val, TypeError)
        assert tb.tb_frame.f_code.co_name == "fn2"
        del seen[:]
        #
        raises(TypeError, ffi.callback, "int(int)",
               lambda x: x, onerror=42)   # <- not callable

    def test_ffi_getctype(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        assert ffi.getctype("int") == "int"
        assert ffi.getctype("int", 'x') == "int x"
        assert ffi.getctype("int*") == "int *"
        assert ffi.getctype("int*", '') == "int *"
        assert ffi.getctype("int*", 'x') == "int * x"
        assert ffi.getctype("int", '*') == "int *"
        assert ffi.getctype("int", replace_with=' * x ') == "int * x"
        assert ffi.getctype(ffi.typeof("int*"), '*') == "int * *"
        assert ffi.getctype("int", '[5]') == "int[5]"
        assert ffi.getctype("int[5]", '[6]') == "int[6][5]"
        assert ffi.getctype("int[5]", '(*)') == "int(*)[5]"
        # special-case for convenience: automatically put '()' around '*'
        assert ffi.getctype("int[5]", '*') == "int(*)[5]"
        assert ffi.getctype("int[5]", '*foo') == "int(*foo)[5]"
        assert ffi.getctype("int[5]", ' ** foo ') == "int(** foo)[5]"

    def test_addressof(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        a = ffi.new("int[10]")
        b = ffi.addressof(a, 5)
        b[2] = -123
        assert a[7] == -123

    def test_handle(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        x = [2, 4, 6]
        xp = ffi.new_handle(x)
        assert ffi.typeof(xp) == ffi.typeof("void *")
        assert ffi.from_handle(xp) is x
        yp = ffi.new_handle([6, 4, 2])
        assert ffi.from_handle(yp) == [6, 4, 2]

    def test_ffi_cast(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        assert ffi.cast("int(*)(int)", 0) == ffi.NULL
        ffi.callback("int(int)")      # side-effect of registering this string
        raises(ffi.error, ffi.cast, "int(int)", 0)

    def test_ffi_invalid_type(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        e = raises(ffi.error, ffi.cast, "", 0)
        assert str(e.value) == ("identifier expected\n"
                                "\n"
                                "^")
        e = raises(ffi.error, ffi.cast, "struct struct", 0)
        assert str(e.value) == ("struct or union name expected\n"
                                "struct struct\n"
                                "       ^")
        e = raises(ffi.error, ffi.cast, "struct never_heard_of_s", 0)
        assert str(e.value) == ("undefined struct/union name\n"
                                "struct never_heard_of_s\n"
                                "       ^")
        e = raises(ffi.error, ffi.cast, "\t\n\x01\x1f~\x7f\x80\xff", 0)
        assert str(e.value) == ("identifier expected\n"
                                "  ??~?????\n"
                                "  ^")
        e = raises(ffi.error, ffi.cast, "X" * 600, 0)
        assert str(e.value) == ("undefined type name")

    def test_ffi_buffer(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        a = ffi.new("signed char[]", [5, 6, 7])
        assert ffi.buffer(a)[:] == b'\x05\x06\x07'
        assert ffi.buffer(cdata=a, size=2)[:] == b'\x05\x06'
        assert type(ffi.buffer(a)) is ffi.buffer

    def test_ffi_buffer_comparisons(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        ba = bytearray(range(100, 110))
        assert ba == memoryview(ba)    # justification for the following
        a = ffi.new("uint8_t[]", list(ba))
        c = ffi.new("uint8_t[]", [99] + list(ba))
        b_full = ffi.buffer(a)
        b_short = ffi.buffer(a, 3)
        b_mid = ffi.buffer(a, 6)
        b_other = ffi.buffer(c, 6)
        content = b_full[:]
        assert content == b_full == ba
        assert b_short < b_mid < b_full
        assert b_other < b_short < b_mid < b_full
        assert ba > b_mid > ba[0:2]
        assert b_short != ba[1:4]
        assert b_short != 42

    def test_ffi_from_buffer(self):
        import _cffi_backend as _cffi1_backend
        import array
        ffi = _cffi1_backend.FFI()
        a = array.array('H', [10000, 20000, 30000, 40000])
        c = ffi.from_buffer(a)
        assert ffi.typeof(c) is ffi.typeof("char[]")
        assert len(c) == 8
        ffi.cast("unsigned short *", c)[1] += 500
        assert list(a) == [10000, 20500, 30000, 40000]
        raises(TypeError, ffi.from_buffer, a, True)
        assert c == ffi.from_buffer("char[]", a, True)
        assert c == ffi.from_buffer(a, require_writable=True)
        #
        c = ffi.from_buffer("unsigned short[]", a)
        assert len(c) == 4
        assert c[1] == 20500
        #
        c = ffi.from_buffer("unsigned short[2][2]", a)
        assert len(c) == 2
        assert len(c[0]) == 2
        assert c[0][1] == 20500
        #
        p = ffi.from_buffer(b"abcd")
        assert p[2] == b"c"
        #
        assert p == ffi.from_buffer(b"abcd", require_writable=False)
        raises((TypeError, BufferError), ffi.from_buffer,
                                         "char[]", b"abcd", True)
        raises((TypeError, BufferError), ffi.from_buffer, b"abcd",
                                         require_writable=True)

    def test_from_buffer_BytesIO(self):
        from _cffi_backend import FFI
        import _io
        ffi = FFI()
        a = _io.BytesIO(b"Hello, world!")
        buf = a.getbuffer()
        # used to segfault
        raises(TypeError, ffi.from_buffer, buf)

    def test_memmove(self):
        import sys
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        p = ffi.new("short[]", [-1234, -2345, -3456, -4567, -5678])
        ffi.memmove(p, p + 1, 4)
        assert list(p) == [-2345, -3456, -3456, -4567, -5678]
        p[2] = 999
        ffi.memmove(p + 2, p, 6)
        assert list(p) == [-2345, -3456, -2345, -3456, 999]
        ffi.memmove(p + 4, ffi.new("char[]", b"\x71\x72"), 2)
        if sys.byteorder == 'little':
            assert list(p) == [-2345, -3456, -2345, -3456, 0x7271]
        else:
            assert list(p) == [-2345, -3456, -2345, -3456, 0x7172]

    def test_memmove_buffer(self):
        import _cffi_backend as _cffi1_backend
        import array
        ffi = _cffi1_backend.FFI()
        a = array.array('H', [10000, 20000, 30000])
        p = ffi.new("short[]", 5)
        ffi.memmove(p, a, 6)
        assert list(p) == [10000, 20000, 30000, 0, 0]
        ffi.memmove(p + 1, a, 6)
        assert list(p) == [10000, 10000, 20000, 30000, 0]
        b = array.array('h', [-1000, -2000, -3000])
        ffi.memmove(b, a, 4)
        assert b.tolist() == [10000, 20000, -3000]
        assert a.tolist() == [10000, 20000, 30000]
        p[0] = 999
        p[1] = 998
        p[2] = 997
        p[3] = 996
        p[4] = 995
        ffi.memmove(b, p, 2)
        assert b.tolist() == [999, 20000, -3000]
        ffi.memmove(b, p + 2, 4)
        assert b.tolist() == [997, 996, -3000]
        p[2] = -p[2]
        p[3] = -p[3]
        ffi.memmove(b, p + 2, 6)
        assert b.tolist() == [-997, -996, 995]

    def test_memmove_readonly_readwrite(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        p = ffi.new("signed char[]", 5)
        ffi.memmove(p, b"abcde", 3)
        assert list(p) == [ord("a"), ord("b"), ord("c"), 0, 0]
        ffi.memmove(p, bytearray(b"ABCDE"), 2)
        assert list(p) == [ord("A"), ord("B"), ord("c"), 0, 0]
        raises((TypeError, BufferError), ffi.memmove, b"abcde", p, 3)
        ba = bytearray(b"xxxxx")
        ffi.memmove(dest=ba, src=p, n=3)
        assert ba == bytearray(b"ABcxx")

    def test_ffi_types(self):
        import _cffi_backend as _cffi1_backend
        CData = _cffi1_backend.FFI.CData
        CType = _cffi1_backend.FFI.CType
        ffi = _cffi1_backend.FFI()
        assert isinstance(ffi.cast("int", 42), CData)
        assert isinstance(ffi.typeof("int"), CType)

    def test_ffi_gc(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        p = ffi.new("int *", 123)
        seen = []
        def destructor(p1):
            assert p1 is p
            assert p1[0] == 123
            seen.append(1)
        ffi.gc(p, destructor=destructor)    # instantly forgotten
        for i in range(5):
            if seen:
                break
            import gc
            gc.collect()
        assert seen == [1]

    def test_ffi_gc_disable(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        p = ffi.new("int *", 123)
        raises(TypeError, ffi.gc, p, None)
        seen = []
        q1 = ffi.gc(p, lambda p: seen.append(1))
        q2 = ffi.gc(q1, lambda p: seen.append(2), size=123)
        import gc; gc.collect()
        assert seen == []
        assert ffi.gc(q1, None) is None
        del q1, q2
        for i in range(5):
            if seen:
                break
            import gc
            gc.collect()
        assert seen == [2]

    def test_ffi_new_allocator_1(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        alloc1 = ffi.new_allocator()
        alloc2 = ffi.new_allocator(should_clear_after_alloc=False)
        for retry in range(100):
            p1 = alloc1("int[10]")
            p2 = alloc2("int[10]")
            combination = 0
            for i in range(10):
                assert p1[i] == 0
                combination |= p2[i]
                p1[i] = -42
                p2[i] = -43
            if combination != 0:
                break
            del p1, p2
            import gc; gc.collect()
        else:
            raise AssertionError("cannot seem to get an int[10] not "
                                 "completely cleared")

    def test_ffi_new_allocator_2(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        seen = []
        def myalloc(size):
            seen.append(size)
            return ffi.new("char[]", b"X" * size)
        def myfree(raw):
            seen.append(raw)
        alloc1 = ffi.new_allocator(myalloc, myfree)
        alloc2 = ffi.new_allocator(alloc=myalloc, free=myfree,
                                   should_clear_after_alloc=False)
        p1 = alloc1("int[10]")
        p2 = alloc2("int[]", 10)
        assert seen == [40, 40]
        assert ffi.typeof(p1) == ffi.typeof("int[10]")
        assert ffi.sizeof(p1) == 40
        assert ffi.typeof(p2) == ffi.typeof("int[]")
        assert ffi.sizeof(p2) == 40
        assert p1[5] == 0
        assert p2[6] == ord('X') * 0x01010101
        raw1 = ffi.cast("char *", p1)
        raw2 = ffi.cast("char *", p2)
        del p1, p2
        retries = 0
        while len(seen) != 4:
            retries += 1
            assert retries <= 5
            import gc; gc.collect()
        assert (seen == [40, 40, raw1, raw2] or
                seen == [40, 40, raw2, raw1])
        assert repr(seen[2]) == "<cdata 'char[]' owning 41 bytes>"
        assert repr(seen[3]) == "<cdata 'char[]' owning 41 bytes>"

    def test_ffi_new_allocator_3(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        seen = []
        def myalloc(size):
            seen.append(size)
            return ffi.new("char[]", b"X" * size)
        alloc1 = ffi.new_allocator(myalloc)    # no 'free'
        p1 = alloc1("int[10]")
        assert seen == [40]
        assert ffi.typeof(p1) == ffi.typeof("int[10]")
        assert ffi.sizeof(p1) == 40
        assert p1[5] == 0

    def test_ffi_new_allocator_4(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        raises(TypeError, ffi.new_allocator, free=lambda x: None)
        #
        def myalloc2(size):
            raise LookupError
        alloc2 = ffi.new_allocator(myalloc2)
        raises(LookupError, alloc2, "int[5]")
        #
        def myalloc3(size):
            return 42
        alloc3 = ffi.new_allocator(myalloc3)
        e = raises(TypeError, alloc3, "int[5]")
        assert str(e.value) == "alloc() must return a cdata object (got int)"
        #
        def myalloc4(size):
            return ffi.cast("int", 42)
        alloc4 = ffi.new_allocator(myalloc4)
        e = raises(TypeError, alloc4, "int[5]")
        assert str(e.value) == "alloc() must return a cdata pointer, not 'int'"
        #
        def myalloc5(size):
            return ffi.NULL
        alloc5 = ffi.new_allocator(myalloc5)
        raises(MemoryError, alloc5, "int[5]")

    def test_bool_issue228(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        fntype = ffi.typeof("int(*callback)(bool is_valid)")
        assert repr(fntype.args[0]) == "<ctype '_Bool'>"

    def test_FILE_issue228(self):
        import _cffi_backend as _cffi1_backend
        fntype1 = _cffi1_backend.FFI().typeof("FILE *")
        fntype2 = _cffi1_backend.FFI().typeof("FILE *")
        assert repr(fntype1) == "<ctype 'FILE *'>"
        assert fntype1 is fntype2

    def test_cast_from_int_type_to_bool(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        for basetype in ['char', 'short', 'int', 'long', 'long long']:
            for sign in ['signed', 'unsigned']:
                type = '%s %s' % (sign, basetype)
                assert int(ffi.cast("_Bool", ffi.cast(type, 42))) == 1
                assert int(ffi.cast("bool", ffi.cast(type, 42))) == 1
                assert int(ffi.cast("_Bool", ffi.cast(type, 0))) == 0

    def test_init_once(self):
        import _cffi_backend as _cffi1_backend
        def do_init():
            seen.append(1)
            return 42
        ffi = _cffi1_backend.FFI()
        seen = []
        for i in range(3):
            res = ffi.init_once(do_init, "tag1")
            assert res == 42
            assert seen == [1]
        for i in range(3):
            res = ffi.init_once(do_init, "tag2")
            assert res == 42
            assert seen == [1, 1]

    def test_init_once_failure(self):
        import _cffi_backend as _cffi1_backend
        def do_init():
            seen.append(1)
            raise ValueError
        ffi = _cffi1_backend.FFI()
        seen = []
        for i in range(5):
            raises(ValueError, ffi.init_once, do_init, "tag")
            assert seen == [1] * (i + 1)

    def test_unpack(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        p = ffi.new("char[]", b"abc\x00def")
        assert ffi.unpack(p+1, 7) == b"bc\x00def\x00"
        p = ffi.new("int[]", [-123456789])
        assert ffi.unpack(p, 1) == [-123456789]

    def test_bug_1(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        q = ffi.new("char[]", b"abcd")
        p = ffi.cast("char(*)(void)", q)
        raises(TypeError, ffi.string, p)

    def test_negative_array_size(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        raises(ffi.error, ffi.cast, "int[-5]", 0)

    def test_char32_t(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        z = ffi.new("char32_t[]", u'\U00012345')
        assert len(z) == 2
        assert ffi.cast("int *", z)[0] == 0x12345
        assert list(z) == [u'\U00012345', u'\x00']   # maybe a 2-unichars str

    def test_ffi_array_as_init(self):
        import _cffi_backend as _cffi1_backend
        ffi = _cffi1_backend.FFI()
        p = ffi.new("int[4]", [10, 20, 30, 400])
        q = ffi.new("int[4]", p)
        assert list(q) == [10, 20, 30, 400]
        raises(TypeError, ffi.new, "int[3]", p)
        raises(TypeError, ffi.new, "int[5]", p)
        raises(TypeError, ffi.new, "int16_t[4]", p)
