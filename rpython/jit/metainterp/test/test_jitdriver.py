"""Tests for multiple JitDrivers."""
import py
from rpython.rlib.jit import JitDriver, unroll_safe, set_param
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.metainterp.warmspot import get_stats


def getloc1():
    return "in jitdriver1"

def getloc2(g):
    return "in jitdriver2, with g=%d" % g

class MultipleJitDriversTests(object):

    def test_simple(self):
        myjitdriver1 = JitDriver(greens=[], reds=['n', 'm'],
                                 get_printable_location = getloc1)
        myjitdriver2 = JitDriver(greens=['g'], reds=['r'],
                                 get_printable_location = getloc2)
        #
        def loop1(n, m):
            while n > 0:
                myjitdriver1.can_enter_jit(n=n, m=m)
                myjitdriver1.jit_merge_point(n=n, m=m)
                n -= m
            return n
        #
        def loop2(g, r):
            while r > 0:
                myjitdriver2.can_enter_jit(g=g, r=r)
                myjitdriver2.jit_merge_point(g=g, r=r)
                r += loop1(r, g) + (-1)
            return r
        #
        res = self.meta_interp(loop2, [4, 40], repeat=7, inline=True)
        assert res == loop2(4, 40)
        # we expect only one int_sub, corresponding to the single
        # compiled instance of loop1()
        self.check_resops(int_sub=2)
        # the following numbers are not really expectations of the test
        # itself, but just the numbers that we got after looking carefully
        # at the generated machine code
        self.check_trace_count(5)
        self.check_jitcell_token_count(2)    # 2 x loop including enter bridge
        self.check_target_token_count(4)    # 2 x loop, 2 x enter bridge
        self.check_enter_count(5)

    def test_inline(self):
        # this is not an example of reasonable code: loop1() is unrolled
        # 'n/m' times, where n and m are given as red arguments.
        myjitdriver1 = JitDriver(greens=[], reds=['n', 'm'],
                                 get_printable_location = getloc1)
        myjitdriver2 = JitDriver(greens=['g'], reds=['r'],
                                 get_printable_location = getloc2)
        #
        def loop1(n, m):
            while n > 0:
                if n > 1000:
                    myjitdriver1.can_enter_jit(n=n, m=m)
                myjitdriver1.jit_merge_point(n=n, m=m)
                n -= m
            return n
        #
        def loop2(g, r):
            set_param(None, 'function_threshold', 0)
            while r > 0:
                myjitdriver2.can_enter_jit(g=g, r=r)
                myjitdriver2.jit_merge_point(g=g, r=r)
                r += loop1(r, g) - 1
            return r
        #
        res = self.meta_interp(loop2, [4, 40], repeat=7, inline=True)
        assert res == loop2(4, 40)
        # we expect no loop at all for 'loop1': it should always be inlined
        # we do however get several version of 'loop2', all of which contains
        # at least one int_add, while there are no int_add's in 'loop1'
        self.check_jitcell_token_count(1)
        for loop in get_stats().loops:
            assert loop.summary()['int_add'] >= 1

    def test_inactive_jitdriver(self):
        myjitdriver1 = JitDriver(greens=[], reds=['n', 'm'],
                                 get_printable_location = getloc1)
        myjitdriver2 = JitDriver(greens=['g'], reds=['r'],
                                 get_printable_location = getloc2)
        #
        myjitdriver1.active = False    # <===
        #
        def loop1(n, m):
            while n > 0:
                myjitdriver1.can_enter_jit(n=n, m=m)
                myjitdriver1.jit_merge_point(n=n, m=m)
                n -= m
            return n
        #
        def loop2(g, r):
            while r > 0:
                myjitdriver2.can_enter_jit(g=g, r=r)
                myjitdriver2.jit_merge_point(g=g, r=r)
                r += loop1(r, g) + (-1)
            return r
        #
        res = self.meta_interp(loop2, [4, 40], repeat=7, inline=True)
        assert res == loop2(4, 40)
        # we expect no int_sub, but a residual call
        self.check_resops(call_i=2, int_sub=0)

    def test_multiple_jits_trace_too_long(self):
        myjitdriver1 = JitDriver(greens=["n"], reds=["i", "box"])
        myjitdriver2 = JitDriver(greens=["n"], reds=["i"])

        class IntBox(object):
            def __init__(self, val):
                self.val = val

        def loop1(n):
            i = 0
            box = IntBox(10)
            while i < n:
                myjitdriver1.can_enter_jit(n=n, i=i, box=box)
                myjitdriver1.jit_merge_point(n=n, i=i, box=box)
                i += 1
                loop2(box)
            return i

        def loop2(n):
            i = 0
            f(10)
            while i < n.val:
                myjitdriver2.can_enter_jit(n=n, i=i)
                myjitdriver2.jit_merge_point(n=n, i=i)
                i += 1

        @unroll_safe
        def f(n):
            i = 0
            while i < n:
                i += 1

        res = self.meta_interp(loop1, [10], inline=True, trace_limit=6)
        assert res == 10
        stats = get_stats()
        assert stats.aborted_keys == [None, None]

    def test_inline_across_languages(self):
        py.test.skip("why does this not work")
        driver_weird = JitDriver(
            greens = ["pc", "bc"],
            reds = ["acc", "x", "y", "z"])

        def interp1(bc, x, y, z):
            pc = 0
            acc = 0
            while True:
                driver_weird.jit_merge_point(bc=bc, pc=pc, acc=acc, x=x, y=y, z=z)
                op = ord(bc[pc])
                pc += 1
                if op == 0:
                    acc += x
                if op == 1:
                    acc += y
                if op == 2:
                    acc *= z
                if op == 3:
                    pc = 0
                if pc >= len(bc):
                    break
            return acc

        driver = JitDriver(
                greens = ["substract"],
                reds = ["x"],
        )
        def interp2(x):
            substract = interp1('\x00', 0, 0, 0)
            while True:
                driver.jit_merge_point(substract=substract, x=x)
                substract += 1
                if x < 0:
                    break
                if substract == 10:
                    # computes x + 1 * (-1)
                    x = interp1('\x01\x02\x00', x, 1, -1)
                    substract = 0
        interp2(100)
        self.meta_interp(interp2, [100], listcomp=True, backendopt=True,
                         listops=True, inline=True)
        self.check_resops(call_assembler=0)

    def test_get_unique_id(self):
        def get_unique_id(pc):
            return pc + 1
        
        driver = JitDriver(greens=["pc"], reds='auto',
                           get_unique_id=get_unique_id, is_recursive=True)

        def f(arg):
            i = 0
            pc = 0
            while i < 30 and pc < 3:
                driver.jit_merge_point(pc=pc)
                pc += 1
                if arg == 0 and pc == 3:
                    pc = 0
                if arg == 0:
                    f(1)
                i += 1

        self.meta_interp(f, [0], inline=True)
        loop = get_stats().loops[1]
        for op in loop.operations:
            if op.getopname() == 'enter_portal_frame':
                assert op.getarg(0).getint() == 0
                assert op.getarg(1).getint() == 1

    def test_manual_leave_enter_portal_frame(self):
        from rpython.rlib import jit
        driver = JitDriver(greens=[], reds='auto', is_recursive=True)

        def f(arg):
            i = 0
            while i < 100:
                driver.jit_merge_point()
                jit.enter_portal_frame(42)
                jit.leave_portal_frame()
                i += 1

        self.meta_interp(f, [0])
        self.check_simple_loop(enter_portal_frame=1, leave_portal_frame=1)

class TestLLtype(MultipleJitDriversTests, LLJitMixin):
    pass
