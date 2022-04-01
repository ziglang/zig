"""
The format table for standard sizes and alignments.
"""

# Note: we follow Python 2.5 in being strict about the ranges of accepted
# values when packing.

import struct

from rpython.rlib.objectmodel import specialize
from rpython.rlib.rarithmetic import r_uint, r_longlong, r_ulonglong
from rpython.rlib.rstruct import ieee
from rpython.rlib.rstruct.error import StructError, StructOverflowError
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.buffer import StringBuffer
from rpython.rlib import rarithmetic
from rpython.rlib.buffer import CannotRead, CannotWrite
from rpython.rtyper.lltypesystem import rffi

USE_FASTPATH = True    # set to False by some tests
ALLOW_SLOWPATH = True  # set to False by some tests
ALLOW_FASTPATH = True  # set to False by some tests

native_is_bigendian = struct.pack("=i", 1) == struct.pack(">i", 1)
native_is_ieee754 = float.__getformat__('double').startswith('IEEE')

@specialize.memo()
def pack_fastpath(TYPE):
    """
    Create a fast path packer for TYPE. The packer returns True is it succeded
    or False otherwise.
    """
    @specialize.argtype(0)
    def do_pack_fastpath(fmtiter, value):
        size = rffi.sizeof(TYPE)
        if (not USE_FASTPATH or
            fmtiter.bigendian != native_is_bigendian or
            not native_is_ieee754):
            raise CannotWrite
        #
        # typed_write() might raise CannotWrite
        fmtiter.wbuf.typed_write(TYPE, fmtiter.pos, value)
        if not ALLOW_FASTPATH:
            # if we are here it means that typed_write did not raise, and thus
            # the fast path was actually taken
            raise ValueError("fastpath not allowed :(")
        fmtiter.advance(size)
    #
    @specialize.argtype(0)
    def do_pack_fastpath_maybe(fmtiter, value):
        try:
            do_pack_fastpath(fmtiter, value)
        except CannotWrite:
            if not ALLOW_SLOWPATH:
                raise ValueError("fastpath not taken :(")
            return False
        else:
            return True
    #
    return do_pack_fastpath_maybe

def pack_pad(fmtiter, count):
    fmtiter.wbuf.setzeros(fmtiter.pos, count)
    fmtiter.advance(count)

def pack_char(fmtiter):
    string = fmtiter.accept_str_arg()
    if len(string) != 1:
        raise StructError("expected a string of length 1")
    c = string[0]   # string->char conversion for the annotator
    fmtiter.wbuf.setitem(fmtiter.pos, c)
    fmtiter.advance(1)

def pack_bool(fmtiter):
    c = '\x01' if fmtiter.accept_bool_arg() else '\x00'
    fmtiter.wbuf.setitem(fmtiter.pos, c)
    fmtiter.advance(1)

def _pack_string(fmtiter, string, count):
    pos = fmtiter.pos
    if len(string) < count:
        n = len(string)
        fmtiter.wbuf.setslice(pos, string)
        fmtiter.wbuf.setzeros(pos+n, count-n)
    else:
        assert count >= 0
        fmtiter.wbuf.setslice(pos, string[:count])
    fmtiter.advance(count)

def pack_string(fmtiter, count):
    string = fmtiter.accept_str_arg()
    _pack_string(fmtiter, string, count)

def pack_pascal(fmtiter, count):
    string = fmtiter.accept_str_arg()
    prefix = len(string)
    if prefix >= count:
        prefix = count - 1
        if prefix < 0:
            raise StructError("bad '0p' in struct format")
    if prefix > 255:
        prefix = 255
    fmtiter.wbuf.setitem(fmtiter.pos, chr(prefix))
    fmtiter.advance(1)
    _pack_string(fmtiter, string, count-1)


def pack_halffloat(fmtiter):
    size = 2
    fl = fmtiter.accept_float_arg()
    try:
        result = ieee.pack_float(fmtiter.wbuf, fmtiter.pos,
                                 fl, size, fmtiter.bigendian)
    except OverflowError:
        raise StructOverflowError("float too large for format 'e'")
    else:
        fmtiter.advance(size)
        return result

def make_float_packer(TYPE):
    size = rffi.sizeof(TYPE)
    def packer(fmtiter):
        fl = fmtiter.accept_float_arg()
        if TYPE is not rffi.FLOAT and pack_fastpath(TYPE)(fmtiter, fl):
            return
        # slow path
        try:
            result = ieee.pack_float(fmtiter.wbuf, fmtiter.pos,
                                     fl, size, fmtiter.bigendian)
        except OverflowError:
            assert size == 4
            raise StructOverflowError("float too large for format 'f'")
        else:
            fmtiter.advance(size)
            return result
    return packer

# ____________________________________________________________

native_int_size = struct.calcsize("l")

def min_max_acc_method(size, signed):
    if signed:
        min = -(2 ** (8*size-1))
        max = (2 ** (8*size-1)) - 1
        if size <= native_int_size:
            accept_method = 'accept_int_arg'
            min = int(min)
            max = int(max)
        else:
            accept_method = 'accept_longlong_arg'
            min = r_longlong(min)
            max = r_longlong(max)
    else:
        min = 0
        max = (2 ** (8*size)) - 1
        if size < native_int_size:
            accept_method = 'accept_int_arg'
        elif size == native_int_size:
            accept_method = 'accept_uint_arg'
            min = r_uint(min)
            max = r_uint(max)
        else:
            accept_method = 'accept_ulonglong_arg'
            min = r_ulonglong(min)
            max = r_ulonglong(max)
    return min, max, accept_method

def make_int_packer(size, signed, _memo={}):
    key = size, signed
    try:
        return _memo[key]
    except KeyError:
        pass
    min, max, accept_method = min_max_acc_method(size, signed)
    if size > 1:
        plural = "s"
    else:
        plural = ""
    errormsg = "argument out of range for %d-byte%s integer format" % (size,
                                                                       plural)
    unroll_revrange_size = unrolling_iterable(range(size-1, -1, -1))
    TYPE = get_rffi_int_type(size, signed)

    def pack_int(fmtiter):
        method = getattr(fmtiter, accept_method)
        value = method()
        if not min <= value <= max:
            raise StructError(errormsg)
        #
        if pack_fastpath(TYPE)(fmtiter, value):
            return
        #
        pos = fmtiter.pos + size - 1        
        if fmtiter.bigendian:
            for i in unroll_revrange_size:
                x = (value >> (8*i)) & 0xff
                fmtiter.wbuf.setitem(pos-i, chr(x))
        else:

            for i in unroll_revrange_size:
                fmtiter.wbuf.setitem(pos-i, chr(value & 0xff))
                value >>= 8
        fmtiter.advance(size)

    _memo[key] = pack_int
    return pack_int

# ____________________________________________________________


@specialize.memo()
def unpack_fastpath(TYPE):
    @specialize.argtype(0)
    def do_unpack_fastpath(fmtiter):
        size = rffi.sizeof(TYPE)
        buf, pos = fmtiter.get_buffer_and_pos()
        if not USE_FASTPATH:
            raise CannotRead
        #
        if not ALLOW_FASTPATH:
            raise ValueError("fastpath not allowed :(")
        # typed_read does not do any bound check, so we must call it only if
        # we are sure there are at least "size" bytes to read
        if fmtiter.can_advance(size):
            result = buf.typed_read(TYPE, pos)
            fmtiter.advance(size)
            return result
        else:
            # this will raise StructError
            fmtiter.advance(size)
            assert False, 'fmtiter.advance should have raised!'
    return do_unpack_fastpath

@specialize.argtype(0)
def unpack_pad(fmtiter, count):
    fmtiter.read(count)

@specialize.argtype(0)
def unpack_char(fmtiter):
    fmtiter.appendobj(fmtiter.read(1))

@specialize.argtype(0)
def unpack_bool(fmtiter):
    c = ord(fmtiter.read(1)[0])
    fmtiter.appendobj(bool(c))

@specialize.argtype(0)
def unpack_string(fmtiter, count):
    fmtiter.appendobj(fmtiter.read(count))

@specialize.argtype(0)
def unpack_pascal(fmtiter, count):
    if count == 0:
        raise StructError("bad '0p' in struct format")
    data = fmtiter.read(count)
    end = 1 + ord(data[0])
    if end > count:
        end = count
    fmtiter.appendobj(data[1:end])

@specialize.argtype(0)
def unpack_halffloat(fmtiter):
    data = fmtiter.read(2)
    fmtiter.appendobj(ieee.unpack_float(data, fmtiter.bigendian))

def make_ieee_unpacker(TYPE):
    @specialize.argtype(0)
    def unpack_ieee(fmtiter):
        size = rffi.sizeof(TYPE)
        if fmtiter.bigendian != native_is_bigendian or not native_is_ieee754:
            # fallback to the very slow unpacking code in ieee.py
            data = fmtiter.read(size)
            fmtiter.appendobj(ieee.unpack_float(data, fmtiter.bigendian))
            return
        ## XXX check if the following code is still needed
        ## if not str_storage_supported(TYPE):
        ##     # this happens e.g. on win32 and ARM32: we cannot read the string
        ##     # content as an array of doubles because it's not properly
        ##     # aligned. But we can read a longlong and convert to float
        ##     assert TYPE == rffi.DOUBLE
        ##     assert rffi.sizeof(TYPE) == 8
        ##     return unpack_longlong2float(fmtiter)
        try:
            # fast path
            val = unpack_fastpath(TYPE)(fmtiter)
        except CannotRead:
            # slow path: we should arrive here only if we could not unpack
            # because of alignment issues. So we copy the slice into a new
            # string, which is guaranteed to be properly aligned, and read the
            # float/double from there
            input = fmtiter.read(size)
            val = StringBuffer(input).typed_read(TYPE, 0)
        fmtiter.appendobj(float(val))
    return unpack_ieee

@specialize.argtype(0)
def unpack_longlong2float(fmtiter):
    from rpython.rlib.rstruct.runpack import runpack
    from rpython.rlib.longlong2float import longlong2float
    s = fmtiter.read(8)
    llval = runpack('q', s) # this is a bit recursive, I know
    doubleval = longlong2float(llval)
    fmtiter.appendobj(doubleval)


unpack_double = make_ieee_unpacker(rffi.DOUBLE)
unpack_float = make_ieee_unpacker(rffi.FLOAT)

# ____________________________________________________________

def get_rffi_int_type(size, signed):
    for TYPE in rffi.platform.numbertype_to_rclass:
        if (rffi.sizeof(TYPE) == size and
            rarithmetic.is_signed_integer_type(TYPE) == signed):
            return TYPE
    raise KeyError("Cannot find an int type size=%d, signed=%d" % (size, signed))

def make_int_unpacker(size, signed, _memo={}):
    try:
        return _memo[size, signed]
    except KeyError:
        pass
    if signed:
        if size <= native_int_size:
            inttype = int
        else:
            inttype = r_longlong
    else:
        if size < native_int_size:
            inttype = int
        elif size == native_int_size:
            inttype = r_uint
        else:
            inttype = r_ulonglong
    unroll_range_size = unrolling_iterable(range(size))
    TYPE = get_rffi_int_type(size, signed)

    @specialize.argtype(0)
    def unpack_int_fastpath_maybe(fmtiter):
        if fmtiter.bigendian != native_is_bigendian or not native_is_ieee754:
            return False
        try:
            intvalue = unpack_fastpath(TYPE)(fmtiter)
        except CannotRead:
            return False
        if not signed and size < native_int_size:
            intvalue = rarithmetic.intmask(intvalue)
        intvalue = inttype(intvalue)
        fmtiter.appendobj(intvalue)
        return True

    @specialize.argtype(0)
    def unpack_int(fmtiter):
        if unpack_int_fastpath_maybe(fmtiter):
            return
        # slow path
        if not ALLOW_SLOWPATH:
            # we enter here only on some tests
            raise ValueError("fastpath not taken :(")
        intvalue = inttype(0)
        s = fmtiter.read(size)
        idx = 0
        if fmtiter.bigendian:
            for i in unroll_range_size:
                x = ord(s[idx])
                if signed and i == 0 and x >= 128:
                    x -= 256
                intvalue <<= 8
                intvalue |= inttype(x)
                idx += 1
        else:
            for i in unroll_range_size:
                x = ord(s[idx])
                if signed and i == size - 1 and x >= 128:
                    x -= 256
                intvalue |= inttype(x) << (8*i)
                idx += 1
        fmtiter.appendobj(intvalue)

    _memo[size, signed] = unpack_int
    return unpack_int

# ____________________________________________________________

standard_fmttable = {
    'x':{ 'size' : 1, 'pack' : pack_pad, 'unpack' : unpack_pad,
          'needcount' : True },
    'c':{ 'size' : 1, 'pack' : pack_char, 'unpack' : unpack_char},
    's':{ 'size' : 1, 'pack' : pack_string, 'unpack' : unpack_string,
          'needcount' : True },
    'p':{ 'size' : 1, 'pack' : pack_pascal, 'unpack' : unpack_pascal,
          'needcount' : True },
    'e':{ 'size' : 2, 'pack' : pack_halffloat,
                    'unpack' : unpack_halffloat},
    'f':{ 'size' : 4, 'pack' : make_float_packer(rffi.FLOAT),
                    'unpack' : unpack_float},
    'd':{ 'size' : 8, 'pack' : make_float_packer(rffi.DOUBLE),
                    'unpack' : unpack_double},
    '?':{ 'size' : 1, 'pack' : pack_bool, 'unpack' : unpack_bool},
    }

for c, size in [('b', 1), ('h', 2), ('i', 4), ('l', 4), ('q', 8)]:
    standard_fmttable[c] = {'size': size,
                            'pack': make_int_packer(size, True),
                            'unpack': make_int_unpacker(size, True)}
    standard_fmttable[c.upper()] = {'size': size,
                                    'pack': make_int_packer(size, False),
                                    'unpack': make_int_unpacker(size, False)}
