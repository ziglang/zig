"""
An RPython implementation of sockets based on rffi.
Note that the interface has to be slightly different - this is not
a drop-in replacement for the 'socket' module.
"""

# XXX this does not support yet the least common AF_xxx address families
# supported by CPython.  See http://bugs.pypy.org/issue1942

from errno import EINVAL
from rpython.rlib import _rsocket_rffi as _c, jit, rgc
from rpython.rlib.buffer import LLBuffer
from rpython.rlib.objectmodel import (
    specialize, instantiate, keepalive_until_here)
from rpython.rlib.rarithmetic import intmask, r_uint
from rpython.rlib import rthread, rposix
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem.rffi import sizeof, offsetof
from rpython.rtyper.extregistry import ExtRegistryEntry


# Usage of @jit.dont_look_inside in this file is possibly temporary
# and only because some lltypes declared in _rsocket_rffi choke the
# JIT's codewriter right now (notably, FixedSizeArray).
INVALID_SOCKET = _c.INVALID_SOCKET


def mallocbuf(buffersize):
    return lltype.malloc(rffi.CCHARP.TO, buffersize, flavor='raw')


constants = _c.constants
locals().update(constants)  # Define constants from _c

HAS_SO_PROTOCOL = hasattr(_c, 'SO_PROTOCOL')

if _c.WIN32:
    from rpython.rlib import rwin32

    def rsocket_startup():
        wsadata = lltype.malloc(_c.WSAData, flavor='raw', zero=True)
        try:
            res = _c.WSAStartup(0x0101, wsadata)
            assert res == 0
        finally:
            lltype.free(wsadata, flavor='raw')
else:
    def rsocket_startup():
        pass


def ntohs(x):
    assert isinstance(x, int)
    return rffi.cast(lltype.Signed, _c.ntohs(x))

def ntohl(x):
    # accepts and returns an Unsigned
    return rffi.cast(lltype.Unsigned, _c.ntohl(x))

def htons(x):
    assert isinstance(x, int)
    return rffi.cast(lltype.Signed, _c.htons(x))

def htonl(x):
    # accepts and returns an Unsigned
    return rffi.cast(lltype.Unsigned, _c.htonl(x))


_FAMILIES = {}

class Address(object):
    """The base class for RPython-level objects representing addresses.
    Fields:  addr    - a _c.sockaddr_ptr (memory owned by the Address instance)
             addrlen - size used within 'addr'
    """
    class __metaclass__(type):
        def __new__(cls, name, bases, dict):
            family = dict.get('family')
            A = type.__new__(cls, name, bases, dict)
            if family is not None:
                _FAMILIES[family] = A
            return A

    # default uninitialized value: NULL ptr
    addr_p = lltype.nullptr(_c.sockaddr_ptr.TO)

    def __init__(self, addr, addrlen):
        self.addr_p = addr
        self.addrlen = addrlen

    @rgc.must_be_light_finalizer
    def __del__(self):
        if self.addr_p:
            lltype.free(self.addr_p, flavor='raw', track_allocation=False)

    @specialize.ll()
    def setdata(self, addr, addrlen):
        # initialize self.addr and self.addrlen.  'addr' can be a different
        # pointer type than exactly sockaddr_ptr, and we cast it for you.
        assert not self.addr_p
        self.addr_p = rffi.cast(_c.sockaddr_ptr, addr)
        self.addrlen = addrlen

    # the following slightly strange interface is needed to manipulate
    # what self.addr_p points to in a safe way.  The problem is that
    # after inlining we might end up with operations that looks like:
    #    addr = self.addr_p
    #    <self is freed here, and its __del__ calls lltype.free()>
    #    read from addr
    # To prevent this we have to insert a keepalive after the last
    # use of 'addr'.  The interface to do that is called lock()/unlock()
    # because it strongly reminds callers not to forget unlock().
    #
    @specialize.ll()
    def lock(self, TYPE=_c.sockaddr):
        """Return self.addr_p, cast as a pointer to TYPE.  Must call unlock()!
        """
        return rffi.cast(lltype.Ptr(TYPE), self.addr_p)

    def unlock(self):
        """To call after we're done with the pointer returned by lock().
        Note that locking and unlocking costs nothing at run-time.
        """
        keepalive_until_here(self)

# ____________________________________________________________

def makeipaddr(name, result=None):
    # Convert a string specifying a host name or one of a few symbolic
    # names to an IPAddress instance.  This usually calls getaddrinfo()
    # to do the work; the names "" and "<broadcast>" are special.
    # If 'result' is specified it must be a prebuilt INETAddress or
    # INET6Address that is filled; otherwise a new INETXAddress is returned.
    if result is None:
        family = AF_UNSPEC
    else:
        family = result.family

    if len(name) == 0:
        info = getaddrinfo(None, "0",
                           family=family,
                           socktype=SOCK_DGRAM,   # dummy
                           flags=AI_PASSIVE,
                           address_to_fill=result)
        if len(info) > 1:
            raise RSocketError("wildcard resolved to multiple addresses")
        return info[0][4]

    # IPv4 also supports the special name "<broadcast>".
    if name == '<broadcast>':
        return makeipv4addr(r_uint(INADDR_BROADCAST), result)

    # "dd.dd.dd.dd" format.
    digits = name.split('.')
    if len(digits) == 4:
        try:
            d0 = int(digits[0])
            d1 = int(digits[1])
            d2 = int(digits[2])
            d3 = int(digits[3])
        except ValueError:
            pass
        else:
            if (0 <= d0 <= 255 and 0 <= d1 <= 255 and
                    0 <= d2 <= 255 and 0 <= d3 <= 255):
                addr = intmask(d0 << 24) | (d1 << 16) | (d2 << 8) | (d3 << 0)
                addr = rffi.cast(rffi.UINT, addr)
                addr = htonl(addr)
                return makeipv4addr(addr, result)

    # generic host name to IP conversion
    info = getaddrinfo(name, None, family=family, address_to_fill=result)
    return info[0][4]

class IPAddress(Address):
    """AF_INET and AF_INET6 addresses"""

    def get_host(self):
        # Create a string object representing an IP address.
        # For IPv4 this is always a string of the form 'dd.dd.dd.dd'
        # (with variable size numbers).
        host, serv = getnameinfo(self, NI_NUMERICHOST | NI_NUMERICSERV)
        return host

    def lock_in_addr(self):
        """ Purely abstract
        """
        raise NotImplementedError

# ____________________________________________________________

HAS_AF_PACKET = 'AF_PACKET' in constants
if HAS_AF_PACKET:
    class PacketAddress(Address):
        family = AF_PACKET
        struct = _c.sockaddr_ll
        maxlen = minlen = sizeof(struct)
        ifr_name_size = _c.ifreq.c_ifr_name.length
        sll_addr_size = _c.sockaddr_ll.c_sll_addr.length

        def __init__(self, ifindex, protocol, pkttype=0, hatype=0, haddr=""):
            addr = lltype.malloc(_c.sockaddr_ll, flavor='raw', zero=True,
                                 track_allocation=False)
            self.setdata(addr, PacketAddress.maxlen)
            rffi.setintfield(addr, 'c_sll_family', AF_PACKET)
            rffi.setintfield(addr, 'c_sll_protocol', htons(protocol))
            rffi.setintfield(addr, 'c_sll_ifindex', ifindex)
            rffi.setintfield(addr, 'c_sll_pkttype', pkttype)
            rffi.setintfield(addr, 'c_sll_hatype', hatype)
            halen = rffi.str2chararray(haddr,
                                       rffi.cast(rffi.CCHARP, addr.c_sll_addr),
                                       PacketAddress.sll_addr_size)
            rffi.setintfield(addr, 'c_sll_halen', halen)

        @staticmethod
        def get_ifindex_from_ifname(fd, ifname):
            p = lltype.malloc(_c.ifreq, flavor='raw')
            iflen = rffi.str2chararray(ifname,
                                       rffi.cast(rffi.CCHARP, p.c_ifr_name),
                                       PacketAddress.ifr_name_size - 1)
            p.c_ifr_name[iflen] = '\0'
            err = _c.ioctl(fd, _c.SIOCGIFINDEX, p)
            ifindex = p.c_ifr_ifindex
            lltype.free(p, flavor='raw')
            if err != 0:
                raise RSocketError("invalid interface name")
            return ifindex

        def get_ifname(self, fd):
            ifname = ""
            a = self.lock(_c.sockaddr_ll)
            ifindex = rffi.getintfield(a, 'c_sll_ifindex')
            if ifindex:
                p = lltype.malloc(_c.ifreq, flavor='raw')
                rffi.setintfield(p, 'c_ifr_ifindex', ifindex)
                if (_c.ioctl(fd, _c.SIOCGIFNAME, p) == 0):
                    ifname = rffi.charp2strn(
                        rffi.cast(rffi.CCHARP, p.c_ifr_name),
                        PacketAddress.ifr_name_size)
                lltype.free(p, flavor='raw')
            self.unlock()
            return ifname

        def get_protocol(self):
            a = self.lock(_c.sockaddr_ll)
            proto = rffi.getintfield(a, 'c_sll_protocol')
            res = ntohs(proto)
            self.unlock()
            return res

        def get_pkttype(self):
            a = self.lock(_c.sockaddr_ll)
            res = rffi.getintfield(a, 'c_sll_pkttype')
            self.unlock()
            return res

        def get_hatype(self):
            a = self.lock(_c.sockaddr_ll)
            res = rffi.getintfield(a, 'c_sll_hatype')
            self.unlock()
            return res

        def get_haddr(self):
            a = self.lock(_c.sockaddr_ll)
            lgt = rffi.getintfield(a, 'c_sll_halen')
            d = []
            for i in range(lgt):
                d.append(a.c_sll_addr[i])
            res = "".join(d)
            self.unlock()
            return res


class INETAddress(IPAddress):
    family = AF_INET
    struct = _c.sockaddr_in
    maxlen = minlen = sizeof(struct)

    def __init__(self, host, port):
        makeipaddr(host, self)
        a = self.lock(_c.sockaddr_in)
        rffi.setintfield(a, 'c_sin_port', htons(port))
        self.unlock()

    def __repr__(self):
        try:
            return '<INETAddress %s:%d>' % (self.get_host(), self.get_port())
        except SocketError:
            return '<INETAddress ?>'

    def get_port(self):
        a = self.lock(_c.sockaddr_in)
        port = ntohs(rffi.getintfield(a, 'c_sin_port'))
        self.unlock()
        return port

    def eq(self, other):   # __eq__() is not called by RPython :-/
        return (isinstance(other, INETAddress) and
                self.get_host() == other.get_host() and
                self.get_port() == other.get_port())

    def from_in_addr(in_addr):
        result = instantiate(INETAddress)
        # store the malloc'ed data into 'result' as soon as possible
        # to avoid leaks if an exception occurs inbetween
        sin = lltype.malloc(_c.sockaddr_in, flavor='raw', zero=True,
                            track_allocation=False)
        result.setdata(sin, sizeof(_c.sockaddr_in))
        # PLAT sin_len
        rffi.setintfield(sin, 'c_sin_family', AF_INET)
        rffi.structcopy(sin.c_sin_addr, in_addr)
        return result
    from_in_addr = staticmethod(from_in_addr)

    def lock_in_addr(self):
        a = self.lock(_c.sockaddr_in)
        p = rffi.cast(rffi.VOIDP, a.c_sin_addr)
        return p, sizeof(_c.in_addr)

# ____________________________________________________________

class INET6Address(IPAddress):
    family = AF_INET6
    struct = _c.sockaddr_in6
    maxlen = minlen = sizeof(struct)

    def __init__(self, host, port, flowinfo=0, scope_id=0):
        makeipaddr(host, self)
        a = self.lock(_c.sockaddr_in6)
        rffi.setintfield(a, 'c_sin6_port', htons(port))
        rffi.setintfield(a, 'c_sin6_flowinfo', htonl(flowinfo))
        rffi.setintfield(a, 'c_sin6_scope_id', scope_id)
        self.unlock()

    def __repr__(self):
        try:
            return '<INET6Address %s:%d %d %d>' % (self.get_host(),
                                                   self.get_port(),
                                                   self.get_flowinfo(),
                                                   self.get_scope_id())
        except SocketError:
            return '<INET6Address ?>'

    def get_port(self):
        a = self.lock(_c.sockaddr_in6)
        port = ntohs(rffi.getintfield(a, 'c_sin6_port'))
        self.unlock()
        return port

    def get_flowinfo(self):
        a = self.lock(_c.sockaddr_in6)
        flowinfo = ntohl(a.c_sin6_flowinfo)
        self.unlock()
        return rffi.cast(lltype.Unsigned, flowinfo)

    def get_scope_id(self):
        a = self.lock(_c.sockaddr_in6)
        scope_id = a.c_sin6_scope_id
        self.unlock()
        return rffi.cast(lltype.Unsigned, scope_id)

    def eq(self, other):   # __eq__() is not called by RPython :-/
        return (isinstance(other, INET6Address) and
                self.get_host() == other.get_host() and
                self.get_port() == other.get_port() and
                self.get_flowinfo() == other.get_flowinfo() and
                self.get_scope_id() == other.get_scope_id())

    def from_in6_addr(in6_addr):
        result = instantiate(INET6Address)
        # store the malloc'ed data into 'result' as soon as possible
        # to avoid leaks if an exception occurs inbetween
        sin = lltype.malloc(_c.sockaddr_in6, flavor='raw', zero=True,
                            track_allocation=False)
        result.setdata(sin, sizeof(_c.sockaddr_in6))
        rffi.setintfield(sin, 'c_sin6_family', AF_INET6)
        rffi.structcopy(sin.c_sin6_addr, in6_addr)
        return result
    from_in6_addr = staticmethod(from_in6_addr)

    def lock_in_addr(self):
        a = self.lock(_c.sockaddr_in6)
        p = rffi.cast(rffi.VOIDP, a.c_sin6_addr)
        return p, sizeof(_c.in6_addr)

# ____________________________________________________________

HAS_AF_UNIX = 'AF_UNIX' in constants
if HAS_AF_UNIX:
    class UNIXAddress(Address):
        family = AF_UNIX
        struct = _c.sockaddr_un
        minlen = offsetof(_c.sockaddr_un, 'c_sun_path')
        maxlen = sizeof(struct)

        def __init__(self, path):
            sun = lltype.malloc(_c.sockaddr_un, flavor='raw', zero=True,
                                track_allocation=False)
            baseofs = offsetof(_c.sockaddr_un, 'c_sun_path')
            self.setdata(sun, baseofs + len(path))
            rffi.setintfield(sun, 'c_sun_family', AF_UNIX)
            if _c.linux and path[0] == '\x00':
                # Linux abstract namespace extension
                if len(path) > sizeof(_c.sockaddr_un.c_sun_path):
                    raise RSocketError("AF_UNIX path too long")
            else:
                # regular NULL-terminated string
                if len(path) >= sizeof(_c.sockaddr_un.c_sun_path):
                    raise RSocketError("AF_UNIX path too long")
                sun.c_sun_path[len(path)] = '\x00'
            for i in range(len(path)):
                sun.c_sun_path[i] = path[i]

        def __repr__(self):
            try:
                return '<UNIXAddress %r>' % (self.get_path(),)
            except SocketError:
                return '<UNIXAddress ?>'

        def get_path(self):
            a = self.lock(_c.sockaddr_un)
            maxlength = self.addrlen - offsetof(_c.sockaddr_un, 'c_sun_path')
            if _c.linux and maxlength > 0 and a.c_sun_path[0] == '\x00':
                # Linux abstract namespace
                length = maxlength
            else:
                # regular NULL-terminated string
                length = 0
                while length < maxlength and a.c_sun_path[length] != '\x00':
                    length += 1
            result = ''.join([a.c_sun_path[i] for i in range(length)])
            self.unlock()
            return result

        def eq(self, other):   # __eq__() is not called by RPython :-/
            return (isinstance(other, UNIXAddress) and
                    self.get_path() == other.get_path())

HAS_AF_NETLINK = 'AF_NETLINK' in constants
if HAS_AF_NETLINK:
    class NETLINKAddress(Address):
        family = AF_NETLINK
        struct = _c.sockaddr_nl
        maxlen = minlen = sizeof(struct)

        def __init__(self, pid, groups):
            addr = lltype.malloc(_c.sockaddr_nl, flavor='raw', zero=True,
                                 track_allocation=False)
            self.setdata(addr, NETLINKAddress.maxlen)
            rffi.setintfield(addr, 'c_nl_family', AF_NETLINK)
            rffi.setintfield(addr, 'c_nl_pid', pid)
            rffi.setintfield(addr, 'c_nl_groups', groups)

        def get_pid(self):
            a = self.lock(_c.sockaddr_nl)
            pid = a.c_nl_pid
            self.unlock()
            return rffi.cast(lltype.Unsigned, pid)

        def get_groups(self):
            a = self.lock(_c.sockaddr_nl)
            groups = a.c_nl_groups
            self.unlock()
            return rffi.cast(lltype.Unsigned, groups)

        def __repr__(self):
            return '<NETLINKAddress %r %r>' % (self.get_pid(), self.get_groups())

# ____________________________________________________________

HAVE_SOCK_NONBLOCK = "SOCK_NONBLOCK" in constants
HAVE_SOCK_CLOEXEC = "SOCK_CLOEXEC" in constants

def familyclass(family):
    return _FAMILIES.get(family, Address)
af_get = familyclass

def make_address(addrptr, addrlen, result=None):
    family = rffi.cast(lltype.Signed, addrptr.c_sa_family)
    if result is None:
        result = instantiate(familyclass(family))
    elif result.family != family:
        raise RSocketError("address family mismatched")
    # copy into a new buffer the address that 'addrptr' points to
    addrlen = rffi.cast(lltype.Signed, addrlen)
    buf = lltype.malloc(rffi.CCHARP.TO, addrlen, flavor='raw',
                        track_allocation=False)
    src = rffi.cast(rffi.CCHARP, addrptr)
    for i in range(addrlen):
        buf[i] = src[i]
    result.setdata(buf, addrlen)
    return result

def makeipv4addr(s_addr, result=None):
    if result is None:
        result = instantiate(INETAddress)
    elif result.family != AF_INET:
        raise RSocketError("address family mismatched")
    sin = lltype.malloc(_c.sockaddr_in, flavor='raw', zero=True,
                        track_allocation=False)
    result.setdata(sin, sizeof(_c.sockaddr_in))
    rffi.setintfield(sin, 'c_sin_family', AF_INET)   # PLAT sin_len
    rffi.setintfield(sin.c_sin_addr, 'c_s_addr', s_addr)
    return result

def make_null_address(family):
    klass = familyclass(family)
    result = instantiate(klass)
    buf = lltype.malloc(rffi.CCHARP.TO, klass.maxlen, flavor='raw', zero=True,
                        track_allocation=False)
    # Initialize the family to the correct value.  Avoids surprizes on
    # Windows when calling a function that unexpectedly does not set
    # the output address (e.g. recvfrom() on a connected IPv4 socket).
    rffi.setintfield(rffi.cast(_c.sockaddr_ptr, buf), 'c_sa_family', family)
    result.setdata(buf, 0)
    return result, klass.maxlen

# ____________________________________________________________

class RSocket(object):
    """RPython-level socket object.
    """
    fd = _c.INVALID_SOCKET
    family = 0
    type = 0
    proto = 0
    timeout = -1.0

    def __init__(self, family=AF_INET, type=SOCK_STREAM, proto=0,
                 fd=_c.INVALID_SOCKET, inheritable=True):
        """Create a new socket."""
        if _c.invalid_socket(fd):
            if not inheritable and HAVE_SOCK_CLOEXEC:
                # Non-inheritable: we try to call socket() with
                # SOCK_CLOEXEC, which may fail.  If we get EINVAL,
                # then we fall back to the SOCK_CLOEXEC-less case.
                fd = _c.socket(family, type | SOCK_CLOEXEC, proto)
                if fd < 0:
                    if _c.geterrno() == EINVAL:
                        # Linux older than 2.6.27 does not support
                        # SOCK_CLOEXEC.  An EINVAL might be caused by
                        # random other things, though.  Don't cache.
                        pass
                    else:
                        raise self.error_handler()
            if _c.invalid_socket(fd):
                fd = _c.socket(family, type, proto)
                if _c.invalid_socket(fd):
                    raise self.error_handler()
                if not inheritable:
                    sock_set_inheritable(fd, False)
        # PLAT RISCOS
        self.fd = fd
        self.family = family
        self.type = type
        if HAVE_SOCK_CLOEXEC:
            self.type &= ~SOCK_CLOEXEC
        if HAVE_SOCK_NONBLOCK:
            self.type &= ~SOCK_NONBLOCK
        self.proto = proto
        if HAVE_SOCK_NONBLOCK and type & SOCK_NONBLOCK:
            self.timeout = 0.0
        else:
            self.settimeout(defaults.timeout)

    @staticmethod
    def empty_rsocket():
        rsocket = instantiate(RSocket)
        return rsocket

    @rgc.must_be_light_finalizer
    def __del__(self):
        fd = self.fd
        if fd != _c.INVALID_SOCKET:
            self.fd = _c.INVALID_SOCKET
            _c.socketclose_no_errno(fd)

    if hasattr(_c, 'fcntl'):
        def _setblocking(self, block):
            orig_delay_flag = intmask(_c.fcntl(self.fd, _c.F_GETFL, 0))
            if orig_delay_flag == -1:
                raise self.error_handler()
            if block:
                delay_flag = orig_delay_flag & ~_c.O_NONBLOCK
            else:
                delay_flag = orig_delay_flag | _c.O_NONBLOCK
            if orig_delay_flag != delay_flag:
                if _c.fcntl(self.fd, _c.F_SETFL, delay_flag) == -1:
                    raise self.error_handler()
    elif hasattr(_c, 'ioctlsocket'):
        def _setblocking(self, block):
            flag = lltype.malloc(rffi.ULONGP.TO, 1, flavor='raw')
            flag[0] = rffi.cast(rffi.ULONG, not block)
            try:
                if _c.ioctlsocket(self.fd, _c.FIONBIO, flag) != 0:
                    raise self.error_handler()
            finally:
                lltype.free(flag, flavor='raw')

    if hasattr(_c, 'poll') and not _c.poll_may_be_broken:
        def _select(self, for_writing):
            """Returns 0 when reading/writing is possible,
            1 when timing out and -1 on error."""
            if self.timeout <= 0.0 or self.fd == _c.INVALID_SOCKET:
                # blocking I/O or no socket.
                return 0
            pollfd = rffi.make(_c.pollfd)
            try:
                rffi.setintfield(pollfd, 'c_fd', self.fd)
                if for_writing:
                    rffi.setintfield(pollfd, 'c_events', _c.POLLOUT)
                else:
                    rffi.setintfield(pollfd, 'c_events', _c.POLLIN)
                timeout = int(self.timeout * 1000.0 + 0.5)
                n = _c.poll(rffi.cast(lltype.Ptr(_c.pollfdarray), pollfd),
                            1, timeout)
            finally:
                lltype.free(pollfd, flavor='raw')
            if n < 0:
                return -1
            if n == 0:
                return 1
            return 0
    else:
        # Version witout poll(): use select()
        def _select(self, for_writing):
            """Returns 0 when reading/writing is possible,
            1 when timing out and -1 on error."""
            timeout = self.timeout
            if timeout <= 0.0 or self.fd == _c.INVALID_SOCKET:
                # blocking I/O or no socket.
                return 0
            tv = rffi.make(_c.timeval)
            rffi.setintfield(tv, 'c_tv_sec', int(timeout))
            rffi.setintfield(tv, 'c_tv_usec',
                int((timeout - int(timeout)) * 1000000))
            fds = lltype.malloc(_c.fd_set.TO, flavor='raw')
            _c.FD_ZERO(fds)
            _c.FD_SET(self.fd, fds)
            null = lltype.nullptr(_c.fd_set.TO)
            if for_writing:
                n = _c.select(self.fd + 1, null, fds, null, tv)
            else:
                n = _c.select(self.fd + 1, fds, null, null, tv)
            lltype.free(fds, flavor='raw')
            lltype.free(tv, flavor='raw')
            if n < 0:
                return -1
            if n == 0:
                return 1
            return 0

    def error_handler(self):
        return last_error()

    # build a null address object, ready to be used as output argument to
    # C functions that return an address.  It must be unlock()ed after you
    # are done using addr_p.
    def _addrbuf(self):
        addr, maxlen = make_null_address(self.family)
        addrlen_p = lltype.malloc(_c.socklen_t_ptr.TO, flavor='raw')
        addrlen_p[0] = rffi.cast(_c.socklen_t, maxlen)
        return addr, addr.addr_p, addrlen_p

    @jit.dont_look_inside
    def accept(self, inheritable=True):
        """Wait for an incoming connection.
        Return (new socket fd, client address)."""
        if self._select(False) == 1:
            raise SocketTimeout
        address, addr_p, addrlen_p = self._addrbuf()
        try:
            remove_inheritable = not inheritable
            if (not inheritable and HAVE_SOCK_CLOEXEC and _c.HAVE_ACCEPT4
                    and _accept4_syscall.attempt_syscall()):
                newfd = _c.socketaccept4(self.fd, addr_p, addrlen_p,
                                         SOCK_CLOEXEC)
                if _accept4_syscall.fallback(newfd):
                    newfd = _c.socketaccept(self.fd, addr_p, addrlen_p)
                else:
                    remove_inheritable = False
            else:
                newfd = _c.socketaccept(self.fd, addr_p, addrlen_p)
            addrlen = addrlen_p[0]
        finally:
            lltype.free(addrlen_p, flavor='raw')
            address.unlock()
        if _c.invalid_socket(newfd):
            raise self.error_handler()
        if remove_inheritable:
            sock_set_inheritable(newfd, False)
        address.addrlen = rffi.cast(lltype.Signed, addrlen)
        return (newfd, address)

    def bind(self, address):
        """Bind the socket to a local address."""
        addr = address.lock()
        res = _c.socketbind(self.fd, addr, address.addrlen)
        address.unlock()
        if res < 0:
            raise self.error_handler()

    def close(self):
        """Close the socket.  It cannot be used after this call."""
        fd = self.fd
        if fd != _c.INVALID_SOCKET:
            self.fd = _c.INVALID_SOCKET
            res = _c.socketclose(fd)
            if res != 0:
                raise self.error_handler()

    def detach(self):
        fd = self.fd
        self.fd = _c.INVALID_SOCKET
        return fd

    if _c.WIN32:
        def _connect(self, address):
            """Connect the socket to a remote address."""
            addr = address.lock()
            res = _c.socketconnect(self.fd, addr, address.addrlen)
            address.unlock()
            errno = _c.geterrno()
            timeout = self.timeout
            if (timeout > 0.0 and res < 0 and
                    errno in (_c.EWOULDBLOCK, _c.WSAEWOULDBLOCK)):
                tv = rffi.make(_c.timeval)
                rffi.setintfield(tv, 'c_tv_sec', int(timeout))
                rffi.setintfield(tv, 'c_tv_usec',
                                 int((timeout - int(timeout)) * 1000000))
                fds = lltype.malloc(_c.fd_set.TO, flavor='raw')
                _c.FD_ZERO(fds)
                _c.FD_SET(self.fd, fds)
                fds_exc = lltype.malloc(_c.fd_set.TO, flavor='raw')
                _c.FD_ZERO(fds_exc)
                _c.FD_SET(self.fd, fds_exc)
                null = lltype.nullptr(_c.fd_set.TO)

                try:
                    n = _c.select(self.fd + 1, null, fds, fds_exc, tv)

                    if n > 0:
                        if _c.FD_ISSET(self.fd, fds):
                            # socket writable == connected
                            return (0, False)
                        else:
                            # per MS docs, call getsockopt() to get error
                            assert _c.FD_ISSET(self.fd, fds_exc)
                            return (self.getsockopt_int(_c.SOL_SOCKET,
                                                        _c.SO_ERROR), False)
                    elif n == 0:
                        return (_c.WSAEWOULDBLOCK, True)
                    else:
                        return (_c.geterrno(), False)

                finally:
                    lltype.free(fds, flavor='raw')
                    lltype.free(fds_exc, flavor='raw')
                    lltype.free(tv, flavor='raw')

            if res == 0:
                errno = 0
            return (errno, False)
    else:
        def _connect(self, address):
            """Connect the socket to a remote address."""
            addr = address.lock()
            res = _c.socketconnect(self.fd, addr, address.addrlen)
            address.unlock()
            errno = _c.geterrno()
            if self.timeout > 0.0 and res < 0 and errno == _c.EINPROGRESS:
                timeout = self._select(True)
                if timeout == 0:
                    res = self.getsockopt_int(_c.SOL_SOCKET, _c.SO_ERROR)
                    if res == _c.EISCONN:
                        res = 0
                    errno = res
                elif timeout == -1:
                    return (_c.geterrno(), False)
                else:
                    return (_c.EWOULDBLOCK, True)

            if res < 0:
                res = errno
            return (res, False)

    def connect(self, address):
        """Connect the socket to a remote address."""
        err, timeout = self._connect(address)
        if timeout:
            raise SocketTimeout
        if err:
            raise CSocketError(err)

    def connect_ex(self, address):
        """This is like connect(address), but returns an error code (the errno
        value) instead of raising an exception when an error occurs."""
        err, timeout = self._connect(address)
        return err

    if hasattr(_c, 'dup'):
        def dup(self, SocketClass=None):
            if SocketClass is None:
                SocketClass = RSocket
            fd = _c.dup(self.fd)
            if fd < 0:
                raise self.error_handler()
            return make_socket(fd, self.family, self.type, self.proto,
                               SocketClass=SocketClass)

    @jit.dont_look_inside
    def getpeername(self):
        """Return the address of the remote endpoint."""
        address, addr_p, addrlen_p = self._addrbuf()
        try:
            res = _c.socketgetpeername(self.fd, addr_p, addrlen_p)
            addrlen = addrlen_p[0]
        finally:
            lltype.free(addrlen_p, flavor='raw')
            address.unlock()
        if res < 0:
            raise self.error_handler()
        address.addrlen = rffi.cast(lltype.Signed, addrlen)
        return address

    @jit.dont_look_inside
    def getsockname(self):
        """Return the address of the local endpoint."""
        address, addr_p, addrlen_p = self._addrbuf()
        try:
            res = _c.socketgetsockname(self.fd, addr_p, addrlen_p)
            addrlen = addrlen_p[0]
        finally:
            lltype.free(addrlen_p, flavor='raw')
            address.unlock()
        if res < 0:
            raise self.error_handler()
        address.addrlen = rffi.cast(lltype.Signed, addrlen)
        return address

    @jit.dont_look_inside
    def getsockopt(self, level, option, maxlen):
        buf = mallocbuf(maxlen)
        try:
            bufsize_p = lltype.malloc(_c.socklen_t_ptr.TO, flavor='raw')
            try:
                bufsize_p[0] = rffi.cast(_c.socklen_t, maxlen)
                res = _c.socketgetsockopt(self.fd, level, option,
                                          buf, bufsize_p)
                if res < 0:
                    raise self.error_handler()
                size = rffi.cast(lltype.Signed, bufsize_p[0])
                assert size >= 0       # socklen_t is signed on Windows
                result = ''.join([buf[i] for i in range(size)])
            finally:
                lltype.free(bufsize_p, flavor='raw')
        finally:
            lltype.free(buf, flavor='raw')
        return result

    @jit.dont_look_inside
    def getsockopt_int(self, level, option):
        flag_p = lltype.malloc(rffi.INTP.TO, 1, flavor='raw')
        # some win32 calls use only a byte to represent a bool
        # zero out so the result is correct anyway
        flag_p[0] = rffi.cast(rffi.INT, 0)
        try:
            flagsize_p = lltype.malloc(_c.socklen_t_ptr.TO, flavor='raw')
            try:
                flagsize_p[0] = rffi.cast(_c.socklen_t, rffi.sizeof(rffi.INT))
                res = _c.socketgetsockopt(self.fd, level, option,
                                          rffi.cast(rffi.VOIDP, flag_p),
                                          flagsize_p)
                if res < 0:
                    raise self.error_handler()
                result = rffi.cast(lltype.Signed, flag_p[0])
            finally:
                lltype.free(flagsize_p, flavor='raw')
        finally:
            lltype.free(flag_p, flavor='raw')
        return result

    def gettimeout(self):
        """Return the timeout of the socket. A timeout < 0 means that
        timeouts are disabled in the socket."""
        return self.timeout

    def listen(self, backlog):
        """Enable a server to accept connections.  The backlog argument
        must be at least 1; it specifies the number of unaccepted connections
        that the system will allow before refusing new connections."""
        if backlog < 1:
            backlog = 1
        res = _c.socketlisten(self.fd, backlog)
        if res < 0:
            raise self.error_handler()

    def wait_for_data(self, for_writing):
        timeout = self._select(for_writing)
        if timeout != 0:
            if timeout == 1:
                raise SocketTimeout
            else:
                raise self.error_handler()

    def recv(self, buffersize, flags=0):
        """Receive up to buffersize bytes from the socket.  For the optional
        flags argument, see the Unix manual.  When no data is available, block
        until at least one byte is available or until the remote end is closed.
        When the remote end is closed and all data is read, return the empty
        string."""
        with rffi.scoped_alloc_buffer(buffersize) as buf:
            llbuf = LLBuffer(buf.raw, buffersize)
            read_bytes = self.recvinto(llbuf, buffersize, flags)
            return buf.str(read_bytes)

    def recvinto(self, rwbuffer, nbytes, flags=0):
        self.wait_for_data(False)
        raw = rwbuffer.get_raw_address()
        read_bytes = _c.socketrecv(self.fd, raw, nbytes, flags)
        keepalive_until_here(rwbuffer)
        if read_bytes >= 0:
            return read_bytes
        raise self.error_handler()

    @jit.dont_look_inside
    def recvfrom(self, buffersize, flags=0):
        """Like recv(buffersize, flags) but also return the sender's
        address."""
        with rffi.scoped_alloc_buffer(buffersize) as buf:
            llbuf = LLBuffer(buf.raw, buffersize)
            read_bytes, address = self.recvfrom_into(llbuf, buffersize, flags)
            return buf.str(read_bytes), address

    def recvfrom_into(self, rwbuffer, nbytes, flags=0):
        self.wait_for_data(False)
        address, addr_p, addrlen_p = self._addrbuf()
        try:
            raw = rwbuffer.get_raw_address()
            read_bytes = _c.recvfrom(self.fd, raw, nbytes, flags,
                                        addr_p, addrlen_p)
            keepalive_until_here(rwbuffer)
            addrlen = rffi.cast(lltype.Signed, addrlen_p[0])
        finally:
            lltype.free(addrlen_p, flavor='raw')
            address.unlock()
        if read_bytes >= 0:
            if addrlen:
                address.addrlen = addrlen
            else:
                address = None
            return (read_bytes, address)
        raise self.error_handler()

    def recvmsg(self, message_size, ancbufsize=0, flags=0):
        """
        Receive up to message_size bytes from a message. Also receives ancillary data.
        Returns the message, ancillary, flag and address of the sender.

        :param message_size: Maximum size of the message to be received
        :param ancbufsize:  Maximum size of the ancillary data to be received
        :param flags: Receive flag. For more details, please check the Unix manual
        :return: a tuple consisting of the message, the ancillary data, return flag and the address.
        """
        if message_size < 0:
            raise RSocketError("Invalid message size")
        with rffi.scoped_alloc_buffer(message_size) as buf:
            llbuf = LLBuffer(buf.raw, message_size)
            nbytes, ancdata, flags, address = self.recvmsg_into(
                [llbuf], ancbufsize, flags)
            return buf.str(nbytes), ancdata, flags, address

    @jit.dont_look_inside
    def recvmsg_into(self, buffers, ancbufsize=0, flags=0):
        if ancbufsize < 0:
            raise RSocketError("invalid ancillary data buffer length")

        self.wait_for_data(False)
        nbuf = len(buffers)
        address, addr_p, addrlen_p = self._addrbuf()
        message_lengths = lltype.malloc(rffi.INTP.TO, nbuf, flavor='raw')
        messages = lltype.malloc(rffi.CCHARPP.TO, nbuf, flavor='raw')
        for i in range(nbuf):
            message_lengths[i] = rffi.cast(rffi.INT, buffers[i].getlength())
            messages[i] = buffers[i].get_raw_address()
        size_of_anc = lltype.malloc(rffi.SIGNEDP.TO, 1, flavor='raw')
        size_of_anc[0] = rffi.cast(rffi.SIGNED, 0)
        levels = lltype.malloc(rffi.SIGNEDPP.TO, 1, flavor='raw')
        types = lltype.malloc(rffi.SIGNEDPP.TO, 1, flavor='raw')
        file_descr = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        descr_per_anc = lltype.malloc(rffi.SIGNEDPP.TO, 1, flavor='raw')
        retflag = lltype.malloc(rffi.SIGNEDP.TO, 1, flavor='raw')
        retflag[0] = rffi.cast(rffi.SIGNED, 0)

        # a mask for the SIGNEDP's that need to be cast to int. (long default)
        reply = _c.recvmsg(
            self.fd,
            rffi.cast(lltype.Signed, ancbufsize),
            rffi.cast(lltype.Signed, flags),
            addr_p, addrlen_p,
            message_lengths, messages, rffi.cast(rffi.INT, nbuf),
            size_of_anc, levels, types, file_descr, descr_per_anc, retflag)
        if reply >= 0:
            anc_size = rffi.cast(rffi.SIGNED, size_of_anc[0])
            returnflag = rffi.cast(rffi.SIGNED, retflag[0])
            addrlen = rffi.cast(rffi.SIGNED, addrlen_p[0])
            offset = 0
            list_of_tuples = []

            pre_anc = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
            for i in range(anc_size):
                level = rffi.cast(rffi.SIGNED, levels[0][i])
                type = rffi.cast(rffi.SIGNED, types[0][i])
                bytes_in_anc = rffi.cast(rffi.SIGNED, descr_per_anc[0][i])
                pre_anc[0] = lltype.malloc(
                    rffi.CCHARP.TO, bytes_in_anc, flavor='raw')
                _c.memcpy_from_CCHARP_at_offset(
                    file_descr[0], pre_anc, rffi.cast(rffi.SIGNED, offset),
                    bytes_in_anc)
                anc = rffi.charpsize2str(pre_anc[0], bytes_in_anc)
                tup = (level, type, anc)
                list_of_tuples.append(tup)
                offset += bytes_in_anc
                lltype.free(pre_anc[0], flavor='raw')

            if addrlen:
                address.addrlen = addrlen
            else:
                address.unlock()
                address = None

            rettup = (reply, list_of_tuples, returnflag, address)

            if address is not None:
                address.unlock()
            # free underlying complexity first
            _c.freeccharp(file_descr)
            _c.freesignedp(levels)
            _c.freesignedp(types)
            _c.freesignedp(descr_per_anc)

            lltype.free(pre_anc, flavor='raw')
            lltype.free(message_lengths, flavor='raw')
            lltype.free(messages, flavor='raw')
            lltype.free(file_descr, flavor='raw')
            lltype.free(size_of_anc, flavor='raw')
            lltype.free(levels, flavor='raw')
            lltype.free(types, flavor='raw')
            lltype.free(descr_per_anc, flavor='raw')
            lltype.free(retflag, flavor='raw')
            lltype.free(addrlen_p, flavor='raw')

            return rettup
        else:
            # in case of failure the underlying complexity has already been freed
            lltype.free(message_lengths, flavor='raw')
            lltype.free(messages, flavor='raw')
            lltype.free(file_descr, flavor='raw')
            lltype.free(size_of_anc, flavor='raw')
            lltype.free(levels, flavor='raw')
            lltype.free(types, flavor='raw')
            lltype.free(descr_per_anc, flavor='raw')
            lltype.free(retflag, flavor='raw')
            lltype.free(addrlen_p, flavor='raw')

            if address is not None:
                address.unlock()
            if (_c.geterrno() == _c.EINTR) or (_c.geterrno() == 11):
                raise last_error()
            if (reply == -10000):
                raise RSocketError("Invalid message size")
            if (reply == -10001):
                raise RSocketError("Invalid ancillary data buffer length")
            if (reply == -10002):
                raise RSocketError(
                    "received malformed or improperly truncated "
                    "ancillary data")
            raise last_error()

    def send_raw(self, dataptr, length, flags=0):
        """Send data from a CCHARP buffer."""
        self.wait_for_data(True)
        res = _c.send(self.fd, dataptr, length, flags)
        if res < 0:
            raise self.error_handler()
        return res

    def send(self, data, flags=0):
        """Send a data string to the socket.  For the optional flags
        argument, see the Unix manual.  Return the number of bytes
        sent; this may be less than len(data) if the network is busy."""
        with rffi.scoped_nonmovingbuffer(data) as dataptr:
            return self.send_raw(dataptr, len(data), flags)

    def sendall(self, data, flags=0, signal_checker=None):
        """Send a data string to the socket.  For the optional flags
        argument, see the Unix manual.  This calls send() repeatedly
        until all data is sent.  If an error occurs, it's impossible
        to tell how much data has been sent."""
        with rffi.scoped_nonmovingbuffer(data) as dataptr:
            remaining = len(data)
            p = dataptr
            while remaining > 0:
                try:
                    res = self.send_raw(p, remaining, flags)
                    p = rffi.ptradd(p, res)
                    remaining -= res
                except CSocketError as e:
                    if e.errno != _c.EINTR:
                        raise
                if signal_checker is not None:
                    signal_checker()

    def sendto(self, data, length, flags, address):
        """Like send(data, flags) but allows specifying the destination
        address.  (Note that 'flags' is mandatory here.)"""
        self.wait_for_data(True)
        addr = address.lock()
        res = _c.sendto(self.fd, data, length, flags,
                        addr, address.addrlen)
        address.unlock()
        if res < 0:
            raise self.error_handler()
        return res

    @jit.dont_look_inside
    def sendmsg(self, messages, ancillary=None, flags=0, address=None):
        """
        Send data and ancillary on a socket. For use of ancillary data, please check the Unix manual.
        Work on connectionless sockets via the address parameter.
        :param messages: a message that is a list of strings
        :param ancillary: data to be sent separate from the message body. Needs to be a list of tuples.
                            E.g. [(level,type, bytes),...]. Default None.
        :param flags: the flag to be set for sendmsg. Please check the Unix manual regarding values. Default 0
        :param address: address of the recepient. Useful for when sending on connectionless sockets. Default None
        :return: Bytes sent from the message
        """
        need_to_free_address = True
        if address is None:
            need_to_free_address = False
            addr = lltype.nullptr(_c.sockaddr)
            addrlen = 0
        else:
            addr = address.lock()
            addrlen = address.addrlen

        no_of_messages = len(messages)
        messages_ptr = lltype.malloc(
            rffi.CCHARPP.TO, no_of_messages + 1, flavor='raw')
        messages_length_ptr = lltype.malloc(
            rffi.SIGNEDP.TO, no_of_messages, flavor='raw', zero=True)
        counter = 0
        for message in messages:
            messages_ptr[counter] = rffi.str2charp(message)
            messages_length_ptr[counter] = rffi.cast(rffi.SIGNED, len(message))
            counter += 1
        messages_ptr[counter] = lltype.nullptr(rffi.CCHARP.TO)
        if ancillary is not None:
            size_of_ancillary = len(ancillary)
        else:
            size_of_ancillary = 0
        levels = lltype.malloc(
            rffi.SIGNEDP.TO, size_of_ancillary, flavor='raw', zero=True)
        types = lltype.malloc(
            rffi.SIGNEDP.TO, size_of_ancillary, flavor='raw', zero=True)
        desc_per_ancillary = lltype.malloc(
            rffi.SIGNEDP.TO, size_of_ancillary, flavor='raw', zero=True)
        file_descr = lltype.malloc(
            rffi.CCHARPP.TO, size_of_ancillary, flavor='raw')
        if ancillary is not None:
            counter = 0
            for level, type, content in ancillary:
                assert isinstance(type, int)
                assert isinstance(level, int)
                levels[counter] = rffi.cast(rffi.SIGNED, level)
                types[counter] = rffi.cast(rffi.SIGNED, type)
                desc_per_ancillary[counter] = rffi.cast(
                    rffi.SIGNED, (len(content)))
                file_descr[counter] = rffi.str2charp(
                    content, track_allocation=True)
                counter += 1
        else:
            size_of_ancillary = 0
        snd_no_msgs = rffi.cast(rffi.SIGNED, no_of_messages)
        snd_anc_size = rffi.cast(rffi.SIGNED, size_of_ancillary)

        bytes_sent = _c.sendmsg(
            self.fd, addr, addrlen, messages_length_ptr, messages_ptr,
            snd_no_msgs, levels, types, file_descr,
            desc_per_ancillary, snd_anc_size, flags)

        if need_to_free_address:
            address.unlock()
        for i in range(len(messages)):
            lltype.free(messages_ptr[i], flavor='raw')
        lltype.free(messages_ptr, flavor='raw')
        lltype.free(messages_length_ptr, flavor='raw')

        if size_of_ancillary > 0:
            for i in range(len(ancillary)):
                lltype.free(file_descr[i], flavor='raw')
        lltype.free(desc_per_ancillary, flavor='raw')
        lltype.free(types, flavor='raw')
        lltype.free(levels, flavor='raw')
        lltype.free(file_descr, flavor='raw')

        self.wait_for_data(True)
        if ((bytes_sent < 0) and (bytes_sent != -1000) and
                (bytes_sent != -1001) and (bytes_sent != -1002)):
            raise last_error()

        return bytes_sent

    def setblocking(self, block):
        if block:
            timeout = -1.0
        else:
            timeout = 0.0
        self.settimeout(timeout)

    def setsockopt(self, level, option, value):
        with rffi.scoped_str2charp(value) as buf:
            res = _c.socketsetsockopt(self.fd, level, option,
                                      rffi.cast(rffi.VOIDP, buf),
                                      len(value))
            if res < 0:
                raise self.error_handler()

    def setsockopt_int(self, level, option, value):
        with lltype.scoped_alloc(rffi.INTP.TO, 1) as flag_p:
            flag_p[0] = rffi.cast(rffi.INT, value)
            res = _c.socketsetsockopt(self.fd, level, option,
                                      rffi.cast(rffi.VOIDP, flag_p),
                                      rffi.sizeof(rffi.INT))
            if res < 0:
                raise self.error_handler()

    def settimeout(self, timeout):
        """Set the timeout of the socket. A timeout < 0 means that
        timeouts are dissabled in the socket."""
        if timeout < 0.0:
            self.timeout = -1.0
        else:
            self.timeout = timeout
        self._setblocking(self.timeout < 0.0)

    def shutdown(self, how):
        """Shut down the reading side of the socket (flag == SHUT_RD), the
        writing side of the socket (flag == SHUT_WR), or both ends
        (flag == SHUT_RDWR)."""
        res = _c.socketshutdown(self.fd, how)
        if res < 0:
            raise self.error_handler()

# ____________________________________________________________

@specialize.arg(4)
def make_socket(fd, family, type, proto, SocketClass=RSocket):
    result = instantiate(SocketClass)
    result.fd = fd
    result.family = family
    result.type = type
    result.proto = proto
    result.timeout = defaults.timeout
    return result

if _c.WIN32:
    def sock_set_inheritable(fd, inheritable):
        handle = rffi.cast(rwin32.HANDLE, fd)
        try:
            rwin32.set_handle_inheritable(handle, inheritable)
        except WindowsError:
            raise RSocketError("SetHandleInformation failed")   # xxx

    def sock_get_inheritable(fd):
        handle = rffi.cast(rwin32.HANDLE, fd)
        try:
            return rwin32.get_handle_inheritable(handle)
        except WindowsError:
            raise RSocketError("GetHandleInformation failed")   # xxx
else:
    def sock_set_inheritable(fd, inheritable):
        try:
            rposix.set_inheritable(fd, inheritable)
        except OSError as e:
            raise CSocketError(e.errno)

    def sock_get_inheritable(fd):
        try:
            return rposix.get_inheritable(fd)
        except OSError as e:
            raise CSocketError(e.errno)

class SocketError(Exception):
    applevelerrcls = 'error'

    def __init__(self):
        pass

    def get_msg(self):
        return ''

    def get_msg_unicode(self):
        return self.get_msg().decode('latin-1')

    def get_msg_utf8(self):
        msg = self.get_msg()
        return msg, len(msg)

    def __str__(self):
        return self.get_msg()

class SocketErrorWithErrno(SocketError):
    def __init__(self, errno):
        self.errno = errno

class RSocketError(SocketError):
    def __init__(self, message):
        self.message = message

    def get_msg(self):
        return self.message

class CSocketError(SocketErrorWithErrno):
    def get_msg(self):
        return _c.socket_strerror_str(self.errno)

    def get_msg_unicode(self):
        return _c.socket_strerror_unicode(self.errno)

    def get_msg_utf8(self):
        return _c.socket_strerror_utf8(self.errno)


def last_error():
    return CSocketError(_c.geterrno())

class GAIError(SocketErrorWithErrno):
    applevelerrcls = 'gaierror'

    def get_msg(self):
        return _c.gai_strerror_str(self.errno)

    def get_msg_unicode(self):
        return _c.gai_strerror_unicode(self.errno)

    def get_msg_utf8(self):
        return _c.gai_strerror_utf8(self.errno)

class HSocketError(SocketError):
    applevelerrcls = 'herror'

    def __init__(self, host):
        self.host = host
        # XXX h_errno is not easily available, and hstrerror() is
        # marked as deprecated in the Linux man pages

    def get_msg(self):
        return "host lookup failed: '%s'" % (self.host,)

class SocketTimeout(SocketError):
    applevelerrcls = 'timeout'
    def get_msg(self):
        return 'timed out'

class Defaults:
    timeout = -1.0  # Blocking
defaults = Defaults()


# ____________________________________________________________
if 'AF_UNIX' not in constants or AF_UNIX is None:
    socketpair_default_family = AF_INET
else:
    socketpair_default_family = AF_UNIX

if hasattr(_c, 'socketpair'):
    def socketpair(family=socketpair_default_family, type=SOCK_STREAM, proto=0,
                   SocketClass=RSocket, inheritable=True):
        """socketpair([family[, type[, proto]]]) -> (socket object, socket object)

        Create a pair of socket objects from the sockets returned by the platform
        socketpair() function.
        The arguments are the same as for socket() except the default family is
        AF_UNIX if defined on the platform; otherwise, the default is AF_INET.
        """
        result = lltype.malloc(_c.socketpair_t, 2, flavor='raw')
        try:
            res = -1
            remove_inheritable = not inheritable
            if not inheritable and HAVE_SOCK_CLOEXEC:
                # Non-inheritable: we try to call socketpair() with
                # SOCK_CLOEXEC, which may fail.  If we get EINVAL,
                # then we fall back to the SOCK_CLOEXEC-less case.
                res = _c.socketpair(family, type | SOCK_CLOEXEC,
                                    proto, result)
                if res < 0:
                    if _c.geterrno() == EINVAL:
                        # Linux older than 2.6.27 does not support
                        # SOCK_CLOEXEC.  An EINVAL might be caused by
                        # random other things, though.  Don't cache.
                        pass
                    else:
                        raise last_error()
                else:
                    remove_inheritable = False
            #
            if res < 0:
                res = _c.socketpair(family, type, proto, result)
                if res < 0:
                    raise last_error()
            fd0 = rffi.cast(lltype.Signed, result[0])
            fd1 = rffi.cast(lltype.Signed, result[1])
        finally:
            lltype.free(result, flavor='raw')
        if remove_inheritable:
            sock_set_inheritable(fd0, False)
            sock_set_inheritable(fd1, False)
        return (make_socket(fd0, family, type, proto, SocketClass),
                make_socket(fd1, family, type, proto, SocketClass))

if _c.HAVE_SENDMSG:
    def CMSG_LEN(demanded_len):
        """
        Socket method to determine the optimal byte size of the ancillary.
        Recommended to be used when computing the ancillary size for recvmsg.
        :param demanded_len: an integer with the minimum size required.
        :return: an integer with the minimum memory needed for the required size. The value is not memory alligned
        """
        if demanded_len < 0:
            return 0
        result = _c.CMSG_LEN(demanded_len)
        return result

    def CMSG_SPACE(demanded_size):
        """
        Socket method to determine the optimal byte size of the ancillary.
        Recommended to be used when computing the ancillary size for recvmsg.
        :param demanded_size: an integer with the minimum size required.
        :return: an integer with the minimum memory needed for the required size. The value is memory alligned
        """
        if demanded_size < 0:
            return 0
        result = _c.CMSG_SPACE(demanded_size)
        return result

if _c.WIN32:
    def dup(fd, inheritable=True):
        with lltype.scoped_alloc(_c.WSAPROTOCOL_INFO, zero=True) as info:
            if _c.WSADuplicateSocket(fd, rwin32.GetCurrentProcessId(), info):
                raise last_error()
            result = _c.WSASocket(
                _c.FROM_PROTOCOL_INFO, _c.FROM_PROTOCOL_INFO,
                _c.FROM_PROTOCOL_INFO, info, 0, 0)
            if result == INVALID_SOCKET:
                raise last_error()
            return result
else:
    def dup(fd, inheritable=True):
        fd = rposix._dup(fd, inheritable)
        if fd < 0:
            raise last_error()
        return fd

def fromfd(fd, family, type, proto=0, SocketClass=RSocket, inheritable=True):
    # Dup the fd so it and the socket can be closed independently
    fd = dup(fd, inheritable=inheritable)
    return make_socket(fd, family, type, proto, SocketClass)

def getdefaulttimeout():
    return defaults.timeout

def gethostname():
    size = 1024
    buf = lltype.malloc(rffi.CCHARP.TO, size, flavor='raw')
    try:
        res = _c.gethostname(buf, size)
        if res < 0:
            raise last_error()
        return rffi.charp2strn(buf, size)
    finally:
        lltype.free(buf, flavor='raw')

def gethostbyname(name):
    # this is explicitly not working with IPv6, because the docs say it
    # should not.  Just use makeipaddr(name) for an IPv6-friendly version...
    result = instantiate(INETAddress)
    makeipaddr(name, result)
    return result

def gethost_common(hostname, hostent, addr=None):
    if not hostent:
        raise HSocketError(hostname)
    family = rffi.getintfield(hostent, 'c_h_addrtype')
    if addr is not None and addr.family != family:
        raise CSocketError(_c.EAFNOSUPPORT)

    h_aliases = hostent.c_h_aliases
    if h_aliases:   # h_aliases can be NULL, according to SF #1511317
        aliases = rffi.charpp2liststr(h_aliases)
    else:
        aliases = []

    address_list = []
    h_addr_list = hostent.c_h_addr_list
    i = 0
    paddr = h_addr_list[0]
    while paddr:
        if family == AF_INET:
            p = rffi.cast(lltype.Ptr(_c.in_addr), paddr)
            addr = INETAddress.from_in_addr(p)
        elif AF_INET6 is not None and family == AF_INET6:
            p = rffi.cast(lltype.Ptr(_c.in6_addr), paddr)
            addr = INET6Address.from_in6_addr(p)
        else:
            raise RSocketError("unknown address family")
        address_list.append(addr)
        i += 1
        paddr = h_addr_list[i]
    return (rffi.charp2str(hostent.c_h_name), aliases, address_list)

def gethostbyname_ex(name):
    # XXX use gethostbyname_r() if available instead of locks
    addr = gethostbyname(name)
    with _get_netdb_lock():
        hostent = _c.gethostbyname(name)
        return gethost_common(name, hostent, addr)

def gethostbyaddr(ip):
    # XXX use gethostbyaddr_r() if available, instead of locks
    addr = makeipaddr(ip)
    assert isinstance(addr, IPAddress)
    with _get_netdb_lock():
        p, size = addr.lock_in_addr()
        try:
            hostent = _c.gethostbyaddr(p, size, addr.family)
        finally:
            addr.unlock()
        return gethost_common(ip, hostent, addr)

# RPython magic to make _netdb_lock turn either into a regular
# rthread.Lock or a rthread.DummyLock, depending on the config
def _get_netdb_lock():
    return rthread.dummy_lock

class _Entry(ExtRegistryEntry):
    _about_ = _get_netdb_lock

    def compute_annotation(self):
        config = self.bookkeeper.annotator.translator.config
        if config.translation.thread:
            fn = _get_netdb_lock_thread
        else:
            fn = _get_netdb_lock_nothread
        return self.bookkeeper.immutablevalue(fn)

def _get_netdb_lock_nothread():
    return rthread.dummy_lock

class _LockCache(object):
    lock = None
_lock_cache = _LockCache()

@jit.elidable
def _get_netdb_lock_thread():
    if _lock_cache.lock is None:
        _lock_cache.lock = rthread.allocate_lock()
    return _lock_cache.lock
# done RPython magic

def getaddrinfo(host, port_or_service,
                family=AF_UNSPEC, socktype=0, proto=0, flags=0,
                address_to_fill=None):
    # port_or_service is a string, not an int (but try str(port_number)).
    assert port_or_service is None or isinstance(port_or_service, str)
    if _c._MACOSX and flags & AI_NUMERICSERV and \
            (port_or_service is None or port_or_service == '0'):
        port_or_service = '00'
    hints = lltype.malloc(_c.addrinfo, flavor='raw', zero=True)
    rffi.setintfield(hints, 'c_ai_family', family)
    rffi.setintfield(hints, 'c_ai_socktype', socktype)
    rffi.setintfield(hints, 'c_ai_protocol', proto)
    rffi.setintfield(hints, 'c_ai_flags', flags)
    # XXX need to lock around getaddrinfo() calls?
    p_res = lltype.malloc(rffi.CArray(_c.addrinfo_ptr), 1, flavor='raw')
    error = intmask(_c.getaddrinfo(host, port_or_service, hints, p_res))
    res = p_res[0]
    lltype.free(p_res, flavor='raw')
    lltype.free(hints, flavor='raw')
    if error:
        raise GAIError(error)
    try:
        result = []
        info = res
        while info:
            addr = make_address(info.c_ai_addr,
                                rffi.getintfield(info, 'c_ai_addrlen'),
                                address_to_fill)
            if info.c_ai_canonname:
                canonname = rffi.charp2str(info.c_ai_canonname)
            else:
                canonname = ""
            result.append((rffi.cast(lltype.Signed, info.c_ai_family),
                           rffi.cast(lltype.Signed, info.c_ai_socktype),
                           rffi.cast(lltype.Signed, info.c_ai_protocol),
                           canonname,
                           addr))
            info = info.c_ai_next
            address_to_fill = None    # don't fill the same address repeatedly
    finally:
        _c.freeaddrinfo(res)
    return result

def getservbyname(name, proto=None):
    servent = _c.getservbyname(name, proto)
    if not servent:
        raise RSocketError("service/proto not found")
    port = rffi.getintfield(servent, 'c_s_port')
    return ntohs(port)

def getservbyport(port, proto=None):
    # This function is only called from pypy/module/_socket and the range of
    # port is checked there
    assert isinstance(port, int)
    servent = _c.getservbyport(htons(port), proto)
    if not servent:
        raise RSocketError("port/proto not found")
    return rffi.charp2str(servent.c_s_name)

def getprotobyname(name):
    protoent = _c.getprotobyname(name)
    if not protoent:
        raise RSocketError("protocol not found")
    proto = protoent.c_p_proto
    return rffi.cast(lltype.Signed, proto)

def getnameinfo(address, flags):
    host = lltype.malloc(rffi.CCHARP.TO, NI_MAXHOST, flavor='raw')
    try:
        serv = lltype.malloc(rffi.CCHARP.TO, NI_MAXSERV, flavor='raw')
        try:
            addr = address.lock()
            error = intmask(_c.getnameinfo(addr, address.addrlen,
                                           host, NI_MAXHOST,
                                           serv, NI_MAXSERV, flags))
            address.unlock()
            if error:
                raise GAIError(error)
            return rffi.charp2str(host), rffi.charp2str(serv)
        finally:
            lltype.free(serv, flavor='raw')
    finally:
        lltype.free(host, flavor='raw')

@jit.dont_look_inside
def getsockopt_int(fd, level, option):
    # XXX almost the same code as RSocket.getsockopt_int
    # some win32 calls use only a byte to represent a bool
    # zero out so the result is correct anyway
    with lltype.scoped_alloc(rffi.INTP.TO, n=1, zero=True) as flag_p, \
            lltype.scoped_alloc(_c.socklen_t_ptr.TO) as flagsize_p:
        flagsize_p[0] = rffi.cast(_c.socklen_t, rffi.sizeof(rffi.INT))
        res = _c.socketgetsockopt(fd, level, option,
                                  rffi.cast(rffi.VOIDP, flag_p),
                                  flagsize_p)
        if res < 0:
            raise last_error()
        result = rffi.cast(lltype.Signed, flag_p[0])
    return result

@jit.dont_look_inside
def get_socket_family(fd):
    """Return the family of a file descriptor."""
    with lltype.scoped_alloc(_c.sockaddr, zero=True) as addr_p, \
            lltype.scoped_alloc(_c.socklen_t_ptr.TO) as addrlen_p:
        addrlen_p[0] = rffi.cast(_c.socklen_t, sizeof(_c.sockaddr))
        res = _c.socketgetsockname(fd, addr_p, addrlen_p)
        addrlen = addrlen_p[0]
        result = rffi.cast(lltype.Signed, addr_p.c_sa_family)
        if res < 0:
            raise last_error()
    return result

if hasattr(_c, 'inet_aton'):
    def inet_aton(ip):
        "IPv4 dotted string -> packed 32-bits string"
        size = sizeof(_c.in_addr)
        buf = mallocbuf(size)
        try:
            if _c.inet_aton(ip, rffi.cast(lltype.Ptr(_c.in_addr), buf)):
                return ''.join([buf[i] for i in range(size)])
            else:
                raise RSocketError("illegal IP address string passed to inet_aton")
        finally:
            lltype.free(buf, flavor='raw')
else:
    def inet_aton(ip):
        "IPv4 dotted string -> packed 32-bits string"
        if ip == "255.255.255.255":
            return "\xff\xff\xff\xff"
        packed_addr = _c.inet_addr(ip)
        if packed_addr == rffi.cast(lltype.Unsigned, INADDR_NONE):
            raise RSocketError("illegal IP address string passed to inet_aton")
        size = sizeof(_c.in_addr)
        buf = mallocbuf(size)
        try:
            rffi.cast(rffi.UINTP, buf)[0] = rffi.cast(rffi.UINT, packed_addr)
            return ''.join([buf[i] for i in range(size)])
        finally:
            lltype.free(buf, flavor='raw')

def inet_ntoa(packed):
    "packet 32-bits string -> IPv4 dotted string"
    if len(packed) != sizeof(_c.in_addr):
        raise RSocketError("packed IP wrong length for inet_ntoa")
    buf = rffi.make(_c.in_addr)
    try:
        for i in range(sizeof(_c.in_addr)):
            rffi.cast(rffi.CCHARP, buf)[i] = packed[i]
        return rffi.charp2str(_c.inet_ntoa(buf))
    finally:
        lltype.free(buf, flavor='raw')

if hasattr(_c, 'inet_pton'):
    def inet_pton(family, ip):
        "human-readable string -> packed string"
        if family == AF_INET:
            size = sizeof(_c.in_addr)
        elif AF_INET6 is not None and family == AF_INET6:
            size = sizeof(_c.in6_addr)
        else:
            raise RSocketError("unknown address family")
        buf = mallocbuf(size)
        try:
            res = _c.inet_pton(family, ip, buf)
            if res < 0:
                raise last_error()
            elif res == 0:
                raise RSocketError("illegal IP address string passed "
                                   "to inet_pton")
            else:
                return ''.join([buf[i] for i in range(size)])
        finally:
            lltype.free(buf, flavor='raw')

if hasattr(_c, 'inet_ntop'):
    def inet_ntop(family, packed):
        "packed string -> human-readable string"
        if family == AF_INET:
            srcsize = sizeof(_c.in_addr)
            dstsize = _c.INET_ADDRSTRLEN
        elif AF_INET6 is not None and family == AF_INET6:
            srcsize = sizeof(_c.in6_addr)
            dstsize = _c.INET6_ADDRSTRLEN
        else:
            raise RSocketError("unknown address family")
        if len(packed) != srcsize:
            raise ValueError("packed IP wrong length for inet_ntop")
        with rffi.scoped_nonmovingbuffer(packed) as srcbuf:
            dstbuf = mallocbuf(dstsize)
            try:
                res = _c.inet_ntop(family, rffi.cast(rffi.VOIDP, srcbuf),
                                   dstbuf, dstsize)
                if not res:
                    raise last_error()
                return rffi.charp2str(res)
            finally:
                lltype.free(dstbuf, flavor='raw')

def setdefaulttimeout(timeout):
    if timeout < 0.0:
        timeout = -1.0
    defaults.timeout = timeout

_accept4_syscall = rposix.ENoSysCache()

if hasattr(_c, 'sethostname'):
    def sethostname(hostname):
        assert hostname is not None
        with rffi.scoped_view_charp(hostname) as buf:
            res = _c.sethostname(buf, len(hostname))
            if res < 0:
                raise last_error()
