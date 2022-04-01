"""
This whole file is DEPRECATED.  Use jit_libffi.py instead.
"""
from __future__ import with_statement

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.objectmodel import specialize, enforceargs
from rpython.rlib.rarithmetic import intmask, r_uint, r_singlefloat, r_longlong
from rpython.rlib import jit
from rpython.rlib import clibffi
from rpython.rlib.clibffi import FUNCFLAG_CDECL, FUNCFLAG_STDCALL, \
        AbstractFuncPtr, push_arg_as_ffiptr, c_ffi_call, FFI_TYPE_STRUCT, \
        adjust_return_size
from rpython.rlib.rdynload import dlopen, dlclose, dlsym, dlsym_byordinal
from rpython.rlib.rdynload import DLLHANDLE

import os
import sys

_BIG_ENDIAN = sys.byteorder == 'big'

class types(object):
    """
    This namespace contains the primitive types you can use to declare the
    signatures of the ffi functions.

    In general, the name of the types are closely related to the ones of the
    C-level ffi_type_*: e.g, instead of ffi_type_sint you should use
    libffi.types.sint.

    However, you should not rely on a perfect correspondence: in particular,
    the exact meaning of ffi_type_{slong,ulong} changes a lot between libffi
    versions, so types.slong could be different than ffi_type_slong.
    """

    @classmethod
    def _import(cls):
        prefix = 'ffi_type_'
        for key, value in clibffi.__dict__.iteritems():
            if key.startswith(prefix):
                name = key[len(prefix):]
                setattr(cls, name, value)
        cls.slong = clibffi.cast_type_to_ffitype(rffi.LONG)
        cls.ulong = clibffi.cast_type_to_ffitype(rffi.ULONG)
        cls.slonglong = clibffi.cast_type_to_ffitype(rffi.LONGLONG)
        cls.ulonglong = clibffi.cast_type_to_ffitype(rffi.ULONGLONG)
        cls.signed = clibffi.cast_type_to_ffitype(rffi.SIGNED)
        cls.unsigned = clibffi.cast_type_to_ffitype(rffi.UNSIGNED)
        cls.wchar_t = clibffi.cast_type_to_ffitype(lltype.UniChar)
        # XXX long double support: clibffi.ffi_type_longdouble, but then
        # XXX fix the whole rest of this file to add a case for long double
        del cls._import

    @staticmethod
    @jit.elidable
    def getkind(ffi_type):
        """Returns 'v' for void, 'f' for float, 'i' for signed integer,
        and 'u' for unsigned integer.
        """
        if   ffi_type is types.void:    return 'v'
        elif ffi_type is types.double:  return 'f'
        elif ffi_type is types.float:   return 's'
        elif ffi_type is types.pointer: return 'u'
        #
        elif ffi_type is types.schar:   return 'i'
        elif ffi_type is types.uchar:   return 'u'
        elif ffi_type is types.sshort:  return 'i'
        elif ffi_type is types.ushort:  return 'u'
        elif ffi_type is types.sint:    return 'i'
        elif ffi_type is types.uint:    return 'u'
        elif ffi_type is types.slong:   return 'i'
        elif ffi_type is types.ulong:   return 'u'
        #
        elif ffi_type is types.sint8:   return 'i'
        elif ffi_type is types.uint8:   return 'u'
        elif ffi_type is types.sint16:  return 'i'
        elif ffi_type is types.uint16:  return 'u'
        elif ffi_type is types.sint32:  return 'i'
        elif ffi_type is types.uint32:  return 'u'
        #
        elif ffi_type is types.signed:  return 'i'
        elif ffi_type is types.unsigned:return 'u'
        ## (note that on 64-bit platforms, types.sint64 is types.slong and the
        ## case is caught above)
        elif ffi_type is types.sint64:  return 'I'
        elif ffi_type is types.uint64:  return 'U'
        #
        elif types.is_struct(ffi_type): return 'S'
        raise KeyError

    @staticmethod
    @jit.elidable
    def is_struct(ffi_type):
        return intmask(ffi_type.c_type) == FFI_TYPE_STRUCT

types._import()

# this was '_fits_into_long', which is not adequate, because long is
# not necessary the type where we compute with. Actually meant is
# the type 'Signed'.

@specialize.arg(0)
def _fits_into_signed(TYPE):
    if isinstance(TYPE, lltype.Ptr):
        return True # pointers always fits into Signeds
    if not isinstance(TYPE, lltype.Primitive):
        return False
    if TYPE is lltype.Void or TYPE is rffi.FLOAT or TYPE is rffi.DOUBLE:
        return False
    sz = rffi.sizeof(TYPE)
    return sz <= rffi.sizeof(rffi.SIGNED)


# ======================================================================

IS_32_BIT = (r_uint.BITS == 32)
IS_WIN64 = os.name == 'nt' and (r_uint.BITS == 64)

@specialize.memo()
def _check_type(TYPE):
    if isinstance(TYPE, lltype.Ptr):
        if TYPE.TO._gckind != 'raw':
            raise TypeError("Can only push raw values to C, not 'gc'")
        # XXX probably we should recursively check for struct fields here,
        # lets just ignore that for now
        if isinstance(TYPE.TO, lltype.Array) and 'nolength' not in TYPE.TO._hints:
            raise TypeError("Can only push to C arrays without length info")


class ArgChain(object):
    first = None
    last = None
    numargs = 0

    @specialize.argtype(1)
    def arg(self, val):
        TYPE = lltype.typeOf(val)
        _check_type(TYPE)
        if _fits_into_signed(TYPE):
            cls = IntArg
            val = rffi.cast(rffi.SIGNED, val)
        elif TYPE is rffi.DOUBLE:
            cls = FloatArg
        elif TYPE is rffi.LONGLONG or TYPE is rffi.ULONGLONG:
            cls = LongLongArg
            val = rffi.cast(rffi.LONGLONG, val)
        elif TYPE is rffi.FLOAT:
            cls = SingleFloatArg
        else:
            raise TypeError('Unsupported argument type: %s' % TYPE)
        self._append(cls(val))
        return self

    def arg_raw(self, val):
        self._append(RawArg(val))

    def _append(self, arg):
        if self.first is None:
            self.first = self.last = arg
        else:
            self.last.next = arg
            self.last = arg
        self.numargs += 1


class AbstractArg(object):
    next = None

class IntArg(AbstractArg):
    """ An argument holding an integer
    """

    def __init__(self, intval):
        self.intval = intval

    def push(self, func, ll_args, i):
        func._push_int(self.intval, ll_args, i)


class FloatArg(AbstractArg):
    """ An argument holding a python float (i.e. a C double)
    """

    def __init__(self, floatval):
        self.floatval = floatval

    def push(self, func, ll_args, i):
        func._push_float(self.floatval, ll_args, i)

class RawArg(AbstractArg):
    """ An argument holding a raw pointer to put inside ll_args
    """

    def __init__(self, ptrval):
        self.ptrval = ptrval

    def push(self, func, ll_args, i):
        func._push_raw(self.ptrval, ll_args, i)

class SingleFloatArg(AbstractArg):
    """ An argument representing a C float
    """

    def __init__(self, singlefloatval):
        self.singlefloatval = singlefloatval

    def push(self, func, ll_args, i):
        func._push_singlefloat(self.singlefloatval, ll_args, i)


class LongLongArg(AbstractArg):
    """ An argument representing a C long long
    """

    def __init__(self, longlongval):
        self.longlongval = longlongval

    def push(self, func, ll_args, i):
        func._push_longlong(self.longlongval, ll_args, i)


# ======================================================================

NARROW_INTEGER_TYPES = unrolling_iterable([rffi.CHAR, rffi.SIGNEDCHAR,
    rffi.UCHAR, rffi.SHORT, rffi.USHORT, rffi.INT, rffi.UINT])

class Func(AbstractFuncPtr):

    _immutable_fields_ = ['funcsym']
    argtypes = []
    restype = clibffi.FFI_TYPE_NULL
    flags = 0
    funcsym = lltype.nullptr(rffi.VOIDP.TO)

    def __init__(self, name, argtypes, restype, funcsym, flags=FUNCFLAG_CDECL,
                 keepalive=None):
        AbstractFuncPtr.__init__(self, name, argtypes, restype, flags)
        self.keepalive = keepalive
        self.funcsym = funcsym

    # ========================================================================
    # PUBLIC INTERFACE
    # ========================================================================

    @jit.unroll_safe
    @specialize.arg(2, 3)
    def call(self, argchain, RESULT, is_struct=False):
        # WARNING!  This code is written carefully in a way that the JIT
        # optimizer will see a sequence of calls like the following:
        #
        #    libffi_prepare_call
        #    libffi_push_arg
        #    libffi_push_arg
        #    ...
        #    libffi_call
        #
        # It is important that there is no other operation in the middle, else
        # the optimizer will fail to recognize the pattern and won't turn it
        # into a fast CALL.  Note that "arg = arg.next" is optimized away,
        # assuming that argchain is completely virtual.
        self = jit.promote(self)
        if argchain.numargs != len(self.argtypes):
            raise TypeError('Wrong number of arguments: %d expected, got %d' %
                (len(self.argtypes), argchain.numargs))
        ll_args = self._prepare()
        i = 0
        arg = argchain.first
        while arg:
            arg.push(self, ll_args, i)
            i += 1
            arg = arg.next
        #
        if is_struct:
            assert types.is_struct(self.restype)
            res = self._do_call_raw(self.funcsym, ll_args)
        elif _fits_into_signed(RESULT):
            assert not types.is_struct(self.restype)
            for res in NARROW_INTEGER_TYPES:
                if RESULT is res:
                    res = self._do_call_int(self.funcsym, ll_args, RESULT)
                    break
            else:
                res = self._do_call_int(self.funcsym, ll_args, rffi.SIGNED)
        elif RESULT is rffi.DOUBLE:
            return self._do_call_float(self.funcsym, ll_args)
        elif RESULT is rffi.FLOAT:
            return self._do_call_singlefloat(self.funcsym, ll_args)
        elif RESULT is rffi.LONGLONG or RESULT is rffi.ULONGLONG:
            assert IS_32_BIT
            res = self._do_call_longlong(self.funcsym, ll_args)
        elif RESULT is lltype.Void:
            return self._do_call_void(self.funcsym, ll_args)
        else:
            raise TypeError('Unsupported result type: %s' % RESULT)
        #
        return rffi.cast(RESULT, res)

    # END OF THE PUBLIC INTERFACE
    # ------------------------------------------------------------------------

    # JIT friendly interface
    # the following methods are supposed to be seen opaquely by the optimizer

    #@jit.oopspec('libffi_prepare_call(self)')
    @jit.dont_look_inside
    def _prepare(self):
        ll_args = lltype.malloc(rffi.VOIDPP.TO, len(self.argtypes), flavor='raw')
        return ll_args


    # _push_* and _do_call_* in theory could be automatically specialize()d by
    # the annotator.  However, specialization doesn't work well with oopspec,
    # so we specialize them by hand

    #@jit.oopspec('libffi_push_int(self, value, ll_args, i)')
    @jit.dont_look_inside
    @enforceargs( None, int,   None,    int) # fix the annotation for tests
    def _push_int(self, value, ll_args, i):
        self._push_arg(value, ll_args, i)

    @jit.dont_look_inside
    def _push_raw(self, value, ll_args, i):
        ll_args[i] = value

    #@jit.oopspec('libffi_push_float(self, value, ll_args, i)')
    @jit.dont_look_inside
    @enforceargs(   None, float, None,    int) # fix the annotation for tests
    def _push_float(self, value, ll_args, i):
        self._push_arg(value, ll_args, i)

    #@jit.oopspec('libffi_push_singlefloat(self, value, ll_args, i)')
    @jit.dont_look_inside
    @enforceargs(None, r_singlefloat, None, int) # fix the annotation for tests
    def _push_singlefloat(self, value, ll_args, i):
        self._push_arg(value, ll_args, i)

    #@jit.oopspec('libffi_push_longlong(self, value, ll_args, i)')
    @jit.dont_look_inside
    @enforceargs(None, r_longlong, None, int) # fix the annotation for tests
    def _push_longlong(self, value, ll_args, i):
        self._push_arg(value, ll_args, i)

    #@jit.oopspec('libffi_call_int(self, funcsym, ll_args)')
    @jit.dont_look_inside
    @specialize.arg(3)
    def _do_call_int(self, funcsym, ll_args, TP):
        return rffi.cast(rffi.SIGNED, self._do_call(funcsym, ll_args, TP))

    #@jit.oopspec('libffi_call_float(self, funcsym, ll_args)')
    @jit.dont_look_inside
    def _do_call_float(self, funcsym, ll_args):
        return self._do_call(funcsym, ll_args, rffi.DOUBLE)

    #@jit.oopspec('libffi_call_singlefloat(self, funcsym, ll_args)')
    @jit.dont_look_inside
    def _do_call_singlefloat(self, funcsym, ll_args):
        return self._do_call(funcsym, ll_args, rffi.FLOAT)

    @jit.dont_look_inside
    def _do_call_raw(self, funcsym, ll_args):
        # same as _do_call_int, but marked as jit.dont_look_inside
        return self._do_call(funcsym, ll_args, rffi.SIGNED)

    #@jit.oopspec('libffi_call_longlong(self, funcsym, ll_args)')
    @jit.dont_look_inside
    def _do_call_longlong(self, funcsym, ll_args):
        return self._do_call(funcsym, ll_args, rffi.LONGLONG)

    #@jit.oopspec('libffi_call_void(self, funcsym, ll_args)')
    @jit.dont_look_inside
    def _do_call_void(self, funcsym, ll_args):
        return self._do_call(funcsym, ll_args, lltype.Void)

    # ------------------------------------------------------------------------
    # private methods

    @specialize.argtype(1)
    def _push_arg(self, value, ll_args, i):
        # XXX: check the type is not translated?
        argtype = self.argtypes[i]
        c_size = intmask(argtype.c_size)
        ll_buf = lltype.malloc(rffi.CCHARP.TO, c_size, flavor='raw')
        push_arg_as_ffiptr(argtype, value, ll_buf)
        ll_args[i] = ll_buf

    @specialize.arg(3)
    def _do_call(self, funcsym, ll_args, RESULT):
        # XXX: check len(args)?
        ll_result = lltype.nullptr(rffi.VOIDP.TO)
        if self.restype != types.void:
            size = adjust_return_size(intmask(self.restype.c_size))
            ll_result = lltype.malloc(rffi.VOIDP.TO, size,
                                      flavor='raw')
        ffires = c_ffi_call(self.ll_cif,
                            self.funcsym,
                            rffi.cast(rffi.VOIDP, ll_result),
                            rffi.cast(rffi.VOIDPP, ll_args))
        if RESULT is not lltype.Void:
            TP = lltype.Ptr(rffi.CArray(RESULT))
            if types.is_struct(self.restype):
                assert RESULT == rffi.SIGNED
                # for structs, we directly return the buffer and transfer the
                # ownership
                buf = rffi.cast(TP, ll_result)
                res = rffi.cast(RESULT, buf)
            else:
                if _BIG_ENDIAN and types.getkind(self.restype) in ('i','u'):
                    ptr = ll_result
                    n = rffi.sizeof(lltype.Signed) - self.restype.c_size
                    ptr = rffi.ptradd(ptr, n)
                    res = rffi.cast(TP, ptr)[0]
                else:
                    res = rffi.cast(TP, ll_result)[0]
        else:
            res = None
        self._free_buffers(ll_result, ll_args)
        clibffi.check_fficall_result(ffires, self.flags)
        return res

    def _free_buffers(self, ll_result, ll_args):
        if ll_result:
            self._free_buffer_maybe(rffi.cast(rffi.VOIDP, ll_result), self.restype)
        for i in range(len(self.argtypes)):
            argtype = self.argtypes[i]
            self._free_buffer_maybe(ll_args[i], argtype)
        lltype.free(ll_args, flavor='raw')

    def _free_buffer_maybe(self, buf, ffitype):
        # if it's a struct, the buffer is not freed and the ownership is
        # already of the caller (in case of ll_args buffers) or transferred to
        # it (in case of ll_result buffer)
        if not types.is_struct(ffitype):
            lltype.free(buf, flavor='raw')


# ======================================================================


# XXX: it partially duplicate the code in clibffi.py
class CDLL(object):
    def __init__(self, libname, mode=-1, lib=0):
        """Load the library, or raises DLOpenError."""
        self.lib = rffi.cast(DLLHANDLE, lib)
        if lib == 0:
            with rffi.scoped_str2charp(libname) as ll_libname:
                self.lib = dlopen(ll_libname, mode)

    def __del__(self):
        if self.lib:
            dlclose(self.lib)
            self.lib = rffi.cast(DLLHANDLE, 0)

    def getpointer(self, name, argtypes, restype, flags=FUNCFLAG_CDECL):
        return Func(name, argtypes, restype, dlsym(self.lib, name),
                    flags=flags, keepalive=self)

    def getpointer_by_ordinal(self, name, argtypes, restype,
                              flags=FUNCFLAG_CDECL):
        return Func('by_ordinal', argtypes, restype,
                    dlsym_byordinal(self.lib, name),
                    flags=flags, keepalive=self)
    def getaddressindll(self, name):
        return dlsym(self.lib, name)

    def getidentifier(self):
        return rffi.cast(lltype.Unsigned, self.lib)

if os.name == 'nt':
    class WinDLL(CDLL):
        def getpointer(self, name, argtypes, restype, flags=FUNCFLAG_STDCALL):
            return Func(name, argtypes, restype, dlsym(self.lib, name),
                        flags=flags, keepalive=self)
        def getpointer_by_ordinal(self, name, argtypes, restype,
                                  flags=FUNCFLAG_STDCALL):
            return Func(name, argtypes, restype, dlsym_byordinal(self.lib, name),
                        flags=flags, keepalive=self)

# ======================================================================

#@jit.oopspec('libffi_struct_getfield(ffitype, addr, offset)')
@jit.dont_look_inside
def struct_getfield_int(ffitype, addr, offset):
    """
    Return the field of type ``ffitype`` at ``addr+offset``, widened to
    lltype.Signed.
    """
    for TYPE, ffitype2 in clibffi.ffitype_map_int_or_ptr:
        if ffitype is ffitype2:
            value = _struct_getfield(TYPE, addr, offset)
            return rffi.cast(lltype.Signed, value)
    assert False, "cannot find the given ffitype"


#@jit.oopspec('libffi_struct_setfield(ffitype, addr, offset, value)')
@jit.dont_look_inside
def struct_setfield_int(ffitype, addr, offset, value):
    """
    Set the field of type ``ffitype`` at ``addr+offset``.  ``value`` is of
    type lltype.Signed, and it's automatically converted to the right type.
    """
    for TYPE, ffitype2 in clibffi.ffitype_map_int_or_ptr:
        if ffitype is ffitype2:
            value = rffi.cast(TYPE, value)
            _struct_setfield(TYPE, addr, offset, value)
            return
    assert False, "cannot find the given ffitype"


#@jit.oopspec('libffi_struct_getfield(ffitype, addr, offset)')
@jit.dont_look_inside
def struct_getfield_longlong(ffitype, addr, offset):
    """
    Return the field of type ``ffitype`` at ``addr+offset``, casted to
    lltype.LongLong.
    """
    value = _struct_getfield(lltype.SignedLongLong, addr, offset)
    return value

#@jit.oopspec('libffi_struct_setfield(ffitype, addr, offset, value)')
@jit.dont_look_inside
def struct_setfield_longlong(ffitype, addr, offset, value):
    """
    Set the field of type ``ffitype`` at ``addr+offset``.  ``value`` is of
    type lltype.LongLong
    """
    _struct_setfield(lltype.SignedLongLong, addr, offset, value)


#@jit.oopspec('libffi_struct_getfield(ffitype, addr, offset)')
@jit.dont_look_inside
def struct_getfield_float(ffitype, addr, offset):
    value = _struct_getfield(lltype.Float, addr, offset)
    return value

#@jit.oopspec('libffi_struct_setfield(ffitype, addr, offset, value)')
@jit.dont_look_inside
def struct_setfield_float(ffitype, addr, offset, value):
    _struct_setfield(lltype.Float, addr, offset, value)


#@jit.oopspec('libffi_struct_getfield(ffitype, addr, offset)')
@jit.dont_look_inside
def struct_getfield_singlefloat(ffitype, addr, offset):
    value = _struct_getfield(lltype.SingleFloat, addr, offset)
    return value

#@jit.oopspec('libffi_struct_setfield(ffitype, addr, offset, value)')
@jit.dont_look_inside
def struct_setfield_singlefloat(ffitype, addr, offset, value):
    _struct_setfield(lltype.SingleFloat, addr, offset, value)


@specialize.arg(0)
def _struct_getfield(TYPE, addr, offset):
    """
    Read the field of type TYPE at addr+offset.
    addr is of type rffi.VOIDP, offset is an int.
    """
    addr = rffi.ptradd(addr, offset)
    PTR_FIELD = lltype.Ptr(rffi.CArray(TYPE))
    return rffi.cast(PTR_FIELD, addr)[0]


@specialize.arg(0)
def _struct_setfield(TYPE, addr, offset, value):
    """
    Write the field of type TYPE at addr+offset.
    addr is of type rffi.VOIDP, offset is an int.
    """
    addr = rffi.ptradd(addr, offset)
    PTR_FIELD = lltype.Ptr(rffi.CArray(TYPE))
    rffi.cast(PTR_FIELD, addr)[0] = value

# ======================================================================

# These specialize.call_location's should really be specialize.arg(0), however
# you can't hash a pointer obj, which the specialize machinery wants to do.
# Given the present usage of these functions, it's good enough.
@specialize.call_location()
#@jit.oopspec("libffi_array_getitem(ffitype, width, addr, index, offset)")
@jit.dont_look_inside
def array_getitem(ffitype, width, addr, index, offset):
    for TYPE, ffitype2 in clibffi.ffitype_map:
        if ffitype is ffitype2:
            addr = rffi.ptradd(addr, index * width)
            addr = rffi.ptradd(addr, offset)
            return rffi.cast(rffi.CArrayPtr(TYPE), addr)[0]
    assert False

def array_getitem_T(TYPE, width, addr, index, offset):
    addr = rffi.ptradd(addr, index * width)
    addr = rffi.ptradd(addr, offset)
    return rffi.cast(rffi.CArrayPtr(TYPE), addr)[0]

@specialize.call_location()
#@jit.oopspec("libffi_array_setitem(ffitype, width, addr, index, offset, value)")
@jit.dont_look_inside
def array_setitem(ffitype, width, addr, index, offset, value):
    for TYPE, ffitype2 in clibffi.ffitype_map:
        if ffitype is ffitype2:
            addr = rffi.ptradd(addr, index * width)
            addr = rffi.ptradd(addr, offset)
            rffi.cast(rffi.CArrayPtr(TYPE), addr)[0] = value
            return
    assert False

def array_setitem_T(TYPE, width, addr, index, offset, value):
    addr = rffi.ptradd(addr, index * width)
    addr = rffi.ptradd(addr, offset)
    rffi.cast(rffi.CArrayPtr(TYPE), addr)[0] = value
