import py
from rpython.rlib.jit import JitDriver, set_param, Counters
from rpython.rlib.jit import unroll_safe, dont_look_inside, promote
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.metainterp.warmspot import get_stats
from rpython.jit.metainterp.jitprof import Profiler

class TraceLimitTests:
    def test_segmented_trace(self):
        def p(pc, code):
            return "%s %d %s" % (code, pc, code[pc])
        myjitdriver = JitDriver(greens=['pc', 'code'], reds=['n'],
                                get_printable_location=p,
                                is_recursive=True)

        def f(code, n):
            pc = 0
            while pc < len(code):

                myjitdriver.jit_merge_point(n=n, code=code, pc=pc)
                op = code[pc]
                if op == "-":
                    n -= 1
                elif op == "c":
                    f('--------------------', n)
                elif op == "l":
                    if n > 0:
                        myjitdriver.can_enter_jit(n=n, code=code, pc=0)
                        pc = 0
                        continue
                else:
                    assert 0
                pc += 1
            return n
        def g(m):
            set_param(None, 'inlining', True)
            set_param(None, 'trace_limit', 40)
            if m > 1000000:
                f('', 0)
            result = 0
            s = '-' * 50 + '-c-l-'
            for i in range(m):
                result += f(s, i+100)
        self.meta_interp(g, [10], backendopt=True, ProfilerClass=Profiler)
        stats = get_stats()
        self.check_resops(label=1, jump=1, omit_finish=False)
        assert stats.metainterp_sd.profiler.counters[
            Counters.ABORT_SEGMENTED_TRACE] == 4
        self.check_trace_count(7)
        self.check_jitcell_token_count(1)

    def test_virtualizable(self):
        # basically the same test as test_segmented_trace, but the value of n
        # is stored in a virtualizable
        myjitdriver = JitDriver(greens = [], reds = ['frame'],
                                virtualizables = ['frame'])

        class Frame(object):
            _virtualizable_ = ['n']

            def __init__(self, n):
                self.n = n

        def p(pc, code):
            return "%s %d %s" % (code, pc, code[pc])
        myjitdriver = JitDriver(greens=['pc', 'code'], reds=['frame'],
                                virtualizables=['frame'],
                                get_printable_location=p,
                                is_recursive=True)

        def f(code, n):
            frame = Frame(n)
            pc = 0
            while pc < len(code):
                myjitdriver.jit_merge_point(frame=frame, code=code, pc=pc)

                op = code[pc]
                if op == "-":
                    frame.n -= 1
                elif op == "c":
                    f('--------------------', frame.n)
                elif op == "l":
                    if frame.n > 0:
                        myjitdriver.can_enter_jit(frame=frame, code=code, pc=0)
                        pc = 0
                        continue
                else:
                    assert 0
                pc += 1
            return frame.n
        def g(m):
            set_param(None, 'inlining', True)
            set_param(None, 'trace_limit', 40)
            if m > 1000000:
                f('', 0)
            result = 0
            s = '-' * 50 + '-c-l-'
            for i in range(m):
                result += f(s, i+100)
        self.meta_interp(g, [10], backendopt=True, ProfilerClass=Profiler)
        stats = get_stats()
        self.check_resops(label=1, jump=1, omit_finish=False)
        assert stats.metainterp_sd.profiler.counters[
            Counters.ABORT_SEGMENTED_TRACE] == 5
        self.check_trace_count(8)
        self.check_jitcell_token_count(1)


    def test_huge_bridge(self):
        def p(pc, code):
            return "%s %d %s" % (code, pc, code[pc])
        myjitdriver = JitDriver(greens=['pc', 'code'], reds=['n'],
                                get_printable_location=p,
                                is_recursive=True)

        @unroll_safe
        def longtrace(x, n):
            for i in range(x):
                n -= 1
            return n

        def f(code, n):
            pc = 0
            while pc < len(code):

                myjitdriver.jit_merge_point(n=n, code=code, pc=pc)
                op = code[pc]
                if op == "-":
                    n -= longtrace(3, n)
                elif op == "~":
                    if n > 10:
                        n -= 1
                    else:
                        code = "-" * 50
                        pc = 0
                        continue
                elif op == "l":
                    if n > 0:
                        myjitdriver.can_enter_jit(n=n, code=code, pc=0)
                        pc = 0
                        continue
                else:
                    assert 0
                pc += 1
            return n
        def g(m):
            set_param(None, 'inlining', True)
            set_param(None, 'trace_limit', 40)
            if m > 1000000:
                f('', 0)
            result = 0
            s = '~l-'
            for i in range(m):
                result += f(s, i+100)
        # idea of this test: we have a tiny loop that's just compiled
        # immediately. then at some point n <= 10 and we switch to "-" * 50.
        # That's a huge bridge. The first time we trace that, it doesn't work,
        # but then we set the flag on the loop "expect huge bridges", next time
        # we make a segmented trace
        self.meta_interp(g, [10], backendopt=True, ProfilerClass=Profiler)
        stats = get_stats()
        assert stats.metainterp_sd.profiler.counters[
            Counters.ABORT_SEGMENTED_TRACE] == 4

class TestLLtype(TraceLimitTests, LLJitMixin):
    pass
