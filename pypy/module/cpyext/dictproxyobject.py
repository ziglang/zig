from pypy.objspace.std.dictproxyobject import W_DictProxyObject
from pypy.module.cpyext.api import cpython_api, build_type_checkers
from pypy.module.cpyext.pyobject import PyObject

PyDictProxy_Check, PyDictProxy_CheckExact = build_type_checkers(
    "DictProxy", W_DictProxyObject)

@cpython_api([PyObject], PyObject)
def PyDictProxy_New(space, w_dict):
    return W_DictProxyObject(w_dict)
