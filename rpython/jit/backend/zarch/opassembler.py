from rpython.jit.backend.llsupport.jump import remap_frame_layout
from rpython.jit.backend.zarch.arch import (WORD,
        STD_FRAME_SIZE_IN_BYTES)
from rpython.jit.backend.zarch.arch import THREADLOCAL_ADDR_OFFSET
from rpython.jit.backend.zarch.helper.assembler import (gen_emit_cmp_op,
        gen_emit_rr_rp, gen_emit_shift, gen_emit_rr_rh_ri_rp, gen_emit_div_mod)
from rpython.jit.backend.zarch.helper.regalloc import (check_imm,
        check_imm_value)
from rpython.jit.metainterp.history import (ConstInt)
from rpython.jit.backend.zarch.codebuilder import ZARCHGuardToken, InstrBuilder
from rpython.jit.backend.llsupport import symbolic, jitframe
from rpython.rlib.rjitlog import rjitlog as jl
import rpython.jit.backend.zarch.conditions as c
import rpython.jit.backend.zarch.registers as r
import rpython.jit.backend.zarch.locations as l
from rpython.jit.backend.zarch.locations import imm
from rpython.jit.backend.zarch import callbuilder
from rpython.jit.backend.zarch.codebuilder import OverwritingBuilder
from rpython.jit.backend.llsupport.descr import CallDescr
from rpython.jit.backend.llsupport.gcmap import allocate_gcmap
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp.history import (FLOAT, INT, REF, VOID)
from rpython.jit.metainterp.resoperation import rop
from rpython.rtyper import rclass
from rpython.rtyper.lltypesystem import rstr, rffi, lltype
from rpython.rtyper.annlowlevel import cast_instance_to_gcref
from rpython.rlib.objectmodel import we_are_translated

class IntOpAssembler(object):
    _mixin_ = True

    emit_int_add = gen_emit_rr_rh_ri_rp('AGR', 'AGHI', 'AGFI', 'AG')
    emit_int_add_ovf = emit_int_add

    emit_nursery_ptr_increment = emit_int_add

    def emit_int_sub(self, op, arglocs, regalloc):
        res, l0, l1 = arglocs
        self.mc.SGRK(res, l0, l1)

    emit_int_sub_ovf = emit_int_sub

    emit_int_mul = gen_emit_rr_rh_ri_rp('MSGR', 'MGHI', 'MSGFI', 'MSG')
    def emit_int_mul_ovf(self, op, arglocs, regalloc):
        lr, lq, l1 = arglocs
        if l1.is_in_pool():
            self.mc.LG(r.SCRATCH, l1)
            l1 = r.SCRATCH
        elif l1.is_imm():
            self.mc.LGFI(r.SCRATCH, l1)
            l1 = r.SCRATCH
        else:
            # we are not allowed to modify l1 if it is not a scratch
            # register, thus copy it here!
            self.mc.LGR(r.SCRATCH, l1)
            l1 = r.SCRATCH

        mc = self.mc

        # check left neg
        jmp_lq_lt_0 = mc.get_relative_pos()
        mc.reserve_cond_jump() # CGIJ lq < 0 +-----------+
        jmp_l1_ge_0 = mc.get_relative_pos() #            |
        mc.reserve_cond_jump() # CGIJ l1 >= 0 -----------|-> (both same sign)
        jmp_lq_pos_l1_neg = mc.get_relative_pos() #      |
        mc.reserve_cond_jump(short=True) #  BCR any -----|-> (xor negative)
        jmp_l1_neg_lq_neg = mc.get_relative_pos() #      |
        mc.reserve_cond_jump() # <-----------------------+
                               # CGIJ l1 < 0 -> (both same_sign)
        # (xor negative)
        label_xor_neg = mc.get_relative_pos()
        mc.LPGR(lq, lq)
        mc.LPGR(l1, l1)
        mc.MLGR(lr, l1)
        mc.LGHI(r.SCRATCH, l.imm(-1))
        mc.RISBG(r.SCRATCH, r.SCRATCH, l.imm(0), l.imm(0x80 | 0), l.imm(0))
        # is the value greater than 2**63 ? then an overflow occurred
        jmp_xor_lq_overflow = mc.get_relative_pos()
        mc.reserve_cond_jump() # CLGRJ lq > 0x8000 ... 00 -> (label_overflow)
        jmp_xor_lr_overflow = mc.get_relative_pos()
        mc.reserve_cond_jump() # CLGIJ lr > 0 -> (label_overflow)
        mc.LCGR(lq, lq) # complement the value
        mc.XGR(r.SCRATCH, r.SCRATCH)
        mc.SPM(r.SCRATCH) # 0x80 ... 00 clears the condition code and program mask
        jmp_no_overflow_xor_neg = mc.get_relative_pos()
        mc.reserve_cond_jump(short=True)

        # both are positive/negative
        label_both_same_sign = mc.get_relative_pos()
        mc.LPGR(lq, lq)
        mc.LPGR(l1, l1)
        mc.MLGR(lr, l1)
        mc.LGHI(r.SCRATCH, l.imm(-1))
        # 0xff -> shift 0 -> 0xff set MSB on pos 0 to zero -> 7f 
        mc.RISBG(r.SCRATCH, r.SCRATCH, l.imm(1), l.imm(0x80 | 63), l.imm(0))
        jmp_lq_overflow = mc.get_relative_pos()
        mc.reserve_cond_jump() # CLGRJ lq > 0x7fff ... ff -> (label_overflow)
        jmp_lr_overflow = mc.get_relative_pos()
        mc.reserve_cond_jump() # CLGIJ lr > 0 -> (label_overflow)
        jmp_neither_lqlr_overflow = mc.get_relative_pos()
        mc.reserve_cond_jump(short=True) # BRC any -> (label_end)


        # set overflow!
        label_overflow = mc.get_relative_pos()
        # set bit 34 & 35 -> indicates overflow
        mc.XGR(r.SCRATCH, r.SCRATCH)
        mc.OILH(r.SCRATCH, l.imm(0x3000)) # sets OF
        mc.SPM(r.SCRATCH)

        # no overflow happended
        label_end = mc.get_relative_pos()

        # patch patch patch!!!

        # jmp_lq_lt_0
        pos = jmp_lq_lt_0
        omc = OverwritingBuilder(self.mc, pos, 1)
        omc.CGIJ(lq, l.imm(0), c.LT, l.imm(jmp_l1_neg_lq_neg - pos))
        omc.overwrite()
        # jmp_l1_ge_0
        pos = jmp_l1_ge_0
        omc = OverwritingBuilder(self.mc, pos, 1)
        omc.CGIJ(l1, l.imm(0), c.GE, l.imm(label_both_same_sign - pos))
        omc.overwrite()
        # jmp_lq_pos_l1_neg
        pos = jmp_lq_pos_l1_neg
        omc = OverwritingBuilder(self.mc, pos, 1)
        omc.BRC(c.ANY, l.imm(label_xor_neg - pos))
        omc.overwrite()
        # jmp_l1_neg_lq_neg
        pos = jmp_l1_neg_lq_neg
        omc = OverwritingBuilder(self.mc, pos, 1)
        omc.CGIJ(l1, l.imm(0), c.LT, l.imm(label_both_same_sign - pos))
        omc.overwrite()

        # patch jmp_xor_lq_overflow
        pos = jmp_xor_lq_overflow
        omc = OverwritingBuilder(self.mc, pos, 1)
        omc.CLGRJ(lq, r.SCRATCH, c.GT, l.imm(label_overflow - pos))
        omc.overwrite()
        # patch jmp_xor_lr_overflow
        pos = jmp_xor_lr_overflow
        omc = OverwritingBuilder(self.mc, pos, 1)
        omc.CLGIJ(lr, l.imm(0), c.GT, l.imm(label_overflow - pos))
        omc.overwrite()
        # patch jmp_no_overflow_xor_neg
        omc = OverwritingBuilder(self.mc, jmp_no_overflow_xor_neg, 1)
        omc.BRC(c.ANY, l.imm(label_end - jmp_no_overflow_xor_neg))
        omc.overwrite()
        # patch jmp_lq_overflow
        omc = OverwritingBuilder(self.mc, jmp_lq_overflow, 1)
        omc.CLGRJ(lq, r.SCRATCH, c.GT, l.imm(label_overflow - jmp_lq_overflow))
        omc.overwrite()
        # patch jmp_lr_overflow
        omc = OverwritingBuilder(self.mc, jmp_lr_overflow, 1)
        omc.CLGIJ(lr, l.imm(0), c.GT, l.imm(label_overflow - jmp_lr_overflow))
        omc.overwrite()
        # patch jmp_neither_lqlr_overflow
        omc = OverwritingBuilder(self.mc, jmp_neither_lqlr_overflow, 1)
        omc.BRC(c.ANY, l.imm(label_end - jmp_neither_lqlr_overflow))
        omc.overwrite()

    def emit_uint_mul_high(self, op, arglocs, regalloc):
        r0, _, a1 = arglocs
        # _ carries the value, contents of r0 are ignored
        assert not r0.is_imm()
        assert not a1.is_imm()
        if a1.is_core_reg():
            self.mc.MLGR(r0, a1)
        else:
            self.mc.MLG(r0, a1)

    def emit_int_invert(self, op, arglocs, regalloc):
        l0, = arglocs
        assert not l0.is_imm()
        self.mc.LGHI(r.SCRATCH, l.imm(-1))
        self.mc.XGR(l0, r.SCRATCH)

    def emit_int_neg(self, op, arglocs, regalloc):
        l0, = arglocs
        self.mc.LCGR(l0, l0)

    def emit_int_signext(self, op, arglocs, regalloc):
        l0, = arglocs
        extend_from = op.getarg(1).getint()
        if extend_from == 1:
            self.mc.LGBR(l0, l0)
        elif extend_from == 2:
            self.mc.LGHR(l0, l0)
        elif extend_from == 4:
            self.mc.LGFR(l0, l0)
        else:
            raise AssertionError(extend_from)

    def emit_int_force_ge_zero(self, op, arglocs, resloc):
        l0, = arglocs
        off = self.mc.CGIJ_byte_count + self.mc.LGHI_byte_count
        self.mc.CGIJ(l0, l.imm(0), c.GE, l.imm(off))
        self.mc.LGHI(l0, l.imm(0))

    def emit_int_is_zero(self, op, arglocs, regalloc):
        l0, res = arglocs
        self.mc.CGHI(l0, l.imm(0))
        self.flush_cc(c.EQ, res)

    def emit_int_is_true(self, op, arglocs, regalloc):
        l0, res = arglocs
        self.mc.CGHI(l0, l.imm(0))
        self.flush_cc(c.NE, res)

    emit_int_and = gen_emit_rr_rp("NGR", "NG")
    emit_int_or  = gen_emit_rr_rp("OGR", "OG")
    emit_int_xor = gen_emit_rr_rp("XGR", "XG")

    emit_int_rshift  = gen_emit_shift("SRAG")
    emit_int_lshift  = gen_emit_shift("SLLG")
    emit_uint_rshift = gen_emit_shift("SRLG")

    emit_int_le = gen_emit_cmp_op(c.LE)
    emit_int_lt = gen_emit_cmp_op(c.LT)
    emit_int_gt = gen_emit_cmp_op(c.GT)
    emit_int_ge = gen_emit_cmp_op(c.GE)
    emit_int_eq = gen_emit_cmp_op(c.EQ)
    emit_int_ne = gen_emit_cmp_op(c.NE)

    emit_ptr_eq = emit_int_eq
    emit_ptr_ne = emit_int_ne

    emit_instance_ptr_eq = emit_ptr_eq
    emit_instance_ptr_ne = emit_ptr_ne

    emit_uint_le = gen_emit_cmp_op(c.LE, signed=False)
    emit_uint_lt = gen_emit_cmp_op(c.LT, signed=False)
    emit_uint_gt = gen_emit_cmp_op(c.GT, signed=False)
    emit_uint_ge = gen_emit_cmp_op(c.GE, signed=False)

class FloatOpAssembler(object):
    _mixin_ = True

    emit_float_add = gen_emit_rr_rp('ADBR', 'ADB')
    emit_float_sub = gen_emit_rr_rp('SDBR', 'SDB')
    emit_float_mul = gen_emit_rr_rp('MDBR', 'MDB')
    emit_float_truediv = gen_emit_rr_rp('DDBR', 'DDB')

    # Support for NaNs: S390X sets condition code to 0x3 (unordered)
    # whenever any operand is nan.
    # in the case float_le,float_ge the overflow bit is not set of
    # the initial condition!
    # e.g. guard_true(nan <= x): jumps 1100 inv => 0011, bit 3 set
    # e.g. guard_false(nan <= x): does not jump 1100, bit 3 not set
    # e.g. guard_true(nan >= nan): jumps 1010 inv => 0101, bit 3 set
    emit_float_lt = gen_emit_cmp_op(c.LT, fp=True)
    emit_float_le = gen_emit_cmp_op(c.FLE, fp=True)
    emit_float_eq = gen_emit_cmp_op(c.EQ, fp=True)
    emit_float_ne = gen_emit_cmp_op(c.NE, fp=True)
    emit_float_gt = gen_emit_cmp_op(c.GT, fp=True)
    emit_float_ge = gen_emit_cmp_op(c.FGE, fp=True)

    def emit_float_neg(self, op, arglocs, regalloc):
        l0, = arglocs
        self.mc.LCDBR(l0, l0)

    def emit_float_abs(self, op, arglocs, regalloc):
        l0, = arglocs
        self.mc.LPDBR(l0, l0)

    def emit_cast_float_to_int(self, op, arglocs, regalloc):
        f0, r0 = arglocs
        self.mc.CGDBR(r0, c.FP_TOWARDS_ZERO, f0)

    def emit_cast_int_to_float(self, op, arglocs, regalloc):
        r0, f0 = arglocs
        self.mc.CDGBR(f0, r0)

    def emit_convert_float_bytes_to_longlong(self, op, arglocs, regalloc):
        l0, res = arglocs
        self.mc.LGDR(res, l0)

    def emit_convert_longlong_bytes_to_float(self, op, arglocs, regalloc):
        l0, res = arglocs
        self.mc.LDGR(res, l0)

class CallOpAssembler(object):

    _mixin_ = True

    def _emit_call(self, op, arglocs, is_call_release_gil=False):
        resloc = arglocs[0]
        func_index = 1 + is_call_release_gil
        adr = arglocs[func_index]
        arglist = arglocs[func_index+1:]

        cb = callbuilder.CallBuilder(self, adr, arglist, resloc, op.getdescr())

        descr = op.getdescr()
        assert isinstance(descr, CallDescr)
        cb.argtypes = descr.get_arg_types()
        cb.restype  = descr.get_result_type()

        if is_call_release_gil:
            saveerrloc = arglocs[1]
            assert saveerrloc.is_imm()
            cb.emit_call_release_gil(saveerrloc.value)
        else:
            cb.emit()

    def _genop_call(self, op, arglocs, regalloc):
        oopspecindex = regalloc.get_oopspecindex(op)
        if oopspecindex == EffectInfo.OS_MATH_SQRT:
            return self._emit_math_sqrt(op, arglocs, regalloc)
        if oopspecindex == EffectInfo.OS_THREADLOCALREF_GET:
            return self._emit_threadlocalref_get(op, arglocs, regalloc)
        self._emit_call(op, arglocs)

    emit_call_i = _genop_call
    emit_call_r = _genop_call
    emit_call_f = _genop_call
    emit_call_n = _genop_call

    def _emit_threadlocalref_get(self, op, arglocs, regalloc):
        [resloc] = arglocs
        offset = op.getarg(1).getint()   # getarg(0) == 'threadlocalref_get'
        calldescr = op.getdescr()
        size = calldescr.get_result_size()
        sign = calldescr.is_result_signed()
        #
        # This loads the stack location THREADLOCAL_OFS into a
        # register, and then read the word at the given offset.
        # It is only supported if 'translate_support_code' is
        # true; otherwise, the execute_token() was done with a
        # dummy value for the stack location THREADLOCAL_OFS
        #
        assert self.cpu.translate_support_code
        assert resloc.is_reg()
        assert check_imm_value(offset)
        self.mc.LG(resloc, l.addr(THREADLOCAL_ADDR_OFFSET, r.SP))
        self._memory_read(resloc, l.addr(offset, resloc), size, sign)

    def _emit_math_sqrt(self, op, arglocs, regalloc):
        l0, res = arglocs
        self.mc.SQDBR(res, l0)

    def _genop_call_may_force(self, op, arglocs, regalloc):
        self._store_force_index(self._find_nearby_operation(regalloc, +1))
        self._emit_call(op, arglocs)

    emit_call_may_force_i = _genop_call_may_force
    emit_call_may_force_r = _genop_call_may_force
    emit_call_may_force_f = _genop_call_may_force
    emit_call_may_force_n = _genop_call_may_force

    def _genop_call_release_gil(self, op, arglocs, regalloc):
        self._store_force_index(self._find_nearby_operation(regalloc, +1))
        self._emit_call(op, arglocs, is_call_release_gil=True)

    emit_call_release_gil_i = _genop_call_release_gil
    emit_call_release_gil_f = _genop_call_release_gil
    emit_call_release_gil_n = _genop_call_release_gil

    def _store_force_index(self, guard_op):
        assert (guard_op.getopnum() == rop.GUARD_NOT_FORCED or
                guard_op.getopnum() == rop.GUARD_NOT_FORCED_2)
        faildescr = guard_op.getdescr()
        ofs = self.cpu.get_ofs_of_frame_field('jf_force_descr')
        #
        faildescrindex = self.get_gcref_from_faildescr(faildescr)
        self.load_gcref_into(r.SCRATCH, faildescrindex)
        self.mc.STG(r.SCRATCH, l.addr(ofs, r.SPP))

    def _find_nearby_operation(self, regalloc, delta):
        return regalloc.operations[regalloc.rm.position + delta]

    _COND_CALL_SAVE_REGS = [r.r11, r.r2, r.r3, r.r4, r.r5]

    def emit_cond_call(self, op, arglocs, regalloc):
        resloc = arglocs[0]
        arglocs = arglocs[1:]

        fcond = self.guard_success_cc
        self.guard_success_cc = c.cond_none
        assert fcond.value != c.cond_none.value

        jmp_adr = self.mc.get_relative_pos()
        self.mc.reserve_cond_jump() # patched later to a relative branch

        # save away r2, r3, r4, r5, r11 into the jitframe
        should_be_saved = [
            reg for reg in self._regalloc.rm.reg_bindings.itervalues()
                if reg in self._COND_CALL_SAVE_REGS]
        self._push_core_regs_to_jitframe(self.mc, should_be_saved)

        self.push_gcmap(self.mc, regalloc.get_gcmap([resloc]))
        #
        # load the 0-to-4 arguments into these registers, with the address of
        # the function to call into r11
        remap_frame_layout(self, arglocs,
                           [r.r11, r.r2, r.r3, r.r4, r.r5][:len(arglocs)],
                           r.SCRATCH)
        #
        # figure out which variant of cond_call_slowpath to call, and call it
        callee_only = False
        floats = False
        for reg in regalloc.rm.reg_bindings.values():
            if reg not in regalloc.rm.save_around_call_regs:
                break
        else:
            callee_only = True
        if regalloc.fprm.reg_bindings:
            floats = True
        cond_call_adr = self.cond_call_slowpath[floats * 2 + callee_only]
        self.mc.load_imm(r.r14, cond_call_adr)
        self.mc.BASR(r.r14, r.r14)
        # restoring the registers saved above, and doing pop_gcmap(), is left
        # to the cond_call_slowpath helper.  We never have any result value.
        if resloc is not None:
            self.mc.LGR(resloc, r.SCRATCH2)
        relative_target = self.mc.currpos() - jmp_adr
        pmc = OverwritingBuilder(self.mc, jmp_adr, 1)
        pmc.BRCL(fcond, l.imm(relative_target))
        pmc.overwrite()
        # might be overridden again to skip over the following
        # guard_no_exception too
        self.previous_cond_call_jcond = jmp_adr, fcond

    emit_cond_call_value_i = emit_cond_call
    emit_cond_call_value_r = emit_cond_call

class AllocOpAssembler(object):
    _mixin_ = True

    def emit_check_memory_error(self, op, arglocs, regalloc):
        self.propagate_memoryerror_if_reg_is_null(arglocs[0])

    def emit_call_malloc_nursery(self, op, arglocs, regalloc):
        # registers r.RES and r.RSZ are allocated for this call
        size_box = op.getarg(0)
        assert isinstance(size_box, ConstInt)
        size = size_box.getint()
        gc_ll_descr = self.cpu.gc_ll_descr
        gcmap = regalloc.get_gcmap([r.RES, r.RSZ])
        self.malloc_cond(
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            size, gcmap)

    def emit_call_malloc_nursery_varsize_frame(self, op, arglocs, regalloc):
        # registers r.RES and r.RSZ are allocated for this call
        [sizeloc] = arglocs
        gc_ll_descr = self.cpu.gc_ll_descr
        gcmap = regalloc.get_gcmap([r.RES, r.RSZ])
        self.malloc_cond_varsize_frame(
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            sizeloc, gcmap)

    def emit_call_malloc_nursery_varsize(self, op, arglocs, regalloc):
        # registers r.RES and r.RSZ are allocated for this call
        gc_ll_descr = self.cpu.gc_ll_descr
        if not hasattr(gc_ll_descr, 'max_size_of_young_obj'):
            raise Exception("unreachable code")
            # for boehm, this function should never be called
        [lengthloc] = arglocs
        arraydescr = op.getdescr()
        itemsize = op.getarg(1).getint()
        maxlength = (gc_ll_descr.max_size_of_young_obj - WORD * 2) // itemsize
        gcmap = regalloc.get_gcmap([r.RES, r.RSZ])
        self.malloc_cond_varsize(
            op.getarg(0).getint(),
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            lengthloc, itemsize, maxlength, gcmap, arraydescr)

    def emit_debug_merge_point(self, op, arglocs, regalloc):
        pass

    emit_jit_debug = emit_debug_merge_point
    emit_keepalive = emit_debug_merge_point

    def emit_enter_portal_frame(self, op, arglocs, regalloc):
        self.enter_portal_frame(op)

    def emit_leave_portal_frame(self, op, arglocs, regalloc):
        self.leave_portal_frame(op)

    def _write_barrier_fastpath(self, mc, descr, arglocs, regalloc, array=False,
                                is_frame=False):
        # Write code equivalent to write_barrier() in the GC: it checks
        # a flag in the object at arglocs[0], and if set, it calls a
        # helper piece of assembler.  The latter saves registers as needed
        # and call the function remember_young_pointer() from the GC.
        if we_are_translated():
            cls = self.cpu.gc_ll_descr.has_write_barrier_class()
            assert cls is not None and isinstance(descr, cls)
        #
        card_marking_mask = 0
        mask = descr.jit_wb_if_flag_singlebyte
        if array and descr.jit_wb_cards_set != 0:
            # assumptions the rest of the function depends on:
            assert (descr.jit_wb_cards_set_byteofs ==
                    descr.jit_wb_if_flag_byteofs)
            card_marking_mask = descr.jit_wb_cards_set_singlebyte
        #
        loc_base = arglocs[0]
        assert loc_base.is_reg()
        if is_frame:
            assert loc_base is r.SPP
        assert check_imm_value(descr.jit_wb_if_flag_byteofs)
        mc.LLGC(r.SCRATCH2, l.addr(descr.jit_wb_if_flag_byteofs, loc_base))
        mc.LGR(r.SCRATCH, r.SCRATCH2)
        mc.NILL(r.SCRATCH, l.imm(mask & 0xFF))

        jz_location = mc.get_relative_pos()
        mc.reserve_cond_jump(short=True)  # patched later with 'EQ'

        # for cond_call_gc_wb_array, also add another fast path:
        # if GCFLAG_CARDS_SET, then we can just set one bit and be done
        if card_marking_mask:
            # GCFLAG_CARDS_SET is in the same byte, loaded in r2 already
            mc.LGR(r.SCRATCH, r.SCRATCH2)
            mc.NILL(r.SCRATCH, l.imm(card_marking_mask & 0xFF))
            js_location = mc.get_relative_pos()
            mc.reserve_cond_jump()  # patched later with 'NE'
        else:
            js_location = 0

        # Write only a CALL to the helper prepared in advance, passing it as
        # argument the address of the structure we are writing into
        # (the first argument to COND_CALL_GC_WB).
        helper_num = (card_marking_mask != 0)
        if is_frame:
            helper_num = 4
        elif regalloc.fprm.reg_bindings:
            helper_num += 2
        if self.wb_slowpath[helper_num] == 0:    # tests only
            assert not we_are_translated()
            assert not is_frame
            self.cpu.gc_ll_descr.write_barrier_descr = descr
            self._build_wb_slowpath(card_marking_mask != 0,
                                    bool(regalloc.fprm.reg_bindings))
            assert self.wb_slowpath[helper_num] != 0
        #
        if not is_frame:
            mc.LGR(r.r0, loc_base)    # unusual argument location

        mc.load_imm(r.r14, self.wb_slowpath[helper_num])
        mc.BASR(r.r14, r.r14)

        if card_marking_mask:
            # The helper ends again with a check of the flag in the object.
            # So here, we can simply write again a beq, which will be
            # taken if GCFLAG_CARDS_SET is still not set.
            jns_location = mc.get_relative_pos()
            mc.reserve_cond_jump(short=True)
            #
            # patch the 'NE' above
            currpos = mc.currpos()
            pmc = OverwritingBuilder(mc, js_location, 1)
            pmc.BRCL(c.NE, l.imm(currpos - js_location))
            pmc.overwrite()
            #
            # case GCFLAG_CARDS_SET: emit a few instructions to do
            # directly the card flag setting
            loc_index = arglocs[1]
            if loc_index.is_reg():
                tmp_loc = arglocs[2]
                n = descr.jit_wb_card_page_shift

                assert tmp_loc is not loc_index

                # compute in tmp_loc the byte offset:
                #   tmp_loc = ~(index >> (card_page_shift + 3))
                mc.SRLG(tmp_loc, loc_index, l.addr(n+3))
                # invert the bits of tmp_loc

                # compute in SCRATCH the index of the bit inside the byte:
                #    scratch = (index >> card_page_shift) & 7
                # 0x80 sets zero flag. will store 0 into all not selected bits
                mc.RISBG(r.SCRATCH, loc_index, l.imm(61), l.imm(0x80 | 63), l.imm(64-n))
                mc.LGHI(r.SCRATCH2, l.imm(-1))
                mc.XGR(tmp_loc, r.SCRATCH2)

                # set SCRATCH2 to 1 << r1
                mc.LGHI(r.SCRATCH2, l.imm(1))
                mc.SLLG(r.SCRATCH2, r.SCRATCH2, l.addr(0,r.SCRATCH))

                # set this bit inside the byte of interest
                addr = l.addr(0, loc_base, tmp_loc)
                mc.LLGC(r.SCRATCH, addr)
                mc.OGRK(r.SCRATCH, r.SCRATCH, r.SCRATCH2)
                mc.STCY(r.SCRATCH, addr)
                # done
            else:
                byte_index = loc_index.value >> descr.jit_wb_card_page_shift
                byte_ofs = ~(byte_index >> 3)
                byte_val = 1 << (byte_index & 7)
                assert check_imm_value(byte_ofs, lower_bound=-2**19, upper_bound=2**19-1)

                addr = l.addr(byte_ofs, loc_base)
                mc.LLGC(r.SCRATCH, addr)
                mc.OILL(r.SCRATCH, l.imm(byte_val))
                mc.STCY(r.SCRATCH, addr)
            #
            # patch the beq just above
            currpos = mc.currpos()
            pmc = OverwritingBuilder(mc, jns_location, 1)
            pmc.BRC(c.EQ, l.imm(currpos - jns_location))
            pmc.overwrite()

        # patch the JZ above
        currpos = mc.currpos()
        pmc = OverwritingBuilder(mc, jz_location, 1)
        pmc.BRC(c.EQ, l.imm(currpos - jz_location))
        pmc.overwrite()

    def emit_cond_call_gc_wb(self, op, arglocs, regalloc):
        self._write_barrier_fastpath(self.mc, op.getdescr(), arglocs, regalloc)

    def emit_cond_call_gc_wb_array(self, op, arglocs, regalloc):
        self._write_barrier_fastpath(self.mc, op.getdescr(), arglocs, regalloc,
                                     array=True)


class GuardOpAssembler(object):
    _mixin_ = True

    def _emit_guard(self, op, arglocs, is_guard_not_invalidated=False):
        if is_guard_not_invalidated:
            fcond = c.cond_none
        else:
            fcond = self.guard_success_cc
            self.guard_success_cc = c.cond_none
            assert fcond.value != c.cond_none.value
            fcond = c.negate(fcond)

        token = self.build_guard_token(op, arglocs[0].value, arglocs[1:], fcond)
        token.pos_jump_offset = self.mc.currpos()
        assert token.guard_not_invalidated() == is_guard_not_invalidated
        if not is_guard_not_invalidated:
            self.mc.reserve_guard_branch()     # has to be patched later on
        self.pending_guard_tokens.append(token)

    def build_guard_token(self, op, frame_depth, arglocs, fcond):
        descr = op.getdescr()
        gcmap = allocate_gcmap(self, frame_depth, r.JITFRAME_FIXED_SIZE)
        faildescrindex = self.get_gcref_from_faildescr(descr)
        token = ZARCHGuardToken(self.cpu, gcmap, descr, op.getfailargs(),
                              arglocs, op.getopnum(), frame_depth,
                              faildescrindex, fcond)
        #token._pool_offset = self.pool.get_descr_offset(descr)
        return token

    def emit_load_from_gc_table(self, op, arglocs, regalloc):
        resloc, = arglocs
        index = op.getarg(0).getint()
        assert resloc.is_reg()
        self.load_gcref_into(resloc, index)

    def emit_guard_true(self, op, arglocs, regalloc):
        self._emit_guard(op, arglocs)

    def emit_guard_false(self, op, arglocs, regalloc):
        self.guard_success_cc = c.negate(self.guard_success_cc)
        self._emit_guard(op, arglocs)

    def emit_guard_overflow(self, op, arglocs, regalloc):
        self.guard_success_cc = c.OF
        self._emit_guard(op, arglocs)

    def emit_guard_no_overflow(self, op, arglocs, regalloc):
        self.guard_success_cc = c.NO
        self._emit_guard(op, arglocs)

    def emit_guard_value(self, op, arglocs, regalloc):
        l0 = arglocs[0]
        l1 = arglocs[1]
        failargs = arglocs[2:]

        if l0.is_reg():
            if l1.is_imm():
                self.mc.cmp_op(l0, l1, imm=True)
            else:
                self.mc.cmp_op(l0, l1)
        elif l0.is_fp_reg():
            assert l1.is_fp_reg()
            self.mc.cmp_op(l0, l1, fp=True)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, failargs)

    emit_guard_nonnull = emit_guard_true
    emit_guard_isnull = emit_guard_false

    def emit_guard_class(self, op, arglocs, regalloc):
        self._cmp_guard_class(op, arglocs, regalloc)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs[2:])

    def emit_guard_nonnull_class(self, op, arglocs, regalloc):
        self.mc.cmp_op(arglocs[0], l.imm(1), imm=True, signed=False)

        patch_pos = self.mc.currpos()
        self.mc.reserve_cond_jump(short=True)

        self._cmp_guard_class(op, arglocs, regalloc)
        #self.mc.CGRT(r.SCRATCH, r.SCRATCH2, c.NE)

        pmc = OverwritingBuilder(self.mc, patch_pos, 1)
        pmc.BRC(c.LT, l.imm(self.mc.currpos() - patch_pos))
        pmc.overwrite()

        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs[2:])

    def _cmp_guard_class(self, op, locs, regalloc):
        offset = self.cpu.vtable_offset
        loc_ptr = locs[0]
        loc_classptr = locs[1]
        if offset is not None:
            # could be one instruction shorter, but don't care because
            # it's not this case that is commonly translated
            self.mc.LG(r.SCRATCH, l.addr(offset, loc_ptr))
            self.mc.load_imm(r.SCRATCH2, locs[1].value)
            self.mc.cmp_op(r.SCRATCH, r.SCRATCH2)
        else:
            classptr = loc_classptr.value
            expected_typeid = (self.cpu.gc_ll_descr
                    .get_typeid_from_classptr_if_gcremovetypeptr(classptr))
            self._cmp_guard_gc_type(loc_ptr, expected_typeid)

    def _read_typeid(self, targetreg, loc_ptr):
        # Note that the typeid half-word is at offset 0 on a little-endian
        # machine; it is at offset 2 or 4 on a big-endian machine.
        assert self.cpu.supports_guard_gc_type
        self.mc.LGF(targetreg, l.addr(4, loc_ptr))

    def _cmp_guard_gc_type(self, loc_ptr, expected_typeid):
        self._read_typeid(r.SCRATCH2, loc_ptr)
        assert 0 <= expected_typeid <= 0x7fffffff   # 4 bytes are always enough
        # we can handle 4 byte compare immediate
        self.mc.cmp_op(r.SCRATCH2, l.imm(expected_typeid),
                       imm=True, signed=False)

    def emit_guard_gc_type(self, op, arglocs, regalloc):
        self._cmp_guard_gc_type(arglocs[0], arglocs[1].value)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs[2:])

    def emit_guard_is_object(self, op, arglocs, regalloc):
        assert self.cpu.supports_guard_gc_type
        loc_object = arglocs[0]
        # idea: read the typeid, fetch one byte of the field 'infobits' from
        # the big typeinfo table, and check the flag 'T_IS_RPYTHON_INSTANCE'.
        base_type_info, shift_by, sizeof_ti = (
            self.cpu.gc_ll_descr.get_translated_info_for_typeinfo())
        infobits_offset, IS_OBJECT_FLAG = (
            self.cpu.gc_ll_descr.get_translated_info_for_guard_is_object())

        self._read_typeid(r.SCRATCH2, loc_object)
        self.mc.load_imm(r.SCRATCH, base_type_info + infobits_offset)
        assert shift_by == 0
        self.mc.AGR(r.SCRATCH, r.SCRATCH2)
        self.mc.LLGC(r.SCRATCH2, l.addr(0, r.SCRATCH)) # cannot use r.r0 as index reg
        self.mc.NILL(r.SCRATCH2, l.imm(IS_OBJECT_FLAG & 0xff))
        self.guard_success_cc = c.NE
        self._emit_guard(op, arglocs[1:])

    def emit_guard_subclass(self, op, arglocs, regalloc):
        assert self.cpu.supports_guard_gc_type
        loc_object = arglocs[0]
        loc_check_against_class = arglocs[1]
        offset = self.cpu.vtable_offset
        offset2 = self.cpu.subclassrange_min_offset
        if offset is not None:
            # read this field to get the vtable pointer
            self.mc.LG(r.SCRATCH, l.addr(offset, loc_object))
            # read the vtable's subclassrange_min field
            assert check_imm_value(offset2)
            self.mc.load(r.SCRATCH2, r.SCRATCH, offset2)
        else:
            # read the typeid
            self._read_typeid(r.SCRATCH, loc_object)
            # read the vtable's subclassrange_min field, as a single
            # step with the correct offset
            base_type_info, shift_by, sizeof_ti = (
                self.cpu.gc_ll_descr.get_translated_info_for_typeinfo())
            self.mc.load_imm(r.SCRATCH2, base_type_info + sizeof_ti + offset2)
            assert shift_by == 0
            # add index manually
            # we cannot use r0 in l.addr(...)
            self.mc.AGR(r.SCRATCH, r.SCRATCH2)
            self.mc.load(r.SCRATCH2, r.SCRATCH, 0)
        # get the two bounds to check against
        vtable_ptr = loc_check_against_class.getint()
        vtable_ptr = rffi.cast(rclass.CLASSTYPE, vtable_ptr)
        check_min = vtable_ptr.subclassrange_min
        check_max = vtable_ptr.subclassrange_max
        assert check_max > check_min
        check_diff = check_max - check_min - 1
        # right now, a full PyPy uses less than 6000 numbers,
        # so we'll assert here that it always fit inside 15 bits
        assert 0 <= check_min <= 0x7fff
        assert 0 <= check_diff <= 0xffff
        # check by doing the unsigned comparison (tmp - min) < (max - min)
        self.mc.AGHI(r.SCRATCH2, l.imm(-check_min))
        self.mc.cmp_op(r.SCRATCH2, l.imm(check_diff), imm=True, signed=False)
        # the guard passes if we get a result of "below or equal"
        self.guard_success_cc = c.LE
        self._emit_guard(op, arglocs[2:])

    def emit_guard_not_invalidated(self, op, arglocs, regalloc):
        self._emit_guard(op, arglocs, is_guard_not_invalidated=True)

    def emit_guard_not_forced(self, op, arglocs, regalloc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.LG(r.SCRATCH, l.addr(ofs, r.SPP))
        self.mc.cmp_op(r.SCRATCH, l.imm(0), imm=True)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs)

    def emit_guard_not_forced_2(self, op, arglocs, regalloc):
        guard_token = self.build_guard_token(op, arglocs[0].value, arglocs[1:],
                                             c.cond_none)
        self._finish_gcmap = guard_token.gcmap
        self._store_force_index(op)
        self.store_info_on_descr(0, guard_token)

    def emit_guard_exception(self, op, arglocs, regalloc):
        loc, resloc = arglocs[:2]
        failargs = arglocs[2:]

        mc = self.mc
        mc.load_imm(r.SCRATCH, self.cpu.pos_exc_value())
        diff = self.cpu.pos_exception() - self.cpu.pos_exc_value()
        assert check_imm_value(diff)

        mc.LG(r.SCRATCH2, l.addr(diff, r.SCRATCH))
        mc.cmp_op(r.SCRATCH2, loc)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, failargs)

        if resloc:
            mc.load(resloc, r.SCRATCH, 0)
        mc.LGHI(r.SCRATCH2, l.imm(0))
        mc.STG(r.SCRATCH2, l.addr(0, r.SCRATCH))
        mc.STG(r.SCRATCH2, l.addr(diff, r.SCRATCH))

    def emit_save_exc_class(self, op, arglocs, regalloc):
        [resloc] = arglocs
        diff = self.mc.load_imm_plus(r.SCRATCH, self.cpu.pos_exception())
        self.mc.load(resloc, r.SCRATCH, diff)

    def emit_save_exception(self, op, arglocs, regalloc):
        [resloc] = arglocs
        self._store_and_reset_exception(self.mc, resloc)

    def emit_restore_exception(self, op, arglocs, regalloc):
        self._restore_exception(self.mc, arglocs[1], arglocs[0])

    def emit_guard_no_exception(self, op, arglocs, regalloc):
        self.mc.load_imm(r.SCRATCH, self.cpu.pos_exception())
        self.mc.LG(r.SCRATCH2, l.addr(0,r.SCRATCH))
        self.mc.cmp_op(r.SCRATCH2, l.imm(0), imm=True)
        self.guard_success_cc = c.EQ
        self._emit_guard(op, arglocs)
        # If the previous operation was a COND_CALL, overwrite its conditional
        # jump to jump over this GUARD_NO_EXCEPTION as well, if we can
        if self._find_nearby_operation(regalloc,-1).getopnum() == rop.COND_CALL:
            jmp_adr, fcond = self.previous_cond_call_jcond
            relative_target = self.mc.currpos() - jmp_adr
            pmc = OverwritingBuilder(self.mc, jmp_adr, 1)
            pmc.BRCL(fcond, l.imm(relative_target))
            pmc.overwrite()


class MemoryOpAssembler(object):
    _mixin_ = True

    def _memory_read(self, result_loc, source_loc, size, sign):
        # res, base_loc, ofs, size and signed are all locations
        if size == 8:
            if result_loc.is_fp_reg():
                self.mc.LDY(result_loc, source_loc)
            else:
                self.mc.LG(result_loc, source_loc)
        elif size == 4:
            if sign:
                self.mc.LGF(result_loc, source_loc)
            else:
                self.mc.LLGF(result_loc, source_loc)
        elif size == 2:
            if sign:
                self.mc.LGH(result_loc, source_loc)
            else:
                self.mc.LLGH(result_loc, source_loc)
        elif size == 1:
            if sign:
                self.mc.LGB(result_loc, source_loc)
            else:
                self.mc.LLGC(result_loc, source_loc)
        else:
            assert 0, "size not supported"

    def _memory_store(self, value_loc, addr_loc, size):
        if size.value == 8:
            if value_loc.is_fp_reg():
                self.mc.STDY(value_loc, addr_loc)
            else:
                self.mc.STG(value_loc, addr_loc)
        elif size.value == 4:
            self.mc.STY(value_loc, addr_loc)
        elif size.value == 2:
            self.mc.STHY(value_loc, addr_loc)
        elif size.value == 1:
            self.mc.STCY(value_loc, addr_loc)
        else:
            assert 0, "size not supported"


    def _emit_gc_load(self, op, arglocs, regalloc):
        result_loc, base_loc, index_loc, size_loc, sign_loc = arglocs
        addr_loc = self._load_address(base_loc, index_loc, l.imm0)
        self._memory_read(result_loc, addr_loc, size_loc.value, sign_loc.value)

    emit_gc_load_i = _emit_gc_load
    emit_gc_load_f = _emit_gc_load
    emit_gc_load_r = _emit_gc_load

    def _emit_gc_load_indexed(self, op, arglocs, regalloc):
        result_loc, base_loc, index_loc, offset_loc, size_loc, sign_loc=arglocs
        addr_loc = self._load_address(base_loc, index_loc, offset_loc)
        self._memory_read(result_loc, addr_loc, size_loc.value, sign_loc.value)

    emit_gc_load_indexed_i = _emit_gc_load_indexed
    emit_gc_load_indexed_f = _emit_gc_load_indexed
    emit_gc_load_indexed_r = _emit_gc_load_indexed

    def emit_gc_store(self, op, arglocs, regalloc):
        (base_loc, index_loc, value_loc, size_loc) = arglocs
        addr_loc = self._load_address(base_loc, index_loc, l.imm0)
        self._memory_store(value_loc, addr_loc, size_loc)

    def emit_gc_store_indexed(self, op, arglocs, regalloc):
        (base_loc, index_loc, value_loc, offset_loc, size_loc) = arglocs
        addr_loc = self._load_address(base_loc, index_loc, offset_loc)
        self._memory_store(value_loc, addr_loc, size_loc)

    def _load_address(self, base_loc, index_loc, offset_imm):
        assert offset_imm.is_imm()
        offset = offset_imm.value
        if index_loc.is_imm():
            offset = index_loc.value + offset
            if self._mem_offset_supported(offset):
                addr_loc = l.addr(offset, base_loc)
            else:
                self.mc.load_imm(r.SCRATCH, offset)
                addr_loc = l.addr(0, base_loc, r.SCRATCH)
        else:
            assert self._mem_offset_supported(offset)
            addr_loc = l.addr(offset, base_loc, index_loc)
        return addr_loc


    def _mem_offset_supported(self, value):
        return -2**19 <= value < 2**19

    # ...copystrcontent logic was removed, but note that
    # if we want to reintroduce support for that:
    # s390x has memset directly as a hardware instruction!!
    # 0xB8 means we might reference dst later
    #self.mc.MVCLE(dst, src, l.addr(0xB8))
    # NOTE this instruction can (determined by the cpu), just
    # quit the movement any time, thus it is looped until all bytes
    # are copied!
    #self.mc.BRC(c.OF, l.imm(-self.mc.MVCLE_byte_count))

    def emit_zero_array(self, op, arglocs, regalloc):
        base_loc, startindex_loc, length_loc, \
            ofs_loc, itemsize_loc = arglocs

        if ofs_loc.is_imm():
            assert check_imm_value(ofs_loc.value)
            self.mc.AGHI(base_loc, ofs_loc)
        else:
            self.mc.AGR(base_loc, ofs_loc)
        if startindex_loc.is_imm():
            assert check_imm_value(startindex_loc.value)
            self.mc.AGHI(base_loc, startindex_loc)
        else:
            self.mc.AGR(base_loc, startindex_loc)
        assert not length_loc.is_imm()
        # contents of r0 do not matter because r1 is zero, so
        # no copying takes place
        self.mc.XGR(r.r1, r.r1)

        assert base_loc.is_even()
        assert length_loc.value == base_loc.value + 1

        # s390x has memset directly as a hardware instruction!!
        # it needs 5 registers allocated
        # dst = rX, dst len = rX+1 (ensured by the regalloc)
        # src = r0, src len = r1
        self.mc.MVCLE(base_loc, r.r0, l.addr(0))
        # NOTE this instruction can (determined by the cpu), just
        # quit the movement any time, thus it is looped until all bytes
        # are copied!
        self.mc.BRC(c.OF, l.imm(-self.mc.MVCLE_byte_count))


class ForceOpAssembler(object):
    _mixin_ = True

    def emit_force_token(self, op, arglocs, regalloc):
        res_loc = arglocs[0]
        self.mc.LGR(res_loc, r.SPP)

    def _genop_call_assembler(self, op, arglocs, regalloc):
        if len(arglocs) == 3:
            [result_loc, argloc, vloc] = arglocs
        else:
            [result_loc, argloc] = arglocs
            vloc = imm(0)
        self._store_force_index(self._find_nearby_operation(regalloc, +1))
        # 'result_loc' is either r2, f0 or None
        self.call_assembler(op, argloc, vloc, result_loc, r.r2)
        self.mc.LARL(r.POOL, l.halfword(self.pool.pool_start - self.mc.get_relative_pos()))

    emit_call_assembler_i = _genop_call_assembler
    emit_call_assembler_r = _genop_call_assembler
    emit_call_assembler_f = _genop_call_assembler
    emit_call_assembler_n = _genop_call_assembler

    imm = staticmethod(imm)   # for call_assembler()

    def _call_assembler_emit_call(self, addr, argloc, _):
        self.regalloc_mov(argloc, r.r2)
        self.mc.LG(r.r3, l.addr(THREADLOCAL_ADDR_OFFSET, r.SP))

        cb = callbuilder.CallBuilder(self, addr, [r.r2, r.r3], r.r2, None)
        cb.emit()

    def _call_assembler_emit_helper_call(self, addr, arglocs, result_loc):
        cb = callbuilder.CallBuilder(self, addr, arglocs, result_loc, None)
        cb.emit()

    def _call_assembler_check_descr(self, value, tmploc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.LG(r.SCRATCH, l.addr(ofs, r.r2))
        if check_imm_value(value):
            self.mc.cmp_op(r.SCRATCH, l.imm(value), imm=True)
        else:
            self.mc.load_imm(r.SCRATCH2, value)
            self.mc.cmp_op(r.SCRATCH, r.SCRATCH2, imm=False)
        jump_if_eq = self.mc.currpos()
        self.mc.trap()      # patched later
        self.mc.write('\x00' * 4) # patched later
        return jump_if_eq

    def _call_assembler_patch_je(self, result_loc, je_location):
        jump_to_done = self.mc.currpos()
        self.mc.trap()      # patched later
        self.mc.write('\x00' * 4) # patched later
        #
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, je_location, 1)
        pmc.BRCL(c.EQ, l.imm(currpos - je_location))
        pmc.overwrite()
        #
        return jump_to_done

    def _call_assembler_load_result(self, op, result_loc):
        if op.type != VOID:
            # load the return value from the dead frame's value index 0
            kind = op.type
            descr = self.cpu.getarraydescr_for_frame(kind)
            ofs = self.cpu.unpack_arraydescr(descr)
            if kind == FLOAT:
                assert result_loc is r.f0
                self.mc.LD(r.f0, l.addr(ofs, r.r2))
            else:
                assert result_loc is r.r2
                self.mc.LG(r.r2, l.addr(ofs, r.r2))

    def _call_assembler_patch_jmp(self, jmp_location):
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_location, 1)
        pmc.BRCL(c.ANY, l.imm(currpos - jmp_location))
        pmc.overwrite()

    def redirect_call_assembler(self, oldlooptoken, newlooptoken):
        # some minimal sanity checking
        old_nbargs = oldlooptoken.compiled_loop_token._debug_nbargs
        new_nbargs = newlooptoken.compiled_loop_token._debug_nbargs
        assert old_nbargs == new_nbargs
        oldadr = oldlooptoken._ll_function_addr
        target = newlooptoken._ll_function_addr
        # copy frame-info data
        baseofs = self.cpu.get_baseofs_of_frame_field()
        newlooptoken.compiled_loop_token.update_frame_info(
            oldlooptoken.compiled_loop_token, baseofs)
        # we overwrite the instructions at the old _ll_function_addr
        # to start with a JMP to the new _ll_function_addr.
        mc = InstrBuilder()
        mc.load_imm(r.SCRATCH, target)
        mc.BCR(c.ANY, r.SCRATCH)
        mc.copy_to_raw_memory(oldadr)
        #
        jl.redirect_assembler(oldlooptoken, newlooptoken, newlooptoken.number)


class MiscOpAssembler(object):
    _mixin_ = True

    def _genop_same_as(self, op, arglocs, regalloc):
        argloc, resloc = arglocs
        if argloc is not resloc:
            self.regalloc_mov(argloc, resloc)

    emit_same_as_i = _genop_same_as
    emit_same_as_r = _genop_same_as
    emit_same_as_f = _genop_same_as
    emit_cast_ptr_to_int = _genop_same_as
    emit_cast_int_to_ptr = _genop_same_as

    def emit_increment_debug_counter(self, op, arglocs, regalloc):
        addr, scratch = arglocs
        self.mc.LG(scratch, l.addr(0,addr))
        self.mc.AGHI(scratch, l.imm(1))
        self.mc.STG(scratch, l.addr(0,addr))

    def emit_debug_merge_point(self, op, arglocs, regalloc):
        pass

    emit_jit_debug = emit_debug_merge_point
    emit_keepalive = emit_debug_merge_point

    def emit_enter_portal_frame(self, op, arglocs, regalloc):
        self.enter_portal_frame(op)

    def emit_leave_portal_frame(self, op, arglocs, regalloc):
        self.leave_portal_frame(op)

class OpAssembler(IntOpAssembler, FloatOpAssembler,
                  GuardOpAssembler, CallOpAssembler,
                  AllocOpAssembler, MemoryOpAssembler,
                  MiscOpAssembler, ForceOpAssembler):
    _mixin_ = True

