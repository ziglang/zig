from rpython.rlib.objectmodel import we_are_translated
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rbigint import rbigint, InvalidSignednessError
from rpython.rlib.rarithmetic import maxint, widen
from pypy.module.cpyext.api import (
    cpython_api, PyObject, build_type_checkers_flags, Py_ssize_t,
    CONST_STRING, ADDR, CANNOT_FAIL, INTP_real)
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.unicodehelper import wcharpsize2utf8
from pypy.module.cpyext.pyerrors import PyErr_BadInternalCall

PyLong_Check, PyLong_CheckExact = build_type_checkers_flags("Long")

@cpython_api([rffi.LONG], PyObject)
def PyLong_FromLong(space, val):
    """Return a new PyLongObject object from v, or NULL on failure."""
    return space.newlong(widen(val))

@cpython_api([Py_ssize_t], PyObject)
def PyLong_FromSsize_t(space, val):
    """Return a new PyLongObject object from a C Py_ssize_t, or
    NULL on failure.
    """
    return space.newlong(val)

@cpython_api([rffi.SIZE_T], PyObject)
def PyLong_FromSize_t(space, val):
    """Return a new PyLongObject object from a C size_t, or NULL on
    failure.
    """
    return space.newlong_from_rarith_int(val)

@cpython_api([rffi.LONGLONG], PyObject)
def PyLong_FromLongLong(space, val):
    """Return a new PyLongObject object from a C long long, or NULL
    on failure."""
    return space.newlong_from_rarith_int(val)

@cpython_api([rffi.ULONG], PyObject)
def PyLong_FromUnsignedLong(space, val):
    """Return a new PyLongObject object from a C unsigned long, or
    NULL on failure."""
    return space.newlong_from_rarith_int(val)

@cpython_api([rffi.ULONGLONG], PyObject)
def PyLong_FromUnsignedLongLong(space, val):
    """Return a new PyLongObject object from a C unsigned long long,
    or NULL on failure."""
    return space.newlong_from_rarith_int(val)

ULONG_MASK = (2 ** (8 * rffi.sizeof(rffi.ULONG)) -1)
ULONG_MAX = (2 ** (8 * rffi.sizeof(rffi.ULONG)) -1)
LONG_MAX = (2 ** (8 * rffi.sizeof(rffi.ULONG) - 1) -1)
LONG_MIN = (-2 ** (8 * rffi.sizeof(rffi.ULONG) - 1))
need_to_check = maxint > ULONG_MAX

@cpython_api([PyObject], rffi.ULONG, error=-1)
def PyLong_AsUnsignedLong(space, w_long):
    """
    Return a C unsigned long representation of the contents of pylong.
    If pylong is greater than ULONG_MAX, an OverflowError is
    raised."""
    try:
        val = space.uint_w(w_long)
    except OperationError as e:
        if e.match(space, space.w_ValueError):
            e.w_type = space.w_OverflowError
        if (e.match(space, space.w_OverflowError) and 
                space.isinstance_w(w_long, space.w_int)):
            raise oefmt(space.w_OverflowError,
                "Python int too large to convert to C unsigned long")
        raise e
    if need_to_check and val > ULONG_MAX:
        # On win64 space.uint_w will succeed for 8-byte ints
        # but long is 4 bytes. So we must check manually
        raise oefmt(space.w_OverflowError,
                    "Python int too large to convert to C unsigned long")
    return rffi.cast(rffi.ULONG, val)

@cpython_api([PyObject], rffi.ULONG, error=-1)
def PyLong_AsUnsignedLongMask(space, w_long):
    """Return a C unsigned long from a Python long integer, without checking
    for overflow.
    """
    num = space.bigint_w(w_long)
    val = num.uintmask()
    if need_to_check and not we_are_translated():
        # On win64 num.uintmask will succeed for 8-byte ints
        # but unsigned long is 4 bytes.
        # The cast below is sufficient when translated, but
        # we need an extra check when running on CPython.
        val &= ULONG_MASK
    return rffi.cast(rffi.ULONG, val)

@cpython_api([PyObject], rffi.LONG, error=-1)
def PyLong_AsLong(space, w_long):
    """
    Get a C long int from an int object or any object that has an __int__
    method.  Return -1 and set an error if overflow occurs.
    """
    try:
        if space.lookup(w_long, '__index__'):
            val = space.int_w(space.index(w_long))
        else:
            val = space.int_w(space.int(w_long))
    except OperationError as e:
        if e.match(space, space.w_ValueError):
            e.w_type = space.w_OverflowError
        if (e.match(space, space.w_OverflowError) and 
                space.isinstance_w(w_long, space.w_int)):
            raise oefmt(space.w_OverflowError,
                "Python int too large to convert to C long")
        raise e
    if need_to_check and (val > LONG_MAX or val < LONG_MIN):
        # On win64 space.int_w will succeed for 8-byte ints
        # but long is 4 bytes. So we must check manually
        raise oefmt(space.w_OverflowError,
                    "Python int too large to convert to C long")
    return rffi.cast(rffi.LONG, val)

@cpython_api([PyObject], Py_ssize_t, error=-1)
def PyLong_AsSsize_t(space, w_long):
    """Return a C Py_ssize_t representation of the contents of pylong.  If
    pylong is greater than PY_SSIZE_T_MAX, an OverflowError is raised
    and -1 will be returned.
    """
    return space.int_w(w_long)

@cpython_api([PyObject], rffi.SIZE_T, error=-1)
def PyLong_AsSize_t(space, w_long):
    """Return a C size_t representation of of pylong.  pylong must be
    an instance of PyLongObject.

    Raise OverflowError if the value of pylong is out of range for a
    size_t."""
    return space.uint_w(w_long)

@cpython_api([PyObject], rffi.LONGLONG, error=-1)
def PyLong_AsLongLong(space, w_long):
    """
    Return a C unsigned long representation of the contents of pylong.
    If pylong is greater than ULONG_MAX, an OverflowError is
    raised."""
    return rffi.cast(rffi.LONGLONG, space.r_longlong_w(w_long))

@cpython_api([PyObject], rffi.ULONGLONG, error=-1)
def PyLong_AsUnsignedLongLong(space, w_long):
    """
    Return a C unsigned long representation of the contents of pylong.
    If pylong is greater than ULONG_MAX, an OverflowError is
    raised."""
    if not w_long:
        return PyErr_BadInternalCall(space)
    try:
        return rffi.cast(rffi.ULONGLONG, space.r_ulonglong_w(w_long))
    except OperationError as e:
        if e.match(space, space.w_ValueError):
            if not w_long:
                raise
            e.w_type = space.w_OverflowError
        raise

@cpython_api([PyObject], rffi.ULONGLONG, error=-1)
def PyLong_AsUnsignedLongLongMask(space, w_long):
    """Will first attempt to cast the object to a PyIntObject or
    PyLongObject, if it is not already one, and then return its value as
    unsigned long long, without checking for overflow.
    """
    if not w_long:
        return PyErr_BadInternalCall(space)
    num = space.bigint_w(w_long)
    return num.ulonglongmask()

@cpython_api([PyObject, INTP_real], rffi.LONG,
             error=-1)
def PyLong_AsLongAndOverflow(space, w_long, overflow_ptr):
    """
    Return a C long representation of the contents of pylong.  If pylong is
    greater than LONG_MAX or less than LONG_MIN, set *overflow to 1 or -1,
    respectively, and return -1; otherwise, set *overflow to 0.  If any other
    exception occurs (for example a TypeError or MemoryError), then -1 will be
    returned and *overflow will be 0."""
    overflow_ptr[0] = rffi.cast(rffi.INT_real, 0)
    try:
        val = space.int_w(w_long)
        if not need_to_check or (val >= LONG_MIN and val <= LONG_MAX):
            # On win64 space.int_w will succeed for 8-byte ints
            # but long is 4 bytes. So we must check manually
            return rffi.cast(rffi.LONG, val)
    except OperationError as e:
        if not e.match(space, space.w_OverflowError):
            raise
    if space.is_true(space.gt(w_long, space.newint(0))):
        overflow_ptr[0] = rffi.cast(rffi.INT_real, 1)
    else:
        overflow_ptr[0] = rffi.cast(rffi.INT_real, -1)
    return -1

@cpython_api([PyObject, INTP_real], rffi.LONGLONG,
             error=-1)
def PyLong_AsLongLongAndOverflow(space, w_long, overflow_ptr):
    """
    Return a C long long representation of the contents of pylong.  If pylong is
    greater than PY_LLONG_MAX or less than PY_LLONG_MIN, set *overflow to 1 or
    -1, respectively, and return -1; otherwise, set *overflow to 0.  If any
    other exception occurs (for example a TypeError or MemoryError), then -1
    will be returned and *overflow will be 0."""
    overflow_ptr[0] = rffi.cast(rffi.INT_real, 0)
    try:
        return rffi.cast(rffi.LONGLONG, space.r_longlong_w(w_long))
    except OperationError as e:
        if not e.match(space, space.w_OverflowError):
            raise
    if space.is_true(space.gt(w_long, space.newint(0))):
        overflow_ptr[0] = rffi.cast(rffi.INT_real, 1)
    else:
        overflow_ptr[0] = rffi.cast(rffi.INT_real, -1)
    return -1

@cpython_api([lltype.Float], PyObject)
def PyLong_FromDouble(space, val):
    """Return a new PyLongObject object from v, or NULL on failure."""
    return space.long(space.newfloat(val))

@cpython_api([PyObject], lltype.Float, error=-1.0)
def PyLong_AsDouble(space, w_long):
    """Return a C double representation of the contents of pylong.  If
    pylong cannot be approximately represented as a double, an
    OverflowError exception is raised and -1.0 will be returned."""
    return space.float_w(space.float(w_long))

@cpython_api([CONST_STRING, rffi.CCHARPP, rffi.INT_real], PyObject)
def PyLong_FromString(space, str, pend, base):
    """Return a new PyLongObject based on the string value in str, which is
    interpreted according to the radix in base.  If pend is non-NULL,
    *pend will point to the first character in str which follows the
    representation of the number.  If base is 0, the radix will be determined
    based on the leading characters of str: if str starts with '0x' or
    '0X', radix 16 will be used; if str starts with '0', radix 8 will be
    used; otherwise radix 10 will be used.  If base is not 0, it must be
    between 2 and 36, inclusive.  Leading spaces are ignored.  If there are
    no digits, ValueError will be raised."""
    s = rffi.charp2str(str)
    w_str = space.newtext(s)
    w_base = space.newint(rffi.cast(lltype.Signed, base))
    if pend:
        pend[0] = rffi.ptradd(str, len(s))
    return space.call_function(space.w_long, w_str, w_base)

@cpython_api([rffi.CWCHARP, Py_ssize_t, rffi.INT_real], PyObject)
def PyLong_FromUnicode(space, u, length, base):
    """Convert a sequence of Unicode digits to a Python long integer value.
    The first parameter, u, points to the first character of the Unicode
    string, length gives the number of characters, and base is the radix
    for the conversion.  The radix must be in the range [2, 36]; if it is
    out of range, ValueError will be raised."""
    if length < 0:
        length = 0
    w_value = space.newutf8(wcharpsize2utf8(space, u, length), length)
    return PyLong_FromUnicodeObject(space, w_value, base)

@cpython_api([PyObject, rffi.INT_real], PyObject)
def PyLong_FromUnicodeObject(space, w_value, base):
    w_base = space.newint(rffi.cast(lltype.Signed, base))
    return space.call_function(space.w_long, w_value, w_base)

@cpython_api([rffi.VOIDP], PyObject)
def PyLong_FromVoidPtr(space, p):
    """Create a Python integer or long integer from the pointer p. The pointer value
    can be retrieved from the resulting value using PyLong_AsVoidPtr().

    If the integer is larger than LONG_MAX, a positive long integer is returned."""
    value = rffi.cast(ADDR, p)    # signed integer
    if value < 0:
        return space.newlong_from_rarith_int(rffi.cast(lltype.Unsigned, p))
    return space.newint(value)

@cpython_api([PyObject], rffi.VOIDP, error=lltype.nullptr(rffi.VOIDP.TO))
def PyLong_AsVoidPtr(space, w_long):
    """Convert a Python integer or long integer pylong to a C void pointer.
    If pylong cannot be converted, an OverflowError will be raised.  This
    is only assured to produce a usable void pointer for values created
    with PyLong_FromVoidPtr().
    For values outside 0..LONG_MAX, both signed and unsigned integers are accepted."""
    return rffi.cast(rffi.VOIDP, space.uint_w(w_long))

@cpython_api([PyObject], rffi.SIZE_T, error=-1)
def _PyLong_NumBits(space, w_long):
    return space.uint_w(space.call_method(w_long, "bit_length"))

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def _PyLong_Sign(space, w_long):
    bigint = space.bigint_w(w_long)
    return bigint.sign

CONST_UCHARP = lltype.Ptr(lltype.Array(rffi.UCHAR, hints={'nolength': True,
                                       'render_as_const': True}))
@cpython_api([CONST_UCHARP, rffi.SIZE_T, rffi.INT_real, rffi.INT_real], PyObject)
def _PyLong_FromByteArray(space, bytes, n, little_endian, signed):
    little_endian = rffi.cast(lltype.Signed, little_endian)
    signed = rffi.cast(lltype.Signed, signed)
    s = rffi.charpsize2str(rffi.cast(rffi.CCHARP, bytes),
                           rffi.cast(lltype.Signed, n))
    if little_endian:
        byteorder = 'little'
    else:
        byteorder = 'big'
    result = rbigint.frombytes(s, byteorder, signed != 0)
    return space.newlong_from_rbigint(result)

@cpython_api([PyObject, rffi.UCHARP, rffi.SIZE_T,
              rffi.INT_real, rffi.INT_real], rffi.INT_real, error=-1)
def _PyLong_AsByteArrayO(space, w_v, bytes, n, little_endian, is_signed):
    n = rffi.cast(lltype.Signed, n)
    little_endian = rffi.cast(lltype.Signed, little_endian)
    signed = rffi.cast(lltype.Signed, is_signed) != 0
    byteorder = 'little' if little_endian else 'big'
    bigint = space.bigint_w(w_v)
    try:
        digits = bigint.tobytes(n, byteorder, signed)
    except InvalidSignednessError:     # < 0 but not 'signed'
        # in this case, CPython raises OverflowError even though the C
        # comments say it should raise TypeError
        raise oefmt(space.w_OverflowError,
                    "can't convert negative long to unsigned")
    except OverflowError:
        raise oefmt(space.w_OverflowError,
                    "long too big to convert")
    assert len(digits) == n
    for i in range(n):
        bytes[i] = rffi.cast(rffi.UCHAR, digits[i])
    return 0
