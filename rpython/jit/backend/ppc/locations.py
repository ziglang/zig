from rpython.jit.metainterp.history import INT, FLOAT, VECTOR
import sys

# cannot import from arch.py, currently we have a circular import
if sys.maxint == (2**31 - 1):
    WORD = 4
    FWORD = 8
else:
    WORD = 8
    FWORD = 8
DWORD = 2 * WORD


class AssemblerLocation(object):
    _immutable_ = True
    type = INT

    def is_imm(self):
        return False

    def is_stack(self):
        return False

    def is_reg(self):
        return False

    def is_core_reg(self):      # for llsupport/assembler.py
        return self.is_reg()

    def is_fp_reg(self):
        return False

    def is_vector_reg(self):
        return False

    def is_imm_float(self):
        return False

    def is_float(self):
        return False

    def as_key(self):
        raise NotImplementedError

class RegisterLocation(AssemblerLocation):
    _immutable_ = True
    width = WORD

    def __init__(self, value):
        self.value = value

    def __repr__(self):
        return 'r%d' % self.value

    def is_reg(self):
        return True

    def as_key(self):
        return self.value

class FPRegisterLocation(RegisterLocation):
    _immutable_ = True
    type = FLOAT
    width = FWORD

    def __repr__(self):
        return 'fp%d' % self.value

    def is_reg(self):
        return False

    def is_fp_reg(self):
        return True

    def is_float(self):
        return True

    def as_key(self):
        return self.value + 100

class VectorRegisterLocation(AssemblerLocation):
    _immutable_ = True
    width = WORD * 2
    type = VECTOR

    def __init__(self, value):
        self.value = value

    def __repr__(self):
        return 'vr%d' % self.value

    def is_reg(self):
        return True

    def as_key(self):
        return self.value + 132

    def is_vector_reg(self):
        return True


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
    width = FWORD
    type = FLOAT

    def __init__(self, value):
        self.value = value

    def getint(self):
        return self.value

    def __repr__(self):
        return "imm_float(stored at %d)" % (self.value)

    def is_imm_float(self):
        return True

    def as_key(self):
        return self.value

class StackLocation(AssemblerLocation):
    _immutable_ = True

    def __init__(self, position, fp_offset, type=INT):
        if type == FLOAT:
            self.width = FWORD
        else:
            self.width = WORD
        self.position = position
        self.value = fp_offset
        self.type = type

    def __repr__(self):
        return 'FP(%s)+%d' % (self.type, self.value)

    def get_position(self):
        return self.position

    def assembler(self):
        return repr(self)

    def is_stack(self):
        return True

    def as_key(self):
        return -self.position + 10000

def imm(val):
    return ImmLocation(val)

def get_fp_offset(base_ofs, position):
    from rpython.jit.backend.ppc.register import JITFRAME_FIXED_SIZE
    # Argument is a frame position (0, 1, 2...).
    # Returns the n'th word beyond the fixed frame size.
    return base_ofs + WORD * (position + JITFRAME_FIXED_SIZE)
