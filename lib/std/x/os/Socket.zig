const std = @import("../../std.zig");

const os = std.os;
const mem = std.mem;
const time = std.time;

/// A generic socket abstraction.
const Socket = @This();

/// The underlying handle of a socket.
fd: os.socket_t,

/// Open a new socket.
pub fn init(domain: u32, socket_type: u32, protocol: u32) !Socket {
    return Socket{ .fd = try os.socket(domain, socket_type, protocol) };
}

/// Enclose a socket abstraction over an existing socket file descriptor.
pub fn from(fd: os.socket_t) Socket {
    return Socket{ .fd = fd };
}

/// Closes the socket.
pub fn deinit(self: Socket) void {
    os.closeSocket(self.fd);
}

/// Shutdown either the read side, write side, or all side of the socket.
pub fn shutdown(self: Socket, how: os.ShutdownHow) !void {
    return os.shutdown(self.fd, how);
}

/// Binds the socket to an address.
pub fn bind(self: Socket, comptime Address: type, address: Address) !void {
    return os.bind(self.fd, @ptrCast(*const os.sockaddr, &address), @sizeOf(Address));
}

/// Start listening for incoming connections on the socket.
pub fn listen(self: Socket, max_backlog_size: u31) !void {
    return os.listen(self.fd, max_backlog_size);
}

/// Have the socket attempt to the connect to an address.
pub fn connect(self: Socket, comptime Address: type, address: Address) !void {
    return os.connect(self.fd, @ptrCast(*const os.sockaddr, &address), @sizeOf(Address));
}

/// Accept a pending incoming connection queued to the kernel backlog
/// of the socket.
pub fn accept(self: Socket, comptime Connection: type, comptime Address: type, flags: u32) !Connection {
    var address: Address = undefined;
    var address_len: u32 = @sizeOf(Address);

    const fd = try os.accept(self.fd, @ptrCast(*os.sockaddr, &address), &address_len, flags);

    return Connection.from(.{ .fd = fd }, address);
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
pub fn getLocalAddress(self: Socket, comptime Address: type) !Address {
    var address: Address = undefined;
    var address_len: u32 = @sizeOf(Address);
    try os.getsockname(self.fd, @ptrCast(*os.sockaddr, &address), &address_len);
    return address;
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
