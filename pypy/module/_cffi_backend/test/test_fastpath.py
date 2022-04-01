# side-effect: FORMAT_LONGDOUBLE must be built before the first test
from pypy.module._cffi_backend import misc
from pypy.module._cffi_backend.ctypeobj import W_CType


class AppTest_fast_path_from_list(object):
    spaceconfig = dict(usemodules=('_cffi_backend',))

    def setup_method(self, meth):
        def forbidden(*args):
            assert False, 'The slow path is forbidden'
        self._original = W_CType.pack_list_of_items.im_func
        W_CType.pack_list_of_items = forbidden

    def teardown_method(self, meth):
        W_CType.pack_list_of_items = self._original

    def test_fast_init_from_list(self):
        import _cffi_backend
        LONG = _cffi_backend.new_primitive_type('long')
        P_LONG = _cffi_backend.new_pointer_type(LONG)
        LONG_ARRAY = _cffi_backend.new_array_type(P_LONG, None)
        buf = _cffi_backend.newp(LONG_ARRAY, [1, 2, 3])
        assert buf[0] == 1
        assert buf[1] == 2
        assert buf[2] == 3

    def test_fast_init_from_list_float(self):
        import _cffi_backend
        DOUBLE = _cffi_backend.new_primitive_type('double')
        P_DOUBLE = _cffi_backend.new_pointer_type(DOUBLE)
        DOUBLE_ARRAY = _cffi_backend.new_array_type(P_DOUBLE, None)
        buf = _cffi_backend.newp(DOUBLE_ARRAY, [1.1, 2.2, 3.3])
        assert buf[0] == 1.1
        assert buf[1] == 2.2
        assert buf[2] == 3.3

    def test_fast_init_short_from_list(self):
        import _cffi_backend
        SHORT = _cffi_backend.new_primitive_type('short')
        P_SHORT = _cffi_backend.new_pointer_type(SHORT)
        SHORT_ARRAY = _cffi_backend.new_array_type(P_SHORT, None)
        buf = _cffi_backend.newp(SHORT_ARRAY, [1, -2, 3])
        assert buf[0] == 1
        assert buf[1] == -2
        assert buf[2] == 3
        raises(OverflowError, _cffi_backend.newp, SHORT_ARRAY, [40000])
        raises(OverflowError, _cffi_backend.newp, SHORT_ARRAY, [-40000])

    def test_fast_init_longlong_from_list(self):
        import _cffi_backend
        import sys
        large_int = 2 ** (50 if sys.maxsize > 2**31 - 1 else 30)
        LONGLONG = _cffi_backend.new_primitive_type('long long')
        P_LONGLONG = _cffi_backend.new_pointer_type(LONGLONG)
        LONGLONG_ARRAY = _cffi_backend.new_array_type(P_LONGLONG, None)
        buf = _cffi_backend.newp(LONGLONG_ARRAY, [1, -2, 3, large_int])
        assert buf[0] == 1
        assert buf[1] == -2
        assert buf[2] == 3
        assert buf[3] == large_int

    def test_fast_init_ushort_from_list(self):
        import _cffi_backend
        USHORT = _cffi_backend.new_primitive_type('unsigned short')
        P_USHORT = _cffi_backend.new_pointer_type(USHORT)
        USHORT_ARRAY = _cffi_backend.new_array_type(P_USHORT, None)
        buf = _cffi_backend.newp(USHORT_ARRAY, [1, 2, 40000])
        assert buf[0] == 1
        assert buf[1] == 2
        assert buf[2] == 40000
        raises(OverflowError, _cffi_backend.newp, USHORT_ARRAY, [70000])
        raises(OverflowError, _cffi_backend.newp, USHORT_ARRAY, [-1])

    def test_fast_init_ulong_from_list(self):
        import sys
        import _cffi_backend
        maxlong = sys.maxsize
        if sys.platform == 'win32':
            # maxlong == 2**31-1 < sys.maxsize == 2**63-1 on win64!
            maxlong = int(2**31-1)
        ULONG = _cffi_backend.new_primitive_type('unsigned long')
        P_ULONG = _cffi_backend.new_pointer_type(ULONG)
        ULONG_ARRAY = _cffi_backend.new_array_type(P_ULONG, None)
        buf = _cffi_backend.newp(ULONG_ARRAY, [1, 2, maxlong])
        assert buf[0] == 1
        assert buf[1] == 2
        assert buf[2] == maxlong
        raises(OverflowError, _cffi_backend.newp, ULONG_ARRAY, [-1])
        raises(OverflowError, _cffi_backend.newp, ULONG_ARRAY, [-maxlong])

    def test_fast_init_cfloat_from_list(self):
        import _cffi_backend
        FLOAT = _cffi_backend.new_primitive_type('float')
        P_FLOAT = _cffi_backend.new_pointer_type(FLOAT)
        FLOAT_ARRAY = _cffi_backend.new_array_type(P_FLOAT, None)
        buf = _cffi_backend.newp(FLOAT_ARRAY, [1.25, -3.5])
        assert buf[0] == 1.25
        assert buf[1] == -3.5

    def test_fast_init_clongdouble_from_list(self):
        import _cffi_backend
        LONGDOUBLE = _cffi_backend.new_primitive_type('long double')
        P_LONGDOUBLE = _cffi_backend.new_pointer_type(LONGDOUBLE)
        LONGDOUBLE_ARRAY = _cffi_backend.new_array_type(P_LONGDOUBLE, None)
        buf = _cffi_backend.newp(LONGDOUBLE_ARRAY, [1.25, -3.5])
        assert float(buf[0]) == 1.25
        assert float(buf[1]) == -3.5

    def test_fast_init_bool_from_list(self):
        import _cffi_backend
        BOOL = _cffi_backend.new_primitive_type('_Bool')
        P_BOOL = _cffi_backend.new_pointer_type(BOOL)
        BOOL_ARRAY = _cffi_backend.new_array_type(P_BOOL, None)
        buf = _cffi_backend.newp(BOOL_ARRAY, [1, 0])
        assert buf[0] is True
        assert buf[1] is False
        raises(OverflowError, _cffi_backend.newp, BOOL_ARRAY, [2])
        raises(OverflowError, _cffi_backend.newp, BOOL_ARRAY, [-1])


class AppTest_fast_path_bug(object):
    spaceconfig = dict(usemodules=('_cffi_backend',))

    def test_bug_not_list_or_tuple(self):
        import _cffi_backend
        LONG = _cffi_backend.new_primitive_type('long')
        P_LONG = _cffi_backend.new_pointer_type(LONG)
        LONG_ARRAY_2 = _cffi_backend.new_array_type(P_LONG, 2)
        P_LONG_ARRAY_2 = _cffi_backend.new_pointer_type(LONG_ARRAY_2)
        LONG_ARRAY_ARRAY = _cffi_backend.new_array_type(P_LONG_ARRAY_2, None)
        raises(TypeError, _cffi_backend.newp, LONG_ARRAY_ARRAY, [set([4, 5])])


class AppTest_fast_path_to_list(object):
    spaceconfig = dict(usemodules=('_cffi_backend',))

    def setup_method(self, meth):
        from pypy.interpreter import gateway
        from rpython.rlib import rrawarray
        #
        self.count = 0
        def get_count(*args):
            return self.space.wrap(self.count)
        self.w_get_count = self.space.wrap(gateway.interp2app(get_count))
        #
        original = rrawarray.populate_list_from_raw_array
        def populate_list_from_raw_array(*args):
            self.count += 1
            return original(*args)
        self._original = original
        rrawarray.populate_list_from_raw_array = populate_list_from_raw_array
        #
        original2 = misc.unpack_list_from_raw_array
        def unpack_list_from_raw_array(*args):
            self.count += 1
            return original2(*args)
        self._original2 = original2
        misc.unpack_list_from_raw_array = unpack_list_from_raw_array
        #
        original3 = misc.unpack_cfloat_list_from_raw_array
        def unpack_cfloat_list_from_raw_array(*args):
            self.count += 1
            return original3(*args)
        self._original3 = original3
        misc.unpack_cfloat_list_from_raw_array = (
            unpack_cfloat_list_from_raw_array)
        #
        original4 = misc.unpack_unsigned_list_from_raw_array
        def unpack_unsigned_list_from_raw_array(*args):
            self.count += 1
            return original4(*args)
        self._original4 = original4
        misc.unpack_unsigned_list_from_raw_array = (
            unpack_unsigned_list_from_raw_array)
        #
        self.w_runappdirect = self.space.wrap(self.runappdirect)


    def teardown_method(self, meth):
        from rpython.rlib import rrawarray
        rrawarray.populate_list_from_raw_array = self._original
        misc.unpack_list_from_raw_array = self._original2
        misc.unpack_cfloat_list_from_raw_array = self._original3
        misc.unpack_unsigned_list_from_raw_array = self._original4

    def test_list_int(self):
        import _cffi_backend
        LONG = _cffi_backend.new_primitive_type('long')
        P_LONG = _cffi_backend.new_pointer_type(LONG)
        LONG_ARRAY = _cffi_backend.new_array_type(P_LONG, 3)
        buf = _cffi_backend.newp(LONG_ARRAY)
        buf[0] = 1
        buf[1] = 2
        buf[2] = 3
        lst = list(buf)
        assert lst == [1, 2, 3]
        if not self.runappdirect:
            assert self.get_count() == 1

    def test_TypeError_if_no_length(self):
        import _cffi_backend
        LONG = _cffi_backend.new_primitive_type('long')
        P_LONG = _cffi_backend.new_pointer_type(LONG)
        LONG_ARRAY = _cffi_backend.new_array_type(P_LONG, 3)
        buf = _cffi_backend.newp(LONG_ARRAY)
        pbuf = _cffi_backend.cast(P_LONG, buf)
        raises(TypeError, "list(pbuf)")

    def test_bug(self):
        import _cffi_backend
        LONG = _cffi_backend.new_primitive_type('long')
        five = _cffi_backend.cast(LONG, 5)
        raises(TypeError, list, five)
        DOUBLE = _cffi_backend.new_primitive_type('double')
        five_and_a_half = _cffi_backend.cast(DOUBLE, 5.5)
        raises(TypeError, list, five_and_a_half)

    def test_list_float(self):
        import _cffi_backend
        DOUBLE = _cffi_backend.new_primitive_type('double')
        P_DOUBLE = _cffi_backend.new_pointer_type(DOUBLE)
        DOUBLE_ARRAY = _cffi_backend.new_array_type(P_DOUBLE, 3)
        buf = _cffi_backend.newp(DOUBLE_ARRAY)
        buf[0] = 1.1
        buf[1] = 2.2
        buf[2] = 3.3
        lst = list(buf)
        assert lst == [1.1, 2.2, 3.3]
        if not self.runappdirect:
            assert self.get_count() == 1

    def test_list_short(self):
        import _cffi_backend
        SHORT = _cffi_backend.new_primitive_type('short')
        P_SHORT = _cffi_backend.new_pointer_type(SHORT)
        SHORT_ARRAY = _cffi_backend.new_array_type(P_SHORT, 3)
        buf = _cffi_backend.newp(SHORT_ARRAY)
        buf[0] = 1
        buf[1] = 2
        buf[2] = 3
        lst = list(buf)
        assert lst == [1, 2, 3]
        if not self.runappdirect:
            assert self.get_count() == 1

    def test_list_ushort(self):
        import _cffi_backend
        USHORT = _cffi_backend.new_primitive_type('unsigned short')
        P_USHORT = _cffi_backend.new_pointer_type(USHORT)
        USHORT_ARRAY = _cffi_backend.new_array_type(P_USHORT, 3)
        buf = _cffi_backend.newp(USHORT_ARRAY)
        buf[0] = 1
        buf[1] = 2
        buf[2] = 50505
        lst = list(buf)
        assert lst == [1, 2, 50505]
        if not self.runappdirect:
            assert self.get_count() == 1

    def test_list_cfloat(self):
        import _cffi_backend
        FLOAT = _cffi_backend.new_primitive_type('float')
        P_FLOAT = _cffi_backend.new_pointer_type(FLOAT)
        FLOAT_ARRAY = _cffi_backend.new_array_type(P_FLOAT, 3)
        buf = _cffi_backend.newp(FLOAT_ARRAY)
        buf[0] = 1.25
        buf[1] = -2.5
        buf[2] = 3.75
        lst = list(buf)
        assert lst == [1.25, -2.5, 3.75]
        if not self.runappdirect:
            assert self.get_count() == 1

    def test_too_many_initializers(self):
        import _cffi_backend
        ffi = _cffi_backend.FFI()
        raises(IndexError, ffi.new, "int[4]", [10, 20, 30, 40, 50])
        raises(IndexError, ffi.new, "int[4]", tuple(range(999)))
        raises(IndexError, ffi.new, "unsigned int[4]", [10, 20, 30, 40, 50])
        raises(IndexError, ffi.new, "float[4]", [10, 20, 30, 40, 50])
        raises(IndexError, ffi.new, "long double[4]", [10, 20, 30, 40, 50])
        raises(IndexError, ffi.new, "char[4]", [10, 20, 30, 40, 50])
        raises(IndexError, ffi.new, "wchar_t[4]", [10, 20, 30, 40, 50])
        raises(IndexError, ffi.new, "_Bool[4]", [10, 20, 30, 40, 50])
        raises(IndexError, ffi.new, "int[4][4]", [[3,4,5,6]] * 5)
        raises(IndexError, ffi.new, "int[4][4]", [[3,4,5,6,7]] * 4)
