import sys
import __pypy__
import _continuation
import _contextvars

__version__ = "0.4.13"

# ____________________________________________________________
# Constants from greenlet 1.0.0

GREENLET_USE_GC = True
GREENLET_USE_TRACING = True
GREENLET_USE_CONTEXT_VARS = True    # added in py3.7

# ____________________________________________________________
# Exceptions

class GreenletExit(BaseException):
    """This special exception does not propagate to the parent greenlet; it
can be used to kill a single greenlet."""

error = _continuation.error

# ____________________________________________________________
# Helper function

def getcurrent():
    "Returns the current greenlet (i.e. the one which called this function)."
    try:
        return _tls.current
    except AttributeError:
        # first call in this thread: current == main
        _green_create_main()
        return _tls.current

# ____________________________________________________________
# The 'greenlet' class

_continulet = _continuation.continulet

class greenlet(_continulet):
    getcurrent = staticmethod(getcurrent)
    error = error
    GreenletExit = GreenletExit
    __main = False
    __started = False
    __context = None

    def __new__(cls, *args, **kwds):
        self = _continulet.__new__(cls)
        self.parent = getcurrent()
        return self

    def __init__(self, run=None, parent=None):
        if run is not None:
            self.run = run
        if parent is not None:
            self.parent = parent

    def switch(self, *args, **kwds):
        "Switch execution to this greenlet, optionally passing the values "
        "given as argument(s).  Returns the value passed when switching back."
        return self.__switch('switch', (args, kwds))

    def throw(self, typ=GreenletExit, val=None, tb=None):
        "raise exception in greenlet, return value passed when switching back"
        return self.__switch('throw', typ, val, tb)

    def __switch(target, methodname, *baseargs):
        current = getcurrent()
        #
        while not (target.__main or _continulet.is_pending(target)):
            # inlined __nonzero__ ^^^ in case it's overridden
            if not target.__started:
                # check that 'target.parent' runs in the current thread,
                # at least.  It can be changed arbitrarily afterwards in
                # pypy greenlets, but too bad
                parent1 = target.parent
                while not parent1.__started:
                    parent1 = parent1.parent
                if parent1.__thread_id is not _tls.thread_id:
                    raise error("cannot start greenlet because its 'parent'"
                                " is running on a different thread")

                if methodname == 'switch':
                    greenlet_func = _greenlet_start
                else:
                    greenlet_func = _greenlet_throw
                _continulet.__init__(target, greenlet_func, *baseargs)
                methodname = 'switch'
                baseargs = ()
                target.__thread_id = _tls.thread_id
                target.__started = True
                break
            # already done, go to the parent instead
            # (NB. infinite loop possible, but unlikely, unless you mess
            # up the 'parent' explicitly.  Good enough, because a Ctrl-C
            # will show that the program is caught in this loop here.)
            target = target.parent
            # convert a "raise GreenletExit" into "return GreenletExit"
            if methodname == 'throw':
                try:
                    raise __pypy__.normalize_exc(baseargs[0], baseargs[1])
                except GreenletExit as e:
                    methodname = 'switch'
                    baseargs = (((e,), {}),)
                except:
                    baseargs = sys.exc_info()[:2] + baseargs[2:]
        else:
            if target.__thread_id is not _tls.thread_id:
                raise error("cannot switch to greenlet running in a"
                            " different thread")
        #
        try:
            unbound_method = getattr(_continulet, methodname)
            current.__context = __pypy__.get_contextvar_context()
            _tls.leaving = current
            args, kwds = unbound_method(current, *baseargs, to=target)
            _tls.current = current
            __pypy__.set_contextvar_context(current.__context)
            current.__context = None
        except:
            _tls.current = current
            __pypy__.set_contextvar_context(current.__context)
            current.__context = None
            if hasattr(_tls, 'trace'):
                _run_trace_callback('throw')
            _tls.leaving = None
            raise
        else:
            if hasattr(_tls, 'trace'):
                _run_trace_callback('switch')
            _tls.leaving = None
        #
        if kwds:
            if args:
                return args, kwds
            return kwds
        elif len(args) == 1:
            return args[0]
        else:
            return args

    def __bool__(self):
        return self.__main or _continulet.is_pending(self)

    @property
    def dead(self):
        return self.__started and not self

    @property
    def gr_frame(self):
        # xxx this doesn't work when called on either the current or
        # the main greenlet of another thread
        if self is getcurrent():
            return None
        if self.__main:
            self = getcurrent()
        f = self._get_frame()
        if not f:
            return None
        return f.f_back.f_back.f_back   # go past start(), __switch(), switch()

    def __get_context(self):
        if self is getcurrent():
            return __pypy__.get_contextvar_context()
        else:
            # can't reliably detect if 'self' is the current greenlet running
            # in another thread.  We might have race conditions between knowing
            # if it is the case and actually reading 'self.__context'.  So we
            # just ignore that case and return 'self.__context'.
            return self.__context

    def __set_context(self, nctx):
        if nctx is not None and not isinstance(nctx, _contextvars.Context):
            raise TypeError("greenlet context must be a "
                            "contextvars.Context or None")
        if self is getcurrent():
            __pypy__.set_contextvar_context(nctx)
        else:
            self.__context = nctx     # same issue as __get_context()
    gr_context = property(__get_context, __set_context)

# ____________________________________________________________
# Recent additions

GREENLET_USE_GC = True
GREENLET_USE_TRACING = True

def gettrace():
    return getattr(_tls, 'trace', None)

def settrace(callback):
    try:
        prev = _tls.trace
        del _tls.trace
    except AttributeError:
        prev = None
    if callback is not None:
        _tls.trace = callback
    return prev

def _run_trace_callback(event):
    try:
        _tls.trace(event, (_tls.leaving, _tls.current))
    except:
        # In case of exceptions trace function is removed
        if hasattr(_tls, 'trace'):
            del _tls.trace
        raise

# ____________________________________________________________
# Internal stuff

try:
    from threading import local as _local
except ImportError:
    class _local(object):    # assume no threads
        pass

_tls = _local()

def _green_create_main():
    # create the main greenlet for this thread
    _tls.current = None
    _tls.thread_id = object()
    gmain = greenlet.__new__(greenlet)
    gmain._greenlet__thread_id = _tls.thread_id
    gmain._greenlet__main = True
    gmain._greenlet__started = True
    assert gmain.parent is None
    _tls.main = gmain
    _tls.current = gmain

def _greenlet_start(greenlet, args):
    try:
        args, kwds = args
        _tls.current = greenlet
        try:
            __pypy__.set_contextvar_context(greenlet._greenlet__context)
            greenlet._greenlet__context = None
            if hasattr(_tls, 'trace'):
                _run_trace_callback('switch')
            res = greenlet.run(*args, **kwds)
        except GreenletExit as e:
            res = e
        finally:
            _continuation.permute(greenlet, greenlet.parent)
        return ((res,), None)
    finally:
        greenlet._greenlet__context = __pypy__.get_contextvar_context()
        _tls.leaving = greenlet

def _greenlet_throw(greenlet, exc, value, tb):
    try:
        _tls.current = greenlet
        try:
            __pypy__.set_contextvar_context(greenlet._greenlet__context)
            greenlet._greenlet__context = None
            if hasattr(_tls, 'trace'):
                _run_trace_callback('throw')
            raise __pypy__.normalize_exc(exc, value, tb)
        except GreenletExit as e:
            res = e
        finally:
            _continuation.permute(greenlet, greenlet.parent)
        return ((res,), None)
    finally:
        greenlet._greenlet__context = __pypy__.get_contextvar_context()
        _tls.leaving = greenlet
