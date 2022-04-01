from rpython.annotator import model as annmodel, annrpython
from rpython.flowspace.model import Constant
from rpython.rtyper import rmodel
from rpython.rtyper.lltypesystem.lltype import Signed, Void
from rpython.rtyper.rtyper import RPythonTyper
from rpython.rtyper.test.test_llinterp import interpret
from rpython.translator.translator import TranslationContext, graphof


def test_reprkeys_dont_clash():
    stup1 = annmodel.SomeTuple((annmodel.SomeFloat(),
                                annmodel.SomeInteger()))
    stup2 = annmodel.SomeTuple((annmodel.SomeString(),
                                annmodel.SomeInteger()))
    key1 = stup1.rtyper_makekey()
    key2 = stup2.rtyper_makekey()
    assert key1 != key2

def test_simple():
    def dummyfn(x):
        return x+1

    res = interpret(dummyfn, [7])
    assert res == 8

def test_function_call():
    def g(x, y):
        return x-y
    def f(x):
        return g(1, x)

    res = interpret(f, [4])
    assert res == -3

def test_retval():
    def f(x):
        return x
    t = TranslationContext()
    t.buildannotator().build_types(f, [int])
    t.buildrtyper().specialize()
    #t.view()
    t.checkgraphs()
    graph = graphof(t, f)
    assert graph.getreturnvar().concretetype == Signed
    assert graph.startblock.exits[0].args[0].concretetype == Signed

def test_retval_None():
    def f(x):
        pass
    t = TranslationContext()
    t.buildannotator().build_types(f, [int])
    t.buildrtyper().specialize()
    #t.view()
    t.checkgraphs()
    graph = graphof(t, f)
    assert graph.getreturnvar().concretetype == Void
    assert graph.startblock.exits[0].args[0].concretetype == Void

def test_ll_calling_ll():
    import test_llann
    tst = test_llann.TestLowLevelAnnotateTestCase()
    a, vTs = tst.test_ll_calling_ll()
    rt = RPythonTyper(a)
    rt.specialize()
    assert [vT.concretetype for vT in vTs] == [Void] * 4

def test_ll_calling_ll2():
    import test_llann
    tst = test_llann.TestLowLevelAnnotateTestCase()
    a, vTs = tst.test_ll_calling_ll2()
    rt = RPythonTyper(a)
    rt.specialize()
    assert [vT.concretetype for vT in vTs] == [Void] * 3


def test_getgcflavor():
    class A:
        pass
    class B:
        _alloc_flavor_ = "gc"
    class R:
        _alloc_flavor_ = "raw"

    class DummyClsDescDef:
        def __init__(self, cls):
            self._cls = cls
            self.classdesc = self
            self.basedef = None

        def getmro(self):
            return [self]

        def get_param(self, name, default=None, inherit=True):
            return getattr(self._cls, name, default)

    assert rmodel.getgcflavor(DummyClsDescDef(A)) == 'gc'
    assert rmodel.getgcflavor(DummyClsDescDef(B)) == 'gc'
    assert rmodel.getgcflavor(DummyClsDescDef(R)) == 'raw'
