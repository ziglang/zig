
from rpython.rlib.objectmodel import we_are_translated
from rpython.jit.backend.llsupport.asmmemmgr import BlockBuilderMixin
from rpython.jit.backend.aarch64.locations import RegisterLocation
from rpython.jit.backend.aarch64 import registers as r
from rpython.rlib.rarithmetic import intmask
from rpython.rtyper.lltypesystem import lltype, rffi, llmemory
from rpython.tool.udir import udir

clear_cache = rffi.llexternal(
    "__clear_cache",
    [llmemory.Address, llmemory.Address],
    lltype.Void,
    _nowrapper=True,
    sandboxsafe=True)


class AbstractAarch64Builder(object):
    def write32(self, word):
        self.writechar(chr(word & 0xFF))
        self.writechar(chr((word >> 8) & 0xFF))
        self.writechar(chr((word >> 16) & 0xFF))
        self.writechar(chr((word >> 24) & 0xFF))

    def RET_r(self, arg):
        self.write32((0b1101011001011111 << 16) | (arg << 5))

    def STR_ri(self, rt, rn, offset):
        base = 0b1111100100
        assert offset & 0x7 == 0
        assert 0 <= offset < 32768
        self.write32((base << 22) | ((offset >> 3) << 10) |
                     (rn << 5) | rt)

    def STR_di(self, rt, rn, offset):
        base = 0b1111110100
        assert offset & 0x7 == 0
        assert 0 <= offset < 32768
        self.write32((base << 22) | ((offset >> 3) << 10) | (rn << 5) | rt)

    def STR_dd(self, rt, rn, rm):
        base = 0b11111100001
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)

    def STP_rr_preindex(self, reg1, reg2, rn, offset):
        base = 0b1010100110
        assert -512 <= offset < 512
        assert offset & 0x7 == 0
        self.write32((base << 22) | ((0x7F & (offset >> 3)) << 15) |
                     (reg2 << 10) | (rn << 5) | reg1)

    def STP_rri(self, reg1, reg2, rn, offset):
        base = 0b1010100100
        assert -512 <= offset < 512
        assert offset & 0x7 == 0
        self.write32((base << 22) | ((0x7F & (offset >> 3)) << 15) |
                     (reg2 << 10) | (rn << 5) | reg1)

    def STR_size_rr(self, scale, rt, rn, rm):
        base = 0b111000001
        assert 0 <= scale <= 3
        self.write32((scale << 30) | (base << 21) | (rm << 16) | (0b11 << 13) |
                     (0b010 << 10) | (rn << 5) | rt)

    def STR_size_ri(self, scale, rt, rn, imm):
        assert 0 <= imm < 4096
        assert 0 <= scale <= 3
        base = 0b11100100
        self.write32((scale << 30) | (base << 22) | (imm >> scale << 10) | (rn << 5) | rt)

    def STRB_ri(self, rt, rn, imm):
        self.STR_size_ri(0, rt, rn, imm)

    def STRH_ri(self, rt, rn, imm):
        self.STR_size_ri(1, rt, rn, imm)

    def STRW_ri(self, rt, rn, imm):
        self.STR_size_ri(2, rt, rn, imm)

    def MOV_rr(self, rd, rn):
        self.ORR_rr(rd, r.xzr.value, rn)

    def UMOV_rd(self, rd, rn):
        base = 0b0100111000001000001111
        self.write32((base << 10) | (rn << 5) | rd)

    def INS_dr(self, rd, rn):
        base = 0b0100111000001000000111
        self.write32((base << 10) | (rn << 5) | rd)

    def ORR_rr(self, rd, rn, rm):
        base = 0b10101010000
        self.write32((base << 21) | (rm << 16) |
                     (rn << 5) | rd)

    def MOVK_r_u16(self, rd, immed, shift):
        base = 0b111100101
        assert 0 <= immed < 1 << 16
        assert shift in (0, 16, 32, 48)
        self.write32((base << 23) | (shift >> 4 << 21) | (immed << 5) | rd) 

    def MOVZ_r_u16(self, rd, immed, shift):
        base = 0b110100101
        assert 0 <= immed < 1 << 16
        assert shift in (0, 16, 32, 48)
        self.write32((base << 23) | (shift >> 4 << 21) | (immed << 5) | rd) 

    def MOVN_r_u16(self, rd, immed):
        base = 0b10010010100
        assert 0 <= immed < 1 << 16
        self.write32((base << 21) | (immed << 5) | rd)

    def ADD_ri(self, rd, rn, constant, s=0):
        base = 0b1001000100 | (s << 7)
        assert 0 <= constant < 4096
        self.write32((base << 22) | (constant << 10) |
                     (rn << 5) | rd)

    def SUB_ri(self, rd, rn, constant, s=0):
        base = 0b1101000100 | (s << 7)
        assert 0 <= constant < 4096
        self.write32((base << 22) | (constant << 10) | (rn << 5) | rd)

    def LDP_rri(self, reg1, reg2, rn, offset):
        base = 0b1010100101
        assert -512 <= offset < 512
        assert offset & 0x7 == 0
        assert reg1 != reg2
        self.write32((base << 22) | ((0x7F & (offset >> 3)) << 15) |
                     (reg2 << 10) | (rn << 5) | reg1)

    def LDP_rr_postindex(self, reg1, reg2, rn, offset):
        base = 0b1010100011
        assert -512 <= offset < 512
        assert offset & 0x7 == 0
        assert reg1 != reg2
        assert rn != reg1
        assert rn != reg2
        self.write32((base << 22) | ((0x7F & (offset >> 3)) << 15) |
                     (reg2 << 10) | (rn << 5) | reg1)

    def LDR_ri(self, rt, rn, immed):
        base = 0b1111100101
        assert 0 <= immed < 1<<16
        assert immed & 0x7 == 0
        self.write32((base << 22) | (immed >> 3 << 10) | (rn << 5) | rt)

    def LDR_uint32_ri(self, rt, rn, immed):
        base = 0b1011100101
        assert 0 <= immed < 1<<15
        assert immed & 0x3 == 0
        self.write32((base << 22) | (immed >> 2 << 10) | (rn << 5) | rt)

    def LDR_di(self, rt, rn, offset):
        assert offset & 0x7 == 0
        assert 0 <= offset < 32768
        base = 0b1111110101
        self.write32((base << 22) | (offset >> 3 << 10) | (rn << 5) | rt)

    def LDR_dr(self, rt, rn, rm):
        base = 0b11111100011
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)

    def LDRB_ri(self, rt, rn, immed):
        base = 0b0011100101
        assert 0 <= immed < 1<<12
        self.write32((base << 22) | (immed << 10) | (rn << 5) | rt)

    def LDRSH_ri(self, rt, rn, immed):
        base = 0b0111100110
        assert 0 <= immed <= 1<<13
        assert immed & 0b1 == 0
        self.write32((base << 22) | (immed >> 1 << 10) | (rn << 5) | rt)

    def LDR_rr(self, rt, rn, rm):
        base = 0b11111000011
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)

    def LDR_uint32_rr(self, rt, rn, rm):
        base = 0b10111000011
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)        

    def LDRH_rr(self, rt, rn, rm):
        base = 0b01111000011
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)

    def LDRH_ri(self, rt, rn, immed):
        assert immed & 0b1 == 0
        assert 0 <= immed < (1 << 13)
        base = 0b0111100101
        self.write32((base << 22) | (immed >> 1 << 10) | (rn << 5) | rt)

    def LDRB_rr(self, rt, rn, rm):
        base = 0b00111000011
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)

    def LDRSW_rr(self, rt, rn, rm):
        base = 0b10111000101
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)

    def LDRSW_ri(self, rt, rn, immed):
        assert immed & 0x3 == 0
        assert 0 <= immed < (1<<14)
        base = 0b1011100110
        self.write32((base << 22) | (immed >> 2 << 10) | (rn << 5) | rt)

    def LDRSH_rr(self, rt, rn, rm):
        base = 0b01111000101
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)

    def LDRSB_rr(self, rt, rn, rm):
        base = 0b00111000101
        self.write32((base << 21) | (rm << 16) | (0b011010 << 10) | (rn << 5) | rt)

    def LDRSB_ri(self, rt, rn, immed):
        base = 0b0011100110
        assert 0 <= immed < 1 << 12
        self.write32((base << 22) | (immed << 10) | (rn << 5) | rt)

    def LDR_r_literal(self, rt, offset):
        base = 0b01011000
        assert -(1 << 20) <= offset < (1<< 20)
        assert offset & 0x3 == 0
        self.write32((base << 24) | ((0x7ffff & (offset >> 2)) << 5) | rt)

    def ADD_rr(self, rd, rn, rm, s=0):
        base = 0b10001011000 | (s << 8)
        self.write32((base << 21) | (rm << 16) | (rn << 5) | (rd))

    def ADD_rr_shifted(self, rd, rn, rm, imm):
        # shifttype is LSL
        base = 0b10001011000
        assert 0 <= imm < 64
        self.write32((base << 21) | (rm << 16) | (imm << 10) | (rn << 5) | (rd))

    def FMOV_dd(self, rd, rn):
        base = 0b0001111001100000010000
        self.write32((base << 10) | (rn << 5) | rd)

    def FMOV_dr(self, rd, rn):
        base = 0b1001111001100111000000
        self.write32((base << 10) | (rn << 5) | rd)

    def FADD_dd(self, rd, rn, rm):
        base = 0b00011110011
        self.write32((base << 21) | (rm << 16) | (0b001010 << 10) | (rn << 5) | rd)

    def FSUB_dd(self, rd, rn, rm):
        base = 0b00011110011
        self.write32((base << 21) | (rm << 16) | (0b001110 << 10) | (rn << 5) | rd)

    def FMUL_dd(self, rd, rn, rm):
        base = 0b00011110011
        self.write32((base << 21) | (rm << 16) | (0b000010 << 10) | (rn << 5) | rd)

    def FDIV_dd(self, rd, rn, rm):
        base = 0b00011110011
        self.write32((base << 21) | (rm << 16) | (0b000110 << 10) | (rn << 5) | rd)

    def FCMP_dd(self, rn, rm):
        base = 0b00011110011
        self.write32((base << 21) | (rm << 16) | (0b001000 << 10) | (rn << 5))

    def FNEG_d(self, rd, rn):
        base = 0b0001111001100001010000
        self.write32((base << 10) | (rn << 5) | rd)

    def FABS_d(self, rd, rn):
        base = 0b0001111001100000110000
        self.write32((base << 10) | (rn << 5) | rd)

    def FCVTZS_d(self, rd, rn):
        base = 0b1001111001111000
        self.write32((base << 16) | (rn << 5) | rd)

    def SCVTF_r(self, rd, rn):
        base = 0b1001111001100010
        self.write32((base << 16) | (rn << 5) | rd)

    def SXTB_rr(self, rd, rn):
        base = 0b1001001101000000000111
        self.write32((base << 10) | (rn << 5) | rd)

    def SXTH_rr(self, rd, rn):
        base = 0b1001001101000000001111
        self.write32((base << 10) | (rn << 5) | rd)        

    def SXTW_rr(self, rd, rn):
        base = 0b1001001101000000011111
        self.write32((base << 10) | (rn << 5) | rd)        

    def FSQRT_dd(self, rd, rn):
        base = 0b0001111001100001110000
        self.write32((base << 10) | (rn << 5) | rd)

    def SUB_rr(self, rd, rn, rm, s=0):
        base = 0b11001011001 | (s << 8)
        self.write32((base << 21) | (rm << 16) | (0b11 << 13) | (rn << 5) | (rd))

    def SUB_rr_shifted(self, rd, rn, rm, shift=0):
        base = 0b11001011000
        assert shift == 0
        self.write32((base << 21) | (rm << 16) | (rn << 5) | rd)

    def MUL_rr(self, rd, rn, rm):
        base = 0b10011011000
        self.write32((base << 21) | (rm << 16) | (0b11111 << 10) | (rn << 5) | rd)

    def UMULH_rr(self, rd, rn, rm):
        base = 0b10011011110
        self.write32((base << 21) | (rm << 16) | (0b11111 << 10) | (rn << 5) | rd)

    def AND_rr(self, rd, rn, rm):
        base = 0b10001010000
        self.write32((base << 21) | (rm << 16) | (rn << 5) | rd)

    def AND_rr_shift(self, rd, rn, rm, shift, shifttype=0):
        base = 0b10001010
        assert 0 <= shift < 64
        self.write32((base << 24) | (shifttype << 22) | (rm << 16) | (shift << 10) | (rn << 5) | rd)

    def AND_ri(self, rd, rn, immed):
        assert immed == 0xFF # just one value for now, don't feel like
        # understanding IMMR/IMMS quite yet
        base = 0b1001001001
        immr = 0b000000
        imms = 0b000111
        self.write32((base << 22) | (immr << 16) | (imms << 10) | (rn << 5) | rd)

    def LSL_rr(self, rd, rn, rm):
        base = 0b10011010110
        self.write32((base << 21) | (rm << 16) | (0b001000 << 10) | (rn << 5) | rd)

    def LSL_ri(self, rd, rn, shift):
        assert 0 <= shift <= 63
        immr = 64 - shift
        imms = immr - 1
        base = 0b1101001101
        self.write32((base << 22) | (immr << 16) | (imms << 10) | (rn << 5) | rd)

    def ASR_rr(self, rd, rn, rm):
        base = 0b10011010110
        self.write32((base << 21) | (rm << 16) | (0b001010 << 10) | (rn << 5) | rd)

    def ASR_ri(self, rd, rn, shift):
        assert 0 <= shift <= 63
        imms = 0b111111
        immr = shift
        base = 0b1001001101
        self.write32((base << 22) | (immr << 16) | (imms << 10) | (rn << 5) | rd)

    def LSR_ri(self, rd, rn, shift):
        assert 0 <= shift <= 63
        imms = 0b111111
        immr = shift
        base = 0b1101001101
        self.write32((base << 22) | (immr << 16) | (imms << 10) | (rn << 5) | rd)

    def LSR_rr(self, rd, rn, rm):
        base = 0b10011010110
        self.write32((base << 21) | (rm << 16) | (0b001001 << 10) | (rn << 5) | rd)

    def EOR_rr(self, rd, rn, rm):
        base = 0b11001010000
        self.write32((base << 21) | (rm << 16) | (rn << 5) | rd)

    def MVN_rr(self, rd, rm): # defaults to xzr
        base = 0b10101010001
        self.write32((base << 21) | (rm << 16) | (0b11111 << 5)| rd)

    def MVN_rr_shifted(self, rd, rm, shift=0, shifttype=0): # defaults to LSL
        base = 0b10101010
        assert 0 <= shift < 64
        self.write32((base << 24) | (shifttype << 22) | (1 << 21) |
                     (rm << 16) | (shift << 10) | (0b11111 << 5) | rd)

    def SMULL_rr(self, rd, rn, rm):
        base = 0b10011011001
        self.write32((base << 21) | (rm << 16) | (0b11111 << 10) | (rn << 5) | rd)

    def SMULH_rr(self, rd, rn, rm):
        base = 0b10011011010
        self.write32((base << 21) | (rm << 16) | (0b11111 << 10) | (rn << 5) | rd)

    def CMP_rr(self, rn, rm):
        base = 0b11101011000
        self.write32((base << 21) | (rm << 16) | (rn << 5) | 0b11111)

    def CMP_rr_shifted(self, rn, rm, imm):
        base = 0b11101011100
        assert 0 <= imm <= 63
        self.write32((base << 21) | (rm << 16) | (imm << 10) | (rn << 5) | 0b11111)

    def CMP_ri(self, rn, imm):
        base = 0b1111000100
        assert 0 <= imm <= 4095
        self.write32((base << 22) | (imm << 10) | (rn << 5) | 0b11111)

    def CMP_wi(self, rn, imm):
        base = 0b0111000100
        assert 0 <= imm <= 4095
        self.write32((base << 22) | (imm << 10) | (rn << 5) | 0b11111)

    def CSET_r_flag(self, rd, cond):
        base = 0b10011010100
        self.write32((base << 21) | (0b11111 << 16) | (cond << 12) | (1 << 10) |
                     (0b11111 << 5) | rd)

    def TST_rr_shift(self, rn, rm, shift):
        assert 0 <= shift <= 64
        base = 0b11101010000
        self.write32((base << 21) | (rm << 16) | (shift << 10) | (rn << 5) | 0b11111)

    def STLR(self, rt, rn):
        base = 0b11001000100
        self.write32((base << 21) | (0b11111 << 16) | (0b111111 << 10) | (rn << 5) | rt)

    def LDXR(self, rt, rn):
        base = 0b1100100001011111011111
        self.write32((base << 10) | (rn << 5) | rt)

    def STXR(self, rs, rt, rn):
        base = 0b11001000000
        self.write32((base << 21) | (rs << 16) | (0b011111 << 10) | (rn << 5) | rt)

    #def LDAXR(self, rt, rn):
    #    don't use any more
    #    base = 0b1100100001011111111111
    #    self.write32((base << 10) | (rn << 5) | rt)

    def STLXR(self, rs, rt, rn):
        base = 0b11001000000
        self.write32((base << 21) | (rs << 16) | (0b111111 << 10) | (rn << 5) | rt)

    def NOP(self):
        self.write32(0b11010101000000110010000000011111)

    def B_ofs(self, ofs):
        base = 0b000101
        assert ofs & 0x3 == 0
        assert -(1 << (26 + 2)) <= ofs < 1<<(26 + 2)
        if ofs < 0:
            ofs = (1 << 26) - (-ofs >> 2)
        else:
            ofs = ofs >> 2
        self.write32((base << 26) | ofs)

    def B_ofs_cond(self, ofs, cond):
        base = 0b01010100
        assert ofs & 0x3 == 0
        assert -1 << 21 <= ofs < 1 << 21
        imm = ofs >> 2
        assert imm > 0 # we seem not to need the - jump
        self.write32((base << 24) | (imm << 5) | cond)

    def CBNZ(self, rt, ofs):
        base = 0b10110101
        assert -1 << 21 <= ofs < 1 << 21
        imm = ofs >> 2
        imm &= (1 << 19) - 1
        self.write32((base << 24) | (imm << 5) | rt)

    def CBNZ_w(self, rt, ofs):
        # checks the 'w' part of the register (32 bits)
        base = 0b00110101
        assert -1 << 21 <= ofs < 1 << 21
        imm = ofs >> 2
        imm &= (1 << 19) - 1
        self.write32((base << 24) | (imm << 5) | rt)

    def CBZ(self, rt, ofs):
        base = 0b10110100
        assert -1 << 21 <= ofs < 1 << 21
        imm = ofs >> 2
        imm &= (1 << 19) - 1
        self.write32((base << 24) | (imm << 5) | rt)

    def B(self, target):
        target = rffi.cast(lltype.Signed, target)
        self.gen_load_int_full(r.ip0.value, target)
        self.BR_r(r.ip0.value)

    def BL(self, target):
        # XXX use the IMM version if close enough
        target = rffi.cast(lltype.Signed, target)
        self.gen_load_int_full(r.ip0.value, target)
        self.BLR_r(r.ip0.value)

    def BLR_r(self, reg):
        base = 0b1101011000111111000000
        self.write32((base << 10) | (reg << 5))

    def BR_r(self, reg):
        base = 0b1101011000011111000000
        self.write32((base << 10) | (reg << 5))

    def BRK(self):
        self.write32(0b11010100001 << 21)

    def DMB_ISH(self):
        self.write32(0xd5033bbf)    # from gcc

    def gen_load_int_full(self, r, value):
        self.MOVZ_r_u16(r, value & 0xFFFF, 0)
        self.MOVK_r_u16(r, (value >> 16) & 0xFFFF, 16)
        self.MOVK_r_u16(r, (value >> 32) & 0xFFFF, 32)
        self.MOVK_r_u16(r, (value >> 48) & 0xFFFF, 48)

    def gen_load_int(self, r, value):
        """r is the register number, value is the value to be loaded to the
        register"""
        # XXX optimize!
        if value < 0:
            if value < -65536:
                self.gen_load_int_full(r, value)
            else:
                self.MOVN_r_u16(r, ~value)
            return
        self.MOVZ_r_u16(r, value & 0xFFFF, 0)
        value = value >> 16
        shift = 16
        while value:
            self.MOVK_r_u16(r, value & 0xFFFF, shift)
            shift += 16
            value >>= 16

    def get_max_size_of_gen_load_int(self):
        return 4

    # -------------------------------------------


class OverwritingBuilder(AbstractAarch64Builder):
    def __init__(self, cb, start, size):
        AbstractAarch64Builder.__init__(self)
        self.cb = cb
        self.index = start
        self.start = start
        self.end = start + size

    def currpos(self):
        return self.index

    def writechar(self, char):
        assert self.index <= self.end
        self.cb.overwrite(self.index, char)
        self.index += 1


class InstrBuilder(BlockBuilderMixin, AbstractAarch64Builder):

    def __init__(self, arch_version=7):
        AbstractAarch64Builder.__init__(self)
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
