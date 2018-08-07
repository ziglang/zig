const std = @import("../../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;
const fs = std.event.fs;
const os = std.os;
const posix = os.posix;
const windows = os.windows;

pub const Loop = struct {
    allocator: *mem.Allocator,
    next_tick_queue: std.atomic.Queue(promise),
    os_data: OsData,
    final_resume_node: ResumeNode,
    pending_event_count: usize,
    extra_threads: []*os.Thread,

    // pre-allocated eventfds. all permanently active.
    // this is how we send promises to be resumed on other threads.
    available_eventfd_resume_nodes: std.atomic.Stack(ResumeNode.EventFd),
    eventfd_resume_nodes: []std.atomic.Stack(ResumeNode.EventFd).Node,

    pub const OsEventHandle = i32;
    // Type for EventFlags based off of u32
    // TODO create some sort of SET type??
    pub const EventFlagType = u32; 
    pub const EventFlags = struct {
        pub const READ = EventFlagType(1<<0);
        pub const WRITE = EventFlagType(1<<1);
        pub const EXCEPT = EventFlagType(1<<2);
    };

    pub const NextTickNode = std.atomic.Queue(promise).Node;

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
            kevent: posix.Kevent,
        };
    };

    /// After initialization, call run().
    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    pub fn initSingleThreaded(self: *Loop, allocator: *mem.Allocator) !void {
        return self.initInternal(allocator, 1);
    }

    /// The allocator must be thread-safe because we use it for multiplexing
    /// coroutines onto kernel threads.
    /// After initialization, call run().
    /// TODO copy elision / named return values so that the threads referencing *Loop
    /// have the correct pointer value.
    pub fn initMultiThreaded(self: *Loop, allocator: *mem.Allocator) !void {
        const core_count = try os.cpuCount(allocator);
        return self.initInternal(allocator, core_count);
    }

    /// Thread count is the total thread count. The thread pool size will be
    /// max(thread_count - 1, 0)
    fn initInternal(self: *Loop, allocator: *mem.Allocator, thread_count: usize) !void {
        self.* = Loop{
            .pending_event_count = 1,
            .allocator = allocator,
            .os_data = undefined,
            .next_tick_queue = std.atomic.Queue(promise).init(),
            .extra_threads = undefined,
            .available_eventfd_resume_nodes = std.atomic.Stack(ResumeNode.EventFd).init(),
            .eventfd_resume_nodes = undefined,
            .final_resume_node = ResumeNode{
                .id = ResumeNode.Id.Stop,
                .handle = undefined,
            },
        };
        const extra_thread_count = thread_count - 1;
        self.eventfd_resume_nodes = try self.allocator.alloc(
            std.atomic.Stack(ResumeNode.EventFd).Node,
            extra_thread_count,
        );
        errdefer self.allocator.free(self.eventfd_resume_nodes);

        self.extra_threads = try self.allocator.alloc(*os.Thread, extra_thread_count);
        errdefer self.allocator.free(self.extra_threads);

        try self.initOsData(extra_thread_count);
        errdefer self.deinitOsData();
    }

    pub fn deinit(self: *Loop) void {
        self.deinitOsData();
        self.allocator.free(self.extra_threads);
    }

    const InitOsDataError = os.LinuxEpollCreateError || mem.Allocator.Error || os.LinuxEventFdError ||
        os.SpawnThreadError || os.LinuxEpollCtlError || os.BsdKEventError ||
        os.WindowsCreateIoCompletionPortError;

    const wakeup_bytes = []u8{0x1} ** 8;

    fn initOsData(self: *Loop, extra_thread_count: usize) InitOsDataError!void {
        self.os_data.kqfd = try os.bsdKQueue();
        errdefer os.close(self.os_data.kqfd);

        self.os_data.fs_kqfd = try os.bsdKQueue();
        errdefer os.close(self.os_data.fs_kqfd);

        self.os_data.fs_queue = std.atomic.Queue(fs.Request).init();
        // we need another thread for the file system because Darwin does not have an async
        // file system I/O API.
        self.os_data.fs_end_request = fs.RequestNode{
            .prev = undefined,
            .next = undefined,
            .data = fs.Request{
                .msg = fs.Request.Msg.End,
                .finish = fs.Request.Finish.NoAction,
            },
        };

        self.os_data.kevents = try self.allocator.alloc(posix.Kevent, extra_thread_count);
        errdefer self.allocator.free(self.os_data.kevents);

        const empty_kevs = ([*]posix.Kevent)(undefined)[0..0];

        for (self.eventfd_resume_nodes) |*eventfd_node, i| {
            eventfd_node.* = std.atomic.Stack(ResumeNode.EventFd).Node{
                .data = ResumeNode.EventFd{
                    .base = ResumeNode{
                        .id = ResumeNode.Id.EventFd,
                        .handle = undefined,
                    },
                    // this one is for sending events
                    .kevent = posix.Kevent{
                        .ident = i,
                        .filter = posix.EVFILT_USER,
                        .flags = posix.EV_CLEAR | posix.EV_ADD | posix.EV_DISABLE,
                        .fflags = 0,
                        .data = 0,
                        .udata = @ptrToInt(&eventfd_node.data.base),
                    },
                },
                .next = undefined,
            };
            self.available_eventfd_resume_nodes.push(eventfd_node);
            const kevent_array = (*[1]posix.Kevent)(&eventfd_node.data.kevent);
            _ = try os.bsdKEvent(self.os_data.kqfd, kevent_array, empty_kevs, null);
            eventfd_node.data.kevent.flags = posix.EV_CLEAR | posix.EV_ENABLE;
            eventfd_node.data.kevent.fflags = posix.NOTE_TRIGGER;
            // this one is for waiting for events
            self.os_data.kevents[i] = posix.Kevent{
                .ident = i,
                .filter = posix.EVFILT_USER,
                .flags = 0,
                .fflags = 0,
                .data = 0,
                .udata = @ptrToInt(&eventfd_node.data.base),
            };
        }

        // Pre-add so that we cannot get error.SystemResources
        // later when we try to activate it.
        self.os_data.final_kevent = posix.Kevent{
            .ident = extra_thread_count,
            .filter = posix.EVFILT_USER,
            .flags = posix.EV_ADD | posix.EV_DISABLE,
            .fflags = 0,
            .data = 0,
            .udata = @ptrToInt(&self.final_resume_node),
        };
        const final_kev_arr = (*[1]posix.Kevent)(&self.os_data.final_kevent);
        _ = try os.bsdKEvent(self.os_data.kqfd, final_kev_arr, empty_kevs, null);
        self.os_data.final_kevent.flags = posix.EV_ENABLE;
        self.os_data.final_kevent.fflags = posix.NOTE_TRIGGER;

        self.os_data.fs_kevent_wake = posix.Kevent{
            .ident = extra_thread_count + 1,
            .filter = posix.EVFILT_USER,
            .flags = posix.EV_ADD,
            .fflags = posix.NOTE_TRIGGER,
            .data = 0,
            .udata = undefined,
        };

        self.os_data.fs_kevent_wait = posix.Kevent{
            .ident = extra_thread_count + 1,
            .filter = posix.EVFILT_USER,
            .flags = posix.EV_ADD|posix.EV_CLEAR,
            .fflags = 0,
            .data = 0,
            .udata = undefined,
        };

        self.os_data.fs_thread = try os.spawnThread(self, posixFsRun);
        errdefer {
            self.posixFsRequest(&self.os_data.fs_end_request);
            self.os_data.fs_thread.wait();
        }

        var extra_thread_index: usize = 0;
        errdefer {
            _ = os.bsdKEvent(self.os_data.kqfd, final_kev_arr, empty_kevs, null) catch unreachable;
            while (extra_thread_index != 0) {
                extra_thread_index -= 1;
                self.extra_threads[extra_thread_index].wait();
            }
        }
        while (extra_thread_index < extra_thread_count) : (extra_thread_index += 1) {
            self.extra_threads[extra_thread_index] = try os.spawnThread(self, workerRun);
        }
    }

    fn deinitOsData(self: *Loop) void {
        self.allocator.free(self.os_data.kevents);
        os.close(self.os_data.kqfd);
        os.close(self.os_data.fs_kqfd);
    }

    /// resume_node must live longer than the promise that it holds a reference to.
    /// flags must contain EPOLLET
    pub fn addEvHandle(self: *Loop, handle: OsEventHandle, resume_node: *ResumeNode, flags: EventFlagType) !void {
        self.beginOneEvent();
        errdefer self.finishOneEvent();
        //TODO
        return os.LinuxEpollCtlError.Unexpected;
    }

    pub fn removeEvHandle(self: *Loop, handle: OsEventHandle) void {
        //TODO
        self.finishOneEvent();
        @panic("removeEvHandle");
    }

    pub async fn waitEvHandle(self: *Loop, handle: OsEventHandle, flags: u32) !void {
        defer self.removeEvHandle(fd);
        suspend {
            // TODO explicitly put this memory in the coroutine frame #1194
            var resume_node = ResumeNode{
                .id = ResumeNode.Id.Basic,
                .handle = @handle(),
            };
            try self.addEvHandle(handle, &resume_node, flags);
        }
    }

    fn dispatch(self: *Loop) void {
        while (self.available_eventfd_resume_nodes.pop()) |resume_stack_node| {
            const next_tick_node = self.next_tick_queue.get() orelse {
                self.available_eventfd_resume_nodes.push(resume_stack_node);
                return;
            };
            const eventfd_node = &resume_stack_node.data;
            eventfd_node.base.handle = next_tick_node.data;
            const kevent_array = (*[1]posix.Kevent)(&eventfd_node.kevent);
            const empty_kevs = ([*]posix.Kevent)(undefined)[0..0];
            _ = os.bsdKEvent(self.os_data.kqfd, kevent_array, empty_kevs, null) catch {
                self.next_tick_queue.unget(next_tick_node);
                self.available_eventfd_resume_nodes.push(resume_stack_node);
                return;
            };
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

        self.os_data.fs_thread.wait();

        for (self.extra_threads) |extra_thread| {
            extra_thread.wait();
        }
    }

    /// This is equivalent to an async call, except instead of beginning execution of the async function,
    /// it immediately returns to the caller, and the async function is queued in the event loop. It still
    /// returns a promise to be awaited.
    pub fn call(self: *Loop, comptime func: var, args: ...) !(promise->@typeOf(func).ReturnType) {
        const S = struct {
            async fn asyncFunc(loop: *Loop, handle: *promise->@typeOf(func).ReturnType, args2: ...) @typeOf(func).ReturnType {
                suspend {
                    handle.* = @handle();
                    var my_tick_node = Loop.NextTickNode{
                        .prev = undefined,
                        .next = undefined,
                        .data = @handle(),
                    };
                    loop.onNextTick(&my_tick_node);
                }
                // TODO guaranteed allocation elision for await in same func as async
                return await (async func(args2) catch unreachable);
            }
        };
        var handle: promise->@typeOf(func).ReturnType = undefined;
        return async<self.allocator> S.asyncFunc(self, &handle, args);
    }

    /// Awaiting a yield lets the event loop run, starting any unstarted async operations.
    /// Note that async operations automatically start when a function yields for any other reason,
    /// for example, when async I/O is performed. This function is intended to be used only when
    /// CPU bound tasks would be waiting in the event loop but never get started because no async I/O
    /// is performed.
    pub async fn yield(self: *Loop) void {
        suspend {
            var my_tick_node = Loop.NextTickNode{
                .prev = undefined,
                .next = undefined,
                .data = @handle(),
            };
            self.onNextTick(&my_tick_node);
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
            self.posixFsRequest(&self.os_data.fs_end_request);
            const final_kevent = (*[1]posix.Kevent)(&self.os_data.final_kevent);
            const empty_kevs = ([*]posix.Kevent)(undefined)[0..0];
            // cannot fail because we already added it and this just enables it
            _ = os.bsdKEvent(self.os_data.kqfd, final_kevent, empty_kevs, null) catch unreachable;
            return;
        }
    }

    fn workerRun(self: *Loop) void {
        while (true) {
            while (true) {
                const next_tick_node = self.next_tick_queue.get() orelse break;
                self.dispatch();
                resume next_tick_node.data;
                self.finishOneEvent();
            }
            var eventlist: [1]posix.Kevent = undefined;
            const count = os.bsdKEvent(self.os_data.kqfd, self.os_data.kevents, eventlist[0..], null) catch unreachable;
            for (eventlist[0..count]) |ev| {
                const resume_node = @intToPtr(*ResumeNode, ev.udata);
                const handle = resume_node.handle;
                const resume_node_id = resume_node.id;
                switch (resume_node_id) {
                    ResumeNode.Id.Basic => {},
                    ResumeNode.Id.Stop => return,
                    ResumeNode.Id.EventFd => {
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
        }
    }

    pub fn posixFsRequest(self: *Loop, request_node: *fs.RequestNode) void {
        self.beginOneEvent(); // finished in posixFsRun after processing the msg
        self.os_data.fs_queue.put(request_node);
        //
        const fs_kevs = (*[1]posix.Kevent)(&self.os_data.fs_kevent_wake);
        const empty_kevs = ([*]posix.Kevent)(undefined)[0..0];
        _ = os.bsdKEvent(self.os_data.fs_kqfd, fs_kevs, empty_kevs, null) catch unreachable;
        //
    }

    fn posixFsRun(self: *Loop) void {
        var processed_count: i32 = 0; // we let this wrap
        while (true) {
            while (self.os_data.fs_queue.get()) |node| {
                processed_count +%= 1;
                switch (node.data.msg) {
                    @TagType(fs.Request.Msg).End => return,
                    @TagType(fs.Request.Msg).PWriteV => |*msg| {
                        msg.result = os.posix_pwritev(msg.fd, msg.iov.ptr, msg.iov.len, msg.offset);
                    },
                    @TagType(fs.Request.Msg).PReadV => |*msg| {
                        msg.result = os.posix_preadv(msg.fd, msg.iov.ptr, msg.iov.len, msg.offset);
                    },
                    @TagType(fs.Request.Msg).OpenRead => |*msg| {
                        const flags = posix.O_LARGEFILE | posix.O_RDONLY | posix.O_CLOEXEC;
                        msg.result = os.posixOpenC(msg.path.ptr, flags, 0);
                    },
                    @TagType(fs.Request.Msg).OpenRW => |*msg| {
                        const flags = posix.O_LARGEFILE | posix.O_RDWR | posix.O_CREAT | posix.O_CLOEXEC;
                        msg.result = os.posixOpenC(msg.path.ptr, flags, msg.mode);
                    },
                    @TagType(fs.Request.Msg).Close => |*msg| os.close(msg.fd),
                    @TagType(fs.Request.Msg).WriteFile => |*msg| blk: {
                        const flags = posix.O_LARGEFILE | posix.O_WRONLY | posix.O_CREAT |
                            posix.O_CLOEXEC | posix.O_TRUNC;
                        const fd = os.posixOpenC(msg.path.ptr, flags, msg.mode) catch |err| {
                            msg.result = err;
                            break :blk;
                        };
                        defer os.close(fd);
                        msg.result = os.posixWrite(fd, msg.contents);
                    },
                }
                switch (node.data.finish) {
                    @TagType(fs.Request.Finish).TickNode => |*tick_node| self.onNextTick(tick_node),
                    @TagType(fs.Request.Finish).DeallocCloseOperation => |close_op| {
                        self.allocator.destroy(close_op);
                    },
                    @TagType(fs.Request.Finish).NoAction => {},
                }
                self.finishOneEvent();
            }
            const fs_kevs = (*[1]posix.Kevent)(&self.os_data.fs_kevent_wait);
            var out_kevs: [1]posix.Kevent = undefined;
            _ = os.bsdKEvent(self.os_data.fs_kqfd, fs_kevs, out_kevs[0..], null) catch unreachable;
        }
    }

    const OsData = struct {
        kqfd: i32,
        final_kevent: posix.Kevent,
        kevents: []posix.Kevent,
        fs_kevent_wake: posix.Kevent,
        fs_kevent_wait: posix.Kevent,
        fs_thread: *os.Thread,
        fs_kqfd: i32,
        fs_queue: std.atomic.Queue(fs.Request),
        fs_end_request: fs.RequestNode,
    };
};
