from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC


class TestThread(BaseTestPyPyC):
    def test_make_ref_with_callback(self):
        log = self.run("""
        import weakref

        class Dummy(object):
            pass

        def noop(obj):
            pass

        def main(n):
            obj = Dummy()
            for i in range(n):
                weakref.ref(obj, noop)
        """, [500])
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
        i58 = getfield_gc_i(p18, descr=<FieldS pypy.module.__builtin__.functional.W_IntRangeIterator.inst_current .>)
        i60 = int_lt(i58, i31)
        guard_true(i60, descr=...)
        i61 = int_add(i58, 1)
        dummy_get_utf8?
        setfield_gc(p18, i61, descr=<FieldS pypy.module.__builtin__.functional.W_IntRangeIterator.inst_current 8>)
        guard_not_invalidated(descr=...)
        dummy_get_utf8?
        dummy_get_utf8?
        p65 = getfield_gc_r(p14, descr=<FieldP .+inst_map \d+>)
        guard_value(p65, ConstPtr(ptr45), descr=...)
        p66 = getfield_gc_r(p14, descr=<FieldP .+inst__value0 \d+>)
        guard_nonnull(p66, descr=...)
        p67 = force_token()
        setfield_gc(p0, p67, descr=<FieldP pypy.interpreter.pyframe.PyFrame.vable_token \d+>)
        p68 = call_may_force_r(ConstClass(WeakrefLifeline.make_weakref_with_callback), p66, ConstPtr(ptr50), p14, ConstPtr(ptr51), descr=<Callr \d rrrr EF=7>)
        guard_not_forced(descr=...)
        guard_no_exception(descr=...)
        guard_nonnull_class(p68, ..., descr=...)
        guard_not_invalidated(descr=...)
        --TICK--
        jump(..., descr=...)
        """)
