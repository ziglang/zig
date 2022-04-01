
from rpython.jit.backend.aarch64 import registers as r
from rpython.jit.backend.aarch64 import locations
from rpython.jit.backend.arm import conditions as c
from rpython.jit.backend.aarch64.arch import WORD, JITFRAME_FIXED_SIZE

from rpython.jit.metainterp.history import (Const, ConstInt, ConstFloat,
                                            ConstPtr,
                                            INT, REF, FLOAT)
from rpython.jit.metainterp.history import TargetToken
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.backend.llsupport.regalloc import FrameManager, \
        RegisterManager, TempVar, compute_vars_longevity, BaseRegalloc, \
        get_scale
from rpython.rtyper.lltypesystem import lltype, rffi, rstr, llmemory
from rpython.jit.backend.aarch64 import registers as r
from rpython.jit.backend.aarch64.jump import remap_frame_layout_mixed
from rpython.jit.backend.aarch64.locations import imm
from rpython.jit.backend.llsupport.gcmap import allocate_gcmap
from rpython.jit.backend.llsupport.descr import CallDescr
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.codewriter import longlong

from rpython.rlib.rarithmetic import r_uint


class TempInt(TempVar):
    type = INT

    def __repr__(self):
        return "<TempInt at %s>" % (id(self),)


class TempPtr(TempVar):
    type = REF

    def __repr__(self):
        return "<TempPtr at %s>" % (id(self),)


class TempFloat(TempVar):
    type = FLOAT

    def __repr__(self):
        return "<TempFloat at %s>" % (id(self),)


class ARMFrameManager(FrameManager):

    def __init__(self, base_ofs):
        FrameManager.__init__(self)
        self.base_ofs = base_ofs

    def frame_pos(self, i, box_type):
        return locations.StackLocation(i, locations.get_fp_offset(self.base_ofs, i), box_type)

    @staticmethod
    def frame_size(type):
        return 1

    @staticmethod
    def get_loc_index(loc):
        assert loc.is_stack()
        return loc.position

class ARMRegisterManager(RegisterManager):
    FORBID_TEMP_BOXES = True

    def return_constant(self, v, forbidden_vars=[], selected_reg=None):
        self._check_type(v)
        if isinstance(v, Const):
            if isinstance(v, ConstPtr):
                tp = REF
            elif isinstance(v, ConstFloat):
                tp = FLOAT
            else:
                tp = INT
            loc = self.get_scratch_reg(tp,
                    forbidden_vars,
                    selected_reg=selected_reg)
            immvalue = self.convert_to_imm(v)
            self.assembler.load(loc, immvalue)
            return loc
        else:
            return RegisterManager.return_constant(self, v,
                                    forbidden_vars, selected_reg)




class VFPRegisterManager(ARMRegisterManager):
    all_regs = r.all_vfp_regs
    box_types = [FLOAT]
    save_around_call_regs = r.all_vfp_regs

    def convert_to_imm(self, c):
        adr = self.assembler.datablockwrapper.malloc_aligned(8, 8)
        x = c.getfloatstorage()
        rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE), adr)[0] = x
        return locations.ConstFloatLoc(adr)

    def call_result_location(self, v):
        return r.d0

    def __init__(self, longevity, frame_manager=None, assembler=None):
        RegisterManager.__init__(self, longevity, frame_manager, assembler)

    def get_scratch_reg(self, type=FLOAT, forbidden_vars=[], selected_reg=None):
        assert type == FLOAT  # for now
        box = TempFloat()
        reg = self.force_allocate_reg(box, forbidden_vars=forbidden_vars,
                                                    selected_reg=selected_reg)
        self.temp_boxes.append(box)
        return reg


class CoreRegisterManager(ARMRegisterManager):
    all_regs = r.all_regs
    box_types = None       # or a list of acceptable types
    no_lower_byte_regs = all_regs
    save_around_call_regs = r.caller_resp
    frame_reg = r.fp

    def __init__(self, longevity, frame_manager=None, assembler=None):
        RegisterManager.__init__(self, longevity, frame_manager, assembler)

    def call_result_location(self, v):
        return r.x0

    def convert_to_imm(self, c):
        if isinstance(c, ConstInt):
            val = rffi.cast(lltype.Signed, c.value)
            return locations.ImmLocation(val)
        else:
            assert isinstance(c, ConstPtr)
            return locations.ImmLocation(rffi.cast(lltype.Signed, c.value))
        assert 0

    def get_scratch_reg(self, type=INT, forbidden_vars=[], selected_reg=None):
        assert type == INT or type == REF
        box = None
        if type == INT:
            box = TempInt()
        else:
            box = TempPtr()
        reg = self.force_allocate_reg(box, forbidden_vars=forbidden_vars,
                                                    selected_reg=selected_reg)
        self.temp_boxes.append(box)
        return reg

    def get_free_reg(self):
        free_regs = self.free_regs
        for i in range(len(free_regs) - 1, -1, -1):
            if free_regs[i] in self.save_around_call_regs:
                continue
            return free_regs[i]

DEFAULT_IMM_SIZE = 4096

def check_imm_arg(arg, size=DEFAULT_IMM_SIZE, allow_zero=True):
    i = arg
    if allow_zero:
        lower_bound = i >= 0
    else:
        lower_bound = i > 0
    return i < size and lower_bound

def check_imm_box(arg, size=DEFAULT_IMM_SIZE, allow_zero=True):
    if isinstance(arg, ConstInt):
        return check_imm_arg(arg.getint(), size, allow_zero)
    return False


class Regalloc(BaseRegalloc):

    def __init__(self, assembler):
        self.cpu = assembler.cpu
        self.assembler = assembler
        self.frame_manager = None
        self.jump_target_descr = None
        self.final_jump_op = None

    def _prepare(self, inputargs, operations, allgcrefs):
        cpu = self.cpu
        self.fm = ARMFrameManager(cpu.get_baseofs_of_frame_field())
        self.frame_manager = self.fm
        operations = cpu.gc_ll_descr.rewrite_assembler(cpu, operations,
                                                       allgcrefs)
        # compute longevity of variables
        longevity = compute_vars_longevity(inputargs, operations)
        self.longevity = longevity
        fm = self.frame_manager
        asm = self.assembler
        self.vfprm = VFPRegisterManager(longevity, fm, asm)
        self.rm = CoreRegisterManager(longevity, fm, asm)
        return operations

    def prepare_loop(self, inputargs, operations, looptoken, allgcrefs):
        operations = self._prepare(inputargs, operations, allgcrefs)
        self._set_initial_bindings(inputargs, looptoken)
        self.possibly_free_vars(list(inputargs))
        return operations

    def loc(self, var):
        if var.type == FLOAT:
            return self.vfprm.loc(var)
        else:
            return self.rm.loc(var)

    def possibly_free_var(self, var):
        if var.type == FLOAT:
            self.vfprm.possibly_free_var(var)
        else:
            self.rm.possibly_free_var(var)

    def force_spill_var(self, var):
        if var.type == FLOAT:
            self.vfprm.force_spill_var(var)
        else:
            self.rm.force_spill_var(var)

    def possibly_free_vars_for_op(self, op):
        for i in range(op.numargs()):
            var = op.getarg(i)
            if var is not None:  # xxx kludgy
                self.possibly_free_var(var)
        if op.is_guard():
            self.possibly_free_vars(op.getfailargs())

    def possibly_free_vars(self, vars):
        for var in vars:
            if var is not None:  # xxx kludgy
                self.possibly_free_var(var)

    def get_scratch_reg(self, type, forbidden_vars=[], selected_reg=None):
        if type == FLOAT:
            return self.vfprm.get_scratch_reg(type, forbidden_vars,
                                                                selected_reg)
        else:
            return self.rm.get_scratch_reg(type, forbidden_vars, selected_reg)

    def get_free_reg(self):
        return self.rm.get_free_reg()

    def free_temp_vars(self):
        self.rm.free_temp_vars()
        self.vfprm.free_temp_vars()

    def make_sure_var_in_reg(self, var, forbidden_vars=[],
                         selected_reg=None, need_lower_byte=False):
        if var.type == FLOAT:
            return self.vfprm.make_sure_var_in_reg(var, forbidden_vars,
                                        selected_reg, need_lower_byte)
        else:
            return self.rm.make_sure_var_in_reg(var, forbidden_vars,
                                        selected_reg, need_lower_byte)

    def convert_to_imm(self, value):
        if isinstance(value, ConstInt):
            return self.rm.convert_to_imm(value)
        else:
            assert isinstance(value, ConstFloat)
            return self.vfprm.convert_to_imm(value)

    def compute_hint_frame_locations(self, operations):
        # optimization only: fill in the 'hint_frame_locations' dictionary
        # of rm and xrm based on the JUMP at the end of the loop, by looking
        # at where we would like the boxes to be after the jump.
        op = operations[-1]
        if op.getopnum() != rop.JUMP:
            return
        self.final_jump_op = op
        descr = op.getdescr()
        assert isinstance(descr, TargetToken)
        if descr._ll_loop_code != 0:
            # if the target LABEL was already compiled, i.e. if it belongs
            # to some already-compiled piece of code
            self._compute_hint_frame_locations_from_descr(descr)
        #else:
        #   The loop ends in a JUMP going back to a LABEL in the same loop.
        #   We cannot fill 'hint_frame_locations' immediately, but we can
        #   wait until the corresponding prepare_op_label() to know where the
        #   we would like the boxes to be after the jump.

    def _compute_hint_frame_locations_from_descr(self, descr):
        arglocs = descr._arm_arglocs
        jump_op = self.final_jump_op
        assert len(arglocs) == jump_op.numargs()
        for i in range(jump_op.numargs()):
            box = jump_op.getarg(i)
            if not isinstance(box, Const):
                loc = arglocs[i]
                if loc is not None and loc.is_stack():
                    self.frame_manager.hint_frame_pos[box] = (
                        self.fm.get_loc_index(loc))

    def position(self):
        return self.rm.position

    def next_instruction(self):
        self.rm.next_instruction()
        self.vfprm.next_instruction()

    def prepare_op_increment_debug_counter(self, op):
        boxes = op.getarglist()
        a0, = boxes
        base_loc = self.make_sure_var_in_reg(a0, boxes)
        value_loc = self.get_scratch_reg(INT, boxes)
        self.free_temp_vars()
        return [base_loc, value_loc]

    def void(self, op):
        return []

    prepare_op_jit_debug = void
    prepare_op_enter_portal_frame = void
    prepare_op_leave_portal_frame = void
    prepare_op_zero_array = void # dealth with in opassembler.py
    prepare_op_keepalive = void

    def prepare_int_ri(self, op, res_in_cc):
        boxes = op.getarglist()
        a0, a1 = boxes
        imm_a0 = check_imm_box(a0)
        imm_a1 = check_imm_box(a1)
        if not imm_a0 and imm_a1:
            l0 = self.make_sure_var_in_reg(a0, boxes)
            l1 = self.convert_to_imm(a1)
        elif imm_a0 and not imm_a1:
            l1 = self.convert_to_imm(a0)
            l0 = self.make_sure_var_in_reg(a1, boxes)
        else:
            l0 = self.make_sure_var_in_reg(a0, boxes)
            l1 = self.make_sure_var_in_reg(a1, boxes)
        self.possibly_free_vars_for_op(op)
        res = self.force_allocate_reg(op)
        # note that we always allocate res, even if res_in_cc is True,
        # that only means overflow is in CC
        return [l0, l1, res]

    def prepare_op_int_add(self, op):
        return self.prepare_int_ri(op, False)

    def prepare_op_int_sub(self, op):
        boxes = op.getarglist()
        a0, a1 = boxes
        imm_a1 = check_imm_box(a1)
        if imm_a1:
            l0 = self.make_sure_var_in_reg(a0, boxes)
            l1 = self.convert_to_imm(a1)
        else:
            l0 = self.make_sure_var_in_reg(a0, boxes)
            l1 = self.make_sure_var_in_reg(a1, boxes)
        self.possibly_free_vars_for_op(op)
        res = self.force_allocate_reg(op)
        return [l0, l1, res]

    def prepare_comp_op_int_sub_ovf(self, op, res_in_cc):
        # ignore res_in_cc
        return self.prepare_op_int_sub(op)

    def prepare_op_int_mul(self, op):
        boxes = op.getarglist()
        a0, a1 = boxes

        reg1 = self.make_sure_var_in_reg(a0, forbidden_vars=boxes)
        reg2 = self.make_sure_var_in_reg(a1, forbidden_vars=boxes)

        self.possibly_free_vars(boxes)
        self.possibly_free_vars_for_op(op)
        res = self.force_allocate_reg(op)
        self.possibly_free_var(op)
        return [reg1, reg2, res]

    def prepare_comp_op_int_mul_ovf(self, op, res_in_cc):
        return self.prepare_op_int_mul(op)

    def prepare_op_int_force_ge_zero(self, op):
        argloc = self.make_sure_var_in_reg(op.getarg(0))
        resloc = self.force_allocate_reg(op, [op.getarg(0)])
        return [argloc, resloc]

    def prepare_op_int_signext(self, op):
        argloc = self.make_sure_var_in_reg(op.getarg(0))
        numbytes = op.getarg(1).getint()
        resloc = self.force_allocate_reg(op)
        return [argloc, imm(numbytes), resloc]

    # some of those have forms of imm that they accept, but they're rather
    # obscure. Can be future optimization
    prepare_op_int_and = prepare_op_int_mul
    prepare_op_int_or = prepare_op_int_mul
    prepare_op_int_xor = prepare_op_int_mul
    prepare_op_int_lshift = prepare_op_int_mul
    prepare_op_int_rshift = prepare_op_int_mul
    prepare_op_uint_rshift = prepare_op_int_mul
    prepare_op_uint_mul_high = prepare_op_int_mul

    def prepare_int_cmp(self, op, res_in_cc):
        boxes = op.getarglist()
        arg0, arg1 = boxes
        imm_a1 = check_imm_box(arg1)

        l0 = self.make_sure_var_in_reg(arg0, forbidden_vars=boxes)
        if imm_a1:
            l1 = self.convert_to_imm(arg1)
        else:
            l1 = self.make_sure_var_in_reg(arg1, forbidden_vars=boxes)

        self.possibly_free_vars_for_op(op)
        self.free_temp_vars()
        if not res_in_cc:
            res = self.force_allocate_reg(op)
            return [l0, l1, res]
        return [l0, l1]

    prepare_comp_op_int_lt = prepare_int_cmp
    prepare_comp_op_int_le = prepare_int_cmp
    prepare_comp_op_int_ge = prepare_int_cmp
    prepare_comp_op_int_gt = prepare_int_cmp
    prepare_comp_op_int_ne = prepare_int_cmp
    prepare_comp_op_int_eq = prepare_int_cmp
    prepare_comp_op_ptr_eq = prepare_comp_op_instance_ptr_eq = prepare_int_cmp
    prepare_comp_op_ptr_ne = prepare_comp_op_instance_ptr_ne = prepare_int_cmp
    prepare_comp_op_uint_lt = prepare_int_cmp
    prepare_comp_op_uint_le = prepare_int_cmp
    prepare_comp_op_uint_ge = prepare_int_cmp
    prepare_comp_op_uint_gt = prepare_int_cmp

    def prepare_float_op(self, op, res_in_cc):
        assert res_in_cc
        loc1 = self.make_sure_var_in_reg(op.getarg(0))
        loc2 = self.make_sure_var_in_reg(op.getarg(1))
        return [loc1, loc2]

    prepare_comp_op_float_lt = prepare_float_op
    prepare_comp_op_float_le = prepare_float_op
    prepare_comp_op_float_gt = prepare_float_op
    prepare_comp_op_float_ge = prepare_float_op
    prepare_comp_op_float_eq = prepare_float_op
    prepare_comp_op_float_ne = prepare_float_op

    def prepare_op_int_le(self, op):
        return self.prepare_int_cmp(op, False)

    prepare_op_int_lt = prepare_op_int_le
    prepare_op_int_gt = prepare_op_int_le
    prepare_op_int_ge = prepare_op_int_le
    prepare_op_int_eq = prepare_op_int_le
    prepare_op_int_ne = prepare_op_int_le
    prepare_op_uint_lt = prepare_op_int_le
    prepare_op_uint_le = prepare_op_int_le
    prepare_op_uint_gt = prepare_op_int_le
    prepare_op_uint_ge = prepare_op_int_le

    def prepare_unary(self, op):
        a0 = op.getarg(0)
        assert not isinstance(a0, Const)
        reg = self.make_sure_var_in_reg(a0)
        self.possibly_free_vars_for_op(op)
        res = self.force_allocate_reg(op)
        return [reg, res]

    prepare_op_int_is_true = prepare_unary
    prepare_op_int_is_zero = prepare_unary
    prepare_op_int_neg = prepare_unary
    prepare_op_int_invert = prepare_unary

    def prepare_comp_unary(self, op, res_in_cc):
        a0 = op.getarg(0)
        assert not isinstance(a0, Const)
        reg = self.make_sure_var_in_reg(a0)
        return [reg]

    prepare_comp_op_int_is_true = prepare_comp_unary
    prepare_comp_op_int_is_zero = prepare_comp_unary

    # --------------------------------- floats --------------------------

    def prepare_two_regs_op(self, op):
        loc1 = self.make_sure_var_in_reg(op.getarg(0))
        loc2 = self.make_sure_var_in_reg(op.getarg(1), op.getarglist())
        self.possibly_free_vars_for_op(op)
        self.free_temp_vars()
        res = self.force_allocate_reg(op)
        return [loc1, loc2, res]

    prepare_op_float_add = prepare_two_regs_op
    prepare_op_float_sub = prepare_two_regs_op
    prepare_op_float_mul = prepare_two_regs_op
    prepare_op_float_truediv = prepare_two_regs_op

    prepare_op_float_lt = prepare_two_regs_op
    prepare_op_float_le = prepare_two_regs_op
    prepare_op_float_eq = prepare_two_regs_op
    prepare_op_float_ne = prepare_two_regs_op
    prepare_op_float_gt = prepare_two_regs_op
    prepare_op_float_ge = prepare_two_regs_op

    prepare_op_float_neg = prepare_unary
    prepare_op_float_abs = prepare_unary
    prepare_op_cast_float_to_int = prepare_unary
    prepare_op_cast_int_to_float = prepare_unary

    def _prepare_op_math_sqrt(self, op):
        loc1 = self.make_sure_var_in_reg(op.getarg(1))
        self.possibly_free_vars_for_op(op)
        res = self.force_allocate_reg(op)
        return [loc1, res]

    def _prepare_threadlocalref_get(self, op):
        res_loc = self.force_allocate_reg(op)
        return [res_loc]

    prepare_op_convert_float_bytes_to_longlong = prepare_unary
    prepare_op_convert_longlong_bytes_to_float = prepare_unary

    # --------------------------------- fields --------------------------

    def prepare_op_gc_store(self, op):
        boxes = op.getarglist()
        base_loc = self.make_sure_var_in_reg(boxes[0], boxes)
        ofs = boxes[1].getint()
        value_loc = self.make_sure_var_in_reg(boxes[2], boxes)
        size = boxes[3].getint()
        if check_imm_arg(ofs):
            ofs_loc = imm(ofs)
        else:
            ofs_loc = r.ip1
            self.assembler.load(ofs_loc, imm(ofs))
        return [value_loc, base_loc, ofs_loc, imm(size)]

    def _prepare_op_gc_load(self, op):
        a0 = op.getarg(0)
        ofs = op.getarg(1).getint()
        nsize = op.getarg(2).getint()    # negative for "signed"
        base_loc = self.make_sure_var_in_reg(a0)
        immofs = imm(ofs)
        if check_imm_arg(ofs):
            ofs_loc = immofs
        else:
            ofs_loc = r.ip1
            self.assembler.load(ofs_loc, immofs)
        self.possibly_free_vars_for_op(op)
        res_loc = self.force_allocate_reg(op)
        return [base_loc, ofs_loc, res_loc, imm(nsize)]

    prepare_op_gc_load_i = _prepare_op_gc_load
    prepare_op_gc_load_r = _prepare_op_gc_load
    prepare_op_gc_load_f = _prepare_op_gc_load

    def prepare_op_gc_store_indexed(self, op):
        boxes = op.getarglist()
        base_loc = self.make_sure_var_in_reg(boxes[0], boxes)
        value_loc = self.make_sure_var_in_reg(boxes[2], boxes)
        index_loc = self.make_sure_var_in_reg(boxes[1], boxes)
        assert boxes[3].getint() == 1    # scale
        ofs = boxes[4].getint()
        size = boxes[5].getint()
        return [value_loc, base_loc, index_loc, imm(size), imm(ofs)]

    def _prepare_op_gc_load_indexed(self, op):
        boxes = op.getarglist()
        base_loc = self.make_sure_var_in_reg(boxes[0], boxes)
        index_loc = self.make_sure_var_in_reg(boxes[1], boxes)
        assert boxes[2].getint() == 1    # scale
        ofs = boxes[3].getint()
        nsize = boxes[4].getint()
        self.possibly_free_vars_for_op(op)
        self.free_temp_vars()
        res_loc = self.force_allocate_reg(op)
        return [res_loc, base_loc, index_loc, imm(nsize), imm(ofs)]

    prepare_op_gc_load_indexed_i = _prepare_op_gc_load_indexed
    prepare_op_gc_load_indexed_r = _prepare_op_gc_load_indexed
    prepare_op_gc_load_indexed_f = _prepare_op_gc_load_indexed

    # --------------------------------- call ----------------------------

    def _prepare_op_call(self, op):
        calldescr = op.getdescr()
        assert calldescr is not None
        effectinfo = calldescr.get_extra_info()
        if effectinfo is not None:
            oopspecindex = effectinfo.oopspecindex
            if oopspecindex == EffectInfo.OS_MATH_SQRT:
                args = self._prepare_op_math_sqrt(op)
                self.assembler.math_sqrt(op, args)
                return
            elif oopspecindex == EffectInfo.OS_THREADLOCALREF_GET:
                args = self._prepare_threadlocalref_get(op)
                self.assembler.threadlocalref_get(op, args)
                return
            #elif oopspecindex == EffectInfo.OS_MATH_READ_TIMESTAMP:
            #    ...
        return self._prepare_call(op)

    prepare_op_call_i = _prepare_op_call
    prepare_op_call_r = _prepare_op_call
    prepare_op_call_f = _prepare_op_call
    prepare_op_call_n = _prepare_op_call

    def _prepare_call(self, op, save_all_regs=False, first_arg_index=1):
        args = [None] * (op.numargs() + 3)
        calldescr = op.getdescr()
        assert isinstance(calldescr, CallDescr)
        assert len(calldescr.arg_classes) == op.numargs() - first_arg_index

        for i in range(op.numargs()):
            args[i + 3] = self.loc(op.getarg(i))

        size = calldescr.get_result_size()
        sign = calldescr.is_result_signed()
        if sign:
            sign_loc = imm(1)
        else:
            sign_loc = imm(0)
        args[1] = imm(size)
        args[2] = sign_loc

        effectinfo = calldescr.get_extra_info()
        if save_all_regs:
            gc_level = 2
        elif effectinfo is None or effectinfo.check_can_collect():
            gc_level = 1
        else:
            gc_level = 0

        args[0] = self._call(op, args, gc_level)
        return args

    def _call(self, op, arglocs, gc_level):
        # spill variables that need to be saved around calls:
        # gc_level == 0: callee cannot invoke the GC
        # gc_level == 1: can invoke GC, save all regs that contain pointers
        # gc_level == 2: can force, save all regs
        save_all_regs = gc_level == 2
        self.vfprm.before_call(save_all_regs=save_all_regs)
        if gc_level == 1 and self.cpu.gc_ll_descr.gcrootmap:
            save_all_regs = 2
        self.rm.before_call(save_all_regs=save_all_regs)
        resloc = self.after_call(op)
        return resloc

    def before_call(self, save_all_regs=False):
        self.rm.before_call(save_all_regs=save_all_regs)
        self.vfprm.before_call(save_all_regs=save_all_regs)

    def after_call(self, v):
        if v.type == 'v':
            return
        if v.type == FLOAT:
            return self.vfprm.after_call(v)
        else:
            return self.rm.after_call(v)

    def prepare_guard_op_guard_not_forced(self, op, prev_op):
        if rop.is_call_release_gil(prev_op.getopnum()):
            arglocs = self._prepare_call(prev_op, save_all_regs=True,
                                         first_arg_index=2)
        elif rop.is_call_assembler(prev_op.getopnum()):
            locs = self.locs_for_call_assembler(prev_op)
            tmploc = self.get_scratch_reg(INT, selected_reg=r.x0)
            resloc = self._call(prev_op, locs + [tmploc], gc_level=2)
            arglocs = locs + [resloc, tmploc]
        else:
            assert rop.is_call_may_force(prev_op.getopnum())
            arglocs = self._prepare_call(prev_op, save_all_regs=True)
        guard_locs = self._guard_impl(op)
        return arglocs + guard_locs, len(arglocs)

    def prepare_op_guard_not_forced_2(self, op):
        self.rm.before_call(op.getfailargs(), save_all_regs=True)
        self.vfprm.before_call(op.getfailargs(), save_all_regs=True)
        fail_locs = self._guard_impl(op)
        return fail_locs

    def prepare_op_label(self, op):
        descr = op.getdescr()
        assert isinstance(descr, TargetToken)
        inputargs = op.getarglist()
        arglocs = [None] * len(inputargs)
        #
        # we use force_spill() on the boxes that are not going to be really
        # used any more in the loop, but that are kept alive anyway
        # by being in a next LABEL's or a JUMP's argument or fail_args
        # of some guard
        position = self.rm.position
        for arg in inputargs:
            assert not isinstance(arg, Const)
            if self.longevity[arg].is_last_real_use_before(position):
                self.force_spill_var(arg)

        #
        for i in range(len(inputargs)):
            arg = inputargs[i]
            assert not isinstance(arg, Const)
            loc = self.loc(arg)
            arglocs[i] = loc
            if loc.is_core_reg() or loc.is_vfp_reg():
                self.frame_manager.mark_as_free(arg)
        #
        descr._arm_arglocs = arglocs
        descr._ll_loop_code = self.assembler.mc.currpos()
        descr._arm_clt = self.assembler.current_clt
        self.assembler.target_tokens_currently_compiling[descr] = None
        self.possibly_free_vars_for_op(op)
        #
        # if the LABEL's descr is precisely the target of the JUMP at the
        # end of the same loop, i.e. if what we are compiling is a single
        # loop that ends up jumping to this LABEL, then we can now provide
        # the hints about the expected position of the spilled variables.
        jump_op = self.final_jump_op
        if jump_op is not None and jump_op.getdescr() is descr:
            self._compute_hint_frame_locations_from_descr(descr)
        return []

    def _prepare_op_cond_call(self, op, res_in_cc):
        assert 2 <= op.numargs() <= 4 + 2
        v = op.getarg(1)
        assert isinstance(v, Const)
        args_so_far = []
        for i in range(2, op.numargs()):
            reg = r.argument_regs[i - 2]
            arg = op.getarg(i)
            self.make_sure_var_in_reg(arg, args_so_far, selected_reg=reg)
            args_so_far.append(arg)
        if res_in_cc:
            argloc = None
        else:
            argloc = self.make_sure_var_in_reg(op.getarg(0), args_so_far)

        if op.type == 'v':
            # a plain COND_CALL.  Calls the function when args[0] is
            # true.  Often used just after a comparison operation.
            return [argloc]
        else:
            # COND_CALL_VALUE_I/R.  Calls the function when args[0]
            # is equal to 0 or NULL.  Returns the result from the
            # function call if done, or args[0] if it was not 0/NULL.
            # Implemented by forcing the result to live in the same
            # register as args[0], and overwriting it if we really do
            # the call.

            # Load the register for the result.  Possibly reuse 'args[0]'.
            # But the old value of args[0], if it survives, is first
            # spilled away.  We can't overwrite any of op.args[2:] here.
            args = op.getarglist()
            resloc = self.rm.force_result_in_reg(op, args[0],
                                                 forbidden_vars=args[2:])
            return [argloc, resloc]

    def prepare_op_cond_call(self, op):
        return self._prepare_op_cond_call(op, False)

    def prepare_op_cond_call_value_i(self, op):
        return self._prepare_op_cond_call(op, False)
    prepare_op_cond_call_value_r = prepare_op_cond_call_value_i

    def prepare_guard_op_cond_call(self, op, prevop):
        fcond = self.assembler.dispatch_comparison(prevop)
        locs = self._prepare_op_cond_call(op, True)
        return locs, fcond

    def prepare_op_force_token(self, op):
        # XXX regular reg
        res_loc = self.force_allocate_reg(op)
        return [res_loc]

    def prepare_op_finish(self, op):
        # the frame is in fp, but we have to point where in the frame is
        # the potential argument to FINISH
        if op.numargs() == 1:
            loc = self.make_sure_var_in_reg(op.getarg(0))
            locs = [loc]
        else:
            locs = []
        return locs

    def guard_impl(self, op, prevop):
        fcond = self.assembler.dispatch_comparison(prevop)
        # result is in CC
        return self._guard_impl(op), fcond

    def _guard_impl(self, op):
        arglocs = [None] * (len(op.getfailargs()) + 1)
        arglocs[0] = imm(self.frame_manager.get_frame_depth())
        failargs = op.getfailargs()
        for i in range(len(failargs)):
            if failargs[i]:
                arglocs[i + 1] = self.loc(failargs[i])
        return arglocs

    prepare_guard_op_guard_true = guard_impl
    prepare_guard_op_guard_false = guard_impl

    def prepare_guard_op_guard_overflow(self, guard_op, prev_op):
        self.assembler.dispatch_comparison(prev_op)
        # result in CC
        if prev_op.opnum == rop.INT_MUL_OVF:
            return self._guard_impl(guard_op), c.EQ
        return self._guard_impl(guard_op), c.VC
    prepare_guard_op_guard_no_overflow = prepare_guard_op_guard_overflow

    def guard_no_cc_impl(self, op):
        # rare case of guard with no CC
        arglocs = self._guard_impl(op)
        return [self.loc(op.getarg(0))] + arglocs

    prepare_op_guard_true = guard_no_cc_impl
    prepare_op_guard_false = guard_no_cc_impl
    prepare_op_guard_nonnull = guard_no_cc_impl
    prepare_op_guard_isnull = guard_no_cc_impl

    def prepare_op_guard_value(self, op):
        arg = self.make_sure_var_in_reg(op.getarg(0))
        op.getdescr().make_a_counter_per_value(op,
            self.cpu.all_reg_indexes[arg.value])
        l1 = self.loc(op.getarg(1))
        imm_a1 = check_imm_box(op.getarg(1))
        if not imm_a1:
            l1 = self.make_sure_var_in_reg(op.getarg(1), [op.getarg(0)])
        arglocs = self._guard_impl(op)
        return [arg, l1] + arglocs

    def prepare_op_guard_class(self, op):
        assert not isinstance(op.getarg(0), Const)
        x = self.make_sure_var_in_reg(op.getarg(0))
        y_val = rffi.cast(lltype.Signed, op.getarg(1).getint())
        arglocs = self._guard_impl(op)
        return [x, imm(y_val)] + arglocs

    prepare_op_guard_nonnull_class = prepare_op_guard_class
    prepare_op_guard_gc_type = prepare_op_guard_class
    prepare_op_guard_subclass = prepare_op_guard_class

    def prepare_op_guard_is_object(self, op):
        loc_object = self.make_sure_var_in_reg(op.getarg(0))
        return [loc_object] + self._guard_impl(op)

    def prepare_op_guard_not_invalidated(self, op):
        return self._guard_impl(op)

    def prepare_op_guard_exception(self, op):
        boxes = op.getarglist()
        arg0 = ConstInt(rffi.cast(lltype.Signed, op.getarg(0).getint()))
        loc = self.make_sure_var_in_reg(arg0)
        if op in self.longevity:
            resloc = self.force_allocate_reg(op, boxes)
            self.possibly_free_var(op)
        else:
            resloc = None
        pos_exc_value = imm(self.cpu.pos_exc_value())
        pos_exception = imm(self.cpu.pos_exception())
        arglocs = [loc, resloc, pos_exc_value, pos_exception] + self._guard_impl(op)
        return arglocs

    def prepare_op_guard_no_exception(self, op):
        loc = self.make_sure_var_in_reg(ConstInt(self.cpu.pos_exception()))
        return [loc] + self._guard_impl(op)

    def prepare_op_save_exception(self, op):
        resloc = self.force_allocate_reg(op)
        return [resloc]
    prepare_op_save_exc_class = prepare_op_save_exception

    def prepare_op_restore_exception(self, op):
        boxes = op.getarglist()
        loc0 = self.make_sure_var_in_reg(op.getarg(0), boxes)  # exc class
        loc1 = self.make_sure_var_in_reg(op.getarg(1), boxes)  # exc instance
        return [loc0, loc1]

    prepare_op_ptr_eq = prepare_op_instance_ptr_eq = prepare_op_int_eq
    prepare_op_ptr_ne = prepare_op_instance_ptr_ne = prepare_op_int_ne

    prepare_op_nursery_ptr_increment = prepare_op_int_add
    prepare_comp_op_int_add_ovf = prepare_int_ri

    def _prepare_op_same_as(self, op):
        arg = op.getarg(0)
        imm_arg = check_imm_box(arg)
        if imm_arg:
            argloc = self.convert_to_imm(arg)
        else:
            argloc = self.make_sure_var_in_reg(arg)
        self.possibly_free_vars_for_op(op)
        self.free_temp_vars()
        resloc = self.force_allocate_reg(op)
        return [argloc, resloc]

    prepare_op_cast_ptr_to_int = _prepare_op_same_as
    prepare_op_cast_int_to_ptr = _prepare_op_same_as
    prepare_op_same_as_i = _prepare_op_same_as
    prepare_op_same_as_r = _prepare_op_same_as
    prepare_op_same_as_f = _prepare_op_same_as

    def prepare_op_load_from_gc_table(self, op):
        resloc = self.force_allocate_reg(op)
        return [resloc]

    def prepare_op_load_effective_address(self, op):
        args = op.getarglist()
        arg0 = self.make_sure_var_in_reg(args[0], args)
        arg1 = self.make_sure_var_in_reg(args[1], args)
        res = self.force_allocate_reg(op)
        return [arg0, arg1, imm(args[2].getint()), imm(args[3].getint()), res]

    def prepare_op_check_memory_error(self, op):
        argloc = self.make_sure_var_in_reg(op.getarg(0))
        return [argloc]

    def prepare_op_jump(self, op):
        assert self.jump_target_descr is None
        descr = op.getdescr()
        assert isinstance(descr, TargetToken)
        self.jump_target_descr = descr
        arglocs = descr._arm_arglocs

        # get temporary locs
        tmploc = r.ip0
        vfptmploc = r.vfp_ip

        # Part about non-floats
        src_locations1 = []
        dst_locations1 = []
        # Part about floats
        src_locations2 = []
        dst_locations2 = []

        # Build the four lists
        for i in range(op.numargs()):
            box = op.getarg(i)
            src_loc = self.loc(box)
            dst_loc = arglocs[i]
            if box.type != FLOAT:
                src_locations1.append(src_loc)
                dst_locations1.append(dst_loc)
            else:
                src_locations2.append(src_loc)
                dst_locations2.append(dst_loc)
        self.assembler.check_frame_before_jump(self.jump_target_descr)
        remap_frame_layout_mixed(self.assembler,
                                 src_locations1, dst_locations1, tmploc,
                                 src_locations2, dst_locations2, vfptmploc)
        return []

    def prepare_op_cond_call_gc_wb(self, op):
        # we force all arguments in a reg because it will be needed anyway by
        # the following gc_store. It avoids loading it twice from the memory.
        N = op.numargs()
        args = op.getarglist()
        arglocs = [self.make_sure_var_in_reg(op.getarg(i), args)
                                                              for i in range(N)]
        return arglocs

    prepare_op_cond_call_gc_wb_array = prepare_op_cond_call_gc_wb

    def prepare_op_call_malloc_nursery(self, op):
        size_box = op.getarg(0)
        assert isinstance(size_box, ConstInt)
        # hint: try to move unrelated registers away from x0 and x1 now
        self.rm.spill_or_move_registers_before_call([r.x0, r.x1])

        self.rm.force_allocate_reg(op, selected_reg=r.x0)
        t = TempInt()
        self.rm.force_allocate_reg(t, selected_reg=r.x1)

        sizeloc = size_box.getint()
        gc_ll_descr = self.cpu.gc_ll_descr
        gcmap = self.get_gcmap([r.x0, r.x1])
        self.possibly_free_var(t)
        self.assembler.malloc_cond(
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            sizeloc,
            gcmap
            )

    def prepare_op_call_malloc_nursery_varsize_frame(self, op):
        size_box = op.getarg(0)
        assert not isinstance(size_box, ConstInt) # we cannot have a const here!
        # sizeloc must be in a register, but we can free it now
        # (we take care explicitly of conflicts with r0 or r1)
        sizeloc = self.rm.make_sure_var_in_reg(size_box)
        self.rm.spill_or_move_registers_before_call([r.x0, r.x1]) # sizeloc safe
        self.rm.possibly_free_var(size_box)
        #
        self.rm.force_allocate_reg(op, selected_reg=r.x0)
        #
        t = TempInt()
        self.rm.force_allocate_reg(t, selected_reg=r.x1)
        #
        gcmap = self.get_gcmap([r.x0, r.x1])
        self.possibly_free_var(t)
        #
        gc_ll_descr = self.cpu.gc_ll_descr
        self.assembler.malloc_cond_varsize_frame(
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            sizeloc,
            gcmap
            )

    def prepare_op_call_malloc_nursery_varsize(self, op):
        gc_ll_descr = self.cpu.gc_ll_descr
        if not hasattr(gc_ll_descr, 'max_size_of_young_obj'):
            raise Exception("unreachable code")
            # for boehm, this function should never be called
        arraydescr = op.getdescr()
        length_box = op.getarg(2)
        assert not isinstance(length_box, Const) # we cannot have a const here!
        # can only use spill_or_move_registers_before_call() as a hint if
        # we are sure that length_box stays alive and won't be freed now
        # (it should always be the case, see below, but better safe than sorry)
        if self.rm.stays_alive(length_box):
            self.rm.spill_or_move_registers_before_call([r.x0, r.x1])
        # the result will be in r0
        self.rm.force_allocate_reg(op, selected_reg=r.x0)
        # we need r1 as a temporary
        tmp_box = TempVar()
        self.rm.force_allocate_reg(tmp_box, selected_reg=r.x1)
        gcmap = self.get_gcmap([r.x0, r.x1]) # allocate the gcmap *before*
        self.rm.possibly_free_var(tmp_box)
        # length_box always survives: it's typically also present in the
        # next operation that will copy it inside the new array.  It's
        # fine to load it from the stack too, as long as it's != x0, x1.
        lengthloc = self.rm.loc(length_box)
        self.rm.possibly_free_var(length_box)
        #
        itemsize = op.getarg(1).getint()
        maxlength = (gc_ll_descr.max_size_of_young_obj - WORD * 2) / itemsize
        self.assembler.malloc_cond_varsize(
            op.getarg(0).getint(),
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            lengthloc, itemsize, maxlength, gcmap, arraydescr)

    def force_allocate_reg(self, var, forbidden_vars=[], selected_reg=None):
        if var.type == FLOAT:
            return self.vfprm.force_allocate_reg(var, forbidden_vars,
                                                 selected_reg)
        else:
            return self.rm.force_allocate_reg(var, forbidden_vars,
                                              selected_reg)

    def _check_invariants(self):
        self.rm._check_invariants()
        self.vfprm._check_invariants()

    def prepare_bridge(self, inputargs, arglocs, operations, allgcrefs,
                       frame_info):
        operations = self._prepare(inputargs, operations, allgcrefs)
        self._update_bindings(arglocs, inputargs)
        return operations

    def _update_bindings(self, locs, inputargs):
        used = {}
        i = 0
        for loc in locs:
            if loc is None:
                loc = r.fp
            arg = inputargs[i]
            i += 1
            if loc.is_core_reg():
                self.rm.reg_bindings[arg] = loc
                used[loc] = None
            elif loc.is_vfp_reg():
                self.vfprm.reg_bindings[arg] = loc
                used[loc] = None
            else:
                assert loc.is_stack()
                self.frame_manager.bind(arg, loc)

        # XXX combine with x86 code and move to llsupport
        self.rm.free_regs = []
        for reg in self.rm.all_regs:
            if reg not in used:
                self.rm.free_regs.append(reg)
        self.vfprm.free_regs = []
        for reg in self.vfprm.all_regs:
            if reg not in used:
                self.vfprm.free_regs.append(reg)
        # note: we need to make a copy of inputargs because possibly_free_vars
        # is also used on op args, which is a non-resizable list
        self.possibly_free_vars(list(inputargs))
        self.fm.finish_binding()
        self._check_invariants()

    def get_gcmap(self, forbidden_regs=[], noregs=False):
        frame_depth = self.fm.get_frame_depth()
        gcmap = allocate_gcmap(self.assembler,
                        frame_depth, JITFRAME_FIXED_SIZE)
        for box, loc in self.rm.reg_bindings.iteritems():
            if loc in forbidden_regs:
                continue
            if box.type == REF and self.rm.is_still_alive(box):
                assert not noregs
                assert loc.is_core_reg()
                val = self.cpu.all_reg_indexes[loc.value]
                gcmap[val // WORD // 8] |= r_uint(1) << (val % (WORD * 8))
        for box, loc in self.fm.bindings.iteritems():
            if box.type == REF and self.rm.is_still_alive(box):
                assert loc.is_stack()
                val = loc.position + JITFRAME_FIXED_SIZE
                gcmap[val // WORD // 8] |= r_uint(1) << (val % (WORD * 8))
        return gcmap

    def get_final_frame_depth(self):
        return self.frame_manager.get_frame_depth()


def notimplemented(self, op):
    print "[ARM64/regalloc] %s not implemented" % op.getopname()
    raise NotImplementedError(op)

def notimplemented_guard_op(self, op, prevop):
    print "[ARM64/regalloc] %s not implemented" % op.getopname()
    raise NotImplementedError(op)    

def notimplemented_comp_op(self, op, res_in_cc):
    print "[ARM64/regalloc] %s not implemented" % op.getopname()
    raise NotImplementedError(op)    

operations = [notimplemented] * (rop._LAST + 1)
guard_operations = [notimplemented_guard_op] * (rop._LAST + 1)
comp_operations = [notimplemented_comp_op] * (rop._LAST + 1)


for key, value in rop.__dict__.items():
    key = key.lower()
    if key.startswith('_'):
        continue
    methname = 'prepare_op_%s' % key
    if hasattr(Regalloc, methname):
        func = getattr(Regalloc, methname).im_func
        operations[value] = func
    methname = 'prepare_guard_op_%s' % key
    if hasattr(Regalloc, methname):
        func = getattr(Regalloc, methname).im_func
        guard_operations[value] = func
    methname = 'prepare_comp_op_%s' % key
    if hasattr(Regalloc, methname):
        func = getattr(Regalloc, methname).im_func
        comp_operations[value] = func
    
