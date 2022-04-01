import sys
from rpython.rlib.rarithmetic import r_uint, r_singlefloat, r_longlong, r_ulonglong
from rpython.rlib.libffi import IS_32_BIT
from pypy.module._rawffi.alt.interp_ffitype import app_types, descr_new_pointer
from pypy.module._rawffi.alt.type_converter import FromAppLevelConverter, ToAppLevelConverter

class DummyFromAppLevelConverter(FromAppLevelConverter):

    def handle_all(self, w_ffitype, w_obj, val, lgt=None):
        self.lastval = val

    handle_signed = handle_all
    handle_unsigned = handle_all
    handle_pointer = handle_all
    handle_char = handle_all
    handle_unichar = handle_all
    handle_longlong = handle_all
    handle_char_p = handle_all
    handle_unichar_p = handle_all
    handle_float = handle_all
    handle_singlefloat = handle_all

    def handle_struct(self, w_ffitype, w_structinstance):
        self.lastval = w_structinstance

    def convert(self, w_ffitype, w_obj):
        self.unwrap_and_do(w_ffitype, w_obj)
        return self.lastval


class TestFromAppLevel(object):
    spaceconfig = dict(usemodules=('_rawffi',))

    def setup_class(cls):
        converter = DummyFromAppLevelConverter(cls.space)
        cls.from_app_level = staticmethod(converter.convert)

    def check(self, w_ffitype, w_obj, expected):
        v = self.from_app_level(w_ffitype, w_obj)
        assert v == expected
        assert type(v) is type(expected)

    def test_int(self):
        self.check(app_types.sint, self.space.wrap(42), 42)
        self.check(app_types.sint, self.space.wrap(sys.maxint+1), -sys.maxint-1)
        self.check(app_types.sint, self.space.wrap(sys.maxint*2), -2)

    def test_unsigned(self):
        space = self.space
        self.check(app_types.uint, space.wrap(42), r_uint(42))
        self.check(app_types.uint, space.wrap(-1), r_uint(sys.maxint*2 +1))
        self.check(app_types.uint, space.wrap(sys.maxint*3),
                   r_uint(sys.maxint - 2))
        self.check(app_types.ulong, space.wrap(sys.maxint+12),
                   r_uint(sys.maxint+12))
        self.check(app_types.ulong, space.wrap(sys.maxint*2+3), r_uint(1))

    def test_char(self):
        space = self.space
        self.check(app_types.char, space.wrap('a'), ord('a'))
        self.check(app_types.unichar, space.wrap(u'\u1234'), 0x1234)

    def test_signed_longlong(self):
        space = self.space
        maxint32 = 2147483647 # we cannot really go above maxint on 64 bits
                              # (and we would not test anything, as there long
                              # is the same as long long)
        expected = maxint32+1
        if IS_32_BIT:
            expected = r_longlong(expected)
        self.check(app_types.slonglong, space.wrap(maxint32+1), expected)

    def test_unsigned_longlong(self):
        space = self.space
        maxint64 = 9223372036854775807 # maxint64+1 does not fit into a
                                       # longlong, but it does into a
                                       # ulonglong
        if IS_32_BIT:
            # internally, the type converter always casts to signed longlongs
            expected = r_longlong(-maxint64-1)
        else:
            # on 64 bit, ulonglong == uint (i.e., unsigned long in C terms)
            expected = r_uint(maxint64+1)
        self.check(app_types.ulonglong, space.wrap(maxint64+1), expected)

    def test_float_and_double(self):
        space = self.space
        self.check(app_types.float, space.wrap(12.34), r_singlefloat(12.34))
        self.check(app_types.double, space.wrap(12.34), 12.34)

    def test_pointer(self):
        # pointers are "unsigned" at applevel, but signed at interp-level (for
        # no good reason, at interp-level Signed or Unsigned makes no
        # difference for passing bits around)
        space = self.space
        self.check(app_types.void_p, space.wrap(42), 42)
        self.check(app_types.void_p, space.wrap(sys.maxint+1), -sys.maxint-1)
        #
        # typed pointers
        w_ptr_sint = descr_new_pointer(space, None, app_types.sint)
        self.check(w_ptr_sint, space.wrap(sys.maxint+1), -sys.maxint-1)


    def test__as_ffi_pointer_(self):
        space = self.space
        w_MyPointerWrapper = space.appexec([], """():
            from _rawffi.alt import types
            class MyPointerWrapper(object):
                def __init__(self, value):
                    self.value = value
                def _as_ffi_pointer_(self, ffitype):
                    assert ffitype is types.void_p
                    return self.value

            return MyPointerWrapper
        """)
        w_obj = space.call_function(w_MyPointerWrapper, space.wrap(42))
        self.check(app_types.void_p, w_obj, 42)

    def test_strings(self):
        # first, try automatic conversion from applevel
        self.check(app_types.char_p, self.space.newbytes('foo'), 'foo')
        self.check(app_types.unichar_p, self.space.wrap(u'foo\u1234'), u'foo\u1234'.encode('utf8'))
        self.check(app_types.unichar_p, self.space.wrap('foo'), 'foo')
        # then, try to pass explicit pointers
        self.check(app_types.char_p, self.space.wrap(42), 42)
        self.check(app_types.unichar_p, self.space.wrap(42), 42)



class DummyToAppLevelConverter(ToAppLevelConverter):

    def get_all(self, w_ffitype):
        return self.val

    get_signed = get_all
    get_unsigned = get_all
    get_pointer = get_all
    get_char = get_all
    get_unichar = get_all
    get_longlong = get_all
    get_char_p = get_all
    get_unichar_p = get_all
    get_float = get_all
    get_singlefloat = get_all
    get_unsigned_which_fits_into_a_signed = get_all

    def convert(self, w_ffitype, val):
        self.val = val
        return self.do_and_wrap(w_ffitype)


class TestToAppLevel(object):
    spaceconfig = dict(usemodules=('_rawffi',))

    def setup_class(cls):
        converter = DummyToAppLevelConverter(cls.space)
        cls.from_app_level = staticmethod(converter.convert)

    def check(self, w_ffitype, val, w_expected):
        w_v = self.from_app_level(w_ffitype, val)
        assert self.space.eq_w(w_v, w_expected)

    def test_int(self):
        self.check(app_types.sint, 42, self.space.wrap(42))
        self.check(app_types.sint, -sys.maxint-1, self.space.wrap(-sys.maxint-1))

    def test_uint(self):
        self.check(app_types.uint, 42, self.space.wrap(42))
        self.check(app_types.uint, r_uint(sys.maxint+1), self.space.wrap(sys.maxint+1))
