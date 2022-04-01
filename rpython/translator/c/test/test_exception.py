import py
import sys
from rpython.translator.c.test import test_typed
from rpython.translator.c.test import test_backendoptimized
from rpython.rtyper.lltypesystem import lltype
from rpython.rlib.rarithmetic import ovfcheck

getcompiled = test_typed.TestTypedTestCase().getcompiled
getcompiledopt = test_backendoptimized.TestTypedOptimizedTestCase().getcompiled


class InTestException(Exception):
    pass

class MyException(Exception):
    pass

def test_simple1():
    def raise_(i):
        if i == 0:
            raise InTestException()
        elif i == 1:
            raise MyException()
        else:
            return 3
    def fn(i):
        try:
            a = raise_(i) + 11
            b = raise_(i) + 12
            c = raise_(i) + 13
            return a+b+c
        except InTestException:
            return 7
        except MyException:
            return 123
        except:
            return 22
        return 66
    f = getcompiled(fn, [int])
    assert f(0) == fn(0)
    assert f(1) == fn(1)
    assert f(2) == fn(2)

def test_implicit_index_error_lists():
    def fn(n):
        lst = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        try:
            return lst[n]
        except:
            return 2
    f = getcompiled(fn, [int])
    assert f(-1) == fn(-1)
    assert f( 0) == fn( 0)
    assert f(10) == fn(10)

def test_myexception():
    def g():
        raise MyException
    def f():
        try:
            g()
        except MyException:
            return 5
        else:
            return 2
    f1 = getcompiled(f, [])
    assert f1() == 5

def test_raise_outside_testfn():
    def testfn(n):
        if n < 0:
            raise ValueError("hello")
        elif n > 0:
            raise MyException("world")
        else:
            return 0
    f1 = getcompiled(testfn, [int])
    f1(-1, expected_exception_name='ValueError')
    f1(1, expected_exception_name='MyException')

def test_memoryerror():
    # in rev 30717 this test causes a segfault on some Linux, but usually
    # only after the test is run.  It is caused by the following sequence
    # of events in lltype.malloc(S, n): there is an OP_MAX_VARSIZE macro
    # which figures out that the size asked for is too large and would
    # cause a wrap-around, so it sets a MemoryError; but execution continues
    # nevertheless and the next line is an OP_MALLOC instruction, which
    # because of the wrap-around allocates for 's' an amount of bytes which
    # falls precisely between 0 and offsetof(s, tail).  It succeeds.  Then
    # the length field of s.tail is initialized - this overwrites random
    # memory!  And only then is the exception check performed, and the
    # MemoryError is noticed.
    A = lltype.Array(lltype.Signed)
    S = lltype.GcStruct('S', ('a', lltype.Signed),
                             ('b', lltype.Signed),
                             ('c', lltype.Signed),
                             ('tail', A))
    def g(n, tag):
        s = lltype.malloc(S, n)
        tag.a = 42
        return s
    def testfn(n):
        tag = lltype.malloc(S, 0)
        try:
            s = g(n, tag)
            result = s.tail[n//2]
        except MemoryError:
            result = 1000
        return result + tag.a
    f1 = getcompiled(testfn, [int])
    assert f1(10) == 42
    assert f1(sys.maxint) == 1000
    for i in range(20):
        assert f1(int((sys.maxint+1) // 2 - i)) == 1000
    assert f1(sys.maxint // 2 - 16384) == 1000
    assert f1(sys.maxint // 2 + 16384) == 1000

def test_assert():
    def testfn(n):
        assert n >= 0

    f1 = getcompiled(testfn, [int])
    res = f1(0)
    assert res is None, repr(res)
    res = f1(42)
    assert res is None, repr(res)
    f1(-2, expected_exception_name='AssertionError')


def test_reraise_exception():
    class A(Exception):
        pass

    def raise_something(n):
        if n > 10:
            raise A
        else:
            raise Exception

    def foo(n):
        try:
            raise_something(n)
        except A:
            raise     # go through
        except Exception as e:
            return 100
        return -1

    def fn(n):
        try:
            return foo(n)
        except A:
            return 42

    f1 = getcompiledopt(fn, [int])
    res = f1(100)
    assert res == 42
    res = f1(0)
    assert res == 100

def test_dict_keyerror_inside_try_finally():
    class CtxMgr:
        def __enter__(self):
            return 42
        def __exit__(self, *args):
            pass
    def fn(x):
        d = {5: x}
        with CtxMgr() as forty_two:
            try:
                return d[x]
            except KeyError:
                return forty_two
    f1 = getcompiledopt(fn, [int])
    res = f1(100)
    assert res == 42

def test_getitem_custom_exception():
    class MyError(Exception):
        pass
    class BadContainer(object):
        def __getitem__(self, n):
            raise MyError
    def f():
        d = BadContainer()
        try:
            return d[0]
        except KeyError:
            return 1
    def g():
        try:
            return f()
        except MyError:
            return -1

    assert g() == -1
    compiled = getcompiled(g, [])
    assert compiled() == -1

def test_ovf_propagation():
    def div(a, b):
        try:
            return ovfcheck(a//b)
        except ZeroDivisionError:
            raise
    def f():
        div(4, 2)
        try:
            return div(-sys.maxint-1, -1)
        except OverflowError:
            return 0
    assert f() == 0
    compiled = getcompiled(f, [])
    assert compiled() == 0
