
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rarithmetic import r_uint
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper import rclass
from rpython.jit.metainterp.history import (AbstractFailDescr, ConstInt,
                                            INT, FLOAT, REF, VOID)
from rpython.jit.backend.aarch64 import registers as r
from rpython.jit.backend.aarch64.codebuilder import OverwritingBuilder
from rpython.jit.backend.aarch64.callbuilder import Aarch64CallBuilder
from rpython.jit.backend.arm import conditions as c, shift
from rpython.jit.backend.aarch64.regalloc import check_imm_arg
from rpython.jit.backend.aarch64.arch import JITFRAME_FIXED_SIZE, WORD
from rpython.jit.backend.aarch64 import locations
from rpython.jit.backend.llsupport.assembler import GuardToken, BaseAssembler
from rpython.jit.backend.llsupport.gcmap import allocate_gcmap
from rpython.jit.backend.llsupport.regalloc import get_scale
from rpython.jit.metainterp.history import TargetToken
from rpython.jit.metainterp.resoperation import rop

def gen_comp_op(name, flag):
    def emit_op(self, op, arglocs):
        l0, l1, res = arglocs

        self.emit_int_comp_op(op, l0, l1)
        self.mc.CSET_r_flag(res.value, c.get_opposite_of(flag))
    emit_op.__name__ = name
    return emit_op

def gen_float_comp_op(name, flag):
    def emit_op(self, op, arglocs):
        l0, l1, res = arglocs
        self.emit_float_comp_op(op, l0, l1)
        self.mc.CSET_r_flag(res.value, c.get_opposite_of(flag))
    emit_op.__name__ = name
    return emit_op        

def gen_float_comp_op_cc(name, flag):
    def emit_op(self, op, arglocs):
        l0, l1 = arglocs
        self.emit_float_comp_op(op, l0, l1)
        return flag
    emit_op.__name__ = name
    return emit_op        

class ResOpAssembler(BaseAssembler):
    def imm(self, v):
        return locations.imm(v)

    def int_sub_impl(self, op, arglocs, flags=0):
        l0, l1, res = arglocs
        if flags:
            s = 1
        else:
            s = 0
        if l1.is_imm():
            value = l1.getint()
            assert value >= 0
            self.mc.SUB_ri(res.value, l0.value, value, s)
        else:
            self.mc.SUB_rr(res.value, l0.value, l1.value, s)

    def emit_op_int_sub(self, op, arglocs):
        self.int_sub_impl(op, arglocs)

    def int_add_impl(self, op, arglocs, ovfcheck=False):
        l0, l1, res = arglocs
        assert not l0.is_imm()
        if ovfcheck:
            s = 1
        else:
            s = 0
        if l1.is_imm():
            self.mc.ADD_ri(res.value, l0.value, l1.value, s)
        else:
            self.mc.ADD_rr(res.value, l0.value, l1.value, s)

    def emit_op_int_add(self, op, arglocs):
        self.int_add_impl(op, arglocs)
    emit_op_nursery_ptr_increment = emit_op_int_add

    def emit_comp_op_int_add_ovf(self, op, arglocs):
        self.int_add_impl(op, arglocs, True)
        return 0

    def emit_comp_op_int_sub_ovf(self, op, arglocs):
        self.int_sub_impl(op, arglocs, True)
        return 0

    def emit_op_int_mul(self, op, arglocs):
        reg1, reg2, res = arglocs
        self.mc.MUL_rr(res.value, reg1.value, reg2.value)

    def emit_comp_op_int_mul_ovf(self, op, arglocs):
        reg1, reg2, res = arglocs
        self.mc.SMULH_rr(r.ip0.value, reg1.value, reg2.value)
        self.mc.MUL_rr(res.value, reg1.value, reg2.value)
        self.mc.CMP_rr_shifted(r.ip0.value, res.value, 63)
        return 0

    def emit_op_int_and(self, op, arglocs):
        l0, l1, res = arglocs
        self.mc.AND_rr(res.value, l0.value, l1.value)

    def emit_op_int_or(self, op, arglocs):
        l0, l1, res = arglocs
        self.mc.ORR_rr(res.value, l0.value, l1.value)

    def emit_op_int_xor(self, op, arglocs):
        l0, l1, res = arglocs
        self.mc.EOR_rr(res.value, l0.value, l1.value)

    def emit_op_int_lshift(self, op, arglocs):
        l0, l1, res = arglocs
        self.mc.LSL_rr(res.value, l0.value, l1.value)

    def emit_op_int_rshift(self, op, arglocs):
        l0, l1, res = arglocs
        self.mc.ASR_rr(res.value, l0.value, l1.value)

    def emit_op_uint_rshift(self, op, arglocs):
        l0, l1, res = arglocs
        self.mc.LSR_rr(res.value, l0.value, l1.value)

    def emit_op_uint_mul_high(self, op, arglocs):
        l0, l1, res = arglocs
        self.mc.UMULH_rr(res.value, l0.value, l1.value)

    def emit_int_comp_op(self, op, l0, l1):
        if l1.is_imm():
            self.mc.CMP_ri(l0.value, l1.getint())
        else:
            self.mc.CMP_rr(l0.value, l1.value)

    def emit_float_comp_op(self, op, l0, l1):
        self.mc.FCMP_dd(l0.value, l1.value)

    emit_comp_op_float_lt = gen_float_comp_op_cc('float_lt', c.VFP_LT)
    emit_comp_op_float_le = gen_float_comp_op_cc('float_le', c.VFP_LE)
    emit_comp_op_float_eq = gen_float_comp_op_cc('float_eq', c.EQ)
    emit_comp_op_float_ne = gen_float_comp_op_cc('float_ne', c.NE)
    emit_comp_op_float_gt = gen_float_comp_op_cc('float_gt', c.GT)
    emit_comp_op_float_ge = gen_float_comp_op_cc('float_ge', c.GE)

    def emit_comp_op_int_lt(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.LT

    def emit_comp_op_int_le(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.LE

    def emit_comp_op_int_gt(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.GT

    def emit_comp_op_int_ge(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.GE

    def emit_comp_op_int_eq(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.EQ

    emit_comp_op_ptr_eq = emit_comp_op_instance_ptr_eq = emit_comp_op_int_eq

    def emit_comp_op_int_ne(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.NE

    emit_comp_op_ptr_ne = emit_comp_op_instance_ptr_ne = emit_comp_op_int_ne

    def emit_comp_op_uint_lt(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.LO

    def emit_comp_op_uint_le(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.LS

    def emit_comp_op_uint_gt(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.HI

    def emit_comp_op_uint_ge(self, op, arglocs):
        self.emit_int_comp_op(op, arglocs[0], arglocs[1])
        return c.HS

    emit_op_int_lt = gen_comp_op('emit_op_int_lt', c.LT)
    emit_op_int_le = gen_comp_op('emit_op_int_le', c.LE)
    emit_op_int_gt = gen_comp_op('emit_op_int_gt', c.GT)
    emit_op_int_ge = gen_comp_op('emit_op_int_ge', c.GE)
    emit_op_int_eq = gen_comp_op('emit_op_int_eq', c.EQ)
    emit_op_int_ne = gen_comp_op('emit_op_int_ne', c.NE)

    emit_op_uint_lt = gen_comp_op('emit_op_uint_lt', c.LO)
    emit_op_uint_gt = gen_comp_op('emit_op_uint_gt', c.HI)
    emit_op_uint_le = gen_comp_op('emit_op_uint_le', c.LS)
    emit_op_uint_ge = gen_comp_op('emit_op_uint_ge', c.HS)

    emit_op_ptr_eq = emit_op_instance_ptr_eq = emit_op_int_eq
    emit_op_ptr_ne = emit_op_instance_ptr_ne = emit_op_int_ne

    def emit_op_int_is_true(self, op, arglocs):
        reg, res = arglocs

        self.mc.CMP_ri(reg.value, 0)
        self.mc.CSET_r_flag(res.value, c.EQ)

    def emit_comp_op_int_is_true(self, op, arglocs):
        self.mc.CMP_ri(arglocs[0].value, 0)
        return c.NE

    def emit_op_int_is_zero(self, op, arglocs):
        reg, res = arglocs

        self.mc.CMP_ri(reg.value, 0)
        self.mc.CSET_r_flag(res.value, c.NE)

    def emit_comp_op_int_is_zero(self, op, arglocs):
        self.mc.CMP_ri(arglocs[0].value, 0)
        return c.EQ

    def emit_op_int_neg(self, op, arglocs):
        reg, res = arglocs
        self.mc.SUB_rr_shifted(res.value, r.xzr.value, reg.value)

    def emit_op_int_invert(self, op, arglocs):
        reg, res = arglocs
        self.mc.MVN_rr(res.value, reg.value)

    def emit_op_int_force_ge_zero(self, op, arglocs):
        arg, res = arglocs
        self.mc.MOVZ_r_u16(res.value, 0, 0)
        self.mc.CMP_ri(arg.value, 0)
        self.mc.B_ofs_cond(8, c.LT) # jump over the next instruction
        self.mc.MOV_rr(res.value, arg.value)
        # jump here

    def emit_op_int_signext(self, op, arglocs):
        arg, numbytes, res = arglocs
        assert numbytes.is_imm()
        if numbytes.value == 1:
            self.mc.SXTB_rr(res.value, arg.value)
        elif numbytes.value == 2:
            self.mc.SXTH_rr(res.value, arg.value)
        elif numbytes.value == 4:
            self.mc.SXTW_rr(res.value, arg.value)
        else:
            raise AssertionError("bad number of bytes")

    def emit_op_increment_debug_counter(self, op, arglocs):
        base_loc, value_loc = arglocs
        self.mc.LDR_ri(value_loc.value, base_loc.value, 0)
        self.mc.ADD_ri(value_loc.value, value_loc.value, 1)
        self.mc.STR_ri(value_loc.value, base_loc.value, 0)

    def emit_op_check_memory_error(self, op, arglocs):
        self.propagate_memoryerror_if_reg_is_null(arglocs[0])

    def _genop_same_as(self, op, arglocs):
        argloc, resloc = arglocs
        if argloc is not resloc:
            self.mov_loc_loc(argloc, resloc)

    emit_op_same_as_i = _genop_same_as
    emit_op_same_as_r = _genop_same_as
    emit_op_same_as_f = _genop_same_as
    emit_op_cast_ptr_to_int = _genop_same_as
    emit_op_cast_int_to_ptr = _genop_same_as

    def emit_op_float_add(self, op, arglocs):
        arg1, arg2, res = arglocs
        self.mc.FADD_dd(res.value, arg1.value, arg2.value)

    def emit_op_float_sub(self, op, arglocs):
        arg1, arg2, res = arglocs
        self.mc.FSUB_dd(res.value, arg1.value, arg2.value)    

    def emit_op_float_mul(self, op, arglocs):
        arg1, arg2, res = arglocs
        self.mc.FMUL_dd(res.value, arg1.value, arg2.value)    

    def emit_op_float_truediv(self, op, arglocs):
        arg1, arg2, res = arglocs
        self.mc.FDIV_dd(res.value, arg1.value, arg2.value)

    def emit_op_convert_float_bytes_to_longlong(self, op, arglocs):
        arg, res = arglocs
        self.mc.UMOV_rd(res.value, arg.value)

    def emit_op_convert_longlong_bytes_to_float(self, op, arglocs):
        arg, res = arglocs
        self.mc.INS_dr(res.value, arg.value)

    def math_sqrt(self, op, arglocs):
        arg, res = arglocs
        self.mc.FSQRT_dd(res.value, arg.value)

    def threadlocalref_get(self, op, arglocs):
        res_loc, = arglocs
        ofs_loc = self.imm(op.getarg(1).getint())
        calldescr = op.getdescr()
        ofs = self.saved_threadlocal_addr
        self.load_reg(self.mc, res_loc, r.sp, ofs)
        scale = get_scale(calldescr.get_result_size())
        signed = (calldescr.is_result_signed() != 0)
        self._load_from_mem(res_loc, res_loc, ofs_loc, scale, signed)

    emit_op_float_lt = gen_float_comp_op('float_lt', c.VFP_LT)
    emit_op_float_le = gen_float_comp_op('float_le', c.VFP_LE)
    emit_op_float_eq = gen_float_comp_op('float_eq', c.EQ)
    emit_op_float_ne = gen_float_comp_op('float_ne', c.NE)
    emit_op_float_gt = gen_float_comp_op('float_gt', c.GT)
    emit_op_float_ge = gen_float_comp_op('float_ge', c.GE)

    def emit_op_float_neg(self, op, arglocs):
        arg, res = arglocs
        self.mc.FNEG_d(res.value, arg.value)

    def emit_op_float_abs(self, op, arglocs):
        arg, res = arglocs
        self.mc.FABS_d(res.value, arg.value)        

    def emit_op_cast_float_to_int(self, op, arglocs):
        arg, res = arglocs
        self.mc.FCVTZS_d(res.value, arg.value)

    def emit_op_cast_int_to_float(self, op, arglocs):
        arg, res = arglocs
        self.mc.SCVTF_r(res.value, arg.value)

    def emit_op_load_from_gc_table(self, op, arglocs):
        res_loc, = arglocs
        index = op.getarg(0).getint()
        self.load_from_gc_table(res_loc.value, index)

    def emit_op_load_effective_address(self, op, arglocs):
        self._gen_address(arglocs[4], arglocs[0], arglocs[1], arglocs[3].value,
                          arglocs[2].value)

   # result = base_loc  + (scaled_loc << scale) + static_offset
    def _gen_address(self, result, base_loc, scaled_loc, scale=0, static_offset=0):
        assert scaled_loc.is_core_reg()
        assert base_loc.is_core_reg()
        if scale > 0:
            self.mc.LSL_ri(r.ip0.value, scaled_loc.value, scale)
            scaled_loc = r.ip0
        else:
            scaled_loc = scaled_loc
        self.mc.ADD_rr(result.value, base_loc.value, scaled_loc.value)
        self.mc.ADD_ri(result.value, result.value, static_offset)

    def emit_op_debug_merge_point(self, op, arglocs):
        pass
    
    emit_op_jit_debug = emit_op_debug_merge_point
    emit_op_keepalive = emit_op_debug_merge_point
    emit_op_enter_portal_frame = emit_op_debug_merge_point
    emit_op_leave_portal_frame = emit_op_debug_merge_point


    # -------------------------------- fields -------------------------------

    def emit_op_gc_store(self, op, arglocs):
        value_loc, base_loc, ofs_loc, size_loc = arglocs
        scale = get_scale(size_loc.value)
        self._write_to_mem(value_loc, base_loc, ofs_loc, scale)

    def _emit_op_gc_load(self, op, arglocs):
        base_loc, ofs_loc, res_loc, nsize_loc = arglocs
        nsize = nsize_loc.value
        signed = (nsize < 0)
        scale = get_scale(abs(nsize))
        self._load_from_mem(res_loc, base_loc, ofs_loc, scale, signed)

    emit_op_gc_load_i = _emit_op_gc_load
    emit_op_gc_load_r = _emit_op_gc_load
    emit_op_gc_load_f = _emit_op_gc_load

    def emit_op_gc_store_indexed(self, op, arglocs):
        value_loc, base_loc, index_loc, size_loc, ofs_loc = arglocs
        assert index_loc.is_core_reg()
        # add the base offset
        if ofs_loc.value != 0:
            if check_imm_arg(ofs_loc.value):
                self.mc.ADD_ri(r.ip0.value, index_loc.value, ofs_loc.value)
            else:
                # ofs_loc.value is too large for an ADD_ri
                self.load(r.ip0, ofs_loc)
                self.mc.ADD_rr(r.ip0.value, r.ip0.value, index_loc.value)
            index_loc = r.ip0
        scale = get_scale(size_loc.value)
        self._write_to_mem(value_loc, base_loc, index_loc, scale)

    def _emit_op_gc_load_indexed(self, op, arglocs):
        res_loc, base_loc, index_loc, nsize_loc, ofs_loc = arglocs
        assert index_loc.is_core_reg()
        nsize = nsize_loc.value
        signed = (nsize < 0)
        # add the base offset
        if ofs_loc.value != 0:
            if check_imm_arg(ofs_loc.value):
                self.mc.ADD_ri(r.ip0.value, index_loc.value, ofs_loc.value)
            else:
                # ofs_loc.value is too large for an ADD_ri
                self.load(r.ip0, ofs_loc)
                self.mc.ADD_rr(r.ip0.value, r.ip0.value, index_loc.value)
            index_loc = r.ip0
        #
        scale = get_scale(abs(nsize))
        self._load_from_mem(res_loc, base_loc, index_loc, scale, signed)

    emit_op_gc_load_indexed_i = _emit_op_gc_load_indexed
    emit_op_gc_load_indexed_r = _emit_op_gc_load_indexed
    emit_op_gc_load_indexed_f = _emit_op_gc_load_indexed

    def _write_to_mem(self, value_loc, base_loc, ofs_loc, scale):
        # Write a value of size '1 << scale' at the address
        # 'base_ofs + ofs_loc'.  Note that 'scale' is not used to scale
        # the offset!
        assert base_loc.is_core_reg()
        if scale == 3:
            # WORD size
            if value_loc.is_float():
                if ofs_loc.is_imm():
                    self.mc.STR_di(value_loc.value, base_loc.value,
                                    ofs_loc.value)
                else:
                    self.mc.STR_dd(value_loc.value, base_loc.value,
                                   ofs_loc.value)
                return
            if ofs_loc.is_imm():
                self.mc.STR_ri(value_loc.value, base_loc.value,
                                ofs_loc.value)
            else:
                self.mc.STR_size_rr(3, value_loc.value, base_loc.value,
                                    ofs_loc.value)
        else:
            if ofs_loc.is_imm():
                self.mc.STR_size_ri(scale, value_loc.value, base_loc.value,
                                     ofs_loc.value)
            else:
                self.mc.STR_size_rr(scale, value_loc.value, base_loc.value,
                                     ofs_loc.value)

    def _load_from_mem(self, res_loc, base_loc, ofs_loc, scale,
                                            signed=False):
        # Load a value of '1 << scale' bytes, from the memory location
        # 'base_loc + ofs_loc'.  Note that 'scale' is not used to scale
        # the offset!
        #
        if scale == 3:
            # WORD
            if res_loc.is_float():
                if ofs_loc.is_imm():
                    self.mc.LDR_di(res_loc.value, base_loc.value, ofs_loc.value)
                else:
                    self.mc.LDR_dr(res_loc.value, base_loc.value, ofs_loc.value)
                return
            if ofs_loc.is_imm():
                self.mc.LDR_ri(res_loc.value, base_loc.value, ofs_loc.value)
            else:
                self.mc.LDR_rr(res_loc.value, base_loc.value, ofs_loc.value)
            return
        if scale == 2:
            # 32bit int
            if not signed:
                if ofs_loc.is_imm():
                    self.mc.LDR_uint32_ri(res_loc.value, base_loc.value,
                                          ofs_loc.value)
                else:
                    self.mc.LDR_uint32_rr(res_loc.value, base_loc.value,
                                          ofs_loc.value)
            else:
                if ofs_loc.is_imm():
                    self.mc.LDRSW_ri(res_loc.value, base_loc.value,
                                             ofs_loc.value)
                else:
                    self.mc.LDRSW_rr(res_loc.value, base_loc.value,
                                             ofs_loc.value)
            return
        if scale == 1:
            # short
            if not signed:
                if ofs_loc.is_imm():
                    self.mc.LDRH_ri(res_loc.value, base_loc.value, ofs_loc.value)
                else:
                    self.mc.LDRH_rr(res_loc.value, base_loc.value, ofs_loc.value)
            else:
                if ofs_loc.is_imm():
                    self.mc.LDRSH_ri(res_loc.value, base_loc.value, ofs_loc.value)
                else:
                    self.mc.LDRSH_rr(res_loc.value, base_loc.value, ofs_loc.value)
            return
        assert scale == 0
        if not signed:
            if ofs_loc.is_imm():
                self.mc.LDRB_ri(res_loc.value, base_loc.value, ofs_loc.value)
            else:
                self.mc.LDRB_rr(res_loc.value, base_loc.value, ofs_loc.value)
        else:
            if ofs_loc.is_imm():
                self.mc.LDRSB_ri(res_loc.value, base_loc.value, ofs_loc.value)
            else:
                self.mc.LDRSB_rr(res_loc.value, base_loc.value, ofs_loc.value)

    # -------------------------------- guard --------------------------------

    def build_guard_token(self, op, frame_depth, arglocs, offset, fcond,
                          extra_offset=-1, extra_cond=-1):
        descr = op.getdescr()
        assert isinstance(descr, AbstractFailDescr)

        gcmap = allocate_gcmap(self, frame_depth, JITFRAME_FIXED_SIZE)
        faildescrindex = self.get_gcref_from_faildescr(descr)
        token = GuardToken(self.cpu, gcmap, descr,
                                    failargs=op.getfailargs(),
                                    fail_locs=arglocs,
                                    guard_opnum=op.getopnum(),
                                    frame_depth=frame_depth,
                                    faildescrindex=faildescrindex)
        token.fcond = fcond
        token.extra_offset = extra_offset
        token.extra_cond = extra_cond
        return token

    def _emit_guard(self, op, fcond, arglocs, is_guard_not_invalidated=False,
                    extra_offset=-1, extra_cond=-1):
        pos = self.mc.currpos()
        token = self.build_guard_token(op, arglocs[0].value, arglocs[1:], pos,
                                       fcond, extra_offset, extra_cond)
        token.offset = pos
        self.pending_guards.append(token)
        assert token.guard_not_invalidated() == is_guard_not_invalidated
        # For all guards that are not GUARD_NOT_INVALIDATED we emit a
        # breakpoint to ensure the location is patched correctly. In the case
        # of GUARD_NOT_INVALIDATED we use just a NOP, because it is only
        # eventually patched at a later point.
        if is_guard_not_invalidated:
            self.mc.NOP()
        else:
            self.mc.BRK()

    def emit_guard_op_guard_true(self, op, guard_op, fcond, arglocs):
        self._emit_guard(guard_op, fcond, arglocs)
    emit_guard_op_guard_no_overflow = emit_guard_op_guard_true

    def emit_guard_op_guard_false(self, op, guard_op, fcond, arglocs):
        self._emit_guard(guard_op, c.get_opposite_of(fcond), arglocs)
    emit_guard_op_guard_overflow = emit_guard_op_guard_false

    def emit_op_guard_not_invalidated(self, op, arglocs):
        self._emit_guard(op, 0, arglocs, True)

    def load_condition_into_cc(self, loc):
        if not loc.is_core_reg():
            if loc.is_stack():
                self.regalloc_mov(loc, r.ip0)
            else:
                assert loc.is_imm()
                self.mc.gen_load_int(r.ip0.value, loc.value)
            loc = r.ip0
        self.mc.CMP_ri(loc.value, 0)

    def emit_op_guard_false(self, op, arglocs):
        self.load_condition_into_cc(arglocs[0])
        self._emit_guard(op, c.EQ, arglocs[1:])
    emit_op_guard_isnull = emit_op_guard_false

    def emit_op_guard_true(self, op, arglocs):
        self.load_condition_into_cc(arglocs[0])
        self._emit_guard(op, c.NE, arglocs[1:])
    emit_op_guard_nonnull = emit_op_guard_true

    def emit_op_guard_value(self, op, arglocs):
        v0 = arglocs[0]
        v1 = arglocs[1]
        if v0.is_core_reg():
            if v1.is_core_reg():
                loc = v1
            elif v1.is_imm():
                self.mc.gen_load_int(r.ip0.value, v1.value)
                loc = r.ip0
            else:
                assert v1.is_stack()
                self.mc.LDR_ri(r.ip0.value, r.fp.value, v1.value)
                loc = r.ip0
            self.mc.CMP_rr(v0.value, loc.value)
        else:
            assert v0.is_vfp_reg()
            if v1.is_vfp_reg():
                loc = v1
            else:
                assert v1.is_stack()
                loc = r.vfp_ip
                self.mc.LDR_di(r.vfp_ip.value, r.fp.value, v1.value)
            self.mc.FCMP_dd(v0.value, loc.value)
        self._emit_guard(op, c.EQ, arglocs[2:])

    def emit_op_guard_class(self, op, arglocs):
        offset = self.cpu.vtable_offset
        if offset is not None:
            self.mc.LDR_ri(r.ip0.value, arglocs[0].value, offset)
            self.mc.gen_load_int(r.ip1.value, arglocs[1].value)
            self.mc.CMP_rr(r.ip0.value, r.ip1.value)
        else:
            expected_typeid = (self.cpu.gc_ll_descr
                    .get_typeid_from_classptr_if_gcremovetypeptr(arglocs[1].value))
            self._cmp_guard_gc_type(arglocs[0], expected_typeid)
        self._emit_guard(op, c.EQ, arglocs[2:])

    def _cmp_guard_gc_type(self, loc_ptr, expected_typeid):
        # Note that the typeid half-word is at offset 0 on a little-endian
        # machine; it would be at offset 2 or 4 on a big-endian machine.
        assert self.cpu.supports_guard_gc_type
        self.mc.LDR_uint32_ri(r.ip0.value, loc_ptr.value, 0)
        self.mc.gen_load_int(r.ip1.value, expected_typeid)
        self.mc.CMP_rr(r.ip0.value, r.ip1.value)

    def emit_op_guard_nonnull_class(self, op, arglocs):
        offset = self.cpu.vtable_offset
        if offset is not None:
            # this is inefficient, but does not matter since translation
            # is always with gcremovetypeptr
            self.mc.MOVZ_r_u16(r.ip0.value, 1, 0)
            self.mc.MOVZ_r_u16(r.ip1.value, 0, 0)
            self.mc.CMP_ri(arglocs[0].value, 0)
            self.mc.B_ofs_cond(4 * (4 + 2), c.EQ)
            self.mc.LDR_ri(r.ip0.value, arglocs[0].value, offset)
            self.mc.gen_load_int_full(r.ip1.value, arglocs[1].value)
            self.mc.CMP_rr(r.ip0.value, r.ip1.value)
            self._emit_guard(op, c.EQ, arglocs[2:])     
        else:
            self.mc.CMP_ri(arglocs[0].value, 0)
            extra_offset = self.mc.currpos()
            self.mc.BRK()
            expected_typeid = (self.cpu.gc_ll_descr
                    .get_typeid_from_classptr_if_gcremovetypeptr(arglocs[1].value))
            self._cmp_guard_gc_type(arglocs[0], expected_typeid)
            self._emit_guard(op, c.EQ, arglocs[2:], False, extra_offset, c.NE)

    def emit_op_guard_gc_type(self, op, arglocs):
        self._cmp_guard_gc_type(arglocs[0], arglocs[1].value)
        self._emit_guard(op, c.EQ, arglocs[2:])

    def emit_op_guard_is_object(self, op, arglocs):
        assert self.cpu.supports_guard_gc_type
        loc_object = arglocs[0]
        # idea: read the typeid, fetch one byte of the field 'infobits' from
        # the big typeinfo table, and check the flag 'T_IS_RPYTHON_INSTANCE'.
        self.mc.LDR_uint32_ri(r.ip0.value, loc_object.value, 0)
        #

        base_type_info, shift_by, sizeof_ti = (
            self.cpu.gc_ll_descr.get_translated_info_for_typeinfo())
        infobits_offset, IS_OBJECT_FLAG = (
            self.cpu.gc_ll_descr.get_translated_info_for_guard_is_object())

        self.mc.gen_load_int(r.ip1.value, base_type_info + infobits_offset)
        if shift_by > 0:
            self.mc.LSL_ri(r.ip0.value, r.ip0.value, shift_by)
        self.mc.LDRB_rr(r.ip0.value, r.ip0.value, r.ip1.value)
        self.mc.MOVZ_r_u16(r.ip1.value, IS_OBJECT_FLAG & 0xff, 0)
        self.mc.TST_rr_shift(r.ip0.value, r.ip1.value, 0)
        self._emit_guard(op, c.NE, arglocs[1:])

    def emit_op_guard_subclass(self, op, arglocs):
        assert self.cpu.supports_guard_gc_type
        loc_object = arglocs[0]
        loc_check_against_class = arglocs[1]
        offset = self.cpu.vtable_offset
        offset2 = self.cpu.subclassrange_min_offset
        if offset is not None:
            # read this field to get the vtable pointer
            self.mc.LDR_ri(r.ip0.value, loc_object.value, offset)
            # read the vtable's subclassrange_min field
            self.mc.LDR_ri(r.ip0.value, r.ip0.value, offset2)
        else:
            # read the typeid
            self.mc.LDR_uint32_ri(r.ip0.value, loc_object.value, 0)
            # read the vtable's subclassrange_min field, as a single
            # step with the correct offset
            base_type_info, shift_by, sizeof_ti = (
                self.cpu.gc_ll_descr.get_translated_info_for_typeinfo())

            self.mc.gen_load_int(r.ip1.value,
                                 base_type_info + sizeof_ti + offset2)
            if shift_by > 0:
                self.mc.LSL_ri(r.ip0.value, r.ip0.value, shift_by)
            self.mc.LDR_rr(r.ip0.value, r.ip0.value, r.ip1.value)

        # get the two bounds to check against
        vtable_ptr = loc_check_against_class.getint()
        vtable_ptr = rffi.cast(rclass.CLASSTYPE, vtable_ptr)
        check_min = vtable_ptr.subclassrange_min
        check_max = vtable_ptr.subclassrange_max
        assert check_max > check_min
        check_diff = check_max - check_min - 1
        # check by doing the unsigned comparison (tmp - min) < (max - min)
        self.mc.gen_load_int(r.ip1.value, check_min)
        self.mc.SUB_rr(r.ip0.value, r.ip0.value, r.ip1.value)
        if check_diff <= 0xff:
            self.mc.CMP_ri(r.ip0.value, check_diff)
        else:
            self.mc.gen_load_int(r.ip1.value, check_diff)
            self.mc.CMP_rr(r.ip0.value, r.ip1.value)
        # the guard passes if we get a result of "below or equal"
        self._emit_guard(op, c.LS, arglocs[2:])

    def emit_op_guard_exception(self, op, arglocs):
        loc, resloc, pos_exc_value, pos_exception = arglocs[:4]
        failargs = arglocs[4:]
        self.mc.gen_load_int(r.ip1.value, pos_exception.value)
        self.mc.LDR_ri(r.ip0.value, r.ip1.value, 0)

        self.mc.CMP_rr(r.ip0.value, loc.value)
        self._emit_guard(op, c.EQ, failargs)
        self._store_and_reset_exception(self.mc, resloc)

    def emit_op_guard_no_exception(self, op, arglocs):
        loc = arglocs[0]
        failargs = arglocs[1:]
        self.mc.LDR_ri(loc.value, loc.value, 0)
        self.mc.CMP_ri(loc.value, 0)
        self._emit_guard(op, c.EQ, failargs)
        # If the previous operation was a COND_CALL, overwrite its conditional
        # jump to jump over this GUARD_NO_EXCEPTION as well, if we can
        #if self._find_nearby_operation(-1).getopnum() == rop.COND_CALL:
        #    XXX
        #    jmp_adr, prev_cond = self.previous_cond_call_jcond
        #    pmc = OverwritingBuilder(self.mc, jmp_adr, WORD)
        #    pmc.B_offs(self.mc.currpos(), prev_cond)

    def emit_op_save_exc_class(self, op, arglocs):
        resloc = arglocs[0]
        self.mc.gen_load_int(r.ip0.value, self.cpu.pos_exception())
        self.load_reg(self.mc, resloc, r.ip0)

    def emit_op_save_exception(self, op, arglocs):
        resloc = arglocs[0]
        self._store_and_reset_exception(self.mc, resloc)

    def emit_op_restore_exception(self, op, arglocs):
        self._restore_exception(self.mc, arglocs[1], arglocs[0])

    def emit_op_cond_call_gc_wb(self, op, arglocs):
        self._write_barrier_fastpath(self.mc, op.getdescr(), arglocs)

    def emit_op_cond_call_gc_wb_array(self, op, arglocs):
        self._write_barrier_fastpath(self.mc, op.getdescr(), arglocs,
                                     array=True)

        #from ../x86/regalloc.py:1388
    def emit_op_zero_array(self, op, arglocs):
        from rpython.jit.backend.llsupport.descr import unpack_arraydescr
        assert len(arglocs) == 0
        size_box = op.getarg(2)
        if isinstance(size_box, ConstInt) and size_box.getint() == 0:
            return
        itemsize, baseofs, _ = unpack_arraydescr(op.getdescr())
        args = op.getarglist()
        #
        # ZERO_ARRAY(base_loc, start, size, 1, 1)
        # 'start' and 'size' are both expressed in bytes,
        # and the two scaling arguments should always be ConstInt(1) on ARM.
        assert args[3].getint() == 1
        assert args[4].getint() == 1
        #
        base_loc = self._regalloc.rm.make_sure_var_in_reg(args[0], args)
        startbyte_box = args[1]
        if isinstance(startbyte_box, ConstInt):
            startbyte_loc = None
            startbyte = startbyte_box.getint()
            assert startbyte >= 0
        else:
            startbyte_loc = self._regalloc.rm.make_sure_var_in_reg(startbyte_box,
                                                                   args)
            startbyte = -1

        # base_loc and startbyte_loc are in two regs here (or startbyte_loc
        # is an immediate).  Compute the dstaddr_loc, which is the raw
        # address that we will pass as first argument to memset().
        # It can be in the same register as either one, but not in
        # args[2], because we're still needing the latter.
        dstaddr_loc = r.ip1
        if startbyte >= 0:    # a constant
            ofs = baseofs + startbyte
            reg = base_loc.value
        else:
            self.mc.ADD_rr(dstaddr_loc.value,
                           base_loc.value, startbyte_loc.value)
            ofs = baseofs
            reg = dstaddr_loc.value
        if check_imm_arg(ofs):
            self.mc.ADD_ri(dstaddr_loc.value, reg, ofs)
        else:
            self.mc.gen_load_int(r.ip0.value, ofs)
            self.mc.ADD_rr(dstaddr_loc.value, reg, r.ip0.value)

        # We use STRB, STRH, STRW or STR based on whether we know the array
        # item size is a multiple of 1, 2 or 4.
        if   itemsize & 1: itemsize = 1
        elif itemsize & 2: itemsize = 2
        elif itemsize & 4: itemsize = 4
        else:              itemsize = 8
        limit = itemsize
        next_group = -1
        if itemsize < 8 and startbyte >= 0:
            # we optimize STRB/STRH into STR, but this needs care:
            # it only works if startindex_loc is a constant, otherwise
            # we'd be doing unaligned accesses.
            next_group = (-startbyte) & 7
            limit = 8

        if (isinstance(size_box, ConstInt) and
                size_box.getint() <= 14 * limit):     # same limit as GCC
            # Inline a series of STR operations, starting at 'dstaddr_loc'.
            #
            self.mc.gen_load_int(r.ip0.value, 0)
            i = dst_i = 0
            total_size = size_box.getint()
            while i < total_size:
                sz = itemsize
                if i == next_group:
                    next_group += 8
                    if next_group <= total_size:
                        sz = 8
                        if dst_i % 8:   # unaligned?
                            self.mc.ADD_ri(dstaddr_loc.value, dstaddr_loc.value, dst_i)
                            dst_i = 0
                if sz == 8:
                    self.mc.STR_ri(r.ip0.value, dstaddr_loc.value, dst_i)
                elif sz == 4:
                    self.mc.STRW_ri(r.ip0.value, dstaddr_loc.value, dst_i)
                elif sz == 2:
                    self.mc.STRH_ri(r.ip0.value, dstaddr_loc.value, dst_i)
                else:
                    self.mc.STRB_ri(r.ip0.value, dstaddr_loc.value, dst_i)
                i += sz
                dst_i += sz

        else:
            if isinstance(size_box, ConstInt):
                size_loc = self.imm(size_box.getint())
            else:
                # load size_loc in a register different than dstaddr_loc
                size_loc = self._regalloc.rm.make_sure_var_in_reg(size_box,
                                                            [])
            #
            # call memset()
            self._regalloc.before_call()
            self.simple_call_no_collect(self.imm(self.memset_addr),
                                        [dstaddr_loc, self.imm(0), size_loc])
            self._regalloc.rm.possibly_free_var(size_box)

    def _emit_op_cond_call(self, op, arglocs, fcond):
        if len(arglocs) == 2:
            res_loc = arglocs[1]     # cond_call_value
        else:
            res_loc = None           # cond_call
        # see x86.regalloc for why we skip res_loc in the gcmap

        if arglocs[0] is not None: # otherwise result already in CC
            self.mc.CMP_ri(arglocs[0].value, 0)

        gcmap = self._regalloc.get_gcmap([res_loc])

        jmp_adr = self.mc.currpos()
        self.mc.BRK()  # patched later: the conditional jump
        #
        self.push_gcmap(self.mc, gcmap)
        self.mc.gen_load_int(r.ip1.value, rffi.cast(lltype.Signed,
            op.getarg(1).getint()))
        #
        callee_only = False
        floats = False
        if self._regalloc is not None:
            for reg in self._regalloc.rm.reg_bindings.values():
                if reg not in self._regalloc.rm.save_around_call_regs:
                    break
            else:
                callee_only = True
            if self._regalloc.vfprm.reg_bindings:
                floats = True
        cond_call_adr = self.cond_call_slowpath[floats * 2 + callee_only]
        assert cond_call_adr

        self.mc.BL(cond_call_adr)
        # if this is a COND_CALL_VALUE, we need to move the result in place
        # from its current location
        if res_loc is not None:
            self.mc.MOV_rr(res_loc.value, r.ip1.value)
        #
        self.pop_gcmap(self.mc)
        pmc = OverwritingBuilder(self.mc, jmp_adr, WORD)
        pmc.B_ofs_cond(self.mc.currpos() - jmp_adr, fcond)
        # might be overridden again to skip over the following
        # guard_no_exception too
        self.previous_cond_call_jcond = jmp_adr, fcond

    def emit_op_cond_call(self, op, arglocs):
        self._emit_op_cond_call(op, arglocs, c.EQ)

    def emit_op_cond_call_value_i(self, op, arglocs):
        self._emit_op_cond_call(op, arglocs, c.NE)
    emit_op_cond_call_value_r = emit_op_cond_call_value_i

    def emit_guard_op_cond_call(self, prevop, op, fcond, arglocs):
        self._emit_op_cond_call(op, arglocs, c.get_opposite_of(fcond))

    def _write_barrier_fastpath(self, mc, descr, arglocs, array=False, is_frame=False):
        # Write code equivalent to write_barrier() in the GC: it checks
        # a flag in the object at arglocs[0], and if set, it calls a
        # helper piece of assembler.  The latter saves registers as needed
        # and call the function remember_young_pointer() from the GC.
        if we_are_translated():
            cls = self.cpu.gc_ll_descr.has_write_barrier_class()
            assert cls is not None and isinstance(descr, cls)
        #
        card_marking = False
        mask = descr.jit_wb_if_flag_singlebyte
        if array and descr.jit_wb_cards_set != 0:
            # assumptions the rest of the function depends on:
            assert (descr.jit_wb_cards_set_byteofs ==
                    descr.jit_wb_if_flag_byteofs)
            assert descr.jit_wb_cards_set_singlebyte == -0x80
            card_marking = True
            mask = descr.jit_wb_if_flag_singlebyte | -0x80
        #
        loc_base = arglocs[0]
        if is_frame:
            assert loc_base is r.fp
        mc.LDRB_ri(r.ip0.value, loc_base.value, descr.jit_wb_if_flag_byteofs)
        mask &= 0xFF
        mc.MOVZ_r_u16(r.ip1.value, mask, 0)
        mc.TST_rr_shift(r.ip0.value, r.ip1.value, 0)
        jz_location = mc.currpos()
        mc.BRK()

        # for cond_call_gc_wb_array, also add another fast path:
        # if GCFLAG_CARDS_SET, then we can just set one bit and be done
        if card_marking:
            mc.MOVZ_r_u16(r.ip1.value, 0x80, 0)
            # GCFLAG_CARDS_SET is in this byte at 0x80
            mc.TST_rr_shift(r.ip0.value, r.ip1.value, 0)

            js_location = mc.currpos()
            mc.BRK()
        else:
            js_location = 0

        # Write only a CALL to the helper prepared in advance, passing it as
        # argument the address of the structure we are writing into
        # (the first argument to COND_CALL_GC_WB).
        helper_num = card_marking
        if is_frame:
            helper_num = 4
        elif self._regalloc is not None and self._regalloc.vfprm.reg_bindings:
            helper_num += 2
        if self.wb_slowpath[helper_num] == 0:    # tests only
            assert not we_are_translated()
            self.cpu.gc_ll_descr.write_barrier_descr = descr
            self._build_wb_slowpath(card_marking,
                                    bool(self._regalloc.vfprm.reg_bindings))
            assert self.wb_slowpath[helper_num] != 0
        #
        if loc_base is not r.x0:
            # push two registers to keep stack aligned
            mc.SUB_ri(r.sp.value, r.sp.value, 2 * WORD)
            mc.STR_ri(r.x0.value, r.sp.value, WORD)
            mc.STR_ri(loc_base.value, r.sp.value, 0)
            mc.MOV_rr(r.x0.value, loc_base.value)
            if is_frame:
                assert loc_base is r.fp
        mc.BL(self.wb_slowpath[helper_num])
        if loc_base is not r.x0:
            mc.LDR_ri(r.x0.value, r.sp.value, WORD)
            mc.LDR_ri(loc_base.value, r.sp.value, 0)
            mc.ADD_ri(r.sp.value, r.sp.value, 2 * WORD)

        if card_marking:
            # The helper ends again with a check of the flag in the object.  So
            # here, we can simply write again a conditional jump, which will be
            # taken if GCFLAG_CARDS_SET is still not set.
            jns_location = mc.currpos()
            mc.BRK()
            #
            # patch the JS above
            offset = mc.currpos() - js_location
            pmc = OverwritingBuilder(mc, js_location, WORD)
            pmc.B_ofs_cond(offset, c.NE)  # We want to jump if the z flag isn't set
            #
            # case GCFLAG_CARDS_SET: emit a few instructions to do
            # directly the card flag setting
            loc_index = arglocs[1]
            assert loc_index.is_core_reg()
            tmp1 = r.ip1
            #tmp2 = arglocs[-1]  -- the last item is a preallocated tmp on arm,
            #                       but not here on aarch64
            # lr = byteofs
            s = 3 + descr.jit_wb_card_page_shift
            mc.MVN_rr_shifted(r.lr.value, loc_index.value, s, shifttype=shift.LSR)

            # tmp1 = byte_index
            mc.MOVZ_r_u16(r.ip0.value, 7, 0)
            mc.AND_rr_shift(tmp1.value, r.ip0.value, loc_index.value,
                            descr.jit_wb_card_page_shift, shifttype=shift.LSR)

            # set the bit
            mc.MOVZ_r_u16(r.ip0.value, 1, 0)
            mc.LSL_rr(tmp1.value, r.ip0.value, tmp1.value)
            mc.LDRB_rr(r.ip0.value, loc_base.value, r.lr.value)
            mc.ORR_rr(r.ip0.value, r.ip0.value, tmp1.value)
            mc.STR_size_rr(0, r.ip0.value, loc_base.value, r.lr.value)
            # done
            #
            # patch the JNS above
            offset = mc.currpos() - jns_location
            pmc = OverwritingBuilder(mc, jns_location, WORD)
            pmc.B_ofs_cond(offset, c.EQ)  # We want to jump if the z flag is set

        offset = mc.currpos() - jz_location
        pmc = OverwritingBuilder(mc, jz_location, WORD)
        pmc.B_ofs_cond(offset, c.EQ)

    # ----------------------------- call ------------------------------

    def _genop_call(self, op, arglocs):
        return self._emit_call(op, arglocs)
    emit_op_call_i = _genop_call
    emit_op_call_r = _genop_call
    emit_op_call_f = _genop_call
    emit_op_call_n = _genop_call

    def _emit_call(self, op, arglocs):
        is_call_release_gil = rop.is_call_release_gil(op.getopnum())
        # args = [resloc, size, sign, args...]
        from rpython.jit.backend.llsupport.descr import CallDescr

        func_index = 3 + is_call_release_gil
        cb = Aarch64CallBuilder(self, arglocs[func_index],
                                arglocs[func_index+1:], arglocs[0])

        descr = op.getdescr()
        assert isinstance(descr, CallDescr)
        cb.callconv = descr.get_call_conv()
        cb.argtypes = descr.get_arg_types()
        cb.restype  = descr.get_result_type()
        sizeloc = arglocs[1]
        assert sizeloc.is_imm()
        cb.ressize = sizeloc.value
        signloc = arglocs[2]
        assert signloc.is_imm()
        cb.ressign = signloc.value

        if is_call_release_gil:
            saveerrloc = arglocs[3]
            assert saveerrloc.is_imm()
            cb.emit_call_release_gil(saveerrloc.value)
        else:
            effectinfo = descr.get_extra_info()
            if effectinfo is None or effectinfo.check_can_collect():
                cb.emit()
            else:
                cb.emit_no_collect()

    def simple_call(self, fnloc, arglocs, result_loc=r.x0):
        if result_loc is None:
            result_type = VOID
            result_size = 0
        elif result_loc.is_vfp_reg():
            result_type = FLOAT
            result_size = WORD
        else:
            result_type = INT
            result_size = WORD
        cb = Aarch64CallBuilder(self, fnloc, arglocs,
                                     result_loc, result_type,
                                     result_size)
        cb.emit()

    def simple_call_no_collect(self, fnloc, arglocs):
        cb = Aarch64CallBuilder(self, fnloc, arglocs)
        cb.emit_no_collect()

    def emit_guard_op_guard_not_forced(self, op, guard_op, fcond, arglocs):
        # arglocs is call locs + guard_locs, split them
        if rop.is_call_assembler(op.getopnum()):
            if fcond == 4:
                [argloc, vloc, result_loc, tmploc] = arglocs[:4]
            else:
                [argloc, result_loc, tmploc] = arglocs[:3]
                vloc = locations.imm(0)
            guard_locs = arglocs[fcond:]
            self._store_force_index(guard_op)
            self.call_assembler(op, argloc, vloc, result_loc, tmploc)
        else:
            assert fcond == op.numargs() + 3
            call_args = arglocs[:fcond]
            guard_locs = arglocs[fcond:]
            self._store_force_index(guard_op)
            self._emit_call(op, call_args)
        # process the guard_not_forced
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.LDR_ri(r.ip0.value, r.fp.value, ofs)
        self.mc.CMP_ri(r.ip0.value, 0)
        self._emit_guard(guard_op, c.EQ, guard_locs)

    def _call_assembler_emit_call(self, addr, argloc, resloc):
        ofs = self.saved_threadlocal_addr
        # we are moving the threadlocal directly to x1, to avoid strange
        # dances
        self.mc.LDR_ri(r.x1.value, r.sp.value, ofs)
        self.simple_call(addr, [argloc], result_loc=resloc)

    def _call_assembler_emit_helper_call(self, addr, arglocs, resloc):
        self.simple_call(addr, arglocs, result_loc=resloc)

    def _call_assembler_check_descr(self, value, tmploc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.LDR_ri(r.ip0.value, tmploc.value, ofs)
        if check_imm_arg(value):
            self.mc.CMP_ri(r.ip0.value, value)
        else:
            self.mc.gen_load_int(r.ip1.value, value)
            self.mc.CMP_rr(r.ip0.value, r.ip1.value)
        pos = self.mc.currpos()
        self.mc.BRK()
        return pos

    def _call_assembler_patch_je(self, result_loc, jmp_location):
        pos = self.mc.currpos()
        self.mc.BRK()
        #
        pmc = OverwritingBuilder(self.mc, jmp_location, WORD)
        pmc.B_ofs_cond(self.mc.currpos() - jmp_location, c.EQ)
        return pos

    def _call_assembler_load_result(self, op, result_loc):
        if op.type != 'v':
            # load the return value from (tmploc, 0)
            kind = op.type
            descr = self.cpu.getarraydescr_for_frame(kind)
            if kind == FLOAT:
                ofs = self.cpu.unpack_arraydescr(descr)
                assert check_imm_arg(ofs)
                assert result_loc.is_vfp_reg()
                # we always have a register here, since we have to sync them
                # before call_assembler
                self.mc.LDR_di(result_loc.value, r.x0.value, ofs)
            else:
                assert result_loc is r.x0
                ofs = self.cpu.unpack_arraydescr(descr)
                assert check_imm_arg(ofs)
                self.mc.LDR_ri(result_loc.value, r.x0.value, ofs)

    def _call_assembler_patch_jmp(self, jmp_location):
        # merge point
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_location, WORD)
        pmc.B_ofs(currpos - jmp_location)

    def _store_force_index(self, guard_op):
        faildescr = guard_op.getdescr()
        faildescrindex = self.get_gcref_from_faildescr(faildescr)
        ofs = self.cpu.get_ofs_of_frame_field('jf_force_descr')
        self.load_from_gc_table(r.ip0.value, faildescrindex)
        self.store_reg(self.mc, r.ip0, r.fp, ofs)

    def emit_op_guard_not_forced_2(self, op, arglocs):
        self.store_force_descr(op, arglocs[1:], arglocs[0].value)

    def store_force_descr(self, op, fail_locs, frame_depth):
        pos = self.mc.currpos()
        guard_token = self.build_guard_token(op, frame_depth, fail_locs, pos, c.AL)
        self._finish_gcmap = guard_token.gcmap
        self._store_force_index(op)
        self.store_info_on_descr(pos, guard_token)

    def emit_op_force_token(self, op, arglocs):
        self.mc.MOV_rr(arglocs[0].value, r.fp.value)

    def emit_op_label(self, op, arglocs):
        pass

    def emit_op_jump(self, op, arglocs):
        target_token = op.getdescr()
        assert isinstance(target_token, TargetToken)
        target = target_token._ll_loop_code
        if target_token in self.target_tokens_currently_compiling:
            self.mc.B_ofs(target - self.mc.currpos())
        else:
            self.mc.B(target)

    def emit_op_finish(self, op, arglocs):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        if len(arglocs) > 0:
            [return_val] = arglocs
            self.store_reg(self.mc, return_val, r.fp, base_ofs)
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')

        faildescrindex = self.get_gcref_from_faildescr(op.getdescr())
        self.load_from_gc_table(r.ip0.value, faildescrindex)
        # XXX self.mov(fail_descr_loc, RawStackLoc(ofs))
        self.store_reg(self.mc, r.ip0, r.fp, ofs)
        if op.numargs() > 0 and op.getarg(0).type == REF:
            if self._finish_gcmap:
                # we're returning with a guard_not_forced_2, and
                # additionally we need to say that r0 contains
                # a reference too:
                self._finish_gcmap[0] |= r_uint(1)
                gcmap = self._finish_gcmap
            else:
                gcmap = self.gcmap_for_finish
            self.push_gcmap(self.mc, gcmap)
        elif self._finish_gcmap:
            # we're returning with a guard_not_forced_2
            gcmap = self._finish_gcmap
            self.push_gcmap(self.mc, gcmap)
        else:
            # note that the 0 here is redundant, but I would rather
            # keep that one and kill all the others
            ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
            self.store_reg(self.mc, r.xzr, r.fp, ofs)
        self.mc.MOV_rr(r.x0.value, r.fp.value)
        # exit function
        self.gen_func_epilog()
