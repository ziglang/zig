""" Test that the math module still behaves even when
    compiled to C with SSE2 enabled.
"""
import py, math
from rpython.translator.c.test.test_genc import compile
from rpython.jit.backend.x86.support import ensure_sse2_floats
from rpython.rlib import rfloat
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.debug import debug_print
from rpython.rtyper.lltypesystem.module.test.math_cases import (MathTests,
                                                                get_tester)

def get_test_case((fnname, args, expected)):
    try:
        fn = getattr(math, fnname)
    except AttributeError:
        fn = getattr(rfloat, fnname)
    expect_valueerror = (expected == ValueError)
    expect_overflowerror = (expected == OverflowError)
    check = get_tester(expected)
    unroll_args = unrolling_iterable(args)
    #
    def testfn():
        debug_print('calling', fnname, 'with arguments:')
        for arg in unroll_args:
            debug_print('\t', arg)
        try:
            got = fn(*args)
        except ValueError:
            if expect_valueerror:
                return True
            else:
                debug_print('unexpected ValueError!')
                return False
        except OverflowError:
            if expect_overflowerror:
                return True
            else:
                debug_print('unexpected OverflowError!')
                return False
        else:
            if check(got):
                return True
            else:
                debug_print('unexpected result:', got)
                return False
    #
    testfn.__name__ = 'test_' + fnname
    return testfn


testfnlist = [get_test_case(testcase)
              for testcase in MathTests.TESTCASES]

def fn():
    ensure_sse2_floats()
    for i in range(len(testfnlist)):
        testfn = testfnlist[i]
        if not testfn():
            return i
    return -42  # ok

def test_math():
    # note: we use lldebug because in the normal optimizing mode, some
    # calls may be completely inlined and constant-folded by the
    # compiler (with -flto), e.g. atanh(0.3).  They give then slightly
    # different result than if they were executed at runtime.
    # https://gcc.gnu.org/bugzilla/show_bug.cgi?id=79973
    f = compile(fn, [], lldebug=True)
    res = f()
    if res >= 0:
        py.test.fail(repr(MathTests.TESTCASES[res]))
    else:
        assert res == -42
