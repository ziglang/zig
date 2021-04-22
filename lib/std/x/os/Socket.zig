const std = @import("../../std.zig");

const os = std.os;
const mem = std.mem;
const net = std.net;
const time = std.time;
const builtin = std.builtin;
const testing = std.testing;

const Socket = @This();

/// A socket-address pair.
pub const Connection = struct {
    socket: Socket,
    address: net.Address,
};

/// The underlying handle of a socket.
fd: os.socket_t,

/// Open a new socket.
pub fn init(domain: u32, socket_type: u32, protocol: u32) !Socket {
    return Socket{ .fd = try os.socket(domain, socket_type, protocol) };
}

/// Closes the socket.
pub fn deinit(self: Socket) void {
    os.closeSocket(self.fd);
}

/// Shutdown either the read side, or write side, or the entirety of a socket.
pub fn shutdown(self: Socket, how: os.ShutdownHow) !void {
    return os.shutdown(self.fd, how);
}

/// Binds the socket to an address.
pub fn bind(self: Socket, address: net.Address) !void {
    return os.bind(self.fd, &address.any, address.getOsSockLen());
}

/// Start listening for incoming connections on the socket.
pub fn listen(self: Socket, max_backlog_size: u31) !void {
    return os.listen(self.fd, max_backlog_size);
}

/// Have the socket attempt to the connect to an address.
pub fn connect(self: Socket, address: net.Address) !void {
    return os.connect(self.fd, &address.any, address.getOsSockLen());
}

/// Accept a pending incoming connection queued to the kernel backlog
/// of the socket.
pub fn accept(self: Socket, flags: u32) !Socket.Connection {
    var address: os.sockaddr = undefined;
    var address_len: u32 = @sizeOf(os.sockaddr);

    const fd = try os.accept(self.fd, &address, &address_len, flags);

    return Connection{
        .socket = Socket{ .fd = fd },
        .address = net.Address.initPosix(@alignCast(4, &address)),
    };
}

/// Read data from the socket into the buffer provided. It returns the
/// number of bytes read into the buffer provided.
pub fn read(self: Socket, buf: []u8) !usize {
    return os.read(self.fd, buf);
}

/// Read data from the socket into the buffer provided with a set of flags
/// specified. It returns the number of bytes read into the buffer provided.
pub fn recv(self: Socket, buf: []u8, flags: u32) !usize {
    return os.recv(self.fd, buf, flags);
}

/// Write a buffer of data provided to the socket. It returns the number
/// of bytes that are written to the socket.
pub fn write(self: Socket, buf: []const u8) !usize {
    return os.write(self.fd, buf);
}

/// Writes multiple I/O vectors to the socket. It returns the number
/// of bytes that are written to the socket.
pub fn writev(self: Socket, buffers: []const os.iovec_const) !usize {
    return os.writev(self.fd, buffers);
}

/// Write a buffer of data provided to the socket with a set of flags specified.
/// It returns the number of bytes that are written to the socket.
pub fn send(self: Socket, buf: []const u8, flags: u32) !usize {
    return os.send(self.fd, buf, flags);
}

/// Writes multiple I/O vectors with a prepended message header to the socket
/// with a set of flags specified. It returns the number of bytes that are
/// written to the socket.
pub fn sendmsg(self: Socket, msg: os.msghdr_const, flags: u32) !usize {
    return os.sendmsg(self.fd, msg, flags);
}

/// Query the address that the socket is locally bounded to.
pub fn getLocalAddress(self: Socket) !net.Address {
    var address: os.sockaddr = undefined;
    var address_len: u32 = @sizeOf(os.sockaddr);
    try os.getsockname(self.fd, &address, &address_len);
    return net.Address.initPosix(@alignCast(4, &address));
}

/// Query and return the latest cached error on the socket.
pub fn getError(self: Socket) !void {
    return os.getsockoptError(self.fd);
}

/// Query the read buffer size of the socket.
pub fn getReadBufferSize(self: Socket) !u32 {
    var value: u32 = undefined;
    var value_len: u32 = @sizeOf(u32);

    const rc = os.system.getsockopt(self.fd, os.SOL_SOCKET, os.SO_RCVBUF, mem.asBytes(&value), &value_len);
    return switch (os.errno(rc)) {
        0 => value,
        os.EBADF => error.BadFileDescriptor,
        os.EFAULT => error.InvalidAddressSpace,
        os.EINVAL => error.InvalidSocketOption,
        os.ENOPROTOOPT => error.UnknownSocketOption,
        os.ENOTSOCK => error.NotASocket,
        else => |err| os.unexpectedErrno(err),
    };
}

/// Query the write buffer size of the socket.
pub fn getWriteBufferSize(self: Socket) !u32 {
    var value: u32 = undefined;
    var value_len: u32 = @sizeOf(u32);

    const rc = os.system.getsockopt(self.fd, os.SOL_SOCKET, os.SO_SNDBUF, mem.asBytes(&value), &value_len);
    return switch (os.errno(rc)) {
        0 => value,
        os.EBADF => error.BadFileDescriptor,
        os.EFAULT => error.InvalidAddressSpace,
        os.EINVAL => error.InvalidSocketOption,
        os.ENOPROTOOPT => error.UnknownSocketOption,
        os.ENOTSOCK => error.NotASocket,
        else => |err| os.unexpectedErrno(err),
    };
}

/// Allow multiple sockets on the same host to listen on the same address. It returns `error.UnsupportedSocketOption` if
/// the host does not support sockets listening the same address.
pub fn setReuseAddress(self: Socket, enabled: bool) !void {
    if (comptime @hasDecl(os, "SO_REUSEADDR")) {
        return os.setsockopt(self.fd, os.SOL_SOCKET, os.SO_REUSEADDR, mem.asBytes(&@as(usize, @boolToInt(enabled))));
    }
    return error.UnsupportedSocketOption;
}

/// Allow multiple sockets on the same host to listen on the same port. It returns `error.UnsupportedSocketOption` if
/// the host does not supports sockets listening on the same port.
pub fn setReusePort(self: Socket, enabled: bool) !void {
    if (comptime @hasDecl(os, "SO_REUSEPORT")) {
        return os.setsockopt(self.fd, os.SOL_SOCKET, os.SO_REUSEPORT, mem.asBytes(&@as(usize, @boolToInt(enabled))));
    }
    return error.UnsupportedSocketOption;
}

/// Disable Nagle's algorithm on a TCP socket. It returns `error.UnsupportedSocketOption` if the host does not support
/// sockets disabling Nagle's algorithm.
pub fn setNoDelay(self: Socket, enabled: bool) !void {
    if (comptime @hasDecl(os, "TCP_NODELAY")) {
        return os.setsockopt(self.fd, os.IPPROTO_TCP, os.TCP_NODELAY, mem.asBytes(&@as(usize, @boolToInt(enabled))));
    }
    return error.UnsupportedSocketOption;
}

/// Enables TCP Fast Open (RFC 7413) on a TCP socket. It returns `error.UnsupportedSocketOption` if the host does not
/// support TCP Fast Open.
pub fn setFastOpen(self: Socket, enabled: bool) !void {
    if (comptime @hasDecl(os, "TCP_FASTOPEN")) {
        return os.setsockopt(self.fd, os.IPPROTO_TCP, os.TCP_FASTOPEN, mem.asBytes(&@as(usize, @boolToInt(enabled))));
    }
    return error.UnsupportedSocketOption;
}

/// Enables TCP Quick ACK on a TCP socket to immediately send rather than delay ACKs when necessary. It returns
/// `error.UnsupportedSocketOption` if the host does not support TCP Quick ACK.
pub fn setQuickACK(self: Socket, enabled: bool) !void {
    if (comptime @hasDecl(os, "TCP_QUICKACK")) {
        return os.setsockopt(self.fd, os.IPPROTO_TCP, os.TCP_QUICKACK, mem.asBytes(&@as(usize, @boolToInt(enabled))));
    }
    return error.UnsupportedSocketOption;
}

/// Set the write buffer size of the socket.
pub fn setWriteBufferSize(self: Socket, size: u32) !void {
    return os.setsockopt(self.fd, os.SOL_SOCKET, os.SO_SNDBUF, mem.asBytes(&size));
}

/// Set the read buffer size of the socket.
pub fn setReadBufferSize(self: Socket, size: u32) !void {
    return os.setsockopt(self.fd, os.SOL_SOCKET, os.SO_RCVBUF, mem.asBytes(&size));
}

/// Set a timeout on the socket that is to occur if no messages are successfully written
/// to its bound destination after a specified number of milliseconds. A subsequent write
/// to the socket will thereafter return `error.WouldBlock` should the timeout be exceeded.
pub fn setWriteTimeout(self: Socket, milliseconds: usize) !void {
    const timeout = os.timeval{
        .tv_sec = @intCast(isize, milliseconds / time.ms_per_s),
        .tv_usec = @intCast(isize, (milliseconds % time.ms_per_s) * time.us_per_ms),
    };

    return os.setsockopt(self.fd, os.SOL_SOCKET, os.SO_SNDTIMEO, mem.asBytes(&timeout));
}

/// Set a timeout on the socket that is to occur if no messages are successfully read
/// from its bound destination after a specified number of milliseconds. A subsequent
/// read from the socket will thereafter return `error.WouldBlock` should the timeout be
/// exceeded.
pub fn setReadTimeout(self: Socket, milliseconds: usize) !void {
    const timeout = os.timeval{
        .tv_sec = @intCast(isize, milliseconds / time.ms_per_s),
        .tv_usec = @intCast(isize, (milliseconds % time.ms_per_s) * time.us_per_ms),
    };

    return os.setsockopt(self.fd, os.SOL_SOCKET, os.SO_RCVTIMEO, mem.asBytes(&timeout));
}

test {
    testing.refAllDecls(@This());
}

test "socket/linux: set read timeout of 1 millisecond on blocking socket" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const a = try Socket.init(os.AF_INET, os.SOCK_STREAM | os.SOCK_CLOEXEC, os.IPPROTO_TCP);
    defer a.deinit();

    try a.bind(net.Address.initIp4([_]u8{ 0, 0, 0, 0 }, 0));
    try a.listen(128);

    const binded_address = try a.getLocalAddress();

    const b = try Socket.init(os.AF_INET, os.SOCK_STREAM | os.SOCK_CLOEXEC, os.IPPROTO_TCP);
    defer b.deinit();

    try b.connect(binded_address);
    try b.setReadTimeout(1);

    const ab = try a.accept(os.SOCK_CLOEXEC);
    defer ab.socket.deinit();

    var buf: [1]u8 = undefined;
    testing.expectError(error.WouldBlock, b.read(&buf));
}

test "socket/linux: create non-blocking socket pair" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const a = try Socket.init(os.AF_INET, os.SOCK_STREAM | os.SOCK_NONBLOCK | os.SOCK_CLOEXEC, os.IPPROTO_TCP);
    defer a.deinit();

    try a.bind(net.Address.initIp4([_]u8{ 0, 0, 0, 0 }, 0));
    try a.listen(128);

    const binded_address = try a.getLocalAddress();

    const b = try Socket.init(os.AF_INET, os.SOCK_STREAM | os.SOCK_NONBLOCK | os.SOCK_CLOEXEC, os.IPPROTO_TCP);
    defer b.deinit();

    testing.expectError(error.WouldBlock, b.connect(binded_address));
    try b.getError();

    const ab = try a.accept(os.SOCK_NONBLOCK | os.SOCK_CLOEXEC);
    defer ab.socket.deinit();
}
