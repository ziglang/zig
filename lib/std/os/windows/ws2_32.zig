// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub const SOCKET = *@Type(.Opaque);
pub const INVALID_SOCKET = @intToPtr(SOCKET, ~@as(usize, 0));
pub const SOCKET_ERROR = -1;

pub const WSADESCRIPTION_LEN = 256;
pub const WSASYS_STATUS_LEN = 128;

pub const WSADATA = if (@sizeOf(usize) == @sizeOf(u64))
    extern struct {
        wVersion: WORD,
        wHighVersion: WORD,
        iMaxSockets: u16,
        iMaxUdpDg: u16,
        lpVendorInfo: *u8,
        szDescription: [WSADESCRIPTION_LEN + 1]u8,
        szSystemStatus: [WSASYS_STATUS_LEN + 1]u8,
    }
else
    extern struct {
        wVersion: WORD,
        wHighVersion: WORD,
        szDescription: [WSADESCRIPTION_LEN + 1]u8,
        szSystemStatus: [WSASYS_STATUS_LEN + 1]u8,
        iMaxSockets: u16,
        iMaxUdpDg: u16,
        lpVendorInfo: *u8,
    };

pub const MAX_PROTOCOL_CHAIN = 7;

pub const WSAPROTOCOLCHAIN = extern struct {
    ChainLen: c_int,
    ChainEntries: [MAX_PROTOCOL_CHAIN]DWORD,
};

pub const WSAPROTOCOL_LEN = 255;

pub const WSAPROTOCOL_INFOA = extern struct {
    dwServiceFlags1: DWORD,
    dwServiceFlags2: DWORD,
    dwServiceFlags3: DWORD,
    dwServiceFlags4: DWORD,
    dwProviderFlags: DWORD,
    ProviderId: GUID,
    dwCatalogEntryId: DWORD,
    ProtocolChain: WSAPROTOCOLCHAIN,
    iVersion: c_int,
    iAddressFamily: c_int,
    iMaxSockAddr: c_int,
    iMinSockAddr: c_int,
    iSocketType: c_int,
    iProtocol: c_int,
    iProtocolMaxOffset: c_int,
    iNetworkByteOrder: c_int,
    iSecurityScheme: c_int,
    dwMessageSize: DWORD,
    dwProviderReserved: DWORD,
    szProtocol: [WSAPROTOCOL_LEN + 1]CHAR,
};

pub const WSAPROTOCOL_INFOW = extern struct {
    dwServiceFlags1: DWORD,
    dwServiceFlags2: DWORD,
    dwServiceFlags3: DWORD,
    dwServiceFlags4: DWORD,
    dwProviderFlags: DWORD,
    ProviderId: GUID,
    dwCatalogEntryId: DWORD,
    ProtocolChain: WSAPROTOCOLCHAIN,
    iVersion: c_int,
    iAddressFamily: c_int,
    iMaxSockAddr: c_int,
    iMinSockAddr: c_int,
    iSocketType: c_int,
    iProtocol: c_int,
    iProtocolMaxOffset: c_int,
    iNetworkByteOrder: c_int,
    iSecurityScheme: c_int,
    dwMessageSize: DWORD,
    dwProviderReserved: DWORD,
    szProtocol: [WSAPROTOCOL_LEN + 1]WCHAR,
};

pub const GROUP = u32;

pub const SG_UNCONSTRAINED_GROUP = 0x1;
pub const SG_CONSTRAINED_GROUP = 0x2;

pub const WSA_FLAG_OVERLAPPED = 0x01;
pub const WSA_FLAG_MULTIPOINT_C_ROOT = 0x02;
pub const WSA_FLAG_MULTIPOINT_C_LEAF = 0x04;
pub const WSA_FLAG_MULTIPOINT_D_ROOT = 0x08;
pub const WSA_FLAG_MULTIPOINT_D_LEAF = 0x10;
pub const WSA_FLAG_ACCESS_SYSTEM_SECURITY = 0x40;
pub const WSA_FLAG_NO_HANDLE_INHERIT = 0x80;

pub const WSAEVENT = HANDLE;

pub const WSAOVERLAPPED = extern struct {
    Internal: DWORD,
    InternalHigh: DWORD,
    Offset: DWORD,
    OffsetHigh: DWORD,
    hEvent: ?WSAEVENT,
};

pub const WSAOVERLAPPED_COMPLETION_ROUTINE = fn (dwError: DWORD, cbTransferred: DWORD, lpOverlapped: *WSAOVERLAPPED, dwFlags: DWORD) callconv(.C) void;

pub const ADDRESS_FAMILY = u16;

// Microsoft use the signed c_int for this, but it should never be negative
const socklen_t = u32;

pub const AF_UNSPEC = 0;
pub const AF_UNIX = 1;
pub const AF_INET = 2;
pub const AF_IMPLINK = 3;
pub const AF_PUP = 4;
pub const AF_CHAOS = 5;
pub const AF_NS = 6;
pub const AF_IPX = AF_NS;
pub const AF_ISO = 7;
pub const AF_OSI = AF_ISO;
pub const AF_ECMA = 8;
pub const AF_DATAKIT = 9;
pub const AF_CCITT = 10;
pub const AF_SNA = 11;
pub const AF_DECnet = 12;
pub const AF_DLI = 13;
pub const AF_LAT = 14;
pub const AF_HYLINK = 15;
pub const AF_APPLETALK = 16;
pub const AF_NETBIOS = 17;
pub const AF_VOICEVIEW = 18;
pub const AF_FIREFOX = 19;
pub const AF_UNKNOWN1 = 20;
pub const AF_BAN = 21;
pub const AF_ATM = 22;
pub const AF_INET6 = 23;
pub const AF_CLUSTER = 24;
pub const AF_12844 = 25;
pub const AF_IRDA = 26;
pub const AF_NETDES = 28;
pub const AF_TCNPROCESS = 29;
pub const AF_TCNMESSAGE = 30;
pub const AF_ICLFXBM = 31;
pub const AF_BTH = 32;
pub const AF_MAX = 33;

pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;

pub const IPPROTO_ICMP = 1;
pub const IPPROTO_IGMP = 2;
pub const BTHPROTO_RFCOMM = 3;
pub const IPPROTO_TCP = 6;
pub const IPPROTO_UDP = 17;
pub const IPPROTO_ICMPV6 = 58;
pub const IPPROTO_RM = 113;

pub const AI_PASSIVE = 0x00001;
pub const AI_CANONNAME = 0x00002;
pub const AI_NUMERICHOST = 0x00004;
pub const AI_NUMERICSERV = 0x00008;
pub const AI_ADDRCONFIG = 0x00400;
pub const AI_V4MAPPED = 0x00800;
pub const AI_NON_AUTHORITATIVE = 0x04000;
pub const AI_SECURE = 0x08000;
pub const AI_RETURN_PREFERRED_NAMES = 0x10000;
pub const AI_DISABLE_IDN_ENCODING = 0x80000;

pub const FIONBIO = -2147195266;

pub const sockaddr = extern struct {
    family: ADDRESS_FAMILY,
    data: [14]u8,
};

pub const addrinfo = extern struct {
    flags: i32,
    family: i32,
    socktype: i32,
    protocol: i32,
    addrlen: usize,
    canonname: ?[*:0]u8,
    addr: ?*sockaddr,
    next: ?*addrinfo,
};

/// IPv4 socket address
pub const sockaddr_in = extern struct {
    family: ADDRESS_FAMILY = AF_INET,
    port: USHORT,
    addr: u32,
    zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
};

/// IPv6 socket address
pub const sockaddr_in6 = extern struct {
    family: ADDRESS_FAMILY = AF_INET6,
    port: USHORT,
    flowinfo: u32,
    addr: [16]u8,
    scope_id: u32,
};

/// UNIX domain socket address
pub const sockaddr_un = extern struct {
    family: ADDRESS_FAMILY = AF_UNIX,
    path: [108]u8,
};

pub const WSABUF = extern struct {
    len: ULONG,
    buf: [*]u8,
};

pub const WSAMSG = extern struct {
    name: *const sockaddr,
    namelen: INT,
    lpBuffers: [*]WSABUF,
    dwBufferCount: DWORD,
    Control: WSABUF,
    dwFlags: DWORD,
};

// https://docs.microsoft.com/en-au/windows/win32/winsock/windows-sockets-error-codes-2
pub const WinsockError = extern enum(u16) {
    /// Specified event object handle is invalid.
    /// An application attempts to use an event object, but the specified handle is not valid.
    WSA_INVALID_HANDLE = 6,

    /// Insufficient memory available.
    /// An application used a Windows Sockets function that directly maps to a Windows function.
    /// The Windows function is indicating a lack of required memory resources.
    WSA_NOT_ENOUGH_MEMORY = 8,

    /// One or more parameters are invalid.
    /// An application used a Windows Sockets function which directly maps to a Windows function.
    /// The Windows function is indicating a problem with one or more parameters.
    WSA_INVALID_PARAMETER = 87,

    /// Overlapped operation aborted.
    /// An overlapped operation was canceled due to the closure of the socket, or the execution of the SIO_FLUSH command in WSAIoctl.
    WSA_OPERATION_ABORTED = 995,

    /// Overlapped I/O event object not in signaled state.
    /// The application has tried to determine the status of an overlapped operation which is not yet completed.
    /// Applications that use WSAGetOverlappedResult (with the fWait flag set to FALSE) in a polling mode to determine when an overlapped operation has completed, get this error code until the operation is complete.
    WSA_IO_INCOMPLETE = 996,

    /// The application has initiated an overlapped operation that cannot be completed immediately.
    /// A completion indication will be given later when the operation has been completed.
    WSA_IO_PENDING = 997,

    /// Interrupted function call.
    /// A blocking operation was interrupted by a call to WSACancelBlockingCall.
    WSAEINTR = 10004,

    /// File handle is not valid.
    /// The file handle supplied is not valid.
    WSAEBADF = 10009,

    /// Permission denied.
    /// An attempt was made to access a socket in a way forbidden by its access permissions.
    /// An example is using a broadcast address for sendto without broadcast permission being set using setsockopt(SO_BROADCAST).
    /// Another possible reason for the WSAEACCES error is that when the bind function is called (on Windows NT 4.0 with SP4 and later), another application, service, or kernel mode driver is bound to the same address with exclusive access.
    /// Such exclusive access is a new feature of Windows NT 4.0 with SP4 and later, and is implemented by using the SO_EXCLUSIVEADDRUSE option.
    WSAEACCES = 10013,

    /// Bad address.
    /// The system detected an invalid pointer address in attempting to use a pointer argument of a call.
    /// This error occurs if an application passes an invalid pointer value, or if the length of the buffer is too small.
    /// For instance, if the length of an argument, which is a sockaddr structure, is smaller than the sizeof(sockaddr).
    WSAEFAULT = 10014,

    /// Invalid argument.
    /// Some invalid argument was supplied (for example, specifying an invalid level to the setsockopt function).
    /// In some instances, it also refers to the current state of the socket—for instance, calling accept on a socket that is not listening.
    WSAEINVAL = 10022,

    /// Too many open files.
    /// Too many open sockets. Each implementation may have a maximum number of socket handles available, either globally, per process, or per thread.
    WSAEMFILE = 10024,

    /// Resource temporarily unavailable.
    /// This error is returned from operations on nonblocking sockets that cannot be completed immediately, for example recv when no data is queued to be read from the socket.
    /// It is a nonfatal error, and the operation should be retried later.
    /// It is normal for WSAEWOULDBLOCK to be reported as the result from calling connect on a nonblocking SOCK_STREAM socket, since some time must elapse for the connection to be established.
    WSAEWOULDBLOCK = 10035,

    /// Operation now in progress.
    /// A blocking operation is currently executing.
    /// Windows Sockets only allows a single blocking operation—per- task or thread—to be outstanding, and if any other function call is made (whether or not it references that or any other socket) the function fails with the WSAEINPROGRESS error.
    WSAEINPROGRESS = 10036,

    /// Operation already in progress.
    /// An operation was attempted on a nonblocking socket with an operation already in progress—that is, calling connect a second time on a nonblocking socket that is already connecting, or canceling an asynchronous request (WSAAsyncGetXbyY) that has already been canceled or completed.
    WSAEALREADY = 10037,

    /// Socket operation on nonsocket.
    /// An operation was attempted on something that is not a socket.
    /// Either the socket handle parameter did not reference a valid socket, or for select, a member of an fd_set was not valid.
    WSAENOTSOCK = 10038,

    /// Destination address required.
    /// A required address was omitted from an operation on a socket.
    /// For example, this error is returned if sendto is called with the remote address of ADDR_ANY.
    WSAEDESTADDRREQ = 10039,

    /// Message too long.
    /// A message sent on a datagram socket was larger than the internal message buffer or some other network limit, or the buffer used to receive a datagram was smaller than the datagram itself.
    WSAEMSGSIZE = 10040,

    /// Protocol wrong type for socket.
    /// A protocol was specified in the socket function call that does not support the semantics of the socket type requested.
    /// For example, the ARPA Internet UDP protocol cannot be specified with a socket type of SOCK_STREAM.
    WSAEPROTOTYPE = 10041,

    /// Bad protocol option.
    /// An unknown, invalid or unsupported option or level was specified in a getsockopt or setsockopt call.
    WSAENOPROTOOPT = 10042,

    /// Protocol not supported.
    /// The requested protocol has not been configured into the system, or no implementation for it exists.
    /// For example, a socket call requests a SOCK_DGRAM socket, but specifies a stream protocol.
    WSAEPROTONOSUPPORT = 10043,

    /// Socket type not supported.
    /// The support for the specified socket type does not exist in this address family.
    /// For example, the optional type SOCK_RAW might be selected in a socket call, and the implementation does not support SOCK_RAW sockets at all.
    WSAESOCKTNOSUPPORT = 10044,

    /// Operation not supported.
    /// The attempted operation is not supported for the type of object referenced.
    /// Usually this occurs when a socket descriptor to a socket that cannot support this operation is trying to accept a connection on a datagram socket.
    WSAEOPNOTSUPP = 10045,

    /// Protocol family not supported.
    /// The protocol family has not been configured into the system or no implementation for it exists.
    /// This message has a slightly different meaning from WSAEAFNOSUPPORT.
    /// However, it is interchangeable in most cases, and all Windows Sockets functions that return one of these messages also specify WSAEAFNOSUPPORT.
    WSAEPFNOSUPPORT = 10046,

    /// Address family not supported by protocol family.
    /// An address incompatible with the requested protocol was used.
    /// All sockets are created with an associated address family (that is, AF_INET for Internet Protocols) and a generic protocol type (that is, SOCK_STREAM).
    /// This error is returned if an incorrect protocol is explicitly requested in the socket call, or if an address of the wrong family is used for a socket, for example, in sendto.
    WSAEAFNOSUPPORT = 10047,

    /// Address already in use.
    /// Typically, only one usage of each socket address (protocol/IP address/port) is permitted.
    /// This error occurs if an application attempts to bind a socket to an IP address/port that has already been used for an existing socket, or a socket that was not closed properly, or one that is still in the process of closing.
    /// For server applications that need to bind multiple sockets to the same port number, consider using setsockopt (SO_REUSEADDR).
    /// Client applications usually need not call bind at all—connect chooses an unused port automatically.
    /// When bind is called with a wildcard address (involving ADDR_ANY), a WSAEADDRINUSE error could be delayed until the specific address is committed.
    /// This could happen with a call to another function later, including connect, listen, WSAConnect, or WSAJoinLeaf.
    WSAEADDRINUSE = 10048,

    /// Cannot assign requested address.
    /// The requested address is not valid in its context.
    /// This normally results from an attempt to bind to an address that is not valid for the local computer.
    /// This can also result from connect, sendto, WSAConnect, WSAJoinLeaf, or WSASendTo when the remote address or port is not valid for a remote computer (for example, address or port 0).
    WSAEADDRNOTAVAIL = 10049,

    /// Network is down.
    /// A socket operation encountered a dead network.
    /// This could indicate a serious failure of the network system (that is, the protocol stack that the Windows Sockets DLL runs over), the network interface, or the local network itself.
    WSAENETDOWN = 10050,

    /// Network is unreachable.
    /// A socket operation was attempted to an unreachable network.
    /// This usually means the local software knows no route to reach the remote host.
    WSAENETUNREACH = 10051,

    /// Network dropped connection on reset.
    /// The connection has been broken due to keep-alive activity detecting a failure while the operation was in progress.
    /// It can also be returned by setsockopt if an attempt is made to set SO_KEEPALIVE on a connection that has already failed.
    WSAENETRESET = 10052,

    /// Software caused connection abort.
    /// An established connection was aborted by the software in your host computer, possibly due to a data transmission time-out or protocol error.
    WSAECONNABORTED = 10053,

    /// Connection reset by peer.
    /// An existing connection was forcibly closed by the remote host.
    /// This normally results if the peer application on the remote host is suddenly stopped, the host is rebooted, the host or remote network interface is disabled, or the remote host uses a hard close (see setsockopt for more information on the SO_LINGER option on the remote socket).
    /// This error may also result if a connection was broken due to keep-alive activity detecting a failure while one or more operations are in progress.
    /// Operations that were in progress fail with WSAENETRESET. Subsequent operations fail with WSAECONNRESET.
    WSAECONNRESET = 10054,

    /// No buffer space available.
    /// An operation on a socket could not be performed because the system lacked sufficient buffer space or because a queue was full.
    WSAENOBUFS = 10055,

    /// Socket is already connected.
    /// A connect request was made on an already-connected socket.
    /// Some implementations also return this error if sendto is called on a connected SOCK_DGRAM socket (for SOCK_STREAM sockets, the to parameter in sendto is ignored) although other implementations treat this as a legal occurrence.
    WSAEISCONN = 10056,

    /// Socket is not connected.
    /// A request to send or receive data was disallowed because the socket is not connected and (when sending on a datagram socket using sendto) no address was supplied.
    /// Any other type of operation might also return this error—for example, setsockopt setting SO_KEEPALIVE if the connection has been reset.
    WSAENOTCONN = 10057,

    /// Cannot send after socket shutdown.
    /// A request to send or receive data was disallowed because the socket had already been shut down in that direction with a previous shutdown call.
    /// By calling shutdown a partial close of a socket is requested, which is a signal that sending or receiving, or both have been discontinued.
    WSAESHUTDOWN = 10058,

    /// Too many references.
    /// Too many references to some kernel object.
    WSAETOOMANYREFS = 10059,

    /// Connection timed out.
    /// A connection attempt failed because the connected party did not properly respond after a period of time, or the established connection failed because the connected host has failed to respond.
    WSAETIMEDOUT = 10060,

    /// Connection refused.
    /// No connection could be made because the target computer actively refused it.
    /// This usually results from trying to connect to a service that is inactive on the foreign host—that is, one with no server application running.
    WSAECONNREFUSED = 10061,

    /// Cannot translate name.
    /// Cannot translate a name.
    WSAELOOP = 10062,

    /// Name too long.
    /// A name component or a name was too long.
    WSAENAMETOOLONG = 10063,

    /// Host is down.
    /// A socket operation failed because the destination host is down. A socket operation encountered a dead host.
    /// Networking activity on the local host has not been initiated.
    /// These conditions are more likely to be indicated by the error WSAETIMEDOUT.
    WSAEHOSTDOWN = 10064,

    /// No route to host.
    /// A socket operation was attempted to an unreachable host. See WSAENETUNREACH.
    WSAEHOSTUNREACH = 10065,

    /// Directory not empty.
    /// Cannot remove a directory that is not empty.
    WSAENOTEMPTY = 10066,

    /// Too many processes.
    /// A Windows Sockets implementation may have a limit on the number of applications that can use it simultaneously.
    /// WSAStartup may fail with this error if the limit has been reached.
    WSAEPROCLIM = 10067,

    /// User quota exceeded.
    /// Ran out of user quota.
    WSAEUSERS = 10068,

    /// Disk quota exceeded.
    /// Ran out of disk quota.
    WSAEDQUOT = 10069,

    /// Stale file handle reference.
    /// The file handle reference is no longer available.
    WSAESTALE = 10070,

    /// Item is remote.
    /// The item is not available locally.
    WSAEREMOTE = 10071,

    /// Network subsystem is unavailable.
    /// This error is returned by WSAStartup if the Windows Sockets implementation cannot function at this time because the underlying system it uses to provide network services is currently unavailable.
    /// Users should check:
    ///   - That the appropriate Windows Sockets DLL file is in the current path.
    ///   - That they are not trying to use more than one Windows Sockets implementation simultaneously.
    ///   - If there is more than one Winsock DLL on your system, be sure the first one in the path is appropriate for the network subsystem currently loaded.
    ///   - The Windows Sockets implementation documentation to be sure all necessary components are currently installed and configured correctly.
    WSASYSNOTREADY = 10091,

    /// Winsock.dll version out of range.
    /// The current Windows Sockets implementation does not support the Windows Sockets specification version requested by the application.
    /// Check that no old Windows Sockets DLL files are being accessed.
    WSAVERNOTSUPPORTED = 10092,

    /// Successful WSAStartup not yet performed.
    /// Either the application has not called WSAStartup or WSAStartup failed.
    /// The application may be accessing a socket that the current active task does not own (that is, trying to share a socket between tasks), or WSACleanup has been called too many times.
    WSANOTINITIALISED = 10093,

    /// Graceful shutdown in progress.
    /// Returned by WSARecv and WSARecvFrom to indicate that the remote party has initiated a graceful shutdown sequence.
    WSAEDISCON = 10101,

    /// No more results.
    /// No more results can be returned by the WSALookupServiceNext function.
    WSAENOMORE = 10102,

    /// Call has been canceled.
    /// A call to the WSALookupServiceEnd function was made while this call was still processing. The call has been canceled.
    WSAECANCELLED = 10103,

    /// Procedure call table is invalid.
    /// The service provider procedure call table is invalid.
    /// A service provider returned a bogus procedure table to Ws2_32.dll.
    /// This is usually caused by one or more of the function pointers being NULL.
    WSAEINVALIDPROCTABLE = 10104,

    /// Service provider is invalid.
    /// The requested service provider is invalid.
    /// This error is returned by the WSCGetProviderInfo and WSCGetProviderInfo32 functions if the protocol entry specified could not be found.
    /// This error is also returned if the service provider returned a version number other than 2.0.
    WSAEINVALIDPROVIDER = 10105,

    /// Service provider failed to initialize.
    /// The requested service provider could not be loaded or initialized.
    /// This error is returned if either a service provider's DLL could not be loaded (LoadLibrary failed) or the provider's WSPStartup or NSPStartup function failed.
    WSAEPROVIDERFAILEDINIT = 10106,

    /// System call failure.
    /// A system call that should never fail has failed.
    /// This is a generic error code, returned under various conditions.
    /// Returned when a system call that should never fail does fail.
    /// For example, if a call to WaitForMultipleEvents fails or one of the registry functions fails trying to manipulate the protocol/namespace catalogs.
    /// Returned when a provider does not return SUCCESS and does not provide an extended error code.
    /// Can indicate a service provider implementation error.
    WSASYSCALLFAILURE = 10107,

    /// Service not found.
    /// No such service is known. The service cannot be found in the specified name space.
    WSASERVICE_NOT_FOUND = 10108,

    /// Class type not found.
    /// The specified class was not found.
    WSATYPE_NOT_FOUND = 10109,

    /// No more results.
    /// No more results can be returned by the WSALookupServiceNext function.
    WSA_E_NO_MORE = 10110,

    /// Call was canceled.
    /// A call to the WSALookupServiceEnd function was made while this call was still processing. The call has been canceled.
    WSA_E_CANCELLED = 10111,

    /// Database query was refused.
    /// A database query failed because it was actively refused.
    WSAEREFUSED = 10112,

    /// Host not found.
    /// No such host is known. The name is not an official host name or alias, or it cannot be found in the database(s) being queried.
    /// This error may also be returned for protocol and service queries, and means that the specified name could not be found in the relevant database.
    WSAHOST_NOT_FOUND = 11001,

    /// Nonauthoritative host not found.
    /// This is usually a temporary error during host name resolution and means that the local server did not receive a response from an authoritative server. A retry at some time later may be successful.
    WSATRY_AGAIN = 11002,

    /// This is a nonrecoverable error.
    /// This indicates that some sort of nonrecoverable error occurred during a database lookup.
    /// This may be because the database files (for example, BSD-compatible HOSTS, SERVICES, or PROTOCOLS files) could not be found, or a DNS request was returned by the server with a severe error.
    WSANO_RECOVERY = 11003,

    /// Valid name, no data record of requested type.
    /// The requested name is valid and was found in the database, but it does not have the correct associated data being resolved for.
    /// The usual example for this is a host name-to-address translation attempt (using gethostbyname or WSAAsyncGetHostByName) which uses the DNS (Domain Name Server).
    /// An MX record is returned but no A record—indicating the host itself exists, but is not directly reachable.
    WSANO_DATA = 11004,

    /// QoS receivers.
    /// At least one QoS reserve has arrived.
    WSA_QOS_RECEIVERS = 11005,

    /// QoS senders.
    /// At least one QoS send path has arrived.
    WSA_QOS_SENDERS = 11006,

    /// No QoS senders.
    /// There are no QoS senders.
    WSA_QOS_NO_SENDERS = 11007,

    /// QoS no receivers.
    /// There are no QoS receivers.
    WSA_QOS_NO_RECEIVERS = 11008,

    /// QoS request confirmed.
    /// The QoS reserve request has been confirmed.
    WSA_QOS_REQUEST_CONFIRMED = 11009,

    /// QoS admission error.
    /// A QoS error occurred due to lack of resources.
    WSA_QOS_ADMISSION_FAILURE = 11010,

    /// QoS policy failure.
    /// The QoS request was rejected because the policy system couldn't allocate the requested resource within the existing policy.
    WSA_QOS_POLICY_FAILURE = 11011,

    /// QoS bad style.
    /// An unknown or conflicting QoS style was encountered.
    WSA_QOS_BAD_STYLE = 11012,

    /// QoS bad object.
    /// A problem was encountered with some part of the filterspec or the provider-specific buffer in general.
    WSA_QOS_BAD_OBJECT = 11013,

    /// QoS traffic control error.
    /// An error with the underlying traffic control (TC) API as the generic QoS request was converted for local enforcement by the TC API.
    /// This could be due to an out of memory error or to an internal QoS provider error.
    WSA_QOS_TRAFFIC_CTRL_ERROR = 11014,

    /// QoS generic error.
    /// A general QoS error.
    WSA_QOS_GENERIC_ERROR = 11015,

    /// QoS service type error.
    /// An invalid or unrecognized service type was found in the QoS flowspec.
    WSA_QOS_ESERVICETYPE = 11016,

    /// QoS flowspec error.
    /// An invalid or inconsistent flowspec was found in the QOS structure.
    WSA_QOS_EFLOWSPEC = 11017,

    /// Invalid QoS provider buffer.
    /// An invalid QoS provider-specific buffer.
    WSA_QOS_EPROVSPECBUF = 11018,

    /// Invalid QoS filter style.
    /// An invalid QoS filter style was used.
    WSA_QOS_EFILTERSTYLE = 11019,

    /// Invalid QoS filter type.
    /// An invalid QoS filter type was used.
    WSA_QOS_EFILTERTYPE = 11020,

    /// Incorrect QoS filter count.
    /// An incorrect number of QoS FILTERSPECs were specified in the FLOWDESCRIPTOR.
    WSA_QOS_EFILTERCOUNT = 11021,

    /// Invalid QoS object length.
    /// An object with an invalid ObjectLength field was specified in the QoS provider-specific buffer.
    WSA_QOS_EOBJLENGTH = 11022,

    /// Incorrect QoS flow count.
    /// An incorrect number of flow descriptors was specified in the QoS structure.
    WSA_QOS_EFLOWCOUNT = 11023,

    /// Unrecognized QoS object.
    /// An unrecognized object was found in the QoS provider-specific buffer.
    WSA_QOS_EUNKOWNPSOBJ = 11024,

    /// Invalid QoS policy object.
    /// An invalid policy object was found in the QoS provider-specific buffer.
    WSA_QOS_EPOLICYOBJ = 11025,

    /// Invalid QoS flow descriptor.
    /// An invalid QoS flow descriptor was found in the flow descriptor list.
    WSA_QOS_EFLOWDESC = 11026,

    /// Invalid QoS provider-specific flowspec.
    /// An invalid or inconsistent flowspec was found in the QoS provider-specific buffer.
    WSA_QOS_EPSFLOWSPEC = 11027,

    /// Invalid QoS provider-specific filterspec.
    /// An invalid FILTERSPEC was found in the QoS provider-specific buffer.
    WSA_QOS_EPSFILTERSPEC = 11028,

    /// Invalid QoS shape discard mode object.
    /// An invalid shape discard mode object was found in the QoS provider-specific buffer.
    WSA_QOS_ESDMODEOBJ = 11029,

    /// Invalid QoS shaping rate object.
    /// An invalid shaping rate object was found in the QoS provider-specific buffer.
    WSA_QOS_ESHAPERATEOBJ = 11030,

    /// Reserved policy QoS element type.
    /// A reserved policy element was found in the QoS provider-specific buffer.
    WSA_QOS_RESERVED_PETYPE = 11031,

    _,
};

/// no parameters
const IOC_VOID = 0x80000000;

/// copy out parameters
const IOC_OUT = 0x40000000;

/// copy in parameters
const IOC_IN = 0x80000000;

/// The IOCTL is a generic Windows Sockets 2 IOCTL code. New IOCTL codes defined for Windows Sockets 2 will have T == 1.
const IOC_WS2 = 0x08000000;

pub const SIO_BASE_HANDLE = IOC_OUT | IOC_WS2 | 34;

pub extern "ws2_32" fn WSAStartup(
    wVersionRequired: WORD,
    lpWSAData: *WSADATA,
) callconv(.Stdcall) c_int;
pub extern "ws2_32" fn WSACleanup() callconv(.Stdcall) c_int;
pub extern "ws2_32" fn WSAGetLastError() callconv(.Stdcall) WinsockError;
pub extern "ws2_32" fn WSASocketA(
    af: c_int,
    type: c_int,
    protocol: c_int,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOA,
    g: GROUP,
    dwFlags: DWORD,
) callconv(.Stdcall) SOCKET;
pub extern "ws2_32" fn WSASocketW(
    af: c_int,
    type: c_int,
    protocol: c_int,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOW,
    g: GROUP,
    dwFlags: DWORD,
) callconv(.Stdcall) SOCKET;
pub extern "ws2_32" fn closesocket(s: SOCKET) callconv(.Stdcall) c_int;
pub extern "ws2_32" fn WSAIoctl(
    s: SOCKET,
    dwIoControlCode: DWORD,
    lpvInBuffer: ?*const c_void,
    cbInBuffer: DWORD,
    lpvOutBuffer: ?LPVOID,
    cbOutBuffer: DWORD,
    lpcbBytesReturned: LPDWORD,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(.Stdcall) c_int;
pub extern "ws2_32" fn accept(
    s: SOCKET,
    addr: ?*sockaddr,
    addrlen: socklen_t,
) callconv(.Stdcall) SOCKET;
pub extern "ws2_32" fn connect(
    s: SOCKET,
    name: *const sockaddr,
    namelen: socklen_t,
) callconv(.Stdcall) c_int;
pub extern "ws2_32" fn WSARecv(
    s: SOCKET,
    lpBuffers: [*]const WSABUF,
    dwBufferCount: DWORD,
    lpNumberOfBytesRecvd: ?*DWORD,
    lpFlags: *DWORD,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(.Stdcall) c_int;
pub extern "ws2_32" fn WSARecvFrom(
    s: SOCKET,
    lpBuffers: [*]const WSABUF,
    dwBufferCount: DWORD,
    lpNumberOfBytesRecvd: ?*DWORD,
    lpFlags: *DWORD,
    lpFrom: ?*sockaddr,
    lpFromlen: ?*socklen_t,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(.Stdcall) c_int;
pub extern "ws2_32" fn WSASend(
    s: SOCKET,
    lpBuffers: [*]WSABUF,
    dwBufferCount: DWORD,
    lpNumberOfBytesSent: ?*DWORD,
    dwFlags: DWORD,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(.Stdcall) c_int;
pub extern "ws2_32" fn WSASendTo(
    s: SOCKET,
    lpBuffers: [*]WSABUF,
    dwBufferCount: DWORD,
    lpNumberOfBytesSent: ?*DWORD,
    dwFlags: DWORD,
    lpTo: ?*const sockaddr,
    iTolen: socklen_t,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(.Stdcall) c_int;
pub extern "ws2_32" fn getaddrinfo(
    pNodeName: [*:0]const u8,
    pServiceName: [*:0]const u8,
    pHints: *const addrinfo,
    ppResult: **addrinfo,
) callconv(.Stdcall) i32;
pub extern "ws2_32" fn freeaddrinfo(
    pAddrInfo: *addrinfo,
) callconv(.Stdcall) void;
pub extern "ws2_32" fn ioctlsocket(
    s: SOCKET,
    cmd: c_long,
    argp: *c_ulong,
) callconv(.Stdcall) c_int;
