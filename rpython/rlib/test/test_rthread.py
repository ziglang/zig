import gc, time
from rpython.rlib.rthread import *
from rpython.rlib.rarithmetic import r_longlong
from rpython.rlib import objectmodel
from rpython.translator.c.test.test_boehm import AbstractGCTestClass
from rpython.rtyper.lltypesystem import lltype, rffi
import py
import platform

def test_lock():
    l = allocate_lock()
    ok1 = l.acquire(True)
    ok2 = l.acquire(False)
    l.release()
    ok3 = l.acquire(False)
    res = ok1 and not ok2 and ok3
    assert res == 1

def test_lock_is_aquired():
    l = allocate_lock()
    ok1 = l.acquire(True)
    assert l.is_acquired() == True
    assert l.is_acquired() == True
    l.release()
    assert l.is_acquired() == False

def test_thread_error():
    l = allocate_lock()
    try:
        l.release()
    except error:
        pass
    else:
        py.test.fail("Did not raise")

def test_tlref_untranslated():
    import thread
    class FooBar(object):
        pass
    t = ThreadLocalReference(FooBar)
    results = []
    def subthread():
        x = FooBar()
        results.append(t.get() is None)
        t.set(x)
        results.append(t.get() is x)
        time.sleep(0.2)
        results.append(t.get() is x)
    for i in range(5):
        thread.start_new_thread(subthread, ())
    time.sleep(0.5)
    assert results == [True] * 15

def test_get_ident():
    import thread
    assert get_ident() == thread.get_ident()


def test_threadlocalref_on_llinterp():
    from rpython.rtyper.test.test_llinterp import interpret
    tlfield = ThreadLocalField(lltype.Signed, "rthread_test_")
    #
    def f():
        x = tlfield.setraw(42)
        return tlfield.getraw()
    #
    res = interpret(f, [])
    assert res == 42


class AbstractThreadTests(AbstractGCTestClass):
    use_threads = True

    def test_start_new_thread(self):
        import time

        class State:
            pass
        state = State()

        def bootstrap1():
            state.my_thread_ident1 = get_ident()
        def bootstrap2():
            state.my_thread_ident2 = get_ident()

        def f():
            state.my_thread_ident1 = get_ident()
            state.my_thread_ident2 = get_ident()
            start_new_thread(bootstrap1, ())
            start_new_thread(bootstrap2, ())
            willing_to_wait_more = 1000
            while (state.my_thread_ident1 == get_ident() or
                   state.my_thread_ident2 == get_ident()):
                willing_to_wait_more -= 1
                if not willing_to_wait_more:
                    raise Exception("thread didn't start?")
                time.sleep(0.01)
            return 42

        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 42

    @py.test.mark.xfail(platform.machine() == 's390x',
                        reason='may fail this test under heavy load')
    def test_gc_locking(self):
        import time
        from rpython.rlib.debug import ll_assert

        class State:
            pass
        state = State()

        class Z:
            def __init__(self, i, j):
                self.i = i
                self.j = j
            def run(self):
                j = self.j
                if self.i > 1:
                    g(self.i-1, self.j * 2)
                    ll_assert(j == self.j, "1: bad j")
                    g(self.i-2, self.j * 2 + 1)
                else:
                    if len(state.answers) % 7 == 5:
                        gc.collect()
                    state.answers.append(self.j)
                ll_assert(j == self.j, "2: bad j")
            run._dont_inline_ = True

        def bootstrap():
            # after_extcall() is called before we arrive here.
            # We can't just acquire and release the GIL manually here,
            # because it is unsafe: bootstrap() is called from a rffi
            # callback which checks for and reports exceptions after
            # bootstrap() returns.  The exception checking code must be
            # protected by the GIL too.
            z = state.z
            state.z = None
            state.bootstrapping.release()
            z.run()
            gc_thread_die()
            # before_extcall() is called after we leave here

        def g(i, j):
            state.bootstrapping.acquire(True)
            state.z = Z(i, j)
            start_new_thread(bootstrap, ())

        def f():
            state.bootstrapping = allocate_lock()
            state.answers = []
            state.finished = 0

            g(10, 1)
            done = False
            willing_to_wait_more = 2000
            while not done:
                if not willing_to_wait_more:
                    break
                willing_to_wait_more -= 1
                done = len(state.answers) == expected

                print "waitting %d more iterations" % willing_to_wait_more
                time.sleep(0.01)

            time.sleep(0.1)

            return len(state.answers)

        expected = 89
        fn = self.getcompiled(f, [])
        answers = fn()
        assert answers == expected

    def test_acquire_timed(self):
        import time
        def f():
            l = allocate_lock()
            l.acquire(True)
            t1 = time.time()
            ok = l.acquire_timed(1000001)
            t2 = time.time()
            delay = t2 - t1
            if ok == 0:        # RPY_LOCK_FAILURE
                return -delay
            elif ok == 2:      # RPY_LOCK_INTR
                return delay
            else:              # RPY_LOCK_ACQUIRED
                return 0.0
        fn = self.getcompiled(f, [])
        res = fn()
        assert res < -1.0

    def test_acquire_timed_huge_timeout(self):
        t = r_longlong(2 ** 61)
        def f():
            l = allocate_lock()
            return l.acquire_timed(t)
        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 1       # RPY_LOCK_ACQUIRED

    def test_acquire_timed_alarm(self):
        import sys
        if not sys.platform.startswith('linux'):
            py.test.skip("skipped on non-linux")
        import time
        from rpython.rlib import rsignal
        def f():
            l = allocate_lock()
            l.acquire(True)
            #
            rsignal.pypysig_setflag(rsignal.SIGALRM)
            rsignal.c_alarm(1)
            #
            t1 = time.time()
            ok = l.acquire_timed(2500000)
            t2 = time.time()
            delay = t2 - t1
            if ok == 0:        # RPY_LOCK_FAILURE
                return -delay
            elif ok == 2:      # RPY_LOCK_INTR
                return delay
            else:              # RPY_LOCK_ACQUIRED
                return 0.0
        fn = self.getcompiled(f, [])
        res = fn()
        assert res >= 0.95

    def test_tlref(self):
        class FooBar(object):
            pass
        t = ThreadLocalReference(FooBar)
        def f():
            x1 = FooBar()
            t.set(x1)
            import gc; gc.collect()
            assert t.get() is x1
            return 42
        fn = self.getcompiled(f, [])
        res = fn()
        assert res == 42

#class TestRunDirectly(AbstractThreadTests):
#    def getcompiled(self, f, argtypes):
#        return f
# These are disabled because they crash occasionally for bad reasons
# related to the fact that ll2ctypes is not at all thread-safe

class TestUsingBoehm(AbstractThreadTests):
    gcpolicy = 'boehm'

class TestUsingFramework(AbstractThreadTests):
    gcpolicy = 'minimark'

    def test_tlref_keepalive(self, no__thread=True):
        import weakref
        from rpython.config.translationoption import SUPPORT__THREAD

        if not (SUPPORT__THREAD or no__thread):
            py.test.skip("no __thread support here")

        class FooBar(object):
            def __init__(self, a, b):
                self.lst = [a, b]
        t = ThreadLocalReference(FooBar)
        t2 = ThreadLocalReference(FooBar)

        def tset():
            x1 = FooBar(40, 2)
            t.set(x1)
            return weakref.ref(x1)
        tset._dont_inline_ = True

        def t2set():
            x1 = FooBar(50, 3)
            t2.set(x1)
            return weakref.ref(x1)
        t2set._dont_inline_ = True

        class WrFromThread:
            pass
        wr_from_thread = WrFromThread()

        def f():
            config = objectmodel.fetch_translated_config()
            assert t.automatic_keepalive(config) is True
            wr = tset()
            wr2 = t2set()
            import gc; gc.collect()   # the two 'x1' should not be collected
            x1 = t.get()
            assert x1 is not None
            assert wr() is not None
            assert wr() is x1
            assert x1.lst == [40, 2]
            x2 = t2.get()
            assert x2 is not None
            assert wr2() is not None
            assert wr2() is x2
            assert x2.lst == [50, 3]
            return wr, wr2

        def thread_entry_point():
            wr, wr2 = f()
            wr_from_thread.wr = wr
            wr_from_thread.wr2 = wr2
            wr_from_thread.seen = True

        def main():
            wr_from_thread.seen = False
            start_new_thread(thread_entry_point, ())
            wr1, wr2 = f()
            count = 0
            while True:
                time.sleep(0.5)
                if wr_from_thread.seen or count >= 50:
                    break
                count += 1
            assert wr_from_thread.seen is True
            wr_other_1 = wr_from_thread.wr
            wr_other_2 = wr_from_thread.wr2
            import gc; gc.collect()      # wr_other_*() should be collected here
            assert wr1() is not None     # this thread, still running
            assert wr2() is not None     # this thread, still running
            assert wr_other_1() is None  # other thread, not running any more
            assert wr_other_2() is None  # other thread, not running any more
            assert wr1().lst == [40, 2]
            assert wr2().lst == [50, 3]
            return 42

        extra_options = {'no__thread': no__thread, 'shared': True}
        fn = self.getcompiled(main, [], extra_options=extra_options)
        res = fn()
        assert res == 42

    def test_tlref_keepalive__thread(self):
        self.test_tlref_keepalive(no__thread=False)
