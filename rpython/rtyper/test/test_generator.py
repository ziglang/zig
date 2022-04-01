import py

from rpython.rtyper.test.tool import BaseRtypingTest


class TestGenerator(BaseRtypingTest):

    def test_simple_explicit(self):
        def g(a, b, c):
            yield a
            yield b
            yield c
        def f():
            gen = g(3, 5, 8)
            x = gen.next() * 100
            x += gen.next() * 10
            x += gen.next()
            return x
        res = self.interpret(f, [])
        assert res == 358

    def test_cannot_merge(self):
        # merging two different generators is not supported
        # right now, but we can use workarounds like here
        class MyGen:
            _immutable_ = True
            def next(self):
                raise NotImplementedError
        class MyG1(MyGen):
            _immutable_ = True
            def __init__(self, a):
                self._gen = self.g1(a)
            def next(self):
                return self._gen.next()
            @staticmethod
            def g1(a):
                yield a + 1
                yield a + 2
        class MyG2(MyGen):
            _immutable_ = True
            def __init__(self):
                self._gen = self.g2()
            def next(self):
                return self._gen.next()
            @staticmethod
            def g2():
                yield 42
        def f(n):
            if n > 0:
                gen = MyG1(n)
            else:
                gen = MyG2()
            return gen.next()
        res = self.interpret(f, [10])
        assert res == 11
        res = self.interpret(f, [0])
        assert res == 42

    def test_except_block(self):
        def foo():
            raise ValueError
        def g(a, b, c):
            yield a
            yield b
            try:
                foo()
            except ValueError:
                pass
            yield c
        def f():
            gen = g(3, 5, 8)
            x = gen.next() * 100
            x += gen.next() * 10
            x += gen.next()
            return x
        res = self.interpret(f, [])
        assert res == 358

    @py.test.mark.xfail
    def test_different_exception(self):
        def h(c):
            if c == 8:
                raise ValueError
        def g(c):
            try:
                h(c)
            except Exception as e:
                if isinstance(e, ValueError):
                    raise
                raise StopIteration
            yield c

        def f(x):
            try:
                for x in g(x):
                    pass
            except ValueError:
                return -5
            return 5
        assert f(8) == -5
        res = self.interpret(f, [8])
        assert res == -5

    def test_iterating_generator(self):
        def f():
            yield 1
            yield 2
            yield 3
        def g():
            s = 0
            for x in f():
                s += x
            return s
        res = self.interpret(g, [])
        assert res == 6

    def test_generator_with_unreachable_yields(self):
        def f(n):
            if n < 0:
                yield 42
            yield n
            if n < 0:
                yield 43
            yield n
            if n < 0:
                yield 44
        def main(n):
            y = 0
            for x in f(abs(n)):
                y += x
            return y
        res = self.interpret(main, [-100])
        assert res == 200
