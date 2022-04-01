from rpython.rlib import libffi
from rpython.rlib import jit, rutf8
from rpython.rlib.rarithmetic import r_uint, intmask
from pypy.interpreter.error import oefmt
from pypy.module._rawffi.structure import W_StructureInstance, W_Structure
from pypy.module._rawffi.alt.interp_ffitype import app_types

class FromAppLevelConverter(object):
    """
    Unwrap an app-level object to the corresponding low-level type, following
    the conversion rules which apply to the specified w_ffitype.  Once
    unwrapped, the value is passed to the corresponding handle_* method.
    Subclasses should override the desired ones.
    """

    def __init__(self, space):
        self.space = space

    def unwrap_and_do(self, w_ffitype, w_obj):
        from pypy.module._rawffi.alt.interp_struct import W__StructInstance
        space = self.space
        if w_ffitype.is_longlong():
            # note that we must check for longlong first, because either
            # is_signed or is_unsigned returns true anyway
            assert libffi.IS_32_BIT
            self._longlong(w_ffitype, w_obj)
        elif w_ffitype.is_signed():
            intval = space.truncatedint_w(w_obj, allow_conversion=False)
            self.handle_signed(w_ffitype, w_obj, intval)
        elif self.maybe_handle_char_or_unichar_p(w_ffitype, w_obj):
            # the object was already handled from within
            # maybe_handle_char_or_unichar_p
            pass
        elif w_ffitype.is_pointer():
            w_obj = self.convert_pointer_arg_maybe(w_obj, w_ffitype)
            intval = space.truncatedint_w(w_obj, allow_conversion=False)
            self.handle_pointer(w_ffitype, w_obj, intval)
        elif w_ffitype.is_unsigned():
            uintval = r_uint(space.truncatedint_w(w_obj, allow_conversion=False))
            self.handle_unsigned(w_ffitype, w_obj, uintval)
        elif w_ffitype.is_char():
            intval = space.int_w(space.ord(w_obj), allow_conversion=False)
            self.handle_char(w_ffitype, w_obj, intval)
        elif w_ffitype.is_unichar():
            intval = space.int_w(space.ord(w_obj), allow_conversion=False)
            self.handle_unichar(w_ffitype, w_obj, intval)
        elif w_ffitype.is_double():
            self._float(w_ffitype, w_obj)
        elif w_ffitype.is_singlefloat():
            self._singlefloat(w_ffitype, w_obj)
        elif w_ffitype.is_struct():
            if isinstance(w_obj, W_StructureInstance):
                self.handle_struct_rawffi(w_ffitype, w_obj)
            else:
                w_obj = space.interp_w(W__StructInstance, w_obj)
                self.handle_struct(w_ffitype, w_obj)
        else:
            self.error(w_ffitype, w_obj)

    def _longlong(self, w_ffitype, w_obj):
        # a separate function, which can be seen by the jit or not,
        # depending on whether longlongs are supported
        longlongval = self.space.truncatedlonglong_w(w_obj, allow_conversion=False)
        self.handle_longlong(w_ffitype, w_obj, longlongval)

    def _float(self, w_ffitype, w_obj):
        # a separate function, which can be seen by the jit or not,
        # depending on whether floats are supported
        floatval = self.space.float_w(w_obj, allow_conversion=False)
        self.handle_float(w_ffitype, w_obj, floatval)

    def _singlefloat(self, w_ffitype, w_obj):
        # a separate function, which can be seen by the jit or not,
        # depending on whether singlefloats are supported
        from rpython.rlib.rarithmetic import r_singlefloat
        floatval = self.space.float_w(w_obj, allow_conversion=False)
        singlefloatval = r_singlefloat(floatval)
        self.handle_singlefloat(w_ffitype, w_obj, singlefloatval)

    def maybe_handle_char_or_unichar_p(self, w_ffitype, w_obj):
        w_type = jit.promote(self.space.type(w_obj))
        if w_ffitype.is_char_p() and w_type is self.space.w_bytes:
            strval = self.space.bytes_w(w_obj)
            self.handle_char_p(w_ffitype, w_obj, strval)
            return True
        elif w_ffitype.is_unichar_p() and (w_type is self.space.w_bytes or
                                           w_type is self.space.w_unicode):
            utf8, lgt = self.space.utf8_len_w(w_obj)
            self.handle_unichar_p(w_ffitype, w_obj, utf8, lgt)
            return True
        return False

    def convert_pointer_arg_maybe(self, w_arg, w_argtype):
        """
        Try to convert the argument by calling _as_ffi_pointer_()
        """
        space = self.space
        meth = space.lookup(w_arg, '_as_ffi_pointer_') # this also promotes the type
        if meth:
            return space.call_function(meth, w_arg, w_argtype)
        else:
            return w_arg

    def error(self, w_ffitype, w_obj):
        raise oefmt(self.space.w_TypeError,
                    "Unsupported ffi type to convert: %s", w_ffitype.name)

    def handle_signed(self, w_ffitype, w_obj, intval):
        """
        intval: lltype.Signed
        """
        self.error(w_ffitype, w_obj)

    def handle_unsigned(self, w_ffitype, w_obj, uintval):
        """
        uintval: lltype.Unsigned
        """
        self.error(w_ffitype, w_obj)

    def handle_pointer(self, w_ffitype, w_obj, intval):
        """
        intval: lltype.Signed
        """
        self.error(w_ffitype, w_obj)

    def handle_char(self, w_ffitype, w_obj, intval):
        """
        intval: lltype.Signed
        """
        self.error(w_ffitype, w_obj)

    def handle_unichar(self, w_ffitype, w_obj, intval):
        """
        intval: lltype.Signed
        """
        self.error(w_ffitype, w_obj)

    def handle_longlong(self, w_ffitype, w_obj, longlongval):
        """
        longlongval: lltype.SignedLongLong
        """
        self.error(w_ffitype, w_obj)

    def handle_char_p(self, w_ffitype, w_obj, strval):
        """
        strval: interp-level str
        """
        self.error(w_ffitype, w_obj)

    def handle_unichar_p(self, w_ffitype, w_obj, utf8val, utf8len):
        """
        unicodeval: interp-level unicode
        """
        self.error(w_ffitype, w_obj)

    def handle_float(self, w_ffitype, w_obj, floatval):
        """
        floatval: lltype.Float
        """
        self.error(w_ffitype, w_obj)

    def handle_singlefloat(self, w_ffitype, w_obj, singlefloatval):
        """
        singlefloatval: lltype.SingleFloat
        """
        self.error(w_ffitype, w_obj)

    def handle_struct(self, w_ffitype, w_structinstance):
        """
        w_structinstance: W_StructureInstance
        """
        self.error(w_ffitype, w_structinstance)

    def handle_struct_rawffi(self, w_ffitype, w_structinstance):
        """
        This method should be killed as soon as we remove support for _rawffi structures

        w_structinstance: W_StructureInstance
        """
        self.error(w_ffitype, w_structinstance)



class ToAppLevelConverter(object):
    """
    Wrap a low-level value to an app-level object, following the conversion
    rules which apply to the specified w_ffitype.  The value is got by calling
    the get_* method corresponding to the w_ffitype. Subclasses should
    override the desired ones.
    """

    def __init__(self, space):
        self.space = space

    def do_and_wrap(self, w_ffitype):
        from pypy.module._rawffi.alt.interp_struct import W__StructDescr
        space = self.space
        if w_ffitype.is_longlong():
            # note that we must check for longlong first, because either
            # is_signed or is_unsigned returns true anyway
            assert libffi.IS_32_BIT
            return self._longlong(w_ffitype)
        elif w_ffitype.is_signed():
            intval = self.get_signed(w_ffitype)
            return space.newint(intval)
        elif (w_ffitype is app_types.ulonglong or
              (not libffi.IS_WIN64 and w_ffitype is app_types.ulong) or
              (libffi.IS_32_BIT and w_ffitype is app_types.uint)):
            # Note that we the second check (for ulonglong) is meaningful only
            # on 64 bit, because on 32 bit the ulonglong case would have been
            # handled by the is_longlong() branch above. On 64 bit, ulonglong
            # is essentially the same as ulong unless we are on win64.
            #
            # We need to be careful when the return type is ULONGLONG, because
            # the value might not fit into a SIGNED, and thus might require
            # an app-level <long>.  This is why we need to treat it separately
            # than the other unsigned types.
            uintval = self.get_unsigned(w_ffitype)
            return space.newint(uintval)
        elif w_ffitype.is_unsigned(): # note that ulong is handled just before
            intval = self.get_unsigned_which_fits_into_a_signed(w_ffitype)
            return space.newint(intval)
        elif w_ffitype.is_pointer():
            uintval = self.get_pointer(w_ffitype)
            return space.newint(uintval)
        elif w_ffitype.is_char():
            ucharval = self.get_char(w_ffitype)
            return space.newbytes(chr(ucharval))
        elif w_ffitype.is_unichar():
            wcharval = r_uint(self.get_unichar(w_ffitype))
            return space.newutf8(rutf8.unichr_as_utf8(wcharval), 1)
        elif w_ffitype.is_double():
            return self._float(w_ffitype)
        elif w_ffitype.is_singlefloat():
            return self._singlefloat(w_ffitype)
        elif w_ffitype.is_struct():
            w_structdescr = w_ffitype.w_structdescr
            if isinstance(w_structdescr, W__StructDescr):
                return self.get_struct(w_ffitype, w_structdescr)
            elif isinstance(w_structdescr, W_Structure):
                return self.get_struct_rawffi(w_ffitype, w_structdescr)
            else:
                raise oefmt(self.space.w_TypeError, "Unsupported struct shape")
        elif w_ffitype.is_void():
            voidval = self.get_void(w_ffitype)
            assert voidval is None
            return space.w_None
        else:
            self.error(w_ffitype)

    def _longlong(self, w_ffitype):
        # a separate function, which can be seen by the jit or not,
        # depending on whether longlongs are supported
        if w_ffitype is app_types.slonglong:
            longlongval = self.get_longlong(w_ffitype)
            return self.space.newint(longlongval)
        elif w_ffitype is app_types.ulonglong:
            ulonglongval = self.get_ulonglong(w_ffitype)
            return self.space.newint(ulonglongval)
        else:
            self.error(w_ffitype)

    def _float(self, w_ffitype):
        # a separate function, which can be seen by the jit or not,
        # depending on whether floats are supported
        floatval = self.get_float(w_ffitype)
        return self.space.newfloat(floatval)

    def _singlefloat(self, w_ffitype):
        # a separate function, which can be seen by the jit or not,
        # depending on whether singlefloats are supported
        singlefloatval = self.get_singlefloat(w_ffitype)
        return self.space.newfloat(float(singlefloatval))

    def error(self, w_ffitype):
        raise oefmt(self.space.w_TypeError,
                    "Unsupported ffi type to convert: %s", w_ffitype.name)

    def get_longlong(self, w_ffitype):
        """
        Return type: lltype.SignedLongLong
        """
        self.error(w_ffitype)

    def get_ulonglong(self, w_ffitype):
        """
        Return type: lltype.UnsignedLongLong
        """
        self.error(w_ffitype)

    def get_signed(self, w_ffitype):
        """
        Return type: lltype.Signed
        """
        self.error(w_ffitype)

    def get_unsigned(self, w_ffitype):
        """
        Return type: lltype.Unsigned
        """
        self.error(w_ffitype)

    def get_unsigned_which_fits_into_a_signed(self, w_ffitype):
        """
        Return type: lltype.Signed.

        We return Signed even if the input type is unsigned, because this way
        we get an app-level <int> instead of a <long>.
        """
        self.error(w_ffitype)

    def get_pointer(self, w_ffitype):
        """
        Return type: lltype.Unsigned
        """
        self.error(w_ffitype)

    def get_char(self, w_ffitype):
        """
        Return type: rffi.UCHAR
        """
        self.error(w_ffitype)

    def get_unichar(self, w_ffitype):
        """
        Return type: rffi.WCHAR_T
        """
        self.error(w_ffitype)

    def get_float(self, w_ffitype):
        """
        Return type: lltype.Float
        """
        self.error(w_ffitype)

    def get_singlefloat(self, w_ffitype):
        """
        Return type: lltype.SingleFloat
        """
        self.error(w_ffitype)

    def get_struct(self, w_ffitype, w_structdescr):
        """
        Return type: lltype.Signed
        (the address of the structure)
        """
        self.error(w_ffitype)

    def get_struct_rawffi(self, w_ffitype, w_structdescr):
        """
        This should be killed as soon as we kill support for _rawffi structures

        Return type: lltype.Unsigned
        (the address of the structure)
        """
        self.error(w_ffitype)

    def get_void(self, w_ffitype):
        """
        Return type: None
        """
        self.error(w_ffitype)
