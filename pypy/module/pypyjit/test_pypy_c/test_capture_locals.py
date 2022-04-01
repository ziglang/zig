from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC


class TestCaptureLocals(BaseTestPyPyC):
    def test_capture_locals(self):
        def main(n):
            num = 42
            i = 0
            acc = 0
            src = '''
while i < n:
    acc += num
    i += 1
'''
            exec(src)
            return acc

        log = self.run(main, [500])
        print (log.result)
        assert log.result == 0
        loop, = log.loops_by_filename("<string>")
        print (loop)
        assert loop.match("""
            i41 = instance_ptr_eq(ConstPtr(ptr18), p16)
            guard_false(i41, descr=...)
            guard_not_invalidated(descr=...)
            i43 = int_lt(i35, 500)
            guard_true(i43, descr=...)
            i45 = getfield_gc_i(ConstPtr(ptr44), descr=...)
            i47 = int_add_ovf(i45, 42)
            guard_no_overflow(descr=...)
            setfield_gc(ConstPtr(ptr48), i47, descr=...)
            i50 = getfield_gc_i(ConstPtr(ptr49), descr=...)
            i52 = int_add_ovf(i50, 1)
            guard_no_overflow(descr=...)
            i54 = getfield_raw_i(..., descr=...)
            setfield_gc(ConstPtr(ptr55), i52, descr=...)
            i57 = int_lt(i54, 0)
            guard_false(i57, descr=...)
            jump(..., descr=...)
        """)
