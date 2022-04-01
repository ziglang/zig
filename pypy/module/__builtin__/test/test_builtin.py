# coding: utf-8
import sys

from rpython.tool.udir import udir

class AppTestBuiltinApp:
    def setup_class(cls):
        space = cls.space
        class X(object):
            def __eq__(self, other):
                raise OverflowError
            def __hash__(self):
                return 42
        d = {X(): 5}
        try:
            d[X()]
        except OverflowError:
            cls.w_sane_lookup = space.wrap(True)
        except KeyError:
            cls.w_sane_lookup = space.wrap(False)
        # starting with CPython 2.6, when the stack is almost out, we
        # can get a random error, instead of just a RuntimeError.
        # For example if an object x has a __getattr__, we can get
        # AttributeError if attempting to call x.__getattr__ runs out
        # of stack.  That's annoying, so we just work around it.
        if cls.runappdirect:
            cls.w_safe_runtimerror = space.wrap(True)
        else:
            cls.w_safe_runtimerror = space.wrap(sys.version_info < (2, 6))

    def test_builtin_names(self):
        import builtins as __builtin__
        assert __builtin__.bytes is bytes
        assert __builtin__.dict is dict
        assert __builtin__.memoryview is memoryview
        assert not hasattr(__builtin__, 'buffer')

    def test_bytes_alias(self):
        assert bytes is not str
        assert isinstance(eval("b'hi'"), bytes)

    def test_eval_adds_builtins(self):
        d = {}
        eval('1', d)
        assert "__builtins__" in d

    def test_import(self):
        m = __import__('sys')
        assert m.__name__ == "sys"
        raises(ImportError, __import__, 'spamspam')
        raises(TypeError, __import__, 1, 2, 3, 4)
        print(__import__.__doc__)
        assert __import__.__doc__.endswith('relative to the current module.')

    def test_ascii(self):
        assert ascii('') == '\'\''
        assert ascii(0) == '0'
        assert ascii(()) == '()'
        assert ascii([]) == '[]'
        assert ascii({}) == '{}'
        a = []
        a.append(a)
        assert ascii(a) == '[[...]]'
        a = {}
        a[0] = a
        assert ascii(a) == '{0: {...}}'
        # Advanced checks for unicode strings
        def _check_uni(s):
            assert ascii(s) == repr(s)
        _check_uni("'")
        _check_uni('"')
        _check_uni('"\'')
        _check_uni('\0')
        _check_uni('\r\n\t .')
        # Unprintable non-ASCII characters
        _check_uni('\x85')
        _check_uni('\u1fff')
        _check_uni('\U00012fff')
        # Lone surrogates
        _check_uni('\ud800')
        _check_uni('\udfff')
        # Issue #9804: surrogates should be joined even for printable
        # wide characters (UCS-2 builds).
        assert ascii('\U0001d121') == "'\\U0001d121'"
        # another buggy case
        x = ascii("\U00012fff")
        assert x == r"'\U00012fff'"
        # All together
        s = "'\0\"\n\r\t abcd\x85é\U00012fff\uD800\U0001D121xxx."
        assert ascii(s) == \
            r"""'\'\x00"\n\r\t abcd\x85\xe9\U00012fff\ud800\U0001d121xxx.'"""

    def test_bin(self):
        class Foo:
            def __index__(self):
                return 4
        assert bin(0) == "0b0"
        assert bin(-1) == "-0b1"
        assert bin(2) == "0b10"
        assert bin(-2) == "-0b10"
        assert bin(Foo()) == "0b100"
        raises(TypeError, bin, 0.)
        class C(object):
            def __index__(self):
                return 42
        assert bin(C()) == bin(42)
        class D(object):
            def __int__(self):
                return 42
        exc = raises(TypeError, bin, D())
        assert "integer" in str(exc.value)

    def test_oct(self):
        class Foo:
            def __index__(self):
                return 4
        assert oct(0) == "0o0"
        assert oct(-1) == "-0o1"
        assert oct(8) == "0o10"
        assert oct(-8) == "-0o10"
        assert oct(Foo()) == "0o4"
        raises(TypeError, oct, 0.)

    def test_hex(self):
        class Foo:
            def __index__(self):
                return 4
        assert hex(0) == "0x0"
        assert hex(-1) == "-0x1"
        assert hex(16) == "0x10"
        assert hex(-16) == "-0x10"
        assert hex(Foo()) == "0x4"
        raises(TypeError, hex, 0.)

    def test_chr(self):
        import sys
        assert chr(65) == 'A'
        assert type(str(65)) is str
        assert chr(0x9876) == '\u9876'
        if sys.maxunicode > 0xFFFF:
            assert chr(sys.maxunicode) == '\U0010FFFF'
        else:
            assert chr(sys.maxunicode) == '\uFFFF'
        assert chr(0x00010000) == '\U00010000'
        assert chr(0x0010ffff) == '\U0010FFFF'
        raises(ValueError, chr, -1)

    def test_globals(self):
        d = {"foo":"bar"}
        exec("def f(): return globals()", d)
        d2 = d["f"]()
        assert d2 is d

    def test_locals(self):
        def f():
            return locals()

        def g(c=0, b=0, a=0):
            return locals()

        assert f() == {}
        assert g() == {'a': 0, 'b': 0, 'c': 0}

    def test_locals_deleted_local(self):
        def f():
            a = 3
            locals()
            del a
            return locals()

        assert f() == {}

    def test_dir(self):
        def f():
            return dir()
        def g(c=0, b=0, a=0):
            return dir()
        def nosp(x): return [y for y in x if y[0]!='_']
        assert f() == []
        assert g() == ['a', 'b', 'c']
        class X(object): pass
        assert nosp(dir(X)) == []
        class X(object):
            a = 23
            c = 45
            b = 67
        assert nosp(dir(X)) == ['a', 'b', 'c']

    def test_dir_in_broken_locals(self):
        class C(object):
            def __getitem__(self, item):
                raise KeyError(item)
            def keys(self):
                return 'abcd'    # not a list!
        names = eval("dir()", {}, C())
        assert names == ['a', 'b', 'c', 'd']

    def test_dir_broken_module(self):
        import sys
        class Foo(type(sys)):
            __dict__ = 8
        raises(TypeError, dir, Foo("foo"))

    def test_dir_broken_object(self):
        class Foo(object):
            x = 3
            def __getattribute__(self, name):
                return name
        assert dir(Foo()) == []

    def test_dir_custom(self):
        class Foo(object):
            def __dir__(self):
                return ["1", "2", "3"]
        f = Foo()
        assert dir(f) == ["1", "2", "3"]
        class Foo:
            def __dir__(self):
                return ["apple"]
        assert dir(Foo()) == ["apple"]
        class Foo(object):
            def __dir__(self):
                return 42
        f = Foo()
        raises(TypeError, dir, f)
        import sys
        class Foo(type(sys)):
            def __dir__(self):
                return ["blah"]
        assert dir(Foo("a_mod")) == ["blah"]

    def test_dir_custom_lookup(self):
        """
        class M(type):
            def __dir__(self, *args): return ["14"]
        class X(metaclass=M):
            pass
        x = X()
        x.__dir__ = lambda x: ["14"]
        assert dir(x) != ["14"]
        """

    def test_format(self):
        assert format(4) == "4"
        assert format(10, "o") == "12"
        assert format(10, "#o") == "0o12"
        assert format("hi") == "hi"

    def test_vars(self):
        def f():
            return vars()
        def g(c=0, b=0, a=0):
            return vars()
        assert f() == {}
        assert g() == {'a':0, 'b':0, 'c':0}

    def test_sum(self):
        assert sum([]) ==0
        assert sum([42]) ==42
        assert sum([1,2,3]) ==6
        assert sum([],5) ==5
        assert sum([1,2,3],4) ==10
        #
        class Foo(object):
            def __radd__(self, other):
                assert other is None
                return 42
        assert sum([Foo()], None) == 42

    def test_sum_fast_path(self):
        # Fast paths for expected behaviour
        start = []
        assert sum([[1, 2], [3]], start) == [1, 2, 3]
        assert start == []

        start = [1, 2]
        assert sum([[3]], start) == [1, 2, 3]
        assert start == [1, 2]

        assert sum([(1, 2), (3,)], ()) == (1, 2, 3)
        assert sum([(3,)], (1, 2)) == (1, 2, 3)
        assert sum(([x + 1] for x in range(3)), []) == [1, 2, 3]

    def test_sum_empty_edge_cases(self):
        assert sum([], []) == []
        assert sum(iter([]), []) == []
        assert sum([], ()) == ()
        start = []
        assert sum([], start) is start
        assert sum([[]], start) is not start

    def test_sum_type_errors(self):
        with raises(TypeError):
            sum([[]], ())
        with raises(TypeError):
            sum([()], [])
        with raises(TypeError):
            sum([[], [], ()], [])

    def test_sum_strange_objects(self):
        # All that follows should be rare, but needs care
        class TupleTail(object):
            def __radd__(self, other):
                assert isinstance(other, tuple)
                return other[1:]

        strange_seq = [(1, 2), (3, 4), TupleTail(), (5,)]
        assert sum(strange_seq, (2, 3, 4, 5))
        assert sum(iter(strange_seq), (2, 3, 4, 5))

        class NotAList(list):
            def __add__(self, _):
                return "!"

            def __radd__(self, _):
                return "?"

            def __iadd__(self, _):
                raise RuntimeError(
                    "Calling __iadd__ breaks CPython compatability"
                )

        assert sum([[1]], NotAList()) == "!"
        assert sum([[1], NotAList()], []) == "?"

    def test_sum_first_object_edge_cases(self):
        class X(list):
            def __radd__(self, other):
                return Y()

        class Y(object):
            calls = []

            def __add__(self, other):
                Y.calls.append("add")

            def __iadd__(self, other):
                Y.calls.append("iadd")

        assert sum([X(), []], []) is None
        assert Y.calls == ["add"]

        class Z(tuple):
            def __radd__(self, other):
                return Y()

        assert sum([Z(), []], []) is None
        assert Y.calls == ["add", "add"]

    def test_type_selftest(self):
        assert type(type) is type

    def test_iter_sequence(self):
        raises(TypeError,iter,3)
        x = iter(['a','b','c'])
        assert next(x) =='a'
        assert next(x) =='b'
        assert next(x) =='c'
        raises(StopIteration, next, x)

    def test_iter___iter__(self):
        # This test assumes that dict.keys() method returns keys in
        # the same order as dict.__iter__().
        # Also, this test is not as explicit as the other tests;
        # it tests 4 calls to __iter__() in one assert.  It could
        # be modified if better granularity on the assert is required.
        mydict = {'a':1,'b':2,'c':3}
        assert list(iter(mydict)) == list(mydict.keys())

    def test_iter_callable_sentinel(self):
        class count(object):
            def __init__(self):
                self.value = 0
            def __call__(self):
                self.value += 1
                if self.value > 10:
                    raise StopIteration
                return self.value
        with raises(TypeError):
            iter(3, 5)

        x = iter(count(),3)
        assert next(x) ==1
        assert next(x) ==2
        raises(StopIteration, next, x)

        # a case that runs till the end
        assert list(iter(count(), 100)) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    def test_enumerate(self):
        import sys
        seq = range(2,4)
        enum = enumerate(seq)
        assert next(enum) == (0, 2)
        assert next(enum) == (1, 3)
        raises(StopIteration, next, enum)
        raises(TypeError, enumerate, 1)
        raises(TypeError, enumerate, None)
        enum = enumerate(range(5), 2)
        assert list(enum) == list(zip(range(2, 7), range(5)))

        enum = enumerate(range(2), 2**100)
        assert list(enum) == [(2**100, 0), (2**100+1, 1)]

        enum = enumerate(range(2), sys.maxsize)
        assert list(enum) == [(sys.maxsize, 0), (sys.maxsize+1, 1)]

        raises(TypeError, enumerate, range(2), 5.5)


    def test_next(self):
        x = iter(['a', 'b', 'c'])
        assert next(x) == 'a'
        assert next(x) == 'b'
        assert next(x) == 'c'
        raises(StopIteration, next, x)
        assert next(x, 42) == 42

    def test_next__next__(self):
        class Counter:
            def __init__(self):
                self.count = 0
            def __next__(self):
                self.count += 1
                return self.count
        x = Counter()
        assert next(x) == 1
        assert next(x) == 2
        assert next(x) == 3

    def test_range_args(self):
        raises(ValueError, range, 0, 1, 0)

    def test_range_repr(self):
        assert repr(range(1)) == 'range(0, 1)'
        assert repr(range(1,2)) == 'range(1, 2)'
        assert repr(range(1,2,3)) == 'range(1, 2, 3)'

    def test_range_up(self):
        x = range(2)
        iter_x = iter(x)
        assert next(iter_x) == 0
        assert next(iter_x) == 1
        raises(StopIteration, next, iter_x)

    def test_range_down(self):
        x = range(4,2,-1)

        iter_x = iter(x)
        assert next(iter_x) == 4
        assert next(iter_x) == 3
        raises(StopIteration, next, iter_x)

    def test_range_has_type_identity(self):
        assert type(range(1)) == type(range(1))

    def test_range_len(self):
        x = range(33)
        assert len(x) == 33
        exc = raises(TypeError, range, 33.2)
        assert "integer" in str(exc.value)
        x = range(33,0,-1)
        assert len(x) == 33
        x = range(33,0)
        assert len(x) == 0
        exc = raises(TypeError, range, 33, 0.2)
        assert "integer" in str(exc.value)
        x = range(0,33)
        assert len(x) == 33
        x = range(0,33,-1)
        assert len(x) == 0
        x = range(0,33,2)
        assert len(x) == 17
        x = range(0,32,2)
        assert len(x) == 16

    def test_range_indexing(self):
        x = range(0,33,2)
        assert x[7] == 14
        assert x[-7] == 20
        raises(IndexError, x.__getitem__, 17)
        raises(IndexError, x.__getitem__, -18)
        assert list(x.__getitem__(slice(0,3,1))) == [0, 2, 4]

    def test_range_bad_args(self):
        raises(TypeError, range, '1')
        raises(TypeError, range, None)
        raises(TypeError, range, 3+2j)
        raises(TypeError, range, 1, '1')
        raises(TypeError, range, 1, 3+2j)
        raises(TypeError, range, 1, 2, '1')
        raises(TypeError, range, 1, 2, 3+2j)

    def test_range_bool(self):
        import sys
        a = range(-sys.maxsize, sys.maxsize)
        assert bool(a) is True
        b = range(10, 0)
        assert bool(b) is False

    def test_sorted(self):
        l = []
        sorted_l = sorted(l)
        assert sorted_l is not l
        assert sorted_l == l
        l = [1, 5, 2, 3]
        sorted_l = sorted(l)
        assert sorted_l == [1, 2, 3, 5]

    def test_sorted_with_keywords(self):
        l = ['a', 'C', 'b']
        sorted_l = sorted(l, reverse = True)
        assert sorted_l is not l
        assert sorted_l == ['b', 'a', 'C']
        sorted_l = sorted(l, reverse = True, key = lambda x: x.lower())
        assert sorted_l is not l
        assert sorted_l == ['C', 'b', 'a']
        raises(TypeError, sorted, [], reverse=None)
        raises(TypeError, sorted, [], None)

    def test_sorted_posonlyarg(self):
        raises(TypeError, sorted, iterable=[])

    def test_reversed_simple_sequences(self):
        l = range(5)
        rev = reversed(l)
        assert list(rev) == [4, 3, 2, 1, 0]
        assert list(l.__reversed__()) == [4, 3, 2, 1, 0]
        s = "abcd"
        assert list(reversed(s)) == ['d', 'c', 'b', 'a']

    def test_reversed_custom_objects(self):
        """make sure __reversed__ is called when defined"""
        class SomeClass(object):
            def __reversed__(self):
                return 42
        obj = SomeClass()
        assert reversed(obj) == 42

    def test_return_None(self):
        class X(object): pass
        x = X()
        assert setattr(x, 'x', 11) == None
        assert delattr(x, 'x') == None

    def test_divmod(self):
        assert divmod(15,10) ==(1,5)

    def test_callable(self):
        class Call(object):
            def __call__(self, a):
                return a+2
        assert callable(Call()), (
                    "Builtin function 'callable' misreads callable object")
        assert callable(int), (
                    "Builtin function 'callable' misreads int")
        class Call:
            def __call__(self, a):
                return a+2
        assert callable(Call())


    def test_uncallable(self):
        # XXX TODO: I made the NoCall class explicitly newstyle to try and
        # remedy the failure in this test observed when running this with
        # the trivial objectspace, but the test _still_ fails then (it
        # doesn't fail with the standard objectspace, though).
        class NoCall(object):
            pass
        a = NoCall()
        assert not callable(a), (
                    "Builtin function 'callable' misreads uncallable object")
        a.__call__ = lambda: "foo"
        assert not callable(a), (
                    "Builtin function 'callable' tricked by instance-__call__")
        class NoCall:
            pass
        assert not callable(NoCall())

    def test_hash(self):
        assert hash(23) == hash(23)
        assert hash(2.3) == hash(2.3)
        assert hash('23') == hash("23")
        assert hash((23,)) == hash((23,))
        assert hash(22) != hash(23)
        raises(TypeError, hash, [])
        raises(TypeError, hash, {})

    def test_eval(self):
        assert eval("1+2") == 3
        assert eval(" \t1+2\n") == 3
        assert eval("len([])") == 0
        assert eval("len([])", {}) == 0
        # cpython 2.4 allows this (raises in 2.3)
        assert eval("3", None, None) == 3
        i = 4
        assert eval("i", None, None) == 4
        assert eval('a', None, dict(a=42)) == 42

    def test_isinstance(self):
        assert isinstance(5, int)
        assert isinstance(5, object)
        assert not isinstance(5, float)
        assert isinstance(True, (int, float))
        assert not isinstance(True, (type, float))
        assert isinstance(True, ((type, float), bool))
        raises(TypeError, isinstance, 5, 6)
        raises(TypeError, isinstance, 5, (float, 6))

    def test_issubclass(self):
        assert issubclass(int, int)
        assert issubclass(int, object)
        assert not issubclass(int, float)
        assert issubclass(bool, (int, float))
        assert not issubclass(bool, (type, float))
        assert issubclass(bool, ((type, float), bool))
        raises(TypeError, issubclass, 5, int)
        raises(TypeError, issubclass, int, 6)
        raises(TypeError, issubclass, int, (float, 6))

    def test_staticmethod(self):
        class X(object):
            def f(*args, **kwds): return args, kwds
            f = staticmethod(f)
        assert X.f() == ((), {})
        assert X.f(42, x=43) == ((42,), {'x': 43})
        assert X().f() == ((), {})
        assert X().f(42, x=43) == ((42,), {'x': 43})

    def test_classmethod(self):
        class X(object):
            def f(*args, **kwds): return args, kwds
            f = classmethod(f)
        class Y(X):
            pass
        assert X.f() == ((X,), {})
        assert X.f(42, x=43) == ((X, 42), {'x': 43})
        assert X().f() == ((X,), {})
        assert X().f(42, x=43) == ((X, 42), {'x': 43})
        assert Y.f() == ((Y,), {})
        assert Y.f(42, x=43) == ((Y, 42), {'x': 43})
        assert Y().f() == ((Y,), {})
        assert Y().f(42, x=43) == ((Y, 42), {'x': 43})

    def test_hasattr(self):
        class X(object):
            def broken(): pass   # TypeError
            abc = property(broken)
            def broken2(): raise IOError
            bac = property(broken2)
        x = X()
        x.foo = 42
        assert hasattr(x, '__class__') is True
        assert hasattr(x, 'foo') is True
        assert hasattr(x, 'bar') is False
        raises(TypeError, "hasattr(x, 'abc')")
        raises(TypeError, "hasattr(x, 'bac')")
        raises(TypeError, hasattr, x, None)
        raises(TypeError, hasattr, x, 42)
        assert hasattr(x, '\u5678') is False

    def test_hasattr_exception(self):
        class X(object):
            def __getattr__(self, name):
                if name == 'foo':
                    raise AttributeError
                else:
                    raise KeyError
        x = X()
        assert hasattr(x, 'foo') is False
        raises(KeyError, "hasattr(x, 'bar')")

    def test_print_function(self):
        import builtins
        import sys
        import _io
        pr = getattr(builtins, "print")
        save = sys.stdout
        out = sys.stdout = _io.StringIO()
        try:
            pr("Hello,", "person!")
            pr("2nd line", file=None)
            sys.stdout = None
            pr("nowhere")
        finally:
            sys.stdout = save
        assert out.getvalue() == "Hello, person!\n2nd line\n"
        out = _io.StringIO()
        pr("Hello,", "person!", file=out)
        assert out.getvalue() == "Hello, person!\n"
        out = _io.StringIO()
        pr("Hello,", "person!", file=out, end="")
        assert out.getvalue() == "Hello, person!"
        out = _io.StringIO()
        pr("Hello,", "person!", file=out, sep="X")
        assert out.getvalue() == "Hello,Xperson!\n"
        out = _io.StringIO()
        pr(b"Hello,", b"person!", file=out)
        result = out.getvalue()
        assert isinstance(result, str)
        assert result == "b'Hello,' b'person!'\n"
        out = _io.StringIO()
        pr(None, file=out)
        assert out.getvalue() == "None\n"
        out = sys.stdout = _io.StringIO()
        try:
            pr("amaury", file=None)
        finally:
            sys.stdout = save
        assert out.getvalue() == "amaury\n"

    def test_print_function2(self):
        import builtins
        import _io
        class MyStr(str):
            def __str__(self):
                return "sqlalchemy"
        out = _io.StringIO()
        s = MyStr('A')
        pr = getattr(builtins, 'print')
        pr(s, file=out)
        pr(str(s), file=out)
        assert out.getvalue() == "sqlalchemy\nsqlalchemy\n"

    def test_print_exceptions(self):
        import builtins
        pr = getattr(builtins, "print")
        raises(TypeError, pr, x=3)
        raises(TypeError, pr, end=3)
        raises(TypeError, pr, sep=42)

    def test_round(self):
        assert round(11.234) == 11
        assert type(round(11.234)) is int
        assert round(11.234, -1) == 10
        assert type(round(11.234, -1)) is float
        assert round(11.234, 0) == 11
        assert round(11.234, 1) == 11.2
        #
        assert round(5e15-1) == 5e15-1
        assert round(5e15) == 5e15
        assert round(-(5e15-1)) == -(5e15-1)
        assert round(-5e15) == -5e15
        assert round(5e15/2) == 5e15/2
        assert round((5e15+1)/2) == 5e15/2
        assert round((5e15-1)/2) == 5e15/2
        #
        inf = 1e200 * 1e200
        raises(OverflowError, round, inf)
        raises(OverflowError, round, -inf)
        nan = inf / inf
        raises(ValueError, round, nan)
        raises(OverflowError, round, 1.6e308, -308)
        #
        assert round(562949953421312.5, 1) == 562949953421312.5
        assert round(56294995342131.5, 3) == 56294995342131.5
        #
        for i in range(-10, 10):
            expected = i + (i % 2)
            assert round(i + 0.5) == round(i + 0.5, 0) == expected
            x = i * 10 + 5
            assert round(x, -1) == round(float(x), -1) == expected * 10

        assert round(0.0) == 0.0
        assert type(round(0.0)) == int
        assert round(1.0) == 1.0
        assert round(10.0) == 10.0
        assert round(1000000000.0) == 1000000000.0
        assert round(1e20) == 1e20

        assert round(-1.0) == -1.0
        assert round(-10.0) == -10.0
        assert round(-1000000000.0) == -1000000000.0
        assert round(-1e20) == -1e20

        assert round(0.1) == 0.0
        assert round(1.1) == 1.0
        assert round(10.1) == 10.0
        assert round(1000000000.1) == 1000000000.0

        assert round(-1.1) == -1.0
        assert round(-10.1) == -10.0
        assert round(-1000000000.1) == -1000000000.0

        assert round(0.9) == 1.0
        assert round(9.9) == 10.0
        assert round(999999999.9) == 1000000000.0

        assert round(-0.9) == -1.0
        assert round(-9.9) == -10.0
        assert round(-999999999.9) == -1000000000.0

        assert round(-8.0, -1) == -10.0
        assert type(round(-8.0, -1)) == float

        assert type(round(-8.0, 0)) == float
        assert type(round(-8.0, 1)) == float

        # Check even / odd rounding behaviour
        assert round(5.5) == 6
        assert round(6.5) == 6
        assert round(-5.5) == -6
        assert round(-6.5) == -6

        # Check behavior on ints
        assert round(0) == 0
        assert round(8) == 8
        assert round(-8) == -8
        assert type(round(0)) == int
        assert type(round(-8, -1)) == int
        assert type(round(-8, 0)) == int
        assert type(round(-8, 1)) == int

        assert round(number=-8.0, ndigits=-1) == -10.0
        raises(TypeError, round)

        # test generic rounding delegation for reals
        class TestRound:
            def __round__(self):
                return 23

        class TestNoRound:
            pass

        assert round(TestRound()) == 23

        raises(TypeError, round, 1, 2, 3)
        raises(TypeError, round, TestNoRound())

        t = TestNoRound()
        t.__round__ = lambda *args: args
        raises(TypeError, round, t)
        raises(TypeError, round, t, 0)

        assert round(3, ndigits=None) == 3
        assert round(3.0, ndigits=None) == 3
        assert type(round(3.0, ndigits=None)) is int

    def test_vars_obscure_case(self):
        class C_get_vars(object):
            def getDict(self):
                return {'a':2}
            __dict__ = property(fget=getDict)
        assert vars(C_get_vars()) == {'a':2}

    def test_len_negative_overflow(self):
        import sys
        class NegativeLen:
            def __len__(self):
                return -10
        raises(ValueError, len, NegativeLen())
        class HugeLen:
            def __len__(self):
                return sys.maxsize + 1
        raises(OverflowError, len, HugeLen())
        class HugeNegativeLen:
            def __len__(self):
                return -sys.maxsize-10
        raises(ValueError, len, HugeNegativeLen())


class AppTestGetattr:
    spaceconfig = {}

    def test_getattr(self):
        class a(object):
            i = 5
        assert getattr(a, 'i') == 5
        raises(AttributeError, getattr, a, 'k')
        assert getattr(a, 'k', 42) == 42
        raises(TypeError, getattr, a, b'i')
        raises(TypeError, getattr, a, b'k', 42)

    def test_getattr_typecheck(self):
        class A(object):
            def __getattribute__(self, name):
                pass
            def __setattr__(self, name, value):
                pass
            def __delattr__(self, name):
                pass
        raises(TypeError, getattr, A(), 42)
        raises(TypeError, setattr, A(), 42, 'x')
        raises(TypeError, delattr, A(), 42)

    def test_getattr_None(self):
        import sys
        if '__pypy__' not in sys.modules:
            skip('CPython uses wrapper types for this')
        class C:
            def _m(self): pass
        assert isinstance(getattr(type(None), '__eq__'), type(lambda: None))
        assert isinstance(getattr(None, '__eq__'), type(C()._m))

    def test_getattr_userobject(self):
        class C:
            def _m(self): pass
        class A(object):
            def __eq__(self, other):
                pass
        a = A()
        assert isinstance(getattr(A, '__eq__'), type(lambda: None))
        assert isinstance(getattr(a, '__eq__'), type(C()._m))
        a.__eq__ = 42
        assert a.__eq__ == 42

    def test_pow_kwarg(self):
        assert pow(base=5, exp=2, mod=14) == 11
