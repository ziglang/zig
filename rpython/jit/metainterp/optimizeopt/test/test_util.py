import pytest
import random
import string

from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper import rclass
from rpython.rtyper.rclass import (
    OBJECT, OBJECT_VTABLE, FieldListAccessor, IR_QUASIIMMUTABLE)
from rpython.rlib.rjitlog import rjitlog as jl

from rpython.jit.backend.llgraph import runner
from rpython.jit.metainterp.history import (
    TreeLoop, AbstractDescr, JitCellToken)
from rpython.jit.metainterp.history import IntFrontendOp, RefFrontendOp
from rpython.jit.codewriter.effectinfo import EffectInfo, compute_bitstrings
from rpython.jit.tool.oparser import (
    OpParser, pure_parse, convert_loop_to_trace)
from rpython.jit.metainterp.quasiimmut import QuasiImmutDescr
from rpython.jit.metainterp import compile
from rpython.jit.metainterp.jitprof import EmptyProfiler
from rpython.jit.metainterp.counter import DeterministicJitCounter
from rpython.config.translationoption import get_combined_translation_config
from rpython.jit.metainterp.resoperation import (
    rop, ResOperation, InputArgRef, AbstractValue)
from rpython.jit.metainterp.virtualref import VirtualRefInfo
from rpython.jit.metainterp.optimizeopt.util import (
    sort_descrs, equaloplists, args_dict)


def test_sort_descrs():
    class PseudoDescr(AbstractDescr):
        def __init__(self, n):
            self.n = n
        def sort_key(self):
            return self.n
    for i in range(17):
        lst = [PseudoDescr(j) for j in range(i)]
        lst2 = lst[:]
        random.shuffle(lst2)
        sort_descrs(lst2)
        assert lst2 == lst

def make_remap(inp1, inp2):
    remap = {}
    for a, b in zip(inp1, inp2):
        remap[b] = a
    return remap

def test_equaloplists():
    ops = """
    [i0]
    i1 = int_add(i0, 1)
    i2 = int_add(i1, 1)
    guard_true(i1) [i2]
    jump(i1)
    """
    namespace = {}
    loop1 = pure_parse(ops, namespace=namespace)
    loop2 = pure_parse(ops, namespace=namespace)
    loop3 = pure_parse(ops.replace("i2 = int_add", "i2 = int_sub"),
                       namespace=namespace)
    assert equaloplists(loop1.operations, loop2.operations,
                        remap=make_remap(loop1.inputargs,
                                         loop2.inputargs))
    with pytest.raises(AssertionError):
        equaloplists(
            loop1.operations, loop3.operations,
            remap=make_remap(loop1.inputargs, loop3.inputargs))

def test_equaloplists_fail_args():
    ops = """
    [i0]
    i1 = int_add(i0, 1)
    i2 = int_add(i1, 1)
    guard_true(i1) [i2, i1]
    jump(i1)
    """
    namespace = {}
    loop1 = pure_parse(ops, namespace=namespace)
    loop2 = pure_parse(ops.replace("[i2, i1]", "[i1, i2]"),
                       namespace=namespace)
    with pytest.raises(AssertionError):
        equaloplists(
            loop1.operations, loop2.operations,
            remap=make_remap(loop1.inputargs, loop2.inputargs))
    assert equaloplists(loop1.operations, loop2.operations,
                        remap=make_remap(loop1.inputargs, loop2.inputargs),
                        strict_fail_args=False)
    loop3 = pure_parse(ops.replace("[i2, i1]", "[i2, i0]"),
                       namespace=namespace)
    with pytest.raises(AssertionError):
        equaloplists(
            loop1.operations, loop3.operations,
            remap=make_remap(loop1.inputargs, loop3.inputargs))

# ____________________________________________________________

class LLtypeMixin(object):
    node_vtable = lltype.malloc(OBJECT_VTABLE, immortal=True)
    node_vtable.name = rclass.alloc_array_name('node')
    node_vtable2 = lltype.malloc(OBJECT_VTABLE, immortal=True)
    node_vtable2.name = rclass.alloc_array_name('node2')
    node_vtable3 = lltype.malloc(OBJECT_VTABLE, immortal=True)
    node_vtable3.name = rclass.alloc_array_name('node3')
    node_vtable3.subclassrange_min = 3
    node_vtable3.subclassrange_max = 3
    cpu = runner.LLGraphCPU(None)

    NODE = lltype.GcForwardReference()
    S = lltype.GcForwardReference()
    NODE.become(lltype.GcStruct('NODE', ('parent', OBJECT),
                                        ('value', lltype.Signed),
                                        ('floatval', lltype.Float),
                                        ('charval', lltype.Char),
                                        ('nexttuple', lltype.Ptr(S)),
                                        ('next', lltype.Ptr(NODE))))
    S.become(lltype.GcStruct('TUPLE', ('a', lltype.Signed), ('abis', lltype.Signed),
                        ('b', lltype.Ptr(NODE))))
    NODE2 = lltype.GcStruct('NODE2', ('parent', NODE),
                                     ('other', lltype.Ptr(NODE)))

    NODE3 = lltype.GcForwardReference()
    NODE3.become(lltype.GcStruct('NODE3', ('parent', OBJECT),
                            ('value', lltype.Signed),
                            ('next', lltype.Ptr(NODE3)),
                            hints={'immutable': True}))

    big_fields = [('big' + i, lltype.Signed) for i in string.ascii_lowercase]
    BIG = lltype.GcForwardReference()
    BIG.become(lltype.GcStruct('BIG', *big_fields, hints={'immutable': True}))

    for field, _ in big_fields:
        locals()[field + 'descr'] = cpu.fielddescrof(BIG, field)

    node = lltype.malloc(NODE)
    node.value = 5
    node.next = node
    node.parent.typeptr = node_vtable
    nodeaddr = lltype.cast_opaque_ptr(llmemory.GCREF, node)
    #nodebox = InputArgRef(lltype.cast_opaque_ptr(llmemory.GCREF, node))
    node2 = lltype.malloc(NODE2)
    node2.parent.parent.typeptr = node_vtable2
    node2addr = lltype.cast_opaque_ptr(llmemory.GCREF, node2)
    myptr = lltype.cast_opaque_ptr(llmemory.GCREF, node)
    mynodeb = lltype.malloc(NODE)
    myarray = lltype.cast_opaque_ptr(llmemory.GCREF,
        lltype.malloc(lltype.GcArray(lltype.Signed), 13, zero=True))
    mynodeb.parent.typeptr = node_vtable
    myptrb = lltype.cast_opaque_ptr(llmemory.GCREF, mynodeb)
    myptr2 = lltype.malloc(NODE2)
    myptr2.parent.parent.typeptr = node_vtable2
    myptr2 = lltype.cast_opaque_ptr(llmemory.GCREF, myptr2)
    nullptr = lltype.nullptr(llmemory.GCREF.TO)

    mynode3 = lltype.malloc(NODE3)
    mynode3.parent.typeptr = node_vtable3
    mynode3.value = 7
    mynode3.next = mynode3
    myptr3 = lltype.cast_opaque_ptr(llmemory.GCREF, mynode3)   # a NODE2
    mynode4 = lltype.malloc(NODE3)
    mynode4.parent.typeptr = node_vtable3
    myptr4 = lltype.cast_opaque_ptr(llmemory.GCREF, mynode4)   # a NODE3

    nodesize = cpu.sizeof(NODE, node_vtable)
    node_tid = nodesize.get_type_id()
    nodesize2 = cpu.sizeof(NODE2, node_vtable2)
    nodesize3 = cpu.sizeof(NODE3, node_vtable3)
    valuedescr = cpu.fielddescrof(NODE, 'value')
    floatdescr = cpu.fielddescrof(NODE, 'floatval')
    chardescr = cpu.fielddescrof(NODE, 'charval')
    nextdescr = cpu.fielddescrof(NODE, 'next')
    nexttupledescr = cpu.fielddescrof(NODE, 'nexttuple')
    otherdescr = cpu.fielddescrof(NODE2, 'other')
    valuedescr3 = cpu.fielddescrof(NODE3, 'value')
    nextdescr3 = cpu.fielddescrof(NODE3, 'next')
    assert valuedescr3.is_always_pure()
    assert nextdescr3.is_always_pure()

    accessor = FieldListAccessor()
    accessor.initialize(None, {'inst_field': IR_QUASIIMMUTABLE})
    QUASI = lltype.GcStruct('QUASIIMMUT', ('inst_field', lltype.Signed),
                            ('mutate_field', rclass.OBJECTPTR),
                            hints={'immutable_fields': accessor})
    quasisize = cpu.sizeof(QUASI, None)
    quasi = lltype.malloc(QUASI, immortal=True)
    quasi.inst_field = -4247
    quasifielddescr = cpu.fielddescrof(QUASI, 'inst_field')
    quasiptr = lltype.cast_opaque_ptr(llmemory.GCREF, quasi)
    quasiimmutdescr = QuasiImmutDescr(cpu, quasiptr, quasifielddescr,
                                      cpu.fielddescrof(QUASI, 'mutate_field'))

    NODEOBJ = lltype.GcStruct('NODEOBJ', ('parent', OBJECT),
                                         ('ref', lltype.Ptr(OBJECT)))
    nodeobj = lltype.malloc(NODEOBJ)
    nodeobjvalue = lltype.cast_opaque_ptr(llmemory.GCREF, nodeobj)
    refdescr = cpu.fielddescrof(NODEOBJ, 'ref')

    INTOBJ_NOIMMUT = lltype.GcStruct('INTOBJ_NOIMMUT', ('parent', OBJECT),
                                                ('intval', lltype.Signed))
    INTOBJ_IMMUT = lltype.GcStruct('INTOBJ_IMMUT', ('parent', OBJECT),
                                            ('intval', lltype.Signed),
                                            hints={'immutable': True})
    intobj_noimmut_vtable = lltype.malloc(OBJECT_VTABLE, immortal=True)
    intobj_immut_vtable = lltype.malloc(OBJECT_VTABLE, immortal=True)
    noimmut_intval = cpu.fielddescrof(INTOBJ_NOIMMUT, 'intval')
    immut_intval = cpu.fielddescrof(INTOBJ_IMMUT, 'intval')
    immut = lltype.malloc(INTOBJ_IMMUT, zero=True)
    immutaddr = lltype.cast_opaque_ptr(llmemory.GCREF, immut)
    noimmut_descr = cpu.sizeof(INTOBJ_NOIMMUT, intobj_noimmut_vtable)
    immut_descr = cpu.sizeof(INTOBJ_IMMUT, intobj_immut_vtable)

    PTROBJ_IMMUT = lltype.GcStruct('PTROBJ_IMMUT', ('parent', OBJECT),
                                            ('ptrval', lltype.Ptr(OBJECT)),
                                            hints={'immutable': True})
    ptrobj_immut_vtable = lltype.malloc(OBJECT_VTABLE, immortal=True)
    ptrobj_immut_descr = cpu.sizeof(PTROBJ_IMMUT, ptrobj_immut_vtable)
    immut_ptrval = cpu.fielddescrof(PTROBJ_IMMUT, 'ptrval')

    arraydescr = cpu.arraydescrof(lltype.GcArray(lltype.Signed))
    int32arraydescr = cpu.arraydescrof(lltype.GcArray(rffi.INT))
    int16arraydescr = cpu.arraydescrof(lltype.GcArray(rffi.SHORT))
    float32arraydescr = cpu.arraydescrof(lltype.GcArray(lltype.SingleFloat))
    arraydescr_tid = arraydescr.get_type_id()
    array = lltype.malloc(lltype.GcArray(lltype.Signed), 15, zero=True)
    arrayref = lltype.cast_opaque_ptr(llmemory.GCREF, array)
    array2 = lltype.malloc(lltype.GcArray(lltype.Ptr(S)), 15, zero=True)
    array2ref = lltype.cast_opaque_ptr(llmemory.GCREF, array2)
    gcarraydescr = cpu.arraydescrof(lltype.GcArray(llmemory.GCREF))
    gcarraydescr_tid = gcarraydescr.get_type_id()
    floatarraydescr = cpu.arraydescrof(lltype.GcArray(lltype.Float))

    arrayimmutdescr = cpu.arraydescrof(lltype.GcArray(lltype.Signed, hints={"immutable": True}))
    immutarray = lltype.cast_opaque_ptr(llmemory.GCREF, lltype.malloc(arrayimmutdescr.A, 13, zero=True))
    gcarrayimmutdescr = cpu.arraydescrof(lltype.GcArray(llmemory.GCREF, hints={"immutable": True}))
    floatarrayimmutdescr = cpu.arraydescrof(lltype.GcArray(lltype.Float, hints={"immutable": True}))

    # a GcStruct not inheriting from OBJECT
    tpl = lltype.malloc(S, zero=True)
    tupleaddr = lltype.cast_opaque_ptr(llmemory.GCREF, tpl)
    nodefull2 = lltype.malloc(NODE, zero=True)
    nodefull2addr = lltype.cast_opaque_ptr(llmemory.GCREF, nodefull2)
    ssize = cpu.sizeof(S, None)
    adescr = cpu.fielddescrof(S, 'a')
    abisdescr = cpu.fielddescrof(S, 'abis')
    bdescr = cpu.fielddescrof(S, 'b')
    #sbox = BoxPtr(lltype.cast_opaque_ptr(llmemory.GCREF, lltype.malloc(S)))
    arraydescr2 = cpu.arraydescrof(lltype.GcArray(lltype.Ptr(S)))

    T = lltype.GcStruct('TUPLE',
                        ('c', lltype.Signed),
                        ('d', lltype.Ptr(lltype.GcArray(lltype.Ptr(NODE)))))

    W_ROOT = lltype.GcStruct('W_ROOT', ('parent', OBJECT),
        ('inst_w_seq', llmemory.GCREF), ('inst_index', lltype.Signed),
        ('inst_w_list', llmemory.GCREF), ('inst_length', lltype.Signed),
        ('inst_start', lltype.Signed), ('inst_step', lltype.Signed))
    inst_w_seq = cpu.fielddescrof(W_ROOT, 'inst_w_seq')
    inst_index = cpu.fielddescrof(W_ROOT, 'inst_index')
    inst_length = cpu.fielddescrof(W_ROOT, 'inst_length')
    inst_start = cpu.fielddescrof(W_ROOT, 'inst_start')
    inst_step = cpu.fielddescrof(W_ROOT, 'inst_step')
    inst_w_list = cpu.fielddescrof(W_ROOT, 'inst_w_list')
    w_root_vtable = lltype.malloc(OBJECT_VTABLE, immortal=True)

    tsize = cpu.sizeof(T, None)
    cdescr = cpu.fielddescrof(T, 'c')
    ddescr = cpu.fielddescrof(T, 'd')
    arraydescr3 = cpu.arraydescrof(lltype.GcArray(lltype.Ptr(NODE3)))

    U = lltype.GcStruct('U',
                        ('parent', OBJECT),
                        ('one', lltype.Ptr(lltype.GcArray(lltype.Ptr(NODE)))))
    u_vtable = lltype.malloc(OBJECT_VTABLE, immortal=True)
    SIMPLE = lltype.GcStruct('simple',
        ('parent', OBJECT),
        ('value', lltype.Signed))
    simplevalue = cpu.fielddescrof(SIMPLE, 'value')
    simple_vtable = lltype.malloc(OBJECT_VTABLE, immortal=True)
    simpledescr = cpu.sizeof(SIMPLE, simple_vtable)
    simple = lltype.malloc(SIMPLE, zero=True)
    simpleaddr = lltype.cast_opaque_ptr(llmemory.GCREF, simple)
    #usize = cpu.sizeof(U, ...)
    onedescr = cpu.fielddescrof(U, 'one')

    FUNC = lltype.FuncType([lltype.Signed], lltype.Signed)
    plaincalldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                     EffectInfo.MOST_GENERAL)
    elidablecalldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                    EffectInfo([valuedescr], [], [],
                                               [valuedescr], [], [],
                                         EffectInfo.EF_ELIDABLE_CANNOT_RAISE))
    elidable2calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                    EffectInfo([valuedescr], [], [],
                                               [valuedescr], [], [],
                                         EffectInfo.EF_ELIDABLE_OR_MEMORYERROR))
    elidable3calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                    EffectInfo([valuedescr], [], [],
                                               [valuedescr], [], [],
                                         EffectInfo.EF_ELIDABLE_CAN_RAISE))
    nonwritedescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                    EffectInfo([], [], [], [], [], []))
    writeadescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                  EffectInfo([], [], [], [adescr], [], []))
    writearraydescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                  EffectInfo([], [], [], [adescr], [arraydescr],
                                             []))
    writevalue3descr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                       EffectInfo([], [], [], [valuedescr3], [], []))
    readadescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                                 EffectInfo([adescr], [], [], [], [], []))
    mayforcevirtdescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                 EffectInfo([nextdescr], [], [], [], [], [],
                            EffectInfo.EF_FORCES_VIRTUAL_OR_VIRTUALIZABLE,
                            can_invalidate=True))
    arraycopydescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
             EffectInfo([], [arraydescr], [], [], [arraydescr], [],
                        EffectInfo.EF_CANNOT_RAISE,
                        oopspecindex=EffectInfo.OS_ARRAYCOPY))
    arraymovedescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
             EffectInfo([], [arraydescr], [], [], [arraydescr], [],
                        EffectInfo.EF_CANNOT_RAISE,
                        oopspecindex=EffectInfo.OS_ARRAYMOVE))

    raw_malloc_descr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
             EffectInfo([], [], [], [], [], [],
                        EffectInfo.EF_CAN_RAISE,
                        oopspecindex=EffectInfo.OS_RAW_MALLOC_VARSIZE_CHAR))
    raw_free_descr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
             EffectInfo([], [], [], [], [], [],
                        EffectInfo.EF_CANNOT_RAISE,
                        oopspecindex=EffectInfo.OS_RAW_FREE))

    chararray = lltype.GcArray(lltype.Char)
    chararraydescr = cpu.arraydescrof(chararray)
    u2array = lltype.GcArray(rffi.USHORT)
    u2arraydescr = cpu.arraydescrof(u2array)

    nodefull = lltype.malloc(NODE2, zero=True)
    nodefull.parent.next = lltype.cast_pointer(lltype.Ptr(NODE), nodefull)
    nodefull.parent.nexttuple = tpl
    nodefulladdr = lltype.cast_opaque_ptr(llmemory.GCREF, nodefull)

    # array of structs (complex data)
    complexarray = lltype.GcArray(
        lltype.Struct("complex",
            ("real", lltype.Float),
            ("imag", lltype.Float),
        )
    )
    complexarraydescr = cpu.arraydescrof(complexarray)
    complexrealdescr = cpu.interiorfielddescrof(complexarray, "real")
    compleximagdescr = cpu.interiorfielddescrof(complexarray, "imag")
    complexarraycopydescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
            EffectInfo([], [complexarraydescr], [], [], [complexarraydescr], [],
                       EffectInfo.EF_CANNOT_RAISE,
                       oopspecindex=EffectInfo.OS_ARRAYCOPY))

    rawarraydescr = cpu.arraydescrof(lltype.Array(lltype.Signed,
                                                  hints={'nolength': True}))
    rawarraydescr_char = cpu.arraydescrof(lltype.Array(lltype.Char,
                                                       hints={'nolength': True}))
    rawarraydescr_float = cpu.arraydescrof(lltype.Array(lltype.Float,
                                                        hints={'nolength': True}))

    fc_array = lltype.GcArray(
        lltype.Struct(
            "floatchar", ("float", lltype.Float), ("char", lltype.Char)))
    fc_array_descr = cpu.arraydescrof(fc_array)
    fc_array_floatdescr = cpu.interiorfielddescrof(fc_array, "float")
    fc_array_chardescr = cpu.interiorfielddescrof(fc_array, "char")

    for _name, _os in [
        ('strconcatdescr',               'OS_STR_CONCAT'),
        ('strslicedescr',                'OS_STR_SLICE'),
        ('strequaldescr',                'OS_STR_EQUAL'),
        ('streq_slice_checknull_descr',  'OS_STREQ_SLICE_CHECKNULL'),
        ('streq_slice_nonnull_descr',    'OS_STREQ_SLICE_NONNULL'),
        ('streq_slice_char_descr',       'OS_STREQ_SLICE_CHAR'),
        ('streq_nonnull_descr',          'OS_STREQ_NONNULL'),
        ('streq_nonnull_char_descr',     'OS_STREQ_NONNULL_CHAR'),
        ('streq_checknull_char_descr',   'OS_STREQ_CHECKNULL_CHAR'),
        ('streq_lengthok_descr',         'OS_STREQ_LENGTHOK'),
        ]:
        if _name in ('strconcatdescr', 'strslicedescr'):
            _extra = EffectInfo.EF_ELIDABLE_OR_MEMORYERROR
        else:
            _extra = EffectInfo.EF_ELIDABLE_CANNOT_RAISE
        _oopspecindex = getattr(EffectInfo, _os)
        locals()[_name] = \
            cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                EffectInfo([], [], [], [], [], [], _extra,
                           oopspecindex=_oopspecindex))
        #
        _oopspecindex = getattr(EffectInfo, _os.replace('STR', 'UNI'))
        locals()[_name.replace('str', 'unicode')] = \
            cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
                EffectInfo([], [], [], [], [], [], _extra,
                           oopspecindex=_oopspecindex))

    s2u_descr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT,
            EffectInfo([], [], [], [], [], [], EffectInfo.EF_ELIDABLE_CAN_RAISE,
                       oopspecindex=EffectInfo.OS_STR2UNICODE))
    #

    class LoopToken(AbstractDescr):
        pass
    asmdescr = LoopToken() # it can be whatever, it's not a descr though


    class FakeWarmRunnerDesc:
        pass
    FakeWarmRunnerDesc.cpu = cpu
    vrefinfo = VirtualRefInfo(FakeWarmRunnerDesc)
    virtualtokendescr = vrefinfo.descr_virtual_token
    virtualforceddescr = vrefinfo.descr_forced
    FUNC = lltype.FuncType([], lltype.Void)
    ei = EffectInfo([], [], [], [], [], [], EffectInfo.EF_CANNOT_RAISE,
                    can_invalidate=False,
                    oopspecindex=EffectInfo.OS_JIT_FORCE_VIRTUALIZABLE)
    clear_vable = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT, ei)

    jit_virtual_ref_vtable = vrefinfo.jit_virtual_ref_vtable
    vref_descr = cpu.sizeof(vrefinfo.JIT_VIRTUAL_REF, jit_virtual_ref_vtable)

    FUNC = lltype.FuncType([lltype.Signed, lltype.Signed], lltype.Signed)
    ei = EffectInfo([], [], [], [], [], [], EffectInfo.EF_ELIDABLE_CANNOT_RAISE,
                    can_invalidate=False,
                    oopspecindex=EffectInfo.OS_INT_PY_DIV)
    int_py_div_descr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT, ei)
    ei = EffectInfo([], [], [], [], [], [], EffectInfo.EF_ELIDABLE_CANNOT_RAISE,
                    can_invalidate=False,
                    oopspecindex=EffectInfo.OS_INT_UDIV)
    int_udiv_descr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT, ei)
    ei = EffectInfo([], [], [], [], [], [], EffectInfo.EF_ELIDABLE_CANNOT_RAISE,
                    can_invalidate=False,
                    oopspecindex=EffectInfo.OS_INT_PY_MOD)
    int_py_mod_descr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT, ei)

    FUNC = lltype.FuncType([], llmemory.GCREF)
    ei = EffectInfo([], [], [], [], [], [], EffectInfo.EF_ELIDABLE_CAN_RAISE)
    plain_r_calldescr = cpu.calldescrof(FUNC, FUNC.ARGS, FUNC.RESULT, ei)

    namespace = locals()


class FakeCallInfoCollection:
    def callinfo_for_oopspec(self, oopspecindex):
        calldescrtype = type(LLtypeMixin.strequaldescr)
        effectinfotype = type(LLtypeMixin.strequaldescr.get_extra_info())
        for value in LLtypeMixin.__dict__.values():
            if isinstance(value, calldescrtype):
                extra = value.get_extra_info()
                if (extra and isinstance(extra, effectinfotype) and
                    extra.oopspecindex == oopspecindex):
                    # returns 0 for 'func' in this test
                    return value, 0
        raise AssertionError("not found: oopspecindex=%d" %
                             oopspecindex)

    calldescr_udiv = LLtypeMixin.int_udiv_descr


class Fake(object):
    failargs_limit = 1000
    storedebug = None

class FakeWarmState(object):
    vec = True # default is on
    vec_all = False
    vec_cost = 0
    def __init__(self, enable_opts):
        self.enable_opts = enable_opts

class FakeJitDriverStaticData(object):
    vec = False

class FakeMetaInterpStaticData(object):
    all_descrs = []

    def __init__(self, cpu):
        self.cpu = cpu
        self.profiler = EmptyProfiler()
        self.options = Fake()
        self.globaldata = Fake()
        self.config = get_combined_translation_config(translating=True)
        self.jitlog = jl.JitLogger()
        self.callinfocollection = FakeCallInfoCollection()

    class logger_noopt:
        @classmethod
        def log_loop(*args, **kwds):
            pass

        @classmethod
        def log_loop_from_trace(*args, **kwds):
            pass

    class logger_ops:
        repr_of_resop = repr

    class warmrunnerdesc:
        class memory_manager:
            retrace_limit = 5
            max_retrace_guards = 15
        jitcounter = DeterministicJitCounter()

    def get_name_from_address(self, addr):
        # hack
        try:
            return "".join(addr.ptr.name.chars)
        except AttributeError:
            return ""

class Info(object):
    def __init__(self, preamble, short_preamble=None, virtual_state=None):
        self.preamble = preamble
        self.short_preamble = short_preamble
        self.virtual_state = virtual_state


class BaseTest(LLtypeMixin):
    @pytest.fixture(autouse=True)
    def cls_attributes(self):
        metainterp_sd = FakeMetaInterpStaticData(self.cpu)
        metainterp_sd.virtualref_info = self.vrefinfo
        compute_bitstrings(self.cpu.fetch_all_descrs())
        self.metainterp_sd = metainterp_sd

    def parse(self, s, boxkinds=None, want_fail_descr=True, postprocess=None):
        AbstractValue._repr_memo.counter = 0
        self.oparse = OpParser(s, self.cpu, self.namespace, boxkinds,
                               None, False, postprocess)
        return self.oparse.parse()

    def add_guard_future_condition(self, res):
        # invent a GUARD_FUTURE_CONDITION to not have to change all tests
        if res.operations[-1].getopnum() == rop.JUMP:
            guard = ResOperation(rop.GUARD_FUTURE_CONDITION, [])
            res.operations.insert(-1, guard)

    @staticmethod
    def assert_equal(optimized, expected, text_right=None):
        assert len(optimized.inputargs) == len(expected.inputargs)
        remap = {}
        for box1, box2 in zip(optimized.inputargs, expected.inputargs):
            assert box1.type == box2.type
            remap[box2] = box1
        assert equaloplists(optimized.operations,
                            expected.operations, False, remap, text_right)

    def _convert_call_pure_results(self, d):
        if d is None:
            return
        call_pure_results = args_dict()
        for k, v in d.items():
            call_pure_results[list(k)] = v
        return call_pure_results

    def convert_values(self, inpargs, values):
        if values:
            r = []
            for arg, v in zip(inpargs, values):
                if arg.type == 'i':
                    n = IntFrontendOp(0)
                    if v is not None:
                        n.setint(v)
                else:
                    n = RefFrontendOp(0)
                    if v is not None:
                        n.setref_base(v)
                    assert arg.type == 'r'
                r.append(n)
            return r
        return inpargs

    def unroll_and_optimize(self, loop, call_pure_results=None,
                            jump_values=None):
        self.add_guard_future_condition(loop)
        jump_op = loop.operations[-1]
        assert jump_op.getopnum() == rop.JUMP
        celltoken = JitCellToken()
        runtime_boxes = self.pack_into_boxes(jump_op, jump_values)
        jump_op.setdescr(celltoken)
        call_pure_results = self._convert_call_pure_results(call_pure_results)
        t = convert_loop_to_trace(loop, self.metainterp_sd)
        preamble_data = compile.PreambleCompileData(
            t, runtime_boxes, call_pure_results, enable_opts=self.enable_opts)
        start_state, preamble_ops = preamble_data.optimize_trace(
            self.metainterp_sd, None, {})
        preamble_data.forget_optimization_info()
        loop_data = compile.UnrolledLoopData(
            preamble_data.trace, celltoken, start_state, call_pure_results,
            enable_opts=self.enable_opts)
        loop_info, ops = loop_data.optimize_trace(self.metainterp_sd, None, {})
        preamble = TreeLoop('preamble')
        preamble.inputargs = start_state.renamed_inputargs
        start_label = ResOperation(rop.LABEL, start_state.renamed_inputargs)
        preamble.operations = ([start_label] + preamble_ops +
                               loop_info.extra_same_as + [loop_info.label_op])
        loop.inputargs = loop_info.label_op.getarglist()[:]
        loop.operations = [loop_info.label_op] + ops
        return Info(preamble, loop_info.target_token.short_preamble,
                    start_state.virtual_state)

    def pack_into_boxes(self, jump_op, jump_values):
        assert jump_op.getopnum() == rop.JUMP
        r = []
        if jump_values is not None:
            assert len(jump_values) == len(jump_op.getarglist())
            for i, v in enumerate(jump_values):
                if v is not None:
                    r.append(InputArgRef(v))
                else:
                    r.append(None)
        else:
            for i, box in enumerate(jump_op.getarglist()):
                if box.type == 'r' and not box.is_constant():
                    # NOTE: we arbitrarily set the box contents to a NODE2
                    # object here.  If you need something different, you
                    # need to pass a 'jump_values' argument to e.g.
                    # optimize_loop()
                    r.append(InputArgRef(self.nodefulladdr))
                else:
                    r.append(None)
        return r

class FakeDescr(compile.ResumeGuardDescr):
    def clone_if_mutable(self):
        return FakeDescr()
    def __eq__(self, other):
        return isinstance(other, FakeDescr)

def convert_old_style_to_targets(loop, jump):
    newloop = TreeLoop(loop.name)
    newloop.inputargs = loop.inputargs
    newloop.operations = [ResOperation(rop.LABEL, loop.inputargs, descr=FakeDescr())] + \
                      loop.operations
    if not jump:
        assert newloop.operations[-1].getopnum() == rop.JUMP
        newloop.operations[-1] = newloop.operations[-1].copy_and_change(
            rop.LABEL)
    return newloop

# ____________________________________________________________
