from __future__ import with_statement

import os

from rpython.jit.backend.arm import conditions as c, registers as r
from rpython.jit.backend.arm import shift
from rpython.jit.backend.arm.arch import (WORD, DOUBLE_WORD,
    JITFRAME_FIXED_SIZE)
from rpython.jit.backend.arm.codebuilder import InstrBuilder, OverwritingBuilder
from rpython.jit.backend.arm.locations import imm, StackLocation, get_fp_offset
from rpython.jit.backend.arm.helper.regalloc import VMEM_imm_size
from rpython.jit.backend.arm.opassembler import ResOpAssembler
from rpython.jit.backend.arm.regalloc import (Regalloc,
    CoreRegisterManager, check_imm_arg, VFPRegisterManager,
    operations as regalloc_operations)
from rpython.jit.backend.llsupport import jitframe, rewrite
from rpython.jit.backend.llsupport.assembler import BaseAssembler
from rpython.jit.backend.llsupport.regalloc import get_scale, valid_addressing_size
from rpython.jit.backend.llsupport.asmmemmgr import MachineDataBlockWrapper
from rpython.jit.backend.model import CompiledLoopToken
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.metainterp.history import AbstractFailDescr, FLOAT, INT, VOID
from rpython.jit.metainterp.resoperation import rop
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rlib.jit import AsmInfo
from rpython.rlib.objectmodel import we_are_translated, specialize, compute_unique_id
from rpython.rlib.rarithmetic import r_uint
from rpython.rtyper.annlowlevel import llhelper, cast_instance_to_gcref
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.jit.backend.arm import callbuilder
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.rjitlog import rjitlog as jl

class AssemblerARM(ResOpAssembler):

    debug = False
    DEBUG_FRAME_DEPTH = False

    def __init__(self, cpu, translate_support_code=False):
        ResOpAssembler.__init__(self, cpu, translate_support_code)
        self.setup_failure_recovery()
        self.mc = None
        self.pending_guards = None
        self._exit_code_addr = 0
        self.current_clt = None
        self.malloc_slowpath = 0
        self.wb_slowpath = [0, 0, 0, 0, 0]
        self._regalloc = None
        self.datablockwrapper = None
        self.propagate_exception_path = 0
        self.stack_check_slowpath = 0
        self._debug = False
        self.loop_run_counters = []
        self.gcrootmap_retaddr_forced = 0

    def setup_once(self):
        BaseAssembler.setup_once(self)

    def setup(self, looptoken):
        BaseAssembler.setup(self, looptoken)
        assert self.memcpy_addr != 0, 'setup_once() not called?'
        if we_are_translated():
            self.debug = False
        self.current_clt = looptoken.compiled_loop_token
        self.mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        self.pending_guards = []
        #assert self.datablockwrapper is None --- but obscure case
        # possible, e.g. getting MemoryError and continuing
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        self.datablockwrapper = MachineDataBlockWrapper(self.cpu.asmmemmgr,
                                                        allblocks)
        self.mc.datablockwrapper = self.datablockwrapper
        self.target_tokens_currently_compiling = {}
        self.frame_depth_to_patch = []

    def teardown(self):
        self.current_clt = None
        self._regalloc = None
        self.mc = None
        self.pending_guards = None

    def setup_failure_recovery(self):
        self.failure_recovery_code = [0, 0, 0, 0]

    def _build_propagate_exception_path(self):
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        self._store_and_reset_exception(mc, r.r0)
        ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
        # make sure ofs fits into a register
        assert check_imm_arg(ofs)
        self.store_reg(mc, r.r0, r.fp, ofs)
        propagate_exception_descr = rffi.cast(lltype.Signed,
                  cast_instance_to_gcref(self.cpu.propagate_exception_descr))
        # put propagate_exception_descr into frame
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        # make sure ofs fits into a register
        assert check_imm_arg(ofs)
        mc.gen_load_int(r.r0.value, propagate_exception_descr)
        self.store_reg(mc, r.r0, r.fp, ofs)
        mc.MOV_rr(r.r0.value, r.fp.value)
        self.gen_func_epilog(mc)
        rawstart = mc.materialize(self.cpu, [])
        self.propagate_exception_path = rawstart

    def _store_and_reset_exception(self, mc, excvalloc=None, exctploc=None,
                                                                on_frame=False):
        """ Resest the exception. If excvalloc is None, then store it on the
        frame in jf_guard_exc
        """
        assert excvalloc is not r.ip
        assert exctploc is not r.ip
        tmpreg = r.lr
        mc.gen_load_int(r.ip.value, self.cpu.pos_exc_value())
        if excvalloc is not None: # store
            assert excvalloc.is_core_reg()
            self.load_reg(mc, excvalloc, r.ip)
        if on_frame:
            # store exc_value in JITFRAME
            ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            assert check_imm_arg(ofs)
            #
            self.load_reg(mc, r.ip, r.ip, helper=tmpreg)
            #
            self.store_reg(mc, r.ip, r.fp, ofs, helper=tmpreg)
        if exctploc is not None:
            # store pos_exception in exctploc
            assert exctploc.is_core_reg()
            mc.gen_load_int(r.ip.value, self.cpu.pos_exception())
            self.load_reg(mc, exctploc, r.ip, helper=tmpreg)

        if on_frame or exctploc is not None:
            mc.gen_load_int(r.ip.value, self.cpu.pos_exc_value())

        # reset exception
        mc.gen_load_int(tmpreg.value, 0)

        self.store_reg(mc, tmpreg, r.ip, 0)

        mc.gen_load_int(r.ip.value, self.cpu.pos_exception())
        self.store_reg(mc, tmpreg, r.ip, 0)

    def _restore_exception(self, mc, excvalloc, exctploc):
        assert excvalloc is not r.ip
        assert exctploc is not r.ip
        tmpreg = r.lr # use lr as a second temporary reg
        mc.gen_load_int(r.ip.value, self.cpu.pos_exc_value())
        if excvalloc is not None:
            assert excvalloc.is_core_reg()
            self.store_reg(mc, excvalloc, r.ip)
        else:
            assert exctploc is not r.fp
            # load exc_value from JITFRAME and put it in pos_exc_value
            ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            self.load_reg(mc, tmpreg, r.fp, ofs)
            self.store_reg(mc, tmpreg, r.ip)
            # reset exc_value in the JITFRAME
            mc.gen_load_int(tmpreg.value, 0)
            self.store_reg(mc, tmpreg, r.fp, ofs)

        # restore pos_exception from exctploc register
        mc.gen_load_int(r.ip.value, self.cpu.pos_exception())
        self.store_reg(mc, exctploc, r.ip)

    def _build_stack_check_slowpath(self):
        _, _, slowpathaddr = self.cpu.insert_stack_check()
        if slowpathaddr == 0 or not self.cpu.propagate_exception_descr:
            return      # no stack check (for tests, or non-translated)
        #
        # make a "function" that is called immediately at the start of
        # an assembler function.  In particular, the stack looks like:
        #
        #    |  retaddr of caller    |   <-- aligned to a multiple of 16
        #    |  saved argument regs  |
        #    |  my own retaddr       |    <-- sp
        #    +-----------------------+
        #
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        # save argument registers and return address
        mc.PUSH([reg.value for reg in r.argument_regs] + [r.ip.value, r.lr.value])
        # stack is aligned here
        # Pass current stack pointer as argument to the call
        mc.MOV_rr(r.r0.value, r.sp.value)
        #
        mc.BL(slowpathaddr)

        # check for an exception
        mc.gen_load_int(r.r0.value, self.cpu.pos_exception())
        mc.LDR_ri(r.r0.value, r.r0.value)
        mc.TST_rr(r.r0.value, r.r0.value)
        #
        # restore registers and return
        # We check for c.EQ here, meaning all bits zero in this case
        mc.POP([reg.value for reg in r.argument_regs] + [r.ip.value, r.pc.value], cond=c.EQ)
        # restore sp
        mc.ADD_ri(r.sp.value, r.sp.value, (len(r.argument_regs) + 2) * WORD)
        mc.B(self.propagate_exception_path)
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
        # all vfp registers.  It takes a single argument which is in r0.
        # It must keep stack alignment accordingly.
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        #
        exc0 = exc1 = None
        mc.PUSH([r.ip.value, r.lr.value]) # push two words to keep alignment
        if not for_frame:
            self._push_all_regs_to_jitframe(mc, [], withfloats, callee_only=True)
        else:
            # NOTE: don't save registers on the jitframe here!  It might
            # override already-saved values that will be restored
            # later...
            #
            # we're possibly called from the slowpath of malloc
            # save the caller saved registers
            # assuming we do not collect here
            exc0, exc1 = r.r4, r.r5
            mc.PUSH([gpr.value for gpr in r.caller_resp] + [exc0.value, exc1.value])
            mc.VPUSH([vfpr.value for vfpr in r.caller_vfp_resp])

            self._store_and_reset_exception(mc, exc0, exc1)
        mc.BL(func)
        #
        if not for_frame:
            self._pop_all_regs_from_jitframe(mc, [], withfloats, callee_only=True)
        else:
            self._restore_exception(mc, exc0, exc1)
            mc.VPOP([vfpr.value for vfpr in r.caller_vfp_resp])
            assert exc0 is not None
            assert exc1 is not None
            mc.POP([gpr.value for gpr in r.caller_resp] +
                            [exc0.value, exc1.value])
        #
        if withcards:
            # A final TEST8 before the RET, for the caller.  Careful to
            # not follow this instruction with another one that changes
            # the status of the CPU flags!
            mc.LDRB_ri(r.ip.value, r.r0.value,
                                    imm=descr.jit_wb_if_flag_byteofs)
            mc.TST_ri(r.ip.value, imm=0x80)
        #
        mc.POP([r.ip.value, r.pc.value])
        #
        rawstart = mc.materialize(self.cpu, [])
        if for_frame:
            self.wb_slowpath[4] = rawstart
        else:
            self.wb_slowpath[withcards + 2 * withfloats] = rawstart

    def _build_cond_call_slowpath(self, supports_floats, callee_only):
        """ This builds a general call slowpath, for whatever call happens to
        come.
        """
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        #
        # We don't save/restore r4; instead the return value (if any)
        # will be stored there.
        self._push_all_regs_to_jitframe(mc, [r.r4], self.cpu.supports_floats, callee_only)
        ## args are in their respective positions
        mc.PUSH([r.ip.value, r.lr.value])
        mc.BLX(r.r4.value)
        mc.MOV_rr(r.r4.value, r.r0.value)
        self._reload_frame_if_necessary(mc)
        self._pop_all_regs_from_jitframe(mc, [r.r4], supports_floats,
                                      callee_only)
        # return
        mc.POP([r.ip.value, r.pc.value])
        return mc.materialize(self.cpu, [])

    def _build_malloc_slowpath(self, kind):
        """ While arriving on slowpath, we have a gcpattern on stack 0.
        The arguments are passed in r0 and r10, as follows:

        kind == 'fixed': nursery_head in r0 and the size in r1 - r0.

        kind == 'str/unicode': length of the string to allocate in r0.

        kind == 'var': length to allocate in r1, tid in r0,
                       and itemsize on the stack.

        This function must preserve all registers apart from r0 and r1.
        """
        assert kind in ['fixed', 'str', 'unicode', 'var']
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        #
        self._push_all_regs_to_jitframe(mc, [r.r0, r.r1], self.cpu.supports_floats)
        #
        if kind == 'fixed':
            addr = self.cpu.gc_ll_descr.get_malloc_slowpath_addr()
        elif kind == 'str':
            addr = self.cpu.gc_ll_descr.get_malloc_fn_addr('malloc_str')
        elif kind == 'unicode':
            addr = self.cpu.gc_ll_descr.get_malloc_fn_addr('malloc_unicode')
        else:
            addr = self.cpu.gc_ll_descr.get_malloc_slowpath_array_addr()
        if kind == 'fixed':
            # stack layout: [gcmap]
            # At this point we know that the values we need to compute the size
            # are stored in r0 and r1.
            mc.SUB_rr(r.r0.value, r.r1.value, r.r0.value) # compute the size we want

            if hasattr(self.cpu.gc_ll_descr, 'passes_frame'):
                mc.MOV_rr(r.r1.value, r.fp.value)
        elif kind == 'str' or kind == 'unicode':
            # stack layout: [gcmap]
            mc.MOV_rr(r.r0.value, r.r1.value)
        else:  # var
            # stack layout: [gcmap][itemsize]...
            # tid is in r0
            # length is in r1
            mc.MOV_rr(r.r2.value, r.r1.value)
            mc.MOV_rr(r.r1.value, r.r0.value)
            mc.POP([r.r0.value])  # load itemsize
        # store the gc pattern
        mc.POP([r.r4.value])
        ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        self.store_reg(mc, r.r4, r.fp, ofs)
        #
        # We need to push two registers here because we are going to make a
        # call an therefore the stack needs to be 8-byte aligned
        mc.PUSH([r.ip.value, r.lr.value])
        #
        mc.BL(addr)
        #
        # If the slowpath malloc failed, we raise a MemoryError that
        # always interrupts the current loop, as a "good enough"
        # approximation.
        mc.CMP_ri(r.r0.value, 0)
        mc.B(self.propagate_exception_path, c=c.EQ)
        #
        self._reload_frame_if_necessary(mc)
        self._pop_all_regs_from_jitframe(mc, [r.r0, r.r1], self.cpu.supports_floats)
        #
        nursery_free_adr = self.cpu.gc_ll_descr.get_nursery_free_addr()
        mc.gen_load_int(r.r1.value, nursery_free_adr)
        mc.LDR_ri(r.r1.value, r.r1.value)
        # clear the gc pattern
        mc.gen_load_int(r.ip.value, 0)
        self.store_reg(mc, r.ip, r.fp, ofs)
        # return
        mc.POP([r.ip.value, r.pc.value])

        #
        rawstart = mc.materialize(self.cpu, [])
        return rawstart

    def _reload_frame_if_necessary(self, mc):
        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            rst = gcrootmap.get_root_stack_top_addr()
            mc.gen_load_int(r.ip.value, rst)
            self.load_reg(mc, r.ip, r.ip)
            self.load_reg(mc, r.fp, r.ip, ofs=-WORD)
        wbdescr = self.cpu.gc_ll_descr.write_barrier_descr
        if gcrootmap and wbdescr:
            # frame never uses card marking, so we enforce this is not
            # an array
            self._write_barrier_fastpath(mc, wbdescr, [r.fp], array=False,
                                         is_frame=True)

    def propagate_memoryerror_if_reg_is_null(self, reg_loc):
        # see ../x86/assembler.py:genop_discard_check_memory_error()
        self.mc.CMP_ri(reg_loc.value, 0)
        self.mc.B(self.propagate_exception_path, c=c.EQ)

    def _push_all_regs_to_jitframe(self, mc, ignored_regs, withfloats,
                                callee_only=False):
        # Push general purpose registers
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        if callee_only:
            regs = CoreRegisterManager.save_around_call_regs
        else:
            regs = CoreRegisterManager.all_regs
        # XXX add special case if ignored_regs are a block at the start of regs
        if not ignored_regs:  # we want to push a contiguous block of regs
            assert check_imm_arg(base_ofs)
            mc.ADD_ri(r.ip.value, r.fp.value, base_ofs)
            mc.STM(r.ip.value, [reg.value for reg in regs])
        else:
            for reg in ignored_regs:
                assert not reg.is_vfp_reg()  # sanity check
            # we can have holes in the list of regs
            for i, gpr in enumerate(regs):
                if gpr in ignored_regs:
                    continue
                self.store_reg(mc, gpr, r.fp, base_ofs + i * WORD)

        if withfloats:
            # Push VFP regs
            regs = VFPRegisterManager.all_regs
            ofs = len(CoreRegisterManager.all_regs) * WORD
            assert check_imm_arg(ofs+base_ofs)
            mc.ADD_ri(r.ip.value, r.fp.value, imm=ofs+base_ofs)
            mc.VSTM(r.ip.value, [vfpr.value for vfpr in regs])

    def _pop_all_regs_from_jitframe(self, mc, ignored_regs, withfloats,
                                 callee_only=False):
        # Pop general purpose registers
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        if callee_only:
            regs = CoreRegisterManager.save_around_call_regs
        else:
            regs = CoreRegisterManager.all_regs
        # XXX add special case if ignored_regs are a block at the start of regs
        if not ignored_regs:  # we want to pop a contiguous block of regs
            assert check_imm_arg(base_ofs)
            mc.ADD_ri(r.ip.value, r.fp.value, base_ofs)
            mc.LDM(r.ip.value, [reg.value for reg in regs])
        else:
            for reg in ignored_regs:
                assert not reg.is_vfp_reg()  # sanity check
            # we can have holes in the list of regs
            for i, gpr in enumerate(regs):
                if gpr in ignored_regs:
                    continue
                ofs = i * WORD + base_ofs
                self.load_reg(mc, gpr, r.fp, ofs)
        if withfloats:
            # Pop VFP regs
            regs = VFPRegisterManager.all_regs
            ofs = len(CoreRegisterManager.all_regs) * WORD
            assert check_imm_arg(ofs+base_ofs)
            mc.ADD_ri(r.ip.value, r.fp.value, imm=ofs+base_ofs)
            mc.VLDM(r.ip.value, [vfpr.value for vfpr in regs])

    def _build_failure_recovery(self, exc, withfloats=False):
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        self._push_all_regs_to_jitframe(mc, [], withfloats)

        if exc:
            # We might have an exception pending.  Load it into r4
            # (this is a register saved across calls)
            mc.gen_load_int(r.r5.value, self.cpu.pos_exc_value())
            mc.LDR_ri(r.r4.value, r.r5.value)
            # clear the exc flags
            mc.gen_load_int(r.r6.value, 0)
            mc.STR_ri(r.r6.value, r.r5.value) # pos_exc_value is still in r5
            mc.gen_load_int(r.r5.value, self.cpu.pos_exception())
            mc.STR_ri(r.r6.value, r.r5.value)
            # save r4 into 'jf_guard_exc'
            offset = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            assert check_imm_arg(abs(offset))
            mc.STR_ri(r.r4.value, r.fp.value, imm=offset)
        # now we return from the complete frame, which starts from
        # _call_header_with_stack_check().  The LEA in _call_footer below
        # throws away most of the frame, including all the PUSHes that we
        # did just above.
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        assert check_imm_arg(abs(ofs))
        ofs2 = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        assert check_imm_arg(abs(ofs2))
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        # store the gcmap
        mc.POP([r.ip.value])
        mc.STR_ri(r.ip.value, r.fp.value, imm=ofs2)
        # store the descr
        mc.POP([r.ip.value])
        mc.STR_ri(r.ip.value, r.fp.value, imm=ofs)

        # set return value
        assert check_imm_arg(base_ofs)
        mc.MOV_rr(r.r0.value, r.fp.value)
        #
        self.gen_func_epilog(mc)
        rawstart = mc.materialize(self.cpu, [])
        self.failure_recovery_code[exc + 2 * withfloats] = rawstart

    def generate_quick_failure(self, guardtok):
        startpos = self.mc.currpos()
        faildescrindex, target = self.store_info_on_descr(startpos, guardtok)
        self.load_from_gc_table(r.ip.value, faildescrindex)
        self.regalloc_push(r.ip)
        self.push_gcmap(self.mc, gcmap=guardtok.gcmap, push=True)
        self.mc.BL(target)
        return startpos

    def gen_func_epilog(self, mc=None, cond=c.AL):
        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if mc is None:
            mc = self.mc
        if gcrootmap and gcrootmap.is_shadow_stack:
            self.gen_footer_shadowstack(gcrootmap, mc)
        if self.cpu.supports_floats:
            mc.VPOP([reg.value for reg in r.callee_saved_vfp_registers],
                                                                    cond=cond)
        # pop all callee saved registers.  This pops 'pc' last.
        # It also pops the threadlocal_addr back into 'r1', but it
        # is not needed any more and will be discarded.
        mc.POP([reg.value for reg in r.callee_restored_registers] +
                                                       [r.r1.value], cond=cond)
        mc.BKPT()

    def gen_func_prolog(self):
        stack_size = WORD #alignment
        stack_size += len(r.callee_saved_registers) * WORD
        if self.cpu.supports_floats:
            stack_size += len(r.callee_saved_vfp_registers) * 2 * WORD

        # push all callee saved registers including lr; and push r1 as
        # well, which contains the threadlocal_addr argument.  Note that
        # we're pushing a total of 10 words, which keeps the stack aligned.
        self.mc.PUSH([reg.value for reg in r.callee_saved_registers] +
                                                        [r.r1.value])
        self.saved_threadlocal_addr = 0   # at offset 0 from location 'sp'
        if self.cpu.supports_floats:
            self.mc.VPUSH([reg.value for reg in r.callee_saved_vfp_registers])
            self.saved_threadlocal_addr += (
                len(r.callee_saved_vfp_registers) * 2 * WORD)
        assert stack_size % 8 == 0 # ensure we keep alignment

        # set fp to point to the JITFRAME
        self.mc.MOV_rr(r.fp.value, r.r0.value)
        #
        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self.gen_shadowstack_header(gcrootmap)

    def gen_shadowstack_header(self, gcrootmap):
        # lr = shadow stack top addr
        # ip = *lr
        rst = gcrootmap.get_root_stack_top_addr()
        self.mc.gen_load_int(r.lr.value, rst)
        self.load_reg(self.mc, r.ip, r.lr)
        # *ip = r.fp
        self.store_reg(self.mc, r.fp, r.ip)
        #
        self.mc.ADD_ri(r.ip.value, r.ip.value, WORD)
        # *lr = ip + WORD
        self.store_reg(self.mc, r.ip, r.lr)

    def gen_footer_shadowstack(self, gcrootmap, mc):
        rst = gcrootmap.get_root_stack_top_addr()
        mc.gen_load_int(r.ip.value, rst)
        self.load_reg(mc, r.r4, r.ip)
        mc.SUB_ri(r.r4.value, r.r4.value, WORD)
        self.store_reg(mc, r.r4, r.ip)

    def _dump(self, ops, type='loop'):
        debug_start('jit-backend-ops')
        debug_print(type)
        for op in ops:
            debug_print(op.repr())
        debug_stop('jit-backend-ops')

    def _call_header(self):
        # there is the gc table before this point
        self.gen_func_prolog()

    def _call_header_with_stack_check(self):
        self._call_header()
        if self.stack_check_slowpath == 0:
            pass                # no stack check (e.g. not translated)
        else:
            endaddr, lengthaddr, _ = self.cpu.insert_stack_check()
            # load stack end
            self.mc.gen_load_int(r.ip.value, endaddr)          # load ip, [end]
            self.mc.LDR_ri(r.ip.value, r.ip.value)             # LDR ip, ip
            # load stack length
            self.mc.gen_load_int(r.lr.value, lengthaddr)       # load lr, lengh
            self.mc.LDR_ri(r.lr.value, r.lr.value)             # ldr lr, *lengh
            # calculate ofs
            self.mc.SUB_rr(r.ip.value, r.ip.value, r.sp.value) # SUB ip, current
            # if ofs
            self.mc.CMP_rr(r.ip.value, r.lr.value)             # CMP ip, lr
            self.mc.BL(self.stack_check_slowpath, c=c.HI)      # call if ip > lr

    # cpu interface
    def assemble_loop(self, jd_id, unique_id, logger, loopname, inputargs,
                      operations, looptoken, log):
        clt = CompiledLoopToken(self.cpu, looptoken.number)
        looptoken.compiled_loop_token = clt
        clt._debug_nbargs = len(inputargs)

        if not we_are_translated():
            # Arguments should be unique
            assert len(set(inputargs)) == len(inputargs)

        self.setup(looptoken)
        #self.codemap_builder.enter_portal_frame(jd_id, unique_id,
        #                                self.mc.get_relative_pos())


        frame_info = self.datablockwrapper.malloc_aligned(
            jitframe.JITFRAMEINFO_SIZE, alignment=WORD)
        clt.frame_info = rffi.cast(jitframe.JITFRAMEINFOPTR, frame_info)
        clt.frame_info.clear() # for now

        if log:
            operations = self._inject_debugging_code(looptoken, operations,
                                                     'e', looptoken.number)

        regalloc = Regalloc(assembler=self)
        allgcrefs = []
        operations = regalloc.prepare_loop(inputargs, operations, looptoken,
                                           allgcrefs)
        self.reserve_gcref_table(allgcrefs)
        functionpos = self.mc.get_relative_pos()

        self._call_header_with_stack_check()
        self._check_frame_depth_debug(self.mc)

        loop_head = self.mc.get_relative_pos()
        looptoken._ll_loop_code = loop_head
        #
        frame_depth_no_fixed_size = self._assemble(regalloc, inputargs, operations)
        self.update_frame_depth(frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE)
        #
        size_excluding_failure_stuff = self.mc.get_relative_pos()

        self.write_pending_failure_recoveries()

        full_size = self.mc.get_relative_pos()
        rawstart = self.materialize_loop(looptoken)
        looptoken._ll_function_addr = rawstart + functionpos

        self.patch_gcref_table(looptoken, rawstart)
        self.process_pending_guards(rawstart)
        self.fixup_target_tokens(rawstart)

        if log and not we_are_translated():
            self.mc._dump_trace(rawstart,
                    'loop.asm')

        ops_offset = self.mc.ops_offset

        if logger:
            log = logger.log_trace(jl.MARK_TRACE_ASM, None, self.mc)
            log.write(inputargs, operations, ops_offset=ops_offset)

            # legacy
            if logger.logger_ops:
                logger.logger_ops.log_loop(inputargs, operations, 0,
                                           "rewritten", name=loopname,
                                           ops_offset=ops_offset)

        self.teardown()

        debug_start("jit-backend-addr")
        debug_print("Loop %d (%s) has address 0x%x to 0x%x (bootstrap 0x%x)" % (
            looptoken.number, loopname,
            r_uint(rawstart + loop_head),
            r_uint(rawstart + size_excluding_failure_stuff),
            r_uint(rawstart + functionpos)))
        debug_print("       gc table: 0x%x" % r_uint(rawstart))
        debug_print("       function: 0x%x" % r_uint(rawstart + functionpos))
        debug_print("         resops: 0x%x" % r_uint(rawstart + loop_head))
        debug_print("       failures: 0x%x" % r_uint(rawstart +
                                                 size_excluding_failure_stuff))
        debug_print("            end: 0x%x" % r_uint(rawstart + full_size))
        debug_stop("jit-backend-addr")

        return AsmInfo(ops_offset, rawstart + loop_head,
                       size_excluding_failure_stuff - loop_head)

    def _assemble(self, regalloc, inputargs, operations):
        self.guard_success_cc = c.cond_none
        regalloc.compute_hint_frame_locations(operations)
        self._walk_operations(inputargs, operations, regalloc)
        assert self.guard_success_cc == c.cond_none
        frame_depth = regalloc.get_final_frame_depth()
        jump_target_descr = regalloc.jump_target_descr
        if jump_target_descr is not None:
            tgt_depth = jump_target_descr._arm_clt.frame_info.jfi_frame_depth
            target_frame_depth = tgt_depth - JITFRAME_FIXED_SIZE
            frame_depth = max(frame_depth, target_frame_depth)
        return frame_depth

    def assemble_bridge(self, logger, faildescr, inputargs, operations,
                        original_loop_token, log):
        if not we_are_translated():
            # Arguments should be unique
            assert len(set(inputargs)) == len(inputargs)

        self.setup(original_loop_token)
        #self.codemap.inherit_code_from_position(faildescr.adr_jump_offset)
        descr_number = compute_unique_id(faildescr)
        if log:
            operations = self._inject_debugging_code(faildescr, operations,
                                                     'b', descr_number)

        assert isinstance(faildescr, AbstractFailDescr)

        arglocs = self.rebuild_faillocs_from_descr(faildescr, inputargs)

        regalloc = Regalloc(assembler=self)
        allgcrefs = []
        operations = regalloc.prepare_bridge(inputargs, arglocs,
                                             operations,
                                             allgcrefs,
                                             self.current_clt.frame_info)
        self.reserve_gcref_table(allgcrefs)
        startpos = self.mc.get_relative_pos()

        self._check_frame_depth(self.mc, regalloc.get_gcmap())

        bridgestartpos = self.mc.get_relative_pos()
        frame_depth_no_fixed_size = self._assemble(regalloc, inputargs, operations)

        codeendpos = self.mc.get_relative_pos()

        self.write_pending_failure_recoveries()

        fullsize = self.mc.get_relative_pos()
        rawstart = self.materialize_loop(original_loop_token)

        self.patch_gcref_table(original_loop_token, rawstart)
        self.process_pending_guards(rawstart)

        debug_start("jit-backend-addr")
        debug_print("bridge out of Guard 0x%x has address 0x%x to 0x%x" %
                    (r_uint(descr_number), r_uint(rawstart + startpos),
                        r_uint(rawstart + codeendpos)))
        debug_print("       gc table: 0x%x" % r_uint(rawstart))
        debug_print("    jump target: 0x%x" % r_uint(rawstart + startpos))
        debug_print("         resops: 0x%x" % r_uint(rawstart + bridgestartpos))
        debug_print("       failures: 0x%x" % r_uint(rawstart + codeendpos))
        debug_print("            end: 0x%x" % r_uint(rawstart + fullsize))
        debug_stop("jit-backend-addr")

        # patch the jump from original guard
        self.patch_trace(faildescr, original_loop_token,
                                    rawstart + startpos, regalloc)

        self.patch_stack_checks(frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE,
                                rawstart)
        if not we_are_translated():
            if log:
                self.mc._dump_trace(rawstart, 'bridge.asm')

        ops_offset = self.mc.ops_offset
        frame_depth = max(self.current_clt.frame_info.jfi_frame_depth,
                          frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE)
        self.fixup_target_tokens(rawstart)
        self.update_frame_depth(frame_depth)

        if logger:
            log = logger.log_trace(jl.MARK_TRACE_ASM, None, self.mc)
            log.write(inputargs, operations, ops_offset)
            # log that the already written bridge is stitched to a descr!
            logger.log_patch_guard(descr_number, rawstart)

            # legacy
            if logger.logger_ops:
                logger.logger_ops.log_bridge(inputargs, operations, "rewritten",
                                          faildescr, ops_offset=ops_offset)

        self.teardown()

        return AsmInfo(ops_offset, startpos + rawstart, codeendpos - startpos)

    def reserve_gcref_table(self, allgcrefs):
        gcref_table_size = len(allgcrefs) * WORD
        # align to a multiple of 16 and reserve space at the beginning
        # of the machine code for the gc table.  This lets us write
        # machine code with relative addressing (see load_from_gc_table())
        gcref_table_size = (gcref_table_size + 15) & ~15
        mc = self.mc
        assert mc.get_relative_pos() == 0
        for i in range(gcref_table_size):
            mc.writechar('\x00')
        self.setup_gcrefs_list(allgcrefs)

    def patch_gcref_table(self, looptoken, rawstart):
        # the gc table is at the start of the machine code.  Fill it now
        tracer = self.cpu.gc_ll_descr.make_gcref_tracer(rawstart,
                                                        self._allgcrefs)
        gcreftracers = self.get_asmmemmgr_gcreftracers(looptoken)
        gcreftracers.append(tracer)    # keepalive
        self.teardown_gcrefs_list()

    def load_from_gc_table(self, regnum, index):
        """emits either:
               LDR Rt, [PC, #offset]    if -4095 <= offset
          or:
               gen_load_int(Rt, offset)
               LDR Rt, [PC, Rt]         for larger offsets
        """
        mc = self.mc
        address_in_buffer = index * WORD   # at the start of the buffer
        offset = address_in_buffer - (mc.get_relative_pos() + 8)   # negative
        if offset >= -4095:
            mc.LDR_ri(regnum, r.pc.value, offset)
        else:
            # The offset we're loading is negative: right now,
            # gen_load_int() will always use exactly
            # get_max_size_of_gen_load_int() instructions.  No point
            # in optimizing in case we get less.  Just in case though,
            # we check and pad with nops.
            extra_bytes = mc.get_max_size_of_gen_load_int() * 4
            offset -= extra_bytes
            start = mc.get_relative_pos()
            mc.gen_load_int(regnum, offset)
            missing = start + extra_bytes - mc.get_relative_pos()
            while missing > 0:
                mc.NOP()
                missing = start + extra_bytes - mc.get_relative_pos()
            assert missing == 0
            mc.LDR_rr(regnum, r.pc.value, regnum)

    def new_stack_loc(self, i, tp):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        return StackLocation(i, get_fp_offset(base_ofs, i), tp)

    def check_frame_before_jump(self, target_token):
        if target_token in self.target_tokens_currently_compiling:
            return
        if target_token._arm_clt is self.current_clt:
            return
        # We can have a frame coming from god knows where that's
        # passed to a jump to another loop. Make sure it has the
        # correct depth
        expected_size = target_token._arm_clt.frame_info.jfi_frame_depth
        self._check_frame_depth(self.mc, self._regalloc.get_gcmap(),
                                expected_size=expected_size)

    def _patch_frame_depth(self, adr, allocated_depth):
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        mc.gen_load_int(r.lr.value, allocated_depth)
        mc.copy_to_raw_memory(adr)

    def _check_frame_depth(self, mc, gcmap, expected_size=-1):
        """ check if the frame is of enough depth to follow this bridge.
        Otherwise reallocate the frame in a helper.
        There are other potential solutions
        to that, but this one does not sound too bad.
        """
        descrs = self.cpu.gc_ll_descr.getframedescrs(self.cpu)
        ofs = self.cpu.unpack_fielddescr(descrs.arraydescr.lendescr)
        mc.LDR_ri(r.ip.value, r.fp.value, imm=ofs)
        stack_check_cmp_ofs = mc.currpos()
        if expected_size == -1:
            for _ in range(mc.get_max_size_of_gen_load_int()):
                mc.NOP()
        else:
            mc.gen_load_int(r.lr.value, expected_size)
        mc.CMP_rr(r.ip.value, r.lr.value)

        jg_location = mc.currpos()
        mc.BKPT()

        # the size value is still stored in lr
        mc.PUSH([r.lr.value])

        self.push_gcmap(mc, gcmap, push=True)

        self.mc.BL(self._frame_realloc_slowpath)

        # patch jg_location above
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(mc, jg_location, WORD)
        pmc.B_offs(currpos, c.GE)

        self.frame_depth_to_patch.append(stack_check_cmp_ofs)

    def _check_frame_depth_debug(self, mc):
        """ double check the depth size. It prints the error (and potentially
        segfaults later)
        """
        if not self.DEBUG_FRAME_DEPTH:
            return
        descrs = self.cpu.gc_ll_descr.getframedescrs(self.cpu)
        ofs = self.cpu.unpack_fielddescr(descrs.arraydescr.lendescr)
        mc.LDR_ri(r.ip.value, r.fp.value, imm=ofs)
        stack_check_cmp_ofs = mc.currpos()
        for _ in range(mc.get_max_size_of_gen_load_int()):
            mc.NOP()
        mc.CMP_rr(r.ip.value, r.lr.value)

        jg_location = mc.currpos()
        mc.BKPT()

        mc.MOV_rr(r.r0.value, r.fp.value)
        mc.MOV_ri(r.r1.value, r.lr.value)

        self.mc.BL(self.cpu.realloc_frame_crash)
        # patch the JG above
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(mc, jg_location, WORD)
        pmc.B_offs(currpos, c.GE)

        self.frame_depth_to_patch.append(stack_check_cmp_ofs)

    def build_frame_realloc_slowpath(self):
        # this code should do the following steps
        # a) store all registers in the jitframe
        # b) fish for the arguments passed by the caller
        # c) store the gcmap in the jitframe
        # d) call realloc_frame
        # e) set the fp to point to the new jitframe
        # f) store the address of the new jitframe in the shadowstack
        # c) set the gcmap field to 0 in the new jitframe
        # g) restore registers and return
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        self._push_all_regs_to_jitframe(mc, [], self.cpu.supports_floats)
        # this is the gcmap stored by push_gcmap(mov=True) in _check_stack_frame
        # and the expected_size pushed in _check_stack_frame
        # pop the values passed on the stack, gcmap -> r0, expected_size -> r1
        mc.POP([r.r0.value, r.r1.value])
        # store return address and keep the stack aligned
        mc.PUSH([r.ip.value, r.lr.value])

        # store the current gcmap(r0) in the jitframe
        gcmap_ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        assert check_imm_arg(abs(gcmap_ofs))
        mc.STR_ri(r.r0.value, r.fp.value, imm=gcmap_ofs)

        # set first arg, which is the old jitframe address
        mc.MOV_rr(r.r0.value, r.fp.value)

        # store a possibly present exception
        # we use a callee saved reg here as a tmp for the exc.
        self._store_and_reset_exception(mc, None, r.r4, on_frame=True)

        # call realloc_frame, it takes two arguments
        # arg0: the old jitframe
        # arg1: the new size
        #
        mc.BL(self.cpu.realloc_frame)

        # set fp to the new jitframe returned from the previous call
        mc.MOV_rr(r.fp.value, r.r0.value)

        # restore a possibly present exception
        self._restore_exception(mc, None, r.r4)

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self._load_shadowstack_top(mc, r.r5, gcrootmap)
            # store the new jitframe addr in the shadowstack
            mc.STR_ri(r.r0.value, r.r5.value, imm=-WORD)

        # reset the jf_gcmap field in the jitframe
        mc.gen_load_int(r.ip.value, 0)
        mc.STR_ri(r.ip.value, r.fp.value, imm=gcmap_ofs)

        # restore registers
        self._pop_all_regs_from_jitframe(mc, [], self.cpu.supports_floats)
        mc.POP([r.ip.value, r.pc.value])  # return
        self._frame_realloc_slowpath = mc.materialize(self.cpu, [])

    def _load_shadowstack_top(self, mc, reg, gcrootmap):
        rst = gcrootmap.get_root_stack_top_addr()
        mc.gen_load_int(reg.value, rst)
        self.load_reg(mc, reg, reg)
        return rst

    def fixup_target_tokens(self, rawstart):
        for targettoken in self.target_tokens_currently_compiling:
            targettoken._ll_loop_code += rawstart
        self.target_tokens_currently_compiling = None

    def _patch_stackadjust(self, adr, allocated_depth):
        mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
        mc.gen_load_int(r.lr.value, allocated_depth)
        mc.copy_to_raw_memory(adr)

    def patch_stack_checks(self, framedepth, rawstart):
        for ofs in self.frame_depth_to_patch:
            self._patch_frame_depth(ofs + rawstart, framedepth)

    def target_arglocs(self, loop_token):
        return loop_token._arm_arglocs

    def materialize_loop(self, looptoken):
        self.datablockwrapper.done()      # finish using cpu.asmmemmgr
        self.datablockwrapper = None
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        size = self.mc.get_relative_pos() 
        res = self.mc.materialize(self.cpu, allblocks,
                                   self.cpu.gc_ll_descr.gcrootmap)
        #self.cpu.codemap.register_codemap(
        #    self.codemap.get_final_bytecode(res, size))
        return res

    def update_frame_depth(self, frame_depth):
        baseofs = self.cpu.get_baseofs_of_frame_field()
        self.current_clt.frame_info.update_frame_depth(baseofs, frame_depth)

    def write_pending_failure_recoveries(self):
        for tok in self.pending_guards:
            #generate the exit stub and the encoded representation
            tok.pos_recovery_stub = self.generate_quick_failure(tok)

    def process_pending_guards(self, block_start):
        clt = self.current_clt
        for tok in self.pending_guards:
            descr = tok.faildescr
            assert isinstance(descr, AbstractFailDescr)
            failure_recovery_pos = block_start + tok.pos_recovery_stub
            descr.adr_jump_offset = failure_recovery_pos
            relative_offset = tok.pos_recovery_stub - tok.offset
            guard_pos = block_start + tok.offset
            if not tok.guard_not_invalidated():
                # patch the guard jump to the stub
                # overwrite the generate NOP with a B_offs to the pos of the
                # stub
                mc = InstrBuilder(self.cpu.cpuinfo.arch_version)
                mc.B_offs(relative_offset, c.get_opposite_of(tok.fcond))
                mc.copy_to_raw_memory(guard_pos)
            else:
                clt.invalidate_positions.append((guard_pos, relative_offset))

    def _walk_operations(self, inputargs, operations, regalloc):
        fcond = c.AL
        self._regalloc = regalloc
        regalloc.operations = operations
        while regalloc.position() < len(operations) - 1:
            regalloc.next_instruction()
            i = regalloc.position()
            op = operations[i]
            self.mc.mark_op(op)
            opnum = op.getopnum()
            if rop.has_no_side_effect(opnum) and op not in regalloc.longevity:
                regalloc.possibly_free_vars_for_op(op)
            elif not we_are_translated() and op.getopnum() == rop.FORCE_SPILL:
                regalloc.prepare_force_spill(op, fcond)
            else:
                arglocs = regalloc_operations[opnum](regalloc, op, fcond)
                if arglocs is not None:
                    fcond = asm_operations[opnum](self, op, arglocs,
                                                        regalloc, fcond)
                    assert fcond is not None
            if rop.is_guard(opnum):
                regalloc.possibly_free_vars(op.getfailargs())
            if op.type != 'v':
                regalloc.possibly_free_var(op)
            regalloc.possibly_free_vars_for_op(op)
            regalloc.free_temp_vars()
            regalloc._check_invariants()
        if not we_are_translated():
            self.mc.BKPT()
        self.mc.mark_op(None)  # end of the loop
        regalloc.operations = None

    def regalloc_emit_extra(self, op, arglocs, fcond, regalloc):
        # for calls to a function with a specifically-supported OS_xxx
        effectinfo = op.getdescr().get_extra_info()
        oopspecindex = effectinfo.oopspecindex
        asm_extra_operations[oopspecindex](self, op, arglocs, regalloc, fcond)
        return fcond

    def patch_trace(self, faildescr, looptoken, bridge_addr, regalloc):
        b = InstrBuilder(self.cpu.cpuinfo.arch_version)
        patch_addr = faildescr.adr_jump_offset
        assert patch_addr != 0
        b.B(bridge_addr)
        b.copy_to_raw_memory(patch_addr)
        faildescr.adr_jump_offset = 0

    # regalloc support
    def load(self, loc, value):
        """load an immediate value into a register"""
        assert (loc.is_core_reg() and value.is_imm()
                    or loc.is_vfp_reg() and value.is_imm_float())
        if value.is_imm():
            self.mc.gen_load_int(loc.value, value.getint())
        elif value.is_imm_float():
            self.mc.gen_load_int(r.ip.value, value.getint())
            self.mc.VLDR(loc.value, r.ip.value)

    def load_reg(self, mc, target, base, ofs=0, cond=c.AL, helper=r.ip):
        if target.is_vfp_reg():
            return self._load_vfp_reg(mc, target, base, ofs, cond, helper)
        elif target.is_core_reg():
            return self._load_core_reg(mc, target, base, ofs, cond, helper)

    def _load_vfp_reg(self, mc, target, base, ofs, cond=c.AL, helper=r.ip):
        if check_imm_arg(ofs, VMEM_imm_size):
            mc.VLDR(target.value, base.value, imm=ofs, cond=cond)
        else:
            mc.gen_load_int(helper.value, ofs, cond=cond)
            mc.ADD_rr(helper.value, base.value, helper.value, cond=cond)
            mc.VLDR(target.value, helper.value, cond=cond)

    def _load_core_reg(self, mc, target, base, ofs, cond=c.AL, helper=r.ip):
        if check_imm_arg(abs(ofs)):
            mc.LDR_ri(target.value, base.value, imm=ofs, cond=cond)
        else:
            mc.gen_load_int(helper.value, ofs, cond=cond)
            mc.LDR_rr(target.value, base.value, helper.value, cond=cond)

    def store_reg(self, mc, source, base, ofs=0, cond=c.AL, helper=r.ip):
        if source.is_vfp_reg():
            return self._store_vfp_reg(mc, source, base, ofs, cond, helper)
        else:
            return self._store_core_reg(mc, source, base, ofs, cond, helper)

    def _store_vfp_reg(self, mc, source, base, ofs, cond=c.AL, helper=r.ip):
        if check_imm_arg(ofs, VMEM_imm_size):
            mc.VSTR(source.value, base.value, imm=ofs, cond=cond)
        else:
            mc.gen_load_int(helper.value, ofs, cond=cond)
            mc.ADD_rr(helper.value, base.value, helper.value, cond=cond)
            mc.VSTR(source.value, helper.value, cond=cond)

    def _store_core_reg(self, mc, source, base, ofs, cond=c.AL, helper=r.ip):
        if check_imm_arg(ofs):
            mc.STR_ri(source.value, base.value, imm=ofs, cond=cond)
        else:
            mc.gen_load_int(helper.value, ofs, cond=cond)
            mc.STR_rr(source.value, base.value, helper.value, cond=cond)

    def get_tmp_reg(self, forbidden_regs=None):
        if forbidden_regs is None:
            return r.ip, False
        for x in [r.ip, r.lr]:
            if x not in forbidden_regs:
                return x, False
        # pick some reg, that we need to save
        for x in r.all_regs:
            if x not in forbidden_regs:
                return x, True
        assert 0

    def _mov_imm_to_loc(self, prev_loc, loc, cond=c.AL):
        if loc.type == FLOAT:
            raise AssertionError("invalid target for move from imm value")
        if loc.is_core_reg():
            new_loc = loc
        elif loc.is_stack() or loc.is_raw_sp():
            new_loc = r.lr
        else:
            raise AssertionError("invalid target for move from imm value")
        self.mc.gen_load_int(new_loc.value, prev_loc.value, cond=cond)
        if loc.is_stack():
            self.regalloc_mov(new_loc, loc)
        elif loc.is_raw_sp():
            self.store_reg(self.mc, new_loc, r.sp, loc.value, cond=cond, helper=r.ip)

    def _mov_reg_to_loc(self, prev_loc, loc, cond=c.AL):
        if loc.is_imm():
            raise AssertionError("mov reg to imm doesn't make sense")
        if loc.is_core_reg():
            self.mc.MOV_rr(loc.value, prev_loc.value, cond=cond)
        elif loc.is_stack() and loc.type != FLOAT:
            # spill a core register
            temp, save = self.get_tmp_reg([prev_loc, loc])
            offset = loc.value
            is_imm = check_imm_arg(offset, size=0xFFF)
            if not is_imm and save:
                self.mc.PUSH([temp.value], cond=cond)
            self.store_reg(self.mc, prev_loc, r.fp, offset, helper=temp, cond=cond)
            if not is_imm and save:
                self.mc.POP([temp.value], cond=cond)
        elif loc.is_raw_sp() and loc.type != FLOAT:
            temp, save = self.get_tmp_reg([prev_loc])
            assert not save
            self.store_reg(self.mc, prev_loc, r.sp, loc.value, cond=cond, helper=temp)
        else:
            assert 0, 'unsupported case'

    def _mov_stack_to_loc(self, prev_loc, loc, cond=c.AL):
        helper = None
        offset = prev_loc.value
        tmp = None
        if loc.is_core_reg():
            assert prev_loc.type != FLOAT, 'trying to load from an \
                incompatible location into a core register'
            # unspill a core register
            is_imm = check_imm_arg(offset, size=0xFFF)
            helper, save = self.get_tmp_reg([loc])
            save_helper = not is_imm and save
        elif loc.is_vfp_reg():
            assert prev_loc.type == FLOAT, 'trying to load from an \
                incompatible location into a float register'
            # load spilled value into vfp reg
            is_imm = check_imm_arg(offset)
            helper, save = self.get_tmp_reg()
            save_helper = not is_imm and save
        elif loc.is_raw_sp():
            assert (loc.type == prev_loc.type == FLOAT
                    or (loc.type != FLOAT and prev_loc.type != FLOAT))
            tmp = loc
            if loc.is_float():
                loc = r.vfp_ip
            else:
                loc, save_helper = self.get_tmp_reg()
                assert not save_helper
            helper, save_helper = self.get_tmp_reg([loc])
            assert not save_helper
        else:
            assert 0, 'unsupported case'

        if save_helper:
            self.mc.PUSH([helper.value], cond=cond)
        self.load_reg(self.mc, loc, r.fp, offset, cond=cond, helper=helper)
        if save_helper:
            self.mc.POP([helper.value], cond=cond)

        if tmp and tmp.is_raw_sp():
            self.store_reg(self.mc, loc, r.sp, tmp.value, cond=cond, helper=helper)

    def _mov_imm_float_to_loc(self, prev_loc, loc, cond=c.AL):
        if loc.is_vfp_reg():
            helper, save_helper = self.get_tmp_reg([loc])
            if save_helper:
                self.mc.PUSH([helper.value], cond=cond)
            self.mc.gen_load_int(helper.value, prev_loc.getint(), cond=cond)
            self.load_reg(self.mc, loc, helper, 0, cond=cond)
            if save_helper:
                self.mc.POP([helper.value], cond=cond)
        elif loc.is_stack() and loc.type == FLOAT:
            self.regalloc_mov(prev_loc, r.vfp_ip, cond)
            self.regalloc_mov(r.vfp_ip, loc, cond)
        elif loc.is_raw_sp() and loc.type == FLOAT:
            self.regalloc_mov(prev_loc, r.vfp_ip, cond)
            self.regalloc_mov(r.vfp_ip, loc, cond)
        else:
            assert 0, 'unsupported case'

    def _mov_vfp_reg_to_loc(self, prev_loc, loc, cond=c.AL):
        if loc.is_vfp_reg():
            self.mc.VMOV_cc(loc.value, prev_loc.value, cond=cond)
        elif loc.is_stack():
            assert loc.type == FLOAT, 'trying to store to an \
                incompatible location from a float register'
            # spill vfp register
            offset = loc.value
            is_imm = check_imm_arg(offset)
            self.store_reg(self.mc, prev_loc, r.fp, offset, cond=cond, helper=r.ip)
        elif loc.is_raw_sp():
            assert loc.type == FLOAT, 'trying to store to an \
                incompatible location from a float register'
            self.store_reg(self.mc, prev_loc, r.sp, loc.value, cond=cond)
        else:
            assert 0, 'unsupported case'

    def _mov_raw_sp_to_loc(self, prev_loc, loc, cond=c.AL):
        if loc.is_core_reg():
            # load a value from 'SP + n'
            assert prev_loc.value <= 0xFFF     # not too far
            self.load_reg(self.mc, loc, r.sp, prev_loc.value, cond=cond)
        else:
            assert 0, 'unsupported case'

    def regalloc_mov(self, prev_loc, loc, cond=c.AL):
        """Moves a value from a previous location to some other location"""
        if prev_loc.is_imm():
            return self._mov_imm_to_loc(prev_loc, loc, cond)
        elif prev_loc.is_core_reg():
            self._mov_reg_to_loc(prev_loc, loc, cond)
        elif prev_loc.is_stack():
            self._mov_stack_to_loc(prev_loc, loc, cond)
        elif prev_loc.is_imm_float():
            self._mov_imm_float_to_loc(prev_loc, loc, cond)
        elif prev_loc.is_vfp_reg():
            self._mov_vfp_reg_to_loc(prev_loc, loc, cond)
        elif prev_loc.is_raw_sp():
            self._mov_raw_sp_to_loc(prev_loc, loc, cond)
        else:
            assert 0, 'unsupported case'
    mov_loc_loc = regalloc_mov

    def mov_from_vfp_loc(self, vfp_loc, reg1, reg2, cond=c.AL):
        """Moves floating point values either as an immediate, in a vfp
        register or at a stack location to a pair of core registers"""
        assert reg1.value + 1 == reg2.value
        if vfp_loc.is_vfp_reg():
            self.mc.VMOV_rc(reg1.value, reg2.value, vfp_loc.value, cond=cond)
        elif vfp_loc.is_imm_float():
            helper, save_helper = self.get_tmp_reg([reg1, reg2])
            if save_helper:
                self.mc.PUSH([helper.value], cond=cond)
            self.mc.gen_load_int(helper.value, vfp_loc.getint(), cond=cond)
            # we need to load one word to loc and one to loc+1 which are
            # two 32-bit core registers
            self.mc.LDR_ri(reg1.value, helper.value, cond=cond)
            self.mc.LDR_ri(reg2.value, helper.value, imm=WORD, cond=cond)
            if save_helper:
                self.mc.POP([helper.value], cond=cond)
        elif vfp_loc.is_stack() and vfp_loc.type == FLOAT:
            # load spilled vfp value into two core registers
            offset = vfp_loc.value
            if not check_imm_arg(offset, size=0xFFF):
                helper, save_helper = self.get_tmp_reg([reg1, reg2])
                if save_helper:
                    self.mc.PUSH([helper.value], cond=cond)
                self.mc.gen_load_int(helper.value, offset, cond=cond)
                self.mc.LDR_rr(reg1.value, r.fp.value, helper.value, cond=cond)
                self.mc.ADD_ri(helper.value, helper.value, imm=WORD, cond=cond)
                self.mc.LDR_rr(reg2.value, r.fp.value, helper.value, cond=cond)
                if save_helper:
                    self.mc.POP([helper.value], cond=cond)
            else:
                self.mc.LDR_ri(reg1.value, r.fp.value, imm=offset, cond=cond)
                self.mc.LDR_ri(reg2.value, r.fp.value,
                                                imm=offset + WORD, cond=cond)
        else:
            assert 0, 'unsupported case'

    def mov_to_vfp_loc(self, reg1, reg2, vfp_loc, cond=c.AL):
        """Moves a floating point value from to consecutive core registers to a
        vfp location, either a vfp regsiter or a stacklocation"""
        assert reg1.value + 1 == reg2.value
        if vfp_loc.is_vfp_reg():
            self.mc.VMOV_cr(vfp_loc.value, reg1.value, reg2.value, cond=cond)
        elif vfp_loc.is_stack():
            # move from two core registers to a float stack location
            offset = vfp_loc.value
            if not check_imm_arg(offset + WORD, size=0xFFF):
                helper, save_helper = self.get_tmp_reg([reg1, reg2])
                if save_helper:
                    self.mc.PUSH([helper.value], cond=cond)
                self.mc.gen_load_int(helper.value, offset, cond=cond)
                self.mc.STR_rr(reg1.value, r.fp.value, helper.value, cond=cond)
                self.mc.ADD_ri(helper.value, helper.value, imm=WORD, cond=cond)
                self.mc.STR_rr(reg2.value, r.fp.value, helper.value, cond=cond)
                if save_helper:
                    self.mc.POP([helper.value], cond=cond)
            else:
                self.mc.STR_ri(reg1.value, r.fp.value, imm=offset, cond=cond)
                self.mc.STR_ri(reg2.value, r.fp.value,
                                                imm=offset + WORD, cond=cond)
        else:
            assert 0, 'unsupported case'

    def regalloc_push(self, loc, cond=c.AL):
        """Pushes the value stored in loc to the stack
        Can trash the current value of the IP register when pushing a stack
        loc"""

        if loc.is_stack():
            if loc.type != FLOAT:
                scratch_reg = r.ip
            else:
                scratch_reg = r.vfp_ip
            self.regalloc_mov(loc, scratch_reg, cond)
            self.regalloc_push(scratch_reg, cond)
        elif loc.is_core_reg():
            self.mc.PUSH([loc.value], cond=cond)
        elif loc.is_vfp_reg():
            self.mc.VPUSH([loc.value], cond=cond)
        elif loc.is_imm():
            self.regalloc_mov(loc, r.ip)
            self.mc.PUSH([r.ip.value], cond=cond)
        elif loc.is_imm_float():
            self.regalloc_mov(loc, r.vfp_ip)
            self.mc.VPUSH([r.vfp_ip.value], cond=cond)
        else:
            raise AssertionError('Trying to push an invalid location')

    def regalloc_pop(self, loc, cond=c.AL):
        """Pops the value on top of the stack to loc Can trash the current
        value of the IP register when popping to a stack loc"""
        if loc.is_stack():
            if loc.type != FLOAT:
                scratch_reg = r.ip
            else:
                scratch_reg = r.vfp_ip
            self.regalloc_pop(scratch_reg)
            self.regalloc_mov(scratch_reg, loc)
        elif loc.is_core_reg():
            self.mc.POP([loc.value], cond=cond)
        elif loc.is_vfp_reg():
            self.mc.VPOP([loc.value], cond=cond)
        else:
            raise AssertionError('Trying to pop to an invalid location')

    def malloc_cond(self, nursery_free_adr, nursery_top_adr, size, gcmap):
        assert size & (WORD-1) == 0

        self.mc.gen_load_int(r.r0.value, nursery_free_adr)
        self.mc.LDR_ri(r.r0.value, r.r0.value)

        if check_imm_arg(size):
            self.mc.ADD_ri(r.r1.value, r.r0.value, size)
        else:
            self.mc.gen_load_int(r.r1.value, size)
            self.mc.ADD_rr(r.r1.value, r.r0.value, r.r1.value)

        self.mc.gen_load_int(r.ip.value, nursery_top_adr)
        self.mc.LDR_ri(r.ip.value, r.ip.value)

        self.mc.CMP_rr(r.r1.value, r.ip.value)

        # We load into r0 the address stored at nursery_free_adr We calculate
        # the new value for nursery_free_adr and store in r1 The we load the
        # address stored in nursery_top_adr into IP If the value in r1 is
        # (unsigned) bigger than the one in ip we conditionally call
        # malloc_slowpath in case we called malloc_slowpath, which returns the
        # new value of nursery_free_adr in r1 and the adr of the new object in
        # r0.
        self.push_gcmap(self.mc, gcmap, push=True, cond=c.HI)

        self.mc.BL(self.malloc_slowpath, c=c.HI)

        self.mc.gen_load_int(r.ip.value, nursery_free_adr)
        self.mc.STR_ri(r.r1.value, r.ip.value)

    def malloc_cond_varsize_frame(self, nursery_free_adr, nursery_top_adr,
                                  sizeloc, gcmap):
        if sizeloc is r.r0:
            self.mc.MOV_rr(r.r1.value, r.r0.value)
            sizeloc = r.r1
        self.mc.gen_load_int(r.r0.value, nursery_free_adr)
        self.mc.LDR_ri(r.r0.value, r.r0.value)
        #
        self.mc.ADD_rr(r.r1.value, r.r0.value, sizeloc.value)
        #
        self.mc.gen_load_int(r.ip.value, nursery_top_adr)
        self.mc.LDR_ri(r.ip.value, r.ip.value)

        self.mc.CMP_rr(r.r1.value, r.ip.value)
        #
        self.push_gcmap(self.mc, gcmap, push=True, cond=c.HI)

        self.mc.BL(self.malloc_slowpath, c=c.HI)

        self.mc.gen_load_int(r.ip.value, nursery_free_adr)
        self.mc.STR_ri(r.r1.value, r.ip.value)

    def malloc_cond_varsize(self, kind, nursery_free_adr, nursery_top_adr,
                            lengthloc, itemsize, maxlength, gcmap,
                            arraydescr):
        from rpython.jit.backend.llsupport.descr import ArrayDescr
        assert isinstance(arraydescr, ArrayDescr)

        # lengthloc is the length of the array, which we must not modify!
        assert lengthloc is not r.r0 and lengthloc is not r.r1
        if lengthloc.is_core_reg():
            varsizeloc = lengthloc
        else:
            assert lengthloc.is_stack()
            self.regalloc_mov(lengthloc, r.r1)
            varsizeloc = r.r1
        #
        if check_imm_arg(maxlength):
            self.mc.CMP_ri(varsizeloc.value, maxlength)
        else:
            self.mc.gen_load_int(r.ip.value, maxlength)
            self.mc.CMP_rr(varsizeloc.value, r.ip.value)
        jmp_adr0 = self.mc.currpos()  # jump to (large)
        self.mc.BKPT()
        #
        self.mc.gen_load_int(r.r0.value, nursery_free_adr)
        self.mc.LDR_ri(r.r0.value, r.r0.value)


        if valid_addressing_size(itemsize):
            shiftsize = get_scale(itemsize)
        else:
            shiftsize = self._mul_const_scaled(self.mc, r.lr, varsizeloc,
                                                itemsize)
            varsizeloc = r.lr
        # now varsizeloc is a register != r0.  The size of
        # the variable part of the array is (varsizeloc << shiftsize)
        assert arraydescr.basesize >= self.gc_minimal_size_in_nursery
        constsize = arraydescr.basesize + self.gc_size_of_header
        force_realignment = (itemsize % WORD) != 0
        if force_realignment:
            constsize += WORD - 1
        self.mc.gen_load_int(r.ip.value, constsize)
        # constsize + (varsizeloc << shiftsize)
        self.mc.ADD_rr(r.r1.value, r.ip.value, varsizeloc.value,
                                imm=shiftsize, shifttype=shift.LSL)
        self.mc.ADD_rr(r.r1.value, r.r1.value, r.r0.value)
        if force_realignment:
            self.mc.MVN_ri(r.ip.value, imm=(WORD - 1))
            self.mc.AND_rr(r.r1.value, r.r1.value, r.ip.value)
        # now r1 contains the total size in bytes, rounded up to a multiple
        # of WORD, plus nursery_free_adr
        #
        self.mc.gen_load_int(r.ip.value, nursery_top_adr)
        self.mc.LDR_ri(r.ip.value, r.ip.value)

        self.mc.CMP_rr(r.r1.value, r.ip.value)
        jmp_adr1 = self.mc.currpos()  # jump to (after-call)
        self.mc.BKPT()
        #
        # (large)
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_adr0, WORD)
        pmc.B_offs(currpos, c.GT)
        #
        # save the gcmap
        self.push_gcmap(self.mc, gcmap, push=True)
        #
        if kind == rewrite.FLAG_ARRAY:
            self.mc.gen_load_int(r.r0.value, arraydescr.tid)
            self.regalloc_mov(lengthloc, r.r1)
            self.regalloc_push(imm(itemsize))
            addr = self.malloc_slowpath_varsize
        else:
            if kind == rewrite.FLAG_STR:
                addr = self.malloc_slowpath_str
            else:
                assert kind == rewrite.FLAG_UNICODE
                addr = self.malloc_slowpath_unicode
            self.regalloc_mov(lengthloc, r.r1)
        self.mc.BL(addr)
        #
        jmp_location = self.mc.currpos()  # jump to (done)
        self.mc.BKPT()
        # (after-call)
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_adr1, WORD)
        pmc.B_offs(currpos, c.LS)
        #
        # write down the tid, but not if it's the result of the CALL
        self.mc.gen_load_int(r.ip.value, arraydescr.tid)
        self.mc.STR_ri(r.ip.value, r.r0.value)

        # while we're at it, this line is not needed if we've done the CALL
        self.mc.gen_load_int(r.ip.value, nursery_free_adr)
        self.mc.STR_ri(r.r1.value, r.ip.value)
        # (done)
        # skip instructions after call
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_location, WORD)
        pmc.B_offs(currpos)

    def push_gcmap(self, mc, gcmap, push=False, store=False, cond=c.AL):
        ptr = rffi.cast(lltype.Signed, gcmap)
        if push:
            mc.gen_load_int(r.ip.value, ptr, cond=cond)
            mc.PUSH([r.ip.value], cond=cond)
        else:
            assert store
            ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
            mc.gen_load_int(r.ip.value, ptr, cond=cond)
            mc.STR_ri(r.ip.value, r.fp.value, imm=ofs, cond=cond)

    def pop_gcmap(self, mc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        assert check_imm_arg(ofs)
        mc.gen_load_int(r.ip.value, 0)
        self.store_reg(mc, r.ip, r.fp, ofs)

    def _mul_const_scaled(self, mc, targetreg, sourcereg, itemsize):
        """Produce one operation to do roughly
               targetreg = sourcereg * itemsize
           except that the targetreg may still need shifting by 0,1,2,3.
        """
        if (itemsize & 7) == 0:
            shiftsize = 3
        elif (itemsize & 3) == 0:
            shiftsize = 2
        elif (itemsize & 1) == 0:
            shiftsize = 1
        else:
            shiftsize = 0
        itemsize >>= shiftsize
        #
        if valid_addressing_size(itemsize - 1):
            self.mc.ADD_rr(targetreg.value, sourcereg.value, sourcereg.value,
                                imm=get_scale(itemsize - 1), shifttype=shift.LSL)
        elif valid_addressing_size(itemsize):
            self.mc.LSL_ri(targetreg.value, sourcereg.value,
                    get_scale(itemsize))
        else:
            mc.gen_load_int(targetreg.value, itemsize)
            mc.MUL(targetreg.value, sourcereg.value, targetreg.value)
        #
        return shiftsize

    def simple_call(self, fnloc, arglocs, result_loc=r.r0):
        if result_loc is None:
            result_type = VOID
            result_size = 0
        elif result_loc.is_vfp_reg():
            result_type = FLOAT
            result_size = DOUBLE_WORD
        else:
            result_type = INT
            result_size = WORD
        cb = callbuilder.get_callbuilder(self.cpu, self, fnloc, arglocs,
                                     result_loc, result_type,
                                     result_size)
        cb.emit()

    def simple_call_no_collect(self, fnloc, arglocs):
        cb = callbuilder.get_callbuilder(self.cpu, self, fnloc, arglocs)
        cb.emit_no_collect()


def not_implemented(msg):
    msg = '[ARM/asm] %s\n' % msg
    if we_are_translated():
        llop.debug_print(lltype.Void, msg)
    raise NotImplementedError(msg)


def notimplemented_op(self, op, arglocs, regalloc, fcond):
    print "[ARM/asm] %s not implemented" % op.getopname()
    raise NotImplementedError(op)


asm_operations = [notimplemented_op] * (rop._LAST + 1)
asm_extra_operations = {}

for name, value in ResOpAssembler.__dict__.iteritems():
    if name.startswith('emit_opx_'):
        opname = name[len('emit_opx_'):]
        num = getattr(EffectInfo, 'OS_' + opname.upper())
        asm_extra_operations[num] = value
    elif name.startswith('emit_op_'):
        opname = name[len('emit_op_'):]
        num = getattr(rop, opname.upper())
        asm_operations[num] = value


class BridgeAlreadyCompiled(Exception):
    pass
