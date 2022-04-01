import py

from rpython.annotator.listdef import s_list_of_strings
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.backendopt import gilanalysis
from rpython.memory.gctransform.test.test_transform import rtype
from rpython.translator.translator import graphof

def test_canrelease_external():
    for rel in ['auto', True, False]:
        for sbxs in [True, False]:
            fext = rffi.llexternal('fext2', [], lltype.Void, 
                                   releasegil=rel, sandboxsafe=sbxs)
            def g():
                fext()
            t = rtype(g, [])
            gg = graphof(t, g)

            releases = (rel == 'auto' and not sbxs) or rel is True
            assert releases == gilanalysis.GilAnalyzer(t).analyze_direct_call(gg)

def test_canrelease_instantiate():
    class O:
        pass
    class A(O):
        pass
    class B(O):
        pass

    classes = [A, B]
    def g(i):
        classes[i]()

    t = rtype(g, [int])
    gg = graphof(t, g)
    assert not gilanalysis.GilAnalyzer(t).analyze_direct_call(gg)



def test_no_release_gil():
    from rpython.rlib import rgc

    @rgc.no_release_gil
    def g():
        return 1

    assert g._dont_inline_
    assert g._no_release_gil_

    def entrypoint(argv):
        return g() + 2
    
    t = rtype(entrypoint, [s_list_of_strings])
    gilanalysis.analyze(t.graphs, t)



def test_no_release_gil_detect(gc="minimark"):
    from rpython.rlib import rgc

    fext1 = rffi.llexternal('fext1', [], lltype.Void, releasegil=True)
    @rgc.no_release_gil
    def g():
        fext1()
        return 1

    assert g._dont_inline_
    assert g._no_release_gil_

    def entrypoint(argv):
        return g() + 2
    
    t = rtype(entrypoint, [s_list_of_strings])
    f = py.test.raises(Exception, gilanalysis.analyze, t.graphs, t)
    expected = "'no_release_gil' function can release the GIL: <function g at "
    assert str(f.value).startswith(expected)
