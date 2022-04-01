from .apiset import API

@API.func('HPy HPyTuple_FromArray(HPyContext *ctx, HPy items[], HPy_ssize_t n)')
def HPyTuple_FromArray(space, handles, ctx, items, n):
    items_w = [None] * n
    for i in range(n):
        items_w[i] = handles.deref(items[i])
    w_result = space.newtuple(items_w)
    return handles.new(w_result)

@API.func("int HPyTuple_Check(HPyContext *ctx, HPy h)", error_value='CANNOT_FAIL')
def HPyTuple_Check(space, handles, ctx, h):
    w_obj = handles.deref(h)
    w_obj_type = space.type(w_obj)
    res = (space.is_w(w_obj_type, space.w_tuple) or
           space.issubtype_w(w_obj_type, space.w_tuple))
    return API.int(res)
