
""" Tests for register allocation for common constructs
"""

import py
from rpython.jit.metainterp.history import (BasicFailDescr,
                                        BasicFinalDescr,
                                        JitCellToken,
                                        TargetToken)
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.backend.llsupport.descr import GcCache
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.backend.arm.regalloc import Regalloc, ARMFrameManager
from rpython.jit.backend.llsupport.regalloc import is_comparison_or_ovf_op
from rpython.jit.tool.oparser import parse
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.annlowlevel import llhelper
from rpython.rtyper.lltypesystem import rstr
from rpython.rtyper import rclass
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.codewriter import longlong
from rpython.jit.backend.llsupport.test.test_regalloc_integration import BaseTestRegalloc


def test_is_comparison_or_ovf_op():
    assert not is_comparison_or_ovf_op(rop.INT_ADD)
    assert is_comparison_or_ovf_op(rop.INT_ADD_OVF)
    assert is_comparison_or_ovf_op(rop.INT_EQ)

CPU = getcpuclass()


class MockGcDescr(GcCache):
    def get_funcptr_for_new(self):
        return 123
    get_funcptr_for_newarray = get_funcptr_for_new
    get_funcptr_for_newstr = get_funcptr_for_new
    get_funcptr_for_newunicode = get_funcptr_for_new

    def rewrite_assembler(self, cpu, operations):
        pass


class MockAssembler(object):
    gcrefs = None
    _float_constants = None

    def __init__(self, cpu=None, gc_ll_descr=None):
        self.movs = []
        self.performs = []
        self.lea = []
        if cpu is None:
            cpu = CPU(None, None)
            cpu.setup_once()
        self.cpu = cpu
        if gc_ll_descr is None:
            gc_ll_descr = MockGcDescr(False)
        self.cpu.gc_ll_descr = gc_ll_descr

    def dump(self, *args):
        pass

    def regalloc_mov(self, from_loc, to_loc):
        self.movs.append((from_loc, to_loc))

    def regalloc_perform(self, op, arglocs, resloc):
        self.performs.append((op, arglocs, resloc))

    def regalloc_perform_discard(self, op, arglocs):
        self.performs.append((op, arglocs))

    def load_effective_addr(self, *args):
        self.lea.append(args)


class RegAllocForTests(Regalloc):
    position = 0

    def _compute_next_usage(self, v, _):
        return -1


def get_zero_division_error(self):
    # for tests, a random emulated ll_inst will do
    ll_inst = lltype.malloc(rclass.OBJECT)
    ll_inst.typeptr = lltype.malloc(rclass.OBJECT_VTABLE,
                                    immortal=True)
    _zer_error_vtable = llmemory.cast_ptr_to_adr(ll_inst.typeptr)
    zer_vtable = self.cast_adr_to_int(_zer_error_vtable)
    zer_inst = lltype.cast_opaque_ptr(llmemory.GCREF, ll_inst)
    return zer_vtable, zer_inst


class CustomBaseTestRegalloc(BaseTestRegalloc):
    cpu = CPU(None, None)
    cpu.setup_once()

    def raising_func(i):
        if i:
            raise LLException(zero_division_error,
                              zero_division_value)
    FPTR = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Void))
    raising_fptr = llhelper(FPTR, raising_func)

    def f(a):
        return 23

    FPTR = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed))
    f_fptr = llhelper(FPTR, f)
    f_calldescr = cpu.calldescrof(FPTR.TO, FPTR.TO.ARGS, FPTR.TO.RESULT,
                                                    EffectInfo.MOST_GENERAL)

    zero_division_tp, zero_division_value = get_zero_division_error(cpu)
    zd_addr = cpu.cast_int_to_adr(zero_division_tp)
    zero_division_error = llmemory.cast_adr_to_ptr(zd_addr,
                                            lltype.Ptr(rclass.OBJECT_VTABLE))
    raising_calldescr = cpu.calldescrof(FPTR.TO, FPTR.TO.ARGS, FPTR.TO.RESULT,
                                                    EffectInfo.MOST_GENERAL)

    targettoken = TargetToken()
    targettoken2 = TargetToken()
    fdescr1 = BasicFailDescr(1)
    fdescr2 = BasicFailDescr(2)
    fdescr3 = BasicFailDescr(3)

    def setup_method(self, meth):
        self.targettoken._ll_loop_code = 0
        self.targettoken2._ll_loop_code = 0

    def f1(x):
        return x + 1

    def f2(x, y):
        return x * y

    def f10(*args):
        assert len(args) == 10
        return sum(args)

    F1PTR = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed))
    F2PTR = lltype.Ptr(lltype.FuncType([lltype.Signed] * 2, lltype.Signed))
    F10PTR = lltype.Ptr(lltype.FuncType([lltype.Signed] * 10, lltype.Signed))
    f1ptr = llhelper(F1PTR, f1)
    f2ptr = llhelper(F2PTR, f2)
    f10ptr = llhelper(F10PTR, f10)

    f1_calldescr = cpu.calldescrof(F1PTR.TO, F1PTR.TO.ARGS, F1PTR.TO.RESULT,
                                                    EffectInfo.MOST_GENERAL)
    f2_calldescr = cpu.calldescrof(F2PTR.TO, F2PTR.TO.ARGS, F2PTR.TO.RESULT,
                                                    EffectInfo.MOST_GENERAL)
    f10_calldescr = cpu.calldescrof(F10PTR.TO, F10PTR.TO.ARGS,
                                    F10PTR.TO.RESULT, EffectInfo.MOST_GENERAL)
    namespace = locals().copy()

class TestRegallocSimple(CustomBaseTestRegalloc):
    def test_simple_loop(self):
        ops = '''
        [i0]
        label(i0, descr=targettoken)
        i1 = int_add(i0, 1)
        i2 = int_lt(i1, 20)
        guard_true(i2) [i1]
        jump(i1, descr=targettoken)
        '''
        self.interpret(ops, [0])
        assert self.getint(0) == 20

    def test_two_loops_and_a_bridge(self):
        ops = '''
        [i0, i1, i2, i3]
        label(i0, i1, i2, i3, descr=targettoken)
        i4 = int_add(i0, 1)
        i5 = int_lt(i4, 20)
        guard_true(i5) [i4, i1, i2, i3]
        jump(i4, i1, i2, i3, descr=targettoken)
        '''
        loop = self.interpret(ops, [0, 0, 0, 0])
        ops2 = '''
        [i5, i6, i7, i8]
        label(i5, descr=targettoken2)
        i1 = int_add(i5, 1)
        i3 = int_add(i1, 1)
        i4 = int_add(i3, 1)
        i2 = int_lt(i4, 30)
        guard_true(i2) [i4]
        jump(i4, descr=targettoken2)
        '''
        loop2 = self.interpret(ops2, [0, 0, 0, 0])
        bridge_ops = '''
        [i4]
        jump(i4, i4, i4, i4, descr=targettoken)
        '''
        bridge = self.attach_bridge(bridge_ops, loop2, 5)
        self.run(loop2, 0, 0, 0, 0)
        assert self.getint(0) == 31
        assert self.getint(1) == 30
        assert self.getint(2) == 30
        assert self.getint(3) == 30

    def test_pointer_arg(self):
        ops = '''
        [i0, p0]
        label(i0, p0, descr=targettoken)
        i1 = int_add(i0, 1)
        i2 = int_lt(i1, 10)
        guard_true(i2) [p0]
        jump(i1, p0, descr=targettoken)
        '''
        S = lltype.GcStruct('S')
        ptr = lltype.malloc(S)
        self.interpret(ops, [0, ptr])
        assert self.getptr(0, lltype.Ptr(S)) == ptr

    def test_exception_bridge_no_exception(self):
        ops = '''
        [i0]
        i1 = same_as_i(1)
        call_n(ConstClass(raising_fptr), i0, descr=raising_calldescr)
        guard_exception(ConstClass(zero_division_error)) [i1]
        finish(0)
        '''
        bridge_ops = '''
        [i3]
        i2 = same_as_i(2)
        guard_no_exception() [i2]
        finish(1)
        '''
        loop = self.interpret(ops, [0])
        assert self.getint(0) == 1
        bridge = self.attach_bridge(bridge_ops, loop, 2)
        self.run(loop, 0)
        assert self.getint(0) == 1

    def test_inputarg_unused(self):
        ops = '''
        [i0]
        finish(1)
        '''
        self.interpret(ops, [0])
        # assert did not explode

    def test_nested_guards(self):
        ops = '''
        [i0, i1]
        guard_true(i0) [i0, i1]
        finish(4)
        '''
        bridge_ops = '''
        [i0, i1]
        guard_true(i0) [i0, i1]
        finish(3)
        '''
        loop = self.interpret(ops, [0, 10])
        assert self.getint(0) == 0
        assert self.getint(1) == 10
        bridge = self.attach_bridge(bridge_ops, loop, 0)
        self.run(loop, 0, 10)
        assert self.getint(0) == 0
        assert self.getint(1) == 10

    def test_nested_unused_arg(self):
        ops = '''
        [i0, i1]
        guard_true(i0) [i0, i1]
        finish(1)
        '''
        loop = self.interpret(ops, [0, 1])
        assert self.getint(0) == 0
        bridge_ops = '''
        [i0, i1]
        guard_true(i0) [i0]
        finish(1)
        '''
        self.attach_bridge(bridge_ops, loop, 0)
        self.run(loop, 0, 1)

    def test_spill_for_constant(self):
        ops = '''
        [i0, i1, i2, i3]
        label(i0, i1, i2, i3, descr=targettoken)
        i4 = int_add(3, i1)
        i5 = int_lt(i4, 30)
        guard_true(i5) [i0, i4, i2, i3]
        jump(1, i4, 3, 4, descr=targettoken)
        '''
        self.interpret(ops, [0, 0, 0, 0])
        assert self.getints(4) == [1, 30, 3, 4]

    def test_spill_for_constant_lshift(self):
        ops = '''
        [i0, i2, i1, i3]
        label(i0, i2, i1, i3, descr=targettoken)
        i4 = int_lshift(1, i1)
        i5 = int_add(1, i1)
        i6 = int_lt(i5, 30)
        guard_true(i6) [i4, i5, i2, i3]
        jump(i4, 3, i5, 4, descr=targettoken)
        '''
        self.interpret(ops, [0, 0, 0, 0])
        assert self.getints(4) == [1<<29, 30, 3, 4]
        ops = '''
        [i0, i1, i2, i3]
        label(i0, i1, i2, i3, descr=targettoken)
        i4 = int_lshift(1, i1)
        i5 = int_add(1, i1)
        i6 = int_lt(i5, 30)
        guard_true(i6) [i4, i5, i2, i3]
        jump(i4, i5, 3, 4, descr=targettoken)
        '''
        self.interpret(ops, [0, 0, 0, 0])
        assert self.getints(4) == [1<<29, 30, 3, 4]
        ops = '''
        [i0, i3, i1, i2]
        label(i0, i3, i1, i2, descr=targettoken)
        i4 = int_lshift(1, i1)
        i5 = int_add(1, i1)
        i6 = int_lt(i5, 30)
        guard_true(i6) [i4, i5, i2, i3]
        jump(i4, 4, i5, 3, descr=targettoken)
        '''
        self.interpret(ops, [0, 0, 0, 0])
        assert self.getints(4) == [1<<29, 30, 3, 4]

    def test_result_selected_reg_via_neg(self):
        ops = '''
        [i0, i1, i2, i3]
        label(i0, i1, i2, i3, descr=targettoken)
        i6 = int_neg(i2)
        i7 = int_add(1, i1)
        i4 = int_lt(i7, 10)
        guard_true(i4) [i0, i6, i7]
        jump(1, i7, i2, i6, descr=targettoken)
        '''
        self.interpret(ops, [0, 0, 3, 0])
        assert self.getints(3) == [1, -3, 10]

    def test_compare_memory_result_survives(self):
        ops = '''
        [i0, i1, i2, i3]
        label(i0, i1, i2, i3, descr=targettoken)
        i4 = int_lt(i0, i1)
        i5 = int_add(i3, 1)
        i6 = int_lt(i5, 30)
        guard_true(i6) [i4]
        jump(i0, i1, i4, i5, descr=targettoken)
        '''
        self.interpret(ops, [0, 10, 0, 0])
        assert self.getint(0) == 1

    def test_jump_different_args(self):
        ops = '''
        [i0, i15, i16, i18, i1, i2, i3]
        label(i0, i15, i16, i18, i1, i2, i3, descr=targettoken)
        i4 = int_add(i3, 1)
        i5 = int_lt(i4, 20)
        guard_true(i5) [i2, i1]
        jump(i0, i18, i15, i16, i2, i1, i4, descr=targettoken)
        '''
        self.interpret(ops, [0, 1, 2, 3, 0, 0, 0])

    def test_op_result_unused(self):
        ops = '''
        [i0, i1]
        i2 = int_add(i0, i1)
        finish(0)
        '''
        self.interpret(ops, [0, 0])

    def test_guard_value_two_boxes(self):
        ops = '''
        [i0, i1, i2, i3, i4, i5, i6, i7]
        guard_value(i6, i1) [i0, i2, i3, i4, i5, i6]
        finish(i0)
        '''
        self.interpret(ops, [0, 0, 0, 0, 0, 0, 0, 0])
        assert self.getint(0) == 0

    def test_bug_wrong_stack_adj(self):
        ops = '''
        [i0, i1, i2, i3, i4, i5, i6, i7, i8]
        i9 = same_as_i(0)
        guard_true(i0) [i9, i0, i1, i2, i3, i4, i5, i6, i7, i8]
        finish(1)
        '''
        loop = self.interpret(ops, [0, 1, 2, 3, 4, 5, 6, 7, 8])
        assert self.getint(0) == 0
        bridge_ops = '''
        [i9, i0, i1, i2, i3, i4, i5, i6, i7, i8]
        call_n(ConstClass(raising_fptr), 0, descr=raising_calldescr)
        guard_true(i0) [i0, i1, i2, i3, i4, i5, i6, i7, i8]
        finish(1)
        '''
        self.attach_bridge(bridge_ops, loop, 1)
        self.run(loop, 0, 1, 2, 3, 4, 5, 6, 7, 8)
        assert self.getints(9) == range(9)

    def test_loopargs(self):
        ops = """
        [i0, i1, i2, i3]
        i4 = int_add(i0, i1)
        jump(i4, i1, i2, i3)
        """
        regalloc = self.prepare_loop(ops)
        assert len(regalloc.rm.reg_bindings) == 0
        assert len(regalloc.frame_manager.bindings) == 4

    def test_loopargs_2(self):
        ops = """
        [i0, i1, i2, i3]
        i4 = int_add(i0, i1)
        guard_false(i0) [i4, i1, i2, i3]
        """
        regalloc = self.prepare_loop(ops)
        assert len(regalloc.frame_manager.bindings) == 4

    def test_loopargs_3(self):
        ops = """
        [i0, i1, i2, i3]
        i4 = int_add(i0, i1)
        guard_true(i4) [i0, i1, i2, i3, i4]
        jump(i4, i1, i2, i3)
        """
        regalloc = self.prepare_loop(ops)
        assert len(regalloc.frame_manager.bindings) == 4


class TestRegallocCompOps(CustomBaseTestRegalloc):

    def test_cmp_op_0(self):
        ops = '''
        [i0, i3]
        i1 = same_as_i(1)
        i2 = int_lt(i0, 100)
        guard_true(i3) [i1, i2]
        finish(i2)
        '''
        self.interpret(ops, [0, 1])
        assert self.getint(0) == 1


class TestRegallocMoreRegisters(CustomBaseTestRegalloc):

    cpu = CustomBaseTestRegalloc.cpu
    targettoken = TargetToken()

    S = lltype.GcStruct('S', ('field', lltype.Char))
    fielddescr = cpu.fielddescrof(S, 'field')

    A = lltype.GcArray(lltype.Char)
    I = lltype.GcArray(lltype.Signed)
    arraydescr = cpu.arraydescrof(A)
    arraydescr_i = cpu.arraydescrof(I)

    namespace = locals().copy()

    def test_int_is_true(self):
        ops = '''
        [i0, i1, i2, i3, i4, i5, i6, i7]
        i10 = int_is_true(i0)
        i11 = int_is_true(i1)
        i12 = int_is_true(i2)
        i13 = int_is_true(i3)
        i14 = int_is_true(i4)
        i15 = int_is_true(i5)
        i16 = int_is_true(i6)
        i17 = int_is_true(i7)
        guard_true(i0) [i10, i11, i12, i13, i14, i15, i16, i17]
        '''
        self.interpret(ops, [0, 42, 12, 0, 13, 0, 0, 3333])
        assert self.getints(8) == [0, 1, 1, 0, 1, 0, 0, 1]

    def test_comparison_ops(self):
        ops = '''
        [i0, i1, i2, i3, i4, i5, i6]
        i10 = int_lt(i0, i1)
        i11 = int_le(i2, i3)
        i12 = int_ge(i4, i5)
        i13 = int_eq(i5, i6)
        i14 = int_gt(i6, i2)
        i15 = int_ne(i2, i6)
        guard_true(i0) [i10, i11, i12, i13, i14, i15]

        '''
        self.interpret(ops, [0, 1, 2, 3, 4, 5, 6])
        assert self.getints(6) == [1, 1, 0, 0, 1, 1]

    def test_strsetitem(self):
        ops = '''
        [p0, i]
        strsetitem(p0, 1, i)
        finish()
        '''
        llstr = rstr.mallocstr(10)
        self.interpret(ops, [llstr, ord('a')])
        assert llstr.chars[1] == 'a'

    def test_setfield_char(self):
        ops = '''
        [p0, i]
        setfield_gc(p0, i, descr=fielddescr)
        finish()
        '''
        s = lltype.malloc(self.S)
        self.interpret(ops, [s, ord('a')])
        assert s.field == 'a'

    def test_setarrayitem_gc(self):
        ops = '''
        [p0, i]
        setarrayitem_gc(p0, 1, i, descr=arraydescr)
        finish()
        '''
        s = lltype.malloc(self.A, 3)
        self.interpret(ops, [s, ord('a')])
        assert s[1] == 'a'

    def test_setarrayitem2_gc(self):
        ops = '''
        [p0, i, i1]
        setarrayitem_gc(p0, i1, i, descr=arraydescr)
        finish()
        '''
        s = lltype.malloc(self.A, 3)
        self.interpret(ops, [s, ord('a'), 1])
        assert s[1] == 'a'

    def test_setarrayitem3_gc(self):
        ops = '''
        [p0, i0, i1]
        setarrayitem_gc(p0, i1, i0, descr=arraydescr_i)
        finish()
        '''
        s = lltype.malloc(self.I, 3)
        self.interpret(ops, [s, 1234567890, 1])
        assert s[1] == 1234567890

    def test_setarrayitem4_gc(self):
        ops = '''
        [p0, i0]
        setarrayitem_gc(p0, 1, i0, descr=arraydescr_i)
        finish()
        '''
        s = lltype.malloc(self.I, 3)
        self.interpret(ops, [s, 1234567890])
        assert s[1] == 1234567890


class TestRegallocFloats(CustomBaseTestRegalloc):
    def test_float_add(self):
        if not self.cpu.supports_floats:
            py.test.skip("requires floats")
        ops = '''
        [f0, f1]
        f2 = float_add(f0, f1)
        guard_value(f0, f1) [f2, f0, f1]
        '''
        self.interpret(ops, [3.0, 1.5])
        assert self.getfloats(3) == [4.5, 3.0, 1.5]

    def test_float_adds_stack(self):
        if not self.cpu.supports_floats:
            py.test.skip("requires floats")
        ops = '''
        [f0, f1, f2, f3, f4, f5, f6, f7, f8]
        f9 = float_add(f0, f1)
        f10 = float_add(f8, 3.5)
        guard_value(f0, f1) [f9, f10, f2, f3, f4, f5, f6, f7, f8]
        '''
        self.interpret(ops, [0.1, .2, .3, .4, .5, .6, .7, .8, .9])
        assert self.getfloats(9) == [.1 + .2, .9 + 3.5, .3,
                                        .4, .5, .6, .7, .8, .9]

    def test_lt_const(self):
        if not self.cpu.supports_floats:
            py.test.skip("requires floats")
        ops = '''
        [f0]
        i1 = float_lt(3.5, f0)
        finish(i1)
        '''
        self.interpret(ops, [0.1])
        assert self.getint(0) == 0

    def test_bug_float_is_true_stack(self):
        if not self.cpu.supports_floats:
            py.test.skip("requires floats")
        # NB. float_is_true no longer exists.  Unsure if keeping this test
        # makes sense any more.
        ops = '''
        [f0, f1, f2, f3, f4, f5, f6, f7, f8, f9]
        i0 = float_ne(f0, 0.0)
        i1 = float_ne(f1, 0.0)
        i2 = float_ne(f2, 0.0)
        i3 = float_ne(f3, 0.0)
        i4 = float_ne(f4, 0.0)
        i5 = float_ne(f5, 0.0)
        i6 = float_ne(f6, 0.0)
        i7 = float_ne(f7, 0.0)
        i8 = float_ne(f8, 0.0)
        i9 = float_ne(f9, 0.0)
        guard_false(i9), [i0, i1, i2, i3, i4, i5, i6, i7, i8, i9]
        '''
        self.interpret(ops, [0.0, .1, .2, .3, .4, .5, .6, .7, .8, .9])
        assert self.getints(9) == [0, 1, 1, 1, 1, 1, 1, 1, 1]


class TestRegAllocCallAndStackDepth(CustomBaseTestRegalloc):
    def expected_param_depth(self, num_args):
        # Assumes the arguments are all non-float
        return num_args

    def test_one_call(self):
        ops = '''
        [i0, i1, i2, i3, i4, i5, i6, i7, i8, i9]
        i10 = call_i(ConstClass(f1ptr), i0, descr=f1_calldescr)
        guard_false(i10), [i10, i1, i2, i3, i4, i5, i6, i7, i8, i9]
        '''
        self.interpret(ops, [4, 7, 9, 9, 9, 9, 9, 9, 9, 9])
        assert self.getints(10) == [5, 7, 9, 9, 9, 9, 9, 9, 9, 9]

    def test_two_calls(self):
        ops = '''
        [i0, i1,  i2, i3, i4, i5, i6, i7, i8, i9]
        i10 = call_i(ConstClass(f1ptr), i0, descr=f1_calldescr)
        i11 = call_i(ConstClass(f2ptr), i10, i1, descr=f2_calldescr)
        guard_false(i11) [i11, i1,  i2, i3, i4, i5, i6, i7, i8, i9]
        '''
        self.interpret(ops, [4, 7, 9, 9, 9, 9, 9, 9, 9, 9])
        assert self.getints(10) == [5 * 7, 7, 9, 9, 9, 9, 9, 9, 9, 9]

    def test_call_many_arguments(self):
        ops = '''
        [i0, i1, i2, i3, i4, i5, i6, i7]
        i8 = call_i(ConstClass(f10ptr), 1, i0, i1, i2, i3, i4, i5, i6, i7, 10, descr=f10_calldescr)
        finish(i8)
        '''
        self.interpret(ops, [2, 3, 4, 5, 6, 7, 8, 9])
        assert self.getint(0) == 55

    def test_bridge_calls_1(self):
        ops = '''
        [i0, i1]
        i2 = call_i(ConstClass(f1ptr), i0, descr=f1_calldescr)
        guard_value(i2, 0, descr=fdescr1) [i2, i1]
        finish(i1)
        '''
        loop = self.interpret(ops, [4, 7])
        assert self.getint(0) == 5
        ops = '''
        [i2, i1]
        i3 = call_i(ConstClass(f2ptr), i2, i1, descr=f2_calldescr)
        finish(i3)
        '''
        self.attach_bridge(ops, loop, -2)

        self.run(loop, 4, 7)
        assert self.getint(0) == 5 * 7

    def test_bridge_calls_2(self):
        ops = '''
        [i0, i1]
        i2 = call_i(ConstClass(f2ptr), i0, i1, descr=f2_calldescr)
        guard_value(i2, 0, descr=fdescr1) [i2]
        finish(i1)
        '''
        loop = self.interpret(ops, [4, 7])
        assert self.getint(0) == 4 * 7
        ops = '''
        [i2]
        i3 = call_i(ConstClass(f1ptr), i2, descr=f1_calldescr)
        finish(i3)
        '''
        self.attach_bridge(ops, loop, -2)

        self.run(loop, 4, 7)
        assert self.getint(0) == 29


class TestJumps(TestRegallocSimple):
    def test_jump_with_consts(self):
        loop = """
        [i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12, i13, i14]
        label(i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12, i13, i14, descr=targettoken)
        jump(i1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, descr=targettoken)
        """
        self.interpret(loop, range(15), run=False)
        # ensure compiling this loop works
        assert 1

    def test_from_loop_to_loop(self):
        def assembler_helper(failindex, virtualizable):
            return 3

        FUNCPTR = lltype.Ptr(lltype.FuncType([lltype.Signed, llmemory.GCREF],
                                             lltype.Signed))

        class FakeJitDriverSD:
            index_of_virtualizable = -1
            _assembler_helper_ptr = llhelper(FUNCPTR, assembler_helper)
            assembler_helper_adr = llmemory.cast_ptr_to_adr(
                _assembler_helper_ptr)

        FakeJitDriverSD.portal_calldescr = self.cpu.calldescrof(
            lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed)), \
                    [lltype.Signed], lltype.Signed, EffectInfo.MOST_GENERAL)
        self.cpu.done_with_this_frame_descr_int = BasicFinalDescr()
        loop1 = """
        [i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10]
        i11 = int_add(i0, i1)
        guard_false(i0) [i11, i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10]
        """
        large = self.interpret(loop1, range(11), run=False)
        large._jitcelltoken.outermost_jitdriver_sd = FakeJitDriverSD()
        self.namespace['looptoken'] = large._jitcelltoken
        assert self.namespace['looptoken']._ll_function_addr != 0
        loop2 = """
        [i0]
        i1 = force_token()
        i2 = call_assembler_i(1,2,3,4,5,6,7,8,9,10,11, descr=looptoken)
        guard_not_forced() [i0]
        guard_false(i0) [i0, i2]
        """

        self.interpret(loop2, [110])
        assert self.getint(0) == 110
        assert self.getint(1) == 3

    def test_far_far_jump(self):
        ops = """
        [i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10]
        label(i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, descr=targettoken)
        i11 = int_add(i0, 1)
        i12 = int_lt(i11, 2)
        i13 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i14 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i15 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i16 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i17 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i18 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i19 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i20 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i21 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i22 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i23 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i24 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i26 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i27 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i28 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i29 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        i30 = call_i(ConstClass(f_fptr), i12, descr=f_calldescr)
        guard_true(i12) [i11, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10]
        jump(i11, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, descr=targettoken)
        """
        self.interpret(ops, range(11))
        assert self.getint(0) == 2  # and not segfault()


class TestStrOps(CustomBaseTestRegalloc):
    def test_newstr(self):
        ops = """
        [i0]
        p1 = newstr(300)
        i2 = strlen(p1)
        finish(i2)
        """
        self.interpret(ops, [0])
        assert self.getint(0) == 300
        ops = """
        [i0]
        p1 = newstr(i0)
        i2 = strlen(p1)
        finish(i2)
        """
        self.interpret(ops, [300])
        assert self.getint(0) == 300

    def test_strlen(self):
        s = rstr.mallocstr(300)
        ops = """
        [p0]
        i1 = strlen(p0)
        finish(i1)
        """
        self.interpret(ops, [s])
        assert self.getint(0) == 300

    def test_len_of_newstr(self):
        ops = """
        []
        p0 = newstr(300)
        finish(p0)
        """
        self.interpret(ops, [])
        string = self.getptr(0, lltype.Ptr(rstr.STR))
        assert len(string.chars) == 300
