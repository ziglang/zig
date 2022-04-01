import sys
import py
from rpython.rlib import rstackovf

def recurse(n):
    if n > 0:
        return recurse(n-1) + n
    return 0

def f(n):
    try:
        recurse(n)
    except rstackovf.StackOverflow:
        return 1
    else:
        return 0


def test_direct():
    assert f(sys.maxint) == 1

class RecurseGetAttr(object):

    def __getattr__(self, attr):
        return getattr(self, attr)

def test_raises_AttributeError():
    py.test.skip("not RPython code...")
    rga = RecurseGetAttr()
    try:
        rga.y
    except AttributeError:
        pass
    else:
        py.test.skip("interpreter is not badly behaved")
    py.test.raises(rstackovf.StackOverflow, getattr, rga, "y")

def test_llinterp():
    from rpython.rtyper.test.test_llinterp import interpret
    res = interpret(f, [sys.maxint])
    assert res == 1

def test_c_translation():
    from rpython.translator.c.test.test_genc import compile
    fn = compile(f, [int])
    res = fn(sys.maxint)
    assert res == 1
