# array._array_reconstructor is a special constructor used when
# unpickling an array. It provides a portable way to rebuild an array
# from its memory representation.
import sys
from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.error import oefmt
from pypy.interpreter.argument import Arguments
from rpython.rlib import rutf8, rbigint
from rpython.rlib.rstruct import ieee
from rpython.rtyper.lltypesystem import rffi

from pypy.module.array import interp_array

UNKNOWN_FORMAT = -1
UNSIGNED_INT8 = 0
SIGNED_INT8 = 1
UNSIGNED_INT16_LE = 2
UNSIGNED_INT16_BE = 3
SIGNED_INT16_LE = 4
SIGNED_INT16_BE = 5
UNSIGNED_INT32_LE = 6
UNSIGNED_INT32_BE = 7
SIGNED_INT32_LE = 8
SIGNED_INT32_BE = 9
UNSIGNED_INT64_LE = 10
UNSIGNED_INT64_BE = 11
SIGNED_INT64_LE = 12
SIGNED_INT64_BE = 13
IEEE_754_FLOAT_LE = 14
IEEE_754_FLOAT_BE = 15
IEEE_754_DOUBLE_LE = 16
IEEE_754_DOUBLE_BE = 17
UTF16_LE = 18
UTF16_BE = 19
UTF32_LE = 20
UTF32_BE = 21

IS_BIG_ENDIAN = sys.byteorder == 'big'

class MachineFormat(object):
    def __init__(self, bytes, signed, big_endian):
        self.bytes = bytes
        self.signed = signed
        self.big_endian = big_endian

format_descriptors = {
    UNSIGNED_INT8:      MachineFormat(1, False, False),
    SIGNED_INT8:        MachineFormat(1, True, False),
    UNSIGNED_INT16_LE:  MachineFormat(2, False, False),
    UNSIGNED_INT16_BE:  MachineFormat(2, False, True),
    SIGNED_INT16_LE:    MachineFormat(2, True, False),
    SIGNED_INT16_BE:    MachineFormat(2, True, True),
    UNSIGNED_INT32_LE:  MachineFormat(4, False, False),
    UNSIGNED_INT32_BE:  MachineFormat(4, False, True),
    SIGNED_INT32_LE:    MachineFormat(4, True, False),
    SIGNED_INT32_BE:    MachineFormat(4, True, True),
    UNSIGNED_INT64_LE:  MachineFormat(8, False, False),
    UNSIGNED_INT64_BE:  MachineFormat(8, False, True),
    SIGNED_INT64_LE:    MachineFormat(8, True, False),
    SIGNED_INT64_BE:    MachineFormat(8, True, True),
    IEEE_754_FLOAT_LE:  MachineFormat(4, False, False),
    IEEE_754_FLOAT_BE:  MachineFormat(4, False, True),
    IEEE_754_DOUBLE_LE: MachineFormat(8, False, False),
    IEEE_754_DOUBLE_BE: MachineFormat(8, False, True),
    UTF16_LE:           MachineFormat(4, False, False),
    UTF16_BE:           MachineFormat(4, False, True),
    UTF32_LE:           MachineFormat(8, False, False),
    UTF32_BE:           MachineFormat(8, False, True),
}
MACHINE_FORMAT_CODE_MIN = min(format_descriptors)
MACHINE_FORMAT_CODE_MAX = max(format_descriptors)


@unwrap_spec(typecode='text', mformat_code=int)
def array_reconstructor(space, w_cls, typecode, mformat_code, w_items):
    # Fast path: machine format code corresponds to the
    # platform-independent typecode.
    if mformat_code == typecode_to_mformat_code(typecode):
        return interp_array.w_array(
            space, w_cls, typecode, Arguments(space, [w_items]))

    if typecode not in interp_array.types:
        raise oefmt(space.w_ValueError, "invalid type code")
    if (mformat_code < MACHINE_FORMAT_CODE_MIN or
        mformat_code > MACHINE_FORMAT_CODE_MAX):
        raise oefmt(space.w_ValueError, "invalid machine format code")

    # Slow path: Decode the byte string according to the given machine
    # format code. This occurs when the computer unpickling the array
    # object is architecturally different from the one that pickled
    # the array.
    if (mformat_code == IEEE_754_FLOAT_LE or
        mformat_code == IEEE_754_FLOAT_BE or
        mformat_code == IEEE_754_DOUBLE_LE or
        mformat_code == IEEE_754_DOUBLE_BE):

        descr = format_descriptors[mformat_code]
        memstr = space.bytes_w(w_items)
        step = descr.bytes
        converted_items = [
            space.newfloat(ieee.unpack_float(
                    memstr[i:i+step],
                    descr.big_endian))
            for i in range(0, len(memstr), step)]
        w_converted_items = space.newlist(converted_items)

    elif mformat_code == UTF16_LE:
        w_converted_items = space.call_method(
            w_items, "decode", space.newtext("utf-16-le"))
    elif mformat_code == UTF16_BE:
        w_converted_items = space.call_method(
            w_items, "decode", space.newtext("utf-16-be"))
    elif mformat_code == UTF32_LE:
        w_converted_items = space.call_method(
            w_items, "decode", space.newtext("utf-32-le"))
    elif mformat_code == UTF32_BE:
        w_converted_items = space.call_method(
            w_items, "decode", space.newtext("utf-32-be"))
    else:
        descr = format_descriptors[mformat_code]
        # If possible, try to pack array's items using a data type
        # that fits better. This may result in an array with narrower
        # or wider elements.
        #
        # For example, if a 32-bit machine pickles a L-code array of
        # unsigned longs, then the array will be unpickled by 64-bit
        # machine as an I-code array of unsigned ints.
        #
        # XXX: Is it possible to write a unit test for this?
        for tc in interp_array.unroll_typecodes:
            typecode_descr = interp_array.types[tc]
            if (typecode_descr.is_integer_type() and
                typecode_descr.bytes == descr.bytes and
                typecode_descr.signed == descr.signed):
                typecode = tc
                break

        memstr = space.bytes_w(w_items)
        step = descr.bytes
        converted_items = [
            space.newlong_from_rbigint(rbigint.rbigint.frombytes(
                memstr[i:i+step],
                descr.big_endian and 'big' or 'little',
                descr.signed))
            for i in range(0, len(memstr), step)]
        w_converted_items = space.newlist(converted_items)

    return interp_array.w_array(
        space, w_cls, typecode, Arguments(space, [w_converted_items]))

def typecode_to_mformat_code(typecode):
    intsize = 0
    if typecode == 'b':
        return SIGNED_INT8
    elif typecode == 'B':
        return UNSIGNED_INT8
    elif typecode == 'u':
        if rutf8.MAXUNICODE == 0xffff:
            return UTF16_LE + IS_BIG_ENDIAN
        else:
            return UTF32_LE + IS_BIG_ENDIAN
    elif typecode == 'f':
        return IEEE_754_FLOAT_LE + IS_BIG_ENDIAN
    elif typecode == 'd':
        return IEEE_754_DOUBLE_LE + IS_BIG_ENDIAN
    # Integers
    elif typecode == 'h':
        intsize = rffi.sizeof(rffi.SHORT)
        is_signed = True
    elif typecode == 'H':
        intsize = rffi.sizeof(rffi.SHORT)
        is_signed = False
    elif typecode == 'i':
        intsize = rffi.sizeof(rffi.INT)
        is_signed = True
    elif typecode == 'I':
        intsize = rffi.sizeof(rffi.INT)
        is_signed = False
    elif typecode == 'l':
        intsize = rffi.sizeof(rffi.LONG)
        is_signed = True
    elif typecode == 'L':
        intsize = rffi.sizeof(rffi.LONG)
        is_signed = False
    elif typecode == 'q':
        intsize = rffi.sizeof(rffi.LONGLONG)
        is_signed = True
    elif typecode == 'Q':
        intsize = rffi.sizeof(rffi.LONGLONG)
        is_signed = False
    else:
        return UNKNOWN_FORMAT
    if intsize == 2:
        return UNSIGNED_INT16_LE + IS_BIG_ENDIAN + (2 * is_signed)
    elif intsize == 4:
        return UNSIGNED_INT32_LE + IS_BIG_ENDIAN + (2 * is_signed)
    elif intsize == 8:
        return UNSIGNED_INT64_LE + IS_BIG_ENDIAN + (2 * is_signed)
    return UNKNOWN_FORMAT
