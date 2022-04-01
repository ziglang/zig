import sys, errno
from rpython.rlib import rsocket, rweaklist
from rpython.rlib.buffer import RawByteBuffer
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rarithmetic import intmask, widen, r_uint
from rpython.rlib.rsocket import (
    RSocket, AF_INET, SOCK_STREAM, SocketError, SocketErrorWithErrno,
    RSocketError, SOMAXCONN, HAS_SO_PROTOCOL,
)
from rpython.rtyper.lltypesystem import lltype, rffi

from pypy.interpreter import gateway
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.typedef import (
    GetSetProperty, TypeDef, generic_new_descr, interp_attrproperty,
    make_weakref_descr)

_WIN32 = sys.platform.startswith('win')

# XXX Hack to separate rpython and pypy
def addr_as_object(addr, fd, space):
    from rpython.rlib import _rsocket_rffi as _c
    if isinstance(addr, rsocket.INETAddress):
        return space.newtuple([space.newtext(addr.get_host()),
                               space.newint(addr.get_port())])
    elif isinstance(addr, rsocket.INET6Address):
        return space.newtuple([space.newtext(addr.get_host()),
                               space.newint(addr.get_port()),
                               space.newint(addr.get_flowinfo()),
                               space.newint(addr.get_scope_id())])
    elif rsocket.HAS_AF_PACKET and isinstance(addr, rsocket.PacketAddress):
        return space.newtuple([space.newtext(addr.get_ifname(fd)),
                               space.newint(addr.get_protocol()),
                               space.newint(addr.get_pkttype()),
                               space.newint(addr.get_hatype()),
                               space.newbytes(addr.get_haddr())])
    elif rsocket.HAS_AF_UNIX and isinstance(addr, rsocket.UNIXAddress):
        path = addr.get_path()
        if _c.linux and len(path) > 0 and path[0] == '\x00':
            # Linux abstract namespace
            return space.newbytes(path)
        else:
            return space.newfilename(path)
    elif rsocket.HAS_AF_NETLINK and isinstance(addr, rsocket.NETLINKAddress):
        return space.newtuple([space.newint(addr.get_pid()),
                               space.newint(addr.get_groups())])
    # If we don't know the address family, don't raise an
    # exception -- return it as a tuple.
    a = addr.lock()
    family = rffi.cast(lltype.Signed, a.c_sa_family)
    datalen = addr.addrlen - rsocket.offsetof(_c.sockaddr, 'c_sa_data')
    rawdata = ''.join([a.c_sa_data[i] for i in range(datalen)])
    addr.unlock()
    return space.newtuple([space.newint(family),
                           space.newtext(rawdata)])

# XXX Hack to seperate rpython and pypy
# XXX a bit of code duplication
def fill_from_object(addr, space, w_address):
    from rpython.rlib import _rsocket_rffi as _c
    if isinstance(addr, rsocket.INETAddress):
        _, w_port = space.unpackiterable(w_address, 2)
        port = space.int_w(w_port)
        port = make_ushort_port(space, port)
        a = addr.lock(_c.sockaddr_in)
        rffi.setintfield(a, 'c_sin_port', rsocket.htons(port))
        addr.unlock()
    elif isinstance(addr, rsocket.INET6Address):
        pieces_w = space.unpackiterable(w_address)
        if not (2 <= len(pieces_w) <= 4):
            raise RSocketError("AF_INET6 address must be a tuple of length 2 "
                               "to 4, not %d" % len(pieces_w))
        port = space.int_w(pieces_w[1])
        port = make_ushort_port(space, port)
        if len(pieces_w) > 2: flowinfo = space.int_w(pieces_w[2])
        else:                 flowinfo = 0
        if len(pieces_w) > 3: scope_id = space.uint_w(pieces_w[3])
        else:                 scope_id = 0
        flowinfo = make_unsigned_flowinfo(space, flowinfo)
        a = addr.lock(_c.sockaddr_in6)
        rffi.setintfield(a, 'c_sin6_port', rsocket.htons(port))
        rffi.setintfield(a, 'c_sin6_flowinfo', rsocket.htonl(flowinfo))
        rffi.setintfield(a, 'c_sin6_scope_id', scope_id)
        addr.unlock()
    else:
        raise NotImplementedError


if HAS_SO_PROTOCOL:
    def get_so_protocol(fd):
        from rpython.rlib import _rsocket_rffi as _c
        return rsocket.getsockopt_int(fd, _c.SOL_SOCKET, _c.SO_PROTOCOL)
else:
    def get_so_protocol(fd):
        return -1


def idna_converter(space, w_host):
    # Converts w_host to a byte string.  Similar to encode_idna()
    # but accepts more types and refuses NULL bytes.
    if space.isinstance_w(w_host, space.w_unicode):
        try:
            w_s = space.encode_unicode_object(w_host, 'ascii', None)
        except OperationError as e:
            if not e.match(space, space.w_UnicodeEncodeError):
                raise
            w_s = space.encode_unicode_object(w_host, 'idna', None)
        s = space.bytes_w(w_s)
    elif space.isinstance_w(w_host, space.w_bytes):
        s = space.bytes_w(w_host)
    elif space.isinstance_w(w_host, space.w_bytearray):
        s = space.charbuf_w(w_host)
    else:
        raise oefmt(space.w_TypeError,
                    "string or unicode text buffer expected, not %T", w_host)
    if '\x00' in s:
        raise oefmt(space.w_TypeError,
                    "host name must not contain null character")
    return s


# XXX Hack to seperate rpython and pypy
def addr_from_object(family, fd, space, w_address):
    family = widen(family)
    if family == rsocket.AF_INET:
        w_host, w_port = space.unpackiterable(w_address, 2)
        host = idna_converter(space, w_host)
        port = space.int_w(w_port)
        port = make_ushort_port(space, port)
        return rsocket.INETAddress(host, port)
    if family == rsocket.AF_INET6:
        pieces_w = space.unpackiterable(w_address)
        if not (2 <= len(pieces_w) <= 4):
            raise oefmt(space.w_TypeError,
                        "AF_INET6 address must be a tuple of length 2 "
                        "to 4, not %d", len(pieces_w))
        host = idna_converter(space, pieces_w[0])
        port = space.int_w(pieces_w[1])
        port = make_ushort_port(space, port)
        if len(pieces_w) > 2: flowinfo = space.int_w(pieces_w[2])
        else:                 flowinfo = 0
        if len(pieces_w) > 3: scope_id = space.uint_w(pieces_w[3])
        else:                 scope_id = 0
        flowinfo = make_unsigned_flowinfo(space, flowinfo)
        return rsocket.INET6Address(host, port, flowinfo, scope_id)
    if rsocket.HAS_AF_UNIX and family == rsocket.AF_UNIX:
        # Not using space.fsencode_w since Linux allows embedded NULs.
        if space.isinstance_w(w_address, space.w_unicode):
            w_address = space.fsencode(w_address)
        elif space.isinstance_w(w_address, space.w_bytearray):
            w_address = space.newbytes(space.charbuf_w(w_address))
        bytelike = space.bytes_w(w_address) # getarg_w('y*', w_address)
        return rsocket.UNIXAddress(bytelike)
    if rsocket.HAS_AF_NETLINK and family == rsocket.AF_NETLINK:
        w_pid, w_groups = space.unpackiterable(w_address, 2)
        return rsocket.NETLINKAddress(space.uint_w(w_pid), space.uint_w(w_groups))
    if rsocket.HAS_AF_PACKET and family == rsocket.AF_PACKET:
        pieces_w = space.unpackiterable(w_address)
        if not (2 <= len(pieces_w) <= 5):
            raise oefmt(space.w_TypeError,
                        "AF_PACKET address must be a tuple of length 2 "
                        "to 5, not %d", len(pieces_w))
        ifname = space.text_w(pieces_w[0])
        ifindex = rsocket.PacketAddress.get_ifindex_from_ifname(fd, ifname)
        protocol = space.int_w(pieces_w[1])
        if len(pieces_w) > 2: pkttype = space.int_w(pieces_w[2])
        else:                 pkttype = 0
        if len(pieces_w) > 3: hatype = space.int_w(pieces_w[3])
        else:                 hatype = 0
        if len(pieces_w) > 4: haddr = space.text_w(pieces_w[4])
        else:                 haddr = ""
        if len(haddr) > 8:
            raise oefmt(space.w_ValueError,
                        "Hardware address must be 8 bytes or less")
        if protocol < 0 or protocol > 0xfffff:
            raise oefmt(space.w_OverflowError, "protoNumber must be 0-65535.")
        return rsocket.PacketAddress(ifindex, protocol, pkttype, hatype, haddr)
    raise RSocketError("unknown address family")

# XXX Hack to seperate rpython and pypy
def make_ushort_port(space, port):
    assert isinstance(port, int)
    if port < 0 or port > 0xffff:
        raise oefmt(space.w_OverflowError, "port must be 0-65535.")
    return port

def make_unsigned_flowinfo(space, flowinfo):
    if flowinfo < 0 or flowinfo > 0xfffff:
        raise oefmt(space.w_OverflowError, "flowinfo must be 0-1048575.")
    return rffi.cast(lltype.Unsigned, flowinfo)

# XXX Hack to seperate rpython and pypy
def ipaddr_from_object(space, w_sockaddr):
    host = space.text_w(space.getitem(w_sockaddr, space.newint(0)))
    addr = rsocket.makeipaddr(host)
    fill_from_object(addr, space, w_sockaddr)
    return addr


class W_Socket(W_Root):
    def __init__(self, space, sock=None):
        self.space = space
        if sock is None:
            self.sock = RSocket.empty_rsocket()
        else:
            register_socket(space, sock)
            self.sock = sock
            self.register_finalizer(space)

    @unwrap_spec(family=int, type=int, proto=int,
                 w_fileno=WrappedDefault(None))
    def descr_init(self, space, family=-1, type=-1, proto=-1,
                   w_fileno=None):
        from rpython.rlib.rsocket import _c
        if space.is_w(w_fileno, space.w_None):
            if family == -1:
                family = AF_INET
            if type == -1:
                type = SOCK_STREAM
            if proto == -1:
                proto = 0
        # TODO: figure out a way to not slow down the non-audit case
        space.audit("socket.__new__",
                    [self, space.newint(family), space.newint(type),
                     space.newint(proto)])
        try:
            if not space.is_w(w_fileno, space.w_None):
                if _WIN32 and space.isinstance_w(w_fileno, space.w_bytes):
                    # it is possible to pass some bytes representing a socket
                    # in the file descriptor object on winodws
                    fdobj = space.bytes_w(w_fileno)
                    if len(fdobj) != rffi.sizeof(_c.WSAPROTOCOL_INFOW):
                        raise oefmt(space.w_ValueError,
                            "socket descriptor string has wrong size, should be %d bytes",
                            rffi.sizeof(_c.WSAPROTOCOL_INFOW))
                    info_charptr = rffi.str2charp(fdobj)
                    try:
                        info_ptr = rffi.cast(lltype.Ptr(_c.WSAPROTOCOL_INFOW), info_charptr)
                        type = info_ptr.c_iSocketType 
                        fd = _c.WSASocketW(_c.FROM_PROTOCOL_INFO, _c.FROM_PROTOCOL_INFO,
                        _c.FROM_PROTOCOL_INFO, info_ptr, 0, _c.WSA_FLAG_OVERLAPPED)
                        if fd == rsocket.INVALID_SOCKET:
                            raise converted_error(space, rsocket.last_error())
                        sock = RSocket(info_ptr.c_iAddressFamily, info_ptr.c_iSocketType, info_ptr.c_iProtocol, fd)
                    finally:
                        lltype.free(info_charptr, flavor='raw')
                else:
                    if space.isinstance_w(w_fileno, space.w_float):
                        raise oefmt(space.w_TypeError,
                            "integer argument expected, got float")
                    fd = space.int_w(w_fileno)
                    if ((_WIN32 and r_uint(fd) == rsocket.INVALID_SOCKET) or (fd < 0)):
                        raise oefmt(space.w_ValueError,
                            "negative file descriptor")
                    if family == -1:
                        family = rsocket.get_socket_family(fd)
                    if type == -1:
                        type = rsocket.getsockopt_int(fd, _c.SOL_SOCKET, _c.SO_TYPE)
                    if proto == -1:
                        proto = get_so_protocol(fd)
                    sock = RSocket(family, type, proto, fd=fd)
            else:
                sock = RSocket(family, type, proto, inheritable=False)
            W_Socket.__init__(self, space, sock)
        except SocketError as e:
            raise converted_error(space, e)

    def _finalize_(self):
        sock = self.sock
        if sock.fd != rsocket.INVALID_SOCKET:
            try:
                self._dealloc_warn()
            finally:
                try:
                    sock.close()
                except SocketError:
                    pass

    def get_type_w(self, space):
        return space.newint(self.sock.type)

    def get_proto_w(self, space):
        return space.newint(self.sock.proto)

    def get_family_w(self, space):
        return space.newint(self.sock.family)

    def _dealloc_warn(self):
        space = self.space
        try:
            msg = (b"unclosed %s" %
                   space.utf8_w(space.repr(self)))
            space.warn(space.newtext(msg), space.w_ResourceWarning)
        except OperationError as e:
            # Spurious errors can appear at shutdown
            if e.match(space, space.w_Warning):
                e.write_unraisable(space, '', self)

    def descr_repr(self, space):
        fd = intmask(self.sock.fd)  # Force to signed type even on Windows.
        family = widen(self.sock.family)  # these are too small on win64
        tp = widen(self.sock.type)
        proto = widen(self.sock.proto)
        return space.newtext("<socket object, fd=%d, family=%d,"
                             " type=%d, proto=%d>" %
                          (fd, family, tp, proto))

    def _accept_w(self, space):
        """_accept() -> (socket object, address info)

        Wait for an incoming connection.  Return a new socket file descriptor
        representing the connection, and the address of the client.
        For IP sockets, the address info is a pair (hostaddr, port).
        """
        while True:
            try:
                fd, addr = self.sock.accept(inheritable=False)
                return space.newtuple([space.newint(fd),
                                       addr_as_object(addr, fd, space)])
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)

    # convert an Address into an app-level object
    def addr_as_object(self, space, address):
        return addr_as_object(address, self.sock.fd, space)

    # convert an app-level object into an Address
    # based on the current socket's family
    def addr_from_object(self, space, w_address):
        fd = intmask(self.sock.fd)
        return addr_from_object(self.sock.family, fd, space, w_address)

    def bind_w(self, space, w_addr):
        """bind(address)

        Bind the socket to a local address.  For IP sockets, the address is a
        pair (host, port); the host must refer to the local host. For raw packet
        sockets the address is a tuple (ifname, proto [,pkttype [,hatype]])
        """
        space.audit("socket.bind", [self, w_addr])
        try:
            self.sock.bind(self.addr_from_object(space, w_addr))
        except SocketError as e:
            raise converted_error(space, e)

    def close_w(self, space):
        """close()

        Close the socket.  It cannot be used after this call.
        """
        try:
            self.sock.close()
        except SocketError as e:
            raise converted_error(space, e)
        self.may_unregister_rpython_finalizer(space)

    def connect_w(self, space, w_addr):
        """connect(address)

        Connect the socket to a remote address.  For IP sockets, the address
        is a pair (host, port).
        """
        space.audit("socket.connect", [self, w_addr])
        while True:
            try:
                self.sock.connect(self.addr_from_object(space, w_addr))
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)

    def connect_ex_w(self, space, w_addr):
        """connect_ex(address) -> errno

        This is like connect(address), but returns an error code (the errno value)
        instead of raising an exception when an error occurs.
        """
        try:
            addr = self.addr_from_object(space, w_addr)
        except SocketError as e:
            raise converted_error(space, e)
        space.audit("socket.connect", [self, w_addr])
        while True:
            error = self.sock.connect_ex(addr)
            if error != errno.EINTR:
                break
            space.getexecutioncontext().checksignals()
        return space.newint(error)

    def fileno_w(self, space):
        """fileno() -> integer

        Return the integer file descriptor of the socket.
        """
        return space.newint(intmask(self.sock.fd))

    def detach_w(self, space):
        """detach()

        Close the socket object without closing the underlying file descriptor.
        The object cannot be used after this call, but the file descriptor
        can be reused for other purposes.  The file descriptor is returned."""
        fd = self.sock.detach()
        return space.newint(intmask(fd))

    def getpeername_w(self, space):
        """getpeername() -> address info

        Return the address of the remote endpoint.  For IP sockets, the address
        info is a pair (hostaddr, port).
        """
        try:
            addr = self.sock.getpeername()
            return addr_as_object(addr, self.sock.fd, space)
        except SocketError as e:
            raise converted_error(space, e)

    def getsockname_w(self, space):
        """getsockname() -> address info

        Return the address of the local endpoint.  For IP sockets, the address
        info is a pair (hostaddr, port).
        """
        try:
            addr = self.sock.getsockname()
            return addr_as_object(addr, self.sock.fd, space)
        except SocketError as e:
            raise converted_error(space, e)

    @unwrap_spec(level=int, optname=int, buflen=int)
    def getsockopt_w(self, space, level, optname, buflen=0):
        """getsockopt(level, option[, buffersize]) -> value

        Get a socket option.  See the Unix manual for level and option.
        If a nonzero buffersize argument is given, the return value is a
        string of that length; otherwise it is an integer.
        """
        if buflen == 0:
            try:
                return space.newint(self.sock.getsockopt_int(level, optname))
            except SocketError as e:
                raise converted_error(space, e)
        if buflen < 0 or buflen > 1024:
            raise explicit_socket_error(space, "getsockopt buflen out of range")
        try:
            return space.newbytes(self.sock.getsockopt(level, optname, buflen))
        except SocketError as e:
            raise converted_error(space, e)

    def gettimeout_w(self, space):
        """gettimeout() -> timeout

        Returns the timeout in floating seconds associated with socket
        operations. A timeout of None indicates that timeouts on socket
        operations are disabled.
        """
        timeout = self.sock.gettimeout()
        if timeout < 0.0:
            return space.w_None
        return space.newfloat(timeout)

    def getblocking_w(self, space):
        """getblocking()

        Returns True if socket is in blocking mode, or False if it
        is in non-blocking mode.
        """
        return space.newbool(self.sock.gettimeout() != 0.0)

    @unwrap_spec(backlog="c_int")
    def listen_w(self, space, backlog=min(SOMAXCONN, 128)):
        """listen(backlog)

        Enable a server to accept connections.  The backlog argument must be at
        least 0 (if it is lower, it is set to 0); it specifies the number of
        unaccepted connection that the system will allow before refusing new
        connections. If not specified, a default reasonable value is chosen.
        """
        if backlog < 0:
            backlog = 0
        try:
            self.sock.listen(backlog)
        except SocketError as e:
            raise converted_error(space, e)

    @unwrap_spec(buffersize='nonnegint', flags=int)
    def recv_w(self, space, buffersize, flags=0):
        """recv(buffersize[, flags]) -> data

        Receive up to buffersize bytes from the socket.  For the optional flags
        argument, see the Unix manual.  When no data is available, block until
        at least one byte is available or until the remote end is closed.  When
        the remote end is closed and all data is read, return the empty string.
        """
        while True:
            try:
                data = self.sock.recv(buffersize, flags)
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)
        return space.newbytes(data)

    @unwrap_spec(buffersize='nonnegint', flags=int)
    def recvfrom_w(self, space, buffersize, flags=0):
        """recvfrom(buffersize[, flags]) -> (data, address info)

        Like recv(buffersize, flags) but also return the sender's address info.
        """
        while True:
            try:
                data, addr = self.sock.recvfrom(buffersize, flags)
                if addr:
                    w_addr = addr_as_object(addr, self.sock.fd, space)
                else:
                    w_addr = space.w_None
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)
        return space.newtuple([space.newbytes(data), w_addr])

    @unwrap_spec(message_size=int, ancbufsize=int, flags=int)
    def recvmsg_w(self, space, message_size, ancbufsize=0, flags=0):
        """
        recvmsg(message_size[, ancbufsize[, flags]]) -> (message, ancillary, flags, address)
        Receive normal data (up to bufsize bytes) and ancillary data from the socket.
        The ancbufsize argument sets the size in bytes of the internal buffer used to receive the ancillary data;
        it defaults to 0, meaning that no ancillary data will be received.
        Appropriate buffer sizes for ancillary data can be calculated using CMSG_SPACE() or CMSG_LEN(),
        and items which do not fit into the buffer might be truncated or discarded.
        The flags argument defaults to 0 and has the same meaning as for recv().
        The ancdata item is a list of zero or more tuples (cmsg_level, cmsg_type, cmsg_data):
        cmsg_level and cmsg_type are integers specifying the protocol level and protocol-specific type respectively,
        and cmsg_data is a bytes object holding the associated data.

        :param space: Non useable parameter. It represents the object space.
        :param message_size: Maximum size of the message to be received
        :param ancbufsize:  Maximum size of the ancillary data to be received
        :param flags: Receive flag. For more details, please check the Unix manual
        :return: a tuple consisting of the message, the ancillary data, return flag and the address.
        """
        if message_size < 0:
            raise oefmt(space.w_ValueError, "negative buffer size in recvmsg()")
        if ancbufsize < 0:
            raise oefmt(space.w_ValueError, "invalid ancillary data buffer length")
        while True:
            try:
                recvtup = self.sock.recvmsg(message_size, ancbufsize, flags)
                w_message = space.newbytes(recvtup[0])
                anclist = []
                for l in recvtup[1]:
                    tup = space.newtuple([space.newint(l[0]), space.newint(l[1]), space.newbytes(l[2])])
                    anclist.append(tup)

                w_anc = space.newlist(anclist)

                w_flag = space.newint(recvtup[2])
                if (recvtup[3] is not None):
                    w_address = addr_as_object(recvtup[3], self.sock.fd, space)
                else:
                    w_address = space.w_None
                rettup = space.newtuple([w_message, w_anc, w_flag, w_address])
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)
        return rettup

    @unwrap_spec(ancbufsize=int, flags=int)
    def recvmsg_into_w(self, space, w_buffers, ancbufsize=0, flags=0):
        """
        recvmsg_into(buffers[, ancbufsize[, flags]]) -> (nbytes, ancdata, msg_flags, address)

        Receive normal data and ancillary data from the socket, scattering the
        non-ancillary data into a series of buffers.  The buffers argument
        must be an iterable of objects that export writable buffers
        (e.g. bytearray objects); these will be filled with successive chunks
        of the non-ancillary data until it has all been written or there are
        no more buffers.  The ancbufsize argument sets the size in bytes of
        the internal buffer used to receive the ancillary data; it defaults to
        0, meaning that no ancillary data will be received.  Appropriate
        buffer sizes for ancillary data can be calculated using CMSG_SPACE()
        or CMSG_LEN(), and items which do not fit into the buffer might be
        truncated or discarded.  The flags argument defaults to 0 and has the
        same meaning as for recv().

        The return value is a 4-tuple: (nbytes, ancdata, msg_flags, address).
        The nbytes item is the total number of bytes of non-ancillary data
        written into the buffers.  The ancdata item is a list of zero or more
        tuples (cmsg_level, cmsg_type, cmsg_data) representing the ancillary
        data (control messages) received: cmsg_level and cmsg_type are
        integers specifying the protocol level and protocol-specific type
        respectively, and cmsg_data is a bytes object holding the associated
        data.  The msg_flags item is the bitwise OR of various flags
        indicating conditions on the received message; see your system
        documentation for details.  If the receiving socket is unconnected,
        address is the address of the sending socket, if available; otherwise,
        its value is unspecified.

        If recvmsg_into() raises an exception after the system call returns,
        it will first attempt to close any file descriptors received via the
        SCM_RIGHTS mechanism.
        """
        if ancbufsize < 0:
            raise oefmt(space.w_ValueError, "invalid ancillary data buffer length")
        buffers_w = space.unpackiterable(w_buffers)
        buffers = [space.writebuf_w(w_buffer) for w_buffer in buffers_w]
        rawbufs = [None] * len(buffers)
        for i in range(len(buffers)):
            try:
                buffers[i].get_raw_address()
            except ValueError:
                rawbufs[i] = RawByteBuffer(buffers[i].getlength())
            else:
                rawbufs[i] = buffers[i]

        while True:
            try:
                recvtup = self.sock.recvmsg_into(rawbufs, ancbufsize, flags)
                nbytes, ancdata, retflag, address = recvtup
                w_nbytes = space.newint(nbytes)
                anclist = []
                for level, type, anc in ancdata:
                    w_tup = space.newtuple([
                        space.newint(level), space.newint(type),
                        space.newbytes(anc)])
                    anclist.append(w_tup)

                w_anc = space.newlist(anclist)

                w_flag = space.newint(retflag)
                if (address is not None):
                    w_address = addr_as_object(recvtup[3], self.sock.fd, space)
                else:
                    w_address = space.w_None
                rettup = space.newtuple([w_nbytes, w_anc, w_flag, w_address])
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)

        n_remaining = nbytes
        for i in range(len(buffers)):
            lgt = rawbufs[i].getlength()
            n_read = min(lgt, n_remaining)
            n_remaining -= n_read
            if rawbufs[i] is not buffers[i]:
                buffers[i].setslice(0, rawbufs[i].getslice(0, 1, n_read))
            if n_remaining == 0:
                break
        return rettup

    @unwrap_spec(data='bufferstr', flags=int)
    def send_w(self, space, data, flags=0):
        """send(data[, flags]) -> count

        Send a data string to the socket.  For the optional flags
        argument, see the Unix manual.  Return the number of bytes
        sent; this may be less than len(data) if the network is busy.
        """
        while True:
            try:
                count = self.sock.send(data, flags)
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)
        return space.newint(count)

    @unwrap_spec(data='bufferstr', flags=int)
    def sendall_w(self, space, data, flags=0):
        """sendall(data[, flags])

        Send a data string to the socket.  For the optional flags
        argument, see the Unix manual.  This calls send() repeatedly
        until all data is sent.  If an error occurs, it's impossible
        to tell how much data has been sent.
        """
        try:
            self.sock.sendall(
                data, flags, space.getexecutioncontext().checksignals)
        except SocketError as e:
            raise converted_error(space, e)

    def sendto_w(self, space, w_data, w_param2, w_param3=None):
        """sendto(data[, flags], address) -> count

        Like send(data, flags) but allows specifying the destination address.
        For IP sockets, the address is a pair (hostaddr, port).
        """
        data = space.charbuf_w(w_data)
        if w_param3 is None:
            # 2 args version
            flags = 0
            w_addr = w_param2
        else:
            # 3 args version
            flags = space.int_w(w_param2)
            w_addr = w_param3
        space.audit("socket.sendto", [self, w_addr])
        while True:
            try:
                addr = self.addr_from_object(space, w_addr)
                count = self.sock.sendto(data, len(data), flags, addr)
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)
        return space.newint(count)

    @unwrap_spec(flags=int)
    def sendmsg_w(self, space, w_data, w_ancillary=None, flags=0 ,w_address=None):
        """
        sendmsg(data[,ancillary[,flags[,address]]]) -> bytes_sent
        Send normal and ancillary data to the socket, gathering the non-ancillary data
        from a series of buffers and concatenating it into a single message.
        The ancdata argument specifies the ancillary data (control messages) as an iterable of zero or more tuples
        (cmsg_level, cmsg_type, cmsg_data), where cmsg_level and cmsg_type are integers specifying the protocol level
        and protocol-specific type respectively, and cmsg_data is a bytes-like object holding the associated data.
        :param space: Represents the object space.
        :param w_data: The message(s). needs to be a bytes like object
        :param w_ancillary: needs to be a sequence object Can remain unspecified.
        :param w_flags: needs to be an integer. Can remain unspecified.
        :param w_address: needs to be a bytes-like object Can remain unspecified.
        :return: Bytes sent from the message
        """
        if not space.is_none(w_address):
            space.audit("socket.sendmsg", [self, w_address])
        else:
            space.audit("socket.sendmsg", [self, space.w_None])
        # Get the flag and address from the object space
        while True:
            try:
                address = None
                if not space.is_none(w_address):
                    address = self.addr_from_object(space, w_address)

                # find data's type in the ObjectSpace and get a list of string out of it.
                data = []
                data_iter = space.unpackiterable(w_data)
                for i in data_iter:
                    data.append(space.readbuf_w(i).as_str())

                # find the ancillary's type in the ObjectSpace and get a list of tuples out of it.
                ancillary = []
                if w_ancillary is not None:
                    anc_iter = space.unpackiterable(w_ancillary)
                    for w_i in anc_iter:
                        if not space.isinstance_w(w_i, space.w_tuple):
                            raise oefmt(space.w_TypeError, "[sendmsg() ancillary data items]() argument must be sequence")
                        if space.len_w(w_i) == 3:
                            intemtup = space.unpackiterable(w_i)
                            level = space.int_w(intemtup[0])
                            type = space.int_w(intemtup[1])
                            cont = space.readbuf_w(intemtup[2]).as_str()
                            tup = (level, type, cont)
                            ancillary.append(tup)
                        else:
                            raise oefmt(space.w_TypeError,
                                        "[sendmsg() ancillary data items]() argument must be sequence of length 3")

                count = self.sock.sendmsg(data, ancillary, flags, address)
                if count < 0:
                    if (count == -1000):
                        raise oefmt(space.w_OSError, "sending multiple control messages not supported")
                    if (count == -1001):
                        raise oefmt(space.w_OSError, "ancillary data item too large")
                    if (count == -1002):
                        raise oefmt(space.w_OSError, "too much ancillary data")
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)

        return space.newint(count)

    @unwrap_spec(flag=int)
    def setblocking_w(self, space, flag):
        """setblocking(flag)

        Set the socket to blocking (flag is true) or non-blocking (false).
        setblocking(True) is equivalent to settimeout(None);
        setblocking(False) is equivalent to settimeout(0.0).
        """
        try:
            self.sock.setblocking(bool(flag))
        except SocketError as e:
            raise converted_error(space, e)

    @unwrap_spec(level=int, optname=int)
    def setsockopt_w(self, space, level, optname, w_optval):
        """setsockopt(level, option, value)

        Set a socket option.  See the Unix manual for level and option.
        The value argument can either be an integer or a string.
        """
        try:
            optval = space.c_int_w(w_optval)
        except OperationError as e:
            if e.async(space):
                raise
            optval = space.charbuf_w(w_optval)
            try:
                self.sock.setsockopt(level, optname, optval)
            except SocketError as e:
                raise converted_error(space, e)
            return
        try:
            self.sock.setsockopt_int(level, optname, optval)
        except SocketError as e:
            raise converted_error(space, e)

    def settimeout_w(self, space, w_timeout):
        """settimeout(timeout)

        Set a timeout on socket operations.  'timeout' can be a float,
        giving in seconds, or None.  Setting a timeout of None disables
        the timeout feature and is equivalent to setblocking(1).
        Setting a timeout of zero is the same as setblocking(0).
        """
        if space.is_w(w_timeout, space.w_None):
            timeout = -1.0
        else:
            timeout = space.float_w(w_timeout)
            if timeout < 0.0:
                raise oefmt(space.w_ValueError, "Timeout value out of range")
        try:
            self.sock.settimeout(timeout)
        except SocketError as e:
            raise converted_error(space, e)

    @unwrap_spec(nbytes=int, flags=int)
    def recv_into_w(self, space, w_buffer, nbytes=0, flags=0):
        """recv_into(buffer, [nbytes[, flags]]) -> nbytes_read

        A version of recv() that stores its data into a buffer rather than creating
        a new string.  Receive up to buffersize bytes from the socket.  If buffersize
        is not specified (or 0), receive up to the size available in the given buffer.

        See recv() for documentation about the flags.
        """
        rwbuffer = space.writebuf_w(w_buffer)
        lgt = rwbuffer.getlength()
        if nbytes < 0:
            raise oefmt(space.w_ValueError, "negative buffersize in recv_into")
        if nbytes == 0:
            nbytes = lgt
        if lgt < nbytes:
            raise oefmt(space.w_ValueError, "buffer too small for requested bytes")
        try:
            rwbuffer.get_raw_address()
        except ValueError:
            rawbuf = RawByteBuffer(nbytes)
        else:
            rawbuf = rwbuffer

        while True:
            try:
                nbytes_read = self.sock.recvinto(rawbuf, nbytes, flags)
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)
        if rawbuf is not rwbuffer:
            rwbuffer.setslice(0, rawbuf.getslice(0, 1, nbytes_read))
        return space.newint(nbytes_read)

    @unwrap_spec(nbytes=int, flags=int)
    def recvfrom_into_w(self, space, w_buffer, nbytes=0, flags=0):
        """recvfrom_into(buffer[, nbytes[, flags]]) -> (nbytes, address info)

        Like recv_into(buffer[, nbytes[, flags]]) but also return the sender's address info.
        """
        rwbuffer = space.writebuf_w(w_buffer)
        lgt = rwbuffer.getlength()
        if nbytes == 0:
            nbytes = lgt
        elif nbytes > lgt:
            raise oefmt(space.w_ValueError,
                        "nbytes is greater than the length of the buffer")
        try:
            rwbuffer.get_raw_address()
        except ValueError:
            rawbuf = RawByteBuffer(nbytes)
        else:
            rawbuf = rwbuffer
        while True:
            try:
                readlgt, addr = self.sock.recvfrom_into(rawbuf, nbytes, flags)
                break
            except SocketError as e:
                converted_error(space, e, eintr_retry=True)
        if rawbuf is not rwbuffer:
            rwbuffer.setslice(0, rawbuf.getslice(0, 1, readlgt))
        if addr:
            try:
                w_addr = addr_as_object(addr, self.sock.fd, space)
            except SocketError as e:
                raise converted_error(space, e)
        else:
            w_addr = space.w_None
        return space.newtuple([space.newint(readlgt), w_addr])

    @unwrap_spec(cmd=int)
    def ioctl_w(self, space, cmd, w_option):
        from rpython.rtyper.lltypesystem import rffi, lltype
        from rpython.rlib import rwin32
        from rpython.rlib.rsocket import _c

        recv_ptr = lltype.malloc(rwin32.LPDWORD.TO, 1, flavor='raw')
        try:
            if cmd == _c.SIO_RCVALL:
                value_size = rffi.sizeof(rffi.INTP)
            elif cmd == _c.SIO_KEEPALIVE_VALS:
                value_size = rffi.sizeof(_c.tcp_keepalive)
            else:
                raise oefmt(space.w_ValueError,
                            "invalid ioctl command %d", cmd)

            value_ptr = lltype.malloc(rffi.VOIDP.TO, value_size, flavor='raw')
            try:
                if cmd == _c.SIO_RCVALL:
                    option_ptr = rffi.cast(rffi.INTP, value_ptr)
                    option_ptr[0] = rffi.cast(rffi.INT, space.int_w(w_option))
                elif cmd == _c.SIO_KEEPALIVE_VALS:
                    w_onoff, w_time, w_interval = space.unpackiterable(w_option, 3)
                    option_ptr = rffi.cast(lltype.Ptr(_c.tcp_keepalive), value_ptr)
                    option_ptr.c_onoff = rffi.cast(rffi.UINT, space.uint_w(w_onoff))
                    option_ptr.c_keepalivetime = rffi.cast(rffi.UINT, space.uint_w(w_time))
                    option_ptr.c_keepaliveinterval = rffi.cast(rffi.UINT, space.uint_w(w_interval))

                res = _c.WSAIoctl(
                    self.sock.fd, cmd, value_ptr, value_size,
                    rffi.NULL, 0, recv_ptr, rffi.NULL, rffi.NULL)
                if res < 0:
                    raise converted_error(space, rsocket.last_error())
            finally:
                if value_ptr:
                    lltype.free(value_ptr, flavor='raw')

            return space.newint(recv_ptr[0])
        finally:
            lltype.free(recv_ptr, flavor='raw')

    @unwrap_spec(processid=int)
    def share_w(self, space, processid):
        from rpython.rtyper.lltypesystem import rffi, lltype
        from rpython.rlib import rwin32
        from rpython.rlib.rsocket import _c
        info_ptr = lltype.malloc(_c.WSAPROTOCOL_INFOW, flavor='raw')
        try:
            winprocessid = rffi.cast(rwin32.DWORD, processid)
            res = _c.WSADuplicateSocketW(
                        self.sock.fd, winprocessid, info_ptr)

            if res < 0:
                raise converted_error(space, rsocket.last_error())

            bytes_ptr = rffi.cast(rffi.CCHARP, info_ptr)
            w_bytes = space.newbytes(rffi.charpsize2str(bytes_ptr, rffi.sizeof(_c.WSAPROTOCOL_INFOW)))
        finally:
            lltype.free(info_ptr, flavor='raw')
        return w_bytes

    @unwrap_spec(how="c_int")
    def shutdown_w(self, space, how):
        """shutdown(flag)

        Shut down the reading side of the socket (flag == SHUT_RD), the
        writing side of the socket (flag == SHUT_WR), or both ends
        (flag == SHUT_RDWR).
        """
        try:
            self.sock.shutdown(how)
        except SocketError as e:
            raise converted_error(space, e)

    #------------------------------------------------------------
    # Support functions for socket._socketobject
    usecount = 1
    def _reuse_w(self):
        """_resue()

        Increase the usecount of the socketobject.
        Intended only to be used by socket._socketobject
        """
        self.usecount += 1

    def _drop_w(self, space):
        """_drop()

        Decrease the usecount of the socketobject. If the
        usecount reaches 0 close the socket.
        Intended only to be used by socket._socketobject
        """
        self.usecount -= 1
        if self.usecount > 0:
            return
        self.close_w(space)


# ____________________________________________________________
# Automatic shutdown()/close()

# On some systems, the C library does not guarantee that when the program
# finishes, all data sent so far is really sent even if the socket is not
# explicitly closed.  This behavior has been observed on Windows but not
# on Linux, so far.
NEED_EXPLICIT_CLOSE = (sys.platform == 'win32')

class OpenRSockets(rweaklist.RWeakListMixin):
    pass
class OpenRSocketsState:
    def __init__(self, space):
        self.openrsockets = OpenRSockets()
        self.openrsockets.initialize()

def getopenrsockets(space):
    if NEED_EXPLICIT_CLOSE and space.config.translation.rweakref:
        return space.fromcache(OpenRSocketsState).openrsockets
    else:
        return None

def register_socket(space, socket):
    openrsockets = getopenrsockets(space)
    if openrsockets is not None:
        openrsockets.add_handle(socket)

def close_all_sockets(space):
    openrsockets = getopenrsockets(space)
    if openrsockets is not None:
        for sock_wref in openrsockets.get_all_handles():
            sock = sock_wref()
            if sock is not None:
                try:
                    sock.close()
                except SocketError:
                    pass


# ____________________________________________________________
# Error handling

class SocketAPI:
    def __init__(self, space):
        self.w_error = space.w_OSError
        self.w_herror = space.new_exception_class(
            "_socket.herror", self.w_error)
        self.w_gaierror = space.new_exception_class(
            "_socket.gaierror", self.w_error)
        self.w_timeout = space.new_exception_class(
            "_socket.timeout", self.w_error)

        self.errors_w = {'error': self.w_error,
                         'herror': self.w_herror,
                         'gaierror': self.w_gaierror,
                         'timeout': self.w_timeout,
                         }

    def get_exception(self, applevelerrcls):
        return self.errors_w[applevelerrcls]

def get_error(space, name):
    return space.fromcache(SocketAPI).get_exception(name)

@specialize.arg(2)
def converted_error(space, e, eintr_retry=False):
    message, lgt = e.get_msg_utf8()
    w_exception_class = get_error(space, e.applevelerrcls)
    if isinstance(e, SocketErrorWithErrno):
        if e.errno == errno.EINTR:
            space.getexecutioncontext().checksignals()
            if eintr_retry:
                return       # only return None if eintr_retry==True
        w_exception = space.call_function(w_exception_class, space.newint(e.errno),
                                      space.newtext(message, lgt))
    else:
        w_exception = space.call_function(w_exception_class,
                                          space.newtext(message, lgt))
    raise OperationError(w_exception_class, w_exception)

def explicit_socket_error(space, msg):
    w_exception_class = space.fromcache(SocketAPI).w_error
    w_exception = space.call_function(w_exception_class, space.newtext(msg))
    return OperationError(w_exception_class, w_exception)


# ____________________________________________________________

socketmethodnames = """
_accept bind close connect connect_ex fileno detach
getpeername getsockname getsockopt gettimeout listen
recv recvfrom send sendall sendto setblocking
setsockopt settimeout shutdown _reuse _drop
recv_into recvfrom_into
getblocking
""".split()
if hasattr(rsocket._c, 'WSAIoctl'):
    socketmethodnames.append('ioctl')
    socketmethodnames.append('share')
if rsocket._c.HAVE_SENDMSG:
    socketmethodnames.append('sendmsg')
    socketmethodnames.append('recvmsg')
    socketmethodnames.append('recvmsg_into')

socketmethods = {}
for methodname in socketmethodnames:
    method = getattr(W_Socket, methodname + '_w')
    socketmethods[methodname] = interp2app(method)

W_Socket.typedef = TypeDef("_socket.socket",
    __doc__ = """\
socket(family=AF_INET, type=SOCK_STREAM, proto=0, fileno=None) -> socket object

Open a socket of the given type.  The family argument specifies the
address family; it defaults to AF_INET.  The type argument specifies
whether this is a stream (SOCK_STREAM, this is the default)
or datagram (SOCK_DGRAM) socket.  The protocol argument defaults to 0,
specifying the default protocol.  Keyword arguments are accepted.
The socket is created as non-inheritable.

A socket object represents one endpoint of a network connection.

Methods of socket objects (keyword arguments not allowed):

_accept() -- accept connection, returning new socket fd and client address
bind(addr) -- bind the socket to a local address
close() -- close the socket
connect(addr) -- connect the socket to a remote address
connect_ex(addr) -- connect, return an error code instead of an exception
dup() -- return a new socket fd duplicated from fileno()
fileno() -- return underlying file descriptor
getpeername() -- return remote address [*]
getsockname() -- return local address
getsockopt(level, optname[, buflen]) -- get socket options
gettimeout() -- return timeout or None
listen([n]) -- start listening for incoming connections
recv(buflen[, flags]) -- receive data
recv_into(buffer[, nbytes[, flags]]) -- receive data (into a buffer)
recvfrom(buflen[, flags]) -- receive data and sender\'s address
recvfrom_into(buffer[, nbytes, [, flags])
  -- receive data and sender\'s address (into a buffer)
sendall(data[, flags]) -- send all data
send(data[, flags]) -- send data, may not send all of it
sendto(data[, flags], addr) -- send data to a given address
setblocking(0 | 1) -- set or clear the blocking I/O flag
setsockopt(level, optname, value[, optlen]) -- set socket options
settimeout(None | float) -- set or clear the timeout
shutdown(how) -- shut down traffic in one or both directions
if_nameindex() -- return all network interface indices and names
if_nametoindex(name) -- return the corresponding interface index
if_indextoname(index) -- return the corresponding interface name

 [*] not available on all platforms!""",
    __new__ = generic_new_descr(W_Socket),
    __init__ = interp2app(W_Socket.descr_init),
    __repr__ = interp2app(W_Socket.descr_repr),
    type = GetSetProperty(W_Socket.get_type_w),
    proto = GetSetProperty(W_Socket.get_proto_w),
    family = GetSetProperty(W_Socket.get_family_w),
    timeout = GetSetProperty(W_Socket.gettimeout_w),
    **socketmethods
    )

@unwrap_spec(fd=int)
def close(space, fd):
    from rpython.rlib import _rsocket_rffi as _c
    res = _c.socketclose(fd)
    if res:
        converted_error(space, rsocket.last_error())

