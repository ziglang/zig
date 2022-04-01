import py
from rpython.rtyper.llannotation import SomePtr
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rtyper.rvirtualizable import replace_force_virtualizable_with_call
from rpython.rlib.jit import hint
from rpython.flowspace.model import summary
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.rclass import IR_IMMUTABLE, IR_IMMUTABLE_ARRAY
from rpython.conftest import option


class V(object):
    _virtualizable_ = ['v']
    v = -12
    w = -62

    def __init__(self, v):
        self.v = v
        self.w = v+1

class SubclassV(V):
    pass

class VArray(object):
    _virtualizable_ = ['lst[*]']

    def __init__(self, lst):
        self.lst = lst
class B(object):
    _virtualizable_ = ['v0']

    x = "XX"

    def __init__(self, v0):
        self.v0 = v0

def get_force_virtualizable_flags(graph):
    res = []
    for block, op in graph.iterblockops():
        if op.opname == 'jit_force_virtualizable':
            res.append(op.args[-1].value)
    return res

class TestVirtualizable(BaseRtypingTest):
    prefix = 'inst_'
    GETFIELD = 'getfield'
    SETFIELD = 'setfield'

    def gettype(self, v):
        return v.concretetype.TO

    def test_generate_force_virtualizable(self):
        def fn(n):
            vinst = V(n)
            return vinst.v
        _, _, graph = self.gengraph(fn, [int])
        block = graph.startblock
        op_promote = block.operations[-2]
        op_getfield = block.operations[-1]
        assert op_getfield.opname == 'getfield'
        v_inst = op_getfield.args[0]
        assert op_promote.opname == 'jit_force_virtualizable'
        assert op_promote.args[0] is v_inst
        assert op_promote.args[-1].value == {}

    def test_generate_force_virtualizable_subclass(self):
        def fn(n):
            V(n) # to attach v to V
            vinst = SubclassV(n)
            return vinst.v
        _, _, graph = self.gengraph(fn, [int])
        block = graph.startblock
        op_promote = block.operations[-2]
        op_getfield = block.operations[-1]
        assert op_getfield.opname == 'getfield'
        v_inst = op_getfield.args[0]
        assert op_promote.opname == 'jit_force_virtualizable'
        assert op_promote.args[0] is v_inst
        assert op_promote.args[-1].value == {}

    def test_no_force_virtualizable_for_other_fields(self):
        def fn(n):
            vinst = V(n)
            return vinst.w
        _, _, graph = self.gengraph(fn, [int])
        block = graph.startblock
        op_getfield = block.operations[-1]
        op_call = block.operations[-2]
        assert op_getfield.opname == 'getfield'
        assert op_call.opname == 'direct_call'    # to V.__init__

    def test_generate_force_virtualizable_array(self):
        def fn(n):
            vinst = VArray([n, n+1])
            return vinst.lst[1]
        _, _, graph = self.gengraph(fn, [int])
        block = graph.startblock
        op_promote = block.operations[-3]
        op_getfield = block.operations[-2]
        op_getarrayitem = block.operations[-1]
        assert op_getarrayitem.opname == 'direct_call'  # to ll_getitem_xxx
        assert op_getfield.opname == 'getfield'
        v_inst = op_getfield.args[0]
        assert op_promote.opname == 'jit_force_virtualizable'
        assert op_promote.args[0] is v_inst
        assert op_promote.args[-1].value == {}

    def test_accessor(self):
        class Base(object):
            pass
        class V(Base):
            _virtualizable_ = ['v1', 'v2[*]']
        class W(V):
            pass
        #
        def fn1(n):
            Base().base1 = 42
            V().v1 = 43
            V().v2 = ['x', 'y']
            W().w1 = 44
            return V()
        _, _, graph = self.gengraph(fn1, [int])
        v_inst = graph.getreturnvar()
        TYPE = self.gettype(v_inst)
        accessor = TYPE._hints['virtualizable_accessor']
        assert accessor.TYPE == TYPE
        assert accessor.fields == {self.prefix + 'v1': IR_IMMUTABLE,
                                   self.prefix + 'v2': IR_IMMUTABLE_ARRAY}
        #
        def fn2(n):
            Base().base1 = 42
            V().v1 = 43
            V().v2 = ['x', 'y']
            W().w1 = 44
            return W()
        _, _, graph = self.gengraph(fn2, [int])
        w_inst = graph.getreturnvar()
        TYPE = self.gettype(w_inst)
        assert 'virtualizable_accessor' not in TYPE._hints

    def replace_force_virtualizable(self, rtyper, graphs):
        from rpython.annotator import model as annmodel
        from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
        graph = graphs[0]

        for block, op in graph.iterblockops():
            if op.opname == 'jit_force_virtualizable':
                v_inst_ll_type = op.args[0].concretetype
                break

        def mycall(vinst_ll):
            if vinst_ll.vable_token:
                raise ValueError
        annhelper = MixLevelHelperAnnotator(rtyper)
        s_vinst = SomePtr(v_inst_ll_type)
        funcptr = annhelper.delayedfunction(mycall, [s_vinst], annmodel.s_None)
        annhelper.finish()
        replace_force_virtualizable_with_call(graphs, v_inst_ll_type, funcptr)
        return funcptr

    def test_replace_force_virtualizable_with_call(self):
        def fn(n):
            vinst = V(n)
            return vinst.v
        _, rtyper, graph = self.gengraph(fn, [int])
        block = graph.startblock
        op_getfield = block.operations[-1]
        assert op_getfield.opname == 'getfield'
        funcptr = self.replace_force_virtualizable(rtyper, [graph])
        if getattr(option, 'view', False):
            graph.show()
        op_promote = block.operations[-2]
        op_getfield = block.operations[-1]
        assert op_getfield.opname == 'getfield'
        assert op_promote.opname == 'direct_call'
        assert op_promote.args[0].value == funcptr
        assert op_promote.args[1] == op_getfield.args[0]
        #
        interp = LLInterpreter(rtyper)
        res = interp.eval_graph(graph, [61])
        assert res == 61

    def test_access_directly(self):
        def g(b):
            b.v0 += 1
            return b.v0

        def f(n):
            b = B(n)
            b = hint(b, access_directly=True)
            return g(b)

        t, typer, graph = self.gengraph(f, [int])
        g_graph = t._graphof(g)

        expected =  [{'access_directly': True}] * 3
        assert get_force_virtualizable_flags(g_graph) == expected

        self.replace_force_virtualizable(typer, [g_graph])
        assert summary(g_graph) == {self.GETFIELD: 2, self.SETFIELD: 1, 'int_add': 1}

        res = self.interpret(f, [23])
        assert res == 24

    def test_access_directly_exception(self):
        def g(b):
            return b.v0

        def f(n):
            b = B(n)
            b = hint(b, access_directly=True)
            if not b.v0:
                raise Exception
            return g(b)

        t, typer, graph = self.gengraph(f, [int])
        f_graph = t._graphof(f)
        g_graph = t._graphof(g)

        self.replace_force_virtualizable(typer, [f_graph, g_graph])
        t.checkgraphs()

        res = self.interpret(f, [23])
        assert res == 23

    def test_access_directly_specialized(self):
        def g(b):
            return b.v0

        def f(n):
            b = B(n)
            x = g(b)
            y = g(hint(b, access_directly=True))
            return x + y

        t, typer, graph = self.gengraph(f, [int])
        desc = typer.annotator.bookkeeper.getdesc(g)
        g_graphs = desc._cache.items()
        assert len(g_graphs) == 2
        g_graphs.sort()
        assert g_graphs[0][0] is None

        assert get_force_virtualizable_flags(g_graphs[0][1]) == [{}]
        expected =  [{'access_directly': True}]
        assert get_force_virtualizable_flags(g_graphs[1][1]) == expected

        self.replace_force_virtualizable(typer, [g_graphs[0][1],
                                                 g_graphs[1][1]])

        assert summary(g_graphs[0][1]) == {'direct_call': 1, self.GETFIELD: 1}
        assert summary(g_graphs[1][1]) == {self.GETFIELD: 1}

        res = self.interpret(f, [23])
        assert res == 46

    def test_access_directly_escape(self):
        class Global:
            pass
        glob = Global()

        def g(b):
            glob.b = b

        def h(b):
            return b.v0

        def f(n):
            b = B(n)
            g(b)
            g(hint(b, access_directly=True))
            return h(glob.b)

        t, typer, graph = self.gengraph(f, [int])
        desc = typer.annotator.bookkeeper.getdesc(g)
        g_graphs = desc._cache.items()
        assert len(g_graphs) == 2
        g_graphs.sort()
        assert g_graphs[0][0] is None
        assert summary(g_graphs[0][1]) == {self.SETFIELD: 1}
        assert summary(g_graphs[1][1]) == {self.SETFIELD: 1}

        h_graph = t._graphof(h)
        assert summary(h_graph) == {'jit_force_virtualizable': 1,
                                    self.GETFIELD: 1}
        assert get_force_virtualizable_flags(h_graph) == [{}]

        res = self.interpret(f, [23])
        assert res == 23

    def test_access_directly_method(self):
        class A:
            _virtualizable_ = ['v0']

            def __init__(self, v):
                self.v0 = v

            def meth1(self, x):
                return self.g(x+1)

            def g(self, y):
                return self.v0 * y

        def f(n):
            a = A(n)
            a = hint(a, access_directly=True)
            return a.meth1(100)

        t, typer, graph = self.gengraph(f, [int])
        g_graph = t._graphof(A.g.im_func)

        self.replace_force_virtualizable(typer, [g_graph])

        assert summary(g_graph) == {self.GETFIELD: 1, 'int_mul': 1}

        res = self.interpret(f, [23])
        assert res == 2323

    def test_access_directly_stop_at_dont_look_inside(self):
        from rpython.rlib.jit import dont_look_inside

        class A:
            _virtualizable_ = ['x']

        def h(a):
            g(a)
        h = dont_look_inside(h)

        def g(a):
            a.x = 2
            h(a)

        def f():
            a = A()
            a = hint(a, access_directly=True)
            a.x = 1
            g(a)

        t, typer, graph = self.gengraph(f, [])

        desc = typer.annotator.bookkeeper.getdesc(g)
        g_graphs = desc._cache.items()
        assert len(g_graphs) == 2
        g_graphs.sort()

        assert g_graphs[0][0] is None # default
        g_graph = g_graphs[0][1]
        g_graph_directly = g_graphs[1][1]

        f_graph = t._graphof(f)
        h_graph = t._graphof(h) # 1 graph!

        def get_direct_call_graph(graph):
            for block, op in graph.iterblockops():
                if op.opname == 'direct_call':
                    return op.args[0].value._obj.graph
            return None

        assert get_direct_call_graph(f_graph) is g_graph_directly
        assert get_direct_call_graph(g_graph) is h_graph
        assert get_direct_call_graph(g_graph_directly) is h_graph
        assert get_direct_call_graph(h_graph) is g_graph

    def test_simple(self):
        def f(v):
            vinst = V(v)
            return vinst, vinst.v
        res = self.interpret(f, [42])
        assert res.item1 == 42
        res = lltype.normalizeptr(res.item0)
        assert res.inst_v == 42
        assert res.vable_token == lltype.nullptr(llmemory.GCREF.TO)
