from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.objectmodel import newlist_hint
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.module._hpy_universal.apiset import API

class W_Tracker(W_Root):
    def __init__(self, size):
        self.hlist = newlist_hint(size)

    def add(self, h):
        self.hlist.append(h)

    def forget_all(self):
        self.hlist = []

    def close(self, handles):
        for h in self.hlist:
            handles.close(h)

@API.func("HPyTracker HPyTracker_New(HPyContext *ctx, HPy_ssize_t size)", error_value=0)
def HPyTracker_New(space, handles, ctx, size):
    w_tracker = W_Tracker(size)
    return handles.new(w_tracker)

@API.func("int HPyTracker_Add(HPyContext *ctx, HPyTracker ht, HPy h)",
          error_value=API.int(-1))
def HPyTracker_Add(space, handles, ctx, ht, h):
    w_tracker = handles.deref(ht)
    assert isinstance(w_tracker, W_Tracker)
    w_tracker.add(h)
    return API.int(0)

@API.func("void HPyTracker_ForgetAll(HPyContext *ctx, HPyTracker ht)")
def HPyTracker_ForgetAll(space, handles, ctx, ht):
    w_tracker = handles.deref(ht)
    assert isinstance(w_tracker, W_Tracker)
    w_tracker.forget_all()

@API.func("void HPyTracker_Close(HPyContext *ctx, HPyTracker ht)")
def HPyTracker_Close(space, handles, ctx, ht):
    w_tracker = handles.deref(ht)
    assert isinstance(w_tracker, W_Tracker)
    w_tracker.close(handles)
    handles.close(ht)
