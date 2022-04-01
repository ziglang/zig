"""
Function pointers.
"""

import sys

from rpython.rlib import jit, clibffi, jit_libffi, rgc
from rpython.rlib.jit_libffi import (CIF_DESCRIPTION, CIF_DESCRIPTION_P,
    FFI_TYPE, FFI_TYPE_P, FFI_TYPE_PP, SIZE_OF_FFI_ARG)
from rpython.rlib.objectmodel import we_are_translated, instantiate
from rpython.rlib.objectmodel import keepalive_until_here
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.annlowlevel import llstr

from pypy.interpreter.error import OperationError, oefmt
from pypy.module._cffi_backend.moduledef import (
    FFI_DEFAULT_ABI, has_stdcall, FFI_STDCALL)
from pypy.module._cffi_backend import ctypearray, cdataobj, cerrno
from pypy.module._cffi_backend.ctypeobj import W_CType
from pypy.module._cffi_backend.ctypeptr import W_CTypePtrBase, W_CTypePointer
from pypy.module._cffi_backend.ctypevoid import W_CTypeVoid
from pypy.module._cffi_backend.ctypestruct import W_CTypeStruct, W_CTypeUnion
from pypy.module._cffi_backend.ctypeprim import (W_CTypePrimitiveSigned,
    W_CTypePrimitiveUnsigned, W_CTypePrimitiveCharOrUniChar,
    W_CTypePrimitiveFloat, W_CTypePrimitiveLongDouble, W_CTypePrimitiveComplex)


class W_CTypeFunc(W_CTypePtrBase):
    _attrs_            = ['fargs', 'ellipsis', 'abi', 'cif_descr']
    _immutable_fields_ = ['fargs[*]', 'ellipsis', 'abi', 'cif_descr']
    kind = "function"

    cif_descr = lltype.nullptr(CIF_DESCRIPTION)

    def __init__(self, space, fargs, fresult, ellipsis,
                 abi=FFI_DEFAULT_ABI):
        assert isinstance(ellipsis, bool)
        extra, xpos = self._compute_extra_text(fargs, fresult, ellipsis, abi)
        size = rffi.sizeof(rffi.VOIDP)
        W_CTypePtrBase.__init__(self, space, size, extra, xpos, fresult)
        self.fargs = fargs
        self.ellipsis = ellipsis
        self.abi = abi
        # fresult is stored in self.ctitem

        if not ellipsis:
            # Functions with '...' varargs are stored without a cif_descr
            # at all.  The cif is computed on every call from the actual
            # types passed in.  For all other functions, the cif_descr
            # is computed here.
            builder = CifDescrBuilder(fargs, fresult, abi)
            try:
                builder.rawallocate(self)
            except OperationError as e:
                if not e.match(space, space.w_NotImplementedError):
                    raise
                # else, eat the NotImplementedError.  We will get the
                # exception if we see an actual call
                if self.cif_descr:   # should not be True, but you never know
                    lltype.free(self.cif_descr, flavor='raw')
                    self.cif_descr = lltype.nullptr(CIF_DESCRIPTION)

    def is_unichar_ptr_or_array(self):
        return False

    def is_char_or_unichar_ptr_or_array(self):
        return False

    def string(self, cdataobj, maxlen):
        # Can't use ffi.string() on a function pointer
        return W_CType.string(self, cdataobj, maxlen)

    def new_ctypefunc_completing_argtypes(self, args_w):
        space = self.space
        nargs_declared = len(self.fargs)
        fvarargs = [None] * len(args_w)
        for i in range(nargs_declared):
            fvarargs[i] = self.fargs[i]
        for i in range(nargs_declared, len(args_w)):
            w_obj = args_w[i]
            if isinstance(w_obj, cdataobj.W_CData):
                ct = w_obj.ctype.get_vararg_type()
            else:
                raise oefmt(space.w_TypeError,
                            "argument %d passed in the variadic part needs to "
                            "be a cdata object (got %T)", i + 1, w_obj)
            fvarargs[i] = ct
        # xxx call instantiate() directly.  It's a bit of a hack.
        ctypefunc = instantiate(W_CTypeFunc)
        ctypefunc.space = space
        ctypefunc.fargs = fvarargs
        ctypefunc.ctitem = self.ctitem
        #ctypefunc.cif_descr = NULL --- already provided as the default
        CifDescrBuilder(fvarargs, self.ctitem, self.abi).rawallocate(ctypefunc)
        return ctypefunc

    @rgc.must_be_light_finalizer
    def __del__(self):
        if self.cif_descr:
            lltype.free(self.cif_descr, flavor='raw')

    def _compute_extra_text(self, fargs, fresult, ellipsis, abi):
        argnames = ['(*)(']
        xpos = 2
        if has_stdcall and abi == FFI_STDCALL:
            argnames[0] = '(__stdcall *)('
            xpos += len('__stdcall ')
        for i, farg in enumerate(fargs):
            if i > 0:
                argnames.append(', ')
            argnames.append(farg.name)
        if ellipsis:
            if len(fargs) > 0:
                argnames.append(', ')
            argnames.append('...')
        argnames.append(')')
        return ''.join(argnames), xpos

    def _fget(self, attrchar):
        if attrchar == 'a':    # args
            return self.space.newtuple([a for a in self.fargs])
        if attrchar == 'r':    # result
            return self.ctitem
        if attrchar == 'E':    # ellipsis
            return self.space.newbool(self.ellipsis)
        if attrchar == 'A':    # abi
            return self.space.newint(self.abi)
        return W_CTypePtrBase._fget(self, attrchar)

    def call(self, funcaddr, args_w):
        if not funcaddr:
            raise oefmt(self.space.w_RuntimeError,
                        "cannot call null function pointer from cdata '%s'",
                        self.name)
        if self.cif_descr:
            # regular case: this function does not take '...' arguments
            self = jit.promote(self)
            nargs_declared = len(self.fargs)
            if len(args_w) != nargs_declared:
                space = self.space
                raise oefmt(space.w_TypeError,
                            "'%s' expects %d arguments, got %d",
                            self.name, nargs_declared, len(args_w))
            return self._call(funcaddr, args_w)
        else:
            # call of a variadic function
            return self.call_varargs(funcaddr, args_w)

    @jit.dont_look_inside
    def call_varargs(self, funcaddr, args_w):
        nargs_declared = len(self.fargs)
        if len(args_w) < nargs_declared:
            space = self.space
            raise oefmt(space.w_TypeError,
                        "'%s' expects at least %d arguments, got %d",
                        self.name, nargs_declared, len(args_w))
        completed = self.new_ctypefunc_completing_argtypes(args_w)
        return completed._call(funcaddr, args_w)

    # The following is the core of function calls.  It is @unroll_safe,
    # which means that the JIT is free to unroll the argument handling.
    # But in case the function takes variable arguments, we don't unroll
    # this (yet) for better safety: this is handled by @dont_look_inside
    # in call_varargs.
    @jit.unroll_safe
    def _call(self, funcaddr, args_w):
        space = self.space
        cif_descr = self.cif_descr   # 'self' should have been promoted here
        size = cif_descr.exchange_size
        mustfree_max_plus_1 = 0
        keepalives = [llstr(None)] * len(args_w)    # llstrings
        buffer = lltype.malloc(rffi.CCHARP.TO, size, flavor='raw')
        try:
            for i in range(len(args_w)):
                data = rffi.ptradd(buffer, cif_descr.exchange_args[i])
                w_obj = args_w[i]
                argtype = self.fargs[i]
                if argtype.convert_argument_from_object(data, w_obj,
                                                        keepalives, i):
                    # argtype is a pointer type, and w_obj a list/tuple/str
                    mustfree_max_plus_1 = i + 1

            jit_libffi.jit_ffi_call(cif_descr,
                                    rffi.cast(rffi.VOIDP, funcaddr),
                                    buffer)

            resultdata = rffi.ptradd(buffer, cif_descr.exchange_result)
            w_res = self.ctitem.copy_and_convert_to_object(resultdata)
        finally:
            for i in range(mustfree_max_plus_1):
                argtype = self.fargs[i]
                if isinstance(argtype, W_CTypePointer):
                    data = rffi.ptradd(buffer, cif_descr.exchange_args[i])
                    flag = get_mustfree_flag(data)
                    raw_cdata = rffi.cast(rffi.CCHARPP, data)[0]
                    if flag == 1:
                        lltype.free(raw_cdata, flavor='raw')
                    elif flag == 3:
                        rgc.unpin(keepalives[i])
                        if not we_are_translated():
                            lltype.free(keepalives[i])
                    elif flag >= 4:
                        llobj = keepalives[i]
                        assert llobj     # not NULL
                        rffi.free_nonmovingbuffer_ll(raw_cdata,
                                                     llobj, chr(flag))
            lltype.free(buffer, flavor='raw')
            keepalive_until_here(args_w)
        return w_res

def get_mustfree_flag(data):
    return ord(rffi.ptradd(data, -1)[0])

def set_mustfree_flag(data, flag):
    """ Set a flag for future handling of the pointer after the call,
    possible values are:
    0 - not set
    1 - free the argument
    2 - file argument
    3 - unpin the keepalive
    4, 5, 6 - free the keepalive slot, different values returned from
              rffi.get_nonmovingbuffer_ll_final_null
    """
    rffi.ptradd(data, -1)[0] = chr(flag)

# ____________________________________________________________


# ----------
# We attach to the classes small methods that return a 'ffi_type'

def _notimplemented_ffi_type(self, is_result_type, extra=''):
    if is_result_type:
        place = "return value"
    else:
        place = "argument"
    raise oefmt(self.space.w_NotImplementedError,
                "ctype '%s' (size %d) not supported as %s%s",
                self.name, self.size, place, extra)

def _missing_ffi_type(self, cifbuilder, is_result_type):
    if self.size < 0:
        raise oefmt(self.space.w_TypeError,
                    "ctype '%s' has incomplete type", self.name)
    raise _notimplemented_ffi_type(self, is_result_type)

def _struct_ffi_type(self, cifbuilder, is_result_type):
    if self.size >= 0:
        return cifbuilder.fb_struct_ffi_type(self, is_result_type)
    return _missing_ffi_type(self, cifbuilder, is_result_type)

def _union_ffi_type(self, cifbuilder, is_result_type):
    if self.size >= 0:   # only for a better error message
        return cifbuilder.fb_union_ffi_type(self, is_result_type)
    return _missing_ffi_type(self, cifbuilder, is_result_type)

def _primsigned_ffi_type(self, cifbuilder, is_result_type):
    size = self.size
    if   size == 1: return clibffi.ffi_type_sint8
    elif size == 2: return clibffi.ffi_type_sint16
    elif size == 4: return clibffi.ffi_type_sint32
    elif size == 8: return clibffi.ffi_type_sint64
    return _missing_ffi_type(self, cifbuilder, is_result_type)

def _primunsigned_ffi_type(self, cifbuilder, is_result_type):
    size = self.size
    if   size == 1: return clibffi.ffi_type_uint8
    elif size == 2: return clibffi.ffi_type_uint16
    elif size == 4: return clibffi.ffi_type_uint32
    elif size == 8: return clibffi.ffi_type_uint64
    return _missing_ffi_type(self, cifbuilder, is_result_type)

def _primfloat_ffi_type(self, cifbuilder, is_result_type):
    size = self.size
    if   size == 4: return clibffi.ffi_type_float
    elif size == 8: return clibffi.ffi_type_double
    return _missing_ffi_type(self, cifbuilder, is_result_type)

def _primlongdouble_ffi_type(self, cifbuilder, is_result_type):
    return clibffi.ffi_type_longdouble

def _primcomplex_ffi_type(self, cifbuilder, is_result_type):
    raise _notimplemented_ffi_type(self, is_result_type,
        extra = " (the support for complex types inside libffi "
                "is mostly missing at this point, so CFFI only "
                "supports complex types as arguments or return "
                "value in API-mode functions)")

def _ptr_ffi_type(self, cifbuilder, is_result_type):
    return clibffi.ffi_type_pointer

def _void_ffi_type(self, cifbuilder, is_result_type):
    if is_result_type:
        return clibffi.ffi_type_void
    return _missing_ffi_type(self, cifbuilder, is_result_type)

W_CType._get_ffi_type                       = _missing_ffi_type
W_CTypeStruct._get_ffi_type                 = _struct_ffi_type
W_CTypeUnion._get_ffi_type                  = _union_ffi_type
W_CTypePrimitiveSigned._get_ffi_type        = _primsigned_ffi_type
W_CTypePrimitiveCharOrUniChar._get_ffi_type = _primunsigned_ffi_type
W_CTypePrimitiveUnsigned._get_ffi_type      = _primunsigned_ffi_type
W_CTypePrimitiveFloat._get_ffi_type         = _primfloat_ffi_type
W_CTypePrimitiveLongDouble._get_ffi_type    = _primlongdouble_ffi_type
W_CTypePrimitiveComplex._get_ffi_type       = _primcomplex_ffi_type
W_CTypePtrBase._get_ffi_type                = _ptr_ffi_type
W_CTypeVoid._get_ffi_type                   = _void_ffi_type
# ----------


_SUPPORTED_IN_API_MODE = (
        " are only supported as %s if the function is "
        "'API mode' and non-variadic (i.e. declared inside ffibuilder"
        ".cdef()+ffibuilder.set_source() and not taking a final '...' "
        "argument)")

class CifDescrBuilder(object):
    rawmem = lltype.nullptr(rffi.CCHARP.TO)

    def __init__(self, fargs, fresult, fabi):
        self.fargs = fargs
        self.fresult = fresult
        self.fabi = fabi

    def fb_alloc(self, size):
        size = llmemory.raw_malloc_usage(size)
        if not self.bufferp:
            self.nb_bytes += size
            return lltype.nullptr(rffi.CCHARP.TO)
        else:
            result = self.bufferp
            self.bufferp = rffi.ptradd(result, size)
            return result

    def fb_fill_type(self, ctype, is_result_type):
        return ctype._get_ffi_type(self, is_result_type)

    def fb_unsupported(self, ctype, is_result_type, detail):
        place = "return value" if is_result_type else "argument"
        raise oefmt(self.space.w_NotImplementedError,
            "ctype '%s' not supported as %s.  %s.  "
            "Such structs" + _SUPPORTED_IN_API_MODE,
            ctype.name, place, detail, place)

    def fb_union_ffi_type(self, ctype, is_result_type=False):
        place = "return value" if is_result_type else "argument"
        raise oefmt(self.space.w_NotImplementedError,
            "ctype '%s' not supported as %s by libffi.  "
            "Unions" + _SUPPORTED_IN_API_MODE,
            ctype.name, place, place)

    def fb_struct_ffi_type(self, ctype, is_result_type=False):
        # We can't pass a struct that was completed by verify().
        # Issue: assume verify() is given "struct { long b; ...; }".
        # Then it will complete it in the same way whether it is actually
        # "struct { long a, b; }" or "struct { double a; long b; }".
        # But on 64-bit UNIX, these two structs are passed by value
        # differently: e.g. on x86-64, "b" ends up in register "rsi" in
        # the first case and "rdi" in the second case.
        #
        # Another reason for 'custom_field_pos' would be anonymous
        # nested structures: we lost the information about having it
        # here, so better safe (and forbid it) than sorry (and maybe
        # crash).  Note: it seems we only get in this case with
        # ffi.verify().
        space = self.space
        ctype.force_lazy_struct()
        if ctype._custom_field_pos:
            # these NotImplementedErrors may be caught and ignored until
            # a real call is made to a function of this type
            raise self.fb_unsupported(ctype, is_result_type,
                "It is a struct declared with \"...;\", but the C "
                "calling convention may depend on the missing fields; "
                "or, it contains anonymous struct/unions")
        # Another reason: __attribute__((packed)) is not supported by libffi.
        if ctype._with_packed_change:
            raise self.fb_unsupported(ctype, is_result_type,
                "It is a 'packed' structure, with a different layout than "
                "expected by libffi")

        # walk the fields, expanding arrays into repetitions; first,
        # only count how many flattened fields there are
        nflat = 0
        for i, cf in enumerate(ctype._fields_list):
            if cf.is_bitfield():
                raise self.fb_unsupported(ctype, is_result_type,
                    "It is a struct with bit fields, which libffi does not "
                    "support")
            flat = 1
            ct = cf.ctype
            while isinstance(ct, ctypearray.W_CTypeArray):
                flat *= ct.length
                ct = ct.ctitem
            if flat <= 0:
                raise self.fb_unsupported(ctype, is_result_type,
                    "It is a struct with a zero-length array, which libffi "
                    "does not support")
            nflat += flat

        # allocate an array of (nflat + 1) ffi_types
        elements = self.fb_alloc(rffi.sizeof(FFI_TYPE_P) * (nflat + 1))
        elements = rffi.cast(FFI_TYPE_PP, elements)

        # fill it with the ffi types of the fields
        nflat = 0
        for i, cf in enumerate(ctype._fields_list):
            flat = 1
            ct = cf.ctype
            while isinstance(ct, ctypearray.W_CTypeArray):
                flat *= ct.length
                ct = ct.ctitem
            ffi_subtype = self.fb_fill_type(ct, False)
            if elements:
                for j in range(flat):
                    elements[nflat] = ffi_subtype
                    nflat += 1

        # zero-terminate the array
        if elements:
            elements[nflat] = lltype.nullptr(FFI_TYPE_P.TO)

        # allocate and fill an ffi_type for the struct itself
        ffistruct = self.fb_alloc(rffi.sizeof(FFI_TYPE))
        ffistruct = rffi.cast(FFI_TYPE_P, ffistruct)
        if ffistruct:
            rffi.setintfield(ffistruct, 'c_size', ctype.size)
            rffi.setintfield(ffistruct, 'c_alignment', ctype.alignof())
            rffi.setintfield(ffistruct, 'c_type', clibffi.FFI_TYPE_STRUCT)
            ffistruct.c_elements = elements

        return ffistruct

    def fb_build(self):
        # Build a CIF_DESCRIPTION.  Actually this computes the size and
        # allocates a larger amount of data.  It starts with a
        # CIF_DESCRIPTION and continues with data needed for the CIF:
        #
        #  - the argument types, as an array of 'ffi_type *'.
        #
        #  - optionally, the result's and the arguments' ffi type data
        #    (this is used only for 'struct' ffi types; in other cases the
        #    'ffi_type *' just points to static data like 'ffi_type_sint32').
        #
        nargs = len(self.fargs)

        # start with a cif_description (cif and exchange_* fields)
        self.fb_alloc(llmemory.sizeof(CIF_DESCRIPTION, nargs))

        # next comes an array of 'ffi_type*', one per argument
        atypes = self.fb_alloc(rffi.sizeof(FFI_TYPE_P) * nargs)
        self.atypes = rffi.cast(FFI_TYPE_PP, atypes)

        # next comes the result type data
        self.rtype = self.fb_fill_type(self.fresult, True)

        # next comes each argument's type data
        for i, farg in enumerate(self.fargs):
            atype = self.fb_fill_type(farg, False)
            if self.atypes:
                self.atypes[i] = atype

    def align_arg(self, n):
        return (n + 7) & ~7

    def fb_build_exchange(self, cif_descr):
        nargs = len(self.fargs)

        # first, enough room for an array of 'nargs' pointers
        exchange_offset = rffi.sizeof(rffi.CCHARP) * nargs
        exchange_offset = self.align_arg(exchange_offset)
        cif_descr.exchange_result = exchange_offset

        # then enough room for the result, rounded up to sizeof(ffi_arg)
        exchange_offset += max(rffi.getintfield(self.rtype, 'c_size'),
                               SIZE_OF_FFI_ARG)

        # loop over args
        for i, farg in enumerate(self.fargs):
            if isinstance(farg, W_CTypePointer):
                exchange_offset += 1   # for the "must free" flag
            exchange_offset = self.align_arg(exchange_offset)
            cif_descr.exchange_args[i] = exchange_offset
            exchange_offset += rffi.getintfield(self.atypes[i], 'c_size')

        # store the exchange data size
        # we also align it to the next multiple of 8, in an attempt to
        # work around bugs(?) of libffi (see cffi issue #241)
        cif_descr.exchange_size = self.align_arg(exchange_offset)

    def fb_extra_fields(self, cif_descr):
        cif_descr.abi = self.fabi
        cif_descr.nargs = len(self.fargs)
        cif_descr.rtype = self.rtype
        cif_descr.atypes = self.atypes

    @jit.dont_look_inside
    def rawallocate(self, ctypefunc):
        space = ctypefunc.space
        self.space = space

        # compute the total size needed in the CIF_DESCRIPTION buffer
        self.nb_bytes = 0
        self.bufferp = lltype.nullptr(rffi.CCHARP.TO)
        self.fb_build()

        # allocate the buffer
        if we_are_translated():
            rawmem = lltype.malloc(rffi.CCHARP.TO, self.nb_bytes,
                                   flavor='raw')
            rawmem = rffi.cast(CIF_DESCRIPTION_P, rawmem)
        else:
            # gross overestimation of the length below, but too bad
            rawmem = lltype.malloc(CIF_DESCRIPTION_P.TO, self.nb_bytes,
                                   flavor='raw')

        # the buffer is automatically managed from the W_CTypeFunc instance
        ctypefunc.cif_descr = rawmem

        # call again fb_build() to really build the libffi data structures
        self.bufferp = rffi.cast(rffi.CCHARP, rawmem)
        self.fb_build()
        assert self.bufferp == rffi.ptradd(rffi.cast(rffi.CCHARP, rawmem),
                                           self.nb_bytes)

        # fill in the 'exchange_*' fields
        self.fb_build_exchange(rawmem)

        # fill in the extra fields
        self.fb_extra_fields(rawmem)

        # call libffi's ffi_prep_cif() function
        res = jit_libffi.jit_ffi_prep_cif(rawmem)
        if res != clibffi.FFI_OK:
            raise oefmt(space.w_SystemError,
                        "libffi failed to build this function type")
