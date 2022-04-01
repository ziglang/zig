"""
Python locks, based on true threading locks provided by the OS.
"""

import time
from rpython.rlib import rthread
from pypy.module.thread.error import wrap_thread_error
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef, make_weakref_descr
from pypy.interpreter.error import oefmt
from rpython.rlib.rarithmetic import r_longlong, ovfcheck, ovfcheck_float_to_longlong

# Force the declaration of the type 'thread.LockType' for RPython
#import pypy.module.thread.rpython.exttable

LONGLONG_MAX = r_longlong(2 ** (r_longlong.BITS - 1) - 1)
TIMEOUT_MAX = LONGLONG_MAX

RPY_LOCK_FAILURE, RPY_LOCK_ACQUIRED, RPY_LOCK_INTR = range(3)


def parse_acquire_args(space, blocking, timeout):
    if not blocking and timeout != -1.0:
        raise oefmt(space.w_ValueError,
                    "can't specify a timeout for a non-blocking call")
    if timeout < 0.0 and timeout != -1.0:
        raise oefmt(space.w_ValueError,
                    "timeout value must be strictly positive")
    if not blocking:
        microseconds = 0
    elif timeout == -1.0:
        microseconds = -1
    else:
        timeout *= 1e6
        try:
            microseconds = ovfcheck_float_to_longlong(timeout)
        except OverflowError:
            raise oefmt(space.w_OverflowError, "timeout value is too large")
    return microseconds


def acquire_timed(space, lock, microseconds):
    """Helper to acquire an interruptible lock with a timeout."""
    endtime = (time.time() * 1e6) + microseconds
    while True:
        result = lock.acquire_timed(microseconds)
        if result == RPY_LOCK_INTR:
            # Run signal handlers if we were interrupted
            space.getexecutioncontext().checksignals()
            if microseconds >= 0:
                microseconds = r_longlong((endtime - (time.time() * 1e6))
                                          + 0.999)
                # Check for negative values, since those mean block
                # forever
                if microseconds <= 0:
                    result = RPY_LOCK_FAILURE
        if result != RPY_LOCK_INTR:
            break
    return result


class Lock(W_Root):
    "A wrappable box around an interp-level lock object."

    _immutable_fields_ = ["lock"]

    def __init__(self, space):
        self.space = space
        try:
            self.lock = rthread.allocate_lock()
        except rthread.error:
            raise wrap_thread_error(space, "out of resources")

    @unwrap_spec(blocking=int, timeout=float)
    def descr_lock_acquire(self, space, blocking=1, timeout=-1.0):
        """Lock the lock.  Without argument, this blocks if the lock is already
locked (even by the same thread), waiting for another thread to release
the lock, and return None once the lock is acquired.
With an argument, this will only block if the argument is true,
and the return value reflects whether the lock is acquired.
The blocking operation is interruptible."""
        microseconds = parse_acquire_args(space, blocking, timeout)
        result = acquire_timed(space, self.lock, microseconds)
        return space.newbool(result == RPY_LOCK_ACQUIRED)

    def descr_lock_release(self, space):
        """Release the lock, allowing another thread that is blocked waiting for
the lock to acquire the lock.  The lock must be in the locked state,
but it needn't be locked by the same thread that unlocks it."""
        try:
            self.lock.release()
        except rthread.error:
            raise oefmt(space.w_RuntimeError,
                        "cannot release un-acquired lock")

    def _is_locked(self):
        if self.lock.acquire(False):
            self.lock.release()
            return False
        else:
            return True

    def descr_lock_locked(self, space):
        """Return whether the lock is in the locked state."""
        return space.newbool(self._is_locked())

    def descr__enter__(self, space):
        self.descr_lock_acquire(space)
        return self

    def descr__exit__(self, space, __args__):
        self.descr_lock_release(space)

    def __enter__(self):
        self.descr_lock_acquire(self.space)
        return self

    def __exit__(self, *args):
        self.descr_lock_release(self.space)

    def descr__repr__(self, space):
        classname = space.getfulltypename(self)
        if self._is_locked():
            locked = "locked"
        else:
            locked = "unlocked"
        return self.getrepr(space, '%s %s object' % (locked, classname))

    def descr_at_fork_reinit(self, space):
        # XXX this it not good enough! CPython leaks the underlying lock
        self.__init__(space)


Lock.typedef = TypeDef(
    "_thread.lock",
    __doc__="""\
A lock object is a synchronization primitive.  To create a lock,
call the thread.allocate_lock() function.  Methods are:

acquire() -- lock the lock, possibly blocking until it can be obtained
release() -- unlock of the lock
locked() -- test whether the lock is currently locked

A lock is not owned by the thread that locked it; another thread may
unlock it.  A thread attempting to lock a lock that it has already locked
will block until another thread unlocks it.  Deadlocks may ensue.""",
    acquire=interp2app(Lock.descr_lock_acquire),
    release=interp2app(Lock.descr_lock_release),
    locked=interp2app(Lock.descr_lock_locked),
    __enter__=interp2app(Lock.descr__enter__),
    __exit__=interp2app(Lock.descr__exit__),
    __repr__ = interp2app(Lock.descr__repr__),
    __weakref__ = make_weakref_descr(Lock),
    # Obsolete synonyms
    acquire_lock=interp2app(Lock.descr_lock_acquire),
    release_lock=interp2app(Lock.descr_lock_release),
    locked_lock=interp2app(Lock.descr_lock_locked),

    _at_fork_reinit=interp2app(Lock.descr_at_fork_reinit),
)


def allocate_lock(space):
    """Create a new lock object.  (allocate() is an obsolete synonym.)
See LockType.__doc__ for information about locks."""
    return Lock(space)

def _set_sentinel(space):
    """_set_sentinel() -> lock

    Set a sentinel lock that will be released when the current thread 
    state is finalized (after it is untied from the interpreter).

    This is a private API for the threading module."""
    # see issue 18808. We need to release this lock just before exiting any thread!
    ec = space.getexecutioncontext()
    # after forking the lock must be recreated! forget the old lock
    lock = Lock(space)
    ec._sentinel_lock = lock
    return lock

class W_RLock(W_Root):
    def __init__(self, space):
        self.rlock_count = 0
        self.rlock_owner = 0
        try:
            self.lock = rthread.allocate_lock()
        except rthread.error:
            raise wrap_thread_error(space, "cannot allocate lock")

    def descr__new__(space, w_subtype):
        self = space.allocate_instance(W_RLock, w_subtype)
        W_RLock.__init__(self, space)
        return self

    def descr__repr__(self, space):
        classname = space.getfulltypename(self)
        if self.rlock_count == 0:
            locked = "unlocked"
        else:
            locked = "locked"
        return self.getrepr(space, '%s %s object owner=%d count=%d' % (
            locked, classname, self.rlock_owner, self.rlock_count))

    @unwrap_spec(blocking=int, timeout=float)
    def acquire_w(self, space, blocking=True, timeout=-1.0):
        """Lock the lock.  `blocking` indicates whether we should wait
        for the lock to be available or not.  If `blocking` is False
        and another thread holds the lock, the method will return False
        immediately.  If `blocking` is True and another thread holds
        the lock, the method will wait for the lock to be released,
        take it and then return True.
        (note: the blocking operation is not interruptible.)

        In all other cases, the method will return True immediately.
        Precisely, if the current thread already holds the lock, its
        internal counter is simply incremented. If nobody holds the lock,
        the lock is taken and its internal counter initialized to 1."""
        microseconds = parse_acquire_args(space, blocking, timeout)
        tid = rthread.get_ident()
        if self.rlock_count > 0 and tid == self.rlock_owner:
            try:
                self.rlock_count = ovfcheck(self.rlock_count + 1)
            except OverflowError:
                raise oefmt(space.w_OverflowError,
                            "internal lock count overflowed")
            return space.w_True

        r = True
        if self.rlock_count > 0 or not self.lock.acquire(False):
            if not blocking:
                return space.w_False
            r = acquire_timed(space, self.lock, microseconds)
            r = (r == RPY_LOCK_ACQUIRED)
        if r:
            assert self.rlock_count == 0
            self.rlock_owner = tid
            self.rlock_count = 1

        return space.newbool(r)

    def release_w(self, space):
        """Release the lock, allowing another thread that is blocked waiting for
        the lock to acquire the lock.  The lock must be in the locked state,
        and must be locked by the same thread that unlocks it; otherwise a
        `RuntimeError` is raised.

        Do note that if the lock was acquire()d several times in a row by the
        current thread, release() needs to be called as many times for the lock
        to be available for other threads."""
        tid = rthread.get_ident()
        if self.rlock_count == 0 or self.rlock_owner != tid:
            raise oefmt(space.w_RuntimeError,
                        "cannot release un-acquired lock")
        self.rlock_count -= 1
        if self.rlock_count == 0:
            self.rlock_owner = 0
            self.lock.release()

    def is_owned_w(self, space):
        """For internal use by `threading.Condition`."""
        tid = rthread.get_ident()
        if self.rlock_count > 0 and self.rlock_owner == tid:
            return space.w_True
        else:
            return space.w_False

    def acquire_restore_w(self, space, w_saved_state):
        """For internal use by `threading.Condition`."""
        # saved_state is the value returned by release_save()
        w_count, w_owner = space.unpackiterable(w_saved_state, 2)
        count = space.int_w(w_count)
        owner = space.int_w(w_owner)
        r = True
        if not self.lock.acquire(False):
            r = self.lock.acquire(True)
        if not r:
            raise wrap_thread_error(space, "coult not acquire lock")
        assert self.rlock_count == 0
        self.rlock_owner = owner
        self.rlock_count = count

    def release_save_w(self, space):
        """For internal use by `threading.Condition`."""
        if self.rlock_count == 0:
            raise oefmt(space.w_RuntimeError,
                        "cannot release un-acquired lock")
        count, self.rlock_count = self.rlock_count, 0
        owner, self.rlock_owner = self.rlock_owner, 0
        self.lock.release()
        return space.newtuple([space.newint(count), space.newint(owner)])

    def descr__enter__(self, space):
        self.acquire_w(space)
        return self

    def descr__exit__(self, space, __args__):
        self.release_w(space)

    def descr_at_fork_reinit(self, space):
        # XXX not good enough, cpython leaks the OS lock
        self.__init__(space)


W_RLock.typedef = TypeDef(
    "_thread.RLock",
    __new__ = interp2app(W_RLock.descr__new__.im_func),
    acquire = interp2app(W_RLock.acquire_w),
    release = interp2app(W_RLock.release_w),
    _is_owned = interp2app(W_RLock.is_owned_w),
    _acquire_restore = interp2app(W_RLock.acquire_restore_w),
    _release_save = interp2app(W_RLock.release_save_w),
    __enter__ = interp2app(W_RLock.descr__enter__),
    __exit__ = interp2app(W_RLock.descr__exit__),
    __weakref__ = make_weakref_descr(W_RLock),
    __repr__ = interp2app(W_RLock.descr__repr__),
    _at_fork_reinit = interp2app(W_RLock.descr_at_fork_reinit),
    )
