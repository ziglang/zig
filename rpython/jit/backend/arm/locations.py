from rpython.jit.metainterp.history import INT, FLOAT
from rpython.jit.backend.arm.arch import WORD, DOUBLE_WORD, JITFRAME_FIXED_SIZE

class AssemblerLocation(object):
    _immutable_ = True
    type = INT

    def is_imm(self):
        return False

    def is_stack(self):
        return False

    def is_raw_sp(self):
        return False

    def is_core_reg(self):
        return False

    def is_vfp_reg(self):
        return False

    def is_imm_float(self):
        return False

    def is_float(self):
        return False

    def as_key(self):
        raise NotImplementedError

    def get_position(self):
        raise NotImplementedError # only for stack

class RegisterLocation(AssemblerLocation):
    _immutable_ = True
    width = WORD

    def __init__(self, value):
        self.value = value

    def __repr__(self):
        return 'r%d' % self.value

    def is_core_reg(self):
        return True

    def as_key(self):       # 0 <= as_key <= 15
        return self.value


class VFPRegisterLocation(RegisterLocation):
    _immutable_ = True
    type = FLOAT
    width = 2 * WORD

    def __repr__(self):
        return 'vfp(d%d)' % self.value

    def is_core_reg(self):
        return False

    def is_vfp_reg(self):
        return True

    def as_key(self):            # 20 <= as_key <= 35
        return self.value + 20

    def is_float(self):
        return True

class SVFPRegisterLocation(VFPRegisterLocation):
    """Single Precission VFP Register"""
    _immutable_ = True
    width = WORD
    type = 'S'

    def __repr__(self):
        return 'vfp(s%d)' % self.value

class ImmLocation(AssemblerLocation):
    _immutable_ = True
    width = WORD

    def __init__(self, value):
        self.value = value

    def getint(self):
        return self.value

    def __repr__(self):
        return "imm(%d)" % (self.value)

    def is_imm(self):
        return True


class ConstFloatLoc(AssemblerLocation):
    """This class represents an imm float value which is stored in memory at
    the address stored in the field value"""
    _immutable_ = True
    width = 2 * WORD
    type = FLOAT

    def __init__(self, value):
        self.value = value

    def getint(self):
        return self.value

    def __repr__(self):
        return "imm_float(stored at %d)" % (self.value)

    def is_imm_float(self):
        return True

    def as_key(self):          # a real address + 1
        return self.value | 1

    def is_float(self):
        return True

class StackLocation(AssemblerLocation):
    _immutable_ = True

    def __init__(self, position, fp_offset, type=INT):
        if type == FLOAT:
            self.width = DOUBLE_WORD
        else:
            self.width = WORD
        self.position = position
        self.value = fp_offset
        self.type = type

    def __repr__(self):
        return 'FP(%s)+%d' % (self.type, self.position,)

    def location_code(self):
        return 'b'

    def get_position(self):
        return self.position

    def assembler(self):
        return repr(self)

    def is_stack(self):
        return True

    def as_key(self):                # an aligned word + 10000
        return self.position + 10000

    def is_float(self):
        return self.type == FLOAT

class RawSPStackLocation(AssemblerLocation):
    _immutable_ = True

    def __init__(self, sp_offset, type=INT):
        if type == FLOAT:
            self.width = DOUBLE_WORD
        else:
            self.width = WORD
        self.value = sp_offset
        self.type = type

    def __repr__(self):
        return 'SP(%s)+%d' % (self.type, self.value,)

    def is_raw_sp(self):
        return True

    def is_float(self):
        return self.type == FLOAT

    def as_key(self):            # a word >= 1000, and < 1000 + size of SP frame
        return self.value + 1000


def imm(i):
    return ImmLocation(i)


def get_fp_offset(base_ofs, position):
    return base_ofs + WORD * (position + JITFRAME_FIXED_SIZE)
