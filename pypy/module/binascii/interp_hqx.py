from pypy.interpreter.error import OperationError
from pypy.interpreter.gateway import unwrap_spec
from rpython.rlib.rstring import StringBuilder
from pypy.module.binascii.interp_binascii import raise_Error, raise_Incomplete
from pypy.module.binascii.interp_binascii import AsciiBufferUnwrapper
from rpython.rlib.rarithmetic import ovfcheck

# ____________________________________________________________

DONE = 0x7f
SKIP = 0x7e
FAIL = 0x7d

table_a2b_hqx = [
    #^@    ^A    ^B    ^C    ^D    ^E    ^F    ^G
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    #\b    \t    \n    ^K    ^L    \r    ^N    ^O
    FAIL, FAIL, SKIP, FAIL, FAIL, SKIP, FAIL, FAIL,
    #^P    ^Q    ^R    ^S    ^T    ^U    ^V    ^W
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    #^X    ^Y    ^Z    ^[    ^\    ^]    ^^    ^_
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    #      !     "     #     $     %     &     '
    FAIL, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
    #(     )     *     +     ,     -     .     /
    0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, FAIL, FAIL,
    #0     1     2     3     4     5     6     7
    0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, FAIL,
    #8     9     :     ;     <     =     >     ?
    0x14, 0x15, DONE, FAIL, FAIL, FAIL, FAIL, FAIL,
    #@     A     B     C     D     E     F     G
    0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D,
    #H     I     J     K     L     M     N     O
    0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, FAIL,
    #P     Q     R     S     T     U     V     W
    0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, FAIL,
    #X     Y     Z     [     \     ]     ^     _
    0x2C, 0x2D, 0x2E, 0x2F, FAIL, FAIL, FAIL, FAIL,
    #`     a     b     c     d     e     f     g
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, FAIL,
    #h     i     j     k     l     m     n     o
    0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, FAIL, FAIL,
    #p     q     r     s     t     u     v     w
    0x3D, 0x3E, 0x3F, FAIL, FAIL, FAIL, FAIL, FAIL,
    #x     y     z     {     |     }     ~    ^?
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
    FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL, FAIL,
]
table_a2b_hqx = ''.join(map(chr, table_a2b_hqx))

@unwrap_spec(ascii=AsciiBufferUnwrapper)
def a2b_hqx(space, ascii):
    """Decode .hqx coding.  Returns (bin, done)."""

    space.warn(
        space.newtext("binascii.a2b_hqx() is deprecated"),
        space.w_DeprecationWarning,
    ) 
    # overestimate the resulting length
    res = StringBuilder(len(ascii))
    done = 0
    pending_value = 0
    pending_bits = 0

    for c in ascii:
        n = ord(table_a2b_hqx[ord(c)])
        if n <= 0x3F:
            pending_value = (pending_value << 6) | n
            pending_bits += 6
            if pending_bits == 24:
                # flush
                res.append(chr(pending_value >> 16))
                res.append(chr((pending_value >> 8) & 0xff))
                res.append(chr(pending_value & 0xff))
                pending_value = 0
                pending_bits = 0
        elif n == FAIL:
            raise_Error(space, 'Illegal character')
        elif n == DONE:
            if pending_bits >= 8:
                res.append(chr(pending_value >> (pending_bits - 8)))
            if pending_bits >= 16:
                res.append(chr((pending_value >> (pending_bits - 16)) & 0xff))
            done = 1
            break
        #elif n == SKIP: pass
    else:
        if pending_bits > 0:
            raise_Incomplete(space, 'String has incomplete number of bytes')
    return space.newtuple([space.newbytes(res.build()), space.newint(done)])

# ____________________________________________________________

hqx_encoding = (
    '!"#$%&\'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr')

@unwrap_spec(bin='bufferstr')
def b2a_hqx(space, bin):
    "Encode .hqx data."
    space.warn(space.newtext("binascii.b2a_hqx() is deprecated"), space.w_DeprecationWarning)
    extra = (len(bin) + 2) // 3
    try:
        newlength = ovfcheck(len(bin) + extra)
    except OverflowError:
        raise OperationError(space.w_MemoryError, space.w_None)
    res = StringBuilder(newlength)
    leftchar = 0
    leftbits = 0
    for c in bin:
        # Shift into our buffer, and output any 6bits ready
        leftchar = (leftchar << 8) | ord(c)
        leftbits += 8
        res.append(hqx_encoding[(leftchar >> (leftbits-6)) & 0x3f])
        leftbits -= 6
        if leftbits >= 6:
            res.append(hqx_encoding[(leftchar >> (leftbits-6)) & 0x3f])
            leftbits -= 6
    # Output a possible runt byte
    if leftbits > 0:
        leftchar <<= (6 - leftbits)
        res.append(hqx_encoding[leftchar & 0x3f])
    return space.newbytes(res.build())

# ____________________________________________________________

@unwrap_spec(hexbin='bufferstr')
def rledecode_hqx(space, hexbin):
    "Decode hexbin RLE-coded string."
    space.warn(
        space.newtext("binascii.rledecode_hqx() is deprecated"),
        space.w_DeprecationWarning,
    ) 

    # that's a guesstimation of the resulting length
    res = StringBuilder(len(hexbin))

    end = len(hexbin)
    i = 0
    lastpushed = -1
    while i < end:
        c = hexbin[i]
        i += 1
        if c != '\x90':
            res.append(c)
            lastpushed = ord(c)
        else:
            if i == end:
                raise_Incomplete(space, 'String ends with the RLE code \\x90')
            count = ord(hexbin[i]) - 1
            i += 1
            if count < 0:
                res.append('\x90')
                lastpushed = 0x90
            else:
                if lastpushed < 0:
                    raise_Error(space, 'String starts with the RLE code \\x90')
                res.append_multiple_char(chr(lastpushed), count)
    return space.newbytes(res.build())

# ____________________________________________________________

@unwrap_spec(data='bufferstr')
def rlecode_hqx(space, data):
    "Binhex RLE-code binary data."

    space.warn(
        space.newtext("binascii.rlecode_hqx() is deprecated"),
        space.w_DeprecationWarning,
    ) 
    # that's a guesstimation of the resulting length
    res = StringBuilder(len(data))

    i = 0
    end = len(data)
    while i < end:
        c = data[i]
        res.append(c)
        if c == '\x90':
            # Escape it, and ignore repetitions (*).
            res.append('\x00')
        else:
            # Check how many following are the same
            inend = i + 1
            while inend < end and data[inend] == c and inend < i + 255:
                inend += 1
            if inend - i > 3:
                # More than 3 in a row. Output RLE.  For the case of more
                # than 255, see (*) below.
                res.append('\x90')
                res.append(chr(inend - i))
                i = inend
                continue
        i += 1
    # (*) Note that we put simplicity before compatness here, like CPython.
    # I am sure that if we tried harder to produce the smallest possible
    # string that rledecode_hqx() would expand back to 'data', there are
    # some programs somewhere that would start failing obscurely in rare
    # cases.
    return space.newbytes(res.build())

# ____________________________________________________________

crctab_hqx = [
        0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
        0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
        0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
        0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
        0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
        0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
        0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
        0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
        0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
        0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
        0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
        0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
        0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
        0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
        0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
        0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
        0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
        0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
        0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
        0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
        0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
        0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
        0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
        0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
        0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
        0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
        0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
        0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
        0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
        0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
        0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
        0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0,
]

@unwrap_spec(data='bufferstr')
def crc_hqx(space, data, w_oldcrc):
    "Compute CRC-CCIT incrementally."

    # CPython converts the oldcrc argument to unsigned long, without overflow
    # checking. we do the mask with wrapped objects, to deal with huge
    # arguments
    crc = space.int_w(space.and_(w_oldcrc, space.newint(0xffff)))
    for c in data:
        crc = ((crc << 8) & 0xff00) ^ crctab_hqx[((crc >> 8) & 0xff) ^ ord(c)]
    return space.newint(crc)
