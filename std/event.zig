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
    sockfd: ?i32,
    accept_coro: ?promise,
    listen_address: std.net.Address,

    waiting_for_emfile_node: PromiseNode,
    listen_resume_node: event.Loop.ResumeNode,

    const PromiseNode = std.LinkedList(promise).Node;

    pub fn init(loop: *Loop) TcpServer {
        // TODO can't initialize handler coroutine here because we need well defined copy elision
        return TcpServer{
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
        self: *TcpServer,
        address: *const std.net.Address,
        handleRequestFn: async<*mem.Allocator> fn (*TcpServer, *const std.net.Address, *const std.os.File) void,
    ) !void {
        self.handleRequestFn = handleRequestFn;

        const sockfd = try std.os.posixSocket(posix.AF_INET, posix.SOCK_STREAM | posix.SOCK_CLOEXEC | posix.SOCK_NONBLOCK, posix.PROTO_tcp);
        errdefer std.os.close(sockfd);
        self.sockfd = sockfd;

        try std.os.posixBind(sockfd, &address.os_addr);
        try std.os.posixListen(sockfd, posix.SOMAXCONN);
        self.listen_address = std.net.Address.initPosix(try std.os.posixGetSockName(sockfd));

        self.accept_coro = try async<self.loop.allocator> TcpServer.handler(self);
        errdefer cancel self.accept_coro.?;

        self.listen_resume_node.handle = self.accept_coro.?;
        try self.loop.addFd(sockfd, &self.listen_resume_node);
        errdefer self.loop.removeFd(sockfd);
    }

    /// Stop listening
    pub fn close(self: *TcpServer) void {
        self.loop.removeFd(self.sockfd.?);
        std.os.close(self.sockfd.?);
    }

    pub fn deinit(self: *TcpServer) void {
        if (self.accept_coro) |accept_coro| cancel accept_coro;
        if (self.sockfd) |sockfd| std.os.close(sockfd);
    }

    pub async fn handler(self: *TcpServer) void {
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

pub const Loop = struct {
    allocator: *mem.Allocator,
    next_tick_queue: std.atomic.QueueMpsc(promise),
    os_data: OsData,
    dispatch_lock: u8, // TODO make this a bool
    pending_event_count: usize,
    extra_threads: []*std.os.Thread,
    final_resume_node: ResumeNode,

    pub const NextTickNode = std.atomic.QueueMpsc(promise).Node;

    pub const ResumeNode = struct {
        id: Id,
        handle: promise,

        pub const Id = enum {
            Basic,
            Stop,
            EventFd,
        };

        pub const EventFd = struct {
            base: ResumeNode,
            epoll_op: u32,
            eventfd: i32,
        };
    };

    /// After initialization, call run().
    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    fn initSingleThreaded(self: *Loop, allocator: *mem.Allocator) !void {
        return self.initInternal(allocator, 1);
    }

    /// The allocator must be thread-safe because we use it for multiplexing
    /// coroutines onto kernel threads.
    /// After initialization, call run().
    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    fn initMultiThreaded(self: *Loop, allocator: *mem.Allocator) !void {
        // TODO check the actual cpu core count
        return self.initInternal(allocator, 4);
    }

    /// Thread count is the total thread count. The thread pool size will be
    /// max(thread_count - 1, 0)
    fn initInternal(self: *Loop, allocator: *mem.Allocator, thread_count: usize) !void {
        self.* = Loop{
            .pending_event_count = 0,
            .allocator = allocator,
            .os_data = undefined,
            .next_tick_queue = std.atomic.QueueMpsc(promise).init(),
            .dispatch_lock = 1, // start locked so threads go directly into epoll wait
            .extra_threads = undefined,
            .final_resume_node = ResumeNode{
                .id = ResumeNode.Id.Stop,
                .handle = undefined,
            },
        };
        try self.initOsData(thread_count);
        errdefer self.deinitOsData();
    }

    /// must call stop before deinit
    pub fn deinit(self: *Loop) void {
        self.deinitOsData();
    }

    const InitOsDataError = std.os.LinuxEpollCreateError || mem.Allocator.Error || std.os.LinuxEventFdError ||
        std.os.SpawnThreadError || std.os.LinuxEpollCtlError;

    const wakeup_bytes = []u8{0x1} ** 8;

    fn initOsData(self: *Loop, thread_count: usize) InitOsDataError!void {
        switch (builtin.os) {
            builtin.Os.linux => {
                const extra_thread_count = thread_count - 1;
                self.os_data.available_eventfd_resume_nodes = std.atomic.Stack(ResumeNode.EventFd).init();
                self.os_data.eventfd_resume_nodes = try self.allocator.alloc(
                    std.atomic.Stack(ResumeNode.EventFd).Node,
                    extra_thread_count,
                );
                errdefer self.allocator.free(self.os_data.eventfd_resume_nodes);

                errdefer {
                    while (self.os_data.available_eventfd_resume_nodes.pop()) |node| std.os.close(node.data.eventfd);
                }
                for (self.os_data.eventfd_resume_nodes) |*eventfd_node| {
                    eventfd_node.* = std.atomic.Stack(ResumeNode.EventFd).Node{
                        .data = ResumeNode.EventFd{
                            .base = ResumeNode{
                                .id = ResumeNode.Id.EventFd,
                                .handle = undefined,
                            },
                            .eventfd = try std.os.linuxEventFd(1, posix.EFD_CLOEXEC | posix.EFD_NONBLOCK),
                            .epoll_op = posix.EPOLL_CTL_ADD,
                        },
                        .next = undefined,
                    };
                    self.os_data.available_eventfd_resume_nodes.push(eventfd_node);
                }

                self.os_data.epollfd = try std.os.linuxEpollCreate(posix.EPOLL_CLOEXEC);
                errdefer std.os.close(self.os_data.epollfd);

                self.os_data.final_eventfd = try std.os.linuxEventFd(0, posix.EFD_CLOEXEC | posix.EFD_NONBLOCK);
                errdefer std.os.close(self.os_data.final_eventfd);

                self.os_data.final_eventfd_event = posix.epoll_event{
                    .events = posix.EPOLLIN,
                    .data = posix.epoll_data{ .ptr = @ptrToInt(&self.final_resume_node) },
                };
                try std.os.linuxEpollCtl(
                    self.os_data.epollfd,
                    posix.EPOLL_CTL_ADD,
                    self.os_data.final_eventfd,
                    &self.os_data.final_eventfd_event,
                );
                self.extra_threads = try self.allocator.alloc(*std.os.Thread, extra_thread_count);
                errdefer self.allocator.free(self.extra_threads);

                var extra_thread_index: usize = 0;
                errdefer {
                    while (extra_thread_index != 0) {
                        extra_thread_index -= 1;
                        // writing 8 bytes to an eventfd cannot fail
                        std.os.posixWrite(self.os_data.final_eventfd, wakeup_bytes) catch unreachable;
                        self.extra_threads[extra_thread_index].wait();
                    }
                }
                while (extra_thread_index < extra_thread_count) : (extra_thread_index += 1) {
                    self.extra_threads[extra_thread_index] = try std.os.spawnThread(self, workerRun);
                }
            },
            else => {},
        }
    }

    fn deinitOsData(self: *Loop) void {
        switch (builtin.os) {
            builtin.Os.linux => {
                std.os.close(self.os_data.final_eventfd);
                while (self.os_data.available_eventfd_resume_nodes.pop()) |node| std.os.close(node.data.eventfd);
                std.os.close(self.os_data.epollfd);
                self.allocator.free(self.os_data.eventfd_resume_nodes);
                self.allocator.free(self.extra_threads);
            },
            else => {},
        }
    }

    /// resume_node must live longer than the promise that it holds a reference to.
    pub fn addFd(self: *Loop, fd: i32, resume_node: *ResumeNode) !void {
        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
        errdefer {
            _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
        }
        try self.modFd(
            fd,
            posix.EPOLL_CTL_ADD,
            std.os.linux.EPOLLIN | std.os.linux.EPOLLOUT | std.os.linux.EPOLLET,
            resume_node,
        );
    }

    pub fn modFd(self: *Loop, fd: i32, op: u32, events: u32, resume_node: *ResumeNode) !void {
        var ev = std.os.linux.epoll_event{
            .events = events,
            .data = std.os.linux.epoll_data{ .ptr = @ptrToInt(resume_node) },
        };
        try std.os.linuxEpollCtl(self.os_data.epollfd, op, fd, &ev);
    }

    pub fn removeFd(self: *Loop, fd: i32) void {
        self.removeFdNoCounter(fd);
        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
    }

    fn removeFdNoCounter(self: *Loop, fd: i32) void {
        std.os.linuxEpollCtl(self.os_data.epollfd, std.os.linux.EPOLL_CTL_DEL, fd, undefined) catch {};
    }

    pub async fn waitFd(self: *Loop, fd: i32) !void {
        defer self.removeFd(fd);
        var resume_node = ResumeNode{
            .id = ResumeNode.Id.Basic,
            .handle = undefined,
        };
        suspend |p| {
            resume_node.handle = p;
            try self.addFd(fd, &resume_node);
        }
        var a = &resume_node; // TODO better way to explicitly put memory in coro frame
    }

    /// Bring your own linked list node. This means it can't fail.
    pub fn onNextTick(self: *Loop, node: *NextTickNode) void {
        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
        self.next_tick_queue.put(node);
    }

    pub fn run(self: *Loop) void {
        _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
        self.workerRun();
        for (self.extra_threads) |extra_thread| {
            extra_thread.wait();
        }
    }

    fn workerRun(self: *Loop) void {
        start_over: while (true) {
            if (@atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst) == 0) {
                while (self.next_tick_queue.get()) |next_tick_node| {
                    const handle = next_tick_node.data;
                    if (self.next_tick_queue.isEmpty()) {
                        // last node, just resume it
                        _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                        resume handle;
                        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        continue :start_over;
                    }

                    // non-last node, stick it in the epoll set so that
                    // other threads can get to it
                    if (self.os_data.available_eventfd_resume_nodes.pop()) |resume_stack_node| {
                        const eventfd_node = &resume_stack_node.data;
                        eventfd_node.base.handle = handle;
                        // the pending count is already accounted for
                        const epoll_events = posix.EPOLLONESHOT | std.os.linux.EPOLLIN | std.os.linux.EPOLLOUT | std.os.linux.EPOLLET;
                        self.modFd(eventfd_node.eventfd, eventfd_node.epoll_op, epoll_events, &eventfd_node.base) catch |_| {
                            // fine, we didn't need it anyway
                            _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                            self.os_data.available_eventfd_resume_nodes.push(resume_stack_node);
                            resume handle;
                            _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                            continue :start_over;
                        };
                    } else {
                        // threads are too busy, can't add another eventfd to wake one up
                        _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
                        resume handle;
                        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                        continue :start_over;
                    }
                }

                const pending_event_count = @atomicLoad(usize, &self.pending_event_count, AtomicOrder.SeqCst);
                if (pending_event_count == 0) {
                    // cause all the threads to stop
                    // writing 8 bytes to an eventfd cannot fail
                    std.os.posixWrite(self.os_data.final_eventfd, wakeup_bytes) catch unreachable;
                    return;
                }

                _ = @atomicRmw(u8, &self.dispatch_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);
            }

            // only process 1 event so we don't steal from other threads
            var events: [1]std.os.linux.epoll_event = undefined;
            const count = std.os.linuxEpollWait(self.os_data.epollfd, events[0..], -1);
            for (events[0..count]) |ev| {
                const resume_node = @intToPtr(*ResumeNode, ev.data.ptr);
                const handle = resume_node.handle;
                const resume_node_id = resume_node.id;
                switch (resume_node_id) {
                    ResumeNode.Id.Basic => {},
                    ResumeNode.Id.Stop => return,
                    ResumeNode.Id.EventFd => {
                        const event_fd_node = @fieldParentPtr(ResumeNode.EventFd, "base", resume_node);
                        event_fd_node.epoll_op = posix.EPOLL_CTL_MOD;
                        const stack_node = @fieldParentPtr(std.atomic.Stack(ResumeNode.EventFd).Node, "data", event_fd_node);
                        self.os_data.available_eventfd_resume_nodes.push(stack_node);
                    },
                }
                resume handle;
                if (resume_node_id == ResumeNode.Id.EventFd) {
                    _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
                }
            }
        }
    }

    const OsData = switch (builtin.os) {
        builtin.Os.linux => struct {
            epollfd: i32,
            // pre-allocated eventfds. all permanently active.
            // this is how we send promises to be resumed on other threads.
            available_eventfd_resume_nodes: std.atomic.Stack(ResumeNode.EventFd),
            eventfd_resume_nodes: []std.atomic.Stack(ResumeNode.EventFd).Node,
            final_eventfd: i32,
            final_eventfd_event: posix.epoll_event,
        },
        else => struct {},
    };
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
            suspend |handle| {
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
    var server = MyServer{ .tcp_server = TcpServer.init(&loop) };
    defer server.tcp_server.deinit();
    try server.tcp_server.listen(addr, MyServer.handler);

    const p = try async<std.debug.global_allocator> doAsyncTest(&loop, server.tcp_server.listen_address, &server.tcp_server);
    defer cancel p;
    loop.run();
}

async fn doAsyncTest(loop: *Loop, address: *const std.net.Address, server: *TcpServer) void {
    errdefer @panic("test failure");

    var socket_file = try await try async event.connect(loop, address);
    defer socket_file.close();

    var buf: [512]u8 = undefined;
    const amt_read = try socket_file.read(buf[0..]);
    const msg = buf[0..amt_read];
    assert(mem.eql(u8, msg, "hello from server\n"));
    server.close();
}

test "std.event.Channel" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    var loop: Loop = undefined;
    // TODO make a multi threaded test
    try loop.initSingleThreaded(allocator);
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
}

async fn testChannelPutter(channel: *Channel(i32)) void {
    await (async channel.put(1234) catch @panic("out of memory"));
    await (async channel.put(4567) catch @panic("out of memory"));
}

/// Thread-safe async/await lock.
/// Does not make any syscalls - coroutines which are waiting for the lock are suspended, and
/// are resumed when the lock is released, in order.
pub const Lock = struct {
    loop: *Loop,
    shared_bit: u8, // TODO make this a bool
    queue: Queue,
    queue_empty_bit: u8, // TODO make this a bool

    const Queue = std.atomic.QueueMpsc(promise);

    pub const Held = struct {
        lock: *Lock,

        pub fn release(self: Held) void {
            // Resume the next item from the queue.
            if (self.lock.queue.get()) |node| {
                self.lock.loop.onNextTick(node);
                return;
            }

            // We need to release the lock.
            _ = @atomicRmw(u8, &self.lock.queue_empty_bit, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
            _ = @atomicRmw(u8, &self.lock.shared_bit, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);

            // There might be a queue item. If we know the queue is empty, we can be done,
            // because the other actor will try to obtain the lock.
            // But if there's a queue item, we are the actor which must loop and attempt
            // to grab the lock again.
            if (@atomicLoad(u8, &self.lock.queue_empty_bit, AtomicOrder.SeqCst) == 1) {
                return;
            }

            while (true) {
                const old_bit = @atomicRmw(u8, &self.lock.shared_bit, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
                if (old_bit != 0) {
                    // We did not obtain the lock. Great, the queue is someone else's problem.
                    return;
                }

                // Resume the next item from the queue.
                if (self.lock.queue.get()) |node| {
                    self.lock.loop.onNextTick(node);
                    return;
                }

                // Release the lock again.
                _ = @atomicRmw(u8, &self.lock.queue_empty_bit, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
                _ = @atomicRmw(u8, &self.lock.shared_bit, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);

                // Find out if we can be done.
                if (@atomicLoad(u8, &self.lock.queue_empty_bit, AtomicOrder.SeqCst) == 1) {
                    return;
                }
            }
        }
    };

    pub fn init(loop: *Loop) Lock {
        return Lock{
            .loop = loop,
            .shared_bit = 0,
            .queue = Queue.init(),
            .queue_empty_bit = 1,
        };
    }

    /// Must be called when not locked. Not thread safe.
    /// All calls to acquire() and release() must complete before calling deinit().
    pub fn deinit(self: *Lock) void {
        assert(self.shared_bit == 0);
        while (self.queue.get()) |node| cancel node.data;
    }

    pub async fn acquire(self: *Lock) Held {
        var my_tick_node: Loop.NextTickNode = undefined;

        s: suspend |handle| {
            my_tick_node.data = handle;
            self.queue.put(&my_tick_node);

            // At this point, we are in the queue, so we might have already been resumed and this coroutine
            // frame might be destroyed. For the rest of the suspend block we cannot access the coroutine frame.

            // We set this bit so that later we can rely on the fact, that if queue_empty_bit is 1, some actor
            // will attempt to grab the lock.
            _ = @atomicRmw(u8, &self.queue_empty_bit, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);

            while (true) {
                const old_bit = @atomicRmw(u8, &self.shared_bit, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
                if (old_bit != 0) {
                    // We did not obtain the lock. Trust that our queue entry will resume us, and allow
                    // suspend to complete.
                    break;
                }
                // We got the lock. However we might have already been resumed from the queue.
                if (self.queue.get()) |node| {
                    // Whether this node is us or someone else, we tail resume it.
                    resume node.data;
                    break;
                } else {
                    // We already got resumed, and there are none left in the queue, which means that
                    // we aren't even supposed to hold the lock right now.
                    _ = @atomicRmw(u8, &self.queue_empty_bit, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
                    _ = @atomicRmw(u8, &self.shared_bit, AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst);

                    // There might be a queue item. If we know the queue is empty, we can be done,
                    // because the other actor will try to obtain the lock.
                    // But if there's a queue item, we are the actor which must loop and attempt
                    // to grab the lock again.
                    if (@atomicLoad(u8, &self.queue_empty_bit, AtomicOrder.SeqCst) == 1) {
                        break;
                    } else {
                        continue;
                    }
                }
                unreachable;
            }
        }

        // TODO this workaround to force my_tick_node to be in the coroutine frame should
        // not be necessary
        var trash1 = &my_tick_node;

        return Held{ .lock = self };
    }
};

/// Thread-safe async/await lock that protects one piece of data.
/// Does not make any syscalls - coroutines which are waiting for the lock are suspended, and
/// are resumed when the lock is released, in order.
pub fn Locked(comptime T: type) type {
    return struct {
        lock: Lock,
        private_data: T,

        const Self = this;

        pub const HeldLock = struct {
            value: *T,
            held: Lock.Held,

            pub fn release(self: HeldLock) void {
                self.held.release();
            }
        };

        pub fn init(loop: *Loop, data: T) Self {
            return Self{
                .lock = Lock.init(loop),
                .private_data = data,
            };
        }

        pub fn deinit(self: *Self) void {
            self.lock.deinit();
        }

        pub async fn acquire(self: *Self) HeldLock {
            return HeldLock{
            // TODO guaranteed allocation elision
                .held = await (async self.lock.acquire() catch unreachable),
                .value = &self.private_data,
            };
        }
    };
}

test "std.event.Lock" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    var loop: Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var lock = Lock.init(&loop);
    defer lock.deinit();

    const handle = try async<allocator> testLock(&loop, &lock);
    defer cancel handle;
    loop.run();

    assert(mem.eql(i32, shared_test_data, [1]i32{3 * @intCast(i32, shared_test_data.len)} ** shared_test_data.len));
}

async fn testLock(loop: *Loop, lock: *Lock) void {
    const handle1 = async lockRunner(lock) catch @panic("out of memory");
    var tick_node1 = Loop.NextTickNode{
        .next = undefined,
        .data = handle1,
    };
    loop.onNextTick(&tick_node1);

    const handle2 = async lockRunner(lock) catch @panic("out of memory");
    var tick_node2 = Loop.NextTickNode{
        .next = undefined,
        .data = handle2,
    };
    loop.onNextTick(&tick_node2);

    const handle3 = async lockRunner(lock) catch @panic("out of memory");
    var tick_node3 = Loop.NextTickNode{
        .next = undefined,
        .data = handle3,
    };
    loop.onNextTick(&tick_node3);

    await handle1;
    await handle2;
    await handle3;

    // TODO this is to force tick node memory to be in the coro frame
    // there should be a way to make it explicit where the memory is
    var a = &tick_node1;
    var b = &tick_node2;
    var c = &tick_node3;
}

var shared_test_data = [1]i32{0} ** 10;
var shared_test_index: usize = 0;

async fn lockRunner(lock: *Lock) void {
    suspend; // resumed by onNextTick

    var i: usize = 0;
    while (i < shared_test_data.len) : (i += 1) {
        const handle = await (async lock.acquire() catch @panic("out of memory"));
        defer handle.release();

        shared_test_index = 0;
        while (shared_test_index < shared_test_data.len) : (shared_test_index += 1) {
            shared_test_data[shared_test_index] = shared_test_data[shared_test_index] + 1;
        }
    }
}
