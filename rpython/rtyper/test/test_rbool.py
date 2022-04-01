from rpython.translator.translator import TranslationContext
from rpython.rtyper.test import snippet
from rpython.rtyper.test.tool import BaseRtypingTest


class TestSnippet(object):
    def _test(self, func, types):
        t = TranslationContext()
        t.buildannotator().build_types(func, types)
        t.buildrtyper().specialize()
        t.checkgraphs()

    def test_not1(self):
        self._test(snippet.not1, [bool])

    def test_not2(self):
        self._test(snippet.not2, [bool])

    def test_bool1(self):
        self._test(snippet.bool1, [bool])

    def test_bool_cast1(self):
        self._test(snippet.bool_cast1, [bool])


class TestRbool(BaseRtypingTest):

    def test_bool2int(self):
        def f(n):
            if n:
                n = 2
            return n
        res = self.interpret(f, [False])
        assert res == 0 and res is not False   # forced to int by static typing
        res = self.interpret(f, [True])
        assert res == 2

    def test_arithmetic_with_bool_inputs(self):
        def f(n):
            a = n * ((n>2) + (n>=2))
            a -= (a != n) > False
            return a + (-(n<0))
        for i in [-1, 1, 2, 42]:
            res = self.interpret(f, [i])
            assert res == f(i)

    def test_bool2str(self):
        def f(n, m):
            if m == 1:
                return hex(n > 5)
            elif m == 2:
                return oct(n > 5)
            else:
                return str(n > 5)
        res = self.interpret(f, [2, 0])
        assert self.ll_to_string(res) in ('0', 'False')   # unspecified so far
        res = self.interpret(f, [9, 0])
        assert self.ll_to_string(res) in ('1', 'True')    # unspecified so far
        res = self.interpret(f, [2, 1])
        assert self.ll_to_string(res) == '0x0'
        res = self.interpret(f, [9, 1])
        assert self.ll_to_string(res) == '0x1'
        res = self.interpret(f, [2, 2])
        assert self.ll_to_string(res) == '0'
        res = self.interpret(f, [9, 2])
        assert self.ll_to_string(res) == '01'

    def test_bool_int_mixture(self):
        def f(x, y):
            return x/y
        res = self.interpret(f, [True, 1])
        assert res == 1
        res = self.interpret(f, [1, True])
        assert res == 1
