import sys, os
from rpython.rlib.objectmodel import UnboxedValue


class A(object):
    __slots__ = ()
    def meth(self, x):
        raise NotImplementedError

class B(A):
    def __init__(self, normalint):
        self.normalint = normalint
    def meth(self, x):
        return self.normalint + x + 2

class C(A, UnboxedValue):
    __slots__ = 'smallint'
    def meth(self, x):
        return self.smallint + x + 3

def makeint(n):
    try:
        return C(n)
    except OverflowError:   # 'n' out of range
        return B(n)

def makeint2(n):
    if n < 0:
        x = prebuilt_c
    elif n > 0:
        x = C(n)
    else:
        x = prebuilt_b
    return x

prebuilt_c = C(111)
prebuilt_b = B(939393)

def entry_point(argv):
    n = 100 + len(argv)
    assert C(n).get_untagged_value() == n

    x = makeint(42)
    assert isinstance(x, C)
    assert x.smallint == 42

    x = makeint(sys.maxint)
    assert isinstance(x, B)
    assert x.normalint == sys.maxint

    x = makeint2(12)
    assert x.meth(1000) == 1015

    x = makeint2(-1)
    assert x.meth(1000) == 1114

    x = makeint2(0)
    assert x.meth(1000) == 940395

    os.write(1, "ALL OK\n")
    return 0

# ____________________________________________________________
# only with Boehm so far

from rpython.translator.interactive import Translation
from rpython.conftest import option

def test_tagged_boehm():
    t = Translation(entry_point, gc='boehm', taggedpointers=True)
    try:
        exename = str(t.compile_c())
    finally:
        if option.view:
            t.view()
    g = os.popen(exename, 'r')
    data = g.read()
    g.close()
    assert data.rstrip().endswith('ALL OK')

def test_name_gcref():
    from rpython.rtyper.lltypesystem import lltype, llmemory
    from rpython.rtyper import rclass
    from rpython.translator.c import primitive
    from rpython.translator.c.database import LowLevelDatabase
    x = lltype.cast_int_to_ptr(rclass.OBJECTPTR, 19)
    y = lltype.cast_opaque_ptr(llmemory.GCREF, x)
    db = LowLevelDatabase()
    assert primitive.name_gcref(y, db) == "((void*) 19)"
