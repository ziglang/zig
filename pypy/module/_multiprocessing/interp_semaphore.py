import errno
import os
import sys
import time

from rpython.rlib import jit, rgc, rthread
from rpython.rlib.rarithmetic import intmask, r_uint
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.tool import rffi_platform as platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import oefmt, wrap_oserror
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import GetSetProperty, TypeDef

RECURSIVE_MUTEX, SEMAPHORE = range(2)
sys_platform = sys.platform

if sys.platform == 'win32':
    from rpython.rlib import rwin32
    from pypy.module._multiprocessing.interp_win32_py3 import (
        _GetTickCount, handle_w)

    SEM_VALUE_MAX = int(2**31-1) # max rffi.LONG

    _CreateSemaphore = rwin32.winexternal(
        'CreateSemaphoreA', [rffi.VOIDP, rffi.LONG, rffi.LONG, rwin32.LPCSTR],
        rwin32.HANDLE,
        save_err=rffi.RFFI_FULL_LASTERROR)
    _CloseHandle_no_errno = rwin32.winexternal('CloseHandle', [rwin32.HANDLE],
        rwin32.BOOL, releasegil=False)
    _ReleaseSemaphore = rwin32.winexternal(
        'ReleaseSemaphore', [rwin32.HANDLE, rffi.LONG, rffi.LONGP],
        rwin32.BOOL,
        save_err=rffi.RFFI_SAVE_LASTERROR, releasegil=False)

    def sem_unlink(name):
        return None
else:
    from rpython.rlib import rposix

    if sys.platform == 'darwin':
        libraries = []
    else:
        libraries = ['rt']

    eci = ExternalCompilationInfo(
        includes = ['sys/time.h',
                    'limits.h',
                    'semaphore.h',
                    ],
        libraries = libraries,
        )

    class CConfig:
        _compilation_info_ = eci
        TIMEVAL = platform.Struct('struct timeval', [('tv_sec', rffi.LONG),
                                                     ('tv_usec', rffi.LONG)])
        TIMESPEC = platform.Struct('struct timespec', [('tv_sec', rffi.TIME_T),
                                                       ('tv_nsec', rffi.LONG)])
        SEM_FAILED = platform.ConstantInteger('SEM_FAILED')
        SEM_VALUE_MAX = platform.DefinedConstantInteger('SEM_VALUE_MAX')
        SEM_TIMED_WAIT = platform.Has('sem_timedwait')
        SEM_T_SIZE = platform.SizeOf('sem_t')

    config = platform.configure(CConfig)
    TIMEVAL        = config['TIMEVAL']
    TIMESPEC       = config['TIMESPEC']
    TIMEVALP       = rffi.CArrayPtr(TIMEVAL)
    TIMESPECP      = rffi.CArrayPtr(TIMESPEC)
    SEM_T          = rffi.COpaquePtr('sem_t', compilation_info=eci)
    #                rffi.cast(SEM_T, config['SEM_FAILED'])
    SEM_FAILED     = config['SEM_FAILED']
    SEM_VALUE_MAX  = config['SEM_VALUE_MAX']
    if SEM_VALUE_MAX is None:      # on Hurd
        SEM_VALUE_MAX = sys.maxint
    SEM_TIMED_WAIT = config['SEM_TIMED_WAIT']
    SEM_T_SIZE = config['SEM_T_SIZE']
    if sys.platform == 'darwin':
        HAVE_BROKEN_SEM_GETVALUE = True
    else:
        HAVE_BROKEN_SEM_GETVALUE = False

    def external(name, args, result, **kwargs):
        return rffi.llexternal(name, args, result,
                               compilation_info=eci, **kwargs)

    _sem_open = external('sem_open',
                         [rffi.CCHARP, rffi.INT, rffi.INT, rffi.UINT],
                         SEM_T, save_err=rffi.RFFI_SAVE_ERRNO)
    # sem_close is releasegil=False to be able to use it in the __del__
    _sem_close_no_errno = external('sem_close', [SEM_T], rffi.INT,
                                   releasegil=False)
    _sem_close = external('sem_close', [SEM_T], rffi.INT, releasegil=False,
                          save_err=rffi.RFFI_SAVE_ERRNO)
    _sem_unlink = external('sem_unlink', [rffi.CCHARP], rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
    _sem_wait = external('sem_wait', [SEM_T], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)
    _sem_trywait = external('sem_trywait', [SEM_T], rffi.INT,
                            save_err=rffi.RFFI_SAVE_ERRNO)
    _sem_post = external('sem_post', [SEM_T], rffi.INT, releasegil=False,
                         save_err=rffi.RFFI_SAVE_ERRNO)
    _sem_getvalue = external('sem_getvalue', [SEM_T, rffi.INTP], rffi.INT,
                             save_err=rffi.RFFI_SAVE_ERRNO)

    _gettimeofday = external('gettimeofday', [TIMEVALP, rffi.VOIDP], rffi.INT,
                             save_err=rffi.RFFI_SAVE_ERRNO)

    _select = external('select', [rffi.INT, rffi.VOIDP, rffi.VOIDP, rffi.VOIDP,
                                                          TIMEVALP], rffi.INT,
                       save_err=rffi.RFFI_SAVE_ERRNO)

    @jit.dont_look_inside
    def sem_open(name, oflag, mode, value):
        res = _sem_open(name, oflag, mode, value)
        if res == rffi.cast(SEM_T, SEM_FAILED):
            raise OSError(rposix.get_saved_errno(), "sem_open failed")
        return res

    def sem_close(handle):
        res = _sem_close(handle)
        if res < 0:
            raise OSError(rposix.get_saved_errno(), "sem_close failed")

    def sem_unlink(name):
        res = _sem_unlink(name)
        if res < 0:
            raise OSError(rposix.get_saved_errno(), "sem_unlink failed")

    def sem_wait(sem):
        res = _sem_wait(sem)
        if res < 0:
            raise OSError(rposix.get_saved_errno(), "sem_wait failed")

    def sem_trywait(sem):
        res = _sem_trywait(sem)
        if res < 0:
            raise OSError(rposix.get_saved_errno(), "sem_trywait failed")

    def sem_timedwait(sem, deadline):
        res = _sem_timedwait(sem, deadline)
        if res < 0:
            raise OSError(rposix.get_saved_errno(), "sem_timedwait failed")

    def _sem_timedwait_save(sem, deadline):
        delay = 0
        void = lltype.nullptr(rffi.VOIDP.TO)
        with lltype.scoped_alloc(TIMEVALP.TO, 1) as tvdeadline:
            while True:
                # poll
                if _sem_trywait(sem) == 0:
                    return 0
                elif rposix.get_saved_errno() != errno.EAGAIN:
                    return -1

                now = gettimeofday()
                c_tv_sec = rffi.getintfield(deadline[0], 'c_tv_sec')
                c_tv_nsec = rffi.getintfield(deadline[0], 'c_tv_nsec')
                if (c_tv_sec < now[0] or
                    (c_tv_sec == now[0] and c_tv_nsec <= now[1])):
                    rposix.set_saved_errno(errno.ETIMEDOUT)
                    return -1


                # calculate how much time is left
                difference = ((c_tv_sec - now[0]) * 1000000 +
                                    (c_tv_nsec - now[1]))

                # check delay not too long -- maximum is 20 msecs
                if delay > 20000:
                    delay = 20000
                if delay > difference:
                    delay = difference
                delay += 1000

                # sleep
                rffi.setintfield(tvdeadline[0], 'c_tv_sec', delay / 1000000)
                rffi.setintfield(tvdeadline[0], 'c_tv_usec', delay % 1000000)
                if _select(0, void, void, void, tvdeadline) < 0:
                    return -1

    if SEM_TIMED_WAIT:
        _sem_timedwait = external('sem_timedwait', [SEM_T, TIMESPECP],
                                  rffi.INT, save_err=rffi.RFFI_SAVE_ERRNO)
    else:
        _sem_timedwait = _sem_timedwait_save

    def sem_post(sem):
        res = _sem_post(sem)
        if res < 0:
            raise OSError(rposix.get_saved_errno(), "sem_post failed")

    def sem_getvalue(sem):
        sval_ptr = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
        try:
            res = _sem_getvalue(sem, sval_ptr)
            if res < 0:
                raise OSError(rposix.get_saved_errno(), "sem_getvalue failed")
            return rffi.cast(lltype.Signed, sval_ptr[0])
        finally:
            lltype.free(sval_ptr, flavor='raw')

    def gettimeofday():
        now = lltype.malloc(TIMEVALP.TO, 1, flavor='raw')
        try:
            res = _gettimeofday(now, None)
            if res < 0:
                raise OSError(rposix.get_saved_errno(), "gettimeofday failed")
            return (rffi.getintfield(now[0], 'c_tv_sec'),
                    rffi.getintfield(now[0], 'c_tv_usec'))
        finally:
            lltype.free(now, flavor='raw')

    def handle_w(space, w_handle):
        return rffi.cast(SEM_T, space.int_w(w_handle))

# utilized by POSIX and win32
def semaphore_unlink(space, w_name):
    name = space.text_w(w_name)
    try:
        sem_unlink(name)
    except OSError as e:
        raise wrap_oserror(space, e)

class CounterState:
    def __init__(self, space):
        self.counter = 0

    def _cleanup_(self):
        self.counter = 0

    def getCount(self):
        value = self.counter
        self.counter += 1
        return value

# These functions may raise bare OSError or WindowsError,
# don't forget to wrap them into OperationError

if sys.platform == 'win32':
    def create_semaphore(space, name, val, max):
        rwin32.SetLastError_saved(0)
        handle = _CreateSemaphore(rffi.NULL, val, max, rffi.NULL)
        # On Windows we should fail on ERROR_ALREADY_EXISTS
        err = rwin32.GetLastError_saved()
        if err != 0:
            raise WindowsError(err, "CreateSemaphore")
        return handle

    def delete_semaphore(handle):
        _CloseHandle_no_errno(handle)

    def semlock_acquire(self, space, block, w_timeout):
        if not block:
            full_msecs = 0
        elif space.is_none(w_timeout):
            full_msecs = rwin32.INFINITE
        else:
            timeout = space.float_w(w_timeout)
            timeout *= 1000.0
            if timeout < 0.0:
                timeout = 0.0
            elif timeout >= 0.5 * rwin32.INFINITE: # 25 days
                raise oefmt(space.w_OverflowError, "timeout is too large")
            full_msecs = r_uint(int(timeout + 0.5))

        # check whether we can acquire without blocking
        res = rwin32.WaitForSingleObject(self.handle, 0)

        if res != rwin32.WAIT_TIMEOUT:
            self.last_tid = rthread.get_ident()
            self.count += 1
            return True

        msecs = full_msecs
        start = _GetTickCount()

        while True:
            from pypy.module.time.interp_time import State
            interrupt_event = space.fromcache(State).get_interrupt_event()
            handles = [self.handle, interrupt_event]

            # do the wait
            rwin32.ResetEvent(interrupt_event)
            res = rwin32.WaitForMultipleObjects(handles, timeout=msecs)

            if res != rwin32.WAIT_OBJECT_0 + 1:
                break

            # got SIGINT so give signal handler a chance to run
            time.sleep(0.001)

            # if this is main thread let KeyboardInterrupt be raised
            _check_signals(space)

            # recalculate timeout
            if msecs != rwin32.INFINITE:
                ticks = _GetTickCount()
                if r_uint(ticks - start) >= full_msecs:
                    return False
                msecs = full_msecs - r_uint(ticks - start)

        # handle result
        if res != rwin32.WAIT_TIMEOUT:
            self.last_tid = rthread.get_ident()
            self.count += 1
            return True
        return False

    def semlock_release(self, space):
        if not _ReleaseSemaphore(self.handle, 1,
                                 lltype.nullptr(rffi.LONGP.TO)):
            err = rwin32.GetLastError_saved()
            if err == 0x0000012a: # ERROR_TOO_MANY_POSTS
                raise oefmt(space.w_ValueError,
                            "semaphore or lock released too many times")
            else:
                raise WindowsError(err, "ReleaseSemaphore")

    def semlock_getvalue(self, space):
        if rwin32.WaitForSingleObject(self.handle, 0) == rwin32.WAIT_TIMEOUT:
            return 0
        previous_ptr = lltype.malloc(rffi.LONGP.TO, 1, flavor='raw')
        try:
            if not _ReleaseSemaphore(self.handle, 1, previous_ptr):
                raise rwin32.lastSavedWindowsError("ReleaseSemaphore")
            return intmask(previous_ptr[0]) + 1
        finally:
            lltype.free(previous_ptr, flavor='raw')

    def semlock_iszero(self, space):
        return semlock_getvalue(self, space) == 0

else:
    def create_semaphore(space, name, val, max):
        sem = sem_open(name, os.O_CREAT | os.O_EXCL, 0600, val)
        rgc.add_memory_pressure(SEM_T_SIZE)
        return sem

    def reopen_semaphore(name):
        sem = sem_open(name, 0, 0600, 0)
        rgc.add_memory_pressure(SEM_T_SIZE)
        return sem

    def delete_semaphore(handle):
        _sem_close_no_errno(handle)

    def semlock_acquire(self, space, block, w_timeout):
        if not block:
            deadline = lltype.nullptr(TIMESPECP.TO)
        elif space.is_none(w_timeout):
            deadline = lltype.nullptr(TIMESPECP.TO)
        else:
            timeout = space.float_w(w_timeout)
            sec = int(timeout)
            nsec = int(1e9 * (timeout - sec) + 0.5)

            now_sec, now_usec = gettimeofday()

            deadline = lltype.malloc(TIMESPECP.TO, 1, flavor='raw')
            rffi.setintfield(deadline[0], 'c_tv_sec', now_sec + sec)
            rffi.setintfield(deadline[0], 'c_tv_nsec', now_usec * 1000 + nsec)
            val = (rffi.getintfield(deadline[0], 'c_tv_sec') +
                   rffi.getintfield(deadline[0], 'c_tv_nsec') / 1000000000)
            rffi.setintfield(deadline[0], 'c_tv_sec', val)
            val = rffi.getintfield(deadline[0], 'c_tv_nsec') % 1000000000
            rffi.setintfield(deadline[0], 'c_tv_nsec', val)
        try:
            while True:
                try:
                    if not block:
                        sem_trywait(self.handle)
                    elif not deadline:
                        sem_wait(self.handle)
                    else:
                        sem_timedwait(self.handle, deadline)
                except OSError as e:
                    if e.errno == errno.EINTR:
                        # again
                        _check_signals(space)
                        continue
                    elif e.errno in (errno.EAGAIN, errno.ETIMEDOUT):
                        return False
                    raise
                _check_signals(space)
                self.last_tid = rthread.get_ident()
                self.count += 1
                return True
        finally:
            if deadline:
                lltype.free(deadline, flavor='raw')


    def semlock_release(self, space):
        if self.kind == RECURSIVE_MUTEX:
            sem_post(self.handle)
            return
        if HAVE_BROKEN_SEM_GETVALUE:
            # We will only check properly the maxvalue == 1 case
            if self.maxvalue == 1:
                # make sure that already locked
                try:
                    sem_trywait(self.handle)
                except OSError as e:
                    if e.errno != errno.EAGAIN:
                        raise
                    # it is already locked as expected
                else:
                    # it was not locked so undo wait and raise
                    sem_post(self.handle)
                    raise oefmt(space.w_ValueError,
                                "semaphore or lock released too many times")
        else:
            # This check is not an absolute guarantee that the semaphore does
            # not rise above maxvalue.
            if sem_getvalue(self.handle) >= self.maxvalue:
                raise oefmt(space.w_ValueError,
                            "semaphore or lock released too many times")

        sem_post(self.handle)

    def semlock_getvalue(self, space):
        if HAVE_BROKEN_SEM_GETVALUE:
            raise oefmt(space.w_NotImplementedError,
                        "sem_getvalue is not implemented on this system")
        else:
            val = sem_getvalue(self.handle)
            # some posix implementations use negative numbers to indicate
            # the number of waiting threads
            if val < 0:
                val = 0
            return val

    def semlock_iszero(self, space):
        if HAVE_BROKEN_SEM_GETVALUE:
            try:
                sem_trywait(self.handle)
            except OSError as e:
                if e.errno != errno.EAGAIN:
                    raise
                return True
            else:
                sem_post(self.handle)
                return False
        else:
            return semlock_getvalue(self, space) == 0


class W_SemLock(W_Root):
    def __init__(self, space, handle, kind, maxvalue, name):
        self.handle = handle
        self.kind = kind
        self.count = 0
        self.maxvalue = maxvalue
        self.register_finalizer(space)
        self.last_tid = -1
        self.name = name

    def name_get(self, space):
        if self.name is None:
            return space.w_None
        return space.newtext(self.name)

    def kind_get(self, space):
        return space.newint(self.kind)

    def maxvalue_get(self, space):
        return space.newint(self.maxvalue)

    def handle_get(self, space):
        h = rffi.cast(rffi.INTPTR_T, self.handle)
        return space.newint(h)

    def get_count(self, space):
        return space.newint(self.count)

    def _ismine(self):
        return self.count > 0 and rthread.get_ident() == self.last_tid

    def is_mine(self, space):
        return space.newbool(self._ismine())

    def is_zero(self, space):
        try:
            res = semlock_iszero(self, space)
        except OSError as e:
            raise wrap_oserror(space, e)
        return space.newbool(res)

    def get_value(self, space):
        try:
            val = semlock_getvalue(self, space)
        except OSError as e:
            raise wrap_oserror(space, e)
        return space.newint(val)

    @unwrap_spec(block=bool)
    def acquire(self, space, block=True, w_timeout=None):
        # check whether we already own the lock
        if self.kind == RECURSIVE_MUTEX and self._ismine():
            self.count += 1
            return space.w_True
        try:
            # sets self.last_tid and increments self.count
            # those steps need to be as close as possible to
            # acquiring the semlock for self._ismine() to support
            # multiple threads
            got = semlock_acquire(self, space, block, w_timeout)
        except OSError as e:
            raise wrap_oserror(space, e)
        if got:
            return space.w_True
        else:
            return space.w_False

    def release(self, space):
        if self.kind == RECURSIVE_MUTEX:
            if not self._ismine():
                raise oefmt(space.w_AssertionError,
                            "attempt to release recursive lock not owned by "
                            "thread")
            if self.count > 1:
                self.count -= 1
                return

        try:
            # Note: a succesful semlock_release() must not release the GIL,
            # otherwise there is a race condition on self.count
            semlock_release(self, space)
            self.count -= 1
        except OSError as e:
            raise wrap_oserror(space, e)


    def after_fork(self):
        self.count = 0

    @unwrap_spec(kind=int, maxvalue=int, name='text_or_none')
    def rebuild(space, w_cls, w_handle, kind, maxvalue, name):
        #
        if sys_platform != 'win32' and name is not None:
            # like CPython, in this case ignore 'w_handle'
            try:
                handle = reopen_semaphore(name)
            except OSError as e:
                raise wrap_oserror(space, e)
        else:
            handle = handle_w(space, w_handle)
        #
        self = space.allocate_instance(W_SemLock, w_cls)
        self.__init__(space, handle, kind, maxvalue, name)
        return self

    def enter(self, space):
        return self.acquire(space, w_timeout=space.w_None)

    def exit(self, space, __args__):
        self.release(space)

    def _finalize_(self):
        delete_semaphore(self.handle)

@unwrap_spec(kind=int, value=int, maxvalue=int, name='text', unlink=int)
def descr_new(space, w_subtype, kind, value, maxvalue, name, unlink):
    if kind != RECURSIVE_MUTEX and kind != SEMAPHORE:
        raise oefmt(space.w_ValueError, "unrecognized kind")

    counter = space.fromcache(CounterState).getCount()

    try:
        handle = create_semaphore(space, name, value, maxvalue)
        if unlink:
            sem_unlink(name)
            name = None
    except OSError as e:
        raise wrap_oserror(space, e)


    self = space.allocate_instance(W_SemLock, w_subtype)
    self.__init__(space, handle, kind, maxvalue, name)

    return self

W_SemLock.typedef = TypeDef(
    "SemLock",
    __new__ = interp2app(descr_new),
    kind = GetSetProperty(W_SemLock.kind_get),
    maxvalue = GetSetProperty(W_SemLock.maxvalue_get),
    handle = GetSetProperty(W_SemLock.handle_get),
    name = GetSetProperty(W_SemLock.name_get),
    _count = interp2app(W_SemLock.get_count),
    _is_mine = interp2app(W_SemLock.is_mine),
    _is_zero = interp2app(W_SemLock.is_zero),
    _get_value = interp2app(W_SemLock.get_value),
    acquire = interp2app(W_SemLock.acquire),
    release = interp2app(W_SemLock.release),
    _rebuild = interp2app(W_SemLock.rebuild.im_func, as_classmethod=True),
    _after_fork = interp2app(W_SemLock.after_fork),
    __enter__=interp2app(W_SemLock.enter),
    __exit__=interp2app(W_SemLock.exit),
    SEM_VALUE_MAX=SEM_VALUE_MAX,
    )

def _check_signals(space):
    space.getexecutioncontext().checksignals()
