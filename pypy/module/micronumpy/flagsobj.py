from rpython.rlib import jit
from rpython.rlib.rstring import StringBuilder

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.module.micronumpy import constants as NPY
from pypy.module.micronumpy.strides import is_c_contiguous, is_f_contiguous

def enable_flags(arr, flags):
    arr.flags |= flags

def clear_flags(arr, flags):
    arr.flags &= ~flags

def get_tf_str(flags, key):
    if flags & key:
        return 'True'
    return 'False'

class W_FlagsObject(W_Root):
    def __init__(self, arr):
        if arr:
            self.flags = arr.get_flags()
        else:
            self.flags = (NPY.ARRAY_C_CONTIGUOUS | NPY.ARRAY_F_CONTIGUOUS |
                          NPY.ARRAY_OWNDATA | NPY.ARRAY_ALIGNED)

    def descr__new__(space, w_subtype):
        self = space.allocate_instance(W_FlagsObject, w_subtype)
        W_FlagsObject.__init__(self, None)
        return self

    def descr_c_contiguous(self, space):
        return space.newbool(bool(self.flags & NPY.ARRAY_C_CONTIGUOUS))

    def descr_f_contiguous(self, space):
        return space.newbool(bool(self.flags & NPY.ARRAY_F_CONTIGUOUS))

    def descr_get_writeable(self, space):
        return space.newbool(bool(self.flags & NPY.ARRAY_WRITEABLE))

    def descr_get_owndata(self, space):
        return space.newbool(bool(self.flags & NPY.ARRAY_OWNDATA))

    def descr_get_aligned(self, space):
        return space.newbool(bool(self.flags & NPY.ARRAY_ALIGNED))

    def descr_get_fnc(self, space):
        return space.newbool(bool(
            self.flags & NPY.ARRAY_F_CONTIGUOUS and not
            self.flags & NPY.ARRAY_C_CONTIGUOUS ))

    def descr_get_forc(self, space):
        return space.newbool(bool(
            self.flags & NPY.ARRAY_F_CONTIGUOUS or
            self.flags & NPY.ARRAY_C_CONTIGUOUS ))

    def descr_get_num(self, space):
        return space.newint(self.flags)

    def descr_getitem(self, space, w_item):
        key = space.text_w(w_item)
        if key == "C" or key == "CONTIGUOUS" or key == "C_CONTIGUOUS":
            return self.descr_c_contiguous(space)
        if key == "F" or key == "FORTRAN" or key == "F_CONTIGUOUS":
            return self.descr_f_contiguous(space)
        if key == "W" or key == "WRITEABLE":
            return self.descr_get_writeable(space)
        if key == "FNC":
            return self.descr_get_fnc(space)
        if key == "FORC":
            return self.descr_get_forc(space)
        raise oefmt(space.w_KeyError, "Unknown flag")

    def descr_setitem(self, space, w_item, w_value):
        raise oefmt(space.w_KeyError, "Unknown flag")

    def eq(self, space, w_other):
        if not isinstance(w_other, W_FlagsObject):
            return False
        return self.flags == w_other.flags

    def descr_eq(self, space, w_other):
        return space.newbool(self.eq(space, w_other))

    def descr_ne(self, space, w_other):
        return space.newbool(not self.eq(space, w_other))

    def descr___str__(self, space):
        s = StringBuilder()
        s.append('  C_CONTIGUOUS : ')
        s.append(get_tf_str(self.flags, NPY.ARRAY_C_CONTIGUOUS))
        s.append('\n  F_CONTIGUOUS : ')
        s.append(get_tf_str(self.flags, NPY.ARRAY_F_CONTIGUOUS))
        s.append('\n  OWNDATA : ')
        s.append(get_tf_str(self.flags, NPY.ARRAY_OWNDATA))
        s.append('\n  WRITEABLE : ')
        s.append(get_tf_str(self.flags, NPY.ARRAY_WRITEABLE))
        s.append('\n  ALIGNED : ')
        s.append(get_tf_str(self.flags, NPY.ARRAY_ALIGNED))
        s.append('\n  UPDATEIFCOPY : ')
        s.append(get_tf_str(self.flags, NPY.ARRAY_UPDATEIFCOPY))
        return space.newtext(s.build())

W_FlagsObject.typedef = TypeDef("numpy.flagsobj",
    __new__ = interp2app(W_FlagsObject.descr__new__.im_func),

    __getitem__ = interp2app(W_FlagsObject.descr_getitem),
    __setitem__ = interp2app(W_FlagsObject.descr_setitem),
    __eq__ = interp2app(W_FlagsObject.descr_eq),
    __ne__ = interp2app(W_FlagsObject.descr_ne),
    __str__ = interp2app(W_FlagsObject.descr___str__),
    __repr__ = interp2app(W_FlagsObject.descr___str__),

    contiguous = GetSetProperty(W_FlagsObject.descr_c_contiguous),
    c_contiguous = GetSetProperty(W_FlagsObject.descr_c_contiguous),
    f_contiguous = GetSetProperty(W_FlagsObject.descr_f_contiguous),
    fortran = GetSetProperty(W_FlagsObject.descr_f_contiguous),
    writeable = GetSetProperty(W_FlagsObject.descr_get_writeable),
    owndata = GetSetProperty(W_FlagsObject.descr_get_owndata),
    aligned = GetSetProperty(W_FlagsObject.descr_get_aligned),
    fnc = GetSetProperty(W_FlagsObject.descr_get_fnc),
    forc = GetSetProperty(W_FlagsObject.descr_get_forc),
    num = GetSetProperty(W_FlagsObject.descr_get_num),
)
