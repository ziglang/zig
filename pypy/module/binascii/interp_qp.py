from pypy.interpreter.gateway import unwrap_spec
from rpython.rlib.rstring import StringBuilder
from pypy.module.binascii.interp_binascii import AsciiBufferUnwrapper

MAXLINESIZE = 76

# ____________________________________________________________

def hexval(c):
    if c <= '9':
        return ord(c) - ord('0')
    elif c <= 'F':
        return ord(c) - (ord('A') - 10)
    else:
        return ord(c) - (ord('a') - 10)
hexval._always_inline_ = True

@unwrap_spec(data=AsciiBufferUnwrapper, header=int)
def a2b_qp(space, data, header=0):
    "Decode a string of qp-encoded data."

    # We allocate the output same size as input, this is overkill.
    odata = StringBuilder(len(data))
    inp = 0

    while inp < len(data):
        c = data[inp]
        inp += 1
        if c == '=':
            if inp >= len(data):
                break
            # Soft line breaks
            c = data[inp]
            if c == '\n' or c == '\r':
                if c != '\n':
                    while inp < len(data) and data[inp] != '\n':
                        inp += 1
                inp += 1   # may go beyond len(data)
            elif c == '=':
                # broken case from broken python qp
                odata.append('=')
                inp += 1
            elif (inp + 1 < len(data) and
                  ('A' <= c <= 'F' or
                   'a' <= c <= 'f' or
                   '0' <= c <= '9') and
                  ('A' <= data[inp+1] <= 'F' or
                   'a' <= data[inp+1] <= 'f' or
                   '0' <= data[inp+1] <= '9')):
                # hexval
                ch = chr(hexval(c) << 4 | hexval(data[inp+1]))
                inp += 2
                odata.append(ch)
            else:
                odata.append('=')
        else:
            if header and c == '_':
                c = ' '
            odata.append(c)
    return space.newbytes(odata.build())

# ____________________________________________________________

class StringBuilderWithOneCharCancellable(object):

    def __init__(self, crlf, initial):
        self.crlf = crlf
        self.builder = StringBuilder(initial)
        self.pending = -1

    def _flush(self):
        if self.pending >= 0:
            self.builder.append(chr(self.pending))
            self.pending = -1
    _flush._always_inline_ = True

    def append(self, c):
        self._flush()
        self.pending = ord(c)

    def newline(self):
        self._flush()
        if self.crlf: self.builder.append('\r')
        self.pending = ord('\n')

    def to_hex(self, c):
        self._flush()
        uvalue = ord(c)
        self.builder.append("0123456789ABCDEF"[uvalue >> 4])
        self.builder.append("0123456789ABCDEF"[uvalue & 0xf])

    def build(self):
        self._flush()
        return self.builder.build()

@unwrap_spec(data='bufferstr', quotetabs=int, istext=int, header=int)
def b2a_qp(space, data, quotetabs=0, istext=1, header=0):
    """Encode a string using quoted-printable encoding.

On encoding, when istext is set, newlines are not encoded, and white
space at end of lines is.  When istext is not set, \\r and \\n (CR/LF) are
both encoded.  When quotetabs is set, space and tabs are encoded."""

    # See if this string is using CRLF line ends
    lf = data.find('\n')
    crlf = lf > 0 and data[lf-1] == '\r'

    # We allocate the output initially the same size as input;
    # it may need resizing.
    odata = StringBuilderWithOneCharCancellable(crlf, len(data))
    inp = 0
    linelen = 0

    while inp < len(data):
        c = data[inp]
        if (c > '~' or
            c == '=' or
            (header and c == '_') or
            (c == '.' and linelen == 0 and (inp + 1 == len(data) or
                                            data[inp+1] in '\n\r\x00')) or
            (not istext and (c == '\r' or c == '\n')) or
            ((c == '\t' or c == ' ') and (inp + 1 == len(data))) or
            (c <= ' ' and c != '\r' and c != '\n' and
             (quotetabs or (c != '\t' and c != ' ')))):
            linelen += 3
            if linelen >= MAXLINESIZE:
                odata.append('=')
                odata.newline()
                linelen = 3
            odata.append('=')
            odata.to_hex(c)
            inp += 1
        else:
            if (istext and
                (c == '\n' or (inp+1 < len(data) and c == '\r' and
                               data[inp+1] == '\n'))):
                # Protect against whitespace on end of line
                pendingnum = odata.pending
                if pendingnum == ord(' ') or pendingnum == ord('\t'):
                    odata.pending = ord('=')
                    odata.to_hex(chr(pendingnum))

                linelen = 0
                odata.newline()
                if c == '\r':
                    inp += 2
                else:
                    inp += 1
            else:
                if (inp + 1 < len(data) and
                    data[inp+1] != '\n' and
                    (linelen + 1) >= MAXLINESIZE):
                    odata.append('=')
                    odata.newline()
                    linelen = 0

                linelen += 1
                if header and c == ' ':
                    c = '_'
                odata.append(c)
                inp += 1

    return space.newbytes(odata.build())
