from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.typedef import TypeDef


class W_NoneObject(W_Root):
    def unwrap(self, space):
        return None

    @staticmethod
    def descr_new(space, w_type):
        "Create and return a new object.  See help(type) for accurate signature."
        return space.w_None

    def descr_bool(self, space):
        return space.w_False

    def descr_repr(self, space):
        return space.newtext('None')


W_NoneObject.w_None = W_NoneObject()

W_NoneObject.typedef = TypeDef("NoneType",
    __new__ = interp2app(W_NoneObject.descr_new),
    __bool__ = interp2app(W_NoneObject.descr_bool),
    __repr__ = interp2app(W_NoneObject.descr_repr),
)
W_NoneObject.typedef.acceptable_as_base_class = False
