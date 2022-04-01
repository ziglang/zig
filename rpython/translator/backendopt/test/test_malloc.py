import py
from rpython.translator.backendopt.malloc import LLTypeMallocRemover
from rpython.translator.backendopt.all import backend_optimizations
from rpython.translator.translator import TranslationContext, graphof
from rpython.translator import simplify
from rpython.flowspace.model import checkgraph, Block, mkentrymap
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rlib import objectmodel
from rpython.conftest import option

class TestMallocRemoval(object):
    MallocRemover = LLTypeMallocRemover

    def check_malloc_removed(cls, graph):
        remover = cls.MallocRemover()
        checkgraph(graph)
        count1 = count2 = 0
        for node in graph.iterblocks():
                for op in node.operations:
                    if op.opname == cls.MallocRemover.MALLOC_OP:
                        S = op.args[0].value
                        if not remover.union_wrapper(S):   # union wrappers are fine
                            count1 += 1
                    if op.opname in ('direct_call', 'indirect_call'):
                        count2 += 1
        assert count1 == 0   # number of mallocs left
        assert count2 == 0   # number of calls left
    check_malloc_removed = classmethod(check_malloc_removed)

    def check(self, fn, signature, args, expected_result, must_be_removed=True,
              inline=None):
        remover = self.MallocRemover()
        t = TranslationContext()
        t.buildannotator().build_types(fn, signature)
        t.buildrtyper().specialize()
        graph = graphof(t, fn)
        if inline is not None:
            from rpython.translator.backendopt.inline import auto_inline_graphs
            auto_inline_graphs(t, t.graphs, inline)
        if option.view:
            t.view()
        # to detect broken intermediate graphs,
        # we do the loop ourselves instead of calling remove_simple_mallocs()
        while True:
            progress = remover.remove_mallocs_once(graph)
            simplify.transform_dead_op_vars_in_blocks(list(graph.iterblocks()),
                                                      [graph])
            if progress and option.view:
                t.view()
            if expected_result is not Ellipsis:
                interp = LLInterpreter(t.rtyper)
                res = interp.eval_graph(graph, args)
                assert res == expected_result
            if not progress:
                break
        if must_be_removed:
            self.check_malloc_removed(graph)
        return graph

    def test_fn1(self):
        def fn1(x, y):
            if x > 0:
                t = x+y, x-y
            else:
                t = x-y, x+y
            s, d = t
            return s*d
        self.check(fn1, [int, int], [15, 10], 125)

    def test_fn2(self):
        class T:
            pass
        def fn2(x, y):
            t = T()
            t.x = x
            t.y = y
            if x > 0:
                return t.x + t.y
            else:
                return t.x - t.y
        self.check(fn2, [int, int], [-6, 7], -13)

    def test_fn3(self):
        def fn3(x):
            a, ((b, c), d, e) = x+1, ((x+2, x+3), x+4, x+5)
            return a+b+c+d+e
        self.check(fn3, [int], [10], 65)

    def test_fn4(self):
        class A:
            pass
        class B(A):
            pass
        def fn4(i):
            a = A()
            b = B()
            a.b = b
            b.i = i
            return a.b.i
        self.check(fn4, [int], [42], 42)

    def test_fn5(self):
        class A:
            attr = 666
        class B(A):
            attr = 42
        def fn5():
            b = B()
            return b.attr
        self.check(fn5, [], [], 42)

    def test_aliasing(self):
        class A:
            pass
        def fn6(n):
            a1 = A()
            a1.x = 5
            a2 = A()
            a2.x = 6
            if n > 0:
                a = a1
            else:
                a = a2
            a.x = 12
            return a1.x
        self.check(fn6, [int], [1], 12, must_be_removed=False)

    def test_bogus_cast_pointer(self):
        class S:
            pass
        class T(S):
            def f(self):
                self.y += 1
        def f(x):
            T().y = 5
            s = S()
            s.x = 123
            if x < 0:
                s.f()
            return s.x
        graph = self.check(f, [int], [5], 123, inline=20)
        found_operations = {}
        for block in graph.iterblocks():
            for op in block.operations:
                found_operations[op.opname] = True
        assert 'debug_fatalerror' in found_operations



    def test_dont_remove_with__del__(self):
        import os
        delcalls = [0]
        class A(object):
            nextid = 0
            def __init__(self):
                self.id = self.nextid
                self.nextid += 1

            def __del__(self):
                delcalls[0] += 1
                #os.write(1, "__del__\n")

        def f(x=int):
            a = A()
            i = 0
            while i < x:
                a = A()
                os.write(1, str(delcalls[0]) + "\n")
                i += 1
            return 1
        t = TranslationContext()
        t.buildannotator().build_types(f, [int])
        t.buildrtyper().specialize()
        graph = graphof(t, f)
        backend_optimizations(t)
        op = graph.startblock.exits[0].target.exits[1].target.operations[0]
        assert op.opname == "malloc"

    def test_wrapper_cannot_be_removed(self):
        SMALL = lltype.OpaqueType('SMALL')
        BIG = lltype.GcStruct('BIG', ('z', lltype.Signed), ('s', SMALL))

        def g(small):
            return -1
        def fn():
            b = lltype.malloc(BIG)
            g(b.s)

        self.check(fn, [], [], None, must_be_removed=False)

    def test_direct_fieldptr(self):
        S = lltype.GcStruct('S', ('x', lltype.Signed))

        def fn():
            s = lltype.malloc(S)
            s.x = 11
            p = lltype.direct_fieldptr(s, 'x')
            return p[0]

        self.check(fn, [], [], 11)

    def test_direct_fieldptr_2(self):
        T = lltype.GcStruct('T', ('z', lltype.Signed))
        S = lltype.GcStruct('S', ('t', T),
                                 ('x', lltype.Signed),
                                 ('y', lltype.Signed))
        def fn():
            s = lltype.malloc(S)
            s.x = 10
            s.t.z = 1
            px = lltype.direct_fieldptr(s, 'x')
            py = lltype.direct_fieldptr(s, 'y')
            pz = lltype.direct_fieldptr(s.t, 'z')
            py[0] = 31
            return px[0] + s.y + pz[0]

        self.check(fn, [], [], 42)

    def test_getarraysubstruct(self):
        py.test.skip("fails because of the interior structure changes")
        U = lltype.Struct('U', ('n', lltype.Signed))
        for length in [1, 2]:
            S = lltype.GcStruct('S', ('a', lltype.FixedSizeArray(U, length)))
            for index in range(length):

                def fn():
                    s = lltype.malloc(S)
                    s.a[index].n = 12
                    return s.a[index].n
                self.check(fn, [], [], 12)

    def test_ptr_nonzero(self):
        S = lltype.GcStruct('S')
        def fn():
            s = lltype.malloc(S)
            return bool(s)
        self.check(fn, [], [], True)

    def test_substruct_not_accessed(self):
        SMALL = lltype.Struct('SMALL', ('x', lltype.Signed))
        BIG = lltype.GcStruct('BIG', ('z', lltype.Signed), ('s', SMALL))
        def fn():
            x = lltype.malloc(BIG)
            while x.z < 10:    # makes several blocks
                x.z += 3
            return x.z
        self.check(fn, [], [], 12)

    def test_union(self):
        py.test.skip("fails because of the interior structure changes")
        UNION = lltype.Struct('UNION', ('a', lltype.Signed), ('b', lltype.Signed),
                              hints = {'union': True})
        BIG = lltype.GcStruct('BIG', ('u1', UNION), ('u2', UNION))
        def fn():
            x = lltype.malloc(BIG)
            x.u1.a = 3
            x.u2.b = 6
            return x.u1.b * x.u2.a
        self.check(fn, [], [], Ellipsis)

    def test_keep_all_keepalives(self):
        SIZE = llmemory.sizeof(lltype.Signed)
        PARRAY = lltype.Ptr(lltype.FixedSizeArray(lltype.Signed, 1))
        class A:
            def __init__(self):
                self.addr = llmemory.raw_malloc(SIZE)
            def __del__(self):
                llmemory.raw_free(self.addr)
        class B:
            pass
        def myfunc():
            b = B()
            b.keep = A()
            b.data = llmemory.cast_adr_to_ptr(b.keep.addr, PARRAY)
            b.data[0] = 42
            ptr = b.data
            # normally 'b' could go away as early as here, which would free
            # the memory held by the instance of A in b.keep...
            res = ptr[0]
            # ...so we explicitly keep 'b' alive until here
            objectmodel.keepalive_until_here(b)
            return res
        graph = self.check(myfunc, [], [], 42,
                           must_be_removed=False)    # 'A' instance left

        # there is a getarrayitem near the end of the graph of myfunc.
        # However, the memory it accesses must still be protected by the
        # following keepalive, even after malloc removal
        entrymap = mkentrymap(graph)
        [link] = entrymap[graph.returnblock]
        assert link.prevblock.operations[-1].opname == 'keepalive'

    def test_nested_struct(self):
        S = lltype.GcStruct("S", ('x', lltype.Signed))
        T = lltype.GcStruct("T", ('s', S))
        def f(x):
            t = lltype.malloc(T)
            s = t.s
            if x:
                s.x = x
            return t.s.x + s.x
        graph = self.check(f, [int], [42], 2 * 42)

    def test_interior_ptr(self):
        py.test.skip("fails")
        S = lltype.Struct("S", ('x', lltype.Signed))
        T = lltype.GcStruct("T", ('s', S))
        def f(x):
            t = lltype.malloc(T)
            t.s.x = x
            return t.s.x
        graph = self.check(f, [int], [42], 42)

    def test_interior_ptr_with_index(self):
        S = lltype.Struct("S", ('x', lltype.Signed))
        T = lltype.GcArray(S)
        def f(x):
            t = lltype.malloc(T, 1)
            t[0].x = x
            return t[0].x
        graph = self.check(f, [int], [42], 42)

    def test_interior_ptr_with_field_and_index(self):
        S = lltype.Struct("S", ('x', lltype.Signed))
        T = lltype.GcStruct("T", ('items', lltype.Array(S)))
        def f(x):
            t = lltype.malloc(T, 1)
            t.items[0].x = x
            return t.items[0].x
        graph = self.check(f, [int], [42], 42)

    def test_interior_ptr_with_index_and_field(self):
        S = lltype.Struct("S", ('x', lltype.Signed))
        T = lltype.Struct("T", ('s', S))
        U = lltype.GcArray(T)
        def f(x):
            u = lltype.malloc(U, 1)
            u[0].s.x = x
            return u[0].s.x
        graph = self.check(f, [int], [42], 42)

    def test_two_paths_one_with_constant(self):
        py.test.skip("XXX implement me?")
        def fn(n):
            if n > 100:
                tup = (0,)
            else:
                tup = (n,)
            (n,)    # <- flowspace
            return tup[0]

        self.check(fn, [int], [42], 42)
