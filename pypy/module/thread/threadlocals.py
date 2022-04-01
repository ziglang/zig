import weakref
from rpython.rlib import rthread, rshrinklist
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rarithmetic import r_ulonglong
from pypy.module.thread.error import wrap_thread_error
from pypy.interpreter.executioncontext import ExecutionContext


ExecutionContext._signals_enabled = 0     # default value
ExecutionContext._sentinel_lock = None


class OSThreadLocals:
    """Thread-local storage for OS-level threads.
    For memory management, this version depends on explicit notification when
    a thread finishes.  This works as long as the thread was started by
    os_thread.bootstrap()."""

    def __init__(self, space):
        "NOT_RPYTHON"
        #
        # This object tracks code that enters and leaves threads.
        # There are two APIs.  For Python-level threads, we know when
        # the thread starts and ends, and we call enter_thread() and
        # leave_thread().  In a few other cases, like callbacks, we
        # might be running in some never-seen-before thread: in this
        # case, the callback logic needs to call try_enter_thread() at
        # the start, and if this returns True it needs to call
        # leave_thread() at the end.
        #
        # We implement an optimization for the second case (which only
        # works if we translate with a framework GC and with
        # rweakref).  If try_enter_thread() is called in a
        # never-seen-before thread, it still returns False and
        # remembers the ExecutionContext with 'self._weaklist'.  The
        # next time we call try_enter_thread() again in the same
        # thread, the ExecutionContext is reused.  The optimization is
        # not completely invisible to the user: 'thread._local()'
        # values will remain.  We can argue that it is the correct
        # behavior to do that, and the behavior we get if the
        # optimization is disabled is buggy (but hard to do better
        # then).
        #
        # 'self._valuedict' is a dict mapping the thread idents to
        # ExecutionContexts; it does not list the ExecutionContexts
        # which are in 'self._weaklist'.  (The latter is more precisely
        # a list of AutoFreeECWrapper objects, defined below, which
        # each references the ExecutionContext.)
        #
        self.space = space
        self._valuedict = {}
        self._cleanup_()
        self.raw_thread_local = rthread.ThreadLocalReference(ExecutionContext,
                                                            loop_invariant=True)

    def can_optimize_with_weaklist(self):
        config = self.space.config
        return (config.translation.rweakref and
                rthread.ThreadLocalReference.automatic_keepalive(config))

    def _cleanup_(self):
        self._valuedict.clear()
        self._weaklist = None
        self._mainthreadident = 0

    def enter_thread(self, space):
        "Notification that the current thread is about to start running."
        self._set_ec(space.createexecutioncontext())

    def try_enter_thread(self, space):
        # common case: the thread-local has already got a value
        if self.raw_thread_local.get() is not None:
            return False

        # Else, make and attach a new ExecutionContext
        ec = space.createexecutioncontext()
        if not self.can_optimize_with_weaklist():
            self._set_ec(ec)
            return True

        # If can_optimize_with_weaklist(), then 'rthread' keeps the
        # thread-local values alive until the end of the thread.  Use
        # AutoFreeECWrapper as an object with a __del__; when this
        # __del__ is called, it means the thread was really finished.
        # In this case we don't want leave_thread() to be called
        # explicitly, so we return False.
        if self._weaklist is None:
            self._weaklist = ListECWrappers()
        self._weaklist.append(weakref.ref(AutoFreeECWrapper(ec)))
        self._set_ec(ec, register_in_valuedict=False)
        return False

    def _set_ec(self, ec, register_in_valuedict=True):
        ident = rthread.get_ident()
        if self._mainthreadident == 0 or self._mainthreadident == ident:
            ec._signals_enabled = 1    # the main thread is enabled
            self._mainthreadident = ident
        if register_in_valuedict:
            self._valuedict[ident] = ec
        self.raw_thread_local.set(ec)

    def leave_thread(self, space):
        "Notification that the current thread is about to stop."
        from pypy.module.thread.os_local import thread_is_stopping
        ec = self.get_ec()
        if ec is not None:
            try:
                thread_is_stopping(ec)
            finally:
                self.raw_thread_local.set(None)
                ident = rthread.get_ident()
                try:
                    del self._valuedict[ident]
                except KeyError:
                    pass

    def get_ec(self):
        ec = self.raw_thread_local.get()
        if not we_are_translated():
            assert ec is self._valuedict.get(rthread.get_ident(), None)
        return ec

    def signals_enabled(self):
        ec = self.get_ec()
        return ec is not None and ec._signals_enabled

    def enable_signals(self, space):
        ec = self.get_ec()
        assert ec is not None
        ec._signals_enabled += 1

    def disable_signals(self, space):
        ec = self.get_ec()
        assert ec is not None
        new = ec._signals_enabled - 1
        if new < 0:
            raise wrap_thread_error(space,
                "cannot disable signals in thread not enabled for signals")
        ec._signals_enabled = new

    def getallvalues(self):
        if self._weaklist is None:
            return self._valuedict
        # This logic walks the 'self._weaklist' list and adds the
        # ExecutionContexts to 'result'.  We are careful in case there
        # are two AutoFreeECWrappers in the list which have the same
        # 'ident'; in this case we must keep the most recent one (the
        # older one should be deleted soon).  Moreover, entries in
        # self._valuedict have priority because they are never
        # outdated.
        result = {}
        for h in self._weaklist.items():
            wrapper = h()
            if wrapper is not None and not wrapper.deleted:
                result[wrapper.ident] = wrapper.ec
                # ^^ this possibly overwrites an older ec
        result.update(self._valuedict)
        return result

    def reinit_threads(self, space):
        "Called in the child process after a fork()"
        ident = rthread.get_ident()
        ec = self.get_ec()
        assert ec is not None
        old_sig = ec._signals_enabled
        if ident != self._mainthreadident:
            old_sig += 1
        self._cleanup_()      # clears self._valuedict
        self._mainthreadident = ident
        self._set_ec(ec)
        ec._signals_enabled = old_sig


class AutoFreeECWrapper(object):
    deleted = False

    def __init__(self, ec):
        # this makes a loop between 'self' and 'ec'.  It should not prevent
        # the __del__ method here from being called.
        self.ec = ec
        ec._threadlocals_auto_free = self
        self.ident = rthread.get_ident()

    def __del__(self):
        from pypy.module.thread.os_local import thread_is_stopping
        # this is always called in another thread: the thread
        # referenced by 'self.ec' has finished at that point, and
        # we're just after the GC which finds no more references to
        # 'ec' (and thus to 'self').
        self.deleted = True
        thread_is_stopping(self.ec)

class ListECWrappers(rshrinklist.AbstractShrinkList):
    def must_keep(self, wref):
        return wref() is not None
