"""
Packing and unpacking of floats in the IEEE 32-bit and 64-bit formats.
"""

import math

from rpython.rlib import rarithmetic, rfloat, objectmodel, jit
from rpython.rtyper.lltypesystem.rffi import r_ulonglong, r_longlong, LONGLONG, ULONGLONG, cast
from rpython.rlib.longlong2float import longlong2float, float2longlong

def round_to_nearest(x):
    """Python 3 style round:  round a float x to the nearest int, but
    unlike the builtin Python 2.x round function:

      - return an int, not a float
      - do round-half-to-even, not round-half-away-from-zero.

    We assume that x is finite and nonnegative; expect wrong results
    if you use this for negative x.

    """
    int_part = r_ulonglong(x)
    frac_part = x - int_part
    if frac_part > 0.5 or frac_part == 0.5 and int_part & 1:
        int_part += 1
    return int_part

def float_unpack(Q, size):
    """Convert a 16-bit, 32-bit, or 64-bit integer created
    by float_pack into a Python float."""
    if size == 8:
        MIN_EXP = -1021  # = sys.float_info.min_exp
        MAX_EXP = 1024   # = sys.float_info.max_exp
        MANT_DIG = 53    # = sys.float_info.mant_dig
        BITS = 64
    elif size == 4:
        MIN_EXP = -125   # C's FLT_MIN_EXP
        MAX_EXP = 128    # FLT_MAX_EXP
        MANT_DIG = 24    # FLT_MANT_DIG
        BITS = 32
    elif size == 2:
        MIN_EXP = -13
        MAX_EXP = 16
        MANT_DIG = 11
        BITS = 16
    else:
        raise ValueError("invalid size value")

    if not objectmodel.we_are_translated():
        # This tests generates wrong code when translated:
        # with gcc, shifting a 64bit int by 64 bits does
        # not change the value.
        if Q >> BITS:
            raise ValueError("input '%r' out of range '%r'" % (Q, Q>>BITS))

    # extract pieces with assumed 1.mant values
    one = r_ulonglong(1)
    sign = rarithmetic.intmask(Q >> BITS - 1)
    exp = rarithmetic.intmask((Q & ((one << BITS - 1) - (one << MANT_DIG - 1))) >> MANT_DIG - 1)
    mant = Q & ((one << MANT_DIG - 1) - 1)

    if exp == MAX_EXP - MIN_EXP + 2:
        # nan or infinity
        if mant == 0:
            result = rfloat.INFINITY
        else:
            # preserve at most 52 bits of mant value, but pad w/zeros
            exp = r_ulonglong(0x7ff) << 52
            sign = r_ulonglong(sign) << 63
            if MANT_DIG < 53:
                mant = r_ulonglong(mant) << (53 - MANT_DIG) 
            if mant == 0:
                result = rfloat.NAN
            else:
                uint = exp | mant | sign
                result =  longlong2float(cast(LONGLONG, uint))
            return result
    elif exp == 0:
        # subnormal or zero
        result = math.ldexp(mant, MIN_EXP - MANT_DIG)
    else:
        # normal: add implicit one value
        mant += one << MANT_DIG - 1
        result = math.ldexp(mant, exp + MIN_EXP - MANT_DIG - 1)
    return -result if sign else result

def float_unpack80(QQ, size):
    '''Unpack a (mant, exp) tuple of r_ulonglong in 80-bit extended format
    into a python float (a double)
    '''
    if size == 10 or size == 12 or size == 16:
        MIN_EXP = -16381
        MAX_EXP = 16384
        MANT_DIG = 64
        TOP_BITS = 80 - 64
    else:
        raise ValueError("invalid size value")

    if len(QQ) != 2:
        raise ValueError("QQ must be two 64 bit uints")

    if not objectmodel.we_are_translated():
        # This tests generates wrong code when translated:
        # with gcc, shifting a 64bit int by 64 bits does
        # not change the value.
        if QQ[1] >> TOP_BITS:
            raise ValueError("input '%r' out of range '%r'" % (QQ, QQ[1]>>TOP_BITS))

    # extract pieces with explicit one in MANT_DIG
    one = r_ulonglong(1)
    sign = rarithmetic.intmask(QQ[1] >> TOP_BITS - 1)
    exp = rarithmetic.intmask((QQ[1] & ((one << TOP_BITS - 1) - 1)))
    mant = QQ[0]

    if exp == MAX_EXP - MIN_EXP + 2:
        # nan or infinity
        if mant == 0:
            result = rfloat.INFINITY
        else:
            exp = r_ulonglong(0x7ff) << 52
            mant = r_ulonglong(mant) >> size + 1
            if mant == 0:
                result = rfloat.NAN
            else:
                uint = exp | r_ulonglong(mant) | r_ulonglong(sign)
                result =  longlong2float(cast(LONGLONG, uint))
            return result
    else:
        # normal
        result = math.ldexp(mant, exp + MIN_EXP - MANT_DIG - 1)
    return -result if sign else result

def float_pack(x, size):
    """Convert a Python float x into a 64-bit unsigned integer
    with the same byte representation."""
    if size == 8:
        MIN_EXP = -1021  # = sys.float_info.min_exp
        MAX_EXP = 1024   # = sys.float_info.max_exp
        MANT_DIG = 53    # = sys.float_info.mant_dig
        BITS = 64
    elif size == 4:
        MIN_EXP = -125   # C's FLT_MIN_EXP
        MAX_EXP = 128    # FLT_MAX_EXP
        MANT_DIG = 24    # FLT_MANT_DIG
        BITS = 32
    elif size == 2:
        MIN_EXP = -13
        MAX_EXP = 16
        MANT_DIG = 11
        BITS = 16
    else:
        raise ValueError("invalid size value")

    sign = math.copysign(1.0, x) < 0.0
    if math.isinf(x):
        mant = r_ulonglong(0)
        exp = MAX_EXP - MIN_EXP + 2
    elif math.isnan(x):
        asint = cast(ULONGLONG, float2longlong(x))
        sign = asint >> 63
        # shift off lower bits, perhaps losing data
        mant = asint & ((r_ulonglong(1) << 52) - 1)
        if MANT_DIG < 53:
            mant = mant >> (53 - MANT_DIG)
        if mant == 0:
            mant = r_ulonglong(1) << (MANT_DIG - 1) - 1
        exp = MAX_EXP - MIN_EXP + 2
    elif x == 0.0:
        mant = r_ulonglong(0)
        exp = 0
    else:
        m, e = math.frexp(abs(x))  # abs(x) == m * 2**e
        exp = e - (MIN_EXP - 1)
        if exp > 0:
            # Normal case.
            mant = round_to_nearest(m * (r_ulonglong(1) << MANT_DIG))
            mant -= r_ulonglong(1) << MANT_DIG - 1
        else:
            # Subnormal case.
            if exp + MANT_DIG - 1 >= 0:
                mant = round_to_nearest(m * (r_ulonglong(1) << exp + MANT_DIG - 1))
            else:
                mant = r_ulonglong(0)
            exp = 0

        # Special case: rounding produced a MANT_DIG-bit mantissa.
        if not objectmodel.we_are_translated():
            assert 0 <= mant <= 1 << MANT_DIG - 1
        if mant == r_ulonglong(1) << MANT_DIG - 1:
            mant = r_ulonglong(0)
            exp += 1

        # Raise on overflow (in some circumstances, may want to return
        # infinity instead).
        if exp >= MAX_EXP - MIN_EXP + 2:
            raise OverflowError("float too large to pack in this format")

    # check constraints
    if not objectmodel.we_are_translated():
        assert 0 <= mant <= (1 << MANT_DIG) - 1
        assert 0 <= exp <= MAX_EXP - MIN_EXP + 2
        assert 0 <= sign <= 1
    exp = r_ulonglong(exp)
    sign = r_ulonglong(sign)
    return ((sign << BITS - 1) | (exp << MANT_DIG - 1)) | mant

def float_pack80(x, size):
    """Convert a Python float or longfloat x into two 64-bit unsigned integers
    with 80 bit extended representation."""
    x = float(x) # longfloat not really supported
    if size == 10 or size == 12 or size == 16:
        MIN_EXP = -16381
        MAX_EXP = 16384
        MANT_DIG = 64
        BITS = 80
    else:
        raise ValueError("invalid size value")

    sign = math.copysign(1.0, x) < 0.0
    if math.isinf(x):
        mant = r_ulonglong(0)
        exp = MAX_EXP - MIN_EXP + 2
    elif math.isnan(x):
        asint = cast(ULONGLONG, float2longlong(x))
        mant = asint & ((r_ulonglong(1) << 51) - 1)
        if mant == 0:
            mant = r_ulonglong(1) << (MANT_DIG - 1) - 1
        sign = asint < 0
        exp = MAX_EXP - MIN_EXP + 2
    elif x == 0.0:
        mant = r_ulonglong(0)
        exp = 0
    else:
        m, e = math.frexp(abs(x))  # abs(x) == m * 2**e
        exp = e - (MIN_EXP - 1)
        if exp > 0:
            # Normal case. Avoid uint64 overflow by using MANT_DIG-1
            mant = round_to_nearest(m * (r_ulonglong(1) << MANT_DIG - 1))
        else:
            # Subnormal case.
            if exp + MANT_DIG - 1 >= 0:
                mant = round_to_nearest(m * (r_ulonglong(1) << exp + MANT_DIG - 1))
            else:
                mant = r_ulonglong(0)
            exp = 0

        # Special case: rounding produced a MANT_DIG-bit mantissa.
        if mant == r_ulonglong(1) << MANT_DIG - 1:
            mant = r_ulonglong(0)
            exp += 1

        # Raise on overflow (in some circumstances, may want to return
        # infinity instead).
        if exp >= MAX_EXP - MIN_EXP + 2:
            raise OverflowError("float too large to pack in this format")

        mant = mant << 1
    # check constraints
    if not objectmodel.we_are_translated():
        assert 0 <= mant <= (1 << MANT_DIG) - 1
        assert 0 <= exp <= MAX_EXP - MIN_EXP + 2
        assert 0 <= sign <= 1
    exp = r_ulonglong(exp)
    sign = r_ulonglong(sign)
    return (mant, (sign << BITS - MANT_DIG - 1) | exp)


def pack_float(wbuf, pos, x, size, be):
    unsigned = float_pack(x, size)
    value = rarithmetic.longlongmask(unsigned)
    pack_float_to_buffer(wbuf, pos, value, size, be)

@jit.unroll_safe
def pack_float_to_buffer(wbuf, pos, value, size, be):
    if be:
        # write in reversed order
        for i in range(size):
            c = chr((value >> (i * 8)) & 0xFF)
            wbuf.setitem(pos + size - i - 1, c)
    else:
        for i in range(size):
            c = chr((value >> (i * 8)) & 0xFF)
            wbuf.setitem(pos+i, c)

@jit.unroll_safe
def pack_float80(result, x, size, be):
    l = []
    unsigned = float_pack80(x, size)
    for i in range(8):
        l.append(chr((unsigned[0] >> (i * 8)) & 0xFF))
    for i in range(2):
        l.append(chr((unsigned[1] >> (i * 8)) & 0xFF))
    for i in range(size - 10):
        l.append('\x00')
    if be:
        l.reverse()
    result.append("".join(l))

@jit.unroll_safe
def unpack_float(s, be):
    unsigned = r_ulonglong(0)
    for i in range(min(len(s), 8)):
        c = ord(s[-i - 1 if be else i])
        unsigned |= r_ulonglong(c) << (i * 8)
    return float_unpack(unsigned, len(s))

@jit.unroll_safe
def unpack_float80(s, be):
    QQ = [r_ulonglong(0), r_ulonglong(0)]
    for i in range(8):
        c = ord(s[-i - 1 if be else i])
        QQ[0] |= r_ulonglong(c) << (i * 8)
    for i in range(8, 10):
        c = ord(s[-i - 1 if be else i])
        QQ[1] |= r_ulonglong(c) << ((i - 8) * 8)
    return float_unpack80(QQ, len(s))
