# -*- coding: utf-8 -*-
import os
import socket
import pytest
from rpython.tool.udir import udir
from rpython.rlib import rsocket
from rpython.rtyper.lltypesystem import lltype, rffi

@pytest.fixture
def spaceconfig():
    return {'usemodules': ['_socket', 'array', 'struct', 'unicodedata']}

@pytest.fixture
def w_socket(space):
    return space.appexec([], "(): import _socket as m; return m")

def test_gethostname(space, w_socket):
    host = space.appexec([w_socket], "(_socket): return _socket.gethostname()")
    assert space.unwrap(host) == socket.gethostname()

def test_gethostbyname(space, w_socket):
    for host in ["localhost", "127.0.0.1"]:
        ip = space.appexec([w_socket, space.wrap(host)],
                           "(_socket, host): return _socket.gethostbyname(host)")
        assert space.unwrap(ip) == socket.gethostbyname(host)

def test_gethostbyname_ex(space, w_socket):
    for host in ["localhost", "127.0.0.1"]:
        ip = space.appexec([w_socket, space.wrap(host)],
                           "(_socket, host): return _socket.gethostbyname_ex(host)")
        assert space.unwrap(ip) == socket.gethostbyname_ex(host)

def test_gethostbyaddr(space, w_socket):
    try:
        socket.gethostbyaddr("::1")
    except socket.herror:
        ipv6 = False
    else:
        ipv6 = True
    for host in ["localhost", "127.0.0.1", "::1"]:
        if host == "::1" and not ipv6:
            from pypy.interpreter.error import OperationError
            with pytest.raises(OperationError):
                space.appexec([w_socket, space.wrap(host)],
                              "(_socket, host): return _socket.gethostbyaddr(host)")
            continue
        ip = space.appexec([w_socket, space.wrap(host)],
                           "(_socket, host): return _socket.gethostbyaddr(host)")
        assert space.unwrap(ip) == socket.gethostbyaddr(host)

def test_getservbyname(space, w_socket):
    name = "smtp"
    # 2 args version
    port = space.appexec([w_socket, space.wrap(name)],
                        "(_socket, name): return _socket.getservbyname(name, 'tcp')")
    assert space.unwrap(port) == 25
    # 1 arg version
    port = space.appexec([w_socket, space.wrap(name)],
                        "(_socket, name): return _socket.getservbyname(name)")
    assert space.unwrap(port) == 25

def test_getservbyport(space, w_socket):
    port = 25
    # 2 args version
    name = space.appexec([w_socket, space.wrap(port)],
                         "(_socket, port): return _socket.getservbyport(port, 'tcp')")
    assert space.unwrap(name) == "smtp"
    name = space.appexec([w_socket, space.wrap(port)],
                         """(_socket, port):
                         try:
                             return _socket.getservbyport(port, 42)
                         except TypeError:
                             return 'OK'
                         """)
    assert space.unwrap(name) == 'OK'
    # 1 arg version
    name = space.appexec([w_socket, space.wrap(port)],
                         "(_socket, port): return _socket.getservbyport(port)")
    assert space.unwrap(name) == "smtp"

def test_getprotobyname(space, w_socket):
    name = "tcp"
    w_n = space.appexec([w_socket, space.wrap(name)],
                        "(_socket, name): return _socket.getprotobyname(name)")
    assert space.unwrap(w_n) == socket.IPPROTO_TCP

@pytest.mark.skipif("not hasattr(socket, 'fromfd')")
@pytest.mark.skipif("sys.platform=='win32'")
def test_ntohs(space, w_socket):
    w_n = space.appexec([w_socket, space.wrap(125)],
                        "(_socket, x): return _socket.ntohs(x)")
    assert space.unwrap(w_n) == socket.ntohs(125)

def test_ntohl(space, w_socket):
    w_n = space.appexec([w_socket, space.wrap(125)],
                        "(_socket, x): return _socket.ntohl(x)")
    assert space.unwrap(w_n) == socket.ntohl(125)
    w_n = space.appexec([w_socket, space.wrap(0x89abcdef)],
                        "(_socket, x): return _socket.ntohl(x)")
    assert space.unwrap(w_n) in (0x89abcdef, 0xefcdab89)
    space.raises_w(space.w_OverflowError, space.appexec,
                   [w_socket, space.wrap(1 << 32)],
                   "(_socket, x): return _socket.ntohl(x)")

def test_htons(space, w_socket):
    w_n = space.appexec([w_socket, space.wrap(125)],
                        "(_socket, x): return _socket.htons(x)")
    assert space.unwrap(w_n) == socket.htons(125)

def test_htonl(space, w_socket):
    w_n = space.appexec([w_socket, space.wrap(125)],
                        "(_socket, x): return _socket.htonl(x)")
    assert space.unwrap(w_n) == socket.htonl(125)
    w_n = space.appexec([w_socket, space.wrap(0x89abcdef)],
                        "(_socket, x): return _socket.htonl(x)")
    assert space.unwrap(w_n) in (0x89abcdef, 0xefcdab89)
    space.raises_w(space.w_OverflowError, space.appexec,
                   [w_socket, space.wrap(1 << 32)],
                   "(_socket, x): return _socket.htonl(x)")

def test_aton_ntoa(space, w_socket):
    ip = '123.45.67.89'
    packed = socket.inet_aton(ip)
    w_p = space.appexec([w_socket, space.wrap(ip)],
                        "(_socket, ip): return _socket.inet_aton(ip)")
    assert space.bytes_w(w_p) == packed
    w_ip = space.appexec([w_socket, w_p],
                         "(_socket, p): return _socket.inet_ntoa(p)")
    assert space.utf8_w(w_ip) == ip

@pytest.mark.skipif("not hasattr(socket, 'inet_pton')")
def test_pton_ntop_ipv4(space, w_socket):
    tests = [
        ("123.45.67.89", "\x7b\x2d\x43\x59"),
        ("0.0.0.0", "\x00" * 4),
        ("255.255.255.255", "\xff" * 4),
    ]
    for ip, packed in tests:
        w_p = space.appexec([w_socket, space.wrap(ip)], """(_socket, ip):
            return _socket.inet_pton(_socket.AF_INET, ip)""")
        assert space.unwrap(w_p) == packed
        w_ip = space.appexec([w_socket, w_p], """(_socket, p):
            return _socket.inet_ntop(_socket.AF_INET, p)""")
        assert space.unwrap(w_ip) == ip

def test_ntop_ipv6(space, w_socket):
    if not hasattr(socket, 'inet_pton'):
        pytest.skip('No socket.inet_pton on this platform')
    if not socket.has_ipv6:
        pytest.skip("No IPv6 on this platform")
    tests = [
        (b"\x00" * 16, "::"),
        (b"\x01" * 16, ":".join(["101"] * 8)),
        (b"\x00\x00\x10\x10" * 4, None),  # "::1010:" + ":".join(["0:1010"] * 3)),
        (b"\x00" * 12 + "\x01\x02\x03\x04", "::1.2.3.4"),
        (b"\x00" * 10 + "\xff\xff\x01\x02\x03\x04", "::ffff:1.2.3.4"),
    ]
    for packed, ip in tests:
        w_ip = space.appexec([w_socket, space.newbytes(packed)],
            "(_socket, packed): return _socket.inet_ntop(_socket.AF_INET6, packed)")
        if ip is not None:   # else don't check for the precise representation
            assert space.unwrap(w_ip) == ip
        w_packed = space.appexec([w_socket, w_ip],
            "(_socket, ip): return _socket.inet_pton(_socket.AF_INET6, ip)")
        assert space.unwrap(w_packed) == packed

def test_pton_ipv6(space, w_socket):
    import sys
    if not hasattr(socket, 'inet_pton'):
        pytest.skip('No socket.inet_pton on this platform')
    if not socket.has_ipv6:
        pytest.skip("No IPv6 on this platform")
    tests = [
        ("\x00" * 16, "::"),
        ("\x01" * 16, ":".join(["101"] * 8)),
        ("\x00\x01" + "\x00" * 12 + "\x00\x02", "1::2"),
        ("\x00" * 4 + "\x00\x01" * 6, "::1:1:1:1:1:1"),
        ("\x00\x01" * 6 + "\x00" * 4, "1:1:1:1:1:1::"),
        ("\xab\xcd\xef\00" + "\x00" * 12, "ABCD:EF00::"),
        ("\xab\xcd\xef\00" + "\x00" * 12, "abcd:ef00::"),
        ("\x00" * 12 + "\x01\x02\x03\x04", "::1.2.3.4"),
        ("\x00" * 10 + "\xff\xff\x01\x02\x03\x04", "::ffff:1.2.3.4"),
    ]
    if sys.platform != 'win32':
        tests.append(
            ("\x00\x00\x10\x10" * 4, "::1010:" + ":".join(["0:1010"] * 3))
        )
    for packed, ip in tests:
        w_packed = space.appexec([w_socket, space.wrap(ip)],
            "(_socket, ip): return _socket.inet_pton(_socket.AF_INET6, ip)")
        assert space.unwrap(w_packed) == packed

def test_getaddrinfo(space, w_socket):
    host = b"localhost"
    port = 25
    info = socket.getaddrinfo(host, port)
    w_l = space.appexec([w_socket, space.newbytes(host), space.wrap(port)],
                        "(_socket, host, port): return _socket.getaddrinfo(host, port)")
    assert space.unwrap(w_l) == info
    w_l = space.appexec([w_socket, space.wrap(host), space.wrap(port)],
                        "(_socket, host, port): return _socket.getaddrinfo(host, port)")
    assert space.unwrap(w_l) == info
    w_l = space.appexec([w_socket, space.newbytes(host), space.wrap('smtp')],
                        "(_socket, host, port): return _socket.getaddrinfo(host, port)")
    assert space.unwrap(w_l) == socket.getaddrinfo(host, 'smtp')
    w_l = space.appexec([w_socket, space.newbytes(host), space.wrap(u'\uD800')], '''

       (_socket, host, port):
            try:
                info = _socket.getaddrinfo(host, port)
            except Exception as e:
                return e.reason == 'surrogates not allowed'
            return -1
        ''')
    assert space.unwrap(w_l) == True

def test_getaddrinfo_ipv6(space, w_socket):
    host = 'fe80::1%1'
    port = 80
    w_l = space.appexec([w_socket, space.newtext(host), space.newint(port)],
                        "(_socket, host, port): return _socket.getaddrinfo(host, port)")
    w_tup = space.getitem(w_l, space.newint(0))
    w_tup2 = space.getitem(w_tup, space.newint(4))
    w_canon = space.getitem(w_tup2, space.newint(0))
    canon_name = space.text_w(w_canon)
    # Includes the scope ID, CPython removes it
    # See issue 3628
    assert '%' in canon_name

@pytest.mark.skipif("not hasattr(socket, 'sethostname')")
def test_sethostname(space, w_socket):
    space.raises_w(space.w_OSError, space.appexec,
                   [w_socket],
                   "(_socket): _socket.sethostname(_socket.gethostname())")


@pytest.mark.skipif("not hasattr(socket, 'sethostname')")
def test_sethostname_bytes(space, w_socket):
    space.raises_w(space.w_OSError, space.appexec,
                   [w_socket],
                   "(_socket): _socket.sethostname(_socket.gethostname().encode())")


def test_unknown_addr_as_object(space, ):
    from pypy.module._socket.interp_socket import addr_as_object
    c_addr = lltype.malloc(rsocket._c.sockaddr, flavor='raw', track_allocation=False)
    c_addr.c_sa_data[0] = 'c'
    rffi.setintfield(c_addr, 'c_sa_family', 15)
    # XXX what size to pass here? for the purpose of this test it has
    #     to be short enough so we have some data, 1 sounds good enough
    #     + sizeof USHORT
    w_obj = addr_as_object(rsocket.Address(c_addr, 1 + 2), -1, space)
    assert space.isinstance_w(w_obj, space.w_tuple)
    assert space.int_w(space.getitem(w_obj, space.wrap(0))) == 15
    assert space.text_w(space.getitem(w_obj, space.wrap(1))) == 'c'

def test_addr_raw_packet(space, ):
    from pypy.module._socket.interp_socket import addr_as_object
    if not hasattr(rsocket._c, 'sockaddr_ll'):
        pytest.skip("posix specific test")
    # HACK: To get the correct interface number of lo, which in most cases is 1,
    # but can be anything (i.e. 39), we need to call the libc function
    # if_nametoindex to get the correct index
    import ctypes
    libc = ctypes.CDLL(ctypes.util.find_library('c'))
    ifnum = libc.if_nametoindex('lo')

    c_addr_ll = lltype.malloc(rsocket._c.sockaddr_ll, flavor='raw')
    addrlen = rffi.sizeof(rsocket._c.sockaddr_ll)
    c_addr = rffi.cast(lltype.Ptr(rsocket._c.sockaddr), c_addr_ll)
    rffi.setintfield(c_addr_ll, 'c_sll_ifindex', ifnum)
    rffi.setintfield(c_addr_ll, 'c_sll_protocol', 8)
    rffi.setintfield(c_addr_ll, 'c_sll_pkttype', 13)
    rffi.setintfield(c_addr_ll, 'c_sll_hatype', 0)
    rffi.setintfield(c_addr_ll, 'c_sll_halen', 3)
    c_addr_ll.c_sll_addr[0] = 'a'
    c_addr_ll.c_sll_addr[1] = 'b'
    c_addr_ll.c_sll_addr[2] = 'c'
    rffi.setintfield(c_addr, 'c_sa_family', socket.AF_PACKET)
    # fd needs to be somehow valid
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    fd = s.fileno()
    w_obj = addr_as_object(rsocket.make_address(c_addr, addrlen), fd, space)
    lltype.free(c_addr_ll, flavor='raw')
    assert space.is_true(space.eq(w_obj, space.newtuple([
        space.newtext('lo'),
        space.newint(socket.ntohs(8)),
        space.newint(13),
        space.newbool(False),
        space.newbytes("abc"),
    ])))

def test_getnameinfo(space, w_socket):
    from pypy.module._socket.interp_socket import get_error
    host = "127.0.0.1"
    port = 25
    info = socket.getnameinfo((host, port), 0)
    w_l = space.appexec([w_socket, space.wrap(host), space.wrap(port)],
                        "(_socket, host, port): return _socket.getnameinfo((host, port), 0)")
    assert space.unwrap(w_l) == info
    sockaddr = space.newtuple([space.wrap('mail.python.org'), space.wrap(0)])
    space.raises_w(get_error(space, 'error'), space.appexec,
                   [w_socket, sockaddr, space.wrap(0)],
                   "(_socket, sockaddr, flags): return _socket.getnameinfo(sockaddr, flags)")
    if socket.has_ipv6:
        sockaddr = space.newtuple([space.wrap('::1'), space.wrap(0),
                                   space.wrap(0xffffffff)])
        space.raises_w(space.w_OverflowError, space.appexec,
                       [w_socket, sockaddr, space.wrap(0)],
                       "(_socket, sockaddr, flags): return _socket.getnameinfo(sockaddr, flags)")

def test_timeout(space, w_socket):
    space.appexec([w_socket, space.wrap(25.4)],
                  "(_socket, timeout): _socket.setdefaulttimeout(timeout)")
    w_t = space.appexec([w_socket],
                  "(_socket): return _socket.getdefaulttimeout()")
    assert space.unwrap(w_t) == 25.4

    space.appexec([w_socket, space.w_None],
                  "(_socket, timeout): _socket.setdefaulttimeout(timeout)")
    w_t = space.appexec([w_socket],
                  "(_socket): return _socket.getdefaulttimeout()")
    assert space.unwrap(w_t) is None


# XXX also need tests for other connection and timeout errors

def test_type(space, w_socket):
    w_bool = space.appexec([w_socket],
                    """(_socket,):
                    if not hasattr(_socket, 'SOCK_CLOEXEC'):
                        return -1
                    s = _socket.socket(_socket.AF_INET,
                                    _socket.SOCK_STREAM | _socket.SOCK_CLOEXEC)
                    return s.type == _socket.SOCK_STREAM
                    """)
    assert(space.bool_w(w_bool))

class AppTestSocket:
    spaceconfig = dict(usemodules=['_socket', '_weakref', 'struct', 'select',
                                   'unicodedata'])

    def setup_class(cls):
        space = cls.space
        cls.w_udir = space.wrap(str(udir))

    def teardown_class(cls):
        if not cls.runappdirect:
            cls.space.sys.getmodule('_socket').shutdown(cls.space)

    def test_module(self):
        import _socket
        assert _socket.socket.__name__ == 'socket'
        assert _socket.socket.__module__ == '_socket'

    def test_overflow_errors(self):
        import _socket
        raises(OverflowError, _socket.getservbyport, -1)
        raises(OverflowError, _socket.getservbyport, 65536)

    def test_ntoa_exception(self):
        import _socket
        raises(_socket.error, _socket.inet_ntoa, b"ab")

    def test_aton_exceptions(self):
        import _socket
        tests = ["127.0.0.256", "127.0.0.255555555555555555", "127.2b.0.0",
            "127.2.0.0.1", "127.2.0."]
        for ip in tests:
            raises(_socket.error, _socket.inet_aton, ip)

    def test_ntop_exceptions(self):
        import _socket
        if not hasattr(_socket, 'inet_ntop'):
            skip('No socket.inet_pton on this platform')
        for family, packed, exception in \
                    [(_socket.AF_INET + _socket.AF_INET6, b"", _socket.error),
                     (_socket.AF_INET, b"a", ValueError),
                     (_socket.AF_INET6, b"a", ValueError),
                     (_socket.AF_INET, "aa\u2222a", TypeError)]:
            raises(exception, _socket.inet_ntop, family, packed)

    def test_pton_exceptions(self):
        import _socket
        if not hasattr(_socket, 'inet_pton'):
            skip('No socket.inet_pton on this platform')
        tests = [
            (_socket.AF_INET + _socket.AF_INET6, ""),
            (_socket.AF_INET, "127.0.0.256"),
            (_socket.AF_INET, "127.0.0.255555555555555555"),
            (_socket.AF_INET, "127.2b.0.0"),
            (_socket.AF_INET, "127.2.0.0.1"),
            (_socket.AF_INET, "127.2..0"),
            (_socket.AF_INET6, "127.0.0.1"),
            (_socket.AF_INET6, "1::2::3"),
            (_socket.AF_INET6, "1:1:1:1:1:1:1:1:1"),
            (_socket.AF_INET6, "1:1:1:1:1:1:1:1::"),
            (_socket.AF_INET6, "1:1:1::1:1:1:1:1"),
            (_socket.AF_INET6, "1::22222:1"),
            (_socket.AF_INET6, "1::eg"),
        ]
        for family, ip in tests:
            raises(_socket.error, _socket.inet_pton, family, ip)

    def test_newsocket_error(self):
        import _socket
        raises(_socket.error, _socket.socket, 10001, _socket.SOCK_STREAM, 0)

    def test_socket_fileno(self):
        import _socket
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM, 0)
        assert s.fileno() > -1
        assert isinstance(s.fileno(), int)

    def test_socket_repr(self):
        import _socket
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        try:
            expected = ('<socket object, fd=%s, family=%s, type=%s, proto=%s>'
                        % (s.fileno(), s.family, s.type, s.proto))
            assert repr(s) == expected
        finally:
            s.close()
        expected = ('<socket object, fd=-1, family=%s, type=%s, proto=%s>'
                    % (s.family, s.type, s.proto))
        assert repr(s) == expected

    def test_socket_close(self):
        import _socket, os
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM, 0)
        fileno = s.fileno()
        assert s.fileno() >= 0
        s.close()
        assert s.fileno() < 0
        s.close()
        if os.name != 'nt':
            raises(OSError, os.close, fileno)

    @pytest.mark.skipif("sys.platform == 'win32'")
    def test_socket_close_exception(self):
        import _socket, errno
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM, 0)
        _socket.socket(fileno=s.fileno()).close()
        e = raises(OSError, s.close)
        assert e.value.errno in (errno.EBADF, errno.ENOTSOCK)

    @pytest.mark.skipif("sys.platform == 'win32'")
    def test_setblocking_invalidfd(self):
        import _socket
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM, 0)
        _socket.socket(fileno=s.fileno()).close()
        raises(OSError, s.setblocking, False)

    def test_socket_connect(self):
        import _socket
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM, 0)
        # it would be nice to have a test which works even if there is no
        # network connection. However, this one is "good enough" for now. Skip
        # it if there is no connection.
        try:
            s.connect(("www.python.org", 80))
        except _socket.gaierror as ex:
            skip("GAIError - probably no connection: %s" % str(ex.args))
        name = s.getpeername() # Will raise socket.error if not connected
        assert name[1] == 80
        s.close()

    def test_socket_connect_ex(self):
        import _socket
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM, 0)
        # The following might fail if the DNS redirects failed requests to a
        # catch-all address (i.e. opendns).
        # Make sure we get an app-level error, not an interp one.
        raises(_socket.gaierror, s.connect_ex, ("wrong.invalid", 80))
        s.close()

    def test_socket_connect_typeerrors(self):
        tests = [
            "",
            "80",
            ("80",),
            ("80", "80"),
            (80, 80),
        ]
        import _socket
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM, 0)
        for args in tests:
            raises((TypeError, ValueError), s.connect, args)
        s.close()

    def test_bigport(self):
        import _socket
        s = _socket.socket()
        exc = raises(OverflowError, s.connect, ("localhost", -1))
        assert "port must be 0-65535." in str(exc.value)
        exc = raises(OverflowError, s.connect, ("localhost", 1000000))
        assert "port must be 0-65535." in str(exc.value)
        s = _socket.socket(_socket.AF_INET6)
        exc = raises(OverflowError, s.connect, ("::1", 1234, 1048576))
        assert "flowinfo must be 0-1048575." in str(exc.value)

    def test_NtoH(self):
        import _socket as socket
        # This checks that htons etc. are their own inverse,
        # when looking at the lower 16 or 32 bits.  It also
        # checks that we get OverflowErrors when calling with -1,
        # or (for XtoXl()) with too large values.  For XtoXs()
        # large values are silently truncated instead, like CPython.
        sizes = {socket.htonl: 32, socket.ntohl: 32,
                 socket.htons: 16, socket.ntohs: 16}
        for func, size in sizes.items():
            mask = (1 << size) - 1
            for i in (0, 1, 0xffff, 0xffff0000, 2, 0x01234567, 0x76543210):
                assert i & mask == func(func(i&mask)) & mask

            swapped = func(mask)
            assert swapped & mask == mask
            raises(OverflowError, func, -1)
            if size > 16:    # else, values too large are ignored
                raises(OverflowError, func, 2 ** size)

    def test_newsocket(self):
        import _socket
        s = _socket.socket()

    def test_subclass(self):
        from _socket import socket
        class MySock(socket):
            blah = 123
        s = MySock()
        assert s.blah == 123

    def test_getsetsockopt(self):
        import _socket as socket
        import struct
        # A socket should start with reuse == 0
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        reuse = s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR)
        assert reuse == 0
        #
        raises(TypeError, s.setsockopt, socket.SOL_SOCKET,
                          socket.SO_REUSEADDR, 2 ** 31)
        raises(TypeError, s.setsockopt, socket.SOL_SOCKET,
                          socket.SO_REUSEADDR, 2 ** 32 + 1)
        assert s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR) == 0
        #
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        reuse = s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR)
        assert reuse != 0
        # String case
        intsize = struct.calcsize('i')
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        reusestr = s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR,
                                intsize)
        (reuse,) = struct.unpack('i', reusestr)
        assert reuse == 0
        reusestr = struct.pack('i', 1)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, reusestr)
        reusestr = s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR,
                                intsize)
        (reuse,) = struct.unpack('i', reusestr)
        assert reuse != 0
        # try to call setsockopt() with a buffer argument
        reusestr = struct.pack('i', 0)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, memoryview(reusestr))
        reusestr = s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR,
                                intsize)
        (reuse,) = struct.unpack('i', reusestr)
        assert reuse == 0

    def test_getsetsockopt_zero(self):
        # related to issue #2561: when specifying the buffer size param:
        # if 0 or None, should return the setted value,
        # otherwise an empty buffer of the specified size
        import _socket
        s = _socket.socket()
        assert s.getsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, 0) == 0
        ret = s.getsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, 2)
        if len(ret) == 1:
            # win32 returns a byte-as-bool
            assert ret == b'\x00'
        else:
            assert ret == b'\x00\x00'
        s.setsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, True)
        assert s.getsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, 0) != 0
        s.setsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, 1)
        assert s.getsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, 0) != 0

    def test_getsockopt_bad_length(self):
        import _socket
        s = _socket.socket()
        buf = s.getsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, 1024)
        if len(buf) == 1:
            # win32 returns a byte-as-bool
            assert buf == b'\x00'
        else:
            assert buf == b'\x00' * 4
        raises(_socket.error, s.getsockopt,
               _socket.IPPROTO_TCP, _socket.TCP_NODELAY, 1025)
        raises(_socket.error, s.getsockopt,
               _socket.IPPROTO_TCP, _socket.TCP_NODELAY, -1)

    def test_socket_ioctl(self):
        import _socket, sys
        if sys.platform != 'win32':
            skip("win32 only")
        assert hasattr(_socket.socket, 'ioctl')
        assert hasattr(_socket, 'SIO_RCVALL')
        assert hasattr(_socket, 'RCVALL_ON')
        assert hasattr(_socket, 'RCVALL_OFF')
        assert hasattr(_socket, 'SIO_KEEPALIVE_VALS')
        s = _socket.socket()
        raises(ValueError, s.ioctl, -1, None)
        s.ioctl(_socket.SIO_KEEPALIVE_VALS, (1, 100, 100))

    @pytest.mark.skipif(os.name != 'nt', reason="win32 only")
    def test_socket_sharelocal(self):
        import _socket, sys, os
        assert hasattr(_socket.socket, 'share')
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        with raises(OSError):
            s.listen()
        s.bind(('localhost', 0))
        s.listen(1)
        data = s.share(os.getpid())
        # emulate socket.fromshare
        s2 = _socket.socket(0, 0, 0, data)
        try:
            assert s.gettimeout() == s2.gettimeout()
            assert s.family == s2.family
            assert s.type == s2.type
            if s.proto != 0:
                assert s.proto == s2.proto
        finally:
            s.close()
            s2.close()

    def test_dup(self):
        import _socket as socket, os
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind(('localhost', 0))
        fd = socket.dup(s.fileno())
        assert s.fileno() != fd
        if os.name != 'nt':
            assert os.get_inheritable(s.fileno()) is False
            assert os.get_inheritable(fd) is False
        s_dup = socket.socket(fileno=fd)
        s_dup.close()
        s.close()

    def test_dup_error(self):
        import _socket
        raises(_socket.error, _socket.dup, 123456)

    @pytest.mark.skipif(os.name=='nt', reason="no recvmsg on win32")
    def test_recvmsg_issue2649(self):
        import _socket as socket
        listener = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(('127.0.0.1', 1234))

        s = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)
        s.sendto(b'x', ('127.0.0.1', 1234))
        with raises(BlockingIOError):
            queue = s.recvmsg(1024, 1024, socket.MSG_ERRQUEUE)

    def test_buffer(self):
        # Test that send/sendall/sendto accept a buffer as arg
        import _socket
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM, 0)
        # XXX temporarily we use python.org to test, will have more robust tests
        # in the absence of a network connection later when more parts of the
        # socket API are implemented.  Currently skip the test if there is no
        # connection.
        try:
            s.connect(("www.python.org", 80))
        except _socket.gaierror as ex:
            skip("GAIError - probably no connection: %s" % str(ex.args))
        exc = raises(TypeError, s.send, None)
        assert str(exc.value).startswith("a bytes-like object is required,")
        assert s.send(memoryview(b'')) == 0
        assert s.sendall(memoryview(b'')) is None
        exc = raises(TypeError, s.send, '')
        assert str(exc.value).startswith("a bytes-like object is required,")
        raises(TypeError, s.sendall, '')
        s.close()
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_DGRAM, 0)
        s.sendto(memoryview(b''), ('localhost', 9))  # Send to discard port.
        s.close()

    def test_listen_default(self):
        import _socket, sys
        if sys.platform == 'win32':
            with raises(OSError):
                _socket.socket().listen()
        else:
            _socket.socket().listen()
        assert isinstance(_socket.SOMAXCONN, int)

    def test_unix_socket_connect(self):
        import _socket, os
        if not hasattr(_socket, 'AF_UNIX'):
            skip('AF_UNIX not supported.')
        oldcwd = os.getcwd()
        os.chdir(self.udir)
        try:
          for sockpath in ['app_test_unix_socket_connect',
                           b'b_app_test_unix_socket_connect',
                           bytearray(b'ba_app_test_unix_socket_connect')]:

            serversock = _socket.socket(_socket.AF_UNIX)
            serversock.bind(sockpath)
            serversock.listen(1)

            clientsock = _socket.socket(_socket.AF_UNIX)
            clientsock.connect(sockpath)
            fileno, addr = serversock._accept()
            s = _socket.socket(fileno=fileno)
            assert not addr

            s.send(b'X')
            data = clientsock.recv(100)
            assert data == b'X'
            clientsock.send(b'Y')
            data = s.recv(100)
            assert data == b'Y'

            clientsock.close()
            s.close()
        finally:
            os.chdir(oldcwd)

    def test_automatic_shutdown(self):
        # doesn't really test anything, but at least should not explode
        # in close_all_sockets()
        import _socket
        self.foo = _socket.socket()

    def test_subclass_init(self):
        # Socket is not created in __new__, but in __init__.
        import _socket as socket
        class Socket_IPV6(socket.socket):
            def __init__(self):
                socket.socket.__init__(self, family=socket.AF_INET6)
        assert Socket_IPV6().family == socket.AF_INET6

    def test_subclass_noinit(self):
        from _socket import socket
        class MySock(socket):
            def __init__(self, *args):
                pass  # don't call super
        s = MySock()
        assert s.type == 0
        assert s.proto == 0
        assert s.family == 0
        assert s.fileno() < 0
        raises(OSError, s.bind, ('localhost', 0))

    def test_dealloc_warn(self):
        import _socket
        import gc
        import warnings

        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        r = repr(s)
        gc.collect()
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter('always')
            s = None
            gc.collect()
        assert len(w) == 1, [str(warning) for warning in w]
        assert r in str(w[0])

    def test_invalid_fd(self):
        import _socket
        raises(ValueError, _socket.socket, fileno=-1)
        raises(TypeError, _socket.socket, fileno=42.5)

    def test_socket_non_inheritable(self):
        import _socket, os
        s1 = _socket.socket()
        if os.name == 'nt':
            with raises(OSError):
                os.get_inheritable(s1.fileno())
        else:
            assert os.get_inheritable(s1.fileno()) is False
        s1.close()

    def test_socketpair_non_inheritable(self):
        import _socket, os
        if not hasattr(_socket, 'socketpair'):
            skip("no socketpair")
        s1, s2 = _socket.socketpair()
        assert os.get_inheritable(s1.fileno()) is False
        assert os.get_inheritable(s2.fileno()) is False
        s1.close()
        s2.close()

    def test_hostname_unicode(self):
        import _socket
        domain = u"испытание.pythontest.net"
        _socket.gethostbyname(domain)
        _socket.gethostbyname_ex(domain)
        _socket.getaddrinfo(domain, 0, _socket.AF_UNSPEC, _socket.SOCK_STREAM)
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        s.connect((domain, 80))
        s.close()
        raises(TypeError, s.connect, (domain + '\x00', 80))

    def test_socket_close(self):
        import _socket
        sock = _socket.socket()
        try:
            sock.bind(('localhost', 0))
            _socket.close(sock.fileno())
            with raises(OSError):
                sock.listen(1)
            with raises(OSError):
                _socket.close(sock.fileno())
        finally:
            with raises(OSError):
                sock.close()

    def test_socket_get_values_from_fd(self):
        import _socket
        if hasattr(_socket, "SOCK_DGRAM"):
            s = _socket.socket(_socket.AF_INET, _socket.SOCK_DGRAM)
            try:
                s.bind(('localhost', 0))
                fd = s.fileno()
                s2 = _socket.socket(fileno=fd)
                try:
                    # detach old fd to avoid double close
                    s.detach()
                    assert s2.fileno() == fd
                    assert s2.family == _socket.AF_INET
                    assert s2.type == _socket.SOCK_DGRAM

                finally:
                    s2.close()
            finally:
                s.close()

    def test_socket_init_non_blocking(self):
        import _socket
        if not hasattr(_socket, "SOCK_NONBLOCK"):
            skip("no SOCK_NONBLOCK")
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM |
                                            _socket.SOCK_NONBLOCK)
        assert s.getblocking() == False
        assert s.gettimeout() == 0.0

    def test_socket_consistent_sock_type(self):
        import _socket
        SOCK_NONBLOCK = getattr(_socket, 'SOCK_NONBLOCK', 0)
        SOCK_CLOEXEC = getattr(_socket, 'SOCK_CLOEXEC', 0)
        sock_type = _socket.SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC

        s = _socket.socket(_socket.AF_INET, sock_type)
        try:
            assert s.type == _socket.SOCK_STREAM
            s.settimeout(1)
            assert s.type == _socket.SOCK_STREAM
            s.settimeout(0)
            assert s.type == _socket.SOCK_STREAM
            s.setblocking(True)
            assert s.type == _socket.SOCK_STREAM
            s.setblocking(False)
            assert s.type == _socket.SOCK_STREAM
        finally:
            s.close()

@pytest.mark.skipif(not hasattr(os, 'getpid'),
    reason="AF_NETLINK needs os.getpid()")
class AppTestNetlink:
    spaceconfig = {'usemodules': ['_socket', 'select']}

    def test_connect_to_kernel_netlink_routing_socket(self):
        import _socket, os
        if not hasattr(_socket, 'AF_NETLINK'):
            skip("no AF_NETLINK on this platform")
        s = _socket.socket(_socket.AF_NETLINK, _socket.SOCK_DGRAM,
                           _socket.NETLINK_ROUTE)
        assert s.getsockname() == (0, 0)
        s.bind((0, 0))
        a, b = s.getsockname()
        assert a == os.getpid()
        assert b == 0


@pytest.mark.skipif(not hasattr(os, 'getuid') or os.getuid() != 0,
    reason="AF_PACKET needs to be root for testing")
class AppTestPacket:
    spaceconfig = {'usemodules': ['_socket', 'select']}

    def test_convert_between_tuple_and_sockaddr_ll(self):
        import _socket
        if not hasattr(_socket, 'AF_PACKET'):
            skip("no AF_PACKET on this platform")
        s = _socket.socket(_socket.AF_PACKET, _socket.SOCK_RAW)
        assert s.getsockname() == ('', 0, 0, 0, b''), 's.getsockname %s' % str(s.getsockname())
        s.bind(('lo', 123))
        a, b, c, d, e = s.getsockname()
        assert (a, b, c) == ('lo', 123, 0)
        assert isinstance(d, int)
        assert isinstance(e, bytes)
        assert 0 <= len(e) <= 8
        s.close()


class AppTestSocketTCP:
    HOST = 'localhost'
    spaceconfig = {'usemodules': ['_socket', 'array', 'select']}

    def setup_method(self, method):
        w_HOST = self.space.wrap(self.HOST)
        self.w_serv = self.space.appexec([w_HOST],
            '''(HOST):
            import _socket
            serv = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
            serv.bind((HOST, 0))
            serv.listen(1)
            return serv
            ''')

    def teardown_method(self, method):
        if hasattr(self, 'w_serv'):
            self.space.appexec([self.w_serv], '(serv): serv.close()')
            self.w_serv = None

    def test_timeout(self):
        from _socket import timeout
        def raise_timeout():
            self.serv.settimeout(1.0)
            self.serv._accept()
        raises(timeout, raise_timeout)

    def test_timeout_zero(self):
        from _socket import error
        def raise_error():
            self.serv.settimeout(0.0)
            foo = self.serv._accept()
        raises(error, raise_error)

    @pytest.mark.skipif(os.name == 'nt', reason="win32 has additional buffering")
    def test_recv_send_timeout(self):
        from _socket import socket, timeout, SOL_SOCKET, SO_RCVBUF, SO_SNDBUF
        import sys
        cli = socket()
        cli.settimeout(1.0)
        cli.connect(self.serv.getsockname())
        fileno, addr = self.serv._accept()
        t = socket(fileno=fileno)
        # test recv() timeout
        t.send(b'*')
        buf = cli.recv(100)
        assert buf == b'*'
        raises(timeout, cli.recv, 100)
        # test that send() works
        count = cli.send(b'!')
        assert count == 1
        buf = t.recv(1)
        assert buf == b'!'
        # test that sendall() works
        count = cli.sendall(b'?')
        assert count is None
        buf = t.recv(1)
        assert buf == b'?'
        # speed up filling the buffers
        t.setsockopt(SOL_SOCKET, SO_RCVBUF, 4096)
        cli.setsockopt(SOL_SOCKET, SO_SNDBUF, 4096)
        # test send() timeout
        count = 0
        if sys.platform != 'win32':
            # windows never fills the buffer
            try:
                while 1:
                    count += cli.send(b'foobar' * 70)
                    if sys.platform == 'darwin':
                        # MacOS will auto-tune up to 512k
                        # (net.inet.tcp.doauto{rcv,snd}buf sysctls)
                        assert count < 1000000
                    else:
                        assert count < 100000
            except timeout:
                pass
            t.recv(count)
        # test sendall() timeout
        try:
            while 1:
                cli.sendall(b'foobar' * 70)
        except timeout:
            pass
        # done
        cli.close()
        t.close()

    def test_getblocking(self):
        self.serv.setblocking(True)
        assert self.serv.getblocking()
        self.serv.setblocking(False)
        assert not self.serv.getblocking()

    def test_recv_into(self):
        import _socket as socket
        import array
        import _io
        MSG = b'dupa was here\n'
        cli = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        cli.connect(self.serv.getsockname())
        fileno, addr = self.serv._accept()
        conn = socket.socket(fileno=fileno)
        buf = memoryview(MSG)
        conn.send(buf)
        buf = array.array('b', b' ' * 1024)
        nbytes = cli.recv_into(buf)
        assert nbytes == len(MSG)
        msg = buf.tobytes()[:len(MSG)]
        assert msg == MSG

        conn.send(MSG)
        buf = bytearray(1024)
        nbytes = cli.recv_into(memoryview(buf))
        assert nbytes == len(MSG)
        msg = buf[:len(MSG)]
        assert msg == MSG

        # A case where rwbuffer.get_raw_address() fails
        conn.send(MSG)
        buf = _io.BytesIO(b' ' * 1024)
        m = buf.getbuffer()
        nbytes = cli.recv_into(m)
        assert nbytes == len(MSG)
        msg = buf.getvalue()[:len(MSG)]
        assert msg == MSG
        conn.close()

    def test_recvfrom_into(self):
        import _socket as socket
        import array
        import _io
        MSG = b'dupa was here\n'
        cli = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        cli.connect(self.serv.getsockname())
        fileno, addr = self.serv._accept()
        conn = socket.socket(fileno=fileno)
        buf = memoryview(MSG)
        conn.send(buf)
        buf = array.array('b', b' ' * 1024)
        nbytes, addr = cli.recvfrom_into(buf)
        assert nbytes == len(MSG)
        msg = buf.tobytes()[:len(MSG)]
        assert msg == MSG

        conn.send(MSG)
        buf = bytearray(1024)
        nbytes, addr = cli.recvfrom_into(memoryview(buf))
        assert nbytes == len(MSG)
        msg = buf[:len(MSG)]
        assert msg == MSG

        # A case where rwbuffer.get_raw_address() fails
        conn.send(MSG)
        buf = _io.BytesIO(b' ' * 1024)
        nbytes, addr = cli.recvfrom_into(buf.getbuffer())
        assert nbytes == len(MSG)
        msg = buf.getvalue()[:len(MSG)]
        assert msg == MSG

        conn.send(MSG)
        buf = bytearray(8)
        exc = raises(ValueError, cli.recvfrom_into, buf, 1024)
        assert str(exc.value) == "nbytes is greater than the length of the buffer"
        conn.close()

    @pytest.mark.skipif(os.name == 'nt', reason="no recvmg_into on win32")
    def test_recvmsg_into(self):
        import _socket
        cli = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        cli.connect(self.serv.getsockname())
        fileno, addr = self.serv._accept()
        conn = _socket.socket(fileno=fileno)
        conn.send(b'Hello World!')
        buf1 = bytearray(5)
        buf2 = bytearray(6)
        rettup = cli.recvmsg_into([memoryview(buf1), memoryview(buf2)])
        nbytes, _, _, addr = rettup
        assert nbytes == 11
        assert buf1 == b'Hello'
        assert buf2 == b' World'
        conn.close()
        cli.close()

    def test_family(self):
        import _socket as socket
        cli = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        assert cli.family == socket.AF_INET

    def test_missing_error_catching(self):
        from _socket import socket, error
        s = socket()
        s.close()
        raises(error, s.settimeout, 1)            # EBADF
        raises(error, s.setblocking, True)        # EBADF
        raises(error, s.getsockopt, 42, 84, 8)    # EBADF

    def test_accept_non_inheritable(self):
        import _socket, os
        cli = _socket.socket()
        cli.connect(self.serv.getsockname())
        fileno, addr = self.serv._accept()
        if os.name == 'nt':
            with raises(OSError):
                os.get_inheritable(fileno)
        else:
            assert os.get_inheritable(fileno) is False
        conn = _socket.socket(fileno=fileno)
        conn.close()
        cli.close()

    def test_recv_into_params(self):
        import os
        import _socket
        cli = _socket.socket()
        cli.connect(self.serv.getsockname())
        fileno, addr = self.serv._accept()
        conn = _socket.socket(fileno=fileno)
        conn.send(b"abcdef")
        #
        m = memoryview(bytearray(5))
        raises(ValueError, cli.recv_into, m, -1)
        raises(ValueError, cli.recv_into, m, 6)
        cli.recv_into(m, 5)
        assert m.tobytes() == b"abcde"
        conn.close()
        cli.close()

    def test_bytearray_name(self):
        import _socket as socket
        if not hasattr(socket, 'AF_UNIX'):
            skip('AF_UNIX not supported.')
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.bind(bytearray(b"\x00python\x00test\x00"))
        assert s.getsockname() == b"\x00python\x00test\x00"

    def test_no_socket_cloexec_non_block(self):
        import _socket
        #assert not hasattr(_socket, "SOCK_CLOEXEC") # not in py 2
        #assert not hasattr(_socket, "SOCK_NONBLOCK") # 3.7 only

    def test_bind_audit(self):
        import _socket
        import sys
        events = []
        def f(event, args):
            events.append((event, args))
        s = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        sys.addaudithook(f)
        s.bind(('localhost', 0))
        assert len(events) == 1
        assert events[0][0] == 'socket.bind'
        assert events[0][1][0] is s
        assert events[0][1][1] == ('localhost', 0)

class AppTestErrno:
    spaceconfig = {'usemodules': ['_socket', 'select']}

    def test_errno(self):
        from _socket import socket, AF_INET, SOCK_STREAM, error
        import errno
        s = socket(AF_INET, SOCK_STREAM)
        exc = raises(error, s._accept)
        assert isinstance(exc.value, error)
        assert isinstance(exc.value, IOError)
        # error is EINVAL, or WSAEINVAL on Windows
        assert exc.value.errno == getattr(errno, 'WSAEINVAL', errno.EINVAL)
        assert isinstance(exc.value.strerror, str)
