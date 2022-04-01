import time
import platform
from rpython.rlib import rtimer
from rpython.rtyper.test.test_llinterp import interpret
from rpython.translator.c.test.test_genc import compile

class TestTimer(object):

    @staticmethod
    def timer():
        t1 = rtimer.read_timestamp()
        start = time.time()
        while time.time() - start < 0.1:
            # busy wait
            pass
        t2 = rtimer.read_timestamp()
        return t2 - t1

    def test_direct(self):
        diff = self.timer()
        # We're counting ticks, verify they look correct
        assert diff > 1000

    def test_annotation(self):
        diff = interpret(self.timer, [])
        assert diff > 1000

    def test_compile_c(self):
        function = compile(self.timer, [])
        diff = function()
        assert diff > 1000


class TestGetUnit(object):

    @staticmethod
    def get_unit():
        return rtimer.get_timestamp_unit()

    def test_direct(self):
        unit = self.get_unit()
        assert unit == rtimer.UNIT_NS

    def test_annotation(self):
        unit = interpret(self.get_unit, [])
        assert unit == rtimer.UNIT_NS

    def test_compile_c(self):
        function = compile(self.get_unit, [])
        unit = function()
        if platform.processor() in ('x86', 'x86_64'):
            assert unit == rtimer.UNIT_TSC
        else:
            assert unit in (rtimer.UNIT_TSC,
                            rtimer.UNIT_NS,
                            rtimer.UNIT_QUERY_PERFORMANCE_COUNTER)
