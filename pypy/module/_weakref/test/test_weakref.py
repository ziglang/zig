class AppTestWeakref(object):
    spaceconfig = dict(usemodules=('_weakref',))

    def setup_class(cls):
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)

    def test_simple(self):
        import _weakref, gc
        class A(object):
            pass
        a = A()
        assert _weakref.getweakrefcount(a) == 0
        ref = _weakref.ref(a)
        assert ref() is a
        assert a.__weakref__ is ref
        assert _weakref.getweakrefcount(a) == 1
        del a
        gc.collect()
        assert ref() is None

    def test_missing_arg(self):
        import _weakref
        raises(TypeError, _weakref.ref)

    def test_no_kwargs(self):
        import _weakref
        class C(object):
            pass
        raises(TypeError, _weakref.ref, C(), callback=None)

    def test_callback(self):
        import _weakref, gc
        class A(object):
            pass
        a1 = A()
        a2 = A()
        def callback(ref):
            a2.ref = ref()
        ref1 = _weakref.ref(a1, callback)
        ref2 = _weakref.ref(a1)
        assert ref1.__callback__ is callback
        assert ref2.__callback__ is None
        assert _weakref.getweakrefcount(a1) == 2
        del a1
        gc.collect()
        assert ref1() is None
        assert ref1.__callback__ is None
        assert a2.ref is None

    def test_callback_order(self):
        import _weakref, gc
        class A(object):
            pass
        a1 = A()
        a2 = A()
        def callback1(ref):
            a2.x = 42
        def callback2(ref):
            a2.x = 43
        ref1 = _weakref.ref(a1, callback1)
        ref2 = _weakref.ref(a1, callback2)
        del a1
        gc.collect()
        assert a2.x == 42
        
    def test_dont_callback_if_weakref_dead(self):
        import _weakref, gc
        class A(object):
            pass
        a1 = A()
        a1.x = 40
        a2 = A()
        def callback(ref):
            a1.x = 42
        assert _weakref.getweakrefcount(a2) == 0
        ref = _weakref.ref(a2, callback)
        assert _weakref.getweakrefcount(a2) == 1
        ref = None
        gc.collect()
        assert _weakref.getweakrefcount(a2) == 0
        a2 = None
        gc.collect()
        assert a1.x == 40

    def test_callback_cannot_ressurect(self):
        import _weakref, gc
        class A(object):
            pass
        a = A()
        alive = A()
        alive.a = 1
        def callback(ref2):
            alive.a = ref1()
        ref1 = _weakref.ref(a, callback)
        ref2 = _weakref.ref(a, callback)
        del a
        gc.collect()
        assert alive.a is None

    def test_weakref_reusing(self):
        import _weakref, gc
        class A(object):
            pass
        a = A()
        ref1 = _weakref.ref(a)
        ref2 = _weakref.ref(a)
        assert ref1 is ref2
        class wref(_weakref.ref):
            pass
        wref1 = wref(a)
        assert isinstance(wref1, wref)

    def test_correct_weakrefcount_after_death(self):
        import _weakref, gc
        class A(object):
            pass
        a = A()
        ref1 = _weakref.ref(a)
        ref2 = _weakref.ref(a)
        assert _weakref.getweakrefcount(a) == 1
        del ref1
        gc.collect()
        assert _weakref.getweakrefcount(a) == 1
        del ref2
        gc.collect()
        assert _weakref.getweakrefcount(a) == 0

    def test_weakref_equality(self):
        import _weakref, gc
        class A(object):
            def __eq__(self, other):
                return True
            def __ne__(self, other):
                return False
        a1 = A()
        a2 = A()
        ref1 = _weakref.ref(a1)
        ref2 = _weakref.ref(a2)
        assert ref1 == ref2
        assert not (ref1 != ref2)
        assert not (ref1 == [])
        assert ref1 != []
        del a1
        gc.collect()
        assert not ref1 == ref2
        assert ref1 != ref2
        assert not (ref1 == [])
        assert ref1 != []
        del a2
        gc.collect()
        assert not ref1 == ref2
        assert ref1 != ref2
        assert not (ref1 == [])
        assert ref1 != []

    def test_ne(self):
        import _weakref
        class X(object):
            pass
        ref1 = _weakref.ref(X())
        assert ref1.__eq__(X()) is NotImplemented
        assert ref1.__ne__(X()) is NotImplemented

    def test_getweakrefs(self):
        import _weakref, gc
        class A(object):
            pass
        a = A()
        assert _weakref.getweakrefs(a) == []
        assert _weakref.getweakrefs(None) == []
        ref1 = _weakref.ref(a)
        assert _weakref.getweakrefs(a) == [ref1]

    def test_hashing(self):
        import _weakref, gc
        class A(object):
            def __hash__(self):
                return 42
        a = A()
        w = _weakref.ref(a)
        assert hash(a) == hash(w)
        del a
        gc.collect()
        assert hash(w) == 42
        w = _weakref.ref(A())
        gc.collect()
        raises(TypeError, hash, w)

    def test_weakref_subclassing(self):
        import _weakref, gc
        class A(object):
            pass
        class Ref(_weakref.ref):
            def __init__(self, ob, callback=None, **other):
                self.__dict__.update(other)
        def callable(ref):
            b.a = 42
        a = A()
        b = A()
        b.a = 1
        w = Ref(a, callable, x=1, y=2)
        assert w.x == 1
        assert w.y == 2
        assert a.__weakref__ is w
        assert b.__weakref__ is None
        w1 = _weakref.ref(a)
        w2 = _weakref.ref(a, callable)
        assert a.__weakref__ is w1
        del a
        gc.collect()
        assert w1() is None
        assert w() is None
        assert w2() is None
        assert b.a == 42

    def test_function_weakrefable(self):
        import _weakref, gc
        def f(x):
            return 42
        wf = _weakref.ref(f)
        assert wf()(63) == 42
        del f
        gc.collect()
        assert wf() is None

    def test_method_weakrefable(self):
        import _weakref, gc
        class A(object):
            def f(self):
                return 42
        a = A()
        meth = A.f
        w_unbound = _weakref.ref(meth)
        assert w_unbound()(A()) == 42
        meth = A().f
        w_bound = _weakref.ref(meth)
        assert w_bound()() == 42
        del meth
        gc.collect()
        # it used to be None on py2, but now there is no longer a newly
        # created unbound method object
        assert w_unbound() is A.f
        assert w_bound() is None

    def test_set_weakrefable(self):
        import _weakref, gc
        s = set([1, 2, 3, 4])
        w = _weakref.ref(s)
        assert w() is s
        del s
        gc.collect()
        assert w() is None

    def test_generator_weakrefable(self):
        import _weakref, gc
        def f(x):
            for i in range(x):
                yield i
        g = f(10)
        w = _weakref.ref(g)
        r = next(w())
        assert r == 0
        r = next(g)
        assert r == 1
        del g
        gc.collect()
        assert w() is None
        g = f(10)
        w = _weakref.ref(g)
        assert list(g) == list(range(10))
        del g
        gc.collect()
        assert w() is None

    def test_weakref_subclass_with_del(self):
        import _weakref, gc
        class Ref(_weakref.ref):
            def __del__(self):
                b.a = 42
        class A(object):
            pass
        a = A()
        b = A()
        b.a = 1
        w = Ref(a)
        del w
        gc.collect()
        assert b.a == 42
        if _weakref.getweakrefcount(a) > 0:
            # the following can crash if the presence of the applevel __del__
            # leads to the fact that the __del__ of _weakref.ref is not called.
            assert _weakref.getweakrefs(a)[0]() is a

    def test_buggy_case(self):
        import gc, weakref
        gone = []
        class A(object):
            def __del__(self):
                gone.append(True)
        a = A()
        w = weakref.ref(a)
        del a
        tries = 5
        for i in range(5):
            if not gone:
                gc.collect()
        if gone:
            a1 = w()
            assert a1 is None

    def test_del_and_callback_and_id(self):
        if not self.runappdirect:
            skip("the id() doesn't work correctly in __del__ and "
                 "callbacks before translation")
        import gc, weakref
        seen_del = []
        class A(object):
            def __del__(self):
                seen_del.append(id(self))
                seen_del.append(w1() is None)
                seen_del.append(w2() is None)
        seen_callback = []
        def callback(r):
            seen_callback.append(r is w2)
            seen_callback.append(w1() is None)
            seen_callback.append(w2() is None)
        a = A()
        w1 = weakref.ref(a)
        w2 = weakref.ref(a, callback)
        aid = id(a)
        del a
        for i in range(5):
            gc.collect()
        if seen_del:
            assert seen_del == [aid, True, True]
        if seen_callback:
            assert seen_callback == [True, True, True]

    def test_type_weakrefable(self):
        import _weakref, gc
        w = _weakref.ref(list)
        assert w() is list
        gc.collect()
        assert w() is list


class AppTestProxy(object):
    spaceconfig = dict(usemodules=('_weakref',))
                    
    def test_simple(self):
        import _weakref, gc
        class A(object):
            def __init__(self, x):
                self.x = x
        a = A(1)
        p = _weakref.proxy(a)
        assert p.x == 1
        assert str(p) == str(a)
        raises(TypeError, p)

    def test_caching(self):
        import _weakref, gc
        class A(object): pass
        a = A()
        assert _weakref.proxy(a) is _weakref.proxy(a)
        assert _weakref.proxy(a) is _weakref.proxy(a, None)

    def test_callable_proxy(self):
        import _weakref, gc
        class A(object):
            def __call__(self):
                global_a.x = 1
        global_a = A()
        global_a.x = 41
        A_ = _weakref.proxy(A)
        a = A_()
        assert isinstance(a, A)
        a_ = _weakref.proxy(a)
        a_()
        assert global_a.x == 1

    def test_callable_proxy_type(self):
        import _weakref, gc
        class Callable(object):
            def __call__(self, x):
                pass
        o = Callable()
        ref1 = _weakref.proxy(o)
        assert type(ref1) is _weakref.CallableProxyType

    def test_dont_create_directly(self):
        import _weakref, gc
        raises(TypeError, _weakref.ProxyType, [])
        raises(TypeError, _weakref.CallableProxyType, [])

    def test_dont_hash(self):
        import _weakref, gc
        class A(object):
            pass
        a = A()
        p = _weakref.proxy(a)
        raises(TypeError, hash, p)

    def test_subclassing_not_allowed(self):
        import _weakref, gc
        def tryit():
            class A(_weakref.ProxyType):
                pass
            return A
        raises(TypeError, tryit)

    def test_proxy_to_dead_object(self):
        import _weakref, gc
        class A(object):
            pass
        p = _weakref.proxy(A())
        gc.collect()
        raises(ReferenceError, "p + 1")

    def test_proxy_with_callback(self):
        import _weakref, gc
        class A(object):
            pass
        a2 = A()
        def callback(proxy):
            a2.seen = proxy
        p = _weakref.proxy(A(), callback)
        gc.collect()
        raises(ReferenceError, "p + 1")
        assert a2.seen is p

    def test_repr(self):
        import _weakref, gc
        for kind in ('ref', 'proxy'):
            def foobaz():
                "A random function not returning None."
                return 42
            w = getattr(_weakref, kind)(foobaz)
            s = repr(w)
            print(s)
            if kind == 'ref':
                assert s.startswith('<weakref at ')
            else:
                assert (s.startswith('<weakproxy at ') or
                        s.startswith('<weakcallableproxy at '))
            assert "function" in s
            del foobaz
            try:
                for i in range(10):
                    if w() is None:
                        break     # only reachable if kind == 'ref'
                    gc.collect()
            except ReferenceError:
                pass    # only reachable if kind == 'proxy'
            s = repr(w)
            print(s)
            assert "dead" in s

    def test_bytes(self):
        import _weakref
        class C(object):
            def __bytes__(self):
                return b"string"
        instance = C()
        assert "__bytes__" in dir(_weakref.proxy(instance))
        assert bytes(_weakref.proxy(instance)) == b"string"

    def test_reversed(self):
        import _weakref
        class C(object):
            def __reversed__(self):
                return b"string"
        instance = C()
        assert "__reversed__" in dir(_weakref.proxy(instance))
        assert reversed(_weakref.proxy(instance)) == b"string"

    def test_eq(self):
        import _weakref
        class A(object):
            pass

        a = A()
        assert not(_weakref.ref(a) == a)
        assert _weakref.ref(a) != a

        class A(object):
            def __eq__(self, other):
                return True
            def __ne__(self, other):
                return False

        a = A()
        assert _weakref.ref(a) == a

    def test_callback_raises(self):
        import _weakref, gc
        class A(object):
            pass
        a1 = A()
        def callback(ref):
            explode
        ref1 = _weakref.ref(a1, callback)
        del a1
        gc.collect()
        assert ref1() is None

    def test_init(self):
        import _weakref, gc
        # Issue 3634
        # <weakref to class>.__init__() doesn't check errors correctly
        r = _weakref.ref(Exception)
        raises(TypeError, r.__init__, 0, 0, 0, 0, 0)
        # No exception should be raised here
        gc.collect()

    def test_add(self):
        import _weakref
        class A(object):
            def __add__(self, other):
                return other
        a1 = A()
        a2 = A()
        p1 = _weakref.proxy(a1)
        p2 = _weakref.proxy(a2)
        a3 = p1 + p2
        assert a3 is a2

    def test_inplace_add(self):
        import _weakref
        class A(object):
            def __add__(self, other):
                return other
        a1 = A()
        a2 = A()
        p1 = _weakref.proxy(a1)
        p2 = _weakref.proxy(a2)
        p1 += p2
        assert p1 is a2

    def test_setattr(self):
        import _weakref
        class A(object):
            def __setitem__(self, key, value):
                self.setkey = key
                self.setvalue = value
        a1 = A()
        a2 = A()
        p1 = _weakref.proxy(a1)
        p2 = _weakref.proxy(a2)
        p1[p2] = 42
        assert a1.setkey is p2
        assert a1.setvalue == 42
        #
        p1[42] = p2
        assert a1.setkey == 42
        assert a1.setvalue is p2

    def test_error_message_wrong_self(self):
        import _weakref
        unboundmeth = _weakref.ref.__repr__
        e = raises(TypeError, unboundmeth, 42)
        assert "weakref" in str(e.value)
        if hasattr(unboundmeth, 'im_func'):
            e = raises(TypeError, unboundmeth.im_func, 42)
            assert "'weakref-or-proxy'" in str(e.value)

    def test_reverse_add(self):
        import _weakref
        class A:
            def __add__(self, other):
                return 17

            def __radd__(self, other):
                return 20

            def __iadd__(self, other):
                return 19

        assert A() + 12 == 17
        assert 12 + A() == 20
        a = A()
        a += -1
        assert a == 19

        a = A()
        p = _weakref.proxy(a)
        assert p + 12 == 17
        print(12 + p)
        assert 12 + p == 20
        p += -1
        assert p == 19

    def test_gt_lt(self):
        import _weakref
        class A:
            def __gt__(self, other):
                return True

            def __lt__(self, other):
                return False

        assert (A() > 12) == True
        assert (12 > A()) == False

        a = A()
        p = _weakref.proxy(a)
        assert (p > 12) == True
        print(12 > p)
        assert (12 > p) == False
