import py
import pytest
try:
    import _continuation
except ImportError:
    py.test.skip("to run on top of a translated pypy-c")

py.test.skip("convert to an apptest")

import sys, random
from rpython.tool.udir import udir

# ____________________________________________________________

STATUS_MAX = 50000
CONTINULETS = 50

def set_fast_mode():
    global STATUS_MAX, CONTINULETS
    STATUS_MAX = 100
    CONTINULETS = 5

# ____________________________________________________________

class Done(Exception):
    pass


class Runner(object):

    def __init__(self):
        self.foobar = 12345
        self.conts = {}     # {continulet: parent-or-None}
        self.contlist = []

    def run_test(self):
        self.start_continulets()
        self.n = 0
        try:
            while True:
                self.do_switch(src=None)
                assert self.target is None
        except Done:
            self.check_traceback(sys.exc_info()[2])

    def do_switch(self, src):
        assert src not in self.conts.values()
        c = random.choice(self.contlist)
        self.target = self.conts[c]
        self.conts[c] = src
        c.switch()
        assert self.target is src

    def run_continulet(self, c, i):
        while True:
            assert self.target is c
            assert self.contlist[i] is c
            self.do_switch(c)
            assert self.foobar == 12345
            self.n += 1
            if self.n >= STATUS_MAX:
                raise Done

    def start_continulets(self, i=0):
        c = _continuation.continulet(self.run_continulet, i)
        self.contlist.append(c)
        if i < CONTINULETS:
            self.start_continulets(i + 1)
            # ^^^ start each continulet with a different base stack
        self.conts[c] = c   # initially (i.e. not started) there are all loops

    def check_traceback(self, tb):
        found = []
        tb = tb.tb_next
        while tb:
            if tb.tb_frame.f_code.co_name != 'do_switch':
                assert tb.tb_frame.f_code.co_name == 'run_continulet', (
                    "got %r" % (tb.tb_frame.f_code.co_name,))
                found.append(tb.tb_frame.f_locals['c'])
            tb = tb.tb_next
        found.reverse()
        #
        expected = []
        c = self.target
        while c is not None:
            expected.append(c)
            c = self.conts[c]
        #
        assert found == expected, "%r == %r" % (found, expected)

# ____________________________________________________________

class AppTestWrapper:
    def setup_class(cls):
        "Run test_various_depths() when we are run with 'pypy py.test -A'."
        from pypy.conftest import option
        if not option.runappdirect:
            py.test.skip("meant only for -A run")
        cls.w_vmprof_file = cls.space.wrap(str(udir.join('profile.vmprof')))

    def test_vmprof(self):
        """
        The point of this test is to check that we do NOT segfault.  In
        particular, we need to ensure that vmprof does not sample the stack in
        the middle of a switch, else we read nonsense.
        """
        _vmprof = pytest.importorskip('_vmprof')
        def switch_forever(c):
            while True:
                c.switch()
        #
        f = open(self.vmprof_file, 'w+b')
        _vmprof.enable(f.fileno(), 1/250.0, False, False, False, False)
        c = _continuation.continulet(switch_forever)
        for i in range(10**7):
            if i % 100000 == 0:
                print i
            c.switch()
        _vmprof.disable()
        f.close()

    def test_thread_switch_to_sub(self):
        try:
            import thread, time
        except ImportError:
            py.test.skip("no threads")
        c_list = []
        lock = thread.allocate_lock()
        lock.acquire()
        lock2 = thread.allocate_lock()
        lock2.acquire()
        #
        def fn():
            c = _continuation.continulet(lambda c_main: c_main.switch())
            c.switch()
            c_list.append(c)
            lock.release()
            lock2.acquire()
        #
        thread.start_new_thread(fn, ())
        lock.acquire()
        [c] = c_list
        py.test.raises(_continuation.error, c.switch)
        #
        lock2.release()
        time.sleep(0.5)
        py.test.raises(_continuation.error, c.switch)

    def test_thread_switch_to_sub_nonstarted(self):
        try:
            import thread, time
        except ImportError:
            py.test.skip("no threads")
        c_list = []
        lock = thread.allocate_lock()
        lock.acquire()
        lock2 = thread.allocate_lock()
        lock2.acquire()
        #
        def fn():
            c = _continuation.continulet(lambda c_main: None)
            c_list.append(c)
            lock.release()
            lock2.acquire()
        #
        thread.start_new_thread(fn, ())
        lock.acquire()
        [c] = c_list
        py.test.raises(_continuation.error, c.switch)
        #
        lock2.release()
        time.sleep(0.5)
        py.test.raises(_continuation.error, c.switch)

    def test_thread_switch_to_main(self):
        try:
            import thread, time
        except ImportError:
            py.test.skip("no threads")
        c_list = []
        lock = thread.allocate_lock()
        lock.acquire()
        lock2 = thread.allocate_lock()
        lock2.acquire()
        #
        def fn():
            def in_continulet(c_main):
                c_list.append(c_main)
                lock.release()
                lock2.acquire()
            c = _continuation.continulet(in_continulet)
            c.switch()
        #
        thread.start_new_thread(fn, ())
        lock.acquire()
        [c] = c_list
        py.test.raises(_continuation.error, c.switch)
        #
        lock2.release()
        time.sleep(0.5)
        py.test.raises(_continuation.error, c.switch)

def _setup():
    for _i in range(20):
        def test_single_threaded(self):
            Runner().run_test()
        test_single_threaded.func_name = 'test_single_threaded_%d' % _i
        setattr(AppTestWrapper, test_single_threaded.func_name,
                test_single_threaded)
    for _i in range(5):
        def test_multi_threaded(self):
            multithreaded_test()
        test_multi_threaded.func_name = 'test_multi_threaded_%d' % _i
        setattr(AppTestWrapper, test_multi_threaded.func_name,
                test_multi_threaded)
_setup()

class ThreadTest(object):
    def __init__(self, lock):
        self.lock = lock
        self.ok = False
        lock.acquire()
    def run(self):
        try:
            Runner().run_test()
            self.ok = True
        finally:
            self.lock.release()

def multithreaded_test():
    try:
        import thread
    except ImportError:
        py.test.skip("no threads")
    ts = [ThreadTest(thread.allocate_lock()) for i in range(5)]
    for t in ts:
        thread.start_new_thread(t.run, ())
    for t in ts:
        t.lock.acquire()
    for t in ts:
        assert t.ok

# ____________________________________________________________

if __name__ == '__main__':
    Runner().run_test()
