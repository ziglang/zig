import sys
from rpython.rlib.clibffi import FFI_DEFAULT_ABI
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rarithmetic import intmask
from rpython.jit.metainterp.history import INT, FLOAT
from rpython.jit.backend.x86.arch import (WORD, IS_X86_64, IS_X86_32,
                                          PASS_ON_MY_FRAME, FRAME_FIXED_SIZE,
                                          THREADLOCAL_OFS, WIN64)
from rpython.jit.backend.x86.regloc import (eax, ecx, edx, ebx, esp, ebp, esi,
    xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, r8, r9, r10, r11, edi,
    r12, r13, r14, r15, X86_64_SCRATCH_REG, X86_64_XMM_SCRATCH_REG,
    RegLoc, RawEspLoc, RawEbpLoc, imm, ImmedLoc)
from rpython.jit.backend.x86.jump import remap_frame_layout
from rpython.jit.backend.x86 import codebuf
from rpython.jit.backend.llsupport.callbuilder import AbstractCallBuilder
from rpython.jit.backend.llsupport import llerrno, lltls
from rpython.rtyper.lltypesystem import llmemory, rffi


# darwin requires the stack to be 16 bytes aligned on calls.
# Same for gcc 4.5.0, better safe than sorry
CALL_ALIGN = 16 // WORD

stdcall_or_cdecl = sys.platform == "win32"
handle_lasterror = sys.platform == "win32"

def align_stack_words(words):
    return (words + CALL_ALIGN - 1) & ~(CALL_ALIGN-1)

def follow_jump(addr):
    # If 'addr' is immediately starting with another JMP instruction,
    # follow it now.  'addr' is an absolute address here
    while rffi.cast(rffi.CCHARP, addr)[0] == '\xE9':    # JMP <4 bytes>
        addr += 5
        addr += intmask(rffi.cast(rffi.INTP, addr - 4)[0])
    return addr


class CallBuilderX86(AbstractCallBuilder):

    # max number of words we have room in esp; if we need more for
    # arguments, we need to decrease esp temporarily
    stack_max = PASS_ON_MY_FRAME

    tlofs_reg = None
    saved_stack_position_reg = None
    result_value_saved_early = False

    def __init__(self, assembler, fnloc, arglocs,
                 resloc=eax, restype=INT, ressize=WORD):
        AbstractCallBuilder.__init__(self, assembler, fnloc, arglocs,
                                     resloc, restype, ressize)
        # Avoid tons of issues with a non-immediate fnloc by sticking it
        # as an extra argument if needed
        if isinstance(fnloc, ImmedLoc):
            self.fnloc_is_immediate = True
            self.fnloc = imm(follow_jump(fnloc.value))
        else:
            self.fnloc_is_immediate = False
            self.fnloc = None
            self.arglocs = arglocs + [fnloc]
        self.start_frame_size = self.mc._frame_size

    def subtract_esp_aligned(self, count):
        if count > 0:
            align = align_stack_words(count)
            self.mc.SUB_ri(esp.value, align * WORD)

    def get_current_esp(self):
        return self.start_frame_size - self.mc._frame_size

    def restore_stack_pointer(self, target_esp=0):
        current_esp = self.get_current_esp()
        if current_esp != target_esp:
            self.mc.ADD_ri(esp.value, target_esp - current_esp)

    def load_result(self):
        """Overridden in CallBuilder32 and CallBuilder64"""
        if self.ressize == 0:
            return      # void result
        # use the code in load_from_mem to do the zero- or sign-extension
        if self.restype == FLOAT:
            srcloc = xmm0
        else:
            srcloc = eax
        if self.ressize >= WORD and self.resloc is srcloc:
            return      # no need for any MOV
        if self.ressize == 1 and isinstance(srcloc, RegLoc):
            srcloc = srcloc.lowest8bits()
        self.asm.load_from_mem(self.resloc, srcloc,
                               imm(self.ressize), imm(self.ressign))

    def push_gcmap(self):
        # we push *now* the gcmap, describing the status of GC registers
        # after the rearrangements done just before, ignoring the return
        # value eax, if necessary
        assert not self.is_call_release_gil
        current_esp = self.get_current_esp()
        #
        # * Note: these commented-out pieces of code about 'extra_stack_depth'
        # * are not necessary any more, but they are kept around in case we
        # * need in the future again to track the exact stack depth.
        #
        #self.change_extra_stack_depth = (current_esp != 0)
        #if self.change_extra_stack_depth:
        #    self.asm.set_extra_stack_depth(self.mc, -current_esp)
        noregs = self.asm.cpu.gc_ll_descr.is_shadow_stack()
        gcmap = self.asm._regalloc.get_gcmap([eax], noregs=noregs)
        self.asm.push_gcmap(self.mc, gcmap, store=True)

    def pop_gcmap(self):
        ssreg = None
        gcrootmap = self.asm.cpu.gc_ll_descr.gcrootmap
        if gcrootmap:
            if gcrootmap.is_shadow_stack and self.is_call_release_gil:
                # in this mode, 'ebx' happens to contain the shadowstack
                # top at this point, so reuse it instead of loading it again
                ssreg = ebx
        self.asm._reload_frame_if_necessary(self.mc, shadowstack_reg=ssreg)
        #if self.change_extra_stack_depth:
        #    self.asm.set_extra_stack_depth(self.mc, 0)
        self.asm.pop_gcmap(self.mc)

    def call_releasegil_addr_and_move_real_arguments(self, fastgil):
        from rpython.jit.backend.x86.assembler import heap
        assert self.is_call_release_gil
        assert not self.asm._is_asmgcc()
        #
        # Save this thread's shadowstack pointer into 'ebx',
        # for later comparison
        gcrootmap = self.asm.cpu.gc_ll_descr.gcrootmap
        if gcrootmap:
            if gcrootmap.is_shadow_stack:
                rst = gcrootmap.get_root_stack_top_addr()
                self.mc.MOV(ebx, heap(rst))
        #
        # shadowstack: change 'rpy_fastgil' to 0 (it should be
        # non-zero right now).
        #self.change_extra_stack_depth = False
        #
        # <--here--> would come a memory fence, if the CPU needed one.
        self.mc.MOV(heap(fastgil), imm(0))
        #
        if not we_are_translated():        # for testing: we should not access
            self.mc.ADD(ebp, imm(1))       # ebp any more

    def get_tlofs_reg(self):
        """Load the THREADLOCAL_OFS from the stack into a callee-saved
        register.  Further calls just return the same register, by assuming
        it is indeed saved."""
        assert self.is_call_release_gil
        if self.tlofs_reg is None:
            # pick a register saved across calls
            if IS_X86_32:
                self.tlofs_reg = esi
            else:
                self.tlofs_reg = r12
            self.mc.MOV_rs(self.tlofs_reg.value,
                           THREADLOCAL_OFS - self.get_current_esp())
        return self.tlofs_reg

    def save_stack_position(self):
        """Load the current 'esp' value into a callee-saved register.
        Further calls just return the same register, by assuming it is
        indeed saved."""
        assert IS_X86_32     # only for 32-bit Windows
        assert stdcall_or_cdecl and self.is_call_release_gil
        if self.saved_stack_position_reg is None:
            # pick a register saved across calls
            self.saved_stack_position_reg = edi
            self.mc.MOV(self.saved_stack_position_reg, esp)

    def write_real_errno(self, save_err):
        """This occurs just before emit_raw_call().
        """
        mc = self.mc

        if handle_lasterror and (save_err & rffi.RFFI_READSAVED_LASTERROR):
            # must call SetLastError().  There are no registers to save
            # if we are on 32-bit in this case: no register contains
            # the arguments to the main function we want to call afterwards.
            # On win64, though, it's more messy.  It could be better optimized
            # but for now we save (again) the registers containing arguments,
            # and restore them afterwards.
            from rpython.rlib.rwin32 import _SetLastError
            adr = llmemory.cast_ptr_to_adr(_SetLastError)
            SetLastError_addr = self.asm.cpu.cast_adr_to_int(adr)
            #
            if save_err & rffi.RFFI_ALT_ERRNO:
                lasterror = llerrno.get_alt_lasterror_offset(self.asm.cpu)
            else:
                lasterror = llerrno.get_rpy_lasterror_offset(self.asm.cpu)
            tlofsreg = self.get_tlofs_reg()    # => esi or r12, callee-saved
            if not WIN64:
                self.save_stack_position()         # => edi, callee-saved
                mc.PUSH_m((tlofsreg.value, lasterror))
                mc.CALL(imm(follow_jump(SetLastError_addr)))
                # restore the stack position without assuming a particular
                # calling convention of _SetLastError()
                self.mc.stack_frame_size_delta(-WORD)
                self.mc.MOV(esp, self.saved_stack_position_reg)
            else:
                self.win64_save_register_args()
                mc.MOV_rm(ecx.value, (tlofsreg.value, lasterror))
                mc.CALL(imm(follow_jump(SetLastError_addr)))
                self.win64_restore_register_args()

        if save_err & rffi.RFFI_READSAVED_ERRNO:
            # Just before a call, read '*_errno' and write it into the
            # real 'errno'.  Most registers are free here, including the
            # callee-saved ones, except 'ebx' and except the ones used to
            # pass the arguments on x86-64.
            if save_err & rffi.RFFI_ALT_ERRNO:
                rpy_errno = llerrno.get_alt_errno_offset(self.asm.cpu)
            else:
                rpy_errno = llerrno.get_rpy_errno_offset(self.asm.cpu)
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            tlofsreg = self.get_tlofs_reg()    # => esi or r12, callee-saved
            if IS_X86_32:
                tmpreg = edx
            else:
                tmpreg = r10                   # edx is used for 3rd argument
            mc.MOV_rm(tmpreg.value, (tlofsreg.value, p_errno))
            mc.MOV32_rm(eax.value, (tlofsreg.value, rpy_errno))
            mc.MOV32_mr((tmpreg.value, 0), eax.value)
        elif save_err & rffi.RFFI_ZERO_ERRNO_BEFORE:
            # Same, but write zero.
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            tlofsreg = self.get_tlofs_reg()    # => esi or r12, callee-saved
            mc.MOV_rm(eax.value, (tlofsreg.value, p_errno))
            mc.MOV32_mi((eax.value, 0), 0)

    def read_real_errno(self, save_err):
        """This occurs after emit_raw_call() and after restore_stack_pointer().
        """
        mc = self.mc

        if save_err & rffi.RFFI_SAVE_ERRNO:
            # Just after a call, read the real 'errno' and save a copy of
            # it inside our thread-local '*_errno'.  Most registers are
            # free here, including the callee-saved ones, except 'ebx'.
            # The tlofs register might have been loaded earlier and is
            # callee-saved, so it does not need to be reloaded.
            if save_err & rffi.RFFI_ALT_ERRNO:
                rpy_errno = llerrno.get_alt_errno_offset(self.asm.cpu)
            else:
                rpy_errno = llerrno.get_rpy_errno_offset(self.asm.cpu)
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            tlofsreg = self.get_tlofs_reg()   # => esi or r12 (possibly reused)
            mc.MOV_rm(ecx.value, (tlofsreg.value, p_errno))
            mc.MOV32_rm(ecx.value, (ecx.value, 0))
            mc.MOV32_mr((tlofsreg.value, rpy_errno), ecx.value)

        if handle_lasterror and (save_err & (rffi.RFFI_SAVE_LASTERROR |
                                             rffi.RFFI_SAVE_WSALASTERROR)):
            if save_err & rffi.RFFI_SAVE_LASTERROR:
                from rpython.rlib.rwin32 import _GetLastError
                adr = llmemory.cast_ptr_to_adr(_GetLastError)
            else:
                from rpython.rlib._rsocket_rffi import _WSAGetLastError
                adr = llmemory.cast_ptr_to_adr(_WSAGetLastError)
            GetLastError_addr = self.asm.cpu.cast_adr_to_int(adr)
            #
            if save_err & rffi.RFFI_ALT_ERRNO:
                lasterror = llerrno.get_alt_lasterror_offset(self.asm.cpu)
            else:
                lasterror = llerrno.get_rpy_lasterror_offset(self.asm.cpu)
            self.save_result_value(save_edx=True)   # save eax/edx/xmm0
            self.result_value_saved_early = True
            mc.CALL(imm(follow_jump(GetLastError_addr)))
            #
            tlofsreg = self.get_tlofs_reg()    # => esi or r12 (possibly reused)
            mc.MOV32_mr((tlofsreg.value, lasterror), eax.value)

    class ReacqGilSlowPath(codebuf.SlowPath):
        early_jump_addr = 0

        def generate_body(self, assembler, mc):
            if self.early_jump_addr != 0:
                # This slow-path has two entry points, with two
                # conditional jumps.  We can jump to the regular start
                # of this slow-path with the 2nd conditional jump.  Or,
                # we can jump past the "MOV(heap(fastgil), 0)"
                # instruction from the 1st conditional jump.
                # This instruction reverts the rpy_fastgil acquired
                # previously, so that the general 'reacqgil_addr'
                # function can acquire it again.  It must only be done
                # if we actually succeeded in acquiring rpy_fastgil.
                from rpython.jit.backend.x86.assembler import heap
                mc.MOV(heap(self.fastgil), imm(0))
                offset = mc.get_relative_pos() - self.early_jump_addr
                mc.overwrite32(self.early_jump_addr-4, offset)
                # scratch register forgotten here, by get_relative_pos()

            # call the reacqgil() function
            cb = self.callbuilder
            if not cb.result_value_saved_early:
                cb.save_result_value(save_edx=False)
            mc.CALL(imm(follow_jump(assembler.reacqgil_addr)))
            if not cb.result_value_saved_early:
                cb.restore_result_value(save_edx=False)

    def move_real_result_and_call_reacqgil_addr(self, fastgil):
        from rpython.jit.backend.x86 import rx86
        #
        # check if we need to call the reacqgil() function or not
        # (to acquiring the GIL)
        mc = self.mc
        restore_edx = False
        #
        # Make sure we can use 'eax' in the sequel for CMPXCHG
        # On 32-bit, we also need to check if restype is 'L' for long long,
        # in which case we need to save eax and edx because they are both
        # used for the return value.
        if self.restype in (INT, 'L') and not self.result_value_saved_early:
            self.save_result_value(save_edx = self.restype == 'L')
            self.result_value_saved_early = True
        #
        # Use LOCK CMPXCHG as a compare-and-swap with memory barrier.
        tlsreg = self.get_tlofs_reg()
        thread_ident_ofs = lltls.get_thread_ident_offset(self.asm.cpu)
        #
        mc.MOV_rm(ecx.value, (tlsreg.value, thread_ident_ofs))
        mc.XOR_rr(eax.value, eax.value)

        if rx86.fits_in_32bits(fastgil):
            mc.LOCK()
            mc.CMPXCHG_jr(fastgil, ecx.value)
        else:
            mc.MOV_ri(X86_64_SCRATCH_REG.value, fastgil)
            mc.LOCK()
            mc.CMPXCHG_mr((X86_64_SCRATCH_REG.value, 0), ecx.value)
        #
        gcrootmap = self.asm.cpu.gc_ll_descr.gcrootmap
        if bool(gcrootmap):
            from rpython.jit.backend.x86.assembler import heap
            assert gcrootmap.is_shadow_stack
            #
            # When doing a call_release_gil with shadowstack, there
            # is the risk that the 'rpy_fastgil' was free but the
            # current shadowstack can be the one of a different
            # thread.  So here we check if the shadowstack pointer
            # is still the same as before we released the GIL (saved
            # in 'ebx'), and if not, we fall back to 'reacqgil_addr'.
            mc.J_il(rx86.Conditions['NZ'], 0xfffff)     # patched later
            early_jump_addr = mc.get_relative_pos(break_basic_block=False)
            # ^^^ this jump will go to almost the same place as the
            # ReacqGilSlowPath() computes, but one instruction further,
            # i.e. just after the "MOV(heap(fastgil), 0)".

            rst = gcrootmap.get_root_stack_top_addr()
            mc = self.mc
            mc.CMP(ebx, heap(rst))
            sp = self.ReacqGilSlowPath(mc, rx86.Conditions['NE'])
            sp.early_jump_addr = early_jump_addr
            sp.fastgil = fastgil
        else:
            sp = self.ReacqGilSlowPath(mc, rx86.Conditions['NZ'])
        sp.callbuilder = self
        sp.set_continue_addr(mc)
        self.asm.pending_slowpaths.append(sp)
        #
        if restore_edx:
            mc.MOV_rs(edx.value, 12)   # restore this
        #
        if self.result_value_saved_early:
            self.restore_result_value(save_edx=True)
        #
        if not we_are_translated():    # for testing: now we can accesss
            mc.SUB(ebp, imm(1))        # ebp again
        #
        # Now that we required the GIL, we will reload a possibly modified ebp:
        # this done for us by _reload_frame_if_necessary()

    def save_result_value(self, save_edx):
        """Overridden in CallBuilder32 and CallBuilder64"""
        raise NotImplementedError

    def restore_result_value(self, save_edx):
        """Overridden in CallBuilder32 and CallBuilder64"""
        raise NotImplementedError


class CallBuilder32(CallBuilderX86):

    def prepare_arguments(self):
        arglocs = self.arglocs
        stack_depth = 0
        n = len(arglocs)
        for i in range(n):
            loc = arglocs[i]
            stack_depth += loc.get_width() // WORD
        self.subtract_esp_aligned(stack_depth - self.stack_max)
        #
        p = 0
        num_moves = 0
        for i in range(n):
            loc = arglocs[i]
            if isinstance(loc, RegLoc):
                num_moves += 1
                if loc.is_xmm:
                    self.mc.MOVSD_sx(p, loc.value)
                else:
                    self.mc.MOV_sr(p, loc.value)
            p += loc.get_width()
        p = 0
        for i in range(n):
            loc = arglocs[i]
            if not isinstance(loc, RegLoc):
                if loc.get_width() == 8:
                    num_moves += 2
                    self.mc.MOVSD(xmm0, loc)
                    self.mc.MOVSD_sx(p, xmm0.value)
                elif isinstance(loc, ImmedLoc):
                    num_moves += 1
                    self.mc.MOV_si(p, loc.value)
                else:
                    num_moves += 2
                    self.mc.MOV(eax, loc)
                    self.mc.MOV_sr(p, eax.value)
            p += loc.get_width()
        self.total_stack_used_by_arguments = p
        #
        if not self.fnloc_is_immediate:    # the last "argument" pushed above
            self.fnloc = RawEspLoc(p - WORD, INT)
        self.num_moves = num_moves

    def emit_raw_call(self):
        if IS_X86_32 and stdcall_or_cdecl and self.is_call_release_gil:
            # Dynamically accept both stdcall and cdecl functions.
            # We could try to detect from pyjitpl which calling
            # convention this particular function takes, which would
            # avoid these two extra MOVs... but later.
            self.save_stack_position()      # => edi (possibly reused)
            self.mc.CALL(self.fnloc)
            self.mc.MOV(esp, self.saved_stack_position_reg)
        else:
            self.mc.CALL(self.fnloc)
            if IS_X86_32 and self.callconv != FFI_DEFAULT_ABI:
                # in the STDCALL ABI, the CALL above has an effect on
                # the stack depth.  Adjust 'mc._frame_size'.
                delta = self._fix_stdcall(self.callconv)
                self.mc.stack_frame_size_delta(-delta)

    def _fix_stdcall(self, callconv):
        from rpython.rlib.clibffi import FFI_STDCALL
        assert callconv == FFI_STDCALL
        return self.total_stack_used_by_arguments

    def load_result(self):
        resloc = self.resloc
        if resloc is not None and resloc.is_float():
            # a float or a long long return
            if self.restype == 'L':     # long long
                # move eax/edx -> xmm0
                self.mc.MOVD32_xr(resloc.value^1, edx.value)
                self.mc.MOVD32_xr(resloc.value,   eax.value)
                self.mc.PUNPCKLDQ_xx(resloc.value, resloc.value^1)
            else:
                # float: we have to go via the stack
                self.mc.FSTPL_s(0)
                self.mc.MOVSD_xs(resloc.value, 0)
            #
        elif self.restype == 'S':
            # singlefloat return: must convert ST(0) to a 32-bit singlefloat
            # and load it into self.resloc.  mess mess mess
            self.mc.FSTPS_s(0)
            self.mc.MOV_rs(resloc.value, 0)
        else:
            CallBuilderX86.load_result(self)

    def save_result_value(self, save_edx):
        # Temporarily save the result value into [ESP+8].  We use "+8"
        # in order to leave the two initial words free, in case it's needed.
        # Also note that in this 32-bit case, a long long return value is
        # in eax/edx, but we already saved the value of edx in
        # move_real_result_and_call_reacqgil_addr().
        if self.ressize == 0:      # void return
            return
        if self.resloc.is_float():
            # a float or a long long return
            if self.restype == 'L':
                self.mc.MOV_sr(8, eax.value)      # long long
                if save_edx:
                    self.mc.MOV_sr(12, edx.value)
            else:
                self.mc.FSTPL_s(8)                # float return
        else:
            if self.restype == 'S':
                self.mc.FSTPS_s(8)
            else:
                assert self.restype == INT
                assert self.ressize <= WORD
                self.mc.MOV_sr(8, eax.value)

    def restore_result_value(self, save_edx):
        # Opposite of save_result_value()
        if self.ressize == 0:      # void return
            return
        if self.resloc.is_float():
            # a float or a long long return
            if self.restype == 'L':
                self.mc.MOV_rs(eax.value, 8)      # long long
                if save_edx:
                    self.mc.MOV_rs(edx.value, 12)
            else:
                self.mc.FLDL_s(8)                 # float return
        else:
            if self.restype == 'S':
                self.mc.FLDS_s(8)
            else:
                assert self.restype == INT
                assert self.ressize <= WORD
                self.mc.MOV_rs(eax.value, 8)


class CallBuilder64(CallBuilderX86):

    if not WIN64:
        ARGUMENTS_GPR = [edi, esi, edx, ecx, r8, r9]
        ARGUMENTS_XMM = [xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7]
    else:
        ARGUMENTS_GPR = [ecx, edx, r8, r9]
        ARGUMENTS_XMM = [xmm0, xmm1, xmm2, xmm3]
    ARG0 = ARGUMENTS_GPR[0]
    ARG1 = ARGUMENTS_GPR[1]
    ARG2 = ARGUMENTS_GPR[2]

    next_arg_gpr = 0
    next_arg_xmm = 0
    win64_arg_gpr = 0
    win64_arg_xmm = 0

    def _unused_gpr(self, hint):
        i = self.next_arg_gpr
        self.next_arg_gpr = i + 1
        if WIN64:
            self.next_arg_xmm = self.next_arg_gpr
        try:
            res = self.ARGUMENTS_GPR[i]
        except IndexError:
            return None
        if WIN64:
            self.win64_arg_gpr |= 1 << i
        return res

    def _unused_xmm(self):
        i = self.next_arg_xmm
        self.next_arg_xmm = i + 1
        if WIN64:
            self.next_arg_gpr = self.next_arg_xmm
        try:
            res = self.ARGUMENTS_XMM[i]
        except IndexError:
            return None
        if WIN64:
            self.win64_arg_xmm |= 1 << i
        return res

    def win64_save_register_args(self):
        # Arguments 0 to 3 are in argument registers; further arguments are already in the stack
        # beyond 4 unused words that will be the shadow space for the CALL.  We can save these
        # arguments 0 to 3 inside that space, but after we do, we need to reserve another shadow
        # space for the call to SetLastError that we'll do immediately afterwards...
        # We might instead save arguments inside esi/edi/r14/r15 at this point, which should
        # be free and callee-save on Win64.  Unclear it's worth the crash if I'm wrong, though...
        assert len(self.ARGUMENTS_GPR) == 4
        assert len(self.ARGUMENTS_XMM) == 4
        for i in range(4):
            if self.win64_arg_gpr & (1 << i):
                self.mc.MOV_sr(i * WORD, self.ARGUMENTS_GPR[i].value)
            elif self.win64_arg_xmm & (1 << i):
                self.mc.MOVSD_sx(i * WORD, self.ARGUMENTS_XMM[i].value)
        self.mc.SUB_ri(esp.value, 4 * WORD)

    def win64_restore_register_args(self):
        self.mc.ADD_ri(esp.value, 4 * WORD)
        for i in range(4):
            if self.win64_arg_gpr & (1 << i):
                self.mc.MOV_rs(self.ARGUMENTS_GPR[i].value, i * WORD)
            elif self.win64_arg_xmm & (1 << i):
                self.mc.MOVSD_xs(self.ARGUMENTS_XMM[i].value, i * WORD)

    def prepare_arguments(self):
        src_locs = []
        dst_locs = []
        xmm_src_locs = []
        xmm_dst_locs = []
        singlefloats = None

        arglocs = self.arglocs
        argtypes = self.argtypes

        on_stack = 0
        if WIN64:
            on_stack = 4      # shadow parameters (space reserved by the caller)
        for i in range(len(arglocs)):
            loc = arglocs[i]
            if loc.is_float():
                tgt = self._unused_xmm()
                if tgt is None:
                    tgt = RawEspLoc(on_stack * WORD, FLOAT)
                    on_stack += 1
                xmm_src_locs.append(loc)
                xmm_dst_locs.append(tgt)
            elif i < len(argtypes) and argtypes[i] == 'S':
                # Singlefloat argument
                if singlefloats is None:
                    singlefloats = []
                tgt = self._unused_xmm()
                if tgt is None:
                    tgt = RawEspLoc(on_stack * WORD, INT)
                    on_stack += 1
                singlefloats.append((loc, tgt))
            else:
                tgt = self._unused_gpr(hint=loc)
                if tgt is None:
                    tgt = RawEspLoc(on_stack * WORD, INT)
                    on_stack += 1
                src_locs.append(loc)
                dst_locs.append(tgt)

        if not self.fnloc_is_immediate:
            self.fnloc = dst_locs[-1]     # the last "argument" prepared above

        if not we_are_translated():  # assert that we got the right stack depth
            floats = 0
            for i in range(len(arglocs)):
                arg = arglocs[i]
                if arg.is_float() or (i < len(argtypes) and argtypes[i]=='S'):
                    floats += 1
            all_args = len(arglocs)
            if not WIN64:
                stack_depth = (max(all_args - floats - len(self.ARGUMENTS_GPR), 0)
                               + max(floats - len(self.ARGUMENTS_XMM), 0))
            else:
                stack_depth = max(all_args, 4)
            assert stack_depth == on_stack

        self.subtract_esp_aligned(on_stack - self.stack_max)

        # Handle register arguments: first remap the xmm arguments
        num_moves = remap_frame_layout(self.asm, xmm_src_locs, xmm_dst_locs,
                                       X86_64_XMM_SCRATCH_REG)
        # Load the singlefloat arguments from main regs or stack to xmm regs
        if singlefloats is not None:
            for src, dst in singlefloats:
                if isinstance(dst, RawEspLoc):
                    # XXX too much special logic
                    if isinstance(src, RawEbpLoc):
                        num_moves += 2
                        self.mc.MOV32(X86_64_SCRATCH_REG, src)
                        self.mc.MOV32(dst, X86_64_SCRATCH_REG)
                    else:
                        num_moves += 1
                        self.mc.MOV32(dst, src)
                    continue
                if isinstance(src, ImmedLoc):
                    num_moves += 1
                    self.mc.MOV(X86_64_SCRATCH_REG, src)
                    src = X86_64_SCRATCH_REG
                num_moves += 1
                self.mc.MOVD32(dst, src)
        # Finally remap the arguments in the main regs
        num_moves += remap_frame_layout(self.asm, src_locs, dst_locs, X86_64_SCRATCH_REG)
        self.num_moves = num_moves


    def emit_raw_call(self):
        assert self.callconv == FFI_DEFAULT_ABI
        self.mc.CALL(self.fnloc)

    def load_result(self):
        if self.restype == 'S':
            # singlefloat return: use MOVD to load the target register
            # from the lower 32 bits of XMM0
            self.mc.MOVD32(self.resloc, xmm0)
        else:
            CallBuilderX86.load_result(self)

    def save_result_value(self, save_edx):
        # Temporarily save the result value into [ESP].
        if self.ressize == 0:      # void return
            return
        #
        if self.restype == FLOAT:    # and not 'S'
            self.mc.MOVSD_sx(0, xmm0.value)
            return
        #
        if self.restype == 'S':
            # singlefloat return: use MOVD to store the lower 32 bits
            # of XMM0 into [ESP]
            self.mc.MOVD32_sx(0, xmm0.value)
        else:
            assert self.restype == INT
            self.mc.MOV_sr(0, eax.value)

    def restore_result_value(self, save_edx):
        # Opposite of save_result_value()
        if self.ressize == 0:      # void return
            return
        #
        if self.restype == FLOAT:    # and not 'S'
            self.mc.MOVSD_xs(xmm0.value, 0)
            return
        #
        if self.restype == 'S':
            self.mc.MOVD32_xs(xmm0.value, 0)
        else:
            assert self.restype == INT
            self.mc.MOV_rs(eax.value, 0)


if IS_X86_32:
    CallBuilder = CallBuilder32
if IS_X86_64:
    CallBuilder = CallBuilder64
