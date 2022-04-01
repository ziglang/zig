import sys
from rpython.rlib import _rffi_stacklet as _c
from rpython.rlib import jit
from rpython.rlib.objectmodel import fetch_translated_config
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rlib import rvmprof

DEBUG = False


class StackletThread(object):

    @jit.dont_look_inside
    def __init__(self, _argument_ignored_for_backward_compatibility=None):
        self._gcrootfinder = _getgcrootfinder(fetch_translated_config())
        self._thrd = _c.newthread()
        if not self._thrd:
            raise MemoryError
        self._thrd_deleter = StackletThreadDeleter(self._thrd)
        if DEBUG:
            assert debug.sthread is None, "multithread debug support missing"
            debug.sthread = self

    @jit.dont_look_inside
    def new(self, callback, arg=llmemory.NULL):
        if DEBUG:
            callback = _debug_wrapper(callback)
        x = rvmprof.save_stack()
        try:
            rvmprof.empty_stack()
            h = self._gcrootfinder.new(self, callback, arg)
        finally:
            rvmprof.restore_stack(x)
        if DEBUG:
            debug.add(h)
        return h
    new._annspecialcase_ = 'specialize:arg(1)'

    @jit.dont_look_inside
    def switch(self, stacklet):
        if DEBUG:
            debug.remove(stacklet)
        x = rvmprof.save_stack()
        try:
            h = self._gcrootfinder.switch(stacklet)
        finally:
            rvmprof.restore_stack(x)
        if DEBUG:
            debug.add(h)
        return h

    def is_empty_handle(self, stacklet):
        # note that "being an empty handle" and being equal to
        # "get_null_handle()" may be the same, or not; don't rely on it
        return self._gcrootfinder.is_empty_handle(stacklet)

    def get_null_handle(self):
        return self._gcrootfinder.get_null_handle()

    def _freeze_(self):
        raise Exception("StackletThread instances must not be seen during"
                        " translation.")


class StackletThreadDeleter(object):
    # quick hack: the __del__ is on another object, so that
    # if the main StackletThread ends up in random circular
    # references, on pypy deletethread() is only called
    # when all that circular reference mess is gone.
    def __init__(self, thrd):
        self._thrd = thrd
    def __del__(self):
        thrd = self._thrd
        if thrd:
            self._thrd = lltype.nullptr(_c.thread_handle.TO)
            _c.deletethread(thrd)

# ____________________________________________________________

def _getgcrootfinder(config):
    if config is None and '__pypy__' in sys.builtin_module_names:
        import py
        py.test.skip("cannot run the stacklet tests on top of pypy: "
                     "calling directly the C function stacklet_switch() "
                     "will crash, depending on details of your config")
    if config is not None:
        assert config.translation.continuation, (
            "stacklet: you have to translate with --continuation")
    if (config is None or
        config.translation.gc in ('ref', 'boehm', 'none')):   # for tests
        gcrootfinder = 'n/a'
    else:
        gcrootfinder = config.translation.gcrootfinder
    gcrootfinder = gcrootfinder.replace('/', '_')
    module = __import__('rpython.rlib._stacklet_%s' % gcrootfinder,
                        None, None, ['__doc__'])
    return module.gcrootfinder
_getgcrootfinder._annspecialcase_ = 'specialize:memo'


class StackletDebugError(Exception):
    pass

class Debug(object):
    def __init__(self):
        self.sthread = None
        self.active = []
    def _cleanup_(self):
        self.__init__()
    def add(self, h):
        if not self.sthread.is_empty_handle(h):
            if h == self.sthread.get_null_handle():
                raise StackletDebugError("unexpected null handle")
            self.active.append(h)
    def remove(self, h):
        try:
            i = self.active.index(h)
        except ValueError:
            if self.sthread.is_empty_handle(h):
                msg = "empty stacklet handle"
            elif h == self.sthread.get_null_handle():
                msg = "unexpected null handle"
            else:
                msg = "double usage of handle %r" % (h,)
            raise StackletDebugError(msg)
        del self.active[i]
debug = Debug()

def _debug_wrapper(callback):
    def wrapper(h, arg):
        debug.add(h)
        h = callback(h, arg)
        debug.remove(h)
        return h
    return wrapper
_debug_wrapper._annspecialcase_ = 'specialize:memo'
