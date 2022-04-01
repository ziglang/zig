from pypy.module._continuation.test.support import BaseAppTest


class AppTestGenerator(BaseAppTest):

    def test_simple(self):
        from _continuation import generator
        #
        @generator
        def f(gen, n):
            gen.switch(n+1)
            f2(gen, n+2)
            gen.switch(n+3)
        #
        def f2(gen, m):
            gen.switch(m*2)
        #
        g = f(10)
        res = next(g)
        assert res == 11
        res = next(g)
        assert res == 24
        res = next(g)
        assert res == 13
        raises(StopIteration, next, g)

    def test_iterator(self):
        from _continuation import generator
        #
        @generator
        def f(gen, n):
            gen.switch(n+1)
            f2(gen, n+2)
            gen.switch(n+3)
        #
        def f2(gen, m):
            gen.switch(m*2)
        #
        res = list(f(10))
        assert res == [11, 24, 13]
        g = f(20)
        assert iter(g) is g

    def test_bound_method(self):
        from _continuation import generator
        #
        class A(object):
            def __init__(self, m):
                self.m = m
            #
            @generator
            def f(self, gen, n):
                gen.switch(n - self.m)
        #
        a = A(10)
        res = list(a.f(25))
        assert res == [15]

    def test_must_return_None(self):
        from _continuation import generator
        #
        @generator
        def f(gen, n):
            gen.switch(n+1)
            return "foo"
        #
        g = f(10)
        res = next(g)
        assert res == 11
        raises(TypeError, next, g)
