
import py
from rpython.jit.metainterp.warmspot import ll_meta_interp
from rpython.rlib.jit import JitDriver, dont_look_inside, elidable, Counters
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.metainterp import pyjitpl
from rpython.jit.metainterp.jitprof import Profiler

class FakeProfiler(Profiler):
    def start(self):
        self.counter = 123456
        Profiler.start(self)
        self.events = []
        self.times = [0, 0]
    
    def timer(self):
        self.counter += 1
        return self.counter - 1

    def _start(self, event):
        Profiler._start(self, event)
        self.events.append(event)

    def _end(self, event):
        Profiler._end(self, event)
        self.events.append(~event)

class ProfilerMixin(LLJitMixin):
    def meta_interp(self, *args, **kwds):
        kwds = kwds.copy()
        kwds['ProfilerClass'] = FakeProfiler
        return LLJitMixin.meta_interp(self, *args, **kwds)

class TestProfile(ProfilerMixin):

    def test_simple_loop(self):
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'res'])
        def f(x, y):
            res = 0
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, res=res)
                myjitdriver.jit_merge_point(x=x, y=y, res=res)
                res += x
                y -= 1
            return res * 2
        res = self.meta_interp(f, [6, 7])
        assert res == 84
        profiler = pyjitpl._warmrunnerdesc.metainterp_sd.profiler
        expected = [
            Counters.TRACING,
            Counters.BACKEND,
            ~ Counters.BACKEND,
            ~ Counters.TRACING,
            ]
        assert profiler.events == expected
        assert profiler.times == [2, 1]
        py.test.skip("disabled until unrolling")
        assert profiler.counters == [1, 1, 3, 3, 2, 15, 2, 0, 0, 0, 0,
                                     0, 0, 0, 0, 0, 0, 0]

    def test_simple_loop_with_call(self):
        @dont_look_inside
        def g(n):
            pass
        
        myjitdriver = JitDriver(greens = [], reds = ['x', 'y', 'res'])
        def f(x, y):
            res = 0
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, res=res)
                myjitdriver.jit_merge_point(x=x, y=y, res=res)
                res += x
                g(x)
                y -= 1
            return res * 2
        res = self.meta_interp(f, [6, 7])
        assert res == 84
        profiler = pyjitpl._warmrunnerdesc.metainterp_sd.profiler
        assert profiler.calls == 1

    def test_blackhole_pure(self):
        @elidable
        def g(n):
            return n+1
        
        myjitdriver = JitDriver(greens = ['z'], reds = ['y', 'x','res'])
        def f(x, y, z):
            res = 0
            while y > 0:
                myjitdriver.can_enter_jit(x=x, y=y, res=res, z=z)
                myjitdriver.jit_merge_point(x=x, y=y, res=res, z=z)
                res += x
                res += g(z)
                y -= 1
            return res * 2
        res = self.meta_interp(f, [6, 7, 2])
        assert res == f(6, 7, 2)
        profiler = pyjitpl._warmrunnerdesc.metainterp_sd.profiler
        assert profiler.calls == 1

    def test_heapcache_stats(self):
        class A:
            pass
        class B(A):
            pass
        @dont_look_inside
        def extern(n):
            if n == -7:
                return None
            elif n:
                return A()
            else:
                return B()
        myjitdriver = JitDriver(greens = [], reds='auto')
        def f(x, y):
            res = 0
            while y > 0:
                myjitdriver.jit_merge_point()
                obj = extern(y)
                res += x + isinstance(obj, B) + isinstance(obj, B) + isinstance(obj, B) + isinstance(obj, B)
                res += x
                y -= 1
            return res * 2
        res = self.meta_interp(f, [6, 7])
        assert res == f(6, 7)
        profiler = pyjitpl._warmrunnerdesc.metainterp_sd.profiler
        assert profiler.counters[Counters.HEAPCACHED_OPS] == 3

