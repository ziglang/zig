# -*- encoding: utf-8 -*-

class Test_DescrOperation:

    def test_nonzero(self):
        space = self.space
        assert space.nonzero(space.w_True) is space.w_True
        assert space.nonzero(space.w_False) is space.w_False
        assert space.nonzero(space.wrap(42)) is space.w_True
        assert space.nonzero(space.wrap(0)) is space.w_False
        l = space.newlist([])
        assert space.nonzero(l) is space.w_False
        space.call_method(l, 'append', space.w_False)
        assert space.nonzero(l) is space.w_True

    def test_isinstance_and_issubtype_ignore_special(self):
        space = self.space
        w_tup = space.appexec((), """():
        class Meta(type):
            def __subclasscheck__(mcls, cls):
                return False
        class Base(metaclass=Meta):
            pass
        class Sub(Base):
            pass
        return Base, Sub""")
        w_base, w_sub = space.unpackiterable(w_tup)
        assert space.issubtype_w(w_sub, w_base)
        w_inst = space.call_function(w_sub)
        assert space.isinstance_w(w_inst, w_base)


class AppTest_Descroperation:
    def test_special_methods(self):
        class A:
            def __lt__(self, other):
                return "lt"
            def __imul__(self, other):
                return "imul"
            def __sub__(self, other):
                return "sub"
            def __rsub__(self, other):
                return "rsub"
            def __pow__(self, other):
                return "pow"
            def __rpow__(self, other):
                return "rpow"
            def __neg__(self):
                return "neg"
        a = A()
        assert (a < 5) == "lt"
        assert (object() > a) == "lt"
        a1 = a
        a1 *= 4
        assert a1 == "imul"
        assert a - 2 == "sub"
        assert a - object() == "sub"
        assert 2 - a == "rsub"
        assert object() - a == "rsub"
        assert a ** 2 == "pow"
        assert a ** object() == "pow"
        assert 2 ** a == "rpow"
        assert object() ** a == "rpow"
        assert -a == "neg"

        class B(A):
            def __lt__(self, other):
                return "B's lt"
            def __imul__(self, other):
                return "B's imul"
            def __sub__(self, other):
                return "B's sub"
            def __rsub__(self, other):
                return "B's rsub"
            def __pow__(self, other):
                return "B's pow"
            def __rpow__(self, other):
                return "B's rpow"
            def __neg__(self):
                return "B's neg"

        b = B()
        assert (a < b) == "lt"
        assert (b > a) == "lt"
        b1 = b
        b1 *= a
        assert b1 == "B's imul"
        a1 = a
        a1 *= b
        assert a1 == "imul"

        assert a - b == "B's rsub"
        assert b - a == "B's sub"
        assert b - b == "B's sub"
        assert a ** b == "B's rpow"
        assert b ** a == "B's pow"
        assert b ** b == "B's pow"
        assert -b == "B's neg"

        class C(B):
            pass
        c = C()
        assert c - 1 == "B's sub"
        assert 1 - c == "B's rsub"
        assert c - b == "B's sub"
        assert b - c == "B's sub"

        assert c ** 1 == "B's pow"
        assert 1 ** c == "B's rpow"
        assert c ** b == "B's pow"
        assert b ** c == "B's pow"

    def test_getslice(self):
        class Sq(object):
            def __getitem__(self, key):
                return key.start, key.stop
            def __len__(self):
                return 100

        sq = Sq()

        assert sq[1:3] == (1,3)
        assert sq[:] == (None, None)
        assert sq[1:] == (1, None)
        assert sq[:3] == (None, 3)
        assert sq[:] == (None, None)
        # negative indices
        assert sq[-1:3] == (-1, 3)
        assert sq[1:-3] == (1, -3)
        assert sq[-1:-3] == (-1, -3)
        # extended slice syntax also uses __getitem__()
        assert sq[::] == (None, None)

    def test_setslice(self):
        class Sq(object):
            def __setitem__(self, key, value):
                ops.append((key.start, key.stop, value))
            def __len__(self):
                return 100

        sq = Sq()
        ops = []
        sq[-5:3] = 'hello'
        sq[12:] = 'world'
        sq[:-1] = 'spam'
        sq[:] = 'egg'

        assert ops == [
            (-5,    3,   'hello'),
            (12,   None, 'world'),
            (None, -1,   'spam'),
            (None, None, 'egg'),
            ]

    def test_delslice(self):
        class Sq(object):
            def __delitem__(self, key):
                ops.append((key.start, key.stop))
            def __len__(self):
                return 100

        sq = Sq()
        ops = []
        del sq[5:-3]
        del sq[-12:]
        del sq[:1]
        del sq[:]

        assert ops == [
            (5,   -3),
            (-12, None),
            (None,1),
            (None,None),
            ]

    def test_getslice_nolength(self):
        class Sq(object):
            def __getitem__(self, key):
                return key.start, key.stop

        sq = Sq()

        assert sq[1:3] == (1,3)
        assert sq[:] == (None, None)
        assert sq[1:] == (1, None)
        assert sq[:3] == (None, 3)
        assert sq[:] == (None, None)
        # negative indices, but no __len__
        assert sq[-1:3] == (-1, 3)
        assert sq[1:-3] == (1, -3)
        assert sq[-1:-3] == (-1, -3)
        # extended slice syntax also uses __getitem__()
        assert sq[::] == (None, None)

    def test_ipow(self):
        x = 2
        x **= 5
        assert x == 32

    def test_typechecks(self):
        class myint(int):
            pass
        class X(object):
            def __bool__(self):
                return myint(1)
        raises(TypeError, "not X()")

    def test_string_subclass(self):
        class S(str):
            def __hash__(self):
                return 123
        s = S("abc")
        setattr(s, s, s)
        assert len(s.__dict__) == 1
        # this behavior changed in 2.4
        #assert type(s.__dict__.keys()[0]) is str   # don't store S keys
        #assert s.abc is s
        assert getattr(s,s) is s

    def test_notimplemented(self):
        #import types
        import operator

        def specialmethod(self, other):
            return NotImplemented

        def check(expr, x, y, operator=operator):
            raises(TypeError, expr)

        for metaclass in [type]:   # [type, types.ClassType]:
            for name, expr, iexpr in [
                    ('__add__',      'x + y',                   'x += y'),
                    ('__sub__',      'x - y',                   'x -= y'),
                    ('__mul__',      'x * y',                   'x *= y'),
                    ('__truediv__',  'operator.truediv(x, y)',  None),
                    ('__floordiv__', 'operator.floordiv(x, y)', None),
                    ('__div__',      'x / y',                   'x /= y'),
                    ('__mod__',      'x % y',                   'x %= y'),
                    ('__divmod__',   'divmod(x, y)',            None),
                    ('__pow__',      'x ** y',                  'x **= y'),
                    ('__lshift__',   'x << y',                  'x <<= y'),
                    ('__rshift__',   'x >> y',                  'x >>= y'),
                    ('__and__',      'x & y',                   'x &= y'),
                    ('__or__',       'x | y',                   'x |= y'),
                    ('__xor__',      'x ^ y',                   'x ^= y'),
                    ]:
                rname = '__r' + name[2:]
                A = metaclass('A', (), {name: specialmethod})
                B = metaclass('B', (), {rname: specialmethod})
                a = A()
                b = B()
                check(expr, a, a)
                check(expr, a, b)
                check(expr, b, a)
                check(expr, b, b)
                check(expr, a, 5)
                check(expr, 5, b)
                if iexpr:
                    check(iexpr, a, a)
                    check(iexpr, a, b)
                    check(iexpr, b, a)
                    check(iexpr, b, b)
                    check(iexpr, a, 5)
                    iname = '__i' + name[2:]
                    C = metaclass('C', (), {iname: specialmethod})
                    c = C()
                    check(iexpr, c, a)
                    check(iexpr, c, b)
                    check(iexpr, c, 5)

    def test_string_results(self):
        class A(object):
            def __str__(self):
                return answer * 2
            def __repr__(self):
                return answer * 3

        for operate, n in [(str, 2), (repr, 3)]:
            answer = "hello"
            assert operate(A()) == "hello" * n
            assert type(operate(A())) is str
            answer = 42
            excinfo = raises(TypeError, operate, A())
            assert "returned non-string (type 'int')" in str(excinfo.value)

    def test_string_results_unicode(self):
        class A(object):
            def __str__(self):
                return 'àèì'
            def __repr__(self):
                return 'àèì'

        for operate in (str, repr):
            x = operate(A())
            assert x == 'àèì'
            assert type(x) is str


    def test_byte_results_unicode(self):
        class A(object):
            def __str__(self):
                return b'foo'
            def __repr__(self):
                return b'bar'

        for operate in (str, repr):
            raises(TypeError, operate, A())

    def test_missing_getattribute(self):
        """
        class X(object):
            pass

        class metaclass(type):
            def mro(cls):
                return [cls, X]
        class Y(X, metaclass=metaclass):
            pass

        x = X()
        x.__class__ = Y
        raises(AttributeError, getattr, x, 'a')
        """

    def test_unordeable_types(self):
        class A(object): pass
        class zz(object): pass
        raises(TypeError, "A() < zz()")
        raises(TypeError, "zz() > A()")
        raises(TypeError, "A() < A()")
        raises(TypeError, "A() < None")
        raises(TypeError, "None < A()")
        raises(TypeError, "0 < ()")
        raises(TypeError, "0.0 < ()")
        raises(TypeError, "0j < ()")
        raises(TypeError, "0 < []")
        raises(TypeError, "0.0 < []")
        raises(TypeError, "0j < []")
        raises(TypeError, "0 < A()")
        raises(TypeError, "0.0 < A()")
        raises(TypeError, "0j < A()")
        raises(TypeError, "0 < zz()")
        raises(TypeError, "0.0 < zz()")
        raises(TypeError, "0j < zz()")

    def test_correct_order_error_msg(self):
        class A(object):
            def __lt__(self, other):
                return NotImplemented
            __gt__ = __lt__

        class B(A):
            pass

        with raises(TypeError) as e:
            A() < B()
        assert str(e.value) == "'<' not supported between instances of 'A' and 'B'"

    def test_equality_among_different_types(self):
        class A(object): pass
        class zz(object): pass
        a = A()
        assert a == a
        for x, y in [(A(), A()),
                     (A(), zz()),
                     (A(), A()),
                     (A(), None),
                     (None, A()),
                     (0, ()),
                     (0.0, ()),
                     (0j, ()),
                     (0, []),
                     (0.0, []),
                     (0j, []),
                     (0, A()),
                     (0.0, A()),
                     (0j, A()),
                     ]:
            assert not x == y
            assert x != y


    def test_setattrweakref(self):
        skip("fails, works in cpython")
        # The issue is that in CPython, none of the built-in types have
        # a __weakref__ descriptor, even if their instances are weakrefable.
        # Should we emulate this?
        class P(object):
            pass

        setattr(P, "__weakref__", 0)

    def test_subclass_addition(self):
        # the __radd__ is never called (compare with the next test)
        l = []
        class A(object):
            def __add__(self, other):
                l.append(self.__class__)
                l.append(other.__class__)
                return 123
            def __radd__(self, other):
                # should never be called!
                return 456
        class B(A):
            pass
        res1 = A() + B()
        res2 = B() + A()
        assert res1 == res2 == 123
        assert l == [A, B, B, A]

    def test__eq__called(self):
        l = []
        class A(object):
            def __eq__(self, other):
                l.append((self, other))
                return True
        a = A()
        a == a
        assert l == [(a, a)]

    def test_subclass_comparison(self):
        # the __eq__ *is* called with reversed arguments
        l = []
        class A(object):
            def __eq__(self, other):
                l.append(self.__class__)
                l.append(other.__class__)
                return False

            def __lt__(self, other):
                l.append(self.__class__)
                l.append(other.__class__)
                return False

        class B(A):
            pass

        A() == B()
        A() < B()
        B() < A()
        assert l == [B, A, A, B, B, A]

    def test_subclass_comparison_more(self):
        # similarly, __gt__(b,a) is called instead of __lt__(a,b)
        l = []
        class A(object):
            def __lt__(self, other):
                l.append(self.__class__)
                l.append(other.__class__)
                return '<'
            def __gt__(self, other):
                l.append(self.__class__)
                l.append(other.__class__)
                return '>'
        class B(A):
            pass
        res1 = A() < B()
        res2 = B() < A()
        assert res1 == '>' and res2 == '<'
        assert l == [B, A, B, A]

    def test_rich_comparison(self):
        class A:
            def __init__(self, a):
                self.a = a
            def __eq__(self, other):
                return self.a == other.a
        class B:
            def __init__(self, a):
                self.a = a

        assert A(1) == B(1)
        assert B(1) == A(1)
        assert not(A(1) == B(2))
        assert not(B(1) == A(2))
        assert A(1) != B(2)
        assert B(1) != A(2)
        assert not(A(1) != B(1))
        assert not(B(1) != A(1))

    def test_ne_high_priority(self):
        """object.__ne__() should allow reflected __ne__() to be tried"""
        calls = []
        class Left:
            # Inherits object.__ne__()
            def __eq__(*args):
                calls.append('Left.__eq__')
                return NotImplemented
        class Right:
            def __eq__(*args):
                calls.append('Right.__eq__')
                return NotImplemented
            def __ne__(*args):
                calls.append('Right.__ne__')
                return NotImplemented
        Left() != Right()
        assert calls == ['Left.__eq__', 'Right.__ne__']

    def test_ne_low_priority(self):
        """object.__ne__() should not invoke reflected __eq__()"""
        calls = []
        class Base:
            # Inherits object.__ne__()
            def __eq__(*args):
                calls.append('Base.__eq__')
                return NotImplemented
        class Derived(Base):  # Subclassing forces higher priority
            def __eq__(*args):
                calls.append('Derived.__eq__')
                return NotImplemented
            def __ne__(*args):
                calls.append('Derived.__ne__')
                return NotImplemented
        Base() != Derived()
        assert calls == ['Derived.__ne__', 'Base.__eq__']

    def test_partial_ordering(self):
        class A(object):
            def __lt__(self, other):
                return self
        a1 = A()
        a2 = A()
        assert (a1 < a2) is a1
        assert (a1 > a2) is a2

    def test_eq_order(self):
        class A(object):
            def __eq__(self, other): return self.__class__.__name__+':A.eq'
            def __ne__(self, other): return self.__class__.__name__+':A.ne'
            def __lt__(self, other): return self.__class__.__name__+':A.lt'
            def __le__(self, other): return self.__class__.__name__+':A.le'
            def __gt__(self, other): return self.__class__.__name__+':A.gt'
            def __ge__(self, other): return self.__class__.__name__+':A.ge'
        class B(object):
            def __eq__(self, other): return self.__class__.__name__+':B.eq'
            def __ne__(self, other): return self.__class__.__name__+':B.ne'
            def __lt__(self, other): return self.__class__.__name__+':B.lt'
            def __le__(self, other): return self.__class__.__name__+':B.le'
            def __gt__(self, other): return self.__class__.__name__+':B.gt'
            def __ge__(self, other): return self.__class__.__name__+':B.ge'
        #
        assert (A() == B()) == 'A:A.eq'
        assert (A() != B()) == 'A:A.ne'
        assert (A() <  B()) == 'A:A.lt'
        assert (A() <= B()) == 'A:A.le'
        assert (A() >  B()) == 'A:A.gt'
        assert (A() >= B()) == 'A:A.ge'
        #
        assert (B() == A()) == 'B:B.eq'
        assert (B() != A()) == 'B:B.ne'
        assert (B() <  A()) == 'B:B.lt'
        assert (B() <= A()) == 'B:B.le'
        assert (B() >  A()) == 'B:B.gt'
        assert (B() >= A()) == 'B:B.ge'
        #
        class C(A):
            def __eq__(self, other): return self.__class__.__name__+':C.eq'
            def __ne__(self, other): return self.__class__.__name__+':C.ne'
            def __lt__(self, other): return self.__class__.__name__+':C.lt'
            def __le__(self, other): return self.__class__.__name__+':C.le'
            def __gt__(self, other): return self.__class__.__name__+':C.gt'
            def __ge__(self, other): return self.__class__.__name__+':C.ge'
        #
        assert (A() == C()) == 'C:C.eq'
        assert (A() != C()) == 'C:C.ne'
        assert (A() <  C()) == 'C:C.gt'
        assert (A() <= C()) == 'C:C.ge'
        assert (A() >  C()) == 'C:C.lt'
        assert (A() >= C()) == 'C:C.le'
        #
        assert (C() == A()) == 'C:C.eq'
        assert (C() != A()) == 'C:C.ne'
        assert (C() <  A()) == 'C:C.lt'
        assert (C() <= A()) == 'C:C.le'
        assert (C() >  A()) == 'C:C.gt'
        assert (C() >= A()) == 'C:C.ge'
        #
        class D(A):
            pass
        #
        assert (A() == D()) == 'D:A.eq'
        assert (A() != D()) == 'D:A.ne'
        assert (A() <  D()) == 'D:A.gt'
        assert (A() <= D()) == 'D:A.ge'
        assert (A() >  D()) == 'D:A.lt'
        assert (A() >= D()) == 'D:A.le'
        #
        assert (D() == A()) == 'D:A.eq'
        assert (D() != A()) == 'D:A.ne'
        assert (D() <  A()) == 'D:A.lt'
        assert (D() <= A()) == 'D:A.le'
        assert (D() >  A()) == 'D:A.gt'
        assert (D() >= A()) == 'D:A.ge'

    def test_binop_rule(self):
        called = []
        class A:
            def __eq__(self, other):
                called.append(self)
                return NotImplemented
        a1 = A()
        a2 = A()
        a1 == a2
        assert called == [a1, a2]

    def test_addition(self):
        class A:
            def __init__(self, a):
                self.a = a
            def __add__(self, other):
                return self.a + other.a
            __radd__ = __add__
        class B:
            def __init__(self, a):
                self.a = a

        assert A(1) + B(2) == 3
        assert B(1) + A(2) == 3

    def test_mod_failure(self):
        try:
            [] % 3
        except TypeError as e:
            assert '%' in str(e)
        else:
            assert False, "did not raise"

    def test_invalid_iterator(self):
        class x(object):
            def __iter__(self):
                return self
        raises(TypeError, iter, x())

    def test_attribute_error(self):
        class classmethodonly(classmethod):
            def __get__(self, instance, type):
                if instance is not None:
                    raise AttributeError("Must be called on a class, not an instance.")
                return super(classmethodonly, self).__get__(instance, type)

        class A(object):
            @classmethodonly
            def a(cls):
                return 3

        raises(AttributeError, lambda: A().a)

    def test_attribute_error2(self):
        import operator
        class A(object):
            def __eq__(self, other):
                raise AttributeError('doh')
        raises(AttributeError, operator.eq, A(), A())

        class E(object):
            @property
            def __eq__(self):
                raise AttributeError('doh')
        assert not (E() == E())

    def test_delete_descriptor(self):
        class Prop(object):
            def __get__(self, obj, cls):
                return 42
            def __delete__(self, obj):
                obj.deleted = True
        class C(object):
            x = Prop()
        obj = C()
        del obj.x
        assert obj.deleted

    def test_non_callable(self):
        meth = classmethod(1).__get__(1)
        raises(TypeError, meth)

    def test_isinstance_and_issubclass(self):
        class Meta(type):
            def __instancecheck__(cls, instance):
                if cls is A:
                    return True
                return False
            def __subclasscheck__(cls, sub):
                if cls is B:
                    return True
                return False
        A = Meta('A', (), {})  # like "class A(metaclass=Meta)", but
                               # Python2 cannot parse this
        class B(A):
            pass
        a = A()
        b = B()
        assert isinstance(a, A) # "shortcut" does not go through metaclass
        assert not isinstance(a, B)
        assert isinstance(b, A)
        assert isinstance(b, B) # "shortcut" does not go through metaclass
        assert isinstance(4, A)
        assert not issubclass(A, A)
        assert not issubclass(B, A)
        assert issubclass(A, B)
        assert issubclass(B, B)
        assert issubclass(23, B)

    def test_rebind_method(self):
        # No check is done on a method copied to another type
        class A:
            def method(self):
                return 42
        class Dict:
            method = A.method
        assert Dict().method() == 42

    def test_len_overflow(self):
        import sys
        class X(object):
            def __len__(self):
                return sys.maxsize + 1
        raises(OverflowError, len, X())
        raises(OverflowError, bool, X())

    def test_len_underflow(self):
        import sys
        class X(object):
            def __len__(self):
                return -1
        raises(ValueError, len, X())
        raises(ValueError, bool, X())

    def test_len_custom__int__(self):
        import sys
        class X(object):
            def __init__(self, x):
                self.x = x
            def __len__(self):
                return self.x
            def __int__(self):
                return self.x

        raises(TypeError, len, X(3.0))
        raises(TypeError, len, X(X(2)))
        raises(TypeError, bool, X(3.0))
        raises(TypeError, bool, X(X(2)))
        raises(OverflowError, len, X(sys.maxsize + 1))

    def test_len_index(self):
        class Index(object):
            def __index__(self):
                return 42
        class X(object):
            def __len__(self):
                return Index()
        n = len(X())
        assert type(n) is int
        assert n == 42

        class BadIndex(object):
            def __index__(self):
                return 'foo'
        class Y(object):
            def __len__(self):
                return BadIndex()
        excinfo = raises(TypeError, len, Y())
        assert excinfo.value.args[0].startswith("__index__ returned non-")

        class BadIndex2(object):
            def __index__(self):
                return 2**100
        class Z(object):
            def __len__(self):
                return BadIndex2()
        excinfo = raises(OverflowError, len, Z())

    def test_sane_len(self):
        # this test just tests our assumptions about __len__
        # this will start failing if __len__ changes assertions
        for badval in ['illegal', -1, 1 << 32]:
            class A:
                def __len__(self):
                    return badval
            try:
                bool(A())
            except (Exception) as e_bool:
                try:
                    len(A())
                except (Exception) as e_len:
                    assert str(e_bool) == str(e_len)

    def test_bool___contains__(self):
        class X(object):
            def __contains__(self, item):
                if item == 'foo':
                    return 42
                else:
                    return 'hello world'
        x = X()
        res = 'foo' in x
        assert res is True
        res = 'bar' in x
        assert res is True
        #
        class MyError(Exception):
            pass
        class CannotConvertToBool(object):
            def __bool__(self):
                raise MyError
        class X(object):
            def __contains__(self, item):
                return CannotConvertToBool()
        x = X()
        raises(MyError, "'foo' in x")

    def test_sequence_rmul_overrides(self):
        class oops(object):
            def __rmul__(self, other):
                return 42
            def __index__(self):
                return 3
        assert b'2' * oops() == 42
        assert [2] * oops() == 42
        assert (2,) * oops() == 42
        assert u'2' * oops() == 42
        assert bytearray(b'2') * oops() == 42
        assert 1000 * oops() == 42
        assert b'2'.__mul__(oops()) == b'222'
        x = '2'
        x *= oops()
        assert x == 42
        x = [2]
        x *= oops()
        assert x == 42

    def test_sequence_rmul_overrides_oldstyle(self):
        class oops:
            def __rmul__(self, other):
                return 42
            def __index__(self):
                return 3
        assert b'2' * oops() == 42
        assert [2] * oops() == 42
        assert (2,) * oops() == 42
        assert u'2' * oops() == 42
        assert bytearray(b'2') * oops() == 42
        assert 1000 * oops() == 42
        assert b'2'.__mul__(oops()) == b'222'

    def test_sequence_radd_overrides(self):
        class A1(list):
            pass
        class A2(list):
            def __radd__(self, other):
                return 42
        assert [2] + A1([3]) == [2, 3]
        assert type([2] + A1([3])) is list
        assert [2] + A2([3]) == 42
        x = "2"
        x += A2([3])
        assert x == 42
        x = [2]
        x += A2([3])
        assert x == 42

    def test_data_descriptor_without_delete(self):
        class D(object):
            def __set__(self, x, y):
                pass
        class A(object):
            d = D()
        raises(AttributeError, "del A().d")

    def test_data_descriptor_without_set(self):
        class D(object):
            def __delete__(self, x):
                pass
        class A(object):
            d = D()
        raises(AttributeError, "A().d = 5")

    def test_not_subscriptable_error_gives_keys(self):
        d = {'key1': {'key2': {'key3': None}}}
        excinfo = raises(TypeError, "d['key1']['key2']['key3']['key4']['key5']")
        assert "key4" in str(excinfo.value)

    def test_64bit_hash(self):
        import sys
        class BigHash(object):
            def __hash__(self):
                return sys.maxsize + 2
            def __eq__(self, other):
                return isinstance(other, BigHash)
        # previously triggered an OverflowError
        d = {BigHash(): None}
        assert BigHash() in d

    def test_class_getitem(self):
        excinfo = raises(TypeError, "int[int]")
        assert "'type' object is not subscriptable" in str(excinfo.value)
