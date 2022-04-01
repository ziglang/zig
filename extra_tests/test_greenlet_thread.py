import pytest
import sys, time
if sys.version_info < (3,):
    import thread
else:
    import _thread as thread
greenlet = pytest.importorskip('greenlet')


class TestThread:

    def test_cannot_switch_to_main_of_different_thread(self):
        mains = []
        mains.append(greenlet.getcurrent())
        lock = thread.allocate_lock()
        lock.acquire()
        got_exception = []
        #
        def run_thread():
            main = greenlet.getcurrent()
            assert main not in mains
            mains.append(main)
            try:
                mains[0].switch()
            except Exception as e:
                got_exception.append(e)
            lock.release()
        #
        thread.start_new_thread(run_thread, ())
        lock.acquire()
        assert isinstance(got_exception[0], greenlet.error)

    def test_nonstarted_greenlet_is_still_attached_to_thread(self):
        subs = []
        lock = thread.allocate_lock()
        lock.acquire()
        #
        def run_thread():
            g = greenlet.greenlet(lambda *args: None)
            subs.append(g)
            lock.release()
            time.sleep(1)
        #
        thread.start_new_thread(run_thread, ())
        lock.acquire()
        [g] = subs
        pytest.raises(greenlet.error, g.switch)

    def test_noninited_greenlet_is_still_attached_to_thread(self):
        subs = []
        lock = thread.allocate_lock()
        lock.acquire()
        #
        def run_thread():
            g = greenlet.greenlet.__new__(greenlet.greenlet)
            subs.append(g)
            lock.release()
            time.sleep(1)
        #
        thread.start_new_thread(run_thread, ())
        lock.acquire()
        [g] = subs
        pytest.raises(greenlet.error, g.switch)
        g.__init__(lambda *args: None)
        pytest.raises(greenlet.error, g.switch)

    def test_noninited_greenlet_change_thread_via_parent(self):
        subs = []
        lock = thread.allocate_lock()
        lock.acquire()
        #
        def run_thread():
            g = greenlet.greenlet.__new__(greenlet.greenlet)
            subs.append(g)
            lock.release()
            time.sleep(1)
        #
        thread.start_new_thread(run_thread, ())
        lock.acquire()
        [g] = subs
        g.__init__(lambda *args: 44)
        g.parent = greenlet.getcurrent()
        x = g.switch()
        assert x == 44

    def test_nonstarted_greenlet_change_thread_via_parent(self):
        subs = []
        lock = thread.allocate_lock()
        lock.acquire()
        #
        def run_thread():
            g = greenlet.greenlet(lambda *args: 42)
            subs.append(g)
            lock.release()
            time.sleep(1)
        #
        thread.start_new_thread(run_thread, ())
        lock.acquire()
        [g] = subs
        g.parent = greenlet.getcurrent()
        x = g.switch()
        assert x == 42

    def test_started_greenlet_cannot_change_thread_via_parent(self):
        pytest.skip("not implemented on PyPy")
        subs = []
        lock = thread.allocate_lock()
        lock.acquire()
        #
        def run_thread():
            g_parent = greenlet.getcurrent()
            g = greenlet.greenlet(lambda *args: g_parent.switch(42))
            x = g.switch()
            assert x == 42
            subs.append(g)
            lock.release()
            time.sleep(1)
        #
        thread.start_new_thread(run_thread, ())
        lock.acquire()
        [g] = subs
        with pytest.raises(ValueError) as e:
            g.parent = greenlet.getcurrent()
        assert str(e.value) == "parent cannot be on a different thread"

    def test_finished_greenlet_cannot_change_thread_via_parent(self):
        pytest.skip("not implemented on PyPy")
        subs = []
        lock = thread.allocate_lock()
        lock.acquire()
        #
        def run_thread():
            g = greenlet.greenlet(lambda *args: 42)
            x = g.switch()
            assert x == 42
            subs.append(g)
            lock.release()
            time.sleep(1)
        #
        thread.start_new_thread(run_thread, ())
        lock.acquire()
        [g] = subs
        with pytest.raises(ValueError) as e:
            g.parent = greenlet.getcurrent()
        assert str(e.value) == "parent cannot be on a different thread"
