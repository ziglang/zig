from rpython.jit.metainterp.history import INT, FLOAT
from rpython.jit.backend.zarch.arch import WORD, DOUBLE_WORD

FWORD = 8

class AssemblerLocation(object):
    _immutable_ = True
    type = INT

    def is_imm(self):
        return False

    def is_stack(self):
        return False

    def is_raw_sp(self):
        return False

    def is_reg(self):
        return self.is_core_reg()

    def is_core_reg(self):
        return False

    def is_fp_reg(self):
        return False

    def is_vector_reg(self):
        return False

    def is_imm_float(self):
        return False

    def is_float(self):
        return False

    def is_in_pool(self):
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

    def is_even(self):
        return self.value % 2 == 0

    def is_odd(self):
        return self.value % 2 == 1

    def as_key(self):       # 0 <= as_key <= 15
        return self.value

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

    def is_float(self):
        return True

    def as_key(self):
        return self.value

class FloatRegisterLocation(RegisterLocation):
    _immutable_ = True
    type = FLOAT
    width = DOUBLE_WORD

    def __repr__(self):
        return 'f%d' % self.value

    def is_core_reg(self):
        return False

    def is_fp_reg(self):
        return True

    def as_key(self):            # 16 <= as_key <= 32
        return self.value + 16

    def is_float(self):
        return True

class VectorRegisterLocation(RegisterLocation):
    _immutable_ = True
    type = FLOAT
    width = DOUBLE_WORD*2

    def __repr__(self):
        return 'v%d' % self.value

    def is_core_reg(self):
        return False

    def as_key(self):            # 16 <= as_key <= 32
        return self.value + 32

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
        return -self.position + 10000

    def is_float(self):
        return self.type == FLOAT

class AddressLocation(AssemblerLocation):
    _immutable_ = True

    def __init__(self, basereg, indexreg, displace, length):
        self.displace = displace
        # designates the absense of an index/base register!
        self.base = 0
        self.index = 0
        self.length = 0
        from rpython.jit.backend.zarch import registers as r
        # using this register would be pretty wrong!
        assert basereg is not r.r0
        assert indexreg is not r.r0
        if basereg:
            self.base = basereg.value
        if indexreg:
            self.index = indexreg.value
        if length:
            self.length = length.value

    def __repr__(self):
        return 'addr(base=r%d,idx=r%d,len=%d)' % (self.base, self.index, self.length)

class PoolLoc(AddressLocation):
    _immutable_ = True
    width = WORD

    def __init__(self, offset, isfloat=False):
        AddressLocation.__init__(self, None, None, offset, None)
        assert offset >= 0
        self.base = 13
        self.isfloat = isfloat
        if self.isfloat:
            self.type = FLOAT
        else:
            self.type = INT

    def is_in_pool(self):
        return True

    def is_imm(self):
        return False

    def is_imm_float(self):
        return False

    def is_float(self):
        return self.isfloat

    def __repr__(self):
        return "pool(i,%d)" %  self.displace

    def as_key(self):
        return -self.displace // 8 + 20000

def addr(displace, basereg=None, indexreg=None, length=None):
    return AddressLocation(basereg, indexreg, displace, length)

def imm(i):
    return ImmLocation(i)

def pool(off, float=False):
    return PoolLoc(off, float)

def halfword(value):
    return ImmLocation(value//2)

def get_fp_offset(base_ofs, position):
    from rpython.jit.backend.zarch.registers import JITFRAME_FIXED_SIZE
    return base_ofs + WORD * (position + JITFRAME_FIXED_SIZE)

imm3 = imm(3)
imm1 = imm(1)
imm0 = imm(0)

MASK_VEC_BYTE = 0
MASK_VEC_HWORD = 1
MASK_VEC_WORD = 2
MASK_VEC_DWORD = 3
MASK_VEC_QWORD = 4

def itemsize_to_mask(v):
    if v == 16:
        return imm(MASK_VEC_QWORD)
    elif v == 8:
        return imm(MASK_VEC_DWORD)
    elif v == 4:
        return imm(MASK_VEC_WORD)
    elif v == 2:
        return imm(MASK_VEC_HWORD)
    elif v == 1:
        return imm(MASK_VEC_BYTE)
    assert 0, "not supported itemsize to mask!"
