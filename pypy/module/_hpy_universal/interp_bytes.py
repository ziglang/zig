from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import rutf8
from pypy.interpreter.error import OperationError, oefmt
from pypy.module._hpy_universal.apiset import API
from pypy.module._hpy_universal.handlemanager import FreeNonMovingBuffer

@API.func("int HPyBytes_Check(HPyContext *ctx, HPy h)", error_value='CANNOT_FAIL')
def HPyBytes_Check(space, handles, ctx, h):
    w_obj = handles.deref(h)
    w_obj_type = space.type(w_obj)
    res = (space.is_w(w_obj_type, space.w_bytes) or
           space.issubtype_w(w_obj_type, space.w_bytes))
    return API.int(res)

@API.func("HPy_ssize_t HPyBytes_Size(HPyContext *ctx, HPy h)", error_value=-1)
def HPyBytes_Size(space, handles, ctx, h):
    w_obj = handles.deref(h)
    return space.len_w(w_obj)

@API.func("HPy_ssize_t HPyBytes_GET_SIZE(HPyContext *ctx, HPy h)", error_value=-1)
def HPyBytes_GET_SIZE(space, handles, ctx, h):
    return HPyBytes_Size(space, handles, ctx, h)

@API.func("char *HPyBytes_AsString(HPyContext *ctx, HPy h)")
def HPyBytes_AsString(space, handles, ctx, h):
    w_obj = handles.deref(h)
    s = space.bytes_w(w_obj)
    return handles.str2ownedptr(s, owner=h)

@API.func("char *HPyBytes_AS_STRING(HPyContext *ctx, HPy h)")
def HPyBytes_AS_STRING(space, handles, ctx, h):
    return HPyBytes_AsString(space, handles, ctx, h)

@API.func("HPy HPyBytes_FromString(HPyContext *ctx, const char *v)")
def HPyBytes_FromString(space, handles, ctx, char_p):
    s = rffi.constcharp2str(char_p)
    w_bytes = space.newbytes(s)
    return handles.new(w_bytes)

@API.func("HPy HPyBytes_FromStringAndSize(HPyContext *ctx, const char *v, HPy_ssize_t len)")
def HPyBytes_FromStringAndSize(space, handles, ctx, char_p, length):
    if not char_p:
        raise oefmt(
            space.w_ValueError,
            "NULL char * passed to HPyBytes_FromStringAndSize"
        )
    if length < 0:
        raise oefmt(space.w_SystemError,
                    "Negative size passed to PyBytes_FromStringAndSize")
    s = rffi.constcharpsize2str(char_p, length)
    w_bytes = space.newbytes(s)
    return handles.new(w_bytes)
