from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import objectmodel, unroll
from rpython.rlib.rarithmetic import r_uint, intmask, LONG_BIT
from rpython.jit.backend.detect_cpu import autodetect, ProcessorAutodetectError

# accelerators for string operations using simd on regular word sizes (*not*
# SSE instructions). this style is sometimes called SWAR (SIMD Within A
# Register) or "broadword techniques"

# XXX remove wordsize and endianness restrictions properly, so far only x86-64
# is tested

USE_SIMD = False
if LONG_BIT == 64:
    WORD_SIZE = 8
    EVERY_BYTE_ONE = 0x0101010101010101
    EVERY_BYTE_HIGHEST_BIT = 0x8080808080808080
    try:
        if autodetect() == "x86-64":
            USE_SIMD = True
    except ProcessorAutodetectError:
        pass
else:
    WORD_SIZE = 4
    EVERY_BYTE_ONE = 0x01010101
    EVERY_BYTE_HIGHEST_BIT = 0x80808080


# helpers

unrolling_wordsize = unroll.unrolling_iterable(range(WORD_SIZE))

def char_repeated_word_width(ch):
    return r_uint(EVERY_BYTE_ONE) * ord(ch)

def any_char_zero(word):
    return (word - r_uint(EVERY_BYTE_ONE)) & ~word & r_uint(EVERY_BYTE_HIGHEST_BIT)

def any_char_in_words_zero(*words):
    return _any_char_in_any_word_zero_accum(0, *words)

def _any_char_in_any_word_zero_accum(accum, word, *words):
    accum |= (word - r_uint(EVERY_BYTE_ONE)) & ~word
    if not words:
        return accum & r_uint(EVERY_BYTE_HIGHEST_BIT)
    return _any_char_in_any_word_zero_accum(accum, *words)

def print_chars(word):
    # for debugging
    out = ''
    for i in range(WORD_SIZE):
        out += chr(word & 0xff)
        word >>= 8
    return out

def index_nonzero(word):
    # XXX can be done very cheap in theory
    assert word
    for i in unrolling_wordsize:
        if word & 0xff:
            return i
        word >>= 8
    assert 0

def index_zero(word):
    # XXX can be done very cheap in theory
    assert any_char_zero(word)
    for i in unrolling_wordsize:
        if not word & 0xff:
            return i
        word >>= 8
    assert 0 # XXX ???

def set_high_bytes_to_zero(word, keep_bytes):
    mask = ((~r_uint(0)) << (8 * keep_bytes))
    return word & ~mask



@objectmodel.always_inline
def position_string_ender(word):
    maskquote = char_repeated_word_width('"')
    maskbackslash = char_repeated_word_width('\\')
    maskx20 = char_repeated_word_width(chr(0xff - 0x1f))
    # x1 and x2 check for equality, if a byte is 0 the corresponding
    # char is equal to " or \
    x1 = maskquote ^ word
    x2 = maskbackslash ^ word
    # x3 checks for char < 0x20, the byte is 0 in that case
    x3 = maskx20 & word
    return any_char_in_words_zero(x1, x2, x3)

@objectmodel.always_inline
def find_end_of_string_simd_unaligned(ll_chars, startpos, length):
    ch = ll_chars[startpos]
    strhash = (ord(ch) << 7) ^ 0x345678

    wordarray = rffi.cast(rffi.UNSIGNEDP, rffi.ptradd(ll_chars, startpos))
    num_safe_reads = (length - startpos) // WORD_SIZE

    bits = 0
    for i in range(num_safe_reads):
        word = wordarray[i]
        cond = position_string_ender(word)
        if cond:
            break
        bits |= word
        strhash = intmask((1000003 * strhash) ^ intmask(word))
    else:
        # didn't find end of string yet, look at remaining chars
        word = 0
        shift = 0
        i = startpos + num_safe_reads * WORD_SIZE
        while True:   # this loop should run at most WORD_SIZE times,
                      # if we assume that ll_chars[length] == '\x00'
            ch = ll_chars[i]
            if ch == '"' or ch == '\\' or ch < '\x20':
                break
            i += 1
            bits |= ord(ch)
            word |= ord(ch) << shift
            shift += 8
        if shift:
            strhash = intmask((1000003 * strhash) ^ intmask(word))

        nonascii = bool(bits & char_repeated_word_width(chr(0x80)))
        return strhash, nonascii, i

    # compute endposition
    nonzero = index_nonzero(cond)
    endposition = startpos + i * WORD_SIZE + nonzero
    if nonzero:
        word = set_high_bytes_to_zero(word, nonzero)
        bits |= word
        strhash = intmask((1000003 * strhash) ^ intmask(word))

    nonascii = bool(bits & char_repeated_word_width(chr(0x80)))

    return strhash, nonascii, endposition

@objectmodel.always_inline
def find_end_of_string_simd_unaligned_no_hash(ll_chars, startpos, length):
    ch = ll_chars[startpos]

    wordarray = rffi.cast(rffi.UNSIGNEDP, rffi.ptradd(ll_chars, startpos))
    num_safe_reads = (length - startpos) // WORD_SIZE

    bits = 0
    for i in range(num_safe_reads):
        word = wordarray[i]
        cond = position_string_ender(word)
        if cond:
            break
        bits |= word
    else:
        # didn't find end of string yet, look at remaining chars
        i = startpos + num_safe_reads * WORD_SIZE
        while True:   # this loop should run at most WORD_SIZE times,
                      # if we assume that ll_chars[length] == '\x00'
            ch = ll_chars[i]
            if ch == '"' or ch == '\\' or ch < '\x20':
                break
            i += 1
            bits |= ord(ch)

        nonascii = bool(bits & char_repeated_word_width(chr(0x80)))
        return nonascii, i

    # compute endposition
    nonzero = index_nonzero(cond)
    endposition = startpos + i * WORD_SIZE + nonzero
    if nonzero:
        word = set_high_bytes_to_zero(word, nonzero)
        bits |= word

    nonascii = bool(bits & char_repeated_word_width(chr(0x80)))

    return nonascii, endposition


@objectmodel.always_inline
def find_end_of_string_slow(ll_chars, i, length):
    ch = ll_chars[i]
    strhash = (ord(ch) << 7) ^ 0x345678
    word = 0
    shift = 0

    bits = 0

    while True:
        # this loop is a fast path for strings which do not contain escape
        # characters
        ch = ll_chars[i]
        if ch == '"' or ch == '\\' or ch < '\x20':
            break
        i += 1
        bits |= ord(ch)

        word |= ord(ch) << shift
        shift += 8
        if shift == WORD_SIZE * 8:
            strhash = intmask((1000003 * strhash) ^ word)
            shift = 0
            word = 0

    if shift:
        strhash = intmask((1000003 * strhash) ^ word)
    return strhash, bool(bits & 0x80), i

@objectmodel.always_inline
def find_end_of_string_slow_no_hash(ll_chars, i, length):
    bits = 0
    while True:
        # this loop is a fast path for strings which do not contain escape
        # characters
        ch = ll_chars[i]
        if ch == '"' or ch == '\\' or ch < '\x20':
            break
        i += 1
        bits |= ord(ch)
    return bool(bits & 0x80), i

if USE_SIMD:
    find_end_of_string = find_end_of_string_simd_unaligned
    find_end_of_string_no_hash = find_end_of_string_simd_unaligned_no_hash
else:
    find_end_of_string = find_end_of_string_slow
    find_end_of_string_no_hash = find_end_of_string_slow_no_hash
