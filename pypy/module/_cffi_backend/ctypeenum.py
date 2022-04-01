"""
Enums.
"""

from pypy.module._cffi_backend import misc
from pypy.module._cffi_backend.ctypeprim import (W_CTypePrimitiveSigned,
    W_CTypePrimitiveUnsigned)


class _Mixin_Enum(object):
    _mixin_ = True

    def __init__(self, space, name, size, align, enumerators, enumvalues):
        self._super.__init__(self, space, size, name, len(name), align)
        self.enumerators2values = {}   # str -> int
        self.enumvalues2erators = {}   # int -> str
        for i in range(len(enumerators)-1, -1, -1):
            self.enumerators2values[enumerators[i]] = enumvalues[i]
            self.enumvalues2erators[enumvalues[i]] = enumerators[i]

    def _fget(self, attrchar):
        if attrchar == 'e':     # elements
            space = self.space
            w_dct = space.newdict()
            for enumvalue, enumerator in self.enumvalues2erators.iteritems():
                space.setitem(w_dct, space.newint(enumvalue),
                                     space.newtext(enumerator))
            return w_dct
        if attrchar == 'R':     # relements
            space = self.space
            w_dct = space.newdict()
            for enumerator, enumvalue in self.enumerators2values.iteritems():
                space.setitem(w_dct, space.newtext(enumerator),
                                     space.newint(enumvalue))
            return w_dct
        return self._super._fget(self, attrchar)

    def extra_repr(self, cdata):
        value = self._get_value(cdata)
        try:
            s = self.enumvalues2erators[value]
        except KeyError:
            return str(value)
        else:
            return '%s: %s' % (value, s)

    def string(self, cdataobj, maxlen):
        with cdataobj as ptr:
            value = self._get_value(ptr)
        try:
            s = self.enumvalues2erators[value]
        except KeyError:
            s = str(value)
        return self.space.newtext(s)


class W_CTypeEnumSigned(_Mixin_Enum, W_CTypePrimitiveSigned):
    _attrs_            = ['enumerators2values', 'enumvalues2erators']
    _immutable_fields_ = ['enumerators2values', 'enumvalues2erators']
    kind = "enum"
    _super = W_CTypePrimitiveSigned

    def _get_value(self, cdata):
        # returns a signed long
        assert self.value_fits_long
        return misc.read_raw_long_data(cdata, self.size)


class W_CTypeEnumUnsigned(_Mixin_Enum, W_CTypePrimitiveUnsigned):
    _attrs_            = ['enumerators2values', 'enumvalues2erators']
    _immutable_fields_ = ['enumerators2values', 'enumvalues2erators']
    kind = "enum"
    _super = W_CTypePrimitiveUnsigned

    def _get_value(self, cdata):
        # returns an unsigned long
        assert self.value_fits_ulong
        return misc.read_raw_ulong_data(cdata, self.size)
