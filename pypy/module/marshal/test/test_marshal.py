import pytest
from rpython.tool.udir import udir

def test_recursion_error_in_subprocess(space):
    import py

    def f():
        space.appexec([], """():
        # test from CPython

        import marshal
        def run_tests(N, check):
            # (((...None...),),)
            check(b')\x01' * N + b'N')
            check(b'(\x01\x00\x00\x00' * N + b'N')
            # [[[...None...]]]
            check(b'[\x01\x00\x00\x00' * N + b'N')
            # {None: {None: {None: ...None...}}}
            check(b'{N' * N + b'N' + b'0' * N)
            # frozenset([frozenset([frozenset([...None...])])])
            check(b'>\x01\x00\x00\x00' * N + b'N')
        # Check that the generated marshal data is valid and marshal.loads()
        # works for moderately deep nesting
        run_tests(100, marshal.loads)
        # Very deeply nested structure shouldn't blow the stack
        def check(s):
            raises(ValueError, marshal.loads, s)
        run_tests(2**20, check)""")

    ff = py.process.ForkedFunc(f)
    res = ff.waitfinish()
    assert res.exitstatus == 0, res.err


class AppTestMarshal:
    spaceconfig = {'usemodules': ['array']}

    def setup_class(cls):
        tmpfile = udir.join('AppTestMarshal.tmp')
        cls.w_tmpfile = cls.space.wrap(str(tmpfile))

    def w_marshal_check(self, case):
        import marshal
        from io import BytesIO
        s = marshal.dumps(case)
        print(repr(s))
        x = marshal.loads(s)
        assert x == case and type(x) is type(case)

        y = marshal.loads(memoryview(s))
        assert y == case and type(y) is type(case)

        import sys
        if '__pypy__' in sys.builtin_module_names:
            f = BytesIO()
            marshal.dump(case, f)
            f.seek(0)
            x = marshal.load(f)
            assert x == case and type(x) is type(case)
        return x

    def test_None(self):
        case = None
        self.marshal_check(case)

    def test_False(self):
        case = False
        self.marshal_check(case)

    def test_True(self):
        case = True
        self.marshal_check(case)

    def test_StopIteration(self):
        case = StopIteration
        self.marshal_check(case)

    def test_Ellipsis(self):
        case = Ellipsis
        self.marshal_check(case)

    def test_42(self):
        case = 42
        self.marshal_check(case)

    def test__minus_17(self):
        case = -17
        self.marshal_check(case)

    def test_sys_dot_maxsize(self):
        import sys
        case = sys.maxsize
        self.marshal_check(case)

    def test__minus_1_dot_25(self):
        case = -1.25
        self.marshal_check(case)

    def test__minus_1_dot_25__2(self):
        case = -1.25 #2
        self.marshal_check(case)

    def test_2_plus_5j(self):
        case = 2+5j
        self.marshal_check(case)

    def test_2_plus_5j__2(self):
        case = 2+5j #2
        self.marshal_check(case)

    def test_long(self):
        case = -1234567890123456789012345678901234567890
        self.marshal_check(case)

    def test_hello_____not_interned(self):
        hello = "he"
        hello += "llo"
        case = hello   # not interned
        self.marshal_check(case)

    def test__Quote_hello_Quote_(self):
        case = "hello"
        self.marshal_check(case)

    def test__brace__ecarb_(self):
        case = ()
        self.marshal_check(case)

    def test__brace_1_comma__2_ecarb_(self):
        case = (1, 2)
        self.marshal_check(case)

    def test__list__tsil_(self):
        case = []
        self.marshal_check(case)

    def test__list_3_comma__4_tsil_(self):
        case = [3, 4]
        self.marshal_check(case)

    def test__dict__tcid_(self):
        case = {}
        self.marshal_check(case)

    def test__dict_5_colon__6_comma__7_colon__8_tcid_(self):
        case = {5: 6, 7: 8}
        self.marshal_check(case)

    def test_func_dot_func_code(self):
        def func(x):
            return lambda y: x+y
        case = func.__code__
        self.marshal_check(case)

    def test_scopefunc_dot_func_code(self):
        def func(x):
            return lambda y: x+y
        scopefunc = func(42)
        case = scopefunc.__code__
        self.marshal_check(case)

    def test_b_quote_hello_quote_(self):
        case = b'hello'
        self.marshal_check(case)

    def test_set_brace__ecarb_(self):
        case = set()
        self.marshal_check(case)

    def test_set_brace__list_1_comma__2_tsil__ecarb_(self):
        case = set([1, 2])
        self.marshal_check(case)

    def test_frozenset_brace__ecarb_(self):
        case = frozenset()
        self.marshal_check(case)

    def test_frozenset_brace__list_3_comma__4_tsil__ecarb_(self):
        case = frozenset([3, 4])
        self.marshal_check(case)

    def test_stream_reader_writer(self):
        # for performance, we have a special case when reading/writing real
        # file objects
        import marshal
        obj1 = [4, ("hello", 7.5)]
        obj2 = "foobar"
        f = open(self.tmpfile, 'wb')
        marshal.dump(obj1, f)
        marshal.dump(obj2, f)
        f.write(b'END')
        f.close()
        f = open(self.tmpfile, 'rb')
        obj1b = marshal.load(f)
        obj2b = marshal.load(f)
        tail = f.read()
        f.close()
        assert obj1b == obj1
        assert obj2b == obj2
        assert tail == b'END'

    def test_unicode(self):
        import marshal, sys
        self.marshal_check('\uFFFF')
        self.marshal_check('\ud800')
        c = u"\ud800"
        self.marshal_check(c + u'\udc00')

        self.marshal_check(chr(sys.maxunicode))

    def test_reject_subtypes(self):
        import marshal
        types = (float, complex, int, tuple, list, dict, set, frozenset)
        for cls in types:
            print(cls)
            class subtype(cls):
                pass
            exc = raises(ValueError, marshal.dumps, subtype)
            assert str(exc.value) == 'unmarshallable object'
            exc = raises(ValueError, marshal.dumps, subtype())
            assert str(exc.value) == 'unmarshallable object'
            exc = raises(ValueError, marshal.dumps, (subtype(),))
            assert str(exc.value) == 'unmarshallable object'

    def test_valid_subtypes(self):
        import marshal
        from array import array
        class subtype(array):
            pass
        assert marshal.dumps(subtype('b', b'test')) == marshal.dumps(array('b', b'test'))

    def test_bad_typecode(self):
        import marshal
        exc = raises(ValueError, marshal.loads, bytes([1]))
        assert str(exc.value).startswith("bad marshal data (unknown type code")

    def test_bad_data(self):
        # If you have sufficiently little memory, the line at the end of the
        # test will fail immediately.  If not, the test will consume high
        # amounts of memory and make your system unstable.  CPython (I tried
        # 3.3 and 3.5) shows the same behaviour on my computers (4 GB and 12 GB).
        skip("takes too much memory")

        import marshal
        # Yes, there is code that depends on this :-(
        raises(EOFError, marshal.loads, b'<test>')
        raises((MemoryError, ValueError), marshal.loads, b'(test)')

    def test_bad_reader(self):
        import marshal, io
        class BadReader(io.BytesIO):
            def read(self, n=-1):
                b = super().read(n)
                if n is not None and n > 4:
                    b += b' ' * 10**6
                return b
        for value in (1.0, 1j, b'0123456789', '0123456789'):
            raises(ValueError, marshal.load,
                   BadReader(marshal.dumps(value)))

    def test_int64(self):
        # another CPython test

        import marshal
        res = marshal.loads(b'I\xff\xff\xff\xff\xff\xff\xff\x7f')
        assert res == 0x7fffffffffffffff
        res = marshal.loads(b'I\xfe\xdc\xba\x98\x76\x54\x32\x10')
        assert res == 0x1032547698badcfe
        res = marshal.loads(b'I\x01\x23\x45\x67\x89\xab\xcd\xef')
        assert res == -0x1032547698badcff
        res = marshal.loads(b'I\x08\x19\x2a\x3b\x4c\x5d\x6e\x7f')
        assert res == 0x7f6e5d4c3b2a1908
        res = marshal.loads(b'I\xf7\xe6\xd5\xc4\xb3\xa2\x91\x80')
        assert res == -0x7f6e5d4c3b2a1909

    def test_co_filename_bug(self):
        import marshal
        code = compile('pass', 'tmp-\udcff.py', "exec")
        res = marshal.dumps(code) # must not crash
        code2 = marshal.loads(res)
        assert code.co_filename == code2.co_filename


@pytest.mark.skipif('config.option.runappdirect or sys.maxint > 2 ** 32')
class AppTestSmallLong(AppTestMarshal):
    spaceconfig = AppTestMarshal.spaceconfig.copy()
    spaceconfig["objspace.std.withsmalllong"] = True

    def setup_class(cls):
        from pypy.interpreter import gateway
        from pypy.objspace.std.smalllongobject import W_SmallLongObject
        def w__small(space, w_obj):
            return W_SmallLongObject.frombigint(space.bigint_w(w_obj))
        cls.w__small = cls.space.wrap(gateway.interp2app(w__small))

    def test_smalllong(self):
        import __pypy__
        x = self._small(-123456789012345)
        assert 'SmallLong' in __pypy__.internal_repr(x)
        y = self.marshal_check(x)
        assert y == x
        # must be unpickled as a small long
        assert 'SmallLong' in __pypy__.internal_repr(y)
