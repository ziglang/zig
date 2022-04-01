from rpython.rlib.clibffi import FFI_DEFAULT_ABI
from rpython.rlib.objectmodel import we_are_translated
from rpython.jit.metainterp.history import INT, FLOAT, REF
from rpython.jit.backend.arm.arch import WORD
from rpython.jit.backend.arm import registers as r
from rpython.jit.backend.arm import conditions as c
from rpython.jit.backend.arm.locations import RawSPStackLocation
from rpython.jit.backend.arm.jump import remap_frame_layout
from rpython.jit.backend.llsupport.callbuilder import AbstractCallBuilder
from rpython.jit.backend.arm.helper.assembler import count_reg_args
from rpython.jit.backend.arm.helper.assembler import saved_registers
from rpython.jit.backend.arm.helper.regalloc import check_imm_arg
from rpython.jit.backend.arm.codebuilder import OverwritingBuilder
from rpython.jit.backend.llsupport import llerrno
from rpython.rtyper.lltypesystem import rffi


class ARMCallbuilder(AbstractCallBuilder):
    def __init__(self, assembler, fnloc, arglocs,
                 resloc=r.r0, restype=INT, ressize=WORD, ressigned=True):
        AbstractCallBuilder.__init__(self, assembler, fnloc, arglocs,
                                     resloc, restype, ressize)
        self.current_sp = 0

    def push_gcmap(self):
        assert not self.is_call_release_gil
        # we push *now* the gcmap, describing the status of GC registers
        # after the rearrangements done just above, ignoring the return
        # value eax, if necessary
        noregs = self.asm.cpu.gc_ll_descr.is_shadow_stack()
        gcmap = self.asm._regalloc.get_gcmap([r.r0], noregs=noregs)
        self.asm.push_gcmap(self.mc, gcmap, store=True)

    def pop_gcmap(self):
        self.asm._reload_frame_if_necessary(self.mc)
        self.asm.pop_gcmap(self.mc)

    def emit_raw_call(self):
        #the actual call
        if self.fnloc.is_imm():
            self.mc.BL(self.fnloc.value)
            return
        # --self.fnloc.is_stack() is always remapped to r4 here
        assert self.fnloc.is_core_reg()
        self.mc.BLX(self.fnloc.value)

    def restore_stack_pointer(self):
        # readjust the sp in case we passed some args on the stack
        assert self.current_sp % 8 == 0  # sanity check
        if self.current_sp != 0:
            self._adjust_sp(self.current_sp)
        self.current_sp = 0

    def _push_stack_args(self, stack_args, on_stack):
        assert on_stack % 8 == 0
        if on_stack == 0:
            return
        self._adjust_sp(-on_stack)
        self.current_sp = on_stack
        ofs = 0
        for i, arg in enumerate(stack_args):
            if arg is not None:
                sp_loc = RawSPStackLocation(ofs, arg.type)
                self.asm.regalloc_mov(arg, sp_loc)
                ofs += sp_loc.width
            else:  # alignment word
                ofs += WORD

    def _adjust_sp(self, n):
        # adjust the current stack pointer by n bytes
        if n > 0:
            if check_imm_arg(n):
                self.mc.ADD_ri(r.sp.value, r.sp.value, n)
            else:
                self.mc.gen_load_int(r.ip.value, n)
                self.mc.ADD_rr(r.sp.value, r.sp.value, r.ip.value)
        elif n < 0:
            n = abs(n)
            if check_imm_arg(n):
                self.mc.SUB_ri(r.sp.value, r.sp.value, n)
            else:
                self.mc.gen_load_int(r.ip.value, n)
                self.mc.SUB_rr(r.sp.value, r.sp.value, r.ip.value)

    def call_releasegil_addr_and_move_real_arguments(self, fastgil):
        assert self.is_call_release_gil
        assert not self.asm._is_asmgcc()

        # Save this thread's shadowstack pointer into r7, for later comparison
        gcrootmap = self.asm.cpu.gc_ll_descr.gcrootmap
        if gcrootmap:
            rst = gcrootmap.get_root_stack_top_addr()
            self.mc.gen_load_int(r.r5.value, rst)
            self.mc.LDR_ri(r.r7.value, r.r5.value)

        # change 'rpy_fastgil' to 0 (it should be non-zero right now)
        if self.asm.cpu.cpuinfo.arch_version >= 7:
            self.mc.DMB()
        self.mc.gen_load_int(r.r6.value, fastgil)
        self.mc.LDR_ri(r.r8.value, r.r6.value)   # => our thread ident
        self.mc.MOV_ri(r.ip.value, 0)
        self.mc.STR_ri(r.ip.value, r.r6.value)

        if not we_are_translated():                     # for testing: we should not access
            self.mc.ADD_ri(r.fp.value, r.fp.value, 1)   # fp any more

    def move_real_result_and_call_reacqgil_addr(self, fastgil):
        # try to reacquire the lock.  The registers r5 to r7 are still
        # valid from before the call:
        #     r5 == &root_stack_top
        #     r6 == fastgil
        #     r7 == previous value of root_stack_top
        #     r8 == our thread ident
        self.mc.LDREX(r.r3.value, r.r6.value)    # load the lock value
        self.mc.CMP_ri(r.r3.value, 0)            # is the lock free?
        self.mc.STREX(r.r3.value, r.r8.value, r.r6.value, c=c.EQ)
                                                 # try to claim the lock
        self.mc.CMP_ri(r.r3.value, 0, cond=c.EQ) # did this succeed?
        if self.asm.cpu.cpuinfo.arch_version >= 7:
            self.mc.DMB()
        # the success of the lock acquisition is defined by
        # 'EQ is true', or equivalently by 'r3 == 0'.
        #
        if self.asm.cpu.gc_ll_descr.gcrootmap:
            # When doing a call_release_gil with shadowstack, there
            # is the risk that the 'rpy_fastgil' was free but the
            # current shadowstack can be the one of a different
            # thread.  So here we check if the shadowstack pointer
            # is still the same as before we released the GIL (saved
            # in 'r7'), and if not, we fall back to 'reacqgil_addr'.
            self.mc.LDR_ri(r.ip.value, r.r5.value, cond=c.EQ)
            self.mc.CMP_rr(r.ip.value, r.r7.value, cond=c.EQ)
            b1_location = self.mc.currpos()
            self.mc.BKPT()                       # BEQ below
            # there are two cases here: either EQ was false from
            # the beginning, or EQ was true at first but the CMP
            # made it false.  In the second case we need to
            # release the fastgil here.  We know which case it is
            # by checking again r3.
            self.mc.CMP_ri(r.r3.value, 0)
            self.mc.STR_ri(r.r3.value, r.r6.value, cond=c.EQ)
        else:
            b1_location = self.mc.currpos()
            self.mc.BKPT()                       # BEQ below
        #
        # save the result we just got
        gpr_to_save, vfp_to_save = self.get_result_locs()
        with saved_registers(self.mc, gpr_to_save, vfp_to_save):
            self.mc.BL(self.asm.reacqgil_addr)

        # replace b1_location with B(here, c.EQ)
        pmc = OverwritingBuilder(self.mc, b1_location, WORD)
        pmc.B_offs(self.mc.currpos(), c.EQ)

        if not we_are_translated():                    # for testing: now we can accesss
            self.mc.SUB_ri(r.fp.value, r.fp.value, 1)  # fp again

    def get_result_locs(self):
        raise NotImplementedError

    def _ensure_result_bit_extension(self, resloc, size, signed):
        if size == 4:
            return
        if size == 1:
            if not signed:  # unsigned char
                self.mc.AND_ri(resloc.value, resloc.value, 0xFF)
            else:
                self.mc.LSL_ri(resloc.value, resloc.value, 24)
                self.mc.ASR_ri(resloc.value, resloc.value, 24)
        elif size == 2:
            if not signed:
                self.mc.LSL_ri(resloc.value, resloc.value, 16)
                self.mc.LSR_ri(resloc.value, resloc.value, 16)
            else:
                self.mc.LSL_ri(resloc.value, resloc.value, 16)
                self.mc.ASR_ri(resloc.value, resloc.value, 16)

    def write_real_errno(self, save_err):
        if save_err & rffi.RFFI_READSAVED_ERRNO:
            # Just before a call, read '*_errno' and write it into the
            # real 'errno'.  The r0-r3 registers contain arguments to the
            # future call; the r5-r8 registers contain various stuff.
            # We still have r9-r12.
            if save_err & rffi.RFFI_ALT_ERRNO:
                rpy_errno = llerrno.get_alt_errno_offset(self.asm.cpu)
            else:
                rpy_errno = llerrno.get_rpy_errno_offset(self.asm.cpu)
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            self.mc.LDR_ri(r.r9.value, r.sp.value,
                           self.asm.saved_threadlocal_addr + self.current_sp)
            self.mc.LDR_ri(r.ip.value, r.r9.value, p_errno)
            self.mc.LDR_ri(r.r9.value, r.r9.value, rpy_errno)
            self.mc.STR_ri(r.r9.value, r.ip.value)
        elif save_err & rffi.RFFI_ZERO_ERRNO_BEFORE:
            # Same, but write zero.
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            self.mc.LDR_ri(r.r9.value, r.sp.value,
                           self.asm.saved_threadlocal_addr + self.current_sp)
            self.mc.LDR_ri(r.ip.value, r.r9.value, p_errno)
            self.mc.MOV_ri(r.r9.value, 0)
            self.mc.STR_ri(r.r9.value, r.ip.value)

    def read_real_errno(self, save_err):
        if save_err & rffi.RFFI_SAVE_ERRNO:
            # Just after a call, read the real 'errno' and save a copy of
            # it inside our thread-local '*_errno'.  Registers r9-r12
            # are unused here, and registers r2-r3 never contain anything
            # after the call.
            if save_err & rffi.RFFI_ALT_ERRNO:
                rpy_errno = llerrno.get_alt_errno_offset(self.asm.cpu)
            else:
                rpy_errno = llerrno.get_rpy_errno_offset(self.asm.cpu)
            p_errno = llerrno.get_p_errno_offset(self.asm.cpu)
            self.mc.LDR_ri(r.r3.value, r.sp.value,
                           self.asm.saved_threadlocal_addr)
            self.mc.LDR_ri(r.ip.value, r.r3.value, p_errno)
            self.mc.LDR_ri(r.ip.value, r.ip.value, 0)
            self.mc.STR_ri(r.ip.value, r.r3.value, rpy_errno)


class SoftFloatCallBuilder(ARMCallbuilder):
    # XXX Maybe we could kill this class and unify the remaining two
    # XXX classes, by carefully checking if all methods here are doing
    # XXX the exact same thing as the methods from HardFloatCallBuilder,
    # XXX but simply forcing all BoxFloat arguments to be longlongs
    # XXX (i.e. ignoring 'f' in favour of 'L'), and the same with
    # XXX single-float arguments (ignoring 'S' in favour of 'i');
    # XXX and the same for the return value.

    def get_result_locs(self):
        if self.resloc is None:
            return [], []
        if self.resloc.is_vfp_reg():
            return [r.r0, r.r1], []
        assert self.resloc.is_core_reg()
        return [r.r0], []

    def load_result(self):
        # ensure the result is wellformed and stored in the correct location
        resloc = self.resloc
        if resloc is None:
            return
        if resloc.is_vfp_reg():
            # move result to the allocated register
            self.asm.mov_to_vfp_loc(r.r0, r.r1, resloc)
        elif resloc.is_core_reg():
            # move result to the allocated register
            if resloc is not r.r0:
                self.asm.mov_loc_loc(r.r0, resloc)
            self._ensure_result_bit_extension(resloc,
                                              self.ressize, self.ressign)


    def _collect_and_push_stack_args(self, arglocs):
        n_args = len(arglocs)
        reg_args = count_reg_args(arglocs)
        # all arguments past the 4th go on the stack
        # first we need to prepare the list so it stays aligned
        stack_args = []
        count = 0
        on_stack = 0
        if n_args > reg_args:
            for i in range(reg_args, n_args):
                arg = arglocs[i]
                if arg.type != FLOAT:
                    count += 1
                    on_stack += 1
                else:
                    on_stack += 2
                    if count % 2 != 0:
                        stack_args.append(None)
                        count = 0
                        on_stack += 1
                stack_args.append(arg)
            if count % 2 != 0:
                on_stack += 1
                stack_args.append(None)
        if on_stack > 0:
            self._push_stack_args(stack_args, on_stack*WORD)

    def prepare_arguments(self):
        arglocs = self.arglocs
        reg_args = count_reg_args(arglocs)
        self._collect_and_push_stack_args(arglocs)
        # collect variables that need to go in registers and the registers they
        # will be stored in
        num = 0
        count = 0
        non_float_locs = []
        non_float_regs = []
        float_locs = []
        for i in range(reg_args):
            arg = arglocs[i]
            if arg.type == FLOAT and count % 2 != 0:
                    num += 1
                    count = 0
            reg = r.caller_resp[num]

            if arg.type == FLOAT:
                float_locs.append((arg, reg))
            else:
                non_float_locs.append(arg)
                non_float_regs.append(reg)

            if arg.type == FLOAT:
                num += 2
            else:
                num += 1
                count += 1
        # Check that the address of the function we want to call is not
        # currently stored in one of the registers used to pass the arguments
        # or on the stack, which we can not access later
        # If this happens to be the case we remap the register to r4 and use r4
        # to call the function
        if not self.fnloc.is_imm():
            non_float_locs.append(self.fnloc)
            non_float_regs.append(r.r4)
            self.fnloc = r.r4
        # remap values stored in core registers
        remap_frame_layout(self.asm, non_float_locs, non_float_regs, r.ip)

        for loc, reg in float_locs:
            self.asm.mov_from_vfp_loc(loc, reg, r.all_regs[reg.value + 1])

class HardFloatCallBuilder(ARMCallbuilder):

    next_arg_vfp = 0
    next_arg_svfp = 0

    def get_next_vfp(self, tp):
        assert tp in 'fS'
        if tp == 'f':
            # 64bit double
            i = max(self.next_arg_vfp, (self.next_arg_svfp + 1) >> 1)
            if i >= len(r.vfp_argument_regs):
                self.next_arg_svfp = 1000    # stop that sequence too
                return None
            self.next_arg_vfp = i + 1
            return r.vfp_argument_regs[i]
        else:
            # 32bit float
            i = self.next_arg_svfp
            if not (i & 1):     # if i is even
                i = max(i, self.next_arg_vfp << 1)
            if i >= len(r.svfp_argument_regs):
                return None
            self.next_arg_svfp = i + 1
            return r.svfp_argument_regs[i]

    def prepare_arguments(self):
        non_float_locs = []
        non_float_regs = []
        float_locs = []
        float_regs = []
        stack_args = []
        singlefloats = None
        longlong_mask = 0

        arglocs = self.arglocs
        argtypes = self.argtypes

        r_register_count = 0
        on_stack = 0

        for i in range(len(arglocs)):
            argtype = INT
            if i < len(argtypes) and argtypes[i] == 'S':
                argtype = argtypes[i]
            arg = arglocs[i]

            if arg.is_float():
                if i < len(argtypes) and argtypes[i] == 'L':
                    # A longlong argument.  It uses two regular argument
                    # positions, but aligned to an even number.  This is
                    # a bit strange, but it is the case even for registers:
                    # it can be in r0-r1 or in r2-r3 but not in r1-r2.
                    assert arg.is_float()
                    if r_register_count == 0:
                        # will temporarily load the register into d8
                        float_locs.append(arg)
                        float_regs.append(r.d8)
                        longlong_mask |= 1
                        r_register_count = 2
                        continue
                    elif r_register_count <= 2:
                        # will temporarily load the register into d9
                        float_locs.append(arg)
                        float_regs.append(r.d9)
                        longlong_mask |= 2
                        r_register_count = 4
                        continue
                    elif r_register_count == 3:
                        r_register_count = 4
                else:
                    # A 64-bit float argument.  Goes into the next free v#
                    # register, or if none, to the stack aligned to an
                    # even number of words.
                    argtype = FLOAT
                    reg = self.get_next_vfp(argtype)
                    if reg:
                        float_locs.append(arg)
                        assert reg not in float_regs
                        float_regs.append(reg)
                        continue
                # float or longlong argument that needs to go on the stack
                if on_stack & 1:   # odd: realign
                    stack_args.append(None)
                    on_stack += 1
                stack_args.append(arg)
                on_stack += 2

            elif argtype == 'S':
                # Singlefloat (32-bit) argument.  Goes into the next free
                # v# register, or if none, to the stack in a single word.
                if singlefloats is None:
                    singlefloats = []
                tgt = self.get_next_vfp(argtype)
                if tgt:
                    singlefloats.append((arg, tgt))
                else:  # Singlefloat argument that needs to go on the stack
                       # treated the same as a regular core register argument
                    stack_args.append(arg)
                    on_stack += 1
            else:
                # Regular one-word argument.  Goes into the next register
                # free from the list r0, r1, r2, r3, or to the stack.
                if r_register_count < len(r.argument_regs):
                    reg = r.argument_regs[r_register_count]
                    r_register_count += 1
                    non_float_locs.append(arg)
                    non_float_regs.append(reg)
                else:  # non-float argument that needs to go on the stack
                    stack_args.append(arg)
                    on_stack += 1

        # align the stack
        if on_stack & 1:    # odd: realign
            stack_args.append(None)
            on_stack += 1
        self._push_stack_args(stack_args, on_stack*WORD)

        # Check that the address of the function we want to call is not
        # currently stored in one of the registers used to pass the arguments
        # or on the stack, which we can not access later
        # If this happens to be the case we remap the register to r4 and use r4
        # to call the function
        if not self.fnloc.is_imm():
            non_float_locs.append(self.fnloc)
            non_float_regs.append(r.r4)
            self.fnloc = r.r4

        # remap values stored in vfp registers
        remap_frame_layout(self.asm, float_locs, float_regs, r.vfp_ip)
        if singlefloats:
            for src, dest in singlefloats:
                if src.is_float():
                    assert 0, 'unsupported case'
                if src.is_stack():
                    # use special VLDR for 32bit
                    self.asm.regalloc_mov(src, r.ip)
                    src = r.ip
                if src.is_imm():
                    self.mc.gen_load_int(r.ip.value, src.value)
                    src = r.ip
                if src.is_core_reg():
                    self.mc.VMOV_cs(dest.value, src.value)

        # remap values stored in core registers
        remap_frame_layout(self.asm, non_float_locs, non_float_regs, r.ip)
        if longlong_mask & 1:
            self.mc.FMRRD(r.r0.value, r.r1.value, r.d8.value)
        if longlong_mask & 2:
            self.mc.FMRRD(r.r2.value, r.r3.value, r.d9.value)


    def load_result(self):
        resloc = self.resloc
        if self.restype == 'S':
            self.mc.VMOV_sc(resloc.value, r.s0.value)
        elif self.restype == 'L':
            assert resloc.is_vfp_reg()
            self.mc.FMDRR(resloc.value, r.r0.value, r.r1.value)
        # ensure the result is wellformed and stored in the correct location
        if resloc is not None and resloc.is_core_reg():
            self._ensure_result_bit_extension(resloc,
                                                  self.ressize, self.ressign)

    def get_result_locs(self):
        if self.resloc is None:
            return [], []
        if self.resloc.is_vfp_reg():
            if self.restype == 'L':      # long long
                return [r.r0, r.r1], []
            else:
                return [], [r.d0]
        assert self.resloc.is_core_reg()
        return [r.r0], []


def get_callbuilder(cpu, assembler, fnloc, arglocs,
                 resloc=r.r0, restype=INT, ressize=WORD, ressigned=True):
    if cpu.cpuinfo.hf_abi:
        return HardFloatCallBuilder(assembler, fnloc, arglocs, resloc,
                                        restype, ressize, ressigned)
    else:
        return SoftFloatCallBuilder(assembler, fnloc, arglocs, resloc,
                                        restype, ressize, ressigned)
