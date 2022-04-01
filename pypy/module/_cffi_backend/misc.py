from __future__ import with_statement
import sys

from pypy.interpreter.error import OperationError, oefmt
from pypy.module._rawffi.interp_rawffi import wrap_dlopenerror

from rpython.rlib import jit
from rpython.rlib.objectmodel import specialize, we_are_translated
from rpython.rlib.rarithmetic import r_uint, r_ulonglong
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.rdynload import dlopen, DLOpenError, DLLHANDLE
from rpython.rlib.nonconst import NonConstant
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo

if sys.platform == 'win32':
    from rpython.rlib.rdynload import dlopenU
    WIN32 = True
else:
    WIN32 = False


# ____________________________________________________________

_prim_signed_types = unrolling_iterable([
    (rffi.SIGNEDCHAR, rffi.SIGNEDCHARP),
    (rffi.SHORT, rffi.SHORTP),
    (rffi.INT, rffi.INTP),
    (rffi.LONG, rffi.LONGP),
    (rffi.LONGLONG, rffi.LONGLONGP)])

_prim_unsigned_types = unrolling_iterable([
    (rffi.UCHAR, rffi.UCHARP),
    (rffi.USHORT, rffi.USHORTP),
    (rffi.UINT, rffi.UINTP),
    (rffi.ULONG, rffi.ULONGP),
    (rffi.ULONGLONG, rffi.ULONGLONGP)])

_prim_float_types = unrolling_iterable([
    (rffi.FLOAT, rffi.FLOATP),
    (rffi.DOUBLE, rffi.DOUBLEP)])

def read_raw_signed_data(target, size):
    for TP, TPP in _prim_signed_types:
        if size == rffi.sizeof(TP):
            return rffi.cast(lltype.SignedLongLong, rffi.cast(TPP, target)[0])
    raise NotImplementedError("bad integer size")

def read_raw_long_data(target, size):
    for TP, TPP in _prim_signed_types:
        if size == rffi.sizeof(TP):
            assert rffi.sizeof(TP) <= rffi.sizeof(lltype.Signed)
            return rffi.cast(lltype.Signed, rffi.cast(TPP, target)[0])
    raise NotImplementedError("bad integer size")

def read_raw_unsigned_data(target, size):
    for TP, TPP in _prim_unsigned_types:
        if size == rffi.sizeof(TP):
            return rffi.cast(lltype.UnsignedLongLong, rffi.cast(TPP, target)[0])
    raise NotImplementedError("bad integer size")

def read_raw_ulong_data(target, size):
    for TP, TPP in _prim_unsigned_types:
        if size == rffi.sizeof(TP):
            assert rffi.sizeof(TP) <= rffi.sizeof(lltype.Unsigned)
            return rffi.cast(lltype.Unsigned, rffi.cast(TPP, target)[0])
    raise NotImplementedError("bad integer size")

@specialize.arg(0)
def _read_raw_float_data_tp(TPP, target):
    # in its own function: FLOAT may make the whole function jit-opaque
    return rffi.cast(lltype.Float, rffi.cast(TPP, target)[0])

def read_raw_float_data(target, size):
    for TP, TPP in _prim_float_types:
        if size == rffi.sizeof(TP):
            return _read_raw_float_data_tp(TPP, target)
    raise NotImplementedError("bad float size")

def read_raw_longdouble_data(target):
    return rffi.cast(rffi.LONGDOUBLEP, target)[0]

@specialize.argtype(1)
def write_raw_unsigned_data(target, source, size):
    for TP, TPP in _prim_unsigned_types:
        if size == rffi.sizeof(TP):
            rffi.cast(TPP, target)[0] = rffi.cast(TP, source)
            return
    raise NotImplementedError("bad integer size")

@specialize.argtype(1)
def write_raw_signed_data(target, source, size):
    for TP, TPP in _prim_signed_types:
        if size == rffi.sizeof(TP):
            rffi.cast(TPP, target)[0] = rffi.cast(TP, source)
            return
    raise NotImplementedError("bad integer size")


@specialize.arg(0, 1)
def _write_raw_float_data_tp(TP, TPP, target, source):
    # in its own function: FLOAT may make the whole function jit-opaque
    rffi.cast(TPP, target)[0] = rffi.cast(TP, source)

def write_raw_float_data(target, source, size):
    for TP, TPP in _prim_float_types:
        if size == rffi.sizeof(TP):
            _write_raw_float_data_tp(TP, TPP, target, source)
            return
    raise NotImplementedError("bad float size")

def write_raw_longdouble_data(target, source):
    rffi.cast(rffi.LONGDOUBLEP, target)[0] = source

@jit.dont_look_inside    # lets get_nonmovingbuffer_ll_final_null be inlined
def write_string_as_charp(target, string):
    from pypy.module._cffi_backend.ctypefunc import set_mustfree_flag
    buf, llobj, buf_flag = rffi.get_nonmovingbuffer_ll_final_null(string)
    set_mustfree_flag(target, ord(buf_flag))   # 4, 5 or 6
    rffi.cast(rffi.CCHARPP, target)[0] = buf
    return llobj

# ____________________________________________________________

sprintf_longdouble = rffi.llexternal(
    "sprintf", [rffi.CCHARP, rffi.CCHARP, rffi.LONGDOUBLE], lltype.Void,
    _nowrapper=True, sandboxsafe=True)

FORMAT_LONGDOUBLE = rffi.str2charp("%LE")

def longdouble2str(lvalue):
    with lltype.scoped_alloc(rffi.CCHARP.TO, 128) as p:    # big enough
        sprintf_longdouble(p, FORMAT_LONGDOUBLE, lvalue)
        return rffi.charp2str(p)

# ____________________________________________________________

def _is_a_float(space, w_ob):
    from pypy.module._cffi_backend.cdataobj import W_CData
    from pypy.module._cffi_backend.ctypeprim import W_CTypePrimitiveFloat
    if isinstance(w_ob, W_CData):
        return isinstance(w_ob.ctype, W_CTypePrimitiveFloat)
    return space.isinstance_w(w_ob, space.w_float)

def as_long_long(space, w_ob):
    # (possibly) convert and cast a Python object to a long long.
    # This version accepts a Python int too, and does convertions from
    # other types of objects.  It refuses floats.
    try:
        return space.int_w(w_ob, allow_conversion=False)
    except OperationError as e:
        if not (e.match(space, space.w_OverflowError) or
                e.match(space, space.w_TypeError)):
            raise
        if _is_a_float(space, w_ob):
            raise
    bigint = space.bigint_w(w_ob, allow_conversion=True)
    try:
        return bigint.tolonglong()
    except OverflowError:
        raise OperationError(space.w_OverflowError, space.newtext(ovf_msg))

def as_long(space, w_ob):
    # Same as as_long_long(), but returning an int instead.
    try:
        return space.int_w(w_ob, allow_conversion=False)
    except OperationError as e:
        if not (e.match(space, space.w_OverflowError) or
                e.match(space, space.w_TypeError)):
            raise
        if _is_a_float(space, w_ob):
            raise
    return space.int_w(w_ob, allow_conversion=True)

def as_unsigned_long_long(space, w_ob, strict):
    # (possibly) convert and cast a Python object to an unsigned long long.
    # This accepts a Python int too, and does convertions from other types of
    # objects.  If 'strict', complains with OverflowError; if 'not strict',
    # mask the result and round floats.
    try:
        value = space.int_w(w_ob, allow_conversion=False)
    except OperationError as e:
        if not (e.match(space, space.w_OverflowError) or
                e.match(space, space.w_TypeError)):
            raise
        if strict and _is_a_float(space, w_ob):
            raise
    else:
        if strict and value < 0:
            raise OperationError(space.w_OverflowError, space.newtext(neg_msg))
        return r_ulonglong(value)
    # note that if not 'strict', then space.int() will round down floats
    bigint = space.bigint_w(space.int(w_ob), allow_conversion=False)
    if strict:
        try:
            return bigint.toulonglong()
        except ValueError:
            raise OperationError(space.w_OverflowError, space.newtext(neg_msg))
        except OverflowError:
            raise OperationError(space.w_OverflowError, space.newtext(ovf_msg))
    else:
        return bigint.ulonglongmask()

def as_unsigned_long(space, w_ob, strict):
    # same as as_unsigned_long_long(), but returning just an Unsigned
    try:
        value = space.int_w(w_ob, allow_conversion=False)
    except OperationError as e:
        if not (e.match(space, space.w_OverflowError) or
                e.match(space, space.w_TypeError)):
            raise
        if strict and _is_a_float(space, w_ob):
            raise
    else:
        if strict and value < 0:
            raise OperationError(space.w_OverflowError, space.newtext(neg_msg))
        if not we_are_translated():
            if isinstance(value, NonConstant):   # hack for test_ztranslation
                return r_uint(0)
        return r_uint(value)
    # note that if not 'strict', then space.int() will round down floats
    bigint = space.bigint_w(space.int(w_ob), allow_conversion=False)
    if strict:
        try:
            return bigint.touint()
        except ValueError:
            raise OperationError(space.w_OverflowError, space.newtext(neg_msg))
        except OverflowError:
            raise OperationError(space.w_OverflowError, space.newtext(ovf_msg))
    else:
        return bigint.uintmask()

neg_msg = "can't convert negative number to unsigned"
ovf_msg = "long too big to convert"

def signext(value, size):
    # 'value' is sign-extended from 'size' bytes to a full integer.
    # 'size' should be smaller than a full integer size.
    if size == rffi.sizeof(rffi.SIGNEDCHAR):
        return rffi.cast(lltype.Signed, rffi.cast(rffi.SIGNEDCHAR, value))
    elif size == rffi.sizeof(rffi.SHORT):
        return rffi.cast(lltype.Signed, rffi.cast(rffi.SHORT, value))
    elif size == rffi.sizeof(rffi.INT):
        return rffi.cast(lltype.Signed, rffi.cast(rffi.INT, value))
    else:
        raise AssertionError("unsupported size")

# ____________________________________________________________

class _NotStandardObject(Exception):
    pass

def _standard_object_as_bool(space, w_ob):
    if space.isinstance_w(w_ob, space.w_int):
        try:
            return space.int_w(w_ob) != 0
        except OperationError as e:
            if not e.match(space, space.w_OverflowError):
                raise
            return space.bigint_w(w_ob).tobool()
    if space.isinstance_w(w_ob, space.w_float):
        return space.float_w(w_ob) != 0.0
    raise _NotStandardObject

# hackish, but the most straightforward way to know if a LONGDOUBLE object
# contains the value 0 or not.
eci = ExternalCompilationInfo(post_include_bits=["""
#define pypy__is_nonnull_longdouble(x)  ((x) != 0.0)
"""])
_is_nonnull_longdouble = rffi.llexternal(
    "pypy__is_nonnull_longdouble", [rffi.LONGDOUBLE], lltype.Bool,
    compilation_info=eci, _nowrapper=True, elidable_function=True,
    sandboxsafe=True)

# split here for JIT backends that don't support floats/longlongs/etc.
@jit.dont_look_inside
def is_nonnull_longdouble(cdata):
    return _is_nonnull_longdouble(read_raw_longdouble_data(cdata))
def is_nonnull_float(cdata, size):
    return read_raw_float_data(cdata, size) != 0.0    # note: True if a NaN

def object_as_bool(space, w_ob):
    # convert and cast a Python object to a boolean.  Accept an integer
    # or a float object, up to a CData 'long double'.
    try:
        return _standard_object_as_bool(space, w_ob)
    except _NotStandardObject:
        pass
    #
    from pypy.module._cffi_backend.cdataobj import W_CData
    from pypy.module._cffi_backend.ctypeprim import W_CTypePrimitiveFloat
    from pypy.module._cffi_backend.ctypeprim import W_CTypePrimitiveLongDouble
    is_cdata = isinstance(w_ob, W_CData)
    if is_cdata and isinstance(w_ob.ctype, W_CTypePrimitiveFloat):
        with w_ob as ptr:
            if isinstance(w_ob.ctype, W_CTypePrimitiveLongDouble):
                result = is_nonnull_longdouble(ptr)
            else:
                result = is_nonnull_float(ptr, w_ob.ctype.size)
        return result
    #
    if not is_cdata and space.lookup(w_ob, '__float__') is not None:
        w_io = space.float(w_ob)
    else:
        w_io = space.int(w_ob)
    try:
        return _standard_object_as_bool(space, w_io)
    except _NotStandardObject:
        raise oefmt(space.w_TypeError, "integer/float expected")

# ____________________________________________________________

@specialize.arg(0)
def _raw_memcopy_tp(TPP, source, dest):
    # in its own function: LONGLONG may make the whole function jit-opaque
    rffi.cast(TPP, dest)[0] = rffi.cast(TPP, source)[0]

def _raw_memcopy(source, dest, size):
    if jit.isconstant(size):
        # for the JIT: first handle the case where 'size' is known to be
        # a constant equal to 1, 2, 4, 8
        for TP, TPP in _prim_unsigned_types:
            if size == rffi.sizeof(TP):
                _raw_memcopy_tp(TPP, source, dest)
                return
    _raw_memcopy_opaque(source, dest, size)

@jit.dont_look_inside
def _raw_memcopy_opaque(source, dest, size):
    # push push push at the llmemory interface (with hacks that are all
    # removed after translation)
    zero = llmemory.itemoffsetof(rffi.CCHARP.TO, 0)
    llmemory.raw_memcopy(
        llmemory.cast_ptr_to_adr(source) + zero,
        llmemory.cast_ptr_to_adr(dest) + zero,
        size * llmemory.sizeof(lltype.Char))

@specialize.arg(0, 1)
def _raw_memclear_tp(TP, TPP, dest):
    # in its own function: LONGLONG may make the whole function jit-opaque
    rffi.cast(TPP, dest)[0] = rffi.cast(TP, 0)

def _raw_memclear(dest, size):
    # for now, only supports the cases of size = 1, 2, 4, 8
    for TP, TPP in _prim_unsigned_types:
        if size == rffi.sizeof(TP):
            _raw_memclear_tp(TP, TPP, dest)
            return
    raise NotImplementedError("bad clear size")

# ____________________________________________________________

def pack_list_to_raw_array_bounds_signed(int_list, target, size):
    for TP, TPP in _prim_signed_types:
        if size == rffi.sizeof(TP):
            ptr = rffi.cast(TPP, target)
            for i in range(len(int_list)):
                x = int_list[i]
                y = rffi.cast(TP, x)
                if x != rffi.cast(lltype.Signed, y):
                    return x      # overflow
                ptr[i] = y
            return 0
    raise NotImplementedError("bad integer size")

def pack_list_to_raw_array_bounds_unsigned(int_list, target, size, vrangemax):
    for TP, TPP in _prim_signed_types:
        if size == rffi.sizeof(TP):
            ptr = rffi.cast(TPP, target)
            for i in range(len(int_list)):
                x = int_list[i]
                if r_uint(x) > vrangemax:
                    return x      # overflow
                ptr[i] = rffi.cast(TP, x)
            return 0
    raise NotImplementedError("bad integer size")

@specialize.arg(2)
def pack_float_list_to_raw_array(float_list, target, TP, TPP):
    target = rffi.cast(TPP, target)
    for i in range(len(float_list)):
        x = float_list[i]
        target[i] = rffi.cast(TP, x)

def unpack_list_from_raw_array(int_list, source, size):
    for TP, TPP in _prim_signed_types:
        if size == rffi.sizeof(TP):
            ptr = rffi.cast(TPP, source)
            for i in range(len(int_list)):
                int_list[i] = rffi.cast(lltype.Signed, ptr[i])
            return
    raise NotImplementedError("bad integer size")

def unpack_unsigned_list_from_raw_array(int_list, source, size):
    for TP, TPP in _prim_unsigned_types:
        if size == rffi.sizeof(TP):
            ptr = rffi.cast(TPP, source)
            for i in range(len(int_list)):
                int_list[i] = rffi.cast(lltype.Signed, ptr[i])
            return
    raise NotImplementedError("bad integer size")

def unpack_cfloat_list_from_raw_array(float_list, source):
    ptr = rffi.cast(rffi.FLOATP, source)
    for i in range(len(float_list)):
        float_list[i] = rffi.cast(lltype.Float, ptr[i])

# ____________________________________________________________

def dlopen_w(space, w_filename, flags):
    from pypy.module._cffi_backend.cdataobj import W_CData
    from pypy.module._cffi_backend import ctypeptr

    autoclose = True
    if isinstance(w_filename, W_CData):
        # 'flags' ignored in this case
        w_ctype = w_filename.ctype
        if (not isinstance(w_ctype, ctypeptr.W_CTypePointer) or
            not w_ctype.is_void_ptr):
            raise oefmt(space.w_TypeError,
                    "dlopen() takes a file name or 'void *' handle, not '%s'",
                    w_ctype.name)
        handle = w_filename.unsafe_escaping_ptr()
        if not handle:
            raise oefmt(space.w_RuntimeError, "cannot call dlopen(NULL)")
        fname = w_ctype.extra_repr(handle)
        handle = rffi.cast(DLLHANDLE, handle)
        autoclose = False
        #
    elif WIN32 and space.isinstance_w(w_filename, space.w_unicode):
        fname = space.text_w(w_filename)
        utf8_name = space.utf8_w(w_filename)
        uni_len = space.len_w(w_filename)
        with rffi.scoped_utf82wcharp(utf8_name, uni_len) as ll_libname:
            try:
                handle = dlopenU(ll_libname, flags)
            except DLOpenError as e:
                raise wrap_dlopenerror(space, e, fname)
    else:
        if space.is_none(w_filename):
            fname = None
        else:
            fname = space.fsencode_w(w_filename)
        with rffi.scoped_str2charp(fname) as ll_libname:
            if fname is None:
                fname = "<None>"
            try:
                handle = dlopen(ll_libname, flags)
            except DLOpenError as e:
                raise wrap_dlopenerror(space, e, fname)
    return fname, handle, autoclose
