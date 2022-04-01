from pypy.interpreter.error import OperationError
from pypy.interpreter.gateway import unwrap_spec
from rpython.rlib.rstring import StringBuilder
from pypy.module.binascii.interp_binascii import raise_Error
from pypy.module.binascii.interp_binascii import AsciiBufferUnwrapper
from rpython.rlib.rarithmetic import ovfcheck

# ____________________________________________________________

PAD = '='

table_a2b_base64 = [
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,62, -1,-1,-1,63,
    52,53,54,55, 56,57,58,59, 60,61,-1,-1, -1,-1,-1,-1, # Note PAD->-1 here
    -1, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,
    15,16,17,18, 19,20,21,22, 23,24,25,-1, -1,-1,-1,-1,
    -1,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,
    41,42,43,44, 45,46,47,48, 49,50,51,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
]
def _transform(n):
    if n == -1:
        return '\xff'
    else:
        return chr(n)
table_a2b_base64 = ''.join(map(_transform, table_a2b_base64))
assert len(table_a2b_base64) == 256

@unwrap_spec(ascii=AsciiBufferUnwrapper)
def a2b_base64(space, ascii):
    "Decode a line of base64 data."

    res = StringBuilder((len(ascii) // 4) * 3)   # maximum estimate
    quad_pos = 0
    leftchar = 0
    leftbits = 0
    last_char_was_a_pad = False
    bin_used = 0

    for c in ascii:
        if c == PAD:
            if quad_pos > 2 or (quad_pos == 2 and last_char_was_a_pad):
                break      # stop on 'xxx=' or on 'xx=='
            last_char_was_a_pad = True
        else:
            n = ord(table_a2b_base64[ord(c)])
            if n == 0xff:
                continue    # ignore strange characters
            #
            # Shift it in on the low end, and see if there's
            # a byte ready for output.
            quad_pos = (quad_pos + 1) & 3
            leftchar = (leftchar << 6) | n
            leftbits += 6
            #
            if leftbits >= 8:
                leftbits -= 8
                res.append(chr(leftchar >> leftbits))
                leftchar &= ((1 << leftbits) - 1)
                bin_used += 1
            #
            last_char_was_a_pad = False
    else:
        if leftbits != 0:
            if leftbits == 6:
                # There is exactly one extra valid, non-padding, base64 character.
                # This is an invalid length, as there is no possible input that
                # could encoded into such a base64 string.
                msg = ("Invalid base64-encoded string: number of data "
                       "characters (%d) cannot be 1 more than a multiple of 4" %
                       ((bin_used // 3) * 4 + 1))
                raise_Error(space, msg)
            raise_Error(space, "Incorrect padding")

    return space.newbytes(res.build())

# ____________________________________________________________

table_b2a_base64 = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

@unwrap_spec(bin='bufferstr', newline=bool)
def b2a_base64(space, bin, __kwonly__, newline=True):
    "Base64-code line of data."

    newlength = (len(bin) + 2) // 3
    try:
        newlength = ovfcheck(newlength * 4)
    except OverflowError:
        raise OperationError(space.w_MemoryError, space.w_None)
    newlength += 1
    res = StringBuilder(newlength)

    leftchar = 0
    leftbits = 0
    for c in bin:
        # Shift into our buffer, and output any 6bits ready
        leftchar = (leftchar << 8) | ord(c)
        leftbits += 8
        res.append(table_b2a_base64[(leftchar >> (leftbits-6)) & 0x3f])
        leftbits -= 6
        if leftbits >= 6:
            res.append(table_b2a_base64[(leftchar >> (leftbits-6)) & 0x3f])
            leftbits -= 6
    #
    if leftbits == 2:
        res.append(table_b2a_base64[(leftchar & 3) << 4])
        res.append(PAD)
        res.append(PAD)
    elif leftbits == 4:
        res.append(table_b2a_base64[(leftchar & 0xf) << 2])
        res.append(PAD)
    if newline:
        res.append('\n')
    return space.newbytes(res.build())
