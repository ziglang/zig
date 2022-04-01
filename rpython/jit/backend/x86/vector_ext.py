import py
from rpython.jit.metainterp.compile import ResumeGuardDescr
from rpython.jit.metainterp.history import (ConstInt, INT, REF,
    FLOAT, VECTOR, TargetToken)
from rpython.jit.backend.llsupport.descr import (ArrayDescr, CallDescr,
    unpack_arraydescr, unpack_fielddescr, unpack_interiorfielddescr)
from rpython.jit.backend.x86.regloc import (FrameLoc, RegLoc, ConstFloatLoc,
    FloatImmedLoc, ImmedLoc, imm, imm0, imm1, ecx, eax, edx, ebx, esi, edi,
    ebp, r8, r9, r10, r11, r12, r13, r14, r15, xmm0, xmm1, xmm2, xmm3, xmm4,
    xmm5, xmm6, xmm7, xmm8, xmm9, xmm10, xmm11, xmm12, xmm13, xmm14,
    X86_64_SCRATCH_REG, X86_64_XMM_SCRATCH_REG, AddressLoc)
from rpython.jit.backend.llsupport.vector_ext import VectorExt
from rpython.jit.backend.llsupport.regalloc import (get_scale, TempVar,
    NoVariableToSpill)
from rpython.jit.metainterp.resoperation import (rop, ResOperation,
        VectorOp, VectorGuardOp)
from rpython.rlib.objectmodel import we_are_translated, always_inline
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.backend.x86 import rx86, detect_feature

# duplicated for easy migration, def in assembler.py as well
# DUP START
def addr_add(reg_or_imm1, reg_or_imm2, offset=0, scale=0):
    return AddressLoc(reg_or_imm1, reg_or_imm2, scale, offset)

def heap(addr):
    return AddressLoc(ImmedLoc(addr), imm0, 0, 0)

def not_implemented(msg):
    msg = '[x86/vector_ext] %s\n' % msg
    if we_are_translated():
        llop.debug_print(lltype.Void, msg)
    raise NotImplementedError(msg)
# DUP END

class TempVector(TempVar):
    def __init__(self, type):
        self.type = type
    def is_vector(self):
        return True
    def __repr__(self):
        return "<TempVector at %s>" % (id(self),)

class TempInt(TempVar):
    type = INT

    def __repr__(self):
        return "<TempInt at %s>" % (id(self),)

class X86VectorExt(VectorExt):

    should_align_unroll = True

    def setup_once(self, asm):
        if detect_feature.detect_sse4_1():
            self.enable(16, accum=True)
            asm.setup_once_vector()
        self._setup = True

class VectorAssemblerMixin(object):
    _mixin_ = True
    element_ones = []    # overridden in assembler.py

    def setup_once_vector(self):
        pass

    def genop_guard_vec_guard_true(self, guard_op, guard_token, locs, resloc):
        self.implement_guard(guard_token)

    def genop_guard_vec_guard_false(self, guard_op, guard_token, locs, resloc):
        self.guard_success_cc = rx86.invert_condition(self.guard_success_cc)
        self.implement_guard(guard_token)

    def guard_vector(self, guard_op, loc, true):
        assert isinstance(guard_op, VectorGuardOp)
        arg = guard_op.getarg(0)
        assert isinstance(arg, VectorOp)
        size = arg.bytesize
        temp = X86_64_XMM_SCRATCH_REG
        ve = self.cpu.vector_ext
        assert ve is not None # MUST hold, optimize_vector is never entered if vector_ext is entered
        load = arg.bytesize * arg.count - ve.register_size
        assert load <= 0
        if true:
            self.mc.PXOR(temp, temp)
            # if the vector is not fully packed blend 1s
            if load < 0:
                self.mc.PCMPEQQ(temp, temp) # fill with ones
                self._blend_unused_slots(loc, arg, temp)
                # reset to zeros
                self.mc.PXOR(temp, temp)

            # cmp with zeros (in temp) creates ones at each slot where it is zero
            self.mc.PCMPEQ(loc, temp, size)
            # temp converted to ones
            self.mc.PCMPEQQ(temp, temp)
            # test if all slots are zero
            self.mc.PTEST(loc, temp)
            self.guard_success_cc = rx86.Conditions['Z']
        else:
            # if the vector is not fully packed blend 1s
            if load < 0:
                temp = X86_64_XMM_SCRATCH_REG
                self.mc.PXOR(temp, temp)
                self._blend_unused_slots(loc, arg, temp)
            self.mc.PTEST(loc, loc)
            self.guard_success_cc = rx86.Conditions['NZ']

    def _blend_unused_slots(self, loc, arg, temp):
        select = 0
        bits_used = (arg.count * arg.bytesize * 8)
        index = bits_used // 16
        while index < 8:
            select |= (1 << index)
            index += 1
        self.mc.PBLENDW_xxi(loc.value, temp.value, select)

    def _update_at_exit(self, fail_locs, fail_args, faildescr, regalloc):
        """ If accumulation is done in this loop, at the guard exit
            some vector registers must be adjusted to yield the correct value
        """
        if not isinstance(faildescr, ResumeGuardDescr):
            return
        assert regalloc is not None
        accum_info = faildescr.rd_vector_info
        while accum_info:
            pos = accum_info.getpos_in_failargs()
            scalar_loc = fail_locs[pos]
            vector_loc = accum_info.location
            # the upper elements will be lost if saved to the stack!
            scalar_arg = accum_info.getoriginal()
            assert isinstance(vector_loc, RegLoc)
            assert scalar_arg is not None
            orig_scalar_loc = scalar_loc
            tmpvar = None
            if not isinstance(scalar_loc, RegLoc):
                # scalar loc might live in memory, use scratch register and save it back later
                if scalar_arg.type == FLOAT:
                    scalar_loc = X86_64_XMM_SCRATCH_REG
                else:
                    tmpvar = TempInt()
                    scalar_loc = regalloc.rm.try_allocate_reg(tmpvar)
                self.mov(orig_scalar_loc, scalar_loc)
            if accum_info.accum_operation == '+':
                self._accum_reduce_sum(scalar_arg, vector_loc, scalar_loc)
            elif accum_info.accum_operation == '*':
                self._accum_reduce_mul(scalar_arg, vector_loc, scalar_loc)
            else:
                not_implemented("accum operator %s not implemented" %
                                            (accum_info.accum_operation)) 
            if tmpvar:
                regalloc.rm.possibly_free_var(tmpvar)
            if scalar_loc is not orig_scalar_loc:
                self.mov(scalar_loc, orig_scalar_loc)
            accum_info = accum_info.next()

    def _accum_reduce_mul(self, arg, accumloc, targetloc):
        self.mov(accumloc, targetloc)
        # swap the two elements
        self.mc.SHUFPD_xxi(targetloc.value, targetloc.value, 0x01)
        self.mc.MULSD(targetloc, accumloc)

    def _accum_reduce_sum(self, arg, accumloc, targetloc):
        # Currently the accumulator can ONLY be the biggest
        # size for X86 -> 64 bit float/int
        if arg.type == FLOAT:
            # r = (r[0]+r[1],r[0]+r[1])
            self.mc.HADDPD(accumloc, accumloc)
            # upper bits (> 64) are dirty (but does not matter)
            if accumloc is not targetloc:
                self.mov(accumloc, targetloc)
            return
        elif arg.type == INT:
            scratchloc = X86_64_SCRATCH_REG
            self.mc.forget_scratch_register()
            self.mc.PEXTRQ_rxi(targetloc.value, accumloc.value, 0)
            self.mc.PEXTRQ_rxi(scratchloc.value, accumloc.value, 1)
            self.mc.ADD_rr(targetloc.value, scratchloc.value)
            return

        not_implemented("reduce sum for %s not impl." % arg)

    def _genop_vec_load(self, op, arglocs, resloc):
        base_loc, ofs_loc, size_loc, scale, ofs, integer_loc = arglocs
        src_addr = addr_add(base_loc, ofs_loc, ofs.value, scale.value)
        self._vec_load(resloc, src_addr, integer_loc.value,
                       size_loc.value, False)

    genop_vec_load_i = _genop_vec_load
    genop_vec_load_f = _genop_vec_load

    @always_inline
    def _vec_load(self, resloc, src_addr, integer, itemsize, aligned):
        if integer:
            if aligned:
                self.mc.MOVDQA(resloc, src_addr)
            else:
                self.mc.MOVDQU(resloc, src_addr)
        else:
            if itemsize == 4:
                self.mc.MOVUPS(resloc, src_addr)
            elif itemsize == 8:
                self.mc.MOVUPD(resloc, src_addr)

    def genop_discard_vec_store(self, op, arglocs):
        base_loc, ofs_loc, value_loc, size_loc, scale,\
                baseofs, integer_loc = arglocs
        dest_loc = addr_add(base_loc, ofs_loc, baseofs.value, scale.value)
        self._vec_store(dest_loc, value_loc, integer_loc.value,
                        size_loc.value, False)

    @always_inline
    def _vec_store(self, dest_loc, value_loc, integer, itemsize, aligned):
        if integer:
            if aligned:
                self.mc.MOVDQA(dest_loc, value_loc)
            else:
                self.mc.MOVDQU(dest_loc, value_loc)
        else:
            if itemsize == 4:
                self.mc.MOVUPS(dest_loc, value_loc)
            elif itemsize == 8:
                self.mc.MOVUPD(dest_loc, value_loc)

    def genop_vec_int_is_true(self, op, arglocs, resloc):
        loc, sizeloc = arglocs
        temp = X86_64_XMM_SCRATCH_REG
        self.mc.PXOR(temp, temp)
        # every entry that is non zero -> becomes zero
        # zero entries become ones
        self.mc.PCMPEQ(loc, temp, sizeloc.value)
        # a second time -> every zero entry (corresponding to non zero
        # entries before) become ones
        self.mc.PCMPEQ(loc, temp, sizeloc.value)

    def genop_vec_int_mul(self, op, arglocs, resloc):
        loc0, loc1, itemsize_loc = arglocs
        itemsize = itemsize_loc.value
        if itemsize == 2:
            self.mc.PMULLW(loc0, loc1)
        elif itemsize == 4:
            self.mc.PMULLD(loc0, loc1)
        else:
            # NOTE see http://stackoverflow.com/questions/8866973/can-long-integer-routines-benefit-from-sse/8867025#8867025
            # There is no 64x64 bit packed mul. For 8 bit either. It is questionable if it gives any benefit?
            not_implemented("int8/64 mul")

    def genop_vec_int_add(self, op, arglocs, resloc):
        loc0, loc1, size_loc = arglocs
        size = size_loc.value
        if size == 1:
            self.mc.PADDB(loc0, loc1)
        elif size == 2:
            self.mc.PADDW(loc0, loc1)
        elif size == 4:
            self.mc.PADDD(loc0, loc1)
        elif size == 8:
            self.mc.PADDQ(loc0, loc1)

    def genop_vec_int_sub(self, op, arglocs, resloc):
        loc0, loc1, size_loc = arglocs
        size = size_loc.value
        if size == 1:
            self.mc.PSUBB(loc0, loc1)
        elif size == 2:
            self.mc.PSUBW(loc0, loc1)
        elif size == 4:
            self.mc.PSUBD(loc0, loc1)
        elif size == 8:
            self.mc.PSUBQ(loc0, loc1)

    def genop_vec_int_and(self, op, arglocs, resloc):
        self.mc.PAND(resloc, arglocs[0])

    def genop_vec_int_or(self, op, arglocs, resloc):
        self.mc.POR(resloc, arglocs[0])

    def genop_vec_int_xor(self, op, arglocs, resloc):
        self.mc.PXOR(resloc, arglocs[0])

    genop_vec_float_xor = genop_vec_int_xor

    genop_vec_float_arith = """
    def genop_vec_float_{type}(self, op, arglocs, resloc):
        loc0, loc1, itemsize_loc = arglocs
        itemsize = itemsize_loc.value
        if itemsize == 4:
            self.mc.{p_op_s}(loc0, loc1)
        elif itemsize == 8:
            self.mc.{p_op_d}(loc0, loc1)
    """
    for op in ['add','mul','sub']:
        OP = op.upper()
        _source = genop_vec_float_arith.format(type=op,
                                               p_op_s=OP+'PS',
                                               p_op_d=OP+'PD')
        exec(py.code.Source(_source).compile())
    del genop_vec_float_arith

    def genop_vec_float_truediv(self, op, arglocs, resloc):
        loc0, loc1, sizeloc = arglocs
        size = sizeloc.value
        if size == 4:
            self.mc.DIVPS(loc0, loc1)
        elif size == 8:
            self.mc.DIVPD(loc0, loc1)

    def genop_vec_float_abs(self, op, arglocs, resloc):
        src, sizeloc = arglocs
        size = sizeloc.value
        if size == 4:
            self.mc.ANDPS(src, heap(self.single_float_const_abs_addr))
        elif size == 8:
            self.mc.ANDPD(src, heap(self.float_const_abs_addr))

    def genop_vec_float_neg(self, op, arglocs, resloc):
        src, sizeloc = arglocs
        size = sizeloc.value
        if size == 4:
            self.mc.XORPS(src, heap(self.single_float_const_neg_addr))
        elif size == 8:
            self.mc.XORPD(src, heap(self.float_const_neg_addr))

    def genop_vec_float_eq(self, op, arglocs, resloc):
        lhsloc, rhsloc, sizeloc = arglocs
        size = sizeloc.value
        if size == 4:
            self.mc.CMPPS_xxi(lhsloc.value, rhsloc.value, 0) # 0 means equal
        else:
            self.mc.CMPPD_xxi(lhsloc.value, rhsloc.value, 0)
        self.flush_vec_cc(rx86.Conditions["E"], lhsloc, resloc, sizeloc.value)

    def flush_vec_cc(self, rev_cond, lhsloc, resloc, size):
        # After emitting an instruction that leaves a boolean result in
        # a condition code (cc), call this.  In the common case, result_loc
        # will be set to SPP by the regalloc, which in this case means
        # "propagate it between this operation and the next guard by keeping
        # it in the cc".  In the uncommon case, result_loc is another
        # register, and we emit a load from the cc into this register.

        if resloc is ebp:
            self.guard_success_cc = rev_cond
        else:
            assert lhsloc is xmm0
            maskloc = X86_64_XMM_SCRATCH_REG
            assert len(self.element_ones) > 0
            self.mc.MOVAPD(maskloc, heap(self.element_ones[get_scale(size)]))
            self.mc.PXOR(resloc, resloc)
            # note that resloc contains true false for each element by the last compare operation
            self.mc.PBLENDVB_xx(resloc.value, maskloc.value)

    def genop_vec_float_ne(self, op, arglocs, resloc):
        lhsloc, rhsloc, sizeloc = arglocs
        size = sizeloc.value
        # b(100) == 1 << 2 means not equal
        if size == 4:
            self.mc.CMPPS_xxi(lhsloc.value, rhsloc.value, 1 << 2)
        else:
            self.mc.CMPPD_xxi(lhsloc.value, rhsloc.value, 1 << 2)
        self.flush_vec_cc(rx86.Conditions["NE"], lhsloc, resloc, sizeloc.value)

    def genop_vec_int_eq(self, op, arglocs, resloc):
        lhsloc, rhsloc, sizeloc = arglocs
        size = sizeloc.value
        self.mc.PCMPEQ(lhsloc, rhsloc, size)
        self.flush_vec_cc(rx86.Conditions["E"], lhsloc, resloc, sizeloc.value)

    def genop_vec_int_ne(self, op, arglocs, resloc):
        lhsloc, rhsloc, sizeloc = arglocs
        size = sizeloc.value
        self.mc.PCMPEQ(resloc, rhsloc, size)
        temp = X86_64_XMM_SCRATCH_REG
        self.mc.PCMPEQQ(temp, temp) # set all bits to one
        # need to invert the value in resloc
        self.mc.PXOR(resloc, temp)
        # 11 00 11 11
        # 11 11 11 11
        # ----------- pxor
        # 00 11 00 00
        self.flush_vec_cc(rx86.Conditions["NE"], lhsloc, resloc, sizeloc.value)

    def genop_vec_int_signext(self, op, arglocs, resloc):
        srcloc, sizeloc, tosizeloc = arglocs
        size = sizeloc.value
        tosize = tosizeloc.value
        if size == tosize:
            return # already the right size
        if size == 4 and tosize == 8:
            scratch = X86_64_SCRATCH_REG.value
            self.mc.forget_scratch_register()
            self.mc.PEXTRD_rxi(scratch, srcloc.value, 1)
            self.mc.PINSRQ_xri(resloc.value, scratch, 1)
            self.mc.PEXTRD_rxi(scratch, srcloc.value, 0)
            self.mc.PINSRQ_xri(resloc.value, scratch, 0)
        elif size == 8 and tosize == 4:
            # is there a better sequence to move them?
            scratch = X86_64_SCRATCH_REG.value
            self.mc.forget_scratch_register()
            self.mc.PEXTRQ_rxi(scratch, srcloc.value, 0)
            self.mc.PINSRD_xri(resloc.value, scratch, 0)
            self.mc.PEXTRQ_rxi(scratch, srcloc.value, 1)
            self.mc.PINSRD_xri(resloc.value, scratch, 1)
        else:
            # note that all other conversions are not implemented
            # on purpose. it needs many x86 op codes to implement
            # the missing combinations. even if they are implemented
            # the speedup might only be modest...
            # the optimization does not emit such code!
            msg = "vec int signext (%d->%d)" % (size, tosize)
            not_implemented(msg)

    def genop_vec_expand_f(self, op, arglocs, resloc):
        srcloc, sizeloc = arglocs
        size = sizeloc.value
        if isinstance(srcloc, ConstFloatLoc):
            # they are aligned!
            self.mc.MOVAPD(resloc, srcloc)
        elif size == 4:
            # the register allocator forces src to be the same as resloc
            # r = (s[0], s[0], r[0], r[0])
            # since resloc == srcloc: r = (r[0], r[0], r[0], r[0])
            self.mc.SHUFPS_xxi(resloc.value, srcloc.value, 0)
        elif size == 8:
            self.mc.MOVDDUP(resloc, srcloc)
        else:
            raise AssertionError("float of size %d not supported" % (size,))

    def genop_vec_expand_i(self, op, arglocs, resloc):
        srcloc, sizeloc = arglocs
        if not isinstance(srcloc, RegLoc):
            # self.mc.forget_scratch_register(): done by self.mov()
            self.mov(srcloc, X86_64_SCRATCH_REG)
            srcloc = X86_64_SCRATCH_REG
        assert not srcloc.is_xmm
        size = sizeloc.value
        if size == 1:
            self.mc.PINSRB_xri(resloc.value, srcloc.value, 0)
            self.mc.PSHUFB(resloc, heap(self.expand_byte_mask_addr))
        elif size == 2:
            self.mc.PINSRW_xri(resloc.value, srcloc.value, 0)
            self.mc.PINSRW_xri(resloc.value, srcloc.value, 4)
            self.mc.PSHUFLW_xxi(resloc.value, resloc.value, 0)
            self.mc.PSHUFHW_xxi(resloc.value, resloc.value, 0)
        elif size == 4:
            self.mc.PINSRD_xri(resloc.value, srcloc.value, 0)
            self.mc.PSHUFD_xxi(resloc.value, resloc.value, 0)
        elif size == 8:
            self.mc.PINSRQ_xri(resloc.value, srcloc.value, 0)
            self.mc.PINSRQ_xri(resloc.value, srcloc.value, 1)
        else:
            raise AssertionError("cannot handle size %d (int expand)" % (size,))

    def genop_vec_pack_i(self, op, arglocs, resloc):
        resultloc, sourceloc, residxloc, srcidxloc, countloc, sizeloc = arglocs
        assert isinstance(resultloc, RegLoc)
        assert isinstance(sourceloc, RegLoc)
        size = sizeloc.value
        srcidx = srcidxloc.value
        residx = residxloc.value
        count = countloc.value
        # for small data type conversion this can be quite costy
        # NOTE there might be some combinations that can be handled
        # more efficiently! e.g.
        # v2 = pack(v0,v1,4,4)
        si = srcidx
        ri = residx
        k = count
        while k > 0:
            if size == 8:
                if resultloc.is_xmm and sourceloc.is_xmm: # both xmm
                    self.mc.forget_scratch_register()
                    self.mc.PEXTRQ_rxi(X86_64_SCRATCH_REG.value, sourceloc.value, si)
                    self.mc.PINSRQ_xri(resultloc.value, X86_64_SCRATCH_REG.value, ri)
                elif resultloc.is_xmm: # xmm <- reg
                    self.mc.PINSRQ_xri(resultloc.value, sourceloc.value, ri)
                else: # reg <- xmm
                    self.mc.PEXTRQ_rxi(resultloc.value, sourceloc.value, si)
            elif size == 4:
                if resultloc.is_xmm and sourceloc.is_xmm:
                    self.mc.forget_scratch_register()
                    self.mc.PEXTRD_rxi(X86_64_SCRATCH_REG.value, sourceloc.value, si)
                    self.mc.PINSRD_xri(resultloc.value, X86_64_SCRATCH_REG.value, ri)
                elif resultloc.is_xmm:
                    self.mc.PINSRD_xri(resultloc.value, sourceloc.value, ri)
                else:
                    self.mc.PEXTRD_rxi(resultloc.value, sourceloc.value, si)
            elif size == 2:
                if resultloc.is_xmm and sourceloc.is_xmm:
                    self.mc.forget_scratch_register()
                    self.mc.PEXTRW_rxi(X86_64_SCRATCH_REG.value, sourceloc.value, si)
                    self.mc.PINSRW_xri(resultloc.value, X86_64_SCRATCH_REG.value, ri)
                elif resultloc.is_xmm:
                    self.mc.PINSRW_xri(resultloc.value, sourceloc.value, ri)
                else:
                    self.mc.PEXTRW_rxi(resultloc.value, sourceloc.value, si)
            elif size == 1:
                if resultloc.is_xmm and sourceloc.is_xmm:
                    self.mc.forget_scratch_register()
                    self.mc.PEXTRB_rxi(X86_64_SCRATCH_REG.value, sourceloc.value, si)
                    self.mc.PINSRB_xri(resultloc.value, X86_64_SCRATCH_REG.value, ri)
                elif resultloc.is_xmm:
                    self.mc.PINSRB_xri(resultloc.value, sourceloc.value, ri)
                else:
                    self.mc.PEXTRB_rxi(resultloc.value, sourceloc.value, si)
            si += 1
            ri += 1
            k -= 1

    genop_vec_unpack_i = genop_vec_pack_i

    def genop_vec_pack_f(self, op, arglocs, resultloc):
        resloc, srcloc, residxloc, srcidxloc, countloc, sizeloc = arglocs
        assert isinstance(resloc, RegLoc)
        assert isinstance(srcloc, RegLoc)
        count = countloc.value
        residx = residxloc.value
        srcidx = srcidxloc.value
        size = sizeloc.value
        if size == 4:
            si = srcidx
            ri = residx
            k = count
            while k > 0:
                if resloc.is_xmm:
                    src = srcloc.value
                    if not srcloc.is_xmm:
                        # if source is a normal register (unpack)
                        assert count == 1
                        assert si == 0
                        self.mov(srcloc, X86_64_XMM_SCRATCH_REG)
                        src = X86_64_XMM_SCRATCH_REG.value
                    select = ((si & 0x3) << 6)|((ri & 0x3) << 4)
                    self.mc.INSERTPS_xxi(resloc.value, src, select)
                else:
                    self.mc.PEXTRD_rxi(resloc.value, srcloc.value, si)
                si += 1
                ri += 1
                k -= 1
        elif size == 8:
            assert resloc.is_xmm
            if srcloc.is_xmm:
                if srcidx == 0:
                    if residx == 0:
                        # r = (s[0], r[1])
                        self.mc.MOVSD(resloc, srcloc)
                    else:
                        assert residx == 1
                        # r = (r[0], s[0])
                        self.mc.UNPCKLPD(resloc, srcloc)
                else:
                    assert srcidx == 1
                    if residx == 0:
                        # r = (s[1], r[1])
                        if resloc != srcloc:
                            self.mc.UNPCKHPD(resloc, srcloc)
                        self.mc.SHUFPD_xxi(resloc.value, resloc.value, 1)
                    else:
                        assert residx == 1
                        # r = (r[0], s[1])
                        if resloc != srcloc:
                            self.mc.SHUFPD_xxi(resloc.value, resloc.value, 1)
                            self.mc.UNPCKHPD(resloc, srcloc)
                        # if they are equal nothing is to be done
        else:
            not_implemented("pack/unpack for size %d" % size)

    genop_vec_unpack_f = genop_vec_pack_f

    def genop_vec_cast_float_to_singlefloat(self, op, arglocs, resloc):
        self.mc.CVTPD2PS(resloc, arglocs[0])

    def genop_vec_cast_float_to_int(self, op, arglocs, resloc):
        self.mc.CVTPD2DQ(resloc, arglocs[0])

    def genop_vec_cast_int_to_float(self, op, arglocs, resloc):
        self.mc.CVTDQ2PD(resloc, arglocs[0])

    def genop_vec_cast_singlefloat_to_float(self, op, arglocs, resloc):
        self.mc.CVTPS2PD(resloc, arglocs[0])

class VectorRegallocMixin(object):
    _mixin_ = True

    def _consider_vec_load(self, op):
        descr = op.getdescr()
        assert isinstance(descr, ArrayDescr)
        assert not descr.is_array_of_pointers() and \
               not descr.is_array_of_structs()
        itemsize, _, _ = unpack_arraydescr(descr)
        integer = not (descr.is_array_of_floats() or descr.getconcrete_type() == FLOAT)
        args = op.getarglist()
        scale = get_scale(op.getarg(2).getint())
        ofs = op.getarg(3).getint()
        base_loc = self.rm.make_sure_var_in_reg(op.getarg(0), args)
        ofs_loc = self.rm.make_sure_var_in_reg(op.getarg(1), args)
        result_loc = self.force_allocate_reg(op)
        self.perform(op, [base_loc, ofs_loc, imm(itemsize), imm(scale),
                          imm(ofs), imm(integer)], result_loc)

    consider_vec_load_i = _consider_vec_load
    consider_vec_load_f = _consider_vec_load

    def consider_vec_store(self, op):
        # TODO
        descr = op.getdescr()
        assert isinstance(descr, ArrayDescr)
        assert not descr.is_array_of_pointers() and \
               not descr.is_array_of_structs()
        itemsize, _, _ = unpack_arraydescr(descr)
        args = op.getarglist()
        base_loc = self.rm.make_sure_var_in_reg(op.getarg(0), args)
        value_loc = self.make_sure_var_in_reg(op.getarg(2), args)
        ofs_loc = self.rm.make_sure_var_in_reg(op.getarg(1), args)
        scale = get_scale(op.getarg(3).getint())
        ofs = op.getarg(4).getint()

        integer = not (descr.is_array_of_floats() or \
                       descr.getconcrete_type() == FLOAT)
        self.perform_discard(op, [base_loc, ofs_loc, value_loc, imm(itemsize),
                                  imm(scale), imm(ofs), imm(integer)])

    def consider_vec_arith(self, op):
        lhs = op.getarg(0)
        assert isinstance(op, VectorOp)
        size = op.bytesize
        args = op.getarglist()
        loc1 = self.make_sure_var_in_reg(op.getarg(1), args)
        loc0 = self.xrm.force_result_in_reg(op, op.getarg(0), args)
        self.perform(op, [loc0, loc1, imm(size)], loc0)

    consider_vec_int_add = consider_vec_arith
    consider_vec_int_sub = consider_vec_arith
    consider_vec_int_mul = consider_vec_arith
    consider_vec_float_add = consider_vec_arith
    consider_vec_float_sub = consider_vec_arith
    consider_vec_float_mul = consider_vec_arith
    consider_vec_float_truediv = consider_vec_arith
    del consider_vec_arith

    def consider_vec_arith_unary(self, op):
        lhs = op.getarg(0)
        assert isinstance(lhs, VectorOp)
        args = op.getarglist()
        res = self.xrm.force_result_in_reg(op, op.getarg(0), args)
        self.perform(op, [res, imm(lhs.bytesize)], res)

    consider_vec_float_neg = consider_vec_arith_unary
    consider_vec_float_abs = consider_vec_arith_unary
    del consider_vec_arith_unary

    def consider_vec_logic(self, op):
        lhs = op.getarg(0)
        assert isinstance(lhs, VectorOp)
        args = op.getarglist()
        source = self.make_sure_var_in_reg(op.getarg(1), args)
        result = self.xrm.force_result_in_reg(op, op.getarg(0), args)
        self.perform(op, [source, imm(lhs.bytesize)], result)

    def consider_vec_float_eq(self, op):
        assert isinstance(op, VectorOp)
        lhs = op.getarg(0)
        assert isinstance(lhs, VectorOp)
        args = op.getarglist()
        # we need to use xmm0
        lhsloc = self.enforce_var_in_vector_reg(op.getarg(0), args, selected_reg=xmm0)
        rhsloc = self.make_sure_var_in_reg(op.getarg(1), args)
        resloc = self.force_allocate_vector_reg_or_cc(op)
        self.perform(op, [lhsloc, rhsloc, imm(lhs.bytesize)], resloc)

    def enforce_var_in_vector_reg(self, arg, forbidden_vars, selected_reg):
        """ Enforce the allocation in a specific register. This can even be a forbidden
            register. If it is forbidden, it will be moved to another register.
            Use with caution, currently this is only used for the vectorization backend
            instructions.
        """
        xrm = self.xrm
        curloc = self.loc(arg)
        if curloc is selected_reg:
            # nothing to do, it is already in the correct register
            return selected_reg
        if selected_reg not in xrm.free_regs:
            # we need to move some registers
            variable = None
            candidate_to_spill = None
            for var, reg in self.xrm.reg_bindings.items():
                if reg is selected_reg:
                    variable = var
                else:
                    if var not in forbidden_vars:
                        candidate_to_spill = var
            # do we have a free register?
            if len(xrm.free_regs) == 0:
                # spill a non forbidden variable
                if not candidate_to_spill:
                    raise NoVariableToSpill
                reg = xrm.reg_bindings[candidate_to_spill]
                xrm._spill_var(forbidden_vars, reg)
                xrm.free_regs.append(reg)
            loc = xrm.free_regs.pop()
            self.assembler.mov(selected_reg, loc)
            reg = xrm.reg_bindings.get(arg, None)
            if reg:
                xrm.free_regs.append(reg)
                self.assembler.mov(reg, selected_reg)
            xrm.reg_bindings[arg] = selected_reg
            xrm.reg_bindings[variable] = loc

            return selected_reg
        return self.make_sure_var_in_reg(arg, forbidden_vars, selected_reg=selected_reg)

    def force_allocate_vector_reg_or_cc(self, var):
        assert var.type == INT
        if self.next_op_can_accept_cc(self.operations, self.rm.position):
            # hack: return the ebp location to mean "lives in CC".  This
            # ebp will not actually be used, and the location will be freed
            # after the next op as usual.
            self.xrm.force_allocate_frame_reg(var)
            return ebp
        else:
            # else, return a regular register (not ebp).
            return self.xrm.force_allocate_reg(var)

    consider_vec_float_ne = consider_vec_float_eq
    consider_vec_int_eq = consider_vec_float_eq
    consider_vec_int_ne = consider_vec_float_eq

    consider_vec_int_and = consider_vec_logic
    consider_vec_int_or = consider_vec_logic
    consider_vec_int_xor = consider_vec_logic
    consider_vec_float_xor = consider_vec_logic
    del consider_vec_logic

    def consider_vec_pack_i(self, op):
        # new_res = vec_pack_i(res, src, index, count)
        assert isinstance(op, VectorOp)
        arg = op.getarg(1)
        index = op.getarg(2)
        count = op.getarg(3)
        assert isinstance(index, ConstInt)
        assert isinstance(count, ConstInt)
        args = op.getarglist()
        srcloc = self.make_sure_var_in_reg(arg, args)
        resloc =  self.xrm.force_result_in_reg(op, op.getarg(0), args)
        residx = index.value # where to put it in result?
        srcidx = 0
        arglocs = [resloc, srcloc, imm(residx), imm(srcidx),
                   imm(count.value), imm(op.bytesize)]
        self.perform(op, arglocs, resloc)

    consider_vec_pack_f = consider_vec_pack_i

    def consider_vec_unpack_i(self, op):
        assert isinstance(op, VectorOp)
        index = op.getarg(1)
        count = op.getarg(2)
        assert isinstance(index, ConstInt)
        assert isinstance(count, ConstInt)
        args = op.getarglist()
        srcloc = self.make_sure_var_in_reg(op.getarg(0), args)
        if op.is_vector():
            resloc =  self.xrm.force_result_in_reg(op, op.getarg(0), args)
            size = op.bytesize
        else:
            # unpack into iX box
            resloc =  self.force_allocate_reg(op, args)
            arg = op.getarg(0)
            assert isinstance(arg, VectorOp)
            size = arg.bytesize
        residx = 0
        args = op.getarglist()
        arglocs = [resloc, srcloc, imm(residx), imm(index.value), imm(count.value), imm(size)]
        self.perform(op, arglocs, resloc)

    consider_vec_unpack_f = consider_vec_unpack_i

    def consider_vec_expand_f(self, op):
        assert isinstance(op, VectorOp)
        arg = op.getarg(0)
        args = op.getarglist()
        if arg.is_constant():
            resloc = self.xrm.force_allocate_reg(op)
            srcloc = self.xrm.expand_float(op.bytesize, arg)
        else:
            resloc = self.xrm.force_result_in_reg(op, arg, args)
            srcloc = resloc
        self.perform(op, [srcloc, imm(op.bytesize)], resloc)

    def consider_vec_expand_i(self, op):
        assert isinstance(op, VectorOp)
        arg = op.getarg(0)
        args = op.getarglist()
        if arg.is_constant():
            srcloc = self.rm.convert_to_imm(arg)
        else:
            srcloc = self.make_sure_var_in_reg(arg, args)
        resloc = self.xrm.force_allocate_reg(op, args)
        self.perform(op, [srcloc, imm(op.bytesize)], resloc)

    def consider_vec_int_signext(self, op):
        assert isinstance(op, VectorOp)
        args = op.getarglist()
        resloc = self.xrm.force_result_in_reg(op, op.getarg(0), args)
        arg = op.getarg(0)
        assert isinstance(arg, VectorOp)
        size = arg.bytesize
        assert size > 0
        self.perform(op, [resloc, imm(size), imm(op.bytesize)], resloc)

    def consider_vec_int_is_true(self, op):
        args = op.getarglist()
        arg = op.getarg(0)
        assert isinstance(arg, VectorOp)
        argloc = self.loc(arg)
        resloc = self.xrm.force_result_in_reg(op, arg, args)
        self.perform(op, [resloc,imm(arg.bytesize)], None)

    def _consider_vec(self, op):
        # pseudo instruction, needed to create a new variable
        self.xrm.force_allocate_reg(op)

    consider_vec_i = _consider_vec
    consider_vec_f = _consider_vec

    def consider_vec_cast_float_to_int(self, op):
        args = op.getarglist()
        srcloc = self.make_sure_var_in_reg(op.getarg(0), args)
        resloc = self.xrm.force_result_in_reg(op, op.getarg(0), args)
        self.perform(op, [srcloc], resloc)

    consider_vec_cast_int_to_float = consider_vec_cast_float_to_int
    consider_vec_cast_float_to_singlefloat = consider_vec_cast_float_to_int
    consider_vec_cast_singlefloat_to_float = consider_vec_cast_float_to_int

    def consider_vec_guard_true(self, op):
        arg = op.getarg(0)
        loc = self.loc(arg)
        self.assembler.guard_vector(op, self.loc(arg), True)
        self.perform_guard(op, [], None)

    def consider_vec_guard_false(self, op):
        arg = op.getarg(0)
        loc = self.loc(arg)
        self.assembler.guard_vector(op, self.loc(arg), False)
        self.perform_guard(op, [], None)

