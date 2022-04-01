import py
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem.rstr import STR
from rpython.rtyper.lltypesystem.rlist import LIST_OF
from rpython.translator.translator import TranslationContext, graphof
from rpython.translator.backendopt.writeanalyze import WriteAnalyzer, top_set
from rpython.translator.backendopt.writeanalyze import ReadWriteAnalyzer
from rpython.translator.backendopt.all import backend_optimizations
from rpython.conftest import option


class BaseTest(object):
    Analyzer = WriteAnalyzer

    def translate(self, func, sig):
        t = TranslationContext()
        t.buildannotator().build_types(func, sig)
        t.buildrtyper().specialize()
        if option.view:
            t.view()
        return t, self.Analyzer(t)


class TestWriteAnalyze(BaseTest):

    def test_writes_simple(self):
        def g(x):
            return True

        def f(x):
            return g(x - 1)
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = wa.analyze(fgraph.startblock.operations[0])
        assert not result

    def test_writes_recursive(self):
        from rpython.translator.transform import insert_ll_stackcheck
        def g(x):
            return f(x)

        def f(x):
            if x:
                return g(x - 1)
            return 1
        t, wa = self.translate(f, [int])
        insert_ll_stackcheck(t)
        ggraph = graphof(t, g)
        result = wa.analyze(ggraph.startblock.operations[-1])
        assert not result

    def test_write_to_new_struct(self):
        class A(object):
            pass
        def f(x):
            a = A()
            a.baz = x   # writes to a fresh new struct are ignored
            return a
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = wa.analyze_direct_call(fgraph)
        assert not result

    def test_write_to_new_struct_2(self):
        class A(object):
            pass
        def f(x):
            a = A()
            # a few extra blocks
            i = 10
            while i > 0:
                i -= 1
            # done
            a.baz = x   # writes to a fresh new struct are ignored
            return a
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = wa.analyze_direct_call(fgraph)
        assert not result

    def test_write_to_new_struct_3(self):
        class A(object):
            pass
        prebuilt = A()
        def f(x):
            if x > 5:
                a = A()
            else:
                a = A()
            a.baz = x
            return a
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = wa.analyze_direct_call(fgraph)
        assert not result

    def test_write_to_new_struct_4(self):
        class A(object):
            pass
        prebuilt = A()
        def f(x):
            if x > 5:
                a = A()
            else:
                a = prebuilt
            a.baz = x
            return a
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = wa.analyze_direct_call(fgraph)
        assert len(result) == 1 and 'baz' in list(result)[0][-1]

    def test_write_to_new_struct_5(self):
        class A(object):
            baz = 123
        def f(x):
            if x:
                a = A()
            else:
                a = A()
            a.baz += 1
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = wa.analyze_direct_call(fgraph)
        assert not result

    def test_method(self):
        class A(object):
            def f(self):
                self.x = 1
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

        t, wa = self.translate(h, [int])
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

        result = wa.analyze(op_call_f)
        assert len(result) == 1
        (struct, T, name), = result
        assert struct == "struct"
        assert name.endswith("x")
        assert not wa.analyze(op_call_m)

    def test_instantiate(self):
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
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = wa.analyze(fgraph.startblock.operations[0])
        assert not result

    def test_llexternal(self):
        from rpython.rtyper.lltypesystem.rffi import llexternal
        z = llexternal('z', [lltype.Signed], lltype.Signed)
        def f(x):
            return z(x)
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        backend_optimizations(t)
        assert fgraph.startblock.operations[0].opname == 'direct_call'

        result = wa.analyze(fgraph.startblock.operations[0])
        assert not result

    def test_contains(self):
        def g(x, y, z):
            l = [x]
            return f(l, y, z)
        def f(x, y, z):
            return y in x


        t, wa = self.translate(g, [int, int, int])
        ggraph = graphof(t, g)
        assert ggraph.startblock.operations[-1].opname == 'direct_call'

        result = wa.analyze(ggraph.startblock.operations[-1])
        assert not result

    def test_list(self):
        def g(x, y, z):
            return f(x, y, z)
        def f(x, y, z):
            l = [0] * x
            l.append(y)
            return len(l) + z


        t, wa = self.translate(g, [int, int, int])
        ggraph = graphof(t, g)
        assert ggraph.startblock.operations[0].opname == 'direct_call'

        result = sorted(wa.analyze(ggraph.startblock.operations[0]))
        array, A = result[0]
        assert array == "array"
        assert A.TO.OF == lltype.Signed

        struct, S1, name = result[1]
        assert struct == "struct"
        assert S1.TO.items == A
        assert S1.TO.length == lltype.Signed
        assert name == "items"

        struct, S2, name = result[2]
        assert struct == "struct"
        assert name == "length"
        assert S1 is S2

    def test_llexternal_with_callback(self):
        from rpython.rtyper.lltypesystem.rffi import llexternal
        from rpython.rtyper.lltypesystem import lltype

        class Abc:
            pass
        abc = Abc()

        FUNC = lltype.FuncType([lltype.Signed], lltype.Signed)
        z = llexternal('z', [lltype.Ptr(FUNC)], lltype.Signed)
        def g(n):
            abc.foobar = n
            return n + 1
        def f(x):
            return z(g)
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        backend_optimizations(t)
        assert fgraph.startblock.operations[0].opname == 'direct_call'

        result = wa.analyze(fgraph.startblock.operations[0])
        assert len(result) == 1
        (struct, T, name), = result
        assert struct == "struct"
        assert name.endswith("foobar")


class TestLLtypeReadWriteAnalyze(BaseTest):
    Analyzer = ReadWriteAnalyzer

    def test_read_simple(self):
        def g(x):
            return True

        def f(x):
            return g(x - 1)
        t, wa = self.translate(f, [int])
        fgraph = graphof(t, f)
        result = wa.analyze(fgraph.startblock.operations[0])
        assert not result

    def test_read_really(self):
        class A(object):
            def __init__(self, y):
                self.y = y
            def f(self):
                self.x = 1
                return self.y
        def h(flag):
            obj = A(flag)
            return obj.f()

        t, wa = self.translate(h, [int])
        hgraph = graphof(t, h)
        op_call_f = hgraph.startblock.operations[-1]

        # check that we fished the expected ops
        assert op_call_f.opname == "direct_call"
        assert op_call_f.args[0].value._obj._name == 'A.f'

        result = wa.analyze(op_call_f)
        assert len(result) == 2
        result = list(result)
        result.sort()
        [(struct1, T1, name1), (struct2, T2, name2)] = result
        assert struct1 == "readstruct"
        assert name1.endswith("y")
        assert struct2 == "struct"
        assert name2.endswith("x")
        assert T1 == T2

    def test_cutoff(self):
        py.test.skip("cutoff: disabled")
        from rpython.rlib.unroll import unrolling_iterable
        cutoff = 20
        attrs = unrolling_iterable(["s%s" % i for i in range(cutoff + 5)])

        class A(object):
            def __init__(self, y):
                for attr in attrs:
                    setattr(self, attr, y)
            def f(self):
                self.x = 1
                res = 0
                for attr in attrs:
                    res += getattr(self, attr)
                return res

        def h(flag):
            obj = A(flag)
            return obj.f()

        t, wa = self.translate(h, [int])
        wa.cutoff = cutoff
        hgraph = graphof(t, h)
        op_call_f = hgraph.startblock.operations[-1]

        # check that we fished the expected ops
        assert op_call_f.opname == "direct_call"
        assert op_call_f.args[0].value._obj._name == 'A.f'

        result = wa.analyze(op_call_f)
        assert result is top_set

    def test_contains(self):
        def g(x, y, z):
            l = [x]
            return f(l, y, z)
        def f(x, y, z):
            return y in x

        t, wa = self.translate(g, [int, int, int])
        ggraph = graphof(t, g)
        assert ggraph.startblock.operations[-1].opname == 'direct_call'

        result = wa.analyze(ggraph.startblock.operations[-1])
        ARRAYPTR = list(result)[0][1]
        assert list(result) == [("readarray", ARRAYPTR)]
        assert isinstance(ARRAYPTR.TO, lltype.GcArray)

    def test_adt_method(self):
        def ll_callme(n):
            return n
        ll_callme = lltype.staticAdtMethod(ll_callme)
        S = lltype.GcStruct('S', ('x', lltype.Signed),
                            adtmeths = {'yep': True,
                                        'callme': ll_callme})
        def g(p, x, y, z):
            p.x = x
            if p.yep:
                z *= p.callme(y)
            return z
        def f(x, y, z):
            p = lltype.malloc(S)
            return g(p, x, y, z)

        t, wa = self.translate(f, [int, int, int])
        fgraph = graphof(t, f)
        assert fgraph.startblock.operations[-1].opname == 'direct_call'

        result = wa.analyze(fgraph.startblock.operations[-1])
        assert list(result) == [("struct", lltype.Ptr(S), "x")]

    def test_interiorfield(self):
        A = lltype.GcArray(lltype.Struct('x', ('x', lltype.Signed),
                                         ('y', lltype.Signed)))

        def g(x):
            a = lltype.malloc(A, 1)
            a[0].y = 3
            return f(a, x)

        def f(a, x):
            a[0].x = x
            return a[0].y

        t, wa = self.translate(g, [int])
        ggraph = graphof(t, g)
        result = wa.analyze(ggraph.startblock.operations[-1])
        res = list(result)
        assert ('readinteriorfield', lltype.Ptr(A), 'y') in res
        assert ('interiorfield', lltype.Ptr(A), 'x') in res


class TestGcLoadStoreIndexed(BaseTest):
    Analyzer = ReadWriteAnalyzer

    def _analyze_graph(self, t, wa, fn):
        graph = graphof(t, fn)
        result = wa.analyze(graph.startblock.operations[-1])
        return result

    def _filter_reads(self, effects):
        result = [item for item in effects if not item[0].startswith('read')]
        return frozenset(result)

    def test_gc_load_indexed_str(self):
        from rpython.rlib.buffer import StringBuffer

        def typed_read(buf):
            return buf.typed_read(lltype.Signed, 0)

        def direct_read(buf):
            return buf.value[0]

        def f(x):
            buf = StringBuffer(x)
            return direct_read(buf), typed_read(buf)

        t, wa = self.translate(f, [str])
        # check that the effect of direct_read
        direct_effects = self._analyze_graph(t, wa, direct_read)
        assert direct_effects == frozenset([
            ('readinteriorfield', lltype.Ptr(STR), 'chars')
        ])
        #
        # typed_read contains many effects because it reads the vtable etc.,
        # but we want to check that it contains also the same effect as
        # direct_read
        typed_effects = self._analyze_graph(t, wa, typed_read)
        assert direct_effects.issubset(typed_effects)

    def test_gc_load_indexed_list_of_chars(self):
        from rpython.rlib.buffer import ByteBuffer

        def typed_read(buf):
            return buf.typed_read(lltype.Signed, 0)

        def direct_read(buf):
            return buf.data[0]

        def f(x):
            buf = ByteBuffer(8)
            return direct_read(buf), typed_read(buf)

        t, wa = self.translate(f, [str])
        # check that the effect of direct_read
        LIST = LIST_OF(lltype.Char)
        PLIST = lltype.Ptr(LIST)
        direct_effects = self._analyze_graph(t, wa, direct_read)
        assert direct_effects == frozenset([
            ('readstruct', PLIST, 'length'),
            ('readstruct', PLIST, 'items'),
            ('readarray', LIST.items),
        ])

        # typed_read contains many effects because it reads the vtable etc.,
        # but we want to check that it contains also the expected effects
        typed_effects = self._analyze_graph(t, wa, typed_read)
        expected = frozenset([
            ('readstruct', PLIST, 'items'),
            ('readarray', LIST.items),
        ])
        assert expected.issubset(typed_effects)

    def test_gc_store_indexed_str(self):
        from rpython.rlib.mutbuffer import MutableStringBuffer

        def typed_write(buf):
            return buf.typed_write(lltype.Signed, 0, 42)

        def direct_write(buf):
            return buf.setitem(0, 'A')

        def f(x):
            buf = MutableStringBuffer(8)
            return direct_write(buf), typed_write(buf)

        t, wa = self.translate(f, [str])
        # check that the effect of direct_write
        direct_effects = self._analyze_graph(t, wa, direct_write)
        direct_effects = self._filter_reads(direct_effects)
        assert direct_effects == frozenset([
            ('interiorfield', lltype.Ptr(STR), 'chars')
        ])
        #
        typed_effects = self._analyze_graph(t, wa, typed_write)
        typed_effects = self._filter_reads(typed_effects)
        assert typed_effects == direct_effects

    def test_gc_store_indexed_list_of_chars(self):
        from rpython.rlib.buffer import ByteBuffer

        def typed_write(buf):
            return buf.typed_write(lltype.Signed, 0, 42)

        def direct_write(buf):
            return buf.setitem(0, 'A')

        def f(x):
            buf = ByteBuffer(8)
            return direct_write(buf), typed_write(buf)

        t, wa = self.translate(f, [str])
        # check that the effect of direct_write
        LIST = LIST_OF(lltype.Char)
        direct_effects = self._analyze_graph(t, wa, direct_write)
        direct_effects = self._filter_reads(direct_effects)
        assert direct_effects == frozenset([
            ('array', LIST.items),
        ])
        #
        typed_effects = self._analyze_graph(t, wa, typed_write)
        typed_effects = self._filter_reads(typed_effects)
        assert typed_effects == direct_effects

    def test_explanation(self):
        class A(object):
            def methodname(self):
                self.x = 1
                return 1
            def m(self):
                raise ValueError
        class B(A):
            def methodname(self):
                return 2
            def m(self):
                return 3
        def fancyname(a):
            return a.methodname()
        def m(a):
            return a.m()
        def h(flag):
            if flag:
                obj = A()
            else:
                obj = B()
            fancyname(obj)
            m(obj)

        t, wa = self.translate(h, [int])
        hgraph = graphof(t, h)
        # fiiiish :-(
        block = hgraph.startblock.exits[0].target.exits[0].target
        op_call_fancyname = block.operations[0]

        explanation = wa.explain_analyze_slowly(op_call_fancyname)
        assert "fancyname" in explanation[0]
        assert "methodname" in explanation[1]
