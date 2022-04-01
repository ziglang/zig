from rpython.jit.backend.zarch.arch import WORD
from rpython.jit.backend.zarch.arch import (THREADLOCAL_ADDR_OFFSET,
        STD_FRAME_SIZE_IN_BYTES)
import rpython.jit.backend.zarch.locations as l
import rpython.jit.backend.zarch.registers as r
import rpython.jit.backend.zarch.conditions as c
from rpython.jit.metainterp.history import INT, FLOAT
from rpython.jit.backend.llsupport.callbuilder import AbstractCallBuilder
from rpython.jit.backend.llsupport.jump import remap_frame_layout
from rpython.rlib.objectmodel import we_are_translated, not_rpython
from rpython.jit.backend.llsupport import llerrno
from rpython.rtyper.lltypesystem import rffi
from rpython.jit.backend.llsupport.descr import CallDescr
from rpython.jit.backend.llsupport import llerrno, lltls

CALL_RELEASE_GIL_STACK_OFF = 6*WORD

class CallBuilder(AbstractCallBuilder):
    GPR_ARGS = [r.r2, r.r3, r.r4, r.r5, r.r6]
    FPR_ARGS =  [r.f0, r.f2, r.f4, r.f6]
    
    RSHADOWOLD  = r.r8
    RSHADOWPTR  = r.r9
    RFASTGILPTR = r.r10
    RTHREADID = r.r11

    def __init__(self, assembler, fnloc, arglocs, resloc, calldescr):
        type = INT
        size = WORD
        self.ressign = True
        if calldescr is not None and isinstance(calldescr, CallDescr):
            type = calldescr.get_result_type()
            size = calldescr.get_result_size()
            self.ressign = calldescr.is_result_signed()

        AbstractCallBuilder.__init__(self, assembler, fnloc, arglocs,
                                     resloc, restype=type, ressize=size)

    def prepare_arguments(self):
        self.subtracted_to_sp = 0

        # Prepare arguments.  Note that this follows the convention where
        # a prototype is in scope, and doesn't take "..." arguments.  If
        # you were to call a C function with a "..." argument with cffi,
        # it would not go there but instead via libffi.  If you pretend
        # instead that it takes fixed arguments, then it would arrive here
        # but the convention is bogus for floating-point arguments.  (And,
        # to add to the mess, at least CPython's ctypes cannot be used
        # to call a "..." function with floating-point arguments.  As I
        # guess that it's a problem with libffi, it means PyPy inherits
        # the same problem.)
        arglocs = self.arglocs
        num_args = len(arglocs)

        max_gpr_in_reg = 5
        max_fpr_in_reg = 4

        non_float_locs = []
        non_float_regs = []
        float_locs = []

        # the IBM zarch manual states:
        # """
        # A function will be passed a frame on the runtime stack by the function which
        # called it, and may allocate a new stack frame. A new stack frame is required if the
        # called function will in turn call further functions (which must be passed the
        # address of the new frame). This stack grows downwards from high addresses
        # """

        gpr_regs = 0
        fpr_regs = 0
        stack_params = []
        for i in range(num_args):
            loc = arglocs[i]
            if not arglocs[i].is_float():
                if gpr_regs < max_gpr_in_reg:
                    non_float_locs.append(arglocs[i])
                    non_float_regs.append(self.GPR_ARGS[gpr_regs])
                    gpr_regs += 1
                else:
                    stack_params.append(i)
            else:
                if fpr_regs < max_fpr_in_reg:
                    float_locs.append(arglocs[i])
                    fpr_regs += 1
                else:
                    stack_params.append(i)

        self.subtracted_to_sp += len(stack_params) * WORD
        base = len(stack_params) * WORD
        if self.is_call_release_gil:
            self.subtracted_to_sp += CALL_RELEASE_GIL_STACK_OFF
            base += CALL_RELEASE_GIL_STACK_OFF
        for idx,i in enumerate(stack_params):
            loc = arglocs[i]
            offset = STD_FRAME_SIZE_IN_BYTES - base + 8 * idx
            if loc.type == FLOAT:
                if loc.is_fp_reg():
                    src = loc
                else:
                    src = r.FP_SCRATCH
                    self.asm.regalloc_mov(loc, src)
                self.mc.STDY(src, l.addr(offset, r.SP))
            else:
                if loc.is_core_reg():
                    src = loc
                else:
                    src = r.SCRATCH
                    self.asm.regalloc_mov(loc, src)
                self.mc.STG(src, l.addr(offset, r.SP))


        # We must also copy fnloc into FNREG
        non_float_locs.append(self.fnloc)
        non_float_regs.append(r.RETURN)

        if float_locs:
            assert len(float_locs) <= len(self.FPR_ARGS)
            remap_frame_layout(self.asm, float_locs,
                               self.FPR_ARGS[:len(float_locs)],
                               r.FP_SCRATCH)

        remap_frame_layout(self.asm, non_float_locs, non_float_regs,
                           r.SCRATCH)


    def push_gcmap(self):
        # we push *now* the gcmap, describing the status of GC registers
        # after the rearrangements done just before, ignoring the return
        # value r2, if necessary
        assert not self.is_call_release_gil
        noregs = self.asm.cpu.gc_ll_descr.is_shadow_stack()
        gcmap = self.asm._regalloc.get_gcmap([r.r2], noregs=noregs)
        self.asm.push_gcmap(self.mc, gcmap, store=True)

    def pop_gcmap(self):
        ssreg = None
        gcrootmap = self.asm.cpu.gc_ll_descr.gcrootmap
        if gcrootmap:
            if gcrootmap.is_shadow_stack and self.is_call_release_gil:
                # in this mode, RSHADOWOLD happens to contain the shadowstack
                # top at this point, so reuse it instead of loading it again
                # RSHADOWOLD is moved to the scratch reg just before restoring r8
                ssreg = r.SCRATCH
        self.asm._reload_frame_if_necessary(self.mc, shadowstack_reg=ssreg)

    def emit_raw_call(self):
        # always allocate a stack frame for the new function
        # save the SP back chain
        # move the frame pointer
        if self.subtracted_to_sp != 0:
            # rewrite the back chain
            self.mc.LG(r.SCRATCH, l.addr(0, r.SP))
            self.mc.STG(r.SCRATCH, l.addr(-self.subtracted_to_sp, r.SP))
            self.mc.LAY(r.SP, l.addr(-self.subtracted_to_sp, r.SP))
        self.mc.raw_call()


    def restore_stack_pointer(self):
        if self.subtracted_to_sp != 0:
            self.mc.LAY(r.SP, l.addr(self.subtracted_to_sp, r.SP))

    def load_result(self):
        assert (self.resloc is None or
                self.resloc is r.GPR_RETURN or
                self.resloc is r.FPR_RETURN)
        #
        if self.restype == 'i' and self.ressize != WORD:
            # we must be sure! libffi (s390x impl) will not return
            # a sane 64 bit zero/sign extended value. fix for this
            # has been rejected (Jan. 2016). This will not be updated
            # any time soon...
            if self.ressign:
                # sign extend!
                if self.ressize == 1: self.mc.LGBR(r.r2, r.r2)
                elif self.ressize == 2: self.mc.LGHR(r.r2, r.r2)
                elif self.ressize == 4: self.mc.LGFR(r.r2, r.r2)
                else:
                    assert 0, "cannot sign extend size %d" % self.ressize
            else:
                # zero extend!
                if self.ressize == 1: self.mc.LLGCR(r.r2, r.r2)
                elif self.ressize == 2: self.mc.LLGHR(r.r2, r.r2)
                elif self.ressize == 4: self.mc.LLGFR(r.r2, r.r2)
                else:
                    assert 0, "cannot zero extend size %d" % self.ressize

    def call_releasegil_addr_and_move_real_arguments(self, fastgil):
        assert self.is_call_release_gil
        RSHADOWOLD = self.RSHADOWOLD
        RSHADOWPTR = self.RSHADOWPTR
        RFASTGILPTR = self.RFASTGILPTR
        RTHREADID = self.RTHREADID
        #
        pos = STD_FRAME_SIZE_IN_BYTES - CALL_RELEASE_GIL_STACK_OFF
        self.mc.STMG(r.r8, r.r13, l.addr(pos, r.SP))
        #
        # Save this thread's shadowstack pointer into r8, for later comparison
        gcrootmap = self.asm.cpu.gc_ll_descr.gcrootmap
        if gcrootmap:
            if gcrootmap.is_shadow_stack:
                rst = gcrootmap.get_root_stack_top_addr()
                self.mc.load_imm(RSHADOWPTR, rst)
                self.mc.load(RSHADOWOLD, RSHADOWPTR, 0)
        #
        # change 'rpy_fastgil' to 0 (it should be non-zero right now)
        self.mc.load_imm(RFASTGILPTR, fastgil)
        self.mc.LG(RTHREADID, l.addr(0, RFASTGILPTR))
        self.mc.XGR(r.SCRATCH, r.SCRATCH)
        # zarch is sequentially consistent
        self.mc.STG(r.SCRATCH, l.addr(0, RFASTGILPTR))


    def move_real_result_and_call_reacqgil_addr(self, fastgil):
        from rpython.jit.backend.zarch.codebuilder import OverwritingBuilder

        # try to reacquire the lock.  The following registers are still
        # valid from before the call:
        RSHADOWOLD  = self.RSHADOWOLD     # r8: previous val of root_stack_top
        RSHADOWPTR  = self.RSHADOWPTR     # r9: &root_stack_top
        RFASTGILPTR = self.RFASTGILPTR    # r10: &fastgil
        RTHREADID = self.RTHREADID        # r11: holding my thread id

        # Equivalent of 'r13 = __sync_val_compre_and_swap(&rpy_fastgil, 0, thread_id);'
        retry_label = self.mc.currpos()
        self.mc.LG(r.r13, l.addr(0, RFASTGILPTR))
        # compare if &rpy_fastgil == 0
        self.mc.CGFI(r.r13, l.imm0)
        branch_forward = self.mc.currpos()
        self.mc.BRC(c.NE, l.imm(0)) # overwrite later
        # if so try to compare and swap.
        # r13 == &r10, then store the contets of r.SCRATCH to &r10
        self.mc.CSG(r.r13, RTHREADID, l.addr(0, RFASTGILPTR))  # try to claim lock
        self.mc.BRC(c.NE, l.imm(retry_label - self.mc.currpos())) # retry if failed
        # CSG performs a serialization
        # zarch is sequential consistent!

        # overwrite the branch
        pmc = OverwritingBuilder(self.mc, branch_forward, 1)
        pmc.BRC(c.NE, l.imm(self.mc.currpos() - branch_forward))

        self.mc.CGHI(r.r13, l.imm0)
        b1_location = self.mc.currpos()
        # save some space, this is patched later
        self.mc.reserve_cond_jump()

        gcrootmap = self.asm.cpu.gc_ll_descr.gcrootmap
        if gcrootmap:
            # When doing a call_release_gil with shadowstack, there
            # is the risk that the 'rpy_fastgil' was free but the
            # current shadowstack can be the one of a different
            # thread.  So here we check if the shadowstack pointer
            # is still the same as before we released the GIL (saved
            # in RSHADOWOLD), and if not, we fall back to 'reacqgil_addr'.
            self.mc.load(r.SCRATCH, RSHADOWPTR, 0)
            self.mc.CGR(r.SCRATCH, RSHADOWOLD)
            bne_location = b1_location
            b1_location = self.mc.currpos()
            self.mc.reserve_cond_jump()

            # revert the rpy_fastgil acquired above, so that the
            # general 'reacqgil_addr' below can acquire it again...
            self.mc.XGR(r.r13, r.r13)
            self.mc.STG(r.r13, l.addr(0, RFASTGILPTR))

            pmc = OverwritingBuilder(self.mc, bne_location, 1)
            pmc.BRCL(c.NE, l.imm(self.mc.currpos() - bne_location))
            pmc.overwrite()
        #
        # Yes, we need to call the reacqgil() function.
        # save the result we just got
        RSAVEDRES = RFASTGILPTR     # can reuse this reg here
        reg = self.resloc
        if reg is not None:
            # save 1 word below the stack pointer
            if reg.is_core_reg():
                self.mc.LGR(RSAVEDRES, reg)
            elif reg.is_fp_reg():
                self.mc.STD(reg, l.addr(16*WORD, r.SP))
        # r8-r13 live on the stack and must NOT be overwritten,
        # restore_stack_pointer already moved SP + subtracted_to_sp,
        self.mc.LAY(r.SP, l.addr(-self.subtracted_to_sp, r.SP))
        self.mc.load_imm(self.mc.RAW_CALL_REG, self.asm.reacqgil_addr)
        self.mc.raw_call()
        self.mc.LAY(r.SP, l.addr(self.subtracted_to_sp, r.SP))

        if reg is not None:
            if reg.is_core_reg():
                self.mc.LGR(reg, RSAVEDRES)
            elif reg.is_fp_reg():
                self.mc.LD(reg, l.addr(16*WORD, r.SP))

        # replace b1_location with BEQ(here)
        pmc = OverwritingBuilder(self.mc, b1_location, 1)
        pmc.BRCL(c.EQ, l.imm(self.mc.currpos() - b1_location))
        pmc.overwrite()

        if gcrootmap:
            if gcrootmap.is_shadow_stack and self.is_call_release_gil:
                self.mc.LGR(r.SCRATCH, RSHADOWOLD)
        pos = STD_FRAME_SIZE_IN_BYTES - CALL_RELEASE_GIL_STACK_OFF
        self.mc.LMG(r.r8, r.r13, l.addr(pos, r.SP))

    def write_real_errno(self, save_err):
        # r11 is saved in call_releasegil_addr_and_move_real_arguments,
        # thus can be used freely here!
        if save_err & rffi.RFFI_READSAVED_ERRNO:
            # Just before a call, read '*_errno' and write it into the
            # real 'errno'.
            if save_err & rffi.RFFI_ALT_ERRNO:
                rpy_errno = llerrno.get_alt_errno_offset(self.asm.cpu)
            else:
                rpy_errno = llerrno.get_rpy_errno_offset(self.asm.cpu)
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            self.mc.LG(r.r11, l.addr(THREADLOCAL_ADDR_OFFSET, r.SP))
            self.mc.LGF(r.SCRATCH2, l.addr(rpy_errno, r.r11))
            self.mc.LG(r.r11, l.addr(p_errno, r.r11))
            self.mc.STY(r.SCRATCH2, l.addr(0,r.r11))
        elif save_err & rffi.RFFI_ZERO_ERRNO_BEFORE:
            # Same, but write zero.
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            self.mc.LG(r.r11, l.addr(THREADLOCAL_ADDR_OFFSET, r.SP))
            self.mc.LG(r.r11, l.addr(p_errno, r.r11))
            self.mc.LGHI(r.SCRATCH, l.imm(0))
            self.mc.STY(r.SCRATCH, l.addr(0,r.r11))

    def read_real_errno(self, save_err):
        if save_err & rffi.RFFI_SAVE_ERRNO:
            # Just after a call, read the real 'errno' and save a copy of
            # it inside our thread-local '*_errno'.  Registers r3-r6
            # never contain anything after the call.
            if save_err & rffi.RFFI_ALT_ERRNO:
                rpy_errno = llerrno.get_alt_errno_offset(self.asm.cpu)
            else:
                rpy_errno = llerrno.get_rpy_errno_offset(self.asm.cpu)
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            self.mc.LG(r.r3, l.addr(THREADLOCAL_ADDR_OFFSET, r.SP))
            self.mc.LG(r.r4, l.addr(p_errno, r.r3))
            self.mc.LGF(r.r4, l.addr(0, r.r4))
            self.mc.STY(r.r4, l.addr(rpy_errno, r.r3))
