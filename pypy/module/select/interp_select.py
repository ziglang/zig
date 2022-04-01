import errno

from rpython.rlib import _rsocket_rffi as _c, rpoll
from rpython.rlib.rarithmetic import USHRT_MAX
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib import objectmodel

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt, wrap_oserror
from pypy.interpreter.gateway import (
    Unwrapper, WrappedDefault, interp2app, unwrap_spec)
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter import timeutils

defaultevents = rpoll.POLLIN | rpoll.POLLOUT | rpoll.POLLPRI


def poll(space):
    """Returns a polling object, which supports registering and
    unregistering file descriptors, and then polling them for I/O
    events.
    """
    return Poll()


class Poll(W_Root):
    def __init__(self):
        self.fddict = {}
        self.running = False

    @unwrap_spec(events="c_ushort")
    def register(self, space, w_fd, events=defaultevents):
        """
        Register a file descriptor with the polling object.
        fd -- either an integer, or an object with a fileno() method returning an
              int.
        events -- an optional bitmask describing the type of events to check for
        """
        fd = space.c_filedescriptor_w(w_fd)
        self.fddict[fd] = events

    @unwrap_spec(events="c_ushort")
    def modify(self, space, w_fd, events):
        """
        Modify an already registered file descriptor.
        fd -- either an integer, or an object with a fileno() method returning an
          int.
        events -- an optional bitmask describing the type of events to check for
        """
        fd = space.c_filedescriptor_w(w_fd)
        if fd not in self.fddict:
            raise wrap_oserror(space, OSError(errno.ENOENT, "poll.modify"),
                               w_exception_class=space.w_IOError)
        self.fddict[fd] = events

    def unregister(self, space, w_fd):
        """
        Remove a file descriptor being tracked by the polling object.
        """
        fd = space.c_filedescriptor_w(w_fd)
        try:
            del self.fddict[fd]
        except KeyError:
            raise OperationError(space.w_KeyError, space.newint(fd))

    @unwrap_spec(w_timeout=WrappedDefault(None))
    def poll(self, space, w_timeout):
        """
        Polls the set of registered file descriptors, returning a list containing
        any descriptors that have events or errors to report.

        the timeout parameter is in milliseconds"""
        if space.is_w(w_timeout, space.w_None):
            timeout = -1
            end_time = 0
        elif space.isinstance_w(w_timeout, space.w_float) or space.isinstance_w(w_timeout, space.w_int):
            if space.is_true(space.lt(w_timeout, space.newint(0))):
                timeout = -1
                end_time = 0
            else:
                timeout = space.c_int_w(space.int(w_timeout))
                end_time = timeutils.monotonic(space) + timeout * 0.001
        else:
            raise oefmt(space.w_TypeError,
                        "timeout must be an integer or None")

        if self.running:
            raise oefmt(space.w_RuntimeError, "concurrent poll() invocation")
        while True:
            self.running = True
            try:
                retval = rpoll.poll(self.fddict, timeout)
            except rpoll.PollError as e:
                if e.errno == errno.EINTR:
                    space.getexecutioncontext().checksignals()
                    timeout = int((end_time - timeutils.monotonic(space))
                                  * 1000.0 + 0.999)   # round up
                    if timeout < 0:
                        timeout = 0
                    continue
                message, lgt = e.get_msg_utf8()
                raise OperationError(space.w_OSError,
                                     space.newtuple([space.newint(e.errno),
                                                 space.newtext(message, lgt)]))
            finally:
                self.running = False
            break

        retval_w = []
        for fd, revents in retval:
            retval_w.append(space.newtuple([space.newint(fd),
                                            space.newint(revents)]))
        return space.newlist(retval_w)

pollmethods = {}
for methodname in 'register modify unregister poll'.split():
    pollmethods[methodname] = interp2app(getattr(Poll, methodname))
Poll.typedef = TypeDef('select.poll', **pollmethods)

# ____________________________________________________________

@objectmodel.always_inline  # get rid of the tuple result
def _build_fd_set(space, list_w, ll_list, nfds):
    _c.FD_ZERO(ll_list)
    fdlist = []
    for w_f in list_w:
        fd = space.c_filedescriptor_w(w_f)
        if fd > nfds:
            if _c.MAX_FD_SIZE is not None and fd >= _c.MAX_FD_SIZE:
                raise oefmt(space.w_ValueError,
                            "file descriptor out of range in select()")
            nfds = fd
        _c.FD_SET(fd, ll_list)
        fdlist.append(fd)
    return fdlist, nfds


def _unbuild_fd_set(space, list_w, fdlist, ll_list, reslist_w):
    for i in range(len(fdlist)):
        fd = fdlist[i]
        if _c.FD_ISSET(fd, ll_list):
            reslist_w.append(list_w[i])


def _call_select(space, iwtd_w, owtd_w, ewtd_w,
                 ll_inl, ll_outl, ll_errl, ll_timeval, timeout):
    fdlistin = fdlistout = fdlisterr = None
    nfds = -1
    if ll_inl:
        fdlistin, nfds = _build_fd_set(space, iwtd_w, ll_inl, nfds)
    if ll_outl:
        fdlistout, nfds = _build_fd_set(space, owtd_w, ll_outl, nfds)
    if ll_errl:
        fdlisterr, nfds = _build_fd_set(space, ewtd_w, ll_errl, nfds)

    if ll_timeval:
        end_time = timeutils.monotonic(space) + timeout
    else:
        end_time = 0.0

    while True:
        if ll_timeval:
            i = int(timeout)
            rffi.setintfield(ll_timeval, 'c_tv_sec', i)
            rffi.setintfield(ll_timeval, 'c_tv_usec', int((timeout-i)*1000000))

        res = _c.select(nfds + 1, ll_inl, ll_outl, ll_errl, ll_timeval)

        if res >= 0:
            break     # normal path
        err = _c.geterrno()
        if err != errno.EINTR:
            msg, length = _c.socket_strerror_utf8(err)
            raise OperationError(space.w_OSError, space.newtuple([
                space.newint(err), space.newtext(msg, length)]))
        # got EINTR, automatic retry
        space.getexecutioncontext().checksignals()
        if timeout > 0.0:
            timeout = end_time - timeutils.monotonic(space)
            if timeout < 0.0:
                timeout = 0.0

    resin_w = []
    resout_w = []
    reserr_w = []
    if res > 0:
        if fdlistin is not None:
            _unbuild_fd_set(space, iwtd_w, fdlistin,  ll_inl,  resin_w)
        if fdlistout is not None:
            _unbuild_fd_set(space, owtd_w, fdlistout, ll_outl, resout_w)
        if fdlisterr is not None:
            _unbuild_fd_set(space, ewtd_w, fdlisterr, ll_errl, reserr_w)
    return space.newtuple([space.newlist(resin_w),
                           space.newlist(resout_w),
                           space.newlist(reserr_w)])


@unwrap_spec(w_timeout=WrappedDefault(None))
def select(space, w_iwtd, w_owtd, w_ewtd, w_timeout):
    """Wait until one or more file descriptors are ready for some kind of I/O.
The first three arguments are sequences of file descriptors to be waited for:
rlist -- wait until ready for reading
wlist -- wait until ready for writing
xlist -- wait for an ``exceptional condition''
If only one kind of condition is required, pass [] for the other lists.
A file descriptor is either a socket or file object, or a small integer
gotten from a fileno() method call on one of those.

The optional 4th argument specifies a timeout in seconds; it may be
a floating point number to specify fractions of seconds.  If it is absent
or None, the call will never time out.

The return value is a tuple of three lists corresponding to the first three
arguments; each contains the subset of the corresponding file descriptors
that are ready.

*** IMPORTANT NOTICE ***
On Windows, only sockets are supported; on Unix, all file descriptors.
"""

    iwtd_w = space.unpackiterable(w_iwtd)
    owtd_w = space.unpackiterable(w_owtd)
    ewtd_w = space.unpackiterable(w_ewtd)

    if space.is_w(w_timeout, space.w_None):
        timeout = -1.0
    else:
        timeout = space.float_w(w_timeout)
        if timeout < 0.0:
            raise oefmt(space.w_ValueError, "timeout must be non-negative")

    ll_inl = lltype.nullptr(_c.fd_set.TO)
    ll_outl = lltype.nullptr(_c.fd_set.TO)
    ll_errl = lltype.nullptr(_c.fd_set.TO)
    ll_timeval = lltype.nullptr(_c.timeval)

    try:
        if len(iwtd_w) > 0:
            ll_inl = lltype.malloc(_c.fd_set.TO, flavor='raw')
        if len(owtd_w) > 0:
            ll_outl = lltype.malloc(_c.fd_set.TO, flavor='raw')
        if len(ewtd_w) > 0:
            ll_errl = lltype.malloc(_c.fd_set.TO, flavor='raw')
        if timeout >= 0.0:
            ll_timeval = rffi.make(_c.timeval)

        # Call this as a separate helper to avoid a large piece of code
        # in try:finally:.  Needed for calling further _always_inline_
        # helpers like _build_fd_set().
        return _call_select(space, iwtd_w, owtd_w, ewtd_w,
                            ll_inl, ll_outl, ll_errl, ll_timeval, timeout)
    finally:
        if ll_timeval:
            lltype.free(ll_timeval, flavor='raw')
        if ll_errl:
            lltype.free(ll_errl, flavor='raw')
        if ll_outl:
            lltype.free(ll_outl, flavor='raw')
        if ll_inl:
            lltype.free(ll_inl, flavor='raw')
