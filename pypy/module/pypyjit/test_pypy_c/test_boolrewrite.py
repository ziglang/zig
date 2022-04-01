import py
from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC

class TestBoolRewrite(BaseTestPyPyC):

    def test_boolrewrite_inverse(self):
        """
        Test for this case::
            guard(i < x)
            ...
            guard(i >= y)

        where x and y can be either constants or variables. There are cases in
        which the second guard is proven to be always true.
        """

        for a, b, res, opt_expected in (('2000', '2000', 20001000, True),
                                        ( '500',  '500', 15001500, True),
                                        ( '300',  '600', 16001700, False),
                                        (   'a',    'b', 16001700, False),
                                        (   'a',    'a', 13001700, True)):
            src = """
                def main():
                    sa = 0
                    a = 300
                    b = 600
                    for i in range(1000):
                        if i < %s:         # ID: lt
                            sa += 1
                        else:
                            sa += 2
                        #
                        if i >= %s:        # ID: ge
                            sa += 10000
                        else:
                            sa += 20000
                    return sa
            """ % (a, b)
            #
            log = self.run(src, [], threshold=400)
            assert log.result == res
            for loop in log.loops_by_filename(self.filepath):
                le_ops = log.opnames(loop.ops_by_id('lt'))
                ge_ops = log.opnames(loop.ops_by_id('ge'))
                assert le_ops.count('int_lt') == 1
                #
                if opt_expected:
                    assert ge_ops.count('int_ge') == 0
                else:
                    # if this assert fails it means that the optimization was
                    # applied even if we don't expect to. Check whether the
                    # optimization is valid, and either fix the code or fix the
                    # test :-)
                    assert ge_ops.count('int_ge') == 1

    def test_boolrewrite_reflex(self):
        """
        Test for this case::
            guard(i < x)
            ...
            guard(y > i)

        where x and y can be either constants or variables. There are cases in
        which the second guard is proven to be always true.
        """
        for a, b, res, opt_expected in (('2000', '2000', 10001000, True),
                                        ( '500',  '500', 15001500, True),
                                        ( '300',  '600', 14001700, False),
                                        (   'a',    'b', 14001700, False),
                                        (   'a',    'a', 17001700, True)):

            src = """
                def main():
                    sa = 0
                    a = 300
                    b = 600
                    for i in range(1000):
                        if i < %s:        # ID: lt
                            sa += 1
                        else:
                            sa += 2
                        if %s > i:        # ID: gt
                            sa += 10000
                        else:
                            sa += 20000
                    return sa
            """ % (a, b)
            log = self.run(src, [], threshold=400)
            assert log.result == res
            for loop in log.loops_by_filename(self.filepath):
                le_ops = log.opnames(loop.ops_by_id('lt'))
                gt_ops = log.opnames(loop.ops_by_id('gt'))
                assert le_ops.count('int_lt') == 1
                #
                if opt_expected:
                    assert gt_ops.count('int_gt') == 0
                else:
                    # if this assert fails it means that the optimization was
                    # applied even if we don't expect to. Check whether the
                    # optimization is valid, and either fix the code or fix the
                    # test :-)
                    assert gt_ops.count('int_gt') == 1


    def test_boolrewrite_allcases_inverse(self):
        """
        Test for this case::
            guard(i < x)
            ...
            guard(i > y)

        with all possible combination of binary comparison operators.  This
        test only checks that we get the expected result, not that any
        optimization has been applied.
        """
        ops = ('<', '>', '<=', '>=', '==', '!=')
        for op1 in ops:
            for op2 in ops:
                for a,b in ((500, 500), (300, 600)):
                    src = """
                        def main():
                            sa = 0
                            for i in range(300):
                                if i %s %d:
                                    sa += 1
                                else:
                                    sa += 2
                                if i %s %d:
                                    sa += 10000
                                else:
                                    sa += 20000
                            return sa
                    """ % (op1, a, op2, b)
                    yield self.run_and_check, src

                    src = """
                        def main():
                            sa = 0
                            i = 0.0
                            while i < 250.0:
                                if i %s %f:
                                    sa += 1
                                else:
                                    sa += 2
                                if i %s %f:
                                    sa += 10000
                                else:
                                    sa += 20000
                                i += 0.25
                            return sa
                    """ % (op1, float(a)/4.0, op2, float(b)/4.0)
                    yield self.run_and_check, src


    def test_boolrewrite_allcases_reflex(self):
        """
        Test for this case::
            guard(i < x)
            ...
            guard(x > i)

        with all possible combination of binary comparison operators.  This
        test only checks that we get the expected result, not that any
        optimization has been applied.
        """
        ops = ('<', '>', '<=', '>=', '==', '!=')
        for op1 in ops:
            for op2 in ops:
                for a,b in ((500, 500), (300, 600)):
                    src = """
                        def main():
                            sa = 0
                            for i in range(300):
                                if i %s %d:
                                    sa += 1
                                else:
                                    sa += 2
                                if %d %s i:
                                    sa += 10000
                                else:
                                    sa += 20000
                            return sa
                    """ % (op1, a, b, op2)
                    yield self.run_and_check, src

                    src = """
                        def main():
                            sa = 0
                            i = 0.0
                            while i < 250.0:
                                if i %s %f:
                                    sa += 1
                                else:
                                    sa += 2
                                if %f %s i:
                                    sa += 10000
                                else:
                                    sa += 20000
                                i += 0.25
                            return sa
                    """ % (op1, float(a)/4.0, float(b)/4.0, op2)
                    yield self.run_and_check, src

    def test_boolrewrite_ptr(self):
        """
        This test only checks that we get the expected result, not that any
        optimization has been applied.
        """
        compares = ('a == b', 'b == a', 'a != b', 'b != a', 'a == c', 'c != b')
        for e1 in compares:
            for e2 in compares:
                src = """
                    class tst(object):
                        pass
                    def main():
                        a = tst()
                        b = tst()
                        c = tst()
                        sa = 0
                        for i in range(1000):
                            if %s:
                                sa += 1
                            else:
                                sa += 2
                            if %s:
                                sa += 10000
                            else:
                                sa += 20000
                            if i > 750:
                                a = b
                        return sa
                """ % (e1, e2)
                yield self.run_and_check, src
