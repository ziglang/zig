from rpython.rlib import rutf8
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.rarithmetic import r_uint, r_ulonglong, intmask
from rpython.rtyper.annlowlevel import llunicode
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem.rstr import copy_unicode_to_raw


class OutOfRange(Exception):
    ordinal = 0

    def __init__(self, ordinal):
        ordinal = intmask(rffi.cast(rffi.INT, ordinal))
        self.ordinal = ordinal

def utf8_from_char32(ptr, length):
    # 'ptr' is a pointer to 'length' 32-bit integers
    ptr = rffi.cast(rffi.UINTP, ptr)
    u = StringBuilder(length)
    j = 0
    while j < length:
        ch = intmask(ptr[j])
        j += 1
        try:
            rutf8.unichr_as_utf8_append(u, ch, allow_surrogates=True)
        except rutf8.OutOfRange:
            raise OutOfRange(ch)
    return u.build(), length

def utf8_from_char16(ptr, length):
    # 'ptr' is a pointer to 'length' 16-bit integers
    ptr = rffi.cast(rffi.USHORTP, ptr)
    u = StringBuilder(length)
    j = 0
    result_length = length
    while j < length:
        ch = intmask(ptr[j])
        j += 1
        if 0xD800 <= ch <= 0xDBFF and j < length:
            ch2 = intmask(ptr[j])
            if 0xDC00 <= ch2 <= 0xDFFF:
                ch = (((ch & 0x3FF)<<10) | (ch2 & 0x3FF)) + 0x10000
                j += 1
                result_length -= 1
        rutf8.unichr_as_utf8_append(u, ch, allow_surrogates=True)
    return u.build(), result_length


@specialize.ll()
def _measure_length(ptr, maxlen):
    result = 0
    if maxlen < 0:
        while intmask(ptr[result]) != 0:
            result += 1
    else:
        while result < maxlen and intmask(ptr[result]) != 0:
            result += 1
    return result

def measure_length_16(ptr, maxlen=-1):
    return _measure_length(rffi.cast(rffi.USHORTP, ptr), maxlen)

def measure_length_32(ptr, maxlen=-1):
    return _measure_length(rffi.cast(rffi.UINTP, ptr), maxlen)


def utf8_size_as_char16(u):
    # Counts one per unichar in 'u', or two if they are greater than 0xffff.
    TABLE = "\x01\x01\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x01\x01\x01\x02"
    result = 0
    for c in u:
        result += ord(TABLE[ord(c) >> 4])
    return result

def utf8_to_char32(utf8, target_ptr, target_length, add_final_zero):
    # 'target_ptr' is a raw pointer to 'target_length' 32-bit integers;
    # we assume (and check) that target_length == number of unichars in utf8.
    unichardata = rffi.cast(rffi.UINTP, target_ptr)
    i = 0
    for j in range(target_length):
        code = rutf8.codepoint_at_pos(utf8, i)
        unichardata[j] = rffi.cast(rffi.UINT, code)
        i = rutf8.next_codepoint_pos(utf8, i)
    assert i == len(utf8)
    if add_final_zero:
        unichardata[target_length] = rffi.cast(rffi.UINT, 0)

def utf8_to_char16(utf8, target_ptr, target_length, add_final_zero):
    # 'target_ptr' is a raw pointer to 'target_length' 16-bit integers;
    # we assume (and check) that target_length == utf8_size_as_char16(utf8).
    ptr = rffi.cast(rffi.USHORTP, target_ptr)
    i = 0
    while i < len(utf8):
        ordinal = rutf8.codepoint_at_pos(utf8, i)
        if ordinal > 0xFFFF:
            ordinal -= 0x10000
            ptr[0] = rffi.cast(rffi.USHORT, 0xD800 | (ordinal >> 10))
            ptr[1] = rffi.cast(rffi.USHORT, 0xDC00 | (ordinal & 0x3FF))
            ptr = rffi.ptradd(ptr, 2)
        else:
            ptr[0] = rffi.cast(rffi.USHORT, ordinal)
            ptr = rffi.ptradd(ptr, 1)
        i = rutf8.next_codepoint_pos(utf8, i)
    assert ptr == (
        rffi.ptradd(rffi.cast(rffi.USHORTP, target_ptr), target_length))
    if add_final_zero:
        ptr[0] = rffi.cast(rffi.USHORT, 0)
