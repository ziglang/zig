usingnamespace @import("bits.zig");

pub const SOCKET = *@OpaqueType();
pub const INVALID_SOCKET = @intToPtr(SOCKET, ~@as(usize, 0));
pub const SOCKET_ERROR = -1;

pub const WSADESCRIPTION_LEN = 256;
pub const WSASYS_STATUS_LEN = 128;

pub const WSADATA = if (usize.bit_count == u64.bit_count)
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

pub const WSAOVERLAPPED_COMPLETION_ROUTINE = extern fn (dwError: DWORD, cbTransferred: DWORD, lpOverlapped: *WSAOVERLAPPED, dwFlags: DWORD) void;

pub const ADDRESS_FAMILY = u16;

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

pub const sockaddr = extern struct {
    family: ADDRESS_FAMILY,
    data: [14]u8,
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

pub const WSA_INVALID_HANDLE = 6;
pub const WSA_NOT_ENOUGH_MEMORY = 8;
pub const WSA_INVALID_PARAMETER = 87;
pub const WSA_OPERATION_ABORTED = 995;
pub const WSA_IO_INCOMPLETE = 996;
pub const WSA_IO_PENDING = 997;
pub const WSAEINTR = 10004;
pub const WSAEBADF = 10009;
pub const WSAEACCES = 10013;
pub const WSAEFAULT = 10014;
pub const WSAEINVAL = 10022;
pub const WSAEMFILE = 10024;
pub const WSAEWOULDBLOCK = 10035;
pub const WSAEINPROGRESS = 10036;
pub const WSAEALREADY = 10037;
pub const WSAENOTSOCK = 10038;
pub const WSAEDESTADDRREQ = 10039;
pub const WSAEMSGSIZE = 10040;
pub const WSAEPROTOTYPE = 10041;
pub const WSAENOPROTOOPT = 10042;
pub const WSAEPROTONOSUPPORT = 10043;
pub const WSAESOCKTNOSUPPORT = 10044;
pub const WSAEOPNOTSUPP = 10045;
pub const WSAEPFNOSUPPORT = 10046;
pub const WSAEAFNOSUPPORT = 10047;
pub const WSAEADDRINUSE = 10048;
pub const WSAEADDRNOTAVAIL = 10049;
pub const WSAENETDOWN = 10050;
pub const WSAENETUNREACH = 10051;
pub const WSAENETRESET = 10052;
pub const WSAECONNABORTED = 10053;
pub const WSAECONNRESET = 10054;
pub const WSAENOBUFS = 10055;
pub const WSAEISCONN = 10056;
pub const WSAENOTCONN = 10057;
pub const WSAESHUTDOWN = 10058;
pub const WSAETOOMANYREFS = 10059;
pub const WSAETIMEDOUT = 10060;
pub const WSAECONNREFUSED = 10061;
pub const WSAELOOP = 10062;
pub const WSAENAMETOOLONG = 10063;
pub const WSAEHOSTDOWN = 10064;
pub const WSAEHOSTUNREACH = 10065;
pub const WSAENOTEMPTY = 10066;
pub const WSAEPROCLIM = 10067;
pub const WSAEUSERS = 10068;
pub const WSAEDQUOT = 10069;
pub const WSAESTALE = 10070;
pub const WSAEREMOTE = 10071;
pub const WSASYSNOTREADY = 10091;
pub const WSAVERNOTSUPPORTED = 10092;
pub const WSANOTINITIALISED = 10093;
pub const WSAEDISCON = 10101;
pub const WSAENOMORE = 10102;
pub const WSAECANCELLED = 10103;
pub const WSAEINVALIDPROCTABLE = 10104;
pub const WSAEINVALIDPROVIDER = 10105;
pub const WSAEPROVIDERFAILEDINIT = 10106;
pub const WSASYSCALLFAILURE = 10107;
pub const WSASERVICE_NOT_FOUND = 10108;
pub const WSATYPE_NOT_FOUND = 10109;
pub const WSA_E_NO_MORE = 10110;
pub const WSA_E_CANCELLED = 10111;
pub const WSAEREFUSED = 10112;
pub const WSAHOST_NOT_FOUND = 11001;
pub const WSATRY_AGAIN = 11002;
pub const WSANO_RECOVERY = 11003;
pub const WSANO_DATA = 11004;
pub const WSA_QOS_RECEIVERS = 11005;
pub const WSA_QOS_SENDERS = 11006;
pub const WSA_QOS_NO_SENDERS = 11007;
pub const WSA_QOS_NO_RECEIVERS = 11008;
pub const WSA_QOS_REQUEST_CONFIRMED = 11009;
pub const WSA_QOS_ADMISSION_FAILURE = 11010;
pub const WSA_QOS_POLICY_FAILURE = 11011;
pub const WSA_QOS_BAD_STYLE = 11012;
pub const WSA_QOS_BAD_OBJECT = 11013;
pub const WSA_QOS_TRAFFIC_CTRL_ERROR = 11014;
pub const WSA_QOS_GENERIC_ERROR = 11015;
pub const WSA_QOS_ESERVICETYPE = 11016;
pub const WSA_QOS_EFLOWSPEC = 11017;
pub const WSA_QOS_EPROVSPECBUF = 11018;
pub const WSA_QOS_EFILTERSTYLE = 11019;
pub const WSA_QOS_EFILTERTYPE = 11020;
pub const WSA_QOS_EFILTERCOUNT = 11021;
pub const WSA_QOS_EOBJLENGTH = 11022;
pub const WSA_QOS_EFLOWCOUNT = 11023;
pub const WSA_QOS_EUNKOWNPSOBJ = 11024;
pub const WSA_QOS_EPOLICYOBJ = 11025;
pub const WSA_QOS_EFLOWDESC = 11026;
pub const WSA_QOS_EPSFLOWSPEC = 11027;
pub const WSA_QOS_EPSFILTERSPEC = 11028;
pub const WSA_QOS_ESDMODEOBJ = 11029;
pub const WSA_QOS_ESHAPERATEOBJ = 11030;
pub const WSA_QOS_RESERVED_PETYPE = 11031;

/// no parameters
const IOC_VOID = 0x80000000;

/// copy out parameters
const IOC_OUT = 0x40000000;

/// copy in parameters
const IOC_IN = 0x80000000;

/// The IOCTL is a generic Windows Sockets 2 IOCTL code. New IOCTL codes defined for Windows Sockets 2 will have T == 1.
const IOC_WS2 = 0x08000000;

pub const SIO_BASE_HANDLE = IOC_OUT | IOC_WS2 | 34;

pub extern "ws2_32" stdcallcc fn WSAStartup(
    wVersionRequired: WORD,
    lpWSAData: *WSADATA,
) c_int;
pub extern "ws2_32" stdcallcc fn WSACleanup() c_int;
pub extern "ws2_32" stdcallcc fn WSAGetLastError() c_int;
pub extern "ws2_32" stdcallcc fn WSASocketA(
    af: c_int,
    type: c_int,
    protocol: c_int,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOA,
    g: GROUP,
    dwFlags: DWORD,
) SOCKET;
pub extern "ws2_32" stdcallcc fn WSASocketW(
    af: c_int,
    type: c_int,
    protocol: c_int,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOW,
    g: GROUP,
    dwFlags: DWORD,
) SOCKET;
pub extern "ws2_32" stdcallcc fn closesocket(s: SOCKET) c_int;
pub extern "ws2_32" stdcallcc fn WSAIoctl(
    s: SOCKET,
    dwIoControlCode: DWORD,
    lpvInBuffer: ?*const c_void,
    cbInBuffer: DWORD,
    lpvOutBuffer: ?LPVOID,
    cbOutBuffer: DWORD,
    lpcbBytesReturned: LPDWORD,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) c_int;
pub extern "ws2_32" stdcallcc fn accept(
    s: SOCKET,
    addr: ?*sockaddr,
    addrlen: c_int,
) SOCKET;
pub extern "ws2_32" stdcallcc fn connect(
    s: SOCKET,
    name: *const sockaddr,
    namelen: c_int,
) c_int;
pub extern "ws2_32" stdcallcc fn WSARecv(
    s: SOCKET,
    lpBuffers: [*]const WSABUF,
    dwBufferCount: DWORD,
    lpNumberOfBytesRecvd: ?*DWORD,
    lpFlags: *DWORD,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) c_int;
pub extern "ws2_32" stdcallcc fn WSARecvFrom(
    s: SOCKET,
    lpBuffers: [*]const WSABUF,
    dwBufferCount: DWORD,
    lpNumberOfBytesRecvd: ?*DWORD,
    lpFlags: *DWORD,
    lpFrom: ?*sockaddr,
    lpFromlen: c_int,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) c_int;
pub extern "ws2_32" stdcallcc fn WSASend(
    s: SOCKET,
    lpBuffers: [*]WSABUF,
    dwBufferCount: DWORD,
    lpNumberOfBytesSent: ?*DWORD,
    dwFlags: DWORD,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) c_int;
pub extern "ws2_32" stdcallcc fn WSASendTo(
    s: SOCKET,
    lpBuffers: [*]WSABUF,
    dwBufferCount: DWORD,
    lpNumberOfBytesSent: ?*DWORD,
    dwFlags: DWORD,
    lpTo: ?*const sockaddr,
    iTolen: c_int,
    lpOverlapped: ?*WSAOVERLAPPED,
    lpCompletionRoutine: ?WSAOVERLAPPED_COMPLETION_ROUTINE,
) c_int;
