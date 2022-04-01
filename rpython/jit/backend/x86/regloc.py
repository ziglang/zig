from rpython.jit.metainterp.history import ConstInt
from rpython.jit.backend.x86 import rx86
from rpython.rlib.unroll import unrolling_iterable
from rpython.jit.backend.x86.arch import WORD, IS_X86_32, IS_X86_64
from rpython.tool.sourcetools import func_with_new_name
from rpython.rlib.objectmodel import specialize, instantiate
from rpython.rlib.rarithmetic import intmask, r_uint
from rpython.jit.metainterp.history import FLOAT, INT
from rpython.jit.codewriter import longlong
from rpython.rtyper.lltypesystem import rffi, lltype

#
# This module adds support for "locations", which can be either in a Const,
# or a RegLoc or a FrameLoc.  It also adds operations like mc.ADD(), which
# take two locations as arguments, decode them, and calls the right
# mc.ADD_rr()/ADD_rb()/ADD_ri().
#

class AssemblerLocation(object):
    _attrs_ = ('value', '_location_code')
    _immutable_ = True
    def _getregkey(self):
        return self.value

    def is_memory_reference(self):
        return self.location_code() in ('b', 's', 'j', 'a', 'm')

    def location_code(self):
        return self._location_code

    def get_width(self):
        raise NotImplementedError

    def value_r(self): return self.value
    def value_b(self): return self.value
    def value_s(self): return self.value
    def value_j(self): return self.value
    def value_i(self): return self.value
    def value_x(self): return self.value
    def value_a(self): raise AssertionError("value_a undefined")
    def value_m(self): raise AssertionError("value_m undefined")

    def find_unused_reg(self): return eax

    def is_stack(self):
        return False

    def is_core_reg(self):
        return False

    def get_position(self):
        raise NotImplementedError # only for stack

class RawEbpLoc(AssemblerLocation):
    """ The same as stack location, but does not know it's position.
    Mostly usable for raw frame access
    """
    _immutable_ = True
    _location_code = 'b'

    def __init__(self, value, type=INT):
        self.value = value
        self.type = type

    def get_width(self):
        if self.type == FLOAT:
            return 8
        return WORD

    def __repr__(self):
        return '%d(%%ebp)' % (self.value,)

    def assembler(self):
        return repr(self)

    def is_float(self):
        return self.type == FLOAT

    def add_offset(self, ofs):
        return RawEbpLoc(self.value + ofs)

    def is_stack(self):
        return True

class RawEspLoc(AssemblerLocation):
    """ Esp-based location
    """
    _immutable_ = True
    _location_code = 's'

    def __init__(self, value, type):
        assert value >= 0     # accessing values < 0 is forbidden on x86-32.
        self.value = value    # (on x86-64 we could allow values down to -128)
        self.type = type

    def _getregkey(self):
        return ~self.value

    def get_width(self):
        if self.type == FLOAT:
            return 8
        return WORD

    def __repr__(self):
        return '%d(%%esp)' % (self.value,)

    def assembler(self):
        return repr(self)

    def is_float(self):
        return self.type == FLOAT

class FrameLoc(RawEbpLoc):
    _immutable_ = True
    
    def __init__(self, position, ebp_offset, type):
        # _getregkey() returns self.value; the value returned must not
        # conflict with RegLoc._getregkey().  It doesn't a bit by chance,
        # so let it fail the following assert if it no longer does.
        assert ebp_offset >= 8 + 8 * IS_X86_64
        self.position = position
        #if position != 9999:
        #    assert (position + JITFRAME_FIXED_SIZE) * WORD == ebp_offset
        self.value = ebp_offset
        # One of INT, REF, FLOAT
        self.type = type

    def get_position(self):
        return self.position

class RegLoc(AssemblerLocation):
    _immutable_ = True
    def __init__(self, regnum, is_xmm):
        assert regnum >= 0
        self.value = regnum
        self.is_xmm = is_xmm
        if self.is_xmm:
            self._location_code = 'x'
        else:
            self._location_code = 'r'
    def __repr__(self):
        if self.is_xmm:
            return rx86.R.xmmnames[self.value]
        else:
            return rx86.R.names[self.value]

    def get_width(self):
        if self.is_xmm:
            return 8
        return WORD

    def lowest8bits(self):
        assert not self.is_xmm
        if WORD == 4:
            assert 0 <= self.value < 4
        return RegLoc(rx86.low_byte(self.value), False)

    def higher8bits(self):
        assert not self.is_xmm
        return RegLoc(rx86.high_byte(self.value), False)

    def assembler(self):
        return '%' + repr(self)

    def find_unused_reg(self):
        if self.value == eax.value:
            return edx
        else:
            return eax

    def is_float(self):
        return self.is_xmm

    def is_core_reg(self):
        return True

class ImmediateAssemblerLocation(AssemblerLocation):
    _immutable_ = True

class ImmedLoc(ImmediateAssemblerLocation):
    _immutable_ = True
    _location_code = 'i'

    def __init__(self, value, is_float=False):
        # force as a real int
        self.value = rffi.cast(lltype.Signed, value)
        self._is_float = is_float

    def getint(self):
        return self.value

    def get_width(self):
        return WORD

    def __repr__(self):
        return "ImmedLoc(%d)" % (self.value)

    def lowest8bits(self):
        val = self.value & 0xFF
        if val > 0x7F:
            val -= 0x100
        return ImmedLoc(val)

    def is_float(self):
        return self._is_float

class AddressLoc(AssemblerLocation):
    _immutable_ = True

    # The address is base_loc + (scaled_loc << scale) + static_offset
    def __init__(self, base_loc, scaled_loc, scale=0, static_offset=0):
        assert 0 <= scale < 4
        assert isinstance(base_loc, ImmedLoc) or isinstance(base_loc, RegLoc)
        assert isinstance(scaled_loc, ImmedLoc) or isinstance(scaled_loc, RegLoc)

        if isinstance(base_loc, ImmedLoc):
            if isinstance(scaled_loc, ImmedLoc):
                self._location_code = 'j'
                self.value = base_loc.value + (scaled_loc.value << scale) + static_offset
            else:
                self._location_code = 'a'
                self.loc_a = (rx86.NO_BASE_REGISTER, scaled_loc.value, scale, base_loc.value + static_offset)
        else:
            if isinstance(scaled_loc, ImmedLoc):
                # FIXME: What if base_loc is ebp or esp?
                self._location_code = 'm'
                self.loc_m = (base_loc.value, (scaled_loc.value << scale) + static_offset)
            else:
                self._location_code = 'a'
                self.loc_a = (base_loc.value, scaled_loc.value, scale, static_offset)

    def __repr__(self):
        dict = {'j': 'value', 'a': 'loc_a', 'm': 'loc_m', 'a':'loc_a'}
        attr = dict.get(self._location_code, '?')
        info = getattr(self, attr, '?')
        return '<AddressLoc %r: %s>' % (self._location_code, info)

    def get_width(self):
        return WORD

    def is_float(self):
        return False # not 100% true, but we don't use AddressLoc for locations
        # really, so it's ok

    def value_a(self):
        return self.loc_a

    def value_m(self):
        return self.loc_m

    def find_unused_reg(self):
        if self._location_code == 'm':
            if self.loc_m[0] == eax.value:
                return edx
        elif self._location_code == 'a':
            if self.loc_a[0] == eax.value:
                if self.loc_a[1] == edx.value:
                    return ecx
                return edx
            if self.loc_a[1] == eax.value:
                if self.loc_a[0] == edx.value:
                    return ecx
                return edx
        return eax

    def add_offset(self, ofs):
        result = instantiate(AddressLoc)
        result._location_code = self._location_code
        if self._location_code == 'm':
            result.loc_m = (self.loc_m[0], self.loc_m[1] + ofs)
        elif self._location_code == 'a':
            result.loc_a = self.loc_a[:3] + (self.loc_a[3] + ofs,)
        elif self._location_code == 'j':
            result.value = self.value + ofs
        else:
            raise AssertionError(self._location_code)
        return result

class ConstFloatLoc(ImmediateAssemblerLocation):
    _immutable_ = True
    _location_code = 'j'

    def __init__(self, address):
        self.value = address

    def get_width(self):
        return 8

    def __repr__(self):
        return '<ConstFloatLoc @%s>' % (self.value,)

    def is_float(self):
        return True

if IS_X86_32:
    class FloatImmedLoc(ImmediateAssemblerLocation):
        # This stands for an immediate float.  It cannot be directly used in
        # any assembler instruction.  Instead, it is meant to be decomposed
        # in two 32-bit halves.  On 64-bit, FloatImmedLoc() is a function
        # instead; see below.
        _immutable_ = True
        _location_code = '#'     # don't use me

        def __init__(self, floatstorage):
            self.aslonglong = floatstorage

        def get_width(self):
            return 8

        def low_part(self):
            return intmask(self.aslonglong)

        def high_part(self):
            return intmask(self.aslonglong >> 32)

        def low_part_loc(self):
            return ImmedLoc(self.low_part())

        def high_part_loc(self):
            return ImmedLoc(self.high_part())

        def __repr__(self):
            floatvalue = longlong.getrealfloat(self.aslonglong)
            return '<FloatImmedLoc(%s)>' % (floatvalue,)

        def is_float(self):
            return True

if IS_X86_64:
    def FloatImmedLoc(floatstorage):
        from rpython.rlib.longlong2float import float2longlong
        value = intmask(float2longlong(floatstorage))
        return ImmedLoc(value, True)


REGLOCS = [RegLoc(i, is_xmm=False) for i in range(16)]
XMMREGLOCS = [RegLoc(i, is_xmm=True) for i in range(16)]
eax, ecx, edx, ebx, esp, ebp, esi, edi, r8, r9, r10, r11, r12, r13, r14, r15 = REGLOCS
xmm0, xmm1, xmm2, xmm3, xmm4, xmm5, xmm6, xmm7, xmm8, xmm9, xmm10, xmm11, xmm12, xmm13, xmm14, xmm15 = XMMREGLOCS

# We use a scratch register to simulate having 64-bit immediates. When we
# want to do something like:
#     mov rax, [0xDEADBEEFDEADBEEF]
# we actually do:
#     mov r11, 0xDEADBEEFDEADBEEF
#     mov rax, [r11]
# 
# NB: You can use the scratch register as a temporary register in
# assembler.py, but care must be taken when doing so. A call to a method in
# LocationCodeBuilder could clobber the scratch register when certain
# location types are passed in.
X86_64_SCRATCH_REG = r11

# XXX: a GPR scratch register is definitely needed, but we could probably do
# without an xmm scratch reg.
X86_64_XMM_SCRATCH_REG = xmm15

# note: 'r' is after 'i' in this list, for _binaryop()
unrolling_location_codes = unrolling_iterable(list("irbsmajx"))

@specialize.arg(1)
def _rx86_getattr(obj, methname):
    if hasattr(rx86.AbstractX86CodeBuilder, methname):
        return getattr(obj, methname)
    else:
        raise AssertionError(methname + " undefined")

def _missing_binary_insn(name, code1, code2):
    raise AssertionError(name + "_" + code1 + code2 + " missing")
_missing_binary_insn._dont_inline_ = True


class LocationCodeBuilder(object):
    _mixin_ = True

    _scratch_register_value = -1    # -1 means 'unknown'

    def _binaryop(name):

        def insn_with_64_bit_immediate(self, loc1, loc2):
            # These are the worst cases:
            val2 = loc2.value_i()
            if name == 'MOV' and isinstance(loc1, RegLoc):
                self.MOV_ri(loc1.value, val2)
                return True
            code1 = loc1.location_code()
            if code1 == 'j':
                checkvalue = loc1.value_j()
            elif code1 == 'm':
                checkvalue = loc1.value_m()[1]
            elif code1 == 'a':
                checkvalue = loc1.value_a()[3]
            else:
                checkvalue = 0
            if not rx86.fits_in_32bits(checkvalue):
                # INSN_ji, and both operands are 64-bit; or INSN_mi or INSN_ai
                # and the constant offset in the address is 64-bit.
                # Hopefully this doesn't happen too often
                freereg = loc1.find_unused_reg()
                self.PUSH_r(freereg.value)
                self.MOV_ri(freereg.value, val2)
                INSN(self, loc1, freereg)
                self.POP_r(freereg.value)
                return True
            else:
                # For this case, we should not need the scratch register more than here.
                self._load_scratch(val2)
                return False

        def invoke(self, codes, val1, val2):
            methname = name + "_" + codes
            _rx86_getattr(self, methname)(val1, val2)
        invoke._annspecialcase_ = 'specialize:arg(1)'

        def has_implementation_for(loc1, loc2):
            # A memo function that returns True if there is any NAME_xy that could match.
            # If it returns False we know the whole subcase can be omitted from translated
            # code.  Without this hack, the size of most _binaryop INSN functions ends up
            # quite large in C code.
            if loc1 == '?':
                return any([has_implementation_for(loc1, loc2)
                            for loc1 in unrolling_location_codes])
            methname = name + "_" + loc1 + loc2
            if not hasattr(rx86.AbstractX86CodeBuilder, methname):
                return False
            # any NAME_j should have a NAME_m as a fallback, too.  Check it
            if loc1 == 'j': assert has_implementation_for('m', loc2), methname
            if loc2 == 'j': assert has_implementation_for(loc1, 'm'), methname
            return True
        has_implementation_for._annspecialcase_ = 'specialize:memo'

        def INSN(self, loc1, loc2):
            code1 = loc1.location_code()
            code2 = loc2.location_code()

            # You cannot pass in the scratch register as a location,
            # except with a MOV instruction.
            if name.startswith('MOV'):
                if loc2 is X86_64_SCRATCH_REG:
                    assert code1 != 'j' and code1 != 'm' and code1 != 'a'
                if loc1 is X86_64_SCRATCH_REG:
                    self.forget_scratch_register()
            elif loc1 is X86_64_SCRATCH_REG or loc2 is X86_64_SCRATCH_REG:
                raise AssertionError("%s with scratch reg specified" % name)

            for possible_code2 in unrolling_location_codes:
                if not has_implementation_for('?', possible_code2):
                    continue
                if code2 == possible_code2:
                    val2 = getattr(loc2, "value_" + possible_code2)()
                    #
                    # Fake out certain operations for x86_64
                    if self.WORD == 8 and possible_code2 == 'i' and not rx86.fits_in_32bits(val2):
                        if insn_with_64_bit_immediate(self, loc1, loc2):
                            return      # done
                        loc2 = X86_64_SCRATCH_REG
                        code2 = 'r'
                        # NB. unrolling_location_codes contains 'r'
                        # after 'i', so that it will be found after
                        # this iteration
                        continue
                    #
                    # Regular case
                    for possible_code1 in unrolling_location_codes:
                        if not has_implementation_for(possible_code1,
                                                      possible_code2):
                            continue
                        if code1 == possible_code1:
                            val1 = getattr(loc1, "value_" + possible_code1)()
                            # More faking out of certain operations for x86_64
                            fits32 = rx86.fits_in_32bits
                            if possible_code1 == 'j' and not fits32(val1):
                                val1 = self._addr_as_reg_offset(val1)
                                invoke(self, "m" + possible_code2, val1, val2)
                                return
                            if possible_code2 == 'j' and not fits32(val2):
                                val2 = self._addr_as_reg_offset(val2)
                                invoke(self, possible_code1 + "m", val1, val2)
                                return
                            if possible_code1 == 'm' and not fits32(val1[1]):
                                val1 = self._fix_static_offset_64_m(val1)
                            if possible_code2 == 'm' and not fits32(val2[1]):
                                val2 = self._fix_static_offset_64_m(val2)
                            if possible_code1 == 'a' and not fits32(val1[3]):
                                val1 = self._fix_static_offset_64_a(val1)
                            if possible_code2 == 'a' and not fits32(val2[3]):
                                val2 = self._fix_static_offset_64_a(val2)
                            invoke(self, possible_code1 + possible_code2, val1, val2)
                            return
            _missing_binary_insn(name, code1, code2)

        return func_with_new_name(INSN, "INSN_" + name)

    def _unaryop(name):
        def INSN(self, loc):
            if loc is X86_64_SCRATCH_REG:
                raise AssertionError("%s with scratch reg specified" % name)

            code = loc.location_code()
            for possible_code in unrolling_location_codes:
                if code == possible_code:
                    val = getattr(loc, "value_" + possible_code)()
                    # Faking out of certain operations for x86_64
                    fits32 = rx86.fits_in_32bits
                    if possible_code == 'i' and not fits32(val):
                        self._load_scratch(val)    # for 'PUSH(imm)'
                        _rx86_getattr(self, name + "_r")(X86_64_SCRATCH_REG.value)
                        return
                    if possible_code == 'j' and not fits32(val):
                        val = self._addr_as_reg_offset(val)
                        _rx86_getattr(self, name + "_m")(val)
                        return
                    if possible_code == 'm' and not fits32(val[1]):
                        val = self._fix_static_offset_64_m(val)
                    if possible_code == 'a' and not fits32(val[3]):
                        val = self._fix_static_offset_64_a(val)
                    methname = name + "_" + possible_code
                    _rx86_getattr(self, methname)(val)

        return func_with_new_name(INSN, "INSN_" + name)

    def _relative_unaryop(name):
        def INSN(self, loc):
            code = loc.location_code()
            for possible_code in unrolling_location_codes:
                if code == possible_code:
                    val = getattr(loc, "value_" + possible_code)()
                    if possible_code == 'i':
                        # This is for CALL or JMP only.
                        if self.WORD == 4:
                            _rx86_getattr(self, name + "_l")(val)
                            self.add_pending_relocation()
                        else:
                            # xxx can we avoid "MOV r11, $val; JMP/CALL *r11"
                            # in case it would fit a 32-bit displacement?
                            # Hard, because we don't know yet where this insn
                            # will end up...
                            assert self.WORD == 8
                            self._load_scratch(val)
                            _rx86_getattr(self, name + "_r")(X86_64_SCRATCH_REG.value)
                    else:
                        methname = name + "_" + possible_code
                        _rx86_getattr(self, methname)(val)
            # This is for CALL and JMP, so it's correct to forget
            # the value of the R11 register here.
            self.forget_scratch_register()

        return func_with_new_name(INSN, "INSN_" + name)

    def _addr_as_reg_offset(self, addr):
        # Encodes a (64-bit) address as an offset from the scratch register.
        # If we are within a "reuse_scratch_register" block, we remember the
        # last value we loaded to the scratch register and encode the address
        # as an offset from that if we can
        if self._scratch_register_value != -1:
            offset = r_uint(addr) - r_uint(self._scratch_register_value)
            offset = intmask(offset)
            if rx86.fits_in_32bits(offset):
                #print '_addr_as_reg_offset(%x) [REUSED r11+%d]' % (
                #    addr, offset)
                return (X86_64_SCRATCH_REG.value, offset)
            #print '_addr_as_reg_offset(%x) [too far]' % (addr,)
            # else: fall through
        #else:
        #    print '_addr_as_reg_offset(%x) [new]' % (addr,)
        self._scratch_register_value = addr
        self.MOV_ri(X86_64_SCRATCH_REG.value, addr)
        return (X86_64_SCRATCH_REG.value, 0)

    def _fix_static_offset_64_m(self, (basereg, static_offset)):
        # For cases where an AddressLoc has the location_code 'm', but
        # where the static offset does not fit in 32-bits.  We have to fall
        # back to the X86_64_SCRATCH_REG.  Returns a new location encoded
        # as mode 'm' too.  These are all possibly rare cases.
        reg, ofs = self._addr_as_reg_offset(static_offset)
        self.forget_scratch_register()
        self.LEA_ra(X86_64_SCRATCH_REG.value, (basereg, reg, 0, ofs))
        return (X86_64_SCRATCH_REG.value, 0)

    def _fix_static_offset_64_a(self, (basereg, scalereg,
                                       scale, static_offset)):
        # For cases where an AddressLoc has the location_code 'a', but
        # where the static offset does not fit in 32-bits.  We have to fall
        # back to the X86_64_SCRATCH_REG.  In one case it is even more
        # annoying.  These are all possibly rare cases.
        reg, ofs = self._addr_as_reg_offset(static_offset)
        #
        if basereg != rx86.NO_BASE_REGISTER:
            self.forget_scratch_register()
            self.LEA_ra(X86_64_SCRATCH_REG.value, (basereg, reg, 0, ofs))
            reg = X86_64_SCRATCH_REG.value
            ofs = 0
        return (reg, scalereg, scale, ofs)

    def _load_scratch(self, value):
        if self._scratch_register_value != -1:
            if self._scratch_register_value == value:
                #print '_load_scratch(%x) [REUSED]' % (value,)
                return
            offset = r_uint(value) - r_uint(self._scratch_register_value)
            offset = intmask(offset)
            if rx86.fits_in_32bits(offset):
                #print '_load_scratch(%x) [LEA r11+%d]' % (value, offset)
                #global COUNT_
                #try:
                #    COUNT_ += 1
                #except NameError:
                #    COUNT_ = 1
                #if COUNT_ % 182 == 0:
                #    import pdb;pdb.set_trace()
                self.LEA_rm(X86_64_SCRATCH_REG.value,
                    (X86_64_SCRATCH_REG.value, offset))
                self._scratch_register_value = value
                return
            #print '_load_scratch(%x) [too far]' % (value,)
        #else:
        #    print '_load_scratch(%x) [new]' % (value,)
        self._scratch_register_value = value
        self.MOV_ri(X86_64_SCRATCH_REG.value, value)

    def forget_scratch_register(self):
        self._scratch_register_value = -1

    def get_scratch_register_known_value(self):
        return self._scratch_register_value

    def restore_scratch_register_known_value(self, saved_value):
        self._scratch_register_value = saved_value

    def load_scratch_if_known(self, saved_value):
        if saved_value != -1:
            assert IS_X86_64
            self._load_scratch(saved_value)

    def trap(self):
        self.INT3()

    def _vector_size_choose(name):
        def invoke(self, suffix, val1, val2):
            methname = name + suffix
            _rx86_getattr(self, methname)(val1, val2)
        invoke._annspecialcase_ = 'specialize:arg(1)'

        possible_instr_unrolled = unrolling_iterable([(1,'B_xx'),(2,'W_xx'),(4,'D_xx'),(8,'Q_xx')])

        def INSN(self, loc1, loc2, size):
            code1 = loc1.location_code()
            code2 = loc2.location_code()
            assert code1 == code2 == 'x'
            val1 = loc1.value_x()
            val2 = loc2.value_x()
            for s,suffix in possible_instr_unrolled:
                if s == size:
                    invoke(self, suffix, val1, val2)
                    break

        return INSN

    AND = _binaryop('AND')
    OR  = _binaryop('OR')
    OR8 = _binaryop('OR8')
    XOR = _binaryop('XOR')
    NOT = _unaryop('NOT')
    SHL = _binaryop('SHL')
    SHR = _binaryop('SHR')
    SAR = _binaryop('SAR')
    TEST = _binaryop('TEST')
    PTEST = _binaryop('PTEST')
    TEST8 = _binaryop('TEST8')
    BTS = _binaryop('BTS')

    INC = _unaryop('INC')
    ADD = _binaryop('ADD')
    SUB = _binaryop('SUB')
    IMUL = _binaryop('IMUL')
    NEG = _unaryop('NEG')
    MUL = _unaryop('MUL')

    CMP = _binaryop('CMP')
    CMP16 = _binaryop('CMP16')
    PCMPEQQ = _binaryop('PCMPEQQ')
    PCMPEQD = _binaryop('PCMPEQD')
    PCMPEQW = _binaryop('PCMPEQW')
    PCMPEQB = _binaryop('PCMPEQB')
    PCMPEQ = _vector_size_choose('PCMPEQ')
    MOV = _binaryop('MOV')
    MOV8 = _binaryop('MOV8')
    MOV16 = _binaryop('MOV16')
    MOVZX8 = _binaryop('MOVZX8')
    MOVSX8 = _binaryop('MOVSX8')
    MOVZX16 = _binaryop('MOVZX16')
    MOVSX16 = _binaryop('MOVSX16')
    MOV32 = _binaryop('MOV32')
    MOVSX32 = _binaryop('MOVSX32')
    # Avoid XCHG because it always implies atomic semantics, which is
    # slower and does not pair well for dispatch.
    #XCHG = _binaryop('XCHG')
    CMOVNS = _binaryop('CMOVNS')

    PUSH = _unaryop('PUSH')
    POP = _unaryop('POP')

    LEA = _binaryop('LEA')

    MOVSD = _binaryop('MOVSD')
    MOVSS = _binaryop('MOVSS')
    MOVAPD = _binaryop('MOVAPD')
    MOVAPS = _binaryop('MOVAPS')
    MOVDQA = _binaryop('MOVDQA')
    MOVDQU = _binaryop('MOVDQU')
    MOVUPD = _binaryop('MOVUPD')
    MOVUPS = _binaryop('MOVUPS')
    ADDSD = _binaryop('ADDSD')
    SUBSD = _binaryop('SUBSD')
    MULSD = _binaryop('MULSD')
    DIVSD = _binaryop('DIVSD')

    # packed
    ADDPD = _binaryop('ADDPD')
    ADDPS = _binaryop('ADDPS')
    SUBPD = _binaryop('SUBPD')
    SUBPS = _binaryop('SUBPS')
    MULPD = _binaryop('MULPD')
    MULPS = _binaryop('MULPS')
    DIVPD = _binaryop('DIVPD')
    DIVPS = _binaryop('DIVPS')

    UCOMISD = _binaryop('UCOMISD')
    CVTSI2SD = _binaryop('CVTSI2SD')
    CVTTSD2SI = _binaryop('CVTTSD2SI')
    CVTSD2SS = _binaryop('CVTSD2SS')
    CVTSS2SD = _binaryop('CVTSS2SD')
    CVTPD2PS = _binaryop('CVTPD2PS')
    CVTPS2PD = _binaryop('CVTPS2PD')
    CVTPD2DQ = _binaryop('CVTPD2DQ')
    CVTDQ2PD = _binaryop('CVTDQ2PD')
    
    SQRTSD = _binaryop('SQRTSD')

    ANDPD = _binaryop('ANDPD')
    ANDPS = _binaryop('ANDPS')
    XORPD = _binaryop('XORPD')
    XORPS = _binaryop('XORPS')

    PADDQ = _binaryop('PADDQ')
    PADDD = _binaryop('PADDD')
    PHADDD = _binaryop('PHADDD')
    PADDW = _binaryop('PADDW')
    PADDB = _binaryop('PADDB')

    PSUBQ = _binaryop('PSUBQ')
    PSUBD = _binaryop('PSUBD')
    PSUBW = _binaryop('PSUBW')
    PSUBB = _binaryop('PSUBB')

    PMULDQ = _binaryop('PMULDQ')
    PMULLD = _binaryop('PMULLD')
    PMULLW = _binaryop('PMULLW')

    PAND  = _binaryop('PAND')
    POR   = _binaryop('POR')
    PXOR  = _binaryop('PXOR')
    PSRLDQ = _binaryop('PSRLDQ')

    MOVDQ = _binaryop('MOVDQ')
    MOVD32 = _binaryop('MOVD32')
    MOVUPS = _binaryop('MOVUPS')
    MOVDDUP = _binaryop('MOVDDUP')

    UNPCKHPD = _binaryop('UNPCKHPD')
    UNPCKLPD = _binaryop('UNPCKLPD')
    UNPCKHPS = _binaryop('UNPCKHPS')
    UNPCKLPS = _binaryop('UNPCKLPS')

    PUNPCKLQDQ = _binaryop('PUNPCKLQDQ')
    PUNPCKHQDQ = _binaryop('PUNPCKHQDQ')
    PUNPCKLDQ = _binaryop('PUNPCKLDQ')
    PUNPCKHDQ = _binaryop('PUNPCKHDQ')

    PSHUFB = _binaryop('PSHUFB')

    HADDPD = _binaryop('HADDPD')
    HADDPS = _binaryop('HADDPS')

    CALL = _relative_unaryop('CALL')
    JMP = _relative_unaryop('JMP')

def imm(x):
    # XXX: ri386 migration shim
    if isinstance(x, ConstInt):
        return ImmedLoc(x.getint())
    else:
        return ImmedLoc(x)

imm0 = imm(0)
imm1 = imm(1)

all_extra_instructions = [name for name in LocationCodeBuilder.__dict__
                          if name[0].isupper()]
all_extra_instructions.sort()
