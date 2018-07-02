const std = @import("index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const event = this;
const mem = std.mem;
const posix = std.os.posix;
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

pub const TcpServer = struct {
    handleRequestFn: async<*mem.Allocator> fn (*TcpServer, *const std.net.Address, *const std.os.File) void,

    loop: *Loop,
    sockfd: i32,
    accept_coro: ?promise,
    listen_address: std.net.Address,

    waiting_for_emfile_node: PromiseNode,

    const PromiseNode = std.LinkedList(promise).Node;

    pub fn init(loop: *Loop) !TcpServer {
        const sockfd = try std.os.posixSocket(posix.AF_INET, posix.SOCK_STREAM | posix.SOCK_CLOEXEC | posix.SOCK_NONBLOCK, posix.PROTO_tcp);
        errdefer std.os.close(sockfd);

        // TODO can't initialize handler coroutine here because we need well defined copy elision
        return TcpServer{
            .loop = loop,
            .sockfd = sockfd,
            .accept_coro = null,
            .handleRequestFn = undefined,
            .waiting_for_emfile_node = undefined,
            .listen_address = undefined,
        };
    }

    pub fn listen(self: *TcpServer, address: *const std.net.Address, handleRequestFn: async<*mem.Allocator> fn (*TcpServer, *const std.net.Address, *const std.os.File) void) !void {
        self.handleRequestFn = handleRequestFn;

        try std.os.posixBind(self.sockfd, &address.os_addr);
        try std.os.posixListen(self.sockfd, posix.SOMAXCONN);
        self.listen_address = std.net.Address.initPosix(try std.os.posixGetSockName(self.sockfd));

        self.accept_coro = try async<self.loop.allocator> TcpServer.handler(self);
        errdefer cancel self.accept_coro.?;

        try self.loop.addFd(self.sockfd, self.accept_coro.?);
        errdefer self.loop.removeFd(self.sockfd);
    }

    pub fn deinit(self: *TcpServer) void {
        self.loop.removeFd(self.sockfd);
        if (self.accept_coro) |accept_coro| cancel accept_coro;
        std.os.close(self.sockfd);
    }

    pub async fn handler(self: *TcpServer) void {
        while (true) {
            var accepted_addr: std.net.Address = undefined;
            if (std.os.posixAccept(self.sockfd, &accepted_addr.os_addr, posix.SOCK_NONBLOCK | posix.SOCK_CLOEXEC)) |accepted_fd| {
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

pub const Loop = struct {
    allocator: *mem.Allocator,
    keep_running: bool,
    next_tick_queue: std.atomic.QueueMpsc(promise),
    os_data: OsData,

    const OsData = switch (builtin.os) {
        builtin.Os.linux => struct {
            epollfd: i32,
        },
        else => struct {},
    };

    pub const NextTickNode = std.atomic.QueueMpsc(promise).Node;

    /// The allocator must be thread-safe because we use it for multiplexing
    /// coroutines onto kernel threads.
    pub fn init(allocator: *mem.Allocator) !Loop {
        var self = Loop{
            .keep_running = true,
            .allocator = allocator,
            .os_data = undefined,
            .next_tick_queue = std.atomic.QueueMpsc(promise).init(),
        };
        try self.initOsData();
        errdefer self.deinitOsData();

        return self;
    }

    /// must call stop before deinit
    pub fn deinit(self: *Loop) void {
        self.deinitOsData();
    }

    const InitOsDataError = std.os.LinuxEpollCreateError;

    fn initOsData(self: *Loop) InitOsDataError!void {
        switch (builtin.os) {
            builtin.Os.linux => {
                self.os_data.epollfd = try std.os.linuxEpollCreate(std.os.linux.EPOLL_CLOEXEC);
                errdefer std.os.close(self.os_data.epollfd);
            },
            else => {},
        }
    }

    fn deinitOsData(self: *Loop) void {
        switch (builtin.os) {
            builtin.Os.linux => std.os.close(self.os_data.epollfd),
            else => {},
        }
    }

    pub fn addFd(self: *Loop, fd: i32, prom: promise) !void {
        var ev = std.os.linux.epoll_event{
            .events = std.os.linux.EPOLLIN | std.os.linux.EPOLLOUT | std.os.linux.EPOLLET,
            .data = std.os.linux.epoll_data{ .ptr = @ptrToInt(prom) },
        };
        try std.os.linuxEpollCtl(self.os_data.epollfd, std.os.linux.EPOLL_CTL_ADD, fd, &ev);
    }

    pub fn removeFd(self: *Loop, fd: i32) void {
        std.os.linuxEpollCtl(self.os_data.epollfd, std.os.linux.EPOLL_CTL_DEL, fd, undefined) catch {};
    }
    async fn waitFd(self: *Loop, fd: i32) !void {
        defer self.removeFd(fd);
        suspend |p| {
            try self.addFd(fd, p);
        }
    }

    pub fn stop(self: *Loop) void {
        // TODO make atomic
        self.keep_running = false;
        // TODO activate an fd in the epoll set which should cancel all the promises
    }

    /// bring your own linked list node. this means it can't fail.
    pub fn onNextTick(self: *Loop, node: *NextTickNode) void {
        self.next_tick_queue.put(node);
    }

    pub fn run(self: *Loop) void {
        while (self.keep_running) {
            // TODO multiplex the next tick queue and the epoll event results onto a thread pool
            while (self.next_tick_queue.get()) |node| {
                resume node.data;
            }
            if (!self.keep_running) break;

            self.dispatchOsEvents();
        }
    }

    fn dispatchOsEvents(self: *Loop) void {
        switch (builtin.os) {
            builtin.Os.linux => {
                var events: [16]std.os.linux.epoll_event = undefined;
                const count = std.os.linuxEpollWait(self.os_data.epollfd, events[0..], -1);
                for (events[0..count]) |ev| {
                    const p = @intToPtr(promise, ev.data.ptr);
                    resume p;
                }
            },
            else => {},
        }
    }
};

/// many producer, many consumer, thread-safe, lock-free, runtime configurable buffer size
/// when buffer is empty, consumers suspend and are resumed by producers
/// when buffer is full, producers suspend and are resumed by consumers
pub fn Channel(comptime T: type) type {
    return struct {
        loop: *Loop,

        getters: std.atomic.QueueMpsc(GetNode),
        putters: std.atomic.QueueMpsc(PutNode),
        get_count: usize,
        put_count: usize,
        dispatch_lock: u8, // TODO make this a bool
        need_dispatch: u8, // TODO make this a bool

        // simple fixed size ring buffer
        buffer_nodes: []T,
        buffer_index: usize,
        buffer_len: usize,

        const SelfChannel = this;
        const GetNode = struct {
            ptr: *T,
            tick_node: *Loop.NextTickNode,
        };
        const PutNode = struct {
            data: T,
            tick_node: *Loop.NextTickNode,
        };

        /// call destroy when done
        pub fn create(loop: *Loop, capacity: usize) !*SelfChannel {
            const buffer_nodes = try loop.allocator.alloc(T, capacity);
            errdefer loop.allocator.free(buffer_nodes);

            const self = try loop.allocator.create(SelfChannel{
                .loop = loop,
                .buffer_len = 0,
                .buffer_nodes = buffer_nodes,
                .buffer_index = 0,
                .dispatch_lock = 0,
                .need_dispatch = 0,
                .getters = std.atomic.QueueMpsc(GetNode).init(),
                .putters = std.atomic.QueueMpsc(PutNode).init(),
                .get_count = 0,
                .put_count = 0,
            });
            errdefer loop.allocator.destroy(self);

            return self;
        }

        /// must be called when all calls to put and get have suspended and no more calls occur
        pub fn destroy(self: *SelfChannel) void {
            while (self.getters.get()) |get_node| {
                cancel get_node.data.tick_node.data;
            }
            while (self.putters.get()) |put_node| {
                cancel put_node.data.tick_node.data;
            }
            self.loop.allocator.free(self.buffer_nodes);
            self.loop.allocator.destroy(self);
        }

        /// puts a data item in the channel. The promise completes when the value has been added to the
        /// buffer, or in the case of a zero size buffer, when the item has been retrieved by a getter.
        pub async fn put(self: *SelfChannel, data: T) void {
            // TODO should be able to group memory allocation failure before first suspend point
            // so that the async invocation catches it
            var dispatch_tick_node_ptr: *Loop.NextTickNode = undefined;
            _ = async self.dispatch(&dispatch_tick_node_ptr) catch unreachable;

            suspend |handle| {
                var my_tick_node = Loop.NextTickNode{
                    .next = undefined,
                    .data = handle,
                };
                var queue_node = std.atomic.QueueMpsc(PutNode).Node{
                    .data = PutNode{
                        .tick_node = &my_tick_node,
                        .data = data,
                    },
                    .next = undefined,
                };
                self.putters.put(&queue_node);
                _ = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);

                self.loop.onNextTick(dispatch_tick_node_ptr);
            }
        }

        /// await this function to get an item from the channel. If the buffer is empty, the promise will
        /// complete when the next item is put in the channel.
        pub async fn get(self: *SelfChannel) T {
            // TODO should be able to group memory allocation failure before first suspend point
            // so that the async invocation catches it
            var dispatch_tick_node_ptr: *Loop.NextTickNode = undefined;
            _ = async self.dispatch(&dispatch_tick_node_ptr) catch unreachable;

            // TODO integrate this function with named return values
            // so we can get rid of this extra result copy
            var result: T = undefined;
            var debug_handle: usize = undefined;
            suspend |handle| {
                debug_handle = @ptrToInt(handle);
                var my_tick_node = Loop.NextTickNode{
                    .next = undefined,
                    .data = handle,
                };
                var queue_node = std.atomic.QueueMpsc(GetNode).Node{
                    .data = GetNode{
                        .ptr = &result,
                        .tick_node = &my_tick_node,
                    },
                    .next = undefined,
                };
                self.getters.put(&queue_node);
                _ = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);

                self.loop.onNextTick(dispatch_tick_node_ptr);
            }
            return result;
        }

        async fn dispatch(self: *SelfChannel, tick_node_ptr: **Loop.NextTickNode) void {
            // resumed by onNextTick
            suspend |handle| {
                var tick_node = Loop.NextTickNode{
                    .data = handle,
                    .next = undefined,
                };
                tick_node_ptr.* = &tick_node;
            }

            // set the "need dispatch" flag
            _ = @atomicRmw(u8, &self.need_dispatch, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);

            lock: while (true) {
                // set the lock flag
                const prev_lock = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
                if (prev_lock != 0) return;

                // clear the need_dispatch flag since we're about to do it
                _ = @atomicRmw(u8, &self.need_dispatch, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);

                while (true) {
                    one_dispatch: {
                        // later we correct these extra subtractions
                        var get_count = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        var put_count = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);

                        // transfer self.buffer to self.getters
                        while (self.buffer_len != 0) {
                            if (get_count == 0) break :one_dispatch;

                            const get_node = &self.getters.get().?.data;
                            get_node.ptr.* = self.buffer_nodes[self.buffer_index -% self.buffer_len];
                            self.loop.onNextTick(get_node.tick_node);
                            self.buffer_len -= 1;

                            get_count = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        }

                        // direct transfer self.putters to self.getters
                        while (get_count != 0 and put_count != 0) {
                            const get_node = &self.getters.get().?.data;
                            const put_node = &self.putters.get().?.data;

                            get_node.ptr.* = put_node.data;
                            self.loop.onNextTick(get_node.tick_node);
                            self.loop.onNextTick(put_node.tick_node);

                            get_count = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                            put_count = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        }

                        // transfer self.putters to self.buffer
                        while (self.buffer_len != self.buffer_nodes.len and put_count != 0) {
                            const put_node = &self.putters.get().?.data;

                            self.buffer_nodes[self.buffer_index] = put_node.data;
                            self.loop.onNextTick(put_node.tick_node);
                            self.buffer_index +%= 1;
                            self.buffer_len += 1;

                            put_count = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        }
                    }

                    // undo the extra subtractions
                    _ = @atomicRmw(usize, &self.get_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
                    _ = @atomicRmw(usize, &self.put_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);

                    // clear need-dispatch flag
                    const need_dispatch = @atomicRmw(u8, &self.need_dispatch, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                    if (need_dispatch != 0) continue;

                    const my_lock = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                    assert(my_lock != 0);

                    // we have to check again now that we unlocked
                    if (@atomicLoad(u8, &self.need_dispatch, AtomicOrder.SeqCst) != 0) continue :lock;

                    return;
                }
            }
        }
    };
}

pub async fn connect(loop: *Loop, _address: *const std.net.Address) !std.os.File {
    var address = _address.*; // TODO https://github.com/ziglang/zig/issues/733

    const sockfd = try std.os.posixSocket(posix.AF_INET, posix.SOCK_STREAM | posix.SOCK_CLOEXEC | posix.SOCK_NONBLOCK, posix.PROTO_tcp);
    errdefer std.os.close(sockfd);

    try std.os.posixConnectAsync(sockfd, &address.os_addr);
    try await try async loop.waitFd(sockfd);
    try std.os.posixGetSockOptConnectError(sockfd);

    return std.os.File.openHandle(sockfd);
}

test "listen on a port, send bytes, receive bytes" {
    if (builtin.os != builtin.Os.linux) {
        // TODO build abstractions for other operating systems
        return;
    }
    const MyServer = struct {
        tcp_server: TcpServer,

        const Self = this;
        async<*mem.Allocator> fn handler(tcp_server: *TcpServer, _addr: *const std.net.Address, _socket: *const std.os.File) void {
            const self = @fieldParentPtr(Self, "tcp_server", tcp_server);
            var socket = _socket.*; // TODO https://github.com/ziglang/zig/issues/733
            defer socket.close();
            const next_handler = async errorableHandler(self, _addr, socket) catch |err| switch (err) {
                error.OutOfMemory => @panic("unable to handle connection: out of memory"),
            };
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

    var loop = try Loop.init(std.debug.global_allocator);
    var server = MyServer{ .tcp_server = try TcpServer.init(&loop) };
    defer server.tcp_server.deinit();
    try server.tcp_server.listen(addr, MyServer.handler);

    const p = try async<std.debug.global_allocator> doAsyncTest(&loop, server.tcp_server.listen_address);
    defer cancel p;
    loop.run();
}

async fn doAsyncTest(loop: *Loop, address: *const std.net.Address) void {
    errdefer @panic("test failure");

    var socket_file = try await try async event.connect(loop, address);
    defer socket_file.close();

    var buf: [512]u8 = undefined;
    const amt_read = try socket_file.read(buf[0..]);
    const msg = buf[0..amt_read];
    assert(mem.eql(u8, msg, "hello from server\n"));
    loop.stop();
}

test "std.event.Channel" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    var loop = try Loop.init(allocator);
    defer loop.deinit();

    const channel = try Channel(i32).create(&loop, 0);
    defer channel.destroy();

    const handle = try async<allocator> testChannelGetter(&loop, channel);
    defer cancel handle;

    const putter = try async<allocator> testChannelPutter(channel);
    defer cancel putter;

    loop.run();
}

async fn testChannelGetter(loop: *Loop, channel: *Channel(i32)) void {
    errdefer @panic("test failed");

    const value1_promise = try async channel.get();
    const value1 = await value1_promise;
    assert(value1 == 1234);

    const value2_promise = try async channel.get();
    const value2 = await value2_promise;
    assert(value2 == 4567);

    loop.stop();
}

async fn testChannelPutter(channel: *Channel(i32)) void {
    await (async channel.put(1234) catch @panic("out of memory"));
    await (async channel.put(4567) catch @panic("out of memory"));
}
