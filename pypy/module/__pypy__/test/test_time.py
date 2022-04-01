import py

from pypy.module.__pypy__.interp_time import HAS_CLOCK_GETTIME


class AppTestTime(object):
    def setup_class(cls):
        if not HAS_CLOCK_GETTIME:
            py.test.skip("need time.clock_gettime")

    def test_clock_realtime(self):
        from __pypy__ import time
        res = time.clock_gettime(time.CLOCK_REALTIME)
        assert isinstance(res, float)

    def test_clock_monotonic(self):
        from __pypy__ import time
        a = time.clock_gettime(time.CLOCK_MONOTONIC)
        b = time.clock_gettime(time.CLOCK_MONOTONIC)
        assert a <= b

    def test_clock_getres(self):
        from __pypy__ import time
        res = time.clock_getres(time.CLOCK_REALTIME)
        assert res > 0.0
        assert res <= 1.0
