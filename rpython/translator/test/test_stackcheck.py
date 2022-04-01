from rpython.conftest import option
from rpython.translator.translator import TranslationContext, graphof
from rpython.translator.backendopt.all import backend_optimizations
from rpython.translator.transform import insert_ll_stackcheck
from rpython.memory.gctransform import shadowstack

def _follow_path_naive(block, cur_path, accum):
    cur_path = (cur_path, block)
    if not block.exits:
        ops = []
        while cur_path:
            block = cur_path[1]
            ops.extend(reversed(block.operations))
            cur_path = cur_path[0]
        accum.append(list(reversed(ops)))
        return
    for link in block.exits:
        _follow_path_naive(link.target, cur_path, accum)

# explodes on loops!
def paths_naive(g):
    accum = []
    _follow_path_naive(g.startblock, None, accum)
    return accum

def direct_target(spaceop):
    return spaceop.args[0].value._obj.graph.name

def direct_calls(p):
    names = []
    for spaceop in p:
        if spaceop.opname == 'direct_call':
            names.append(direct_target(spaceop))
    return names

            
def check(g, funcname, ignore=None):
    paths = paths_naive(g)
    relevant = []
    for p in paths:
        funcs_called = direct_calls(p)
        if funcname in funcs_called and ignore not in funcs_called:
            assert 'stack_check___' in funcs_called
            assert (funcs_called.index(funcname) >
                    funcs_called.index('stack_check___'))
            relevant.append(p)
    return relevant
    

class A(object):
    def __init__(self, n):
        self.n = n

def f(a):
    x = A(a.n+1)
    if x.n == 10:
        return
    f(x)

def g(n):
    f(A(n))
    return 0

def test_simple():
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(g, [int])
    a.simplify()
    t.buildrtyper().specialize()        
    backend_optimizations(t)
    t.checkgraphs()
    n = insert_ll_stackcheck(t)
    t.checkgraphs()
    assert n == 1
    if option.view:
        t.view()
    check(graphof(t, f), 'f')

def test_gctransformed():
    t = TranslationContext()
    a = t.buildannotator()
    a.build_types(g, [int])
    a.simplify()
    t.buildrtyper().specialize()        
    backend_optimizations(t)
    t.checkgraphs()
    n = insert_ll_stackcheck(t)
    t.checkgraphs()
    assert n == 1
    exctransf = t.getexceptiontransformer()
    f_graph = graphof(t, f)
    exctransf.create_exception_handling(f_graph)
    if option.view:
        f_graph.show()
    check(f_graph, 'f')    

    class GCTransform(shadowstack.ShadowStackFrameworkGCTransformer):
        from rpython.memory.gc.generation import GenerationGC as \
                                                          GCClass
        GC_PARAMS = {}

    gctransf = GCTransform(t)
    gctransf.transform_graph(f_graph)
    if option.view:
        f_graph.show()
    relevant = check(f_graph, 'f')        
    for p in relevant:
        in_between = False
        reload = 0
        for spaceop in p:
            if spaceop.opname == 'direct_call':
                target = direct_target(spaceop)
                if target == 'f':
                    in_between = False
                elif target == 'stack_check___':
                    in_between = True
            if in_between and spaceop.opname == 'gc_reload_possibly_moved':
                reload += 1
                
        assert reload == 0
