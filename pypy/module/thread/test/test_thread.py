import thread, time
from pypy.module.thread.test.support import GenericTestThread
import pytest

class AppTestThread(GenericTestThread):


    def test_thread_error(self):
        import _thread
        assert _thread.error is RuntimeError   # uh, since CPython 3.3

    def test_start_new_thread(self):
        import _thread
        feedback = []
        please_start = []
        def f(x, y, z):
            self.waitfor(lambda: please_start)
            feedback.append(42)
        _thread.start_new_thread(f, (1, 2), {'z': 3})
        assert feedback == []   # still empty
        please_start.append(1)  # trigger
        self.waitfor(lambda: feedback)
        assert feedback == [42]

    def test_thread_count(self):
        import _thread, time
        feedback = []
        please_start = []
        def f():
            feedback.append(42)
            self.waitfor(lambda: please_start)
        assert _thread._count() == 0
        _thread.start_new_thread(f, ())
        self.waitfor(lambda: feedback)
        assert _thread._count() == 1
        please_start.append(1)  # trigger
        # XXX joining a thread seems difficult at applevel.

    def test_start_new_thread_args(self):
        import _thread
        def f():
            pass
        test_args = [
            (f, [], {}),
            (f, (), []),
            ("", (), {}),
        ]
        for args in test_args:
            try:
                _thread.start_new_thread(*args)
                assert False
            except TypeError:
                pass

    def test_get_ident(self):
        import _thread
        ident = _thread.get_ident()
        feedback = []
        def f():
            feedback.append(_thread.get_ident())
        ident2 = _thread.start_new_thread(f, ())
        assert ident2 != ident
        assert ident == _thread.get_ident()
        self.waitfor(lambda: feedback)
        assert feedback == [ident2]

    def test_sys_getframe(self):
        # this checks that each thread gets its own ExecutionContext.
        def main():
            import _thread, sys
            def dump_frames(feedback):
                f = sys._getframe()
                for i in range(3):
                    if f is None:
                        feedback.append(None)
                    else:
                        feedback.append(f.f_code.co_name)
                        self.busywait(0.04)
                        assert f is sys._getframe(i)
                        f = f.f_back
            def dummyfn(feedback):
                dump_frames(feedback)
            feedback = []
            dummyfn(feedback)
            assert feedback == ['dump_frames', 'dummyfn', 'main']
            feedbacks = []
            for i in range(3):
                feedback = []
                _thread.start_new_thread(dummyfn, (feedback,))
                feedbacks.append(feedback)
            expected = 3*[['dump_frames', 'dummyfn', None]]   # without 'main'
            self.waitfor(lambda: feedbacks == expected)
            assert feedbacks == expected
        main()

    def test_thread_exit(self):
        import _thread, sys, io
        # preemptively import trackback to speed up the call to fn3,
        # which relies on the space.appexec in error.py:write_unraisable
        import traceback
        def fn1():
            _thread.exit()
        def fn2():
            raise SystemExit
        def fn3():
            raise ValueError("hello world")
        prev = sys.stderr
        try:
            sys.stderr = io.StringIO()
            _thread.start_new_thread(fn1, ())
            _thread.start_new_thread(fn2, ())
            self.busywait(0.2)   # time for the threads to finish
            assert sys.stderr.getvalue() == ''

            sys.stderr = io.StringIO()
            _thread.start_new_thread(fn3, ())
            self.waitfor(lambda: "ValueError" in sys.stderr.getvalue())
            result = sys.stderr.getvalue().splitlines()
            #assert result[0].startswith("Unhandled exception in thread ")
            assert result[1].startswith("Traceback ")
            assert result[-1] == "ValueError: hello world"
        finally:
            sys.stderr = prev

    def test_perthread_excinfo(self):
        import _thread, sys
        done = []
        def fn1(n):
            success = False
            try:
                caught = False
                try:
                    try:
                        {}[n]
                    except KeyError:
                        self.busywait(0.05)
                        caught = True
                        raise
                except KeyError:
                    self.busywait(0.05)
                    assert caught
                    etype, evalue, etb = sys.exc_info()
                    assert etype is KeyError
                    assert evalue.args[0] == n
                    success = True
            finally:
                done.append(success)
        for i in range(20):
            _thread.start_new_thread(fn1, (i,))
        self.waitfor(lambda: len(done) == 20)
        assert done == 20*[True]  # see stderr for failures in the threads

    def test_no_corruption(self):
        import _thread
        lst = []
        done_marker = []
        def f(x, done):
            for j in range(40):
                lst.insert(0, x+j)  # all threads trying to modify the same list
            done.append(True)
        for i in range(0, 120, 40):
            done = []
            _thread.start_new_thread(f, (i, done))
            done_marker.append(done)
        for done in done_marker:
            self.waitfor(lambda: done, delay=3)
            assert done    # see stderr for failures in threads
        assert sorted(lst) == list(range(120))

    def test_stack_size(self):
        import _thread
        _thread.stack_size(0)
        res = _thread.stack_size(0)
        assert res == 0
        res = _thread.stack_size(1024*1024)
        assert res == 0
        res = _thread.stack_size(2*1024*1024)
        assert res == 1024*1024
        res = _thread.stack_size(0)
        assert res == 2*1024*1024

    def test_interrupt_main(self):
        import _thread, time
        import signal

        def f():
            for x in range(40):
                if waiting:
                    _thread.interrupt_main()
                    return
                time.sleep(0.1)

        def busy_wait():
            waiting.append(None)
            for x in range(50):
                time.sleep(0.1)
            waiting.pop()

        # This is normally called by app_main.py
        signal.signal(signal.SIGINT, signal.default_int_handler)

        for i in range(100):
            print()
            print("loop", i)
            waiting = []
            _thread.start_new_thread(f, ())
            raises(KeyboardInterrupt, busy_wait)

@pytest.mark.skip("too slow")
class _AppTestThread(GenericTestThread):
    '''
    This test is very slow, do not run it by default.
    '''
    def setup_class(cls):
        GenericTestThread.setup_class.im_func(cls)
        # if we cannot start more than, say, 1000 threads on this OS, then
        # we can check that we get the proper error at app-level
        space = cls.space
        lock = thread.allocate_lock()
        lock.acquire()
        def f():
            lock.acquire()
            lock.release()
        start = thread._count()
        try:
            try:
                for i in range(1000):
                    thread.start_new_thread(f, ())
            finally:
                lock.release()
        except (thread.error, MemoryError):
            cls.w_can_start_many_threads = space.wrap(False)
        else:
            cls.w_can_start_many_threads = space.wrap(True)
        # wait a bit to allow all threads to finish now
        remaining = thread._count()
        retries = 0
        while remaining > start:
            retries += 1
            if retries == 200:
                raise Exception("the test's threads don't stop!")
            time.sleep(0.2)
            remaining = thread._count()

    def test_many_threads(self):
        import time, sys
        if sys.version_info[0] < 3:
            import thread as _thread
        else:
            import _thread
        if self.can_start_many_threads or sys.platform == 'win32':
            skip("this OS supports too many threads to check (> 1000)")
        lock = _thread.allocate_lock()
        lock.acquire()
        count = [0]
        def f():
            count[0] += 1
            lock.acquire()
            lock.release()
            count[0] -= 1
        try:
            try:
                for i in range(1000):
                    _thread.start_new_thread(f, ())
            finally:
                lock.release()
                # wait a bit to allow most threads to finish now
                while count[0] > 10:
                    print(count[0])     # <- releases the GIL
                print("ok.")
        except (_thread.error, MemoryError):
            pass
        else:
            raise Exception("could unexpectedly start 1000 threads")
        # safety: check that we can start a new thread here
        _thread.start_new_thread(lambda: None, ())


