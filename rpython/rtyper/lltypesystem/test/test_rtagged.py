import sys
from rpython.rtyper.test.test_llinterp import interpret, get_interpreter
from rpython.rtyper.lltypesystem import lltype
from rpython.rlib.objectmodel import UnboxedValue
from rpython.translator.translator import graphof
from rpython.flowspace.model import summary
from rpython.translator.backendopt.all import backend_optimizations
from rpython.conftest import option


class A(object):
    __slots__ = ()
    def meth(self, x):
        raise NotImplementedError

class B(A):
    attrvalue = 66
    def __init__(self, normalint):
        self.normalint = normalint
    def meth(self, x):
        return self.normalint + x + 2

class C(A, UnboxedValue):
    __slots__ = 'smallint'
    def meth(self, x):
        return self.smallint + x + 3

class D(B):
    attrvalue = 68

# ____________________________________________________________

def test_instantiate():
    def fn1(n):
        return C(n)
    res = interpret(fn1, [42], taggedpointers=True)
    value = lltype.cast_ptr_to_int(res)
    assert value == 42 * 2 + 1    # for now

def test_attribute():
    def fn1(n):
        return C(n).smallint
    res = interpret(fn1, [42], taggedpointers=True)
    assert res == 42

def test_get_untagged_value():
    def fn1(n):
        return C(n).get_untagged_value()
    res = interpret(fn1, [42], taggedpointers=True)
    assert res == 42

def test_overflowerror():
    def makeint(n):
        try:
            return C(n)
        except OverflowError:   # 'n' out of range
            return B(n)

    def fn2(n):
        x = makeint(n)
        if isinstance(x, B):
            return 'B', x.normalint
        elif isinstance(x, C):
            return 'C', x.smallint
        else:
            return 'A', 0

    res = interpret(fn2, [-117], taggedpointers=True)
    assert res.item0 == 'C'
    assert res.item1 == -117

    res = interpret(fn2, [sys.maxint], taggedpointers=True)
    assert res.item0 == 'B'
    assert res.item1 == sys.maxint

def test_prebuilt():
    c = C(111)
    b = B(939393)

    def makeint(n):
        if n < 0:
            x = c
        elif n > 0:
            x = C(n)
        else:
            x = b
        return x

    def fn(n):
        x = makeint(n)
        if isinstance(x, B):
            return 'B', x.normalint
        elif isinstance(x, C):
            return 'C', x.smallint
        else:
            return 'A', 0

    res = interpret(fn, [12], taggedpointers=True)
    assert res.item0 == 'C'
    assert res.item1 == 12
    res = interpret(fn, [-1], taggedpointers=True)
    assert res.item0 == 'C'
    assert res.item1 == 111
    res = interpret(fn, [0], taggedpointers=True)
    assert res.item0 == 'B'
    assert res.item1 == 939393

def test_C_or_None():
    def g(x):
        if x is None:
            return sys.maxint
        else:
            return x.smallint
    def fn(n):
        if n < 0:
            x = None
        else:
            x = C(n)
        return g(x)

    res = interpret(fn, [-1], taggedpointers=True)
    assert res == sys.maxint
    res = interpret(fn, [56], taggedpointers=True)
    assert res == 56

def test_type():
    def fn(n):
        if n < 0:
            x = B(n)
        else:
            x = C(n)
        return type(x) is B, type(x) is C

    res = interpret(fn, [-212], taggedpointers=True)
    assert res.item0 and not res.item1
    res = interpret(fn, [9874], taggedpointers=True)
    assert res.item1 and not res.item0

def test_type_of_None():
    # use extra function to prevent flow graph cleverness
    def g(n):
        if n < 0:
            x = B(n)
        elif n == 0:
            x = None
        else:
            x = C(n)
        return x
    def fn(n):
        x= g(n)
        return type(x) is B, type(x) is C

    res = interpret(fn, [-212], taggedpointers=True)
    assert res.item0 and not res.item1
    res = interpret(fn, [9874], taggedpointers=True)
    assert res.item1 and not res.item0
    res = interpret(fn, [0], taggedpointers=True)
    assert not res.item1 and not res.item0

def test_str():
    def fn(n):
        if n > 0:
            x = B(n)
        else:
            x = C(n)
        return str(x)
    res = interpret(fn, [-832], taggedpointers=True)
    assert ''.join(res.chars) == '<unboxed -832>'
    res = interpret(fn, [1], taggedpointers=True)
    assert ''.join(res.chars).startswith('<B object')

def test_format():
    def fn(n):
        if n > 0:
            x = B(n)
        else:
            x = C(n)
        return '%r' % (x,)
    res = interpret(fn, [-832], taggedpointers=True)
    assert ''.join(res.chars) == '<unboxed -832>'
    res = interpret(fn, [1], taggedpointers=True)
    assert ''.join(res.chars).startswith('<B object')

def test_method():
    def fn(n):
        if n > 0:
            x = B(n)
        else:
            x = C(n)
        return x.meth(100)
    res = interpret(fn, [1000], taggedpointers=True)
    assert res == 1102
    res = interpret(fn, [-1000], taggedpointers=True)
    assert res == -897

def test_optimize_method():
    def fn(n):
        if n > 0:
            x = B(n)
        else:
            x = C(n)
        return x.meth(100)
    interp, graph = get_interpreter(fn, [-1000], taggedpointers=True)

    t = interp.typer.annotator.translator
    t.config.translation.backendopt.constfold = True
    backend_optimizations(t)
    if option.view:
        t.view()

    LLFrame = interp.frame_class
    class MyFrame(LLFrame):
        def op_indirect_call(self, f, *args):
            raise AssertionError("this call should be optimized away")
    interp.frame_class = MyFrame
    res = interp.eval_graph(graph, [-1000])
    assert res == -897

def test_untagged_subclasses():
    def g(x):
        return x.attrvalue   # should not produce a call to ll_unboxed_getclass
    def fn(n):
        y = C(12)
        if n > 0:
            x = B(5)
        else:
            x = D(5)
        return g(x)

    interp, graph = get_interpreter(fn, [-1000], taggedpointers=True)

    t = interp.typer.annotator.translator
    ggraph = graphof(t, g)
    assert summary(ggraph) == {'cast_pointer': 2, 'getfield': 2}

    res = interp.eval_graph(graph, [-1000])
    assert res == 68
    res = interp.eval_graph(graph, [3])
    assert res == 66


def test_disable_tagging():
    def fn(n):
        if n < 0:
            x = B(n)
        else:
            x = C(n)
        return type(x) is B, type(x) is C

    res = interpret(fn, [-212], taggedpointers=False)
    assert res.item0 and not res.item1
    res = interpret(fn, [9874], taggedpointers=False)
    assert res.item1 and not res.item0
