import py


from rpython.annotator.test.test_annrpython import graphof
from rpython.annotator.test.test_annrpython import TestAnnotateTestCase as parent
from rpython.annotator.model import AnnotatorError


class TestAnnotateAndSimplifyTestCase(parent):
    """Same tests as test_annrpython.TestAnnotateTestCase, but automatically
    running the simplify() method of the annotator after the annotation phase.
    """

    class RPythonAnnotator(parent.RPythonAnnotator):
        def complete(self):
            parent.RPythonAnnotator.complete(self)
            if self.translator is not None:
                self.simplify()

    def test_simple_pbc_call(self):
        def f1(x,y=0):
            pass
        def f2(x):
            pass
        def f3(x):
            pass
        def g(f):
            f(1)
        def h():
            f1(1)
            f1(1,2)
            g(f2)
            g(f3)

        a = self.RPythonAnnotator()
        s = a.build_types(h, [])

        fdesc1 = a.bookkeeper.getdesc(f1)
        fdesc2 = a.bookkeeper.getdesc(f2)
        fdesc3 = a.bookkeeper.getdesc(f3)

        fam1 = fdesc1.getcallfamily()
        fam2 = fdesc2.getcallfamily()
        fam3 = fdesc3.getcallfamily()

        assert fam1 is not fam2
        assert fam1 is not fam3
        assert fam3 is fam2

        gf1 = graphof(a, f1)
        gf2 = graphof(a, f2)
        gf3 = graphof(a, f3)

        assert fam1.calltables == {(2, (), False): [{fdesc1: gf1}],
                                   (1, (), False): [{fdesc1: gf1}]}
        assert fam2.calltables == {(1, (), False): [{fdesc2: gf2, fdesc3: gf3}]}

    def test_pbc_call_ins(self):
        class A(object):
            def m(self):
                pass
        class B(A):
            def n(self):
                pass
        class C(A):
            def __init__(self):
                pass
            def m(self):
                pass
        def f(x):
            b = B()
            c = C()
            b.n()
            if x:
                a = b
            else:
                a = c
            a.m()

        a = self.RPythonAnnotator()
        s = a.build_types(f, [bool])

        bookkeeper = a.bookkeeper

        def getmdesc(bmeth):
            return bookkeeper.immutablevalue(bmeth).any_description()

        mdescA_m = getmdesc(A().m)
        mdescC_m = getmdesc(C().m)
        mdescB_n = getmdesc(B().n)

        assert mdescA_m.name == 'm' == mdescC_m.name
        assert mdescB_n.name == 'n'

        famA_m = mdescA_m.getcallfamily()
        famC_m = mdescC_m.getcallfamily()
        famB_n = mdescB_n.getcallfamily()

        assert famA_m is famC_m
        assert famB_n is not famA_m

        gfB_n = graphof(a, B.n.im_func)
        gfA_m = graphof(a, A.m.im_func)
        gfC_m = graphof(a, C.m.im_func)

        assert famB_n.calltables == {(1, (), False): [{mdescB_n.funcdesc: gfB_n}]}
        assert famA_m.calltables == {(1, (), False): [
            {mdescA_m.funcdesc: gfA_m, mdescC_m.funcdesc: gfC_m }]}

        mdescCinit = getmdesc(C().__init__)
        famCinit = mdescCinit.getcallfamily()
        gfCinit = graphof(a, C.__init__.im_func)

        assert famCinit.calltables == {(1, (), False): [{mdescCinit.funcdesc: gfCinit}]}

    def test_call_classes_with_noarg_init(self):
        class A:
            foo = 21
        class B(A):
            foo = 22
        class C(A):
            def __init__(self):
                self.foo = 42
        class D(A):
            def __init__(self):
                self.foo = 43
        def f(i):
            if i == 1:
                cls = B
            elif i == 2:
                cls = D
            else:
                cls = C
            return cls().foo
        a = self.RPythonAnnotator()
        with py.test.raises(AnnotatorError):
            a.build_types(f, [int])
