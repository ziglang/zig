const builtin = @import("builtin");
const std = @import("../index.zig");
const event = std.event;
const assert = std.debug.assert;
const os = std.os;
const mem = std.mem;
const posix = os.posix;
const windows = os.windows;
const Loop = event.Loop;

pub const RequestNode = std.atomic.Queue(Request).Node;

pub const Request = struct {
    msg: Msg,
    finish: Finish,

    pub const Finish = union(enum) {
        TickNode: Loop.NextTickNode,
        DeallocCloseOperation: *CloseOperation,
        NoAction,
    };

    pub const Msg = union(enum) {
        PWriteV: PWriteV,
        PReadV: PReadV,
        Open: Open,
        Close: Close,
        WriteFile: WriteFile,
        End, // special - means the fs thread should exit

        pub const PWriteV = struct {
            fd: os.FileHandle,
            iov: []os.posix.iovec_const,
            offset: usize,
            result: Error!void,

            pub const Error = os.File.WriteError;
        };

        pub const PReadV = struct {
            fd: os.FileHandle,
            iov: []os.posix.iovec,
            offset: usize,
            result: Error!usize,

            pub const Error = os.File.ReadError;
        };

        pub const Open = struct {
            /// must be null terminated. TODO https://github.com/ziglang/zig/issues/265
            path: []const u8,
            flags: u32,
            mode: os.File.Mode,
            result: Error!os.FileHandle,

            pub const Error = os.File.OpenError;
        };

        pub const WriteFile = struct {
            /// must be null terminated. TODO https://github.com/ziglang/zig/issues/265
            path: []const u8,
            contents: []const u8,
            mode: os.File.Mode,
            result: Error!void,

            pub const Error = os.File.OpenError || os.File.WriteError;
        };

        pub const Close = struct {
            fd: os.FileHandle,
        };
    };
};

/// data - just the inner references - must live until pwritev promise completes.
pub async fn pwritev(loop: *Loop, fd: os.FileHandle, data: []const []const u8, offset: usize) !void {
    switch (builtin.os) {
        builtin.Os.macosx,
        builtin.Os.linux,
        => return await (async pwritevPosix(loop, fd, data, offset) catch unreachable),
        builtin.Os.windows,
        => return await (async pwritevWindows(loop, fd, data, offset) catch unreachable),
        else => @compileError("Unsupported OS"),
    }
}

/// data - just the inner references - must live until pwritev promise completes.
pub async fn pwritevWindows(loop: *Loop, fd: os.FileHandle, data: []const []const u8, offset: usize) !void {
    if (data.len == 0) return;
    if (data.len == 1) return await (async pwriteWindows(loop, fd, data[0], offset) catch unreachable);

    const data_copy = std.mem.dupe(loop.allocator, []const u8, data);
    defer loop.allocator.free(data_copy);

    var off = offset;
    for (data_copy) |buf| {
        try await (async pwriteWindows(loop, fd, buf, off) catch unreachable);
        off += buf.len;
    }
}

pub async fn pwriteWindows(loop: *Loop, fd: os.FileHandle, data: []const u8, offset: u64) os.WindowsWriteError!void {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
    }

    var resume_node = Loop.ResumeNode.Basic{
        .base = Loop.ResumeNode{
            .id = Loop.ResumeNode.Id.Basic,
            .handle = @handle(),
        },
    };
    const completion_key = @ptrToInt(&resume_node.base);
    _ = try os.windowsCreateIoCompletionPort(fd, loop.os_data.io_port, completion_key, undefined);
    var overlapped = windows.OVERLAPPED{
        .Internal = 0,
        .InternalHigh = 0,
        .Offset = @truncate(u32, offset),
        .OffsetHigh = @truncate(u32, offset >> 32),
        .hEvent = null,
    };
    errdefer {
        _ = windows.CancelIoEx(fd, &overlapped);
    }
    suspend {
        _ = windows.WriteFile(fd, data.ptr, @intCast(windows.DWORD, data.len), null, &overlapped);
    }
    var bytes_transferred: windows.DWORD = undefined;
    if (windows.GetOverlappedResult(fd, &overlapped, &bytes_transferred, windows.FALSE) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.IO_PENDING => unreachable,
            windows.ERROR.INVALID_USER_BUFFER => error.SystemResources,
            windows.ERROR.NOT_ENOUGH_MEMORY => error.SystemResources,
            windows.ERROR.OPERATION_ABORTED => error.OperationAborted,
            windows.ERROR.NOT_ENOUGH_QUOTA => error.SystemResources,
            windows.ERROR.BROKEN_PIPE => error.BrokenPipe,
            else => os.unexpectedErrorWindows(err),
        };
    }
}


/// data - just the inner references - must live until pwritev promise completes.
pub async fn pwritevPosix(loop: *Loop, fd: os.FileHandle, data: []const []const u8, offset: usize) !void {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
    }

    const iovecs = try loop.allocator.alloc(os.posix.iovec_const, data.len);
    defer loop.allocator.free(iovecs);

    for (data) |buf, i| {
        iovecs[i] = os.posix.iovec_const{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        };
    }

    var req_node = RequestNode{
        .prev = null,
        .next = null,
        .data = Request{
            .msg = Request.Msg{
                .PWriteV = Request.Msg.PWriteV{
                    .fd = fd,
                    .iov = iovecs,
                    .offset = offset,
                    .result = undefined,
                },
            },
            .finish = Request.Finish{
                .TickNode = Loop.NextTickNode{
                    .prev = null,
                    .next = null,
                    .data = @handle(),
                },
            },
        },
    };

    errdefer loop.posixFsCancel(&req_node);

    suspend {
        loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.PWriteV.result;
}

/// data - just the inner references - must live until preadv promise completes.
pub async fn preadv(loop: *Loop, fd: os.FileHandle, data: []const []u8, offset: usize) !usize {
    //const data_dupe = try mem.dupe(loop.allocator, []const u8, data);
    //defer loop.allocator.free(data_dupe);

    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
    }

    const iovecs = try loop.allocator.alloc(os.posix.iovec, data.len);
    defer loop.allocator.free(iovecs);

    for (data) |buf, i| {
        iovecs[i] = os.posix.iovec{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        };
    }

    var req_node = RequestNode{
        .prev = null,
        .next = null,
        .data = Request{
            .msg = Request.Msg{
                .PReadV = Request.Msg.PReadV{
                    .fd = fd,
                    .iov = iovecs,
                    .offset = offset,
                    .result = undefined,
                },
            },
            .finish = Request.Finish{
                .TickNode = Loop.NextTickNode{
                    .prev = null,
                    .next = null,
                    .data = @handle(),
                },
            },
        },
    };

    errdefer loop.posixFsCancel(&req_node);

    suspend {
        loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.PReadV.result;
}

pub async fn openPosix(
    loop: *Loop,
    path: []const u8,
    flags: u32,
    mode: os.File.Mode,
) os.File.OpenError!os.FileHandle {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
    }

    const path_with_null = try std.cstr.addNullByte(loop.allocator, path);
    defer loop.allocator.free(path_with_null);

    var req_node = RequestNode{
        .prev = null,
        .next = null,
        .data = Request{
            .msg = Request.Msg{
                .Open = Request.Msg.Open{
                    .path = path_with_null[0..path.len],
                    .flags = flags,
                    .mode = mode,
                    .result = undefined,
                },
            },
            .finish = Request.Finish{
                .TickNode = Loop.NextTickNode{
                    .prev = null,
                    .next = null,
                    .data = @handle(),
                },
            },
        },
    };

    errdefer loop.posixFsCancel(&req_node);

    suspend {
        loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.Open.result;
}

pub async fn openRead(loop: *Loop, path: []const u8) os.File.OpenError!os.FileHandle {
    const flags = posix.O_LARGEFILE | posix.O_RDONLY | posix.O_CLOEXEC;
    return await (async openPosix(loop, path, flags, os.File.default_mode) catch unreachable);
}

/// Creates if does not exist. Truncates the file if it exists.
/// Uses the default mode.
pub async fn openWrite(loop: *Loop, path: []const u8) os.File.OpenError!os.FileHandle {
    return await (async openWriteMode(loop, path, os.File.default_mode) catch unreachable);
}

/// Creates if does not exist. Truncates the file if it exists.
pub async fn openWriteMode(loop: *Loop, path: []const u8, mode: os.File.Mode) os.File.OpenError!os.FileHandle {
    switch (builtin.os) {
        builtin.Os.macosx,
        builtin.Os.linux,
        => {
            const flags = posix.O_LARGEFILE | posix.O_WRONLY | posix.O_CREAT | posix.O_CLOEXEC | posix.O_TRUNC;
            return await (async openPosix(loop, path, flags, os.File.default_mode) catch unreachable);
        },
        builtin.Os.windows,
        => return os.windowsOpen(
            loop.allocator,
            path,
            windows.GENERIC_WRITE,
            windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
            windows.CREATE_ALWAYS,
            windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED,
        ),
        else => @compileError("Unsupported OS"),
    }
}

/// Creates if does not exist. Does not truncate.
pub async fn openReadWrite(
    loop: *Loop,
    path: []const u8,
    mode: os.File.Mode,
) os.File.OpenError!os.FileHandle {
    const flags = posix.O_LARGEFILE | posix.O_RDWR | posix.O_CREAT | posix.O_CLOEXEC;
    return await (async openPosix(loop, path, flags, mode) catch unreachable);
}

/// This abstraction helps to close file handles in defer expressions
/// without the possibility of failure and without the use of suspend points.
/// Start a `CloseOperation` before opening a file, so that you can defer
/// `CloseOperation.finish`.
/// If you call `setHandle` then finishing will close the fd; otherwise finishing
/// will deallocate the `CloseOperation`.
pub const CloseOperation = struct {
    loop: *Loop,
    os_data: OsData,

    const OsData = switch (builtin.os) {
        builtin.Os.linux,
        builtin.Os.macosx,
        => struct {
            have_fd: bool,
            close_req_node: RequestNode,
        },
        builtin.Os.windows,
        => struct {
            handle: ?os.FileHandle,
        },
        else => @compileError("Unsupported OS"),
    };

    pub fn start(loop: *Loop) (error{OutOfMemory}!*CloseOperation) {
        const self = try loop.allocator.createOne(CloseOperation);
        self.* = CloseOperation{
            .loop = loop,
            .os_data = switch (builtin.os) {
                builtin.Os.linux,
                builtin.Os.macosx,
                => OsData{
                    .have_fd = false,
                    .close_req_node = RequestNode{
                        .prev = null,
                        .next = null,
                        .data = Request{
                            .msg = Request.Msg{
                                .Close = Request.Msg.Close{ .fd = undefined },
                            },
                            .finish = Request.Finish{ .DeallocCloseOperation = self },
                        },
                    },
                },
                builtin.Os.windows,
                => OsData{ .handle = null },
                else => @compileError("Unsupported OS"),
            },
        };
        return self;
    }

    /// Defer this after creating.
    pub fn finish(self: *CloseOperation) void {
        switch (builtin.os) {
            builtin.Os.linux,
            builtin.Os.macosx,
            => {
                if (self.have_fd) {
                    self.loop.posixFsRequest(&self.close_req_node);
                } else {
                    self.loop.allocator.destroy(self);
                }
            },
            builtin.Os.windows,
            => {
                if (self.handle) |handle| {
                    os.close(handle);
                }
                self.loop.allocator.destroy(self);
            },
            else => @compileError("Unsupported OS"),
        }
    }

    pub fn setHandle(self: *CloseOperation, handle: os.FileHandle) void {
        switch (builtin.os) {
            builtin.Os.linux,
            builtin.Os.macosx,
            => {
                self.close_req_node.data.msg.Close.fd = handle;
                self.have_fd = true;
            },
            builtin.Os.windows,
            => {
                self.handle = handle;
            },
            else => @compileError("Unsupported OS"),
        }
    }

    /// Undo a `setHandle`.
    pub fn clearHandle(self: *CloseOperation) void {
        switch (builtin.os) {
            builtin.Os.linux,
            builtin.Os.macosx,
            => {
                self.have_fd = false;
            },
            builtin.Os.windows,
            => {
                self.handle = null;
            },
            else => @compileError("Unsupported OS"),
        }
    }

    pub fn getHandle(self: *CloseOperation) os.FileHandle {
        switch (builtin.os) {
            builtin.Os.linux,
            builtin.Os.macosx,
            => {
                assert(self.have_fd);
                return self.close_req_node.data.msg.Close.fd;
            },
            builtin.Os.windows,
            => {
                return self.handle.?;
            },
            else => @compileError("Unsupported OS"),
        }
    }
};

/// contents must remain alive until writeFile completes.
/// TODO make this atomic or provide writeFileAtomic and rename this one to writeFileTruncate
pub async fn writeFile(loop: *Loop, path: []const u8, contents: []const u8) !void {
    return await (async writeFileMode(loop, path, contents, os.File.default_mode) catch unreachable);
}

/// contents must remain alive until writeFile completes.
pub async fn writeFileMode(loop: *Loop, path: []const u8, contents: []const u8, mode: os.File.Mode) !void {
    switch (builtin.os) {
        builtin.Os.linux,
        builtin.Os.macosx,
        => return await (async writeFileModeThread(loop, path, contents, mode) catch unreachable),
        builtin.Os.windows,
        => return await (async writeFileWindows(loop, path, contents) catch unreachable),
        else => @compileError("Unsupported OS"),
    }
}

async fn writeFileWindows(loop: *Loop, path: []const u8, contents: []const u8) !void {
    const handle = try os.windowsOpen(
        loop.allocator,
        path,
        windows.GENERIC_WRITE,
        windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
        windows.CREATE_ALWAYS,
        windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED,
    );
    defer os.close(handle);

    try await (async pwriteWindows(loop, handle, contents, 0) catch unreachable);
}

async fn writeFileModeThread(loop: *Loop, path: []const u8, contents: []const u8, mode: os.File.Mode) !void {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
    }

    const path_with_null = try std.cstr.addNullByte(loop.allocator, path);
    defer loop.allocator.free(path_with_null);

    var req_node = RequestNode{
        .prev = null,
        .next = null,
        .data = Request{
            .msg = Request.Msg{
                .WriteFile = Request.Msg.WriteFile{
                    .path = path_with_null[0..path.len],
                    .contents = contents,
                    .mode = mode,
                    .result = undefined,
                },
            },
            .finish = Request.Finish{
                .TickNode = Loop.NextTickNode{
                    .prev = null,
                    .next = null,
                    .data = @handle(),
                },
            },
        },
    };

    errdefer loop.posixFsCancel(&req_node);

    suspend {
        loop.posixFsRequest(&req_node);
    }

    return req_node.data.msg.WriteFile.result;
}

/// The promise resumes when the last data has been confirmed written, but before the file handle
/// is closed.
/// Caller owns returned memory.
pub async fn readFile(loop: *Loop, file_path: []const u8, max_size: usize) ![]u8 {
    var close_op = try CloseOperation.start(loop);
    defer close_op.finish();

    const path_with_null = try std.cstr.addNullByte(loop.allocator, file_path);
    defer loop.allocator.free(path_with_null);

    const fd = try await (async openRead(loop, path_with_null[0..file_path.len]) catch unreachable);
    close_op.setHandle(fd);

    var list = std.ArrayList(u8).init(loop.allocator);
    defer list.deinit();

    while (true) {
        try list.ensureCapacity(list.len + os.page_size);
        const buf = list.items[list.len..];
        const buf_array = [][]u8{buf};
        const amt = try await (async preadv(loop, fd, buf_array, list.len) catch unreachable);
        list.len += amt;
        if (list.len > max_size) {
            return error.FileTooBig;
        }
        if (amt < buf.len) {
            return list.toOwnedSlice();
        }
    }
}

pub const WatchEventId = enum {
    CloseWrite,
    Delete,
};

pub const WatchEventError = error{
    UserResourceLimitReached,
    SystemResources,
    AccessDenied,
};

pub fn Watch(comptime V: type) type {
    return struct {
        channel: *event.Channel(Event.Error!Event),
        os_data: OsData,

        const OsData = switch (builtin.os) {
            builtin.Os.macosx => struct {
                file_table: FileTable,
                table_lock: event.Lock,

                const FileTable = std.AutoHashMap([]const u8, *Put);
                const Put = struct {
                    putter: promise,
                    value_ptr: *V,
                };
            },
            builtin.Os.linux => struct {
                putter: promise,
                inotify_fd: i32,
                wd_table: WdTable,
                table_lock: event.Lock,

                const FileTable = std.AutoHashMap([]const u8, V);
            },
            else => @compileError("Unsupported OS"),
        };

        const WdTable = std.AutoHashMap(i32, Dir);
        const FileToHandle = std.AutoHashMap([]const u8, promise);

        const Self = this;

        const Dir = struct {
            dirname: []const u8,
            file_table: OsData.FileTable,
        };

        pub const Event = struct {
            id: Id,
            data: V,

            pub const Id = WatchEventId;
            pub const Error = WatchEventError;
        };

        pub fn create(loop: *Loop, event_buf_count: usize) !*Self {
            const channel = try event.Channel(Self.Event.Error!Self.Event).create(loop, event_buf_count);
            errdefer channel.destroy();

            switch (builtin.os) {
                builtin.Os.linux => {
                    const inotify_fd = try os.linuxINotifyInit1(os.linux.IN_NONBLOCK | os.linux.IN_CLOEXEC);
                    errdefer os.close(inotify_fd);

                    var result: *Self = undefined;
                    _ = try async<loop.allocator> linuxEventPutter(inotify_fd, channel, &result);
                    return result;
                },
                builtin.Os.macosx => {
                    const self = try loop.allocator.createOne(Self);
                    errdefer loop.allocator.destroy(self);

                    self.* = Self{
                        .channel = channel,
                        .os_data = OsData{
                            .table_lock = event.Lock.init(loop),
                            .file_table = OsData.FileTable.init(loop.allocator),
                        },
                    };
                    return self;
                },
                else => @compileError("Unsupported OS"),
            }
        }

        pub fn destroy(self: *Self) void {
            switch (builtin.os) {
                builtin.Os.macosx => {
                    self.os_data.table_lock.deinit();
                    var it = self.os_data.file_table.iterator();
                    while (it.next()) |entry| {
                        cancel entry.value.putter;
                        self.channel.loop.allocator.free(entry.key);
                    }
                    self.channel.destroy();
                },
                builtin.Os.linux => cancel self.os_data.putter,
                else => @compileError("Unsupported OS"),
            }
        }

        pub async fn addFile(self: *Self, file_path: []const u8, value: V) !?V {
            switch (builtin.os) {
                builtin.Os.macosx => return await (async addFileMacosx(self, file_path, value) catch unreachable),
                builtin.Os.linux => return await (async addFileLinux(self, file_path, value) catch unreachable),
                else => @compileError("Unsupported OS"),
            }
        }

        async fn addFileMacosx(self: *Self, file_path: []const u8, value: V) !?V {
            const resolved_path = try os.path.resolve(self.channel.loop.allocator, file_path);
            var resolved_path_consumed = false;
            defer if (!resolved_path_consumed) self.channel.loop.allocator.free(resolved_path);

            var close_op = try CloseOperation.start(self.channel.loop);
            var close_op_consumed = false;
            defer if (!close_op_consumed) close_op.finish();

            const flags = posix.O_SYMLINK | posix.O_EVTONLY;
            const mode = 0;
            const fd = try await (async openPosix(self.channel.loop, resolved_path, flags, mode) catch unreachable);
            close_op.setHandle(fd);

            var put_data: *OsData.Put = undefined;
            const putter = try async self.kqPutEvents(close_op, value, &put_data);
            close_op_consumed = true;
            errdefer cancel putter;

            const result = blk: {
                const held = await (async self.os_data.table_lock.acquire() catch unreachable);
                defer held.release();

                const gop = try self.os_data.file_table.getOrPut(resolved_path);
                if (gop.found_existing) {
                    const prev_value = gop.kv.value.value_ptr.*;
                    cancel gop.kv.value.putter;
                    gop.kv.value = put_data;
                    break :blk prev_value;
                } else {
                    resolved_path_consumed = true;
                    gop.kv.value = put_data;
                    break :blk null;
                }
            };

            return result;
        }

        async fn kqPutEvents(self: *Self, close_op: *CloseOperation, value: V, out_put: **OsData.Put) void {
            // TODO https://github.com/ziglang/zig/issues/1194
            suspend {
                resume @handle();
            }

            var value_copy = value;
            var put = OsData.Put{
                .putter = @handle(),
                .value_ptr = &value_copy,
            };
            out_put.* = &put;
            self.channel.loop.beginOneEvent();

            defer {
                close_op.finish();
                self.channel.loop.finishOneEvent();
            }

            while (true) {
                if (await (async self.channel.loop.bsdWaitKev(
                    @intCast(usize, close_op.getHandle()),
                    posix.EVFILT_VNODE,
                    posix.NOTE_WRITE | posix.NOTE_DELETE,
                ) catch unreachable)) |kev| {
                    // TODO handle EV_ERROR
                    if (kev.fflags & posix.NOTE_DELETE != 0) {
                        await (async self.channel.put(Self.Event{
                            .id = Event.Id.Delete,
                            .data = value_copy,
                        }) catch unreachable);
                    } else if (kev.fflags & posix.NOTE_WRITE != 0) {
                        await (async self.channel.put(Self.Event{
                            .id = Event.Id.CloseWrite,
                            .data = value_copy,
                        }) catch unreachable);
                    }
                } else |err| switch (err) {
                    error.EventNotFound => unreachable,
                    error.ProcessNotFound => unreachable,
                    error.AccessDenied, error.SystemResources => {
                        // TODO https://github.com/ziglang/zig/issues/769
                        const casted_err = @errSetCast(error{
                            AccessDenied,
                            SystemResources,
                        }, err);
                        await (async self.channel.put(casted_err) catch unreachable);
                    },
                }
            }
        }

        async fn addFileLinux(self: *Self, file_path: []const u8, value: V) !?V {
            const dirname = os.path.dirname(file_path) orelse ".";
            const dirname_with_null = try std.cstr.addNullByte(self.channel.loop.allocator, dirname);
            var dirname_with_null_consumed = false;
            defer if (!dirname_with_null_consumed) self.channel.loop.allocator.free(dirname_with_null);

            const basename = os.path.basename(file_path);
            const basename_with_null = try std.cstr.addNullByte(self.channel.loop.allocator, basename);
            var basename_with_null_consumed = false;
            defer if (!basename_with_null_consumed) self.channel.loop.allocator.free(basename_with_null);

            const wd = try os.linuxINotifyAddWatchC(
                self.os_data.inotify_fd,
                dirname_with_null.ptr,
                os.linux.IN_CLOSE_WRITE | os.linux.IN_ONLYDIR | os.linux.IN_EXCL_UNLINK,
            );
            // wd is either a newly created watch or an existing one.

            const held = await (async self.os_data.table_lock.acquire() catch unreachable);
            defer held.release();

            const gop = try self.os_data.wd_table.getOrPut(wd);
            if (!gop.found_existing) {
                gop.kv.value = Dir{
                    .dirname = dirname_with_null,
                    .file_table = OsData.FileTable.init(self.channel.loop.allocator),
                };
                dirname_with_null_consumed = true;
            }
            const dir = &gop.kv.value;

            const file_table_gop = try dir.file_table.getOrPut(basename_with_null);
            if (file_table_gop.found_existing) {
                const prev_value = file_table_gop.kv.value;
                file_table_gop.kv.value = value;
                return prev_value;
            } else {
                file_table_gop.kv.value = value;
                basename_with_null_consumed = true;
                return null;
            }
        }

        pub async fn removeFile(self: *Self, file_path: []const u8) ?V {
            @panic("TODO");
        }

        async fn linuxEventPutter(inotify_fd: i32, channel: *event.Channel(Event.Error!Event), out_watch: **Self) void {
            // TODO https://github.com/ziglang/zig/issues/1194
            suspend {
                resume @handle();
            }

            const loop = channel.loop;

            var watch = Self{
                .channel = channel,
                .os_data = OsData{
                    .putter = @handle(),
                    .inotify_fd = inotify_fd,
                    .wd_table = WdTable.init(loop.allocator),
                    .table_lock = event.Lock.init(loop),
                },
            };
            out_watch.* = &watch;

            loop.beginOneEvent();

            defer {
                watch.os_data.table_lock.deinit();
                var wd_it = watch.os_data.wd_table.iterator();
                while (wd_it.next()) |wd_entry| {
                    var file_it = wd_entry.value.file_table.iterator();
                    while (file_it.next()) |file_entry| {
                        loop.allocator.free(file_entry.key);
                    }
                    loop.allocator.free(wd_entry.value.dirname);
                }
                loop.finishOneEvent();
                os.close(inotify_fd);
                channel.destroy();
            }

            var event_buf: [4096]u8 align(@alignOf(os.linux.inotify_event)) = undefined;

            while (true) {
                const rc = os.linux.read(inotify_fd, &event_buf, event_buf.len);
                const errno = os.linux.getErrno(rc);
                switch (errno) {
                    0 => {
                        // can't use @bytesToSlice because of the special variable length name field
                        var ptr = event_buf[0..].ptr;
                        const end_ptr = ptr + event_buf.len;
                        var ev: *os.linux.inotify_event = undefined;
                        while (@ptrToInt(ptr) < @ptrToInt(end_ptr)) : (ptr += @sizeOf(os.linux.inotify_event) + ev.len) {
                            ev = @ptrCast(*os.linux.inotify_event, ptr);
                            if (ev.mask & os.linux.IN_CLOSE_WRITE == os.linux.IN_CLOSE_WRITE) {
                                const basename_ptr = ptr + @sizeOf(os.linux.inotify_event);
                                const basename_with_null = basename_ptr[0 .. std.cstr.len(basename_ptr) + 1];
                                const user_value = blk: {
                                    const held = await (async watch.os_data.table_lock.acquire() catch unreachable);
                                    defer held.release();

                                    const dir = &watch.os_data.wd_table.get(ev.wd).?.value;
                                    if (dir.file_table.get(basename_with_null)) |entry| {
                                        break :blk entry.value;
                                    } else {
                                        break :blk null;
                                    }
                                };
                                if (user_value) |v| {
                                    await (async channel.put(Event{
                                        .id = WatchEventId.CloseWrite,
                                        .data = v,
                                    }) catch unreachable);
                                }
                            }
                        }
                    },
                    os.linux.EINTR => continue,
                    os.linux.EINVAL => unreachable,
                    os.linux.EFAULT => unreachable,
                    os.linux.EAGAIN => {
                        (await (async loop.linuxWaitFd(
                            inotify_fd,
                            os.linux.EPOLLET | os.linux.EPOLLIN,
                        ) catch unreachable)) catch |err| {
                            const transformed_err = switch (err) {
                                error.InvalidFileDescriptor => unreachable,
                                error.FileDescriptorAlreadyPresentInSet => unreachable,
                                error.InvalidSyscall => unreachable,
                                error.OperationCausesCircularLoop => unreachable,
                                error.FileDescriptorNotRegistered => unreachable,
                                error.SystemResources => error.SystemResources,
                                error.UserResourceLimitReached => error.UserResourceLimitReached,
                                error.FileDescriptorIncompatibleWithEpoll => unreachable,
                                error.Unexpected => unreachable,
                            };
                            await (async channel.put(transformed_err) catch unreachable);
                        };
                    },
                    else => unreachable,
                }
            }
        }
    };
}

const test_tmp_dir = "std_event_fs_test";

test "write a file, watch it, write it again" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    // TODO move this into event loop too
    try os.makePath(allocator, test_tmp_dir);
    defer os.deleteTree(allocator, test_tmp_dir) catch {};

    var loop: Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var result: error!void = error.ResultNeverWritten;
    const handle = try async<allocator> testFsWatchCantFail(&loop, &result);
    defer cancel handle;

    loop.run();
    return result;
}

async fn testFsWatchCantFail(loop: *Loop, result: *(error!void)) void {
    result.* = await async testFsWatch(loop) catch unreachable;
}

async fn testFsWatch(loop: *Loop) !void {
    const file_path = try os.path.join(loop.allocator, test_tmp_dir, "file.txt");
    defer loop.allocator.free(file_path);

    const contents =
        \\line 1
        \\line 2
    ;
    const line2_offset = 7;

    // first just write then read the file
    try await try async writeFile(loop, file_path, contents);

    const read_contents = try await try async readFile(loop, file_path, 1024 * 1024);
    assert(mem.eql(u8, read_contents, contents));

    // now watch the file
    var watch = try Watch(void).create(loop, 0);
    defer watch.destroy();

    assert((try await try async watch.addFile(file_path, {})) == null);

    const ev = try async watch.channel.get();
    var ev_consumed = false;
    defer if (!ev_consumed) cancel ev;

    // overwrite line 2
    const fd = try await try async openReadWrite(loop, file_path, os.File.default_mode);
    {
        defer os.close(fd);

        try await try async pwritev(loop, fd, []const []const u8{"lorem ipsum"}, line2_offset);
    }

    ev_consumed = true;
    switch ((try await ev).id) {
        WatchEventId.CloseWrite => {},
        WatchEventId.Delete => @panic("wrong event"),
    }

    const contents_updated = try await try async readFile(loop, file_path, 1024 * 1024);
    assert(mem.eql(u8, contents_updated,
        \\line 1
        \\lorem ipsum
    ));

    // TODO test deleting the file and then re-adding it. we should get events for both
}
