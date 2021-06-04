// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");

const os = std.os;
const mem = std.mem;
const time = std.time;

pub fn Mixin(comptime Socket: type) type {
    return struct {
        /// Open a new socket.
        pub fn init(domain: u32, socket_type: u32, protocol: u32, flags: std.enums.EnumFieldStruct(Socket.InitFlags, bool, false)) !Socket {
            var raw_flags: u32 = socket_type;
            const set = std.EnumSet(Socket.InitFlags).init(flags);
            if (set.contains(.close_on_exec)) raw_flags |= os.SOCK_CLOEXEC;
            if (set.contains(.nonblocking)) raw_flags |= os.SOCK_NONBLOCK;
            return Socket{ .fd = try os.socket(domain, raw_flags, protocol) };
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
        pub fn bind(self: Socket, address: Socket.Address) !void {
            return os.bind(self.fd, @ptrCast(*const os.sockaddr, &address.toNative()), address.getNativeSize());
        }

        /// Start listening for incoming connections on the socket.
        pub fn listen(self: Socket, max_backlog_size: u31) !void {
            return os.listen(self.fd, max_backlog_size);
        }

        /// Have the socket attempt to the connect to an address.
        pub fn connect(self: Socket, address: Socket.Address) !void {
            return os.connect(self.fd, @ptrCast(*const os.sockaddr, &address.toNative()), address.getNativeSize());
        }

        /// Accept a pending incoming connection queued to the kernel backlog
        /// of the socket.
        pub fn accept(self: Socket, flags: std.enums.EnumFieldStruct(Socket.InitFlags, bool, false)) !Socket.Connection {
            var address: Socket.Address.Native.Storage = undefined;
            var address_len: u32 = @sizeOf(Socket.Address.Native.Storage);

            var raw_flags: u32 = 0;
            const set = std.EnumSet(Socket.InitFlags).init(flags);
            if (set.contains(.close_on_exec)) raw_flags |= os.SOCK_CLOEXEC;
            if (set.contains(.nonblocking)) raw_flags |= os.SOCK_NONBLOCK;

            const socket = Socket{ .fd = try os.accept(self.fd, @ptrCast(*os.sockaddr, &address), &address_len, raw_flags) };
            const socket_address = Socket.Address.fromNative(@ptrCast(*os.sockaddr, &address));

            return Socket.Connection.from(socket, socket_address);
        }

        /// Read data from the socket into the buffer provided with a set of flags
        /// specified. It returns the number of bytes read into the buffer provided.
        pub fn read(self: Socket, buf: []u8, flags: u32) !usize {
            return os.recv(self.fd, buf, flags);
        }

        /// Write a buffer of data provided to the socket with a set of flags specified.
        /// It returns the number of bytes that are written to the socket.
        pub fn write(self: Socket, buf: []const u8, flags: u32) !usize {
            return os.send(self.fd, buf, flags);
        }

        /// Writes multiple I/O vectors with a prepended message header to the socket
        /// with a set of flags specified. It returns the number of bytes that are
        /// written to the socket.
        pub fn writeMessage(self: Socket, msg: Socket.Message, flags: u32) !usize {
            while (true) {
                const rc = os.system.sendmsg(self.fd, &msg, @intCast(c_int, flags));
                return switch (os.errno(rc)) {
                    0 => return @intCast(usize, rc),
                    os.EACCES => error.AccessDenied,
                    os.EAGAIN => error.WouldBlock,
                    os.EALREADY => error.FastOpenAlreadyInProgress,
                    os.EBADF => unreachable, // always a race condition
                    os.ECONNRESET => error.ConnectionResetByPeer,
                    os.EDESTADDRREQ => unreachable, // The socket is not connection-mode, and no peer address is set.
                    os.EFAULT => unreachable, // An invalid user space address was specified for an argument.
                    os.EINTR => continue,
                    os.EINVAL => unreachable, // Invalid argument passed.
                    os.EISCONN => unreachable, // connection-mode socket was connected already but a recipient was specified
                    os.EMSGSIZE => error.MessageTooBig,
                    os.ENOBUFS => error.SystemResources,
                    os.ENOMEM => error.SystemResources,
                    os.ENOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
                    os.EOPNOTSUPP => unreachable, // Some bit in the flags argument is inappropriate for the socket type.
                    os.EPIPE => error.BrokenPipe,
                    os.EAFNOSUPPORT => error.AddressFamilyNotSupported,
                    os.ELOOP => error.SymLinkLoop,
                    os.ENAMETOOLONG => error.NameTooLong,
                    os.ENOENT => error.FileNotFound,
                    os.ENOTDIR => error.NotDir,
                    os.EHOSTUNREACH => error.NetworkUnreachable,
                    os.ENETUNREACH => error.NetworkUnreachable,
                    os.ENOTCONN => error.SocketNotConnected,
                    os.ENETDOWN => error.NetworkSubsystemFailed,
                    else => |err| os.unexpectedErrno(err),
                };
            }
        }

        /// Read multiple I/O vectors with a prepended message header from the socket
        /// with a set of flags specified. It returns the number of bytes that were
        /// read into the buffer provided.
        pub fn readMessage(self: Socket, msg: *Socket.Message, flags: u32) !usize {
            while (true) {
                const rc = os.system.recvmsg(self.fd, msg, @intCast(c_int, flags));
                return switch (os.errno(rc)) {
                    0 => @intCast(usize, rc),
                    os.EBADF => unreachable, // always a race condition
                    os.EFAULT => unreachable,
                    os.EINVAL => unreachable,
                    os.ENOTCONN => unreachable,
                    os.ENOTSOCK => unreachable,
                    os.EINTR => continue,
                    os.EAGAIN => error.WouldBlock,
                    os.ENOMEM => error.SystemResources,
                    os.ECONNREFUSED => error.ConnectionRefused,
                    os.ECONNRESET => error.ConnectionResetByPeer,
                    else => |err| os.unexpectedErrno(err),
                };
            }
        }

        /// Query the address that the socket is locally bounded to.
        pub fn getLocalAddress(self: Socket) !Socket.Address {
            var address: Socket.Address.Native.Storage = undefined;
            var address_len: u32 = @sizeOf(Socket.Address.Native.Storage);
            try os.getsockname(self.fd, @ptrCast(*os.sockaddr, &address), &address_len);
            return Socket.Address.fromNative(@ptrCast(*os.sockaddr, &address));
        }

        /// Query the address that the socket is connected to.
        pub fn getRemoteAddress(self: Socket) !Socket.Address {
            var address: Socket.Address.Native.Storage = undefined;
            var address_len: u32 = @sizeOf(Socket.Address.Native.Storage);
            try os.getpeername(self.fd, @ptrCast(*os.sockaddr, &address), &address_len);
            return Socket.Address.fromNative(@ptrCast(*os.sockaddr, &address));
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

        /// Set a socket option.
        pub fn setOption(self: Socket, level: u32, code: u32, value: []const u8) !void {
            return os.setsockopt(self.fd, level, code, value);
        }

        /// Have close() or shutdown() syscalls block until all queued messages in the socket have been successfully
        /// sent, or if the timeout specified in seconds has been reached. It returns `error.UnsupportedSocketOption`
        /// if the host does not support the option for a socket to linger around up until a timeout specified in
        /// seconds.
        pub fn setLinger(self: Socket, timeout_seconds: ?u16) !void {
            if (comptime @hasDecl(os, "SO_LINGER")) {
                const settings = Socket.Linger.init(timeout_seconds);
                return self.setOption(os.SOL_SOCKET, os.SO_LINGER, mem.asBytes(&settings));
            }

            return error.UnsupportedSocketOption;
        }

        /// On connection-oriented sockets, have keep-alive messages be sent periodically. The timing in which keep-alive
        /// messages are sent are dependant on operating system settings. It returns `error.UnsupportedSocketOption` if
        /// the host does not support periodically sending keep-alive messages on connection-oriented sockets. 
        pub fn setKeepAlive(self: Socket, enabled: bool) !void {
            if (comptime @hasDecl(os, "SO_KEEPALIVE")) {
                return self.setOption(os.SOL_SOCKET, os.SO_KEEPALIVE, mem.asBytes(&@as(u32, @boolToInt(enabled))));
            }
            return error.UnsupportedSocketOption;
        }

        /// Allow multiple sockets on the same host to listen on the same address. It returns `error.UnsupportedSocketOption` if
        /// the host does not support sockets listening the same address.
        pub fn setReuseAddress(self: Socket, enabled: bool) !void {
            if (comptime @hasDecl(os, "SO_REUSEADDR")) {
                return self.setOption(os.SOL_SOCKET, os.SO_REUSEADDR, mem.asBytes(&@as(u32, @boolToInt(enabled))));
            }
            return error.UnsupportedSocketOption;
        }

        /// Allow multiple sockets on the same host to listen on the same port. It returns `error.UnsupportedSocketOption` if
        /// the host does not supports sockets listening on the same port.
        pub fn setReusePort(self: Socket, enabled: bool) !void {
            if (comptime @hasDecl(os, "SO_REUSEPORT")) {
                return self.setOption(os.SOL_SOCKET, os.SO_REUSEPORT, mem.asBytes(&@as(u32, @boolToInt(enabled))));
            }
            return error.UnsupportedSocketOption;
        }

        /// Set the write buffer size of the socket.
        pub fn setWriteBufferSize(self: Socket, size: u32) !void {
            return self.setOption(os.SOL_SOCKET, os.SO_SNDBUF, mem.asBytes(&size));
        }

        /// Set the read buffer size of the socket.
        pub fn setReadBufferSize(self: Socket, size: u32) !void {
            return self.setOption(os.SOL_SOCKET, os.SO_RCVBUF, mem.asBytes(&size));
        }

        /// WARNING: Timeouts only affect blocking sockets. It is undefined behavior if a timeout is
        /// set on a non-blocking socket.
        /// 
        /// Set a timeout on the socket that is to occur if no messages are successfully written
        /// to its bound destination after a specified number of milliseconds. A subsequent write
        /// to the socket will thereafter return `error.WouldBlock` should the timeout be exceeded.
        pub fn setWriteTimeout(self: Socket, milliseconds: usize) !void {
            const timeout = os.timeval{
                .tv_sec = @intCast(i32, milliseconds / time.ms_per_s),
                .tv_usec = @intCast(i32, (milliseconds % time.ms_per_s) * time.us_per_ms),
            };

            return self.setOption(os.SOL_SOCKET, os.SO_SNDTIMEO, mem.asBytes(&timeout));
        }

        /// WARNING: Timeouts only affect blocking sockets. It is undefined behavior if a timeout is
        /// set on a non-blocking socket.
        /// 
        /// Set a timeout on the socket that is to occur if no messages are successfully read
        /// from its bound destination after a specified number of milliseconds. A subsequent
        /// read from the socket will thereafter return `error.WouldBlock` should the timeout be
        /// exceeded.
        pub fn setReadTimeout(self: Socket, milliseconds: usize) !void {
            const timeout = os.timeval{
                .tv_sec = @intCast(i32, milliseconds / time.ms_per_s),
                .tv_usec = @intCast(i32, (milliseconds % time.ms_per_s) * time.us_per_ms),
            };

            return self.setOption(os.SOL_SOCKET, os.SO_RCVTIMEO, mem.asBytes(&timeout));
        }
    };
}
