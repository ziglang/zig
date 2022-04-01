"""
These are the default implementation for type slots that we put
in user-defined app-level Python classes, if the class implements
the corresponding '__xxx__' special method.  It should mostly just
call back the general version of the space operation.

This is only approximately correct.  One problem is that some
details are likely subtly wrong.  Another problem is that we don't
track changes to an app-level Python class (addition or removal of
'__xxx__' special methods) after initalization of the PyTypeObject.
"""

from pypy.interpreter.error import oefmt
from pypy.interpreter.argument import Arguments
from pypy.module.cpyext.api import slot_function, PyObject, Py_ssize_t
from pypy.module.cpyext.api import PyTypeObjectPtr
from rpython.rtyper.lltypesystem import rffi, lltype

@slot_function([PyObject], Py_ssize_t, error=-1)
def slot_sq_length(space, w_obj):
    return space.int_w(space.len(w_obj))

@slot_function([PyObject], lltype.Signed, error=-1)
def slot_tp_hash(space, w_obj):
    return space.hash_w(w_obj)

@slot_function([PyObject, Py_ssize_t], PyObject)
def slot_sq_item(space, w_obj, index):
    return space.getitem(w_obj, space.newint(index))

@slot_function([PyTypeObjectPtr, PyObject, PyObject], PyObject)
def slot_tp_new(space, w_type, w_args, w_kwds):
    # XXX problem - we need to find the actual __new__ function to call.
    #     but we have no 'self' argument. Theoretically, self will be
    #     w_type, but if w_type is a subclass of self, and w_type has a
    #     __new__ function that calls super().__new__, and that call ends
    #     up here, we will get infinite recursion. Prevent the recursion
    #     in the simple case (from cython) where w_type is a cpytype, but
    #     we know (since we are in this function) that self is not a cpytype
    from pypy.module.cpyext.typeobject import W_PyCTypeObject
    w_type0 = w_type
    mro_w = space.listview(space.getattr(w_type0, space.newtext('__mro__')))
    for w_m in mro_w[1:]:
        if not w_type0.is_cpytype():
            break
        w_type0 = w_m
    w_impl = space.getattr(w_type0, space.newtext('__new__'))
    args = Arguments(space, [w_type],
                     w_stararg=w_args, w_starstararg=w_kwds)
    return space.call_args(w_impl, args)

@slot_function([PyObject, PyObject, PyObject], PyObject)
def slot_tp_call(space, w_self, w_args, w_kwds):
    args = Arguments(space, [], w_stararg=w_args, w_starstararg=w_kwds)
    return space.call_args(w_self, args)

# unary functions

@slot_function([PyObject], PyObject)
def slot_tp_str(space, w_obj):
    return space.str(w_obj)

@slot_function([PyObject], PyObject)
def slot_tp_repr(space, w_obj):
    return space.repr(w_obj)

@slot_function([PyObject], PyObject)
def slot_nb_int(space, w_obj):
    return space.int(w_obj)

@slot_function([PyObject], PyObject)
def slot_nb_float(space, w_obj):
    return space.float(w_obj)

#binary functions

@slot_function([PyObject, PyObject], PyObject)
def slot_nb_add(space, w_obj1, w_obj2):
    return space.add(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_nb_subtract(space, w_obj1, w_obj2):
    return space.sub(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_nb_multiply(space, w_obj1, w_obj2):
    return space.mul(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_nb_divide(space, w_obj1, w_obj2):
    return space.div(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_nb_inplace_add(space, w_obj1, w_obj2):
    return space.add(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_nb_inplace_subtract(space, w_obj1, w_obj2):
    return space.sub(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_nb_inplace_multiply(space, w_obj1, w_obj2):
    return space.mul(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_nb_inplace_divide(space, w_obj1, w_obj2):
    return space.div(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_sq_concat(space, w_obj1, w_obj2):
    return space.add(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_sq_inplace_concat(space, w_obj1, w_obj2):
    return space.add(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_mp_subscript(space, w_obj1, w_obj2):
    return space.getitem(w_obj1, w_obj2)

@slot_function([PyObject, PyObject], PyObject)
def slot_tp_getattr_hook(space, w_obj1, w_obj2):
    return space.getattr(w_obj1, w_obj2)

@slot_function([PyObject, PyObject, PyObject], PyObject)
def slot_tp_descr_get(space, w_self, w_obj, w_type):
    if w_obj is None:
        w_obj = space.w_None
    return space.get(w_self, w_obj, w_type)

@slot_function([PyObject, PyObject, PyObject], rffi.INT_real, error=-1)
def slot_tp_descr_set(space, w_self, w_obj, w_value):
    if w_value is not None:
        space.set(w_self, w_obj, w_value)
    else:
        space.delete(w_self, w_obj)
    return 0

@slot_function([PyObject], PyObject)
def slot_tp_iter(space, w_self):
    return space.iter(w_self)

@slot_function([PyObject], PyObject)
def slot_tp_iternext(space, w_self):
    return space.next(w_self)

@slot_function([PyObject], PyObject)
def slot_am_await(space, w_self):
    w_await = space.lookup(w_self, "__await__")
    if w_await is None:
        raise oefmt(space.w_TypeError,
            "object %T does not have __await__ method", w_self)
    return space.get_and_call_function(w_await, w_self)

@slot_function([PyObject], PyObject)
def slot_am_aiter(space, w_self):
    w_aiter = space.lookup(w_self, "__aiter__")
    if w_aiter is None:
        raise oefmt(space.w_TypeError,
            "object %T does not have __aiter__ method", w_self)
    return space.get_and_call_function(w_aiter, w_self)

@slot_function([PyObject], PyObject)
def slot_am_anext(space, w_self):
    w_anext = space.lookup(w_self, "__anext__")
    if w_anext is None:
        raise oefmt(space.w_TypeError,
            "object %T does not have __anext__ method", w_self)
    return space.get_and_call_function(w_anext, w_self)
