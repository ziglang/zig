"""
Struct and unions.
"""

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.typedef import TypeDef, interp_attrproperty, interp_attrproperty_w

from rpython.rlib import jit
from rpython.rlib.rarithmetic import r_uint, r_ulonglong, r_longlong, intmask
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rtyper.lltypesystem import lltype, rffi

from pypy.module._cffi_backend import cdataobj, ctypeprim, misc
from pypy.module._cffi_backend.ctypeobj import W_CType


class W_CTypeStructOrUnion(W_CType):
    _immutable_fields_ = ['alignment?', '_fields_list?[*]', '_fields_dict?',
                          '_custom_field_pos?', '_with_var_array?']
    is_indirect_arg_for_call_python = True

    # three possible states:
    # - "opaque": for opaque C structs; self.size < 0.
    # - "lazy": for non-opaque C structs whose _fields_list, _fields_dict,
    #       _custom_field_pos and _with_var_array are not filled yet; can be
    #       filled by calling force_lazy_struct().
    #       (But self.size and .alignment are already set and won't change.)
    # - "forced": for non-opaque C structs which are fully ready.

    # fields added by complete_struct_or_union():
    alignment = -1
    _fields_list = None
    _fields_dict = None
    _custom_field_pos = False
    _with_var_array = False
    _with_packed_changed = False

    def __init__(self, space, name):
        W_CType.__init__(self, space, -1, name, len(name))

    def check_complete(self, w_errorcls=None):
        # Check ONLY that are are not opaque.  Complain if we are.
        if self.size < 0:
            space = self.space
            raise oefmt(w_errorcls or space.w_TypeError,
                        "'%s' is opaque or not completed yet", self.name)

    def force_lazy_struct(self):
        # Force a "lazy" struct to become "forced"; complain if we are "opaque".
        if self._fields_list is None:
            self.check_complete()
            #
            from pypy.module._cffi_backend import realize_c_type
            realize_c_type.do_realize_lazy_struct(self)

    def _alignof(self):
        self.check_complete(w_errorcls=self.space.w_ValueError)
        if self.alignment == -1:
            self.force_lazy_struct()
            assert self.alignment > 0
        return self.alignment

    def _fget(self, attrchar):
        if attrchar == 'f':     # fields
            space = self.space
            if self.size < 0:
                return space.w_None
            self.force_lazy_struct()
            result = [None] * len(self._fields_list)
            for fname, field in self._fields_dict.iteritems():
                i = self._fields_list.index(field)
                result[i] = space.newtuple([space.newtext(fname),
                                            field])
            return space.newlist(result)
        return W_CType._fget(self, attrchar)

    def convert_to_object(self, cdata):
        space = self.space
        self.check_complete()
        return cdataobj.W_CData(space, cdata, self)

    def copy_and_convert_to_object(self, source):
        space = self.space
        self.check_complete()
        ptr = lltype.malloc(rffi.CCHARP.TO, self.size, flavor='raw', zero=False)
        misc._raw_memcopy(source, ptr, self.size)
        return cdataobj.W_CDataNewStd(space, ptr, self)

    def typeoffsetof_field(self, fieldname, following):
        self.force_lazy_struct()
        space = self.space
        try:
            cfield = self._getcfield_const(fieldname)
        except KeyError:
            raise OperationError(space.w_KeyError, space.newtext(fieldname))
        if cfield.bitshift >= 0:
            raise oefmt(space.w_TypeError, "not supported for bitfields")
        return (cfield.ctype, cfield.offset)

    def _copy_from_same(self, cdata, w_ob):
        if isinstance(w_ob, cdataobj.W_CData):
            if w_ob.ctype is self and self.size >= 0:
                with w_ob as ptr:
                    misc._raw_memcopy(ptr, cdata, self.size)
                return True
        return False

    def convert_from_object(self, cdata, w_ob):
        if not self._copy_from_same(cdata, w_ob):
            self.convert_struct_from_object(cdata, w_ob, optvarsize=-1)

    @jit.look_inside_iff(
        lambda self, cdata, w_ob, optvarsize: jit.isvirtual(w_ob)
    )
    def convert_struct_from_object(self, cdata, w_ob, optvarsize):
        self.force_lazy_struct()

        space = self.space
        if (space.isinstance_w(w_ob, space.w_list) or
            space.isinstance_w(w_ob, space.w_tuple)):
            lst_w = space.listview(w_ob)
            j = 0
            for w_obj in lst_w:
                try:
                    while (self._fields_list[j].flags &
                               W_CField.BF_IGNORE_IN_CTOR):
                        j += 1
                except IndexError:
                    raise oefmt(space.w_ValueError,
                                "too many initializers for '%s' (got %d)",
                                self.name, len(lst_w))
                optvarsize = self._fields_list[j].write_v(cdata, w_obj,
                                                          optvarsize)
                j += 1
            return optvarsize

        elif space.isinstance_w(w_ob, space.w_dict):
            lst_w = space.fixedview(w_ob)
            for i in range(len(lst_w)):
                w_key = lst_w[i]
                key = space.text_w(w_key)
                try:
                    cf = self._fields_dict[key]
                except KeyError:
                    space.raise_key_error(w_key)
                    assert 0
                optvarsize = cf.write_v(cdata, space.getitem(w_ob, w_key),
                                        optvarsize)
            return optvarsize

        else:
            if optvarsize == -1:
                msg = "list or tuple or dict or struct-cdata"
            else:
                msg = "list or tuple or dict"
            raise self._convert_error(msg, w_ob)

    @jit.elidable
    def _getcfield_const(self, attr):
        return self._fields_dict[attr]

    def getcfield(self, attr):
        # Returns a W_CField.  Error cases: returns None if we are an
        # opaque struct; or raises KeyError if the particular field
        # 'attr' does not exist.  The point of not directly building the
        # error here is to get the exact ctype in the error message: it
        # might be of the kind 'struct foo' or 'struct foo *'.
        if self._fields_dict is None:
            if self.size < 0:
                return None
            self.force_lazy_struct()
        self = jit.promote(self)
        attr = jit.promote_string(attr)
        return self._getcfield_const(attr)    # <= KeyError here

    def cdata_dir(self):
        if self.size < 0:
            return []
        self.force_lazy_struct()
        return self._fields_dict.keys()


class W_CTypeStruct(W_CTypeStructOrUnion):
    kind = "struct"


class W_CTypeUnion(W_CTypeStructOrUnion):
    kind = "union"


class W_CField(W_Root):
    _immutable_ = True

    BS_REGULAR     = -1
    BS_EMPTY_ARRAY = -2

    BF_IGNORE_IN_CTOR = 0x01

    def __init__(self, ctype, offset, bitshift, bitsize, flags):
        self.ctype = ctype
        self.offset = offset
        self.bitshift = bitshift # >= 0: bitshift; or BS_REGULAR/BS_EMPTY_ARRAY
        self.bitsize = bitsize
        self.flags = flags       # BF_xxx

    def is_bitfield(self):
        return self.bitshift >= 0

    def make_shifted(self, offset, fflags):
        return W_CField(self.ctype, offset + self.offset,
                        self.bitshift, self.bitsize, self.flags | fflags)

    def read(self, cdata, w_cdata):
        cdata = rffi.ptradd(cdata, self.offset)
        if self.bitshift == self.BS_REGULAR:
            return self.ctype.convert_to_object(cdata)
        elif self.bitshift == self.BS_EMPTY_ARRAY:
            from pypy.module._cffi_backend import ctypearray
            ctype = self.ctype
            assert isinstance(ctype, ctypearray.W_CTypeArray)
            structobj = w_cdata.get_structobj()
            if structobj is not None:
                # variable-length array
                size = structobj.allocated_length - self.offset
                if size >= 0:
                    arraylen = size // ctype.ctitem.size
                    return cdataobj.W_CDataSliced(ctype.space, cdata, ctype,
                                                  arraylen)
            return cdataobj.W_CData(ctype.space, cdata, ctype.ctptr)
        else:
            return self.convert_bitfield_to_object(cdata)

    def write(self, cdata, w_ob):
        cdata = rffi.ptradd(cdata, self.offset)
        if self.is_bitfield():
            self.convert_bitfield_from_object(cdata, w_ob)
        else:
            self.ctype.convert_from_object(cdata, w_ob)

    def add_varsize_length(self, space, itemsize, varsizelength, optvarsize):
        # returns an updated 'optvarsize' to account for an array of
        # 'varsizelength' elements, each of size 'itemsize', that starts
        # at 'self.offset'.
        try:
            varsize = ovfcheck(itemsize * varsizelength)
            size = ovfcheck(self.offset + varsize)
        except OverflowError:
            raise oefmt(space.w_OverflowError,
                        "array size would overflow a ssize_t")
        assert size >= 0
        return max(size, optvarsize)

    def write_v(self, cdata, w_ob, optvarsize):
        # a special case for var-sized C99 arrays
        from pypy.module._cffi_backend import ctypearray
        ct = self.ctype
        space = ct.space
        if isinstance(ct, ctypearray.W_CTypeArray) and ct.length < 0:
            w_ob, varsizelength = ct.get_new_array_length(w_ob)
            if optvarsize != -1:
                # in this mode, the only purpose of this function is to compute
                # the real size of the structure from a var-sized C99 array
                assert cdata == lltype.nullptr(rffi.CCHARP.TO)
                return self.add_varsize_length(space, ct.ctitem.size,
                    varsizelength, optvarsize)
            # if 'value' was only an integer, get_new_array_length() returns
            # w_ob = space.w_None.  Detect if this was the case,
            # and if so, stop here, leaving the content uninitialized
            # (it should be zero-initialized from somewhere else).
            if space.is_w(w_ob, space.w_None):
                return optvarsize
        #
        if optvarsize == -1:
            self.write(cdata, w_ob)
        elif (isinstance(ct, W_CTypeStructOrUnion) and ct._with_var_array and
              not isinstance(w_ob, cdataobj.W_CData)):
            subsize = ct.size
            subsize = ct.convert_struct_from_object(
                lltype.nullptr(rffi.CCHARP.TO), w_ob, subsize)
            optvarsize = self.add_varsize_length(space, 1, subsize, optvarsize)
        return optvarsize

    def convert_bitfield_to_object(self, cdata):
        ctype = self.ctype
        space = ctype.space
        #
        if isinstance(ctype, ctypeprim.W_CTypePrimitiveSigned):
            if ctype.value_fits_long:
                value = r_uint(misc.read_raw_long_data(cdata, ctype.size))
                valuemask = (r_uint(1) << self.bitsize) - 1
                shiftforsign = r_uint(1) << (self.bitsize - 1)
                value = ((value >> self.bitshift) + shiftforsign) & valuemask
                result = intmask(value) - intmask(shiftforsign)
                return space.newint(result)
            else:
                value = misc.read_raw_unsigned_data(cdata, ctype.size)
                valuemask = (r_ulonglong(1) << self.bitsize) - 1
                shiftforsign = r_ulonglong(1) << (self.bitsize - 1)
                value = ((value >> self.bitshift) + shiftforsign) & valuemask
                result = r_longlong(value) - r_longlong(shiftforsign)
                return space.newint(result)
        #
        if isinstance(ctype, ctypeprim.W_CTypePrimitiveUnsigned):
            value_fits_long = ctype.value_fits_long
            value_fits_ulong = ctype.value_fits_ulong
        elif isinstance(ctype, ctypeprim.W_CTypePrimitiveCharOrUniChar):
            value_fits_long = True
            value_fits_ulong = True
        else:
            raise NotImplementedError
        #
        if value_fits_ulong:
            value = misc.read_raw_ulong_data(cdata, ctype.size)
            valuemask = (r_uint(1) << self.bitsize) - 1
            value = (value >> self.bitshift) & valuemask
            if value_fits_long:
                return space.newint(intmask(value))
            else:
                return space.newint(value)    # uint => wrapped long object
        else:
            value = misc.read_raw_unsigned_data(cdata, ctype.size)
            valuemask = (r_ulonglong(1) << self.bitsize) - 1
            value = (value >> self.bitshift) & valuemask
            return space.newint(value)      # ulonglong => wrapped long object

    def convert_bitfield_from_object(self, cdata, w_ob):
        ctype = self.ctype
        space = ctype.space
        #
        value = misc.as_long_long(space, w_ob)
        if isinstance(ctype, ctypeprim.W_CTypePrimitiveSigned):
            is_signed = True
            fmin = -(r_longlong(1) << (self.bitsize - 1))
            fmax = (r_longlong(1) << (self.bitsize - 1)) - 1
            if fmax == 0:
                fmax = 1      # special case to let "int x:1" receive "1"
        else:
            is_signed = False
            fmin = r_longlong(0)
            fmax = r_longlong((r_ulonglong(1) << self.bitsize) - 1)
        if value < fmin or value > fmax:
            raise oefmt(space.w_OverflowError,
                        "value %d outside the range allowed by the bit field "
                        "width: %d <= x <= %d", value, fmin, fmax)
        rawmask = ((r_ulonglong(1) << self.bitsize) - 1) << self.bitshift
        rawvalue = r_ulonglong(value) << self.bitshift
        rawfielddata = misc.read_raw_unsigned_data(cdata, ctype.size)
        rawfielddata = (rawfielddata & ~rawmask) | (rawvalue & rawmask)
        if is_signed:
            misc.write_raw_signed_data(cdata, rawfielddata, ctype.size)
        else:
            misc.write_raw_unsigned_data(cdata, rawfielddata, ctype.size)


W_CField.typedef = TypeDef(
    '_cffi_backend.CField',
    type = interp_attrproperty_w('ctype', W_CField),
    offset = interp_attrproperty('offset', W_CField, wrapfn="newint"),
    bitshift = interp_attrproperty('bitshift', W_CField, wrapfn="newint"),
    bitsize = interp_attrproperty('bitsize', W_CField, wrapfn="newint"),
    flags = interp_attrproperty('flags', W_CField, wrapfn="newint"),
    )
W_CField.typedef.acceptable_as_base_class = False
