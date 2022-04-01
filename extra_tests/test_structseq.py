import sys
from _structseq import structseqtype, structseqfield

class foo(metaclass=structseqtype):
    f1 = structseqfield(0, "a")
    f2 = structseqfield(1, "b")
    f3 = structseqfield(2, "c")

def test_structseqtype():
    t = foo((1, 2, 3))
    assert t.f1 == 1
    assert t.f2 == 2
    assert t.f3 == 3
    assert isinstance(t, tuple)

def test_trace_get():
    l = []
    def trace(frame, event, *args):
        l.append((frame, event, *args))
        return trace

    t = foo((1, 2, 3))
    sys.settrace(trace)
    assert t.f1 == 1
    sys.settrace(None)
    assert l == []
