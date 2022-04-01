class AppTestCProfile(object):
    spaceconfig = {
        "usemodules": ['_lsprof', 'time'],
    }

    def setup_class(cls):
        cls.w_file = cls.space.wrap(__file__)

    def test_repr(self):
        import _lsprof
        assert repr(_lsprof.Profiler) == "<class '_lsprof.Profiler'>"

    def test_builtins(self):
        import _lsprof
        prof = _lsprof.Profiler()
        lst = []
        prof.enable()
        lst.append(len(lst))
        prof.disable()
        stats = prof.getstats()
        expected = (
            "<built-in function len>",
            "<method 'append' of 'list' objects>",
            "<method 'disable' of '_lsprof.Profiler' objects>",
        )
        for entry in stats:
            assert entry.code in expected

    def test_builtins_callers(self):
        import _lsprof
        prof = _lsprof.Profiler(subcalls=True)
        lst = []
        def f1():
            lst.append(len(lst))
        prof.enable(subcalls=True)
        f1()
        prof.disable()
        stats = prof.getstats()
        expected = (
            "<built-in function len>",
            "<method 'append' of 'list' objects>",
        )
        by_id = set()
        for entry in stats:
            if entry.code == f1.__code__:
                assert len(entry.calls) == 2
                for subentry in entry.calls:
                    assert subentry.code in expected
                    by_id.add(id(subentry.code))
            elif entry.code in expected:
                by_id.add(id(entry.code))
        #  :-(  cProfile.py relies on the id() of the strings...
        assert len(by_id) == len(expected)

    def test_direct(self):
        import _lsprof
        def getticks():
            return len(ticks)
        prof = _lsprof.Profiler(getticks, 0.25, True, False)
        ticks = []
        def bar(m):
            ticks.append(1)
            if m == 1:
                foo(42)
            ticks.append(1)
        def spam(m):
            bar(m)
        def foo(n):
            bar(n)
            ticks.append(1)
            bar(n+1)
            ticks.append(1)
            spam(n+2)
        prof.enable()
        foo(0)
        prof.disable()
        assert len(ticks) == 16
        stats = prof.getstats()
        entries = {}
        for entry in stats:
            assert hasattr(entry.code, 'co_name')
            entries[entry.code.co_name] = entry
        efoo = entries['foo']
        assert efoo.callcount == 2
        assert efoo.reccallcount == 1
        assert efoo.inlinetime == 1.0
        assert efoo.totaltime == 4.0
        assert len(efoo.calls) == 2
        ebar = entries['bar']
        assert ebar.callcount == 6
        assert ebar.reccallcount == 3
        assert ebar.inlinetime == 3.0
        assert ebar.totaltime == 3.5
        assert len(ebar.calls) == 1
        espam = entries['spam']
        assert espam.callcount == 2
        assert espam.reccallcount == 0
        assert espam.inlinetime == 0.0
        assert espam.totaltime == 1.0
        assert len(espam.calls) == 1

        foo2spam, foo2bar = efoo.calls
        if foo2bar.code.co_name == 'spam':
            foo2bar, foo2spam = foo2spam, foo2bar
        assert foo2bar.code.co_name == 'bar'
        assert foo2bar.callcount == 4
        assert foo2bar.reccallcount == 2
        assert foo2bar.inlinetime == 2.0
        assert foo2bar.totaltime == 3.0
        assert foo2spam.code.co_name == 'spam'
        assert foo2spam.callcount == 2
        assert foo2spam.reccallcount == 0
        assert foo2spam.inlinetime == 0.0
        assert foo2spam.totaltime == 1.0

        bar2foo, = ebar.calls
        assert bar2foo.code.co_name == 'foo'
        assert bar2foo.callcount == 1
        assert bar2foo.reccallcount == 0
        assert bar2foo.inlinetime == 0.5
        assert bar2foo.totaltime == 2.0

        spam2bar, = espam.calls
        assert spam2bar.code.co_name == 'bar'
        assert spam2bar.callcount == 2
        assert spam2bar.reccallcount == 0
        assert spam2bar.inlinetime == 1.0
        assert spam2bar.totaltime == 1.0

    def test_scale_of_result(self):
        import _lsprof, time
        prof = _lsprof.Profiler()
        def foo(n):
            t = time.time()
            while abs(t - time.time()) < 1.0:
                pass      # busy-wait for 1 second
        def bar(n):
            foo(n)
        prof.enable()
        bar(0)
        prof.disable()
        stats = prof.getstats()
        entries = {}
        for entry in stats:
            entries[entry.code] = entry
        efoo = entries[foo.__code__]
        ebar = entries[bar.__code__]
        assert 0.9 < efoo.totaltime < 2.9
        # --- cannot test .inlinetime, because it does not include
        # --- the time spent doing the call to time.time()
        #assert 0.9 < efoo.inlinetime < 2.9
        for subentry in ebar.calls:
            assert 0.9 < subentry.totaltime < 2.9
            #assert 0.9 < subentry.inlinetime < 2.9

    def test_builtin_exception(self):
        import math
        import _lsprof

        prof = _lsprof.Profiler()
        prof.enable()
        try:
            math.sqrt("a")
        except TypeError:
            pass
        prof.disable()
        stats = prof.getstats()
        assert len(stats) == 2
