""" Interpreter-level implementation of structure, exposing ll-structure
to app-level with apropriate interface
"""

from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import interp_attrproperty, interp_attrproperty_w
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.interpreter.error import OperationError, oefmt
from pypy.module._rawffi.interp_rawffi import segfault_exception, _MS_WINDOWS
from pypy.module._rawffi.interp_rawffi import W_DataShape, W_DataInstance
from pypy.module._rawffi.interp_rawffi import wrap_value, unwrap_value
from pypy.module._rawffi.interp_rawffi import unpack_shape_with_length
from pypy.module._rawffi.interp_rawffi import LL_TYPEMAP
from pypy.module._rawffi.interp_rawffi import unroll_letters_for_numbers
from pypy.module._rawffi.interp_rawffi import size_alignment
from pypy.module._rawffi.interp_rawffi import read_ptr, write_ptr
from rpython.rlib import clibffi, rgc, rutf8
from rpython.rlib.rarithmetic import intmask, signedtype, r_uint, \
    r_ulonglong
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.objectmodel import specialize
import sys

IS_BIG_ENDIAN = sys.byteorder == 'big'



def unpack_fields(space, w_fields):
    fields_w = space.unpackiterable(w_fields)
    fields = []
    for w_tup in fields_w:
        l_w = space.unpackiterable(w_tup)
        len_l = len(l_w)

        if len_l < 2 or len_l > 3:
            raise oefmt(space.w_ValueError,
                        "Expected list of 2- or 3-size tuples")

        try:
            name = space.text_w(l_w[0])
        except OperationError:
            raise oefmt(space.w_TypeError,
                        "structure field name must be string not %T", l_w[0])
        tp = unpack_shape_with_length(space, l_w[1])

        if len_l == 3:
            for c in unroll_letters_for_numbers:
                if c == tp.itemcode:
                    break
            else:
                raise oefmt(space.w_TypeError,
                            "bit fields not allowed for type")
            bitsize = space.int_w(l_w[2])
            if bitsize <= 0 or bitsize > tp.size * 8:
                raise oefmt(space.w_ValueError,
                            "number of bits invalid for bit field")
        else:
            bitsize = 0

        fields.append((name, tp, bitsize))
    return fields

def round_up(size, alignment):
    return (size + alignment - 1) & -alignment

NO_BITFIELD, NEW_BITFIELD, CONT_BITFIELD, EXPAND_BITFIELD = range(4)

def size_alignment_pos(fields, is_union=False, pack=0):
    size = 0
    alignment = 1
    pos = []
    bitsizes = []
    bitoffset = 0
    has_bitfield = False
    last_size = 0

    for fieldname, fieldtype, bitsize in fields:
        # fieldtype is a W_Array
        fieldsize = fieldtype.size
        fieldalignment = fieldtype.alignment
        if pack:
            fieldalignment = min(fieldalignment, pack)
        alignment = max(alignment, fieldalignment)

        if not bitsize:
            # not a bit field
            field_type = NO_BITFIELD
            last_size = 0
            bitoffset = 0
        elif (last_size and # we have a bitfield open
              (not _MS_WINDOWS or fieldsize * 8 == last_size) and
              fieldsize * 8 <= last_size and
              bitoffset + bitsize <= last_size):
            # continue bit field
            field_type = CONT_BITFIELD
        elif (not _MS_WINDOWS and
              last_size and # we have a bitfield open
              fieldsize * 8 >= last_size and
              bitoffset + bitsize <= fieldsize * 8):
            # expand bit field
            field_type = EXPAND_BITFIELD
        else:
            # start new bitfield
            field_type = NEW_BITFIELD
            has_bitfield = True
            bitoffset = 0
            last_size = fieldsize * 8

        if is_union:
            pos.append(0)
            bitsizes.append(fieldsize)
            size = max(size, fieldsize)
        else:
            if field_type == NO_BITFIELD:
                # the usual case
                size = round_up(size, fieldalignment)
                pos.append(size)
                size += intmask(fieldsize)
                bitsizes.append(fieldsize)
            elif field_type == NEW_BITFIELD:
                if IS_BIG_ENDIAN:
                    off = last_size - bitoffset - bitsize
                else:
                    off = bitoffset
                bitsizes.append((bitsize << 16) + off)
                bitoffset = bitsize
                size = round_up(size, fieldalignment)
                pos.append(size)
                size += fieldsize
            elif field_type == CONT_BITFIELD:
                if IS_BIG_ENDIAN:
                    off = last_size - bitoffset - bitsize
                else:
                    off = bitoffset
                bitsizes.append((bitsize << 16) + off)
                bitoffset += bitsize
                # offset is already updated for the NEXT field
                pos.append(size - fieldsize)
            elif field_type == EXPAND_BITFIELD:
                size += fieldsize - last_size / 8
                last_size = fieldsize * 8
                if IS_BIG_ENDIAN:
                    off = last_size - bitoffset - bitsize
                else:
                    off = bitoffset
                bitsizes.append((bitsize << 16) + off)
                bitoffset += bitsize
                # offset is already updated for the NEXT field
                pos.append(size - fieldsize)

    if not has_bitfield:
        bitsizes = None
    size = round_up(size, alignment)
    return size, alignment, pos, bitsizes


class W_Structure(W_DataShape):
    def __init__(self, space, fields, size, alignment, is_union=False, pack=0):
        name_to_index = {}
        if fields is not None:
            for i in range(len(fields)):
                name, tp, bitsize = fields[i]
                if name in name_to_index:
                    raise oefmt(space.w_ValueError,
                                "duplicate field name %s", name)
                try:
                    rutf8.check_ascii(name)
                except rutf8.CheckError:
                    raise oefmt(space.w_TypeError, 'non-ascii field name')
                name_to_index[name] = i
            size, alignment, pos, bitsizes = size_alignment_pos(
                fields, is_union, pack)
        else: # opaque case
            fields = []
            pos = []
            bitsizes = None
        self.fields = fields
        self.size = size
        self.alignment = alignment
        self.ll_positions = pos
        self.ll_bitsizes = bitsizes
        self.name_to_index = name_to_index

    def allocate(self, space, length, autofree=False):
        # length is ignored!
        if autofree:
            return W_StructureInstanceAutoFree(space, self)
        return W_StructureInstance(space, self, 0)

    def getindex(self, space, attr):
        try:
            return self.name_to_index[attr]
        except KeyError:
            raise oefmt(space.w_AttributeError,
                        "C Structure has no attribute %s", attr)

    @unwrap_spec(autofree=int)
    def descr_call(self, space, autofree=False):
        return self.allocate(space, 1, bool(autofree))

    def descr_repr(self, space):
        fieldnames = ' '.join(["'%s'" % name for name, _, _ in self.fields])
        return space.newtext("<_rawffi.Structure %s (%d, %d)>" % (fieldnames,
                                                                  self.size,
                                                                  self.alignment))

    @unwrap_spec(address=r_uint)
    def fromaddress(self, space, address):
        return W_StructureInstance(space, self, address)

    @unwrap_spec(attr='text')
    def descr_fieldoffset(self, space, attr):
        index = self.getindex(space, attr)
        return space.newint(self.ll_positions[index])

    @unwrap_spec(attr='text')
    def descr_fieldsize(self, space, attr):
        index = self.getindex(space, attr)
        if self.ll_bitsizes and index < len(self.ll_bitsizes):
            return space.newint(self.ll_bitsizes[index])
        else:
            return space.newint(self.fields[index][1].size)

    # get the corresponding ffi_type
    ffi_struct = lltype.nullptr(clibffi.FFI_STRUCT_P.TO)

    def get_basic_ffi_type(self):
        if not self.ffi_struct:
            # Repeated fields are delicate.  Consider for example
            #     struct { int a[5]; }
            # or  struct { struct {int x;} a[5]; }
            # Seeing no corresponding doc in clibffi, let's just repeat
            # the field 5 times...
            fieldtypes = []
            for name, tp, bitsize in self.fields:
                basic_ffi_type = tp.get_basic_ffi_type()
                basic_size, _ = size_alignment(basic_ffi_type)
                total_size = tp.size
                count = 0
                while count + basic_size <= total_size:
                    fieldtypes.append(basic_ffi_type)
                    count += basic_size
                    if basic_size == 0: # corner case. get out of this infinite
                        break           # loop after 1 iteration ("why not")
            self.ffi_struct = clibffi.make_struct_ffitype_e(self.size,
                                                           self.alignment,
                                                           fieldtypes)
        return self.ffi_struct.ffistruct

    @rgc.must_be_light_finalizer
    def __del__(self):
        if self.ffi_struct:
            lltype.free(self.ffi_struct, flavor='raw')


@unwrap_spec(union=int, pack=int)
def descr_new_structure(space, w_type, w_shapeinfo, union=0, pack=0):
    union = bool(union)
    if pack < 0:
        raise oefmt(space.w_ValueError,
                    "_pack_ must be a non-negative integer")

    if space.isinstance_w(w_shapeinfo, space.w_tuple):
        w_size, w_alignment = space.fixedview(w_shapeinfo, expected_length=2)
        S = W_Structure(space, None, space.int_w(w_size),
                                     space.int_w(w_alignment), union)
    else:
        fields = unpack_fields(space, w_shapeinfo)
        S = W_Structure(space, fields, 0, 0, union, pack)
    return S

W_Structure.typedef = TypeDef(
    'Structure',
    __new__     = interp2app(descr_new_structure),
    __call__    = interp2app(W_Structure.descr_call),
    __repr__    = interp2app(W_Structure.descr_repr),
    fromaddress = interp2app(W_Structure.fromaddress),
    size        = interp_attrproperty('size', W_Structure,
        wrapfn="newint"),
    alignment   = interp_attrproperty('alignment', W_Structure,
        wrapfn="newint"),
    fieldoffset = interp2app(W_Structure.descr_fieldoffset),
    fieldsize   = interp2app(W_Structure.descr_fieldsize),
    size_alignment = interp2app(W_Structure.descr_size_alignment),
    get_ffi_type   = interp2app(W_Structure.descr_get_ffi_type),
)
W_Structure.typedef.acceptable_as_base_class = False

def LOW_BIT(x):
    return x & 0xFFFF

def NUM_BITS(x):
    return x >> 16

@specialize.arg(1)
def BIT_MASK(x, ll_t):
    if ll_t is lltype.SignedLongLong or ll_t is lltype.UnsignedLongLong:
        one = r_ulonglong(1)
    else:
        one = r_uint(1)
    # to avoid left shift by x == sizeof(ll_t)
    return (((one << (x - 1)) - 1) << 1) + 1

@specialize.argtype(2)
def push_field(self, num, value):
    ptr = rffi.ptradd(self.ll_buffer, self.shape.ll_positions[num])
    TP = lltype.typeOf(value)
    # Handle bitfields
    for c in unroll_letters_for_numbers:
        if LL_TYPEMAP[c] is TP and self.shape.ll_bitsizes:
            # Modify the current value with the bitfield changed
            bitsize = self.shape.ll_bitsizes[num]
            numbits = NUM_BITS(bitsize)
            if numbits:
                lowbit = LOW_BIT(bitsize)
                bitmask = BIT_MASK(numbits, TP)
                masktype = lltype.typeOf(bitmask)
                value = rffi.cast(masktype, value)
                current = rffi.cast(masktype, read_ptr(ptr, 0, TP))
                current &= ~(bitmask << lowbit)
                current |= (value & bitmask) << lowbit
                value = rffi.cast(TP, current)
            break
    write_ptr(ptr, 0, value)

@specialize.arg(2)
def cast_pos(self, i, ll_t):
    pos = rffi.ptradd(self.ll_buffer, self.shape.ll_positions[i])
    value = read_ptr(pos, 0, ll_t)
    # Handle bitfields
    for c in unroll_letters_for_numbers:
        if LL_TYPEMAP[c] is ll_t and self.shape.ll_bitsizes:
            bitsize = self.shape.ll_bitsizes[i]
            numbits = NUM_BITS(bitsize)
            if numbits:
                lowbit = LOW_BIT(bitsize)
                bitmask = BIT_MASK(numbits, ll_t)
                masktype = lltype.typeOf(bitmask)
                value = rffi.cast(masktype, value)
                value >>= lowbit
                value &= bitmask
                if ll_t is lltype.Bool or signedtype(ll_t._type):
                    sign = (value >> (numbits - 1)) & 1
                    if sign:
                        value -= bitmask + 1
                value = rffi.cast(ll_t, value)
            break
    return value

class W_StructureInstance(W_DataInstance):
    def __init__(self, space, shape, address):
        W_DataInstance.__init__(self, space, shape.size, address)
        self.shape = shape

    def descr_repr(self, space):
        addr = rffi.cast(lltype.Unsigned, self.ll_buffer)
        return space.newtext("<_rawffi struct %x>" % (addr,))

    @unwrap_spec(attr='text')
    def getattr(self, space, attr):
        if not self.ll_buffer:
            raise segfault_exception(space, "accessing NULL pointer")
        i = self.shape.getindex(space, attr)
        _, tp, _ = self.shape.fields[i]
        return wrap_value(space, cast_pos, self, i, tp.itemcode)

    @unwrap_spec(attr='text')
    def setattr(self, space, attr, w_value):
        if not self.ll_buffer:
            raise segfault_exception(space, "accessing NULL pointer")
        i = self.shape.getindex(space, attr)
        _, tp, _ = self.shape.fields[i]
        unwrap_value(space, push_field, self, i, tp.itemcode, w_value)

    @unwrap_spec(attr='text')
    def descr_fieldaddress(self, space, attr):
        i = self.shape.getindex(space, attr)
        ptr = rffi.ptradd(self.ll_buffer, self.shape.ll_positions[i])
        return space.newint(rffi.cast(lltype.Unsigned, ptr))

    def getrawsize(self):
        return self.shape.size


W_StructureInstance.typedef = TypeDef(
    'StructureInstance', None, None, "read-write",
    __repr__    = interp2app(W_StructureInstance.descr_repr),
    __getattr__ = interp2app(W_StructureInstance.getattr),
    __setattr__ = interp2app(W_StructureInstance.setattr),
    buffer      = GetSetProperty(W_StructureInstance.getbuffer),
    free        = interp2app(W_StructureInstance.free),
    shape       = interp_attrproperty_w('shape', W_StructureInstance),
    byptr       = interp2app(W_StructureInstance.byptr),
    fieldaddress= interp2app(W_StructureInstance.descr_fieldaddress),
)
W_StructureInstance.typedef.acceptable_as_base_class = False

class W_StructureInstanceAutoFree(W_StructureInstance):
    def __init__(self, space, shape):
        W_StructureInstance.__init__(self, space, shape, 0)

    @rgc.must_be_light_finalizer
    def __del__(self):
        if self.ll_buffer:
            self._free()

W_StructureInstanceAutoFree.typedef = TypeDef(
    'StructureInstanceAutoFree', None, None, "read-write",
    __repr__    = interp2app(W_StructureInstance.descr_repr),
    __getattr__ = interp2app(W_StructureInstance.getattr),
    __setattr__ = interp2app(W_StructureInstance.setattr),
    buffer      = GetSetProperty(W_StructureInstance.getbuffer),
    shape       = interp_attrproperty_w('shape', W_StructureInstance),
    byptr       = interp2app(W_StructureInstance.byptr),
    fieldaddress= interp2app(W_StructureInstance.descr_fieldaddress),
)
W_StructureInstanceAutoFree.typedef.acceptable_as_base_class = False
