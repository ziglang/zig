"""

application level support module for transparent proxies.

"""
from __pypy__ import tproxy
from types import MethodType

_dummy = object()
origtype = type

def make_proxy(controller, type=_dummy, obj=_dummy):
    """ return a tranparent proxy controlled by the given
        'controller' callable.  The proxy will appear
        as a completely regular instance of the given
        type but all operations on it are send to the
        specified controller - which receives on
        ProxyOperation instance on each such call.
        A non-specified type will default to type(obj)
        if obj is specified.
    """
    if type is _dummy:
        if obj is _dummy:
            raise TypeError("you must specify a type or an instance obj of it")
        type = origtype(obj)
    def perform(opname, *args, **kwargs):
        operation = ProxyOperation(tp, obj, opname, args, kwargs)
        return controller(operation)
    tp = tproxy(type, perform)
    return tp

class ProxyOperation(object):
    def __init__(self, proxyobj, obj, opname, args, kwargs):
        self.proxyobj = proxyobj
        self.opname = opname
        self.args = args
        self.kwargs = kwargs
        if obj is not _dummy:
            self.obj = obj

    def delegate(self):
        """ return result from delegating this operation to the
            underyling self.obj - which must exist and is usually
            provided through the initial make_proxy(..., obj=...)
            creation.
        """
        try:
            obj = getattr(self, 'obj')
        except AttributeError:
            raise TypeError("proxy does not have an underlying 'obj', "
                            "cannot delegate")
        objattr = getattr(obj, self.opname)
        res = objattr(*self.args, **self.kwargs)
        if self.opname == "__getattribute__":
            if (isinstance(res, MethodType) and
                res.__self__ is self.instance):
                res = MethodType(res.__func__, self.proxyobj, res.__self__.__class__)
        if res is self.obj:
            res = self.proxyobj
        return res

    def __repr__(self):
        args = ", ".join([repr(x) for x in self.args])
        args = "<0x%x>, " % id(self.proxyobj) + args
        if self.kwargs:
            args += ", ".join(["%s=%r" % item
                                  for item in self.kwargs.items()])
        return "<ProxyOperation %s.%s(%s)>" %(
                    type(self.proxyobj).__name__, self.opname, args)
