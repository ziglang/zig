import py

from pypy.interpreter.gateway import interp2app
from rpython.rlib import debug


class AppTestDebug:
    spaceconfig = dict(usemodules=['__pypy__'])

    def setup_class(cls):
        if cls.runappdirect:
            py.test.skip("not meant to be run with -A")
        cls.w_check_log = cls.space.wrap(interp2app(cls.check_log))

    def setup_method(self, meth):
        debug._log = debug.DebugLog()

    def teardown_method(self, meth):
        debug._log = None

    @staticmethod
    def check_log(space, w_expected):
        assert list(debug._log) == space.unwrap(w_expected)

    def test_debug_print(self):
        from __pypy__ import debug_start, debug_stop, debug_print
        debug_start('my-category')
        debug_print('one')
        debug_print('two', 3, [])
        debug_stop('my-category')
        self.check_log([
                ('my-category', [
                        ('debug_print', 'one'),
                        ('debug_print', 'two 3 []'),
                        ])
                ])

    def test_debug_print_once(self):
        from __pypy__ import debug_print_once
        debug_print_once('foobar', 'hello world')
        self.check_log([
                ('foobar', [
                        ('debug_print', 'hello world'),
                        ])
                ])

    def test_debug_flush(self):
        from __pypy__ import debug_flush
        debug_flush()
        # assert did not crash

    def test_debug_read_timestamp(self):
        from __pypy__ import debug_read_timestamp
        a = debug_read_timestamp()
        b = debug_read_timestamp()
        assert b > a

    def test_debug_get_timestamp_unit(self):
        from __pypy__ import debug_get_timestamp_unit
        unit = debug_get_timestamp_unit()
        assert unit in ('tsc', 'ns', 'QueryPerformanceCounter')

    def test_debug_start_stop_timestamp(self):
        import time
        from __pypy__ import debug_start, debug_stop, debug_read_timestamp
        assert debug_start('foo') is None
        assert debug_stop('foo') is None
        ts1 = debug_start('foo', timestamp=True)
        t = time.clock()
        while time.clock() - t < 0.02:
            pass
        ts2 = debug_stop('foo', timestamp=True)
        assert ts2 > ts1
