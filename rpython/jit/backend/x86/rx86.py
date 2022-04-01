import py
from rpython.rlib.objectmodel import ComputedIntSymbolic, we_are_translated
from rpython.rlib.objectmodel import specialize
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.rarithmetic import intmask
from rpython.rtyper.lltypesystem import rffi
from rpython.jit.backend.x86.arch import IS_X86_64

BYTE_REG_FLAG = 0x20
NO_BASE_REGISTER = -1

class R(object):
    # the following are synonyms for rax, rcx, etc. on 64 bits
    eax, ecx, edx, ebx, esp, ebp, esi, edi = range(8)

    # 8-bit registers
    al, cl, dl, bl, ah, ch, dh, bh = [reg | BYTE_REG_FLAG for reg in range(8)]

    # xmm registers
    xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7 = range(8)

    # the following are extra registers available only on 64 bits
    r8, r9, r10, r11, r12, r13, r14, r15 = range(8, 16)
    xmm8, xmm9, xmm10, xmm11, xmm12, xmm13, xmm14, xmm15 = range(8, 16)

    # These replace ah, ch, dh, bh when the REX-prefix is used
    spl, bpl, sil, dil = ah, ch, dh, bh

    # Low-byte of extra registers
    r8l, r9l, r10l, r11l, r12l, r13l, r14l, r15l = [reg | BYTE_REG_FLAG for reg in range(8, 16)]

    names = ['eax', 'ecx', 'edx', 'ebx', 'esp', 'ebp', 'esi', 'edi',
             'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15']
    xmmnames = ['xmm%d' % i for i in range(16)]

def low_byte(reg):
    # On 32-bit, this only works for 0 <= reg < 4.  The caller checks that.
    # On 64-bit, it works for any register, but the assembler instruction
    # must include a REX prefix (possibly with no modifier flags).
    return reg | BYTE_REG_FLAG

def high_byte(reg):
    # This probably shouldn't be called in 64-bit mode, since to use the
    # high-byte registers you have to make sure that there is no REX-prefix
    assert 0 <= reg < 4
    return (reg + 4) | BYTE_REG_FLAG

def single_byte(value):
    return -128 <= value < 128

def fits_in_32bits(value):
    return -2147483648 <= value <= 2147483647

# ____________________________________________________________
# Emit a single char

def encode_char(mc, _, char, orbyte):
    mc.writechar(chr(char | orbyte))
    return 0

# ____________________________________________________________
# Encode a register number in the orbyte

def reg_number_3bits(mc, reg):
    if mc.WORD == 4:
        assert 0 <= reg < 8
        return reg
    else:
        assert 0 <= reg < 16
        return reg & 7

@specialize.arg(2)
def encode_register(mc, reg, factor, orbyte):
    return orbyte | (reg_number_3bits(mc, reg) * factor)

@specialize.arg(2)
def rex_register(mc, reg, factor):
    if reg >= 8:
        if factor == 1:
            return REX_B
        elif factor == 8:
            return REX_R
        else:
            raise ValueError(factor)
    return 0

def register(argnum, factor=1):
    assert factor in (1, 8)
    return encode_register, argnum, factor, rex_register

@specialize.arg(2)
def rex_byte_register(mc, reg, factor):
    assert reg & BYTE_REG_FLAG
    return rex_register(mc, reg & ~BYTE_REG_FLAG, factor)

@specialize.arg(2)
def encode_byte_register(mc, reg, factor, orbyte):
    assert reg & BYTE_REG_FLAG
    return encode_register(mc, reg & ~BYTE_REG_FLAG, factor, orbyte)

def byte_register(argnum, factor=1):
    assert factor in (1, 8)
    return encode_byte_register, argnum, factor, rex_byte_register


# ____________________________________________________________
# Encode a constant in the orbyte

def encode_orbyte(mc, _, constant, orbyte):
    return orbyte | constant

def orbyte(value):
    return encode_orbyte, None, value, None

# ____________________________________________________________
# Emit an immediate value

@specialize.arg(2)
def encode_immediate(mc, immediate, width, orbyte):
    assert orbyte == 0
    if width == 'b':
        mc.writeimm8(immediate)
    elif width == 'h':
        mc.writeimm16(immediate)
    elif width == 'o':
        return immediate    # in the 'orbyte' for the next command
    elif width == 'q' and mc.WORD == 8:
        mc.writeimm64(immediate)
    else:
        mc.writeimm32(immediate)
    return 0

def immediate(argnum, width='i'):
    return encode_immediate, argnum, width, None

# ____________________________________________________________
# Emit an immediate displacement (relative to the cur insn)

def encode_relative(mc, relative_target, _, orbyte):
    assert orbyte == 0
    mc.writeimm32(relative_target)
    return 0

def relative(argnum):
    return encode_relative, argnum, None, None

# ____________________________________________________________
# Emit a mod/rm referencing a stack location [EBP+offset]

@specialize.arg(2)
def encode_stack_bp(mc, offset, force_32bits, orbyte):
    if not force_32bits and single_byte(offset):
        mc.writechar(chr(0x40 | orbyte | R.ebp))
        mc.writeimm8(offset)
    else:
        mc.writechar(chr(0x80 | orbyte | R.ebp))
        mc.writeimm32(offset)
    return 0

def stack_bp(argnum, force_32bits=False):
    return encode_stack_bp, argnum, force_32bits, None

# ____________________________________________________________
# Emit a mod/rm referencing a stack location [ESP+offset]

def encode_stack_sp(mc, offset, _, orbyte):
    SIB = chr((R.esp<<3) | R.esp)    #   use [esp+(no index)+offset]
    if offset == 0:
        mc.writechar(chr(0x04 | orbyte))
        mc.writechar(SIB)
    elif single_byte(offset):
        mc.writechar(chr(0x44 | orbyte))
        mc.writechar(SIB)
        mc.writeimm8(offset)
    else:
        mc.writechar(chr(0x84 | orbyte))
        mc.writechar(SIB)
        mc.writeimm32(offset)
    return 0

def stack_sp(argnum):
    return encode_stack_sp, argnum, None, None

# ____________________________________________________________
# Emit a mod/rm referencing a memory location [reg1+offset]

def encode_mem_reg_plus_const(mc, (reg, offset), _, orbyte):
    assert reg != R.esp and reg != R.ebp
    #
    reg1 = reg_number_3bits(mc, reg)
    no_offset = offset == 0
    SIB = -1
    # 64-bits special cases for reg1 == r12 or r13
    # (which look like esp or ebp after being truncated to 3 bits)
    if mc.WORD == 8:
        if reg1 == R.esp:               # forces an SIB byte:
            SIB = (R.esp<<3) | R.esp    #   use [r12+(no index)+offset]
        elif reg1 == R.ebp:
            no_offset = False
    # end of 64-bits special cases
    if no_offset:
        mc.writechar(chr(0x00 | orbyte | reg1))
        if SIB >= 0: mc.writechar(chr(SIB))
    elif single_byte(offset):
        mc.writechar(chr(0x40 | orbyte | reg1))
        if SIB >= 0: mc.writechar(chr(SIB))
        mc.writeimm8(offset)
    else:
        mc.writechar(chr(0x80 | orbyte | reg1))
        if SIB >= 0: mc.writechar(chr(SIB))
        mc.writeimm32(offset)
    return 0

def rex_mem_reg_plus_const(mc, (reg, offset), _):
    if reg >= 8:
        return REX_B
    return 0

def mem_reg_plus_const(argnum):
    return encode_mem_reg_plus_const, argnum, None, rex_mem_reg_plus_const

# ____________________________________________________________
# Emit a mod/rm referencing an array memory location [reg1+reg2*scale+offset]

def encode_mem_reg_plus_scaled_reg_plus_const(mc,
                                              (reg1, reg2, scaleshift, offset),
                                              _, orbyte):
    # emit "reg1 + (reg2 << scaleshift) + offset"
    assert reg1 != R.ebp and reg2 != R.esp
    assert 0 <= scaleshift < 4
    reg2 = reg_number_3bits(mc, reg2)

    # Special case for no base register
    if reg1 == NO_BASE_REGISTER:
        # modrm
        mc.writechar(chr(0x04 | orbyte))
        # SIB
        mc.writechar(chr((scaleshift<<6) | (reg2<<3) | 5))
        # We're forced to output a disp32, even if offset == 0
        mc.writeimm32(offset)
        return 0

    reg1 = reg_number_3bits(mc, reg1)

    SIB = chr((scaleshift<<6) | (reg2<<3) | reg1)
    #
    no_offset = offset == 0
    # 64-bits special case for reg1 == r13
    # (which look like ebp after being truncated to 3 bits)
    if mc.WORD == 8:
        if reg1 == R.ebp:
            no_offset = False
    # end of 64-bits special case
    if no_offset:
        mc.writechar(chr(0x04 | orbyte))
        mc.writechar(SIB)
    elif single_byte(offset):
        mc.writechar(chr(0x44 | orbyte))
        mc.writechar(SIB)
        mc.writeimm8(offset)
    else:
        mc.writechar(chr(0x84 | orbyte))
        mc.writechar(SIB)
        mc.writeimm32(offset)
    return 0

def rex_mem_reg_plus_scaled_reg_plus_const(mc,
                                           (reg1, reg2, scaleshift, offset),
                                           _):
    rex = 0
    if reg1 >= 8: rex |= REX_B
    if reg2 >= 8: rex |= REX_X
    return rex

def mem_reg_plus_scaled_reg_plus_const(argnum):
    return (encode_mem_reg_plus_scaled_reg_plus_const, argnum, None,
            rex_mem_reg_plus_scaled_reg_plus_const)

# ____________________________________________________________
# Emit a mod/rm referencing an immediate address that fits in 32-bit
# (the immediate address itself must be explicitely encoded as well,
# with immediate(argnum)).

@specialize.arg(2)
def encode_abs(mc, immediate, _, orbyte):
    # expands to either '\x05' on 32-bit, or '\x04\x25' on 64-bit
    if mc.WORD == 8:
        mc.writechar(chr(0x04 | orbyte))
        mc.writechar(chr(0x25))
    else:
        mc.writechar(chr(0x05 | orbyte))
    # followed by an immediate, always 32 bits
    mc.writeimm32(immediate)
    return 0

def abs_(argnum):
    return encode_abs, argnum, None, None

# ____________________________________________________________
# ***X86_64 only*** 
# Emit a mod/rm referencing an address "RIP + immediate_offset".

@specialize.arg(2)
def encode_rip_offset(mc, immediate, _, orbyte):
    assert mc.WORD == 8
    mc.writechar(chr(0x05 | orbyte))
    mc.writeimm32(immediate)
    return 0

def rip_offset(argnum):
    return encode_rip_offset, argnum, None, None

# ____________________________________________________________
# For 64-bits mode: the REX.W, REX.R, REX.X, REG.B prefixes

REX_W = 8
REX_R = 4
REX_X = 2
REX_B = 1

@specialize.arg(2)
def encode_rex(mc, rexbyte, w, orbyte):
    if mc.WORD == 8:
        assert 0 <= rexbyte < 8
        mc.writechar(chr(0x40 | w | rexbyte))
    else:
        assert rexbyte == 0
    return 0

@specialize.arg(2)
def encode_rex_opt(mc, rexbyte, _, orbyte):
    if mc.WORD == 8:
        assert 0 <= rexbyte < 8
        if rexbyte != 0:
            mc.writechar(chr(0x40 | rexbyte))
    else:
        assert rexbyte == 0
    return 0

# REX prefixes: 'rex_w' generates a REX_W, forcing the instruction
# to operate on 64-bit.  'rex_nw' doesn't, so the instruction operates
# on 32-bit or less; the complete REX prefix is omitted if unnecessary.
# 'rex_fw' is a special case which doesn't generate a REX_W but forces
# the REX prefix in all cases.  It is only useful on instructions which
# have an 8-bit register argument, to force access to the "sil" or "dil"
# registers (as opposed to "ah-dh").
rex_w  = encode_rex, 0, REX_W, None       # a REX.W prefix
rex_nw = encode_rex_opt, 0, 0, None       # an optional REX prefix
rex_fw = encode_rex, 0, 0, None           # a forced REX prefix

# ____________________________________________________________

def insn(*encoding):
    def encode(mc, *args):
        rexbyte = 0
        if mc.WORD == 8:
            # compute the REX byte, if any
            for encode_step, arg, extra, rex_step in encoding_steps:
                if rex_step:
                    if arg is not None:
                        arg = args[arg-1]
                    rexbyte |= rex_step(mc, arg, extra)
        args = (rexbyte,) + args
        # emit the bytes of the instruction
        orbyte = 0
        for encode_step, arg, extra, rex_step in encoding_steps:
            if arg is not None:
                arg = args[arg]
            orbyte = encode_step(mc, arg, extra, orbyte)
        assert orbyte == 0

    #
    encoding_steps = []
    for step in encoding:
        if isinstance(step, str):
            for c in step:
                encoding_steps.append((encode_char, None, ord(c), None))
        else:
            assert type(step) is tuple and len(step) == 4
            encoding_steps.append(step)
    encoding_steps = unrolling_iterable(encoding_steps)
    return encode

def xmminsn(*encoding):
    encode = insn(*encoding)
    encode.is_xmm_insn = True
    return encode

def common_modes(group):
    base = group * 8
    char = chr(0xC0 | base)
    INSN_ri8 = insn(rex_w, '\x83', register(1), char, immediate(2,'b'))
    INSN_ri32= insn(rex_w, '\x81', register(1), char, immediate(2))
    INSN_rr = insn(rex_w, chr(base+1), register(2,8), register(1,1), '\xC0')
    INSN_br = insn(rex_w, chr(base+1), register(2,8), stack_bp(1))
    INSN_rb = insn(rex_w, chr(base+3), register(1,8), stack_bp(2))
    INSN_rm = insn(rex_w, chr(base+3), register(1,8), mem_reg_plus_const(2))
    INSN_rj = insn(rex_w, chr(base+3), register(1,8), abs_(2))
    INSN_ji8 = insn(rex_w, '\x83', orbyte(base), abs_(1), immediate(2,'b'))
    INSN_mi8 = insn(rex_w, '\x83', orbyte(base), mem_reg_plus_const(1),
                    immediate(2,'b'))
    INSN_bi8 = insn(rex_w, '\x83', orbyte(base), stack_bp(1), immediate(2,'b'))
    INSN_bi32= insn(rex_w, '\x81', orbyte(base), stack_bp(1), immediate(2))

    def INSN_ri(mc, reg, immed):
        if single_byte(immed):
            INSN_ri8(mc, reg, immed)
        else:
            INSN_ri32(mc, reg, immed)
    INSN_ri._always_inline_ = True      # try to constant-fold single_byte()

    def INSN_bi(mc, offset, immed):
        if single_byte(immed):
            INSN_bi8(mc, offset, immed)
        else:
            INSN_bi32(mc, offset, immed)
    INSN_bi._always_inline_ = True      # try to constant-fold single_byte()

    return (INSN_ri, INSN_rr, INSN_rb, INSN_bi, INSN_br, INSN_rm, INSN_rj,
            INSN_ji8, INSN_mi8)

def select_8_or_32_bit_immed(insn_8, insn_32):
    def INSN(*args):
        immed = args[-1]
        if single_byte(immed):
            insn_8(*args)
        else:
            assert fits_in_32bits(immed)
            insn_32(*args)

    return INSN

def shifts(mod_field):
    modrm = chr(0xC0 | (mod_field << 3))
    shift_once = insn(rex_w, '\xD1', register(1), modrm)
    shift_r_by_cl = insn(rex_w, '\xD3', register(1), modrm)
    shift_ri8 = insn(rex_w, '\xC1', register(1), modrm, immediate(2, 'b'))

    def shift_ri(mc, reg, immed):
        if immed == 1:
            shift_once(mc, reg)
        else:
            shift_ri8(mc, reg, immed)

    def shift_rr(mc, reg1, reg2):
        assert reg2 == R.ecx
        shift_r_by_cl(mc, reg1)

    return (shift_ri, shift_rr)
# ____________________________________________________________


# Method names take the form of
#
#     <instruction name>_<operand type codes>
#
# For example, the method name for "mov reg, immed" is MOV_ri. Operand order
# is Intel-style, with the destination first.
#
# The operand type codes are:
#     r - register
#     b - ebp/rbp offset
#     s - esp/rsp offset
#     j - address
#     i - immediate
#     x - XMM register
#     a - 4-tuple: (base_register, scale_register, scale, offset)
#     m - 2-tuple: (base_register, offset)
class AbstractX86CodeBuilder(object):
    """Abstract base class."""

    def __init__(self):
        self.force_frame_size(self.WORD)

    def writechar(self, char):
        raise NotImplementedError

    def writeimm8(self, imm):
        self.writechar(chr(imm & 0xFF))

    def writeimm16(self, imm):
        self.writechar(chr(imm & 0xFF))
        self.writechar(chr((imm >> 8) & 0xFF))

    def writeimm32(self, imm):
        assert fits_in_32bits(imm)
        self.writechar(chr(imm & 0xFF))
        self.writechar(chr((imm >> 8) & 0xFF))
        self.writechar(chr((imm >> 16) & 0xFF))
        self.writechar(chr((imm >> 24) & 0xFF))

    def force_frame_size(self, frame_size):
        self._frame_size = frame_size

    def stack_frame_size_delta(self, delta):
        "Called when we generate an instruction that changes the value of ESP"
        self._frame_size += delta
        assert self._frame_size >= self.WORD

    def check_stack_size_at_ret(self):
        if IS_X86_64:
            assert self._frame_size == self.WORD
            if not we_are_translated():
                self._frame_size = None

    # ------------------------------ MOV ------------------------------

    MOV_ri = insn(register(1), '\xB8', immediate(2))
    MOV8_ri = insn(rex_fw, byte_register(1), '\xB0', immediate(2, 'b'))

    # ------------------------------ Arithmetic ------------------------------

    INC_m = insn(rex_w, '\xFF', orbyte(0), mem_reg_plus_const(1))
    INC_j = insn(rex_w, '\xFF', orbyte(0), abs_(1))

    AD1_ri,ADD_rr,ADD_rb,_,_,ADD_rm,ADD_rj,_,_ = common_modes(0)
    OR_ri, OR_rr, OR_rb, _,_,OR_rm, OR_rj, _,_ = common_modes(1)
    AND_ri,AND_rr,AND_rb,_,_,AND_rm,AND_rj,_,_ = common_modes(4)
    SU1_ri,SUB_rr,SUB_rb,_,_,SUB_rm,SUB_rj,SUB_ji8,SUB_mi8 = common_modes(5)
    SBB_ri,SBB_rr,SBB_rb,_,_,SBB_rm,SBB_rj,_,_ = common_modes(3)
    XOR_ri,XOR_rr,XOR_rb,_,_,XOR_rm,XOR_rj,_,_ = common_modes(6)
    CMP_ri,CMP_rr,CMP_rb,CMP_bi,CMP_br,CMP_rm,CMP_rj,_,_ = common_modes(7)

    def ADD_ri(self, reg, immed):
        self.AD1_ri(reg, immed)
        if reg == R.esp:
            self.stack_frame_size_delta(-immed)

    def SUB_ri(self, reg, immed):
        self.SU1_ri(reg, immed)
        if reg == R.esp:
            self.stack_frame_size_delta(+immed)

    CMP_mi8 = insn(rex_w, '\x83', orbyte(7<<3), mem_reg_plus_const(1), immediate(2, 'b'))
    CMP_mi32 = insn(rex_w, '\x81', orbyte(7<<3), mem_reg_plus_const(1), immediate(2))
    CMP_mi = select_8_or_32_bit_immed(CMP_mi8, CMP_mi32)
    CMP_mr = insn(rex_w, '\x39', register(2, 8), mem_reg_plus_const(1))

    CMP_ji8 = insn(rex_w, '\x83', orbyte(7<<3), abs_(1), immediate(2, 'b'))
    CMP_ji32 = insn(rex_w, '\x81', orbyte(7<<3), abs_(1), immediate(2))
    CMP_ji = select_8_or_32_bit_immed(CMP_ji8, CMP_ji32)
    CMP_jr = insn(rex_w, '\x39', register(2, 8), abs_(1))

    CMP32_mi = insn(rex_nw, '\x81', orbyte(7<<3), mem_reg_plus_const(1), immediate(2))
    CMP16_mi = insn('\x66', rex_nw, '\x81', orbyte(7<<3), mem_reg_plus_const(1), immediate(2, 'h'))
    CMP8_ri = insn(rex_fw, '\x80', byte_register(1), '\xF8', immediate(2, 'b'))

    AND8_rr = insn(rex_fw, '\x20', byte_register(1), byte_register(2,8), '\xC0')

    OR8_rr = insn(rex_fw, '\x08', byte_register(1), byte_register(2,8), '\xC0')
    OR8_mi = insn(rex_nw, '\x80', orbyte(1<<3), mem_reg_plus_const(1),
                  immediate(2, 'b'))
    OR8_ji = insn(rex_nw, '\x80', orbyte(1<<3), abs_(1),
                  immediate(2, 'b'))

    NEG_r = insn(rex_w, '\xF7', register(1), '\xD8')

    DIV_r = insn(rex_w, '\xF7', register(1), '\xF0')
    IDIV_r = insn(rex_w, '\xF7', register(1), '\xF8')

    MUL_r = insn(rex_w, '\xF7', orbyte(4<<3), register(1), '\xC0')
    MUL_b = insn(rex_w, '\xF7', orbyte(4<<3), stack_bp(1))

    IMUL_rr = insn(rex_w, '\x0F\xAF', register(1, 8), register(2), '\xC0')
    IMUL_rb = insn(rex_w, '\x0F\xAF', register(1, 8), stack_bp(2))

    IMUL_rri8 = insn(rex_w, '\x6B', register(1, 8), register(2), '\xC0', immediate(3, 'b'))
    IMUL_rri32 = insn(rex_w, '\x69', register(1, 8), register(2), '\xC0', immediate(3))
    IMUL_rri = select_8_or_32_bit_immed(IMUL_rri8, IMUL_rri32)

    def IMUL_ri(self, reg, immed):
        self.IMUL_rri(reg, reg, immed)

    SHL_ri, SHL_rr = shifts(4)
    SHR_ri, SHR_rr = shifts(5)
    SAR_ri, SAR_rr = shifts(7)

    NOT_r = insn(rex_w, '\xF7', register(1), '\xD0')
    NOT_b = insn(rex_w, '\xF7', orbyte(2<<3), stack_bp(1))

    CMOVNS_rr = insn(rex_w, '\x0F\x49', register(1, 8), register(2), '\xC0')

    # ------------------------------ Misc stuff ------------------------------

    NOP = insn('\x90')
    RE1 = insn('\xC3')
    RE116_i = insn('\xC2', immediate(1, 'h'))

    def RET(self):
        self.check_stack_size_at_ret()
        self.RE1()

    def RET16_i(self, immed):
        self.check_stack_size_at_ret()
        self.RE116_i(immed)

    PUS1_r = insn(rex_nw, register(1), '\x50')
    PUS1_b = insn(rex_nw, '\xFF', orbyte(6<<3), stack_bp(1))
    PUS1_m = insn(rex_nw, '\xFF', orbyte(6<<3), mem_reg_plus_const(1))
    PUS1_j = insn(rex_nw, '\xFF', orbyte(6<<3), abs_(1))
    PUS1_p = insn(rex_nw, '\xFF', orbyte(6<<3), rip_offset(1))
    PUS1_i8 = insn('\x6A', immediate(1, 'b'))
    PUS1_i32 = insn('\x68', immediate(1, 'i'))

    def PUSH_r(self, reg):
        self.PUS1_r(reg)
        self.stack_frame_size_delta(+self.WORD)

    def PUSH_b(self, ofs):
        self.PUS1_b(ofs)
        self.stack_frame_size_delta(+self.WORD)

    def PUSH_m(self, ofs):
        self.PUS1_m(ofs)
        self.stack_frame_size_delta(+self.WORD)

    def PUSH_i(self, immed):
        if single_byte(immed):
            self.PUS1_i8(immed)
        else:
            self.PUS1_i32(immed)
        self.stack_frame_size_delta(+self.WORD)

    def PUSH_j(self, abs_addr):
        self.PUS1_j(abs_addr)
        self.stack_frame_size_delta(+self.WORD)

    def PUSH_p(self, rip_offset):
        self.PUS1_p(rip_offset)
        self.stack_frame_size_delta(+self.WORD)

    PO1_r = insn(rex_nw, register(1), '\x58')
    PO1_b = insn(rex_nw, '\x8F', orbyte(0<<3), stack_bp(1))

    def POP_r(self, reg):
        self.PO1_r(reg)
        self.stack_frame_size_delta(-self.WORD)

    def POP_b(self, ofs):
        self.PO1_b(ofs)
        self.stack_frame_size_delta(-self.WORD)

    LEA_rb = insn(rex_w, '\x8D', register(1,8), stack_bp(2))
    LE1_rs = insn(rex_w, '\x8D', register(1,8), stack_sp(2))
    LEA32_rb = insn(rex_w, '\x8D', register(1,8),stack_bp(2,force_32bits=True))
    LEA_ra = insn(rex_w, '\x8D', register(1, 8), mem_reg_plus_scaled_reg_plus_const(2))
    LEA_rm = insn(rex_w, '\x8D', register(1, 8), mem_reg_plus_const(2))
    LEA_rj = insn(rex_w, '\x8D', register(1, 8), abs_(2))

    def LEA_rs(self, reg, ofs):
        self.LE1_rs(reg, ofs)
        if reg == R.esp:
            self.stack_frame_size_delta(-ofs)

    CALL_l = insn('\xE8', relative(1))
    CALL_r = insn(rex_nw, '\xFF', register(1), chr(0xC0 | (2<<3)))
    CALL_b = insn('\xFF', orbyte(2<<3), stack_bp(1))
    CALL_s = insn('\xFF', orbyte(2<<3), stack_sp(1))

    # XXX: Only here for testing purposes..."as" happens the encode the
    # registers in the opposite order that we would otherwise do in a
    # register-register exchange.
    XCHG_rr = insn(rex_w, '\x87', register(1), register(2,8), '\xC0')

    JM1_l = insn('\xE9', relative(1))
    JM1_r = insn(rex_nw, '\xFF', orbyte(4<<3), register(1), '\xC0')
    # FIXME: J_il8 and JMP_l8 assume the caller will do the appropriate
    # calculation to find the displacement, but J_il does it for the caller.
    # We need to be consistent.
    JM1_l8 = insn('\xEB', immediate(1, 'b'))
    J_il8 = insn(immediate(1, 'o'), '\x70', immediate(2, 'b'))
    J_il = insn('\x0F', immediate(1,'o'), '\x80', relative(2))

    def JMP_l(self, rel):
        self.JM1_l(rel)
        if not we_are_translated():
            self._frame_size = None

    def JMP_r(self, reg):
        self.JM1_r(reg)
        if not we_are_translated():
            self._frame_size = None

    def JMP_l8(self, rel):
        self.JM1_l8(rel)
        if not we_are_translated():
            self._frame_size = None

    SET_ir = insn(rex_fw, '\x0F', immediate(1,'o'),'\x90', byte_register(2), '\xC0')

    # The 64-bit version of this, CQO, is defined in X86_64_CodeBuilder
    CDQ = insn(rex_nw, '\x99')

    TEST8_mi = insn(rex_nw, '\xF6', orbyte(0<<3), mem_reg_plus_const(1), immediate(2, 'b'))
    TEST8_ai = insn(rex_nw, '\xF6', orbyte(0<<3), mem_reg_plus_scaled_reg_plus_const(1), immediate(2, 'b'))
    TEST8_bi = insn(rex_nw, '\xF6', orbyte(0<<3), stack_bp(1), immediate(2, 'b'))
    TEST8_ji = insn(rex_nw, '\xF6', orbyte(0<<3), abs_(1), immediate(2, 'b'))
    TEST_rr = insn(rex_w, '\x85', register(2,8), register(1), '\xC0')
    TEST_ai = insn(rex_w, '\xF7', orbyte(0<<3), mem_reg_plus_scaled_reg_plus_const(1), immediate(2))
    TEST_mi = insn(rex_w, '\xF7', orbyte(0<<3), mem_reg_plus_const(1), immediate(2))
    TEST_ji = insn(rex_w, '\xF7', orbyte(0<<3), abs_(1), immediate(2))
    TEST_ri = insn(rex_w, '\xF7', orbyte(0<<3), register(1), '\xC0', immediate(2))
    TEST_bi = insn(rex_w, '\xF7', orbyte(0<<3), stack_bp(1), immediate(2))
    TEST_br = insn(rex_w, '\x85', register(2,8), stack_bp(1))

    BTS_mr = insn(rex_w, '\x0F\xAB', register(2,8), mem_reg_plus_const(1))
    BTS_jr = insn(rex_w, '\x0F\xAB', register(2,8), abs_(1))

    # x87 instructions
    FSTPL_b = insn('\xDD', orbyte(3<<3), stack_bp(1)) # rffi.DOUBLE ('as' wants L??)
    FSTPL_s = insn('\xDD', orbyte(3<<3), stack_sp(1)) # rffi.DOUBLE ('as' wants L??)
    FSTPS_s = insn('\xD9', orbyte(3<<3), stack_sp(1)) # lltype.SingleFloat
    FLDL_s  = insn('\xDD', orbyte(0<<3), stack_sp(1))
    FLDS_s  = insn('\xD9', orbyte(0<<3), stack_sp(1))

    # ------------------------------ Random mess -----------------------
    RDTSC = insn('\x0F\x31')

    # reserved as an illegal instruction
    UD2 = insn('\x0F\x0B')

    # a breakpoint
    INT3 = insn('\xCC')

    LOCK = insn('\xF0')
    CMPXCHG_jr = insn(rex_w, '\x0F\xB1', register(2,8), abs_(1))
    CMPXCHG_mr = insn(rex_w, '\x0F\xB1', register(2,8), mem_reg_plus_const(1))

    # ------------------------------ SSE2 ------------------------------

    # Conversion
    CVTSI2SD_xr = xmminsn('\xF2', rex_w, '\x0F\x2A', register(1, 8), register(2), '\xC0')
    CVTSI2SD_xb = xmminsn('\xF2', rex_w, '\x0F\x2A', register(1, 8), stack_bp(2))

    CVTTSD2SI_rx = xmminsn('\xF2', rex_w, '\x0F\x2C', register(1, 8), register(2), '\xC0')
    CVTTSD2SI_rb = xmminsn('\xF2', rex_w, '\x0F\x2C', register(1, 8), stack_bp(2))

    CVTSD2SS_xx = xmminsn('\xF2', rex_nw, '\x0F\x5A', register(1, 8), register(2), '\xC0')
    CVTSD2SS_xb = xmminsn('\xF2', rex_nw, '\x0F\x5A', register(1, 8), stack_bp(2))
    CVTSS2SD_xx = xmminsn('\xF3', rex_nw, '\x0F\x5A', register(1, 8), register(2), '\xC0')
    CVTSS2SD_xb = xmminsn('\xF3', rex_nw, '\x0F\x5A', register(1, 8), stack_bp(2))

    CVTPD2PS_xx = xmminsn('\x66', rex_nw, '\x0F\x5A', register(1, 8), register(2), '\xC0')
    CVTPS2PD_xx = xmminsn(rex_nw, '\x0F\x5A', register(1, 8), register(2), '\xC0')
    CVTDQ2PD_xx = xmminsn('\xF3', rex_nw, '\x0F\xE6', register(1, 8), register(2), '\xC0')
    CVTPD2DQ_xx = xmminsn('\xF2', rex_nw, '\x0F\xE6', register(1, 8), register(2), '\xC0')

    # These work on machine sized registers, so "MOVDQ" is MOVD when running
    # on 32 bits and MOVQ when running on 64 bits.  "MOVD32" is always 32-bit.
    # Note a bug in the Intel documentation:
    # http://lists.gnu.org/archive/html/bug-binutils/2007-07/msg00095.html
    MOVDQ_rx = xmminsn('\x66', rex_w, '\x0F\x7E', register(2, 8), register(1), '\xC0')
    MOVDQ_xr = xmminsn('\x66', rex_w, '\x0F\x6E', register(1, 8), register(2), '\xC0')
    MOVDQ_xb = xmminsn('\x66', rex_w, '\x0F\x6E', register(1, 8), stack_bp(2))
    MOVDQ_xx = xmminsn('\xF3', rex_nw, '\x0F\x7E', register(1, 8), register(2), '\xC0')

    MOVD32_rx = xmminsn('\x66', rex_nw, '\x0F\x7E', register(2, 8), register(1), '\xC0')
    MOVD32_sx = xmminsn('\x66', rex_nw, '\x0F\x7E', register(2, 8), stack_sp(1))
    MOVD32_xr = xmminsn('\x66', rex_nw, '\x0F\x6E', register(1, 8), register(2), '\xC0')
    MOVD32_xb = xmminsn('\x66', rex_nw, '\x0F\x6E', register(1, 8), stack_bp(2))
    MOVD32_xs = xmminsn('\x66', rex_nw, '\x0F\x6E', register(1, 8), stack_sp(2))

    MOVSS_xx = xmminsn('\xF3', rex_nw, '\x0F\x10', register(1,8), register(2), '\xC0')

    PSRAD_xi = xmminsn('\x66', rex_nw, '\x0F\x72', register(1), '\xE0', immediate(2, 'b'))
    PSRLDQ_xi = xmminsn('\x66', rex_nw, '\x0F\x73', register(1), 
                        orbyte(0x3 << 3), '\xC0', immediate(2, 'b'))
    UNPCKLPD_xx = xmminsn('\x66', rex_nw, '\x0F\x14', register(1, 8), register(2), '\xC0')
    UNPCKHPD_xx = xmminsn('\x66', rex_nw, '\x0F\x15', register(1, 8), register(2), '\xC0')
    UNPCKLPS_xx = xmminsn(        rex_nw, '\x0F\x14', register(1, 8), register(2), '\xC0')
    UNPCKHPS_xx = xmminsn(        rex_nw, '\x0F\x15', register(1, 8), register(2), '\xC0')
    MOVDDUP_xx = xmminsn('\xF2', rex_nw, '\x0F\x12', register(1, 8), register(2), '\xC0')
    SHUFPS_xxi = xmminsn(rex_nw, '\x0F\xC6', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    SHUFPD_xxi = xmminsn('\x66', rex_nw, '\x0F\xC6', register(1,8), register(2), '\xC0', immediate(3, 'b'))

    PSHUFD_xxi = xmminsn('\x66', rex_nw, '\x0F\x70', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    PSHUFHW_xxi = xmminsn('\xF3', rex_nw, '\x0F\x70', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    PSHUFLW_xxi = xmminsn('\xF2', rex_nw, '\x0F\x70', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    PSHUFB_xx = xmminsn('\x66', rex_nw, '\x0F\x38\x00', register(1,8), register(2), '\xC0')
    PSHUFB_xm = xmminsn('\x66', rex_nw, '\x0F\x38\x00', register(1,8), mem_reg_plus_const(2))
    PSHUFB_xj = xmminsn('\x66', rex_nw, '\x0F\x38\x00', register(1,8), abs_(2))

    # SSE3
    HADDPD_xx = xmminsn('\x66', rex_nw, '\x0F\x7C', register(1,8), register(2), '\xC0')
    HADDPS_xx = xmminsn('\xF2', rex_nw, '\x0F\x7C', register(1,8), register(2), '\xC0')
    PHADDD_xx = xmminsn('\x66', rex_nw, '\x0F\x38\x02', register(1,8), register(2), '\xC0')

    # following require SSE4_1
    PEXTRQ_rxi = xmminsn('\x66', rex_w, '\x0F\x3A\x16', register(1), register(2,8), '\xC0', immediate(3, 'b'))
    PEXTRD_rxi = xmminsn('\x66', rex_nw, '\x0F\x3A\x16', register(1), register(2,8), '\xC0', immediate(3, 'b'))
    PEXTRW_rxi = xmminsn('\x66', rex_nw, '\x0F\xC5', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    PEXTRB_rxi = xmminsn('\x66', rex_nw, '\x0F\x3A\x14', register(1), register(2,8), '\xC0', immediate(3, 'b'))
    EXTRACTPS_rxi = xmminsn('\x66', rex_nw, '\x0F\x3A\x17', register(1), register(2,8), '\xC0', immediate(3, 'b'))
    
    PINSRQ_xri = xmminsn('\x66', rex_w, '\x0F\x3A\x22', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    PINSRD_xri = xmminsn('\x66', rex_nw, '\x0F\x3A\x22', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    PINSRW_xri = xmminsn('\x66', rex_nw, '\x0F\xC4', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    PINSRB_xri = xmminsn('\x66', rex_nw, '\x0F\x3A\x20', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    INSERTPS_xxi = xmminsn('\x66', rex_nw, '\x0F\x3A\x21', register(1,8), register(2), '\xC0', immediate(3, 'b'))

    PTEST_xx = xmminsn('\x66', rex_nw, '\x0F\x38\x17', register(1,8), register(2), '\xC0')
    PBLENDW_xxi = xmminsn('\x66', rex_nw, '\x0F\x3A\x0E', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    PBLENDVB_xx = xmminsn('\x66', rex_nw, '\x0F\x38\x10', register(1,8), register(2), '\xC0')
    CMPPD_xxi = xmminsn('\x66', rex_nw, '\x0F\xC2', register(1,8), register(2), '\xC0', immediate(3, 'b'))
    CMPPS_xxi = xmminsn(        rex_nw, '\x0F\xC2', register(1,8), register(2), '\xC0', immediate(3, 'b'))

    # ------------------------------------------------------------

Conditions = {
     'O':  0,
    'NO':  1,
     'C':  2,     'B':  2,   'NAE':  2,
    'NC':  3,    'NB':  3,    'AE':  3,
     'Z':  4,     'E':  4,
    'NZ':  5,    'NE':  5,
                 'BE':  6,    'NA':  6,
                'NBE':  7,     'A':  7,
     'S':  8,
    'NS':  9,
     'P': 10,    'PE': 10,
    'NP': 11,    'PO': 11,
                  'L': 12,   'NGE': 12,
                 'NL': 13,    'GE': 13,
                 'LE': 14,    'NG': 14,
                'NLE': 15,     'G': 15,
}
cond_none = -1

def invert_condition(cond_num):
    return cond_num ^ 1


class X86_32_CodeBuilder(AbstractX86CodeBuilder):
    WORD = 4

    PMOVMSKB_rx = xmminsn('\x66', rex_nw, '\x0F\xD7', register(1, 8), register(2), '\xC0')

    # multibyte nops, from 0 to 15 bytes
    MULTIBYTE_NOPs = [
        '',
        '\x90',                          # nop
        '\x66\x90',                      # xchg ax, ax
        '\x8d\x76\x00',                  # lea    0x0(%esi),%esi
        '\x8d\x74\x26\x00',              # lea    0x0(%esi,%eiz,1),%esi
        '\x90\x8d\x74\x26\x00',          # nop; lea 0x0(%esi,%eiz,1),%esi
        '\x8d\xb6\x00\x00\x00\x00',      # lea    0x0(%esi),%esi
        '\x8d\xb4\x26\x00\x00\x00\x00',  # lea    0x0(%esi,%eiz,1),%esi
        ('\x90'                          # nop
         '\x8d\xb4\x26\x00\x00\x00\x00'),#   lea    0x0(%esi,%eiz,1),%esi
        ('\x89\xf6'                      # mov    %esi,%esi
         '\x8d\xbc\x27\x00\x00\x00\x00'),#   lea    0x0(%edi,%eiz,1),%edi
        ('\x8d\x76\x00'                  # lea    0x0(%esi),%esi
         '\x8d\xbc\x27\x00\x00\x00\x00'),#   lea    0x0(%edi,%eiz,1),%edi
        ('\x8d\x74\x26\x00'              # lea    0x0(%esi,%eiz,1),%esi
         '\x8d\xbc\x27\x00\x00\x00\x00'),#   lea    0x0(%edi,%eiz,1),%edi
        ('\x8d\xb6\x00\x00\x00\x00'      # lea    0x0(%esi),%esi
         '\x8d\xbf\x00\x00\x00\x00'),    #   lea    0x0(%edi),%edi
        ('\x8d\xb6\x00\x00\x00\x00'      # lea    0x0(%esi),%esi
         '\x8d\xbc\x27\x00\x00\x00\x00'),#   lea    0x0(%edi,%eiz,1),%edi
        ('\x8d\xb4\x26\x00\x00\x00\x00'  # lea    0x0(%esi,%eiz,1),%esi
         '\x8d\xbc\x27\x00\x00\x00\x00'),#   lea    0x0(%edi,%eiz,1),%edi
        ('\xeb\x0d' + '\x90' * 13)]      # jmp +x0d; a bunch of nops


class X86_64_CodeBuilder(AbstractX86CodeBuilder):
    WORD = 8

    def writeimm64(self, imm):
        self.writechar(chr(imm & 0xFF))
        self.writechar(chr((imm >> 8) & 0xFF))
        self.writechar(chr((imm >> 16) & 0xFF))
        self.writechar(chr((imm >> 24) & 0xFF))
        self.writechar(chr((imm >> 32) & 0xFF))
        self.writechar(chr((imm >> 40) & 0xFF))
        self.writechar(chr((imm >> 48) & 0xFF))
        self.writechar(chr((imm >> 56) & 0xFF))

    CQO = insn(rex_w, '\x99')

    # Three different encodings... following what gcc does.  From the
    # shortest encoding to the longest one.
    MOV_riu32 = insn(rex_nw, register(1), '\xB8', immediate(2, 'i'))
    MOV_ri32 = insn(rex_w, '\xC7', register(1), '\xC0', immediate(2, 'i'))
    MOV_ri64 = insn(rex_w, register(1), '\xB8', immediate(2, 'q'))

    def MOV_ri(self, reg, immed):
        if 0 <= immed <= 4294967295:
            immed = intmask(rffi.cast(rffi.INT, immed))
            self.MOV_riu32(reg, immed)
        elif fits_in_32bits(immed):    # for negative values that fit in 32 bit
            self.MOV_ri32(reg, immed)
        else:
            self.MOV_ri64(reg, immed)

    # multibyte nops, from 0 to 15 bytes
    MULTIBYTE_NOPs = ([
        '',
        '\x90',                          # nop
        '\x66\x90',                      # xchg ax, ax
        '\x0f\x1f\x00',                  # nopl   (%rax)
        '\x0f\x1f\x40\x00',              # nopl   0x0(%rax)
        '\x0f\x1f\x44\x00\x00',          # nopl   0x0(%rax,%rax,1)
        '\x66\x0f\x1f\x44\x00\x00',      # nopw   0x0(%rax,%rax,1)
        '\x0f\x1f\x80\x00\x00\x00\x00',  # nopl   0x0(%rax)
        ('\x0f\x1f\x84\x00\x00\x00\x00'  # nopl   0x0(%rax,%rax,1)
         '\x00'),
        ('\x66\x0f\x1f\x84\x00\x00\x00'  # nopw   0x0(%rax,%rax,1)
         '\x00\x00')] +
        ['\x66' * _i + '\x2e\x0f\x1f'    # nopw   %cs:0x0(%rax,%rax,1)
         '\x84\x00\x00\x00\x00\x00' for _i in range(1, 7)])


def define_modrm_modes(insnname_template, before_modrm, after_modrm=[], regtype='GPR'):
    def add_insn(code, *modrm):
        args = before_modrm + list(modrm)
        methname = insnname_template.replace('*', code)
        if (methname.endswith('_rr') or methname.endswith('_xx')
                or methname.endswith('_ri')):
            args.append('\xC0')
        args += after_modrm

        if regtype == 'XMM':
            insn_func = xmminsn(*args)
        else:
            insn_func = insn(*args)

        if not hasattr(AbstractX86CodeBuilder, methname):
            setattr(AbstractX86CodeBuilder, methname, insn_func)

    modrm_argnum = insnname_template.split('_')[1].index('*')+1

    if regtype == 'GPR':
        add_insn('r', register(modrm_argnum))
    elif regtype == 'BYTE':
        add_insn('r', byte_register(modrm_argnum))
    elif regtype == 'XMM':
        add_insn('x', register(modrm_argnum))
    else:
        raise AssertionError("Invalid type")

    add_insn('b', stack_bp(modrm_argnum))
    add_insn('s', stack_sp(modrm_argnum))
    add_insn('m', mem_reg_plus_const(modrm_argnum))
    add_insn('a', mem_reg_plus_scaled_reg_plus_const(modrm_argnum))
    add_insn('j', abs_(modrm_argnum))
    add_insn('p', rip_offset(modrm_argnum))

# Define a regular MOV, and a variant MOV32 that only uses the low 4 bytes of a
# register
for insnname, rex_type in [('MOV', rex_w), ('MOV32', rex_nw)]:
    define_modrm_modes(insnname + '_*r', [rex_type, '\x89', register(2, 8)])
    define_modrm_modes(insnname + '_r*', [rex_type, '\x8B', register(1, 8)])
    define_modrm_modes(insnname + '_*i', [rex_type, '\xC7', orbyte(0<<3)], [immediate(2)])

define_modrm_modes('MOV8_*r', [rex_fw, '\x88', byte_register(2, 8)], regtype='BYTE')
define_modrm_modes('MOV8_*i', [rex_fw, '\xC6', orbyte(0<<3)], [immediate(2, 'b')], regtype='BYTE')
define_modrm_modes('MOV16_*r', ['\x66', rex_nw, '\x89', register(2, 8)])
define_modrm_modes('MOV16_*i', ['\x66', rex_nw, '\xC7', orbyte(0<<3)], [immediate(2, 'h')])

define_modrm_modes('MOVZX8_r*', [rex_w, '\x0F\xB6', register(1, 8)], regtype='BYTE')
define_modrm_modes('MOVSX8_r*', [rex_w, '\x0F\xBE', register(1, 8)], regtype='BYTE')
define_modrm_modes('MOVZX16_r*', [rex_w, '\x0F\xB7', register(1, 8)])
define_modrm_modes('MOVSX16_r*', [rex_w, '\x0F\xBF', register(1, 8)])
define_modrm_modes('MOVSX32_r*', [rex_w, '\x63', register(1, 8)])

define_modrm_modes('MOVSD_x*', ['\xF2', rex_nw, '\x0F\x10', register(1,8)], regtype='XMM')
define_modrm_modes('MOVSD_*x', ['\xF2', rex_nw, '\x0F\x11', register(2,8)], regtype='XMM')
define_modrm_modes('MOVSS_x*', ['\xF3', rex_nw, '\x0F\x10', register(1,8)], regtype='XMM')
define_modrm_modes('MOVSS_*x', ['\xF3', rex_nw, '\x0F\x11', register(2,8)], regtype='XMM')
define_modrm_modes('MOVAPD_x*', ['\x66', rex_nw, '\x0F\x28', register(1,8)], regtype='XMM')
define_modrm_modes('MOVAPD_*x', ['\x66', rex_nw, '\x0F\x29', register(2,8)], regtype='XMM')
define_modrm_modes('MOVAPS_x*', [        rex_nw, '\x0F\x28', register(1,8)], regtype='XMM')
define_modrm_modes('MOVAPS_*x', [        rex_nw, '\x0F\x29', register(2,8)], regtype='XMM')

define_modrm_modes('MOVDQA_x*', ['\x66', rex_nw, '\x0F\x6F', register(1, 8)], regtype='XMM')
define_modrm_modes('MOVDQA_*x', ['\x66', rex_nw, '\x0F\x7F', register(2, 8)], regtype='XMM')
define_modrm_modes('MOVDQU_x*', ['\xF3', rex_nw, '\x0F\x6F', register(1, 8)], regtype='XMM')
define_modrm_modes('MOVDQU_*x', ['\xF3', rex_nw, '\x0F\x7F', register(2, 8)], regtype='XMM')
define_modrm_modes('MOVUPS_x*', [        rex_nw, '\x0F\x10', register(1, 8)], regtype='XMM')
define_modrm_modes('MOVUPS_*x', [        rex_nw, '\x0F\x11', register(2, 8)], regtype='XMM')
define_modrm_modes('MOVUPD_x*', ['\x66', rex_nw, '\x0F\x10', register(1, 8)], regtype='XMM')
define_modrm_modes('MOVUPD_*x', ['\x66', rex_nw, '\x0F\x11', register(2, 8)], regtype='XMM')

define_modrm_modes('SQRTSD_x*', ['\xF2', rex_nw, '\x0F\x51', register(1,8)], regtype='XMM')

define_modrm_modes('XCHG_r*', [rex_w, '\x87', register(1, 8)])

define_modrm_modes('ADDSD_x*', ['\xF2', rex_nw, '\x0F\x58', register(1, 8)], regtype='XMM')
define_modrm_modes('ADDPD_x*', ['\x66', rex_nw, '\x0F\x58', register(1, 8)], regtype='XMM')
define_modrm_modes('SUBSD_x*', ['\xF2', rex_nw, '\x0F\x5C', register(1, 8)], regtype='XMM')
define_modrm_modes('MULSD_x*', ['\xF2', rex_nw, '\x0F\x59', register(1, 8)], regtype='XMM')
define_modrm_modes('DIVSD_x*', ['\xF2', rex_nw, '\x0F\x5E', register(1, 8)], regtype='XMM')
define_modrm_modes('UCOMISD_x*', ['\x66', rex_nw, '\x0F\x2E', register(1, 8)], regtype='XMM')
define_modrm_modes('XORPD_x*', ['\x66', rex_nw, '\x0F\x57', register(1, 8)], regtype='XMM')
define_modrm_modes('XORPS_x*', [        rex_nw, '\x0F\x57', register(1, 8)], regtype='XMM')
define_modrm_modes('ANDPD_x*', ['\x66', rex_nw, '\x0F\x54', register(1, 8)], regtype='XMM')
define_modrm_modes('ANDPS_x*', [        rex_nw, '\x0F\x54', register(1, 8)], regtype='XMM')

# floating point operations (single & double)
define_modrm_modes('ADDPD_x*', ['\x66', rex_nw, '\x0F\x58', register(1, 8)], regtype='XMM')
define_modrm_modes('ADDPS_x*', [        rex_nw, '\x0F\x58', register(1, 8)], regtype='XMM')
define_modrm_modes('SUBPD_x*', ['\x66', rex_nw, '\x0F\x5C', register(1, 8)], regtype='XMM')
define_modrm_modes('SUBPS_x*', [        rex_nw, '\x0F\x5C', register(1, 8)], regtype='XMM')
define_modrm_modes('MULPD_x*', ['\x66', rex_nw, '\x0F\x59', register(1, 8)], regtype='XMM')
define_modrm_modes('MULPS_x*', [        rex_nw, '\x0F\x59', register(1, 8)], regtype='XMM')
define_modrm_modes('DIVPD_x*', ['\x66', rex_nw, '\x0F\x5E', register(1, 8)], regtype='XMM')
define_modrm_modes('DIVPS_x*', [        rex_nw, '\x0F\x5E', register(1, 8)], regtype='XMM')
define_modrm_modes('DIVPD_x*', ['\x66', rex_nw, '\x0F\x5E', register(1, 8)], regtype='XMM')
define_modrm_modes('DIVPS_x*', [        rex_nw, '\x0F\x5E', register(1, 8)], regtype='XMM')

def define_pxmm_insn(insnname_template, insn_char):
    def add_insn(char, *post):
        methname = insnname_template.replace('*', char)
        insn_func = xmminsn('\x66', rex_nw, '\x0F' + insn_char,
                            register(1, 8), *post)
        assert not hasattr(AbstractX86CodeBuilder, methname)
        setattr(AbstractX86CodeBuilder, methname, insn_func)
    #
    assert insnname_template.count('*') == 1
    add_insn('x', register(2), '\xC0')
    add_insn('j', abs_(2))
    add_insn('m', mem_reg_plus_const(2))

define_pxmm_insn('PADDQ_x*',     '\xD4')
define_pxmm_insn('PADDD_x*',     '\xFE')
define_pxmm_insn('PADDW_x*',     '\xFD')
define_pxmm_insn('PADDB_x*',     '\xFC')

define_pxmm_insn('PSUBQ_x*',     '\xFB')
define_pxmm_insn('PSUBD_x*',     '\xFA')
define_pxmm_insn('PSUBW_x*',     '\xF9')
define_pxmm_insn('PSUBB_x*',     '\xF8')

define_pxmm_insn('PMULDQ_x*',    '\x38\x28')
define_pxmm_insn('PMULLD_x*',    '\x38\x40')
define_pxmm_insn('PMULLW_x*',    '\xD5')

define_pxmm_insn('PAND_x*',      '\xDB')
define_pxmm_insn('POR_x*',       '\xEB')
define_pxmm_insn('PXOR_x*',      '\xEF')
define_pxmm_insn('PUNPCKLDQ_x*', '\x62')
define_pxmm_insn('PUNPCKHDQ_x*', '\x6A')
define_pxmm_insn('PUNPCKLQDQ_x*', '\x6C')
define_pxmm_insn('PUNPCKHQDQ_x*', '\x6D')
define_pxmm_insn('PCMPEQQ_x*',   '\x38\x29')
define_pxmm_insn('PCMPEQD_x*',   '\x76')
define_pxmm_insn('PCMPEQW_x*',   '\x75')
define_pxmm_insn('PCMPEQB_x*',   '\x74')

# ____________________________________________________________

_classes = (AbstractX86CodeBuilder, X86_64_CodeBuilder, X86_32_CodeBuilder)

# Used to build the MachineCodeBlockWrapper
all_instructions = sorted(name for cls in _classes for name in cls.__dict__
                          if name.split('_')[0].isupper())
