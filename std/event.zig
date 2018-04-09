const std = @import("index.zig");
const assert = std.debug.assert;
const event = this;
const mem = std.mem;
const posix = std.os.posix;

pub const TcpServer = struct {
    handleRequestFn: async<&mem.Allocator> fn (&TcpServer, &const std.net.Address, &const std.os.File) void,

    loop: &Loop,
    sockfd: i32,
    accept_coro: ?promise,
    listen_address: std.net.Address,

    waiting_for_emfile_node: PromiseNode,

    const PromiseNode = std.LinkedList(promise).Node;

    pub fn init(loop: &Loop) !TcpServer {
        const sockfd = try std.os.posixSocket(posix.AF_INET,
            posix.SOCK_STREAM|posix.SOCK_CLOEXEC|posix.SOCK_NONBLOCK,
            posix.PROTO_tcp);
        errdefer std.os.close(sockfd);

        // TODO can't initialize handler coroutine here because we need well defined copy elision
        return TcpServer {
            .loop = loop,
            .sockfd = sockfd,
            .accept_coro = null,
            .handleRequestFn = undefined,
            .waiting_for_emfile_node = undefined,
            .listen_address = undefined,
        };
    }

    pub fn listen(self: &TcpServer, address: &const std.net.Address,
        handleRequestFn: async<&mem.Allocator> fn (&TcpServer, &const std.net.Address, &const std.os.File)void) !void
    {
        self.handleRequestFn = handleRequestFn;

        try std.os.posixBind(self.sockfd, &address.sockaddr);
        try std.os.posixListen(self.sockfd, posix.SOMAXCONN);
        self.listen_address = std.net.Address.initPosix(try std.os.posixGetSockName(self.sockfd));

        self.accept_coro = try async<self.loop.allocator> TcpServer.handler(self);
        errdefer cancel ??self.accept_coro;

        try self.loop.addFd(self.sockfd, ??self.accept_coro);
        errdefer self.loop.removeFd(self.sockfd);

    }

    pub fn deinit(self: &TcpServer) void {
        self.loop.removeFd(self.sockfd);
        if (self.accept_coro) |accept_coro| cancel accept_coro;
        std.os.close(self.sockfd);
    }

    pub async fn handler(self: &TcpServer) void {
        while (true) {
            var accepted_addr: std.net.Address = undefined;
            if (std.os.posixAccept(self.sockfd, &accepted_addr.sockaddr,
                posix.SOCK_NONBLOCK | posix.SOCK_CLOEXEC)) |accepted_fd|
            {
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
                error.ConnectionAborted,
                error.FileDescriptorClosed => continue,

                error.PageFault => unreachable,
                error.InvalidSyscall => unreachable,
                error.FileDescriptorNotASocket => unreachable,
                error.OperationNotSupported => unreachable,

                error.SystemFdQuotaExceeded,
                error.SystemResources,
                error.ProtocolFailure,
                error.BlockedByFirewall,
                error.Unexpected => {
                    @panic("TODO handle this error");
                },
            }
        }
    }
};

pub const Loop = struct {
    allocator: &mem.Allocator,
    epollfd: i32,
    keep_running: bool,

    fn init(allocator: &mem.Allocator) !Loop {
        const epollfd = try std.os.linuxEpollCreate(std.os.linux.EPOLL_CLOEXEC);
        return Loop {
            .keep_running = true,
            .allocator = allocator,
            .epollfd = epollfd,
        };
    }

    pub fn addFd(self: &Loop, fd: i32, prom: promise) !void {
        var ev = std.os.linux.epoll_event {
            .events = std.os.linux.EPOLLIN|std.os.linux.EPOLLET,
            .data = std.os.linux.epoll_data {
                .ptr = @ptrToInt(prom),
            },
        };
        try std.os.linuxEpollCtl(self.epollfd, std.os.linux.EPOLL_CTL_ADD, fd, &ev);
    }

    pub fn removeFd(self: &Loop, fd: i32) void {
        std.os.linuxEpollCtl(self.epollfd, std.os.linux.EPOLL_CTL_DEL, fd, undefined) catch {};
    }

    async fn waitFd(self: &Loop, fd: i32) !void {
        defer self.removeFd(fd);
        suspend |p| {
            try self.addFd(fd, p);
        }
    }

    pub fn stop(self: &Loop) void {
        // TODO make atomic
        self.keep_running = false;
        // TODO activate an fd in the epoll set
    }

    pub fn run(self: &Loop) void {
        while (self.keep_running) {
            var events: [16]std.os.linux.epoll_event = undefined;
            const count = std.os.linuxEpollWait(self.epollfd, events[0..], -1);
            for (events[0..count]) |ev| {
                const p = @intToPtr(promise, ev.data.ptr);
                resume p;
            }
        }
    }
};

test "listen on a port, send bytes, receive bytes" {
    const MyServer = struct {
        tcp_server: TcpServer,

        const Self = this;

        async<&mem.Allocator> fn handler(tcp_server: &TcpServer, _addr: &const std.net.Address,
            _socket: &const std.os.File) void
        {
            const self = @fieldParentPtr(Self, "tcp_server", tcp_server);
            var socket = *_socket; // TODO https://github.com/zig-lang/zig/issues/733
            defer socket.close();
            const next_handler = async errorableHandler(self, _addr, socket) catch |err| switch (err) {
                error.OutOfMemory => @panic("unable to handle connection: out of memory"),
            };
            (await next_handler) catch |err| {
                std.debug.panic("unable to handle connection: {}\n", err);
            };
            suspend |p| { cancel p; }
        }

        async fn errorableHandler(self: &Self, _addr: &const std.net.Address,
            _socket: &const std.os.File) !void
        {
            const addr = *_addr; // TODO https://github.com/zig-lang/zig/issues/733
            var socket = *_socket; // TODO https://github.com/zig-lang/zig/issues/733

            var adapter = std.io.FileOutStream.init(&socket);
            var stream = &adapter.stream;
            try stream.print("hello from server\n");
        }
    };

    const ip4addr = std.net.parseIp4("127.0.0.1") catch unreachable;
    const addr = std.net.Address.initIp4(ip4addr, 0);

    var loop = try Loop.init(std.debug.global_allocator);
    var server = MyServer {
        .tcp_server = try TcpServer.init(&loop),
    };
    defer server.tcp_server.deinit();
    try server.tcp_server.listen(addr, MyServer.handler);

    var stderr_file = try std.io.getStdErr();
    var stderr_stream = &std.io.FileOutStream.init(&stderr_file).stream;
    try stderr_stream.print("\nlistening at ");
    try server.tcp_server.listen_address.format(stderr_stream);
    try stderr_stream.print("\n");

    loop.run();
}
