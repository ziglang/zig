from pypy.module.cpyext.api import (
    cpython_api, CANNOT_FAIL, cpython_struct)
from pypy.module.cpyext.pyobject import PyObject, decref, make_ref, from_ref
from pypy.module.cpyext.modsupport import PyModuleDef
from pypy.interpreter.error import OperationError, oefmt
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib import rthread
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rarithmetic import widen

PyInterpreterStateStruct = lltype.ForwardReference()
PyInterpreterState = lltype.Ptr(PyInterpreterStateStruct)
cpython_struct(
    "PyInterpreterState",
    [('next', PyInterpreterState),
     ('modules_by_index', PyObject)],
    PyInterpreterStateStruct)
PyThreadState = lltype.Ptr(cpython_struct(
    "PyThreadState",
    [('interp', PyInterpreterState),
     ('dict', PyObject),
     ]))

class NoThreads(Exception):
    pass

@cpython_api([], PyThreadState, error=CANNOT_FAIL, gil="release")
def PyEval_SaveThread(space):
    """Release the global interpreter lock (if it has been created and thread
    support is enabled) and reset the thread state to NULL, returning the
    previous thread state.  If the lock has been created,
    the current thread must have acquired it.  (This function is available even
    when thread support is disabled at compile time.)"""
    state = space.fromcache(InterpreterState)
    ec = space.getexecutioncontext()
    tstate = state._get_thread_state(space, ec).memory
    ec.cpyext_threadstate_is_current = False
    return tstate

@cpython_api([PyThreadState], lltype.Void, gil="acquire")
def PyEval_RestoreThread(space, tstate):
    """Acquire the global interpreter lock (if it has been created and thread
    support is enabled) and set the thread state to tstate, which must not be
    NULL.  If the lock has been created, the current thread must not have
    acquired it, otherwise deadlock ensues.  (This function is available even
    when thread support is disabled at compile time.)"""
    PyThreadState_Swap(space, tstate)

@cpython_api([], lltype.Void)
def PyEval_InitThreads(space):
    if not space.config.translation.thread:
        raise NoThreads
    from pypy.module.thread import os_thread
    os_thread.setup_threads(space)

@cpython_api([], rffi.INT_real, error=CANNOT_FAIL)
def PyEval_ThreadsInitialized(space):
    if not space.config.translation.thread:
        return 0
    from pypy.module.thread import os_thread
    return int(os_thread.threads_initialized(space))

# XXX: might be generally useful
def encapsulator(T, flavor='raw', dealloc=None):
    class MemoryCapsule(object):
        def __init__(self, space):
            self.space = space
            if space is not None:
                self.memory = lltype.malloc(T, flavor=flavor)
            else:
                self.memory = lltype.nullptr(T)
        def __del__(self):
            if self.memory:
                if dealloc and self.space:
                    dealloc(self.memory, self.space)
                lltype.free(self.memory, flavor=flavor)
    return MemoryCapsule

def ThreadState_dealloc(ts, space):
    assert space is not None
    decref(space, ts.c_dict)
ThreadStateCapsule = encapsulator(PyThreadState.TO,
                                  dealloc=ThreadState_dealloc)

from pypy.interpreter.executioncontext import ExecutionContext

# Keep track of the ThreadStateCapsule for a particular execution context.  The
# default is for new execution contexts not to have one; it is allocated on the
# first cpyext-based request for it.
ExecutionContext.cpyext_threadstate = ThreadStateCapsule(None)

# Also keep track of whether it has been initialized yet or not (None is a valid
# PyThreadState for an execution context to have, when the GIL has been
# released, so a check against that can't be used to determine the need for
# initialization).
ExecutionContext.cpyext_initialized_threadstate = False
ExecutionContext.cpyext_threadstate_is_current = True

def cleanup_cpyext_state(self):
    self.cpyext_threadstate = None
    self.cpyext_threadstate_is_current = True
    self.cpyext_initialized_threadstate = False
ExecutionContext.cleanup_cpyext_state = cleanup_cpyext_state

class InterpreterState(object):
    def __init__(self, space):
        self.interpreter_state = lltype.malloc(
            PyInterpreterState.TO, flavor='raw', zero=True, immortal=True)

    def new_thread_state(self, space):
        """
        Create a new ThreadStateCapsule to hold the PyThreadState for a
        particular execution context.

        :param space: A space.

        :returns: A new ThreadStateCapsule holding a newly allocated
            PyThreadState and referring to this interpreter state.
        """
        capsule = ThreadStateCapsule(space)
        ts = capsule.memory
        ts.c_interp = self.interpreter_state
        ts.c_dict = make_ref(space, space.newdict())
        return capsule


    def get_thread_state(self, space):
        """
        Get the current PyThreadState for the current execution context.

        :param space: A space.

        :returns: The current PyThreadState for the current execution context,
            or None if it does not have one.
        """
        ec = space.getexecutioncontext()
        return self._get_thread_state(space, ec).memory


    def swap_thread_state(self, space, tstate):
        """
        Replace the current thread state of the current execution context with a
        new thread state.

        :param space: The space.

        :param tstate: The new PyThreadState for the current execution context.

        :returns: The old thread state for the current execution context, either
            None or a PyThreadState.
        """
        ec = space.getexecutioncontext()
        capsule = self._get_thread_state(space, ec)
        old_tstate = capsule.memory
        capsule.memory = tstate
        return old_tstate

    def _get_thread_state(self, space, ec):
        """
        Get the ThreadStateCapsule for the given execution context, possibly
        creating a new one if it does not already have one.

        :param space: The space.
        :param ec: The ExecutionContext of which to get the thread state.
        :returns: The ThreadStateCapsule for the given execution context.
        """
        if not ec.cpyext_initialized_threadstate:
            ec.cpyext_threadstate = self.new_thread_state(space)
            ec.cpyext_initialized_threadstate = True
            ec.cpyext_threadstate_is_current = True
        return ec.cpyext_threadstate

@cpython_api([], PyThreadState, error=CANNOT_FAIL)
def PyThreadState_Get(space):
    state = space.fromcache(InterpreterState)
    ts = state.get_thread_state(space)
    if not ts:
        from pypy.module.cpyext.api import py_fatalerror
        py_fatalerror("PyThreadState_Get: no current thread")
    return ts

@cpython_api([], PyThreadState, error=CANNOT_FAIL)
def _PyThreadState_UncheckedGet(space):
    """Similar to PyThreadState_Get(), but don't issue a fatal error
    if it is NULL.
    This is from CPython >= 3.7.  On py3.6, it is present anyway and used to
    implement _Py_Finalizing as a macro.
    """
    state = space.fromcache(InterpreterState)
    ts = state.get_thread_state(space)
    return ts

@cpython_api([], PyObject, result_is_ll=True, error=CANNOT_FAIL)
def PyThreadState_GetDict(space):
    """Return a dictionary in which extensions can store thread-specific state
    information.  Each extension should use a unique key to use to store state in
    the dictionary.  It is okay to call this function when no current thread state
    is available. If this function returns NULL, no exception has been raised and
    the caller should assume no current thread state is available.

    Previously this could only be called when a current thread is active, and NULL
    meant that an exception was raised."""
    state = space.fromcache(InterpreterState)
    ts = state.get_thread_state(space)
    if not space.getexecutioncontext().cpyext_threadstate_is_current:
        return lltype.nullptr(PyObject.TO)
    return ts.c_dict

@cpython_api([PyThreadState], PyThreadState, error=CANNOT_FAIL)
def PyThreadState_Swap(space, tstate):
    """Swap the current thread state with the thread state given by the argument
    tstate, which may be NULL.  The global interpreter lock must be held."""
    ec = space.getexecutioncontext()
    state = space.fromcache(InterpreterState)
    old_tstate = state.get_thread_state(space)
    if not ec.cpyext_threadstate_is_current:
        old_tstate = lltype.nullptr(PyThreadState.TO)
    if tstate:
        if tstate != state.get_thread_state(space):
            print "Error in cpyext, CPython compatibility layer:"
            print "PyThreadState_Swap() cannot be used to switch to another"
            print "different PyThreadState right now"
            raise AssertionError
        ec.cpyext_threadstate_is_current = True
    else:
        ec.cpyext_threadstate_is_current = False
    return old_tstate

@cpython_api([PyThreadState], lltype.Void, gil="acquire")
def PyEval_AcquireThread(space, tstate):
    """Acquire the global interpreter lock and set the current thread state to
    tstate, which should not be NULL.  The lock must have been created earlier.
    If this thread already has the lock, deadlock ensues.  This function is not
    available when thread support is disabled at compile time."""

@cpython_api([PyThreadState], lltype.Void, gil="release")
def PyEval_ReleaseThread(space, tstate):
    """Reset the current thread state to NULL and release the global interpreter
    lock.  The lock must have been created earlier and must be held by the current
    thread.  The tstate argument, which must not be NULL, is only used to check
    that it represents the current thread state --- if it isn't, a fatal error is
    reported. This function is not available when thread support is disabled at
    compile time."""

PyGILState_STATE = rffi.INT
PyGILState_LOCKED = 0
PyGILState_UNLOCKED = 1
PyGILState_IGNORE = 2

ExecutionContext.cpyext_gilstate_counter_noleave = 0

def _workaround_cpython_untranslated(space):
    # Workaround when not translated.  The problem is that
    # space.threadlocals.get_ec() is based on "thread._local", but
    # CPython will clear a "thread._local" as soon as CPython's
    # PyThreadState goes away.  This occurs even if we're in a thread
    # created from C and we're going to call some more Python code
    # from this thread.  This case shows up in
    # test_pystate.test_frame_tstate_tracing.
    def get_possibly_deleted_ec():
        ec1 = space.threadlocals.raw_thread_local.get()
        ec2 = space.threadlocals._valuedict.get(rthread.get_ident(), None)
        if ec1 is None and ec2 is not None:
            space.threadlocals.raw_thread_local.set(ec2)
        return space.threadlocals.__class__.get_ec(space.threadlocals)
    space.threadlocals.get_ec = get_possibly_deleted_ec


@cpython_api([], rffi.INT_real, error=CANNOT_FAIL, gil="pygilstate_check")
def PyGILState_Check(space):
    assert False, "the logic is completely inside wrapper_second_level"


@cpython_api([], PyGILState_STATE, error=CANNOT_FAIL, gil="pygilstate_ensure")
def PyGILState_Ensure(space, previous_state):
    # The argument 'previous_state' is not part of the API; it is inserted
    # by make_wrapper() and contains PyGILState_LOCKED/UNLOCKED based on
    # the previous GIL state.
    must_leave = space.threadlocals.try_enter_thread(space)
    ec = space.getexecutioncontext()
    if not must_leave:
        # This is a counter of how many times we called try_enter_thread()
        # and it returned False.  In PyGILState_Release(), if this counter
        # is greater than zero, we decrement it; only if the counter is
        # already zero do we call leave_thread().
        ec.cpyext_gilstate_counter_noleave += 1
    else:
        # This case is for when we just built a fresh threadlocals.
        # We should only see it when we are in a new thread with no
        # PyPy code below.
        assert previous_state == PyGILState_UNLOCKED
        assert ec.cpyext_gilstate_counter_noleave == 0
        if not we_are_translated():
            _workaround_cpython_untranslated(space)
    #
    ec.cpyext_threadstate_is_current = True
    return rffi.cast(PyGILState_STATE, previous_state)

@cpython_api([PyGILState_STATE], lltype.Void, gil="pygilstate_release")
def PyGILState_Release(space, oldstate):
    oldstate = rffi.cast(lltype.Signed, oldstate)
    ec = space.getexecutioncontext()
    if ec.cpyext_gilstate_counter_noleave > 0:
        ec.cpyext_gilstate_counter_noleave -= 1
    else:
        assert ec.cpyext_gilstate_counter_noleave == 0
        assert oldstate == PyGILState_UNLOCKED
        assert space.config.translation.thread
        #      ^^^ otherwise, we should not reach this case
        ec.cpyext_threadstate_is_current = False
        space.threadlocals.leave_thread(space)

@cpython_api([], PyInterpreterState, error=CANNOT_FAIL)
def PyInterpreterState_Head(space):
    """Return the interpreter state object at the head of the list of all such objects.
    """
    return space.fromcache(InterpreterState).interpreter_state

@cpython_api([PyInterpreterState], PyInterpreterState, error=CANNOT_FAIL)
def PyInterpreterState_Next(space, interp):
    """Return the next interpreter state object after interp from the list of all
    such objects.
    """
    return lltype.nullptr(PyInterpreterState.TO)

@cpython_api([PyInterpreterState], PyThreadState, error=CANNOT_FAIL,
             gil="around")
def PyThreadState_New(space, interp):
    """Create a new thread state object belonging to the given interpreter
    object.  The global interpreter lock need not be held, but may be held if
    it is necessary to serialize calls to this function."""
    if not space.config.translation.thread:
        raise NoThreads
    # PyThreadState_Get will allocate a new execution context,
    # we need to protect gc and other globals with the GIL.
    rthread.gc_thread_start()
    return PyThreadState_Get(space)

@cpython_api([PyThreadState], lltype.Void)
def PyThreadState_Clear(space, tstate):
    """Reset all information in a thread state object.  The global
    interpreter lock must be held."""
    if not space.config.translation.thread:
        raise NoThreads
    decref(space, tstate.c_dict)
    tstate.c_dict = lltype.nullptr(PyObject.TO)
    space.threadlocals.leave_thread(space)
    space.getexecutioncontext().cleanup_cpyext_state()
    rthread.gc_thread_die()

@cpython_api([PyThreadState], lltype.Void)
def PyThreadState_Delete(space, tstate):
    """Destroy a thread state object.  The global interpreter lock need not
    be held.  The thread state must have been reset with a previous call to
    PyThreadState_Clear()."""

@cpython_api([], lltype.Void)
def PyThreadState_DeleteCurrent(space):
    """Destroy a thread state object.  The global interpreter lock need not
    be held.  The thread state must have been reset with a previous call to
    PyThreadState_Clear()."""

@cpython_api([], lltype.Void)
def PyOS_AfterFork(space):
    """Function to update some internal state after a process fork; this should be
    called in the new process if the Python interpreter will continue to be used.
    If a new executable is loaded into the new process, this function does not need
    to be called."""
    if not space.config.translation.thread:
        return
    from pypy.module.thread import os_thread
    try:
        os_thread.reinit_threads(space)
    except OperationError as e:
        e.write_unraisable(space, "PyOS_AfterFork()")

@cpython_api([], rffi.INT_real, error=CANNOT_FAIL)
def _Py_IsFinalizing(space):
    """From CPython >= 3.7.  On py3.6, it is present anyway and used to
    implement _Py_Finalizing as a macro."""
    return space.sys.finalizing

def _PyInterpreterState_GET(space):
    tstate = PyThreadState_Get(space)
    return tstate.c_interp

@cpython_api([PyObject, PyModuleDef], rffi.INT_real, error=-1)
def PyState_AddModule(space, w_module, moddef):
    if not moddef:
        raise oefmt(space.w_SystemError, "module definition is NULL")
    interp = _PyInterpreterState_GET(space)
    index = widen(moddef.c_m_base.c_m_index)
    if index < 0:
        raise oefmt(space.w_SystemError, "module index < 0")
    if not interp.c_modules_by_index:
        w_by_index = space.newlist([])
        interp.c_modules_by_index = make_ref(space, w_by_index)
    else:
        w_by_index = from_ref(space, interp.c_modules_by_index)
    if moddef.c_m_slots:
        raise oefmt(space.w_SystemError,
                    "PyState_AddModule called on module with slots");
    if index < space.len_w(w_by_index):
        w_module_seen = space.getitem(w_by_index, space.newint(index))
        if space.eq_w(w_module_seen, w_module):
            raise oefmt(space.w_SystemError, "module %R already added", w_module)
    while space.len_w(w_by_index) <= index:
        space.call_method(w_by_index, 'append', space.w_None)
    space.setitem(w_by_index, space.newint(index), w_module)
    return 0

@cpython_api([PyModuleDef], rffi.INT_real, error=-1)
def PyState_RemoveModule(space, moddef):
    interp = _PyInterpreterState_GET(space)
    if moddef.c_m_slots:
        raise oefmt(space.w_SystemError,
                    "PyState_RemoveModule called on module with slots")
    index = widen(moddef.c_m_base.c_m_index)
    if index == 0:
        raise oefmt(space.w_SystemError, "invalid module index")
    if not interp.c_modules_by_index:
        raise oefmt(space.w_SystemError, "Interpreters module-list not accessible.")
    w_by_index = from_ref(space, interp.c_modules_by_index)
    if index > space.len_w(w_by_index):
        raise oefmt(space.w_SystemError, "Module index out of bounds.")
    space.setitem(w_by_index, space.newint(index), space.w_None)
    return 0
