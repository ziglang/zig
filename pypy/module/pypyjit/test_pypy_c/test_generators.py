from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC


class TestGenerators(BaseTestPyPyC):
    def test_simple_generator1(self):
        def main(n):
            def f():
                for i in range(10000):
                    i -= 1
                    i -= 42    # ID: subtract
                    yield i

            def g():
                for i in f():  # ID: generator
                    pass

            g()

        log = self.run(main, [500])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id("generator", """
            cond_call(..., descr=...)
            i16 = force_token()
            setfield_gc(p14, 1, descr=<FieldU pypy.interpreter.generator.GeneratorOrCoroutine.inst_running .*>)
            setfield_gc(p22, p35, descr=<FieldP pypy.interpreter.pyframe.PyFrame.inst_f_backref .*>)
            guard_not_invalidated(descr=...)

            p45 = new_with_vtable(descr=<.*>)
            ifoo = arraylen_gc(p8, descr=<ArrayP .*>)
            setfield_gc(p45, i29, descr=<FieldS .*>)
            setarrayitem_gc(p8, 0, p45, descr=<ArrayP .>)
            jump(..., descr=...)
            """)
        assert loop.match_by_id("subtract", """
            setfield_gc(p20, ..., descr=<FieldS pypy.interpreter.pyframe.PyFrame.inst_last_instr .*>)
            i2 = int_sub_ovf(i1, 42)
            guard_no_overflow(descr=...)
            """)

    def test_simple_generator2(self):
        def main(n):
            def f():
                for i in range(1, 10000):
                    i -= 1
                    i -= 42    # ID: subtract
                    yield i

            def g():
                for i in f():  # ID: generator
                    pass

            g()

        log = self.run(main, [500])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match_by_id("generator", """
            cond_call(..., descr=...)
            i16 = force_token()
            setfield_gc(p14, 1, descr=<FieldU pypy.interpreter.generator.GeneratorOrCoroutine.inst_running .*>)
            setfield_gc(p22, p35, descr=<FieldP pypy.interpreter.pyframe.PyFrame.inst_f_backref .*>)
            guard_not_invalidated(descr=...)
            p45 = new_with_vtable(descr=<.*>)
            i47 = arraylen_gc(p8, descr=<ArrayP .>) # Should be removed by backend
            setfield_gc(p45, i29, descr=<FieldS .*>)
            setarrayitem_gc(p8, 0, p45, descr=<ArrayP .>)
            jump(..., descr=...)
            """)
        assert loop.match_by_id("subtract", """
            setfield_gc(..., descr=<.*last_instr .*>)     # XXX bad, kill me
            i2 = int_sub_ovf(i1, 42)
            guard_no_overflow(descr=...)
            """)

    def test_nonstd_jitdriver_distinguishes_generators(self):
        def main():
            # test the "contains" jitdriver, but the others are the same
            res = (9999 in (i for i in range(20000)))
            res += (9999 in (i for i in range(20000)))
            return res
        log = self.run(main, [])
        assert len(log.loops) >= 2  # as opposed to one loop, one bridge

