
""" Tests for register allocation for common constructs
"""

import py
from rpython.jit.metainterp.history import BasicFailDescr, JitCellToken,\
     TargetToken
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.backend.llsupport.regalloc import is_comparison_or_ovf_op
from rpython.jit.tool.oparser import parse
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.annlowlevel import llhelper
from rpython.rtyper.lltypesystem import rstr
from rpython.rtyper import rclass
from rpython.jit.codewriter import longlong
from rpython.jit.codewriter.effectinfo import EffectInfo

def test_is_comparison_or_ovf_op():
    assert not is_comparison_or_ovf_op(rop.INT_ADD)
    assert is_comparison_or_ovf_op(rop.INT_ADD_OVF)
    assert is_comparison_or_ovf_op(rop.INT_EQ)


def get_zero_division_error(self):
    # for tests, a random emulated ll_inst will do
    ll_inst = lltype.malloc(rclass.OBJECT)
    ll_inst.typeptr = lltype.malloc(rclass.OBJECT_VTABLE,
                                    immortal=True)
    _zer_error_vtable = llmemory.cast_ptr_to_adr(ll_inst.typeptr)
    zer_vtable = self.cast_adr_to_int(_zer_error_vtable)
    zer_inst = lltype.cast_opaque_ptr(llmemory.GCREF, ll_inst)
    return zer_vtable, zer_inst


CPU = getcpuclass()
class BaseTestRegalloc(object):
    cpu = CPU(None, None)
    cpu.setup_once()

    def raising_func(i):
        if i:
            raise LLException(zero_division_error,
                              zero_division_value)
    FPTR = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Void))
    raising_fptr = llhelper(FPTR, raising_func)
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
        return x+1

    def f2(x, y):
        return x*y

    def f10(*args):
        assert len(args) == 10
        return sum(args)

    def fgcref(x):
        return 17

    def fppii(x, y, i, j):
        return 19

    def ff(x, y):
        return x + y + 0.1

    F1PTR = lltype.Ptr(lltype.FuncType([lltype.Signed], lltype.Signed))
    F2PTR = lltype.Ptr(lltype.FuncType([lltype.Signed]*2, lltype.Signed))
    F10PTR = lltype.Ptr(lltype.FuncType([lltype.Signed]*10, lltype.Signed))
    FGCREFPTR = lltype.Ptr(lltype.FuncType([llmemory.GCREF], lltype.Signed))
    FPPIIPTR = lltype.Ptr(lltype.FuncType([llmemory.GCREF, llmemory.GCREF, lltype.Signed, lltype.Signed], lltype.Signed))
    FFPTR = lltype.Ptr(lltype.FuncType([lltype.Float]*2, lltype.Float))

    f1ptr = llhelper(F1PTR, f1)
    f2ptr = llhelper(F2PTR, f2)
    f10ptr = llhelper(F10PTR, f10)
    fgcrefptr = llhelper(FGCREFPTR, fgcref)
    fppiiptr = llhelper(FPPIIPTR, fppii)
    ffptr = llhelper(FFPTR, ff)

    f1_calldescr = cpu.calldescrof(F1PTR.TO, F1PTR.TO.ARGS, F1PTR.TO.RESULT,
                                   EffectInfo.MOST_GENERAL)
    f2_calldescr = cpu.calldescrof(F2PTR.TO, F2PTR.TO.ARGS, F2PTR.TO.RESULT,
                                   EffectInfo.MOST_GENERAL)
    f10_calldescr = cpu.calldescrof(F10PTR.TO, F10PTR.TO.ARGS, F10PTR.TO.RESULT,
                                    EffectInfo.MOST_GENERAL)
    fgcref_calldescr = cpu.calldescrof(FGCREFPTR.TO, FGCREFPTR.TO.ARGS, FGCREFPTR.TO.RESULT,
                                       EffectInfo.MOST_GENERAL)
    fppii_calldescr = cpu.calldescrof(FPPIIPTR.TO, FPPIIPTR.TO.ARGS, FPPIIPTR.TO.RESULT,
                                      EffectInfo.MOST_GENERAL)
    ff_calldescr = cpu.calldescrof(FFPTR.TO, FFPTR.TO.ARGS, FFPTR.TO.RESULT,
                                   EffectInfo.MOST_GENERAL)

    namespace = locals().copy()

    def parse(self, s, boxkinds=None, namespace=None):
        return parse(s, self.cpu, namespace or self.namespace,
                     boxkinds=boxkinds)

    def interpret(self, ops, args, run=True, namespace=None):
        loop = self.parse(ops, namespace=namespace)
        self.loop = loop
        looptoken = JitCellToken()
        self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
        arguments = []
        for arg in args:
            if isinstance(arg, int):
                arguments.append(arg)
            elif isinstance(arg, float):
                arg = longlong.getfloatstorage(arg)
                arguments.append(arg)
            else:
                assert isinstance(lltype.typeOf(arg), lltype.Ptr)
                llgcref = lltype.cast_opaque_ptr(llmemory.GCREF, arg)
                arguments.append(llgcref)
        loop._jitcelltoken = looptoken
        if run:
            self.deadframe = self.cpu.execute_token(looptoken, *arguments)
        return loop

    def prepare_loop(self, ops):
        loop = self.parse(ops)
        self.loop = loop
        regalloc = self.cpu.build_regalloc()
        regalloc.prepare_loop(loop.inputargs, loop.operations,
                              loop.original_jitcell_token, [])
        return regalloc

    def getint(self, index):
        return self.cpu.get_int_value(self.deadframe, index)

    def getfloat(self, index):
        return self.cpu.get_float_value(self.deadframe, index)

    def getints(self, end):
        return [self.cpu.get_int_value(self.deadframe, index) for
                index in range(0, end)]

    def getfloats(self, end):
        return [longlong.getrealfloat(
                    self.cpu.get_float_value(self.deadframe, index))
                for index in range(0, end)]

    def getptr(self, index, T):
        gcref = self.cpu.get_ref_value(self.deadframe, index)
        return lltype.cast_opaque_ptr(T, gcref)

    def attach_bridge(self, ops, loop, guard_op_index, **kwds):
        guard_op = loop.operations[guard_op_index]
        assert guard_op.is_guard()
        bridge = self.parse(ops, **kwds)
        assert ([box.type for box in bridge.inputargs] ==
                [box.type for box in guard_op.getfailargs()])
        faildescr = guard_op.getdescr()
        self.cpu.compile_bridge(faildescr, bridge.inputargs,
                                bridge.operations,
                                loop._jitcelltoken)
        return bridge

    def run(self, loop, *arguments):
        self.deadframe = self.cpu.execute_token(loop._jitcelltoken, *arguments)
        return self.cpu.get_latest_descr(self.deadframe)

class TestRegallocSimple(BaseTestRegalloc):
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
        finish(2)
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
        guard_true(i9) [i0, i1, i2, i3, i4, i5, i6, i7, i8]
        finish()
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
        # we pass stuff on the frame
        assert len(regalloc.rm.reg_bindings) == 0
        assert len(regalloc.fm.bindings) == 4

    def test_longevity(self):
        ops = """
        [i0, i1, i2, i3, i4, i10]
        i5 = int_add(i0, i1)     # 0
        i8 = int_add(i0, i1)     # 1 unused result, so not in real_usages
        i6 = int_is_true(i5)     # 2
        i11 = int_add(i5, i10)   # 3
        guard_true(i6) [i0, i4]  # 4
        jump(i5, i1, i2, i3, i5, i11) # 5
        """
        regalloc = self.prepare_loop(ops)
        i0, i1, i2, i3, i4, i10 = self.loop.inputargs
        i5 = self.loop.operations[0]
        i6 = self.loop.operations[2]
        longevity = regalloc.longevity
        assert longevity[i0].last_usage == 4
        assert longevity[i0].real_usages == [0]
        assert longevity[i1].last_usage == 5
        assert longevity[i1].real_usages == [0]
        assert longevity[i2].last_usage == 5
        assert longevity[i2].real_usages is None
        assert longevity[i3].last_usage == 5
        assert longevity[i3].real_usages is None
        assert longevity[i4].last_usage == 4
        assert longevity[i4].real_usages is None
        assert longevity[i5].last_usage == 5
        assert longevity[i5].real_usages == [2, 3]
        assert longevity[i6].last_usage == 4
        assert longevity[i6].real_usages == [4]
        assert longevity[i10].last_usage == 3
        assert longevity[i10].real_usages == [3]

class TestRegallocCompOps(BaseTestRegalloc):

    def test_cmp_op_0(self):
        ops = '''
        [i0, i3]
        i1 = same_as_i(1)
        i2 = int_lt(i0, 100)
        guard_true(i3) [i1, i2]
        i4 = int_neg(i2)
        finish(0)
        '''
        self.interpret(ops, [0, 1])
        assert self.getint(0) == 0

class TestRegallocMoreRegisters(BaseTestRegalloc):

    cpu = BaseTestRegalloc.cpu
    targettoken = TargetToken()

    S = lltype.GcStruct('S', ('field', lltype.Char))
    fielddescr = cpu.fielddescrof(S, 'field')

    A = lltype.GcArray(lltype.Char)
    arraydescr = cpu.arraydescrof(A)

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
        finish()
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
        finish()
        '''
        self.interpret(ops, [0, 1, 2, 3, 4, 5, 6])
        assert self.getints(6) == [1, 1, 0, 0, 1, 1]

    def test_strsetitem(self):
        ops = '''
        [p0, i]
        strsetitem(p0, 1, i)
        finish()
        '''
        llstr  = rstr.mallocstr(10)
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


class TestRegallocFloats(BaseTestRegalloc):
    def setup_class(cls):
        if not cls.cpu.supports_floats:
            py.test.skip("needs float support")

    def test_float_add(self):
        ops = '''
        [f0, f1]
        f2 = float_add(f0, f1)
        i0 = same_as_i(0)
        guard_true(i0) [f2, f0, f1]
        finish()
        '''
        self.interpret(ops, [3.0, 1.5])
        assert self.getfloats(3) == [4.5, 3.0, 1.5]

    def test_float_adds_stack(self):
        ops = '''
        [f0, f1, f2, f3, f4, f5, f6, f7, f8]
        f9 = float_add(f0, f1)
        f10 = float_add(f8, 3.5)
        i0 = same_as_i(0)
        guard_true(i0) [f9, f10, f2, f3, f4, f5, f6, f7, f8]
        finish()
        '''
        self.interpret(ops, [0.1, .2, .3, .4, .5, .6, .7, .8, .9])
        assert self.getfloats(9) == [.1+.2, .9+3.5, .3, .4, .5, .6, .7, .8, .9]

    def test_lt_const(self):
        ops = '''
        [f0]
        i1 = float_lt(3.5, f0)
        finish(i1)
        '''
        self.interpret(ops, [0.1])
        assert self.getint(0) == 0

    def test_bug_float_is_true_stack(self):
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
        guard_true(i0) [i0, i1, i2, i3, i4, i5, i6, i7, i8, i9]
        finish()
        '''
        loop = self.interpret(ops, [0.0, .1, .2, .3, .4, .5, .6, .7, .8, .9])
        assert self.getints(9) == [0, 1, 1, 1, 1, 1, 1, 1, 1]

class TestRegAllocCallAndStackDepth(BaseTestRegalloc):
    def setup_class(cls):
        py.test.skip("skip for now, not sure what do we do")

    def expected_frame_depth(self, num_call_args, num_pushed_input_args=0):
        # Assumes the arguments are all non-float
        if not self.cpu.IS_64_BIT:
            extra_esp = num_call_args
            return extra_esp
        elif self.cpu.IS_64_BIT:
            # 'num_pushed_input_args' is for X86_64 only
            extra_esp = max(num_call_args - 6, 0)
            return num_pushed_input_args + extra_esp

    def test_one_call(self):
        ops = '''
        [i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i9b]
        i10 = call(ConstClass(f1ptr), i0, descr=f1_calldescr)
        guard_false(i10) [i10, i1, i2, i3, i4, i5, i6, i7, i8, i9, i9b]
        '''
        loop = self.interpret(ops, [4, 7, 9, 9 ,9, 9, 9, 9, 9, 9, 8])
        assert self.getints(11) == [5, 7, 9, 9, 9, 9, 9, 9, 9, 9, 8]
        clt = loop._jitcelltoken.compiled_loop_token
        assert clt.frame_depth == self.expected_frame_depth(1, 5)

    def test_one_call_reverse(self):
        ops = '''
        [i1, i2, i3, i4, i5, i6, i7, i8, i9, i9b, i0]
        i10 = call(ConstClass(f1ptr), i0, descr=f1_calldescr)
        guard_false(i10) [i10, i1, i2, i3, i4, i5, i6, i7, i8, i9, i9b]
        '''
        loop = self.interpret(ops, [7, 9, 9 ,9, 9, 9, 9, 9, 9, 8, 4])
        assert self.getints(11) == [5, 7, 9, 9, 9, 9, 9, 9, 9, 9, 8]
        clt = loop._jitcelltoken.compiled_loop_token
        assert clt.frame_depth == self.expected_frame_depth(1, 6)

    def test_two_calls(self):
        ops = '''
        [i0, i1,  i2, i3, i4, i5, i6, i7, i8, i9]
        i10 = call(ConstClass(f1ptr), i0, descr=f1_calldescr)
        i11 = call(ConstClass(f2ptr), i10, i1, descr=f2_calldescr)
        guard_false(i5) [i11, i1,  i2, i3, i4, i5, i6, i7, i8, i9]
        '''
        loop = self.interpret(ops, [4, 7, 9, 9 ,9, 9, 9, 9, 9, 9])
        assert self.getints(10) == [5*7, 7, 9, 9, 9, 9, 9, 9, 9, 9]
        clt = loop._jitcelltoken.compiled_loop_token
        assert clt.frame_depth == self.expected_frame_depth(2, 5)

    def test_call_many_arguments(self):
        # NB: The first and last arguments in the call are constants. This
        # is primarily for x86-64, to ensure that loading a constant to an
        # argument register or to the stack works correctly
        ops = '''
        [i0, i1, i2, i3, i4, i5, i6, i7]
        i8 = call(ConstClass(f10ptr), 1, i0, i1, i2, i3, i4, i5, i6, i7, 10, descr=f10_calldescr)
        finish(i8)
        '''
        loop = self.interpret(ops, [2, 3, 4, 5, 6, 7, 8, 9])
        assert self.getint(0) == 55
        clt = loop._jitcelltoken.compiled_loop_token
        assert clt.frame_depth == self.expected_frame_depth(10)

    def test_bridge_calls_1(self):
        ops = '''
        [i0, i1]
        i2 = call(ConstClass(f1ptr), i0, descr=f1_calldescr)
        guard_value(i2, 0, descr=fdescr1) [i2, i0, i1]
        guard_false(i1) [i1]
        '''
        loop = self.interpret(ops, [4, 7])
        assert self.getint(0) == 5
        clt = loop._jitcelltoken.compiled_loop_token
        orgdepth = clt.frame_depth
        assert orgdepth == self.expected_frame_depth(1, 2)

        ops = '''
        [i2, i0, i1]
        i3 = call(ConstClass(f2ptr), i2, i1, descr=f2_calldescr)
        guard_false(i0, descr=fdescr2) [i3, i0]
        '''
        bridge = self.attach_bridge(ops, loop, -2)

        assert clt.frame_depth == max(orgdepth, self.expected_frame_depth(2, 2))
        assert loop.operations[-2].getdescr()._x86_bridge_frame_depth == \
            self.expected_frame_depth(2, 2)

        self.run(loop, 4, 7)
        assert self.getint(0) == 5*7

    def test_bridge_calls_2(self):
        ops = '''
        [i0, i1]
        i2 = call(ConstClass(f2ptr), i0, i1, descr=f2_calldescr)
        guard_value(i2, 0, descr=fdescr1) [i2]
        guard_false(i2) [i2]
        '''
        loop = self.interpret(ops, [4, 7])
        assert self.getint(0) == 4*7
        clt = loop._jitcelltoken.compiled_loop_token
        orgdepth = clt.frame_depth
        assert orgdepth == self.expected_frame_depth(2)

        ops = '''
        [i2]
        i3 = call(ConstClass(f1ptr), i2, descr=f1_calldescr)
        guard_false(i3, descr=fdescr2) [i3]
        '''
        bridge = self.attach_bridge(ops, loop, -2)

        assert clt.frame_depth == max(orgdepth, self.expected_frame_depth(1))
        assert loop.operations[-2].getdescr()._x86_bridge_frame_depth == \
            self.expected_frame_depth(1)

        self.run(loop, 4, 7)
        assert self.getint(0) == 29

