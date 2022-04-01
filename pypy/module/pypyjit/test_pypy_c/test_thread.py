from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC


class TestThread(BaseTestPyPyC):
    def test_simple(self):
        def main(n):
            try:
                import _thread as thread
            except ImportError:
                import thread
            def f():
                i = 0
                while i < n:
                    i += 1
                done.release()

            done = thread.allocate_lock()
            done.acquire()
            thread.start_new_thread(f, ())
            done.acquire()
            return 0
        log = self.run(main, [500])
        assert round(log.result, 6) == round(main(500), 6)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i2 = int_lt(i0, i1)
            guard_true(i2, descr=...)
            i3 = int_add(i0, 1)
            --THREAD-TICK--
            jump(..., descr=...)
        """)

    def test_tls(self):
        def main(n):
            try:
                from _thread import _local
            except ImportError:
                from thread import _local
            local = _local()
            local.x = "abc" # prevent type unboxing
            local.x = 1
            i = 0
            while i < n:
                i += local.x
            return 0
        log = self.run(main, [500])
        assert round(log.result, 6) == round(main(500), 6)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
            i53 = int_lt(i48, i27)
            guard_true(i53, descr=...)
            i54 = int_add_ovf(i48, i47)
            guard_no_overflow(descr=...)
            --TICK--
            i58 = arraylen_gc(p43, descr=...)
            jump(..., descr=...)
        """)

    def test_lock_acquire_release(self):
        def main(n):
            import threading
            lock = threading.Lock()
            while n > 0:
                with lock:
                    n -= 1
        log = self.run(main, [500])
        assert log.result == main(500)
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
        i56 = int_gt(i44, 0)
        guard_true(i56, descr=...)
        p57 = force_token()
        setfield_gc(p0, p57, descr=<FieldP pypy.interpreter.pyframe.PyFrame.vable_token 8>)
        i58 = call_may_force_i(ConstClass(acquire_timed), p31, -1, descr=<Calli . ri EF=7>)
        guard_not_forced(descr=...)
        guard_no_exception(descr=...)
        i99 = int_eq(i58, 1)
        guard_true(i99, descr=...)
        i58 = int_sub(i44, 1)
        guard_not_invalidated?
        i59 = call_i(ConstClass(RPyThreadReleaseLock), i37, descr=<Calli . i EF=2>)
        i60 = int_is_true(i59)
        guard_false(i60, descr=...)
        --TICK--
        jump(..., descr=...)
        """)
