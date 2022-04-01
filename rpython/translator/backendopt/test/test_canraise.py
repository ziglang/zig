from rpython.translator.translator import TranslationContext, graphof
from rpython.translator.backendopt.canraise import RaiseAnalyzer
from rpython.translator.backendopt.all import backend_optimizations
from rpython.conftest import option

class TestCanRaise(object):
    def translate(self, func, sig):
        t = TranslationContext()
        t.buildannotator().build_types(func, sig)
        t.buildrtyper().specialize()
        if option.view:
            t.view()
        return t, RaiseAnalyzer(t)


    def test_can_raise_simple(self):
        def g(x):
            return True

        def f(x):
            return g(x - 1)
        t, ra = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = ra.can_raise(fgraph.startblock.operations[0])
        assert not result

    def test_can_raise_recursive(self):
        from rpython.translator.transform import insert_ll_stackcheck
        def g(x):
            return f(x)

        def f(x):
            if x:
                return g(x - 1)
            return 1
        t, ra = self.translate(f, [int])
        insert_ll_stackcheck(t)
        ggraph = graphof(t, g)
        result = ra.can_raise(ggraph.startblock.operations[-1])
        assert result # due to stack check every recursive function can raise

    def test_bug_graphanalyze_recursive(self):
        # intentionally don't insert stack checks. the test shows a problem
        # with using the graph analyzer on recursive functions that is indepent
        # of the fact that recursive functions always happen to raise
        def g(x):
            return f(x)

        def f(x):
            if x:
                if x % 2:
                    return x
                raise ValueError
            return g(x - 1)
        t, ra = self.translate(f, [int])
        ggraph = graphof(t, g)
        fgraph = graphof(t, f)
        result = ra.can_raise(ggraph.startblock.operations[-1]) # the call to f
        assert result
        result = ra.can_raise(fgraph.startblock.exits[0].target.operations[-1]) # the call to g
        assert result

    def test_recursive_cannot_raise(self):
        # intentionally don't insert stack checks.  The goal is to verify
        # the graph analyzer, which should return "no" on such a recursion.
        def g(x):
            return f(x)

        def f(x):
            if x:
                if x % 2:
                    return x
                return 42
            return g(x - 1)

        t, ra = self.translate(f, [int])
        ggraph = graphof(t, g)
        fgraph = graphof(t, f)
        result = ra.can_raise(ggraph.startblock.operations[-1]) # the call to f
        assert not result
        result = ra.can_raise(fgraph.startblock.exits[0].target.operations[-1]) # the call to g
        assert not result

    def test_can_raise_exception(self):
        def g():
            raise ValueError
        def f():
            return g()
        t, ra = self.translate(f, [])
        fgraph = graphof(t, f)
        result = ra.can_raise(fgraph.startblock.operations[0])
        assert result

    def test_indirect_call(self):
        def g1():
            raise ValueError
        def g2():
            return 2
        def f(x):
            if x:
                g = g1
            else:
                g = g2
            return g()
        def h(x):
            return f(x)
        t, ra = self.translate(h, [int])
        hgraph = graphof(t, h)
        result = ra.can_raise(hgraph.startblock.operations[0])
        assert result

    def test_method(self):
        class A(object):
            def f(self):
                return 1
            def m(self):
                raise ValueError
        class B(A):
            def f(self):
                return 2
            def m(self):
                return 3
        def f(a):
            return a.f()
        def m(a):
            return a.m()
        def h(flag):
            if flag:
                obj = A()
            else:
                obj = B()
            f(obj)
            m(obj)

        t, ra = self.translate(h, [int])
        hgraph = graphof(t, h)
        # fiiiish :-(
        block = hgraph.startblock.exits[0].target.exits[0].target
        op_call_f = block.operations[0]
        op_call_m = block.operations[1]

        # check that we fished the expected ops
        def check_call(op, fname):
            assert op.opname == "direct_call"
            assert op.args[0].value._obj._name == fname
        check_call(op_call_f, "f")
        check_call(op_call_m, "m")

        assert not ra.can_raise(op_call_f)
        assert ra.can_raise(op_call_m)

    def test_method_recursive(self):
        class A:
            def m(self, x):
                if x > 0:
                    return self.m(x-1)
                else:
                    return 42
        def m(a):
            return a.m(2)
        def h():
            obj = A()
            m(obj)
        t, ra = self.translate(h, [])
        hgraph = graphof(t, h)
        # fiiiish :-(
        block = hgraph.startblock
        op_call_m = block.operations[-1]
        assert op_call_m.opname == "direct_call"
        assert not ra.can_raise(op_call_m)

    def test_instantiate(self):
        # instantiate is interesting, because it leads to one of the few cases of
        # an indirect call without a list of graphs
        from rpython.rlib.objectmodel import instantiate
        class A:
            pass
        class B(A):
            pass
        def g(x):
            if x:
                C = A
            else:
                C = B
            a = instantiate(C)
        def f(x):
            return g(x)
        t, ra = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = ra.can_raise(fgraph.startblock.operations[0])
        assert result

    def test_llexternal(self):
        from rpython.rtyper.lltypesystem.rffi import llexternal
        from rpython.rtyper.lltypesystem import lltype
        z = llexternal('z', [lltype.Signed], lltype.Signed)
        def f(x):
            return z(x)
        t, ra = self.translate(f, [int])
        fgraph = graphof(t, f)
        backend_optimizations(t)
        assert fgraph.startblock.operations[0].opname == 'direct_call'

        result = ra.can_raise(fgraph.startblock.operations[0])
        assert not result

        z = llexternal('z', [lltype.Signed], lltype.Signed)
        def g(x):
            return z(x)
        t, ra = self.translate(g, [int])
        ggraph = graphof(t, g)

        assert ggraph.startblock.operations[0].opname == 'direct_call'

        result = ra.can_raise(ggraph.startblock.operations[0])
        assert result

    def test_ll_arraycopy(self):
        from rpython.rtyper.lltypesystem import rffi
        from rpython.rlib.rgc import ll_arraycopy
        def f(a, b, c, d, e):
            ll_arraycopy(a, b, c, d, e)
        t, ra = self.translate(f, [rffi.CCHARP, rffi.CCHARP, int, int, int])
        fgraph = graphof(t, f)
        result = ra.can_raise(fgraph.startblock.operations[0])
        assert not result

    def test_memoryerror(self):
        def f(x):
            return [x, 42]
        t, ra = self.translate(f, [int])
        result = ra.analyze_direct_call(graphof(t, f))
        assert result
        #
        ra = RaiseAnalyzer(t)
        ra.do_ignore_memory_error()
        result = ra.analyze_direct_call(graphof(t, f))
        assert not result
        #
        def g(x):
            try:
                return f(x)
            except:
                raise
        t, ra = self.translate(g, [int])
        ra.do_ignore_memory_error()
        result = ra.analyze_direct_call(graphof(t, g))
        assert not result
        #
        def h(x):
            return {5:6}[x]
        t, ra = self.translate(h, [int])
        ra.do_ignore_memory_error()     # but it's potentially a KeyError
        result = ra.analyze_direct_call(graphof(t, h))
        assert result
