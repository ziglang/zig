from __future__ import with_statement
import py
import sys, os
from pypy.module.thread.test.support import GenericTestThread
from rpython.translator.c.test.test_genc import compile
from platform import machine


class AppTestLock(GenericTestThread):

    def test_lock(self):
        import _thread
        lock = _thread.allocate_lock()
        assert type(lock) is _thread.LockType
        assert lock.locked() is False
        raises(RuntimeError, lock.release)
        assert lock.locked() is False
        r = lock.acquire()
        assert r is True
        r = lock.acquire(False)
        assert r is False
        assert lock.locked() is True
        lock.release()
        assert lock.locked() is False
        raises(RuntimeError, lock.release)
        assert lock.locked() is False
        feedback = []
        lock.acquire()
        def f():
            self.busywait(0.25)
            feedback.append(42)
            lock.release()
        assert lock.locked() is True
        _thread.start_new_thread(f, ())
        lock.acquire()
        assert lock.locked() is True
        assert feedback == [42]

    def test_lock_in_with(self):
        import _thread
        lock = _thread.allocate_lock()
        feedback = []
        lock.acquire()
        def f():
            self.busywait(0.25)
            feedback.append(42)
            lock.release()
        assert lock.locked() is True
        _thread.start_new_thread(f, ())
        with lock:
            assert lock.locked() is True
            assert feedback == [42]
        assert lock.locked() is False

    def test_weakrefable(self):
        import _thread, weakref
        weakref.ref(_thread.allocate_lock())

    def test_timeout(self):
        import _thread
        assert isinstance(_thread.TIMEOUT_MAX, float)
        assert _thread.TIMEOUT_MAX > 1000
        lock = _thread.allocate_lock()
        assert lock.acquire() is True
        assert lock.acquire(False) is False
        assert lock.acquire(True, timeout=.1) is False

    def test_timeout_overflow(self):
        import _thread
        lock = _thread.allocate_lock()
        maxint = 2**63 - 1
        for i in [-100000, -10000, -1000, -100, -10, -1, 0,
                  1, 10, 100, 1000, 10000, 100000]:
            timeout = (maxint + i) * 1e-6
            try:
                lock.acquire(True, timeout=timeout)
            except OverflowError:
                got_ovf = True
            else:
                got_ovf = False
                lock.release()
            assert (i, got_ovf) == (i, int(timeout * 1e6) > maxint)

    @py.test.mark.xfail(machine()=='s390x', reason='may fail under heavy load')
    def test_ping_pong(self):
        # The purpose of this test is that doing a large number of ping-pongs
        # between two threads, using locks, should complete in a reasonable
        # time on a translated pypy with -A.  If the GIL logic causes too
        # much sleeping, then it will fail.
        import _thread as thread, time
        COUNT = 100000 if self.runappdirect else 50
        lock1 = thread.allocate_lock()
        lock2 = thread.allocate_lock()
        def fn():
            for i in range(COUNT):
                lock1.acquire()
                lock2.release()
        lock2.acquire()
        print("STARTING")
        start = time.time()
        thread.start_new_thread(fn, ())
        for i in range(COUNT):
            lock2.acquire()
            lock1.release()
        stop = time.time()
        assert stop - start < 30.0    # ~0.6 sec on pypy-c-jit

    def test_at_fork_reinit(self):
        import _thread as thread
        def use_lock(lock):
            # make sure that the lock still works normally
            # after _at_fork_reinit()
            lock.acquire()
            lock.release()

        # unlocked
        for constr in [thread.allocate_lock, thread.RLock]:
            lock = constr()
            lock._at_fork_reinit()
            use_lock(lock)

            # locked: _at_fork_reinit() resets the lock to the unlocked state
            lock2 = constr()
            lock2.acquire()
            lock2._at_fork_reinit()
            use_lock(lock2)

def test_compile_lock():
    from rpython.rlib import rgc
    from rpython.rlib.rthread import allocate_lock
    def g():
        l = allocate_lock()
        ok1 = l.acquire(True)
        ok2 = l.acquire(False)
        l.release()
        ok3 = l.acquire(False)
        res = ok1 and not ok2 and ok3
        return res
    g._dont_inline_ = True
    def f():
        res = g()
        # the lock must have been freed by now - we use refcounting
        return res
    fn = compile(f, [], gcpolicy='ref')
    res = fn()
    assert res


class AppTestLockAgain(GenericTestThread):
    # test it at app-level again to detect strange interactions
    test_lock_again = AppTestLock.test_lock.im_func


class AppTestRLock(GenericTestThread):
    """
    Tests for recursive locks.
    """
    def test_reacquire(self):
        import _thread
        lock = _thread.RLock()
        lock.acquire()
        lock.acquire()
        lock.release()
        lock.acquire()
        lock.release()
        lock.release()

    def test_release_unacquired(self):
        # Cannot release an unacquired lock
        import _thread
        lock = _thread.RLock()
        raises(RuntimeError, lock.release)
        lock.acquire()
        lock.acquire()
        lock.release()
        lock.acquire()
        lock.release()
        lock.release()
        raises(RuntimeError, lock.release)

    def test_release_save(self):
        import _thread
        lock = _thread.RLock()
        raises(RuntimeError, lock._release_save)
        lock.acquire()
        state = lock._release_save()
        lock._acquire_restore(state)
        lock.release()

    def test__is_owned(self):
        import _thread
        lock = _thread.RLock()
        assert lock._is_owned() is False
        lock.acquire()
        assert lock._is_owned() is True
        lock.acquire()
        assert lock._is_owned() is True
        lock.release()
        assert lock._is_owned() is True
        lock.release()
        assert lock._is_owned() is False

    def test_context_manager(self):
        import _thread
        lock = _thread.RLock()
        with lock:
            assert lock._is_owned() is True

    def test_timeout(self):
        import _thread
        lock = _thread.RLock()
        assert lock.acquire() is True
        assert lock.acquire(False) is True
        assert lock.acquire(True, timeout=.1) is True


class AppTestLockSignals(GenericTestThread):
    pytestmark = py.test.mark.skipif("os.name != 'posix'")

    def w_acquire_retries_on_intr(self, lock):
        import _thread, os, signal, time
        self.sig_recvd = False
        def my_handler(signal, frame):
            self.sig_recvd = True
        old_handler = signal.signal(signal.SIGUSR1, my_handler)
        try:
            ready = _thread.allocate_lock()
            ready.acquire()
            def other_thread():
                # Acquire the lock in a non-main thread, so this test works for
                # RLocks.
                lock.acquire()
                # Notify the main thread that we're ready
                ready.release()
                # Wait for 5 seconds here
                for n in range(50):
                    time.sleep(0.1)
                # Send the signal
                os.kill(os.getpid(), signal.SIGUSR1)
                # Let the main thread take the interrupt, handle it, and retry
                # the lock acquisition.  Then we'll let it run.
                for n in range(50):
                    time.sleep(0.1)
                lock.release()
            _thread.start_new_thread(other_thread, ())
            ready.acquire()
            result = lock.acquire()  # Block while we receive a signal.
            assert self.sig_recvd
            assert result
        finally:
            signal.signal(signal.SIGUSR1, old_handler)
            for i in range(50):
                time.sleep(0.1)

    def test_lock_acquire_retries_on_intr(self):
        import _thread
        self.acquire_retries_on_intr(_thread.allocate_lock())

    def test_rlock_acquire_retries_on_intr(self):
        import _thread
        self.acquire_retries_on_intr(_thread.RLock())

    def w_alarm_interrupt(self, sig, frame):
        raise KeyboardInterrupt

    def test_lock_acquire_interruption(self):
        import _thread, signal, time
        # Mimic receiving a SIGINT (KeyboardInterrupt) with SIGALRM while stuck
        # in a deadlock.
        # XXX this test can fail when the legacy (non-semaphore) implementation
        # of locks is used in thread_pthread.h, see issue #11223.
        oldalrm = signal.signal(signal.SIGALRM, self.alarm_interrupt)
        try:
            lock = _thread.allocate_lock()
            lock.acquire()
            signal.alarm(1)
            t1 = time.time()
            # XXX: raises doesn't work here?
            #raises(KeyboardInterrupt, lock.acquire, timeout=5)
            try:
                lock.acquire(timeout=5)
            except KeyboardInterrupt:
                pass
            else:
                assert False, 'Expected KeyboardInterrupt'
            dt = time.time() - t1
            # Checking that KeyboardInterrupt was raised is not sufficient.
            # We want to assert that lock.acquire() was interrupted because
            # of the signal, not that the signal handler was called immediately
            # after timeout return of lock.acquire() (which can fool assertRaises).
            assert dt < 3.0
        finally:
            signal.signal(signal.SIGALRM, oldalrm)

    def test_rlock_acquire_interruption(self):
        import _thread, signal, time
        # Mimic receiving a SIGINT (KeyboardInterrupt) with SIGALRM while stuck
        # in a deadlock.
        # XXX this test can fail when the legacy (non-semaphore) implementation
        # of locks is used in thread_pthread.h, see issue #11223.
        oldalrm = signal.signal(signal.SIGALRM, self.alarm_interrupt)
        try:
            rlock = _thread.RLock()
            # For reentrant locks, the initial acquisition must be in another
            # thread.
            def other_thread():
                rlock.acquire()
            _thread.start_new_thread(other_thread, ())
            # Wait until we can't acquire it without blocking...
            while rlock.acquire(blocking=False):
                rlock.release()
                time.sleep(0.01)
            signal.alarm(1)
            t1 = time.time()
            #raises(KeyboardInterrupt, rlock.acquire, timeout=5)
            try:
                rlock.acquire(timeout=5)
            except KeyboardInterrupt:
                pass
            else:
                assert False, 'Expected KeyboardInterrupt'
            dt = time.time() - t1
            # See rationale above in test_lock_acquire_interruption
            assert dt < 3.0
        finally:
            signal.signal(signal.SIGALRM, oldalrm)


class AppTestLockRepr(GenericTestThread):

    def test_lock_repr(self):
        import _thread
        lock = _thread.allocate_lock()
        assert repr(lock).startswith("<unlocked _thread.lock object at ")
        lock.acquire()
        assert repr(lock).startswith("<locked _thread.lock object at ")

    def test_rlock_repr(self):
        import _thread
        rlock = _thread.RLock()
        assert repr(rlock).startswith(
            "<unlocked _thread.RLock object owner=0 count=0 at ")
        rlock.acquire()
        rlock.acquire()
        assert repr(rlock).startswith("<locked _thread.RLock object owner=")
        assert 'owner=0' not in repr(rlock)
        assert " count=2 at " in repr(rlock)
