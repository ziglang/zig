import sys

from rpython.jit.backend.llsupport import jitframe, rewrite
from rpython.jit.backend.llsupport.assembler import (GuardToken, BaseAssembler)
from rpython.jit.backend.llsupport.asmmemmgr import MachineDataBlockWrapper
from rpython.jit.backend.llsupport.gcmap import allocate_gcmap
from rpython.jit.metainterp.history import (AbstractFailDescr, INT, REF, FLOAT,
        Const, VOID)
from rpython.jit.metainterp.compile import ResumeGuardDescr
from rpython.rlib.rjitlog import rjitlog as jl
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.annlowlevel import cast_instance_to_gcref
from rpython.rtyper import rclass
from rpython.rlib.jit import AsmInfo
from rpython.jit.backend.model import CompiledLoopToken
from rpython.jit.backend.x86.jump import remap_frame_layout_mixed
from rpython.jit.backend.x86.regalloc import (RegAlloc, get_ebp_ofs,
    gpr_reg_mgr_cls, xmm_reg_mgr_cls)
from rpython.jit.backend.llsupport.regalloc import (get_scale, valid_addressing_size)
from rpython.jit.backend.x86 import arch
from rpython.jit.backend.x86.arch import (FRAME_FIXED_SIZE, WORD, IS_X86_64,
                                       JITFRAME_FIXED_SIZE, IS_X86_32,
                                       PASS_ON_MY_FRAME, THREADLOCAL_OFS,
                                       DEFAULT_FRAME_BYTES, WIN64)
from rpython.jit.backend.x86.regloc import (eax, ecx, edx, ebx, esp, ebp, esi,
    xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, r8, r9, r10, r11, edi,
    r12, r13, r14, r15, X86_64_SCRATCH_REG, X86_64_XMM_SCRATCH_REG,
    RegLoc, FrameLoc, ConstFloatLoc, ImmedLoc, AddressLoc, imm,
    imm0, imm1, FloatImmedLoc, RawEbpLoc, RawEspLoc)
from rpython.rlib.objectmodel import we_are_translated
from rpython.jit.backend.x86 import rx86, codebuf, callbuilder
from rpython.jit.backend.x86.vector_ext import VectorAssemblerMixin
from rpython.jit.backend.x86.callbuilder import follow_jump
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.backend.x86 import support
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rlib import rgc
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.jit.codewriter import longlong
from rpython.rlib.rarithmetic import intmask, r_uint
from rpython.rlib.objectmodel import compute_unique_id


class Assembler386(BaseAssembler, VectorAssemblerMixin):
    _regalloc = None
    _output_loop_log = None
    _second_tmp_reg = ecx

    DEBUG_FRAME_DEPTH = False

    def __init__(self, cpu, translate_support_code=False):
        BaseAssembler.__init__(self, cpu, translate_support_code)
        self.verbose = False
        self.loop_run_counters = []
        self.float_const_neg_addr = 0
        self.float_const_abs_addr = 0
        self.single_float_const_neg_addr = 0
        self.single_float_const_abs_addr = 0
        self.expand_byte_mask_addr = 0
        self.malloc_slowpath = 0
        self.malloc_slowpath_varsize = 0
        self.wb_slowpath = [0, 0, 0, 0, 0]
        self.setup_failure_recovery()
        self.datablockwrapper = None
        self.stack_check_slowpath = 0
        self.propagate_exception_path = 0
        self.teardown()

    def setup_once(self):
        BaseAssembler.setup_once(self)
        if self.cpu.supports_floats:
            support.ensure_sse2_floats()
            self._build_float_constants()

    def setup(self, looptoken):
        BaseAssembler.setup(self, looptoken)
        assert self.memcpy_addr != 0, "setup_once() not called?"
        self.current_clt = looptoken.compiled_loop_token
        self.pending_slowpaths = []
        self.pending_guard_tokens = []
        if WORD == 8:
            self.pending_memoryerror_trampoline_from = []
            self.error_trampoline_64 = 0
        self.mc = codebuf.MachineCodeBlockWrapper()
        #assert self.datablockwrapper is None --- but obscure case
        # possible, e.g. getting MemoryError and continuing
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        self.datablockwrapper = MachineDataBlockWrapper(self.cpu.asmmemmgr,
                                                        allblocks)
        self.target_tokens_currently_compiling = {}
        self.frame_depth_to_patch = []


    def teardown(self):
        self.pending_guard_tokens = None
        if WORD == 8:
            self.pending_memoryerror_trampoline_from = None
        self.mc = None
        self.current_clt = None
        self.frame_depth_to_patch = None

    def _build_float_constants(self):
        # 0x80000000000000008000000000000000
        neg_const = '\x00\x00\x00\x00\x00\x00\x00\x80\x00\x00\x00\x00\x00\x00\x00\x80'
        # 0x7FFFFFFFFFFFFFFF7FFFFFFFFFFFFFFF
        abs_const = '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x7F'
        # 0x7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF
        single_abs_const = '\xFF\xFF\xFF\x7F\xFF\xFF\xFF\x7F\xFF\xFF\xFF\x7F\xFF\xFF\xFF\x7F'
        # 0x80000000800000008000000080000000
        single_neg_const = '\x00\x00\x00\x80\x00\x00\x00\x80\x00\x00\x00\x80\x00\x00\x00\x80'
        zero_const = '\x00' * 16
        #
        two_64bit_ones = '\x01\x00\x00\x00\x00\x00\x00\x00' * 2
        four_32bit_ones = '\x01\x00\x00\x00' * 4
        eight_16bit_ones = '\x01\x00' * 8
        sixteen_8bit_ones = '\x01' * 16





        #
        data = neg_const + abs_const + \
               single_neg_const + single_abs_const + \
               zero_const + sixteen_8bit_ones + eight_16bit_ones + \
               four_32bit_ones + two_64bit_ones
        datablockwrapper = MachineDataBlockWrapper(self.cpu.asmmemmgr, [])
        float_constants = datablockwrapper.malloc_aligned(len(data), alignment=16)
        datablockwrapper.done()
        addr = rffi.cast(rffi.CArrayPtr(lltype.Char), float_constants)
        for i in range(len(data)):
            addr[i] = data[i]
        self.float_const_neg_addr = float_constants
        self.float_const_abs_addr = float_constants + 16
        self.single_float_const_neg_addr = float_constants + 32
        self.single_float_const_abs_addr = float_constants + 48
        self.expand_byte_mask_addr = float_constants + 64
        self.element_ones = [float_constants + 80 + 16*i for i in range(4)]

    def build_frame_realloc_slowpath(self):
        mc = codebuf.MachineCodeBlockWrapper()
        self._push_all_regs_to_frame(mc, [], self.cpu.supports_floats)
        # the caller already did push_gcmap(store=True)

        tmpreg = ecx
        if IS_X86_64:
            mc.MOV_rs(callbuilder.CallBuilder64.ARG1.value, WORD*2)     # esi/edx
            # push first arg
            mc.MOV_rr(callbuilder.CallBuilder64.ARG0.value, ebp.value)  # edi/ecx
            align = callbuilder.align_stack_words(1)
            if WIN64:
                align += 4    # shadow space
                tmpreg = r12
            mc.SUB_ri(esp.value, (align - 1) * WORD)
        else:
            align = callbuilder.align_stack_words(3)
            mc.MOV_rs(eax.value, WORD * 2)
            mc.SUB_ri(esp.value, (align - 1) * WORD)
            mc.MOV_sr(WORD, eax.value)
            mc.MOV_sr(0, ebp.value)
        # align

        #
        # * Note: these commented-out pieces of code about 'extra_stack_depth'
        # * are not necessary any more, but they are kept around in case we
        # * need in the future again to track the exact stack depth.
        #
        #self.set_extra_stack_depth(mc, align * WORD)

        self._store_and_reset_exception(mc, None, ebx, tmpreg)

        mc.CALL(imm(self.cpu.realloc_frame))
        mc.MOV_rr(ebp.value, eax.value)
        self._restore_exception(mc, None, ebx, ecx)
        mc.ADD_ri(esp.value, (align - 1) * WORD)
        #self.set_extra_stack_depth(mc, 0)

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self._load_shadowstack_top_in_ebx(mc, gcrootmap)
            mc.MOV_mr((ebx.value, -WORD), eax.value)

        self.pop_gcmap(mc)   # cancel the push_gcmap(store=True) in the caller
        self._pop_all_regs_from_frame(mc, [], self.cpu.supports_floats)
        mc.RET()
        self._frame_realloc_slowpath = mc.materialize(self.cpu, [])

    def _build_cond_call_slowpath(self, supports_floats, callee_only):
        """ This builds a general call slowpath, for whatever call happens to
        come.
        """
        self.pending_slowpaths = []
        mc = codebuf.MachineCodeBlockWrapper()
        # copy registers to the frame, with the exception of the
        # 'cond_call_register_arguments' and eax, because these have already
        # been saved by the caller.  Note that this is not symmetrical:
        # these 5 registers are saved by the caller but 4 of them are
        # restored here at the end of this function.
        self._push_all_regs_to_frame(mc, cond_call_register_arguments + [eax],
                                     supports_floats, callee_only)
        # the caller already did push_gcmap(store=True)
        if IS_X86_64:
            if WIN64:
                add_to_esp = WORD * 5      # alignment + shadow store
            else:
                add_to_esp = WORD          # alignment
            mc.SUB(esp, imm(add_to_esp))
            #self.set_extra_stack_depth(mc, 2 * WORD)
            # the arguments are already in the correct registers
        else:
            # we want space for 4 arguments + call + alignment
            add_to_esp = WORD * 7
            mc.SUB(esp, imm(add_to_esp))
            #self.set_extra_stack_depth(mc, 8 * WORD)
            # store the arguments at the correct place in the stack
            for i in range(4):
                mc.MOV_sr(i * WORD, cond_call_register_arguments[i].value)
        mc.CALL(eax)
        self._reload_frame_if_necessary(mc)
        mc.ADD(esp, imm(add_to_esp))
        #self.set_extra_stack_depth(mc, 0)
        self.pop_gcmap(mc)   # cancel the push_gcmap(store=True) in the caller
        self._pop_all_regs_from_frame(mc, [eax], supports_floats, callee_only)
        mc.RET()
        self.flush_pending_slowpaths(mc)
        return mc.materialize(self.cpu, [])

    def _build_malloc_slowpath(self, kind):
        """ While arriving on slowpath, we have a gcpattern on stack 0.
        The arguments are passed in ecx and edx, as follows:

        kind == 'fixed': nursery_head in ecx and the size in (edx - ecx).

        kind == 'str/unicode': length of the string to allocate in edx.

        kind == 'var': length to allocate in edx, tid in ecx,
                       and itemsize in the stack 1 (position esp+WORD).

        This function must preserve all registers apart from ecx and edx.
        """
        assert kind in ['fixed', 'str', 'unicode', 'var']
        self.pending_slowpaths = []
        mc = codebuf.MachineCodeBlockWrapper()
        self._push_all_regs_to_frame(mc, [ecx, edx], self.cpu.supports_floats)
        # the caller already did push_gcmap(store=True)
        #
        if kind == 'fixed':
            addr = self.cpu.gc_ll_descr.get_malloc_slowpath_addr()
        elif kind == 'str':
            addr = self.cpu.gc_ll_descr.get_malloc_fn_addr('malloc_str')
        elif kind == 'unicode':
            addr = self.cpu.gc_ll_descr.get_malloc_fn_addr('malloc_unicode')
        else:
            addr = self.cpu.gc_ll_descr.get_malloc_slowpath_array_addr()
        add_to_esp = 16 - WORD     # restore 16-byte alignment
        if WIN64:
            add_to_esp += 4 * WORD    # shadow space before the CALL
        mc.SUB_ri(esp.value, add_to_esp)
        # magically, the above is enough on X86_32 to reserve 3 stack places
        if kind == 'fixed':
            mc.SUB_rr(edx.value, ecx.value) # compute the size we want
            if IS_X86_32:
                mc.MOV_sr(0, edx.value)     # store the length
                if hasattr(self.cpu.gc_ll_descr, 'passes_frame'):
                    mc.MOV_sr(WORD, ebp.value)        # for tests only
            else:
                mc.MOV_rr(callbuilder.CallBuilder64.ARG0.value, edx.value)   # length argument
                if hasattr(self.cpu.gc_ll_descr, 'passes_frame'):
                    mc.MOV_rr(callbuilder.CallBuilder64.ARG1.value, ebp.value)   # for tests only
        elif kind == 'str' or kind == 'unicode':
            if IS_X86_32:
                # stack layout: [---][---][---][ret].. with 3 free stack places
                mc.MOV_sr(0, edx.value)     # store the length
            elif IS_X86_64:
                mc.MOV_rr(callbuilder.CallBuilder64.ARG0.value, edx.value)   # length argument
        else:
            if IS_X86_32:
                # stack layout: [---][---][---][ret][gcmap][itemsize]...
                mc.MOV_sr(WORD * 2, edx.value)  # store the length
                mc.MOV_sr(WORD * 1, ecx.value)  # store the tid
                mc.MOV_rs(edx.value, WORD * 5)  # load the itemsize
                mc.MOV_sr(WORD * 0, edx.value)  # store the itemsize
            else:
                # stack layout: [win64:4*shadowsave][---][ret][gcmap][itemsize]...
                # (careful ordering of the following three instructions for Win64, because
                # there we have ARG0==ecx and ARG1==edx)
                if callbuilder.CallBuilder64.ARG2 is not edx:
                    mc.MOV_rr(callbuilder.CallBuilder64.ARG2.value, edx.value) # length
                mc.MOV_rr(callbuilder.CallBuilder64.ARG1.value, ecx.value) # tid
                mc.MOV_rs(callbuilder.CallBuilder64.ARG0.value, add_to_esp + WORD * 2)  # load the itemsize
        #self.set_extra_stack_depth(mc, 16)
        mc.CALL(imm(follow_jump(addr)))
        self._reload_frame_if_necessary(mc)
        mc.ADD_ri(esp.value, add_to_esp)
        #self.set_extra_stack_depth(mc, 0)
        #
        mc.TEST_rr(eax.value, eax.value)
        # common case: not taken
        mc.J_il(rx86.Conditions['Z'], 0xfffff) # patched later
        jz_location = mc.get_relative_pos(break_basic_block=False)
        mc.MOV_rr(ecx.value, eax.value)
        #
        nursery_free_adr = self.cpu.gc_ll_descr.get_nursery_free_addr()
        self._pop_all_regs_from_frame(mc, [ecx, edx], self.cpu.supports_floats)
        self.pop_gcmap(mc)   # push_gcmap(store=True) done by the caller
        mc.RET()
        #
        # If the slowpath malloc failed, we raise a MemoryError that
        # always interrupts the current loop, as a "good enough"
        # approximation.  We have to adjust the esp a little, to point to
        # the correct "ret" arg
        offset = mc.get_relative_pos() - jz_location
        mc.overwrite32(jz_location-4, offset)
        # From now on this function is basically "merged" with
        # its caller and so contains DEFAULT_FRAME_BYTES bytes
        # plus my own return address, which we'll ignore next
        mc.force_frame_size(DEFAULT_FRAME_BYTES + WORD)
        mc.ADD_ri(esp.value, WORD)
        mc.JMP(imm(self.propagate_exception_path))
        self.flush_pending_slowpaths(mc)
        #
        rawstart = mc.materialize(self.cpu, [])
        return rawstart

    def _build_propagate_exception_path(self):
        self.mc = codebuf.MachineCodeBlockWrapper()
        self.mc.force_frame_size(DEFAULT_FRAME_BYTES)
        #
        # read and reset the current exception

        self._store_and_reset_exception(self.mc, eax)
        ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
        self.mc.MOV_br(ofs, eax.value)
        propagate_exception_descr = rffi.cast(lltype.Signed,
                  cast_instance_to_gcref(self.cpu.propagate_exception_descr))
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.MOV(RawEbpLoc(ofs), imm(propagate_exception_descr))
        #
        self._call_footer()
        rawstart = self.mc.materialize(self.cpu, [])
        self.propagate_exception_path = rawstart
        self.mc = None

    def _build_stack_check_slowpath(self):
        _, _, slowpathaddr = self.cpu.insert_stack_check()
        if slowpathaddr == 0 or not self.cpu.propagate_exception_descr:
            return      # no stack check (for tests, or non-translated)
        #
        # make a regular function that is called from a point near the start
        # of an assembler function (after it adjusts the stack and saves
        # registers).
        mc = codebuf.MachineCodeBlockWrapper()
        #
        if IS_X86_64:
            mc.MOV_rr(callbuilder.CallBuilder64.ARG0.value, esp.value)
            add_to_esp = WORD
            if WIN64:
                add_to_esp += 4 * WORD    # shadow space before the CALL
            mc.SUB_ri(esp.value, add_to_esp)   # alignment
        #
        if IS_X86_32:
            mc.SUB_ri(esp.value, 2*WORD) # alignment
            mc.PUSH_r(esp.value)
            add_to_esp = 3 * WORD
        #
        # esp is now aligned to a multiple of 16 again
        mc.CALL(imm(follow_jump(slowpathaddr)))
        #
        mc.ADD_ri(esp.value, add_to_esp)
        #
        mc.MOV(eax, heap(self.cpu.pos_exception()))
        mc.TEST_rr(eax.value, eax.value)
        jnz_location = mc.emit_forward_jump('NZ')
        #
        mc.RET()
        #
        # patch the JNZ above
        mc.patch_forward_jump(jnz_location)
        # From now on this function is basically "merged" with
        # its caller and so contains DEFAULT_FRAME_BYTES bytes
        # plus my own return address, which we'll ignore next
        mc.force_frame_size(DEFAULT_FRAME_BYTES + WORD)
        mc.ADD_ri(esp.value, WORD)
        mc.JMP(imm(self.propagate_exception_path))
        #
        rawstart = mc.materialize(self.cpu, [])
        self.stack_check_slowpath = rawstart

    def _build_wb_slowpath(self, withcards, withfloats=False, for_frame=False):
        descr = self.cpu.gc_ll_descr.write_barrier_descr
        exc0, exc1 = None, None
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
        # all XMM registers.  It takes a single argument just pushed
        # on the stack even on X86_64.  It must restore stack alignment
        # accordingly.
        mc = codebuf.MachineCodeBlockWrapper()
        shadow_save = 4 * WORD if WIN64 else 0    # win64: 4 extra unused words before CALL
        #
        if not for_frame:
            self._push_all_regs_to_frame(mc, [], withfloats, callee_only=True)
            if IS_X86_32:
                # we have 2 extra words on stack for retval and we pass 1 extra
                # arg, so we need to substract 2 words
                assert shadow_save == 0
                add_to_esp = 2 * WORD
                mc.SUB_ri(esp.value, 2 * WORD)
                mc.MOV_rs(eax.value, 3 * WORD) # 2 + 1
                mc.MOV_sr(0, eax.value)
            else:
                add_to_esp = shadow_save
                if add_to_esp != 0:
                    mc.SUB_ri(esp.value, add_to_esp)    # the 4-words shadow store
                mc.MOV_rs(callbuilder.CallBuilder64.ARG0.value, WORD + add_to_esp)
        else:
            # NOTE: don't save registers on the jitframe here!
            # It might override already-saved values that will be
            # restored later...
            #
            # This 'for_frame' version is called after a CALL.  It does not
            # need to save many registers: the registers that are anyway
            # destroyed by the call can be ignored (volatiles), and the
            # non-volatile registers won't be changed here.  It only needs
            # to save eax, maybe edx, and xmm0 (possible results of the call)
            # and two more non-volatile registers (used to store the RPython
            # exception that occurred in the CALL, if any).
            assert not withcards
            # we have one word to align
            add_to_esp = shadow_save + 7 * WORD
            mc.SUB_ri(esp.value, add_to_esp) # align and reserve some space
            mc.MOV_sr(shadow_save + WORD, eax.value) # save for later
            if self.cpu.supports_floats:
                mc.MOVSD_sx(shadow_save + 2 * WORD, xmm0.value)   # 32-bit: also 3 * WORD
            if IS_X86_32:
                mc.MOV_sr(shadow_save + 4 * WORD, edx.value)
                mc.MOV_sr(shadow_save, ebp.value)
                exc0, exc1 = esi, edi
            else:
                mc.MOV_rr(callbuilder.CallBuilder64.ARG0.value, ebp.value)
                exc0, exc1 = ebx, r12
            mc.MOV(RawEspLoc(shadow_save + WORD * 5, REF), exc0)
            mc.MOV(RawEspLoc(shadow_save + WORD * 6, INT), exc1)
            # note that it's safe to store the exception in register,
            # since the call to write barrier can't collect
            # (and this is assumed a bit left and right here, like lack
            # of _reload_frame_if_necessary)
            self._store_and_reset_exception(mc, exc0, exc1)

        mc.CALL(imm(func))
        #
        if withcards:
            # A final TEST8 before the RET, for the caller.  Careful to
            # not follow this instruction with another one that changes
            # the status of the CPU flags!
            mc.MOV_rs(eax.value, WORD + add_to_esp)
            mc.TEST8(addr_add_const(eax, descr.jit_wb_if_flag_byteofs),
                     imm(-0x80))
        #

        if not for_frame:
            if add_to_esp != 0:
                # ADD touches CPU flags
                mc.LEA_rs(esp.value, add_to_esp)
            self._pop_all_regs_from_frame(mc, [], withfloats, callee_only=True)
            mc.RET16_i(WORD)
            # Note that wb_slowpath[0..3] end with a RET16_i, which must be
            # taken care of in the caller by stack_frame_size_delta(-WORD)
        else:
            if IS_X86_32:
                mc.MOV_rs(edx.value, shadow_save + 4 * WORD)
            if self.cpu.supports_floats:
                mc.MOVSD_xs(xmm0.value, shadow_save + 2 * WORD)
            mc.MOV_rs(eax.value, shadow_save + WORD) # restore
            self._restore_exception(mc, exc0, exc1)
            mc.MOV(exc0, RawEspLoc(shadow_save + WORD * 5, REF))
            mc.MOV(exc1, RawEspLoc(shadow_save + WORD * 6, INT))
            mc.LEA_rs(esp.value, add_to_esp)
            mc.RET()

        rawstart = mc.materialize(self.cpu, [])
        if for_frame:
            self.wb_slowpath[4] = rawstart
        else:
            self.wb_slowpath[withcards + 2 * withfloats] = rawstart

    @rgc.no_release_gil
    def assemble_loop(self, jd_id, unique_id, logger, loopname, inputargs,
                      operations, looptoken, log):
        '''adds the following attributes to looptoken:
               _ll_function_addr    (address of the generated func, as an int)
               _ll_raw_start        (jitlog: address of the first byte to asm memory)
               _ll_loop_code       (debug: addr of the start of the ResOps)
               _x86_fullsize        (debug: full size including failure)
        '''
        # XXX this function is too longish and contains some code
        # duplication with assemble_bridge().  Also, we should think
        # about not storing on 'self' attributes that will live only
        # for the duration of compiling one loop or a one bridge.
        clt = CompiledLoopToken(self.cpu, looptoken.number)
        looptoken.compiled_loop_token = clt
        clt._debug_nbargs = len(inputargs)
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

        if log or self._debug:
            number = looptoken.number
            operations = self._inject_debugging_code(looptoken, operations,
                                                     'e', number)

        regalloc = RegAlloc(self, self.cpu.translate_support_code)
        #
        allgcrefs = []
        operations = regalloc.prepare_loop(inputargs, operations,
                                           looptoken, allgcrefs)
        self.reserve_gcref_table(allgcrefs)
        functionpos = self.mc.get_relative_pos()
        self._call_header_with_stack_check()
        self._check_frame_depth_debug(self.mc)
        looppos = self.mc.get_relative_pos()
        frame_depth_no_fixed_size = self._assemble(regalloc, inputargs,
                                                   operations)
        self.update_frame_depth(frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE)
        #
        size_excluding_failure_stuff = self.mc.get_relative_pos()
        self.write_pending_failure_recoveries(regalloc)
        full_size = self.mc.get_relative_pos()
        #
        rawstart = self.materialize_loop(looptoken)
        self.patch_gcref_table(looptoken, rawstart)
        self.patch_stack_checks(frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE,
                                rawstart)
        looptoken._ll_loop_code = looppos + rawstart
        debug_start("jit-backend-addr")
        debug_print("Loop %d (%s) has address 0x%x to 0x%x (bootstrap 0x%x)" % (
            looptoken.number, loopname,
            r_uint(rawstart + looppos),
            r_uint(rawstart + size_excluding_failure_stuff),
            r_uint(rawstart + functionpos)))
        debug_print("       gc table: 0x%x" % r_uint(self.gc_table_addr))
        debug_print("       function: 0x%x" % r_uint(rawstart + functionpos))
        debug_print("         resops: 0x%x" % r_uint(rawstart + looppos))
        debug_print("       failures: 0x%x" % r_uint(rawstart +
                                                 size_excluding_failure_stuff))
        debug_print("            end: 0x%x" % r_uint(rawstart + full_size))
        debug_stop("jit-backend-addr")
        debug_start("jit-regalloc-stats")
        debug_print("Loop %d (%s) has address 0x%x to 0x%x (bootstrap 0x%x)" % (
            looptoken.number, loopname,
            r_uint(rawstart + looppos),
            r_uint(rawstart + size_excluding_failure_stuff),
            r_uint(rawstart + functionpos)))
        debug_print("assembler size: ", size_excluding_failure_stuff)
        debug_print("number ops: ", len(operations))
        debug_print("preamble num moves calls: ", self.preamble_num_moves_calls)
        debug_print("preamble num moves jump:", self.preamble_num_moves_jump)
        debug_print("preamble num moves spills:", self.preamble_num_spills)
        debug_print("preamble num moves spills to existing:", self.preamble_num_spills_to_existing)
        debug_print("preamble num register reloads:", self.preamble_num_reloads)
        debug_print("num moves calls: ", self.num_moves_calls)
        debug_print("num moves jump:", self.num_moves_jump)
        debug_print("num moves spills:", self.num_spills)
        debug_print("num moves spills to existing:", self.num_spills_to_existing)
        debug_print("num moves register reloads:", self.num_reloads)
        debug_stop("jit-regalloc-stats")
        self.patch_pending_failure_recoveries(rawstart)
        #
        ops_offset = self.mc.ops_offset
        if not we_are_translated():
            # used only by looptoken.dump() -- useful in tests
            looptoken._x86_rawstart = rawstart
            looptoken._x86_fullsize = full_size
            looptoken._x86_ops_offset = ops_offset
        looptoken._ll_function_addr = rawstart + functionpos
        looptoken._ll_raw_start = rawstart

        if log and logger:
            l = logger.log_trace(jl.MARK_TRACE_ASM, None, self.mc)
            l.write(inputargs, operations, ops_offset=ops_offset)

            # legacy
            if logger.logger_ops:
                logger.logger_ops.log_loop(inputargs, operations, 0,
                                           "rewritten", name=loopname,
                                           ops_offset=ops_offset)

        self.fixup_target_tokens(rawstart)
        self.teardown()
        # oprofile support
        if self.cpu.profile_agent is not None:
            name = "Loop # %s: %s" % (looptoken.number, loopname)
            self.cpu.profile_agent.native_code_written(name,
                                                       rawstart, full_size)
        return AsmInfo(ops_offset, rawstart + looppos,
                       size_excluding_failure_stuff - looppos, rawstart)

    @rgc.no_release_gil
    def assemble_bridge(self, faildescr, inputargs, operations,
                        original_loop_token, log, logger):
        if not we_are_translated():
            # Arguments should be unique
            assert len(set(inputargs)) == len(inputargs)

        self.setup(original_loop_token)
        if self.cpu.HAS_CODEMAP:
            self.codemap_builder.inherit_code_from_position(
                faildescr.adr_jump_offset)
        self.mc.force_frame_size(DEFAULT_FRAME_BYTES)
        descr_number = compute_unique_id(faildescr)
        if log or self._debug:
            operations = self._inject_debugging_code(faildescr, operations,
                                                     'b', descr_number)
        arglocs = self.rebuild_faillocs_from_descr(faildescr, inputargs)
        regalloc = RegAlloc(self, self.cpu.translate_support_code)
        allgcrefs = []
        operations = regalloc.prepare_bridge(inputargs, arglocs,
                                             operations,
                                             allgcrefs,
                                             self.current_clt.frame_info)
        self.reserve_gcref_table(allgcrefs)
        startpos = self.mc.get_relative_pos()
        self._check_frame_depth(self.mc, regalloc.get_gcmap())
        bridgestartpos = self.mc.get_relative_pos()
        self._update_at_exit(arglocs, inputargs, faildescr, regalloc)
        frame_depth_no_fixed_size = self._assemble(regalloc, inputargs, operations)
        codeendpos = self.mc.get_relative_pos()
        self.write_pending_failure_recoveries(regalloc)
        fullsize = self.mc.get_relative_pos()
        #
        rawstart = self.materialize_loop(original_loop_token)
        original_loop_token._ll_raw_start = rawstart
        self.patch_gcref_table(original_loop_token, rawstart)
        self.patch_stack_checks(frame_depth_no_fixed_size + JITFRAME_FIXED_SIZE,
                                rawstart)
        debug_start("jit-backend-addr")
        debug_print("bridge out of Guard 0x%x has address 0x%x to 0x%x" %
                    (r_uint(descr_number), r_uint(rawstart + startpos),
                        r_uint(rawstart + codeendpos)))
        debug_print("       gc table: 0x%x" % r_uint(self.gc_table_addr))
        debug_print("    jump target: 0x%x" % r_uint(rawstart + startpos))
        debug_print("         resops: 0x%x" % r_uint(rawstart + bridgestartpos))
        debug_print("       failures: 0x%x" % r_uint(rawstart + codeendpos))
        debug_print("            end: 0x%x" % r_uint(rawstart + fullsize))
        debug_stop("jit-backend-addr")
        debug_start("jit-regalloc-stats")
        debug_print("bridge out of Guard 0x%x has address 0x%x to 0x%x" %
                    (r_uint(descr_number), r_uint(rawstart + startpos),
                        r_uint(rawstart + codeendpos)))

        debug_print("assembler size: ", fullsize)
        debug_print("number ops: ", len(operations))
        debug_print("preamble num moves calls: ", self.preamble_num_moves_calls)
        debug_print("preamble num moves jump:", self.preamble_num_moves_jump)
        debug_print("preamble num moves spills:", self.preamble_num_spills)
        debug_print("preamble num moves spills to existing:", self.preamble_num_spills_to_existing)
        debug_print("preamble num register reloads:", self.preamble_num_reloads)
        debug_print("num moves calls: ", self.num_moves_calls)
        debug_print("num moves jump:", self.num_moves_jump)
        debug_print("num moves spills:", self.num_spills)
        debug_print("num moves spills to existing:", self.num_spills_to_existing)
        debug_print("num moves register reloads:", self.num_reloads)
        debug_stop("jit-regalloc-stats")
        self.patch_pending_failure_recoveries(rawstart)
        # patch the jump from original guard
        self.patch_jump_for_descr(faildescr, rawstart + startpos)
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
        # oprofile support
        if self.cpu.profile_agent is not None:
            name = "Bridge # %s" % (descr_number,)
            self.cpu.profile_agent.native_code_written(name,
                                                       rawstart, fullsize)
        return AsmInfo(ops_offset, startpos + rawstart, codeendpos - startpos, rawstart+bridgestartpos)

    def stitch_bridge(self, faildescr, target):
        """ Stitching means that one can enter a bridge with a complete different register
            allocation. This needs remapping which is done here for both normal registers
            and accumulation registers.
            Why? Because this only generates a very small junk of memory, instead of
            duplicating the loop assembler for each faildescr!
        """
        asminfo, bridge_faildescr, version, looptoken = target
        assert isinstance(bridge_faildescr, ResumeGuardDescr)
        assert isinstance(faildescr, ResumeGuardDescr)
        assert asminfo.rawstart != 0
        self.mc = codebuf.MachineCodeBlockWrapper()
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        self.datablockwrapper = MachineDataBlockWrapper(self.cpu.asmmemmgr,
                                                   allblocks)
        frame_info = self.datablockwrapper.malloc_aligned(
            jitframe.JITFRAMEINFO_SIZE, alignment=WORD)

        self.mc.force_frame_size(DEFAULT_FRAME_BYTES)
        # if accumulation is saved at the guard, we need to update it here!
        guard_locs = self.rebuild_faillocs_from_descr(faildescr, version.inputargs)
        bridge_locs = self.rebuild_faillocs_from_descr(bridge_faildescr, version.inputargs)
        #import pdb; pdb.set_trace()
        guard_accum_info = faildescr.rd_vector_info
        # O(n**2), but usually you only have at most 1 fail argument
        while guard_accum_info:
            bridge_accum_info = bridge_faildescr.rd_vector_info
            while bridge_accum_info:
                if bridge_accum_info.failargs_pos == guard_accum_info.failargs_pos:
                    # the mapping might be wrong!
                    if bridge_accum_info.location is not guard_accum_info.location:
                        self.mov(guard_accum_info.location, bridge_accum_info.location)
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
            if not src_loc.is_float():
                src_locations1.append(src_loc)
                dst_locations1.append(dst_loc)
            else:
                src_locations2.append(src_loc)
                dst_locations2.append(dst_loc)
        remap_frame_layout_mixed(self, src_locations1, dst_locations1, X86_64_SCRATCH_REG,
                                 src_locations2, dst_locations2, X86_64_XMM_SCRATCH_REG)

        offset = self.mc.get_relative_pos()
        self.mc.JMP_l(0)
        self.mc.writeimm32(0)
        self.mc.force_frame_size(DEFAULT_FRAME_BYTES)
        rawstart = self.materialize_loop(looptoken)
        # update the jump (above) to the real trace
        self._patch_jump_to(rawstart + offset, asminfo.rawstart)
        # update the guard to jump right to this custom piece of assembler
        self.patch_jump_for_descr(faildescr, rawstart)

    def _patch_jump_to(self, adr_jump_offset, adr_new_target):
        assert adr_jump_offset != 0
        offset = adr_new_target - (adr_jump_offset + 5)
        mc = codebuf.MachineCodeBlockWrapper()
        mc.force_frame_size(DEFAULT_FRAME_BYTES)
        if rx86.fits_in_32bits(offset):
            mc.JMP_l(offset)
        else:
            # mc.forget_scratch_register() not needed here
            mc.MOV_ri(X86_64_SCRATCH_REG.value, adr_new_target)
            mc.JMP_r(X86_64_SCRATCH_REG.value)
        mc.copy_to_raw_memory(adr_jump_offset)

    def reserve_gcref_table(self, allgcrefs):
        gcref_table_size = len(allgcrefs) * WORD
        if IS_X86_64:
            # align to a multiple of 16 and reserve space at the beginning
            # of the machine code for the gc table.  This lets us write
            # machine code with relative addressing (%rip - constant).
            gcref_table_size = (gcref_table_size + 15) & ~15
            mc = self.mc
            assert mc.get_relative_pos() == 0
            for i in range(gcref_table_size):
                mc.writechar('\x00')
        elif IS_X86_32:
            # allocate the gc table right now.  This lets us write
            # machine code with absolute 32-bit addressing.
            self.gc_table_addr = self.datablockwrapper.malloc_aligned(
                gcref_table_size, alignment=WORD)
        #
        self.setup_gcrefs_list(allgcrefs)

    def patch_gcref_table(self, looptoken, rawstart):
        if IS_X86_64:
            # the gc table is at the start of the machine code
            self.gc_table_addr = rawstart
        elif IS_X86_32:
            # the gc table was already allocated by reserve_gcref_table()
            rawstart = self.gc_table_addr
        #
        tracer = self.cpu.gc_ll_descr.make_gcref_tracer(rawstart,
                                                        self._allgcrefs)
        gcreftracers = self.get_asmmemmgr_gcreftracers(looptoken)
        gcreftracers.append(tracer)    # keepalive
        self.teardown_gcrefs_list()

    def flush_pending_slowpaths(self, mc):
        # for each pending slowpath, generate it now.  Note that this
        # may occasionally add an extra guard_token in
        # pending_guard_tokens, so it must be done before the
        # following loop in write_pending_failure_recoveries().
        for sp in self.pending_slowpaths:
            sp.generate(self, mc)
        self.pending_slowpaths = None

    def write_pending_failure_recoveries(self, regalloc):
        self.flush_pending_slowpaths(self.mc)
        # for each pending guard, generate the code of the recovery stub
        # at the end of self.mc.
        for tok in self.pending_guard_tokens:
            descr = tok.faildescr
            if descr.loop_version():
                startpos = self.mc.get_relative_pos()
                self.store_info_on_descr(startpos, tok)
            else:
                tok.pos_recovery_stub = self.generate_quick_failure(tok, regalloc)
        if WORD == 8 and len(self.pending_memoryerror_trampoline_from) > 0:
            self.error_trampoline_64 = self.generate_propagate_error_64()

    def patch_pending_failure_recoveries(self, rawstart):
        # after we wrote the assembler to raw memory, set up
        # tok.faildescr.adr_jump_offset to contain the raw address of
        # the 4-byte target field in the JMP/Jcond instruction, and patch
        # the field in question to point (initially) to the recovery stub
        clt = self.current_clt
        for tok in self.pending_guard_tokens:
            addr = rawstart + tok.pos_jump_offset
            tok.faildescr.adr_jump_offset = addr
            descr = tok.faildescr
            if descr.loop_version():
                continue # patch them later
            relative_target = tok.pos_recovery_stub - (tok.pos_jump_offset + 4)
            assert rx86.fits_in_32bits(relative_target)
            #
            if not tok.guard_not_invalidated():
                mc = codebuf.MachineCodeBlockWrapper()
                mc.writeimm32(relative_target)
                mc.copy_to_raw_memory(addr)
            else:
                # GUARD_NOT_INVALIDATED, record an entry in
                # clt.invalidate_positions of the form:
                #     (addr-in-the-code-of-the-not-yet-written-jump-target,
                #      relative-target-to-use)
                relpos = tok.pos_jump_offset
                clt.invalidate_positions.append((rawstart + relpos,
                                                 relative_target))
                # General idea: Although no code was generated by this
                # guard, the code might be patched with a "JMP rel32" to
                # the guard recovery code.  This recovery code is
                # already generated, and looks like the recovery code
                # for any guard, even if at first it has no jump to it.
                # So we may later write 5 bytes overriding the existing
                # instructions; this works because a CALL instruction
                # would also take at least 5 bytes.  If it could take
                # less, we would run into the issue that overwriting the
                # 5 bytes here might get a few nonsense bytes at the
                # return address of the following CALL.
        if WORD == 8:
            for pos_after_jz in self.pending_memoryerror_trampoline_from:
                assert self.error_trampoline_64 != 0     # only if non-empty
                mc = codebuf.MachineCodeBlockWrapper()
                mc.writeimm32(self.error_trampoline_64 - pos_after_jz)
                mc.copy_to_raw_memory(rawstart + pos_after_jz - 4)

    def update_frame_depth(self, frame_depth):
        baseofs = self.cpu.get_baseofs_of_frame_field()
        self.current_clt.frame_info.update_frame_depth(baseofs, frame_depth)

    def patch_stack_checks(self, framedepth, rawstart):
        for ofs in self.frame_depth_to_patch:
            self._patch_frame_depth(ofs + rawstart, framedepth)

    class IncreaseStackSlowPath(codebuf.SlowPath):
        def generate_body(self, assembler, mc):
            mc.MOV_si(WORD, 0xffffff)     # force writing 32 bit
            ofs2 = mc.get_relative_pos(break_basic_block=False) - 4
            assembler.frame_depth_to_patch.append(ofs2)
            assembler.push_gcmap(mc, self.gcmap, store=True)
            mc.CALL(imm(assembler._frame_realloc_slowpath))

    def _check_frame_depth(self, mc, gcmap):
        """ check if the frame is of enough depth to follow this bridge.
        Otherwise reallocate the frame in a helper.
        There are other potential solutions
        to that, but this one does not sound too bad.
        """
        descrs = self.cpu.gc_ll_descr.getframedescrs(self.cpu)
        ofs = self.cpu.unpack_fielddescr(descrs.arraydescr.lendescr)
        mc.CMP_bi(ofs, 0xffffff)     # force writing 32 bit
        stack_check_cmp_ofs = mc.get_relative_pos(break_basic_block=False) - 4
        self.frame_depth_to_patch.append(stack_check_cmp_ofs)
        sp = self.IncreaseStackSlowPath(mc, rx86.Conditions['L'])
        sp.gcmap = gcmap
        sp.set_continue_addr(mc)
        self.pending_slowpaths.append(sp)

    def _check_frame_depth_debug(self, mc):
        """ double check the depth size. It prints the error (and potentially
        segfaults later)
        """
        if not self.DEBUG_FRAME_DEPTH:
            return
        descrs = self.cpu.gc_ll_descr.getframedescrs(self.cpu)
        ofs = self.cpu.unpack_fielddescr(descrs.arraydescr.lendescr)
        mc.CMP_bi(ofs, 0xffffff)
        stack_check_cmp_ofs = mc.get_relative_pos(break_basic_block=False) - 4
        jg_location = mc.emit_forward_jump('GE')
        mc.MOV_rr(edi.value, ebp.value)
        mc.MOV_ri(esi.value, 0xffffff)
        ofs2 = mc.get_relative_pos(break_basic_block=False) - 4
        if WIN64:
            assert False   # implement me if needed on Win64
        mc.CALL(imm(self.cpu.realloc_frame_crash))
        # patch the JG above
        mc.patch_forward_jump(jg_location)
        self.frame_depth_to_patch.append(stack_check_cmp_ofs)
        self.frame_depth_to_patch.append(ofs2)

    def _patch_frame_depth(self, adr, allocated_depth):
        mc = codebuf.MachineCodeBlockWrapper()
        mc.writeimm32(allocated_depth)
        mc.copy_to_raw_memory(adr)

    def materialize_loop(self, looptoken):
        self.datablockwrapper.done()      # finish using cpu.asmmemmgr
        self.datablockwrapper = None
        allblocks = self.get_asmmemmgr_blocks(looptoken)
        size = self.mc.get_relative_pos()
        res = self.mc.materialize(self.cpu, allblocks,
                                  self.cpu.gc_ll_descr.gcrootmap)
        if self.cpu.HAS_CODEMAP:
            self.cpu.codemap.register_codemap(
                self.codemap_builder.get_final_bytecode(res, size))
        return res

    def patch_jump_for_descr(self, faildescr, adr_new_target):
        adr_jump_offset = faildescr.adr_jump_offset
        assert adr_jump_offset != 0
        offset = adr_new_target - (adr_jump_offset + 4)
        # If the new target fits within a rel32 of the jump, just patch
        # that. Otherwise, leave the original rel32 to the recovery stub in
        # place, but clobber the recovery stub with a jump to the real
        # target.
        mc = codebuf.MachineCodeBlockWrapper()
        mc.force_frame_size(DEFAULT_FRAME_BYTES)
        if rx86.fits_in_32bits(offset):
            mc.writeimm32(offset)
            mc.copy_to_raw_memory(adr_jump_offset)
        else:
            # "mov r11, addr; jmp r11" is up to 13 bytes, which fits in there
            # because we always write "mov r11, imm-as-8-bytes; call *r11" in
            # the first place.
            # mc.forget_scratch_register() not needed here
            mc.MOV_ri(X86_64_SCRATCH_REG.value, adr_new_target)
            mc.JMP_r(X86_64_SCRATCH_REG.value)
            p = rffi.cast(rffi.INTP, adr_jump_offset)
            adr_target = adr_jump_offset + 4 + rffi.cast(lltype.Signed, p[0])
            mc.copy_to_raw_memory(adr_target)
        faildescr.adr_jump_offset = 0    # means "patched"

    def fixup_target_tokens(self, rawstart):
        for targettoken in self.target_tokens_currently_compiling:
            targettoken._ll_loop_code += rawstart
        self.target_tokens_currently_compiling = None

    def _assemble(self, regalloc, inputargs, operations):
        self._regalloc = regalloc
        self.guard_success_cc = rx86.cond_none
        regalloc.compute_hint_frame_locations(operations)
        regalloc.walk_operations(inputargs, operations)
        assert self.guard_success_cc == rx86.cond_none
        if we_are_translated() or self.cpu.dont_keepalive_stuff:
            self._regalloc = None   # else keep it around for debugging
        frame_depth = regalloc.get_final_frame_depth()
        jump_target_descr = regalloc.jump_target_descr
        if jump_target_descr is not None:
            tgt_depth = jump_target_descr._x86_clt.frame_info.jfi_frame_depth
            target_frame_depth = tgt_depth - JITFRAME_FIXED_SIZE
            frame_depth = max(frame_depth, target_frame_depth)
        return frame_depth

    def _call_header_vmprof(self):
        from rpython.rlib.rvmprof.rvmprof import cintf, VMPROF_JITTED_TAG

        # tloc = address of pypy_threadlocal_s
        if IS_X86_32:
            # Can't use esi here, its old value is not saved yet.
            # But we can use eax and ecx.
            self.mc.MOV_rs(edx.value, THREADLOCAL_OFS)
            tloc = edx
            old = ecx
        else:
            # The thread-local value is already in esi.
            # We should avoid if possible to use ecx or edx because they
            # would be used to pass arguments #3 and #4 (even though, so
            # far, the assembler only receives two arguments).
            tloc = callbuilder.CallBuilder64.ARG1   # esi/edx
            old = r10
        # eax = address in the stack of a 3-words struct vmprof_stack_s
        self.mc.LEA_rs(eax.value, (FRAME_FIXED_SIZE - 4) * WORD)
        # old = current value of vmprof_tl_stack
        offset = cintf.vmprof_tl_stack.getoffset()
        self.mc.MOV_rm(old.value, (tloc.value, offset))
        # eax->next = old
        self.mc.MOV_mr((eax.value, 0), old.value)
        # eax->value = my esp
        self.mc.MOV_mr((eax.value, WORD), esp.value)
        # eax->kind = VMPROF_JITTED_TAG
        self.mc.MOV_mi((eax.value, WORD * 2), VMPROF_JITTED_TAG)
        # save in vmprof_tl_stack the new eax
        self.mc.MOV_mr((tloc.value, offset), eax.value)

    def _call_footer_vmprof(self):
        from rpython.rlib.rvmprof.rvmprof import cintf
        # edx = address of pypy_threadlocal_s
        self.mc.MOV_rs(edx.value, THREADLOCAL_OFS)
        # eax = (our local vmprof_tl_stack).next
        self.mc.MOV_rs(eax.value, (FRAME_FIXED_SIZE - 4 + 0) * WORD)
        # save in vmprof_tl_stack the value eax
        offset = cintf.vmprof_tl_stack.getoffset()
        self.mc.MOV_mr((edx.value, offset), eax.value)

    def _call_header(self):
        self.mc.SUB_ri(esp.value, FRAME_FIXED_SIZE * WORD)
        self.mc.MOV_sr(PASS_ON_MY_FRAME * WORD, ebp.value)
        if IS_X86_64:
            r_arg2 = callbuilder.CallBuilder64.ARG1   # esi/edx
            self.mc.MOV_sr(THREADLOCAL_OFS, r_arg2.value)
        if self.cpu.translate_support_code and not WIN64:
            self._call_header_vmprof()     # on X86_64, this uses esi/edx
        if IS_X86_64:
            r_arg1 = callbuilder.CallBuilder64.ARG0   # edi/ecx
            self.mc.MOV_rr(ebp.value, r_arg1.value)
        else:
            self.mc.MOV_rs(ebp.value, (FRAME_FIXED_SIZE + 1) * WORD)

        for i, loc in enumerate(self.cpu.CALLEE_SAVE_REGISTERS):
            ofs = (PASS_ON_MY_FRAME + i + 1) * WORD
            if WIN64 and i == 4: ofs = arch.SHADOWSTORE2_OFS
            if WIN64 and i == 5: ofs = arch.SHADOWSTORE3_OFS
            self.mc.MOV_sr(ofs, loc.value)

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self._call_header_shadowstack(gcrootmap)

    class StackCheckSlowPath(codebuf.SlowPath):
        def generate_body(self, assembler, mc):
            mc.CALL(imm(assembler.stack_check_slowpath))

    def _call_header_with_stack_check(self):
        self._call_header()
        if self.stack_check_slowpath == 0:
            pass                # no stack check (e.g. not translated)
        else:
            endaddr, lengthaddr, _ = self.cpu.insert_stack_check()
            self.mc.MOV(eax, heap(endaddr))             # MOV eax, [start]
            self.mc.SUB(eax, esp)                       # SUB eax, current
            self.mc.CMP(eax, heap(lengthaddr))          # CMP eax, [length]
            sp = self.StackCheckSlowPath(self.mc, rx86.Conditions['A'])
            sp.set_continue_addr(self.mc)
            self.pending_slowpaths.append(sp)

    def _call_footer(self):
        # the return value is the jitframe
        if self.cpu.translate_support_code and not WIN64:
            self._call_footer_vmprof()
        self.mc.MOV_rr(eax.value, ebp.value)

        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap and gcrootmap.is_shadow_stack:
            self._call_footer_shadowstack(gcrootmap)

        for i in range(len(self.cpu.CALLEE_SAVE_REGISTERS)-1, -1, -1):
            ofs = (i + 1 + PASS_ON_MY_FRAME) * WORD
            if WIN64 and i == 4: ofs = arch.SHADOWSTORE2_OFS
            if WIN64 and i == 5: ofs = arch.SHADOWSTORE3_OFS
            self.mc.MOV_rs(self.cpu.CALLEE_SAVE_REGISTERS[i].value, ofs)

        self.mc.MOV_rs(ebp.value, PASS_ON_MY_FRAME * WORD)
        self.mc.ADD_ri(esp.value, FRAME_FIXED_SIZE * WORD)
        self.mc.RET()

    def _load_shadowstack_top_in_ebx(self, mc, gcrootmap):
        """Loads the shadowstack top in ebx, and returns an integer
        that gives the address of the stack top.  If this integer doesn't
        fit in 32 bits, it will be loaded in r11.
        """
        rst = gcrootmap.get_root_stack_top_addr()
        mc.MOV(ebx, heap(rst))                  # maybe via loading r11
        return rst

    def _call_header_shadowstack(self, gcrootmap):
        rst = self._load_shadowstack_top_in_ebx(self.mc, gcrootmap)
        # the '1' is to benefit from the shadowstack 'is_minor' optimization
        self.mc.MOV_mi((ebx.value, 0), 1)               # MOV [ebx], 1
        self.mc.MOV_mr((ebx.value, WORD), ebp.value)    # MOV [ebx + WORD], ebp
        self.mc.ADD_ri(ebx.value, WORD * 2)
        self.mc.MOV(heap(rst), ebx)                   # MOV [rootstacktop], ebx

    def _call_footer_shadowstack(self, gcrootmap):
        rst = gcrootmap.get_root_stack_top_addr()
        if rx86.fits_in_32bits(rst):
            self.mc.SUB_ji8(rst, WORD * 2)       # SUB [rootstacktop], WORD * 2
        else:
            self.mc.MOV_ri(ebx.value, rst)           # MOV ebx, rootstacktop
            self.mc.SUB_mi8((ebx.value, 0), WORD * 2)  # SUB [ebx], WORD * 2

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
        mc = codebuf.MachineCodeBlockWrapper()
        mc.JMP(imm(follow_jump(target)))
        if WORD == 4:         # keep in sync with prepare_loop()
            assert mc.get_relative_pos() == 5
        else:
            assert mc.get_relative_pos() <= 13
        mc.copy_to_raw_memory(oldadr)
        # log the redirection of the call_assembler_* operation
        asm_adr = newlooptoken._ll_raw_start
        jl.redirect_assembler(oldlooptoken, newlooptoken, asm_adr)

    def dump(self, text):
        if not self.verbose:
            return
        pos = self.mc.get_relative_pos()
        print >> sys.stderr, ' 0x%x  %s' % (pos, text)

    # ------------------------------------------------------------

    def mov(self, from_loc, to_loc):
        from_xmm = isinstance(from_loc, RegLoc) and from_loc.is_xmm
        to_xmm = isinstance(to_loc, RegLoc) and to_loc.is_xmm
        if from_xmm or to_xmm:
            if from_xmm and to_xmm:
                # copy 128-bit from -> to
                self.mc.MOVAPD(to_loc, from_loc)
            else:
                self.mc.MOVSD(to_loc, from_loc)
        else:
            assert to_loc is not ebp
            self.mc.MOV(to_loc, from_loc)

    regalloc_mov = mov # legacy interface

    def regalloc_push(self, loc):
        if isinstance(loc, RegLoc) and loc.is_xmm:
            self.mc.SUB_ri(esp.value, 8)   # = size of doubles
            self.mc.MOVSD_sx(0, loc.value)
        elif WORD == 4 and isinstance(loc, FrameLoc) and loc.get_width() == 8:
            # XXX evil trick
            self.mc.PUSH_b(loc.value + 4)
            self.mc.PUSH_b(loc.value)
        else:
            self.mc.PUSH(loc)

    def regalloc_pop(self, loc):
        if isinstance(loc, RegLoc) and loc.is_xmm:
            self.mc.MOVSD_xs(loc.value, 0)
            self.mc.ADD_ri(esp.value, 8)   # = size of doubles
        elif WORD == 4 and isinstance(loc, FrameLoc) and loc.get_width() == 8:
            # XXX evil trick
            self.mc.POP_b(loc.value)
            self.mc.POP_b(loc.value + 4)
        else:
            self.mc.POP(loc)

    def regalloc_immedmem2mem(self, from_loc, to_loc):
        # move a ConstFloatLoc directly to a FrameLoc, as two MOVs
        # (even on x86-64, because the immediates are encoded as 32 bits)
        assert isinstance(from_loc, ConstFloatLoc)
        low_part  = rffi.cast(rffi.CArrayPtr(rffi.INT), from_loc.value)[0]
        high_part = rffi.cast(rffi.CArrayPtr(rffi.INT), from_loc.value)[1]
        low_part  = intmask(low_part)
        high_part = intmask(high_part)
        if isinstance(to_loc, RawEbpLoc):
            self.mc.MOV32_bi(to_loc.value,     low_part)
            self.mc.MOV32_bi(to_loc.value + 4, high_part)
        else:
            assert isinstance(to_loc, RawEspLoc)
            self.mc.MOV32_si(to_loc.value,     low_part)
            self.mc.MOV32_si(to_loc.value + 4, high_part)

    def regalloc_perform(self, op, arglocs, resloc):
        genop_list[op.getopnum()](self, op, arglocs, resloc)

    def regalloc_perform_discard(self, op, arglocs):
        genop_discard_list[op.getopnum()](self, op, arglocs)

    def regalloc_perform_llong(self, op, arglocs, resloc):
        effectinfo = op.getdescr().get_extra_info()
        oopspecindex = effectinfo.oopspecindex
        genop_llong_list[oopspecindex](self, op, arglocs, resloc)

    def regalloc_perform_math(self, op, arglocs, resloc):
        effectinfo = op.getdescr().get_extra_info()
        oopspecindex = effectinfo.oopspecindex
        genop_math_list[oopspecindex](self, op, arglocs, resloc)

    def regalloc_perform_guard(self, guard_op, faillocs, arglocs, resloc,
                               frame_depth):
        faildescr = guard_op.getdescr()
        assert isinstance(faildescr, AbstractFailDescr)
        failargs = guard_op.getfailargs()
        guard_opnum = guard_op.getopnum()
        guard_token = self.implement_guard_recovery(guard_opnum,
                                                    faildescr, failargs,
                                                    faillocs, frame_depth)
        genop_guard_list[guard_opnum](self, guard_op, guard_token,
                                      arglocs, resloc)
        # this must usually have added guard_token as last element
        # of self.pending_guard_tokens, but not always (see
        # genop_guard_guard_no_exception)

    def load_effective_addr(self, sizereg, baseofs, scale, result, frm=imm0):
        self.mc.LEA(result, addr_add(frm, sizereg, baseofs, scale))

    def _unaryop(asmop):
        def genop_unary(self, op, arglocs, resloc):
            getattr(self.mc, asmop)(arglocs[0])
        return genop_unary

    def _binaryop(asmop):
        def genop_binary(self, op, arglocs, result_loc):
            getattr(self.mc, asmop)(arglocs[0], arglocs[1])
        return genop_binary

    def _binaryop_or_lea(asmop, is_add):
        def genop_binary_or_lea(self, op, arglocs, result_loc):
            # use a regular ADD or SUB if result_loc is arglocs[0],
            # and a LEA only if different.
            if result_loc is arglocs[0]:
                getattr(self.mc, asmop)(arglocs[0], arglocs[1])
            else:
                loc = arglocs[0]
                argloc = arglocs[1]
                assert isinstance(loc, RegLoc)
                assert isinstance(argloc, ImmedLoc)
                assert isinstance(result_loc, RegLoc)
                delta = argloc.value
                if not is_add:    # subtraction
                    delta = -delta
                self.mc.LEA_rm(result_loc.value, (loc.value, delta))
        return genop_binary_or_lea

    def flush_cc(self, cond, result_loc):
        # After emitting a instruction that leaves a boolean result in
        # a condition code (cc), call this.  In the common case, result_loc
        # will be set to ebp by the regalloc, which in this case means
        # "propagate it between this operation and the next guard by keeping
        # it in the cc".  In the uncommon case, result_loc is another
        # register, and we emit a load from the cc into this register.
        assert self.guard_success_cc == rx86.cond_none
        if result_loc is ebp:
            self.guard_success_cc = cond
        else:
            self.mc.MOV_ri(result_loc.value, 0)
            rl = result_loc.lowest8bits()
            self.mc.SET_ir(cond, rl.value)

    def _cmpop(cond, rev_cond):
        cond = rx86.Conditions[cond]
        rev_cond = rx86.Conditions[rev_cond]
        #
        def genop_cmp(self, op, arglocs, result_loc):
            if isinstance(op.getarg(0), Const):
                self.mc.CMP(arglocs[1], arglocs[0])
                self.flush_cc(rev_cond, result_loc)
            else:
                self.mc.CMP(arglocs[0], arglocs[1])
                self.flush_cc(cond, result_loc)
        return genop_cmp

    def _if_parity_clear_zero_and_carry(self):
        jnp_location = self.mc.emit_forward_jump('NP')
        # CMP EBP, 0: as EBP cannot be null here, that operation should
        # always clear zero and carry
        self.mc.CMP_ri(ebp.value, 0)
        # patch the JNP above
        self.mc.patch_forward_jump(jnp_location)

    def _cmpop_float(cond, rev_cond):
        is_ne           = cond == 'NE'
        need_direct_p   = 'A' not in cond
        need_rev_p      = 'A' not in rev_cond
        cond_contains_e = ('E' in cond) ^ ('N' in cond)
        cond            = rx86.Conditions[cond]
        rev_cond        = rx86.Conditions[rev_cond]
        #
        def genop_cmp_float(self, op, arglocs, result_loc):
            if need_direct_p:
                direct_case = not isinstance(arglocs[1], RegLoc)
            else:
                direct_case = isinstance(arglocs[0], RegLoc)
            if direct_case:
                self.mc.UCOMISD(arglocs[0], arglocs[1])
                checkcond = cond
                need_p = need_direct_p
            else:
                self.mc.UCOMISD(arglocs[1], arglocs[0])
                checkcond = rev_cond
                need_p = need_rev_p
            if need_p:
                self._if_parity_clear_zero_and_carry()
            self.flush_cc(checkcond, result_loc)
        return genop_cmp_float

    def simple_call(self, fnloc, arglocs, result_loc=eax):
        if result_loc is xmm0:
            result_type = FLOAT
            result_size = 8
        elif result_loc is None:
            result_type = VOID
            result_size = 0
        else:
            result_type = INT
            result_size = WORD
        cb = callbuilder.CallBuilder(self, fnloc, arglocs,
                                     result_loc, result_type,
                                     result_size)
        cb.emit()
        self.num_moves_calls += cb.num_moves

    def simple_call_no_collect(self, fnloc, arglocs):
        cb = callbuilder.CallBuilder(self, fnloc, arglocs)
        cb.emit_no_collect()
        self.num_moves_calls += cb.num_moves

    def _reload_frame_if_necessary(self, mc, shadowstack_reg=None):
        gcrootmap = self.cpu.gc_ll_descr.gcrootmap
        if gcrootmap:
            if gcrootmap.is_shadow_stack:
                if shadowstack_reg is None:
                    rst = gcrootmap.get_root_stack_top_addr()
                    mc.MOV(ecx, heap(rst))
                    shadowstack_reg = ecx
                mc.MOV(ebp, mem(shadowstack_reg, -WORD))
        wbdescr = self.cpu.gc_ll_descr.write_barrier_descr
        if gcrootmap and wbdescr:
            # frame never uses card marking, so we enforce this is not
            # an array
            self._write_barrier_fastpath(mc, wbdescr, [ebp], array=False,
                                         is_frame=True)

    genop_int_neg = _unaryop("NEG")
    genop_int_invert = _unaryop("NOT")
    genop_int_add = _binaryop_or_lea("ADD", is_add=True)
    genop_nursery_ptr_increment = _binaryop_or_lea('ADD', is_add=True)
    genop_int_sub = _binaryop_or_lea("SUB", is_add=False)
    genop_int_mul = _binaryop("IMUL")
    genop_int_or  = _binaryop("OR")
    genop_int_xor = _binaryop("XOR")
    genop_int_lshift = _binaryop("SHL")
    genop_int_rshift = _binaryop("SAR")
    genop_uint_rshift = _binaryop("SHR")
    genop_float_add = _binaryop("ADDSD")
    genop_float_sub = _binaryop('SUBSD')
    genop_float_mul = _binaryop('MULSD')
    genop_float_truediv = _binaryop('DIVSD')

    def genop_uint_mul_high(self, op, arglocs, result_loc):
        self.mc.MUL(arglocs[0])

    def genop_int_and(self, op, arglocs, result_loc):
        arg1 = arglocs[1]
        if IS_X86_64 and (isinstance(arg1, ImmedLoc) and
                          arg1.value == (1 << 32) - 1):
            # special case
            self.mc.MOV32(arglocs[0], arglocs[0])
        else:
            self.mc.AND(arglocs[0], arg1)

    genop_int_lt = _cmpop("L", "G")
    genop_int_le = _cmpop("LE", "GE")
    genop_int_eq = _cmpop("E", "E")
    genop_int_ne = _cmpop("NE", "NE")
    genop_int_gt = _cmpop("G", "L")
    genop_int_ge = _cmpop("GE", "LE")
    genop_ptr_eq = genop_instance_ptr_eq = genop_int_eq
    genop_ptr_ne = genop_instance_ptr_ne = genop_int_ne

    genop_uint_gt = _cmpop("A", "B")
    genop_uint_lt = _cmpop("B", "A")
    genop_uint_le = _cmpop("BE", "AE")
    genop_uint_ge = _cmpop("AE", "BE")

    genop_float_lt = _cmpop_float("B", "A")
    genop_float_le = _cmpop_float("BE","AE")
    genop_float_eq = _cmpop_float("E", "E")
    genop_float_ne = _cmpop_float("NE", "NE")
    genop_float_gt = _cmpop_float("A", "B")
    genop_float_ge = _cmpop_float("AE","BE")

    def genop_math_sqrt(self, op, arglocs, resloc):
        self.mc.SQRTSD(arglocs[0], resloc)

    def genop_int_signext(self, op, arglocs, resloc):
        argloc, numbytesloc = arglocs
        assert isinstance(numbytesloc, ImmedLoc)
        assert isinstance(resloc, RegLoc)
        if numbytesloc.value == 1:
            if isinstance(argloc, RegLoc):
                if WORD == 4 and argloc.value >= 4:
                    # meh, can't read the lowest byte of esi or edi on 32-bit
                    if resloc is not argloc:
                        self.mc.MOV(resloc, argloc)
                        argloc = resloc
                    if resloc.value >= 4:
                        # still annoyed, hack needed
                        self.mc.SHL_ri(resloc.value, 24)
                        self.mc.SAR_ri(resloc.value, 24)
                        return
                argloc = argloc.lowest8bits()
            self.mc.MOVSX8(resloc, argloc)
        elif numbytesloc.value == 2:
            self.mc.MOVSX16(resloc, argloc)
        elif IS_X86_64 and numbytesloc.value == 4:
            self.mc.MOVSX32(resloc, argloc)
        else:
            raise AssertionError("bad number of bytes")

    def genop_float_neg(self, op, arglocs, resloc):
        # Following what gcc does: res = x ^ 0x8000000000000000
        self.mc.XORPD(arglocs[0], heap(self.float_const_neg_addr))

    def genop_float_abs(self, op, arglocs, resloc):
        # Following what gcc does: res = x & 0x7FFFFFFFFFFFFFFF
        self.mc.ANDPD(arglocs[0], heap(self.float_const_abs_addr))

    def genop_cast_float_to_int(self, op, arglocs, resloc):
        self.mc.CVTTSD2SI(resloc, arglocs[0])

    def genop_cast_int_to_float(self, op, arglocs, resloc):
        self.mc.CVTSI2SD(resloc, arglocs[0])

    def genop_cast_float_to_singlefloat(self, op, arglocs, resloc):
        loc0, loctmp = arglocs
        self.mc.CVTSD2SS(loctmp, loc0)
        assert isinstance(resloc, RegLoc)
        assert isinstance(loctmp, RegLoc)
        self.mc.MOVD32_rx(resloc.value, loctmp.value)

    def genop_cast_singlefloat_to_float(self, op, arglocs, resloc):
        loc0, = arglocs
        assert isinstance(resloc, RegLoc)
        assert isinstance(loc0, RegLoc)
        self.mc.MOVD32_xr(resloc.value, loc0.value)
        self.mc.CVTSS2SD_xx(resloc.value, resloc.value)

    def genop_convert_float_bytes_to_longlong(self, op, arglocs, resloc):
        loc0, = arglocs
        if longlong.is_64_bit:
            assert isinstance(resloc, RegLoc)
            assert isinstance(loc0, RegLoc)
            self.mc.MOVDQ(resloc, loc0)
        else:
            self.mov(loc0, resloc)

    def genop_convert_longlong_bytes_to_float(self, op, arglocs, resloc):
        loc0, = arglocs
        if longlong.is_64_bit:
            assert isinstance(resloc, RegLoc)
            assert isinstance(loc0, RegLoc)
            self.mc.MOVDQ(resloc, loc0)
        else:
            self.mov(loc0, resloc)

    def test_location(self, loc):
        assert not isinstance(loc, ImmedLoc)
        if isinstance(loc, RegLoc):
            self.mc.TEST_rr(loc.value, loc.value)   # more compact
        else:
            self.mc.CMP(loc, imm0)         # works from memory too

    def genop_int_is_true(self, op, arglocs, resloc):
        self.test_location(arglocs[0])
        self.flush_cc(rx86.Conditions['NZ'], resloc)

    def genop_int_is_zero(self, op, arglocs, resloc):
        self.test_location(arglocs[0])
        self.flush_cc(rx86.Conditions['Z'], resloc)

    def _genop_same_as(self, op, arglocs, resloc):
        self.mov(arglocs[0], resloc)
    genop_same_as_i = _genop_same_as
    genop_same_as_r = _genop_same_as
    genop_same_as_f = _genop_same_as
    genop_cast_ptr_to_int = _genop_same_as
    genop_cast_int_to_ptr = _genop_same_as

    def _patch_load_from_gc_table(self, index):
        # must be called immediately after a "p"-mode instruction
        # has been emitted.  64-bit mode only.
        assert IS_X86_64
        address_in_buffer = index * WORD   # at the start of the buffer
        p_location = self.mc.get_relative_pos(break_basic_block=False)
        offset = address_in_buffer - p_location
        self.mc.overwrite32(p_location-4, offset)

    def _addr_from_gc_table(self, index):
        # get the address of the gc table entry 'index'.  32-bit mode only.
        assert IS_X86_32
        return self.gc_table_addr + index * WORD

    def genop_load_from_gc_table(self, op, arglocs, resloc):
        index = op.getarg(0).getint()
        assert isinstance(resloc, RegLoc)
        if IS_X86_64:
            self.mc.MOV_rp(resloc.value, 0)    # %rip-relative
            self._patch_load_from_gc_table(index)
        elif IS_X86_32:
            self.mc.MOV_rj(resloc.value, self._addr_from_gc_table(index))

    def genop_int_force_ge_zero(self, op, arglocs, resloc):
        self.mc.TEST(arglocs[0], arglocs[0])
        self.mov(imm0, resloc)
        self.mc.CMOVNS(resloc, arglocs[0])

    genop_llong_add = _binaryop("PADDQ")
    genop_llong_sub = _binaryop("PSUBQ")
    genop_llong_and = _binaryop("PAND")
    genop_llong_or  = _binaryop("POR")
    genop_llong_xor = _binaryop("PXOR")

    def genop_llong_to_int(self, op, arglocs, resloc):
        loc = arglocs[0]
        assert isinstance(resloc, RegLoc)
        if isinstance(loc, RegLoc):
            self.mc.MOVD32_rx(resloc.value, loc.value)
        elif isinstance(loc, FrameLoc):
            self.mc.MOV_rb(resloc.value, loc.value)
        else:
            not_implemented("llong_to_int: %s" % (loc,))

    def genop_llong_from_int(self, op, arglocs, resloc):
        loc1, loc2 = arglocs
        if isinstance(loc1, ConstFloatLoc):
            assert loc2 is None
            self.mc.MOVSD(resloc, loc1)
        else:
            assert isinstance(loc1, RegLoc)
            assert isinstance(loc2, RegLoc)
            assert isinstance(resloc, RegLoc)
            self.mc.MOVD32_xr(loc2.value, loc1.value)
            self.mc.PSRAD_xi(loc2.value, 31)    # -> 0 or -1
            self.mc.MOVD32_xr(resloc.value, loc1.value)
            self.mc.PUNPCKLDQ_xx(resloc.value, loc2.value)

    def genop_llong_from_uint(self, op, arglocs, resloc):
        loc1, = arglocs
        assert isinstance(resloc, RegLoc)
        assert isinstance(loc1, RegLoc)
        self.mc.MOVD32_xr(resloc.value, loc1.value)   # zero-extending

    def genop_llong_eq(self, op, arglocs, resloc):
        loc1, loc2, locxtmp = arglocs
        self.mc.MOVSD(locxtmp, loc1)
        self.mc.PCMPEQD(locxtmp, loc2)
        self.mc.PMOVMSKB_rx(resloc.value, locxtmp.value)
        # Now the lower 8 bits of resloc contain 0x00, 0x0F, 0xF0 or 0xFF
        # depending on the result of the comparison of each of the two
        # double-words of loc1 and loc2.  The higher 8 bits contain random
        # results.  We want to map 0xFF to 1, and 0x00, 0x0F and 0xF0 to 0.
        self.mc.CMP8_ri(resloc.value | rx86.BYTE_REG_FLAG, -1)
        self.mc.SBB_rr(resloc.value, resloc.value)
        self.mc.ADD_ri(resloc.value, 1)

    def genop_llong_ne(self, op, arglocs, resloc):
        loc1, loc2, locxtmp = arglocs
        self.mc.MOVSD(locxtmp, loc1)
        self.mc.PCMPEQD(locxtmp, loc2)
        self.mc.PMOVMSKB_rx(resloc.value, locxtmp.value)
        # Now the lower 8 bits of resloc contain 0x00, 0x0F, 0xF0 or 0xFF
        # depending on the result of the comparison of each of the two
        # double-words of loc1 and loc2.  The higher 8 bits contain random
        # results.  We want to map 0xFF to 0, and 0x00, 0x0F and 0xF0 to 1.
        self.mc.CMP8_ri(resloc.value | rx86.BYTE_REG_FLAG, -1)
        self.mc.SBB_rr(resloc.value, resloc.value)
        self.mc.NEG_r(resloc.value)

    def genop_llong_lt(self, op, arglocs, resloc):
        # XXX just a special case for now: "x < 0"
        loc1, = arglocs
        self.mc.PMOVMSKB_rx(resloc.value, loc1.value)
        self.mc.SHR_ri(resloc.value, 7)
        self.mc.AND_ri(resloc.value, 1)

    # ----------

    def genop_discard_check_memory_error(self, op, arglocs):
        reg = arglocs[0]
        self.mc.TEST(reg, reg)
        if WORD == 4:
            # common case: not taken
            self.mc.J_il(rx86.Conditions['Z'], self.propagate_exception_path)
            self.mc.add_pending_relocation()
        elif WORD == 8:
            # common case: not taken
            self.mc.J_il(rx86.Conditions['Z'], 0)
            pos = self.mc.get_relative_pos(break_basic_block=False)
            self.pending_memoryerror_trampoline_from.append(pos)

    # ----------

    def load_from_mem(self, resloc, source_addr, size_loc, sign_loc):
        assert isinstance(resloc, RegLoc)
        size = size_loc.value
        sign = sign_loc.value
        if resloc.is_xmm:
            self.mc.MOVSD(resloc, source_addr)
        elif size == WORD:
            self.mc.MOV(resloc, source_addr)
        elif size == 1:
            if sign:
                self.mc.MOVSX8(resloc, source_addr)
            else:
                self.mc.MOVZX8(resloc, source_addr)
        elif size == 2:
            if sign:
                self.mc.MOVSX16(resloc, source_addr)
            else:
                self.mc.MOVZX16(resloc, source_addr)
        elif IS_X86_64 and size == 4:
            if sign:
                self.mc.MOVSX32(resloc, source_addr)
            else:
                self.mc.MOV32(resloc, source_addr)    # zero-extending
        else:
            not_implemented("load_from_mem size = %d" % size)

    def save_into_mem(self, dest_addr, value_loc, size_loc):
        size = size_loc.value
        if isinstance(value_loc, RegLoc) and value_loc.is_xmm:
            self.mc.MOVSD(dest_addr, value_loc)
        elif size == 1:
            self.mc.MOV8(dest_addr, value_loc.lowest8bits())
        elif size == 2:
            self.mc.MOV16(dest_addr, value_loc)
        elif size == 4:
            self.mc.MOV32(dest_addr, value_loc)
        elif size == 8:
            if IS_X86_64:
                self.mc.MOV(dest_addr, value_loc)
            else:
                assert isinstance(value_loc, FloatImmedLoc)
                self.mc.MOV(dest_addr, value_loc.low_part_loc())
                self.mc.MOV(dest_addr.add_offset(4), value_loc.high_part_loc())
        else:
            not_implemented("save_into_mem size = %d" % size)

    def _genop_gc_load(self, op, arglocs, resloc):
        base_loc, ofs_loc, size_loc, sign_loc = arglocs
        assert isinstance(size_loc, ImmedLoc)
        src_addr = addr_add(base_loc, ofs_loc, 0, 0)
        self.load_from_mem(resloc, src_addr, size_loc, sign_loc)

    genop_gc_load_i = _genop_gc_load
    genop_gc_load_r = _genop_gc_load
    genop_gc_load_f = _genop_gc_load

    def _genop_gc_load_indexed(self, op, arglocs, resloc):
        base_loc, ofs_loc, scale_loc, offset_loc, size_loc, sign_loc = arglocs
        assert isinstance(scale_loc, ImmedLoc)
        scale = get_scale(scale_loc.value)
        src_addr = addr_add(base_loc, ofs_loc, offset_loc.value, scale)
        self.load_from_mem(resloc, src_addr, size_loc, sign_loc)

    genop_gc_load_indexed_i = _genop_gc_load_indexed
    genop_gc_load_indexed_r = _genop_gc_load_indexed
    genop_gc_load_indexed_f = _genop_gc_load_indexed

    def _imul_const_scaled(self, mc, targetreg, sourcereg, itemsize):
        """Produce one operation to do roughly
               targetreg = sourcereg * itemsize
           except that the targetreg may still need shifting by 0,1,2,3.
        """
        if (itemsize & 7) == 0:
            shift = 3
        elif (itemsize & 3) == 0:
            shift = 2
        elif (itemsize & 1) == 0:
            shift = 1
        else:
            shift = 0
        itemsize >>= shift
        #
        if valid_addressing_size(itemsize - 1):
            mc.LEA_ra(targetreg, (sourcereg, sourcereg,
                                  get_scale(itemsize - 1), 0))
        elif valid_addressing_size(itemsize):
            mc.LEA_ra(targetreg, (rx86.NO_BASE_REGISTER, sourcereg,
                                  get_scale(itemsize), 0))
        else:
            mc.IMUL_rri(targetreg, sourcereg, itemsize)
        #
        return shift

    def genop_discard_increment_debug_counter(self, op, arglocs):
        # The argument should be an immediate address.  This should
        # generate code equivalent to a GETFIELD_RAW, an ADD(1), and a
        # SETFIELD_RAW.  Here we use the direct from-memory-to-memory
        # increment operation of x86.
        base_loc, = arglocs
        self.mc.INC(mem(base_loc, 0))

    def genop_discard_gc_store(self, op, arglocs):
        base_loc, ofs_loc, value_loc, size_loc = arglocs
        assert isinstance(size_loc, ImmedLoc)
        scale = get_scale(size_loc.value)
        dest_addr = AddressLoc(base_loc, ofs_loc, 0, 0)
        self.save_into_mem(dest_addr, value_loc, size_loc)

    def genop_discard_gc_store_indexed(self, op, arglocs):
        base_loc, ofs_loc, value_loc, factor_loc, offset_loc, size_loc = arglocs
        assert isinstance(size_loc, ImmedLoc)
        scale = get_scale(factor_loc.value)
        dest_addr = AddressLoc(base_loc, ofs_loc, scale, offset_loc.value)
        self.save_into_mem(dest_addr, value_loc, size_loc)

    # genop_discard_setfield_raw = genop_discard_setfield_gc

    def genop_math_read_timestamp(self, op, arglocs, resloc):
        self.mc.RDTSC()
        if longlong.is_64_bit:
            self.mc.SHL_ri(edx.value, 32)
            self.mc.OR_rr(edx.value, eax.value)
        else:
            loc1, = arglocs
            self.mc.MOVD32_xr(loc1.value, edx.value)
            self.mc.MOVD32_xr(resloc.value, eax.value)
            self.mc.PUNPCKLDQ_xx(resloc.value, loc1.value)

    def genop_guard_guard_true(self, guard_op, guard_token, locs, resloc):
        self.implement_guard(guard_token)
    genop_guard_guard_nonnull = genop_guard_guard_true

    def genop_guard_guard_false(self, guard_op, guard_token, locs, resloc):
        self.guard_success_cc = rx86.invert_condition(self.guard_success_cc)
        self.implement_guard(guard_token)
    genop_guard_guard_isnull = genop_guard_guard_false

    def genop_guard_guard_no_exception(self, guard_op, guard_token, locs, ign):
        # If the previous operation was a COND_CALL, don't emit
        # anything now.  Instead, we'll emit the GUARD_NO_EXCEPTION at
        # the end of the slowpath in CondCallSlowPath.
        if self._find_nearby_operation(-1).getopnum() in (
                rop.COND_CALL, rop.COND_CALL_VALUE_I, rop.COND_CALL_VALUE_R):
            sp = self.pending_slowpaths[-1]
            assert isinstance(sp, self.CondCallSlowPath)
            sp.guard_token_no_exception = guard_token
        else:
            self.generate_guard_no_exception(guard_token)

    def generate_guard_no_exception(self, guard_token):
        self.mc.CMP(heap(self.cpu.pos_exception()), imm0)
        self.guard_success_cc = rx86.Conditions['Z']
        self.implement_guard(guard_token)

    def genop_guard_guard_not_invalidated(self, guard_op, guard_token,
                                          locs, ign):
        pos = self.mc.get_relative_pos(break_basic_block=False)
        pos += 1   # after potential jmp
        guard_token.pos_jump_offset = pos
        saved = self.mc.get_scratch_register_known_value()
        guard_token.known_scratch_value = saved
        self.pending_guard_tokens.append(guard_token)

    def genop_guard_guard_exception(self, guard_op, guard_token, locs, resloc):
        loc = locs[0]
        loc1 = locs[1]
        self.mc.MOV(loc1, heap(self.cpu.pos_exception()))
        self.mc.CMP(loc1, loc)
        self.guard_success_cc = rx86.Conditions['E']
        self.implement_guard(guard_token)
        self._store_and_reset_exception(self.mc, resloc)

    def genop_save_exc_class(self, op, arglocs, resloc):
        self.mc.MOV(resloc, heap(self.cpu.pos_exception()))

    def genop_save_exception(self, op, arglocs, resloc):
        self._store_and_reset_exception(self.mc, resloc)

    def genop_discard_restore_exception(self, op, arglocs):
        self._restore_exception(self.mc, arglocs[1], arglocs[0])

    def _store_and_reset_exception(self, mc, excvalloc=None, exctploc=None,
                                   tmploc=None):
        """ Resest the exception. If excvalloc is None, then store it on the
        frame in jf_guard_exc
        """
        if excvalloc is not None:
            assert excvalloc.is_core_reg()
            mc.MOV(excvalloc, heap(self.cpu.pos_exc_value()))
        elif tmploc is not None: # if both are None, just ignore
            ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            mc.MOV(tmploc, heap(self.cpu.pos_exc_value()))
            mc.MOV(RawEbpLoc(ofs), tmploc)
        if exctploc is not None:
            assert exctploc.is_core_reg()
            mc.MOV(exctploc, heap(self.cpu.pos_exception()))

        mc.MOV(heap(self.cpu.pos_exception()), imm0)
        mc.MOV(heap(self.cpu.pos_exc_value()), imm0)

    def _restore_exception(self, mc, excvalloc, exctploc, tmploc=None):
        if excvalloc is not None:
            mc.MOV(heap(self.cpu.pos_exc_value()), excvalloc)
        else:
            assert tmploc is not None
            ofs = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            mc.MOV(tmploc, RawEbpLoc(ofs))
            mc.MOV_bi(ofs, 0)
            mc.MOV(heap(self.cpu.pos_exc_value()), tmploc)
        mc.MOV(heap(self.cpu.pos_exception()), exctploc)

    def genop_int_add_ovf(self, op, arglocs, resloc):
        self.genop_int_add(op, arglocs, resloc)
        self.guard_success_cc = rx86.Conditions['NO']

    def genop_int_sub_ovf(self, op, arglocs, resloc):
        self.genop_int_sub(op, arglocs, resloc)
        self.guard_success_cc = rx86.Conditions['NO']

    def genop_int_mul_ovf(self, op, arglocs, resloc):
        self.genop_int_mul(op, arglocs, resloc)
        self.guard_success_cc = rx86.Conditions['NO']

    genop_guard_guard_no_overflow = genop_guard_guard_true
    genop_guard_guard_overflow    = genop_guard_guard_false

    def genop_guard_guard_value(self, guard_op, guard_token, locs, ign):
        if guard_op.getarg(0).type == FLOAT:
            assert guard_op.getarg(1).type == FLOAT
            self.mc.UCOMISD(locs[0], locs[1])
        else:
            self.mc.CMP(locs[0], locs[1])
        self.guard_success_cc = rx86.Conditions['E']
        self.implement_guard(guard_token)

    def _cmp_guard_class(self, locs):
        loc_ptr = locs[0]
        loc_classptr = locs[1]
        offset = self.cpu.vtable_offset
        if offset is not None:
            self.mc.CMP(mem(loc_ptr, offset), loc_classptr)
        else:
            assert isinstance(loc_classptr, ImmedLoc)
            classptr = loc_classptr.value
            expected_typeid = (self.cpu.gc_ll_descr
                    .get_typeid_from_classptr_if_gcremovetypeptr(classptr))
            self._cmp_guard_gc_type(loc_ptr, ImmedLoc(expected_typeid))

    def _cmp_guard_gc_type(self, loc_ptr, loc_expected_typeid):
        # Note that the typeid half-word is at offset 0 on a little-endian
        # machine; it would be at offset 2 or 4 on a big-endian machine.
        assert self.cpu.supports_guard_gc_type
        if IS_X86_32:
            self.mc.CMP16(mem(loc_ptr, 0), loc_expected_typeid)
        else:
            assert isinstance(loc_expected_typeid, ImmedLoc)
            self.mc.CMP32_mi((loc_ptr.value, 0), loc_expected_typeid.value)

    def genop_guard_guard_class(self, guard_op, guard_token, locs, ign):
        self._cmp_guard_class(locs)
        self.guard_success_cc = rx86.Conditions['E']
        self.implement_guard(guard_token)

    def genop_guard_guard_nonnull_class(self, guard_op, guard_token, locs, ign):
        self.mc.CMP(locs[0], imm1)
        # Patched below
        jb_location = self.mc.emit_forward_jump('B')
        self._cmp_guard_class(locs)
        # patch the JB above
        self.mc.patch_forward_jump(jb_location)
        #
        self.guard_success_cc = rx86.Conditions['E']
        self.implement_guard(guard_token)

    def genop_guard_guard_gc_type(self, guard_op, guard_token, locs, ign):
        self._cmp_guard_gc_type(locs[0], locs[1])
        self.guard_success_cc = rx86.Conditions['E']
        self.implement_guard(guard_token)

    def genop_guard_guard_is_object(self, guard_op, guard_token, locs, ign):
        assert self.cpu.supports_guard_gc_type
        [loc_object, loc_typeid] = locs
        # idea: read the typeid, fetch the field 'infobits' from the big
        # typeinfo table, and check the flag 'T_IS_RPYTHON_INSTANCE'.
        if IS_X86_32:
            self.mc.MOVZX16(loc_typeid, mem(loc_object, 0))
        else:
            self.mc.MOV32(loc_typeid, mem(loc_object, 0))
        #
        base_type_info, shift_by, sizeof_ti = (
            self.cpu.gc_ll_descr.get_translated_info_for_typeinfo())
        infobits_offset, IS_OBJECT_FLAG = (
            self.cpu.gc_ll_descr.get_translated_info_for_guard_is_object())
        loc_infobits = addr_add(imm(base_type_info), loc_typeid,
                                scale=shift_by, offset=infobits_offset)
        self.mc.TEST8(loc_infobits, imm(IS_OBJECT_FLAG))
        #
        self.guard_success_cc = rx86.Conditions['NZ']
        self.implement_guard(guard_token)

    def genop_guard_guard_subclass(self, guard_op, guard_token, locs, ign):
        assert self.cpu.supports_guard_gc_type
        [loc_object, loc_check_against_class, loc_tmp] = locs
        assert isinstance(loc_object, RegLoc)
        assert isinstance(loc_tmp, RegLoc)
        offset = self.cpu.vtable_offset
        offset2 = self.cpu.subclassrange_min_offset
        if offset is not None:
            # read this field to get the vtable pointer
            self.mc.MOV_rm(loc_tmp.value, (loc_object.value, offset))
            # read the vtable's subclassrange_min field
            self.mc.MOV_rm(loc_tmp.value, (loc_tmp.value, offset2))
        else:
            # read the typeid
            if IS_X86_32:
                self.mc.MOVZX16(loc_tmp, mem(loc_object, 0))
            else:
                self.mc.MOV32(loc_tmp, mem(loc_object, 0))
            # read the vtable's subclassrange_min field, as a single
            # step with the correct offset
            base_type_info, shift_by, sizeof_ti = (
                self.cpu.gc_ll_descr.get_translated_info_for_typeinfo())
            self.mc.MOV(loc_tmp, addr_add(imm(base_type_info), loc_tmp,
                                          scale = shift_by,
                                          offset = sizeof_ti + offset2))
        # get the two bounds to check against
        vtable_ptr = loc_check_against_class.getint()
        vtable_ptr = rffi.cast(rclass.CLASSTYPE, vtable_ptr)
        check_min = vtable_ptr.subclassrange_min
        check_max = vtable_ptr.subclassrange_max
        # check by doing the unsigned comparison (tmp - min) < (max - min)
        self.mc.SUB_ri(loc_tmp.value, check_min)
        self.mc.CMP_ri(loc_tmp.value, check_max - check_min)
        # the guard passes if we get a result of "below"
        self.guard_success_cc = rx86.Conditions['B']
        self.implement_guard(guard_token)

    def implement_guard_recovery(self, guard_opnum, faildescr, failargs,
                                 fail_locs, frame_depth):
        gcmap = allocate_gcmap(self, frame_depth, JITFRAME_FIXED_SIZE)
        faildescrindex = self.get_gcref_from_faildescr(faildescr)
        return GuardToken(self.cpu, gcmap, faildescr, failargs, fail_locs,
                          guard_opnum, frame_depth, faildescrindex)

    def generate_propagate_error_64(self):
        assert WORD == 8
        self.mc.force_frame_size(DEFAULT_FRAME_BYTES)
        startpos = self.mc.get_relative_pos()
        self.mc.JMP(imm(self.propagate_exception_path))
        return startpos

    def generate_quick_failure(self, guardtok, regalloc):
        """ Gather information about failure
        """
        self.mc.force_frame_size(DEFAULT_FRAME_BYTES)
        startpos = self.mc.get_relative_pos()
        self.mc.restore_scratch_register_known_value(
                                         guardtok.known_scratch_value)
        #
        self._update_at_exit(guardtok.fail_locs, guardtok.failargs,
                             guardtok.faildescr, regalloc)
        #
        faildescrindex, target = self.store_info_on_descr(startpos, guardtok)
        if IS_X86_64:
            self.mc.PUSH_p(0)     # %rip-relative
            self._patch_load_from_gc_table(faildescrindex)
        elif IS_X86_32:
            self.mc.PUSH_j(self._addr_from_gc_table(faildescrindex))
        self.push_gcmap(self.mc, guardtok.gcmap, push=True)
        self.mc.JMP(imm(target))
        return startpos

    def push_gcmap(self, mc, gcmap, push=False, store=False):
        if push:
            mc.PUSH(imm(rffi.cast(lltype.Signed, gcmap)))
        else:
            assert store
            ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
            mc.MOV(raw_stack(ofs), imm(rffi.cast(lltype.Signed, gcmap)))

    def pop_gcmap(self, mc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.MOV_bi(ofs, 0)

    def new_stack_loc(self, i, tp):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        return FrameLoc(i, get_ebp_ofs(base_ofs, i), tp)

    def setup_failure_recovery(self):
        self.failure_recovery_code = [0, 0, 0, 0]

    def _push_all_regs_to_frame(self, mc, ignored_regs, withfloats,
                                callee_only=False):
        # Push all general purpose registers
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        if callee_only:
            regs = gpr_reg_mgr_cls.save_around_call_regs
        else:
            regs = gpr_reg_mgr_cls.all_regs
        for gpr in regs:
            if gpr not in ignored_regs:
                v = gpr_reg_mgr_cls.all_reg_indexes[gpr.value]
                mc.MOV_br(v * WORD + base_ofs, gpr.value)
        if withfloats:
            if IS_X86_64:
                coeff = 1
            else:
                coeff = 2
            # Push all XMM regs
            ofs = len(gpr_reg_mgr_cls.all_regs)
            for i in range(len(xmm_reg_mgr_cls.all_regs)):
                mc.MOVSD_bx((ofs + i * coeff) * WORD + base_ofs, i)

    def _pop_all_regs_from_frame(self, mc, ignored_regs, withfloats,
                                 callee_only=False):
        # Pop all general purpose registers
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        if callee_only:
            regs = gpr_reg_mgr_cls.save_around_call_regs
        else:
            regs = gpr_reg_mgr_cls.all_regs
        for gpr in regs:
            if gpr not in ignored_regs:
                v = gpr_reg_mgr_cls.all_reg_indexes[gpr.value]
                mc.MOV_rb(gpr.value, v * WORD + base_ofs)
        if withfloats:
            # Pop all XMM regs
            if IS_X86_64:
                coeff = 1
            else:
                coeff = 2
            ofs = len(gpr_reg_mgr_cls.all_regs)
            for i in range(len(xmm_reg_mgr_cls.all_regs)):
                mc.MOVSD_xb(i, (ofs + i * coeff) * WORD + base_ofs)

    def _build_failure_recovery(self, exc, withfloats=False):
        mc = codebuf.MachineCodeBlockWrapper()
        # this is jumped to, from a stack that has DEFAULT_FRAME_BYTES
        # followed by 2 extra words just pushed
        mc.force_frame_size(DEFAULT_FRAME_BYTES + 2 * WORD)
        self.mc = mc

        self._push_all_regs_to_frame(mc, [], withfloats)

        if exc:
            # We might have an exception pending.  Load it into ebx...
            mc.MOV(ebx, heap(self.cpu.pos_exc_value()))
            mc.MOV(heap(self.cpu.pos_exception()), imm0)
            mc.MOV(heap(self.cpu.pos_exc_value()), imm0)
            # ...and save ebx into 'jf_guard_exc'
            offset = self.cpu.get_ofs_of_frame_field('jf_guard_exc')
            mc.MOV_br(offset, ebx.value)

        # fill in the jf_descr and jf_gcmap fields of the frame according
        # to which failure we are resuming from.  These are constants
        # pushed on the stack just before we jump to the current helper,
        # in generate_quick_failure().
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        ofs2 = self.cpu.get_ofs_of_frame_field('jf_gcmap')
        mc.POP_b(ofs2)
        mc.POP_b(ofs)

        # now we return from the complete frame, which starts from
        # _call_header_with_stack_check().  The _call_footer below does it.
        self._call_footer()
        rawstart = mc.materialize(self.cpu, [])
        self.failure_recovery_code[exc + 2 * withfloats] = rawstart
        self.mc = None

    def genop_finish(self, op, arglocs, result_loc):
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        if len(arglocs) > 0:
            [return_val] = arglocs
            if op.getarg(0).type == FLOAT and not IS_X86_64:
                size = WORD * 2
            else:
                size = WORD
            self.save_into_mem(raw_stack(base_ofs), return_val, imm(size))
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')

        descr = op.getdescr()
        faildescrindex = self.get_gcref_from_faildescr(descr)
        if IS_X86_64:
            self.mc.MOV_rp(eax.value, 0)
            self._patch_load_from_gc_table(faildescrindex)
        elif IS_X86_32:
            self.mc.MOV_rj(eax.value, self._addr_from_gc_table(faildescrindex))
        self.mov(eax, RawEbpLoc(ofs))

        arglist = op.getarglist()
        if arglist and arglist[0].type == REF:
            if self._finish_gcmap:
                # we're returning with a guard_not_forced_2, and
                # additionally we need to say that eax/rax contains
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
            self.mc.MOV_bi(ofs, 0)
        # exit function
        self._call_footer()

    def implement_guard(self, guard_token):
        # These jumps are patched later.
        assert self.guard_success_cc >= 0
        # common case: not taken
        self.mc.J_il(rx86.invert_condition(self.guard_success_cc), 0)
        self.guard_success_cc = rx86.cond_none
        pos = self.mc.get_relative_pos(break_basic_block=False)
        guard_token.pos_jump_offset = pos - 4
        saved = self.mc.get_scratch_register_known_value()
        guard_token.known_scratch_value = saved
        self.pending_guard_tokens.append(guard_token)

    def _genop_real_call(self, op, arglocs, resloc):
        self._genop_call(op, arglocs, resloc)
    genop_call_i = _genop_real_call
    genop_call_r = _genop_real_call
    genop_call_f = _genop_real_call
    genop_call_n = _genop_real_call

    def _genop_call(self, op, arglocs, resloc, is_call_release_gil=False):
        from rpython.jit.backend.llsupport.descr import CallDescr

        func_index = 2 + is_call_release_gil
        cb = callbuilder.CallBuilder(self, arglocs[func_index],
                                     arglocs[func_index+1:], resloc)

        descr = op.getdescr()
        assert isinstance(descr, CallDescr)
        cb.callconv = descr.get_call_conv()
        cb.argtypes = descr.get_arg_types()
        cb.restype  = descr.get_result_type()
        sizeloc = arglocs[0]
        assert isinstance(sizeloc, ImmedLoc)
        cb.ressize = sizeloc.value
        signloc = arglocs[1]
        assert isinstance(signloc, ImmedLoc)
        cb.ressign = signloc.value

        if is_call_release_gil:
            saveerrloc = arglocs[2]
            assert isinstance(saveerrloc, ImmedLoc)
            cb.emit_call_release_gil(saveerrloc.value)
        else:
            effectinfo = descr.get_extra_info()
            if effectinfo is None or effectinfo.check_can_collect():
                cb.emit()
            else:
                cb.emit_no_collect()
        self.num_moves_calls += cb.num_moves

    def _store_force_index(self, guard_op):
        assert (guard_op.getopnum() == rop.GUARD_NOT_FORCED or
                guard_op.getopnum() == rop.GUARD_NOT_FORCED_2)
        faildescr = guard_op.getdescr()
        ofs = self.cpu.get_ofs_of_frame_field('jf_force_descr')

        faildescrindex = self.get_gcref_from_faildescr(faildescr)
        if IS_X86_64:
            self.mc.forget_scratch_register()
            self.mc.MOV_rp(X86_64_SCRATCH_REG.value, 0)
            self._patch_load_from_gc_table(faildescrindex)
            self.mc.MOV(raw_stack(ofs), X86_64_SCRATCH_REG)
        elif IS_X86_32:
            # XXX need a scratch reg here for efficiency; be more clever
            self.mc.PUSH_j(self._addr_from_gc_table(faildescrindex))
            self.mc.POP(raw_stack(ofs))

    def _find_nearby_operation(self, delta):
        regalloc = self._regalloc
        return regalloc.operations[regalloc.rm.position + delta]

    def genop_guard_guard_not_forced(self, guard_op, guard_token, locs, resloc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.CMP_bi(ofs, 0)
        self.guard_success_cc = rx86.Conditions['E']
        self.implement_guard(guard_token)

    def _genop_call_may_force(self, op, arglocs, result_loc):
        self._store_force_index(self._find_nearby_operation(+1))
        self._genop_call(op, arglocs, result_loc)
    genop_call_may_force_i = _genop_call_may_force
    genop_call_may_force_r = _genop_call_may_force
    genop_call_may_force_f = _genop_call_may_force
    genop_call_may_force_n = _genop_call_may_force

    def _genop_call_release_gil(self, op, arglocs, result_loc):
        self._store_force_index(self._find_nearby_operation(+1))
        self._genop_call(op, arglocs, result_loc, is_call_release_gil=True)
    genop_call_release_gil_i = _genop_call_release_gil
    genop_call_release_gil_f = _genop_call_release_gil
    genop_call_release_gil_n = _genop_call_release_gil

    def imm(self, v):
        return imm(v)

    # ------------------- CALL ASSEMBLER --------------------------

    def _genop_call_assembler(self, op, arglocs, result_loc):
        if len(arglocs) == 2:
            [argloc, vloc] = arglocs
        else:
            [argloc] = arglocs
            vloc = self.imm(0)
        self._store_force_index(self._find_nearby_operation(+1))
        self.call_assembler(op, argloc, vloc, result_loc, eax)
    genop_call_assembler_i = _genop_call_assembler
    genop_call_assembler_r = _genop_call_assembler
    genop_call_assembler_f = _genop_call_assembler
    genop_call_assembler_n = _genop_call_assembler

    def _call_assembler_emit_call(self, addr, argloc, _):
        threadlocal_loc = RawEspLoc(THREADLOCAL_OFS, INT)
        self.simple_call(addr, [argloc, threadlocal_loc])

    def _call_assembler_emit_helper_call(self, addr, arglocs, result_loc):
        self.simple_call(addr, arglocs, result_loc)

    def _call_assembler_check_descr(self, value, tmploc):
        ofs = self.cpu.get_ofs_of_frame_field('jf_descr')
        self.mc.CMP(mem(eax, ofs), imm(value))
        # patched later
        return self.mc.emit_forward_jump('E') # goto B if we get 'done_with_this_frame'

    def _call_assembler_patch_je(self, result_loc, je_location):
        if (IS_X86_32 and isinstance(result_loc, FrameLoc) and
            result_loc.type == FLOAT):
            self.mc.FSTPL_b(result_loc.value)
        jmp_location = self.mc.emit_forward_jump_uncond()   # jump to the end
        #
        self.mc.patch_forward_jump(je_location)
        self.mc.force_frame_size(DEFAULT_FRAME_BYTES)
        #
        return jmp_location

    def _call_assembler_load_result(self, op, result_loc):
        if op.type != 'v':
            # load the return value from the dead frame's value index 0
            kind = op.type
            descr = self.cpu.getarraydescr_for_frame(kind)
            ofs = self.cpu.unpack_arraydescr(descr)
            if kind == FLOAT:
                self.mc.MOVSD_xm(xmm0.value, (eax.value, ofs))
                if result_loc is not xmm0:
                    self.mc.MOVSD(result_loc, xmm0)
            else:
                assert result_loc is eax
                self.mc.MOV_rm(eax.value, (eax.value, ofs))

    def _call_assembler_patch_jmp(self, jmp_location):
        self.mc.patch_forward_jump(jmp_location)

    # ------------------- END CALL ASSEMBLER -----------------------

    class WriteBarrierSlowPath(codebuf.SlowPath):
        def generate_body(self, assembler, mc):
            mc.force_frame_size(DEFAULT_FRAME_BYTES)
            # for cond_call_gc_wb_array, also add another fast path:
            # if GCFLAG_CARDS_SET, then we can just set one bit and be done
            card_marking = (self.loc_index is not None)
            if card_marking:
                # GCFLAG_CARDS_SET is in this byte at 0x80, so this fact can
                # been checked by the sign flags of the previous TEST8
                js_location = mc.emit_forward_jump('S')   # patched later
            else:
                js_location = 0

            # Write only a CALL to the helper prepared in advance, passing it as
            # argument the address of the structure we are writing into
            # (the first argument to COND_CALL_GC_WB).
            helper_num = self.helper_num
            is_frame = (helper_num == 4)
            descr = self.descr
            loc_base = self.loc_base
            #
            if not is_frame:
                mc.PUSH(loc_base)
            mc.CALL(imm(assembler.wb_slowpath[helper_num]))
            if not is_frame:
                mc.stack_frame_size_delta(-WORD)

            if card_marking:
                # The helper ends again with a check of the flag in the object.
                # So here, we can simply write again a 'JNS', which will be
                # taken if GCFLAG_CARDS_SET is still not set.
                jns_location = mc.emit_forward_jump('NS')   # patched later
                #
                # patch the JS above
                mc.patch_forward_jump(js_location)
                #
                # case GCFLAG_CARDS_SET: emit a few instructions to do
                # directly the card flag setting
                loc_index = self.loc_index
                if isinstance(loc_index, RegLoc):
                    if IS_X86_64 and isinstance(loc_base, RegLoc):
                        # copy loc_index into r11
                        tmp1 = X86_64_SCRATCH_REG
                        mc.forget_scratch_register()
                        mc.MOV_rr(tmp1.value, loc_index.value)
                        final_pop = False
                    else:
                        # must save the register loc_index before it is mutated
                        mc.PUSH_r(loc_index.value)
                        tmp1 = loc_index
                        final_pop = True
                    # SHR tmp, card_page_shift
                    mc.SHR_ri(tmp1.value, descr.jit_wb_card_page_shift)
                    # XOR tmp, -8
                    mc.XOR_ri(tmp1.value, -8)
                    # BTS [loc_base], tmp
                    if final_pop:
                        # r11 is not specially used, fall back to regloc.py
                        mc.BTS(addr_add_const(loc_base, 0), tmp1)
                    else:
                        # tmp1 is r11!  but in this case, loc_base is a
                        # register so we can invoke directly rx86.py
                        mc.BTS_mr((loc_base.value, 0), tmp1.value)
                    # done
                    if final_pop:
                        mc.POP_r(loc_index.value)
                    #
                elif isinstance(loc_index, ImmedLoc):
                    byte_index = loc_index.value >> descr.jit_wb_card_page_shift
                    byte_ofs = ~(byte_index >> 3)
                    byte_val = 1 << (byte_index & 7)
                    mc.OR8(addr_add_const(loc_base, byte_ofs), imm(byte_val))
                else:
                    raise AssertionError("index is neither RegLoc nor ImmedLoc")
                #
                # patch the JNS above
                mc.patch_forward_jump(jns_location)

    def _write_barrier_fastpath(self, mc, descr, arglocs, array=False,
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
        loc_index = None
        mask = descr.jit_wb_if_flag_singlebyte
        if array and descr.jit_wb_cards_set != 0:
            # assumptions the rest of the function depends on:
            assert (descr.jit_wb_cards_set_byteofs ==
                    descr.jit_wb_if_flag_byteofs)
            assert descr.jit_wb_cards_set_singlebyte == -0x80
            card_marking = True
            loc_index = arglocs[1]
            mask = descr.jit_wb_if_flag_singlebyte | -0x80
        #
        loc_base = arglocs[0]
        if is_frame:
            assert loc_base is ebp
            loc = raw_stack(descr.jit_wb_if_flag_byteofs)
        else:
            loc = addr_add_const(loc_base, descr.jit_wb_if_flag_byteofs)
        #
        helper_num = card_marking
        if is_frame:
            helper_num = 4
        elif self._regalloc is not None and self._regalloc.xrm.reg_bindings:
            helper_num += 2
        if self.wb_slowpath[helper_num] == 0:    # tests only
            assert not we_are_translated()
            self.cpu.gc_ll_descr.write_barrier_descr = descr
            self._build_wb_slowpath(card_marking,
                                    bool(self._regalloc.xrm.reg_bindings))
            assert self.wb_slowpath[helper_num] != 0
        #
        mc.TEST8(loc, imm(mask))
        sp = self.WriteBarrierSlowPath(mc, rx86.Conditions['NZ'])
        sp.loc_base = loc_base
        sp.loc_index = loc_index
        sp.helper_num = helper_num
        sp.descr = descr
        sp.set_continue_addr(mc)
        self.pending_slowpaths.append(sp)

    def genop_discard_cond_call_gc_wb(self, op, arglocs):
        self._write_barrier_fastpath(self.mc, op.getdescr(), arglocs)

    def genop_discard_cond_call_gc_wb_array(self, op, arglocs):
        self._write_barrier_fastpath(self.mc, op.getdescr(), arglocs,
                                     array=True)

    def not_implemented_op_discard(self, op, arglocs):
        not_implemented("not implemented operation: %s" % op.getopname())

    def not_implemented_op(self, op, arglocs, resloc):
        not_implemented("not implemented operation with res: %s" %
                        op.getopname())

    def not_implemented_op_guard(self, guard_op, guard_token, locs, resloc):
        not_implemented("not implemented operation (guard): %s" %
                        guard_op.getopname())

    def closing_jump(self, target_token):
        target = target_token._ll_loop_code
        if target_token in self.target_tokens_currently_compiling:
            curpos = self.mc.get_relative_pos() + 5
            self.mc.JMP_l(target - curpos)
        else:
            self.mc.JMP(imm(target))

    def label(self):
        self.preamble_num_moves_calls += self.num_moves_calls
        self.preamble_num_moves_jump += self.num_moves_jump
        self.preamble_num_spills += self.num_spills
        self.preamble_num_spills_to_existing += self.num_spills_to_existing
        self.preamble_num_reloads += self.num_reloads
        self.num_moves_calls = 0
        self.num_moves_jump = 0
        self.num_spills = 0
        self.num_spills_to_existing = 0
        self.num_reloads = 0
        self._check_frame_depth_debug(self.mc)

    class CondCallSlowPath(codebuf.SlowPath):
        guard_token_no_exception = None

        def generate_body(self, assembler, mc):
            assembler.push_gcmap(mc, self.gcmap, store=True)
            #
            # first save away the 4 registers from
            # 'cond_call_register_arguments' plus the register 'eax'
            base_ofs = assembler.cpu.get_baseofs_of_frame_field()
            should_be_saved = self.should_be_saved
            restore_eax = False
            for gpr in cond_call_register_arguments + [eax]:
                if gpr not in should_be_saved or gpr is self.resloc:
                    continue
                v = gpr_reg_mgr_cls.all_reg_indexes[gpr.value]
                mc.MOV_br(v * WORD + base_ofs, gpr.value)
                if gpr is eax:
                    restore_eax = True
            #
            # load the 0-to-4 arguments into these registers
            from rpython.jit.backend.x86.jump import remap_frame_layout
            arglocs = self.arglocs
            remap_frame_layout(assembler, arglocs,
                               cond_call_register_arguments[:len(arglocs)],
                               X86_64_SCRATCH_REG if IS_X86_64 else None)
            #
            # load the constant address of the function to call into eax
            mc.MOV(eax, self.imm_func)
            #
            # figure out which variant of cond_call_slowpath to call,
            # and call it
            cond_call_adr = assembler.cond_call_slowpath[self.variant_num]
            mc.CALL(imm(follow_jump(cond_call_adr)))
            # if this is a COND_CALL_VALUE, we need to move the result in place
            resloc = self.resloc
            if resloc is not None and resloc is not eax:
                mc.MOV(resloc, eax)
            # restoring the registers saved above, and doing pop_gcmap(), is
            # left to the cond_call_slowpath helper.  We must only restore eax,
            # if needed.
            if restore_eax:
                v = gpr_reg_mgr_cls.all_reg_indexes[eax.value]
                mc.MOV_rb(eax.value, v * WORD + base_ofs)
            #
            # if needed, emit now the guard_no_exception
            if self.guard_token_no_exception is not None:
                assembler.generate_guard_no_exception(
                             self.guard_token_no_exception)

    def cond_call(self, gcmap, imm_func, arglocs, resloc=None):
        assert self.guard_success_cc >= 0
        sp = self.CondCallSlowPath(self.mc, self.guard_success_cc)
        sp.set_continue_addr(self.mc)
        self.guard_success_cc = rx86.cond_none
        sp.gcmap = gcmap
        sp.imm_func = imm_func
        sp.arglocs = arglocs
        sp.resloc = resloc
        sp.should_be_saved = self._regalloc.rm.reg_bindings.values()
        #
        callee_only = False
        floats = False
        if self._regalloc is not None:
            for reg in self._regalloc.rm.reg_bindings.values():
                if reg not in self._regalloc.rm.save_around_call_regs:
                    break
            else:
                callee_only = True
            if self._regalloc.xrm.reg_bindings:
                floats = True
        sp.variant_num = floats * 2 + callee_only
        #
        self.pending_slowpaths.append(sp)

    class MallocCondSlowPath(codebuf.SlowPath):
        def generate_body(self, assembler, mc):
            assembler.push_gcmap(mc, self.gcmap, store=True)
            mc.CALL(imm(follow_jump(assembler.malloc_slowpath)))

    def malloc_cond(self, nursery_free_adr, nursery_top_adr, size, gcmap):
        assert size & (WORD-1) == 0     # must be correctly aligned
        self.mc.MOV(ecx, heap(nursery_free_adr))
        self.mc.LEA_rm(edx.value, (ecx.value, size))
        self.mc.CMP(edx, heap(nursery_top_adr))
        sp = self.MallocCondSlowPath(self.mc, rx86.Conditions['A'])
        sp.gcmap = gcmap
        self.mc.MOV(heap(nursery_free_adr), edx)
        sp.set_continue_addr(self.mc)
        self.pending_slowpaths.append(sp)

    def malloc_cond_varsize_frame(self, nursery_free_adr, nursery_top_adr,
                                  sizeloc, gcmap):
        if sizeloc is ecx:
            self.mc.MOV(edx, sizeloc)
            sizeloc = edx
        self.mc.MOV(ecx, heap(nursery_free_adr))
        if sizeloc is edx:
            self.mc.ADD_rr(edx.value, ecx.value)
        else:
            self.mc.LEA_ra(edx.value, (ecx.value, sizeloc.value, 0, 0))
        self.mc.CMP(edx, heap(nursery_top_adr))
        sp = self.MallocCondSlowPath(self.mc, rx86.Conditions['A'])
        sp.gcmap = gcmap
        self.mc.MOV(heap(nursery_free_adr), edx)
        sp.set_continue_addr(self.mc)
        self.pending_slowpaths.append(sp)

    class MallocCondVarsizeSlowPath(codebuf.SlowPath):
        def generate_body(self, assembler, mc):
            # save the gcmap
            assembler.push_gcmap(mc, self.gcmap, store=True)
            kind = self.kind
            if kind == rewrite.FLAG_ARRAY:
                mc.MOV_si(WORD, self.itemsize)
                mc.MOV_ri(ecx.value, self.arraydescr.tid)
                addr = assembler.malloc_slowpath_varsize
            else:
                if kind == rewrite.FLAG_STR:
                    addr = assembler.malloc_slowpath_str
                else:
                    assert kind == rewrite.FLAG_UNICODE
                    addr = assembler.malloc_slowpath_unicode
            lengthloc = self.lengthloc
            assert lengthloc is not ecx and lengthloc is not edx
            mc.MOV(edx, lengthloc)
            mc.CALL(imm(follow_jump(addr)))

    def malloc_cond_varsize(self, kind, nursery_free_adr, nursery_top_adr,
                            lengthloc, itemsize, maxlength, gcmap,
                            arraydescr):
        from rpython.jit.backend.llsupport.descr import ArrayDescr
        assert isinstance(arraydescr, ArrayDescr)

        # lengthloc is the length of the array, which we must not modify!
        assert lengthloc is not ecx and lengthloc is not edx
        if isinstance(lengthloc, RegLoc):
            varsizeloc = lengthloc
        else:
            self.mc.MOV(edx, lengthloc)
            varsizeloc = edx

        self.mc.CMP(varsizeloc, imm(maxlength))
        ja_location = self.mc.emit_forward_jump('A')   # patched later

        self.mc.MOV(ecx, heap(nursery_free_adr))
        if valid_addressing_size(itemsize):
            shift = get_scale(itemsize)
        else:
            shift = self._imul_const_scaled(self.mc, edx.value,
                                            varsizeloc.value, itemsize)
            varsizeloc = edx

        # now varsizeloc is a register != ecx.  The size of
        # the variable part of the array is (varsizeloc << shift)
        assert arraydescr.basesize >= self.gc_minimal_size_in_nursery
        constsize = arraydescr.basesize + self.gc_size_of_header
        force_realignment = (itemsize % WORD) != 0
        if force_realignment:
            constsize += WORD - 1
        self.mc.LEA_ra(edx.value, (ecx.value, varsizeloc.value, shift,
                                   constsize))
        if force_realignment:
            self.mc.AND_ri(edx.value, ~(WORD - 1))
        # now edx contains the total size in bytes, rounded up to a multiple
        # of WORD, plus nursery_free_adr
        self.mc.CMP(edx, heap(nursery_top_adr))
        self.mc.patch_forward_jump(ja_location)
        # Note: we call the slow path in condition 'A', which may be
        # true either because the CMP just above really got that
        # condition, or because we jumped here from ja_location before.
        # In both cases, the jumps are forward-going and the expected
        # common case is "not taken".
        sp = self.MallocCondVarsizeSlowPath(self.mc, rx86.Conditions['A'])
        sp.gcmap = gcmap
        sp.kind = kind
        sp.itemsize = itemsize
        sp.lengthloc = lengthloc
        sp.arraydescr = arraydescr
        # some more code that is only if we *don't* call the slow
        # path: write down the tid, and save edx into nursery_free_adr
        self.mc.MOV(mem(ecx, 0), imm(arraydescr.tid))
        self.mc.MOV(heap(nursery_free_adr), edx)
        sp.set_continue_addr(self.mc)
        self.pending_slowpaths.append(sp)

    def store_force_descr(self, op, fail_locs, frame_depth):
        guard_token = self.implement_guard_recovery(op.opnum,
                                                    op.getdescr(),
                                                    op.getfailargs(),
                                                    fail_locs, frame_depth)
        self._finish_gcmap = guard_token.gcmap
        self._store_force_index(op)
        self.store_info_on_descr(0, guard_token)

    def force_token(self, reg):
        # XXX kill me
        assert isinstance(reg, RegLoc)
        self.mc.MOV_rr(reg.value, ebp.value)

    def threadlocalref_get(self, offset, resloc, size, sign):
        # This loads the stack location THREADLOCAL_OFS into a
        # register, and then read the word at the given offset.
        # It is only supported if 'translate_support_code' is
        # true; otherwise, the execute_token() was done with a
        # dummy value for the stack location THREADLOCAL_OFS
        #
        assert self.cpu.translate_support_code
        assert isinstance(resloc, RegLoc)
        self.mc.MOV_rs(resloc.value, THREADLOCAL_OFS)
        self.load_from_mem(resloc, addr_add_const(resloc, offset),
                           imm(size), imm(sign))

    def genop_discard_zero_array(self, op, arglocs):
        (base_loc, startindex_loc, bytes_loc,
         itemsize_loc, baseofs_loc, null_loc) = arglocs
        assert isinstance(bytes_loc, ImmedLoc)
        assert isinstance(itemsize_loc, ImmedLoc)
        assert isinstance(baseofs_loc, ImmedLoc)
        assert isinstance(null_loc, RegLoc) and null_loc.is_xmm
        baseofs = baseofs_loc.value
        nbytes = bytes_loc.value
        assert valid_addressing_size(itemsize_loc.value)
        scale = get_scale(itemsize_loc.value)
        null_reg_cleared = False
        i = 0
        while i < nbytes:
            addr = addr_add(base_loc, startindex_loc, baseofs + i, scale)
            current = nbytes - i
            if current >= 16 and self.cpu.supports_floats:
                current = 16
                if not null_reg_cleared:
                    self.mc.XORPS_xx(null_loc.value, null_loc.value)
                    null_reg_cleared = True
                self.mc.MOVUPS(addr, null_loc)
            else:
                if current >= WORD:
                    current = WORD
                elif current >= 4:
                    current = 4
                elif current >= 2:
                    current = 2
                self.save_into_mem(addr, imm0, imm(current))
            i += current


genop_discard_list = [Assembler386.not_implemented_op_discard] * rop._LAST
genop_list = [Assembler386.not_implemented_op] * rop._LAST
genop_llong_list = {}
genop_math_list = {}
genop_tlref_list = {}
genop_guard_list = [Assembler386.not_implemented_op_guard] * rop._LAST

import itertools
iterate = itertools.chain(Assembler386.__dict__.iteritems(),
                          VectorAssemblerMixin.__dict__.iteritems())
for name, value in iterate:
    if name.startswith('genop_discard_'):
        opname = name[len('genop_discard_'):]
        num = getattr(rop, opname.upper())
        genop_discard_list[num] = value
    elif name.startswith('genop_guard_'):
        opname = name[len('genop_guard_'):]
        num = getattr(rop, opname.upper())
        genop_guard_list[num] = value
    elif name.startswith('genop_llong_'):
        opname = name[len('genop_llong_'):]
        num = getattr(EffectInfo, 'OS_LLONG_' + opname.upper())
        genop_llong_list[num] = value
    elif name.startswith('genop_math_'):
        opname = name[len('genop_math_'):]
        num = getattr(EffectInfo, 'OS_MATH_' + opname.upper())
        genop_math_list[num] = value
    elif name.startswith('genop_'):
        opname = name[len('genop_'):]
        num = getattr(rop, opname.upper())
        genop_list[num] = value

# XXX: ri386 migration shims:
def addr_add(reg_or_imm1, reg_or_imm2, offset=0, scale=0):
    return AddressLoc(reg_or_imm1, reg_or_imm2, scale, offset)

def addr_add_const(reg_or_imm1, offset):
    return AddressLoc(reg_or_imm1, imm0, 0, offset)

def mem(loc, offset):
    return AddressLoc(loc, imm0, 0, offset)

def raw_stack(offset, type=INT):
    return RawEbpLoc(offset, type)

def heap(addr):
    return AddressLoc(ImmedLoc(addr), imm0, 0, 0)

def not_implemented(msg):
    msg = '[x86/asm] %s\n' % msg
    if we_are_translated():
        llop.debug_print(lltype.Void, msg)
    raise NotImplementedError(msg)

cond_call_register_arguments = callbuilder.CallBuilder64.ARGUMENTS_GPR[:4]

class BridgeAlreadyCompiled(Exception):
    pass
