import sys
import __pypy__

class TestHook:
    def __init__(self, raise_on_events=None, exc_type=RuntimeError):
        self.raise_on_events = raise_on_events or ()
        self.exc_type = exc_type
        self.seen = []
        self.closed = False

    def __enter__(self, *a):
        sys.addaudithook(self)
        return self

    def __exit__(self, *a):
        self.close()
        if hasattr(__pypy__, '_testing_clear_audithooks'):
            __pypy__._testing_clear_audithooks()

    def close(self):
        self.closed = True

    @property
    def seen_events(self):
        return [i[0] for i in self.seen]

    def __call__(self, event, args):
        if self.closed:
            return
        self.seen.append((event, args))
        if event in self.raise_on_events:
            raise self.exc_type("saw event " + event)


def test_simple_hook():
    with TestHook() as hook:
        sys.audit("test_event", 1, 2, 3)
        assert hook.seen[0][0] == "test_event"
        assert hook.seen[0][1] == (1, 2, 3)

def test_two_hooks():
    l = []
    def f(event, args):
        l.append((1, event, args))
    def g(event, args):
        l.append((2, event, args))
    sys.addaudithook(f)
    sys.addaudithook(g)
    try:
        sys.audit("test")
        assert l[-1] == (2, "test", ())
        assert l[-2] == (1, "test", ())
    finally:
        if hasattr(__pypy__, '_testing_clear_audithooks'):
            __pypy__._testing_clear_audithooks()

def test_block_add_hook():
    # Raising an exception should prevent a new hook from being added,
    # but will not propagate out.
    with TestHook(raise_on_events="sys.addaudithook") as hook1:
        with TestHook() as hook2:
            sys.audit("test_event")
            assert "test_event" in hook1.seen_events
            assert hook2.seen_events == []

def test_id_hook():
    with TestHook() as hook:
        x = id(hook)
        assert hook.seen[0] == ("builtins.id", (x, ))

def test_eval():
    def ret1():
        return 1

    with TestHook() as hook:
        res = eval(ret1.__code__)
        assert res == 1
    assert hook.seen == [("exec", (ret1.__code__, ))]

def test_exec():
    def ret1():
        return 1

    with TestHook() as hook:
        exec(ret1.__code__)
    assert hook.seen == [("exec", (ret1.__code__, ))]

def test_donttrace():
    trace_events = []
    audit_events = []
    def trace(frame, evt, *args):
        trace_events.append((evt, frame.f_code, frame.f_lineno))
        return trace
    def audit(evt, *args):
        audit_events.append(evt)
    sys.addaudithook(audit)
    sys.settrace(trace)
    try:
        sys.audit("Überraschung!")
    finally:
        sys.settrace(None)
        if hasattr(__pypy__, '_testing_clear_audithooks'):
            __pypy__._testing_clear_audithooks()
    print(trace_events)
    assert len(trace_events) == 0

def test_cantrace():
    trace_events = []
    audit_events = []
    def trace(frame, evt, *args):
        trace_events.append((evt, frame.f_code, frame.f_lineno))
        return trace
    def audit(evt, *args):
        audit_events.append(evt)
    audit.__cantrace__ = 132
    sys.addaudithook(audit)
    sys.settrace(trace)
    try:
        sys.audit("Überraschung!")
    finally:
        sys.settrace(None)
        if hasattr(__pypy__, '_testing_clear_audithooks'):
            __pypy__._testing_clear_audithooks()
    print(trace_events)
    assert len(trace_events) == 3 # call, line, return


