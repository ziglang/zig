from rpython.rlib.rstring import StringBuilder
from rpython.rlib.rutf8 import Utf8StringIterator

HEX = '0123456789abcdef'

ESCAPE_DICT = {
    '\b': '\\b',
    '\f': '\\f',
    '\n': '\\n',
    '\r': '\\r',
    '\t': '\\t',
}
ESCAPE_BEFORE_SPACE = [ESCAPE_DICT.get(chr(_i), '\\u%04x' % _i)
                       for _i in range(32)]


def raw_encode_basestring_ascii(space, w_unicode):
    u = space.utf8_w(w_unicode)
    for i in range(len(u)):
        c = ord(u[i])
        if c < 32 or c > 126 or c == ord('\\') or c == ord('"'):
            break
    else:
        # The unicode string 'u' contains only safe characters.
        return w_unicode

    sb = StringBuilder(len(u) + 20)

    for c in Utf8StringIterator(u):
        if c <= ord('~'):
            if c == ord('"') or c == ord('\\'):
                sb.append('\\')
            elif c < ord(' '):
                sb.append(ESCAPE_BEFORE_SPACE[c])
                continue
            sb.append(chr(c))
        else:
            if c <= ord(u'\uffff'):
                sb.append('\\u')
                sb.append(HEX[c >> 12])
                sb.append(HEX[(c >> 8) & 0x0f])
                sb.append(HEX[(c >> 4) & 0x0f])
                sb.append(HEX[c & 0x0f])
            else:
                # surrogate pair
                n = c - 0x10000
                s1 = 0xd800 | ((n >> 10) & 0x3ff)
                sb.append('\\ud')
                sb.append(HEX[(s1 >> 8) & 0x0f])
                sb.append(HEX[(s1 >> 4) & 0x0f])
                sb.append(HEX[s1 & 0x0f])
                s2 = 0xdc00 | (n & 0x3ff)
                sb.append('\\ud')
                sb.append(HEX[(s2 >> 8) & 0x0f])
                sb.append(HEX[(s2 >> 4) & 0x0f])
                sb.append(HEX[s2 & 0x0f])

    res = sb.build()
    return space.newtext(res)
