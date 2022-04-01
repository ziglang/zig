from rpython.jit.backend.arm import conditions as cond
from rpython.jit.backend.arm import registers as reg
from rpython.jit.backend.arm.arch import WORD, PC_OFFSET
from rpython.jit.backend.arm.instruction_builder import define_instructions
from rpython.jit.backend.llsupport.asmmemmgr import BlockBuilderMixin
from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory
from rpython.tool.udir import udir
from rpython.jit.backend.detect_cpu import autodetect

clear_cache = rffi.llexternal(
    "__clear_cache",
    [llmemory.Address, llmemory.Address],
    lltype.Void,
    _nowrapper=True,
    sandboxsafe=True)


class AbstractARMBuilder(object):
    def __init__(self, arch_version=7):
        self.arch_version = arch_version

    def NOP(self):
        self.MOV_rr(0, 0)

    def PUSH(self, regs, cond=cond.AL):
        assert reg.sp.value not in regs
        instr = 0
        if len(regs) == 1:
            instr = cond << 28 | 0x52D0004 | (regs[0] & 0xF)  << 12
        else:
            instr = self._encode_reg_list(cond << 28 | 0x92D << 16, regs)
        self.write32(instr)

    def STM(self, base, regs, write_back=False, cond=cond.AL):
        assert len(regs) > 0
        instr = (cond << 28
                | 0x11 << 23
                | (1 if write_back else 0) << 21
                | (base & 0xF) << 16)
        instr = self._encode_reg_list(instr, regs)
        self.write32(instr)

    def LDM(self, base, regs, write_back=False, cond=cond.AL):
        assert len(regs) > 0
        instr = (cond << 28
                | 0x11 << 23
                | (1 if write_back else 0) << 21
                | 1 << 20
                | (base & 0xF) << 16)
        instr = self._encode_reg_list(instr, regs)
        self.write32(instr)

    def VSTM(self, base, regs, write_back=False, cond=cond.AL):
        # encoding T1
        P = 0
        U = 1
        nregs = len(regs)
        assert nregs > 0 and nregs <= 16
        freg = regs[0]
        D = (freg & 0x10) >> 4
        Dd = (freg & 0xF)
        nregs *= 2
        instr = (cond << 28
                | 3 << 26
                | P << 24
                | U << 23
                | D << 22
                | (1 if write_back else 0) << 21
                | (base & 0xF) << 16
                | Dd << 12
                | 0xB << 8
                | nregs)
        self.write32(instr)

    def VLDM(self, base, regs, write_back=False, cond=cond.AL):
        # encoding T1
        P = 0
        U = 1
        nregs = len(regs)
        assert nregs > 0 and nregs <= 16
        freg = regs[0]
        D = (freg & 0x10) >> 4
        Dd = (freg & 0xF)
        nregs *= 2
        instr = (cond << 28
                | 3 << 26
                | P << 24
                | U << 23
                | D << 22
                | (1 if write_back else 0) << 21
                | 1 << 20
                | (base & 0xF) << 16
                | Dd << 12
                | 0xB << 8
                | nregs)
        self.write32(instr)

    def VPUSH(self, regs, cond=cond.AL):
        nregs = len(regs)
        assert nregs > 0 and nregs <= 16
        freg = regs[0]
        D = (freg & 0x10) >> 4
        Dd = (freg & 0xF)
        nregs *= 2
        instr = (cond << 28
                | 0xD2D << 16
                | D << 22
                | Dd << 12
                | 0xB << 8
                | nregs)
        self.write32(instr)

    def VPOP(self, regs, cond=cond.AL):
        nregs = len(regs)
        assert nregs > 0 and nregs <= 16
        freg = regs[0]
        D = (freg & 0x10) >> 4
        Dd = (freg & 0xF)
        nregs *= 2
        instr = (cond << 28
                | 0xCBD << 16
                | D << 22
                | Dd << 12
                | 0xB << 8
                | nregs)
        self.write32(instr)

    def VMOV_rc(self, rt, rt2, dm, cond=cond.AL):
        """This instruction copies two words from two ARM core registers into a
        doubleword extension register, or from a doubleword extension register
        to two ARM core registers.
        """
        op = 1
        instr = (cond << 28
                | 0xC << 24
                | 0x4 << 20
                | op << 20
                | (rt2 & 0xF) << 16
                | (rt & 0xF) << 12
                | 0xB << 8
                | 0x1 << 4
                | (dm & 0xF))
        self.write32(instr)

    # VMOV<c> <Dm>, <Rt>, <Rt2>
    def VMOV_cr(self, dm, rt, rt2, cond=cond.AL):
        """This instruction copies two words from two ARM core registers into a
        doubleword extension register, or from a doubleword extension register
        to two ARM core registers.
        """
        op = 0
        instr = (cond << 28
                | 0xC << 24
                | 0x4 << 20
                | op << 20
                | (rt2 & 0xF) << 16
                | (rt & 0xF) << 12
                | 0xB << 8
                | 0x1 << 4
                | (dm & 0xF))
        self.write32(instr)

    def VMOV_sc(self, dest, src):
        """move a single precision vfp register[src] to a core reg[dest]"""
        self._VMOV_32bit(src, dest, to_arm_register=1)

    def VMOV_cs(self, dest, src):
        """move a core register[src] to a single precision vfp
        register[dest]"""
        self._VMOV_32bit(dest, src, to_arm_register=0)

    def _VMOV_32bit(self, float_reg, core_reg, to_arm_register, cond=cond.AL):
        """This instruction transfers the contents of a single-precision VFP
           register to an ARM core register, or the contents of an ARM core
           register to a single-precision VFP register.
        """
        instr = (cond << 28
                | 0xE << 24
                | to_arm_register << 20
                | ((float_reg >> 1) & 0xF) << 16
                | core_reg << 12
                | 0xA << 8
                | (float_reg & 0x1) << 7
                | 1 << 4)
        self.write32(instr)

    def VMOV_cc(self, dd, dm, cond=cond.AL):
        sz = 1  # for 64-bit mode
        instr = (cond << 28
                | 0xEB << 20
                | (dd & 0xF) << 12
                | 0x5 << 9
                | (sz & 0x1) << 8
                | 0x1 << 6
                | (dm & 0xF))
        self.write32(instr)

    def VCVT_float_to_int(self, target, source, cond=cond.AL):
        opc2 = 0x5
        sz = 1
        self._VCVT(target, source, cond, opc2, sz)

    def VCVT_int_to_float(self, target, source, cond=cond.AL):
        self._VCVT(target, source, cond, 0, 1)

    def _VCVT(self, target, source, cond, opc2, sz):
        # A8.6.295
        to_integer = (opc2 >> 2) & 1
        if to_integer:
            D = target & 1
            target >>= 1
            M = (source >> 4) & 1
        else:
            M = source & 1
            source >>= 1
            D = (target >> 4) & 1
        op = 1
        instr = (cond << 28
                | 0xEB8 << 16
                | D << 22
                | opc2 << 16
                | (target & 0xF) << 12
                | 0x5 << 9
                | sz << 8
                | op << 7
                | 1 << 6
                | M << 5
                | (source & 0xF))
        self.write32(instr)

    def _VCVT_single_double(self, target, source, cond, sz):
        # double_to_single = (sz == '1');
        D = target & 1 if sz else (target >> 4) & 1
        M = (source >> 4) & 1 if sz else source & 1
        instr = (cond << 28
                | 0xEB7 << 16
                | 0xAC << 4
                | D << 22
                | (target & 0xF) << 12
                | sz << 8
                | M << 5
                | (source & 0xF))
        self.write32(instr)

    def VCVT_f64_f32(self, target, source, cond=cond.AL):
        self._VCVT_single_double(target, source, cond, 1)

    def VCVT_f32_f64(self, target, source, cond=cond.AL):
        self._VCVT_single_double(target, source, cond, 0)

    def POP(self, regs, cond=cond.AL):
        instr = self._encode_reg_list(cond << 28 | 0x8BD << 16, regs)
        self.write32(instr)

    def BKPT(self):
        """Unconditional breakpoint"""
        self.write32(cond.AL << 28 | 0x1200070)

    # corresponds to the instruction vmrs APSR_nzcv, fpscr
    def VMRS(self, cond=cond.AL):
        self.write32(cond << 28 | 0xEF1FA10)

    def B(self, target, c=cond.AL):
        self.gen_load_int(reg.ip.value, target, cond=c)
        self.BX(reg.ip.value, c=c)

    def BX(self, reg, c=cond.AL):
        self.write32(c << 28 | 0x12FFF1 << 4 | (reg & 0xF))

    def B_offs(self, target_ofs, c=cond.AL):
        pos = self.currpos()
        target_ofs = target_ofs - (pos + PC_OFFSET)
        assert target_ofs & 0x3 == 0
        self.write32(c << 28 | 0xA << 24 | (target_ofs >> 2) & 0xFFFFFF)

    def BL(self, addr, c=cond.AL):
        target = rffi.cast(rffi.INT, addr)
        self.gen_load_int(reg.ip.value, target, cond=c)
        self.BLX(reg.ip.value, c)

    def BLX(self, reg, c=cond.AL):
        self.write32(c << 28 | 0x12FFF3 << 4 | (reg & 0xF))

    def MOVT_ri(self, rd, imm16, c=cond.AL):
        """Move Top writes an immediate value to the top halfword of the
        destination register. It does not affect the contents of the bottom
        halfword."""
        self.write32(c << 28
                    | 0x3 << 24
                    | (1 << 22)
                    | ((imm16 >> 12) & 0xF) << 16
                    | (rd & 0xF) << 12
                    | imm16 & 0xFFF)

    def MOVW_ri(self, rd, imm16, c=cond.AL):
        """Encoding A2 of MOV, that allow to load a 16 bit constant"""
        self.write32(c << 28
                    | 0x3 << 24
                    | ((imm16 >> 12) & 0xF) << 16
                    | (rd & 0xF) << 12
                    | imm16 & 0xFFF)

    def SXTB_rr(self, rd, rm, c=cond.AL):
        self.write32(c << 28
                    | 0x06AF0070
                    | (rd & 0xF) << 12
                    | (rm & 0xF))

    def SXTH_rr(self, rd, rm, c=cond.AL):
        self.write32(c << 28
                    | 0x06BF0070
                    | (rd & 0xF) << 12
                    | (rm & 0xF))

    def LDREX(self, rt, rn, c=cond.AL):
        self.write32(c << 28
                    | 0x01900f9f
                    | (rt & 0xF) << 12
                    | (rn & 0xF) << 16)

    def STREX(self, rd, rt, rn, c=cond.AL):
        """rd must not be the same register as rt or rn"""
        self.write32(c << 28
                    | 0x01800f90
                    | (rt & 0xF)
                    | (rd & 0xF) << 12
                    | (rn & 0xF) << 16)

    def DMB(self):
        # ARMv7 only.  I guess ARMv6 CPUs cannot be used in symmetric
        # multi-processing at all? That would make this instruction unneeded.
        # note: 'cond' is only permitted on Thumb here, but don't
        # write literally 0xf57ff05f, because it's larger than 31 bits
        c = cond.AL
        self.write32(c << 28
                    | 0x157ff05f)

    FMDRR = VMOV_cr     # uh, there are synonyms?
    FMRRD = VMOV_rc

    def _encode_reg_list(self, instr, regs):
        for reg in regs:
            instr |= 0x1 << reg
        return instr

    def _encode_imm(self, imm):
        u = 1
        if imm < 0:
            u = 0
            imm = -imm
        return u, imm

    def write32(self, word):
        self.writechar(chr(word & 0xFF))
        self.writechar(chr((word >> 8) & 0xFF))
        self.writechar(chr((word >> 16) & 0xFF))
        self.writechar(chr((word >> 24) & 0xFF))

    def writechar(self, char):
        raise NotImplementedError

    def currpos(self):
        raise NotImplementedError

    def gen_load_int(self, r, value, cond=cond.AL):
        if self.arch_version < 7:
            self.gen_load_int_v6(r, value, cond)
        else:
            self.gen_load_int_v7(r, value, cond)

    def gen_load_int_v7(self, r, value, cond=cond.AL):
        """r is the register number, value is the value to be loaded to the
        register"""
        bottom = value & 0xFFFF
        top = value >> 16
        self.MOVW_ri(r, bottom, cond)
        if top:
            self.MOVT_ri(r, top, cond)

    def gen_load_int_v6(self, r, value, cond=cond.AL):
        from rpython.jit.backend.arm.conditions import AL
        if cond != AL or 0 <= value <= 0xFFFF:
            self._load_by_shifting(r, value, cond)
        else:
            self.LDR_ri(r, reg.pc.value)
            self.MOV_rr(reg.pc.value, reg.pc.value)
            self.write32(value)

    def get_max_size_of_gen_load_int(self):
        return 4 if self.arch_version < 7 else 2

    ofs_shift = zip(range(8, 25, 8), range(12, 0, -4))

    def _load_by_shifting(self, r, value, c=cond.AL):
        # to be sure it is only called for the correct cases
        assert c != cond.AL or 0 <= value <= 0xFFFF
        self.MOV_ri(r, (value & 0xFF), cond=c)
        for offset, shift in self.ofs_shift:
            b = (value >> offset) & 0xFF
            if b == 0:
                continue
            t = b | (shift << 8)
            self.ORR_ri(r, r, imm=t, cond=c)


class OverwritingBuilder(AbstractARMBuilder):
    def __init__(self, cb, start, size):
        AbstractARMBuilder.__init__(self, cb.arch_version)
        self.cb = cb
        self.index = start
        self.end = start + size

    def currpos(self):
        return self.index

    def writechar(self, char):
        assert self.index <= self.end
        self.cb.overwrite(self.index, char)
        self.index += 1


class InstrBuilder(BlockBuilderMixin, AbstractARMBuilder):

    def __init__(self, arch_version=7):
        AbstractARMBuilder.__init__(self, arch_version)
        self.init_block_builder()
        #
        # ResOperation --> offset in the assembly.
        # ops_offset[None] represents the beginning of the code after the last op
        # (i.e., the tail of the loop)
        self.ops_offset = {}

    def mark_op(self, op):
        pos = self.get_relative_pos()
        self.ops_offset[op] = pos

    def _dump_trace(self, addr, name, formatter=-1):
        if not we_are_translated():
            if formatter != -1:
                name = name % formatter
            dir = udir.ensure('asm', dir=True)
            f = dir.join(name).open('wb')
            data = rffi.cast(rffi.CCHARP, addr)
            for i in range(self.currpos()):
                f.write(data[i])
            f.close()

    def clear_cache(self, addr):
        if we_are_translated():
            startaddr = rffi.cast(llmemory.Address, addr)
            endaddr = rffi.cast(llmemory.Address,
                            addr + self.get_relative_pos())
            clear_cache(startaddr, endaddr)

    def copy_to_raw_memory(self, addr):
        self._copy_to_raw_memory(addr)
        self.clear_cache(addr)
        self._dump(addr, "jit-backend-dump", 'arm')

    def currpos(self):
        return self.get_relative_pos()


define_instructions(AbstractARMBuilder)
