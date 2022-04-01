import os
from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.interpreter.error import OperationError, oefmt
import pypy.module.__builtin__.operation as operation
from pypy.objspace.std.bytesobject import invoke_bytes_method
from pypy.module._hpy_universal.apiset import API
from . import llapi

HPy_RichCmpOp = llapi.cts.gettype('HPy_RichCmpOp')

@API.func("int HPy_IsTrue(HPyContext *ctx, HPy h)", error_value=API.int(-1))
def HPy_IsTrue(space, handles, ctx, h_obj):
    w_obj = handles.deref(h_obj)
    return API.int(space.is_true(w_obj))

@API.func("HPy HPy_GetAttr(HPyContext *ctx, HPy obj, HPy h_name)")
def HPy_GetAttr(space, handles, ctx, h_obj, h_name):
    w_obj = handles.deref(h_obj)
    w_name = handles.deref(h_name)
    w_res = space.getattr(w_obj, w_name)
    return handles.new(w_res)

@API.func("HPy HPy_GetAttr_s(HPyContext *ctx, HPy h_obj, const char *name)")
def HPy_GetAttr_s(space, handles, ctx, h_obj, name):
    w_obj = handles.deref(h_obj)
    w_name = API.ccharp2text(space, name)
    w_res = space.getattr(w_obj, w_name)
    return handles.new(w_res)


@API.func("int HPy_HasAttr(HPyContext *ctx, HPy h_obj, HPy h_name)",
          error_value='CANNOT_FAIL')
def HPy_HasAttr(space, handles, ctx, h_obj, h_name):
    w_obj = handles.deref(h_obj)
    w_name = handles.deref(h_name)
    return _HasAttr(space, w_obj, w_name)

@API.func("int HPy_HasAttr_s(HPyContext *ctx, HPy h_obj, const char *name)",
          error_value='CANNOT_FAIL')
def HPy_HasAttr_s(space, handles, ctx, h_obj, name):
    w_obj = handles.deref(h_obj)
    w_name = API.ccharp2text(space, name)
    return _HasAttr(space, w_obj, w_name)

def _HasAttr(space, w_obj, w_name):
    try:
        w_res = operation.hasattr(space, w_obj, w_name)
        return API.int(space.is_true(w_res))
    except OperationError:
        return API.int(0)


@API.func("int HPy_SetAttr(HPyContext *ctx, HPy h_obj, HPy h_name, HPy h_value)",
          error_value=API.int(-1))
def HPy_SetAttr(space, handles, ctx, h_obj, h_name, h_value):
    w_obj = handles.deref(h_obj)
    w_name = handles.deref(h_name)
    w_value = handles.deref(h_value)
    operation.setattr(space, w_obj, w_name, w_value)
    return API.int(0)

@API.func("int HPy_SetAttr_s(HPyContext *ctx, HPy h_obj, const char *name, HPy h_value)",
          error_value=API.int(-1))
def HPy_SetAttr_s(space, handles, ctx, h_obj, name, h_value):
    w_obj = handles.deref(h_obj)
    w_name = API.ccharp2text(space, name)
    w_value = handles.deref(h_value)
    operation.setattr(space, w_obj, w_name, w_value)
    return API.int(0)


@API.func("int HPyCallable_Check(HPyContext *ctx, HPy h)", error_value='CANNOT_FAIL')
def HPyCallable_Check(space, handles, ctx, h_obj):
    w_obj = handles.deref(h_obj)
    return API.int(space.is_true(space.callable(w_obj)))


@API.func("HPy HPy_GetItem(HPyContext *ctx, HPy h_obj, HPy h_key)")
def HPy_GetItem(space, handles, ctx, h_obj, h_key):
    w_obj = handles.deref(h_obj)
    w_key = handles.deref(h_key)
    w_res = space.getitem(w_obj, w_key)
    return handles.new(w_res)

@API.func("HPy HPy_GetItem_i(HPyContext *ctx, HPy h_obj, HPy_ssize_t idx)")
def HPy_GetItem_i(space, handles, ctx, h_obj, idx):
    w_obj = handles.deref(h_obj)
    w_key = space.newint(idx)
    w_res = space.getitem(w_obj, w_key)
    return handles.new(w_res)

@API.func("HPy HPy_GetItem_s(HPyContext *ctx, HPy h_obj, const char *key)")
def HPy_GetItem_s(space, handles, ctx, h_obj, key):
    w_obj = handles.deref(h_obj)
    w_key = API.ccharp2text(space, key)
    w_res = space.getitem(w_obj, w_key)
    return handles.new(w_res)


@API.func("int HPy_SetItem(HPyContext *ctx, HPy h_obj, HPy h_key, HPy h_val)",
          error_value=API.int(-1))
def HPy_SetItem(space, handles, ctx, h_obj, h_key, h_val):
    w_obj = handles.deref(h_obj)
    w_key = handles.deref(h_key)
    w_val = handles.deref(h_val)
    space.setitem(w_obj, w_key, w_val)
    return API.int(0)

@API.func("int HPy_SetItem_i(HPyContext *ctx, HPy h_obj, HPy_ssize_t idx, HPy h_val)",
          error_value=API.int(-1))
def HPy_SetItem_i(space, handles, ctx, h_obj, idx, h_val):
    w_obj = handles.deref(h_obj)
    w_key = space.newint(idx)
    w_val = handles.deref(h_val)
    space.setitem(w_obj, w_key, w_val)
    return API.int(0)

@API.func("int HPy_SetItem_s(HPyContext *ctx, HPy h_obj, const char *key, HPy h_val)",
          error_value=API.int(-1))
def HPy_SetItem_s(space, handles, ctx, h_obj, key, h_val):
    w_obj = handles.deref(h_obj)
    w_key = API.ccharp2text(space, key)
    w_val = handles.deref(h_val)
    space.setitem(w_obj, w_key, w_val)
    return API.int(0)

@API.func("HPy HPy_Repr(HPyContext *ctx, HPy h_obj)")
def HPy_Repr(space, handles, ctx, h_obj):
    # XXX: cpyext checks and returns <NULL>. Add a test to HPy and fix here
    w_obj = handles.deref(h_obj)
    w_res = space.repr(w_obj)
    return handles.new(w_res)

@API.func("HPy HPy_Str(HPyContext *ctx, HPy h_obj)")
def HPy_Str(space, handles, ctx, h_obj):
    # XXX: cpyext checks and returns <NULL>. Add a test to HPy and fix here
    w_obj = handles.deref(h_obj)
    w_res = space.str(w_obj)
    return handles.new(w_res)

@API.func("HPy HPy_ASCII(HPyContext *ctx, HPy h_obj)")
def HPy_ASCII(space, handles, ctx, h_obj):
    w_obj = handles.deref(h_obj)
    w_res = operation.ascii(space, w_obj)
    return handles.new(w_res)

@API.func("HPy HPy_Bytes(HPyContext *ctx, HPy h_obj)")
def HPy_Bytes(space, handles, ctx, h_obj):
    # XXX: cpyext checks and returns <NULL>. Add a test to HPy and fix here
    w_obj = handles.deref(h_obj)
    if space.type(w_obj) is space.w_bytes:
        # XXX write a test for this case
        return handles.dup(h_obj)
    w_result = invoke_bytes_method(space, w_obj)
    if w_result is not None:
        return handles.new(w_result)
    # return PyBytes_FromObject(space, w_obj)
    # XXX: write a test for this case
    buffer = space.buffer_w(w_obj, space.BUF_FULL_RO)
    w_res = space.newbytes(buffer.as_str())
    return handles.new(w_res)

@API.func("HPy HPy_RichCompare(HPyContext *ctx, HPy v, HPy w, int op)")
def HPy_RichCompare(space, handles, ctx, v, w, op):
    w_o1 = handles.deref(v)
    w_o2 = handles.deref(w)
    w_result = rich_compare(space, w_o1, w_o2, op)
    return handles.new(w_result)

def rich_compare(space, w_o1, w_o2, opid_int):
    opid = rffi.cast(lltype.Signed, opid_int)
    if opid == HPy_RichCmpOp.HPy_LT:
        return space.lt(w_o1, w_o2)
    elif opid == HPy_RichCmpOp.HPy_LE:
        return space.le(w_o1, w_o2)
    elif opid == HPy_RichCmpOp.HPy_EQ:
        return space.eq(w_o1, w_o2)
    elif opid == HPy_RichCmpOp.HPy_NE:
        return space.ne(w_o1, w_o2)
    elif opid == HPy_RichCmpOp.HPy_GT:
        return space.gt(w_o1, w_o2)
    elif opid == HPy_RichCmpOp.HPy_GE:
        return space.ge(w_o1, w_o2)
    else:
        raise oefmt(space.w_SystemError, "Bad internal call!")


@API.func("int HPy_RichCompareBool(HPyContext *ctx, HPy v, HPy w, int op)",
          error_value=API.int(-1))
def HPy_RichCompareBool(space, handles, ctx, v, w, op):
    w_o1 = handles.deref(v)
    w_o2 = handles.deref(w)
    # Quick result when objects are the same.
    # Guarantees that identity implies equality.
    if space.is_w(w_o1, w_o2):
        opid = rffi.cast(lltype.Signed, op)
        if opid == HPy_RichCmpOp.HPy_EQ:
            return API.int(1)
        if opid == HPy_RichCmpOp.HPy_NE:
            return API.int(0)
    w_result = rich_compare(space, w_o1, w_o2, op)
    return API.int(space.is_true(w_result))

@API.func("HPy_hash_t HPy_Hash(HPyContext *ctx, HPy obj)", error_value=-1)
def HPy_Hash(space, handles, ctx, h_obj):
    w_obj = handles.deref(h_obj)
    return API.cts.cast('HPy_hash_t', space.hash_w(w_obj))

@API.func("HPy_ssize_t HPy_Length(HPyContext *ctx, HPy h)", error_value=-1)
def HPy_Length(space, handles, ctx, h_obj):
    w_obj = handles.deref(h_obj)
    return space.len_w(w_obj)

@API.func("HPy HPy_Type(HPyContext *ctx, HPy obj)")
def HPy_Type(space, handles, ctx, h_obj):
    w_obj = handles.deref(h_obj)
    return handles.new(space.type(w_obj))

@API.func("int HPy_TypeCheck(HPyContext *ctx, HPy obj, HPy type)",
          error_value='CANNOT_FAIL')
def HPy_TypeCheck(space, handles, ctx, h_obj, h_type):
    w_obj = handles.deref(h_obj)
    w_type = handles.deref(h_type)
    assert space.isinstance_w(w_type, space.w_type)
    return API.int(space.issubtype_w(space.type(w_obj), w_type))

@API.func("int HPy_Is(HPyContext *ctx, HPy obj, HPy other)",
          error_value='CANNOT_FAIL')
def HPy_Is(space, handles, ctx, h_obj, h_other):
    w_obj = handles.deref(h_obj)
    w_other = handles.deref(h_other)
    return API.int(space.is_w(w_obj, w_other))

@API.func("void _HPy_Dump(HPyContext *ctx, HPy h)")
def _HPy_Dump(space, handles, ctx, h_obj):
    # this is a debugging helper meant to be called from gdb. As such, we
    # write directly to stderr, bypassing sys.stderr&co.
    stderr = 2
    w_obj = handles.deref(h_obj)
    w_type = space.type(w_obj)
    os.write(stderr, "object type     : %r\n" % (w_type,))
    os.write(stderr, "object type name: %s\n" % (w_type.name,))
    os.write(stderr, "object rpy repr : %r\n" % (w_obj,))
    w_repr = space.repr(w_obj)
    s = space.text_w(w_repr)
    os.write(stderr, "object repr     : %s\n" % (s,))
