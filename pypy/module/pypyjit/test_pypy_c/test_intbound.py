import py
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class TestIntbound(BaseTestPyPyC):

    def test_intbound_simple(self):
        """
        This test only checks that we get the expected result, not that any
        optimization has been applied.
        """
        ops = ('<', '>', '<=', '>=', '==', '!=')
        nbr = (3, 7)
        for o1 in ops:
            for o2 in ops:
                for n1 in nbr:
                    for n2 in nbr:
                        src = '''
                        def f(i):
                            a, b = 3, 3
                            if i %s %d:
                                a = 0
                            else:
                                a = 1
                            if i %s %d:
                                b = 0
                            else:
                                b = 1
                            return a + b * 2

                        def main():
                            res = [0] * 4
                            idx = []
                            for i in range(15):
                                idx.extend([i] * 15)
                            for i in idx:
                                res[f(i)] += 1
                            return res

                        ''' % (o1, n1, o2, n2)
                        yield self.run_and_check, src

    def test_intbound_addsub_mix(self):
        """
        This test only checks that we get the expected result, not that any
        optimization has been applied.
        """
        tests = ('i > 4', 'i > 2', 'i + 1 > 2', '1 + i > 4',
                 'i - 1 > 1', '1 - i > 1', '1 - i < -3',
                 'i == 1', 'i == 5', 'i != 1', '-2 * i < -4')
        for t1 in tests:
            for t2 in tests:
                src = '''
                def f(i):
                    a, b = 3, 3
                    if %s:
                        a = 0
                    else:
                        a = 1
                    if %s:
                        b = 0
                    else:
                        b = 1
                    return a + b * 2

                def main():
                    res = [0] * 4
                    idx = []
                    for i in range(15):
                        idx.extend([i] * 15)
                    for i in idx:
                        res[f(i)] += 1
                    return res

                ''' % (t1, t2)
                yield self.run_and_check, src

    def test_intbound_gt(self):
        def main(n):
            i, a, b = 0, 0, 0
            while i < n:
                if i > -1:
                    a += 1
                if i > -2:
                    b += 1
                i += 1
            return (a, b)
        #
        log = self.run(main, [300])
        assert log.result == (300, 300)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i10 = int_lt(i8, i9)
            guard_true(i10, descr=...)
            i12 = int_add_ovf(i7, 1)
            guard_no_overflow(descr=...)
            i14 = int_add_ovf(i6, 1)
            guard_no_overflow(descr=...)
            i17 = int_add(i8, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_intbound_sub_lt(self):
        def main():
            i, a = 0, 0
            while i < 300:
                if i - 10 < 295:
                    a += 1
                i += 1
            return a
        #
        log = self.run(main, [])
        assert log.result == 300
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i7 = int_lt(i5, 300)
            guard_true(i7, descr=...)
            i9 = int_sub_ovf(i5, 10)
            guard_no_overflow(descr=...)
            i11 = int_add_ovf(i4, 1)
            guard_no_overflow(descr=...)
            i13 = int_add(i5, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_intbound_addsub_ge(self):
        def main(n):
            i, a, b = 0, 0, 0
            while i < n:
                if i + 5 >= 5:
                    a += 1
                if i - 1 >= -1:
                    b += 1
                i += 1
            return (a, b)
        #
        log = self.run(main, [300])
        assert log.result == (300, 300)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i10 = int_lt(i8, i9)
            guard_true(i10, descr=...)
            i12 = int_add_ovf(i8, 5)
            guard_no_overflow(descr=...)
            i14 = int_add_ovf(i7, 1)
            guard_no_overflow(descr=...)
            i16s = int_sub(i8, 1)            
            i16 = int_add_ovf(i6, 1)
            guard_no_overflow(descr=...)
            i19 = int_add(i8, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_intbound_addmul_ge(self):
        def main(n):
            i, a, b = 0, 0, 0
            while i < 300:
                if i + 5 >= 5:
                    a += 1
                if 2 * i >= 0:
                    b += 1
                i += 1
            return (a, b)
        #
        log = self.run(main, [300])
        assert log.result == (300, 300)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i10 = int_lt(i8, 300)
            guard_true(i10, descr=...)
            i12 = int_add(i8, 5)
            i14 = int_add_ovf(i7, 1)
            guard_no_overflow(descr=...)
            i16 = int_lshift(i8, 1)
            i18 = int_add_ovf(i6, 1)
            guard_no_overflow(descr=...)
            i21 = int_add(i8, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_intbound_eq(self):
        def main(a, n):
            i, s = 0, 0
            while i < 300:
                if a == 7:
                    s += a + 1
                elif i == 10:
                    s += i
                else:
                    s += 1
                i += 1
            return s
        #
        log = self.run(main, [7, 300])
        assert log.result == main(7, 300)
        log = self.run(main, [10, 300])
        assert log.result == main(10, 300)
        log = self.run(main, [42, 300])
        assert log.result == main(42, 300)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i10 = int_lt(i8, 300)
            guard_true(i10, descr=...)
            i12 = int_eq(i8, 10)
            guard_false(i12, descr=...)
            i14 = int_add_ovf(i7, 1)
            guard_no_overflow(descr=...)
            i16 = int_add(i8, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_intbound_mul(self):
        def main(a):
            i, s = 0, 0
            while i < 300:
                assert i >= 0
                if 2 * i < 30000:
                    s += 1
                else:
                    s += a
                i += 1
            return s
        #
        log = self.run(main, [7])
        assert log.result == 300
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i8 = int_lt(i6, 300)
            guard_true(i8, descr=...)
            guard_not_invalidated?
            i10 = int_lshift(i6, 1)
            i12 = int_add_ovf(i5, 1)
            guard_no_overflow(descr=...)
            i14 = int_add(i6, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_assert(self):
        def main(a):
            i, s = 0, 0
            while i < 300:
                assert a == 7
                s += a + 1
                i += 1
            return s
        log = self.run(main, [7])
        assert log.result == 300*8
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i8 = int_lt(i6, 300)
            guard_true(i8, descr=...)
            guard_not_invalidated?
            i10 = int_add_ovf(i5, 8)
            guard_no_overflow(descr=...)
            i12 = int_add(i6, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_xor(self):
        def main(b):
            a = sa = 0
            while a < 300:
                if a > 0: # Specialises the loop
                    pass
                if b > 10:
                    pass
                if a^b >= 0:  # ID: guard
                    sa += 1
                sa += a^a     # ID: a_xor_a
                a += 1
            return sa

        log = self.run(main, [11])
        assert log.result == 300
        loop, = log.loops_by_filename(self.filepath)
        # if both are >=0, a^b is known to be >=0
        # note that we know that b>10
        assert loop.match_by_id('guard', """
            i10 = int_xor(i5, i7)
        """)
        #
        # x^x is always optimized to 0
        assert loop.match_by_id('a_xor_a', "")

        log = self.run(main, [9])
        assert log.result == 300
        loop, = log.loops_by_filename(self.filepath)
        # we don't know that b>10, hence we cannot optimize it
        assert loop.match_by_id('guard', """
            i10 = int_xor(i5, i7)
            i12 = int_ge(i10, 0)
            guard_true(i12, descr=...)
        """)
