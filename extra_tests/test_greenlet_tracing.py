import pytest
greenlet = pytest.importorskip('greenlet')


class SomeError(Exception):
    pass

class TestTracing:
    def test_greenlet_tracing(self):
        main = greenlet.getcurrent()
        actions = []
        def trace(*args):
            actions.append(args)
        def dummy():
            pass
        def dummyexc():
            raise SomeError()
        oldtrace = greenlet.settrace(trace)
        try:
            g1 = greenlet.greenlet(dummy)
            g1.switch()
            g2 = greenlet.greenlet(dummyexc)
            pytest.raises(SomeError, g2.switch)
        finally:
            greenlet.settrace(oldtrace)
        assert actions == [
            ('switch', (main, g1)),
            ('switch', (g1, main)),
            ('switch', (main, g2)),
            ('throw', (g2, main)),
        ]

    def test_exception_disables_tracing(self):
        main = greenlet.getcurrent()
        actions = []
        def trace(*args):
            actions.append(args)
            raise SomeError()
        def dummy():
            main.switch()
        g = greenlet.greenlet(dummy)
        g.switch()
        oldtrace = greenlet.settrace(trace)
        try:
            pytest.raises(SomeError, g.switch)
            assert greenlet.gettrace() is None
        finally:
            greenlet.settrace(oldtrace)
        assert actions == [
            ('switch', (main, g)),
        ]
