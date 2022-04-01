from rpython.translator.backendopt.removenoops import remove_same_as, \
        remove_unaryops, remove_duplicate_casts
from rpython.translator.backendopt.inline import simple_inline_function
from rpython.translator.translator import TranslationContext, graphof
from rpython.memory.gctransform.test.test_transform import getops
from rpython.translator.test.snippet import simple_method
from rpython.translator.backendopt.all import backend_optimizations
from rpython.translator.backendopt.all import INLINE_THRESHOLD_FOR_TEST
from rpython.flowspace.model import checkgraph, Block
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.llinterp import LLInterpreter
from rpython.conftest import option


def get_graph(fn, signature, all_opts=True):
    t = TranslationContext()
    t.buildannotator().build_types(fn, signature)
    t.buildrtyper().specialize()
    if all_opts:
        backend_optimizations(t, inline_threshold=INLINE_THRESHOLD_FOR_TEST,
                              constfold=False)
    graph = graphof(t, fn)
    if option.view:
        t.view()
    return graph, t

def check_graph(graph, args, expected_result, t):
    interp = LLInterpreter(t.rtyper)
    res = interp.eval_graph(graph, args)
    assert res == expected_result

def check_get_graph(fn, signature, args, expected_result):
    graph, t = get_graph(fn, signature)
    check_graph(graph, args, expected_result, t)
    return graph


def test_remove_same_as():
    def nothing(x):
        return x
    def f():
        nothing(False)
        if nothing(True):
            return 42
        else:
            return 666
    t = TranslationContext()
    t.buildannotator().build_types(f, [])
    t.buildrtyper().specialize()
    # now we make the 'if True' appear
    f_graph = graphof(t, f)
    simple_inline_function(t, nothing, f_graph)
    # here, the graph looks like  v21=same_as(True);  exitswitch: v21
    remove_same_as(f_graph)
    t.checkgraphs()
    # only one path should be left
    for block in f_graph.iterblocks():
        assert len(block.exits) <= 1

    interp = LLInterpreter(t.rtyper)
    result = interp.eval_graph(f_graph, [])
    assert result == 42


def test_remove_same_as_nonconst():
    from rpython.rlib.nonconst import NonConstant
    from rpython.rtyper.lltypesystem.lloperation import llop
    from rpython.rtyper.lltypesystem import lltype

    def f():
        if NonConstant(False):
            x = llop.same_as(lltype.Signed, 666)
        return 42

    t = TranslationContext()
    t.buildannotator().build_types(f, [])
    t.buildrtyper().specialize()
    f_graph = graphof(t, f)
    #simple_inline_function(t, nothing, f_graph)
    # here, the graph looks like  v21=same_as(True);  exitswitch: v21
    remove_same_as(f_graph)
    t.checkgraphs()
    # only one path should be left
    for block in f_graph.iterblocks():
        assert len(block.exits) <= 1

    for block in t.annotator.annotated:
        assert None not in block.operations

    interp = LLInterpreter(t.rtyper)
    result = interp.eval_graph(f_graph, [])
    assert result == 42


def test_remove_unaryops():
    # We really want to use remove_unaryops for more complex operations, but
    # it's easier to test it with operations on ints here.
    def f(x):
        i = llop.int_invert(lltype.Signed, x)
        i = llop.int_add(lltype.Signed, x, 1)
        return llop.int_neg(lltype.Signed, i)
    t = TranslationContext()
    t.buildannotator().build_types(f, [int])
    t.buildrtyper().specialize()
    f_graph = graphof(t, f)
    remove_unaryops(f_graph, ["int_neg", "int_invert"])
    t.checkgraphs()

    interp = LLInterpreter(t.rtyper)
    result = interp.eval_graph(f_graph, [-2])
    assert result == -1

def test_remove_duplicate_casts():
    class A(object):
        def __init__(self, x, y):
            self.x = x
            self.y = y
        def getsum(self):
            return self.x + self.y
    class B(A):
        def __init__(self, x, y, z):
            A.__init__(self, x, y)
            self.z = z
        def getsum(self):
            return self.x + self.y + self.z
    def f(x, switch):
        a = A(x, x + 1)
        b = B(x, x + 1, x + 2)
        if switch:
            c = A(x, x + 1)
        else:
            c = B(x, x + 1, x + 2)
        return a.x + a.y + b.x + b.y + b.z + c.getsum()
    assert f(10, True) == 75
    graph, t = get_graph(f, [int, bool], all_opts=False)
    num_cast_pointer = len(getops(graph)['cast_pointer'])
    changed = remove_duplicate_casts(graph, t)
    assert changed
    ops = getops(graph)
    assert len(ops['cast_pointer']) < num_cast_pointer
    print len(ops['cast_pointer']), num_cast_pointer
    graph_getsum = graphof(t, B.getsum.im_func)
    num_cast_pointer = len(getops(graph_getsum)['cast_pointer'])
    changed = remove_duplicate_casts(graph_getsum, t)
    assert changed
    if option.view:
        t.view()
    check_graph(graph, [10, True], 75, t)
    ops = getops(graph_getsum)
    assert len(ops['cast_pointer']) < num_cast_pointer
    print len(ops['cast_pointer']), num_cast_pointer
    
