from rpython.rlib.rarithmetic import intmask
from rpython.rtyper.rrange import ll_rangelen, ll_rangeitem, ll_rangeitem_nonneg, dum_nocheck
from rpython.rtyper.lltypesystem import rrange
from rpython.rtyper.test.tool import BaseRtypingTest


class TestRrange(BaseRtypingTest):

    def test_rlist_range(self):
        def test1(start, stop, step, varstep):
            expected = range(start, stop, step)
            length = len(expected)
            if varstep:
                l = rrange.ll_newrangest(start, stop, step)
                step = l.step
            else:
                RANGE = rrange.RangeRepr(step).RANGE
                l = rrange.ll_newrange(RANGE, start, stop)
            assert ll_rangelen(l, step) == length
            lst = [ll_rangeitem(dum_nocheck, l, i, step) for i in range(length)]
            assert lst == expected
            lst = [ll_rangeitem_nonneg(dum_nocheck, l, i, step) for i in range(length)]
            assert lst == expected
            lst = [ll_rangeitem(dum_nocheck, l, i-length, step) for i in range(length)]
            assert lst == expected

        for start in (-10, 0, 1, 10):
            for stop in (-8, 0, 4, 8, 25):
                for step in (1, 2, 3, -1, -2):
                    for varstep in False, True:
                        test1(start, stop, step, varstep)

    def test_range(self):
        def dummyfn(N):
            total = 0
            for i in range(N):
                total += i
            return total
        res = self.interpret(dummyfn, [10])
        assert res == 45

    def test_range_is_lazy(self):
        def dummyfn(N, M):
            total = 0
            for i in range(M):
                if i == N:
                    break
                total += i
            return total
        res = self.interpret(dummyfn, [10, 2147418112])
        assert res == 45

    def test_range_item(self):
        def dummyfn(start, stop, i):
            r = range(start, stop)
            return r[i]
        res = self.interpret(dummyfn, [10, 17, 4])
        assert res == 14
        res = self.interpret(dummyfn, [10, 17, -2])
        assert res == 15

    def test_xrange(self):
        def dummyfn(N):
            total = 0
            for i in xrange(N):
                total += i
            return total
        res = self.interpret(dummyfn, [10])
        assert res == 45

    def test_range_len_nostep(self):
        def dummyfn(start, stop):
            r = range(start, stop)
            return len(r)
        start, stop = 10, 17
        res = self.interpret(dummyfn, [start, stop])
        assert res == dummyfn(start, stop)
        start, stop = 17, 10
        res = self.interpret(dummyfn, [start, stop])
        assert res == 0

    def test_range_len_step_const(self):
        def dummyfn(start, stop):
            r = range(start, stop, -2)
            return len(r)
        start, stop = 10, 17
        res = self.interpret(dummyfn, [start, stop])
        assert res == 0
        start, stop = 17, 10
        res = self.interpret(dummyfn, [start, stop])
        assert res == dummyfn(start, stop)

    def test_range_len_step_nonconst(self):
        def dummyfn(start, stop, step):
            r = range(start, stop, step)
            return len(r)
        start, stop, step = 10, 17, -3
        res = self.interpret(dummyfn, [start, stop, step])
        assert res == 0
        start, stop, step = 17, 10, -3
        res = self.interpret(dummyfn, [start, stop, step])
        assert res == dummyfn(start, stop, step)

    def test_range2list(self):
        def dummyfn(start, stop):
            r = range(start, stop)
            r.reverse()
            return r[0]
        start, stop = 10, 17
        res = self.interpret(dummyfn, [start, stop])
        assert res == dummyfn(start, stop)

    def check_failed(self, func, *args):
        try:
            self.interpret(func, *args, **kwargs)
        except:
            return True
        else:
            return False

    def test_range_extra(self):
        def failingfn_const():
            r = range(10, 17, 0)
            return r[-1]
        assert self.check_failed(failingfn_const, [])

        def failingfn_var(step):
            r = range(10, 17, step)
            return r[-1]
        step = 3
        res = self.interpret(failingfn_var, [step])
        assert res == failingfn_var(step)
        step = 0
        assert self.check_failed(failingfn_var, [step])

    def test_range_iter(self):
        def fn(start, stop, step):
            res = 0
            if step == 0:
                if stop >= start:
                    r = range(start, stop, 1)
                else:
                    r = range(start, stop, -1)
            else:
                r = range(start, stop, step)
            for i in r:
                res = res * 51 + i
            return res
        for args in [2, 7, 0], [7, 2, 0], [10, 50, 7], [50, -10, -3]:
            res = self.interpret(fn, args)
            assert res == intmask(fn(*args))

    def test_empty_range(self):
        def g(lst):
            total = 0
            for i in range(len(lst)):
                total += lst[i]
            return total
        def fn():
            return g([])
        res = self.interpret(fn, [])
        assert res == 0

    def test_enumerate(self):
        def fn(n):
            for i, x in enumerate([123, 456, 789, 654]):
                if i == n:
                    return x
            return 5
        res = self.interpret(fn, [2])
        assert res == 789

    def test_enumerate_startindex(self):
        def fn(n):
            for i, x in enumerate([123, 456, 789, 654], 5):
                if i == n:
                    return x
            return 5
        res = self.interpret(fn, [7])
        assert res == 789

    def test_enumerate_instances(self):
        class A:
            pass
        def fn(n):
            a = A()
            b = A()
            a.k = 10
            b.k = 20
            for i, x in enumerate([a, b]):
                if i == n:
                    return x.k
            return 5
        res = self.interpret(fn, [1])
        assert res == 20

    def test_extend_range(self):
        def fn(n):
            lst = [n, n, n]
            lst.extend(range(n))
            return len(lst)
        res = self.interpret(fn, [5])
        assert res == 8
