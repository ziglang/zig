from _multiprocessing import SemLock
from threading import Thread
import _thread
import time
import sys
import pytest

@pytest.mark.skipif(sys.platform=='win32', reason='segfaults on win32')
def test_notify_all():
    """A low-level variation on test_notify_all() in lib-python's
    _test_multiprocessing.py
    """
    N_THREADS = 1000
    lock = SemLock(0, 1, 1, "/test_notify_all", True)
    results = []

    def f(n):
        if lock.acquire(timeout=5.):
            results.append(n)
            lock.release()
        else:
            print("lock acquire timed out!")

    threads = [Thread(target=f, args=(i,)) for i in range(N_THREADS)]
    n_started = N_THREADS
    with lock:
        for t in threads:
            try:
                t.start()
            except _thread.error:
                # too many threads for this system
                t.started = False
                n_started -= 1
            else:
                t.started = True
        time.sleep(0.1)
        print("started %d threads" % n_started)
    for t in threads:
        if t.started:
            t.join()
    assert len(results) == n_started
