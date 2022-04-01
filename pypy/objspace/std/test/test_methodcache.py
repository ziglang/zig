import pytest
from pypy.objspace.std.test import test_typeobject


@pytest.mark.skipif('config.option.runappdirect')
class AppTestMethodCaching(test_typeobject.AppTestTypeObject):
    spaceconfig = {"objspace.std.withmethodcachecounter": True}

    def setup_class(cls):
        # This is for the following tests, which are a bit fragile and
        # historically have been failing once in a while.  With this hack,
        # they are run up to 5 times in a row, saving the frame of the
        # failed attempt.  This means occasional collisions should work
        # differently during the retry.
        cls.w_retry = cls.space.appexec([], """():
            def retry(run):
                keepalive = []
                for i in range(4):
                    try:
                        return run()
                    except AssertionError:
                        import sys
                        keepalive.append(sys.exc_info())
                return run()
            return retry
        """)

    def test_mix_classes(self):
        @self.retry
        def run():
            import __pypy__
            class A(object):
                def f(self):
                    return 42
            class B(object):
                def f(self):
                    return 43
            class C(object):
                def f(self):
                    return 44
            l = [A(), B(), C()] * 10
            __pypy__.reset_method_cache_counter()
            for i, a in enumerate(l):
                assert a.f() == 42 + i % 3
            cache_counter = __pypy__.method_cache_counter("f")
            assert cache_counter[0] >= 15
            assert cache_counter[1] >= 3 # should be (27, 3)
            assert sum(cache_counter) == 30


    def test_subclasses(self):
        @self.retry
        def run():
            import __pypy__
            class A(object):
                def f(self):
                    return 42
            class B(object):
                def f(self):
                    return 43
            class C(A):
                pass
            l = [A(), B(), C()] * 10
            __pypy__.reset_method_cache_counter()
            for i, a in enumerate(l):
                assert a.f() == 42 + (i % 3 == 1)
            cache_counter = __pypy__.method_cache_counter("f")
            assert cache_counter[0] >= 15
            assert cache_counter[1] >= 3 # should be (27, 3)
            assert sum(cache_counter) == 30

    def test_many_names(self):
        @self.retry
        def run():
            import __pypy__
            laste = None
            for j in range(20):
                class A(object):
                    def f(self):
                        return 42
                class B(object):
                    def f(self):
                        return 43
                class C(A):
                    pass
                l = [A(), B(), C()] * 10
                __pypy__.reset_method_cache_counter()
                for i, a in enumerate(l):
                    assert a.f() == 42 + (i % 3 == 1)
                cache_counter = __pypy__.method_cache_counter("f")
                assert cache_counter[0] >= 15
                assert cache_counter[1] >= 3 # should be (27, 3)
                assert sum(cache_counter) == 30

                a = A()
                names = [name for name in A.__dict__.keys()
                         if not name.startswith('_')]
                names.sort()
                names_repeated = names * 10
                result = []
                __pypy__.reset_method_cache_counter()
                for name in names_repeated:
                    result.append(getattr(a, name))
                append_counter = __pypy__.method_cache_counter("append")
                names_counters = [__pypy__.method_cache_counter(name)
                                  for name in names]
                try:
                    assert append_counter[0] >= 10 * len(names) - 1
                    for name, count in zip(names, names_counters):
                        assert count == (9, 1), str((name, count))
                    break
                except AssertionError as e:
                    laste = e
            else:
                raise laste

    def test_mutating_bases(self):
        class C(object):
            pass
        class C2(object):
            foo = 5
        class D(C):
            pass
        class E(D):
            pass
        d = D()
        e = E()
        D.__bases__ = (C2,)
        assert e.foo == 5

        class F(object):
            foo = 3
        D.__bases__ = (C, F)
        assert e.foo == 3

    def test_custom_metaclass(self):
        @self.retry
        def run():
            import __pypy__
            for j in range(20):
                class MetaA(type):
                    def __getattribute__(self, x):
                        return 1
                def f(self):
                    return 42
                A = type.__new__(MetaA, "A", (), {"f": f})
                l = [type.__getattribute__(A, "__new__")(A)] * 10
                __pypy__.reset_method_cache_counter()
                for i, a in enumerate(l):
                    # use getattr to circumvent the mapdict cache
                    assert getattr(a, "f")() == 42
                cache_counter = __pypy__.method_cache_counter("f")
                assert sum(cache_counter) == 10
                if cache_counter == (9, 1):
                    break
                #else the moon is misaligned, try again
            else:
                raise AssertionError("cache_counter = %r" % (cache_counter,))

    def test_mutate_class(self):
        @self.retry
        def run():
            import __pypy__
            class A(object):
                x = 1
                y = 2
            __pypy__.reset_method_cache_counter()
            a = A()
            for i in range(100):
                assert a.y == 2
                assert a.x == i + 1
                A.x += 1
            cache_counter = __pypy__.method_cache_counter("x")
            # XXX this is the bad case for the mapdict cache: looking up
            # non-method attributes from the class
            assert cache_counter[0] >= 450
            assert cache_counter[1] >= 1
            assert sum(cache_counter) == 500

            __pypy__.reset_method_cache_counter()
            a = A()
            for i in range(100):
                assert a.y == 2
                setattr(a, "a%s" % i, i)
            cache_counter = __pypy__.method_cache_counter("x")
            assert cache_counter[0] == 0 # 0 hits, because all the attributes are new
