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
            iov: []const os.posix.iovec_const,
            offset: usize,
            result: Error!void,

            pub const Error = os.PosixWriteError;
        };

        pub const PReadV = struct {
            fd: os.FileHandle,
            iov: []const os.posix.iovec,
            offset: usize,
            result: Error!usize,

            pub const Error = os.PosixReadError;
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

pub const PWriteVError = error{OutOfMemory} || os.File.WriteError;

/// data - just the inner references - must live until pwritev promise completes.
pub async fn pwritev(loop: *Loop, fd: os.FileHandle, data: []const []const u8, offset: usize) PWriteVError!void {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
    }
    switch (builtin.os) {
        builtin.Os.macosx,
        builtin.Os.linux,
        builtin.Os.freebsd,
        => {
            const iovecs = try loop.allocator.alloc(os.posix.iovec_const, data.len);
            defer loop.allocator.free(iovecs);

            for (data) |buf, i| {
                iovecs[i] = os.posix.iovec_const{
                    .iov_base = buf.ptr,
                    .iov_len = buf.len,
                };
            }

            return await (async pwritevPosix(loop, fd, iovecs, offset) catch unreachable);
        },
        builtin.Os.windows => {
            const data_copy = try std.mem.dupe(loop.allocator, []const u8, data);
            defer loop.allocator.free(data_copy);
            return await (async pwritevWindows(loop, fd, data, offset) catch unreachable);
        },
        else => @compileError("Unsupported OS"),
    }
}

/// data must outlive the returned promise
pub async fn pwritevWindows(loop: *Loop, fd: os.FileHandle, data: []const []const u8, offset: usize) os.WindowsWriteError!void {
    if (data.len == 0) return;
    if (data.len == 1) return await (async pwriteWindows(loop, fd, data[0], offset) catch unreachable);

    // TODO do these in parallel
    var off = offset;
    for (data) |buf| {
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
            .overlapped = windows.OVERLAPPED{
                .Internal = 0,
                .InternalHigh = 0,
                .Offset = @truncate(u32, offset),
                .OffsetHigh = @truncate(u32, offset >> 32),
                .hEvent = null,
            },
        },
    };
    // TODO only call create io completion port once per fd
    _ = windows.CreateIoCompletionPort(fd, loop.os_data.io_port, undefined, undefined);
    loop.beginOneEvent();
    errdefer loop.finishOneEvent();

    errdefer {
        _ = windows.CancelIoEx(fd, &resume_node.base.overlapped);
    }
    suspend {
        _ = windows.WriteFile(fd, data.ptr, @intCast(windows.DWORD, data.len), null, &resume_node.base.overlapped);
    }
    var bytes_transferred: windows.DWORD = undefined;
    if (windows.GetOverlappedResult(fd, &resume_node.base.overlapped, &bytes_transferred, windows.FALSE) == 0) {
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

/// iovecs must live until pwritev promise completes.
pub async fn pwritevPosix(
    loop: *Loop,
    fd: os.FileHandle,
    iovecs: []const posix.iovec_const,
    offset: usize,
) os.PosixWriteError!void {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
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

pub const PReadVError = error{OutOfMemory} || os.File.ReadError;

/// data - just the inner references - must live until preadv promise completes.
pub async fn preadv(loop: *Loop, fd: os.FileHandle, data: []const []u8, offset: usize) PReadVError!usize {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
    }

    assert(data.len != 0);
    switch (builtin.os) {
        builtin.Os.macosx,
        builtin.Os.linux,
        builtin.Os.freebsd,
        => {
            const iovecs = try loop.allocator.alloc(os.posix.iovec, data.len);
            defer loop.allocator.free(iovecs);

            for (data) |buf, i| {
                iovecs[i] = os.posix.iovec{
                    .iov_base = buf.ptr,
                    .iov_len = buf.len,
                };
            }

            return await (async preadvPosix(loop, fd, iovecs, offset) catch unreachable);
        },
        builtin.Os.windows => {
            const data_copy = try std.mem.dupe(loop.allocator, []u8, data);
            defer loop.allocator.free(data_copy);
            return await (async preadvWindows(loop, fd, data_copy, offset) catch unreachable);
        },
        else => @compileError("Unsupported OS"),
    }
}

/// data must outlive the returned promise
pub async fn preadvWindows(loop: *Loop, fd: os.FileHandle, data: []const []u8, offset: u64) os.WindowsReadError!usize {
    assert(data.len != 0);
    if (data.len == 1) return await (async preadWindows(loop, fd, data[0], offset) catch unreachable);

    // TODO do these in parallel?
    var off: usize = 0;
    var iov_i: usize = 0;
    var inner_off: usize = 0;
    while (true) {
        const v = data[iov_i];
        const amt_read = try await (async preadWindows(loop, fd, v[inner_off .. v.len - inner_off], offset + off) catch unreachable);
        off += amt_read;
        inner_off += amt_read;
        if (inner_off == v.len) {
            iov_i += 1;
            inner_off = 0;
            if (iov_i == data.len) {
                return off;
            }
        }
        if (amt_read == 0) return off; // EOF
    }
}

pub async fn preadWindows(loop: *Loop, fd: os.FileHandle, data: []u8, offset: u64) !usize {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
    }

    var resume_node = Loop.ResumeNode.Basic{
        .base = Loop.ResumeNode{
            .id = Loop.ResumeNode.Id.Basic,
            .handle = @handle(),
            .overlapped = windows.OVERLAPPED{
                .Internal = 0,
                .InternalHigh = 0,
                .Offset = @truncate(u32, offset),
                .OffsetHigh = @truncate(u32, offset >> 32),
                .hEvent = null,
            },
        },
    };
    // TODO only call create io completion port once per fd
    _ = windows.CreateIoCompletionPort(fd, loop.os_data.io_port, undefined, undefined);
    loop.beginOneEvent();
    errdefer loop.finishOneEvent();

    errdefer {
        _ = windows.CancelIoEx(fd, &resume_node.base.overlapped);
    }
    suspend {
        _ = windows.ReadFile(fd, data.ptr, @intCast(windows.DWORD, data.len), null, &resume_node.base.overlapped);
    }
    var bytes_transferred: windows.DWORD = undefined;
    if (windows.GetOverlappedResult(fd, &resume_node.base.overlapped, &bytes_transferred, windows.FALSE) == 0) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.IO_PENDING => unreachable,
            windows.ERROR.OPERATION_ABORTED => return error.OperationAborted,
            windows.ERROR.BROKEN_PIPE => return error.BrokenPipe,
            windows.ERROR.HANDLE_EOF => return usize(bytes_transferred),
            else => return os.unexpectedErrorWindows(err),
        }
    }
    return usize(bytes_transferred);
}

/// iovecs must live until preadv promise completes
pub async fn preadvPosix(
    loop: *Loop,
    fd: os.FileHandle,
    iovecs: []const posix.iovec,
    offset: usize,
) os.PosixReadError!usize {
    // workaround for https://github.com/ziglang/zig/issues/1194
    suspend {
        resume @handle();
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

    const path_c = try std.os.toPosixPath(path);

    var req_node = RequestNode{
        .prev = null,
        .next = null,
        .data = Request{
            .msg = Request.Msg{
                .Open = Request.Msg.Open{
                    .path = path_c[0..path.len],
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
    switch (builtin.os) {
        builtin.Os.macosx, builtin.Os.linux, builtin.Os.freebsd => {
            const flags = posix.O_LARGEFILE | posix.O_RDONLY | posix.O_CLOEXEC;
            return await (async openPosix(loop, path, flags, os.File.default_mode) catch unreachable);
        },

        builtin.Os.windows => return os.windowsOpen(
            path,
            windows.GENERIC_READ,
            windows.FILE_SHARE_READ,
            windows.OPEN_EXISTING,
            windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED,
        ),

        else => @compileError("Unsupported OS"),
    }
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
        builtin.Os.freebsd,
        => {
            const flags = posix.O_LARGEFILE | posix.O_WRONLY | posix.O_CREAT | posix.O_CLOEXEC | posix.O_TRUNC;
            return await (async openPosix(loop, path, flags, os.File.default_mode) catch unreachable);
        },
        builtin.Os.windows => return os.windowsOpen(
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
    switch (builtin.os) {
        builtin.Os.macosx, builtin.Os.linux, builtin.Os.freebsd => {
            const flags = posix.O_LARGEFILE | posix.O_RDWR | posix.O_CREAT | posix.O_CLOEXEC;
            return await (async openPosix(loop, path, flags, mode) catch unreachable);
        },

        builtin.Os.windows => return os.windowsOpen(
            path,
            windows.GENERIC_WRITE | windows.GENERIC_READ,
            windows.FILE_SHARE_WRITE | windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE,
            windows.OPEN_ALWAYS,
            windows.FILE_ATTRIBUTE_NORMAL | windows.FILE_FLAG_OVERLAPPED,
        ),

        else => @compileError("Unsupported OS"),
    }
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
        builtin.Os.linux, builtin.Os.macosx, builtin.Os.freebsd => OsDataPosix,

        builtin.Os.windows => struct {
            handle: ?os.FileHandle,
        },

        else => @compileError("Unsupported OS"),
    };

    const OsDataPosix = struct {
        have_fd: bool,
        close_req_node: RequestNode,
    };

    pub fn start(loop: *Loop) (error{OutOfMemory}!*CloseOperation) {
        const self = try loop.allocator.createOne(CloseOperation);
        self.* = CloseOperation{
            .loop = loop,
            .os_data = switch (builtin.os) {
                builtin.Os.linux, builtin.Os.macosx, builtin.Os.freebsd => initOsDataPosix(self),
                builtin.Os.windows => OsData{ .handle = null },
                else => @compileError("Unsupported OS"),
            },
        };
        return self;
    }

    fn initOsDataPosix(self: *CloseOperation) OsData {
        return OsData{
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
        };
    }

    /// Defer this after creating.
    pub fn finish(self: *CloseOperation) void {
        switch (builtin.os) {
            builtin.Os.linux,
            builtin.Os.macosx,
            builtin.Os.freebsd,
            => {
                if (self.os_data.have_fd) {
                    self.loop.posixFsRequest(&self.os_data.close_req_node);
                } else {
                    self.loop.allocator.destroy(self);
                }
            },
            builtin.Os.windows => {
                if (self.os_data.handle) |handle| {
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
            builtin.Os.freebsd,
            => {
                self.os_data.close_req_node.data.msg.Close.fd = handle;
                self.os_data.have_fd = true;
            },
            builtin.Os.windows => {
                self.os_data.handle = handle;
            },
            else => @compileError("Unsupported OS"),
        }
    }

    /// Undo a `setHandle`.
    pub fn clearHandle(self: *CloseOperation) void {
        switch (builtin.os) {
            builtin.Os.linux,
            builtin.Os.macosx,
            builtin.Os.freebsd,
            => {
                self.os_data.have_fd = false;
            },
            builtin.Os.windows => {
                self.os_data.handle = null;
            },
            else => @compileError("Unsupported OS"),
        }
    }

    pub fn getHandle(self: *CloseOperation) os.FileHandle {
        switch (builtin.os) {
            builtin.Os.linux,
            builtin.Os.macosx,
            builtin.Os.freebsd,
            => {
                assert(self.os_data.have_fd);
                return self.os_data.close_req_node.data.msg.Close.fd;
            },
            builtin.Os.windows => {
                return self.os_data.handle.?;
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
        builtin.Os.freebsd,
        => return await (async writeFileModeThread(loop, path, contents, mode) catch unreachable),
        builtin.Os.windows => return await (async writeFileWindows(loop, path, contents) catch unreachable),
        else => @compileError("Unsupported OS"),
    }
}

async fn writeFileWindows(loop: *Loop, path: []const u8, contents: []const u8) !void {
    const handle = try os.windowsOpen(
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

    const fd = try await (async openRead(loop, file_path) catch unreachable);
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
    Unexpected, // TODO remove this possibility
};

pub fn Watch(comptime V: type) type {
    return struct {
        channel: *event.Channel(Event.Error!Event),
        os_data: OsData,

        const OsData = switch (builtin.os) {
            builtin.Os.macosx, builtin.Os.freebsd => struct {
                file_table: FileTable,
                table_lock: event.Lock,

                const FileTable = std.AutoHashMap([]const u8, *Put);
                const Put = struct {
                    putter: promise,
                    value_ptr: *V,
                };
            },

            builtin.Os.linux => LinuxOsData,
            builtin.Os.windows => WindowsOsData,

            else => @compileError("Unsupported OS"),
        };

        const WindowsOsData = struct {
            table_lock: event.Lock,
            dir_table: DirTable,
            all_putters: std.atomic.Queue(promise),
            ref_count: std.atomic.Int(usize),

            const DirTable = std.AutoHashMap([]const u8, *Dir);
            const FileTable = std.AutoHashMap([]const u16, V);

            const Dir = struct {
                putter: promise,
                file_table: FileTable,
                table_lock: event.Lock,
            };
        };

        const LinuxOsData = struct {
            putter: promise,
            inotify_fd: i32,
            wd_table: WdTable,
            table_lock: event.Lock,

            const WdTable = std.AutoHashMap(i32, Dir);
            const FileTable = std.AutoHashMap([]const u8, V);

            const Dir = struct {
                dirname: []const u8,
                file_table: FileTable,
            };
        };

        const FileToHandle = std.AutoHashMap([]const u8, promise);

        const Self = @This();

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

                builtin.Os.windows => {
                    const self = try loop.allocator.createOne(Self);
                    errdefer loop.allocator.destroy(self);
                    self.* = Self{
                        .channel = channel,
                        .os_data = OsData{
                            .table_lock = event.Lock.init(loop),
                            .dir_table = OsData.DirTable.init(loop.allocator),
                            .ref_count = std.atomic.Int(usize).init(1),
                            .all_putters = std.atomic.Queue(promise).init(),
                        },
                    };
                    return self;
                },

                builtin.Os.macosx, builtin.Os.freebsd => {
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

        /// All addFile calls and removeFile calls must have completed.
        pub fn destroy(self: *Self) void {
            switch (builtin.os) {
                builtin.Os.macosx, builtin.Os.freebsd => {
                    // TODO we need to cancel the coroutines before destroying the lock
                    self.os_data.table_lock.deinit();
                    var it = self.os_data.file_table.iterator();
                    while (it.next()) |entry| {
                        cancel entry.value.putter;
                        self.channel.loop.allocator.free(entry.key);
                    }
                    self.channel.destroy();
                },
                builtin.Os.linux => cancel self.os_data.putter,
                builtin.Os.windows => {
                    while (self.os_data.all_putters.get()) |putter_node| {
                        cancel putter_node.data;
                    }
                    self.deref();
                },
                else => @compileError("Unsupported OS"),
            }
        }

        fn ref(self: *Self) void {
            _ = self.os_data.ref_count.incr();
        }

        fn deref(self: *Self) void {
            if (self.os_data.ref_count.decr() == 1) {
                const allocator = self.channel.loop.allocator;
                self.os_data.table_lock.deinit();
                var it = self.os_data.dir_table.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key);
                    allocator.destroy(entry.value);
                }
                self.os_data.dir_table.deinit();
                self.channel.destroy();
                allocator.destroy(self);
            }
        }

        pub async fn addFile(self: *Self, file_path: []const u8, value: V) !?V {
            switch (builtin.os) {
                builtin.Os.macosx, builtin.Os.freebsd => return await (async addFileKEvent(self, file_path, value) catch unreachable),
                builtin.Os.linux => return await (async addFileLinux(self, file_path, value) catch unreachable),
                builtin.Os.windows => return await (async addFileWindows(self, file_path, value) catch unreachable),
                else => @compileError("Unsupported OS"),
            }
        }

        async fn addFileKEvent(self: *Self, file_path: []const u8, value: V) !?V {
            const resolved_path = try os.path.resolve(self.channel.loop.allocator, file_path);
            var resolved_path_consumed = false;
            defer if (!resolved_path_consumed) self.channel.loop.allocator.free(resolved_path);

            var close_op = try CloseOperation.start(self.channel.loop);
            var close_op_consumed = false;
            defer if (!close_op_consumed) close_op.finish();

            const flags = switch (builtin.os) {
                builtin.Os.macosx => posix.O_SYMLINK | posix.O_EVTONLY,
                else => 0,
            };
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
            const value_copy = value;

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
                gop.kv.value = OsData.Dir{
                    .dirname = dirname_with_null,
                    .file_table = OsData.FileTable.init(self.channel.loop.allocator),
                };
                dirname_with_null_consumed = true;
            }
            const dir = &gop.kv.value;

            const file_table_gop = try dir.file_table.getOrPut(basename_with_null);
            if (file_table_gop.found_existing) {
                const prev_value = file_table_gop.kv.value;
                file_table_gop.kv.value = value_copy;
                return prev_value;
            } else {
                file_table_gop.kv.value = value_copy;
                basename_with_null_consumed = true;
                return null;
            }
        }

        async fn addFileWindows(self: *Self, file_path: []const u8, value: V) !?V {
            const value_copy = value;
            // TODO we might need to convert dirname and basename to canonical file paths ("short"?)

            const dirname = try std.mem.dupe(self.channel.loop.allocator, u8, os.path.dirname(file_path) orelse ".");
            var dirname_consumed = false;
            defer if (!dirname_consumed) self.channel.loop.allocator.free(dirname);

            const dirname_utf16le = try std.unicode.utf8ToUtf16LeWithNull(self.channel.loop.allocator, dirname);
            defer self.channel.loop.allocator.free(dirname_utf16le);

            // TODO https://github.com/ziglang/zig/issues/265
            const basename = os.path.basename(file_path);
            const basename_utf16le_null = try std.unicode.utf8ToUtf16LeWithNull(self.channel.loop.allocator, basename);
            var basename_utf16le_null_consumed = false;
            defer if (!basename_utf16le_null_consumed) self.channel.loop.allocator.free(basename_utf16le_null);
            const basename_utf16le_no_null = basename_utf16le_null[0 .. basename_utf16le_null.len - 1];

            const dir_handle = windows.CreateFileW(
                dirname_utf16le.ptr,
                windows.FILE_LIST_DIRECTORY,
                windows.FILE_SHARE_READ | windows.FILE_SHARE_DELETE | windows.FILE_SHARE_WRITE,
                null,
                windows.OPEN_EXISTING,
                windows.FILE_FLAG_BACKUP_SEMANTICS | windows.FILE_FLAG_OVERLAPPED,
                null,
            );
            if (dir_handle == windows.INVALID_HANDLE_VALUE) {
                const err = windows.GetLastError();
                switch (err) {
                    windows.ERROR.FILE_NOT_FOUND => return error.FileNotFound,
                    windows.ERROR.PATH_NOT_FOUND => return error.FileNotFound,
                    else => return os.unexpectedErrorWindows(err),
                }
            }
            var dir_handle_consumed = false;
            defer if (!dir_handle_consumed) os.close(dir_handle);

            const held = await (async self.os_data.table_lock.acquire() catch unreachable);
            defer held.release();

            const gop = try self.os_data.dir_table.getOrPut(dirname);
            if (gop.found_existing) {
                const dir = gop.kv.value;
                const held_dir_lock = await (async dir.table_lock.acquire() catch unreachable);
                defer held_dir_lock.release();

                const file_gop = try dir.file_table.getOrPut(basename_utf16le_no_null);
                if (file_gop.found_existing) {
                    const prev_value = file_gop.kv.value;
                    file_gop.kv.value = value_copy;
                    return prev_value;
                } else {
                    file_gop.kv.value = value_copy;
                    basename_utf16le_null_consumed = true;
                    return null;
                }
            } else {
                errdefer _ = self.os_data.dir_table.remove(dirname);
                const dir = try self.channel.loop.allocator.createOne(OsData.Dir);
                errdefer self.channel.loop.allocator.destroy(dir);

                dir.* = OsData.Dir{
                    .file_table = OsData.FileTable.init(self.channel.loop.allocator),
                    .table_lock = event.Lock.init(self.channel.loop),
                    .putter = undefined,
                };
                gop.kv.value = dir;
                assert((try dir.file_table.put(basename_utf16le_no_null, value_copy)) == null);
                basename_utf16le_null_consumed = true;

                dir.putter = try async self.windowsDirReader(dir_handle, dir);
                dir_handle_consumed = true;

                dirname_consumed = true;

                return null;
            }
        }

        async fn windowsDirReader(self: *Self, dir_handle: windows.HANDLE, dir: *OsData.Dir) void {
            // TODO https://github.com/ziglang/zig/issues/1194
            suspend {
                resume @handle();
            }

            self.ref();
            defer self.deref();

            defer os.close(dir_handle);

            var putter_node = std.atomic.Queue(promise).Node{
                .data = @handle(),
                .prev = null,
                .next = null,
            };
            self.os_data.all_putters.put(&putter_node);
            defer _ = self.os_data.all_putters.remove(&putter_node);

            var resume_node = Loop.ResumeNode.Basic{
                .base = Loop.ResumeNode{
                    .id = Loop.ResumeNode.Id.Basic,
                    .handle = @handle(),
                    .overlapped = windows.OVERLAPPED{
                        .Internal = 0,
                        .InternalHigh = 0,
                        .Offset = 0,
                        .OffsetHigh = 0,
                        .hEvent = null,
                    },
                },
            };
            var event_buf: [4096]u8 align(@alignOf(windows.FILE_NOTIFY_INFORMATION)) = undefined;

            // TODO handle this error not in the channel but in the setup
            _ = os.windowsCreateIoCompletionPort(
                dir_handle,
                self.channel.loop.os_data.io_port,
                undefined,
                undefined,
            ) catch |err| {
                await (async self.channel.put(err) catch unreachable);
                return;
            };

            while (true) {
                {
                    // TODO only 1 beginOneEvent for the whole coroutine
                    self.channel.loop.beginOneEvent();
                    errdefer self.channel.loop.finishOneEvent();
                    errdefer {
                        _ = windows.CancelIoEx(dir_handle, &resume_node.base.overlapped);
                    }
                    suspend {
                        _ = windows.ReadDirectoryChangesW(
                            dir_handle,
                            &event_buf,
                            @intCast(windows.DWORD, event_buf.len),
                            windows.FALSE, // watch subtree
                            windows.FILE_NOTIFY_CHANGE_FILE_NAME | windows.FILE_NOTIFY_CHANGE_DIR_NAME |
                                windows.FILE_NOTIFY_CHANGE_ATTRIBUTES | windows.FILE_NOTIFY_CHANGE_SIZE |
                                windows.FILE_NOTIFY_CHANGE_LAST_WRITE | windows.FILE_NOTIFY_CHANGE_LAST_ACCESS |
                                windows.FILE_NOTIFY_CHANGE_CREATION | windows.FILE_NOTIFY_CHANGE_SECURITY,
                            null, // number of bytes transferred (unused for async)
                            &resume_node.base.overlapped,
                            null, // completion routine - unused because we use IOCP
                        );
                    }
                }
                var bytes_transferred: windows.DWORD = undefined;
                if (windows.GetOverlappedResult(dir_handle, &resume_node.base.overlapped, &bytes_transferred, windows.FALSE) == 0) {
                    const errno = windows.GetLastError();
                    const err = switch (errno) {
                        else => os.unexpectedErrorWindows(errno),
                    };
                    await (async self.channel.put(err) catch unreachable);
                } else {
                    // can't use @bytesToSlice because of the special variable length name field
                    var ptr = event_buf[0..].ptr;
                    const end_ptr = ptr + bytes_transferred;
                    var ev: *windows.FILE_NOTIFY_INFORMATION = undefined;
                    while (@ptrToInt(ptr) < @ptrToInt(end_ptr)) : (ptr += ev.NextEntryOffset) {
                        ev = @ptrCast(*windows.FILE_NOTIFY_INFORMATION, ptr);
                        const emit = switch (ev.Action) {
                            windows.FILE_ACTION_REMOVED => WatchEventId.Delete,
                            windows.FILE_ACTION_MODIFIED => WatchEventId.CloseWrite,
                            else => null,
                        };
                        if (emit) |id| {
                            const basename_utf16le = ([*]u16)(&ev.FileName)[0 .. ev.FileNameLength / 2];
                            const user_value = blk: {
                                const held = await (async dir.table_lock.acquire() catch unreachable);
                                defer held.release();

                                if (dir.file_table.get(basename_utf16le)) |entry| {
                                    break :blk entry.value;
                                } else {
                                    break :blk null;
                                }
                            };
                            if (user_value) |v| {
                                await (async self.channel.put(Event{
                                    .id = id,
                                    .data = v,
                                }) catch unreachable);
                            }
                        }
                        if (ev.NextEntryOffset == 0) break;
                    }
                }
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
                    .wd_table = OsData.WdTable.init(loop.allocator),
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
                                error.FileDescriptorAlreadyPresentInSet => unreachable,
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
    if (builtin.os == builtin.Os.windows) {
        // TODO this test is disabled on windows until the coroutine rewrite is finished.
        // https://github.com/ziglang/zig/issues/1363
        return error.SkipZigTest;
    }
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    // TODO move this into event loop too
    try os.makePath(allocator, test_tmp_dir);
    defer os.deleteTree(allocator, test_tmp_dir) catch {};

    var loop: Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var result: anyerror!void = error.ResultNeverWritten;
    const handle = try async<allocator> testFsWatchCantFail(&loop, &result);
    defer cancel handle;

    loop.run();
    return result;
}

async fn testFsWatchCantFail(loop: *Loop, result: *(anyerror!void)) void {
    result.* = await (async testFsWatch(loop) catch unreachable);
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

pub const OutStream = struct {
    fd: os.FileHandle,
    stream: Stream,
    loop: *Loop,
    offset: usize,

    pub const Error = os.File.WriteError;
    pub const Stream = event.io.OutStream(Error);

    pub fn init(loop: *Loop, fd: os.FileHandle, offset: usize) OutStream {
        return OutStream{
            .fd = fd,
            .loop = loop,
            .offset = offset,
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    async<*mem.Allocator> fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {
        const self = @fieldParentPtr(OutStream, "stream", out_stream);
        const offset = self.offset;
        self.offset += bytes.len;
        return await (async pwritev(self.loop, self.fd, [][]const u8{bytes}, offset) catch unreachable);
    }
};

pub const InStream = struct {
    fd: os.FileHandle,
    stream: Stream,
    loop: *Loop,
    offset: usize,

    pub const Error = PReadVError; // TODO make this not have OutOfMemory
    pub const Stream = event.io.InStream(Error);

    pub fn init(loop: *Loop, fd: os.FileHandle, offset: usize) InStream {
        return InStream{
            .fd = fd,
            .loop = loop,
            .offset = offset,
            .stream = Stream{ .readFn = readFn },
        };
    }

    async<*mem.Allocator> fn readFn(in_stream: *Stream, bytes: []u8) Error!usize {
        const self = @fieldParentPtr(InStream, "stream", in_stream);
        const amt = try await (async preadv(self.loop, self.fd, [][]u8{bytes}, self.offset) catch unreachable);
        self.offset += amt;
        return amt;
    }
};
