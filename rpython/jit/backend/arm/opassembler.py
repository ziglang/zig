from __future__ import with_statement
from rpython.jit.backend.arm import conditions as c
from rpython.jit.backend.arm import registers as r
from rpython.jit.backend.arm import shift
from rpython.jit.backend.arm.arch import WORD, DOUBLE_WORD, JITFRAME_FIXED_SIZE
from rpython.jit.backend.arm.helper.assembler import (
                                                gen_emit_op_unary_cmp,
                                                gen_emit_op_ri,
                                                gen_emit_cmp_op,
                                                gen_emit_float_op,
                                                gen_emit_float_cmp_op,
                                                gen_emit_unary_float_op,
                                                saved_registers)
from rpython.jit.backend.arm.helper.regalloc import check_imm_arg
from rpython.jit.backend.arm.helper.regalloc import VMEM_imm_size
from rpython.jit.backend.arm.codebuilder import InstrBuilder, OverwritingBuilder
from rpython.jit.backend.arm.jump import remap_frame_layout
from rpython.jit.backend.arm.regalloc import TempVar
from rpython.jit.backend.arm.locations import imm, RawSPStackLocation
from rpython.jit.backend.llsupport import symbolic
from rpython.jit.backend.llsupport.gcmap import allocate_gcmap
from rpython.jit.backend.llsupport.assembler import GuardToken, BaseAssembler
from rpython.jit.backend.llsupport.regalloc import get_scale
from rpython.jit.metainterp.history import (AbstractFailDescr, ConstInt,
                                            INT, FLOAT, REF)
from rpython.jit.metainterp.history import TargetToken
from rpython.jit.metainterp.resoperation import rop
from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem import rstr, rffi, lltype
from rpython.rtyper.annlowlevel import cast_instance_to_gcref
from rpython.rtyper import rclass
from rpython.jit.backend.arm import callbuilder
from rpython.rlib.rarithmetic import r_uint
from rpython.rlib.rjitlog import rjitlog as jl


class ArmGuardToken(GuardToken):
    def __init__(self, cpu, gcmap, faildescr, failargs, fail_locs,
                 offset, guard_opnum, frame_depth, faildescrindex, fcond=c.AL):
        GuardToken.__init__(self, cpu, gcmap, faildescr, failargs, fail_locs,
                            guard_opnum, frame_depth, faildescrindex)
        self.fcond = fcond
        self.offset = offset


class ResOpAssembler(BaseAssembler):

    def emit_op_int_add(self, op, arglocs, regalloc, fcond):
        return self.int_add_impl(op, arglocs, regalloc, fcond)

    emit_op_nursery_ptr_increment = emit_op_int_add

    def int_add_impl(self, op, arglocs, regalloc, fcond, flags=False):
        l0, l1, res = arglocs
        if flags:
            s = 1
        else:
            s = 0
        if l0.is_imm():
            self.mc.ADD_ri(res.value, l1.value, imm=l0.value, s=s)
        elif l1.is_imm():
            self.mc.ADD_ri(res.value, l0.value, imm=l1.value, s=s)
        else:
            self.mc.ADD_rr(res.value, l0.value, l1.value, s=1)

        return fcond

    def emit_op_int_sub(self, op, arglocs, regalloc, fcond, flags=False):
        return self.int_sub_impl(op, arglocs, regalloc, fcond)

    def int_sub_impl(self, op, arglocs, regalloc, fcond, flags=False):
        l0, l1, res = arglocs
        if flags:
            s = 1
        else:
            s = 0
        if l0.is_imm():
            value = l0.getint()
            assert value >= 0
            # reverse substract ftw
            self.mc.RSB_ri(res.value, l1.value, value, s=s)
        elif l1.is_imm():
            value = l1.getint()
            assert value >= 0
            self.mc.SUB_ri(res.value, l0.value, value, s=s)
        else:
            self.mc.SUB_rr(res.value, l0.value, l1.value, s=s)

        return fcond

    def emit_op_int_mul(self, op, arglocs, regalloc, fcond):
        reg1, reg2, res = arglocs
        self.mc.MUL(res.value, reg1.value, reg2.value)
        return fcond

    def emit_op_uint_mul_high(self, op, arglocs, regalloc, fcond):
        reg1, reg2, res = arglocs
        self.mc.UMULL(r.ip.value, res.value, reg1.value, reg2.value)
        return fcond

    def emit_op_int_force_ge_zero(self, op, arglocs, regalloc, fcond):
        arg, res = arglocs
        self.mc.CMP_ri(arg.value, 0)
        self.mc.MOV_ri(res.value, 0, cond=c.LT)
        self.mc.MOV_rr(res.value, arg.value, cond=c.GE)
        return fcond

    def emit_op_int_signext(self, op, arglocs, regalloc, fcond):
        arg, numbytes, res = arglocs
        assert numbytes.is_imm()
        if numbytes.value == 1:
            self.mc.SXTB_rr(res.value, arg.value)
        elif numbytes.value == 2:
            self.mc.SXTH_rr(res.value, arg.value)
        else:
            raise AssertionError("bad number of bytes")
        return fcond

    #ref: http://blogs.arm.com/software-enablement/detecting-overflow-from-mul/
    def emit_op_int_mul_ovf(self, op, arglocs, regalloc, fcond):
        reg1 = arglocs[0]
        reg2 = arglocs[1]
        res = arglocs[2]
        self.mc.SMULL(res.value, r.ip.value, reg1.value, reg2.value,
                                                                cond=fcond)
        self.mc.CMP_rr(r.ip.value, res.value, shifttype=shift.ASR,
                                                        imm=31, cond=fcond)
        self.guard_success_cc = c.EQ
        return fcond

    def emit_op_int_add_ovf(self, op, arglocs, regalloc, fcond):
        fcond = self.int_add_impl(op, arglocs, regalloc, fcond, flags=True)
        self.guard_success_cc = c.VC
        return fcond

    def emit_op_int_sub_ovf(self, op, arglocs, regalloc, fcond):
        fcond = self.int_sub_impl(op, arglocs, regalloc, fcond, flags=True)
        self.guard_success_cc = c.VC
        return fcond

    emit_op_int_and = gen_emit_op_ri('int_and', 'AND')
    emit_op_int_or = gen_emit_op_ri('int_or', 'ORR')
    emit_op_int_xor = gen_emit_op_ri('int_xor', 'EOR')
    emit_op_int_lshift = gen_emit_op_ri('int_lshift', 'LSL')
    emit_op_int_rshift = gen_emit_op_ri('int_rshift', 'ASR')
    emit_op_uint_rshift = gen_emit_op_ri('uint_rshift', 'LSR')

    emit_op_int_lt = gen_emit_cmp_op('int_lt', c.LT)
    emit_op_int_le = gen_emit_cmp_op('int_le', c.LE)
    emit_op_int_eq = gen_emit_cmp_op('int_eq', c.EQ)
    emit_op_int_ne = gen_emit_cmp_op('int_ne', c.NE)
    emit_op_int_gt = gen_emit_cmp_op('int_gt', c.GT)
    emit_op_int_ge = gen_emit_cmp_op('int_ge', c.GE)

    emit_op_uint_le = gen_emit_cmp_op('uint_le', c.LS)
    emit_op_uint_gt = gen_emit_cmp_op('uint_gt', c.HI)
    emit_op_uint_lt = gen_emit_cmp_op('uint_lt', c.LO)
    emit_op_uint_ge = gen_emit_cmp_op('uint_ge', c.HS)

    emit_op_ptr_eq = emit_op_instance_ptr_eq = emit_op_int_eq
    emit_op_ptr_ne = emit_op_instance_ptr_ne = emit_op_int_ne

    emit_op_int_is_true = gen_emit_op_unary_cmp('int_is_true', c.NE)
    emit_op_int_is_zero = gen_emit_op_unary_cmp('int_is_zero', c.EQ)

    def emit_op_int_invert(self, op, arglocs, regalloc, fcond):
        reg, res = arglocs

        self.mc.MVN_rr(res.value, reg.value)
        return fcond

    def emit_op_int_neg(self, op, arglocs, regalloc, fcond):
        l0, resloc = arglocs
        self.mc.RSB_ri(resloc.value, l0.value, imm=0)
        return fcond

    def build_guard_token(self, op, frame_depth, arglocs, offset, fcond):
        assert isinstance(fcond, int)
        descr = op.getdescr()
        assert isinstance(descr, AbstractFailDescr)

        gcmap = allocate_gcmap(self, frame_depth, JITFRAME_FIXED_SIZE)
        faildescrindex = self.get_gcref_from_faildescr(descr)
        token = ArmGuardToken(self.cpu, gcmap,
                                    descr,
                                    failargs=op.getfailargs(),
                                    fail_locs=arglocs,
                                    offset=offset,
                                    guard_opnum=op.getopnum(),
                                    frame_depth=frame_depth,
                                    faildescrindex=faildescrindex,
                                    fcond=fcond)
        return token

    def _emit_guard(self, op, arglocs, is_guard_not_invalidated=False):
        if is_guard_not_invalidated:
            fcond = c.cond_none
        else:
            fcond = self.guard_success_cc
            self.guard_success_cc = c.cond_none
            assert fcond != c.cond_none
        pos = self.mc.currpos()
        token = self.build_guard_token(op, arglocs[0].value, arglocs[1:], pos, fcond)
        self.pending_guards.append(token)
        assert token.guard_not_invalidated() == is_guard_not_invalidated
        # For all guards that are not GUARD_NOT_INVALIDATED we emit a
        # breakpoint to ensure the location is patched correctly. In the case
        # of GUARD_NOT_INVALIDATED we use just a NOP, because it is only
        # eventually patched at a later point.
        if is_guard_not_invalidated:
            self.mc.NOP()
        else:
            self.mc.BKPT()
        return c.AL

    def emit_op_guard_true(self, op, arglocs, regalloc, fcond):
        fcond = self._emit_guard(op, arglocs)
        return fcond

    def emit_op_guard_false(self, op, arglocs, regalloc, fcond):
        self.guard_success_cc = c.get_opposite_of(self.guard_success_cc)
        fcond = self._emit_guard(op, arglocs)
        return fcond

    def emit_op_guard_value(self, op, arglocs, regalloc, fcond):
        l0 = arglocs[0]
        l1 = arglocs[1]
        failargs = arglocs[2:]

        if l0.is_core_reg():
            if l1.is_imm():
                self.mc.CMP_ri(l0.value, l1.getint())
            else:
                self.mc.CMP_rr(l0.value, l1.value)
        elif l0.is_vfp_reg():
            assert l1.is_vfp_reg()
            self.mc.VCMP(l0.value, l1.value)
            self.mc.VMRS(cond=fcond)
        self.guard_success_cc = c.EQ
        fcond = self._emit_guard(op, failargs)
        return fcond

    emit_op_guard_nonnull = emit_op_guard_true
    emit_op_guard_isnull = emit_op_guard_false

    emit_op_guard_no_overflow = emit_op_guard_true
    emit_op_guard_overflow    = emit_op_guard_false

    def emit_op_guard_class(self, op, arglocs, regalloc, fcond):
        self._cmp_guard_class(op, arglocs, regalloc, fcond)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs[2:])
        return fcond

    def emit_op_guard_nonnull_class(self, op, arglocs, regalloc, fcond):
        self.mc.CMP_ri(arglocs[0].value, 1)
        self._cmp_guard_class(op, arglocs, regalloc, c.HS)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs[2:])
        return fcond

    def _cmp_guard_class(self, op, locs, regalloc, fcond):
        offset = self.cpu.vtable_offset
        if offset is not None:
            self.mc.LDR_ri(r.ip.value, locs[0].value, offset, cond=fcond)
            self.mc.gen_load_int(r.lr.value, locs[1].value, cond=fcond)
            self.mc.CMP_rr(r.ip.value, r.lr.value, cond=fcond)
        else:
            expected_typeid = (self.cpu.gc_ll_descr
                    .get_typeid_from_classptr_if_gcremovetypeptr(locs[1].value))
            self._cmp_guard_gc_type(locs[0], expected_typeid, fcond)

    def _cmp_guard_gc_type(self, loc_ptr, expected_typeid, fcond=c.AL):
        # Note that the typeid half-word is at offset 0 on a little-endian
        # machine; it would be at offset 2 or 4 on a big-endian machine.
        assert self.cpu.supports_guard_gc_type
        self.mc.LDRH_ri(r.ip.value, loc_ptr.value, cond=fcond)
        self.mc.gen_load_int(r.lr.value, expected_typeid, cond=fcond)
        self.mc.CMP_rr(r.ip.value, r.lr.value, cond=fcond)

    def emit_op_guard_gc_type(self, op, arglocs, regalloc, fcond):
        self._cmp_guard_gc_type(arglocs[0], arglocs[1].value, fcond)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs[2:])
        return fcond

    def emit_op_guard_is_object(self, op, arglocs, regalloc, fcond):
        assert self.cpu.supports_guard_gc_type
        loc_object = arglocs[0]
        # idea: read the typeid, fetch one byte of the field 'infobits' from
        # the big typeinfo table, and check the flag 'T_IS_RPYTHON_INSTANCE'.
        self.mc.LDRH_ri(r.ip.value, loc_object.value)
        #
        base_type_info, shift_by, sizeof_ti = (
            self.cpu.gc_ll_descr.get_translated_info_for_typeinfo())
        infobits_offset, IS_OBJECT_FLAG = (
            self.cpu.gc_ll_descr.get_translated_info_for_guard_is_object())

        self.mc.gen_load_int(r.lr.value, base_type_info + infobits_offset)
        if shift_by > 0:
            self.mc.LSL_ri(r.ip.value, r.ip.value, shift_by)
        self.mc.LDRB_rr(r.ip.value, r.ip.value, r.lr.value)
        self.mc.TST_ri(r.ip.value, imm=(IS_OBJECT_FLAG & 0xff))
        self.guard_success_cc = c.NE
        self._emit_guard(op, arglocs[1:])
        return fcond

    def emit_op_guard_subclass(self, op, arglocs, regalloc, fcond):
        assert self.cpu.supports_guard_gc_type
        loc_object = arglocs[0]
        loc_check_against_class = arglocs[1]
        offset = self.cpu.vtable_offset
        offset2 = self.cpu.subclassrange_min_offset
        if offset is not None:
            # read this field to get the vtable pointer
            self.mc.LDR_ri(r.ip.value, loc_object.value, offset)
            # read the vtable's subclassrange_min field
            self.mc.LDR_ri(r.ip.value, r.ip.value, offset2)
        else:
            # read the typeid
            self.mc.LDRH_ri(r.ip.value, loc_object.value)
            # read the vtable's subclassrange_min field, as a single
            # step with the correct offset
            base_type_info, shift_by, sizeof_ti = (
                self.cpu.gc_ll_descr.get_translated_info_for_typeinfo())

            self.mc.gen_load_int(r.lr.value,
                                 base_type_info + sizeof_ti + offset2)
            if shift_by > 0:
                self.mc.LSL_ri(r.ip.value, r.ip.value, shift_by)
            self.mc.LDR_rr(r.ip.value, r.ip.value, r.lr.value)
        # get the two bounds to check against
        vtable_ptr = loc_check_against_class.getint()
        vtable_ptr = rffi.cast(rclass.CLASSTYPE, vtable_ptr)
        check_min = vtable_ptr.subclassrange_min
        check_max = vtable_ptr.subclassrange_max
        assert check_max > check_min
        check_diff = check_max - check_min - 1
        # check by doing the unsigned comparison (tmp - min) < (max - min)
        self.mc.gen_load_int(r.lr.value, check_min)
        self.mc.SUB_rr(r.ip.value, r.ip.value, r.lr.value)
        if check_diff <= 0xff:
            self.mc.CMP_ri(r.ip.value, check_diff)
        else:
            self.mc.gen_load_int(r.lr.value, check_diff)
            self.mc.CMP_rr(r.ip.value, r.lr.value)
        # the guard passes if we get a result of "below or equal"
        self.guard_success_cc = c.LS
        self._emit_guard(op, arglocs[2:])
        return fcond

    def emit_op_guard_not_invalidated(self, op, locs, regalloc, fcond):
        return self._emit_guard(op, locs, is_guard_not_invalidated=True)

    def emit_op_label(self, op, arglocs, regalloc, fcond):
        self._check_frame_depth_debug(self.mc)
        return fcond

    def emit_op_cond_call(self, op, arglocs, regalloc, fcond):
        call_loc = arglocs[0]
        if len(arglocs) == 2:
            res_loc = arglocs[1]     # cond_call_value
        else:
            res_loc = None           # cond_call
        # see x86.regalloc for why we skip res_loc in the gcmap
        gcmap = regalloc.get_gcmap([res_loc])

        assert call_loc is r.r4
        jmp_adr = self.mc.currpos()
        self.mc.BKPT()  # patched later: the conditional jump
        #
        self.push_gcmap(self.mc, gcmap, store=True)
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
        self.mc.BL(cond_call_adr)
        # if this is a COND_CALL_VALUE, we need to move the result in place
        # from its current location (which is, unusually, in r4: see
        # cond_call_slowpath)
        if res_loc is not None and res_loc is not r.r4:
            self.mc.MOV_rr(res_loc.value, r.r4.value)
        #
        self.pop_gcmap(self.mc)
        cond = c.get_opposite_of(self.guard_success_cc)
        self.guard_success_cc = c.cond_none
        pmc = OverwritingBuilder(self.mc, jmp_adr, WORD)
        pmc.B_offs(self.mc.currpos(), cond)
        # might be overridden again to skip over the following
        # guard_no_exception too
        self.previous_cond_call_jcond = jmp_adr, cond
        return fcond

    emit_op_cond_call_value_i = emit_op_cond_call
    emit_op_cond_call_value_r = emit_op_cond_call

    def emit_op_jump(self, op, arglocs, regalloc, fcond):
        target_token = op.getdescr()
        assert isinstance(target_token, TargetToken)
        target = target_token._ll_loop_code
        assert fcond == c.AL
        if target_token in self.target_tokens_currently_compiling:
            self.mc.B_offs(target, fcond)
        else:
            self.mc.B(target, fcond)
        return fcond

    def emit_op_finish(self, op, arglocs, regalloc, fcond):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        if len(arglocs) > 0:
            [return_val] = arglocs
            self.store_reg(self.mc, return_val, r.fp, base_ofs)
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')

        faildescrindex = self.get_gcref_from_faildescr(op.getdescr())
        self.load_from_gc_table(r.ip.value, faildescrindex)
        # XXX self.mov(fail_descr_loc, RawStackLoc(ofs))
        self.store_reg(self.mc, r.ip, r.fp, ofs, helper=r.lr)
        if op.numargs() > 0 and op.getarg(0).type == REF:
            if self._finish_gcmap:
                # we're returning with a guard_not_forced_2, and
                # additionally we need to say that r0 contains
                # a reference too:
                self._finish_gcmap[0] |= r_uint(1)
                gcmap = self._finish_gcmap
            else:
                gcmap = self.gcmap_for_finish
            self.push_gcmap(self.mc, gcmap, store=True)
        elif self._finish_gcmap:
            # we're returning with a guard_not_forced_2
            gcmap = self._finish_gcmap
            self.push_gcmap(self.mc, gcmap, store=True)
        else:
            # note that the 0 here is redundant, but I would rather
            # keep that one and kill all the others
            ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
            self.mc.gen_load_int(r.ip.value, 0)
            self.store_reg(self.mc, r.ip, r.fp, ofs)
        self.mc.MOV_rr(r.r0.value, r.fp.value)
        # exit function
        self.gen_func_epilog()
        return fcond

    def _genop_call(self, op, arglocs, regalloc, fcond):
        return self._emit_call(op, arglocs, fcond=fcond)
    emit_op_call_i = _genop_call
    emit_op_call_r = _genop_call
    emit_op_call_f = _genop_call
    emit_op_call_n = _genop_call

    def _emit_call(self, op, arglocs, is_call_release_gil=False, fcond=c.AL):
        # args = [resloc, size, sign, args...]
        from rpython.jit.backend.llsupport.descr import CallDescr

        func_index = 3 + is_call_release_gil
        cb = callbuilder.get_callbuilder(self.cpu, self, arglocs[func_index],
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
        return fcond

    def _genop_same_as(self, op, arglocs, regalloc, fcond):
        argloc, resloc = arglocs
        if argloc is not resloc:
            self.mov_loc_loc(argloc, resloc)
        return fcond

    emit_op_same_as_i = _genop_same_as
    emit_op_same_as_r = _genop_same_as
    emit_op_same_as_f = _genop_same_as
    emit_op_cast_ptr_to_int = _genop_same_as
    emit_op_cast_int_to_ptr = _genop_same_as

    def emit_op_guard_no_exception(self, op, arglocs, regalloc, fcond):
        loc = arglocs[0]
        failargs = arglocs[1:]
        self.mc.LDR_ri(loc.value, loc.value)
        self.mc.CMP_ri(loc.value, 0)
        self.guard_success_cc = c.EQ
        fcond = self._emit_guard(op, failargs)
        # If the previous operation was a COND_CALL, overwrite its conditional
        # jump to jump over this GUARD_NO_EXCEPTION as well, if we can
        if self._find_nearby_operation(-1).getopnum() == rop.COND_CALL:
            jmp_adr, prev_cond = self.previous_cond_call_jcond
            pmc = OverwritingBuilder(self.mc, jmp_adr, WORD)
            pmc.B_offs(self.mc.currpos(), prev_cond)
        return fcond

    def emit_op_guard_exception(self, op, arglocs, regalloc, fcond):
        loc, loc1, resloc, pos_exc_value, pos_exception = arglocs[:5]
        failargs = arglocs[5:]
        self.mc.gen_load_int(loc1.value, pos_exception.value)
        self.mc.LDR_ri(r.ip.value, loc1.value)

        self.mc.CMP_rr(r.ip.value, loc.value)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, failargs)
        self._store_and_reset_exception(self.mc, resloc)
        return fcond

    def emit_op_save_exc_class(self, op, arglocs, regalloc, fcond):
        resloc = arglocs[0]
        self.mc.gen_load_int(r.ip.value, self.cpu.pos_exception())
        self.load_reg(self.mc, resloc, r.ip)
        return fcond

    def emit_op_save_exception(self, op, arglocs, regalloc, fcond):
        resloc = arglocs[0]
        self._store_and_reset_exception(self.mc, resloc)
        return fcond

    def emit_op_restore_exception(self, op, arglocs, regalloc, fcond):
        self._restore_exception(self.mc, arglocs[1], arglocs[0])
        return fcond

    def emit_op_debug_merge_point(self, op, arglocs, regalloc, fcond):
        return fcond
    emit_op_jit_debug = emit_op_debug_merge_point
    emit_op_keepalive = emit_op_debug_merge_point
    emit_op_enter_portal_frame = emit_op_debug_merge_point
    emit_op_leave_portal_frame = emit_op_debug_merge_point

    def emit_op_cond_call_gc_wb(self, op, arglocs, regalloc, fcond):
        self._write_barrier_fastpath(self.mc, op.getdescr(), arglocs, fcond)
        return fcond

    def emit_op_cond_call_gc_wb_array(self, op, arglocs, regalloc, fcond):
        self._write_barrier_fastpath(self.mc, op.getdescr(), arglocs,
                                                        fcond, array=True)
        return fcond

    def _write_barrier_fastpath(self, mc, descr, arglocs, fcond=c.AL, array=False,
                                                            is_frame=False):
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
        mc.LDRB_ri(r.ip.value, loc_base.value,
                                    imm=descr.jit_wb_if_flag_byteofs)
        mask &= 0xFF
        mc.TST_ri(r.ip.value, imm=mask)
        jz_location = mc.currpos()
        mc.BKPT()

        # for cond_call_gc_wb_array, also add another fast path:
        # if GCFLAG_CARDS_SET, then we can just set one bit and be done
        if card_marking:
            # GCFLAG_CARDS_SET is in this byte at 0x80
            mc.TST_ri(r.ip.value, imm=0x80)

            js_location = mc.currpos()
            mc.BKPT()
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
        if loc_base is not r.r0:
            # push two registers to keep stack aligned
            mc.PUSH([r.r0.value, loc_base.value])
            mc.MOV_rr(r.r0.value, loc_base.value)
            if is_frame:
                assert loc_base is r.fp
        mc.BL(self.wb_slowpath[helper_num])
        if loc_base is not r.r0:
            mc.POP([r.r0.value, loc_base.value])

        if card_marking:
            # The helper ends again with a check of the flag in the object.  So
            # here, we can simply write again a conditional jump, which will be
            # taken if GCFLAG_CARDS_SET is still not set.
            jns_location = mc.currpos()
            mc.BKPT()
            #
            # patch the JS above
            offset = mc.currpos()
            pmc = OverwritingBuilder(mc, js_location, WORD)
            pmc.B_offs(offset, c.NE)  # We want to jump if the z flag isn't set
            #
            # case GCFLAG_CARDS_SET: emit a few instructions to do
            # directly the card flag setting
            loc_index = arglocs[1]
            assert loc_index.is_core_reg()
            # must save the register loc_index before it is mutated
            mc.PUSH([loc_index.value])
            tmp1 = loc_index
            tmp2 = arglocs[-1]  # the last item is a preallocated tmp
            # lr = byteofs
            s = 3 + descr.jit_wb_card_page_shift
            mc.MVN_rr(r.lr.value, loc_index.value,
                                       imm=s, shifttype=shift.LSR)

            # tmp1 = byte_index
            mc.MOV_ri(r.ip.value, imm=7)
            mc.AND_rr(tmp1.value, r.ip.value, loc_index.value,
            imm=descr.jit_wb_card_page_shift, shifttype=shift.LSR)

            # set the bit
            mc.MOV_ri(tmp2.value, imm=1)
            mc.LDRB_rr(r.ip.value, loc_base.value, r.lr.value)
            mc.ORR_rr_sr(r.ip.value, r.ip.value, tmp2.value,
                                          tmp1.value, shifttype=shift.LSL)
            mc.STRB_rr(r.ip.value, loc_base.value, r.lr.value)
            # done
            mc.POP([loc_index.value])
            #
            #
            # patch the JNS above
            offset = mc.currpos()
            pmc = OverwritingBuilder(mc, jns_location, WORD)
            pmc.B_offs(offset, c.EQ)  # We want to jump if the z flag is set

        offset = mc.currpos()
        pmc = OverwritingBuilder(mc, jz_location, WORD)
        pmc.B_offs(offset, c.EQ)
        return fcond

    def emit_op_gc_store(self, op, arglocs, regalloc, fcond):
        value_loc, base_loc, ofs_loc, size_loc = arglocs
        scale = get_scale(size_loc.value)
        self._write_to_mem(value_loc, base_loc, ofs_loc, imm(scale), fcond)
        return fcond

    def _emit_op_gc_load(self, op, arglocs, regalloc, fcond):
        base_loc, ofs_loc, res_loc, nsize_loc = arglocs
        nsize = nsize_loc.value
        signed = (nsize < 0)
        scale = get_scale(abs(nsize))
        self._load_from_mem(res_loc, base_loc, ofs_loc, imm(scale),
                            signed, fcond)
        return fcond

    emit_op_gc_load_i = _emit_op_gc_load
    emit_op_gc_load_r = _emit_op_gc_load
    emit_op_gc_load_f = _emit_op_gc_load

    def emit_op_increment_debug_counter(self, op, arglocs, regalloc, fcond):
        base_loc, value_loc = arglocs
        self.mc.LDR_ri(value_loc.value, base_loc.value, 0, cond=fcond)
        self.mc.ADD_ri(value_loc.value, value_loc.value, 1, cond=fcond)
        self.mc.STR_ri(value_loc.value, base_loc.value, 0, cond=fcond)
        return fcond

    def emit_op_gc_store_indexed(self, op, arglocs, regalloc, fcond):
        value_loc, base_loc, index_loc, size_loc, ofs_loc = arglocs
        assert index_loc.is_core_reg()
        # add the base offset
        if ofs_loc.value != 0:
            if check_imm_arg(ofs_loc.value):
                self.mc.ADD_ri(r.ip.value, index_loc.value, imm=ofs_loc.value)
            else:
                # ofs_loc.value is too large for an ADD_ri
                self.load(r.ip, ofs_loc)
                self.mc.ADD_rr(r.ip.value, r.ip.value, index_loc.value)
            index_loc = r.ip
        scale = get_scale(size_loc.value)
        self._write_to_mem(value_loc, base_loc, index_loc, imm(scale), fcond)
        return fcond

    def _write_to_mem(self, value_loc, base_loc, ofs_loc, scale, fcond=c.AL):
        # Write a value of size '1 << scale' at the address
        # 'base_ofs + ofs_loc'.  Note that 'scale' is not used to scale
        # the offset!
        if scale.value == 3:
            assert value_loc.is_vfp_reg()
            # vstr only supports imm offsets
            # so if the ofset is too large we add it to the base and use an
            # offset of 0
            if ofs_loc.is_core_reg():
                tmploc, save = self.get_tmp_reg([value_loc, base_loc, ofs_loc])
                assert not save
                self.mc.ADD_rr(tmploc.value, base_loc.value, ofs_loc.value)
                base_loc = tmploc
                ofs_loc = imm(0)
            else:
                assert ofs_loc.is_imm()
                assert ofs_loc.value % 4 == 0
            self.mc.VSTR(value_loc.value, base_loc.value, ofs_loc.value)
        elif scale.value == 2:
            if ofs_loc.is_imm():
                self.mc.STR_ri(value_loc.value, base_loc.value,
                                ofs_loc.value, cond=fcond)
            else:
                self.mc.STR_rr(value_loc.value, base_loc.value,
                                ofs_loc.value, cond=fcond)
        elif scale.value == 1:
            if ofs_loc.is_imm():
                self.mc.STRH_ri(value_loc.value, base_loc.value,
                                ofs_loc.value, cond=fcond)
            else:
                self.mc.STRH_rr(value_loc.value, base_loc.value,
                                ofs_loc.value, cond=fcond)
        elif scale.value == 0:
            if ofs_loc.is_imm():
                self.mc.STRB_ri(value_loc.value, base_loc.value,
                                ofs_loc.value, cond=fcond)
            else:
                self.mc.STRB_rr(value_loc.value, base_loc.value,
                                ofs_loc.value, cond=fcond)
        else:
            assert 0

    def _emit_op_gc_load_indexed(self, op, arglocs, regalloc, fcond):
        res_loc, base_loc, index_loc, nsize_loc, ofs_loc = arglocs
        assert index_loc.is_core_reg()
        nsize = nsize_loc.value
        signed = (nsize < 0)
        # add the base offset
        if ofs_loc.value != 0:
            if check_imm_arg(ofs_loc.value):
                self.mc.ADD_ri(r.ip.value, index_loc.value, imm=ofs_loc.value)
            else:
                # ofs_loc.value is too large for an ADD_ri
                self.load(r.ip, ofs_loc)
                self.mc.ADD_rr(r.ip.value, r.ip.value, index_loc.value)
            index_loc = r.ip
        #
        scale = get_scale(abs(nsize))
        self._load_from_mem(res_loc, base_loc, index_loc, imm(scale),
                            signed, fcond)
        return fcond

    emit_op_gc_load_indexed_i = _emit_op_gc_load_indexed
    emit_op_gc_load_indexed_r = _emit_op_gc_load_indexed
    emit_op_gc_load_indexed_f = _emit_op_gc_load_indexed

    def _load_from_mem(self, res_loc, base_loc, ofs_loc, scale,
                                            signed=False, fcond=c.AL):
        # Load a value of '1 << scale' bytes, from the memory location
        # 'base_loc + ofs_loc'.  Note that 'scale' is not used to scale
        # the offset!
        #
        if scale.value == 3:
            assert res_loc.is_vfp_reg()
            # vldr only supports imm offsets
            # if the offset is in a register we add it to the base and use a
            # tmp reg
            if ofs_loc.is_core_reg():
                tmploc, save = self.get_tmp_reg([base_loc, ofs_loc])
                assert not save
                self.mc.ADD_rr(tmploc.value, base_loc.value, ofs_loc.value)
                base_loc = tmploc
                ofs_loc = imm(0)
            else:
                assert ofs_loc.is_imm()
                assert ofs_loc.value % 4 == 0
            self.mc.VLDR(res_loc.value, base_loc.value, ofs_loc.value, cond=fcond)
        elif scale.value == 2:
            if ofs_loc.is_imm():
                self.mc.LDR_ri(res_loc.value, base_loc.value,
                                ofs_loc.value, cond=fcond)
            else:
                self.mc.LDR_rr(res_loc.value, base_loc.value,
                                ofs_loc.value, cond=fcond)
        elif scale.value == 1:
            if ofs_loc.is_imm():
                if signed:
                    self.mc.LDRSH_ri(res_loc.value, base_loc.value,
                                        ofs_loc.value, cond=fcond)
                else:
                    self.mc.LDRH_ri(res_loc.value, base_loc.value,
                                        ofs_loc.value, cond=fcond)
            else:
                if signed:
                    self.mc.LDRSH_rr(res_loc.value, base_loc.value,
                                        ofs_loc.value, cond=fcond)
                else:
                    self.mc.LDRH_rr(res_loc.value, base_loc.value,
                                        ofs_loc.value, cond=fcond)
        elif scale.value == 0:
            if ofs_loc.is_imm():
                if signed:
                    self.mc.LDRSB_ri(res_loc.value, base_loc.value,
                                        ofs_loc.value, cond=fcond)
                else:
                    self.mc.LDRB_ri(res_loc.value, base_loc.value,
                                        ofs_loc.value, cond=fcond)
            else:
                if signed:
                    self.mc.LDRSB_rr(res_loc.value, base_loc.value,
                                        ofs_loc.value, cond=fcond)
                else:
                    self.mc.LDRB_rr(res_loc.value, base_loc.value,
                                        ofs_loc.value, cond=fcond)
        else:
            assert 0

    def emit_op_load_effective_address(self, op, arglocs, regalloc, fcond):
        static_ofs = op.getarg(2).getint()
        scale = op.getarg(3).getint()
        self._gen_address(arglocs[2], arglocs[0], arglocs[1], scale, static_ofs)
        return fcond

   # result = base_loc  + (scaled_loc << scale) + static_offset
    def _gen_address(self, result, base_loc, scaled_loc, scale=0, static_offset=0):
        assert scaled_loc.is_core_reg()
        assert base_loc.is_core_reg()
        assert check_imm_arg(scale)
        assert check_imm_arg(static_offset)
        if scale > 0:
            self.mc.LSL_ri(r.ip.value, scaled_loc.value, scale)
            scaled_loc = r.ip
        else:
            scaled_loc = scaled_loc
        self.mc.ADD_rr(result.value, base_loc.value, scaled_loc.value)
        self.mc.ADD_ri(result.value, result.value, static_offset)

    def store_force_descr(self, op, fail_locs, frame_depth):
        pos = self.mc.currpos()
        guard_token = self.build_guard_token(op, frame_depth, fail_locs, pos, c.AL)
        #self.pending_guards.append(guard_token)
        self._finish_gcmap = guard_token.gcmap
        self._store_force_index(op)
        self.store_info_on_descr(pos, guard_token)

    def emit_op_force_token(self, op, arglocs, regalloc, fcond):
        # XXX kill me
        res_loc = arglocs[0]
        self.mc.MOV_rr(res_loc.value, r.fp.value)
        return fcond

    def imm(self, v):
        return imm(v)

    def _genop_call_assembler(self, op, arglocs, regalloc, fcond):
        if len(arglocs) == 4:
            [argloc, vloc, result_loc, tmploc] = arglocs
        else:
            [argloc, result_loc, tmploc] = arglocs
            vloc = imm(0)
        self._store_force_index(self._find_nearby_operation(+1))
        self.call_assembler(op, argloc, vloc, result_loc, tmploc)
        return fcond
    emit_op_call_assembler_i = _genop_call_assembler
    emit_op_call_assembler_r = _genop_call_assembler
    emit_op_call_assembler_f = _genop_call_assembler
    emit_op_call_assembler_n = _genop_call_assembler

    def _call_assembler_emit_call(self, addr, argloc, resloc):
        ofs = self.saved_threadlocal_addr
        threadlocal_loc = RawSPStackLocation(ofs, INT)
        self.simple_call(addr, [argloc, threadlocal_loc], result_loc=resloc)

    def _call_assembler_emit_helper_call(self, addr, arglocs, resloc):
        self.simple_call(addr, arglocs, result_loc=resloc)

    def _call_assembler_check_descr(self, value, tmploc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.LDR_ri(r.ip.value, tmploc.value, imm=ofs)
        if check_imm_arg(value):
            self.mc.CMP_ri(r.ip.value, imm=value)
        else:
            self.mc.gen_load_int(r.lr.value, value)
            self.mc.CMP_rr(r.ip.value, r.lr.value)
        pos = self.mc.currpos()
        self.mc.BKPT()
        return pos

    def _call_assembler_patch_je(self, result_loc, jmp_location):
        pos = self.mc.currpos()
        self.mc.BKPT()
        #
        pmc = OverwritingBuilder(self.mc, jmp_location, WORD)
        pmc.B_offs(self.mc.currpos(), c.EQ)
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
                self.load_reg(self.mc, result_loc, r.r0, ofs=ofs)
            else:
                assert result_loc is r.r0
                ofs = self.cpu.unpack_arraydescr(descr)
                assert check_imm_arg(ofs)
                self.mc.LDR_ri(result_loc.value, result_loc.value, imm=ofs)

    def _call_assembler_patch_jmp(self, jmp_location):
        # merge point
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_location, WORD)
        pmc.B_offs(currpos)

    # ../x86/assembler.py:668
    def redirect_call_assembler(self, oldlooptoken, newlooptoken):
        # some minimal sanity checking
        old_nbargs = oldlooptoken.compiled_loop_token._debug_nbargs
        new_nbargs = newlooptoken.compiled_loop_token._debug_nbargs
        assert old_nbargs == new_nbargs
        # we overwrite the instructions at the old _ll_function_addr
        # to start with a JMP to the new _ll_function_addr.
        # Ideally we should rather patch all existing CALLs, but well.
        oldadr = oldlooptoken._ll_function_addr
        target = newlooptoken._ll_function_addr
        # copy frame-info data
        baseofs = self.cpu.get_baseofs_of_frame_field()
        newlooptoken.compiled_loop_token.update_frame_info(
            oldlooptoken.compiled_loop_token, baseofs)
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        mc.B(target)
        mc.copy_to_raw_memory(oldadr)
        #
        jl.redirect_assembler(oldlooptoken, newlooptoken, newlooptoken.number)

    def emit_op_guard_not_forced(self, op, arglocs, regalloc, fcond):
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.LDR_ri(r.ip.value, r.fp.value, imm=ofs)
        self.mc.CMP_ri(r.ip.value, 0)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs)
        return fcond

    def _genop_call_may_force(self, op, arglocs, regalloc, fcond):
        self._store_force_index(self._find_nearby_operation(+1))
        self._emit_call(op, arglocs, fcond=fcond)
        return fcond
    emit_op_call_may_force_i = _genop_call_may_force
    emit_op_call_may_force_r = _genop_call_may_force
    emit_op_call_may_force_f = _genop_call_may_force
    emit_op_call_may_force_n = _genop_call_may_force

    def _genop_call_release_gil(self, op, arglocs, regalloc, fcond):
        self._store_force_index(self._find_nearby_operation(+1))
        self._emit_call(op, arglocs, is_call_release_gil=True)
        return fcond
    emit_op_call_release_gil_i = _genop_call_release_gil
    emit_op_call_release_gil_f = _genop_call_release_gil
    emit_op_call_release_gil_n = _genop_call_release_gil

    def _store_force_index(self, guard_op):
        assert (guard_op.getopnum() == rop.GUARD_NOT_FORCED or
                guard_op.getopnum() == rop.GUARD_NOT_FORCED_2)
        faildescr = guard_op.getdescr()
        faildescrindex = self.get_gcref_from_faildescr(faildescr)
        ofs = self.cpu.get_ofs_of_frame_field('jf_force_descr')
        self.load_from_gc_table(r.ip.value, faildescrindex)
        self.store_reg(self.mc, r.ip, r.fp, ofs)

    def _find_nearby_operation(self, delta):
        regalloc = self._regalloc
        return regalloc.operations[regalloc.rm.position + delta]

    def emit_op_check_memory_error(self, op, arglocs, regalloc, fcond):
        self.propagate_memoryerror_if_reg_is_null(arglocs[0])
        self._alignment_check()
        return fcond

    def _alignment_check(self):
        if not self.debug:
            return
        self.mc.MOV_rr(r.ip.value, r.r0.value)
        self.mc.AND_ri(r.ip.value, r.ip.value, 3)
        self.mc.CMP_ri(r.ip.value, 0)
        self.mc.MOV_rr(r.pc.value, r.pc.value, cond=c.EQ)
        self.mc.BKPT()
        self.mc.NOP()

    emit_op_float_add = gen_emit_float_op('float_add', 'VADD')
    emit_op_float_sub = gen_emit_float_op('float_sub', 'VSUB')
    emit_op_float_mul = gen_emit_float_op('float_mul', 'VMUL')
    emit_op_float_truediv = gen_emit_float_op('float_truediv', 'VDIV')

    emit_op_float_neg = gen_emit_unary_float_op('float_neg', 'VNEG')
    emit_op_float_abs = gen_emit_unary_float_op('float_abs', 'VABS')
    emit_opx_math_sqrt = gen_emit_unary_float_op('math_sqrt', 'VSQRT')

    emit_op_float_lt = gen_emit_float_cmp_op('float_lt', c.VFP_LT)
    emit_op_float_le = gen_emit_float_cmp_op('float_le', c.VFP_LE)
    emit_op_float_eq = gen_emit_float_cmp_op('float_eq', c.EQ)
    emit_op_float_ne = gen_emit_float_cmp_op('float_ne', c.NE)
    emit_op_float_gt = gen_emit_float_cmp_op('float_gt', c.GT)
    emit_op_float_ge = gen_emit_float_cmp_op('float_ge', c.GE)

    def emit_op_cast_float_to_int(self, op, arglocs, regalloc, fcond):
        arg, res = arglocs
        assert arg.is_vfp_reg()
        assert res.is_core_reg()
        self.mc.VCVT_float_to_int(r.svfp_ip.value, arg.value)
        self.mc.VMOV_sc(res.value, r.svfp_ip.value)
        return fcond

    def emit_op_cast_int_to_float(self, op, arglocs, regalloc, fcond):
        arg, res = arglocs
        assert res.is_vfp_reg()
        assert arg.is_core_reg()
        self.mc.VMOV_cs(r.svfp_ip.value, arg.value)
        self.mc.VCVT_int_to_float(res.value, r.svfp_ip.value)
        return fcond

    # the following five instructions are only ARMv7 with NEON;
    # regalloc.py won't call them at all, in other cases
    emit_opx_llong_add = gen_emit_float_op('llong_add', 'VADD_i64')
    emit_opx_llong_sub = gen_emit_float_op('llong_sub', 'VSUB_i64')
    emit_opx_llong_and = gen_emit_float_op('llong_and', 'VAND_i64')
    emit_opx_llong_or = gen_emit_float_op('llong_or', 'VORR_i64')
    emit_opx_llong_xor = gen_emit_float_op('llong_xor', 'VEOR_i64')

    def emit_opx_llong_to_int(self, op, arglocs, regalloc, fcond):
        loc = arglocs[0]
        res = arglocs[1]
        assert loc.is_vfp_reg()
        assert res.is_core_reg()
        self.mc.VMOV_rc(res.value, r.ip.value, loc.value)
        return fcond

    emit_op_convert_float_bytes_to_longlong = gen_emit_unary_float_op(
                                    'float_bytes_to_longlong', 'VMOV_cc')
    emit_op_convert_longlong_bytes_to_float = gen_emit_unary_float_op(
                                    'longlong_bytes_to_float', 'VMOV_cc')

    """   disabled: missing an implementation that works in user mode
    def ..._read_timestamp(...):
        tmp = arglocs[0]
        res = arglocs[1]
        self.mc.MRC(15, 0, tmp.value, 15, 12, 1)
        self.mc.MOV_ri(r.ip.value, 0)
        self.mc.VMOV_cr(res.value, tmp.value, r.ip.value)
        return fcond
    """

    def emit_op_cast_float_to_singlefloat(self, op, arglocs, regalloc, fcond):
        arg, res = arglocs
        assert arg.is_vfp_reg()
        assert res.is_core_reg()
        self.mc.VCVT_f64_f32(r.svfp_ip.value, arg.value)
        self.mc.VMOV_sc(res.value, r.svfp_ip.value)
        return fcond

    def emit_op_cast_singlefloat_to_float(self, op, arglocs, regalloc, fcond):
        arg, res = arglocs
        assert res.is_vfp_reg()
        assert arg.is_core_reg()
        self.mc.VMOV_cs(r.svfp_ip.value, arg.value)
        self.mc.VCVT_f32_f64(res.value, r.svfp_ip.value)
        return fcond

    #from ../x86/regalloc.py:1388
    def emit_op_zero_array(self, op, arglocs, regalloc, fcond):
        from rpython.jit.backend.llsupport.descr import unpack_arraydescr
        assert len(arglocs) == 0
        size_box = op.getarg(2)
        if isinstance(size_box, ConstInt) and size_box.getint() == 0:
            return fcond     # nothing to do
        itemsize, baseofs, _ = unpack_arraydescr(op.getdescr())
        args = op.getarglist()
        #
        # ZERO_ARRAY(base_loc, start, size, 1, 1)
        # 'start' and 'size' are both expressed in bytes,
        # and the two scaling arguments should always be ConstInt(1) on ARM.
        assert args[3].getint() == 1
        assert args[4].getint() == 1
        #
        base_loc = regalloc.rm.make_sure_var_in_reg(args[0], args)
        startbyte_box = args[1]
        if isinstance(startbyte_box, ConstInt):
            startbyte_loc = None
            startbyte = startbyte_box.getint()
            assert startbyte >= 0
        else:
            startbyte_loc = regalloc.rm.make_sure_var_in_reg(startbyte_box,
                                                             args)
            startbyte = -1

        # base_loc and startbyte_loc are in two regs here (or startbyte_loc
        # is an immediate).  Compute the dstaddr_loc, which is the raw
        # address that we will pass as first argument to memset().
        # It can be in the same register as either one, but not in
        # args[2], because we're still needing the latter.
        dstaddr_box = TempVar()
        dstaddr_loc = regalloc.rm.force_allocate_reg(dstaddr_box, [args[2]])
        if startbyte >= 0:    # a constant
            ofs = baseofs + startbyte
            reg = base_loc.value
        else:
            self.mc.ADD_rr(dstaddr_loc.value,
                           base_loc.value, startbyte_loc.value)
            ofs = baseofs
            reg = dstaddr_loc.value
        if check_imm_arg(ofs):
            self.mc.ADD_ri(dstaddr_loc.value, reg, imm=ofs)
        else:
            self.mc.gen_load_int(r.ip.value, ofs)
            self.mc.ADD_rr(dstaddr_loc.value, reg, r.ip.value)

        # We use STRB, STRH or STR based on whether we know the array
        # item size is a multiple of 1, 2 or 4.
        if   itemsize & 1: itemsize = 1
        elif itemsize & 2: itemsize = 2
        else:              itemsize = 4
        limit = itemsize
        next_group = -1
        if itemsize < 4 and startbyte >= 0:
            # we optimize STRB/STRH into STR, but this needs care:
            # it only works if startindex_loc is a constant, otherwise
            # we'd be doing unaligned accesses.
            next_group = (-startbyte) & 3
            limit = 4

        if (isinstance(size_box, ConstInt) and
                size_box.getint() <= 14 * limit):     # same limit as GCC
            # Inline a series of STR operations, starting at 'dstaddr_loc'.
            #
            self.mc.gen_load_int(r.ip.value, 0)
            i = 0
            total_size = size_box.getint()
            while i < total_size:
                sz = itemsize
                if i == next_group:
                    next_group += 4
                    if next_group <= total_size:
                        sz = 4
                if sz == 4:
                    self.mc.STR_ri(r.ip.value, dstaddr_loc.value, imm=i)
                elif sz == 2:
                    self.mc.STRH_ri(r.ip.value, dstaddr_loc.value, imm=i)
                else:
                    self.mc.STRB_ri(r.ip.value, dstaddr_loc.value, imm=i)
                i += sz

        else:
            if isinstance(size_box, ConstInt):
                size_loc = imm(size_box.getint())
            else:
                # load size_loc in a register different than dstaddr_loc
                size_loc = regalloc.rm.make_sure_var_in_reg(size_box,
                                                            [dstaddr_box])
            #
            # call memset()
            regalloc.before_call()
            self.simple_call_no_collect(imm(self.memset_addr),
                                        [dstaddr_loc, imm(0), size_loc])
            regalloc.rm.possibly_free_var(size_box)
        regalloc.rm.possibly_free_var(dstaddr_box)
        return fcond

    def emit_opx_threadlocalref_get(self, op, arglocs, regalloc, fcond):
        ofs_loc, size_loc, sign_loc, res_loc = arglocs
        assert ofs_loc.is_imm()
        assert size_loc.is_imm()
        assert sign_loc.is_imm()
        ofs = self.saved_threadlocal_addr
        self.load_reg(self.mc, res_loc, r.sp, ofs)
        scale = get_scale(size_loc.value)
        signed = (sign_loc.value != 0)
        self._load_from_mem(res_loc, res_loc, ofs_loc, imm(scale), signed,
                            fcond)
        return fcond

    def emit_op_load_from_gc_table(self, op, arglocs, regalloc, fcond):
        res_loc, = arglocs
        index = op.getarg(0).getint()
        self.load_from_gc_table(res_loc.value, index)
        return fcond
