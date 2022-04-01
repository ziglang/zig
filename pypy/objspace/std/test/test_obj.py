from pypy.conftest import option
import pytest

class AppTestObject:

    spaceconfig = {'usemodules': ['itertools']}

    def setup_class(cls):
        from pypy.interpreter import gateway
        import sys

        space = cls.space
        cls.w_appdirect = space.wrap(option.runappdirect)

        def w_unwrap_wrap_unicode(space, w_obj):
            return space.newutf8(space.utf8_w(w_obj), w_obj._length)
        cls.w_unwrap_wrap_unicode = space.wrap(gateway.interp2app(w_unwrap_wrap_unicode))
        def w_unwrap_wrap_bytes(space, w_obj):
            return space.newbytes(space.bytes_w(w_obj))
        cls.w_unwrap_wrap_bytes = space.wrap(gateway.interp2app(w_unwrap_wrap_bytes))

    def test_hash_method(self):
        o = object()
        assert hash(o) == o.__hash__()

    def test_hash_list(self):
        l = list(range(5))
        raises(TypeError, hash, l)

    def test_no_getnewargs(self):
        o = object()
        assert not hasattr(o, '__getnewargs__')

    def test_hash_subclass(self):
        import sys
        class X(object):
            pass
        x = X()
        assert hash(x) == object.__hash__(x)

    def test_reduce_recursion_bug(self):
        class X(object):
            def __reduce__(self):
                return object.__reduce__(self) + (':-)',)
        s = X().__reduce__()
        assert s[-1] == ':-)'

    def test_getnewargs_ex(self):
        class NamedInt(int):
            def __new__(cls, name, **kwargs):
                if len(kwargs) == 0:
                    raise TypeError("name and value must be specified")
                self = int.__new__(cls, kwargs['value'])
                self._name = name
                return self
            def __getnewargs_ex__(self):
                return (self._name,), dict(value=int(self))
        import copyreg
        for protocol in [2, 3, 4]:
            assert NamedInt("Name", value=42).__reduce_ex__(protocol) == (
                copyreg.__newobj_ex__,
                (NamedInt, ('Name',), dict(value=42)),
                dict(_name='Name'), None, None)

    def test_reduce_ex_does_getattr(self):
        seen = []
        class X:
            def __getattribute__(self, name):
                seen.append(name)
                return object.__getattribute__(self, name)
        X().__reduce_ex__(2)
        # it is the case at least on CPython 3.5.2, like PyPy:
        assert '__reduce__' in seen
        # but these methods, which are also called, are not looked up
        # with getattr:
        assert '__getnewargs__' not in seen
        assert '__getnewargs_ex__' not in seen

    def test_reduce_ex_errors(self):
        # cf. lib-python/3/test/test_descr.py::PicklingTests.test_reduce()
        args = (-101, "spam")
        kwargs = {'bacon': -201, 'fish': -301}

        class C2:
            def __getnewargs__(self):
                return "bad args"
        excinfo = raises(TypeError, C2().__reduce_ex__, 4)
        assert str(excinfo.value) == \
            "__getnewargs__ should return a tuple, not 'str'"

        class C4:
            def __getnewargs_ex__(self):
                return (args, "bad dict")
        excinfo = raises(TypeError, C4().__reduce_ex__, 4)
        assert str(excinfo.value) == ("second item of the tuple "
            "returned by __getnewargs_ex__ must be a dict, not 'str'")

        class C5:
            def __getnewargs_ex__(self):
                return ("bad tuple", kwargs)
        excinfo = raises(TypeError, C5().__reduce_ex__, 4)
        assert str(excinfo.value) == ("first item of the tuple "
            "returned by __getnewargs_ex__ must be a tuple, not 'str'")

        class C6:
            def __getnewargs_ex__(self):
                return ()
        excinfo = raises(ValueError, C6().__reduce_ex__, 4)
        assert str(excinfo.value) == \
            "__getnewargs_ex__ should return a tuple of length 2, not 0"

        class C7:
            def __getnewargs_ex__(self):
                return "bad args"
        excinfo = raises(TypeError, C7().__reduce_ex__, 4)
        assert str(excinfo.value) == \
            "__getnewargs_ex__ should return a tuple, not 'str'"


    def test_reduce_state_empty_dict(self):
        class X(object):
            pass
        assert X().__reduce_ex__(2)[2] is None

    def test_reduce_arguments(self):
        # since python3.7 object.__reduce__ doesn't take an argument anymore
        # (used to be proto), and __reduce_ex__ requires one
        with raises(TypeError):
            object().__reduce__(0)
        with raises(TypeError):
            object().__reduce_ex__()

    def test_default_format(self):
        class x(object):
            def __str__(self):
                return "Pickle"
        res = format(x())
        assert res == "Pickle"
        assert isinstance(res, str)

    def test_format(self):
        class B:
            pass
        excinfo = raises(TypeError, format, B(), 's')
        assert 'B.__format__' in str(excinfo.value)


    def test_subclasshook(self):
        class x(object):
            pass
        assert x().__subclasshook__(object()) is NotImplemented
        assert x.__subclasshook__(object()) is NotImplemented

    def test_object_init(self):
        import warnings

        class A(object):
            pass

        raises(TypeError, A().__init__, 3)
        raises(TypeError, A().__init__, a=3)

        class B(object):
            def __new__(cls):
                return super(B, cls).__new__(cls)

            def __init__(self):
                super(B, self).__init__(a=3)

        raises(TypeError, B)

    def test_object_init_not_really_overridden(self):
        class A(object):
            def __new__(cls, value):
                return object.__new__(cls)
            __init__ = object.__init__     # see issue #3239
        assert isinstance(A(1), A)

    def test_object_new_not_really_overridden(self):
        class A(object):
            def __init__(self, value):
                self.value = value
            __new__ = object.__new__
        assert A(42).value == 42

    def test_object_init_cant_call_parent_with_args(self):
        class A(object):
            def __init__(self, value):
                object.__init__(self, value)
        raises(TypeError, A, 1)

    def test_object_new_cant_call_parent_with_args(self):
        class A(object):
            def __new__(cls, value):
                return object.__new__(cls, value)
        raises(TypeError, A, 1)

    def test_object_init_and_new_overridden(self):
        class A(object):
            def __new__(cls, value):
                result = object.__new__(cls)
                result.other_value = value + 1
                return result
            def __init__(self, value):
                self.value = value
        assert A(42).value == 42
        assert A(42).other_value == 43

    def test_object_str(self):
        # obscure case: __str__() must delegate to __repr__() without adding
        # type checking on its own
        class A(object):
            def __repr__(self):
                return 123456
        assert A().__str__() == 123456

    def test_object_dir(self):
        class A(object):
            a_var = None

        assert hasattr(object, '__dir__')
        obj = A()
        obj_items = dir(obj)
        assert obj_items == sorted(obj_items)
        assert obj_items == sorted(object.__dir__(obj))


    @pytest.mark.pypy_only
    def test_is_on_primitives(self):
        assert 1 is 1
        x = 1000000
        assert x + 1 is int(str(x + 1))
        assert 1 is not 1.0
        assert 1.1 is 1.1
        assert 0.0 is not -0.0
        for x in range(10):
            assert x + 0.1 is x + 0.1
        for x in range(10):
            assert x + 1 is x + 1
        for x in range(10):
            assert x+1j is x+1j
            assert 1+x*1j is 1+x*1j
        l = [1]
        assert l[0] is l[0]

    def test_is_on_strs(self):
        if self.appdirect:
            skip("cannot run this test as apptest")
        l = ["a"]
        assert l[0] is l[0]
        u = "a"
        assert self.unwrap_wrap_unicode(u) is u
        s = b"a"
        assert self.unwrap_wrap_bytes(s) is s

    @pytest.mark.pypy_only
    def test_is_by_value(self):
        for typ in [int, float, complex]:
            assert typ(42) is typ(42)

    def test_is_on_subclasses(self):
        for typ in [int, float, complex, str]:
            class mytyp(typ):
                pass
            assert mytyp(42) is not mytyp(42)
            assert mytyp(42) is not typ(42)
            assert typ(42) is not mytyp(42)
            x = mytyp(42)
            assert x is x
            assert x is not "43"
            assert x is not None
            assert "43" is not x
            assert None is not x
            x = typ(42)
            assert x is x
            assert x is not "43"
            assert x is not None
            assert "43" is not x
            assert None is not x

    @pytest.mark.pypy_only
    def test_id_on_primitives(self):
        assert id(1) == (1 << 4) + 1
        class myint(int):
            pass
        assert id(myint(1)) != id(1)

        assert id(1.0) & 7 == 5
        assert id(-0.0) != id(0.0)
        assert hex(id(2.0)) == '0x40000000000000005'
        assert id(0.0) == 5

    def test_id_on_strs(self):
        if self.appdirect:
            skip("cannot run this test as apptest")
        for u in [u"", u"a", u"aa"]:
            assert id(self.unwrap_wrap_unicode(u)) == id(u)
            s = u.encode()
            assert id(self.unwrap_wrap_bytes(s)) == id(s)
        #
        assert id(b'') == (256 << 4) | 11     # always
        assert id(u'') == (257 << 4) | 11
        assert id(b'a') == (ord('a') << 4) | 11
        # we no longer cache unicodes <128
        # assert id(u'\u1234') == ((~0x1234) << 4) | 11

    def test_id_of_tuples(self):
        l = []
        x = (l,)
        assert id(x) != id((l,))          # no caching at all
        if self.appdirect:
            skip("cannot run this test as apptest")
        assert id(()) == (258 << 4) | 11     # always

    def test_id_of_frozensets(self):
        x = frozenset([4])
        assert id(x) != id(frozenset([4]))          # no caching at all
        if self.appdirect:
            skip("cannot run this test as apptest")
        assert id(frozenset()) == (259 << 4) | 11     # always
        assert id(frozenset([])) == (259 << 4) | 11   # always

    def test_identity_vs_id_primitives(self):
        import sys
        l = list(range(-10, 10, 2))
        for i in [0, 1, 3]:
            l.append(float(i))
            l.append(i + 0.1)
            l.append(i + sys.maxsize)
            l.append(i - sys.maxsize)
            l.append(i + 1j)
            l.append(i - 1j)
            l.append(1 + i * 1j)
            l.append(1 - i * 1j)
            l.append((i,))
            l.append(frozenset([i]))
        l.append(-0.0)
        l.append(None)
        l.append(True)
        l.append(False)
        l.append(())
        l.append(tuple([]))
        l.append(frozenset())

        for i, a in enumerate(l):
            for b in l[i:]:
                assert (a is b) == (id(a) == id(b))
                if a is b:
                    assert a == b

    def test_identity_vs_id_str(self):
        if self.appdirect:
            skip("cannot run this test as apptest")
        l = []
        def add(s, u):
            l.append(s)
            l.append(self.unwrap_wrap_bytes(s))
            l.append(s[:1] + s[1:])
            l.append(u)
            l.append(self.unwrap_wrap_unicode(u))
            l.append(u[:1] + u[1:])
        for i in range(3, 18):
            add(str(i).encode(), str(i))
        add(b"s", u"s")
        add(b"", u"")

        for i, a in enumerate(l):
            for b in l[i:]:
                assert (a is b) == (id(a) == id(b))
                if a is b:
                    assert a == b

    def test_identity_bug(self):
        x = 0x4000000000000000
        y = 2j
        assert id(x) != id(y)

    def test_object_hash_immutable(self):
        x = 42
        y = 40
        y += 2
        assert object.__hash__(x) == object.__hash__(y)

    def test_richcompare(self):
        o = object()
        o2 = object()
        assert o.__eq__(o) is True
        assert o.__eq__(o2) is NotImplemented
        assert o.__ne__(o) is False
        assert o.__ne__(o2) is NotImplemented
        assert o.__le__(o2) is NotImplemented
        assert o.__lt__(o2) is NotImplemented
        assert o.__ge__(o2) is NotImplemented
        assert o.__gt__(o2) is NotImplemented

    def test_init_subclass(self):
        object().__init_subclass__() # does not crash
        object.__init_subclass__() # does not crash
        raises(TypeError, object.__init_subclass__, 1)

    def test_better_error_init(self):
        class A: pass

        with raises(TypeError) as excinfo:
            A(1)
        assert "A() takes no arguments" in str(excinfo.value)

        with raises(TypeError) as excinfo:
            A().__init__(1)
        assert "A.__init__() takes exactly one argument (the instance to initialize)" in str(excinfo.value)

        class D:
            def __new__(cls, *args, **kwargs):
                super().__new__(cls, *args, **kwargs)
            def __init__(self, *args, **kwargs):
                super().__init__(*args, **kwargs)
        with raises(TypeError) as excinfo:
            D(3)
        assert 'object.__new__() takes exactly one argument (the type to instantiate)' in str(excinfo.value)

        # Class that only overrides __init__
        class E:
            def __init__(self, *args, **kwargs):
                super().__init__(*args, **kwargs)

        error_msg = 'object.__init__() takes exactly one argument (the instance to initialize)'

        with raises(TypeError) as excinfo:
            E().__init__(42)
        print(excinfo.value)
        assert error_msg in str(excinfo.value)

        with raises(TypeError) as excinfo:
            object.__init__(E(), 42)
        print(excinfo.value)
        assert error_msg in str(excinfo.value)
    
    def test_class_getitem(self):
        for cls in [type, tuple]:
            ga = cls[int]
            assert ga.__origin__ is cls
            assert ga.__args__ == (int, )

def test_isinstance_shortcut():
    from pypy.objspace.std import objspace
    space = objspace.StdObjSpace()
    w_a = space.newtext("a")
    space.type = None
    # if it crashes, it means that space._type_isinstance didn't go through
    # the fast path, and tries to call type() (which is set to None just
    # above)
    space.isinstance_w(w_a, space.w_text) # does not crash
