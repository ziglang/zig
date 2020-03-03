const std = @import("../std.zig");
const builtin = @import("builtin");
const root = @import("root");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;
const os = std.os;
const windows = os.windows;
const maxInt = std.math.maxInt;
const Thread = std.Thread;

pub const Loop = struct {
    next_tick_queue: std.atomic.Queue(anyframe),
    os_data: OsData,
    final_resume_node: ResumeNode,
    pending_event_count: usize,
    extra_threads: []*Thread,

    /// For resources that have the same lifetime as the `Loop`.
    /// This is only used by `Loop` for the thread pool and associated resources.
    arena: std.heap.ArenaAllocator,

    /// Pre-allocated eventfds. All permanently active.
    /// This is how `Loop` sends promises to be resumed on other threads.
    available_eventfd_resume_nodes: std.atomic.Stack(ResumeNode.EventFd),
    eventfd_resume_nodes: []std.atomic.Stack(ResumeNode.EventFd).Node,

    pub const NextTickNode = std.atomic.Queue(anyframe).Node;

    pub const ResumeNode = struct {
        id: Id,
        handle: anyframe,
        overlapped: Overlapped,

        pub const overlapped_init = switch (builtin.os.tag) {
            .windows => windows.OVERLAPPED{
                .Internal = 0,
                .InternalHigh = 0,
                .Offset = 0,
                .OffsetHigh = 0,
                .hEvent = null,
            },
            else => {},
        };
        pub const Overlapped = @TypeOf(overlapped_init);

        pub const Id = enum {
            Basic,
            Stop,
            EventFd,
        };

        pub const EventFd = switch (builtin.os.tag) {
            .macosx, .freebsd, .netbsd, .dragonfly => KEventFd,
            .linux => struct {
                base: ResumeNode,
                epoll_op: u32,
                eventfd: i32,
            },
            .windows => struct {
                base: ResumeNode,
                completion_key: usize,
            },
            else => struct {},
        };

        const KEventFd = struct {
            base: ResumeNode,
            kevent: os.Kevent,
        };

        pub const Basic = switch (builtin.os.tag) {
            .macosx, .freebsd, .netbsd, .dragonfly => KEventBasic,
            .linux => struct {
                base: ResumeNode,
            },
            .windows => struct {
                base: ResumeNode,
            },
            else => @compileError("unsupported OS"),
        };

        const KEventBasic = struct {
            base: ResumeNode,
            kev: os.Kevent,
        };
    };

    var global_instance_state: Loop = undefined;
    const default_instance: ?*Loop = switch (std.io.mode) {
        .blocking => null,
        .evented => &global_instance_state,
    };
    pub const instance: ?*Loop = if (@hasDecl(root, "event_loop")) root.event_loop else default_instance;

    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    /// https://github.com/ziglang/zig/issues/2761 and https://github.com/ziglang/zig/issues/2765
    pub fn init(self: *Loop) !void {
        if (builtin.single_threaded) {
            return self.initSingleThreaded();
        } else {
            return self.initMultiThreaded();
        }
    }

    /// After initialization, call run().
    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    /// https://github.com/ziglang/zig/issues/2761 and https://github.com/ziglang/zig/issues/2765
    pub fn initSingleThreaded(self: *Loop) !void {
        return self.initThreadPool(1);
    }

    /// After initialization, call run().
    /// This is the same as `initThreadPool` using `Thread.cpuCount` to determine the thread
    /// pool size.
    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    /// https://github.com/ziglang/zig/issues/2761 and https://github.com/ziglang/zig/issues/2765
    pub fn initMultiThreaded(self: *Loop) !void {
        if (builtin.single_threaded)
            @compileError("initMultiThreaded unavailable when building in single-threaded mode");
        const core_count = try Thread.cpuCount();
        return self.initThreadPool(core_count);
    }

    /// Thread count is the total thread count. The thread pool size will be
    /// max(thread_count - 1, 0)
    pub fn initThreadPool(self: *Loop, thread_count: usize) !void {
        self.* = Loop{
            .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
            .pending_event_count = 1,
            .os_data = undefined,
            .next_tick_queue = std.atomic.Queue(anyframe).init(),
            .extra_threads = undefined,
            .available_eventfd_resume_nodes = std.atomic.Stack(ResumeNode.EventFd).init(),
            .eventfd_resume_nodes = undefined,
            .final_resume_node = ResumeNode{
                .id = ResumeNode.Id.Stop,
                .handle = undefined,
                .overlapped = ResumeNode.overlapped_init,
            },
        };
        errdefer self.arena.deinit();

        // We need at least one of these in case the fs thread wants to use onNextTick
        const extra_thread_count = thread_count - 1;
        const resume_node_count = std.math.max(extra_thread_count, 1);
        self.eventfd_resume_nodes = try self.arena.allocator.alloc(
            std.atomic.Stack(ResumeNode.EventFd).Node,
            resume_node_count,
        );

        self.extra_threads = try self.arena.allocator.alloc(*Thread, extra_thread_count);

        try self.initOsData(extra_thread_count);
        errdefer self.deinitOsData();
    }

    pub fn deinit(self: *Loop) void {
        self.deinitOsData();
        self.arena.deinit();
        self.* = undefined;
    }

    const InitOsDataError = os.EpollCreateError || mem.Allocator.Error || os.EventFdError ||
        Thread.SpawnError || os.EpollCtlError || os.KEventError ||
        windows.CreateIoCompletionPortError;

    const wakeup_bytes = [_]u8{0x1} ** 8;

    fn initOsData(self: *Loop, extra_thread_count: usize) InitOsDataError!void {
        switch (builtin.os.tag) {
            .linux => {
                self.os_data.fs_queue = std.atomic.Queue(Request).init();
                self.os_data.fs_queue_item = 0;
                // we need another thread for the file system because Linux does not have an async
                // file system I/O API.
                self.os_data.fs_end_request = Request.Node{
                    .data = Request{
                        .msg = .end,
                        .finish = .NoAction,
                    },
                };

                errdefer {
                    while (self.available_eventfd_resume_nodes.pop()) |node| noasync os.close(node.data.eventfd);
                }
                for (self.eventfd_resume_nodes) |*eventfd_node| {
                    eventfd_node.* = std.atomic.Stack(ResumeNode.EventFd).Node{
                        .data = ResumeNode.EventFd{
                            .base = ResumeNode{
                                .id = .EventFd,
                                .handle = undefined,
                                .overlapped = ResumeNode.overlapped_init,
                            },
                            .eventfd = try os.eventfd(1, os.EFD_CLOEXEC | os.EFD_NONBLOCK),
                            .epoll_op = os.EPOLL_CTL_ADD,
                        },
                        .next = undefined,
                    };
                    self.available_eventfd_resume_nodes.push(eventfd_node);
                }

                self.os_data.epollfd = try os.epoll_create1(os.EPOLL_CLOEXEC);
                errdefer noasync os.close(self.os_data.epollfd);

                self.os_data.final_eventfd = try os.eventfd(0, os.EFD_CLOEXEC | os.EFD_NONBLOCK);
                errdefer noasync os.close(self.os_data.final_eventfd);

                self.os_data.final_eventfd_event = os.epoll_event{
                    .events = os.EPOLLIN,
                    .data = os.epoll_data{ .ptr = @ptrToInt(&self.final_resume_node) },
                };
                try os.epoll_ctl(
                    self.os_data.epollfd,
                    os.EPOLL_CTL_ADD,
                    self.os_data.final_eventfd,
                    &self.os_data.final_eventfd_event,
                );

                self.os_data.fs_thread = try Thread.spawn(self, posixFsRun);
                errdefer {
                    self.posixFsRequest(&self.os_data.fs_end_request);
                    self.os_data.fs_thread.wait();
                }

                if (builtin.single_threaded) {
                    assert(extra_thread_count == 0);
                    return;
                }

                var extra_thread_index: usize = 0;
                errdefer {
                    // writing 8 bytes to an eventfd cannot fail
                    const amt = noasync os.write(self.os_data.final_eventfd, &wakeup_bytes) catch unreachable;
                    assert(amt == wakeup_bytes.len);
                    while (extra_thread_index != 0) {
                        extra_thread_index -= 1;
                        self.extra_threads[extra_thread_index].wait();
                    }
                }
                while (extra_thread_index < extra_thread_count) : (extra_thread_index += 1) {
                    self.extra_threads[extra_thread_index] = try Thread.spawn(self, workerRun);
                }
            },
            .macosx, .freebsd, .netbsd, .dragonfly => {
                self.os_data.kqfd = try os.kqueue();
                errdefer noasync os.close(self.os_data.kqfd);

                self.os_data.fs_kqfd = try os.kqueue();
                errdefer noasync os.close(self.os_data.fs_kqfd);

                self.os_data.fs_queue = std.atomic.Queue(Request).init();
                // we need another thread for the file system because Darwin does not have an async
                // file system I/O API.
                self.os_data.fs_end_request = Request.Node{
                    .prev = undefined,
                    .next = undefined,
                    .data = Request{
                        .msg = .end,
                        .finish = .NoAction,
                    },
                };

                const empty_kevs = &[0]os.Kevent{};

                for (self.eventfd_resume_nodes) |*eventfd_node, i| {
                    eventfd_node.* = std.atomic.Stack(ResumeNode.EventFd).Node{
                        .data = ResumeNode.EventFd{
                            .base = ResumeNode{
                                .id = ResumeNode.Id.EventFd,
                                .handle = undefined,
                                .overlapped = ResumeNode.overlapped_init,
                            },
                            // this one is for sending events
                            .kevent = os.Kevent{
                                .ident = i,
                                .filter = os.EVFILT_USER,
                                .flags = os.EV_CLEAR | os.EV_ADD | os.EV_DISABLE,
                                .fflags = 0,
                                .data = 0,
                                .udata = @ptrToInt(&eventfd_node.data.base),
                            },
                        },
                        .next = undefined,
                    };
                    self.available_eventfd_resume_nodes.push(eventfd_node);
                    const kevent_array = @as(*const [1]os.Kevent, &eventfd_node.data.kevent);
                    _ = try os.kevent(self.os_data.kqfd, kevent_array, empty_kevs, null);
                    eventfd_node.data.kevent.flags = os.EV_CLEAR | os.EV_ENABLE;
                    eventfd_node.data.kevent.fflags = os.NOTE_TRIGGER;
                }

                // Pre-add so that we cannot get error.SystemResources
                // later when we try to activate it.
                self.os_data.final_kevent = os.Kevent{
                    .ident = extra_thread_count,
                    .filter = os.EVFILT_USER,
                    .flags = os.EV_ADD | os.EV_DISABLE,
                    .fflags = 0,
                    .data = 0,
                    .udata = @ptrToInt(&self.final_resume_node),
                };
                const final_kev_arr = @as(*const [1]os.Kevent, &self.os_data.final_kevent);
                _ = try os.kevent(self.os_data.kqfd, final_kev_arr, empty_kevs, null);
                self.os_data.final_kevent.flags = os.EV_ENABLE;
                self.os_data.final_kevent.fflags = os.NOTE_TRIGGER;

                self.os_data.fs_kevent_wake = os.Kevent{
                    .ident = 0,
                    .filter = os.EVFILT_USER,
                    .flags = os.EV_ADD | os.EV_ENABLE,
                    .fflags = os.NOTE_TRIGGER,
                    .data = 0,
                    .udata = undefined,
                };

                self.os_data.fs_kevent_wait = os.Kevent{
                    .ident = 0,
                    .filter = os.EVFILT_USER,
                    .flags = os.EV_ADD | os.EV_CLEAR,
                    .fflags = 0,
                    .data = 0,
                    .udata = undefined,
                };

                self.os_data.fs_thread = try Thread.spawn(self, posixFsRun);
                errdefer {
                    self.posixFsRequest(&self.os_data.fs_end_request);
                    self.os_data.fs_thread.wait();
                }

                if (builtin.single_threaded) {
                    assert(extra_thread_count == 0);
                    return;
                }

                var extra_thread_index: usize = 0;
                errdefer {
                    _ = os.kevent(self.os_data.kqfd, final_kev_arr, empty_kevs, null) catch unreachable;
                    while (extra_thread_index != 0) {
                        extra_thread_index -= 1;
                        self.extra_threads[extra_thread_index].wait();
                    }
                }
                while (extra_thread_index < extra_thread_count) : (extra_thread_index += 1) {
                    self.extra_threads[extra_thread_index] = try Thread.spawn(self, workerRun);
                }
            },
            .windows => {
                self.os_data.io_port = try windows.CreateIoCompletionPort(
                    windows.INVALID_HANDLE_VALUE,
                    null,
                    undefined,
                    maxInt(windows.DWORD),
                );
                errdefer windows.CloseHandle(self.os_data.io_port);

                for (self.eventfd_resume_nodes) |*eventfd_node, i| {
                    eventfd_node.* = std.atomic.Stack(ResumeNode.EventFd).Node{
                        .data = ResumeNode.EventFd{
                            .base = ResumeNode{
                                .id = ResumeNode.Id.EventFd,
                                .handle = undefined,
                                .overlapped = ResumeNode.overlapped_init,
                            },
                            // this one is for sending events
                            .completion_key = @ptrToInt(&eventfd_node.data.base),
                        },
                        .next = undefined,
                    };
                    self.available_eventfd_resume_nodes.push(eventfd_node);
                }

                if (builtin.single_threaded) {
                    assert(extra_thread_count == 0);
                    return;
                }

                var extra_thread_index: usize = 0;
                errdefer {
                    var i: usize = 0;
                    while (i < extra_thread_index) : (i += 1) {
                        while (true) {
                            const overlapped = &self.final_resume_node.overlapped;
                            windows.PostQueuedCompletionStatus(self.os_data.io_port, undefined, undefined, overlapped) catch continue;
                            break;
                        }
                    }
                    while (extra_thread_index != 0) {
                        extra_thread_index -= 1;
                        self.extra_threads[extra_thread_index].wait();
                    }
                }
                while (extra_thread_index < extra_thread_count) : (extra_thread_index += 1) {
                    self.extra_threads[extra_thread_index] = try Thread.spawn(self, workerRun);
                }
            },
            else => {},
        }
    }

    fn deinitOsData(self: *Loop) void {
        switch (builtin.os.tag) {
            .linux => {
                noasync os.close(self.os_data.final_eventfd);
                while (self.available_eventfd_resume_nodes.pop()) |node| noasync os.close(node.data.eventfd);
                noasync os.close(self.os_data.epollfd);
            },
            .macosx, .freebsd, .netbsd, .dragonfly => {
                noasync os.close(self.os_data.kqfd);
                noasync os.close(self.os_data.fs_kqfd);
            },
            .windows => {
                windows.CloseHandle(self.os_data.io_port);
            },
            else => {},
        }
    }

    /// resume_node must live longer than the anyframe that it holds a reference to.
    /// flags must contain EPOLLET
    pub fn linuxAddFd(self: *Loop, fd: i32, resume_node: *ResumeNode, flags: u32) !void {
        assert(flags & os.EPOLLET == os.EPOLLET);
        self.beginOneEvent();
        errdefer self.finishOneEvent();
        try self.linuxModFd(
            fd,
            os.EPOLL_CTL_ADD,
            flags,
            resume_node,
        );
    }

    pub fn linuxModFd(self: *Loop, fd: i32, op: u32, flags: u32, resume_node: *ResumeNode) !void {
        assert(flags & os.EPOLLET == os.EPOLLET);
        var ev = os.linux.epoll_event{
            .events = flags,
            .data = os.linux.epoll_data{ .ptr = @ptrToInt(resume_node) },
        };
        try os.epoll_ctl(self.os_data.epollfd, op, fd, &ev);
    }

    pub fn linuxRemoveFd(self: *Loop, fd: i32) void {
        os.epoll_ctl(self.os_data.epollfd, os.linux.EPOLL_CTL_DEL, fd, null) catch {};
        self.finishOneEvent();
    }

    pub fn linuxWaitFd(self: *Loop, fd: i32, flags: u32) void {
        assert(flags & os.EPOLLET == os.EPOLLET);
        assert(flags & os.EPOLLONESHOT == os.EPOLLONESHOT);
        var resume_node = ResumeNode.Basic{
            .base = ResumeNode{
                .id = .Basic,
                .handle = @frame(),
                .overlapped = ResumeNode.overlapped_init,
            },
        };
        var need_to_delete = false;
        defer if (need_to_delete) self.linuxRemoveFd(fd);

        suspend {
            if (self.linuxAddFd(fd, &resume_node.base, flags)) |_| {
                need_to_delete = true;
            } else |err| switch (err) {
                error.FileDescriptorNotRegistered => unreachable,
                error.OperationCausesCircularLoop => unreachable,
                error.FileDescriptorIncompatibleWithEpoll => unreachable,
                error.FileDescriptorAlreadyPresentInSet => unreachable, // evented writes to the same fd is not thread-safe

                error.SystemResources,
                error.UserResourceLimitReached,
                error.Unexpected,
                => {
                    // Fall back to a blocking poll(). Ideally this codepath is never hit, since
                    // epoll should be just fine. But this is better than incorrect behavior.
                    var poll_flags: i16 = 0;
                    if ((flags & os.EPOLLIN) != 0) poll_flags |= os.POLLIN;
                    if ((flags & os.EPOLLOUT) != 0) poll_flags |= os.POLLOUT;
                    var pfd = [1]os.pollfd{os.pollfd{
                        .fd = fd,
                        .events = poll_flags,
                        .revents = undefined,
                    }};
                    _ = os.poll(&pfd, -1) catch |poll_err| switch (poll_err) {
                        error.SystemResources,
                        error.Unexpected,
                        => {
                            // Even poll() didn't work. The best we can do now is sleep for a
                            // small duration and then hope that something changed.
                            std.time.sleep(1 * std.time.millisecond);
                        },
                    };
                    resume @frame();
                },
            }
        }
    }

    pub fn waitUntilFdReadable(self: *Loop, fd: os.fd_t) void {
        return self.linuxWaitFd(fd, os.EPOLLET | os.EPOLLONESHOT | os.EPOLLIN);
    }

    pub fn waitUntilFdWritable(self: *Loop, fd: os.fd_t) void {
        return self.linuxWaitFd(fd, os.EPOLLET | os.EPOLLONESHOT | os.EPOLLOUT);
    }

    pub fn waitUntilFdWritableOrReadable(self: *Loop, fd: os.fd_t) void {
        return self.linuxWaitFd(fd, os.EPOLLET | os.EPOLLONESHOT | os.EPOLLOUT | os.EPOLLIN);
    }

    pub async fn bsdWaitKev(self: *Loop, ident: usize, filter: i16, fflags: u32) !os.Kevent {
        var resume_node = ResumeNode.Basic{
            .base = ResumeNode{
                .id = ResumeNode.Id.Basic,
                .handle = @frame(),
                .overlapped = ResumeNode.overlapped_init,
            },
            .kev = undefined,
        };
        defer self.bsdRemoveKev(ident, filter);
        suspend {
            try self.bsdAddKev(&resume_node, ident, filter, fflags);
        }
        return resume_node.kev;
    }

    /// resume_node must live longer than the anyframe that it holds a reference to.
    pub fn bsdAddKev(self: *Loop, resume_node: *ResumeNode.Basic, ident: usize, filter: i16, fflags: u32) !void {
        self.beginOneEvent();
        errdefer self.finishOneEvent();
        var kev = os.Kevent{
            .ident = ident,
            .filter = filter,
            .flags = os.EV_ADD | os.EV_ENABLE | os.EV_CLEAR,
            .fflags = fflags,
            .data = 0,
            .udata = @ptrToInt(&resume_node.base),
        };
        const kevent_array = (*const [1]os.Kevent)(&kev);
        const empty_kevs = ([*]os.Kevent)(undefined)[0..0];
        _ = try os.kevent(self.os_data.kqfd, kevent_array, empty_kevs, null);
    }

    pub fn bsdRemoveKev(self: *Loop, ident: usize, filter: i16) void {
        var kev = os.Kevent{
            .ident = ident,
            .filter = filter,
            .flags = os.EV_DELETE,
            .fflags = 0,
            .data = 0,
            .udata = 0,
        };
        const kevent_array = (*const [1]os.Kevent)(&kev);
        const empty_kevs = ([*]os.Kevent)(undefined)[0..0];
        _ = os.kevent(self.os_data.kqfd, kevent_array, empty_kevs, null) catch undefined;
        self.finishOneEvent();
    }

    fn dispatch(self: *Loop) void {
        while (self.available_eventfd_resume_nodes.pop()) |resume_stack_node| {
            const next_tick_node = self.next_tick_queue.get() orelse {
                self.available_eventfd_resume_nodes.push(resume_stack_node);
                return;
            };
            const eventfd_node = &resume_stack_node.data;
            eventfd_node.base.handle = next_tick_node.data;
            switch (builtin.os.tag) {
                .macosx, .freebsd, .netbsd, .dragonfly => {
                    const kevent_array = @as(*const [1]os.Kevent, &eventfd_node.kevent);
                    const empty_kevs = &[0]os.Kevent{};
                    _ = os.kevent(self.os_data.kqfd, kevent_array, empty_kevs, null) catch {
                        self.next_tick_queue.unget(next_tick_node);
                        self.available_eventfd_resume_nodes.push(resume_stack_node);
                        return;
                    };
                },
                .linux => {
                    // the pending count is already accounted for
                    const epoll_events = os.EPOLLONESHOT | os.linux.EPOLLIN | os.linux.EPOLLOUT |
                        os.linux.EPOLLET;
                    self.linuxModFd(
                        eventfd_node.eventfd,
                        eventfd_node.epoll_op,
                        epoll_events,
                        &eventfd_node.base,
                    ) catch {
                        self.next_tick_queue.unget(next_tick_node);
                        self.available_eventfd_resume_nodes.push(resume_stack_node);
                        return;
                    };
                },
                .windows => {
                    windows.PostQueuedCompletionStatus(
                        self.os_data.io_port,
                        undefined,
                        undefined,
                        &eventfd_node.base.overlapped,
                    ) catch {
                        self.next_tick_queue.unget(next_tick_node);
                        self.available_eventfd_resume_nodes.push(resume_stack_node);
                        return;
                    };
                },
                else => @compileError("unsupported OS"),
            }
        }
    }

    /// Bring your own linked list node. This means it can't fail.
    pub fn onNextTick(self: *Loop, node: *NextTickNode) void {
        self.beginOneEvent(); // finished in dispatch()
        self.next_tick_queue.put(node);
        self.dispatch();
    }

    pub fn cancelOnNextTick(self: *Loop, node: *NextTickNode) void {
        if (self.next_tick_queue.remove(node)) {
            self.finishOneEvent();
        }
    }

    pub fn run(self: *Loop) void {
        self.finishOneEvent(); // the reference we start with

        self.workerRun();

        switch (builtin.os.tag) {
            .linux,
            .macosx,
            .freebsd,
            .netbsd,
            .dragonfly,
            => self.os_data.fs_thread.wait(),
            else => {},
        }

        for (self.extra_threads) |extra_thread| {
            extra_thread.wait();
        }
    }

    /// Yielding lets the event loop run, starting any unstarted async operations.
    /// Note that async operations automatically start when a function yields for any other reason,
    /// for example, when async I/O is performed. This function is intended to be used only when
    /// CPU bound tasks would be waiting in the event loop but never get started because no async I/O
    /// is performed.
    pub fn yield(self: *Loop) void {
        suspend {
            var my_tick_node = NextTickNode{
                .prev = undefined,
                .next = undefined,
                .data = @frame(),
            };
            self.onNextTick(&my_tick_node);
        }
    }

    /// If the build is multi-threaded and there is an event loop, then it calls `yield`. Otherwise,
    /// does nothing.
    pub fn startCpuBoundOperation() void {
        if (builtin.single_threaded) {
            return;
        } else if (instance) |event_loop| {
            event_loop.yield();
        }
    }

    /// call finishOneEvent when done
    pub fn beginOneEvent(self: *Loop) void {
        _ = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
    }

    pub fn finishOneEvent(self: *Loop) void {
        const prev = @atomicRmw(usize, &self.pending_event_count, AtomicRmwOp.Sub, 1, AtomicOrder.SeqCst);
        if (prev == 1) {
            // cause all the threads to stop
            switch (builtin.os.tag) {
                .linux => {
                    self.posixFsRequest(&self.os_data.fs_end_request);
                    // writing 8 bytes to an eventfd cannot fail
                    const amt = noasync os.write(self.os_data.final_eventfd, &wakeup_bytes) catch unreachable;
                    assert(amt == wakeup_bytes.len);
                    return;
                },
                .macosx, .freebsd, .netbsd, .dragonfly => {
                    self.posixFsRequest(&self.os_data.fs_end_request);
                    const final_kevent = @as(*const [1]os.Kevent, &self.os_data.final_kevent);
                    const empty_kevs = &[0]os.Kevent{};
                    // cannot fail because we already added it and this just enables it
                    _ = os.kevent(self.os_data.kqfd, final_kevent, empty_kevs, null) catch unreachable;
                    return;
                },
                .windows => {
                    var i: usize = 0;
                    while (i < self.extra_threads.len + 1) : (i += 1) {
                        while (true) {
                            const overlapped = &self.final_resume_node.overlapped;
                            windows.PostQueuedCompletionStatus(self.os_data.io_port, undefined, undefined, overlapped) catch continue;
                            break;
                        }
                    }
                    return;
                },
                else => @compileError("unsupported OS"),
            }
        }
    }

    /// Performs an async `os.open` using a separate thread.
    pub fn openZ(self: *Loop, file_path: [*:0]const u8, flags: u32, mode: usize) os.OpenError!os.fd_t {
        var req_node = Request.Node{
            .data = .{
                .msg = .{
                    .open = .{
                        .path = file_path,
                        .flags = flags,
                        .mode = mode,
                        .result = undefined,
                    },
                },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
        return req_node.data.msg.open.result;
    }

    /// Performs an async `os.opent` using a separate thread.
    pub fn openatZ(self: *Loop, fd: os.fd_t, file_path: [*:0]const u8, flags: u32, mode: usize) os.OpenError!os.fd_t {
        var req_node = Request.Node{
            .data = .{
                .msg = .{
                    .openat = .{
                        .fd = fd,
                        .path = file_path,
                        .flags = flags,
                        .mode = mode,
                        .result = undefined,
                    },
                },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
        return req_node.data.msg.openat.result;
    }

    /// Performs an async `os.close` using a separate thread.
    pub fn close(self: *Loop, fd: os.fd_t) void {
        var req_node = Request.Node{
            .data = .{
                .msg = .{ .close = .{ .fd = fd } },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
    }

    /// Performs an async `os.read` using a separate thread.
    /// `fd` must block and not return EAGAIN.
    pub fn read(self: *Loop, fd: os.fd_t, buf: []u8) os.ReadError!usize {
        var req_node = Request.Node{
            .data = .{
                .msg = .{
                    .read = .{
                        .fd = fd,
                        .buf = buf,
                        .result = undefined,
                    },
                },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
        return req_node.data.msg.read.result;
    }

    /// Performs an async `os.readv` using a separate thread.
    /// `fd` must block and not return EAGAIN.
    pub fn readv(self: *Loop, fd: os.fd_t, iov: []const os.iovec) os.ReadError!usize {
        var req_node = Request.Node{
            .data = .{
                .msg = .{
                    .readv = .{
                        .fd = fd,
                        .iov = iov,
                        .result = undefined,
                    },
                },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
        return req_node.data.msg.readv.result;
    }

    /// Performs an async `os.preadv` using a separate thread.
    /// `fd` must block and not return EAGAIN.
    pub fn preadv(self: *Loop, fd: os.fd_t, iov: []const os.iovec, offset: u64) os.ReadError!usize {
        var req_node = Request.Node{
            .data = .{
                .msg = .{
                    .preadv = .{
                        .fd = fd,
                        .iov = iov,
                        .offset = offset,
                        .result = undefined,
                    },
                },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
        return req_node.data.msg.preadv.result;
    }

    /// Performs an async `os.write` using a separate thread.
    /// `fd` must block and not return EAGAIN.
    pub fn write(self: *Loop, fd: os.fd_t, bytes: []const u8) os.WriteError!usize {
        var req_node = Request.Node{
            .data = .{
                .msg = .{
                    .write = .{
                        .fd = fd,
                        .bytes = bytes,
                        .result = undefined,
                    },
                },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
        return req_node.data.msg.write.result;
    }

    /// Performs an async `os.writev` using a separate thread.
    /// `fd` must block and not return EAGAIN.
    pub fn writev(self: *Loop, fd: os.fd_t, iov: []const os.iovec_const) os.WriteError!usize {
        var req_node = Request.Node{
            .data = .{
                .msg = .{
                    .writev = .{
                        .fd = fd,
                        .iov = iov,
                        .result = undefined,
                    },
                },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
        return req_node.data.msg.writev.result;
    }

    /// Performs an async `os.pwritev` using a separate thread.
    /// `fd` must block and not return EAGAIN.
    pub fn pwritev(self: *Loop, fd: os.fd_t, iov: []const os.iovec_const, offset: u64) os.WriteError!usize {
        var req_node = Request.Node{
            .data = .{
                .msg = .{
                    .pwritev = .{
                        .fd = fd,
                        .iov = iov,
                        .offset = offset,
                        .result = undefined,
                    },
                },
                .finish = .{ .TickNode = .{ .data = @frame() } },
            },
        };
        suspend {
            self.posixFsRequest(&req_node);
        }
        return req_node.data.msg.pwritev.result;
    }

    fn workerRun(self: *Loop) void {
        while (true) {
            while (true) {
                const next_tick_node = self.next_tick_queue.get() orelse break;
                self.dispatch();
                resume next_tick_node.data;
                self.finishOneEvent();
            }

            switch (builtin.os.tag) {
                .linux => {
                    // only process 1 event so we don't steal from other threads
                    var events: [1]os.linux.epoll_event = undefined;
                    const count = os.epoll_wait(self.os_data.epollfd, events[0..], -1);
                    for (events[0..count]) |ev| {
                        const resume_node = @intToPtr(*ResumeNode, ev.data.ptr);
                        const handle = resume_node.handle;
                        const resume_node_id = resume_node.id;
                        switch (resume_node_id) {
                            .Basic => {},
                            .Stop => return,
                            .EventFd => {
                                const event_fd_node = @fieldParentPtr(ResumeNode.EventFd, "base", resume_node);
                                event_fd_node.epoll_op = os.EPOLL_CTL_MOD;
                                const stack_node = @fieldParentPtr(std.atomic.Stack(ResumeNode.EventFd).Node, "data", event_fd_node);
                                self.available_eventfd_resume_nodes.push(stack_node);
                            },
                        }
                        resume handle;
                        if (resume_node_id == ResumeNode.Id.EventFd) {
                            self.finishOneEvent();
                        }
                    }
                },
                .macosx, .freebsd, .netbsd, .dragonfly => {
                    var eventlist: [1]os.Kevent = undefined;
                    const empty_kevs = &[0]os.Kevent{};
                    const count = os.kevent(self.os_data.kqfd, empty_kevs, eventlist[0..], null) catch unreachable;
                    for (eventlist[0..count]) |ev| {
                        const resume_node = @intToPtr(*ResumeNode, ev.udata);
                        const handle = resume_node.handle;
                        const resume_node_id = resume_node.id;
                        switch (resume_node_id) {
                            .Basic => {
                                const basic_node = @fieldParentPtr(ResumeNode.Basic, "base", resume_node);
                                basic_node.kev = ev;
                            },
                            .Stop => return,
                            .EventFd => {
                                const event_fd_node = @fieldParentPtr(ResumeNode.EventFd, "base", resume_node);
                                const stack_node = @fieldParentPtr(std.atomic.Stack(ResumeNode.EventFd).Node, "data", event_fd_node);
                                self.available_eventfd_resume_nodes.push(stack_node);
                            },
                        }
                        resume handle;
                        if (resume_node_id == ResumeNode.Id.EventFd) {
                            self.finishOneEvent();
                        }
                    }
                },
                .windows => {
                    var completion_key: usize = undefined;
                    const overlapped = while (true) {
                        var nbytes: windows.DWORD = undefined;
                        var overlapped: ?*windows.OVERLAPPED = undefined;
                        switch (windows.GetQueuedCompletionStatus(self.os_data.io_port, &nbytes, &completion_key, &overlapped, windows.INFINITE)) {
                            .Aborted => return,
                            .Normal => {},
                            .EOF => {},
                            .Cancelled => continue,
                        }
                        if (overlapped) |o| break o;
                    } else unreachable; // TODO else unreachable should not be necessary
                    const resume_node = @fieldParentPtr(ResumeNode, "overlapped", overlapped);
                    const handle = resume_node.handle;
                    const resume_node_id = resume_node.id;
                    switch (resume_node_id) {
                        .Basic => {},
                        .Stop => return,
                        .EventFd => {
                            const event_fd_node = @fieldParentPtr(ResumeNode.EventFd, "base", resume_node);
                            const stack_node = @fieldParentPtr(std.atomic.Stack(ResumeNode.EventFd).Node, "data", event_fd_node);
                            self.available_eventfd_resume_nodes.push(stack_node);
                        },
                    }
                    resume handle;
                    self.finishOneEvent();
                },
                else => @compileError("unsupported OS"),
            }
        }
    }

    fn posixFsRequest(self: *Loop, request_node: *Request.Node) void {
        self.beginOneEvent(); // finished in posixFsRun after processing the msg
        self.os_data.fs_queue.put(request_node);
        switch (builtin.os.tag) {
            .macosx, .freebsd, .netbsd, .dragonfly => {
                const fs_kevs = @as(*const [1]os.Kevent, &self.os_data.fs_kevent_wake);
                const empty_kevs = &[0]os.Kevent{};
                _ = os.kevent(self.os_data.fs_kqfd, fs_kevs, empty_kevs, null) catch unreachable;
            },
            .linux => {
                @atomicStore(i32, &self.os_data.fs_queue_item, 1, AtomicOrder.SeqCst);
                const rc = os.linux.futex_wake(&self.os_data.fs_queue_item, os.linux.FUTEX_WAKE, 1);
                switch (os.linux.getErrno(rc)) {
                    0 => {},
                    os.EINVAL => unreachable,
                    else => unreachable,
                }
            },
            else => @compileError("Unsupported OS"),
        }
    }

    fn posixFsCancel(self: *Loop, request_node: *Request.Node) void {
        if (self.os_data.fs_queue.remove(request_node)) {
            self.finishOneEvent();
        }
    }

    // TODO make this whole function noasync
    // https://github.com/ziglang/zig/issues/3157
    fn posixFsRun(self: *Loop) void {
        while (true) {
            if (builtin.os.tag == .linux) {
                @atomicStore(i32, &self.os_data.fs_queue_item, 0, .SeqCst);
            }
            while (self.os_data.fs_queue.get()) |node| {
                switch (node.data.msg) {
                    .end => return,
                    .read => |*msg| {
                        msg.result = noasync os.read(msg.fd, msg.buf);
                    },
                    .write => |*msg| {
                        msg.result = noasync os.write(msg.fd, msg.bytes);
                    },
                    .writev => |*msg| {
                        msg.result = noasync os.writev(msg.fd, msg.iov);
                    },
                    .pwritev => |*msg| {
                        msg.result = noasync os.pwritev(msg.fd, msg.iov, msg.offset);
                    },
                    .preadv => |*msg| {
                        msg.result = noasync os.preadv(msg.fd, msg.iov, msg.offset);
                    },
                    .open => |*msg| {
                        msg.result = noasync os.openC(msg.path, msg.flags, msg.mode);
                    },
                    .openat => |*msg| {
                        msg.result = noasync os.openatC(msg.fd, msg.path, msg.flags, msg.mode);
                    },
                    .close => |*msg| noasync os.close(msg.fd),
                }
                switch (node.data.finish) {
                    .TickNode => |*tick_node| self.onNextTick(tick_node),
                    .NoAction => {},
                }
                self.finishOneEvent();
            }
            switch (builtin.os.tag) {
                .linux => {
                    const rc = os.linux.futex_wait(&self.os_data.fs_queue_item, os.linux.FUTEX_WAIT, 0, null);
                    switch (os.linux.getErrno(rc)) {
                        0, os.EINTR, os.EAGAIN => continue,
                        else => unreachable,
                    }
                },
                .macosx, .freebsd, .netbsd, .dragonfly => {
                    const fs_kevs = @as(*const [1]os.Kevent, &self.os_data.fs_kevent_wait);
                    var out_kevs: [1]os.Kevent = undefined;
                    _ = os.kevent(self.os_data.fs_kqfd, fs_kevs, out_kevs[0..], null) catch unreachable;
                },
                else => @compileError("Unsupported OS"),
            }
        }
    }

    const OsData = switch (builtin.os.tag) {
        .linux => LinuxOsData,
        .macosx, .freebsd, .netbsd, .dragonfly => KEventData,
        .windows => struct {
            io_port: windows.HANDLE,
            extra_thread_count: usize,
        },
        else => struct {},
    };

    const KEventData = struct {
        kqfd: i32,
        final_kevent: os.Kevent,
        fs_kevent_wake: os.Kevent,
        fs_kevent_wait: os.Kevent,
        fs_thread: *Thread,
        fs_kqfd: i32,
        fs_queue: std.atomic.Queue(Request),
        fs_end_request: Request.Node,
    };

    const LinuxOsData = struct {
        epollfd: i32,
        final_eventfd: i32,
        final_eventfd_event: os.linux.epoll_event,
        fs_thread: *Thread,
        fs_queue_item: i32,
        fs_queue: std.atomic.Queue(Request),
        fs_end_request: Request.Node,
    };

    pub const Request = struct {
        msg: Msg,
        finish: Finish,

        pub const Node = std.atomic.Queue(Request).Node;

        pub const Finish = union(enum) {
            TickNode: Loop.NextTickNode,
            NoAction,
        };

        pub const Msg = union(enum) {
            read: Read,
            write: Write,
            writev: WriteV,
            pwritev: PWriteV,
            preadv: PReadV,
            open: Open,
            openat: OpenAt,
            close: Close,

            /// special - means the fs thread should exit
            end,

            pub const Read = struct {
                fd: os.fd_t,
                buf: []u8,
                result: Error!usize,

                pub const Error = os.ReadError;
            };

            pub const Write = struct {
                fd: os.fd_t,
                bytes: []const u8,
                result: Error!usize,

                pub const Error = os.WriteError;
            };

            pub const WriteV = struct {
                fd: os.fd_t,
                iov: []const os.iovec_const,
                result: Error!usize,

                pub const Error = os.WriteError;
            };

            pub const PWriteV = struct {
                fd: os.fd_t,
                iov: []const os.iovec_const,
                offset: usize,
                result: Error!usize,

                pub const Error = os.PWriteError;
            };

            pub const PReadV = struct {
                fd: os.fd_t,
                iov: []const os.iovec,
                offset: usize,
                result: Error!usize,

                pub const Error = os.PReadError;
            };

            pub const Open = struct {
                path: [*:0]const u8,
                flags: u32,
                mode: os.mode_t,
                result: Error!os.fd_t,

                pub const Error = os.OpenError;
            };

            pub const OpenAt = struct {
                fd: os.fd_t,
                path: [*:0]const u8,
                flags: u32,
                mode: os.mode_t,
                result: Error!os.fd_t,

                pub const Error = os.OpenError;
            };

            pub const Close = struct {
                fd: os.fd_t,
            };
        };
    };
};

test "std.event.Loop - basic" {
    // https://github.com/ziglang/zig/issues/1908
    if (builtin.single_threaded) return error.SkipZigTest;

    var loop: Loop = undefined;
    try loop.initMultiThreaded();
    defer loop.deinit();

    loop.run();
}

async fn testEventLoop() i32 {
    return 1234;
}

async fn testEventLoop2(h: anyframe->i32, did_it: *bool) void {
    const value = await h;
    testing.expect(value == 1234);
    did_it.* = true;
}
