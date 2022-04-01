
""" Register allocation scheme.
"""

from rpython.jit.backend.llsupport import symbolic
from rpython.jit.backend.llsupport.descr import CallDescr, unpack_arraydescr
from rpython.jit.backend.llsupport.gcmap import allocate_gcmap
from rpython.jit.backend.llsupport.regalloc import (FrameManager, BaseRegalloc,
     RegisterManager, TempVar, compute_vars_longevity, is_comparison_or_ovf_op,
     valid_addressing_size, get_scale, SAVE_DEFAULT_REGS, SAVE_GCREF_REGS,
     SAVE_ALL_REGS)
from rpython.jit.backend.x86 import rx86
from rpython.jit.backend.x86.arch import (WORD, JITFRAME_FIXED_SIZE, IS_X86_32,
    IS_X86_64, DEFAULT_FRAME_BYTES, WIN64)
from rpython.jit.backend.x86.jump import remap_frame_layout_mixed
from rpython.jit.backend.x86.regloc import (FrameLoc, RegLoc, ConstFloatLoc,
    FloatImmedLoc, ImmedLoc, imm, imm0, imm1, ecx, eax, edx, ebx, esi, edi,
    ebp, r8, r9, r10, r11, r12, r13, r14, r15, xmm0, xmm1, xmm2, xmm3, xmm4,
    xmm5, xmm6, xmm7, xmm8, xmm9, xmm10, xmm11, xmm12, xmm13, xmm14,
    X86_64_SCRATCH_REG, X86_64_XMM_SCRATCH_REG)
from rpython.jit.backend.x86.vector_ext import VectorRegallocMixin
from rpython.jit.codewriter import longlong
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp.history import (Const, ConstInt, ConstPtr,
    ConstFloat, INT, REF, FLOAT, VECTOR, TargetToken, AbstractFailDescr)
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.metainterp.resume import AccumInfo
from rpython.rlib import rgc
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rarithmetic import r_longlong, r_uint
from rpython.rtyper.lltypesystem import lltype, rffi, rstr
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.jit.backend.x86.regloc import AddressLoc

def compute_gc_level(calldescr, guard_not_forced=False):
    effectinfo = calldescr.get_extra_info()
    if guard_not_forced:
        return SAVE_ALL_REGS
    elif effectinfo is None or effectinfo.check_can_collect():
        return SAVE_GCREF_REGS
    else:
        return SAVE_DEFAULT_REGS


class X86RegisterManager(RegisterManager):
    box_types = [INT, REF]
    all_regs = [ecx, eax, edx, ebx, esi, edi]
    no_lower_byte_regs = [esi, edi]
    save_around_call_regs = [eax, edx, ecx]
    frame_reg = ebp

    def call_result_location(self, v):
        return eax

    def convert_to_imm(self, c):
        if isinstance(c, ConstInt):
            return imm(c.value)
        elif isinstance(c, ConstPtr):
            if we_are_translated() and c.value and rgc.can_move(c.value):
                not_implemented("convert_to_imm: ConstPtr needs special care")
            return imm(rffi.cast(lltype.Signed, c.value))
        else:
            not_implemented("convert_to_imm: got a %s" % c)

class X86_64_RegisterManager(X86RegisterManager):
    # r11 omitted because it's used as scratch
    all_regs = [ecx, eax, edx, ebx, esi, edi, r8, r9, r10, r12, r13, r14, r15]
    if WIN64:
        all_regs.remove(r13)

    no_lower_byte_regs = []
    save_around_call_regs = [eax, ecx, edx, esi, edi, r8, r9, r10]
    if WIN64:
        save_around_call_regs.remove(esi)
        save_around_call_regs.remove(edi)

class X86XMMRegisterManager(RegisterManager):
    box_types = [FLOAT, INT] # yes INT!
    all_regs = [xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7]
    # we never need lower byte I hope
    save_around_call_regs = all_regs

    def convert_to_imm(self, c):
        adr = self.assembler.datablockwrapper.malloc_aligned(8, 8)
        x = c.getfloatstorage()
        rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE), adr)[0] = x
        return ConstFloatLoc(adr)

    def convert_to_imm_16bytes_align(self, c):
        adr = self.assembler.datablockwrapper.malloc_aligned(16, 16)
        x = c.getfloatstorage()
        y = longlong.ZEROF
        rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE), adr)[0] = x
        rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE), adr)[1] = y
        return ConstFloatLoc(adr)

    def expand_float(self, size, const):
        if size == 4:
            loc = self.expand_single_float(const)
        else:
            loc = self.expand_double_float(const)
        return loc

    def expand_double_float(self, f):
        adr = self.assembler.datablockwrapper.malloc_aligned(16, 16)
        fs = f.getfloatstorage()
        rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE), adr)[0] = fs
        rffi.cast(rffi.CArrayPtr(longlong.FLOATSTORAGE), adr)[1] = fs
        return ConstFloatLoc(adr)

    def expand_single_float(self, f):
        adr = self.assembler.datablockwrapper.malloc_aligned(16, 16)
        fs = rffi.cast(lltype.SingleFloat, f.getfloatstorage())
        rffi.cast(rffi.CArrayPtr(lltype.SingleFloat), adr)[0] = fs
        rffi.cast(rffi.CArrayPtr(lltype.SingleFloat), adr)[1] = fs
        rffi.cast(rffi.CArrayPtr(lltype.SingleFloat), adr)[2] = fs
        rffi.cast(rffi.CArrayPtr(lltype.SingleFloat), adr)[3] = fs
        return ConstFloatLoc(adr)

    def call_result_location(self, v):
        return xmm0

class X86_64_XMMRegisterManager(X86XMMRegisterManager):
    # xmm15 reserved for scratch use
    all_regs = [xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm8, xmm9, xmm10, xmm11, xmm12, xmm13, xmm14]
    save_around_call_regs = all_regs

class X86_64_WIN_XMMRegisterManager(X86_64_XMMRegisterManager):
    # xmm15 reserved for scratch use
    all_regs = [xmm0, xmm1, xmm2, xmm3, xmm4]

class X86FrameManager(FrameManager):
    def __init__(self, base_ofs):
        FrameManager.__init__(self)
        self.base_ofs = base_ofs

    def frame_pos(self, i, box_type):
        return FrameLoc(i, get_ebp_ofs(self.base_ofs, i), box_type)

    @staticmethod
    def frame_size(box_type):
        if IS_X86_32 and box_type == FLOAT:
            return 2
        else:
            return 1

    @staticmethod
    def get_loc_index(loc):
        assert isinstance(loc, FrameLoc)
        return loc.position

if WORD == 4:
    gpr_reg_mgr_cls = X86RegisterManager
    xmm_reg_mgr_cls = X86XMMRegisterManager
elif WORD == 8:
    gpr_reg_mgr_cls = X86_64_RegisterManager
    if WIN64:
        xmm_reg_mgr_cls = X86_64_WIN_XMMRegisterManager
    else:
        xmm_reg_mgr_cls = X86_64_XMMRegisterManager
else:
    raise AssertionError("Word size should be 4 or 8")

gpr_reg_mgr_cls.all_reg_indexes = [-1] * WORD * 2 # eh, happens to be true
for _i, _reg in enumerate(gpr_reg_mgr_cls.all_regs):
    gpr_reg_mgr_cls.all_reg_indexes[_reg.value] = _i


class RegAlloc(BaseRegalloc, VectorRegallocMixin):

    def __init__(self, assembler, translate_support_code=False):
        assert isinstance(translate_support_code, bool)
        # variables that have place in register
        self.assembler = assembler
        self.translate_support_code = translate_support_code
        # to be read/used by the assembler too
        self.jump_target_descr = None
        self.final_jump_op = None
        self.final_jump_op_position = -1

    def _prepare(self, inputargs, operations, allgcrefs):
        from rpython.jit.backend.x86.reghint import X86RegisterHints
        for box in inputargs:
            assert box.get_forwarded() is None
        cpu = self.assembler.cpu
        self.fm = X86FrameManager(cpu.get_baseofs_of_frame_field())
        operations = cpu.gc_ll_descr.rewrite_assembler(cpu, operations,
                                                       allgcrefs)
        # compute longevity of variables
        longevity = compute_vars_longevity(inputargs, operations)
        X86RegisterHints().add_hints(longevity, inputargs, operations)
        self.longevity = longevity
        self.rm = gpr_reg_mgr_cls(self.longevity,
                                  frame_manager = self.fm,
                                  assembler = self.assembler)
        self.xrm = xmm_reg_mgr_cls(self.longevity, frame_manager = self.fm,
                                   assembler = self.assembler)
        return operations

    def prepare_loop(self, inputargs, operations, looptoken, allgcrefs):
        operations = self._prepare(inputargs, operations, allgcrefs)
        self._set_initial_bindings(inputargs, looptoken)
        # note: we need to make a copy of inputargs because possibly_free_vars
        # is also used on op args, which is a non-resizable list
        self.possibly_free_vars(list(inputargs))
        if WORD == 4:       # see redirect_call_assembler()
            self.min_bytes_before_label = 5
        else:
            self.min_bytes_before_label = 13
        return operations

    def prepare_bridge(self, inputargs, arglocs, operations, allgcrefs,
                       frame_info):
        operations = self._prepare(inputargs, operations, allgcrefs)
        self._update_bindings(arglocs, inputargs)
        self.min_bytes_before_label = 0
        return operations

    def ensure_next_label_is_at_least_at_position(self, at_least_position):
        self.min_bytes_before_label = max(self.min_bytes_before_label,
                                          at_least_position)

    def get_final_frame_depth(self):
        return self.fm.get_frame_depth()

    def possibly_free_var(self, var):
        if var.type == FLOAT or var.is_vector():
            self.xrm.possibly_free_var(var)
        else:
            self.rm.possibly_free_var(var)

    def possibly_free_vars_for_op(self, op):
        for i in range(op.numargs()):
            var = op.getarg(i)
            if var is not None: # xxx kludgy
                self.possibly_free_var(var)
        if op.type != 'v':
            self.possibly_free_var(op)

    def possibly_free_vars(self, vars):
        for var in vars:
            if var is not None: # xxx kludgy
                self.possibly_free_var(var)

    def make_sure_var_in_reg(self, var, forbidden_vars=[],
                             selected_reg=None, need_lower_byte=False):
        if var.type == FLOAT or var.is_vector():
            if isinstance(var, ConstFloat):
                return FloatImmedLoc(var.getfloatstorage())
            return self.xrm.make_sure_var_in_reg(var, forbidden_vars,
                                                 selected_reg, need_lower_byte)
        else:
            return self.rm.make_sure_var_in_reg(var, forbidden_vars,
                                                selected_reg, need_lower_byte)

    def force_allocate_reg(self, var, forbidden_vars=[], selected_reg=None,
                           need_lower_byte=False):
        if var.type == FLOAT or var.is_vector():
            return self.xrm.force_allocate_reg(var, forbidden_vars,
                                               selected_reg, need_lower_byte)
        else:
            return self.rm.force_allocate_reg(var, forbidden_vars,
                                              selected_reg, need_lower_byte)

    def force_allocate_reg_or_cc(self, var):
        assert var.type == INT
        if self.next_op_can_accept_cc(self.operations, self.rm.position):
            # hack: return the ebp location to mean "lives in CC".  This
            # ebp will not actually be used, and the location will be freed
            # after the next op as usual.
            self.rm.force_allocate_frame_reg(var)
            return ebp
        else:
            # else, return a regular register (not ebp).
            return self.rm.force_allocate_reg(var, need_lower_byte=True)

    def force_spill_var(self, var):
        if var.type == FLOAT:
            return self.xrm.force_spill_var(var)
        else:
            return self.rm.force_spill_var(var)

    def load_xmm_aligned_16_bytes(self, var, forbidden_vars=[]):
        # Load 'var' in a register; but if it is a constant, we can return
        # a 16-bytes-aligned ConstFloatLoc.
        if isinstance(var, Const):
            return self.xrm.convert_to_imm_16bytes_align(var)
        else:
            return self.xrm.make_sure_var_in_reg(var, forbidden_vars)

    def _update_bindings(self, locs, inputargs):
        # XXX this should probably go to llsupport/regalloc.py
        used = {}
        i = 0
        for loc in locs:
            if loc is None: # xxx bit kludgy
                loc = ebp
            arg = inputargs[i]
            i += 1
            if isinstance(loc, RegLoc):
                if arg.type == FLOAT:
                    self.xrm.reg_bindings[arg] = loc
                    used[loc] = None
                else:
                    if loc is ebp:
                        self.rm.bindings_to_frame_reg[arg] = None
                    else:
                        self.rm.reg_bindings[arg] = loc
                        used[loc] = None
            else:
                self.fm.bind(arg, loc)
        self.rm.free_regs = []
        for reg in self.rm.all_regs:
            if reg not in used:
                self.rm.free_regs.append(reg)
        self.xrm.free_regs = []
        for reg in self.xrm.all_regs:
            if reg not in used:
                self.xrm.free_regs.append(reg)
        self.possibly_free_vars(list(inputargs))
        self.fm.finish_binding()
        self.rm._check_invariants()
        self.xrm._check_invariants()

    def perform(self, op, arglocs, result_loc):
        if not we_are_translated():
            self.assembler.dump('%s <- %s(%s)' % (result_loc, op, arglocs))
        self.assembler.regalloc_perform(op, arglocs, result_loc)

    def perform_llong(self, op, arglocs, result_loc):
        if not we_are_translated():
            self.assembler.dump('%s <- %s(%s)' % (result_loc, op, arglocs))
        self.assembler.regalloc_perform_llong(op, arglocs, result_loc)

    def perform_math(self, op, arglocs, result_loc):
        if not we_are_translated():
            self.assembler.dump('%s <- %s(%s)' % (result_loc, op, arglocs))
        self.assembler.regalloc_perform_math(op, arglocs, result_loc)

    def locs_for_fail(self, guard_op):
        faillocs = [self.loc(arg) for arg in guard_op.getfailargs()]
        descr = guard_op.getdescr()
        if not descr:
            return faillocs
        assert isinstance(descr, AbstractFailDescr)
        if descr.rd_vector_info:
            accuminfo = descr.rd_vector_info
            while accuminfo:
                accuminfo.location = faillocs[accuminfo.getpos_in_failargs()]
                loc = self.loc(accuminfo.getoriginal())
                faillocs[accuminfo.getpos_in_failargs()] = loc
                accuminfo = accuminfo.next()
        return faillocs

    def perform_guard(self, guard_op, arglocs, result_loc):
        faillocs = self.locs_for_fail(guard_op)
        if not we_are_translated():
            if result_loc is not None:
                self.assembler.dump('%s <- %s(%s)' % (result_loc, guard_op,
                                                      arglocs))
            else:
                self.assembler.dump('%s(%s)' % (guard_op, arglocs))
        self.assembler.regalloc_perform_guard(guard_op, faillocs, arglocs,
                                              result_loc,
                                              self.fm.get_frame_depth())
        self.possibly_free_vars(guard_op.getfailargs())

    def perform_discard(self, op, arglocs):
        if not we_are_translated():
            self.assembler.dump('%s(%s)' % (op, arglocs))
        self.assembler.regalloc_perform_discard(op, arglocs)

    def walk_operations(self, inputargs, operations):
        i = 0
        self.operations = operations
        while i < len(operations):
            op = operations[i]
            self.assembler.mc.mark_op(op)
            assert self.assembler.mc._frame_size == DEFAULT_FRAME_BYTES
            self.rm.position = i
            self.xrm.position = i
            if rop.has_no_side_effect(op.opnum) and op not in self.longevity:
                i += 1
                self.possibly_free_vars_for_op(op)
                continue
            if not we_are_translated() and op.getopnum() == rop.FORCE_SPILL:
                self._consider_force_spill(op)
            else:
                oplist[op.getopnum()](self, op)
            self.possibly_free_vars_for_op(op)
            self.rm._check_invariants()
            self.xrm._check_invariants()
            i += 1
        assert not self.rm.reg_bindings
        assert not self.xrm.reg_bindings
        if not we_are_translated():
            self.assembler.mc.UD2()
        self.flush_loop()
        self.assembler.mc.mark_op(None) # end of the loop
        self.operations = None
        for arg in inputargs:
            self.possibly_free_var(arg)

    def flush_loop(self):
        # Force the code to be aligned to a multiple of 16.  Also,
        # rare case: if the loop is too short, or if we are just after
        # a GUARD_NOT_INVALIDATED, we need to make sure we insert enough
        # NOPs.  This is important to ensure that there are enough bytes
        # produced, because GUARD_NOT_INVALIDATED or
        # redirect_call_assembler() will maybe overwrite them.  (In that
        # rare case we don't worry too much about alignment.)
        mc = self.assembler.mc
        current_pos = mc.get_relative_pos()
        target_pos = (current_pos + 15) & ~15
        target_pos = max(target_pos, self.min_bytes_before_label)
        insert_nops = target_pos - current_pos
        assert 0 <= insert_nops <= 15
        for c in mc.MULTIBYTE_NOPs[insert_nops]:
            mc.writechar(c)

    def loc(self, v):
        if v is None: # xxx kludgy
            return None
        if v.type == FLOAT or v.is_vector():
            return self.xrm.loc(v)
        return self.rm.loc(v)

    def load_condition_into_cc(self, box):
        if self.assembler.guard_success_cc == rx86.cond_none:
            self.assembler.test_location(self.loc(box))
            self.assembler.guard_success_cc = rx86.Conditions['NZ']


    def _consider_guard_cc(self, op):
        arg = op.getarg(0)
        self.load_condition_into_cc(arg)
        self.perform_guard(op, [], None)

    consider_guard_true = _consider_guard_cc
    consider_guard_false = _consider_guard_cc
    consider_guard_nonnull = _consider_guard_cc
    consider_guard_isnull = _consider_guard_cc

    def consider_finish(self, op):
        # the frame is in ebp, but we have to point where in the frame is
        # the potential argument to FINISH
        if op.numargs() == 1:
            loc = self.make_sure_var_in_reg(op.getarg(0))
            locs = [loc]
        else:
            locs = []
        self.perform(op, locs, None)

    def consider_guard_no_exception(self, op):
        self.perform_guard(op, [], None)

    def consider_guard_not_invalidated(self, op):
        mc = self.assembler.mc
        n = mc.get_relative_pos(break_basic_block=False)
        self.perform_guard(op, [], None)
        assert n == mc.get_relative_pos(break_basic_block=False)
        # ensure that the next label is at least 5 bytes farther than
        # the current position.  Otherwise, when invalidating the guard,
        # we would overwrite randomly the next label's position.
        self.ensure_next_label_is_at_least_at_position(n + 5)

    def consider_guard_exception(self, op):
        loc = self.rm.make_sure_var_in_reg(op.getarg(0))
        box = TempVar()
        args = op.getarglist()
        loc1 = self.rm.force_allocate_reg(box, args)
        if op in self.longevity:
            # this means, is it ever used
            resloc = self.rm.force_allocate_reg(op, args + [box])
        else:
            resloc = None
        self.perform_guard(op, [loc, loc1], resloc)
        self.rm.possibly_free_var(box)

    def consider_save_exception(self, op):
        resloc = self.rm.force_allocate_reg(op)
        self.perform(op, [], resloc)
    consider_save_exc_class = consider_save_exception

    def consider_restore_exception(self, op):
        args = op.getarglist()
        loc0 = self.rm.make_sure_var_in_reg(op.getarg(0), args)  # exc class
        loc1 = self.rm.make_sure_var_in_reg(op.getarg(1), args)  # exc instance
        self.perform_discard(op, [loc0, loc1])

    consider_guard_no_overflow = consider_guard_no_exception
    consider_guard_overflow    = consider_guard_no_exception
    consider_guard_not_forced  = consider_guard_no_exception

    def consider_guard_value(self, op):
        x = self.make_sure_var_in_reg(op.getarg(0))
        loc = self.assembler.cpu.all_reg_indexes[x.value]
        op.getdescr().make_a_counter_per_value(op, loc)
        y = self.loc(op.getarg(1))
        self.perform_guard(op, [x, y], None)

    def consider_guard_class(self, op):
        assert not isinstance(op.getarg(0), Const)
        x = self.rm.make_sure_var_in_reg(op.getarg(0))
        y = self.loc(op.getarg(1))
        self.perform_guard(op, [x, y], None)

    consider_guard_nonnull_class = consider_guard_class
    consider_guard_gc_type = consider_guard_class

    def consider_guard_is_object(self, op):
        x = self.make_sure_var_in_reg(op.getarg(0))
        tmp_box = TempVar()
        y = self.rm.force_allocate_reg(tmp_box, [op.getarg(0)])
        self.rm.possibly_free_var(tmp_box)
        self.perform_guard(op, [x, y], None)

    def consider_guard_subclass(self, op):
        x = self.make_sure_var_in_reg(op.getarg(0))
        tmp_box = TempVar()
        z = self.rm.force_allocate_reg(tmp_box, [op.getarg(0)])
        y = self.loc(op.getarg(1))
        self.rm.possibly_free_var(tmp_box)
        self.perform_guard(op, [x, y, z], None)

    def _consider_binop_part(self, op, symm=False):
        x = op.getarg(0)
        y = op.getarg(1)
        xloc = self.loc(x)
        argloc = self.loc(y)

        # For symmetrical operations, if x is not in a reg, but y is,
        # and if x lives longer than the current operation while y dies, then
        # swap the role of 'x' and 'y'
        if (symm and not isinstance(xloc, RegLoc) and
                isinstance(argloc, RegLoc)):
            if ((x not in self.rm.longevity or
                    self.rm.longevity[x].last_usage > self.rm.position) and
                    self.rm.longevity[y].last_usage == self.rm.position):
                x, y = y, x
                argloc = self.loc(y)
        #
        args = op.getarglist()
        loc = self.rm.force_result_in_reg(op, x, args)
        return loc, argloc

    def _consider_binop(self, op):
        loc, argloc = self._consider_binop_part(op)
        self.perform(op, [loc, argloc], loc)

    def _consider_binop_symm(self, op):
        loc, argloc = self._consider_binop_part(op, symm=True)
        self.perform(op, [loc, argloc], loc)

    def _consider_lea(self, op):
        x = op.getarg(0)
        loc = self.make_sure_var_in_reg(x)
        # make it possible to have argloc be == loc if x dies
        # (then LEA will not be used, but that's fine anyway)
        self.possibly_free_var(x)
        argloc = self.loc(op.getarg(1))
        resloc = self.force_allocate_reg(op)
        self.perform(op, [loc, argloc], resloc)

    def consider_int_add(self, op):
        y = op.getarg(1)
        if isinstance(y, ConstInt) and rx86.fits_in_32bits(y.value):
            self._consider_lea(op)
        else:
            self._consider_binop_symm(op)

    consider_nursery_ptr_increment = consider_int_add

    def consider_int_sub(self, op):
        y = op.getarg(1)
        if isinstance(y, ConstInt) and rx86.fits_in_32bits(-y.value):
            self._consider_lea(op)
        else:
            self._consider_binop(op)

    consider_int_mul = _consider_binop_symm
    consider_int_and = _consider_binop_symm
    consider_int_or  = _consider_binop_symm
    consider_int_xor = _consider_binop_symm

    consider_int_mul_ovf = _consider_binop_symm
    consider_int_sub_ovf = _consider_binop
    consider_int_add_ovf = _consider_binop_symm

    def consider_uint_mul_high(self, op):
        arg1, arg2 = op.getarglist()
        # should support all cases, but is optimized for (box, const)
        if isinstance(arg1, Const):
            arg1, arg2 = arg2, arg1
        self.rm.make_sure_var_in_reg(arg2, selected_reg=eax)
        l1 = self.loc(arg1)
        # l1 is a register != eax, or stack_bp; or, just possibly, it
        # can be == eax if arg1 is arg2
        assert not isinstance(l1, ImmedLoc)
        assert l1 is not eax or arg1 is arg2
        #
        # eax will be trash after the operation
        self.rm.possibly_free_var(arg2)
        tmpvar = TempVar()
        self.rm.force_allocate_reg(tmpvar, selected_reg=eax)
        self.rm.possibly_free_var(tmpvar)
        #
        self.rm.force_allocate_reg(op, selected_reg=edx)
        self.perform(op, [l1], edx)

    def consider_int_neg(self, op):
        res = self.rm.force_result_in_reg(op, op.getarg(0))
        self.perform(op, [res], res)

    consider_int_invert = consider_int_neg

    def consider_int_signext(self, op):
        argloc = self.loc(op.getarg(0))
        numbytesloc = self.loc(op.getarg(1))
        resloc = self.force_allocate_reg(op)
        self.perform(op, [argloc, numbytesloc], resloc)

    def consider_int_lshift(self, op):
        if isinstance(op.getarg(1), Const):
            loc2 = self.rm.convert_to_imm(op.getarg(1))
        else:
            loc2 = self.rm.make_sure_var_in_reg(op.getarg(1), selected_reg=ecx)
        args = op.getarglist()
        loc1 = self.rm.force_result_in_reg(op, op.getarg(0), args)
        self.perform(op, [loc1, loc2], loc1)

    consider_int_rshift  = consider_int_lshift
    consider_uint_rshift = consider_int_lshift

    def _consider_compop(self, op):
        vx = op.getarg(0)
        vy = op.getarg(1)
        arglocs = [self.loc(vx), self.loc(vy)]
        if (vx in self.rm.reg_bindings or vy in self.rm.reg_bindings or
            isinstance(vx, Const) or isinstance(vy, Const)):
            pass
        else:
            arglocs[0] = self.rm.make_sure_var_in_reg(vx)
        loc = self.force_allocate_reg_or_cc(op)
        self.perform(op, arglocs, loc)

    consider_int_lt = _consider_compop
    consider_int_gt = _consider_compop
    consider_int_ge = _consider_compop
    consider_int_le = _consider_compop
    consider_int_ne = _consider_compop
    consider_int_eq = _consider_compop
    consider_uint_gt = _consider_compop
    consider_uint_lt = _consider_compop
    consider_uint_le = _consider_compop
    consider_uint_ge = _consider_compop
    consider_ptr_eq = consider_instance_ptr_eq = _consider_compop
    consider_ptr_ne = consider_instance_ptr_ne = _consider_compop

    def _consider_float_op(self, op):
        loc1 = self.xrm.loc(op.getarg(1))
        args = op.getarglist()
        loc0 = self.xrm.force_result_in_reg(op, op.getarg(0), args)
        self.perform(op, [loc0, loc1], loc0)

    consider_float_add = _consider_float_op      # xxx could be _symm
    consider_float_sub = _consider_float_op
    consider_float_mul = _consider_float_op      # xxx could be _symm
    consider_float_truediv = _consider_float_op

    def _consider_float_cmp(self, op):
        vx = op.getarg(0)
        vy = op.getarg(1)
        arglocs = [self.loc(vx), self.loc(vy)]
        if not (isinstance(arglocs[0], RegLoc) or
                isinstance(arglocs[1], RegLoc)):
            if isinstance(vx, Const):
                arglocs[1] = self.xrm.make_sure_var_in_reg(vy)
            else:
                arglocs[0] = self.xrm.make_sure_var_in_reg(vx)
        loc = self.force_allocate_reg_or_cc(op)
        self.perform(op, arglocs, loc)

    consider_float_lt = _consider_float_cmp
    consider_float_le = _consider_float_cmp
    consider_float_eq = _consider_float_cmp
    consider_float_ne = _consider_float_cmp
    consider_float_gt = _consider_float_cmp
    consider_float_ge = _consider_float_cmp

    def _consider_float_unary_op(self, op):
        loc0 = self.xrm.force_result_in_reg(op, op.getarg(0))
        self.perform(op, [loc0], loc0)

    consider_float_neg = _consider_float_unary_op
    consider_float_abs = _consider_float_unary_op

    def consider_cast_float_to_int(self, op):
        loc0 = self.xrm.make_sure_var_in_reg(op.getarg(0))
        loc1 = self.rm.force_allocate_reg(op)
        self.perform(op, [loc0], loc1)

    def consider_cast_int_to_float(self, op):
        loc0 = self.rm.make_sure_var_in_reg(op.getarg(0))
        loc1 = self.xrm.force_allocate_reg(op)
        self.perform(op, [loc0], loc1)

    def consider_cast_float_to_singlefloat(self, op):
        loc0 = self.xrm.make_sure_var_in_reg(op.getarg(0))
        loc1 = self.rm.force_allocate_reg(op)
        tmpxvar = TempVar()
        loctmp = self.xrm.force_allocate_reg(tmpxvar)   # may be equal to loc0
        self.xrm.possibly_free_var(tmpxvar)
        self.perform(op, [loc0, loctmp], loc1)

    consider_cast_singlefloat_to_float = consider_cast_int_to_float

    def consider_convert_float_bytes_to_longlong(self, op):
        if longlong.is_64_bit:
            loc0 = self.xrm.make_sure_var_in_reg(op.getarg(0))
            loc1 = self.rm.force_allocate_reg(op)
            self.perform(op, [loc0], loc1)
        else:
            arg0 = op.getarg(0)
            loc0 = self.xrm.loc(arg0)
            loc1 = self.xrm.force_allocate_reg(op, forbidden_vars=[arg0])
            self.perform(op, [loc0], loc1)

    def consider_convert_longlong_bytes_to_float(self, op):
        if longlong.is_64_bit:
            loc0 = self.rm.make_sure_var_in_reg(op.getarg(0))
            loc1 = self.xrm.force_allocate_reg(op)
            self.perform(op, [loc0], loc1)
        else:
            arg0 = op.getarg(0)
            loc0 = self.xrm.make_sure_var_in_reg(arg0)
            loc1 = self.xrm.force_allocate_reg(op, forbidden_vars=[arg0])
            self.perform(op, [loc0], loc1)

    def _consider_llong_binop_xx(self, op):
        # must force both arguments into xmm registers, because we don't
        # know if they will be suitably aligned.  Exception: if the second
        # argument is a constant, we can ask it to be aligned to 16 bytes.
        # xxx some of these operations could be '_symm'.
        args = [op.getarg(1), op.getarg(2)]
        loc1 = self.load_xmm_aligned_16_bytes(args[1])
        loc0 = self.xrm.force_result_in_reg(op, args[0], args)
        self.perform_llong(op, [loc0, loc1], loc0)

    def _consider_llong_eq_ne_xx(self, op):
        # must force both arguments into xmm registers, because we don't
        # know if they will be suitably aligned.  Exception: if they are
        # constants, we can ask them to be aligned to 16 bytes.
        args = [op.getarg(1), op.getarg(2)]
        loc1 = self.load_xmm_aligned_16_bytes(args[0])
        loc2 = self.load_xmm_aligned_16_bytes(args[1], args)
        tmpxvar = TempVar()
        loc3 = self.xrm.force_allocate_reg(tmpxvar, args)
        self.xrm.possibly_free_var(tmpxvar)
        loc0 = self.rm.force_allocate_reg(op, need_lower_byte=True)
        self.perform_llong(op, [loc1, loc2, loc3], loc0)

    def _maybe_consider_llong_lt(self, op):
        # XXX just a special case for now
        box = op.getarg(2)
        if not isinstance(box, ConstFloat):
            return False
        if box.getfloat() != 0.0:    # NaNs are also != 0.0
            return False
        # "x < 0.0" or maybe "x < -0.0" which is the same
        box = op.getarg(1)
        assert box.type == FLOAT
        loc1 = self.xrm.make_sure_var_in_reg(box)
        loc0 = self.rm.force_allocate_reg(op)
        self.perform_llong(op, [loc1], loc0)
        return True

    def _consider_llong_to_int(self, op):
        # accept an argument in a xmm register or in the stack
        loc1 = self.xrm.loc(op.getarg(1))
        loc0 = self.rm.force_allocate_reg(op)
        self.perform_llong(op, [loc1], loc0)

    def _loc_of_const_longlong(self, value64):
        c = ConstFloat(value64)
        return self.xrm.convert_to_imm(c)

    def _consider_llong_from_int(self, op):
        assert IS_X86_32
        loc0 = self.xrm.force_allocate_reg(op)
        box = op.getarg(1)
        if isinstance(box, ConstInt):
            loc1 = self._loc_of_const_longlong(r_longlong(box.value))
            loc2 = None    # unused
        else:
            loc1 = self.rm.make_sure_var_in_reg(box)
            tmpxvar = TempVar()
            loc2 = self.xrm.force_allocate_reg(tmpxvar, [op])
            self.xrm.possibly_free_var(tmpxvar)
        self.perform_llong(op, [loc1, loc2], loc0)

    def _consider_llong_from_uint(self, op):
        assert IS_X86_32
        loc0 = self.xrm.force_allocate_reg(op)
        loc1 = self.rm.make_sure_var_in_reg(op.getarg(1))
        self.perform_llong(op, [loc1], loc0)

    def _consider_math_sqrt(self, op):
        loc0 = self.xrm.force_result_in_reg(op, op.getarg(1))
        self.perform_math(op, [loc0], loc0)

    def _consider_threadlocalref_get(self, op):
        if self.translate_support_code:
            offset = op.getarg(1).getint()   # getarg(0) == 'threadlocalref_get'
            calldescr = op.getdescr()
            size = calldescr.get_result_size()
            sign = calldescr.is_result_signed()
            resloc = self.force_allocate_reg(op)
            self.assembler.threadlocalref_get(offset, resloc, size, sign)
        else:
            self._consider_call(op)

    def _call(self, op, arglocs, gc_level):
        # we need to save registers on the stack:
        #
        #  - at least the non-callee-saved registers
        #    (gc_level == SAVE_DEFAULT_REGS)
        #
        #  - if gc_level == SAVE_GCREF_REGS we save also the callee-saved
        #    registers that contain GC pointers
        #
        #  - gc_level == SAVE_ALL_REGS for CALL_MAY_FORCE or CALL_ASSEMBLER.  We
        #    have to save all regs anyway, in case we need to do
        #    cpu.force().  The issue is that grab_frame_values() would
        #    not be able to locate values in callee-saved registers.
        #
        if gc_level == SAVE_ALL_REGS:
            save_all_regs = SAVE_ALL_REGS
        else:
            save_all_regs = SAVE_DEFAULT_REGS
        self.xrm.before_call(save_all_regs=save_all_regs)
        if gc_level == SAVE_GCREF_REGS:
            gcrootmap = self.assembler.cpu.gc_ll_descr.gcrootmap
            # we save all the GCREF registers for shadowstack
            if gcrootmap: # and gcrootmap.is_shadow_stack:
                save_all_regs = SAVE_GCREF_REGS
        self.rm.before_call(save_all_regs=save_all_regs)
        if op.type != 'v':
            if op.type == FLOAT:
                resloc = self.xrm.after_call(op)
            else:
                resloc = self.rm.after_call(op)
        else:
            resloc = None
        self.perform(op, arglocs, resloc)

    def _consider_call(self, op, guard_not_forced=False, first_arg_index=1):
        calldescr = op.getdescr()
        assert isinstance(calldescr, CallDescr)
        assert len(calldescr.arg_classes) == op.numargs() - first_arg_index
        size = calldescr.get_result_size()
        sign = calldescr.is_result_signed()
        if sign:
            sign_loc = imm1
        else:
            sign_loc = imm0

        gc_level = compute_gc_level(calldescr, guard_not_forced)
        #
        self._call(op, [imm(size), sign_loc] +
                       [self.loc(op.getarg(i)) for i in range(op.numargs())],
                   gc_level=gc_level)

    def _consider_real_call(self, op):
        effectinfo = op.getdescr().get_extra_info()
        assert effectinfo is not None
        oopspecindex = effectinfo.oopspecindex
        if oopspecindex != EffectInfo.OS_NONE:
            if IS_X86_32:
                # support for some of the llong operations,
                # which only exist on x86-32
                if oopspecindex in (EffectInfo.OS_LLONG_ADD,
                                    EffectInfo.OS_LLONG_SUB,
                                    EffectInfo.OS_LLONG_AND,
                                    EffectInfo.OS_LLONG_OR,
                                    EffectInfo.OS_LLONG_XOR):
                    return self._consider_llong_binop_xx(op)
                if oopspecindex == EffectInfo.OS_LLONG_TO_INT:
                    return self._consider_llong_to_int(op)
                if oopspecindex == EffectInfo.OS_LLONG_FROM_INT:
                    return self._consider_llong_from_int(op)
                if oopspecindex == EffectInfo.OS_LLONG_FROM_UINT:
                    return self._consider_llong_from_uint(op)
                if (oopspecindex == EffectInfo.OS_LLONG_EQ or
                    oopspecindex == EffectInfo.OS_LLONG_NE):
                    return self._consider_llong_eq_ne_xx(op)
                if oopspecindex == EffectInfo.OS_LLONG_LT:
                    if self._maybe_consider_llong_lt(op):
                        return
            if oopspecindex == EffectInfo.OS_MATH_SQRT:
                return self._consider_math_sqrt(op)
            if oopspecindex == EffectInfo.OS_THREADLOCALREF_GET:
                return self._consider_threadlocalref_get(op)
            if oopspecindex == EffectInfo.OS_MATH_READ_TIMESTAMP:
                return self._consider_math_read_timestamp(op)
        self._consider_call(op)
    consider_call_i = _consider_real_call
    consider_call_r = _consider_real_call
    consider_call_f = _consider_real_call
    consider_call_n = _consider_real_call

    def _consider_call_may_force(self, op):
        self._consider_call(op, guard_not_forced=True)
    consider_call_may_force_i = _consider_call_may_force
    consider_call_may_force_r = _consider_call_may_force
    consider_call_may_force_f = _consider_call_may_force
    consider_call_may_force_n = _consider_call_may_force

    def _consider_call_release_gil(self, op):
        # [Const(save_err), func_addr, args...]
        self._consider_call(op, guard_not_forced=True, first_arg_index=2)
    consider_call_release_gil_i = _consider_call_release_gil
    consider_call_release_gil_f = _consider_call_release_gil
    consider_call_release_gil_n = _consider_call_release_gil

    def consider_check_memory_error(self, op):
        x = self.rm.make_sure_var_in_reg(op.getarg(0))
        self.perform_discard(op, [x])

    def _consider_call_assembler(self, op):
        locs = self.locs_for_call_assembler(op)
        self._call(op, locs, gc_level=SAVE_ALL_REGS)
    consider_call_assembler_i = _consider_call_assembler
    consider_call_assembler_r = _consider_call_assembler
    consider_call_assembler_f = _consider_call_assembler
    consider_call_assembler_n = _consider_call_assembler

    def consider_cond_call_gc_wb(self, op):
        assert op.type == 'v'
        args = op.getarglist()
        N = len(args)
        # we force all arguments in a reg (unless they are Consts),
        # because it will be needed anyway by the following gc_load
        # It avoids loading it twice from the memory.
        arglocs = [self.rm.make_sure_var_in_reg(op.getarg(i), args)
                   for i in range(N)]
        self.perform_discard(op, arglocs)

    consider_cond_call_gc_wb_array = consider_cond_call_gc_wb

    def consider_cond_call(self, op):
        args = op.getarglist()
        assert 2 <= len(args) <= 4 + 2     # maximum 4 arguments
        v_func = args[1]
        assert isinstance(v_func, Const)
        imm_func = self.rm.convert_to_imm(v_func)

        # Delicate ordering here.  First get the argument's locations.
        # If this also contains args[0], this returns the current
        # location too.
        arglocs = [self.loc(args[i]) for i in range(2, len(args))]

        if op.type == 'v':
            # a plain COND_CALL.  Calls the function when args[0] is
            # true.  Often used just after a comparison operation.
            gcmap = self.get_gcmap()
            self.load_condition_into_cc(op.getarg(0))
            resloc = None
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

            # YYY args[0] is maybe not spilled here!!!
            resloc = self.rm.force_result_in_reg(op, args[0],
                                                 forbidden_vars=args[2:])

            # Get the gcmap here, possibly including the spilled
            # location, and always excluding the 'resloc' register.
            # Some more details: the only interesting case is the case
            # where we're doing the call (if we are not, the gcmap is
            # not used); and in this case, the gcmap must include the
            # spilled location (it contains a valid GC pointer to fix
            # during the call if a GC occurs), and never 'resloc'
            # (it will be overwritten with the result of the call, which
            # is not computed yet if a GC occurs).
            #
            # (Note that the spilled value is always NULL at the moment
            # if the call really occurs, but it's not worth the effort to
            # not list it in the gcmap and get crashes if we tweak
            # COND_CALL_VALUE_R in the future)
            gcmap = self.get_gcmap([resloc])

            # Test the register for the result.
            self.assembler.test_location(resloc)
            self.assembler.guard_success_cc = rx86.Conditions['Z']

        if not we_are_translated():
            self.assembler.dump('%s <- %s(%s)' % (resloc, op, arglocs))
        self.assembler.cond_call(gcmap, imm_func, arglocs, resloc)

    consider_cond_call_value_i = consider_cond_call
    consider_cond_call_value_r = consider_cond_call

    def consider_call_malloc_nursery(self, op):
        # YYY what's the reason for using a fixed register for the result?
        size_box = op.getarg(0)
        assert isinstance(size_box, ConstInt)
        size = size_box.getint()
        # hint: try to move unrelated registers away from ecx and edx now
        self.rm.spill_or_move_registers_before_call([ecx, edx])
        # the result will be in ecx
        self.rm.force_allocate_reg(op, selected_reg=ecx)
        #
        # We need edx as a temporary, but otherwise don't save any more
        # register.  See comments in _build_malloc_slowpath().
        tmp_box = TempVar()
        self.rm.force_allocate_reg(tmp_box, selected_reg=edx)
        gcmap = self.get_gcmap([ecx, edx]) # allocate the gcmap *before*
        self.rm.possibly_free_var(tmp_box)
        #
        gc_ll_descr = self.assembler.cpu.gc_ll_descr
        self.assembler.malloc_cond(
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            size, gcmap)

    def consider_call_malloc_nursery_varsize_frame(self, op):
        size_box = op.getarg(0)
        assert not isinstance(size_box, Const) # we cannot have a const here!
        # sizeloc must be in a register, but we can free it now
        # (we take care explicitly of conflicts with ecx or edx)
        sizeloc = self.rm.make_sure_var_in_reg(size_box)
        self.rm.spill_or_move_registers_before_call([ecx, edx])  # sizeloc safe
        self.rm.possibly_free_var(size_box)
        # the result will be in ecx
        self.rm.force_allocate_reg(op, selected_reg=ecx)
        # we need edx as a temporary
        tmp_box = TempVar()
        self.rm.force_allocate_reg(tmp_box, selected_reg=edx)
        gcmap = self.get_gcmap([ecx, edx]) # allocate the gcmap *before*
        self.rm.possibly_free_var(tmp_box)
        #
        gc_ll_descr = self.assembler.cpu.gc_ll_descr
        self.assembler.malloc_cond_varsize_frame(
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            sizeloc, gcmap)

    def consider_call_malloc_nursery_varsize(self, op):
        gc_ll_descr = self.assembler.cpu.gc_ll_descr
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
            self.rm.spill_or_move_registers_before_call([ecx, edx])
        # the result will be in ecx
        self.rm.force_allocate_reg(op, selected_reg=ecx)
        # we need edx as a temporary
        tmp_box = TempVar()
        self.rm.force_allocate_reg(tmp_box, selected_reg=edx)
        gcmap = self.get_gcmap([ecx, edx]) # allocate the gcmap *before*
        self.rm.possibly_free_var(tmp_box)
        # length_box always survives: it's typically also present in the
        # next operation that will copy it inside the new array.  It's
        # fine to load it from the stack too, as long as it is != ecx, edx.
        lengthloc = self.rm.loc(length_box)
        self.rm.possibly_free_var(length_box)
        #
        itemsize = op.getarg(1).getint()
        maxlength = (gc_ll_descr.max_size_of_young_obj - WORD * 2)
        self.assembler.malloc_cond_varsize(
            op.getarg(0).getint(),
            gc_ll_descr.get_nursery_free_addr(),
            gc_ll_descr.get_nursery_top_addr(),
            lengthloc, itemsize, maxlength, gcmap, arraydescr)

    def get_gcmap(self, forbidden_regs=[], noregs=False):
        frame_depth = self.fm.get_frame_depth()
        gcmap = allocate_gcmap(self.assembler, frame_depth, JITFRAME_FIXED_SIZE)
        for box, loc in self.rm.reg_bindings.iteritems():
            if loc in forbidden_regs:
                continue
            if box.type == REF and self.rm.is_still_alive(box):
                assert not noregs
                assert isinstance(loc, RegLoc)
                val = gpr_reg_mgr_cls.all_reg_indexes[loc.value]
                gcmap[val // WORD // 8] |= r_uint(1) << (val % (WORD * 8))
        for box, loc in self.fm.bindings.iteritems():
            if box.type == REF and self.rm.is_still_alive(box):
                assert isinstance(loc, FrameLoc)
                val = loc.position + JITFRAME_FIXED_SIZE
                gcmap[val // WORD // 8] |= r_uint(1) << (val % (WORD * 8))
        return gcmap

    def consider_gc_store(self, op):
        args = op.getarglist()
        base_loc = self.rm.make_sure_var_in_reg(op.getarg(0), args)
        size_box = op.getarg(3)
        assert isinstance(size_box, ConstInt)
        size = size_box.value
        assert size >= 1
        if size == 1:
            need_lower_byte = True
        else:
            need_lower_byte = False
        value_loc = self.make_sure_var_in_reg(op.getarg(2), args,
                                          need_lower_byte=need_lower_byte)
        ofs_loc = self.rm.make_sure_var_in_reg(op.getarg(1), args)
        self.perform_discard(op, [base_loc, ofs_loc, value_loc,
                                 imm(size)])

    def consider_gc_store_indexed(self, op):
        args = op.getarglist()
        base_loc = self.rm.make_sure_var_in_reg(op.getarg(0), args)
        scale_box = op.getarg(3)
        offset_box = op.getarg(4)
        size_box = op.getarg(5)
        assert isinstance(scale_box, ConstInt)
        assert isinstance(offset_box, ConstInt)
        assert isinstance(size_box, ConstInt)
        factor = scale_box.value
        offset = offset_box.value
        size = size_box.value
        assert size >= 1
        if size == 1:
            need_lower_byte = True
        else:
            need_lower_byte = False
        value_loc = self.make_sure_var_in_reg(op.getarg(2), args,
                                          need_lower_byte=need_lower_byte)
        ofs_loc = self.rm.make_sure_var_in_reg(op.getarg(1), args)
        self.perform_discard(op, [base_loc, ofs_loc, value_loc,
                                  imm(factor), imm(offset), imm(size)])

    def consider_increment_debug_counter(self, op):
        base_loc = self.loc(op.getarg(0))
        self.perform_discard(op, [base_loc])

    def _consider_gc_load(self, op):
        args = op.getarglist()
        base_loc = self.rm.make_sure_var_in_reg(op.getarg(0), args)
        ofs_loc = self.rm.make_sure_var_in_reg(op.getarg(1), args)
        result_loc = self.force_allocate_reg(op)
        size_box = op.getarg(2)
        assert isinstance(size_box, ConstInt)
        nsize = size_box.value      # negative for "signed"
        size_loc = imm(abs(nsize))
        if nsize < 0:
            sign_loc = imm1
        else:
            sign_loc = imm0
        self.perform(op, [base_loc, ofs_loc, size_loc, sign_loc], result_loc)

    consider_gc_load_i = _consider_gc_load
    consider_gc_load_r = _consider_gc_load
    consider_gc_load_f = _consider_gc_load

    def _consider_gc_load_indexed(self, op):
        args = op.getarglist()
        base_loc = self.rm.make_sure_var_in_reg(op.getarg(0), args)
        ofs_loc = self.rm.make_sure_var_in_reg(op.getarg(1), args)
        result_loc = self.force_allocate_reg(op)
        scale_box = op.getarg(2)
        offset_box = op.getarg(3)
        size_box = op.getarg(4)
        assert isinstance(scale_box, ConstInt)
        assert isinstance(offset_box, ConstInt)
        assert isinstance(size_box, ConstInt)
        scale = scale_box.value
        offset = offset_box.value
        nsize = size_box.value      # negative for "signed"
        size_loc = imm(abs(nsize))
        if nsize < 0:
            sign_loc = imm1
        else:
            sign_loc = imm0
        locs = [base_loc, ofs_loc, imm(scale), imm(offset), size_loc, sign_loc]
        self.perform(op, locs, result_loc)

    consider_gc_load_indexed_i = _consider_gc_load_indexed
    consider_gc_load_indexed_r = _consider_gc_load_indexed
    consider_gc_load_indexed_f = _consider_gc_load_indexed

    def consider_int_is_true(self, op):
        # doesn't need arg to be in a register
        argloc = self.loc(op.getarg(0))
        resloc = self.force_allocate_reg_or_cc(op)
        self.perform(op, [argloc], resloc)

    consider_int_is_zero = consider_int_is_true

    def _consider_same_as(self, op):
        argloc = self.loc(op.getarg(0))
        resloc = self.force_allocate_reg(op)
        self.perform(op, [argloc], resloc)
    consider_cast_ptr_to_int = _consider_same_as
    consider_cast_int_to_ptr = _consider_same_as
    consider_same_as_i = _consider_same_as
    consider_same_as_r = _consider_same_as
    consider_same_as_f = _consider_same_as

    def consider_load_from_gc_table(self, op):
        resloc = self.rm.force_allocate_reg(op)
        self.perform(op, [], resloc)

    def consider_int_force_ge_zero(self, op):
        argloc = self.make_sure_var_in_reg(op.getarg(0))
        resloc = self.force_allocate_reg(op, [op.getarg(0)])
        self.perform(op, [argloc], resloc)

    def consider_load_effective_address(self, op):
        p0 = op.getarg(0)
        i0 = op.getarg(1)
        ploc = self.make_sure_var_in_reg(p0, [i0])
        iloc = self.make_sure_var_in_reg(i0, [p0])
        res = self.rm.force_allocate_reg(op, [p0, i0])
        assert isinstance(op.getarg(2), ConstInt)
        assert isinstance(op.getarg(3), ConstInt)
        self.assembler.load_effective_addr(iloc, op.getarg(2).getint(),
            op.getarg(3).getint(), res, ploc)

    def _consider_math_read_timestamp(self, op):
        # hint: try to move unrelated registers away from eax and edx now
        self.rm.spill_or_move_registers_before_call([eax, edx])
        tmpbox_high = TempVar()
        self.rm.force_allocate_reg(tmpbox_high, selected_reg=eax)
        if longlong.is_64_bit:
            # on 64-bit, use rax as temporary register and returns the
            # result in rdx
            result_loc = self.rm.force_allocate_reg(op,
                                                    selected_reg=edx)
            self.perform_math(op, [], result_loc)
        else:
            # on 32-bit, use both eax and edx as temporary registers,
            # use a temporary xmm register, and returns the result in
            # another xmm register.
            tmpbox_low = TempVar()
            self.rm.force_allocate_reg(tmpbox_low, selected_reg=edx)
            xmmtmpbox = TempVar()
            xmmtmploc = self.xrm.force_allocate_reg(xmmtmpbox)
            result_loc = self.xrm.force_allocate_reg(op)
            self.perform_math(op, [xmmtmploc], result_loc)
            self.xrm.possibly_free_var(xmmtmpbox)
            self.rm.possibly_free_var(tmpbox_low)
        self.rm.possibly_free_var(tmpbox_high)

    def compute_hint_frame_locations(self, operations):
        # optimization only: fill in the 'hint_frame_pos' dictionary
        # of 'fm' based on the JUMP at the end of the loop, by looking
        # at where we would like the boxes to be after the jump.
        op = operations[-1]
        if op.getopnum() != rop.JUMP:
            return
        self.final_jump_op = op
        self.final_jump_op_position = len(operations) - 1
        descr = op.getdescr()
        assert isinstance(descr, TargetToken)
        if descr._ll_loop_code != 0:
            # if the target LABEL was already compiled, i.e. if it belongs
            # to some already-compiled piece of code
            self._compute_hint_locations_from_descr(descr)
        #else:
        #   The loop ends in a JUMP going back to a LABEL in the same loop.
        #   We cannot fill 'hint_frame_pos' immediately, but we can
        #   wait until the corresponding consider_label() to know where the
        #   we would like the boxes to be after the jump.
        # YYY can we do coalescing hints in the new register allocation model?

    def _compute_hint_locations_from_descr(self, descr):
        arglocs = descr._x86_arglocs
        jump_op = self.final_jump_op
        assert len(arglocs) == jump_op.numargs()
        hinted = []
        for i in range(jump_op.numargs()):
            box = jump_op.getarg(i)
            if not isinstance(box, Const):
                loc = arglocs[i]
                if isinstance(loc, FrameLoc):
                    self.fm.hint_frame_pos[box] = self.fm.get_loc_index(loc)
                else:
                    if box not in hinted:
                        hinted.append(box)
                        assert isinstance(loc, RegLoc)
                        self.longevity.fixed_register(
                                self.final_jump_op_position,
                                loc, box)

    def consider_jump(self, op):
        assembler = self.assembler
        assert self.jump_target_descr is None
        descr = op.getdescr()
        assert isinstance(descr, TargetToken)
        arglocs = descr._x86_arglocs
        self.jump_target_descr = descr
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
            if box.type != FLOAT and not box.is_vector():
                src_locations1.append(src_loc)
                dst_locations1.append(dst_loc)
            else:
                src_locations2.append(src_loc)
                dst_locations2.append(dst_loc)
        # Do we have a temp var?
        if IS_X86_64:
            tmpreg = X86_64_SCRATCH_REG
            if WIN64:
                # XXX perhaps use this for all_regs and do xmmtmp = None?
                xmmtmp = xmm5
            else:
                xmmtmp = X86_64_XMM_SCRATCH_REG
        else:
            tmpreg = None
            xmmtmp = None
        # Do the remapping
        num_moves = remap_frame_layout_mixed(assembler,
                                 src_locations1, dst_locations1, tmpreg,
                                 src_locations2, dst_locations2, xmmtmp)
        self.possibly_free_vars_for_op(op)
        assembler.closing_jump(self.jump_target_descr)
        assembler.num_moves_jump += num_moves

    def consider_enter_portal_frame(self, op):
        self.assembler.enter_portal_frame(op)

    def consider_leave_portal_frame(self, op):
        self.assembler.leave_portal_frame(op)

    def consider_jit_debug(self, op):
        pass

    def _consider_force_spill(self, op):
        # This operation is used only for testing
        self.force_spill_var(op.getarg(0))

    def consider_force_token(self, op):
        # XXX for now we return a regular reg
        #self.rm.force_allocate_frame_reg(op)
        self.assembler.force_token(self.rm.force_allocate_reg(op))

    def consider_label(self, op):
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
        # we need to make sure that no variable is stored in ebp
        for arg in inputargs:
            if self.loc(arg) is ebp:
                loc2 = self.fm.loc(arg)
                self.assembler.mc.MOV(loc2, ebp)
        self.rm.bindings_to_frame_reg.clear()
        #
        for i in range(len(inputargs)):
            arg = inputargs[i]
            assert not isinstance(arg, Const)
            loc = self.loc(arg)
            assert loc is not ebp
            arglocs[i] = loc
            if isinstance(loc, RegLoc):
                self.fm.mark_as_free(arg)
        #
        # if we are too close to the start of the loop, the label's target may
        # get overridden by redirect_call_assembler().  (rare case)
        self.flush_loop()
        #
        descr._x86_arglocs = arglocs
        descr._ll_loop_code = self.assembler.mc.get_relative_pos()
        descr._x86_clt = self.assembler.current_clt
        self.assembler.target_tokens_currently_compiling[descr] = None
        self.possibly_free_vars_for_op(op)
        self.assembler.label()
        #
        # if the LABEL's descr is precisely the target of the JUMP at the
        # end of the same loop, i.e. if what we are compiling is a single
        # loop that ends up jumping to this LABEL, then we can now provide
        # the hints about the expected position of the spilled variables.
        jump_op = self.final_jump_op
        if jump_op is not None and jump_op.getdescr() is descr:
            self._compute_hint_locations_from_descr(descr)

    def consider_guard_not_forced_2(self, op):
        self.rm.before_call(op.getfailargs(), save_all_regs=True)
        self.xrm.before_call(op.getfailargs(), save_all_regs=True)
        fail_locs = [self.loc(v) for v in op.getfailargs()]
        self.assembler.store_force_descr(op, fail_locs,
                                         self.fm.get_frame_depth())
        self.possibly_free_vars(op.getfailargs())

    def consider_keepalive(self, op):
        pass

    def _scaled_addr(self, index_loc, itemsize_loc,
                                base_loc, ofs_loc):
        assert isinstance(itemsize_loc, ImmedLoc)
        itemsize = itemsize_loc.value
        if isinstance(index_loc, ImmedLoc):
            temp_loc = imm(index_loc.value * itemsize)
            shift = 0
        else:
            assert valid_addressing_size(itemsize), "rewrite did not correctly handle shift/mul!"
            temp_loc = index_loc
            shift = get_scale(itemsize)
        assert isinstance(ofs_loc, ImmedLoc)
        return AddressLoc(base_loc, temp_loc, shift, ofs_loc.value)

    def consider_zero_array(self, op):
        _, baseofs, _ = unpack_arraydescr(op.getdescr())
        length_box = op.getarg(2)

        scale_box = op.getarg(3)
        assert isinstance(scale_box, ConstInt)
        start_itemsize = scale_box.value

        len_scale_box = op.getarg(4)
        assert isinstance(len_scale_box, ConstInt)
        len_itemsize = len_scale_box.value
        # rewrite handles the mul of a constant length box
        constbytes = -1
        if isinstance(length_box, ConstInt):
            constbytes = length_box.getint()
        args = op.getarglist()
        base_loc = self.rm.make_sure_var_in_reg(args[0], args)
        startindex_loc = self.rm.make_sure_var_in_reg(args[1], args)
        if 0 <= constbytes <= 16 * 8:
            if IS_X86_64:
                null_loc = X86_64_XMM_SCRATCH_REG
            else:
                null_box = TempVar()
                null_loc = self.xrm.force_allocate_reg(null_box)
                self.xrm.possibly_free_var(null_box)
            self.perform_discard(op, [base_loc, startindex_loc,
                                      imm(constbytes), imm(start_itemsize),
                                      imm(baseofs), null_loc])
        else:
            # base_loc and startindex_loc are in two regs here (or they are
            # immediates).  Compute the dstaddr_loc, which is the raw
            # address that we will pass as first argument to memset().
            # It can be in the same register as either one, but not in
            # args[2], because we're still needing the latter.
            dstaddr_box = TempVar()
            dstaddr_loc = self.rm.force_allocate_reg(dstaddr_box, [args[2]])
            itemsize_loc = imm(start_itemsize)
            dst_addr = self._scaled_addr(startindex_loc, itemsize_loc,
                                         base_loc, imm(baseofs))
            self.assembler.mc.LEA(dstaddr_loc, dst_addr)
            #
            if constbytes >= 0:
                length_loc = imm(constbytes)
            else:
                # load length_loc in a register different than dstaddr_loc
                length_loc = self.rm.make_sure_var_in_reg(length_box,
                                                          [dstaddr_box])
                if len_itemsize > 1:
                    # we need a register that is different from dstaddr_loc,
                    # but which can be identical to length_loc (as usual,
                    # only if the length_box is not used by future operations)
                    bytes_box = TempVar()
                    bytes_loc = self.rm.force_allocate_reg(bytes_box,
                                                           [dstaddr_box])
                    len_itemsize_loc = imm(len_itemsize)
                    b_adr = self._scaled_addr(length_loc, len_itemsize_loc, imm0, imm0)
                    self.assembler.mc.LEA(bytes_loc, b_adr)
                    length_box = bytes_box
                    length_loc = bytes_loc
            #
            # call memset()
            self.rm.before_call()
            self.xrm.before_call()
            self.assembler.simple_call_no_collect(
                imm(self.assembler.memset_addr),
                [dstaddr_loc, imm0, length_loc])
            self.rm.possibly_free_var(length_box)
            self.rm.possibly_free_var(dstaddr_box)

    def not_implemented_op(self, op):
        not_implemented("not implemented operation: %s" % op.getopname())

oplist = [RegAlloc.not_implemented_op] * rop._LAST

import itertools
iterate = itertools.chain(RegAlloc.__dict__.iteritems(),
                          VectorRegallocMixin.__dict__.iteritems())
for name, value in iterate:
    if name.startswith('consider_'):
        name = name[len('consider_'):]
        num = getattr(rop, name.upper())
        oplist[num] = value

def get_ebp_ofs(base_ofs, position):
    # Argument is a frame position (0, 1, 2...).
    # Returns (ebp+20), (ebp+24), (ebp+28)...
    # i.e. the n'th word beyond the fixed frame size.
    return base_ofs + WORD * (position + JITFRAME_FIXED_SIZE)

def not_implemented(msg):
    msg = '[x86/regalloc] %s\n' % msg
    if we_are_translated():
        llop.debug_print(lltype.Void, msg)
    raise NotImplementedError(msg)
