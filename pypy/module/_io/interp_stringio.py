from rpython.rlib.rutf8 import (
    codepoints_in_utf8, codepoint_at_pos, Utf8StringIterator,
    Utf8StringBuilder)
from rpython.rlib.signature import signature, finishsigs
from rpython.rlib import types

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.typedef import (
    TypeDef, generic_new_descr, GetSetProperty)
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.module._io.interp_textio import (
    W_TextIOBase, W_IncrementalNewlineDecoder)
from pypy.module._io.interp_iobase import convert_size
from pypy.objspace.std.unicodeobject import W_UnicodeObject


def _find_end(start, size, total):
        available = total - start
        if size >= 0 and size <= available:
            end = start + size
        else:
            end = total
        assert 0 <= start and 0 <= end
        return end

class UnicodeIO(object):
    def __init__(self, data=None):
        if data is None:
            data = ''
        self.data = []
        self.write(data, 0)

    def resize(self, newlength):
        if len(self.data) > newlength:
            self.data = self.data[:newlength]
        if len(self.data) < newlength:
            self.data.extend([u'\0'] * (newlength - len(self.data)))

    def read(self, start, size):
        end = _find_end(start, size, len(self.data))
        return u''.join(self.data[start:end])

    def _convert_limit(self, limit, start):
        if limit < 0 or limit > len(self.data) - start:
            limit = len(self.data) - start
            if limit < 0:  # happens when self.pos > len(self.data)
                limit = 0
        return limit

    def readline_universal(self, start, limit):
        # Universal newline search. Find any of \r, \r\n, \n
        limit = self._convert_limit(limit, start)
        end = start + limit
        pos = start
        while pos < end:
            ch = self.data[pos]
            pos += 1
            if ch == u'\n':
                break
            if ch == u'\r':
                if pos >= end:
                    break
                if self.data[pos] == u'\n':
                    pos += 1
                    break
                else:
                    break
        result = u''.join(self.data[start:pos])
        return result

    def readline(self, marker, start, limit):
        limit = self._convert_limit(limit, start)
        end = start + limit
        found = False
        marker = marker.decode('utf-8')
        for pos in range(start, end - len(marker) + 1):
            ch = self.data[pos]
            if ch == marker[0]:
                for j in range(1, len(marker)):
                    if self.data[pos + j] != marker[j]:
                        break  # from inner loop
                else:
                    pos += len(marker)
                    found = True
                    break
        if not found:
            pos = end
        result = u''.join(self.data[start:pos])
        return result

    def write(self, string, start):
        ustr = string.decode('utf-8')
        newlen = start + len(ustr)
        if newlen > len(self.data):
            self.resize(newlen)
        for i in range(len(ustr)):
            self.data[start + i] = ustr[i]
        return len(ustr)

    def truncate(self, size):
        if size < len(self.data):
            self.resize(size)

    def getvalue(self):
        return u''.join(self.data).encode('utf-8')

READING, ACCUMULATING, RWBUFFER, CLOSED = range(4)

@finishsigs
class W_StringIO(W_TextIOBase):
    def __init__(self, space):
        W_TextIOBase.__init__(self, space)
        self.buf = None
        self.w_value = W_UnicodeObject.EMPTY
        self.builder = None
        self.pos = 0
        self.state = READING

    def get_length(self):
        """Return the total size (in codepoints) of the object"""
        if self.state == READING:
            return self.w_value._len()
        elif self.state == ACCUMULATING:
            return self.builder.getlength()
        else:
            return len(self.buf.data)

    def _init_newline(self, space, w_newline):
        self.w_decoder = None
        self.readnl = None
        self.writenl = None

        if space.is_w(w_newline, space.w_None):
            newline = None
        elif space.isinstance_w(w_newline, space.w_unicode):
            newline = space.utf8_w(w_newline)
        else:
            raise oefmt(space.w_TypeError,
                 "newline must be str or None, not %T", w_newline)

        if (newline is not None and newline != "" and newline != "\n" and
                newline != "\r" and newline != "\r\n"):
            # Not using oefmt() because I don't know how to use it
            # with unicode
            raise OperationError(space.w_ValueError,
                space.mod(
                    space.newtext("illegal newline value: %s"), w_newline
                )
            )
        if newline is not None:
            self.readnl = newline
        self.readuniversal = newline is None or newline == ""
        self.readtranslate = newline is None
        if newline and newline[0] == "\r":
            self.writenl = newline
        if self.readuniversal:
            self.w_decoder = space.call_function(
                space.gettypefor(W_IncrementalNewlineDecoder),
                space.w_None,
                space.newint(int(self.readtranslate))
            )


    @unwrap_spec(w_newline = WrappedDefault(u"\n"))
    def descr_init(self, space, w_initvalue=None, w_newline=None):
        # In case __init__ is called multiple times
        self.buf = None
        self.pos = 0
        self._init_newline(space, w_newline)

        if not space.is_none(w_initvalue):
            self.w_value = self._decode_string(space, w_initvalue)
        else:
            self.w_value = W_UnicodeObject.EMPTY
        self.state = READING

    def descr_getstate(self, space):
        w_initialval = self.getvalue_w(space)
        w_dict = space.call_method(self.getdict(space), "copy")
        readnl = self.readnl
        if readnl is None:
            w_readnl = space.w_None
        else:
            w_readnl = space.str(space.newutf8(readnl, codepoints_in_utf8(readnl)))  # YYY
        return space.newtuple([
            w_initialval, w_readnl, space.newint(self.pos), w_dict
        ])

    def descr_setstate(self, space, w_state):
        self._check_closed(space)

        # We allow the state tuple to be longer than 4, because we may need
        # someday to extend the object's state without breaking
        # backwards-compatibility
        if (not space.isinstance_w(w_state, space.w_tuple)
                or space.len_w(w_state) < 4):
            raise oefmt(space.w_TypeError,
                        "%T.__setstate__ argument should be a 4-tuple, got %T",
                        self, w_state)
        w_initval, w_readnl, w_pos, w_dict = space.unpackiterable(w_state, 4)
        self.w_value = space.interp_w(W_UnicodeObject, w_initval)
        self.buf = None
        self.builder = None
        self.state = READING
        self._init_newline(space, w_readnl)

        pos = space.getindex_w(w_pos, space.w_TypeError)
        if pos < 0:
            raise oefmt(space.w_ValueError,
                        "position value cannot be negative")
        self.pos = pos
        if not space.is_w(w_dict, space.w_None):
            if not space.isinstance_w(w_dict, space.w_dict):
                raise oefmt(
                    space.w_TypeError,
                    "fourth item of state should be a dict, got a %T", w_dict)
            # Alternatively, we could replace the internal dictionary
            # completely. However, it seems more practical to just update it.
            space.call_method(self.getdict(space), "update", w_dict)

    def _check_closed(self, space, message=None):
        if self.state == CLOSED:
            if message is None:
                message = "I/O operation on closed file"
            raise OperationError(space.w_ValueError, space.newtext(message))

    @signature(
        types.self(), types.any(), types.any(),
        returns=types.instance(W_UnicodeObject))
    def _decode_string(self, space, w_obj):
        if not space.isinstance_w(w_obj, space.w_unicode):
            raise oefmt(space.w_TypeError,
                        "unicode argument expected, got '%T'", w_obj)
        self._check_closed(space)

        if self.w_decoder is not None:
            w_decoded = space.call_method(
                self.w_decoder, "decode", w_obj, space.w_True)
        else:
            w_decoded = w_obj
        writenl = self.writenl
        if writenl is not None:
            w_decoded = space.call_method(
                w_decoded, "replace",
                space.newtext("\n"),
                space.newutf8(writenl, codepoints_in_utf8(writenl)),
            )
        w_decoded = space.interp_w(W_UnicodeObject, w_decoded)
        return w_decoded

    def write_w(self, space, w_obj):
        w_decoded = self._decode_string(space, w_obj)
        string = space.utf8_w(w_decoded)
        orig_size = space.len_w(w_obj)
        if not string:
            return space.newint(orig_size)
        if self.state == READING:
            if self.pos == self.get_length():
                # switch to ACCUMULATING
                self.builder = Utf8StringBuilder()
                self.builder.append_utf8(self.w_value._utf8, self.w_value._len())
                self.w_value = None
                self.state = ACCUMULATING
            else:
                # switch to RWBUFFER
                self.buf = UnicodeIO(space.utf8_w(self.w_value))
                self.w_value = None
                self.state = RWBUFFER
        elif self.state == ACCUMULATING and self.pos != self.get_length():
            s = self.builder.build()
            self.buf = UnicodeIO(s)
            self.builder = None
            self.state = RWBUFFER

        if self.state == ACCUMULATING:
            written = w_decoded._len()
            self.builder.append_utf8(string, written)
        else:
            assert self.state == RWBUFFER
            written = self.buf.write(string, self.pos)
        self.pos += written
        return space.newint(orig_size)

    def _realize(self, space):
        """Switch from ACCUMULATING to READING"""
        s = self.builder.build()
        length = self.builder.getlength()
        self.w_value = space.newutf8(s, length)
        self.builder = None
        self.state = READING

    def read_w(self, space, w_size=None):
        self._check_closed(space)
        size = convert_size(space, w_size)
        if self.pos >= self.get_length():
            return W_UnicodeObject.EMPTY
        if self.state == ACCUMULATING:
            self._realize(space)
        if self.state == READING:
            length = self.w_value._len()
            end = _find_end(self.pos, size, length)
            if self.pos > end:
                return space.newutf8('', 0)
            w_res = self.w_value._unicode_sliced(space, self.pos, end)
            self.pos = end
            return w_res
        assert self.state == RWBUFFER
        result_u = self.buf.read(self.pos, size)
        self.pos += len(result_u)
        return space.newutf8(result_u.encode('utf-8'), len(result_u))

    def readline_w(self, space, w_limit=None):
        self._check_closed(space)
        limit = convert_size(space, w_limit)
        if self.pos >= self.get_length():
            return W_UnicodeObject.EMPTY
        if self.state == ACCUMULATING:
            self._realize(space)
        if self.state == READING:
            length = self.w_value._len()
            end = _find_end(self.pos, limit, length)
            if self.readuniversal:
                start = self.pos
                start_offset = self.w_value._index_to_byte(start)
                it = Utf8StringIterator(self.w_value._utf8)
                it._pos = start_offset
                for ch in it:
                    if self.pos >= end:
                        break
                    if ch == ord(u'\n'):
                        self.pos += 1
                        break
                    elif ch == ord(u'\r'):
                        self.pos += 1
                        if self.pos >= end:
                            break
                        if it.next() == ord(u'\n'):
                            self.pos += 1
                            break
                        else:
                            # `it` has gone one char too far, but we don't care
                            break
                    self.pos += 1
                w_res = self.w_value._unicode_sliced(space, start, self.pos)
                return w_res
            else:
                if self.readtranslate:
                    # Newlines are already translated, only search for \n
                    newline = '\n'
                else:
                    newline = self.readnl

                start = self.pos
                start_offset = self.w_value._index_to_byte(start)
                it = Utf8StringIterator(self.w_value._utf8)
                it._pos = start_offset
                for ch in it:
                    if self.pos >= end:
                        break
                    self.pos += 1
                    if ch == ord(newline[0]):
                        if len(newline) == 1 or self.pos >= end:
                            break
                        else:
                            ch = codepoint_at_pos(self.w_value._utf8, it.get_pos())
                            if ch == ord(newline[1]):
                                self.pos += 1
                                break
                            else:
                                continue
                w_res = self.w_value._unicode_sliced(space, start, self.pos)
                return w_res

        if self.readuniversal:
            result_u = self.buf.readline_universal(self.pos, limit)
        else:
            if self.readtranslate:
                # Newlines are already translated, only search for \n
                newline = '\n'
            else:
                newline = self.readnl
            result_u = self.buf.readline(newline, self.pos, limit)
        self.pos += len(result_u)
        return space.newutf8(result_u.encode('utf-8'), len(result_u))

    @unwrap_spec(pos=int, mode=int)
    def seek_w(self, space, pos, mode=0):
        self._check_closed(space)

        if not 0 <= mode <= 2:
            raise oefmt(space.w_ValueError,
                        "Invalid whence (%d, should be 0, 1 or 2)", mode)
        elif mode == 0 and pos < 0:
            raise oefmt(space.w_ValueError, "Negative seek position %d", pos)
        elif mode != 0 and pos != 0:
            raise oefmt(space.w_IOError, "Can't do nonzero cur-relative seeks")

        # XXX: this makes almost no sense, but its how CPython does it.
        if mode == 1:
            pos = self.pos
        elif mode == 2:
            pos = self.get_length()
        assert pos >= 0
        self.pos = pos
        return space.newint(pos)

    def truncate_w(self, space, w_size=None):
        self._check_closed(space)
        if space.is_none(w_size):
            size = self.pos
        else:
            size = space.int_w(w_size)
        if size < 0:
            raise oefmt(space.w_ValueError, "Negative size value %d", size)
        if self.state == ACCUMULATING:
            self._realize(space)
        if self.state == READING:
            if size < self.w_value._len():
                self.w_value = self.w_value._unicode_sliced(space, 0, size)
        else:
            self.buf.truncate(size)
        return space.newint(size)

    def getvalue_w(self, space):
        self._check_closed(space)
        if self.state == ACCUMULATING:
            self._realize(space)
        if self.state == READING:
            return self.w_value
        v = self.buf.getvalue()
        lgt = codepoints_in_utf8(v)
        return space.newutf8(v, lgt)

    def readable_w(self, space):
        self._check_closed(space)
        return space.w_True

    def writable_w(self, space):
        self._check_closed(space)
        return space.w_True

    def seekable_w(self, space):
        self._check_closed(space)
        return space.w_True

    def close_w(self, space):
        self.buf = None
        self.state = CLOSED

    def needs_finalizer(self):
        # 'self.buf = None' is not necessary when the object goes away
        return type(self) is not W_StringIO

    def closed_get_w(self, space):
        return space.newbool(self.state == CLOSED)

    def line_buffering_get_w(self, space):
        return space.w_False

    def newlines_get_w(self, space):
        if self.w_decoder is None:
            return space.w_None
        return space.getattr(self.w_decoder, space.newtext("newlines"))


W_StringIO.typedef = TypeDef(
    '_io.StringIO', W_TextIOBase.typedef,
    __new__  = generic_new_descr(W_StringIO),
    __init__ = interp2app(W_StringIO.descr_init),
    __getstate__ = interp2app(W_StringIO.descr_getstate),
    __setstate__ = interp2app(W_StringIO.descr_setstate),
    write = interp2app(W_StringIO.write_w),
    read = interp2app(W_StringIO.read_w),
    readline = interp2app(W_StringIO.readline_w),
    seek = interp2app(W_StringIO.seek_w),
    truncate = interp2app(W_StringIO.truncate_w),
    getvalue = interp2app(W_StringIO.getvalue_w),
    readable = interp2app(W_StringIO.readable_w),
    writable = interp2app(W_StringIO.writable_w),
    seekable = interp2app(W_StringIO.seekable_w),
    close = interp2app(W_StringIO.close_w),
    closed = GetSetProperty(W_StringIO.closed_get_w),
    line_buffering = GetSetProperty(W_StringIO.line_buffering_get_w),
    newlines = GetSetProperty(W_StringIO.newlines_get_w),
)
