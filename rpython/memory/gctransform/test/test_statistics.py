from rpython.rtyper.lltypesystem import lltype
from rpython.memory.gctransform.test.test_transform import \
     rtype
from rpython.memory.gctransform.statistics import \
     relevant_gcvars_graph, relevant_gcvars, filter_for_nongcptr
from rpython.translator.translator import graphof

def test_count_vars_simple():
    S = lltype.GcStruct('abc', ('x', lltype.Signed))
    def f():
        s1 = lltype.malloc(S)
        s2 = lltype.malloc(S)
        s1.x = 1
        s2.x = 2
        return s1.x + s2.x
    t = rtype(f, [])
    assert relevant_gcvars_graph(graphof(t, f)) == [0, 1]

def test_count_vars_big():
    from rpython.translator.goal.targetrpystonex import make_target_definition
    from rpython.translator.backendopt.all import backend_optimizations
    entrypoint, _, _ = make_target_definition(10)
    t = rtype(entrypoint, [int])
    backend_optimizations(t)
    # does not crash
    rel = relevant_gcvars(t)
    print rel
    print sum(rel) / float(len(rel)), max(rel), min(rel)

    rel = relevant_gcvars(t, filter_for_nongcptr)
    print rel
    print sum(rel) / float(len(rel)), max(rel), min(rel)
