import weakref
from rpython.rlib import jit
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import oefmt
from pypy.interpreter.executioncontext import ExecutionContext
from pypy.interpreter.typedef import (TypeDef, interp2app, GetSetProperty,
    descr_get_dict, make_weakref_descr)
from rpython.rlib.rshrinklist import AbstractShrinkList


class WRefShrinkList(AbstractShrinkList):
    def must_keep(self, wref):
        return wref() is not None


ExecutionContext._thread_local_objs = None
ExecutionContext._sentinel_lock = None


class Local(W_Root):
    """Thread-local data"""

    @jit.dont_look_inside
    def __init__(self, space, initargs):
        self.initargs = initargs
        self.dicts = {}   # mapping ExecutionContexts to the wraped dict
        # The app-level __init__() will be called by the general
        # instance-creation logic.  It causes getdict() to be
        # immediately called.  If we don't prepare and set a w_dict
        # for the current thread, then this would in cause getdict()
        # to call __init__() a second time.
        ec = space.getexecutioncontext()
        w_dict = space.newdict(instance=True)
        self.dicts[ec] = w_dict
        self._register_in_ec(ec)
        # cache the last seen dict, works because we are protected by the GIL
        self.last_dict = w_dict
        self.last_ec = ec

    def _register_in_ec(self, ec):
        if not ec.space.config.translation.rweakref:
            return    # without weakrefs, works but 'dicts' is never cleared
        if ec._thread_local_objs is None:
            ec._thread_local_objs = WRefShrinkList()
        ec._thread_local_objs.append(weakref.ref(self))

    @jit.dont_look_inside
    def create_new_dict(self, ec):
        # create a new dict for this thread
        space = ec.space
        w_dict = space.newdict(instance=True)
        self.dicts[ec] = w_dict
        # call __init__
        try:
            w_type = space.type(self)
            w_init = space.getattr(w_type, space.newtext("__init__"))
            space.call_obj_args(w_init, self, self.initargs)
        except:
            # failed, forget w_dict and propagate the exception
            del self.dicts[ec]
            raise
        # ready
        self._register_in_ec(ec)
        return w_dict

    def getdict(self, space):
        ec = space.getexecutioncontext()
        if ec is self.last_ec:
            return self.last_dict
        try:
            w_dict = self.dicts[ec]
        except KeyError:
            w_dict = self.create_new_dict(ec)
        self.last_ec = ec
        self.last_dict = w_dict
        return w_dict

    def descr_local__new__(space, w_subtype, __args__):
        from pypy.objspace.std.typeobject import _precheck_for_new
        w_subtype = _precheck_for_new(space, w_subtype)
        if __args__.arguments_w or __args__.keyword_names_w:
            w_parent_init, _ = space.lookup_in_type_where(w_subtype, '__init__')
            if w_parent_init is space.w_object:
                raise oefmt(space.w_TypeError,
                            "Initialization arguments are not supported")
        local = space.allocate_instance(Local, w_subtype)
        Local.__init__(local, space, __args__)
        return local

Local.typedef = TypeDef("_thread._local",
                        __doc__ = "Thread-local data",
                        __new__ = interp2app(Local.descr_local__new__.im_func),
                        __dict__ = GetSetProperty(descr_get_dict, cls=Local),
                        __weakref__ = make_weakref_descr(Local),
                        )

def thread_is_stopping(ec):
    sentinel_lock = ec._sentinel_lock
    if sentinel_lock is not None:
        if sentinel_lock.lock.is_acquired():
            sentinel_lock.descr_lock_release(ec.space)
    tlobjs = ec._thread_local_objs
    if tlobjs is None:
        return
    ec._thread_local_objs = None
    for wref in tlobjs.items():
        local = wref()
        if local is not None:
            del local.dicts[ec]
            local.last_dict = None
            local.last_ec = None
