from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.interpreter.error import OperationError, oefmt
from pypy.objspace.std.dictmultiobject import W_DictMultiObject
from pypy.module._hpy_universal.apiset import API
from pypy.module._hpy_universal import llapi

@API.func("HPy HPyDict_New(HPyContext *ctx)")
def HPyDict_New(space, handles, ctx):
    w_dict = space.newdict()
    return handles.new(w_dict)

@API.func("int HPyDict_Check(HPyContext *ctx, HPy h)", error_value='CANNOT_FAIL')
def HPyDict_Check(space, handles, ctx, h):
    w_obj = handles.deref(h)
    w_obj_type = space.type(w_obj)
    res = (space.is_w(w_obj_type, space.w_dict) or
           space.issubtype_w(w_obj_type, space.w_dict))
    return API.int(res)
