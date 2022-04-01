""" transparent.py - Several transparent proxy helpers
"""
from pypy.interpreter import gateway
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.typedef import Function, GeneratorIterator, PyTraceback, \
    PyFrame, PyCode
from pypy.objspace.std.proxyobject import W_Transparent, W_TransparentBaseException
from pypy.objspace.std.typeobject import W_TypeObject
from pypy.module.exceptions import interp_exceptions
from rpython.rlib.unroll import unrolling_iterable


class W_TransparentFunction(W_Transparent):
    typedef = Function.typedef

class W_TransparentTraceback(W_Transparent):
    typedef = PyTraceback.typedef

class W_TransparentCode(W_Transparent):
    typedef = PyCode.typedef

class W_TransparentFrame(W_Transparent):
    typedef = PyFrame.typedef

class W_TransparentGenerator(W_Transparent):
    typedef = GeneratorIterator.typedef


class TypeCache(object):
    def __init__(self):
        self.cache = []

    def _freeze_(self):
        self.cache = unrolling_iterable(self.cache)
        return True

type_cache = TypeCache()


def setup(space):
    """Add proxy functions to the __pypy__ module."""
    w___pypy__ = space.getbuiltinmodule("__pypy__")
    space.setattr(w___pypy__, space.newtext('tproxy'), app_proxy.spacebind(space))
    space.setattr(w___pypy__, space.newtext('get_tproxy_controller'),
                  app_proxy_controller.spacebind(space))


def proxy(space, w_type, w_controller):
    """tproxy(typ, controller) -> obj
Return something that looks like it is of type typ. Its behaviour is
completely controlled by the controller."""
    if not space.is_true(space.callable(w_controller)):
        raise oefmt(space.w_TypeError, "controller should be function")

    if isinstance(w_type, W_TypeObject):
        if space.issubtype_w(w_type, space.gettypeobject(Function.typedef)):
            return W_TransparentFunction(space, w_type, w_controller)
        if space.issubtype_w(w_type, space.gettypeobject(PyTraceback.typedef)):
            return W_TransparentTraceback(space, w_type, w_controller)
        if space.issubtype_w(w_type, space.gettypeobject(PyFrame.typedef)):
            return W_TransparentFrame(space, w_type, w_controller)
        if space.issubtype_w(w_type, space.gettypeobject(GeneratorIterator.typedef)):
            return W_TransparentGenerator(space, w_type, w_controller)
        if space.issubtype_w(w_type, space.gettypeobject(PyCode.typedef)):
            return W_TransparentCode(space, w_type, w_controller)
        if space.issubtype_w(w_type, space.gettypeobject(interp_exceptions.W_BaseException.typedef)):
            return W_TransparentBaseException(space, w_type, w_controller)
        if w_type.layout.typedef is space.w_object.layout.typedef:
            return W_Transparent(space, w_type, w_controller)
    else:
        raise oefmt(space.w_TypeError, "type expected as first argument")
    w_lookup = w_type
    for k, v in type_cache.cache:
        if w_lookup == k:
            return v(space, w_type, w_controller)
    raise oefmt(space.w_TypeError, "'%N' object could not be wrapped", w_type)

def register_proxyable(space, cls):
    tpdef = cls.typedef
    class W_TransparentUserCreated(W_Transparent):
        typedef = tpdef
    type_cache.cache.append((space.gettypeobject(tpdef), W_TransparentUserCreated))

def proxy_controller(space, w_object):
    """get_tproxy_controller(obj) -> controller
If obj is really a transparent proxy, return its controller. Otherwise return
None."""
    if isinstance(w_object, W_Transparent):
        return w_object.w_controller
    #if isinstance(w_object, W_TransparentObject):
    #    return w_object.w_controller
    return None

app_proxy = gateway.interp2app(proxy)
app_proxy_controller = gateway.interp2app(proxy_controller)
