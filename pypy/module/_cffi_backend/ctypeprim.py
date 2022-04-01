"""
Primitives.
"""

import sys

from rpython.rlib.rarithmetic import r_uint, r_ulonglong, intmask
from rpython.rlib import jit, rutf8
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rfficache

from pypy.interpreter.error import oefmt
from pypy.module._cffi_backend import cdataobj, misc, wchar_helper
from pypy.module._cffi_backend.ctypeobj import W_CType


class W_CTypePrimitive(W_CType):
    _attrs_            = ['align']
    _immutable_fields_ = ['align']
    kind = "primitive"

    def __init__(self, space, size, name, name_position, align):
        W_CType.__init__(self, space, size, name, name_position)
        self.align = align

    def extra_repr(self, cdata):
        w_ob = self.convert_to_object(cdata)
        return self.space.text_w(self.space.repr(w_ob))

    def _alignof(self):
        return self.align

    def cast_str(self, w_ob):
        space = self.space
        s = space.bytes_w(w_ob)
        if len(s) != 1:
            raise oefmt(space.w_TypeError,
                        "cannot cast string of length %d to ctype '%s'",
                        len(s), self.name)
        return ord(s[0])

    def cast_unicode(self, w_ob):
        space = self.space
        w_u = space.convert_arg_to_w_unicode(w_ob)
        if w_u._len() != 1:
            raise oefmt(space.w_TypeError,
                        "cannot cast unicode string of length %d to ctype '%s'",
                        w_u._len(), self.name)
        return rutf8.codepoint_at_pos(w_u._utf8, 0)

    def cast(self, w_ob):
        from pypy.module._cffi_backend import ctypeptr
        space = self.space
        if (isinstance(w_ob, cdataobj.W_CData) and
               isinstance(w_ob.ctype, ctypeptr.W_CTypePtrOrArray)):
            ptr = w_ob.unsafe_escaping_ptr()
            value = rffi.cast(lltype.Signed, ptr)
            value = self._cast_result(value)
        elif space.isinstance_w(w_ob, space.w_bytes):
            value = self.cast_str(w_ob)
            value = self._cast_result(value)
        elif space.isinstance_w(w_ob, space.w_unicode):
            value = self.cast_unicode(w_ob)
            value = self._cast_result(value)
        else:
            value = self._cast_generic(w_ob)
        w_cdata = cdataobj.W_CDataMem(space, self)
        self.write_raw_integer_data(w_cdata, value)
        return w_cdata

    def _cast_result(self, intvalue):
        return r_ulonglong(intvalue)

    def _cast_generic(self, w_ob):
        return misc.as_unsigned_long_long(self.space, w_ob, strict=False)

    def _overflow(self, w_ob):
        space = self.space
        s = space.text_w(space.str(w_ob))
        raise oefmt(space.w_OverflowError,
                    "integer %s does not fit '%s'", s, self.name)

    def string(self, cdataobj, maxlen):
        if self.size == 1:
            with cdataobj as ptr:
                s = ptr[0]
            return self.space.newbytes(s)
        return W_CType.string(self, cdataobj, maxlen)

    def unpack_ptr(self, w_ctypeptr, ptr, length):
        result = self.unpack_list_of_int_items(ptr, length)
        if result is not None:
            return self.space.newlist_int(result)
        return W_CType.unpack_ptr(self, w_ctypeptr, ptr, length)

    def nonzero(self, cdata):
        if self.size <= rffi.sizeof(lltype.Signed):
            value = misc.read_raw_long_data(cdata, self.size)
            return value != 0
        else:
            return self._nonzero_longlong(cdata)

    def _nonzero_longlong(self, cdata):
        # in its own function: LONGLONG may make the whole function jit-opaque
        value = misc.read_raw_signed_data(cdata, self.size)
        return bool(value)


class W_CTypePrimitiveCharOrUniChar(W_CTypePrimitive):
    _attrs_ = []
    is_primitive_integer = True

    def get_vararg_type(self):
        from pypy.module._cffi_backend import newtype
        return newtype.new_primitive_type(self.space, "int")

    def write_raw_integer_data(self, w_cdata, value):
        w_cdata.write_raw_unsigned_data(value)


class W_CTypePrimitiveChar(W_CTypePrimitiveCharOrUniChar):
    _attrs_ = []

    def cast_to_int(self, cdata):
        return self.space.newint(ord(cdata[0]))

    def convert_to_object(self, cdata):
        return self.space.newbytes(cdata[0])

    def _convert_to_char(self, w_ob):
        space = self.space
        if space.isinstance_w(w_ob, space.w_bytes):
            s = space.bytes_w(w_ob)
            if len(s) == 1:
                return s[0]
        if (isinstance(w_ob, cdataobj.W_CData) and
               isinstance(w_ob.ctype, W_CTypePrimitiveChar)):
            with w_ob as ptr:
                return ptr[0]
        raise self._convert_error("string of length 1", w_ob)

    def convert_from_object(self, cdata, w_ob):
        value = self._convert_to_char(w_ob)
        cdata[0] = value

    def unpack_ptr(self, w_ctypeptr, ptr, length):
        s = rffi.charpsize2str(ptr, length)
        return self.space.newbytes(s)


class W_CTypePrimitiveUniChar(W_CTypePrimitiveCharOrUniChar):
    _attrs_            = ['is_signed_wchar']
    _immutable_fields_ = ['is_signed_wchar']

    _wchar_is_signed = rfficache.signof_c_type('wchar_t')

    def __init__(self, space, size, name, name_position, align):
        W_CTypePrimitiveCharOrUniChar.__init__(self, space, size, name,
                                               name_position, align)
        self.is_signed_wchar = self._wchar_is_signed and (name == "wchar_t")
        # "char16_t" and "char32_t" are always unsigned

    def cast_to_int(self, cdata):
        if self.is_signed_wchar:
            value = misc.read_raw_long_data(cdata, self.size)
            return self.space.newint(value)
        else:
            value = misc.read_raw_ulong_data(cdata, self.size)
            if self.size < rffi.sizeof(lltype.Signed):
                return self.space.newint(intmask(value))
            else:
                return self.space.newint(value)    # r_uint => 'long' object

    def convert_to_object(self, cdata):
        value = misc.read_raw_ulong_data(cdata, self.size)   # r_uint
        try:
            utf8 = rutf8.unichr_as_utf8(value, allow_surrogates=True)
        except rutf8.OutOfRange:
            if self.is_signed_wchar:
                s = hex(intmask(value))
            else:
                s = hex(value)
            raise oefmt(self.space.w_ValueError,
                        "%s out of range for conversion to unicode: %s",
                        self.name, s)
        return self.space.newutf8(utf8, 1)

    def string(self, cdataobj, maxlen):
        with cdataobj as ptr:
            w_res = self.convert_to_object(ptr)
        return w_res

    def _convert_to_charN_t(self, w_ob):
        # returns a r_uint.  If self.size == 2, it is smaller than 0x10000
        space = self.space
        if space.isinstance_w(w_ob, space.w_unicode):
            w_u = space.convert_arg_to_w_unicode(w_ob)
            if w_u._len() != 1:
                raise self._convert_error("single character", w_ob)
            ordinal = rutf8.codepoint_at_pos(w_u._utf8, 0)
            if self.size == 2 and ordinal > 0xFFFF:
                raise self._convert_error("single character <= 0xFFFF", w_ob)
            return r_uint(ordinal)
        elif (isinstance(w_ob, cdataobj.W_CData) and
               isinstance(w_ob.ctype, W_CTypePrimitiveUniChar) and
               w_ob.ctype.size == self.size):
            with w_ob as ptr:
                return misc.read_raw_ulong_data(ptr, self.size)
        raise self._convert_error("unicode string of length 1", w_ob)

    def convert_from_object(self, cdata, w_ob):
        ordinal = self._convert_to_charN_t(w_ob)
        misc.write_raw_unsigned_data(cdata, ordinal, self.size)

    def unpack_ptr(self, w_ctypeptr, ptr, length):
        if self.size == 2:
            utf8, lgt = wchar_helper.utf8_from_char16(ptr, length)
        else:
            try:
                utf8, lgt = wchar_helper.utf8_from_char32(ptr, length)
            except wchar_helper.OutOfRange as e:
                raise oefmt(self.space.w_ValueError,
                            "%s out of range for conversion to unicode: %s",
                            self.name, hex(e.ordinal))
        assert lgt >= 0
        return self.space.newutf8(utf8, lgt)


class W_CTypePrimitiveSigned(W_CTypePrimitive):
    _attrs_            = ['value_fits_long', 'value_smaller_than_long']
    _immutable_fields_ = ['value_fits_long', 'value_smaller_than_long']
    is_primitive_integer = True

    def __init__(self, *args):
        W_CTypePrimitive.__init__(self, *args)
        self.value_fits_long = self.size <= rffi.sizeof(lltype.Signed)
        self.value_smaller_than_long = self.size < rffi.sizeof(lltype.Signed)

    def cast_to_int(self, cdata):
        return self.convert_to_object(cdata)

    def convert_to_object(self, cdata):
        if self.value_fits_long:
            value = misc.read_raw_long_data(cdata, self.size)
            return self.space.newint(value)
        else:
            return self._convert_to_object_longlong(cdata)

    def _convert_to_object_longlong(self, cdata):
        # in its own function: LONGLONG may make the whole function jit-opaque
        value = misc.read_raw_signed_data(cdata, self.size)
        return self.space.newint(value)    # r_longlong => on 32-bit, 'long'

    def convert_from_object(self, cdata, w_ob):
        if self.value_fits_long:
            value = misc.as_long(self.space, w_ob)
            if self.value_smaller_than_long:
                if value != misc.signext(value, self.size):
                    self._overflow(w_ob)
            misc.write_raw_signed_data(cdata, value, self.size)
        else:
            self._convert_from_object_longlong(cdata, w_ob)

    def _convert_from_object_longlong(self, cdata, w_ob):
        # in its own function: LONGLONG may make the whole function jit-opaque
        value = misc.as_long_long(self.space, w_ob)
        misc.write_raw_signed_data(cdata, value, self.size)

    def get_vararg_type(self):
        if self.size < rffi.sizeof(rffi.INT):
            from pypy.module._cffi_backend import newtype
            return newtype.new_primitive_type(self.space, "int")
        return self

    def write_raw_integer_data(self, w_cdata, value):
        w_cdata.write_raw_signed_data(value)

    def unpack_list_of_int_items(self, ptr, length):
        if self.size == rffi.sizeof(rffi.SIGNED):
            from rpython.rlib.rrawarray import populate_list_from_raw_array
            res = []
            buf = rffi.cast(rffi.SIGNEDP, ptr)
            populate_list_from_raw_array(res, buf, length)
            return res
        elif self.value_smaller_than_long:
            res = [0] * length
            misc.unpack_list_from_raw_array(res, ptr, self.size)
            return res
        return None

    def pack_list_of_items(self, cdata, w_ob, expected_length):
        int_list = self.space.listview_int(w_ob)
        if (int_list is not None and
                self._within_bounds(len(int_list), expected_length)):
            if self.size == rffi.sizeof(rffi.SIGNED): # fastest path
                from rpython.rlib.rrawarray import copy_list_to_raw_array
                cdata = rffi.cast(rffi.SIGNEDP, cdata)
                copy_list_to_raw_array(int_list, cdata)
            else:
                overflowed = misc.pack_list_to_raw_array_bounds_signed(
                    int_list, cdata, self.size)
                if overflowed != 0:
                    self._overflow(self.space.newint(overflowed))
            return True
        return W_CTypePrimitive.pack_list_of_items(self, cdata, w_ob,
                                                   expected_length)


class W_CTypePrimitiveUnsigned(W_CTypePrimitive):
    _attrs_            = ['value_fits_long', 'value_fits_ulong', 'vrangemax']
    _immutable_fields_ = ['value_fits_long', 'value_fits_ulong', 'vrangemax']
    is_primitive_integer = True

    def __init__(self, *args):
        W_CTypePrimitive.__init__(self, *args)
        self.value_fits_long = self.size < rffi.sizeof(lltype.Signed)
        self.value_fits_ulong = self.size <= rffi.sizeof(lltype.Unsigned)
        if self.value_fits_long:
            self.vrangemax = self._compute_vrange_max()
        else:
            self.vrangemax = r_uint(sys.maxint)

    def _compute_vrange_max(self):
        sh = self.size * 8
        return (r_uint(1) << sh) - 1

    def cast_to_int(self, cdata):
        return self.convert_to_object(cdata)

    def convert_from_object(self, cdata, w_ob):
        if self.value_fits_ulong:
            value = misc.as_unsigned_long(self.space, w_ob, strict=True)
            if self.value_fits_long:
                if value > self.vrangemax:
                    self._overflow(w_ob)
            misc.write_raw_unsigned_data(cdata, value, self.size)
        else:
            self._convert_from_object_longlong(cdata, w_ob)

    def _convert_from_object_longlong(self, cdata, w_ob):
        # in its own function: LONGLONG may make the whole function jit-opaque
        value = misc.as_unsigned_long_long(self.space, w_ob, strict=True)
        misc.write_raw_unsigned_data(cdata, value, self.size)

    def convert_to_object(self, cdata):
        if self.value_fits_ulong:
            value = misc.read_raw_ulong_data(cdata, self.size)
            if self.value_fits_long:
                return self.space.newint(intmask(value))
            else:
                return self.space.newint(value)    # r_uint => 'long' object
        else:
            return self._convert_to_object_longlong(cdata)

    def _convert_to_object_longlong(self, cdata):
        # in its own function: LONGLONG may make the whole function jit-opaque
        value = misc.read_raw_unsigned_data(cdata, self.size)
        return self.space.newint(value)    # r_ulonglong => 'long' object

    def get_vararg_type(self):
        if self.size < rffi.sizeof(rffi.INT):
            from pypy.module._cffi_backend import newtype
            return newtype.new_primitive_type(self.space, "int")
        return self

    def write_raw_integer_data(self, w_cdata, value):
        w_cdata.write_raw_unsigned_data(value)

    def unpack_list_of_int_items(self, ptr, length):
        if self.value_fits_long:
            res = [0] * length
            misc.unpack_unsigned_list_from_raw_array(res, ptr, self.size)
            return res
        return None

    def pack_list_of_items(self, cdata, w_ob, expected_length):
        int_list = self.space.listview_int(w_ob)
        if (int_list is not None and
                self._within_bounds(len(int_list), expected_length)):
            overflowed = misc.pack_list_to_raw_array_bounds_unsigned(
                int_list, cdata, self.size, self.vrangemax)
            if overflowed != 0:
                self._overflow(self.space.newint(overflowed))
            return True
        return W_CTypePrimitive.pack_list_of_items(self, cdata, w_ob,
                                                   expected_length)


class W_CTypePrimitiveBool(W_CTypePrimitiveUnsigned):
    _attrs_ = []

    def _compute_vrange_max(self):
        return r_uint(1)

    def _cast_result(self, intvalue):
        return r_ulonglong(intvalue != 0)

    def _cast_generic(self, w_ob):
        return misc.object_as_bool(self.space, w_ob)

    def string(self, cdataobj, maxlen):
        # bypass the method 'string' implemented in W_CTypePrimitive
        return W_CType.string(self, cdataobj, maxlen)

    def _read_bool_0_or_1(self, cdata):
        """Read one byte, check it is 0 or 1, but return it as an integer"""
        value = ord(cdata[0])
        if value >= 2:
            raise oefmt(self.space.w_ValueError,
                        "got a _Bool of value %d, expected 0 or 1",
                        value)
        return value

    def convert_to_object(self, cdata):
        value = self._read_bool_0_or_1(cdata)
        return self.space.newbool(value != 0)

    def cast_to_int(self, cdata):
        value = self._read_bool_0_or_1(cdata)
        return self.space.newint(value)

    def unpack_list_of_int_items(self, ptr, length):
        return None


class W_CTypePrimitiveFloat(W_CTypePrimitive):
    _attrs_ = []

    def cast(self, w_ob):
        space = self.space
        if isinstance(w_ob, cdataobj.W_CData):
            if not isinstance(w_ob.ctype, W_CTypePrimitive):
                raise oefmt(space.w_TypeError,
                            "cannot cast ctype '%s' to ctype '%s'",
                            w_ob.ctype.name, self.name)
            w_ob = w_ob.convert_to_object()
        #
        if space.isinstance_w(w_ob, space.w_bytes):
            value = self.cast_str(w_ob)
        elif space.isinstance_w(w_ob, space.w_unicode):
            value = self.cast_unicode(w_ob)
        else:
            value = space.float_w(w_ob)
        w_cdata = cdataobj.W_CDataMem(space, self)
        if not isinstance(self, W_CTypePrimitiveLongDouble):
            w_cdata.write_raw_float_data(value)
        else:
            with w_cdata as ptr:
                self._to_longdouble_and_write(value, ptr)
        return w_cdata

    def cast_to_int(self, cdata):
        w_value = self.float(cdata)
        return self.space.int(w_value)

    def float(self, cdata):
        return self.convert_to_object(cdata)

    def convert_to_object(self, cdata):
        value = misc.read_raw_float_data(cdata, self.size)
        return self.space.newfloat(value)

    def convert_from_object(self, cdata, w_ob):
        space = self.space
        value = space.float_w(space.float(w_ob))
        misc.write_raw_float_data(cdata, value, self.size)

    def unpack_list_of_float_items(self, ptr, length):
        if self.size == rffi.sizeof(rffi.DOUBLE):
            from rpython.rlib.rrawarray import populate_list_from_raw_array
            res = []
            buf = rffi.cast(rffi.DOUBLEP, ptr)
            populate_list_from_raw_array(res, buf, length)
            return res
        elif self.size == rffi.sizeof(rffi.FLOAT):
            res = [0.0] * length
            misc.unpack_cfloat_list_from_raw_array(res, ptr)
            return res
        return None

    def pack_list_of_items(self, cdata, w_ob, expected_length):
        float_list = self.space.listview_float(w_ob)
        if (float_list is not None and
                self._within_bounds(len(float_list), expected_length)):
            if self.size == rffi.sizeof(rffi.DOUBLE):   # fastest path
                from rpython.rlib.rrawarray import copy_list_to_raw_array
                cdata = rffi.cast(rffi.DOUBLEP, cdata)
                copy_list_to_raw_array(float_list, cdata)
                return True
            elif self.size == rffi.sizeof(rffi.FLOAT):
                misc.pack_float_list_to_raw_array(float_list, cdata,
                                                  rffi.FLOAT, rffi.FLOATP)
                return True
        return W_CTypePrimitive.pack_list_of_items(self, cdata, w_ob,
                                                   expected_length)

    def unpack_ptr(self, w_ctypeptr, ptr, length):
        result = self.unpack_list_of_float_items(ptr, length)
        if result is not None:
            return self.space.newlist_float(result)
        return W_CType.unpack_ptr(self, w_ctypeptr, ptr, length)

    def nonzero(self, cdata):
        return misc.is_nonnull_float(cdata, self.size)


class W_CTypePrimitiveLongDouble(W_CTypePrimitiveFloat):
    _attrs_ = []
    is_indirect_arg_for_call_python = True

    @jit.dont_look_inside
    def extra_repr(self, cdata):
        lvalue = misc.read_raw_longdouble_data(cdata)
        return misc.longdouble2str(lvalue)

    def cast(self, w_ob):
        if (isinstance(w_ob, cdataobj.W_CData) and
                isinstance(w_ob.ctype, W_CTypePrimitiveLongDouble)):
            with w_ob as ptr:
                w_cdata = self.convert_to_object(ptr)
            return w_cdata
        else:
            return W_CTypePrimitiveFloat.cast(self, w_ob)

    @jit.dont_look_inside
    def _to_longdouble_and_write(self, value, cdata):
        lvalue = rffi.cast(rffi.LONGDOUBLE, value)
        misc.write_raw_longdouble_data(cdata, lvalue)

    @jit.dont_look_inside
    def _read_from_longdouble(self, cdata):
        lvalue = misc.read_raw_longdouble_data(cdata)
        value = rffi.cast(lltype.Float, lvalue)
        return value

    @jit.dont_look_inside
    def _copy_longdouble(self, cdatasrc, cdatadst):
        lvalue = misc.read_raw_longdouble_data(cdatasrc)
        misc.write_raw_longdouble_data(cdatadst, lvalue)

    def float(self, cdata):
        value = self._read_from_longdouble(cdata)
        return self.space.newfloat(value)

    def convert_to_object(self, cdata):
        w_cdata = cdataobj.W_CDataMem(self.space, self)
        with w_cdata as ptr:
            self._copy_longdouble(cdata, ptr)
        return w_cdata

    def convert_from_object(self, cdata, w_ob):
        space = self.space
        if (isinstance(w_ob, cdataobj.W_CData) and
                isinstance(w_ob.ctype, W_CTypePrimitiveLongDouble)):
            with w_ob as ptr:
                self._copy_longdouble(ptr, cdata)
        else:
            value = space.float_w(space.float(w_ob))
            self._to_longdouble_and_write(value, cdata)

    # Cannot have unpack_list_of_float_items() here:
    # 'list(array-of-longdouble)' returns a list of cdata objects,
    # not a list of floats.

    def pack_list_of_items(self, cdata, w_ob, expected_length):
        float_list = self.space.listview_float(w_ob)
        if (float_list is not None and
                self._within_bounds(len(float_list), expected_length)):
            misc.pack_float_list_to_raw_array(float_list, cdata,
                                             rffi.LONGDOUBLE, rffi.LONGDOUBLEP)
            return True
        return W_CTypePrimitive.pack_list_of_items(self, cdata, w_ob,
                                                   expected_length)

    @jit.dont_look_inside
    def nonzero(self, cdata):
        return misc.is_nonnull_longdouble(cdata)


class W_CTypePrimitiveComplex(W_CTypePrimitive):
    _attrs_ = []

    def cast(self, w_ob):
        space = self.space
        if isinstance(w_ob, cdataobj.W_CData):
            if not isinstance(w_ob.ctype, W_CTypePrimitive):
                raise oefmt(space.w_TypeError,
                            "cannot cast ctype '%s' to ctype '%s'",
                            w_ob.ctype.name, self.name)
            w_ob = w_ob.convert_to_object()
        #
        imag = 0.0
        if space.isinstance_w(w_ob, space.w_bytes):
            real = self.cast_str(w_ob)
        elif space.isinstance_w(w_ob, space.w_unicode):
            real = self.cast_unicode(w_ob)
        else:
            real, imag = space.unpackcomplex(w_ob)
        w_cdata = cdataobj.W_CDataMem(space, self)
        w_cdata.write_raw_complex_data(real, imag)
        return w_cdata

    def complex(self, cdata):
        return self.convert_to_object(cdata)

    def convert_to_object(self, cdata):
        halfsize = self.size >> 1
        cdata2 = rffi.ptradd(cdata, halfsize)
        real = misc.read_raw_float_data(cdata, halfsize)
        imag = misc.read_raw_float_data(cdata2, halfsize)
        return self.space.newcomplex(real, imag)

    def convert_from_object(self, cdata, w_ob):
        space = self.space
        real, imag = space.unpackcomplex(w_ob)
        halfsize = self.size >> 1
        cdata2 = rffi.ptradd(cdata, halfsize)
        misc.write_raw_float_data(cdata,  real, halfsize)
        misc.write_raw_float_data(cdata2, imag, halfsize)

    def nonzero(self, cdata):
        halfsize = self.size >> 1
        cdata2 = rffi.ptradd(cdata, halfsize)
        return (misc.is_nonnull_float(cdata, halfsize) |
                misc.is_nonnull_float(cdata2, halfsize))
