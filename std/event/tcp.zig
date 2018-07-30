const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const event = std.event;
const mem = std.mem;
const posix = std.os.posix;
const windows = std.os.windows;
const Loop = std.event.Loop;

pub const Server = struct {
    handleRequestFn: async<*mem.Allocator> fn (*Server, *const std.net.Address, *const std.os.File) void,

    loop: *Loop,
    sockfd: ?i32,
    accept_coro: ?promise,
    listen_address: std.net.Address,

    waiting_for_emfile_node: PromiseNode,
    listen_resume_node: event.Loop.ResumeNode,

    const PromiseNode = std.LinkedList(promise).Node;

    pub fn init(loop: *Loop) Server {
        // TODO can't initialize handler coroutine here because we need well defined copy elision
        return Server{
            .loop = loop,
            .sockfd = null,
            .accept_coro = null,
            .handleRequestFn = undefined,
            .waiting_for_emfile_node = undefined,
            .listen_address = undefined,
            .listen_resume_node = event.Loop.ResumeNode{
                .id = event.Loop.ResumeNode.Id.Basic,
                .handle = undefined,
            },
        };
    }

    pub fn listen(
        self: *Server,
        address: *const std.net.Address,
        handleRequestFn: async<*mem.Allocator> fn (*Server, *const std.net.Address, *const std.os.File) void,
    ) !void {
        self.handleRequestFn = handleRequestFn;

        const sockfd = try std.os.posixSocket(posix.AF_INET, posix.SOCK_STREAM | posix.SOCK_CLOEXEC | posix.SOCK_NONBLOCK, posix.PROTO_tcp);
        errdefer std.os.close(sockfd);
        self.sockfd = sockfd;

        try std.os.posixBind(sockfd, &address.os_addr);
        try std.os.posixListen(sockfd, posix.SOMAXCONN);
        self.listen_address = std.net.Address.initPosix(try std.os.posixGetSockName(sockfd));

        self.accept_coro = try async<self.loop.allocator> Server.handler(self);
        errdefer cancel self.accept_coro.?;

        self.listen_resume_node.handle = self.accept_coro.?;
        try self.loop.linuxAddFd(sockfd, &self.listen_resume_node, posix.EPOLLIN | posix.EPOLLOUT | posix.EPOLLET);
        errdefer self.loop.removeFd(sockfd);
    }

    /// Stop listening
    pub fn close(self: *Server) void {
        self.loop.removeFd(self.sockfd.?);
        std.os.close(self.sockfd.?);
    }

    pub fn deinit(self: *Server) void {
        if (self.accept_coro) |accept_coro| cancel accept_coro;
        if (self.sockfd) |sockfd| std.os.close(sockfd);
    }

    pub async fn handler(self: *Server) void {
        while (true) {
            var accepted_addr: std.net.Address = undefined;
            if (std.os.posixAccept(self.sockfd.?, &accepted_addr.os_addr, posix.SOCK_NONBLOCK | posix.SOCK_CLOEXEC)) |accepted_fd| {
                var socket = std.os.File.openHandle(accepted_fd);
                _ = async<self.loop.allocator> self.handleRequestFn(self, accepted_addr, socket) catch |err| switch (err) {
                    error.OutOfMemory => {
                        socket.close();
                        continue;
                    },
                };
            } else |err| switch (err) {
                error.WouldBlock => {
                    suspend; // we will get resumed by epoll_wait in the event loop
                    continue;
                },
                error.ProcessFdQuotaExceeded => {
                    errdefer std.os.emfile_promise_queue.remove(&self.waiting_for_emfile_node);
                    suspend |p| {
                        self.waiting_for_emfile_node = PromiseNode.init(p);
                        std.os.emfile_promise_queue.append(&self.waiting_for_emfile_node);
                    }
                    continue;
                },
                error.ConnectionAborted, error.FileDescriptorClosed => continue,

                error.PageFault => unreachable,
                error.InvalidSyscall => unreachable,
                error.FileDescriptorNotASocket => unreachable,
                error.OperationNotSupported => unreachable,

                error.SystemFdQuotaExceeded, error.SystemResources, error.ProtocolFailure, error.BlockedByFirewall, error.Unexpected => {
                    @panic("TODO handle this error");
                },
            }
        }
    }
};

pub async fn connect(loop: *Loop, _address: *const std.net.Address) !std.os.File {
    var address = _address.*; // TODO https://github.com/ziglang/zig/issues/733

    const sockfd = try std.os.posixSocket(posix.AF_INET, posix.SOCK_STREAM | posix.SOCK_CLOEXEC | posix.SOCK_NONBLOCK, posix.PROTO_tcp);
    errdefer std.os.close(sockfd);

    try std.os.posixConnectAsync(sockfd, &address.os_addr);
    try await try async loop.linuxWaitFd(sockfd, posix.EPOLLIN | posix.EPOLLOUT);
    try std.os.posixGetSockOptConnectError(sockfd);

    return std.os.File.openHandle(sockfd);
}

test "listen on a port, send bytes, receive bytes" {
    if (builtin.os != builtin.Os.linux) {
        // TODO build abstractions for other operating systems
        return error.SkipZigTest;
    }

    const MyServer = struct {
        tcp_server: Server,

        const Self = this;
        async<*mem.Allocator> fn handler(tcp_server: *Server, _addr: *const std.net.Address, _socket: *const std.os.File) void {
            const self = @fieldParentPtr(Self, "tcp_server", tcp_server);
            var socket = _socket.*; // TODO https://github.com/ziglang/zig/issues/733
            defer socket.close();
            // TODO guarantee elision of this allocation
            const next_handler = async errorableHandler(self, _addr, socket) catch unreachable;
            (await next_handler) catch |err| {
                std.debug.panic("unable to handle connection: {}\n", err);
            };
            suspend |p| {
                cancel p;
            }
        }
        async fn errorableHandler(self: *Self, _addr: *const std.net.Address, _socket: *const std.os.File) !void {
            const addr = _addr.*; // TODO https://github.com/ziglang/zig/issues/733
            var socket = _socket.*; // TODO https://github.com/ziglang/zig/issues/733

            var adapter = std.io.FileOutStream.init(&socket);
            var stream = &adapter.stream;
            try stream.print("hello from server\n");
        }
    };

    const ip4addr = std.net.parseIp4("127.0.0.1") catch unreachable;
    const addr = std.net.Address.initIp4(ip4addr, 0);

    var loop: Loop = undefined;
    try loop.initSingleThreaded(std.debug.global_allocator);
    var server = MyServer{ .tcp_server = Server.init(&loop) };
    defer server.tcp_server.deinit();
    try server.tcp_server.listen(addr, MyServer.handler);

    const p = try async<std.debug.global_allocator> doAsyncTest(&loop, server.tcp_server.listen_address, &server.tcp_server);
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
