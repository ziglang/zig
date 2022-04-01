import sys

from pypy.interpreter.error import OperationError, oefmt
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rstring import StringBuilder
from rpython.rlib import rutf8
from rpython.rlib.rarithmetic import r_uint, intmask
from rpython.rtyper.lltypesystem import rffi
from pypy.module.unicodedata.interp_ucd import unicodedb
from rpython.rlib import runicode

@specialize.memo()
def decode_error_handler(space):
    # Fast version of the "strict" errors handler.
    def raise_unicode_exception_decode(errors, encoding, msg, s,
                                       startingpos, endingpos):
        raise OperationError(space.w_UnicodeDecodeError,
                             space.newtuple([space.newtext(encoding),
                                             space.newbytes(s),
                                             space.newint(startingpos),
                                             space.newint(endingpos),
                                             space.newtext(msg)]))
    return raise_unicode_exception_decode

def decode_never_raise(errors, encoding, msg, s, startingpos, endingpos):
    assert startingpos >= 0
    assert endingpos >= 0
    ux = ['\ux' + hex(ord(x))[2:].upper() for x in s[startingpos:endingpos]]
    return ''.join(ux), endingpos, 'b', ''

@specialize.memo()
def encode_error_handler(space):
    # Fast version of the "strict" errors handler.
    def raise_unicode_exception_encode(errors, encoding, msg, utf8,
                                       startingpos, endingpos):
        u_len = rutf8.codepoints_in_utf8(utf8)
        raise OperationError(space.w_UnicodeEncodeError,
                             space.newtuple([space.newtext(encoding),
                                             space.newutf8(utf8, u_len),
                                             space.newint(startingpos),
                                             space.newint(endingpos),
                                             space.newtext(msg)]))
    return raise_unicode_exception_encode

def default_error_encode(
        errors, encoding, msg, u, startingpos, endingpos):
    """A default handler, for tests"""
    assert endingpos >= 0
    if errors == 'replace':
        return '?', endingpos
    if errors == 'ignore':
        return '', endingpos
    raise ValueError

# ____________________________________________________________
_WIN32 = sys.platform == 'win32'
_MACOSX = sys.platform == 'darwin'

def fsdecode(space, w_string):
    from pypy.module._codecs import interp_codecs
    state = space.fromcache(interp_codecs.CodecState)
    errorhandler=state.decode_error_handler
    utf8 = space.bytes_w(w_string)
    # fast path for ascii
    if rutf8.first_non_ascii_char(utf8) < 0:
        return space.newtext(utf8, len(utf8))
    if _WIN32:
        import pypy.interpreter.unicodehelper_win32 as win32
        slen = len(utf8)
        utf8, _, lgt = str_decode_utf8(utf8, 'surrogateescape', True, errorhandler)
    elif 0 and  _MACOSX:
        utf8, lgt, pos  = str_decode_utf8(utf8, 'surrogateescape', True,
                                    errorhandler, allow_surrogates=False)
    elif space.sys.filesystemencoding is None or state.codec_need_encodings:
        # bootstrap check: if the filesystemencoding isn't initialized
        # or the filesystem codec is implemented in Python we cannot
        # use it before the codecs are ready. use the locale codec
        # instead
        from pypy.module._codecs.locale import (
            str_decode_locale_surrogateescape)
        utf8, lgt = str_decode_locale_surrogateescape(utf8)
    else:
        from pypy.module.sys.interp_encoding import getfilesystemencoding
        return space.call_method(w_string, 'decode',
                                 getfilesystemencoding(space),
                                 space.newtext('surrogateescape'))
    return space.newtext(utf8, lgt)

def fsencode(space, w_uni):
    from pypy.module._codecs import interp_codecs
    state = space.fromcache(interp_codecs.CodecState)
    if _WIN32:
        errorhandler=state.encode_error_handler
        utf8 = space.utf8_w(w_uni)
        bytes = utf8_encode_utf_8(utf8, 'surrogateescape', errorhandler)
    elif 0 and _MACOSX:
        utf8 = space.utf8_w(w_uni)
        errorhandler=state.encode_error_handler,
        bytes = utf8_encode_utf_8(utf8, 'surrogateescape', errorhandler,
                                  allow_surrogates=False)
    elif space.sys.filesystemencoding is None or state.codec_need_encodings:
        # bootstrap check: if the filesystemencoding isn't initialized
        # or the filesystem codec is implemented in Python we cannot
        # use it before the codecs are ready. use the locale codec
        # instead
        from pypy.module._codecs.locale import (
            utf8_encode_locale_surrogateescape)
        utf8 = space.utf8_w(w_uni)
        ulen = space.len_w(w_uni)
        if '\x00' in utf8:
            raise oefmt(space.w_ValueError, "embedded null character")
        bytes = utf8_encode_locale_surrogateescape(utf8, ulen)
    else:
        from pypy.module.sys.interp_encoding import getfilesystemencoding
        return space.call_method(w_uni, 'encode',
                                 getfilesystemencoding(space),
                                 space.newtext('surrogateescape'))
    return space.newbytes(bytes)

def encode(space, w_data, encoding=None, errors='strict'):
    from pypy.objspace.std.unicodeobject import encode_object
    return encode_object(space, w_data, encoding, errors)


# These functions take and return unwrapped rpython strings

def decode_raw_unicode_escape(space, string):
    return str_decode_raw_unicode_escape(
        string, "strict",
        final=True, errorhandler=decode_error_handler(space))

def check_ascii_or_raise(space, string):
    try:
        rutf8.check_ascii(string)
    except rutf8.CheckError as e:
        decode_error_handler(space)('strict', 'ascii',
                                    'ordinal not in range(128)', string,
                                    e.pos, e.pos + 1)
        assert False, "unreachable"

def check_utf8_or_raise(space, string, start=0, end=-1):
    # Surrogates are accepted and not treated specially at all.
    # If there happen to be two 3-bytes encoding a pair of surrogates,
    # you still get two surrogate unicode characters in the result.
    # These are the Python3 rules, Python2 differs
    assert isinstance(string, str)
    try:
        return rutf8.check_utf8(string, True, start, end)
    except rutf8.CheckError as e:
        decode_error_handler(space)('strict', 'utf-8',
                                    'unexpected end of data', string,
                                    e.pos, e.pos + 1)

def str_decode_ascii(s, errors, final, errorhandler):
    try:
        rutf8.check_ascii(s)
        return s, len(s), len(s)
    except rutf8.CheckError:
        return _str_decode_ascii_slowpath(s, errors, final, errorhandler)

def _str_decode_ascii_slowpath(s, errors, final, errorhandler):
    i = 0
    res = StringBuilder()
    while i < len(s):
        ch = s[i]
        if ord(ch) > 0x7F:
            r, i, rettype, s = errorhandler(errors, 'ascii', 'ordinal not in range(128)',
                s, i, i + 1)
            res.append(r)
        else:
            res.append(ch)
            i += 1
    ress = res.build()
    lgt = rutf8.check_utf8(ress, True)
    return ress, lgt, lgt

def str_decode_latin_1(s, errors, final, errorhandler):
    try:
        rutf8.check_ascii(s)
        return s, len(s), len(s)
    except rutf8.CheckError:
        return _str_decode_latin_1_slowpath(s, errors, final, errorhandler)

def _str_decode_latin_1_slowpath(s, errors, final, errorhandler):
    res = StringBuilder(len(s))
    i = 0
    while i < len(s):
        if ord(s[i]) > 0x7F:
            while i < len(s) and ord(s[i]) > 0x7F:
                rutf8.unichr_as_utf8_append(res, ord(s[i]))
                i += 1
        else:
            start = i
            end = i + 1
            while end < len(s) and ord(s[end]) <= 0x7F:
                end += 1
            res.append_slice(s, start, end)
            i = end
    return res.build(), len(s), len(s)

class ErrorHandlerError(Exception):
    def __init__(self, new, old):
        self.new = new
        self.old = old

def utf8_encode_utf_8(s, errors, errorhandler, allow_surrogates=False):
    if len(s) == 0:
        return ''

    # two fast paths
    if allow_surrogates:
        # already valid utf-8 with surrogates, surrogates are allowed, so just
        # return
        return s
    if not rutf8.has_surrogates(s):
        # already valid utf-8 and doesn't contain surrogates, so we don't need
        # to do anything
        return s
    # annoying slow path
    return _utf8_encode_utf_8_deal_with_surrogates(s, errors, errorhandler)

def _utf8_encode_utf_8_deal_with_surrogates(s, errors, errorhandler):
    pos = 0
    upos = 0
    result = StringBuilder(len(s))
    while pos < len(s):
        try:
            rutf8.check_utf8(s, allow_surrogates=False, start=pos)
            # otherwise the fast path above would have triggered
            assert pos != 0
            result.append_slice(s, pos, len(s))
            break
        except rutf8.CheckError as e:
            end = e.pos
            assert end >= 0
            result.append_slice(s, pos, end)
            upos += rutf8.codepoints_in_utf8(s, start=pos, end=end)
            pos = end
            # Try to get collect surrogates in one pass
            # XXX do we care about performance in this case?
            # XXX should this loop for more than one pair?
            delta = 1
            uchr = rutf8.codepoint_at_pos(s, pos)
            if 0xD800 <= uchr <= 0xDBFF:
                pos = rutf8.next_codepoint_pos(s, pos)
                if pos < len(s):
                    uchr = rutf8.codepoint_at_pos(s, pos)
                    if 0xDC00 <= uchr <= 0xDFFF:
                        delta += 1
            res, newindex, rettype, obj = errorhandler(errors, 'utf-8',
                        'surrogates not allowed', s, upos, upos + delta)
            if rettype == 'u':
                try:
                    rutf8.check_ascii(res)
                except rutf8.CheckError:
                    # this is a weird behaviour of CPython, but it's what happens
                    errorhandler("strict", 'utf-8', 'surrogates not allowed', s, upos, upos + delta)
                    assert 0, "unreachable"
            s = obj
            result.append(res)
            if newindex <= upos:
                raise ErrorHandlerError(newindex, upos)
            upos = newindex
            pos = rutf8._pos_at_index(s, upos)
    return result.build()

def utf8_encode_latin_1(s, errors, errorhandler, allow_surrogates=False):
    try:
        rutf8.check_ascii(s)
        return s
    except rutf8.CheckError, e:
        return _utf8_encode_latin_1_slowpath(s, e.pos, errors, errorhandler)

def _utf8_encode_latin_1_slowpath(s, first_non_ascii_char, errors, errorhandler):
    result = StringBuilder(len(s))
    result.append_slice(s, 0, first_non_ascii_char)
    pos = index = first_non_ascii_char
    while pos < len(s):
        ch = rutf8.codepoint_at_pos(s, pos)
        if ch <= 0xFF:
            result.append(chr(ch))
            index += 1
            pos = rutf8.next_codepoint_pos(s, pos)
        else:
            startindex = index
            pos = rutf8.next_codepoint_pos(s, pos)
            index += 1
            while pos < len(s) and rutf8.codepoint_at_pos(s, pos) > 0xFF:
                pos = rutf8.next_codepoint_pos(s, pos)
                index += 1
            msg = "ordinal not in range(256)"
            res, newindex, rettype, obj = errorhandler(
                errors, 'latin1', msg, s, startindex, index)
            if rettype == 'u':
                for cp in rutf8.Utf8StringIterator(res):
                    if cp > 0xFF:
                        errorhandler("strict", 'latin1', msg, s, startindex, index)
                        raise RuntimeError('error handler should not have returned')
                    result.append(chr(cp))
            else:
                for ch in res:
                    result.append(ch)
            s = obj
            if index != newindex:  # Should be uncommon
                index = newindex
                pos = rutf8._pos_at_index(s, newindex)
    return result.build()

def utf8_encode_ascii(s, errors, errorhandler, allow_surrogates=False):
    """ Don't be confused - this is a slowpath for errors e.g. "ignore"
    or an obscure errorhandler
    """
    result = StringBuilder(len(s))
    index = 0
    pos = 0
    while pos < len(s):
        ch = rutf8.codepoint_at_pos(s, pos)
        if ch <= 0x7F:
            result.append(chr(ch))
            index += 1
            pos = rutf8.next_codepoint_pos(s, pos)
        else:
            startindex = index
            pos = rutf8.next_codepoint_pos(s, pos)
            index += 1
            while pos < len(s) and rutf8.codepoint_at_pos(s, pos) > 0x7F:
                pos = rutf8.next_codepoint_pos(s, pos)
                index += 1
            msg = "ordinal not in range(128)"
            res, newindex, rettype, obj = errorhandler(
                errors, 'ascii', msg, s, startindex, index)
            if rettype == 'u':
                for cp in rutf8.Utf8StringIterator(res):
                    if cp > 0x80:
                        errorhandler("strict", 'ascii', msg, s, startindex, index)
                        raise RuntimeError('error handler should not have returned')
                    result.append(chr(cp))
            else:
                for ch in res:
                    result.append(ch)
            obj = s
            pos = rutf8._pos_at_index(s, newindex)
    return result.build()

if _WIN32:
    import pypy.interpreter.unicodehelper_win32 as win32
    def utf8_encode_mbcs(s, errors, errorhandler, allow_surrogates=False):
        return win32.utf8_encode_mbcs(s, errors, errorhandler)

    def utf8_encode_utf8(s, errors, errorhandler, allow_surrogates=False):
        return win32.utf8_encode_utf8(s, errors, errorhandler)

    def str_decode_mbcs(s, errors, final, errorhandler):
        res, size = win32.str_decode_mbcs(s, errors, errorhandler, final=final)
        return res, size, size

    def utf8_encode_oem(s, errors, errorhandler, allow_surrogates=False):
        res = win32.utf8_encode_oem(s, errors, errorhandler)
        return res

    def str_decode_oem(s, errors, final, errorhandler):
        res, size = win32.str_decode_oem(s, errors, errorhandler, final)
        return res, size, size

    def utf8_encode_code_page(cp, s, errors, errorhandler, allow_surrogates=False):
        res = win32.utf8_encode_code_page(cp, s, errors, errorhandler)
        return res

    def str_decode_code_page(cp, s, errors, final, errorhandler):
        res, size = win32.str_decode_code_page(cp, s, errors, errorhandler, final)
        return res, size, size


def str_decode_utf8(s, errors, final, errorhandler, allow_surrogates=False):
    try:
        # fast version first
        return s, rutf8.check_utf8(s, allow_surrogates=allow_surrogates), len(s)
    except rutf8.CheckError:
        return _str_decode_utf8_slowpath(
            s, errors, final, errorhandler, allow_surrogates=allow_surrogates)

def _str_decode_utf8_slowpath(s, errors, final, errorhandler, allow_surrogates):
    """ Same as checking for the valid utf8, but we know the utf8 is not
    valid so we're trying to either raise or pack stuff with error handler.
    The key difference is that this is call_may_force.

    In CPython this is done in unicode_decode_utf8, which has no
    allow_surrogates. That argument is used in at least decode_utf8sp, in
    interpreter.error._compute_value.
    """
    if errors is None:
        errors = 'strict'
    result = StringBuilder(len(s))
    pos = 0
    while pos < len(s):
        ordch1 = ord(s[pos])
        # fast path for ASCII
        # XXX maybe use a while loop here
        if ordch1 <= 0x7F:
            pos += 1
            result.append(chr(ordch1))
            continue

        n = ord(runicode._utf8_code_length[ordch1 - 0x80])
        if pos + n > len(s):
            # argh, this obscure block of code is mostly a copy of
            # what follows :-(
            charsleft = len(s) - pos - 1 # either 0, 1, 2
            # note: when we get the 'unexpected end of data' we need
            # to care about the pos returned; it can be lower than len(s),
            # in case we need to continue running this loop
            if not charsleft:
                # there's only the start byte and nothing else
                if not final:
                    break
                r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'unexpected end of data',
                                      s, pos, pos+1)
                result.append(r)
                continue
            ordch2 = ord(s[pos+1])
            if n == 3:
                # 3-bytes seq with only a continuation byte
                if rutf8._invalid_byte_2_of_3(ordch1, ordch2, allow_surrogates):
                    # second byte invalid, take the first and continue
                    r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                          'invalid continuation byte',
                                          s, pos, pos+1)
                    result.append(r)
                    continue
                else:
                    # second byte valid, but third byte missing
                    if not final:
                        break
                    r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'unexpected end of data',
                                      s, pos, pos+2)
                    result.append(r)
                    continue
            elif n == 4:
                # 4-bytes seq with 1 or 2 continuation bytes
                if rutf8._invalid_byte_2_of_4(ordch1, ordch2):
                    # second byte invalid, take the first and continue
                    r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                          'invalid continuation byte',
                                          s, pos, pos+1)
                    result.append(r)
                    continue
                elif charsleft == 2 and rutf8._invalid_byte_3_of_4(ord(s[pos+2])):
                    # third byte invalid, take the first two and continue
                    r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                          'invalid continuation byte',
                                          s, pos, pos+2)
                    result.append(r)
                    continue
                else:
                    # there's only 1 or 2 valid cb, but the others are missing
                    if not final:
                        break
                    r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'unexpected end of data',
                                      s, pos, pos+charsleft+1)
                    result.append(r)
                    continue
            raise AssertionError("unreachable")

        if n == 0:
            r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                  'invalid start byte',
                                  s, pos, pos+1)
            result.append(r)

        elif n == 1:
            assert 0, "ascii should have gone through the fast path"

        elif n == 2:
            ordch2 = ord(s[pos+1])
            if rutf8._invalid_byte_2_of_2(ordch2):
                r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'invalid continuation byte',
                                      s, pos, pos+1)
                result.append(r)
                continue
            # 110yyyyy 10zzzzzz -> 00000000 00000yyy yyzzzzzz
            result.append(chr(ordch1))
            result.append(chr(ordch2))
            pos += 2

        elif n == 3:
            ordch2 = ord(s[pos+1])
            ordch3 = ord(s[pos+2])
            if rutf8._invalid_byte_2_of_3(ordch1, ordch2, allow_surrogates):
                r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'invalid continuation byte',
                                      s, pos, pos+1)
                result.append(r)
                continue
            elif rutf8._invalid_byte_3_of_3(ordch3):
                r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'invalid continuation byte',
                                      s, pos, pos+2)
                result.append(r)
                continue
            # 1110xxxx 10yyyyyy 10zzzzzz -> 00000000 xxxxyyyy yyzzzzzz
            result.append(chr(ordch1))
            result.append(chr(ordch2))
            result.append(chr(ordch3))
            pos += 3

        elif n == 4:
            ordch2 = ord(s[pos+1])
            ordch3 = ord(s[pos+2])
            ordch4 = ord(s[pos+3])
            if rutf8._invalid_byte_2_of_4(ordch1, ordch2):
                r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'invalid continuation byte',
                                      s, pos, pos+1)
                result.append(r)
                continue
            elif rutf8._invalid_byte_3_of_4(ordch3):
                r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'invalid continuation byte',
                                      s, pos, pos+2)
                result.append(r)
                continue
            elif rutf8._invalid_byte_4_of_4(ordch4):
                r, pos, rettype, s = errorhandler(errors, 'utf-8',
                                      'invalid continuation byte',
                                      s, pos, pos+3)
                result.append(r)
                continue
            # 11110www 10xxxxxx 10yyyyyy 10zzzzzz -> 000wwwxx xxxxyyyy yyzzzzzz
            result.append(chr(ordch1))
            result.append(chr(ordch2))
            result.append(chr(ordch3))
            result.append(chr(ordch4))
            pos += 4

    r = result.build()
    # XXX can keep track of the resulting length without calling check_utf8
    # here
    return r, rutf8.check_utf8(r, True), pos

hexdigits = "0123456789ABCDEFabcdef"

def hexescape(builder, s, pos, digits,
              encoding, errorhandler, message, errors):
    chr = 0
    if pos + digits > len(s):
        endinpos = pos
        while endinpos < len(s) and s[endinpos] in hexdigits:
            endinpos += 1
        r, pos, rettype, s = errorhandler(
            errors, encoding, message, s, pos - 2, endinpos)
        builder.append(r)
    else:
        try:
            chr = int(s[pos:pos + digits], 16)
        except ValueError:
            endinpos = pos
            while s[endinpos] in hexdigits:
                endinpos += 1
            r, pos, rettype, s = errorhandler(
                errors, encoding, message, s, pos - 2, endinpos)
            builder.append(r)
        else:
            # when we get here, chr is a 32-bit unicode character
            try:
                builder.append_code(chr)
                pos += digits
            except rutf8.OutOfRange:
                message = "illegal Unicode character"
                r, pos, rettype, s = errorhandler(
                    errors, encoding, message, s, pos - 2, pos + digits)
                builder.append(r)
    return pos, s

def str_decode_unicode_escape(s, errors, final, errorhandler, ud_handler):
    if len(s) == 0:
        return '', 0, 0, None

    builder = rutf8.Utf8StringBuilder(len(s))
    pos = 0
    first_escape_error_char = None
    while pos < len(s):
        ch = s[pos]

        # Non-escape characters are interpreted as Unicode ordinals
        if ch != '\\':
            if ord(ch) > 0x7F:
                builder.append_code(ord(ch))
            else:
                builder.append(ch)
            pos += 1
            continue

        # - Escapes
        if pos + 1 >= len(s):
            if not final:
                break
            message = "\\ at end of string"
            r, pos, rettype, s = errorhandler(errors, "unicodeescape",
                                    message, s, pos - 1, len(s))
            builder.append(r)
            continue
        pos += 1

        ch = s[pos]
        pos += 1
        # \x escapes
        if ch == '\n':
            pass
        elif ch == '\\':
            builder.append_char('\\')
        elif ch == '\'':
            builder.append_char('\'')
        elif ch == '\"':
            builder.append_char('\"')
        elif ch == 'b':
            builder.append_char('\b')
        elif ch == 'f':
            builder.append_char('\f')
        elif ch == 't':
            builder.append_char('\t')
        elif ch == 'n':
            builder.append_char('\n')
        elif ch == 'r':
            builder.append_char('\r')
        elif ch == 'v':
            builder.append_char('\v')
        elif ch == 'a':
            builder.append_char('\a')
        elif '0' <= ch <= '7':
            x = ord(ch) - ord('0')
            if pos < len(s):
                ch = s[pos]
                if '0' <= ch <= '7':
                    pos += 1
                    x = (x << 3) + ord(ch) - ord('0')
                    if pos < len(s):
                        ch = s[pos]
                        if '0' <= ch <= '7':
                            pos += 1
                            x = (x << 3) + ord(ch) - ord('0')
            if x > 0x7F:
                builder.append_code(x)
            else:
                builder.append_char(chr(x))
        # hex escapes
        # \xXX
        elif ch == 'x':
            digits = 2
            if pos + digits > len(s) and not final:
                pos -= 2
                break
            message = "truncated \\xXX escape"
            pos, s = hexescape(builder, s, pos, digits,
                            "unicodeescape", errorhandler, message, errors)
        # \uXXXX
        elif ch == 'u':
            digits = 4
            if pos + digits > len(s) and not final:
                pos -= 2
                break
            message = "truncated \\uXXXX escape"
            pos, s = hexescape(builder, s, pos, digits,
                            "unicodeescape", errorhandler, message, errors)
        #  \UXXXXXXXX
        elif ch == 'U':
            digits = 8
            if pos + digits > len(s) and not final:
                pos -= 2
                break
            message = "truncated \\UXXXXXXXX escape"
            pos, s = hexescape(builder, s, pos, digits,
                            "unicodeescape", errorhandler, message, errors)
        # \N{name}
        elif ch == 'N' and ud_handler is not None:
            message = "malformed \\N character escape"
            look = pos

            if look < len(s) and s[look] == '{':
                # look for the closing brace
                while look < len(s) and s[look] != '}':
                    look += 1
                if look < len(s) and s[look] == '}':
                    # found a name.  look it up in the unicode database
                    message = "unknown Unicode character name"
                    name = s[pos + 1:look]
                    code = ud_handler.call(name)
                    if code < 0:
                        r, pos, rettype, s = errorhandler(
                            errors, "unicodeescape", message,
                            s, pos - 1, look + 1)
                        builder.append(r)
                        continue
                    pos = look + 1
                    builder.append_code(code)
                else:
                    if not final:
                        pos -= 2
                        break
                    r, pos, rettype, s = errorhandler(errors, "unicodeescape",
                                            message, s, pos - 1, look + 1)
                    builder.append(r)
            else:
                if not final:
                    pos -= 2
                    break
                r, pos, rettype, s = errorhandler(errors, "unicodeescape",

                                        message, s, pos - 1, look + 1)
                builder.append(r)
        else:
            builder.append_char('\\')
            builder.append_code(ord(ch))
            first_escape_error_char = ch

    return builder.build(), builder.getlength(), pos, first_escape_error_char

def wcharpsize2utf8(space, wcharp, size):
    """Safe version of rffi.wcharpsize2utf8.

    Raises app-level ValueError if any wchar value is outside the valid
    codepoint range.
    """
    if _WIN32:
        import pypy.interpreter.unicodehelper_win32 as win32
        # wcharp is actually utf16
        return win32._unibuf_to_utf8(wcharp, size)
    else:
        try:
            return rffi.wcharpsize2utf8(wcharp, size)
        except rutf8.OutOfRange as e:
            raise wrap_unicode_out_of_range_error(space, e)

def wrap_unicode_out_of_range_error(space, e):
    raise oefmt(space.w_ValueError,
        "character %s is not in range [U+0000; U+10ffff]", 'U+%x' % e.code)


# ____________________________________________________________
# Raw unicode escape

def str_decode_raw_unicode_escape(s, errors, final=False,
                                  errorhandler=None):
    if len(s) == 0:
        return '', 0, 0

    builder = rutf8.Utf8StringBuilder(len(s))
    pos = 0
    while pos < len(s):
        ch = s[pos]
        pos += 1

        # Non-escape characters are interpreted as Unicode ordinals
        if ch != '\\':
            builder.append_code(ord(ch))
            continue

        if pos == len(s):
            if final:
                # we have a backslash at the end of the string, stop here
                builder.append_char('\\')
            else:
                pos -= 1
            break
        ch = s[pos]
        if ch == "\\":
            builder.append_char('\\')
            pos += 1
            continue
        if s[pos] == 'u':
            digits = 4
            message = "truncated \\uXXXX escape"
        elif s[pos] == 'U':
            digits = 8
            message = "truncated \\UXXXXXXXX escape"
        else:
            builder.append_char('\\')
            builder.append_char(ch)
            pos += 1
            continue
        pos += 1
        if pos + digits > len(s) and not final:
            pos -= 2
            break
        pos, s = hexescape(builder, s, pos, digits,
                           "rawunicodeescape", errorhandler, message, errors)

    return builder.build(), builder.getlength(), pos

_utf8_encode_unicode_escape = rutf8.make_utf8_escape_function()


TABLE = '0123456789abcdef'

def raw_unicode_escape_helper(result, char):
    if char >= 0x10000 or char < 0:
        result.append("\\U")
        zeros = 8
    elif char >= 0x100:
        result.append("\\u")
        zeros = 4
    else:
        result.append("\\x")
        zeros = 2
    for i in range(zeros-1, -1, -1):
        result.append(TABLE[(char >> (4 * i)) & 0x0f])

def utf8_encode_raw_unicode_escape(s, errors, errorhandler, allow_surrogates=False):
    # errorhandler is not used: this function cannot cause Unicode errors
    size = len(s)
    if size == 0:
        return ''
    result = StringBuilder(size)
    pos = 0
    while pos < size:
        oc = rutf8.codepoint_at_pos(s, pos)

        if oc < 0x100:
            result.append(chr(oc))
        else:
            raw_unicode_escape_helper(result, oc)
        pos = rutf8.next_codepoint_pos(s, pos)

    return result.build()


def utf8_encode_unicode_escape(s, errors, errorhandler, allow_surrogates=False):
    return _utf8_encode_unicode_escape(s)

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
    if oc >= 0x10000:
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

def str_decode_utf_7(s, errors, final=False,
                     errorhandler=None):
    if len(s) == 0:
        return '', 0, 0

    inShift = False
    base64bits = 0
    base64buffer = 0
    surrogate = 0
    outsize = 0

    result = StringBuilder(len(s))
    pos = 0
    shiftOutStartPos = 0
    startinpos = 0
    while pos < len(s):
        ch = s[pos]

        if inShift: # in a base-64 section
            if _utf7_IS_BASE64(ord(ch)): #consume a base-64 character
                base64buffer = (base64buffer << 6) | _utf7_FROM_BASE64(ch)
                assert base64buffer >= 0
                base64bits += 6
                pos += 1

                if base64bits >= 16:
                    # enough bits for a UTF-16 value
                    outCh = base64buffer >> (base64bits - 16)
                    assert outCh >= 0
                    base64bits -= 16
                    base64buffer &= (1 << base64bits) - 1 # clear high bits
                    assert outCh <= 0xffff
                    if surrogate:
                        # expecting a second surrogate
                        if outCh >= 0xDC00 and outCh <= 0xDFFF:
                            code = (((surrogate & 0x3FF)<<10) |
                                        (outCh & 0x3FF)) + 0x10000
                            rutf8.unichr_as_utf8_append(result, code)
                            outsize += 1
                            surrogate = 0
                            continue
                        else:
                            rutf8.unichr_as_utf8_append(result, surrogate,
                                                        allow_surrogates=True)
                            outsize += 1
                            surrogate = 0
                            # Not done with outCh: falls back to next line
                    if outCh >= 0xD800 and outCh <= 0xDBFF:
                        # first surrogate
                        surrogate = outCh
                    else:
                        outsize += 1
                        assert outCh >= 0
                        rutf8.unichr_as_utf8_append(result, outCh, True)

            else:
                # now leaving a base-64 section
                inShift = False

                if base64bits > 0: # left-over bits
                    if base64bits >= 6:
                        # We've seen at least one base-64 character
                        pos += 1
                        msg = "partial character in shift sequence"
                        r, pos, rettype, s = errorhandler(errors, 'utf7',
                                                msg, s, pos-1, pos)
                        reslen = rutf8.check_utf8(r, True)
                        outsize += reslen
                        result.append(r)
                        continue
                    else:
                        # Some bits remain; they should be zero
                        if base64buffer != 0:
                            pos += 1
                            msg = "non-zero padding bits in shift sequence"
                            r, pos, rettype, s = errorhandler(errors, 'utf7',
                                                    msg, s, pos-1, pos)
                            reslen = rutf8.check_utf8(r, True)
                            outsize += reslen
                            result.append(r)
                            continue

                if surrogate and _utf7_DECODE_DIRECT(ord(ch)):
                    outsize += 1
                    rutf8.unichr_as_utf8_append(result, surrogate, True)
                surrogate = 0

                if ch == '-':
                    # '-' is absorbed; other terminating characters are
                    # preserved
                    pos += 1

        elif ch == '+':
            startinpos = pos
            pos += 1 # consume '+'
            if pos < len(s) and s[pos] == '-': # '+-' encodes '+'
                pos += 1
                result.append('+')
                outsize += 1
            elif pos < len(s) and not _utf7_IS_BASE64(ord(s[pos])):
                msg = "ill-formed sequence"
                r, pos, rettype, s = errorhandler(errors, 'utf7', msg, s, pos-1, pos+1)
                reslen = rutf8.check_utf8(r, True)
                outsize += reslen
                result.append(r)
            else: # begin base64-encoded section
                inShift = 1
                surrogate = 0
                shiftOutStartPos = result.getlength()
                base64bits = 0
                base64buffer = 0

        elif _utf7_DECODE_DIRECT(ord(ch)): # character decodes at itself
            result.append(ch)
            outsize += 1
            pos += 1
        else:
            startinpos = pos
            pos += 1
            msg = "unexpected special character"
            r, pos, rettype, s = errorhandler(errors, 'utf7', msg, s, pos-1, pos)
            reslen = rutf8.check_utf8(r, True)
            outsize += reslen
            result.append(r)

    # end of string
    final_length = result.getlength()
    final_size = len(s)
    if inShift and final: # in shift sequence, no more to follow
        inShift = 0
        if (surrogate or
            base64bits >= 6 or
            (base64bits > 0 and base64buffer != 0)):
            # if we're in an inconsistent state, that's an error
            msg = "unterminated shift sequence"
            r, pos, rettype, s = errorhandler(errors, 'utf7', msg, s, shiftOutStartPos, pos)
            reslen = rutf8.check_utf8(r, True)
            outsize += reslen
            result.append(r)
            final_length = result.getlength()
    elif inShift:
        final_size = startinpos
        final_length = shiftOutStartPos # back off output

    assert final_length >= 0
    return result.build()[:final_length], outsize, final_size

def utf8_encode_utf_7(s, errors, errorhandler, allow_surrogates=False):
    # only uses s, other arguments are ignored
    size = len(s)
    if size == 0:
        return ''
    result = StringBuilder(size)

    encodeSetO = encodeWhiteSpace = False

    inShift = False
    base64bits = 0
    base64buffer = 0

    pos = 0
    while pos < size:
        oc = rutf8.codepoint_at_pos(s, pos)
        if not inShift:
            if oc == ord('+'):
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
                if _utf7_IS_BASE64(oc) or oc == ord('-'):
                    result.append('-')
                result.append(chr(oc))
            else:
                base64bits, base64buffer = _utf7_ENCODE_CHAR(
                    result, oc, base64bits, base64buffer)
        pos = rutf8.next_codepoint_pos(s, pos)

    if base64bits:
        result.append(_utf7_TO_BASE64(base64buffer << (6 - base64bits)))
    if inShift:
        result.append('-')

    return result.build()

def decode_utf8sp(space, string):
    # Surrogate-preserving utf-8 decoding.  Assuming there is no
    # encoding error, it should always be reversible, and the reverse is
    # unused encode_utf8sp().
    return str_decode_utf8(string, "string", True, decode_never_raise,
                           allow_surrogates=True)

# ____________________________________________________________
# utf-16

BYTEORDER = sys.byteorder
BYTEORDER2 = BYTEORDER[0] + 'e'      # either "le" or "be"
assert BYTEORDER2 in ('le', 'be')

def str_decode_utf_16(s, errors, final=True,
                      errorhandler=None):
    return str_decode_utf_16_helper(s, errors, final, errorhandler,
                                    "native")[:3]

def str_decode_utf_16_be(s, errors, final=True,
                        errorhandler=None):
    return str_decode_utf_16_helper(s, errors, final, errorhandler, "big",
                                   'utf16-be')[:3]

def str_decode_utf_16_le(s, errors, final=True,
                         errorhandler=None):
    return str_decode_utf_16_helper(s, errors, final, errorhandler, "little",
                                    'utf16-le')[:3]

def str_decode_utf_16_helper(s, errors, final=True,
                             errorhandler=None,
                             byteorder="native",
                             public_encoding_name='utf16'):
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
        if len(s) >= 2:
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
    if len(s) == 0:
        return '', 0, 0, bo
    if bo == -1:
        # force little endian
        ihi = 1
        ilo = 0

    elif bo == 1:
        # force big endian
        ihi = 0
        ilo = 1

    result = StringBuilder(len(s) // 2)

    while pos < len(s):
        # remaining bytes at the end? (len(s) should be even)
        if len(s) - pos < 2:
            if not final:
                break
            r, pos, rettype, s = errorhandler(errors, public_encoding_name,
                                  "truncated data",
                                  s, pos, len(s))
            result.append(r)
            if len(s) - pos < 2:
                break
        ch = (ord(s[pos + ihi]) << 8) | ord(s[pos + ilo])
        pos += 2
        if ch < 0xD800 or ch > 0xDFFF:
            rutf8.unichr_as_utf8_append(result, ch)
            continue
        # unexpected low surrogate
        elif ch >= 0xDC00:
            r, pos, rettype, s = errorhandler(errors, public_encoding_name,
                                  "illegal encoding",
                                  s, pos - 2, pos)
            result.append(r)
            continue
        # UTF-16 code pair:
        if len(s) - pos < 2:
            pos -= 2
            if not final:
                break
            errmsg = "unexpected end of data"
            r, pos, rettype, s = errorhandler(errors, public_encoding_name,
                                  errmsg, s, pos, len(s))
            result.append(r)
        else:
            ch2 = (ord(s[pos+ihi]) << 8) | ord(s[pos+ilo])
            pos += 2
            if 0xDC00 <= ch2 <= 0xDFFF:
                ch = (((ch & 0x3FF)<<10) | (ch2 & 0x3FF)) + 0x10000
                rutf8.unichr_as_utf8_append(result, ch)
                continue
            else:
                r, pos, rettype, s = errorhandler(errors, public_encoding_name,
                                      "illegal UTF-16 surrogate",
                                      s, pos - 4, pos - 2)
                result.append(r)
    r = result.build()
    lgt = rutf8.check_utf8(r, True)
    return r, lgt, pos, bo

def _STORECHAR(result, CH, byteorder):
    hi = chr(((CH) >> 8) & 0xff)
    lo = chr((CH) & 0xff)
    if byteorder == 'little':
        result.append(lo)
        result.append(hi)
    else:
        result.append(hi)
        result.append(lo)

def utf8_encode_utf_16_helper(s, errors,
                                 errorhandler=None,
                                 allow_surrogates=True,
                                 byteorder='little',
                                 public_encoding_name='utf16'):
    if len(s) == 0:
        if byteorder == 'native':
            result = StringBuilder(2)
            _STORECHAR(result, 0xFEFF, BYTEORDER)
            return result.build()
        return ""

    result = StringBuilder(len(s) * 2 + 2)
    if byteorder == 'native':
        _STORECHAR(result, 0xFEFF, BYTEORDER)
        byteorder = BYTEORDER

    pos = 0
    index = 0
    while pos < len(s):
        cp = rutf8.codepoint_at_pos(s, pos)
        if cp < 0xD800:
            _STORECHAR(result, cp, byteorder)
        elif cp >= 0x10000:
            _STORECHAR(result, 0xD800 | ((cp-0x10000) >> 10), byteorder)
            _STORECHAR(result, 0xDC00 | ((cp-0x10000) & 0x3FF), byteorder)
        elif cp >= 0xE000 or allow_surrogates:
            _STORECHAR(result, cp, byteorder)
        else:
            r, newindex, rettype, s = errorhandler(
                errors, public_encoding_name, 'surrogates not allowed',
                s, index, index+1)
            if rettype == 'u':
                for cp in rutf8.Utf8StringIterator(r):
                    if cp < 0xD800 or allow_surrogates:
                        _STORECHAR(result, cp, byteorder)
                    else:
                        errorhandler('strict', public_encoding_name,
                                     'surrogates not allowed',
                                     s, index, index+1)
            else:
                for ch in r:
                    cp = ord(ch)
                    if cp < 0xD800 or allow_surrogates:
                        _STORECHAR(result, cp, byteorder)
                    else:
                        errorhandler('strict', public_encoding_name,
                                     'surrogates not allowed',
                                 s, index, index+1)
            if index != newindex:  # Should be uncommon
                index = newindex
                pos = rutf8._pos_at_index(s, newindex)
            continue
        pos = rutf8.next_codepoint_pos(s, pos)
        index += 1

    return result.build()

def utf8_encode_utf_16(s, errors,
                          errorhandler=None,
                          allow_surrogates=False):
    return utf8_encode_utf_16_helper(s, errors, errorhandler,
                                        allow_surrogates, "native",
                                        'utf-16-' + BYTEORDER2)

def utf8_encode_utf_16_be(s, errors,
                             errorhandler=None,
                             allow_surrogates=False):
    return utf8_encode_utf_16_helper(s, errors, errorhandler,
                                        allow_surrogates, "big",
                                        'utf-16-be')

def utf8_encode_utf_16_le(s, errors,
                             errorhandler=None,
                             allow_surrogates=False):
    return utf8_encode_utf_16_helper(s, errors, errorhandler,
                                        allow_surrogates, "little",
                                        'utf-16-le')

# ____________________________________________________________
# utf-32

def str_decode_utf_32(s, errors, final=True,
                      errorhandler=None):
    return str_decode_utf_32_helper(
        s, errors, final, errorhandler, "native", 'utf-32-' + BYTEORDER2,
        allow_surrogates=False)[:3]

def str_decode_utf_32_be(s, errors, final=True,
                         errorhandler=None):
    return str_decode_utf_32_helper(
        s, errors, final, errorhandler, "big", 'utf-32-be',
        allow_surrogates=False)[:3]

def str_decode_utf_32_le(s, errors, final=True,
                         errorhandler=None):
    return str_decode_utf_32_helper(
        s, errors, final, errorhandler, "little", 'utf-32-le',
        allow_surrogates=False)[:3]

BOM32_DIRECT  = intmask(0x0000FEFF)
BOM32_REVERSE = intmask(0xFFFE0000)

def str_decode_utf_32_helper(s, errors, final,
                             errorhandler,
                             byteorder="native",
                             public_encoding_name='utf32',
                             allow_surrogates=True):
    assert errorhandler is not None
    bo = 0

    if BYTEORDER == 'little':
        iorder0, iorder1, iorder2, iorder3 = 0, 1, 2, 3
    else:
        iorder0, iorder1, iorder2, iorder3 = 3, 2, 1, 0

    #  Check for BOM marks (U+FEFF) in the input and adjust current
    #  byte order setting accordingly. In native mode, the leading BOM
    #  mark is skipped, in all other modes, it is copied to the output
    #  stream as-is (giving a ZWNBSP character).
    pos = 0
    if byteorder == 'native':
        if len(s) >= 4:
            bom = intmask(
                (ord(s[iorder3]) << 24) | (ord(s[iorder2]) << 16) |
                (ord(s[iorder1]) << 8) | ord(s[iorder0]))
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
    if len(s) == 0:
        return '', 0, 0, bo
    if bo == -1:
        # force little endian
        iorder0, iorder1, iorder2, iorder3 = 0, 1, 2, 3
    elif bo == 1:
        # force big endian
        iorder0, iorder1, iorder2, iorder3 = 3, 2, 1, 0

    result = StringBuilder(len(s) // 4)

    while pos < len(s):
        # remaining bytes at the end? (len(s) should be divisible by 4)
        if len(s) - pos < 4:
            if not final:
                break
            r, pos, rettype, s = errorhandler(errors, public_encoding_name,
                                  "truncated data",
                                  s, pos, len(s))
            result.append(r)
            if len(s) - pos < 4:
                break
            continue
        ch = ((ord(s[pos + iorder3]) << 24) | (ord(s[pos + iorder2]) << 16) |
              (ord(s[pos + iorder1]) << 8)  | ord(s[pos + iorder0]))
        if not allow_surrogates and 0xD800 <= ch <= 0xDFFF:
            r, pos, rettype, obj = errorhandler(errors, public_encoding_name,
                                  "code point in surrogate code point "
                                  "range(0xd800, 0xe000)",
                                  s, pos, pos + 4)
            result.append(r)
            continue
        elif r_uint(ch) >= 0x110000:
            r, pos, rettype, s = errorhandler(errors, public_encoding_name,
                                  "codepoint not in range(0x110000)",
                                  s, pos, len(s))
            result.append(r)
            continue

        rutf8.unichr_as_utf8_append(result, ch, allow_surrogates=allow_surrogates)
        pos += 4
    r = result.build()
    lgt = rutf8.check_utf8(r, True)
    return r, lgt, pos, bo

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

def utf8_encode_utf_32_helper(s, errors,
                                 errorhandler=None,
                                 allow_surrogates=True,
                                 byteorder='little',
                                 public_encoding_name='utf32'):
    # s is utf8
    if len(s) == 0:
        if byteorder == 'native':
            result = StringBuilder(4)
            _STORECHAR32(result, 0xFEFF, BYTEORDER)
            return result.build()
        return ""

    result = StringBuilder(len(s) * 4 + 4)
    if byteorder == 'native':
        _STORECHAR32(result, 0xFEFF, BYTEORDER)
        byteorder = BYTEORDER

    pos = 0
    index = 0
    while pos < len(s):
        ch = rutf8.codepoint_at_pos(s, pos)
        if not allow_surrogates and 0xD800 <= ch < 0xE000:
            r, newindex, rettype, obj = errorhandler(
                errors, public_encoding_name, 'surrogates not allowed',
                s, index, index+1)
            if rettype == 'u':
                for ch in rutf8.Utf8StringIterator(r):
                    if ch < 0xD800:
                        _STORECHAR32(result, ch, byteorder)
                    else:
                        errorhandler(
                            'strict', public_encoding_name, 'surrogates not allowed',
                            s, index, index+1)
            else:
                for ch in r:
                    cp = ord(ch)
                    if cp < 0xD800:
                        _STORECHAR32(result, cp, byteorder)
                    else:
                        errorhandler(
                            'strict', public_encoding_name, 'surrogates not allowed',
                            s, index, index+1)
            s = obj
            if index != newindex:  # Should be uncommon
                index = newindex
                pos = rutf8._pos_at_index(s, newindex)
            continue
        pos = rutf8.next_codepoint_pos(s, pos)
        _STORECHAR32(result, ch, byteorder)
        index += 1

    return result.build()

def utf8_encode_utf_32(s, errors,
                       errorhandler=None, allow_surrogates=True):
    return utf8_encode_utf_32_helper(s, errors, errorhandler,
                                        allow_surrogates, "native",
                                        'utf-32-' + BYTEORDER2)

def utf8_encode_utf_32_be(s, errors,
                          errorhandler=None, allow_surrogates=True):
    return utf8_encode_utf_32_helper(s, errors, errorhandler,
                                        allow_surrogates, "big",
                                        'utf-32-be')

def utf8_encode_utf_32_le(s, errors,
                          errorhandler=None, allow_surrogates=True):
    return utf8_encode_utf_32_helper(s, errors, errorhandler,
                                        allow_surrogates, "little",
                                        'utf-32-le')
# ____________________________________________________________
# Charmap

ERROR_CHAR = u'\ufffe'.encode('utf8')

@specialize.argtype(4)
def str_decode_charmap(s, errors, final=False,
                       errorhandler=None, mapping=None):
    "mapping can be a rpython dictionary, or a dict-like object."

    # Default to Latin-1
    if mapping is None:
        return str_decode_latin_1(s, errors, final=final,
                                  errorhandler=errorhandler)
    if len(s) == 0:
        return '', 0, 0

    pos = 0
    result = StringBuilder(len(s))
    while pos < len(s):
        ch = s[pos]

        c = mapping.get(ord(ch), ERROR_CHAR)
        if c == ERROR_CHAR:
            r, pos, rettype, s = errorhandler(errors, "charmap",
                                  "character maps to <undefined>",
                                  s,  pos, pos + 1)
            result.append(r)
            continue
        result.append(c)
        pos += 1
    r = result.build()
    lgt = rutf8.codepoints_in_utf8(r)
    return r, lgt, pos

def utf8_encode_charmap(s, errors, errorhandler=None, mapping=None, allow_surrogates=False):
    if mapping is None:
        return utf8_encode_latin_1(s, errors, errorhandler=errorhandler)
    if len(s) == 0:
        return ''
    result = StringBuilder(len(s))
    pos = 0
    index = 0
    while pos < len(s):
        ch = rutf8.codepoint_at_pos(s, pos)
        c = mapping.get(ch, '')
        if len(c) == 0:
            # collect all unencodable chars.
            startindex = index
            pos = rutf8.next_codepoint_pos(s, pos)
            index += 1
            while (pos < len(s) and
                   mapping.get(rutf8.codepoint_at_pos(s, pos), '') == ''):
                pos = rutf8.next_codepoint_pos(s, pos)
                index += 1
            r, newindex, rettype, obj = errorhandler(errors, "charmap",
                                   "character maps to <undefined>",
                                   s, startindex, index)
            if rettype == 'u':
                for cp2 in rutf8.Utf8StringIterator(r):
                    ch2 = mapping.get(cp2, '')
                    if not ch2:
                        errorhandler(
                            "strict", "charmap", "character maps to <undefined>",
                            s,  startindex, index)
                    result.append(ch2)
            else:
                for ch in r:
                    result.append(ch)
            s = obj
            if index != newindex:  # Should be uncommon
                index = newindex
                pos = rutf8._pos_at_index(s, newindex)
            continue
        result.append(c)
        index += 1
        pos = rutf8.next_codepoint_pos(s, pos)
    return result.build()

# ____________________________________________________________
# Decimal Encoder
def unicode_encode_decimal(s, errors, errorhandler=None, allow_surrogates=False):
    """Converts whitespace to ' ', decimal characters to their
    corresponding ASCII digit and all other Latin-1 characters except
    \0 as-is. Characters outside this range (Unicode ordinals 1-256)
    are treated as errors. This includes embedded NULL bytes.
    """
    if errorhandler is None:
        errorhandler = default_error_encode
    result = StringBuilder(len(s))
    pos = 0
    i = 0
    it = rutf8.Utf8StringIterator(s)
    for ch in it:
        if unicodedb.isspace(ch):
            result.append(' ')
            i += 1
            continue
        try:
            decimal = unicodedb.decimal(ch)
        except KeyError:
            pass
        else:
            result.append(chr(48 + decimal))
            i += 1
            continue
        if 0 < ch < 256:
            result.append(chr(ch))
            i += 1
            continue
        # All other characters are considered unencodable
        start_index = i
        i += 1
        while not it.done():
            ch = rutf8.codepoint_at_pos(s, it.get_pos())
            try:
                if (0 < ch < 256 or unicodedb.isspace(ch) or
                        unicodedb.decimal(ch) >= 0):
                    break
            except KeyError:
                # not a decimal
                pass
            if it.done():
                break
            ch = next(it)
            i += 1
        end_index = i
        msg = "invalid decimal Unicode string"
        r, pos, retype, obj = errorhandler(
            errors, 'decimal', msg, s, start_index, end_index)
        for ch in rutf8.Utf8StringIterator(r):
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
            errorhandler('strict', 'decimal', msg, s, start_index, end_index)
    return result.build()
