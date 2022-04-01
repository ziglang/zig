from rpython.rlib import jit
from rpython.rlib.buffer import SubBuffer
from rpython.rlib.mutbuffer import MutableStringBuffer
from rpython.rlib.rarithmetic import r_uint, widen
from rpython.rlib.rstruct.error import StructError, StructOverflowError
from rpython.rlib.rstruct.formatiterator import CalcSizeFormatIterator

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.typedef import TypeDef, interp_attrproperty
from pypy.interpreter.typedef import make_weakref_descr
from pypy.module.struct.formatiterator import (
    PackFormatIterator, UnpackFormatIterator
)


class Cache:
    def __init__(self, space):
        self.error = space.new_exception_class("struct.error", space.w_Exception)


def get_error(space):
    return space.fromcache(Cache).error


def _calcsize(space, format):
    fmtiter = CalcSizeFormatIterator()
    try:
        fmtiter.interpret(format)
    except StructOverflowError as e:
        raise OperationError(space.w_OverflowError, space.newtext(e.msg))
    except StructError as e:
        raise OperationError(get_error(space), space.newtext(e.msg))
    return fmtiter.totalsize


def text_or_bytes_w(space, w_input):
    # why does CPython do this??
    if space.isinstance_w(w_input, space.w_bytes):
        return space.bytes_w(w_input)
    else:
        return space.text_w(w_input)

def calcsize(space, w_format):
    """Return size of C struct described by format string fmt."""
    format = text_or_bytes_w(space, w_format)
    return space.newint(_calcsize(space, format))


def _pack(space, format, args_w):
    """Return string containing values v1, v2, ... packed according to fmt."""
    size = _calcsize(space, format)
    wbuf = MutableStringBuffer(size)
    fmtiter = PackFormatIterator(space, wbuf, args_w)
    try:
        fmtiter.interpret(format)
    except StructOverflowError as e:
        raise OperationError(space.w_OverflowError, space.newtext(e.msg))
    except StructError as e:
        raise OperationError(get_error(space), space.newtext(e.msg))
    assert fmtiter.pos == wbuf.getlength(), 'missing .advance() or wrong calcsize()'
    return wbuf.finish()


def pack(space, w_format, args_w):
    """Return string containing values v1, v2, ... packed according to fmt."""
    format = text_or_bytes_w(space, w_format)
    return do_pack(space, format, args_w)

def do_pack(space, format, args_w):
    return space.newbytes(_pack(space, format, args_w))


@unwrap_spec(offset=int)
def pack_into(space, w_format, w_buffer, offset, args_w):
    """ Pack the values v1, v2, ... according to fmt.
Write the packed bytes into the writable buffer buf starting at offset
    """
    format = text_or_bytes_w(space, w_format)
    return do_pack_into(space, format, w_buffer, offset, args_w)

def do_pack_into(space, format, w_buffer, offset, args_w):
    """ Pack the values v1, v2, ... according to fmt.
Write the packed bytes into the writable buffer buf starting at offset
    """
    size = _calcsize(space, format)
    buf = space.writebuf_w(w_buffer)
    buflen = buf.getlength()
    if offset < 0:
        # Check that negative offset is low enough to fit data
        if offset + size > 0:
            raise oefmt(get_error(space),
                        "no space to pack %d bytes at offset %d",
                        size,
                        offset)
        # Check that negative offset is not crossing buffer boundary
        if offset + buflen < 0:
            raise oefmt(get_error(space),
                        "offset %d out of range for %d-byte buffer",
                        offset,
                        buflen)
        offset += buflen
    if (buflen - offset) < size:
        raise oefmt(get_error(space),
                    "pack_into requires a buffer of at least %d bytes for "
                    "packing %d bytes at offset %d "
                    "(actual buffer size is %d)",
                    r_uint(size + offset),
                    size,
                    offset,
                    buflen)
    #
    wbuf = SubBuffer(buf, offset, size)
    fmtiter = PackFormatIterator(space, wbuf, args_w)
    try:
        fmtiter.interpret(format)
    except StructOverflowError as e:
        raise OperationError(space.w_OverflowError, space.newtext(e.msg))
    except StructError as e:
        raise OperationError(get_error(space), space.newtext(e.msg))


def _unpack(space, format, buf):
    fmtiter = UnpackFormatIterator(space, buf)
    try:
        fmtiter.interpret(format)
    except StructOverflowError as e:
        raise OperationError(space.w_OverflowError, space.newtext(e.msg))
    except StructError as e:
        raise OperationError(get_error(space), space.newtext(e.msg))
    return space.newtuple(fmtiter.result_w[:])


def unpack(space, w_format, w_str):
    format = text_or_bytes_w(space, w_format)
    return do_unpack(space, format, w_str)

def do_unpack(space, format, w_str):
    buf = space.readbuf_w(w_str)
    return _unpack(space, format, buf)


@unwrap_spec(offset=int)
def unpack_from(space, w_format, w_buffer, offset=0):
    """Unpack the buffer, containing packed C structure data, according to
fmt, starting at offset. Requires len(buffer[offset:]) >= calcsize(fmt)."""
    format = text_or_bytes_w(space, w_format)
    return do_unpack_from(space, format, w_buffer, offset)

def do_unpack_from(space, format, w_buffer, offset=0):
    """Unpack the buffer, containing packed C structure data, according to
fmt, starting at offset. Requires len(buffer[offset:]) >= calcsize(fmt)."""
    s_size = _calcsize(space, format)
    buf = space.readbuf_w(w_buffer)
    buf_length = buf.getlength()
    if offset < 0:
        if offset + s_size > 0:
            raise oefmt(get_error(space),
                    "not enough data to unpack %d bytes at offset %d",
                    s_size, offset)
        if offset + buf_length < 0:
            raise oefmt(get_error(space),
                    "offset %d out of range for %d-byte buffer",
                    offset, buf_length)
        offset += buf_length
    if buf_length - offset < s_size:
        raise oefmt(get_error(space),
                    "unpack_from requires a buffer of at least %d bytes for "
                    "unpacking %d bytes at offset %d "
                    "(actual buffer size is %d)",
                    r_uint(s_size + offset), s_size, offset, buf_length)
    buf = SubBuffer(buf, offset, s_size)
    return _unpack(space, format, buf)


class W_UnpackIter(W_Root):
    def __init__(self, space, w_struct, w_buffer):
        buf = space.readbuf_w(w_buffer)
        if w_struct.size <= 0:
            raise oefmt(get_error(space),
                "cannot iteratively unpack with a struct of length %d",
                w_struct.size)
        if buf.getlength() % w_struct.size != 0:
            raise oefmt(get_error(space),
                "iterative unpacking requires a bytes length multiple of %d",
                w_struct.size)
        self.w_struct = w_struct
        self.buf = buf
        self.index = 0

    def descr_iter(self, space):
        return self

    def descr_next(self, space):
        if self.w_struct is None:
            raise OperationError(space.w_StopIteration, space.w_None)
        if self.index >= self.buf.getlength():
            raise OperationError(space.w_StopIteration, space.w_None)
        size = self.w_struct.size
        buf = SubBuffer(self.buf, self.index, size)
        w_res = _unpack(space, self.w_struct.format, buf)
        self.index += size
        return w_res

    def descr_length_hint(self, space):
        if self.w_struct is None:
            return space.newint(0)
        length = (self.buf.getlength() - self.index) // self.w_struct.size
        return space.newint(length)


class W_Struct(W_Root):
    _immutable_fields_ = ["format", "size"]

    format = ""
    size = -1

    def descr__new__(space, w_subtype, __args__):
        return space.allocate_instance(W_Struct, w_subtype)

    def descr__init__(self, space, w_format):
        format = text_or_bytes_w(space, w_format)
        self.format = format
        self.size = _calcsize(space, format)

    def descr_pack(self, space, args_w):
        return do_pack(space, jit.promote_string(self.format), args_w)

    @unwrap_spec(offset=int)
    def descr_pack_into(self, space, w_buffer, offset, args_w):
        return do_pack_into(space, jit.promote_string(self.format), w_buffer, offset, args_w)

    def descr_unpack(self, space, w_str):
        return do_unpack(space, jit.promote_string(self.format), w_str)

    @unwrap_spec(offset=int)
    def descr_unpack_from(self, space, w_buffer, offset=0):
        return do_unpack_from(space, jit.promote_string(self.format), w_buffer, offset)

    def descr_iter_unpack(self, space, w_buffer):
        return W_UnpackIter(space, self, w_buffer)

W_Struct.typedef = TypeDef("Struct",
    __new__=interp2app(W_Struct.descr__new__.im_func),
    __init__=interp2app(W_Struct.descr__init__),
    format=interp_attrproperty("format", cls=W_Struct, wrapfn="newtext"),
    size=interp_attrproperty("size", cls=W_Struct, wrapfn="newint"),

    pack=interp2app(W_Struct.descr_pack),
    unpack=interp2app(W_Struct.descr_unpack),
    pack_into=interp2app(W_Struct.descr_pack_into),
    unpack_from=interp2app(W_Struct.descr_unpack_from),
    iter_unpack=interp2app(W_Struct.descr_iter_unpack),
    __weakref__=make_weakref_descr(W_Struct),
)

W_UnpackIter.typedef = TypeDef("unpack_iterator",
    __iter__=interp2app(W_UnpackIter.descr_iter),
    __next__=interp2app(W_UnpackIter.descr_next),
    __length_hint__=interp2app(W_UnpackIter.descr_length_hint)
)

def iter_unpack(space, w_format, w_buffer):
    w_struct = W_Struct()
    w_struct.descr__init__(space, w_format)
    return W_UnpackIter(space, w_struct, w_buffer)

def clearcache(space):
    """No-op on PyPy"""
