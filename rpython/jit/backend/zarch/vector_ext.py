from rpython.jit.metainterp.compile import ResumeGuardDescr
from rpython.jit.metainterp.history import (ConstInt, INT, FLOAT)
from rpython.jit.backend.llsupport.descr import (ArrayDescr, 
    unpack_arraydescr)
from rpython.jit.metainterp.resoperation import VectorOp, rop
from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.backend.zarch.detect_feature import detect_simd_z
import rpython.jit.backend.zarch.registers as r
import rpython.jit.backend.zarch.conditions as c
import rpython.jit.backend.zarch.locations as l
import rpython.jit.backend.zarch.masks as m
from rpython.jit.backend.zarch.locations import imm
from rpython.rtyper.lltypesystem import rffi
from rpython.jit.codewriter import longlong
from rpython.rlib.objectmodel import always_inline
from rpython.jit.backend.zarch.arch import WORD
from rpython.jit.backend.llsupport.vector_ext import (VectorExt,
        OpRestrict, TR_INT64_2)

def not_implemented(msg):
    msg = '[zarch/vector_ext] %s\n' % msg
    if we_are_translated():
        llop.debug_print(lltype.Void, msg)
    raise NotImplementedError(msg)

@always_inline
def permi(v1,v2):
    return l.imm((v1 << 2 | v2) & 0xf)

def flush_vec_cc(asm, regalloc, condition, size, resultloc):
    # After emitting an instruction that leaves a boolean result in
    # a condition code (cc), call this.  In the common case, resultloc
    # will be set to SPP by the regalloc, which in this case means
    # "propagate it between this operation and the next guard by keeping
    # it in the cc".  In the uncommon case, resultloc is another
    # register, and we emit a load from the cc into this register.

    if resultloc is r.SPP:
        asm.guard_success_cc = condition
    else:
        ones = regalloc.vrm.get_scratch_reg()
        zeros = regalloc.vrm.get_scratch_reg()
        asm.mc.VX(zeros, zeros, zeros)
        asm.mc.VREPI(ones, l.imm(1), l.itemsize_to_mask(size))
        asm.mc.VSEL(resultloc, ones, zeros, resultloc)

class ZSIMDVectorExt(VectorExt):
    def setup_once(self, asm):
        if detect_simd_z():
            self.enable(16, accum=True)
            asm.setup_once_vector()
        self._setup = True
ZSIMDVectorExt.TR_MAPPING[rop.VEC_CAST_INT_TO_FLOAT] = OpRestrict([TR_INT64_2])

class VectorAssembler(object):
    _mixin_ = True

    def setup_once_vector(self):
        pass

    def emit_vec_load_f(self, op, arglocs, regalloc):
        resloc, baseloc, indexloc, size_loc, offsetloc, integer_loc = arglocs
        addrloc = self._load_address(baseloc, indexloc, offsetloc)
        self.mc.VL(resloc, addrloc)

    emit_vec_load_i = emit_vec_load_f

    def emit_vec_store(self, op, arglocs, regalloc):
        baseloc, indexloc, valueloc, sizeloc, offsetloc, integer_loc = arglocs
        addrloc = self._load_address(baseloc, indexloc, offsetloc)
        self.mc.VST(valueloc, addrloc)

    def emit_vec_int_add(self, op, arglocs, regalloc):
        resloc, loc0, loc1, size_loc = arglocs
        mask = l.itemsize_to_mask(size_loc.value)
        self.mc.VA(resloc, loc0, loc1, mask)

    def emit_vec_int_sub(self, op, arglocs, regalloc):
        resloc, loc0, loc1, size_loc = arglocs
        mask = l.itemsize_to_mask(size_loc.value)
        self.mc.VS(resloc, loc0, loc1, mask)

    def emit_vec_float_add(self, op, arglocs, regalloc):
        resloc, loc0, loc1, itemsize_loc = arglocs
        itemsize = itemsize_loc.value
        if itemsize == 8:
            self.mc.VFA(resloc, loc0, loc1, l.imm(3), l.imm(0), l.imm(0))
            return
        not_implemented("vec_float_add of size %d" % itemsize)

    def emit_vec_float_sub(self, op, arglocs, regalloc):
        resloc, loc0, loc1, itemsize_loc = arglocs
        itemsize = itemsize_loc.value
        if itemsize == 8:
            self.mc.VFS(resloc, loc0, loc1, l.imm(3), l.imm(0), l.imm(0))
            return
        not_implemented("vec_float_sub of size %d" % itemsize)

    def emit_vec_float_mul(self, op, arglocs, regalloc):
        resloc, loc0, loc1, itemsize_loc = arglocs
        itemsize = itemsize_loc.value
        if itemsize == 8:
            self.mc.VFM(resloc, loc0, loc1, l.imm(3), l.imm(0), l.imm(0))
            return
        not_implemented("vec_float_mul of size %d" % itemsize)

    def emit_vec_float_truediv(self, op, arglocs, regalloc):
        resloc, loc0, loc1, itemsize_loc = arglocs
        itemsize = itemsize_loc.value
        if itemsize == 8:
            self.mc.VFD(resloc, loc0, loc1, l.imm(3), l.imm(0), l.imm(0))
            return
        not_implemented("vec_float_truediv of size %d" % itemsize)

    def emit_vec_int_and(self, op, arglocs, regalloc):
        resloc, loc0, loc1, sizeloc = arglocs
        self.mc.VN(resloc, loc0, loc1)

    def emit_vec_int_or(self, op, arglocs, regalloc):
        resloc, loc0, loc1, sizeloc = arglocs
        self.mc.VO(resloc, loc0, loc1)

    def emit_vec_int_xor(self, op, arglocs, regalloc):
        resloc, loc0, loc1, sizeloc = arglocs
        self.mc.VX(resloc, loc0, loc1)

    def emit_vec_int_signext(self, op, arglocs, regalloc):
        resloc, loc0, osizeloc, nsizeloc = arglocs
        # signext is only allowed if the data type sizes do not change.
        # e.g. [byte,byte] = sign_ext([byte, byte]), a simple move is sufficient!
        osize = osizeloc.value
        nsize = nsizeloc.value
        if osize == nsize:
            self.regalloc_mov(loc0, resloc)
        elif (osize == 4 and nsize == 8) or (osize == 8 and nsize == 4):
            self.mc.VLGV(r.SCRATCH, loc0, l.addr(0), l.itemsize_to_mask(osize))
            self.mc.VLVG(resloc, r.SCRATCH, l.addr(0), l.itemsize_to_mask(nsize))
            self.mc.VLGV(r.SCRATCH, loc0, l.addr(1), l.itemsize_to_mask(osize))
            self.mc.VLVG(resloc, r.SCRATCH, l.addr(1), l.itemsize_to_mask(nsize))
            if nsize == 8:
                self.mc.VSEG(resloc, resloc, l.itemsize_to_mask(osize))

    def emit_vec_float_abs(self, op, arglocs, regalloc):
        resloc, argloc, sizeloc = arglocs
        size = sizeloc.value
        if size == 8:
            self.mc.VFPSO(resloc, argloc, l.imm(3), l.imm(0), l.imm(2))
            return
        not_implemented("vec_float_abs of size %d" % size)

    def emit_vec_float_neg(self, op, arglocs, regalloc):
        resloc, argloc, sizeloc = arglocs
        size = sizeloc.value
        if size == 8:
            self.mc.VFPSO(resloc, argloc, l.imm(3), l.imm(0), l.imm(0))
            return
        not_implemented("vec_float_abs of size %d" % size)

    def emit_vec_guard_true(self, guard_op, arglocs, regalloc):
        self._emit_guard(guard_op, arglocs)

    def emit_vec_guard_false(self, guard_op, arglocs, regalloc):
        self.guard_success_cc = c.negate(self.guard_success_cc)
        self._emit_guard(guard_op, arglocs)

    def _update_at_exit(self, fail_locs, fail_args, faildescr, regalloc):
        """ If accumulation is done in this loop, at the guard exit
            some vector registers must be adjusted to yield the correct value
        """
        if not isinstance(faildescr, ResumeGuardDescr):
            return
        accum_info = faildescr.rd_vector_info
        while accum_info:
            pos = accum_info.getpos_in_failargs()
            scalar_loc = fail_locs[pos]
            vector_loc = accum_info.location
            # the upper elements will be lost if saved to the stack!
            scalar_arg = accum_info.getoriginal()
            orig_scalar_loc = scalar_loc
            if not scalar_loc.is_reg():
                if scalar_arg.type == FLOAT:
                    scalar_loc = r.FP_SCRATCH
                else:
                    scalar_loc = r.SCRATCH2
                self.regalloc_mov(orig_scalar_loc, scalar_loc)
            assert scalar_arg is not None
            op = accum_info.accum_operation
            self._accum_reduce(op, scalar_arg, vector_loc, scalar_loc)
            if scalar_loc is not orig_scalar_loc:
                self.regalloc_mov(scalar_loc, orig_scalar_loc)
            accum_info = accum_info.next()

    def _accum_reduce(self, op, arg, accumloc, targetloc):
        # Currently the accumulator can ONLY be 64 bit float/int
        if arg.type == FLOAT:
            self.mc.VPDI(targetloc, accumloc, accumloc, permi(1,0))
            if op == '+':
                self.mc.VFA(targetloc, targetloc, accumloc, l.imm3, l.imm(0b1000), l.imm(0))
                return
            elif op == '*':
                self.mc.VFM(targetloc, targetloc, accumloc, l.imm3, l.imm(0b1000), l.imm(0))
                return
        else:
            assert arg.type == INT
            # store the vector onto the stack, just below the stack pointer
            self.mc.VLGV(r.SCRATCH, accumloc, l.addr(0), l.itemsize_to_mask(8))
            self.mc.VLGV(targetloc, accumloc, l.addr(1), l.itemsize_to_mask(8))
            if op == '+':
                self.mc.AGR(targetloc, r.SCRATCH)
                return
            elif op == '*':
                self.mc.MSGR(targetloc, r.SCRATCH)
                return
        not_implemented("reduce sum for %s not impl." % arg)



    def emit_vec_int_is_true(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, argloc, sizeloc = arglocs
        size = sizeloc.value
        tmploc = regalloc.vrm.get_scratch_reg()
        self.mc.VX(tmploc, tmploc, tmploc) # all zero
        self.mc.VCHL(resloc, argloc, tmploc, l.itemsize_to_mask(size), l.imm(0b0001))
        flush_vec_cc(self, regalloc, c.VEQI, op.bytesize, resloc)

    def emit_vec_float_eq(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, loc0, loc1, sizeloc = arglocs
        size = sizeloc.value
        if size == 8:
            # bit 3 in last argument sets the condition code
            self.mc.VFCE(resloc, loc0, loc1, l.imm(3), l.imm(0), l.imm(1))
        else:
            not_implemented("[zarch/assembler] float == for size %d" % size)
        flush_vec_cc(self, regalloc, c.VEQI, op.bytesize, resloc)

    def emit_vec_float_xor(self, op, arglocs, regalloc):
        resloc, loc0, loc1, sizeloc = arglocs
        self.mc.VX(resloc, loc0, loc1)

    def emit_vec_float_ne(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, loc0, loc1, sizeloc = arglocs
        size = sizeloc.value
        if size == 8:
            # bit 3 in last argument sets the condition code
            self.mc.VFCE(resloc, loc0, loc1, l.imm(3), l.imm(0), l.imm(1))
            self.mc.VNO(resloc, resloc, resloc)
        else:
            not_implemented("[zarch/assembler] float != for size %d" % size)
        flush_vec_cc(self, regalloc, c.VNEI, op.bytesize, resloc)

    def emit_vec_cast_int_to_float(self, op, arglocs, regalloc):
        resloc, loc0 = arglocs
        self.mc.VCDG(resloc, loc0, l.imm(3), l.imm(4), m.RND_TOZERO)

    def emit_vec_int_eq(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, loc0, loc1, sizeloc = arglocs
        size = sizeloc.value
        self.mc.VCEQ(resloc, loc0, loc1, l.itemsize_to_mask(size), l.imm(1))
        flush_vec_cc(self, regalloc, c.VEQI, op.bytesize, resloc)

    def emit_vec_int_ne(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, loc0, loc1, sizeloc = arglocs
        size = sizeloc.value
        self.mc.VCEQ(resloc, loc0, loc1, l.itemsize_to_mask(size), l.imm(1))
        self.mc.VNO(resloc, resloc, resloc)
        flush_vec_cc(self, regalloc, c.VNEI, op.bytesize, resloc)

    def emit_vec_cast_float_to_int(self, op, arglocs, regalloc):
        resloc, loc0 = arglocs
        # 4 => bit 1 from the MSB: XxC
        self.mc.VCGD(resloc, loc0, l.imm(3), l.imm(4), m.RND_TOZERO)

    def emit_vec_expand_i(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, loc0 = arglocs
        size = op.bytesize
        if loc0.is_core_reg():
            self.mc.VLVG(resloc, loc0, l.addr(0), l.itemsize_to_mask(size))
            self.mc.VREP(resloc, resloc, l.imm0, l.itemsize_to_mask(size))
        else:
            self.mc.VLREP(resloc, loc0, l.itemsize_to_mask(size))

    def emit_vec_expand_f(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, loc0 = arglocs
        size = op.bytesize
        if loc0.is_fp_reg():
            self.mc.VREP(resloc, loc0, l.imm0, l.itemsize_to_mask(size))
        else:
            self.mc.VLREP(resloc, loc0, l.itemsize_to_mask(size))

    def emit_vec_pack_i(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, vecloc, sourceloc, residxloc, srcidxloc, countloc, sizeloc = arglocs
        residx = residxloc.value
        srcidx = srcidxloc.value
        count = countloc.value
        size = sizeloc.value
        assert isinstance(op, VectorOp)
        newsize = op.bytesize
        if count == 1:
            if resloc.is_core_reg():
                assert sourceloc.is_vector_reg()
                index = l.addr(srcidx)
                self.mc.VLGV(resloc, sourceloc, index, l.itemsize_to_mask(size))
            else:
                assert sourceloc.is_core_reg()
                assert resloc.is_vector_reg()
                index = l.addr(residx)
                self.mc.VLR(resloc, vecloc)
                self.mc.VLVG(resloc, sourceloc, index, l.itemsize_to_mask(newsize))
        else:
            assert resloc.is_vector_reg()
            assert sourceloc.is_vector_reg()
            self.mc.VLR(resloc, vecloc)
            for j in range(count):
                sindex = l.addr(j + srcidx)
                # load from sourceloc into GP reg and store back into resloc
                self.mc.VLGV(r.SCRATCH, sourceloc, sindex, l.itemsize_to_mask(size))
                rindex = l.addr(j + residx)
                self.mc.VLVG(resloc, r.SCRATCH, rindex, l.itemsize_to_mask(newsize))

    emit_vec_unpack_i = emit_vec_pack_i

    def emit_vec_pack_f(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, vecloc, srcloc, residxloc, srcidxloc, countloc = arglocs
        residx = residxloc.value
        srcidx = srcidxloc.value
        # srcloc is always a floating point register f, this means it is
        # vsr[0] == valueof(f)
        if srcidx == 0:
            if residx == 0:
                # r = (s[0], v[1])
                self.mc.VPDI(resloc, srcloc, vecloc, permi(0,1))
            else:
                assert residx == 1
                # r = (v[0], s[0])
                self.mc.VPDI(resloc, vecloc, srcloc, permi(0,0))
        else:
            assert srcidx == 1
            if residx == 0:
                # r = (s[1], v[1])
                self.mc.VPDI(resloc, srcloc, vecloc, permi(1,1))
            else:
                assert residx == 1
                # r = (v[0], s[1])
                self.mc.VPDI(resloc, vecloc, srcloc, permi(0,1))

    def emit_vec_unpack_f(self, op, arglocs, regalloc):
        assert isinstance(op, VectorOp)
        resloc, srcloc, srcidxloc, countloc = arglocs
        srcidx = srcidxloc.value
        # srcloc is always a floating point register f, this means it is
        # vsr[0] == valueof(f)
        if srcidx == 0:
            # r = (s[0], s[1])
            self.mc.VPDI(resloc, srcloc, srcloc, permi(0,1))
            return
        else:
            # r = (s[1], s[0])
            self.mc.VPDI(resloc, srcloc, srcloc, permi(1,0))
            return
        not_implemented("unpack for combination src %d -> res %d" % (srcidx, 0))

    def emit_vec_f(self, op, arglocs, regalloc):
        pass
    emit_vec_i = emit_vec_f

class VectorRegalloc(object):
    _mixin_ = True

    def force_allocate_vector_reg(self, op):
        forbidden_vars = self.vrm.temp_boxes
        return self.vrm.force_allocate_reg(op, forbidden_vars)

    def force_allocate_vector_reg_or_cc(self, op):
        assert op.type == INT
        if self.next_op_can_accept_cc(self.operations, self.rm.position):
            # hack: return the SPP location to mean "lives in CC".  This
            # SPP will not actually be used, and the location will be freed
            # after the next op as usual.
            self.rm.force_allocate_frame_reg(op)
            return r.SPP
        else:
            return self.force_allocate_vector_reg(op)

    def ensure_vector_reg(self, box):
        return self.vrm.make_sure_var_in_reg(box,
                           forbidden_vars=self.vrm.temp_boxes)

    def _prepare_load(self, op):
        descr = op.getdescr()
        assert isinstance(descr, ArrayDescr)
        assert not descr.is_array_of_pointers() and \
               not descr.is_array_of_structs()
        itemsize, ofs, _ = unpack_arraydescr(descr)
        integer = not (descr.is_array_of_floats() or descr.getconcrete_type() == FLOAT)
        a0 = op.getarg(0)
        a1 = op.getarg(1)
        base_loc = self.ensure_reg(a0)
        ofs_loc = self.ensure_reg(a1)
        result_loc = self.force_allocate_vector_reg(op)
        return [result_loc, base_loc, ofs_loc, imm(itemsize), imm(ofs),
                imm(integer)]

    prepare_vec_load_i = _prepare_load
    prepare_vec_load_f = _prepare_load

    def prepare_vec_arith(self, op):
        assert isinstance(op, VectorOp)
        a0 = op.getarg(0)
        a1 = op.getarg(1)
        size = op.bytesize
        loc0 = self.ensure_vector_reg(a0)
        loc1 = self.ensure_vector_reg(a1)
        resloc = self.force_allocate_vector_reg(op)
        return [resloc, loc0, loc1, imm(size)]

    prepare_vec_int_add = prepare_vec_arith
    prepare_vec_int_sub = prepare_vec_arith
    prepare_vec_int_mul = prepare_vec_arith
    prepare_vec_float_add = prepare_vec_arith
    prepare_vec_float_sub = prepare_vec_arith
    prepare_vec_float_mul = prepare_vec_arith
    prepare_vec_float_truediv = prepare_vec_arith

    # logic functions
    prepare_vec_int_and = prepare_vec_arith
    prepare_vec_int_or = prepare_vec_arith
    prepare_vec_int_xor = prepare_vec_arith
    prepare_vec_float_xor = prepare_vec_arith
    del prepare_vec_arith

    def prepare_vec_bool(self, op):
        assert isinstance(op, VectorOp)
        a0 = op.getarg(0)
        a1 = op.getarg(1)
        size = op.bytesize
        loc0 = self.ensure_vector_reg(a0)
        loc1 = self.ensure_vector_reg(a1)
        resloc = self.force_allocate_vector_reg_or_cc(op)
        return [resloc, loc0, loc1, imm(size)]

    prepare_vec_float_eq = prepare_vec_bool
    prepare_vec_float_ne = prepare_vec_bool
    prepare_vec_int_eq = prepare_vec_bool
    prepare_vec_int_ne = prepare_vec_bool
    del prepare_vec_bool

    def prepare_vec_store(self, op):
        descr = op.getdescr()
        assert isinstance(descr, ArrayDescr)
        assert not descr.is_array_of_pointers() and \
               not descr.is_array_of_structs()
        itemsize, ofs, _ = unpack_arraydescr(descr)
        a0 = op.getarg(0)
        a1 = op.getarg(1)
        a2 = op.getarg(2)
        baseloc = self.ensure_reg(a0)
        ofsloc = self.ensure_reg(a1)
        valueloc = self.ensure_vector_reg(a2)

        integer = not (descr.is_array_of_floats() or descr.getconcrete_type() == FLOAT)
        return [baseloc, ofsloc, valueloc,
                imm(itemsize), imm(ofs), imm(integer)]

    def prepare_vec_int_signext(self, op):
        assert isinstance(op, VectorOp)
        a0 = op.getarg(0)
        assert isinstance(a0, VectorOp)
        loc0 = self.ensure_vector_reg(a0)
        resloc = self.force_allocate_vector_reg(op)
        return [resloc, loc0, imm(a0.bytesize), imm(op.bytesize)]

    def prepare_vec_arith_unary(self, op):
        assert isinstance(op, VectorOp)
        a0 = op.getarg(0)
        loc0 = self.ensure_vector_reg(a0)
        resloc = self.force_allocate_vector_reg(op)
        sizeloc = imm(op.bytesize)
        return [resloc, loc0, sizeloc]

    prepare_vec_float_neg = prepare_vec_arith_unary
    prepare_vec_float_abs = prepare_vec_arith_unary
    del prepare_vec_arith_unary

    def prepare_vec_pack_i(self, op):
        # new_res = vec_pack_i(res, src, index, count)
        assert isinstance(op, VectorOp)
        arg = op.getarg(1)
        index = op.getarg(2)
        count = op.getarg(3)
        assert isinstance(index, ConstInt)
        assert isinstance(count, ConstInt)
        arg0 = op.getarg(0)
        assert isinstance(arg0, VectorOp)
        vloc = self.ensure_vector_reg(arg0)
        srcloc = self.ensure_reg(arg)
        resloc = self.force_allocate_vector_reg(op)
        residx = index.value # where to put it in result?
        srcidx = 0
        return [resloc, vloc, srcloc, imm(residx), imm(srcidx), imm(count.value), imm(arg0.bytesize)]

    def prepare_vec_unpack_i(self, op):
        assert isinstance(op, VectorOp)
        index = op.getarg(1)
        count = op.getarg(2)
        assert isinstance(index, ConstInt)
        assert isinstance(count, ConstInt)
        arg = op.getarg(0)
        if arg.is_vector():
            srcloc = self.ensure_vector_reg(arg)
            assert isinstance(arg, VectorOp)
            size = arg.bytesize
        else:
            # unpack
            srcloc = self.ensure_reg(arg)
            size = WORD
        if op.is_vector():
            resloc = self.force_allocate_vector_reg(op)
        else:
            resloc = self.force_allocate_reg(op)
        return [resloc, srcloc, srcloc, imm(0), imm(index.value), imm(count.value), imm(size)]

    def prepare_vec_pack_f(self, op):
        # new_res = vec_pack_f(res, src, index, count)
        assert isinstance(op, VectorOp)
        arg = op.getarg(1)
        index = op.getarg(2)
        count = op.getarg(3)
        assert isinstance(index, ConstInt)
        assert isinstance(count, ConstInt)
        assert not arg.is_vector()
        srcloc = self.ensure_reg(arg)
        vloc = self.ensure_vector_reg(op.getarg(0))
        if op.is_vector():
            resloc = self.force_allocate_vector_reg(op)
        else:
            resloc = self.force_allocate_reg(op)
        residx = index.value # where to put it in result?
        srcidx = 0
        return [resloc, vloc, srcloc, imm(residx), imm(srcidx), imm(count.value)]

    def prepare_vec_unpack_f(self, op):
        index = op.getarg(1)
        count = op.getarg(2)
        assert isinstance(index, ConstInt)
        assert isinstance(count, ConstInt)
        srcloc = self.ensure_vector_reg(op.getarg(0))
        resloc = self.force_allocate_reg(op)
        return [resloc, srcloc, imm(index.value), imm(count.value)]

    def expand_float(self, size, box):
        adr = self.assembler.datablockwrapper.malloc_aligned(16, 16)
        fs = box.getfloatstorage()
        rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE), adr)[0] = fs
        rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE), adr)[1] = fs
        return l.ConstFloatLoc(adr)

    def prepare_vec_expand_f(self, op):
        assert isinstance(op, VectorOp)
        arg = op.getarg(0)
        l0 = self.ensure_reg_or_pool(arg)
        res = self.force_allocate_vector_reg(op)
        return [res, l0]

    prepare_vec_expand_i = prepare_vec_expand_f

    def prepare_vec_int_is_true(self, op):
        assert isinstance(op, VectorOp)
        arg = op.getarg(0)
        assert isinstance(arg, VectorOp)
        argloc = self.ensure_vector_reg(arg)
        resloc = self.force_allocate_vector_reg_or_cc(op)
        return [resloc, argloc, imm(arg.bytesize)]

    def _prepare_vec(self, op):
        # pseudo instruction, needed to allocate a register for a new variable
        return [self.force_allocate_vector_reg(op)]

    prepare_vec_i = _prepare_vec
    prepare_vec_f = _prepare_vec

    def prepare_vec_cast_float_to_int(self, op):
        l0 = self.ensure_vector_reg(op.getarg(0))
        res = self.force_allocate_vector_reg(op)
        return [res, l0]

    prepare_vec_cast_int_to_float = prepare_vec_cast_float_to_int

    def prepare_vec_guard_true(self, op):
        self.assembler.guard_success_cc = c.EQ
        return self._prepare_guard(op)

    def prepare_vec_guard_false(self, op):
        self.assembler.guard_success_cc = c.NE
        return self._prepare_guard(op)
