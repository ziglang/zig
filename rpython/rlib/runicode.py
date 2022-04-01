import sys
from rpython.rlib.objectmodel import specialize, we_are_translated, enforceargs
from rpython.rlib.rstring import StringBuilder, UnicodeBuilder
from rpython.rlib.rarithmetic import r_uint, intmask, widen
from rpython.rlib.unicodedata import unicodedb
from rpython.tool.sourcetools import func_with_new_name
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import jit, nonconst


# We always use MAXUNICODE = 0x10ffff when unicode objects use utf8,
# which is now the default for rpython
if 1 or rffi.sizeof(lltype.UniChar) == 4:
    MAXUNICODE = 0x10ffff
    allow_surrogate_by_default = False
else:
    MAXUNICODE = 0xffff
    allow_surrogate_by_default = True

BYTEORDER = sys.byteorder
BYTEORDER2 = BYTEORDER[0] + 'e'      # either "le" or "be"
assert BYTEORDER2 in ('le', 'be')

# python 2.7 has a preview of py3k behavior, so those functions
# are used either when we're testing wide pypy on narrow cpython
# or in unicodedata in pypy

def unichr_returns_surrogate(c):
    if c <= 0xffff or c > 0x10ffff:
        return unichr(c)
    else:
        c -= 0x10000
        return (unichr(0xD800 + (c >> 10)) +
                unichr(0xDC00 + (c & 0x03FF)))

def ord_accepts_surrogate(u):
    if isinstance(u, unicode) and len(u) == 2:
        ch1 = ord(u[0])
        ch2 = ord(u[1])
        if 0xD800 <= ch1 <= 0xDBFF and 0xDC00 <= ch2 <= 0xDFFF:
            return (((ch1 - 0xD800) << 10) | (ch2 - 0xDC00)) + 0x10000
    if not we_are_translated():
        return ord(u)
    else:
        if len(u) == 1:
            return ord(u[0])
        raise TypeError

if MAXUNICODE > sys.maxunicode:
    # A version of unichr which allows codes outside the BMP
    # even on narrow unicode builds.
    # It will be used when interpreting code on top of a UCS2 CPython,
    # when sizeof(wchar_t) == 4.
    # Note that Python3 uses a similar implementation.
    def UNICHR(c):
        assert not we_are_translated()
        return unichr_returns_surrogate(c)
    UNICHR._flowspace_rewrite_directly_as_ = unichr
    # ^^^ NB.: for translation, it's essential to use this hack instead
    # of calling unichr() from UNICHR(), because unichr() detects if there
    # is a "try:except ValueError" immediately around it.

    def ORD(u):
        assert not we_are_translated()
        return ord_accepts_surrogate(u)
    ORD._flowspace_rewrite_directly_as_ = ord

else:
    UNICHR = unichr
    ORD = ord

if MAXUNICODE > 0xFFFF:
    def code_to_unichr(code):
        if is_narrow_host():
            # Host CPython is narrow build, generate surrogates
            return unichr_returns_surrogate(code)
        else:
            return unichr(code)
else:
    def code_to_unichr(code):
        # generate surrogates for large codes
        return unichr_returns_surrogate(widen(code))

def _STORECHAR(result, CH, byteorder):
    hi = chr(((CH) >> 8) & 0xff)
    lo = chr((CH) & 0xff)
    if byteorder == 'little':
        result.append(lo)
        result.append(hi)
    else:
        result.append(hi)
        result.append(lo)

def is_narrow_host():
    return not we_are_translated() and sys.maxunicode == 0xFFFF

def default_unicode_error_decode(errors, encoding, msg, s,
                                 startingpos, endingpos):
    assert endingpos >= 0
    if errors == 'replace':
        return u'\ufffd', endingpos
    if errors == 'ignore':
        return u'', endingpos
    raise UnicodeDecodeError(encoding, s, startingpos, endingpos, msg)

def default_unicode_error_encode(errors, encoding, msg, u,
                                 startingpos, endingpos):
    assert endingpos >= 0
    if errors == 'replace':
        return u'?', None, endingpos
    if errors == 'ignore':
        return u'', None, endingpos
    raise UnicodeEncodeError(encoding, u, startingpos, endingpos, msg)

# ____________________________________________________________
# utf-8

_utf8_code_length = ''.join(map(chr, [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, # 80-8F
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, # B0-BF
    0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, # C0-C1 + C2-CF
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, # D0-DF
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, # E0-EF
    4, 4, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  # F0-F4 - F5-FF
]))

# if you can't use the @elidable version, call str_decode_utf_8_impl()
# directly
@jit.elidable
def str_decode_utf_8(s, size, errors, final=False,
                     errorhandler=None, allow_surrogates=allow_surrogate_by_default):
    if errorhandler is None:
        errorhandler = default_unicode_error_decode
    return str_decode_utf_8_elidable(s, size, errors, final, errorhandler,
                                     allow_surrogates=allow_surrogates)

def _invalid_cont_byte(ordch):
    return ordch>>6 != 0x2    # 0b10

_invalid_byte_2_of_2 = _invalid_cont_byte
_invalid_byte_3_of_3 = _invalid_cont_byte
_invalid_byte_3_of_4 = _invalid_cont_byte
_invalid_byte_4_of_4 = _invalid_cont_byte

@enforceargs(allow_surrogates=bool)
def _invalid_byte_2_of_3(ordch1, ordch2, allow_surrogates):
    return (ordch2>>6 != 0x2 or    # 0b10
            (ordch1 == 0xe0 and ordch2 < 0xa0)
            # surrogates shouldn't be valid UTF-8!
            or (ordch1 == 0xed and ordch2 > 0x9f and not allow_surrogates))

def _invalid_byte_2_of_4(ordch1, ordch2):
    return (ordch2>>6 != 0x2 or    # 0b10
            (ordch1 == 0xf0 and ordch2 < 0x90) or
            (ordch1 == 0xf4 and ordch2 > 0x8f))

# NOTE: this is a slightly fixed algorithm when compared with
# CPython2's.  It is closer to CPython3's.  See comments in
# test_invalid_cb_for_3bytes_seq().
def str_decode_utf_8_impl(s, size, errors, final, errorhandler,
                          allow_surrogates):
    if size == 0:
        return u'', 0

    result = UnicodeBuilder(size)
    pos = 0
    while pos < size:
        ordch1 = ord(s[pos])
        # fast path for ASCII
        # XXX maybe use a while loop here
        if ordch1 < 0x80:
            result.append(unichr(ordch1))
            pos += 1
            continue

        n = ord(_utf8_code_length[ordch1 - 0x80])
        if pos + n > size:
            if not final:
                break
            # argh, this obscure block of code is mostly a copy of
            # what follows :-(
            charsleft = size - pos - 1 # either 0, 1, 2
            # note: when we get the 'unexpected end of data' we need
            # to care about the pos returned; it can be lower than size,
            # in case we need to continue running this loop
            if not charsleft:
                # there's only the start byte and nothing else
                r, pos = errorhandler(errors, 'utf8',
                                      'unexpected end of data',
                                      s, pos, pos+1)
                result.append(r)
                continue
            ordch2 = ord(s[pos+1])
            if n == 3:
                # 3-bytes seq with only a continuation byte
                if _invalid_byte_2_of_3(ordch1, ordch2, allow_surrogates):
                    # second byte invalid, take the first and continue
                    r, pos = errorhandler(errors, 'utf8',
                                          'invalid continuation byte',
                                          s, pos, pos+1)
                    result.append(r)
                    continue
                else:
                    # second byte valid, but third byte missing
                    r, pos = errorhandler(errors, 'utf8',
                                      'unexpected end of data',
                                      s, pos, pos+2)
                    result.append(r)
                    continue
            elif n == 4:
                # 4-bytes seq with 1 or 2 continuation bytes
                if _invalid_byte_2_of_4(ordch1, ordch2):
                    # second byte invalid, take the first and continue
                    r, pos = errorhandler(errors, 'utf8',
                                          'invalid continuation byte',
                                          s, pos, pos+1)
                    result.append(r)
                    continue
                elif charsleft == 2 and _invalid_byte_3_of_4(ord(s[pos+2])):
                    # third byte invalid, take the first two and continue
                    r, pos = errorhandler(errors, 'utf8',
                                          'invalid continuation byte',
                                          s, pos, pos+2)
                    result.append(r)
                    continue
                else:
                    # there's only 1 or 2 valid cb, but the others are missing
                    r, pos = errorhandler(errors, 'utf8',
                                      'unexpected end of data',
                                      s, pos, pos+charsleft+1)
                    result.append(r)
                    continue
            raise AssertionError("unreachable")

        if n == 0:
            r, pos = errorhandler(errors, 'utf8',
                                  'invalid start byte',
                                  s, pos, pos+1)
            result.append(r)

        elif n == 1:
            assert 0, "ascii should have gone through the fast path"

        elif n == 2:
            ordch2 = ord(s[pos+1])
            if _invalid_byte_2_of_2(ordch2):
                r, pos = errorhandler(errors, 'utf8',
                                      'invalid continuation byte',
                                      s, pos, pos+1)
                result.append(r)
                continue
            # 110yyyyy 10zzzzzz -> 00000000 00000yyy yyzzzzzz
            result.append(unichr(((ordch1 & 0x1F) << 6) +    # 0b00011111
                                 (ordch2 & 0x3F)))           # 0b00111111
            pos += 2

        elif n == 3:
            ordch2 = ord(s[pos+1])
            ordch3 = ord(s[pos+2])
            if _invalid_byte_2_of_3(ordch1, ordch2, allow_surrogates):
                r, pos = errorhandler(errors, 'utf8',
                                      'invalid continuation byte',
                                      s, pos, pos+1)
                result.append(r)
                continue
            elif _invalid_byte_3_of_3(ordch3):
                r, pos = errorhandler(errors, 'utf8',
                                      'invalid continuation byte',
                                      s, pos, pos+2)
                result.append(r)
                continue
            # 1110xxxx 10yyyyyy 10zzzzzz -> 00000000 xxxxyyyy yyzzzzzz
            result.append(unichr(((ordch1 & 0x0F) << 12) +     # 0b00001111
                                 ((ordch2 & 0x3F) << 6) +      # 0b00111111
                                 (ordch3 & 0x3F)))             # 0b00111111
            pos += 3

        elif n == 4:
            ordch2 = ord(s[pos+1])
            ordch3 = ord(s[pos+2])
            ordch4 = ord(s[pos+3])
            if _invalid_byte_2_of_4(ordch1, ordch2):
                r, pos = errorhandler(errors, 'utf8',
                                      'invalid continuation byte',
                                      s, pos, pos+1)
                result.append(r)
                continue
            elif _invalid_byte_3_of_4(ordch3):
                r, pos = errorhandler(errors, 'utf8',
                                      'invalid continuation byte',
                                      s, pos, pos+2)
                result.append(r)
                continue
            elif _invalid_byte_4_of_4(ordch4):
                r, pos = errorhandler(errors, 'utf8',
                                      'invalid continuation byte',
                                      s, pos, pos+3)
                result.append(r)
                continue
            # 11110www 10xxxxxx 10yyyyyy 10zzzzzz -> 000wwwxx xxxxyyyy yyzzzzzz
            c = (((ordch1 & 0x07) << 18) +      # 0b00000111
                 ((ordch2 & 0x3F) << 12) +      # 0b00111111
                 ((ordch3 & 0x3F) << 6) +       # 0b00111111
                 (ordch4 & 0x3F))               # 0b00111111
            if c <= MAXUNICODE:
                result.append(UNICHR(c))
            else:
                # compute and append the two surrogates:
                # translate from 10000..10FFFF to 0..FFFF
                c -= 0x10000
                # high surrogate = top 10 bits added to D800
                result.append(unichr(0xD800 + (c >> 10)))
                # low surrogate = bottom 10 bits added to DC00
                result.append(unichr(0xDC00 + (c & 0x03FF)))
            pos += 4

    return result.build(), pos
str_decode_utf_8_elidable = jit.elidable(
    func_with_new_name(str_decode_utf_8_impl, "str_decode_utf_8_elidable"))

def _encodeUCS4(result, ch):
    # Encode UCS4 Unicode ordinals
    result.append((chr((0xf0 | (ch >> 18)))))
    result.append((chr((0x80 | ((ch >> 12) & 0x3f)))))
    result.append((chr((0x80 | ((ch >> 6) & 0x3f)))))
    result.append((chr((0x80 | (ch & 0x3f)))))

# if you can't use the @elidable version, call unicode_encode_utf_8_impl()
# directly
@jit.elidable
def unicode_encode_utf_8(s, size, errors, errorhandler=None,
                         allow_surrogates=allow_surrogate_by_default):
    # In this function, allow_surrogates can be:
    #
    #  * True:  surrogates are always allowed.  A valid surrogate pair
    #           is replaced with the non-BMP unicode char it stands for,
    #           which is then encoded as 4 bytes.
    #
    #  * False: surrogates are always forbidden.
    #
    # See also unicode_encode_utf8sp().
    #
    if errorhandler is None:
        errorhandler = default_unicode_error_encode
    return unicode_encode_utf_8_elidable(s, size, errors, errorhandler,
                                         allow_surrogates=allow_surrogates)

def unicode_encode_utf_8_impl(s, size, errors, errorhandler,
                              allow_surrogates=False):
    assert(size >= 0)
    result = StringBuilder(size)
    pos = 0
    while pos < size:
        ch = ord(s[pos])
        pos += 1
        if ch < 0x80:
            # Encode ASCII
            result.append(chr(ch))
        elif ch < 0x0800:
            # Encode Latin-1
            result.append(chr((0xc0 | (ch >> 6))))
            result.append(chr((0x80 | (ch & 0x3f))))
        else:
            # Encode UCS2 Unicode ordinals
            if ch < 0x10000:
                # Special case: check for high surrogate
                if 0xD800 <= ch <= 0xDFFF:
                    if pos != size:
                        ch2 = ord(s[pos])
                        # Check for low surrogate and combine the two to
                        # form a UCS4 value
                        if ((allow_surrogates or MAXUNICODE < 65536
                             or is_narrow_host()) and
                            ch <= 0xDBFF and 0xDC00 <= ch2 <= 0xDFFF):
                            ch3 = ((ch - 0xD800) << 10 | (ch2 - 0xDC00)) + 0x10000
                            assert ch3 >= 0
                            pos += 1
                            _encodeUCS4(result, ch3)
                            continue
                    # note: if the program only ever calls this with
                    # allow_surrogates=True, then we'll never annotate
                    # the following block of code, and errorhandler()
                    # will never be called.  This causes RPython
                    # problems.  Avoid it with the nonconst hack.
                    if not allow_surrogates or nonconst.NonConstant(False):
                        ru, rs, pos = errorhandler(errors, 'utf8',
                                                   'surrogates not allowed',
                                                   s, pos-1, pos)
                        if rs is not None:
                            # py3k only
                            result.append(rs)
                            continue
                        for ch in ru:
                            if ord(ch) < 0x80:
                                result.append(chr(ord(ch)))
                            else:
                                errorhandler('strict', 'utf8',
                                             'surrogates not allowed',
                                             s, pos-1, pos)
                        continue
                    # else: Fall through and handles isolated high surrogates
                result.append((chr((0xe0 | (ch >> 12)))))
                result.append((chr((0x80 | ((ch >> 6) & 0x3f)))))
                result.append((chr((0x80 | (ch & 0x3f)))))
            else:
                _encodeUCS4(result, ch)
    return result.build()
unicode_encode_utf_8_elidable = jit.elidable(
    enforceargs(s=unicode, allow_surrogates=bool)(
    func_with_new_name(unicode_encode_utf_8_impl,
                       "unicode_encode_utf_8_elidable")))

def unicode_encode_utf8sp(s, size):
    # Surrogate-preserving utf-8 encoding.  Any surrogate character
    # turns into its 3-bytes encoding, whether it is paired or not.
    # This should always be reversible, and the reverse is the regular
    # str_decode_utf_8() with allow_surrogates=True.
    assert(size >= 0)
    result = StringBuilder(size)
    pos = 0
    while pos < size:
        ch = ord(s[pos])
        pos += 1
        if ch < 0x80:
            # Encode ASCII
            result.append(chr(ch))
        elif ch < 0x0800:
            # Encode Latin-1
            result.append(chr((0xc0 | (ch >> 6))))
            result.append(chr((0x80 | (ch & 0x3f))))
        elif ch < 0x10000:
            # Encode UCS2 Unicode ordinals, and surrogates
            result.append((chr((0xe0 | (ch >> 12)))))
            result.append((chr((0x80 | ((ch >> 6) & 0x3f)))))
            result.append((chr((0x80 | (ch & 0x3f)))))
        else:
            _encodeUCS4(result, ch)
    return result.build()

class SurrogateError(Exception):
    def __init__(self, char, index):
        self.char = char
        self.index = index

def unicode_encode_utf8_forbid_surrogates(s, size):
    # Strict surrogate-forbidding utf-8 encoding.  Any surrogate character
    # raises an interp-level SurrogateError, even on 16-bit hosts.
    # --- XXX check in detail what occurs on 16-bit hosts in PyPy 3 ---
    assert(size >= 0)
    result = StringBuilder(size)
    pos = 0
    while pos < size:
        ch = ord(s[pos])
        pos += 1
        if ch < 0x80:
            # Encode ASCII
            result.append(chr(ch))
        elif ch < 0x0800:
            # Encode Latin-1
            result.append(chr((0xc0 | (ch >> 6))))
            result.append(chr((0x80 | (ch & 0x3f))))
        elif ch < 0x10000:
            if 0xD800 <= ch <= 0xDFFF:
                raise SurrogateError(ch, pos)
            # Encode UCS2 Unicode ordinals
            result.append((chr((0xe0 | (ch >> 12)))))
            result.append((chr((0x80 | ((ch >> 6) & 0x3f)))))
            result.append((chr((0x80 | (ch & 0x3f)))))
        else:
            _encodeUCS4(result, ch)
    return result.build()

# ____________________________________________________________
# utf-16

def str_decode_utf_16(s, size, errors, final=True,
                      errorhandler=None):
    result, length, byteorder = str_decode_utf_16_helper(s, size, errors, final,
                                                         errorhandler, "native")
    return result, length

def str_decode_utf_16_be(s, size, errors, final=True,
                         errorhandler=None):
    result, length, byteorder = str_decode_utf_16_helper(s, size, errors, final,
                                                         errorhandler, "big")
    return result, length

def str_decode_utf_16_le(s, size, errors, final=True,
                         errorhandler=None):
    result, length, byteorder = str_decode_utf_16_helper(s, size, errors, final,
                                                         errorhandler, "little")
    return result, length

def py3k_str_decode_utf_16(s, size, errors, final=True,
                           errorhandler=None):
    result, length, byteorder = str_decode_utf_16_helper(s, size, errors, final,
                                                         errorhandler, "native",
                                                         'utf-16-' + BYTEORDER2)
    return result, length

def py3k_str_decode_utf_16_be(s, size, errors, final=True,
                              errorhandler=None):
    result, length, byteorder = str_decode_utf_16_helper(s, size, errors, final,
                                                         errorhandler, "big",
                                                         'utf-16-be')
    return result, length

def py3k_str_decode_utf_16_le(s, size, errors, final=True,
                              errorhandler=None):
    result, length, byteorder = str_decode_utf_16_helper(s, size, errors, final,
                                                         errorhandler, "little",
                                                         'utf-16-le')
    return result, length

def str_decode_utf_16_helper(s, size, errors, final=True,
                             errorhandler=None,
                             byteorder="native",
                             public_encoding_name='utf16'):
    if errorhandler is None:
        errorhandler = default_unicode_error_decode
    bo = 0

    if BYTEORDER == 'little':
        ihi = 1
        ilo = 0
    else:
        ihi = 0
        ilo = 1

    #  Check for BOM marks (U+FEFF) in the input and adjust current
    #  byte order setting accordingly. In native mode, the leading BOM
    #  mark is skipped, in all other modes, it is copied to the output
    #  stream as-is (giving a ZWNBSP character).
    pos = 0
    if byteorder == 'native':
        if size >= 2:
            bom = (ord(s[ihi]) << 8) | ord(s[ilo])
            if BYTEORDER == 'little':
                if bom == 0xFEFF:
                    pos += 2
                    bo = -1
                elif bom == 0xFFFE:
                    pos += 2
                    bo = 1
            else:
                if bom == 0xFEFF:
                    pos += 2
                    bo = 1
                elif bom == 0xFFFE:
                    pos += 2
                    bo = -1
    elif byteorder == 'little':
        bo = -1
    else:
        bo = 1
    if size == 0:
        return u'', 0, bo
    if bo == -1:
        # force little endian
        ihi = 1
        ilo = 0

    elif bo == 1:
        # force big endian
        ihi = 0
        ilo = 1

    result = UnicodeBuilder(size // 2)

    #XXX I think the errors are not correctly handled here
    while pos < size:
        # remaining bytes at the end? (size should be even)
        if len(s) - pos < 2:
            if not final:
                break
            r, pos = errorhandler(errors, public_encoding_name,
                                  "truncated data",
                                  s, pos, len(s))
            result.append(r)
            if len(s) - pos < 2:
                break
        ch = (ord(s[pos + ihi]) << 8) | ord(s[pos + ilo])
        pos += 2
        if ch < 0xD800 or ch > 0xDFFF:
            result.append(unichr(ch))
            continue
        # UTF-16 code pair:
        if len(s) - pos < 2:
            pos -= 2
            if not final:
                break
            errmsg = "unexpected end of data"
            r, pos = errorhandler(errors, public_encoding_name,
                                  errmsg, s, pos, len(s))
            result.append(r)
            if len(s) - pos < 2:
                break
        elif 0xD800 <= ch <= 0xDBFF:
            ch2 = (ord(s[pos+ihi]) << 8) | ord(s[pos+ilo])
            pos += 2
            if 0xDC00 <= ch2 <= 0xDFFF:
                if MAXUNICODE < 65536:
                    result.append(unichr(ch))
                    result.append(unichr(ch2))
                else:
                    result.append(UNICHR((((ch & 0x3FF)<<10) |
                                           (ch2 & 0x3FF)) + 0x10000))
                continue
            else:
                r, pos = errorhandler(errors, public_encoding_name,
                                      "illegal UTF-16 surrogate",
                                      s, pos - 4, pos - 2)
                result.append(r)
        else:
            r, pos = errorhandler(errors, public_encoding_name,
                                  "illegal encoding",
                                  s, pos - 2, pos)
            result.append(r)
    return result.build(), pos, bo

def unicode_encode_utf_16_helper(s, size, errors,
                                 errorhandler=None,
                                 allow_surrogates=True,
                                 byteorder='little',
                                 public_encoding_name='utf16'):
    if errorhandler is None:
        errorhandler = default_unicode_error_encode
    if size == 0:
        if byteorder == 'native':
            result = StringBuilder(2)
            _STORECHAR(result, 0xFEFF, BYTEORDER)
            return result.build()
        return ""

    result = StringBuilder(size * 2 + 2)
    if byteorder == 'native':
        _STORECHAR(result, 0xFEFF, BYTEORDER)
        byteorder = BYTEORDER

    pos = 0
    while pos < size:
        ch = ord(s[pos])
        pos += 1

        if ch < 0xD800:
            _STORECHAR(result, ch, byteorder)
        elif ch >= 0x10000:
            _STORECHAR(result, 0xD800 | ((ch-0x10000) >> 10), byteorder)
            _STORECHAR(result, 0xDC00 | ((ch-0x10000) & 0x3FF), byteorder)
        elif ch >= 0xE000 or allow_surrogates:
            _STORECHAR(result, ch, byteorder)
        else:
            ru, rs, pos = errorhandler(errors, public_encoding_name,
                                       'surrogates not allowed',
                                       s, pos-1, pos)
            if rs is not None:
                # py3k only
                if len(rs) % 2 != 0:
                    errorhandler('strict', public_encoding_name,
                                 'surrogates not allowed',
                                 s, pos-1, pos)
                result.append(rs)
                continue
            for ch in ru:
                if ord(ch) < 0xD800:
                    _STORECHAR(result, ord(ch), byteorder)
                else:
                    errorhandler('strict', public_encoding_name,
                                 'surrogates not allowed',
                                 s, pos-1, pos)
            continue

    return result.build()

def unicode_encode_utf_16(s, size, errors,
                          errorhandler=None,
                          allow_surrogates=True):
    return unicode_encode_utf_16_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "native")

def unicode_encode_utf_16_be(s, size, errors,
                             errorhandler=None,
                             allow_surrogates=True):
    return unicode_encode_utf_16_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "big")

def unicode_encode_utf_16_le(s, size, errors,
                             errorhandler=None,
                             allow_surrogates=True):
    return unicode_encode_utf_16_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "little")

def py3k_unicode_encode_utf_16(s, size, errors,
                          errorhandler=None,
                          allow_surrogates=True):
    return unicode_encode_utf_16_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "native",
                                        'utf-16-' + BYTEORDER2)

def py3k_unicode_encode_utf_16_be(s, size, errors,
                             errorhandler=None,
                             allow_surrogates=True):
    return unicode_encode_utf_16_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "big",
                                        'utf-16-be')

def py3k_unicode_encode_utf_16_le(s, size, errors,
                             errorhandler=None,
                             allow_surrogates=True):
    return unicode_encode_utf_16_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "little",
                                        'utf-16-le')


# ____________________________________________________________
# utf-32 (not used in PyPy any more)

def str_decode_utf_32(s, size, errors, final=True,
                      errorhandler=None):
    result, length, byteorder = str_decode_utf_32_helper(
        s, size, errors, final, errorhandler, "native")
    return result, length

def str_decode_utf_32_be(s, size, errors, final=True,
                         errorhandler=None):
    result, length, byteorder = str_decode_utf_32_helper(
        s, size, errors, final, errorhandler, "big")
    return result, length

def str_decode_utf_32_le(s, size, errors, final=True,
                         errorhandler=None):
    result, length, byteorder = str_decode_utf_32_helper(
        s, size, errors, final, errorhandler, "little")
    return result, length

def py3k_str_decode_utf_32(s, size, errors, final=True,
                           errorhandler=None):
    result, length, byteorder = str_decode_utf_32_helper(
        s, size, errors, final, errorhandler, "native",
        'utf-32-' + BYTEORDER2, allow_surrogates=False)
    return result, length

def py3k_str_decode_utf_32_be(s, size, errors, final=True,
                              errorhandler=None):
    result, length, byteorder = str_decode_utf_32_helper(
        s, size, errors, final, errorhandler, "big",
        'utf-32-be', allow_surrogates=False)
    return result, length

def py3k_str_decode_utf_32_le(s, size, errors, final=True,
                              errorhandler=None):
    result, length, byteorder = str_decode_utf_32_helper(
        s, size, errors, final, errorhandler, "little",
        'utf-32-le', allow_surrogates=False)
    return result, length

BOM32_DIRECT  = intmask(0x0000FEFF)
BOM32_REVERSE = intmask(0xFFFE0000)

def str_decode_utf_32_helper(s, size, errors, final=True,
                             errorhandler=None,
                             byteorder="native",
                             public_encoding_name='utf32',
                             allow_surrogates=True):
    if errorhandler is None:
        errorhandler = default_unicode_error_decode
    bo = 0

    if BYTEORDER == 'little':
        iorder = [0, 1, 2, 3]
    else:
        iorder = [3, 2, 1, 0]

    #  Check for BOM marks (U+FEFF) in the input and adjust current
    #  byte order setting accordingly. In native mode, the leading BOM
    #  mark is skipped, in all other modes, it is copied to the output
    #  stream as-is (giving a ZWNBSP character).
    pos = 0
    if byteorder == 'native':
        if size >= 4:
            bom = intmask(
                (ord(s[iorder[3]]) << 24) | (ord(s[iorder[2]]) << 16) |
                (ord(s[iorder[1]]) << 8)  | ord(s[iorder[0]]))
            if BYTEORDER == 'little':
                if bom == BOM32_DIRECT:
                    pos += 4
                    bo = -1
                elif bom == BOM32_REVERSE:
                    pos += 4
                    bo = 1
            else:
                if bom == BOM32_DIRECT:
                    pos += 4
                    bo = 1
                elif bom == BOM32_REVERSE:
                    pos += 4
                    bo = -1
    elif byteorder == 'little':
        bo = -1
    else:
        bo = 1
    if size == 0:
        return u'', 0, bo
    if bo == -1:
        # force little endian
        iorder = [0, 1, 2, 3]

    elif bo == 1:
        # force big endian
        iorder = [3, 2, 1, 0]

    result = UnicodeBuilder(size // 4)

    while pos < size:
        # remaining bytes at the end? (size should be divisible by 4)
        if len(s) - pos < 4:
            if not final:
                break
            r, pos = errorhandler(errors, public_encoding_name,
                                  "truncated data",
                                  s, pos, len(s))
            result.append(r)
            if len(s) - pos < 4:
                break
            continue
        ch = ((ord(s[pos + iorder[3]]) << 24) | (ord(s[pos + iorder[2]]) << 16) |
              (ord(s[pos + iorder[1]]) << 8)  | ord(s[pos + iorder[0]]))
        if not allow_surrogates and 0xD800 <= ch <= 0xDFFFF:
            r, pos = errorhandler(errors, public_encoding_name,
                                  "code point in surrogate code point "
                                  "range(0xd800, 0xe000)",
                                  s, pos, len(s))
            result.append(r)
        elif ch >= 0x110000:
            r, pos = errorhandler(errors, public_encoding_name,
                                  "codepoint not in range(0x110000)",
                                  s, pos, len(s))
            result.append(r)
            continue

        if MAXUNICODE < 65536 and ch >= 0x10000:
            ch -= 0x10000L
            result.append(unichr(0xD800 + (ch >> 10)))
            result.append(unichr(0xDC00 + (ch & 0x03FF)))
        else:
            result.append(UNICHR(ch))
        pos += 4
    return result.build(), pos, bo

def _STORECHAR32(result, CH, byteorder):
    c0 = chr(((CH) >> 24) & 0xff)
    c1 = chr(((CH) >> 16) & 0xff)
    c2 = chr(((CH) >> 8) & 0xff)
    c3 = chr((CH) & 0xff)
    if byteorder == 'little':
        result.append(c3)
        result.append(c2)
        result.append(c1)
        result.append(c0)
    else:
        result.append(c0)
        result.append(c1)
        result.append(c2)
        result.append(c3)

def unicode_encode_utf_32_helper(s, size, errors,
                                 errorhandler=None,
                                 allow_surrogates=True,
                                 byteorder='little',
                                 public_encoding_name='utf32'):
    if errorhandler is None:
        errorhandler = default_unicode_error_encode
    if size == 0:
        if byteorder == 'native':
            result = StringBuilder(4)
            _STORECHAR32(result, 0xFEFF, BYTEORDER)
            return result.build()
        return ""

    result = StringBuilder(size * 4 + 4)
    if byteorder == 'native':
        _STORECHAR32(result, 0xFEFF, BYTEORDER)
        byteorder = BYTEORDER

    pos = 0
    while pos < size:
        ch = ord(s[pos])
        pos += 1
        ch2 = 0
        if not allow_surrogates and 0xD800 <= ch < 0xE000:
            ru, rs, pos = errorhandler(errors, public_encoding_name,
                                        'surrogates not allowed',
                                        s, pos-1, pos)
            if rs is not None:
                # py3k only
                if len(rs) % 4 != 0:
                    errorhandler('strict', public_encoding_name,
                                    'surrogates not allowed',
                                    s, pos-1, pos)
                result.append(rs)
                continue
            for ch in ru:
                if ord(ch) < 0xD800:
                    _STORECHAR32(result, ord(ch), byteorder)
                else:
                    errorhandler('strict', public_encoding_name,
                                    'surrogates not allowed',
                                    s, pos-1, pos)
            continue
        if 0xD800 <= ch < 0xDC00 and MAXUNICODE < 65536 and pos < size:
            ch2 = ord(s[pos])
            if 0xDC00 <= ch2 < 0xE000:
                ch = (((ch & 0x3FF)<<10) | (ch2 & 0x3FF)) + 0x10000;
                pos += 1
        _STORECHAR32(result, ch, byteorder)

    return result.build()

def unicode_encode_utf_32(s, size, errors,
                          errorhandler=None, allow_surrogates=True):
    return unicode_encode_utf_32_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "native")

def unicode_encode_utf_32_be(s, size, errors,
                             errorhandler=None, allow_surrogates=True):
    return unicode_encode_utf_32_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "big")

def unicode_encode_utf_32_le(s, size, errors,
                             errorhandler=None, allow_surrogates=True):
    return unicode_encode_utf_32_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "little")

def py3k_unicode_encode_utf_32(s, size, errors,
                               errorhandler=None, allow_surrogates=True):
    return unicode_encode_utf_32_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "native",
                                        'utf-32-' + BYTEORDER2)

def py3k_unicode_encode_utf_32_be(s, size, errors,
                                  errorhandler=None, allow_surrogates=True):
    return unicode_encode_utf_32_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "big",
                                        'utf-32-be')

def py3k_unicode_encode_utf_32_le(s, size, errors,
                                  errorhandler=None, allow_surrogates=True):
    return unicode_encode_utf_32_helper(s, size, errors, errorhandler,
                                        allow_surrogates, "little",
                                        'utf-32-le')


# ____________________________________________________________
# utf-7

# Three simple macros defining base-64

def _utf7_IS_BASE64(oc):
    "Is c a base-64 character?"
    c = chr(oc)
    return c.isalnum() or c == '+' or c == '/'
def _utf7_TO_BASE64(n):
    "Returns the base-64 character of the bottom 6 bits of n"
    return "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"[n & 0x3f]
def _utf7_FROM_BASE64(c):
    "given that c is a base-64 character, what is its base-64 value?"
    if c >= 'a':
        return ord(c) - 71
    elif c >= 'A':
        return ord(c) - 65
    elif c >= '0':
        return ord(c) + 4
    elif c == '+':
        return 62
    else: # c == '/'
        return 63

def _utf7_DECODE_DIRECT(oc):
    return oc <= 127 and oc != ord('+')

# The UTF-7 encoder treats ASCII characters differently according to
# whether they are Set D, Set O, Whitespace, or special (i.e. none of
# the above).  See RFC2152.  This array identifies these different
# sets:
# 0 : "Set D"
#      alphanumeric and '(),-./:?
# 1 : "Set O"
#     !"#$%&*;<=>@[]^_`{|}
# 2 : "whitespace"
#     ht nl cr sp
# 3 : special (must be base64 encoded)
#     everything else (i.e. +\~ and non-printing codes 0-8 11-12 14-31 127)

utf7_category = [
#  nul soh stx etx eot enq ack bel bs  ht  nl  vt  np  cr  so  si
    3,  3,  3,  3,  3,  3,  3,  3,  3,  2,  2,  3,  3,  2,  3,  3,
#  dle dc1 dc2 dc3 dc4 nak syn etb can em  sub esc fs  gs  rs  us
    3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,
#  sp   !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /
    2,  1,  1,  1,  1,  1,  1,  0,  0,  0,  1,  3,  0,  0,  0,  0,
#   0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,  0,
#   @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O
    1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#   P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  3,  1,  1,  1,
#   `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o
    1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#   p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~  del
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  3,  3,
]

# ENCODE_DIRECT: this character should be encoded as itself.  The
# answer depends on whether we are encoding set O as itself, and also
# on whether we are encoding whitespace as itself.  RFC2152 makes it
# clear that the answers to these questions vary between
# applications, so this code needs to be flexible.

def _utf7_ENCODE_DIRECT(oc, directO, directWS):
    return(oc < 128 and oc > 0 and
           (utf7_category[oc] == 0 or
            (directWS and utf7_category[oc] == 2) or
            (directO and utf7_category[oc] == 1)))

def _utf7_ENCODE_CHAR(result, oc, base64bits, base64buffer):
    if MAXUNICODE > 65535 and oc >= 0x10000:
        # code first surrogate
        base64bits += 16
        base64buffer = (base64buffer << 16) | 0xd800 | ((oc-0x10000) >> 10)
        while base64bits >= 6:
            result.append(_utf7_TO_BASE64(base64buffer >> (base64bits-6)))
            base64bits -= 6
        # prepare second surrogate
        oc = 0xDC00 | ((oc-0x10000) & 0x3FF)
    base64bits += 16
    base64buffer = (base64buffer << 16) | oc
    while base64bits >= 6:
        result.append(_utf7_TO_BASE64(base64buffer >> (base64bits-6)))
        base64bits -= 6
    return base64bits, base64buffer

def str_decode_utf_7(s, size, errors, final=False,
                     errorhandler=None):
    if errorhandler is None:
        errorhandler = default_unicode_error_decode
    if size == 0:
        return u'', 0

    inShift = False
    base64bits = 0
    base64buffer = 0
    surrogate = 0

    result = UnicodeBuilder(size)
    pos = 0
    shiftOutStartPos = 0
    startinpos = 0
    while pos < size:
        ch = s[pos]

        if inShift: # in a base-64 section
            if _utf7_IS_BASE64(ord(ch)): #consume a base-64 character
                base64buffer = (base64buffer << 6) | _utf7_FROM_BASE64(ch)
                base64bits += 6
                pos += 1

                if base64bits >= 16:
                    # enough bits for a UTF-16 value
                    outCh = base64buffer >> (base64bits - 16)
                    base64bits -= 16
                    base64buffer &= (1 << base64bits) - 1 # clear high bits
                    assert outCh <= 0xffff
                    if surrogate:
                        # expecting a second surrogate
                        if outCh >= 0xDC00 and outCh <= 0xDFFF:
                            if MAXUNICODE < 65536:
                                result.append(unichr(surrogate))
                                result.append(unichr(outCh))
                            else:
                                result.append(
                                    UNICHR((((surrogate & 0x3FF)<<10) |
                                            (outCh & 0x3FF)) + 0x10000))
                            surrogate = 0
                            continue
                        else:
                            result.append(unichr(surrogate))
                            surrogate = 0
                            # Not done with outCh: falls back to next line
                    if outCh >= 0xD800 and outCh <= 0xDBFF:
                        # first surrogate
                        surrogate = outCh
                    else:
                        result.append(unichr(outCh))

            else:
                # now leaving a base-64 section
                inShift = False

                if base64bits > 0: # left-over bits
                    if base64bits >= 6:
                        # We've seen at least one base-64 character
                        pos += 1
                        msg = "partial character in shift sequence"
                        res, pos = errorhandler(errors, 'utf7',
                                                msg, s, pos-1, pos)
                        result.append(res)
                        continue
                    else:
                        # Some bits remain; they should be zero
                        if base64buffer != 0:
                            pos += 1
                            msg = "non-zero padding bits in shift sequence"
                            res, pos = errorhandler(errors, 'utf7',
                                                    msg, s, pos-1, pos)
                            result.append(res)
                            continue

                if surrogate and _utf7_DECODE_DIRECT(ord(ch)):
                    result.append(unichr(surrogate))
                surrogate = 0

                if ch == '-':
                    # '-' is absorbed; other terminating characters are
                    # preserved
                    pos += 1

        elif ch == '+':
            startinpos = pos
            pos += 1 # consume '+'
            if pos < size and s[pos] == '-': # '+-' encodes '+'
                pos += 1
                result.append(u'+')
            else: # begin base64-encoded section
                inShift = 1
                surrogate = 0
                shiftOutStartPos = result.getlength()
                base64bits = 0
                base64buffer = 0

        elif _utf7_DECODE_DIRECT(ord(ch)): # character decodes at itself
            result.append(unichr(ord(ch)))
            pos += 1
        else:
            startinpos = pos
            pos += 1
            msg = "unexpected special character"
            res, pos = errorhandler(errors, 'utf7', msg, s, pos-1, pos)
            result.append(res)

    # end of string
    final_length = result.getlength()
    if inShift and final: # in shift sequence, no more to follow
        # if we're in an inconsistent state, that's an error
        inShift = 0
        if (surrogate or
            base64bits >= 6 or
            (base64bits > 0 and base64buffer != 0)):
            msg = "unterminated shift sequence"
            res, pos = errorhandler(errors, 'utf7', msg, s, shiftOutStartPos, pos)
            result.append(res)
            final_length = result.getlength()
    elif inShift:
        pos = startinpos
        final_length = shiftOutStartPos # back off output

    assert final_length >= 0
    return result.build()[:final_length], pos

def unicode_encode_utf_7(s, size, errors, errorhandler=None):
    if size == 0:
        return ''
    result = StringBuilder(size)

    encodeSetO = encodeWhiteSpace = False

    inShift = False
    base64bits = 0
    base64buffer = 0

    pos = 0
    while pos < size:
        ch = s[pos]
        oc = ord(ch)
        if not inShift:
            if ch == u'+':
                result.append('+-')
            elif _utf7_ENCODE_DIRECT(oc, not encodeSetO, not encodeWhiteSpace):
                result.append(chr(oc))
            else:
                result.append('+')
                inShift = True
                base64bits, base64buffer = _utf7_ENCODE_CHAR(
                    result, oc, base64bits, base64buffer)
        else:
            if _utf7_ENCODE_DIRECT(oc, not encodeSetO, not encodeWhiteSpace):
                # shifting out
                if base64bits: # output remaining bits
                    result.append(_utf7_TO_BASE64(base64buffer << (6-base64bits)))
                    base64buffer = 0
                    base64bits = 0

                inShift = False
                ## Characters not in the BASE64 set implicitly unshift the
                ## sequence so no '-' is required, except if the character is
                ## itself a '-'
                if _utf7_IS_BASE64(oc) or ch == u'-':
                    result.append('-')
                result.append(chr(oc))
            else:
                base64bits, base64buffer = _utf7_ENCODE_CHAR(
                    result, oc, base64bits, base64buffer)
        pos += 1

    if base64bits:
        result.append(_utf7_TO_BASE64(base64buffer << (6 - base64bits)))
    if inShift:
        result.append('-')

    return result.build()

# ____________________________________________________________
# ascii and latin-1

def str_decode_latin_1(s, size, errors, final=False,
                       errorhandler=None):
    # latin1 is equivalent to the first 256 ordinals in Unicode.
    pos = 0
    result = UnicodeBuilder(size)
    while pos < size:
        result.append(unichr(ord(s[pos])))
        pos += 1
    return result.build(), pos


def str_decode_ascii(s, size, errors, final=False,
                     errorhandler=None):
    if errorhandler is None:
        errorhandler = default_unicode_error_decode
    # ASCII is equivalent to the first 128 ordinals in Unicode.
    result = UnicodeBuilder(size)
    pos = 0
    while pos < size:
        c = s[pos]
        if ord(c) < 128:
            result.append(unichr(ord(c)))
            pos += 1
        else:
            r, pos = errorhandler(errors, "ascii", "ordinal not in range(128)",
                                  s,  pos, pos + 1)
            result.append(r)
    return result.build(), pos

# An elidable version, for a subset of the cases
@jit.elidable
def fast_str_decode_ascii(s):
    result = UnicodeBuilder(len(s))
    for c in s:
        if ord(c) >= 128:
            raise ValueError
        result.append(unichr(ord(c)))
    return result.build()


def unicode_encode_ucs1_helper(p, size, errors,
                               errorhandler=None, limit=256):
    if errorhandler is None:
        errorhandler = default_unicode_error_encode
    if limit == 256:
        reason = "ordinal not in range(256)"
        encoding = "latin-1"
    else:
        reason = "ordinal not in range(128)"
        encoding = "ascii"

    if size == 0:
        return ''
    result = StringBuilder(size)
    pos = 0
    while pos < size:
        ch = p[pos]

        if ord(ch) < limit:
            result.append(chr(ord(ch)))
            pos += 1
        else:
            # startpos for collecting unencodable chars
            collstart = pos
            collend = pos+1
            while collend < len(p) and ord(p[collend]) >= limit:
                collend += 1
            ru, rs, pos = errorhandler(errors, encoding, reason, p,
                                       collstart, collend)
            if rs is not None:
                # py3k only
                result.append(rs)
                continue
            for ch in ru:
                if ord(ch) < limit:
                    result.append(chr(ord(ch)))
                else:
                    errorhandler("strict", encoding, reason, p,
                                 collstart, collend)

    return result.build()

def unicode_encode_latin_1(p, size, errors, errorhandler=None):
    res = unicode_encode_ucs1_helper(p, size, errors, errorhandler, 256)
    return res

def unicode_encode_ascii(p, size, errors, errorhandler=None):
    res = unicode_encode_ucs1_helper(p, size, errors, errorhandler, 128)
    return res

# ____________________________________________________________
# Charmap

ERROR_CHAR = u'\ufffe'

@specialize.argtype(5)
def str_decode_charmap(s, size, errors, final=False,
                       errorhandler=None, mapping=None):
    "mapping can be a rpython dictionary, or a dict-like object."

    # Default to Latin-1
    if mapping is None:
        return str_decode_latin_1(s, size, errors, final=final,
                                  errorhandler=errorhandler)
    if errorhandler is None:
        errorhandler = default_unicode_error_decode
    if size == 0:
        return u'', 0

    pos = 0
    result = UnicodeBuilder(size)
    while pos < size:
        ch = s[pos]

        c = mapping.get(ch, ERROR_CHAR)
        if c == ERROR_CHAR:
            r, pos = errorhandler(errors, "charmap",
                                  "character maps to <undefined>",
                                  s,  pos, pos + 1)
            result.append(r)
            continue
        result.append(c)
        pos += 1
    return result.build(), pos

def unicode_encode_charmap(s, size, errors, errorhandler=None,
                           mapping=None):
    if mapping is None:
        return unicode_encode_latin_1(s, size, errors,
                                      errorhandler=errorhandler)

    if errorhandler is None:
        errorhandler = default_unicode_error_encode

    if size == 0:
        return ''
    result = StringBuilder(size)
    pos = 0
    while pos < size:
        ch = s[pos]

        c = mapping.get(ch, '')
        if len(c) == 0:
            # collect all unencodable chars. Important for narrow builds.
            collend = pos + 1
            while collend < size and mapping.get(s[collend], '') == '':
                collend += 1
            ru, rs, pos = errorhandler(errors, "charmap",
                                       "character maps to <undefined>",
                                       s, pos, collend)
            if rs is not None:
                # py3k only
                result.append(rs)
                continue
            for ch2 in ru:
                c2 = mapping.get(ch2, '')
                if len(c2) == 0:
                    errorhandler(
                        "strict", "charmap",
                        "character maps to <undefined>",
                        s,  pos, pos + 1)
                result.append(c2)
            continue
        result.append(c)
        pos += 1
    return result.build()

# ____________________________________________________________
# Unicode escape

hexdigits = "0123456789ABCDEFabcdef"

def hexescape(builder, s, pos, digits,
              encoding, errorhandler, message, errors):
    chr = 0
    if pos + digits > len(s):
        endinpos = pos
        while endinpos < len(s) and s[endinpos] in hexdigits:
            endinpos += 1
        res, pos = errorhandler(errors, encoding,
                                message, s, pos-2, endinpos)
        builder.append(res)
    else:
        try:
            chr = r_uint(int(s[pos:pos+digits], 16))
        except ValueError:
            endinpos = pos
            while s[endinpos] in hexdigits:
                endinpos += 1
            res, pos = errorhandler(errors, encoding,
                                    message, s, pos-2, endinpos)
            builder.append(res)
        else:
            # when we get here, chr is a 32-bit unicode character
            if chr <= MAXUNICODE:
                builder.append(UNICHR(chr))
                pos += digits

            elif chr <= 0x10ffff:
                chr -= 0x10000L
                builder.append(unichr(0xD800 + (chr >> 10)))
                builder.append(unichr(0xDC00 + (chr & 0x03FF)))
                pos += digits
            else:
                message = "illegal Unicode character"
                res, pos = errorhandler(errors, encoding,
                                        message, s, pos-2, pos+digits)
                builder.append(res)
    return pos

def str_decode_unicode_escape(s, size, errors, final=False,
                              errorhandler=None,
                              unicodedata_handler=None):
    if errorhandler is None:
        errorhandler = default_unicode_error_decode

    if size == 0:
        return u'', 0

    builder = UnicodeBuilder(size)
    pos = 0
    while pos < size:
        ch = s[pos]

        # Non-escape characters are interpreted as Unicode ordinals
        if ch != '\\':
            builder.append(unichr(ord(ch)))
            pos += 1
            continue

        # - Escapes
        pos += 1
        if pos >= size:
            message = "\\ at end of string"
            res, pos = errorhandler(errors, "unicodeescape",
                                    message, s, pos-1, size)
            builder.append(res)
            continue

        ch = s[pos]
        pos += 1
        # \x escapes
        if ch == '\n': pass
        elif ch == '\\': builder.append(u'\\')
        elif ch == '\'': builder.append(u'\'')
        elif ch == '\"': builder.append(u'\"')
        elif ch == 'b' : builder.append(u'\b')
        elif ch == 'f' : builder.append(u'\f')
        elif ch == 't' : builder.append(u'\t')
        elif ch == 'n' : builder.append(u'\n')
        elif ch == 'r' : builder.append(u'\r')
        elif ch == 'v' : builder.append(u'\v')
        elif ch == 'a' : builder.append(u'\a')
        elif '0' <= ch <= '7':
            x = ord(ch) - ord('0')
            if pos < size:
                ch = s[pos]
                if '0' <= ch <= '7':
                    pos += 1
                    x = (x<<3) + ord(ch) - ord('0')
                    if pos < size:
                        ch = s[pos]
                        if '0' <= ch <= '7':
                            pos += 1
                            x = (x<<3) + ord(ch) - ord('0')
            builder.append(unichr(x))
        # hex escapes
        # \xXX
        elif ch == 'x':
            digits = 2
            message = "truncated \\xXX escape"
            pos = hexescape(builder, s, pos, digits,
                            "unicodeescape", errorhandler, message, errors)

        # \uXXXX
        elif ch == 'u':
            digits = 4
            message = "truncated \\uXXXX escape"
            pos = hexescape(builder, s, pos, digits,
                            "unicodeescape", errorhandler, message, errors)

        #  \UXXXXXXXX
        elif ch == 'U':
            digits = 8
            message = "truncated \\UXXXXXXXX escape"
            pos = hexescape(builder, s, pos, digits,
                            "unicodeescape", errorhandler, message, errors)

        # \N{name}
        elif ch == 'N' and unicodedata_handler is not None:
            message = "malformed \\N character escape"
            look = pos

            if look < size and s[look] == '{':
                # look for the closing brace
                while look < size and s[look] != '}':
                    look += 1
                if look < size and s[look] == '}':
                    # found a name.  look it up in the unicode database
                    message = "unknown Unicode character name"
                    name = s[pos+1:look]
                    code = unicodedata_handler.call(name)
                    if code < 0:
                        res, pos = errorhandler(errors, "unicodeescape",
                                                message, s, pos-1, look+1)
                        builder.append(res)
                        continue
                    pos = look + 1
                    if code <= MAXUNICODE:
                        builder.append(UNICHR(code))
                    else:
                        code -= 0x10000L
                        builder.append(unichr(0xD800 + (code >> 10)))
                        builder.append(unichr(0xDC00 + (code & 0x03FF)))
                else:
                    res, pos = errorhandler(errors, "unicodeescape",
                                            message, s, pos-1, look+1)
                    builder.append(res)
            else:
                res, pos = errorhandler(errors, "unicodeescape",
                                        message, s, pos-1, look+1)
                builder.append(res)
        else:
            builder.append(u'\\')
            builder.append(unichr(ord(ch)))

    return builder.build(), pos

def make_unicode_escape_function(pass_printable=False, unicode_output=False,
                                 quotes=False, prefix=None):
    # Python3 has two similar escape functions: One to implement
    # encode('unicode_escape') and which outputs bytes, and unicode.__repr__
    # which outputs unicode.  They cannot share RPython code, so we generate
    # them with the template below.
    # Python2 does not really need this, but it reduces diffs between branches.

    if unicode_output:
        STRING_BUILDER = UnicodeBuilder
        STR = unicode
        CHR = UNICHR
    else:
        STRING_BUILDER = StringBuilder
        STR = str
        CHR = chr

    def unicode_escape(s, size, errors, errorhandler=None):
        # errors and errorhandler are not used: this function cannot cause
        # Unicode errors
        return _unicode_escape(s, size)

    @jit.elidable
    def _unicode_escape(s, size):
        result = STRING_BUILDER(size)

        if quotes:
            if prefix:
                result.append(STR(prefix))
            if s.find(STR("'")) != -1 and s.find(STR('"')) == -1:
                quote = ord('\"')
                result.append(STR('"'))
            else:
                quote = ord('\'')
                result.append(STR('\''))
        else:
            quote = 0

            if size == 0:
                return STR('')

        pos = 0
        while pos < size:
            ch = s[pos]
            oc = ord(ch)

            # Escape quotes
            if quotes and (oc == quote or ch == STR('\\')):
                result.append(STR('\\'))
                result.append(CHR(oc))
                pos += 1
                continue

            # The following logic is enabled only if MAXUNICODE == 0xffff, or
            # for testing on top of a host Python where sys.maxunicode == 0xffff
            if ((MAXUNICODE < 65536 or is_narrow_host())
                and 0xD800 <= oc < 0xDC00 and pos + 1 < size):
                # Map UTF-16 surrogate pairs to Unicode \UXXXXXXXX escapes
                pos += 1
                oc2 = ord(s[pos])

                if 0xDC00 <= oc2 <= 0xDFFF:
                    ucs = (((oc & 0x03FF) << 10) | (oc2 & 0x03FF)) + 0x00010000
                    char_escape_helper(result, ucs)
                    pos += 1
                    continue
                # Fall through: isolated surrogates are copied as-is
                pos -= 1

            # Map special whitespace to '\t', \n', '\r'
            if ch == STR('\t'):
                result.append(STR('\\t'))
            elif ch == STR('\n'):
                result.append(STR('\\n'))
            elif ch == STR('\r'):
                result.append(STR('\\r'))
            elif ch == STR('\\'):
                result.append(STR('\\\\'))

            # Map non-printable or non-ascii to '\xhh' or '\uhhhh'
            elif pass_printable and not (oc <= 0x10ffff and unicodedb.isprintable(oc)):
                char_escape_helper(result, oc)
            elif not pass_printable and (oc < 32 or oc >= 0x7F):
                char_escape_helper(result, oc)

            # Copy everything else as-is
            else:
                result.append(CHR(oc))
            pos += 1

        if quotes:
            result.append(CHR(quote))
        return result.build()

    TABLE = STR('0123456789abcdef')

    def char_escape_helper(result, char):
        if char >= 0x10000 or char < 0:
            result.append(STR("\\U"))
            zeros = 8
        elif char >= 0x100:
            result.append(STR("\\u"))
            zeros = 4
        else:
            result.append(STR("\\x"))
            zeros = 2
        for i in range(zeros-1, -1, -1):
            result.append(TABLE[(char >> (4 * i)) & 0x0f])

    return unicode_escape, char_escape_helper

# This function is also used by _codecs/interp_codecs.py
(unicode_encode_unicode_escape, raw_unicode_escape_helper
 ) = make_unicode_escape_function()
(_, raw_unicode_escape_helper_unicode
) = make_unicode_escape_function(unicode_output=True)

# ____________________________________________________________
# Raw unicode escape

def str_decode_raw_unicode_escape(s, size, errors, final=False,
                                  errorhandler=None):
    if errorhandler is None:
        errorhandler = default_unicode_error_decode
    if size == 0:
        return u'', 0

    result = UnicodeBuilder(size)
    pos = 0
    while pos < size:
        ch = s[pos]

        # Non-escape characters are interpreted as Unicode ordinals
        if ch != '\\':
            result.append(unichr(ord(ch)))
            pos += 1
            continue

        # \u-escapes are only interpreted iff the number of leading
        # backslashes is odd
        bs = pos
        while pos < size:
            pos += 1
            if pos == size or s[pos] != '\\':
                break
            result.append(u'\\')

        # we have a backslash at the end of the string, stop here
        if pos >= size:
            result.append(u'\\')
            break

        if ((pos - bs) & 1 == 0 or
            pos >= size or
            (s[pos] != 'u' and s[pos] != 'U')):
            result.append(u'\\')
            result.append(unichr(ord(s[pos])))
            pos += 1
            continue

        digits = 4 if s[pos] == 'u' else 8
        message = "truncated \\uXXXX"
        pos += 1
        pos = hexescape(result, s, pos, digits,
                        "rawunicodeescape", errorhandler, message, errors)

    return result.build(), pos

def unicode_encode_raw_unicode_escape(s, size, errors, errorhandler=None):
    # errorhandler is not used: this function cannot cause Unicode errors
    if size == 0:
        return ''
    result = StringBuilder(size)
    pos = 0
    while pos < size:
        oc = ord(s[pos])

        if MAXUNICODE < 65536 and 0xD800 <= oc < 0xDC00 and pos + 1 < size:
            # Map UTF-16 surrogate pairs to Unicode \UXXXXXXXX escapes
            pos += 1
            oc2 = ord(s[pos])

            if 0xDC00 <= oc2 <= 0xDFFF:
                ucs = (((oc & 0x03FF) << 10) | (oc2 & 0x03FF)) + 0x00010000
                raw_unicode_escape_helper(result, ucs)
                pos += 1
                continue
            # Fall through: isolated surrogates are copied as-is
            pos -= 1

        if oc < 0x100:
            result.append(chr(oc))
        else:
            raw_unicode_escape_helper(result, oc)
        pos += 1

    return result.build()

# ____________________________________________________________
# unicode-internal

def str_decode_unicode_internal(s, size, errors, final=False,
                                errorhandler=None):
    if errorhandler is None:
        errorhandler = default_unicode_error_decode
    if size == 0:
        return u'', 0

    if MAXUNICODE < 65536:
        unicode_bytes = 2
    else:
        unicode_bytes = 4
    if BYTEORDER == "little":
        start = 0
        stop = unicode_bytes
        step = 1
    else:
        start = unicode_bytes - 1
        stop = -1
        step = -1

    result = UnicodeBuilder(size // unicode_bytes)
    pos = 0
    while pos < size:
        if pos > size - unicode_bytes:
            res, pos = errorhandler(errors, "unicode_internal",
                                    "truncated input",
                                    s, pos, size)
            result.append(res)
            continue
        t = r_uint(0)
        h = 0
        for j in range(start, stop, step):
            t += r_uint(ord(s[pos + j])) << (h*8)
            h += 1
        if t > MAXUNICODE:
            res, pos = errorhandler(errors, "unicode_internal",
                                    "unichr(%d) not in range" % (t,),
                                    s, pos, pos + unicode_bytes)
            result.append(res)
            continue
        result.append(UNICHR(t))
        pos += unicode_bytes
    return result.build(), pos

def unicode_encode_unicode_internal(s, size, errors, errorhandler=None):
    if size == 0:
        return ''

    if MAXUNICODE < 65536:
        unicode_bytes = 2
    else:
        unicode_bytes = 4

    result = StringBuilder(size * unicode_bytes)
    pos = 0
    while pos < size:
        oc = ord(s[pos])
        if MAXUNICODE < 65536:
            if BYTEORDER == "little":
                result.append(chr(oc       & 0xFF))
                result.append(chr(oc >>  8 & 0xFF))
            else:
                result.append(chr(oc >>  8 & 0xFF))
                result.append(chr(oc       & 0xFF))
        else:
            if BYTEORDER == "little":
                result.append(chr(oc       & 0xFF))
                result.append(chr(oc >>  8 & 0xFF))
                result.append(chr(oc >> 16 & 0xFF))
                result.append(chr(oc >> 24 & 0xFF))
            else:
                result.append(chr(oc >> 24 & 0xFF))
                result.append(chr(oc >> 16 & 0xFF))
                result.append(chr(oc >>  8 & 0xFF))
                result.append(chr(oc       & 0xFF))
        pos += 1

    return result.build()

# ____________________________________________________________
# MBCS codecs for Windows

if sys.platform == 'win32':
    from rpython.rtyper.lltypesystem import lltype, rffi
    from rpython.rlib import rwin32
    CP_ACP = 0
    BOOLP = lltype.Ptr(lltype.Array(rwin32.BOOL, hints={'nolength': True}))

    MultiByteToWideChar = rffi.llexternal('MultiByteToWideChar',
                                          [rffi.UINT, rwin32.DWORD,
                                           rwin32.LPCSTR, rffi.INT,
                                           rffi.CWCHARP, rffi.INT],
                                          rffi.INT,
                                          calling_conv='win',
                                          save_err=rffi.RFFI_SAVE_LASTERROR)

    WideCharToMultiByte = rffi.llexternal('WideCharToMultiByte',
                                          [rffi.UINT, rwin32.DWORD,
                                           rffi.CWCHARP, rffi.INT,
                                           rwin32.LPCSTR, rffi.INT,
                                           rwin32.LPCSTR, BOOLP],
                                          rffi.INT,
                                          calling_conv='win',
                                          save_err=rffi.RFFI_SAVE_LASTERROR)

    def is_dbcs_lead_byte(c):
        # XXX don't know how to test this
        return False

    def _decode_mbcs_error(s, errorhandler):
        if rwin32.GetLastError_saved() == rwin32.ERROR_NO_UNICODE_TRANSLATION:
            msg = ("No mapping for the Unicode character exists in the target "
                   "multi-byte code page.")
            errorhandler('strict', 'mbcs', msg, s, 0, 0)
        else:
            raise rwin32.lastSavedWindowsError()

    def str_decode_mbcs(s, size, errors, final=False, errorhandler=None,
                        force_ignore=True):
        if errorhandler is None:
            errorhandler = default_unicode_error_decode

        if not force_ignore and errors not in ('strict', 'ignore'):
            msg = "mbcs encoding does not support errors='%s'" % errors
            errorhandler('strict', 'mbcs', msg, s, 0, 0)

        if size == 0:
            return u"", 0

        if force_ignore or errors == 'ignore':
            flags = 0
        else:
            # strict
            flags = rwin32.MB_ERR_INVALID_CHARS

        # Skip trailing lead-byte unless 'final' is set
        if not final and is_dbcs_lead_byte(s[size-1]):
            size -= 1

        with rffi.scoped_nonmovingbuffer(s) as dataptr:
            # first get the size of the result
            usize = MultiByteToWideChar(CP_ACP, flags,
                                        dataptr, size,
                                        lltype.nullptr(rffi.CWCHARP.TO), 0)
            if usize == 0:
                _decode_mbcs_error(s, errorhandler)

            with rffi.scoped_alloc_unicodebuffer(usize) as buf:
                # do the conversion
                if MultiByteToWideChar(CP_ACP, flags,
                                       dataptr, size, buf.raw, usize) == 0:
                    _decode_mbcs_error(s, errorhandler)
                ret = buf.str(usize)
                assert ret is not None
                return ret, size

    def unicode_encode_mbcs(s, size, errors, errorhandler=None,
                            force_replace=True):
        if errorhandler is None:
            errorhandler = default_unicode_error_encode

        if not force_replace and errors not in ('strict', 'replace'):
            msg = "mbcs encoding does not support errors='%s'" % errors
            errorhandler('strict', 'mbcs', msg, s, 0, 0)

        if size == 0:
            return ''

        if force_replace or errors == 'replace':
            flags = 0
            used_default_p = lltype.nullptr(BOOLP.TO)
        else:
            # strict
            flags = rwin32.WC_NO_BEST_FIT_CHARS
            used_default_p = lltype.malloc(BOOLP.TO, 1, flavor='raw')
            used_default_p[0] = rffi.cast(rwin32.BOOL, False)

        try:
            with rffi.scoped_nonmoving_unicodebuffer(s) as dataptr:
                # first get the size of the result
                mbcssize = WideCharToMultiByte(CP_ACP, flags,
                                               dataptr, size, None, 0,
                                               None, used_default_p)
                if mbcssize == 0:
                    raise rwin32.lastSavedWindowsError()
                # If we used a default char, then we failed!
                if (used_default_p and
                    rffi.cast(lltype.Bool, used_default_p[0])):
                    errorhandler('strict', 'mbcs', "invalid character",
                                 s, 0, 0)

                with rffi.scoped_alloc_buffer(mbcssize) as buf:
                    # do the conversion
                    if WideCharToMultiByte(CP_ACP, flags,
                                           dataptr, size, buf.raw, mbcssize,
                                           None, used_default_p) == 0:
                        raise rwin32.lastSavedWindowsError()
                    if (used_default_p and
                        rffi.cast(lltype.Bool, used_default_p[0])):
                        errorhandler('strict', 'mbcs', "invalid character",
                                     s, 0, 0)
                    result = buf.str(mbcssize)
                    assert result is not None
                    return result
        finally:
            if used_default_p:
                lltype.free(used_default_p, flavor='raw')

# ____________________________________________________________
# Decimal Encoder
def unicode_encode_decimal(s, size, errors, errorhandler=None):
    """Converts whitespace to ' ', decimal characters to their
    corresponding ASCII digit and all other Latin-1 characters except
    \0 as-is. Characters outside this range (Unicode ordinals 1-256)
    are treated as errors. This includes embedded NULL bytes.
    """
    if errorhandler is None:
        errorhandler = default_unicode_error_encode
    if size == 0:
        return ''
    result = StringBuilder(size)
    pos = 0
    while pos < size:
        ch = ord(s[pos])
        if unicodedb.isspace(ch):
            result.append(' ')
            pos += 1
            continue
        try:
            decimal = unicodedb.decimal(ch)
        except KeyError:
            pass
        else:
            result.append(chr(48 + decimal))
            pos += 1
            continue
        if 0 < ch < 256:
            result.append(chr(ch))
            pos += 1
            continue
        # All other characters are considered unencodable
        collstart = pos
        collend = collstart + 1
        while collend < size:
            ch = ord(s[collend])
            try:
                if (0 < ch < 256 or
                    unicodedb.isspace(ch) or
                    unicodedb.decimal(ch) >= 0):
                    break
            except KeyError:
                # not a decimal
                pass
            collend += 1
        msg = "invalid decimal Unicode string"
        ru, rs, pos = errorhandler(errors, 'decimal',
                                   msg, s, collstart, collend)
        if rs is not None:
            # py3k only
            errorhandler('strict', 'decimal', msg, s, collstart, collend)
        for char in ru:
            ch = ord(char)
            if unicodedb.isspace(ch):
                result.append(' ')
                continue
            try:
                decimal = unicodedb.decimal(ch)
            except KeyError:
                pass
            else:
                result.append(chr(48 + decimal))
                continue
            if 0 < ch < 256:
                result.append(chr(ch))
                continue
            errorhandler('strict', 'decimal',
                         msg, s, collstart, collend)
    return result.build()
