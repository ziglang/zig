# -*- coding: utf-8 -*-

class AppTestOperator:
    def test_getters_are_not_regular_functions(self):
        import _operator as operator
        class A(object):
            getx = operator.attrgetter('x')
            get3 = operator.itemgetter(3)
            callx = operator.methodcaller("append", "x")
        a = A()
        a.x = 5
        assert a.getx(a) == 5
        assert a.get3("foobar") == "b"
        assert a.getx(*(a,)) == 5
        l = []
        a.callx(l)
        assert l == ["x"]

    def test_getter_multiple_gest(self):
        import _operator as operator

        class A(object):
            pass

        a = A()
        a.x = 'X'
        a.y = 'Y'
        a.z = 'Z'

        assert operator.attrgetter('x','z','y')(a) == ('X', 'Z', 'Y')
        e = raises(TypeError, operator.attrgetter, ('x', (), 'y'))
        assert str(e.value) == "attribute name must be a string, not 'tuple'"

        data = list(map(str, range(20)))
        assert operator.itemgetter(2,10,5)(data) == ('2', '10', '5')
        raises(TypeError, operator.itemgetter(2, 'x', 5), data)

    def test_attrgetter(self):
        import _operator as operator
        raises(TypeError, operator.attrgetter, 2)

    def test_dotted_attrgetter(self):
        from _operator import attrgetter
        class A:
            pass
        a = A()
        a.name = "hello"
        a.child = A()
        a.child.name = "world"
        a.child.foo = "bar"
        assert attrgetter("child.name")(a) == "world"
        assert attrgetter("child.name", "child.foo")(a) == ("world", "bar")

    def test_attrgetter_type(self):
        from _operator import attrgetter
        assert type(attrgetter("child.name")) is attrgetter

    def test_concat(self):
        class Seq1:
            def __init__(self, lst):
                self.lst = lst
            def __len__(self):
                return len(self.lst)
            def __getitem__(self, i):
                return self.lst[i]
            def __add__(self, other):
                return self.lst + other.lst
            def __mul__(self, other):
                return self.lst * other
            def __rmul__(self, other):
                return other * self.lst

        class Seq2(object):
            def __init__(self, lst):
                self.lst = lst
            def __len__(self):
                return len(self.lst)
            def __getitem__(self, i):
                return self.lst[i]
            def __add__(self, other):
                return self.lst + other.lst
            def __mul__(self, other):
                return self.lst * other
            def __rmul__(self, other):
                return other * self.lst

        import _operator as operator

        raises(TypeError, operator.concat)
        raises(TypeError, operator.concat, None, None)
        assert operator.concat('py', 'thon') == 'python'
        assert operator.concat([1, 2], [3, 4]) == [1, 2, 3, 4]
        assert operator.concat(Seq1([5, 6]), Seq1([7])) == [5, 6, 7]
        assert operator.concat(Seq2([5, 6]), Seq2([7])) == [5, 6, 7]
        raises(TypeError, operator.concat, 13, 29)

    def test_mul(self):
        class Seq1:
            def __init__(self, lst):
                self.lst = lst
            def __len__(self):
                return len(self.lst)
            def __getitem__(self, i):
                return self.lst[i]
            def __add__(self, other):
                return self.lst + other.lst
            def __mul__(self, other):
                return self.lst * other
            def __rmul__(self, other):
                return other * self.lst

        class Seq2(object):
            def __init__(self, lst):
                self.lst = lst
            def __len__(self):
                return len(self.lst)
            def __getitem__(self, i):
                return self.lst[i]
            def __add__(self, other):
                return self.lst + other.lst
            def __mul__(self, other):
                return self.lst * other
            def __rmul__(self, other):
                return other * self.lst

        import _operator as operator

        a = list(range(3))
        raises(TypeError, operator.mul)
        raises(TypeError, operator.mul, a, None)
        assert operator.mul(a, 2) == a+a
        assert operator.mul(a, 1) == a
        assert operator.mul(a, 0) == []
        a = (1, 2, 3)
        assert operator.mul(a, 2) == a+a
        assert operator.mul(a, 1) == a
        assert operator.mul(a, 0) == ()
        a = '123'
        assert operator.mul(a, 2) == a+a
        assert operator.mul(a, 1) == a
        assert operator.mul(a, 0) == ''
        a = Seq1([4, 5, 6])
        assert operator.mul(a, 2) == [4, 5, 6, 4, 5, 6]
        assert operator.mul(a, 1) == [4, 5, 6]
        assert operator.mul(a, 0) == []
        a = Seq2([4, 5, 6])
        assert operator.mul(a, 2) == [4, 5, 6, 4, 5, 6]
        assert operator.mul(a, 1) == [4, 5, 6]
        assert operator.mul(a, 0) == []

    def test_iadd(self):
        import _operator as operator

        list = []
        assert operator.iadd(list, [1, 2]) is list
        assert list == [1, 2]

    def test_imul(self):
        import _operator as operator

        class X(object):
            def __index__(self):
                return 5

        a = list(range(3))
        raises(TypeError, operator.imul)
        raises(TypeError, operator.imul, a, None)
        raises(TypeError, operator.imul, a, [])
        assert operator.imul(a, 2) is a
        assert a == [0, 1, 2, 0, 1, 2]
        assert operator.imul(a, 1) is a
        assert a == [0, 1, 2, 0, 1, 2]

    def test_methodcaller(self):
        from _operator import methodcaller
        class X(object):
            def method(self, arg1=2, arg2=3):
                return arg1, arg2
        x = X()
        assert methodcaller("method")(x) == (2, 3)
        assert methodcaller("method", 4)(x) == (4, 3)
        assert methodcaller("method", 4, 5)(x) == (4, 5)
        assert methodcaller("method", 4, arg2=42)(x) == (4, 42)

    def test_methodcaller_self(self):
        from operator import methodcaller
        class X:
            def method(myself, self):
                return self * 6
        assert methodcaller("method", self=7)(X()) == 42

    def test_methodcaller_not_string(self):
        import _operator as operator
        e = raises(TypeError, operator.methodcaller, 42)
        assert str(e.value) == "method name must be a string"

    def test_index(self):
        import _operator as operator
        assert operator.index(42) == 42
        raises(TypeError, operator.index, "abc")
        exc = raises(TypeError, operator.index, "abc")
        assert str(exc.value) == "'str' object cannot be interpreted as an integer"

    def test_indexOf(self):
        import _operator as operator
        raises(TypeError, operator.indexOf)
        raises(TypeError, operator.indexOf, None, None)
        assert operator.indexOf([4, 3, 2, 1], 3) == 1
        raises(ValueError, operator.indexOf, [4, 3, 2, 1], 0)

    def test_index_int_subclass(self):
        import operator
        class myint(int):
            def __index__(self):
                return 13289
        assert operator.index(myint(7)) == 7

    def test_index_int_subclass(self):
        import operator
        class myint(int):
            def __index__(self):
                return 13289
        assert operator.index(myint(7)) == 7

    def test_compare_digest(self):
        import _operator as operator

        # Testing input type exception handling
        a, b = 100, 200
        raises(TypeError, operator._compare_digest, a, b)
        a, b = 100, b"foobar"
        raises(TypeError, operator._compare_digest, a, b)
        a, b = b"foobar", 200
        raises(TypeError, operator._compare_digest, a, b)
        a, b = u"foobar", b"foobar"
        raises(TypeError, operator._compare_digest, a, b)
        a, b = b"foobar", u"foobar"
        raises(TypeError, operator._compare_digest, a, b)

        # Testing bytes of different lengths
        a, b = b"foobar", b"foo"
        assert not operator._compare_digest(a, b)
        a, b = b"\xde\xad\xbe\xef", b"\xde\xad"
        assert not operator._compare_digest(a, b)

        # Testing bytes of same lengths, different values
        a, b = b"foobar", b"foobaz"
        assert not operator._compare_digest(a, b)
        a, b = b"\xde\xad\xbe\xef", b"\xab\xad\x1d\xea"
        assert not operator._compare_digest(a, b)

        # Testing bytes of same lengths, same values
        a, b = b"foobar", b"foobar"
        assert operator._compare_digest(a, b)
        a, b = b"\xde\xad\xbe\xef", b"\xde\xad\xbe\xef"
        assert operator._compare_digest(a, b)

        # Testing bytearrays of same lengths, same values
        a, b = bytearray(b"foobar"), bytearray(b"foobar")
        assert operator._compare_digest(a, b)

        # Testing bytearrays of diffeent lengths
        a, b = bytearray(b"foobar"), bytearray(b"foo")
        assert not operator._compare_digest(a, b)

        # Testing bytearrays of same lengths, different values
        a, b = bytearray(b"foobar"), bytearray(b"foobaz")
        assert not operator._compare_digest(a, b)

        # Testing byte and bytearray of same lengths, same values
        a, b = bytearray(b"foobar"), b"foobar"
        assert operator._compare_digest(a, b)
        assert operator._compare_digest(b, a)

        # Testing byte bytearray of diffeent lengths
        a, b = bytearray(b"foobar"), b"foo"
        assert not operator._compare_digest(a, b)
        assert not operator._compare_digest(b, a)

        # Testing byte and bytearray of same lengths, different values
        a, b = bytearray(b"foobar"), b"foobaz"
        assert not operator._compare_digest(a, b)
        assert not operator._compare_digest(b, a)

        # Testing str of same lengths
        a, b = "foobar", "foobar"
        assert operator._compare_digest(a, b)

        # Testing str of diffeent lengths
        a, b = "foo", "foobar"
        assert not operator._compare_digest(a, b)

        # Testing bytes of same lengths, different values
        a, b = "foobar", "foobaz"
        assert not operator._compare_digest(a, b)

        # Testing error cases
        a, b = u"foobar", b"foobar"
        raises(TypeError, operator._compare_digest, a, b)
        a, b = b"foobar", u"foobar"
        raises(TypeError, operator._compare_digest, a, b)
        a, b = b"foobar", 1
        raises(TypeError, operator._compare_digest, a, b)
        a, b = 100, 200
        raises(TypeError, operator._compare_digest, a, b)
        a, b = "fooä", "fooä"
        raises(TypeError, operator._compare_digest, a, b)

        # subclasses are supported by ignore __eq__
        class mystr(str):
            def __eq__(self, other):
                return False

        a, b = mystr("foobar"), mystr("foobar")
        assert operator._compare_digest(a, b)
        a, b = mystr("foobar"), "foobar"
        assert operator._compare_digest(a, b)
        a, b = mystr("foobar"), mystr("foobaz")
        assert not operator._compare_digest(a, b)

        class mybytes(bytes):
            def __eq__(self, other):
                return False

        a, b = mybytes(b"foobar"), mybytes(b"foobar")
        assert operator._compare_digest(a, b)
        a, b = mybytes(b"foobar"), b"foobar"
        assert operator._compare_digest(a, b)
        a, b = mybytes(b"foobar"), mybytes(b"foobaz")
        assert not operator._compare_digest(a, b)

    def test_compare_digest_unicode(self):
        import _operator as operator
        assert operator._compare_digest(u'asd', u'asd')
        assert not operator._compare_digest(u'asd', u'qwe')
        raises(TypeError, operator._compare_digest, u'asd', b'qwe')

    def test_length_hint(self):
        import _operator as operator
        assert operator.length_hint([1, 2]) == 2

    def test_repr_attrgetter(self):
        import _operator as operator
        assert repr(operator.attrgetter("foo")) == "operator.attrgetter('foo')"
        assert repr(operator.attrgetter("foo", 'bar')) == (
            "operator.attrgetter('foo', 'bar')")
        assert repr(operator.attrgetter("foo.bar")) == (
            "operator.attrgetter('foo.bar')")
        assert repr(operator.attrgetter("foo", 'bar.baz')) == (
            "operator.attrgetter('foo', 'bar.baz')")

    def test_repr_itemgetter(self):
        import _operator as operator
        assert repr(operator.itemgetter(2)) == "operator.itemgetter(2)"
        assert repr(operator.itemgetter(2, 3)) == "operator.itemgetter(2, 3)"

    def test_repr_methodcaller(self):
        import _operator as operator
        assert repr(operator.methodcaller("foo", "bar", baz=42)) == (
            "operator.methodcaller('foo', 'bar', baz=42)")

    def test_countOf(self):
        from _operator import countOf
        assert countOf([1, 2, 1, 1, 4], 1) == 3
        nan = float('nan')
        assert countOf([nan, nan, 4, nan], nan) == 3
