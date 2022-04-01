import py
from rpython.memory.gctransform.test.test_transform import rtype, rtype_and_transform, getops
from rpython.memory.gctransform.test.test_transform import LLInterpedTranformerTests
from rpython.memory.gctransform.refcounting import RefcountingGCTransformer
from rpython.rtyper.lltypesystem import lltype
from rpython.translator.translator import TranslationContext, graphof
from rpython.translator.c.gc import RefcountingGcPolicy
from rpython.conftest import option

class TestLLInterpedRefcounting(LLInterpedTranformerTests):
    gcpolicy = RefcountingGcPolicy

    def test_llinterp_refcounted_graph_with_del(self):
        from rpython.annotator.model import SomeInteger

        class D:
            pass

        delcounter = D()
        delcounter.dels = 0

        class C:
            def __del__(self):
                delcounter.dels += 1
        c = C()
        c.x = 1
        def h(x):
            if x:
                return c
            else:
                d = C()
                d.x = 2
                return d
        def g(x):
            return h(x).x
        def f(x):
            r = g(x)
            return r + delcounter.dels

        llinterp, graph = self.llinterpreter_for_transformed_graph(f, [SomeInteger()])

        res = llinterp.eval_graph(graph, [1])
        assert res == 1
        res = llinterp.eval_graph(graph, [0])
        assert res == 3

    def test_raw_instance_flavor(self):
        # crashes for now because X() is not initialized with zeroes when
        # it is allocated, but it's probably illegal to try to store
        # references into a raw-malloced instance
        py.test.skip("a probably-illegal test")
        class State:
            pass
        state = State()
        class Y:
            def __del__(self):
                state.freed_counter += 1
        class X:
            _alloc_flavor_ = 'raw'
        def g():
            x = X()
            x.y = Y()
            return x
        def f():
            from rpython.rlib.objectmodel import free_non_gc_object
            state.freed_counter = 0
            x = g()
            assert state.freed_counter == 0
            x.y = None
            assert state.freed_counter == 1
            free_non_gc_object(x)
            # for now we have no automatic decref when free_non_gc_object() is
            # called
        llinterp, graph = self.llinterpreter_for_transformed_graph(f, [])
        llinterp.eval_graph(graph, [])

def test_simple_barrier():
    S = lltype.GcStruct("S", ('x', lltype.Signed))
    T = lltype.GcStruct("T", ('s', lltype.Ptr(S)))
    def f():
        s1 = lltype.malloc(S)
        s1.x = 1
        s2 = lltype.malloc(S)
        s2.x = 2
        t = lltype.malloc(T)
        t.s = s1
        t.s = s2
        return t
    t, transformer = rtype_and_transform(f, [], RefcountingGCTransformer,
                                         check=False)
    graph = graphof(t, f)
    ops = getops(graph)
    assert len(ops['getfield']) == 2
    assert len(ops['bare_setfield']) == 4

def test_arraybarrier():
    S = lltype.GcStruct("S", ('x', lltype.Signed))
    A = lltype.GcArray(lltype.Ptr(S))
    def f():
        s1 = lltype.malloc(S)
        s1.x = 1
        s2 = lltype.malloc(S)
        s2.x = 2
        a = lltype.malloc(A, 1)
        a[0] = s1
        a[0] = s2
    t, transformer = rtype_and_transform(f, [], RefcountingGCTransformer,
                                         check=False)
    graph = graphof(t, f)
    ops = getops(graph)
    assert len(ops['getarrayitem']) == 2
    assert len(ops['bare_setarrayitem']) == 2
    assert len(ops['bare_setfield']) == 2

def make_deallocator(TYPE,
                     attr="static_deallocation_funcptr_for_type",
                     cls=RefcountingGCTransformer):
    if TYPE._is_varsize():
        def f():
            return lltype.malloc(TYPE, 1)
    else:
        def f():
            return lltype.malloc(TYPE)
    t = TranslationContext()
    t.buildannotator().build_types(f, [])
    t.buildrtyper().specialize()
    transformer = cls(t)
    fptr = getattr(transformer, attr)(TYPE)
    transformer.transform_graph(graphof(t, f))
    transformer.finish(backendopt=False)
    if option.view:
        t.view()
    if fptr:
        return fptr._obj.graph, t
    else:
        return None, t

def test_deallocator_simple():
    S = lltype.GcStruct("S", ('x', lltype.Signed))
    dgraph, t = make_deallocator(S)
    ops = []
    for block in dgraph.iterblocks():
        ops.extend([op for op in block.operations if op.opname != 'same_as']) # XXX
    assert len(ops) == 1
    op = ops[0]
    assert op.opname == 'gc_free'

def test_deallocator_less_simple():
    TPtr = lltype.Ptr(lltype.GcStruct("T", ('a', lltype.Signed)))
    S = lltype.GcStruct(
        "S",
        ('x', lltype.Signed),
        ('y', TPtr),
        ('z', TPtr),
        )
    dgraph, t = make_deallocator(S)
    ops = getops(dgraph)
    assert len(ops['direct_call']) == 2
    assert len(ops['getfield']) == 2
    assert len(ops['gc_free']) == 1

def test_deallocator_array():
    TPtr = lltype.Ptr(lltype.GcStruct("T", ('a', lltype.Signed)))
    GcA = lltype.GcArray(('x', TPtr), ('y', TPtr))
    A = lltype.Array(('x', TPtr), ('y', TPtr))
    APtr = lltype.Ptr(GcA)
    S = lltype.GcStruct('S', ('t', TPtr), ('x', lltype.Signed), ('aptr', APtr),
                             ('rest', A))
    dgraph, t = make_deallocator(S)
    ops = getops(dgraph)
    assert len(ops['direct_call']) == 4
    assert len(ops['getfield']) == 2
    assert len(ops['getinteriorfield']) == 2
    assert len(ops['getinteriorarraysize']) == 1
    assert len(ops['gc_free']) == 1

def test_deallocator_with_destructor():
    S = lltype.GcStruct("S", ('x', lltype.Signed), rtti=True)
    def f(s):
        s.x = 1
    def type_info_S(p):
        return lltype.getRuntimeTypeInfo(S)
    qp = lltype.functionptr(lltype.FuncType([lltype.Ptr(S)],
                                            lltype.Ptr(lltype.RuntimeTypeInfo)),
                            "type_info_S",
                            _callable=type_info_S)
    dp = lltype.functionptr(lltype.FuncType([lltype.Ptr(S)],
                                            lltype.Void),
                            "destructor_funcptr",
                            _callable=f)
    pinf = lltype.attachRuntimeTypeInfo(S, qp, destrptr=dp)
    graph, t = make_deallocator(S)

def test_caching_dynamic_deallocator():
    S = lltype.GcStruct("S", ('x', lltype.Signed), rtti=True)
    S1 = lltype.GcStruct("S1", ('s', S), ('y', lltype.Signed), rtti=True)
    T = lltype.GcStruct("T", ('x', lltype.Signed), rtti=True)
    def f_S(s):
        s.x = 1
    def f_S1(s1):
        s1.s.x = 1
        s1.y = 2
    def f_T(s):
        s.x = 1
    def type_info_S(p):
        return lltype.getRuntimeTypeInfo(S)
    def type_info_T(p):
        return lltype.getRuntimeTypeInfo(T)
    qp = lltype.functionptr(lltype.FuncType([lltype.Ptr(S)],
                                            lltype.Ptr(lltype.RuntimeTypeInfo)),
                            "type_info_S",
                            _callable=type_info_S)
    dp = lltype.functionptr(lltype.FuncType([lltype.Ptr(S)],
                                            lltype.Void),
                            "destructor_funcptr",
                            _callable=f_S)
    pinf = lltype.attachRuntimeTypeInfo(S, qp, destrptr=dp)
    dp = lltype.functionptr(lltype.FuncType([lltype.Ptr(S)],
                                            lltype.Void),
                            "destructor_funcptr",
                            _callable=f_S1)
    pinf = lltype.attachRuntimeTypeInfo(S1, qp, destrptr=dp)
    qp = lltype.functionptr(lltype.FuncType([lltype.Ptr(T)],
                                            lltype.Ptr(lltype.RuntimeTypeInfo)),
                            "type_info_S",
                            _callable=type_info_T)
    dp = lltype.functionptr(lltype.FuncType([lltype.Ptr(T)],
                                            lltype.Void),
                            "destructor_funcptr",
                            _callable=f_T)
    pinf = lltype.attachRuntimeTypeInfo(T, qp, destrptr=dp)
    def f():
        pass
    t = TranslationContext()
    t.buildannotator().build_types(f, [])
    t.buildrtyper().specialize()
    transformer = RefcountingGCTransformer(t)
    p_S = transformer.dynamic_deallocation_funcptr_for_type(S)
    p_S1 = transformer.dynamic_deallocation_funcptr_for_type(S1)
    p_T = transformer.dynamic_deallocation_funcptr_for_type(T)
    assert p_S is not p_T
    assert p_S is p_S1

def test_dynamic_deallocator():
    class A(object):
        pass
    class B(A):
        pass
    def f(x):
        a = A()
        a.x = 1
        b = B()
        b.x = 2
        b.y = 3
        if x:
            c = a
        else:
            c = b
        return c.x
    t, transformer = rtype_and_transform(
        f, [int], RefcountingGCTransformer, check=False)
    fgraph = graphof(t, f)
    s_instance = t.annotator.bookkeeper.valueoftype(A)
    TYPE = t.rtyper.getrepr(s_instance).lowleveltype.TO
    p = transformer.dynamic_deallocation_funcptr_for_type(TYPE)
    t.rtyper.specialize_more_blocks()

def test_recursive_structure():
    F = lltype.GcForwardReference()
    S = lltype.GcStruct('abc', ('x', lltype.Ptr(F)))
    F.become(S)
    def f():
        s1 = lltype.malloc(S)
        s2 = lltype.malloc(S)
        s1.x = s2
    t, transformer = rtype_and_transform(
        f, [], RefcountingGCTransformer, check=False)

def test_dont_decref_nongc_pointers():
    S = lltype.GcStruct('S',
                        ('x', lltype.Ptr(lltype.Struct('T', ('x', lltype.Signed)))),
                        ('y', lltype.Ptr(lltype.GcStruct('Y', ('x', lltype.Signed))))
                        )
    def f():
        pass
    graph, t = make_deallocator(S)
    ops = getops(graph)
    assert len(ops['direct_call']) == 1
