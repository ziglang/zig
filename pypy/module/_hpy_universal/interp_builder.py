from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.debug import make_sure_not_resized
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.objspace.std.listobject import W_ListObject
from pypy.module._hpy_universal.apiset import API

# ~~~ HPyListBuilder ~~~

# note that ListBuilder does not necessarily need to be a W_Root: the object
# is never diretly exposed to the user, because the C HPyListBuilder type is
# basically an opaque integer. However, by making it a W_Root, we can just
# (re)use HandleManager to get this unique index.
class W_ListBuilder(W_Root):
    def __init__(self, initial_size):
        self.items_w = [None] * initial_size

@API.func("HPyListBuilder HPyListBuilder_New(HPyContext *ctx, HPy_ssize_t initial_size)",
          error_value=0)
def HPyListBuilder_New(space, handles, ctx, initial_size):
    w_builder = W_ListBuilder(initial_size)
    h = handles.new(w_builder)
    return h

@API.func("void HPyListBuilder_Set(HPyContext *ctx, HPyListBuilder builder, HPy_ssize_t index, HPy h_item)")
def HPyListBuilder_Set(space, handles, ctx, builder, index, h_item):
    # XXX if builder==0, there was an error inside _New. The C code just exits
    # here, but there is no tests for it. Write it
    w_builder = handles.deref(builder)
    assert isinstance(w_builder, W_ListBuilder)
    w_item = handles.deref(h_item)
    w_builder.items_w[index] = w_item

@API.func("HPy HPyListBuilder_Build(HPyContext *ctx, HPyListBuilder builder)")
def HPyListBuilder_Build(space, handles, ctx, builder):
    w_builder = handles.deref(builder)
    assert isinstance(w_builder, W_ListBuilder)
    w_list = space.newlist(w_builder.items_w)
    return handles.new(w_list)

@API.func("void HPyListBuilder_Cancel(HPyContext *ctx, HPyListBuilder builder)")
def HPyListBuilder_Cancel(space, handles, ctx, builder):
    # XXX write a test
    from rpython.rlib.nonconst import NonConstant # for the annotator
    if NonConstant(False): return
    raise NotImplementedError


# ~~~ HPyTupleBuilder ~~~

class W_TupleBuilder(W_Root):
    def __init__(self, initial_size):
        self.items_w = [None] * initial_size
        make_sure_not_resized(self.items_w)

@API.func("HPyTupleBuilder HPyTupleBuilder_New(HPyContext *ctx, HPy_ssize_t initial_size)",
          error_value=0)
def HPyTupleBuilder_New(space, handles, ctx, initial_size):
    w_builder = W_TupleBuilder(initial_size)
    h = handles.new(w_builder)
    return h

@API.func("void HPyTupleBuilder_Set(HPyContext *ctx, HPyTupleBuilder builder, HPy_ssize_t index, HPy h_item)")
def HPyTupleBuilder_Set(space, handles, ctx, builder, index, h_item):
    # XXX if builder==0, there was an error inside _New. The C code just exits
    # here, but there is no tests for it. Write it
    w_builder = handles.deref(builder)
    assert isinstance(w_builder, W_TupleBuilder)
    w_item = handles.deref(h_item)
    w_builder.items_w[index] = w_item

@API.func("HPy HPyTupleBuilder_Build(HPyContext *ctx, HPyTupleBuilder builder)")
def HPyTupleBuilder_Build(space, handles, ctx, builder):
    w_builder = handles.deref(builder)
    assert isinstance(w_builder, W_TupleBuilder)
    w_tuple = space.newtuple(w_builder.items_w)
    return handles.new(w_tuple)

@API.func("void HPyTupleBuilder_Cancel(HPyContext *ctx, HPyTupleBuilder builder)")
def HPyTupleBuilder_Cancel(space, handles, ctx, builder):
    # XXX write a test
    from rpython.rlib.nonconst import NonConstant # for the annotator
    if NonConstant(False): return
    raise NotImplementedError

