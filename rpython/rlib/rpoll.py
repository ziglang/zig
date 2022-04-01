"""
An RPython implementation of select.poll() based on rffi.
Note that this is not a drop-in replacement: the interface is
simplified - instead of a polling object there is only a poll()
function that directly takes a dictionary as argument.
"""

from errno import EINTR
from rpython.rlib import _rsocket_rffi as _c
from rpython.rlib.rarithmetic import r_uint
from rpython.rtyper.lltypesystem import lltype, rffi

# ____________________________________________________________
# events
#
eventnames = '''POLLIN POLLPRI POLLOUT POLLERR POLLHUP POLLNVAL
                POLLRDNORM POLLRDBAND POLLWRNORM POLLWEBAND POLLMSG
                FD_SETSIZE'''.split()

eventnames = [name for name in eventnames
                   if _c.constants.get(name) is not None]

for name in eventnames:
    globals()[name] = _c.constants[name]

class PollError(Exception):
    def __init__(self, errno):
        self.errno = errno
    def get_msg(self):
        return _c.socket_strerror_str(self.errno)
    def get_msg_unicode(self):
        return _c.socket_strerror_unicode(self.errno)
    def get_msg_utf8(self):
        return _c.socket_strerror_utf8(self.errno)

class SelectError(Exception):
    def __init__(self, errno):
        self.errno = errno
    def get_msg(self):
        return _c.socket_strerror_str(self.errno)
    def get_msg_unicode(self):
        return _c.socket_strerror_unicode(self.errno)
    def get_msg_utf8(self):
        return _c.socket_strerror_utf8(self.errno)

# ____________________________________________________________
# poll() for POSIX systems
#
if hasattr(_c, 'poll'):

    def poll(fddict, timeout=-1):
        """'fddict' maps file descriptors to interesting events.
        'timeout' is an integer in milliseconds, and NOT a float
        number of seconds, but it's the same in CPython.  Use -1 for infinite.
        Returns a list [(fd, events)].
        """
        numfd = len(fddict)
        pollfds = lltype.malloc(_c.pollfdarray, numfd, flavor='raw')
        try:
            i = 0
            for fd, events in fddict.iteritems():
                rffi.setintfield(pollfds[i], 'c_fd', fd)
                rffi.setintfield(pollfds[i], 'c_events', events)
                i += 1
            assert i == numfd

            ret = _c.poll(pollfds, numfd, timeout)

            if ret < 0:
                raise PollError(_c.geterrno())

            retval = []
            for i in range(numfd):
                pollfd = pollfds[i]
                fd      = rffi.cast(lltype.Signed, pollfd.c_fd)
                revents = rffi.cast(lltype.Signed, pollfd.c_revents)
                if revents:
                    retval.append((fd, revents))
        finally:
            lltype.free(pollfds, flavor='raw')
        return retval

def select(inl, outl, excl, timeout=-1.0, handle_eintr=False):
    nfds = 0
    if inl:
        ll_inl = lltype.malloc(_c.fd_set.TO, flavor='raw')
        _c.FD_ZERO(ll_inl)
        for i in inl:
            _c.FD_SET(i, ll_inl)
            if i > nfds:
                nfds = i
    else:
        ll_inl = lltype.nullptr(_c.fd_set.TO)
    if outl:
        ll_outl = lltype.malloc(_c.fd_set.TO, flavor='raw')
        _c.FD_ZERO(ll_outl)
        for i in outl:
            _c.FD_SET(i, ll_outl)
            if i > nfds:
                nfds = i
    else:
        ll_outl = lltype.nullptr(_c.fd_set.TO)
    if excl:
        ll_excl = lltype.malloc(_c.fd_set.TO, flavor='raw')
        _c.FD_ZERO(ll_excl)
        for i in excl:
            _c.FD_SET(i, ll_excl)
            if i > nfds:
                nfds = i
    else:
        ll_excl = lltype.nullptr(_c.fd_set.TO)

    if timeout < 0:
        ll_timeval = lltype.nullptr(_c.timeval)
        while True:
            res = _c.select(nfds + 1, ll_inl, ll_outl, ll_excl, ll_timeval)
            if not handle_eintr or res >= 0 or _c.geterrno() != EINTR:
                break
    else:
        sec = int(timeout)
        usec = int((timeout - sec) * 10**6)
        ll_timeval = rffi.make(_c.timeval)
        rffi.setintfield(ll_timeval, 'c_tv_sec', sec)
        rffi.setintfield(ll_timeval, 'c_tv_usec', usec)
        res = _c.select(nfds + 1, ll_inl, ll_outl, ll_excl, ll_timeval)
        if handle_eintr and res < 0 and _c.geterrno() == EINTR:
            res = 0  # interrupted, act as timed out
    try:
        if res == -1:
            raise SelectError(_c.geterrno())
        if res == 0:
            return ([], [], [])
        else:
            return (
                [i for i in inl if _c.FD_ISSET(i, ll_inl)],
                [i for i in outl if _c.FD_ISSET(i, ll_outl)],
                [i for i in excl if _c.FD_ISSET(i, ll_excl)])
    finally:
        if ll_inl:
            lltype.free(ll_inl, flavor='raw')
        if ll_outl:
            lltype.free(ll_outl, flavor='raw')
        if ll_excl:
            lltype.free(ll_excl, flavor='raw')
        if ll_timeval:
            lltype.free(ll_timeval, flavor='raw')

# ____________________________________________________________
# poll() for Win32
#
if hasattr(_c, 'WSAEventSelect'):
    # WSAWaitForMultipleEvents is broken. If you wish to try it,
    # rename the function to poll() and run test_exchange in test_rpoll
    def _poll(fddict, timeout=-1):
        """'fddict' maps file descriptors to interesting events.
        'timeout' is an integer in milliseconds, and NOT a float
        number of seconds, but it's the same in CPython.  Use -1 for infinite.
        Returns a list [(fd, events)].
        """
        numfd = len(fddict)
        numevents = 0
        socketevents = lltype.malloc(_c.WSAEVENT_ARRAY, numfd, flavor='raw')
        try:
            eventdict = {}

            for fd, events in fddict.iteritems():
                # select desired events
                wsaEvents = 0
                if events & _c.POLLIN:
                    wsaEvents |= _c.FD_READ | _c.FD_ACCEPT | _c.FD_CLOSE
                if events & _c.POLLOUT:
                    wsaEvents |= _c.FD_WRITE | _c.FD_CONNECT | _c.FD_CLOSE

                # if no events then ignore socket
                if wsaEvents == 0:
                    continue

                # select socket for desired events
                event = _c.WSACreateEvent()
                if _c.WSAEventSelect(fd, event, wsaEvents) != 0:
                    raise PollError(_c.geterrno())

                eventdict[fd] = event
                socketevents[numevents] = event
                numevents += 1

            assert numevents <= numfd

            # if no sockets then return immediately
            # XXX commented out by arigo - we just want to sleep for
            #     'timeout' milliseconds in this case, which is what
            #     I hope WSAWaitForMultipleEvents will do, no?
            #if numevents == 0:
            #    return []

            # prepare timeout
            if timeout < 0:
                timeout = _c.INFINITE

            # XXX does not correctly report write status of a port
            ret = _c.WSAWaitForMultipleEvents(numevents, socketevents,
                                              False, timeout, False)

            if ret == _c.WSA_WAIT_TIMEOUT:
                return []

            if ret == r_uint(_c.WSA_WAIT_FAILED):
                raise PollError(_c.geterrno())

            retval = []
            info = rffi.make(_c.WSANETWORKEVENTS)
            for fd, event in eventdict.iteritems():
                if _c.WSAEnumNetworkEvents(fd, event, info) < 0:
                    continue
                revents = 0
                if info.c_lNetworkEvents & _c.FD_READ:
                    revents |= _c.POLLIN
                if info.c_lNetworkEvents & _c.FD_ACCEPT:
                    revents |= _c.POLLIN
                if info.c_lNetworkEvents & _c.FD_WRITE:
                    revents |= _c.POLLOUT
                if info.c_lNetworkEvents & _c.FD_CONNECT:
                    if info.c_iErrorCode[_c.FD_CONNECT_BIT]:
                        revents |= _c.POLLERR
                    else:
                        revents |= _c.POLLOUT
                if info.c_lNetworkEvents & _c.FD_CLOSE:
                    if info.c_iErrorCode[_c.FD_CLOSE_BIT]:
                        revents |= _c.POLLERR
                    else:
                        if fddict[fd] & _c.POLLIN:
                            revents |= _c.POLLIN
                        if fddict[fd] & _c.POLLOUT:
                            revents |= _c.POLLOUT
                if revents:
                    retval.append((fd, revents))

            lltype.free(info, flavor='raw')

        finally:
            for fd, event in eventdict.iteritems():
                _c.WSAEventSelect(fd, event, 0)
                _c.WSACloseEvent(event)
            lltype.free(socketevents, flavor='raw')

        return retval
