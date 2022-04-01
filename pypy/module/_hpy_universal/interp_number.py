from rpython.rlib.rarithmetic import widen
from pypy.module._hpy_universal.apiset import API

def make_unary(name, spacemeth):
    assert spacemeth.startswith('space.')
    spacemeth = spacemeth[len('space.'):]
    #
    @API.func("HPy HPy_unary(HPyContext *ctx, HPy h1)", func_name=name)
    def HPy_unary(space, handles, ctx, h1):
        w_obj1 = handles.deref(h1)
        meth = getattr(space, spacemeth)
        w_res = meth(w_obj1)
        return handles.new(w_res)
    #
    globals()[name] = HPy_unary

def make_binary(name, spacemeth):
    assert spacemeth.startswith('space.')
    spacemeth = spacemeth[len('space.'):]
    #
    @API.func("HPy HPy_binary(HPyContext *ctx, HPy h1, HPy h2)", func_name=name)
    def HPy_binary(space, handles, ctx, h1, h2):
        w_obj1 = handles.deref(h1)
        w_obj2 = handles.deref(h2)
        meth = getattr(space, spacemeth)
        w_res = meth(w_obj1, w_obj2)
        return handles.new(w_res)
    #
    globals()[name] = HPy_binary


make_unary('HPy_Negative', 'space.neg')
make_unary('HPy_Positive', 'space.pos')
make_unary('HPy_Absolute', 'space.abs')
make_unary('HPy_Invert', 'space.invert')
make_unary('HPy_Index', 'space.index')

make_binary('HPy_Add', 'space.add')
make_binary('HPy_Subtract', 'space.sub')
make_binary('HPy_Multiply', 'space.mul')
make_binary('HPy_FloorDivide', 'space.floordiv')
make_binary('HPy_TrueDivide', 'space.truediv')
make_binary('HPy_Remainder', 'space.mod')
make_binary('HPy_Divmod', 'space.divmod')
make_binary('HPy_Lshift', 'space.lshift')
make_binary('HPy_Rshift', 'space.rshift')
make_binary('HPy_And', 'space.and_')
make_binary('HPy_Xor', 'space.xor')
make_binary('HPy_Or', 'space.or_')
make_binary('HPy_MatrixMultiply', 'space.matmul')

make_binary('HPy_InPlaceAdd', 'space.inplace_add')
make_binary('HPy_InPlaceSubtract', 'space.inplace_sub'),
make_binary('HPy_InPlaceMultiply', 'space.inplace_mul'),
make_binary('HPy_InPlaceFloorDivide', 'space.inplace_floordiv'),
make_binary('HPy_InPlaceTrueDivide', 'space.inplace_truediv'),
make_binary('HPy_InPlaceRemainder', 'space.inplace_mod'),
make_binary('HPy_InPlaceLshift', 'space.inplace_lshift'),
make_binary('HPy_InPlaceRshift', 'space.inplace_rshift'),
make_binary('HPy_InPlaceAnd', 'space.inplace_and'),
make_binary('HPy_InPlaceXor', 'space.inplace_xor'),
make_binary('HPy_InPlaceOr', 'space.inplace_or'),
make_binary('HPy_InPlaceMatrixMultiply', 'space.inplace_matmul')


@API.func("HPy HPy_Long(HPyContext *ctx, HPy h1)")
def HPy_Long(space, handles, ctx, h1):
    w_obj1 = handles.deref(h1)
    w_res = space.call_function(space.w_int, w_obj1)
    return handles.new(w_res)


@API.func("HPy HPy_Float(HPyContext *ctx, HPy h1)")
def HPy_Float(space, handles, ctx, h1):
    w_obj1 = handles.deref(h1)
    w_res = space.call_function(space.w_float, w_obj1)
    return handles.new(w_res)


@API.func("HPy HPy_Power(HPyContext *ctx, HPy h1, HPy h2, HPy h3)")
def HPy_Power(space, handles, ctx, h1, h2, h3):
    w_o1 = handles.deref(h1)
    w_o2 = handles.deref(h2)
    w_o3 = handles.deref(h3)
    w_res = space.pow(w_o1, w_o2, w_o3)
    return handles.new(w_res)


@API.func("HPy HPy_InPlacePower(HPyContext *ctx, HPy h1, HPy h2, HPy h3)")
def HPy_InPlacePower(space, handles, ctx, h1, h2, h3):
    # CPython seems to have a weird semantics for InPlacePower: if __ipow__ is
    # defined, the 3rd argument is always ignored (contrarily to what the
    # documentation says). If now, it falls back to pow, so the 3rd arg is
    # handled correctly. Here we try to be bug-to-bug compatible
    w_o1 = handles.deref(h1)
    w_o2 = handles.deref(h2)
    w_o3 = handles.deref(h3)
    w_ipow = space.lookup(w_o1, '__ipow__')
    if w_ipow is None:
        w_res = space.pow(w_o1, w_o2, w_o3)
    else:
        w_res = space.inplace_pow(w_o1, w_o2)
    return handles.new(w_res)

@API.func("int HPyNumber_Check(HPyContext *ctx, HPy h)", error_value='CANNOT_FAIL')
def HPyNumber_Check(space, handles, ctx, h):
    # XXX: write proper tests
    w_obj = handles.deref(h)
    if (space.lookup(w_obj, '__int__') or space.lookup(w_obj, '__float__') or
        0): # XXX in py3.8: space.lookup(w_obj, '__index__')):
        return API.int(1)
    return API.int(0)

@API.func("HPy HPyBool_FromLong(HPyContext *ctx, long v)")
def HPyBool_FromLong(space, handles, ctx, value):
    if widen(value) != 0:
        return handles.new(space.w_True)
    return handles.new(space.w_False)
