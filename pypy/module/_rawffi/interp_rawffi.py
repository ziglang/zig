import sys
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.buffer import SimpleView
from pypy.interpreter.error import OperationError, oefmt, wrap_oserror
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import interp_attrproperty
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.interpreter.unicodehelper import wcharpsize2utf8
from pypy.interpreter.unicodehelper import wrap_unicode_out_of_range_error

from rpython.rlib.clibffi import *
from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rffi_platform
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib import rutf8
from rpython.rlib.objectmodel import specialize
import rpython.rlib.rposix as rposix

_MS_WINDOWS = os.name == "nt"

if _MS_WINDOWS:
    from rpython.rlib import rwin32

from rpython.tool.sourcetools import func_with_new_name
from rpython.rlib.rarithmetic import intmask, r_uint
from pypy.module._rawffi.buffer import RawFFIBuffer
from pypy.module._rawffi.tracker import tracker

BIGENDIAN = sys.byteorder == 'big'

TYPEMAP = {
    # XXX A mess with unsigned/signed/normal chars :-/
    'c' : ffi_type_uchar,
    'b' : ffi_type_schar,
    'B' : ffi_type_uchar,
    'h' : ffi_type_sshort,
    'u' : cast_type_to_ffitype(lltype.UniChar),
    'H' : ffi_type_ushort,
    'i' : cast_type_to_ffitype(rffi.INT),
    'I' : cast_type_to_ffitype(rffi.UINT),
    'l' : cast_type_to_ffitype(rffi.LONG),
    'L' : cast_type_to_ffitype(rffi.ULONG),
    'q' : cast_type_to_ffitype(rffi.LONGLONG),
    'Q' : cast_type_to_ffitype(rffi.ULONGLONG),
    'f' : ffi_type_float,
    'd' : ffi_type_double,
    'g' : ffi_type_longdouble,
    's' : ffi_type_pointer,
    'P' : ffi_type_pointer,
    'z' : ffi_type_pointer,
    'O' : ffi_type_pointer,
    'Z' : ffi_type_pointer,
    '?' : cast_type_to_ffitype(lltype.Bool),
    'v' : ffi_type_sshort
}
TYPEMAP_PTR_LETTERS = "POszZ"
TYPEMAP_NUMBER_LETTERS = "bBhHiIlLqQ?v"
TYPEMAP_FLOAT_LETTERS = "fd" # XXX long doubles are not propperly supported in
                             # rpython, so we ignore then here

if _MS_WINDOWS:
    TYPEMAP['X'] = ffi_type_pointer
    TYPEMAP_PTR_LETTERS += 'X'

def size_alignment(ffi_type):
    return intmask(ffi_type.c_size), intmask(ffi_type.c_alignment)

LL_TYPEMAP = {
    'c' : rffi.CHAR,
    'u' : lltype.UniChar,
    'b' : rffi.SIGNEDCHAR,
    'B' : rffi.UCHAR,
    'h' : rffi.SHORT,
    'H' : rffi.USHORT,
    'i' : rffi.INT,
    'I' : rffi.UINT,
    'l' : rffi.LONG,
    'L' : rffi.ULONG,
    'q' : rffi.LONGLONG,
    'Q' : rffi.ULONGLONG,
    'f' : rffi.FLOAT,
    'd' : rffi.DOUBLE,
    'g' : rffi.LONGDOUBLE,
    's' : rffi.CCHARP,
    'z' : rffi.CCHARP,
    'Z' : rffi.CArrayPtr(lltype.UniChar),
    'O' : rffi.VOIDP,
    'P' : rffi.VOIDP,
    '?' : lltype.Bool,
    'v' : rffi.SHORT
}

if _MS_WINDOWS:
    LL_TYPEMAP['X'] = rffi.CCHARP

def letter2tp(space, key):
    from pypy.module._rawffi.interp_array import PRIMITIVE_ARRAY_TYPES
    try:
        return PRIMITIVE_ARRAY_TYPES[key]
    except KeyError:
        raise oefmt(space.w_ValueError, "Unknown type letter %s", key)

def unpack_simple_shape(space, w_shape):
    # 'w_shape' must be either a letter or a tuple (struct, 1).
    if space.isinstance_w(w_shape, space.w_text):
        letter = space.text_w(w_shape)
        return letter2tp(space, letter)
    else:
        w_shapetype, w_length = space.fixedview(w_shape, expected_length=2)
        from pypy.module._rawffi.structure import W_Structure
        return space.interp_w(W_Structure, w_shapetype)

def unpack_shape_with_length(space, w_shape):
    # Allow 'w_shape' to be a letter or any (shape, number).
    # The result is always a W_Array.
    if space.isinstance_w(w_shape, space.w_text):
        letter = space.text_w(w_shape)
        return letter2tp(space, letter)
    else:
        w_shapetype, w_length = space.fixedview(w_shape, expected_length=2)
        length = space.int_w(w_length)
        shape = space.interp_w(W_DataShape, w_shapetype)
        if shape._array_shapes is None:
            shape._array_shapes = {}
        try:
            result = shape._array_shapes[length]
        except KeyError:
            from pypy.module._rawffi.interp_array import W_Array
            if isinstance(shape, W_Array) and length == 1:
                result = shape
            else:
                ffitype = shape.get_basic_ffi_type()
                size = shape.size * length
                result = W_Array(ffitype, size)
            shape._array_shapes[length] = result
        return result

def unpack_resshape(space, w_restype):
    if space.is_w(w_restype, space.w_None):
        return None
    return unpack_simple_shape(space, w_restype)

def unpack_argshapes(space, w_argtypes):
    return [unpack_simple_shape(space, w_arg)
            for w_arg in space.unpackiterable(w_argtypes)]

def got_libffi_error(space):
    raise oefmt(space.w_SystemError, "not supported by libffi")

def wrap_dlopenerror(space, e, filename):
    if e.msg:
        # dlerror can return garbage messages under ll2ctypes (not
        # we_are_translated()), so repr it to avoid potential problems
        # converting to unicode later
        msg = e.msg if we_are_translated() else repr(e.msg)
    else:
        msg = 'unspecified error'
    return oefmt(space.w_OSError, 'Cannot load library %s: %8', filename, msg)


class W_CDLL(W_Root):
    def __init__(self, space, name, cdll):
        self.cdll = cdll
        self.name = name
        self.w_cache = space.newdict()
        self.space = space

    @unwrap_spec(flags=int)
    def ptr(self, space, w_name, w_argtypes, w_restype, flags=FUNCFLAG_CDECL):
        """ Get a pointer for function name with provided argtypes
        and restype
        """
        resshape = unpack_resshape(space, w_restype)
        if resshape is None:
            w_resshape = space.w_None
        else:
            w_resshape = resshape
        argtypes_w = space.fixedview(w_argtypes)
        w_argtypes = space.newtuple(argtypes_w)
        w_key = space.newtuple([w_name, w_argtypes, w_resshape])
        try:
            return space.getitem(self.w_cache, w_key)
        except OperationError as e:
            if e.match(space, space.w_KeyError):
                pass
            else:
                raise
        # Array arguments not supported directly (in C, an array argument
        # will be just a pointer).  And the result cannot be an array (at all).
        argshapes = unpack_argshapes(space, w_argtypes)
        ffi_argtypes = [shape.get_basic_ffi_type() for shape in argshapes]
        if resshape is not None:
            ffi_restype = resshape.get_basic_ffi_type()
        else:
            ffi_restype = ffi_type_void

        if space.isinstance_w(w_name, space.w_text):
            name = space.text_w(w_name)

            try:
                ptr = self.cdll.getrawpointer(name, ffi_argtypes, ffi_restype,
                                              flags)
            except KeyError:
                raise oefmt(space.w_AttributeError,
                            "No symbol %s found in library %s",
                            name, self.name)
            except LibFFIError:
                raise got_libffi_error(space)

        elif (_MS_WINDOWS and space.isinstance_w(w_name, space.w_int)):
            ordinal = space.int_w(w_name)
            try:
                ptr = self.cdll.getrawpointer_byordinal(ordinal, ffi_argtypes,
                                                        ffi_restype, flags)
            except KeyError:
                raise oefmt(space.w_AttributeError,
                            "No symbol %d found in library %s",
                            ordinal, self.name)
            except LibFFIError:
                raise got_libffi_error(space)
        else:
            raise oefmt(space.w_TypeError,
                        "function name must be string or integer")

        w_funcptr = W_FuncPtr(space, ptr, argshapes, resshape)
        space.setitem(self.w_cache, w_key, w_funcptr)
        return w_funcptr

    @unwrap_spec(name='text')
    def getaddressindll(self, space, name):
        try:
            address_as_uint = rffi.cast(lltype.Unsigned,
                                        self.cdll.getaddressindll(name))
        except KeyError:
            raise oefmt(space.w_ValueError, "Cannot find symbol %s", name)
        return space.newint(address_as_uint)

def open_cdll(space, name):
    try:
        return CDLL(name)
    except DLOpenError as e:
        raise wrap_dlopenerror(space, e, name or "<None>")
    except OSError as e:
        raise wrap_oserror(space, e)

if _MS_WINDOWS:
    name_spec = 'fsencode'
else:
    name_spec = 'fsencode_or_none'
@unwrap_spec(name=name_spec)
def descr_new_cdll(space, w_type, name):
    cdll = open_cdll(space, name)
    return W_CDLL(space, name, cdll)

W_CDLL.typedef = TypeDef(
    'CDLL',
    __new__     = interp2app(descr_new_cdll),
    ptr         = interp2app(W_CDLL.ptr),
    getaddressindll = interp2app(W_CDLL.getaddressindll),
    name        = interp_attrproperty('name', W_CDLL,
        wrapfn="newtext_or_none"),
    __doc__     = """ C Dynamically loaded library
use CDLL(libname) to create a handle to a C library (the argument is processed
the same way as dlopen processes it). On such a library you can call:
lib.ptr(func_name, argtype_list, restype)

where argtype_list is a list of single characters and restype is a single
character. The character meanings are more or less the same as in the struct
module, except that s has trailing \x00 added, while p is considered a raw
buffer.""" # xxx fix doc
)

unroll_letters_for_numbers = unrolling_iterable(TYPEMAP_NUMBER_LETTERS)
unroll_letters_for_floats = unrolling_iterable(TYPEMAP_FLOAT_LETTERS)

_ARM = rffi_platform.getdefined('__arm__', '')

@specialize.arg(2)
def read_ptr(ptr, ofs, TP):
    T = lltype.Ptr(rffi.CArray(TP))
    for c in unroll_letters_for_floats:
        # Note: if we are on ARM and have a float-ish value that is not word
        # aligned accessing it directly causes a SIGBUS. Instead we use memcpy
        # to avoid the problem
        if (_ARM and LL_TYPEMAP[c] is TP
                    and rffi.cast(lltype.Signed, ptr) & 3 != 0):
            if ofs != 0:
                ptr = rffi.ptradd(ptr, ofs*rffi.sizeof(TP))
            with lltype.scoped_alloc(T.TO, 1) as t_array:
                rffi.c_memcpy(
                    rffi.cast(rffi.VOIDP, t_array),
                    rffi.cast(rffi.VOIDP, ptr),
                    rffi.sizeof(TP))
                ptr_val = t_array[0]
                return ptr_val
    else:
        return rffi.cast(T, ptr)[ofs]

@specialize.argtype(2)
def write_ptr(ptr, ofs, value):
    TP = lltype.typeOf(value)
    T = lltype.Ptr(rffi.CArray(TP))
    for c in unroll_letters_for_floats:
        # Note: if we are on ARM and have a float-ish value that is not word
        # aligned accessing it directly causes a SIGBUS. Instead we use memcpy
        # to avoid the problem
        if (_ARM and LL_TYPEMAP[c] is TP
                    and rffi.cast(lltype.Signed, ptr) & 3 != 0):
            if ofs != 0:
                ptr = rffi.ptradd(ptr, ofs*rffi.sizeof(TP))
            with lltype.scoped_alloc(T.TO, 1) as s_array:
                s_array[0] = value
                rffi.c_memcpy(
                    rffi.cast(rffi.VOIDP, ptr),
                    rffi.cast(rffi.VOIDP, s_array),
                    rffi.sizeof(TP))
                return
    else:
        rffi.cast(T, ptr)[ofs] = value

def segfault_exception(space, reason):
    w_mod = space.getbuiltinmodule("_rawffi")
    w_exception = space.getattr(w_mod, space.newtext("SegfaultException"))
    return OperationError(w_exception, space.newtext(reason))

class W_DataShape(W_Root):
    _array_shapes = None
    size = 0
    alignment = 0
    itemcode = '\0'

    def allocate(self, space, length, autofree=False):
        raise NotImplementedError

    def get_basic_ffi_type(self):
        raise NotImplementedError

    def descr_get_ffi_type(self, space):
        from pypy.module._rawffi.alt.interp_ffitype import W_FFIType
        return W_FFIType('<unknown>', self.get_basic_ffi_type(), self)

    @unwrap_spec(n=int)
    def descr_size_alignment(self, space, n=1):
        return space.newtuple([space.newint(self.size * n),
                               space.newint(self.alignment)])


class W_DataInstance(W_Root):
    fmt = 'B'
    itemsize = 1
    def __init__(self, space, size, address=r_uint(0)):
        if address:
            self.ll_buffer = rffi.cast(rffi.VOIDP, address)
        else:
            self.ll_buffer = lltype.malloc(rffi.VOIDP.TO, size, flavor='raw',
                                           zero=True, add_memory_pressure=True)
            if tracker.DO_TRACING:
                ll_buf = rffi.cast(lltype.Signed, self.ll_buffer)
                tracker.trace_allocation(ll_buf, self)
        self._ll_buffer = self.ll_buffer

    def getbuffer(self, space):
        return space.newint(rffi.cast(lltype.Unsigned, self.ll_buffer))

    def buffer_advance(self, n):
        self.ll_buffer = rffi.ptradd(self.ll_buffer, n)

    def byptr(self, space):
        from pypy.module._rawffi.interp_array import ARRAY_OF_PTRS
        array = ARRAY_OF_PTRS.allocate(space, 1)
        array.setitem(space, 0, self)
        return array

    def free(self, space):
        if not self._ll_buffer:
            raise segfault_exception(space, "freeing NULL pointer")
        self._free()

    def _free(self):
        if tracker.DO_TRACING:
            ll_buf = rffi.cast(lltype.Signed, self._ll_buffer)
            tracker.trace_free(ll_buf)
        lltype.free(self._ll_buffer, flavor='raw')
        self.ll_buffer = lltype.nullptr(rffi.VOIDP.TO)
        self._ll_buffer = self.ll_buffer

    def buffer_w(self, space, flags):
        return SimpleView(RawFFIBuffer(self), w_obj=self)

    def getrawsize(self):
        raise NotImplementedError("abstract base class")

@specialize.arg(0)
def unwrap_truncate_int(TP, space, w_arg):
    return rffi.cast(TP, space.bigint_w(w_arg).ulonglongmask())


@specialize.arg(1)
def unwrap_value(space, push_func, add_arg, argdesc, letter, w_arg):
    if letter in TYPEMAP_PTR_LETTERS:
        # check for NULL ptr
        if isinstance(w_arg, W_DataInstance):
            ptr = w_arg.ll_buffer
        else:
            ptr = unwrap_truncate_int(rffi.VOIDP, space, w_arg)
        push_func(add_arg, argdesc, ptr)
    elif letter == "d":
        push_func(add_arg, argdesc, space.float_w(w_arg))
    elif letter == "f":
        push_func(add_arg, argdesc, rffi.cast(rffi.FLOAT,
                                              space.float_w(w_arg)))
    elif letter == "g":
        push_func(add_arg, argdesc, rffi.cast(rffi.LONGDOUBLE,
                                              space.float_w(w_arg)))
    elif letter == "c":
        if space.isinstance_w(w_arg, space.w_int):
            val = space.byte_w(w_arg)
        else:
            s = space.bytes_w(w_arg)
            if len(s) != 1:
                raise oefmt(space.w_TypeError,
                            "Expected bytes of length one as character")
            val = s[0]
        push_func(add_arg, argdesc, val)
    elif letter == 'u':
        s, lgt = space.utf8_len_w(w_arg)
        if lgt != 1:
            raise oefmt(space.w_TypeError,
                        "Expected unicode string of length one as wide "
                        "character")
        val = rutf8.codepoint_at_pos(s, 0)
        push_func(add_arg, argdesc, rffi.cast(rffi.WCHAR_T, val))
    else:
        for c in unroll_letters_for_numbers:
            if letter == c:
                TP = LL_TYPEMAP[c]
                val = unwrap_truncate_int(TP, space, w_arg)
                push_func(add_arg, argdesc, val)
                return
        else:
            raise oefmt(space.w_TypeError, "cannot directly write value")

ll_typemap_iter = unrolling_iterable(LL_TYPEMAP.items())

@specialize.arg(1)
def wrap_value(space, func, add_arg, argdesc, letter):
    for c, ll_type in ll_typemap_iter:
        if letter == c:
            if c in TYPEMAP_PTR_LETTERS:
                res = func(add_arg, argdesc, rffi.VOIDP)
                return space.newint(rffi.cast(lltype.Unsigned, res))
            if c in TYPEMAP_NUMBER_LETTERS:
                return space.newint(func(add_arg, argdesc, ll_type))
            elif c == 'c':
                return space.newbytes(func(add_arg, argdesc, ll_type))
            elif c == 'u':
                code = ord(func(add_arg, argdesc, ll_type))
                try:
                    return space.newutf8(rutf8.unichr_as_utf8(
                        r_uint(code), allow_surrogates=True), 1)
                except rutf8.OutOfRange:
                    raise oefmt(space.w_ValueError,
                        "unicode character %d out of range", code)
            elif c == 'f' or c == 'd' or c == 'g':
                return space.newfloat(float(func(add_arg, argdesc, ll_type)))
            else:
                assert 0, "unreachable"
    raise oefmt(space.w_TypeError, "cannot directly read value")

NARROW_INTEGER_TYPES = 'cbhiBIH?'

def is_narrow_integer_type(letter):
    return letter in NARROW_INTEGER_TYPES

class W_FuncPtr(W_Root):
    def __init__(self, space, ptr, argshapes, resshape):
        self.ptr = ptr
        self.argshapes = argshapes
        self.resshape = resshape
        self.narrow_integer = False
        if resshape is not None:
            self.narrow_integer = is_narrow_integer_type(resshape.itemcode.lower())

    def getbuffer(self, space):
        return space.newint(rffi.cast(lltype.Unsigned, self.ptr.funcsym))

    def byptr(self, space):
        from pypy.module._rawffi.interp_array import ARRAY_OF_PTRS
        array = ARRAY_OF_PTRS.allocate(space, 1)
        array.setitem(space, 0, self.getbuffer(space))
        if tracker.DO_TRACING:
            # XXX this is needed, because functions tend to live forever
            #     hence our testing is not performing that well
            del tracker.alloced[rffi.cast(lltype.Signed, array.ll_buffer)]
        return array

    def call(self, space, args_w):
        from pypy.module._rawffi.interp_array import W_ArrayInstance
        from pypy.module._rawffi.structure import W_StructureInstance
        from pypy.module._rawffi.structure import W_Structure
        argnum = len(args_w)
        if argnum != len(self.argshapes):
            raise oefmt(space.w_TypeError,
                        "Wrong number of arguments: expected %d, got %d",
                        len(self.argshapes), argnum)
        args_ll = []
        for i in range(argnum):
            argshape = self.argshapes[i]
            w_arg = args_w[i]
            if isinstance(argshape, W_Structure):   # argument by value
                arg = space.interp_w(W_StructureInstance, w_arg)
                xsize, xalignment = size_alignment(self.ptr.argtypes[i])
                if (arg.shape.size != xsize or
                    arg.shape.alignment != xalignment):
                    raise oefmt(space.w_TypeError,
                                "Argument %d should be a structure of size %d "
                                "and alignment %d, got instead size %d and "
                                "alignment %d", i + 1, xsize, xalignment,
                                arg.shape.size, arg.shape.alignment)
            else:
                arg = space.interp_w(W_ArrayInstance, w_arg)
                if arg.length != 1:
                    raise oefmt(space.w_TypeError,
                                "Argument %d should be an array of length 1, "
                                "got length %d", i+1, arg.length)
                argletter = argshape.itemcode
                letter = arg.shape.itemcode
                if letter != argletter:
                    if not (argletter in TYPEMAP_PTR_LETTERS and
                            letter in TYPEMAP_PTR_LETTERS):
                        raise oefmt(space.w_TypeError,
                                    "Argument %d should be typecode %s, got "
                                    "%s", i + 1, argletter, letter)
            args_ll.append(arg.ll_buffer)
            # XXX we could avoid the intermediate list args_ll

        try:
            if self.resshape is not None:
                result = self.resshape.allocate(space, 1, autofree=True)
                # adjust_return_size() was used here on result.ll_buffer
                self.ptr.call(args_ll, result.ll_buffer)
                if BIGENDIAN and self.narrow_integer:
                    # we get a 8 byte value in big endian
                    n = rffi.sizeof(lltype.Signed) - result.shape.size
                    result.buffer_advance(n)
                return result
            else:
                self.ptr.call(args_ll, lltype.nullptr(rffi.VOIDP.TO))
                return space.w_None
        except StackCheckError as e:
            raise OperationError(space.w_ValueError, space.newtext(e.message))

@unwrap_spec(addr=r_uint, flags=int)
def descr_new_funcptr(space, w_tp, addr, w_args, w_res, flags=FUNCFLAG_CDECL):
    argshapes = unpack_argshapes(space, w_args)
    resshape = unpack_resshape(space, w_res)
    ffi_args = [shape.get_basic_ffi_type() for shape in argshapes]
    if resshape is not None:
        ffi_res = resshape.get_basic_ffi_type()
    else:
        ffi_res = ffi_type_void
    try:
        ptr = RawFuncPtr('???', ffi_args, ffi_res, rffi.cast(rffi.VOIDP, addr),
                         flags)
    except LibFFIError:
        raise got_libffi_error(space)
    return W_FuncPtr(space, ptr, argshapes, resshape)

W_FuncPtr.typedef = TypeDef(
    'FuncPtr',
    __new__  = interp2app(descr_new_funcptr),
    __call__ = interp2app(W_FuncPtr.call),
    buffer   = GetSetProperty(W_FuncPtr.getbuffer),
    byptr    = interp2app(W_FuncPtr.byptr),
)
W_FuncPtr.typedef.acceptable_as_base_class = False

def _create_new_accessor(func_name, name):
    @unwrap_spec(tp_letter='text')
    def accessor(space, tp_letter):
        if len(tp_letter) != 1:
            raise oefmt(space.w_ValueError, "Expecting string of length one")
        tp_letter = tp_letter[0] # fool annotator
        try:
            return space.newint(intmask(getattr(TYPEMAP[tp_letter], name)))
        except KeyError:
            raise oefmt(space.w_ValueError, "Unknown type specification %s",
                        tp_letter)
    return func_with_new_name(accessor, func_name)

sizeof = _create_new_accessor('sizeof', 'c_size')
alignment = _create_new_accessor('alignment', 'c_alignment')

@unwrap_spec(address=r_uint, maxlength=int)
def charp2string(space, address, maxlength=-1):
    if address == 0:
        return space.w_None
    charp_addr = rffi.cast(rffi.CCHARP, address)
    if maxlength == -1:
        s = rffi.charp2str(charp_addr)
    else:
        s = rffi.charp2strn(charp_addr, maxlength)
    return space.newbytes(s)

@unwrap_spec(address=r_uint, maxlength=int)
def wcharp2unicode(space, address, maxlength=-1):
    if address == 0:
        return space.w_None
    wcharp_addr = rffi.cast(rffi.CWCHARP, address)
    try:
        if maxlength == -1:
            s, lgt = rffi.wcharp2utf8(wcharp_addr)
        else:
            s, lgt = rffi.wcharp2utf8n(wcharp_addr, maxlength)
    except rutf8.OutOfRange as e:
        raise wrap_unicode_out_of_range_error(space, e)
    return space.newutf8(s, lgt)

@unwrap_spec(address=r_uint, maxlength=int)
def charp2rawstring(space, address, maxlength=-1):
    if maxlength == -1:
        return charp2string(space, address)
    s = rffi.charpsize2str(rffi.cast(rffi.CCHARP, address), maxlength)
    return space.newbytes(s)

@unwrap_spec(address=r_uint, maxlength=int)
def wcharp2rawunicode(space, address, maxlength=-1):
    if maxlength == -1:
        return wcharp2unicode(space, address)
    elif maxlength < 0:
        maxlength = 0
    s = wcharpsize2utf8(space, rffi.cast(rffi.CWCHARP, address), maxlength)
    return space.newutf8(s, maxlength)

@unwrap_spec(address=r_uint, newcontent='bufferstr', offset=int, size=int)
def rawstring2charp(space, address, newcontent, offset=0, size=-1):
    from rpython.rtyper.annlowlevel import llstr
    from rpython.rtyper.lltypesystem.rstr import copy_string_to_raw
    array = rffi.cast(rffi.CCHARP, address)
    if size < 0:
        size = len(newcontent) - offset
    copy_string_to_raw(llstr(newcontent), array, offset, size)

if _MS_WINDOWS:
    @unwrap_spec(code=int)
    def FormatError(space, code):
        return space.newtext(*rwin32.FormatErrorW(code))

    @unwrap_spec(hresult=int)
    def check_HRESULT(space, hresult):
        if rwin32.FAILED(hresult):
            raise OperationError(space.w_WindowsError, space.newint(hresult))
        return space.newint(hresult)

def get_libc(space):
    name = get_libc_name()
    cdll = open_cdll(space, name)
    return W_CDLL(space, name, cdll)

def get_errno(space):
    return space.newint(rposix.get_saved_alterrno())

def set_errno(space, w_errno):
    rposix.set_saved_alterrno(space.int_w(w_errno))

if sys.platform == 'win32':
    # see also
    # issue #1944 ctypes-on-windows-getlasterror
    def get_last_error(space):
        return space.newint(rwin32.GetLastError_alt_saved())
    @unwrap_spec(error=int)
    def set_last_error(space, error):
        rwin32.SetLastError_alt_saved(error)
else:
    # always have at least a dummy version of these functions
    # issue 1242
    def get_last_error(space):
        return space.newint(0)
    @unwrap_spec(error=int)
    def set_last_error(space, error):
        pass
