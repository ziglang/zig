
import py
from rpython.rlib.jit import JitDriver, JitHookInterface, Counters, dont_look_inside
from rpython.rlib import jit_hooks
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.codewriter.policy import JitPolicy
from rpython.jit.metainterp.resoperation import rop
from rpython.rtyper.annlowlevel import hlstr, cast_instance_to_gcref
from rpython.jit.metainterp.jitprof import Profiler, EmptyProfiler
from rpython.jit.codewriter.policy import JitPolicy


class JitHookInterfaceTests(object):
    # !!!note!!! - don't subclass this from the backend. Subclass the LL
    # class later instead

    def test_abort_quasi_immut(self):
        reasons = []

        class MyJitIface(JitHookInterface):
            def on_abort(self, reason, jitdriver, greenkey, greenkey_repr, logops, ops):
                assert jitdriver is myjitdriver
                assert len(greenkey) == 1
                reasons.append(reason)
                assert greenkey_repr == 'blah'
                assert len(ops) > 1

        iface = MyJitIface()

        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'],
                                get_printable_location=lambda *args: 'blah')

        class Foo:
            _immutable_fields_ = ['a?']

            def __init__(self, a):
                self.a = a

        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                # read a quasi-immutable field out of a Constant
                total += foo.a
                foo.a += 1
                x -= 1
            return total
        #
        assert f(100, 7) == 721
        res = self.meta_interp(f, [100, 7], policy=JitPolicy(iface))
        assert res == 721
        assert reasons == [Counters.ABORT_FORCE_QUASIIMMUT] * 2

    def test_on_compile(self):
        called = []

        class MyJitIface(JitHookInterface):
            def after_compile(self, di):
                called.append(("compile", di.greenkey[1].getint(),
                               di.greenkey[0].getint(), di.type))

            def before_compile(self, di):
                called.append(("optimize", di.greenkey[1].getint(),
                               di.greenkey[0].getint(), di.type))

            #def before_optimize(self, jitdriver, logger, looptoken, oeprations,
            #                   type, greenkey):
            #    called.append(("trace", greenkey[1].getint(),
            #                   greenkey[0].getint(), type))

        iface = MyJitIface()

        driver = JitDriver(greens = ['n', 'm'], reds = ['i'])

        def loop(n, m):
            i = 0
            while i < n + m:
                driver.can_enter_jit(n=n, m=m, i=i)
                driver.jit_merge_point(n=n, m=m, i=i)
                i += 1

        self.meta_interp(loop, [1, 4], policy=JitPolicy(iface))
        assert called == [#("trace", 4, 1, "loop"),
                          ("optimize", 4, 1, "loop"),
                          ("compile", 4, 1, "loop")]
        self.meta_interp(loop, [2, 4], policy=JitPolicy(iface))
        assert called == [#("trace", 4, 1, "loop"),
                          ("optimize", 4, 1, "loop"),
                          ("compile", 4, 1, "loop"),
                          #("trace", 4, 2, "loop"),
                          ("optimize", 4, 2, "loop"),
                          ("compile", 4, 2, "loop")]

    def test_on_compile_bridge(self):
        called = []

        class MyJitIface(JitHookInterface):
            def after_compile(self, di):
                called.append("compile")

            def after_compile_bridge(self, di):
                called.append("compile_bridge")

            def before_compile_bridge(self, di):
                called.append("before_compile_bridge")

        driver = JitDriver(greens = ['n', 'm'], reds = ['i'])

        def loop(n, m):
            i = 0
            while i < n + m:
                driver.can_enter_jit(n=n, m=m, i=i)
                driver.jit_merge_point(n=n, m=m, i=i)
                if i >= 4:
                    i += 2
                i += 1

        self.meta_interp(loop, [1, 10], policy=JitPolicy(MyJitIface()))
        assert called == ["compile", "before_compile_bridge", "compile_bridge"]

    def test_get_stats(self):
        driver = JitDriver(greens = [], reds = ['i', 's'])

        def loop(i):
            s = 0
            while i > 0:
                driver.jit_merge_point(i=i, s=s)
                if i % 2:
                    s += 1
                i -= 1
                s+= 2
            return s

        def main():
            loop(30)
            assert jit_hooks.stats_get_counter_value(None,
                                           Counters.TOTAL_COMPILED_LOOPS) == 1
            assert jit_hooks.stats_get_counter_value(None,
                                           Counters.TOTAL_COMPILED_BRIDGES) == 1
            assert jit_hooks.stats_get_counter_value(None,
                                                     Counters.TRACING) == 2
            assert jit_hooks.stats_get_times_value(None, Counters.TRACING) >= 0

        self.meta_interp(main, [], ProfilerClass=Profiler)

    def test_get_stats_empty(self):
        driver = JitDriver(greens = [], reds = ['i'])
        def loop(i):
            while i > 0:
                driver.jit_merge_point(i=i)
                i -= 1
        def main():
            loop(30)
            assert jit_hooks.stats_get_counter_value(None,
                                           Counters.TOTAL_COMPILED_LOOPS) == 0
            assert jit_hooks.stats_get_times_value(None, Counters.TRACING) == 0
        self.meta_interp(main, [], ProfilerClass=EmptyProfiler)

    def test_get_jitcell_at_key(self):
        driver = JitDriver(greens = ['s'], reds = ['i'], name='jit')

        def loop(i, s):
            while i > s:
                driver.jit_merge_point(i=i, s=s)
                i -= 1

        def main(s):
            loop(30, s)
            assert jit_hooks.get_jitcell_at_key("jit", s)
            assert not jit_hooks.get_jitcell_at_key("jit", s + 1)
            jit_hooks.trace_next_iteration("jit", s + 1)
            loop(s + 3, s + 1)
            assert jit_hooks.get_jitcell_at_key("jit", s + 1)

        self.meta_interp(main, [5])
        self.check_jitcell_token_count(2)

    def test_get_jitcell_at_key_ptr(self):
        driver = JitDriver(greens = ['s'], reds = ['i'], name='jit')

        class Green(object):
            pass

        def loop(i, s):
            while i > 0:
                driver.jit_merge_point(i=i, s=s)
                i -= 1

        def main(s):
            g1 = Green()
            g2 = Green()
            g1_ptr = cast_instance_to_gcref(g1)
            g2_ptr = cast_instance_to_gcref(g2)
            loop(10, g1)
            assert jit_hooks.get_jitcell_at_key("jit", g1_ptr)
            assert not jit_hooks.get_jitcell_at_key("jit", g2_ptr)
            jit_hooks.trace_next_iteration("jit", g2_ptr)
            loop(2, g2)
            assert jit_hooks.get_jitcell_at_key("jit", g2_ptr)

        self.meta_interp(main, [5])
        self.check_jitcell_token_count(2)

    def test_dont_trace_here(self):
        driver = JitDriver(greens = ['s'], reds = ['i', 'k'], name='jit')

        def loop(i, s):
            k = 4
            while i > 0:
                driver.jit_merge_point(k=k, i=i, s=s)
                if s == 1:
                    loop(3, 0)
                k -= 1
                i -= 1
                if k == 0:
                    k = 4
                    driver.can_enter_jit(k=k, i=i, s=s)

        def main(s, check):
            if check:
                jit_hooks.dont_trace_here("jit", 0)
            loop(30, s)

        self.meta_interp(main, [1, 0], inline=True)
        self.check_resops(call_assembler_n=0)
        self.meta_interp(main, [1, 1], inline=True)
        self.check_resops(call_assembler_n=8)

    def test_trace_next_iteration_hash(self):
        driver = JitDriver(greens = ['s'], reds = ['i'], name="name")
        class Hashes(object):
            check = False

            def __init__(self):
                self.l = []
                self.t = []

        hashes = Hashes()

        class Hooks(JitHookInterface):
            def before_compile(self, debug_info):
                pass

            def after_compile(self, debug_info):
                for op in debug_info.operations:
                    if op.is_guard():
                        hashes.l.append(op.getdescr().get_jitcounter_hash())

            def before_compile_bridge(self, debug_info):
                pass

            def after_compile_bridge(self, debug_info):
                hashes.t.append(debug_info.fail_descr.get_jitcounter_hash())

        hooks = Hooks()

        @dont_look_inside
        def foo():
            if hashes.l:
                for item in hashes.l:
                    jit_hooks.trace_next_iteration_hash("name", item)

        def loop(i, s):
            while i > 0:
                driver.jit_merge_point(s=s, i=i)
                foo()
                if i == 3:
                    i -= 1
                i -= 1

        def main(s, check):
            hashes.check = check
            loop(10, s)

        self.meta_interp(main, [1, 0], policy=JitPolicy(hooks))
        assert len(hashes.l) == 4
        assert len(hashes.t) == 0
        self.meta_interp(main, [1, 1], policy=JitPolicy(hooks))
        assert len(hashes.t) == 1


    def test_are_hooks_enabled(self):
        reasons = []

        class MyJitIface(JitHookInterface):
            def are_hooks_enabled(self):
                return False

            def on_abort(self, reason, jitdriver, greenkey, greenkey_repr, logops, ops):
                reasons.append(reason)

        iface = MyJitIface()

        myjitdriver = JitDriver(greens=['foo'], reds=['x', 'total'],
                                get_printable_location=lambda *args: 'blah')

        class Foo:
            _immutable_fields_ = ['a?']

            def __init__(self, a):
                self.a = a

        def f(a, x):
            foo = Foo(a)
            total = 0
            while x > 0:
                myjitdriver.jit_merge_point(foo=foo, x=x, total=total)
                total += foo.a
                foo.a += 1
                x -= 1
            return total
        #
        assert f(100, 7) == 721
        res = self.meta_interp(f, [100, 7], policy=JitPolicy(iface))
        assert res == 721
        assert reasons == []

    def test_memmgr_release_all(self):
        driver = JitDriver(greens = [], reds = ['i'])
        def loop(i):
            while i > 0:
                driver.jit_merge_point(i=i)
                i -= 1
        def num_loops():
            return jit_hooks.stats_get_counter_value(None,
                                           Counters.TOTAL_COMPILED_LOOPS)
        def main():
            loop(30)
            if num_loops() != 1:
                return 1000 + num_loops()
            loop(30)
            if num_loops() != 1:
                return 1500 + num_loops()
            #
            jit_hooks.stats_memmgr_release_all(None)
            from rpython.rlib import rgc
            rgc.collect(); rgc.collect(); rgc.collect()
            #
            loop(30)
            if num_loops() != 2:
                return 2000 + num_loops()
            loop(30)
            if num_loops() != 2:
                return 2500 + num_loops()
            return 42

        res = self.meta_interp(main, [], ProfilerClass=Profiler,
                               no_stats_history=True)
        assert res == 42


class LLJitHookInterfaceTests(JitHookInterfaceTests):
    # use this for any backend, instead of the super class

    def test_ll_get_stats(self):
        driver = JitDriver(greens = [], reds = ['i', 's'])

        def loop(i):
            s = 0
            while i > 0:
                driver.jit_merge_point(i=i, s=s)
                if i % 2:
                    s += 1
                i -= 1
                s+= 2
            return s

        def main(b):
            jit_hooks.stats_set_debug(None, b)
            loop(30)
            l = jit_hooks.stats_get_loop_run_times(None)
            if b:
                assert len(l) == 4
                # completely specific test that would fail each time
                # we change anything major. for now it's 4
                # (loop, bridge, 2 entry points)
                assert l[0].type == 'e'
                assert l[0].number == 0
                assert l[0].counter == 4
                assert l[1].type == 'l'
                assert l[1].counter == 4
                assert l[2].type == 'l'
                assert l[2].counter == 23
                assert l[3].type == 'b'
                assert l[3].number == 4
                assert l[3].counter == 11
            else:
                assert len(l) == 0
        self.meta_interp(main, [True], ProfilerClass=Profiler)
        # this so far does not work because of the way setup_once is done,
        # but fine, it's only about untranslated version anyway
        #self.meta_interp(main, [False], ProfilerClass=Profiler)

class TestJitHookInterface(JitHookInterfaceTests, LLJitMixin):
    pass
