const std = @import("../std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const event = std.event;
const mem = std.mem;
const os = std.os;
const Loop = std.event.Loop;
const File = std.fs.File;
const fd_t = os.fd_t;

pub const Server = struct {
    handleRequestFn: async fn (*Server, *const std.net.Address, File) void,

    loop: *Loop,
    sockfd: ?i32,
    accept_frame: ?anyframe,
    listen_address: std.net.Address,

    waiting_for_emfile_node: PromiseNode,
    listen_resume_node: event.Loop.ResumeNode,

    const PromiseNode = std.TailQueue(anyframe).Node;

    pub fn init(loop: *Loop) Server {
        // TODO can't initialize handler here because we need well defined copy elision
        return Server{
            .loop = loop,
            .sockfd = null,
            .accept_frame = null,
            .handleRequestFn = undefined,
            .waiting_for_emfile_node = undefined,
            .listen_address = undefined,
            .listen_resume_node = event.Loop.ResumeNode{
                .id = event.Loop.ResumeNode.Id.Basic,
                .handle = undefined,
                .overlapped = event.Loop.ResumeNode.overlapped_init,
            },
        };
    }

    pub fn listen(
        self: *Server,
        address: *const std.net.Address,
        handleRequestFn: async fn (*Server, *const std.net.Address, File) void,
    ) !void {
        self.handleRequestFn = handleRequestFn;

        const sockfd = try os.socket(os.AF_INET, os.SOCK_STREAM | os.SOCK_CLOEXEC | os.SOCK_NONBLOCK, os.PROTO_tcp);
        errdefer os.close(sockfd);
        self.sockfd = sockfd;

        try os.bind(sockfd, &address.os_addr);
        try os.listen(sockfd, os.SOMAXCONN);
        self.listen_address = std.net.Address.initPosix(try os.getsockname(sockfd));

        self.accept_frame = async Server.handler(self);
        errdefer await self.accept_frame.?;

        self.listen_resume_node.handle = self.accept_frame.?;
        try self.loop.linuxAddFd(sockfd, &self.listen_resume_node, os.EPOLLIN | os.EPOLLOUT | os.EPOLLET);
        errdefer self.loop.removeFd(sockfd);
    }

    /// Stop listening
    pub fn close(self: *Server) void {
        self.loop.linuxRemoveFd(self.sockfd.?);
        if (self.sockfd) |fd| {
            os.close(fd);
            self.sockfd = null;
        }
    }

    pub fn deinit(self: *Server) void {
        if (self.accept_frame) |accept_frame| await accept_frame;
        if (self.sockfd) |sockfd| os.close(sockfd);
    }

    pub async fn handler(self: *Server) void {
        while (true) {
            var accepted_addr: std.net.Address = undefined;
            // TODO just inline the following function here and don't expose it as posixAsyncAccept
            if (os.accept4_async(self.sockfd.?, &accepted_addr.os_addr, os.SOCK_NONBLOCK | os.SOCK_CLOEXEC)) |accepted_fd| {
                if (accepted_fd == -1) {
                    // would block
                    suspend; // we will get resumed by epoll_wait in the event loop
                    continue;
                }
                var socket = File.openHandle(accepted_fd);
                self.handleRequestFn(self, &accepted_addr, socket);
            } else |err| switch (err) {
                error.ProcessFdQuotaExceeded => @panic("TODO handle this error"),
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
    const sockfd = try os.socket(
        os.AF_UNIX,
        os.SOCK_STREAM | os.SOCK_CLOEXEC | os.SOCK_NONBLOCK,
        0,
    );
    errdefer os.close(sockfd);

    var sock_addr = os.sockaddr_un{
        .family = os.AF_UNIX,
        .path = undefined,
    };

    if (path.len > @typeOf(sock_addr.path).len) return error.NameTooLong;
    mem.copy(u8, sock_addr.path[0..], path);
    const size = @intCast(u32, @sizeOf(os.sa_family_t) + path.len);
    try os.connect_async(sockfd, &sock_addr, size);
    try loop.linuxWaitFd(sockfd, os.EPOLLIN | os.EPOLLOUT | os.EPOLLET);
    try os.getsockoptError(sockfd);

    return sockfd;
}

pub const ReadError = error{
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
pub async fn read(loop: *std.event.Loop, fd: fd_t, buffer: []u8) ReadError!usize {
    const iov = os.iovec{
        .iov_base = buffer.ptr,
        .iov_len = buffer.len,
    };
    const iovs: *const [1]os.iovec = &iov;
    return readvPosix(loop, fd, iovs, 1);
}

pub const WriteError = error{};

pub async fn write(loop: *std.event.Loop, fd: fd_t, buffer: []const u8) WriteError!void {
    const iov = os.iovec_const{
        .iov_base = buffer.ptr,
        .iov_len = buffer.len,
    };
    const iovs: *const [1]os.iovec_const = &iov;
    return writevPosix(loop, fd, iovs, 1);
}

pub async fn writevPosix(loop: *Loop, fd: i32, iov: [*]const os.iovec_const, count: usize) !void {
    while (true) {
        switch (builtin.os) {
            .macosx, .linux => {
                switch (os.errno(os.system.writev(fd, iov, count))) {
                    0 => return,
                    os.EINTR => continue,
                    os.ESPIPE => unreachable,
                    os.EINVAL => unreachable,
                    os.EFAULT => unreachable,
                    os.EAGAIN => {
                        try loop.linuxWaitFd(fd, os.EPOLLET | os.EPOLLOUT);
                        continue;
                    },
                    os.EBADF => unreachable, // always a race condition
                    os.EDESTADDRREQ => unreachable, // connect was never called
                    os.EDQUOT => unreachable,
                    os.EFBIG => unreachable,
                    os.EIO => return error.InputOutput,
                    os.ENOSPC => unreachable,
                    os.EPERM => return error.AccessDenied,
                    os.EPIPE => unreachable,
                    else => |err| return os.unexpectedErrno(err),
                }
            },
            else => @compileError("Unsupported OS"),
        }
    }
}

/// returns number of bytes read. 0 means EOF.
pub async fn readvPosix(loop: *std.event.Loop, fd: i32, iov: [*]os.iovec, count: usize) !usize {
    while (true) {
        switch (builtin.os) {
            builtin.Os.linux, builtin.Os.freebsd, builtin.Os.macosx => {
                const rc = os.system.readv(fd, iov, count);
                switch (os.errno(rc)) {
                    0 => return rc,
                    os.EINTR => continue,
                    os.EINVAL => unreachable,
                    os.EFAULT => unreachable,
                    os.EAGAIN => {
                        try loop.linuxWaitFd(fd, os.EPOLLET | os.EPOLLIN);
                        continue;
                    },
                    os.EBADF => unreachable, // always a race condition
                    os.EIO => return error.InputOutput,
                    os.EISDIR => unreachable,
                    os.ENOBUFS => return error.SystemResources,
                    os.ENOMEM => return error.SystemResources,
                    else => |err| return os.unexpectedErrno(err),
                }
            },
            else => @compileError("Unsupported OS"),
        }
    }
}

pub async fn writev(loop: *Loop, fd: fd_t, data: []const []const u8) !void {
    const iovecs = try loop.allocator.alloc(os.iovec_const, data.len);
    defer loop.allocator.free(iovecs);

    for (data) |buf, i| {
        iovecs[i] = os.iovec_const{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        };
    }

    return writevPosix(loop, fd, iovecs.ptr, data.len);
}

pub async fn readv(loop: *Loop, fd: fd_t, data: []const []u8) !usize {
    const iovecs = try loop.allocator.alloc(os.iovec, data.len);
    defer loop.allocator.free(iovecs);

    for (data) |buf, i| {
        iovecs[i] = os.iovec{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        };
    }

    return readvPosix(loop, fd, iovecs.ptr, data.len);
}

pub async fn connect(loop: *Loop, _address: *const std.net.Address) !File {
    var address = _address.*; // TODO https://github.com/ziglang/zig/issues/1592

    const sockfd = try os.socket(os.AF_INET, os.SOCK_STREAM | os.SOCK_CLOEXEC | os.SOCK_NONBLOCK, os.PROTO_tcp);
    errdefer os.close(sockfd);

    try os.connect_async(sockfd, &address.os_addr, @sizeOf(os.sockaddr_in));
    try loop.linuxWaitFd(sockfd, os.EPOLLIN | os.EPOLLOUT | os.EPOLLET);
    try os.getsockoptError(sockfd);

    return File.openHandle(sockfd);
}

test "listen on a port, send bytes, receive bytes" {
    // https://github.com/ziglang/zig/issues/2377
    if (true) return error.SkipZigTest;

    if (builtin.os != builtin.Os.linux) {
        // TODO build abstractions for other operating systems
        return error.SkipZigTest;
    }

    const MyServer = struct {
        tcp_server: Server,

        const Self = @This();
        async fn handler(tcp_server: *Server, _addr: *const std.net.Address, _socket: File) void {
            const self = @fieldParentPtr(Self, "tcp_server", tcp_server);
            var socket = _socket; // TODO https://github.com/ziglang/zig/issues/1592
            defer socket.close();
            const next_handler = errorableHandler(self, _addr, socket) catch |err| {
                std.debug.panic("unable to handle connection: {}\n", err);
            };
        }
        async fn errorableHandler(self: *Self, _addr: *const std.net.Address, _socket: File) !void {
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
    var server = MyServer{ .tcp_server = Server.init(&loop) };
    defer server.tcp_server.deinit();
    try server.tcp_server.listen(&addr, MyServer.handler);

    _ = async doAsyncTest(&loop, &server.tcp_server.listen_address, &server.tcp_server);
    loop.run();
}

async fn doAsyncTest(loop: *Loop, address: *const std.net.Address, server: *Server) void {
    errdefer @panic("test failure");

    var socket_file = try connect(loop, address);
    defer socket_file.close();

    var buf: [512]u8 = undefined;
    const amt_read = try socket_file.read(buf[0..]);
    const msg = buf[0..amt_read];
    testing.expect(mem.eql(u8, msg, "hello from server\n"));
    server.close();
}

pub const OutStream = struct {
    fd: fd_t,
    stream: Stream,
    loop: *Loop,

    pub const Error = WriteError;
    pub const Stream = event.io.OutStream(Error);

    pub fn init(loop: *Loop, fd: fd_t) OutStream {
        return OutStream{
            .fd = fd,
            .loop = loop,
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    async fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {
        const self = @fieldParentPtr(OutStream, "stream", out_stream);
        return write(self.loop, self.fd, bytes);
    }
};

pub const InStream = struct {
    fd: fd_t,
    stream: Stream,
    loop: *Loop,

    pub const Error = ReadError;
    pub const Stream = event.io.InStream(Error);

    pub fn init(loop: *Loop, fd: fd_t) InStream {
        return InStream{
            .fd = fd,
            .loop = loop,
            .stream = Stream{ .readFn = readFn },
        };
    }

    async fn readFn(in_stream: *Stream, bytes: []u8) Error!usize {
        const self = @fieldParentPtr(InStream, "stream", in_stream);
        return read(self.loop, self.fd, bytes);
    }
};
