
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import rtime

import time, sys, py

class TestTime(BaseRtypingTest):
    def test_time_time(self):
        def fn():
            return time.time()

        t0 = time.time()
        res0 = self.interpret(fn, [])
        t1 = time.time()
        res1 = self.interpret(fn, [])
        assert t0 <= res0 <= t1 <= res1

    def test_time_clock(self):
        def sleep(t):
            # a version of time.sleep() that consumes actual CPU time
            start = time.clock()
            while abs(time.clock() - start) <= t:
                pass
        def f():
            return time.clock()
        t0 = time.clock()
        sleep(0.011)
        t1 = self.interpret(f, [])
        sleep(0.011)
        t2 = time.clock()
        sleep(0.011)
        t3 = self.interpret(f, [])
        sleep(0.011)
        t4 = time.clock()
        sleep(0.011)
        t5 = self.interpret(f, [])
        sleep(0.011)
        t6 = time.clock()
        # time.clock() and t1() might have a different notion of zero, so
        # we can only subtract two numbers returned by the same function.
        # Moreover they might have different precisions, but it should
        # be at least 0.01 seconds, hence the "sleeps".
        assert 0.0099 <= t2-t0 <= 9.0
        assert 0.0099 <= t3-t1 <= t4-t0 <= 9.0
        assert 0.0099 <= t4-t2 <= t5-t1 <= t6-t0 <= 9.0
        assert 0.0099 <= t5-t3 <= t6-t2 <= 9.0
        assert 0.0099 <= t6-t4 <= 9.0

    def test_time_sleep(self):
        def does_nothing():
            time.sleep(0.19)
        t0 = time.time()
        self.interpret(does_nothing, [])
        t1 = time.time()
        assert t0 <= t1
        assert t1 - t0 >= 0.15

    def test_clock_gettime(self):
        if not rtime.HAS_CLOCK_GETTIME:
            py.test.skip("no clock_gettime()")
        lst = []
        for i in range(50):
            with lltype.scoped_alloc(rtime.TIMESPEC) as a1:
                res = rtime.c_clock_gettime(rtime.CLOCK_MONOTONIC, a1)
                assert res == 0
                t = (float(rffi.getintfield(a1, 'c_tv_sec')) +
                     float(rffi.getintfield(a1, 'c_tv_nsec')) * 0.000000001)
                lst.append(t)
        assert lst == sorted(lst)

    def test_clock_getres(self):
        if not rtime.HAS_CLOCK_GETTIME:
            py.test.skip("no clock_gettime()")
        lst = []
        with lltype.scoped_alloc(rtime.TIMESPEC) as a1:
            res = rtime.c_clock_getres(rtime.CLOCK_MONOTONIC, a1)
            assert res == 0
            t = (float(rffi.getintfield(a1, 'c_tv_sec')) +
                 float(rffi.getintfield(a1, 'c_tv_nsec')) * 0.000000001)
        assert 0.0 < t <= 1.0
