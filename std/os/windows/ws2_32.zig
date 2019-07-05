usingnamespace @import("bits.zig");

// TODO use GetNameInfoW?
pub extern "ws2_32" stdcallcc fn getnameinfo(
    pSockaddr: *const sockaddr,
    SockaddrLength: socklen_t,
    pNodeBuffer: [*]u8,
    NodeBufferSize: DWORD,
    pServiceBuffer: [*]u8,
    ServiceBufferSize: DWORD,
    Flags: c_int,
) c_int;

// TODO use GetAddrInfoW?
// TODO(emekoi): https://github.com/ziglang/zig/pull/2822/files#r300552261
pub extern "ws2_32" stdcallcc fn getaddrinfo(
    pNodeName: ?[*]const u8,
    pServiceName: [*]const u8,
    pHints: *const addrinfo,
    ppResult: **addrinfo,
) c_int;

pub extern "ws2_32" stdcallcc fn freeaddrinfo(pAddrInfo: *addrinfo) void;

// TODO use these?
// pub extern "ws2_32" stdcallcc fn WSAAsyncGetProtoByName(hWnd: HWND, wMsg: u_int, name: ?[*]const u8, buf: ?[*]u8, buflen: c_int) HANDLE;
// pub extern "ws2_32" stdcallcc fn WSAAsyncGetProtoByNumber(hWnd: HWND, wMsg: u_int, number: c_int, buf: ?[*]u8, buflen: c_int) HANDLE;
// pub extern "ws2_32" stdcallcc fn WSAAsyncGetServByName(hWnd: HWND, wMsg: u_int, name: ?[*]const u8, proto: ?[*]const u8, buf: ?[*]u8, buflen: c_int) HANDLE;
// pub extern "ws2_32" stdcallcc fn WSAAsyncGetServByPort(hWnd: HWND, wMsg: u_int, port: c_int, proto: ?[*]const u8, buf: ?[*]u8, buflen: c_int) HANDLE;
// pub extern "ws2_32" stdcallcc fn WSACancelAsyncRequest(hAsyncTaskHandle: HANDLE) c_int;

pub extern "ws2_32" stdcallcc fn WSACleanup() c_int;

pub extern "ws2_32" stdcallcc fn WSAGetLastError() c_int;

pub extern "ws2_32" stdcallcc fn WSAStartup(wVersionRequired: WORD, lpWSAData: *WSAData) c_int;

pub extern "ws2_32" stdcallcc fn getsockname(s: SOCKET, name: ?*sockaddr, namelen: ?*socklen_t) c_int;

pub extern "ws2_32" stdcallcc fn getpeername(s: SOCKET, name: ?*sockaddr, namelen: ?*socklen_t) c_int;

pub extern "ws2_32" stdcallcc fn socket(af: c_int, @"type": c_int, protocol: c_int) SOCKET;

pub extern "ws2_32" stdcallcc fn setsockopt(s: SOCKET, level: c_int, optname: c_int, optval: ?[*]const u8, optlen: c_int) c_int;

pub extern "ws2_32" stdcallcc fn getsockopt(s: SOCKET, level: c_int, optname: c_int, optval: ?[*]u8, optlen: ?*c_int) c_int;

pub extern "ws2_32" stdcallcc fn connect(s: SOCKET, name: ?*const sockaddr, namelen: socklen_t) c_int;

pub extern "ws2_32" stdcallcc fn recvfrom(s: SOCKET, buf: ?[*]u8, len: c_int, flags: c_int, from: ?*sockaddr, fromlen: ?*c_int) c_int;

pub extern "ws2_32" stdcallcc fn shutdown(s: SOCKET, how: c_int) c_int;

pub extern "ws2_32" stdcallcc fn bind(s: SOCKET, addr: *const sockaddr, namelen: socklen_t) c_int;

pub extern "ws2_32" stdcallcc fn listen(s: SOCKET, backlog: c_int) c_int;

pub extern "ws2_32" stdcallcc fn sendto(s: SOCKET, buf: ?[*]const u8, len: c_int, flags: c_int, to: ?*const sockaddr, tolen: c_int) c_int;

pub extern "ws2_32" stdcallcc fn accept(s: SOCKET, addr: ?*sockaddr, addrlen: ?*socklen_t) SOCKET;

pub extern "ws2_32" stdcallcc fn closesocket(s: SOCKET) c_int;

pub extern "ws2_32" stdcallcc fn ioctlsocket(s: SOCKET, cmd: c_ulong, argp: ?*c_ulong) c_int;

pub extern "ws2_32" stdcallcc fn send(s: SOCKET, buf: ?[*]const u8, len: c_int, flags: c_int) c_int;

pub extern "ws2_32" stdcallcc fn recv(s: SOCKET, buf: ?[*]u8, len: c_int, flags: c_int) c_int;

// TODO delete these?
// pub extern "ws2_32" stdcallcc fn getprotobyname(name: ?[*]const u8) ?*struct_protoent;
// pub extern "ws2_32" stdcallcc fn getprotobynumber(proto: c_int) ?*struct_protoent;
// pub extern "ws2_32" stdcallcc fn getservbyname(name: ?[*]const u8, proto: ?[*]const u8) ?*struct_servent;
// pub extern "ws2_32" stdcallcc fn getservbyport(port: c_int, proto: ?[*]const u8) ?*struct_servent;
// pub extern "ws2_32" stdcallcc fn inet_ntop(Family: c_int, pAddr: *const c_void, pStringBuf: [*]u8, StringBufSize: c_ulong) ?[*]u8;
// pub extern "ws2_32" stdcallcc fn select(nfds: c_int, readfds: ?*fd_set, writefds: ?*fd_set, exceptfds: ?*fd_set, timeout: ?*const struct_timeval) c_int;

// pub extern "ws2_32" stdcallcc fn WSASocketW(
//     af: c_int,
//     @"type": c_int,
//     protocol: c_int,
//     lpProtocolInfo: ?*c_void,
//     g: c_uint,
//     dwFlags: DWORD,
// ) SOCKET;

pub extern "ws2_32" stdcallcc fn WSASendMsg(s: SOCKET, lpMsg: *WSAMSG, dwFlags: DWORD, lpNumberOfBytesSent: *DWORD, lpOverlapped: ?*OVERLAPPED, lpCompletionRoutine: ?OVERLAPPED_COMPLETION_ROUTINE) c_int;

pub extern "ws2_32" stdcallcc fn WSARecvMsg(
    s: SOCKET,
    lpMsg: *WSAMSG,
    lpdwNumberOfBytesRecvd: *DWORD,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?OVERLAPPED_COMPLETION_ROUTINE,
) c_int;

pub extern "ws2_32" stdcallcc fn WSARecvFrom(s: SOCKET, lpBuffers: [*]WSABuf, dwBufferCount: DWORD, lpNumberOfBytesSent: *DWORD, lpFlags: *DWORD, lpFrom: *sockaddr, lpFromlen: *c_int, lpOverlapped: ?*OVERLAPPED, lpCompletionRoutine: ?OVERLAPPED_COMPLETION_ROUTINE) c_int;

pub extern "ws2_32" stdcallcc fn WSASendTo(s: SOCKET, lpBuffers: [*]WSABuf, dwBufferCount: DWORD, lpNumberOfBytesSent: *DWORD, dwFlags: DWORD, lpTo: *const sockaddr, iTolen: c_int, lpOverlapped: *OVERLAPPED, lpCompletionRoutine: ?OVERLAPPED_COMPLETION_ROUTINE) c_int;

pub extern "ws2_32" stdcallcc fn WSASend(s: SOCKET, lpBuffers: [*]WSABufConst, dwBufferCount: DWORD, lpNumberOfBytesSent: *DWORD, dwFlags: DWORD, lpOverlapped: ?*OVERLAPPED, lpCompletionRoutine: ?OVERLAPPED_COMPLETION_ROUTINE) c_int;

pub extern "ws2_32" stdcallcc fn WSARecv(s: SOCKET, lpBuffers: [*]WSABuf, dwBufferCount: DWORD, lpNumberOfBytesRecvd: *DWORD, lpFlags: *DWORD, lpOverlapped: ?*OVERLAPPED, lpCompletionRoutine: ?OVERLAPPED_COMPLETION_ROUTINE) c_int;
