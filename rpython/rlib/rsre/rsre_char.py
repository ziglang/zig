"""
Character categories and charsets.
"""
import sys
from rpython.rlib.rlocale import tolower, toupper, isalnum
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib import jit
from rpython.rlib.rarithmetic import int_between
from rpython.rlib.rsre import rsre_constants as consts

# Note: the unicode parts of this module require you to call
# rsre_char.set_unicode_db() first, to select one of the modules
# pypy.module.unicodedata.unicodedb_x_y_z.  This allows PyPy to use sre
# with the same version of the unicodedb as it uses for
# unicodeobject.py.  If unset, the RPython program cannot use unicode
# matching.

unicodedb = None       # possibly patched by set_unicode_db()

def set_unicode_db(newunicodedb):
    # check the validity of the following optimization for the given unicodedb:
    # for all ascii chars c, getlower(c)/getupper(c) behaves like on ascii
    # (very unlikely to change, but who knows)
    if newunicodedb is not None:
        for i in range(128):
            assert newunicodedb.tolower(i) == getlower_ascii(i)
            assert newunicodedb.toupper(i) == getupper_ascii(i)
            assert newunicodedb.toupper_full(i) == [getupper_ascii(i)]
    global unicodedb
    unicodedb = newunicodedb


#### Constants

if sys.maxint > 2**32:
    MAXREPEAT = int(2**32 - 1)
    MAXGROUPS = int(2**31 - 1)
else:
    MAXREPEAT = int(2**31 - 1)
    MAXGROUPS = int(2**30 - 1)

# In _sre.c this is bytesize of the code word type of the C implementation.
# There it's 2 for normal Python builds and more for wide unicode builds (large
# enough to hold a 32-bit UCS-4 encoded character). Since here in pure Python
# we only see re bytecodes as Python longs, we shouldn't have to care about the
# codesize. But sre_compile will compile some stuff differently depending on the
# codesize (e.g., charsets).
from rpython.rlib.runicode import MAXUNICODE
if MAXUNICODE == 65535 and not consts.V37:
    CODESIZE = 2
else:
    CODESIZE = 4        # always 4 from py3.7

copyright = "_sre.py 2.4 Copyright 2005 by Nik Haldimann"

BIG_ENDIAN = sys.byteorder == "big"

def getlower_ascii(char_ord):
    return char_ord + int_between(ord('A'), char_ord, ord('Z') + 1) * (ord('a') - ord('A'))

def getlower_locale(char_ord):
    if char_ord < 256:      # cheating!  Well, CPython does too.
        char_ord = tolower(char_ord)
    return char_ord

def getlower_unicode(char_ord):
    if char_ord < 128: # shortcut for ascii
        return getlower_ascii(char_ord)
    assert unicodedb is not None
    return unicodedb.tolower(char_ord)

def getlower(char_ord, flags):
    if flags & consts.SRE_FLAG_LOCALE:
        char_ord = getlower_locale(char_ord)
    elif flags & consts.SRE_FLAG_UNICODE:
        char_ord = getlower_unicode(char_ord)
    else:
        char_ord = getlower_ascii(char_ord)
    return char_ord

def getupper_ascii(char_ord):
    return char_ord - int_between(ord('a'), char_ord, ord('z') + 1) * (ord('a') - ord('A'))

def getupper_locale(char_ord):
    if char_ord < 256:      # cheating!  Well, CPython does too.
        char_ord = toupper(char_ord)
    return char_ord

def getupper_unicode(char_ord):
    if char_ord < 128: # shortcut for ascii
        return getupper_ascii(char_ord)
    # Note: this is like CPython's sre_upper_unicode(), including for a few
    # arguments like 0xfb05, whose uppercase is *several letters* in unicode.
    # We return the first of these letters.  That's rather random but no
    # caller expects a sane result in this case, I think: iscased_unicode()
    # is fine as long as it returns anything != char_ord in this case.
    assert unicodedb is not None
    return unicodedb.toupper_full(char_ord)[0]

def getupper(char_ord, flags):
    if flags & consts.SRE_FLAG_LOCALE:
        char_ord = getupper_locale(char_ord)
    elif flags & consts.SRE_FLAG_UNICODE:
        char_ord = getupper_unicode(char_ord)
    else:
        char_ord = getupper_ascii(char_ord)
    return char_ord

def iscased_ascii(char_ord):   # used by py3.7
    upper = int_between(ord('A'), char_ord, ord('Z')+1)
    lower = int_between(ord('a'), char_ord, ord('z')+1)
    return upper | lower

def iscased_unicode(char_ord):   # used by py3.7
    # NOTE: this is not unicodedb.iscased().  As per CPython 3.7, it is
    # something different which---as far as I can tell---doesn't really
    # have a meaning on its own, but well.
    return (char_ord != getlower_unicode(char_ord) or
            char_ord != getupper_unicode(char_ord))

#### Category helpers

is_a_word = [(chr(i).isalnum() or chr(i) == '_') for i in range(256)]
linebreak = ord("\n")
underline = ord("_")

def is_digit(code):
    return int_between(48, code, 58)

def is_uni_digit(code):
    assert unicodedb is not None
    return unicodedb.isdecimal(code)

def is_space(code):
    return (code == 32) | int_between(9, code, 14)

def is_uni_space(code):
    assert unicodedb is not None
    return unicodedb.isspace(code)

def is_word(code):
    assert code >= 0
    return code < 256 and is_a_word[code]

def is_uni_word(code):
    assert unicodedb is not None
    return unicodedb.isalnum(code) or code == underline

def is_loc_alnum(code):
    return code < 256 and isalnum(code)

def is_loc_word(code):
    return code == underline or is_loc_alnum(code)

def is_linebreak(code):
    return code == linebreak

def is_uni_linebreak(code):
    assert unicodedb is not None
    return unicodedb.islinebreak(code)


#### Category dispatch

def category_dispatch(category_code, char_code):
    for i, (function, negate) in category_dispatch_unroll:
        if category_code == i:
            result = function(char_code)
            if negate:
                return not result # XXX this might lead to a guard
            else:
                return result
    else:
        return False


# Maps opcodes to (function, negate) tuples.
category_dispatch_table = {
    consts.CATEGORY_DIGIT: (is_digit, False),
    consts.CATEGORY_NOT_DIGIT: (is_digit, True),
    consts.CATEGORY_SPACE: (is_space, False),
    consts.CATEGORY_NOT_SPACE: (is_space, True),
    consts.CATEGORY_WORD: (is_word, False),
    consts.CATEGORY_NOT_WORD: (is_word, True),
    consts.CATEGORY_LINEBREAK: (is_linebreak, False),
    consts.CATEGORY_NOT_LINEBREAK: (is_linebreak, True),
    consts.CATEGORY_LOC_WORD: (is_loc_word, False),
    consts.CATEGORY_LOC_NOT_WORD: (is_loc_word, True),
    consts.CATEGORY_UNI_DIGIT: (is_uni_digit, False), 
    consts.CATEGORY_UNI_NOT_DIGIT: (is_uni_digit, True),
    consts.CATEGORY_UNI_SPACE: (is_uni_space, False), 
    consts.CATEGORY_UNI_NOT_SPACE: (is_uni_space, True), 
    consts.CATEGORY_UNI_WORD: (is_uni_word, False),
    consts.CATEGORY_UNI_NOT_WORD: (is_uni_word, True),
    consts.CATEGORY_UNI_LINEBREAK: (is_uni_linebreak, False),
    consts.CATEGORY_UNI_NOT_LINEBREAK: (is_uni_linebreak, True),
    }
category_dispatch_unroll = unrolling_iterable(sorted(category_dispatch_table.items()))

##### Charset evaluation

@jit.unroll_safe
def check_charset(ctx, pattern, ppos, char_code):
    """Checks whether a character matches set of arbitrary length.
    The set starts at pattern[ppos]."""
    negated = False
    result = False
    while True:
        opcode = pattern.pattern[ppos]
        for i, function in set_dispatch_unroll:
            if opcode == i:
                newresult, ppos = function(ctx, pattern, ppos, char_code)
                result |= newresult
                break
        else:
            if opcode == consts.OPCODE_FAILURE:
                break
            elif opcode == consts.OPCODE_NEGATE:
                negated ^= True
                ppos += 1
            else:
                return False
    if negated:
        return not result
    return result

def set_literal(ctx, pattern, index, char_code):
    # <LITERAL> <code>
    match = pattern.pattern[index+1] == char_code
    return match, index + 2

def set_category(ctx, pattern, index, char_code):
    # <CATEGORY> <code>
    match = category_dispatch(pattern.pattern[index+1], char_code)
    return match, index + 2

def set_charset(ctx, pattern, index, char_code):
    # <CHARSET> <bitmap> (16 bits per code word)
    if CODESIZE == 2:
        match = char_code < 256 and \
                (pattern.pattern[index+1+(char_code >> 4)] & (1 << (char_code & 15)))
        return match, index + 17  # skip bitmap
    else:
        match = char_code < 256 and \
                (pattern.pattern[index+1+(char_code >> 5)] & (1 << (char_code & 31)))
        return match, index + 9   # skip bitmap

def set_range(ctx, pattern, index, char_code):
    # <RANGE> <lower> <upper>
    match = int_between(pattern.pattern[index+1], char_code, pattern.pattern[index+2] + 1)
    return match, index + 3

def set_range_ignore(ctx, pattern, index, char_code):
    # <RANGE_IGNORE> <lower> <upper>
    # the char_code is already lower cased
    assert not consts.V37
    lower = pattern.pattern[index + 1]
    upper = pattern.pattern[index + 2]
    match1 = int_between(lower, char_code, upper + 1)
    match2 = int_between(lower, getupper(char_code, pattern.flags), upper + 1)
    return match1 | match2, index + 3

def set_range_uni_ignore(ctx, pattern, index, char_code):
    # <RANGE_UNI_IGNORE> <lower> <upper>
    # the char_code is already lower cased
    lower = pattern.pattern[index + 1]
    upper = pattern.pattern[index + 2]
    match1 = int_between(lower, char_code, upper + 1)
    match2 = int_between(lower, getupper_unicode(char_code), upper + 1)
    return match1 | match2, index + 3

def set_bigcharset(ctx, pattern, index, char_code):
    # <BIGCHARSET> <blockcount> <256 blockindices> <blocks>
    count = pattern.pattern[index+1]
    index += 2

    if CODESIZE == 2:
        # One bytecode is 2 bytes, so contains 2 of the blockindices.
        # So the 256 blockindices are packed in 128 bytecodes, but
        # we need to unpack it as a byte.
        assert char_code < 65536
        shift = 4
    else:
        # One bytecode is 4 bytes, so contains 4 of the blockindices.
        # So the 256 blockindices are packed in 64 bytecodes, but
        # we need to unpack it as a byte.
        if char_code >= 65536:
            index += 256 / CODESIZE + count * (32 / CODESIZE)
            return False, index
        shift = 5

    block = pattern.pattern[index + (char_code >> (shift + 5))]

    block_shift = char_code >> 5
    if BIG_ENDIAN:
        block_shift = ~block_shift
    block_shift &= (CODESIZE - 1) * 8
    block = (block >> block_shift) & 0xFF

    index += 256 / CODESIZE
    block_value = pattern.pattern[index+(block * (32 / CODESIZE)
                             + ((char_code & 255) >> shift))]
    match = (block_value & (1 << (char_code & ((8 * CODESIZE) - 1))))
    index += count * (32 / CODESIZE)  # skip blocks
    return match, index

def set_unicode_general_category(ctx, pattern, index, char_code):
    # Unicode "General category property code" (not used by Python).
    # A general category is two letters.  'pattern.pattern[index+1]' contains both
    # the first character, and the second character shifted by 8.
    # http://en.wikipedia.org/wiki/Unicode_character_property#General_Category
    # Also supports single-character categories, if the second character is 0.
    # Negative matches are triggered by bit number 7.
    assert unicodedb is not None
    cat = unicodedb.category(char_code)
    category_code = pattern.pattern[index + 1]
    first_character = category_code & 0x7F
    second_character = (category_code >> 8) & 0x7F
    negative_match = category_code & 0x80
    #
    if second_character == 0:
        # single-character match
        check = ord(cat[0])
        expected = first_character
    else:
        # two-characters match
        check = ord(cat[0]) | (ord(cat[1]) << 8)
        expected = first_character | (second_character << 8)
    #
    if negative_match:
        result = check != expected
    else:
        result = check == expected
    #
    return result, index + 2

set_dispatch_table = {
    consts.OPCODE_CATEGORY: set_category,
    consts.OPCODE_CHARSET: set_charset,
    consts.OPCODE_BIGCHARSET: set_bigcharset,
    consts.OPCODE_LITERAL: set_literal,
    consts.OPCODE_RANGE: set_range,
    consts.OPCODE27_RANGE_IGNORE: set_range_ignore,
    consts.OPCODE37_RANGE_UNI_IGNORE: set_range_uni_ignore,
    consts.OPCODE_UNICODE_GENERAL_CATEGORY: set_unicode_general_category,
}
set_dispatch_table.pop(None, None)   # remove the OPCODE27_* or OPCODE37_*
set_dispatch_unroll = unrolling_iterable(sorted(set_dispatch_table.items()))
