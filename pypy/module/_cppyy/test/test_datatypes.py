import py, os, sys
from pytest import raises
from .support import setup_make, soext

currpath = py.path.local(__file__).dirpath()
test_dct = str(currpath.join("datatypesDict"))+soext

def setup_module(mod):
    setup_make("datatypes")


class AppTestDATATYPES:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_datatypes = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))
        cls.w_N = cls.space.appexec([], """():
            import _cppyy
            return _cppyy.gbl.N""")
        cls.w_has_byte = cls.space.appexec([], """():
            import _cppyy
            return 201402 < _cppyy.gbl.gInterpreter.ProcessLine("__cplusplus;")""")

    def test01_instance_data_read_access(self):
        """Read access to instance public data and verify values"""

        import sys
        import _cppyy as cppyy

        if sys.hexversion >= 0x3000000:
            pyunicode = str
        else:
            pyunicode = unicode

        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        # reading boolean type
        assert c.m_bool == False
        assert not c.get_bool(); assert not c.get_bool_cr(); assert not c.get_bool_r()

        # reading char types
        assert c.m_char  == b'a'
        assert c.m_schar == b'b'
        assert c.m_uchar == b'c'
        assert type(c.m_wchar) == pyunicode
        assert c.m_wchar == u'D'
        assert type(c.m_char16) == pyunicode
        assert c.m_char16 == u'\u00df'
        assert type(c.m_char32) == pyunicode
        assert c.m_char32 == u'\u00df'

        # reading integer types
        assert c.m_int8    == - 9; assert c.get_int8_cr()    == - 9; assert c.get_int8_r()    == - 9
        assert c.m_uint8   ==   9; assert c.get_uint8_cr()   ==   9; assert c.get_uint8_r()   ==   9
        if self.has_byte:
            assert c.m_byte == ord('d'); assert c.get_byte_cr() == ord('d'); assert c.get_byte_r() == ord('d')
        assert c.m_short   == -11; assert c.get_short_cr()   == -11; assert c.get_short_r()   == -11
        assert c.m_ushort  ==  11; assert c.get_ushort_cr()  ==  11; assert c.get_ushort_r()  ==  11
        assert c.m_int     == -22; assert c.get_int_cr()     == -22; assert c.get_int_r()     == -22
        assert c.m_uint    ==  22; assert c.get_uint_cr()    ==  22; assert c.get_uint_r()    ==  22
        assert c.m_long    == -33; assert c.get_long_cr()    == -33; assert c.get_long_r()    == -33
        assert c.m_ulong   ==  33; assert c.get_ulong_cr()   ==  33; assert c.get_ulong_r()   ==  33
        assert c.m_llong   == -44; assert c.get_llong_cr()   == -44; assert c.get_llong_r()   == -44
        assert c.m_ullong  ==  44; assert c.get_ullong_cr()  ==  44; assert c.get_ullong_r()  ==  44
        assert c.m_long64  == -55; assert c.get_long64_cr()  == -55; assert c.get_long64_r()  == -55
        assert c.m_ulong64 ==  55; assert c.get_ulong64_cr() ==  55; assert c.get_ulong64_r() ==  55

        # reading floating point types
        assert round(c.m_float          + 66.,  5) == 0
        assert round(c.get_float_cr()   + 66.,  5) == 0
        assert round(c.get_float_r()    + 66.,  5) == 0
        assert round(c.m_double         + 77., 11) == 0
        assert round(c.get_double_cr()  + 77., 11) == 0
        assert round(c.get_double_r()   + 77., 11) == 0
        assert round(c.m_ldouble        + 88., 24) == 0
        assert round(c.get_ldouble_cr() + 88., 24) == 0
        assert round(c.get_ldouble_r()  + 88., 24) == 0
        assert round(c.get_ldouble_def()  -1., 24) == 0
        assert round(c.get_ldouble_def(2) -2., 24) == 0

        # complex<double> type
        assert type(c.get_complex()) == complex
        assert round(c.get_complex().real    -  99., 11) == 0
        assert round(c.get_complex().imag    - 101., 11) == 0
        assert repr(c.get_complex()) == '(99+101j)'
        assert round(c.get_complex_cr().real -  99., 11) == 0
        assert round(c.get_complex_cr().imag - 101., 11) == 0
        assert round(c.get_complex_r().real  -  99., 11) == 0
        assert round(c.get_complex_r().imag  - 101., 11) == 0
        assert complex(cppyy.gbl.std.complex['double'](1, 2)) == complex(1, 2)
        assert repr(cppyy.gbl.std.complex['double'](1, 2)) == '(1+2j)'

        # complex<int> retains C++ type in all cases (but includes pythonization to
        # resemble Python's complex more closely
        assert type(c.get_icomplex()) == cppyy.gbl.std.complex[int]
        assert round(c.get_icomplex().real    - 121., 11) == 0
        assert round(c.get_icomplex().imag    - 141., 11) == 0
        assert repr(c.get_icomplex()) == '(121+141j)'
        assert round(c.get_icomplex_cr().real - 121., 11) == 0
        assert round(c.get_icomplex_cr().imag - 141., 11) == 0
        assert type(c.get_icomplex_r()) == cppyy.gbl.std.complex[int]
        assert round(c.get_icomplex_r().real  - 121., 11) == 0
        assert round(c.get_icomplex_r().imag  - 141., 11) == 0
        assert complex(cppyy.gbl.std.complex['int'](1, 2)) == complex(1, 2)

        # reading of enum types
        assert c.m_enum == CppyyTestData.kNothing
        assert c.m_enum == c.kNothing

        # reading of boolean array
        for i in range(self.N):
            assert c.m_bool_array[i]        ==   bool(i%2)
            assert c.get_bool_array()[i]    ==   bool(i%2)
            assert c.m_bool_array2[i]       ==   bool((i+1)%2)
            assert c.get_bool_array2()[i]   ==   bool((i+1)%2)

        # reading of integer array types
        names = ['schar', 'uchar', 'short', 'ushort',    'int', 'uint',    'long',  'ulong']
        alpha = [ (1, 2), (1, 2), (-1, -2),   (3, 4), (-5, -6), (7, 8), (-9, -10), (11, 12)]
        if self.has_byte: names.append('byte'); alpha.append((3,4))

        for j in range(self.N):
            assert getattr(c, 'm_%s_array'    % names[i])[i]   == alpha[i][0]*i
            assert getattr(c, 'get_%s_array'  % names[i])()[i] == alpha[i][0]*i
            assert getattr(c, 'm_%s_array2'   % names[i])[i]   == alpha[i][1]*i
            assert getattr(c, 'get_%s_array2' % names[i])()[i] == alpha[i][1]*i

        # reading of floating point array types
        for k in range(self.N):
            assert round(c.m_float_array[k]   + 13.*k, 5) == 0
            assert round(c.m_float_array2[k]  + 14.*k, 5) == 0
            assert round(c.m_double_array[k]  + 15.*k, 8) == 0
            assert round(c.m_double_array2[k] + 16.*k, 8) == 0

        # out-of-bounds checks
        raises(IndexError, c.m_schar_array.__getitem__,  self.N)
        raises(IndexError, c.m_uchar_array.__getitem__,  self.N)
        if self.has_byte:
            raises(IndexError, c.m_byte_array.__getitem__,   self.N)
        raises(IndexError, c.m_short_array.__getitem__,  self.N)
        raises(IndexError, c.m_ushort_array.__getitem__, self.N)
        raises(IndexError, c.m_int_array.__getitem__,    self.N)
        raises(IndexError, c.m_uint_array.__getitem__,   self.N)
        raises(IndexError, c.m_long_array.__getitem__,   self.N)
        raises(IndexError, c.m_ulong_array.__getitem__,  self.N)
        raises(IndexError, c.m_float_array.__getitem__,  self.N)
        raises(IndexError, c.m_double_array.__getitem__, self.N)

        # can not access an instance member on the class
        raises(AttributeError, getattr, CppyyTestData, 'm_bool')
        raises(AttributeError, getattr, CppyyTestData, 'm_int')

        assert not hasattr(CppyyTestData, 'm_bool')
        assert not hasattr(CppyyTestData, 'm_int')

        c.__destruct__()

    def test02_instance_data_write_access(self):
        """Test write access to instance public data and verify values"""

        import sys
        import _cppyy as cppyy

        if sys.hexversion >= 0x3000000:
            pyunicode = str
        else:
            pyunicode = unicode

        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        # boolean types through functions
        c.set_bool(True);  assert c.get_bool() == True
        c.set_bool(0);     assert c.get_bool() == False

        # boolean types through data members
        c.m_bool = True;   assert c.get_bool() == True
        c.set_bool(True);  assert c.m_bool     == True
        c.m_bool = 0;      assert c.get_bool() == False
        c.set_bool(0);     assert c.m_bool     == False

        raises(ValueError, c.set_bool, 10)

        # char types through functions
        c.set_char('c');   assert c.get_char()  == b'c'
        c.set_char(b'b');  assert c.get_char()  == b'b'
        c.set_uchar('e');  assert c.get_uchar() == b'e'
        c.set_uchar(b'd'); assert c.get_uchar() == b'd'
        c.set_char16(u'\u00f2');     assert c.get_char16() == u'\u00f2'
        c.set_char32(u'\U0001f31c'); assert c.get_char32() == u'\U0001f31c'

        # char types through data members
        c.m_char = 'b';    assert c.get_char()  == b'b'
        c.m_char = 40;     assert c.get_char()  == str.encode(chr(40))
        c.set_char('c');   assert c.m_char      == b'c'
        c.set_char(41);    assert c.m_char      == str.encode(chr(41))
        c.m_uchar = 'd';   assert c.get_uchar() == b'd'
        c.m_uchar = 42;    assert c.get_uchar() == str.encode(chr(42))
        c.set_uchar('e');  assert c.m_uchar     == b'e'
        c.set_uchar(43);   assert c.m_uchar     == str.encode(chr(43))
        c.m_wchar = u'G';  assert c.get_wchar() ==    u'G'
        c.set_wchar(u'H'); assert c.m_wchar     ==    u'H'
        c.m_char16 = u'\u00f3';  assert c.get_char16() == u'\u00f3'
        c.set_char16(u'\u00f4'); assert c.m_char16     == u'\u00f4'
        c.m_char32 = u'\U0001f31d';  assert c.get_char32() == u'\U0001f31d'
        c.set_char32(u'\U0001f31e'); assert c.m_char32     == u'\U0001f31e'

        raises(ValueError, c.set_char,   "string")
        raises(ValueError, c.set_char,   500)
        raises(ValueError, c.set_uchar,  "string")
        raises(ValueError, c.set_uchar,  -1)
        raises(ValueError, c.set_wchar,  "string")
        raises(ValueError, c.set_char16, "string")
        raises(ValueError, c.set_char32, "string")

        # integer types
        names = ['int8', 'uint8', 'short', 'ushort', 'int', 'uint', 'long', 'ulong', 'llong', 'ullong']
        if self.has_byte: names.append('byte')

        for i in range(len(names)):
            setattr(c, 'm_'+names[i], i)
            assert eval('c.get_%s()' % names[i]) == i

        for i in range(len(names)):
            getattr(c, 'set_'+names[i])(2*i)
            assert eval('c.m_%s' % names[i]) == 2*i

        for i in range(len(names)):
            getattr(c, 'set_'+names[i]+'_cr')(3*i)
            assert eval('c.m_%s' % names[i]) == 3*i

        # float types through functions
        c.set_float(0.123);   assert round(c.get_float()   - 0.123, 5) == 0
        c.set_double(0.456);  assert round(c.get_double()  - 0.456, 8) == 0
        c.set_ldouble(0.789); assert round(c.get_ldouble() - 0.789, 8) == 0

        # float types through data members
        c.m_float = 0.123;       assert round(c.get_float()   - 0.123, 5) == 0
        c.set_float(0.234);      assert round(c.m_float       - 0.234, 5) == 0
        c.set_float_cr(0.456);   assert round(c.m_float       - 0.456, 5) == 0
        c.m_double = 0.678;      assert round(c.get_double()  - 0.678, 8) == 0
        c.set_double(0.890);     assert round(c.m_double      - 0.890, 8) == 0
        c.set_double_cr(0.012);  assert round(c.m_double      - 0.012, 8) == 0
        c.m_ldouble = 0.876;     assert round(c.get_ldouble() - 0.876, 8) == 0
        c.set_ldouble(0.098);    assert round(c.m_ldouble     - 0.098, 8) == 0
        c.set_ldouble_cr(0.210); assert round(c.m_ldouble     - 0.210, 8) == 0

        # arrays; there will be pointer copies, so destroy the current ones
        c.destroy_arrays()

        # integer arrays
        names = ['uchar', 'short', 'ushort', 'int', 'uint', 'long', 'ulong']
        if self.has_byte: names.append('byte')

        import array
        a = range(self.N)
        atypes = ['B', 'h', 'H', 'i', 'I', 'l', 'L']
        if self.has_byte: atypes.append('B')
        for j in range(len(names)):
            b = array.array(atypes[j], a)
            setattr(c, 'm_'+names[j]+'_array', b)     # buffer copies
            for i in range(self.N):
                assert eval('c.m_%s_array[i]' % names[j]) == b[i]

            setattr(c, 'm_'+names[j]+'_array2', b)    # pointer copies
            assert 3 < self.N
            b[3] = 28
            for i in range(self.N):
                assert eval('c.m_%s_array2[i]' % names[j]) == b[i]

        # can not write to constant data
        assert c.m_const_int == 17
        raises(TypeError, setattr, c, 'm_const_int', 71)

        c.__destruct__()

    def test03_array_passing(self):
        """Test passing of array arguments"""

        import _cppyy as cppyy, array, sys
        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        a = range(self.N)
        # test arrays in mixed order, to give overload resolution a workout
        for t in ['d', 'i', 'f', 'H', 'I', 'h', 'L', 'l']:
            b = array.array(t, a)

            # typed passing
            ca = c.pass_array(b)
            assert type(ca[0]) == type(b[0])
            assert len(b) == self.N
            for i in range(self.N):
                assert ca[i] == b[i]

            # void* passing
            ca = eval('c.pass_void_array_%s(b)' % t)
            assert type(ca[0]) == type(b[0])
            assert len(b) == self.N
            for i in range(self.N):
                assert ca[i] == b[i]

        # NULL/nullptr passing (will use short*)
        assert not c.pass_array(0)
        raises(Exception, c.pass_array(0).__getitem__, 0)    # raises SegfaultException
        assert raises(TypeError, c.pass_array, None)
        assert not c.pass_array(cppyy.nullptr)
        raises(Exception, c.pass_array(cppyy.nullptr).__getitem__, 0) # id. id.

        c.__destruct__()

    def test04_class_read_access(self):
        """Test read access to class public data and verify values"""

        import sys
        import _cppyy as cppyy

        if sys.hexversion >= 0x3000000:
            pylong = int
            pyunicode = str
        else:
            pylong = long
            pyunicode = unicode

        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        # char types
        assert CppyyTestData.s_char    == b'c'
        assert c.s_char                == b'c'
        assert c.s_uchar               == b'u'
        assert CppyyTestData.s_uchar   == b'u'
        assert CppyyTestData.s_wchar    == u'U'
        assert c.s_wchar                == u'U'
        assert CppyyTestData.s_char16   == u'\u6c29'
        assert c.s_char16               == u'\u6c29'
        assert CppyyTestData.s_char32   == u'\U0001f34b'
        assert c.s_char32               == u'\U0001f34b'

        assert type(c.s_wchar)              == pyunicode
        assert type(CppyyTestData.s_wchar)  == pyunicode
        assert type(c.s_char16)             == pyunicode
        assert type(CppyyTestData.s_char16) == pyunicode
        assert type(c.s_char32)             == pyunicode
        assert type(CppyyTestData.s_char32) == pyunicode

        # integer types
        if self.has_byte:
            assert CppyyTestData.s_byte == ord('b')
            assert c.s_byte             == ord('b')
        assert CppyyTestData.s_int8     == - 87
        assert c.s_int8                 == - 87
        assert CppyyTestData.s_uint8    ==   87
        assert c.s_uint8                ==   87
        assert CppyyTestData.s_short    == -101
        assert c.s_short                == -101
        assert c.s_ushort               ==  255
        assert CppyyTestData.s_ushort   ==  255
        assert CppyyTestData.s_int      == -202
        assert c.s_int                  == -202
        assert c.s_uint                 ==  202
        assert CppyyTestData.s_uint     ==  202
        assert CppyyTestData.s_long     == -pylong(303)
        assert c.s_long                 == -pylong(303)
        assert c.s_ulong                ==  pylong(303)
        assert CppyyTestData.s_ulong    ==  pylong(303)
        assert CppyyTestData.s_llong    == -pylong(404)
        assert c.s_llong                == -pylong(404)
        assert c.s_ullong               ==  pylong(404)
        assert CppyyTestData.s_ullong   ==  pylong(404)

        # floating point types
        assert round(CppyyTestData.s_float   + 606., 5) == 0
        assert round(c.s_float               + 606., 5) == 0
        assert round(CppyyTestData.s_double  + 707., 8) == 0
        assert round(c.s_double              + 707., 8) == 0
        assert round(CppyyTestData.s_ldouble + 808., 8) == 0
        assert round(c.s_ldouble             + 808., 8) == 0

        c.__destruct__()

    def test05_class_data_write_access(self):
        """Test write access to class public data and verify values"""

        import sys
        import _cppyy as cppyy

        if sys.hexversion >= 0x3000000:
            pylong = int
        else:
            pylong = long

        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        # char types
        CppyyTestData.s_char           =  'a'
        assert c.s_char               == b'a'
        c.s_char                       =  'b'
        assert CppyyTestData.s_char   == b'b'
        CppyyTestData.s_uchar          =  'c'
        assert c.s_uchar              == b'c'
        c.s_uchar                      =  'd'
        assert CppyyTestData.s_uchar  == b'd'
        raises(ValueError, setattr, CppyyTestData, 's_uchar', -1)
        raises(ValueError, setattr, c,             's_uchar', -1)
        CppyyTestData.s_wchar            = u'K'
        assert c.s_wchar                == u'K'
        c.s_wchar                        = u'L'
        assert CppyyTestData.s_wchar    == u'L'
        CppyyTestData.s_char16           = u'\u00df'
        assert c.s_char16               == u'\u00df'
        c.s_char16                       = u'\u00ef'
        assert CppyyTestData.s_char16   == u'\u00ef'
        CppyyTestData.s_char32           = u'\u00df'
        assert c.s_char32               == u'\u00df'
        c.s_char32                       = u'\u00ef'
        assert CppyyTestData.s_char32   == u'\u00ef'

        # integer types
        if self.has_byte:
            c.s_byte                     =   66
            assert CppyyTestData.s_byte ==   66
            CppyyTestData.s_byte         =   66
            assert c.s_byte             ==   66
        c.s_short                        = -102
        assert CppyyTestData.s_short    == -102
        CppyyTestData.s_short            = -203
        assert c.s_short                == -203
        c.s_ushort                       =  127
        assert CppyyTestData.s_ushort   ==  127
        CppyyTestData.s_ushort           =  227
        assert c.s_ushort               ==  227
        CppyyTestData.s_int              = -234
        assert c.s_int                  == -234
        c.s_int                          = -321
        assert CppyyTestData.s_int      == -321
        CppyyTestData.s_uint             = 1234
        assert c.s_uint                 == 1234
        c.s_uint                         = 4321
        assert CppyyTestData.s_uint     == 4321
        raises(ValueError, setattr, c,             's_uint', -1)
        raises(ValueError, setattr, CppyyTestData, 's_uint', -1)
        CppyyTestData.s_long             = -pylong(87)
        assert c.s_long                 == -pylong(87)
        c.s_long                         = pylong(876)
        assert CppyyTestData.s_long     == pylong(876)
        CppyyTestData.s_ulong            = pylong(876)
        assert c.s_ulong                == pylong(876)
        c.s_ulong                        = pylong(678)
        assert CppyyTestData.s_ulong    == pylong(678)
        raises(ValueError, setattr, CppyyTestData, 's_ulong', -1)
        raises(ValueError, setattr, c,             's_ulong', -1)

        # floating point types
        CppyyTestData.s_float                      = -3.1415
        assert round(c.s_float, 5)                == -3.1415
        c.s_float                                  =  3.1415
        assert round(CppyyTestData.s_float, 5)    ==  3.1415
        import math
        c.s_double                                 = -math.pi
        assert CppyyTestData.s_double             == -math.pi
        CppyyTestData.s_double                     =  math.pi
        assert c.s_double                         ==  math.pi
        c.s_ldouble                                = -math.pi
        assert CppyyTestData.s_ldouble            == -math.pi
        CppyyTestData.s_ldouble                    =  math.pi
        assert c.s_ldouble                        ==  math.pi

        c.__destruct__()

    def test06_range_access(self):
        """Test the ranges of integer types"""

        import _cppyy as cppyy, sys
        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        # TODO: should these be TypeErrors, or should char/bool raise
        #       ValueErrors? In any case, consistency is needed ...
        raises(ValueError, setattr, c, 'm_uint',  -1)
        raises(ValueError, setattr, c, 'm_ulong', -1)

        c.__destruct__()

    def test07_type_conversions(self):
        """Test conversions between builtin types"""

        import _cppyy as cppyy, sys
        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        c.m_double = -1
        assert round(c.m_double + 1.0, 8) == 0

        raises(TypeError, setattr, c.m_double,  'c')
        raises(TypeError, setattr, c.m_int,     -1.)
        raises(TypeError, setattr, c.m_int,      1.)

        c.__destruct__()

    def test08_global_builtin_type(self):
        """Test access to a global builtin type"""

        import _cppyy as cppyy
        gbl = cppyy.gbl

        assert gbl.g_int == gbl.get_global_int()

        gbl.set_global_int(32)
        assert gbl.get_global_int() == 32
        assert gbl.g_int == 32

        gbl.g_int = 22
        assert gbl.get_global_int() == 22
        assert gbl.g_int == 22

    def test09_global_ptr(self):
        """Test access of global objects through a pointer"""

        import _cppyy as cppyy
        gbl = cppyy.gbl

        with raises(ReferenceError):
            gbl.g_pod.m_int

        c = gbl.CppyyTestPod()
        c.m_int = 42
        c.m_double = 3.14

        gbl.set_global_pod(c)
        assert gbl.is_global_pod(c)
        assert gbl.g_pod.m_int == 42
        assert gbl.g_pod.m_double == 3.14

        d = gbl.get_global_pod()
        assert gbl.is_global_pod(d)
        assert c == d
        assert id(c) == id(d)

        e = gbl.CppyyTestPod()
        e.m_int = 43
        e.m_double = 2.14

        gbl.g_pod = e
        assert gbl.is_global_pod(e)
        assert gbl.g_pod.m_int == 43
        assert gbl.g_pod.m_double == 2.14

    def test10_enum(self):
        """Test access to enums"""

        import _cppyy as cppyy
        gbl = cppyy.gbl

        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        # test that the enum is accessible as a type
        assert CppyyTestData.EWhat

        assert CppyyTestData.kNothing   ==   6
        assert CppyyTestData.kSomething == 111
        assert CppyyTestData.kLots      ==  42

        assert CppyyTestData.EWhat(CppyyTestData.kNothing) == CppyyTestData.kNothing
        assert CppyyTestData.EWhat(6) == CppyyTestData.kNothing
        # TODO: only allow instantiations with correct values (C++11)

        assert c.get_enum() == CppyyTestData.kNothing
        assert c.m_enum == CppyyTestData.kNothing

        c.m_enum = CppyyTestData.kSomething
        assert c.get_enum() == CppyyTestData.kSomething
        assert c.m_enum == CppyyTestData.kSomething

        c.set_enum(CppyyTestData.kLots)
        assert c.get_enum() == CppyyTestData.kLots
        assert c.m_enum == CppyyTestData.kLots

        assert c.s_enum == CppyyTestData.s_enum
        assert c.s_enum == CppyyTestData.kNothing
        assert CppyyTestData.s_enum == CppyyTestData.kNothing

        c.s_enum = CppyyTestData.kSomething
        assert c.s_enum == CppyyTestData.s_enum
        assert c.s_enum == CppyyTestData.kSomething
        assert CppyyTestData.s_enum == CppyyTestData.kSomething

        # global enums
        assert gbl.EFruit          # test type accessible
        assert gbl.kApple  == 78
        assert gbl.kBanana == 29
        assert gbl.kCitrus == 34

        assert gbl.EnumSpace.E
        assert gbl.EnumSpace.EnumClass.E1 == -1   # anonymous
        assert gbl.EnumSpace.EnumClass.E2 == -1   # named type

        # typedef enum
        assert gbl.EnumSpace.letter_code
        assert gbl.EnumSpace.AA == 1
        assert gbl.EnumSpace.BB == 2

    def test11_string_passing(self):
        """Test passing/returning of a const char*"""

        import _cppyy as cppyy
        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert c.get_valid_string('aap') == 'aap'
        #assert c.get_invalid_string() == ''

    def test12_copy_constructor(self):
        """Test copy constructor"""

        import _cppyy as cppyy
        FourVector = cppyy.gbl.FourVector

        t1 = FourVector(1., 2., 3., -4.)
        t2 = FourVector(0., 0., 0.,  0.)
        t3 = FourVector(t1)

        assert t1 == t3
        assert t1 != t2

        for i in range(4):
            assert t1[i] == t3[i]

    def test13_object_returns(self):
        """Test access to and return of PODs"""

        import _cppyy as cppyy

        c = cppyy.gbl.CppyyTestData()

        assert c.m_pod.m_int == 888
        assert c.m_pod.m_double == 3.14

        pod = c.get_pod_val()
        assert pod.m_int == 888
        assert pod.m_double == 3.14

        assert c.get_pod_val_ptr().m_int == 888
        assert c.get_pod_val_ptr().m_double == 3.14
        c.get_pod_val_ptr().m_int = 777
        assert c.get_pod_val_ptr().m_int == 777

        assert c.get_pod_val_ref().m_int == 777
        assert c.get_pod_val_ref().m_double == 3.14
        c.get_pod_val_ref().m_int = 666
        assert c.get_pod_val_ref().m_int == 666

        assert c.get_pod_ptrref().m_int == 666
        assert c.get_pod_ptrref().m_double == 3.14

    def test14_object_arguments(self):
        """Test setting and returning of a POD through arguments"""

        import _cppyy as cppyy

        c = cppyy.gbl.CppyyTestData()
        assert c.m_pod.m_int == 888
        assert c.m_pod.m_double == 3.14

        p = cppyy.gbl.CppyyTestPod()
        p.m_int = 123
        assert p.m_int == 123
        p.m_double = 321.
        assert p.m_double == 321.

        c.set_pod_val(p)
        assert c.m_pod.m_int == 123
        assert c.m_pod.m_double == 321.

        c = cppyy.gbl.CppyyTestData()
        c.set_pod_ptr_in(p)
        assert c.m_pod.m_int == 123
        assert c.m_pod.m_double == 321.

        c = cppyy.gbl.CppyyTestData()
        c.set_pod_ptr_out(p)
        assert p.m_int == 888
        assert p.m_double == 3.14

        p.m_int = 555
        p.m_double = 666.

        c = cppyy.gbl.CppyyTestData()
        c.set_pod_ref(p)
        assert c.m_pod.m_int == 555
        assert c.m_pod.m_double == 666.

        c = cppyy.gbl.CppyyTestData()
        c.set_pod_ptrptr_in(p)
        assert c.m_pod.m_int == 555
        assert c.m_pod.m_double == 666.
        assert p.m_int == 555
        assert p.m_double == 666.

        c = cppyy.gbl.CppyyTestData()
        c.set_pod_void_ptrptr_in(p)
        assert c.m_pod.m_int == 555
        assert c.m_pod.m_double == 666.
        assert p.m_int == 555
        assert p.m_double == 666.

        c = cppyy.gbl.CppyyTestData()
        c.set_pod_ptrptr_out(p)
        assert c.m_pod.m_int == 888
        assert c.m_pod.m_double == 3.14
        assert p.m_int == 888
        assert p.m_double == 3.14

        p.m_int = 777
        p.m_double = 888.

        c = cppyy.gbl.CppyyTestData()
        c.set_pod_void_ptrptr_out(p)
        assert c.m_pod.m_int == 888
        assert c.m_pod.m_double == 3.14
        assert p.m_int == 888
        assert p.m_double == 3.14

    def test15_nullptr_passing(self):
        """Integer 0 ('NULL') and nullptr allowed to pass through instance*"""

        import _cppyy as cppyy

        for o in (0, cppyy.nullptr):
            c = cppyy.gbl.CppyyTestData()
            assert c.m_pod.m_int == 888
            assert c.m_pod.m_double == 3.14
            assert not not c.m_ppod

            c.set_pod_ptr(o)
            assert not c.m_ppod
            assert not c.get_pod_ptr()

    def test16_respect_privacy(self):
        """Test that privacy settings are respected"""

        import _cppyy as cppyy
        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        assert isinstance(c, CppyyTestData)

        raises(AttributeError, getattr, c, 'm_owns_arrays')

        c.__destruct__()

    def test17_object_and_pointer_comparisons(self):
        """Verify object and pointer comparisons"""

        import _cppyy as cppyy
        gbl = cppyy.gbl

        c1 = cppyy.bind_object(0, gbl.CppyyTestData)
        assert c1 == None
        assert None == c1

        c2 = cppyy.bind_object(0, gbl.CppyyTestData)
        assert c1 == c2
        assert c2 == c1

        # FourVector overrides operator==
        l1 = cppyy.bind_object(0, gbl.FourVector)
        assert l1 == None
        assert None == l1

        assert c1 != l1
        assert l1 != c1

        l2 = cppyy.bind_object(0, gbl.FourVector)
        assert l1 == l2
        assert l2 == l1

        l3 = gbl.FourVector(1, 2, 3, 4)
        l4 = gbl.FourVector(1, 2, 3, 4)
        l5 = gbl.FourVector(4, 3, 2, 1)
        assert l3 == l4
        assert l4 == l3

        assert l3 != None                 # like this to ensure __ne__ is called
        assert None != l3                 # id.
        assert l3 != l5
        assert l5 != l3

    def test18_object_validity(self):
        """Test object validity checking"""

        from _cppyy import gbl

        d = gbl.CppyyTestPod()

        assert d
        assert not not d

        d2 = gbl.get_null_pod()

        assert not d2

    def test19_buffer_reshaping(self):
        """Test usage of buffer sizing"""

        import _cppyy as cppyy
        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()
        byte_array_names = []
        if self.has_byte:
            byte_array_names = ['get_byte_array', 'get_byte_array2']
        for func in ['get_bool_array',   'get_bool_array2',
                     'get_uchar_array',  'get_uchar_array2',
                     'get_ushort_array', 'get_ushort_array2',
                     'get_int_array',    'get_int_array2',
                     'get_uint_array',   'get_uint_array2',
                     'get_long_array',   'get_long_array2',
                     'get_ulong_array',  'get_ulong_array2']+\
                     byte_array_names:
            arr = getattr(c, func)()
            arr.reshape((self.N,))
            assert len(arr) == self.N

            raises(TypeError, arr.reshape, (1, 2))
            assert len(arr) == self.N

            raises(TypeError, arr.reshape, 2*self.N)
            assert len(arr) == self.N

            l = list(arr)
            for i in range(self.N):
                assert arr[i] == l[i]

    def test20_voidp(self):
        """Test usage of void* data"""

        import _cppyy as cppyy
        CppyyTestData = cppyy.gbl.CppyyTestData

        c = CppyyTestData()

        assert not cppyy.nullptr

        assert c.s_voidp                is cppyy.nullptr
        assert CppyyTestData.s_voidp    is cppyy.nullptr

        assert c.m_voidp                is cppyy.nullptr
        assert c.get_voidp()            is cppyy.nullptr

        c2 = CppyyTestData()
        assert c2.m_voidp               is cppyy.nullptr
        c.set_voidp(c2.m_voidp)
        assert c.m_voidp                is cppyy.nullptr
        c.set_voidp(c2.get_voidp())
        assert c.m_voidp                is cppyy.nullptr
        c.set_voidp(cppyy.nullptr)
        assert c.m_voidp                is cppyy.nullptr

        c.set_voidp(c2)
        def address_equality_test(a, b):
            assert cppyy.addressof(a) == cppyy.addressof(b)
            b2 = cppyy.bind_object(a, CppyyTestData)
            assert b is b2    # memory regulator recycles
            b3 = cppyy.bind_object(cppyy.addressof(a), CppyyTestData)
            assert b is b3    # likewise

        address_equality_test(c.m_voidp, c2)
        address_equality_test(c.get_voidp(), c2)

        def null_test(null):
            c.m_voidp = null
            assert c.m_voidp is cppyy.nullptr
        map(null_test, [0, cppyy.nullptr])

        c.m_voidp = c2
        address_equality_test(c.m_voidp,     c2)
        address_equality_test(c.get_voidp(), c2)

        c.s_voidp = c2
        address_equality_test(c.s_voidp, c2)

    def test21_byte_arrays(self):
        """Usage of unsigned char* as byte array and std::byte*"""

        import _cppyy as cppyy
        import array, ctypes

        buf = b'123456789'
        total = 0
        for c in buf:
            try:
                total += ord(c)        # p2
            except TypeError:
                total += c             # p3

        def run(self, f, buf, total):

            # The following create a unique type for fixed-size C arrays: ctypes.c_char_Array_9
            # and neither inherits from a non-sized type nor implements the buffer interface.
            # As such, it can't be handled. TODO?
            #pbuf = ctypes.create_string_buffer(len(buf), buf)
            #assert f(pbuf, len(buf)) == total

            pbuf = array.array('B', buf)
            assert f(pbuf, len(buf)) == total

            pbuf = (ctypes.c_ubyte * len(buf)).from_buffer_copy(buf)
            assert f(pbuf, len(buf)) == total

            pbuf = ctypes.cast(buf, ctypes.POINTER(ctypes.c_ubyte * len(buf)))[0]
            assert f(pbuf, len(buf)) == total

        run(self, cppyy.gbl.sum_uc_data, buf, total)

        if self.has_byte:
            run(self, cppyy.gbl.sum_byte_data, buf, total)

    def test22_function_pointers(self):
        """Function pointer passing"""

        import os

        # TODO: currently crashes if fast path disabled
        try:
            if os.environ['CPPYY_DISABLE_FASTPATH']:
                return
        except KeyError:
            pass

        import _cppyy as cppyy

        f1 = cppyy.gbl.sum_of_int1
        f2 = cppyy.gbl.sum_of_double
        f3 = cppyy.gbl.call_double_double

        assert 5 == f1(2, 3)
        assert 5. == f2(5., 0.)

        raises(TypeError, f3, f1, 2, 3)

        assert 5. == f3(f2, 5., 0.)
