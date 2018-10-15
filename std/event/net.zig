const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const event = std.event;
const mem = std.mem;
const os = std.os;
const posix = os.posix;
const Loop = std.event.Loop;

pub const Server = struct.{
    handleRequestFn: async<*mem.Allocator> fn (*Server, *const std.net.Address, os.File) void,

    loop: *Loop,
    sockfd: ?i32,
    accept_coro: ?promise,
    listen_address: std.net.Address,

    waiting_for_emfile_node: PromiseNode,
    listen_resume_node: event.Loop.ResumeNode,

    const PromiseNode = std.LinkedList(promise).Node;

    pub fn init(loop: *Loop) Server {
        // TODO can't initialize handler coroutine here because we need well defined copy elision
        return Server.{
            .loop = loop,
            .sockfd = null,
            .accept_coro = null,
            .handleRequestFn = undefined,
            .waiting_for_emfile_node = undefined,
            .listen_address = undefined,
            .listen_resume_node = event.Loop.ResumeNode.{
                .id = event.Loop.ResumeNode.Id.Basic,
                .handle = undefined,
                .overlapped = event.Loop.ResumeNode.overlapped_init,
            },
        };
    }

    pub fn listen(
        self: *Server,
        address: *const std.net.Address,
        handleRequestFn: async<*mem.Allocator> fn (*Server, *const std.net.Address, os.File) void,
    ) !void {
        self.handleRequestFn = handleRequestFn;

        const sockfd = try os.posixSocket(posix.AF_INET, posix.SOCK_STREAM | posix.SOCK_CLOEXEC | posix.SOCK_NONBLOCK, posix.PROTO_tcp);
        errdefer os.close(sockfd);
        self.sockfd = sockfd;

        try os.posixBind(sockfd, &address.os_addr);
        try os.posixListen(sockfd, posix.SOMAXCONN);
        self.listen_address = std.net.Address.initPosix(try os.posixGetSockName(sockfd));

        self.accept_coro = try async<self.loop.allocator> Server.handler(self);
        errdefer cancel self.accept_coro.?;

        self.listen_resume_node.handle = self.accept_coro.?;
        try self.loop.linuxAddFd(sockfd, &self.listen_resume_node, posix.EPOLLIN | posix.EPOLLOUT | posix.EPOLLET);
        errdefer self.loop.removeFd(sockfd);
    }

    /// Stop listening
    pub fn close(self: *Server) void {
        self.loop.linuxRemoveFd(self.sockfd.?);
        os.close(self.sockfd.?);
    }

    pub fn deinit(self: *Server) void {
        if (self.accept_coro) |accept_coro| cancel accept_coro;
        if (self.sockfd) |sockfd| os.close(sockfd);
    }

    pub async fn handler(self: *Server) void {
        while (true) {
            var accepted_addr: std.net.Address = undefined;
            // TODO just inline the following function here and don't expose it as posixAsyncAccept
            if (os.posixAsyncAccept(self.sockfd.?, &accepted_addr.os_addr, posix.SOCK_NONBLOCK | posix.SOCK_CLOEXEC)) |accepted_fd| {
                if (accepted_fd == -1) {
                    // would block
                    suspend; // we will get resumed by epoll_wait in the event loop
                    continue;
                }
                var socket = os.File.openHandle(accepted_fd);
                _ = async<self.loop.allocator> self.handleRequestFn(self, &accepted_addr, socket) catch |err| switch (err) {
                    error.OutOfMemory => {
                        socket.close();
                        continue;
                    },
                };
            } else |err| switch (err) {
                error.ProcessFdQuotaExceeded => {
                    errdefer os.emfile_promise_queue.remove(&self.waiting_for_emfile_node);
                    suspend {
                        self.waiting_for_emfile_node = PromiseNode.init(@handle());
                        os.emfile_promise_queue.append(&self.waiting_for_emfile_node);
                    }
                    continue;
                },
                error.ConnectionAborted => continue,

                error.FileDescriptorNotASocket => unreachable,
                error.OperationNotSupported => unreachable,

                error.SystemFdQuotaExceeded, error.SystemResources, error.ProtocolFailure, error.BlockedByFirewall, error.Unexpected => {
                    @panic("TODO handle this error");
                },
            }
        }
    }
};

pub async fn connectUnixSocket(loop: *Loop, path: []const u8) !i32 {
    const sockfd = try os.posixSocket(
        posix.AF_UNIX,
        posix.SOCK_STREAM | posix.SOCK_CLOEXEC | posix.SOCK_NONBLOCK,
        0,
    );
    errdefer os.close(sockfd);

    var sock_addr = posix.sockaddr_un.{
        .family = posix.AF_UNIX,
        .path = undefined,
    };

    if (path.len > @typeOf(sock_addr.path).len) return error.NameTooLong;
    mem.copy(u8, sock_addr.path[0..], path);
    const size = @intCast(u32, @sizeOf(posix.sa_family_t) + path.len);
    try os.posixConnectAsync(sockfd, &sock_addr, size);
    try await try async loop.linuxWaitFd(sockfd, posix.EPOLLIN | posix.EPOLLOUT | posix.EPOLLET);
    try os.posixGetSockOptConnectError(sockfd);

    return sockfd;
}

pub const ReadError = error.{
    SystemResources,
    Unexpected,
    UserResourceLimitReached,
    InputOutput,

    FileDescriptorNotRegistered, // TODO remove this possibility
    OperationCausesCircularLoop, // TODO remove this possibility
    FileDescriptorAlreadyPresentInSet, // TODO remove this possibility
    FileDescriptorIncompatibleWithEpoll, // TODO remove this possibility
};

/// returns number of bytes read. 0 means EOF.
pub async fn read(loop: *std.event.Loop, fd: os.FileHandle, buffer: []u8) ReadError!usize {
    const iov = posix.iovec.{
        .iov_base = buffer.ptr,
        .iov_len = buffer.len,
    };
    const iovs: *const [1]posix.iovec = &iov;
    return await (async readvPosix(loop, fd, iovs, 1) catch unreachable);
}

pub const WriteError = error.{};

pub async fn write(loop: *std.event.Loop, fd: os.FileHandle, buffer: []const u8) WriteError!void {
    const iov = posix.iovec_const.{
        .iov_base = buffer.ptr,
        .iov_len = buffer.len,
    };
    const iovs: *const [1]posix.iovec_const = &iov;
    return await (async writevPosix(loop, fd, iovs, 1) catch unreachable);
}

pub async fn writevPosix(loop: *Loop, fd: i32, iov: [*]const posix.iovec_const, count: usize) !void {
    while (true) {
        switch (builtin.os) {
            builtin.Os.macosx, builtin.Os.linux => {
                const rc = posix.writev(fd, iov, count);
                const err = posix.getErrno(rc);
                switch (err) {
                    0 => return,
                    posix.EINTR => continue,
                    posix.ESPIPE => unreachable,
                    posix.EINVAL => unreachable,
                    posix.EFAULT => unreachable,
                    posix.EAGAIN => {
                        try await (async loop.linuxWaitFd(fd, posix.EPOLLET | posix.EPOLLOUT) catch unreachable);
                        continue;
                    },
                    posix.EBADF => unreachable, // always a race condition
                    posix.EDESTADDRREQ => unreachable, // connect was never called
                    posix.EDQUOT => unreachable,
                    posix.EFBIG => unreachable,
                    posix.EIO => return error.InputOutput,
                    posix.ENOSPC => unreachable,
                    posix.EPERM => return error.AccessDenied,
                    posix.EPIPE => unreachable,
                    else => return os.unexpectedErrorPosix(err),
                }
            },
            else => @compileError("Unsupported OS"),
        }
    }
}

/// returns number of bytes read. 0 means EOF.
pub async fn readvPosix(loop: *std.event.Loop, fd: i32, iov: [*]posix.iovec, count: usize) !usize {
    while (true) {
        switch (builtin.os) {
            builtin.Os.linux, builtin.Os.freebsd, builtin.Os.macosx => {
                const rc = posix.readv(fd, iov, count);
                const err = posix.getErrno(rc);
                switch (err) {
                    0 => return rc,
                    posix.EINTR => continue,
                    posix.EINVAL => unreachable,
                    posix.EFAULT => unreachable,
                    posix.EAGAIN => {
                        try await (async loop.linuxWaitFd(fd, posix.EPOLLET | posix.EPOLLIN) catch unreachable);
                        continue;
                    },
                    posix.EBADF => unreachable, // always a race condition
                    posix.EIO => return error.InputOutput,
                    posix.EISDIR => unreachable,
                    posix.ENOBUFS => return error.SystemResources,
                    posix.ENOMEM => return error.SystemResources,
                    else => return os.unexpectedErrorPosix(err),
                }
            },
            else => @compileError("Unsupported OS"),
        }
    }
}

pub async fn writev(loop: *Loop, fd: os.FileHandle, data: []const []const u8) !void {
    const iovecs = try loop.allocator.alloc(os.posix.iovec_const, data.len);
    defer loop.allocator.free(iovecs);

    for (data) |buf, i| {
        iovecs[i] = os.posix.iovec_const.{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        };
    }

    return await (async writevPosix(loop, fd, iovecs.ptr, data.len) catch unreachable);
}

pub async fn readv(loop: *Loop, fd: os.FileHandle, data: []const []u8) !usize {
    const iovecs = try loop.allocator.alloc(os.posix.iovec, data.len);
    defer loop.allocator.free(iovecs);

    for (data) |buf, i| {
        iovecs[i] = os.posix.iovec.{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        };
    }

    return await (async readvPosix(loop, fd, iovecs.ptr, data.len) catch unreachable);
}

pub async fn connect(loop: *Loop, _address: *const std.net.Address) !os.File {
    var address = _address.*; // TODO https://github.com/ziglang/zig/issues/1592

    const sockfd = try os.posixSocket(posix.AF_INET, posix.SOCK_STREAM | posix.SOCK_CLOEXEC | posix.SOCK_NONBLOCK, posix.PROTO_tcp);
    errdefer os.close(sockfd);

    try os.posixConnectAsync(sockfd, &address.os_addr, @sizeOf(posix.sockaddr_in));
    try await try async loop.linuxWaitFd(sockfd, posix.EPOLLIN | posix.EPOLLOUT | posix.EPOLLET);
    try os.posixGetSockOptConnectError(sockfd);

    return os.File.openHandle(sockfd);
}

test "listen on a port, send bytes, receive bytes" {
    if (builtin.os != builtin.Os.linux) {
        // TODO build abstractions for other operating systems
        return error.SkipZigTest;
    }

    const MyServer = struct.{
        tcp_server: Server,

        const Self = @This();
        async<*mem.Allocator> fn handler(tcp_server: *Server, _addr: *const std.net.Address, _socket: os.File) void {
            const self = @fieldParentPtr(Self, "tcp_server", tcp_server);
            var socket = _socket; // TODO https://github.com/ziglang/zig/issues/1592
            defer socket.close();
            // TODO guarantee elision of this allocation
            const next_handler = async errorableHandler(self, _addr, socket) catch unreachable;
            (await next_handler) catch |err| {
                std.debug.panic("unable to handle connection: {}\n", err);
            };
            suspend {
                cancel @handle();
            }
        }
        async fn errorableHandler(self: *Self, _addr: *const std.net.Address, _socket: os.File) !void {
            const addr = _addr.*; // TODO https://github.com/ziglang/zig/issues/1592
            var socket = _socket; // TODO https://github.com/ziglang/zig/issues/1592

            const stream = &socket.outStream().stream;
            try stream.print("hello from server\n");
        }
    };

    const ip4addr = std.net.parseIp4("127.0.0.1") catch unreachable;
    const addr = std.net.Address.initIp4(ip4addr, 0);

    var loop: Loop = undefined;
    try loop.initSingleThreaded(std.debug.global_allocator);
    var server = MyServer.{ .tcp_server = Server.init(&loop) };
    defer server.tcp_server.deinit();
    try server.tcp_server.listen(&addr, MyServer.handler);

    const p = try async<std.debug.global_allocator> doAsyncTest(&loop, &server.tcp_server.listen_address, &server.tcp_server);
    defer cancel p;
    loop.run();
}

async fn doAsyncTest(loop: *Loop, address: *const std.net.Address, server: *Server) void {
    errdefer @panic("test failure");

    var socket_file = try await try async connect(loop, address);
    defer socket_file.close();

    var buf: [512]u8 = undefined;
    const amt_read = try socket_file.read(buf[0..]);
    const msg = buf[0..amt_read];
    assert(mem.eql(u8, msg, "hello from server\n"));
    server.close();
}

pub const OutStream = struct.{
    fd: os.FileHandle,
    stream: Stream,
    loop: *Loop,

    pub const Error = WriteError;
    pub const Stream = event.io.OutStream(Error);

    pub fn init(loop: *Loop, fd: os.FileHandle) OutStream {
        return OutStream.{
            .fd = fd,
            .loop = loop,
            .stream = Stream.{ .writeFn = writeFn },
        };
    }

    async<*mem.Allocator> fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {
        const self = @fieldParentPtr(OutStream, "stream", out_stream);
        return await (async write(self.loop, self.fd, bytes) catch unreachable);
    }
};

pub const InStream = struct.{
    fd: os.FileHandle,
    stream: Stream,
    loop: *Loop,

    pub const Error = ReadError;
    pub const Stream = event.io.InStream(Error);

    pub fn init(loop: *Loop, fd: os.FileHandle) InStream {
        return InStream.{
            .fd = fd,
            .loop = loop,
            .stream = Stream.{ .readFn = readFn },
        };
    }

    async<*mem.Allocator> fn readFn(in_stream: *Stream, bytes: []u8) Error!usize {
        const self = @fieldParentPtr(InStream, "stream", in_stream);
        return await (async read(self.loop, self.fd, bytes) catch unreachable);
    }
};
