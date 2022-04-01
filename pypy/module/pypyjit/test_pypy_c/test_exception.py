import py
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class TestException(BaseTestPyPyC):

    def test_cmp_exc(self):
        def f1(n):
            # So we don't get a LOAD_GLOBAL op
            KE = KeyError
            i = 0
            while i < n:
                try:
                    raise KE
                except KE: # ID: except
                    i += 1
            return i

        log = self.run(f1, [10000])
        assert log.result == 10000
        loop, = log.loops_by_id("except")
        ops = list(loop.ops_by_id("except", opcode="COMPARE_OP"))
        assert ops == []

    def test_exception_inside_loop_1(self):
        def main(n):
            while n:
                try:
                    raise ValueError
                except ValueError:
                    pass
                n -= 1
            return n
        #
        log = self.run(main, [1000])
        assert log.result == 0
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
        i5 = int_is_true(i3)
        guard_true(i5, descr=...)
        guard_not_invalidated(descr=...)
        --EXC-TICK--
        i12 = int_sub_ovf(i3, 1)
        guard_no_overflow(descr=...)
        --TICK--
        jump(..., descr=...)
        """)

    def test_exception_inside_loop_2(self):
        def main(n):
            def g(n):
                raise ValueError(n)  # ID: raise
            def f(n):
                g(n)
            #
            while n:
                try:
                    f(n)
                except ValueError:
                    pass
                n -= 1
            return n
        #
        log = self.run(main, [1000])
        assert log.result == 0
        loop, = log.loops_by_filename(self.filepath)
        ops = log.opnames(loop.ops_by_id('raise'))
        assert 'new' not in ops

    def test_reraise(self):
        def f(n):
            i = 0
            while i < n:
                try:
                    try:
                        raise KeyError
                    except KeyError:
                        raise
                except KeyError:
                    i += 1
            return i

        log = self.run(f, [100000])
        assert log.result == 100000
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i7 = int_lt(i4, i5)
            guard_true(i7, descr=...)
            guard_not_invalidated(descr=...)
            --EXC-TICK--
            i14 = int_add(i4, 1)
            --TICK--
            jump(..., descr=...)
        """)

    def test_continue_in_finally(self):
        # check that 'continue' inside a try:finally: block is correctly
        # detected as closing a loop
        def f(n):
            i = 0
            while 1:
                try:
                    if i < n:
                        continue
                finally:
                    i += 1
                return i

        log = self.run(f, [2000])
        assert log.result == 2001
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i3 = int_lt(i1, i2)
            guard_true(i3, descr=...)
            i4 = int_add(i1, 1)
            --TICK--
            jump(..., descr=...)
        """)
