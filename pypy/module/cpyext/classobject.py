from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.api import CANNOT_FAIL, cpython_api
from pypy.module.cpyext.pyobject import PyObject
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.function import Method
from pypy.interpreter.typedef import TypeDef, interp_attrproperty_w, GetSetProperty
from pypy.interpreter.gateway import interp2app


class InstanceMethod(W_Root):
    """The instancemethod facade."""
    _immutable_fields_ = ['w_function']

    def __init__(self, w_function):
        self.w_function = w_function

    def fget_name(self, space):
        return space.getattr(self.w_function, space.newtext("__name__"))

    def fget_module(self, space):
        return space.getattr(self.w_function, space.newtext("__module__"))

    def fget_docstring(self, space):
        return space.getattr(self.w_function, space.newtext("__doc__"))

    @staticmethod
    def descr_new(space, w_subtype, w_function):
        # instancemethod is not subclassable
        return InstanceMethod(w_function)

    def descr_get(self, space, w_obj, w_klass=None):
        if space.is_none(w_obj):
            return self.w_function
        return Method(space, self.w_function, w_obj)

    def descr_call(self, space, __args__):
        return space.call_args(self.w_function, __args__)

    def descr_repr(self, space):
        return self.getrepr(space, '<instancemethod %s>' %
                            (self.w_function.getname(space),))

InstanceMethod.typedef = TypeDef(
    "cinstancemethod",
    __new__ = interp2app(InstanceMethod.descr_new),
    __call__ = interp2app(InstanceMethod.descr_call,
                          descrmismatch='__call__'),
    __get__ = interp2app(InstanceMethod.descr_get),
    __repr__ = interp2app(InstanceMethod.descr_repr,
                          descrmismatch='__repr__'),
    __func__ = interp_attrproperty_w('w_function', cls=InstanceMethod),
    __name__ = GetSetProperty(InstanceMethod.fget_name, cls=InstanceMethod),
    __module__ = GetSetProperty(InstanceMethod.fget_module, cls=InstanceMethod),
    __doc__ = GetSetProperty(InstanceMethod.fget_docstring, cls=InstanceMethod),
)
InstanceMethod.typedef.acceptable_as_base_class = False

@cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
def PyInstanceMethod_Check(space, w_o):
    """Return true if o is an instance method object (has type
    PyInstanceMethod_Type).  The parameter must not be NULL."""
    return space.isinstance_w(w_o,
                              space.gettypeobject(InstanceMethod.typedef))
    

@cpython_api([PyObject], PyObject)
def PyInstanceMethod_New(space, w_func):
    """Return a new instance method object, with func being any
    callable object func is the function that will be called when the
    instance method is called."""
    return InstanceMethod(w_func)
    

@cpython_api([PyObject], PyObject)
def PyInstanceMethod_Function(space, w_im):
    """Return the function object associated with the instance method im."""
    return space.interp_w(InstanceMethod, w_im).w_function
    

@cpython_api([PyObject], PyObject)
def PyInstanceMethod_GET_FUNCTION(space, w_im):
    """Macro version of PyInstanceMethod_Function() which avoids error
    checking."""
    return space.interp_w(InstanceMethod, w_im).w_function
    
    if w_bases is None:
        w_bases = space.newtuple([])

