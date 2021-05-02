// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");

const os = std.os;
const ip = std.x.net.ip;

const fmt = std.fmt;
const mem = std.mem;
const builtin = std.builtin;
const testing = std.testing;

const IPv4 = std.x.os.IPv4;
const IPv6 = std.x.os.IPv6;
const Socket = std.x.os.Socket;

/// A generic TCP socket abstraction.
const tcp = @This();

/// A TCP client-address pair.
pub const Connection = struct {
    client: tcp.Client,
    address: ip.Address,

    /// Enclose a TCP client and address into a client-address pair.
    pub fn from(conn: Socket.Connection) tcp.Connection {
        return .{
            .client = tcp.Client.from(conn.socket),
            .address = ip.Address.from(conn.address),
        };
    }

    /// Unravel a TCP client-address pair into a socket-address pair.
    pub fn into(self: tcp.Connection) Socket.Connection {
        return .{
            .socket = self.client.socket,
            .address = self.address.into(),
        };
    }

    /// Closes the underlying client of the connection.
    pub fn deinit(self: tcp.Connection) void {
        self.client.deinit();
    }
};

/// Possible domains that a TCP client/listener may operate over.
pub const Domain = extern enum(u16) {
    ip = os.AF_INET,
    ipv6 = os.AF_INET6,
};

/// A TCP client.
pub const Client = struct {
    socket: Socket,

    /// Opens a new client.
    pub fn init(domain: tcp.Domain, flags: u32) !Client {
        return Client{
            .socket = try Socket.init(
                @enumToInt(domain),
                os.SOCK_STREAM | flags,
                os.IPPROTO_TCP,
            ),
        };
    }

    /// Enclose a TCP client over an existing socket.
    pub fn from(socket: Socket) Client {
        return Client{ .socket = socket };
    }

    /// Closes the client.
    pub fn deinit(self: Client) void {
        self.socket.deinit();
    }

    /// Shutdown either the read side, write side, or all sides of the client's underlying socket.
    pub fn shutdown(self: Client, how: os.ShutdownHow) !void {
        return self.socket.shutdown(how);
    }

    /// Have the client attempt to the connect to an address.
    pub fn connect(self: Client, address: ip.Address) !void {
        return self.socket.connect(address.into());
    }

    /// Read data from the socket into the buffer provided. It returns the
    /// number of bytes read into the buffer provided.
    pub fn read(self: Client, buf: []u8) !usize {
        return self.socket.read(buf);
    }

    /// Read data from the socket into the buffer provided with a set of flags
    /// specified. It returns the number of bytes read into the buffer provided.
    pub fn recv(self: Client, buf: []u8, flags: u32) !usize {
        return self.socket.recv(buf, flags);
    }

    /// Write a buffer of data provided to the socket. It returns the number
    /// of bytes that are written to the socket.
    pub fn write(self: Client, buf: []const u8) !usize {
        return self.socket.write(buf);
    }

    /// Writes multiple I/O vectors to the socket. It returns the number
    /// of bytes that are written to the socket.
    pub fn writev(self: Client, buffers: []const os.iovec_const) !usize {
        return self.socket.writev(buffers);
    }

    /// Write a buffer of data provided to the socket with a set of flags specified.
    /// It returns the number of bytes that are written to the socket.
    pub fn send(self: Client, buf: []const u8, flags: u32) !usize {
        return self.socket.send(buf, flags);
    }

    /// Writes multiple I/O vectors with a prepended message header to the socket
    /// with a set of flags specified. It returns the number of bytes that are
    /// written to the socket.
    pub fn sendmsg(self: Client, msg: os.msghdr_const, flags: u32) !usize {
        return self.socket.sendmsg(msg, flags);
    }

    /// Query and return the latest cached error on the client's underlying socket.
    pub fn getError(self: Client) !void {
        return self.socket.getError();
    }

    /// Query the read buffer size of the client's underlying socket.
    pub fn getReadBufferSize(self: Client) !u32 {
        return self.socket.getReadBufferSize();
    }

    /// Query the write buffer size of the client's underlying socket.
    pub fn getWriteBufferSize(self: Client) !u32 {
        return self.socket.getWriteBufferSize();
    }

    /// Query the address that the client's socket is locally bounded to.
    pub fn getLocalAddress(self: Client) !ip.Address {
        return ip.Address.from(try self.socket.getLocalAddress());
    }

    /// Disable Nagle's algorithm on a TCP socket. It returns `error.UnsupportedSocketOption` if
    /// the host does not support sockets disabling Nagle's algorithm.
    pub fn setNoDelay(self: Client, enabled: bool) !void {
        if (comptime @hasDecl(os, "TCP_NODELAY")) {
            const bytes = mem.asBytes(&@as(usize, @boolToInt(enabled)));
            return os.setsockopt(self.socket.fd, os.IPPROTO_TCP, os.TCP_NODELAY, bytes);
        }
        return error.UnsupportedSocketOption;
    }

    /// Set the write buffer size of the socket.
    pub fn setWriteBufferSize(self: Client, size: u32) !void {
        return self.socket.setWriteBufferSize(size);
    }

    /// Set the read buffer size of the socket.
    pub fn setReadBufferSize(self: Client, size: u32) !void {
        return self.socket.setReadBufferSize(size);
    }

    /// Set a timeout on the socket that is to occur if no messages are successfully written
    /// to its bound destination after a specified number of milliseconds. A subsequent write
    /// to the socket will thereafter return `error.WouldBlock` should the timeout be exceeded.
    pub fn setWriteTimeout(self: Client, milliseconds: usize) !void {
        return self.socket.setWriteTimeout(milliseconds);
    }

    /// Set a timeout on the socket that is to occur if no messages are successfully read
    /// from its bound destination after a specified number of milliseconds. A subsequent
    /// read from the socket will thereafter return `error.WouldBlock` should the timeout be
    /// exceeded.
    pub fn setReadTimeout(self: Client, milliseconds: usize) !void {
        return self.socket.setReadTimeout(milliseconds);
    }
};

/// A TCP listener.
pub const Listener = struct {
    socket: Socket,

    /// Opens a new listener.
    pub fn init(domain: tcp.Domain, flags: u32) !Listener {
        return Listener{
            .socket = try Socket.init(
                @enumToInt(domain),
                os.SOCK_STREAM | flags,
                os.IPPROTO_TCP,
            ),
        };
    }

    /// Closes the listener.
    pub fn deinit(self: Listener) void {
        self.socket.deinit();
    }

    /// Shuts down the underlying listener's socket. The next subsequent call, or
    /// a current pending call to accept() after shutdown is called will return
    /// an error.
    pub fn shutdown(self: Listener) !void {
        return self.socket.shutdown(.recv);
    }

    /// Binds the listener's socket to an address.
    pub fn bind(self: Listener, address: ip.Address) !void {
        return self.socket.bind(address.into());
    }

    /// Start listening for incoming connections.
    pub fn listen(self: Listener, max_backlog_size: u31) !void {
        return self.socket.listen(max_backlog_size);
    }

    /// Accept a pending incoming connection queued to the kernel backlog
    /// of the listener's socket.
    pub fn accept(self: Listener, flags: u32) !tcp.Connection {
        return tcp.Connection.from(try self.socket.accept(flags));
    }

    /// Query and return the latest cached error on the listener's underlying socket.
    pub fn getError(self: Client) !void {
        return self.socket.getError();
    }

    /// Query the address that the listener's socket is locally bounded to.
    pub fn getLocalAddress(self: Listener) !ip.Address {
        return ip.Address.from(try self.socket.getLocalAddress());
    }

    /// Allow multiple sockets on the same host to listen on the same address. It returns `error.UnsupportedSocketOption` if
    /// the host does not support sockets listening the same address.
    pub fn setReuseAddress(self: Listener, enabled: bool) !void {
        return self.socket.setReuseAddress(enabled);
    }

    /// Allow multiple sockets on the same host to listen on the same port. It returns `error.UnsupportedSocketOption` if
    /// the host does not supports sockets listening on the same port.
    pub fn setReusePort(self: Listener, enabled: bool) !void {
        return self.socket.setReusePort(enabled);
    }

    /// Enables TCP Fast Open (RFC 7413) on a TCP socket. It returns `error.UnsupportedSocketOption` if the host does not
    /// support TCP Fast Open.
    pub fn setFastOpen(self: Listener, enabled: bool) !void {
        if (comptime @hasDecl(os, "TCP_FASTOPEN")) {
            return os.setsockopt(self.socket.fd, os.IPPROTO_TCP, os.TCP_FASTOPEN, mem.asBytes(&@as(usize, @boolToInt(enabled))));
        }
        return error.UnsupportedSocketOption;
    }

    /// Enables TCP Quick ACK on a TCP socket to immediately send rather than delay ACKs when necessary. It returns
    /// `error.UnsupportedSocketOption` if the host does not support TCP Quick ACK.
    pub fn setQuickACK(self: Listener, enabled: bool) !void {
        if (comptime @hasDecl(os, "TCP_QUICKACK")) {
            return os.setsockopt(self.socket.fd, os.IPPROTO_TCP, os.TCP_QUICKACK, mem.asBytes(&@as(usize, @boolToInt(enabled))));
        }
        return error.UnsupportedSocketOption;
    }

    /// Set a timeout on the listener that is to occur if no new incoming connections come in
    /// after a specified number of milliseconds. A subsequent accept call to the listener
    /// will thereafter return `error.WouldBlock` should the timeout be exceeded.
    pub fn setAcceptTimeout(self: Listener, milliseconds: usize) !void {
        return self.socket.setReadTimeout(milliseconds);
    }
};

test "tcp: create client/listener pair" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const listener = try tcp.Listener.init(.ip, os.SOCK_CLOEXEC);
    defer listener.deinit();

    try listener.bind(ip.Address.initIPv4(IPv4.unspecified, 0));
    try listener.listen(128);

    const binded_address = try listener.getLocalAddress();

    const client = try tcp.Client.init(.ip, os.SOCK_CLOEXEC);
    defer client.deinit();

    try client.connect(binded_address);

    const conn = try listener.accept(os.SOCK_CLOEXEC);
    defer conn.deinit();
}

test "tcp/client: set read timeout of 1 millisecond on blocking client" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const listener = try tcp.Listener.init(.ip, os.SOCK_CLOEXEC);
    defer listener.deinit();

    try listener.bind(ip.Address.initIPv4(IPv4.unspecified, 0));
    try listener.listen(128);

    const binded_address = try listener.getLocalAddress();

    const client = try tcp.Client.init(.ip, os.SOCK_CLOEXEC);
    defer client.deinit();

    try client.connect(binded_address);
    try client.setReadTimeout(1);

    const conn = try listener.accept(os.SOCK_CLOEXEC);
    defer conn.deinit();

    var buf: [1]u8 = undefined;
    testing.expectError(error.WouldBlock, client.read(&buf));
}

test "tcp/listener: bind to unspecified ipv4 address" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const listener = try tcp.Listener.init(.ip, os.SOCK_CLOEXEC);
    defer listener.deinit();

    try listener.bind(ip.Address.initIPv4(IPv4.unspecified, 0));
    try listener.listen(128);

    const address = try listener.getLocalAddress();
    testing.expect(address == .ipv4);
}

test "tcp/listener: bind to unspecified ipv6 address" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const listener = try tcp.Listener.init(.ipv6, os.SOCK_CLOEXEC);
    defer listener.deinit();

    try listener.bind(ip.Address.initIPv6(IPv6.unspecified, 0));
    try listener.listen(128);

    const address = try listener.getLocalAddress();
    testing.expect(address == .ipv6);
}
