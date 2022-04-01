import py, os, sys
from .support import setup_make, soext

currpath = py.path.local(__file__).dirpath()
test_dct = str(currpath.join("stltypesDict"))+soext

def setup_module(mod):
    setup_make("stltypes")


class AppTestSTLVECTOR:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_N = cls.space.newint(13)
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_stlvector = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_builtin_type_vector_types(self):
        """Test access to std::vector<int>/std::vector<double>"""

        import _cppyy as cppyy

        assert cppyy.gbl.std        is cppyy.gbl.std
        assert cppyy.gbl.std.vector is cppyy.gbl.std.vector

        assert callable(cppyy.gbl.std.vector)

        type_info = (
            ("int",     int),
            ("float",   "float"),
            ("double",  "double"),
        )

        for c_type, p_type in type_info:
            tv1 = getattr(cppyy.gbl.std, 'vector<%s>' % c_type)
            tv2 = cppyy.gbl.std.vector(p_type)
            assert tv1 is tv2
            assert tv1.iterator is cppyy.gbl.std.vector(p_type).iterator

            #----- 
            v = tv1(); v += range(self.N)
            if p_type == int:
                assert v.begin().__eq__(v.begin())
                assert v.begin() == v.begin()
                assert v.end() == v.end()
                assert v.begin() != v.end()
                assert v.end() != v.begin()

            #-----
            for i in range(self.N):
                v[i] = i
                assert v[i] == i
                assert v.at(i) == i

            assert v.size() == self.N
            assert len(v) == self.N
            assert len(v.data()) == self.N

            #-----
            v = tv1()
            for i in range(self.N):
                v.push_back(i)
                assert v.size() == i+1
                assert v.at(i) == i
                assert v[i] == i

            assert v.size() == self.N
            assert len(v) == self.N

    def test02_user_type_vector_type(self):
        """Test access to an std::vector<just_a_class>"""

        import _cppyy as cppyy

        assert cppyy.gbl.std        is cppyy.gbl.std
        assert cppyy.gbl.std.vector is cppyy.gbl.std.vector

        assert callable(cppyy.gbl.std.vector)

        tv1 = getattr(cppyy.gbl.std, 'vector<just_a_class>')
        tv2 = cppyy.gbl.std.vector('just_a_class')
        tv3 = cppyy.gbl.std.vector(cppyy.gbl.just_a_class)

        assert tv1 is tv2
        assert tv2 is tv3

        v = tv3()
        assert hasattr(v, 'size' )
        assert hasattr(v, 'push_back' )
        assert hasattr(v, '__getitem__' )
        assert hasattr(v, 'begin' )
        assert hasattr(v, 'end' )

        for i in range(self.N):
            v.push_back(cppyy.gbl.just_a_class())
            v[i].m_i = i
            assert v[i].m_i == i

        assert len(v) == self.N
        v.__destruct__()

    def test03_empty_vector_type(self):
        """Test behavior of empty std::vector<int>"""

        import _cppyy as cppyy

        v = cppyy.gbl.std.vector(int)()
        for arg in v:
            pass
        v.__destruct__()

    def test04_vector_iteration(self):
        """Test iteration over an std::vector<int>"""

        import _cppyy as cppyy

        v = cppyy.gbl.std.vector(int)()

        for i in range(self.N):
            v.push_back(i)
            assert v.size() == i+1
            assert v.at(i) == i
            assert v[i] == i

        assert v.size() == self.N
        assert len(v) == self.N

        i = 0
        for arg in v:
            assert arg == i
            i += 1

        assert list(v) == [i for i in range(self.N)]

        v.__destruct__()

    def test05_push_back_iterables_with_iadd(self):
        """Test usage of += of iterable on push_back-able container"""

        import _cppyy as cppyy

        v = cppyy.gbl.std.vector(int)()

        v += [1, 2, 3]
        assert len(v) == 3
        assert v[0] == 1
        assert v[1] == 2
        assert v[2] == 3

        v += (4, 5, 6)
        assert len(v) == 6
        assert v[3] == 4
        assert v[4] == 5
        assert v[5] == 6

        raises(TypeError, v.__iadd__, (7, '8'))  # string shouldn't pass
        assert len(v) == 7   # TODO: decide whether this should roll-back

        v2 = cppyy.gbl.std.vector(int)()
        v2 += [8, 9]
        assert len(v2) == 2
        assert v2[0] == 8
        assert v2[1] == 9

        v += v2
        assert len(v) == 9
        assert v[6] == 7
        assert v[7] == 8
        assert v[8] == 9

    def test06_vector_indexing(self):
        """Test python-style indexing to an std::vector<int>"""

        import _cppyy as cppyy

        v = cppyy.gbl.std.vector(int)()

        for i in range(self.N):
            v.push_back(i)

        raises(IndexError, 'v[self.N]')
        raises(IndexError, 'v[self.N+1]')

        assert v[-1] == self.N-1
        assert v[-2] == self.N-2

        assert len(v[0:0]) == 0
        assert v[1:2][0] == v[1]

        v2 = v[2:-1]
        assert len(v2) == self.N-3     # 2 off from start, 1 from end
        assert v2[0] == v[2]
        assert v2[-1] == v[-2]
        assert v2[self.N-4] == v[-2]

    def test07_vector_bool(self):
        """Usability of std::vector<bool> which can be a specialization"""

        import _cppyy as cppyy

        vb = cppyy.gbl.std.vector(bool)(8)
        assert [x for x in vb] == [False]*8

        vb[0] = True
        assert vb[0]
        vb[-1] = True
        assert vb[7]

        assert [x for x in vb] == [True]+[False]*6+[True]

        assert len(vb[4:8]) == 4
        assert list(vb[4:8]) == [False]*3+[True]

    def test08_vector_enum(self):
        """Usability of std::vector<> of some enums"""

        import _cppyy as cppyy

        # TODO: would like to use cppyy.gbl.VecTestEnum but that's an int
        assert cppyy.gbl.VecTestEnum
        ve = cppyy.gbl.std.vector['VecTestEnum']()
        ve.push_back(cppyy.gbl.EVal1);
        assert ve[0] == 1
        ve[0] = cppyy.gbl.EVal2
        assert ve[0] == 3

        assert cppyy.gbl.VecTestEnumNS.VecTestEnum
        ve = cppyy.gbl.std.vector['VecTestEnumNS::VecTestEnum']()
        ve.push_back(cppyy.gbl.VecTestEnumNS.EVal1);
        assert ve[0] == 5
        ve[0] = cppyy.gbl.VecTestEnumNS.EVal2
        assert ve[0] == 42


class AppTestSTLSTRING:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_stlstring = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_string_argument_passing(self):
        """Test mapping of python strings and std::string"""

        import _cppyy as cppyy
        std = cppyy.gbl.std
        stringy_class = cppyy.gbl.stringy_class

        c, s = stringy_class(""), std.string("test1")

        # pass through const std::string&
        c.set_string1(s)
        assert c.get_string1() == s

        c.set_string1("test2")
        assert c.get_string1() == "test2"

        # pass through std::string (by value)
        s = std.string("test3")
        c.set_string2(s)
        assert c.get_string1() == s

        c.set_string2("test4")
        assert c.get_string1() == "test4"

        # getting through std::string&
        s2 = std.string()
        c.get_string2(s2)
        assert s2 == "test4"

        raises(TypeError, c.get_string2, "temp string")

    def test02_string_data_access(self):
        """Test access to std::string object data members"""

        import _cppyy as cppyy
        std = cppyy.gbl.std
        stringy_class = cppyy.gbl.stringy_class

        c, s = stringy_class("dummy"), std.string("test string")

        c.m_string = "another test"
        assert c.m_string == "another test"
        assert str(c.m_string) == c.m_string
        assert c.get_string1() == "another test"

        c.m_string = s
        assert str(c.m_string) == s
        assert c.m_string == s
        assert c.get_string1() == s

    def test03_string_with_null_character(self):
        """Test that strings with NULL do not get truncated"""

        return # don't bother; is fixed in cling-support

        import _cppyy as cppyy
        std = cppyy.gbl.std
        stringy_class = cppyy.gbl.stringy_class

        t0 = "aap\0noot"
        assert t0 == "aap\0noot"

        c, s = stringy_class(""), std.string(t0, len(t0))

        c.set_string1(s)
        assert t0 == c.get_string1()
        assert s == c.get_string1()

    def test04_array_of_strings(self):
        """Access to global arrays of strings"""

        import _cppyy as cppyy

        assert tuple(cppyy.gbl.str_array_1) == ('a', 'b', 'c')
        str_array_2 = cppyy.gbl.str_array_2
        # fix up the size
        str_array_2.size = 4
        assert tuple(str_array_2) == ('d', 'e', 'f', 'g')
        assert tuple(str_array_2) == ('d', 'e', 'f', 'g')

        # multi-dimensional
        vals = ['a', 'b', 'c', 'd', 'e', 'f']
        str_array_3 = cppyy.gbl.str_array_3
        for i in range(3):
            for j in range(2):
                assert str_array_3[i][j] == vals[i*2+j]

        vals = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
                'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p']
        str_array_4 = cppyy.gbl.str_array_4
        for i in range(4):
            for j in range(2):
                for k in range(2):
                    assert str_array_4[i][j][k] == vals[i*4+j*2+k]


class AppTestSTLLIST:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_N = cls.space.newint(13)
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_stlstring = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_builtin_list_type(self):
        """Test access to a list<int>"""

        import _cppyy as cppyy
        std = cppyy.gbl.std

        type_info = (
            ("int",     int),
            ("float",   "float"),
            ("double",  "double"),
        )

        for c_type, p_type in type_info:
            tl1 = getattr(std, 'list<%s>' % c_type)
            tl2 = cppyy.gbl.std.list(p_type)
            assert tl1 is tl2
            assert tl1.iterator is cppyy.gbl.std.list(p_type).iterator

            #-----
            a = tl1()
            for i in range(self.N):
                a.push_back( i )

            assert len(a) == self.N
            assert 11 < self.N
            assert 11 in a

            #-----
            ll = list(a)
            for i in range(self.N):
                assert ll[i] == i

            for val in a:
                assert ll[ll.index(val)] == val

    def test02_empty_list_type(self):
        """Test behavior of empty list<int>"""

        import _cppyy as cppyy
        std = cppyy.gbl.std

        a = std.list(int)()
        for arg in a:
            pass


class AppTestSTLMAP:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_N = cls.space.newint(13)
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_stlstring = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_builtin_map_type(self):
        """Test access to a map<int,int>"""

        import _cppyy as cppyy
        std = cppyy.gbl.std

        a = std.map(int, int)()
        for i in range(self.N):
            a[i] = i
            assert a[i] == i

        assert len(a) == self.N

        for key, value in a:
            assert key == value
        assert key   == self.N-1
        assert value == self.N-1

        # add a variation, just in case
        m = std.map(int, int)()
        for i in range(self.N):
            m[i] = i*i
            assert m[i] == i*i

        for key, value in m:
            assert key*key == value
        assert key   == self.N-1
        assert value == (self.N-1)*(self.N-1)

    def test02_keyed_maptype(self):
        """Test access to a map<std::string,int>"""

        import _cppyy as cppyy
        std = cppyy.gbl.std

        a = std.map(std.string, int)()
        for i in range(self.N):
            a[str(i)] = i
            assert a[str(i)] == i

        assert len(a) == self.N

    def test03_empty_maptype(self):
        """Test behavior of empty map<int,int>"""

        import _cppyy as cppyy
        std = cppyy.gbl.std

        m = std.map(int, int)()
        for key, value in m:
            pass

    def test04_unsignedvalue_typemap_types(self):
        """Test assignability of maps with unsigned value types"""

        import _cppyy as cppyy
        import math, sys
        std = cppyy.gbl.std

        mui = std.map(str, 'unsigned int')()
        mui['one'] = 1
        assert mui['one'] == 1
        raises(ValueError, mui.__setitem__, 'minus one', -1)

        # UInt_t is always 32b, sys.maxint follows system int
        maxint32 = int(math.pow(2,31)-1)
        mui['maxint'] = maxint32 + 3
        assert mui['maxint'] == maxint32 + 3

        mul = std.map(str, 'unsigned long')()
        mul['two'] = 2
        assert mul['two'] == 2
        mul['maxint'] = sys.maxint + 3
        assert mul['maxint'] == sys.maxint + 3

        raises(ValueError, mul.__setitem__, 'minus two', -2)

    def test05_STL_like_class_indexing_overloads(self):
        """Test overloading of operator[] in STL like class"""

        import _cppyy as cppyy
        stl_like_class = cppyy.gbl.stl_like_class

        a = stl_like_class(int)()
        assert a["some string" ] == 'string'
        assert a[3.1415] == 'double'

    def test06_STL_like_class_iterators(self):
        """Test the iterator protocol mapping for an STL like class"""

        import _cppyy as cppyy
        stl_like_class = cppyy.gbl.stl_like_class

        a = stl_like_class(int)()
        assert len(a) == 4
        for i, j in enumerate(a):
            assert i == j

        assert i == len(a)-1


class AppTestSTLITERATOR:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_stlstring = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_builtin_vector_iterators(self):
        """Test iterator comparison with operator== reflected"""

        import _cppyy as cppyy
        std = cppyy.gbl.std

        v = std.vector(int)()
        v.resize(1)

        b1, e1 = v.begin(), v.end()
        b2, e2 = v.begin(), v.end()

        assert b1 == b2
        assert not b1 != b2

        assert e1 == e2
        assert not e1 != e2

        assert not b1 == e1
        assert b1 != e1

        b1.__preinc__()
        assert not b1 == b2
        assert b1 == e2
        assert b1 != b2
        assert b1 == e2


class AppTestTEMPLATE_UI:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_stlstring = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_explicit_templates(self):
        """Explicit use of Template class"""

        import _cppyy as cppyy

        vector = cppyy.Template('vector', cppyy.gbl.std)
        assert vector[int] == vector(int)

        v = vector[int]()

        N = 10
        v += range(N)
        assert len(v) == N
        for i in range(N):
            assert v[i] == i


class AppTestSTLARRAY:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_test_dct  = cls.space.newtext(test_dct)
        cls.w_stlarray = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()
            return ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)""" % (test_dct, ))

    def test01_array_of_basic_types(self):
        """Usage of std::array of basic types"""

        import _cppyy as cppyy
        std = cppyy.gbl.std

        a = std.array[int, 4]()
        assert len(a) == 4
        for i in range(len(a)):
            a[i] = i
            assert a[i] == i

    def test02_array_of_pods(self):
        """Usage of std::array of PODs"""

        import _cppyy as cppyy
        gbl, std = cppyy.gbl, cppyy.gbl.std

        a = std.array[gbl.ArrayTest.Point, 4]()
        assert len(a) == 4
        for i in range(len(a)):
            a[i].px = i
            assert a[i].px == i
            a[i].py = i**2
            assert a[i].py == i**2

    def test03_array_of_pointer_to_pods(self):
        """Usage of std::array of pointer to PODs"""

        import _cppyy as cppyy
        gbl = cppyy.gbl
        std = cppyy.gbl.std

        ll = [gbl.ArrayTest.Point() for i in range(4)]
        for i in range(len(ll)):
            ll[i].px = 13*i
            ll[i].py = 42*i

        # more tests in cppyy/test/test_stltypes.py, but currently not supported
