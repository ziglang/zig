"""
Thread support based on OS-level threads.
"""

import os
from rpython.rlib import rthread
from pypy.module.thread.error import wrap_thread_error
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import unwrap_spec, Arguments

# Here are the steps performed to start a new thread:
#
# * The bootstrapper.lock is first acquired to prevent two parallel
#   starting threads from messing with each other's start-up data.
#
# * The start-up data (the app-level callable and arguments) is
#   stored in the global bootstrapper object.
#
# * The new thread is launched at RPython level using an rffi call
#   to the C function RPyThreadStart() defined in
#   translator/c/src/thread*.h.  This RPython thread will invoke the
#   static method bootstrapper.bootstrap() as a call-back.
#
# * As if it was a regular callback, rffi adds a wrapper around
#   bootstrap().  This wrapper acquires and releases the GIL.  In this
#   way the new thread is immediately GIL-protected.
#
# * As soon as the GIL is acquired in the new thread, the gc_thread_run()
#   operation is called (this is all done by gil.after_external_call(),
#   called from the rffi-generated wrapper).  The gc_thread_run()
#   operation will automatically notice that the current thread id was
#   not seen before, and (in shadowstack) it will allocate and use a
#   fresh new stack.
#
# * Only then does bootstrap() really run.  The first thing it does
#   is grab the start-up information (app-level callable and args)
#   out of the global bootstrapper object and release bootstrapper.lock.
#   Then it calls the app-level callable, to actually run the thread.
#
# * After each potential thread switch, as soon as the GIL is re-acquired,
#   gc_thread_run() is called again; it ensures that the currently
#   installed shadow stack is the correct one for the currently running
#   thread.
#
# * Just before a thread finishes, gc_thread_die() is called to free
#   its shadow stack.


class Bootstrapper(object):
    "A global container used to pass information to newly starting threads."

    # Passing a closure argument to rthread.start_new_thread() would be
    # theoretically nicer, but comes with messy memory management issues.
    # This is much more straightforward.

    nbthreads = 0

    # The following lock is held whenever the fields
    # 'bootstrapper.w_callable' and 'bootstrapper.args' are in use.
    lock = None
    args = None
    w_callable = None

    @staticmethod
    def setup(space):
        if bootstrapper.lock is None:
            try:
                bootstrapper.lock = rthread.allocate_lock()
            except rthread.error:
                raise wrap_thread_error(space, "can't allocate bootstrap lock")

    @staticmethod
    def reinit():
        bootstrapper.lock = None
        bootstrapper.nbthreads = 0
        bootstrapper.w_callable = None
        bootstrapper.args = None

    def _cleanup_(self):
        self.reinit()

    def bootstrap():
        # Note that when this runs, we already hold the GIL.  This is ensured
        # by rffi's callback mecanism: we are a callback for the
        # c_thread_start() external function.
        rthread.gc_thread_start()
        space = bootstrapper.space
        w_callable = bootstrapper.w_callable
        args = bootstrapper.args
        bootstrapper.nbthreads += 1
        bootstrapper.release()
        # run!
        try:
            bootstrapper.run(space, w_callable, args)
            # done
        except Exception as e:
            # oups! last-level attempt to recover.
            try:
                STDERR = 2
                os.write(STDERR, "Thread exited with ")
                os.write(STDERR, str(e))
                os.write(STDERR, "\n")
            except OSError:
                pass
        #
        bootstrapper.nbthreads -= 1
        rthread.gc_thread_die()
    bootstrap = staticmethod(bootstrap)

    def acquire(space, w_callable, args):
        # If the previous thread didn't start yet, wait until it does.
        # Note that bootstrapper.lock must be a regular lock, not a NOAUTO
        # lock, because the GIL must be released while we wait.
        bootstrapper.lock.acquire(True)
        bootstrapper.space = space
        bootstrapper.w_callable = w_callable
        bootstrapper.args = args
    acquire = staticmethod(acquire)

    def release():
        # clean up 'bootstrapper' to make it ready for the next
        # start_new_thread() and release the lock to tell that there
        # isn't any bootstrapping thread left.
        bootstrapper.w_callable = None
        bootstrapper.args = None
        bootstrapper.lock.release()
    release = staticmethod(release)

    def run(space, w_callable, args):
        # add the ExecutionContext to space.threadlocals
        space.threadlocals.enter_thread(space)
        try:
            space.call_args(w_callable, args)
        except OperationError as e:
            if not e.match(space, space.w_SystemExit):
                ident = rthread.get_ident()
                # PyPy adds the thread ident
                where = 'in thread %d started by ' % ident
                e.write_unraisable(space, where, w_callable, with_traceback=True)
            e.clear(space)
        # clean up space.threadlocals to remove the ExecutionContext
        # entry corresponding to the current thread
        space.threadlocals.leave_thread(space)
    run = staticmethod(run)

bootstrapper = Bootstrapper()


def setup_threads(space):
    space.threadlocals.setup_threads(space)
    bootstrapper.setup(space)

def threads_initialized(space):
    return space.threadlocals.threads_initialized()


def reinit_threads(space):
    "Called in the child process after a fork()"
    space.threadlocals.reinit_threads(space)
    bootstrapper.reinit()
    rthread.thread_after_fork()

def start_new_thread(space, w_callable, w_args, w_kwargs=None):
    """Start a new thread and return its identifier.  The thread will call the
function with positional arguments from the tuple args and keyword arguments
taken from the optional dictionary kwargs.  The thread exits when the
function returns; the return value is ignored.  The thread will also exit
when the function raises an unhandled exception; a stack trace will be
printed unless the exception is SystemExit."""
    setup_threads(space)
    if not space.isinstance_w(w_args, space.w_tuple):
        raise oefmt(space.w_TypeError, "2nd arg must be a tuple")
    if w_kwargs is not None and not space.isinstance_w(w_kwargs, space.w_dict):
        raise oefmt(space.w_TypeError, "optional 3rd arg must be a dictionary")
    if not space.is_true(space.callable(w_callable)):
        raise oefmt(space.w_TypeError, "first arg must be callable")

    args = Arguments.frompacked(space, w_args, w_kwargs)
    bootstrapper.acquire(space, w_callable, args)
    try:
        try:
            ident = rthread.start_new_thread(bootstrapper.bootstrap, ())
        except Exception:
            bootstrapper.release()     # normally called by the new thread
            raise
    except rthread.error:
        raise wrap_thread_error(space, "can't start new thread")
    return space.newint(ident)


def get_ident(space):
    """Return a non-zero integer that uniquely identifies the current thread
amongst other threads that exist simultaneously.
This may be used to identify per-thread resources.
Even though on some platforms threads identities may appear to be
allocated consecutive numbers starting at 1, this behavior should not
be relied upon, and the number should be seen purely as a magic cookie.
A thread's identity may be reused for another thread after it exits."""
    ident = rthread.get_ident()
    return space.newint(ident)

@unwrap_spec(size=int)
def stack_size(space, size=0):
    """stack_size([size]) -> size

Return the thread stack size used when creating new threads.  The
optional size argument specifies the stack size (in bytes) to be used
for subsequently created threads, and must be 0 (use platform or
configured default) or a positive integer value of at least 32,768 (32k).
If changing the thread stack size is unsupported, a ThreadError
exception is raised.  If the specified size is invalid, a ValueError
exception is raised, and the stack size is unmodified.  32k bytes
is currently the minimum supported stack size value to guarantee
sufficient stack space for the interpreter itself.

Note that some platforms may have particular restrictions on values for
the stack size, such as requiring a minimum stack size larger than 32kB or
requiring allocation in multiples of the system memory page size
- platform documentation should be referred to for more information
(4kB pages are common; using multiples of 4096 for the stack size is
the suggested approach in the absence of more specific information)."""
    if size < 0:
        raise oefmt(space.w_ValueError, "size must be 0 or a positive value")
    old_size = rthread.get_stacksize()
    error = rthread.set_stacksize(size)
    if error == -1:
        raise oefmt(space.w_ValueError, "size not valid: %d bytes", size)
    if error == -2:
        raise wrap_thread_error(space, "setting stack size not supported")
    return space.newint(old_size)

def _count(space):
    """_count() -> integer
Return the number of currently running Python threads, excluding
the main thread. The returned number comprises all threads created
through `start_new_thread()` as well as `threading.Thread`, and not
yet finished.

This function is meant for internal and specialized purposes only.
In most applications `threading.enumerate()` should be used instead."""
    return space.newint(bootstrapper.nbthreads)

def exit(space):
    """This is synonymous to ``raise SystemExit''.  It will cause the current
thread to exit silently unless the exception is caught."""
    raise OperationError(space.w_SystemExit, space.w_None)

def interrupt_main(space):
    """Raise a KeyboardInterrupt in the main thread.
A subthread can use this function to interrupt the main thread."""
    if space.check_signal_action is None:   # no signal module!
        raise OperationError(space.w_KeyboardInterrupt, space.w_None)
    space.check_signal_action.set_interrupt()
