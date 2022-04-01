import py
from rpython.memory.gctypelayout import TypeLayoutBuilder, GCData
from rpython.memory.gctypelayout import offsets_to_gc_pointers
from rpython.memory.gctypelayout import gc_pointers_inside
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper import rclass
from rpython.rtyper.rclass import IR_IMMUTABLE, IR_QUASIIMMUTABLE
from rpython.rtyper.test.test_llinterp import get_interpreter
from rpython.flowspace.model import Constant

class FakeGC:
    object_minimal_size = 0

def getname(T):
    try:
        return "field:" + T._name
    except:
        return "field:" + T.__name__

S = lltype.Struct('S', ('s', lltype.Signed), ('char', lltype.Char))
GC_S = lltype.GcStruct('GC_S', ('S', S))

A = lltype.Array(S)
GC_A = lltype.GcArray(S)

S2 = lltype.Struct('SPTRS',
                   *[(getname(TYPE), lltype.Ptr(TYPE)) for TYPE in (GC_S, GC_A)])
GC_S2 = lltype.GcStruct('GC_S2', ('S2', S2))

A2 = lltype.Array(S2)
GC_A2 = lltype.GcArray(S2)

l = [(getname(TYPE), lltype.Ptr(TYPE)) for TYPE in (GC_S, GC_A)]
l.append(('vararray', A2))

GC_S3 = lltype.GcStruct('GC_S3', *l)

def test_struct():
    for T, c in [(GC_S, 0), (GC_S2, 2), (GC_A, 0), (GC_A2, 0), (GC_S3, 2)]:
        assert len(offsets_to_gc_pointers(T)) == c

def test_layout_builder(lltype2vtable=None):
    # XXX a very minimal test
    layoutbuilder = TypeLayoutBuilder(FakeGC, lltype2vtable)
    for T1, T2 in [(GC_A, GC_S), (GC_A2, GC_S2), (GC_S3, GC_S2)]:
        tid1 = layoutbuilder.get_type_id(T1)
        tid2 = layoutbuilder.get_type_id(T2)
        gcdata = GCData(layoutbuilder.type_info_group)
        lst1 = gcdata.q_varsize_offsets_to_gcpointers_in_var_part(tid1)
        lst2 = gcdata.q_offsets_to_gc_pointers(tid2)
        assert len(lst1) == len(lst2)
    return layoutbuilder

def test_layout_builder_with_vtable():
    from rpython.rtyper.lltypesystem.lloperation import llop
    vtable = lltype.malloc(rclass.OBJECT_VTABLE, immortal=True)
    layoutbuilder = test_layout_builder({GC_S: vtable})
    tid1 = layoutbuilder.get_type_id(GC_S)
    tid2 = layoutbuilder.get_type_id(GC_S2)
    tid3 = layoutbuilder.get_type_id(GC_S3)
    group = layoutbuilder.type_info_group
    vt = llop.get_next_group_member(rclass.CLASSTYPE, group._as_ptr(), tid1,
                                    layoutbuilder.size_of_fixed_type_info)
    assert vt == vtable
    for tid in [tid2, tid3]:
        py.test.raises((lltype.InvalidCast, AssertionError),
                       llop.get_next_group_member,
                       rclass.CLASSTYPE, group._as_ptr(), tid,
                       layoutbuilder.size_of_fixed_type_info)

def test_constfold():
    layoutbuilder = TypeLayoutBuilder(FakeGC)
    tid1 = layoutbuilder.get_type_id(GC_A)
    tid2 = layoutbuilder.get_type_id(GC_S3)
    class MockGC:
        def set_query_functions(self, is_varsize,
                                has_gcptr_in_varsize,
                                is_gcarrayofgcptr,
                                *rest):
            self.is_varsize = is_varsize
            self.has_gcptr_in_varsize = has_gcptr_in_varsize
            self.is_gcarrayofgcptr = is_gcarrayofgcptr
    gc = MockGC()
    layoutbuilder.initialize_gc_query_function(gc)
    #
    def f():
        return (1 * gc.is_varsize(tid1) +
               10 * gc.has_gcptr_in_varsize(tid1) +
              100 * gc.is_gcarrayofgcptr(tid1) +
             1000 * gc.is_varsize(tid2) +
            10000 * gc.has_gcptr_in_varsize(tid2) +
           100000 * gc.is_gcarrayofgcptr(tid2))
    interp, graph = get_interpreter(f, [], backendopt=True)
    assert interp.eval_graph(graph, []) == 11001
    assert graph.startblock.exits[0].args == [Constant(11001, lltype.Signed)]

def test_gc_pointers_inside():
    from rpython.rtyper import rclass
    PT = lltype.Ptr(lltype.GcStruct('T'))
    S1 = lltype.GcStruct('S', ('x', PT), ('y', PT))
    S2 = lltype.GcStruct('S', ('x', PT), ('y', PT),
                         hints={'immutable': True})
    accessor = rclass.FieldListAccessor()
    S3 = lltype.GcStruct('S', ('x', PT), ('y', PT),
                         hints={'immutable_fields': accessor})
    accessor.initialize(S3, {'x': IR_IMMUTABLE, 'y': IR_QUASIIMMUTABLE})
    #
    s1 = lltype.malloc(S1)
    adr = llmemory.cast_ptr_to_adr(s1)
    lst = list(gc_pointers_inside(s1._obj, adr, mutable_only=True))
    expected = [adr + llmemory.offsetof(S1, 'x'),
                adr + llmemory.offsetof(S1, 'y')]
    assert lst == expected or lst == expected[::-1]
    #
    s2 = lltype.malloc(S2)
    adr = llmemory.cast_ptr_to_adr(s2)
    lst = list(gc_pointers_inside(s2._obj, adr, mutable_only=True))
    assert lst == []
    #
    s3 = lltype.malloc(S3)
    adr = llmemory.cast_ptr_to_adr(s3)
    lst = list(gc_pointers_inside(s3._obj, adr, mutable_only=True))
    assert lst == [adr + llmemory.offsetof(S3, 'y')]
