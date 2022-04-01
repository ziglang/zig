from rpython.jit.backend.ppc.regalloc import (PPCFrameManager,
                                              Regalloc, PPCRegisterManager)
from rpython.jit.backend.ppc.opassembler import OpAssembler
from rpython.jit.backend.ppc.codebuilder import (PPCBuilder, OverwritingBuilder,
                                                 scratch_reg)
from rpython.jit.backend.ppc.arch import (IS_PPC_32, IS_PPC_64, WORD,
                                          LR_BC_OFFSET, REGISTERS_SAVED,
                                          GPR_SAVE_AREA_OFFSET,
                                          THREADLOCAL_ADDR_OFFSET,
                                          STD_FRAME_SIZE_IN_BYTES,
                                          IS_BIG_ENDIAN,
                                          LOCAL_VARS_OFFSET)
from rpython.jit.backend.ppc.helper.assembler import Saved_Volatiles
from rpython.jit.backend.ppc.helper.regalloc import _check_imm_arg
import rpython.jit.backend.ppc.register as r
import rpython.jit.backend.ppc.condition as c
from rpython.jit.metainterp.compile import ResumeGuardDescr
from rpython.jit.backend.ppc.register import JITFRAME_FIXED_SIZE
from rpython.jit.metainterp.history import AbstractFailDescr
from rpython.jit.backend.llsupport import jitframe, rewrite
from rpython.jit.backend.llsupport.asmmemmgr import MachineDataBlockWrapper
from rpython.jit.backend.llsupport.assembler import (DEBUG_COUNTER, debug_bridge,
                                                     BaseAssembler)
from rpython.jit.backend.model import CompiledLoopToken
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory
from rpython.jit.metainterp.resoperation import rop, ResOperation
from rpython.jit.codewriter import longlong
from rpython.jit.metainterp.history import (INT, REF, FLOAT)
from rpython.rlib.debug import (debug_print, debug_start, debug_stop,
                                have_debug_prints)
from rpython.rlib import rgc
from rpython.rtyper.annlowlevel import llhelper, cast_instance_to_gcref
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.jit.backend.ppc.locations import StackLocation, get_fp_offset, imm
from rpython.jit.backend.ppc import callbuilder
from rpython.rlib.jit import AsmInfo
from rpython.rlib.objectmodel import compute_unique_id
from rpython.rlib.rarithmetic import r_uint
from rpython.rlib.rjitlog import rjitlog as jl
from rpython.jit.backend.ppc.jump import remap_frame_layout_mixed

memcpy_fn = rffi.llexternal('memcpy', [llmemory.Address, llmemory.Address,
                                       rffi.SIZE_T], lltype.Void,
                            sandboxsafe=True, _nowrapper=True)

DEBUG_COUNTER = lltype.Struct('DEBUG_COUNTER', ('i', lltype.Signed),
                              ('type', lltype.Char),  # 'b'ridge, 'l'abel or
                                                      # 'e'ntry point
                              ('number', lltype.Signed))
def hi(w):
    return w >> 16

def ha(w):
    if (w >> 15) & 1:
        return (w >> 16) + 1
    else:
        return w >> 16

def lo(w):
    return w & 0x0000FFFF

def la(w):
    v = w & 0x0000FFFF
    if v & 0x8000:
        return -((v ^ 0xFFFF) + 1) # "sign extend" to 32 bits
    return v

def highest(w):
    return w >> 48

def higher(w):
    return (w >> 32) & 0x0000FFFF

def high(w):
    return (w >> 16) & 0x0000FFFF

class JitFrameTooDeep(Exception):
    pass

class AssemblerPPC(OpAssembler, BaseAssembler):

    #ENCODING_AREA               = FORCE_INDEX_OFS
    #OFFSET_SPP_TO_GPR_SAVE_AREA = (FORCE_INDEX + FLOAT_INT_CONVERSION
    #                               + ENCODING_AREA)
    #OFFSET_SPP_TO_FPR_SAVE_AREA = (OFFSET_SPP_TO_GPR_SAVE_AREA
    #                               + GPR_SAVE_AREA)
    #OFFSET_SPP_TO_OLD_BACKCHAIN = (OFFSET_SPP_TO_GPR_SAVE_AREA
    #                               + GPR_SAVE_AREA + FPR_SAVE_AREA)

    #OFFSET_STACK_ARGS = OFFSET_SPP_TO_OLD_BACKCHAIN + BACKCHAIN_SIZE * WORD
    #if IS_PPC_64:
    #    OFFSET_STACK_ARGS += MAX_REG_PARAMS * WORD

    def __init__(self, cpu, translate_support_code=False):
        BaseAssembler.__init__(self, cpu, translate_support_code)
        self.loop_run_counters = []
        self.wb_slowpath = [0, 0, 0, 0, 0]
        self.setup_failure_recovery()
        self.stack_check_slowpath = 0
        self.propagate_exception_path = 0
        self.teardown()

    def set_debug(self, v):
        self._debug = v

    def _save_nonvolatiles(self):
        """ save nonvolatile GPRs and FPRs in SAVE AREA 
        """
        for i, reg in enumerate(NONVOLATILES):
            # save r31 later on
            if reg.value == r.SPP.value:
                continue
            self.mc.store(reg.value, r.SPP.value, 
                          self.OFFSET_SPP_TO_GPR_SAVE_AREA + WORD * i)
        for i, reg in enumerate(NONVOLATILES_FLOAT):
            self.mc.stfd(reg.value, r.SPP.value, 
                         self.OFFSET_SPP_TO_FPR_SAVE_AREA + WORD * i)

    def _restore_nonvolatiles(self, mc, spp_reg):
        """ restore nonvolatile GPRs and FPRs from SAVE AREA
        """
        for i, reg in enumerate(NONVOLATILES):
            mc.load(reg.value, spp_reg.value, 
                         self.OFFSET_SPP_TO_GPR_SAVE_AREA + WORD * i)
        for i, reg in enumerate(NONVOLATILES_FLOAT):
            mc.lfd(reg.value, spp_reg.value,
                        self.OFFSET_SPP_TO_FPR_SAVE_AREA + WORD * i)

    def _call_header_shadowstack(self, gcrootmap):
        # we need to put one word into the shadowstack: the jitframe (SPP)
        mc = self.mc
        diff = mc.load_imm_plus(r.RCS1, gcrootmap.get_root_stack_top_addr())
        mc.load(r.RCS2.value, r.RCS1.value, diff) # ld RCS2, [rootstacktop]
        #
        mc.addi(r.RCS3.value, r.RCS2.value, WORD) # add RCS3, RCS2, WORD
        mc.store(r.SPP.value, r.RCS2.value, 0)    # std SPP, RCS2
        #
        mc.store(r.RCS3.value, r.RCS1.value, diff)# std RCS3, [rootstacktop]

    def _call_footer_shadowstack(self, gcrootmap):
        mc = self.mc
        diff = mc.load_imm_plus(r.RCS1, gcrootmap.get_root_stack_top_addr())
        mc.load(r.RCS2.value, r.RCS1.value, diff)  # ld RCS2, [rootstacktop]
        mc.subi(r.RCS2.value, r.RCS2.value, WORD)  # sub RCS2, RCS2, WORD
        mc.store(r.RCS2.value, r.RCS1.value, diff) # std RCS2, [rootstacktop]

    def new_stack_loc(self, i, tp):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        return StackLocation(i, get_fp_offset(base_ofs, i), tp)

    def setup_failure_recovery(self):
        self.failure_recovery_code = [0, 0, 0, 0]

    def _push_core_regs_to_jitframe(self, mc, includes=r.MANAGED_REGS):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        for reg in includes:
            v = r.ALL_REG_INDEXES[reg]
            mc.std(reg.value, r.SPP.value, base_ofs + v * WORD)

    def _push_fp_regs_to_jitframe(self, mc, includes=r.MANAGED_FP_REGS):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        for reg in includes:
            v = r.ALL_REG_INDEXES[reg]
            mc.stfd(reg.value, r.SPP.value, base_ofs + v * WORD)

    def _pop_core_regs_from_jitframe(self, mc, includes=r.MANAGED_REGS):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        for reg in includes:
            v = r.ALL_REG_INDEXES[reg]
            mc.ld(reg.value, r.SPP.value, base_ofs + v * WORD)

    def _pop_fp_regs_from_jitframe(self, mc, includes=r.MANAGED_FP_REGS):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        for reg in includes:
            v = r.ALL_REG_INDEXES[reg]
            mc.lfd(reg.value, r.SPP.value, base_ofs + v * WORD)

    def _build_failure_recovery(self, exc, withfloats=False):
        mc = PPCBuilder()
        self.mc = mc

        # fill in the jf_descr and jf_gcmap fields of the frame according
        # to which failure we are resuming from.  These are set before
        # this function is called (see generate_quick_failure()).
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        ofs2 = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.store(r.r0.value, r.SPP.value, ofs)
        mc.store(r.r2.value, r.SPP.value, ofs2)

        self._push_core_regs_to_jitframe(mc)
        if withfloats:
            self._push_fp_regs_to_jitframe(mc)

        if exc:
            # We might have an exception pending.
            mc.load_imm(r.r2, self.cpu.pos_exc_value())
            # Copy it into 'jf_guard_exc'
            offset = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            mc.load(r.r0.value, r.r2.value, 0)
            mc.store(r.r0.value, r.SPP.value, offset)
            # Zero out the exception fields
            diff = self.cpu.pos_exception() - self.cpu.pos_exc_value()
            assert _check_imm_arg(diff)
            mc.li(r.r0.value, 0)
            mc.store(r.r0.value, r.r2.value, 0)
            mc.store(r.r0.value, r.r2.value, diff)

        # now we return from the complete frame, which starts from
        # _call_header_with_stack_check().  The _call_footer below does it.
        self._call_footer()
        rawstart = mc.materialize(self.cpu, [])
        self.failure_recovery_code[exc + 2 * withfloats] = rawstart
        self.mc = None

    def build_frame_realloc_slowpath(self):
        mc = PPCBuilder()
        self.mc = mc

        # signature of this _frame_realloc_slowpath function:
        #   * on entry, r0 is the new size
        #   * on entry, r2 is the gcmap
        #   * no managed register must be modified

        ofs2 = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.store(r.r2.value, r.SPP.value, ofs2)

        self._push_core_regs_to_jitframe(mc)
        self._push_fp_regs_to_jitframe(mc)

        # Save away the LR inside r30
        mc.mflr(r.RCS1.value)

        # First argument is SPP (= r31), which is the jitframe
        mc.mr(r.r3.value, r.SPP.value)

        # Second argument is the new size, which is still in r0 here
        mc.mr(r.r4.value, r.r0.value)

        # This trashes r0 and r2
        self._store_and_reset_exception(mc, r.RCS2, r.RCS3)

        # Do the call
        adr = rffi.cast(lltype.Signed, self.cpu.realloc_frame)
        mc.load_imm(mc.RAW_CALL_REG, adr)
        mc.raw_call()

        # The result is stored back into SPP (= r31)
        mc.mr(r.SPP.value, r.r3.value)

        self._restore_exception(mc, r.RCS2, r.RCS3)

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            diff = mc.load_imm_plus(r.r5, gcrootmap.get_root_stack_top_addr())
            mc.load(r.r5.value, r.r5.value, diff)
            mc.store(r.r3.value, r.r5.value, -WORD)

        mc.mtlr(r.RCS1.value)     # restore LR
        self._pop_core_regs_from_jitframe(mc)
        self._pop_fp_regs_from_jitframe(mc)
        mc.blr()

        self._frame_realloc_slowpath = mc.materialize(self.cpu, [])
        self.mc = None

    def _store_and_reset_exception(self, mc, excvalloc, exctploc=None):
        """Reset the exception, after fetching it inside the two regs.
        """
        mc.load_imm(r.r2, self.cpu.pos_exc_value())
        diff = self.cpu.pos_exception() - self.cpu.pos_exc_value()
        assert _check_imm_arg(diff)
        # Load the exception fields into the two registers
        mc.load(excvalloc.value, r.r2.value, 0)
        if exctploc is not None:
            mc.load(exctploc.value, r.r2.value, diff)
        # Zero out the exception fields
        mc.li(r.r0.value, 0)
        mc.store(r.r0.value, r.r2.value, 0)
        mc.store(r.r0.value, r.r2.value, diff)

    def _restore_exception(self, mc, excvalloc, exctploc):
        mc.load_imm(r.r2, self.cpu.pos_exc_value())
        diff = self.cpu.pos_exception() - self.cpu.pos_exc_value()
        assert _check_imm_arg(diff)
        # Store the exception fields from the two registers
        mc.store(excvalloc.value, r.r2.value, 0)
        mc.store(exctploc.value, r.r2.value, diff)

    def _reload_frame_if_necessary(self, mc, shadowstack_reg=None):
        # might trash the VOLATILE registers different from r3 and f1
        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap:
            if gcrootmap.is_shadow_stack:
                if shadowstack_reg is None:
                    diff = mc.load_imm_plus(r.SPP,
                                            gcrootmap.get_root_stack_top_addr())
                    mc.load(r.SPP.value, r.SPP.value, diff)
                    shadowstack_reg = r.SPP
                mc.load(r.SPP.value, shadowstack_reg.value, -WORD)
        wbdescr = self.cpu.gc_ll_descr.write_barrier_descr
        if gcrootmap and wbdescr:
            # frame never uses card marking, so we enforce this is not
            # an array
            self._write_barrier_fastpath(mc, wbdescr, [r.SPP], regalloc=None,
                                         array=False, is_frame=True)

    def _build_cond_call_slowpath(self, supports_floats, callee_only):
        """ This builds a general call slowpath, for whatever call happens to
        come.
        """
        # signature of these cond_call_slowpath functions:
        #   * on entry, r12 contains the function to call
        #   * r3, r4, r5, r6 contain arguments for the call
        #   * r2 is the gcmap
        #   * the old value of these regs must already be stored in the jitframe
        #   * on exit, all registers are restored from the jitframe
        #   * the result of the call, if any, is moved to r2

        mc = PPCBuilder()
        self.mc = mc
        ofs2 = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.store(r.r2.value, r.SPP.value, ofs2)

        # copy registers to the frame, with the exception of r3 to r6 and r12,
        # because these have already been saved by the caller.  Note that
        # this is not symmetrical: these 5 registers are saved by the caller
        # but restored here at the end of this function.
        if callee_only:
            saved_regs = PPCRegisterManager.save_around_call_regs
        else:
            saved_regs = PPCRegisterManager.all_regs
        self._push_core_regs_to_jitframe(mc, [reg for reg in saved_regs
                                              if reg is not r.r3 and
                                                 reg is not r.r4 and
                                                 reg is not r.r5 and
                                                 reg is not r.r6 and
                                                 reg is not r.r12])
        if supports_floats:
            self._push_fp_regs_to_jitframe(mc)

        # Save away the LR inside r30
        mc.mflr(r.RCS1.value)

        # Do the call
        mc.raw_call(r.r12)

        # Finish
        self._reload_frame_if_necessary(mc)

        # Move the result, if any, to r2
        mc.mr(r.SCRATCH2.value, r.r3.value)

        mc.mtlr(r.RCS1.value)     # restore LR

        self._pop_core_regs_from_jitframe(mc, saved_regs)
        if supports_floats:
            self._pop_fp_regs_from_jitframe(mc)
        mc.blr()
        self.mc = None
        return mc.materialize(self.cpu, [])

    def _build_malloc_slowpath(self, kind):
        """ While arriving on slowpath, we have a gcmap in r2.
        The arguments are passed in r.RES and r.RSZ, as follows:

        kind == 'fixed': nursery_head in r.RES and the size in r.RSZ - r.RES.

        kind == 'str/unicode': length of the string to allocate in r.RES.

        kind == 'var': itemsize in r.RES, length to allocate in r.RSZ,
                       and tid in r.SCRATCH.

        This function must preserve all registers apart from r.RES and r.RSZ.
        On return, r2 must contain the address of nursery_free.
        """
        assert kind in ['fixed', 'str', 'unicode', 'var']
        mc = PPCBuilder()
        self.mc = mc
        ofs2 = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.store(r.r2.value, r.SPP.value, ofs2)
        saved_regs = [reg for reg in r.MANAGED_REGS
                          if reg is not r.RES and reg is not r.RSZ]
        self._push_core_regs_to_jitframe(mc, saved_regs)
        self._push_fp_regs_to_jitframe(mc)
        #
        if kind == 'fixed':
            addr = self.cpu.gc_ll_descr.get_malloc_slowpath_addr()
        elif kind == 'str':
            addr = self.cpu.gc_ll_descr.get_malloc_fn_addr('malloc_str')
        elif kind == 'unicode':
            addr = self.cpu.gc_ll_descr.get_malloc_fn_addr('malloc_unicode')
        else:
            addr = self.cpu.gc_ll_descr.get_malloc_slowpath_array_addr()

        # Save away the LR inside r30
        mc.mflr(r.RCS1.value)

        if kind == 'fixed':
            # compute the size we want
            mc.subf(r.r3.value, r.RES.value, r.RSZ.value)
            if hasattr(self.cpu.gc_ll_descr, 'passes_frame'):
                # for tests only
                mc.mr(r.r4.value, r.SPP.value)
        elif kind == 'str' or kind == 'unicode':
            pass  # length is already in r3
        else:
            # arguments to the called function are [itemsize, tid, length]
            # itemsize is already in r3
            mc.mr(r.r5.value, r.RSZ.value)       # length
            mc.mr(r.r4.value, r.SCRATCH.value)   # tid

        # Do the call
        addr = rffi.cast(lltype.Signed, addr)
        mc.load_imm(mc.RAW_CALL_REG, addr)
        mc.raw_call()

        self._reload_frame_if_necessary(mc)

        # Check that we don't get NULL; if we do, we always interrupt the
        # current loop, as a "good enough" approximation (same as
        # emit_call_malloc_gc()).
        self.propagate_memoryerror_if_reg_is_null(r.r3)

        mc.mtlr(r.RCS1.value)     # restore LR
        self._pop_core_regs_from_jitframe(mc, saved_regs)
        self._pop_fp_regs_from_jitframe(mc)

        nursery_free_adr = self.cpu.gc_ll_descr.get_nursery_free_addr()
        self.mc.load_imm(r.r2, nursery_free_adr)

        # r2 is now the address of nursery_free
        # r.RES is still the result of the call done above
        # r.RSZ is loaded from [r2], to make the caller's store a no-op here
        mc.load(r.RSZ.value, r.r2.value, 0)
        #
        mc.blr()
        self.mc = None
        return mc.materialize(self.cpu, [])

    def _build_stack_check_slowpath(self):
        _, _, slowpathaddr = self.cpu.insert_stack_check()
        if slowpathaddr == 0 or not self.cpu.propagate_exception_descr:
            return      # no stack check (for tests, or non-translated)
        #
        # make a regular function that is called from a point near the start
        # of an assembler function (after it adjusts the stack and saves
        # registers).
        mc = PPCBuilder()
        #
        # Save away the LR inside r30
        mc.mflr(r.RCS1.value)
        #
        # Do the call
        # use SP as single parameter for the call
        mc.mr(r.r3.value, r.SP.value)
        mc.load_imm(mc.RAW_CALL_REG, slowpathaddr)
        mc.raw_call()
        #
        # Restore LR
        mc.mtlr(r.RCS1.value)
        #
        # Check if it raised StackOverflow
        mc.load_imm(r.SCRATCH, self.cpu.pos_exception())
        mc.loadx(r.SCRATCH.value, 0, r.SCRATCH.value)
        # if this comparison is true, then everything is ok,
        # else we have an exception
        mc.cmp_op(0, r.SCRATCH.value, 0, imm=True)
        #
        # So we return to LR back to our caller, conditionally if "EQ"
        mc.beqlr()
        #
        # Else, jump to propagate_exception_path
        assert self.propagate_exception_path
        mc.b_abs(self.propagate_exception_path)
        #
        rawstart = mc.materialize(self.cpu, [])
        self.stack_check_slowpath = rawstart

    def _build_wb_slowpath(self, withcards, withfloats=False, for_frame=False):
        descr = self.cpu.gc_ll_descr.write_barrier_descr
        if descr is None:
            return
        if not withcards:
            func = descr.get_write_barrier_fn(self.cpu)
        else:
            if descr.jit_wb_cards_set == 0:
                return
            func = descr.get_write_barrier_from_array_fn(self.cpu)
            if func == 0:
                return
        #
        # This builds a helper function called from the slow path of
        # write barriers.  It must save all registers, and optionally
        # all fp registers.  It takes its single argument in r0
        # (or in SPP if 'for_frame').
        if for_frame:
            argument_loc = r.SPP
        else:
            argument_loc = r.r0

        mc = PPCBuilder()
        old_mc = self.mc
        self.mc = mc

        extra_stack_size = LOCAL_VARS_OFFSET + 4 * WORD + 8
        extra_stack_size = (extra_stack_size + 15) & ~15
        if for_frame:
            # NOTE: don't save registers on the jitframe here!  It might
            # override already-saved values that will be restored
            # later...
            #
            # This 'for_frame' version is called after a CALL.  It does not
            # need to save many registers: the registers that are anyway
            # destroyed by the call can be ignored (VOLATILES), and the
            # non-volatile registers won't be changed here.  It only needs
            # to save r.RCS1 (used below), r3 and f1 (possible results of
            # the call), and two more non-volatile registers (used to store
            # the RPython exception that occurred in the CALL, if any).
            #
            # We need to increase our stack frame size a bit to store them.
            #
            self.mc.load(r.SCRATCH.value, r.SP.value, 0)    # SP back chain
            self.mc.store_update(r.SCRATCH.value, r.SP.value, -extra_stack_size)
            self.mc.std(r.RCS1.value, r.SP.value, LOCAL_VARS_OFFSET + 0 * WORD)
            self.mc.std(r.RCS2.value, r.SP.value, LOCAL_VARS_OFFSET + 1 * WORD)
            self.mc.std(r.RCS3.value, r.SP.value, LOCAL_VARS_OFFSET + 2 * WORD)
            self.mc.std(r.r3.value,   r.SP.value, LOCAL_VARS_OFFSET + 3 * WORD)
            self.mc.stfd(r.f1.value,  r.SP.value, LOCAL_VARS_OFFSET + 4 * WORD)
            saved_regs = None
            saved_fp_regs = None

        else:
            # push all volatile registers, push RCS1, and sometimes push RCS2
            if withcards:
                saved_regs = r.VOLATILES + [r.RCS1, r.RCS2]
            else:
                saved_regs = r.VOLATILES + [r.RCS1]
            if withfloats:
                saved_fp_regs = r.MANAGED_FP_REGS
            else:
                saved_fp_regs = []

            self._push_core_regs_to_jitframe(mc, saved_regs)
            self._push_fp_regs_to_jitframe(mc, saved_fp_regs)

        if for_frame:
            # note that it's safe to store the exception in register,
            # since the call to write barrier can't collect
            # (and this is assumed a bit left and right here, like lack
            # of _reload_frame_if_necessary)
            # This trashes r0 and r2, which is fine in this case
            assert argument_loc is not r.r0
            self._store_and_reset_exception(mc, r.RCS2, r.RCS3)

        if withcards:
            mc.mr(r.RCS2.value, argument_loc.value)
        #
        # Save the lr into r.RCS1
        mc.mflr(r.RCS1.value)
        #
        func = rffi.cast(lltype.Signed, func)
        # Note: if not 'for_frame', argument_loc is r0, which must carefully
        # not be overwritten above
        mc.mr(r.r3.value, argument_loc.value)
        mc.load_imm(mc.RAW_CALL_REG, func)
        mc.raw_call()
        #
        # Restore lr
        mc.mtlr(r.RCS1.value)

        if for_frame:
            self._restore_exception(mc, r.RCS2, r.RCS3)

        if withcards:
            # A final andix before the blr, for the caller.  Careful to
            # not follow this instruction with another one that changes
            # the status of cr0!
            card_marking_mask = descr.jit_wb_cards_set_singlebyte
            mc.lbz(r.RCS2.value, r.RCS2.value, descr.jit_wb_if_flag_byteofs)
            mc.andix(r.RCS2.value, r.RCS2.value, card_marking_mask & 0xFF)

        if for_frame:
            self.mc.ld(r.RCS1.value, r.SP.value, LOCAL_VARS_OFFSET + 0 * WORD)
            self.mc.ld(r.RCS2.value, r.SP.value, LOCAL_VARS_OFFSET + 1 * WORD)
            self.mc.ld(r.RCS3.value, r.SP.value, LOCAL_VARS_OFFSET + 2 * WORD)
            self.mc.ld(r.r3.value,   r.SP.value, LOCAL_VARS_OFFSET + 3 * WORD)
            self.mc.lfd(r.f1.value,  r.SP.value, LOCAL_VARS_OFFSET + 4 * WORD)
            self.mc.addi(r.SP.value, r.SP.value, extra_stack_size)

        else:
            self._pop_core_regs_from_jitframe(mc, saved_regs)
            self._pop_fp_regs_from_jitframe(mc, saved_fp_regs)

        mc.blr()

        self.mc = old_mc
        rawstart = mc.materialize(self.cpu, [])
        if for_frame:
            self.wb_slowpath[4] = rawstart
        else:
            self.wb_slowpath[withcards + 2 * withfloats] = rawstart

    def _build_propagate_exception_path(self):
        self.mc = PPCBuilder()
        #
        # read and reset the current exception

        propagate_exception_descr = rffi.cast(lltype.Signed,
                  cast_instance_to_gcref(self.cpu.propagate_exception_descr))
        ofs3 = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
        ofs4 = self.cpu.get_ofs_of_frame_field('jf_descr')

        self._store_and_reset_exception(self.mc, r.r3)
        self.mc.load_imm(r.r4, propagate_exception_descr)
        self.mc.std(r.r3.value, r.SPP.value, ofs3)
        self.mc.std(r.r4.value, r.SPP.value, ofs4)
        #
        self._call_footer()
        rawstart = self.mc.materialize(self.cpu, [])
        self.propagate_exception_path = rawstart
        self.mc = None

    def _call_header(self):
        if IS_PPC_64 and IS_BIG_ENDIAN:
            # Reserve space for a function descriptor, 3 words
            self.mc.write64(0)
            self.mc.write64(0)
            self.mc.write64(0)

        # Build a new stackframe of size STD_FRAME_SIZE_IN_BYTES
        self.mc.store_update(r.SP.value, r.SP.value, -STD_FRAME_SIZE_IN_BYTES)
        self.mc.mflr(r.SCRATCH.value)
        self.mc.store(r.SCRATCH.value, r.SP.value,
                      STD_FRAME_SIZE_IN_BYTES + LR_BC_OFFSET)

        # save registers r25 to r31
        for i, reg in enumerate(REGISTERS_SAVED):
            self.mc.store(reg.value, r.SP.value,
                          GPR_SAVE_AREA_OFFSET + i * WORD)

        # save r4, the second argument, to THREADLOCAL_ADDR_OFFSET
        self.mc.store(r.r4.value, r.SP.value, THREADLOCAL_ADDR_OFFSET)

        # move r3, the first argument, to r31 (SPP): the jitframe object
        self.mc.mr(r.SPP.value, r.r3.value)

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self._call_header_shadowstack(gcrootmap)

    def _call_header_with_stack_check(self):
        self._call_header()
        if self.stack_check_slowpath == 0:
            pass            # not translated
        else:
            endaddr, lengthaddr, _ = self.cpu.insert_stack_check()
            diff = lengthaddr - endaddr
            assert _check_imm_arg(diff)

            mc = self.mc
            mc.load_imm(r.SCRATCH, self.stack_check_slowpath)
            mc.load_imm(r.SCRATCH2, endaddr)                 # li r2, endaddr
            mc.mtctr(r.SCRATCH.value)
            mc.load(r.SCRATCH.value, r.SCRATCH2.value, 0)    # ld r0, [end]
            mc.load(r.SCRATCH2.value, r.SCRATCH2.value, diff)# ld r2, [length]
            mc.subf(r.SCRATCH.value, r.SP.value, r.SCRATCH.value)  # sub r0, SP
            mc.cmp_op(0, r.SCRATCH.value, r.SCRATCH2.value, signed=False)
            mc.bgtctrl()

    def _call_footer(self):
        # the return value is the jitframe
        self.mc.mr(r.r3.value, r.SPP.value)

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self._call_footer_shadowstack(gcrootmap)

        # restore registers r25 to r31
        for i, reg in enumerate(REGISTERS_SAVED):
            self.mc.load(reg.value, r.SP.value,
                         GPR_SAVE_AREA_OFFSET + i * WORD)

        # load the return address into r4
        self.mc.load(r.r4.value, r.SP.value,
                     STD_FRAME_SIZE_IN_BYTES + LR_BC_OFFSET)

        # throw away the stack frame and return to r4
        self.mc.addi(r.SP.value, r.SP.value, STD_FRAME_SIZE_IN_BYTES)
        self.mc.mtlr(r.r4.value)     # restore LR
        self.mc.blr()

    def setup(self, looptoken):
        BaseAssembler.setup(self, looptoken)
        assert self.memcpy_addr != 0, "setup_once() not called?"
        self.current_clt = looptoken.compiled_loop_token
        self.pending_guard_tokens = []
        self.pending_guard_tokens_recovered = 0
        #if WORD == 8:
        #    self.pending_memoryerror_trampoline_from = []
        #    self.error_trampoline_64 = 0
        self.mc = PPCBuilder()
        #assert self.datablockwrapper is None --- but obscure case
        # possible, e.g. getting MemoryError and continuing
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        self.datablockwrapper = MachineDataBlockWrapper(self.cpu.asmmemmgr,
                                                        allblocks)
        self.target_tokens_currently_compiling = {}
        self.frame_depth_to_patch = []

    def update_frame_depth(self, frame_depth):
        if frame_depth > 0x7fff:
            raise JitFrameTooDeep     # XXX
        baseofs = self.cpu.get_baseofs_of_frame_field()
        self.current_clt.frame_info.update_frame_depth(baseofs, frame_depth)

    def patch_stack_checks(self, frame_depth):
        if frame_depth > 0x7fff:
            raise JitFrameTooDeep     # XXX
        for traps_pos, jmp_target in self.frame_depth_to_patch:
            pmc = OverwritingBuilder(self.mc, traps_pos, 3)
            # three traps, so exactly three instructions to patch here
            pmc.cmpdi(0, r.r2.value, frame_depth)         # 1
            pmc.bc(7, 0, jmp_target - (traps_pos + 4))    # 2   "bge+"
            pmc.li(r.r0.value, frame_depth)               # 3
            pmc.overwrite()

    def _check_frame_depth(self, mc, gcmap):
        """ check if the frame is of enough depth to follow this bridge.
        Otherwise reallocate the frame in a helper.
        """
        descrs = self.cpu.gc_ll_descr.getframedescrs(self.cpu)
        ofs = self.cpu.unpack_fielddescr(descrs.arraydescr.lendescr)
        mc.ld(r.r2.value, r.SPP.value, ofs)
        patch_pos = mc.currpos()
        mc.trap()     # placeholder for cmpdi(0, r2, ...)
        mc.trap()     # placeholder for bge
        mc.trap()     # placeholder for li(r0, ...)
        mc.load_imm(r.SCRATCH2, self._frame_realloc_slowpath)
        mc.mtctr(r.SCRATCH2.value)
        self.load_gcmap(mc, r.r2, gcmap)
        mc.bctrl()

        self.frame_depth_to_patch.append((patch_pos, mc.currpos()))

    @rgc.no_release_gil
    def assemble_loop(self, jd_id, unique_id, logger, loopname, inputargs,
                      operations, looptoken, log):
        clt = CompiledLoopToken(self.cpu, looptoken.number)
        looptoken.compiled_loop_token = clt
        clt._debug_nbargs = len(inputargs)
        if not we_are_translated():
            # Arguments should be unique
            assert len(set(inputargs)) == len(inputargs)

        self.setup(looptoken)
        frame_info = self.datablockwrapper.malloc_aligned(
            jitframe.JITFRAMEINFO_SIZE, alignment=WORD)
        clt.frame_info = rffi.cast(jitframe.JITFRAMEINFOPTR, frame_info)
        clt.frame_info.clear() # for now

        if log:
            operations = self._inject_debugging_code(looptoken, operations,
                                                     'e', looptoken.number)

        regalloc = Regalloc(assembler=self)
        #
        self._call_header_with_stack_check()
        allgcrefs = []
        operations = regalloc.prepare_loop(inputargs, operations,
                                           looptoken, allgcrefs)
        self.reserve_gcref_table(allgcrefs)
        looppos = self.mc.get_relative_pos()
        frame_depth_no_fixed_size = self._assemble(regalloc, inputargs,
                                                   operations)
        self.update_frame_depth(frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE)
        #
        size_excluding_failure_stuff = self.mc.get_relative_pos()
        self.write_pending_failure_recoveries(regalloc)
        full_size = self.mc.get_relative_pos()
        #
        self.patch_stack_checks(frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE)
        rawstart = self.materialize_loop(looptoken)
        if IS_PPC_64 and IS_BIG_ENDIAN:  # fix the function descriptor (3 words)
            rffi.cast(rffi.LONGP, rawstart)[0] = rawstart + 3 * WORD
        #
        looptoken._ll_loop_code = looppos + rawstart
        debug_start("jit-backend-addr")
        debug_print("Loop %d (%s) has address 0x%x to 0x%x (bootstrap 0x%x)" % (
            looptoken.number, loopname,
            r_uint(rawstart + looppos),
            r_uint(rawstart + size_excluding_failure_stuff),
            r_uint(rawstart)))
        debug_stop("jit-backend-addr")
        self.patch_gcref_table(looptoken, rawstart)
        self.patch_pending_failure_recoveries(rawstart)
        #
        ops_offset = self.mc.ops_offset
        if not we_are_translated():
            # used only by looptoken.dump() -- useful in tests
            looptoken._ppc_rawstart = rawstart
            looptoken._ppc_fullsize = full_size
            looptoken._ppc_ops_offset = ops_offset
        looptoken._ll_function_addr = rawstart

        if logger:
            log = logger.log_trace(jl.MARK_TRACE_ASM, None, self.mc)
            log.write(inputargs, operations, ops_offset=ops_offset)

            # legacy
            if logger.logger_ops:
                logger.logger_ops.log_loop(inputargs, operations, 0,
                                           "rewritten", name=loopname,
                                           ops_offset=ops_offset)

        self.fixup_target_tokens(rawstart)
        self.teardown()
        # oprofile support
        #if self.cpu.profile_agent is not None:
        #    name = "Loop # %s: %s" % (looptoken.number, loopname)
        #    self.cpu.profile_agent.native_code_written(name,
        #                                               rawstart, full_size)
        #print(hex(rawstart))
        #import pdb; pdb.set_trace()
        return AsmInfo(ops_offset, rawstart + looppos,
                       size_excluding_failure_stuff - looppos, rawstart + looppos)

    def _assemble(self, regalloc, inputargs, operations):
        self._regalloc = regalloc
        self.guard_success_cc = c.cond_none
        regalloc.compute_hint_frame_locations(operations)
        regalloc.walk_operations(inputargs, operations)
        assert self.guard_success_cc == c.cond_none
        if 1: # we_are_translated() or self.cpu.dont_keepalive_stuff:
            self._regalloc = None   # else keep it around for debugging
        frame_depth = regalloc.get_final_frame_depth()
        jump_target_descr = regalloc.jump_target_descr
        if jump_target_descr is not None:
            tgt_depth = jump_target_descr._ppc_clt.frame_info.jfi_frame_depth
            target_frame_depth = tgt_depth - JITFRAME_FIXED_SIZE
            frame_depth = max(frame_depth, target_frame_depth)
        return frame_depth

    @rgc.no_release_gil
    def assemble_bridge(self, faildescr, inputargs, operations,
                        original_loop_token, log, logger):
        if not we_are_translated():
            # Arguments should be unique
            assert len(set(inputargs)) == len(inputargs)

        self.setup(original_loop_token)
        descr_number = compute_unique_id(faildescr)
        if log:
            operations = self._inject_debugging_code(faildescr, operations,
                                                     'b', descr_number)

        arglocs = self.rebuild_faillocs_from_descr(faildescr, inputargs)
        regalloc = Regalloc(assembler=self)
        allgcrefs = []
        operations = regalloc.prepare_bridge(inputargs, arglocs,
                                             operations,
                                             allgcrefs,
                                             self.current_clt.frame_info)
        self.reserve_gcref_table(allgcrefs)
        startpos = self.mc.get_relative_pos()

        self._update_at_exit(arglocs, inputargs, faildescr, regalloc)

        self._check_frame_depth(self.mc, regalloc.get_gcmap())
        frame_depth_no_fixed_size = self._assemble(regalloc, inputargs, operations)
        codeendpos = self.mc.get_relative_pos()
        self.write_pending_failure_recoveries(regalloc)
        fullsize = self.mc.get_relative_pos()
        #
        self.patch_stack_checks(frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE)
        rawstart = self.materialize_loop(original_loop_token)
        debug_bridge(descr_number, rawstart, codeendpos)
        self.patch_gcref_table(original_loop_token, rawstart)
        self.patch_pending_failure_recoveries(rawstart)
        # patch the jump from original guard
        self.patch_jump_for_descr(faildescr, rawstart)
        ops_offset = self.mc.ops_offset
        frame_depth = max(self.current_clt.frame_info.jfi_frame_depth,
                          frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE)

        if logger:
            log = logger.log_trace(jl.MARK_TRACE_ASM, None, self.mc)
            log.write(inputargs, operations, ops_offset)
            # log that the already written bridge is stitched to a descr!
            logger.log_patch_guard(descr_number, rawstart)

            # legacy
            if logger.logger_ops:
                logger.logger_ops.log_bridge(inputargs, operations, "rewritten",
                                          faildescr, ops_offset=ops_offset)

        self.fixup_target_tokens(rawstart)
        self.update_frame_depth(frame_depth)
        self.teardown()
        return AsmInfo(ops_offset, startpos + rawstart, codeendpos - startpos,
                       startpos + rawstart)

    def reserve_gcref_table(self, allgcrefs):
        # allocate the gc table right now.  We write absolute loads in
        # each load_from_gc_table instruction for now.  XXX improve,
        # but it's messy.
        self.gc_table_addr = self.datablockwrapper.malloc_aligned(
                len(allgcrefs) * WORD, alignment=WORD)
        self.setup_gcrefs_list(allgcrefs)

    def patch_gcref_table(self, looptoken, rawstart):
        rawstart = self.gc_table_addr
        tracer = self.cpu.gc_ll_descr.make_gcref_tracer(rawstart,
                                                        self._allgcrefs)
        gcreftracers = self.get_asmmemmgr_gcreftracers(looptoken)
        gcreftracers.append(tracer)    # keepalive
        self.teardown_gcrefs_list()

    def teardown(self):
        self.pending_guard_tokens = None
        self.mc = None
        self.current_clt = None

    def _find_failure_recovery_bytecode(self, faildescr):
        return faildescr._failure_recovery_code_adr

    def fixup_target_tokens(self, rawstart):
        for targettoken in self.target_tokens_currently_compiling:
            targettoken._ll_loop_code += rawstart
        self.target_tokens_currently_compiling = None

    def target_arglocs(self, looptoken):
        return looptoken._ppc_arglocs

    def materialize_loop(self, looptoken):
        self.datablockwrapper.done()
        self.datablockwrapper = None
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        start = self.mc.materialize(self.cpu, allblocks,
                                    self.cpu.gc_ll_descr.gcrootmap)
        return start

    def load_gcmap(self, mc, reg, gcmap):
        # load the current gcmap into register 'reg'
        ptr = rffi.cast(lltype.Signed, gcmap)
        mc.load_imm(reg, ptr)

    def push_gcmap(self, mc, gcmap, store=True):
        # (called from callbuilder.py and ../llsupport/callbuilder.py)
        assert store is True
        self.load_gcmap(mc, r.SCRATCH, gcmap)
        ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.store(r.SCRATCH.value, r.SPP.value, ofs)

    def break_long_loop(self, regalloc):
        # If the loop is too long, the guards in it will jump forward
        # more than 32 KB.  We use an approximate hack to know if we
        # should break the loop here with an unconditional "b" that
        # jumps over the target code.
        jmp_pos = self.mc.currpos()
        self.mc.trap()

        self.write_pending_failure_recoveries(regalloc)

        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_pos, 1)
        pmc.b(currpos - jmp_pos)
        pmc.overwrite()

    def generate_quick_failure(self, guardtok, regalloc):
        startpos = self.mc.currpos()
        # accum vecopt
        self._update_at_exit(guardtok.fail_locs, guardtok.failargs,
                             guardtok.faildescr, regalloc)
        pos = self.mc.currpos()
        guardtok.rel_recovery_prefix = pos - startpos
        faildescrindex, target = self.store_info_on_descr(startpos, guardtok)
        assert target != 0
        self.mc.load_imm(r.r2, target)
        self.mc.mtctr(r.r2.value)
        self._load_from_gc_table(r.r0, r.r2, faildescrindex)
        self.load_gcmap(self.mc, r.r2, gcmap=guardtok.gcmap)   # preserves r0
        self.mc.bctr()
        # we need to write at least 6 insns here, for patch_jump_for_descr()
        while self.mc.currpos() < startpos + 6 * 4:
            self.mc.trap()
        return startpos

    def write_pending_failure_recoveries(self, regalloc):
        # for each pending guard, generate the code of the recovery stub
        # at the end of self.mc.
        for i in range(self.pending_guard_tokens_recovered,
                       len(self.pending_guard_tokens)):
            tok = self.pending_guard_tokens[i]
            tok.pos_recovery_stub = self.generate_quick_failure(tok, regalloc)
        self.pending_guard_tokens_recovered = len(self.pending_guard_tokens)

    def patch_pending_failure_recoveries(self, rawstart):
        assert (self.pending_guard_tokens_recovered ==
                len(self.pending_guard_tokens))
        clt = self.current_clt
        for tok in self.pending_guard_tokens:
            addr = rawstart + tok.pos_jump_offset
            #
            # XXX see patch_jump_for_descr()
            tok.faildescr.adr_jump_offset = rawstart + tok.pos_recovery_stub + tok.rel_recovery_prefix
            #
            relative_target = tok.pos_recovery_stub - tok.pos_jump_offset
            #
            if not tok.guard_not_invalidated():
                mc = PPCBuilder()
                mc.b_cond_offset(relative_target, tok.fcond)
                mc.copy_to_raw_memory(addr)
            else:
                # GUARD_NOT_INVALIDATED, record an entry in
                # clt.invalidate_positions of the form:
                #     (addr-in-the-code-of-the-not-yet-written-jump-target,
                #      relative-target-to-use)
                relpos = tok.pos_jump_offset
                clt.invalidate_positions.append((rawstart + relpos,
                                                 relative_target))

    def patch_jump_for_descr(self, faildescr, adr_new_target):
        # 'faildescr.adr_jump_offset' is the address of an instruction that is a
        # conditional jump.  We must patch this conditional jump to go
        # to 'adr_new_target'.  If the target is too far away, we can't
        # patch it inplace, and instead we patch the quick failure code
        # (which should be at least 6 instructions, so enough).
        # --- XXX for now we always use the second solution ---
        mc = PPCBuilder()
        mc.b_abs(adr_new_target)
        mc.copy_to_raw_memory(faildescr.adr_jump_offset)
        assert faildescr.adr_jump_offset != 0
        faildescr.adr_jump_offset = 0    # means "patched"

    def get_asmmemmgr_blocks(self, looptoken):
        clt = looptoken.compiled_loop_token
        if clt.asmmemmgr_blocks is None:
            clt.asmmemmgr_blocks = []
        return clt.asmmemmgr_blocks

    def regalloc_mov(self, prev_loc, loc):
        if prev_loc.is_imm():
            value = prev_loc.getint()
            # move immediate value to register
            if loc.is_reg():
                self.mc.load_imm(loc, value)
                return
            # move immediate value to memory
            elif loc.is_stack():
                with scratch_reg(self.mc):
                    offset = loc.value
                    self.mc.load_imm(r.SCRATCH, value)
                    self.mc.store(r.SCRATCH.value, r.SPP.value, offset)
                return
            assert 0, "not supported location"
        elif prev_loc.is_stack():
            offset = prev_loc.value
            # move from memory to register
            if loc.is_reg():
                reg = loc.value
                self.mc.load(reg, r.SPP.value, offset)
                return
            # move in memory
            elif loc.is_stack():
                target_offset = loc.value
                with scratch_reg(self.mc):
                    self.mc.load(r.SCRATCH.value, r.SPP.value, offset)
                    self.mc.store(r.SCRATCH.value, r.SPP.value, target_offset)
                return
            # move from memory to fp register
            elif loc.is_fp_reg():
                assert prev_loc.type == FLOAT, 'source not float location'
                reg = loc.value
                self.mc.lfd(reg, r.SPP.value, offset)
                return
            assert 0, "not supported location"
        elif prev_loc.is_vector_reg():
            assert loc.is_vector_reg()
            self.mc.vmr(loc.value, prev_loc.value, prev_loc.value)
            return
        elif prev_loc.is_reg():
            reg = prev_loc.value
            # move to another register
            if loc.is_reg():
                other_reg = loc.value
                self.mc.mr(other_reg, reg)
                return
            # move to memory
            elif loc.is_stack():
                offset = loc.value
                self.mc.store(reg, r.SPP.value, offset)
                return
            assert 0, "not supported location"
        elif prev_loc.is_imm_float():
            value = prev_loc.getint()
            # move immediate value to fp register
            if loc.is_fp_reg():
                with scratch_reg(self.mc):
                    self.mc.load_imm(r.SCRATCH, value)
                    self.mc.lfdx(loc.value, 0, r.SCRATCH.value)
                return
            # move immediate value to memory
            elif loc.is_stack():
                with scratch_reg(self.mc):
                    offset = loc.value
                    self.mc.load_imm(r.SCRATCH, value)
                    self.mc.lfdx(r.FP_SCRATCH.value, 0, r.SCRATCH.value)
                    self.mc.stfd(r.FP_SCRATCH.value, r.SPP.value, offset)
                return
            assert 0, "not supported location"
        elif prev_loc.is_fp_reg():
            reg = prev_loc.value
            # move to another fp register
            if loc.is_fp_reg():
                other_reg = loc.value
                self.mc.fmr(other_reg, reg)
                return
            # move from fp register to memory
            elif loc.is_stack():
                assert loc.type == FLOAT, "target not float location"
                offset = loc.value
                self.mc.stfd(reg, r.SPP.value, offset)
                return
            assert 0, "not supported location"
        assert 0, "not supported location"
    mov_loc_loc = regalloc_mov

    def regalloc_push(self, loc, already_pushed):
        """Pushes the value stored in loc to the stack
        Can trash the current value of SCRATCH when pushing a stack
        loc"""
        assert IS_PPC_64, 'needs to updated for ppc 32'

        index = WORD * (~already_pushed)

        if loc.type == FLOAT:
            if not loc.is_fp_reg():
                self.regalloc_mov(loc, r.FP_SCRATCH)
                loc = r.FP_SCRATCH
            self.mc.stfd(loc.value, r.SP.value, index)
        else:
            if not loc.is_core_reg():
                self.regalloc_mov(loc, r.SCRATCH)
                loc = r.SCRATCH
            self.mc.std(loc.value, r.SP.value, index)

    def regalloc_pop(self, loc, already_pushed):
        """Pops the value on top of the stack to loc. Can trash the current
        value of SCRATCH when popping to a stack loc"""
        assert IS_PPC_64, 'needs to updated for ppc 32'

        index = WORD * (~already_pushed)

        if loc.type == FLOAT:
            if loc.is_fp_reg():
                self.mc.lfd(loc.value, r.SP.value, index)
            else:
                self.mc.lfd(r.FP_SCRATCH.value, r.SP.value, index)
                self.regalloc_mov(r.FP_SCRATCH, loc)
        else:
            if loc.is_core_reg():
                self.mc.ld(loc.value, r.SP.value, index)
            else:
                self.mc.ld(r.SCRATCH.value, r.SP.value, index)
                self.regalloc_mov(r.SCRATCH, loc)

    def malloc_cond(self, nursery_free_adr, nursery_top_adr, size, gcmap):
        assert size & (WORD-1) == 0     # must be correctly aligned

        # We load into RES the address stored at nursery_free_adr. We
        # calculate the new value for nursery_free_adr and store it in
        # RSZ.  Then we load the address stored in nursery_top_adr
        # into SCRATCH.  In the rare case where the value in RSZ is
        # (unsigned) bigger than the one in SCRATCH we call
        # malloc_slowpath.  In the common case where malloc_slowpath
        # is not called, we must still write RSZ back into
        # nursery_free_adr (r2); so we do it always, even if we called
        # malloc_slowpath.

        diff = nursery_top_adr - nursery_free_adr
        assert _check_imm_arg(diff)
        mc = self.mc
        mc.load_imm(r.r2, nursery_free_adr)

        mc.load(r.RES.value, r.r2.value, 0)         # load nursery_free
        mc.load(r.SCRATCH.value, r.r2.value, diff)  # load nursery_top

        if _check_imm_arg(size):
            mc.addi(r.RSZ.value, r.RES.value, size)
        else:
            mc.load_imm(r.RSZ, size)
            mc.add(r.RSZ.value, r.RES.value, r.RSZ.value)

        mc.cmp_op(0, r.RSZ.value, r.SCRATCH.value, signed=False)

        fast_jmp_pos = mc.currpos()
        mc.trap()        # conditional jump, patched later

        # new value of nursery_free_adr in RSZ and the adr of the new object
        # in RES.
        self.load_gcmap(mc, r.r2, gcmap)
        # We are jumping to malloc_slowpath without a call through a function
        # descriptor, because it is an internal call and "call" would trash
        # r2 and r11
        mc.bl_abs(self.malloc_slowpath)

        offset = mc.currpos() - fast_jmp_pos
        pmc = OverwritingBuilder(mc, fast_jmp_pos, 1)
        pmc.bc(7, 1, offset)    # jump if LE (not GT), predicted to be true
        pmc.overwrite()

        mc.store(r.RSZ.value, r.r2.value, 0)    # store into nursery_free

    def malloc_cond_varsize_frame(self, nursery_free_adr, nursery_top_adr,
                                  sizeloc, gcmap):
        diff = nursery_top_adr - nursery_free_adr
        assert _check_imm_arg(diff)
        mc = self.mc
        mc.load_imm(r.r2, nursery_free_adr)

        if sizeloc is r.RES:
            mc.mr(r.RSZ.value, r.RES.value)
            sizeloc = r.RSZ

        mc.load(r.RES.value, r.r2.value, 0)         # load nursery_free
        mc.load(r.SCRATCH.value, r.r2.value, diff)  # load nursery_top

        mc.add(r.RSZ.value, r.RES.value, sizeloc.value)

        mc.cmp_op(0, r.RSZ.value, r.SCRATCH.value, signed=False)

        fast_jmp_pos = mc.currpos()
        mc.trap()        # conditional jump, patched later

        # new value of nursery_free_adr in RSZ and the adr of the new object
        # in RES.
        self.load_gcmap(mc, r.r2, gcmap)
        mc.bl_abs(self.malloc_slowpath)

        offset = mc.currpos() - fast_jmp_pos
        pmc = OverwritingBuilder(mc, fast_jmp_pos, 1)
        pmc.bc(7, 1, offset)    # jump if LE (not GT), predicted to be true
        pmc.overwrite()

        mc.store(r.RSZ.value, r.r2.value, 0)    # store into nursery_free

    def malloc_cond_varsize(self, kind, nursery_free_adr, nursery_top_adr,
                            lengthloc, itemsize, maxlength, gcmap,
                            arraydescr):
        from rpython.jit.backend.llsupport.descr import ArrayDescr
        assert isinstance(arraydescr, ArrayDescr)

        # lengthloc is the length of the array, which we must not modify!
        assert lengthloc is not r.RES and lengthloc is not r.RSZ
        assert lengthloc.is_reg()

        if maxlength > 2**16-1:
            maxlength = 2**16-1      # makes things easier
        mc = self.mc
        mc.cmp_op(0, lengthloc.value, maxlength, imm=True, signed=False)

        jmp_adr0 = mc.currpos()
        mc.trap()       # conditional jump, patched later

        # ------------------------------------------------------------
        # block of code for the case: the length is <= maxlength

        diff = nursery_top_adr - nursery_free_adr
        assert _check_imm_arg(diff)
        mc.load_imm(r.r2, nursery_free_adr)

        varsizeloc = self._multiply_by_constant(lengthloc, itemsize,
                                                r.RSZ)
        # varsizeloc is either RSZ here, or equal to lengthloc if
        # itemsize == 1.  It is the size of the variable part of the
        # array, in bytes.

        mc.load(r.RES.value, r.r2.value, 0)         # load nursery_free
        mc.load(r.SCRATCH.value, r.r2.value, diff)  # load nursery_top

        assert arraydescr.basesize >= self.gc_minimal_size_in_nursery
        constsize = arraydescr.basesize + self.gc_size_of_header
        force_realignment = (itemsize % WORD) != 0
        if force_realignment:
            constsize += WORD - 1
        mc.addi(r.RSZ.value, varsizeloc.value, constsize)
        if force_realignment:
            # "& ~(WORD-1)"
            bit_limit = 60 if WORD == 8 else 61
            mc.rldicr(r.RSZ.value, r.RSZ.value, 0, bit_limit)

        mc.add(r.RSZ.value, r.RES.value, r.RSZ.value)
        # now RSZ contains the total size in bytes, rounded up to a multiple
        # of WORD, plus nursery_free_adr

        mc.cmp_op(0, r.RSZ.value, r.SCRATCH.value, signed=False)

        jmp_adr1 = mc.currpos()
        mc.trap()        # conditional jump, patched later

        # ------------------------------------------------------------
        # block of code for two cases: either the length is > maxlength
        # (jump from jmp_adr0), or the length is small enough but there
        # is not enough space in the nursery (fall-through)
        #
        offset = mc.currpos() - jmp_adr0
        pmc = OverwritingBuilder(mc, jmp_adr0, 1)
        pmc.bgt(offset)    # jump if GT
        pmc.overwrite()
        #
        # save the gcmap
        self.load_gcmap(mc, r.r2, gcmap)
        #
        # load the function to call into CTR
        if kind == rewrite.FLAG_ARRAY:
            addr = self.malloc_slowpath_varsize
        elif kind == rewrite.FLAG_STR:
            addr = self.malloc_slowpath_str
        elif kind == rewrite.FLAG_UNICODE:
            addr = self.malloc_slowpath_unicode
        else:
            raise AssertionError(kind)
        mc.load_imm(r.SCRATCH, addr)
        mc.mtctr(r.SCRATCH.value)
        #
        # load the argument(s)
        if kind == rewrite.FLAG_ARRAY:
            mc.mr(r.RSZ.value, lengthloc.value)
            mc.load_imm(r.RES, itemsize)
            mc.load_imm(r.SCRATCH, arraydescr.tid)
        else:
            mc.mr(r.RES.value, lengthloc.value)
        #
        # call!
        mc.bctrl()

        jmp_location = mc.currpos()
        mc.trap()      # jump forward, patched later

        # ------------------------------------------------------------
        # block of code for the common case: the length is <= maxlength
        # and there is enough space in the nursery

        offset = mc.currpos() - jmp_adr1
        pmc = OverwritingBuilder(mc, jmp_adr1, 1)
        pmc.ble(offset)    # jump if LE
        pmc.overwrite()
        #
        # write down the tid, but only in this case (not in other cases
        # where r.RES is the result of the CALL)
        mc.load_imm(r.SCRATCH, arraydescr.tid)
        mc.store(r.SCRATCH.value, r.RES.value, 0)
        # while we're at it, this line is not needed if we've done the CALL
        mc.store(r.RSZ.value, r.r2.value, 0)    # store into nursery_free

        # ------------------------------------------------------------

        offset = mc.currpos() - jmp_location
        pmc = OverwritingBuilder(mc, jmp_location, 1)
        pmc.b(offset)    # jump always
        pmc.overwrite()

    def propagate_memoryerror_if_reg_is_null(self, reg_loc):
        self.mc.cmp_op(0, reg_loc.value, 0, imm=True)
        self.mc.b_cond_abs(self.propagate_exception_path, c.EQ)

    def write_new_force_index(self):
        # for shadowstack only: get a new, unused force_index number and
        # write it to FORCE_INDEX_OFS.  Used to record the call shape
        # (i.e. where the GC pointers are in the stack) around a CALL
        # instruction that doesn't already have a force_index.
        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            clt = self.current_clt
            force_index = clt.reserve_and_record_some_faildescr_index()
            self._write_fail_index(force_index)
            return force_index
        else:
            return 0

    def _write_fail_index(self, fail_index):
        with scratch_reg(self.mc):
            self.mc.load_imm(r.SCRATCH, fail_index)
            self.mc.store(r.SCRATCH.value, r.SPP.value, FORCE_INDEX_OFS)

    def stitch_bridge(self, faildescr, target):
        """ Stitching means that one can enter a bridge with a complete different register
            allocation. This needs remapping which is done here for both normal registers
            and accumulation registers.
        """
        asminfo, bridge_faildescr, version, looptoken = target
        assert isinstance(bridge_faildescr, ResumeGuardDescr)
        assert isinstance(faildescr, ResumeGuardDescr)
        assert asminfo.rawstart != 0
        self.mc = PPCBuilder()
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        self.datablockwrapper = MachineDataBlockWrapper(self.cpu.asmmemmgr,
                                                   allblocks)
        frame_info = self.datablockwrapper.malloc_aligned(
            jitframe.JITFRAMEINFO_SIZE, alignment=WORD)

        # if accumulation is saved at the guard, we need to update it here!
        guard_locs = self.rebuild_faillocs_from_descr(faildescr, version.inputargs)
        bridge_locs = self.rebuild_faillocs_from_descr(bridge_faildescr, version.inputargs)
        guard_accum_info = faildescr.rd_vector_info
        # O(n**2), but usually you only have at most 1 fail argument
        while guard_accum_info:
            bridge_accum_info = bridge_faildescr.rd_vector_info
            while bridge_accum_info:
                if bridge_accum_info.failargs_pos == guard_accum_info.failargs_pos:
                    # the mapping might be wrong!
                    if bridge_accum_info.location is not guard_accum_info.location:
                        self.regalloc_mov(guard_accum_info.location, bridge_accum_info.location)
                bridge_accum_info = bridge_accum_info.next()
            guard_accum_info = guard_accum_info.next()

        # register mapping is most likely NOT valid, thus remap it
        src_locations1 = []
        dst_locations1 = []
        src_locations2 = []
        dst_locations2 = []

        # Build the four lists
        assert len(guard_locs) == len(bridge_locs)
        for i,src_loc in enumerate(guard_locs):
            dst_loc = bridge_locs[i]
            if not src_loc.is_fp_reg():
                src_locations1.append(src_loc)
                dst_locations1.append(dst_loc)
            else:
                src_locations2.append(src_loc)
                dst_locations2.append(dst_loc)
        remap_frame_layout_mixed(self, src_locations1, dst_locations1, r.SCRATCH,
                                 src_locations2, dst_locations2, r.FP_SCRATCH)

        offset = self.mc.get_relative_pos()
        self.mc.b_abs(asminfo.rawstart)

        rawstart = self.materialize_loop(looptoken)
        # update the guard to jump right to this custom piece of assembler
        self.patch_jump_for_descr(faildescr, rawstart)

def notimplemented_op(self, op, arglocs, regalloc):
    msg = '[PPC/asm] %s not implemented\n' % op.getopname()
    if we_are_translated():
        llop.debug_print(lltype.Void, msg)
    raise NotImplementedError(msg)

operations = [notimplemented_op] * (rop._LAST + 1)

for key, value in rop.__dict__.items():
    key = key.lower()
    if key.startswith('_'):
        continue
    methname = 'emit_%s' % key
    if hasattr(AssemblerPPC, methname):
        func = getattr(AssemblerPPC, methname).im_func
        operations[value] = func

class BridgeAlreadyCompiled(Exception):
    pass
