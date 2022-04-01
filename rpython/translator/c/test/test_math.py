import py, math
from rpython.rtyper.lltypesystem.module.test.math_cases import (MathTests,
                                                                get_tester)
from rpython.translator.c.test.test_standalone import StandaloneTests
from rpython.rlib import rfloat


def get_test_case((fnname, args, expected)):
    try:
        fn = getattr(math, fnname)
    except AttributeError:
        fn = getattr(rfloat, fnname)
    expect_valueerror = (expected == ValueError)
    expect_overflowerror = (expected == OverflowError)
    check = get_tester(expected)
    #
    def testfn():
        try:
            got = fn(*args)
        except ValueError:
            return expect_valueerror
        except OverflowError:
            return expect_overflowerror
        else:
            return check(got)
    #
    testfn.__name__ = 'test_' + fnname
    return testfn


testfnlist = [get_test_case(testcase)
              for testcase in MathTests.TESTCASES]
reprlist = [repr(testcase)
            for testcase in MathTests.TESTCASES]

def fn(args):
    err = False
    for i in range(len(testfnlist)):
        testfn = testfnlist[i]
        if not testfn():
            print "error:", reprlist[i]
            err = True
    if not err:
        print "all ok"
    return 0


class TestMath(StandaloneTests):

    def test_math(self, debug=True):
        t, cbuilder = self.compile(fn, debug=debug)
        data = cbuilder.cmdexec('')
        if "error:" in data:
            py.test.fail(data.strip())
        else:
            assert "all ok" in data

    def test_math_nodebug(self):
        self.test_math(debug=False)
