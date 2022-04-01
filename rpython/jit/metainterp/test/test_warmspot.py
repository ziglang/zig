import py
from rpython.jit.metainterp import jitexc
from rpython.jit.metainterp.warmspot import get_stats
from rpython.rlib.jit import JitDriver, set_param, unroll_safe, jit_callback, set_user_param
from rpython.jit.backend.llgraph import runner

from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.metainterp.optimizeopt import ALL_OPTS_NAMES


class Exit(Exception):
    def __init__(self, result):
        self.result = result


class TestLLWarmspot(LLJitMixin):
    CPUClass = runner.LLGraphCPU

    def test_basic(self):
        mydriver = JitDriver(reds=['a'],
                             greens=['i'])
        CODE_INCREASE = 0
        CODE_JUMP = 1
        lst = [CODE_INCREASE, CODE_INCREASE, CODE_JUMP]
        def interpreter_loop(a):
            i = 0
            while True:
                mydriver.jit_merge_point(i=i, a=a)
                if i >= len(lst):
                    break
                elem = lst[i]
                if elem == CODE_INCREASE:
                    a = a + 1
                    i += 1
                elif elem == CODE_JUMP:
                    if a < 20:
                        i = 0
                        mydriver.can_enter_jit(i=i, a=a)
                    else:
                        i += 1
                else:
                    pass
            raise Exit(a)

        def main(a):
            try:
                interpreter_loop(a)
            except Exit as e:
                return e.result

        res = self.meta_interp(main, [1])
        assert res == 21

    def test_reentry(self):
        mydriver = JitDriver(reds = ['n'], greens = [])

        def f(n):
            while n > 0:
                mydriver.can_enter_jit(n=n)
                mydriver.jit_merge_point(n=n)
                if n % 20 == 0:
                    n -= 2
                n -= 1

        res = self.meta_interp(f, [60])
        assert res == f(30)

    def test_location(self):
        def get_printable_location(n):
            return 'GREEN IS %d.' % n
        myjitdriver = JitDriver(greens=['n'], reds=['m'],
                                get_printable_location=get_printable_location)
        def f(n, m):
            while m > 0:
                myjitdriver.can_enter_jit(n=n, m=m)
                myjitdriver.jit_merge_point(n=n, m=m)
                m -= 1

        self.meta_interp(f, [123, 10])
        assert len(get_stats().locations) >= 4
        for loc in get_stats().locations:
            assert loc == (0, 0, 123)

    def test_set_param_enable_opts(self):
        from rpython.rtyper.annlowlevel import llstr, hlstr

        myjitdriver = JitDriver(greens = [], reds = ['n'])
        class A(object):
            def m(self, n):
                return n-1

        def g(n):
            while n > 0:
                myjitdriver.can_enter_jit(n=n)
                myjitdriver.jit_merge_point(n=n)
                n = A().m(n)
            return n
        def f(n, enable_opts):
            set_param(None, 'enable_opts', hlstr(enable_opts))
            return g(n)

        # check that the set_param will override the default
        res = self.meta_interp(f, [10, llstr('')])
        assert res == 0
        self.check_resops(new_with_vtable=1)

        res = self.meta_interp(f, [10, llstr(ALL_OPTS_NAMES)],
                               enable_opts='')
        assert res == 0
        self.check_resops(new_with_vtable=0)

    def test_unwanted_loops(self):
        mydriver = JitDriver(reds = ['n', 'total', 'm'], greens = [])

        def loop1(n):
            # the jit should not look here, as there is a loop
            res = 0
            for i in range(n):
                res += i
            return res

        @unroll_safe
        def loop2(n):
            # the jit looks here, due to the decorator
            for i in range(5):
                n += 1
            return n

        def f(m):
            total = 0
            n = 0
            while n < m:
                mydriver.can_enter_jit(n=n, total=total, m=m)
                mydriver.jit_merge_point(n=n, total=total, m=m)
                total += loop1(n)
                n = loop2(n)
            return total
        self.meta_interp(f, [50])
        self.check_enter_count_at_most(2)

    def test_wanted_unrolling_and_preinlining(self):
        mydriver = JitDriver(reds = ['n', 'm'], greens = [])

        @unroll_safe
        def loop2(n):
            # the jit looks here, due to the decorator
            for i in range(5):
                n += 1
            return n
        loop2._always_inline_ = True

        def g(n):
            return loop2(n)
        g._dont_inline_ = True

        def f(m):
            n = 0
            while n < m:
                mydriver.can_enter_jit(n=n, m=m)
                mydriver.jit_merge_point(n=n, m=m)
                n = g(n)
            return n
        self.meta_interp(f, [50], backendopt=True)
        self.check_enter_count_at_most(2)
        self.check_resops(call=0)

    def test_loop_header(self):
        # artificial test: we enter into the JIT only when can_enter_jit()
        # is seen, but we close a loop in the JIT much more quickly
        # because of loop_header().
        mydriver = JitDriver(reds = ['n', 'm'], greens = [])

        def f(m):
            n = 0
            while True:
                mydriver.jit_merge_point(n=n, m=m)
                if n > m:
                    m -= 1
                    if m < 0:
                        return n
                    n = 0
                    mydriver.can_enter_jit(n=n, m=m)
                else:
                    n += 1
                    mydriver.loop_header()
        assert f(15) == 1
        res = self.meta_interp(f, [15], backendopt=True)
        assert res == 1
        self.check_resops(int_add=2)   # I get 13 without the loop_header()

    def test_omit_can_enter_jit(self):
        # Simple test comparing the effects of always giving a can_enter_jit(),
        # or not giving any.  Mostly equivalent, except that if given, it is
        # ignored the first time, and so it ends up taking one extra loop to
        # start JITting.
        mydriver = JitDriver(greens=[], reds=['m'])
        #
        for i2 in range(10):
            def f2(m):
                while m > 0:
                    mydriver.jit_merge_point(m=m)
                    m -= 1
            self.meta_interp(f2, [i2])
            try:
                self.check_jitcell_token_count(1)
                break
            except AssertionError:
                print "f2: no loop generated for i2==%d" % i2
        else:
            raise     # re-raise the AssertionError: check_loop_count never 1
        #
        for i1 in range(10):
            def f1(m):
                while m > 0:
                    mydriver.can_enter_jit(m=m)
                    mydriver.jit_merge_point(m=m)
                    m -= 1
            self.meta_interp(f1, [i1])
            try:
                self.check_jitcell_token_count(1)
                break
            except AssertionError:
                print "f1: no loop generated for i1==%d" % i1
        else:
            raise     # re-raise the AssertionError: check_loop_count never 1
        #
        assert i1 - 1 == i2

    def test_no_loop_at_all(self):
        mydriver = JitDriver(greens=[], reds=['m'])
        def f2(m):
            mydriver.jit_merge_point(m=m)
            return m - 1
        def f1(m):
            while m > 0:
                m = f2(m)
        self.meta_interp(f1, [8])
        # it should generate one "loop" only, which ends in a FINISH
        # corresponding to the return from f2.
        self.check_trace_count(1)
        self.check_resops(jump=0)

    def test_simple_loop(self):
        mydriver = JitDriver(greens=[], reds=['m'])
        def f1(m):
            while m > 0:
                mydriver.jit_merge_point(m=m)
                m = m - 1
        self.meta_interp(f1, [8])
        self.check_trace_count(1)
        self.check_resops({'jump': 1, 'guard_true': 2, 'int_gt': 2,
                           'int_sub': 2})

    def test_void_red_variable(self):
        mydriver = JitDriver(greens=[], reds=['m'])
        def f1(m):
            a = None
            while m > 0:
                mydriver.jit_merge_point(m=m)
                m = m - 1
                if m == 10:
                    pass   # other case
        self.meta_interp(f1, [18])

    def test_bug_constant_int(self):
        py.test.skip("crashes because a is a constant")
        from rpython.rtyper.lltypesystem import lltype, rffi
        mydriver = JitDriver(greens=['a'], reds=['m'])
        def f1(m, a):
            while m > 0:
                mydriver.jit_merge_point(a=a, m=m)
                m = m - 1
        def entry(m):
            f1(m, 42)
        self.meta_interp(entry, [18])

    def test_bug_constant_instance(self):
        py.test.skip("crashes because a is a constant")
        from rpython.rtyper.lltypesystem import lltype, rffi
        mydriver = JitDriver(greens=['a'], reds=['m'])
        class A(object):
            pass
        a1 = A()
        def f1(m, a):
            while m > 0:
                mydriver.jit_merge_point(a=a, m=m)
                m = m - 1
        def entry(m):
            f1(m, a1)
        self.meta_interp(entry, [18])

    def test_bug_constant_rawptrs(self):
        py.test.skip("crashes because a is a constant")
        from rpython.rtyper.lltypesystem import lltype, rffi
        mydriver = JitDriver(greens=['a'], reds=['m'])
        def f1(m):
            a = lltype.nullptr(rffi.VOIDP.TO)
            while m > 0:
                mydriver.jit_merge_point(a=a, m=m)
                m = m - 1
        self.meta_interp(f1, [18])

    def test_bug_rawptrs(self):
        from rpython.rtyper.lltypesystem import lltype, rffi
        mydriver = JitDriver(greens=['a'], reds=['m'])
        def f1(m):
            a = lltype.malloc(rffi.VOIDP.TO, 5, flavor='raw')
            while m > 0:
                mydriver.jit_merge_point(a=a, m=m)
                m = m - 1
                if m == 10:
                    pass
            lltype.free(a, flavor='raw')
        self.meta_interp(f1, [18])


    def test_loop_automatic_reds(self):
        myjitdriver = JitDriver(greens = ['m'], reds = 'auto')
        def f(n, m):
            res = 0
            # try to have lots of red vars, so that if there is an error in
            # the ordering of reds, there are low chances that the test passes
            # by chance
            a = b = c = d = n
            while n > 0:
                myjitdriver.jit_merge_point(m=m)
                n -= 1
                a += 1 # dummy unused red
                b += 2 # dummy unused red
                c += 3 # dummy unused red
                d += 4 # dummy unused red
                res += m*2
            return res
        expected = f(21, 5)
        res = self.meta_interp(f, [21, 5])
        assert res == expected
        self.check_resops(int_sub=2, int_mul=0, int_add=10)

    def test_loop_automatic_reds_with_floats_and_refs(self):
        myjitdriver = JitDriver(greens = ['m'], reds = 'auto')
        class MyObj(object):
            def __init__(self, val):
                self.val = val
        def f(n, m):
            res = 0
            # try to have lots of red vars, so that if there is an error in
            # the ordering of reds, there are low chances that the test passes
            # by chance
            i1 = i2 = i3 = i4 = n
            f1 = f2 = f3 = f4 = float(n)
            r1 = r2 = r3 = r4 = MyObj(n)
            while n > 0:
                myjitdriver.jit_merge_point(m=m)
                n -= 1
                i1 += 1 # dummy unused red
                i2 += 2 # dummy unused red
                i3 += 3 # dummy unused red
                i4 += 4 # dummy unused red
                f1 += 1 # dummy unused red
                f2 += 2 # dummy unused red
                f3 += 3 # dummy unused red
                f4 += 4 # dummy unused red
                r1.val += 1 # dummy unused red
                r2.val += 2 # dummy unused red
                r3.val += 3 # dummy unused red
                r4.val += 4 # dummy unused red
                res += m*2
            return res
        expected = f(21, 5)
        res = self.meta_interp(f, [21, 5])
        assert res == expected
        self.check_resops(int_sub=2, int_mul=0, int_add=18, float_add=8)

    def test_loop_automatic_reds_livevars_before_jit_merge_point(self):
        myjitdriver = JitDriver(greens = ['m'], reds = 'auto')
        def f(n, m):
            res = 0
            while n > 0:
                n -= 1
                myjitdriver.jit_merge_point(m=m)
                res += m*2
            return res
        expected = f(21, 5)
        res = self.meta_interp(f, [21, 5])
        assert res == expected
        self.check_resops(int_sub=2, int_mul=0, int_add=2)

    def test_loop_automatic_reds_not_too_many_redvars(self):
        myjitdriver = JitDriver(greens = ['m'], reds = 'auto')
        def one():
            return 1
        def f(n, m):
            res = 0
            while n > 0:
                n -= one()
                myjitdriver.jit_merge_point(m=m)
                res += m*2
            return res
        expected = f(21, 5)
        res = self.meta_interp(f, [21, 5])
        assert res == expected
        oplabel = get_stats().loops[0].operations[0]
        assert len(oplabel.getarglist()) == 2     # 'n', 'res' in some order

    def test_inline_jit_merge_point(self):
        py.test.skip("fix the test if you want to re-enable this")
        # test that the machinery to inline jit_merge_points in callers
        # works. The final user does not need to mess manually with the
        # _inline_jit_merge_point_ attribute and similar, it is all nicely
        # handled by @JitDriver.inline() (see next tests)
        myjitdriver = JitDriver(greens = ['a'], reds = 'auto')

        def jit_merge_point(a, b):
            myjitdriver.jit_merge_point(a=a)

        def add(a, b):
            jit_merge_point(a, b)
            return a+b
        add._inline_jit_merge_point_ = jit_merge_point
        myjitdriver.inline_jit_merge_point = True

        def calc(n):
            res = 0
            while res < 1000:
                res = add(n, res)
            return res

        def f():
            return calc(1) + calc(3)

        res = self.meta_interp(f, [])
        assert res == 1000 + 1002
        self.check_resops(int_add=4)

    def test_jitdriver_inline(self):
        py.test.skip("fix the test if you want to re-enable this")
        myjitdriver = JitDriver(greens = [], reds = 'auto')
        class MyRange(object):
            def __init__(self, n):
                self.cur = 0
                self.n = n

            def __iter__(self):
                return self

            def jit_merge_point(self):
                myjitdriver.jit_merge_point()

            @myjitdriver.inline(jit_merge_point)
            def next(self):
                if self.cur == self.n:
                    raise StopIteration
                self.cur += 1
                return self.cur

        def f(n):
            res = 0
            for i in MyRange(n):
                res += i
            return res

        expected = f(21)
        res = self.meta_interp(f, [21])
        assert res == expected
        self.check_resops(int_eq=2, int_add=4)
        self.check_trace_count(1)

    def test_jitdriver_inline_twice(self):
        py.test.skip("fix the test if you want to re-enable this")
        myjitdriver = JitDriver(greens = [], reds = 'auto')

        def jit_merge_point(a, b):
            myjitdriver.jit_merge_point()

        @myjitdriver.inline(jit_merge_point)
        def add(a, b):
            return a+b

        def one(n):
            res = 0
            while res < 1000:
                res = add(n, res)
            return res

        def two(n):
            res = 0
            while res < 2000:
                res = add(n, res)
            return res

        def f(n):
            return one(n) + two(n)

        res = self.meta_interp(f, [1])
        assert res == 3000
        self.check_resops(int_add=4)
        self.check_trace_count(2)

    def test_jitdriver_inline_exception(self):
        py.test.skip("fix the test if you want to re-enable this")
        # this simulates what happens in a real case scenario: inside the next
        # we have a call which we cannot inline (e.g. space.next in the case
        # of W_InterpIterable), but we need to put it in a try/except block.
        # With the first "inline_in_portal" approach, this case crashed
        myjitdriver = JitDriver(greens = [], reds = 'auto')

        def inc(x, n):
            if x == n:
                raise OverflowError
            return x+1
        inc._dont_inline_ = True

        class MyRange(object):
            def __init__(self, n):
                self.cur = 0
                self.n = n

            def __iter__(self):
                return self

            def jit_merge_point(self):
                myjitdriver.jit_merge_point()

            @myjitdriver.inline(jit_merge_point)
            def next(self):
                try:
                    self.cur = inc(self.cur, self.n)
                except OverflowError:
                    raise StopIteration
                return self.cur

        def f(n):
            res = 0
            for i in MyRange(n):
                res += i
            return res

        expected = f(21)
        res = self.meta_interp(f, [21])
        assert res == expected
        self.check_resops(int_eq=2, int_add=4)
        self.check_trace_count(1)


    def test_callback_jit_merge_point(self):
        @jit_callback("testing")
        def callback(a, b):
            if a > b:
                return 1
            return -1

        def main():
            total = 0
            for i in range(10):
                total += callback(i, 2)
            return total

        res = self.meta_interp(main, [])
        assert res == 7 - 3
        self.check_trace_count(2)

    def test_jitdriver_single_jit_merge_point(self):
        jitdriver = JitDriver(greens=[], reds='auto')
        def g1(n):
            jitdriver.jit_merge_point()
            return n
        def g2():
            jitdriver.jit_merge_point()
        def f(n):
            if n:
                g1(n)
            else:
                g2()
        e = py.test.raises(AssertionError, self.meta_interp, f, [42])
        assert str(e.value) == ("there are multiple jit_merge_points "
                                "with the same jitdriver")

    def test_jit_off_returns_early(self):
        from rpython.jit.metainterp.counter import DeterministicJitCounter
        driver = JitDriver(greens = ['s'], reds = ['i'], name='jit')

        def loop(i, s):
            set_user_param(driver, "off")
            while i > s:
                driver.jit_merge_point(i=i, s=s)
                i -= 1

        def main(s):
            loop(30, s)

        fn = DeterministicJitCounter.lookup_chain
        DeterministicJitCounter.lookup_chain = None
        try:
            self.meta_interp(main, [5]) # must not crash
        finally:
            DeterministicJitCounter.lookup_chain = fn


class TestWarmspotDirect(object):
    def setup_class(cls):
        from rpython.jit.codewriter.support import annotate
        from rpython.jit.metainterp.warmspot import WarmRunnerDesc
        from rpython.rtyper.rclass import OBJECT, OBJECT_VTABLE
        from rpython.rtyper.lltypesystem import lltype, llmemory
        exc_vtable = lltype.malloc(OBJECT_VTABLE, immortal=True)
        cls.exc_vtable = exc_vtable

        class FakeFailDescr(object):
            def __init__(self, no):
                self.no = no
            def handle_fail(self, deadframe, metainterp_sd, jitdrivers_sd):
                no = self.no
                assert deadframe._no == no
                if no == 0:
                    raise jitexc.DoneWithThisFrameInt(3)
                if no == 1:
                    raise jitexc.ContinueRunningNormally(
                        [0], [], [], [1], [], [])
                if no == 3:
                    exc = lltype.malloc(OBJECT)
                    exc.typeptr = exc_vtable
                    raise jitexc.ExitFrameWithExceptionRef(
                        lltype.cast_opaque_ptr(llmemory.GCREF, exc))
                assert 0

        class FakeDeadFrame:
            def __init__(self, no):
                self._no = no

        class FakeDescr:
            pass

        class FakeCPU(object):
            supports_floats = False
            supports_longlong = False
            supports_singlefloats = False
            translate_support_code = False
            stats = "stats"

            class tracker:
                pass

            def setup_descrs(self):
                return []

            def get_latest_descr(self, deadframe):
                assert isinstance(deadframe, FakeDeadFrame)
                return self.get_fail_descr_from_number(deadframe._no)

            def get_fail_descr_number(self, d):
                return -1

            def __init__(self, *args, **kwds):
                pass

            def nodescr(self, *args, **kwds):
                return FakeDescr()
            fielddescrof = nodescr
            calldescrof  = nodescr
            sizeof       = nodescr

            def get_fail_descr_from_number(self, no):
                return FakeFailDescr(no)

            def make_execute_token(self, *ARGS):
                return "not callable"

        driver = JitDriver(reds = ['red'], greens = ['green'])

        def f(green):
            red = 0
            while red < 10:
                driver.can_enter_jit(red=red, green=green)
                driver.jit_merge_point(red=red, green=green)
                red += 1
            return red

        rtyper = annotate(f, [0])
        FakeCPU.rtyper = rtyper
        translator = rtyper.annotator.translator
        translator.config.translation.gc = 'hybrid'
        cls.desc = WarmRunnerDesc(translator, CPUClass=FakeCPU)
        cls.FakeDeadFrame = FakeDeadFrame

    def test_call_helper(self):
        from rpython.rtyper.llinterp import LLException

        [jd] = self.desc.jitdrivers_sd
        FakeDeadFrame = self.FakeDeadFrame
        assert jd._assembler_call_helper(FakeDeadFrame(0), 0) == 3
        assert jd._assembler_call_helper(FakeDeadFrame(1), 0) == 10
        try:
            jd._assembler_call_helper(FakeDeadFrame(3), 0)
        except LLException as lle:
            assert lle[0] == self.exc_vtable
        else:
            py.test.fail("DID NOT RAISE")
