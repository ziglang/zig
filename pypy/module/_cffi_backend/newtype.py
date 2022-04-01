import sys
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec

from rpython.rlib.objectmodel import specialize, r_dict, compute_identity_hash
from rpython.rlib.rarithmetic import ovfcheck, intmask
from rpython.rlib import jit, rweakref, clibffi
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rffi_platform

from pypy.module._cffi_backend.moduledef import FFI_DEFAULT_ABI
from pypy.module._cffi_backend import (ctypeobj, ctypeprim, ctypeptr,
    ctypearray, ctypestruct, ctypevoid, ctypeenum)


@specialize.memo()
def alignment(TYPE):
    S = lltype.Struct('aligncheck', ('x', lltype.Char), ('y', TYPE))
    return rffi.offsetof(S, 'y')

alignment_of_pointer = alignment(rffi.CCHARP)

# ____________________________________________________________

class UniqueCache:
    for_testing = False    # set to True on the class level in test_c.py

    def __init__(self, space):
        self.ctvoid = None      # Cache for the 'void' type
        self.ctvoidp = None     # Cache for the 'void *' type
        self.ctchara = None     # Cache for the 'char[]' type
        self.primitives = {}    # Cache for {name: primitive_type}
        self.functions = []     # see _new_function_type()
        self.functions_packed = None     # only across translation

    def _cleanup_(self):
        import gc
        assert self.functions_packed is None
        # Note: a full PyPy translation may still have
        # 'self.functions == []' at this point, possibly depending
        # on details.  Code tested directly in test_ffi_obj
        gc.collect()
        funcs = []
        for weakdict in self.functions:
            funcs += weakdict._dict.values()
        del self.functions[:]
        self.functions_packed = funcs if len(funcs) > 0 else None

    def unpack_functions(self):
        for fct in self.functions_packed:
            _record_function_type(self, fct)
        self.functions_packed = None


def _clean_cache(space):
    "NOT_RPYTHON"
    from pypy.module._cffi_backend.realize_c_type import RealizeCache
    from pypy.module._cffi_backend.call_python import KeepaliveCache
    if hasattr(space, 'fromcache'):   # not with the TinyObjSpace
        space.fromcache(UniqueCache).__init__(space)
        space.fromcache(RealizeCache).__init__(space)
        space.fromcache(KeepaliveCache).__init__(space)

# ____________________________________________________________


PRIMITIVE_TYPES = {}

def eptype(name, TYPE, ctypecls, rep=1):
    PRIMITIVE_TYPES[name] = ctypecls, rffi.sizeof(TYPE) * rep, alignment(TYPE)

def eptypesize(name, size, ctypecls):
    for TYPE in [lltype.Signed, lltype.SignedLongLong, rffi.SIGNEDCHAR,
                 rffi.SHORT, rffi.INT, rffi.LONG, rffi.LONGLONG]:
        if rffi.sizeof(TYPE) == size:
            eptype(name, TYPE, ctypecls)
            return
    raise NotImplementedError("no integer type of size %d??" % size)

eptype("char",        lltype.Char,     ctypeprim.W_CTypePrimitiveChar)
eptype("wchar_t",     lltype.UniChar,  ctypeprim.W_CTypePrimitiveUniChar)
eptype("signed char", rffi.SIGNEDCHAR, ctypeprim.W_CTypePrimitiveSigned)
eptype("short",       rffi.SHORT,      ctypeprim.W_CTypePrimitiveSigned)
eptype("int",         rffi.INT,        ctypeprim.W_CTypePrimitiveSigned)
eptype("long",        rffi.LONG,       ctypeprim.W_CTypePrimitiveSigned)
eptype("long long",   rffi.LONGLONG,   ctypeprim.W_CTypePrimitiveSigned)
eptype("unsigned char",      rffi.UCHAR,    ctypeprim.W_CTypePrimitiveUnsigned)
eptype("unsigned short",     rffi.SHORT,    ctypeprim.W_CTypePrimitiveUnsigned)
eptype("unsigned int",       rffi.INT,      ctypeprim.W_CTypePrimitiveUnsigned)
eptype("unsigned long",      rffi.LONG,     ctypeprim.W_CTypePrimitiveUnsigned)
eptype("unsigned long long", rffi.LONGLONG, ctypeprim.W_CTypePrimitiveUnsigned)
eptype("float",  rffi.FLOAT,  ctypeprim.W_CTypePrimitiveFloat)
eptype("double", rffi.DOUBLE, ctypeprim.W_CTypePrimitiveFloat)
eptype("long double", rffi.LONGDOUBLE, ctypeprim.W_CTypePrimitiveLongDouble)
eptype("_Bool",  lltype.Bool,          ctypeprim.W_CTypePrimitiveBool)

eptype("float _Complex",  rffi.FLOAT,  ctypeprim.W_CTypePrimitiveComplex, rep=2)
eptype("double _Complex", rffi.DOUBLE, ctypeprim.W_CTypePrimitiveComplex, rep=2)

eptypesize("int8_t",   1, ctypeprim.W_CTypePrimitiveSigned)
eptypesize("uint8_t",  1, ctypeprim.W_CTypePrimitiveUnsigned)
eptypesize("int16_t",  2, ctypeprim.W_CTypePrimitiveSigned)
eptypesize("uint16_t", 2, ctypeprim.W_CTypePrimitiveUnsigned)
eptypesize("int32_t",  4, ctypeprim.W_CTypePrimitiveSigned)
eptypesize("uint32_t", 4, ctypeprim.W_CTypePrimitiveUnsigned)
eptypesize("int64_t",  8, ctypeprim.W_CTypePrimitiveSigned)
eptypesize("uint64_t", 8, ctypeprim.W_CTypePrimitiveUnsigned)

eptype("intptr_t",  rffi.INTPTR_T,  ctypeprim.W_CTypePrimitiveSigned)
eptype("uintptr_t", rffi.UINTPTR_T, ctypeprim.W_CTypePrimitiveUnsigned)
eptype("size_t",    rffi.SIZE_T,    ctypeprim.W_CTypePrimitiveUnsigned)
eptype("ssize_t",   rffi.SSIZE_T,   ctypeprim.W_CTypePrimitiveSigned)

eptypesize("char16_t", 2, ctypeprim.W_CTypePrimitiveUniChar)
eptypesize("char32_t", 4, ctypeprim.W_CTypePrimitiveUniChar)

_WCTSigned = ctypeprim.W_CTypePrimitiveSigned
_WCTUnsign = ctypeprim.W_CTypePrimitiveUnsigned

eptype("ptrdiff_t", getattr(rffi, 'PTRDIFF_T', rffi.INTPTR_T), _WCTSigned)
eptype("intmax_t",  getattr(rffi, 'INTMAX_T',  rffi.LONGLONG), _WCTSigned)
eptype("uintmax_t", getattr(rffi, 'UINTMAX_T', rffi.LONGLONG), _WCTUnsign)

if hasattr(rffi, 'INT_LEAST8_T'):
    eptype("int_least8_t",  rffi.INT_LEAST8_T,  _WCTSigned)
    eptype("int_least16_t", rffi.INT_LEAST16_T, _WCTSigned)
    eptype("int_least32_t", rffi.INT_LEAST32_T, _WCTSigned)
    eptype("int_least64_t", rffi.INT_LEAST64_T, _WCTSigned)
    eptype("uint_least8_t", rffi.UINT_LEAST8_T,  _WCTUnsign)
    eptype("uint_least16_t",rffi.UINT_LEAST16_T, _WCTUnsign)
    eptype("uint_least32_t",rffi.UINT_LEAST32_T, _WCTUnsign)
    eptype("uint_least64_t",rffi.UINT_LEAST64_T, _WCTUnsign)
else:
    eptypesize("int_least8_t",   1, _WCTSigned)
    eptypesize("uint_least8_t",  1, _WCTUnsign)
    eptypesize("int_least16_t",  2, _WCTSigned)
    eptypesize("uint_least16_t", 2, _WCTUnsign)
    eptypesize("int_least32_t",  4, _WCTSigned)
    eptypesize("uint_least32_t", 4, _WCTUnsign)
    eptypesize("int_least64_t",  8, _WCTSigned)
    eptypesize("uint_least64_t", 8, _WCTUnsign)

if hasattr(rffi, 'INT_FAST8_T'):
    eptype("int_fast8_t",  rffi.INT_FAST8_T,  _WCTSigned)
    eptype("int_fast16_t", rffi.INT_FAST16_T, _WCTSigned)
    eptype("int_fast32_t", rffi.INT_FAST32_T, _WCTSigned)
    eptype("int_fast64_t", rffi.INT_FAST64_T, _WCTSigned)
    eptype("uint_fast8_t", rffi.UINT_FAST8_T,  _WCTUnsign)
    eptype("uint_fast16_t",rffi.UINT_FAST16_T, _WCTUnsign)
    eptype("uint_fast32_t",rffi.UINT_FAST32_T, _WCTUnsign)
    eptype("uint_fast64_t",rffi.UINT_FAST64_T, _WCTUnsign)
else:
    eptypesize("int_fast8_t",   1, _WCTSigned)
    eptypesize("uint_fast8_t",  1, _WCTUnsign)
    eptypesize("int_fast16_t",  2, _WCTSigned)
    eptypesize("uint_fast16_t", 2, _WCTUnsign)
    eptypesize("int_fast32_t",  4, _WCTSigned)
    eptypesize("uint_fast32_t", 4, _WCTUnsign)
    eptypesize("int_fast64_t",  8, _WCTSigned)
    eptypesize("uint_fast64_t", 8, _WCTUnsign)

@unwrap_spec(name='text')
def new_primitive_type(space, name):
    return _new_primitive_type(space, name)

@jit.elidable
def _new_primitive_type(space, name):
    unique_cache = space.fromcache(UniqueCache)
    try:
        return unique_cache.primitives[name]
    except KeyError:
        pass
    try:
        ctypecls, size, align = PRIMITIVE_TYPES[name]
    except KeyError:
        raise OperationError(space.w_KeyError, space.newtext(name))
    ctype = ctypecls(space, size, name, len(name), align)
    unique_cache.primitives[name] = ctype
    return ctype

# ____________________________________________________________

@specialize.memo()
def _setup_wref(has_weakref_support):
    assert has_weakref_support, "_cffi_backend requires weakrefs"
    ctypeobj.W_CType._pointer_type = rweakref.dead_ref
    ctypeptr.W_CTypePointer._array_types = None

@unwrap_spec(w_ctype=ctypeobj.W_CType)
def new_pointer_type(space, w_ctype):
    return _new_pointer_type(space, w_ctype)

@jit.elidable
def _new_pointer_type(space, w_ctype):
    _setup_wref(rweakref.has_weakref_support())
    ctptr = w_ctype._pointer_type()
    if ctptr is None:
        ctptr = ctypeptr.W_CTypePointer(space, w_ctype)
        w_ctype._pointer_type = rweakref.ref(ctptr)
    return ctptr

# ____________________________________________________________

@unwrap_spec(w_ctptr=ctypeobj.W_CType)
def new_array_type(space, w_ctptr, w_length):
    if space.is_w(w_length, space.w_None):
        length = -1
    else:
        length = space.getindex_w(w_length, space.w_OverflowError)
        if length < 0:
            raise oefmt(space.w_ValueError, "negative array length")
    return _new_array_type(space, w_ctptr, length)

@jit.elidable
def _new_array_type(space, w_ctptr, length):
    _setup_wref(rweakref.has_weakref_support())
    if not isinstance(w_ctptr, ctypeptr.W_CTypePointer):
        raise oefmt(space.w_TypeError, "first arg must be a pointer ctype")
    arrays = w_ctptr._array_types
    if arrays is None:
        arrays = rweakref.RWeakValueDictionary(int, ctypearray.W_CTypeArray)
        w_ctptr._array_types = arrays
    else:
        ctype = arrays.get(length)
        if ctype is not None:
            return ctype
    #
    ctitem = w_ctptr.ctitem
    if ctitem.size < 0:
        raise oefmt(space.w_ValueError, "array item of unknown size: '%s'",
                    ctitem.name)
    if length < 0:
        assert length == -1
        arraysize = -1
        extra = '[]'
    else:
        try:
            arraysize = ovfcheck(length * ctitem.size)
        except OverflowError:
            raise oefmt(space.w_OverflowError,
                        "array size would overflow a ssize_t")
        extra = '[%d]' % length
    #
    ctype = ctypearray.W_CTypeArray(space, w_ctptr, length, arraysize, extra)
    arrays.set(length, ctype)
    return ctype

# ____________________________________________________________


SF_MSVC_BITFIELDS     = 0x01
SF_GCC_ARM_BITFIELDS  = 0x02
SF_GCC_X86_BITFIELDS  = 0x10

SF_GCC_BIG_ENDIAN     = 0x04
SF_GCC_LITTLE_ENDIAN  = 0x40

SF_PACKED             = 0x08
SF_STD_FIELD_POS      = 0x80

if sys.platform == 'win32':
    SF_DEFAULT_PACKING = 8
else:
    SF_DEFAULT_PACKING = 0x40000000    # a huge power of two


if sys.platform == 'win32':
    DEFAULT_SFLAGS_PLATFORM = SF_MSVC_BITFIELDS
else:
    if (rffi_platform.getdefined('__arm__', '') or
        rffi_platform.getdefined('__aarch64__', '')):
        DEFAULT_SFLAGS_PLATFORM = SF_GCC_ARM_BITFIELDS
    else:
        DEFAULT_SFLAGS_PLATFORM = SF_GCC_X86_BITFIELDS

if sys.byteorder == 'big':
    DEFAULT_SFLAGS_ENDIAN = SF_GCC_BIG_ENDIAN
else:
    DEFAULT_SFLAGS_ENDIAN = SF_GCC_LITTLE_ENDIAN


def complete_sflags(sflags):
    # add one of the SF_xxx_BITFIELDS flags if none is specified
    if not (sflags & (SF_MSVC_BITFIELDS | SF_GCC_ARM_BITFIELDS |
                      SF_GCC_X86_BITFIELDS)):
        sflags |= DEFAULT_SFLAGS_PLATFORM
    # add one of SF_GCC_xx_ENDIAN if none is specified
    if not (sflags & (SF_GCC_BIG_ENDIAN | SF_GCC_LITTLE_ENDIAN)):
        sflags |= DEFAULT_SFLAGS_ENDIAN
    return sflags

# ____________________________________________________________


@unwrap_spec(name='text')
def new_struct_type(space, name):
    return ctypestruct.W_CTypeStruct(space, name)

@unwrap_spec(name='text')
def new_union_type(space, name):
    return ctypestruct.W_CTypeUnion(space, name)

def detect_custom_layout(w_ctype, sflags, cdef_value, compiler_value,
                         msg1, msg2="", msg3=""):
    if compiler_value != cdef_value:
        if sflags & SF_STD_FIELD_POS:
            from pypy.module._cffi_backend.ffi_obj import get_ffi_error
            w_FFIError = get_ffi_error(w_ctype.space)
            raise oefmt(w_FFIError,
                    '%s: %s%s%s (cdef says %d, but C compiler says %d).'
                    ' fix it or use "...;" as the last field in the '
                    'cdef for %s to make it flexible',
                    w_ctype.name, msg1, msg2, msg3,
                    cdef_value, compiler_value, w_ctype.name)
        w_ctype._custom_field_pos = True

def roundup_bytes(bytes, bit):
    assert bit == (bit & 7)
    return bytes + (bit > 0)

@unwrap_spec(w_ctype=ctypeobj.W_CType, totalsize=int, totalalignment=int,
             sflags=int, pack=int)
def complete_struct_or_union(space, w_ctype, w_fields, w_ignored=None,
                             totalsize=-1, totalalignment=-1, sflags=0,
                             pack=0):
    sflags = complete_sflags(sflags)
    if sflags & SF_PACKED:
        pack = 1
    elif pack <= 0:
        pack = SF_DEFAULT_PACKING
    else:
        sflags |= SF_PACKED

    if (not isinstance(w_ctype, ctypestruct.W_CTypeStructOrUnion)
            or w_ctype.size >= 0):
        raise oefmt(space.w_TypeError,
                    "first arg must be a non-initialized struct or union "
                    "ctype")

    is_union = isinstance(w_ctype, ctypestruct.W_CTypeUnion)
    alignment = 1
    byteoffset = 0     # the real value is 'byteoffset+bitoffset*8', which
    bitoffset = 0      #     counts the offset in bits
    byteoffsetmax = 0  # the maximum value of byteoffset-rounded-up-to-byte
    prev_bitfield_size = 0
    prev_bitfield_free = 0
    fields_w = space.listview(w_fields)
    fields_list = []
    fields_dict = {}
    w_ctype._custom_field_pos = False
    with_var_array = False
    with_packed_change = False

    for i in range(len(fields_w)):
        w_field = fields_w[i]
        field_w = space.fixedview(w_field)
        if not (2 <= len(field_w) <= 4):
            raise oefmt(space.w_TypeError, "bad field descr")
        fname = space.text_w(field_w[0])
        ftype = space.interp_w(ctypeobj.W_CType, field_w[1])
        fbitsize = -1
        foffset = -1
        if len(field_w) > 2: fbitsize = space.int_w(field_w[2])
        if len(field_w) > 3: foffset = space.int_w(field_w[3])
        #
        if fname in fields_dict:
            raise oefmt(space.w_KeyError, "duplicate field name '%s'", fname)
        #
        if ftype.size < 0:
            if (isinstance(ftype, ctypearray.W_CTypeArray) and fbitsize < 0
                    and (i == len(fields_w) - 1 or foffset != -1)):
                with_var_array = True
            else:
                raise oefmt(space.w_TypeError,
                            "field '%s.%s' has ctype '%s' of unknown size",
                            w_ctype.name, fname, ftype.name)
        elif isinstance(ftype, ctypestruct.W_CTypeStructOrUnion):
            ftype.force_lazy_struct()
            # GCC (or maybe C99) accepts var-sized struct fields that are not
            # the last field of a larger struct.  That's why there is no
            # check here for "last field": we propagate the flag
            # '_with_var_array' to any struct that contains either an open-
            # ended array or another struct that recursively contains an
            # open-ended array.
            if ftype._with_var_array:
                with_var_array = True
        #
        if is_union:
            byteoffset = bitoffset = 0        # reset each field at offset 0
        #
        # update the total alignment requirement, but skip it if the
        # field is an anonymous bitfield or if SF_PACKED
        falignorg = ftype.alignof()
        falign = min(pack, falignorg)
        do_align = True
        if (sflags & SF_GCC_ARM_BITFIELDS) == 0 and fbitsize >= 0:
            if (sflags & SF_MSVC_BITFIELDS) == 0:
                # GCC: anonymous bitfields (of any size) don't cause alignment
                do_align = (fname != '')
            else:
                # MSVC: zero-sized bitfields don't cause alignment
                do_align = (fbitsize > 0)
        if alignment < falign and do_align:
            alignment = falign
        #
        if is_union and i > 0:
            fflags = ctypestruct.W_CField.BF_IGNORE_IN_CTOR
        else:
            fflags = 0
        #
        if fbitsize < 0:
            # not a bitfield: common case

            if isinstance(ftype, ctypearray.W_CTypeArray) and ftype.length<=0:
                bs_flag = ctypestruct.W_CField.BS_EMPTY_ARRAY
            else:
                bs_flag = ctypestruct.W_CField.BS_REGULAR

            # align this field to its own 'falign' by inserting padding.
            # first, pad to the next byte,
            # then pad to 'falign' or 'falignorg' bytes
            byteoffset = roundup_bytes(byteoffset, bitoffset)
            bitoffset = 0
            byteoffsetorg = (byteoffset + falignorg-1) & ~(falignorg-1)
            byteoffset = (byteoffset + falign-1) & ~(falign-1)

            if byteoffsetorg != byteoffset:
                with_packed_change = True

            if foffset >= 0:
                # a forced field position: ignore the offset just computed,
                # except to know if we must set 'custom_field_pos'
                detect_custom_layout(w_ctype, sflags, byteoffset, foffset,
                                     "wrong offset for field '",
                                     fname, "'")
                byteoffset = foffset

            if (fname == '' and
                    isinstance(ftype, ctypestruct.W_CTypeStructOrUnion)):
                # a nested anonymous struct or union
                # note: it seems we only get here with ffi.verify()
                srcfield2names = {}
                for name, srcfld in ftype._fields_dict.items():
                    srcfield2names[srcfld] = name
                for srcfld in ftype._fields_list:
                    fld = srcfld.make_shifted(byteoffset, fflags)
                    fields_list.append(fld)
                    try:
                        fields_dict[srcfield2names[srcfld]] = fld
                    except KeyError:
                        pass
                # always forbid such structures from being passed by value
                w_ctype._custom_field_pos = True
            else:
                # a regular field
                fld = ctypestruct.W_CField(ftype, byteoffset, bs_flag, -1,
                                           fflags)
                fields_list.append(fld)
                fields_dict[fname] = fld

            if ftype.size >= 0:
                byteoffset += ftype.size
            prev_bitfield_size = 0

        else:
            # this is the case of a bitfield

            if foffset >= 0:
                raise oefmt(space.w_TypeError,
                            "field '%s.%s' is a bitfield, but a fixed offset "
                            "is specified", w_ctype.name, fname)

            if not (isinstance(ftype, ctypeprim.W_CTypePrimitiveSigned) or
                    isinstance(ftype, ctypeprim.W_CTypePrimitiveUnsigned) or
                    isinstance(ftype,ctypeprim.W_CTypePrimitiveCharOrUniChar)):
                raise oefmt(space.w_TypeError,
                            "field '%s.%s' declared as '%s' cannot be a bit "
                            "field", w_ctype.name, fname, ftype.name)
            if fbitsize > 8 * ftype.size:
                raise oefmt(space.w_TypeError,
                            "bit field '%s.%s' is declared '%s:%d', which "
                            "exceeds the width of the type",
                            w_ctype.name, fname, ftype.name, fbitsize)

            # compute the starting position of the theoretical field
            # that covers a complete 'ftype', inside of which we will
            # locate the real bitfield
            field_offset_bytes = byteoffset
            field_offset_bytes &= ~(falign - 1)

            if fbitsize == 0:
                if fname != '':
                    raise oefmt(space.w_TypeError,
                                "field '%s.%s' is declared with :0",
                                w_ctype.name, fname)
                if (sflags & SF_MSVC_BITFIELDS) == 0:
                    # GCC's notion of "ftype :0;"
                    # pad byteoffset to a value aligned for "ftype"
                    if (roundup_bytes(byteoffset, bitoffset) >
                                                    field_offset_bytes):
                        field_offset_bytes += falign
                        assert byteoffset < field_offset_bytes
                    byteoffset = field_offset_bytes
                    bitoffset = 0
                else:
                    # MSVC's notion of "ftype :0;
                    # Mostly ignored.  It seems they only serve as
                    # separator between other bitfields, to force them
                    # into separate words.
                    pass
                prev_bitfield_size = 0

            else:
                if (sflags & SF_MSVC_BITFIELDS) == 0:
                    # GCC's algorithm

                    # Can the field start at the offset given by 'boffset'?  It
                    # can if it would entirely fit into an aligned ftype field.
                    bits_already_occupied = (
                        (byteoffset-field_offset_bytes) * 8 + bitoffset)

                    if bits_already_occupied + fbitsize > 8 * ftype.size:
                        # it would not fit, we need to start at the next
                        # allowed position
                        if ((sflags & SF_PACKED) != 0 and
                            (bits_already_occupied & 7) != 0):
                            raise oefmt(space.w_NotImplementedError,
                                        "with 'packed', gcc would compile "
                                        "field '%s.%s' to reuse some bits in "
                                        "the previous field",
                                        w_ctype.name, fname)
                        field_offset_bytes += falign
                        assert byteoffset < field_offset_bytes
                        byteoffset = field_offset_bytes
                        bitoffset = 0
                        bitshift = 0
                    else:
                        bitshift = bits_already_occupied
                        assert bitshift >= 0
                    bitoffset += fbitsize
                    byteoffset += (bitoffset >> 3)
                    bitoffset &= 7

                else:
                    # MSVC's algorithm

                    # A bitfield is considered as taking the full width
                    # of their declared type.  It can share some bits
                    # with the previous field only if it was also a
                    # bitfield and used a type of the same size.
                    if (prev_bitfield_size == ftype.size and
                        prev_bitfield_free >= fbitsize):
                        # yes: reuse
                        bitshift = 8 * prev_bitfield_size - prev_bitfield_free
                    else:
                        # no: start a new full field
                        byteoffset = roundup_bytes(byteoffset, bitoffset)
                        bitoffset = 0
                        # align
                        byteoffset = (byteoffset + falign-1) & ~(falign-1)
                        byteoffset += ftype.size
                        bitshift = 0
                        prev_bitfield_size = ftype.size
                        prev_bitfield_free = 8 * prev_bitfield_size
                    #
                    prev_bitfield_free -= fbitsize
                    field_offset_bytes = byteoffset - ftype.size

                if sflags & SF_GCC_BIG_ENDIAN:
                    bitshift = 8 * ftype.size - fbitsize- bitshift

                if fname != '':
                    fld = ctypestruct.W_CField(ftype, field_offset_bytes,
                                               bitshift, fbitsize, fflags)
                    fields_list.append(fld)
                    fields_dict[fname] = fld

        if roundup_bytes(byteoffset, bitoffset) > byteoffsetmax:
            byteoffsetmax = roundup_bytes(byteoffset, bitoffset)

    # Like C, if the size of this structure would be zero, we compute it
    # as 1 instead.  But for ctypes support, we allow the manually-
    # specified totalsize to be zero in this case.
    alignedsize = (byteoffsetmax + alignment - 1) & ~(alignment - 1)
    alignedsize = alignedsize or 1

    if totalsize < 0:
        totalsize = alignedsize
    else:
        detect_custom_layout(w_ctype, sflags, alignedsize, totalsize,
                             "wrong total size")
        if totalsize < byteoffsetmax:
            raise oefmt(space.w_TypeError,
                "%s cannot be of size %d: there are fields at least up to %d",
                w_ctype.name, totalsize, byteoffsetmax)
    if totalalignment < 0:
        totalalignment = alignment
    else:
        detect_custom_layout(w_ctype, sflags, alignment, totalalignment,
                             "wrong total alignment")

    w_ctype.size = totalsize
    w_ctype.alignment = totalalignment
    w_ctype._fields_list = fields_list[:]
    w_ctype._fields_dict = fields_dict
    #w_ctype._custom_field_pos = ...set above already
    w_ctype._with_var_array = with_var_array
    w_ctype._with_packed_change = with_packed_change

# ____________________________________________________________

def new_void_type(space):
    return _new_void_type(space)

@jit.elidable
def _new_void_type(space):
    unique_cache = space.fromcache(UniqueCache)
    if unique_cache.ctvoid is None:
        unique_cache.ctvoid = ctypevoid.W_CTypeVoid(space)
    return unique_cache.ctvoid

@jit.elidable
def _new_voidp_type(space):
    unique_cache = space.fromcache(UniqueCache)
    if unique_cache.ctvoidp is None:
        unique_cache.ctvoidp = new_pointer_type(space, new_void_type(space))
    return unique_cache.ctvoidp

@jit.elidable
def _new_chara_type(space):
    unique_cache = space.fromcache(UniqueCache)
    if unique_cache.ctchara is None:
        ctchar = new_primitive_type(space, "char")
        ctcharp = new_pointer_type(space, ctchar)
        ctchara = _new_array_type(space, ctcharp, length=-1)
        unique_cache.ctchara = ctchara
    return unique_cache.ctchara

# ____________________________________________________________

@unwrap_spec(name='text', w_basectype=ctypeobj.W_CType)
def new_enum_type(space, name, w_enumerators, w_enumvalues, w_basectype):
    enumerators_w = space.fixedview(w_enumerators)
    enumvalues_w  = space.fixedview(w_enumvalues)
    if len(enumerators_w) != len(enumvalues_w):
        raise oefmt(space.w_ValueError, "tuple args must have the same size")
    enumerators = [space.text_w(w) for w in enumerators_w]
    #
    if (not isinstance(w_basectype, ctypeprim.W_CTypePrimitiveSigned) and
        not isinstance(w_basectype, ctypeprim.W_CTypePrimitiveUnsigned)):
        raise oefmt(space.w_TypeError,
                    "expected a primitive signed or unsigned base type")
    #
    lvalue = lltype.malloc(rffi.CCHARP.TO, w_basectype.size, flavor='raw')
    try:
        for w in enumvalues_w:
            # detects out-of-range or badly typed values
            w_basectype.convert_from_object(lvalue, w)
    finally:
        lltype.free(lvalue, flavor='raw')
    #
    size = w_basectype.size
    align = w_basectype.align
    if isinstance(w_basectype, ctypeprim.W_CTypePrimitiveSigned):
        enumvalues = [space.int_w(w) for w in enumvalues_w]
        ctype = ctypeenum.W_CTypeEnumSigned(space, name, size, align,
                                            enumerators, enumvalues)
    else:
        enumvalues = [space.uint_w(w) for w in enumvalues_w]
        ctype = ctypeenum.W_CTypeEnumUnsigned(space, name, size, align,
                                              enumerators, enumvalues)
    return ctype

# ____________________________________________________________

@unwrap_spec(w_fresult=ctypeobj.W_CType, ellipsis=int, abi=int)
def new_function_type(space, w_fargs, w_fresult, ellipsis=0,
                      abi=FFI_DEFAULT_ABI):
    fargs = []
    for w_farg in space.fixedview(w_fargs):
        if not isinstance(w_farg, ctypeobj.W_CType):
            raise oefmt(space.w_TypeError,
                        "first arg must be a tuple of ctype objects")
        if isinstance(w_farg, ctypearray.W_CTypeArray):
            w_farg = w_farg.ctptr
        fargs.append(w_farg)
    return _new_function_type(space, fargs, w_fresult, bool(ellipsis), abi)

def _func_key_hash(unique_cache, fargs, fresult, ellipsis, abi):
    x = compute_identity_hash(fresult)
    for w_arg in fargs:
        y = compute_identity_hash(w_arg)
        x = intmask((1000003 * x) ^ y)
    x ^= ellipsis + 2 * abi
    if unique_cache.for_testing:    # constant-folded to False in translation;
        x &= 3                      # but for test, keep only 2 bits of hash
    return x

# can't use @jit.elidable here, because it might call back to random
# space functions via force_lazy_struct()
def _new_function_type(space, fargs, fresult, ellipsis, abi):
    try:
        return _get_function_type(space, fargs, fresult, ellipsis, abi)
    except KeyError:
        return _build_function_type(space, fargs, fresult, ellipsis, abi)

@jit.elidable
def _get_function_type(space, fargs, fresult, ellipsis, abi):
    # This function is elidable because if called again with exactly the
    # same arguments (and if it didn't raise KeyError), it would give
    # the same result, at least as long as this result is still live.
    #
    # 'unique_cache.functions' is a list of weak dicts, each mapping
    # the func_hash number to a W_CTypeFunc.  There is normally only
    # one such dict, but in case of hash collision, there might be
    # more.
    unique_cache = space.fromcache(UniqueCache)
    if unique_cache.functions_packed is not None:
        unique_cache.unpack_functions()
    func_hash = _func_key_hash(unique_cache, fargs, fresult, ellipsis, abi)
    for weakdict in unique_cache.functions:
        ctype = weakdict.get(func_hash)
        if (ctype is not None and
            ctype.ctitem is fresult and
            ctype.fargs == fargs and
            ctype.ellipsis == ellipsis and
            ctype.abi == abi):
            return ctype
    raise KeyError

@jit.dont_look_inside
def _build_function_type(space, fargs, fresult, ellipsis, abi):
    from pypy.module._cffi_backend import ctypefunc
    #
    if ((fresult.size < 0 and
         not isinstance(fresult, ctypevoid.W_CTypeVoid))
        or isinstance(fresult, ctypearray.W_CTypeArray)):
        if (isinstance(fresult, ctypestruct.W_CTypeStructOrUnion) and
                fresult.size < 0):
            raise oefmt(space.w_TypeError,
                        "result type '%s' is opaque", fresult.name)
        else:
            raise oefmt(space.w_TypeError,
                        "invalid result type: '%s'", fresult.name)
    #
    fct = ctypefunc.W_CTypeFunc(space, fargs, fresult, ellipsis, abi)
    unique_cache = space.fromcache(UniqueCache)
    _record_function_type(unique_cache, fct)
    return fct

def _record_function_type(unique_cache, fct):
    from pypy.module._cffi_backend import ctypefunc
    #
    func_hash = _func_key_hash(unique_cache, fct.fargs, fct.ctitem,
                               fct.ellipsis, fct.abi)
    for weakdict in unique_cache.functions:
        if weakdict.get(func_hash) is None:
            break
    else:
        weakdict = rweakref.RWeakValueDictionary(int, ctypefunc.W_CTypeFunc)
        unique_cache.functions.append(weakdict)
    weakdict.set(func_hash, fct)
