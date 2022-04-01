
from rpython.jit.backend.aarch64.arch import WORD, JITFRAME_FIXED_SIZE
from rpython.jit.backend.aarch64.codebuilder import InstrBuilder, OverwritingBuilder
from rpython.jit.backend.aarch64.locations import imm, StackLocation, get_fp_offset
#from rpython.jit.backend.arm.helper.regalloc import VMEM_imm_size
from rpython.jit.backend.aarch64.opassembler import ResOpAssembler
from rpython.jit.backend.aarch64.regalloc import (Regalloc, check_imm_arg,
    operations as regalloc_operations, guard_operations, comp_operations,
    CoreRegisterManager, VFPRegisterManager)
from rpython.jit.backend.aarch64 import registers as r
from rpython.jit.backend.arm import conditions as c
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
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.rjitlog import rjitlog as jl

class AssemblerARM64(ResOpAssembler):
    def __init__(self, cpu, translate_support_code=False):
        ResOpAssembler.__init__(self, cpu, translate_support_code)
        self.failure_recovery_code = [0, 0, 0, 0]
        self.wb_slowpath = [0, 0, 0, 0, 0]
        self.stack_check_slowpath = 0

    def assemble_loop(self, jd_id, unique_id, logger, loopname, inputargs,
                      operations, looptoken, log):
        clt = CompiledLoopToken(self.cpu, looptoken.number)
        clt._debug_nbargs = len(inputargs)
        looptoken.compiled_loop_token = clt

        if not we_are_translated():
            # Arguments should be unique
            assert len(set(inputargs)) == len(inputargs)

        self.setup(looptoken)
        if self.cpu.HAS_CODEMAP:
            self.codemap_builder.enter_portal_frame(jd_id, unique_id,
                                                    self.mc.get_relative_pos())

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

    def assemble_bridge(self, logger, faildescr, inputargs, operations,
                        original_loop_token, log):
        if not we_are_translated():
            # Arguments should be unique
            assert len(set(inputargs)) == len(inputargs)

        self.setup(original_loop_token)
        if self.cpu.HAS_CODEMAP:
            self.codemap_builder.inherit_code_from_position(
                faildescr.adr_jump_offset)

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

    def setup(self, looptoken):
        BaseAssembler.setup(self, looptoken)
        assert self.memcpy_addr != 0, 'setup_once() not called?'
        if we_are_translated():
            self.debug = False
        self.current_clt = looptoken.compiled_loop_token
        self.mc = InstrBuilder()
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
            assert base_ofs < 0x100
            for i, reg in enumerate(regs):
                mc.STR_ri(reg.value, r.fp.value, base_ofs + i * WORD)
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
            for reg in regs:
                mc.STR_di(reg.value, r.fp.value, ofs + base_ofs + reg.value * WORD)

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
            assert base_ofs < 0x100
            for i, reg in enumerate(regs):
                mc.LDR_ri(reg.value, r.fp.value, base_ofs + i * WORD)
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
            for reg in regs:
                mc.LDR_di(reg.value, r.fp.value, ofs + base_ofs + reg.value * WORD)

    def _build_failure_recovery(self, exc, withfloats=False):
        mc = InstrBuilder()
        self._push_all_regs_to_jitframe(mc, [], withfloats)

        if exc:
            # We might have an exception pending.  Load it into r4
            # (this is a register saved across calls)
            mc.gen_load_int(r.x5.value, self.cpu.pos_exc_value())
            mc.LDR_ri(r.x4.value, r.x5.value, 0)
            # clear the exc flags
            mc.gen_load_int(r.x6.value, 0)
            mc.STR_ri(r.x6.value, r.x5.value, 0) # pos_exc_value is still in r5
            mc.gen_load_int(r.x5.value, self.cpu.pos_exception())
            mc.STR_ri(r.x6.value, r.x5.value, 0)
            # save r4 into 'jf_guard_exc'
            offset = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            assert check_imm_arg(abs(offset))
            mc.STR_ri(r.x4.value, r.fp.value, offset)
        # now we return from the complete frame, which starts from
        # _call_header_with_stack_check().  The LEA in _call_footer below
        # throws away most of the frame, including all the PUSHes that we
        # did just above.

        # set return value
        mc.MOV_rr(r.x0.value, r.fp.value)

        self.gen_func_epilog(mc)
        rawstart = mc.materialize(self.cpu, [])
        self.failure_recovery_code[exc + 2 * withfloats] = rawstart

    def propagate_memoryerror_if_reg_is_null(self, reg_loc):
        # see ../x86/assembler.py:genop_discard_check_memory_error()
        self.mc.CMP_ri(reg_loc.value, 0)
        self.mc.B_ofs_cond(6 * 4, c.NE)
        self.mc.B(self.propagate_exception_path)

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
        # all vfp registers.  It takes a single argument which is in x0.
        # It must keep stack alignment accordingly.
        mc = InstrBuilder()
        #
        mc.SUB_ri(r.sp.value, r.sp.value, 2 * WORD)
        mc.STR_ri(r.lr.value, r.sp.value, 0)
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
            exc0, exc1 = r.x19, r.x20
            mc.SUB_ri(r.sp.value, r.sp.value, (len(r.caller_resp) + 2 + len(r.caller_vfp_resp)) * WORD)
            cur_stack = 0
            for i in range(0, len(r.caller_resp), 2):
                mc.STP_rri(r.caller_resp[i].value, r.caller_resp[i + 1].value, r.sp.value, i * WORD)
            cur_stack = len(r.caller_resp)
            mc.STP_rri(exc0.value, exc1.value, r.sp.value, cur_stack * WORD)
            cur_stack += 2
            for i in range(len(r.caller_vfp_resp)):
                mc.STR_di(r.caller_vfp_resp[i].value, r.sp.value, cur_stack * WORD)
                cur_stack += 1

            self._store_and_reset_exception(mc, exc0, exc1)
        mc.BL(func)
        #
        if not for_frame:
            self._pop_all_regs_from_jitframe(mc, [], withfloats, callee_only=True)
        else:
            exc0, exc1 = r.x19, r.x20
            self._restore_exception(mc, exc0, exc1)

            cur_stack = 0
            for i in range(0, len(r.caller_resp), 2):
                mc.LDP_rri(r.caller_resp[i].value, r.caller_resp[i + 1].value, r.sp.value, i * WORD)
            cur_stack = len(r.caller_resp)
            mc.LDP_rri(exc0.value, exc1.value, r.sp.value, cur_stack * WORD)
            cur_stack += 2
            for i in range(len(r.caller_vfp_resp)):
                mc.LDR_di(r.caller_vfp_resp[i].value, r.sp.value, cur_stack * WORD)
                cur_stack += 1

            assert exc0 is not None
            assert exc1 is not None

            mc.ADD_ri(r.sp.value, r.sp.value, (len(r.caller_resp) + 2 + len(r.caller_vfp_resp)) * WORD)

        #
        if withcards:
            # A final TEST8 before the RET, for the caller.  Careful to
            # not follow this instruction with another one that changes
            # the status of the CPU flags!
            mc.LDRB_ri(r.ip0.value, r.x0.value, descr.jit_wb_if_flag_byteofs)
            mc.MOVZ_r_u16(r.ip1.value, 0x80, 0)
            mc.TST_rr_shift(r.ip0.value, r.ip1.value, 0)
        #
        mc.LDR_ri(r.ip1.value, r.sp.value, 0)
        mc.ADD_ri(r.sp.value, r.sp.value, 2 * WORD)
        mc.RET_r(r.ip1.value)
        #
        rawstart = mc.materialize(self.cpu, [])
        if for_frame:
            self.wb_slowpath[4] = rawstart
        else:
            self.wb_slowpath[withcards + 2 * withfloats] = rawstart

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
        mc = InstrBuilder()
        self._push_all_regs_to_jitframe(mc, [], self.cpu.supports_floats)
        # this is the gcmap stored by push_gcmap(mov=True) in _check_stack_frame
        # and the expected_size pushed in _check_stack_frame
        # pop the values passed on the stack, gcmap -> r0, expected_size -> r1
        mc.LDP_rri(r.x0.value, r.x1.value, r.sp.value, 0)
        
        mc.STR_ri(r.lr.value, r.sp.value, 0)

        # store the current gcmap(r0) in the jitframe
        gcmap_ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.STR_ri(r.x0.value, r.fp.value, gcmap_ofs)

        # set first arg, which is the old jitframe address
        mc.MOV_rr(r.x0.value, r.fp.value)

        # store a possibly present exception
        self._store_and_reset_exception(mc, None, r.x19, on_frame=True)

        # call realloc_frame, it takes two arguments
        # arg0: the old jitframe
        # arg1: the new size
        #
        mc.BL(self.cpu.realloc_frame)

        # set fp to the new jitframe returned from the previous call
        mc.MOV_rr(r.fp.value, r.x0.value)

        # restore a possibly present exception
        self._restore_exception(mc, None, r.x19)

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self._load_shadowstack_top(mc, r.x19, gcrootmap)
            # store the new jitframe addr in the shadowstack
            mc.SUB_ri(r.x19.value, r.x19.value, WORD)
            mc.STR_ri(r.x0.value, r.x19.value, 0)

        # reset the jf_gcmap field in the jitframe
        mc.gen_load_int(r.ip0.value, 0)
        mc.STR_ri(r.ip0.value, r.fp.value, gcmap_ofs)

        # restore registers
        self._pop_all_regs_from_jitframe(mc, [], self.cpu.supports_floats)

        # return
        mc.LDR_ri(r.lr.value, r.sp.value, 0)
        mc.ADD_ri(r.sp.value, r.sp.value, 2*WORD)
        mc.RET_r(r.lr.value)
        self._frame_realloc_slowpath = mc.materialize(self.cpu, [])        

    def _load_shadowstack_top(self, mc, reg, gcrootmap):
        rst = gcrootmap.get_root_stack_top_addr()
        mc.gen_load_int(reg.value, rst)
        self.load_reg(mc, reg, reg)
        return rst

    def _store_and_reset_exception(self, mc, excvalloc=None, exctploc=None,
                                   on_frame=False):
        """ Resest the exception. If excvalloc is None, then store it on the
        frame in jf_guard_exc
        """
        assert excvalloc is not r.ip0
        assert exctploc is not r.ip0
        tmpreg = r.ip1
        mc.gen_load_int(r.ip0.value, self.cpu.pos_exc_value())
        if excvalloc is not None: # store
            assert excvalloc.is_core_reg()
            self.load_reg(mc, excvalloc, r.ip0)
        if on_frame:
            # store exc_value in JITFRAME
            ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            assert check_imm_arg(ofs)
            #
            self.load_reg(mc, r.ip0, r.ip0, helper=tmpreg)
            #
            self.store_reg(mc, r.ip0, r.fp, ofs, helper=tmpreg)
        if exctploc is not None:
            # store pos_exception in exctploc
            assert exctploc.is_core_reg()
            mc.gen_load_int(r.ip0.value, self.cpu.pos_exception())
            self.load_reg(mc, exctploc, r.ip0, helper=tmpreg)

        if on_frame or exctploc is not None:
            mc.gen_load_int(r.ip0.value, self.cpu.pos_exc_value())

        # reset exception
        mc.gen_load_int(tmpreg.value, 0)

        self.store_reg(mc, tmpreg, r.ip0, 0)

        mc.gen_load_int(r.ip0.value, self.cpu.pos_exception())
        self.store_reg(mc, tmpreg, r.ip0, 0)

    def _restore_exception(self, mc, excvalloc, exctploc):
        assert excvalloc is not r.ip0
        assert exctploc is not r.ip0
        mc.gen_load_int(r.ip0.value, self.cpu.pos_exc_value())
        if excvalloc is not None:
            assert excvalloc.is_core_reg()
            self.store_reg(mc, excvalloc, r.ip0)
        else:
            assert exctploc is not r.fp
            # load exc_value from JITFRAME and put it in pos_exc_value
            ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            self.load_reg(mc, r.ip1, r.fp, ofs)
            self.store_reg(mc, r.ip1, r.ip0)
            # reset exc_value in the JITFRAME
            mc.gen_load_int(r.ip1.value, 0)
            self.store_reg(mc, r.ip1, r.fp, ofs)

        # restore pos_exception from exctploc register
        mc.gen_load_int(r.ip0.value, self.cpu.pos_exception())
        self.store_reg(mc, exctploc, r.ip0)

    def _build_propagate_exception_path(self):
        mc = InstrBuilder()
        self._store_and_reset_exception(mc, r.x0)
        ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
        # make sure ofs fits into a register
        assert check_imm_arg(ofs)
        self.store_reg(mc, r.x0, r.fp, ofs)
        propagate_exception_descr = rffi.cast(lltype.Signed,
                  cast_instance_to_gcref(self.cpu.propagate_exception_descr))
        # put propagate_exception_descr into frame
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        # make sure ofs fits into a register
        assert check_imm_arg(ofs)
        mc.gen_load_int(r.x0.value, propagate_exception_descr)
        self.store_reg(mc, r.x0, r.fp, ofs)
        mc.MOV_rr(r.x0.value, r.fp.value)
        self.gen_func_epilog(mc)
        rawstart = mc.materialize(self.cpu, [])
        self.propagate_exception_path = rawstart

    def _build_cond_call_slowpath(self, supports_floats, callee_only):
        """ This builds a general call slowpath, for whatever call happens to
        come.

        The address of function to call comes in ip1. the result is also stored
        in ip1 or ivfp
        """
        mc = InstrBuilder()
        #
        self._push_all_regs_to_jitframe(mc, [], self.cpu.supports_floats, callee_only)
        ## args are in their respective positions
        mc.SUB_ri(r.sp.value, r.sp.value, 2 * WORD)
        mc.STR_ri(r.ip0.value, r.sp.value, WORD)
        mc.STR_ri(r.lr.value, r.sp.value, 0)
        mc.BLR_r(r.ip1.value)
        # callee saved
        self._reload_frame_if_necessary(mc) # <- this will not touch x0
        mc.MOV_rr(r.ip1.value, r.x0.value)
        self._pop_all_regs_from_jitframe(mc, [], supports_floats,
                                         callee_only) # <- this does not touch ip1
        # return
        mc.LDR_ri(r.ip0.value, r.sp.value, 0)
        mc.ADD_ri(r.sp.value, r.sp.value, 2 * WORD)
        mc.RET_r(r.ip0.value)
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
        mc = InstrBuilder()
        #
        self._push_all_regs_to_jitframe(mc, [r.x0, r.x1], True)
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
            # At this point we know that the values we need to compute the size
            # are stored in x0 and x1.
            mc.SUB_rr(r.x0.value, r.x1.value, r.x0.value) # compute the size we want

            if hasattr(self.cpu.gc_ll_descr, 'passes_frame'):
                mc.MOV_rr(r.x1.value, r.fp.value)
        elif kind == 'str' or kind == 'unicode':
            mc.MOV_rr(r.x0.value, r.x1.value)
        else:  # var
            # tid is in x0
            # length is in x1
            # gcmap in ip1
            # itemsize in ip2
            mc.MOV_rr(r.x2.value, r.x1.value)
            mc.MOV_rr(r.x1.value, r.x0.value)
            mc.MOV_rr(r.x0.value, r.ip2.value) # load itemsize, ip2 now free
        # store the gc pattern
        ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.STR_ri(r.ip1.value, r.fp.value, ofs)
        #
        mc.SUB_ri(r.sp.value, r.sp.value, 2 * WORD)
        mc.STR_ri(r.lr.value, r.sp.value, 0)
        #
        mc.BL(addr)
        #
        # If the slowpath malloc failed, we raise a MemoryError that
        # always interrupts the current loop, as a "good enough"
        # approximation.
        mc.CMP_ri(r.x0.value, 0)
        mc.B_ofs_cond(4 * 6, c.NE)
        mc.B(self.propagate_exception_path)
        # jump here
        self._reload_frame_if_necessary(mc)
        self._pop_all_regs_from_jitframe(mc, [r.x0, r.x1], self.cpu.supports_floats)
        #
        nursery_free_adr = self.cpu.gc_ll_descr.get_nursery_free_addr()
        mc.gen_load_int(r.x1.value, nursery_free_adr)
        mc.LDR_ri(r.x1.value, r.x1.value, 0)
        # clear the gc pattern
        mc.gen_load_int(r.ip0.value, 0)
        self.store_reg(mc, r.ip0, r.fp, ofs)
        # return
        mc.LDR_ri(r.lr.value, r.sp.value, 0)
        mc.ADD_ri(r.sp.value, r.sp.value, 2 * WORD)
        mc.RET_r(r.lr.value)

        #
        rawstart = mc.materialize(self.cpu, [])
        return rawstart

    def malloc_cond(self, nursery_free_adr, nursery_top_adr, size, gcmap):
        assert size & (WORD-1) == 0

        self.mc.gen_load_int(r.x0.value, nursery_free_adr)
        self.mc.LDR_ri(r.x0.value, r.x0.value, 0)

        if check_imm_arg(size):
            self.mc.ADD_ri(r.x1.value, r.x0.value, size)
        else:
            self.mc.gen_load_int(r.x1.value, size)
            self.mc.ADD_rr(r.x1.value, r.x0.value, r.x1.value)

        self.mc.gen_load_int(r.ip0.value, nursery_top_adr)
        self.mc.LDR_ri(r.ip0.value, r.ip0.value, 0)

        self.mc.CMP_rr(r.x1.value, r.ip0.value)

        # We load into r0 the address stored at nursery_free_adr We calculate
        # the new value for nursery_free_adr and store in r1 The we load the
        # address stored in nursery_top_adr into IP If the value in r1 is
        # (unsigned) bigger than the one in ip we conditionally call
        # malloc_slowpath in case we called malloc_slowpath, which returns the
        # new value of nursery_free_adr in r1 and the adr of the new object in
        # r0.

        self.mc.B_ofs_cond(10 * 4, c.LS) # 4 for gcmap load, 5 for BL, 1 for B_ofs_cond
        self.mc.gen_load_int_full(r.ip1.value, rffi.cast(lltype.Signed, gcmap))

        self.mc.BL(self.malloc_slowpath)

        self.mc.gen_load_int(r.ip0.value, nursery_free_adr)
        self.mc.STR_ri(r.x1.value, r.ip0.value, 0)

    def malloc_cond_varsize_frame(self, nursery_free_adr, nursery_top_adr,
                                  sizeloc, gcmap):
        if sizeloc is r.x0:
            self.mc.MOV_rr(r.x1.value, r.x0.value)
            sizeloc = r.x1
        self.mc.gen_load_int(r.x0.value, nursery_free_adr)
        self.mc.LDR_ri(r.x0.value, r.x0.value, 0)
        #
        self.mc.ADD_rr(r.x1.value, r.x0.value, sizeloc.value)
        #
        self.mc.gen_load_int(r.ip0.value, nursery_top_adr)
        self.mc.LDR_ri(r.ip0.value, r.ip0.value, 0)

        self.mc.CMP_rr(r.x1.value, r.ip0.value)
        #
        self.mc.B_ofs_cond(40, c.LS) # see calculations in malloc_cond
        self.mc.gen_load_int_full(r.ip1.value, rffi.cast(lltype.Signed, gcmap))

        self.mc.BL(self.malloc_slowpath)

        self.mc.gen_load_int(r.ip0.value, nursery_free_adr)
        self.mc.STR_ri(r.x1.value, r.ip0.value, 0)

    def malloc_cond_varsize(self, kind, nursery_free_adr, nursery_top_adr,
                            lengthloc, itemsize, maxlength, gcmap,
                            arraydescr):
        from rpython.jit.backend.llsupport.descr import ArrayDescr
        assert isinstance(arraydescr, ArrayDescr)

        # lengthloc is the length of the array, which we must not modify!
        assert lengthloc is not r.x0 and lengthloc is not r.x1
        if lengthloc.is_core_reg():
            varsizeloc = lengthloc
        else:
            assert lengthloc.is_stack()
            self.regalloc_mov(lengthloc, r.x1)
            varsizeloc = r.x1
        #
        if check_imm_arg(maxlength):
            self.mc.CMP_ri(varsizeloc.value, maxlength)
        else:
            self.mc.gen_load_int(r.ip0.value, maxlength)
            self.mc.CMP_rr(varsizeloc.value, r.ip0.value)
        jmp_adr0 = self.mc.currpos()  # jump to (large)
        self.mc.BRK()
        #
        self.mc.gen_load_int(r.x0.value, nursery_free_adr)
        self.mc.LDR_ri(r.x0.value, r.x0.value, 0)


        if valid_addressing_size(itemsize):
            shiftsize = get_scale(itemsize)
        else:
            shiftsize = self._mul_const_scaled(self.mc, r.lr, varsizeloc,
                                                itemsize)
            varsizeloc = r.lr
        # now varsizeloc is a register != x0.  The size of
        # the variable part of the array is (varsizeloc << shiftsize)
        assert arraydescr.basesize >= self.gc_minimal_size_in_nursery
        constsize = arraydescr.basesize + self.gc_size_of_header
        force_realignment = (itemsize % WORD) != 0
        if force_realignment:
            constsize += WORD - 1
        self.mc.gen_load_int(r.ip0.value, constsize)
        # constsize + (varsizeloc << shiftsize)
        self.mc.ADD_rr_shifted(r.x1.value, r.ip0.value, varsizeloc.value,
                               shiftsize)
        self.mc.ADD_rr(r.x1.value, r.x1.value, r.x0.value)
        if force_realignment:
            # -WORD = 0xfffffffffffffff8
            self.mc.gen_load_int(r.ip0.value, -WORD)
            self.mc.AND_rr(r.x1.value, r.x1.value, r.ip0.value)
        # now x1 contains the total size in bytes, rounded up to a multiple
        # of WORD, plus nursery_free_adr
        #
        self.mc.gen_load_int(r.ip0.value, nursery_top_adr)
        self.mc.LDR_ri(r.ip0.value, r.ip0.value, 0)

        self.mc.CMP_rr(r.x1.value, r.ip0.value)
        jmp_adr1 = self.mc.currpos()  # jump to (after-call)
        self.mc.BRK()
        #
        # (large)
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_adr0, WORD)
        pmc.B_ofs_cond(currpos - jmp_adr0, c.GT)
        #
        # save the gcmap
        self.mc.gen_load_int_full(r.ip1.value, rffi.cast(lltype.Signed, gcmap))
        #

        if kind == rewrite.FLAG_ARRAY:
            self.mc.gen_load_int(r.x0.value, arraydescr.tid)
            self.regalloc_mov(lengthloc, r.x1)
            self.mc.gen_load_int(r.ip2.value, itemsize)
            addr = self.malloc_slowpath_varsize
        else:
            if kind == rewrite.FLAG_STR:
                addr = self.malloc_slowpath_str
            else:
                assert kind == rewrite.FLAG_UNICODE
                addr = self.malloc_slowpath_unicode
            self.regalloc_mov(lengthloc, r.x1)
        self.mc.BL(addr)
        #
        jmp_location = self.mc.currpos()  # jump to (done)
        self.mc.BRK()
        # (after-call)
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_adr1, WORD)
        pmc.B_ofs_cond(currpos - jmp_adr1, c.LS)
        #
        # write down the tid, but not if it's the result of the CALL
        self.mc.gen_load_int(r.ip0.value, arraydescr.tid)
        self.mc.STR_ri(r.ip0.value, r.x0.value, 0)

        # while we're at it, this line is not needed if we've done the CALL
        self.mc.gen_load_int(r.ip0.value, nursery_free_adr)
        self.mc.STR_ri(r.x1.value, r.ip0.value, 0)
        # (done)
        # skip instructions after call
        currpos = self.mc.currpos()
        pmc = OverwritingBuilder(self.mc, jmp_location, WORD)
        pmc.B_ofs(currpos - jmp_location)

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
            self.mc.ADD_rr_shifted(targetreg.value, sourcereg.value, sourcereg.value,
                                   get_scale(itemsize - 1))
        elif valid_addressing_size(itemsize):
            self.mc.LSL_ri(targetreg.value, sourcereg.value,
                    get_scale(itemsize))
        else:
            mc.gen_load_int(targetreg.value, itemsize)
            mc.MUL_rr(targetreg.value, sourcereg.value, targetreg.value)
        #
        return shiftsize


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
        mc = InstrBuilder()
        # save argument registers and return address
        mc.SUB_ri(r.sp.value, r.sp.value, (len(r.argument_regs) + 2) * WORD)
        mc.STR_ri(r.lr.value, r.sp.value, 0)
        for i in range(0, len(r.argument_regs), 2):
            mc.STP_rri(r.argument_regs[i].value, r.argument_regs[i + 1].value,
                       r.sp.value, (i + 2) * WORD)
        # stack is aligned here
        # Pass current stack pointer as argument to the call
        mc.SUB_ri(r.x0.value, r.sp.value, 0)
        #
        mc.BL(slowpathaddr)

        # check for an exception
        mc.gen_load_int(r.x0.value, self.cpu.pos_exception())
        mc.LDR_ri(r.x0.value, r.x0.value, 0)
        mc.TST_rr_shift(r.x0.value, r.x0.value, 0)
        #
        # restore registers and return
        # We check for c.EQ here, meaning all bits zero in this case

        jmp = mc.currpos()
        mc.BRK()

        for i in range(0, len(r.argument_regs), 2):
            mc.LDP_rri(r.argument_regs[i].value, r.argument_regs[i + 1].value,
                       r.sp.value, (i + 2) * WORD)
        mc.LDR_ri(r.ip0.value, r.sp.value, 0)
        mc.ADD_ri(r.sp.value, r.sp.value, (len(r.argument_regs) + 2) * WORD)
        mc.RET_r(r.ip0.value)

        # jump here

        pmc = OverwritingBuilder(mc, jmp, WORD)
        pmc.B_ofs_cond(mc.currpos() - jmp, c.NE)

        mc.ADD_ri(r.sp.value, r.sp.value, (len(r.argument_regs) + 2) * WORD)
        mc.B(self.propagate_exception_path)
        #

        rawstart = mc.materialize(self.cpu, [])
        self.stack_check_slowpath = rawstart

    def _check_frame_depth_debug(self, mc):
        pass

    def _check_frame_depth(self, mc, gcmap, expected_size=-1):
        """ check if the frame is of enough depth to follow this bridge.
        Otherwise reallocate the frame in a helper.
        There are other potential solutions
        to that, but this one does not sound too bad.
        """
        descrs = self.cpu.gc_ll_descr.getframedescrs(self.cpu)
        ofs = self.cpu.unpack_fielddescr(descrs.arraydescr.lendescr)
        mc.LDR_ri(r.ip0.value, r.fp.value, ofs)
        stack_check_cmp_ofs = mc.currpos()
        if expected_size == -1:
            for _ in range(mc.get_max_size_of_gen_load_int()):
                mc.NOP()
        else:
            mc.gen_load_int(r.ip1.value, expected_size)
        mc.CMP_rr(r.ip0.value, r.ip1.value)

        jg_location = mc.currpos()
        mc.BRK()

        # the size value is still stored in ip1
        mc.SUB_ri(r.sp.value, r.sp.value, 2*WORD)
        mc.STR_ri(r.ip1.value, r.sp.value, WORD)

        mc.gen_load_int(r.ip0.value, rffi.cast(lltype.Signed, gcmap))
        mc.STR_ri(r.ip0.value, r.sp.value, 0)

        mc.BL(self._frame_realloc_slowpath)

        # patch jg_location above
        currpos = mc.currpos()
        pmc = OverwritingBuilder(mc, jg_location, WORD)
        pmc.B_ofs_cond(currpos - jg_location, c.GE)

        self.frame_depth_to_patch.append(stack_check_cmp_ofs)

    def update_frame_depth(self, frame_depth):
        baseofs = self.cpu.get_baseofs_of_frame_field()
        self.current_clt.frame_info.update_frame_depth(baseofs, frame_depth)

    def _reload_frame_if_necessary(self, mc):
        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            rst = gcrootmap.get_root_stack_top_addr()
            mc.gen_load_int(r.ip0.value, rst)
            self.load_reg(mc, r.ip0, r.ip0)
            mc.SUB_ri(r.ip0.value, r.ip0.value, WORD)
            mc.LDR_ri(r.fp.value, r.ip0.value, 0)
        wbdescr = self.cpu.gc_ll_descr.write_barrier_descr
        if gcrootmap and wbdescr:
            # frame never uses card marking, so we enforce this is not
            # an array
            self._write_barrier_fastpath(mc, wbdescr, [r.fp], array=False,
                                         is_frame=True)

    def generate_quick_failure(self, guardtok):
        startpos = self.mc.currpos()
        faildescrindex, target = self.store_info_on_descr(startpos, guardtok)
        self.load_from_gc_table(r.ip0.value, faildescrindex)
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.store_reg(self.mc, r.ip0, r.fp, ofs)
        self.push_gcmap(self.mc, gcmap=guardtok.gcmap)
        assert target
        self.mc.BL(target)
        return startpos

    def push_gcmap(self, mc, gcmap, store=True):
        assert store
        ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        ptr = rffi.cast(lltype.Signed, gcmap)
        mc.gen_load_int(r.ip0.value, ptr)
        self.store_reg(mc, r.ip0, r.fp, ofs)

    def pop_gcmap(self, mc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.gen_load_int(r.ip0.value, 0)
        self.store_reg(mc, r.ip0, r.fp, ofs)

    def write_pending_failure_recoveries(self):
        for tok in self.pending_guards:
            #generate the exit stub and the encoded representation
            tok.pos_recovery_stub = self.generate_quick_failure(tok)

    def reserve_gcref_table(self, allgcrefs):
        gcref_table_size = len(allgcrefs) * WORD
        # align to a multiple of 16 and reserve space at the beginning
        # of the machine code for the gc table.  This lets us write
        # machine code with relative addressing (LDR literal).
        gcref_table_size = (gcref_table_size + 15) & ~15
        mc = self.mc
        assert mc.get_relative_pos() == 0
        for i in range(gcref_table_size):
            mc.writechar('\x00')
        self.setup_gcrefs_list(allgcrefs)

    def patch_gcref_table(self, looptoken, rawstart):
        # the gc table is at the start of the machine code
        self.gc_table_addr = rawstart
        tracer = self.cpu.gc_ll_descr.make_gcref_tracer(rawstart,
                                                        self._allgcrefs)
        gcreftracers = self.get_asmmemmgr_gcreftracers(looptoken)
        gcreftracers.append(tracer)    # keepalive
        self.teardown_gcrefs_list()

    def patch_stack_checks(self, framedepth, rawstart):
        for ofs in self.frame_depth_to_patch:
            mc = InstrBuilder()
            mc.gen_load_int(r.ip1.value, framedepth)
            mc.copy_to_raw_memory(ofs + rawstart)

    def load_from_gc_table(self, regnum, index):
        address_in_buffer = index * WORD   # at the start of the buffer
        p_location = self.mc.get_relative_pos(break_basic_block=False)
        offset = address_in_buffer - p_location
        self.mc.LDR_r_literal(regnum, offset)

    def materialize_loop(self, looptoken):
        self.datablockwrapper.done()      # finish using cpu.asmmemmgr
        self.datablockwrapper = None
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        size = self.mc.get_relative_pos() 
        res = self.mc.materialize(self.cpu, allblocks,
                                   self.cpu.gc_ll_descr.gcrootmap)
        self.cpu.codemap.register_codemap(
            self.codemap_builder.get_final_bytecode(res, size))
        return res

    def patch_trace(self, faildescr, looptoken, bridge_addr, regalloc):
        b = InstrBuilder()
        patch_addr = faildescr.adr_jump_offset
        assert patch_addr != 0
        b.BL(bridge_addr)
        b.copy_to_raw_memory(patch_addr)
        faildescr.adr_jump_offset = 0

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
                # overwrite the generate BRK with a B_offs to the pos of the
                # stub
                mc = InstrBuilder()
                mc.B_ofs_cond(relative_offset, c.get_opposite_of(tok.fcond))
                mc.copy_to_raw_memory(guard_pos)
                if tok.extra_offset != -1:
                    mc = InstrBuilder()
                    relative_offset = tok.pos_recovery_stub - tok.extra_offset
                    guard_pos = block_start + tok.extra_offset
                    mc.B_ofs_cond(relative_offset, c.get_opposite_of(tok.extra_cond))
                    mc.copy_to_raw_memory(guard_pos)
            else:
                clt.invalidate_positions.append((guard_pos, relative_offset))

    def fixup_target_tokens(self, rawstart):
        for targettoken in self.target_tokens_currently_compiling:
            targettoken._ll_loop_code += rawstart
        self.target_tokens_currently_compiling = None

    def _call_header_with_stack_check(self):
        self._call_header()
        if self.stack_check_slowpath == 0:
            pass                # no stack check (e.g. not translated)
        else:
            endaddr, lengthaddr, _ = self.cpu.insert_stack_check()
            # load stack end
            self.mc.gen_load_int(r.lr.value, endaddr)           # load lr, [end]
            self.mc.LDR_ri(r.lr.value, r.lr.value, 0)             # LDR lr, lr
            # load stack length
            self.mc.gen_load_int(r.ip1.value, lengthaddr)        # load ip1, lengh
            self.mc.LDR_ri(r.ip1.value, r.ip1.value, 0)             # ldr ip1, *lengh
            # calculate ofs
            self.mc.SUB_ri(r.ip0.value, r.sp.value, 0) # ip0 = sp
                                                       # otherwise we can't use sp
            self.mc.SUB_rr(r.lr.value, r.lr.value, r.ip0.value) # lr = lr - ip0
            # if ofs
            self.mc.CMP_rr(r.lr.value, r.ip1.value)             # CMP ip0, ip1
            pos = self.mc.currpos()
            self.mc.BRK()
            self.mc.BL(self.stack_check_slowpath)                 # call if ip0 > ip1
            pmc = OverwritingBuilder(self.mc, pos, WORD)
            pmc.B_ofs_cond(self.mc.currpos() - pos, c.LS)

    def _call_header(self):
        stack_size = (len(r.callee_saved_registers) + 8) * WORD
        self.mc.STP_rr_preindex(r.lr.value, r.fp.value, r.sp.value, -stack_size)
        for i in range(0, len(r.callee_saved_registers), 2):
            self.mc.STP_rri(r.callee_saved_registers[i].value,
                            r.callee_saved_registers[i + 1].value,
                            r.sp.value,
                            (i + 8) * WORD)

        if self.cpu.translate_support_code:
            self._call_header_vmprof()
        
        self.saved_threadlocal_addr = 3 * WORD   # at offset 3 from location 'sp'
        self.mc.STR_ri(r.x1.value, r.sp.value, 3 * WORD)

        # set fp to point to the JITFRAME, passed in argument 'x0'
        self.mc.MOV_rr(r.fp.value, r.x0.value)
        #

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self.gen_shadowstack_header(gcrootmap)

    def _call_header_vmprof(self):
        # this uses values 0, 1 and 2 on stack as vmprof next
        from rpython.rlib.rvmprof.rvmprof import cintf, VMPROF_JITTED_TAG

        # tloc = address of pypy_threadlocal_s
        tloc = r.x1
        # ip0 = current value of vmprof_tl_stack
        offset = cintf.vmprof_tl_stack.getoffset()
        self.mc.LDR_ri(r.ip0.value, tloc.value, offset)
        # stack->next = old
        self.mc.STR_ri(r.ip0.value, r.sp.value, 4 * WORD)
        # stack->value = my sp
        self.mc.ADD_ri(r.ip1.value, r.sp.value, 0)
        self.mc.STR_ri(r.ip1.value, r.sp.value, (4 + 1) * WORD)
        # stack->kind = VMPROF_JITTED_TAG
        self.mc.gen_load_int(r.ip0.value, VMPROF_JITTED_TAG)
        self.mc.STR_ri(r.ip0.value, r.sp.value, (4 + 2) * WORD)
        # save in vmprof_tl_stack the new eax
        self.mc.ADD_ri(r.ip0.value, r.sp.value, 4 * WORD)
        self.mc.STR_ri(r.ip0.value, tloc.value, offset)


    def _assemble(self, regalloc, inputargs, operations):
        #self.guard_success_cc = c.cond_none
        regalloc.compute_hint_frame_locations(operations)
        self._walk_operations(inputargs, operations, regalloc)
        #assert self.guard_success_cc == c.cond_none
        frame_depth = regalloc.get_final_frame_depth()
        jump_target_descr = regalloc.jump_target_descr
        if jump_target_descr is not None:
            tgt_depth = jump_target_descr._arm_clt.frame_info.jfi_frame_depth
            target_frame_depth = tgt_depth - JITFRAME_FIXED_SIZE
            frame_depth = max(frame_depth, target_frame_depth)
        return frame_depth

    def _walk_operations(self, inputargs, operations, regalloc):
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
                regalloc.force_spill_var(op.getarg(0))
            elif ((rop.returns_bool_result(opnum) or op.is_ovf()) and 
                  i < len(operations) - 1 and
                  regalloc.next_op_can_accept_cc(operations, i) or
                                               operations[i].is_ovf()):
                if operations[i].is_ovf():
                    assert operations[i + 1].getopnum() in [rop.GUARD_OVERFLOW,
                                                            rop.GUARD_NO_OVERFLOW]
                guard_op = operations[i + 1]
                guard_num = guard_op.getopnum()
                arglocs, fcond = guard_operations[guard_num](regalloc, guard_op, op)
                if arglocs is not None:
                    asm_guard_operations[guard_num](self, op, guard_op, fcond, arglocs)
                regalloc.next_instruction() # advance one more
                if guard_op.is_guard(): # can be also cond_call
                    regalloc.possibly_free_vars(guard_op.getfailargs())
                regalloc.possibly_free_vars_for_op(guard_op)
            elif (rop.is_call_may_force(op.getopnum()) or
                  rop.is_call_release_gil(op.getopnum()) or
                  rop.is_call_assembler(op.getopnum())):
                guard_op = operations[i + 1] # has to exist
                guard_num = guard_op.getopnum()
                assert guard_num in (rop.GUARD_NOT_FORCED, rop.GUARD_NOT_FORCED_2)
                arglocs, fcond = guard_operations[guard_num](regalloc, guard_op, op)
                if arglocs is not None:
                    asm_guard_operations[guard_num](self, op, guard_op, fcond, arglocs)
                # fcond is abused here to pass the number of args
                regalloc.next_instruction() # advance one more
                regalloc.possibly_free_vars(guard_op.getfailargs())
                regalloc.possibly_free_vars_for_op(guard_op)
            else:
                arglocs = regalloc_operations[opnum](regalloc, op)
                if arglocs is not None:
                    asm_operations[opnum](self, op, arglocs)
            if rop.is_guard(opnum):
                regalloc.possibly_free_vars(op.getfailargs())
            if op.type != 'v':
                regalloc.possibly_free_var(op)
            regalloc.possibly_free_vars_for_op(op)
            regalloc.free_temp_vars()
            regalloc._check_invariants()
        if not we_are_translated():
            self.mc.BRK()
        self.mc.mark_op(None)  # end of the loop
        regalloc.operations = None

    def dispatch_comparison(self, op):
        opnum = op.getopnum()
        arglocs = comp_operations[opnum](self._regalloc, op, True)
        assert arglocs is not None
        return asm_comp_operations[opnum](self, op, arglocs)

    # regalloc support
    def load(self, loc, value):
        """load an immediate value into a register"""
        assert (loc.is_core_reg() and value.is_imm()
                    or loc.is_vfp_reg() and value.is_imm_float())
        if value.is_imm():
            self.mc.gen_load_int(loc.value, value.getint())
        elif value.is_imm_float():
            self.mc.gen_load_int(r.ip0.value, value.getint())
            self.mc.LDR_di(loc.value, r.ip0.value, 0)

    def _mov_stack_to_loc(self, prev_loc, loc):
        offset = prev_loc.value
        if loc.is_core_reg():
            assert prev_loc.type != FLOAT, 'trying to load from an \
                incompatible location into a core register'
            # unspill a core register
            assert 0 <= offset <= (1<<15) - 1
            self.mc.LDR_ri(loc.value, r.fp.value, offset)
            return
        if loc.is_vfp_reg():
            assert prev_loc.type == FLOAT, 'trying to load from an \
                incompatible location into a float register'
            assert 0 <= offset <= (1 << 15) - 1
            self.mc.LDR_di(loc.value, r.fp.value, offset)
            return
        assert False
        # elif loc.is_vfp_reg():
        #     assert prev_loc.type == FLOAT, 'trying to load from an \
        #         incompatible location into a float register'
        #     # load spilled value into vfp reg
        #     is_imm = check_imm_arg(offset)
        #     helper, save = self.get_tmp_reg()
        #     save_helper = not is_imm and save
        # elif loc.is_raw_sp():
        #     assert (loc.type == prev_loc.type == FLOAT
        #             or (loc.type != FLOAT and prev_loc.type != FLOAT))
        #     tmp = loc
        #     if loc.is_float():
        #         loc = r.vfp_ip
        #     else:
        #         loc, save_helper = self.get_tmp_reg()
        #         assert not save_helper
        #     helper, save_helper = self.get_tmp_reg([loc])
        #     assert not save_helper
        # else:
        #     assert 0, 'unsupported case'

        # if save_helper:
        #     self.mc.PUSH([helper.value], cond=cond)
        # self.load_reg(self.mc, loc, r.fp, offset, cond=cond, helper=helper)
        # if save_helper:
        #     self.mc.POP([helper.value], cond=cond)

    def _mov_reg_to_loc(self, prev_loc, loc):
        if loc.is_core_reg():
            self.mc.MOV_rr(loc.value, prev_loc.value)
        elif loc.is_stack():
            self.mc.STR_ri(prev_loc.value, r.fp.value, loc.value)
        else:
            assert False

    def _mov_imm_to_loc(self, prev_loc, loc):
        if loc.is_core_reg():
            self.mc.gen_load_int(loc.value, prev_loc.value)
        elif loc.is_stack():
            self.mc.gen_load_int(r.ip0.value, prev_loc.value)
            self.mc.STR_ri(r.ip0.value, r.fp.value, loc.value)
        else:
            assert False

    def new_stack_loc(self, i, tp):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        return StackLocation(i, get_fp_offset(base_ofs, i), tp)

    def mov_loc_to_raw_stack(self, loc, pos):
        if loc.is_core_reg():
            self.mc.STR_ri(loc.value, r.sp.value, pos)
        elif loc.is_stack():
            self.mc.LDR_ri(r.ip0.value, r.fp.value, loc.value)
            self.mc.STR_ri(r.ip0.value, r.sp.value, pos)
        elif loc.is_vfp_reg():
            self.mc.STR_di(loc.value, r.sp.value, pos)
        elif loc.is_imm():
            self.mc.gen_load_int(r.ip0.value, loc.value)
            self.mc.STR_ri(r.ip0.value, r.sp.value, pos)
        else:
            assert False, "wrong loc"

    def mov_raw_stack_to_loc(self, pos, loc):
        if loc.is_core_reg():
            self.mc.LDR_ri(loc.value, r.sp.value, pos)
        elif loc.is_stack():
            self.mc.LDR_ri(r.ip0.value, r.sp.value, pos)
            self.mc.STR_ri(r.ip0.value, r.fp.value, loc.value)
        elif loc.is_vfp_reg():
            self.mc.LDR_di(loc.value, r.sp.value, pos)
        else:
            assert False, "wrong loc"

    def _mov_imm_float_to_loc(self, prev_loc, loc):
        if loc.is_vfp_reg():
            self.load(loc, prev_loc)
        elif loc.is_stack():
            self.load(r.vfp_ip, prev_loc)
            self._mov_vfp_reg_to_loc(r.vfp_ip, loc)
        else:
            assert False, "wrong loc"

    def _mov_vfp_reg_to_loc(self, prev_loc, loc):
        if loc.is_stack():
            self.mc.STR_di(prev_loc.value, r.fp.value, loc.value)
        elif loc.is_vfp_reg():
            self.mc.FMOV_dd(loc.value, prev_loc.value)
        else:
            assert False, "wrong loc"

    def push_locations(self, locs):
        if not locs:
            return
        depth = len(locs) * WORD
        depth += depth & WORD # align
        self.mc.SUB_ri(r.sp.value, r.sp.value, depth)
        for i, loc in enumerate(locs):
            self.mov_loc_to_raw_stack(loc, i * WORD)

    def pop_locations(self, locs):
        if not locs:
            return
        depth = len(locs) * WORD
        depth += depth & WORD # align
        for i, loc in enumerate(locs):
            self.mov_raw_stack_to_loc(i * WORD, loc)
        self.mc.ADD_ri(r.sp.value, r.sp.value, depth)

    def regalloc_mov(self, prev_loc, loc):
        """Moves a value from a previous location to some other location"""
        if prev_loc.is_imm():
            return self._mov_imm_to_loc(prev_loc, loc)
        elif prev_loc.is_core_reg():
            self._mov_reg_to_loc(prev_loc, loc)
        elif prev_loc.is_stack():
            self._mov_stack_to_loc(prev_loc, loc)
        elif prev_loc.is_imm_float():
            self._mov_imm_float_to_loc(prev_loc, loc)
        elif prev_loc.is_vfp_reg():
            self._mov_vfp_reg_to_loc(prev_loc, loc)
        else:
            assert 0, 'unsupported case'
    mov_loc_loc = regalloc_mov

    def gen_func_epilog(self, mc=None):
        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if mc is None:
            mc = self.mc
        if gcrootmap and gcrootmap.is_shadow_stack:
            self.gen_footer_shadowstack(gcrootmap, mc)

        if self.cpu.translate_support_code:
            self._call_footer_vmprof(mc)
        # pop all callee saved registers

        stack_size = (len(r.callee_saved_registers) + 8) * WORD

        for i in range(0, len(r.callee_saved_registers), 2):
            mc.LDP_rri(r.callee_saved_registers[i].value,
                            r.callee_saved_registers[i + 1].value,
                            r.sp.value,
                            (i + 8) * WORD)
        mc.LDP_rr_postindex(r.lr.value, r.fp.value, r.sp.value, stack_size)


        mc.RET_r(r.lr.value)

    def _call_footer_vmprof(self, mc):
        from rpython.rlib.rvmprof.rvmprof import cintf
        # ip0 = address of pypy_threadlocal_s
        mc.LDR_ri(r.ip0.value, r.sp.value, 3 * WORD)
        # ip1 = (our local vmprof_tl_stack).next
        mc.LDR_ri(r.ip1.value, r.sp.value, 4 * WORD)
        # save in vmprof_tl_stack the value eax
        offset = cintf.vmprof_tl_stack.getoffset()
        mc.STR_ri(r.ip1.value, r.ip0.value, offset)

    def gen_shadowstack_header(self, gcrootmap):
        # we push two words, like the x86 backend does:
        # the '1' is to benefit from the shadowstack 'is_minor' optimization
        rst = gcrootmap.get_root_stack_top_addr()
        self.mc.gen_load_int(r.ip1.value, rst)
        # x8 = *ip1
        self.load_reg(self.mc, r.x8, r.ip1)
        # x8[0] = 1
        self.mc.gen_load_int(r.ip0.value, 1)
        self.store_reg(self.mc, r.ip0, r.x8)
        # x8[1] = r.fp
        self.store_reg(self.mc, r.fp, r.x8, WORD)
        # *ip1 = x8 + 2 * WORD
        self.mc.ADD_ri(r.x8.value, r.x8.value, 2 * WORD)
        self.store_reg(self.mc, r.x8, r.ip1)

    def gen_footer_shadowstack(self, gcrootmap, mc):
        rst = gcrootmap.get_root_stack_top_addr()
        mc.gen_load_int(r.ip0.value, rst)
        self.load_reg(mc, r.ip1, r.ip0)
        mc.SUB_ri(r.ip1.value, r.ip1.value, 2 * WORD)   # two words, see above
        self.store_reg(mc, r.ip1, r.ip0)

    def store_reg(self, mc, source, base, ofs=0, helper=None):
        if source.is_vfp_reg():
            return self._store_vfp_reg(mc, source, base, ofs)
        else:
            return self._store_core_reg(mc, source, base, ofs)

    def _store_vfp_reg(self, mc, source, base, ofs):
        assert ofs <= (1 << 15) - 1
        mc.STR_di(source.value, base.value, ofs)

    def _store_core_reg(self, mc, source, base, ofs):
        # XXX fix:
        assert ofs & 0x7 == 0
        assert 0 <= ofs < 32768
        mc.STR_ri(source.value, base.value, ofs)
        #if check_imm_arg(ofs):
        #    mc.STR_ri(source.value, base.value, imm=ofs)
        #else:
        #    mc.gen_load_int(r.ip1, ofs)
        #    mc.STR_rr(source.value, base.value, r.ip1)

    def load_reg(self, mc, target, base, ofs=0, helper=r.ip0):
        assert target.is_core_reg()
        if check_imm_arg(abs(ofs)):
            mc.LDR_ri(target.value, base.value, ofs)
        else:
            mc.gen_load_int(helper.value, ofs)
            mc.LDR_rr(target.value, base.value, helper.value)

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
        mc = InstrBuilder()
        mc.B(target)
        mc.copy_to_raw_memory(oldadr)
        #
        jl.redirect_assembler(oldlooptoken, newlooptoken, newlooptoken.number)



def not_implemented(msg):
    msg = '[ARM64/asm] %s\n' % msg
    if we_are_translated():
        llop.debug_print(lltype.Void, msg)
    raise NotImplementedError(msg)


def notimplemented_op(self, op, arglocs):
    print "[ARM64/asm] %s not implemented" % op.getopname()
    raise NotImplementedError(op)

def notimplemented_comp_op(self, op, arglocs):
    print "[ARM64/asm] %s not implemented" % op.getopname()
    raise NotImplementedError(op)

def notimplemented_guard_op(self, op, guard_op, fcond, arglocs):
    print "[ARM64/asm] %s not implemented" % op.getopname()
    raise NotImplementedError(op)

asm_operations = [notimplemented_op] * (rop._LAST + 1)
asm_guard_operations = [notimplemented_guard_op] * (rop._LAST + 1)
asm_comp_operations = [notimplemented_comp_op] * (rop._LAST + 1)
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
    elif name.startswith('emit_guard_op_'):
        opname = name[len('emit_guard_op_'):]
        num = getattr(rop, opname.upper())
        asm_guard_operations[num] = value
    elif name.startswith('emit_comp_op_'):
        opname = name[len('emit_comp_op_'):]
        num = getattr(rop, opname.upper())
        asm_comp_operations[num] = value
