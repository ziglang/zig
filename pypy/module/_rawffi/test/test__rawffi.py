from rpython.translator.platform import platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator import cdir
from pypy.module._rawffi.interp_rawffi import TYPEMAP, TYPEMAP_FLOAT_LETTERS
from pypy.module._rawffi.tracker import Tracker

import os, sys, py

class AppTestFfi:
    spaceconfig = dict(usemodules=['_rawffi', 'struct'])

    def prepare_c_example():
        from rpython.tool.udir import udir
        c_file = udir.ensure("test__rawffi", dir=1).join("xlib.c")
        c_file.write(py.code.Source('''
        #include "src/precommondefs.h"
        #include <stdlib.h>
        #include <stdio.h>
        #include <errno.h>

        struct x
        {
           int x1;
           short x2;
           char x3;
           struct x* next;
        };

        RPY_EXPORTED
        void nothing()
        {
        }

        RPY_EXPORTED
        char inner_struct_elem(struct x *x1)
        {
           return x1->next->x3;
        }

        RPY_EXPORTED
        struct x* create_double_struct()
        {
           struct x* x1, *x2;

           x1 = (struct x*)malloc(sizeof(struct x));
           x2 = (struct x*)malloc(sizeof(struct x));
           x1->next = x2;
           x2->x2 = 3;
           return x1;
        }

        RPY_EXPORTED
        void free_double_struct(struct x* x1)
        {
            free(x1->next);
            free(x1);
        }

        const char *static_str = "xxxxxx";
        RPY_EXPORTED
        long static_int = 42;
        RPY_EXPORTED
        double static_double = 42.42;
        RPY_EXPORTED
        long double static_longdouble = 42.42;

        RPY_EXPORTED
        unsigned short add_shorts(short one, short two)
        {
           return one + two;
        }

        RPY_EXPORTED
        void* get_raw_pointer()
        {
           return (void*)add_shorts;
        }

        RPY_EXPORTED
        char get_char(char* s, unsigned short num)
        {
           return s[num];
        }

        RPY_EXPORTED
        const char *char_check(char x, char y)
        {
           if (y == static_str[0])
              return static_str;
           return NULL;
        }

        RPY_EXPORTED
        int get_array_elem(int* stuff, int num)
        {
           return stuff[num];
        }

        RPY_EXPORTED
        struct x* get_array_elem_s(struct x** array, int num)
        {
           return array[num];
        }

        RPY_EXPORTED
        long long some_huge_value()
        {
           return 1LL<<42;
        }

        RPY_EXPORTED
        unsigned long long some_huge_uvalue()
        {
           return 1LL<<42;
        }

        RPY_EXPORTED
        long long pass_ll(long long x)
        {
           return x;
        }

        static int prebuilt_array1[] = {3};

        RPY_EXPORTED
        int* allocate_array()
        {
            return prebuilt_array1;
        }

        RPY_EXPORTED
        long long runcallback(long long(*callback)())
        {
            return callback();
        }

        struct x_y {
            long x;
            long y;
        };

        RPY_EXPORTED
        long sum_x_y(struct x_y s) {
            return s.x + s.y;
        }

        RPY_EXPORTED
        long op_x_y(struct x_y s, long(*callback)(struct x_y))
        {
            return callback(s);
        }

        struct s2h {
            short x;
            short y;
        };

        RPY_EXPORTED
        struct s2h give(short x, short y) {
            struct s2h out;
            out.x = x;
            out.y = y;
            return out;
        }

        RPY_EXPORTED
        struct s2h perturb(struct s2h inp) {
            inp.x *= 2;
            inp.y *= 3;
            return inp;
        }

        struct s2a {
            int bah[2];
        };

        RPY_EXPORTED
        struct s2a get_s2a(void) {
            struct s2a outp;
            outp.bah[0] = 4;
            outp.bah[1] = 5;
            return outp;
        }

        RPY_EXPORTED
        int check_s2a(struct s2a inp) {
            return (inp.bah[0] == 4 && inp.bah[1] == 5);
        }

        RPY_EXPORTED
        int AAA_first_ordinal_function()
        {
            return 42;
        }

        typedef union {
            short x;
            long y;
        } UN;

        RPY_EXPORTED
        UN ret_un_func(UN inp)
        {
            inp.y = inp.x * 100;
            return inp;
        }

        RPY_EXPORTED
        int check_errno(int incoming)
        {
            int old_errno = errno;
            errno = incoming;
            return old_errno;
        }

        #ifdef _WIN32
        #include <Windows.h>
        RPY_EXPORTED
        int check_last_error(int incoming)
        {
            int old_errno = GetLastError();
            SetLastError(incoming);
            return old_errno;
        }
        #endif
        '''))
        eci = ExternalCompilationInfo(include_dirs=[cdir])
        return str(platform.compile([c_file], eci, 'x', standalone=False))
    prepare_c_example = staticmethod(prepare_c_example)

    def setup_class(cls):
        space = cls.space
        from rpython.rlib.clibffi import get_libc_name
        cls.w_lib_name = space.wrap(cls.prepare_c_example())
        cls.w_libc_name = space.wrap(get_libc_name())
        if sys.platform == 'win32':
            cls.w_iswin32 = space.wrap(True)
            cls.w_libm_name = space.wrap('msvcrt')
        else:
            cls.w_iswin32 = space.wrap(False)
            cls.w_libm_name = space.wrap('libm.so')
            if sys.platform == "darwin":
                cls.w_libm_name = space.wrap('libm.dylib')
        cls.w_platform = space.wrap(platform.name)
        cls.w_sizes_and_alignments = space.wrap(dict(
            [(k, (v.c_size, v.c_alignment)) for k,v in TYPEMAP.iteritems()]))
        cls.w_float_typemap = space.wrap(TYPEMAP_FLOAT_LETTERS)
        cls.w_is64bit = space.wrap(sys.maxint > 2147483647)

    def test_libload(self):
        import _rawffi
        _rawffi.CDLL(self.libc_name)

    def test_libload_fail(self):
        import _rawffi
        try:
            _rawffi.CDLL("xxxxx_this_name_does_not_exist_xxxxx")
        except OSError as e:
            print(e)
            assert str(e).startswith(
                "Cannot load library xxxxx_this_name_does_not_exist_xxxxx: ")
        else:
            raise AssertionError("did not fail??")

    def test_libload_None(self):
        import _rawffi
        # this should return *all* loaded libs, dlopen(NULL)
        try:
            dll = _rawffi.CDLL(None)
        except TypeError:
            if not self.iswin32:
                raise
        else:
            func = dll.ptr('rand', [], 'i')
            res = func()
            assert res[0] != 0

    def test_libc_load(self):
        import _rawffi
        _rawffi.get_libc()

    def test_getattr(self):
        import _rawffi
        libc = _rawffi.get_libc()
        func = libc.ptr('rand', [], 'i')
        assert libc.ptr('rand', [], 'i') is func # caching
        assert libc.ptr('rand', [], 'l') is not func
        assert isinstance(func, _rawffi.FuncPtr)
        raises(AttributeError, "libc.xxxxxxxxxxxxxx")

    def test_byordinal(self):
        if not self.iswin32:
            skip("win32 specific")
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        # This will call the ordinal function numbered 1
        # my compiler seems to order them alphabetically:
        # AAA_first_ordinal_function
        assert lib.ptr(1, [], 'i')()[0] == 42

    def test_getchar(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        get_char = lib.ptr('get_char', ['P', 'H'], 'c')
        A = _rawffi.Array('c')
        B = _rawffi.Array('H')
        dupa = A(5, b'dupa')
        dupaptr = dupa.byptr()
        for i in range(4):
            intptr = B(1)
            intptr[0] = i
            res = get_char(dupaptr, intptr)
            char = b'dupa'[i:i+1]
            assert res[0] == char
            intptr.free()
        dupaptr.free()
        dupa.free()

    def test_chararray_as_bytebuffer(self):
        # a useful extension to arrays of shape 'c': buffer-like slicing
        import _rawffi
        A = _rawffi.Array('c')
        buf = A(10, autofree=True)
        buf[0] = b'*'
        assert buf[1:5] == b'\x00' * 4
        buf[7:] = b'abc'
        assert buf[9] == b'c'
        assert buf[:8] == b'*' + b'\x00'*6 + b'a'

    def test_returning_str(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        char_check = lib.ptr('char_check', ['c', 'c'], 's')
        A = _rawffi.Array('c')
        arg1 = A(1)
        arg2 = A(1)
        arg1[0] = b'y'
        arg2[0] = b'x'
        res = char_check(arg1, arg2)
        assert _rawffi.charp2string(res[0]) == b'xxxxxx'
        assert _rawffi.charp2rawstring(res[0]) == b'xxxxxx'
        assert _rawffi.charp2rawstring(res[0], 3) == b'xxx'
        a = A(6, b'xx\x00\x00xx')
        assert _rawffi.charp2string(a.buffer) == b'xx'
        assert _rawffi.charp2rawstring(a.buffer, 4) == b'xx\x00\x00'
        arg1[0] = b'x'
        arg2[0] = b'y'
        res = char_check(arg1, arg2)
        assert res[0] == 0
        assert _rawffi.charp2string(res[0]) is None
        arg1.free()
        arg2.free()
        a.free()

    def test_unicode_array(self):
        import _rawffi
        A = _rawffi.Array('u')
        a = A(6, u'\u1234')
        assert a[0] == u'\u1234'
        a[0] = u'\ud800'
        assert a[0] == u'\ud800'
        if _rawffi.sizeof('u') == 4:
            a[0] = u'\U00012345'
            assert a[0] == u'\U00012345'
            B = _rawffi.Array('i')
            b = B.fromaddress(a.itemaddress(0), 1)
            b[0] = 0xffffffff
            raises(ValueError, "a[0]")
        a.free()

    def test_returning_unicode(self):
        import _rawffi
        A = _rawffi.Array('u')
        a = A(6, u'xx\x00\x00xx')
        for i in (-1, 6):
            res = _rawffi.wcharp2unicode(a.buffer, i)
            assert isinstance(res, str)
            assert res == u'xx'
        a.free()

    def test_rawstring2charp(self):
        import _rawffi
        A = _rawffi.Array('c')
        a = A(10, b'x'*10)
        _rawffi.rawstring2charp(a.buffer, b"foobar")
        assert b''.join([a[i] for i in range(10)]) == b"foobarxxxx"
        _rawffi.rawstring2charp(a.buffer, memoryview(b"baz"))
        assert b''.join([a[i] for i in range(10)]) == b"bazbarxxxx"
        _rawffi.rawstring2charp(a.buffer, memoryview(b"ABCDEF"), 2)
        assert b''.join([a[i] for i in range(10)]) == b"CDEFarxxxx"
        _rawffi.rawstring2charp(a.buffer, memoryview(b"ZYXWVU"), 2, 3)
        assert b''.join([a[i] for i in range(10)]) == b"XWVFarxxxx"
        a.free()

    def test_raw_callable(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        get_raw_pointer = lib.ptr('get_raw_pointer', [], 'P')
        ptr = get_raw_pointer()
        rawcall = _rawffi.FuncPtr(ptr[0], ['h', 'h'], 'H')
        A = _rawffi.Array('h')
        arg1 = A(1)
        arg2 = A(1)
        arg1[0] = 1
        arg2[0] = 2
        res = rawcall(arg1, arg2)
        assert res[0] == 3
        arg1.free()
        arg2.free()
        assert rawcall.buffer == ptr[0]
        ptr = rawcall.byptr()
        assert ptr[0] == rawcall.buffer
        ptr.free()

    def test_raw_callable_returning_void(self):
        import _rawffi
        _rawffi.FuncPtr(0, [], None)
        # assert did not crash

    def test_short_addition(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        short_add = lib.ptr('add_shorts', ['h', 'h'], 'H')
        A = _rawffi.Array('h')
        arg1 = A(1)
        arg2 = A(1)
        arg1[0] = 1
        arg2[0] = 2
        res = short_add(arg1, arg2)
        assert res[0] == 3
        arg1.free()
        arg2.free()

    def test_pow(self):
        import _rawffi
        libm = _rawffi.CDLL(self.libm_name)
        pow = libm.ptr('pow', ['d', 'd'], 'd')
        A = _rawffi.Array('d')
        arg1 = A(1)
        arg2 = A(1)
        raises(TypeError, "arg1[0] = 'x'")
        arg1[0] = 3
        arg2[0] = 2.0
        res = pow(arg1, arg2)
        assert res[0] == 9.0
        arg1.free()
        arg2.free()

    def test_time(self):
        import _rawffi
        libc = _rawffi.get_libc()
        try:
            time = libc.ptr('time', ['z'], 'l')  # 'z' instead of 'P' just for test
        except AttributeError:
            # Since msvcr80, this function is named differently
            time = libc.ptr('_time32', ['z'], 'l')
        arg = _rawffi.Array('P')(1)
        arg[0] = 0
        res = time(arg)
        assert res[0] != 0
        arg.free()

    def test_gettimeofday(self):
        if self.iswin32:
            skip("No gettimeofday on win32")
        import _rawffi
        struct_type = _rawffi.Structure([('tv_sec', 'l'), ('tv_usec', 'l')])
        structure = struct_type()
        libc = _rawffi.get_libc()
        gettimeofday = libc.ptr('gettimeofday', ['P', 'P'], 'i')

        arg1 = structure.byptr()
        arg2 = _rawffi.Array('P')(1)
        res = gettimeofday(arg1, arg2)
        assert res[0] == 0

        struct2 = struct_type()
        arg1[0] = struct2
        res = gettimeofday(arg1, arg2)
        assert res[0] == 0

        assert structure.tv_usec != struct2.tv_usec
        assert (structure.tv_sec == struct2.tv_sec) or (structure.tv_sec == struct2.tv_sec - 1)
        raises(AttributeError, "structure.xxx")
        structure.free()
        struct2.free()
        arg1.free()
        arg2.free()

    def test_structreturn(self):
        import _rawffi
        X = _rawffi.Structure([('x', 'l')])
        x = X()
        x.x = 121
        Tm = _rawffi.Structure([('tm_sec', 'i'),
                                ('tm_min', 'i'),
                                ('tm_hour', 'i'),
                                ("tm_mday", 'i'),
                                ("tm_mon", 'i'),
                                ("tm_year", 'i'),
                                ("tm_wday", 'i'),
                                ("tm_yday", 'i'),
                                ("tm_isdst", 'i')])
        libc = _rawffi.get_libc()
        try:
            gmtime = libc.ptr('gmtime', ['P'], 'P')
        except AttributeError:
            # Since msvcr80, this function is named differently
            gmtime = libc.ptr('_gmtime32', ['P'], 'P')

        arg = x.byptr()
        res = gmtime(arg)
        t = Tm.fromaddress(res[0])
        arg.free()
        assert t.tm_year == 70
        assert t.tm_sec == 1
        assert t.tm_min == 2
        x.free()

    def test_nested_structures(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        inner = lib.ptr("inner_struct_elem", ['P'], 'c')
        X = _rawffi.Structure([('x1', 'i'), ('x2', 'h'), ('x3', 'c'), ('next', 'P')])
        next = X()
        next.next = 0
        next.x3 = b'x'
        x = X()
        x.next = next
        x.x1 = 1
        x.x2 = 2
        x.x3 = b'x'
        assert X.fromaddress(x.next).x3 == b'x'
        x.free()
        next.free()
        create_double_struct = lib.ptr("create_double_struct", [], 'P')
        res = create_double_struct()
        x = X.fromaddress(res[0])
        assert X.fromaddress(x.next).x2 == 3
        free_double_struct = lib.ptr("free_double_struct", ['P'], None)
        free_double_struct(res)

    def test_structure_bitfields_char(self):
        import _rawffi
        X = _rawffi.Structure([('A', 'B', 1),
                               ('B', 'B', 6),
                               ('C', 'B', 1)])
        x = X()
        x.A = 0xf
        x.B = 0xff
        x.C = 0xf
        assert x.A == 1
        assert x.B == 63
        assert x.C == 1
        x.free()

    def test_structure_bitfields_varied(self):
        import _rawffi
        X = _rawffi.Structure([('A', 'I', 1),
                               ('B', 'I', 2),
                               ('C', 'i', 2)])
        x = X()
        x.A = 0xf
        x.B = 0xf
        x.C = 0xf
        assert x.A == 1
        assert x.B == 3
        assert x.C == -1
        x.free()

    def test_structure_bitfields_int(self):
        import _rawffi
        Y = _rawffi.Structure([('a', 'i', 1),
                               ('b', 'i', 30),
                               ('c', 'i', 1)])
        y = Y()
        y.a, y.b, y.c = -1, -7, 1
        assert (y.a, y.b, y.c) == (-1, -7, -1)
        y.free()

    def test_structure_bitfields_uint(self):
        import _rawffi
        Y = _rawffi.Structure([('a', 'I', 1),
                               ('b', 'I', 30),
                               ('c', 'I', 1)])
        y = Y()
        y.a, y.b, y.c = 7, (1 << 29) | 1, 7
        assert (y.a, y.b, y.c) == (1, (1 << 29) | 1, 1)
        y.free()

    def test_structure_bitfields_longlong(self):
        import _rawffi
        Y = _rawffi.Structure([('a', 'q', 1),
                               ('b', 'q', 62),
                               ('c', 'q', 1)])
        y = Y()
        y.a, y.b, y.c = -1, -7, 1
        assert (y.a, y.b, y.c) == (-1, -7, -1)
        y.free()

    def test_structure_bitfields_ulonglong(self):
        import _rawffi
        Y = _rawffi.Structure([('a', 'Q', 1),
                               ('b', 'Q', 62),
                               ('c', 'Q', 1)])
        y = Y()
        y.a, y.b, y.c = 7, (1 << 61) | 1, 7
        assert (y.a, y.b, y.c) == (1, (1 << 61) | 1, 1)
        y.free()

    def test_structure_bitfields_single_signed(self):
        import _rawffi
        for s in [('i', 32), ('q', 64)]:
            Y = _rawffi.Structure([('a',) + s])
            y = Y()
            y.a = 10
            assert y.a == 10
            val = (1 << (s[1] - 1)) | 1
            y.a = val
            assert y.a == val - (1 << s[1])
            y.free()

    def test_structure_bitfields_single_unsigned(self):
        import _rawffi
        for s in [('I', 32), ('Q', 64)]:
            Y = _rawffi.Structure([('a',) + s])
            y = Y()
            y.a = 10
            assert y.a == 10
            val = (1 << (s[1] - 1)) | 1
            y.a = val
            assert y.a == val
            y.free()

    def test_invalid_bitfields(self):
        import _rawffi
        raises(TypeError, _rawffi.Structure, [('A', 'c', 1)])
        raises(ValueError, _rawffi.Structure, [('A', 'I', 129)])
        raises(ValueError, _rawffi.Structure, [('A', 'I', -1)])
        raises(ValueError, _rawffi.Structure, [('A', 'I', 0)])

    def test_packed_structure(self):
        import _rawffi
        Y = _rawffi.Structure([('a', 'c'),
                               ('b', 'i')], pack=1)
        assert Y.size == 5

    def test_array(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        A = _rawffi.Array('i')
        get_array_elem = lib.ptr('get_array_elem', ['P', 'i'], 'i')
        a = A(10)
        a[8] = 3
        a[7] = 1
        a[6] = 2
        arg1 = a.byptr()
        arg2 = A(1)
        for i, expected in enumerate([0, 0, 0, 0, 0, 0, 2, 1, 3, 0]):
            arg2[0] = i
            res = get_array_elem(arg1, arg2)
            assert res[0] == expected
        arg1.free()
        arg2.free()
        assert a[3] == 0
        a.free()

    def test_array_of_structure(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        A = _rawffi.Array('P')
        X = _rawffi.Structure([('x1', 'i'), ('x2', 'h'), ('x3', 'c'), ('next', 'P')])
        x = X()
        x.x2 = 3
        a = A(3)
        a[1] = x
        get_array_elem_s = lib.ptr('get_array_elem_s', ['P', 'i'], 'P')
        arg1 = a.byptr()
        arg2 = _rawffi.Array('i')(1)
        res = get_array_elem_s(arg1, arg2)
        assert res[0] == 0
        arg2[0] = 1
        res = get_array_elem_s(arg1, arg2)
        assert X.fromaddress(res[0]).x2 == 3
        assert res[0] == x.buffer
        arg1.free()
        arg2.free()
        x.free()
        a.free()

    def test_bad_parameters(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        nothing = lib.ptr('nothing', [], None)
        assert nothing() is None
        raises(AttributeError, "lib.ptr('get_charx', [], None)")
        raises(ValueError, "lib.ptr('get_char', ['xx'], None)")
        raises(ValueError, "lib.ptr('get_char', ['x'], None)")
        raises(ValueError, "lib.ptr('get_char', [], 'x')")
        raises(ValueError, "_rawffi.Structure(['x1', 'xx'])")
        raises(ValueError, _rawffi.Structure, [('x1', 'xx')])
        raises(ValueError, "_rawffi.Array('xx')")

    def test_longs_ulongs(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        some_huge_value = lib.ptr('some_huge_value', [], 'q')
        res = some_huge_value()
        assert res[0] == 1<<42
        some_huge_uvalue = lib.ptr('some_huge_uvalue', [], 'Q')
        res = some_huge_uvalue()
        assert res[0] == 1<<42
        pass_ll = lib.ptr('pass_ll', ['q'], 'q')
        arg1 = _rawffi.Array('q')(1)
        arg1[0] = 1<<42
        res = pass_ll(arg1)
        assert res[0] == 1<<42
        arg1.free()

    def test_callback(self):
        import _rawffi
        import struct
        libc = _rawffi.get_libc()
        ll_to_sort = _rawffi.Array('i')(4)
        for i in range(4):
            ll_to_sort[i] = 4-i
        qsort = libc.ptr('qsort', ['P', 'Z', 'Z', 'P'], None)
        bogus_args = []
        def compare(a, b):
            a1 = _rawffi.Array('i').fromaddress(_rawffi.Array('P').fromaddress(a, 1)[0], 1)
            a2 = _rawffi.Array('i').fromaddress(_rawffi.Array('P').fromaddress(b, 1)[0], 1)
            if a1[0] not in [1,2,3,4] or a2[0] not in [1,2,3,4]:
                bogus_args.append((a1[0], a2[0]))
            if a1[0] > a2[0]:
                return 1
            return -1
        a1 = ll_to_sort.byptr()
        a2 = _rawffi.Array('Z')(1)
        a2[0] = len(ll_to_sort)
        a3 = _rawffi.Array('Z')(1)
        a3[0] = struct.calcsize('i')
        cb = _rawffi.CallbackPtr(compare, ['P', 'P'], 'i')
        a4 = cb.byptr()
        qsort(a1, a2, a3, a4)
        res = [ll_to_sort[i] for i in range(len(ll_to_sort))]
        assert res == [1,2,3,4]
        assert not bogus_args
        a1.free()
        a2.free()
        a3.free()
        a4.free()
        ll_to_sort.free()
        cb.free()

    def test_another_callback(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        runcallback = lib.ptr('runcallback', ['P'], 'q')
        def callback():
            return 1<<42

        cb = _rawffi.CallbackPtr(callback, [], 'q')
        a1 = cb.byptr()
        res = runcallback(a1)
        assert res[0] == 1<<42
        a1.free()
        cb.free()

    def test_void_returning_callback(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        runcallback = lib.ptr('runcallback', ['P'], None)
        called = []
        def callback():
            called.append(True)

        cb = _rawffi.CallbackPtr(callback, [], None)
        a1 = cb.byptr()
        res = runcallback(a1)
        assert res is None
        assert called == [True]
        a1.free()
        cb.free()

    def test_raising_callback(self):
        import _rawffi, sys
        from io import StringIO
        lib = _rawffi.CDLL(self.lib_name)
        err = StringIO()
        orig = sys.stderr
        sys.stderr = err
        try:
            runcallback = lib.ptr('runcallback', ['P'], 'q')
            def callback():
                1/0

            cb = _rawffi.CallbackPtr(callback, [], 'q')
            a1 = cb.byptr()
            res = runcallback(a1)
            a1.free()
            cb.free()
            val = err.getvalue()
            assert 'ZeroDivisionError' in val
            assert 'callback' in val
            assert res[0] == 0
        finally:
            sys.stderr = orig

    def test_setattr_struct(self):
        import _rawffi
        X = _rawffi.Structure([('value1', 'i'), ('value2', 'i')])
        x = X()
        x.value1 = 1
        x.value2 = 2
        assert x.value1 == 1
        assert x.value2 == 2
        x.value1 = 3
        assert x.value1 == 3
        raises(AttributeError, "x.foo")
        raises(AttributeError, "x.foo = 1")
        x.free()

    def test_sizes_and_alignments(self):
        import _rawffi
        for k, (s, a) in self.sizes_and_alignments.items():
            assert _rawffi.sizeof(k) == s
            assert _rawffi.alignment(k) == a

    def test_unaligned(self):
        import _rawffi
        for k in self.float_typemap:
            S = _rawffi.Structure([('pad', 'c'), ('value', k)], pack=1)
            s = S()
            s.value = 4
            assert s.value == 4
            s.free()

    def test_array_addressof(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        alloc = lib.ptr('allocate_array', [], 'P')
        A = _rawffi.Array('i')
        res = alloc()
        a = A.fromaddress(res[0], 1)
        assert a[0] == 3
        assert A.fromaddress(a.buffer, 1)[0] == 3

    def test_shape(self):
        import _rawffi
        A = _rawffi.Array('i')
        a = A(1)
        assert a.shape is A
        a.free()
        S = _rawffi.Structure([('v1', 'i')])
        s = S()
        s.v1 = 3
        assert s.shape is S
        s.free()

    def test_negative_pointers(self):
        import _rawffi
        A = _rawffi.Array('P')
        a = A(1)
        a[0] = -1234
        a.free()

    def test_long_with_fromaddress(self):
        import _rawffi
        addr = -1
        raises(ValueError, _rawffi.Array('u').fromaddress, addr, 100)

    def test_passing_raw_pointers(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        A = _rawffi.Array('i')
        get_array_elem = lib.ptr('get_array_elem', ['P', 'i'], 'i')
        a = A(1)
        a[0] = 3
        arg1 = _rawffi.Array('P')(1)
        arg1[0] = a.buffer
        arg2 = _rawffi.Array('i')(1)
        res = get_array_elem(arg1, arg2)
        assert res[0] == 3
        arg1.free()
        arg2.free()
        a.free()

    def test_repr(self):
        import _rawffi, struct
        isize = struct.calcsize("i")
        lsize = struct.calcsize("l")
        assert (repr(_rawffi.Array('i')) ==
                "<_rawffi.Array 'i' (%d, %d)>" % (isize, isize))

        # fragile
        S = _rawffi.Structure([('x', 'c'), ('y', 'l')])
        assert (repr(_rawffi.Array((S, 2))) ==
                "<_rawffi.Array '\0' (%d, %d)>" % (4*lsize, lsize))

        assert (repr(_rawffi.Structure([('x', 'i'), ('yz', 'i')])) ==
                "<_rawffi.Structure 'x' 'yz' (%d, %d)>" % (2*isize, isize))

        s = _rawffi.Structure([('x', 'i'), ('yz', 'i')])()
        assert repr(s) == "<_rawffi struct %x>" % (s.buffer,)
        s.free()
        a = _rawffi.Array('i')(5)
        assert repr(a) == "<_rawffi array %x of length %d>" % (a.buffer,
                                                               len(a))
        a.free()

    def test_wide_char(self):
        import _rawffi, sys
        A = _rawffi.Array('u')
        a = A(3)
        a[0] = u'x'
        a[1] = u'y'
        a[2] = u'z'
        assert a[0] == u'x'
        b = _rawffi.Array('c').fromaddress(a.buffer, 38)
        if _rawffi.sizeof('u') == 4:
            # UCS4 build
            if sys.byteorder == 'big':
                assert b[0:8] == b'\x00\x00\x00x\x00\x00\x00y'
            else:
                assert b[0:5] == b'x\x00\x00\x00y'
        else:
            # UCS2 build
            print(b[0:4])
            assert b[0:4] == b'x\x00y\x00'
        a.free()

    def test_truncate(self):
        import _rawffi, struct
        a = _rawffi.Array('b')(1)
        a[0] = -5
        assert a[0] == -5
        a[0] = 123
        assert a[0] == 123
        a[0] = 0x97817182ab128111111111111171817d042
        assert a[0] == 0x42
        a[0] = 255
        assert a[0] == -1
        a[0] = -2
        assert a[0] == -2
        a[0] = -255
        assert a[0] == 1
        a.free()

        a = _rawffi.Array('B')(1)
        a[0] = 123
        assert a[0] == 123
        a[0] = 0x18329b1718b97d89b7198db817d042
        assert a[0] == 0x42
        a[0] = 255
        assert a[0] == 255
        a[0] = -2
        assert a[0] == 254
        a[0] = -255
        assert a[0] == 1
        a.free()

        a = _rawffi.Array('h')(1)
        a[0] = 123
        assert a[0] == 123
        a[0] = 0x9112cbc91bd91db19aaaaaaaaaaaaaa8170d42
        assert a[0] == 0x0d42
        a[0] = 65535
        assert a[0] == -1
        a[0] = -2
        assert a[0] == -2
        a[0] = -65535
        assert a[0] == 1
        a.free()

        a = _rawffi.Array('H')(1)
        a[0] = 123
        assert a[0] == 123
        a[0] = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeee817d042
        assert a[0] == 0xd042
        a[0] = -2
        assert a[0] == 65534
        a.free()

        maxptr = (256 ** struct.calcsize("P")) - 1
        a = _rawffi.Array('P')(1)
        a[0] = 123
        assert a[0] == 123
        a[0] = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeee817d042
        assert a[0] == 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeee817d042 & maxptr
        a[0] = -2
        assert a[0] == maxptr - 1
        a.free()

    def test_getaddressindll(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        def getprimitive(typecode, name):
            addr = lib.getaddressindll(name)
            return _rawffi.Array(typecode).fromaddress(addr, 1)
        a = getprimitive("l", "static_int")
        assert a[0] == 42
        a[0] = 43
        assert a[0] == 43
        a = getprimitive("d", "static_double")
        assert a[0] == 42.42
        a[0] = 43.43
        assert a[0] == 43.43
        a = getprimitive("g", "static_longdouble")
        assert a[0] == 42.42
        a[0] = 43.43
        assert a[0] == 43.43
        raises(ValueError, getprimitive, 'z', 'ddddddd')
        raises(ValueError, getprimitive, 'zzz', 'static_int')

    def test_segfault_exception(self):
        import _rawffi
        S = _rawffi.Structure([('x', 'i')])
        s = S()
        s.x = 3
        s.free()
        raises(_rawffi.SegfaultException, s.__getattr__, 'x')
        raises(_rawffi.SegfaultException, s.__setattr__, 'x', 3)
        A = _rawffi.Array('c')
        a = A(13)
        a.free()
        raises(_rawffi.SegfaultException, a.__getitem__, 3)
        raises(_rawffi.SegfaultException, a.__setitem__, 3, 3)

    def test_stackcheck(self):
        if self.platform != "msvc" or self.is64bit:
            skip("32-bit win32 msvc specific")

        # Even if the call corresponds to the specified signature,
        # the STDCALL calling convention may detect some errors
        import _rawffi
        lib = _rawffi.CDLL('kernel32')

        f = lib.ptr('SetLastError', [], 'i')
        try:
            f()
        except ValueError as e:
            assert "Procedure called with not enough arguments" in str(e)
        else:
            assert 0, "Did not raise"

        f = lib.ptr('GetLastError', ['i'], None,
                    flags=_rawffi.FUNCFLAG_STDCALL)
        arg = _rawffi.Array('i')(1)
        arg[0] = 1
        try:
            f(arg)
        except ValueError as e:
            assert "Procedure called with too many arguments" in str(e)
        else:
            assert 0, "Did not raise"
        arg.free()

    def test_struct_byvalue(self):
        import _rawffi, sys
        X_Y = _rawffi.Structure([('x', 'l'), ('y', 'l')])
        x_y = X_Y()
        lib = _rawffi.CDLL(self.lib_name)
        sum_x_y = lib.ptr('sum_x_y', [(X_Y, 1)], 'l')
        x_y.x = 200
        x_y.y = 220
        res = sum_x_y(x_y)
        assert res[0] == 420
        x_y.free()

    def test_callback_struct_byvalue(self):
        import _rawffi, sys
        X_Y = _rawffi.Structure([('x', 'l'), ('y', 'l')])
        lib = _rawffi.CDLL(self.lib_name)
        op_x_y = lib.ptr('op_x_y', [(X_Y, 1), 'P'], 'l')

        def callback(x_y):
            return x_y.x + x_y.y
        cb = _rawffi.CallbackPtr(callback, [(X_Y, 1)], 'l')

        x_y = X_Y()
        x_y.x = 200
        x_y.y = 220

        a1 = cb.byptr()
        res = op_x_y(x_y, a1)
        a1.free()
        x_y.free()
        cb.free()

        assert res[0] == 420

    def test_ret_struct(self):
        import _rawffi
        S2H = _rawffi.Structure([('x', 'h'), ('y', 'h')])
        s2h = S2H()
        lib = _rawffi.CDLL(self.lib_name)
        give = lib.ptr('give', ['h', 'h'], (S2H, 1))
        a1 = _rawffi.Array('h')(1)
        a2 = _rawffi.Array('h')(1)
        a1[0] = 13
        a2[0] = 17
        res = give(a1, a2)
        assert isinstance(res, _rawffi.StructureInstanceAutoFree)
        assert res.shape is S2H
        assert res.x == 13
        assert res.y == 17
        a1.free()
        a2.free()

        s2h.x = 7
        s2h.y = 11
        perturb = lib.ptr('perturb', [(S2H, 1)], (S2H, 1))
        res = perturb(s2h)
        assert isinstance(res, _rawffi.StructureInstanceAutoFree)
        assert res.shape is S2H
        assert res.x == 14
        assert res.y == 33
        assert s2h.x == 7
        assert s2h.y == 11

        s2h.free()

    def test_ret_struct_containing_array(self):
        import _rawffi
        AoI = _rawffi.Array('i')
        S2A = _rawffi.Structure([('bah', (AoI, 2))])
        lib = _rawffi.CDLL(self.lib_name)
        get_s2a = lib.ptr('get_s2a', [], (S2A, 1))
        check_s2a = lib.ptr('check_s2a', [(S2A, 1)], 'i')

        res = get_s2a()
        assert isinstance(res, _rawffi.StructureInstanceAutoFree)
        assert res.shape is S2A
        ok = check_s2a(res)
        assert ok[0] == 1

    def test_buffer(self):
        import _rawffi
        S = _rawffi.Structure((40, 1))
        s = S(autofree=True)
        b = memoryview(s)
        assert len(b) == 40
        b[4] = ord(b'X')
        b[:3] = b'ABC'
        assert b[:6] == b'ABC\x00X\x00'

        A = _rawffi.Array('c')
        a = A(10, autofree=True)
        a[3] = b'x'
        b = memoryview(a)
        assert len(b) == 10
        assert b[3] == b'x'
        b[6] = b'y'
        assert a[6] == b'y'
        b[3:5] = b'zt'
        assert a[3] == b'z'
        assert a[4] == b't'

        b = memoryview(a)
        assert len(b) == 10
        assert b[3] == b'z'
        b[3] = b'x'
        assert b[3] == b'x'

    def test_pypy_raw_address(self):
        import _rawffi
        S = _rawffi.Structure((40, 1))
        s = S(autofree=True)
        addr = memoryview(s)._pypy_raw_address()
        assert type(addr) is int
        assert memoryview(s)._pypy_raw_address() == addr
        assert memoryview(s)[10:]._pypy_raw_address() == addr + 10

    def test_union(self):
        import _rawffi
        longsize = _rawffi.sizeof('l')
        S = _rawffi.Structure([('x', 'h'), ('y', 'l')], union=True)
        s = S(autofree=False)
        s.x = 12345
        lib = _rawffi.CDLL(self.lib_name)
        f = lib.ptr('ret_un_func', [(S, 1)], (S, 1))
        ret = f(s)
        assert ret.y == 1234500, "ret.y == %d" % (ret.y,)
        s.free()

    def test_ffi_type(self):
        import _rawffi
        EMPTY = _rawffi.Structure([])
        S2E = _rawffi.Structure([('bah', (EMPTY, 1))])
        S2E.get_ffi_type()     # does not hang

    def test_overflow_error(self):
        import _rawffi
        A = _rawffi.Array('d')
        arg1 = A(1)
        raises(OverflowError, "arg1[0] = 10**900")
        arg1.free()

    def test_errno(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        A = _rawffi.Array('i')
        f = lib.ptr('check_errno', ['i'], 'i')
        _rawffi.set_errno(42)
        arg = A(1)
        arg[0] = 43
        res = f(arg)
        assert res[0] == 42
        z = _rawffi.get_errno()
        assert z == 43
        arg.free()

    def test_last_error(self):
        import sys
        if sys.platform != 'win32':
            skip("Windows test")
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        A = _rawffi.Array('i')
        f = lib.ptr('check_last_error', ['i'], 'i')
        _rawffi.set_last_error(42)
        arg = A(1)
        arg[0] = 43
        res = f(arg)
        assert res[0] == 42
        z = _rawffi.get_last_error()
        assert z == 43
        arg.free()

    def test_char_array_int(self):
        import _rawffi
        A = _rawffi.Array('c')
        a = A(1)
        a[0] = b'a'
        assert a[0] == b'a'
        # also accept int but return bytestring
        a[0] = 100
        assert a[0] == b'd'
        a.free()

    def test_cdll_name(self):
        import _rawffi
        lib = _rawffi.CDLL(self.lib_name)
        assert lib.name == self.lib_name

    def test_wcharp2rawunicode(self):
        import _rawffi
        A = _rawffi.Array('i')
        arg = A(1)
        arg[0] = 0x1234
        u = _rawffi.wcharp2rawunicode(arg.itemaddress(0))
        assert u == u'\u1234'
        u = _rawffi.wcharp2rawunicode(arg.itemaddress(0), 1)
        assert u == u'\u1234'
        arg[0] = -1
        if _rawffi.sizeof('u') == 4:
            raises(ValueError, _rawffi.wcharp2rawunicode, arg.itemaddress(0))
            raises(ValueError, _rawffi.wcharp2rawunicode, arg.itemaddress(0), 1)
            arg[0] = 0x110000
            raises(ValueError, _rawffi.wcharp2rawunicode, arg.itemaddress(0))
            raises(ValueError, _rawffi.wcharp2rawunicode, arg.itemaddress(0), 1)
        arg.free()


class AppTestAutoFree:
    spaceconfig = dict(usemodules=['_rawffi', 'struct'])

    def setup_class(cls):
        cls.w_sizes_and_alignments = cls.space.wrap(dict(
            [(k, (v.c_size, v.c_alignment)) for k,v in TYPEMAP.iteritems()]))
        Tracker.DO_TRACING = True

    def test_structure_autofree(self):
        import gc, _rawffi
        gc.collect()
        gc.collect()
        S = _rawffi.Structure([('x', 'i')])
        try:
            oldnum = _rawffi._num_of_allocated_objects()
        except RuntimeError:
            oldnum = '?'
        s = S(autofree=True)
        s.x = 3
        s = None
        gc.collect()
        if oldnum != '?':
            assert oldnum == _rawffi._num_of_allocated_objects()

    def test_array_autofree(self):
        import gc, _rawffi
        gc.collect()
        try:
            oldnum = _rawffi._num_of_allocated_objects()
        except RuntimeError:
            oldnum = '?'

        A = _rawffi.Array('c')
        a = A(6, b'xxyxx\x00', autofree=True)
        assert _rawffi.charp2string(a.buffer) == b'xxyxx'
        a = None
        gc.collect()
        if oldnum != '?':
            assert oldnum == _rawffi._num_of_allocated_objects()

    def teardown_class(cls):
        Tracker.DO_TRACING = False
