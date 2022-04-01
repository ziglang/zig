"""The builtin object type implementation"""

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import applevel, interp2app, unwrap_spec
from pypy.interpreter.typedef import (
    GetSetProperty, TypeDef, default_identity_hash)
from pypy.objspace.descroperation import Object
from pypy.interpreter.function import StaticMethod

from rpython.rlib.objectmodel import specialize


app = applevel(r'''
import sys

def _abstract_method_error(typ):
    methods = ", ".join(sorted(typ.__abstractmethods__))
    method_s = 's' if len(typ.__abstractmethods__) > 1 else ''
    err = "Can't instantiate abstract class %s with abstract method%s %s"
    raise TypeError(err % (typ.__name__, method_s, methods))

def reduce_1(obj, proto):
    import copyreg
    return copyreg._reduce_ex(obj, proto)

def _getstate(obj, required=False):
    cls = obj.__class__

    try:
        getstate = obj.__getstate__
    except AttributeError:
        # and raises a TypeError if the condition holds true, this is done
        # just before reduce_2 is called in pypy
        state = getattr(obj, "__dict__", None)
        # CPython returns None if the dict is empty
        if state is not None and len(state) == 0:
            state = None
        names = slotnames(cls) # not checking for list
        if names is not None:
            slots = {}
            for name in names:
                try:
                    value = getattr(obj, name)
                except AttributeError:
                    pass
                else:
                    slots[name] =  value
            if slots:
                state = state, slots
    else:
        state = getstate()
    return state

def reduce_2(obj, proto, args, kwargs):
    cls = obj.__class__

    if not hasattr(type(obj), "__new__"):
        raise TypeError("can't pickle %s objects" % type(obj).__name__)

    try:
        copyreg = sys.modules['copyreg']
    except KeyError:
        import copyreg

    if not isinstance(args, tuple):
        raise TypeError("__getnewargs__ should return a tuple")
    if not kwargs:
       newobj = copyreg.__newobj__
       args2 = (cls,) + args
    else:
       newobj = copyreg.__newobj_ex__
       args2 = (cls, args, kwargs)
    state = _getstate(obj)
    listitems = iter(obj) if isinstance(obj, list) else None
    dictitems = iter(obj.items()) if isinstance(obj, dict) else None

    return newobj, args2, state, listitems, dictitems


def slotnames(cls):
    if not isinstance(cls, type):
        return None

    try:
        return cls.__dict__["__slotnames__"]
    except KeyError:
        pass

    try:
        copyreg = sys.modules['copyreg']
    except KeyError:
        import copyreg
    slotnames = copyreg._slotnames(cls)
    if not isinstance(slotnames, list) and slotnames is not None:
        raise TypeError("copyreg._slotnames didn't return a list or None")
    return slotnames
''', filename=__file__)

_abstract_method_error = app.interphook("_abstract_method_error")
reduce_1 = app.interphook('reduce_1')
reduce_2 = app.interphook('reduce_2')


class W_ObjectObject(W_Root):
    """Instances of this class are what the user can directly see with an
    'object()' call."""


def _excess_args(__args__):
    return bool(__args__.arguments_w) or bool(__args__.keyword_names_w)

@specialize.memo()
def _object_new(space):
    "Utility that returns the function object.__new__."
    w_x = space.lookup_in_type(space.w_object, '__new__')
    assert isinstance(w_x, StaticMethod)
    return w_x.w_function

@specialize.memo()
def _object_init(space):
    "Utility that returns the function object.__init__."
    return space.lookup_in_type(space.w_object, '__init__')

def _same_static_method(space, w_x, w_y):
    # pff pff pff
    if isinstance(w_x, StaticMethod): w_x = w_x.w_function
    return space.is_w(w_x, w_y)

def descr__new__(space, w_type, __args__):
    from pypy.objspace.std.typeobject import _precheck_for_new
    w_type = _precheck_for_new(space, w_type)

    if _excess_args(__args__):
        tp_new = space.lookup_in_type(w_type, '__new__')
        tp_init = space.lookup_in_type(w_type, '__init__')
        if not _same_static_method(space, tp_new, _object_new(space)):
            raise oefmt(space.w_TypeError,
                    "object.__new__() takes exactly one argument (the type to instantiate)")
        if space.is_w(tp_init, _object_init(space)):
            raise oefmt(space.w_TypeError,
                        "%s() takes no arguments", w_type.name)
    if w_type.is_abstract():
        _abstract_method_error(space, w_type)
    return space.allocate_instance(W_ObjectObject, w_type)


def descr___subclasshook__(space, __args__):
    return space.w_NotImplemented

def descr___init_subclass__(space, w_cls):
    return space.w_None

def descr__init__(space, w_obj, __args__):
    if _excess_args(__args__):
        w_type = space.type(w_obj)
        tp_new = space.lookup_in_type(w_type, '__new__')
        tp_init = space.lookup_in_type(w_type, '__init__')
        if not space.is_w(tp_init, _object_init(space)):
            raise oefmt(space.w_TypeError,
                        "object.__init__() takes exactly one argument (the instance to initialize)")
        elif _same_static_method(space, tp_new, _object_new(space)):
            raise oefmt(space.w_TypeError,
                        "%T.__init__() takes exactly one argument (the instance to initialize)",
                        w_obj)


def descr_get___class__(space, w_obj):
    return space.type(w_obj)


def descr_set___class__(space, w_obj, w_newcls):
    from pypy.objspace.std.typeobject import W_TypeObject
    from pypy.interpreter.module import Module
    #
    if not isinstance(w_newcls, W_TypeObject):
        raise oefmt(space.w_TypeError,
                    "__class__ must be set to a class, not '%T' "
                    "object", w_newcls)
    if not (w_newcls.is_heaptype() or
            w_newcls is space.gettypeobject(Module.typedef)):
        raise oefmt(space.w_TypeError,
                    "__class__ assignment only supported for heap types "
                    "or ModuleType subclasses")
    w_oldcls = space.type(w_obj)
    assert isinstance(w_oldcls, W_TypeObject)
    if (w_oldcls.get_full_instance_layout() ==
        w_newcls.get_full_instance_layout()):
        w_obj.setclass(space, w_newcls)
    else:
        raise oefmt(space.w_TypeError,
                    "__class__ assignment: '%N' object layout differs from "
                    "'%N'", w_oldcls, w_newcls)


def descr__repr__(space, w_obj):
    classname = space.getfulltypename(w_obj)
    return w_obj.getrepr(space, '%s object' % (classname,))


def descr__str__(space, w_obj):
    w_type = space.type(w_obj)
    w_impl = w_type.lookup("__repr__")
    if w_impl is None:
        # can it really occur?
        raise oefmt(space.w_TypeError, "operand does not support unary str")
    return space.get_and_call_function(w_impl, w_obj)


def _getnewargs(space, w_obj):
    w_descr = space.lookup(w_obj, '__getnewargs_ex__')
    hasargs = True
    if w_descr is not None:
        w_result = space.get_and_call_function(w_descr, w_obj)
        if not space.isinstance_w(w_result, space.w_tuple):
            raise oefmt(space.w_TypeError,
                "__getnewargs_ex__ should return a tuple, not '%T'", w_result)
        n = space.len_w(w_result)
        if n != 2:
            raise oefmt(space.w_ValueError,
                "__getnewargs_ex__ should return a tuple of length 2, not %d",
                n)
        w_args, w_kwargs = space.fixedview(w_result, 2)
        if not space.isinstance_w(w_args, space.w_tuple):
            raise oefmt(space.w_TypeError,
                "first item of the tuple returned by __getnewargs_ex__ must "
                "be a tuple, not '%T'", w_args)
        if not space.isinstance_w(w_kwargs, space.w_dict):
            raise oefmt(space.w_TypeError,
                "second item of the tuple returned by __getnewargs_ex__ must "
                "be a dict, not '%T'", w_kwargs)
    else:
        w_descr = space.lookup(w_obj, '__getnewargs__')
        if w_descr is not None:
            w_args = space.get_and_call_function(w_descr, w_obj)
            if not space.isinstance_w(w_args, space.w_tuple):
                raise oefmt(space.w_TypeError,
                    "__getnewargs__ should return a tuple, not '%T'", w_args)
        else:
            hasargs = False
            w_args = space.newtuple([])
        w_kwargs = space.w_None
    return hasargs, w_args, w_kwargs

def descr__reduce__(space, w_obj):
    w_proto = space.newint(0)
    return reduce_1(space, w_obj, w_proto)

@unwrap_spec(proto=int)
def descr__reduce_ex__(space, w_obj, proto):
    w_st_reduce = space.newtext('__reduce__')
    w_reduce = space.findattr(w_obj, w_st_reduce)
    if w_reduce is not None:
        # Check if __reduce__ has been overridden:
        # "type(obj).__reduce__ is not object.__reduce__"
        w_cls_reduce = space.getattr(space.type(w_obj), w_st_reduce)
        w_obj_reduce = space.getattr(space.w_object, w_st_reduce)
        override = not space.is_w(w_cls_reduce, w_obj_reduce)
        if override:
            return space.call_function(w_reduce)
    w_proto = space.newint(proto)
    if proto >= 2:
        hasargs, w_args, w_kwargs = _getnewargs(space, w_obj)
        w_getstate = space.lookup(w_obj, '__get_state__')
        if w_getstate is None:
            required = (not hasargs and
                not space.isinstance_w(w_obj, space.w_list) and
                not space.isinstance_w(w_obj, space.w_dict))
            w_obj_type = space.type(w_obj)
            if required and w_obj_type.layout.typedef.variable_sized:
                raise oefmt(
                    space.w_TypeError, "cannot pickle %N objects", w_obj_type)
        return reduce_2(space, w_obj, w_proto, w_args, w_kwargs)
    return reduce_1(space, w_obj, w_proto)

def descr___format__(space, w_obj, w_format_spec):
    if space.isinstance_w(w_format_spec, space.w_unicode):
        w_as_str = space.call_function(space.w_unicode, w_obj)
    elif space.isinstance_w(w_format_spec, space.w_bytes):
        w_as_str = space.str(w_obj)
    else:
        raise oefmt(space.w_TypeError, "format_spec must be a string")
    if space.len_w(w_format_spec) > 0:
        raise oefmt(space.w_TypeError,
                     "unsupported format string passed to %T.__format__",
                     w_obj);
    return space.format(w_as_str, w_format_spec)

def descr__eq__(space, w_self, w_other):
    if space.is_w(w_self, w_other):
        return space.w_True
    # Return NotImplemented instead of False, so if two objects are
    # compared, both get a chance at the comparison (issue #1393)
    return space.w_NotImplemented

def descr__ne__(space, w_self, w_other):
    # By default, __ne__() delegates to __eq__() and inverts the result,
    # unless the latter returns NotImplemented.
    w_eq = space.lookup(w_self, '__eq__')
    w_res = space.get_and_call_function(w_eq, w_self, w_other)
    if space.is_w(w_res, space.w_NotImplemented):
        return w_res
    return space.not_(w_res)

def descr_richcompare(space, w_self, w_other):
    return space.w_NotImplemented

def descr__dir__(space, w_obj):
    from pypy.objspace.std.util import _objectdir
    return space.call_function(space.w_list, _objectdir(space, w_obj))

W_ObjectObject.typedef = TypeDef("object",
    _text_signature_='()',
    __doc__ = "The most base type",
    __new__ = interp2app(descr__new__),
    __subclasshook__ = interp2app(descr___subclasshook__, as_classmethod=True),
    __init_subclass__ = interp2app(descr___init_subclass__, as_classmethod=True),

    # these are actually implemented in pypy.objspace.descroperation
    __getattribute__ = interp2app(Object.descr__getattribute__.im_func),
    __setattr__ = interp2app(Object.descr__setattr__.im_func),
    __delattr__ = interp2app(Object.descr__delattr__.im_func),


    __init__ = interp2app(descr__init__),
    __class__ = GetSetProperty(descr_get___class__, descr_set___class__),
    __repr__ = interp2app(descr__repr__),
    __str__ = interp2app(descr__str__),
    __hash__ = interp2app(default_identity_hash),
    __reduce__ = interp2app(descr__reduce__),
    __reduce_ex__ = interp2app(descr__reduce_ex__),
    __format__ = interp2app(descr___format__),
    __dir__ = interp2app(descr__dir__),

    __eq__ = interp2app(descr__eq__),
    __ne__ = interp2app(descr__ne__),
    __le__ = interp2app(descr_richcompare),
    __lt__ = interp2app(descr_richcompare),
    __ge__ = interp2app(descr_richcompare),
    __gt__ = interp2app(descr_richcompare),
)
