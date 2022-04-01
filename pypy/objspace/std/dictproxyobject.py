"""
Read-only proxy for mappings.

Its main use is as the return type of cls.__dict__.
"""

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import oefmt
from pypy.interpreter.gateway import unwrap_spec, WrappedDefault
from pypy.interpreter.typedef import TypeDef, interp2app
from pypy.objspace.std.util import generic_alias_class_getitem

class W_DictProxyObject(W_Root):
    "Read-only proxy for mappings."

    def __init__(self, w_mapping):
        self.w_mapping = w_mapping

    @staticmethod
    def descr_new(space, w_type, w_mapping):
        if (not space.lookup(w_mapping, "__getitem__") or
                space.isinstance_w(w_mapping, space.w_list) or
                space.isinstance_w(w_mapping, space.w_tuple)):
            raise oefmt(space.w_TypeError,
                        "mappingproxy() argument must be a mapping, not %T",
                        w_mapping)
        return W_DictProxyObject(w_mapping)

    def descr_init(self, space, __args__):
        pass

    def descr_len(self, space):
        return space.len(self.w_mapping)

    def descr_getitem(self, space, w_key):
        return space.getitem(self.w_mapping, w_key)

    def descr_contains(self, space, w_key):
        return space.contains(self.w_mapping, w_key)

    def descr_iter(self, space):
        return space.iter(self.w_mapping)

    def descr_str(self, space):
        return space.str(self.w_mapping)

    def descr_repr(self, space):
        return space.newtext(b"mappingproxy(%s)" %
                                (space.utf8_w(space.repr(self.w_mapping)),))

    def descr_or(self, space, w_other):
        if isinstance(w_other, W_DictProxyObject):
            w_other = w_other.w_mapping
        if not space.isinstance_w(w_other, space.w_dict):
            return space.w_NotImplemented
        w_copyself = self.copy_w(space)
        space.call_method(w_copyself, "update", w_other)
        return w_copyself

    def descr_ror(self, space, w_other):
        if isinstance(w_other, W_DictProxyObject):
            w_other = w_other.w_mapping
        if not space.isinstance_w(w_other, space.w_dict):
            return space.w_NotImplemented
        return space.call_method(w_other, "__or__", self.w_mapping)

    def descr_ior(self, space, w_other):
        raise oefmt(space.w_TypeError,
            "'|=' is not supported by mappingproxy; use '|' instead")

    @unwrap_spec(w_default=WrappedDefault(None))
    def get_w(self, space, w_key, w_default):
        return space.call_method(self.w_mapping, "get", w_key, w_default)

    def keys_w(self, space):
        return space.call_method(self.w_mapping, "keys")

    def values_w(self, space):
        return space.call_method(self.w_mapping, "values")

    def items_w(self, space):
        return space.call_method(self.w_mapping, "items")

    def copy_w(self, space):
        return space.call_method(self.w_mapping, "copy")

    def descr_reversed(self, space):
        return space.call_method(self.w_mapping, "__reversed__")

cmp_methods = {}
def make_cmp_method(op):
    def descr_op(self, space, w_other):
        return getattr(space, op)(self.w_mapping, w_other)
    descr_name = 'descr_' + op
    descr_op.__name__ = descr_name
    setattr(W_DictProxyObject, descr_name, descr_op)
    cmp_methods['__%s__' % op] = interp2app(getattr(W_DictProxyObject, descr_name))

for op in ['eq', 'ne', 'gt', 'ge', 'lt', 'le']:
    make_cmp_method(op)


W_DictProxyObject.typedef = TypeDef(
    'mappingproxy',
    __new__=interp2app(W_DictProxyObject.descr_new),
    __init__=interp2app(W_DictProxyObject.descr_init),
    __len__=interp2app(W_DictProxyObject.descr_len),
    __getitem__=interp2app(W_DictProxyObject.descr_getitem),
    __contains__=interp2app(W_DictProxyObject.descr_contains),
    __iter__=interp2app(W_DictProxyObject.descr_iter),
    __str__=interp2app(W_DictProxyObject.descr_str),
    __repr__=interp2app(W_DictProxyObject.descr_repr),
    __or__=interp2app(W_DictProxyObject.descr_or),
    __ror__=interp2app(W_DictProxyObject.descr_ror),
    __ior__=interp2app(W_DictProxyObject.descr_ior),
    __reversed__ = interp2app(W_DictProxyObject.descr_reversed),
    __class_getitem__ = interp2app(
        generic_alias_class_getitem, as_classmethod=True),
    get=interp2app(W_DictProxyObject.get_w),
    keys=interp2app(W_DictProxyObject.keys_w),
    values=interp2app(W_DictProxyObject.values_w),
    items=interp2app(W_DictProxyObject.items_w),
    copy=interp2app(W_DictProxyObject.copy_w),
    **cmp_methods
)

def _set_flag_map_or_seq(space):
    w_type = space.gettypeobject(W_DictProxyObject.typedef)
    w_type.flag_map_or_seq = 'M'
