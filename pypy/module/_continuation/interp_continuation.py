from rpython.rlib.rstacklet import StackletThread
from rpython.rlib import jit
from rpython.rlib import rvmprof
from pypy.interpreter.error import OperationError, get_cleared_operation_error
from pypy.interpreter.error import oefmt
from pypy.interpreter.executioncontext import ExecutionContext
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.pycode import PyCode
from pypy.interpreter.pyframe import PyFrame


class W_Continulet(W_Root):
    sthread = None

    def __init__(self, space):
        self.space = space
        # states:
        #  - not init'ed: self.sthread == None
        #  - normal:      self.sthread != None, not is_empty_handle(self.h)
        #  - finished:    self.sthread != None, is_empty_handle(self.h)

    def check_sthread(self):
        ec = self.space.getexecutioncontext()
        if ec.stacklet_thread is not self.sthread:
            global_state.clear()
            raise geterror(self.space, "cannot switch to a different thread")

    def descr_init(self, w_callable, __args__):
        if self.sthread is not None:
            raise geterror(self.space, "continulet already __init__ialized")
        sthread = build_sthread(self.space)
        #
        # hackish: build the frame "by hand", passing it the correct arguments
        space = self.space
        w_args, w_kwds = __args__.topacked()
        bottomframe = space.createframe(get_entrypoint_pycode(space),
                                        get_w_module_dict(space), None)
        bottomframe.locals_cells_stack_w[0] = self
        bottomframe.locals_cells_stack_w[1] = w_callable
        bottomframe.locals_cells_stack_w[2] = w_args
        bottomframe.locals_cells_stack_w[3] = w_kwds
        bottomframe.last_exception = get_cleared_operation_error(space)
        self.bottomframe = bottomframe
        #
        global_state.origin = self
        self.sthread = sthread
        saved_exception = pre_switch(sthread)
        h = sthread.new(new_stacklet_callback)
        post_switch(sthread, h, saved_exception)

    def switch(self, w_to):
        sthread = self.sthread
        to = self.space.interp_w(W_Continulet, w_to, can_be_None=True)
        if to is not None and to.sthread is None:
            to = None
        if sthread is None:      # if self is non-initialized:
            if to is not None:   #     if we are given a 'to'
                self = to        #         then just use it and ignore 'self'
                sthread = self.sthread
                to = None
            else:
                return get_result()  # else: no-op
        if sthread is not None and sthread.is_empty_handle(self.h):
            global_state.clear()
            raise geterror(self.space, "continulet already finished")
        if to is not None:
            if to.sthread is not sthread:
                global_state.clear()
                raise geterror(self.space, "cross-thread double switch")
            if self is to:    # double-switch to myself: no-op
                return get_result()
            if sthread.is_empty_handle(to.h):
                global_state.clear()
                raise geterror(self.space, "continulet already finished")
        self.check_sthread()

        global_state.origin = self
        if to is None:
            # simple switch: going to self.h
            global_state.destination = self
        else:
            # double switch: the final destination is to.h
            global_state.destination = to
        #
        saved_exception = pre_switch(sthread)
        h = sthread.switch(global_state.destination.h)
        return post_switch(sthread, h, saved_exception)

    @unwrap_spec(w_value = WrappedDefault(None),
                 w_to = WrappedDefault(None))
    def descr_switch(self, w_value=None, w_to=None):
        global_state.w_value = w_value
        return self.switch(w_to)

    @unwrap_spec(w_val = WrappedDefault(None),
                 w_tb = WrappedDefault(None),
                 w_to = WrappedDefault(None))
    def descr_throw(self, w_type, w_val=None, w_tb=None, w_to=None):
        from pypy.interpreter.pytraceback import check_traceback
        space = self.space
        #
        msg = "throw() third argument must be a traceback object"
        if space.is_none(w_tb):
            tb = None
        else:
            tb = check_traceback(space, w_tb, msg)
        #
        operr = OperationError(w_type, w_val, tb)
        operr.normalize_exception(space)
        global_state.w_value = None
        global_state.propagate_exception = operr
        return self.switch(w_to)

    def descr_is_pending(self):
        valid = (self.sthread is not None
                 and not self.sthread.is_empty_handle(self.h))
        return self.space.newbool(valid)

    def descr__reduce__(self):
        raise oefmt(self.space.w_NotImplementedError,
                    "continulet's pickle support is currently disabled")
        from pypy.module._continuation import interp_pickle
        return interp_pickle.reduce(self)

    def descr__setstate__(self, w_args):
        # XXX: review direct calls to frame.run(), notably when
        # unpickling generators (or coroutines!)
        raise oefmt(self.space.w_NotImplementedError,
                    "continulet's pickle support is currently disabled")
        from pypy.module._continuation import interp_pickle
        interp_pickle.setstate(self, w_args)

    def descr_get_frame(self, space):
        if self.sthread is None:
            w_frame = space.w_False
        elif self.sthread.is_empty_handle(self.h):
            w_frame = space.w_None
        else:
            w_frame = self.bottomframe
        return w_frame


def W_Continulet___new__(space, w_subtype, __args__):
    r = space.allocate_instance(W_Continulet, w_subtype)
    r.__init__(space)
    return r

def unpickle(space, w_subtype):
    """Pickle support."""
    r = space.allocate_instance(W_Continulet, w_subtype)
    r.__init__(space)
    return r


W_Continulet.typedef = TypeDef(
    '_continuation.continulet',
    __new__     = interp2app(W_Continulet___new__),
    __init__    = interp2app(W_Continulet.descr_init),
    switch      = interp2app(W_Continulet.descr_switch),
    throw       = interp2app(W_Continulet.descr_throw),
    is_pending  = interp2app(W_Continulet.descr_is_pending),
    __reduce__  = interp2app(W_Continulet.descr__reduce__),
    __setstate__= interp2app(W_Continulet.descr__setstate__),
    _get_frame=interp2app(W_Continulet.descr_get_frame)
    )

# ____________________________________________________________

# Continulet objects maintain a dummy frame object in order to ensure
# that the 'f_back' chain is consistent.  We hide this dummy frame
# object by giving it a dummy code object with hidden_applevel=True.

class State:
    def __init__(self, space):
        self.space = space
        w_module = space.getbuiltinmodule('_continuation')
        self.w_error = space.getattr(w_module, space.newtext('error'))
        # the following function switches away immediately, so that
        # continulet.__init__() doesn't immediately run func(), but it
        # also has the hidden purpose of making sure we have a single
        # bottomframe for the whole duration of the continulet's run.
        # Hackish: only the func_code is used, and used in the context
        # of w_globals == this module, so we can access the name
        # 'continulet' directly.
        w_code = space.appexec([], '''():
            def start(c, func, args, kwds):
                if continulet.switch(c) is not None:
                    raise TypeError(
                     "can\'t send non-None value to a just-started continulet")
                return func(c, *args, **kwds)
            return start.__code__
        ''')
        self.entrypoint_pycode = space.interp_w(PyCode, w_code)
        self.entrypoint_pycode.hidden_applevel = True
        self.w_unpickle = w_module.get('_p')
        self.w_module_dict = w_module.getdict(space)

def geterror(space, message):
    cs = space.fromcache(State)
    return OperationError(cs.w_error, space.newtext(message))

def get_entrypoint_pycode(space):
    cs = space.fromcache(State)
    return cs.entrypoint_pycode

def get_w_module_dict(space):
    cs = space.fromcache(State)
    return cs.w_module_dict

# ____________________________________________________________


class SThread(StackletThread):

    def __init__(self, space, ec):
        StackletThread.__init__(self)
        self.space = space
        self.ec = ec
        # for unpickling
        from rpython.rlib.rweakref import RWeakKeyDictionary
        self.frame2continulet = RWeakKeyDictionary(PyFrame, W_Continulet)

ExecutionContext.stacklet_thread = None

# ____________________________________________________________


class GlobalState:
    def clear(self):
        self.origin = None
        self.destination = None
        self.w_value = None
        self.propagate_exception = None
global_state = GlobalState()
global_state.clear()


def new_stacklet_callback(h, arg):
    self = global_state.origin
    self.h = h
    global_state.clear()
    try:
        rvmprof.start_sampling()
        frame = self.bottomframe
        w_result = frame.execute_frame()
    except Exception as e:
        global_state.propagate_exception = e
    else:
        global_state.w_value = w_result
    finally:
        rvmprof.stop_sampling()
    self.sthread.ec.topframeref = jit.vref_None
    global_state.origin = self
    global_state.destination = self
    return self.h

def pre_switch(sthread):
    saved_exception = sthread.ec.sys_exc_info()
    sthread.ec.set_sys_exc_info(None)
    return saved_exception

def post_switch(sthread, h, saved_exception):
    origin = global_state.origin
    self = global_state.destination
    global_state.origin = None
    global_state.destination = None
    self.h, origin.h = origin.h, h
    #
    current = sthread.ec.topframeref
    sthread.ec.topframeref = self.bottomframe.f_backref
    sthread.ec.set_sys_exc_info(saved_exception)
    self.bottomframe.f_backref = origin.bottomframe.f_backref
    origin.bottomframe.f_backref = current
    #
    return get_result()

def get_result():
    if global_state.propagate_exception:
        e = global_state.propagate_exception
        global_state.propagate_exception = None
        raise e
    w_value = global_state.w_value
    global_state.w_value = None
    return w_value

def build_sthread(space):
    ec = space.getexecutioncontext()
    sthread = ec.stacklet_thread
    if not sthread:
        sthread = ec.stacklet_thread = SThread(space, ec)
    return sthread

# ____________________________________________________________

def permute(space, args_w):
    sthread = build_sthread(space)
    #
    contlist = []
    for w_cont in args_w:
        cont = space.interp_w(W_Continulet, w_cont)
        if cont.sthread is not sthread:
            if cont.sthread is None:
                continue   # ignore non-initialized continulets
            else:
                raise geterror(space, "inter-thread support is missing")
        elif sthread.is_empty_handle(cont.h):
            raise geterror(space, "got an already-finished continulet")
        contlist.append(cont)
    #
    if len(contlist) > 1:
        otherh = contlist[-1].h
        otherb = contlist[-1].bottomframe.f_backref
        for cont in contlist:
            otherh, cont.h = cont.h, otherh
            b = cont.bottomframe
            otherb, b.f_backref = b.f_backref, otherb
