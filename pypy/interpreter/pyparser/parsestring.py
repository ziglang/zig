# coding: utf-8
from rpython.rlib import rutf8
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter import unicodehelper
from pypy.interpreter.pyparser.error import SyntaxError
from rpython.rlib.rstring import StringBuilder


class W_FString(W_Root):
    def __init__(self, unparsed, raw_mode, token, content_offset=0):
        assert isinstance(unparsed, str)    # utf-8 encoded string
        self.unparsed = unparsed     # but the quotes are removed
        self.raw_mode = raw_mode
        self.current_index = 0       # for astcompiler.fstring
        self.token = token
        # offset behind the start of the string, after f" (or however it
        # starts)
        self.content_offset = content_offset



# this function belongs to astbuilder.fstring somehow...

def parsestr(space, encoding, s, token=None, astbuilder=None):
    """Parses a string or unicode literal, and return usually
    a wrapped value.  If we get an f-string, then instead return
    an unparsed but unquoted W_FString instance.

    If encoding=None, the source string is ascii only.
    In other cases, the source string is in utf-8 encoding.

    When a bytes string is returned, it will be encoded with the
    original encoding.

    Yes, it's very inefficient.
    Yes, CPython has very similar code.
    """
    # we use ps as "pointer to s"
    # q is the virtual last char index of the string
    ps = 0
    quote = s[ps]
    rawmode = False
    unicode_literal = True
    saw_u = False
    saw_f = False

    # string decoration handling
    if quote == 'b' or quote == 'B':
        ps += 1
        quote = s[ps]
        unicode_literal = False
    elif quote == 'u' or quote == 'U':
        ps += 1
        quote = s[ps]
        saw_u = True
    elif quote == 'r' or quote == 'R':
        ps += 1
        quote = s[ps]
        rawmode = True
    elif quote == 'f' or quote == 'F':
        ps += 1
        quote = s[ps]
        saw_f = True

    if not saw_u:
        if quote == 'r' or quote == 'R':
            ps += 1
            quote = s[ps]
            rawmode = True
        elif quote == 'b' or quote == 'B':
            ps += 1
            quote = s[ps]
            unicode_literal = False
        elif quote == 'f' or quote == 'F':
            ps += 1
            quote = s[ps]
            saw_f = True

    if quote != "'" and quote != '"':
        raise_app_valueerror(space,
                             'Internal error: parser passed unquoted literal')
    ps += 1
    q = len(s) - 1
    if s[q] != quote:
        raise_app_valueerror(space, 'Internal error: parser passed unmatched '
                                    'quotes in literal')
    if q-ps >= 4 and s[ps] == quote and s[ps+1] == quote:
        # triple quotes
        ps += 2
        if s[q-1] != quote or s[q-2] != quote:
            raise_app_valueerror(space, 'Internal error: parser passed '
                                        'unmatched triple quotes in literal')
        q -= 2

    assert 0 <= ps <= q
    if unicode_literal:
        if saw_f:
            return W_FString(s[ps:q], rawmode, token, ps)
        elif rawmode:
            length = unicodehelper.check_utf8_or_raise(space, s, ps, q)
            return space.newutf8(s[ps:q], length)
        else:
            if encoding is None:
                substr = s[ps:q]
            else:
                length = unicodehelper.check_utf8_or_raise(space, s, ps, q)
                if "\\" not in s: # fast path, no escapes
                    return space.newutf8(s[ps:q], length)
                substr = decode_unicode_utf8(space, s, ps, q)
            r = decode_unicode_escape(space, substr, astbuilder, token)
            v, length, pos = r
            return space.newutf8(v, length)

    substr = s[ps : q]
    # Disallow non-ascii characters (but not escapes)
    for i, c in enumerate(substr):
        if ord(c) > 0x80:
            raise SyntaxError("bytes can only contain ASCII literal characters.",
                token.lineno,
                token.column + ps + i + 1)
            raise oefmt(space.w_SyntaxError,
                        )

    if rawmode or '\\' not in substr:
        return space.newbytes(substr)

    v, first_escape_error_char = _PyString_DecodeEscape(
        space, substr, 'strict', encoding)
    if first_escape_error_char != '':
        msg = "invalid escape sequence '%s'"
        if astbuilder:
            astbuilder.deprecation_warn(msg % first_escape_error_char, token)

    return space.newbytes(v)

def decode_unicode_utf8(space, s, ps, q):
    # ****The Python 2.7 version, producing UTF-32 escapes****
    # String is utf8-encoded, but 'unicode_escape' expects
    # latin-1; So multibyte sequences must be escaped.
    lis = [] # using a list to assemble the value
    end = q
    # Worst case:
    # "<92><195><164>" may become "\u005c\U000000E4" (16 bytes)
    while ps < end:
        if s[ps] == '\\':
            lis.append(s[ps])
            ps += 1
            if ps >= end or ord(s[ps]) & 0x80:
                # A multibyte sequence will follow, it will be
                # escaped like \u1234. To avoid confusion with
                # the backslash we just wrote, we emit "\u005c"
                # instead.
                lis.append("u005c")
                if ps >= end:
                    break
        if ord(s[ps]) & 0x80:
            cp = rutf8.codepoint_at_pos(s, ps)
            hexa = hex(cp + 0x10000000)
            lis.append('\\U0')
            lis.append(hexa[3:])  # Skip 0x and the leading 1
            ps = rutf8.next_codepoint_pos(s, ps)
        else:
            lis.append(s[ps])
            ps += 1
    return ''.join(lis)

def _PyString_DecodeEscape(space, s, errors, recode_encoding):
    """
    Unescape a backslash-escaped string. If recode_encoding is non-zero,
    the string is UTF-8 encoded and should be re-encoded in the
    specified encoding.
    """
    builder = StringBuilder(len(s))
    ps = 0
    end = len(s)
    first_escape_error_char = ''
    while ps < end:
        if s[ps] != '\\':
            # note that the C code has a label here.
            # the logic is the same.
            if recode_encoding and ord(s[ps]) & 0x80:
                w, ps = decode_utf8_recode(space, s, ps, end, recode_encoding)
                # Append bytes to output buffer.
                builder.append(w)
            else:
                builder.append(s[ps])
                ps += 1
            continue

        ps += 1
        if ps == end:
            raise_app_valueerror(space, 'Trailing \\ in string')
        prevps = ps
        ch = s[ps]
        ps += 1
        # XXX This assumes ASCII!
        if ch == '\n':
            pass
        elif ch == '\\':
            builder.append('\\')
        elif ch == "'":
            builder.append("'")
        elif ch == '"':
            builder.append('"')
        elif ch == 'b':
            builder.append("\010")
        elif ch == 'f':
            builder.append('\014') # FF
        elif ch == 't':
            builder.append('\t')
        elif ch == 'n':
            builder.append('\n')
        elif ch == 'r':
            builder.append('\r')
        elif ch == 'v':
            builder.append('\013') # VT
        elif ch == 'a':
            builder.append('\007') # BEL, not classic C
        elif ch in '01234567':
            # Look for up to two more octal digits
            span = ps
            span += (span < end) and (s[span] in '01234567')
            span += (span < end) and (s[span] in '01234567')
            octal = s[prevps : span]
            # emulate a strange wrap-around behavior of CPython:
            # \400 is the same as \000 because 0400 == 256
            num = int(octal, 8) & 0xFF
            builder.append(chr(num))
            ps = span
        elif ch == 'x':
            if ps+2 <= end and isxdigit(s[ps]) and isxdigit(s[ps + 1]):
                hexa = s[ps : ps + 2]
                num = int(hexa, 16)
                builder.append(chr(num))
                ps += 2
            else:
                if errors == 'strict':
                    raise_app_valueerror(
                        space, "invalid \\x escape at position %d" % (ps - 2))
                elif errors == 'replace':
                    builder.append('?')
                elif errors == 'ignore':
                    pass
                else:
                    raise oefmt(space.w_ValueError, "decoding error; "
                        "unknown error handling code: %s", errors)
                if ps+1 <= end and isxdigit(s[ps]):
                    ps += 1
        else:
            # this was not an escape, so the backslash
            # has to be added, and we start over in
            # non-escape mode.
            builder.append('\\')
            ps -= 1
            assert ps >= 0
            if first_escape_error_char == '':
                first_escape_error_char = ch
            continue
            # an arbitry number of unescaped UTF-8 bytes may follow.

    buf = builder.build()
    return buf, first_escape_error_char


def PyString_DecodeEscape(space, s, errors, recode_encoding):
    buf, first_escape_error_char = _PyString_DecodeEscape(space, s, errors, recode_encoding)
    if first_escape_error_char != '':
        msg = "invalid escape sequence '%s'"
        space.warn(space.newtext(msg % first_escape_error_char), space.w_DeprecationWarning)
    return buf, first_escape_error_char


def decode_unicode_escape(space, string, astbuilder, token):
    from pypy.interpreter.unicodehelper import str_decode_unicode_escape
    from pypy.module._codecs import interp_codecs
    state = space.fromcache(interp_codecs.CodecState)
    unicodedata_handler = state.get_unicodedata_handler(space)
    s, ulen, blen, first_escape_error_char = str_decode_unicode_escape(
        string, "strict",
        final=True,
        errorhandler=state.decode_error_handler,
        ud_handler=unicodedata_handler)
    if first_escape_error_char is not None and astbuilder is not None:
        msg = "invalid escape sequence '%s'"
        astbuilder.deprecation_warn(msg % first_escape_error_char, token)
    return s, ulen, blen

def isxdigit(ch):
    return (ch >= '0' and ch <= '9' or
            ch >= 'a' and ch <= 'f' or
            ch >= 'A' and ch <= 'F')


def check_utf8(space, s, ps, end):
    assert ps >= 0
    pt = ps
    # while (s < end && *s != '\\') s++; */ /* inefficient for u".."
    while ps < end and ord(s[ps]) & 0x80:
        ps += 1
    try:
        rutf8.check_utf8(s, True, pt, ps)
    except rutf8.CheckError as e:
        lgt, flag = rutf8.check_utf8(s, True, pt, e.pos)
        unicodehelper.decode_error_handler(space)('strict', 'utf8',
            'invalid utf-8', s, pt + lgt, pt + lgt + 1)
    return s[pt:ps]

def decode_utf8_recode(space, s, ps, end, recode_encoding):
    p = ps
    while p < end and ord(s[p]) & 0x80:
        p += 1
    lgt = unicodehelper.check_utf8_or_raise(space, s, ps, p)
    w_v = unicodehelper.encode(space, space.newutf8(s[ps:p], lgt),
                               recode_encoding)
    v = space.bytes_w(w_v)
    return v, p

def raise_app_valueerror(space, msg):
    raise OperationError(space.w_ValueError, space.newtext(msg))
