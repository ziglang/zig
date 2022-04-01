
from rpython.jit.metainterp.test.support import LLJitMixin, noConst
from rpython.rlib import jit

class CallTest(object):
    def test_indirect_call(self):
        @jit.dont_look_inside
        def f1(x):
            return x + 1

        @jit.dont_look_inside
        def f2(x):
            return x + 2

        @jit.dont_look_inside
        def choice(i):
            if i:
                return f1
            return f2

        def f(i):
            func = choice(i)
            return func(i)

        res = self.interp_operations(f, [3])
        assert res == f(3)

    def test_cond_call(self):
        def f(l, n):
            l.append(n)

        def main(n):
            l = []
            jit.conditional_call(n == 10, f, l, n)
            return len(l)

        assert self.interp_operations(main, [10]) == 1
        assert self.interp_operations(main, [5]) == 0

    def test_cond_call_disappears(self):
        driver = jit.JitDriver(greens = [], reds = ['n'])

        def f(n):
            raise ValueError

        def main(n):
            while n > 0:
                driver.jit_merge_point(n=n)
                jit.conditional_call(False, f, 10)
                n -= 1
            return 42

        assert self.meta_interp(main, [10]) == 42
        self.check_resops(guard_no_exception=0)

    def test_cond_call_i(self):
        def f(n):
            return n * 200

        def main(n, m):
            return jit.conditional_call_elidable(n, f, m)

        assert self.interp_operations(main, [0, 10]) == 2000
        assert self.interp_operations(main, [15, 42]) == 15

    def test_cond_call_r(self):
        def f(n):
            return [n]

        def main(n):
            if n == 10:
                l = []
            else:
                l = None
            l = jit.conditional_call_elidable(l, f, n)
            return len(l)

        assert main(10) == 0
        assert main(5) == 1
        assert self.interp_operations(main, [10]) == 0
        assert self.interp_operations(main, [5]) == 1

    def test_cond_call_constant_in_pyjitpl(self):
        def f(a, b):
            return a + b
        def main(n):
            # this is completely constant-folded because the arguments
            # to f() are constants.
            return jit.conditional_call_elidable(n, f, 40, 2)

        assert main(12) == 12
        assert main(0) == 42
        assert self.interp_operations(main, [12]) == 12
        self.check_operations_history({'finish': 1})   # empty history
        assert self.interp_operations(main, [0]) == 42
        self.check_operations_history({'finish': 1})   # empty history

    def test_cond_call_constant_in_optimizer(self):
        myjitdriver = jit.JitDriver(greens = ['m'], reds = ['n', 'p'])
        def externfn(x):
            return x - 3
        class V:
            def __init__(self, value):
                self.value = value
        def f(n, m, p):
            while n > 0:
                myjitdriver.can_enter_jit(n=n, p=p, m=m)
                myjitdriver.jit_merge_point(n=n, p=p, m=m)
                m1 = noConst(m)
                n -= jit.conditional_call_elidable(p, externfn, m1)
            return n
        res = self.meta_interp(f, [21, 5, 0])
        assert res == -1
        # the COND_CALL_VALUE is constant-folded away by optimizeopt.py
        self.check_resops({'int_sub': 2, 'int_gt': 2, 'guard_true': 2,
                           'jump': 1})

    def test_cond_call_constant_in_optimizer_1(self):
        # same as test_cond_call_constant_in_optimizer, but the 'value'
        # argument changes
        myjitdriver = jit.JitDriver(greens = ['m'], reds = ['n', 'p'])
        def externfn(x):
            return x - 3
        class V:
            def __init__(self, value):
                self.value = value
        def f(n, m, p):
            while n > 0:
                myjitdriver.can_enter_jit(n=n, p=p, m=m)
                myjitdriver.jit_merge_point(n=n, p=p, m=m)
                m1 = noConst(m)
                n -= jit.conditional_call_elidable(p, externfn, m1)
            return n
        assert f(21, 5, 0) == -1
        res = self.meta_interp(f, [21, 5, 0])
        assert res == -1
        # the COND_CALL_VALUE is constant-folded away by optimizeopt.py
        self.check_resops({'int_sub': 2, 'int_gt': 2, 'guard_true': 2,
                           'jump': 1})

    def test_cond_call_constant_in_optimizer_2(self):
        myjitdriver = jit.JitDriver(greens = ['m'], reds = ['n', 'p'])
        def externfn(x):
            return 2
        def f(n, m, p):
            while n > 0:
                myjitdriver.can_enter_jit(n=n, p=p, m=m)
                myjitdriver.jit_merge_point(n=n, p=p, m=m)
                assert p > -1
                assert p < 1
                n -= jit.conditional_call_elidable(p, externfn, n)
            return n
        res = self.meta_interp(f, [21, 5, 0])
        assert res == -1
        # optimizer: the COND_CALL_VALUE is turned into a regular
        # CALL_PURE, which itself becomes a CALL
        self.check_resops(call_pure_i=0, cond_call_value_i=0, call_i=2,
                          int_sub=2)

    def test_cond_call_constant_in_optimizer_3(self):
        myjitdriver = jit.JitDriver(greens = ['m'], reds = ['n', 'p'])
        def externfn(x):
            return 1
        def f(n, m, p):
            while n > 0:
                myjitdriver.can_enter_jit(n=n, p=p, m=m)
                myjitdriver.jit_merge_point(n=n, p=p, m=m)
                assert p > -1
                assert p < 1
                n0 = n
                n -= jit.conditional_call_elidable(p, externfn, n0)
                n -= jit.conditional_call_elidable(p, externfn, n0)
            return n
        res = self.meta_interp(f, [21, 5, 0])
        assert res == -1
        # same as test_cond_call_constant_in_optimizer_2, but the two
        # intermediate CALL_PUREs are replaced with only one, because
        # they are called with the same arguments
        self.check_resops(call_pure_i=0, cond_call_value_i=0, call_i=2,
                          int_sub=4)

    def test_cond_call_constant_in_optimizer_4(self):
        class X:
            def __init__(self, value):
                self.value = value
                self.triple = 0
            def _compute_triple(self):
                self.triple = self.value * 3
                return self.triple
            def get_triple(self):
                return jit.conditional_call_elidable(self.triple,
                                                  X._compute_triple, self)

        myjitdriver = jit.JitDriver(greens = [], reds = 'auto')
        def main(n):
            total = 0
            while n > 1:
                myjitdriver.jit_merge_point()
                x = X(n)
                total += x.get_triple() + x.get_triple() + x.get_triple()
                n -= 10
            return total

        res = self.meta_interp(main, [100])
        assert res == main(100)
        # remaining: only the first call to get_triple(), as a call_i
        # because we know that x.triple == 0 here.  The remaining calls
        # are removed because equal to the first one.
        self.check_resops(call_i=2, cond_call_value_i=0,
                          new_with_vtable=2)  # escapes: _compute_triple(self)

    def test_cond_call_constant_in_optimizer_5(self):
        def _compute_triple(value):
            return value * 3
        class X:
            def __init__(self, value):
                self.value = value
                self.triple = 0
            def get_triple(self):
                res = jit.conditional_call_elidable(self.triple,
                                                    _compute_triple, self.value)
                self.triple = res
                return res

        myjitdriver = jit.JitDriver(greens = [], reds = 'auto')
        def main(n):
            total = 0
            while n > 1:
                myjitdriver.jit_merge_point()
                x = X(n)
                total += x.get_triple() + x.get_triple() + x.get_triple()
                n -= 10
            return total

        res = self.meta_interp(main, [100])
        assert res == main(100)
        # remaining: only the first call to get_triple(), as a call_i
        # because we know that x.triple == 0 here.  The remaining calls
        # are removed because equal to the first one.
        self.check_resops(call_i=2, cond_call_value_i=0,
                          new_with_vtable=0)  # all virtual

    def test_cond_call_multiple_in_optimizer_1(self):
        # test called several times with the same arguments, but
        # the condition is not available to the short preamble.
        # This means that the second cond_call_value after unrolling
        # can't be removed.
        myjitdriver = jit.JitDriver(greens = [], reds = ['n', 'p', 'm'])
        def externfn(x):
            return 2000      # never actually called
        @jit.dont_look_inside
        def randomish(p):
            return p + 1
        def f(n, m, p):
            while n > 0:
                myjitdriver.can_enter_jit(n=n, p=p, m=m)
                myjitdriver.jit_merge_point(n=n, p=p, m=m)
                n -= jit.conditional_call_elidable(randomish(p), externfn, m)
            return n
        assert f(21, 5, 1) == -1
        res = self.meta_interp(f, [21, 5, 1])
        assert res == -1
        self.check_resops(call_pure_i=0, cond_call_value_i=2,
                          call_i=2,    # randomish()
                          int_sub=2)

    def test_cond_call_multiple_in_optimizer_2(self):
        # test called several times with the same arguments.  Ideally
        # we would like them to be consolidated into one call even if
        # the 'value' are different but available from the short
        # preamble.  We don't do it so far---it's a mess, because the
        # short preamble is supposed to depend only on loop-invariant
        # things, and 'value' is (most of the time) not loop-invariant.
        myjitdriver = jit.JitDriver(greens = [], reds = ['n', 'p', 'm'])
        def externfn(x):
            return 2      # called only the first time
        def f(n, m, p):
            while n > 0:
                myjitdriver.can_enter_jit(n=n, p=p, m=m)
                myjitdriver.jit_merge_point(n=n, p=p, m=m)
                p = jit.conditional_call_elidable(p, externfn, m)
                n -= p
            return n
        assert f(21, 5, 0) == -1
        res = self.meta_interp(f, [21, 5, 0])
        assert res == -1
        self.check_resops(call_pure_i=0,
                          cond_call_value_i=2,   # ideally 1, but see above
                          int_sub=2)

    def test_cond_call_in_blackhole(self):
        myjitdriver = jit.JitDriver(greens = [], reds = ['n', 'p', 'm'])
        def externfn(x):
            return 2
        def f(n, m, p):
            while n > 0:
                myjitdriver.can_enter_jit(n=n, p=p, m=m)
                myjitdriver.jit_merge_point(n=n, p=p, m=m)
                if n > 6:    # will fail and finish in the blackhole
                    pass
                if jit.we_are_jitted():   # manually inline here
                    p = jit._jit_conditional_call_value(p, externfn, m)
                else:
                    p = jit.conditional_call_elidable(p, externfn, m)
                n -= p
            return n
        assert f(21, 5, 0) == -1
        res = self.meta_interp(f, [21, 5, 0])
        assert res == -1

    def test_cond_call_raises(self):
        myjitdriver = jit.JitDriver(greens = [], reds = ['n', 'p', 'm'])
        def externfn(x, m):
            if m == 1 or m == 1008:
                raise ValueError
            return x + m
        def f(n, m, p):
            while n > 0:
                myjitdriver.can_enter_jit(n=n, p=p, m=m)
                myjitdriver.jit_merge_point(n=n, p=p, m=m)
                try:
                    p = jit.conditional_call_elidable(p, externfn, n, m)
                    p -= (n + m)   # => zero again
                except ValueError:
                    m += 1000
                m += 1
                n -= 2
            return n * m
        assert f(21, 0, 0) == -2011
        res = self.meta_interp(f, [21, 0, 0])
        assert res == -2011


class TestCall(LLJitMixin, CallTest):
    pass
