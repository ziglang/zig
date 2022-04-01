from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import clibffi
from rpython.rlib import libffi
from rpython.rlib import jit
from rpython.rlib.rgc import must_be_light_finalizer
from rpython.rlib.rarithmetic import r_uint, r_ulonglong, intmask
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, interp_attrproperty, interp_attrproperty_w
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.error import OperationError, oefmt
from pypy.module._rawffi.alt.interp_ffitype import W_FFIType
from pypy.module._rawffi.alt.type_converter import FromAppLevelConverter, ToAppLevelConverter


class W_Field(W_Root):
    def __init__(self, name, w_ffitype):
        self.name = name
        self.w_ffitype = w_ffitype
        self.offset = -1

    def __repr__(self):
        return '<Field %s %s>' % (self.name, self.w_ffitype.name)

@unwrap_spec(name='text')
def descr_new_field(space, w_type, name, w_ffitype):
    w_ffitype = space.interp_w(W_FFIType, w_ffitype)
    return W_Field(name, w_ffitype)

W_Field.typedef = TypeDef(
    'Field',
    __new__ = interp2app(descr_new_field),
    name = interp_attrproperty('name', W_Field,
        wrapfn="newtext_or_none"),
    ffitype = interp_attrproperty_w('w_ffitype', W_Field),
    offset = interp_attrproperty('offset', W_Field,
        wrapfn="newint"),
    )


# ==============================================================================

class FFIStructOwner(object):
    """
    The only job of this class is to stay outside of the reference cycle
    W__StructDescr -> W_FFIType -> W__StructDescr and free the ffistruct
    """

    def __init__(self, ffistruct):
        self.ffistruct = ffistruct

    @must_be_light_finalizer
    def __del__(self):
        if self.ffistruct:
            lltype.free(self.ffistruct, flavor='raw', track_allocation=True)


class W__StructDescr(W_Root):

    def __init__(self, name):
        self.w_ffitype = W_FFIType('struct %s' % name, clibffi.FFI_TYPE_NULL,
                                   w_structdescr=self)
        self.fields_w = None
        self.name2w_field = {}
        self._ffistruct_owner = None

    def define_fields(self, space, w_fields):
        if self.fields_w is not None:
            raise oefmt(space.w_ValueError,
                        "%s's fields has already been defined",
                        self.w_ffitype.name)
        fields_w = space.fixedview(w_fields)
        # note that the fields_w returned by compute_size_and_alignement has a
        # different annotation than the original: list(W_Root) vs list(W_Field)
        size, alignment, fields_w = compute_size_and_alignement(space, fields_w)
        self.fields_w = fields_w
        field_types = [] # clibffi's types
        for w_field in fields_w:
            field_types.append(w_field.w_ffitype.get_ffitype())
            self.name2w_field[w_field.name] = w_field
        #
        # on CPython, the FFIStructOwner might go into gc.garbage and thus the
        # __del__ never be called. Thus, we don't track the allocation of the
        # malloc done inside this function, else the leakfinder might complain
        ffistruct = clibffi.make_struct_ffitype_e(size, alignment, field_types,
                                                  track_allocation=False)
        self.w_ffitype.set_ffitype(ffistruct.ffistruct)
        self._ffistruct_owner = FFIStructOwner(ffistruct)

    def check_complete(self, space):
        if self.fields_w is None:
            raise oefmt(space.w_ValueError,
                        "%s has an incomplete type", self.w_ffitype.name)

    def allocate(self, space):
        self.check_complete(space)
        return W__StructInstance(self)

    @unwrap_spec(addr=int)
    def fromaddress(self, space, addr):
        self.check_complete(space)
        rawmem = rffi.cast(rffi.VOIDP, addr)
        return W__StructInstance(self, allocate=False, autofree=True, rawmem=rawmem)

    def get_type_and_offset_for_field(self, space, w_name):
        name = space.text_w(w_name)
        try:
            return self._get_type_and_offset_for_field(space, name)
        except KeyError:
            raise OperationError(space.w_AttributeError, w_name)

    @jit.elidable_promote('0')
    def _get_type_and_offset_for_field(self, space, name):
        w_field = self.name2w_field[name]
        return w_field.w_ffitype, w_field.offset



@unwrap_spec(name='text')
def descr_new_structdescr(space, w_type, name, w_fields=None):
    descr = W__StructDescr(name)
    if not space.is_none(w_fields):
        descr.define_fields(space, w_fields)
    return descr

def round_up(size, alignment):
    return (size + alignment - 1) & -alignment

def compute_size_and_alignement(space, fields_w):
    size = 0
    alignment = 1
    fields_w2 = []
    for w_field in fields_w:
        w_field = space.interp_w(W_Field, w_field)
        fieldsize = w_field.w_ffitype.sizeof()
        fieldalignment = w_field.w_ffitype.get_alignment()
        alignment = max(alignment, fieldalignment)
        size = round_up(size, fieldalignment)
        w_field.offset = size
        size += fieldsize
        fields_w2.append(w_field)
    #
    size = round_up(size, alignment)
    return size, alignment, fields_w2



W__StructDescr.typedef = TypeDef(
    '_StructDescr',
    __new__ = interp2app(descr_new_structdescr),
    ffitype = interp_attrproperty_w('w_ffitype', W__StructDescr),
    define_fields = interp2app(W__StructDescr.define_fields),
    allocate = interp2app(W__StructDescr.allocate),
    fromaddress = interp2app(W__StructDescr.fromaddress),
    )


# ==============================================================================

NULL = lltype.nullptr(rffi.VOIDP.TO)

class W__StructInstance(W_Root):

    _immutable_fields_ = ['structdescr', 'rawmem']

    def __init__(self, structdescr, allocate=True, autofree=True, rawmem=NULL):
        self.structdescr = structdescr
        self.autofree = autofree
        if allocate:
            assert not rawmem
            assert autofree
            size = structdescr.w_ffitype.sizeof()
            self.rawmem = lltype.malloc(rffi.VOIDP.TO, size, flavor='raw',
                                        zero=True, add_memory_pressure=True)
        else:
            self.rawmem = rawmem

    @must_be_light_finalizer
    def __del__(self):
        if self.autofree and self.rawmem:
            lltype.free(self.rawmem, flavor='raw')
            self.rawmem = lltype.nullptr(rffi.VOIDP.TO)

    def getaddr(self, space):
        addr = rffi.cast(lltype.Unsigned, self.rawmem)
        return space.newint(addr)

    def getfield(self, space, w_name):
        w_ffitype, offset = self.structdescr.get_type_and_offset_for_field(
            space, w_name)
        field_getter = GetFieldConverter(space, self.rawmem, offset)
        return field_getter.do_and_wrap(w_ffitype)

    def setfield(self, space, w_name, w_value):
        w_ffitype, offset = self.structdescr.get_type_and_offset_for_field(
            space, w_name)
        field_setter = SetFieldConverter(space, self.rawmem, offset)
        field_setter.unwrap_and_do(w_ffitype, w_value)


class GetFieldConverter(ToAppLevelConverter):
    """
    A converter used by W__StructInstance to get a field from the struct and
    wrap it to the correct app-level type.
    """

    def __init__(self, space, rawmem, offset):
        self.space = space
        self.rawmem = rawmem
        self.offset = offset

    def get_longlong(self, w_ffitype):
        return libffi.struct_getfield_longlong(libffi.types.slonglong,
                                               self.rawmem, self.offset)

    def get_ulonglong(self, w_ffitype):
        longlongval = libffi.struct_getfield_longlong(libffi.types.ulonglong,
                                                      self.rawmem, self.offset)
        return r_ulonglong(longlongval)


    def get_signed(self, w_ffitype):
        return libffi.struct_getfield_int(w_ffitype.get_ffitype(),
                                          self.rawmem, self.offset)

    def get_unsigned(self, w_ffitype):
        value = libffi.struct_getfield_int(w_ffitype.get_ffitype(),
                                           self.rawmem, self.offset)
        return r_uint(value)

    get_unsigned_which_fits_into_a_signed = get_signed
    get_pointer = get_unsigned

    def get_char(self, w_ffitype):
        intval = libffi.struct_getfield_int(w_ffitype.get_ffitype(),
                                            self.rawmem, self.offset)
        return rffi.cast(rffi.UCHAR, intval)

    def get_unichar(self, w_ffitype):
        intval = libffi.struct_getfield_int(w_ffitype.get_ffitype(),
                                            self.rawmem, self.offset)
        return rffi.cast(rffi.WCHAR_T, intval)

    def get_float(self, w_ffitype):
        return libffi.struct_getfield_float(w_ffitype.get_ffitype(),
                                            self.rawmem, self.offset)

    def get_singlefloat(self, w_ffitype):
        return libffi.struct_getfield_singlefloat(w_ffitype.get_ffitype(),
                                                  self.rawmem, self.offset)

    def get_struct(self, w_ffitype, w_structdescr):
        assert isinstance(w_structdescr, W__StructDescr)
        rawmem = rffi.cast(rffi.CCHARP, self.rawmem)
        innermem = rffi.cast(rffi.VOIDP, rffi.ptradd(rawmem, self.offset))
        # we return a reference to the inner struct, not a copy
        # autofree=False because it's still owned by the parent struct
        return W__StructInstance(w_structdescr, allocate=False, autofree=False,
                                 rawmem=innermem)

    ## def get_void(self, w_ffitype):
    ##     ...


class SetFieldConverter(FromAppLevelConverter):
    """
    A converter used by W__StructInstance to convert an app-level object to
    the corresponding low-level value and set the field of a structure.
    """

    def __init__(self, space, rawmem, offset):
        self.space = space
        self.rawmem = rawmem
        self.offset = offset

    def handle_signed(self, w_ffitype, w_obj, intval):
        libffi.struct_setfield_int(w_ffitype.get_ffitype(), self.rawmem, self.offset,
                                   intval)

    def handle_unsigned(self, w_ffitype, w_obj, uintval):
        libffi.struct_setfield_int(w_ffitype.get_ffitype(), self.rawmem, self.offset,
                                   intmask(uintval))

    handle_pointer = handle_signed
    handle_char = handle_signed
    handle_unichar = handle_signed

    def handle_longlong(self, w_ffitype, w_obj, longlongval):
        libffi.struct_setfield_longlong(w_ffitype.get_ffitype(),
                                        self.rawmem, self.offset, longlongval)

    def handle_float(self, w_ffitype, w_obj, floatval):
        libffi.struct_setfield_float(w_ffitype.get_ffitype(),
                                     self.rawmem, self.offset, floatval)

    def handle_singlefloat(self, w_ffitype, w_obj, singlefloatval):
        libffi.struct_setfield_singlefloat(w_ffitype.get_ffitype(),
                                           self.rawmem, self.offset, singlefloatval)

    def handle_struct(self, w_ffitype, w_structinstance):
        rawmem = rffi.cast(rffi.CCHARP, self.rawmem)
        dst = rffi.cast(rffi.VOIDP, rffi.ptradd(rawmem, self.offset))
        src = w_structinstance.rawmem
        length = w_ffitype.sizeof()
        rffi.c_memcpy(dst, src, length)

    ## def handle_char_p(self, w_ffitype, w_obj, strval):
    ##     ...

    ## def handle_unichar_p(self, w_ffitype, w_obj, unicodeval):
    ##     ...




W__StructInstance.typedef = TypeDef(
    '_StructInstance',
    getaddr  = interp2app(W__StructInstance.getaddr),
    getfield = interp2app(W__StructInstance.getfield),
    setfield = interp2app(W__StructInstance.setfield),
    )
