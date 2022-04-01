""" explicit integration tests for register allocation in the x86 backend """

import pytest

from rpython.jit.backend.llsupport.test import test_regalloc_integration
from rpython.jit.backend.x86.assembler import Assembler386
from rpython.jit.backend.x86.arch import IS_X86_64, WIN64

class LogEntry(object):
    def __init__(self, position, name, *args):
        self.position = position
        self.name = name
        self.args = args

    def __repr__(self):
        r = repr(self.args)
        if self.name == "op":
            r = repr(self.args[1:])
            return "<%s: %s %s %s>" % (self.position, self.name, self.args[0], r.strip("(),"))
        return "<%s: %s %s>" % (self.position, self.name, r.strip("(),"))

class LoggingAssembler(Assembler386):
    def __init__(self, *args, **kwargs):
        self._instr_log = []
        Assembler386.__init__(self, *args, **kwargs)

    def _log(self, name, *args):
        self._instr_log.append(LogEntry(self._regalloc.rm.position, name, *args))

    def mov(self, from_loc, to_loc):
        self._log("mov", from_loc, to_loc)
        return Assembler386.mov(self, from_loc, to_loc)

    def regalloc_mov(self, from_loc, to_loc):
        self._log("mov", from_loc, to_loc)
        return Assembler386.mov(self, from_loc, to_loc)

    def regalloc_perform(self, op, arglocs, resloc):
        self._log("op", op.getopname(), arglocs, resloc)
        return Assembler386.regalloc_perform(self, op, arglocs, resloc)

    def regalloc_perform_discard(self, op, arglocs):
        self._log("op", op.getopname(), arglocs)
        return Assembler386.regalloc_perform_discard(self, op, arglocs)

    def regalloc_perform_guard(self, guard_op, faillocs, arglocs, resloc,
                               frame_depth):
        self._log("guard", guard_op.getopname(), arglocs, faillocs, resloc)
        return Assembler386.regalloc_perform_guard(self, guard_op, faillocs,
                arglocs, resloc, frame_depth)

    def malloc_cond(self, nursery_free_adr, nursery_top_adr, size, gcmap):
        self._log("malloc_cond", size, "ecx") # always uses edx and ecx

    def label(self):
        self._log("label", self._regalloc.final_jump_op.getdescr()._x86_arglocs)
        return Assembler386.label(self)

    def closing_jump(self, jump_target_descr):
        self._log("jump", self._regalloc.final_jump_op.getdescr()._x86_arglocs)
        return Assembler386.closing_jump(self, jump_target_descr)

class BaseTestCheckRegistersExplicitly(test_regalloc_integration.BaseTestRegalloc):
    def setup_class(cls):
        cls.cpu.assembler = LoggingAssembler(cls.cpu, False)
        cls.cpu.assembler.setup_once()

    def setup_method(self, meth):
        self.cpu.assembler._instr_log = self.log = []

    def teardown_method(self, meth):
        for l in self.log:
            print l

    def filter_log_moves(self):
        return [entry for entry in self.log if entry.name == "mov"]

class TestCheckRegistersExplicitly(BaseTestCheckRegistersExplicitly):
    def test_unused(self):
        ops = '''
        [i0, i1, i2, i3]
        i7 = int_add(i0, i1) # unused
        i9 = int_add(i2, i3)
        finish(i9)
        '''
        # does not crash
        self.interpret(ops, [5, 6, 7, 8])
        assert len([entry for entry in self.log if entry.args[0] == "int_add"]) == 1

    def test_bug_const(self):
        ops = '''
        [i0, i1, i2, i3]
        i9 = int_add(1, i3)
        finish(i9)
        '''
        # does not crash
        self.interpret(ops, [5, 6, 7, 8])
        assert len([entry for entry in self.log if entry.args[0] == "int_add"]) == 1

    def test_use_lea_even_for_stack(self):
        ops = '''
        [i0, i1, i2, i3]
        i9 = int_add(i3, 16)
        i4 = int_add(i3, 26)
        i6 = int_add(i9, i4)
        finish(i6)
        '''
        self.interpret(ops, [5, 6, 7, 8])
        assert len(self.filter_log_moves()) == 2

    def test_call_use_correct_regs(self):
        ops = '''
        [i0, i1, i2, i3]
        i7 = int_add(i0, i1)
        i8 = int_add(i2, 13)
        i9 = call_i(ConstClass(f1ptr), i7, descr=f1_calldescr)
        i10 = int_is_true(i9)
        guard_true(i10) [i8]
        finish(i9)
        '''
        self.interpret(ops, [5, 6, 7, 8])
        # two moves are needed from the stack frame to registers for arguments
        # i0 and i1, one for the result to the stack
        assert len(self.filter_log_moves()) == 3

    @pytest.mark.skip("later")
    def test_same_stack_entry_many_times(self):
        ops = '''
        [i0, i1, i2, i3]
        i7 = int_add(i0, i1)
        i8 = int_add(i2, i1)
        i9 = int_add(i3, i1)
        i10 = int_is_true(i9)
        guard_true(i10) [i8]
        finish(i7)
        '''
        self.interpret(ops, [5, 6, 7, 8])
        # 4 moves for arguments, 1 for result
        assert len(self.filter_log_moves()) == 5

    def test_coalescing(self):
        ops = '''
        [i0, i1, i3]
        i7 = int_add(i0, i1)
        i8 = int_add(i7, i3)
        i9 = call_i(ConstClass(f1ptr), i8, descr=f1_calldescr)
        i10 = int_is_true(i9)
        guard_true(i10) []
        finish(i9)
        '''
        self.interpret(ops, [5, 6, 8])
        # coalescing makes sure that i0 (and thus i8) lands in edi
        assert len(self.filter_log_moves()) == 2

    def test_coalescing_sub(self):
        ops = '''
        [i0, i1, i3]
        i7 = int_sub(i0, i1)
        i8 = int_sub(i7, i3)
        i9 = call_i(ConstClass(f1ptr), i8, descr=f1_calldescr)
        i10 = int_is_true(i9)
        guard_true(i10) []
        finish(i9)
        '''
        self.interpret(ops, [5, 6, 8])
        # coalescing makes sure that i7 (and thus i8) lands in edi
        assert len(self.filter_log_moves()) == 2

    def test_coalescing_mul(self):
        # won't test all symmetric operations, but at least check a second one
        ops = '''
        [i0, i1, i3]
        i7 = int_mul(i0, i1)
        i8 = int_mul(i7, i3)
        i9 = call_i(ConstClass(f1ptr), i8, descr=f1_calldescr)
        i10 = int_is_true(i9)
        guard_true(i10) []
        finish(i9)
        '''
        self.interpret(ops, [5, 6, 8])
        assert len(self.filter_log_moves()) == 2

    def test_lshift(self):
        ops = '''
        [i0, i1, i2, i3]
        i5 = int_add(i2, i3)
        i7 = int_lshift(i0, i5)
        i8 = int_lshift(i7, i3)
        i9 = call_i(ConstClass(f1ptr), 42, i8, descr=f2_calldescr)
        i10 = int_is_true(i9)
        guard_true(i10) []
        finish(i9)
        '''
        self.interpret(ops, [5, 6, 7, 8])
        # 3 moves for arguments, 1 move for the constant 42, 1 move for result
        assert len(self.filter_log_moves()) == 5

    def test_binop_dont_swap_unnecessarily(self):
        ops = '''
        [i0, i1, i2, i3]
        i7 = int_add(i0, i1)
        i8 = int_add(i2, 13)
        i9 = int_add(i7, i8)
        i10 = int_is_true(i9)
        guard_true(i10) []
        finish(i9)
        '''
        self.interpret(ops, [5, 6, 7, 8])
        add1 = self.log[2]
        op = self.log[5]
        assert op.name == "op"
        # make sure that the arguments of the third op are not swapped (since
        # that would break coalescing between i7 and i9)
        assert op.args[1][0] is add1.args[-1]

    def test_jump_hinting(self):
        self.targettoken._ll_loop_code = 0
        ops = '''
        [i0]
        i1 = int_add(i0, 1)
        i10 = int_add(i1, 1)
        i2 = int_add(i1, 1)
        i3 = int_lt(i2, 20)
        guard_true(i3) [i1, i10]
        label(i2, descr=targettoken)
        i4 = int_add(i2, 1)
        i11 = int_add(i4, 1)
        i5 = int_add(i4, 1)
        i6 = int_lt(i5, 20)
        guard_true(i6) [i4, i11]
        jump(i5, descr=targettoken)
        '''
        self.interpret(ops, [0], run=False)
        assert len(self.filter_log_moves()) == 1

    def test_jump_hinting_duplicate(self):
        self.targettoken._ll_loop_code = 0
        ops = '''
        [i0]
        i1 = int_add(i0, 1)
        i10 = int_add(i1, 1)
        i2 = int_add(i1, 1)
        i3 = int_lt(i2, 20)
        guard_true(i3) [i1, i10]
        label(i2, i10, descr=targettoken)
        i4 = int_add(i2, 1)
        i11 = int_add(i4, i10)
        i5 = int_add(i4, 1)
        i6 = int_lt(i5, 20)
        guard_true(i6) [i4, i11]
        jump(i5, i5, descr=targettoken)
        '''
        self.interpret(ops, [0], run=False)
        assert len(self.filter_log_moves()) == 3


    def test_jump_hinting_int_add(self):
        self.targettoken._ll_loop_code = 0
        ops = '''
        [i0]
        i1 = int_add(i0, 1)
        i3 = int_lt(i1, 20)
        guard_true(i3) [i1]
        label(i1, descr=targettoken)
        i4 = int_add(i1, 1)
        i6 = int_lt(i4, 20)
        guard_true(i6) [i4]
        jump(i4, descr=targettoken)
        '''
        self.interpret(ops, [0], run=False)
        assert len(self.filter_log_moves()) == 1

    @pytest.mark.skip("later")
    def test_jump_different_args2(self):
        ops = '''
        [i0, i4, i6]
        i1 = int_add(i0, i6)
        i2 = int_lt(i1, 20)
        guard_true(i2) [i1]
        label(i4, i1, i6, descr=targettoken)
        i3 = int_add(i4, i6)
        i7 = int_lt(i3, 20)
        guard_true(i7) [i3]
        jump(i1, i3, i6, descr=targettoken)
        '''
        self.interpret(ops, [0], run=False)


    def test_flowcontext(self):
        # real index manipulation for a slicing operation done when translating
        # on top of pypy
        ops = """
        [i1, i2]
        i3 = int_and(i1, 255)
        i4 = int_rshift(i1, 8)
        i5 = int_and(i4, 255)
        i6 = int_lt(0, i5)
        guard_false(i6) [i1]
        i7 = int_eq(i3, 0)
        guard_false(i7) [i1]
        i8 = int_neg(i3)
        i9 = int_lt(i8, 0)
        guard_true(i9) [i1]
        i10 = int_lt(i2, 0)
        guard_false(i10) [i1]
        i11 = int_add(i8, i2)
        i12 = int_lt(i11, 0)
        guard_false(i12) [i1]
        i13 = int_gt(i11, i2)
        guard_false(i13) [i1]
        i14 = int_sub(i2, i11)
        i15 = int_is_zero(i14)
        guard_false(i15) [i1]
        # this simulates the arraycopy call
        i16 = call_i(ConstClass(f2ptr), i11, i14, descr=f2_calldescr)
        finish(i16)
        """
        self.interpret(ops, [0], run=False)
        # 4 moves, three for args, one for result
        assert len(self.filter_log_moves()) == 4

class TestCheckRegistersExplicitly64(BaseTestCheckRegistersExplicitly):
    def setup_class(self):
        if not IS_X86_64:
            pytest.skip("needs 64 bit")

    def test_call_use_argument_twice(self):
        ops = '''
        [i0, i1, i2, i3]
        i7 = int_add(i0, i1)
        i8 = int_add(i2, 13)
        i9 = call_i(ConstClass(f2ptr), i7, i7, descr=f2_calldescr)
        i10 = int_is_true(i9)
        guard_true(i10) [i8]
        finish(i9)
        '''
        self.interpret(ops, [5, 6, 7, 8])
        # two moves are needed from the stack frame to registers for arguments
        # i0 and i1, one for the result to the stack
        # one for the copy to the other argument register
        assert len(self.filter_log_moves()) == 4

    def test_coalescing_float(self):
        ops = '''
        [f0, f1, f3]
        f7 = float_add(f0, f1)
        f8 = float_add(f7, f3)
        f9 = call_f(ConstClass(ffptr), f8, 1.0, descr=ff_calldescr)
        i10 = float_ne(f9, 0.0)
        guard_true(i10) []
        finish(f9)
        '''
        self.interpret(ops, [5.0, 6.0, 8.0])
        assert len(self.filter_log_moves()) == 3

    def test_malloc(self, monkeypatch):
        ops = '''
        [i0]
        i1 = int_add(i0, 1) # this is using ecx or edx because it fits
        i6 = int_add(i0, 6) # this is using ecx or edx because it fits
        i2 = int_add(i6, i1)
        p0 = call_malloc_nursery(16)
        gc_store(p0, 0, 83944, 8)
        gc_store(p0, 8, i2, 8)
        i10 = int_is_true(i2)
        guard_true(i10) [p0, i0]
        finish(p0)
        '''
        monkeypatch.setattr(self.cpu.gc_ll_descr, "get_nursery_top_addr", lambda: 61)
        monkeypatch.setattr(self.cpu.gc_ll_descr, "get_nursery_free_addr", lambda: 68)
        self.interpret(ops, [0], run=False)
        # 2 moves, because the call_malloc_nursery hints prevent using ecx and
        # edx for any of the integer results
        assert len(self.filter_log_moves()) == 2

    def test_dict_lookup(self, monkeypatch):
        monkeypatch.setattr(self.cpu.gc_ll_descr, "get_nursery_top_addr", lambda: 61)
        monkeypatch.setattr(self.cpu.gc_ll_descr, "get_nursery_free_addr", lambda: 68)
        # real trace for a dict lookup
        ops = """
        [i172, i182, i201, p209, p0, p219]
        i184 = int_lt(i172, 0)
        guard_false(i184) []
        i185 = int_ge(i172, i182)
        guard_false(i185) []
        i187 = int_add(i172, 1)
        i202 = uint_ge(i172, i201)
        guard_false(i202) [i172]
        i221 = int_xor(i172, 3430008)
        i223 = int_mul(i221, 1000003)
        i230 = call_i(ConstClass(fgcrefptr), p209, descr=fgcref_calldescr)
        guard_no_exception() [p209, i230, i172]
        i232 = int_eq(i230, -1)
        i233 = int_sub(i230, i232)
        i234 = int_xor(i223, i233)
        i236 = int_mul(i234, 1082525)
        i238 = int_add(i236, 97531)
        i240 = int_eq(i238, -1)
        i241 = int_sub(i238, i240)
        p242 = force_token()
        p244 = call_malloc_nursery(40)
        gc_store(p244, 0, 83568, 8)
        p249 = nursery_ptr_increment(p244, 24)
        gc_store(p249, 0, 4656, 8)
        gc_store(p249, 8, i172, 8)
        #cond_call_gc_wb(p0)
        gc_store(p0, 8, p242, 8)
        i263 = call_may_force_i(ConstClass(fppiiptr), p219, p244, i241, 0, descr=fppii_calldescr)
        guard_not_forced() [p0, p249, p244, i263, p219]
        guard_no_exception() [p0, p249, p244, i263, p219]
        i265 = int_lt(i263, 0)
        guard_true(i265) [p0, p249, p244, i263, p219]
        finish(i263)
        """
        self.interpret(ops, [0], run=False)
        # the moves are:
        # 5 arguments
        # 1 result
        # 1 because lifetime of i172 does not end at the int_xor
        # 1 ptr to save before call
        # 3 for argument shuffling

        # XXX there is an additional mov, find out why!
        if not WIN64:
            assert len(self.filter_log_moves()) == 12
        else:
            # on Win64 we get:
            # 5 arguments (including the constant 0)
            # 1 result
            # 1 because lifetime of i172 does not end at the int_xor
            # 2 ptrs to save before call (p249, p244)
            # 1 for argument shuffling (ecx => edx)
            assert len(self.filter_log_moves()) == 10
